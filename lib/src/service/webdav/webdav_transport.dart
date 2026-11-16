import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_socks_proxy/socks_proxy.dart';

enum WebDavProxyType { system, http, socks5, socks4, direct }

/// Everything that can change the route belongs to the pool identity. Account
/// credentials and WebDAV paths remain request properties.
class WebDavRoute {
  final WebDavProxyType type;
  final String address;
  final String? username;
  final String? password;
  final String systemAddress;

  const WebDavRoute({
    required this.type,
    this.address = '',
    this.username,
    this.password,
    this.systemAddress = '',
  });

  // The application's network lifecycle installs readers after system proxy
  // discovery. Keeping the transport independent also permits local clients.
  static WebDavRoute Function() readCurrent = () =>
      const WebDavRoute(type: WebDavProxyType.direct);
  static bool Function(X509Certificate, String, int) acceptBadCertificate = (
    _,
    __,
    ___,
  ) => false;

  factory WebDavRoute.current() => readCurrent();

  String? get httpAddress => switch (type) {
    WebDavProxyType.http => address,
    WebDavProxyType.system when systemAddress.trim().isNotEmpty =>
      systemAddress,
    _ => null,
  };

  String get proxyConfiguration {
    if (type == WebDavProxyType.direct ||
        (type == WebDavProxyType.system && httpAddress == null)) {
      return 'DIRECT';
    }
    final credentials =
        type != WebDavProxyType.system &&
            ((username?.trim().isNotEmpty ?? false) ||
                (password?.trim().isNotEmpty ?? false))
        ? '${username ?? ''}:${password ?? ''}@'
        : '';
    final prefix = switch (type) {
      WebDavProxyType.socks4 => 'SOCKS4',
      WebDavProxyType.socks5 => 'SOCKS5',
      _ => 'PROXY',
    };
    return '$prefix $credentials${httpAddress ?? address}; DIRECT';
  }

  @override
  bool operator ==(Object other) =>
      other is WebDavRoute &&
      type == other.type &&
      address == other.address &&
      username == other.username &&
      password == other.password &&
      systemAddress == other.systemAddress;

  @override
  int get hashCode =>
      Object.hash(type, address, username, password, systemAddress);
}

/// A request holds its route until completion, including streamed response
/// consumption. Replacing settings retires only the previous pool.
class WebDavTransport {
  final WebDavRoute Function() route;
  final SecurityContext? securityContext;
  final bool Function(X509Certificate, String, int)? badCertificateCallback;
  final Duration connectTimeout;
  final Duration receiveTimeout;
  _RoutePool? _current;
  bool _closed = false;

  WebDavTransport({
    WebDavRoute Function()? route,
    this.securityContext,
    this.badCertificateCallback,
    this.connectTimeout = const Duration(seconds: 15),
    this.receiveTimeout = const Duration(seconds: 60),
  }) : route = route ?? WebDavRoute.current;

  Future<Response<T>> requestUri<T>(
    Uri uri, {
    Object? data,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
  }) async {
    if (_closed) {
      throw StateError('WebDAV transport is closed');
    }
    final snapshot = route();
    var pool = _current;
    if (pool == null || pool.route != snapshot) {
      pool?.retire();
      pool = _RoutePool(this, snapshot);
      _current = pool;
    }
    pool.holds++;
    var released = false;
    void release() {
      if (released) {
        return;
      }
      released = true;
      pool!.release();
    }

    try {
      final response = await pool.dio.requestUri<T>(
        uri,
        data: data,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
      );
      final body = response.data;
      if (body is ResponseBody) {
        body.stream = _heldStream(body.stream, release);
      } else {
        release();
      }
      return response;
    } catch (_) {
      release();
      rethrow;
    }
  }

  static Stream<Uint8List> _heldStream(
    Stream<Uint8List> source,
    void Function() release,
  ) {
    // StreamController preserves cancellation (including a consumer that stops
    // early), unlike an onDone-only transformer.
    late StreamSubscription<Uint8List> subscription;
    late StreamController<Uint8List> controller;
    controller = StreamController<Uint8List>(
      onListen: () {
        subscription = source.listen(
          controller.add,
          onError: (Object error, StackTrace stack) {
            controller.addError(error, stack);
            release();
          },
          onDone: () {
            release();
            controller.close();
          },
        );
      },
      onPause: () => subscription.pause(),
      onResume: () => subscription.resume(),
      onCancel: () async {
        try {
          await subscription.cancel();
        } finally {
          release();
        }
      },
    );
    return controller.stream;
  }

  void close() {
    _closed = true;
    _current?.retire();
    _current = null;
  }
}

class _RoutePool {
  final WebDavRoute route;
  late final Dio dio;
  int holds = 0;
  bool retired = false;

  _RoutePool(WebDavTransport owner, this.route) {
    dio = Dio(
      BaseOptions(
        connectTimeout: owner.connectTimeout,
        receiveTimeout: owner.receiveTimeout,
      ),
    )..httpClientAdapter = _RouteAdapter(owner, route);
  }

  void retire() {
    retired = true;
    if (holds == 0) {
      dio.close();
    }
  }

  void release() {
    holds--;
    if (retired && holds == 0) {
      dio.close();
    }
  }
}

// Bypass the application's global SOCKS HttpOverrides only for the SDK outer
// target pool and CONNECT helper. Other routes retain the installed adapter.
class _SdkOverrides extends HttpOverrides {}

final _sdkOverrides = _SdkOverrides();
HttpClient _sdkClient(SecurityContext? context) =>
    _sdkOverrides.createHttpClient(context);

final _connectionScopeKey = Object();

class _RouteAdapter implements HttpClientAdapter {
  final IOHttpClientAdapter legacy;
  final IOHttpClientAdapter? tunneled;

  _RouteAdapter(WebDavTransport owner, WebDavRoute route)
    : legacy = IOHttpClientAdapter(
        createHttpClient: () {
          return createProxyHttpClient(context: owner.securityContext)
            ..findProxy = ((_) => route.proxyConfiguration)
            ..badCertificateCallback =
                owner.badCertificateCallback ??
                WebDavRoute.acceptBadCertificate;
        },
      ),
      tunneled = route.httpAddress == null
          ? null
          : IOHttpClientAdapter(
              createHttpClient: () {
                final client = _sdkClient(owner.securityContext)
                  ..findProxy = ((_) => 'DIRECT');
                client.connectionFactory = (uri, _, __) async {
                  final scope =
                      Zone.current[_connectionScopeKey] as _ConnectionScope;
                  final attempt = _TunnelAttempt(owner, route, uri, scope);
                  scope.pending.add(attempt);
                  return ConnectionTask.fromSocket(
                    attempt.connect(),
                    attempt.cancel,
                  );
                };
                return client;
              },
            );

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    final adapter = options.uri.scheme == 'https' ? tunneled ?? legacy : legacy;
    final scope = _ConnectionScope();
    cancelFuture?.then((_) => scope.cancel());
    try {
      return await runZoned(
        () => adapter.fetch(options, stream, cancelFuture),
        zoneValues: {_connectionScopeKey: scope},
      );
    } finally {
      scope.cancel();
    }
  }

  @override
  void close({bool force = false}) {
    legacy.close(force: force);
    tunneled?.close(force: force);
  }
}

class _ConnectionScope {
  final pending = <_TunnelAttempt>{};
  bool cancelled = false;

  void cancel() {
    cancelled = true;
    for (final attempt in pending.toList()) {
      attempt.cancel();
    }
  }
}

class _TunnelAttempt {
  final WebDavTransport owner;
  final WebDavRoute route;
  final Uri target;
  final _ConnectionScope scope;
  HttpClient? helper;
  ConnectionTask<Socket>? connecting;
  Socket? raw;
  SecureSocket? tls;
  bool cancelled = false;
  bool transferred = false;

  _TunnelAttempt(this.owner, this.route, this.target, this.scope);

  void checkCancelled() {
    if (cancelled || scope.cancelled) {
      throw const SocketException('WebDAV connection cancelled');
    }
  }

  void cancel() {
    if (transferred) {
      return;
    }
    cancelled = true;
    connecting?.cancel();
    helper?.close(force: true);
    raw?.destroy();
    tls?.destroy();
  }

  Future<Socket> connect() async {
    try {
      checkCancelled();
      try {
        final proxy = Uri.parse('http://${route.httpAddress}');
        if (proxy.host.isEmpty || !proxy.hasPort) {
          throw const HttpException('Invalid HTTP proxy address');
        }
        helper = _sdkClient(null)
          ..findProxy = ((_) => route.proxyConfiguration.split(';').first)
          ..connectionTimeout = owner.connectTimeout;
        helper!.connectionFactory = (_, __, ___) async {
          checkCancelled();
          connecting = await Socket.startConnect(proxy.host, proxy.port);
          checkCancelled();
          raw = await connecting!.socket;
          checkCancelled();
          return ConnectionTask.fromSocket(Future.value(raw!), cancel);
        };
        // HTTP here prevents the helper from building its own implicit TLS
        // tunnel; SDK proxy mode still serializes the CONNECT authority.
        final request = await helper!.openUrl(
          'CONNECT',
          target.replace(scheme: 'http', port: target.port),
        );
        final response = await request.close();
        if (response.statusCode != HttpStatus.ok) {
          throw HttpException(
            'Proxy failed to establish tunnel '
            '(${response.statusCode} ${response.reasonPhrase})',
          );
        }
        // detachSocket completes the SDK ownership transfer. Its wrapper cannot
        // be secured on this SDK; use the factory's original Socket instead.
        await response.detachSocket();
        helper!.close();
        helper = null;
        checkCancelled();
        tls = await SecureSocket.secure(
          raw!,
          host: target.host,
          context: owner.securityContext,
          onBadCertificate: (certificate) =>
              owner.badCertificateCallback?.call(
                certificate,
                target.host,
                target.port,
              ) ??
              WebDavRoute.acceptBadCertificate(
                certificate,
                target.host,
                target.port,
              ),
        );
        checkCancelled();
      } on Exception {
        // Match the existing `PROXY ...; DIRECT` order, including failures
        // during CONNECT authentication or TLS negotiation.
        helper?.close(force: true);
        helper = null;
        raw?.destroy();
        tls?.destroy();
        checkCancelled();
        connecting = await SecureSocket.startConnect(
          target.host,
          target.port,
          context: owner.securityContext,
          onBadCertificate: (certificate) =>
              owner.badCertificateCallback?.call(
                certificate,
                target.host,
                target.port,
              ) ??
              WebDavRoute.acceptBadCertificate(
                certificate,
                target.host,
                target.port,
              ),
        );
        checkCancelled();
        tls = await connecting!.socket as SecureSocket;
        checkCancelled();
      }
      transferred = true;
      return tls!;
    } finally {
      scope.pending.remove(this);
      if (!transferred) {
        cancel();
      }
    }
  }
}
