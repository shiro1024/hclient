import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/model/gallery_image.dart';
import 'package:jhentai/src/pages/read/read_page_logic.dart';
import 'package:jhentai/src/pages/read/layout/base/base_layout_logic.dart';
import 'package:jhentai/src/setting/download_setting.dart';
import 'package:jhentai/src/service/content_sync/content_repository.dart';
import 'package:jhentai/src/service/content_codec.dart';
import 'package:jhentai/src/service/gallery_download/gallery_download_service.dart';
import 'package:jhentai/src/service/local_content_service.dart';
import 'package:jhentai/src/service/log.dart';
import 'package:jhentai/src/service/path_service.dart';
import 'package:jhentai/src/widget/eh_image.dart';

import 'support/test_log_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  late AppDb db;
  late LocalContentService previousOwner;
  late LogService previousLog;
  late Directory? previousAppDocDir;
  late GalleryImage image;
  late DownloadSetting previousDownloadSetting;
  late String copyId;

  final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg==',
  );

  setUp(() async {
    previousOwner = localContentService;
    previousLog = log;
    previousDownloadSetting = downloadSetting;
    downloadSetting = DownloadSetting();
    previousAppDocDir = pathService.appDocDir;
    log = TestLogService();
    temp = await Directory.systemTemp.createTemp('hclient-managed-reading-');
    pathService.appDocDir = temp;
    downloadSetting.tempDownloadPath = '${temp.path}/exports'.obs;
    downloadSetting.singleImageSavePath = '${temp.path}/saved'.obs;
    await Directory(downloadSetting.singleImageSavePath.value).create();
    db = AppDb.testing(NativeDatabase(File('${temp.path}/runtime.sqlite')));
    localContentService = LocalContentService(
      repository: ContentRepository(db),
    );
    final root = await Directory('${temp.path}/old/gallery')
        .create(recursive: true);
    await File('${root.path}/001.png').writeAsBytes(png);
    copyId = await localContentService.ensureCopy(
      gid: 41,
      representation: 'original',
      rootPath: root.path,
      makeCurrent: false,
    );
    await localContentService.recordPage(
      copyId: copyId,
      ordinal: 0,
      relativePath: '001.png',
      rawHash: sha256.convert(png).toString(),
      rawLength: png.length,
    );
    await localContentService.completeCopy(
      copyId,
      galleryUrl: 'https://e-hentai.org/g/41/0123456789/',
      title: 'Gallery',
      expectedPages: 1,
    );
    image = (await localContentService.readPageInfoForCopy(copyId))
        .images!
        .single;
  });

  tearDown(() async {
    imageCache.clear();
    imageCache.clearLiveImages();
    localContentService = previousOwner;
    pathService.appDocDir = previousAppDocDir;
    log = previousLog;
    downloadSetting = previousDownloadSetting;
    Get.reset();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('pasteboard'), null);
    await db.close();
    await temp.delete(recursive: true);
  });

  Future<ImageProvider> providerFor(
    WidgetTester tester,
    GalleryImage value,
  ) async {
    await tester.runAsync(
      () => tester.pumpWidget(
        MaterialApp(home: EHImage(galleryImage: value, disableAnimation: true)),
      ),
    );
    return tester.widget<ExtendedImage>(find.byType(ExtendedImage)).image;
  }

  Future<void> decodeProvider(
    WidgetTester tester,
    ImageProvider provider,
  ) async {
    await tester.runAsync(() async {
      final done = Completer<void>();
      final stream = provider.resolve(ImageConfiguration.empty);
      late ImageStreamListener listener;
      listener = ImageStreamListener(
        (info, synchronous) {
          expect(info.image.width, 1);
          expect(info.image.height, 1);
          done.complete();
          stream.removeListener(listener);
        },
        onError: (Object error, StackTrace? stack) {
          done.completeError(error, stack);
          stream.removeListener(listener);
        },
      );
      stream.addListener(listener);
      await done.future.timeout(const Duration(seconds: 10));
    });
  }

  Future<_TestLayoutLogic> layoutForOpenCopy() async {
    Get.routing.args = await localContentService.readPageInfoForCopy(copyId);
    Get.put<ReadPageLogic>(_TestReadPageLogic());
    return _TestLayoutLogic();
  }

  test('PCF owner coalesces WebP display reads and exports original PNG', () async {
    final fixture = File('native/tests/fixtures/gradient.png');
    final bytes = await fixture.readAsBytes();
    final root = await localContentService.rootPath(copyId);
    await File('$root/002.png').writeAsBytes(bytes);
    await localContentService.recordPage(
      copyId: copyId,
      ordinal: 1,
      relativePath: '002.png',
      rawHash: sha256.convert(bytes).toString(),
      rawLength: bytes.length,
      mime: 'image/png',
    );
    final work = await localContentService.representationWorkDirectory(
      copyId,
      'test',
    );
    final artifact = await ContentCodec().encodeFile(
      inputPath: '$root/002.png',
      outputPath: '${work.path}/encoded',
    );
    expect(artifact.codecProfile, ContentCodec.encodedProfile);
    expect(
      await localContentService.installPageRepresentation(
        copyId: copyId,
        ordinal: 1,
        artifact: artifact,
      ),
      isTrue,
    );
    expect(await File('$root/002.png').exists(), isFalse);
    final first = localContentService.readPageForDisplay(copyId, 1);
    final second = localContentService.readPageForDisplay(copyId, 1);
    expect(identical(first, second), isTrue);
    final display = await first;
    expect(String.fromCharCodes(display.take(4)), 'RIFF');
    expect(String.fromCharCodes(display.skip(8).take(4)), 'WEBP');
    expect(display, isNot(bytes));
    final later = localContentService.readPageForDisplay(copyId, 1);
    expect(identical(first, later), isFalse);
    expect(await later, display);
    expect(
      (await localContentService.readPageForExport(copyId, 1)).bytes,
      bytes,
    );
    expect(await localContentService.pageExportName(copyId, 1), '002.png');
    final exported = await localContentService.exportPageToFile(
      copyId,
      1,
      '${temp.path}/exports/002.png',
    );
    expect(await exported.readAsBytes(), bytes);
    expect(await File('$root/002.png').exists(), isFalse);
    await localContentService.completeCopy(
      copyId,
      galleryUrl: 'https://e-hentai.org/g/41/0123456789/',
      title: 'Gallery',
      expectedPages: 2,
    );
    final layout = await layoutForOpenCopy();
    await layout.saveDownloadedImageFile(1);
    expect(
      await File('${temp.path}/saved/41_0123456789_1.png').readAsBytes(),
      bytes,
    );
    String? clipboardPath;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('pasteboard'), (
          call,
        ) async {
          expect(call.method, 'writeFiles');
          clipboardPath = (call.arguments as List).single as String;
          return null;
        });
    await layout.copyDownloadedImageFile(1);
    expect(clipboardPath, endsWith('/002.png'));
    expect(await File(clipboardPath!).readAsBytes(), bytes);
    expect(await File('$root/002.png').exists(), isFalse);
    await ContentCodec().close();
  });

  testWidgets('managed PCF provider decodes pixels without a raw disk cache', (
    tester,
  ) async {
    final root = await tester.runAsync(() async {
      final fixture = File('native/tests/fixtures/gradient.png');
      final bytes = await fixture.readAsBytes();
      final root = await localContentService.rootPath(copyId);
      await File('$root/001.png').writeAsBytes(bytes);
      await localContentService.recordPage(
        copyId: copyId,
        ordinal: 0,
        relativePath: '001.png',
        rawHash: sha256.convert(bytes).toString(),
        rawLength: bytes.length,
        mime: 'image/png',
      );
      final work = await localContentService.representationWorkDirectory(
        copyId,
        'test',
      );
      final artifact = await ContentCodec().encodeFile(
        inputPath: '$root/001.png',
        outputPath: '${work.path}/encoded',
      );
      await localContentService.installPageRepresentation(
        copyId: copyId,
        ordinal: 0,
        artifact: artifact,
      );
      return root;
    });
    final provider = await providerFor(tester, image);
    await tester.runAsync(() async {
      final stream = provider.resolve(ImageConfiguration.empty);
      final done = Completer<void>();
      late ImageStreamListener listener;
      listener = ImageStreamListener(
        (info, _) {
          expect(info.image.width, greaterThan(1));
          expect(info.image.height, greaterThan(1));
          done.complete();
          stream.removeListener(listener);
        },
        onError: (Object error, StackTrace? stack) {
          done.completeError(error, stack);
          stream.removeListener(listener);
        },
      );
      stream.addListener(listener);
      await done.future.timeout(const Duration(seconds: 10));
    });
    await tester.pumpAndSettle();
    final facts = EHImage.sourceInfoFor(
      tester.state(find.byType(ExtendedImage)) as ExtendedImageState,
    );
    final record = await tester.runAsync(
      () => localContentService.repository.getPage(copyId, 0),
    );
    expect(facts!.mime, 'image/webp');
    expect(facts.encodedLength, isNot(record!.rawLength));
    expect(record.mime, 'image/png');
    expect(facts.width, greaterThan(1));
    expect(facts.height, greaterThan(1));
    expect(
      await tester.runAsync(() => File('$root/001.png').exists()),
      isFalse,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => ContentCodec().close());
  });

  test('saving from an open reader resolves the moved owner root', () async {
    final layout = await layoutForOpenCopy();
    await localContentService.relocateCopy(copyId, '${temp.path}/new');
    await layout.saveDownloadedImageFile(0);
    expect(
      await File('${temp.path}/saved/41_0123456789_0.png').readAsBytes(),
      png,
    );
    await File('${temp.path}/saved/41_0123456789_0.png').delete();
    await layout.saveArchiveImageFile(0);
    expect(
      await File('${temp.path}/saved/41_0123456789_0.png').readAsBytes(),
      png,
    );
  });

  test('clipboard export survives a later root move and replaces its previous export', () async {
    final layout = await layoutForOpenCopy();
    final paths = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('pasteboard'), (
          call,
        ) async {
          expect(call.method, 'writeFiles');
          paths.add((call.arguments as List).single as String);
          return null;
        });
    await layout.copyDownloadedImageFile(0);
    expect(await File(paths.single).readAsBytes(), png);
    await localContentService.relocateCopy(copyId, '${temp.path}/new');
    expect(await File(paths.single).readAsBytes(), png);
    await layout.copyArchiveImageFile(0);
    expect(await File(paths.first).exists(), isFalse);
    expect(await File(paths.last).readAsBytes(), png);
  });

  testWidgets(
    'open managed page decodes after relocation deletes its old path',
    (tester) async {
      final providerBefore = await providerFor(tester, image);
      await decodeProvider(tester, providerBefore);
      await tester.pumpWidget(const SizedBox());
      await providerBefore.evict();

      final oldPath = '${temp.path}/${image.path}';
      await tester.runAsync(
        () => localContentService.relocateCopy(copyId, '${temp.path}/new'),
      );
      expect(await tester.runAsync(() => File(oldPath).exists()), isFalse);

      final providerAfter = await providerFor(tester, image);
      expect(providerAfter, providerBefore);
      await decodeProvider(tester, providerAfter);

      // A fresh path hint still refers to the same cached page identity.
      final updatedHint = image.copyWith(path: 'new/gallery/001.png');
      final providerWithUpdatedHint = await providerFor(tester, updatedHint);
      expect(providerWithUpdatedHint, providerBefore);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'replacement refreshes the provider key for an already open page',
    (tester) async {
      final before = await providerFor(tester, image);
      await decodeProvider(tester, before);
      await tester.pumpWidget(const SizedBox());
      // The open reader still holds its old path and hash after replacement.
      await tester.runAsync(() async {
        final replacement = await localContentService.enqueuePageReplacement(
          copyId: copyId,
          ordinal: 0,
          newRelativePath: '002.png',
        );
        final bytes = [...png, 0];
        await File(replacement.tempPath).writeAsBytes(bytes);
        await localContentService.finishDownloadedReplacement(
          replacement.replacementId,
          rawHash: sha256.convert(bytes).toString(),
          rawLength: bytes.length,
          mime: 'image/png',
        );
      });
      final after = await providerFor(tester, image);
      expect(after, isNot(before));
      await decodeProvider(tester, after);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'unmanaged local file reads directly through the observed file provider',
    (tester) async {
      final provider = await providerFor(
        tester,
        GalleryImage(
          url: '',
          path: 'old/gallery/001.png',
          downloadStatus: DownloadStatus.downloaded,
        ),
      );
      // This separate file was never registered with the owner.
      await tester.runAsync(
        () => File('${temp.path}/unmanaged.png').writeAsBytes(png),
      );
      final unmanaged = await providerFor(
        tester,
        GalleryImage(
          url: '',
          path: 'unmanaged.png',
          downloadStatus: DownloadStatus.downloaded,
        ),
      );
      final key = await unmanaged.obtainKey(ImageConfiguration.empty);
      expect(
        key,
        ExtendedFileImageProvider(File('${temp.path}/unmanaged.png')),
      );
      expect(unmanaged, isNot(provider));
      await decodeProvider(tester, unmanaged);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

class _TestReadPageLogic extends ReadPageLogic {
  @override
  void onReady() {}

  @override
  void onClose() {
    state.focusNode.dispose();
    executor.close();
  }
}

class _TestLayoutLogic extends BaseLayoutLogic {
  @override
  void enterAutoMode() {}

  @override
  void toLeft() {}

  @override
  void toRight() {}

  @override
  void toNext() {}

  @override
  void toPrev() {}
}
