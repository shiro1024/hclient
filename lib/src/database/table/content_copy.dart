import 'package:drift/drift.dart';

/// A mutable, locally resident directory. A page revision does not create a copy.
@TableIndex(
  name: 'content_copy_root_unique',
  columns: {#rootPath},
  unique: true,
)
@TableIndex.sql(
  'CREATE UNIQUE INDEX content_copy_current_unique ON content_copy (gid, representation) WHERE is_current = 1',
)
class ContentCopy extends Table {
  TextColumn get copyId => text()();
  IntColumn get gid => integer()();
  TextColumn get representation => text()();
  TextColumn get rootPath => text()();
  TextColumn get metadataJson => text().nullable()();
  TextColumn get libraryNamespace => text().nullable()();
  BoolColumn get isCurrent => boolean().withDefault(const Constant(false))();
  TextColumn get lifecycle => text().withDefault(const Constant('active'))();
  TextColumn get trashPath => text().nullable()();
  TextColumn get cleanupState => text().nullable()();
  TextColumn get createdAt => text()();

  @override
  Set<Column<Object>> get primaryKey => {copyId};
}
