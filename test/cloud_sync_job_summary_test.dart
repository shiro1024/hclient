import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/service/content_sync/content_repository.dart';
import 'package:jhentai/src/service/gallery_sync/gallery_sync_service.dart';
import 'package:jhentai/src/setting/webdav_setting.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDb db;
  late ContentRepository repository;
  late GallerySyncService service;
  late WebDavSetting previousSetting;
  late String namespace;

  setUp(() {
    previousSetting = webDavSetting;
    webDavSetting = WebDavSetting()
      ..address.value = 'https://example.invalid/sync';
    namespace = webDavSetting.connection.namespace;
    db = AppDb.testing(NativeDatabase.memory());
    repository = ContentRepository(db);
    service = GallerySyncService(repository: repository);
  });
  tearDown(() async {
    service.dispose();
    webDavSetting = previousSetting;
    await db.close();
  });

  test('hundreds of payloads project only current unfinished job facts and preserve revision titles', () async {
    final pages = [
      for (var ordinal = 0; ordinal < 64; ordinal++)
        {
          'ordinal': ordinal,
          'relativePath': 'page-$ordinal.jpg',
          'rawHash': List.filled(64, 'a').join(),
          'rawLength': 100000,
          'mime': 'image/jpeg',
          'width': 1200,
          'height': 1800,
        },
    ];
    await db.transaction(() async {
      for (var index = 0; index < 405; index++) {
        final work = await repository.createWorkItem(
          workItemId: 'payload-${index.toString().padLeft(3, '0')}',
          kind: 'content',
          targetNamespace: namespace,
          inputJson: jsonEncode({
            'title': 'Payload gallery $index',
            'pages': pages,
            'unused': List.filled(2048, 'x').join(),
          }),
          finishAction: index % 5 == 0 ? 'release' : 'handoff',
        );
        await db.customStatement(
          'UPDATE content_work_item SET artifacts_json=?, state=? WHERE work_item_id=?',
          [
            jsonEncode({
              '_completedOrdinals': [0, 3, 12],
              if (index % 3 == 0)
                '_error': {'kind': 'authentication', 'statusCode': 403},
              'unused': List.filled(4096, 'y').join(),
            }),
            index % 3 == 0 ? 'failed' : 'queued',
            work.workItemId,
          ],
        );
      }
      await db.customStatement(
        'INSERT INTO content_manifest (target_namespace,manifest_id,gid,representation,title,gallery_url,portable_json,imported_at) VALUES (?,?,?,?,?,?,?,?)',
        [
          namespace,
          'base',
          1,
          'original',
          'Revision base title',
          'https://example.invalid/gallery',
          '{}',
          'now',
        ],
      );
      await repository.createWorkItem(
        workItemId: 'revision',
        kind: 'revision',
        targetNamespace: namespace,
        inputManifestId: 'base',
        inputJson: jsonEncode({
          'manifestId': 'base',
          'title': 'Not the revision title',
          'pages': pages,
        }),
      );
      await repository.createWorkItem(
        workItemId: 'waiting',
        kind: 'content',
        targetNamespace: namespace,
        inputJson: '{}',
      );
      for (final state in ['completed', 'cancelled']) {
        final work = await repository.createWorkItem(
          kind: 'content',
          targetNamespace: namespace,
          inputJson: 'not-json',
        );
        await repository.updateWorkItemState(work.workItemId, state);
      }
      await repository.createWorkItem(
        workItemId: 'restore',
        kind: 'restore',
        targetNamespace: namespace,
        inputManifestId: 'base',
        inputJson: 'not-json',
      );
      await repository.createWorkItem(
        kind: 'content',
        targetNamespace: 'other-namespace',
        inputJson: 'not-json',
      );
    });
    final jobs = await service.listSyncJobs();
    expect(jobs, hasLength(408));
    final restore = jobs.singleWhere((job) => job.workItemId == 'restore');
    expect(restore.kind, 'restore');
    expect(restore.title, 'Revision base title');
    final payloads = jobs
        .where((job) => job.workItemId.startsWith('payload-'))
        .toList();
    expect(payloads, hasLength(405));
    for (final job in payloads) {
      final index = int.parse(job.workItemId.substring('payload-'.length));
      expect(job.title, 'Payload gallery $index');
      expect(job.totalPages, 64);
      expect(job.completedPages, 3);
      expect(job.state, index % 3 == 0 ? 'failed' : 'queued');
      expect(job.error?.statusCode, index % 3 == 0 ? 403 : null);
    }
    final revision = jobs.singleWhere((job) => job.workItemId == 'revision');
    expect(revision.title, 'Revision base title');
    expect(revision.totalPages, 0);
    expect(revision.completedPages, 0);
    final waiting = jobs.singleWhere((job) => job.workItemId == 'waiting');
    expect(waiting.title, 'cloudWaitingInput');
    expect(waiting.totalPages, 0);
    final release = await service.listSyncJobs(finishAction: 'release');
    expect(release, hasLength(81));
    expect(release.every((job) => job.finishAction == 'release'), isTrue);
  });

  test('finish-action filtering precedes payload projection and ignores unrelated malformed input', () async {
    await repository.createWorkItem(
      kind: 'content',
      targetNamespace: namespace,
      finishAction: 'handoff',
      inputJson: 'not-json',
    );
    await repository.createWorkItem(
      workItemId: 'release',
      kind: 'content',
      targetNamespace: namespace,
      finishAction: 'release',
      inputJson: jsonEncode({'title': 'Release only', 'pages': []}),
    );
    final jobs = await service.listSyncJobs(finishAction: 'release');
    expect(jobs.single.workItemId, 'release');
    expect(jobs.single.title, 'Release only');
  });
}
