import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/model/gallery_image.dart';
import 'package:jhentai/src/model/gallery_detail.dart';
import 'package:jhentai/src/model/gallery_tag.dart';
import 'package:jhentai/src/model/gallery_url.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/service/archive_download_service.dart';
import 'package:jhentai/src/service/archive_downloader/j_downloader.dart';
import 'package:jhentai/src/service/content_sync/content_repository.dart';
import 'package:jhentai/src/service/content_sync/portable_manifest.dart';
import 'package:jhentai/src/service/gallery_download/gallery_download_service.dart';
import 'package:jhentai/src/service/local_content_service.dart';
import 'package:jhentai/src/service/local_gallery_service.dart';
import 'package:jhentai/src/service/log.dart';
import 'package:jhentai/src/service/path_service.dart';
import 'package:jhentai/src/setting/download_setting.dart';
import 'package:jhentai/src/utils/eh_spider_parser.dart';
import 'package:path/path.dart' as path;

import 'support/test_log_service.dart';

class _BlockedReplacementRequest extends EHRequest {
  final entered = Completer<void>();

  @override
  Future<T> requestDetailPage<T>({
    required String galleryUrl,
    int thumbnailsPageIndex = 0,
    bool useCacheIfAvailable = true,
    CancelToken? cancelToken,
    required HtmlParser<T> parser,
  }) async {
    if (!entered.isCompleted) entered.complete();
    throw await cancelToken!.whenCancel;
  }
}

class _NoProxyRequest extends EHRequest {
  @override
  ProxyConfig? currentProxyConfig() => null;
}

class _BlockedArchiveUnlockRequest extends EHRequest {
  final entered = Completer<void>();
  final secondEntered = Completer<void>();
  int calls = 0;

  @override
  Future<T> requestUnlockArchive<T>({
    required String url,
    required bool isOriginal,
    CancelToken? cancelToken,
    HtmlParser<T>? parser,
  }) async {
    calls++;
    if (calls == 1) entered.complete();
    if (calls == 2) secondEntered.complete();
    throw await cancelToken!.whenCancel;
  }
}

class _HeldComicInfoRequest extends EHRequest {
  final entered = Completer<void>();
  final release = Completer<void>();

  @override
  Future<T> requestDetailPage<T>({
    required String galleryUrl,
    int thumbnailsPageIndex = 0,
    bool useCacheIfAvailable = true,
    CancelToken? cancelToken,
    required HtmlParser<T> parser,
  }) async {
    if (cancelToken != null) {
      throw await cancelToken.whenCancel;
    }
    if (!entered.isCompleted) entered.complete();
    await release.future;
    return (
      galleryDetails: GalleryDetail(
        galleryUrl: GalleryUrl.parse(galleryUrl),
        rawTitle: 'Comic info',
        category: 'Manga',
        cover: GalleryImage(url: 'https://example.com/cover.jpg'),
        pageCount: 1,
        rating: 0,
        realRating: 0,
        hasRated: false,
        ratingCount: 0,
        favoriteCount: 0,
        language: 'English',
        publishTime: '2023-11-14',
        isExpunged: false,
        tags: LinkedHashMap<String, List<GalleryTag>>(),
        size: '0',
        torrentCount: '0',
        torrentPageUrl: '',
        archivePageUrl: '',
        comments: [],
        thumbnails: [],
        thumbnailsPageCount: 0,
      ),
      apikey: '',
    ) as T;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory home;
  late LogService previousLog;

  setUpAll(() {
    previousLog = log;
    log = TestLogService();
  });

  setUp(() async {
    home = await Directory.systemTemp.createTemp('hclient-content-restore-');
    pathService.appDocDir = home;
    pathService.appSupportDir = home;
    pathService.tempDir = home;
    appDb = AppDb.testing(NativeDatabase(File('${home.path}/old.sqlite')));
    localContentService = LocalContentService(
      repository: ContentRepository(appDb),
    );
    await downloadSetting.doInitBean();
    downloadSetting.downloadPath.value = '${home.path}/download';
    downloadSetting.restoreTasksAutomatically.value = false;
    await Directory(downloadSetting.downloadPath.value).create();
  });

  tearDown(() async {
    await appDb.close();
    Get.reset();
    await home.delete(recursive: true);
  });

  tearDownAll(() => log = previousLog);

  Future<void> freshDatabase() async {
    await appDb.close();
    final file = File('${home.path}/fresh.sqlite');
    if (await file.exists()) await file.delete();
    appDb = AppDb.testing(NativeDatabase(file));
    localContentService = LocalContentService(
      repository: ContentRepository(appDb),
    );
    await localContentService.doInitBean();
  }

  test(
    'cloud handoff and catalog changes update the local browsing projection',
    () async {
      final originalLocal = localGalleryService;
      localGalleryService = LocalGalleryService();
      addTearDown(() => localGalleryService = originalLocal);
      final root = await Directory(
        '${downloadSetting.downloadPath.value}/resident',
      ).create();
      await File('${root.path}/1.jpg').writeAsBytes([1, 2, 3]);
      final id = await localContentService.ensureCopy(
        gid: 42,
        representation: 'original',
        rootPath: root.path,
      );
      await localContentService.recordPage(
        copyId: id,
        ordinal: 0,
        relativePath: '1.jpg',
        rawHash: sha256.convert([1, 2, 3]).toString(),
        rawLength: 3,
      );
      await localContentService.completeCopy(
        id,
        galleryUrl: 'https://e-hentai.org/g/42/0123456789/',
        title: 'Resident',
      );
      var namespace = 'cloud-a';
      localContentService.currentLibraryNamespace = () => namespace;
      await localGalleryService.doInitBean();
      expect(
        localGalleryService.allGalleries.where((g) => g.copyId == id),
        hasLength(1),
      );
      final manifest = PortableManifest(
        gid: 42,
        representation: 'original',
        galleryUrl: 'https://e-hentai.org/g/42/0123456789/',
        title: 'Resident',
        tags: [],
        lineage: [],
        supersedes: [],
        codecProfiles: {},
        pages: [
          PortablePage(
            rawHash: sha256.convert([1, 2, 3]).toString(),
            rawLength: 3,
            objectHash: sha256.convert([1, 2, 3]).toString(),
            storedLength: 3,
            codecProfile: 'raw',
            mime: 'image/jpeg',
          ),
        ],
      );
      final artifact = PortableManifestCodec.write(
        File('${home.path}/remote.sqlite'),
        manifest,
      );
      final repo = localContentService.repository;
      await appDb.transaction(() async {
        await repo.importManifest(namespace, artifact);
        await repo.recordRemoteResource(
          targetNamespace: namespace,
          href: 'manifests/book.sqlite',
          kind: 'manifest',
          objectHash: artifact.manifestId,
          partition: 'aa',
        );
        await repo.handoffCopy(id, namespace);
      });
      await localContentService.finishCloudHandoff(id);
      expect(
        localGalleryService.allGalleries.where((g) => g.copyId == id),
        isEmpty,
      );
      expect(
        await localContentService.shouldRestoreTask(root.path, 'gallery'),
        isFalse,
      );
      expect(
        await localContentService.shouldRestoreTask(root.path, 'archive'),
        isFalse,
      );
      expect(
        await localContentService.withPageInput(
          id,
          0,
          (file) => file.readAsBytes(),
        ),
        [1, 2, 3],
      );
      namespace = 'cloud-b';
      await localContentService.onLibraryChanged!();
      expect(
        localGalleryService.allGalleries.where((g) => g.copyId == id),
        hasLength(1),
      );
      namespace = 'cloud-a';
      await localContentService.onLibraryChanged!();
      expect(
        localGalleryService.allGalleries.where((g) => g.copyId == id),
        isEmpty,
      );
      await appDb.customStatement('DELETE FROM content_remote_resource');
      await localContentService.onLibraryChanged!();
      expect(
        localGalleryService.allGalleries.where((g) => g.copyId == id),
        hasLength(1),
      );
    },
  );

  test(
    'gallery restore keeps sparse page ordinals when mapping image paths',
    () async {
      final root = await Directory(
        '${downloadSetting.downloadPath.value}/123 - Sparse',
      ).create();
      await File('${root.path}/last.jpg').writeAsBytes([1, 2, 3]);
      DirectoryRecoveryCodec.writeNew(
        File('${root.path}/.content.sqlite'),
        DirectoryRecoveryProjection(
          copyId: 'sparse-gallery',
          taskKind: 'gallery',
          taskState: 'paused',
          taskJson: jsonEncode({
            'gallery': {
              'gid': 123,
              'token': 'token',
              'title': 'Sparse',
              'category': 'Manga',
              'publishTime': '2023-11-14',
              'pageCount': 3,
              'galleryUrl': 'https://e-hentai.org/g/123/token/',
              'downloadStatusIndex': DownloadStatus.paused.index,
              'insertTime': '2023-11-14',
              'downloadOriginalImage': false,
              'priority': 4,
              'sortOrder': 0,
              'groupName': '',
              'tags': '',
              'sanitizedTitle': 'Sparse',
            },
            'images': [
              null,
              null,
              GalleryImage(
                url: 'https://example.com/third.jpg',
                path: 'stale/third.jpg',
                downloadStatus: DownloadStatus.downloaded,
              ).toJson(),
            ],
          }),
          pages: const [DirectoryRecoveryPage(2, 'last.jpg', 'downloaded')],
        ),
      );
      final service = GalleryDownloadService();
      await service.doInitBean();
      try {
        expect(await service.restoreTasks(), 1);
        final gallery = service.galleryDownloadInfos[123]!;
        expect(gallery.imageAtSync(0), isNull);
        expect(gallery.imageAtSync(1), isNull);
        expect(
          gallery.imageAtSync(2)!.path,
          path.relative('${root.path}/last.jpg', from: home.path),
        );
        final pages = await localContentService.repository.listPages(
          'sparse-gallery',
        );
        expect(pages.single.ordinal, 2);
        expect(pages.single.relativePath, 'last.jpg');
      } finally {
        await service.executor.close();
        service.onClose();
      }
    },
  );

  test(
    'gallery restore imports partial page owner before page replacement',
    () async {
      final root = await Directory(
        '${downloadSetting.downloadPath.value}/123 - Old title',
      ).create();
      await File('${root.path}/0.jpg').writeAsBytes([1, 2, 3]);
      final rawGallery = <String, Object?>{
        'gid': 123,
        'token': 'token',
        'title': 'Old title',
        'category': 'Manga',
        'pageCount': 1,
        'galleryUrl': 'https://e-hentai.org/g/123/token/',
        'oldVersionGalleryUrl': null,
        'uploader': null,
        'publishTime': '2023-11-14',
        'downloadStatusIndex': DownloadStatus.paused.index,
        'insertTime': '2023-11-14',
        'downloadOriginalImage': false,
        'priority': 4,
        'sortOrder': 0,
        'groupName': '',
        'tags': 'artist:sample',
        'tagRefreshTime': '2023-11-14',
        'sanitizedTitle': 'Old title',
      };
      final image = GalleryImage(
        url: 'https://example.com/0.jpg',
        path: 'stale/0.jpg',
        downloadStatus: DownloadStatus.downloaded,
      );
      DirectoryRecoveryCodec.writeNew(
        File('${root.path}/.content.sqlite'),
        DirectoryRecoveryProjection(
          copyId: 'restored-gallery-copy',
          taskKind: 'gallery',
          taskState: 'paused',
          taskJson: jsonEncode({
            'gallery': rawGallery,
            'images': [image.toJson()],
          }),
          pages: const [DirectoryRecoveryPage(0, '0.jpg', 'downloaded')],
        ),
      );
      await freshDatabase();
      final service = GalleryDownloadService();
      await service.doInitBean();
      try {
        expect(
          await service.restoreTasks().timeout(const Duration(seconds: 5)),
          1,
        );
        final id = await localContentService.copyIdForRoot(root.path);
        expect(id, 'restored-gallery-copy');
        expect(service.galleryDownloadInfos[123]!.copyId, id);
        downloadSetting.downloadPath.value = '${home.path}/new-default';
        final pages = await localContentService.repository.listPages(id!);
        expect(pages.single.rawHash, sha256.convert([1, 2, 3]).toString());
        expect(pages.single.relativePath, '0.jpg');
        await appDb.customStatement(
          'UPDATE gallery_downloaded_v2 SET download_status_index = 4 WHERE gid = 123',
        );
        await localContentService.completeCopy(
          id,
          galleryUrl: rawGallery['galleryUrl']! as String,
          title: 'Old title',
          expectedPages: 1,
        );
        final gallery = service.galleryDownloadInfos[123]!;
        gallery.downloadProgress.downloadStatus = DownloadStatus.downloaded;
        await service.assignPriority(gallery, 7);
        await Future<void>.delayed(const Duration(milliseconds: 700));
        await localContentService.flushProjection(root.path);
        final snapshot = jsonDecode(
          localContentService.readProjection(root.path).taskJson,
        ) as Map<String, dynamic>;
        expect((snapshot['gallery'] as Map)['priority'], 7);
        final replacement = await localContentService
            .enqueuePageReplacement(
              copyId: id,
              ordinal: 0,
              newRelativePath: '0.jpg',
            )
            .timeout(const Duration(seconds: 5));
        expect(replacement.oldPath, path.join(root.path, '0.jpg'));
        await localContentService
            .abandonDownloadingReplacements(id)
            .timeout(const Duration(seconds: 5));
        final originalRequest = ehRequest;
        final blocked = _BlockedReplacementRequest();
        ehRequest = blocked;
        try {
          await service.reDownloadImage(123, 0);
          await blocked.entered.future.timeout(const Duration(seconds: 5));
          await service.reDownloadImage(123, 0);
          expect(
            (await localContentService.repository.listPageReplacements(id))
                .where((item) => item.state != 'completed'),
            hasLength(1),
          );
          await service
              .deleteGallery(service.galleryDownloadInfos[123]!)
              .timeout(const Duration(seconds: 5));
          expect(await root.exists(), isFalse);
        } finally {
          ehRequest = originalRequest;
        }
      } finally {
        await service.executor.close().timeout(const Duration(seconds: 5));
        service.onClose();
      }
    },
  );

  test('archive restore imports complete page owner', () async {
    final root = await Directory(
      '${downloadSetting.downloadPath.value}/Archive - 789 - Archive',
    ).create();
    await File('${root.path}/1.jpg').writeAsBytes([4, 5, 6]);
    final copyId = await localContentService.ensureCopy(
      gid: 789,
      representation: 'original',
      rootPath: root.path,
    );
    await localContentService.recordPage(
      copyId: copyId,
      ordinal: 0,
      relativePath: '1.jpg',
      rawHash: sha256.convert([4, 5, 6]).toString(),
      rawLength: 3,
    );
    final archive = <String, Object?>{
      'gid': 789,
      'token': 'token',
      'title': 'Archive',
      'category': 'Manga',
      'pageCount': 1,
      'galleryUrl': 'https://e-hentai.org/g/789/token/',
      'coverUrl': 'https://example.com/cover.jpg',
      'uploader': null,
      'size': 3,
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
    };
    await appDb
        .into(appDb.archiveDownloaded)
        .insert(ArchiveDownloadedData.fromJson(archive));
    await localContentService.completeCopy(
      copyId,
      galleryUrl: archive['galleryUrl']! as String,
      title: 'Archive',
      expectedPages: 1,
    );
    await freshDatabase();
    final service = ArchiveDownloadService();
    await service.doInitBean();
    final originalArchiveService = archiveDownloadService;
    archiveDownloadService = service;
    try {
      final packingPath = service.computePackingFileDownloadPath(
        ArchiveDownloadedData.fromJson(archive),
      );
      expect(path.isWithin(root.path, packingPath), isTrue);
      await File('$packingPath.jdtemp').create(recursive: true);
      expect(await service.restoreTasks(), 1);
      expect(service.archives.single.parseSource, ArchiveParseSource.bot.code);
      final id = await localContentService.copyIdForRoot(root.path);
      expect(id, copyId);
      expect(service.archives.single.copyId, id);
      downloadSetting.downloadPath.value = '${home.path}/new-default';
      expect(
        service.computeArchiveUnpackingPath(service.archives.single),
        root.path,
      );
      final pages = await localContentService.repository.listPages(id!);
      expect(pages.single.rawHash, sha256.convert([4, 5, 6]).toString());
      expect((await localContentService.readPageInfoForCopy(id)).pageCount, 1);
      final repo = localContentService.repository;
      final work = await repo.createWorkItem(
        kind: 'content',
        targetNamespace: 'test',
        copyId: id,
        inputJson: '{}',
        finishAction: 'release',
      );
      final manifestId = 'a' * 64;
      await repo.updateContentWorkProgress(
        workItemId: work.workItemId,
        state: 'completed',
        artifactsJson: '{}',
        committedObjectsJson: '[]',
        pendingManifestId: manifestId,
      );
      expect(
        await localContentService.executeRelease(
          id,
          work.workItemId,
          manifestId,
        ),
        isTrue,
      );
      expect(service.archives, isEmpty);
      expect(await appDb.select(appDb.archiveDownloaded).get(), isEmpty);
      expect(await root.exists(), isFalse);
    } finally {
      archiveDownloadService = originalArchiveService;
      service.onClose();
    }
  });

  test(
    'paused archive moves its partial ZIP and rebuilds download task',
    () async {
      final root = await Directory(
        '${downloadSetting.downloadPath.value}/Archive - 790 - Partial',
      ).create();
      final copyId = await localContentService.ensureCopy(
        gid: 790,
        representation: 'original',
        rootPath: root.path,
        makeCurrent: false,
      );
      final archive = ArchiveDownloadedData.fromJson(<String, Object?>{
        'gid': 790,
        'token': 'token',
        'title': 'Partial',
        'category': 'Manga',
        'pageCount': 1,
        'galleryUrl': 'https://e-hentai.org/g/790/token/',
        'coverUrl': 'https://example.com/cover.jpg',
        'uploader': null,
        'size': 100,
        'publishTime': '2023-11-14',
        'archiveStatusCode': ArchiveStatus.paused.code,
        'archivePageUrl': 'https://example.com/archive',
        'downloadPageUrl': null,
        'downloadUrl': 'https://example.com/archive.zip',
        'isOriginal': true,
        'insertTime': '2023-11-14',
        'sortOrder': 0,
        'groupName': '',
        'tags': '',
        'tagRefreshTime': null,
        'parseSource': ArchiveParseSource.bot.code,
        'sanitizedTitle': 'Partial',
        'copyId': copyId,
      });
      await appDb.into(appDb.archiveDownloaded).insert(archive);
      final originalRequest = ehRequest;
      ehRequest = _NoProxyRequest();
      final service = ArchiveDownloadService();
      final originalArchiveService = archiveDownloadService;
      try {
        await service.doInitBean();
        archiveDownloadService = service;
        final before = service.archiveDownloadInfos[790]!.downloadTask;
        expect(before, isNotNull);
        final packing = service.computePackingFileDownloadPath(archive);
        await Directory(path.dirname(packing)).create(recursive: true);
        await File(packing).writeAsBytes([1, 2, 3]);
        localContentService.onBeforeRelocation = service.prepareCopyRelocation;
        localContentService.onAfterRelocation = service.finishCopyRelocation;
        await localContentService.relocateCopy(
          copyId,
          '${home.path}/new-download',
        );
        final after = service.archiveDownloadInfos[790]!.downloadTask;
        expect(after, isNotNull);
        expect(identical(before, after), false);
        final moved = service.computePackingFileDownloadPath(
          service.archives.single,
        );
        expect(await File(moved).readAsBytes(), [1, 2, 3]);
        expect(await File(packing).exists(), false);
        expect(
          service.archiveDownloadInfos[790]!.archiveStatus,
          ArchiveStatus.paused,
        );
      } finally {
        ehRequest = originalRequest;
        archiveDownloadService = originalArchiveService;
        service.onClose();
      }
    },
  );
  test('resume all restarts a paused archive after its copy moves', () async {
    final root = await Directory(
      '${downloadSetting.downloadPath.value}/Archive - 794 - Resume',
    ).create();
    final copyId = await localContentService.ensureCopy(
      gid: 794,
      representation: 'original',
      rootPath: root.path,
      makeCurrent: false,
    );
    await appDb
        .into(appDb.archiveDownloaded)
        .insert(
          ArchiveDownloadedData.fromJson(<String, Object?>{
            'gid': 794,
            'token': 'abcdefghij',
            'title': 'Resume',
            'category': 'Manga',
            'pageCount': 1,
            'galleryUrl': 'https://e-hentai.org/g/794/abcdefghij/',
            'coverUrl': 'https://example.com/cover.jpg',
            'uploader': null,
            'size': 100,
            'publishTime': '2023-11-14',
            'archiveStatusCode': ArchiveStatus.paused.code,
            'archivePageUrl': 'https://example.com/archive',
            'downloadPageUrl': null,
            'downloadUrl': null,
            'isOriginal': true,
            'insertTime': '2023-11-14',
            'sortOrder': 0,
            'groupName': '',
            'tags': '',
            'tagRefreshTime': null,
            'parseSource': ArchiveParseSource.official.code,
            'sanitizedTitle': 'Resume',
            'copyId': copyId,
          }),
        );
    final service = ArchiveDownloadService();
    await service.doInitBean();
    final originalRequest = ehRequest;
    final blocked = _BlockedArchiveUnlockRequest();
    ehRequest = blocked;
    final beforeEntered = Completer<void>();
    final releaseBefore = Completer<void>();
    try {
      localContentService.onBeforeRelocation = (id) async {
        await service.prepareCopyRelocation(id);
        beforeEntered.complete();
        await releaseBefore.future;
      };
      localContentService.onAfterRelocation = service.finishCopyRelocation;
      final move = localContentService.relocateCopy(
        copyId,
        '${home.path}/new-download',
      );
      await beforeEntered.future.timeout(const Duration(seconds: 5));
      await service.resumeAllDownloadArchive();
      expect(
        service.archiveDownloadInfos[794]!.archiveStatus,
        ArchiveStatus.paused,
      );
      releaseBefore.complete();
      await move.timeout(const Duration(seconds: 5));
      await blocked.entered.future.timeout(const Duration(seconds: 5));
      expect(
        service.archiveDownloadInfos[794]!.archiveStatus,
        ArchiveStatus.unlocking,
      );
      expect(
        await localContentService.rootPath(copyId),
        path.join(home.path, 'new-download', path.basename(root.path)),
      );
      await service.pauseDownloadArchive(794);

      // Hold the status write so relocation starts after resume observes
      // paused but before it can submit its archive runner.
      final transactionEntered = Completer<void>();
      final releaseTransaction = Completer<void>();
      final transaction = appDb.transaction(() async {
        transactionEntered.complete();
        await releaseTransaction.future;
      });
      await transactionEntered.future;
      final resuming = service.resumeDownloadArchive(794);
      expect(
        service.archiveDownloadInfos[794]!.archiveStatus,
        ArchiveStatus.unlocking,
      );
      localContentService.onBeforeRelocation = service.prepareCopyRelocation;
      final secondMove = localContentService.relocateCopy(
        copyId,
        '${home.path}/third-download',
      );
      await Future<void>.value();
      expect(localContentService.isRelocating(copyId), isTrue);
      releaseTransaction.complete();
      await transaction;
      await resuming;
      await secondMove.timeout(const Duration(seconds: 5));
      await blocked.secondEntered.future.timeout(const Duration(seconds: 5));
      expect(blocked.calls, 2);
      expect(
        service.archiveDownloadInfos[794]!.archiveStatus,
        ArchiveStatus.unlocking,
      );
      expect(
        await localContentService.rootPath(copyId),
        path.join(home.path, 'third-download', path.basename(root.path)),
      );
      await service.pauseDownloadArchive(794);
    } finally {
      if (!releaseBefore.isCompleted) releaseBefore.complete();
      ehRequest = originalRequest;
      service.onClose();
    }
  });
  test('resume all preserves a paused gallery while its copy moves', () async {
    final root = await Directory(
      '${downloadSetting.downloadPath.value}/792 - Moving',
    ).create();
    final copyId = await localContentService.ensureCopy(
      gid: 792,
      representation: 'resampled',
      rootPath: root.path,
      makeCurrent: false,
    );
    await appDb.customStatement(
      '''
      INSERT INTO gallery_downloaded_v2
        (gid,token,title,category,page_count,gallery_url,publish_time,
         download_status_index,insert_time,download_original_image,priority,
         sort_order,group_name,tags,sanitized_title,copy_id)
      VALUES (792,'token','Moving','Manga',1,
        'https://e-hentai.org/g/792/abcdefghij/','2023-11-14',2,
        '2023-11-14',0,4,0,'','','Moving',?)
    ''',
      [copyId],
    );
    final service = GalleryDownloadService();
    await service.doInitBean();
    final originalRequest = ehRequest;
    final blocked = _BlockedReplacementRequest();
    ehRequest = blocked;
    final beforeEntered = Completer<void>();
    final releaseBefore = Completer<void>();
    try {
      localContentService.onBeforeRelocation = (id) async {
        await service.prepareCopyRelocation(id);
        beforeEntered.complete();
        await releaseBefore.future;
      };
      localContentService.onAfterRelocation = service.finishCopyRelocation;
      final move = localContentService.relocateCopy(
        copyId,
        '${home.path}/new-download',
      );
      await beforeEntered.future.timeout(const Duration(seconds: 5));
      expect(localContentService.isRelocating(copyId), isTrue);
      await service.resumeAllDownloadGallery();
      expect(
        service.galleryDownloadInfos[792]!.downloadProgress.downloadStatus,
        DownloadStatus.paused,
      );
      releaseBefore.complete();
      await move.timeout(const Duration(seconds: 5));
      await blocked.entered.future.timeout(const Duration(seconds: 5));
      expect(
        service.galleryDownloadInfos[792]!.downloadProgress.downloadStatus,
        DownloadStatus.downloading,
      );
      expect(
        (await appDb
                .customSelect(
                  'SELECT download_status_index FROM gallery_downloaded_v2 WHERE gid = 792',
                )
                .getSingle())
            .read<int>('download_status_index'),
        DownloadStatus.downloading.index,
      );
      expect(
        await localContentService.rootPath(copyId),
        path.join(home.path, 'new-download', path.basename(root.path)),
      );
      await service.pauseDownloadGallery(service.galleryDownloadInfos[792]!);
    } finally {
      if (!releaseBefore.isCompleted) releaseBefore.complete();
      ehRequest = originalRequest;
      await service.executor.close();
      service.onClose();
    }
  });

  test('moving gallery waits for its ComicInfo write', () async {
    final service = GalleryDownloadService();
    await service.doInitBean();
    final originalRequest = ehRequest;
    final held = _HeldComicInfoRequest();
    ehRequest = held;
    try {
      await service.downloadGallery(
        const GalleryDownloadRequest(
          gid: 793,
          token: 'abcdefghij',
          title: 'Comic info',
          category: 'Manga',
          pageCount: 1,
          galleryUrl: 'https://e-hentai.org/g/793/abcdefghij/',
          publishTime: '2023-11-14',
          downloadOriginalImage: false,
          group: '',
          tags: '',
        ),
      );
      await held.entered.future.timeout(const Duration(seconds: 5));
      final gallery = service.galleryDownloadInfos[793]!;
      final copyId = gallery.copyId!;
      final oldRoot = await localContentService.rootPath(copyId);
      final beforeEntered = Completer<void>();
      final beforeCompleted = Completer<void>();
      localContentService.onBeforeRelocation = (id) async {
        beforeEntered.complete();
        await service.prepareCopyRelocation(id);
        expect(held.release.isCompleted, isTrue);
        beforeCompleted.complete();
      };
      localContentService.onAfterRelocation = service.finishCopyRelocation;
      final move = localContentService.relocateCopy(
        copyId,
        '${home.path}/new-download',
      );
      await beforeEntered.future.timeout(const Duration(seconds: 5));
      expect(localContentService.isRelocating(copyId), isTrue);
      expect(beforeCompleted.isCompleted, isFalse);
      held.release.complete();
      await move.timeout(const Duration(seconds: 5));
      expect(beforeCompleted.isCompleted, isTrue);
      expect(await File(path.join(oldRoot, 'ComicInfo.xml')).exists(), isFalse);
      expect(
        await File(
          path.join(
            await localContentService.rootPath(copyId),
            'ComicInfo.xml',
          ),
        ).exists(),
        isTrue,
      );
    } finally {
      if (!held.release.isCompleted) held.release.complete();
      ehRequest = originalRequest;
      await service.executor.close();
      service.onClose();
    }
  });
  test(
    'legacy archive reader gets owner page identity before moving',
    () async {
      final root = await Directory(
        '${downloadSetting.downloadPath.value}/Archive - 791 - Legacy',
      ).create();
      await File('${root.path}/1.jpg').writeAsBytes([7, 8, 9]);
      final copyId = await localContentService.ensureCopy(
        gid: 791,
        representation: 'original',
        rootPath: root.path,
      );
      await appDb
          .into(appDb.archiveDownloaded)
          .insert(
            ArchiveDownloadedData.fromJson(<String, Object?>{
              'gid': 791,
              'token': 'token',
              'title': 'Legacy',
              'category': 'Manga',
              'pageCount': 1,
              'galleryUrl': 'https://e-hentai.org/g/791/token/',
              'coverUrl': 'https://example.com/cover.jpg',
              'uploader': null,
              'size': 3,
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
              'sanitizedTitle': 'Legacy',
              'copyId': copyId,
            }),
          );
      final service = ArchiveDownloadService();
      await service.doInitBean();
      try {
        final image = (await service.getUnpackedImages(791)).single;
        expect(image.managedPage?.copyId, copyId);
        expect(
          (await localContentService.completedInput(copyId))?.pages,
          hasLength(1),
        );
        localContentService.onBeforeRelocation = service.prepareCopyRelocation;
        localContentService.onAfterRelocation = service.finishCopyRelocation;
        await localContentService.relocateCopy(
          copyId,
          '${home.path}/new-download',
        );
        expect(image.managedPage?.ordinal, 0);
        final bytes = await localContentService.withPageInput(
          image.managedPage!.copyId,
          image.managedPage!.ordinal,
          (file) => file.readAsBytes(),
        );
        expect(bytes, [7, 8, 9]);
      } finally {
        service.onClose();
      }
    },
  );
  test(
    'completed gallery replacement uses relocated owner page path',
    () async {
      final root = await Directory(
        '${downloadSetting.downloadPath.value}/124 - Completed',
      ).create();
      await File('${root.path}/0.jpg').writeAsBytes([1, 2, 3]);
      final copyId = await localContentService.ensureCopy(
        gid: 124,
        representation: 'resampled',
        rootPath: root.path,
      );
      await appDb.customStatement(
        '''
      INSERT INTO gallery_downloaded_v2
        (gid,token,title,category,page_count,gallery_url,publish_time,
         download_status_index,insert_time,download_original_image,priority,
         sort_order,group_name,tags,sanitized_title,copy_id)
      VALUES (124,'token','Completed','Manga',1,
        'https://e-hentai.org/g/124/token/','2023-11-14',4,
        '2023-11-14',0,4,0,'','','Completed',?)
    ''',
        [copyId],
      );
      await appDb.customStatement(
        '''
      INSERT INTO image (gid,url,serialNo,path,imageHash,downloadStatusIndex)
      VALUES (124,'https://example.com/0.jpg',0,?,'',4)
    ''',
        [
          path.relative(
            '${root.path}/0.jpg',
            from: pathService.getVisibleDir().path,
          ),
        ],
      );
      final service = GalleryDownloadService();
      await service.doInitBean();
      final originalRequest = ehRequest;
      final blocked = _BlockedReplacementRequest();
      ehRequest = blocked;
      try {
        final gallery = service.galleryDownloadInfos[124]!;
        await gallery.ensureImagesLoaded();
        final openedImage = gallery.imageAtSync(0)!;
        expect(openedImage.managedPage, isNull);
        localContentService.onBeforeRelocation = service.prepareCopyRelocation;
        localContentService.onAfterRelocation = service.finishCopyRelocation;
        await localContentService.relocateCopy(
          copyId,
          '${home.path}/new-download',
        );
        expect(identical(gallery.imageAtSync(0), openedImage), isTrue);
        expect(openedImage.managedPage?.copyId, copyId);
        expect(
          (await localContentService.completedInput(copyId))?.pages,
          hasLength(1),
        );
        expect(
          gallery.imageAtSync(0)!.path,
          path.relative(
            '${root.path}/0.jpg',
            from: pathService.getVisibleDir().path,
          ),
        );
        await service.reDownloadImage(124, 0);
        await blocked.entered.future.timeout(const Duration(seconds: 5));
        final pending = await localContentService.repository
            .listPageReplacements(copyId);
        expect(
          pending.single.newPath,
          path.join(await localContentService.rootPath(copyId), '0.jpg'),
        );
        await service
            .deleteGallery(gallery)
            .timeout(const Duration(seconds: 5));
      } finally {
        ehRequest = originalRequest;
        await service.executor.close();
        service.onClose();
      }
    },
  );
  test(
    'complete content restores without a task and keeps manifest page order',
    () async {
      final root = await Directory(
        '${downloadSetting.downloadPath.value}/standalone',
      ).create();
      await File('native/tests/fixtures/minimal.jpg')
          .copy('${root.path}/z.jpg');
      await File('native/tests/fixtures/minimal.png')
          .copy('${root.path}/a.png');
      final id = await localContentService.ensureCopy(
        gid: 501,
        representation: 'unspecified',
        rootPath: root.path,
      );
      for (final (ordinal, name) in [(0, 'z.jpg'), (1, 'a.png')]) {
        await localContentService.recordPage(
          copyId: id,
          ordinal: ordinal,
          relativePath: name,
        );
      }
      await localContentService.completeCopy(
        id,
        galleryUrl: 'https://e-hentai.org/g/501/token/',
        title: 'Independent content',
        expectedPages: 2,
      );
      await freshDatabase();
      expect(await localContentService.restoreContentDirectories(), 1);
      final restored = await localContentService.completedInput(id);
      expect(restored!.representation, 'unspecified');
      expect(restored.pages.map((page) => page.relativePath), [
        'z.jpg',
        'a.png',
      ]);
      expect(await appDb.select(appDb.galleryDownloaded).get(), isEmpty);
      expect(await appDb.select(appDb.archiveDownloaded).get(), isEmpty);
      final oldLocal = localGalleryService;
      localGalleryService = LocalGalleryService();
      try {
        await localGalleryService.doInitBean();
        final entry = localGalleryService.allGalleries.single;
        expect(entry.copyId, id);
        final info = await localContentService.readPageInfoForCopy(
          id,
          initialIndex: 1,
        );
        expect(info.readProgressRecordStorageKey, '501');
        expect(info.initialIndex, 1);
        expect(info.images!.map((image) => path.basename(image.path!)), [
          'z.jpg',
          'a.png',
        ]);
        await localGalleryService.deleteGallery(entry, path.dirname(root.path));
        expect(localGalleryService.allGalleries, isEmpty);
        expect(await root.exists(), isFalse);
      } finally {
        localGalleryService = oldLocal;
      }
    },
  );

  test(
    'failed sidecar write keeps main-db content readable and rebuildable',
    () async {
      final root = await Directory(
        '${downloadSetting.downloadPath.value}/projection-error',
      ).create();
      await File('native/tests/fixtures/minimal.png')
          .copy('${root.path}/page.png');
      final blocked = await Directory('${root.path}/.content.sqlite').create();
      final id = await localContentService.ensureCopy(
        gid: 502,
        representation: 'unspecified',
        rootPath: root.path,
      );
      await localContentService.recordPage(
        copyId: id,
        ordinal: 0,
        relativePath: 'page.png',
      );
      await localContentService.completeCopy(
        id,
        galleryUrl: 'https://e-hentai.org/g/502/token/',
        title: 'Durable content',
        expectedPages: 1,
      );
      expect(
        (await localContentService.completedInput(id))!.title,
        'Durable content',
      );
      final metadata =
          (await appDb
                  .customSelect('SELECT metadata_json FROM content_copy')
                  .getSingle())
              .read<String>('metadata_json');
      expect(jsonDecode(metadata), isNot(contains('gallery')));
      await blocked.delete();
      await localContentService.rebuildProjection(id);
      expect(
        localContentService.readProjection(root.path).completeManifest!.gid,
        502,
      );
    },
  );
  test('same-version independent copies all remain visible after directory restore', () async {
    final ids = <String>[];
    for (final name in ['minimal.jpg', 'minimal.png']) {
      final root = await Directory(
        '${downloadSetting.downloadPath.value}/$name-copy',
      ).create();
      await File('native/tests/fixtures/$name').copy('${root.path}/$name');
      final id = await localContentService.ensureCopy(
        gid: 503,
        representation: 'unspecified',
        rootPath: root.path,
      );
      await localContentService.recordPage(
        copyId: id,
        ordinal: 0,
        relativePath: name,
      );
      await localContentService.completeCopy(
        id,
        galleryUrl: 'https://e-hentai.org/g/503/token/',
        title: 'Same gallery',
        expectedPages: 1,
      );
      ids.add(id);
    }
    final source = '${downloadSetting.downloadPath.value}/minimal.jpg-copy';
    final clone = await Directory('${downloadSetting.downloadPath.value}/clone')
        .create();
    await File('$source/minimal.jpg').copy('${clone.path}/minimal.jpg');
    await File('$source/.content.sqlite').copy('${clone.path}/.content.sqlite');
    await freshDatabase();
    expect(await localContentService.restoreContentDirectories(), 3);
    final copies = await localContentService.standaloneCopies();
    expect(copies, hasLength(3));
    expect(copies.map((copy) => copy.copyId), containsAll(ids));
    expect(copies.map((copy) => copy.copyId).toSet(), hasLength(3));
    for (final copy in copies) {
      expect(
        localContentService.readProjection(copy.rootPath).copyId,
        copy.copyId,
      );
    }
    for (final id in ids) {
      final info = await localContentService.readPageInfoForCopy(id);
      expect(info.pageCount, 1);
    }
    final rebound = copies.singleWhere((copy) => !ids.contains(copy.copyId));
    final replacement = await localContentService.enqueuePageReplacement(
      copyId: rebound.copyId,
      ordinal: 0,
      newRelativePath: 'replacement.png',
    );
    final bytes = await File('native/tests/fixtures/minimal.png').readAsBytes();
    await File(replacement.tempPath).writeAsBytes(bytes);
    final hash = sha256.convert(bytes).toString();
    await localContentService.finishDownloadedReplacement(
      replacement.replacementId,
      rawHash: hash,
      rawLength: bytes.length,
    );
    final updated = localContentService.readProjection(rebound.rootPath);
    expect(updated.copyId, rebound.copyId);
    expect(updated.completeManifest!.pages.single.rawHash, hash);
    await freshDatabase();
    expect(await localContentService.restoreContentDirectories(), 3);
    expect(
      (await localContentService.repository.listPages(rebound.copyId))
          .single
          .rawHash,
      hash,
    );
  });
}
