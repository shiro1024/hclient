import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/pages/download/download_base_page.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/service/gallery_sync/gallery_sync_service.dart';
import 'package:jhentai/src/widget/cloud_sync_feedback.dart';

class _Words extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {'en_US': {
    'cloudSyncedOne': '@title synced',
    'cloudSyncedCount': '@count tasks synced',
    'cloudOpen': 'Open',
  }};
}

void main() {
  testWidgets('consecutive handoffs update one notice and open the cloud tab', (tester) async {
    final original = gallerySyncService;
    gallerySyncService = GallerySyncService();
    addTearDown(() {
      gallerySyncService = original;
      Get.reset();
    });
    await tester.pumpWidget(GetMaterialApp(
      locale: const Locale('en', 'US'), translations: _Words(),
      home: const CloudSyncFeedback(child: Scaffold(body: Text('Library'))),
      getPages: [GetPage(name: Routes.download, page: () => Scaffold(
        body: Text(Get.arguments == DownloadPageGalleryType.cloud ? 'Cloud library' : 'Wrong tab'),
      ))],
    ));
    gallerySyncService.onHandoffCompleted!('First');
    await tester.pumpAndSettle();
    expect(find.text('First synced'), findsOneWidget);
    gallerySyncService.onHandoffCompleted!('Second');
    await tester.pumpAndSettle();
    expect(find.text('2 tasks synced'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Cloud library'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    expect(gallerySyncService.onHandoffCompleted, isNull);
  });
}
