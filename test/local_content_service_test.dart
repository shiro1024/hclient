import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:sqlite3/sqlite3.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/service/content_sync/content_repository.dart';
import 'package:jhentai/src/service/local_content_service.dart';
import 'package:jhentai/src/service/log.dart';
import 'package:jhentai/src/service/path_service.dart';
import 'package:jhentai/src/service/content_sync/portable_manifest.dart';
import 'package:jhentai/src/service/content_codec.dart';

import 'support/test_log_service.dart';

class _FailOnceRepository extends ContentRepository {
  bool failCommit = true;
  _FailOnceRepository(super.db);

  @override
  Future<void> commitPageReplacement(
    String replacementId,
    ContentPageRecord page,
  ) async {
    if (failCommit) {
      failCommit = false;
      throw StateError('injected commit failure');
    }
    await super.commitPageReplacement(replacementId, page);
  }
}

class _CountingCommitRepository extends ContentRepository {
  int commits = 0;
  _CountingCommitRepository(super.db);
  @override
  Future<void> commitPageReplacement(String id, ContentPageRecord page) async {
    commits++;
    await super.commitPageReplacement(id, page);
  }
}

class _CommitTrackingService extends LocalContentService {
  int commitRequests = 0;
  final enteredCommit = Completer<void>();
  final secondCommit = Completer<void>();
  _CommitTrackingService({required super.repository});
  @override
  Future<void> commitPageReplacement(String id) {
    commitRequests++;
    if (!enteredCommit.isCompleted) enteredCommit.complete();
    if (commitRequests == 2) secondCommit.complete();
    return super.commitPageReplacement(id);
  }
}

enum _PageRestartStage { downloading, ready, oldRetained, newFinal, committed }

enum _RetirementRestartStage { recorded, inTrash, partlyDeleted }

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  late AppDb db;
  late LocalContentService service;
  late LogService previousLog;
  late PathService previousPaths;

  setUpAll(() {
    previousLog = log;
    log = TestLogService();
  });
  tearDownAll(() => log = previousLog);

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('hclient-local-content-');
    previousPaths = pathService;
    pathService = PathService()..appDocDir = temp;
    db = AppDb.testing(NativeDatabase(File('${temp.path}/runtime.sqlite')));
    service = LocalContentService(repository: ContentRepository(db));
  });

  tearDown(() async {
    pathService = previousPaths;
    await db.close();
    await temp.delete(recursive: true);
  });

  Future<String> createPageIn(String folder, int gid, String bytes) async {
    final root = Directory('${temp.path}/$folder');
    await root.create();
    await File('${root.path}/001.jpg').writeAsString(bytes);
    final id = await service.ensureCopy(
      gid: gid,
      representation: 'original',
      rootPath: root.path,
      makeCurrent: false,
    );
    await service.recordPage(
      copyId: id,
      ordinal: 0,
      relativePath: '001.jpg',
      rawHash: sha256.convert(bytes.codeUnits).toString(),
      rawLength: bytes.length,
    );
    await service.completeCopy(
      id,
      galleryUrl: 'https://e-hentai.org/g/$gid/0123456789/',
      title: 'Gallery',
      expectedPages: 1,
    );
    return id;
  }

  Future<String> createOnePage(String bytes) =>
      createPageIn('gallery', 41, bytes);

  test('representation adoption preserves content work and restores projection', () async {
    final copy = await createOnePage('original');
    var mutations = 0;
    var completions = 0;
    service.onBeforeMutation = (_) async {
      mutations++;
    };
    service.onCompleted = (_) async {
      completions++;
    };
    final createdWork = await service.repository.createWorkItem(
      kind: 'content',
      targetNamespace: 'target',
      copyId: copy,
      inputJson: '{}',
      finishAction: 'release',
    );
    final workId = createdWork.workItemId;
    final directory = await service.representationWorkDirectory(copy, workId);
    final artifactFile = File('${directory.path}/page.artifact');
    await artifactFile.writeAsString('pcf');
    final page = await service.repository.getPage(copy, 0);
    await db.customStatement(
      'UPDATE content_work_item SET artifacts_json = ? WHERE work_item_id = ?',
      [
        jsonEncode({
          '0': {'path': artifactFile.path, 'temporary': true},
        }),
        workId,
      ],
    );
    final entered = Completer<void>();
    final release = Completer<void>();
    final reading = service.withPageInput(copy, 0, (file) async {
      entered.complete();
      await release.future;
      expect(await file.readAsString(), 'original');
    });
    await entered.future;
    final install = service.installPageRepresentation(
      copyId: copy,
      ordinal: 0,
      artifact: ContentCodecArtifact(
        path: artifactFile.path,
        codecProfile: ContentCodec.encodedProfile,
        rawHash: page.rawHash!,
        rawLength: page.rawLength!,
        objectHash: sha256.convert('pcf'.codeUnits).toString(),
        storedLength: 3,
        isTemporary: true,
      ),
      workItemId: workId,
    );
    // Installation has to wait for the active physical page lease.
    await Future.doWhile(() async {
      final pending = await service.repository.listPageReplacements(copy);
      return pending.isEmpty || pending.single.state != 'committing';
    }).timeout(const Duration(seconds: 5));
    expect(await artifactFile.exists(), true);
    release.complete();
    await reading;
    expect(await install, true);
    expect(mutations, 0);
    expect(completions, 0);
    final work = await service.repository.getWorkItem(workId);
    expect(work!.finishAction, 'release');
    expect((jsonDecode(work.artifactsJson) as Map).containsKey('0'), false);
    final resident = await service.repository.getPage(copy, 0);
    expect(resident.codecProfile, ContentCodec.encodedProfile);
    expect(resident.relativePath, '001.jpg.pcf');
    expect(await File('${temp.path}/gallery/001.jpg').exists(), false);
    final projection = DirectoryRecoveryCodec.read(
      File('${temp.path}/gallery/.content.sqlite'),
    );
    expect(projection.pages.single.relativePath, '001.jpg.pcf');
    expect(
      projection.completeManifest!.pages.single.objectHash,
      resident.objectHash,
    );
    expect(
      projection.completeManifest!.codecProfiles.keys,
      contains(ContentCodec.encodedProfile),
    );
    final restoredRoot = Directory('${temp.path}/restored');
    await restoredRoot.create();
    await File('${temp.path}/gallery/001.jpg.pcf')
        .copy('${restoredRoot.path}/001.jpg.pcf');
    final restored = await service.restoreDirectoryProjection(
      restoredRoot.path,
      projection,
      gid: 41,
      representation: 'original',
    );
    expect(
      (await service.repository.getPage(restored, 0)).codecProfile,
      ContentCodec.encodedProfile,
    );
    expect(
      (await service.repository.getPage(restored, 0)).rawHash,
      page.rawHash,
    );
  });

  test('strict representation projection includes installed pages while another page downloads', () async {
    final copy = await createOnePage('original');
    await File('${temp.path}/gallery/second.png').writeAsString('second');
    await service.recordPage(
      copyId: copy,
      ordinal: 1,
      relativePath: 'second.png',
      rawHash: sha256.convert('second'.codeUnits).toString(),
      rawLength: 6,
      mime: 'image/png',
    );
    await service.completeCopy(
      copy,
      galleryUrl: 'https://e-hentai.org/g/41/0123456789/',
      title: 'Gallery',
      expectedPages: 2,
    );
    await service.enqueuePageReplacement(
      copyId: copy,
      ordinal: 1,
      newRelativePath: 'new.png',
    );
    expect(await service.completedInput(copy), null);
    var notifications = 0;
    service.onCompleted = (_) async {
      notifications++;
    };
    final page = await service.repository.getPage(copy, 0);
    final directory = await service.representationWorkDirectory(copy, 'upload');
    final artifact = File('${directory.path}/page.artifact');
    await artifact.writeAsString('pcf');
    expect(
      await service.installPageRepresentation(
        copyId: copy,
        ordinal: 0,
        artifact: ContentCodecArtifact(
          path: artifact.path,
          codecProfile: ContentCodec.encodedProfile,
          rawHash: page.rawHash!,
          rawLength: page.rawLength!,
          objectHash: sha256.convert('pcf'.codeUnits).toString(),
          storedLength: 3,
          isTemporary: true,
        ),
      ),
      true,
    );
    final projection = service.readProjection('${temp.path}/gallery');
    expect(projection.pages.map((page) => page.relativePath), [
      '001.jpg.pcf',
      'second.png',
    ]);
    expect(
      projection.completeManifest!.pages.first.codecProfile,
      ContentCodec.encodedProfile,
    );
    expect(await File('${temp.path}/gallery/001.jpg').exists(), false);
    expect(await service.completedInput(copy), null);
    expect(notifications, 0);
  });

  test('projection failure retains old page and committed representation journal for replay', () async {
    final copy = await createOnePage('original');
    final page = await service.repository.getPage(copy, 0);
    final root = '${temp.path}/gallery';
    final projection = File('$root/.content.sqlite');
    await projection.rename('$root/saved-projection.sqlite');
    await Directory(projection.path).create();
    final directory = await service.representationWorkDirectory(copy, 'upload');
    final artifact = File('${directory.path}/page.artifact');
    await artifact.writeAsString('pcf');
    await expectLater(
      service.installPageRepresentation(
        copyId: copy,
        ordinal: 0,
        artifact: ContentCodecArtifact(
          path: artifact.path,
          codecProfile: ContentCodec.encodedProfile,
          rawHash: page.rawHash!,
          rawLength: page.rawLength!,
          objectHash: sha256.convert('pcf'.codeUnits).toString(),
          storedLength: 3,
          isTemporary: true,
        ),
      ),
      throwsA(isA<FileSystemException>()),
    );
    final pending = (await service.repository.listPageReplacements(copy))
        .single;
    expect(pending.state, 'committed');
    expect(await File(pending.retainedPath).readAsString(), 'original');
    expect(await File(pending.newPath).readAsString(), 'pcf');
    await Directory(projection.path).delete();
    await File('$root/saved-projection.sqlite').rename(projection.path);
    await service.finishCommittingReplacements(copy);
    expect(await service.repository.listPageReplacements(copy), isEmpty);
    expect(await File(pending.retainedPath).exists(), false);
    expect(
      service.readProjection(root).pages.single.relativePath,
      '001.jpg.pcf',
    );
  });

  for (final operation in ['relocation', 'retirement']) {
    test(
      'representation commit joins $operation while reader holds lease',
      () async {
        final repository = _CountingCommitRepository(db);
        final tracked = _CommitTrackingService(repository: repository);
        service = tracked;
        final copy = await createOnePage('original');
        final page = await repository.getPage(copy, 0);
        final directory = await service.representationWorkDirectory(
          copy,
          'upload',
        );
        final artifact = File('${directory.path}/page.artifact');
        await artifact.writeAsString('pcf');
        final entered = Completer<void>();
        final release = Completer<void>();
        final reading = service.withPageInput(copy, 0, (file) async {
          entered.complete();
          await release.future;
          expect(await file.readAsString(), 'original');
        });
        await entered.future;
        final installation = service.installPageRepresentation(
          copyId: copy,
          ordinal: 0,
          artifact: ContentCodecArtifact(
            path: artifact.path,
            codecProfile: ContentCodec.encodedProfile,
            rawHash: page.rawHash!,
            rawLength: page.rawLength!,
            objectHash: sha256.convert('pcf'.codeUnits).toString(),
            storedLength: 3,
            isTemporary: true,
          ),
        );
        await tracked.enteredCommit.future;
        if (operation == 'retirement') {
          service.onBeforeRetirement = (copyId) async {
            await service.finishCommittingReplacements(copyId);
            // The retirement coordinator has marked the in-memory owner as
            // retiring, but strict projection must precede root retirement.
            expect(
              service
                  .readProjection('${temp.path}/gallery')
                  .pages
                  .single
                  .relativePath,
              '001.jpg.pcf',
            );
            expect(await File('${temp.path}/gallery/001.jpg').exists(), false);
          };
        }
        final changing = operation == 'relocation'
            ? service.relocateCopy(copy, '${temp.path}/moved')
            : service.retireCopy(copy);
        await tracked.secondCommit.future.timeout(const Duration(seconds: 5));
        release.complete();
        await reading;
        expect(await installation, true);
        await changing;
        expect(repository.commits, 1);
        if (operation == 'relocation') {
          expect(
            await File('${temp.path}/moved/gallery/001.jpg.pcf').readAsString(),
            'pcf',
          );
          expect(
            await File('${temp.path}/moved/gallery/001.jpg').exists(),
            false,
          );
        } else {
          expect(await Directory('${temp.path}/gallery').exists(), false);
        }
      },
    );
  }

  test('raw selection persists in runtime and independent directory can select again', () async {
    final copy = await createOnePage('original');
    final page = await service.repository.getPage(copy, 0);
    expect(
      await service.installPageRepresentation(
        copyId: copy,
        ordinal: 0,
        artifact: ContentCodecArtifact(
          path: '${temp.path}/gallery/001.jpg',
          codecProfile: 'raw',
          rawHash: page.rawHash!,
          rawLength: page.rawLength!,
          objectHash: page.rawHash!,
          storedLength: page.rawLength!,
          isTemporary: false,
        ),
      ),
      true,
    );
    expect((await service.repository.getPage(copy, 0)).codecProfile, 'raw');
    final projection = DirectoryRecoveryCodec.read(
      File('${temp.path}/gallery/.content.sqlite'),
    );
    final root = Directory('${temp.path}/other');
    await root.create();
    await File('${temp.path}/gallery/001.jpg').copy('${root.path}/001.jpg');
    final restored = await service.restoreDirectoryProjection(
      root.path,
      projection,
      gid: 41,
      representation: 'original',
    );
    expect((await service.repository.getPage(restored, 0)).codecProfile, null);
    final replacement = await service.enqueuePageReplacement(
      copyId: copy,
      ordinal: 0,
      newRelativePath: 'new.jpg',
    );
    await File(replacement.tempPath).writeAsString('original');
    await service.finishDownloadedReplacement(
      replacement.replacementId,
      rawHash: page.rawHash!,
      rawLength: page.rawLength!,
    );
    expect((await service.repository.getPage(copy, 0)).codecProfile, 'raw');
  });

  test(
    'relocation keeps identity, relative pages, and independent copies',
    () async {
      final copy = await createPageIn('source', 41, 'first');
      final other = await createPageIn('other', 41, 'second');
      final target = Directory('${temp.path}/destination');
      await target.create();
      await Directory('${target.path}/source').create();
      await File('${target.path}/source/occupied').writeAsString('keep');
      await service.relocateCopy(copy, target.path);
      expect(await service.rootPath(copy), '${target.path}/source-1');
      expect(await Directory('${temp.path}/source').exists(), false);
      expect(
        await File('${target.path}/source/occupied').readAsString(),
        'keep',
      );
      expect(
        await service.withPageInput(copy, 0, (file) => file.readAsString()),
        'first',
      );
      expect(
        await service.withPageInput(other, 0, (file) => file.readAsString()),
        'second',
      );
      expect(
        (await service.repository.getPage(copy, 0)).relativePath,
        '001.jpg',
      );
    },
  );

  test(
    'relocation joins producers before closing input and drains readers',
    () async {
      final copy = await createOnePage('page');
      final acquired = Completer<void>();
      final release = Completer<void>();
      final read = service.withPageInput(copy, 0, (file) async {
        acquired.complete();
        await release.future;
        return file.readAsString();
      });
      await acquired.future;
      service.onBeforeRelocation = (id) async {
        expect(service.isRelocating(id), true);
        expect(
          await service.withPageInput(id, 0, (file) => file.readAsString()),
          'page',
        );
        release.complete();
      };
      await service.relocateCopy(copy, '${temp.path}/destination');
      expect(await read, 'page');
      expect(service.isRelocating(copy), false);
    },
  );

  test('producer pause failure keeps an intact owner readable', () async {
    final copy = await createOnePage('page');
    bool? usable;
    service.onBeforeRelocation = (_) async => throw StateError('pause failed');
    service.onAfterRelocation = (_, value) async {
      usable = value;
    };
    await expectLater(
      service.relocateCopy(copy, '${temp.path}/destination'),
      throwsStateError,
    );
    expect(usable, true);
    expect(service.isRelocating(copy), false);
    expect(
      await service.withPageInput(copy, 0, (file) => file.readAsString()),
      'page',
    );
  });

  test('one unavailable recovery does not block another copy', () async {
    final missing = await createPageIn('missing', 41, 'first');
    final good = await createPageIn('good', 42, 'second');
    for (final copy in [missing, good]) {
      await service.repository.createWorkItem(
        kind: 'local_relocation',
        targetNamespace: 'local',
        copyId: copy,
        inputJson: jsonEncode({
          'sourceRoot': await service.rootPath(copy),
          'targetRoot': '${temp.path}/moved-$copy',
        }),
      );
    }
    await Directory(await service.rootPath(missing)).delete(recursive: true);
    await service.recoverRelocations();
    expect(service.isRelocating(missing), true);
    expect(service.isRelocating(good), false);
    expect(
      await service.withPageInput(good, 0, (file) => file.readAsString()),
      'second',
    );
  });

  test(
    'old source cleanup failure keeps committed destination readable',
    () async {
      final copy = await createOnePage('page');
      final source = await service.rootPath(copy);
      final target = '${temp.path}/moved';
      await Directory(target).create();
      await File('$source/001.jpg').copy('$target/001.jpg');
      await service.repository.createWorkItem(
        kind: 'local_relocation',
        targetNamespace: 'local',
        copyId: copy,
        inputJson: jsonEncode({'sourceRoot': source, 'targetRoot': target}),
      );
      await service.repository.relocateCopyRoot(copy, source, target);
      await Process.run('chmod', ['500', source]);
      try {
        await service.recoverRelocations();
        expect(await Directory(source).exists(), true);
        expect(service.isRelocating(copy), false);
        expect(
          await service.withPageInput(copy, 0, (file) => file.readAsString()),
          'page',
        );
      } finally {
        await Process.run('chmod', ['700', source]);
      }
      await service.recoverRelocations();
      expect(await Directory(source).exists(), false);
    },
    skip: Platform.isWindows,
  );

  test('root switch rebases unfinished task rows but leaves completed tasks untouched', () async {
    final pending = await createPageIn('pending-task', 101, 'pending');
    final completed = await createPageIn('completed-task', 102, 'complete');
    for (final entry in [
      (101, pending, 2, 'pending-task'),
      (102, completed, 4, 'completed-task'),
    ]) {
      await db.customStatement(
        'INSERT INTO gallery_downloaded_v2 (gid,copy_id,token,title,category,page_count,gallery_url,publish_time,download_status_index,insert_time,priority,group_name) VALUES (?,?,?, ?,?,1,?,?,?, ?,0,?)',
        [
          entry.$1,
          entry.$2,
          'token',
          'title',
          'Manga',
          'url',
          'now',
          entry.$3,
          'now',
          'default',
        ],
      );
      await db.customStatement(
        'INSERT INTO image (gid,url,serialNo,path,imageHash,downloadStatusIndex) VALUES (?, ?,0,?,?,0)',
        [entry.$1, 'url', '${entry.$4}/001.jpg', 'hash'],
      );
    }
    await service.relocateCopy(pending, '${temp.path}/destination');
    await service.relocateCopy(completed, '${temp.path}/destination');
    final rows = await db
        .customSelect('SELECT path FROM image ORDER BY gid')
        .get();
    expect(rows[0].read<String>('path'), 'destination/pending-task/001.jpg');
    expect(rows[1].read<String>('path'), 'completed-task/001.jpg');
  });

  test(
    'new destination request completes prior journal then moves onward',
    () async {
      final copy = await createOnePage('page');
      final source = await service.rootPath(copy);
      final prior = '${temp.path}/prior/gallery';
      await Directory('${temp.path}/prior').create();
      await service.repository.createWorkItem(
        kind: 'local_relocation',
        targetNamespace: 'local',
        copyId: copy,
        inputJson: jsonEncode({'sourceRoot': source, 'targetRoot': prior}),
      );
      await Directory(source).rename(prior);
      await service.relocateCopy(copy, '${temp.path}/requested');
      expect(await service.rootPath(copy), '${temp.path}/requested/gallery');
      expect(await Directory(prior).exists(), false);
    },
  );

  test('uncommitted installed target is rebuilt from the resumed authoritative source', () async {
    final copy = await createOnePage('original');
    final source = await service.rootPath(copy);
    final target = '${temp.path}/destination/gallery';
    await Directory(target).create(recursive: true);
    await File('$source/001.jpg').copy('$target/001.jpg');
    await File('$target/obsolete.tmp').writeAsString('stale snapshot');
    final work = await service.repository.createWorkItem(
      kind: 'local_relocation',
      targetNamespace: 'local',
      copyId: copy,
      inputJson: jsonEncode({'sourceRoot': source, 'targetRoot': target}),
    );
    // The installed target survived, but the failed transaction left source
    // authoritative. Resumed producers change a page and download another.
    await File('$source/001.jpg').writeAsString('changed');
    await File('$source/002.jpg').writeAsString('new page');
    await File('$source/resume.tmp').writeAsString('new partial bytes');
    for (final page in [
      (0, '001.jpg', 'changed'),
      (1, '002.jpg', 'new page'),
    ]) {
      await service.recordPage(
        copyId: copy,
        ordinal: page.$1,
        relativePath: page.$2,
        rawHash: sha256.convert(page.$3.codeUnits).toString(),
        rawLength: page.$3.length,
      );
    }
    final restarted = LocalContentService(repository: ContentRepository(db));
    await restarted.recoverRelocations();
    expect(await restarted.rootPath(copy), target);
    expect(
      await restarted.withPageInput(copy, 0, (file) => file.readAsString()),
      'changed',
    );
    expect(
      await restarted.withPageInput(copy, 1, (file) => file.readAsString()),
      'new page',
    );
    expect(
      await File('$target/resume.tmp').readAsString(),
      'new partial bytes',
    );
    expect(await File('$target/obsolete.tmp').exists(), false);
    expect(await Directory(source).exists(), false);
    expect(
      (await restarted.repository.getWorkItem(work.workItemId))!.state,
      'completed',
    );
  });

  for (final switched in [false, true]) {
    for (final restart in [false, true]) {
      test(
        'retirement settles relocation leftovers switched=$switched restart=$restart',
        () async {
          final copy = await createOnePage('page');
          final independent = await createPageIn('independent', 42, 'keep');
          final source = await service.rootPath(copy);
          final target = '${temp.path}/destination/gallery';
          await Directory(target).create(recursive: true);
          await File('$source/001.jpg').copy('$target/001.jpg');
          final work = await service.repository.createWorkItem(
            kind: 'local_relocation',
            targetNamespace: 'local',
            copyId: copy,
            inputJson: jsonEncode({'sourceRoot': source, 'targetRoot': target}),
          );
          final stage =
              '${temp.path}/destination/.content-relocation-${work.workItemId}';
          await Directory(stage).create();
          await File('$stage/partial.tmp').writeAsString('partial');
          if (switched) {
            await service.repository.relocateCopyRoot(copy, source, target);
          }
          if (restart) {
            // Retirement reached durable completion for its authoritative root,
            // but the interrupted move's other directories remain on disk.
            final root = await service.rootPath(copy);
            await service.repository.markCopyRetiring(
              copy,
              '${temp.path}/trash/$copy',
            );
            await Directory(root).delete(recursive: true);
            await service.repository.updateCopyCleanupState(copy, 'completed');
            await db.close();
            db = AppDb.testing(
              NativeDatabase(File('${temp.path}/runtime.sqlite')),
            );
            service = LocalContentService(repository: ContentRepository(db));
            await service.doInitBean();
          } else {
            await service.retireCopy(copy);
          }
          for (final directory in [source, target, stage]) {
            expect(await Directory(directory).exists(), false);
          }
          expect(
            (await service.repository.getWorkItem(work.workItemId))!.state,
            'cancelled',
          );
          expect(service.registeredRoot(copy), null);
          expect(await service.copyIdForRoot(target), null);
          expect(await service.currentCopyId(41, 'original'), null);
          expect(
            await service.withPageInput(
              independent,
              0,
              (file) => file.readAsString(),
            ),
            'keep',
          );
          // A second recovery cannot resurrect the retired target or its map.
          await service.recoverRelocations();
          expect(service.registeredRoot(copy), null);
          expect(await Directory(target).exists(), false);
        },
      );
    }
  }

  for (final switched in [false, true]) {
    test(
      'restart relocation after install with owner switched=$switched',
      () async {
        final copy = await createOnePage('page');
        final source = await service.rootPath(copy);
        final target = '${temp.path}/destination/gallery';
        await Directory('${temp.path}/destination').create();
        // Cross-volume installation preserves source until owner switch.
        await Directory(target).create();
        await File('$source/001.jpg').copy('$target/001.jpg');
        final work = await service.repository.createWorkItem(
          kind: 'local_relocation',
          targetNamespace: 'local',
          copyId: copy,
          inputJson: jsonEncode({'sourceRoot': source, 'targetRoot': target}),
        );
        if (switched)
          await service.repository.relocateCopyRoot(copy, source, target);
        final restarted = LocalContentService(
          repository: ContentRepository(db),
        );
        await restarted.recoverRelocations();
        expect(await restarted.rootPath(copy), target);
        expect(await Directory(source).exists(), false);
        expect(
          await restarted.withPageInput(copy, 0, (file) => file.readAsString()),
          'page',
        );
        expect(
          (await restarted.repository.getWorkItem(work.workItemId))!.state,
          'completed',
        );
      },
    );
  }

  test(
    'restart relocation after same-volume rename before owner switch',
    () async {
      final copy = await createOnePage('page');
      final source = await service.rootPath(copy);
      final target = '${temp.path}/destination/gallery';
      await Directory('${temp.path}/destination').create();
      await service.repository.createWorkItem(
        kind: 'local_relocation',
        targetNamespace: 'local',
        copyId: copy,
        inputJson: jsonEncode({'sourceRoot': source, 'targetRoot': target}),
      );
      await Directory(source).rename(target);
      final restarted = LocalContentService(repository: ContentRepository(db));
      await restarted.recoverRelocations();
      expect(await restarted.rootPath(copy), target);
      expect(
        await restarted.withPageInput(copy, 0, (file) => file.readAsString()),
        'page',
      );
    },
  );

  test(
    'relocation rebases pending replacement without losing downloaded bytes',
    () async {
      final copy = await createOnePage('old');
      final pending = await service.enqueuePageReplacement(
        copyId: copy,
        ordinal: 0,
        newRelativePath: 'new.jpg',
      );
      await File(pending.tempPath).writeAsString('partial');
      await service.relocateCopy(copy, '${temp.path}/destination');
      final moved = (await service.repository.listPageReplacements(copy))
          .single;
      expect(moved.state, 'downloading');
      expect(await File(moved.tempPath).readAsString(), 'partial');
      expect(
        await service.withPageInput(copy, 0, (file) => file.readAsString()),
        'old',
      );
    },
  );

  Future<void> restartOwner() async {
    await db.close();
    db = AppDb.testing(NativeDatabase(File('${temp.path}/runtime.sqlite')));
    service = LocalContentService(repository: ContentRepository(db));
    await service.doInitBean();
  }

  for (final child in ['', '/nested']) {
    test('relocation keeps owned roots disjoint for parent $child', () async {
      final first = await createOnePage('first');
      final second = await createPageIn('second', 42, 'second');
      await expectLater(
        service.relocateCopy(second, '${temp.path}/gallery$child'),
        throwsArgumentError,
      );
      expect(await service.rootPath(first), '${temp.path}/gallery');
      expect(await service.rootPath(second), '${temp.path}/second');
      expect(
        await File('${temp.path}/gallery/001.jpg').readAsString(),
        'first',
      );
      expect(
        await File('${temp.path}/second/001.jpg').readAsString(),
        'second',
      );
      expect(
        await service.repository.listWorkItems(kind: 'local_relocation'),
        isEmpty,
      );
      await service.relocateCopy(second, '${temp.path}/new-default');
      expect(await service.rootPath(second), '${temp.path}/new-default/second');
      expect(
        await service.withPageInput(second, 0, (file) => file.readAsString()),
        'second',
      );
    });
  }

  for (final stage in [
    'ready',
    'oldRetained',
    'newFinal',
    'committed',
    'projected',
  ]) {
    test('representation replacement resumes after $stage', () async {
      final copy = await createOnePage('original');
      final before = await service.repository.getPage(copy, 0);
      final replacement = await service.enqueuePageReplacement(
        copyId: copy,
        ordinal: 0,
        newRelativePath: '001.jpg.pcf',
        representationOnly: true,
      );
      await File(replacement.tempPath).writeAsString('pcf');
      final objectHash = sha256.convert('pcf'.codeUnits).toString();
      await service.repository.setPageReplacementReady(
        replacement.replacementId,
        jsonEncode({
          'representationOnly': true,
          'rawHash': before.rawHash,
          'rawLength': before.rawLength,
          'mime': 'image/jpeg',
          'codecProfile': ContentCodec.encodedProfile,
          'objectHash': objectHash,
          'storedLength': 3,
        }),
      );
      if (stage != 'ready')
        await File(replacement.oldPath).rename(replacement.retainedPath);
      if (stage == 'newFinal' || stage == 'committed' || stage == 'projected') {
        await File(replacement.tempPath).rename(replacement.newPath);
      }
      if (stage == 'committed' || stage == 'projected') {
        await service.repository.commitPageReplacement(
          replacement.replacementId,
          ContentPageRecord(
            copyId: copy,
            ordinal: 0,
            relativePath: '001.jpg.pcf',
            rawHash: before.rawHash,
            rawLength: before.rawLength,
            mime: 'image/jpeg',
            width: null,
            height: null,
            state: 'completed',
            codecProfile: ContentCodec.encodedProfile,
            objectHash: objectHash,
            storedLength: 3,
          ),
        );
      }
      if (stage == 'projected') await service.rebuildProjection(copy);
      await db.close();
      db = AppDb.testing(NativeDatabase(File('${temp.path}/runtime.sqlite')));
      service = LocalContentService(repository: ContentRepository(db));
      service.onBeforeMutation = (_) async {
        fail('representation must not mutate content');
      };
      service.onCompleted = (_) async {
        fail('representation must not publish another input');
      };
      await service.doInitBean();
      final page = await service.repository.getPage(copy, 0);
      expect(page.rawHash, before.rawHash);
      expect(page.codecProfile, ContentCodec.encodedProfile);
      expect(await File(replacement.newPath).readAsString(), 'pcf');
      expect(await File(replacement.oldPath).exists(), false);
      expect(await File(replacement.retainedPath).exists(), false);
      expect(
        service
            .readProjection('${temp.path}/gallery')
            .completeManifest!
            .pages
            .single
            .objectHash,
        objectHash,
      );
      // Same-content download keeps the resident selection and cache identity.
      final download = await service.enqueuePageReplacement(
        copyId: copy,
        ordinal: 0,
        newRelativePath: '001.jpg',
      );
      await File(download.tempPath).writeAsString('original');
      service.onCompleted = null;
      await service.finishDownloadedReplacement(
        download.replacementId,
        rawHash: before.rawHash!,
        rawLength: before.rawLength!,
      );
      expect(
        (await service.repository.getPage(copy, 0)).relativePath,
        '001.jpg.pcf',
      );
      expect(await File(replacement.newPath).readAsString(), 'pcf');
    });
  }

  for (final stage in _PageRestartStage.values) {
    test('page replacement resumes after ${stage.name} on disk', () async {
      final id = await createOnePage('old');
      final root = '${temp.path}/gallery';
      // completeCopy already flushed its projection; join any later write
      // before simulating process exit.
      await service.flushProjection(root);
      final replacement = await service.enqueuePageReplacement(
        copyId: id,
        ordinal: 0,
        newRelativePath: '001.jpg',
      );
      final oldHash = sha256.convert('old'.codeUnits).toString();
      final newHash = sha256.convert('new'.codeUnits).toString();
      await File(replacement.tempPath).writeAsString('new');
      if (stage != _PageRestartStage.downloading) {
        await service.repository.setPageReplacementReady(
          replacement.replacementId,
          jsonEncode({
            'rawHash': newHash,
            'rawLength': 3,
            'mime': 'image/jpeg',
            'width': null,
            'height': null,
          }),
        );
      }
      if (stage == _PageRestartStage.oldRetained ||
          stage == _PageRestartStage.newFinal ||
          stage == _PageRestartStage.committed) {
        await File(replacement.oldPath).rename(replacement.retainedPath);
      }
      if (stage == _PageRestartStage.newFinal ||
          stage == _PageRestartStage.committed) {
        await File(replacement.tempPath).rename(replacement.newPath);
      }
      if (stage == _PageRestartStage.committed) {
        await service.repository.commitPageReplacement(
          replacement.replacementId,
          ContentPageRecord(
            copyId: id,
            ordinal: 0,
            relativePath: '001.jpg',
            rawHash: newHash,
            rawLength: 3,
            mime: 'image/jpeg',
            width: null,
            height: null,
            state: 'completed',
          ),
        );
      }

      await restartOwner();
      if (stage == _PageRestartStage.downloading) {
        expect(await File(replacement.oldPath).readAsString(), 'old');
        expect(await File(replacement.tempPath).readAsString(), 'new');
        expect(await service.completedInput(id), isNull);
        expect((await service.repository.getPage(id, 0)).rawHash, oldHash);
        expect(
          await service.withPageInput(id, 0, (file) => file.readAsString()),
          'old',
        );
        expect(
          (await service.repository.listPageReplacements(id)).single.state,
          'downloading',
        );
        // The owner leaves the unfinished transfer to the download task.
        await service.finishDownloadedReplacement(
          replacement.replacementId,
          rawHash: newHash,
          rawLength: 3,
          mime: 'image/jpeg',
        );
      }
      expect(await File(replacement.newPath).readAsString(), 'new');
      expect(await File(replacement.tempPath).exists(), isFalse);
      expect(await File(replacement.retainedPath).exists(), isFalse);
      expect(
        (await service.repository.listPageReplacements(
          id,
          includeFinished: true,
        )).single.state,
        'completed',
      );
      expect((await service.repository.getPage(id, 0)).rawHash, newHash);
      expect((await service.completedInput(id))?.pages.single.rawHash, newHash);
      expect(
        service.readProjection(root).completeManifest?.pages.single.rawHash,
        newHash,
      );

      await service.flushProjection(root);
      await restartOwner();
      expect(await File(replacement.newPath).readAsString(), 'new');
      expect((await service.repository.getPage(id, 0)).rawHash, newHash);
      expect(await service.repository.listPageReplacements(id), isEmpty);
    });
  }

  for (final stage in _RetirementRestartStage.values) {
    test('retirement resumes after ${stage.name} on disk', () async {
      final targetId = await createOnePage('retire');
      final survivorId = await createPageIn('survivor', 42, 'survive');
      final root = Directory('${temp.path}/gallery');
      final survivor = Directory('${temp.path}/survivor');
      final trash = Directory('${temp.path}/.content-trash/$targetId');
      await service.flushProjection(root.path);
      await service.flushProjection(survivor.path);
      await service.repository.markCopyRetiring(targetId, trash.path);
      if (stage != _RetirementRestartStage.recorded) {
        await trash.parent.create(recursive: true);
        await root.rename(trash.path);
      }
      if (stage == _RetirementRestartStage.partlyDeleted) {
        await File('${trash.path}/001.jpg').delete();
      }

      await restartOwner();
      for (var open = 0; open < 2; open++) {
        expect(await root.exists(), isFalse);
        expect(await trash.exists(), isFalse);
        final retired = await db
            .customSelect(
              'SELECT lifecycle, cleanup_state FROM content_copy WHERE copy_id = ?',
              variables: [Variable.withString(targetId)],
            )
            .getSingle();
        expect(retired.read<String>('lifecycle'), 'retiring');
        expect(retired.read<String>('cleanup_state'), 'completed');
        await expectLater(service.completedInput(targetId), throwsStateError);
        expect(await survivor.exists(), isTrue);
        expect(
          await service.withPageInput(
            survivorId,
            0,
            (file) => file.readAsString(),
          ),
          'survive',
        );
        expect(await service.currentCopyId(42, 'original'), survivorId);
        if (open == 0) {
          await service.flushProjection(survivor.path);
          await restartOwner();
        }
      }
    });
  }

  test(
    'one physical root keeps its copy ID and completion survives restart',
    () async {
      final id = await createOnePage('old');
      expect(
        await service.ensureCopy(
          gid: 41,
          representation: 'original',
          rootPath: '${temp.path}/gallery',
          makeCurrent: false,
        ),
        id,
      );
      final restarted = LocalContentService(repository: ContentRepository(db));
      await restarted.doInitBean();
      final input = await restarted.completedInput(id);
      expect(
        input?.pages.single.rawHash,
        sha256.convert('old'.codeUnits).toString(),
      );
      expect(input?.title, 'Gallery');
      expect(input?.rootPath, '${temp.path}/gallery');
    },
  );

  test('equal replacement discards temporary bytes without mutation', () async {
    final id = await createOnePage('old');
    var mutationCount = 0;
    service.onBeforeMutation = (_) async {
      mutationCount++;
    };
    final replacement = await service.enqueuePageReplacement(
      copyId: id,
      ordinal: 0,
      newRelativePath: '001.jpg',
    );
    await File(replacement.tempPath).writeAsString('old');
    await service.finishDownloadedReplacement(
      replacement.replacementId,
      rawHash: sha256.convert('old'.codeUnits).toString(),
      rawLength: 3,
    );
    expect(mutationCount, 0);
    expect(await File('${temp.path}/gallery/001.jpg').readAsString(), 'old');
    expect(await File(replacement.tempPath).exists(), isFalse);
    expect(await service.completedInput(id), isNotNull);
  });

  test(
    'changed page waits only for its active read, then swaps bytes',
    () async {
      final id = await createOnePage('old');
      final repository = ContentRepository(db);
      final oldWork = await repository.createWorkItem(
        kind: 'content',
        targetNamespace: 'dav-A',
        copyId: id,
        inputJson: '{"old":true}',
        finishAction: 'release',
      );
      final held = Completer<void>();
      final entered = Completer<void>();
      final read = service.withPageInput(id, 0, (file) async {
        entered.complete();
        await held.future;
        return file.readAsString();
      });
      await entered.future;
      final replacement = await service.enqueuePageReplacement(
        copyId: id,
        ordinal: 0,
        newRelativePath: '001.jpg',
      );
      await File(replacement.tempPath).writeAsString('new');
      final commit = service.finishDownloadedReplacement(
        replacement.replacementId,
        rawHash: sha256.convert('new'.codeUnits).toString(),
        rawLength: 3,
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(await File('${temp.path}/gallery/001.jpg').readAsString(), 'old');
      held.complete();
      expect(await read, 'old');
      await commit;
      expect(
        (await repository.getWorkItem(oldWork.workItemId))?.state,
        'cancelled',
      );
      final waiting = (await repository.listWorkItems(kind: 'content'))
          .where((work) => work.copyId == id && work.state == 'waiting_input')
          .toList();
      expect(waiting, hasLength(1));
      expect(waiting.single.targetNamespace, 'dav-A');
      expect(waiting.single.finishAction, 'keep');
      expect(await File('${temp.path}/gallery/001.jpg').readAsString(), 'new');
      expect(
        (await service.completedInput(id))?.pages.single.rawHash,
        sha256.convert('new'.codeUnits).toString(),
      );
    },
  );

  test('retirement waits for a page read and removes the directory', () async {
    final id = await createOnePage('old');
    final held = Completer<void>();
    final entered = Completer<void>();
    final read = service.withPageInput(id, 0, (file) async {
      entered.complete();
      await held.future;
      return file.readAsString();
    });
    await entered.future;
    final retire = service.retireCopy(id);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(await Directory('${temp.path}/gallery').exists(), isTrue);
    held.complete();
    expect(await read, 'old');
    await retire;
    expect(await Directory('${temp.path}/gallery').exists(), isFalse);
  });

  test(
    'page enqueue revokes completed work cleanup before retirement',
    () async {
      final id = await createOnePage('old');
      final repository = ContentRepository(db);
      final work = await repository.createWorkItem(
        kind: 'content',
        targetNamespace: 'dav-A',
        copyId: id,
        inputJson: '{}',
        finishAction: 'release',
      );
      final manifestId = 'a' * 64;
      await repository.updateContentWorkProgress(
        workItemId: work.workItemId,
        state: 'completed',
        artifactsJson: '{}',
        committedObjectsJson: '[]',
        pendingManifestId: manifestId,
      );
      final replacement = await service.enqueuePageReplacement(
        copyId: id,
        ordinal: 0,
        newRelativePath: '001.jpg',
      );
      expect(
        (await repository.getWorkItem(work.workItemId))?.finishAction,
        'keep',
      );
      expect(
        await service.executeRelease(id, work.workItemId, manifestId),
        isFalse,
      );
      expect(await Directory('${temp.path}/gallery').exists(), isTrue);
      await service.abandonDownloadingReplacements(id);
      expect(await File(replacement.tempPath).exists(), isFalse);
    },
  );

  test('cleanup checks published manifest then retires exact copy', () async {
    final id = await createOnePage('old');
    final repository = ContentRepository(db);
    final work = await repository.createWorkItem(
      kind: 'content',
      targetNamespace: 'dav-A',
      copyId: id,
      inputJson: '{}',
      finishAction: 'release',
    );
    final manifestId = 'b' * 64;
    await repository.updateContentWorkProgress(
      workItemId: work.workItemId,
      state: 'completed',
      artifactsJson: '{}',
      committedObjectsJson: '[]',
      pendingManifestId: manifestId,
    );
    expect(
      await service.executeRelease(id, work.workItemId, 'c' * 64),
      isFalse,
    );
    expect(await Directory('${temp.path}/gallery').exists(), isTrue);
    expect(
      await service.executeRelease(id, work.workItemId, manifestId),
      isTrue,
    );
    expect(
      (await repository.getWorkItem(work.workItemId))?.finishAction,
      'release',
    );
    expect(await Directory('${temp.path}/gallery').exists(), isFalse);
  });

  test(
    'rename succeeded but DB commit failed keeps page closed until replay',
    () async {
      final failing = _FailOnceRepository(db);
      service = LocalContentService(repository: failing);
      final id = await createOnePage('old');
      final replacement = await service.enqueuePageReplacement(
        copyId: id,
        ordinal: 0,
        newRelativePath: '001.jpg',
      );
      await File(replacement.tempPath).writeAsString('new');
      await expectLater(
        service.finishDownloadedReplacement(
          replacement.replacementId,
          rawHash: sha256.convert('new'.codeUnits).toString(),
          rawLength: 3,
        ),
        throwsStateError,
      );
      expect(await File('${temp.path}/gallery/001.jpg').readAsString(), 'new');
      var readFinished = false;
      final read = service.withPageInput(id, 0, (file) => file.readAsString())
        ..then((_) => readFinished = true);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(readFinished, isFalse);
      await service.commitPageReplacement(replacement.replacementId);
      expect(await read, 'new');
      expect(readFinished, isTrue);
      expect(
        (await service.completedInput(id))?.pages.single.rawHash,
        sha256.convert('new'.codeUnits).toString(),
      );
    },
  );

  test('retirement cancels a pending projection timer', () async {
    final id = await createOnePage('old');
    final projection = service.readProjection('${temp.path}/gallery');
    service.scheduleProjection(
      '${temp.path}/gallery',
      DirectoryRecoveryProjection(
        copyId: id,
        taskKind: projection.taskKind,
        taskState: projection.taskState,
        taskJson: projection.taskJson,
        pages: projection.pages,
        completeManifest: projection.completeManifest,
      ),
    );
    await service.retireCopy(id);
    await Future<void>.delayed(const Duration(seconds: 6));
    expect(await Directory('${temp.path}/gallery').exists(), isFalse);
  });

  test('projection merge leaves unchanged page rows untouched', () async {
    final id = await createOnePage('old');
    final file = File('${temp.path}/gallery/.content.sqlite');
    final sqlite = sqlite3.open(file.path);
    sqlite.execute('CREATE TABLE audit (updates INTEGER NOT NULL)');
    sqlite.execute('INSERT INTO audit VALUES (0)');
    sqlite.execute('''CREATE TRIGGER page_update AFTER UPDATE ON local_page
      BEGIN UPDATE audit SET updates = updates + 1; END''');
    sqlite.close();
    final projection = service.readProjection('${temp.path}/gallery');
    service.scheduleProjection(
      '${temp.path}/gallery',
      DirectoryRecoveryProjection(
        copyId: id,
        taskKind: projection.taskKind,
        taskState: projection.taskState,
        taskJson: projection.taskJson,
        pages: projection.pages,
        completeManifest: projection.completeManifest,
      ),
    );
    await service.flushProjection('${temp.path}/gallery');
    final check = sqlite3.open(file.path);
    expect(check.select('SELECT updates FROM audit').single['updates'], 0);
    check.close();
  });
  test(
    'one blocked retirement does not hide later owners on startup',
    () async {
      final activeId = await createOnePage('active');
      final blockedRoot = await Directory('${temp.path}/blocked').create();
      await File('${blockedRoot.path}/page.jpg').writeAsString('blocked');
      final blockedId = await service.ensureCopy(
        gid: 42,
        representation: 'original',
        rootPath: blockedRoot.path,
      );
      final trash = await Directory('${temp.path}/.content-trash/$blockedId')
          .create(recursive: true);
      await service.repository.markCopyRetiring(blockedId, trash.path);
      final restarted = LocalContentService(repository: service.repository);
      await restarted.doInitBean();
      expect(restarted.isManagedDirectory(blockedRoot.path), isTrue);
      expect(restarted.isManagedDirectory(trash.path), isTrue);
      expect(
        restarted
            .managedPageForPathSync('${temp.path}/gallery/001.jpg')
            ?.copyId,
        activeId,
      );
      expect(
        await restarted.withPageInput(
          activeId,
          0,
          (file) => file.readAsString(),
        ),
        'active',
      );
      await trash.delete(recursive: true);
      await restarted.retireCopy(blockedId);
      expect(await blockedRoot.exists(), isFalse);
    },
  );
}
