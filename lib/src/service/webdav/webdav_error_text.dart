import 'dart:async';
import 'dart:io';

import 'package:get/get.dart';

import '../content_codec.dart';
import 'webdav_client.dart';

class WebDavFailure {
  final String kind;
  final int? statusCode;

  const WebDavFailure(this.kind, {this.statusCode});

  factory WebDavFailure.fromError(Object error) {
    if (error is WebDavException) {
      return WebDavFailure(error.kind.name, statusCode: error.statusCode);
    }
    if (error is SocketException ||
        error is HandshakeException ||
        error is TimeoutException) {
      return const WebDavFailure('network');
    }
    if (error is FileSystemException) {
      return const WebDavFailure('localIo');
    }
    if (error is ContentCodecException) {
      return const WebDavFailure('codec');
    }
    if (error is FormatException) {
      return const WebDavFailure('invalidData');
    }
    return const WebDavFailure('unknown');
  }

  static WebDavFailure? fromJson(Object? value) {
    if (value is! Map || value['kind'] is! String) {
      return null;
    }
    return WebDavFailure(
      value['kind'] as String,
      statusCode: value['statusCode'] is int
          ? value['statusCode'] as int
          : null,
    );
  }

  Map<String, Object> toJson() => {
    'kind': kind,
    if (statusCode != null) 'statusCode': statusCode!,
  };
}

String webDavErrorText(Object error) =>
    webDavFailureText(WebDavFailure.fromError(error));

String webDavFailureText(WebDavFailure error) {
  final key = switch (error.kind) {
    'authentication' =>
      error.statusCode == 403
          ? 'webDavErrorPermission'
          : 'webDavErrorAuthentication',
    'missing' => 'webDavErrorMissing',
    'conflict' => 'webDavErrorConflict',
    'network' => 'webDavErrorNetwork',
    'server' => 'webDavErrorServer',
    'invalidResponse' => 'webDavErrorInvalidResponse',
    'localIo' => 'webDavErrorLocalIo',
    'codec' => 'webDavErrorCodec',
    'invalidData' => 'webDavErrorInvalidData',
    _ => 'webDavErrorUnknown',
  };
  final status = error.statusCode;
  return status == null ? key.tr : '${key.tr} (HTTP $status)';
}
