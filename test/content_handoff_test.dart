import 'dart:io';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/service/content_sync/content_repository.dart';
import 'package:jhentai/src/service/content_sync/portable_manifest.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  late AppDb db;
  late ContentRepository repo;
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('hclient-handoff-');
    db = AppDb.testing(NativeDatabase.memory());
    repo = ContentRepository(db);
  });
  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });

  Future<String> copy(String id, int gid) async {
    await repo.createCopy(
      copyId: id,
      gid: gid,
      representation: 'original',
      rootPath: '${root.path}/$id',
    );
    await repo.putPage(
      ContentPageRecord(
        copyId: id,
        ordinal: 0,
        relativePath: '1.png',
        rawHash: 'a' * 64,
        rawLength: 3,
        mime: 'image/png',
        width: null,
        height: null,
        state: 'completed',
      ),
    );
    return id;
  }

  Future<void> task(String copyId, int gid, {int status = 4}) async {
    await db.customStatement(
      '''
      INSERT INTO gallery_downloaded_v2
      (gid,copy_id,token,title,category,page_count,gallery_url,publish_time,
       download_status_index,insert_time,priority,group_name)
      VALUES (?,?,'0123456789','Book','Manga',1,'https://e-hentai.org/g/1/0123456789/','2026',?,'2026',0,'Reading')
    ''',
      [gid, copyId, status],
    );
    await db.customStatement(
      '''
      INSERT INTO image (gid,serialNo,url,path,imageHash,downloadStatusIndex)
      VALUES (?,0,'','1.png','hash',4)
    ''',
      [gid],
    );
  }

  test('v3 raw pages migrate to unselected residency without changing identity or ownership', () async {
    await db.close();
    final file = File('${root.path}/v3.sqlite');
    db = AppDb.testing(NativeDatabase(file));
    repo = ContentRepository(db);
    await copy('existing-raw', 7);
    await db.customStatement(
      "UPDATE content_copy SET library_namespace = 'published' WHERE copy_id = 'existing-raw'",
    );
    await db.close();
    final old = sqlite.sqlite3.open(file.path);
    old.execute('ALTER TABLE content_page DROP COLUMN codec_profile');
    old.execute('ALTER TABLE content_page DROP COLUMN object_hash');
    old.execute('ALTER TABLE content_page DROP COLUMN stored_length');
    old.execute('PRAGMA user_version = 3');
    old.dispose();
    db = AppDb.testing(NativeDatabase(file));
    repo = ContentRepository(db);
    final page = await repo.getPage('existing-raw', 0);
    expect(page.rawHash, 'a' * 64);
    expect(page.rawLength, 3);
    expect(page.relativePath, '1.png');
    expect(page.codecProfile, null);
    expect(page.objectHash, null);
    expect(page.storedLength, null);
    expect(
      (await db
              .customSelect(
                "SELECT library_namespace FROM content_copy WHERE copy_id = 'existing-raw'",
              )
              .getSingle())
          .read<String>('library_namespace'),
      'published',
    );
  });

  test('v2 upgrade preserves tasks and maps release, source links and restored ownership', () async {
    await db.close();
    final file = File('${root.path}/upgrade.sqlite');
    db = AppDb.testing(NativeDatabase(file));
    repo = ContentRepository(db);
    await copy('download', 1);
    await copy('same-gid-other', 1);
    await copy('restored', 2);
    await task('download', 1);
    await db.customStatement(
      "UPDATE content_copy SET metadata_json = '{\"title\":\"Personal title\",\"galleryUrl\":\"https://e-hentai.org/g/1/0123456789/\",\"expectedPages\":1,\"tags\":[],\"lineage\":[]}' WHERE copy_id = 'download'",
    );
    final upload = await repo.createWorkItem(
      kind: 'content',
      targetNamespace: 'cloud-a',
      inputJson: '{}',
      copyId: 'download',
      finishAction: 'release',
    );
    final restore = await repo.createWorkItem(
      kind: 'restore',
      targetNamespace: 'cloud-b',
      inputJson: '{}',
      copyId: 'restored',
    );
    await repo.updateWorkItemState(restore.workItemId, 'completed');
    await db.close();
    final legacy = sqlite.sqlite3.open(file.path);
    legacy.execute('ALTER TABLE content_copy DROP COLUMN library_namespace');
    legacy.execute('ALTER TABLE content_page DROP COLUMN source_page_url');
    legacy.execute('ALTER TABLE content_page DROP COLUMN codec_profile');
    legacy.execute('ALTER TABLE content_page DROP COLUMN object_hash');
    legacy.execute('ALTER TABLE content_page DROP COLUMN stored_length');
    legacy.execute(
      'ALTER TABLE content_work_item ADD COLUMN cleanup_intent TEXT',
    );
    legacy.execute(
      "UPDATE content_work_item SET cleanup_intent = copy_id WHERE finish_action = 'release'",
    );
    legacy.execute('ALTER TABLE content_work_item DROP COLUMN source');
    legacy.execute('ALTER TABLE content_work_item DROP COLUMN finish_action');
    legacy.execute('PRAGMA user_version = 2');
    legacy.dispose();
    db = AppDb.testing(NativeDatabase(file));
    repo = ContentRepository(db);
    final upgraded = await repo.getWorkItem(upload.workItemId);
    expect(upgraded!.source, 'manual');
    expect(upgraded.finishAction, 'release');
    expect(
      (await db.select(db.galleryDownloaded).get()).single.copyId,
      'download',
    );
    expect(
      (await repo.getPage('download', 0)).sourcePageUrl,
      'https://e-hentai.org/s/hash/1-1',
    );
    expect((await repo.getPage('same-gid-other', 0)).sourcePageUrl, isNull);
    final resident = await (db.select(
      db.contentCopy,
    )..where((t) => t.copyId.equals('restored'))).getSingle();
    expect(resident.libraryNamespace, 'cloud-b');
    final local = await (db.select(
      db.contentCopy,
    )..where((t) => t.copyId.equals('download'))).getSingle();
    expect(local.libraryNamespace, isNull);
    final metadata = jsonDecode(local.metadataJson!);
    expect(metadata['title'], 'Personal title');
    expect(metadata['collections'], ['Reading']);
    expect(metadata['providerMetadata']['category'], 'Manga');
    expect(
      (await db.customSelect('PRAGMA table_info(content_work_item)').get()).map(
        (r) => r.read<String>('name'),
      ),
      isNot(contains('cleanup_intent')),
    );
  });

  test('handoff is atomic with publication and leaves bytes and exact-copy identity intact', () async {
    await copy('old', 1);
    await task('old', 1);
    final file = File('${root.path}/page.png');
    await file.writeAsBytes([1, 2, 3]);
    final artifact = PortableManifestCodec.write(
      File('${root.path}/manifest.sqlite'),
      PortableManifest(
        gid: 1,
        representation: 'original',
        galleryUrl: 'https://e-hentai.org/g/1/0123456789/',
        title: 'Book',
        tags: [],
        pages: [
          PortablePage(
            rawHash: 'a' * 64,
            rawLength: 3,
            objectHash: 'a' * 64,
            storedLength: 3,
            codecProfile: 'raw',
            mime: 'image/png',
          ),
        ],
        lineage: [],
        supersedes: [],
        codecProfiles: {},
      ),
    );
    Future<void> publish() async {
      await repo.importManifest('cloud-a', artifact);
      await repo.recordRemoteResource(
        targetNamespace: 'cloud-a',
        href: 'manifests/x.sqlite',
        kind: 'manifest',
        objectHash: artifact.manifestId,
        partition: 'aa',
      );
      await repo.handoffCopy('old', 'cloud-a');
    }

    await expectLater(
      db.transaction(() async {
        await publish();
        throw StateError('interrupted');
      }),
      throwsStateError,
    );
    expect(await db.select(db.galleryDownloaded).get(), hasLength(1));
    expect(await repo.isCloudResident('old', 'cloud-a'), isFalse);
    await db.transaction(publish);
    expect(await db.select(db.galleryDownloaded).get(), isEmpty);
    expect(await db.select(db.image).get(), isEmpty);
    expect(await repo.listPages('old'), hasLength(1));
    expect(await file.readAsBytes(), [1, 2, 3]);
    expect(await repo.isCloudResident('old', 'cloud-a'), isTrue);
    expect(await repo.isCloudResident('old', 'cloud-b'), isFalse);
    final successor = PortableManifestCodec.write(
      File('${root.path}/new.sqlite'),
      PortableManifest(
        gid: 1,
        representation: 'original',
        galleryUrl: 'https://e-hentai.org/g/1/0123456789/',
        title: 'Book',
        tags: [],
        lineage: [],
        codecProfiles: {},
        supersedes: [artifact.manifestId],
        pages: [
          PortablePage(
            rawHash: 'b' * 64,
            rawLength: 3,
            objectHash: 'b' * 64,
            storedLength: 3,
            codecProfile: 'raw',
            mime: 'image/png',
          ),
        ],
      ),
    );
    await repo.importManifest('cloud-a', successor);
    await repo.recordRemoteResource(
      targetNamespace: 'cloud-a',
      href: 'manifests/new.sqlite',
      kind: 'manifest',
      objectHash: successor.manifestId,
      partition: 'bb',
    );
    expect(
      await repo.isCloudResident('old', 'cloud-a'),
      isFalse,
      reason: 'Only a historical copy matches; retain its normal local entry',
    );
    await db.customStatement('DELETE FROM content_remote_resource');
    expect(await repo.isCloudResident('old', 'cloud-a'), isFalse);
  });

  test('completion of an older copy never removes the same-gid newer task or incomplete tasks', () async {
    await copy('old', 1);
    await copy('new', 1);
    await task('new', 1);
    await repo.handoffCopy('old', 'cloud-a');
    expect((await db.select(db.galleryDownloaded).get()).single.copyId, 'new');
    expect(await db.select(db.image).get(), hasLength(1));
    await copy('partial', 2);
    await task('partial', 2, status: 2);
    await repo.handoffCopy('partial', 'cloud-a');
    expect(await db.select(db.galleryDownloaded).get(), hasLength(2));
    expect(await db.select(db.image).get(), hasLength(2));
  });
}
