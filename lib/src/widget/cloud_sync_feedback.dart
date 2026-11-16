import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../pages/download/download_base_page.dart';
import '../routes/routes.dart';
import '../service/gallery_sync/gallery_sync_service.dart';

/// One foreground notice, updated while consecutive handoffs complete.
class CloudSyncFeedback extends StatefulWidget {
  final Widget child;
  const CloudSyncFeedback({super.key, required this.child});

  @override
  State<CloudSyncFeedback> createState() => _CloudSyncFeedbackState();
}

class _CloudSyncFeedbackState extends State<CloudSyncFeedback> {
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _notice;
  int _count = 0;

  @override
  void initState() {
    super.initState();
    gallerySyncService.onHandoffCompleted = _completed;
  }

  @override
  void dispose() {
    if (gallerySyncService.onHandoffCompleted == _completed) {
      gallerySyncService.onHandoffCompleted = null;
    }
    super.dispose();
  }

  void _completed(String title) {
    final messenger = ScaffoldMessenger.of(context);
    _count++;
    messenger.removeCurrentSnackBar();
    final notice = messenger.showSnackBar(
      SnackBar(
        content: Text(
          _count == 1
              ? 'cloudSyncedOne'.trParams({'title': title})
              : 'cloudSyncedCount'.trParams({'count': '$_count'}),
        ),
        action: SnackBarAction(
          label: 'cloudOpen'.tr,
          onPressed: () {
            Get.toNamed(
              Routes.download,
              arguments: DownloadPageGalleryType.cloud,
              preventDuplicates: false,
            );
          },
        ),
        persist: false,
      ),
    );
    _notice = notice;
    notice.closed.then((_) {
      if (_notice == notice) {
        _notice = null;
        _count = 0;
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
