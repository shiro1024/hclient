import 'package:path/path.dart' as path;

import '../database/database.dart';
import '../setting/download_setting.dart';
import 'archive_download_service.dart';
import 'content_page_download_service.dart';
import 'gallery_download/gallery_download_service.dart';
import 'gallery_sync/gallery_sync_service.dart';
import 'jh_service.dart';
import 'local_content_service.dart';
import 'local_gallery_service.dart';
import 'log.dart';

final downloadRelocationService = DownloadRelocationService();

class DownloadRelocationService
    with JHLifeCircleBeanErrorCatch
    implements JHLifeCircleBean {
  @override
  List<JHLifeCircleBean> get initDependencies => [
    localContentService,
    galleryDownloadService,
    archiveDownloadService,
    gallerySyncService,
    localGalleryService,
  ];

  @override
  Future<void> doInitBean() async {
    localContentService.onBeforeRetirement = prepareCopyRetirement;
    localContentService.onBeforeRelocation = (copyId) async {
      await Future.wait([
        contentPageDownloadService.prepareCopyRelocation(copyId),
        galleryDownloadService.prepareCopyRelocation(copyId),
        archiveDownloadService.prepareCopyRelocation(copyId),
        gallerySyncService.prepareCopyRelocation(copyId),
      ]);
    };
    localContentService.onAfterRelocation = (copyId, usable) async {
      await Future.wait([
        contentPageDownloadService.finishCopyRelocation(copyId, usable),
        galleryDownloadService.finishCopyRelocation(copyId, usable),
        archiveDownloadService.finishCopyRelocation(copyId, usable),
        gallerySyncService.finishCopyRelocation(copyId, usable),
      ]);
    };
  }

  @override
  Future<void> doAfterBeanReady() async {
    await contentPageDownloadService.resumePendingReplacements();
  }

  Future<void> prepareCopyRetirement(String copyId) async {
    await Future.wait([
      contentPageDownloadService.cancelAndJoin(copyId),
      galleryDownloadService.stopCopyDownloads(copyId),
      archiveDownloadService.stopCopyDownloads(copyId),
    ]);
    await localContentService.abandonDownloadingReplacements(copyId);
    await localContentService.finishCommittingReplacements(copyId);
  }

  Future<({int moved, int failed})> moveToCurrentDirectory({
    void Function(int completed, int total)? onProgress,
  }) => _move(onProgress);

  Future<({int moved, int failed})> _move(
    void Function(int completed, int total)? onProgress,
  ) async {
    final destination = path.normalize(
      path.absolute(downloadSetting.downloadPath.value),
    );
    if (localContentService.isManagedDirectory(destination)) {
      throw ArgumentError.value(destination, 'targetParent');
    }
    final copies = await appDb
        .customSelect(
          "SELECT copy_id, root_path FROM content_copy WHERE lifecycle = 'active'",
        )
        .get();
    final unfinished = await localContentService.repository.listWorkItems(
      kind: 'local_relocation',
    );
    final ids = {
      for (final row in copies)
        if (!path.equals(
          path.dirname(path.normalize(row.read<String>('root_path'))),
          destination,
        ))
          row.read<String>('copy_id'),
      for (final work in unfinished)
        if (work.copyId != null) work.copyId!,
    };
    var moved = 0;
    var failed = 0;
    onProgress?.call(0, ids.length);
    for (final id in ids) {
      try {
        await localContentService.relocateCopy(id, destination);
        moved++;
      } catch (error, stack) {
        failed++;
        log.error('Move download copy $id failed', error, stack);
      }
      onProgress?.call(moved + failed, ids.length);
    }
    await localGalleryService.refreshLocalGalleries();
    return (moved: moved, failed: failed);
  }
}
