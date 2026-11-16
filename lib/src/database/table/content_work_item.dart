import 'package:drift/drift.dart';

/// Input pages and target are immutable for the lifetime of an item.
class ContentWorkItem extends Table {
  TextColumn get workItemId => text()();
  TextColumn get targetNamespace => text()();
  TextColumn get copyId => text().nullable()();
  TextColumn get kind => text()();
  TextColumn get state => text()();
  TextColumn get inputManifestId => text().nullable()();
  TextColumn get inputJson => text()();
  TextColumn get localArtifactPath => text().nullable()();
  TextColumn get remoteDestination => text().nullable()();
  TextColumn get artifactsJson => text().withDefault(const Constant('{}'))();
  TextColumn get committedObjectsJson =>
      text().withDefault(const Constant('[]'))();
  TextColumn get pendingManifestId => text().nullable()();
  TextColumn get source => text().withDefault(const Constant('manual'))();
  TextColumn get finishAction => text().withDefault(const Constant('keep'))();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();

  @override
  Set<Column<Object>> get primaryKey => {workItemId};
}
