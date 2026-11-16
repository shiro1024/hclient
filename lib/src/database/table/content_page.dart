import 'package:drift/drift.dart';

class ContentPage extends Table {
  TextColumn get copyId => text()();
  IntColumn get ordinal => integer()();
  TextColumn get relativePath => text()();
  TextColumn get rawHash => text().nullable()();
  IntColumn get rawLength => integer().nullable()();
  TextColumn get codecProfile => text().nullable()();
  TextColumn get objectHash => text().nullable()();
  IntColumn get storedLength => integer().nullable()();
  TextColumn get mime => text().nullable()();
  IntColumn get width => integer().nullable()();
  IntColumn get height => integer().nullable()();
  TextColumn get sourcePageUrl => text().nullable()();
  TextColumn get state => text()();

  @override
  Set<Column<Object>> get primaryKey => {copyId, ordinal};
}
