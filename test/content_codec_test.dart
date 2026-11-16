import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/service/content_codec.dart';
import 'package:path/path.dart' as p;

void main() {
  final codec = ContentCodec();
  late Directory temporary;

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('content-codec-test-');
  });

  tearDown(() async {
    await codec.close();
    await temporary.delete(recursive: true);
  });

  for (final extension in ['webp', 'avif', 'gif']) {
    test('$extension remains raw and restores exactly', () async {
      final source = File(
        p.join('native', 'tests', 'fixtures', 'passthrough.$extension'),
      ).absolute;
      final bytes = await source.readAsBytes();
      final output = p.join(temporary.path, 'candidate');
      final artifact = await codec.encodeFile(
        inputPath: source.path,
        outputPath: output,
      );
      expect(artifact.codecProfile, ContentCodec.rawProfile);
      expect(artifact.path, source.path);
      expect(await File(output).exists(), isFalse);
      final restored = await codec.decodeFile(
        inputPath: artifact.path,
        outputPath: p.join(temporary.path, 'restored'),
        codecProfile: artifact.codecProfile,
        expectedRawHash: artifact.rawHash,
        expectedRawLength: artifact.rawLength,
      );
      expect(await File(restored.path).readAsBytes(), bytes);
      expect(
        await codec.decodeImageForDisplay(
          inputPath: artifact.path,
          codecProfile: artifact.codecProfile,
        ),
        bytes,
      );
      expect(
        await codec.decodeBytes(
          inputPath: artifact.path,
          codecProfile: artifact.codecProfile,
          expectedRawHash: artifact.rawHash,
          expectedRawLength: artifact.rawLength,
        ),
        bytes,
      );
    });
  }

  for (final extension in ['jpg', 'png', 'gif']) {
    test('encoded $extension fixture restores every original byte', () async {
      final source = File(
        p.join(
          'native',
          'tests',
          'fixtures',
          extension == 'gif' ? 'animated.gif' : 'gradient.$extension',
        ),
      ).absolute;
      final bytes = await source.readAsBytes();
      final artifact = await codec.encodeFile(
        inputPath: source.path,
        outputPath: p.join(temporary.path, 'candidate'),
      );
      expect(artifact.codecProfile, ContentCodec.encodedProfile);
      expect(artifact.storedLength, lessThan(artifact.rawLength));
      final display = await codec.decodeImageForDisplay(
        inputPath: artifact.path,
        codecProfile: artifact.codecProfile,
      );
      if (extension == 'png') {
        expect(String.fromCharCodes(display.sublist(8, 12)), 'WEBP');
        expect(display, isNot(bytes));
        Future<Uint8List> pixels(Uint8List encoded) async {
          final decoder = await ui.instantiateImageCodec(encoded);
          try {
            final frame = await decoder.getNextFrame();
            try {
              return (await frame.image.toByteData())!.buffer.asUint8List();
            } finally {
              frame.image.dispose();
            }
          } finally {
            decoder.dispose();
          }
        }

        expect(await pixels(display), await pixels(bytes));
      } else {
        expect(display, bytes);
      }
      if (extension == 'gif') {
        final animation = await ui.instantiateImageCodec(display);
        expect(animation.frameCount, 3);
        animation.dispose();
      }
      expect(artifact.isTemporary, isTrue);
      expect(await File(artifact.path).length(), artifact.storedLength);
      expect(artifact.rawHash, sha256.convert(bytes).toString());
      expect(
        artifact.objectHash,
        sha256.convert(await File(artifact.path).readAsBytes()).toString(),
      );
      final restored = await codec.decodeFile(
        inputPath: artifact.path,
        outputPath: p.join(temporary.path, 'restored'),
        codecProfile: artifact.codecProfile,
        expectedRawHash: artifact.rawHash,
        expectedRawLength: artifact.rawLength,
      );
      expect(await File(restored.path).readAsBytes(), bytes);
      expect(
        await codec.decodeBytes(
          inputPath: artifact.path,
          codecProfile: artifact.codecProfile,
          expectedRawHash: artifact.rawHash,
          expectedRawLength: artifact.rawLength,
        ),
        bytes,
      );
      expect(restored.codecProfile, ContentCodec.rawProfile);
    });
  }

  for (final extension in ['jpg', 'png']) {
    test(
      'real $extension fixture has exact raw identity and restoration',
      () async {
        final source = File(
          p.join('native', 'tests', 'fixtures', 'minimal.$extension'),
        ).absolute;
        final bytes = await source.readAsBytes();
        final output = p.join(temporary.path, 'candidate');
        final artifact = await codec.encodeFile(
          inputPath: source.path,
          outputPath: output,
        );
        expect(artifact.rawLength, bytes.length);
        expect(artifact.rawHash, sha256.convert(bytes).toString());
        expect(artifact.codecProfile, ContentCodec.rawProfile);
        expect(artifact.path, source.path);
        expect(artifact.isTemporary, isFalse);
        expect(await File(output).exists(), isFalse);
        final restored = await codec.decodeFile(
          inputPath: artifact.path,
          outputPath: p.join(temporary.path, '恢复.$extension'),
          codecProfile: artifact.codecProfile,
          expectedRawHash: artifact.rawHash,
          expectedRawLength: artifact.rawLength,
        );
        expect(await File(restored.path).readAsBytes(), bytes);
        expect(
          await codec.decodeBytes(
            inputPath: artifact.path,
            codecProfile: artifact.codecProfile,
            expectedRawHash: artifact.rawHash,
            expectedRawLength: artifact.rawLength,
          ),
          bytes,
        );
        expect(restored.rawHash, artifact.rawHash);
      },
    );
  }

  test(
    'original byte reads keep priority over queued batch conversions',
    () async {
      final source = File(p.join('native', 'tests', 'fixtures', 'minimal.jpg'))
          .absolute;
      final bytes = await source.readAsBytes();
      final order = <String>[];
      final batch = List.generate(
        3,
        (index) => codec
            .encodeFile(
              inputPath: source.path,
              outputPath: p.join(temporary.path, 'batch-$index'),
            )
            .then((_) => order.add('batch-$index')),
      );
      final read = codec
          .decodeBytes(
            inputPath: source.path,
            codecProfile: ContentCodec.rawProfile,
            expectedRawHash: sha256.convert(bytes).toString(),
            expectedRawLength: bytes.length,
          )
          .then((value) {
            expect(value, bytes);
            order.add('read');
          });
      await Future.wait([...batch, read]);
      expect(order, ['batch-0', 'read', 'batch-1', 'batch-2']);
    },
  );

  test('display finishes while a conversion is still executing', () async {
    final random = math.Random(7);
    const width = 512;
    final pixels = Uint8List(width * width * 4);
    for (var index = 0; index < pixels.length; index += 4) {
      pixels[index] = random.nextInt(256);
      pixels[index + 1] = random.nextInt(256);
      pixels[index + 2] = random.nextInt(256);
      pixels[index + 3] = 255;
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(pixels);
    final descriptor = ui.ImageDescriptor.raw(
      buffer,
      width: width,
      height: width,
      pixelFormat: ui.PixelFormat.rgba8888,
    );
    final imageCodec = await descriptor.instantiateCodec();
    final frame = await imageCodec.getNextFrame();
    final png = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    final source = File(p.join(temporary.path, 'busy.png'));
    await source.writeAsBytes(png!.buffer.asUint8List());
    frame.image.dispose();
    imageCodec.dispose();
    descriptor.dispose();
    buffer.dispose();
    var conversionFinished = false;
    final conversion = codec
        .encodeFile(
          inputPath: source.path,
          outputPath: p.join(temporary.path, 'busy.pcf'),
        )
        .then((value) {
          conversionFinished = true;
          return value;
        });
    final displaySource = File(
      p.join('native', 'tests', 'fixtures', 'passthrough.webp'),
    ).absolute;
    try {
      final display = await codec.decodeImageForDisplay(
        inputPath: displaySource.path,
        codecProfile: ContentCodec.rawProfile,
      );
      expect(conversionFinished, isFalse);
      expect(display, await displaySource.readAsBytes());
    } finally {
      await conversion;
    }
  });

  test(
    'failed display read releases its buffer and the worker remains usable',
    () async {
      final corrupt = File(p.join(temporary.path, 'corrupt.pcf'));
      await corrupt.writeAsString('invalid zstd');
      await expectLater(
        codec.decodeImageForDisplay(
          inputPath: corrupt.path,
          codecProfile: ContentCodec.encodedProfile,
        ),
        throwsA(
          isA<ContentCodecException>().having(
            (error) => error.status,
            'status',
            3,
          ),
        ),
      );
      final source = File(
        p.join('native', 'tests', 'fixtures', 'passthrough.webp'),
      ).absolute;
      expect(
        await codec.decodeImageForDisplay(
          inputPath: source.path,
          codecProfile: ContentCodec.rawProfile,
        ),
        await source.readAsBytes(),
      );
    },
  );

  test('byte decode validates identity before delivering data', () async {
    final source = File(p.join('native', 'tests', 'fixtures', 'minimal.png'))
        .absolute;
    await expectLater(
      codec.decodeBytes(
        inputPath: source.path,
        codecProfile: ContentCodec.rawProfile,
        expectedRawHash: List.filled(64, '0').join(),
        expectedRawLength: await source.length(),
      ),
      throwsA(
        isA<ContentCodecException>().having(
          (error) => error.status,
          'status',
          3,
        ),
      ),
    );
  });

  test('bad identity deletes only newly created output', () async {
    final source = File(p.join('native', 'tests', 'fixtures', 'minimal.png'))
        .absolute;
    final length = await source.length();
    final output = p.join(temporary.path, 'restored.png');
    final badHash = List.filled(64, '0').join();
    Future<ContentCodecArtifact> decode() => codec.decodeFile(
      inputPath: source.path,
      outputPath: output,
      codecProfile: ContentCodec.rawProfile,
      expectedRawHash: badHash,
      expectedRawLength: length,
    );
    await expectLater(
      decode(),
      throwsA(
        isA<ContentCodecException>().having(
          (error) => error.status,
          'status',
          3,
        ),
      ),
    );
    expect(await File(output).exists(), isFalse);
    final existing = await source.readAsBytes();
    await File(output).writeAsBytes(existing);
    await expectLater(
      decode(),
      throwsA(
        isA<ContentCodecException>().having(
          (error) => error.status,
          'status',
          2,
        ),
      ),
    );
    expect(await File(output).readAsBytes(), existing);
  });

  test('FFI rejects invalid paths before entering native code', () async {
    await expectLater(
      codec.encodeFile(
        inputPath: 'invalid\u0000path',
        outputPath: p.join(temporary.path, 'candidate'),
      ),
      throwsArgumentError,
    );
  });

  test('close drains both channels and allows both to restart', () async {
    final source = File(p.join('native', 'tests', 'fixtures', 'minimal.jpg'))
        .absolute;
    final bytes = await source.readAsBytes();
    final conversions = List.generate(
      3,
      (index) => codec.encodeFile(
        inputPath: source.path,
        outputPath: p.join(temporary.path, '$index'),
      ),
    );
    final displays = List.generate(
      3,
      (_) => codec.decodeImageForDisplay(
        inputPath: source.path,
        codecProfile: ContentCodec.rawProfile,
      ),
    );
    final closing = codec.close();
    final rejectedClose = expectLater(codec.close(), throwsStateError);
    final rejectedConversion = expectLater(
      codec.encodeFile(
        inputPath: source.path,
        outputPath: p.join(temporary.path, 'rejected'),
      ),
      throwsStateError,
    );
    final rejectedDisplay = expectLater(
      codec.decodeImageForDisplay(
        inputPath: source.path,
        codecProfile: ContentCodec.rawProfile,
      ),
      throwsStateError,
    );
    await Future.wait([rejectedClose, rejectedConversion, rejectedDisplay]);
    await closing;
    final results = await Future.wait(conversions);
    expect(results.map((result) => result.rawHash).toSet(), hasLength(1));
    for (final display in await Future.wait(displays)) {
      expect(display, bytes);
    }
    final restarted = await codec.encodeFile(
      inputPath: source.path,
      outputPath: p.join(temporary.path, 'restart'),
    );
    expect(restarted.rawHash, results.first.rawHash);
    expect(
      await codec.decodeImageForDisplay(
        inputPath: source.path,
        codecProfile: ContentCodec.rawProfile,
      ),
      bytes,
    );
  });
}
