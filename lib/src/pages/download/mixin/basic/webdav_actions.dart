import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../cloud/cloud_transfer_sheet.dart';

import '../../../../routes/routes.dart';
import '../../../../service/gallery_sync/gallery_sync_service.dart';
import '../../../../service/log.dart';
import '../../../../setting/preference_setting.dart';
import '../../../../setting/webdav_setting.dart';
import '../../../../utils/route_util.dart';
import '../../../../utils/toast_util.dart';
import '../../../../widget/eh_alert_dialog.dart';

Future<void> queueCloudUploads(
  Iterable<Future<String?> Function()> copies, {
  required bool cleanupAfterUpload,
}) async {
  if (!webDavSetting.isConfigured) {
    await toRoute(Routes.settingWebDav);
    if (!webDavSetting.isConfigured) {
      return;
    }
  }
  if (cleanupAfterUpload &&
      preferenceSetting.confirmDestructiveActions.isTrue) {
    final confirmed = await Get.dialog<bool>(
      EHDialog(
        title: 'cloudUploadAndClean'.tr,
        content: 'cloudUploadAndCleanConfirm'.tr,
      ),
    );
    if (confirmed != true) {
      return;
    }
  }
  var queued = 0;
  var failed = 0;
  for (final copy in copies) {
    try {
      final copyId = await copy();
      if (copyId == null) {
        continue;
      }
      await gallerySyncService.requestUpload(
        copyId,
        cleanupAfterUpload: cleanupAfterUpload,
      );
      queued++;
    } catch (error, stack) {
      log.error('Queue gallery upload failed', error, stack);
      failed++;
    }
  }
  final message = failed > 0
      ? 'cloudQueuePartialFailure'.trParams({
          'count': '$queued',
          'failed': '$failed',
        })
      : queued == 0
      ? 'cloudNoCompleted'.tr
      : 'cloudQueuedFeedback'.trParams({'count': '$queued'});
  if (queued == 0) {
    toast(message);
    return;
  }
  final context = Get.context!;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 5),
      action: SnackBarAction(
        label: 'cloudViewTransfers'.tr,
        onPressed: () => showCloudTransfers(context),
      ),
      persist: false,
    ),
  );
}
