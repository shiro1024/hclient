import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/pages/setting/webdav/setting_webdav_page.dart';
import 'package:jhentai/src/service/gallery_sync/gallery_sync_service.dart';
import 'package:jhentai/src/service/local_backup_service.dart';
import 'package:jhentai/src/service/webdav/webdav_backup_service.dart';
import 'package:jhentai/src/service/webdav/webdav_client.dart';
import 'package:jhentai/src/setting/webdav_setting.dart';

void main() {
  late WebDavBackupService originalBackup;
  late WebDavSetting originalSetting;
  late GallerySyncService originalGallery;
  late _FakeBackupService backup;
  late _FakeGallerySyncService gallery;

  setUp(() {
    originalBackup = webDavBackupService;
    originalSetting = webDavSetting;
    originalGallery = gallerySyncService;
    webDavSetting = _FakeWebDavSetting();
    webDavBackupService = backup = _FakeBackupService();
    gallerySyncService = gallery = _FakeGallerySyncService();
  });

  tearDown(() {
    webDavBackupService = originalBackup;
    webDavSetting = originalSetting;
    gallerySyncService = originalGallery;
  });

  Future<void> configure([String server = 'a']) => webDavSetting.save(
    address: 'https://server-$server.example/dav',
    username: 'user',
    password: 'pw',
    rootPath: '',
  );

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(const GetMaterialApp(home: SettingWebDavPage()));
    await tester.pumpAndSettle();
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    final target = find.text(text).last;
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'automatic-sync settings query only release jobs and merge overlapping refreshes',
    (tester) async {
      await configure();
      final held = Completer<List<CloudSyncJob>>();
      gallery.heldJobs = held;
      await open(tester);
      for (var event = 0; event < 30; event++) {
        gallery.announceJobs();
      }
      await tester.pump();
      expect(gallery.jobFilters, ['release']);
      gallery.heldJobs = null;
      gallery.jobs = const [
        CloudSyncJob(
          'release',
          'content',
          'Release scope',
          'paused',
          0,
          1,
          finishAction: 'release',
        ),
        CloudSyncJob(
          'handoff',
          'content',
          'Automatic scope',
          'paused',
          0,
          1,
          finishAction: 'handoff',
        ),
      ];
      held.complete(const []);
      await tester.pumpAndSettle();
      expect(gallery.jobFilters, ['release', 'release']);
      await tester.ensureVisible(find.byType(ExpansionTile));
      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();
      expect(find.text('Release scope'), findsOneWidget);
      expect(find.text('Automatic scope'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'automatic gallery sync stays separate from backup and preserves existing release choices',
    (tester) async {
      await configure();
      gallery.jobs = const [
        CloudSyncJob(
          'release',
          'content',
          'Previously selected local release',
          'queued',
          0,
          1,
          finishAction: 'release',
        ),
      ];
      await open(tester);
      await tester.ensureVisible(find.byType(SwitchListTile));
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(gallery.autoChanges, [true]);
      expect(webDavSetting.autoSync.value, isTrue);
      expect(backup.createTargets, isEmpty);
      await tester.ensureVisible(find.text('webdavExistingReleaseCount'));
      await tester.tap(find.text('webdavExistingReleaseCount'));
      await tester.pumpAndSettle();
      expect(find.text('Previously selected local release'), findsOneWidget);
      expect(gallery.jobs.single.cleanupAfterUpload, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'automatic sync is absent without a connection and exposes toggle errors',
    (tester) async {
      await open(tester);
      expect(find.byType(SwitchListTile), findsNothing);
      await configure();
      await tester.pumpAndSettle();
      gallery.autoError = const WebDavException(
        WebDavErrorKind.network,
        'offline',
      );
      await tester.ensureVisible(find.byType(SwitchListTile));
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(webDavSetting.autoSync.value, isFalse);
      expect(find.byType(SwitchListTile), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'editing stays a draft and cancellation leaves saved connection intact',
    (tester) async {
      await configure();
      await open(tester);
      expect(find.byType(TextFormField), findsNothing);
      await tapText(tester, 'webdavEditConnection');
      await tester.enterText(
        find.byType(TextFormField).first,
        'https://draft.example/dav',
      );
      await tester.tap(find.byTooltip('webdavShowPassword'));
      await tester.pumpAndSettle();
      final password = tester.widget<TextField>(
        find.descendant(
          of: find.byType(TextFormField).at(2),
          matching: find.byType(TextField),
        ),
      );
      expect(password.obscureText, isFalse);
      expect(webDavSetting.address.value, contains('server-a'));
      expect(
        backup.listTargets.every((target) => target.contains('server-a')),
        isTrue,
      );
      await tapText(tester, 'cancel');
      expect(webDavSetting.address.value, contains('server-a'));
      expect(find.text('https://draft.example/dav'), findsNothing);
    },
  );

  testWidgets(
    'saving without testing updates the connection and list errors preserve save success',
    (tester) async {
      await configure();
      await open(tester);
      backup.listError = const WebDavException(
        WebDavErrorKind.network,
        'offline',
      );
      await tapText(tester, 'webdavEditConnection');
      await tester.enterText(
        find.byType(TextFormField).first,
        'https://server-b.example/dav',
      );
      await tapText(tester, 'webdavSave');
      expect(find.byType(TextFormField), findsNothing);
      expect(webDavSetting.address.value, contains('server-b'));
      expect(gallery.changedTargets.single, contains('server-b'));
      expect(
        backup.listTargets.where((target) => target.contains('server-b')),
        hasLength(1),
      );
      expect(find.text('webdavSaved'), findsOneWidget);
      expect(find.text('webdavBackupsLoadError'), findsOneWidget);
      expect(find.text('webdavNoSnapshots'), findsNothing);
      backup.listError = null;
      await tapText(tester, 'webdavRetry');
      expect(find.text('webdavBackupsLoadError'), findsNothing);
      expect(find.text('webdavNoSnapshots'), findsOneWidget);
      final requestsBeforeSameSave = backup.listTargets.length;
      await tapText(tester, 'webdavEditConnection');
      await tapText(tester, 'webdavSave');
      expect(backup.listTargets.length, requestsBeforeSameSave + 1);
    },
  );

  testWidgets(
    'invalid addresses are inline and never replace saved connection',
    (tester) async {
      await configure();
      await open(tester);
      await tapText(tester, 'webdavEditConnection');
      await tester.enterText(
        find.byType(TextFormField).first,
        'not-an-address',
      );
      await tapText(tester, 'webdavSave');
      expect(find.text('webdavInvalidAddress'), findsOneWidget);
      expect(webDavSetting.address.value, contains('server-a'));
      expect(gallery.changedTargets, isEmpty);
    },
  );

  testWidgets(
    'old target snapshots disappear and late results cannot replace new target list',
    (tester) async {
      await configure();
      final oldResult = Completer<List<WebDavBackupSnapshot>>();
      backup.pendingList = oldResult;
      await tester.pumpWidget(const GetMaterialApp(home: SettingWebDavPage()));
      await tester.pump();
      backup.pendingList = null;
      backup.listError = const WebDavException(
        WebDavErrorKind.network,
        'offline',
      );
      await configure('b');
      await tester.pumpAndSettle();
      oldResult.complete([_FakeBackupService.snapshot]);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.restore), findsNothing);
      expect(find.text('webdavBackupsLoadError'), findsOneWidget);
      expect(find.text('webdavNoSnapshots'), findsNothing);
      expect(backup.downloadTargets, isEmpty);
    },
  );

  testWidgets(
    'restore uses saved connection and ignores a download after target changes',
    (tester) async {
      await configure();
      backup.snapshots = [_FakeBackupService.snapshot];
      backup.pendingDownload = Completer<String>();
      await open(tester);
      await tester.ensureVisible(find.text('webdavRestore'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('webdavRestore'));
      await tester.pump();
      expect(backup.downloadTargets.single, contains('server-a'));
      backup.snapshots = [];
      await configure('b');
      await tester.pumpAndSettle();
      backup.pendingDownload!.complete('[]');
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('webdavNoSnapshots'), findsOneWidget);
    },
  );

  testWidgets(
    'backup uses saved connection and creation success survives list failure',
    (tester) async {
      await configure();
      await open(tester);
      await tapText(tester, 'webdavCreateBackup');
      backup.listError = const WebDavException(
        WebDavErrorKind.network,
        'offline',
      );
      await tapText(tester, 'OK');
      expect(backup.createTargets.single, contains('server-a'));
      expect(find.text('webdavBackupComplete'), findsOneWidget);
      expect(find.text('webdavBackupsLoadError'), findsOneWidget);
    },
  );

  testWidgets(
    'connection editor fits narrow screens with large text and keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        GetMaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.8),
              viewInsets: const EdgeInsets.only(bottom: 280),
            ),
            child: child!,
          ),
          home: const SettingWebDavPage(),
        ),
      );
      await tester.pumpAndSettle();
      await tapText(tester, 'webdavConfigureConnection');
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byType(TextFormField).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('webdavSave'), findsOneWidget);
    },
  );
}

class _FakeWebDavSetting extends WebDavSetting {
  @override
  Future<void> save({
    required String address,
    required String username,
    required String password,
    required String rootPath,
  }) async {
    final connection = WebDavConnection.fromFields(
      address: address,
      username: username,
      password: password,
      rootPath: rootPath,
    );
    this.address.value = connection.address.toString();
    this.username.value = username;
    this.password.value = password;
    this.rootPath.value = connection.rootSegments.join('/');
  }
}

class _FakeGallerySyncService extends GallerySyncService {
  final List<String> changedTargets = [];
  final List<bool> autoChanges = [];
  List<CloudSyncJob> jobs = [];
  Object? autoError;
  Completer<List<CloudSyncJob>>? heldJobs;
  final List<String?> jobFilters = [];
  void announceJobs() => notifyListeners();

  @override
  Future<List<CloudSyncJob>> listSyncJobs({String? finishAction}) async {
    jobFilters.add(finishAction);
    if (heldJobs != null) return heldJobs!.future;
    return finishAction == null
        ? jobs
        : jobs.where((job) => job.finishAction == finishAction).toList();
  }

  @override
  Future<void> setAutoSync(bool enabled) async {
    autoChanges.add(enabled);
    if (autoError != null) throw autoError!;
    webDavSetting.autoSync.value = enabled;
  }

  @override
  Future<void> targetChanged() async =>
      changedTargets.add(webDavSetting.connection.namespace);
}

class _FakeBackupService extends WebDavBackupService {
  static const snapshot = WebDavBackupSnapshot(
    deviceId: 'tiny',
    snapshotId: 'a',
    remotePath: 'backups/tiny/a.json',
    size: 2048,
  );
  Completer<List<WebDavBackupSnapshot>>? pendingList;
  Completer<String>? pendingDownload;
  Object? listError;
  List<WebDavBackupSnapshot> snapshots = [];
  final List<String> listTargets = [];
  final List<String> downloadTargets = [];
  final List<String> createTargets = [];

  @override
  Future<void> resumePending() async {}

  @override
  Future<List<WebDavBackupSnapshot>> listBackups() async {
    listTargets.add(webDavSetting.connection.namespace);
    if (pendingList != null) return pendingList!.future;
    if (listError != null) throw listError!;
    return snapshots;
  }

  @override
  Future<WebDavBackupSnapshot> createBackup(
    LocalBackupSelection selection,
  ) async {
    createTargets.add(webDavSetting.connection.namespace);
    return snapshot;
  }

  @override
  Future<String> downloadBackup(WebDavBackupSnapshot snapshot) async {
    downloadTargets.add(webDavSetting.connection.namespace);
    return pendingDownload?.future ?? '[]';
  }
}
