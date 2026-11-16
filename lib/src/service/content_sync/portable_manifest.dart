import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:sqlite3/sqlite3.dart';

/// Only portable, immutable content facts belong in this model. Local paths,
/// credentials, task states, and short-lived URLs stay in the runtime database.
class PortableManifest {
  static const formatVersion = 1;

  final int gid;
  final String representation;
  final String galleryUrl;
  final String title;
  final String? rawTitle;
  final String? japaneseTitle;
  final String? category;
  final String? uploader;
  final String? publishTime;
  final String? language;
  final String? coverUrl;
  final double? rating;
  final List<String> collections;
  final List<PortableTag> tags;
  final List<PortablePage> pages;
  final PortableThumbnail? thumbnail;
  final List<ManifestLineage> lineage;
  final List<String> supersedes;
  final Map<String, Map<String, Object?>> codecProfiles;

  const PortableManifest({
    required this.gid,
    required this.representation,
    required this.galleryUrl,
    required this.title,
    required this.tags,
    required this.pages,
    this.rawTitle,
    this.japaneseTitle,
    this.category,
    this.uploader,
    this.publishTime,
    this.language,
    this.coverUrl,
    this.rating,
    this.collections = const [],
    this.thumbnail,
    this.lineage = const [],
    this.supersedes = const [],
    this.codecProfiles = const {},
  });

  String toPortableJson() => _canonicalJson({
    'gid': gid,
    'representation': representation,
    'galleryUrl': galleryUrl,
    'title': title,
    ...providerMetadata,
    'collections': collections,
    'tags': tags.map((tag) => [tag.namespace, tag.name]).toList(),
    'pages': pages
        .map(
          (page) => {
            'rawHash': page.rawHash,
            'rawLength': page.rawLength,
            'objectHash': page.objectHash,
            'storedLength': page.storedLength,
            'codecProfile': page.codecProfile,
            'mime': page.mime,
            'width': page.width,
            'height': page.height,
            'sourcePageUrl': page.sourcePageUrl,
          },
        )
        .toList(),
    'thumbnail': thumbnail == null
        ? null
        : {
            'rawHash': thumbnail!.rawHash,
            'rawLength': thumbnail!.rawLength,
            'objectHash': thumbnail!.objectHash,
            'mime': thumbnail!.mime,
          },
    'lineage': lineage
        .map((edge) => [edge.fromGid, edge.toGid, edge.kind])
        .toList(),
    'supersedes': supersedes,
    'codecProfiles': codecProfiles,
  });

  factory PortableManifest.fromPortableJson(String source) {
    final data = jsonDecode(source) as Map<String, dynamic>;
    final thumbnail = data['thumbnail'] as Map<String, dynamic>?;
    final manifest = PortableManifest(
      gid: data['gid'] as int,
      representation: data['representation'] as String,
      galleryUrl: data['galleryUrl'] as String,
      title: data['title'] as String,
      rawTitle: data['rawTitle'] as String?,
      japaneseTitle: data['japaneseTitle'] as String?,
      category: data['category'] as String?,
      uploader: data['uploader'] as String?,
      publishTime: data['publishTime'] as String?,
      language: data['language'] as String?,
      coverUrl: data['coverUrl'] as String?,
      rating: (data['rating'] as num?)?.toDouble(),
      collections: (data['collections'] as List?)?.cast<String>() ?? const [],
      tags: (data['tags'] as List).map((entry) {
        final tag = entry as List;
        return PortableTag(tag[0] as String, tag[1] as String);
      }).toList(),
      pages: (data['pages'] as List).map((entry) {
        final page = entry as Map<String, dynamic>;
        return PortablePage(
          rawHash: page['rawHash'] as String,
          rawLength: page['rawLength'] as int,
          objectHash: page['objectHash'] as String,
          storedLength: page['storedLength'] as int,
          codecProfile: page['codecProfile'] as String,
          mime: page['mime'] as String,
          width: page['width'] as int?,
          height: page['height'] as int?,
          sourcePageUrl: page['sourcePageUrl'] as String?,
        );
      }).toList(),
      thumbnail: thumbnail == null
          ? null
          : PortableThumbnail(
              rawHash: thumbnail['rawHash'] as String,
              rawLength: thumbnail['rawLength'] as int,
              objectHash: thumbnail['objectHash'] as String,
              mime: thumbnail['mime'] as String,
            ),
      lineage: (data['lineage'] as List).map((entry) {
        final edge = entry as List;
        return ManifestLineage(
          edge[0] as int,
          edge[1] as int,
          edge[2] as String,
        );
      }).toList(),
      supersedes: (data['supersedes'] as List).cast<String>(),
      codecProfiles: (data['codecProfiles'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, (value as Map).cast<String, Object?>()),
      ),
    );
    manifest.validate();
    return manifest;
  }

  /// Website facts are replaced together; personal display fields stay separate.
  Map<String, Object?> get providerMetadata => {
    'rawTitle': rawTitle,
    'japaneseTitle': japaneseTitle,
    'category': category,
    'uploader': uploader,
    'publishTime': publishTime,
    'language': language,
    'coverUrl': coverUrl,
    'rating': rating,
  };

  Map<String, Object?> get userFields => {
    'title': title,
    'collections': collections,
  };

  PortableManifest copyWith({
    String? title,
    List<PortableTag>? tags,
    List<String>? collections,
    Map<String, Object?>? providerMetadata,
    List<ManifestLineage>? lineage,
    List<String>? supersedes,
    PortableThumbnail? thumbnail,
  }) {
    final provider = providerMetadata ?? this.providerMetadata;
    return PortableManifest(
      gid: gid,
      representation: representation,
      galleryUrl: galleryUrl,
      title: title ?? this.title,
      tags: tags ?? this.tags,
      collections: collections ?? this.collections,
      rawTitle: provider['rawTitle'] as String?,
      japaneseTitle: provider['japaneseTitle'] as String?,
      category: provider['category'] as String?,
      uploader: provider['uploader'] as String?,
      publishTime: provider['publishTime'] as String?,
      language: provider['language'] as String?,
      coverUrl: provider['coverUrl'] as String?,
      rating: (provider['rating'] as num?)?.toDouble(),
      pages: pages,
      thumbnail: thumbnail ?? this.thumbnail,
      lineage: lineage ?? this.lineage,
      supersedes: supersedes ?? this.supersedes,
      codecProfiles: codecProfiles,
    );
  }

  bool samePagesAs(PortableManifest other) =>
      gid == other.gid &&
      representation == other.representation &&
      _canonicalJson(
            pages.map((page) => [page.rawHash, page.rawLength]).toList(),
          ) ==
          _canonicalJson(
            other.pages.map((page) => [page.rawHash, page.rawLength]).toList(),
          );

  /// Compare business facts directly; storage representation and ancestry of
  /// revisions do not cause duplicate heads in the cloud list.
  bool businessEquivalentTo(PortableManifest other) =>
      _canonicalJson(_businessFields()) ==
      _canonicalJson(other._businessFields());

  Map<String, Object?> _businessFields() => {
    'gid': gid,
    'representation': representation,
    'galleryUrl': galleryUrl,
    'title': title,
    ...providerMetadata,
    'collections': collections.toSet().toList()..sort(),
    'tags': tags.map((tag) => '${tag.namespace}\u0000${tag.name}').toList()
      ..sort(),
    'pages': pages
        .map(
          (page) => [
            page.rawHash,
            page.rawLength,
            page.mime,
            page.width,
            page.height,
            page.sourcePageUrl,
          ],
        )
        .toList(),
    'thumbnail': thumbnail == null
        ? null
        : [thumbnail!.rawHash, thumbnail!.rawLength, thumbnail!.mime],
    'lineage':
        lineage
            .map(
              (edge) => '${edge.fromGid}\u0000${edge.toGid}\u0000${edge.kind}',
            )
            .toList()
          ..sort(),
  };

  void validate() {
    if (gid <= 0) {
      throw const FormatException('Invalid gid');
    }
    if (!const {
      'original',
      'resampled',
      'unspecified',
    }.contains(representation)) {
      throw const FormatException('Invalid representation');
    }
    if (galleryUrl.isEmpty) {
      throw const FormatException('Missing stable gallery URL');
    }
    if (pages.isEmpty) {
      throw const FormatException('Manifest requires a complete page list');
    }
    for (final page in pages) {
      _requireHash(page.rawHash);
      _requireHash(page.objectHash);
      if (page.rawLength < 0 || page.storedLength < 0) {
        throw const FormatException('Negative page length');
      }
      if (page.codecProfile != 'raw' &&
          !codecProfiles.containsKey(page.codecProfile)) {
        throw FormatException('Undefined codec profile ${page.codecProfile}');
      }
      if (page.codecProfile == 'raw' &&
          (page.rawHash != page.objectHash ||
              page.rawLength != page.storedLength)) {
        throw const FormatException('Raw page object differs from source');
      }
    }
    if (thumbnail != null) {
      _requireHash(thumbnail!.rawHash);
      if (thumbnail!.rawHash != thumbnail!.objectHash ||
          thumbnail!.rawLength < 0) {
        throw const FormatException('Thumbnail must reference a raw object');
      }
    }
    for (final id in supersedes) {
      _requireHash(id);
    }
    if (supersedes.toSet().length != supersedes.length) {
      throw const FormatException('Duplicate supersedes');
    }
  }

  static void _requireHash(String hash) {
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(hash)) {
      throw FormatException('Invalid SHA-256: $hash');
    }
  }
}

class PortableTag {
  final String namespace;
  final String name;
  const PortableTag(this.namespace, this.name);
}

class PortablePage {
  final String rawHash;
  final int rawLength;
  final String objectHash;
  final int storedLength;
  final String codecProfile;
  final String mime;
  final int? width;
  final int? height;
  final String? sourcePageUrl;

  const PortablePage({
    required this.rawHash,
    required this.rawLength,
    required this.objectHash,
    required this.storedLength,
    required this.codecProfile,
    required this.mime,
    this.width,
    this.height,
    this.sourcePageUrl,
  });
}

class PortableThumbnail {
  final String rawHash;
  final int rawLength;
  final String objectHash;
  final String mime;
  const PortableThumbnail({
    required this.rawHash,
    required this.rawLength,
    required this.objectHash,
    required this.mime,
  });
}

class ManifestLineage {
  final int fromGid;
  final int toGid;
  final String kind;
  const ManifestLineage(this.fromGid, this.toGid, this.kind);
}

class ManifestArtifact {
  final File file;
  final String manifestId;
  const ManifestArtifact(this.file, this.manifestId);
}

/// The final closed SQLite file is the immutable artifact. Its bytes are the ID.
class PortableManifestCodec {
  static Future<ManifestArtifact> writeAsync(
    File file,
    PortableManifest manifest,
  ) async {
    final filePath = file.path;
    final id = await Isolate.run(
      () => write(File(filePath), manifest).manifestId,
    );
    return ManifestArtifact(file, id);
  }

  static Future<PortableManifest> readAsync(File file) {
    final filePath = file.path;
    return Isolate.run(() => read(File(filePath)));
  }

  static const portableApplicationId = 0x48434d31; // HCM1
  static const directoryApplicationId = 0x48435231; // HCR1
  /// Shared portable table layout for remote manifests and directory recovery.
  static void createSchema(Database db) {
    db.execute(
      'CREATE TABLE metadata (gid INTEGER NOT NULL, representation TEXT NOT NULL, gallery_url TEXT NOT NULL, title TEXT NOT NULL)',
    );
    db.execute(
      'CREATE TABLE display_metadata (provider_json TEXT NOT NULL, collections_json TEXT NOT NULL)',
    );
    db.execute(
      'CREATE TABLE tag (ordinal INTEGER PRIMARY KEY, namespace TEXT NOT NULL, name TEXT NOT NULL)',
    );
    db.execute(
      'CREATE TABLE page (ordinal INTEGER PRIMARY KEY, raw_hash TEXT NOT NULL, raw_length INTEGER NOT NULL, object_hash TEXT NOT NULL, stored_length INTEGER NOT NULL, codec_profile TEXT NOT NULL, mime TEXT NOT NULL, width INTEGER, height INTEGER, source_page_url TEXT)',
    );
    db.execute(
      'CREATE TABLE thumbnail (raw_hash TEXT NOT NULL, raw_length INTEGER NOT NULL, object_hash TEXT NOT NULL, mime TEXT NOT NULL)',
    );
    db.execute(
      'CREATE TABLE lineage (ordinal INTEGER PRIMARY KEY, from_gid INTEGER NOT NULL, to_gid INTEGER NOT NULL, kind TEXT NOT NULL)',
    );
    db.execute('CREATE TABLE supersedes (manifest_id TEXT PRIMARY KEY)');
    db.execute(
      'CREATE TABLE codec_profile (profile_id TEXT PRIMARY KEY, definition_json TEXT NOT NULL)',
    );
  }

  static ManifestArtifact write(File file, PortableManifest manifest) {
    manifest.validate();
    if (file.existsSync()) {
      throw StateError('Manifest artifact already exists: ${file.path}');
    }
    file.parent.createSync(recursive: true);
    final db = sqlite3.open(file.path);
    var completed = false;
    try {
      db.execute('PRAGMA journal_mode = DELETE');
      db.execute('BEGIN IMMEDIATE');
      try {
        db.execute('PRAGMA application_id = $portableApplicationId');
        db.execute('PRAGMA user_version = ${PortableManifest.formatVersion}');
        createSchema(db);
        _insertManifest(db, manifest);
        db.execute('COMMIT');
        completed = true;
      } catch (_) {
        db.execute('ROLLBACK');
        rethrow;
      }
    } finally {
      db.close();
      if (!completed && file.existsSync()) {
        file.deleteSync();
      }
    }
    return ManifestArtifact(
      file,
      sha256.convert(file.readAsBytesSync()).toString(),
    );
  }

  static void _insertManifest(Database db, PortableManifest manifest) {
    _writeDisplayMetadata(db, manifest);
    db.execute('INSERT INTO metadata VALUES (?, ?, ?, ?)', [
      manifest.gid,
      manifest.representation,
      manifest.galleryUrl,
      manifest.title,
    ]);
    for (var i = 0; i < manifest.tags.length; i++) {
      final tag = manifest.tags[i];
      db.execute('INSERT INTO tag VALUES (?, ?, ?)', [
        i,
        tag.namespace,
        tag.name,
      ]);
    }
    for (var i = 0; i < manifest.pages.length; i++) {
      final page = manifest.pages[i];
      db.execute('INSERT INTO page VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', [
        i,
        page.rawHash,
        page.rawLength,
        page.objectHash,
        page.storedLength,
        page.codecProfile,
        page.mime,
        page.width,
        page.height,
        page.sourcePageUrl,
      ]);
    }
    if (manifest.thumbnail case final thumb?) {
      db.execute('INSERT INTO thumbnail VALUES (?, ?, ?, ?)', [
        thumb.rawHash,
        thumb.rawLength,
        thumb.objectHash,
        thumb.mime,
      ]);
    }
    for (var i = 0; i < manifest.lineage.length; i++) {
      final edge = manifest.lineage[i];
      db.execute('INSERT INTO lineage VALUES (?, ?, ?, ?)', [
        i,
        edge.fromGid,
        edge.toGid,
        edge.kind,
      ]);
    }
    for (final id in manifest.supersedes.toSet().toList()..sort()) {
      db.execute('INSERT INTO supersedes VALUES (?)', [id]);
    }
    for (final id in manifest.codecProfiles.keys.toList()..sort()) {
      db.execute('INSERT INTO codec_profile VALUES (?, ?)', [
        id,
        _canonicalJson(manifest.codecProfiles[id]),
      ]);
    }
  }

  static void _writeDisplayMetadata(Database db, PortableManifest manifest) {
    db.execute(
      'CREATE TABLE IF NOT EXISTS display_metadata (provider_json TEXT NOT NULL, collections_json TEXT NOT NULL)',
    );
    final provider = _canonicalJson(manifest.providerMetadata);
    final collections = _canonicalJson(manifest.collections);
    final existing = db.select('SELECT * FROM display_metadata');
    if (existing.isNotEmpty &&
        existing.single['provider_json'] == provider &&
        existing.single['collections_json'] == collections)
      return;
    db.execute('DELETE FROM display_metadata');
    db.execute('INSERT INTO display_metadata VALUES (?, ?)', [
      provider,
      collections,
    ]);
  }

  static PortableManifest read(File file) =>
      _read(file, expectedApplicationId: portableApplicationId);

  static PortableManifest _read(
    File file, {
    required int expectedApplicationId,
  }) {
    final db = sqlite3.open(file.path, mode: OpenMode.readOnly);
    try {
      final applicationId =
          db.select('PRAGMA application_id').single.columnAt(0) as int;
      if (applicationId != expectedApplicationId) {
        throw FormatException(
          'Unexpected SQLite application ID $applicationId',
        );
      }
      return _readDatabase(db);
    } finally {
      db.close();
    }
  }

  static PortableManifest _readDatabase(
    Database db, {
    List<PortablePage>? existingPages,
    Map<String, Map<String, Object?>>? existingProfiles,
  }) {
    final version = db.select('PRAGMA user_version').single.columnAt(0) as int;
    if (version != PortableManifest.formatVersion) {
      throw FormatException('Unsupported manifest version $version');
    }
    final metadata = db.select('SELECT * FROM metadata').single;
    final displayTable = db.select(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'display_metadata'",
    );
    final display = displayTable.isEmpty
        ? null
        : db.select('SELECT * FROM display_metadata').firstOrNull;
    final provider = display == null
        ? <String, dynamic>{}
        : jsonDecode(display['provider_json'] as String)
              as Map<String, dynamic>;
    final collections = display == null
        ? <String>[]
        : (jsonDecode(display['collections_json'] as String) as List)
              .cast<String>();
    final tags = db
        .select('SELECT namespace, name FROM tag ORDER BY ordinal')
        .map(
          (row) =>
              PortableTag(row['namespace'] as String, row['name'] as String),
        )
        .toList();
    final pages =
        existingPages ??
        db
            .select('SELECT * FROM page ORDER BY ordinal')
            .map(
              (row) => PortablePage(
                rawHash: row['raw_hash'] as String,
                rawLength: row['raw_length'] as int,
                objectHash: row['object_hash'] as String,
                storedLength: row['stored_length'] as int,
                codecProfile: row['codec_profile'] as String,
                mime: row['mime'] as String,
                width: row['width'] as int?,
                height: row['height'] as int?,
                sourcePageUrl: row.keys.contains('source_page_url')
                    ? row['source_page_url'] as String?
                    : null,
              ),
            )
            .toList();
    final thumbnailRows = db.select('SELECT * FROM thumbnail');
    final thumbnail = thumbnailRows.isEmpty
        ? null
        : PortableThumbnail(
            rawHash: thumbnailRows.single['raw_hash'] as String,
            rawLength: thumbnailRows.single['raw_length'] as int,
            objectHash: thumbnailRows.single['object_hash'] as String,
            mime: thumbnailRows.single['mime'] as String,
          );
    final lineage = db
        .select('SELECT from_gid, to_gid, kind FROM lineage ORDER BY ordinal')
        .map(
          (row) => ManifestLineage(
            row['from_gid'] as int,
            row['to_gid'] as int,
            row['kind'] as String,
          ),
        )
        .toList();
    final supersedes = db
        .select('SELECT manifest_id FROM supersedes ORDER BY manifest_id')
        .map((row) => row['manifest_id'] as String)
        .toList();
    final profiles = existingProfiles ?? _readCodecProfiles(db);
    final manifest = PortableManifest(
      gid: metadata['gid'] as int,
      representation: metadata['representation'] as String,
      galleryUrl: metadata['gallery_url'] as String,
      title: metadata['title'] as String,
      rawTitle: provider['rawTitle'] as String?,
      japaneseTitle: provider['japaneseTitle'] as String?,
      category: provider['category'] as String?,
      uploader: provider['uploader'] as String?,
      publishTime: provider['publishTime'] as String?,
      language: provider['language'] as String?,
      coverUrl: provider['coverUrl'] as String?,
      rating: (provider['rating'] as num?)?.toDouble(),
      collections: collections,
      tags: tags,
      pages: pages,
      thumbnail: thumbnail,
      lineage: lineage,
      supersedes: supersedes,
      codecProfiles: profiles,
    );
    manifest.validate();
    return manifest;
  }

  static Map<String, Map<String, Object?>> _readCodecProfiles(Database db) {
    return {
      for (final row in db.select(
        'SELECT profile_id, definition_json FROM codec_profile',
      ))
        row['profile_id'] as String: (jsonDecode(
          row['definition_json'] as String,
        ) as Map).cast<String, Object?>(),
    };
  }
}

/// Local-only rows share the portable table layout but never enter a WebDAV
/// manifest. An incomplete download has no portable metadata row yet.
class DirectoryRecoveryProjection {
  final String copyId;
  final String taskKind;
  final String taskState;
  final String taskJson;
  final List<DirectoryRecoveryPage> pages;
  final PortableManifest? completeManifest;
  final Map<int, PortablePage> residentPages;
  final Map<String, Map<String, Object?>> codecProfiles;

  const DirectoryRecoveryProjection({
    required this.copyId,
    required this.taskKind,
    required this.taskState,
    required this.taskJson,
    required this.pages,
    this.completeManifest,
    this.residentPages = const {},
    this.codecProfiles = const {},
  });
}

class DirectoryRecoveryPage {
  final int ordinal;
  final String? relativePath;
  final String state;
  const DirectoryRecoveryPage(this.ordinal, this.relativePath, this.state);
}

class DirectoryRecoveryCodec {
  static Future<void> writeNewAsync(
    File file,
    DirectoryRecoveryProjection projection,
  ) {
    final filePath = file.path;
    return Isolate.run(() => writeNew(File(filePath), projection));
  }

  static Future<void> updateExistingAsync(
    File file,
    DirectoryRecoveryProjection projection,
  ) {
    final filePath = file.path;
    return Isolate.run(() => updateExisting(File(filePath), projection));
  }

  /// Write a new projection file. The owner chooses a staging path and
  /// replaces its existing directory projection after this method closes it.
  static void writeNew(File file, DirectoryRecoveryProjection projection) {
    if (file.existsSync()) {
      throw StateError('Projection already exists: ${file.path}');
    }
    file.parent.createSync(recursive: true);
    projection.completeManifest?.validate();
    final db = sqlite3.open(file.path);
    var completed = false;
    try {
      db.execute('BEGIN IMMEDIATE');
      try {
        db.execute(
          'PRAGMA application_id = ${PortableManifestCodec.directoryApplicationId}',
        );
        db.execute('PRAGMA user_version = ${PortableManifest.formatVersion}');
        PortableManifestCodec.createSchema(db);
        if (projection.completeManifest case final manifest?) {
          PortableManifestCodec._insertManifest(db, manifest);
        } else {
          _mergeResidentPages(db, projection);
        }
        db.execute(
          'CREATE TABLE local_task (copy_id TEXT NOT NULL, task_kind TEXT NOT NULL, task_state TEXT NOT NULL, task_json TEXT NOT NULL)',
        );
        db.execute(
          'CREATE TABLE local_page (ordinal INTEGER PRIMARY KEY, relative_path TEXT, state TEXT NOT NULL)',
        );
        db.execute('INSERT INTO local_task VALUES (?, ?, ?, ?)', [
          projection.copyId,
          projection.taskKind,
          projection.taskState,
          projection.taskJson,
        ]);
        for (final page in projection.pages) {
          db.execute('INSERT INTO local_page VALUES (?, ?, ?)', [
            page.ordinal,
            page.relativePath,
            page.state,
          ]);
        }
        db.execute('COMMIT');
        completed = true;
      } catch (_) {
        db.execute('ROLLBACK');
        rethrow;
      }
    } finally {
      db.close();
      if (!completed && file.existsSync()) file.deleteSync();
    }
  }

  /// Merge a changed runtime snapshot into the directory database. Existing
  /// rows with identical values stay untouched; the transaction is visible to
  /// readers all at once.
  static void updateExisting(
    File file,
    DirectoryRecoveryProjection projection,
  ) {
    projection.completeManifest?.validate();
    final db = sqlite3.open(file.path);
    try {
      final appId =
          db.select('PRAGMA application_id').single.columnAt(0) as int;
      if (appId != PortableManifestCodec.directoryApplicationId) {
        throw FormatException('Unexpected directory projection ID $appId');
      }
      final owner =
          db.select('SELECT copy_id FROM local_task').single['copy_id']
              as String;
      if (owner != projection.copyId)
        throw StateError('Projection owner changed');
      db.execute('BEGIN IMMEDIATE');
      try {
        if (!db
            .select('PRAGMA table_info(page)')
            .any((row) => row['name'] == 'source_page_url')) {
          db.execute('ALTER TABLE page ADD COLUMN source_page_url TEXT');
        }
        db.execute(
          '''
          UPDATE local_task SET task_kind = ?, task_state = ?, task_json = ?
          WHERE task_kind IS NOT ? OR task_state IS NOT ? OR task_json IS NOT ?
        ''',
          [
            projection.taskKind,
            projection.taskState,
            projection.taskJson,
            projection.taskKind,
            projection.taskState,
            projection.taskJson,
          ],
        );
        final ordinals = projection.pages.map((page) => page.ordinal).toSet();
        for (final old in db.select('SELECT ordinal FROM local_page')) {
          final ordinal = old['ordinal'] as int;
          if (!ordinals.contains(ordinal)) {
            db.execute('DELETE FROM local_page WHERE ordinal = ?', [ordinal]);
          }
        }
        for (final page in projection.pages) {
          db.execute(
            '''
            INSERT INTO local_page VALUES (?, ?, ?)
            ON CONFLICT(ordinal) DO UPDATE SET
              relative_path = excluded.relative_path, state = excluded.state
            WHERE local_page.relative_path IS NOT excluded.relative_path
               OR local_page.state IS NOT excluded.state
          ''',
            [page.ordinal, page.relativePath, page.state],
          );
        }
        if (projection.completeManifest case final manifest?) {
          PortableManifestCodec._writeDisplayMetadata(db, manifest);
          final metadata = db.select('SELECT * FROM metadata');
          if (metadata.isEmpty) {
            db.execute('INSERT INTO metadata VALUES (?, ?, ?, ?)', [
              manifest.gid,
              manifest.representation,
              manifest.galleryUrl,
              manifest.title,
            ]);
          } else {
            db.execute(
              '''
              UPDATE metadata SET gid = ?, representation = ?,
                gallery_url = ?, title = ?
              WHERE gid IS NOT ? OR representation IS NOT ?
                OR gallery_url IS NOT ? OR title IS NOT ?
            ''',
              [
                manifest.gid,
                manifest.representation,
                manifest.galleryUrl,
                manifest.title,
                manifest.gid,
                manifest.representation,
                manifest.galleryUrl,
                manifest.title,
              ],
            );
          }
          _replaceOrdinalRows(db, 'tag', manifest.tags.length);
          for (var i = 0; i < manifest.tags.length; i++) {
            final tag = manifest.tags[i];
            db.execute(
              '''
              INSERT INTO tag VALUES (?, ?, ?)
              ON CONFLICT(ordinal) DO UPDATE SET
                namespace = excluded.namespace, name = excluded.name
              WHERE tag.namespace IS NOT excluded.namespace
                 OR tag.name IS NOT excluded.name
            ''',
              [i, tag.namespace, tag.name],
            );
          }
          final thumbnail = manifest.thumbnail;
          final existingThumb = db.select('SELECT * FROM thumbnail');
          if (thumbnail == null) {
            if (existingThumb.isNotEmpty) db.execute('DELETE FROM thumbnail');
          } else if (existingThumb.isEmpty ||
              existingThumb.single['raw_hash'] != thumbnail.rawHash ||
              existingThumb.single['raw_length'] != thumbnail.rawLength ||
              existingThumb.single['object_hash'] != thumbnail.objectHash ||
              existingThumb.single['mime'] != thumbnail.mime) {
            db.execute('DELETE FROM thumbnail');
            db.execute('INSERT INTO thumbnail VALUES (?, ?, ?, ?)', [
              thumbnail.rawHash,
              thumbnail.rawLength,
              thumbnail.objectHash,
              thumbnail.mime,
            ]);
          }
          _replaceOrdinalRows(db, 'lineage', manifest.lineage.length);
          for (var i = 0; i < manifest.lineage.length; i++) {
            final edge = manifest.lineage[i];
            db.execute(
              '''
              INSERT INTO lineage VALUES (?, ?, ?, ?)
              ON CONFLICT(ordinal) DO UPDATE SET
                from_gid = excluded.from_gid, to_gid = excluded.to_gid,
                kind = excluded.kind
              WHERE lineage.from_gid IS NOT excluded.from_gid
                 OR lineage.to_gid IS NOT excluded.to_gid
                 OR lineage.kind IS NOT excluded.kind
            ''',
              [i, edge.fromGid, edge.toGid, edge.kind],
            );
          }
          final supersedes = manifest.supersedes.toSet();
          for (final row in db.select('SELECT manifest_id FROM supersedes')) {
            final id = row['manifest_id'] as String;
            if (!supersedes.contains(id)) {
              db.execute('DELETE FROM supersedes WHERE manifest_id = ?', [id]);
            }
          }
          for (final id in supersedes) {
            db.execute('INSERT OR IGNORE INTO supersedes VALUES (?)', [id]);
          }
        } else {
          // Sparse resident facts do not turn a partial task into a complete
          // portable gallery. Only a full metadata row carries that meaning.
          db.execute('DELETE FROM metadata');
        }
        _mergeResidentPages(db, projection);
        db.execute('COMMIT');
      } catch (_) {
        db.execute('ROLLBACK');
        rethrow;
      }
    } finally {
      db.close();
    }
  }

  static void _mergeResidentPages(
    Database db,
    DirectoryRecoveryProjection projection,
  ) {
    final facts =
        projection.completeManifest?.pages.asMap() ?? projection.residentPages;
    final profiles =
        projection.completeManifest?.codecProfiles ?? projection.codecProfiles;
    for (final row in db.select('SELECT ordinal FROM page')) {
      final ordinal = row['ordinal'] as int;
      if (!facts.containsKey(ordinal))
        db.execute('DELETE FROM page WHERE ordinal = ?', [ordinal]);
    }
    for (final entry in facts.entries) {
      final i = entry.key;
      final page = entry.value;
      db.execute(
        '''
              INSERT INTO page VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
              ON CONFLICT(ordinal) DO UPDATE SET
                raw_hash = excluded.raw_hash, raw_length = excluded.raw_length,
                object_hash = excluded.object_hash,
                stored_length = excluded.stored_length,
                codec_profile = excluded.codec_profile, mime = excluded.mime,
                width = excluded.width, height = excluded.height,
                source_page_url = excluded.source_page_url
              WHERE page.raw_hash IS NOT excluded.raw_hash
                 OR page.raw_length IS NOT excluded.raw_length
                 OR page.object_hash IS NOT excluded.object_hash
                 OR page.stored_length IS NOT excluded.stored_length
                 OR page.codec_profile IS NOT excluded.codec_profile
                 OR page.mime IS NOT excluded.mime
                 OR page.width IS NOT excluded.width
                 OR page.height IS NOT excluded.height
                 OR page.source_page_url IS NOT excluded.source_page_url
            ''',
        [
          i,
          page.rawHash,
          page.rawLength,
          page.objectHash,
          page.storedLength,
          page.codecProfile,
          page.mime,
          page.width,
          page.height,
          page.sourcePageUrl,
        ],
      );
    }
    for (final row in db.select('SELECT profile_id FROM codec_profile')) {
      final id = row['profile_id'] as String;
      if (!profiles.containsKey(id)) {
        db.execute('DELETE FROM codec_profile WHERE profile_id = ?', [id]);
      }
    }
    for (final entry in profiles.entries) {
      final definition = _canonicalJson(entry.value);
      db.execute(
        '''
              INSERT INTO codec_profile VALUES (?, ?)
              ON CONFLICT(profile_id) DO UPDATE SET
                definition_json = excluded.definition_json
              WHERE codec_profile.definition_json IS NOT excluded.definition_json
            ''',
        [entry.key, definition],
      );
    }
  }

  static void _replaceOrdinalRows(Database db, String table, int length) {
    db.execute('DELETE FROM $table WHERE ordinal >= ?', [length]);
  }

  static DirectoryRecoveryProjection read(File file) {
    final db = sqlite3.open(file.path, mode: OpenMode.readOnly);
    late final String copyId;
    late final String taskKind;
    late final String taskState;
    late final String taskJson;
    late final List<DirectoryRecoveryPage> pages;
    late final PortableManifest? completeManifest;
    final residentPages = <int, PortablePage>{};
    final codecProfiles = <String, Map<String, Object?>>{};
    try {
      final applicationId =
          db.select('PRAGMA application_id').single.columnAt(0) as int;
      if (applicationId != PortableManifestCodec.directoryApplicationId) {
        throw FormatException(
          'Unexpected SQLite application ID $applicationId',
        );
      }
      final local = db.select('SELECT * FROM local_task').single;
      copyId = local['copy_id'] as String;
      taskKind = local['task_kind'] as String;
      taskState = local['task_state'] as String;
      taskJson = local['task_json'] as String;
      pages = db
          .select('SELECT * FROM local_page ORDER BY ordinal')
          .map(
            (row) => DirectoryRecoveryPage(
              row['ordinal'] as int,
              row['relative_path'] as String?,
              row['state'] as String,
            ),
          )
          .toList();
      for (final row in db.select('SELECT * FROM page ORDER BY ordinal')) {
        residentPages[row['ordinal'] as int] = PortablePage(
          rawHash: row['raw_hash'] as String,
          rawLength: row['raw_length'] as int,
          objectHash: row['object_hash'] as String,
          storedLength: row['stored_length'] as int,
          codecProfile: row['codec_profile'] as String,
          mime: row['mime'] as String,
          width: row['width'] as int?,
          height: row['height'] as int?,
          sourcePageUrl: row.keys.contains('source_page_url')
              ? row['source_page_url'] as String?
              : null,
        );
      }
      for (final row in db.select(
        'SELECT profile_id, definition_json FROM codec_profile',
      )) {
        codecProfiles[row['profile_id'] as String] = (jsonDecode(
          row['definition_json'] as String,
        ) as Map).cast<String, Object?>();
      }
      final hasCompleteManifest =
          (db.select('SELECT COUNT(*) AS count FROM metadata').single['count']
              as int) >
          0;
      completeManifest = hasCompleteManifest
          ? PortableManifestCodec._readDatabase(
              db,
              existingPages: residentPages.values.toList(),
              existingProfiles: codecProfiles,
            )
          : null;
    } finally {
      db.close();
    }
    return DirectoryRecoveryProjection(
      copyId: copyId,
      taskKind: taskKind,
      taskState: taskState,
      taskJson: taskJson,
      pages: pages,
      residentPages: residentPages,
      codecProfiles: codecProfiles,
      completeManifest: completeManifest,
    );
  }
}

String _canonicalJson(Object? value) {
  Object? sorted(Object? v) {
    if (v is Map) {
      final keys = v.keys.map((key) => key.toString()).toList()..sort();
      return {for (final key in keys) key: sorted(v[key])};
    }
    if (v is List) {
      return v.map(sorted).toList();
    }
    return v;
  }

  return jsonEncode(sorted(value));
}
