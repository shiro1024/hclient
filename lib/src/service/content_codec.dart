import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

const _codecAsset = 'package:jhentai/src/service/content_codec.dart';

/// The bytes to upload. Raw artifacts refer to the original input file and do
/// not own it. A temporary artifact belongs to the caller's staging slot.
class ContentCodecArtifact {
  final String path;
  final String codecProfile;
  final String rawHash;
  final int rawLength;
  final String objectHash;
  final int storedLength;
  final bool isTemporary;

  const ContentCodecArtifact({
    required this.path,
    required this.codecProfile,
    required this.rawHash,
    required this.rawLength,
    required this.objectHash,
    required this.storedLength,
    required this.isTemporary,
  });
}

class ContentCodecException implements Exception {
  final int status;
  const ContentCodecException(this.status);

  @override
  String toString() => 'Content codec failed (status $status)';
}

/// File conversions share one worker; display reads use a separate persistent
/// worker so encoding cannot hold up reading. Each worker executes one native
/// call at a time. Cancellation remains owned by the sync coordinator, which
/// lets an active conversion finish before releasing its input and staging slot.
class ContentCodec {
  static final ContentCodec _instance = ContentCodec._();
  factory ContentCodec() => _instance;
  ContentCodec._();

  static const rawProfile = 'raw';
  static const encodedProfile = 'hclient-pcf2-zstd-v1';
  static const profileDefinitions = <String, Map<String, Object>>{
    encodedProfile: {'format': 'pcf2+zstd', 'pcf2Version': 2},
  };

  static bool isEncodingCandidate(String? mime) =>
      mime == 'image/jpeg' || mime == 'image/png' || mime == 'image/gif';

  static bool supportsProfile(String profile) =>
      profile == rawProfile || profile == encodedProfile;

  final _conversions = _CodecChannel('content-codec');
  final _display = _CodecChannel('content-codec-display');
  bool _closing = false;

  Future<ContentCodecArtifact> encodeFile({
    required String inputPath,
    required String outputPath,
  }) => _request([0, inputPath, outputPath]);

  /// Restores to a new file and checks the decoded raw byte identity.
  /// A failed decode removes its partial output. The caller commits the
  /// completed file to its final location.
  Future<ContentCodecArtifact> decodeFile({
    required String inputPath,
    required String outputPath,
    required String codecProfile,
    required String expectedRawHash,
    required int expectedRawLength,
  }) {
    if (!supportsProfile(codecProfile)) {
      return Future.error(const ContentCodecException(4));
    }
    _validateHash(expectedRawHash);
    if (expectedRawLength < 0) {
      throw ArgumentError('Content lengths must be nonnegative');
    }
    return _request([
      1,
      inputPath,
      outputPath,
      codecProfile == rawProfile ? 0 : 1,
      expectedRawHash,
      expectedRawLength,
    ]);
  }

  /// Restores original image bytes without creating a disk cache. This request
  /// runs before pending batch conversions once the current native call ends.
  Future<Uint8List> decodeBytes({
    required String inputPath,
    required String codecProfile,
    required String expectedRawHash,
    required int expectedRawLength,
  }) async {
    if (!supportsProfile(codecProfile)) {
      throw const ContentCodecException(4);
    }
    _validateHash(expectedRawHash);
    if (expectedRawLength < 0) {
      throw ArgumentError('Content lengths must be nonnegative');
    }
    final transfer = await _request<TransferableTypedData>([
      2,
      inputPath,
      codecProfile == rawProfile ? 0 : 1,
      expectedRawHash,
      expectedRawLength,
    ], interactive: true);
    return transfer.materialize().asUint8List();
  }

  /// Returns independently displayable image bytes. Encoded PNGs use their
  /// WebP carrier; exports must keep using the original-byte decode methods.
  Future<Uint8List> decodeImageForDisplay({
    required String inputPath,
    required String codecProfile,
  }) async {
    if (!supportsProfile(codecProfile)) {
      throw const ContentCodecException(4);
    }
    final transfer = await _request<TransferableTypedData>([
      3,
      inputPath,
      codecProfile == rawProfile ? 0 : 1,
    ]);
    return transfer.materialize().asUint8List();
  }

  Future<T> _request<T>(List<Object> arguments, {bool interactive = false}) {
    if (_closing) {
      return Future.error(StateError('Content codec is closing'));
    }
    final paths = (arguments[0] as int) >= 2
        ? [arguments[1] as String]
        : arguments.skip(1).take(2).cast<String>();
    for (final path in paths) {
      if (path.isEmpty || path.contains('\u0000')) {
        return Future.error(ArgumentError('Invalid content file path'));
      }
    }
    final channel = arguments[0] == 3 ? _display : _conversions;
    return channel.request<T>(arguments, interactive: interactive);
  }

  /// Drains both channels and closes their workers. New operations are rejected
  /// until this completes; a subsequent operation starts a fresh worker.
  Future<void> close() async {
    if (_closing) {
      throw StateError('Content codec is already closing');
    }
    _closing = true;
    try {
      await Future.wait([_conversions.close(), _display.close()]);
    } finally {
      _closing = false;
    }
  }
}

class _CodecChannel {
  final String debugName;
  Future<SendPort>? _worker;
  final List<_CodecRequest> _interactive = [];
  final List<_CodecRequest> _batch = [];
  Future<void>? _draining;

  _CodecChannel(this.debugName);

  Future<T> request<T>(List<Object> arguments, {bool interactive = false}) {
    final request = _CodecRequest(arguments);
    (interactive ? _interactive : _batch).add(request);
    _draining ??= _drain();
    return request.result.future.then((value) => value as T);
  }

  Future<void> _drain() async {
    try {
      while (_interactive.isNotEmpty || _batch.isNotEmpty) {
        final request = (_interactive.isNotEmpty ? _interactive : _batch)
            .removeAt(0);
        final response = ReceivePort();
        try {
          final worker = await (_worker ??= _startWorker(debugName));
          worker.send([response.sendPort, request.arguments]);
          final result = await response.first as List<Object>;
          if (result.length == 1) {
            request.result.complete(result.first);
          } else {
            request.result.completeError(
              result.first,
              StackTrace.fromString(result[1] as String),
            );
          }
        } catch (error, stack) {
          request.result.completeError(error, stack);
        } finally {
          response.close();
        }
      }
    } finally {
      _draining = null;
    }
  }

  Future<void> close() async {
    await _draining;
    final pendingWorker = _worker;
    if (pendingWorker == null) {
      return;
    }
    final response = ReceivePort();
    try {
      (await pendingWorker).send([response.sendPort, null]);
      await response.first;
    } finally {
      response.close();
      _worker = null;
    }
  }
}

class _CodecRequest {
  final List<Object> arguments;
  final Completer<Object> result = Completer<Object>();
  _CodecRequest(this.arguments);
}

Future<SendPort> _startWorker(String debugName) async {
  final ready = ReceivePort();
  try {
    await Isolate.spawn(_codecWorker, ready.sendPort, debugName: debugName);
    return await ready.first as SendPort;
  } finally {
    ready.close();
  }
}

void _codecWorker(SendPort ready) {
  final requests = ReceivePort();
  ready.send(requests.sendPort);
  requests.listen((message) {
    final request = message as List<Object?>;
    final reply = request[0] as SendPort;
    if (request[1] == null) {
      requests.close();
      reply.send(true);
      return;
    }
    try {
      final arguments = request[1] as List<Object>;
      reply.send([
        switch (arguments[0]) {
          2 => _decodeBytes(arguments),
          3 => _decodeImageForDisplay(arguments),
          _ => _convert(arguments),
        },
      ]);
    } catch (error, stack) {
      reply.send([error, stack.toString()]);
    }
  });
}

void _validateHash(String hash) {
  if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(hash)) {
    throw ArgumentError('Content hashes must contain 64 hexadecimal digits');
  }
}

String _hex(Array<Uint8> value) => List.generate(
  32,
  (index) => value[index].toRadixString(16).padLeft(2, '0'),
).join();

Pointer<Uint8> _hashPointer(String hash, Arena arena) {
  final pointer = arena<Uint8>(32);
  for (var index = 0; index < 32; index++) {
    pointer[index] = int.parse(
      hash.substring(index * 2, index * 2 + 2),
      radix: 16,
    );
  }
  return pointer;
}

ContentCodecArtifact _convert(List<Object> request) => using((arena) {
  final decode = request[0] == 1;
  final inputPath = request[1] as String;
  final outputPath = request[2] as String;
  final input = inputPath.toNativeUtf8(allocator: arena).cast<Uint8>();
  final output = outputPath.toNativeUtf8(allocator: arena).cast<Uint8>();
  final result = arena<_NativeResult>();
  final status = decode
      ? _nativeDecode(
          input,
          utf8.encode(inputPath).length,
          output,
          utf8.encode(outputPath).length,
          request[3] as int,
          request[5] as int,
          _hashPointer(request[4] as String, arena),
          result,
        )
      : _nativeEncode(
          input,
          utf8.encode(inputPath).length,
          output,
          utf8.encode(outputPath).length,
          result,
        );
  if (status != 0) {
    throw ContentCodecException(status);
  }
  final value = result.ref;
  return ContentCodecArtifact(
    path: decode || value.codec == 1 ? outputPath : inputPath,
    codecProfile: value.codec == 0
        ? ContentCodec.rawProfile
        : ContentCodec.encodedProfile,
    rawHash: _hex(value.rawHash),
    rawLength: value.rawLength,
    objectHash: _hex(value.objectHash),
    storedLength: value.storedLength,
    isTemporary: decode || value.codec == 1,
  );
});

TransferableTypedData _decodeBytes(List<Object> request) => using((arena) {
  final inputPath = request[1] as String;
  final length = request[4] as int;
  final output = arena<Uint8>(length == 0 ? 1 : length);
  final result = arena<_NativeResult>();
  final status = _nativeDecodeBytes(
    inputPath.toNativeUtf8(allocator: arena).cast<Uint8>(),
    utf8.encode(inputPath).length,
    request[2] as int,
    length,
    _hashPointer(request[3] as String, arena),
    output,
    length,
    result,
  );
  if (status != 0) throw ContentCodecException(status);
  return TransferableTypedData.fromList([output.asTypedList(length)]);
});

TransferableTypedData _decodeImageForDisplay(List<Object> request) => using((
  arena,
) {
  final inputPath = request[1] as String;
  final output = arena<_NativeBuffer>();
  try {
    final status = _nativeDecodeImageForDisplay(
      inputPath.toNativeUtf8(allocator: arena).cast<Uint8>(),
      utf8.encode(inputPath).length,
      request[2] as int,
      output,
    );
    if (status != 0) throw ContentCodecException(status);
    // fromList copies into independently owned transferable memory before the
    // Rust Box slice is freed. The receiving isolate materializes that copy.
    return TransferableTypedData.fromList([
      output.ref.data.asTypedList(output.ref.length),
    ]);
  } finally {
    _nativeFreeBuffer(output.ref.data, output.ref.length);
  }
});

final class _NativeBuffer extends Struct {
  external Pointer<Uint8> data;
  @UintPtr()
  external int length;
}

@Native<
  Int32 Function(Pointer<Uint8>, UintPtr, Uint32, Pointer<_NativeBuffer>)
>(assetId: _codecAsset, symbol: 'hclient_codec_decode_image_for_display')
external int _nativeDecodeImageForDisplay(
  Pointer<Uint8> input,
  int inputLength,
  int codec,
  Pointer<_NativeBuffer> output,
);

@Native<Void Function(Pointer<Uint8>, UintPtr)>(
  assetId: _codecAsset,
  symbol: 'hclient_codec_free_buffer',
)
external void _nativeFreeBuffer(Pointer<Uint8> data, int length);

final class _NativeResult extends Struct {
  @Uint32()
  external int codec;
  @Uint64()
  external int rawLength;
  @Uint64()
  external int storedLength;
  @Array(32)
  external Array<Uint8> rawHash;
  @Array(32)
  external Array<Uint8> objectHash;
}

@Native<
  Int32 Function(
    Pointer<Uint8>,
    UintPtr,
    Pointer<Uint8>,
    UintPtr,
    Pointer<_NativeResult>,
  )
>(assetId: _codecAsset, symbol: 'hclient_codec_encode')
external int _nativeEncode(
  Pointer<Uint8> input,
  int inputLength,
  Pointer<Uint8> output,
  int outputLength,
  Pointer<_NativeResult> result,
);

@Native<
  Int32 Function(
    Pointer<Uint8>,
    UintPtr,
    Pointer<Uint8>,
    UintPtr,
    Uint32,
    Uint64,
    Pointer<Uint8>,
    Pointer<_NativeResult>,
  )
>(assetId: _codecAsset, symbol: 'hclient_codec_decode')
external int _nativeDecode(
  Pointer<Uint8> input,
  int inputLength,
  Pointer<Uint8> output,
  int outputLength,
  int codec,
  int rawLength,
  Pointer<Uint8> rawHash,
  Pointer<_NativeResult> result,
);

@Native<
  Int32 Function(
    Pointer<Uint8>,
    UintPtr,
    Uint32,
    Uint64,
    Pointer<Uint8>,
    Pointer<Uint8>,
    UintPtr,
    Pointer<_NativeResult>,
  )
>(assetId: _codecAsset, symbol: 'hclient_codec_decode_bytes')
external int _nativeDecodeBytes(
  Pointer<Uint8> input,
  int inputLength,
  int codec,
  int rawLength,
  Pointer<Uint8> rawHash,
  Pointer<Uint8> output,
  int outputLength,
  Pointer<_NativeResult> result,
);
