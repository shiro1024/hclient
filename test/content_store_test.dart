import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/service/content_sync/content_repository.dart';
import 'package:jhentai/src/service/content_sync/portable_manifest.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late AppDb db;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('hclient-content-');
  });
  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });

  AppDb openDb() =>
      AppDb.testing(NativeDatabase(File('${root.path}/runtime.sqlite')));

  Future<void> expectCopyIndexes(String prefix) async {
    final indexes = await db
        .customSelect("PRAGMA index_list('content_copy')")
        .get();
    final names = indexes.map((row) => row.read<String>('name')).toSet();
    expect(
      names,
      containsAll({'content_copy_root_unique', 'content_copy_current_unique'}),
    );
    final repository = ContentRepository(db);
    final first = await repository.createCopy(
      copyId: '$prefix-first',
      gid: 17,
      representation: 'original',
      rootPath: '${root.path}/$prefix-first',
    );
    await repository.createCopy(
      copyId: '$prefix-second',
      gid: 17,
      representation: 'original',
      rootPath: '${root.path}/$prefix-second',
    );
    await repository.setCurrentCopy(first);
    expect(
      () => repository.createCopy(
        copyId: '$prefix-duplicate-root',
        gid: 18,
        representation: 'original',
        rootPath: '${root.path}/$prefix-first',
      ),
      throwsA(isA<Exception>()),
    );
    expect(
      () => db.customStatement(
        'UPDATE content_copy SET is_current = 1 WHERE copy_id = ?',
        ['$prefix-second'],
      ),
      throwsA(isA<Exception>()),
    );
  }

  PortableManifest manifest({
    String rawHash = 'a',
    String objectHash = 'a',
    String title = 'Gallery',
    String? sourcePageUrl,
    List<ManifestLineage> lineage = const [],
    List<String> supersedes = const [],
  }) {
    final encoded = objectHash != rawHash;
    return PortableManifest(
      gid: 42,
      representation: 'original',
      galleryUrl: 'https://example.org/g/42/token/',
      title: title,
      tags: const [PortableTag('artist', 'Alice')],
      pages: [
        PortablePage(
          rawHash: rawHash * 64,
          rawLength: 100,
          objectHash: objectHash * 64,
          storedLength: encoded ? 80 : 100,
          codecProfile: encoded ? 'precomp2-zstd-v1' : 'raw',
          mime: 'image/jpeg',
          width: 800,
          height: 600,
          sourcePageUrl: sourcePageUrl,
        ),
      ],
      lineage: lineage,
      supersedes: supersedes,
      codecProfiles: encoded
          ? const {
              'precomp2-zstd-v1': {'encoder': 'precomp2', 'level': 3},
            }
          : const {},
    );
  }

  test('portable website fields and user collections survive JSON, SQLite and directory updates', () async {
    db = openDb();
    final original = manifest();
    final rich = manifest(sourcePageUrl: 'https://example.org/s/hash/42-1')
        .copyWith(
          title: 'Personal title',
          collections: ['Favorites', 'Reading'],
          providerMetadata: {
            'rawTitle': 'Site title',
            'japaneseTitle': '日本語',
            'category': 'Manga',
            'uploader': 'Alice',
            'publishTime': '2026-11-15',
            'language': 'Japanese',
            'rating': 4.5,
            'coverUrl': 'https://example.org/cover.jpg',
          },
        );
    final artifact = PortableManifestCodec.write(
      File('${root.path}/rich.sqlite'),
      rich,
    );
    final decoded = PortableManifestCodec.read(artifact.file);
    expect(decoded.toPortableJson(), rich.toPortableJson());
    expect(
      decoded.pages.single.sourcePageUrl,
      'https://example.org/s/hash/42-1',
    );
    expect(
      PortableManifest.fromPortableJson(rich.toPortableJson()).toPortableJson(),
      rich.toPortableJson(),
    );
    expect(original.businessEquivalentTo(rich), isFalse);
    expect(
      rich.businessEquivalentTo(
        rich.copyWith(collections: ['Reading', 'Favorites']),
      ),
      isTrue,
    );
    expect(rich.samePagesAs(original), isTrue);
    final legacy = PortableManifestCodec.write(
      File('${root.path}/legacy.sqlite'),
      original,
    );
    final old = sqlite3.open(legacy.file.path);
    old.execute('DROP TABLE display_metadata');
    old.execute('ALTER TABLE page DROP COLUMN source_page_url');
    old.close();
    expect(PortableManifestCodec.read(legacy.file).category, isNull);
    expect(PortableManifestCodec.read(legacy.file).collections, isEmpty);
    DirectoryRecoveryProjection projection(PortableManifest value) =>
        DirectoryRecoveryProjection(
          copyId: 'copy',
          taskKind: 'content',
          taskState: 'completed',
          taskJson: '{}',
          pages: const [DirectoryRecoveryPage(0, '1.jpg', 'completed')],
          completeManifest: value,
        );
    final directory = File('${root.path}/directory.sqlite');
    DirectoryRecoveryCodec.writeNew(directory, projection(original));
    final oldDirectory = sqlite3.open(directory.path);
    oldDirectory.execute('DROP TABLE display_metadata');
    oldDirectory.execute('ALTER TABLE page DROP COLUMN source_page_url');
    oldDirectory.close();
    DirectoryRecoveryCodec.updateExisting(directory, projection(rich));
    expect(
      DirectoryRecoveryCodec.read(directory).completeManifest!.toPortableJson(),
      rich.toPortableJson(),
    );
  });

  test(
    'complete directory recovery retains manifest version and fact validation',
    () async {
      db = openDb();
      final file = File('${root.path}/validation.sqlite');
      DirectoryRecoveryCodec.writeNew(
        file,
        DirectoryRecoveryProjection(
          copyId: 'copy',
          taskKind: 'content',
          taskState: 'completed',
          taskJson: '{}',
          pages: const [DirectoryRecoveryPage(0, '1.jpg', 'completed')],
          completeManifest: manifest(),
        ),
      );
      final sqlite = sqlite3.open(file.path);
      sqlite.execute('PRAGMA user_version = 999');
      expect(() => DirectoryRecoveryCodec.read(file), throwsFormatException);
      sqlite.execute('PRAGMA user_version = ${PortableManifest.formatVersion}');
      sqlite.execute("UPDATE page SET codec_profile = 'missing'");
      expect(() => DirectoryRecoveryCodec.read(file), throwsFormatException);
      sqlite.close();
    },
  );

  test('partial projection preserves sparse resident raw and PCF facts without complete metadata', () async {
    db = openDb();
    final file = File('${root.path}/partial.sqlite');
    final pcf = PortablePage(
      rawHash: 'a' * 64,
      rawLength: 100,
      objectHash: 'b' * 64,
      storedLength: 40,
      codecProfile: 'test-pcf',
      mime: 'image/jpeg',
      width: 20,
      height: 30,
    );
    DirectoryRecoveryProjection partial(Map<int, PortablePage> facts) =>
        DirectoryRecoveryProjection(
          copyId: 'partial',
          taskKind: 'gallery',
          taskState: 'paused',
          taskJson: '{}',
          pages: const [
            DirectoryRecoveryPage(0, null, 'none'),
            DirectoryRecoveryPage(3, 'fourth.jpg.pcf', 'completed'),
          ],
          residentPages: facts,
          codecProfiles: const {
            'test-pcf': {'format': 'test'},
          },
        );
    DirectoryRecoveryCodec.writeNew(file, partial({3: pcf}));
    var restored = DirectoryRecoveryCodec.read(file);
    expect(restored.completeManifest, null);
    expect(restored.residentPages.keys, [3]);
    expect(restored.residentPages[3]!.objectHash, pcf.objectHash);
    expect(restored.residentPages[3]!.rawHash, pcf.rawHash);
    expect(restored.codecProfiles['test-pcf'], {'format': 'test'});
    DirectoryRecoveryCodec.updateExisting(file, partial({3: pcf}));
    restored = DirectoryRecoveryCodec.read(file);
    expect(restored.residentPages.keys, [3]);
    final raw = PortablePage(
      rawHash: 'c' * 64,
      rawLength: 60,
      objectHash: 'c' * 64,
      storedLength: 60,
      codecProfile: 'raw',
      mime: 'image/png',
    );
    DirectoryRecoveryCodec.updateExisting(file, partial({3: raw}));
    expect(
      DirectoryRecoveryCodec.read(file).residentPages[3]!.rawHash,
      raw.rawHash,
    );
    DirectoryRecoveryCodec.updateExisting(file, partial({}));
    expect(DirectoryRecoveryCodec.read(file).residentPages, isEmpty);
  });

  test(
    'v1 runtime data survives v2 migration and work item survives reopen',
    () async {
      final sqlite = sqlite3.open('${root.path}/runtime.sqlite');
      sqlite.execute(
        'CREATE TABLE local_config (config_key TEXT NOT NULL, sub_config_key TEXT NOT NULL, value TEXT NOT NULL, utime TEXT NOT NULL, PRIMARY KEY (config_key, sub_config_key))',
      );
      sqlite.execute(
        "INSERT INTO local_config VALUES ('theme', '', 'dark', '2026-01-01')",
      );
      sqlite.execute(
        File('test/fixtures/runtime_v1_download_tables.sql').readAsStringSync(),
      );
      sqlite.execute('PRAGMA user_version = 1');
      sqlite.close();

      db = openDb();
      await expectCopyIndexes('migrated');
      final repository = ContentRepository(db);
      final item = await repository.createWorkItem(
        workItemId: 'backup-1',
        kind: 'backup',
        targetNamespace: 'target-a',
        inputJson: '{"snapshotId":"abc"}',
        localArtifactPath: '${root.path}/backup.json',
        remoteDestination: 'backups/device/abc.json',
      );
      expect(item.state, 'queued');
      await repository.updateWorkItemState(item.workItemId, 'uploaded');
      await db.close();

      db = openDb();
      final existing = await db
          .customSelect(
            "SELECT value FROM local_config WHERE config_key = 'theme'",
          )
          .getSingle();
      expect(existing.read<String>('value'), 'dark');
      final resumed = await ContentRepository(db)
          .listWorkItems(kind: 'backup', targetNamespace: 'target-a');
      expect(resumed, hasLength(1));
      expect(resumed.single.state, 'uploaded');
      expect(resumed.single.inputJson, '{"snapshotId":"abc"}');
      expect(resumed.single.remoteDestination, 'backups/device/abc.json');
      expect(
        await ContentRepository(db)
            .listWorkItems(kind: 'backup', targetNamespace: 'other'),
        isEmpty,
      );
    },
  );

  test(
    'closed SQLite manifest hash, head folding, and lineage correction',
    () async {
      db = openDb();
      final repository = ContentRepository(db);
      final first = PortableManifestCodec.write(
        File('${root.path}/first.sqlite'),
        manifest(lineage: const [ManifestLineage(41, 42, 'source-parent')]),
      );
      final equivalent = PortableManifestCodec.write(
        File('${root.path}/equivalent.sqlite'),
        manifest(
          objectHash: 'b',
          lineage: const [ManifestLineage(41, 42, 'source-parent')],
        ),
      );
      final identical = PortableManifestCodec.write(
        File('${root.path}/identical.sqlite'),
        manifest(lineage: const [ManifestLineage(41, 42, 'source-parent')]),
      );
      expect(identical.manifestId, first.manifestId);
      final unrelated = PortableManifestCodec.write(
        File('${root.path}/unrelated.sqlite'),
        manifest(rawHash: 'c', objectHash: 'c'),
      );
      expect(
        PortableManifestCodec.read(first.file).pages.single.rawHash,
        'a' * 64,
      );
      expect(first.manifestId, isNot(equivalent.manifestId));
      expect(
        manifest().businessEquivalentTo(manifest(objectHash: 'b')),
        isTrue,
      );
      await repository.importManifest('target-a', first);
      await repository.importManifest('target-a', equivalent);
      await repository.importManifest('target-a', unrelated);
      expect(
        (await repository.listManifestHeads(
          'target-a',
          42,
          'original',
        )).map((head) => head.manifestIds.length),
        [2, 1],
      );
      expect(
        (await repository.findObjectRepresentations('target-a', 'a' * 64)),
        hasLength(2),
      );
      expect(
        await repository.findObjectRepresentations('target-b', 'a' * 64),
        isEmpty,
      );

      final correction = PortableManifestCodec.write(
        File('${root.path}/correction.sqlite'),
        manifest(
          rawHash: 'c',
          objectHash: 'c',
          supersedes: [
            first.manifestId,
            equivalent.manifestId,
            unrelated.manifestId,
          ],
        ),
      );
      await repository.importManifest('target-a', correction);
      await db.close();
      db = openDb();
      final heads = await ContentRepository(db)
          .listManifestHeads('target-a', 42, 'original');
      expect(heads, hasLength(1));
      expect(heads.single.manifestIds, [correction.manifestId]);
      expect(heads.single.representative.lineage, isEmpty);
    },
  );

  test(
    'page replacement journals the same copy and revokes stale cleanup',
    () async {
      db = openDb();
      await expectCopyIndexes('fresh');
      var repository = ContentRepository(db);
      final copyId = await repository.createCopy(
        copyId: 'copy-1',
        gid: 42,
        representation: 'original',
        rootPath: '${root.path}/gallery',
      );
      expect(
        () => repository.createCopy(
          copyId: 'copy-duplicate',
          gid: 43,
          representation: 'original',
          rootPath: '${root.path}/gallery',
        ),
        throwsA(isA<Exception>()),
      );
      await repository.setCurrentCopy(copyId);
      await repository.putPage(
        ContentPageRecord(
          copyId: copyId,
          ordinal: 0,
          relativePath: '001.jpg',
          rawHash: 'a' * 64,
          rawLength: 100,
          mime: 'image/jpeg',
          width: 800,
          height: 600,
          state: 'complete',
        ),
      );
      final work = await repository.createWorkItem(
        kind: 'content',
        targetNamespace: 'target-a',
        inputJson: '{"pages":["old"]}',
        copyId: copyId,
        finishAction: 'release',
      );
      final replacement = await repository.enqueuePageReplacement(
        copyId: copyId,
        ordinal: 0,
        oldPath: '001.jpg',
        newPath: '001.jpg',
        tempPath: '.work/001.new',
        retainedPath: '.work/001.old',
      );
      expect(
        (await repository.getWorkItem(work.workItemId))!.finishAction,
        'keep',
      );
      await repository.setPageReplacementReady(
        replacement.replacementId,
        '{"rawHash":"new"}',
      );
      await db.close();

      db = openDb();
      repository = ContentRepository(db);
      expect(
        (await repository.listPageReplacements(copyId)).single.state,
        'committing',
      );
      await repository.commitPageReplacement(
        replacement.replacementId,
        ContentPageRecord(
          copyId: copyId,
          ordinal: 0,
          relativePath: '001.jpg',
          rawHash: 'b' * 64,
          rawLength: 110,
          mime: 'image/jpeg',
          width: 800,
          height: 600,
          state: 'complete',
        ),
      );
      expect((await repository.listPages(copyId)).single.rawHash, 'b' * 64);
      expect(
        (await repository.listPageReplacements(copyId)).single.state,
        'committed',
      );
      await repository.finishPageReplacement(replacement.replacementId);
      expect(await repository.listPageReplacements(copyId), isEmpty);
      expect(
        (await repository.getWorkItem(work.workItemId))!.inputJson,
        '{"pages":["old"]}',
      );
    },
  );

  test(
    'directory recovery keeps local task rows outside portable manifests',
    () async {
      db = openDb();
      final incomplete = File('${root.path}/incomplete.sqlite');
      DirectoryRecoveryCodec.writeNew(
        incomplete,
        const DirectoryRecoveryProjection(
          copyId: 'copy-in-progress',
          taskKind: 'gallery',
          taskState: 'paused',
          taskJson: '{"priority":2}',
          pages: [
            DirectoryRecoveryPage(0, '001.jpg', 'complete'),
            DirectoryRecoveryPage(1, null, 'pending'),
          ],
        ),
      );
      final restored = DirectoryRecoveryCodec.read(incomplete);
      expect(restored.taskState, 'paused');
      expect(restored.pages[1].relativePath, isNull);
      expect(restored.completeManifest, isNull);
      expect(
        () => PortableManifestCodec.read(incomplete),
        throwsFormatException,
      );

      final complete = File('${root.path}/complete-recovery.sqlite');
      DirectoryRecoveryCodec.writeNew(
        complete,
        DirectoryRecoveryProjection(
          copyId: 'copy-complete',
          taskKind: 'archive',
          taskState: 'complete',
          taskJson: '{}',
          pages: const [DirectoryRecoveryPage(0, '001.jpg', 'complete')],
          completeManifest: manifest(),
        ),
      );
      expect(DirectoryRecoveryCodec.read(complete).completeManifest!.gid, 42);
      expect(() => PortableManifestCodec.read(complete), throwsFormatException);
    },
  );
}
