part of 'local_content_service.dart';

extension LocalContentPublishedMetadata on LocalContentService {
  /// Called inside the manifest publication transaction. Only owners already
  /// associated with this target and these exact ordered pages receive edits.
  Future<List<String>> applyPublishedMetadataRevision({
    required String targetNamespace,
    required PortableManifest manifest,
    required Map<String, dynamic> patch,
  }) async {
    if (patch.isEmpty) return [];
    final rows = await repository.db
        .customSelect(
          '''
      SELECT c.copy_id, c.metadata_json FROM content_copy c
      WHERE c.lifecycle = 'active' AND c.gid = ? AND c.representation = ?
        AND c.metadata_json IS NOT NULL AND (
          c.library_namespace = ? OR EXISTS (
            SELECT 1 FROM content_work_item w WHERE w.copy_id = c.copy_id
              AND w.target_namespace = ? AND w.kind IN ('content', 'revision')
              AND w.state = 'completed' AND w.pending_manifest_id IS NOT NULL))
    ''',
          variables: [
            Variable.withInt(manifest.gid),
            Variable.withString(manifest.representation),
            Variable.withString(targetNamespace),
            Variable.withString(targetNamespace),
          ],
        )
        .get();
    final changed = <String>[];
    for (final row in rows) {
      final copyId = row.read<String>('copy_id');
      final input = await completedInput(copyId);
      if (input == null || input.pages.length != manifest.pages.length)
        continue;
      if (List.generate(input.pages.length, (i) => i).any(
        (i) =>
            input.pages[i].rawHash != manifest.pages[i].rawHash ||
            input.pages[i].rawLength != manifest.pages[i].rawLength,
      ))
        continue;
      final metadata =
          jsonDecode(row.read<String>('metadata_json')) as Map<String, dynamic>;
      final previous = jsonEncode(metadata);
      for (final field in ['title', 'tags', 'collections']) {
        if (patch.containsKey(field)) metadata[field] = patch[field];
      }
      if (patch['providerMetadata'] case final Map provider) {
        metadata['providerMetadata'] = {
          ...?(metadata['providerMetadata'] as Map?),
          ...provider,
        };
      }
      final lineage = <String, dynamic>{
        for (final edge in metadata['lineage'] as List? ?? const [])
          jsonEncode(edge): edge,
      };
      if (patch['sourceParentGid'] case final int gid) {
        lineage.removeWhere(
          (_, edge) =>
              edge[2] == 'source_parent' && (edge[0] == gid || edge[1] == gid),
        );
      }
      for (final edge in patch['lineageRemoved'] as List? ?? const []) {
        lineage.remove(jsonEncode(edge));
      }
      for (final edge in patch['lineageAdded'] as List? ?? const []) {
        lineage[jsonEncode(edge)] = edge;
      }
      if (patch.containsKey('sourceParentGid') ||
          patch.containsKey('lineageAdded') ||
          patch.containsKey('lineageRemoved')) {
        metadata['lineage'] = lineage.values.toList();
      }
      if (jsonEncode(metadata) == previous) continue;
      await _storeMetadata(copyId, metadata);
      changed.add(copyId);
    }
    return changed;
  }

  /// Projection and scheduler events follow the committed metadata transaction.
  Future<void> finishPublishedMetadataRevision(List<String> copyIds) async {
    for (final copyId in copyIds) {
      try {
        await rebuildProjection(copyId);
      } catch (error, stack) {
        log.error(
          'Published metadata projection update deferred',
          error,
          stack,
        );
      }
      try {
        final input = await completedInput(copyId);
        if (input != null) await onCompleted?.call(input);
      } catch (error, stack) {
        log.error('Published metadata scheduling deferred', error, stack);
      }
    }
  }
}
