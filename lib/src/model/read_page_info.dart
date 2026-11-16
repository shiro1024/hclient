import 'gallery_image.dart';

import '../setting/read_setting.dart';

enum ReadMode { downloaded, online, archive, local }

class ReadPageInfo {
  ReadMode mode;

  /// null for local gallery
  int? gid;

  /// null for local gallery
  String? token;

  String galleryTitle;

  String? galleryUrl;

  /// Stable local-content identity, independent of download and archive tasks.
  String? contentCopyId;

  String? representation;

  int initialIndex;

  int currentImageIndex;

  int pageCount;

  /// used for archive
  bool isOriginal;

  String readProgressRecordStorageKey;

  /// used for archive&local
  List<GalleryImage>? images;

  ReadDirection? readDirection;

  ReadPageInfo({
    required this.mode,
    this.gid,
    this.token,
    required this.galleryTitle,
    this.galleryUrl,
    this.contentCopyId,
    this.representation,
    required this.initialIndex,
    required this.pageCount,
    this.isOriginal = false,
    required this.readProgressRecordStorageKey,
    this.images,
    this.readDirection,
  }) : currentImageIndex = initialIndex;
}
