import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/extension/get_logic_extension.dart';
import 'package:jhentai/src/mixin/scroll_to_top_logic_mixin.dart';
import 'package:jhentai/src/mixin/update_global_gallery_status_logic_mixin.dart';

import '../../../../model/read_page_info.dart';
import '../../../../routes/routes.dart';
import '../../../../service/gallery_download/download_path_resolver.dart';
import '../../../../service/gallery_download/gallery_download_service.dart';
import '../../../../service/local_content_service.dart';
import '../../../../service/read_progress_service.dart';
import '../../../../setting/read_setting.dart';
import '../../../../setting/preference_setting.dart';
import '../../../../utils/route_util.dart';
import '../../../../utils/convert_util.dart';
import '../../../../widget/eh_alert_dialog.dart';
import '../../../../widget/eh_context_menu.dart';
import '../../../../widget/eh_download_dialog.dart';
import '../basic/multi_select/multi_select_download_page_logic_mixin.dart';
import '../basic/webdav_actions.dart';

mixin GalleryDownloadPageLogicMixin on GetxController
    implements
        Scroll2TopLogicMixin,
        MultiSelectDownloadPageLogicMixin<GalleryDownloadInfo>,
        UpdateGlobalGalleryStatusLogicMixin {
  final String bodyId = 'bodyId';

  final GalleryDownloadService downloadService = galleryDownloadService;

  Future<bool> confirmDestructiveAction({
    required String title,
    String? content,
  }) async {
    if (!preferenceSetting.confirmDestructiveActions.isTrue) {
      return true;
    }
    bool? result = await Get.dialog(EHDialog(title: title, content: content));
    return result == true;
  }

  Future<void> handleChangeGroup(GalleryDownloadInfo gallery) async {
    String oldGroup = downloadService.galleryDownloadInfos[gallery.gid]!.group;

    ({String group, bool downloadOriginalImage})? result = await Get.dialog(
      EHDownloadDialog(
        title: 'changeGroup'.tr,
        currentGroup: oldGroup,
        candidates: downloadService.allGroups,
      ),
    );

    if (result == null) {
      return;
    }

    String newGroup = result.group;
    if (newGroup == oldGroup) {
      return;
    }

    await downloadService.updateGroup(gallery, newGroup);

    update([bodyId]);
  }

  Future<void> handleLongPressGroup(String oldGroup) async {
    if (downloadService.galleryDownloadInfos.values.every(
      (g) => g.group != oldGroup,
    )) {
      return handleDeleteGroup(oldGroup);
    }
    return handleRenameGroup(oldGroup);
  }

  Future<void> handleRenameGroup(String oldGroup) async {
    ({String group, bool downloadOriginalImage})? result = await Get.dialog(
      EHDownloadDialog(
        title: 'renameGroup'.tr,
        currentGroup: oldGroup,
        candidates: downloadService.allGroups,
      ),
    );

    if (result == null) {
      return;
    }

    String newGroup = result.group;
    if (newGroup == oldGroup) {
      return;
    }

    return doRenameGroup(oldGroup, newGroup);
  }

  Future<void> doRenameGroup(String oldGroup, String newGroup) async {
    await downloadService.renameGroup(oldGroup, newGroup);
    update([bodyId]);
  }

  Future<void> handleDeleteGroup(String oldGroup) async {
    bool? success = await Get.dialog(EHDialog(title: 'deleteGroup'.tr + '?'));
    if (success == null || !success) {
      return;
    }

    await downloadService.deleteGroup(oldGroup);

    update([bodyId]);
  }

  @override
  void handleTapItem(GalleryDownloadInfo item) {
    if (multiSelectDownloadPageState.inMultiSelectMode) {
      toggleSelectItem(item.gid);
    } else {
      goToReadPage(item);
    }
  }

  @override
  void handleLongPressOrSecondaryTapItem(
    GalleryDownloadInfo item,
    BuildContext context, {
    Offset? position,
  }) {
    if (multiSelectDownloadPageState.inMultiSelectMode) {
      toggleSelectItem(item.gid);
    } else {
      showBottomSheet(item, context, position: position);
    }
  }

  void handleResumeAllTasks() {
    downloadService.resumeAllDownloadGallery();
  }

  void handlePauseAllTasks() {
    downloadService.pauseAllDownloadGallery();
  }

  void handleRemoveItem(
    GalleryDownloadInfo gallery,
    bool deleteImages,
    BuildContext context,
  ) async {
    downloadService.update([downloadService.galleryCountChangedId]);
  }

  void handleAssignPriority(GalleryDownloadInfo gallery, int priority) {
    downloadService.assignPriority(gallery, priority);
    updateSafely([bodyId]);
  }

  Future<void> handleReDownloadItem(GalleryDownloadInfo gallery) async {
    bool confirmed = await confirmDestructiveAction(
      title: 'reDownload'.tr + '?',
    );
    if (!confirmed) {
      return;
    }
    downloadService.reDownloadGallery(gallery);
  }

  Future<void> goToReadPage(GalleryDownloadInfo gallery) async {
    final completedCopyId = await downloadService.ensureContentCopy(
      gallery.gid,
    );
    if (completedCopyId != null) {
      await _openContentCopy(completedCopyId, gallery);
      return;
    }
    final currentCopyId = await localContentService.currentCopyId(
      gallery.gid,
      gallery.downloadOriginalImage ? 'original' : 'resampled',
    );
    // A full redownload builds a new directory before it becomes current.
    // Keep the previous completed copy readable during that window.
    if (currentCopyId != null &&
        currentCopyId != gallery.copyId &&
        await localContentService.completedInput(currentCopyId) != null) {
      final readIndexRecord = await readProgressService.getReadProgress(
        gallery.gid,
      );
      final info = await localContentService.readPageInfoForCopy(
        currentCopyId,
        initialIndex: readIndexRecord,
      );
      info.readProgressRecordStorageKey = gallery.gid.toString();
      toRoute(Routes.read, arguments: info);
      return;
    }
    int readIndexRecord = await readProgressService.getReadProgress(
      gallery.gid,
    );

    /// Ensure the gallery's image list is resident before entering read
    /// page — ReadPageState's constructor reads [imageAtSync] synchronously
    /// to build the initial snapshot. If images has been evicted (gallery
    /// was fully downloaded), this reloads from DB.
    await galleryDownloadService.galleryDownloadInfos[gallery.gid]!
        .ensureImagesLoaded();

    ReadDirection? readDirection = isWebtoonGalleryFromTagString(gallery.tags)
        ? ReadDirection.top2bottomList
        : null;

    toRoute(
      Routes.read,
      arguments: ReadPageInfo(
        mode: ReadMode.downloaded,
        gid: gallery.gid,
        token: gallery.token,
        galleryTitle: gallery.title,
        galleryUrl: gallery.galleryUrl,
        initialIndex: readIndexRecord,
        readProgressRecordStorageKey: gallery.gid.toString(),
        pageCount: gallery.pageCount,
        readDirection: readDirection,
      ),
    );
  }

  Future<void> _openContentCopy(
    String copyId,
    GalleryDownloadInfo gallery,
  ) async {
    final info = await localContentService.readPageInfoForCopy(
      copyId,
      initialIndex: await readProgressService.getReadProgress(gallery.gid),
    );
    info.readDirection = isWebtoonGalleryFromTagString(gallery.tags)
        ? ReadDirection.top2bottomList
        : null;
    toRoute(Routes.read, arguments: info);
  }

  Future<String?> _copyForCloud(int gid) async {
    final gallery = downloadService.galleryDownloadInfos[gid];
    if (gallery == null) return null;
    final completed = await downloadService.ensureContentCopy(gid);
    if (completed != null) return completed;
    return localContentService.ensureCopy(
      gid: gid,
      representation: gallery.downloadOriginalImage ? 'original' : 'resampled',
      rootPath: DownloadPathResolver.computeGalleryDownloadAbsolutePath(
        gallery.toGalleryDownloadedData(),
      ),
      makeCurrent: false,
    );
  }

  Future<void> handleCloudUpload(
    GalleryDownloadInfo item, {
    bool cleanup = false,
  }) => queueCloudUploads([
    () => _copyForCloud(item.gid),
  ], cleanupAfterUpload: cleanup);

  Future<void> handleMultiCloudUpload({bool cleanup = false}) async {
    final gids = multiSelectDownloadPageState.selectedGids.toList();
    await queueCloudUploads(
      gids.map(
        (gid) =>
            () => _copyForCloud(gid),
      ),
      cleanupAfterUpload: cleanup,
    );
    exitSelectMode();
  }

  void showBottomSheet(
    GalleryDownloadInfo gallery,
    BuildContext context, {
    Offset? position,
  }) {
    showEHContextMenu(
      context,
      position: position,
      actions: [
        ...[
          EHContextMenuAction(
            text: 'cloudUpload'.tr,
            onTap: () => handleCloudUpload(gallery),
          ),
          EHContextMenuAction(
            text: 'cloudUploadAndClean'.tr,
            onTap: () => handleCloudUpload(gallery, cleanup: true),
          ),
        ],
        EHContextMenuAction(
          text: 'changeGroup'.tr,
          onTap: () => handleChangeGroup(gallery),
        ),
        EHContextMenuAction(
          text: 'changePriority'.tr,
          onTap: () => showPrioritySheet(gallery, context, position: position),
        ),
        EHContextMenuAction(
          text: 'reDownload'.tr,
          onTap: () => handleReDownloadItem(gallery),
        ),
        EHContextMenuAction(
          text: 'deleteTask'.tr,
          color: UIConfig.alertColor(context),
          onTap: () => handleRemoveItem(gallery, false, context),
        ),
        EHContextMenuAction(
          text: 'deleteTaskAndImages'.tr,
          color: UIConfig.alertColor(context),
          onTap: () => handleRemoveItem(gallery, true, context),
        ),
      ],
    );
  }

  void showPrioritySheet(
    GalleryDownloadInfo gallery,
    BuildContext context, {
    Offset? position,
  }) {
    showEHContextMenu(
      context,
      position: position,
      actions: [
        EHContextMenuAction(
          text: '${'priority'.tr} : 1 (${'highest'.tr})',
          isDefault:
              downloadService.galleryDownloadInfos[gallery.gid]?.priority == 1,
          onTap: () => handleAssignPriority(gallery, 1),
        ),
        ...[2, 3]
            .map(
              (i) => EHContextMenuAction(
                text: '${'priority'.tr} : $i',
                isDefault:
                    downloadService
                        .galleryDownloadInfos[gallery.gid]
                        ?.priority ==
                    i,
                onTap: () => handleAssignPriority(gallery, i),
              ),
            )
            .toList(),
        EHContextMenuAction(
          text: '${'priority'.tr} : 4 (${'default'.tr})',
          isDefault:
              downloadService.galleryDownloadInfos[gallery.gid]?.priority == 4,
          onTap: () => handleAssignPriority(gallery, 4),
        ),
        EHContextMenuAction(
          text: '${'priority'.tr} : 5',
          isDefault:
              downloadService.galleryDownloadInfos[gallery.gid]?.priority == 5,
          onTap: () => handleAssignPriority(gallery, 5),
        ),
      ],
    );
  }

  Future<void> handleMultiResumeTasks() async {
    for (int gid in multiSelectDownloadPageState.selectedGids) {
      downloadService.resumeDownloadGalleryByGid(gid);
    }

    exitSelectMode();
  }

  Future<void> handleMultiPauseTasks() async {
    for (int gid in multiSelectDownloadPageState.selectedGids) {
      downloadService.pauseDownloadGalleryByGid(gid);
    }

    exitSelectMode();
  }

  Future<void> handleMultiReDownloadItems() async {
    bool? result = await Get.dialog(
      EHDialog(title: 'reDownload'.tr, content: 'multiReDownloadHint'.tr),
    );

    if (result == true) {
      for (int gid in multiSelectDownloadPageState.selectedGids) {
        downloadService.reDownloadGalleryByGid(gid);
      }

      exitSelectMode();
    }
  }

  Future<void> handleMultiChangeGroup() async {
    ({String group, bool downloadOriginalImage})? result = await Get.dialog(
      EHDownloadDialog(
        title: 'changeGroup'.tr,
        candidates: downloadService.allGroups,
      ),
    );

    if (result == null) {
      return;
    }

    String newGroup = result.group;

    for (int gid in multiSelectDownloadPageState.selectedGids) {
      await downloadService.updateGroupByGid(gid, newGroup);
    }

    multiSelectDownloadPageState.inMultiSelectMode = false;
    multiSelectDownloadPageState.selectedGids.clear();
    updateSafely([bottomAppbarId, bodyId]);
  }

  Future<void> handleMultiDelete() async {
    bool isUpdatingDependent = multiSelectDownloadPageState.selectedGids.any(
      downloadService.isUpdatingDependent,
    );

    bool? result = await Get.dialog(
      EHDialog(
        title: 'delete'.tr,
        content:
            'multiDeleteHint'.tr +
            (isUpdatingDependent
                ? '\n\n' + 'deleteUpdatingDependentHint'.tr
                : ''),
      ),
    );

    if (result == true) {
      List<Future> futures = [];

      for (int gid in multiSelectDownloadPageState.selectedGids) {
        futures.add(downloadService.deleteGalleryByGid(gid));
      }

      exitSelectMode();
      await Future.wait(futures);
      updateGlobalGalleryStatus();
    }
  }
}
