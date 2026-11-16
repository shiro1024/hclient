import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/l18n/locale_text.dart';
import 'package:jhentai/src/model/gallery_image.dart';
import 'package:jhentai/src/model/image_source_info.dart';
import 'package:jhentai/src/pages/read/read_image_info.dart';
import 'package:jhentai/src/service/content_codec.dart';
import 'package:jhentai/src/service/content_sync/content_repository.dart';
import 'package:jhentai/src/service/gallery_download/gallery_download_service.dart';
import 'package:jhentai/src/service/path_service.dart';
import 'package:jhentai/src/widget/eh_image.dart';

ContentPageRecord page({
  int raw = 1000,
  int? stored = 250,
  String? profile = ContentCodec.encodedProfile,
  int? width,
  int? height,
}) => ContentPageRecord(
  copyId: 'copy',
  ordinal: 0,
  relativePath: '001.pcf',
  rawHash: 'hash',
  rawLength: raw,
  mime: 'image/jpeg',
  width: width,
  height: height,
  state: 'resident',
  codecProfile: profile,
  storedLength: stored,
);

void main() {
  tearDown(() {
    imageCache.clear();
    imageCache.clearLiveImages();
    EHImageAnimationGateRegistry.clear();
    Get.reset();
  });

  Future<void> showInfo(
    WidgetTester tester,
    Future<ContentPageRecord?> metadata, {
    double width = 600,
    ImageSourceInfo? source,
    bool managed = false,
  }) async {
    await tester.pumpWidget(
      GetMaterialApp(
        locale: const Locale('en', 'US'),
        translations: LocaleText(),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: ReadingImageInfo(
                metadata: metadata,
                source: source,
                managed: managed,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('owner storage facts remain distinct from source image facts', (
    tester,
  ) async {
    await showInfo(
      tester,
      Future.value(page(width: 512, height: 512)),
      source: const ImageSourceInfo(
        encodedLength: 999,
        mime: 'image/png',
        width: 1200,
        height: 1800,
      ),
    );
    expect(
      find.text('JPEG · 1200 × 1800 · 1000.0B → 250.0B（−75.0%）'),
      findsOneWidget,
    );
    final text = tester.widget<Text>(find.textContaining('→'));
    expect(text.semanticsLabel, contains('Original 1000.0B → Disk 250.0B'));
    expect(find.textContaining('PCF'), findsNothing);
    expect(find.textContaining('Page'), findsNothing);
    await showInfo(tester, Future.value(page(raw: 1000, stored: 1100)));
    expect(find.textContaining('1000.0B → 1.07KB（+10.0%）'), findsOneWidget);
    await showInfo(tester, Future.value(page(raw: 1000, stored: 1000)));
    expect(find.textContaining('（0.0%）'), findsOneWidget);
    await showInfo(tester, Future.value(page(raw: 10000, stored: 9999)));
    expect(find.textContaining('（0.0%）'), findsOneWidget);
    expect(find.textContaining('−0.0%'), findsNothing);
    await showInfo(tester, Future.value(page(raw: 0, stored: 0)));
    expect(find.textContaining('%'), findsNothing);
    expect(find.textContaining('0.0B → 0.0B'), findsOneWidget);
    await showInfo(
      tester,
      Future.value(null),
      source: const ImageSourceInfo(encodedLength: 2048),
    );
    expect(find.text('2.00KB'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('2.00KB')).semanticsLabel,
      'Original 2.00KB',
    );
    await showInfo(tester, Future.value(page(raw: -1, stored: 250)));
    expect(find.text('JPEG · Disk 250.0B'), findsOneWidget);
    expect(find.textContaining('→'), findsNothing);
  });

  testWidgets('managed display bytes never become original format or size', (
    tester,
  ) async {
    final metadata = Completer<ContentPageRecord?>();
    await showInfo(
      tester,
      metadata.future,
      managed: true,
      source: const ImageSourceInfo(
        mime: 'image/webp',
        encodedLength: 100,
        width: 512,
        height: 512,
      ),
    );
    expect(find.text('512 × 512'), findsOneWidget);
    expect(find.textContaining('WEBP'), findsNothing);
    expect(find.textContaining('100.0B'), findsNothing);
    metadata.complete(
      ContentPageRecord(
        copyId: 'copy',
        ordinal: 0,
        relativePath: '001.png.pcf',
        rawHash: 'hash',
        rawLength: 1000,
        mime: 'image/png',
        width: null,
        height: null,
        state: 'completed',
        codecProfile: ContentCodec.encodedProfile,
        storedLength: 250,
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('PNG · 512 × 512 · 1000.0B → 250.0B（−75.0%）'),
      findsOneWidget,
    );
    expect(find.textContaining('WEBP'), findsNothing);
  });

  testWidgets('selected raw storage derives its unchanged resident size', (
    tester,
  ) async {
    await showInfo(
      tester,
      Future.value(
        page(raw: 13846398, stored: null, profile: ContentCodec.rawProfile),
      ),
    );
    expect(find.text('JPEG · 13.20MB → 13.20MB（0.0%）'), findsOneWidget);
    for (final profile in [null, ContentCodec.encodedProfile]) {
      await showInfo(
        tester,
        Future.value(page(stored: null, profile: profile)),
      );
      expect(find.text('JPEG · 1000.0B'), findsOneWidget);
      expect(find.textContaining('→'), findsNothing);
    }
    await showInfo(
      tester,
      Future.value(page(stored: 900, profile: ContentCodec.rawProfile)),
    );
    expect(find.textContaining('1000.0B → 900.0B（−10.0%）'), findsOneWidget);
    await showInfo(
      tester,
      Future.value(page(stored: -1, profile: ContentCodec.rawProfile)),
    );
    expect(find.textContaining('→'), findsNothing);
  });

  testWidgets('unknown source and page dimensions remain omitted', (
    tester,
  ) async {
    await showInfo(tester, Future.value(null));
    expect(
      find.descendant(
        of: find.byType(ReadingImageInfo),
        matching: find.byType(Text),
      ),
      findsNothing,
    );
    expect(find.textContaining('800 × 1200'), findsNothing);
    await showInfo(
      tester,
      Future.value(page()),
      source: const ImageSourceInfo(encodedLength: 999),
    );
    expect(find.textContaining('×'), findsNothing);
    expect(find.textContaining('1000.0B → 250.0B（−75.0%）'), findsOneWidget);
  });

  testWidgets('rapid page changes never show retained or late owner metadata', (
    tester,
  ) async {
    await showInfo(tester, Future.value(page()));
    expect(find.textContaining('1000.0B → 250.0B'), findsOneWidget);
    final second = Completer<ContentPageRecord?>();
    await showInfo(tester, second.future);
    expect(find.textContaining('→'), findsNothing);
    final third = Completer<ContentPageRecord?>();
    await showInfo(tester, third.future);
    second.complete(page(stored: 100));
    await tester.pump();
    expect(find.textContaining('→'), findsNothing);
    third.complete(page(stored: 800));
    await tester.pumpAndSettle();
    expect(find.textContaining('1000.0B → 800.0B（−20.0%）'), findsOneWidget);
    expect(find.textContaining('100.0B'), findsNothing);
  });

  testWidgets('image facts wrap within a narrow reader overlay', (
    tester,
  ) async {
    await showInfo(
      tester,
      Future.value(page()),
      width: 180,
      source: const ImageSourceInfo(
        encodedLength: 1000,
        width: 12000,
        height: 18000,
      ),
    );
    final text = find.textContaining('→');
    expect(tester.getSize(text).width, lessThanOrEqualTo(156));
    expect(tester.getSize(text).height, greaterThan(20));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'normal file decode records source size before downsampling and survives a hot cache hit',
    (tester) async {
      final previousDirectory = pathService.appDocDir;
      final temp = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('reading-source-info-'),
      ))!;
      pathService.appDocDir = temp;
      try {
        final bytes = (await tester.runAsync(() async {
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder);
          canvas.drawRect(
            const Rect.fromLTWH(0, 0, 80, 120),
            Paint()..color = Colors.blue,
          );
          final picture = recorder.endRecording();
          final sourceImage = await picture.toImage(80, 120);
          final data = await sourceImage.toByteData(
            format: ui.ImageByteFormat.png,
          );
          sourceImage.dispose();
          picture.dispose();
          final result = data!.buffer.asUint8List();
          await File('${temp.path}/image.png').writeAsBytes(result);
          return result;
        }))!;
        final image = GalleryImage(
          url: '',
          path: 'image.png',
          downloadStatus: DownloadStatus.downloaded,
        );
        ImageSourceInfo? facts;
        Size? decodedSize;
        Future<void> load({int? maxBytes, int instance = 0}) async {
          await tester.runAsync(() async {
            await tester.pumpWidget(
              MaterialApp(
                home: EHImage(
                  key: ValueKey(instance),
                  galleryImage: image,
                  maxBytes: maxBytes,
                  completedWidgetBuilder: (state) {
                    facts = EHImage.sourceInfoFor(state);
                    return null;
                  },
                ),
              ),
            );
            final provider = tester
                .widget<ExtendedImage>(find.byType(ExtendedImage))
                .image;
            final stream = provider.resolve(ImageConfiguration.empty);
            final loaded = Completer<void>();
            late ImageStreamListener listener;
            listener = ImageStreamListener(
              (info, _) {
                decodedSize = Size(
                  info.image.width.toDouble(),
                  info.image.height.toDouble(),
                );
                stream.removeListener(listener);
                loaded.complete();
              },
              onError: (Object error, StackTrace? stack) =>
                  loaded.completeError(error, stack),
            );
            stream.addListener(listener);
            await loaded.future;
          });
          await tester.pumpAndSettle();
        }

        await load();
        expect(decodedSize, const Size(80, 120));
        expect(
          facts,
          ImageSourceInfo(
            encodedLength: bytes.length,
            mime: 'image/png',
            width: 80,
            height: 120,
          ),
        );
        final ordinaryProvider = ExtendedFileImageProvider(
          File('${temp.path}/image.png'),
        );
        expect(
          (await ordinaryProvider.obtainCacheStatus(
            configuration: ImageConfiguration.empty,
          ))!.keepAlive,
          isTrue,
        );
        expect(await ordinaryProvider.evict(), isTrue);
        expect(
          (await ordinaryProvider.obtainCacheStatus(
            configuration: ImageConfiguration.empty,
          ))!.untracked,
          isTrue,
        );
        final limit = bytes.length ~/ 2;
        await load(maxBytes: limit, instance: 1);
        final pixels = 80 * 120 * limit ~/ bytes.length;
        final targetHeight = math.sqrt(pixels / (80 / 120)).floor();
        final targetWidth = (80 / 120 * targetHeight).floor();
        expect(
          decodedSize,
          Size(targetWidth.toDouble(), targetHeight.toDouble()),
        );
        expect(facts!.width, 80);
        expect(facts!.height, 120);
        await tester.runAsync(
          () => File('${temp.path}/image.png').delete(),
        ); // A hot image carries facts without another read.
        facts = null;
        await load(maxBytes: limit, instance: 2);
        expect(facts!.encodedLength, bytes.length);
        expect(facts!.width, 80);
        await tester.pumpWidget(const SizedBox());
      } finally {
        pathService.appDocDir = previousDirectory;
        await tester.runAsync(() => temp.delete(recursive: true));
      }
    },
  );
  testWidgets('animated and single-frame GIF paths retain source facts', (
    tester,
  ) async {
    final previousDirectory = pathService.appDocDir;
    pathService.appDocDir = Directory.current;
    final length = (await tester.runAsync(
      () => File('native/tests/fixtures/animated.gif').length(),
    ))!;
    try {
      for (final singleFrame in [false, true]) {
        final observed = <ImageSourceInfo>{};
        await tester.runAsync(() async {
          await tester.pumpWidget(
            MaterialApp(
              home: EHImage(
                key: ValueKey(singleFrame),
                galleryImage: GalleryImage(
                  url: '',
                  path: 'native/tests/fixtures/animated.gif',
                  downloadStatus: DownloadStatus.downloaded,
                ),
                disableAnimation: singleFrame,
                animateOnlyWhenVisible: !singleFrame,
                completedWidgetBuilder: (state) {
                  final info = EHImage.sourceInfoFor(state);
                  if (info != null) observed.add(info);
                  return null;
                },
              ),
            ),
          );
        });
        for (var attempt = 0; attempt < 50 && observed.isEmpty; attempt++) {
          // Animated completers emit their first frame through the scheduler.
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 1)),
          );
          await tester.pump(const Duration(milliseconds: 20));
        }
        for (var frame = 0; frame < 5; frame++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(observed, hasLength(1));
        expect(observed.single.mime, 'image/gif');
        expect(observed.single.encodedLength, length);
        expect(observed.single.width, greaterThan(0));
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      }
    } finally {
      pathService.appDocDir = previousDirectory;
    }
  });
}
