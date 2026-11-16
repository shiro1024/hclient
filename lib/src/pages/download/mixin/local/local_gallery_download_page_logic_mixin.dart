import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/extension/string_extension.dart';
import 'package:path/path.dart';

import '../../../../config/ui_config.dart';
import '../../../../enum/config_enum.dart';
import '../../../../model/gallery_image.dart';
import '../../../../model/read_page_info.dart';
import '../../../../routes/routes.dart';
import '../../../../service/local_config_service.dart';
import '../../../../service/local_gallery_service.dart';
import '../../../../service/local_content_service.dart';
import '../../../../service/read_progress_service.dart';
import '../basic/webdav_actions.dart';
import '../../../../utils/route_util.dart' as route;
import '../../../../utils/toast_util.dart';
import '../../../../widget/eh_alert_dialog.dart';
import '../../../../widget/eh_context_menu.dart';
import '../../../../widget/loading_state_indicator.dart';

mixin LocalGalleryDownloadPageLogicMixin on GetxController {
  final String bodyId = 'bodyId';

  String get currentPath;

  set currentPath(String value);

  bool get isAtRootPath => currentPath == LocalGalleryService.rootPath;

  int computeItemCount() {
    return isAtRootPath
        ? localGalleryService.rootDirectories.length
        : (localGalleryService.path2GalleryDir[currentPath]?.length ?? 0) +
              (localGalleryService.path2SubDir[currentPath]?.length ?? 0) +
              1;
  }

  int computeCurrentDirectoryCount() {
    if (isAtRootPath) {
      return localGalleryService.rootDirectories.length;
    }

    return localGalleryService.path2SubDir[currentPath]?.length ?? 0;
  }

  String computeChildPath(int index) {
    if (isAtRootPath) {
      return localGalleryService.rootDirectories[index];
    }

    return localGalleryService.path2SubDir[currentPath]![index];
  }

  Future<void> handleRemoveItem(LocalGallery gallery) async {
    bool? result = await Get.dialog(
      EHDialog(title: 'deleteLocalGalleryHint'.tr + '?'),
    );
    if (result == true) {
      doRemoveItem(gallery);
    }
  }

  Future<void> doRemoveItem(LocalGallery gallery) async {
    if (gallery.copyId != null) {
      await localGalleryService.deleteGallery(gallery, currentPath);
    }
    update([bodyId]);
  }

  void pushRoute(String dirName) {
    currentPath = join(currentPath, dirName);
    update([bodyId]);
  }

  void backRoute() {
    if (isAtRootPath) {
      return;
    }

    if (localGalleryService.rootDirectories.contains(currentPath)) {
      currentPath = LocalGalleryService.rootPath;
    } else {
      currentPath = Directory(currentPath).parent.path;
    }

    update([bodyId]);
  }

  Future<void> goToReadPage(LocalGallery gallery) async {
    if (gallery.copyId case final copyId?) {
      final index = await readProgressService.getReadProgress(gallery.gid!);
      final info = await localContentService.readPageInfoForCopy(
        copyId,
        initialIndex: index,
      );
      route.toRoute(Routes.read, arguments: info);
      return;
    }
    String? string = await localConfigService.read(
      configKey: ConfigEnum.readIndexRecord,
      subConfigKey: gallery.cover.path!,
    );
    int readIndexRecord = (string == null ? 0 : (int.tryParse(string) ?? 0));

    List<GalleryImage> images = localGalleryService.getGalleryImages(gallery);

    route.toRoute(
      Routes.read,
      arguments: ReadPageInfo(
        mode: ReadMode.local,
        galleryTitle: gallery.title,
        initialIndex: readIndexRecord,
        pageCount: images.length,
        readProgressRecordStorageKey: gallery.cover.path!,
        images: images,
      ),
    );
  }

  Future<void> handleRefreshLocalGallery() async {
    if (localGalleryService.loadingState == LoadingState.loading) {
      return;
    }

    int preCount = localGalleryService.allGalleries.length;

    localGalleryService.refreshLocalGalleries().then((_) {
      currentPath = LocalGalleryService.rootPath;
      update([bodyId]);
      toast(
        '${'newGalleryCount'.tr}: ${localGalleryService.allGalleries.length - preCount}',
      );
    });
  }

  void showBottomSheet(
    LocalGallery gallery,
    BuildContext context, {
    Offset? position,
  }) {
    showEHContextMenu(
      context,
      position: position,
      actions: [
        if (gallery.copyId != null) ...[
          EHContextMenuAction(
            text: 'cloudUpload'.tr,
            onTap: () => queueCloudUploads([
              () async => gallery.copyId,
            ], cleanupAfterUpload: false),
          ),
          EHContextMenuAction(
            text: 'cloudUploadAndClean'.tr,
            onTap: () => queueCloudUploads([
              () async => gallery.copyId,
            ], cleanupAfterUpload: true),
          ),
        ],
        EHContextMenuAction(
          text: 'delete'.tr,
          color: UIConfig.alertColor(context),
          onTap: () => handleRemoveItem(gallery),
        ),
      ],
    );
  }

  String transformDisplayPath(String path) {
    List<String> parts = path.split(separator);
    if (parts.length > 2) {
      return '.../${parts[parts.length - 2]}/${parts[parts.length - 1]}'
          .breakWord;
    } else {
      return path.breakWord;
    }
  }
}
