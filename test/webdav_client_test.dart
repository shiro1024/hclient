import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_socks_proxy/socks_proxy.dart' show SocksException;
import 'package:jhentai/src/service/webdav/webdav_client.dart';

void main() {
  for (final status in [405, 501]) {
    test(
      'REPORT $status capability is reused only by the current client',
      () async {
        final dio = Dio();
        final requested = <String>[];
        dio.httpClientAdapter = _TestAdapter((options) async {
          expect(options.method, 'REPORT');
          requested.add(options.uri.path);
          return ResponseBody.fromString('', status);
        });
        final first = WebDavClient(_diagnosticConnection(), dio: dio);
        final next = WebDavClient(_diagnosticConnection(), dio: dio);
        try {
          expect(await first.syncCollection('manifests/aa', null), isNull);
          expect(await first.syncCollection('manifests/bb', null), isNull);
          expect(requested, ['/dav/hclient-v1/manifests/aa/']);
          expect(await next.syncCollection('manifests/bb', null), isNull);
          expect(requested, [
            '/dav/hclient-v1/manifests/aa/',
            '/dav/hclient-v1/manifests/bb/',
          ]);
        } finally {
          first.close();
          next.close();
          dio.close(force: true);
        }
      },
    );
  }

  test('an unsupported parallel partition preserves an existing REPORT continuation', () async {
    final dio = Dio();
    final unsupportedStarted = Completer<void>();
    final releaseUnsupported = Completer<void>();
    final requested = <(String, String)>[];
    dio.httpClientAdapter = _TestAdapter((options) async {
      expect(options.method, 'REPORT');
      final token = RegExp(r'<d:sync-token>(.*?)</d:sync-token>')
          .firstMatch(options.data as String)!
          .group(1)!;
      requested.add((options.uri.path, token));
      if (options.uri.path.endsWith('/bb/')) {
        unsupportedStarted.complete();
        await releaseUnsupported.future;
        return ResponseBody.fromString('', 405);
      }
      return ResponseBody.fromString(
        '<?xml version="1.0"?><d:multistatus xmlns:d="DAV:">'
        '${token.isEmpty ? '<d:response><d:href>${options.uri.path}</d:href><d:status>HTTP/1.1 507 Insufficient Storage</d:status></d:response>' : ''}'
        '<d:sync-token>${token.isEmpty ? 'sync://aa/first' : 'sync://aa/complete'}</d:sync-token>'
        '</d:multistatus>',
        207,
      );
    });
    final client = WebDavClient(_diagnosticConnection(), dio: dio);
    try {
      final supported = client.syncCollection('manifests/aa', null);
      final unsupported = client.syncCollection('manifests/bb', null);
      final firstPage = (await supported)!;
      await unsupportedStarted.future;
      expect(firstPage.truncated, isTrue);
      releaseUnsupported.complete();
      expect(await unsupported, isNull);
      // The server capability hint must not discard a token already obtained
      // by another partition that was being scanned concurrently.
      final lastPage = (await client.syncCollection(
        'manifests/aa',
        firstPage.syncToken,
      ))!;
      expect(lastPage.truncated, isFalse);
      expect(lastPage.syncToken, 'sync://aa/complete');
      expect(await client.syncCollection('manifests/cc', null), isNull);
      expect(requested, [
        ('/dav/hclient-v1/manifests/aa/', ''),
        ('/dav/hclient-v1/manifests/bb/', ''),
        ('/dav/hclient-v1/manifests/aa/', 'sync://aa/first'),
      ]);
    } finally {
      if (!releaseUnsupported.isCompleted) {
        releaseUnsupported.complete();
      }
      client.close();
      dio.close(force: true);
    }
  });

  for (final failure in ['401', '403', 'network']) {
    test(
      'REPORT $failure failures do not disable later capability probes',
      () async {
        final dio = Dio();
        var attempts = 0;
        dio.httpClientAdapter = _TestAdapter((options) async {
          expect(options.method, 'REPORT');
          if (++attempts == 1) {
            if (failure == 'network') {
              throw DioException(
                requestOptions: options,
                error: const SocketException('fixture disconnect'),
              );
            }
            return ResponseBody.fromString('', int.parse(failure));
          }
          return ResponseBody.fromString(
            '<?xml version="1.0"?><d:multistatus xmlns:d="DAV:"><d:sync-token>sync://recovered</d:sync-token></d:multistatus>',
            207,
          );
        });
        final client = WebDavClient(_diagnosticConnection(), dio: dio);
        try {
          await expectLater(
            client.syncCollection('manifests/aa', null),
            throwsA(
              isA<WebDavException>().having(
                (error) => error.statusCode,
                'status',
                failure == 'network' ? null : int.parse(failure),
              ),
            ),
          );
          final recovered = await client.syncCollection('manifests/bb', null);
          expect(recovered!.syncToken, 'sync://recovered');
          expect(attempts, 2);
        } finally {
          client.close();
          dio.close(force: true);
        }
      },
    );
  }

  test(
    'keeps transport details and the original stack when Dio has no message',
    () async {
      final dio = Dio();
      final originalStack = StackTrace.fromString('transport fixture stack');
      dio.httpClientAdapter = _TestAdapter((options) async {
        throw DioException(
          requestOptions: options,
          error: const HandshakeException('TLS fixture failure'),
          stackTrace: originalStack,
        );
      });
      final client = WebDavClient(_diagnosticConnection(), dio: dio);
      try {
        await client.ensureCollection('objects/aa');
        fail('Expected a transport error');
      } on WebDavException catch (error, stack) {
        expect(error.kind, WebDavErrorKind.network);
        expect(error.statusCode, isNull);
        final failure = error.requestFailure!;
        expect(failure.method, 'MKCOL');
        expect(
          failure.uri.toString(),
          'https://example.test/dav/hclient-v1/objects/aa/',
        );
        expect(failure.phase, 'request');
        expect(failure.elapsed, greaterThanOrEqualTo(Duration.zero));
        expect(failure.dioType, DioExceptionType.unknown);
        expect(failure.causeType, 'HandshakeException');
        expect(error.toString(), contains('TLS fixture failure'));
        expect(stack.toString(), originalStack.toString());
        expect(error.toString(), isNot(contains('diagnostic-password')));
        expect(
          error.toString(),
          isNot(contains(_diagnosticConnection().authorization)),
        );
      } finally {
        client.close();
        dio.close(force: true);
      }
    },
  );

  test('preserves anonymous transport message punctuation and URIs', () async {
    final dio = Dio();
    final cause = SocketException(
      'Connection failed: http://127.0.0.1:7890/proxy',
      osError: const OSError('Connection refused', 61),
      address: InternetAddress.loopbackIPv4,
      port: 7890,
    );
    dio.httpClientAdapter = _TestAdapter((options) async {
      throw DioException(requestOptions: options, error: cause);
    });
    final client = WebDavClient(
      WebDavConnection.fromFields(
        address: 'https://example.test/dav',
        username: '',
        password: '',
      ),
      dio: dio,
    );
    try {
      await client.ensureCollection('objects');
      fail('Expected a transport error');
    } on WebDavException catch (error) {
      expect(error.kind, WebDavErrorKind.network);
      expect(error.requestFailure!.causeType, 'SocketException');
      expect(error.requestFailure!.causeMessage, cause.toString());
      expect(error.toString(), contains('SocketException: Connection failed:'));
      expect(error.toString(), contains('http://127.0.0.1:7890/proxy'));
      expect(error.toString(), isNot(contains('[credentials]')));
    } finally {
      client.close();
      dio.close(force: true);
    }
  });

  test('keeps the installed SOCKS transport failure reasons', () async {
    for (final cause in [
      SocksException.incorrect,
      SocksException.failure,
      SocksException.noAuthMethods,
    ]) {
      final dio = Dio();
      dio.httpClientAdapter = _TestAdapter((options) async {
        throw DioException(requestOptions: options, error: cause);
      });
      final client = WebDavClient(_diagnosticConnection(), dio: dio);
      try {
        await client.ensureCollection('objects');
        fail('Expected a transport error');
      } on WebDavException catch (error) {
        expect(error.kind, WebDavErrorKind.network);
        expect(error.requestFailure!.causeType, 'SocksException');
        expect(error.toString(), contains(cause.toString()));
      } finally {
        client.close();
        dio.close(force: true);
      }
    }
  });

  test(
    'redacts paginated request tokens and transport URI credentials',
    () async {
      final dio = Dio();
      var requests = 0;
      dio.httpClientAdapter = _TestAdapter((options) async {
        if (++requests == 1) {
          return ResponseBody.fromString(
            _multiStatus([
              _response('/dav/hclient-v1/backups/', 200, collection: true),
            ]),
            207,
            headers: {
              'x-next-cursor': ['private-cursor'],
            },
          );
        }
        expect(options.uri.queryParameters['cursor'], 'private-cursor');
        throw DioException(
          requestOptions: options,
          error: HttpException(
            'Connection closed for https://someone:diagnostic-password@example.test/dav?token=private-token#private-fragment',
            uri: options.uri,
          ),
        );
      });
      final client = WebDavClient(_diagnosticConnection(), dio: dio);
      try {
        await client.list('backups');
        fail('Expected a transport error');
      } on WebDavException catch (error) {
        final failure = error.requestFailure!;
        expect(failure.method, 'PROPFIND');
        expect(failure.uri.hasQuery, false);
        expect(failure.uri.hasFragment, false);
        expect(failure.uri.userInfo, isEmpty);
        expect(failure.causeType, 'HttpException');
        expect(error.toString(), contains('Connection closed'));
        for (final secret in [
          'someone',
          'diagnostic-password',
          'private-token',
          'private-fragment',
          'private-cursor',
        ]) {
          expect(error.toString(), isNot(contains(secret)));
        }
      } finally {
        client.close();
        dio.close(force: true);
      }
    },
  );

  test(
    'does not serialize arbitrary adapter errors, Dio messages or request data',
    () async {
      final dio = Dio();
      dio.httpClientAdapter = _TestAdapter((options) async {
        throw DioException(
          requestOptions: options,
          message: 'Authorization: secret-header; body: secret-body',
          error: _SensitiveAdapterError(),
        );
      });
      final client = WebDavClient(_diagnosticConnection(), dio: dio);
      try {
        await client.ensureCollection('objects');
        fail('Expected a transport error');
      } on WebDavException catch (error) {
        expect(error.requestFailure!.causeType, '_SensitiveAdapterError');
        expect(error.requestFailure!.causeMessage, isNull);
        expect(error.toString(), isNot(contains('secret-header')));
        expect(error.toString(), isNot(contains('secret-body')));
        expect(error.toString(), isNot(contains('diagnostic-password')));
      } finally {
        client.close();
        dio.close(force: true);
      }
    },
  );

  test('diagnoses a real HTTP disconnect before response headers', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final socket = await request.response.detachSocket(writeHeaders: false);
      socket.destroy();
    });
    final dio = Dio();
    final client = WebDavClient(
      WebDavConnection.fromFields(
        address: 'http://127.0.0.1:${server.port}',
        username: 'u',
        password: 'p',
      ),
      dio: dio,
    );
    try {
      await client.ensureCollection('objects');
      fail('Expected a transport error');
    } on WebDavException catch (error) {
      expect(error.kind, WebDavErrorKind.network);
      expect(error.requestFailure!.method, 'MKCOL');
      expect(error.requestFailure!.phase, 'request');
      expect(error.requestFailure!.causeType, 'HttpException');
      expect(
        error.toString(),
        contains('Connection closed before full header'),
      );
    } finally {
      client.close();
      dio.close(force: true);
      await server.close(force: true);
    }
  });

  test('diagnoses a real receive timeout without changing the error kind', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requestStarted = Completer<void>();
    server.listen((request) {
      requestStarted.complete();
      // Deliberately leave response headers pending until the client times out.
    });
    final dio = Dio(
      BaseOptions(receiveTimeout: const Duration(milliseconds: 80)),
    );
    final client = WebDavClient(
      WebDavConnection.fromFields(
        address: 'http://127.0.0.1:${server.port}',
        username: 'u',
        password: 'p',
      ),
      dio: dio,
    );
    try {
      await expectLater(
        client.ensureCollection('objects'),
        throwsA(
          isA<WebDavException>()
              .having((error) => error.kind, 'kind', WebDavErrorKind.network)
              .having(
                (error) => error.requestFailure!.dioType,
                'Dio type',
                DioExceptionType.receiveTimeout,
              )
              .having(
                (error) => error.requestFailure!.phase,
                'phase',
                'request',
              )
              .having(
                (error) => error.toString(),
                'diagnostics',
                contains('elapsed='),
              ),
        ),
      );
      expect(requestStarted.isCompleted, true);
    } finally {
      client.close();
      dio.close(force: true);
      await server.close(force: true);
    }
  });

  test('reuses TCP across logical clients, credentials and an idle gap', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final ports = <int>{};
    final credentials = <String?>[];
    final paths = <String>[];
    server.listen((request) async {
      ports.add(request.connectionInfo!.remotePort);
      credentials.add(request.headers.value(HttpHeaders.authorizationHeader));
      paths.add(request.uri.path);
      expect(await utf8.decoder.bind(request).join(), 'abc');
      request.response.statusCode = 201;
      await request.response.close();
    });
    final dir = await Directory.systemTemp.createTemp('webdav-pool-test-');
    final file = File('${dir.path}/artifact')..writeAsStringSync('abc');
    try {
      for (var i = 0; i < 6; i++) {
        if (i == 3) {
          // The fork's default adapter expires sockets after three seconds.
          await Future<void>.delayed(const Duration(milliseconds: 3200));
        }
        final connection = WebDavConnection.fromFields(
          address: 'http://127.0.0.1:${server.port}/dav',
          username: i < 3 ? 'old' : 'new',
          password: 'secret-$i',
          rootPath: i < 3 ? 'old-root' : 'new-root',
        );
        expect(
          () => connection.rootSegments.add('changed'),
          throwsUnsupportedError,
        );
        final client = WebDavClient(connection);
        try {
          final sent = <int>[];
          await client.putFile(
            'file-$i',
            file,
            onSendProgress: (count, total) {
              expect(total, 3);
              sent.add(count);
            },
          );
          expect(sent, isNotEmpty);
          expect(sent.last, 3);
        } finally {
          client.close();
        }
      }
      expect(ports, hasLength(1));
      expect(credentials, [
        for (var i = 0; i < 6; i++)
          'Basic ${base64Encode(utf8.encode('${i < 3 ? 'old' : 'new'}:secret-$i'))}',
      ]);
      expect(paths.take(3), everyElement(startsWith('/dav/old-root/')));
      expect(paths.skip(3), everyElement(startsWith('/dav/new-root/')));
    } finally {
      await server.close(force: true);
      await dir.delete(recursive: true);
    }
  });

  test(
    'shares eight HTTP transfers and cancels queued files without waiting',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final gates = <String, Completer<void>>{};
      final paths = <String>[];
      final eightStarted = Completer<void>();
      final successorStarted = Completer<void>();
      var active = 0;
      var peak = 0;
      server.listen((request) async {
        final name = request.uri.pathSegments.last;
        paths.add(name);
        active++;
        if (active > peak) {
          peak = active;
        }
        if (paths.length == 8) {
          eightStarted.complete();
        }
        if (name == 'successor') {
          successorStarted.complete();
        }
        if (request.method == 'PUT') {
          await request.drain<void>();
        }
        await gates[name]!.future;
        active--;
        request.response.statusCode = request.method == 'PUT' ? 201 : 200;
        if (request.method == 'GET') {
          request.response.write('abc');
        }
        await request.response.close();
      });
      final dir = await Directory.systemTemp.createTemp('webdav-eight-test-');
      final file = File('${dir.path}/upload')..writeAsStringSync('abc');
      final connection = WebDavConnection.fromFields(
        address: 'http://127.0.0.1:${server.port}',
        username: 'u',
        password: 'p',
      );
      final clients = [WebDavClient(connection), WebDavClient(connection)];
      final running = <Future<Object?>>[];
      try {
        for (var i = 0; i < 8; i++) {
          final name = 'held-$i';
          gates[name] = Completer<void>();
          running.add(
            i.isEven
                ? clients[i % 2].putFile(name, file)
                : clients[i % 2].getFile(name, File('${dir.path}/$name')),
          );
        }
        await eightStarted.future.timeout(const Duration(seconds: 10));
        final cancel = CancelToken();
        final ninth = expectLater(
          clients.first.putFile('cancelled', file, cancelToken: cancel),
          throwsA(
            isA<WebDavException>()
                .having((error) => error.kind, 'kind', WebDavErrorKind.network)
                .having(
                  (error) => error.requestFailure!.phase,
                  'phase',
                  'queue',
                )
                .having(
                  (error) => error.requestFailure!.dioType,
                  'type',
                  DioExceptionType.cancel,
                ),
          ),
        );
        gates['successor'] = Completer<void>();
        final successor = clients.last.getFile(
          'successor',
          File('${dir.path}/successor'),
        );
        running.add(successor);
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(paths, hasLength(8));
        cancel.cancel('Cancel only the queued ninth transfer');
        await ninth.timeout(const Duration(seconds: 1));
        expect(active, 8);
        expect(paths, isNot(contains('cancelled')));
        expect(successorStarted.isCompleted, false);
        gates['held-0']!.complete();
        await successorStarted.future.timeout(const Duration(seconds: 10));
        expect(active, 8);
        expect(peak, 8);
        for (final gate in gates.values) {
          if (!gate.isCompleted) {
            gate.complete();
          }
        }
        await Future.wait(running);
        expect(await successor, sha256.convert(utf8.encode('abc')).toString());
        expect(paths, hasLength(9));
      } finally {
        for (final gate in gates.values) {
          if (!gate.isCompleted) {
            gate.complete();
          }
        }
        await Future.wait(running);
        for (final client in clients) {
          client.close();
        }
        await server.close(force: true);
        await dir.delete(recursive: true);
      }
    },
  );

  test(
    'cancellation around a transfer grant returns capacity exactly once',
    () async {
      final dir = await Directory.systemTemp.createTemp('webdav-grant-test-');
      final file = File('${dir.path}/upload')..writeAsStringSync('abc');
      final responses = <String, Completer<ResponseBody>>{};
      final started = <String>[];
      final dio = Dio();
      dio.httpClientAdapter = _TestAdapter((options) {
        final name = options.uri.pathSegments.last;
        started.add(name);
        return responses.putIfAbsent(name, Completer<ResponseBody>.new).future;
      });
      final client = WebDavClient(_diagnosticConnection(), dio: dio);
      void finish(String name) {
        final response = responses[name];
        if (response != null && !response.isCompleted) {
          response.complete(ResponseBody.fromString('', 201));
        }
      }

      Future<void> waitForCount(int count) async {
        for (var attempt = 0; attempt < 1000; attempt++) {
          if (started.length >= count) {
            return;
          }
          await Future<void>.delayed(const Duration(milliseconds: 1));
        }
        fail('Only ${started.length} transfers started, expected $count');
      }

      try {
        for (final cancelBeforeGrant in [true, false]) {
          final prefix = cancelBeforeGrant ? 'before' : 'after';
          final offset = started.length;
          final held = [
            for (var i = 0; i < 8; i++) client.putFile('$prefix-$i', file),
          ];
          await waitForCount(offset + 8);
          final cancel = CancelToken();
          final cancelled = expectLater(
            client.putFile('$prefix-cancelled', file, cancelToken: cancel),
            throwsA(
              isA<WebDavException>()
                  .having(
                    (error) => error.kind,
                    'kind',
                    WebDavErrorKind.network,
                  )
                  .having(
                    (error) => error.requestFailure!.dioType,
                    'type',
                    DioExceptionType.cancel,
                  ),
            ),
          );
          if (cancelBeforeGrant) {
            cancel.cancel();
            await cancelled.timeout(const Duration(seconds: 1));
            finish('$prefix-0');
          } else {
            finish('$prefix-0');
            await held.first;
            cancel.cancel();
            await cancelled.timeout(const Duration(seconds: 1));
          }
          for (var i = 1; i < 8; i++) {
            finish('$prefix-$i');
          }
          await Future.wait(held);
        }
        // A leak prevents all eight requests starting; an extra release admits nine.
        final offset = started.length;
        final refill = [
          for (var i = 0; i < 9; i++) client.putFile('refill-$i', file),
        ];
        await waitForCount(offset + 8);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(started.length, offset + 8);
        for (var i = 0; i < 8; i++) {
          finish('refill-$i');
        }
        await waitForCount(offset + 9);
        finish('refill-8');
        await Future.wait(refill);
      } finally {
        for (final name in responses.keys.toList()) {
          finish(name);
        }
        client.close();
        dio.close(force: true);
        await dir.delete(recursive: true);
      }
    },
  );

  test(
    'closing and cancelling one handle leaves sibling requests running',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final started = <String, Completer<void>>{
        'first': Completer<void>(),
        'second': Completer<void>(),
      };
      final release = Completer<void>();
      server.listen((request) async {
        started[request.uri.pathSegments.last]!.complete();
        await release.future;
        request.response.write('abc');
        await request.response.close();
      });
      final dir = await Directory.systemTemp.createTemp('webdav-cancel-test-');
      final connection = WebDavConnection.fromFields(
        address: 'http://127.0.0.1:${server.port}',
        username: 'u',
        password: 'p',
      );
      final first = WebDavClient(connection);
      final second = WebDavClient(connection);
      final cancel = CancelToken();
      final cancelled = expectLater(
        first.getFile('first', File('${dir.path}/first'), cancelToken: cancel),
        throwsA(
          isA<WebDavException>().having(
            (error) => error.kind,
            'kind',
            WebDavErrorKind.network,
          ),
        ),
      );
      final sibling = second.getFile('second', File('${dir.path}/second'));
      try {
        await Future.wait(started.values.map((value) => value.future));
        first.close();
        await expectLater(first.exists('closed'), throwsStateError);
        cancel.cancel('Stop only the first request');
        await cancelled;
        second.close();
        release.complete();
        expect(await sibling, sha256.convert(utf8.encode('abc')).toString());
        expect(await File('${dir.path}/second').readAsString(), 'abc');
      } finally {
        if (!release.isCompleted) {
          release.complete();
        }
        first.close();
        second.close();
        await server.close(force: true);
        await dir.delete(recursive: true);
      }
    },
  );

  test(
    'prepares only missing parents and recovers after directory changes',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final collections = <String>{'/dav/'};
      final attempts = <String>[];
      var failNext = false;
      String directoryPath(Uri uri) =>
          '${uri.path.replaceFirst(RegExp(r'/+$'), '')}/';
      void removeTree(String path) =>
          collections.removeWhere((entry) => entry.startsWith(path));
      server.listen((request) async {
        final path = directoryPath(request.uri);
        if (request.method == 'MKCOL') {
          attempts.add(path);
          if (failNext) {
            failNext = false;
            request.response.statusCode = 500;
          } else if (collections.contains(path)) {
            request.response.statusCode = 405;
          } else {
            final parent = path
                .substring(0, path.length - 1)
                .replaceFirst(RegExp(r'[^/]+$'), '');
            request.response.statusCode = collections.contains(parent)
                ? 201
                : 409;
            if (request.response.statusCode == 201) {
              collections.add(path);
            }
          }
        } else if (request.method == 'DELETE') {
          removeTree(path);
          request.response.statusCode = 204;
        } else if (request.method == 'MOVE') {
          final destination = directoryPath(
            Uri.parse(request.headers.value('Destination')!),
          );
          final moved = collections
              .where((entry) => entry.startsWith(path))
              .toList();
          removeTree(path);
          collections.addAll(
            moved.map((entry) => '$destination${entry.substring(path.length)}'),
          );
          request.response.statusCode = 201;
        }
        await request.response.close();
      });
      final client = WebDavClient(
        WebDavConnection.fromFields(
          address: 'http://127.0.0.1:${server.port}/dav',
          username: 'u',
          password: 'p',
          rootPath: 'root/one',
        ),
      );
      const root = '/dav/root/one/hclient-v1/';
      try {
        await client.ensureCollection('objects/aa');
        expect(collections, contains('${root}objects/aa/'));
        expect(attempts, hasLength(9));
        expect(attempts, isNot(contains('/dav/')));
        attempts.clear();
        await client.ensureCollection('objects/aa');
        await client.ensureCollection('objects/bb');
        expect(attempts, ['${root}objects/aa/', '${root}objects/bb/']);
        attempts.clear();
        await client.delete('objects');
        await client.ensureCollection('objects/aa');
        expect(attempts, [
          '${root}objects/aa/',
          '${root}objects/',
          '${root}objects/aa/',
        ]);
        attempts.clear();
        await client.move('objects', 'moved');
        await client.ensureCollection('objects/aa');
        expect(attempts, hasLength(3));
        expect(collections, contains('${root}moved/aa/'));
        // Simulate a directory removed by another WebDAV client.
        removeTree('/dav/root/one/');
        await client.ensureCollection('objects/aa');
        expect(collections, contains('${root}objects/aa/'));
        failNext = true;
        await expectLater(
          client.ensureCollection('objects/cc'),
          throwsA(isA<WebDavException>()),
        );
        await client.ensureCollection('objects/cc');
        expect(collections, contains('${root}objects/cc/'));
      } finally {
        client.close();
        await server.close(force: true);
      }
    },
  );

  test(
    'encodes segments and sends Basic auth, MKCOL, PUT, MOVE and DELETE',
    () async {
      final methods = <String>[];
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        methods.add(request.method);
        expect(
          request.headers.value(HttpHeaders.authorizationHeader),
          'Basic ${base64Encode(utf8.encode('a:b:secret'))}',
        );
        if (request.method == 'PUT') {
          expect(request.headers.contentLength, 3);
          expect(await utf8.decoder.bind(request).join(), 'abc');
          request.response.statusCode = 201;
        } else if (request.method == 'MOVE') {
          expect(request.headers.value('Overwrite'), 'F');
          expect(
            request.headers.value('Destination'),
            contains('backups/device%20one/file%23.json'),
          );
          request.response.statusCode = 201;
        } else if (request.method == 'DELETE') {
          request.response.statusCode = 204;
        } else {
          request.response.statusCode = 201;
        }
        await request.response.close();
      });
      final dir = await Directory.systemTemp.createTemp('webdav-test-');
      try {
        final connection = WebDavConnection.fromFields(
          address: 'http://localhost:${server.port}/v1/dav/sync/',
          username: 'a:b',
          password: 'secret',
          rootPath: 'root folder',
        );
        final client = WebDavClient(connection);
        expect(
          client.uri('backups/device one/file#.json').path,
          '/v1/dav/sync/root%20folder/hclient-v1/backups/device%20one/file%23.json',
        );
        expect(
          client.uri('backups/device one/file#.json').toString(),
          contains(
            'root%20folder/hclient-v1/backups/device%20one/file%23.json',
          ),
        );
        final file = File('${dir.path}/artifact')..writeAsStringSync('abc');
        await client.ensureCollection('backups/device one');
        await client.putFile('staging/item/hash', file);
        await client.move('staging/item/hash', 'backups/device one/file#.json');
        await client.delete('staging/item/hash');
        expect(methods, containsAllInOrder(['MKCOL', 'PUT', 'MOVE', 'DELETE']));
      } finally {
        await server.close(force: true);
        await dir.delete(recursive: true);
      }
    },
  );

  test('paginates PROPFIND and resumes GET with Range', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final ranges = <String?>[];
    server.listen((request) async {
      if (request.method == 'PROPFIND') {
        request.response.statusCode = 207;
        request.response.headers.contentType = ContentType(
          'application',
          'xml',
        );
        if (request.uri.queryParameters['cursor'] == null) {
          request.response.headers.set('x-next-cursor', 'page 2');
          request.response.write(
            _xml(
              '/v1/dav/sync/hclient-v1/backups/',
              '/v1/dav/sync/hclient-v1/backups/a%20b/',
            ),
          );
        } else {
          expect(request.uri.queryParameters['cursor'], 'page 2');
          request.response.write(
            _xml(
              '/v1/dav/sync/hclient-v1/backups/',
              '/v1/dav/sync/hclient-v1/backups/c/',
            ),
          );
        }
      } else if (request.method == 'GET') {
        ranges.add(request.headers.value(HttpHeaders.rangeHeader));
        request.response.statusCode = 206;
        request.response.headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes 3-5/6',
        );
        request.response.write('def');
      }
      await request.response.close();
    });
    final dir = await Directory.systemTemp.createTemp('webdav-test-');
    try {
      final client = WebDavClient(
        WebDavConnection.fromFields(
          address: 'http://localhost:${server.port}/v1/dav/sync',
          username: 'u',
          password: 'p',
        ),
      );
      final resources = await client.list('backups');
      expect(
        resources.map(
          (r) => r.uri.pathSegments.where((s) => s.isNotEmpty).last,
        ),
        ['a b', 'c'],
      );
      final file = File('${dir.path}/partial')..writeAsStringSync('abc');
      final progress = <(int, int)>[];
      await client.getFile(
        'backups/file',
        file,
        onReceiveProgress: (received, total) => progress.add((received, total)),
      );
      expect(progress.last, (3, 3));
      expect(ranges, ['bytes=3-']);
      expect(await file.readAsString(), 'abcdef');
    } finally {
      await server.close(force: true);
      await dir.delete(recursive: true);
    }
  });

  test('distinguishes authentication from missing resource', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.statusCode = request.uri.path.endsWith('missing')
          ? 404
          : 401;
      await request.response.close();
    });
    try {
      final client = WebDavClient(
        WebDavConnection.fromFields(
          address: 'http://localhost:${server.port}',
          username: 'u',
          password: 'p',
        ),
      );
      await expectLater(client.exists('missing'), completion(false));
      await expectLater(
        client.exists('denied'),
        throwsA(
          isA<WebDavException>().having(
            (e) => e.kind,
            'kind',
            WebDavErrorKind.authentication,
          ),
        ),
      );
    } finally {
      await server.close(force: true);
    }
  });

  test('interprets resource and property failures inside HTTP 207', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final path = request.uri.path;
      request.response.statusCode = 207;
      request.response.headers.contentType = ContentType('application', 'xml');
      if (path.endsWith('/split/')) {
        request.response.write(
          _multiStatus([
            _response(path, 200, collection: true),
            '<d:response><d:href>${path}child/</d:href><d:propstat><d:prop><d:resourcetype><d:collection/></d:resourcetype></d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat><d:propstat><d:prop><d:getetag>"abc"</d:getetag></d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>',
          ]),
        );
      } else if (path.endsWith('/backups/')) {
        request.response.write(
          _multiStatus([
            _response(path, 200, collection: true),
            _response('${path}bad.json', 404),
          ]),
        );
      } else {
        request.response.write(
          _multiStatus([
            path.endsWith('mixed')
                ? '<d:response><d:href>$path</d:href><d:propstat><d:prop><d:resourcetype/></d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat><d:propstat><d:prop><d:getetag/></d:prop><d:status>HTTP/1.1 403 Forbidden</d:status></d:propstat></d:response>'
                : _response(path, path.endsWith('denied') ? 403 : 404),
          ]),
        );
      }
      await request.response.close();
    });
    try {
      final client = WebDavClient(
        WebDavConnection.fromFields(
          address: 'http://localhost:${server.port}',
          username: 'u',
          password: 'p',
        ),
      );
      expect(await client.exists('missing'), false);
      await expectLater(
        client.exists('denied'),
        throwsA(
          isA<WebDavException>().having(
            (e) => e.kind,
            'kind',
            WebDavErrorKind.authentication,
          ),
        ),
      );
      await expectLater(
        client.list('backups'),
        throwsA(
          isA<WebDavException>().having(
            (e) => e.kind,
            'kind',
            WebDavErrorKind.invalidResponse,
          ),
        ),
      );
      await expectLater(
        client.exists('mixed'),
        throwsA(
          isA<WebDavException>().having(
            (e) => e.kind,
            'kind',
            WebDavErrorKind.authentication,
          ),
        ),
      );
      final split = await client.list('split');
      expect(split, hasLength(1));
      expect(split.single.isCollection, true);
      expect(split.single.etag, '"abc"');
      client.close();
    } finally {
      await server.close(force: true);
    }
  });

  test('rejects mismatched 206, continues a short range, and overwrites on 200 or 416 fallback', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var fallbackRequests = 0;
    final shortRanges = <String?>[];
    server.listen((request) async {
      if (request.uri.path.endsWith('/bad')) {
        request.response.statusCode = 206;
        request.response.headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes 0-2/6',
        );
        request.response.write('abc');
      } else if (request.uri.path.endsWith('/shortRange')) {
        shortRanges.add(request.headers.value(HttpHeaders.rangeHeader));
        request.response.statusCode = 206;
        if (shortRanges.length == 1) {
          request.response.headers.set(
            HttpHeaders.contentRangeHeader,
            'bytes 3-4/6',
          );
          request.response.write('de');
        } else {
          request.response.headers.set(
            HttpHeaders.contentRangeHeader,
            'bytes 5-5/6',
          );
          request.response.write('f');
        }
      } else if (request.uri.path.endsWith('/full')) {
        request.response.statusCode = 200;
        request.response.write('xyz');
      } else {
        fallbackRequests++;
        if (fallbackRequests == 1) {
          request.response.statusCode = 416;
          request.response.write('range invalid');
        } else {
          expect(request.headers.value(HttpHeaders.rangeHeader), isNull);
          request.response.statusCode = 200;
          request.response.write('new');
        }
      }
      await request.response.close();
    });
    final dir = await Directory.systemTemp.createTemp('webdav-range-test-');
    try {
      final client = WebDavClient(
        WebDavConnection.fromFields(
          address: 'http://localhost:${server.port}',
          username: 'u',
          password: 'p',
        ),
      );
      final file = File('${dir.path}/file')..writeAsStringSync('abc');
      await expectLater(
        client.getFile('bad', file),
        throwsA(
          isA<WebDavException>().having(
            (e) => e.kind,
            'kind',
            WebDavErrorKind.invalidResponse,
          ),
        ),
      );
      expect(await file.readAsString(), 'abc');
      final progress = <(int, int)>[];
      expect(
        await client.getFile(
          'shortRange',
          file,
          onReceiveProgress: (received, total) =>
              progress.add((received, total)),
        ),
        sha256.convert(utf8.encode('abcdef')).toString(),
      );
      expect(shortRanges, ['bytes=3-', 'bytes=5-']);
      expect(progress.last, (3, 3));
      expect(progress.map((p) => p.$1), orderedEquals([2, 3]));
      expect(await file.readAsString(), 'abcdef');
      await client.getFile('full', file);
      expect(await file.readAsString(), 'xyz');
      await client.getFile('fallback', file);
      expect(fallbackRequests, 2);
      expect(await file.readAsString(), 'new');
      client.close();
    } finally {
      await server.close(force: true);
      await dir.delete(recursive: true);
    }
  });

  test(
    'preserves an interrupted prefix and returns a resumed stream hash',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      const bytes = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
      var requests = 0;
      server.listen((request) async {
        requests++;
        if (requests == 1) {
          final socket = await request.response.detachSocket(
            writeHeaders: false,
          );
          socket.write('HTTP/1.1 200 OK\r\nContent-Length: 10\r\n\r\n');
          socket.add(bytes.take(4).toList());
          await socket.flush();
          socket.destroy();
        } else {
          expect(request.headers.value(HttpHeaders.rangeHeader), 'bytes=4-');
          request.response.statusCode = 206;
          request.response.headers.set(
            HttpHeaders.contentRangeHeader,
            'bytes 4-9/10',
          );
          request.response.contentLength = 6;
          request.response.add(bytes.skip(4).toList());
          await request.response.close();
        }
      });
      final dir = await Directory.systemTemp.createTemp('webdav-range-test-');
      final client = WebDavClient(
        WebDavConnection.fromFields(
          address: 'http://localhost:${server.port}/',
          username: 'u',
          password: 'p',
        ),
      );
      final file = File('${dir.path}/object');
      try {
        await expectLater(
          client.getFile('objects/aa/file', file),
          throwsA(
            isA<WebDavException>()
                .having((error) => error.kind, 'kind', WebDavErrorKind.network)
                .having(
                  (error) => error.requestFailure!.method,
                  'method',
                  'GET',
                )
                .having((error) => error.requestFailure!.phase, 'phase', 'body')
                .having(
                  (error) => error.requestFailure!.causeType,
                  'cause',
                  'HttpException',
                ),
          ),
        );
        expect(await file.readAsBytes(), bytes.take(4).toList());
        expect(
          await client.getFile('objects/aa/file', file),
          sha256.convert(bytes).toString(),
        );
        expect(await file.readAsBytes(), bytes);
      } finally {
        client.close();
        await server.close(force: true);
        await dir.delete(recursive: true);
      }
    },
  );
}

String _multiStatus(List<String> responses) =>
    '<?xml version="1.0"?><d:multistatus xmlns:d="DAV:">${responses.join()}</d:multistatus>';
String _response(String href, int status, {bool collection = false}) =>
    '<d:response><d:href>$href</d:href><d:propstat><d:prop><d:resourcetype>${collection ? '<d:collection/>' : ''}</d:resourcetype></d:prop><d:status>HTTP/1.1 $status Status</d:status></d:propstat></d:response>';

String _xml(String self, String child) =>
    '''<?xml version="1.0"?><d:multistatus xmlns:d="DAV:">
<d:response><d:href>$self</d:href><d:propstat><d:prop><d:resourcetype><d:collection/></d:resourcetype></d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>
<d:response><d:href>$child</d:href><d:propstat><d:prop><d:resourcetype><d:collection/></d:resourcetype><d:getcontentlength>0</d:getcontentlength><d:getlastmodified>Sat, 14 Nov 2026 10:00:00 GMT</d:getlastmodified></d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>
</d:multistatus>''';

WebDavConnection _diagnosticConnection() => WebDavConnection.fromFields(
  address: 'https://example.test/dav',
  username: 'diagnostic-user',
  password: 'diagnostic-password',
);

class _SensitiveAdapterError {
  @override
  String toString() => 'Authorization: secret-header; body: secret-body';
}

class _TestAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions) respond;

  _TestAdapter(this.respond);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => respond(options);

  @override
  void close({bool force = false}) {}
}
