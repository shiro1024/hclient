import 'transfer_activity_service.dart';
import 'gallery_sync/upload_speed.dart';
import 'screen_awake_service.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:extended_image/extended_image.dart';
import 'package:retry/retry.dart';
import 'package:path/path.dart' as path;

import '../model/detail_page_info.dart';
import '../model/gallery_image.dart';
import '../network/eh_request.dart';
import '../setting/site_setting.dart';
import '../utils/eh_spider_parser.dart';
import 'log.dart';
import 'local_content_service.dart';

ContentPageDownloadService contentPageDownloadService =
    ContentPageDownloadService();

/// Website actions on an owner page. Reading itself never uses this network
/// path. Requests join the owner's retirement and relocation boundary.
class ContentPageDownloadService extends ChangeNotifier {
  ContentPageDownloadService() {
    transferActivityService.register(
      this,
      suspend: _suspendForSystem,
      resume: resumePendingReplacements,
    );
  }
  @override
  void dispose() {
    transferActivityService.unregister(this);
    super.dispose();
  }

  final Map<(String, int), UploadSpeed> _speeds = {};
  final Map<(String, int), int> _progress = {}, _totals = {};

  ProgressCallback _requestProgress((String, int) key) {
    final recordSpeed = _speeds[key]!.requestProgress();
    return (current, total) {
      _progress[key] = current;
      if (total > 0) _totals[key] = total;
      recordSpeed(current, total);
    };
  }

  Future<void> _suspendForSystem() async {
    final active = _downloads.values.toList();
    for (final job in active) {
      job.token.cancel('System dataSync timeout');
    }
    await Future.wait(
      active.map((job) => job.done.catchError((Object _, StackTrace __) {})),
    );
  }

  // Retains the existing gallery replacement request retry policy.
  static const _maxRetryTimes = 5;
  final Map<
    (String, int),
    ({CancelToken token, Future<void> done, String? galleryUrl})
  >
  _downloads = {};
  final Map<String, List<({int ordinal, String? galleryUrl})>>
  _resumeAfterRelocation = {};

  void _updateScreenAwake() {
    transferActivityService.replace(this, [
      for (final entry in _downloads.entries)
        if (!entry.value.token.isCancelled)
          TransferActivity(
            id: 'page:${entry.key.$1}:${entry.key.$2}',
            copyId: entry.key.$1,
            title: 'singlePageTransfer',
            target: 'download',
            byteProgress: true,
            readProgress: () => _progress[entry.key],
            readTotal: () => _totals[entry.key],
            bytesPerSecond: () => _speeds[entry.key]?.bytesPerSecond ?? 0,
          ),
    ]);
    screenAwakeService.setRequested(
      this,
      _downloads.values.any((job) => !job.token.isCancelled),
    );
  }

  Future<({String representation, String? galleryUrl})> _source(
    String copyId,
  ) async {
    final row = await localContentService.repository.db
        .customSelect(
          '''SELECT c.representation, c.metadata_json,
            COALESCE(g.gallery_url, a.gallery_url) AS task_gallery_url
          FROM content_copy c
          LEFT JOIN gallery_downloaded_v2 g ON g.copy_id=c.copy_id
          LEFT JOIN archive_downloaded_v2 a ON a.copy_id=c.copy_id
          WHERE c.copy_id = ?''',
          variables: [Variable.withString(copyId)],
        )
        .getSingle();
    final json = row.readNullable<String>('metadata_json');
    final metadata = json == null
        ? const <String, dynamic>{}
        : jsonDecode(json) as Map<String, dynamic>;
    return (
      representation: row.read<String>('representation'),
      galleryUrl: (metadata['galleryUrl'] as String?)?.isNotEmpty == true
          ? metadata['galleryUrl'] as String
          : row.readNullable<String>('task_gallery_url'),
    );
  }

  Future<String> sourcePageUrl(
    String copyId,
    int ordinal, {
    String? galleryUrl,
  }) => _sourcePageUrl(copyId, ordinal, galleryUrl: galleryUrl);

  Future<String> _sourcePageUrl(
    String copyId,
    int ordinal, {
    String? galleryUrl,
    CancelToken? cancelToken,
  }) async {
    final page = await localContentService.repository.getPage(copyId, ordinal);
    if (page.sourcePageUrl case final existing? when existing.isNotEmpty)
      return existing;
    final saved = (await _source(copyId)).galleryUrl;
    final source = saved == null || saved.isEmpty ? galleryUrl : saved;
    if (source == null || source.isEmpty)
      throw StateError('Gallery source is unavailable');
    var pageIndex = ordinal ~/ SiteSetting.thumbnailsCountPerPage.value;
    DetailPageInfo detail = await ehRequest.requestDetailPage(
      galleryUrl: source,
      thumbnailsPageIndex: pageIndex,
      useCacheIfAvailable: false,
      cancelToken: cancelToken,
      parser: EHSpiderParser.detailPage2RangeAndThumbnails,
    );
    if (ordinal < detail.imageNoFrom || ordinal > detail.imageNoTo) {
      pageIndex = ordinal ~/ detail.thumbnailsCountPerPage;
      detail = await ehRequest.requestDetailPage(
        galleryUrl: source,
        thumbnailsPageIndex: pageIndex,
        cancelToken: cancelToken,
        useCacheIfAvailable: false,
        parser: EHSpiderParser.detailPage2RangeAndThumbnails,
      );
    }
    if (ordinal < detail.imageNoFrom || ordinal > detail.imageNoTo)
      throw StateError('Source page is unavailable: $ordinal');
    final url = detail.thumbnails[ordinal - detail.imageNoFrom].replacedMPVHref(
      ordinal + 1,
    );
    await localContentService.setSourcePageUrl(copyId, ordinal, url);
    return url;
  }

  Future<void> redownload(
    String copyId,
    int ordinal, {
    String? galleryUrl,
  }) async {
    await transferActivityService.whenAdmitted;
    await _start(copyId, ordinal, galleryUrl: galleryUrl, createIfEmpty: true);
  }

  Future<void> _start(
    String copyId,
    int ordinal, {
    String? galleryUrl,
    required bool createIfEmpty,
  }) async {
    if (localContentService.isRetiringCopy(copyId) ||
        localContentService.isRelocating(copyId)) {
      throw StateError('Content copy is unavailable');
    }
    if (!transferActivityService.canAdmit) return;
    final key = (copyId, ordinal);
    final existing = _downloads[key];
    if (existing != null) return existing.done;
    final token = CancelToken();
    _speeds[key] = UploadSpeed();
    final done = _redownload(
      copyId,
      ordinal,
      token,
      galleryUrl: galleryUrl,
      createIfEmpty: createIfEmpty,
    );
    _downloads[key] = (token: token, done: done, galleryUrl: galleryUrl);
    _updateScreenAwake();
    try {
      await done;
    } finally {
      if (identical(_downloads[key]?.done, done)) _downloads.remove(key);
      _speeds.remove(key)?.dispose();
      _progress.remove(key);
      _totals.remove(key);
      _updateScreenAwake();
    }
  }

  Future<void> _redownload(
    String copyId,
    int ordinal,
    CancelToken token, {
    String? galleryUrl,
    required bool createIfEmpty,
  }) async {
    while (true) {
      if (token.isCancelled) throw token.cancelError!;
      final page = await localContentService.repository.getPage(
        copyId,
        ordinal,
      );
      final pending =
          (await localContentService.repository.listPageReplacements(copyId))
              .where((item) => item.ordinal == ordinal)
              .toList();
      if (pending.isEmpty && !createIfEmpty) return;
      createIfEmpty = false;
      final replacement = pending.isEmpty
          ? await localContentService.enqueuePageReplacement(
              copyId: copyId,
              ordinal: ordinal,
              newRelativePath: path.join(
                path.dirname(page.relativePath),
                await localContentService.pageExportName(copyId, ordinal),
              ),
            )
          : pending.first;
      if (replacement.state != 'downloading') {
        await localContentService.commitPageReplacement(
          replacement.replacementId,
        );
      } else {
        // The owner journal has already withdrawn any upload release decision.
        final source = await _source(copyId);
        final original = source.representation == 'original';
        final downloaded = await retry(
          () async {
            final url = await _sourcePageUrl(
              copyId,
              ordinal,
              galleryUrl: galleryUrl,
              cancelToken: token,
            );
            final image = await ehRequest.requestImagePage<GalleryImage>(
              url,
              cancelToken: token,
              useCacheIfAvailable: false,
              parser: EHSpiderParser.imagePage2GalleryImage,
            );
            final downloadUrl = original
                ? image.originalImageUrl ?? image.url
                : image.url;
            final result = await ehRequest.downloadWithHash(
              onReceiveProgress: _requestProgress((copyId, ordinal)),
              url: downloadUrl,
              path: replacement.tempPath,
              cancelToken: token,
              receiveTimeout: 3 * 60 * 1000,
            );
            if (!result.response.isRedirect &&
                result.response.headers
                        .value(Headers.contentTypeHeader)
                        ?.toLowerCase()
                        .contains('text/html') ==
                    true) {
              final temporary = File(replacement.tempPath);
              if (await temporary.exists()) await temporary.delete();
              throw StateError('Replacement response is HTML');
            }
            return (image: image, result: result);
          },
          retryIf: (error) =>
              error is DioException &&
              !CancelToken.isCancel(error) &&
              !token.isCancelled,
          maxAttempts: _maxRetryTimes,
        );
        final image = downloaded.image;
        final result = downloaded.result;
        await localContentService.finishDownloadedReplacement(
          replacement.replacementId,
          rawHash: result.rawHash,
          rawLength: result.rawLength,
          mime:
              result.response.headers
                  .value(Headers.contentTypeHeader)
                  ?.split(';')
                  .first ??
              page.mime,
          width:
              (original ? image.originalImageWidth ?? image.width : image.width)
                  ?.round(),
          height:
              (original
                      ? image.originalImageHeight ?? image.height
                      : image.height)
                  ?.round(),
        );
      }
      await ExtendedFileImageProvider(File(replacement.newPath)).evict();
      notifyListeners();
      // A second queued request belongs to this same page owner as well.
    }
  }

  Future<void> resumePendingReplacements() async {
    if (!transferActivityService.canAdmit) return;
    final rows = await localContentService.repository.db
        .customSelect(
          "SELECT DISTINCT p.copy_id, p.ordinal FROM content_page_replacement p "
          "JOIN content_copy c ON c.copy_id=p.copy_id WHERE c.lifecycle='active' AND p.state!='completed'",
        )
        .get();
    for (final row in rows) {
      final copyId = row.read<String>('copy_id');
      if (localContentService.isRelocating(copyId) ||
          localContentService.isRetiringCopy(copyId))
        continue;
      _resume(copyId, row.read<int>('ordinal'));
    }
  }

  void _resume(String copyId, int ordinal, {String? galleryUrl}) {
    unawaited(
      _start(
        copyId,
        ordinal,
        galleryUrl: galleryUrl,
        createIfEmpty: false,
      ).catchError((Object error, StackTrace stack) {
        if (error is DioException && CancelToken.isCancel(error)) return;
        log.error(
          'Resume owner page download failed: $copyId/$ordinal',
          error,
          stack,
        );
      }),
    );
  }

  Future<void> cancelAndJoin(String copyId) async {
    final active = [
      for (final job in _downloads.entries)
        if (job.key.$1 == copyId) job.value,
    ];
    for (final job in active) {
      job.token.cancel('Content copy is moving or retiring');
    }
    _updateScreenAwake();
    await Future.wait([
      for (final job in active)
        job.done.then<void>(
          (_) {},
          onError: (Object error, StackTrace stack) {},
        ),
    ]);
  }

  Future<void> prepareCopyRelocation(String copyId) async {
    _resumeAfterRelocation[copyId] = [
      for (final job in _downloads.entries)
        if (job.key.$1 == copyId)
          (ordinal: job.key.$2, galleryUrl: job.value.galleryUrl),
    ];
    await cancelAndJoin(copyId);
  }

  Future<void> finishCopyRelocation(String copyId, bool usable) async {
    final inputs = _resumeAfterRelocation.remove(copyId) ?? const [];
    if (!usable || inputs.isEmpty) return;
    final pending = await localContentService.repository.listPageReplacements(
      copyId,
    );
    for (final input in inputs) {
      if (!pending.any((item) => item.ordinal == input.ordinal)) continue;
      _resume(copyId, input.ordinal, galleryUrl: input.galleryUrl);
    }
  }
}
