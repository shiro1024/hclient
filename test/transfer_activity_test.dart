import 'dart:async';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/l18n/locale_text.dart';
import 'package:jhentai/src/service/transfer_activity_service.dart';
import 'package:jhentai/src/service/log.dart';

import 'support/test_log_service.dart';

import 'package:jhentai/src/utils/speed_computer.dart';

TransferActivity activity(
  String id, {
  bool upload = false,
  bool waiting = false,
  double rate = 0,
}) => TransferActivity(
  id: id,
  title: id,
  target: upload ? 'cloud' : 'download',
  upload: upload,
  waiting: waiting,
  progress: 1,
  total: 4,
  bytesPerSecond: () => rate,
);

void main() {
  late LogService previousLog;
  setUp(() {
    previousLog = log;
    log = TestLogService();
    Get.addTranslations(LocaleText().keys);
    Get.locale = const Locale('en', 'US');
  });
  tearDown(() {
    log = previousLog;
    Get.clearTranslations();
    Get.locale = null;
  });

  for (final firstThrows in [false, true]) {
    test(
      'owner recovery starts independently when the first ${firstThrows ? 'throws' : 'is held'}',
      () async {
        final service = TransferActivityService();
        final held = Completer<void>();
        final calls = <int>[];
        service.register(
          Object(),
          suspend: () async {},
          resume: () {
            calls.add(1);
            if (firstThrows) throw StateError('First owner cannot resume');
            return held.future;
          },
        );
        for (final index in [2, 3]) {
          service.register(
            Object(),
            suspend: () async {},
            resume: () async {
              calls.add(index);
            },
          );
        }
        service.suspendForSystemTimeout();
        final resumed = service.handleLifecycle(AppLifecycleState.resumed);
        await Future<void>.delayed(Duration.zero);
        expect(calls, [1, 2, 3]);
        expect(service.canAdmit, isTrue);
        if (!firstThrows) held.complete();
        await resumed;
      },
    );
  }

  test(
    'mixed notification keeps actual execution order and separate rates',
    () {
      final service = TransferActivityService();
      final firstOwner = Object();
      final otherOwner = Object();
      service.replace(firstOwner, [
        activity('first', rate: 100),
        activity('waiting', upload: true, waiting: true),
      ]);
      service.replace(otherOwner, [
        activity('second', upload: true, rate: 200),
      ]);
      var snapshot = service.notificationSnapshot();
      expect(snapshot['title'], 'first');
      expect(snapshot['text'], 'Download · 1/4 · 100 B/s');
      expect(
        (snapshot['lines'] as List).reversed.skip(1).first,
        '↓ 100 B/s · ↑ 200 B/s',
      );
      service.replace(firstOwner, [activity('waiting', upload: true)]);
      snapshot = service.notificationSnapshot();
      expect(snapshot['title'], 'second');
      expect(snapshot['text'], 'Upload · 1/4 · 200 B/s');
      expect(snapshot['total'], 4); // Only the primary task, never a mixed sum.
      service.replace(otherOwner, []);
      expect(service.notificationSnapshot()['title'], 'waiting');
      service.replace(firstOwner, []);
      expect(service.notificationSnapshot(), {'active': false});
    },
  );

  test(
    'long titles cannot displace progress and translated transfer summaries',
    () {
      Get.locale = const Locale('zh', 'CN');
      final service = TransferActivityService();
      final longTitle = List.filled(30, '非常长的作品标题').join();
      service.replace(Object(), [
        TransferActivity(
          id: 'main',
          title: longTitle,
          target: 'cloud',
          upload: true,
          progress: 12,
          total: 30,
          bytesPerSecond: () => 256,
        ),
        TransferActivity(
          id: 'other',
          title: longTitle,
          target: 'download',
          progress: 3,
          total: 8,
          bytesPerSecond: () => 128,
        ),
        activity('queued', upload: true, waiting: true),
      ]);
      final snapshot = service.notificationSnapshot();
      final lines = snapshot['lines'] as List;
      expect(snapshot['title'], longTitle);
      expect(snapshot['text'], '上传 · 12/30 · 256 B/s');
      expect(lines.first, snapshot['text']);
      expect(lines[1], startsWith('下载 · 3/8 · '));
      expect(lines[1], endsWith(longTitle));
      expect(lines[2], '↓ 128 B/s · ↑ 256 B/s');
      expect(lines.last, '下载 1 · 上传 2 · 等待 1');
      expect(snapshot['progress'], 12);
      expect(snapshot['total'], 30);
      expect(snapshot['target'], 'cloud');
    },
  );

  test(
    'system timeout closes admission before asynchronous owner settlement',
    () async {
      final service = TransferActivityService();
      final settling = Completer<void>();
      var stopped = false;
      var resumed = false;
      service.register(
        Object(),
        suspend: () {
          expect(service.canAdmit, isFalse);
          stopped = true;
          return settling.future;
        },
        resume: () async {
          resumed = true;
          expect(service.canAdmit, isTrue);
        },
      );
      service.suspendForSystemTimeout();
      expect(stopped, isTrue);
      expect(service.canAdmit, isFalse);
      expect(service.notificationSnapshot(), {'active': false});
      final resume = service.handleLifecycle(AppLifecycleState.resumed);
      expect(resumed, isFalse);
      settling.complete();
      await resume;
      expect(resumed, isTrue);
      expect(service.canAdmit, isTrue);
    },
  );

  test('speed uses actual elapsed time and counts each sampled byte once', () {
    var elapsed = Duration.zero;
    final speed = SpeedComputer(elapsed: () => elapsed);
    speed.start();
    speed.downloadedBytes = 1200;
    elapsed = const Duration(milliseconds: 2400);
    speed.computeAndUpdateSpeed();
    expect(speed.bytesPerSecond, 500);
    elapsed = const Duration(milliseconds: 3400);
    speed.computeAndUpdateSpeed();
    expect(speed.bytesPerSecond, 0);
    speed.dispose();
  });
}
