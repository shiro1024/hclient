import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/enum/config_enum.dart';
import 'package:jhentai/src/service/content_sync/content_repository.dart';
import 'package:jhentai/src/service/local_backup_service.dart';
import 'package:jhentai/src/service/local_config_service.dart';
import 'package:jhentai/src/service/path_service.dart';
import 'package:jhentai/src/service/webdav/webdav_backup_service.dart';
import 'package:jhentai/src/service/webdav/webdav_client.dart';
import 'package:jhentai/src/setting/webdav_setting.dart';

void main() {
  test(
    'automatic sync belongs to the namespace and password changes preserve it',
    () async {
      final previous = localConfigService;
      addTearDown(() => localConfigService = previous);
      final setting = WebDavSetting();
      setting.applyBeanConfig(
        jsonEncode({
          'address': 'https://example.org/dav',
          'username': 'u',
          'password': 'old',
          'rootPath': 'books',
        }),
      );
      expect(setting.autoSync.value, isFalse);
      Future<void> save({
        String username = 'u',
        String password = 'new',
        String root = 'books',
      }) async {
        final storage = _PendingConfigService();
        localConfigService = storage;
        final pending = setting.save(
          address: 'https://example.org/dav/',
          username: username,
          password: password,
          rootPath: root,
        );
        storage.completion.complete(1);
        await pending;
      }

      setting.autoSync.value = true;
      await save();
      expect(setting.autoSync.value, isTrue);
      expect(jsonDecode(setting.toConfigString())['autoSync'], isTrue);
      await save(root: 'another');
      expect(setting.autoSync.value, isFalse);
      setting.autoSync.value = true;
      await save(username: 'another', root: 'another');
      expect(setting.autoSync.value, isFalse);
    },
  );

  test(
    'WebDAV save keeps the current connection when persistence fails',
    () async {
      final previousConfigService = localConfigService;
      final storage = _PendingConfigService();
      localConfigService = storage;
      addTearDown(() => localConfigService = previousConfigService);
      final setting = WebDavSetting();
      final oldConfig = jsonEncode({
        'address': 'https://old.example/dav',
        'username': 'old-user',
        'password': 'old-password',
        'rootPath': 'old-root',
        'autoSync': false,
      });
      setting.applyBeanConfig(oldConfig);
      final oldNamespace = setting.connection.namespace;
      final pending = setting.save(
        address: ' https://NEW.example/dav/ ',
        username: 'new-user',
        password: 'new-password',
        rootPath: '/new root//books/',
      );
      expect(storage.configKey, ConfigEnum.webdavSetting);
      expect(setting.toConfigString(), oldConfig);
      expect(setting.connection.namespace, oldNamespace);
      final failure = FileSystemException('Configuration write failed');
      final failedSave = expectLater(pending, throwsA(same(failure)));
      storage.completion.completeError(failure);
      await failedSave;
      expect(setting.toConfigString(), oldConfig);
      expect(setting.connection.namespace, oldNamespace);
    },
  );

  test(
    'WebDAV save publishes normalized values only after persistence succeeds',
    () async {
      final previousConfigService = localConfigService;
      final storage = _PendingConfigService();
      localConfigService = storage;
      addTearDown(() => localConfigService = previousConfigService);
      final setting = WebDavSetting();
      setting.applyBeanConfig(
        jsonEncode({
          'address': 'https://old.example/dav',
          'username': 'old-user',
          'password': 'old-password',
          'rootPath': 'old-root',
        }),
      );
      final oldConfig = setting.toConfigString();
      final pending = setting.save(
        address: ' https://NEW.example/dav/ ',
        username: 'new-user',
        password: 'new-password',
        rootPath: '/new root//books/',
      );
      final expected = {
        'address': 'https://new.example/dav',
        'username': 'new-user',
        'password': 'new-password',
        'rootPath': 'new root/books',
        'autoSync': false,
      };
      expect(storage.configKey, ConfigEnum.webdavSetting);
      expect(jsonDecode(storage.value!), expected);
      await Future<void>.delayed(Duration.zero);
      expect(setting.toConfigString(), oldConfig);
      storage.completion.complete(1);
      await pending;
      expect(jsonDecode(setting.toConfigString()), expected);
      expect(
        setting.connection.namespace,
        'https://new.example/dav/new%20root/books|new-user',
      );
    },
  );

  test('backup keeps fixed artifact after failure and resumes into an immutable remote snapshot', () async {
    final home = await Directory.systemTemp.createTemp('webdav-backup-test-');
    pathService.appDocDir = home;
    pathService.appSupportDir = home;
    pathService.tempDir = home;
    appDb = AppDb();
    final server = await _DavServer.start();
    final service = WebDavBackupService();
    try {
      await service.doInitBean();
      await webDavSetting.save(
        address: 'http://localhost:${server.server.port}/v1/dav/sync/',
        username: 'u',
        password: 'p',
        rootPath: 'my root',
      );
      await localConfigService.write(
        configKey: ConfigEnum.preferenceSetting,
        value: jsonEncode({'test': 1}),
      );
      server.failPut = true;
      await expectLater(
        service.createBackup(
          const LocalBackupSelection(
            dataTypes: [],
            login: false,
            settings: true,
            settingUnits: {ConfigEnum.preferenceSetting},
            groups: false,
            archives: false,
          ),
        ),
        throwsA(anything),
      );
      final pending = await ContentRepository(appDb)
          .listWorkItems(kind: 'backup');
      expect(pending, hasLength(1));
      expect(pending.single.state, 'failed');
      final artifactBytes = await File(pending.single.localArtifactPath!)
          .readAsBytes();
      server.failPut = false;
      await service.resumePending();
      expect(
        (await ContentRepository(appDb).getWorkItem(pending.single.workItemId))!
            .state,
        'completed',
      );
      expect(
        await File(pending.single.localArtifactPath!).readAsBytes(),
        artifactBytes,
      );
      final snapshots = await service.listBackups();
      expect(snapshots, hasLength(1));
      final contents = await service.downloadBackup(snapshots.single);
      expect(jsonDecode(contents)['version'], 2);
      expect(server.moves, 1);
      await service.resumePending();
      expect(server.moves, 1);
    } finally {
      await server.server.close(force: true);
      await appDb.close();
      await home.delete(recursive: true);
    }
  });

  test(
    'two device homes append independently and retain both snapshots',
    () async {
      final home = await Directory.systemTemp.createTemp(
        'webdav-devices-test-',
      );
      final server = await _DavServer.start();
      final previousSetting = webDavSetting.toConfigString();
      final services = <WebDavBackupService>[];
      final snapshots = <WebDavBackupSnapshot>[];
      final contents = <String>[];
      AppDb? database;
      try {
        webDavSetting.applyBeanConfig(
          jsonEncode({
            'address': 'http://localhost:${server.server.port}/v1/dav/sync/',
            'username': 'u',
            'password': 'p',
            'rootPath': '',
          }),
        );
        for (var device = 0; device < 2; device++) {
          final deviceHome = Directory('${home.path}/device-$device');
          await deviceHome.create();
          pathService.appDocDir = deviceHome;
          pathService.appSupportDir = deviceHome;
          pathService.tempDir = deviceHome;
          appDb = database = AppDb();
          final service = WebDavBackupService();
          await service.doInitBean();
          services.add(service);
          await localConfigService.write(
            configKey: ConfigEnum.preferenceSetting,
            value: jsonEncode({'device': device}),
          );
          final snapshot = await service.createBackup(
            const LocalBackupSelection(
              dataTypes: [],
              login: false,
              groups: false,
              archives: false,
              settingUnits: {ConfigEnum.preferenceSetting},
            ),
          );
          snapshots.add(snapshot);
          contents.add(await service.downloadBackup(snapshot));
          final settings =
              (jsonDecode(contents.last) as Map)['settings'] as List;
          expect(jsonDecode((settings.single as Map)['value'] as String), {
            'device': device,
          });
          // Reopening this home must retain its identity before the next device starts.
          final reopened = WebDavBackupService();
          await reopened.doInitBean();
          expect(reopened.deviceId, service.deviceId);
          await database.close();
          database = null;
        }
        expect(
          services.map((service) => service.deviceId).toSet(),
          hasLength(2),
        );
        expect(
          snapshots.map((snapshot) => snapshot.remotePath).toSet(),
          hasLength(2),
        );
        expect(contents[0], isNot(contents[1]));
        for (final service in services) {
          final listed = await service.listBackups();
          expect(
            listed.map((snapshot) => snapshot.remotePath),
            unorderedEquals(snapshots.map((snapshot) => snapshot.remotePath)),
          );
          for (var device = 0; device < 2; device++) {
            final snapshot = listed.singleWhere(
              (snapshot) => snapshot.deviceId == services[device].deviceId,
            );
            expect(await service.downloadBackup(snapshot), contents[device]);
          }
        }
        expect(server.moves, 2);
        expect(server.puts, 2);
      } finally {
        webDavSetting.applyBeanConfig(previousSetting);
        await database?.close();
        await server.server.close(force: true);
        await home.delete(recursive: true);
      }
    },
  );

  test('concurrent resume shares one in-flight backup work item', () async {
    final home = await Directory.systemTemp.createTemp(
      'webdav-concurrent-test-',
    );
    pathService.appDocDir = home;
    pathService.appSupportDir = home;
    pathService.tempDir = home;
    appDb = AppDb();
    final server = await _DavServer.start();
    final service = WebDavBackupService();
    server.moveStarted = Completer<void>();
    server.moveGate = Completer<void>();
    try {
      await service.doInitBean();
      await webDavSetting.save(
        address: 'http://localhost:${server.server.port}/v1/dav/sync/',
        username: 'u',
        password: 'p',
        rootPath: '',
      );
      await localConfigService.write(
        configKey: ConfigEnum.preferenceSetting,
        value: jsonEncode({'test': 2}),
      );
      final backup = service.createBackup(
        const LocalBackupSelection(
          login: false,
          groups: false,
          settingUnits: {ConfigEnum.preferenceSetting},
        ),
      );
      await server.moveStarted!.future;
      final resume = service.resumePending();
      server.moveGate!.complete();
      await Future.wait([backup, resume]);
      final items = await ContentRepository(appDb)
          .listWorkItems(kind: 'backup', includeFinished: true);
      expect(items, hasLength(1));
      expect(items.single.state, 'completed');
      expect(server.puts, 1);
      expect(server.moves, 1);
    } finally {
      await server.server.close(force: true);
      await appDb.close();
      await home.delete(recursive: true);
    }
  });

  test('backup listing rejects a missing child in HTTP 207 instead of reporting no backups', () async {
    final server = await _DavServer.start();
    final previousSetting = webDavSetting.toConfigString();
    server.badChildListing = true;
    try {
      webDavSetting.applyBeanConfig(
        jsonEncode({
          'address': 'http://localhost:${server.server.port}/v1/dav/sync/',
          'username': 'u',
          'password': 'p',
          'rootPath': '',
        }),
      );
      await expectLater(
        WebDavBackupService().listBackups(),
        throwsA(
          isA<WebDavException>().having(
            (e) => e.kind,
            'kind',
            WebDavErrorKind.invalidResponse,
          ),
        ),
      );
    } finally {
      webDavSetting.applyBeanConfig(previousSetting);
      await server.server.close(force: true);
    }
  });

  test('backup restore resumes an interrupted HTTP body and removes its artifact after import', () async {
    await _withDownloadFixture((home, server, service) async {
      final contents = jsonEncode({
        'format': 'hclient-local-backup',
        'version': 2,
        'units': {
          'settings': [ConfigEnum.preferenceSetting.key],
          'login': false,
          'dataTypes': [],
          'botCredential': false,
          'proxyCredential': false,
          'groups': false,
        },
        'settings': [
          {
            'configKey': ConfigEnum.preferenceSetting.key,
            'subConfigKey': '',
            'value': jsonEncode({'restored': List.filled(8192, 'value')}),
            'utime': '2026-11-15T00:00:00.000Z',
          },
        ],
      });
      final snapshot = server.addSnapshot(utf8.encode(contents));
      server.interruptNextGetAfter = 1024;
      await expectLater(service.restoreBackup(snapshot), throwsA(anything));
      final partials = await _restoreArtifacts(home);
      expect(partials, hasLength(1));
      final offset = await partials.single.length();
      expect(offset, 1024);

      final result = await service.restoreBackup(snapshot);
      expect(result.legacy, isFalse);
      expect(result.needsRestart, isTrue);
      final stored = await localConfigService.read(
        configKey: ConfigEnum.preferenceSetting,
      );
      expect(jsonDecode(stored!)['restored'], hasLength(8192));
      expect(server.getRanges, [null, 'bytes=$offset-']);
      expect(server.getBytesSent, utf8.encode(contents).length);
      expect(await _restoreArtifacts(home), isEmpty);
    });
  });

  test('concurrent backup reads share one HTTP request and result', () async {
    await _withDownloadFixture((home, server, service) async {
      final contents = jsonEncode({'backup': 'concurrent'});
      final snapshot = server.addSnapshot(utf8.encode(contents));
      server.getStarted = Completer<void>();
      server.getGate = Completer<void>();
      final first = service.downloadBackup(snapshot);
      await server.getStarted!.future;
      final second = service.downloadBackup(snapshot);
      server.getGate!.complete();
      expect(await Future.wait([first, second]), [contents, contents]);
      expect(server.getRanges, [null]);
      expect(await _restoreArtifacts(home), isEmpty);
    });
  });

  test('backup partials stay isolated when switching namespaces', () async {
    await _withDownloadFixture((home, server, service) async {
      final contents = jsonEncode({'backup': List.filled(8192, 'value')});
      final snapshot = server.addSnapshot(utf8.encode(contents));
      final original = webDavSetting.toConfigString();
      server.interruptNextGetAfter = 1024;
      await expectLater(service.downloadBackup(snapshot), throwsA(anything));
      final originalPartial = (await _restoreArtifacts(home)).single;
      final other = Map<String, dynamic>.from(jsonDecode(original) as Map)
        ..['rootPath'] = 'another';
      webDavSetting.applyBeanConfig(jsonEncode(other));
      server.addSnapshot(utf8.encode(contents));
      expect(await service.downloadBackup(snapshot), contents);
      expect(await originalPartial.exists(), isTrue);
      webDavSetting.applyBeanConfig(original);
      expect(await service.downloadBackup(snapshot), contents);
      expect(server.getRanges, [null, null, 'bytes=1024-']);
      expect(await _restoreArtifacts(home), isEmpty);
    });
  });

  test(
    'backup checksum or UTF8 failure removes the unusable download',
    () async {
      await _withDownloadFixture((home, server, service) async {
        final contents = utf8.encode(
          jsonEncode({'backup': List.filled(8192, 'value')}),
        );
        final snapshot = server.addSnapshot(contents);
        server.interruptNextGetAfter = 1024;
        await expectLater(service.downloadBackup(snapshot), throwsA(anything));
        final partial = (await _restoreArtifacts(home)).single;
        final damaged = await partial.readAsBytes();
        damaged[0] = 0;
        await partial.writeAsBytes(damaged);
        await expectLater(
          service.downloadBackup(snapshot),
          throwsA(isA<FormatException>()),
        );
        expect(await _restoreArtifacts(home), isEmpty);
        expect(await service.downloadBackup(snapshot), utf8.decode(contents));
        final invalidUtf8 = server.addSnapshot([0xff]);
        await expectLater(
          service.downloadBackup(invalidUtf8),
          throwsA(isA<FormatException>()),
        );
        expect(server.getRanges, [null, 'bytes=1024-', null, null]);
        expect(await _restoreArtifacts(home), isEmpty);
      });
    },
  );
}

Future<void> _withDownloadFixture(
  Future<void> Function(
    Directory home,
    _DavServer server,
    WebDavBackupService service,
  )
  body,
) async {
  final home = await Directory.systemTemp.createTemp('webdav-download-test-');
  final previousSetting = webDavSetting.toConfigString();
  final previousDoc = pathService.appDocDir;
  final previousSupport = pathService.appSupportDir;
  final previousTemp = pathService.tempDir;
  final server = await _DavServer.start();
  pathService.appDocDir = home;
  pathService.appSupportDir = home;
  pathService.tempDir = home;
  appDb = AppDb();
  try {
    webDavSetting.applyBeanConfig(
      jsonEncode({
        'address': 'http://localhost:${server.server.port}/v1/dav/sync/',
        'username': 'u',
        'password': 'p',
        'rootPath': '',
      }),
    );
    final service = WebDavBackupService();
    await service.doInitBean();
    await body(home, server, service);
  } finally {
    webDavSetting.applyBeanConfig(previousSetting);
    pathService.appDocDir = previousDoc;
    pathService.appSupportDir = previousSupport;
    pathService.tempDir = previousTemp;
    await server.server.close(force: true);
    await appDb.close();
    await home.delete(recursive: true);
  }
}

Future<List<File>> _restoreArtifacts(Directory home) async =>
    (await Directory('${home.path}/webdav-backup-artifacts').list().toList())
        .whereType<File>()
        .where((file) => file.uri.pathSegments.last.startsWith('restore-'))
        .toList();

class _PendingConfigService extends LocalConfigService {
  final completion = Completer<int>();
  ConfigEnum? configKey;
  String? value;

  @override
  Future<int> write({
    required ConfigEnum configKey,
    String subConfigKey = LocalConfigService.defaultSubConfigKey,
    required String value,
  }) {
    this.configKey = configKey;
    this.value = value;
    return completion.future;
  }
}

class _DavServer {
  final HttpServer server;
  final Map<String, List<int>?> entries = {'/v1/dav/sync/': null};
  bool failPut = false;
  bool badChildListing = false;
  int puts = 0;
  int moves = 0;
  Completer<void>? moveStarted;
  Completer<void>? moveGate;
  Completer<void>? getStarted;
  Completer<void>? getGate;
  int? interruptNextGetAfter;
  final List<String?> getRanges = [];
  int getBytesSent = 0;

  _DavServer._(this.server);

  static Future<_DavServer> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final dav = _DavServer._(server);
    server.listen(dav._handle);
    return dav;
  }

  WebDavBackupSnapshot addSnapshot(List<int> bytes) {
    final hash = sha256.convert(bytes).toString();
    final snapshot = WebDavBackupSnapshot(
      deviceId: 'remote-device',
      snapshotId: hash,
      remotePath: 'backups/remote-device/$hash.json',
    );
    entries[webDavSetting.connection.uri(snapshot.remotePath).path] = bytes;
    return snapshot;
  }

  Future<void> _handle(HttpRequest request) async {
    final path = request.uri.path.endsWith('/')
        ? request.uri.path
        : request.uri.path;
    final key = path.endsWith('/') ? path : '$path/';
    switch (request.method) {
      case 'MKCOL':
        if (entries.containsKey(key)) {
          request.response.statusCode = 405;
        } else if (!entries.containsKey(Uri.parse(key).resolve('../').path)) {
          request.response.statusCode = 409;
        } else {
          entries[key] = null;
          request.response.statusCode = 201;
        }
      case 'PROPFIND':
        if (badChildListing && path.endsWith('/backups/')) {
          request.response.statusCode = 207;
          request.response.headers.contentType = ContentType(
            'application',
            'xml',
          );
          request.response.write(
            '<?xml version="1.0"?><d:multistatus xmlns:d="DAV:">${_xmlEntry(path, null)}<d:response><d:href>${path}missing/</d:href><d:propstat><d:prop><d:resourcetype><d:collection/></d:resourcetype></d:prop><d:status>HTTP/1.1 404 Not Found</d:status></d:propstat></d:response></d:multistatus>',
          );
          break;
        }
        final directory = path.endsWith('/') ? path : '$path/';
        final resource = entries.containsKey(path)
            ? path
            : entries.containsKey(directory)
            ? directory
            : null;
        if (resource == null) {
          request.response.statusCode = 404;
        } else {
          request.response.statusCode = 207;
          request.response.headers.contentType = ContentType(
            'application',
            'xml',
          );
          final depth = request.headers.value('Depth');
          final children = depth == '1'
              ? entries.keys.where(
                  (entry) =>
                      entry != resource &&
                      entry.startsWith(resource) &&
                      !entry
                          .substring(resource.length)
                          .replaceAll(RegExp(r'/$'), '')
                          .contains('/'),
                )
              : <String>[];
          request.response.write(
            '<?xml version="1.0"?><d:multistatus xmlns:d="DAV:">${[resource, ...children].map((entry) => _xmlEntry(entry, entries[entry])).join()}</d:multistatus>',
          );
        }
      case 'PUT':
        puts++;
        if (failPut) {
          await request.toList();
          request.response.statusCode = 503;
        } else {
          entries[path] = await request.toList().then(
            (chunks) => chunks.expand((v) => v).toList(),
          );
          request.response.statusCode = 201;
        }
      case 'MOVE':
        moveStarted?.complete();
        await moveGate?.future;
        final target = Uri.parse(request.headers.value('Destination')!).path;
        if (entries.containsKey(target)) {
          request.response.statusCode = 412;
        } else {
          entries[target] = entries.remove(path);
          moves++;
          request.response.statusCode = 201;
        }
      case 'GET':
        getRanges.add(request.headers.value(HttpHeaders.rangeHeader));
        if (getStarted case final started? when !started.isCompleted) {
          started.complete();
        }
        await getGate?.future;
        final bytes = entries[path];
        if (bytes == null) {
          request.response.statusCode = 404;
        } else {
          final range = request.headers.value(HttpHeaders.rangeHeader);
          final offset = range == null
              ? 0
              : int.parse(RegExp(r'^bytes=(\d+)-$').firstMatch(range)![1]!);
          request.response.statusCode = offset == 0 ? 200 : 206;
          request.response.contentLength = bytes.length - offset;
          if (offset > 0) {
            request.response.headers.set(
              HttpHeaders.contentRangeHeader,
              'bytes $offset-${bytes.length - 1}/${bytes.length}',
            );
          }
          final interrupted = interruptNextGetAfter;
          interruptNextGetAfter = null;
          final end = interrupted == null ? bytes.length : offset + interrupted;
          getBytesSent += end - offset;
          if (interrupted != null) {
            final socket = await request.response.detachSocket(
              writeHeaders: false,
            );
            socket.write(
              'HTTP/1.1 200 OK\r\nContent-Length: ${bytes.length}\r\n\r\n',
            );
            socket.add(bytes.sublist(offset, end));
            await socket.flush();
            socket.destroy();
            return;
          }
          request.response.add(bytes.sublist(offset, end));
        }
      case 'DELETE':
        entries.remove(path);
        request.response.statusCode = 204;
      default:
        request.response.statusCode = 405;
    }
    await request.response.close();
  }

  String _xmlEntry(String path, List<int>? bytes) =>
      '<d:response><d:href>$path</d:href><d:propstat><d:prop><d:resourcetype>${bytes == null ? '<d:collection/>' : ''}</d:resourcetype><d:getcontentlength>${bytes?.length ?? 0}</d:getcontentlength></d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>';
}
