import 'package:drift/drift.dart';

class ContentRemotePartition extends Table {
  TextColumn get targetNamespace => text()();
  TextColumn get partition => text()();
  TextColumn get syncToken => text().nullable()();
  TextColumn get scanState => text()();
  TextColumn get scannedAt => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {targetNamespace, partition};
}
