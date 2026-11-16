import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/service/archive_downloader/j_downloader.dart';
import 'package:jhentai/src/service/archive_downloader/src/model/download_chunk.dart';
import 'package:jhentai/src/service/archive_downloader/src/model/download_progress.dart';

void main() {
  late Directory directory;
  late HttpServer server;
  late Uint8List bytes;
  late List<String?> requests;
  late List<JDownloadTask> tasks;
  bool supportRange = true;
  bool invalidRange = false;
  bool truncate = false;
  int active = 0;
  int maxActive = 0;
  int fullActive = 0;
  int maxFullActive = 0;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('archive-downloader-test');
    bytes = Uint8List.fromList(List.generate(256 * 1024, (i) => (i * 31 + i ~/ 251) % 256));
    requests = [];
    tasks = [];
    supportRange = true;
    invalidRange = false;
    truncate = false;
    active = maxActive = fullActive = maxFullActive = 0;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final response = request.response;
      response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes'); // Deliberately misleading in fallback tests.
      if (request.method == 'HEAD') {
        response.contentLength = bytes.length;
        await response.close();
        return;
      }
      final range = request.headers.value(HttpHeaders.rangeHeader);
      requests.add(range);
      int start = 0;
      int end = bytes.length;
      if (range != null && supportRange) {
        final match = RegExp(r'^bytes=(\d+)-(\d+)$').firstMatch(range);
        if (match == null) {
          response.statusCode = HttpStatus.badRequest;
          await response.close();
          return;
        }
        start = int.parse(match[1]!);
        end = int.parse(match[2]!) + 1;
        response.statusCode = HttpStatus.partialContent;
        response.headers.set(HttpHeaders.contentRangeHeader, 'bytes ${invalidRange ? start + 1 : start}-${end - 1}/${bytes.length}');
      }
      if (!truncate) {
        response.contentLength = end - start;
      }
      final sendEnd = truncate ? start + (end - start) ~/ 2 : end;
      active++;
      if (active > maxActive) {
        maxActive = active;
      }
      if (range == null) {
        fullActive++;
        if (fullActive > maxFullActive) {
          maxFullActive = fullActive;
        }
      }
      try {
        for (int offset = start; offset < sendEnd; offset += 1024) {
          final limit = offset + 1024 < sendEnd ? offset + 1024 : sendEnd;
          response.add(bytes.sublist(offset, limit));
          await response.flush();
          await Future<void>.delayed(const Duration(milliseconds: 2));
        }
        await response.close();
      } catch (_) {
        // Expected when a probe, pause, or rejected response closes its socket.
      } finally {
        active--;
        if (range == null) {
          fullActive--;
        }
      }
    });
  });

  tearDown(() async {
    for (final task in tasks) {
      await task.dispose();
    }
    await server.close(force: true);
    await directory.delete(recursive: true);
  });

  JDownloadTask createTask(Completer<void> done, {void Function(int, int)? onProgress, void Function(int)? onReceiveBytes}) {
    final task = JDownloadTask.newTask(
      url: 'http://127.0.0.1:${server.port}/archive',
      savePath: '${directory.path}/archive.zip',
      isolateCount: 4,
      onProgress: onProgress,
      onReceiveBytes: onReceiveBytes,
      onDone: () {
        if (!done.isCompleted) {
          done.complete();
        }
      },
      onError: (error) {
        if (!done.isCompleted) {
          done.completeError(error);
        }
      },
    );
    tasks.add(task);
    return task;
  }

  Future<void> finish(JDownloadTask task, Completer<void> done) async {
    await task.start();
    await done.future.timeout(const Duration(seconds: 15));
    expect(task.status, TaskStatus.completed);
    expect(await File(task.savePath).readAsBytes(), bytes);
    expect(await File(task.downloadPath).exists(), isFalse);
  }

  test('uses standard byte ranges and downloads concurrently', () async {
    final done = Completer<void>();
    var received = 0;
    await finish(createTask(done, onReceiveBytes: (count) => received += count), done);
    expect(received, bytes.length);
    expect(requests.length, 4);
    expect(requests.every((r) => r != null && r.startsWith('bytes=')), isTrue);
    expect(maxActive, greaterThan(1));
  });

  test('pauses and resumes partial chunks without restarting them', () async {
    final done = Completer<void>();
    final progressed = Completer<void>();
    final task = createTask(
      done,
      onProgress: (current, _) {
        if (current >= 16 * 1024 && !progressed.isCompleted) {
          progressed.complete();
        }
      },
    );
    await task.start();
    await progressed.future.timeout(const Duration(seconds: 10));
    await task.pause();
    final savedBytes = task.currentBytes;
    final requestCount = requests.length;
    expect(savedBytes, greaterThan(0));
    await finish(task, done);
    final resumedStarts = requests.skip(requestCount).map((r) => int.parse(r!.substring(6).split('-').first));
    expect(resumedStarts.any((start) => start % (bytes.length ~/ 4) != 0), isTrue);
  });

  test('ignoring Range falls back to a single full GET', () async {
    supportRange = false;
    final done = Completer<void>();
    await finish(createTask(done), done);
    expect(requests.where((r) => r == null).length, 1);
    expect(maxFullActive, 1);
  });

  test('restores ranged progress from legacy metadata without a mode flag', () async {
    final progressed = Completer<void>();
    final first = createTask(Completer<void>(), onProgress: (current, _) {
      if (current >= 16 * 1024 && !progressed.isCompleted) {
        progressed.complete();
      }
    });
    await first.start();
    await progressed.future.timeout(const Duration(seconds: 10));
    await first.pause();
    final savedBytes = first.currentBytes;
    final raf = await File(first.downloadPath).open(mode: FileMode.writeOnlyAppend);
    final contents = await File(first.downloadPath).openRead(0, 16384).fold<List<int>>([], (all, data) => all..addAll(data));
    final legacy = DownloadProgress.fromBuffer(Uint8List.fromList(contents)).toJson()..remove('useRange');
    final payload = utf8.encode(jsonEncode(legacy));
    await raf.setPosition(0);
    await raf.writeFrom([payload.length & 0xff, payload.length >> 8, ...payload]);
    await raf.close();
    final count = requests.length;
    final done = Completer<void>();
    final recovered = createTask(done);
    expect(recovered.currentBytes, savedBytes);
    await finish(recovered, done);
    expect(requests.skip(count).every((r) => r != null), isTrue);
  });

  test('fallback restarts from zero after pause and metadata recovery', () async {
    supportRange = false;
    final firstDone = Completer<void>();
    final progressed = Completer<void>();
    final task = createTask(
      firstDone,
      onProgress: (current, _) {
        if (current >= 16 * 1024 && !progressed.isCompleted) {
          progressed.complete();
        }
      },
    );
    await task.start();
    await progressed.future.timeout(const Duration(seconds: 10));
    await task.pause();
    final count = requests.length;
    final done = Completer<void>();
    final recovered = createTask(done);
    expect(recovered.currentBytes, greaterThan(0));
    await finish(recovered, done);
    expect(requests.skip(count).toList(), [null]);
  });

  test('existing ranged progress is discarded when server stops supporting Range', () async {
    final done = Completer<void>();
    final task = createTask(done);
    final metadata = DownloadProgress(
      url: task.url,
      savePath: task.savePath,
      totalBytes: bytes.length,
      chunks: [
        DownloadTrunk(size: bytes.length ~/ 2, downloadedBytes: 1024),
        DownloadTrunk(size: bytes.length ~/ 2),
      ],
    );
    final file = await File(task.downloadPath).open(mode: FileMode.write);
    await file.writeFrom(metadata.toBuffer);
    await file.truncate(16384 + bytes.length);
    await file.close();
    supportRange = false;
    final recovered = createTask(done);
    expect(recovered.currentBytes, 1024);
    await finish(recovered, done);
    expect(requests.where((r) => r == null).length, 1);
  });

  test('rejects a mismatched Content-Range without publishing corrupt output', () async {
    invalidRange = true;
    final done = Completer<void>();
    final task = createTask(done);
    final failure = expectLater(done.future, throwsA(isA<JDownloadException>()));
    await task.start();
    await failure;
    expect(await File(task.savePath).exists(), isFalse);
    expect(requests.where((r) => r == null), isEmpty);
  });
  test('a truncated full response is never marked complete', () async {
    supportRange = false;
    truncate = true;
    final done = Completer<void>();
    final task = createTask(done);
    final failure = expectLater(done.future, throwsA(isA<JDownloadException>()));
    await task.start();
    await failure;
    expect(task.status, TaskStatus.failed);
    expect(await File(task.savePath).exists(), isFalse);
  });

  test('damaged metadata restarts safely', () async {
    final done = Completer<void>();
    final task = createTask(done);
    await File(task.downloadPath).writeAsBytes([1, 2, 3]);
    final recovered = createTask(done);
    expect(recovered.currentBytes, 0);
    await finish(recovered, done);
  });
}
