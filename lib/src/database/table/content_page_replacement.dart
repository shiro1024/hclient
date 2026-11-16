import 'package:drift/drift.dart';

/// Ordered page replacement journal; file moves and row commit are restartable.
class ContentPageReplacement extends Table {
  TextColumn get replacementId => text()();
  TextColumn get copyId => text()();
  IntColumn get ordinal => integer()();
  IntColumn get queueOrder => integer()();
  TextColumn get state => text()();
  TextColumn get oldPath => text()();
  TextColumn get newPath => text()();
  TextColumn get tempPath => text()();
  TextColumn get retainedPath => text()();
  TextColumn get newMetadataJson => text().nullable()();
  TextColumn get createdAt => text()();

  @override
  Set<Column<Object>> get primaryKey => {replacementId};
}
