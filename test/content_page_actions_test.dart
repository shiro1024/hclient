import 'dart:io';
import 'dart:ui' show AppLifecycleState;
import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/model/detail_page_info.dart';
import 'package:jhentai/src/model/gallery_image.dart';
import 'package:jhentai/src/model/gallery_thumbnail.dart';
import 'package:jhentai/src/model/read_page_info.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/service/content_page_download_service.dart';
import 'package:jhentai/src/service/transfer_activity_service.dart';
import 'package:jhentai/src/service/content_codec.dart';
import 'package:jhentai/src/pages/read/read_page_state.dart';
import 'package:jhentai/src/service/content_sync/content_repository.dart';
import 'package:jhentai/src/service/gallery_download/gallery_download_service.dart';
import 'package:jhentai/src/service/local_content_service.dart';
import 'package:jhentai/src/service/download_relocation_service.dart';
import 'package:jhentai/src/service/gallery_sync/gallery_sync_service.dart';
import 'package:jhentai/src/service/log.dart';
import 'package:jhentai/src/service/path_service.dart';
import 'package:jhentai/src/utils/eh_spider_parser.dart';

import 'support/test_log_service.dart';

class _SourceRequest extends EHRequest {
  List<int> bytes = [4, 5, 6];
  String? mime = 'image/png';
  int detailCalls = 0;
  int imageCalls = 0;
  bool failDownload = false;
  String? downloadedUrl;
  bool blockSource = false;
  bool unblockAfterCancel = false;
  int transientFailures = 0;
  String? downloadedPath;
  final downloaded = Completer<void>();
  final sourceStarted = Completer<void>();

  @override
  Future<T> requestDetailPage<T>({
    required String galleryUrl,
    int thumbnailsPageIndex = 0,
    bool useCacheIfAvailable = true,
    CancelToken? cancelToken,
    required HtmlParser<T> parser,
  }) async {
    detailCalls++;
    if (!sourceStarted.isCompleted) sourceStarted.complete();
    if (blockSource) {
      final cancelled = await cancelToken!.whenCancel;
      if (unblockAfterCancel) blockSource = false;
      throw cancelled;
    }
    expect(galleryUrl, 'https://e-hentai.org/g/41/0123456789/');
    return DetailPageInfo(
      imageNoFrom: 0,
      imageNoTo: 0,
      imageCount: 1,
      currentPageNo: 1,
      pageCount: 1,
      thumbnails: [
        GalleryThumbnail(
          href: 'https://e-hentai.org/s/abcdefghij/41-1',
          isLarge: false,
          thumbUrl: '',
        ),
      ],
    ) as T;
  }

  @override
  Future<T> requestImagePage<T>(
    String href, {
    String? reloadKey,
    CancelToken? cancelToken,
    bool useCacheIfAvailable = true,
    required HtmlParser<T> parser,
  }) async {
    imageCalls++;
    expect(href, 'https://e-hentai.org/s/abcdefghij/41-1');
    expect(useCacheIfAvailable, isFalse);
    return GalleryImage(
      url: 'https://example.org/resampled.png',
      originalImageUrl: 'https://example.org/original.png',
    ) as T;
  }

  @override
  Future<({Response<ResponseBody> response, String rawHash, int rawLength})>
  downloadWithHash({
    required String url,
    required String path,
    ProgressCallback? onReceiveProgress,
    CancelToken? cancelToken,
    int? receiveTimeout,
  }) async {
    downloadedUrl = url;
    downloadedPath = path;
    if (transientFailures > 0) {
      transientFailures--;
      throw DioException(
        requestOptions: RequestOptions(path: url),
        type: DioExceptionType.connectionError,
      );
    }
    if (failDownload) throw StateError('network unavailable');
    await File(path).writeAsBytes(bytes);
    if (!downloaded.isCompleted) downloaded.complete();
    return (
      response: Response<ResponseBody>(
        requestOptions: RequestOptions(path: url),
        headers: Headers.fromMap({
          if (mime != null) 'content-type': [mime!],
        }),
      ),
      rawHash: sha256.convert(bytes).toString(),
      rawLength: bytes.length,
    );
  }
}

GalleryDownloadInfo _task(String copyId, List<GalleryImage?> images) =>
    GalleryDownloadInfo(
      gid: 41,
      token: '0123456789',
      galleryUrl: 'https://e-hentai.org/g/41/0123456789/',
      title: 'Gallery',
      category: 'Manga',
      pageCount: 1,
      thumbnailsCountPerPage: 20,
      tasks: [],
      cancelToken: CancelToken(),
      downloadProgress: GalleryDownloadProgress(
        curCount: 0,
        totalCount: 1,
        downloadStatus: DownloadStatus.downloading,
      ),
      imageHrefs: [null],
      images: images,
      priority: 0,
      sortOrder: 0,
      group: '',
      downloadOriginalImage: true,
      tags: '',
      tagRefreshTime: null,
      publishTime: '',
      insertTime: '',
      copyId: copyId,
      onSpeedUpdate: () {},
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  late AppDb db;
  late LocalContentService oldOwner;
  late Directory? oldDoc;
  late LogService oldLog;
  late EHRequest oldRequest;
  late GalleryDownloadService oldDownload;
  late _SourceRequest request;
  late String copyId;
  late ContentPageDownloadService actions;
  late ContentPageDownloadService oldPageDownload;
  late GallerySyncService oldSync;

  setUp(() async {
    oldOwner = localContentService;
    oldPageDownload = contentPageDownloadService;
    oldSync = gallerySyncService;
    gallerySyncService = _LocalSyncPeer();
    oldDoc = pathService.appDocDir;
    oldLog = log;
    oldRequest = ehRequest;
    oldDownload = galleryDownloadService;
    log = TestLogService();
    request = _SourceRequest();
    ehRequest = request;
    galleryDownloadService = GalleryDownloadService();
    temp = await Directory.systemTemp.createTemp('hclient-content-actions-');
    pathService.appDocDir = temp;
    db = AppDb.testing(NativeDatabase.memory());
    localContentService = LocalContentService(
      repository: ContentRepository(db),
    );
    actions = ContentPageDownloadService();
    contentPageDownloadService = actions;
    await DownloadRelocationService().doInitBean();
    final root = await Directory('${temp.path}/gallery').create();
    await File('${root.path}/001.png').writeAsBytes([1, 2, 3]);
    copyId = await localContentService.ensureCopy(
      gid: 41,
      representation: 'original',
      rootPath: root.path,
      makeCurrent: false,
    );
    await localContentService.recordPage(
      copyId: copyId,
      ordinal: 0,
      relativePath: '001.png',
      rawHash: sha256.convert([1, 2, 3]).toString(),
      rawLength: 3,
    );
    await localContentService.completeCopy(
      copyId,
      galleryUrl: 'https://e-hentai.org/g/41/0123456789/',
      title: 'Gallery',
      expectedPages: 1,
    );
  });
  tearDown(() async {
    localContentService = oldOwner;
    contentPageDownloadService = oldPageDownload;
    gallerySyncService = oldSync;
    actions.dispose();
    pathService.appDocDir = oldDoc;
    log = oldLog;
    ehRequest = oldRequest;
    galleryDownloadService = oldDownload;
    Get.reset();
    await db.close();
    await temp.delete(recursive: true);
  });

  test('public redownload waits through system settlement and then performs the replacement', () async {
    final owner = Object();
    final settled = Completer<void>();
    transferActivityService.register(
      owner,
      suspend: () => settled.future,
      resume: () async {},
    );
    transferActivityService.suspendForSystemTimeout();
    var completed = false;
    final redownload = actions.redownload(copyId, 0).then((_) {
      completed = true;
    });
    final resumed = transferActivityService.handleLifecycle(
      AppLifecycleState.resumed,
    );
    await Future<void>.delayed(Duration.zero);
    expect(completed, isFalse);
    expect(request.detailCalls, 0);
    settled.complete();
    await resumed;
    await redownload;
    expect(completed, isTrue);
    expect(request.downloadedUrl, 'https://example.org/original.png');
    expect(
      await localContentService.readPageForDisplay(copyId, 0),
      request.bytes,
    );
    transferActivityService.unregister(owner);
  });

  for (final sameContent in [false, true]) {
    test(sameContent ? 'same-content redownload preserves PCF residency' : 'PCF redownload restores raw path and MIME when response has no type', () async {
      final bytes = await File('native/tests/fixtures/gradient.png')
          .readAsBytes();
      final root = await localContentService.rootPath(copyId);
      await File('$root/001.png').writeAsBytes(bytes);
      await localContentService.recordPage(
        copyId: copyId,
        ordinal: 0,
        relativePath: '001.png',
        rawHash: sha256.convert(bytes).toString(),
        rawLength: bytes.length,
        mime: 'image/png',
      );
      final work = await localContentService.representationWorkDirectory(
        copyId,
        'test',
      );
      final artifact = await ContentCodec().encodeFile(
        inputPath: '$root/001.png',
        outputPath: '${work.path}/candidate',
      );
      expect(
        await localContentService.installPageRepresentation(
          copyId: copyId,
          ordinal: 0,
          artifact: artifact,
        ),
        isTrue,
      );
      final before = await localContentService.repository.getPage(copyId, 0);
      expect(before.relativePath, '001.png.pcf');
      request.mime = null;
      request.bytes = sameContent ? bytes : [7, 8, 9];
      await actions.redownload(copyId, 0);
      final after = await localContentService.repository.getPage(copyId, 0);
      expect(after.mime, 'image/png');
      expect(after.relativePath, sameContent ? '001.png.pcf' : '001.png');
      expect(
        after.codecProfile,
        sameContent ? ContentCodec.encodedProfile : isNull,
      );
      expect(
        (await localContentService.readPageForExport(copyId, 0)).bytes,
        request.bytes,
      );
      expect(await File('$root/001.png.pcf').exists(), sameContent);
      await ContentCodec().close();
    });
  }

  test('complete reading owns stable page input without task records or website access', () async {
    final info = await localContentService.readPageInfoForCopy(copyId);
    Get.routing.args = info;
    final state = ReadPageState();
    expect(info.contentCopyId, copyId);
    expect(info.gid, 41);
    expect(info.representation, 'original');
    expect(info.token, '0123456789');
    expect(state.images.single!.managedPage!.copyId, copyId);
    expect(
      await localContentService.withPageInput(
        copyId,
        0,
        (file) => file.readAsBytes(),
      ),
      [1, 2, 3],
    );
    expect(request.detailCalls, 0);
    expect(request.imageCalls, 0);
    state.focusNode.dispose();
  });

  test('incomplete reader survives handoff and ignores a new task for the same gid', () async {
    final live = <GalleryImage?>[null];
    final original = _task(copyId, live);
    galleryDownloadService.galleryDownloadInfos[41] = original;
    Get.routing.args = ReadPageInfo(
      mode: ReadMode.downloaded,
      gid: 41,
      token: '0123456789',
      galleryTitle: 'Gallery',
      galleryUrl: original.galleryUrl,
      initialIndex: 0,
      pageCount: 1,
      readProgressRecordStorageKey: '41',
    );
    final state = ReadPageState();
    expect(state.images.single, isNull);
    expect(state.readPageInfo.mode, ReadMode.downloaded);
    live[0] = (await localContentService.readPageInfoForCopy(copyId))
        .images!
        .single;
    original.downloadProgress.downloadStatus = DownloadStatus.downloaded;
    galleryDownloadService.galleryDownloadInfos.remove(41);
    galleryDownloadService.galleryDownloadInfos[41] = _task('another-copy', [
      null,
    ]);
    expect(state.images.single!.managedPage!.copyId, copyId);
    expect(state.readPageInfo.mode, ReadMode.local);
    expect(state.readPageInfo.contentCopyId, copyId);
    expect(
      await localContentService.withPageInput(
        copyId,
        0,
        (file) => file.readAsBytes(),
      ),
      [1, 2, 3],
    );
    state.focusNode.dispose();
  });

  test(
    'explicit source lookup persists URL and the next action stays local',
    () async {
      expect(
        await actions.sourcePageUrl(copyId, 0),
        'https://e-hentai.org/s/abcdefghij/41-1',
      );
      expect(request.detailCalls, 1);
      expect(
        await actions.sourcePageUrl(copyId, 0),
        'https://e-hentai.org/s/abcdefghij/41-1',
      );
      expect(request.detailCalls, 1);
      expect(
        (await localContentService.repository.getPage(copyId, 0)).sourcePageUrl,
        'https://e-hentai.org/s/abcdefghij/41-1',
      );
      expect(galleryDownloadService.galleryDownloadInfos, isEmpty);
    },
  );

  test('partial original copy chooses its owner representation without reader defaults', () async {
    await db.customStatement(
      'UPDATE content_copy SET metadata_json=NULL WHERE copy_id=?',
      [copyId],
    );
    await actions.redownload(
      copyId,
      0,
      galleryUrl: 'https://e-hentai.org/g/41/0123456789/',
    );
    expect(request.downloadedUrl, 'https://example.org/original.png');
    expect(galleryDownloadService.galleryDownloadInfos, isEmpty);
  });

  test('ready replacement commits while the website is unavailable', () async {
    final replacement = await localContentService.enqueuePageReplacement(
      copyId: copyId,
      ordinal: 0,
      newRelativePath: '001.png',
    );
    await File(replacement.tempPath).writeAsBytes([4, 5, 6]);
    await localContentService.repository.setPageReplacementReady(
      replacement.replacementId,
      jsonEncode({
        'rawHash': sha256.convert([4, 5, 6]).toString(),
        'rawLength': 3,
        'mime': 'image/png',
      }),
    );
    request.blockSource = true;
    await actions.redownload(copyId, 0);
    expect(request.detailCalls, 0);
    expect(request.imageCalls, 0);
    expect(
      await localContentService.withPageInput(
        copyId,
        0,
        (file) => file.readAsBytes(),
      ),
      [4, 5, 6],
    );
  });

  test('same-page journals drain in order including a ready head and a queued download', () async {
    final first = await localContentService.enqueuePageReplacement(
      copyId: copyId,
      ordinal: 0,
      newRelativePath: '001.png',
    );
    await File(first.tempPath).writeAsBytes([4, 5, 6]);
    await localContentService.repository.setPageReplacementReady(
      first.replacementId,
      jsonEncode({
        'rawHash': sha256.convert([4, 5, 6]).toString(),
        'rawLength': 3,
        'mime': 'image/png',
      }),
    );
    await localContentService.enqueuePageReplacement(
      copyId: copyId,
      ordinal: 0,
      newRelativePath: '001.png',
    );
    var notifications = 0;
    actions.addListener(() => notifications++);
    await actions.redownload(copyId, 0);
    expect(request.imageCalls, 1);
    expect(notifications, 2);
    expect(
      await localContentService.repository.listPageReplacements(copyId),
      isEmpty,
    );
  });

  test(
    'transient download failures reparse the image before retrying',
    () async {
      request.transientFailures = 1;
      await actions.redownload(copyId, 0);
      expect(request.imageCalls, 2);
      expect(
        await localContentService.withPageInput(
          copyId,
          0,
          (file) => file.readAsBytes(),
        ),
        [4, 5, 6],
      );
    },
  );

  test(
    'startup resumes an active owner journal without a gallery task',
    () async {
      await localContentService.enqueuePageReplacement(
        copyId: copyId,
        ordinal: 0,
        newRelativePath: '001.png',
      );
      final done = Completer<void>();
      actions.addListener(() {
        if (!done.isCompleted) done.complete();
      });
      await actions.resumePendingReplacements();
      await done.future.timeout(const Duration(seconds: 10));
      expect(
        await localContentService.repository.listPageReplacements(copyId),
        isEmpty,
      );
      expect(galleryDownloadService.galleryDownloadInfos, isEmpty);
    },
  );

  test('real relocation coordinator keeps a running owner action and resumes at the new root', () async {
    request.blockSource = true;
    request.unblockAfterCancel = true;
    final running = actions.redownload(copyId, 0);
    final cancelled = expectLater(
      running,
      throwsA(
        isA<DioException>().having(
          (error) => CancelToken.isCancel(error),
          'cancelled',
          isTrue,
        ),
      ),
    );
    await request.sourceStarted.future;
    final complete = Completer<void>();
    actions.addListener(() {
      if (!complete.isCompleted) complete.complete();
    });
    await localContentService.relocateCopy(copyId, '${temp.path}/moved');
    await cancelled;
    await complete.future.timeout(const Duration(seconds: 10));
    expect(request.downloadedPath, startsWith('${temp.path}/moved/'));
    expect(
      await localContentService.withPageInput(
        copyId,
        0,
        (file) => file.readAsBytes(),
      ),
      [4, 5, 6],
    );
    expect(
      await localContentService.repository.listPageReplacements(copyId),
      isEmpty,
    );
  });

  test('real retirement callback cancels and joins a source request before retiring its copy', () async {
    request.blockSource = true;
    final upload = await localContentService.repository.createWorkItem(
      kind: 'content',
      targetNamespace: 'cloud',
      inputJson: '{}',
      copyId: copyId,
      finishAction: 'release',
    );
    final downloading = actions.redownload(copyId, 0);
    final stopped = expectLater(
      downloading,
      throwsA(
        isA<DioException>().having(
          (error) => CancelToken.isCancel(error),
          'cancelled',
          isTrue,
        ),
      ),
    );
    await request.sourceStarted.future;
    expect(
      (await localContentService.repository.getWorkItem(upload.workItemId))!
          .finishAction,
      'keep',
    );
    expect(
      await localContentService.repository.listPageReplacements(copyId),
      hasLength(1),
    );
    await localContentService.retireCopy(copyId);
    await stopped;
    expect(
      await localContentService.repository.listPageReplacements(copyId),
      isEmpty,
    );
    expect(await Directory('${temp.path}/gallery').exists(), isFalse);
  });

  test('retirement settles a failed downloading replacement without an active request', () async {
    request.failDownload = true;
    await expectLater(actions.redownload(copyId, 0), throwsStateError);
    await localContentService.retireCopy(copyId);
    expect(
      await localContentService.repository.listPageReplacements(copyId),
      isEmpty,
    );
  });

  test('owner page redownload keeps the old file on failure then replaces without rebuilding a task', () async {
    request.failDownload = true;
    await expectLater(actions.redownload(copyId, 0), throwsStateError);
    expect(
      await localContentService.withPageInput(
        copyId,
        0,
        (file) => file.readAsBytes(),
      ),
      [1, 2, 3],
    );
    request.failDownload = false;
    await actions.redownload(copyId, 0);
    expect(request.downloadedUrl, 'https://example.org/original.png');
    expect(request.detailCalls, 1);
    expect(
      await localContentService.withPageInput(
        copyId,
        0,
        (file) => file.readAsBytes(),
      ),
      [4, 5, 6],
    );
    expect(
      (await localContentService.repository.getPage(copyId, 0)).sourcePageUrl,
      'https://e-hentai.org/s/abcdefghij/41-1',
    );
    expect(galleryDownloadService.galleryDownloadInfos, isEmpty);
    expect(
      await localContentService.repository.listPageReplacements(copyId),
      isEmpty,
    );
  });
}

class _LocalSyncPeer extends GallerySyncService {
  @override
  Future<void> prepareCopyRelocation(String copyId) async {}
  @override
  Future<void> finishCopyRelocation(String copyId, bool usable) async {}
}
