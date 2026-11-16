import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/mixin/scroll_status_listener_state.dart';
import 'package:jhentai/src/model/read_page_info.dart';
import 'package:jhentai/src/setting/site_setting.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../model/gallery_image.dart';
import '../../model/gallery_thumbnail.dart';
import '../../model/image_source_info.dart';
import '../../service/gallery_download/gallery_download_service.dart';
import '../../service/local_content_service.dart';
import '../../service/gallery_download/download_path_resolver.dart';
import '../../setting/read_setting.dart';
import '../../widget/loading_state_indicator.dart';

class ReadPageState with ScrollStatusListerState {
  /// gallery info
  final ReadPageInfo readPageInfo = Get.arguments;

  /// property used for parsing and loading
  int thumbnailsCountPerPage = SiteSetting.thumbnailsCountPerPage.value;
  late List<GalleryThumbnail?> thumbnails;

  late List<GalleryImage?> _images;
  GalleryDownloadInfo? _downloadInput;

  /// An incomplete session follows its original task's resident list. Once all
  /// pages have owner identities, keep a stable snapshot through task handoff.
  List<GalleryImage?> get images {
    if (readPageInfo.mode == ReadMode.downloaded) {
      final resident = _downloadInput?.images;
      if (resident != null) _images = resident;
      if (identical(
            galleryDownloadService.galleryDownloadInfos[readPageInfo.gid],
            _downloadInput,
          ) &&
          _downloadInput?.downloadProgress.downloadStatus !=
              DownloadStatus.downloaded)
        return _images;
      final managed = <GalleryImage>[];
      for (final image in _images) {
        if (image == null || image.downloadStatus != DownloadStatus.downloaded)
          return _images;
        final identity =
            image.managedPage ??
            (image.path == null
                ? null
                : localContentService.managedPageForPathSync(
                    DownloadPathResolver.computeImageDownloadAbsolutePathFromRelativePath(
                      image.path!,
                    ),
                  ));
        if (identity == null) return _images;
        managed.add(image.copyWith(managedPage: identity));
      }
      if (managed.isNotEmpty &&
          managed.every(
            (image) =>
                image.managedPage!.copyId == managed.first.managedPage!.copyId,
          )) {
        _images = managed;
        readPageInfo.contentCopyId = managed.first.managedPage!.copyId;
        readPageInfo.representation =
            _downloadInput?.downloadOriginalImage == true
            ? 'original'
            : 'resampled';
        readPageInfo.isOriginal = readPageInfo.representation == 'original';
        readPageInfo.images = managed;
        readPageInfo.mode = ReadMode.local;
        _downloadInput = null;
      }
    }
    return _images;
  }

  set images(List<GalleryImage?> value) => _images = value;

  late List<LoadingState> parseImageHrefsStates;
  late List<LoadingState> parseImageUrlStates;
  late List<Size?> imageContainerSizes;
  final Map<int, ImageSourceInfo> imageSourceInfos = {};
  String? parseImageHrefErrorMsg;
  late List<String?> parseImageUrlErrorMsg;

  bool autoMode = false;
  bool isMenuOpen = false;
  bool showTapZoneGuide = false;
  Battery battery = Battery();
  int batteryLevel = 100;
  bool displayFirstPageAlone = readSetting.displayFirstPageAlone.value;
  FocusNode focusNode = FocusNode();

  late Size displayRegionSize;

  final ItemPositionsListener thumbnailPositionsListener =
      ItemPositionsListener.create();
  final ItemScrollController thumbnailsScrollController =
      ItemScrollController();
  final ScrollOffsetController thumbnailsScrollOffsetController =
      ScrollOffsetController();

  ReadPageState() {
    thumbnails = List.generate(
      readPageInfo.pageCount,
      (_) => null,
      growable: true,
    );

    if (readPageInfo.mode == ReadMode.online) {
      _images = List.generate(readPageInfo.pageCount, (_) => null);
    }

    if (readPageInfo.mode == ReadMode.downloaded) {
      _downloadInput =
          galleryDownloadService.galleryDownloadInfos[readPageInfo.gid];
      _images =
          _downloadInput?.images ??
          List.generate(readPageInfo.pageCount, (_) => null);
    }

    if (readPageInfo.mode == ReadMode.archive ||
        readPageInfo.mode == ReadMode.local) {
      _images = readPageInfo.images!.cast<GalleryImage?>();
    }

    parseImageHrefsStates = List.generate(
      readPageInfo.pageCount,
      (_) => LoadingState.idle,
    );
    parseImageUrlStates = List.generate(
      readPageInfo.pageCount,
      (_) => LoadingState.idle,
    );
    imageContainerSizes = List.generate(readPageInfo.pageCount, (_) => null);
    parseImageUrlErrorMsg = List.generate(readPageInfo.pageCount, (_) => null);
    parseImageUrlErrorMsg = List.generate(readPageInfo.pageCount, (_) => null);
  }
}
