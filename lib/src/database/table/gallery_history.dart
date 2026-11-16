import 'package:drift/drift.dart';

@TableIndex(name: 'idx_gh2_last_read_time', columns: {#lastReadTime})
class GalleryHistoryV2 extends Table {
  @override
  String? get tableName => 'gallery_history_v2';

  IntColumn get gid => integer()();

  TextColumn get jsonBody => text().named('jsonBody')();

  TextColumn get lastReadTime => text().named('lastReadTime')();

  @override
  Set<Column<Object>>? get primaryKey => {gid};
}
