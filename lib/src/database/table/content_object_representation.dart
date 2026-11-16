import 'package:drift/drift.dart';

/// A decodable object reference learned from a manifest in one target.
class ContentObjectRepresentation extends Table {
  TextColumn get targetNamespace => text()();
  TextColumn get rawHash => text()();
  TextColumn get objectHash => text()();
  TextColumn get codecProfile => text()();
  IntColumn get storedLength => integer()();

  @override
  Set<Column<Object>> get primaryKey => {targetNamespace, rawHash, objectHash};
}
