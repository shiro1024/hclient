import '../pages/download/download_base_page.dart';
import '../pages/download/transfer_navigation.dart';
import '../service/transfer_activity_service.dart';

import 'dart:ui';

import 'package:blur/blur.dart';
import 'package:flutter/material.dart';
import 'package:flutter_windowmanager_plus/flutter_windowmanager_plus.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/extension/get_logic_extension.dart';

import '../config/theme_config.dart';
import '../config/ui_config.dart';
import '../routes/routes.dart';
import '../setting/security_setting.dart';
import '../setting/style_setting.dart';
import '../service/log.dart';
import '../utils/route_util.dart';

typedef DidChangePlatformBrightnessCallback = void Function();
typedef DidChangeAppLifecycleStateCallback = void Function(
  AppLifecycleState state,
);
typedef DidHaveMemoryPressureCallback = void Function();
typedef AppLaunchCallback = void Function(BuildContext context);

class AppManager extends StatefulWidget {
  static final List<DidChangePlatformBrightnessCallback>
  _didChangePlatformBrightnessCallbacks = [];
  static final List<DidChangeAppLifecycleStateCallback>
  _didChangeAppLifecycleStateCallbacks = [];
  static final List<DidHaveMemoryPressureCallback>
  _didHaveMemoryPressureCallbacks = [];

  static final List<AppLaunchCallback> _appLaunchCallbacks = [];

  static final List<VoidCallback> _activityWindowCallbacks = [];

  static void registerActivityWindowCallback(VoidCallback callback) =>
      _activityWindowCallbacks.add(callback);
  static void unregisterActivityWindowCallback(VoidCallback callback) =>
      _activityWindowCallbacks.remove(callback);

  static void replayActivityWindowState() {
    for (final callback in _activityWindowCallbacks) {
      callback();
    }
  }

  final Widget child;

  const AppManager({Key? key, required this.child}) : super(key: key);

  @override
  State<AppManager> createState() => _AppManagerState();

  static void registerDidChangePlatformBrightnessCallback(
    DidChangePlatformBrightnessCallback callback,
  ) {
    _didChangePlatformBrightnessCallbacks.add(callback);
  }

  static void unRegisterDidChangePlatformBrightnessCallback(
    DidChangePlatformBrightnessCallback callback,
  ) {
    _didChangePlatformBrightnessCallbacks.remove(callback);
  }

  static void registerDidChangeAppLifecycleStateCallback(
    DidChangeAppLifecycleStateCallback callback,
  ) {
    _didChangeAppLifecycleStateCallbacks.add(callback);
  }

  static void unRegisterDidChangeAppLifecycleStateCallback(
    DidChangeAppLifecycleStateCallback callback,
  ) {
    _didChangeAppLifecycleStateCallbacks.remove(callback);
  }

  static void registerDidHaveMemoryPressureCallback(
    DidHaveMemoryPressureCallback callback,
  ) {
    _didHaveMemoryPressureCallbacks.add(callback);
  }

  static void unRegisterDidHaveMemoryPressureCallback(
    DidHaveMemoryPressureCallback callback,
  ) {
    _didHaveMemoryPressureCallbacks.remove(callback);
  }

  static void registerAppLaunchCallback(AppLaunchCallback callback) {
    _appLaunchCallbacks.add(callback);
  }

  static void unRegisterAppLaunchCallback(AppLaunchCallback callback) {
    _appLaunchCallbacks.remove(callback);
  }
}

class _AppManagerState extends State<AppManager> with WidgetsBindingObserver {
  late final AppLifecycleListener _listener;
  DateTime? lastInactiveTime;
  bool inBlur = false;

  late AppLifecycleState _currentState;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    transferActivityService.navigationAllowed = () =>
        _currentState == AppLifecycleState.resumed &&
        !inBlur &&
        !isRouteAtTop(Routes.lock);
    transferActivityService.openTarget = (target) async {
      final type = switch (target) {
        'archive' => DownloadPageGalleryType.archive,
        'cloud' => DownloadPageGalleryType.cloud,
        _ => DownloadPageGalleryType.download,
      };
      toRoute(
        Routes.download,
        preventDuplicates: false,
        arguments: TransferDownloadNavigation(
          type,
          showCloudTransfers: target == 'cloud',
        ),
      );
    };
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => transferActivityService.navigationReady(),
    );

    _listener = AppLifecycleListener(
      onInactive: _onInactive,
      onResume: _onResume,
      onStateChange: (AppLifecycleState state) => _currentState = state,
    );

    _currentState =
        WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.detached;
    for (final callback in AppManager._didChangeAppLifecycleStateCallbacks) {
      callback(_currentState);
    }

    AppManager.registerAppLaunchCallback(_addSecureFlagForAndroid);
    AppManager.registerActivityWindowCallback(_replayWindow);
    AppManager.registerDidChangePlatformBrightnessCallback(_changeTheme);
    AppManager.registerDidHaveMemoryPressureCallback(_logMemoryPressure);

    for (var callback in AppManager._appLaunchCallbacks) {
      callback.call(context);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _listener.dispose();
    AppManager.unRegisterAppLaunchCallback(_addSecureFlagForAndroid);
    AppManager.unregisterActivityWindowCallback(_replayWindow);
    AppManager.unRegisterDidChangePlatformBrightnessCallback(_changeTheme);
    AppManager.unRegisterDidHaveMemoryPressureCallback(_logMemoryPressure);
    transferActivityService.openTarget = null;
    transferActivityService.navigationAllowed = null;
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    for (DidChangePlatformBrightnessCallback callback
        in AppManager._didChangePlatformBrightnessCallbacks) {
      callback.call();
    }
    super.didChangePlatformBrightness();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    for (DidChangeAppLifecycleStateCallback callback
        in AppManager._didChangeAppLifecycleStateCallbacks) {
      callback.call(state);
    }
    super.didChangeAppLifecycleState(state);
  }

  @override
  void didHaveMemoryPressure() {
    if (_currentState == AppLifecycleState.resumed) {
      for (DidHaveMemoryPressureCallback callback
          in AppManager._didHaveMemoryPressureCallbacks) {
        callback.call();
      }
    }
    super.didHaveMemoryPressure();
  }

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: UIConfig.scrollBehaviourWithScrollBar,
      child: inBlur
          ? Blur(
              blur: 100,
              blurColor: GetPlatform.isAndroid
                  ? Colors.white
                  : Colors.grey.shade600,
              colorOpacity: 1,
              child: widget.child,
            )
          : widget.child,
    );
  }

  void _changeTheme() {
    if (styleSetting.themeMode.value != ThemeMode.system) {
      return;
    }
    if (PlatformDispatcher.instance.platformBrightness == Brightness.light) {
      Get.rootController.theme = ThemeConfig.theme(
        styleSetting.lightThemeColor.value,
        Brightness.light,
      );
    } else {
      Get.rootController.darkTheme = ThemeConfig.theme(
        styleSetting.darkThemeColor.value,
        Brightness.dark,
      );
    }

    Get.rootController.updateSafely();
  }

  void _logMemoryPressure() {
    log.warning('Memory pressure');
  }

  void _onInactive() {
    log.debug('App is hidden');

    if (securitySetting.enableAuthOnResume.isTrue) {
      lastInactiveTime ??= DateTime.now();
    }

    if ((securitySetting.enableAuthOnResume.isTrue ||
            securitySetting.enableBlur.isTrue) &&
        !inBlur &&
        !isRouteAtTop(Routes.lock)) {
      setState(() => inBlur = true);
    }
  }

  void _removeBlur() {
    if (!mounted) return;
    setState(() => inBlur = false);
    transferActivityService.navigationReady();
  }

  void _onResume() {
    log.debug('App is shown');
    transferActivityService.navigationReady();

    if (!inBlur) {
      return;
    }

    if (securitySetting.enableBlur.isFalse) {
      return;
    }

    if (securitySetting.enableAuthOnResume.isFalse) {
      _removeBlur();
      return;
    }

    if ((securitySetting.enablePasswordAuth.isTrue ||
            securitySetting.enableBiometricAuth.isTrue) &&
        DateTime.now().difference(lastInactiveTime!).inSeconds >= 3) {
      toRoute(Routes.lock);
      Future.delayed(const Duration(milliseconds: 300), () => _removeBlur());
      lastInactiveTime = null;
    } else {
      _removeBlur();
      return;
    }
  }

  /// for Android, blur is invalid when switch app to background(app is still clearly visible in switcher),
  /// so i choose to set FLAG_SECURE to do the same effect.
  void _replayWindow() => _addSecureFlagForAndroid(context);

  void _addSecureFlagForAndroid(BuildContext context) {
    if (GetPlatform.isAndroid &&
        (securitySetting.enableAuthOnResume.isTrue ||
            securitySetting.enableBlur.isTrue)) {
      FlutterWindowManagerPlus.addFlags(FlutterWindowManagerPlus.FLAG_SECURE);
    }
  }
}
