import 'dart:io';
import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/l18n/locale_text.dart';
import 'package:jhentai/src/pages/download/cloud/cloud_statistics_dialog.dart';
import 'package:jhentai/src/service/content_codec.dart';
import 'package:jhentai/src/service/content_sync/content_repository.dart';
import 'package:jhentai/src/service/content_sync/portable_manifest.dart';
import 'package:jhentai/src/service/gallery_sync/gallery_sync_service.dart';
import 'package:jhentai/src/setting/webdav_setting.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDb db;
  late GallerySyncService service;
  late GallerySyncService previousService;
  late WebDavSetting previousSetting;

  setUp(() {
    previousService = gallerySyncService;
    previousSetting = webDavSetting;
    webDavSetting = WebDavSetting()
      ..address.value = 'https://statistics.invalid/dav';
    db = AppDb.testing(NativeDatabase.memory());
    service = GallerySyncService(repository: ContentRepository(db));
    gallerySyncService = service;
    Get.testMode = true;
  });

  tearDown(() async {
    service.dispose();
    gallerySyncService = previousService;
    webDavSetting = previousSetting;
    await db.close();
    Get.reset();
  });

  PortablePage page(String identity, int raw, int stored) => PortablePage(
    rawHash: identity.padLeft(64, '0'),
    rawLength: raw,
    objectHash: identity.padLeft(64, 'f'),
    storedLength: stored,
    codecProfile: ContentCodec.encodedProfile,
    mime: 'image/png',
  );

  Future<void> publish(
    String id,
    int gid,
    List<PortablePage> pages, {
    String representation = 'original',
    List<String> supersedes = const [],
    List<ManifestLineage> lineage = const [],
    String? namespace,
    bool observed = true,
  }) async {
    String hash(String value) => sha256.convert(utf8.encode(value)).toString();
    final manifestId = hash(id);
    final manifest = PortableManifest(
      gid: gid,
      representation: representation,
      galleryUrl: 'https://e-hentai.org/g/$gid/0123456789/',
      title: 'Public gallery $gid — 长标题用于检查统计布局',
      tags: const [],
      pages: pages,
      supersedes: supersedes.map(hash).toList(),
      lineage: lineage,
      codecProfiles: ContentCodec.profileDefinitions,
    );
    final target = namespace ?? webDavSetting.connection.namespace;
    await db.customStatement(
      'INSERT INTO content_manifest '
      '(target_namespace,manifest_id,gid,representation,title,gallery_url,portable_json,imported_at) '
      'VALUES (?,?,?,?,?,?,?,?)',
      [
        target,
        manifestId,
        gid,
        representation,
        manifest.title,
        manifest.galleryUrl,
        manifest.toPortableJson(),
        id,
      ],
    );
    if (observed) {
      await service.repository.recordRemoteResource(
        targetNamespace: target,
        href: 'manifests/$manifestId.sqlite',
        kind: 'manifest',
        objectHash: manifestId,
      );
    }
  }

  Future<void> seed() async {
    final a = page('1', 100, 60);
    final b = page('2', 200, 100);
    final c = page('3', 80, 120);
    await publish('old', 10, [a]);
    await publish('revision', 10, [a], supersedes: ['old']);
    await publish('concurrent', 10, [a]);
    await publish(
      'new-gid',
      20,
      [a, b],
      lineage: const [
        ManifestLineage(10, 15, 'parent'),
        ManifestLineage(15, 20, 'parent'),
      ],
    );
    await publish('resampled', 20, [c], representation: 'resampled');
    await publish('unobserved', 40, [a], observed: false);
    await publish('other-target', 99, [a], namespace: 'other');
    await service.repository.commitPartitionScan(
      targetNamespace: webDavSetting.connection.namespace,
      partition: '__root__',
      scanState: 'complete',
      deletedHrefs: [],
    );
  }

  test(
    'indexed heads and referenced objects produce statistics without network',
    () async {
      await seed();
      final stats = await HttpOverrides.runZoned(
        () => service.statistics(),
        createHttpClient: (_) =>
            throw StateError('Statistics requested network'),
      );
      expect(stats.entries.length, 3);
      expect(stats.familyCount, 1);
      expect(stats.gidCount, 2);
      expect(stats.multiVersionFamilyCount, 1);
      expect(stats.pageCount, 4);
      expect(stats.rawBytes, 480);
      expect(stats.storedBytes, 340);
      expect(stats.compressionRatio, closeTo(1 - 340 / 480, .00001));
      expect(stats.uniqueObjectCount, 3);
      expect(stats.uniqueStoredBytes, 280);
      expect(stats.reusedStoredBytes, 60);
      expect(
        stats.entries
            .singleWhere(
              (entry) => entry.manifest.representation == 'resampled',
            )
            .compressionRatio,
        -.5,
      );
      expect(stats.indexComplete, true);
      expect(stats.indexedAt, isNotNull);
      final entries = await service.listCloudEntries();
      expect(
        entries.map((entry) => entry.familyKey).toSet().length,
        stats.familyCount,
      );
      await service.repository.recordRemoteResource(
        targetNamespace: webDavSetting.connection.namespace,
        href: 'manifests/pending.sqlite',
        kind: 'manifest',
        objectHash: 'pending',
      );
      expect((await service.statistics()).indexComplete, false);
    },
  );

  test(
    'empty index has no compression denominator or invented counts',
    () async {
      final stats = await service.statistics();
      expect(stats.familyCount, 0);
      expect(stats.gidCount, 0);
      expect(stats.entries, isEmpty);
      expect(stats.rawBytes, 0);
      expect(stats.uniqueStoredBytes, 0);
      expect(stats.compressionRatio, isNull);
      expect(stats.indexComplete, false);
    },
  );

  testWidgets(
    'statistics overview and gallery detail remain usable with large text',
    (tester) async {
      await seed();
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        GetMaterialApp(
          translations: LocaleText(),
          locale: const Locale('zh', 'CN'),
          builder: (_, child) => MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 700),
              textScaler: TextScaler.linear(1.8),
            ),
            child: child!,
          ),
          home: const Scaffold(body: CloudStatisticsDialog()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('图库统计'), findsOneWidget);
      expect(find.text('总览'), findsOneWidget);
      await tester.tap(find.text('图库明细'));
      await tester.pumpAndSettle();
      expect(find.textContaining('GID 10'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
