import 'dart:async';

import 'package:flutter/foundation.dart';

class SpeedComputer {
  Timer? timer;

  String speed = '0 B/s';

  int downloadedBytesLastTime = 0;
  int downloadedBytes = 0;

  VoidCallback? updateCallback;

  SpeedComputer({this.updateCallback, Duration Function()? elapsed})
    : _elapsed = elapsed;
  final Duration Function()? _elapsed;
  int get _nowMicros =>
      _elapsed?.call().inMicroseconds ?? _clock.elapsedMicroseconds;

  bool isActive() {
    return timer?.isActive ?? false;
  }

  void start() {
    if (isActive()) {
      return;
    }
    _clock.start();
    _sampleMicros = _nowMicros;
    downloadedBytesLastTime = downloadedBytes;
    timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => computeAndUpdateSpeed(),
    );
  }

  final Stopwatch _clock = Stopwatch();
  int _sampleMicros = 0;
  double bytesPerSecond = 0;

  void computeAndUpdateSpeed() {
    final now = _nowMicros;
    final elapsed = now - _sampleMicros;
    final delta = downloadedBytes - downloadedBytesLastTime;
    downloadedBytesLastTime = downloadedBytes;
    _sampleMicros = now;
    bytesPerSecond = elapsed > 0 && delta > 0 ? delta * 1000000 / elapsed : 0;
    speed = formatSpeed(bytesPerSecond);
    updateCallback?.call();
  }

  static String formatSpeed(double bytes) {
    if (bytes < 1024) return '${bytes.toInt()} B/s';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toInt()} KB/s';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB/s';
  }

  void resetDownloadedBytes(int bytes) {
    downloadedBytes = bytes;
    downloadedBytesLastTime = bytes;
  }

  void pause() {
    timer?.cancel();
    bytesPerSecond = 0;
    speed = '0 B/s';
  }

  void dispose() {
    pause();
  }
}
