import 'dart:convert';
import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:extended_image/extended_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/service/cloud_service.dart';
import 'package:jhentai/src/setting/advanced_setting.dart';
import 'package:jhentai/src/service/path_service.dart';
import 'package:jhentai/src/service/log.dart';
import 'package:jhentai/src/utils/toast_util.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';
import 'package:path/path.dart';

import '../../../config/ui_config.dart';
import '../../../routes/routes.dart';
import '../../../utils/byte_util.dart';
import '../../../utils/route_util.dart';
import '../../../widget/eh_local_backup_select_dialog.dart';
import '../../../service/local_backup_service.dart';

class SettingAdvancedPage extends StatefulWidget {
  const SettingAdvancedPage({Key? key}) : super(key: key);

  @override
  _SettingAdvancedPageState createState() => _SettingAdvancedPageState();
}

class _SettingAdvancedPageState extends State<SettingAdvancedPage> {
  LoadingState _logLoadingState = LoadingState.idle;
  String _logSize = '...';

  LoadingState _imageCacheLoadingState = LoadingState.idle;
  String _imageCacheSize = '...';

  LoadingState _exportDataLoadingState = LoadingState.idle;
  LoadingState _importDataLoadingState = LoadingState.idle;

  @override
  void initState() {
    super.initState();

    _loadingLogSize();
    _getImagesCacheSize();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: Text('advancedSetting'.tr)),
      body: Obx(
        () => ListView(
          padding: const EdgeInsets.only(top: 16),
          children: [
            _buildEnableLogging(),
            if (advancedSetting.enableLogging.isTrue) _buildRecordAllLogs().fadeIn(),
            _buildOpenLogs(),
            _buildClearLogs(context),
            _buildClearImageCache(context),
            _buildClearNetworkCache(),
            _buildCheckClipboard(),
            if (GetPlatform.isAndroid) _buildVerifyAppLinks(),
            if (GetPlatform.isAndroid) _buildRefreshRate(),
            _buildInNoImageMode(),
            _buildImportData(context),
            _buildExportData(context),
          ],
        ).withListTileTheme(context),
      ),
    );
  }

  Widget _buildEnableLogging() {
    return ListTile(
      title: Text('enableLogging'.tr),
      subtitle: Text('needRestart'.tr),
      trailing: Switch(value: advancedSetting.enableLogging.value, onChanged: advancedSetting.saveEnableLogging),
    );
  }

  Widget _buildRecordAllLogs() {
    return SwitchListTile(
      title: Text('enableVerboseLogging'.tr),
      subtitle: Text('needRestart'.tr),
      value: advancedSetting.enableVerboseLogging.value,
      onChanged: advancedSetting.saveEnableVerboseLogging,
    );
  }

  Widget _buildOpenLogs() {
    return ListTile(
      title: Text('openLog'.tr),
      trailing: const Icon(Icons.keyboard_arrow_right).marginOnly(right: 4),
      onTap: () => toRoute(Routes.logList),
    );
  }

  Widget _buildClearLogs(BuildContext context) {
    return ListTile(
      title: Text('clearLogs'.tr),
      subtitle: Text('longPress2Clear'.tr),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          LoadingStateIndicator(
            loadingState: _logLoadingState,
            useCupertinoIndicator: true,
            successWidgetBuilder: () => Text(
              _logSize,
              style: TextStyle(color: UIConfig.resumePauseButtonColor(context), fontWeight: FontWeight.w500),
            ),
            errorTapCallback: _loadingLogSize,
          ).marginOnly(right: 8),
        ],
      ),
      onLongPress: _clearAndLoadingLogSize,
    );
  }

  Widget _buildClearImageCache(BuildContext context) {
    return ListTile(
      title: Text('clearImagesCache'.tr),
      subtitle: Text('longPress2Clear'.tr),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          LoadingStateIndicator(
            loadingState: _imageCacheLoadingState,
            useCupertinoIndicator: true,
            successWidgetBuilder: () => Text(
              _imageCacheSize,
              style: TextStyle(color: UIConfig.resumePauseButtonColor(context), fontWeight: FontWeight.w500),
            ),
            errorTapCallback: _getImagesCacheSize,
          ).marginOnly(right: 8),
        ],
      ),
      onLongPress: _clearAndLoadingImageCacheSize,
    );
  }

  Widget _buildClearNetworkCache() {
    return ListTile(
      title: Text('clearPageCache'.tr),
      subtitle: Text('longPress2Clear'.tr),
      onLongPress: () async {
        await ehRequest.removeAllCache();
        toast('clearSuccess'.tr, isCenter: false);
      },
    );
  }

  Widget _buildCheckClipboard() {
    return SwitchListTile(
      title: Text('checkClipboard'.tr),
      value: advancedSetting.enableCheckClipboard.value,
      onChanged: advancedSetting.saveEnableCheckClipboard,
    );
  }

  Widget _buildVerifyAppLinks() {
    return ListTile(
      title: Text('verityAppLinks4Android12'.tr),
      subtitle: Text('verityAppLinks4Android12Hint'.tr),
      trailing: const Icon(Icons.keyboard_arrow_right).marginOnly(right: 4),
      onTap: () async {
        try {
          await const AndroidIntent(action: 'android.settings.APP_OPEN_BY_DEFAULT_SETTINGS', data: 'package:shiro.hclient').launch();
        } on Exception catch (e) {
          log.error(e);
          log.uploadError(e);
          toast('error'.tr);
        }
      },
    );
  }

  Widget _buildRefreshRate() {
    return ListTile(
      title: Text('refreshRate'.tr),
      trailing: const Icon(Icons.keyboard_arrow_right).marginOnly(right: 4),
      onTap: () => toRoute(Routes.settingFrameRate),
    );
  }

  Widget _buildInNoImageMode() {
    return SwitchListTile(
      title: Text('noImageMode'.tr),
      value: advancedSetting.inNoImageMode.value,
      onChanged: advancedSetting.saveInNoImageMode,
    );
  }

  Widget _buildImportData(BuildContext context) {
    return ListTile(
      title: Text('importData'.tr),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          LoadingStateIndicator(
            loadingState: _importDataLoadingState,
            idleWidgetBuilder: () => const Icon(Icons.keyboard_arrow_right),
            successWidgetSameWithIdle: true,
            useCupertinoIndicator: true,
            errorWidgetSameWithIdle: true,
          ).marginOnly(right: 8),
        ],
      ),
      onTap: () => _importData(context),
    );
  }

  Widget _buildExportData(BuildContext context) {
    return ListTile(
      title: Text('exportData'.tr),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          LoadingStateIndicator(
            loadingState: _exportDataLoadingState,
            idleWidgetBuilder: () => const Icon(Icons.keyboard_arrow_right),
            successWidgetSameWithIdle: true,
            useCupertinoIndicator: true,
            errorWidgetSameWithIdle: true,
          ).marginOnly(right: 8),
        ],
      ),
      onTap: () => _exportData(context),
    );
  }

  Future<void> _loadingLogSize() async {
    if (_logLoadingState == LoadingState.loading) {
      return;
    }

    setStateSafely(() => _logLoadingState = LoadingState.loading);

    try {
      _logSize = await log.getSize();
    } catch (e) {
      log.error('loading log size error', e);
      _logSize = '-1B';
      setStateSafely(() => _imageCacheLoadingState = LoadingState.error);
      return;
    }

    setStateSafely(() => _logLoadingState = LoadingState.success);
  }

  Future<void> _clearAndLoadingLogSize() async {
    if (_logLoadingState == LoadingState.loading) {
      return;
    }

    await log.clear();
    await _loadingLogSize();

    toast('clearSuccess'.tr, isCenter: false);
  }

  Future<void> _getImagesCacheSize() async {
    if (_imageCacheLoadingState == LoadingState.loading) {
      return;
    }

    setStateSafely(() => _imageCacheLoadingState = LoadingState.loading);

    try {
      _imageCacheSize = await compute((dirPath) {
        Directory cacheImagesDirectory = Directory(dirPath);

        int totalBytes;
        if (!cacheImagesDirectory.existsSync()) {
          totalBytes = 0;
        } else {
          totalBytes = cacheImagesDirectory.listSync().fold<int>(
            0,
            (previousValue, element) => previousValue += (element as File).lengthSync(),
          );
        }

        return byte2String(totalBytes.toDouble());
      }, join(pathService.tempDir.path, cacheImageFolderName));
    } catch (e) {
      log.error(e);
      _imageCacheSize = '-1B';
      setStateSafely(() => _imageCacheLoadingState = LoadingState.error);
      return;
    }

    setStateSafely(() => _imageCacheLoadingState = LoadingState.success);
  }

  Future<void> _clearAndLoadingImageCacheSize() async {
    if (_imageCacheLoadingState == LoadingState.loading) {
      return;
    }

    await clearDiskCachedImages();
    await _getImagesCacheSize();

    toast('clearSuccess'.tr, isCenter: false);
  }

  Future<void> _importData(BuildContext context) async {
    if (_importDataLoadingState == LoadingState.loading) return;
    try {
      final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['json']);
      if (file == null) return;
      setStateSafely(() => _importDataLoadingState = LoadingState.loading);
      final contents = utf8.decode(await file.readAsBytes());
      final available = localBackupService.availableSelection(contents);
      if (!mounted) return;
      final selection = await showDialog<LocalBackupSelection>(
        context: context,
        builder: (_) => EHLocalBackupSelectDialog(available: available, restore: true),
      );
      if (selection == null || selection.isEmpty) {
        setStateSafely(() => _importDataLoadingState = LoadingState.idle);
        return;
      }
      final result = await localBackupService.import(contents, selection: selection);
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text((result.needsRestart ? 'needRestart' : 'success').tr),
            content: Text(
              (result.legacy
                      ? 'legacyBackupHint'
                      : result.needsRestart
                      ? 'backupRestartHint'
                      : 'success')
                  .tr,
            ),
            actions: [
              if (result.needsRestart && GetPlatform.isAndroid)
                TextButton(onPressed: SystemNavigator.pop, child: Text('closeAppForRestore'.tr))
              else
                TextButton(onPressed: () => Navigator.pop(context), child: Text('OK'.tr)),
            ],
          ),
        );
      }
      setStateSafely(() => _importDataLoadingState = LoadingState.success);
    } catch (e, stack) {
      log.error('Import data failed (${e.runtimeType})', null, stack);
      toast('internalError'.tr);
      setStateSafely(() => _importDataLoadingState = LoadingState.error);
    }
  }

  Future<void> _exportData(BuildContext context) async {
    LocalBackupSelection? result = await showDialog<LocalBackupSelection>(
      context: context,
      builder: (_) => const EHLocalBackupSelectDialog(),
    );
    if (result?.isEmpty ?? true) {
      return;
    }

    String fileName = '${CloudConfigService.configFileName}-${DateFormat('yyyyMMddHHmmss').format(DateTime.now())}.json';
    return _exportSelectedConfig(fileName, result!);
  }

  Future<void> _exportSelectedConfig(String fileName, LocalBackupSelection selection) async {
    if (_exportDataLoadingState == LoadingState.loading) return;
    setStateSafely(() => _exportDataLoadingState = LoadingState.loading);
    try {
      final contents = await localBackupService.export(selection);
      final savedUri = await FilePicker.saveFile(
        fileName: fileName,
        bytes: utf8.encode(contents),
        mimeType: 'application/json',
        windowsOptions: const WindowsOptions(lockParentWindow: true),
      );
      if (savedUri == null) {
        setStateSafely(() => _exportDataLoadingState = LoadingState.idle);
        return;
      }
      toast('success'.tr);
      setStateSafely(() => _exportDataLoadingState = LoadingState.success);
    } catch (e, stack) {
      log.error('Export data failed (${e.runtimeType})', null, stack);
      toast('internalError'.tr);
      setStateSafely(() => _exportDataLoadingState = LoadingState.error);
    }
  }
}
