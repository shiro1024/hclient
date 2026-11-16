import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/pages/download/mixin/basic/multi_select/multi_select_download_page_mixin.dart';

import '../../../../mixin/scroll_to_top_logic_mixin.dart';
import '../../../../mixin/scroll_to_top_page_mixin.dart';
import '../../../../mixin/scroll_to_top_state_mixin.dart';
import '../basic/multi_select/multi_select_download_page_logic_mixin.dart';
import '../basic/multi_select/multi_select_download_page_state_mixin.dart';
import 'archive_download_page_logic_mixin.dart';
import 'archive_download_page_state_mixin.dart';

mixin ArchiveDownloadPageMixin on StatelessWidget
    implements Scroll2TopPageMixin, MultiSelectDownloadPageMixin {
  ArchiveDownloadPageLogicMixin get archiveDownloadPageLogic;

  ArchiveDownloadPageStateMixin get archiveDownloadPageState;

  @override
  Scroll2TopLogicMixin get scroll2TopLogic => archiveDownloadPageLogic;

  @override
  Scroll2TopStateMixin get scroll2TopState => archiveDownloadPageState;

  @override
  MultiSelectDownloadPageLogicMixin get multiSelectDownloadPageLogic =>
      archiveDownloadPageLogic;

  @override
  MultiSelectDownloadPageStateMixin get multiSelectDownloadPageState =>
      archiveDownloadPageState;

  @override
  List<Widget> buildBottomAppBarButtons() {
    return [
      IconButton(
        icon: const Icon(Icons.done_all),
        onPressed: archiveDownloadPageLogic.selectAllItem,
      ),
      IconButton(
        icon: const Icon(Icons.play_arrow),
        onPressed: archiveDownloadPageLogic.handleMultiResumeTasks,
      ),
      IconButton(
        icon: const Icon(Icons.pause),
        onPressed: archiveDownloadPageLogic.handleMultiPauseTasks,
      ),
      PopupMenuButton<String>(
        icon: const Icon(Icons.more_horiz),
        onSelected: (action) {
          switch (action) {
            case 'group':
              archiveDownloadPageLogic.handleMultiChangeGroup();
            case 'upload':
              archiveDownloadPageLogic.handleMultiCloudUpload();
            case 'cleanup':
              archiveDownloadPageLogic.handleMultiCloudUpload(cleanup: true);
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem(value: 'group', child: Text('changeGroup'.tr)),
          PopupMenuItem(value: 'upload', child: Text('cloudUpload'.tr)),
          PopupMenuItem(
            value: 'cleanup',
            child: Text('cloudUploadAndClean'.tr),
          ),
        ],
      ),
      IconButton(
        icon: const Icon(Icons.delete),
        onPressed: archiveDownloadPageLogic.handleMultiDelete,
      ),
      IconButton(
        icon: const Icon(Icons.smart_toy_outlined),
        onPressed: archiveDownloadPageLogic.handleChangeParseSource,
      ),
      const Expanded(child: SizedBox()),
      IconButton(
        icon: const Icon(Icons.close),
        onPressed: multiSelectDownloadPageLogic.exitSelectMode,
      ),
    ];
  }
}
