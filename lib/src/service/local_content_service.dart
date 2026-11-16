import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

import '../database/database.dart';
import '../model/gallery_image.dart';
import '../model/gallery_url.dart';
import '../model/read_page_info.dart';
import '../setting/download_setting.dart';
import 'content_sync/content_repository.dart';
import 'content_codec.dart';
import 'content_sync/portable_manifest.dart';
import 'archive_download_service.dart';
import 'gallery_download/gallery_download_service.dart';
import 'gallery_download/download_path_resolver.dart';
import 'jh_service.dart';
import 'log.dart';
import 'path_service.dart';

part 'local_content_relocation.dart';
part 'local_content_metadata.dart';
part 'local_content_reading.dart';
part 'local_content_representation.dart';

typedef BeforeContentMutation = Future<void> Function(String copyId);
typedef ContentCompleted = Future<void> Function(CompletedContent content);

class CompletedContentPage {
  final int ordinal;
  final String relativePath;
  final String rawHash;
  final int rawLength;
  final String mime;
  final int? width;
  final int? height;
  final String? sourcePageUrl;
  final String? codecProfile;
  final String? objectHash;
  final int? storedLength;

  const CompletedContentPage({
    required this.ordinal,
    required this.relativePath,
    required this.rawHash,
    required this.rawLength,
    required this.mime,
    this.width,
    this.height,
    this.sourcePageUrl,
    this.codecProfile,
    this.objectHash,
    this.storedLength,
  });
}

/// A snapshot of one complete local directory, independent of a download task.
class CompletedContent {
  final String copyId;
  final int gid;
  final String representation;
  final String rootPath;
  final String galleryUrl;
  final String title;
  final List<PortableTag> tags;
  final List<ManifestLineage> lineage;
  final Map<String, Object?> providerMetadata;
  final List<String> collections;
  Map<String, Object?> get userFields => {
    'title': title,
    'collections': collections,
  };
  final List<CompletedContentPage> pages;

  const CompletedContent({
    required this.copyId,
    required this.gid,
    required this.representation,
    required this.rootPath,
    required this.galleryUrl,
    required this.title,
    required this.tags,
    required this.lineage,
    required this.pages,
    this.providerMetadata = const {},
    this.collections = const [],
  });
}

class _PageInputGate {
  int readers = 0;
  bool closed = false;
  final List<Completer<void>> waiters = [];

  void notify() {
    for (final waiter in waiters) {
      if (!waiter.isCompleted) waiter.complete();
    }
    waiters.clear();
  }

  Future<void> wait() {
    final waiter = Completer<void>();
    waiters.add(waiter);
    return waiter.future;
  }
}

LocalContentService localContentService = LocalContentService();

/// Owns local directories, page input leases, replacement journals and retirement.
class LocalContentService
    with JHLifeCircleBeanErrorCatch
    implements JHLifeCircleBean {
  final ContentRepository repository;
  final Map<String, _PageInputGate> _pageGates = {};
  final Map<String, ManagedPageLocation> _managedPages = {};
  final Map<(String, int), ManagedPageLocation> _managedPagesByIdentity = {};
  final Map<String, String> _copiesByRoot = {};
  final Set<String> _retiring = {};
  final Map<String, Completer<void>> _replacementDone = {};
  final Map<String, Future<void>> _replacementCommits = {};
  final Map<String, Timer> _projectionTimers = {};
  final Map<String, DirectoryRecoveryProjection> _pendingProjections = {};
  final Map<String, Future<void>> _projectionWrites = {};
  final Set<String> _retiringRoots = {};
  final Map<String, Future<void>> _retirementFutures = {};

  final Set<String> _relocating = {};
  final Map<String, Completer<void>> _relocationGates = {};
  final Set<String> _relocationRoots = {};
  Future<void> _relocationTail = Future<void>.value();
  Future<void> Function(String copyId)? onBeforeRelocation;
  Future<void> Function(String copyId, bool usable)? onAfterRelocation;

  BeforeContentMutation? onBeforeMutation;
  BeforeContentMutation? onBeforeRetirement;
  ContentCompleted? onCompleted;
  void Function(String copyId)? onRetired;
  String? Function()? currentLibraryNamespace;
  Future<void> Function()? onLibraryChanged;

  Future<void> setSourcePageUrl(String copyId, int ordinal, String url) async {
    await repository.setSourcePageUrl(copyId, ordinal, url);
    final input = await completedInput(copyId);
    if (input == null) return;
    await rebuildProjection(copyId);
    await onCompleted?.call(input);
  }

  /// The database handoff has committed; update consumers without moving bytes.
  Future<void> finishCloudHandoff(String copyId) async {
    galleryDownloadService.detachCompletedCopy(copyId);
    await archiveDownloadService.detachCompletedCopy(copyId);
    try {
      await rebuildProjection(copyId);
    } catch (error, stack) {
      log.error('Cloud resident projection rebuild failed', error, stack);
    }
    await onLibraryChanged?.call();
  }

  /// Known runtime owners take precedence over an older task sidecar.
  Future<bool> shouldRestoreTask(String rootPath, String taskKind) async {
    final copyId = await copyIdForRoot(rootPath);
    if (copyId == null) return true;
    final owner = await repository.db
        .customSelect(
          'SELECT library_namespace FROM content_copy WHERE copy_id = ?',
          variables: [Variable.withString(copyId)],
        )
        .getSingle();
    if (owner.readNullable<String>('library_namespace') == null) {
      return true;
    }
    final table = taskKind == 'gallery'
        ? 'gallery_downloaded_v2'
        : 'archive_downloaded_v2';
    final rows = await repository.db
        .customSelect(
          'SELECT 1 FROM $table WHERE copy_id = ?',
          variables: [Variable.withString(copyId)],
        )
        .get();
    return rows.isNotEmpty;
  }

  LocalContentService({ContentRepository? repository})
    : repository = repository ?? ContentRepository(appDb);

  @override
  List<JHLifeCircleBean> get initDependencies =>
      super.initDependencies..add(downloadSetting);

  @override
  Future<void> doInitBean() async {
    await recoverRelocations();
    // Finished journals need no recovery. Select owners once instead of
    // scanning their retained replacement history for every active copy.
    final pendingCopies = await repository.pendingPageReplacementCopyIds();
    final rows = await repository.db
        .customSelect(
          "SELECT copy_id, root_path, trash_path, lifecycle, metadata_json FROM content_copy WHERE lifecycle = 'retiring' OR lifecycle = 'active'",
        )
        .get();
    for (final row in rows) {
      final copyId = row.read<String>('copy_id');
      final root = path.normalize(row.read<String>('root_path'));
      if (row.read<String>('lifecycle') == 'retiring') {
        _retiring.add(copyId);
        _retiringRoots.add(root);
      } else {
        _copiesByRoot[root] = copyId;
      }
    }
    await repository.db.transaction(() async {
      await repository.db.customStatement("""
        DELETE FROM image WHERE gid IN (
          SELECT g.gid FROM gallery_downloaded_v2 g JOIN content_copy c ON c.copy_id=g.copy_id
          WHERE c.lifecycle='retiring')
      """);
      await repository.db.customStatement("""
        DELETE FROM gallery_downloaded_v2 WHERE copy_id IN
          (SELECT copy_id FROM content_copy WHERE lifecycle='retiring')
      """);
      await repository.db.customStatement("""
        DELETE FROM archive_downloaded_v2 WHERE copy_id IN
          (SELECT copy_id FROM content_copy WHERE lifecycle='retiring')
      """);
    });
    for (final row in rows) {
      final copyId = row.read<String>('copy_id');
      if (row.read<String>('lifecycle') != 'active' ||
          isRelocating(copyId) ||
          !pendingCopies.contains(copyId))
        continue;
      for (final pending in await repository.listPageReplacements(copyId)) {
        if (pending.state == 'committing') {
          _gate(copyId, pending.ordinal).closed = true;
        }
      }
    }
    for (final row in rows) {
      final copyId = row.read<String>('copy_id');
      try {
        if (isRelocating(copyId)) continue;
        if (row.read<String>('lifecycle') == 'retiring') {
          await _finishRetirement(
            copyId,
            row.read<String>('root_path'),
            row.readNullable<String>('trash_path'),
          );
          continue;
        }
        while (pendingCopies.contains(copyId)) {
          final pending = await repository.listPageReplacements(copyId);
          PageReplacementRecord? next;
          for (final replacement in pending) {
            final blocked = pending.any(
              (item) =>
                  item.ordinal == replacement.ordinal &&
                  item.queueOrder < replacement.queueOrder,
            );
            if (!blocked &&
                (replacement.state == 'committing' ||
                    replacement.state == 'committed')) {
              next = replacement;
              break;
            }
          }
          if (next == null) break;
          await commitPageReplacement(next.replacementId);
        }
      } catch (error, stack) {
        log.error(
          'Resume local content operation failed: $copyId',
          error,
          stack,
        );
      }
    }
    final projectedRoots = <String>{};
    for (final row in rows) {
      if (row.read<String>('lifecycle') == 'active' &&
          !isRelocating(row.read<String>('copy_id')) &&
          row.readNullable<String>('metadata_json') != null) {
        final result = await _rebuildProjection(row.read<String>('copy_id'));
        if (result.written) {
          projectedRoots.add(
            path.normalize(path.absolute(row.read<String>('root_path'))),
          );
        }
      }
    }
    if (downloadSetting.restoreTasksAutomatically.value) {
      await _restoreContentDirectories(excludeRoots: projectedRoots);
    }
    final pageRows = await repository.db.customSelect('''
      SELECT c.root_path, p.copy_id, p.ordinal, p.relative_path, p.raw_hash
      FROM content_page p JOIN content_copy c ON c.copy_id = p.copy_id
      WHERE c.lifecycle = 'active' AND p.state = 'completed'
    ''').get();
    for (final row in pageRows) {
      _indexManagedPage(
        path.normalize(
          path.join(
            row.read<String>('root_path'),
            row.read<String>('relative_path'),
          ),
        ),
        ManagedPageLocation(
          row.read<String>('copy_id'),
          row.read<int>('ordinal'),
          row.readNullable<String>('raw_hash'),
        ),
      );
    }
  }

  @override
  Future<void> doAfterBeanReady() async {}

  String _gateKey(String copyId, int ordinal) => '$copyId:$ordinal';
  _PageInputGate _gate(String copyId, int ordinal) =>
      _pageGates.putIfAbsent(_gateKey(copyId, ordinal), _PageInputGate.new);

  Future<String> ensureCopy({
    required int gid,
    required String representation,
    required String rootPath,
    bool makeCurrent = true,
    String? copyId,
  }) async {
    final id = await _ensureCopyRecord(
      gid: gid,
      representation: representation,
      rootPath: rootPath,
      makeCurrent: makeCurrent,
      copyId: copyId,
    );
    _copiesByRoot[path.normalize(path.absolute(rootPath))] = id;
    return id;
  }

  Future<String> _ensureCopyRecord({
    required int gid,
    required String representation,
    required String rootPath,
    bool makeCurrent = true,
    String? copyId,
  }) async {
    final normalized = path.normalize(path.absolute(rootPath));
    final rows = await repository.db
        .customSelect(
          'SELECT copy_id, gid, representation, lifecycle FROM content_copy WHERE root_path = ?',
          variables: [Variable.withString(normalized)],
        )
        .get();
    if (rows.isNotEmpty) {
      if (rows.single.read<String>('lifecycle') != 'active') {
        throw StateError('Cannot reuse retired content directory $normalized');
      }
      if (rows.single.read<int>('gid') != gid ||
          rows.single.read<String>('representation') != representation) {
        throw StateError(
          'Content root belongs to another version: $normalized',
        );
      }
      final id = rows.single.read<String>('copy_id');
      if (copyId != null && copyId != id) {
        throw StateError('Content root has another copy ID: $normalized');
      }
      return id;
    }
    final id = await repository.createCopy(
      copyId: copyId,
      gid: gid,
      representation: representation,
      rootPath: normalized,
    );
    if (makeCurrent) await repository.setCurrentCopy(id);
    return id;
  }

  String? registeredRoot(String copyId) {
    for (final entry in _copiesByRoot.entries) {
      if (entry.value == copyId) return entry.key;
    }
    return null;
  }

  bool isRetiringCopy(String copyId) => _retiring.contains(copyId);
  bool isRetiringDirectory(String root) =>
      _retiringRoots.contains(path.normalize(path.absolute(root)));

  bool isManagedDirectory(String directoryPath) {
    final normalized = path.normalize(path.absolute(directoryPath));
    if (path
        .split(normalized)
        .any(
          (part) =>
              part == '.content-trash' ||
              part.startsWith('.content-relocation-'),
        ))
      return true;
    return [
      ..._copiesByRoot.keys,
      ..._retiringRoots,
      ..._relocationRoots,
    ].any((root) => root == normalized || path.isWithin(root, normalized));
  }

  void _indexManagedPage(String physicalPath, ManagedPageLocation location) {
    _managedPages[physicalPath] = location;
    _managedPagesByIdentity[(location.copyId, location.ordinal)] = location;
  }

  ManagedPageLocation? managedPageForIdentitySync(String copyId, int ordinal) =>
      _managedPagesByIdentity[(copyId, ordinal)];

  ManagedPageLocation currentManagedPageSync(ManagedPageLocation identity) =>
      _managedPagesByIdentity[(identity.copyId, identity.ordinal)] ?? identity;

  ManagedPageLocation? managedPageForPathSync(String absolutePath) =>
      _managedPages[path.normalize(path.absolute(absolutePath))];

  Future<String?> copyIdForRoot(String rootPath) async {
    final rows = await repository.db
        .customSelect(
          'SELECT copy_id FROM content_copy WHERE root_path = ? AND lifecycle = ?',
          variables: [
            Variable.withString(path.normalize(path.absolute(rootPath))),
            Variable.withString('active'),
          ],
        )
        .get();
    return rows.isEmpty ? null : rows.single.read<String>('copy_id');
  }

  Future<bool> isRootReserved(String rootPath) async {
    if (_relocationRoots.contains(path.normalize(path.absolute(rootPath))))
      return true;
    final rows = await repository.db
        .customSelect(
          'SELECT 1 FROM content_copy WHERE root_path = ? LIMIT 1',
          variables: [
            Variable.withString(path.normalize(path.absolute(rootPath))),
          ],
        )
        .get();
    return rows.isNotEmpty;
  }

  /// Rebuild the runtime owner before a restored download/archive consumer is
  /// made visible. Complete projections carry hashes; partial pages are hashed
  /// once from their surviving bytes.
  Future<String> restoreDirectoryProjection(
    String rootPath,
    DirectoryRecoveryProjection projection, {
    required int gid,
    required String representation,
  }) async {
    final existing = await copyIdForRoot(rootPath);
    if (existing != null) return existing;
    final manifest = projection.completeManifest;
    if (manifest != null &&
        (manifest.gid != gid ||
            manifest.pages.length != projection.pages.length)) {
      throw StateError('Directory projection does not match gallery $gid');
    }
    final records = <ContentPageRecord>[];
    for (final page in projection.pages) {
      final relative = page.relativePath;
      if (relative == null ||
          (page.state != 'downloaded' && page.state != 'completed'))
        continue;
      final file = _pageFile(rootPath, relative);
      if (!await file.exists()) {
        if (manifest != null)
          throw StateError('Missing restored page ${file.path}');
        continue;
      }
      final source =
          projection.residentPages[page.ordinal] ??
          manifest?.pages[page.ordinal];
      records.add(
        ContentPageRecord(
          copyId: projection.copyId,
          ordinal: page.ordinal,
          relativePath: relative,
          rawHash:
              source?.rawHash ??
              (await sha256.bind(file.openRead()).first).toString(),
          rawLength: source?.rawLength ?? await file.length(),
          mime: source?.mime ?? _mime(file.path),
          width: source?.width,
          height: source?.height,
          sourcePageUrl: source?.sourcePageUrl,
          codecProfile: source?.codecProfile == 'raw'
              ? null
              : source?.codecProfile,
          objectHash: source?.codecProfile == 'raw' ? null : source?.objectHash,
          storedLength: source?.codecProfile == 'raw'
              ? null
              : source?.storedLength,
          state: 'completed',
        ),
      );
    }
    final actualRepresentation = manifest?.representation ?? representation;
    final id = await repository.db.transaction(() async {
      final previous = await repository.db
          .customSelect(
            'SELECT root_path FROM content_copy WHERE copy_id = ?',
            variables: [Variable.withString(projection.copyId)],
          )
          .get();
      final sourceId =
          previous.isEmpty ||
              path.normalize(previous.single.read<String>('root_path')) ==
                  path.normalize(path.absolute(rootPath))
          ? projection.copyId
          : const Uuid().v4();
      final id = await _ensureCopyRecord(
        copyId: sourceId,
        gid: gid,
        representation: actualRepresentation,
        rootPath: rootPath,
        makeCurrent: false,
      );
      for (final record in records) {
        await repository.putPage(
          ContentPageRecord(
            copyId: id,
            ordinal: record.ordinal,
            relativePath: record.relativePath,
            rawHash: record.rawHash,
            rawLength: record.rawLength,
            mime: record.mime,
            width: record.width,
            height: record.height,
            sourcePageUrl: record.sourcePageUrl,
            codecProfile: record.codecProfile,
            objectHash: record.objectHash,
            storedLength: record.storedLength,
            state: record.state,
          ),
        );
      }
      if (manifest != null) {
        final snapshot =
            jsonDecode(projection.taskJson) as Map<String, dynamic>;
        final task = (snapshot['gallery'] ?? snapshot['archive']) as Map?;
        final provider = <String, Object?>{
          if (task?['category'] != null) 'category': task!['category'],
          if (task?['uploader'] != null) 'uploader': task!['uploader'],
          if (task?['publishTime'] != null) 'publishTime': task!['publishTime'],
          if (task?['coverUrl'] != null) 'coverUrl': task!['coverUrl'],
          for (final entry in manifest.providerMetadata.entries)
            if (entry.value != null) entry.key: entry.value,
          ...?(snapshot['providerMetadata'] as Map?)?.cast<String, Object?>(),
        };
        final collections = snapshot.containsKey('collections')
            ? (snapshot['collections'] as List).cast<String>()
            : manifest.collections.isNotEmpty
            ? manifest.collections
            : [
                if (task?['groupName'] case final String group
                    when group.isNotEmpty)
                  group,
              ];
        await _storeMetadata(id, {
          'galleryUrl': manifest.galleryUrl,
          'title': manifest.title,
          'providerMetadata': provider,
          'collections': collections,
          'tags': manifest.tags.map((t) => [t.namespace, t.name]).toList(),
          'lineage': manifest.lineage
              .map((e) => [e.fromGid, e.toGid, e.kind])
              .toList(),
          'expectedPages': manifest.pages.length,
        });
      }
      if (manifest != null ||
          await currentCopyId(gid, actualRepresentation) == null) {
        await repository.setCurrentCopy(id);
      }
      if (id != projection.copyId) {
        final target = File(path.join(rootPath, '.content.sqlite'));
        final staging = File('${target.path}.tmp');
        if (await staging.exists()) await staging.delete();
        await DirectoryRecoveryCodec.writeNewAsync(
          staging,
          DirectoryRecoveryProjection(
            copyId: id,
            taskKind: projection.taskKind,
            taskState: projection.taskState,
            taskJson: projection.taskJson,
            pages: projection.pages,
            completeManifest: manifest,
            residentPages: projection.residentPages,
            codecProfiles: projection.codecProfiles,
          ),
        );
        await staging.rename(target.path);
      }
      return id;
    });
    final root = path.normalize(path.absolute(rootPath));
    _copiesByRoot[root] = id;
    for (final record in records) {
      _indexManagedPage(
        path.normalize(path.join(root, record.relativePath)),
        ManagedPageLocation(id, record.ordinal, record.rawHash),
      );
    }
    return id;
  }

  Future<String?> currentCopyId(int gid, String representation) async {
    final rows = await repository.db
        .customSelect(
          'SELECT copy_id FROM content_copy WHERE gid = ? AND representation = ? AND is_current = 1 AND lifecycle = ?',
          variables: [
            Variable.withInt(gid),
            Variable.withString(representation),
            Variable.withString('active'),
          ],
        )
        .get();
    return rows.isEmpty ? null : rows.single.read<String>('copy_id');
  }

  Future<String> rootPath(String copyId) async {
    final rows = await repository.db
        .customSelect(
          'SELECT root_path FROM content_copy WHERE copy_id = ?',
          variables: [Variable.withString(copyId)],
        )
        .get();
    if (rows.isEmpty) throw StateError('Unknown local copy $copyId');
    return rows.single.read<String>('root_path');
  }

  Future<void> recordPage({
    required String copyId,
    required int ordinal,
    required String relativePath,
    String? rawHash,
    int? rawLength,
    String? mime,
    int? width,
    int? height,
    String? sourcePageUrl,
    String state = 'completed',
    String? codecProfile,
    String? objectHash,
    int? storedLength,
  }) async {
    if (_retiring.contains(copyId)) throw StateError('Copy is retiring');
    _pageFile(await rootPath(copyId), relativePath);
    await repository.putPage(
      ContentPageRecord(
        copyId: copyId,
        ordinal: ordinal,
        relativePath: relativePath,
        rawHash: rawHash,
        rawLength: rawLength,
        mime: mime,
        width: width,
        height: height,
        state: state,
        sourcePageUrl: sourcePageUrl,
        codecProfile: codecProfile,
        objectHash: objectHash,
        storedLength: storedLength,
      ),
    );
    if (state == 'completed') {
      _indexManagedPage(
        path.normalize(path.join(await rootPath(copyId), relativePath)),
        ManagedPageLocation(copyId, ordinal, rawHash),
      );
    }
  }

  Future<CompletedContent?> completedInput(String copyId) async {
    final rows = await repository.db
        .customSelect(
          'SELECT metadata_json FROM content_copy WHERE copy_id = ?',
          variables: [Variable.withString(copyId)],
        )
        .get();
    if (rows.isEmpty) return null;
    final metadata = rows.single.readNullable<String>('metadata_json');
    if (metadata == null) return null;
    return _buildCompletedInput(
      copyId,
      jsonDecode(metadata) as Map<String, dynamic>,
    );
  }

  /// Opens a restored copy through the existing local reading page, without
  /// creating a download task or depending on the source site.
  Future<ReadPageInfo> readPageInfoForCopy(
    String copyId, {
    int initialIndex = 0,
  }) async {
    final input = await completedInput(copyId);
    if (input == null) throw StateError('Copy is not complete: $copyId');
    final images = input.pages
        .map(
          (page) => GalleryImage(
            managedPage: ManagedPageLocation(
              copyId,
              page.ordinal,
              page.rawHash,
            ),
            url: '',
            width: page.width?.toDouble(),
            height: page.height?.toDouble(),
            path: path.relative(
              path.join(input.rootPath, page.relativePath),
              from: pathService.getVisibleDir().path,
            ),
            downloadStatus: DownloadStatus.downloaded,
          ),
        )
        .toList();
    return ReadPageInfo(
      mode: ReadMode.local,
      contentCopyId: input.copyId,
      representation: input.representation,
      gid: input.gid,
      token: GalleryUrl.tryParse(input.galleryUrl)?.token,
      galleryUrl: input.galleryUrl,
      isOriginal: input.representation == 'original',
      galleryTitle: input.title,
      initialIndex: initialIndex.clamp(0, images.length - 1),
      pageCount: images.length,
      readProgressRecordStorageKey: input.gid.toString(),
      images: images,
    );
  }

  Future<CompletedContent?> _buildCompletedInput(
    String copyId,
    Map<String, dynamic> metadata, {
    bool includePendingReplacements = false,
  }) async {
    final copies = await repository.db
        .customSelect(
          'SELECT gid, representation, root_path, lifecycle FROM content_copy WHERE copy_id = ?',
          variables: [Variable.withString(copyId)],
        )
        .get();
    if (copies.isEmpty || copies.single.read<String>('lifecycle') != 'active') {
      throw StateError('Copy is unavailable: $copyId');
    }
    final pages = await repository.listPages(copyId);
    if (pages.isEmpty ||
        pages.length != metadata['expectedPages'] ||
        (!includePendingReplacements &&
            (await repository.listPageReplacements(copyId)).any(
              (item) =>
                  item.state != 'committed' &&
                  (item.newMetadataJson == null ||
                      (jsonDecode(item.newMetadataJson!)
                              as Map)['representationOnly'] !=
                          true),
            ))) {
      return null;
    }
    final root = copies.single.read<String>('root_path');
    final completed = <CompletedContentPage>[];
    for (var i = 0; i < pages.length; i++) {
      final page = pages[i];
      if (page.ordinal != i || page.state != 'completed') return null;
      final file = _pageFile(root, page.relativePath);
      final String hash =
          page.rawHash ??
          await sha256.bind(file.openRead()).first.then((d) => d.toString());
      final length = page.rawLength ?? await file.length();
      if (page.rawHash == null || page.rawLength == null) {
        await recordPage(
          copyId: copyId,
          ordinal: i,
          relativePath: page.relativePath,
          rawHash: hash,
          rawLength: length,
          mime: page.mime,
          width: page.width,
          height: page.height,
          sourcePageUrl: page.sourcePageUrl,
        );
      }
      completed.add(
        CompletedContentPage(
          ordinal: i,
          relativePath: page.relativePath,
          rawHash: hash,
          rawLength: length,
          mime: page.mime ?? _mime(file.path),
          width: page.width,
          height: page.height,
          sourcePageUrl: page.sourcePageUrl,
          codecProfile: page.codecProfile,
          objectHash: page.objectHash,
          storedLength: page.storedLength,
        ),
      );
    }
    final tags = (metadata['tags'] as List).map((tag) {
      final parts = tag as List;
      return PortableTag(parts[0] as String, parts[1] as String);
    }).toList();
    final lineage = (metadata['lineage'] as List).map((item) {
      final parts = item as List;
      return ManifestLineage(
        parts[0] as int,
        parts[1] as int,
        parts[2] as String,
      );
    }).toList();
    return CompletedContent(
      copyId: copyId,
      gid: copies.single.read<int>('gid'),
      representation: copies.single.read<String>('representation'),
      rootPath: root,
      galleryUrl: metadata['galleryUrl'] as String,
      title: metadata['title'] as String,
      providerMetadata:
          (metadata['providerMetadata'] as Map?)?.cast<String, Object?>() ??
          const {},
      collections:
          (metadata['collections'] as List?)?.cast<String>() ?? const [],
      tags: List.unmodifiable(tags),
      lineage: List.unmodifiable(lineage),
      pages: List.unmodifiable(completed),
    );
  }

  Future<CompletedContent> completeCopy(
    String copyId, {
    required String galleryUrl,
    required String title,
    List<PortableTag> tags = const [],
    List<ManifestLineage> lineage = const [],
    int? expectedPages,
    Map<String, Object?>? providerMetadata,
    List<String>? collections,
  }) async {
    final result = await repository.db.transaction(() async {
      final previous = await _metadataForCopy(copyId);
      final metadata = <String, dynamic>{
        ...previous,
        'providerMetadata': {
          ...?(previous['providerMetadata'] as Map?),
          ...?providerMetadata,
        },
        'collections': collections ?? previous['collections'] ?? <String>[],
        'galleryUrl': galleryUrl,
        'title': title,
        // A producer's original task tags are fallback facts. The owner may
        // already hold a later refresh, including an explicitly empty tag set.
        'tags':
            previous['tags'] ??
            tags.map((tag) => [tag.namespace, tag.name]).toList(),
        'lineage': lineage
            .map((item) => [item.fromGid, item.toGid, item.kind])
            .toList(),
        'expectedPages':
            expectedPages ?? (await repository.listPages(copyId)).length,
      };
      final input = await _buildCompletedInput(copyId, metadata);
      if (input == null) throw StateError('Copy is not complete: $copyId');
      await _storeMetadata(copyId, metadata);
      await repository.setCurrentCopy(copyId);
      return (input: input, metadata: metadata);
    });
    final input = result.input;
    final metadata = result.metadata;
    await _writeCompletedProjection(input, metadata);
    await onCompleted?.call(input);
    return input;
  }

  Future<Map<String, dynamic>> _metadataForCopy(String copyId) async {
    final row = await repository.db
        .customSelect(
          'SELECT metadata_json FROM content_copy WHERE copy_id = ?',
          variables: [Variable.withString(copyId)],
        )
        .getSingle();
    final json = row.readNullable<String>('metadata_json');
    return json == null ? {} : jsonDecode(json) as Map<String, dynamic>;
  }

  /// Persist producer facts even before completion; notify sync only for a
  /// complete snapshot. This also relays later group and tag changes.
  Future<void> updateMetadata(
    String copyId, {
    Map<String, Object?>? providerMetadata,
    List<String>? collections,
    List<PortableTag>? tags,
  }) async {
    final result = await repository.db.transaction(() async {
      final metadata = await _metadataForCopy(copyId);
      final previous = jsonEncode(metadata);
      if (providerMetadata != null)
        metadata['providerMetadata'] = {
          ...?(metadata['providerMetadata'] as Map?),
          ...providerMetadata,
        };
      if (collections != null) metadata['collections'] = collections;
      if (tags != null)
        metadata['tags'] = tags
            .map((tag) => [tag.namespace, tag.name])
            .toList();
      if (jsonEncode(metadata) == previous) return null;
      await _storeMetadata(copyId, metadata);
      if (metadata['expectedPages'] == null) return null;
      final input = await _buildCompletedInput(copyId, metadata);
      if (input == null) return null;
      return (input: input, metadata: metadata);
    });
    if (result == null) return;
    final input = result.input;
    final metadata = result.metadata;
    await _writeCompletedProjection(input, metadata);
    await onCompleted?.call(input);
  }

  Future<bool> _writeCompletedProjection(
    CompletedContent input,
    Map<String, dynamic> metadata, {
    bool flush = true,
    bool requireSuccess = false,
  }) async {
    final snapshot = await _taskSnapshot(
      input.copyId,
      input.gid,
      input.rootPath,
    );
    final manifest = PortableManifest(
      gid: input.gid,
      representation: input.representation,
      galleryUrl: input.galleryUrl,
      title: input.title,
      rawTitle: input.providerMetadata['rawTitle'] as String?,
      japaneseTitle: input.providerMetadata['japaneseTitle'] as String?,
      category: input.providerMetadata['category'] as String?,
      uploader: input.providerMetadata['uploader'] as String?,
      publishTime: input.providerMetadata['publishTime'] as String?,
      language: input.providerMetadata['language'] as String?,
      coverUrl: input.providerMetadata['coverUrl'] as String?,
      rating: (input.providerMetadata['rating'] as num?)?.toDouble(),
      collections: input.collections,
      tags: input.tags,
      lineage: input.lineage,
      codecProfiles: {
        for (final page in input.pages)
          if (ContentCodec.profileDefinitions[page.codecProfile]
              case final definition?)
            page.codecProfile!: definition,
      },
      pages: input.pages
          .map(
            (page) => PortablePage(
              rawHash: page.rawHash,
              rawLength: page.rawLength,
              objectHash: page.objectHash ?? page.rawHash,
              storedLength: page.storedLength ?? page.rawLength,
              codecProfile: page.codecProfile ?? 'raw',
              mime: page.mime,
              width: page.width,
              height: page.height,
              sourcePageUrl: page.sourcePageUrl,
            ),
          )
          .toList(),
    );
    final projection = DirectoryRecoveryProjection(
      copyId: input.copyId,
      taskKind: 'content',
      taskState: 'completed',
      taskJson: jsonEncode({...snapshot, ...metadata}),
      pages: input.pages
          .map(
            (page) => DirectoryRecoveryPage(
              page.ordinal,
              page.relativePath,
              'completed',
            ),
          )
          .toList(),
      completeManifest: manifest,
    );
    if (requireSuccess) {
      // Retirement drains this commit before marking the root for deletion.
      // Its installed-page projection must still finish during that drain.
      _pendingProjections[path.normalize(path.absolute(input.rootPath))] =
          projection;
    } else {
      scheduleProjection(input.rootPath, projection);
    }
    if (flush) {
      try {
        await flushProjection(input.rootPath);
        return true;
      } catch (error, stack) {
        if (requireSuccess) rethrow;
        log.error('Write local content projection failed', error, stack);
      }
    }
    return false;
  }

  Future<void> _storeMetadata(String copyId, Map<String, dynamic> metadata) =>
      repository.db.customStatement(
        'UPDATE content_copy SET metadata_json = ? WHERE copy_id = ?',
        [jsonEncode(metadata), copyId],
      );

  /// Returns whether a complete installed snapshot is available to project. Pending
  /// replacement work affects sync eligibility, not directory persistence.
  Future<bool> rebuildProjection(
    String copyId, {
    bool flush = true,
    bool requireSuccess = false,
  }) async => (await _rebuildProjection(
    copyId,
    flush: flush,
    requireSuccess: requireSuccess,
  )).complete;

  Future<({bool complete, bool written})> _rebuildProjection(
    String copyId, {
    bool flush = true,
    bool requireSuccess = false,
  }) async {
    final row = await repository.db
        .customSelect(
          'SELECT metadata_json FROM content_copy WHERE copy_id = ?',
          variables: [Variable.withString(copyId)],
        )
        .getSingleOrNull();
    final json = row?.readNullable<String>('metadata_json');
    if (json == null) {
      if (requireSuccess) await _writeInstalledProjection(copyId);
      return (complete: false, written: false);
    }
    final metadata = jsonDecode(json) as Map<String, dynamic>;
    final input = await _buildCompletedInput(
      copyId,
      metadata,
      includePendingReplacements: true,
    );
    if (input == null) {
      if (requireSuccess) await _writeInstalledProjection(copyId);
      return (complete: false, written: false);
    }
    final written = await _writeCompletedProjection(
      input,
      metadata,
      flush: flush,
      requireSuccess: requireSuccess,
    );
    return (complete: true, written: written);
  }

  /// Shared by task projections and owner journals; temporary download bytes
  /// are excluded until the owner has installed their raw identity.
  static PortablePage? residentPageFact(ContentPageRecord page) {
    if (page.state != 'completed' ||
        page.rawHash == null ||
        page.rawLength == null)
      return null;
    return PortablePage(
      rawHash: page.rawHash!,
      rawLength: page.rawLength!,
      objectHash: page.objectHash ?? page.rawHash!,
      storedLength: page.storedLength ?? page.rawLength!,
      codecProfile: page.codecProfile ?? 'raw',
      mime: page.mime ?? _mime(page.relativePath),
      width: page.width,
      height: page.height,
      sourcePageUrl: page.sourcePageUrl,
    );
  }

  /// A partial download has installed page facts but no complete gallery
  /// metadata yet. Preserve its task snapshot and project those sparse facts.
  Future<void> _writeInstalledProjection(String copyId) async {
    final owner = await repository.db
        .customSelect(
          'SELECT gid, root_path FROM content_copy WHERE copy_id = ?',
          variables: [Variable.withString(copyId)],
        )
        .getSingle();
    final root = path.normalize(path.absolute(owner.read<String>('root_path')));
    final target = File(path.join(root, '.content.sqlite'));
    final previous =
        _pendingProjections[root] ??
        (await target.exists() ? readProjection(root) : null);
    final records = await repository.listPages(copyId);
    final installed = <int, PortablePage>{
      for (final page in records)
        if (residentPageFact(page) case final fact?) page.ordinal: fact,
    };
    final localPages = <int, DirectoryRecoveryPage>{
      for (final page in previous?.pages ?? const <DirectoryRecoveryPage>[])
        page.ordinal: page,
      for (final page in records)
        page.ordinal: DirectoryRecoveryPage(
          page.ordinal,
          page.relativePath,
          page.state,
        ),
    };
    final snapshot = previous == null
        ? await _taskSnapshot(copyId, owner.read<int>('gid'), root)
        : null;
    final projection = DirectoryRecoveryProjection(
      copyId: copyId,
      taskKind:
          previous?.taskKind ??
          (snapshot!.containsKey('gallery')
              ? 'gallery'
              : snapshot.containsKey('archive')
              ? 'archive'
              : 'content'),
      taskState: previous?.taskState ?? 'partial',
      taskJson: previous?.taskJson ?? jsonEncode(snapshot),
      pages: (localPages.values.toList()
        ..sort((a, b) => a.ordinal.compareTo(b.ordinal))),
      residentPages: installed,
      codecProfiles: {
        for (final page in installed.values)
          if (ContentCodec.profileDefinitions[page.codecProfile]
              case final definition?)
            page.codecProfile: definition,
      },
    );
    _pendingProjections[root] = projection;
    await flushProjection(root);
  }

  Future<Map<String, dynamic>> _taskSnapshot(
    String copyId,
    int gid,
    String rootPath,
  ) async {
    final db = repository.db;
    final gallery = await (db.select(
      db.galleryDownloaded,
    )..where((t) => t.gid.equals(gid))).getSingleOrNull();
    if (gallery != null &&
        path.normalize(
              DownloadPathResolver.computeGalleryDownloadAbsolutePath(gallery),
            ) ==
            path.normalize(rootPath)) {
      final records = await (db.select(
        db.image,
      )..where((t) => t.gid.equals(gid))).get();
      final images = List<Map<String, dynamic>?>.filled(
        gallery.pageCount,
        null,
      );
      final residents = {
        for (final page in await repository.listPages(copyId))
          page.ordinal: page,
      };
      for (final image in records) {
        final resident = residents[image.serialNo];
        images[image.serialNo] = GalleryImage(
          url: image.url,
          path: resident == null
              ? image.path
              : path.relative(
                  path.join(rootPath, resident.relativePath),
                  from: pathService.getVisibleDir().path,
                ),
          originalImageUrl: image.originalImageUrl,
          imageHash: image.imageHash,
          downloadStatus: DownloadStatus.values[image.downloadStatusIndex],
        ).toJson();
      }
      return {'gallery': gallery.toJson(), 'images': images};
    }
    final archive = await (db.select(
      db.archiveDownloaded,
    )..where((t) => t.gid.equals(gid))).getSingleOrNull();
    if (archive != null &&
        path.normalize(
              archiveDownloadService.computeArchiveUnpackingPath(archive),
            ) ==
            path.normalize(rootPath)) {
      return {'archive': archive.toJson()};
    }
    return {};
  }

  Future<int> restoreContentDirectories() => _restoreContentDirectories();

  Future<int> _restoreContentDirectories({
    Set<String> excludeRoots = const {},
  }) async {
    final directory = Directory(downloadSetting.downloadPath.value);
    if (!await directory.exists()) return 0;
    var restored = 0;
    await for (final entry in directory.list()) {
      if (entry is! Directory ||
          excludeRoots.contains(path.normalize(path.absolute(entry.path))) ||
          path.basename(entry.path) == '.content-trash' ||
          path.basename(entry.path).startsWith('.content-relocation-') ||
          _relocationRoots.contains(path.normalize(entry.path)) ||
          _retiringRoots.contains(path.normalize(entry.path)))
        continue;
      final file = File(path.join(entry.path, '.content.sqlite'));
      if (!await file.exists()) continue;
      try {
        final projection = DirectoryRecoveryCodec.read(file);
        final manifest = projection.completeManifest;
        if (manifest == null) continue;
        final existing = await copyIdForRoot(entry.path);
        if (existing != null && await completedInput(existing) != null) {
          await rebuildProjection(existing);
          continue;
        }
        await restoreDirectoryProjection(
          entry.path,
          projection,
          gid: manifest.gid,
          representation: manifest.representation,
        );
        restored++;
      } catch (error, stack) {
        log.error(
          'Restore content directory failed: ${entry.path}',
          error,
          stack,
        );
      }
    }
    return restored;
  }

  Future<
    List<
      ({String copyId, int gid, String title, String rootPath, String cover})
    >
  >
  standaloneCopies() async {
    final rows = await repository.db.customSelect("""
      SELECT c.copy_id,c.gid,c.root_path,c.metadata_json,p.relative_path
      FROM content_copy c JOIN content_page p ON p.copy_id=c.copy_id AND p.ordinal=0
      WHERE c.lifecycle='active' AND c.metadata_json IS NOT NULL
    """).get();
    final taskRoots = <String>{
      for (final gallery
          in await repository.db.select(repository.db.galleryDownloaded).get())
        path.normalize(
          DownloadPathResolver.computeGalleryDownloadAbsolutePath(gallery),
        ),
      for (final archive
          in await repository.db.select(repository.db.archiveDownloaded).get())
        path.normalize(
          archiveDownloadService.computeArchiveUnpackingPath(archive),
        ),
    };
    final namespace = currentLibraryNamespace?.call();
    final cloudCopies = namespace == null
        ? <String>{}
        : await repository.cloudResidentCopyIds(
            namespace,
            rows.map((row) => row.read<String>('copy_id')),
          );
    return rows
        .where(
          (row) =>
              !cloudCopies.contains(row.read<String>('copy_id')) &&
              !taskRoots.contains(
                path.normalize(row.read<String>('root_path')),
              ),
        )
        .map((row) {
          final metadata = jsonDecode(row.read<String>('metadata_json')) as Map;
          return (
            copyId: row.read<String>('copy_id'),
            gid: row.read<int>('gid'),
            title: metadata['title'] as String,
            rootPath: row.read<String>('root_path'),
            cover: row.read<String>('relative_path'),
          );
        })
        .toList();
  }

  /// The lease covers one physical read, rather than an entire reading session.
  Future<T> withPageInput<T>(
    String copyId,
    int ordinal,
    Future<T> Function(File file) read,
  ) async {
    return withResidentPageInput(copyId, ordinal, (file, page) => read(file));
  }

  Future<T> withResidentPageInput<T>(
    String copyId,
    int ordinal,
    Future<T> Function(File file, ContentPageRecord page) read,
  ) async {
    final gate = _gate(copyId, ordinal);
    while (gate.closed || _relocationGates.containsKey(copyId)) {
      if (_retiring.contains(copyId)) throw StateError('Copy is retiring');
      final relocation = _relocationGates[copyId];
      await (relocation?.future ?? gate.wait());
    }
    if (_retiring.contains(copyId)) throw StateError('Copy is retiring');
    gate.readers++;
    try {
      final page = await repository.getPage(copyId, ordinal);
      return await read(
        _pageFile(await rootPath(copyId), page.relativePath),
        page,
      );
    } finally {
      gate.readers--;
      gate.notify();
    }
  }

  Future<PageReplacementRecord> enqueuePageReplacement({
    required String copyId,
    required int ordinal,
    required String newRelativePath,
    bool representationOnly = false,
  }) async {
    if (_retiring.contains(copyId)) throw StateError('Copy is retiring');
    if (isRelocating(copyId)) throw StateError('Copy is relocating');
    final old = await repository.getPage(copyId, ordinal);
    final root = await rootPath(copyId);
    final pending = await repository.listPageReplacements(copyId);
    final id = const Uuid().v4();
    final oldPath = _pageFile(root, old.relativePath).path;
    final newPath = _pageFile(root, newRelativePath).path;
    final tempPath = path.join(root, '.content-work', '$id.tmp');
    final retainedPath = path.join(root, '.content-work', '$id.old');
    await Directory(path.dirname(tempPath)).create(recursive: true);
    final replacement = await repository.db.transaction(() async {
      final rows = await repository.db
          .customSelect(
            'SELECT lifecycle FROM content_copy WHERE copy_id = ?',
            variables: [Variable.withString(copyId)],
          )
          .get();
      if (_retiring.contains(copyId) ||
          rows.isEmpty ||
          rows.single.read<String>('lifecycle') != 'active') {
        throw StateError('Copy is retiring');
      }
      final queued = await repository.enqueuePageReplacement(
        replacementId: id,
        copyId: copyId,
        ordinal: ordinal,
        oldPath: oldPath,
        newPath: newPath,
        tempPath: tempPath,
        retainedPath: retainedPath,
        representationOnly: representationOnly,
      );
      return queued;
    });
    _replacementDone.putIfAbsent(id, Completer<void>.new);
    for (final previous in pending.where((item) => item.ordinal == ordinal)) {
      _replacementDone.putIfAbsent(previous.replacementId, Completer<void>.new);
    }
    return replacement;
  }

  Future<void> finishDownloadedReplacement(
    String replacementId, {
    required String rawHash,
    required int rawLength,
    String? mime,
    int? width,
    int? height,
  }) async {
    final replacement = await _replacement(replacementId);
    final earlier = (await repository.listPageReplacements(replacement.copyId))
        .where(
          (item) =>
              item.ordinal == replacement.ordinal &&
              item.queueOrder < replacement.queueOrder,
        );
    for (final item in earlier) {
      await _replacementDone
          .putIfAbsent(item.replacementId, Completer<void>.new)
          .future;
    }
    if ((await _replacement(replacementId)).state == 'completed') return;
    final old = await repository.getPage(
      replacement.copyId,
      replacement.ordinal,
    );
    final oldHash =
        old.rawHash ??
        await sha256
            .bind(File(replacement.oldPath).openRead())
            .first
            .then((d) => d.toString());
    if (old.rawHash == null) {
      await repository.putPage(
        ContentPageRecord(
          copyId: old.copyId,
          ordinal: old.ordinal,
          relativePath: old.relativePath,
          rawHash: oldHash,
          rawLength: old.rawLength ?? await File(replacement.oldPath).length(),
          mime: old.mime,
          width: old.width,
          height: old.height,
          state: old.state,
        ),
      );
    }
    if (oldHash == rawHash) {
      final temporary = File(replacement.tempPath);
      if (await temporary.exists()) await temporary.delete();
      await repository.finishUnchangedPageReplacement(replacementId);
      _replacementDone.remove(replacementId)?.complete();
      await _notifyAfterReplacements(replacement.copyId);
      return;
    }
    await repository.db.transaction(() async {
      await repository.setPageReplacementReady(
        replacementId,
        jsonEncode({
          'rawHash': rawHash,
          'rawLength': rawLength,
          'mime': mime ?? _mime(replacement.newPath),
          'width': width,
          'height': height,
        }),
      );
      await _rolloverContentWork(replacement.copyId);
    });
    await commitPageReplacement(replacementId);
  }

  Future<void> commitPageReplacement(String replacementId) {
    final existing = _replacementCommits[replacementId];
    if (existing != null) return existing;
    late final Future<void> future;
    future = _commitPageReplacement(replacementId).whenComplete(() {
      if (identical(_replacementCommits[replacementId], future)) {
        _replacementCommits.remove(replacementId);
      }
    });
    _replacementCommits[replacementId] = future;
    return future;
  }

  Future<void> _commitPageReplacement(String replacementId) async {
    var replacement = await _replacement(replacementId);
    final earlier = (await repository.listPageReplacements(replacement.copyId))
        .where(
          (item) =>
              item.ordinal == replacement.ordinal &&
              item.queueOrder < replacement.queueOrder,
        );
    for (final item in earlier) {
      await _replacementDone
          .putIfAbsent(item.replacementId, Completer<void>.new)
          .future;
    }
    replacement = await _replacement(replacementId);
    if (replacement.state == 'completed') return;
    if (replacement.state == 'committing') {
      final representationOnly =
          (jsonDecode(replacement.newMetadataJson!)
              as Map)['representationOnly'] ==
          true;
      if (!representationOnly) {
        await _rolloverContentWork(replacement.copyId);
        await _prepareMutation(replacement.copyId, replacement: true);
      }
      final gate = _gate(replacement.copyId, replacement.ordinal);
      gate.closed = true;
      var pageCommitted = false;
      try {
        while (gate.readers > 0) await gate.wait();
        // A preceding queued representation may have changed the physical
        // path while this download was in flight. Resolve its current owner.
        final latest = await repository.getPage(
          replacement.copyId,
          replacement.ordinal,
        );
        if (!await File(replacement.retainedPath).exists()) {
          final actualOld = _pageFile(
            await rootPath(replacement.copyId),
            latest.relativePath,
          ).path;
          if (actualOld != replacement.oldPath) {
            await repository.db.customStatement(
              'UPDATE content_page_replacement SET old_path = ? WHERE replacement_id = ?',
              [actualOld, replacementId],
            );
            replacement = await _replacement(replacementId);
          }
        }
        final old = File(replacement.oldPath);
        final temporary = File(replacement.tempPath);
        final retained = File(replacement.retainedPath);
        final next = File(replacement.newPath);
        if (await old.exists() && !await retained.exists()) {
          await retained.parent.create(recursive: true);
          await old.rename(retained.path);
        }
        if (await temporary.exists()) {
          await next.parent.create(recursive: true);
          await temporary.rename(next.path);
        }
        if (!await next.exists())
          throw StateError('Missing replacement page ${next.path}');
        final data =
            jsonDecode(replacement.newMetadataJson!) as Map<String, dynamic>;
        await repository.commitPageReplacement(
          replacementId,
          ContentPageRecord(
            copyId: replacement.copyId,
            ordinal: replacement.ordinal,
            relativePath: path.relative(
              next.path,
              from: await rootPath(replacement.copyId),
            ),
            rawHash: data['rawHash'] as String,
            rawLength: data['rawLength'] as int,
            mime: data['mime'] as String?,
            width: data['width'] as int?,
            height: data['height'] as int?,
            state: 'completed',
            codecProfile: data['codecProfile'] as String?,
            objectHash: data['objectHash'] as String?,
            storedLength: data['storedLength'] as int?,
          ),
        );
        pageCommitted = true;
        _managedPages.remove(path.normalize(replacement.oldPath));
        _indexManagedPage(
          path.normalize(next.path),
          ManagedPageLocation(
            replacement.copyId,
            replacement.ordinal,
            data['rawHash'] as String,
          ),
        );
      } finally {
        if (pageCommitted) {
          gate.closed = false;
          gate.notify();
        }
      }
      replacement = await _replacement(replacementId);
    }
    if (replacement.state == 'committed') {
      final representationOnly =
          (jsonDecode(replacement.newMetadataJson!)
              as Map)['representationOnly'] ==
          true;
      await rebuildProjection(replacement.copyId, requireSuccess: true);
      final retained = File(replacement.retainedPath);
      if (await retained.exists()) await retained.delete();
      await repository.finishPageReplacement(replacementId);
      _replacementDone.remove(replacementId)?.complete();
      if (!representationOnly)
        await _notifyAfterReplacements(replacement.copyId);
    }
  }

  Future<PageReplacementRecord> _replacement(String id) async {
    final rows = await repository.db
        .customSelect(
          'SELECT copy_id FROM content_page_replacement WHERE replacement_id = ?',
          variables: [Variable.withString(id)],
        )
        .get();
    if (rows.isEmpty) throw StateError('Unknown replacement $id');
    return (await repository.listPageReplacements(
      rows.single.read<String>('copy_id'),
      includeFinished: true,
    )).singleWhere((item) => item.replacementId == id);
  }

  Future<void> _notifyAfterReplacements(String copyId) async {
    if (_retiring.contains(copyId)) return;
    if ((await repository.listPageReplacements(copyId)).isNotEmpty) return;
    final input = await completedInput(copyId);
    if (input == null) return;
    await rebuildProjection(copyId);
    await onCompleted?.call(input);
  }

  Future<void> retireCopy(String copyId) async {
    if (isRelocating(copyId)) throw StateError('Copy is relocating');
    final ongoing = _retirementFutures[copyId];
    if (ongoing != null) return ongoing;
    final future = _retireCopy(copyId);
    _retirementFutures[copyId] = future;
    try {
      await future;
    } finally {
      _retirementFutures.remove(copyId);
    }
  }

  Future<void> _retireCopy(String copyId) async {
    if (!_retiring.add(copyId)) {
      final rows = await repository.db
          .customSelect(
            'SELECT root_path, trash_path, lifecycle FROM content_copy WHERE copy_id = ?',
            variables: [Variable.withString(copyId)],
          )
          .get();
      if (rows.isNotEmpty &&
          rows.single.read<String>('lifecycle') == 'retiring') {
        await _finishRetirement(
          copyId,
          rows.single.read<String>('root_path'),
          rows.single.readNullable<String>('trash_path'),
        );
      }
      return;
    }
    try {
      await onBeforeRetirement?.call(copyId);
      await _prepareMutation(copyId);
      final pending = await repository.listPageReplacements(copyId);
      for (final item in pending) {
        await _replacementDone
            .putIfAbsent(item.replacementId, Completer<void>.new)
            .future;
      }
      final root = await rootPath(copyId);
      final trash = path.join(path.dirname(root), '.content-trash', copyId);
      await repository.markCopyRetiring(copyId, trash);
      await _finishRetirement(copyId, root, trash);
    } catch (_) {
      final rows = await repository.db
          .customSelect(
            'SELECT lifecycle FROM content_copy WHERE copy_id = ?',
            variables: [Variable.withString(copyId)],
          )
          .get();
      if (rows.isNotEmpty &&
          rows.single.read<String>('lifecycle') == 'active') {
        _retiring.remove(copyId);
      }
      rethrow;
    }
  }

  /// Apply a published work item's release disposition to its
  /// exact copy. Enqueue and this claim share the runtime database transaction.
  Future<bool> executeRelease(
    String copyId,
    String workItemId,
    String manifestId,
  ) async {
    if (_retiring.contains(copyId) || isRelocating(copyId)) return false;
    final work = await repository.getWorkItem(workItemId);
    if (work == null ||
        work.copyId != copyId ||
        (work.kind != 'content' && work.kind != 'revision') ||
        work.state != 'completed' ||
        work.pendingManifestId != manifestId ||
        work.finishAction != 'release') {
      return false;
    }
    if (isRelocating(copyId)) return false;
    _retiring.add(copyId);
    var claimed = false;
    try {
      if ((await repository.listPageReplacements(copyId)).isNotEmpty) {
        return false;
      }
      await _prepareMutation(copyId);
      final root = await rootPath(copyId);
      final trash = path.join(path.dirname(root), '.content-trash', copyId);
      claimed = await repository.db.transaction(() async {
        final current = await repository.db
            .customSelect(
              '''
          SELECT w.finish_action, w.pending_manifest_id, w.state,
                 c.lifecycle
          FROM content_work_item w JOIN content_copy c ON c.copy_id = w.copy_id
          WHERE w.work_item_id = ? AND w.copy_id = ? AND w.kind IN ('content', 'revision')
        ''',
              variables: [
                Variable.withString(workItemId),
                Variable.withString(copyId),
              ],
            )
            .get();
        if (current.isEmpty ||
            current.single.read<String>('finish_action') != 'release' ||
            current.single.readNullable<String>('pending_manifest_id') !=
                manifestId ||
            current.single.read<String>('state') != 'completed' ||
            current.single.read<String>('lifecycle') != 'active') {
          return false;
        }
        final pending = await repository.db
            .customSelect(
              '''
          SELECT 1 FROM content_page_replacement
          WHERE copy_id = ? AND state != 'completed' LIMIT 1
        ''',
              variables: [Variable.withString(copyId)],
            )
            .get();
        if (pending.isNotEmpty) return false;
        await repository.markCopyRetiring(copyId, trash);
        return true;
      });
      if (!claimed) return false;
      await _removeRetiredDownloadTask(root);
      await _finishRetirement(copyId, root, trash);
      return true;
    } finally {
      if (!claimed) _retiring.remove(copyId);
    }
  }

  /// Cleanup follows the exact retired root. A newer download of the same gid
  /// may already have a different root and must remain in the local list.
  Future<void> _removeRetiredDownloadTask(String root) async {
    for (final gallery in galleryDownloadService.galleries.toList()) {
      final candidate = DownloadPathResolver.computeGalleryDownloadAbsolutePath(
        gallery.toGalleryDownloadedData(),
      );
      if (path.normalize(candidate) == path.normalize(root)) {
        await galleryDownloadService.deleteGallery(
          gallery,
          deleteImages: false,
        );
      }
    }
    for (final archive in archiveDownloadService.archives.toList()) {
      if (path.normalize(
            archiveDownloadService.computeArchiveUnpackingPath(archive),
          ) ==
          path.normalize(root)) {
        await archiveDownloadService.deleteArchive(archive.gid);
      }
    }
  }

  /// Explicit task deletion stops downloaded-but-uncommitted page attempts.
  /// The download owner cancels and joins their network tasks before calling.
  Future<void> abandonDownloadingReplacements(String copyId) async {
    for (final item in await repository.listPageReplacements(copyId)) {
      if (item.state != 'downloading') continue;
      final temporary = File(item.tempPath);
      if (await temporary.exists()) await temporary.delete();
      await repository.finishUnchangedPageReplacement(item.replacementId);
      _replacementDone.remove(item.replacementId)?.complete();
    }
  }

  Future<void> finishCommittingReplacements(String copyId) async {
    while (true) {
      final pending = await repository.listPageReplacements(copyId);
      if (pending.isEmpty) return;
      final head = pending.first;
      if (head.state == 'downloading') {
        throw StateError('Replacement download is still pending');
      }
      await commitPageReplacement(head.replacementId);
    }
  }

  Future<void> _prepareMutation(
    String copyId, {
    bool replacement = false,
  }) async {
    if (onBeforeMutation case final callback?) {
      await callback(copyId);
    } else if (!replacement) {
      // On startup there are no in-flight network requests to settle.
      await repository.db.customStatement(
        '''
        UPDATE content_work_item SET state = 'cancelled', finish_action = 'keep',
          updated_at = ?
        WHERE copy_id = ? AND kind IN ('content', 'revision')
          AND state NOT IN ('completed', 'cancelled')
      ''',
        [DateTime.now().toUtc().toIso8601String(), copyId],
      );
    }
  }

  /// Page mutations replace active frozen input while preserving scheduling
  /// source. Paused and failed decisions remain until an explicit resume.
  Future<void> _rolloverContentWork(String copyId) async {
    await repository.db.transaction(() async {
      final active = await repository.db
          .customSelect(
            "SELECT target_namespace, source, finish_action FROM content_work_item WHERE copy_id = ? "
            "AND kind IN ('content', 'revision') AND state IN ('queued', 'running', 'publishing') "
            "ORDER BY created_at, work_item_id",
            variables: [Variable.withString(copyId)],
          )
          .get();
      if (active.isEmpty) return;
      final sources = {
        for (final row in active)
          row.read<String>('target_namespace'): (
            source: row.read<String>('source'),
            finishAction: row.read<String>('finish_action'),
          ),
      };
      final now = DateTime.now().toUtc().toIso8601String();
      await repository.db.customStatement(
        "UPDATE content_work_item SET state = 'cancelled', finish_action = 'keep', updated_at = ? "
        "WHERE copy_id = ? AND kind IN ('content', 'revision') AND state IN ('queued', 'running', 'publishing')",
        [now, copyId],
      );
      for (final entry in sources.entries) {
        final waiting = await repository.db
            .customSelect(
              "SELECT work_item_id FROM content_work_item WHERE copy_id = ? AND target_namespace = ? "
              "AND kind IN ('content', 'revision') AND state = 'waiting_input' LIMIT 1",
              variables: [
                Variable.withString(copyId),
                Variable.withString(entry.key),
              ],
            )
            .get();
        if (waiting.isNotEmpty) continue;
        await repository
            .createWorkItem(
              kind: 'content',
              targetNamespace: entry.key,
              copyId: copyId,
              inputJson: jsonEncode({'copyId': copyId}),
              source: entry.value.source,
              finishAction: entry.value.finishAction,
            )
            .then(
              (work) => repository.updateWorkItemState(
                work.workItemId,
                'waiting_input',
              ),
            );
      }
    });
  }

  Future<void> _finishRetirement(
    String copyId,
    String root,
    String? trashPath,
  ) async {
    if (trashPath == null) throw StateError('Missing trash path for $copyId');
    final projectionRoot = path.normalize(path.absolute(root));
    _retiringRoots.add(projectionRoot);
    _projectionTimers.remove(projectionRoot)?.cancel();
    _pendingProjections.remove(projectionRoot);
    await _projectionWrites[projectionRoot];
    final prefix = '$copyId:';
    final gates = _pageGates.entries.where(
      (entry) => entry.key.startsWith(prefix),
    );
    for (final entry in gates) {
      entry.value.closed = true;
      entry.value.notify();
    }
    for (final entry in gates) {
      while (entry.value.readers > 0) await entry.value.wait();
    }
    await _cancelRetiredRelocations(copyId, root);
    final original = Directory(root);
    final trash = Directory(trashPath);
    if (await original.exists()) {
      await trash.parent.create(recursive: true);
      if (await trash.exists())
        throw StateError('Trash path already occupied: $trashPath');
      await original.rename(trashPath);
    }
    if (await trash.exists()) await trash.delete(recursive: true);
    _copiesByRoot.remove(path.normalize(root));
    _managedPages.removeWhere((_, location) => location.copyId == copyId);
    _managedPagesByIdentity.removeWhere((key, _) => key.$1 == copyId);
    await repository.updateCopyCleanupState(copyId, 'completed');
    onRetired?.call(copyId);
  }

  /// Replace the local SQLite projection with one atomic same-directory rename.
  void scheduleProjection(
    String rootPath,
    DirectoryRecoveryProjection projection, {
    bool flush = false,
  }) {
    rootPath = path.normalize(path.absolute(rootPath));
    if (_retiring.contains(projection.copyId) ||
        _retiringRoots.contains(rootPath))
      return;
    _pendingProjections[rootPath] = projection;
    if (flush) {
      _projectionTimers.remove(rootPath)?.cancel();
      unawaited(flushProjection(rootPath));
    } else {
      _projectionTimers.putIfAbsent(
        rootPath,
        () => Timer(const Duration(seconds: 5), () {
          _projectionTimers.remove(rootPath);
          unawaited(flushProjection(rootPath));
        }),
      );
    }
  }

  Future<void> flushProjection(String rootPath) async {
    rootPath = path.normalize(path.absolute(rootPath));
    _projectionTimers.remove(rootPath)?.cancel();
    if (_retiringRoots.contains(rootPath)) {
      _pendingProjections.remove(rootPath);
      await _projectionWrites[rootPath];
      return;
    }
    final projection = _pendingProjections.remove(rootPath);
    if (projection == null) {
      await _projectionWrites[rootPath];
      return;
    }
    final previous = _projectionWrites[rootPath] ?? Future<void>.value();
    final write = previous.then((_) async {
      final target = File(path.join(rootPath, '.content.sqlite'));
      if (await target.exists()) {
        await DirectoryRecoveryCodec.updateExistingAsync(target, projection);
      } else {
        final staging = File('${target.path}.tmp');
        if (await staging.exists()) await staging.delete();
        await DirectoryRecoveryCodec.writeNewAsync(staging, projection);
        await staging.rename(target.path);
      }
    });
    _projectionWrites[rootPath] = write;
    try {
      await write;
    } finally {
      if (identical(_projectionWrites[rootPath], write)) {
        _projectionWrites.remove(rootPath);
      }
    }
  }

  DirectoryRecoveryProjection readProjection(String rootPath) =>
      DirectoryRecoveryCodec.read(File(path.join(rootPath, '.content.sqlite')));

  static String _mime(String filename) {
    switch (path.extension(filename).toLowerCase()) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.gif':
        return 'image/gif';
      case '.avif':
        return 'image/avif';
      default:
        return 'application/octet-stream';
    }
  }

  static File _pageFile(String root, String relativePath) {
    final normalizedRoot = path.normalize(path.absolute(root));
    final absolute = path.normalize(path.join(normalizedRoot, relativePath));
    if (!path.isWithin(normalizedRoot, absolute)) {
      throw StateError('Page escapes its content directory: $relativePath');
    }
    return File(absolute);
  }
}
