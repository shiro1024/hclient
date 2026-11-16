import 'dart:async';
import 'dart:convert';
import 'dart:collection';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_socks_proxy/socks_proxy.dart' show SocksException;
import 'package:xml/xml.dart';

import '../content_sync/content_transfer_concurrency.dart';
import 'webdav_transport.dart';

enum WebDavErrorKind {
  authentication,
  missing,
  conflict,
  network,
  server,
  invalidResponse,
}

class WebDavException implements Exception {
  final WebDavErrorKind kind;
  final int? statusCode;
  final String message;
  final WebDavRequestFailure? requestFailure;

  const WebDavException(this.kind, this.message, [this.statusCode])
    : requestFailure = null;

  const WebDavException.network(this.requestFailure)
    : kind = WebDavErrorKind.network,
      message = 'WebDAV network error',
      statusCode = null;

  @override
  String toString() =>
      requestFailure == null ? message : '$message ($requestFailure)';
}

/// Transport diagnostics only: never retain Dio's request headers or body.
class WebDavRequestFailure {
  final String method;
  final Uri uri;
  final String phase;
  final Duration elapsed;
  final DioExceptionType? dioType;
  final String? causeType;
  final String? causeMessage;

  const WebDavRequestFailure({
    required this.method,
    required this.uri,
    required this.phase,
    required this.elapsed,
    required this.dioType,
    required this.causeType,
    required this.causeMessage,
  });

  @override
  String toString() => [
    '$method $uri',
    'phase=$phase',
    'elapsed=${elapsed.inMilliseconds}ms',
    if (dioType != null) 'dioType=${dioType!.name}',
    if (causeType != null) 'cause=$causeType',
    if (causeMessage != null) causeMessage!,
  ].join(', ');
}

class WebDavConnection {
  final Uri address;
  final String username;
  final String password;
  final List<String> rootSegments;

  WebDavConnection.fromFields({
    required String address,
    required this.username,
    required this.password,
    String rootPath = '',
  }) : address = _parseAddress(address),
       rootSegments = _segments(rootPath);

  static Uri _parseAddress(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        !{'http', 'https'}.contains(uri.scheme.toLowerCase()) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const FormatException('Enter a valid HTTP or HTTPS WebDAV address');
    }
    return uri.replace(
      scheme: uri.scheme.toLowerCase(),
      host: uri.host.toLowerCase(),
      pathSegments: uri.pathSegments.where((s) => s.isNotEmpty).toList(),
    );
  }

  static List<String> _segments(String path) {
    final segments = path
        .replaceAll('\\', '/')
        .split('/')
        .where((s) => s.isNotEmpty)
        .toList();
    if (segments.any((s) => s == '.' || s == '..'))
      throw const FormatException('Invalid WebDAV root path');
    return List.unmodifiable(segments);
  }

  String get namespace =>
      '${address.origin}${address.path}/${rootSegments.map(Uri.encodeComponent).join('/')}|$username';

  Uri uri(String relativePath, {bool directory = false}) {
    final parts = [
      ...address.pathSegments.where((s) => s.isNotEmpty),
      ...rootSegments,
      'hclient-v1',
      ..._segments(relativePath),
    ];
    return address.replace(pathSegments: [...parts, if (directory) '']);
  }

  Uri get parentUri => address.replace(
    pathSegments: [
      ...address.pathSegments.where((s) => s.isNotEmpty),
      ...rootSegments,
      '',
    ],
  );

  String get authorization =>
      'Basic ${base64Encode(utf8.encode('$username:$password'))}';
}

class WebDavResource {
  final Uri uri;
  final bool isCollection;
  final String? etag;
  final int? length;
  final DateTime? modified;

  const WebDavResource({
    required this.uri,
    required this.isCollection,
    this.etag,
    this.length,
    this.modified,
  });
}

class WebDavSyncResult {
  final List<WebDavResource> changed;
  final List<Uri> deleted;
  final String syncToken;
  final bool truncated;

  const WebDavSyncResult(
    this.changed,
    this.deleted,
    this.syncToken,
    this.truncated,
  );
}

class _DigestSink implements Sink<Digest> {
  Digest? value;
  @override
  void add(Digest data) => value = data;
  @override
  void close() {}
}

class _TransferPool {
  int available = contentTransferConcurrency;
  final Queue<Completer<void>> waiting = Queue<Completer<void>>();

  Future<T> run<T>(
    Future<T> Function() action, {
    CancelToken? cancelToken,
  }) async {
    if (cancelToken?.isCancelled == true) {
      throw cancelToken!.cancelError!;
    }
    if (available == 0 || waiting.isNotEmpty) {
      final waiter = Completer<void>();
      waiting.add(waiter);
      await Future.any([
        waiter.future,
        if (cancelToken != null) cancelToken.whenCancel.then((_) {}),
      ]);
      if (cancelToken?.isCancelled == true && waiting.remove(waiter)) {
        // Still queued: no capacity was granted, so nothing is released.
        throw cancelToken!.cancelError!;
      }
    } else {
      available--;
    }
    try {
      // A waiter can be granted its slot in the same turn as cancellation.
      // In that case this finally block is the only owner of the release.
      if (cancelToken?.isCancelled == true) {
        throw cancelToken!.cancelError!;
      }
      return await action();
    } finally {
      if (waiting.isNotEmpty) {
        waiting.removeFirst().complete();
      } else {
        available++;
      }
    }
  }
}

/// A client is bound to one immutable target, so an in-flight request cannot
/// silently move to a different account when settings are changed.
class WebDavClient {
  static final _fileTransfers = _TransferPool();
  static final WebDavTransport _sharedTransport = WebDavTransport();
  final WebDavConnection connection;
  final Dio? _dio;
  bool _closed = false;
  bool _syncUnsupported = false;

  WebDavClient(this.connection, {Dio? dio}) : _dio = dio;

  /// Releases this handle. Started requests finish normally; callers cancel
  /// individual transfers with their CancelToken rather than closing the pool.
  void close() {
    _closed = true;
  }

  Uri uri(String relativePath, {bool directory = false}) =>
      connection.uri(relativePath, directory: directory);

  Future<Response<dynamic>> _request(
    String method,
    Uri uri, {
    Object? data,
    Map<String, String>? headers,
    ResponseType responseType = ResponseType.plain,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
  }) async {
    if (_closed) {
      throw StateError('WebDAV client is closed');
    }
    final watch = Stopwatch()..start();
    var phase = 'request';
    try {
      final requestUri = _dio?.requestUri ?? _sharedTransport.requestUri;
      final response = await requestUri<dynamic>(
        uri,
        data: data,
        options: Options(
          method: method,
          responseType: responseType,
          validateStatus: (_) => true,
          headers: {
            HttpHeaders.authorizationHeader: connection.authorization,
            ...?headers,
          },
        ),
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
      );
      if ((response.statusCode ?? 0) >= 200 && (response.statusCode ?? 0) < 300)
        return response;
      if (response.data is ResponseBody) {
        phase = 'body';
        await (response.data as ResponseBody).stream.drain<void>();
      }
      throw _statusError(response.statusCode);
    } catch (error, stack) {
      if (_isTransportError(error)) {
        _throwNetworkError(method, uri, phase, watch.elapsed, error, stack);
      }
      rethrow;
    }
  }

  static bool _isTransportError(Object error) =>
      error is DioException ||
      error is HttpException ||
      error is SocketException ||
      error is TlsException ||
      error is SocksException;

  Never _throwNetworkError(
    String method,
    Uri target,
    String phase,
    Duration elapsed,
    Object error,
    StackTrace stack,
  ) {
    final dioType = error is DioException ? error.type : null;
    final originalStack = error is DioException ? error.stackTrace : stack;
    Object? cause = error;
    while (cause is DioException) {
      cause = cause.error;
    }
    // SDK transport exceptions expose useful messages without serializing
    // arbitrary adapter objects, which may contain credentials or payloads.
    final causeMessage = switch (cause) {
      SocketException() => cause.toString(),
      HttpException() => cause.toString(),
      TlsException() => cause.toString(),
      SocksException() => cause.toString(),
      _ => null,
    };
    Error.throwWithStackTrace(
      WebDavException.network(
        WebDavRequestFailure(
          method: method,
          uri: _diagnosticUri(target),
          phase: phase,
          elapsed: elapsed,
          dioType: dioType,
          causeType: cause?.runtimeType.toString(),
          causeMessage: causeMessage == null
              ? null
              : _redactTransportMessage(causeMessage),
        ),
      ),
      originalStack,
    );
  }

  static Uri _diagnosticUri(Uri uri) => Uri(
    scheme: uri.scheme,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
    pathSegments: uri.pathSegments,
  );

  String _redactTransportMessage(String message) {
    var result = message.replaceAllMapped(
      RegExp(r'''https?://[^\s<>"']+''', caseSensitive: false),
      (match) {
        final uri = Uri.tryParse(match[0]!);
        return uri == null ? '[URI]' : _diagnosticUri(uri).toString();
      },
    );
    result = result.replaceAll(connection.authorization, '[authorization]');
    if (connection.username.isNotEmpty || connection.password.isNotEmpty) {
      result = result.replaceAll(
        '${connection.username}:${connection.password}',
        '[credentials]',
      );
    }
    if (connection.password.isNotEmpty) {
      result = result.replaceAll(
        RegExp(
          '(?<![a-zA-Z0-9_])${RegExp.escape(connection.password)}(?![a-zA-Z0-9_])',
        ),
        '[password]',
      );
    }
    return result;
  }

  WebDavException _statusError(int? status) {
    if (status == 401 || status == 403)
      return WebDavException(
        WebDavErrorKind.authentication,
        'WebDAV authentication failed',
        status,
      );
    if (status == 404)
      return WebDavException(
        WebDavErrorKind.missing,
        'WebDAV resource was not found',
        status,
      );
    if (status == 405 || status == 409 || status == 412)
      return WebDavException(
        WebDavErrorKind.conflict,
        'WebDAV resource conflict',
        status,
      );
    return WebDavException(
      WebDavErrorKind.server,
      'WebDAV server returned ${status ?? 'an error'}',
      status,
    );
  }

  Future<bool> exists(
    String path, {
    bool directory = false,
    CancelToken? cancelToken,
  }) async {
    final target = uri(path, directory: directory);
    try {
      final response = await _request(
        'PROPFIND',
        target,
        headers: {'Depth': '0'},
        data: _propfindBody,
        cancelToken: cancelToken,
      );
      if (response.statusCode == 207) {
        final document = XmlDocument.parse(response.data as String);
        final matches = document.descendants
            .whereType<XmlElement>()
            .where((e) => e.name.local == 'response')
            .where((e) {
              final href = _first(e, 'href')?.innerText;
              return href != null &&
                  _sameResource(target, target.resolve(href));
            });
        if (matches.isEmpty) {
          throw const WebDavException(
            WebDavErrorKind.invalidResponse,
            'WebDAV resource status is missing',
          );
        }
        _successfulProps(matches.first);
      }
      return true;
    } on WebDavException catch (e) {
      if (e.kind == WebDavErrorKind.missing) return false;
      rethrow;
    } on XmlException {
      throw const WebDavException(
        WebDavErrorKind.invalidResponse,
        'Invalid WebDAV resource response',
      );
    }
  }

  Future<void> ensureCollection(String relativePath) async {
    final base = connection.address.pathSegments
        .where((s) => s.isNotEmpty)
        .toList();
    final pieces = [
      ...connection.rootSegments,
      'hclient-v1',
      ...WebDavConnection._segments(relativePath),
    ];
    await _ensureCollection(
      connection.address.replace(pathSegments: [...base, ...pieces, '']),
      base.length + 1,
    );
  }

  Future<void> _ensureCollection(Uri target, int minimumDepth) async {
    try {
      await _createCollection(target);
    } on WebDavException catch (e) {
      final segments = target.pathSegments.where((s) => s.isNotEmpty).toList();
      if (e.statusCode != 409 || segments.length <= minimumDepth) {
        rethrow;
      }
      // Existing leaves need only one request. Prepare parents only when the
      // server reports one missing, including after external directory removal.
      await _ensureCollection(
        target.replace(
          pathSegments: [...segments.take(segments.length - 1), ''],
        ),
        minimumDepth,
      );
      await _createCollection(target);
    }
  }

  Future<void> _createCollection(Uri target) async {
    try {
      await _request('MKCOL', target);
    } on WebDavException catch (e) {
      if (e.statusCode != 405) {
        rethrow;
      }
    }
  }

  Future<T> _fileTransfer<T>(
    String method,
    String path,
    Future<T> Function() action,
    CancelToken? cancelToken,
  ) async {
    final watch = Stopwatch()..start();
    try {
      return await _fileTransfers.run(action, cancelToken: cancelToken);
    } on DioException catch (error, stack) {
      if (!CancelToken.isCancel(error)) {
        rethrow;
      }
      // Requests already translate transport failures at their own boundary.
      // Cancellation before a request starts belongs to the transfer queue.
      _throwNetworkError(
        method,
        uri(path),
        'queue',
        watch.elapsed,
        error,
        stack,
      );
    }
  }

  Future<void> putFile(
    String path,
    File file, {
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
  }) => _fileTransfer(
    'PUT',
    path,
    () => _putFile(
      path,
      file,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
    ),
    cancelToken,
  );

  Future<void> _putFile(
    String path,
    File file, {
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
  }) async {
    final length = await file.length();
    await _request(
      'PUT',
      uri(path),
      data: file.openRead(),
      headers: {
        HttpHeaders.contentLengthHeader: '$length',
        HttpHeaders.contentTypeHeader: 'application/octet-stream',
      },
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
    );
  }

  Future<void> move(
    String source,
    String destination, {
    bool overwrite = false,
  }) async {
    await _request(
      'MOVE',
      uri(source),
      headers: {
        'Destination': uri(destination).toString(),
        'Overwrite': overwrite ? 'T' : 'F',
      },
    );
  }

  Future<void> delete(String path) async =>
      _request('DELETE', uri(path)).then((_) {});

  Future<List<WebDavResource>> list(
    String path, {
    CancelToken? cancelToken,
  }) async {
    final target = uri(path, directory: true);
    try {
      final result = <WebDavResource>[];
      String? cursor;
      final seenCursors = <String>{};
      var sawCollection = false;
      do {
        final pageUri = cursor == null
            ? target
            : target.replace(queryParameters: {'cursor': cursor});
        final response = await _request(
          'PROPFIND',
          pageUri,
          data: _propfindBody,
          cancelToken: cancelToken,
          headers: {
            'Depth': '1',
            HttpHeaders.contentTypeHeader: 'application/xml; charset=utf-8',
          },
        );
        final xml = XmlDocument.parse(response.data as String);
        for (final node in xml.descendants.whereType<XmlElement>().where(
          (e) => e.name.local == 'response',
        )) {
          final href = _first(node, 'href')?.innerText;
          if (href == null)
            throw const WebDavException(
              WebDavErrorKind.invalidResponse,
              'WebDAV response is missing href',
            );
          final resourceUri = target.resolve(href);
          final isSelf = _sameResource(target, resourceUri);
          late final List<XmlElement> props;
          try {
            props = _successfulProps(node);
          } on WebDavException catch (e) {
            if (!isSelf && e.kind == WebDavErrorKind.missing) {
              throw const WebDavException(
                WebDavErrorKind.invalidResponse,
                'WebDAV directory listing contains a missing child',
              );
            }
            rethrow;
          }
          if (isSelf) {
            sawCollection = true;
            continue;
          }
          final collection = props.any(
            (prop) => prop.descendants.whereType<XmlElement>().any(
              (e) => e.name.local == 'collection',
            ),
          );
          final length = int.tryParse(
            _firstInProps(props, 'getcontentlength')?.innerText ?? '',
          );
          final modifiedText = _firstInProps(
            props,
            'getlastmodified',
          )?.innerText;
          DateTime? modified;
          if (modifiedText != null) {
            try {
              modified = HttpDate.parse(modifiedText);
            } catch (_) {
              /* Optional server property. */
            }
          }
          result.add(
            WebDavResource(
              uri: resourceUri,
              isCollection: collection,
              etag: _firstInProps(props, 'getetag')?.innerText,
              length: length,
              modified: modified,
            ),
          );
        }
        cursor = response.headers.value('x-next-cursor');
        if (cursor != null && !seenCursors.add(cursor))
          throw const WebDavException(
            WebDavErrorKind.invalidResponse,
            'WebDAV pagination did not advance',
          );
      } while (cursor != null);
      if (!sawCollection)
        throw const WebDavException(
          WebDavErrorKind.invalidResponse,
          'WebDAV collection status is missing',
        );
      return result;
    } catch (e) {
      if (e is WebDavException) rethrow;
      throw const WebDavException(
        WebDavErrorKind.invalidResponse,
        'Invalid WebDAV directory response',
      );
    }
  }

  /// Returns null when collection synchronization is unsupported. A stale token is reported as
  /// a conflict so the caller can restart this partition with an empty token.
  Future<WebDavSyncResult?> syncCollection(
    String path,
    String? token, {
    CancelToken? cancelToken,
  }) async {
    if (_syncUnsupported && token == null) return null;
    final target = uri(path, directory: true);
    final escapedToken = token == null ? '' : _xmlEscape(token);
    Response<dynamic> response;
    try {
      response = await _request(
        'REPORT',
        target,
        cancelToken: cancelToken,
        data:
            '<?xml version="1.0" encoding="utf-8"?>'
            '<d:sync-collection xmlns:d="DAV:">'
            '<d:sync-token>$escapedToken</d:sync-token>'
            '<d:sync-level>1</d:sync-level>'
            '<d:prop><d:getetag/></d:prop>'
            '</d:sync-collection>',
        headers: {
          'Depth': '0',
          HttpHeaders.contentTypeHeader: 'application/xml; charset=utf-8',
        },
      );
    } on WebDavException catch (error) {
      if (error.statusCode == 405 || error.statusCode == 501) {
        _syncUnsupported = true;
        return null;
      }
      rethrow;
    }
    if (response.statusCode != 207) {
      throw const WebDavException(
        WebDavErrorKind.invalidResponse,
        'Invalid WebDAV sync report',
      );
    }
    try {
      final xml = XmlDocument.parse(response.data as String);
      final root = xml.rootElement;
      if (root.name.local != 'multistatus')
        throw const FormatException('Missing multistatus');
      final nextToken = root.children
          .whereType<XmlElement>()
          .where((element) => element.name.local == 'sync-token')
          .firstOrNull
          ?.innerText;
      if (nextToken == null || nextToken.isEmpty)
        throw const FormatException('Missing sync token');
      final changed = <WebDavResource>[];
      final deleted = <Uri>[];
      var truncated = false;
      for (final node in root.children.whereType<XmlElement>().where(
        (element) => element.name.local == 'response',
      )) {
        final href = _first(node, 'href')?.innerText;
        if (href == null) throw const FormatException('Missing href');
        final resourceUri = target.resolve(href);
        final statusText = node.children
            .whereType<XmlElement>()
            .where((element) => element.name.local == 'status')
            .firstOrNull
            ?.innerText;
        final status = int.tryParse(
          RegExp(r'\b(\d{3})\b').firstMatch(statusText ?? '')?.group(1) ?? '',
        );
        if (status == 404) {
          deleted.add(resourceUri);
          continue;
        }
        if (status == 507 && _sameResource(target, resourceUri)) {
          truncated = true;
          continue;
        }
        final props = _successfulProps(node);
        changed.add(
          WebDavResource(
            uri: resourceUri,
            isCollection: props.any(
              (prop) => prop.descendants.whereType<XmlElement>().any(
                (element) => element.name.local == 'collection',
              ),
            ),
            etag: _firstInProps(props, 'getetag')?.innerText,
          ),
        );
      }
      return WebDavSyncResult(changed, deleted, nextToken, truncated);
    } catch (_) {
      throw const WebDavException(
        WebDavErrorKind.invalidResponse,
        'Invalid WebDAV sync report',
      );
    }
  }

  static String _xmlEscape(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');

  Future<String> getFile(
    String path,
    File file, {
    bool resume = true,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) => _fileTransfer(
    'GET',
    path,
    () => _getFile(
      path,
      file,
      resume: resume,
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress,
    ),
    cancelToken,
  );

  Future<String> _getFile(
    String path,
    File file, {
    bool resume = true,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    var offset = resume && await file.exists() ? await file.length() : 0;
    await file.parent.create(recursive: true);
    var digestSink = _DigestSink();
    var hash = sha256.startChunkedConversion(digestSink);
    var prefixHashed = false;
    var receivedBytes = 0;
    while (true) {
      final watch = Stopwatch()..start();
      Response<dynamic> response;
      try {
        response = await _request(
          'GET',
          uri(path),
          responseType: ResponseType.stream,
          headers: {
            HttpHeaders.acceptEncodingHeader: 'identity',
            if (offset > 0) HttpHeaders.rangeHeader: 'bytes=$offset-',
          },
          cancelToken: cancelToken,
        );
      } on WebDavException catch (e) {
        if (e.statusCode != 416 || offset == 0) rethrow;
        // A stale prefix can be replaced only after a successful full GET.
        offset = 0;
        digestSink = _DigestSink();
        hash = sha256.startChunkedConversion(digestSink);
        prefixHashed = false;
        continue;
      }
      if (response.statusCode != 200 && response.statusCode != 206) {
        await _discardStream(response);
        throw const WebDavException(
          WebDavErrorKind.invalidResponse,
          'WebDAV download returned an unexpected status',
        );
      }
      int? total;
      int? expectedLength;
      if (response.statusCode == 206) {
        final range = response.headers.value(HttpHeaders.contentRangeHeader);
        final match = range == null
            ? null
            : RegExp(r'^bytes (\d+)-(\d+)/(\d+)$').firstMatch(range);
        if (match == null) {
          await _discardStream(response);
          throw const WebDavException(
            WebDavErrorKind.invalidResponse,
            'Invalid WebDAV Content-Range',
          );
        }
        final start = int.parse(match.group(1)!);
        final end = int.parse(match.group(2)!);
        total = int.parse(match.group(3)!);
        if (start != offset || end < start || total <= end) {
          await _discardStream(response);
          throw const WebDavException(
            WebDavErrorKind.invalidResponse,
            'WebDAV Content-Range does not match the local file',
          );
        }
        expectedLength = end - start + 1;
        final declared = int.tryParse(
          response.headers.value(HttpHeaders.contentLengthHeader) ?? '',
        );
        if (declared != null && declared != expectedLength) {
          await _discardStream(response);
          throw const WebDavException(
            WebDavErrorKind.invalidResponse,
            'WebDAV range length is inconsistent',
          );
        }
        if (!prefixHashed) {
          if (offset > 0) {
            await for (final chunk in file.openRead(0, offset)) {
              hash.add(chunk);
            }
          }
          prefixHashed = true;
        }
      } else {
        offset = 0;
        digestSink = _DigestSink();
        hash = sha256.startChunkedConversion(digestSink);
        prefixHashed = true;
        expectedLength = int.tryParse(
          response.headers.value(HttpHeaders.contentLengthHeader) ?? '',
        );
      }
      final sink = file.openWrite(
        mode: offset == 0 ? FileMode.write : FileMode.append,
      );
      var received = 0;
      final responseStartBytes = receivedBytes;
      try {
        await for (final chunk in (response.data as ResponseBody).stream) {
          if (cancelToken?.isCancelled == true) throw cancelToken!.cancelError!;
          received += chunk.length;
          receivedBytes += chunk.length;
          onReceiveProgress?.call(
            receivedBytes,
            total == null
                ? expectedLength ?? -1
                : responseStartBytes + total - offset,
          );
          if (expectedLength != null && received > expectedLength) {
            throw const WebDavException(
              WebDavErrorKind.invalidResponse,
              'WebDAV response exceeded its declared length',
            );
          }
          sink.add(chunk);
          hash.add(chunk);
        }
        await sink.close();
      } catch (error, stack) {
        await sink.close();
        if (_isTransportError(error)) {
          _throwNetworkError(
            'GET',
            uri(path),
            'body',
            watch.elapsed,
            error,
            stack,
          );
        }
        rethrow;
      }
      if (expectedLength != null && received != expectedLength) {
        throw const WebDavException(
          WebDavErrorKind.invalidResponse,
          'WebDAV response length was incomplete',
        );
      }
      offset += received;
      if (total != null && offset < total) continue;
      hash.close();
      return digestSink.value!.toString();
    }
  }

  Future<void> _discardStream(Response<dynamic> response) async {
    if (response.data is ResponseBody) {
      await (response.data as ResponseBody).stream.drain<void>();
    }
  }

  bool _sameResource(Uri a, Uri b) {
    final aParts = a.pathSegments.where((s) => s.isNotEmpty).toList();
    final bParts = b.pathSegments.where((s) => s.isNotEmpty).toList();
    return a.origin == b.origin &&
        aParts.length == bParts.length &&
        List.generate(
          aParts.length,
          (i) => aParts[i] == bParts[i],
        ).every((same) => same);
  }

  List<XmlElement> _successfulProps(XmlElement response) {
    int? parseStatus(XmlElement element) {
      final value = element.children
          .whereType<XmlElement>()
          .where((e) => e.name.local == 'status')
          .firstOrNull
          ?.innerText;
      if (value == null) return null;
      return int.tryParse(
        RegExp(r'\b(\d{3})\b').firstMatch(value)?.group(1) ?? '',
      );
    }

    final direct = parseStatus(response);
    if (direct != null && (direct < 200 || direct >= 300))
      throw _statusError(direct);
    final propstats = response.children
        .whereType<XmlElement>()
        .where((e) => e.name.local == 'propstat')
        .toList();
    final statuses = propstats.map(parseStatus).toList();
    if (statuses.any((status) => status == null)) {
      throw const WebDavException(
        WebDavErrorKind.invalidResponse,
        'WebDAV property status is missing',
      );
    }
    for (final status in statuses.whereType<int>()) {
      if ((status < 200 || status >= 300) && status != 404)
        throw _statusError(status);
    }
    final success = propstats.where((p) {
      final status = parseStatus(p);
      return status != null && status >= 200 && status < 300;
    }).toList();
    if (success.isNotEmpty) {
      final props = <XmlElement>[];
      for (final item in success) {
        final prop = item.children
            .whereType<XmlElement>()
            .where((e) => e.name.local == 'prop')
            .firstOrNull;
        if (prop == null)
          throw const WebDavException(
            WebDavErrorKind.invalidResponse,
            'WebDAV properties are missing',
          );
        props.add(prop);
      }
      return props;
    }
    final failure = statuses.whereType<int>().firstOrNull ?? direct;
    if (failure != null && (failure < 200 || failure >= 300))
      throw _statusError(failure);
    throw const WebDavException(
      WebDavErrorKind.invalidResponse,
      'WebDAV property status is missing',
    );
  }

  static XmlElement? _firstInProps(List<XmlElement> props, String localName) {
    for (final prop in props) {
      final value = _first(prop, localName);
      if (value != null) return value;
    }
    return null;
  }

  static XmlElement? _first(XmlElement node, String localName) {
    for (final element in node.descendants.whereType<XmlElement>()) {
      if (element.name.local == localName) return element;
    }
    return null;
  }

  static const _propfindBody =
      '<?xml version="1.0" encoding="utf-8"?><d:propfind xmlns:d="DAV:"><d:prop><d:getetag/><d:getcontentlength/><d:getlastmodified/><d:resourcetype/></d:prop></d:propfind>';
}
