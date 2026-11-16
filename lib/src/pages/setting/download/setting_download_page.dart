import 'dart:io' as io;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/extension/string_extension.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:jhentai/src/service/local_gallery_service.dart';
import 'package:jhentai/src/setting/download_setting.dart';
import 'package:jhentai/src/setting/user_setting.dart';
import 'package:jhentai/src/utils/toast_util.dart';
import 'package:jhentai/src/widget/eh_wheel_speed_controller.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';

import '../../../routes/routes.dart';
import '../../../service/archive_download_service.dart';
import '../../../service/gallery_download/gallery_download_service.dart';
import '../../../service/log.dart';
import '../../../service/local_content_service.dart';
import '../../../service/download_relocation_service.dart';
import '../../../utils/permission_util.dart';
import '../../../utils/route_util.dart';
import '../../../widget/eh_download_dialog.dart';

class SettingDownloadPage extends StatefulWidget {
  const SettingDownloadPage({Key? key}) : super(key: key);

  @override
  State<SettingDownloadPage> createState() => _SettingDownloadPageState();
}

class _SettingDownloadPageState extends State<SettingDownloadPage> {
  LoadingState changeDownloadPathState = LoadingState.idle;
  bool movingDownloads = false;
  int movedDownloads = 0;
  int totalDownloadsToMove = 0;

  final ScrollController scrollController = ScrollController();

  @override
  void dispose() {
    super.dispose();
    scrollController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: Text('downloadSetting'.tr)),
      body: Obx(
        () => EHWheelSpeedController(
          controller: scrollController,
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.only(top: 16),
            children: [
              _buildDownloadPath(),
              if (!GetPlatform.isIOS) _buildResetDownloadPath(),
              _buildMoveDownloads(),
              _buildExtraGalleryScanPath(),
              if (GetPlatform.isDesktop) _buildSingleImageSavePath(),
              _buildDownloadOriginalImage(),
              _buildDefaultGalleryGroup(context),
              _buildPrioritizeRecentGalleryGroups(),
              _buildDefaultArchiveGroup(context),
              _buildArchiveBotSettings(),
              _buildDownloadConcurrency(),
              _buildSpeedLimit(context),
              _buildDownloadAllGalleriesOfSamePriority(),
              _buildUseJH2UpdateGallery(),
              _buildArchiveDownloadIsolateCount(),
              _buildManageArchiveDownloadConcurrency(),
              _buildDeleteArchiveFileAfterDownload(),
              _buildRestore(),
              _buildRestoreTasksAutomatically(),
            ],
          ).withListTileTheme(context),
        ),
      ),
    );
  }

  Widget _buildDownloadPath() {
    return ListTile(
      title: Text('downloadPath'.tr),
      subtitle: Text(downloadSetting.downloadPath.value.breakWord),
      trailing: changeDownloadPathState == LoadingState.loading
          ? const CupertinoActivityIndicator()
          : null,
      onTap: () {
        if (!GetPlatform.isIOS) {
          toast('changeDownloadPathHint'.tr, isShort: false);
        }
      },
      onLongPress: _handleChangeDownloadPath,
    );
  }

  Widget _buildResetDownloadPath() {
    return ListTile(
      title: Text('resetDownloadPath'.tr),
      subtitle: Text('longPress2Reset'.tr),
      onLongPress: _handleResetDownloadPath,
    );
  }

  Widget _buildMoveDownloads() {
    return ListTile(
      title: Text('moveExistingDownloads'.tr),
      subtitle: Text(
        movingDownloads
            ? '${'movingDownloads'.tr} $movedDownloads/$totalDownloadsToMove'
            : 'moveExistingDownloadsHint'.tr,
      ),
      trailing: movingDownloads
          ? const CupertinoActivityIndicator()
          : const Icon(Icons.drive_file_move_outlined),
      onTap: movingDownloads ? null : _moveDownloads,
    );
  }

  Future<void> _moveDownloads() async {
    setState(() {
      movingDownloads = true;
      movedDownloads = 0;
      totalDownloadsToMove = 0;
    });
    try {
      if (GetPlatform.isAndroid) {
        await requestStoragePermission();
      }
      final result = await downloadRelocationService.moveToCurrentDirectory(
        onProgress: (completed, total) {
          if (!mounted) {
            return;
          }
          setState(() {
            movedDownloads = completed;
            totalDownloadsToMove = total;
          });
        },
      );
      toast(
        'moveDownloadsResult'.trParams({
          'count': '${result.moved}',
          'failed': '${result.failed}',
        }),
      );
    } catch (error, stack) {
      log.error('Move downloads failed', error, stack);
      toast((error is ArgumentError ? 'invalidPath' : 'internalError').tr);
    } finally {
      if (mounted) {
        setState(() => movingDownloads = false);
      }
    }
  }

  Widget _buildExtraGalleryScanPath() {
    return ListTile(
      title: Text('extraGalleryScanPath'.tr),
      subtitle: Text('extraGalleryScanPathHint'.tr),
      trailing: const Icon(Icons.keyboard_arrow_right),
      onTap: () => toRoute(Routes.extraGalleryScanPath),
    );
  }

  Widget _buildSingleImageSavePath() {
    return ListTile(
      title: Text('singleImageSavePath'.tr),
      subtitle: Text(downloadSetting.singleImageSavePath.value.breakWord),
      trailing: GetPlatform.isMacOS
          ? null
          : const Icon(Icons.keyboard_arrow_right),
      onTap: GetPlatform.isMacOS ? null : _handleChangeSingleImageSavePath,
    );
  }

  Widget _buildDownloadOriginalImage() {
    return SwitchListTile(
      title: Text('downloadOriginalImageByDefault'.tr),
      value: downloadSetting.downloadOriginalImageByDefault.value,
      onChanged: (value) {
        if (!userSetting.hasLoggedIn()) {
          toast('needLoginToOperate'.tr);
          return;
        }
        downloadSetting.saveDownloadOriginalImageByDefault(value);
      },
    );
  }

  Widget _buildDefaultGalleryGroup(BuildContext context) {
    return ListTile(
      title: Text('defaultGalleryGroup'.tr),
      subtitle: Text('longPress2Reset'.tr),
      trailing: Text(
        downloadSetting.defaultGalleryGroup.value ?? '',
        style: UIConfig.settingPageListTileTrailingTextStyle(context),
      ),
      onTap: () async {
        ({String group, bool downloadOriginalImage})? result = await showDialog(
          context: context,
          builder: (_) => EHDownloadDialog(
            title: 'chooseGroup'.tr,
            currentGroup: downloadSetting.defaultGalleryGroup.value,
            candidates: galleryDownloadService.allGroups,
          ),
        );

        if (result != null) {
          downloadSetting.saveDefaultGalleryGroup(result.group);
        }
      },
      onLongPress: () {
        downloadSetting.saveDefaultGalleryGroup(null);
      },
    ).marginOnly(right: 12);
  }

  Widget _buildDefaultArchiveGroup(BuildContext context) {
    return ListTile(
      title: Text('defaultArchiveGroup'.tr),
      subtitle: Text('longPress2Reset'.tr),
      trailing: Text(
        downloadSetting.defaultArchiveGroup.value ?? '',
        style: UIConfig.settingPageListTileTrailingTextStyle(context),
      ),
      onTap: () async {
        ({String group, bool downloadOriginalImage})? result = await showDialog(
          context: context,
          builder: (_) => EHDownloadDialog(
            title: 'chooseGroup'.tr,
            currentGroup: downloadSetting.defaultArchiveGroup.value,
            candidates: archiveDownloadService.allGroups,
          ),
        );

        if (result != null) {
          downloadSetting.saveDefaultArchiveGroup(result.group);
        }
      },
      onLongPress: () {
        downloadSetting.saveDefaultArchiveGroup(null);
      },
    ).marginOnly(right: 12);
  }

  Widget _buildPrioritizeRecentGalleryGroups() {
    return SwitchListTile(
      title: Text('prioritizeRecentGalleryGroups'.tr),
      value: downloadSetting.prioritizeRecentGalleryGroups.value,
      onChanged: downloadSetting.savePrioritizeRecentGalleryGroups,
    );
  }

  Widget _buildDownloadConcurrency() {
    return ListTile(
      title: Text('downloadTaskConcurrency'.tr),
      trailing: DropdownButton<int>(
        value: downloadSetting.downloadTaskConcurrency.value,
        elevation: 4,
        onChanged: (int? newValue) =>
            downloadSetting.saveDownloadTaskConcurrency(newValue!),
        items: const [
          DropdownMenuItem(child: Text('2'), value: 2),
          DropdownMenuItem(child: Text('4'), value: 4),
          DropdownMenuItem(child: Text('6'), value: 6),
          DropdownMenuItem(child: Text('8'), value: 8),
          DropdownMenuItem(child: Text('10'), value: 10),
        ],
      ),
    );
  }

  Widget _buildArchiveBotSettings() {
    return ListTile(
      title: Text('archiveBotSettings'.tr),
      subtitle: Text('archiveBotSettingsHint'.tr),
      trailing: const Icon(Icons.keyboard_arrow_right),
      onTap: () => toRoute(Routes.archiveBotSettings),
    );
  }

  Widget _buildSpeedLimit(BuildContext context) {
    return ListTile(
      title: Text('speedLimit'.tr),
      subtitle: Text('speedLimitHint'.tr),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          DropdownButton<int>(
            value: downloadSetting.maximum.value,
            elevation: 4,
            alignment: AlignmentDirectional.bottomEnd,
            onChanged: (int? newValue) {
              downloadSetting.saveMaximum(newValue!);
            },
            items: const [
              DropdownMenuItem(child: Text('1'), value: 1),
              DropdownMenuItem(child: Text('2'), value: 2),
              DropdownMenuItem(child: Text('3'), value: 3),
              DropdownMenuItem(child: Text('5'), value: 5),
              DropdownMenuItem(child: Text('10'), value: 10),
              DropdownMenuItem(child: Text('99'), value: 99),
            ],
          ),
          Text(
            '${'images'.tr} ${'per'.tr}',
            style: UIConfig.settingPageListTileTrailingTextStyle(context),
          ).marginSymmetric(horizontal: 8),
          DropdownButton<Duration>(
            value: downloadSetting.period.value,
            elevation: 4,
            alignment: AlignmentDirectional.bottomEnd,
            onChanged: (Duration? newValue) =>
                downloadSetting.savePeriod(newValue!),
            items: const [
              DropdownMenuItem(child: Text('1s'), value: Duration(seconds: 1)),
              DropdownMenuItem(child: Text('2s'), value: Duration(seconds: 2)),
              DropdownMenuItem(child: Text('3s'), value: Duration(seconds: 3)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadAllGalleriesOfSamePriority() {
    return SwitchListTile(
      title: Text('downloadAllGalleriesOfSamePriority'.tr),
      subtitle: Text(
        '${'downloadAllGalleriesOfSamePriorityHint'.tr} | ${'needRestart'.tr}',
      ),
      value: downloadSetting.downloadAllGalleriesOfSamePriority.value,
      onChanged: downloadSetting.saveDownloadAllGalleriesOfSamePriority,
    );
  }

  Widget _buildUseJH2UpdateGallery() {
    return SwitchListTile(
      title: Text('useJH2UpdateGallery'.tr),
      value: downloadSetting.useJH2UpdateGallery.value,
      onChanged: downloadSetting.saveUseJH2UpdateGallery,
    );
  }

  Widget _buildArchiveDownloadIsolateCount() {
    return ListTile(
      title: Text('archiveDownloadIsolateCount'.tr),
      subtitle: Text('archiveDownloadIsolateCountHint'.tr),
      trailing: DropdownButton<int>(
        value: downloadSetting.archiveDownloadIsolateCount.value,
        elevation: 4,
        onChanged: (int? newValue) =>
            downloadSetting.saveArchiveDownloadIsolateCount(newValue!),
        items: const [
          DropdownMenuItem(child: Text('1'), value: 1),
          DropdownMenuItem(child: Text('2'), value: 2),
          DropdownMenuItem(child: Text('3'), value: 3),
          DropdownMenuItem(child: Text('4'), value: 4),
          DropdownMenuItem(child: Text('5'), value: 5),
          DropdownMenuItem(child: Text('6'), value: 6),
          DropdownMenuItem(child: Text('7'), value: 7),
          DropdownMenuItem(child: Text('8'), value: 8),
          DropdownMenuItem(child: Text('9'), value: 9),
          DropdownMenuItem(child: Text('10'), value: 10),
        ],
      ),
    );
  }

  Widget _buildManageArchiveDownloadConcurrency() {
    return SwitchListTile(
      title: Text('manageArchiveDownloadConcurrency'.tr),
      subtitle: Text('manageArchiveDownloadConcurrencyHint'.tr),
      value: downloadSetting.manageArchiveDownloadConcurrency.value,
      onChanged: downloadSetting.saveManageArchiveDownloadConcurrency,
    );
  }

  Widget _buildDeleteArchiveFileAfterDownload() {
    return SwitchListTile(
      title: Text('deleteArchiveFileAfterDownload'.tr),
      value: downloadSetting.deleteArchiveFileAfterDownload.value,
      onChanged: downloadSetting.saveDeleteArchiveFileAfterDownload,
    );
  }

  Widget _buildRestore() {
    return ListTile(
      title: Text('restoreDownloadTasks'.tr),
      subtitle: Text('restoreDownloadTasksHint'.tr),
      onTap: _restore,
    );
  }

  Widget _buildRestoreTasksAutomatically() {
    return SwitchListTile(
      title: Text('restoreTasksAutomatically'.tr),
      subtitle: Text('restoreTasksAutomaticallyHint'.tr),
      value: downloadSetting.restoreTasksAutomatically.value,
      onChanged: downloadSetting.saveRestoreTasksAutomatically,
    );
  }

  Future<void> _handleChangeDownloadPath({String? newDownloadPath}) async {
    if (changeDownloadPathState == LoadingState.loading) {
      return;
    }

    if (GetPlatform.isIOS) {
      return;
    }

    if (GetPlatform.isAndroid) {
      await requestStoragePermission();
    }

    String oldDownloadPath = downloadSetting.downloadPath.value;

    /// choose new download path
    try {
      newDownloadPath ??= await FilePicker.getDirectoryPath();
    } on Exception catch (e) {
      log.error('Pick download path failed', e);
    }

    if (newDownloadPath == null || newDownloadPath == oldDownloadPath) {
      return;
    }
    if (localContentService.isManagedDirectory(newDownloadPath)) {
      toast('invalidPath'.tr);
      return;
    }

    setState(() => changeDownloadPathState = LoadingState.loading);
    try {
      await io.Directory(newDownloadPath).create(recursive: true);
      await downloadSetting.saveDownloadPath(newDownloadPath);
      await localGalleryService.refreshLocalGalleries();
    } on Exception catch (e, stack) {
      log.error('Change download directory failed', e, stack);
      toast('internalError'.tr);
    } finally {
      if (mounted) {
        setState(() => changeDownloadPathState = LoadingState.idle);
      }
    }
  }

  Future<void> _handleResetDownloadPath() {
    return _handleChangeDownloadPath(
      newDownloadPath: downloadSetting.defaultDownloadPath,
    );
  }

  Future<void> _handleChangeSingleImageSavePath() async {
    String oldPath = downloadSetting.singleImageSavePath.value;
    String? newPath;

    /// choose new path
    try {
      newPath = await FilePicker.getDirectoryPath();
    } on Exception catch (e) {
      log.error('Pick single image save path failed', e);
    }

    if (newPath == null || newPath == oldPath) {
      return;
    }

    /// check permission
    if (!checkPermissionForPath(newPath)) {
      toast('invalidPath'.tr, isShort: false);
      return;
    }

    downloadSetting.saveSingleImageSavePath(newPath);
  }

  Future<void> _restore() async {
    log.info('Restore download task.');

    final before = (await localContentService.standaloneCopies()).length;
    await localContentService.restoreContentDirectories();
    int restoredGalleryCount = await galleryDownloadService.restoreTasks();
    int restoredArchiveCount = await archiveDownloadService.restoreTasks();

    final after = (await localContentService.standaloneCopies()).length;
    final contentCount = after > before ? after - before : 0;
    await localGalleryService.refreshLocalGalleries();
    toast(
      '${'restoredGalleryCount'.tr}: ${restoredGalleryCount + contentCount}\n${'restoredArchiveCount'.tr}: $restoredArchiveCount',
      isShort: false,
    );
  }
}
