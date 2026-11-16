part of 'gallery_sync_service.dart';

class CloudGalleryStatisticsEntry {
  final PortableManifest manifest;
  final int rawBytes;
  final int storedBytes;

  CloudGalleryStatisticsEntry(this.manifest)
    : rawBytes = manifest.pages.fold(0, (sum, page) => sum + page.rawLength),
      storedBytes = manifest.pages.fold(
        0,
        (sum, page) => sum + page.storedLength,
      );

  double? get compressionRatio =>
      rawBytes == 0 ? null : 1 - storedBytes / rawBytes;
}

/// A snapshot of published image references in one connection's local index.
class CloudGalleryStatistics {
  final String host;
  final List<CloudGalleryStatisticsEntry> entries;
  final int familyCount;
  final int gidCount;
  final int multiVersionFamilyCount;
  final int pageCount;
  final int rawBytes;
  final int storedBytes;
  final int uniqueObjectCount;
  final int uniqueStoredBytes;
  final DateTime? indexedAt;
  final bool indexComplete;
  final bool indexing;
  final String? refreshError;

  CloudGalleryStatistics({
    required this.host,
    required List<PortableManifest> manifests,
    this.indexedAt,
    this.indexComplete = false,
    this.indexing = false,
    this.refreshError,
  }) : entries = List.unmodifiable(
         manifests.map(CloudGalleryStatisticsEntry.new),
       ),
       familyCount = _familyGids(manifests).length,
       gidCount = manifests.map((item) => item.gid).toSet().length,
       multiVersionFamilyCount = _familyGids(manifests).values
           .where((gids) => gids.length > 1)
           .length,
       pageCount = manifests.fold(0, (sum, item) => sum + item.pages.length),
       rawBytes = manifests.fold(
         0,
         (sum, item) =>
             sum + item.pages.fold<int>(0, (n, page) => n + page.rawLength),
       ),
       storedBytes = manifests.fold(
         0,
         (sum, item) =>
             sum + item.pages.fold<int>(0, (n, page) => n + page.storedLength),
       ),
       uniqueObjectCount = _objects(manifests).length,
       uniqueStoredBytes = _objects(manifests).values
           .fold(0, (sum, size) => sum + size);

  double? get compressionRatio =>
      rawBytes == 0 ? null : 1 - storedBytes / rawBytes;
  int get reusedStoredBytes => storedBytes - uniqueStoredBytes;

  static Map<int, Set<int>> _familyGids(List<PortableManifest> manifests) {
    final families = _GalleryFamilyIndex(manifests);
    final result = <int, Set<int>>{};
    for (final manifest in manifests) {
      (result[families.find(manifest.gid)] ??= {}).add(manifest.gid);
    }
    return result;
  }

  static Map<String, int> _objects(List<PortableManifest> manifests) {
    final result = <String, int>{};
    for (final manifest in manifests) {
      for (final page in manifest.pages) {
        result.putIfAbsent(page.objectHash, () => page.storedLength);
      }
    }
    return result;
  }
}

extension GallerySyncStatistics on GallerySyncService {
  Future<CloudGalleryStatistics> statistics() async {
    final connection = _connection();
    final heads = await _catalogHeads(namespace: connection.namespace);
    final status = await repository.db
        .customSelect(
          """
      SELECT scan_state, scanned_at,
        EXISTS (SELECT 1 FROM content_remote_partition
          WHERE target_namespace = ? AND partition != '__root__'
            AND scan_state = 'partial') AS partial,
        EXISTS (SELECT 1 FROM content_remote_resource r
          LEFT JOIN content_manifest m ON m.target_namespace = r.target_namespace
            AND m.manifest_id = r.object_hash
          WHERE r.target_namespace = ? AND r.kind = 'manifest'
            AND r.object_hash IS NOT NULL AND m.manifest_id IS NULL) AS unimported
      FROM content_remote_partition
      WHERE target_namespace = ? AND partition = '__root__'
    """,
          variables: [
            for (var i = 0; i < 3; i++)
              Variable.withString(connection.namespace),
          ],
        )
        .getSingleOrNull();
    final scannedAt = status?.readNullable<String>('scanned_at');
    return CloudGalleryStatistics(
      host: connection.address.host,
      manifests: heads.map((head) => head.manifest).toList(),
      indexedAt: scannedAt == null ? null : DateTime.parse(scannedAt),
      indexComplete:
          status != null &&
          status.read<String>('scan_state') == 'complete' &&
          status.read<int>('partial') == 0 &&
          status.read<int>('unimported') == 0,
      indexing: scanning,
      refreshError: lastError,
    );
  }
}

/// Shared by browsing and statistics, including relations through absent GIDs.
class _GalleryFamilyIndex {
  final _parent = <int, int>{};
  final supersededGids = <int>{};

  _GalleryFamilyIndex(Iterable<PortableManifest> manifests) {
    for (final manifest in manifests) {
      for (final edge in manifest.lineage) {
        final a = find(edge.fromGid);
        final b = find(edge.toGid);
        if (a != b) _parent[a] = b;
        supersededGids.add(edge.fromGid);
      }
    }
  }

  int find(int gid) {
    final parent = _parent.putIfAbsent(gid, () => gid);
    return parent == gid ? gid : _parent[gid] = find(parent);
  }
}
