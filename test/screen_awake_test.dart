import 'dart:async';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/service/archive_download_service.dart';
import 'package:jhentai/src/service/gallery_download/gallery_download_service.dart';
import 'package:jhentai/src/service/log.dart';
import 'package:jhentai/src/service/screen_awake_service.dart';
import 'package:jhentai/src/utils/speed_computer.dart';

import 'support/test_log_service.dart';

void main() {
  setUp(() {
    log = TestLogService();
  });

  test(
    'reader and transfer requests combine and follow visible lifecycle',
    () async {
      final calls = <bool>[];
      final awake = ScreenAwakeService(
        toggle: (value) async {
          calls.add(value);
        },
      );
      final reader = Object(), transfer = Object();
      await awake.setRequested(reader, true);
      expect(calls, isEmpty);
      await awake.handleLifecycle(AppLifecycleState.resumed);
      await awake.setRequested(transfer, true);
      await awake.setRequested(reader, false);
      await awake.handleLifecycle(AppLifecycleState.inactive);
      expect(calls, [true]);
      await awake.handleLifecycle(AppLifecycleState.hidden);
      expect(calls, [true, false]);
      await awake.handleLifecycle(AppLifecycleState.resumed);
      await awake.setRequested(transfer, false);
      expect(calls, [true, false, true, false]);
    },
  );

  test('a delayed platform enable settles before the latest disable', () async {
    final calls = <bool>[];
    final started = Completer<void>(), release = Completer<void>();
    final awake = ScreenAwakeService(
      toggle: (value) async {
        calls.add(value);
        if (value) {
          started.complete();
          await release.future;
        }
      },
    );
    await awake.handleLifecycle(AppLifecycleState.resumed);
    final owner = Object();
    final enabling = awake.setRequested(owner, true);
    await started.future;
    final completed = awake.setRequested(owner, false);
    final hidden = awake.handleLifecycle(AppLifecycleState.paused);
    release.complete();
    await Future.wait([enabling, completed, hidden]);
    expect(calls, [true, false]);
  });

  test('platform failure does not poison later requests', () async {
    var attempts = 0;
    final awake = ScreenAwakeService(
      toggle: (_) async {
        if (++attempts == 1) throw StateError('Platform unavailable');
      },
    );
    final owner = Object();
    await awake.handleLifecycle(AppLifecycleState.resumed);
    await awake.setRequested(owner, true);
    await awake.setRequested(owner, false);
    await awake.setRequested(owner, true);
    expect(attempts, 2);
    await awake.setRequested(owner, false);
    expect(attempts, 3);
  });

  test(
    'gallery status and queued tasks drive awake without page JSON',
    () async {
      final previous = screenAwakeService;
      final calls = <bool>[];
      final awake = screenAwakeService = ScreenAwakeService(
        toggle: (value) async {
          calls.add(value);
        },
      );
      final gallery = GalleryDownloadService();
      final task = GalleryDownloadInfo(
        gid: 1,
        token: 'token',
        galleryUrl: 'https://e-hentai.org/g/1/token/',
        title: 'Title',
        category: 'Manga',
        pageCount: 1,
        thumbnailsCountPerPage: 20,
        tasks: [() async {}],
        cancelToken: CancelToken(),
        downloadProgress: GalleryDownloadProgress(
          curCount: 0,
          totalCount: 1,
          downloadStatus: DownloadStatus.downloading,
        ),
        imageHrefs: [null],
        images: [],
        priority: 0,
        sortOrder: 0,
        group: '',
        downloadOriginalImage: true,
        tags: '',
        tagRefreshTime: null,
        publishTime: '',
        insertTime: '',
        onSpeedUpdate: () {},
      );
      try {
        await awake.handleLifecycle(AppLifecycleState.resumed);
        gallery.galleryDownloadInfos[1] = task;
        gallery.update([gallery.galleryCountChangedId]);
        await awake.setRequested(Object(), false);
        expect(calls, [true]);
        task.downloadProgress.downloadStatus = DownloadStatus.paused;
        gallery.update(['${gallery.galleryDownloadProgressId}::1']);
        await awake.setRequested(Object(), false);
        expect(calls, [true, false]);
        task.downloadProgress.downloadStatus = DownloadStatus.downloading;
        gallery.update(['${gallery.galleryDownloadProgressId}::1']);
        await awake.setRequested(Object(), false);
        task.tasks
            .clear(); // An executor error can leave its old display status.
        gallery.update(['${gallery.galleryDownloadProgressId}::1']);
        await awake.setRequested(Object(), false);
        expect(calls, [true, false, true, false]);
      } finally {
        await awake.setRequested(gallery, false);
        screenAwakeService = previous;
      }
    },
  );

  test(
    'archive waiting queue holds awake but paused and stale failed work do not',
    () async {
      final previous = screenAwakeService;
      final calls = <bool>[];
      final awake = screenAwakeService = ScreenAwakeService(
        toggle: (value) async {
          calls.add(value);
        },
      );
      final archive = ArchiveDownloadService();
      final info = ArchiveDownloadInfo(
        size: 0,
        parseSource: 0,
        archiveStatus: ArchiveStatus.waitingIsolate,
        cancelToken: CancelToken(),
        speedComputer: SpeedComputer(),
        sortOrder: 0,
        group: '',
      );
      try {
        await awake.handleLifecycle(AppLifecycleState.resumed);
        archive.archiveDownloadInfos[1] = info;
        archive.update([archive.galleryCountChangedId]);
        await awake.setRequested(Object(), false);
        expect(calls, [true]);
        for (final state in [
          ArchiveStatus.paused,
          ArchiveStatus.needReUnlock,
          ArchiveStatus.completed,
          ArchiveStatus.unpacking,
        ]) {
          info.archiveStatus = state;
          archive.update(['${ArchiveDownloadService.archiveStatusId}::1']);
          await awake.setRequested(Object(), false);
        }
        expect(calls, [true, false]);
      } finally {
        await awake.setRequested(archive, false);
        screenAwakeService = previous;
      }
    },
  );
}
