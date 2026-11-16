import 'dart:async';
import 'dart:io';

import 'package:jhentai/src/service/archive_downloader/src/util/lock.dart';
import 'package:logger/logger.dart';

typedef AsyncValueCallback<T> = Future<T> Function();

class FileManager {
  final String path;
  final Logger _logger;

  bool _writeReady = false;
  RandomAccessFile? _writeRaf;
  Lock? _writeLock;

  FileManager({required this.path, required Logger logger}) : _logger = logger;

  Future<void> truncate(int length) async {
    await _writeOperation(() => _writeRaf!.truncate(length));
  }

  Future<void> writeFrom(List<int> buffer, {int? position}) async {
    await _writeOperation(() async {
      if (position != null) {
        await _writeRaf!.setPosition(position);
      }
      await _writeRaf!.writeFrom(buffer);
    });
  }

  Future<void> close() async {
    await _closeWrite();
  }

  Future<T> _writeOperation<T>(AsyncValueCallback<T> operation) async {
    await _initWrite();
    T result = await _writeLock!.lock(operation);
    return result;
  }

  Future<void> _initWrite() async {
    if (_writeReady) {
      return;
    }

    _logger.d('init write file');

    _writeRaf = await File(path).open(mode: FileMode.writeOnlyAppend);
    _writeLock = Lock();
    _writeReady = true;
  }

  Future<void> _closeWrite() async {
    if (!_writeReady) {
      return;
    }

    await _writeLock!.dispose();
    await _writeRaf!.flush();
    await _writeRaf!.close();

    _writeLock = null;
    _writeReady = false;
    _writeRaf = null;

    _logger.d('close write file');
  }
}
