import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Gives Android's edge-back callback the drawers of the current route only.
/// Android 14+ commits the swipe before opening a standard Material drawer.
class EdgeDrawerScope extends StatefulWidget {
  const EdgeDrawerScope({super.key, required this.scaffoldKey, this.leftEnabled = false, this.rightEnabled = false, required this.builder});

  final GlobalKey<ScaffoldState> scaffoldKey;
  final bool leftEnabled;
  final bool rightEnabled;
  final Widget Function(BuildContext context, VoidCallback drawersChanged) builder;

  @override
  State<EdgeDrawerScope> createState() => _EdgeDrawerScopeState();
}

class _EdgeDrawerScopeState extends State<EdgeDrawerScope> {
  static const _channel = MethodChannel('shiro.hclient.edge_drawer');
  static int _nextId = 0;
  static _EdgeDrawerScopeState? _active;

  final int _id = ++_nextId;
  ModalRoute<dynamic>? _route;
  bool _syncScheduled = false;

  bool get _android => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  bool get _current => mounted && _route?.isCurrent == true;
  bool get _drawerOpen {
    final scaffold = widget.scaffoldKey.currentState;
    return scaffold?.isDrawerOpen == true || scaffold?.isEndDrawerOpen == true;
  }

  @override
  void initState() {
    super.initState();
    if (_android) {
      _channel.setMethodCallHandler(_handlePlatformCall);
    }
  }

  static Future<void> _handlePlatformCall(MethodCall call) async {
    if (call.method != 'open') {
      throw MissingPluginException();
    }
    final arguments = call.arguments as Map<Object?, Object?>;
    final owner = _active;
    if (owner == null || arguments['id'] != owner._id || !owner._current || owner._drawerOpen) {
      return;
    }
    final scaffold = owner.widget.scaffoldKey.currentState;
    if (arguments['side'] == 'left' && owner.widget.leftEnabled) {
      scaffold?.openDrawer();
    }
    if (arguments['side'] == 'right' && owner.widget.rightEnabled) {
      scaffold?.openEndDrawer();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
    if (!_current) {
      _release();
    }
    _scheduleSync();
  }

  @override
  void didUpdateWidget(EdgeDrawerScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleSync();
  }

  void _scheduleSync() {
    if (!_android || _syncScheduled) {
      return;
    }
    _syncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncScheduled = false;
      _sync();
    });
  }

  void _sync() {
    if (!_android || !_current) {
      return;
    }
    _active = this;
    unawaited(_channel.invokeMethod<void>('update', {'id': _id, 'left': widget.leftEnabled && !_drawerOpen, 'right': widget.rightEnabled && !_drawerOpen}));
  }

  void _release() {
    if (!_android || _active != this) {
      return;
    }
    _active = null;
    unawaited(_channel.invokeMethod<void>('update', {'id': null, 'left': false, 'right': false}));
  }

  @override
  void dispose() {
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _sync);
}
