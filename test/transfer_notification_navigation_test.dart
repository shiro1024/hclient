import 'package:flutter/material.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/model/jh_layout.dart';
import 'package:jhentai/src/pages/lock_page.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/service/log.dart';
import 'package:jhentai/src/service/transfer_activity_service.dart';
import 'package:jhentai/src/setting/security_setting.dart';
import 'package:jhentai/src/setting/style_setting.dart';
import 'package:jhentai/src/widget/app_manager.dart';

import 'support/test_log_service.dart';

void main() {
  setUp(() {
    Get.testMode = true;
    log = TestLogService();
    styleSetting.layout.value = LayoutMode.mobileV2;
    securitySetting.enablePasswordAuth.value = true;
    securitySetting.encryptedPassword.value = keyToMd5('1234');
    securitySetting.enableBiometricAuth.value = false;
    securitySetting.enableAuthOnResume.value = true;
    securitySetting.enableBlur.value = true;
  });
  tearDown(() {
    securitySetting.enablePasswordAuth.value = false;
    securitySetting.enableAuthOnResume.value = false;
    securitySetting.enableBlur.value = false;
    Get.reset();
  });

  Future<void> mount(WidgetTester tester, String initialRoute) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: initialRoute,
        getPages: [
          GetPage(name: Routes.lock, page: () => const LockPage()),
          GetPage(
            name: Routes.home,
            page: () => const Scaffold(body: Text('home')),
          ),
          GetPage(
            name: '/transfer-test',
            page: () => const Scaffold(body: Text('transfer')),
          ),
        ],
        builder: (_, child) => AppManager(child: child!),
      ),
    );
    await tester.pumpAndSettle();
    await transferActivityService.doAfterBeanReady();
  }

  Future<void> unlock(WidgetTester tester) async {
    await tester.enterText(find.byType(EditableText).first, '1234');
    await tester.pumpAndSettle();
  }

  testWidgets(
    'cold notification waits on the existing PIN route and consumes once after unlock',
    (tester) async {
      await mount(tester, Routes.lock);
      var opened = 0;
      transferActivityService.openTarget = (_) async {
        opened++;
        Get.toNamed('/transfer-test');
      };
      transferActivityService.queueNotificationTarget('cloud');
      await tester.pumpAndSettle();
      expect(Get.currentRoute, Routes.lock);
      expect(opened, 0);
      await unlock(tester);
      expect(Get.currentRoute, '/transfer-test');
      expect(opened, 1);
      transferActivityService.navigationReady();
      await tester.pumpAndSettle();
      expect(opened, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'notification before resume respects the existing timed resume lock',
    (tester) async {
      await mount(tester, Routes.home);
      var opened = 0;
      transferActivityService.openTarget = (_) async {
        opened++;
        Get.toNamed('/transfer-test', preventDuplicates: false);
      };
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 3100)),
      );
      transferActivityService.queueNotificationTarget('cloud');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(Get.currentRoute, Routes.lock);
      expect(opened, 0);
      await unlock(tester);
      expect(Get.currentRoute, '/transfer-test');
      expect(opened, 1);
      transferActivityService.queueNotificationTarget('archive');
      await tester.pumpAndSettle();
      expect(opened, 2);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
