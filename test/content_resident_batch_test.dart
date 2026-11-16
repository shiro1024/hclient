import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/service/content_sync/content_repository.dart';
import 'package:jhentai/src/service/content_sync/portable_manifest.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory home;
  late AppDb db;
  late ContentRepository repository;
  var serial = 0;
  const namespace = 'library';

  setUp(() async {
    home = await Directory.systemTemp.createTemp('hclient-resident-batch-');
    db = AppDb.testing(NativeDatabase.memory());
    repository = ContentRepository(db);
    serial = 0;
  });
  tearDown(() async {
    await db.close();
    await home.delete(recursive: true);
  });

  PortableManifest manifest(
    List<String> hashes, {
    int gid = 42,
    List<String> supersedes = const [],
  }) => PortableManifest(
    gid: gid,
    representation: 'original',
    galleryUrl: 'https://example.org/g/$gid/token/',
    title: 'Gallery',
    tags: const [],
    supersedes: supersedes,
    pages: [
      for (final hash in hashes)
        PortablePage(
          rawHash: hash * 64,
          rawLength: 100,
          objectHash: hash * 64,
          storedLength: 100,
          codecProfile: 'raw',
          mime: 'image/jpeg',
        ),
    ],
  );

  Future<ManifestArtifact> index(
    PortableManifest manifest, {
    bool published = true,
    String target = namespace,
  }) async {
    final artifact = PortableManifestCodec.write(
      File('${home.path}/manifest-${serial++}.sqlite'),
      manifest,
    );
    await repository.importManifest(target, artifact);
    if (published) {
      await repository.recordRemoteResource(
        targetNamespace: target,
        href: 'manifests/${artifact.manifestId}.sqlite',
        kind: 'manifest',
        objectHash: artifact.manifestId,
      );
    }
    return artifact;
  }

  Future<String> copy(
    String id,
    List<String> hashes, {
    String ownerNamespace = namespace,
    String representation = 'original',
    bool encoded = false,
  }) async {
    await repository.createCopy(
      copyId: id,
      gid: 42,
      representation: representation,
      rootPath: '${home.path}/$id',
    );
    await repository.handoffCopy(id, ownerNamespace);
    for (var i = 0; i < hashes.length; i++) {
      await repository.putPage(
        ContentPageRecord(
          copyId: id,
          ordinal: i,
          relativePath: '$i.jpg',
          rawHash: hashes[i] * 64,
          rawLength: 100,
          mime: 'image/jpeg',
          width: null,
          height: null,
          state: 'completed',
          codecProfile: encoded ? 'another-local-codec' : null,
          objectHash: encoded ? 'f' * 64 : null,
          storedLength: encoded ? 80 : null,
        ),
      );
    }
    return id;
  }

  Future<void> expectResidents(Set<String> ids, Set<String> expected) async {
    final scalar = <String>{};
    for (final id in ids) {
      if (await repository.isCloudResident(id, namespace)) {
        scalar.add(id);
      }
    }
    expect(scalar, expected);
    expect(await repository.cloudResidentCopyIds(namespace, ids), expected);
  }

  test(
    'indexed bytes become cloud residents only while remotely published',
    () async {
      final owner = await copy('owner', ['a']);
      final artifact = await index(manifest(['a']), published: false);
      await expectResidents({owner}, {});
      await repository.recordRemoteResource(
        targetNamespace: 'other-library',
        href: 'same-hash',
        kind: 'manifest',
        objectHash: artifact.manifestId,
      );
      await expectResidents({owner}, {});
      await repository.recordRemoteResource(
        targetNamespace: namespace,
        href: 'published',
        kind: 'manifest',
        objectHash: artifact.manifestId,
      );
      await expectResidents({owner}, {owner});
      await db.customStatement(
        'DELETE FROM content_remote_resource WHERE target_namespace = ?',
        [namespace],
      );
      await expectResidents({owner}, {});
    },
  );

  test('each same-gallery copy must match one entire published head', () async {
    await index(manifest(['a', 'b']));
    await index(manifest(['c', 'd']));
    final first = await copy('first', ['a', 'b']);
    final second = await copy('second', ['c', 'd']);
    final encoded = await copy('encoded', ['a', 'b'], encoded: true);
    final mixed = await copy('mixed', ['a', 'd']);
    final shorter = await copy('shorter', ['a']);
    final resampled = await copy('resampled', [
      'a',
      'b',
    ], representation: 'resampled');
    final otherNamespace = await copy('other', [
      'a',
      'b',
    ], ownerNamespace: 'other');
    final partial = await copy('partial', ['a', 'b']);
    final sparse = await copy('sparse', ['a', 'b']);
    final wrongLength = await copy('length', ['a', 'b']);
    final retiring = await copy('retiring', ['a', 'b']);
    final empty = await copy('empty', []);
    await db.customStatement(
      "UPDATE content_page SET state='downloading' WHERE copy_id=? AND ordinal=1",
      [partial],
    );
    await db.customStatement(
      'UPDATE content_page SET ordinal=3 WHERE copy_id=? AND ordinal=1',
      [sparse],
    );
    await db.customStatement(
      'UPDATE content_page SET raw_length=101 WHERE copy_id=? AND ordinal=1',
      [wrongLength],
    );
    await db.customStatement(
      "UPDATE content_copy SET lifecycle='retiring' WHERE copy_id=?",
      [retiring],
    );
    await db.customStatement(
      '''
      INSERT INTO content_page_replacement
        (replacement_id,copy_id,ordinal,queue_order,state,old_path,new_path,temp_path,retained_path,created_at)
      VALUES ('pending',?,0,0,'downloading','old','new','temp','retained','now')
    ''',
      [first],
    );
    await expectResidents(
      {
        first,
        second,
        encoded,
        mixed,
        shorter,
        resampled,
        otherNamespace,
        partial,
        sparse,
        wrongLength,
        retiring,
        empty,
        'missing',
      },
      {first, second, encoded},
    );
    expect(await repository.cloudResidentCopyIds(namespace, []), isEmpty);
  });

  test(
    'all published manifests suppress superseded heads across gallery groups',
    () async {
      final owner = await copy('owner', ['a']);
      final original = await index(manifest(['a']));
      final correction = await index(
        manifest(['b'], gid: 43, supersedes: [original.manifestId]),
        published: false,
      );
      await expectResidents({owner}, {owner});
      await repository.recordRemoteResource(
        targetNamespace: namespace,
        href: 'correction',
        kind: 'manifest',
        objectHash: correction.manifestId,
      );
      await expectResidents({owner}, {});
      await index(
        manifest(['c'], gid: 44, supersedes: [correction.manifestId]),
      );
      await expectResidents({owner}, {});
      await db.customStatement(
        "DELETE FROM content_remote_resource WHERE href='correction'",
      );
      await expectResidents({owner}, {owner});
    },
  );

  test('null supersedes and unrelated or superseded invalid payloads keep their existing scope', () async {
    final owner = await copy('owner', ['a']);
    final obsolete = await index(manifest(['b']));
    await db.customStatement(
      'UPDATE content_manifest SET portable_json=? WHERE manifest_id=?',
      [
        jsonEncode({'supersedes': [], 'pages': 'invalid'}),
        obsolete.manifestId,
      ],
    );
    await index(manifest(['a'], supersedes: [obsolete.manifestId]));
    final unrelated = await index(manifest(['c'], gid: 999));
    await db.customStatement(
      'UPDATE content_manifest SET portable_json=? WHERE manifest_id=?',
      [
        jsonEncode({
          'supersedes': [null],
          'pages': 'invalid',
        }),
        unrelated.manifestId,
      ],
    );
    await expectResidents({owner}, {owner});
  });

  test('candidate grouping follows manifest database columns', () async {
    final owner = await copy('owner', ['a']);
    final artifact = await index(manifest(['a'], gid: 43));
    await db.customStatement(
      'UPDATE content_manifest SET gid=42 WHERE manifest_id=?',
      [artifact.manifestId],
    );
    await expectResidents({owner}, {owner});
  });
}
