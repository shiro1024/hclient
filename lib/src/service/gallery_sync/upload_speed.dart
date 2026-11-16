import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../utils/speed_computer.dart';

/// One upload's approximate aggregate request-body rate, sampled each second.
class UploadSpeed {
  UploadSpeed({this.elapsed});
  final Duration Function()? elapsed;
  final _value = ValueNotifier<String?>(null);
  late final SpeedComputer _computer = SpeedComputer(
    updateCallback: () => _value.value = _computer.speed,
    elapsed: elapsed,
  );
  bool _closed = false;

  ValueListenable<String?> get listenable => _value;
  double get bytesPerSecond => _computer.bytesPerSecond;

  /// Dio counters belong to an individual request, including each retry.
  ProgressCallback requestProgress() {
    var lastSent = 0;
    if (!_closed && !_computer.isActive()) {
      _value.value = '0 B/s';
      _computer.start();
    }
    return (sent, total) {
      if (_closed) return;
      _computer.downloadedBytes += sent >= lastSent ? sent - lastSent : sent;
      lastSent = sent;
    };
  }

  void dispose() {
    if (_closed) return;
    _closed = true;
    _computer.dispose();
    _value.value = null;
    // A queried job can still reach the view after its runner has finished.
    // Keep that snapshot subscribable; it owns no timer or external resource.
  }
}
