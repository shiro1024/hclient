import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/service/content_sync/content_repository.dart';
import 'package:jhentai/src/service/local_content_service.dart';
import 'package:jhentai/src/service/log.dart';
import 'package:jhentai/src/service/path_service.dart';
import 'package:jhentai/src/setting/download_setting.dart';

import 'support/test_log_service.dart';

class _StartupRepository extends ContentRepository {
  final List<String> replacementReads = [];
  int pendingScans = 0;
  _StartupRepository(super.db);

  @override
  Future<Set<String>> pendingPageReplacementCopyIds() {
    pendingScans++;
    return super.pendingPageReplacementCopyIds();
  }

  @override
  Future<List<PageReplacementRecord>> listPageReplacements(
    String copyId, {
    bool includeFinished = false,
  }) {
    replacementReads.add(copyId);
    return super.listPageReplacements(copyId, includeFinished: includeFinished);
  }
}

class _StartupService extends LocalContentService {
  final Map<String, int> writes = {};
  bool failNextWrite = false;
  _StartupService({required super.repository});

  @override
  Future<void> flushProjection(String rootPath) async {
    writes.update(rootPath, (n) => n + 1, ifAbsent: () => 1);
    if (failNextWrite) {
      failNextWrite = false;
      throw const FileSystemException('injected projection write failure');
    }
    await super.flushProjection(rootPath);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory home;
  late AppDb db;
  late _StartupRepository repository;
  late LocalContentService service;
  late LogService oldLog;
  late PathService oldPaths;
  late DownloadSetting oldSetting;

  setUp(() async {
    oldLog = log;
    log = TestLogService();
    oldPaths = pathService;
    oldSetting = downloadSetting;
    home = await Directory.systemTemp.createTemp('hclient-startup-test-');
    pathService = PathService()..appDocDir = home;
    downloadSetting = DownloadSetting()..downloadPath = home.path.obs;
    db = AppDb.testing(NativeDatabase(File('${home.path}/runtime.sqlite')));
    repository = _StartupRepository(db);
    service = LocalContentService(repository: repository);
  });
  tearDown(() async {
    await db.close();
    await home.delete(recursive: true);
    log = oldLog;
    pathService = oldPaths;
    downloadSetting = oldSetting;
  });

  Future<String> complete(String folder, int gid) async {
    final root = await Directory('${home.path}/$folder').create();
    await File('${root.path}/page.jpg').writeAsString('page');
    final id = await service.ensureCopy(
      gid: gid,
      representation: 'original',
      rootPath: root.path,
    );
    await service.recordPage(
      copyId: id,
      ordinal: 0,
      relativePath: 'page.jpg',
      rawHash: sha256.convert('page'.codeUnits).toString(),
      rawLength: 4,
    );
    await service.completeCopy(
      id,
      galleryUrl: 'https://example.org/g/$gid/token/',
      title: folder,
    );
    return id;
  }

  test('startup skips empty journals and retains downloading work', () async {
    final unchanged = await complete('unchanged', 1);
    final pending = await complete('pending', 2);
    await service.enqueuePageReplacement(
      copyId: pending,
      ordinal: 0,
      newRelativePath: 'next.jpg',
    );
    repository.replacementReads.clear();
    final restarted = _StartupService(repository: repository);
    await restarted.doInitBean();
    expect(repository.pendingScans, 1);
    expect(repository.replacementReads, [pending, pending]);
    expect(repository.replacementReads, isNot(contains(unchanged)));
    expect(
      await restarted.withPageInput(pending, 0, (file) => file.readAsString()),
      'page',
    );
  });

  test('pending copy scan includes every unfinished journal state', () async {
    final id = await complete('owner', 1);
    for (final state in [
      'queued',
      'downloading',
      'committing',
      'committed',
      'completed',
    ]) {
      await db.customStatement(
        '''
        INSERT INTO content_page_replacement
          (replacement_id,copy_id,ordinal,queue_order,state,old_path,new_path,
           temp_path,retained_path,created_at)
        VALUES (?,?,0,0,?,'old','new','temp','retained','now')
      ''',
        [state, id, state],
      );
      expect(
        await repository.pendingPageReplacementCopyIds(),
        state == 'completed' ? isEmpty : {id},
      );
      await db.customStatement('DELETE FROM content_page_replacement');
    }
  });

  test(
    'automatic restore skips only roots written during this startup',
    () async {
      final known = await complete('known', 1);
      final unknown = await complete('unknown', 2);
      await db.customStatement('DELETE FROM content_page WHERE copy_id = ?', [
        unknown,
      ]);
      await db.customStatement('DELETE FROM content_copy WHERE copy_id = ?', [
        unknown,
      ]);
      downloadSetting.restoreTasksAutomatically.value = true;
      final restarted = _StartupService(repository: repository);
      await restarted.doInitBean();
      expect(restarted.writes['${home.path}/known'], 1);
      expect(await restarted.completedInput(known), isNotNull);
      expect(await restarted.completedInput(unknown), isNotNull);
      expect(await restarted.restoreContentDirectories(), 0);
      expect(restarted.writes['${home.path}/known'], 2);
    },
  );

  test(
    'failed startup projection remains eligible for automatic retry',
    () async {
      final id = await complete('owner', 1);
      downloadSetting.restoreTasksAutomatically.value = true;
      final restarted = _StartupService(repository: repository)
        ..failNextWrite = true;
      await restarted.doInitBean();
      expect(restarted.writes['${home.path}/owner'], 2);
      expect(await restarted.completedInput(id), isNotNull);
      expect(restarted.readProjection('${home.path}/owner').copyId, id);
    },
  );

  test(
    'public rebuild result still describes completeness after write failure',
    () async {
      final id = await complete('owner', 1);
      final restarted = _StartupService(repository: repository)
        ..failNextWrite = true;
      expect(await restarted.rebuildProjection(id), isTrue);
      await restarted.flushProjection('${home.path}/owner');
    },
  );
}
