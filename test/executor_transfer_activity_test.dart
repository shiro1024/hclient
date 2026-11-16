import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/exception/cancel_exception.dart';
import 'package:jhentai/src/utils/eh_executor.dart';
import 'package:jhentai/src/service/transfer_activity_service.dart';

void main() {
  test(
    'notification reads live archive progress without re-registering activity',
    () {
      final service = TransferActivityService();
      int? received;
      int? total;
      service.replace(Object(), [
        TransferActivity(
          id: 'archive:1',
          title: 'Archive',
          target: 'archive',
          readProgress: () => received,
          readTotal: () => total,
          byteProgress: true,
          bytesPerSecond: () => 100,
        ),
      ]);
      expect(service.notificationSnapshot()['total'], isNull);
      received = 1024;
      total = 4096;
      expect(service.notificationSnapshot()['progress'], 1024);
      expect(service.notificationSnapshot()['total'], 4096);
      received = 3072;
      expect(service.notificationSnapshot()['progress'], 3072);
    },
  );

  test(
    'execution facts exclude queued and cancelled tasks and settle failures',
    () async {
      final executor = EHExecutor(concurrency: 1);
      final release = Completer<void>();
      final events = <String>[];
      final first = executor.scheduleTask(
        0,
        () => release.future,
        onExecutionChanged: (running) => events.add('first:$running'),
      );
      await Future<void>.delayed(Duration.zero);
      Future<void> cancelledTask() async => fail('cancelled task ran');
      final cancelled = executor.scheduleTask(
        0,
        cancelledTask,
        onExecutionChanged: (running) => events.add('cancelled:$running'),
      );
      final cancelledCheck = expectLater(
        cancelled,
        throwsA(isA<CancelException>()),
      );
      final failed = executor.scheduleTask<void>(
        1,
        () async => throw StateError('failed'),
        onExecutionChanged: (running) => events.add('failed:$running'),
      );
      final failedCheck = expectLater(failed, throwsStateError);
      expect(events, ['first:true']);
      executor.cancelTask(cancelledTask);
      release.complete();
      await Future.wait([first, cancelledCheck, failedCheck]);
      expect(events, [
        'first:true',
        'first:false',
        'failed:true',
        'failed:false',
      ]);
      await executor.close();
    },
  );
}
