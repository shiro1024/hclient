import 'dart:io';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as path;
import 'package:sqlite3/sqlite3.dart';

import '../service/path_service.dart';
import 'table/archive_downloaded.dart';
import 'table/archive_group.dart';
import 'table/block_rule.dart';
import 'table/content_copy.dart';
import 'table/content_manifest.dart';
import 'table/content_object_representation.dart';
import 'table/content_page.dart';
import 'table/content_page_replacement.dart';
import 'table/content_remote_partition.dart';
import 'table/content_remote_resource.dart';
import 'table/content_work_item.dart';
import 'table/dio_cache.dart';
import 'table/gallery_downloaded.dart';
import 'table/gallery_group.dart';
import 'table/gallery_history.dart';
import 'table/image.dart';
import 'table/local_config.dart';
import 'table/tag.dart';
import 'table/tag_count.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Tag,
    ArchiveDownloaded,
    ArchiveGroup,
    GalleryDownloaded,
    GalleryGroup,
    Image,
    GalleryHistoryV2,
    TagCount,
    DioCache,
    BlockRule,
    LocalConfig,
    ContentCopy,
    ContentPage,
    ContentRemoteResource,
    ContentRemotePartition,
    ContentManifest,
    ContentObjectRepresentation,
    ContentWorkItem,
    ContentPageReplacement,
  ],
)
class AppDb extends _$AppDb {
  AppDb() : super(_openConnection());

  /// Inject a real temporary SQLite connection or an in-memory executor in tests.
  AppDb.testing(QueryExecutor executor) : super(executor);

  // shiro.hclient starts a new baseline. Do not reuse upstream schema versions.
  @override
  int get schemaVersion => 4;

  Future<void> _backfillContentMetadata() async {
    final rows = await customSelect("""
      SELECT c.copy_id, c.metadata_json, g.category, g.uploader,
        g.publish_time, g.group_name, NULL AS cover_url
      FROM content_copy c JOIN gallery_downloaded_v2 g ON g.copy_id = c.copy_id
      WHERE c.metadata_json IS NOT NULL AND g.download_status_index = 4
      UNION ALL
      SELECT c.copy_id, c.metadata_json, a.category, a.uploader,
        a.publish_time, a.group_name, a.cover_url
      FROM content_copy c JOIN archive_downloaded_v2 a ON a.copy_id = c.copy_id
      WHERE c.metadata_json IS NOT NULL AND a.archive_status_index = 90
    """).get();
    final byCopy = <String, List<QueryRow>>{};
    for (final row in rows) {
      (byCopy[row.read<String>('copy_id')] ??= []).add(row);
    }
    for (final entry in byCopy.entries) {
      final metadata = jsonDecode(
        entry.value.first.read<String>('metadata_json'),
      ) as Map<String, dynamic>;
      final provider = <String, dynamic>{
        ...?(metadata['providerMetadata'] as Map?),
      };
      for (final row in entry.value) {
        for (final field in {
          'category': 'category',
          'uploader': 'uploader',
          'publishTime': 'publish_time',
          'coverUrl': 'cover_url',
        }.entries) {
          final value = row.readNullable<String>(field.value);
          if (value != null) provider.putIfAbsent(field.key, () => value);
        }
      }
      if (!metadata.containsKey('providerMetadata') ||
          metadata['providerMetadata'] is Map) {
        metadata['providerMetadata'] = provider;
      }
      metadata.putIfAbsent(
        'collections',
        () => entry.value
            .map((row) => row.read<String>('group_name'))
            .where((name) => name.isNotEmpty)
            .toSet()
            .toList(),
      );
      await customStatement(
        'UPDATE content_copy SET metadata_json = ? WHERE copy_id = ?',
        [jsonEncode(metadata), entry.key],
      );
    }
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from == 1 && to == 4) {
        await m.createTable(contentCopy);
        await m.addColumn(galleryDownloaded, galleryDownloaded.copyId);
        await m.addColumn(archiveDownloaded, archiveDownloaded.copyId);
        await m.createTable(contentPage);
        await m.createTable(contentRemoteResource);
        await m.createTable(contentRemotePartition);
        await m.createTable(contentManifest);
        await m.createTable(contentObjectRepresentation);
        await m.createTable(contentWorkItem);
        await m.createTable(contentPageReplacement);
        await m.createIndex(contentCopyRootUnique);
        await m.createIndex(contentCopyCurrentUnique);
        return;
      }
      if (from == 2 && to == 4) {
        await m.addColumn(contentCopy, contentCopy.libraryNamespace);
        await m.addColumn(contentPage, contentPage.sourcePageUrl);
        await m.addColumn(contentWorkItem, contentWorkItem.source);
        await m.addColumn(contentWorkItem, contentWorkItem.finishAction);
        await customStatement(
          "UPDATE content_work_item SET finish_action = CASE WHEN cleanup_intent IS NULL THEN 'keep' ELSE 'release' END",
        );
        await customStatement(
          'ALTER TABLE content_work_item DROP COLUMN cleanup_intent',
        );
        await _backfillContentMetadata();
        await customStatement("""
          UPDATE content_page AS p SET source_page_url =
            CASE WHEN instr(g.gallery_url, 'exhentai.org') > 0
              THEN 'https://exhentai.org' ELSE 'https://e-hentai.org' END
              || '/s/' || i.imageHash || '/' || g.gid || '-' || (i.serialNo + 1)
          FROM gallery_downloaded_v2 g JOIN image i ON i.gid = g.gid
          WHERE g.copy_id = p.copy_id AND i.serialNo = p.ordinal
            AND i.imageHash != '' 
        """);
        await customStatement("""
          UPDATE content_copy SET library_namespace = (
            SELECT w.target_namespace FROM content_work_item w
            WHERE w.copy_id = content_copy.copy_id AND w.kind = 'restore'
              AND w.state = 'completed'
            ORDER BY w.updated_at DESC, w.work_item_id LIMIT 1
          ) WHERE NOT EXISTS (
            SELECT 1 FROM gallery_downloaded_v2 g WHERE g.copy_id = content_copy.copy_id
          ) AND NOT EXISTS (
            SELECT 1 FROM archive_downloaded_v2 a WHERE a.copy_id = content_copy.copy_id
          )
        """);
      }
      if ((from == 2 || from == 3) && to == 4) {
        await m.addColumn(contentPage, contentPage.codecProfile);
        await m.addColumn(contentPage, contentPage.objectHash);
        await m.addColumn(contentPage, contentPage.storedLength);
        return;
      }
      throw StateError('No database migration defined from $from to $to');
    },
  );
}

LazyDatabase _openConnection() => LazyDatabase(() async {
  final temporaryDirectory = pathService.tempDir.path;
  final file = File(path.join(pathService.getVisibleDir().path, 'db.sqlite'));
  return NativeDatabase.createInBackground(
    file,
    isolateSetup: () => sqlite3.tempDirectory = temporaryDirectory,
  );
});

AppDb appDb = AppDb();
