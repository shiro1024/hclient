import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:dio/dio.dart';
import 'package:flutter_socks_proxy/socks_proxy.dart';
import 'package:jhentai/src/service/archive_downloader/src/exception/j_download_exception.dart';
import 'package:jhentai/src/service/archive_downloader/src/model/main_isolate_message.dart';
import 'package:jhentai/src/service/archive_downloader/src/model/proxy_config.dart';
import 'package:jhentai/src/service/archive_downloader/src/model/sub_isolate_message.dart';
import 'package:logger/web.dart';

class SubIsolateManager {
  final ReceivePort _subReceivePort;
  final SendPort _mainSendPort;

  late final ProxyConfig? _proxyConfig;

  CancelToken? _cancelToken;

  SubIsolateManager({required SendPort mainSendPort})
      : _mainSendPort = mainSendPort,
        _subReceivePort = ReceivePort() {
    _mainSendPort.send(SubIsolateMessage(SubIsolateMessageType.created, _subReceivePort.sendPort));

    _subReceivePort.listen((message) {
      _mainSendPort.send(SubIsolateMessage(SubIsolateMessageType.log, LogEvent(Level.debug, 'received main message: $message')));

      switch (message.type) {
        case MainIsolateMessageType.init:
          message = message as MainIsolateMessage<ProxyConfig?>;
          _proxyConfig = message.data;
          SocksProxy.initProxy(findProxy: ProxyConfig.toFindProxy(_proxyConfig));
          _mainSendPort.send(SubIsolateMessage<void>(SubIsolateMessageType.inited, null));
          break;
        case MainIsolateMessageType.download:
          message = message as MainIsolateMessage<
              ({String url, String downloadPath, ({int start, int end}) downloadRange, int fileWriteOffset, bool useRange, int totalBytes})>;
          download(
            message.data.url,
            message.data.downloadPath,
            message.data.downloadRange,
            message.data.fileWriteOffset,
            message.data.useRange,
            message.data.totalBytes,
          );
          break;
        case MainIsolateMessageType.close:
          if (_cancelToken == null || _cancelToken!.isCancelled) {
            _mainSendPort.send(SubIsolateMessage<void>(SubIsolateMessageType.closeReady, null));
          } else {
            _cancelToken!.cancel();
          }
          break;
        default:
          break;
      }
    });
  }

  Future<void> download(
    String url,
    String downloadPath,
    ({int start, int end}) downloadRange,
    int fileWriteOffset,
    bool useRange,
    int totalBytes,
  ) async {
    final cancelToken = _cancelToken = CancelToken();
    final dio = Dio();
    RandomAccessFile? raf;
    JDownloadException? failure;
    _mainSendPort.send(SubIsolateMessage<void>(SubIsolateMessageType.begin, null));
    try {
      final response = await dio.get<ResponseBody>(
        url,
        options: Options(
          headers: {
            HttpHeaders.acceptEncodingHeader: 'identity',
            if (useRange) HttpHeaders.rangeHeader: 'bytes=${downloadRange.start}-${downloadRange.end - 1}',
          },
          responseType: ResponseType.stream,
        ),
        cancelToken: cancelToken,
      );
      final expectedLength = downloadRange.end - downloadRange.start;
      if (useRange) {
        if (response.statusCode == HttpStatus.ok) {
          throw JDownloadException(JDownloadExceptionType.serverNotSupport);
        }
        final expectedRange = 'bytes ${downloadRange.start}-${downloadRange.end - 1}/';
        final contentRange = response.headers.value(HttpHeaders.contentRangeHeader) ?? '';
        final total = int.tryParse(contentRange.split('/').last);
        if (response.statusCode != HttpStatus.partialContent || !contentRange.startsWith(expectedRange) || total == null || total != totalBytes) {
          throw JDownloadException(JDownloadExceptionType.receiveDataFailed, error: 'Invalid Content-Range: $contentRange');
        }
      } else if (response.statusCode != HttpStatus.ok) {
        throw JDownloadException(JDownloadExceptionType.receiveDataFailed, error: 'Expected a full response, got ${response.statusCode}');
      }
      final contentLength = int.tryParse(response.headers.value(HttpHeaders.contentLengthHeader) ?? '');
      if (contentLength != null && contentLength != expectedLength) {
        throw JDownloadException(
          JDownloadExceptionType.receiveDataFailed,
          error: 'Unexpected Content-Length: $contentLength, expected $expectedLength',
        );
      }

      raf = await File(downloadPath).open(mode: FileMode.writeOnlyAppend);
      await raf.setPosition(fileWriteOffset);
      int received = 0;
      await for (final data in response.data!.stream) {
        if (cancelToken.isCancelled) {
          throw cancelToken.cancelError!;
        }
        if (received + data.length > expectedLength) {
          throw JDownloadException(JDownloadExceptionType.receiveDataFailed, error: 'Response exceeded requested length');
        }
        await raf.writeFrom(data);
        received += data.length;
        _mainSendPort.send(SubIsolateMessage<int>(SubIsolateMessageType.progress, data.length));
      }
      if (cancelToken.isCancelled) {
        throw cancelToken.cancelError!;
      }
      if (received != expectedLength) {
        throw JDownloadException(JDownloadExceptionType.receiveDataFailed, error: 'Truncated response: $received of $expectedLength bytes');
      }
    } on JDownloadException catch (e) {
      failure = e;
    } on DioException catch (e) {
      // Streams and cancellation futures cannot be sent across isolate ports.
      e.response?.data = null;
      e.requestOptions.cancelToken = null;
      if (!cancelToken.isCancelled) {
        failure = JDownloadException(JDownloadExceptionType.downloadFailed, error: e);
      }
    } catch (e) {
      failure = JDownloadException(JDownloadExceptionType.receiveDataFailed, error: e.toString());
    } finally {
      dio.close(force: true);
      try {
        await raf?.close();
      } catch (e) {
        failure ??= JDownloadException(JDownloadExceptionType.writeDownloadFileFailed, error: e.toString());
      }
      _cancelToken = null;
    }
    if (cancelToken.isCancelled) {
      _mainSendPort.send(SubIsolateMessage<void>(SubIsolateMessageType.closeReady, null));
    } else if (failure != null) {
      _mainSendPort.send(SubIsolateMessage<JDownloadException>(SubIsolateMessageType.error, failure));
    } else {
      _mainSendPort.send(SubIsolateMessage<void>(SubIsolateMessageType.done, null));
    }
  }
}

void subIsolateEntryPoint(SendPort mainSendPort) {
  SubIsolateManager(mainSendPort: mainSendPort);
}
