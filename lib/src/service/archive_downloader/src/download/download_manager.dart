import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_socks_proxy/socks_proxy.dart';
import 'package:jhentai/src/service/archive_downloader/j_downloader.dart';
import 'package:jhentai/src/service/archive_downloader/src/extension/file_extension.dart';
import 'package:jhentai/src/service/archive_downloader/src/file/file_manager.dart';
import 'package:jhentai/src/service/archive_downloader/src/function/function.dart';
import 'package:jhentai/src/service/archive_downloader/src/isolate/main_isolate_manager.dart';
import 'package:jhentai/src/service/archive_downloader/src/model/download_chunk.dart';
import 'package:jhentai/src/service/archive_downloader/src/model/download_progress.dart';
import 'package:jhentai/src/service/archive_downloader/src/util/lock.dart';
import 'package:jhentai/src/service/archive_downloader/src/util/log_output.dart';
import 'package:logger/logger.dart';
import 'package:retry/retry.dart';

typedef AsyncVoidCallback<T> = Future Function();

class DownloadManager {
  final String url;
  final String downloadPath;
  final String savePath;

  ProxyConfig? proxyConfig;

  late int _isolateCount;

  late final Dio _dio;

  late final int totalBytes;

  bool _useRange = true;
  bool _running = false;
  bool _handlingError = false;
  bool _completing = false;

  bool _fileReady = false;
  late FileManager _fileManager;

  bool _chunksReady = false;
  List<DownloadTrunk> _chunks = [];
  List<bool> _chunksBusy = [];

  int get currentBytes => _chunks.fold(0, (previousValue, element) => previousValue + element.downloadedBytes);

  bool _isolatesReady = false;
  final List<MainIsolateManager> _isolates = [];

  int get activeIsolateCount => _isolates.where((i) => i.ready).length;

  final Lock _statusChangeLock = Lock();

  DownloadProgressCallback? _onProgress;
  ValueCallback<int>? onReceiveBytes;
  VoidCallback? _onDone;
  ValueCallback<JDownloadException>? _onError;

  final JDownloadLogOutput _logOutput = JDownloadLogOutput();
  late final Logger _logger = Logger(output: _logOutput);

  static const int _preservedMetadataHeaderSize = 1024 * 16;

  static const String _copySuffix = '.jdcopy';

  DownloadManager({
    required this.url,
    required this.downloadPath,
    required this.savePath,
    required int isolateCount,
    required Duration connectionTimeout,
    required Duration receiveTimeout,
  }) : _isolateCount = isolateCount {
    _dio = Dio(BaseOptions(
      connectTimeout: connectionTimeout,
      receiveTimeout: receiveTimeout,
      headers: {HttpHeaders.acceptEncodingHeader: 'identity'},
    ));
    (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient =
        () => createProxyHttpClient()..findProxy = ProxyConfig.toFindProxy(proxyConfig);
  }

  void tryRecoverFromMetadata(bool deleteWhenUrlMismatch) {
    File downloadFile = File(downloadPath);
    if (!downloadFile.existsSync()) {
      return;
    }

    try {
      final raf = downloadFile.openSync(mode: FileMode.read);
      late DownloadProgress progress;
      try {
        progress = DownloadProgress.fromBuffer(raf.readSync(_preservedMetadataHeaderSize));
      } finally {
        raf.closeSync();
      }
      if (progress.url != url && deleteWhenUrlMismatch) {
        downloadFile.deleteSyncIgnoreError();
        return;
      }
      if (progress.totalBytes <= 0 ||
          progress.chunks.isEmpty ||
          progress.chunks.any((c) => c.size <= 0 || c.downloadedBytes < 0 || c.downloadedBytes > c.size) ||
          progress.chunks.fold<int>(0, (sum, c) => sum + c.size) != progress.totalBytes ||
          downloadFile.lengthSync() != _preservedMetadataHeaderSize + progress.totalBytes) {
        throw const FormatException('Invalid download metadata');
      }
      totalBytes = progress.totalBytes;
      _useRange = progress.useRange;
      _chunks = progress.chunks;
      _chunksBusy = List.generate(_chunks.length, (_) => false);
      _chunksReady = true;
    } catch (_) {
      downloadFile.deleteSyncIgnoreError();
    }
  }

  Future<void> start() {
    return _statusChangeLock.lock(() async {
      _running = true;
      await _initTrunks();

      // A full-response download cannot resume by appending bytes.
      if (!_useRange) {
        _chunks = [DownloadTrunk(size: totalBytes)];
        _chunksBusy = [false];
        if (_fileReady) {
          await _storeCurrentDownloadProgress();
        }
      }

      await _preCreateDownloadFile();

      await _startIsolates();

      await _tryHandleTrunks();
    });
  }

  Future<void> pause() {
    _running = false;
    return _statusChangeLock.lock(() async {
      await _killIsolates();
      if (_fileReady) {
        await _storeCurrentDownloadProgress();
      }
    });
  }

  Future<void> dispose() async {
    _running = false;
    return _statusChangeLock.lock(() async {
      await _killIsolates();

      if (_fileReady) {
        await _fileManager.close();
        _fileReady = false;
      }

      File downloadFile = File(downloadPath);
      if (await downloadFile.exists()) {
        await downloadFile.delete();
      }

      _chunks.clear();
      _chunksBusy.clear();
      _chunksReady = false;

      unRegisterOnProgress();
      unRegisterOnDone();
      unRegisterOnError();
      unRegisterOnLog();
      _dio.close(force: true);
    });
  }

  Future<void> changeIsolateCount(int count) async {
    if (_isolateCount == count) {
      return;
    }

    bool wasRunning = _isolatesReady;

    await _statusChangeLock.lock(() async {
      await _killIsolates();

      _isolateCount = count;

      /// add chunk if uncompleted chunk is less than isolate count
      if (_useRange && _chunksReady && _chunks.where((c) => !c.completed).length < _isolateCount && !_chunks.every((chunk) => chunk.completed)) {
        List<DownloadTrunk> newChunks = [];

        for (int i = 0; i < _chunks.length; i++) {
          if (_chunks[i].downloadedBytes != 0) {
            newChunks.add(DownloadTrunk(size: _chunks[i].downloadedBytes, downloadedBytes: _chunks[i].downloadedBytes));
          }
          if (_chunks[i].downloadedBytes != _chunks[i].size) {
            newChunks.add(DownloadTrunk(size: _chunks[i].size - _chunks[i].downloadedBytes));
          }
        }

        while (newChunks.where((c) => !c.completed).length < _isolateCount) {
          int largestUnCompletedChunkIndex = -1;
          int largestUnCompletedChunkSize = 0;
          for (int i = 0; i < newChunks.length; i++) {
            if (newChunks[i].completed) {
              continue;
            }
            if (newChunks[i].size > largestUnCompletedChunkSize) {
              largestUnCompletedChunkIndex = i;
              largestUnCompletedChunkSize = newChunks[i].size;
            }
          }

          if (largestUnCompletedChunkIndex == -1 || largestUnCompletedChunkSize <= 1) {
            break;
          }

          newChunks[largestUnCompletedChunkIndex] = DownloadTrunk(size: largestUnCompletedChunkSize ~/ 2);
          newChunks.insert(largestUnCompletedChunkIndex + 1, DownloadTrunk(size: largestUnCompletedChunkSize - largestUnCompletedChunkSize ~/ 2));
        }

        _chunks = newChunks;
        _chunksBusy = List.generate(_chunks.length, (_) => false);

        if (_fileReady) {
          await _storeCurrentDownloadProgress();
        }
      }
    });

    if (wasRunning) {
      return start();
    }
  }

  Future<void> changeConnectionTimeout(Duration duration) async {
    _dio.options = _dio.options.copyWith(connectTimeout: duration);
  }

  Future<void> changeReceiveTimeout(Duration duration) async {
    _dio.options = _dio.options.copyWith(receiveTimeout: duration);
  }

  void registerOnProgress(DownloadProgressCallback callback) {
    _onProgress = callback;
  }

  void unRegisterOnProgress() {
    _onProgress = null;
  }

  void registerOnDone(VoidCallback callback) {
    _onDone = callback;
  }

  void unRegisterOnDone() {
    _onDone = null;
  }

  void registerOnError(ValueCallback callback) {
    _onError = callback;
  }

  void unRegisterOnError() {
    _onError = null;
  }

  void registerOnLog(JDownloadLogCallback callback) {
    _logOutput.registerCallBack(callback);
  }

  void unRegisterOnLog() {
    _logOutput.unregisterCallBack();
  }

  Future<void> _initTrunks() async {
    if (_chunksReady) {
      return;
    }

    Response response;

    try {
      response = await retry(
        () => _dio.head(url),
        maxAttempts: 3,
        retryIf: (e) =>
            e is DioException &&
            (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.sendTimeout || e.type == DioExceptionType.receiveTimeout),
      );
    } on DioException catch (e) {
      throw JDownloadException(JDownloadExceptionType.fetchContentLengthFailed, error: e);
    }

    int? contentLength = int.tryParse(response.headers.value(HttpHeaders.contentLengthHeader) ?? '');
    if (contentLength == null) {
      throw JDownloadException(JDownloadExceptionType.noContentLengthHeaderFound);
    }

    if (contentLength <= 0) {
      throw JDownloadException(JDownloadExceptionType.noContentLengthHeaderFound);
    }
    totalBytes = contentLength;
    final chunkCount = min(_isolateCount, contentLength);

    _chunks = List.generate(
      chunkCount,
      (index) => DownloadTrunk(
        size: index != chunkCount - 1 ? contentLength ~/ chunkCount : contentLength - (chunkCount - 1) * (contentLength ~/ chunkCount),
      ),
    );
    _chunksBusy = List.generate(_chunks.length, (_) => false);

    _chunksReady = true;
  }

  Future<void> _startIsolates() async {
    if (_isolatesReady) {
      return;
    }

    _isolates.clear();

    try {
      List<Completer<void>> readyCompleters = List.generate(
        min(_useRange ? _isolateCount : 1, _chunks.where((c) => !c.completed).length),
        (_) => Completer<void>(),
      );
      for (int i = 0; i < readyCompleters.length; i++) {
        MainIsolateManager isolateManager = MainIsolateManager(proxyConfig: proxyConfig, logger: _logger)
          ..registerOnReady(readyCompleters[i].complete);
        _isolates.add(isolateManager);
        isolateManager.initIsolate().catchError(readyCompleters[i].completeError);
      }

      await Future.wait(readyCompleters.map((e) => e.future));
    } on Exception catch (e) {
      await _killIsolates();
      _isolates.clear();
      throw JDownloadException(JDownloadExceptionType.startIsolateFailed, error: e);
    }

    for (MainIsolateManager isolate in _isolates) {
      isolate.unRegisterOnReady();
    }

    _isolatesReady = true;
  }

  Future<void> _tryHandleTrunks() async {
    if (_chunks.every((chunk) => chunk.completed)) {
      // Progress can reach 100% before workers finish validating their streams.
      if (_chunksBusy.any((busy) => busy) || _completing) {
        return;
      }
      _completing = true;
      _statusChangeLock.lock(() async {
        if (!_running) {
          _completing = false;
          return;
        }
        await _completeDownloadFile();
      });
      return;
    }

    nextIsolate:
    for (MainIsolateManager isolate in _isolates) {
      if (!isolate.free) {
        continue;
      }

      for (int i = 0; i < _chunks.length; i++) {
        if (_chunks[i].completed) {
          continue;
        }
        if (_chunksBusy[i]) {
          continue;
        }
        isolate
          ..registerOnProgress((value) {
            onReceiveBytes?.call(value);
            _handleChunkDownloadProgress(isolate, i, value);
          })
          ..registerOnDone(() {
            _handleChunkDownloadComplete(isolate, i);
          })
          ..registerOnError((JDownloadException error) {
            _handleChunkDownloadError(isolate, i, error);
          });

        _chunksBusy[i] = true;

        isolate.beginDownload(
          url,
          downloadPath,
          _computeChunkDownloadRange(_chunks, i),
          _computeFileWriteOffset(_chunks, i),
          useRange: _useRange,
          totalBytes: totalBytes,
        );

        continue nextIsolate;
      }

      isolate.killIsolate();
    }
  }

  Future<void> _preCreateDownloadFile() async {
    if (_fileReady) {
      return;
    }

    try {
      File downloadFile = File(downloadPath);
      if (!await downloadFile.exists()) {
        await downloadFile.create(recursive: true);
      }

      _fileManager = FileManager(path: downloadPath, logger: _logger);

      await _storeCurrentDownloadProgress();

      await _fileManager.truncate(_preservedMetadataHeaderSize + totalBytes);

      _fileReady = true;
    } on Exception catch (e) {
      throw JDownloadException(JDownloadExceptionType.preCreateDownloadFileFailed, error: e);
    }
  }

  int _computeFileWriteOffset(List<DownloadTrunk> chunks, int i) {
    int offset = 0;
    for (int j = 0; j < i; j++) {
      offset += chunks[j].size;
    }

    return _preservedMetadataHeaderSize + offset + chunks[i].downloadedBytes;
  }

  ({int start, int end}) _computeChunkDownloadRange(List<DownloadTrunk> chunks, int i) {
    int start = 0;
    for (int j = 0; j < i; j++) {
      start += chunks[j].size;
    }

    int end = start + chunks[i].size;
    start = start + chunks[i].downloadedBytes;

    return (start: start, end: end);
  }

  Future<void> _killIsolates() async {
    List<Future> killFutures = _isolates.map((e) => e.killIsolate()).toList();

    for (MainIsolateManager isolate in _isolates) {
      isolate.unRegisterOnProgress();
      isolate.unRegisterOnDone();
      isolate.unRegisterOnError();
    }

    // A worker must acknowledge EOF before a full chunk is trusted on resume.
    for (int i = 0; i < _chunks.length; i++) {
      if (_chunksBusy[i] && _chunks[i].completed) {
        _chunks[i].downloadedBytes = 0;
      }
    }
    _chunksBusy = List.generate(_chunks.length, (_) => false);
    _isolatesReady = false;

    await Future.wait(killFutures);

    _isolates.clear();
  }

  void _handleChunkDownloadProgress(MainIsolateManager isolate, int chunkIndex, int newDownloadedBytes) {
    _chunks[chunkIndex].downloadedBytes += newDownloadedBytes;

    _onProgress?.call(currentBytes, totalBytes);

    _storeCurrentDownloadProgress();
  }

  void _handleChunkDownloadComplete(MainIsolateManager isolate, int chunkIndex) {
    assert(_chunks[chunkIndex].completed);

    _logger.d('chunk $chunkIndex done, size:${_chunks[chunkIndex].size}, bytes:${_chunks[chunkIndex].downloadedBytes}');

    _chunksBusy[chunkIndex] = false;

    _tryHandleTrunks();
  }

  Future<void> _handleChunkDownloadError(MainIsolateManager isolate, int chunkIndex, JDownloadException error) async {
    if (_handlingError || !_running) {
      return;
    }
    _handlingError = true;
    try {
      await _statusChangeLock.lock(() async {
        await _killIsolates();
        if (!_running) {
          return;
        }
        if (_useRange && error.type == JDownloadExceptionType.serverNotSupport) {
          _logger.i('Server ignored Range; restarting with one connection.');
          _useRange = false;
          _chunks = [DownloadTrunk(size: totalBytes)];
          _chunksBusy = [false];
          await _storeCurrentDownloadProgress();
          await _startIsolates();
          await _tryHandleTrunks();
        } else {
          _running = false;
          _onError?.call(error);
        }
      });
    } catch (e) {
      _running = false;
      _onError?.call(JDownloadException(JDownloadExceptionType.downloadFailed, error: e));
    } finally {
      _handlingError = false;
    }
  }

  Future<void> _completeDownloadFile() async {
    assert(_chunks.every((chunk) => chunk.completed));

    File downloadFile = File(downloadPath);
    File saveFile = File(savePath + _copySuffix);
    IOSink? saveFileOutput;
    try {
      await _fileManager.close();

      await saveFile.create(recursive: true);

      Stream<List<int>> inputStream = downloadFile.openRead(_preservedMetadataHeaderSize);
      saveFileOutput = saveFile.openWrite();

      await inputStream.forEach(saveFileOutput.add);
      await saveFileOutput.flush();
      await saveFileOutput.close();

      _logger.d('complete download file');
      await saveFile.rename(savePath);
      await downloadFile.delete();
    } on Exception catch (e) {
      await saveFileOutput?.close();
      _onError?.call(JDownloadException(JDownloadExceptionType.completeDownloadFileFailed, error: e));
      return;
    } finally {
      await _killIsolates();
    }

    _fileReady = false;
    _running = false;
    _onDone?.call();
  }

  Future<void> _storeCurrentDownloadProgress() async {
    DownloadProgress progress = DownloadProgress(url: url, savePath: savePath, totalBytes: totalBytes, useRange: _useRange, chunks: _chunks);

    try {
      await _fileManager.writeFrom(progress.toBuffer, position: 0);
    } on Exception catch (_) {
      /// ignore error after download complete
    }
  }
}
