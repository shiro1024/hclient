import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/service/content_sync/content_repository.dart';
import 'package:jhentai/src/service/download_relocation_service.dart';
import 'package:jhentai/src/service/gallery_sync/gallery_sync_service.dart';
import 'package:jhentai/src/service/local_content_service.dart';
import 'package:jhentai/src/service/local_gallery_service.dart';
import 'package:jhentai/src/service/log.dart';
import 'package:jhentai/src/service/path_service.dart';
import 'package:jhentai/src/setting/download_setting.dart';

import 'support/test_log_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('recent gallery groups can be disabled', () {
    DownloadSetting setting = DownloadSetting();
    setting.recentGalleryGroups = ['recent', 'older'];

    expect(setting.preferredGalleryGroups, ['recent', 'older']);

    setting.prioritizeRecentGalleryGroups.value = false;
    expect(setting.preferredGalleryGroups, isEmpty);
  });

  group('default directory and explicit migration', () {
    late Directory home;
    late LogService previousLog;
    late DownloadRelocationService relocation;

    setUp(() async {
      previousLog = log;
      log = TestLogService();
      home = await Directory.systemTemp.createTemp('download-directory-');
      pathService.appDocDir = home;
      pathService.appSupportDir = home;
      pathService.tempDir = home;
      appDb = AppDb.testing(NativeDatabase(File('${home.path}/db.sqlite')));
      await downloadSetting.doInitBean();
      localContentService = LocalContentService(
        repository: ContentRepository(appDb),
      );
      await localContentService.doInitBean();
      gallerySyncService = GallerySyncService(
        repository: ContentRepository(appDb),
      );
      localGalleryService = LocalGalleryService();
      relocation = DownloadRelocationService();
      await relocation.doInitBean();
    });

    tearDown(() async {
      gallerySyncService.dispose();
      await appDb.close();
      await home.delete(recursive: true);
      log = previousLog;
    });

    Future<String> copy(String parent, int gid, String name) async {
      final root = Directory('$parent/$name');
      await root.create(recursive: true);
      await File('native/tests/fixtures/passthrough.webp')
          .copy('${root.path}/001.webp');
      final id = await localContentService.ensureCopy(
        gid: gid,
        representation: 'original',
        rootPath: root.path,
      );
      await localContentService.recordPage(
        copyId: id,
        ordinal: 0,
        relativePath: '001.webp',
        mime: 'image/webp',
      );
      await localContentService.completeCopy(
        id,
        galleryUrl: 'https://e-hentai.org/g/$gid/0123456789/',
        title: name,
        expectedPages: 1,
      );
      return id;
    }

    test(
      'new default leaves existing content until explicit migration',
      () async {
        final oldParent = '${home.path}/old';
        final newParent = '${home.path}/current';
        final oldId = await copy(oldParent, 7101, 'old-copy');
        await Directory(newParent).create();
        await downloadSetting.saveDownloadPath(newParent);
        final currentId = await copy(
          downloadSetting.downloadPath.value,
          7102,
          'current-copy',
        );
        await localGalleryService.refreshLocalGalleries();
        expect(
          await localContentService.rootPath(oldId),
          '$oldParent/old-copy',
        );
        expect(await File('$oldParent/old-copy/001.webp').exists(), isTrue);
        expect(
          localGalleryService.allGalleries.map((item) => item.copyId),
          contains(oldId),
        );

        final progress = <(int, int)>[];
        final result = await relocation.moveToCurrentDirectory(
          onProgress: (done, total) => progress.add((done, total)),
        );
        expect(result, (moved: 1, failed: 0));
        expect(progress, [(0, 1), (1, 1)]);
        expect(await Directory('$oldParent/old-copy').exists(), isFalse);
        expect(
          await localContentService.rootPath(oldId),
          '$newParent/old-copy',
        );
        expect(
          await localContentService.rootPath(currentId),
          '$newParent/current-copy',
        );
        expect(
          await localContentService.withPageInput(
            oldId,
            0,
            (file) => file.readAsBytes(),
          ),
          await File('native/tests/fixtures/passthrough.webp').readAsBytes(),
        );
        expect((await relocation.moveToCurrentDirectory()), (
          moved: 0,
          failed: 0,
        ));
      },
    );

    test('one missing source does not stop the remaining downloads', () async {
      final oldParent = '${home.path}/old';
      final newParent = '${home.path}/current';
      await copy(oldParent, 7103, 'missing');
      final good = await copy(oldParent, 7104, 'good');
      await Directory('$oldParent/missing').delete(recursive: true);
      await Directory(newParent).create();
      await downloadSetting.saveDownloadPath(newParent);
      final result = await relocation.moveToCurrentDirectory();
      expect(result, (moved: 1, failed: 1));
      expect(await localContentService.rootPath(good), '$newParent/good');
      expect(await File('$newParent/good/001.webp').exists(), isTrue);
    });
  });
}
