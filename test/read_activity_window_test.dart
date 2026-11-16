import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/model/read_page_info.dart';
import 'package:jhentai/src/pages/read/read_page_logic.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/widget/app_manager.dart';

class _ReadWindowProbe extends ReadPageLogic {
  int brightness = 0, orientation = 0, immersive = 0, restored = 0;
  @override
  void applyCurrentBrightness() => brightness++;
  @override
  void updateDeviceOrientation() => orientation++;
  @override
  void applyCurrentImmersiveMode() => immersive++;
  @override
  void restoreImmersiveMode() => restored++;
}

void main() {
  testWidgets(
    'reader window replay respects a covering settings route and unregisters',
    (tester) async {
      Get.testMode = true;
      await tester.pumpWidget(
        GetMaterialApp(
          initialRoute: Routes.read,
          getPages: [
            GetPage(
              name: Routes.read,
              page: () => const Scaffold(body: Text('reader')),
            ),
            GetPage(
              name: Routes.settingRead,
              page: () => const Scaffold(body: Text('settings')),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      Get.routing.args = ReadPageInfo(
        mode: ReadMode.online,
        galleryTitle: 'Reader',
        initialIndex: 0,
        pageCount: 1,
        readProgressRecordStorageKey: 'fixture',
      );
      final logic = _ReadWindowProbe();
      AppManager.registerActivityWindowCallback(
        logic.replayActivityWindowState,
      );
      AppManager.replayActivityWindowState();
      expect(
        [logic.brightness, logic.orientation, logic.immersive, logic.restored],
        [1, 1, 1, 0],
      );
      Get.toNamed(Routes.settingRead);
      await tester.pumpAndSettle();
      AppManager.replayActivityWindowState();
      expect(
        [logic.brightness, logic.orientation, logic.immersive, logic.restored],
        [2, 2, 1, 1],
      );
      Get.back();
      await tester.pumpAndSettle();
      AppManager.replayActivityWindowState();
      expect(
        [logic.brightness, logic.orientation, logic.immersive, logic.restored],
        [3, 3, 2, 1],
      );
      AppManager.unregisterActivityWindowCallback(
        logic.replayActivityWindowState,
      );
      AppManager.replayActivityWindowState();
      expect(logic.brightness, 3);
      logic.state.focusNode.dispose();
      await logic.executor.close();
      await tester.pumpWidget(const SizedBox());
      Get.reset();
    },
  );
}
