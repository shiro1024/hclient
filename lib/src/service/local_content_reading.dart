part of 'local_content_service.dart';

final _pageDisplayReads =
    Expando<Map<(String, int, String?), Future<Uint8List>>>();

extension LocalContentReading on LocalContentService {
  /// Coalesces only in-flight reads. Flutter's ImageCache owns decoded pixels;
  /// the owner retains no completed display-image byte cache.
  Future<Uint8List> readPageForDisplay(String copyId, int ordinal) {
    final rawHash = managedPageForIdentitySync(copyId, ordinal)?.rawHash;
    // An unindexed or incomplete page has no stable cache identity yet.
    if (rawHash == null) return _readResidentPageForDisplay(copyId, ordinal);
    final reads = _pageDisplayReads[this] ??= {};
    final key = (copyId, ordinal, rawHash);
    final pending = reads[key];
    if (pending != null) return pending;
    late final Future<Uint8List> future;
    future = (() async {
      try {
        return await _readResidentPageForDisplay(copyId, ordinal);
      } finally {
        if (identical(reads[key], future)) reads.remove(key);
      }
    })();
    reads[key] = future;
    return future;
  }

  Future<Uint8List> _readResidentPageForDisplay(String copyId, int ordinal) =>
      withResidentPageInput(copyId, ordinal, (file, page) {
        if (page.codecProfile == null ||
            page.codecProfile == ContentCodec.rawProfile) {
          return file.readAsBytes();
        }
        return ContentCodec().decodeImageForDisplay(
          inputPath: file.path,
          codecProfile: page.codecProfile!,
        );
      });

  Future<Uint8List> _decodeResidentOriginal(File file, ContentPageRecord page) {
    if (page.codecProfile == null ||
        page.codecProfile == ContentCodec.rawProfile) {
      return file.readAsBytes();
    }
    return ContentCodec().decodeBytes(
      inputPath: file.path,
      codecProfile: page.codecProfile!,
      expectedRawHash: page.rawHash!,
      expectedRawLength: page.rawLength!,
    );
  }

  /// Keeps exported bytes and the MIME-derived name in one page snapshot.
  Future<({Uint8List bytes, String name})> readPageForExport(
    String copyId,
    int ordinal,
  ) => withResidentPageInput(
    copyId,
    ordinal,
    (file, page) async => (
      bytes: await _decodeResidentOriginal(file, page),
      name: _pageExportName(page),
    ),
  );

  /// Exports independently owned original image bytes at the destination.
  Future<File> exportPageToFile(
    String copyId,
    int ordinal,
    String destinationPath,
  ) async {
    final exported = await readPageForExport(copyId, ordinal);
    final destination = File(destinationPath);
    await destination.parent.create(recursive: true);
    return destination.writeAsBytes(exported.bytes);
  }

  /// The original MIME controls external file names even when residency is PCF.
  Future<String> pageExportName(String copyId, int ordinal) async {
    return _pageExportName(await repository.getPage(copyId, ordinal));
  }

  String _pageExportName(ContentPageRecord page) {
    final extension = switch (page.mime) {
      'image/jpeg' => '.jpg',
      'image/png' => '.png',
      'image/gif' => '.gif',
      'image/webp' => '.webp',
      'image/avif' => '.avif',
      'image/bmp' => '.bmp',
      'image/tiff' => '.tiff',
      'image/jxl' => '.jxl',
      'image/heic' => '.heic',
      'image/heif' => '.heif',
      'image/x-icon' || 'image/vnd.microsoft.icon' => '.ico',
      _ => path.extension(page.relativePath),
    };
    final residentName = path.basename(page.relativePath);
    final imageName = residentName.endsWith('.pcf')
        ? residentName.substring(0, residentName.length - 4)
        : residentName;
    return '${path.basenameWithoutExtension(imageName)}$extension';
  }
}
