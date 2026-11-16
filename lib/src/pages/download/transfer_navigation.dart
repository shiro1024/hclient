import 'download_base_page.dart';

/// Internal notification destination; not a network deep-link protocol.
class TransferDownloadNavigation {
  final DownloadPageGalleryType galleryType;
  final bool showCloudTransfers;
  const TransferDownloadNavigation(
    this.galleryType, {
    this.showCloudTransfers = false,
  });
}
