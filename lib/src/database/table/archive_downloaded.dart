import 'package:drift/drift.dart';

import 'content_copy.dart';

@TableIndex(name: 'a_idx_insert_time', columns: {#insertTime})
@TableIndex(name: 'a_idx_sort_order', columns: {#sortOrder})
@TableIndex(name: 'a_idx_group_name', columns: {#groupName})
@TableIndex(name: 'a_idx_tag_refresh_time', columns: {#tagRefreshTime})
class ArchiveDownloaded extends Table {
  @override
  String? get tableName => 'archive_downloaded_v2';

  IntColumn get gid => integer()();

  TextColumn get copyId => text().nullable().references(ContentCopy, #copyId)();

  TextColumn get token => text()();

  TextColumn get title => text()();

  TextColumn get category => text()();

  IntColumn get pageCount => integer()();

  TextColumn get galleryUrl => text()();

  TextColumn get coverUrl => text()();

  TextColumn get uploader => text().nullable()();

  IntColumn get size => integer()();

  TextColumn get publishTime => text()();

  IntColumn get archiveStatusCode => integer().named('archive_status_index')();

  TextColumn get archivePageUrl => text()();

  TextColumn get downloadPageUrl => text().nullable()();

  TextColumn get downloadUrl => text().nullable()();

  BoolColumn get isOriginal => boolean()();

  TextColumn get insertTime => text()();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  TextColumn get groupName => text()();

  TextColumn get tags => text().withDefault(const Constant(''))();

  TextColumn get tagRefreshTime => text().nullable()();

  IntColumn get parseSource => integer().withDefault(const Constant(0))();
  
  /// Sanitized and truncated title used as the directory/file name on disk.
  /// Computed once when the download task is first created and stored here to
  /// ensure the path never changes even if the truncation algorithm is updated.
  TextColumn get sanitizedTitle => text().nullable()();

  @override
  Set<Column<Object>>? get primaryKey => {gid};
}
