import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/service/webdav/webdav_transport.dart';

void main() {
  late _Origin origin;
  late _Proxy proxy;
  late WebDavTransport transport;
  late WebDavRoute route;

  setUp(() async {
    origin = await _Origin.start();
    proxy = await _Proxy.start();
    route = proxy.route;
    transport = WebDavTransport(
      route: () => route,
      badCertificateCallback: _acceptFixtureCertificate,
      securityContext: SecurityContext(withTrustedRoots: false)
        ..setTrustedCertificates('test/fixtures/webdav/localhost.cert.pem'),
    );
  });

  tearDown(() async {
    transport.close();
    await proxy.close();
    await origin.close();
  });

  Future<Response<dynamic>> head([Uri? uri]) => transport.requestUri<dynamic>(
    uri ?? origin.uri,
    options: Options(method: 'HEAD'),
  );

  test('authenticated fragmented CONNECT reuses one tunnel for HEAD and streaming PUT', () async {
    for (var i = 0; i < 5; i++) {
      expect((await head()).statusCode, HttpStatus.ok);
    }
    const length = 1024 * 1024;
    final sent = <int>[];
    await transport.requestUri<dynamic>(
      origin.uri,
      data: Stream<List<int>>.fromIterable(
        List.generate(16, (_) => Uint8List(length ~/ 16)),
      ),
      options: Options(
        method: 'PUT',
        headers: {
          HttpHeaders.contentLengthHeader: length,
          HttpHeaders.authorizationHeader: 'Basic server-account',
        },
      ),
      onSendProgress: (count, _) => sent.add(count),
    );
    expect(proxy.connects, 1);
    expect(proxy.authorizations, [proxy.authorization]);
    expect(origin.ports.length, 1);
    expect(origin.received, length);
    expect(origin.authorizations.last, 'Basic server-account');
    expect(origin.authorizations, isNot(contains(proxy.authorization)));
    expect(sent.last, length);
  });

  test(
    'target origins own separate tunnels and server close rebuilds one',
    () async {
      final other = await _Origin.start();
      try {
        await head();
        await head(other.uri);
        await head();
        expect(proxy.connects, 2);
        await head(origin.uri.resolve('/close'));
        await head();
        expect(proxy.connects, 3);
        expect(other.ports.length, 1);
      } finally {
        await other.close();
      }
    },
  );

  test(
    'route snapshots retain an active response until consumption finishes',
    () async {
      final response = await transport.requestUri<ResponseBody>(
        origin.uri.resolve('/stream'),
        options: Options(responseType: ResponseType.stream),
      );
      final received = <int>[];
      final finished = Completer<void>();
      final subscription = response.data!.stream.listen(
        received.addAll,
        onError: finished.completeError,
        onDone: finished.complete,
      );
      await origin.streamStarted.future;
      subscription.pause();
      final replacement = await _Proxy.start();
      try {
        route = replacement.route;
        await head();
        expect(proxy.connects, 1);
        expect(replacement.connects, 1);
        expect(proxy.active, 1);
        origin.finishStream.complete();
        subscription.resume();
        await finished.future;
        expect(utf8.decode(received), 'firstlast');
        await _eventually(() => proxy.active == 0);
        expect(replacement.active, 1);
      } finally {
        await replacement.close();
      }
    },
  );

  test('cancelled response consumption releases a retired route', () async {
    final response = await transport.requestUri<ResponseBody>(
      origin.uri.resolve('/stream'),
      options: Options(responseType: ResponseType.stream),
    );
    final subscription = response.data!.stream.listen((_) {});
    await origin.streamStarted.future;
    route = const WebDavRoute(type: WebDavProxyType.direct);
    await head();
    await subscription.cancel();
    origin.finishStream.complete();
    await _eventually(() => proxy.active == 0);
  });

  test('changing only proxy credentials selects a fresh route pool', () async {
    await head();
    proxy.username = 'replacement-user';
    proxy.password = 'replacement-password';
    route = proxy.route;
    await head();
    expect(proxy.connects, 2);
    expect(proxy.authorizations.toSet().length, 2);
    expect(origin.ports.length, 2);
    await _eventually(() => proxy.active == 1);
  });

  test(
    'HTTP requests retain the existing forward proxy path and authentication',
    () async {
      final target = Uri.parse('http://unresolved.test/webdav');
      await head(target);
      await head(target);
      expect(proxy.connects, 0);
      expect(proxy.forwards, [target, target]);
      expect(proxy.authorizations, [proxy.authorization, proxy.authorization]);
      expect(origin.requests, 0);
    },
  );

  for (final type in [WebDavProxyType.socks4, WebDavProxyType.socks5]) {
    test('${type.name} HTTPS retains its existing adapter path', () async {
      final socks = await _SocksProxy.start(type);
      try {
        route = socks.route;
        await head();
        expect(socks.connections, 1);
        expect(socks.destinations, [origin.uri.port]);
        expect(origin.requests, 1);
        expect(proxy.connects, 0);
      } finally {
        await socks.close();
      }
    });
  }

  test(
    'CONNECT auth rejection and proxy failure fall back to DIRECT',
    () async {
      route = WebDavRoute(
        type: WebDavProxyType.http,
        address: proxy.route.address,
        username: 'wrong',
        password: 'wrong',
      );
      await head();
      expect(proxy.connects, 1);
      expect(proxy.accepted, 0);
      expect(origin.ports.length, 1);
      // A refused proxy connection also falls back, on a fresh route pool.
      final unused = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = unused.port;
      await unused.close();
      route = WebDavRoute(
        type: WebDavProxyType.http,
        address: '127.0.0.1:$port',
      );
      await head();
      expect(origin.requests, 2);
    },
  );

  test(
    'system proxy snapshot and explicit direct keep their route semantics',
    () async {
      proxy.requireAuthorization = false;
      route = WebDavRoute(
        type: WebDavProxyType.system,
        systemAddress: proxy.route.address,
      );
      await head();
      await head();
      expect(proxy.connects, 1);
      expect(proxy.authorizations.single, isNull);
      route = const WebDavRoute(type: WebDavProxyType.system);
      await head();
      route = const WebDavRoute(type: WebDavProxyType.direct);
      await head();
      expect(proxy.connects, 1);
    },
  );

  test(
    'cancelling a CONNECT leaves concurrent sibling requests usable',
    () async {
      proxy.stallNext = true;
      final cancel = CancelToken();
      final pending = transport.requestUri<dynamic>(
        origin.uri,
        options: Options(method: 'HEAD'),
        cancelToken: cancel,
      );
      final failure = expectLater(pending, throwsA(isA<DioException>()));
      await proxy.stalled.future;
      await head();
      expect(proxy.connects, 2);
      cancel.cancel('cancel only the connecting operation');
      await failure;
      await _eventually(() => proxy.active == 1);
      await head();
      expect(proxy.connects, 2);
      expect(origin.requests, 2);
    },
  );

  test(
    'CONNECT timeout releases its socket and the client can reconnect',
    () async {
      transport.close();
      transport = WebDavTransport(
        route: () => route,
        badCertificateCallback: _acceptFixtureCertificate,
        connectTimeout: const Duration(milliseconds: 150),
        securityContext: SecurityContext(withTrustedRoots: false)
          ..setTrustedCertificates('test/fixtures/webdav/localhost.cert.pem'),
      );
      proxy.stallNext = true;
      await expectLater(
        head(),
        throwsA(
          isA<DioException>().having(
            (e) => e.type,
            'type',
            DioExceptionType.connectionTimeout,
          ),
        ),
      );
      await _eventually(() => proxy.active == 0);
      await head();
      expect(proxy.connects, 2);
    },
  );
}

bool _acceptFixtureCertificate(
  X509Certificate certificate,
  String host,
  int port,
) =>
    host == 'localhost' &&
    certificate.pem ==
        File('test/fixtures/webdav/localhost.cert.pem').readAsStringSync();

Future<void> _eventually(bool Function() condition) async {
  final watch = Stopwatch()..start();
  while (!condition()) {
    if (watch.elapsed > const Duration(seconds: 3)) {
      fail('Timed out waiting for socket ownership change');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

class _Origin {
  final HttpServer server;
  final ports = <int>{};
  final authorizations = <String?>[];
  final streamStarted = Completer<void>();
  final finishStream = Completer<void>();
  int requests = 0;
  int received = 0;

  _Origin(this.server) {
    server.listen((request) async {
      requests++;
      ports.add(request.connectionInfo!.remotePort);
      authorizations.add(
        request.headers.value(HttpHeaders.authorizationHeader),
      );
      await for (final chunk in request) {
        received += chunk.length;
      }
      if (request.uri.path == '/stream') {
        request.response.add(utf8.encode('first'));
        await request.response.flush();
        streamStarted.complete();
        await finishStream.future;
        request.response.add(utf8.encode('last'));
      }
      if (request.uri.path == '/close') {
        request.response.persistentConnection = false;
      }
      await request.response.close();
    });
  }

  Uri get uri =>
      Uri(scheme: 'https', host: 'localhost', port: server.port, path: '/');

  static Future<_Origin> start() async {
    final context = SecurityContext()
      ..useCertificateChain('test/fixtures/webdav/localhost.cert.pem')
      ..usePrivateKey('test/fixtures/webdav/localhost.key.pem');
    return _Origin(
      await HttpServer.bindSecure(InternetAddress.loopbackIPv4, 0, context),
    );
  }

  Future<void> close() async {
    if (!finishStream.isCompleted) {
      finishStream.complete();
    }
    await server.close(force: true);
  }
}

/// The SDK parses inbound CONNECT. Successful replies are deliberately split
/// across writes, so production relies on SDK parsing rather than chunk layout.
class _Proxy {
  final HttpServer server;
  final sockets = <Socket>{};
  final authorizations = <String?>[];
  final forwards = <Uri>[];
  String username = 'proxy-user';
  String password = 'proxy-secret';
  final stalled = Completer<void>();
  int connects = 0;
  int accepted = 0;
  int active = 0;
  bool requireAuthorization = true;
  bool stallNext = false;

  _Proxy(this.server) {
    server.listen((request) async {
      final auth = request.headers.value(HttpHeaders.proxyAuthorizationHeader);
      authorizations.add(auth);
      if (request.method != 'CONNECT') {
        forwards.add(request.uri);
        expect(auth, authorization);
        await request.response.close();
        return;
      }
      connects++;
      expect(request.uri.toString(), 'localhost:${request.headers.port}');
      if (requireAuthorization && auth != authorization) {
        request.response.statusCode = HttpStatus.proxyAuthenticationRequired;
        request.response.headers.set(
          HttpHeaders.proxyAuthenticateHeader,
          'Basic realm="fixture"',
        );
        request.response.persistentConnection = false;
        await request.response.close();
        return;
      }
      accepted++;
      final socket = await request.response.detachSocket(writeHeaders: false);
      sockets.add(socket);
      active++;
      Socket? upstream;
      var ended = false;
      void finish() {
        if (ended) {
          return;
        }
        ended = true;
        active--;
        sockets.remove(socket);
        socket.destroy();
        upstream?.destroy();
      }

      if (stallNext) {
        stallNext = false;
        socket.listen((_) {}, onDone: finish, onError: (_) => finish());
        stalled.complete();
        return;
      }
      upstream = await Socket.connect(
        InternetAddress.loopbackIPv4,
        request.headers.port!,
      );
      sockets.add(upstream);
      socket.write('HTTP/1.1 200 Connection');
      await socket.flush();
      await Future<void>.delayed(const Duration(milliseconds: 1));
      socket.write(' established\r\nX-Fragmented: true\r\n\r\n');
      await socket.flush();
      socket.listen(upstream.add, onDone: finish, onError: (_) => finish());
      upstream.listen(socket.add, onDone: finish, onError: (_) => finish());
    });
  }

  String get authorization =>
      'Basic ${base64Encode(utf8.encode('$username:$password'))}';

  WebDavRoute get route => WebDavRoute(
    type: WebDavProxyType.http,
    address: '127.0.0.1:${server.port}',
    username: username,
    password: password,
  );

  static Future<_Proxy> start() async =>
      _Proxy(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));

  Future<void> close() async {
    for (final socket in sockets.toList()) {
      socket.destroy();
    }
    await server.close(force: true);
  }
}

class _SocketReader {
  final StreamIterator<Uint8List> iterator;
  final List<int> buffered = [];

  _SocketReader(Socket socket) : iterator = StreamIterator(socket);

  Future<List<int>> read(int length) async {
    while (buffered.length < length) {
      if (!await iterator.moveNext()) {
        throw const SocketException('SOCKS fixture connection ended');
      }
      buffered.addAll(iterator.current);
    }
    final bytes = buffered.sublist(0, length);
    buffered.removeRange(0, length);
    return bytes;
  }

  Future<void> readTerminated() async {
    while ((await read(1)).single != 0) {}
  }

  Future<void> forward(Socket destination) async {
    destination.add(buffered);
    buffered.clear();
    while (await iterator.moveNext()) {
      destination.add(iterator.current);
    }
  }
}

class _SocksProxy {
  final ServerSocket server;
  final WebDavProxyType type;
  final sockets = <Socket>{};
  final destinations = <int>[];
  int connections = 0;

  _SocksProxy(this.server, this.type) {
    server.listen((socket) async {
      sockets.add(socket);
      connections++;
      Socket? upstream;
      try {
        final reader = _SocketReader(socket);
        int port;
        if (type == WebDavProxyType.socks4) {
          final header = await reader.read(8);
          expect(header.take(2), [4, 1]);
          port = header[2] * 256 + header[3];
          await reader.readTerminated(); // userid
          await reader.readTerminated(); // SOCKS4a hostname
          socket.add([0, 90, 0, 0, 0, 0, 0, 0]);
        } else {
          final greeting = await reader.read(2);
          expect(greeting.first, 5);
          expect(await reader.read(greeting.last), contains(2));
          socket.add([5, 2]);
          final auth = await reader.read(2);
          expect(auth.first, 1);
          expect(utf8.decode(await reader.read(auth.last)), 'socks-user');
          final passwordLength = (await reader.read(1)).single;
          expect(
            utf8.decode(await reader.read(passwordLength)),
            'socks-secret',
          );
          socket.add([1, 0]);
          final request = await reader.read(4);
          expect(request, [5, 1, 0, 3]);
          final hostLength = (await reader.read(1)).single;
          expect(utf8.decode(await reader.read(hostLength)), 'localhost');
          final portBytes = await reader.read(2);
          port = portBytes[0] * 256 + portBytes[1];
          socket.add([5, 0, 0, 1, 127, 0, 0, 1, 0, 0]);
        }
        destinations.add(port);
        upstream = await Socket.connect(InternetAddress.loopbackIPv4, port);
        sockets.add(upstream);
        upstream.listen(
          socket.add,
          onDone: socket.destroy,
          onError: (_) => socket.destroy(),
        );
        await reader.forward(upstream);
      } on SocketException {
        // Transport and fixture teardown can close either half first.
      } finally {
        socket.destroy();
        upstream?.destroy();
      }
    });
  }

  WebDavRoute get route => WebDavRoute(
    type: type,
    address: '127.0.0.1:${server.port}',
    username: type == WebDavProxyType.socks5 ? 'socks-user' : null,
    password: type == WebDavProxyType.socks5 ? 'socks-secret' : null,
  );

  static Future<_SocksProxy> start(WebDavProxyType type) async => _SocksProxy(
    await ServerSocket.bind(InternetAddress.loopbackIPv4, 0),
    type,
  );

  Future<void> close() async {
    for (final socket in sockets) {
      socket.destroy();
    }
    await server.close();
  }
}
