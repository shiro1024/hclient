import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../utils/speed_computer.dart';
import '../widget/app_manager.dart';
import 'jh_service.dart';
import 'log.dart';

final transferActivityService = TransferActivityService();

/// An in-memory view of an existing executor. No task or retry is owned here.
class TransferActivity {
  final String id;
  final String title;
  final String target;
  final String? copyId;
  final bool upload;
  final String phase;
  final int? _progress;
  final int? _total;
  final int? Function()? readProgress;
  final int? Function()? readTotal;
  final bool byteProgress;
  int? get progress => readProgress == null ? _progress : readProgress!();
  int? get total => readTotal == null ? _total : readTotal!();
  final bool waiting;
  final double Function() bytesPerSecond;

  const TransferActivity({
    required this.id,
    required this.title,
    required this.target,
    this.copyId,
    this.upload = false,
    this.phase = 'downloading',
    int? progress,
    int? total,
    this.readProgress,
    this.readTotal,
    this.byteProgress = false,
    this.waiting = false,
    required this.bytesPerSecond,
  }) : _progress = progress,
       _total = total;
}

class TransferActivityService
    with JHLifeCircleBeanErrorCatch
    implements JHLifeCircleBean {
  static const channel = MethodChannel('shiro.hclient.transfer');
  final Map<Object, List<TransferActivity>> _owners = {};
  final Map<String, int> _order = {};
  final Map<Object, Future<void> Function()> _suspend = {};
  final Map<Object, Future<void> Function()> _resume = {};
  int _serial = 0;
  Timer? _timer;
  bool _foreground = false;
  bool _blocked = false;
  bool _hostRunning = false;
  bool _startRejected = false;
  bool _ready = false;
  bool _updating = false;
  bool _dirty = false;
  String? _pendingTarget;
  Future<void>? _settlement;
  Completer<void>? _admissionResumed;
  Future<void> get whenAdmitted =>
      _blocked ? _admissionResumed!.future : Future<void>.value();
  Future<void> Function(String)? openTarget;
  bool Function()? navigationAllowed;
  bool _navigationScheduled = false;

  bool get canAdmit => !_blocked;
  bool get hasBackgroundSession => !_blocked && _hostRunning;

  @override
  List<JHLifeCircleBean> get initDependencies => [log];

  void register(
    Object owner, {
    required Future<void> Function() suspend,
    required Future<void> Function() resume,
  }) {
    _suspend[owner] = suspend;
    _resume[owner] = resume;
  }

  void replace(Object owner, Iterable<TransferActivity> activities) {
    _owners[owner] = activities.toList();
    final ids = _owners.values
        .expand((items) => items)
        .map((a) => a.id)
        .toSet();
    _order.removeWhere((id, _) => !ids.contains(id));
    for (final activity in _owners.values.expand((items) => items)) {
      if (!activity.waiting) _order.putIfAbsent(activity.id, () => _serial++);
    }
    if (ids.isEmpty) {
      _timer?.cancel();
      _timer = null;
    } else if (Platform.isAndroid && !_blocked) {
      _timer ??= Timer.periodic(const Duration(seconds: 1), (_) => _publish());
    }
    _publish();
  }

  void keepSessionUntil(String copyId, Future<void> work) {
    final activities = snapshot.where((item) => item.copyId == copyId).toList();
    if (activities.isEmpty) return;
    final lease = Object();
    replace(lease, activities);
    unawaited(
      work
          .whenComplete(() {
            unregister(lease);
          })
          .catchError((Object _, StackTrace __) {}),
    );
  }

  void unregister(Object owner) {
    _suspend.remove(owner);
    _resume.remove(owner);
    replace(owner, const []);
    _owners.remove(owner);
  }

  @override
  Future<void> doInitBean() async {
    AppManager.registerDidChangeAppLifecycleStateCallback(_lifecycle);
    if (!Platform.isAndroid) return;
    channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'timeout':
          suspendForSystemTimeout();
        case 'activityAttached':
          AppManager.replayActivityWindowState();
        case 'activityResumed':
          _startRejected = false;
          _foreground = true;
          await _resumeAfterSystemStop();
          _publish();
        case 'notificationTap':
          if (call.arguments case final String target)
            queueNotificationTarget(target);
      }
    });
  }

  @override
  Future<void> doAfterBeanReady() async {
    _ready = true;
    if (Platform.isAndroid) {
      _pendingTarget ??= await channel.invokeMethod<String>(
        'consumeNotificationTarget',
      );
    }
    _consumeTarget();
  }

  void navigationReady() => _consumeTarget();

  void queueNotificationTarget(String target) {
    _pendingTarget = target;
    _consumeTarget();
  }

  void _consumeTarget() {
    if (!_ready ||
        _pendingTarget == null ||
        openTarget == null ||
        _navigationScheduled)
      return;
    _navigationScheduled = true;
    // Lifecycle resume can request the existing lock route in this same turn.
    // Consume after that route decision, and only after its successful unlock.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigationScheduled = false;
      if (Get.context == null || navigationAllowed?.call() == false) return;
      final target = _pendingTarget;
      if (target == null) return;
      _pendingTarget = null;
      unawaited(openTarget!(target));
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> openNotificationSettings() async {
    if (Platform.isAndroid)
      await channel.invokeMethod<void>('openNotificationSettings');
  }

  void _lifecycle(AppLifecycleState state) {
    unawaited(
      handleLifecycle(state).catchError((Object error, StackTrace stack) {
        log.error('Resume system-stopped transfers failed', error, stack);
      }),
    );
  }

  Future<void> handleLifecycle(AppLifecycleState state) async {
    if (state == AppLifecycleState.inactive) return;
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      _startRejected = false;
      await _resumeAfterSystemStop();
      _consumeTarget();
    }
    _publish();
  }

  /// Admission closes synchronously before any owner performs asynchronous work.
  void suspendForSystemTimeout() {
    if (_blocked) return;
    _blocked = true;
    _admissionResumed = Completer<void>();
    _hostRunning = false;
    _timer?.cancel();
    _timer = null;
    final work = [for (final stop in _suspend.values) stop()];
    _settlement = Future.wait(work)
        .then<void>((_) {})
        .catchError((Object e, StackTrace s) {
          log.error('Settle system-stopped transfers failed', e, s);
        });
  }

  Future<void> _resumeAfterSystemStop() async {
    if (!_blocked || !_foreground) return;
    await _settlement;
    if (!_foreground || !_blocked) return;
    _blocked = false;
    _admissionResumed?.complete();
    _admissionResumed = null;
    final resuming = [
      for (final resume in _resume.values.toList())
        Future<void>.sync(resume).catchError((Object error, StackTrace stack) {
          log.error('Resume transfer owner failed', error, stack);
        }),
    ];
    await Future.wait(resuming);
    replace(this, const []);
  }

  List<TransferActivity> get snapshot {
    final items = {
      for (final activity in _owners.values.expand((items) => items))
        activity.id: activity,
    }.values.toList();
    items.sort(
      (a, b) => (_order[a.id] ?? _serial).compareTo(_order[b.id] ?? _serial),
    );
    return items;
  }

  Map<String, Object?> notificationSnapshot() {
    final items = snapshot;
    if (_blocked || items.isEmpty) return {'active': false};
    final executing = items.where((a) => !a.waiting).toList();
    final main = executing.isEmpty ? items.first : executing.first;
    final uploadCount = items.where((a) => a.upload).length;
    final downloadCount = items.length - uploadCount;
    final up = items
        .where((a) => a.upload)
        .fold<double>(0, (n, a) => n + a.bytesPerSecond());
    final down = items
        .where((a) => !a.upload)
        .fold<double>(0, (n, a) => n + a.bytesPerSecond());
    String number(TransferActivity a, int value) => a.byteProgress
        ? SpeedComputer.formatSpeed(value.toDouble()).replaceAll('/s', '')
        : '$value';
    String directionAndProgress(TransferActivity a) =>
        '${(a.upload ? 'transferUpload' : 'download').tr} · ${a.total != null && a.total! > 0 ? '${number(a, a.progress ?? 0)}/${number(a, a.total!)}' : a.phase.tr}';
    String detail(TransferActivity a) =>
        '${directionAndProgress(a)} · ${SpeedComputer.formatSpeed(a.bytesPerSecond())}';
    return {
      'active': true,
      'title': main.title.tr,
      'text': detail(main),
      'lines': [
        detail(main),
        for (final item in executing)
          if (item.id != main.id)
            '${directionAndProgress(item)} · ${item.title.tr}',
        '↓ ${SpeedComputer.formatSpeed(down)} · ↑ ${SpeedComputer.formatSpeed(up)}',
        '${'download'.tr} $downloadCount · ${'transferUpload'.tr} $uploadCount · ${'transferWaiting'.tr} ${items.where((a) => a.waiting).length}',
      ],
      'progress': main.progress,
      'total': main.total,
      'target': main.target,
    };
  }

  void _publish() {
    if (!Platform.isAndroid) return;
    _dirty = true;
    if (_updating) return;
    _updating = true;
    unawaited(
      (() async {
        try {
          while (_dirty) {
            _dirty = false;
            final snapshot = notificationSnapshot();
            // A rejected start is retried on actual foreground entry only.
            if (snapshot['active'] == true &&
                ((_startRejected) || (!_foreground && !_hostRunning)))
              continue;
            _hostRunning =
                await channel.invokeMethod<bool>('update', snapshot) ?? false;
            if (snapshot['active'] == true && !_hostRunning)
              _startRejected = true;
          }
        } catch (e, s) {
          _hostRunning = false;
          _startRejected = true;
          log.error('Update transfer notification failed', e, s);
        } finally {
          _updating = false;
        }
      })(),
    );
  }
}
