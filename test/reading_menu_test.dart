import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/l18n/locale_text.dart';
import 'package:jhentai/src/model/gallery_image.dart';
import 'package:jhentai/src/model/read_page_info.dart';
import 'package:jhentai/src/pages/read/read_image_info.dart';
import 'package:jhentai/src/pages/read/read_page.dart';
import 'package:jhentai/src/pages/read/read_page_logic.dart';
import 'package:jhentai/src/setting/read_setting.dart';
import 'package:jhentai/src/service/gallery_download/gallery_download_service.dart';

class _MenuLogic extends ReadPageLogic {
  int taps = 0;

  @override
  void onReady() {}

  @override
  void beginToParseImageHref(int index) {}

  @override
  void onClose() {
    state.focusNode.dispose();
    executor.close();
  }

  @override
  void handleTapZone(int index) => taps++;
}

void main() {
  testWidgets(
    'reader hides the complete wrapping menu and passes taps through while closing',
    (tester) async {
      Get.testMode = true;
      Get.put<GalleryDownloadService>(GalleryDownloadService());
      final previousSettings = readSetting;
      readSetting = ReadSetting();
      readSetting.enableImmersiveMode.value = true;
      readSetting.showStatusInfo.value = false;
      readSetting.showThumbnails.value = true;
      readSetting.enableOrientationSpecificReadDirection.value = false;
      readSetting.readDirection.value = ReadDirection.left2rightSinglePage;
      Get.routing.args = ReadPageInfo(
        mode: ReadMode.online,
        galleryTitle: 'Reader',
        initialIndex: 0,
        pageCount: 3,
        images: List.generate(
          3,
          (_) => GalleryImage(
            url: '',
            width: 800,
            height: 1200,
            originalImageWidth: 2400,
            originalImageHeight: 3600,
          ),
        ),
        readProgressRecordStorageKey: 'menu-test',
      );
      final logic = Get.put<ReadPageLogic>(_MenuLogic()) as _MenuLogic;
      try {
        await tester.pumpWidget(
          GetMaterialApp(
            locale: const Locale('en', 'US'),
            translations: LocaleText(),
            home: Builder(
              builder: (_) {
                Get.routing.args = logic.state.readPageInfo;
                return const ReadPage();
              },
            ),
          ),
        );
        logic.toggleMenu();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        final info = find.byType(ReadingImageInfo);
        expect(
          find.descendant(
            of: info,
            matching: find.textContaining('800 × 1200'),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: info,
            matching: find.textContaining('2400 × 3600'),
          ),
          findsNothing,
        );
        final openRect = tester.getRect(info);
        final menu = find.ancestor(
          of: info,
          matching: find.byType(AnimatedSlide),
        );
        final openSize = tester.getSize(menu);
        logic.toggleMenu();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 30));
        expect(tester.getSize(menu), openSize);
        await tester.tapAt(openRect.center);
        expect(logic.taps, 1);
        await tester.pump(const Duration(milliseconds: 250));
        final height =
            tester.view.physicalSize.height / tester.view.devicePixelRatio;
        expect(tester.getTopLeft(info).dy, greaterThanOrEqualTo(height));
        final semantics = tester.widget<ExcludeSemantics>(
          find
              .ancestor(of: info, matching: find.byType(ExcludeSemantics))
              .first,
        );
        expect(semantics.excluding, isTrue);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        Get.reset();
        readSetting = previousSettings;
      }
    },
  );
}
