import 'package:drift/drift.dart';

/// Local projection of an immutable portable manifest from one target.
class ContentManifest extends Table {
  TextColumn get targetNamespace => text()();
  TextColumn get manifestId => text()();
  IntColumn get gid => integer()();
  TextColumn get representation => text()();
  TextColumn get title => text()();
  TextColumn get galleryUrl => text()();
  TextColumn get portableJson => text()();
  TextColumn get importedAt => text()();

  @override
  Set<Column<Object>> get primaryKey => {targetNamespace, manifestId};
}
