import 'package:drift/drift.dart';

/// A resource observed or committed in one WebDAV target namespace.
class ContentRemoteResource extends Table {
  TextColumn get targetNamespace => text()();
  TextColumn get href => text()();
  TextColumn get kind => text()();
  TextColumn get objectHash => text().nullable()();
  TextColumn get etag => text().nullable()();
  TextColumn get partition => text().nullable()();
  TextColumn get observedAt => text()();

  @override
  Set<Column<Object>> get primaryKey => {targetNamespace, href};
}
