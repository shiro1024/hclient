import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;

import '../../database/database.dart';
import 'portable_manifest.dart';

class ManifestHeadGroup {
  final PortableManifest representative;
  final List<String> manifestIds;
  const ManifestHeadGroup(this.representative, this.manifestIds);
}

class ObjectRepresentationRecord {
  final String rawHash;
  final String objectHash;
  final String codecProfile;
  final int storedLength;
  const ObjectRepresentationRecord(
    this.rawHash,
    this.objectHash,
    this.codecProfile,
    this.storedLength,
  );
}

class ContentPageRecord {
  final String copyId;
  final int ordinal;
  final String relativePath;
  final String? rawHash;
  final int? rawLength;
  final String? mime;
  final int? width;
  final int? height;
  final String state;
  final String? sourcePageUrl;
  final String? codecProfile;
  final String? objectHash;
  final int? storedLength;

  const ContentPageRecord({
    required this.copyId,
    required this.ordinal,
    required this.relativePath,
    required this.rawHash,
    required this.rawLength,
    required this.mime,
    required this.width,
    required this.height,
    required this.state,
    this.sourcePageUrl,
    this.codecProfile,
    this.objectHash,
    this.storedLength,
  });
}

class PageReplacementRecord {
  final String replacementId;
  final String copyId;
  final int ordinal;
  final int queueOrder;
  final String state;
  final String oldPath;
  final String newPath;
  final String tempPath;
  final String retainedPath;
  final String? newMetadataJson;

  const PageReplacementRecord({
    required this.replacementId,
    required this.copyId,
    required this.ordinal,
    required this.queueOrder,
    required this.state,
    required this.oldPath,
    required this.newPath,
    required this.tempPath,
    required this.retainedPath,
    required this.newMetadataJson,
  });
}

/// One fixed input and target, with restartable transfer progress.
class ContentWorkRecord {
  final String workItemId;
  final String targetNamespace;
  final String? copyId;
  final String kind;
  final String state;
  final String inputJson;
  final String? localArtifactPath;
  final String? remoteDestination;
  final String? inputManifestId;
  final String artifactsJson;
  final String committedObjectsJson;
  final String? pendingManifestId;
  final String source;
  final String finishAction;

  const ContentWorkRecord({
    required this.workItemId,
    required this.targetNamespace,
    required this.copyId,
    required this.kind,
    required this.state,
    required this.inputJson,
    required this.localArtifactPath,
    required this.remoteDestination,
    required this.inputManifestId,
    required this.artifactsJson,
    required this.committedObjectsJson,
    required this.pendingManifestId,
    this.source = 'manual',
    this.finishAction = 'keep',
  });

  factory ContentWorkRecord.fromRow(Map<String, dynamic> row) =>
      ContentWorkRecord(
        workItemId: row['work_item_id'] as String,
        targetNamespace: row['target_namespace'] as String,
        copyId: row['copy_id'] as String?,
        kind: row['kind'] as String,
        state: row['state'] as String,
        inputJson: row['input_json'] as String,
        localArtifactPath: row['local_artifact_path'] as String?,
        remoteDestination: row['remote_destination'] as String?,
        inputManifestId: row['input_manifest_id'] as String?,
        artifactsJson: row['artifacts_json'] as String,
        committedObjectsJson: row['committed_objects_json'] as String,
        pendingManifestId: row['pending_manifest_id'] as String?,
        source: row['source'] as String,
        finishAction: row['finish_action'] as String,
      );
}

class ContentRepository {
  final AppDb db;

  const ContentRepository(this.db);

  /// Called in the manifest/index/work completion transaction.
  Future<void> handoffCopy(String copyId, String namespace) async {
    await db.customStatement(
      "UPDATE content_copy SET library_namespace = ? WHERE copy_id = ? AND lifecycle = 'active'",
      [namespace, copyId],
    );
    await db.customStatement(
      """
      DELETE FROM image WHERE gid IN (
        SELECT gid FROM gallery_downloaded_v2
        WHERE copy_id = ? AND download_status_index = 4
      )
    """,
      [copyId],
    );
    await db.customStatement(
      'DELETE FROM gallery_downloaded_v2 WHERE copy_id = ? AND download_status_index = 4',
      [copyId],
    );
    await db.customStatement(
      'DELETE FROM archive_downloaded_v2 WHERE copy_id = ? AND archive_status_index = 90',
      [copyId],
    );
  }

  Future<void> setSourcePageUrl(String copyId, int ordinal, String url) =>
      db.customStatement(
        'UPDATE content_page SET source_page_url = ? WHERE copy_id = ? AND ordinal = ?',
        [url, copyId, ordinal],
      );

  /// A resident belongs to the cloud browser only while its indexed manifest
  /// and published resource still describe these exact pages.
  Future<bool> isCloudResident(String copyId, String namespace) async {
    final owner = await db
        .customSelect(
          'SELECT library_namespace FROM content_copy WHERE copy_id = ?',
          variables: [Variable.withString(copyId)],
        )
        .getSingleOrNull();
    return owner?.readNullable<String>('library_namespace') == namespace &&
        await publishedPagesForCopy(copyId, namespace, headsOnly: true) != null;
  }

  /// Evaluates one library refresh against the same published heads as
  /// [isCloudResident], without repeating the namespace's publication query.
  Future<Set<String>> cloudResidentCopyIds(
    String namespace,
    Iterable<String> copyIds,
  ) async {
    final ids = copyIds.toSet();
    if (ids.isEmpty) {
      return {};
    }
    final rows = await db
        .customSelect(
          '''
      SELECT c.copy_id,c.gid,c.representation,
        p.ordinal,p.state,p.raw_hash,p.raw_length
      FROM content_copy c JOIN json_each(?) wanted ON wanted.value=c.copy_id
      LEFT JOIN content_page p ON p.copy_id=c.copy_id
      WHERE c.lifecycle='active' AND c.library_namespace=?
      ORDER BY c.copy_id,p.ordinal
    ''',
          variables: [
            Variable.withString(jsonEncode(ids.toList())),
            Variable.withString(namespace),
          ],
        )
        .get();
    final copies =
        <String, ({int gid, String representation, List<QueryRow> pages})>{};
    for (final row in rows) {
      final copy = copies.putIfAbsent(
        row.read<String>('copy_id'),
        () => (
          gid: row.read<int>('gid'),
          representation: row.read<String>('representation'),
          pages: [],
        ),
      );
      if (row.readNullable<int>('ordinal') != null) {
        copy.pages.add(row);
      }
    }
    if (copies.isEmpty) {
      return {};
    }
    final candidateKinds = {
      for (final copy in copies.values) (copy.gid, copy.representation),
    };
    final heads = await db
        .customSelect(
          '''
      WITH published AS (
        SELECT DISTINCT m.manifest_id,m.gid,m.representation,m.portable_json
        FROM content_manifest m JOIN content_remote_resource r
          ON r.target_namespace=m.target_namespace
            AND r.kind='manifest' AND r.object_hash=m.manifest_id
        WHERE m.target_namespace=?
      )
      SELECT p.manifest_id,p.gid,p.representation,p.portable_json FROM published p
      WHERE p.manifest_id NOT IN (
        SELECT s.value FROM published h,json_each(h.portable_json,'\$.supersedes') s
        WHERE s.value IS NOT NULL
      )
    ''',
          variables: [Variable.withString(namespace)],
        )
        .get();
    final headsByKind = <(int, String), List<QueryRow>>{};
    for (final row in heads) {
      final kind = (row.read<int>('gid'), row.read<String>('representation'));
      if (candidateKinds.contains(kind)) {
        (headsByKind[kind] ??= []).add(row);
      }
    }
    final parsedHeads = <String, PortableManifest>{};
    final resident = <String>{};
    for (final entry in copies.entries) {
      final copy = entry.value;
      for (final head
          in headsByKind[(copy.gid, copy.representation)] ?? <QueryRow>[]) {
        final manifest = parsedHeads.putIfAbsent(
          head.read<String>('manifest_id'),
          () => PortableManifest.fromPortableJson(
            head.read<String>('portable_json'),
          ),
        );
        if (copy.pages.length == manifest.pages.length &&
            copy.pages.asMap().entries.every((entry) {
              final row = entry.value;
              final page = manifest.pages[entry.key];
              return row.read<int>('ordinal') == entry.key &&
                  row.read<String>('state') == 'completed' &&
                  row.readNullable<String>('raw_hash') == page.rawHash &&
                  row.readNullable<int>('raw_length') == page.rawLength;
            })) {
          resident.add(entry.key);
          break;
        }
      }
    }
    return resident;
  }

  /// Publication is a raw-content relation and does not depend on which local
  /// browser currently owns the copy.
  Future<Map<int, PortablePage>?> publishedPagesForCopy(
    String copyId,
    String namespace, {
    bool headsOnly = false,
  }) async {
    final rows = await db
        .customSelect(
          """
      SELECT m.portable_json FROM content_copy c
      JOIN content_manifest m ON m.target_namespace = ?
        AND m.gid = c.gid AND m.representation = c.representation
      JOIN content_remote_resource r ON r.target_namespace = m.target_namespace
        AND r.kind = 'manifest' AND r.object_hash = m.manifest_id
      WHERE c.copy_id = ? AND c.lifecycle = 'active'
        ${headsOnly ? '''AND NOT EXISTS (
          SELECT 1 FROM content_manifest h
          JOIN content_remote_resource hr ON hr.target_namespace = h.target_namespace
            AND hr.kind = 'manifest' AND hr.object_hash = h.manifest_id
          JOIN json_each(h.portable_json, '\$.supersedes') s
          WHERE h.target_namespace = m.target_namespace AND s.value = m.manifest_id
        )''' : ''}
    """,
          variables: [
            Variable.withString(namespace),
            Variable.withString(copyId),
          ],
        )
        .get();
    if (rows.isEmpty) return null;
    final pages = await listPages(copyId);
    final matched = <int, PortablePage>{};
    for (final row in rows) {
      final manifest = PortableManifest.fromPortableJson(
        row.read<String>('portable_json'),
      );
      bool samePage(ContentPageRecord page, int ordinal) =>
          ordinal < manifest.pages.length &&
          page.ordinal == ordinal &&
          page.state == 'completed' &&
          page.rawHash == manifest.pages[ordinal].rawHash &&
          page.rawLength == manifest.pages[ordinal].rawLength;
      if (headsOnly) {
        if (pages.length == manifest.pages.length &&
            pages.asMap().entries.every(
              (entry) => samePage(entry.value, entry.key),
            )) {
          return manifest.pages.asMap();
        }
      } else {
        for (final page in pages) {
          if (samePage(page, page.ordinal))
            matched[page.ordinal] = manifest.pages[page.ordinal];
        }
      }
    }
    return matched.isEmpty ? null : matched;
  }

  Future<String> createCopy({
    String? copyId,
    required int gid,
    required String representation,
    required String rootPath,
  }) async {
    final id = copyId ?? const Uuid().v4();
    await db.customStatement(
      '''
      INSERT INTO content_copy
        (copy_id, gid, representation, root_path, is_current, lifecycle,
         created_at)
      VALUES (?, ?, ?, ?, 0, 'active', ?)
    ''',
      [
        id,
        gid,
        representation,
        rootPath,
        DateTime.now().toUtc().toIso8601String(),
      ],
    );
    return id;
  }

  /// The directory remains its own copyId when pages change in place.
  Future<void> setCurrentCopy(String copyId) => db.transaction(() async {
    final rows = await db
        .customSelect(
          'SELECT gid, representation, lifecycle FROM content_copy WHERE copy_id = ?',
          variables: [Variable.withString(copyId)],
        )
        .get();
    if (rows.isEmpty || rows.single.read<String>('lifecycle') != 'active') {
      throw StateError('Cannot select missing or retired copy $copyId');
    }
    final gid = rows.single.read<int>('gid');
    final representation = rows.single.read<String>('representation');
    await db.customStatement(
      '''
      UPDATE content_copy SET is_current = 0
      WHERE gid = ? AND representation = ?
    ''',
      [gid, representation],
    );
    await db.customStatement(
      'UPDATE content_copy SET is_current = 1 WHERE copy_id = ?',
      [copyId],
    );
  });

  Future<void> putPage(ContentPageRecord page) async {
    await db.customStatement(
      '''
      INSERT INTO content_page (copy_id, ordinal, relative_path, raw_hash,
        raw_length, mime, width, height, state, source_page_url, codec_profile, object_hash, stored_length)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(copy_id, ordinal) DO UPDATE SET
        relative_path = excluded.relative_path,
        codec_profile = excluded.codec_profile, object_hash = excluded.object_hash,
        stored_length = excluded.stored_length,
        raw_hash = excluded.raw_hash, raw_length = excluded.raw_length,
        mime = excluded.mime, width = excluded.width,
        height = excluded.height, state = excluded.state,
        source_page_url = COALESCE(excluded.source_page_url, content_page.source_page_url)
    ''',
      [
        page.copyId,
        page.ordinal,
        page.relativePath,
        page.rawHash,
        page.rawLength,
        page.mime,
        page.width,
        page.height,
        page.state,
        page.sourcePageUrl,
        page.codecProfile,
        page.objectHash,
        page.storedLength,
      ],
    );
  }

  Future<List<ContentPageRecord>> listPages(String copyId) async {
    final rows = await db
        .customSelect(
          'SELECT * FROM content_page WHERE copy_id = ? ORDER BY ordinal',
          variables: [Variable.withString(copyId)],
        )
        .get();
    return rows
        .map(
          (row) => ContentPageRecord(
            copyId: row.read<String>('copy_id'),
            ordinal: row.read<int>('ordinal'),
            relativePath: row.read<String>('relative_path'),
            rawHash: row.readNullable<String>('raw_hash'),
            rawLength: row.readNullable<int>('raw_length'),
            mime: row.readNullable<String>('mime'),
            width: row.readNullable<int>('width'),
            height: row.readNullable<int>('height'),
            state: row.read<String>('state'),
            sourcePageUrl: row.readNullable<String>('source_page_url'),
            codecProfile: row.readNullable<String>('codec_profile'),
            objectHash: row.readNullable<String>('object_hash'),
            storedLength: row.readNullable<int>('stored_length'),
          ),
        )
        .toList();
  }

  Future<ContentPageRecord> getPage(String copyId, int ordinal) async {
    final row = await db
        .customSelect(
          'SELECT * FROM content_page WHERE copy_id = ? AND ordinal = ?',
          variables: [Variable.withString(copyId), Variable.withInt(ordinal)],
        )
        .getSingle();
    return ContentPageRecord(
      copyId: row.read<String>('copy_id'),
      ordinal: row.read<int>('ordinal'),
      relativePath: row.read<String>('relative_path'),
      rawHash: row.readNullable<String>('raw_hash'),
      rawLength: row.readNullable<int>('raw_length'),
      mime: row.readNullable<String>('mime'),
      width: row.readNullable<int>('width'),
      height: row.readNullable<int>('height'),
      state: row.read<String>('state'),
      sourcePageUrl: row.readNullable<String>('source_page_url'),
      codecProfile: row.readNullable<String>('codec_profile'),
      objectHash: row.readNullable<String>('object_hash'),
      storedLength: row.readNullable<int>('stored_length'),
    );
  }

  /// A retirement is journaled before any directory rename or deletion.
  Future<void> markCopyRetiring(String copyId, String trashPath) async {
    await db.customStatement(
      '''
      UPDATE content_copy SET lifecycle = 'retiring', is_current = 0,
        trash_path = ?, cleanup_state = 'pending'
      WHERE copy_id = ? AND lifecycle = 'active'
    ''',
      [trashPath, copyId],
    );
  }

  Future<void> updateCopyCleanupState(String copyId, String state) async {
    await db.customStatement(
      'UPDATE content_copy SET cleanup_state = ? WHERE copy_id = ?',
      [state, copyId],
    );
  }

  Future<PageReplacementRecord> enqueuePageReplacement({
    String? replacementId,
    required String copyId,
    required int ordinal,
    required String oldPath,
    required String newPath,
    required String tempPath,
    required String retainedPath,
    bool representationOnly = false,
  }) async {
    final id = replacementId ?? const Uuid().v4();
    await db.transaction(() async {
      final row = await db
          .customSelect(
            '''
        SELECT COALESCE(MAX(queue_order), 0) AS last_order
        FROM content_page_replacement WHERE copy_id = ? AND ordinal = ?
      ''',
            variables: [Variable.withString(copyId), Variable.withInt(ordinal)],
          )
          .getSingle();
      final order = row.read<int>('last_order') + 1;
      await db.customStatement(
        '''
        INSERT INTO content_page_replacement
          (replacement_id, copy_id, ordinal, queue_order, state,
           old_path, new_path, temp_path, retained_path, created_at)
        VALUES (?, ?, ?, ?, 'downloading', ?, ?, ?, ?, ?)
      ''',
        [
          id,
          copyId,
          ordinal,
          order,
          oldPath,
          newPath,
          tempPath,
          retainedPath,
          DateTime.now().toUtc().toIso8601String(),
        ],
      );
      if (!representationOnly) {
        // An already queued upload must not clean the old page after mutation.
        await db.customStatement(
          '''
        UPDATE content_work_item SET finish_action = 'keep', updated_at = ?
        WHERE copy_id = ? AND kind IN ('content', 'revision') AND finish_action = 'release'
      ''',
          [DateTime.now().toUtc().toIso8601String(), copyId],
        );
      }
    });
    return (await listPageReplacements(copyId))
        .singleWhere((item) => item.replacementId == id);
  }

  Future<Set<String>> pendingPageReplacementCopyIds() async {
    final rows = await db.customSelect('''
      SELECT DISTINCT copy_id FROM content_page_replacement
      WHERE state != 'completed'
    ''').get();
    return rows.map((row) => row.read<String>('copy_id')).toSet();
  }

  Future<List<PageReplacementRecord>> listPageReplacements(
    String copyId, {
    bool includeFinished = false,
  }) async {
    final rows = await db
        .customSelect(
          '''
      SELECT * FROM content_page_replacement WHERE copy_id = ?
      ${includeFinished ? '' : "AND state != 'completed'"}
      ORDER BY ordinal, queue_order
    ''',
          variables: [Variable.withString(copyId)],
        )
        .get();
    return rows
        .map(
          (row) => PageReplacementRecord(
            replacementId: row.read<String>('replacement_id'),
            copyId: row.read<String>('copy_id'),
            ordinal: row.read<int>('ordinal'),
            queueOrder: row.read<int>('queue_order'),
            state: row.read<String>('state'),
            oldPath: row.read<String>('old_path'),
            newPath: row.read<String>('new_path'),
            tempPath: row.read<String>('temp_path'),
            retainedPath: row.read<String>('retained_path'),
            newMetadataJson: row.readNullable<String>('new_metadata_json'),
          ),
        )
        .toList();
  }

  Future<void> setPageReplacementReady(
    String replacementId,
    String newMetadataJson,
  ) async {
    await db.customStatement(
      '''
      UPDATE content_page_replacement SET state = 'committing', new_metadata_json = ?
      WHERE replacement_id = ? AND state = 'downloading'
    ''',
      [newMetadataJson, replacementId],
    );
  }

  /// Call only after the on-disk rename sequence has reached the new final page.
  Future<void> commitPageReplacement(
    String replacementId,
    ContentPageRecord page,
  ) => db.transaction(() async {
    final rows = await db
        .customSelect(
          '''
      SELECT copy_id, ordinal, state FROM content_page_replacement
      WHERE replacement_id = ?
    ''',
          variables: [Variable.withString(replacementId)],
        )
        .get();
    if (rows.isEmpty ||
        rows.single.read<String>('state') != 'committing' ||
        rows.single.read<String>('copy_id') != page.copyId ||
        rows.single.read<int>('ordinal') != page.ordinal) {
      throw StateError('Page replacement is not ready for commit');
    }
    await putPage(page);
    await db.customStatement(
      '''
      UPDATE content_page_replacement SET state = 'committed'
      WHERE replacement_id = ?
    ''',
      [replacementId],
    );
  });

  Future<void> finishPageReplacement(String replacementId) async {
    await db.customStatement(
      '''
      UPDATE content_page_replacement SET state = 'completed'
      WHERE replacement_id = ? AND state = 'committed'
    ''',
      [replacementId],
    );
  }

  Future<void> finishUnchangedPageReplacement(String replacementId) async {
    await db.customStatement(
      '''
      UPDATE content_page_replacement SET state = 'completed'
      WHERE replacement_id = ? AND state = 'downloading'
    ''',
      [replacementId],
    );
  }

  Future<void> recordRemoteResource({
    required String targetNamespace,
    required String href,
    required String kind,
    String? objectHash,
    String? etag,
    String? partition,
  }) async {
    await db.customStatement(
      '''
      INSERT INTO content_remote_resource
        (target_namespace, href, kind, object_hash, etag, partition, observed_at)
      VALUES (?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(target_namespace, href) DO UPDATE SET
        kind = excluded.kind, object_hash = excluded.object_hash,
        etag = excluded.etag, partition = excluded.partition,
        observed_at = excluded.observed_at
    ''',
      [
        targetNamespace,
        href,
        kind,
        objectHash,
        etag,
        partition,
        DateTime.now().toUtc().toIso8601String(),
      ],
    );
  }

  /// Resource updates, removals, and token advance become visible together.
  Future<void> commitPartitionScan({
    required String targetNamespace,
    required String partition,
    required String scanState,
    String? syncToken,
    required List<String> deletedHrefs,
  }) => db.transaction(() async {
    for (final href in deletedHrefs) {
      await db.customStatement(
        '''
        DELETE FROM content_remote_resource
        WHERE target_namespace = ? AND href = ?
      ''',
        [targetNamespace, href],
      );
    }
    await db.customStatement(
      '''
      INSERT INTO content_remote_partition
        (target_namespace, partition, sync_token, scan_state, scanned_at)
      VALUES (?, ?, ?, ?, ?)
      ON CONFLICT(target_namespace, partition) DO UPDATE SET
        sync_token = excluded.sync_token, scan_state = excluded.scan_state,
        scanned_at = excluded.scanned_at
    ''',
      [
        targetNamespace,
        partition,
        syncToken,
        scanState,
        DateTime.now().toUtc().toIso8601String(),
      ],
    );
  });

  /// Import a closed artifact into one target's local projection.
  /// The same path handles a local publish and a remote discovery.
  Future<void> importManifest(
    String targetNamespace,
    ManifestArtifact artifact,
  ) async {
    final manifest = await PortableManifestCodec.readAsync(artifact.file);
    final now = DateTime.now().toUtc().toIso8601String();
    await db.transaction(() async {
      await db.customStatement(
        '''
        INSERT OR IGNORE INTO content_manifest
          (target_namespace, manifest_id, gid, representation, title,
           gallery_url, portable_json, imported_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ''',
        [
          targetNamespace,
          artifact.manifestId,
          manifest.gid,
          manifest.representation,
          manifest.title,
          manifest.galleryUrl,
          manifest.toPortableJson(),
          now,
        ],
      );
      for (final page in manifest.pages) {
        await db.customStatement(
          '''
          INSERT OR IGNORE INTO content_object_representation
            (target_namespace, raw_hash, object_hash, codec_profile, stored_length)
          VALUES (?, ?, ?, ?, ?)
        ''',
          [
            targetNamespace,
            page.rawHash,
            page.objectHash,
            page.codecProfile,
            page.storedLength,
          ],
        );
      }
      if (manifest.thumbnail case final thumb?) {
        await db.customStatement(
          '''
          INSERT OR IGNORE INTO content_object_representation
            (target_namespace, raw_hash, object_hash, codec_profile, stored_length)
          VALUES (?, ?, ?, 'raw', ?)
        ''',
          [targetNamespace, thumb.rawHash, thumb.objectHash, thumb.rawLength],
        );
      }
    });
  }

  Future<List<ManifestHeadGroup>> listManifestHeads(
    String targetNamespace,
    int gid,
    String representation,
  ) async {
    final rows = await db
        .customSelect(
          '''
      SELECT manifest_id, portable_json FROM content_manifest
      WHERE target_namespace = ? AND gid = ? AND representation = ?
      ORDER BY manifest_id
    ''',
          variables: [
            Variable.withString(targetNamespace),
            Variable.withInt(gid),
            Variable.withString(representation),
          ],
        )
        .get();
    final manifests = <String, PortableManifest>{
      for (final row in rows)
        row.read<String>('manifest_id'): PortableManifest.fromPortableJson(
          row.read<String>('portable_json'),
        ),
    };
    final superseded = <String>{
      for (final manifest in manifests.values) ...manifest.supersedes,
    };
    final groups = <ManifestHeadGroup>[];
    for (final entry in manifests.entries) {
      if (superseded.contains(entry.key)) {
        continue;
      }
      final existing = groups.indexWhere(
        (group) => group.representative.businessEquivalentTo(entry.value),
      );
      if (existing < 0) {
        groups.add(ManifestHeadGroup(entry.value, [entry.key]));
      } else {
        groups[existing].manifestIds.add(entry.key);
      }
    }
    return groups;
  }

  Future<List<ObjectRepresentationRecord>> findObjectRepresentations(
    String targetNamespace,
    String rawHash,
  ) async {
    final rows = await db
        .customSelect(
          '''
      SELECT raw_hash, object_hash, codec_profile, stored_length
      FROM content_object_representation
      WHERE target_namespace = ? AND raw_hash = ? ORDER BY codec_profile, object_hash
    ''',
          variables: [
            Variable.withString(targetNamespace),
            Variable.withString(rawHash),
          ],
        )
        .get();
    return rows
        .map(
          (row) => ObjectRepresentationRecord(
            row.read<String>('raw_hash'),
            row.read<String>('object_hash'),
            row.read<String>('codec_profile'),
            row.read<int>('stored_length'),
          ),
        )
        .toList();
  }

  /// Atomically switches ownership and rebases only unfinished absolute page
  /// replacement facts. Completed pages remain relative to the owned root.
  Future<void> relocateCopyRoot(
    String copyId,
    String source,
    String target, {
    String? visibleRoot,
  }) async {
    await db.transaction(() async {
      final pending = await listPageReplacements(copyId);
      String rebase(String value) =>
          path.join(target, path.relative(value, from: source));
      for (final item in pending) {
        await db.customStatement(
          'UPDATE content_page_replacement SET old_path=?, new_path=?, temp_path=?, retained_path=? WHERE replacement_id=?',
          [
            rebase(item.oldPath),
            rebase(item.newPath),
            rebase(item.tempPath),
            rebase(item.retainedPath),
            item.replacementId,
          ],
        );
      }
      final unfinishedImages = await db
          .customSelect(
            "SELECT i.gid, i.serialNo, i.path FROM image i JOIN gallery_downloaded_v2 g ON g.gid=i.gid WHERE g.copy_id=? AND g.download_status_index!=4 AND i.path!=''",
            variables: [Variable.withString(copyId)],
          )
          .get();
      if (unfinishedImages.isNotEmpty && visibleRoot == null) {
        throw StateError(
          'Visible root is required to relocate unfinished image paths',
        );
      }
      for (final image in unfinishedImages) {
        final previous = path.normalize(
          path.join(visibleRoot!, image.read<String>('path')),
        );
        if (!path.isWithin(source, previous)) continue;
        await db.customStatement(
          'UPDATE image SET path=? WHERE gid=? AND serialNo=?',
          [
            path.relative(
              path.join(target, path.relative(previous, from: source)),
              from: visibleRoot,
            ),
            image.read<int>('gid'),
            image.read<int>('serialNo'),
          ],
        );
      }
      await db.customStatement(
        "UPDATE content_copy SET root_path=? WHERE copy_id=? AND root_path=? AND lifecycle='active'",
        [target, copyId, source],
      );
    });
  }

  /// Caller supplies a frozen input JSON and, for backup, a completed artifact.
  /// Transfer retries retain this row and do not regenerate either input.
  Future<ContentWorkRecord> createWorkItem({
    String? workItemId,
    required String kind,
    required String targetNamespace,
    required String inputJson,
    String? copyId,
    String? inputManifestId,
    String? localArtifactPath,
    String? remoteDestination,
    String source = 'manual',
    String finishAction = 'keep',
  }) async {
    final id = workItemId ?? const Uuid().v4();
    final now = DateTime.now().toUtc().toIso8601String();
    await db.customStatement(
      '''
      INSERT INTO content_work_item
        (work_item_id, target_namespace, copy_id, kind, state,
         input_manifest_id, input_json, local_artifact_path, remote_destination,
         artifacts_json, committed_objects_json, pending_manifest_id,
         source, finish_action, created_at, updated_at)
      VALUES (?, ?, ?, ?, 'queued', ?, ?, ?, ?, '{}', '[]', NULL, ?, ?, ?, ?)
    ''',
      [
        id,
        targetNamespace,
        copyId,
        kind,
        inputManifestId,
        inputJson,
        localArtifactPath,
        remoteDestination,
        source,
        finishAction,
        now,
        now,
      ],
    );
    return (await getWorkItem(id))!;
  }

  Future<ContentWorkRecord?> getWorkItem(String workItemId) async {
    final rows = await db
        .customSelect(
          'SELECT * FROM content_work_item WHERE work_item_id = ?',
          variables: [Variable.withString(workItemId)],
        )
        .get();
    return rows.isEmpty ? null : ContentWorkRecord.fromRow(rows.single.data);
  }

  Future<List<ContentWorkRecord>> listWorkItems({
    String? kind,
    String? copyId,
    String? targetNamespace,
    bool includeFinished = false,
  }) async {
    final filters = <String>[];
    final variables = <Variable>[];
    if (kind != null) {
      filters.add('kind = ?');
      variables.add(Variable.withString(kind));
    }
    if (targetNamespace != null) {
      filters.add('target_namespace = ?');
      variables.add(Variable.withString(targetNamespace));
    }
    if (copyId != null) {
      filters.add('copy_id = ?');
      variables.add(Variable.withString(copyId));
    }
    if (!includeFinished) {
      filters.add("state NOT IN ('completed', 'cancelled')");
    }
    final where = filters.isEmpty ? '' : 'WHERE ${filters.join(' AND ')}';
    final rows = await db
        .customSelect(
          'SELECT * FROM content_work_item $where ORDER BY created_at, work_item_id',
          variables: variables,
        )
        .get();
    return rows.map((row) => ContentWorkRecord.fromRow(row.data)).toList();
  }

  Future<void> updateWorkItemState(String workItemId, String state) async {
    await db.customStatement(
      'UPDATE content_work_item SET state = ?, updated_at = ? WHERE work_item_id = ?',
      [state, DateTime.now().toUtc().toIso8601String(), workItemId],
    );
  }

  /// Persist content transfer progress without changing the fixed input or target.
  Future<void> updateContentWorkProgress({
    required String workItemId,
    required String state,
    required String artifactsJson,
    required String committedObjectsJson,
    String? pendingManifestId,
  }) async {
    await db.customStatement(
      '''
      UPDATE content_work_item SET state = ?, artifacts_json = ?,
        committed_objects_json = ?, pending_manifest_id = ?,
        updated_at = ? WHERE work_item_id = ?
          AND state NOT IN ('cancelled', 'paused', 'completed')
    ''',
      [
        state,
        artifactsJson,
        committedObjectsJson,
        pendingManifestId,
        DateTime.now().toUtc().toIso8601String(),
        workItemId,
      ],
    );
  }
}
