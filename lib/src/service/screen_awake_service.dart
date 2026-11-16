import 'dart:async';
import 'dart:ui';

import 'package:wakelock_plus/wakelock_plus.dart';

import '../widget/app_manager.dart';
import 'jh_service.dart';
import 'log.dart';

ScreenAwakeService screenAwakeService = ScreenAwakeService();

/// Reader and transfer owners share the platform's single screen-awake flag.
class ScreenAwakeService
    with JHLifeCircleBeanErrorCatch
    implements JHLifeCircleBean {
  ScreenAwakeService({Future<void> Function(bool)? toggle})
    : _toggle = toggle ?? ((enabled) => WakelockPlus.toggle(enable: enabled));

  final Future<void> Function(bool) _toggle;
  final Set<Object> _requests = {};
  bool _foreground = false;
  bool _applied = false;
  Future<void> _tail = Future<void>.value();

  @override
  List<JHLifeCircleBean> get initDependencies => [log];

  @override
  Future<void> doInitBean() async {
    AppManager.registerDidChangeAppLifecycleStateCallback(_onLifecycle);
    AppManager.registerActivityWindowCallback(() {
      _applied = false;
      unawaited(_apply());
    });
  }

  @override
  Future<void> doAfterBeanReady() async {}

  Future<void> setRequested(Object owner, bool requested) {
    final changed = requested ? _requests.add(owner) : _requests.remove(owner);
    return changed ? _apply() : _tail;
  }

  void _onLifecycle(AppLifecycleState state) {
    unawaited(handleLifecycle(state));
  }

  Future<void> handleLifecycle(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) return _tail;
    _foreground = state == AppLifecycleState.resumed;
    return _apply();
  }

  Future<void> _apply() {
    // Each queued application reads the latest combined demand. An older
    // asynchronous enable cannot finish after a newer disable.
    return _tail = _tail
        .then((_) async {
          final desired = _foreground && _requests.isNotEmpty;
          if (desired == _applied) return;
          await _toggle(desired);
          _applied = desired;
        })
        .catchError((Object error, StackTrace stack) {
          log.error('Update screen awake state failed', error, stack);
        });
  }
}
