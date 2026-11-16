import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart' as dio;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/enum/config_enum.dart';
import 'package:jhentai/src/model/gallery_image.dart';
import 'package:jhentai/src/model/read_page_info.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/utils/eh_spider_parser.dart';
import 'package:jhentai/src/service/content_page_download_service.dart';
import 'package:jhentai/src/pages/download_search/download_search_logic.dart';
import 'package:jhentai/src/pages/download_search/download_search_state.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/service/archive_download_service.dart';
import 'package:jhentai/src/service/content_codec.dart';
import 'package:jhentai/src/service/content_sync/content_repository.dart';
import 'package:jhentai/src/service/content_sync/portable_manifest.dart';
import 'package:jhentai/src/service/gallery_download/gallery_download_service.dart';
import 'package:jhentai/src/service/local_config_service.dart';
import 'package:jhentai/src/service/local_content_service.dart';
import 'package:jhentai/src/service/log.dart';
import 'package:jhentai/src/service/path_service.dart';
import 'package:jhentai/src/setting/download_setting.dart';
import 'package:path/path.dart' as p;

import 'support/test_log_service.dart';

class _PartialUpgradeRequest extends EHRequest {
  final pendingPage = Completer<void>();
  @override
  Future<T> requestDetailPage<T>({
    required String galleryUrl,
    int thumbnailsPageIndex = 0,
    bool useCacheIfAvailable = true,
    dio.CancelToken? cancelToken,
    required HtmlParser<T> parser,
  }) async {
    if (cancelToken == null) {
      throw StateError('No ComicInfo network in this test');
    }
    if (!pendingPage.isCompleted) {
      pendingPage.complete();
    }
    throw await cancelToken.whenCancel;
  }

  @override
  Future<T> requestImagePage<T>(
    String href, {
    String? reloadKey,
    dio.CancelToken? cancelToken,
    bool useCacheIfAvailable = true,
    required HtmlParser<T> parser,
  }) async => GalleryImage(url: 'https://example.com/replacement.png') as T;
  @override
  Future<
    ({dio.Response<dio.ResponseBody> response, String rawHash, int rawLength})
  >
  downloadWithHash({
    required String url,
    required String path,
    dio.ProgressCallback? onReceiveProgress,
    dio.CancelToken? cancelToken,
    int? receiveTimeout,
  }) async {
    final bytes = [7, 8, 9];
    await File(path).writeAsBytes(bytes);
    return (
      response: dio.Response<dio.ResponseBody>(
        requestOptions: dio.RequestOptions(path: url),
        headers: dio.Headers.fromMap({
          'content-type': ['image/png'],
        }),
      ),
      rawHash: sha256.convert(bytes).toString(),
      rawLength: bytes.length,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory home;
  late AppDb previousDb;
  late LocalContentService previousOwner;
  late DownloadSetting previousDownloadSetting;
  late LogService previousLog;
  late Directory? previousDoc;
  late Directory? previousSupport;

  setUp(() async {
    previousDb = appDb;
    previousOwner = localContentService;
    previousDownloadSetting = downloadSetting;
    previousLog = log;
    previousDoc = pathService.appDocDir;
    previousSupport = pathService.appSupportDir;
    log = TestLogService();
    home = await Directory.systemTemp.createTemp('hclient-owner-entries-');
    pathService.appDocDir = home;
    pathService.appSupportDir = home;
    pathService.tempDir = home;
    appDb = AppDb.testing(NativeDatabase.memory());
    localContentService = LocalContentService(
      repository: ContentRepository(appDb),
    );
    downloadSetting = DownloadSetting();
    await downloadSetting.doInitBean();
    downloadSetting.downloadPath.value = '${home.path}/download';
    downloadSetting.restoreTasksAutomatically.value = false;
    await Directory(downloadSetting.downloadPath.value).create();
  });

  tearDown(() async {
    await ContentCodec().close();
    Get.reset();
    await appDb.close();
    appDb = previousDb;
    localContentService = previousOwner;
    downloadSetting = previousDownloadSetting;
    log = previousLog;
    pathService.appDocDir = previousDoc;
    pathService.appSupportDir = previousSupport;
    pathService.tempDir = Directory.systemTemp;
    await home.delete(recursive: true);
  });

  Map<String, Object?> galleryJson(String title, {String? copyId}) => {
    'gid': 123,
    'token': 'token',
    'title': title,
    'category': 'Manga',
    'pageCount': 1,
    'galleryUrl': 'https://e-hentai.org/g/123/token/',
    'oldVersionGalleryUrl': null,
    'uploader': null,
    'publishTime': '2023-11-14',
    'downloadStatusIndex': DownloadStatus.downloaded.index,
    'insertTime': '2023-11-14',
    'downloadOriginalImage': false,
    'priority': 4,
    'sortOrder': 0,
    'groupName': '',
    'tags': '',
    'tagRefreshTime': null,
    'sanitizedTitle': title,
    'copyId': copyId,
  };

  Future<String> completedCopy(
    Directory root, {
    int gid = 123,
    bool pcf = false,
  }) async {
    final bytes = await File('native/tests/fixtures/gradient.png')
        .readAsBytes();
    await root.create(recursive: true);
    await File('${root.path}/0.png').writeAsBytes(bytes);
    final id = await localContentService.ensureCopy(
      gid: gid,
      representation: 'resampled',
      rootPath: root.path,
    );
    await localContentService.recordPage(
      copyId: id,
      ordinal: 0,
      relativePath: '0.png',
      rawHash: sha256.convert(bytes).toString(),
      rawLength: bytes.length,
      mime: 'image/png',
    );
    await localContentService.completeCopy(
      id,
      galleryUrl: 'https://e-hentai.org/g/$gid/token/',
      title: p.basename(root.path),
      expectedPages: 1,
    );
    if (pcf) {
      final work = await localContentService.representationWorkDirectory(
        id,
        'test',
      );
      final artifact = await ContentCodec().encodeFile(
        inputPath: '${root.path}/0.png',
        outputPath: '${work.path}/candidate',
      );
      expect(artifact.codecProfile, ContentCodec.encodedProfile);
      expect(
        await localContentService.installPageRepresentation(
          copyId: id,
          ordinal: 0,
          artifact: artifact,
        ),
        isTrue,
      );
      expect(await File('${root.path}/0.png').exists(), isFalse);
    }
    return id;
  }

  Future<void> addOtherDirectory() async {
    final root = await Directory(
      '${downloadSetting.downloadPath.value}/123 - Other',
    ).create();
    await File('${root.path}/0.png').writeAsBytes([1, 2, 3]);
    final image = GalleryImage(
      url: 'https://example.com/0.png',
      path: 'obsolete/0.png',
      downloadStatus: DownloadStatus.downloaded,
    );
    DirectoryRecoveryCodec.writeNew(
      File('${root.path}/.content.sqlite'),
      DirectoryRecoveryProjection(
        copyId: 'other-copy',
        taskKind: 'gallery',
        taskState: 'downloaded',
        taskJson: jsonEncode({
          'gallery': galleryJson('Other'),
          'images': [image.toJson()],
        }),
        pages: const [DirectoryRecoveryPage(0, '0.png', 'downloaded')],
      ),
    );
  }

  for (final missing in [false, true]) {
    test(missing ? 'restore still repairs a genuinely missing owner directory' : 'restore does not replace a PCF owner with another directory of the same gid', () async {
      final root = Directory(
        '${downloadSetting.downloadPath.value}/123 - Existing',
      );
      final copyId = await completedCopy(root, pcf: true);
      await appDb
          .into(appDb.galleryDownloaded)
          .insert(
            GalleryDownloadedData.fromJson(
              galleryJson('Existing', copyId: copyId),
            ),
          );
      await appDb.customStatement(
        'INSERT INTO image (gid,url,serialNo,path,imageHash,downloadStatusIndex) VALUES (?,?,?,?,?,?)',
        [
          123,
          'https://example.com/0.png',
          0,
          p.relative('${root.path}/0.png', from: home.path),
          '',
          DownloadStatus.downloaded.index,
        ],
      );
      await addOtherDirectory();
      if (missing) {
        await root.delete(recursive: true);
      }
      final service = GalleryDownloadService();
      await service.doInitBean();
      try {
        expect(await service.restoreTasks(), missing ? 1 : 0);
        expect(
          service.galleryDownloadInfos[123]!.copyId,
          missing ? 'other-copy' : copyId,
        );
        if (!missing) {
          final bytes = (await localContentService.readPageForExport(
            copyId,
            0,
          )).bytes;
          expect(
            bytes,
            await File('native/tests/fixtures/gradient.png').readAsBytes(),
          );
        }
      } finally {
        await service.executor.close();
        service.onClose();
      }
    });
  }

  test('PCF reuse survives pause, directory-only restore and partial page redownload', () async {
    final root = Directory(
      '${downloadSetting.downloadPath.value}/123 - Existing',
    );
    final oldCopy = await completedCopy(root, pcf: true);
    await appDb
        .into(appDb.galleryDownloaded)
        .insert(
          GalleryDownloadedData.fromJson(
            galleryJson('Existing', copyId: oldCopy),
          ),
        );
    await appDb.customStatement(
      'INSERT INTO image (gid,url,serialNo,path,imageHash,downloadStatusIndex) VALUES (?,?,?,?,?,?)',
      [
        123,
        'https://example.com/0.png',
        0,
        p.relative('${root.path}/0.png', from: home.path),
        'aaaaaaaaaa',
        DownloadStatus.downloaded.index,
      ],
    );
    await localConfigService.write(
      configKey: ConfigEnum.galleryImageHash,
      subConfigKey: '124',
      value: jsonEncode(['aaaaaaaaaa', 'bbbbbbbbbb']),
    );
    downloadSetting.useJH2UpdateGallery.value = true;
    final previousRequest = ehRequest;
    final previousService = galleryDownloadService;
    addTearDown(() {
      ehRequest = previousRequest;
      galleryDownloadService = previousService;
    });
    final request = _PartialUpgradeRequest();
    ehRequest = request;
    final service = GalleryDownloadService();
    galleryDownloadService = service;
    await service.doInitBean();
    String? targetCopy;
    try {
      await service.downloadGallery(
        const GalleryDownloadRequest(
          gid: 124,
          token: 'token',
          title: 'Updated',
          category: 'Manga',
          pageCount: 2,
          galleryUrl: 'https://e-hentai.org/g/124/token/',
          publishTime: '2023-11-14',
          downloadOriginalImage: false,
          group: '',
          tags: '',
          oldVersionGalleryUrl: 'https://e-hentai.org/g/123/token/',
        ),
      );
      await request.pendingPage.future.timeout(const Duration(seconds: 10));
      await service.pauseDownloadGalleryByGid(124);
      final target = service.galleryDownloadInfos[124]!;
      targetCopy = target.copyId;
      expect(targetCopy, isNotNull);
      final newRoot = await localContentService.rootPath(targetCopy!);
      final before = await localContentService.repository.getPage(
        targetCopy,
        0,
      );
      expect(before.codecProfile, ContentCodec.encodedProfile);
      expect(await localContentService.completedInput(targetCopy), isNull);
      final projection = localContentService.readProjection(newRoot);
      expect(projection.completeManifest, isNull);
      expect(projection.pages, hasLength(2));
      expect(projection.residentPages.keys, [0]);
      expect(projection.residentPages[0]!.rawHash, before.rawHash);
      expect(
        projection.residentPages[0]!.codecProfile,
        ContentCodec.encodedProfile,
      );
      expect(projection.codecProfiles.keys, [ContentCodec.encodedProfile]);
      expect(
        (await localContentService.readPageForExport(targetCopy, 0)).bytes,
        await File('native/tests/fixtures/gradient.png').readAsBytes(),
      );
    } finally {
      await service.executor.close();
      service.onClose();
      galleryDownloadService = previousService;
    }
    await appDb.close();
    appDb = AppDb.testing(NativeDatabase.memory());
    localContentService = LocalContentService(
      repository: ContentRepository(appDb),
    );
    await localContentService.doInitBean();
    Get.reset();
    final restoredService = GalleryDownloadService();
    galleryDownloadService = restoredService;
    await restoredService.doInitBean();
    final actions = ContentPageDownloadService();
    try {
      expect(await restoredService.restoreTasks(), 1);
      final restored = restoredService.galleryDownloadInfos[124]!;
      expect(restored.copyId, targetCopy);
      expect(restored.downloadProgress.downloadStatus, DownloadStatus.paused);
      final page = await localContentService.repository.getPage(targetCopy, 0);
      expect(page.codecProfile, ContentCodec.encodedProfile);
      expect(await localContentService.completedInput(targetCopy), isNull);
      expect(
        (await localContentService.readPageForExport(targetCopy, 0)).bytes,
        await File('native/tests/fixtures/gradient.png').readAsBytes(),
      );
      await actions.redownload(
        targetCopy,
        0,
        galleryUrl: 'https://e-hentai.org/g/124/token/',
      );
      expect(await localContentService.readPageForDisplay(targetCopy, 0), [
        7,
        8,
        9,
      ]);
      expect(await localContentService.completedInput(targetCopy), isNull);
      final updated = localContentService.readProjection(
        await localContentService.rootPath(targetCopy),
      );
      expect(updated.completeManifest, isNull);
      expect(
        updated.residentPages[0]!.rawHash,
        sha256.convert([7, 8, 9]).toString(),
      );
      expect(updated.residentPages[0]!.codecProfile, ContentCodec.rawProfile);
      expect(
        (await localContentService.repository.listPages(targetCopy)).length,
        1,
      );
    } finally {
      actions.dispose();
      await restoredService.executor.close();
      restoredService.onClose();
      galleryDownloadService = previousService;
      ehRequest = previousRequest;
    }
  });

  test('complete owner projection preserves business metadata while a replacement downloads', () async {
    final root = Directory(
      '${downloadSetting.downloadPath.value}/123 - Existing',
    );
    final copyId = await completedCopy(root, pcf: true);
    await appDb
        .into(appDb.galleryDownloaded)
        .insert(
          GalleryDownloadedData.fromJson(
            galleryJson('Existing', copyId: copyId),
          ),
        );
    await appDb.customStatement(
      'INSERT INTO image (gid,url,serialNo,path,imageHash,downloadStatusIndex) VALUES (?,?,?,?,?,?)',
      [
        123,
        'https://example.com/0.png',
        0,
        p.relative('${root.path}/0.png', from: home.path),
        'aaaaaaaaaa',
        DownloadStatus.downloaded.index,
      ],
    );
    await localContentService.completeCopy(
      copyId,
      galleryUrl: 'https://e-hentai.org/g/123/token/',
      title: 'Owner edited title',
      expectedPages: 1,
      providerMetadata: {
        'rawTitle': 'Owner original title',
        'uploader': 'Owner uploader',
        'rating': 4.75,
        'language': 'Chinese',
      },
      collections: ['Owner collection', 'Second collection'],
      tags: [const PortableTag('artist', 'Owner artist')],
      lineage: [const ManifestLineage(100, 123, 'update')],
    );
    await localContentService.updateMetadata(
      copyId,
      tags: [const PortableTag('artist', 'Owner artist')],
    );
    final service = GalleryDownloadService();
    await service.doInitBean();
    try {
      await localContentService.enqueuePageReplacement(
        copyId: copyId,
        ordinal: 0,
        newRelativePath: '0.png',
      );
      await service.assignPriority(service.galleryDownloadInfos[123]!, 7);
      await Future<void>.delayed(const Duration(milliseconds: 700));
      await localContentService.flushProjection(root.path);
      final projection = localContentService.readProjection(root.path);
      expect(projection.completeManifest, isNotNull);
      expect(await localContentService.completedInput(copyId), isNull);
      expect(projection.pages.single.relativePath, '0.png.pcf');
      expect(
        projection.residentPages[0]!.codecProfile,
        ContentCodec.encodedProfile,
      );
      final task = jsonDecode(projection.taskJson) as Map;
      expect(
        ((task['images'] as List).single as Map)['path'],
        p.relative('${root.path}/0.png.pcf', from: home.path),
      );
    } finally {
      await service.executor.close();
      service.onClose();
    }
    // Only directory bytes survive; neither owner metadata nor its pending
    // runtime work journal is available to the restored owner.
    await appDb.close();
    appDb = AppDb.testing(NativeDatabase.memory());
    localContentService = LocalContentService(
      repository: ContentRepository(appDb),
    );
    final disk = DirectoryRecoveryCodec.read(
      File('${root.path}/.content.sqlite'),
    );
    final restoredId = await localContentService.restoreDirectoryProjection(
      root.path,
      disk,
      gid: 123,
      representation: 'resampled',
    );
    final restored = (await localContentService.completedInput(restoredId))!;
    expect(restored.title, 'Owner edited title');
    expect(restored.providerMetadata['rawTitle'], 'Owner original title');
    expect(restored.providerMetadata['uploader'], 'Owner uploader');
    expect(restored.providerMetadata['rating'], 4.75);
    expect(restored.providerMetadata['language'], 'Chinese');
    expect(restored.collections, ['Owner collection', 'Second collection']);
    expect(restored.tags.single.name, 'Owner artist');
    expect(restored.lineage.single.fromGid, 100);
    expect(restored.lineage.single.toGid, 123);
    expect(restored.lineage.single.kind, 'update');
    expect(restored.pages.single.relativePath, '0.png.pcf');
  });

  testWidgets(
    'archive search opens mixed raw and PCF pages through their owner',
    (tester) async {
      final previousArchiveService = archiveDownloadService;
      final service = ArchiveDownloadService();
      late String copyId;
      late List<int> raw;
      late List<int> encodedRaw;
      await tester.runAsync(() async {
        final root = Directory(
          '${downloadSetting.downloadPath.value}/Archive - 789 - Archive',
        );
        copyId = await completedCopy(root, gid: 789, pcf: true);
        raw = await File('native/tests/fixtures/minimal.jpg').readAsBytes();
        encodedRaw = await File('native/tests/fixtures/gradient.png')
            .readAsBytes();
        await File('${root.path}/1.jpg').writeAsBytes(raw);
        await localContentService.recordPage(
          copyId: copyId,
          ordinal: 1,
          relativePath: '1.jpg',
          rawHash: sha256.convert(raw).toString(),
          rawLength: raw.length,
          mime: 'image/jpeg',
        );
        await localContentService.completeCopy(
          copyId,
          galleryUrl: 'https://e-hentai.org/g/789/token/',
          title: 'Archive',
          expectedPages: 2,
        );
        final archive = ArchiveDownloadedData.fromJson({
          'gid': 789,
          'token': 'token',
          'title': 'Archive',
          'category': 'Manga',
          'pageCount': 2,
          'galleryUrl': 'https://e-hentai.org/g/789/token/',
          'coverUrl': 'https://example.com/cover.jpg',
          'uploader': null,
          'size': raw.length,
          'publishTime': '2023-11-14',
          'archiveStatusCode': ArchiveStatus.completed.code,
          'archivePageUrl': 'https://example.com/archive',
          'downloadPageUrl': null,
          'downloadUrl': null,
          'isOriginal': true,
          'insertTime': '2023-11-14',
          'sortOrder': 0,
          'groupName': '',
          'tags': '',
          'tagRefreshTime': null,
          'parseSource': ArchiveParseSource.bot.code,
          'sanitizedTitle': 'Archive',
          'copyId': copyId,
        });
        await appDb.into(appDb.archiveDownloaded).insert(archive);
        archiveDownloadService = service;
        await service.doInitBean();
        await localConfigService.write(
          configKey: ConfigEnum.readIndexRecord,
          subConfigKey: '789',
          value: '1',
        );
      });
      ReadPageInfo? opened;
      await tester.pumpWidget(
        GetMaterialApp(
          home: const SizedBox(),
          getPages: [
            GetPage(
              name: Routes.read,
              page: () {
                opened = Get.arguments as ReadPageInfo;
                return const SizedBox();
              },
            ),
          ],
        ),
      );
      try {
        await tester.runAsync(
          () => DownloadSearchLogic().goToArchiveReadPage(
            ArchiveSearchVO(
              gid: 789,
              token: 'token',
              title: 'Archive',
              category: 'Manga',
              pageCount: 2,
              galleryUrl: 'https://e-hentai.org/g/789/token/',
              coverUrl: '',
              size: 0,
              publishTime: '2023-11-14',
              archivePageUrl: '',
              isOriginal: true,
              insertTime: '2023-11-14',
              sortOrder: 0,
              groupName: '',
              tags: [],
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(opened?.contentCopyId, copyId);
        expect(opened?.initialIndex, 1);
        expect(opened?.images, hasLength(2));
        expect(opened!.images!.map((image) => image.managedPage!.ordinal), [
          0,
          1,
        ]);
        expect(
          await tester.runAsync(
            () async =>
                (await localContentService.readPageForExport(copyId, 0)).bytes,
          ),
          encodedRaw,
        );
        expect(
          await tester.runAsync(
            () => localContentService.readPageForDisplay(copyId, 1),
          ),
          raw,
        );
      } finally {
        await tester.pumpWidget(const SizedBox());
        service.onClose();
        archiveDownloadService = previousArchiveService;
      }
    },
  );
}
