import 'transfer_activity_service.dart';
import 'screen_awake_service.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_instance/get_instance.dart';
import 'package:get/get_rx/get_rx.dart';
import 'package:get/get_state_manager/src/simple/get_controllers.dart';
import 'package:get/get_utils/get_utils.dart';
import 'package:intl/intl.dart';
import 'package:jhentai/src/service/archive_downloader/j_downloader.dart';
import 'package:jhentai/src/database/dao/archive_group_dao.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/exception/eh_site_exception.dart';
import 'package:jhentai/src/extension/dio_exception_extension.dart';
import 'package:jhentai/src/model/archive_bot_response/archive_bot_response.dart';
import 'package:jhentai/src/model/archive_bot_response/archive_resolve_vo.dart';
import 'package:jhentai/src/model/archive_unlock_result.dart';
import 'package:jhentai/src/network/archive_bot_request.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/service/path_service.dart';
import 'package:jhentai/src/setting/archive_bot_setting.dart';
import 'package:jhentai/src/setting/download_setting.dart';
import 'package:jhentai/src/setting/network_setting.dart';
import 'package:jhentai/src/utils/eh_spider_parser.dart';
import 'package:jhentai/src/utils/speed_computer.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart';
import 'package:retry/retry.dart';

import '../consts/locale_consts.dart';
import '../database/dao/archive_dao.dart';
import '../exception/cancel_exception.dart';
import '../model/comic_info.dart';
import '../model/gallery_detail.dart';
import '../model/gallery_image.dart';
import '../pages/download/grid/mixin/grid_download_page_service_mixin.dart';
import '../utils/archive_util.dart';
import '../utils/file_util.dart';
import '../utils/snack_util.dart';
import 'gallery_download/download_path_resolver.dart';
import 'gallery_download/gallery_download_service.dart';
import 'jh_service.dart';
import 'log.dart';
import 'local_content_service.dart';
import 'content_sync/portable_manifest.dart';
import '../utils/convert_util.dart';

ArchiveDownloadService archiveDownloadService = ArchiveDownloadService();

class ArchiveDownloadService extends GetxController
    with GridBasePageServiceMixin, JHLifeCircleBeanErrorCatch
    implements JHLifeCircleBean {
  static const String archiveStatusId = 'archiveStatusId';
  static const String archiveSpeedComputerId = 'archiveSpeedComputerId';

  final Set<int> _systemSuspended = {};

  Future<void> _suspendForSystem() async {
    final stopping = <Future<void>>[];
    for (final entry in archiveDownloadInfos.entries) {
      final info = entry.value;
      if (info.archiveStatus.code <= ArchiveStatus.paused.code ||
          info.archiveStatus.code >= ArchiveStatus.completed.code)
        continue;
      _systemSuspended.add(entry.key);
      info.cancelToken.cancel('System dataSync timeout');
      final completer = info.downloadCompleter;
      if (completer != null && !completer.isCompleted)
        completer.completeError(CancelException());
      info.speedComputer.pause();
      if (info.downloadTask case final task?) stopping.add(task.pause());
    }
    _updateScreenAwake();
    await Future.wait(stopping);
    await Future.wait([
      for (final runs in _downloadRuns.values)
        ...runs.map((run) => run.catchError((Object _, StackTrace __) {})),
    ]);
  }

  Future<void> _resumeAfterSystem() async {
    final ids = _systemSuspended.toList();
    _systemSuspended.clear();
    for (final gid in ids) {
      final info = archiveDownloadInfos[gid];
      final archive = archives.firstWhereOrNull((item) => item.gid == gid);
      if (info == null ||
          archive == null ||
          info.archiveStatus.code <= ArchiveStatus.paused.code ||
          info.archiveStatus == ArchiveStatus.completed)
        continue;
      info.cancelToken = CancelToken();
      unawaited(downloadArchive(archive, resume: true));
    }
  }

  void _updateScreenAwake() {
    transferActivityService.replace(this, [
      for (final archive in archives)
        if (archiveDownloadInfos[archive.gid] case final info?)
          if (!_systemSuspended.contains(archive.gid) &&
              (info.archiveStatus == ArchiveStatus.waitingIsolate ||
                  _downloadRuns.containsKey(archive.gid)) &&
              info.archiveStatus.code > ArchiveStatus.paused.code &&
              info.archiveStatus.code < ArchiveStatus.completed.code)
            TransferActivity(
              id: 'archive:${archive.gid}',
              copyId: archive.copyId,
              title: archive.title,
              target: 'archive',
              phase: info.archiveStatus.name,
              readProgress: () =>
                  info.archiveStatus == ArchiveStatus.downloading
                  ? info.downloadTask?.currentBytes
                  : null,
              readTotal: () =>
                  info.archiveStatus == ArchiveStatus.downloading &&
                      info.size > 0
                  ? info.size
                  : null,
              byteProgress: true,
              waiting: info.archiveStatus == ArchiveStatus.waitingIsolate,
              bytesPerSecond: () => info.speedComputer.bytesPerSecond,
            ),
    ]);
    final waiting = archiveDownloadInfos.values.any(
      (info) => info.archiveStatus == ArchiveStatus.waitingIsolate,
    );
    final running = _downloadRuns.keys.any((gid) {
      final status = archiveDownloadInfos[gid]?.archiveStatus;
      return status == null ||
          (status.code > ArchiveStatus.paused.code &&
              status.code < ArchiveStatus.completed.code);
    });
    screenAwakeService.setRequested(this, waiting || running);
  }

  @override
  void update([List<Object>? ids, bool condition = true]) {
    if (condition &&
        (ids == null ||
            ids.any(
              (id) =>
                  id == galleryCountChangedId ||
                  id.toString().startsWith(archiveStatusId),
            ))) {
      _updateScreenAwake();
    }
    super.update(ids, condition);
  }

  static const int _maxRetryTimes = 3;
  static const String metadataFileName = 'ametadata';
  static const int _maxIsolateCountsTotal = 10;

  final Completer<bool> _completer = Completer();

  Future<bool> get completed => _completer.future;

  List<String> allGroups = [];
  List<ArchiveDownloadedData> archives = <ArchiveDownloadedData>[];
  Map<int, ArchiveDownloadInfo> archiveDownloadInfos = {};
  final Map<int, Future<void>> _unpackingRuns = {};
  final Map<int, Future<void>> _comicInfoRuns = {};
  final Map<int, Set<Future<void>>> _downloadRuns = {};
  final Set<String> _resumeAfterRelocation = {};

  Future<void> stopCopyDownloads(String copyId) async {
    final archive = archives.firstWhereOrNull((item) => item.copyId == copyId);
    if (archive == null) return;
    final info = archiveDownloadInfos[archive.gid];
    if (info == null) return;
    await pauseDownloadArchive(archive.gid);
    await Future.wait(
      [
        ...?_downloadRuns[archive.gid]?.toList(),
        if (_comicInfoRuns[archive.gid] case final run?) run,
        if (_unpackingRuns[archive.gid] case final run?) run,
      ].map((run) => run.catchError((Object _, StackTrace __) {})),
    );
    await info.downloadTask?.dispose();
    info.downloadTask = null;
  }

  Future<void> prepareCopyRelocation(String copyId) async {
    final archive = archives.firstWhereOrNull((item) => item.copyId == copyId);
    if (archive == null) return;
    final info = archiveDownloadInfos[archive.gid];
    if (info == null) return;
    final wasActive =
        info.archiveStatus.code > ArchiveStatus.paused.code &&
        info.archiveStatus.code < ArchiveStatus.downloaded.code;
    if (wasActive) {
      _resumeAfterRelocation.add(copyId);
    }
    await stopCopyDownloads(copyId);
  }

  Future<void> finishCopyRelocation(String copyId, bool usable) async {
    if (!usable) return;
    final resume = _resumeAfterRelocation.remove(copyId);
    final archive = archives.firstWhereOrNull((item) => item.copyId == copyId);
    if (archive == null) return;
    final info = archiveDownloadInfos[archive.gid];
    if (info == null) return;
    if (info.downloadUrl != null &&
        info.archiveStatus.code < ArchiveStatus.downloaded.code) {
      info.downloadTask = _generateDownloadTask(info.downloadUrl!, archive);
    }
    if (resume) {
      if (info.archiveStatus == ArchiveStatus.paused) {
        await resumeDownloadArchive(archive.gid);
      } else if (info.archiveStatus.code > ArchiveStatus.paused.code &&
          info.archiveStatus.code < ArchiveStatus.downloaded.code) {
        downloadArchive(archive, resume: true);
      }
    }
  }

  List<ArchiveDownloadedData> archivesWithGroup(String group) => archives
      .where((g) => archiveDownloadInfos[g.gid]!.group == group)
      .toList();

  late Worker isolateCountListener;
  late Worker proxyConfigListener;
  late Worker timeoutListener;

  @override
  List<JHLifeCircleBean> get initDependencies =>
      super.initDependencies..addAll([
        downloadSetting,
        networkSetting,
        localContentService,
        screenAwakeService,
        transferActivityService,
      ]);

  @override
  Future<void> doInitBean() async {
    transferActivityService.register(
      this,
      suspend: _suspendForSystem,
      resume: _resumeAfterSystem,
    );
    Get.put(this, permanent: true);

    await _instantiateFromDB();

    log.debug('Archive download tasks count: ${archives.length}');

    for (ArchiveDownloadedData archive in archives) {
      if (archive.archiveStatusCode >= ArchiveStatus.unlocking.code &&
          archive.archiveStatusCode <= ArchiveStatus.unpacking.code) {
        downloadArchive(archive, resume: true);
      }
    }

    _completer.complete(true);

    isolateCountListener = ever(
      downloadSetting.archiveDownloadIsolateCount,
      (_) => _onIsolateCountChange(),
    );
    proxyConfigListener = everAll([
      networkSetting.proxyAddress,
      networkSetting.proxyUsername,
      networkSetting.proxyPassword,
    ], (_) => _onProxyConfigChange());
    timeoutListener = everAll([
      networkSetting.connectTimeout,
      networkSetting.receiveTimeout,
    ], (_) => _onTimeoutChange());

    if (downloadSetting.restoreTasksAutomatically.isTrue) {
      await restoreTasks();
    }
  }

  @override
  Future<void> doAfterBeanReady() async {}

  @override
  void onClose() {
    transferActivityService.unregister(this);
    screenAwakeService.setRequested(this, false);
    super.dispose();

    isolateCountListener.dispose();
    proxyConfigListener.dispose();
    timeoutListener.dispose();
  }

  bool containArchive(int gid) {
    return archiveDownloadInfos.containsKey(gid);
  }

  Future<void> downloadArchive(
    ArchiveDownloadedData archive, {
    bool resume = false,
    bool reParse = false,
  }) async {
    await transferActivityService.whenAdmitted;
    if (archive.copyId case final id?) {
      if (localContentService.isRelocating(id)) {
        if (resume) _resumeAfterRelocation.add(id);
        return Future<void>.value();
      }
    }
    final run = _downloadArchive(archive, resume: resume, reParse: reParse);
    final runs = _downloadRuns.putIfAbsent(archive.gid, () => <Future<void>>{});
    runs.add(run);
    _updateScreenAwake();
    void removeRun() {
      runs.remove(run);
      if (runs.isEmpty) _downloadRuns.remove(archive.gid);
      _updateScreenAwake();
    }

    run.then<void>(
      (_) => removeRun(),
      onError: (Object _, StackTrace __) {
        removeRun();
      },
    );
    return run;
  }

  Future<void> _downloadArchive(
    ArchiveDownloadedData archive, {
    required bool resume,
    required bool reParse,
  }) async {
    await _ensureDownloadDirExists();

    if (!resume) {
      if (archiveDownloadInfos.containsKey(archive.gid)) {
        return;
      }

      ArchiveDownloadedData? archiveWithSanitizedTitle = await _initArchiveInfo(
        archive,
      );
      if (archiveWithSanitizedTitle == null) {
        return;
      }
      archive = archiveWithSanitizedTitle;

      final comicInfo = _generateComicInfoInDisk(archive);
      _comicInfoRuns[archive.gid] = comicInfo;
      comicInfo.whenComplete(() {
        if (identical(_comicInfoRuns[archive.gid], comicInfo)) {
          _comicInfoRuns.remove(archive.gid);
        }
      });
    }

    // Own the directory before ZIP chunks or resume files are written so a
    // paused or failed task can retire every intermediate artifact together.
    await localContentService.ensureCopy(
      gid: archive.gid,
      representation: archive.isOriginal ? 'original' : 'resampled',
      rootPath: computeArchiveUnpackingPath(archive),
      makeCurrent: false,
    );

    log.info(
      'Begin to handle archive: ${archive.title}, original: ${archive.isOriginal}, parseSource: ${archive.parseSource}',
    );

    /// step 1: request to unlock archive: if we have unlocked before or unlock has completed,
    /// we can get [downloadPageUrl] immediately, otherwise we must wait for a second
    await _unlock(archive);

    /// step 2: circularly check if unlock has completed so that we can get [downloadPageUrl]
    await _getDownloadPageUrl(archive);

    /// step 3: parse download url
    await _getDownloadUrl(archive, reParse: reParse);

    /// step 4: do download
    await _doDownloadArchiveViaMultiIsolate(archive);

    /// step 5: unpacking files
    final unpacking = _unpackingArchive(archive);
    _unpackingRuns[archive.gid] = unpacking;
    try {
      await unpacking;
    } finally {
      if (identical(_unpackingRuns[archive.gid], unpacking)) {
        _unpackingRuns.remove(archive.gid);
      }
    }
  }

  Future<void> deleteArchive(int gid) async {
    ArchiveDownloadedData? archive = archives.firstWhereOrNull(
      (archive) => archive.gid == gid,
    );
    if (archive != null) {
      log.info(
        'Delete archive: ${archive.title}, original: ${archive.isOriginal}',
      );

      await pauseDownloadArchive(gid);
      await _deleteArchiveInfoInDatabase(gid);
      await _deleteArchiveInMemory(gid);
      try {
        await _comicInfoRuns[gid];
        await _unpackingRuns[gid];
      } catch (e, st) {
        log.error('Archive unpack ended before deletion: $gid', e, st);
      }

      final copyId = await localContentService.copyIdForRoot(
        computeArchiveUnpackingPath(archive),
      );
      if (copyId != null) await localContentService.retireCopy(copyId);

      update(['$archiveStatusId::${archive.gid}']);
    }
  }

  Future<void> pauseAllDownloadArchive() async {
    await Future.wait(
      archives.map((a) => a.gid).map(pauseDownloadArchive).toList(),
    );
  }

  Future<void> pauseDownloadArchive(
    int gid, {
    bool needReUnlock = false,
  }) async {
    ArchiveDownloadedData? archive = archives.firstWhereOrNull(
      (archive) => archive.gid == gid,
    );
    if (archive != null) {
      ArchiveDownloadInfo archiveDownloadInfo = archiveDownloadInfos[gid]!;
      if (archiveDownloadInfo.archiveStatus.code <= ArchiveStatus.paused.code ||
          archiveDownloadInfo.archiveStatus.code >=
              ArchiveStatus.downloaded.code) {
        return;
      }

      log.info(
        'Pause archive: ${archive.title}, original: ${archive.isOriginal}',
      );

      archiveDownloadInfo.cancelToken.cancel();
      archiveDownloadInfo.cancelToken = CancelToken();
      await archiveDownloadInfo.downloadTask?.pause();
      archiveDownloadInfo.downloadCompleter?.completeError(CancelException());
      archiveDownloadInfo.speedComputer.pause();

      await _updateArchiveStatus(
        gid,
        needReUnlock ? ArchiveStatus.needReUnlock : ArchiveStatus.paused,
      );

      _tryWakeWaitingTasks();
    }
  }

  Future<void> resumeAllDownloadArchive() async {
    await Future.wait(
      archives.map((a) => a.gid).map(resumeDownloadArchive).toList(),
    );
  }

  Future<void> resumeDownloadArchive(int gid) async {
    ArchiveDownloadedData? archive = archives.firstWhereOrNull(
      (archive) => archive.gid == gid,
    );
    if (archive != null) {
      ArchiveDownloadInfo archiveDownloadInfo =
          archiveDownloadInfos[archive.gid]!;
      if (archiveDownloadInfo.archiveStatus != ArchiveStatus.paused) {
        return;
      }
      if (archive.copyId case final id?) {
        if (localContentService.isRelocating(id)) {
          _resumeAfterRelocation.add(id);
          return;
        }
      }

      log.info(
        'Resume archive: ${archive.title}, original: ${archive.isOriginal}',
      );

      await _updateArchiveStatus(gid, ArchiveStatus.unlocking);

      downloadArchive(archive, resume: true);
    }
  }

  /// cancel archive to deal with 410
  Future<void> cancelArchive(int gid) async {
    ArchiveDownloadedData? archive = archives.firstWhereOrNull(
      (a) => a.gid == gid,
    );
    if (archive != null) {
      ArchiveDownloadInfo archiveDownloadInfo =
          archiveDownloadInfos[archive.gid]!;
      if (archiveDownloadInfo.archiveStatus.code >=
          ArchiveStatus.downloaded.code) {
        return;
      }

      log.download(
        'Cancel archive: ${archive.title}, original: ${archive.isOriginal}',
      );

      archiveDownloadInfo.archiveStatus = ArchiveStatus.unlocking;
      archiveDownloadInfo.downloadPageUrl = null;
      archiveDownloadInfo.downloadUrl = null;
      archiveDownloadInfo.downloadTask = null;
      archiveDownloadInfo.cancelToken.cancel();
      archiveDownloadInfo.cancelToken = CancelToken();
      await archiveDownloadInfo.downloadTask?.pause();
      archiveDownloadInfo.downloadCompleter?.completeError(CancelException());

      await _updateArchiveInDatabase(archive.gid);
      update(['$archiveStatusId::${archive.gid}']);

      /// skip when use bot
      if (archiveDownloadInfo.parseSource == ArchiveParseSource.official.code) {
        try {
          await retry(
            () => ehRequest.requestCancelArchive(
              url: archive.archivePageUrl.replaceFirst('--', '-'),
              cancelToken: archiveDownloadInfo.cancelToken,
            ),
            retryIf: (e) =>
                e is DioException && e.type != DioExceptionType.cancel,
            onRetry: (e) => log.download(
              'Cancel archive: ${archive.title} failed, retry. Reason: ${(e as DioException).message}',
            ),
            maxAttempts: _maxRetryTimes,
          );
        } on DioException catch (e) {
          if (e.type == DioExceptionType.cancel) {
            return;
          }

          log.download('Cancel archive error, reason: ${e.toString()}');
          return pauseDownloadArchive(archive.gid);
        }
      }
    }
  }

  Future<bool> updateArchiveGroup(int gid, String group) async {
    ArchiveDownloadInfo? archiveDownloadInfo = archiveDownloadInfos[gid];
    if (archiveDownloadInfo == null) {
      return false;
    }

    archiveDownloadInfo.group = group;

    if (!allGroups.contains(group)) {
      if (!await _addGroup(group)) {
        return false;
      }
    }

    _sortArchives();

    bool success = await _updateArchiveInDatabase(gid);
    if (!success) {
      return false;
    }

    _updateArchiveInfoInDisk(gid);
    await relayContentMetadata(gid);

    return true;
  }

  Future<void> relayContentMetadata(int gid) async {
    final archive = archives.firstWhereOrNull((item) => item.gid == gid);
    if (archive == null) return;
    final copyId =
        archive.copyId ??
        await localContentService.copyIdForRoot(
          computeArchiveUnpackingPath(archive),
        );
    if (copyId == null) return;
    await localContentService.updateMetadata(
      copyId,
      collections: [archiveDownloadInfos[gid]?.group ?? archive.groupName],
    );
  }

  Future<void> renameGroup(String oldGroup, String newGroup) async {
    List<ArchiveDownloadedData> archiveDownloadedDatas = archives
        .where((a) => archiveDownloadInfos[a.gid]!.group == oldGroup)
        .toList();

    await appDb.transaction(() async {
      if (!allGroups.contains(newGroup)) {
        int index = allGroups.indexOf(oldGroup);
        allGroups[index] = newGroup;
        await ArchiveGroupDao.insertArchiveGroup(
          ArchiveGroupData(groupName: newGroup, sortOrder: index),
        );
      }

      for (ArchiveDownloadedData a in archiveDownloadedDatas) {
        archiveDownloadInfos[a.gid]!.group = newGroup;
        await _updateArchiveInDatabase(a.gid);
      }

      await deleteGroup(oldGroup);
    });

    for (ArchiveDownloadedData a in archiveDownloadedDatas) {
      await _updateArchiveInfoInDisk(a.gid);
      await relayContentMetadata(a.gid);
    }

    _sortArchives();
  }

  Future<bool> deleteGroup(String group) async {
    allGroups.remove(group);

    try {
      return (await ArchiveGroupDao.deleteArchiveGroup(group) > 0);
    } on SqliteException catch (e) {
      log.info(e);
      return false;
    }
  }

  Future<void> updateGroupOrder(int beforeIndex, int afterIndex) async {
    if (afterIndex == allGroups.length - 1) {
      allGroups.add(allGroups.removeAt(beforeIndex));
    } else {
      allGroups.insert(afterIndex, allGroups.removeAt(beforeIndex));
    }

    log.info('Update group order: $allGroups');

    await appDb.transaction(() async {
      for (int i = 0; i < allGroups.length; i++) {
        await ArchiveGroupDao.updateArchiveGroupOrder(allGroups[i], i);
      }
    });
  }

  Future<void> changeParseSource(
    int gid,
    ArchiveParseSource parseSource,
  ) async {
    log.info('Update parse source: $gid $parseSource');

    ArchiveDownloadInfo? archiveDownloadInfo = archiveDownloadInfos[gid];
    if (archiveDownloadInfo == null) {
      return;
    }

    if (archiveDownloadInfo.archiveStatus.code >=
        ArchiveStatus.downloaded.code) {
      return;
    }

    archiveDownloadInfo.downloadUrl = null;
    archiveDownloadInfo.parseSource = parseSource.code;

    await _updateArchiveInDatabase(gid);

    update(['$archiveStatusId::$gid']);
  }

  Future<void> batchUpdateArchiveInDatabase(
    List<ArchiveDownloadedData> archives,
  ) async {
    await appDb.transaction(() async {
      for (ArchiveDownloadedData archive in archives) {
        await _updateArchiveInDatabase(archive.gid);
      }
    });

    _sortArchives();

    for (ArchiveDownloadedData archive in archives) {
      await _updateArchiveInfoInDisk(archive.gid);
    }
  }

  /// Use meta in each archive folder to restore download tasks, then sync to database.
  /// this is used after re-install app, or share download folder to another user.
  Future<int> restoreTasks() async {
    await completed;

    Directory downloadDir = Directory(downloadSetting.downloadPath.value);
    if (!await downloadDir.exists()) {
      return 0;
    }

    int restoredCount = 0;
    await for (FileSystemEntity galleryDir in downloadDir.list()) {
      if (galleryDir is! Directory) continue;
      final metadataFile = File(join(galleryDir.path, '.content.sqlite'));
      if (!await metadataFile.exists()) {
        continue;
      }
      if (!await localContentService.shouldRestoreTask(
        galleryDir.path,
        'archive',
      )) {
        continue;
      }
      final projection = DirectoryRecoveryCodec.read(metadataFile);
      if (projection.taskState != 'completed' ||
          projection.completeManifest == null)
        continue;
      final snapshot = jsonDecode(projection.taskJson) as Map<String, dynamic>;
      if (snapshot['archive'] is! Map) continue;
      ArchiveDownloadedData archive = ArchiveDownloadedData.fromJson(
        (snapshot['archive'] as Map).cast<String, dynamic>(),
      );
      final restoredCopyId = await localContentService
          .restoreDirectoryProjection(
            galleryDir.path,
            projection,
            gid: archive.gid,
            representation: archive.isOriginal ? 'original' : 'resampled',
          );

      archive = archive.copyWith(
        copyId: Value(restoredCopyId),
        archiveStatusCode: ArchiveStatus.completed.code,
      );

      /// The scanned unpacking directory is where the unpacked image bytes
      /// actually live. Metadata written before sanitizedTitle has no such field,
      /// and restoring one of those files with the newer byte-based rule (issue
      /// #823) can store a title that points at a directory which never existed.
      /// Reconcile the title to the real on-disk directory in both cases.
      final String restoredSanitizedTitle =
          DownloadPathResolver.resolveArchiveSanitizedTitleForRestore(
            gid: archive.gid,
            rawTitle: archive.title,
            persistedSanitizedTitle: archive.sanitizedTitle,
            archiveDirectoryPath: galleryDir.path,
          );

      final ArchiveDownloadInfo? existingInfo =
          archiveDownloadInfos[archive.gid];
      if (existingInfo != null) {
        /// A stale record restored once under the bug keeps a sanitizedTitle that
        /// points at a missing directory. If the scanned metadata now resolves to
        /// a real unpacking directory, patch that record in place instead of
        /// skipping it. Archive images are never persisted — readers list the
        /// unpacking directory live — so only the stored title must change and no
        /// disk data is ever touched.
        if (!_shouldRepairRestoredArchivePath(
          existingInfo,
          archive,
          restoredSanitizedTitle,
        )) {
          continue;
        }

        log.info('Repair stale restored archive path, gid: ${archive.gid}');

        await _repairRestoredArchiveInfo(archive.gid, restoredSanitizedTitle);
        restoredCount++;
        continue;
      }

      archive = archive.copyWith(sanitizedTitle: Value(restoredSanitizedTitle));

      if (!await _saveArchiveAndGroupInDatabase(archive)) {
        log.error('Restore archive failed: $archive');
        await deleteArchive(archive.gid);
        continue;
      }

      _initArchiveInMemory(archive, sort: false);

      /// Persist the corrected snapshot back to the real unpacking directory's
      /// metadata file so future installs / transfers no longer need to re-apply
      /// the legacy naming compatibility. A metadata write failure is logged and
      /// does not roll back the successful restore.
      try {
        await _saveArchiveInfoInDisk(archive);
      } catch (e, st) {
        log.error(
          'Save restored archive metadata failed, gid: ${archive.gid}',
          e,
          st,
        );
      }

      restoredCount++;
    }

    if (restoredCount > 0) {
      _sortArchives();
    }

    return restoredCount;
  }

  /// Return true only for the stale-path shape created by the old restore bug:
  /// an already-completed record points at an unpacking directory that holds no
  /// image bytes, while the metadata being scanned resolves to an existing
  /// directory that does contain at least one image file.
  bool _shouldRepairRestoredArchivePath(
    ArchiveDownloadInfo existingInfo,
    ArchiveDownloadedData restoredArchive,
    String restoredSanitizedTitle,
  ) {
    if (existingInfo.archiveStatus != ArchiveStatus.completed) {
      return false;
    }

    final ArchiveDownloadedData? existingData = archives.firstWhereOrNull(
      (a) => a.gid == restoredArchive.gid,
    );
    if (existingData == null) {
      return false;
    }

    final String existingPath = normalize(
      computeArchiveUnpackingPath(existingData),
    );
    final String restoredPath = normalize(
      computeArchiveUnpackingPath(
        restoredArchive.copyWith(sanitizedTitle: Value(restoredSanitizedTitle)),
      ),
    );

    if (existingPath == restoredPath ||
        !_unpackingDirectoryHasImage(restoredPath)) {
      return false;
    }

    /// A previous bad restore can later materialize the wrong directory just by
    /// writing metadata. Existing image bytes therefore take precedence when
    /// they are actually readable; only an existing directory without any image
    /// inside is treated as stale.
    return !_unpackingDirectoryHasImage(existingPath);
  }

  bool _unpackingDirectoryHasImage(String directoryPath) {
    final Directory directory = Directory(directoryPath);
    if (!directory.existsSync()) {
      return false;
    }
    return directory.listSync().whereType<File>().any(
      (file) => FileUtil.isImageExtension(file.path),
    );
  }

  /// Patch a stale archive's stored title in database, memory and its metadata
  /// file, keeping the existing record's own data intact (group, sort order,
  /// tags, ...). Only the title changes and no unpacked image bytes on disk are
  /// ever deleted.
  Future<void> _repairRestoredArchiveInfo(
    int gid,
    String restoredSanitizedTitle,
  ) async {
    final ArchiveDownloadedData? existingData = archives.firstWhereOrNull(
      (a) => a.gid == gid,
    );
    if (existingData == null) {
      return;
    }

    final ArchiveDownloadedData repaired = existingData.copyWith(
      sanitizedTitle: Value(restoredSanitizedTitle),
    );
    final int index = archives.indexWhere((a) => a.gid == gid);
    if (index >= 0) {
      archives[index] = repaired;
    }

    await ArchiveDao.updateArchive(
      ArchiveDownloadedCompanion(
        gid: Value(gid),
        sanitizedTitle: Value(restoredSanitizedTitle),
      ),
    );

    try {
      await _saveArchiveInfoInDisk(repaired);
    } catch (e, st) {
      log.error('Save repaired archive metadata failed, gid: $gid', e, st);
    }
  }

  Future<List<GalleryImage>> getUnpackedImages(
    int gid, {
    bool computeHash = false,
  }) async {
    final archive = archives.firstWhere((item) => item.gid == gid);
    if (archive.copyId != null &&
        archive.archiveStatusCode == ArchiveStatus.completed.code) {
      final copy = await appDb
          .customSelect(
            'SELECT metadata_json FROM content_copy WHERE copy_id = ?',
            variables: [Variable.withString(archive.copyId!)],
          )
          .getSingle();
      if (copy.readNullable<String>('metadata_json') == null) {
        await ensureContentCopy(gid);
      }
    }
    return _listUnpackedImages(gid, computeHash: computeHash);
  }

  Future<List<GalleryImage>> _listUnpackedImages(
    int gid, {
    bool computeHash = false,
  }) async {
    ArchiveDownloadedData archive = archives.firstWhere((a) => a.gid == gid);
    Directory directory = Directory(computeArchiveUnpackingPath(archive));

    return directory
        .list()
        .toList()
        .then((files) {
          List<File> imageFiles = files
              .whereType<File>()
              .where((file) => FileUtil.isImageExtension(file.path))
              .toList();
          imageFiles.sort(FileUtil.naturalCompareFile);
          return imageFiles;
        })
        .then((imageFiles) {
          return imageFiles
              .asMap()
              .entries
              .map(
                (entry) => GalleryImage(
                  url: '',
                  managedPage: archive.copyId == null
                      ? null
                      : localContentService.managedPageForIdentitySync(
                          archive.copyId!,
                          entry.key,
                        ),
                  path: relative(
                    entry.value.path,
                    from: pathService.getVisibleDir().path,
                  ),
                  downloadStatus: DownloadStatus.downloaded,
                ),
              )
              .toList();
        })
        .then((images) {
          if (!computeHash) {
            return images;
          }

          List<Future> futures = [];
          for (GalleryImage image in images) {
            futures.add(
              FileUtil.computeSha1Hash(
                File(join(pathService.getVisibleDir().path, image.path)),
              ).then((value) => image.imageHash = value),
            );
          }
          return Future.wait(futures).then((_) => images);
        });
  }

  /// Adopt an already unpacked legacy archive the first time it is uploaded.
  /// Only missing page facts need a one-time read of the surviving files.
  Future<String?> ensureContentCopy(int gid) async {
    final archive = archives.firstWhereOrNull((item) => item.gid == gid);
    if (archive == null ||
        archive.archiveStatusCode != ArchiveStatus.completed.code) {
      return null;
    }
    final root = computeArchiveUnpackingPath(archive);
    final existing = await localContentService.copyIdForRoot(root);
    if (existing != null &&
        await localContentService.completedInput(existing) != null) {
      return existing;
    }
    final copyId =
        existing ??
        await localContentService.ensureCopy(
          gid: gid,
          representation: archive.isOriginal ? 'original' : 'resampled',
          rootPath: root,
          makeCurrent: false,
        );
    final known = {
      for (final page in await localContentService.repository.listPages(copyId))
        page.ordinal: page,
    };
    final images = await _listUnpackedImages(gid);
    for (var i = 0; i < images.length; i++) {
      final absolute = join(pathService.getVisibleDir().path, images[i].path!);
      final relativePath = relative(absolute, from: root);
      if (known[i]?.rawHash != null && known[i]?.relativePath == relativePath)
        continue;
      final file = File(absolute);
      await localContentService.recordPage(
        copyId: copyId,
        ordinal: i,
        relativePath: relativePath,
        rawHash: (await sha256.bind(file.openRead()).first).toString(),
        rawLength: await file.length(),
      );
    }
    final tags = tagDataString2TagDataList(archive.tags)
        .map((tag) => PortableTag(tag.namespace, tag.key))
        .toList();
    await localContentService.completeCopy(
      copyId,
      galleryUrl: archive.galleryUrl,
      title: archive.title,
      tags: tags,
      providerMetadata: {
        'category': archive.category,
        'uploader': archive.uploader,
        'publishTime': archive.publishTime,
      },
      collections: [
        archiveDownloadInfos[archive.gid]?.group ?? archive.groupName,
      ],
      expectedPages: images.length,
    );
    return copyId;
  }

  Future<void> _generateComicInfoInDisk(ArchiveDownloadedData archive) async {
    GalleryDetail galleryDetail;
    try {
      ({GalleryDetail galleryDetails, String apikey}) detailPageInfo =
          await retry(
            () => ehRequest.requestDetailPage(
              galleryUrl: archive.galleryUrl,
              parser: EHSpiderParser.detailPage2GalleryAndDetailAndApikey,
            ),
            retryIf: (e) => e is DioException,
            maxAttempts: _maxRetryTimes,
          );
      galleryDetail = detailPageInfo.galleryDetails;
    } catch (e) {
      log.error('Get gallery detail failed, gallery: ${archive.gid}', e);
      return;
    }

    if (!archiveDownloadInfos.containsKey(archive.gid)) {
      return;
    }

    final copyId =
        archive.copyId ??
        await localContentService.copyIdForRoot(
          computeArchiveUnpackingPath(archive),
        );
    if (copyId != null) {
      await localContentService.updateMetadata(
        copyId,
        providerMetadata: {
          'rawTitle': galleryDetail.rawTitle,
          'japaneseTitle': galleryDetail.japaneseTitle,
          'category': galleryDetail.category,
          'uploader': galleryDetail.uploader,
          'publishTime': galleryDetail.publishTime,
          'language': galleryDetail.language,
          'rating': galleryDetail.realRating,
          'coverUrl': galleryDetail.cover.url,
        },
      );
    }

    EHGalleryComicInfo galleryComicInfo = EHGalleryComicInfo(
      rawTitle: galleryDetail.rawTitle,
      japaneseTitle: galleryDetail.japaneseTitle,
      category: galleryDetail.category,
      pageCount: galleryDetail.pageCount,
      galleryUrl: galleryDetail.galleryUrl.url,
      uploader: galleryDetail.uploader,
      publishTime: galleryDetail.publishTime,
      languageAbbreviation: LocaleConsts
          .language2Abbreviation[galleryDetail.language]
          ?.toLowerCase(),
      tagDatas: galleryDetail.tags.values.flattened
          .map((galleryTag) => galleryTag.tagData)
          .toList(),
      rating: galleryDetail.realRating,
    );

    try {
      File file = File(
        join(computeArchiveUnpackingPath(archive), 'ComicInfo.xml'),
      );
      if (!await file.exists()) {
        await file.create(recursive: true);
      }
      await file.writeAsString(
        galleryComicInfo.toXmlDocument().toXmlString(pretty: true),
      );
    } catch (e) {
      log.error('Write comic info failed, gallery: ${archive.gid}', e);
    }
  }

  static const int _maxFileNameBytes = 200;

  /// Compute the sanitized title for the first time. Strips illegal file-name
  /// characters then truncates to fit within [_maxFileNameBytes] bytes minus
  /// [reservedBytes] (the byte length of the surrounding prefix / suffix).
  String _computeSanitizedArchiveTitle(String rawTitle, int reservedBytes) {
    String title = rawTitle.replaceAll(RegExp(r'[/|?,:*"<>\\.]'), ' ').trim();
    return FileUtil.truncateTitleToBytes(
      title,
      _maxFileNameBytes - reservedBytes,
    );
  }

  String computePackingFileDownloadPath(ArchiveDownloadedData archive) {
    return join(
      computeArchiveUnpackingPath(archive),
      '.content-work',
      'archive.zip',
    );
  }

  String computeArchiveUnpackingPath(ArchiveDownloadedData archive) {
    if (archive.copyId case final id?) {
      final root = localContentService.registeredRoot(id);
      if (root == null) throw StateError('Content copy is unavailable: $id');
      return root;
    }

    /// Directory name format: 'Archive - {gid} - {title}'
    return join(
      downloadSetting.downloadPath.value,
      'Archive - ${archive.gid} - ${archive.sanitizedTitle ?? DownloadPathResolver.computeLegacyArchiveTitle(archive.title)}',
    );
  }

  void _sortArchives() {
    archives.sort((a, b) {
      ArchiveDownloadInfo aInfo = archiveDownloadInfos[a.gid]!;
      ArchiveDownloadInfo bInfo = archiveDownloadInfos[b.gid]!;

      if (!(aInfo.group == 'default'.tr && bInfo.group == 'default'.tr)) {
        if (aInfo.group == 'default'.tr) {
          return 1;
        }
        if (bInfo.group == 'default'.tr) {
          return -1;
        }
      }

      int gResult = aInfo.group.compareTo(bInfo.group);
      if (gResult != 0) {
        return gResult;
      }

      int aOrder = aInfo.sortOrder;
      int bOrder = bInfo.sortOrder;
      if (aOrder - bOrder != 0) {
        return aOrder - bOrder;
      }

      DateTime aTime = DateFormat('yyyy-MM-dd HH:mm:ss').parse(a.insertTime);
      DateTime bTime = DateFormat('yyyy-MM-dd HH:mm:ss').parse(b.insertTime);

      return bTime.difference(aTime).inMilliseconds;
    });
  }

  JDownloadTask _generateDownloadTask(
    String url,
    ArchiveDownloadedData archive,
  ) {
    return JDownloadTask.newTask(
      url: url,
      savePath: computePackingFileDownloadPath(archive),
      isolateCount: downloadSetting.archiveDownloadIsolateCount.value,
      deleteWhenUrlMismatch: false,
      proxyConfig: ehRequest.currentProxyConfig(),
      headConnectionTimeout: Duration(
        milliseconds: networkSetting.connectTimeout.value,
      ),
      headReceiveTimeout: Duration(
        milliseconds: networkSetting.receiveTimeout.value,
      ),
      onLog: (OutputEvent event) {},
      onReceiveBytes: (bytes) =>
          archiveDownloadInfos[archive.gid]?.speedComputer.downloadedBytes +=
              bytes,
      onProgress: (current, total) {
        ArchiveDownloadInfo archiveDownloadInfo =
            archiveDownloadInfos[archive.gid]!;
        if (total != archiveDownloadInfo.size) {
          archiveDownloadInfo.size = total;
          _updateArchiveInDatabase(archive.gid);
        }
      },
      onDone: () async {
        final completer = archiveDownloadInfos[archive.gid]?.downloadCompleter;
        if (completer != null && !completer.isCompleted) completer.complete();
      },
      onError: (JDownloadException e) async {
        final completer = archiveDownloadInfos[archive.gid]?.downloadCompleter;
        if (completer != null && !completer.isCompleted)
          completer.completeError(e);
      },
    );
  }

  Future<void> _check410Or404Reason(
    String url,
    ArchiveDownloadedData archive,
  ) async {
    try {
      await ehRequest.get(
        url: url,
        cancelToken: archiveDownloadInfos[archive.gid]?.cancelToken,
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        return;
      }

      if (e.response?.statusCode != 410 && e.response?.statusCode != 404) {
        log.download(
          'Check archive  ${archive.title} 410 reason failed, pause task.',
        );
        return pauseDownloadArchive(archive.gid);
      }

      if (e.response!.data is String &&
          e.response!.data.contains(
            'You have clocked too many downloaded bytes on this gallery',
          )) {
        log.download('${'410Hints'.tr} Archive: ${archive.title}');
        snack(
          'archiveError'.tr,
          '${'410Hints'.tr} : ${archive.title}',
          isShort: true,
        );
        return pauseDownloadArchive(archive.gid, needReUnlock: true);
      } else if (e.response!.data is String &&
          e.response!.data.contains(
            'This archive session has been used from too many different locations',
          )) {
        log.download(
          'Archive session has been used from too many different locations! Archive: ${archive.title}',
        );
        snack(
          'archiveError'.tr,
          'This archive session has been used from too many different locations.',
          isShort: true,
        );
        return pauseDownloadArchive(archive.gid, needReUnlock: true);
      } else if (e.response!.data is String &&
          e.response!.data.contains('IP quota exhausted')) {
        log.download('IP quota exhausted! Archive: ${archive.title}');
        snack('archiveError'.tr, 'IP quota exhausted!', isShort: true);
        return pauseDownloadArchive(archive.gid, needReUnlock: true);
      } else if (e.response!.data is String &&
          e.response!.data.contains('Expired or invalid session')) {
        log.download('Expired or invalid session! Archive: ${archive.title}');
        snack('archiveError'.tr, 'Expired or invalid session!', isShort: true);
        return pauseDownloadArchive(archive.gid);
      } else {
        log.download(
          'Download archive 410, try re-parse. Archive: ${archive.title} Response: ${e.response!.data}',
        );

        archiveDownloadInfos[archive.gid]!.downloadUrl = null;

        await _getDownloadUrl(archive, reParse: true);
        return _doDownloadArchiveViaMultiIsolate(archive);
      }
    }

    return _doDownloadArchiveViaMultiIsolate(archive);
  }

  Future<void> _tryWakeWaitingTasks() async {
    int currentActiveIsolateCount = archiveDownloadInfos.values
        .where((a) => a.archiveStatus == ArchiveStatus.downloading)
        .fold(
          0,
          (previousValue, a) =>
              previousValue + a.downloadTask!.activeIsolateCount,
        );
    if (currentActiveIsolateCount >= _maxIsolateCountsTotal) {
      return;
    }

    List<int> gids = archiveDownloadInfos.entries
        .where((e) => e.value.archiveStatus == ArchiveStatus.waitingIsolate)
        .map((e) => e.key)
        .toList();
    List<ArchiveDownloadedData> waitingArchives = archives
        .where((a) => gids.contains(a.gid))
        .toList();
    waitingArchives.sort((a, b) => a.insertTime.compareTo(b.insertTime));

    for (ArchiveDownloadedData a in waitingArchives) {
      if (a.copyId case final id?) {
        if (localContentService.isRelocating(id)) continue;
      }
      ArchiveDownloadInfo archiveDownloadInfo = archiveDownloadInfos[a.gid]!;
      if (currentActiveIsolateCount +
              archiveDownloadInfo.downloadTask!.isolateCount <=
          _maxIsolateCountsTotal) {
        log.download('Archive ${a.title} gain isolates.');
        await _updateArchiveStatus(a.gid, ArchiveStatus.downloading);
        downloadArchive(a, resume: true);
        return;
      }
    }
  }

  void _onIsolateCountChange() {
    for (ArchiveDownloadInfo archiveDownloadInfo
        in archiveDownloadInfos.values) {
      if (archiveDownloadInfo.archiveStatus.code <=
              ArchiveStatus.unpacking.code &&
          archiveDownloadInfo.downloadTask != null) {
        archiveDownloadInfo.downloadTask!.changeIsolateCount(
          downloadSetting.archiveDownloadIsolateCount.value,
        );
      }
    }
  }

  void _onProxyConfigChange() {
    for (ArchiveDownloadInfo archiveDownloadInfo
        in archiveDownloadInfos.values) {
      if (archiveDownloadInfo.archiveStatus.code <=
              ArchiveStatus.downloading.code &&
          archiveDownloadInfo.downloadTask != null) {
        archiveDownloadInfo.downloadTask!.setProxy(
          ehRequest.currentProxyConfig(),
        );
      }
    }
  }

  void _onTimeoutChange() {
    for (ArchiveDownloadInfo archiveDownloadInfo
        in archiveDownloadInfos.values) {
      if (archiveDownloadInfo.archiveStatus.code <=
              ArchiveStatus.unpacking.code &&
          archiveDownloadInfo.downloadTask != null) {
        archiveDownloadInfo.downloadTask!.changeConnectionTimeout(
          Duration(milliseconds: networkSetting.connectTimeout.value),
        );
        archiveDownloadInfo.downloadTask!.changeReceiveTimeout(
          Duration(milliseconds: networkSetting.receiveTimeout.value),
        );
      }
    }
  }

  bool _isTaskInStatus(int gid, List<ArchiveStatus> statuses) {
    if (!transferActivityService.canAdmit || _systemSuspended.contains(gid))
      return false;
    return archiveDownloadInfos.containsKey(gid) &&
        statuses.contains(archiveDownloadInfos[gid]!.archiveStatus);
  }

  Future<void> _updateArchiveStatus(
    int gid,
    ArchiveStatus archiveStatus,
  ) async {
    ArchiveDownloadInfo archiveDownloadInfo = archiveDownloadInfos[gid]!;

    if (archiveDownloadInfo.archiveStatus != archiveStatus) {
      archiveDownloadInfo.archiveStatus = archiveStatus;
      await _updateArchiveInDatabase(gid);
      update(['$archiveStatusId::$gid']);
    }
  }

  // TASKS

  Future<void> _unlock(ArchiveDownloadedData archive) async {
    ArchiveDownloadInfo archiveDownloadInfo =
        archiveDownloadInfos[archive.gid]!;

    if (!_isTaskInStatus(archive.gid, [ArchiveStatus.unlocking])) {
      return;
    }
    if (archiveDownloadInfo.downloadPageUrl != null) {
      archiveDownloadInfo.archiveStatus = ArchiveStatus.unlocked;
      return;
    }
    if (archiveDownloadInfo.parseSource == ArchiveParseSource.bot.code) {
      archiveDownloadInfo.archiveStatus = ArchiveStatus.unlocked;
      return;
    }

    log.download(
      'Begin to unlock archive: ${archive.title}, original: ${archive.isOriginal}',
    );

    await _updateArchiveStatus(archive.gid, ArchiveStatus.unlocking);

    ArchiveUnlockResult result;
    try {
      result = await retry(
        () => ehRequest.requestUnlockArchive(
          url: archive.archivePageUrl.replaceFirst('--', '-'),
          isOriginal: archive.isOriginal,
          cancelToken: archiveDownloadInfo.cancelToken,
          parser: EHSpiderParser.unlockArchivePage2DownloadArchivePageUrl,
        ),
        retryIf: (e) => e is DioException && e.type != DioExceptionType.cancel,
        onRetry: (e) => log.download(
          'Request unlock archive: ${archive.title} failed, retry. Reason: ${(e as DioException).message}',
        ),
        maxAttempts: _maxRetryTimes,
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        return;
      }
      return await _unlock(archive);
    } on EHSiteException catch (e) {
      log.download('Unlock archive error, reason: ${e.message}');
      snack('archiveError'.tr, e.message, isShort: true);

      if (e.shouldPauseAllDownloadTasks) {
        return await pauseAllDownloadArchive();
      } else {
        return await pauseDownloadArchive(archive.gid);
      }
    }

    if (result.success) {
      log.download('Get archive download page url success: ${archive.title}');
      archiveDownloadInfo.downloadPageUrl = result.url;
      await _updateArchiveStatus(archive.gid, ArchiveStatus.unlocked);
    } else {
      log.download(
        'Unlock archive failed. Archive: ${archive.title}, reason: ${result.msg}',
      );
      snack('archiveError'.tr, result.msg, isShort: true);
      await pauseDownloadArchive(archive.gid);
    }
  }

  Future<void> _getDownloadPageUrl(ArchiveDownloadedData archive) async {
    ArchiveDownloadInfo archiveDownloadInfo =
        archiveDownloadInfos[archive.gid]!;
    if (!_isTaskInStatus(archive.gid, [
      ArchiveStatus.unlocked,
      ArchiveStatus.parsingDownloadPageUrl,
    ])) {
      return;
    }
    if (archiveDownloadInfo.downloadPageUrl != null) {
      archiveDownloadInfo.archiveStatus = ArchiveStatus.parsedDownloadPageUrl;
      return;
    }
    if (archiveDownloadInfo.parseSource == ArchiveParseSource.bot.code) {
      archiveDownloadInfo.archiveStatus = ArchiveStatus.parsedDownloadPageUrl;
      return;
    }

    log.download(
      'Begin to circularly fetch archive download page url: ${archive.title}, original: ${archive.isOriginal}',
    );

    await _updateArchiveStatus(
      archive.gid,
      ArchiveStatus.parsingDownloadPageUrl,
    );

    ArchiveUnlockResult result;
    try {
      result = await retry(
        () => ehRequest.requestUnlockArchive(
          url: archive.archivePageUrl.replaceFirst('--', '-'),
          isOriginal: archive.isOriginal,
          cancelToken: archiveDownloadInfo.cancelToken,
          parser: EHSpiderParser.unlockArchivePage2DownloadArchivePageUrl,
        ),
        retryIf: (e) => e is DioException && e.type != DioExceptionType.cancel,
        onRetry: (e) => log.download(
          'Request unlock archive: ${archive.title} failed, retry. Reason: ${(e as DioException).message}',
        ),
        maxAttempts: _maxRetryTimes,
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        return;
      }
      return await _unlock(archive);
    } on EHSiteException catch (e) {
      log.download(
        'Parsing archive download page url failed, reason: ${e.message}',
      );
      snack('archiveError'.tr, e.message, isShort: true);

      if (e.shouldPauseAllDownloadTasks) {
        return pauseAllDownloadArchive();
      } else {
        return pauseDownloadArchive(archive.gid);
      }
    }

    if (result.success && result.url != null) {
      log.download('Get archive download page url success: ${archive.title}');
      archiveDownloadInfo.downloadPageUrl = result.url;
      await _updateArchiveStatus(
        archive.gid,
        ArchiveStatus.parsedDownloadPageUrl,
      );
    } else if (result.success && result.url == null) {
      /// wait for server operation
      await Future.delayed(const Duration(milliseconds: 1000));
      return _getDownloadPageUrl(archive);
    } else {
      log.download(
        'Get archive download page url failed. Archive: ${archive.title}, reason: ${result.msg}',
      );
      snack('archiveError'.tr, result.msg, isShort: true);
      await pauseDownloadArchive(archive.gid);
      return;
    }
  }

  Future<void> _getDownloadUrl(
    ArchiveDownloadedData archive, {
    bool reParse = false,
  }) async {
    ArchiveDownloadInfo archiveDownloadInfo =
        archiveDownloadInfos[archive.gid]!;
    if (!_isTaskInStatus(archive.gid, [
      ArchiveStatus.parsedDownloadPageUrl,
      ArchiveStatus.parsingDownloadUrl,
    ])) {
      return;
    }
    if (archiveDownloadInfo.downloadUrl != null) {
      archiveDownloadInfo.archiveStatus = ArchiveStatus.parsedDownloadUrl;
      return;
    }

    /// changed parse source from bot to official
    if (archiveDownloadInfo.parseSource == ArchiveParseSource.official.code &&
        archiveDownloadInfo.downloadPageUrl == null) {
      archiveDownloadInfo.archiveStatus = ArchiveStatus.unlocked;
      return downloadArchive(archive);
    }

    log.download(
      'Begin to parse fetch archive download url: ${archive.title}, original: ${archive.isOriginal}, parseSource: ${archive.parseSource}',
    );

    await _updateArchiveStatus(archive.gid, ArchiveStatus.parsingDownloadUrl);

    String downloadPath;

    if (archiveDownloadInfo.parseSource == ArchiveParseSource.official.code) {
      try {
        downloadPath = await retry(
          () => ehRequest.get(
            url: archiveDownloadInfo.downloadPageUrl!,
            cancelToken: archiveDownloadInfo.cancelToken,
            parser: EHSpiderParser.downloadArchivePage2DownloadUrl,
          ),
          retryIf: (e) =>
              e is DioException && e.type != DioExceptionType.cancel,
          onRetry: (e) => log.download(
            'Parse archive download url: ${archive.title} failed, retry. Reason: ${(e as DioException).errorMsg}',
          ),
          maxAttempts: _maxRetryTimes,
        );
      } on DioException catch (e) {
        if (e.type == DioExceptionType.cancel) {
          return;
        }

        return await _getDownloadUrl(archive);
      } on EHSiteException catch (e) {
        log.download('Download error, reason: ${e.message}');
        snack('archiveError'.tr, e.message, isShort: true);

        if (e.shouldPauseAllDownloadTasks) {
          return pauseAllDownloadArchive();
        } else {
          return pauseDownloadArchive(archive.gid);
        }
      } catch (e) {
        log.download('Parse archive download url error, reason: $e');
        snack('archiveError'.tr, e.toString(), isShort: true);
        return pauseDownloadArchive(archive.gid);
      }
    } else {
      if (!archiveBotSetting.isReady) {
        snack('archiveError'.tr, 'pauseDownloadByInvalidArchiveBotKey'.tr);
        return pauseDownloadArchive(archive.gid);
      }

      try {
        ArchiveBotResponse response = await retry(
          () => archiveBotRequest.requestResolve(
            botType: archiveBotSetting.botType.value,
            apiAddress: archiveBotSetting.apiAddress.value!,
            apiKey: archiveBotSetting.apiKey.value!,
            gid: archive.gid,
            token: archive.token,
            reParse: reParse,
            cancelToken: archiveDownloadInfo.cancelToken,
          ),
          retryIf: (e) =>
              e is DioException && e.type != DioExceptionType.cancel,
          onRetry: (e) => log.download(
            'Parse archive download url: ${archive.title} failed, retry. Reason: ${(e as DioException).message}',
          ),
          maxAttempts: _maxRetryTimes,
        );
        log.download('Parse archive download url via bot, response: $response');

        if (response.isSuccess) {
          ArchiveResolveVO archiveResolveVO = archiveBotSetting.botType.value
              .parseResolve(response.data);
          downloadPath = archiveResolveVO.url;
        } else {
          snack('archiveError'.tr, response.errorMessage);
          return pauseDownloadArchive(archive.gid);
        }
      } on DioException catch (e) {
        if (e.type == DioExceptionType.cancel) {
          return;
        }

        return await _getDownloadUrl(archive);
      } catch (e) {
        log.download('Parse archive download url error, reason: $e');
        snack('archiveError'.tr, e.toString(), isShort: true);
        return pauseDownloadArchive(archive.gid);
      }
    }

    /// add start=1
    Uri uri = Uri.parse(downloadPath);
    Map<String, String> queryParameters = Map.from(uri.queryParameters);
    queryParameters.remove('autostart');
    queryParameters.putIfAbsent('start', () => '1');
    Uri replacedUri = uri.replace(queryParameters: queryParameters);
    downloadPath = replacedUri.toString();

    /// the bot protocol only returns the original archive url; the resample variant lives at the same path with trailing '/2' replaced by '/3'
    if (archiveDownloadInfo.parseSource != ArchiveParseSource.official.code &&
        !archive.isOriginal) {
      List<String> segments = List.of(replacedUri.pathSegments);
      if (segments.isNotEmpty && segments.last == '2') {
        segments[segments.length - 1] = '3';
        downloadPath = replacedUri.replace(pathSegments: segments).toString();
      } else {
        log.warning(
          'Bot returned archive url without trailing /2 segment, fallback to original: $downloadPath',
        );
      }
    }

    if (archiveDownloadInfo.parseSource == ArchiveParseSource.official.code) {
      archiveDownloadInfo.downloadUrl =
          'https://' +
          Uri.parse(archiveDownloadInfo.downloadPageUrl!).host +
          downloadPath;
    } else {
      archiveDownloadInfo.downloadUrl = downloadPath;
    }

    log.trace(
      'Parse archive download url success: ${archive.title}, original: ${archive.isOriginal}, url: ${archiveDownloadInfo.downloadUrl}',
    );
    return _updateArchiveStatus(archive.gid, ArchiveStatus.parsedDownloadUrl);
  }

  Future<void> _doDownloadArchiveViaMultiIsolate(
    ArchiveDownloadedData archive,
  ) async {
    ArchiveDownloadInfo archiveDownloadInfo =
        archiveDownloadInfos[archive.gid]!;
    if (!_isTaskInStatus(archive.gid, [
      ArchiveStatus.parsedDownloadUrl,
      ArchiveStatus.downloading,
    ])) {
      return;
    }

    log.download(
      'Begin to download archive: ${archive.title}, original: ${archive.isOriginal}',
    );

    await _updateArchiveStatus(archive.gid, ArchiveStatus.downloading);

    JDownloadTask task = archiveDownloadInfo.downloadTask ??=
        _generateDownloadTask(archiveDownloadInfo.downloadUrl!, archive);
    archiveDownloadInfo.speedComputer
      ..resetDownloadedBytes(task.currentBytes)
      ..start();
    log.download('${archive.title} downloaded bytes: ${task.currentBytes}');

    if (task.status != TaskStatus.completed) {
      if (downloadSetting.manageArchiveDownloadConcurrency.isTrue) {
        int currentActiveIsolateCount = archiveDownloadInfos.entries
            .where((e) => e.value.archiveStatus == ArchiveStatus.downloading)
            .where((e) => e.key != archive.gid)
            .map((e) => e.value)
            .fold(
              0,
              (previousValue, a) =>
                  previousValue +
                  (a.downloadTask!.activeIsolateCount > 0
                      ? a.downloadTask!.activeIsolateCount
                      : a.downloadTask!.isolateCount),
            );
        if (currentActiveIsolateCount + task.isolateCount >
            _maxIsolateCountsTotal) {
          log.download('Archive ${archive.title} is waiting isolates...');
          return _updateArchiveStatus(
            archive.gid,
            ArchiveStatus.waitingIsolate,
          );
        }
      }

      try {
        archiveDownloadInfo.downloadCompleter = Completer();
        await task.start();
        await archiveDownloadInfo.downloadCompleter!.future;
      } on CancelException catch (_) {
        archiveDownloadInfo.downloadCompleter = null;
        return;
      } on JDownloadException catch (e) {
        archiveDownloadInfo.downloadCompleter = null;

        if ((e.type == JDownloadExceptionType.fetchContentLengthFailed ||
                e.type == JDownloadExceptionType.downloadFailed) &&
            e.error is DioException) {
          DioException dioException = e.error;
          Response? response = dioException.response;

          /// download too many bytes will cause 410/404
          if (response?.statusCode == 410 || response?.statusCode == 404) {
            return await _check410Or404Reason(
              archiveDownloadInfos[archive.gid]!.downloadUrl!,
              archive,
            );
          }
          /// too many download thread will cause 410
          else if (response?.statusCode == 429) {
            log.download('${'429Hints'.tr} Archive: ${archive.title}');
            snack('archiveError'.tr, '429Hints'.tr, isShort: true);
            return await pauseDownloadArchive(archive.gid);
          } else {
            log.download(
              'Download archive failed: ${archive.title}, original: ${archive.isOriginal}, reason: $e',
            );
            snack(
              'archiveError'.tr,
              e.error?.toString() ?? e.type.desc,
              isShort: true,
            );
            return pauseDownloadArchive(archive.gid);
          }
        } else {
          log.download(
            'Download archive failed: ${archive.title}, original: ${archive.isOriginal}, reason: $e',
          );
          snack(
            'archiveError'.tr,
            e.error?.toString() ?? e.type.desc,
            isShort: true,
          );
          return pauseDownloadArchive(archive.gid);
        }
      } on Exception catch (e) {
        log.download('Failed to download archive ${archive.title}, reason: $e');
        snack('archiveError'.tr, e.toString(), isShort: true);
        archiveDownloadInfo.downloadCompleter = null;
        return pauseDownloadArchive(archive.gid);
      }
    }

    log.download(
      'Download archive success: ${archive.title}, original: ${archive.isOriginal}',
    );

    archiveDownloadInfo.speedComputer.dispose();
    return _updateArchiveStatus(archive.gid, ArchiveStatus.downloaded);
  }

  Future<void> _unpackingArchive(ArchiveDownloadedData archive) async {
    final archiveDownloadInfo = archiveDownloadInfos[archive.gid];
    if (archiveDownloadInfo == null) return;
    if (!_isTaskInStatus(archive.gid, [
      ArchiveStatus.downloaded,
      ArchiveStatus.unpacking,
    ])) {
      return;
    }

    log.info(
      'Unpacking archive: ${archive.title}, original: ${archive.isOriginal}',
    );

    final unpackedHashes = await extractZipArchiveWithHashes(
      computePackingFileDownloadPath(archive),
      computeArchiveUnpackingPath(archive),
    );

    if (unpackedHashes == null) {
      log.error('Unpacking archive error!');
      log.uploadError(
        Exception('Unpacking error!'),
        extraInfos: {'archive': archive},
      );
      snack(
        'unpackingArchiveError'.tr,
        '${'failedToDealWith'.tr}:${archive.title}',
        isShort: true,
      );

      archiveDownloadInfo.archiveStatus = ArchiveStatus.downloading;
      await archiveDownloadInfo.downloadTask!.dispose();
      archiveDownloadInfo.downloadTask = null;
      await _deletePackingFileInDisk(archive);
      return pauseDownloadArchive(archive.gid);
    }

    if (downloadSetting.deleteArchiveFileAfterDownload.isTrue) {
      _deletePackingFileInDisk(archive);
    }

    final root = computeArchiveUnpackingPath(archive);
    final copyId = await localContentService.ensureCopy(
      gid: archive.gid,
      representation: archive.isOriginal ? 'original' : 'resampled',
      rootPath: root,
      makeCurrent: false,
    );
    final images = await getUnpackedImages(archive.gid);
    for (var i = 0; i < images.length; i++) {
      final image = images[i];
      final absolute = join(pathService.getVisibleDir().path, image.path!);
      final relativePath = relative(absolute, from: root);
      final hash = unpackedHashes[relativePath];
      if (hash == null)
        throw StateError('Missing unpacked page hash $relativePath');
      await localContentService.recordPage(
        copyId: copyId,
        ordinal: i,
        relativePath: relativePath,
        rawHash: hash,
        rawLength: await File(absolute).length(),
      );
    }
    final tags = tagDataString2TagDataList(archive.tags)
        .map((tag) => PortableTag(tag.namespace, tag.key))
        .toList();
    await localContentService.completeCopy(
      copyId,
      galleryUrl: archive.galleryUrl,
      title: archive.title,
      tags: tags,
      providerMetadata: {
        'category': archive.category,
        'uploader': archive.uploader,
        'publishTime': archive.publishTime,
      },
      collections: [
        archiveDownloadInfos[archive.gid]?.group ?? archive.groupName,
      ],
      expectedPages: images.length,
    );
    await localContentService.repository.setCurrentCopy(copyId);

    await _updateArchiveStatus(archive.gid, ArchiveStatus.completed);

    _tryWakeWaitingTasks();
  }

  // ALL

  Future<void> _instantiateFromDB() async {
    allGroups = (await ArchiveGroupDao.selectArchiveGroups())
        .map((e) => e.groupName)
        .toList();
    log.debug('init Archive groups: $allGroups');

    List<ArchiveDownloadedData> archives = await ArchiveDao.selectArchives();

    for (ArchiveDownloadedData archive in archives) {
      final root = archive.copyId == null
          ? computeArchiveUnpackingPath(archive)
          : localContentService.registeredRoot(archive.copyId!);
      if ((archive.copyId != null &&
              localContentService.isRetiringCopy(archive.copyId!)) ||
          (root != null && localContentService.isRetiringDirectory(root))) {
        await _deleteArchiveInfoInDatabase(archive.gid);
        continue;
      }
      if (root == null)
        throw StateError('Content copy is unavailable: ${archive.copyId}');
      archive = await _bindArchiveCopy(archive, root);
      _initArchiveInMemory(archive, sort: false);
    }
    _sortArchives();
  }

  Future<ArchiveDownloadedData> _bindArchiveCopy(
    ArchiveDownloadedData archive,
    String root,
  ) async {
    if (archive.copyId != null) return archive;
    final id = await localContentService.ensureCopy(
      gid: archive.gid,
      representation: archive.isOriginal ? 'original' : 'resampled',
      rootPath: root,
      makeCurrent: false,
    );
    await appDb.customStatement(
      'UPDATE archive_downloaded_v2 SET copy_id = ? WHERE gid = ?',
      [id, archive.gid],
    );
    return archive.copyWith(copyId: Value(id));
  }

  Future<ArchiveDownloadedData?> _initArchiveInfo(
    ArchiveDownloadedData archive,
  ) async {
    /// Compute and attach the sanitized title before the first DB write so the
    /// path is frozen for the lifetime of this download task.
    final int reservedBytes = utf8.encode('Archive - ${archive.gid} - ').length;
    archive = archive.copyWith(
      copyId: const Value(null),
      sanitizedTitle: Value(
        _computeSanitizedArchiveTitle(archive.title, reservedBytes),
      ),
    );
    final defaultRoot = computeArchiveUnpackingPath(archive);
    if (await localContentService.isRootReserved(defaultRoot) ||
        await Directory(defaultRoot).exists()) {
      final suffix = DateTime.now().microsecondsSinceEpoch.toString();
      archive = archive.copyWith(
        sanitizedTitle: Value(
          '${_computeSanitizedArchiveTitle(archive.title, reservedBytes + suffix.length + 1)}-$suffix',
        ),
      );
    }

    if (!await _saveArchiveAndGroupInDatabase(archive)) {
      return null;
    }

    archive = await _bindArchiveCopy(
      archive,
      computeArchiveUnpackingPath(archive),
    );
    _initArchiveInMemory(archive);
    return archive;
  }

  Future<bool> _addGroup(String group) async {
    if (!allGroups.contains(group)) {
      allGroups.add(group);
    }

    return (await ArchiveGroupDao.insertArchiveGroup(
          ArchiveGroupData(groupName: group, sortOrder: 0),
        ) >
        0);
  }

  // DB

  Future<bool> _saveArchiveAndGroupInDatabase(
    ArchiveDownloadedData archive,
  ) async {
    return appDb.transaction(() async {
      await ArchiveGroupDao.insertArchiveGroup(
        ArchiveGroupData(groupName: archive.groupName, sortOrder: 0),
      );

      return await ArchiveDao.insertArchive(
            ArchiveDownloadedCompanion.insert(
              gid: Value(archive.gid),
              token: archive.token,
              title: archive.title,
              category: archive.category,
              pageCount: archive.pageCount,
              galleryUrl: archive.galleryUrl,
              coverUrl: archive.coverUrl,
              uploader: Value(archive.uploader),
              size: archive.size,
              publishTime: archive.publishTime,
              archiveStatusCode: archive.archiveStatusCode,
              archivePageUrl: archive.archivePageUrl,
              downloadPageUrl: const Value(null),
              downloadUrl: const Value(null),
              sortOrder: Value(archive.sortOrder),
              groupName: archive.groupName,
              isOriginal: archive.isOriginal,
              insertTime: archive.insertTime,
              tags: Value(archive.tags),
              tagRefreshTime: Value(archive.tagRefreshTime),
              parseSource: Value(archive.parseSource),
              sanitizedTitle: Value(archive.sanitizedTitle),
              copyId: Value(archive.copyId),
            ),
          ) >
          0;
    });
  }

  Future<bool> _updateArchiveInDatabase(int gid) async {
    ArchiveDownloadInfo archiveDownloadInfo = archiveDownloadInfos[gid]!;

    return await ArchiveDao.updateArchive(
          ArchiveDownloadedCompanion(
            gid: Value(gid),
            archiveStatusCode: Value(archiveDownloadInfo.archiveStatus.code),
            downloadPageUrl: archiveDownloadInfo.downloadPageUrl == null
                ? const Value.absent()
                : Value(archiveDownloadInfo.downloadPageUrl),
            downloadUrl: archiveDownloadInfo.downloadUrl == null
                ? const Value.absent()
                : Value(archiveDownloadInfo.downloadUrl),
            size: Value(archiveDownloadInfo.size),
            sortOrder: Value(archiveDownloadInfo.sortOrder),
            groupName: Value(archiveDownloadInfo.group),
          ),
        ) >
        0;
  }

  Future<bool> _deleteArchiveInfoInDatabase(int gid) async {
    return await ArchiveDao.deleteArchive(gid) > 0;
  }

  // MEMORY

  void _initArchiveInMemory(ArchiveDownloadedData archive, {bool sort = true}) {
    if (!allGroups.contains(archive.groupName)) {
      allGroups.add(archive.groupName);
    }
    archives.add(archive);

    archiveDownloadInfos[archive.gid] = ArchiveDownloadInfo(
      size: archive.size,
      parseSource: archive.parseSource,
      downloadPageUrl: archive.downloadPageUrl,
      downloadUrl: archive.downloadUrl,
      archiveStatus: ArchiveStatus.fromCode(archive.archiveStatusCode),
      cancelToken: CancelToken(),
      speedComputer: SpeedComputer(
        updateCallback: () => update([
          '$archiveSpeedComputerId::${archive.gid}::${archive.isOriginal}',
        ]),
      ),
      sortOrder: archive.sortOrder,
      group: archive.groupName,
    );

    if (archive.downloadUrl != null) {
      JDownloadTask downloadTask =
          archiveDownloadInfos[archive.gid]!.downloadTask =
              _generateDownloadTask(archive.downloadUrl!, archive);
      archiveDownloadInfos[archive.gid]!.speedComputer.resetDownloadedBytes(
        downloadTask.currentBytes,
      );
    }

    if (sort) {
      _sortArchives();
    }
    update([galleryCountChangedId, '$archiveStatusId::${archive.gid}']);
  }

  Future<void> detachCompletedCopy(String copyId) async {
    for (final archive in archives.toList()) {
      if (archive.copyId == copyId &&
          archive.archiveStatusCode == ArchiveStatus.completed.code) {
        await _deleteArchiveInMemory(archive.gid);
      }
    }
  }

  Future<void> _deleteArchiveInMemory(int gid) async {
    archives.removeWhere((a) => a.gid == gid);
    ArchiveDownloadInfo? archiveDownloadInfo = archiveDownloadInfos.remove(gid);

    archiveDownloadInfo?.cancelToken.cancel();
    archiveDownloadInfo?.speedComputer.dispose();
    await archiveDownloadInfo?.downloadTask?.dispose();

    update([galleryCountChangedId]);
  }

  // DISK

  Future<void> _saveArchiveInfoInDisk(ArchiveDownloadedData archive) async {
    final root = computeArchiveUnpackingPath(archive);
    final file = File(join(root, '.content.sqlite'));
    if (!await file.exists()) return;
    final projection = DirectoryRecoveryCodec.read(file);
    final snapshot = jsonDecode(projection.taskJson) as Map<String, dynamic>;
    snapshot['archive'] = archive.toJson();
    localContentService.scheduleProjection(
      root,
      DirectoryRecoveryProjection(
        copyId: projection.copyId,
        taskKind: projection.taskKind,
        taskState: projection.taskState,
        taskJson: jsonEncode(snapshot),
        pages: projection.pages,
        completeManifest: projection.completeManifest,
        residentPages: projection.residentPages,
        codecProfiles: projection.codecProfiles,
      ),
    );
  }

  Future<void> _updateArchiveInfoInDisk(int gid) async {
    ArchiveDownloadedData? archive = archives.firstWhereOrNull(
      (a) => a.gid == gid,
    );
    ArchiveDownloadInfo? archiveDownloadInfo = archiveDownloadInfos[gid];
    if (archive == null || archiveDownloadInfo == null) {
      return;
    }

    ArchiveDownloadedData archiveWithUpdatedInfo = archive.copyWith(
      sortOrder: archiveDownloadInfo.sortOrder,
      groupName: archiveDownloadInfo.group,
    );

    return _saveArchiveInfoInDisk(archiveWithUpdatedInfo);
  }

  Future<void> _deletePackingFileInDisk(ArchiveDownloadedData archive) async {
    File file = File(computePackingFileDownloadPath(archive));
    if (await file.exists()) {
      await file.delete();
    }
    return;
  }

  Future<void> _ensureDownloadDirExists() async {
    try {
      await Directory(downloadSetting.downloadPath.value)
          .create(recursive: true);
    } on Exception catch (e) {
      log.error('Create download directory failed', e);
    }
  }
}

class ArchiveDownloadInfo {
  /// Archive true size is different from which displayed in detail page
  int size;

  int parseSource;

  String? downloadPageUrl;

  String? downloadUrl;

  ArchiveStatus archiveStatus;

  CancelToken cancelToken;

  JDownloadTask? downloadTask;

  Completer? downloadCompleter;

  SpeedComputer speedComputer;

  int sortOrder;

  String group;

  ArchiveDownloadInfo({
    required this.size,
    required this.parseSource,
    this.downloadPageUrl,
    this.downloadUrl,
    required this.archiveStatus,
    required this.cancelToken,
    this.downloadTask,
    this.downloadCompleter,
    required this.speedComputer,
    required this.sortOrder,
    required this.group,
  });

  @override
  String toString() {
    return 'ArchiveDownloadInfo{size: $size, parseSource: $parseSource, downloadPageUrl: $downloadPageUrl, downloadUrl: $downloadUrl, archiveStatus: $archiveStatus, cancelToken: $cancelToken, downloadTask: $downloadTask, downloadCompleter: $downloadCompleter, speedComputer: $speedComputer, sortOrder: $sortOrder, group: $group}';
  }
}

enum ArchiveStatus {
  needReUnlock(10),
  paused(20),
  unlocking(30),
  unlocked(35),
  parsingDownloadPageUrl(40),
  parsedDownloadPageUrl(45),
  parsingDownloadUrl(50),
  parsedDownloadUrl(55),
  waitingIsolate(58),
  downloading(60),
  downloaded(70),
  unpacking(80),
  completed(90);

  final int code;

  const ArchiveStatus(this.code);

  factory ArchiveStatus.fromCode(int code) {
    return ArchiveStatus.values.firstWhere((s) => s.code == code);
  }
}

enum ArchiveParseSource {
  official(0),
  bot(1);

  final int code;

  const ArchiveParseSource(this.code);

  factory ArchiveParseSource.fromCode(int code) {
    return ArchiveParseSource.values.firstWhere((s) => s.code == code);
  }
}
