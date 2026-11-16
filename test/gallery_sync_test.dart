import 'package:jhentai/src/service/screen_awake_service.dart';

import 'dart:async';
import 'dart:collection';

import 'package:dio/dio.dart';
import 'package:jhentai/src/model/gallery_detail.dart';
import 'package:jhentai/src/model/gallery_image.dart';
import 'package:jhentai/src/model/gallery_url.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/utils/eh_spider_parser.dart';

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show AppLifecycleState;

import 'package:drift/drift.dart'
    show ApplyInterceptor, QueryExecutor, QueryInterceptor, Variable;
import 'package:drift/native.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/service/content_codec.dart';
import 'package:jhentai/src/service/content_sync/content_repository.dart';
import 'package:jhentai/src/service/content_sync/portable_manifest.dart';
import 'package:jhentai/src/service/gallery_download/gallery_download_service.dart';
import 'package:jhentai/src/service/gallery_sync/gallery_sync_service.dart';
import 'package:jhentai/src/service/local_content_service.dart';
import 'package:jhentai/src/service/log.dart';
import 'package:jhentai/src/service/path_service.dart';
import 'package:jhentai/src/service/webdav/webdav_client.dart';
import 'package:jhentai/src/service/webdav/webdav_error_text.dart';
import 'package:jhentai/src/setting/download_setting.dart';
import 'package:jhentai/src/setting/webdav_setting.dart';

import 'support/test_log_service.dart';

void main() {
  setUp(() {
    log = TestLogService();
  });

  test('discovery refills a free partition slot while another partition is held', () async {
    await _withAutomaticFixture((home, server, repo, service) async {
      const root = '/v1/dav/sync/hclient-v1/manifests/';
      final partitions = [
        for (var i = 0; i < 10; i++) i.toRadixString(16).padLeft(2, '0'),
      ];
      server.directories.add(root);
      for (final partition in partitions) {
        server.directories.add('$root$partition/');
        server.partitionListGates[partition] = Completer<void>();
        server.partitionListStarted[partition] = Completer<void>();
      }
      final scan = service.refresh();
      try {
        await Future.wait(
          partitions
              .take(8)
              .map(
                (partition) => server.partitionListStarted[partition]!.future,
              ),
        ).timeout(const Duration(seconds: 3));
        expect(server.partitionListStarted['08']!.isCompleted, isFalse);
        server.partitionListGates['01']!.complete();
        await server.partitionListStarted['08']!.future.timeout(
          const Duration(seconds: 3),
        );
        expect(server.partitionListGates['00']!.isCompleted, isFalse);
        expect(server.partitionListStarted['09']!.isCompleted, isFalse);
        // Only one slot was freed: the ninth request must occupy it before the
        // held first partition can finish, without admitting a tenth request.
        expect(service.scanning, isTrue);
      } finally {
        for (final gate in server.partitionListGates.values) {
          if (!gate.isCompleted) {
            gate.complete();
          }
        }
        await scan.timeout(const Duration(seconds: 3));
      }
      expect(service.lastError, isNull);
      final completed = await repo.db
          .customSelect(
            "SELECT partition FROM content_remote_partition WHERE scan_state = 'complete'",
          )
          .get();
      expect(
        completed.map((row) => row.read<String>('partition')),
        unorderedEquals([...partitions, '__root__']),
      );
    }, initiallyForeground: false);
  });

  test('a failed partition stops new discovery work and drains dispatched partitions before finishing', () async {
    await _withAutomaticFixture((home, server, repo, service) async {
      const root = '/v1/dav/sync/hclient-v1/manifests/';
      final partitions = [
        for (var i = 0; i < 12; i++) i.toRadixString(16).padLeft(2, '0'),
      ];
      server.directories.add(root);
      for (final partition in partitions) {
        server.directories.add('$root$partition/');
        server.partitionListGates[partition] = Completer<void>();
        server.partitionListStarted[partition] = Completer<void>();
        server.partitionListFinished[partition] = Completer<void>();
      }
      server.partitionListFailures['00'] = 503;
      var finished = false;
      final scan = service.refresh().whenComplete(() => finished = true);
      try {
        await Future.wait(
          partitions
              .take(8)
              .map(
                (partition) => server.partitionListStarted[partition]!.future,
              ),
        ).timeout(const Duration(seconds: 3));
        server.partitionListGates['00']!.complete();
        await server.partitionListFinished['00']!.future.timeout(
          const Duration(seconds: 3),
        );
        // Give the localhost response back to the client while the other seven
        // requests remain held. No timer controls the successful requests.
        await pumpEventQueue();
        expect(finished, isFalse);
        expect(service.scanning, isTrue);
        expect(service.lastError, isNull);
      } finally {
        for (final gate in server.partitionListGates.values) {
          if (!gate.isCompleted) {
            gate.complete();
          }
        }
        await scan.timeout(const Duration(seconds: 3));
      }
      expect(service.lastError, contains('HTTP 503'));
      expect(service.scanning, isFalse);
      expect(
        server.partitionListStarted.entries
            .where((entry) => entry.value.isCompleted)
            .map((entry) => entry.key),
        unorderedEquals(partitions.take(8)),
      );
      final rootState = await repo.db
          .customSelect(
            "SELECT scan_state FROM content_remote_partition WHERE partition = '__root__'",
          )
          .get();
      expect(rootState, isEmpty);
      final completed = await repo.db
          .customSelect(
            "SELECT partition FROM content_remote_partition WHERE scan_state = 'complete'",
          )
          .get();
      expect(
        completed.map((row) => row.read<String>('partition')),
        unorderedEquals(partitions.skip(1).take(7)),
      );
    }, initiallyForeground: false);
  });

  test('catalog pagination reads local copies only for visible families and retains all matching versions', () async {
    final reads = _CatalogLocalReadInterceptor();
    await _withAutomaticFixture(
      (home, server, repo, service) async {
        final copies = <int, String>{};
        for (final gid in [9101, 9102, 9200]) {
          final copy = await _fixtureCopy(home, gid, 'gradient.jpg');
          copies[gid] = copy;
          final local = (await repo.listPages(copy)).single;
          final hash = gid == 9102 ? 'a' * 64 : local.rawHash!;
          final manifest = PortableManifest(
            gid: gid,
            representation: 'original',
            galleryUrl: 'https://e-hentai.org/g/$gid/0123456789/',
            title: 'Gallery $gid',
            tags: const [],
            lineage: gid == 9102
                ? [const ManifestLineage(9101, 9102, 'upgrade')]
                : const [],
            pages: [
              PortablePage(
                rawHash: hash,
                rawLength: local.rawLength!,
                objectHash: hash,
                storedLength: local.rawLength!,
                codecProfile: 'raw',
                mime: local.mime!,
              ),
            ],
          );
          final artifact = PortableManifestCodec.write(
            File('${home.path}/catalog-$gid.sqlite'),
            manifest,
          );
          final namespace = webDavSetting.connection.namespace;
          await repo.importManifest(namespace, artifact);
          await repo.recordRemoteResource(
            targetNamespace: namespace,
            href:
                'manifests/${artifact.manifestId.substring(0, 2)}/${artifact.manifestId}.sqlite',
            kind: 'manifest',
            objectHash: artifact.manifestId,
            partition: artifact.manifestId.substring(0, 2),
          );
        }
        reads.clear();
        final first = await service.listCloudEntries(limit: 1);
        expect(first.map((entry) => entry.gid), [9200]);
        expect(first.single.localCopyId, copies[9200]);
        expect(first.single.localState, CloudLocalState.available);
        expect(reads.gids, [9200]);
        expect(reads.copyIds, [copies[9200]]);
        reads.clear();
        final next = await service.listCloudEntries(offset: 1, limit: 1);
        expect(next.map((entry) => entry.gid), [9102, 9101]);
        expect(next.map((entry) => entry.familyKey).toSet(), hasLength(1));
        expect(next.first.preferred, isTrue);
        expect(next.first.localCopyId, isNull);
        expect(next.first.localState, CloudLocalState.none);
        expect(next.last.localCopyId, copies[9101]);
        expect(next.last.localState, CloudLocalState.available);
        expect(reads.gids, [9102, 9101]);
        expect(reads.copyIds, [copies[9102], copies[9101]]);
        reads.clear();
        expect(
          await service.listCloudEntries(search: 'no matching gallery'),
          isEmpty,
        );
        expect(reads.gids, isEmpty);
        expect(reads.copyIds, isEmpty);
      },
      initiallyForeground: false,
      queryInterceptor: reads,
    );
  });

  for (final website in [true, false]) {
    test(
      'committed ${website ? 'website facts' : 'user title and lineage'} survive later owner group auto revision',
      () async {
        final originalRequest = ehRequest;
        try {
          ehRequest = _WebsiteMetadataRequest();
          await _withAutomaticFixture((home, server, repo, service) async {
            final copy = await _fixtureCopy(
              home,
              8090,
              'gradient.jpg',
              lineage: [
                const ManifestLineage(7000, 8090, 'source_parent'),
                const ManifestLineage(7990, 8090, 'upgrade'),
                const ManifestLineage(6000, 6001, 'source_parent'),
              ],
            );
            await localContentService.updateMetadata(
              copy,
              providerMetadata: {'category': 'Old category'},
              collections: ['Personal group'],
              tags: [const PortableTag('artist', 'old')],
            );
            final upload = await service.requestUpload(copy);
            await _workFinished(service, repo, upload);
            final base = (await service.listCloudEntries()).single;
            final revision = website
                ? await service.requestWebsiteMetadataRevision(base)
                : await service.requestMetadataRevision(
                    base.manifestId,
                    title: 'Personal edited title',
                    lineageRemoved: [
                      const ManifestLineage(7000, 8090, 'source_parent'),
                    ],
                    lineageAdded: [
                      const ManifestLineage(7002, 8090, 'source_parent'),
                    ],
                  );
            await _workFinished(service, repo, revision);
            final owner = (await localContentService.completedInput(copy))!;
            expect(owner.collections, ['Personal group']);
            expect(
              owner.title,
              website ? 'Gallery 8090' : 'Personal edited title',
            );
            if (website) {
              expect(owner.providerMetadata['category'], 'Manga');
              expect(owner.tags, isEmpty);
            } else {
              expect(owner.providerMetadata['category'], 'Old category');
              expect(owner.tags.single.name, 'old');
            }
            final before = (await service.listCloudEntries()).single.manifest;
            final puts = server.pagePuts;
            await service.setAutoSync(true);
            await _waitForHandoff(repo, copy);
            await localContentService.updateMetadata(
              copy,
              collections: ['Later group'],
            );
            await _waitUntil(
              () async => (await service.listCloudEntries()).single.collections
                  .contains('Later group'),
            );
            final after = (await service.listCloudEntries()).single.manifest;
            expect(after.title, before.title);
            expect(after.providerMetadata, before.providerMetadata);
            expect(
              after.tags.map((tag) => [tag.namespace, tag.name]),
              before.tags.map((tag) => [tag.namespace, tag.name]),
            );
            expect(
              after.lineage.map(
                (edge) => [edge.fromGid, edge.toGid, edge.kind],
              ),
              before.lineage.map(
                (edge) => [edge.fromGid, edge.toGid, edge.kind],
              ),
            );
            expect(server.pagePuts, puts);
          });
        } finally {
          ehRequest = originalRequest;
        }
      },
    );
  }

  test('cloud title edits leave an unassociated copy with identical pages unchanged', () async {
    await _withAutomaticFixture((home, server, repo, service) async {
      final published = await _fixtureCopy(home, 8092, 'gradient.jpg');
      await _workFinished(
        service,
        repo,
        await service.requestUpload(published),
      );
      final root = Directory('${home.path}/independent');
      await root.create();
      await File('native/tests/fixtures/gradient.jpg')
          .copy('${root.path}/1.jpg');
      final independent = await localContentService.ensureCopy(
        gid: 8092,
        representation: 'original',
        rootPath: root.path,
      );
      await localContentService.recordPage(
        copyId: independent,
        ordinal: 0,
        relativePath: '1.jpg',
        mime: 'image/jpeg',
      );
      await localContentService.completeCopy(
        independent,
        galleryUrl: 'https://e-hentai.org/g/8092/0123456789/',
        title: 'Independent title',
        expectedPages: 1,
        collections: ['Independent group'],
      );
      final entry = (await service.listCloudEntries()).single;
      await _workFinished(
        service,
        repo,
        await service.requestMetadataRevision(
          entry.manifestId,
          title: 'Cloud title',
        ),
      );
      expect(
        (await localContentService.completedInput(published))!.title,
        'Cloud title',
      );
      final untouched = (await localContentService.completedInput(
        independent,
      ))!;
      expect(untouched.title, 'Independent title');
      expect(untouched.collections, ['Independent group']);
    });
  });

  for (final overlap in [false, true]) {
    test(
      'startup resumed and ready scan automatic copies once overlap=$overlap',
      () async {
        final scans = _AutomaticScanInterceptor(holdFirstScan: overlap);
        await _withAutomaticFixture(
          (home, server, repo, service) async {
            await repo.commitPartitionScan(
              targetNamespace: webDavSetting.connection.namespace,
              partition: '__root__',
              scanState: 'complete',
              deletedHrefs: const [],
            );
            webDavSetting.autoSync.value = true;
            final resumed = service.handleAppLifecycleState(
              AppLifecycleState.resumed,
            );
            if (overlap) {
              await scans.firstScanEntered.future.timeout(
                const Duration(seconds: 3),
              );
              try {
                await service.doAfterBeanReady().timeout(
                  const Duration(seconds: 3),
                );
                expect(scans.fullScans, 1);
              } finally {
                scans.releaseFirstScan.complete();
              }
            } else {
              await resumed;
              await service.doAfterBeanReady();
            }
            await resumed;
            expect(scans.fullScans, 1);
          },
          initiallyForeground: false,
          queryInterceptor: scans,
        );
      },
    );
  }

  test(
    'background startup ready defers its only automatic scan until resumed',
    () async {
      final scans = _AutomaticScanInterceptor();
      await _withAutomaticFixture(
        (home, server, repo, service) async {
          await repo.commitPartitionScan(
            targetNamespace: webDavSetting.connection.namespace,
            partition: '__root__',
            scanState: 'complete',
            deletedHrefs: const [],
          );
          await service.handleAppLifecycleState(AppLifecycleState.hidden);
          webDavSetting.autoSync.value = true;
          await service.doAfterBeanReady();
          expect(scans.fullScans, 0);
          await service.handleAppLifecycleState(AppLifecycleState.resumed);
          expect(scans.fullScans, 1);
        },
        initiallyForeground: false,
        queryInterceptor: scans,
      );
    },
  );

  test(
    'automatic scheduling waits for an observed foreground lifecycle',
    () async {
      await _withAutomaticFixture((home, server, repo, service) async {
        final copy = await _fixtureCopy(home, 8093, 'gradient.jpg');
        await service.setAutoSync(true);
        await service.doAfterBeanReady();
        expect(
          await repo.listWorkItems(copyId: copy, includeFinished: true),
          isEmpty,
        );
        await service.handleAppLifecycleState(AppLifecycleState.resumed);
        await _waitForHandoff(repo, copy);
      }, initiallyForeground: false);
    },
  );

  for (final action in ['pause', 'cancel']) {
    for (final phase in ['preparing', 'completing']) {
      test('restore $action during $phase preserves user intent', () async {
        late _RestoreBarrierRepository barrier;
        await _withAutomaticFixture((home, server, repo, service) async {
          final copy = await _fixtureCopy(home, 8191, 'gradient.jpg');
          final upload = await service.requestUpload(copy);
          await _workFinished(service, repo, upload);
          final entry = (await service.listCloudEntries()).single;
          await localContentService.retireCopy(copy);
          final completing = Completer<void>();
          final releaseCompletion = Completer<void>();
          final original = localContentService.onCompleted;
          if (phase == 'preparing') {
            barrier.hold = true;
          } else {
            localContentService.onCompleted = (input) async {
              if (input.copyId != copy) {
                if (!completing.isCompleted) completing.complete();
                await releaseCompletion.future;
              }
              await original?.call(input);
            };
          }
          final restoring = service.restore(entry.manifestId);
          if (phase == 'preparing') {
            await barrier.entered.future.timeout(const Duration(seconds: 3));
          } else {
            await completing.future.timeout(const Duration(seconds: 3));
          }
          final work = (await repo.listWorkItems(kind: 'restore')).single;
          final stopping = action == 'pause'
              ? service.pause(work.workItemId)
              : service.cancel(work.workItemId);
          if (phase == 'preparing') barrier.release.complete();
          if (phase == 'completing') releaseCompletion.complete();
          await stopping;
          await restoring;
          expect(
            (await repo.getWorkItem(work.workItemId))!.state,
            action == 'pause' ? 'paused' : 'cancelled',
          );
          if (phase == 'completing')
            expect(await _libraryNamespace(repo, work.copyId!), isNull);
          localContentService.onCompleted = original;
        }, repositoryFactory: (db) => barrier = _RestoreBarrierRepository(db));
      });
    }
  }

  test('automatic completion arriving during the drain tail starts without another resume', () async {
    late _AutomaticTailRepository barrier;
    await _withAutomaticFixture((home, server, repo, service) async {
      barrier.holdTail = true;
      final enabling = service.setAutoSync(true);
      await barrier.tailEntered.future;
      final copy = await _fixtureCopy(home, 8091, 'gradient.jpg');
      barrier.releaseTail.complete();
      await enabling;
      await _waitForHandoff(repo, copy);
    }, repositoryFactory: (db) => barrier = _AutomaticTailRepository(db));
  });

  test('foreground leaves published kept resident representations untouched', () async {
    await _withAutomaticFixture((home, server, repo, service) async {
      await service.handleAppLifecycleState(AppLifecycleState.hidden);
      Future<void> publish(
        String copy, {
        List<String> supersedes = const [],
        String? title,
      }) async {
        final content = (await localContentService.completedInput(copy))!;
        final manifest = PortableManifest(
          gid: content.gid,
          representation: content.representation,
          galleryUrl: content.galleryUrl,
          title: title ?? content.title,
          tags: content.tags,
          supersedes: supersedes,
          pages: [
            for (final page in content.pages)
              PortablePage(
                rawHash: page.rawHash,
                rawLength: page.rawLength,
                objectHash: page.rawHash,
                storedLength: page.rawLength,
                codecProfile: 'raw',
                mime: page.mime,
              ),
          ],
        );
        final artifact = PortableManifestCodec.write(
          File('${home.path}/${content.gid}-${title ?? 'old'}.sqlite'),
          manifest,
        );
        await repo.importManifest(webDavSetting.connection.namespace, artifact);
        await repo.recordRemoteResource(
          targetNamespace: webDavSetting.connection.namespace,
          href:
              'manifests/${artifact.manifestId.substring(0, 2)}/${artifact.manifestId}.sqlite',
          kind: 'manifest',
          objectHash: artifact.manifestId,
        );
      }

      final jpeg = await _fixtureCopy(home, 8071, 'gradient.jpg');
      final jpegRoot = await localContentService.rootPath(jpeg);
      await File('native/tests/fixtures/gradient.png')
          .copy('$jpegRoot/second.png');
      await localContentService.recordPage(
        copyId: jpeg,
        ordinal: 1,
        relativePath: 'second.png',
        mime: 'image/png',
      );
      await localContentService.completeCopy(
        jpeg,
        galleryUrl: 'https://e-hentai.org/g/8071/0123456789/',
        title: 'Gallery 8071',
        expectedPages: 2,
      );
      final fallback = await _fixtureCopy(home, 8072, 'passthrough.webp');
      await publish(jpeg);
      await publish(fallback);
      final replacement = await localContentService.enqueuePageReplacement(
        copyId: jpeg,
        ordinal: 1,
        newRelativePath: 'new.webp',
      );
      final changed = await File('native/tests/fixtures/passthrough.webp')
          .readAsBytes();
      await File(replacement.tempPath).writeAsBytes(changed);
      await localContentService.finishDownloadedReplacement(
        replacement.replacementId,
        rawHash: sha256.convert(changed).toString(),
        rawLength: changed.length,
        mime: 'image/webp',
      );
      final old =
          (await repo.db
                  .customSelect(
                    'SELECT manifest_id FROM content_manifest WHERE gid = 8071',
                  )
                  .getSingle())
              .read<String>('manifest_id');
      // The matching raw pages remain a valid published history even after a
      // newer immutable head supersedes their manifest.
      final successor = PortableManifest(
        gid: 8071,
        representation: 'original',
        galleryUrl: 'https://e-hentai.org/g/8071/0123456789/',
        title: 'Successor',
        tags: const [],
        supersedes: [old],
        pages: [
          PortablePage(
            rawHash: 'f' * 64,
            rawLength: 1,
            objectHash: 'f' * 64,
            storedLength: 1,
            codecProfile: 'raw',
            mime: 'image/jpeg',
          ),
        ],
      );
      final artifact = PortableManifestCodec.write(
        File('${home.path}/successor.sqlite'),
        successor,
      );
      await repo.importManifest(webDavSetting.connection.namespace, artifact);
      await repo.recordRemoteResource(
        targetNamespace: webDavSetting.connection.namespace,
        href: 'manifests/${artifact.manifestId}.sqlite',
        kind: 'manifest',
        objectHash: artifact.manifestId,
      );
      await service.handleAppLifecycleState(AppLifecycleState.resumed);
      await service.handleAppLifecycleState(AppLifecycleState.hidden);
      expect((await repo.getPage(jpeg, 0)).codecProfile, null);
      expect((await repo.getPage(fallback, 0)).codecProfile, null);
      expect((await repo.getPage(jpeg, 1)).codecProfile, null);
      expect(await _libraryNamespace(repo, jpeg), null);
      expect(
        await localContentService.readPageForDisplay(jpeg, 0),
        await File('native/tests/fixtures/gradient.jpg').readAsBytes(),
      );
      expect(
        server.requests.where((request) => request.method == 'PUT'),
        isEmpty,
      );
      final manifestCount =
          (await repo.db
                  .customSelect('SELECT COUNT(*) AS n FROM content_manifest')
                  .getSingle())
              .read<int>('n');
      await service.handleAppLifecycleState(AppLifecycleState.resumed);
      await service.handleAppLifecycleState(AppLifecycleState.hidden);
      expect(
        (await repo.db
                .customSelect('SELECT COUNT(*) AS n FROM content_manifest')
                .getSingle())
            .read<int>('n'),
        manifestCount,
      );
    });
  });

  for (final changedMetadata in [false, true]) {
    test(
      'matching raw head selects local PNG once for repeated ordinals before ${changedMetadata ? 'metadata revision' : 'equivalent handoff'}',
      () async {
        final counter = _EncodingCounter();
        await _withAutomaticFixture((home, server, repo, service) async {
          const gid = 8073;
          final root = await Directory('${home.path}/matching-head').create();
          final bytes = await File('native/tests/fixtures/gradient.png')
              .readAsBytes();
          final rawHash = sha256.convert(bytes).toString();
          final copy = await localContentService.ensureCopy(
            gid: gid,
            representation: 'original',
            rootPath: root.path,
          );
          for (var ordinal = 0; ordinal < 2; ordinal++) {
            await File('${root.path}/$ordinal.png').writeAsBytes(bytes);
            await localContentService.recordPage(
              copyId: copy,
              ordinal: ordinal,
              relativePath: '$ordinal.png',
              mime: 'image/png',
              width: 512,
              height: 512,
              sourcePageUrl:
                  'https://e-hentai.org/s/page$ordinal/$gid-$ordinal',
            );
          }
          await localContentService.completeCopy(
            copy,
            galleryUrl: 'https://e-hentai.org/g/$gid/0123456789/',
            title: changedMetadata ? 'Changed owner title' : 'Remote title',
            expectedPages: 2,
          );
          final manifest = PortableManifest(
            gid: gid,
            representation: 'original',
            galleryUrl: 'https://e-hentai.org/g/$gid/0123456789/',
            title: 'Remote title',
            category: 'Inherited category',
            tags: const [],
            pages: [
              for (var ordinal = 0; ordinal < 2; ordinal++)
                PortablePage(
                  rawHash: rawHash,
                  rawLength: bytes.length,
                  objectHash: rawHash,
                  storedLength: bytes.length,
                  codecProfile: 'raw',
                  mime: 'image/png',
                  width: 512,
                  height: 512,
                  sourcePageUrl:
                      'https://e-hentai.org/s/page$ordinal/$gid-$ordinal',
                ),
            ],
          );
          final artifact = PortableManifestCodec.write(
            File('${home.path}/raw-head.sqlite'),
            manifest,
          );
          final namespace = webDavSetting.connection.namespace;
          await repo.importManifest(namespace, artifact);
          final href =
              'manifests/${artifact.manifestId.substring(0, 2)}/${artifact.manifestId}.sqlite';
          await repo.recordRemoteResource(
            targetNamespace: namespace,
            href: href,
            kind: 'manifest',
            objectHash: artifact.manifestId,
          );
          server.files['/v1/dav/sync/hclient-v1/$href'] = await artifact.file
              .readAsBytes();
          server.files['/v1/dav/sync/hclient-v1/objects/${rawHash.substring(0, 2)}/$rawHash'] =
              bytes;
          if (changedMetadata) server.putFailureStatus = 503;
          await service.setAutoSync(true);
          if (changedMetadata) {
            final failed = await _waitForCopyState(repo, copy, 'failed');
            expect(counter.encodes, 1);
            expect(
              (await repo.listPages(copy)).every(
                (page) => page.codecProfile == ContentCodec.encodedProfile,
              ),
              isTrue,
            );
            expect(
              (jsonDecode(failed.artifactsJson) as Map)['_completedOrdinals'],
              [0, 1],
            );
            expect(
              (await localContentService.readPageForExport(copy, 1)).bytes,
              bytes,
            );
            server.putFailureStatus = null;
            await service.resume(failed.workItemId);
          }
          await _waitForHandoff(repo, copy);
          expect(counter.encodes, 1);
          final selected = await repo.listPages(copy);
          expect(selected.map((page) => page.codecProfile).toSet(), {
            ContentCodec.encodedProfile,
          });
          expect(selected.map((page) => page.objectHash).toSet(), hasLength(1));
          expect(selected.first.objectHash, isNot(rawHash));
          for (var ordinal = 0; ordinal < 2; ordinal++) {
            expect(
              (await localContentService.readPageForExport(
                copy,
                ordinal,
              )).bytes,
              bytes,
            );
            final display = await localContentService.readPageForDisplay(
              copy,
              ordinal,
            );
            expect(String.fromCharCodes(display.take(4)), 'RIFF');
          }
          final head = (await service.listCloudEntries()).single;
          expect(head.manifest.category, 'Inherited category');
          expect(head.manifest.pages.map((page) => page.codecProfile).toSet(), {
            'raw',
          });
          expect(head.manifestId == artifact.manifestId, !changedMetadata);
          if (changedMetadata)
            expect(head.manifest.supersedes, [artifact.manifestId]);
          expect(
            server.requests.where(
              (request) =>
                  request.method == 'PUT' && request.path.endsWith('/$rawHash'),
            ),
            isEmpty,
          );
          expect(
            server.requests.where(
              (request) =>
                  request.method == 'PUT' &&
                  request.path.endsWith('/${selected.first.objectHash}'),
            ),
            isEmpty,
          );
          // A metadata-only update on the admitted owner does not encode again.
          await localContentService.updateMetadata(
            copy,
            collections: ['Later group'],
          );
          await _waitUntil(
            () async => (await service.listCloudEntries()).single.collections
                .contains('Later group'),
          );
          await service.handleAppLifecycleState(AppLifecycleState.hidden);
          await service.handleAppLifecycleState(AppLifecycleState.resumed);
          expect(counter.encodes, 1);
          expect(
            (await repo.listPages(copy)).map((page) => page.objectHash),
            selected.map((page) => page.objectHash),
          );
        }, codec: counter);
      },
    );
  }

  for (final changedMetadata in [false, true]) {
    test(
      'handoff owner page replacement matching a head selects only new input before ${changedMetadata ? 'metadata revision' : 'equivalent reuse'}',
      () async {
        final counter = _EncodingCounter();
        await _withAutomaticFixture((home, server, repo, service) async {
          const gid = 8075;
          final copy = await _fixtureCopy(home, gid, 'gradient.jpg');
          final root = await localContentService.rootPath(copy);
          await File('native/tests/fixtures/passthrough.webp')
              .copy('$root/second.webp');
          await localContentService.recordPage(
            copyId: copy,
            ordinal: 1,
            relativePath: 'second.webp',
            mime: 'image/webp',
          );
          await localContentService.completeCopy(
            copy,
            galleryUrl: 'https://e-hentai.org/g/$gid/0123456789/',
            title: 'Owner title',
            expectedPages: 2,
          );
          await service.setAutoSync(true);
          await _waitForHandoff(repo, copy);
          await service.setAutoSync(false);
          expect(counter.encodes, 1);
          final selectedFirst = await repo.getPage(copy, 0);
          expect(selectedFirst.codecProfile, ContentCodec.encodedProfile);
          final previous = (await service.listCloudEntries()).single;
          final bytes = await File('native/tests/fixtures/gradient.png')
              .readAsBytes();
          final rawHash = sha256.convert(bytes).toString();
          final matching = PortableManifest(
            gid: gid,
            representation: 'original',
            galleryUrl: previous.manifest.galleryUrl,
            title: changedMetadata ? 'Other head title' : 'Owner title',
            tags: previous.manifest.tags,
            collections: previous.manifest.collections,
            lineage: previous.manifest.lineage,
            thumbnail: previous.manifest.thumbnail,
            codecProfiles: previous.manifest.codecProfiles,
            supersedes: [previous.manifestId],
            pages: [
              previous.manifest.pages.first,
              PortablePage(
                rawHash: rawHash,
                rawLength: bytes.length,
                objectHash: rawHash,
                storedLength: bytes.length,
                codecProfile: 'raw',
                mime: 'image/png',
              ),
            ],
          );
          final artifact = PortableManifestCodec.write(
            File('${home.path}/replacement-head.sqlite'),
            matching,
          );
          final namespace = webDavSetting.connection.namespace;
          await repo.importManifest(namespace, artifact);
          final href =
              'manifests/${artifact.manifestId.substring(0, 2)}/${artifact.manifestId}.sqlite';
          await repo.recordRemoteResource(
            targetNamespace: namespace,
            href: href,
            kind: 'manifest',
            objectHash: artifact.manifestId,
          );
          server.files['/v1/dav/sync/hclient-v1/$href'] = await artifact.file
              .readAsBytes();
          server.files['/v1/dav/sync/hclient-v1/objects/${rawHash.substring(0, 2)}/$rawHash'] =
              bytes;
          final replacement = await localContentService.enqueuePageReplacement(
            copyId: copy,
            ordinal: 1,
            newRelativePath: 'replacement.png',
          );
          await File(replacement.tempPath).writeAsBytes(bytes);
          await localContentService.finishDownloadedReplacement(
            replacement.replacementId,
            rawHash: rawHash,
            rawLength: bytes.length,
            mime: 'image/png',
          );
          expect(await _libraryNamespace(repo, copy), namespace);
          expect((await repo.getPage(copy, 1)).codecProfile, isNull);
          final priorWork = (await repo.listWorkItems(
            copyId: copy,
            includeFinished: true,
          )).last;
          final requestStart = server.requests.length;
          await service.setAutoSync(true);
          await _waitUntil(() async {
            final jobs = await repo.listWorkItems(
              copyId: copy,
              includeFinished: true,
            );
            return jobs.last.workItemId != priorWork.workItemId &&
                jobs.last.state == 'completed';
          });
          final selectedNew = await repo.getPage(copy, 1);
          expect(selectedNew.codecProfile, ContentCodec.encodedProfile);
          expect(counter.encodes, 2);
          expect(
            (await repo.getPage(copy, 0)).objectHash,
            selectedFirst.objectHash,
          );
          expect(
            (await localContentService.readPageForExport(copy, 1)).bytes,
            bytes,
          );
          final head = (await service.listCloudEntries()).single;
          expect(head.manifestId == artifact.manifestId, !changedMetadata);
          if (changedMetadata)
            expect(head.manifest.supersedes, [artifact.manifestId]);
          expect(head.manifest.pages.last.codecProfile, 'raw');
          expect(
            server.requests
                .skip(requestStart)
                .where(
                  (request) =>
                      request.method == 'PUT' &&
                      (request.path.endsWith('/$rawHash') ||
                          request.path.endsWith('/${selectedNew.objectHash}') ||
                          request.path.endsWith(
                            '/${selectedFirst.objectHash}',
                          )),
                ),
            isEmpty,
          );
          await localContentService.updateMetadata(
            copy,
            collections: ['After replacement'],
          );
          await _waitUntil(
            () async => (await service.listCloudEntries()).single.collections
                .contains('After replacement'),
          );
          expect(counter.encodes, 2);
          final work = (await repo.listWorkItems(
            copyId: copy,
            includeFinished: true,
          )).last;
          expect(work.kind, 'revision');
          expect(work.state, 'completed');
        }, codec: counter);
      },
    );
  }

  test(
    'raw PNG fallback is selected once across later upload and foreground',
    () async {
      final counter = _EncodingCounter();
      await _withAutomaticFixture((home, server, repo, service) async {
        final copy = await _fixtureCopy(home, 8074, 'minimal.png');
        final bytes = await File('native/tests/fixtures/minimal.png')
            .readAsBytes();
        final first = await service.requestUpload(copy);
        await _workFinished(service, repo, first);
        expect(counter.encodes, 1);
        final selected = await repo.getPage(copy, 0);
        expect(selected.codecProfile, ContentCodec.rawProfile);
        expect(selected.relativePath, 'minimal.png');
        expect(await localContentService.readPageForDisplay(copy, 0), bytes);
        final puts = server.pagePuts;
        final next = await service.requestUpload(copy);
        await _workFinished(service, repo, next);
        await service.handleAppLifecycleState(AppLifecycleState.hidden);
        await service.handleAppLifecycleState(AppLifecycleState.resumed);
        expect(counter.encodes, 1);
        expect(server.pagePuts, puts);
        final work = (await repo.getWorkItem(next))!;
        expect((jsonDecode(work.artifactsJson) as Map)['_completedOrdinals'], [
          0,
        ]);
        expect(
          (jsonDecode(work.artifactsJson) as Map).containsKey('0'),
          isFalse,
        );
      }, codec: counter);
    },
  );

  test('automatic enable uploads stock and later completions and keeps owner-readable bytes', () async {
    await _withAutomaticFixture((home, server, repo, service) async {
      final first = await _fixtureCopy(home, 8001, 'gradient.jpg');
      final before = await File('${home.path}/copy-8001/gradient.jpg')
          .readAsBytes();
      final completed = <String>[];
      service.onHandoffCompleted = completed.add;
      await service.setAutoSync(true);
      await _waitForHandoff(repo, first);
      final second = await _fixtureCopy(home, 8002, 'gradient.png');
      await _waitForHandoff(repo, second);
      expect(await localContentService.readPageForDisplay(first, 0), before);
      expect(
        (await localContentService.completedInput(first))!.rootPath,
        '${home.path}/copy-8001',
      );
      final work = await repo.listWorkItems(includeFinished: true);
      expect(
        work
            .where((item) => item.kind == 'content')
            .every(
              (item) =>
                  item.source == 'automatic' && item.finishAction == 'handoff',
            ),
        isTrue,
      );
      final initialPuts = server.pagePuts;
      await localContentService.updateMetadata(
        first,
        collections: ['Changed group'],
        tags: [const PortableTag('artist', 'changed')],
      );
      await _waitUntil(
        () async => (await service.listCloudEntries())
            .firstWhere((entry) => entry.gid == 8001)
            .collections
            .contains('Changed group'),
      );
      expect(server.pagePuts, initialPuts);
      expect(await localContentService.readPageForDisplay(first, 0), before);
      final jobsBefore = (await repo.listWorkItems(includeFinished: true))
          .length;
      await service.synchronizeAutomatic();
      expect(
        (await repo.listWorkItems(includeFinished: true)).length,
        jobsBefore,
      );
      expect(completed, contains('Gallery 8001'));
    });
  });

  test(
    'metadata changed during manifest MOVE is revised before the owner handoff',
    () async {
      await _withAutomaticFixture((home, server, repo, service) async {
        final copy = await _fixtureCopy(home, 8010, 'gradient.jpg');
        server.holdManifestMove = true;
        await service.setAutoSync(true);
        await server.moveStarted.future.timeout(const Duration(seconds: 10));
        expect(await _libraryNamespace(repo, copy), isNull);
        await localContentService.updateMetadata(
          copy,
          collections: ['Latest'],
          tags: [const PortableTag('artist', 'latest')],
        );
        server.holdManifestMove = false;
        server.moveGate.complete();
        await _waitForHandoff(repo, copy);
        final entry = (await service.listCloudEntries()).single;
        expect(entry.collections, ['Latest']);
        expect(entry.tags.single.name, 'latest');
        final jobs = await repo.listWorkItems(
          copyId: copy,
          includeFinished: true,
        );
        expect(jobs.map((job) => job.kind), ['content', 'revision']);
        expect(jobs.first.finishAction, 'keep');
        expect(jobs.last.finishAction, 'handoff');
        expect(jobs.every((job) => job.state == 'completed'), isTrue);
        expect(server.pagePuts, 2); // One encoded page and one small cover.
      });
    },
  );

  test(
    'foreground resume keeps a suspended automatic PUT awake before it settles',
    () async {
      final previousAwake = screenAwakeService;
      final calls = <bool>[];
      final awake = screenAwakeService = _RecordingAwakeService(
        toggle: (value) async {
          calls.add(value);
        },
      );
      try {
        await awake.handleLifecycle(AppLifecycleState.resumed);
        await _withAutomaticFixture((home, server, repo, service) async {
          final copy = await _fixtureCopy(home, 8098, 'gradient.jpg');
          server.holdObjectPut = true;
          await service.setAutoSync(true);
          await server.putStarted.future.timeout(const Duration(seconds: 10));
          expect(calls.last, isTrue);
          final suspended = Completer<void>();
          awake.onDemand = (owner, requested) {
            if (identical(owner, service) &&
                !requested &&
                !suspended.isCompleted)
              suspended.complete();
          };
          final hiding = service.handleAppLifecycleState(
            AppLifecycleState.hidden,
          );
          await awake.handleLifecycle(AppLifecycleState.hidden);
          await suspended.future;
          expect(calls.last, isFalse);
          var resumed = false;
          final resuming = service
              .handleAppLifecycleState(AppLifecycleState.resumed)
              .then((_) {
                resumed = true;
              });
          await awake.handleLifecycle(AppLifecycleState.resumed);
          expect(resumed, isFalse); // The HTTP response is still held below.
          expect(calls.last, isTrue);
          final work = (await repo.listWorkItems(copyId: copy)).single;
          final pausing = service.pause(work.workItemId);
          await awake.setRequested(Object(), false);
          expect(calls.last, isFalse);
          server.holdObjectPut = false;
          server.putGate.complete();
          await Future.wait([hiding, resuming, pausing]);
          expect((await repo.getWorkItem(work.workItemId))!.state, 'paused');
        });
      } finally {
        screenAwakeService = previousAwake;
      }
    },
  );

  test('an empty automatic scan does not request screen awake', () async {
    final previousAwake = screenAwakeService;
    final calls = <bool>[];
    final awake = screenAwakeService = ScreenAwakeService(
      toggle: (value) async {
        calls.add(value);
      },
    );
    try {
      await awake.handleLifecycle(AppLifecycleState.resumed);
      await _withAutomaticFixture((home, server, repo, service) async {
        await service.setAutoSync(true);
        await service.handleAppLifecycleState(AppLifecycleState.hidden);
        await service.handleAppLifecycleState(AppLifecycleState.resumed);
        await awake.setRequested(Object(), false);
        expect(calls, isEmpty);
      });
    } finally {
      screenAwakeService = previousAwake;
    }
  });

  test('automatic background suspension settles current PUT and resumes without user pause', () async {
    await _withAutomaticFixture((home, server, repo, service) async {
      final first = await _fixtureCopy(home, 8020, 'gradient.jpg');
      server.holdObjectPut = true;
      await service.setAutoSync(true);
      await server.putStarted.future.timeout(const Duration(seconds: 10));
      await service.handleAppLifecycleState(AppLifecycleState.inactive);
      final suspending = service.handleAppLifecycleState(
        AppLifecycleState.paused,
      );
      server.holdObjectPut = false;
      server.putGate.complete();
      await suspending;
      final pending = (await repo.listWorkItems(copyId: first)).single;
      expect(pending.state, isNot(anyOf('failed', 'paused')));
      expect(await _libraryNamespace(repo, first), isNull);
      final second = await _fixtureCopy(home, 8021, 'gradient.png');
      expect(
        await repo.listWorkItems(copyId: second, includeFinished: true),
        isEmpty,
      );
      await service.handleAppLifecycleState(AppLifecycleState.resumed);
      await _waitForHandoff(repo, first);
      await _waitForHandoff(repo, second);
    });
  });

  test(
    'hidden resumed hidden preserves the latest lifecycle while a PUT settles',
    () async {
      await _withAutomaticFixture((home, server, repo, service) async {
        final copy = await _fixtureCopy(home, 8022, 'gradient.jpg');
        server.holdObjectPut = true;
        await service.setAutoSync(true);
        await server.putStarted.future.timeout(const Duration(seconds: 10));
        final firstHidden = service.handleAppLifecycleState(
          AppLifecycleState.hidden,
        );
        final staleResume = service.handleAppLifecycleState(
          AppLifecycleState.resumed,
        );
        final lastHidden = service.handleAppLifecycleState(
          AppLifecycleState.hidden,
        );
        server.holdObjectPut = false;
        server.putGate.complete();
        await Future.wait([firstHidden, staleResume, lastHidden]);
        final second = await _fixtureCopy(home, 8023, 'gradient.png');
        await service.synchronizeAutomatic();
        expect(await _libraryNamespace(repo, copy), isNull);
        expect(
          await repo.listWorkItems(copyId: second, includeFinished: true),
          isEmpty,
        );
        await service.handleAppLifecycleState(AppLifecycleState.resumed);
        await _waitForHandoff(repo, copy);
        await _waitForHandoff(repo, second);
      });
    },
  );

  test(
    'paused automatic input remains paused until explicit manual resume',
    () async {
      await _withAutomaticFixture((home, server, repo, service) async {
        final copy = await _fixtureCopy(home, 8030, 'gradient.jpg');
        server.putFailureStatus = 503;
        await service.setAutoSync(true);
        final work = await _waitForCopyState(repo, copy, 'failed');
        await service.pause(work.workItemId);
        await localContentService.updateMetadata(
          copy,
          collections: ['New while paused'],
        );
        server.putFailureStatus = null;
        await service.handleAppLifecycleState(AppLifecycleState.resumed);
        expect((await repo.getWorkItem(work.workItemId))!.state, 'paused');
        await service.resume(work.workItemId);
        await _waitForHandoff(repo, copy);
        final jobs = await repo.listWorkItems(
          copyId: copy,
          includeFinished: true,
        );
        expect(jobs.every((job) => job.source == 'manual'), isTrue);
        expect((await service.listCloudEntries()).single.collections, [
          'New while paused',
        ]);
      });
    },
  );

  for (final state in ['paused', 'failed']) {
    test(
      'page replacement preserves automatic $state until explicit fresh-input resume',
      () async {
        await _withAutomaticFixture((home, server, repo, service) async {
          final copy = await _fixtureCopy(home, 8041, 'gradient.jpg');
          server.putFailureStatus = 401;
          await service.setAutoSync(true);
          final work = await _waitForCopyState(repo, copy, 'failed');
          if (state == 'paused') await service.pause(work.workItemId);
          server.putFailureStatus = null;
          await _replaceFixturePage(copy, 'gradient.png');
          await service.handleAppLifecycleState(AppLifecycleState.resumed);
          final retained = (await repo.listWorkItems(copyId: copy)).single;
          expect(retained.workItemId, work.workItemId);
          expect(retained.state, state);
          expect(retained.source, 'automatic');
          await service.resume(work.workItemId);
          await _waitForHandoff(repo, copy);
          final entry = (await service.listCloudEntries()).single;
          expect(
            entry.manifest.pages.single.rawHash,
            (await repo.getPage(copy, 0)).rawHash,
          );
          expect((await repo.getWorkItem(work.workItemId))!.source, 'manual');
        });
      },
    );
  }

  test('page rollover keeps automatic source while disabled and starts only after enable', () async {
    await _withAutomaticFixture((home, server, repo, service) async {
      final copy = await _fixtureCopy(home, 8042, 'gradient.jpg');
      final old = await repo.createWorkItem(
        kind: 'content',
        targetNamespace: webDavSetting.connection.namespace,
        copyId: copy,
        inputJson: jsonEncode({'copyId': copy}),
        source: 'automatic',
        finishAction: 'handoff',
      );
      await _replaceFixturePage(copy, 'gradient.png');
      await service.resumePending();
      final items = await repo.listWorkItems(
        copyId: copy,
        includeFinished: true,
      );
      expect(items, hasLength(2));
      expect(items.first.workItemId, old.workItemId);
      expect(items.first.state, 'cancelled');
      expect(items.last.state, 'queued');
      expect(items.last.source, 'automatic');
      expect(items.last.finishAction, 'handoff');
      expect(server.pagePuts, 0);
      await service.setAutoSync(true);
      await _waitForHandoff(repo, copy);
      expect(
        (await repo.getWorkItem(items.last.workItemId))!.finishAction,
        'handoff',
      );
    });
  });

  test('cancelled automatic snapshot stays cancelled until its content metadata changes', () async {
    await _withAutomaticFixture((home, server, repo, service) async {
      final copy = await _fixtureCopy(home, 8040, 'gradient.jpg');
      server.putFailureStatus = 503;
      await service.setAutoSync(true);
      final failed = await _waitForCopyState(repo, copy, 'failed');
      await service.cancel(failed.workItemId);
      server.putFailureStatus = null;
      await service.handleAppLifecycleState(AppLifecycleState.resumed);
      expect(await repo.listWorkItems(copyId: copy), isEmpty);
      await localContentService.updateMetadata(
        copy,
        collections: ['Real change'],
      );
      await _waitForHandoff(repo, copy);
      final jobs = await repo.listWorkItems(
        copyId: copy,
        includeFinished: true,
      );
      expect(jobs, hasLength(2));
      expect(jobs.first.state, 'cancelled');
      expect(jobs.last.state, 'completed');
    });
  });

  for (final status in [503, 401, 422]) {
    test(
      'automatic foreground retry classifies HTTP $status and explicit retry stays manual',
      () async {
        await _withAutomaticFixture((home, server, repo, service) async {
          final copy = await _fixtureCopy(home, 8050 + status, 'gradient.jpg');
          server.putFailureStatus = status;
          await service.setAutoSync(true);
          final failed = await _waitForCopyState(repo, copy, 'failed');
          server.putFailureStatus = null;
          await service.synchronizeAutomatic(copyId: copy);
          expect((await repo.getWorkItem(failed.workItemId))!.state, 'failed');
          await service.handleAppLifecycleState(AppLifecycleState.resumed);
          if (status != 503) {
            expect(
              (await repo.getWorkItem(failed.workItemId))!.state,
              'failed',
            );
            await service.resume(failed.workItemId);
          }
          await _waitForHandoff(repo, copy);
          expect(
            (await repo.getWorkItem(failed.workItemId))!.source,
            status == 503 ? 'automatic' : 'manual',
          );
        });
      },
    );
  }

  test('already published content hands off without uploads and notification errors cannot undo it', () async {
    await _withAutomaticFixture((home, server, repo, service) async {
      final copy = await _fixtureCopy(home, 8060, 'gradient.jpg');
      final manual = await service.requestUpload(copy);
      await _workFinished(service, repo, manual);
      final puts = server.requests
          .where((request) => request.method == 'PUT')
          .length;
      var notices = 0;
      localContentService.onLibraryChanged = () async =>
          throw StateError('Projection display unavailable');
      service.onHandoffCompleted = (_) {
        notices++;
        throw StateError('Notification unavailable');
      };
      await service.setAutoSync(true);
      await _waitForHandoff(repo, copy);
      expect(
        server.requests.where((request) => request.method == 'PUT'),
        hasLength(puts),
      );
      expect(
        (await repo.listWorkItems(
          copyId: copy,
          includeFinished: true,
        )).last.state,
        'completed',
      );
      expect(
        await localContentService.readPageForDisplay(copy, 0),
        await File('native/tests/fixtures/gradient.jpg').readAsBytes(),
      );
      await service.setAutoSync(false);
      expect(notices, 1);
      localContentService.onLibraryChanged = null;
      final second = await _fixtureCopy(home, 8061, 'gradient.png');
      await service.synchronizeAutomatic();
      expect(
        await repo.listWorkItems(copyId: second, includeFinished: true),
        isEmpty,
      );
      final explicit = await service.requestUpload(second);
      await _workFinished(service, repo, explicit);
      expect((await repo.getWorkItem(explicit))!.source, 'manual');
    });
  });

  test(
    'enabling automatic sync preserves a user selected release disposition',
    () async {
      await _withAutomaticFixture((home, server, repo, service) async {
        final copy = await _fixtureCopy(home, 8070, 'gradient.jpg');
        server.holdObjectPut = true;
        final id = await service.requestUpload(copy, cleanupAfterUpload: true);
        await server.putStarted.future.timeout(const Duration(seconds: 10));
        await service.setAutoSync(true);
        expect((await repo.getWorkItem(id))!.finishAction, 'release');
        server.holdObjectPut = false;
        server.putGate.complete();
        await _workFinished(service, repo, id, cleanup: true);
        expect(await Directory('${home.path}/copy-8070').exists(), isFalse);
      });
    },
  );

  test(
    'restored content belongs to the cloud namespace and does not upload again',
    () async {
      await _withAutomaticFixture((home, server, repo, service) async {
        final copy = await _fixtureCopy(home, 8080, 'gradient.jpg');
        final uploaded = await service.requestUpload(copy);
        await _workFinished(service, repo, uploaded);
        final entry = (await service.listCloudEntries()).single;
        await localContentService.retireCopy(copy);
        await service.setAutoSync(true);
        final restored = await service.restore(entry.manifestId);
        expect(restored, isNot(copy));
        final resident = await repo.getPage(restored, 0);
        final restoredRoot = await localContentService.rootPath(restored);
        expect(resident.codecProfile, ContentCodec.encodedProfile);
        expect(resident.objectHash, entry.manifest.pages.single.objectHash);
        final residentFile = File('$restoredRoot/${resident.relativePath}');
        expect(
          await residentFile.length(),
          entry.manifest.pages.single.storedLength,
        );
        expect(
          (await sha256.bind(residentFile.openRead()).first).toString(),
          resident.objectHash,
        );
        expect(await File('$restoredRoot/0001.jpg').exists(), false);
        expect(
          await localContentService.readPageForDisplay(restored, 0),
          await File('native/tests/fixtures/gradient.jpg').readAsBytes(),
        );
        final exported = await localContentService.exportPageToFile(
          restored,
          0,
          '${home.path}/exported.jpg',
        );
        expect(
          await exported.readAsBytes(),
          await File('native/tests/fixtures/gradient.jpg').readAsBytes(),
        );
        expect(await File('$restoredRoot/0001.jpg').exists(), false);
        expect(
          await _libraryNamespace(repo, restored),
          webDavSetting.connection.namespace,
        );
        final puts = server.requests
            .where((request) => request.method == 'PUT')
            .length;
        await service.handleAppLifecycleState(AppLifecycleState.resumed);
        expect(
          server.requests.where((request) => request.method == 'PUT'),
          hasLength(puts),
        );
        expect(
          (await repo.listWorkItems(
            copyId: restored,
            includeFinished: true,
          )).map((work) => work.kind),
          ['restore'],
        );
        expect((await service.listCloudEntries()).single.localCopyId, restored);
      });
    },
  );

  test('owner page URL enrichment publishes a metadata revision without changing object references', () async {
    await _withAutomaticFixture((home, server, repo, service) async {
      final copy = await _fixtureCopy(home, 8090, 'gradient.jpg');
      await service.setAutoSync(true);
      await _waitForHandoff(repo, copy);
      final before = (await service.listCloudEntries()).single;
      final puts = server.pagePuts;
      const sourceUrl = 'https://e-hentai.org/s/sourcehash/8090-1';
      await localContentService.setSourcePageUrl(copy, 0, sourceUrl);
      await service.synchronizeAutomatic(copyId: copy);
      await _waitUntil(
        () async =>
            (await service.listCloudEntries())
                .single
                .manifest
                .pages
                .single
                .sourcePageUrl ==
            sourceUrl,
      );
      final after = (await service.listCloudEntries()).single;
      expect(
        after.manifest.pages.single.objectHash,
        before.manifest.pages.single.objectHash,
      );
      expect(server.pagePuts, puts);
    });
  });

  test(
    'concurrent owner metadata writes and completion merge all current facts',
    () async {
      final home = await Directory.systemTemp.createTemp(
        'metadata-transactions-',
      );
      pathService.appDocDir = home;
      pathService.appSupportDir = home;
      pathService.tempDir = home;
      appDb = AppDb();
      localContentService = LocalContentService(
        repository: ContentRepository(appDb),
      );
      try {
        await File('${home.path}/1.jpg').writeAsBytes([1, 2, 3]);
        final copy = await localContentService.ensureCopy(
          gid: 7400,
          representation: 'original',
          rootPath: home.path,
        );
        await localContentService.recordPage(
          copyId: copy,
          ordinal: 0,
          relativePath: '1.jpg',
        );
        await Future.wait([
          localContentService.updateMetadata(
            copy,
            collections: ['Concurrent group'],
          ),
          localContentService.updateMetadata(
            copy,
            tags: [const PortableTag('artist', 'current')],
          ),
          localContentService.updateMetadata(
            copy,
            providerMetadata: {'rawTitle': 'Website title'},
          ),
          localContentService.completeCopy(
            copy,
            galleryUrl: 'https://e-hentai.org/g/7400/0123456789/',
            title: 'Personal title',
            expectedPages: 1,
          ),
        ]);
        final current = (await localContentService.completedInput(copy))!;
        expect(current.collections, ['Concurrent group']);
        expect(current.tags.single.name, 'current');
        expect(current.providerMetadata['rawTitle'], 'Website title');
        expect(current.title, 'Personal title');
      } finally {
        await appDb.close();
        await home.delete(recursive: true);
      }
    },
  );

  test('eight thumbnail revisions complete while a queued revision pauses without throwing', () async {
    final home = await Directory.systemTemp.createTemp('revision-slots-');
    final server = await _DavServer.start();
    pathService.appDocDir = home;
    pathService.appSupportDir = home;
    pathService.tempDir = home;
    appDb = AppDb();
    final repo = _RevisionBarrierRepository(appDb);
    localContentService = LocalContentService(repository: repo);
    final service = GallerySyncService(repository: repo);
    try {
      await _configureServer(server);
      await service.doInitBean();
      final entries = <CloudGalleryEntry>[];
      for (final gid in List.generate(8, (index) => 7401 + index)) {
        entries.add(await _seedMetadataEntry(repo, home, gid));
      }
      final ids = await Future.wait([
        for (var i = 0; i < entries.length; i++)
          () async {
            final file = File(
              'native/tests/fixtures/${i.isEven ? 'minimal' : 'gradient'}.png',
            );
            final hash = (await sha256.bind(file.openRead()).first).toString();
            return service.requestMetadataRevision(
              entries[i].manifestId,
              title: 'Revised $i',
              tags: [],
              thumbnail: PortableThumbnail(
                rawHash: hash,
                rawLength: await file.length(),
                objectHash: hash,
                mime: 'image/png',
              ),
              thumbnailArtifact: file,
            );
          }(),
      ]);
      // The second repository read is inside _runRevision, after its outer
      // lease. Releasing all eight readers reproduces nested-slot deadlock.
      await repo.allRevisionsEntered.future.timeout(
        const Duration(seconds: 10),
      );
      final queuedEntry = await _seedMetadataEntry(repo, home, 7409);
      final queuedId = await service.requestMetadataRevision(
        queuedEntry.manifestId,
        title: 'Queued',
        tags: [],
      );
      final pausing = service.pause(queuedId);
      repo.releaseRevisions.complete();
      await Future.wait([
        ...ids.map((id) => _workFinished(service, repo, id)),
        pausing,
      ]);
      expect((await repo.getWorkItem(queuedId))!.state, 'paused');
      expect(
        server.requests.where((request) => request.path.contains(queuedId)),
        isEmpty,
      );
      expect(
        (await service.listCloudEntries())
            .where((entry) => entry.gid != 7409)
            .every((entry) => entry.manifest.thumbnail != null),
        isTrue,
      );
      expect(server.pagePuts, inInclusiveRange(2, 8));
      expect(server.maxActivePuts, lessThanOrEqualTo(8));
    } finally {
      if (!repo.releaseRevisions.isCompleted) repo.releaseRevisions.complete();
      service.dispose();
      await server.server.close(force: true);
      await appDb.close();
      await home.delete(recursive: true);
    }
  });

  test('website refresh retains concurrent user revision and publishes despite missing cover', () async {
    final home = await Directory.systemTemp.createTemp(
      'website-current-heads-',
    );
    final server = await _DavServer.start();
    pathService.appDocDir = home;
    pathService.appSupportDir = home;
    pathService.tempDir = home;
    appDb = AppDb();
    final repo = ContentRepository(appDb);
    localContentService = LocalContentService(repository: repo);
    final service = GallerySyncService(repository: repo);
    final originalRequest = ehRequest;
    final gate = Completer<void>();
    final website = _WebsiteMetadataRequest(detailGate: gate, coverUrl: '');
    ehRequest = website;
    try {
      await _configureServer(server);
      await service.doInitBean();
      final entry = await _seedMetadataEntry(repo, home, 7403);
      final refreshing = service.requestWebsiteMetadataRevision(entry);
      await website.detailStarted.future;
      final userWork = await service.requestMetadataRevision(
        entry.manifestId,
        title: 'New personal title',
        tags: [],
        collections: ['New personal group'],
        lineageAdded: const [
          ManifestLineage(7300, 7390, 'source_parent'),
          ManifestLineage(7391, 7403, 'upgrade'),
        ],
      );
      await _workFinished(service, repo, userWork);
      final userId = (await service.listCloudEntries()).single.manifestId;
      gate.complete();
      await _workFinished(service, repo, await refreshing);
      final updated = (await service.listCloudEntries()).single;
      expect(updated.title, 'New personal title');
      expect(updated.collections, ['New personal group']);
      expect(updated.manifest.rawTitle, 'Website title');
      expect(updated.manifest.thumbnail, isNull);
      expect(updated.manifest.supersedes, contains(userId));
      expect(
        updated.manifest.lineage
            .map((edge) => '${edge.fromGid}:${edge.toGid}:${edge.kind}')
            .toSet(),
        {
          '7300:7390:source_parent',
          '7391:7403:upgrade',
          '7403:7203:source_parent',
        },
      );
      expect(
        server.requests.where(
          (request) =>
              request.method == 'GET' && request.path.contains('/objects/'),
        ),
        hasLength(1),
      );
    } finally {
      if (!gate.isCompleted) gate.complete();
      ehRequest = originalRequest;
      service.dispose();
      await server.server.close(force: true);
      await appDb.close();
      await home.delete(recursive: true);
    }
  });

  test(
    'website detail from another gid cannot change the selected manifest',
    () async {
      final home = await Directory.systemTemp.createTemp('website-wrong-gid-');
      final server = await _DavServer.start();
      pathService.appDocDir = home;
      pathService.appSupportDir = home;
      pathService.tempDir = home;
      appDb = AppDb();
      final repo = ContentRepository(appDb);
      localContentService = LocalContentService(repository: repo);
      final service = GallerySyncService(repository: repo);
      final originalRequest = ehRequest;
      ehRequest = _WebsiteMetadataRequest(returnedGid: 9999);
      try {
        await _configureServer(server);
        await service.doInitBean();
        final entry = await _seedMetadataEntry(repo, home, 7404);
        await expectLater(
          service.requestWebsiteMetadataRevision(entry),
          throwsA(isA<FormatException>()),
        );
        expect(
          (await service.listCloudEntries()).single.manifestId,
          entry.manifestId,
        );
        expect(await repo.listWorkItems(kind: 'revision'), isEmpty);
        expect(server.requests, isEmpty);
      } finally {
        ehRequest = originalRequest;
        service.dispose();
        await server.server.close(force: true);
        await appDb.close();
        await home.delete(recursive: true);
      }
    },
  );

  test('website revision stays queued on its original target across a connection change', () async {
    final home = await Directory.systemTemp.createTemp('website-target-');
    final server = await _DavServer.start();
    pathService.appDocDir = home;
    pathService.appSupportDir = home;
    pathService.tempDir = home;
    appDb = AppDb();
    final repo = ContentRepository(appDb);
    localContentService = LocalContentService(repository: repo);
    final service = GallerySyncService(repository: repo);
    final originalRequest = ehRequest;
    final gate = Completer<void>();
    final website = _WebsiteMetadataRequest(detailGate: gate, coverUrl: '');
    ehRequest = website;
    try {
      await _configureServer(server);
      await service.doInitBean();
      final originalConnection = webDavSetting.connection;
      final entry = await _seedMetadataEntry(repo, home, 7405);
      final refreshing = service.requestWebsiteMetadataRevision(entry);
      await website.detailStarted.future;
      await webDavSetting.save(
        address: 'http://localhost:${server.server.port}/v1/dav/sync/',
        username: 'test',
        password: 'test',
        rootPath: 'other',
      );
      await service.targetChanged();
      await _seedMetadataEntry(repo, home, 7405, fileName: 'second-target');
      final afterSwitch = server.requests.length;
      gate.complete();
      final id = await refreshing;
      final work = (await repo.getWorkItem(id))!;
      expect(work.targetNamespace, originalConnection.namespace);
      expect(work.state, 'queued');
      expect(
        server.requests
            .skip(afterSwitch)
            .where((request) => request.path.contains('/other/')),
        isEmpty,
      );
      await _configureServer(server);
      await service.targetChanged();
      await service.resumePending();
      await _workFinished(service, repo, id);
      expect(
        (await service.listCloudEntries()).single.manifest.rawTitle,
        'Website title',
      );
    } finally {
      if (!gate.isCompleted) gate.complete();
      ehRequest = originalRequest;
      service.dispose();
      await server.server.close(force: true);
      await appDb.close();
      await home.delete(recursive: true);
    }
  });

  test(
    'completion preserves owner refreshed tags including an empty tag set',
    () async {
      final home = await Directory.systemTemp.createTemp('completion-tags-');
      pathService.appDocDir = home;
      pathService.appSupportDir = home;
      pathService.tempDir = home;
      appDb = AppDb();
      localContentService = LocalContentService(
        repository: ContentRepository(appDb),
      );
      try {
        final root = Directory('${home.path}/copy');
        await root.create();
        await File('${root.path}/1.jpg').writeAsBytes([1, 2, 3]);
        final copyId = await localContentService.ensureCopy(
          gid: 7301,
          representation: 'original',
          rootPath: root.path,
        );
        await localContentService.recordPage(
          copyId: copyId,
          ordinal: 0,
          relativePath: '1.jpg',
        );
        await localContentService.updateMetadata(
          copyId,
          tags: [],
          collections: ['Refreshed group'],
          providerMetadata: {'rawTitle': 'Fresh title'},
        );
        final completed = await localContentService.completeCopy(
          copyId,
          galleryUrl: 'https://e-hentai.org/g/7301/0123456789/',
          title: 'Personal title',
          tags: [const PortableTag('artist', 'old')],
          expectedPages: 1,
        );
        expect(completed.tags, isEmpty);
        expect(completed.collections, ['Refreshed group']);
        expect(completed.providerMetadata['rawTitle'], 'Fresh title');
        await localContentService.updateMetadata(
          copyId,
          tags: [const PortableTag('artist', 'fresh')],
        );
        await localContentService.updateMetadata(
          copyId,
          collections: ['Another group'],
        );
        final current = await localContentService.completedInput(copyId);
        expect(current!.tags.single.name, 'fresh');
        expect(current.collections, ['Another group']);
      } finally {
        await appDb.close();
        await home.delete(recursive: true);
      }
    },
  );

  test('same-page heads aggregate groups and tags while history and family filters retain facts', () async {
    final home = await Directory.systemTemp.createTemp('cloud-facets-');
    final server = await _DavServer.start();
    pathService.appDocDir = home;
    pathService.appSupportDir = home;
    pathService.tempDir = home;
    appDb = AppDb();
    final repo = ContentRepository(appDb);
    localContentService = LocalContentService(repository: repo);
    final service = GallerySyncService(repository: repo);
    try {
      await _configureServer(server);
      await service.doInitBean();
      final page = PortablePage(
        rawHash: 'a' * 64,
        rawLength: 1,
        objectHash: 'a' * 64,
        storedLength: 1,
        codecProfile: 'raw',
        mime: 'image/png',
      );
      Future<String> seed(String name, PortableManifest manifest) async {
        final artifact = PortableManifestCodec.write(
          File('${home.path}/$name.sqlite'),
          manifest,
        );
        await repo.importManifest(webDavSetting.connection.namespace, artifact);
        await repo.recordRemoteResource(
          targetNamespace: webDavSetting.connection.namespace,
          href:
              'manifests/${artifact.manifestId.substring(0, 2)}/${artifact.manifestId}.sqlite',
          kind: 'manifest',
          objectHash: artifact.manifestId,
          partition: artifact.manifestId.substring(0, 2),
        );
        return artifact.manifestId;
      }

      final base = PortableManifest(
        gid: 7001,
        representation: 'original',
        galleryUrl: 'https://e-hentai.org/g/7001/token/',
        title: 'My title',
        rawTitle: 'Site title',
        category: 'Manga',
        uploader: 'Uploader',
        collections: const ['Group A'],
        tags: const [PortableTag('artist', 'alice')],
        pages: [page],
      );
      final first = await seed('a', base);
      final second = await seed(
        'b',
        base.copyWith(
          collections: ['Group B'],
          tags: [const PortableTag('language', 'japanese')],
          lineage: [const ManifestLineage(6001, 7001, 'source_parent')],
        ),
      );
      final list = await service.listCloudEntries();
      expect(list, hasLength(1));
      expect(list.single.collections.toSet(), {'Group A', 'Group B'});
      expect(list.single.tags.map((tag) => tag.name).toSet(), {
        'alice',
        'japanese',
      });
      expect(list.single.equivalentManifestIds.toSet(), {first, second});
      final history = await service.listHistory(list.single);
      expect(history, hasLength(1));
      expect(history.single.collections, hasLength(1));
      expect(
        await service.listCloudEntries(
          search: 'uploader',
          category: 'Manga',
          collection: 'Group A',
          tag: const PortableTag('artist', 'alice'),
        ),
        hasLength(1),
      );
      expect(await service.listCloudEntries(search: 'japanese'), hasLength(1));
      expect(await service.listCloudEntries(category: 'Other'), isEmpty);
      final facets = await service.listCloudFacets();
      expect(facets.categories, ['Manga']);
      expect(facets.collections, ['Group A', 'Group B']);
      expect(facets.tags, hasLength(2));
      // A new unrelated edge arrives after the user observed the two heads.
      final third = await seed(
        'c',
        base.copyWith(
          lineage: [const ManifestLineage(6000, 6002, 'source_parent')],
        ),
      );
      final revised = await service.requestMetadataRevision(
        first,
        title: 'Personal title',
        lineageRemoved: [const ManifestLineage(6001, 7001, 'source_parent')],
        lineageAdded: [const ManifestLineage(6003, 7001, 'source_parent')],
        providerMetadata: {'rating': 4.5},
      );
      await _workFinished(service, repo, revised);
      final current = (await service.listCloudEntries()).single;
      expect(current.manifest.supersedes.toSet(), {first, second, third});
      expect(
        current.manifest.lineage
            .map((edge) => '${edge.fromGid}:${edge.toGid}:${edge.kind}')
            .toSet(),
        {'6000:6002:source_parent', '6003:7001:source_parent'},
      );
      expect(current.manifest.pages.single.rawHash, page.rawHash);
      expect(current.manifest.rating, 4.5);
      expect(current.manifest.category, 'Manga');
      expect(current.manifest.rawTitle, 'Site title');
      expect(current.collections.toSet(), {'Group A', 'Group B'});
      expect(
        server.requests.where((request) => request.path.contains('/objects/')),
        isEmpty,
      );
    } finally {
      service.dispose();
      await server.server.close(force: true);
      await appDb.close();
      await home.delete(recursive: true);
    }
  });

  for (final fixture in [
    ('gradient.jpg', 'image/jpeg'),
    ('gradient.png', 'image/png'),
    ('animated.gif', 'image/gif'),
  ]) {
    test(
      'cloud ${fixture.$2} cover reads first display page and caches without remote writes',
      () async {
        final home = await Directory.systemTemp.createTemp('cloud-cover-');
        final server = await _DavServer.start();
        pathService.appDocDir = home;
        pathService.appSupportDir = home;
        pathService.tempDir = home;
        appDb = AppDb();
        final repo = ContentRepository(appDb);
        localContentService = LocalContentService(repository: repo);
        final counter = _EncodingCounter();
        final service = GallerySyncService(repository: repo, codec: counter);
        try {
          await _configureServer(server);
          await service.doInitBean();
          final encoded = await ContentCodec().encodeFile(
            inputPath: 'native/tests/fixtures/${fixture.$1}',
            outputPath: '${home.path}/first.encoded',
          );
          final first = PortablePage(
            rawHash: encoded.rawHash,
            rawLength: encoded.rawLength,
            objectHash: encoded.objectHash,
            storedLength: encoded.storedLength,
            codecProfile: encoded.codecProfile,
            mime: fixture.$2,
          );
          final second = PortablePage(
            rawHash: 'b' * 64,
            rawLength: 1,
            objectHash: 'b' * 64,
            storedLength: 1,
            codecProfile: 'raw',
            mime: 'image/jpeg',
          );
          server.files['/v1/dav/sync/hclient-v1/objects/${first.objectHash.substring(0, 2)}/${first.objectHash}'] =
              await File(encoded.path).readAsBytes();
          final manifest = PortableManifest(
            gid: 7101,
            representation: 'original',
            galleryUrl: 'https://e-hentai.org/g/7101/token/',
            title: 'Cloud only',
            tags: [],
            pages: [first, second],
            codecProfiles: {
              if (first.codecProfile != 'raw')
                first.codecProfile: ContentCodec
                    .profileDefinitions[first.codecProfile]!
                    .cast<String, Object?>(),
            },
          );
          final entry = CloudGalleryEntry(
            gid: manifest.gid,
            representation: manifest.representation,
            title: manifest.title,
            manifestId: 'c' * 64,
            manifest: manifest,
            equivalentManifestIds: [],
            localCopyId: null,
            localState: CloudLocalState.none,
          );
          final thumbnail = await service.thumbnailFile(entry);
          expect(thumbnail, isNotNull);
          expect(await thumbnail!.exists(), isTrue);
          expect(counter.displayReads, 1);
          final reads = server.requests
              .where((request) => request.method == 'GET')
              .toList();
          expect(reads, hasLength(1));
          expect(reads.single.path, endsWith(first.objectHash));
          expect(
            server.requests.where(
              (request) => request.method == 'PUT' || request.method == 'MOVE',
            ),
            isEmpty,
          );
          expect(await service.thumbnailFile(entry), isNotNull);
          expect(counter.displayReads, 1);
          expect(
            server.requests.where((request) => request.method == 'GET'),
            hasLength(1),
          );
          expect(
            (await home.list(recursive: true).toList()).whereType<File>().where(
              (file) =>
                  file.path.endsWith('page.object') ||
                  file.path.endsWith('page.decoded'),
            ),
            isEmpty,
          );
        } finally {
          service.dispose();
          await server.server.close(force: true);
          await appDb.close();
          await home.delete(recursive: true);
        }
      },
    );
  }

  test('website metadata uses one detail request and replaces only authoritative gid edges', () async {
    final home = await Directory.systemTemp.createTemp('website-metadata-');
    final server = await _DavServer.start();
    pathService.appDocDir = home;
    pathService.appSupportDir = home;
    pathService.tempDir = home;
    appDb = AppDb();
    final repo = ContentRepository(appDb);
    localContentService = LocalContentService(repository: repo);
    final service = GallerySyncService(repository: repo);
    final previousRequest = ehRequest;
    final website = _WebsiteMetadataRequest();
    ehRequest = website;
    try {
      await _configureServer(server);
      await service.doInitBean();
      final copy = await _fixtureCopy(
        home,
        7201,
        'gradient.jpg',
        lineage: const [
          ManifestLineage(7199, 7201, 'source_parent'),
          ManifestLineage(7201, 7202, 'source_parent'),
          ManifestLineage(7190, 7201, 'upgrade'),
          ManifestLineage(7180, 7190, 'source_parent'),
        ],
      );
      await localContentService.updateMetadata(
        copy,
        collections: ['Personal group'],
        tags: [const PortableTag('artist', 'old')],
      );
      final upload = await service.requestUpload(copy);
      await _workFinished(service, repo, upload);
      final original = (await service.listCloudEntries()).single;
      final work = await service.requestWebsiteMetadataRevision(original);
      await _workFinished(service, repo, work);
      final updated = (await service.listCloudEntries()).single;
      expect(website.calls, 1);
      expect(updated.gid, 7201);
      expect(updated.title, original.title);
      expect(updated.collections, ['Personal group']);
      expect(updated.tags, isEmpty);
      expect(updated.manifest.rawTitle, 'Website title');
      expect(updated.manifest.rating, 4.25);
      expect(updated.manifest.japaneseTitle, '日本語');
      expect(updated.manifest.category, 'Manga');
      expect(
        updated.manifest.pages.single.rawHash,
        original.manifest.pages.single.rawHash,
      );
      expect(
        updated.manifest.lineage
            .map((edge) => '${edge.fromGid}:${edge.toGid}:${edge.kind}')
            .toSet(),
        {
          '7190:7201:upgrade',
          '7180:7190:source_parent',
          '7201:7203:source_parent',
        },
      );
      expect(updated.manifest.thumbnail, isNotNull);
    } finally {
      ehRequest = previousRequest;
      for (final work in await repo.listWorkItems(includeFinished: true)) {
        await service.cancel(work.workItemId);
      }
      service.dispose();
      await server.server.close(force: true);
      await appDb.close();
      await home.delete(recursive: true);
    }
  });

  test(
    'error facts retain classification and HTTP status without request data',
    () {
      const sensitive = 'https://user:secret@example.com/private?token=secret';
      final failure = WebDavFailure.fromError(
        const WebDavException(WebDavErrorKind.authentication, sensitive, 403),
      );
      expect(failure.toJson(), {'kind': 'authentication', 'statusCode': 403});
      expect(webDavFailureText(failure), contains('HTTP 403'));
      expect(webDavFailureText(failure), isNot(contains('secret')));
      expect(
        WebDavFailure.fromError(const FileSystemException(sensitive)).kind,
        'localIo',
      );
      expect(
        WebDavFailure.fromError(const ContentCodecException(2)).kind,
        'codec',
      );
      expect(
        WebDavFailure.fromError(const FormatException(sensitive)).kind,
        'invalidData',
      );
      expect(WebDavFailure.fromError(StateError(sensitive)).kind, 'unknown');
    },
  );

  test(
    'upload failures survive restart and do not replace discovery errors',
    () async {
      final home = await Directory.systemTemp.createTemp('gallery-error-test-');
      final server = await _DavServer.start();
      pathService.appDocDir = home;
      pathService.appSupportDir = home;
      pathService.tempDir = home;
      appDb = AppDb();
      final repo = ContentRepository(appDb);
      localContentService = LocalContentService(repository: repo);
      final service = GallerySyncService(repository: repo);
      GallerySyncService? restarted;
      try {
        await _configureServer(server);
        await service.doInitBean();
        server.manifestListingFailureStatus = 503;
        await service.refresh();
        final discoveryError = service.lastError;
        expect(discoveryError, contains('HTTP 503'));
        server.putFailureStatus = 403;
        final copyId = await _fixtureCopy(home, 2901, 'passthrough.webp');
        final id = await service.requestUpload(
          copyId,
          cleanupAfterUpload: true,
        );
        await _waitUntil(
          () async => (await repo.getWorkItem(id))?.state == 'failed',
        );
        final failed = (await service.listSyncJobs()).single;
        expect(failed.error?.kind, 'authentication');
        expect(failed.error?.statusCode, 403);
        expect(failed.cleanupAfterUpload, isTrue);
        expect(service.lastError, discoveryError);
        restarted = GallerySyncService(repository: repo);
        await restarted.doInitBean();
        expect((await restarted.listSyncJobs()).single.error?.statusCode, 403);
        expect(restarted.lastError, isNull);
        server.putFailureStatus = null;
        server.manifestListingFailureStatus = null;
        server.holdObjectPut = true;
        await restarted.resume(id);
        await server.putStarted.future.timeout(const Duration(seconds: 10));
        expect((await restarted.listSyncJobs()).single.error, isNull);
        expect(restarted.lastError, isNull);
        server.putGate.complete();
        await _workFinished(restarted, repo, id, cleanup: true);
        expect(
          jsonDecode((await repo.getWorkItem(id))!.artifactsJson),
          isNot(contains('_error')),
        );
        await service.refresh();
        expect(service.lastError, isNull);
        await downloadSetting.doInitBean();
        downloadSetting.downloadPath.value = home.path;
        final entry = (await restarted.listCloudEntries()).single;
        server.objectGetFailureStatus = 503;
        await expectLater(
          restarted.restore(entry.manifestId),
          throwsA(isA<WebDavException>()),
        );
        final restore = (await repo.listWorkItems(kind: 'restore')).single;
        expect(restore.state, 'failed');
        final restoreError = WebDavFailure.fromJson(
          (jsonDecode(restore.artifactsJson) as Map<String, dynamic>)['_error'],
        );
        expect(restoreError?.kind, 'server');
        expect(restoreError?.statusCode, 503);
        expect(restarted.lastError, isNull);
        server.objectGetFailureStatus = null;
        expect(await restarted.restore(entry.manifestId), restore.copyId);
        final completedRestore = (await repo.getWorkItem(restore.workItemId))!;
        expect(completedRestore.state, 'completed');
        expect(
          jsonDecode(completedRestore.artifactsJson),
          isNot(contains('_error')),
        );
      } finally {
        if (!server.putGate.isCompleted) {
          server.putGate.complete();
        }
        restarted?.dispose();
        service.dispose();
        await server.server.close(force: true);
        await appDb.close();
        await home.delete(recursive: true);
      }
    },
  );

  test(
    'saving a password retries a failed refresh of a completed index',
    () async {
      final home = await Directory.systemTemp.createTemp(
        'gallery-password-test-',
      );
      final server = await _DavServer.start();
      pathService.appDocDir = home;
      pathService.appSupportDir = home;
      pathService.tempDir = home;
      appDb = AppDb();
      final repo = ContentRepository(appDb);
      localContentService = LocalContentService(repository: repo);
      final service = GallerySyncService(repository: repo);
      try {
        await _configureServer(server);
        await service.doInitBean();
        await service.ensureInitialDiscovery();
        final initialRequests = server.requests.length;
        await service.ensureInitialDiscovery();
        expect(server.requests.length, initialRequests);
        final namespace = webDavSetting.connection.namespace;
        server.manifestListingAuthorization =
            'Basic ${base64Encode(utf8.encode('test:new-password'))}';
        await service.refresh();
        expect(service.lastError, contains('HTTP 401'));
        final failedRequests = server.requests.length;
        await webDavSetting.save(
          address: webDavSetting.address.value,
          username: webDavSetting.username.value,
          password: 'new-password',
          rootPath: webDavSetting.rootPath.value,
        );
        expect(webDavSetting.connection.namespace, namespace);
        await service.targetChanged();
        expect(service.lastError, isNull);
        expect(server.requests.length, failedRequests + 1);
        expect(server.requests.last.method, 'PROPFIND');
        expect(server.requests.last.path, endsWith('/manifests/'));
        final recoveredRequests = server.requests.length;
        await service.targetChanged();
        expect(server.requests.length, recoveredRequests);
      } finally {
        service.dispose();
        await server.server.close(force: true);
        await appDb.close();
        await home.delete(recursive: true);
      }
    },
  );

  for (final invalidStatus in [403, 409]) {
    test(
      'discovery reuses its index and re-enumerates only the $invalidStatus token partition',
      () async {
        final home = await Directory.systemTemp.createTemp(
          'gallery-token-test-',
        );
        final server = await _DavServer.start();
        pathService.appDocDir = home;
        pathService.appSupportDir = home;
        pathService.tempDir = home;
        appDb = AppDb();
        final repo = ContentRepository(appDb);
        localContentService = LocalContentService(repository: repo);
        final service = GallerySyncService(repository: repo);
        try {
          await _configureServer(server);
          await service.doInitBean();
          server.completeReports = true;
          Future<String> seed(int gid, String title) async {
            final artifact = PortableManifestCodec.write(
              File('${home.path}/seed-$gid-$title.sqlite'),
              PortableManifest(
                gid: gid,
                representation: 'original',
                galleryUrl: 'https://e-hentai.org/g/$gid/token/',
                title: title,
                tags: const [],
                pages: [
                  PortablePage(
                    rawHash: List.filled(64, 'a').join(),
                    rawLength: 1,
                    objectHash: List.filled(64, 'a').join(),
                    storedLength: 1,
                    codecProfile: 'raw',
                    mime: 'image/webp',
                  ),
                ],
              ),
            );
            final partition = artifact.manifestId.substring(0, 2);
            server.directories.add('/v1/dav/sync/hclient-v1/manifests/');
            server.directories.add(
              '/v1/dav/sync/hclient-v1/manifests/$partition/',
            );
            final remote =
                '/v1/dav/sync/hclient-v1/manifests/$partition/${artifact.manifestId}.sqlite';
            server.files[remote] = await artifact.file.readAsBytes();
            return remote;
          }

          final first = await seed(2401, 'first');
          // Choose a different real hash partition without fabricating a manifest ID.
          var second = await seed(2402, 'second');
          for (
            var suffix = 0;
            second.split('/')[6] == first.split('/')[6];
            suffix++
          ) {
            server.files.remove(second);
            second = await seed(2402, 'second-$suffix');
          }
          await service.ensureInitialDiscovery();
          expect(await service.listCloudEntries(), hasLength(2));
          final initialRequests = server.requests.length;
          for (var entry = 0; entry < 3; entry++) {
            await service.ensureInitialDiscovery();
            expect(
              await service.listCloudEntries(offset: entry % 2, limit: 1),
              hasLength(1),
            );
          }
          expect(server.requests.length, initialRequests);
          final firstPartition = first.split('/')[6];
          final secondPartition = second.split('/')[6];
          final oldTokens = Map<String, String>.from(server.partitionTokens);
          server.files.remove(first);
          await seed(2403, 'replacement');
          // Keep the replacement in its content-addressed partition. The invalid
          // partition must still fully enumerate and remove its vanished resource.
          server.invalidTokenStatuses[firstPartition] = invalidStatus;
          final refreshStart = server.requests.length;
          await service.refresh();
          final reports = server.requests
              .skip(refreshStart)
              .where((request) => request.method == 'REPORT')
              .toList();
          expect(
            reports
                .where((request) => request.path.endsWith('/$firstPartition/'))
                .map((request) => request.token),
            [oldTokens[firstPartition], ''],
          );
          expect(
            reports
                .where((request) => request.path.endsWith('/$secondPartition/'))
                .map((request) => request.token),
            [oldTokens[secondPartition]],
          );
          final entries = await service.listCloudEntries();
          expect(
            entries.map((entry) => entry.gid),
            unorderedEquals([2402, 2403]),
          );
          expect(
            await appDb
                .customSelect(
                  'SELECT 1 FROM content_remote_resource WHERE href = ?',
                  variables: [
                    Variable.withString(
                      first.substring('/v1/dav/sync/hclient-v1/'.length),
                    ),
                  ],
                )
                .get(),
            isEmpty,
          );
        } finally {
          service.dispose();
          await server.server.close(force: true);
          await appDb.close();
          await home.delete(recursive: true);
        }
      },
    );
  }

  test(
    'jumped gid reuses uploaded pages and revises metadata after cleanup',
    () async {
      final home = await Directory.systemTemp.createTemp('gallery-reuse-test-');
      final server = await _DavServer.start();
      pathService.appDocDir = home;
      pathService.appSupportDir = home;
      pathService.tempDir = home;
      appDb = AppDb();
      final repo = ContentRepository(appDb);
      localContentService = LocalContentService(repository: repo);
      final service = GallerySyncService(repository: repo);
      try {
        await _configureServer(server);
        await service.doInitBean();
        final oldCopy = await _fixtureCopy(home, 2501, 'passthrough.webp');
        final oldWork = await service.requestUpload(oldCopy);
        await _workFinished(service, repo, oldWork);
        final oldEntry = (await service.listCloudEntries()).single;
        final initialPuts = server.pagePuts;
        expect(initialPuts, 2); // Page plus its small cover.
        final newCopy = await _fixtureCopy(
          home,
          2503,
          'passthrough.webp',
          lineage: GalleryDownloadService.lineageForSelectedUpgradeBase(
            oldEntry.manifest.galleryUrl,
            2503,
          ),
        );
        final newWork = await service.requestUpload(
          newCopy,
          cleanupAfterUpload: true,
        );
        await _workFinished(service, repo, newWork, cleanup: true);
        expect(await Directory('${home.path}/copy-2503').exists(), isFalse);
        expect(server.pagePuts, initialPuts);
        final entries = await service.listCloudEntries();
        expect(entries, hasLength(2));
        expect(entries.map((entry) => entry.familyKey).toSet(), hasLength(1));
        expect(entries.first.gid, 2503);
        expect(entries.first.preferred, isTrue);
        expect(entries.last.preferred, isFalse);
        final base = entries.first;
        expect(
          base.manifest.pages.single.objectHash,
          oldEntry.manifest.pages.single.objectHash,
        );
        expect(
          base.manifest.lineage.map(
            (edge) => [edge.fromGid, edge.toGid, edge.kind],
          ),
          [
            [2501, 2503, 'upgrade'],
          ],
        );
        final revisionStart = server.requests.length;
        final revisionWork = await service.requestMetadataRevision(
          base.manifestId,
          title: 'Corrected title',
          tags: const [PortableTag('language', 'english')],
        );
        await _workFinished(service, repo, revisionWork);
        final revised = (await service.listCloudEntries()).first;
        expect(revised.title, 'Corrected title');
        expect(revised.manifestId, isNot(base.manifestId));
        expect(revised.manifest.supersedes, contains(base.manifestId));
        expect(
          revised.manifest.lineage.map(
            (edge) => [edge.fromGid, edge.toGid, edge.kind],
          ),
          [
            [2501, 2503, 'upgrade'],
          ],
        );
        expect(
          (jsonDecode(revised.manifest.toPortableJson()) as Map)['pages'],
          (jsonDecode(base.manifest.toPortableJson()) as Map)['pages'],
        );
        expect(revised.manifest.tags.single.namespace, 'language');
        expect(revised.manifest.tags.single.name, 'english');
        expect(server.pagePuts, initialPuts);
        expect(
          server.requests
              .skip(revisionStart)
              .where((request) => request.path.contains('/objects/')),
          isEmpty,
        );
        expect(
          server.requests
              .skip(revisionStart)
              .where((request) => request.method == 'PUT'),
          hasLength(1),
        );
      } finally {
        service.dispose();
        await server.server.close(force: true);
        await appDb.close();
        await home.delete(recursive: true);
      }
    },
  );

  test(
    'book pages share eight slots and the next book fills only the tail',
    () async {
      await _withAutomaticFixture((home, server, repo, service) async {
        final firstCopy = await _multiPageCopy(home, 2611, 16);
        final skippedCopy = await _multiPageCopy(home, 2612, 2);
        final secondCopy = await _multiPageCopy(home, 2613, 16);
        final thirdCopy = await _multiPageCopy(home, 2614, 2);
        final firstPages = await repo.listPages(firstCopy);
        final secondPages = await repo.listPages(secondCopy);
        final tailGate = Completer<void>();
        final secondGate = Completer<void>();
        server.objectPutGates[firstPages.last.rawHash!] = tailGate;
        for (final page in secondPages) {
          server.objectPutGates[page.rawHash!] = secondGate;
        }
        server.holdPagePuts = true;
        final first = await service.requestUpload(firstCopy);
        await server.pagePutsStarted.future.timeout(
          const Duration(seconds: 10),
        );
        final skipped = await service.requestUpload(skippedCopy);
        final second = await service.requestUpload(secondCopy);
        final third = await service.requestUpload(thirdCopy);
        expect(server.activePuts, 8);
        expect(
          server.requests.where((request) => request.method == 'PUT'),
          everyElement(
            predicate<_DavRequest>(
              (request) => request.path.contains('/$first/'),
            ),
          ),
        );
        // A stopped queued book settles immediately, without bypassing the book
        // that still owns the head of the queue.
        await service.pause(skipped).timeout(const Duration(seconds: 1));
        expect(
          server.requests.where(
            (request) => request.path.contains('/$second/'),
          ),
          isEmpty,
        );
        server.pagePutGate.complete();
        await _waitUntil(
          () async =>
              server.requests.any(
                (request) =>
                    request.method == 'PUT' &&
                    request.path.endsWith('/${firstPages.last.rawHash}'),
              ) &&
              server.requests.any(
                (request) =>
                    request.method == 'PUT' &&
                    request.path.contains('/$second/'),
              ),
        );
        expect(
          server.requests.where(
            (request) =>
                request.method == 'PUT' && request.path.contains('/$first/'),
          ),
          hasLength(16),
        );
        expect(
          server.requests.where((request) => request.path.contains('/$third/')),
          isEmpty,
        );
        tailGate.complete();
        // Publication retains the finishing page's slot while the next book's
        // first PUT remains held. It does not wait for that whole book.
        await _workFinished(service, repo, first);
        expect((await repo.getWorkItem(second))!.state, isNot('completed'));
        expect(
          server.requests.where((request) => request.path.contains('/$third/')),
          isEmpty,
        );
        secondGate.complete();
        await Future.wait([
          _workFinished(service, repo, second),
          _workFinished(service, repo, third),
        ]);
        expect(server.maxActivePuts, 8);
        expect((await repo.getWorkItem(skipped))!.state, 'paused');
      });
    },
  );

  test(
    'a failed page drains all active pages before starting another book',
    () async {
      await _withAutomaticFixture((home, server, repo, service) async {
        final firstCopy = await _multiPageCopy(home, 2621, 16);
        final secondCopy = await _multiPageCopy(home, 2622, 16);
        final thirdCopy = await _multiPageCopy(home, 2623, 2);
        final secondGate = Completer<void>();
        for (final page in await repo.listPages(secondCopy)) {
          server.objectPutGates[page.rawHash!] = secondGate;
        }
        final firstPages = await repo.listPages(firstCopy);
        final held = Completer<void>();
        for (final page in firstPages.take(8)) {
          server.objectPutGates[page.rawHash!] = held;
        }
        server.objectPutFailures[firstPages[1].rawHash!] = 503;
        final first = await service.requestUpload(firstCopy);
        final second = await service.requestUpload(secondCopy);
        await _waitUntil(
          () async => server.requests.any(
            (request) =>
                request.method == 'PUT' &&
                request.path.endsWith('/${firstPages[1].rawHash}'),
          ),
        );
        expect((await repo.getWorkItem(first))!.state, isNot('failed'));
        expect(
          server.requests.where(
            (request) => request.path.contains('/$second/'),
          ),
          isEmpty,
        );
        held.complete();
        await _waitUntil(
          () async => (await repo.getWorkItem(first))!.state == 'failed',
        );
        final failed = (await repo.getWorkItem(first))!;
        expect(
          jsonDecode(failed.committedObjectsJson),
          contains(firstPages.first.rawHash),
        );
        expect(
          server.requests.where(
            (request) =>
                request.method == 'PUT' && request.path.contains('/$first/'),
          ),
          hasLength(8),
        );
        await _waitUntil(
          () async =>
              server.requests
                  .where(
                    (request) =>
                        request.method == 'PUT' &&
                        request.path.contains('/$second/'),
                  )
                  .length ==
              8,
        );
        final third = await service.requestUpload(thirdCopy);
        server.objectPutFailures.clear();
        final putsBeforeRetry = server.requests
            .where(
              (request) =>
                  request.method == 'PUT' &&
                  request.path.endsWith('/${firstPages.first.rawHash}'),
            )
            .length;
        await service.resume(first);
        final resumedAt = server.requests.length;
        secondGate.complete();
        await Future.wait([
          _workFinished(service, repo, first),
          _workFinished(service, repo, second),
          _workFinished(service, repo, third),
        ]);
        final followingPuts = server.requests
            .skip(resumedAt)
            .where(
              (request) =>
                  request.method == 'PUT' &&
                  (request.path.contains('/$first/') ||
                      request.path.contains('/$third/')),
            );
        expect(followingPuts.first.path, contains('/$first/'));
        expect(
          server.requests.where(
            (request) =>
                request.method == 'PUT' &&
                request.path.endsWith('/${firstPages.first.rawHash}'),
          ),
          hasLength(putsBeforeRetry),
        );
      });
    },
  );

  test(
    'retry of a prepared first page precedes untouched queued books',
    () async {
      await _withAutomaticFixture((home, server, repo, service) async {
        final interruptedCopy = await _multiPageCopy(home, 2624, 1);
        final hash = (await repo.listPages(interruptedCopy)).single.rawHash!;
        server.objectPutFailures[hash] = 503;
        final interrupted = await service.requestUpload(interruptedCopy);
        await _waitUntil(
          () async => (await repo.getWorkItem(interrupted))!.state == 'failed',
        );
        final failed = (await repo.getWorkItem(interrupted))!;
        expect(jsonDecode(failed.committedObjectsJson), isEmpty);
        expect(jsonDecode(failed.artifactsJson), contains('0'));
        server.objectPutFailures.clear();
        final headCopy = await _multiPageCopy(home, 2625, 16);
        final untouchedCopy = await _multiPageCopy(home, 2626, 2);
        final headGate = Completer<void>();
        for (final page in await repo.listPages(headCopy)) {
          server.objectPutGates[page.rawHash!] = headGate;
        }
        final head = await service.requestUpload(headCopy);
        await _waitUntil(
          () async =>
              server.requests
                  .where(
                    (request) =>
                        request.method == 'PUT' &&
                        request.path.contains('/$head/'),
                  )
                  .length ==
              8,
        );
        final untouched = await service.requestUpload(untouchedCopy);
        await service.resume(interrupted);
        final resumeAt = server.requests.length;
        headGate.complete();
        await Future.wait([
          _workFinished(service, repo, head),
          _workFinished(service, repo, interrupted),
          _workFinished(service, repo, untouched),
        ]);
        final followingPuts = server.requests
            .skip(resumeAt)
            .where(
              (request) =>
                  request.method == 'PUT' &&
                  (request.path.contains('/$interrupted/') ||
                      request.path.contains('/$untouched/')),
            );
        expect(followingPuts.first.path, contains('/$interrupted/'));
      });
    },
  );

  test(
    'parallel duplicate pages share one object and retain ordinal metadata',
    () async {
      await _withAutomaticFixture((home, server, repo, service) async {
        final root = Directory('${home.path}/duplicate-pages');
        await root.create();
        final copy = await localContentService.ensureCopy(
          gid: 2631,
          representation: 'original',
          rootPath: root.path,
        );
        for (var ordinal = 0; ordinal < 2; ordinal++) {
          final name = '$ordinal.webp';
          await File('native/tests/fixtures/passthrough.webp')
              .copy('${root.path}/$name');
          await localContentService.recordPage(
            copyId: copy,
            ordinal: ordinal,
            relativePath: name,
            mime: 'image/webp',
            width: 100 + ordinal,
            height: 200 + ordinal,
            sourcePageUrl: 'https://e-hentai.org/s/page$ordinal/2631-$ordinal',
          );
        }
        await localContentService.completeCopy(
          copy,
          galleryUrl: 'https://e-hentai.org/g/2631/0123456789/',
          title: 'Repeated pages',
          expectedPages: 2,
        );
        final hash = (await repo.listPages(copy)).first.rawHash!;
        final work = await service.requestUpload(copy);
        await _workFinished(service, repo, work);
        expect(
          server.requests.where(
            (request) =>
                request.method == 'PUT' && request.path.endsWith('/$hash'),
          ),
          hasLength(1),
        );
        final pages = (await service.listCloudEntries()).single.manifest.pages;
        expect(pages.map((page) => page.objectHash).toSet(), hasLength(1));
        expect(pages.map((page) => page.width), [100, 101]);
        expect(pages.map((page) => page.height), [200, 201]);
        expect(pages.map((page) => page.sourcePageUrl), [
          'https://e-hentai.org/s/page0/2631-0',
          'https://e-hentai.org/s/page1/2631-1',
        ]);
        final completed = (await repo.getWorkItem(work))!;
        expect(
          (jsonDecode(completed.artifactsJson) as Map)['_completedOrdinals'],
          [0, 1],
        );
      });
    },
  );

  test(
    'real native uploads observe eight transfers and eight temporary artifacts',
    () async {
      final home = await Directory.systemTemp.createTemp('gallery-slots-test-');
      final server = await _DavServer.start();
      pathService.appDocDir = home;
      pathService.appSupportDir = home;
      pathService.tempDir = home;
      appDb = AppDb();
      final repo = ContentRepository(appDb);
      localContentService = LocalContentService(repository: repo);
      final service = GallerySyncService(repository: repo);
      try {
        await _configureServer(server);
        await service.doInitBean();
        server.artifactRoot = home;
        server.holdPagePuts = true;
        final copies = <String>[];
        for (var i = 0; i < 9; i++) {
          copies.add(
            await _fixtureCopy(
              home,
              2601 + i,
              i == 0 ? 'gradient.png' : 'gradient.jpg',
              jpegComment: i == 0 ? null : 'upload-$i',
            ),
          );
        }
        final work = <String>[];
        for (final copy in copies.take(8)) {
          work.add(await service.requestUpload(copy));
        }
        await server.pagePutsStarted.future.timeout(
          const Duration(seconds: 10),
        );
        final ninth = await service.requestUpload(copies.last);
        work.add(ninth);
        expect(server.activePuts, 8);
        expect(await server.countArtifacts(), 8);
        // The ninth job waits for a page slot before preparing its directories.
        expect(
          server.requests.where((request) => request.path.contains('/$ninth/')),
          isEmpty,
        );
        // Artifact peaks are sampled at HTTP requests throughout this real run.
        server.pagePutGate.complete();
        await Future.wait(work.map((id) => _workFinished(service, repo, id)));
        // Concurrent publications can PUT the same rendered cover. Compare
        // committed objects rather than assuming those PUTs run sequentially.
        expect(
          server.files.keys.where((path) => path.contains('/objects/')),
          hasLength(11),
        ); // Nine distinct pages, two distinct rendered covers.
        expect(server.maxActivePuts, 8);
        expect(server.maxArtifacts, 8);
        expect(await server.countArtifacts(), 0);
        final entries = await service.listCloudEntries();
        expect(
          entries.where(
            (entry) =>
                entry.manifest.pages.single.codecProfile ==
                ContentCodec.encodedProfile,
          ),
          hasLength(9),
        );
      } finally {
        if (!server.pagePutGate.isCompleted) {
          server.pagePutGate.complete();
        }
        service.dispose();
        await ContentCodec().close();
        await server.server.close(force: true);
        await appDb.close();
        await home.delete(recursive: true);
      }
    },
  );

  test(
    'paused upload waiting for a page slot never prepares remote directories',
    () async {
      await _withAutomaticFixture((home, server, repo, service) async {
        final copies = <String>[];
        for (var i = 0; i < 9; i++) {
          copies.add(
            await _fixtureCopy(
              home,
              9900 + i,
              'gradient.jpg',
              jpegComment: 'paused-$i',
            ),
          );
        }
        server.holdPagePuts = true;
        final active = <String>[];
        for (final copy in copies.take(8)) {
          active.add(await service.requestUpload(copy));
        }
        await server.pagePutsStarted.future.timeout(
          const Duration(seconds: 10),
        );
        final ninth = await service.requestUpload(copies[8]);
        final pausing = service.pause(ninth);
        await pausing.timeout(const Duration(seconds: 1));
        await _waitUntil(
          () async => (await repo.getWorkItem(ninth))!.state == 'paused',
        );
        expect(server.activePuts, 8);
        server.pagePutGate.complete();
        await pausing;
        await Future.wait([
          ...active.map((id) => _workFinished(service, repo, id)),
        ]);
        expect((await repo.getWorkItem(ninth))!.state, 'paused');
        expect(
          server.requests.where(
            (request) =>
                request.method == 'MKCOL' &&
                request.path.contains('/staging/$ninth/'),
          ),
          isEmpty,
        );
        expect(
          server.directories.where(
            (directory) => directory.contains('/staging/$ninth/'),
          ),
          isEmpty,
        );
        expect(server.maxActivePuts, 8);
      });
    },
  );

  test('restart binds a completed waiting input and launches it now', () async {
    final home = await Directory.systemTemp.createTemp('gallery-wait-test-');
    final server = await _DavServer.start();
    pathService.appDocDir = home;
    pathService.appSupportDir = home;
    pathService.tempDir = home;
    appDb = AppDb();
    final repo = ContentRepository(appDb);
    localContentService = LocalContentService(repository: repo);
    final service = GallerySyncService(repository: repo);
    try {
      await webDavSetting.save(
        address: 'http://localhost:${server.server.port}/v1/dav/sync/',
        username: 'test',
        password: 'test',
        rootPath: '',
      );
      await service.doInitBean();
      final root = Directory('${home.path}/copy');
      await root.create(recursive: true);
      await File('${root.path}/0001.webp').writeAsBytes(List.filled(128, 9));
      final copyId = await localContentService.ensureCopy(
        gid: 2301,
        representation: 'original',
        rootPath: root.path,
      );
      await localContentService.recordPage(
        copyId: copyId,
        ordinal: 0,
        relativePath: '0001.webp',
        mime: 'image/webp',
      );
      await localContentService.completeCopy(
        copyId,
        galleryUrl: 'https://e-hentai.org/g/2301/token/',
        title: 'Waiting input',
        expectedPages: 1,
      );
      final work = await repo.createWorkItem(
        kind: 'content',
        targetNamespace: webDavSetting.connection.namespace,
        copyId: copyId,
        inputJson: jsonEncode({'copyId': copyId}),
      );
      await repo.updateWorkItemState(work.workItemId, 'waiting_input');
      await service.resumePending();
      await _waitUntil(
        () async =>
            (await repo.getWorkItem(work.workItemId))?.state == 'completed',
      );
      expect(server.moves, 2);
    } finally {
      await server.server.close(force: true);
      await appDb.close();
      await home.delete(recursive: true);
    }
  });

  test('an upload supersedes only its frozen equivalent base heads', () async {
    final home = await Directory.systemTemp.createTemp('gallery-heads-test-');
    final server = await _DavServer.start();
    pathService.appDocDir = home;
    pathService.appSupportDir = home;
    pathService.tempDir = home;
    appDb = AppDb();
    final repo = ContentRepository(appDb);
    localContentService = LocalContentService(repository: repo);
    final service = GallerySyncService(repository: repo);
    try {
      await webDavSetting.save(
        address: 'http://localhost:${server.server.port}/v1/dav/sync/',
        username: 'test',
        password: 'test',
        rootPath: '',
      );
      await service.doInitBean();
      final namespace = webDavSetting.connection.namespace;
      final oldHash = sha256.convert(List.filled(32, 5)).toString();
      final encodedHash = sha256.convert(List.filled(16, 6)).toString();
      final rawPage = PortablePage(
        rawHash: oldHash,
        rawLength: 32,
        objectHash: oldHash,
        storedLength: 32,
        codecProfile: 'raw',
        mime: 'image/webp',
      );
      final encodedPage = PortablePage(
        rawHash: oldHash,
        rawLength: 32,
        objectHash: encodedHash,
        storedLength: 16,
        codecProfile: ContentCodec.encodedProfile,
        mime: 'image/webp',
      );
      PortableManifest manifest(String title, PortablePage page) =>
          PortableManifest(
            gid: 2302,
            representation: 'original',
            galleryUrl: 'https://e-hentai.org/g/2302/token/',
            title: title,
            tags: const [],
            pages: [page],
            codecProfiles: page.codecProfile == 'raw'
                ? const {}
                : {
                    ContentCodec.encodedProfile: ContentCodec
                        .profileDefinitions[ContentCodec.encodedProfile]!
                        .cast<String, Object?>(),
                  },
          );
      final artifactDir = Directory('${home.path}/manifests');
      await artifactDir.create();
      Future<String> seed(String name, PortableManifest value) async {
        final artifact = PortableManifestCodec.write(
          File('${artifactDir.path}/$name.sqlite'),
          value,
        );
        await repo.importManifest(namespace, artifact);
        await repo.recordRemoteResource(
          targetNamespace: namespace,
          href:
              'manifests/${artifact.manifestId.substring(0, 2)}/${artifact.manifestId}.sqlite',
          kind: 'manifest',
          objectHash: artifact.manifestId,
          partition: artifact.manifestId.substring(0, 2),
        );
        return artifact.manifestId;
      }

      final a = await seed('a', manifest('Base', rawPage));
      final b = await seed('b', manifest('Base', encodedPage));
      final other = await seed('other', manifest('Other branch', rawPage));
      final root = Directory('${home.path}/copy');
      await root.create();
      await File('${root.path}/0001.webp').writeAsBytes(List.filled(64, 7));
      final copyId = await localContentService.ensureCopy(
        gid: 2302,
        representation: 'original',
        rootPath: root.path,
      );
      await localContentService.recordPage(
        copyId: copyId,
        ordinal: 0,
        relativePath: '0001.webp',
        mime: 'image/webp',
      );
      await localContentService.completeCopy(
        copyId,
        galleryUrl: 'https://e-hentai.org/g/2302/token/',
        title: 'Changed',
        expectedPages: 1,
      );
      final previous = await repo.createWorkItem(
        kind: 'content',
        targetNamespace: namespace,
        copyId: copyId,
        inputJson: '{}',
      );
      await repo.updateContentWorkProgress(
        workItemId: previous.workItemId,
        state: 'running',
        artifactsJson: '{}',
        committedObjectsJson: '[]',
        pendingManifestId: a,
      );
      await repo.updateWorkItemState(previous.workItemId, 'completed');
      final workId = await service.requestUpload(copyId);
      final frozen = jsonDecode(
        (await repo.getWorkItem(workId))!.inputJson,
      ) as Map<String, dynamic>;
      expect((frozen['supersedes'] as List).toSet(), {a, b});
      await _waitUntil(
        () async => (await repo.getWorkItem(workId))?.state == 'completed',
      );
      final currentId = (await repo.getWorkItem(workId))!.pendingManifestId!;
      final current = await appDb
          .customSelect(
            'SELECT portable_json FROM content_manifest WHERE target_namespace = ? AND manifest_id = ?',
            variables: [
              Variable.withString(namespace),
              Variable.withString(currentId),
            ],
          )
          .get();
      final published = PortableManifest.fromPortableJson(
        current.single.read<String>('portable_json'),
      );
      expect(published.supersedes.toSet(), {a, b});
      final heads = await repo.listManifestHeads(namespace, 2302, 'original');
      expect(heads.expand((group) => group.manifestIds).toSet(), {
        currentId,
        other,
      });
      final revision = await repo.createWorkItem(
        kind: 'revision',
        targetNamespace: namespace,
        inputManifestId: a,
        inputJson: jsonEncode({'manifestId': a}),
        localArtifactPath: '${artifactDir.path}/a.sqlite',
        remoteDestination: 'manifests/${a.substring(0, 2)}/$a.sqlite',
      );
      server.putFailureStatus = 409;
      await service.resume(revision.workItemId);
      await _waitUntil(
        () async =>
            (await repo.getWorkItem(revision.workItemId))?.state == 'failed',
      );
      final revisionJob = (await service.listSyncJobs()).singleWhere(
        (job) => job.workItemId == revision.workItemId,
      );
      expect(revisionJob.kind, 'revision');
      expect(revisionJob.title, 'Base');
      expect(revisionJob.state, 'failed');
      expect(revisionJob.error?.kind, 'conflict');
      expect(revisionJob.error?.statusCode, 409);
      expect(service.lastError, isNull);
      server.putFailureStatus = null;
      await service.resume(revision.workItemId);
      await _waitUntil(
        () async =>
            (await repo.getWorkItem(revision.workItemId))?.state == 'completed',
      );
    } finally {
      await server.server.close(force: true);
      await appDb.close();
      await home.delete(recursive: true);
    }
  });

  test('a committed resource imports after discovery GET is interrupted', () async {
    final home = await Directory.systemTemp.createTemp('gallery-import-test-');
    final server = await _DavServer.start();
    pathService.appDocDir = home;
    pathService.appSupportDir = home;
    pathService.tempDir = home;
    appDb = AppDb();
    final repo = ContentRepository(appDb);
    localContentService = LocalContentService(repository: repo);
    final service = GallerySyncService(repository: repo);
    try {
      await webDavSetting.save(
        address: 'http://localhost:${server.server.port}/v1/dav/sync/',
        username: 'test',
        password: 'test',
        rootPath: '',
      );
      await service.doInitBean();
      final hash = sha256.convert(List.filled(16, 3)).toString();
      final artifact = PortableManifestCodec.write(
        File('${home.path}/remote.sqlite'),
        PortableManifest(
          gid: 2303,
          representation: 'unspecified',
          galleryUrl: 'https://e-hentai.org/g/2303/token/',
          title: 'Remote only',
          tags: const [],
          pages: [
            PortablePage(
              rawHash: hash,
              rawLength: 16,
              objectHash: hash,
              storedLength: 16,
              codecProfile: 'raw',
              mime: 'image/webp',
            ),
          ],
        ),
      );
      final partition = artifact.manifestId.substring(0, 2);
      final remotePath =
          '/v1/dav/sync/hclient-v1/manifests/$partition/${artifact.manifestId}.sqlite';
      server.directories.addAll({
        '/v1/dav/sync/hclient-v1/manifests/',
        '/v1/dav/sync/hclient-v1/manifests/$partition/',
      });
      server.files[remotePath] = await artifact.file.readAsBytes();
      server.holdManifestGet = true;
      final interrupted = service.refresh();
      await server.manifestGetStarted.future.timeout(
        const Duration(seconds: 3),
      );
      final namespace = webDavSetting.connection.namespace;
      expect(
        await appDb
            .customSelect(
              'SELECT 1 FROM content_remote_resource WHERE target_namespace = ? AND object_hash = ?',
              variables: [
                Variable.withString(namespace),
                Variable.withString(artifact.manifestId),
              ],
            )
            .get(),
        hasLength(1),
      );
      expect(
        await appDb
            .customSelect(
              'SELECT 1 FROM content_manifest WHERE target_namespace = ? AND manifest_id = ?',
              variables: [
                Variable.withString(namespace),
                Variable.withString(artifact.manifestId),
              ],
            )
            .get(),
        isEmpty,
      );
      await webDavSetting.save(
        address: 'http://localhost:${server.server.port}/v1/dav/sync/',
        username: 'test',
        password: 'test',
        rootPath: 'new-target',
      );
      await service.targetChanged().timeout(const Duration(seconds: 3));
      await interrupted.timeout(const Duration(seconds: 3));
      server.holdManifestGet = false;
      server.manifestGetGate.complete();
      await webDavSetting.save(
        address: 'http://localhost:${server.server.port}/v1/dav/sync/',
        username: 'test',
        password: 'test',
        rootPath: '',
      );
      final restarted = GallerySyncService(repository: repo);
      await restarted.doInitBean();
      await restarted.ensureInitialDiscovery();
      final entries = await restarted.listCloudEntries();
      expect(entries, hasLength(1));
      expect(entries.single.title, 'Remote only');
    } finally {
      if (!server.manifestGetGate.isCompleted)
        server.manifestGetGate.complete();
      await server.server.close(force: true);
      await appDb.close();
      await home.delete(recursive: true);
    }
  });

  test('discovery rejects a manifest whose bytes differ from its remote id', () async {
    final home = await Directory.systemTemp.createTemp('gallery-hash-test-');
    final server = await _DavServer.start();
    pathService.appDocDir = home;
    pathService.appSupportDir = home;
    pathService.tempDir = home;
    appDb = AppDb();
    final repo = ContentRepository(appDb);
    localContentService = LocalContentService(repository: repo);
    final service = GallerySyncService(repository: repo);
    try {
      await webDavSetting.save(
        address: 'http://localhost:${server.server.port}/v1/dav/sync/',
        username: 'test',
        password: 'test',
        rootPath: '',
      );
      await service.doInitBean();
      final pageHash = sha256.convert(List.filled(16, 3)).toString();
      final artifact = PortableManifestCodec.write(
        File('${home.path}/actual.sqlite'),
        PortableManifest(
          gid: 2304,
          representation: 'unspecified',
          galleryUrl: 'https://e-hentai.org/g/2304/token/',
          title: 'Other bytes',
          tags: const [],
          pages: [
            PortablePage(
              rawHash: pageHash,
              rawLength: 16,
              objectHash: pageHash,
              storedLength: 16,
              codecProfile: 'raw',
              mime: 'image/webp',
            ),
          ],
        ),
      );
      final wrongId = sha256.convert(List.filled(16, 4)).toString();
      final partition = wrongId.substring(0, 2);
      server.directories.addAll({
        '/v1/dav/sync/hclient-v1/manifests/',
        '/v1/dav/sync/hclient-v1/manifests/$partition/',
      });
      server.files['/v1/dav/sync/hclient-v1/manifests/$partition/$wrongId.sqlite'] =
          await artifact.file.readAsBytes();
      await expectLater(service.refresh(), throwsA(isA<FormatException>()));
      expect(service.lastError, isNotNull);
      expect(service.lastError, isNotEmpty);
      final namespace = webDavSetting.connection.namespace;
      expect(
        await appDb
            .customSelect(
              'SELECT 1 FROM content_manifest WHERE target_namespace = ?',
              variables: [Variable.withString(namespace)],
            )
            .get(),
        isEmpty,
      );
      expect(
        await File(
          '${home.path}/gallery-sync-artifacts/discovery/$wrongId.sqlite',
        ).exists(),
        isFalse,
      );
      server.files.remove(
        '/v1/dav/sync/hclient-v1/manifests/$partition/$wrongId.sqlite',
      );
      final correctPartition = artifact.manifestId.substring(0, 2);
      server.directories.add(
        '/v1/dav/sync/hclient-v1/manifests/$correctPartition/',
      );
      server.files['/v1/dav/sync/hclient-v1/manifests/$correctPartition/${artifact.manifestId}.sqlite'] =
          await artifact.file.readAsBytes();
      await service.refresh();
      expect(service.lastError, isNull);
      expect((await service.listCloudEntries()).single.title, 'Other bytes');
    } finally {
      await server.server.close(force: true);
      await appDb.close();
      await home.delete(recursive: true);
    }
  });

  test('target switch joins an old discovery scan', () async {
    final home = await Directory.systemTemp.createTemp('gallery-scan-test-');
    final server = await _DavServer.start();
    pathService.appDocDir = home;
    pathService.appSupportDir = home;
    pathService.tempDir = home;
    appDb = AppDb();
    localContentService = LocalContentService(
      repository: ContentRepository(appDb),
    );
    final service = GallerySyncService(repository: ContentRepository(appDb));
    try {
      await webDavSetting.save(
        address: 'http://localhost:${server.server.port}/v1/dav/sync/',
        username: 'test',
        password: 'test',
        rootPath: '',
      );
      await service.doInitBean();
      final oldNamespace = webDavSetting.connection.namespace;
      server.holdManifestListing = true;
      final oldScan = service.refresh();
      await server.listStarted.future.timeout(const Duration(seconds: 3));
      await webDavSetting.save(
        address: 'http://localhost:${server.server.port}/v1/dav/sync/',
        username: 'test',
        password: 'test',
        rootPath: 'new-target',
      );
      await service.targetChanged().timeout(const Duration(seconds: 3));
      await oldScan.timeout(const Duration(seconds: 3));
      final oldRoot = await appDb
          .customSelect(
            "SELECT scan_state FROM content_remote_partition WHERE target_namespace = ? AND partition = '__root__'",
            variables: [Variable.withString(oldNamespace)],
          )
          .get();
      expect(oldRoot, isEmpty);
    } finally {
      if (!server.listGate.isCompleted) server.listGate.complete();
      await server.server.close(force: true);
      await appDb.close();
      await home.delete(recursive: true);
    }
  });

  test('target switch joins an old PUT and pauses its work', () async {
    final home = await Directory.systemTemp.createTemp('gallery-switch-test-');
    final server = await _DavServer.start();
    pathService.appDocDir = home;
    pathService.appSupportDir = home;
    pathService.tempDir = home;
    appDb = AppDb();
    localContentService = LocalContentService(
      repository: ContentRepository(appDb),
    );
    final service = GallerySyncService(repository: ContentRepository(appDb));
    try {
      await downloadSetting.doInitBean();
      await webDavSetting.save(
        address: 'http://localhost:${server.server.port}/v1/dav/sync/',
        username: 'test',
        password: 'test',
        rootPath: '',
      );
      await service.doInitBean();
      final root = Directory('${home.path}/copy');
      await root.create(recursive: true);
      await File('${root.path}/0001.webp')
          .writeAsBytes(List<int>.filled(2048, 61));
      final copyId = await localContentService.ensureCopy(
        gid: 3333,
        representation: 'original',
        rootPath: root.path,
      );
      await localContentService.recordPage(
        copyId: copyId,
        ordinal: 0,
        relativePath: '0001.webp',
        mime: 'image/webp',
      );
      await localContentService.completeCopy(
        copyId,
        galleryUrl: 'https://e-hentai.org/g/3333/token/',
        title: 'Switch sample',
        expectedPages: 1,
      );
      server.holdObjectPut = true;
      final oldNamespace = webDavSetting.connection.namespace;
      final workId = await service.requestUpload(copyId);
      await server.putStarted.future.timeout(const Duration(seconds: 3));
      await webDavSetting.save(
        address: 'http://localhost:${server.server.port}/v1/dav/sync/',
        username: 'test',
        password: 'test',
        rootPath: 'new-target',
      );
      await service.targetChanged().timeout(const Duration(seconds: 3));
      expect(webDavSetting.connection.namespace, isNot(oldNamespace));
      expect(
        (await ContentRepository(appDb).getWorkItem(workId))!.state,
        'paused',
      );
      expect(server.moves, 0);
    } finally {
      if (!server.putGate.isCompleted) server.putGate.complete();
      await server.server.close(force: true);
      await appDb.close();
      await home.delete(recursive: true);
    }
  });

  test(
    'copy move settles raw PUT and restore GET then resumes at owner root',
    () async {
      final home = await Directory.systemTemp.createTemp('gallery-move-test-');
      final server = await _DavServer.start();
      pathService.appDocDir = home;
      pathService.appSupportDir = home;
      pathService.tempDir = home;
      appDb = AppDb();
      final repo = ContentRepository(appDb);
      localContentService = LocalContentService(repository: repo);
      final service = GallerySyncService(repository: repo);
      try {
        await downloadSetting.doInitBean();
        downloadSetting.downloadPath.value = '${home.path}/downloads';
        await _configureServer(server);
        await service.doInitBean();
        localContentService.onBeforeRelocation = (copyId) async {
          await service.prepareCopyRelocation(copyId);
          if (server.putStarted.isCompleted && !server.putGate.isCompleted) {
            server.holdObjectPut = false;
            server.putGate.complete();
          }
          if (server.getStarted.isCompleted && !server.getGate.isCompleted) {
            server.holdObjectGet = false;
            server.getGate.complete();
          }
        };
        localContentService.onAfterRelocation = service.finishCopyRelocation;
        final bytes = List<int>.generate(4096, (index) => index % 251);
        final source = Directory('${home.path}/old/copy');
        await source.create(recursive: true);
        await File('${source.path}/0001.webp').writeAsBytes(bytes);
        final copyId = await localContentService.ensureCopy(
          gid: 8123,
          representation: 'original',
          rootPath: source.path,
        );
        await localContentService.recordPage(
          copyId: copyId,
          ordinal: 0,
          relativePath: '0001.webp',
          mime: 'image/webp',
        );
        await localContentService.completeCopy(
          copyId,
          galleryUrl: 'https://e-hentai.org/g/8123/token/',
          title: 'Move sample',
          expectedPages: 1,
        );
        server.holdObjectPut = true;
        final uploadId = await service.requestUpload(copyId);
        await server.putStarted.future.timeout(const Duration(seconds: 3));
        await localContentService
            .relocateCopy(copyId, '${home.path}/new')
            .timeout(const Duration(seconds: 5));
        await _workFinished(service, repo, uploadId);
        final movedRoot = await localContentService.rootPath(copyId);
        expect(movedRoot, '${home.path}/new/copy');
        expect(await source.exists(), false);
        expect(await File('$movedRoot/0001.webp').readAsBytes(), bytes);
        expect((await repo.getWorkItem(uploadId))!.state, 'completed');
        final heads = await repo.listManifestHeads(
          webDavSetting.connection.namespace,
          8123,
          'original',
        );
        expect(heads, hasLength(1));

        await localContentService.retireCopy(copyId);
        server.holdObjectGet = true;
        final restoring = service.restore(heads.single.manifestIds.single);
        await server.getStarted.future.timeout(const Duration(seconds: 3));
        final restoreWork = (await repo.listWorkItems(kind: 'restore')).single;
        final restoredId = restoreWork.copyId!;
        await localContentService
            .relocateCopy(restoredId, '${home.path}/restored-new')
            .timeout(const Duration(seconds: 5));
        await restoring.timeout(const Duration(seconds: 5));
        await _workFinished(service, repo, restoreWork.workItemId);
        final restoredRoot = await localContentService.rootPath(restoredId);
        expect(
          restoredRoot,
          '${home.path}/restored-new/cloud-8123-$restoredId',
        );
        expect(await File('$restoredRoot/0001.webp').readAsBytes(), bytes);
        expect(
          (await repo.getWorkItem(restoreWork.workItemId))!.state,
          'completed',
        );
      } finally {
        if (!server.putGate.isCompleted) server.putGate.complete();
        if (!server.getGate.isCompleted) server.getGate.complete();
        service.dispose();
        await server.server.close(force: true);
        await appDb.close();
        await home.delete(recursive: true);
      }
    },
  );

  test('owner rollover cancels an already-journaled PUT and preserves its waiting successor', () async {
    final home = await Directory.systemTemp.createTemp(
      'gallery-rollover-test-',
    );
    final server = await _DavServer.start();
    pathService.appDocDir = home;
    pathService.appSupportDir = home;
    pathService.tempDir = home;
    appDb = AppDb();
    localContentService = LocalContentService(
      repository: ContentRepository(appDb),
    );
    final service = GallerySyncService(repository: ContentRepository(appDb));
    try {
      await downloadSetting.doInitBean();
      await webDavSetting.save(
        address: 'http://localhost:${server.server.port}/v1/dav/sync/',
        username: 'test',
        password: 'test',
        rootPath: '',
      );
      await service.doInitBean();
      final root = Directory('${home.path}/original');
      await root.create(recursive: true);
      await File('${root.path}/0001.webp')
          .writeAsBytes(List<int>.filled(2048, 37));
      final copyId = await localContentService.ensureCopy(
        gid: 2024,
        representation: 'original',
        rootPath: root.path,
      );
      await localContentService.recordPage(
        copyId: copyId,
        ordinal: 0,
        relativePath: '0001.webp',
        mime: 'image/webp',
      );
      await localContentService.completeCopy(
        copyId,
        galleryUrl: 'https://e-hentai.org/g/2024/token/',
        title: 'Rollover sample',
        expectedPages: 1,
      );
      server.holdObjectPut = true;
      final oldId = await service.requestUpload(
        copyId,
        cleanupAfterUpload: true,
      );
      await server.putStarted.future.timeout(const Duration(seconds: 3));
      final repo = ContentRepository(appDb);
      await appDb.transaction(() async {
        await appDb.customStatement(
          "UPDATE content_work_item SET state = 'cancelled', finish_action = 'keep' WHERE work_item_id = ?",
          [oldId],
        );
        final successor = await repo.createWorkItem(
          kind: 'content',
          targetNamespace: webDavSetting.connection.namespace,
          copyId: copyId,
          inputJson: jsonEncode({'copyId': copyId}),
        );
        await repo.updateWorkItemState(successor.workItemId, 'waiting_input');
      });
      await service
          .onBeforeMutation(copyId)
          .timeout(const Duration(seconds: 3));
      final works = await repo.listWorkItems(
        kind: 'content',
        includeFinished: true,
      );
      expect(
        works.where((item) => item.workItemId == oldId).single.state,
        'cancelled',
      );
      expect(
        works.where((item) => item.workItemId != oldId).single.state,
        'waiting_input',
      );
      expect(server.moves, 0);
    } finally {
      if (!server.putGate.isCompleted) server.putGate.complete();
      await server.server.close(force: true);
      await appDb.close();
      await home.delete(recursive: true);
    }
  });

  test(
    'an in-flight manifest MOVE settles without reviving revoked cleanup',
    () async {
      final home = await Directory.systemTemp.createTemp('gallery-move-test-');
      final server = await _DavServer.start();
      pathService.appDocDir = home;
      pathService.appSupportDir = home;
      pathService.tempDir = home;
      appDb = AppDb();
      localContentService = LocalContentService(
        repository: ContentRepository(appDb),
      );
      final service = GallerySyncService(repository: ContentRepository(appDb));
      try {
        await downloadSetting.doInitBean();
        await webDavSetting.save(
          address: 'http://localhost:${server.server.port}/v1/dav/sync/',
          username: 'test',
          password: 'test',
          rootPath: '',
        );
        await service.doInitBean();
        final root = Directory('${home.path}/original');
        await root.create(recursive: true);
        await File('${root.path}/0001.webp')
            .writeAsBytes(List<int>.filled(2048, 39));
        final copyId = await localContentService.ensureCopy(
          gid: 2025,
          representation: 'original',
          rootPath: root.path,
        );
        await localContentService.recordPage(
          copyId: copyId,
          ordinal: 0,
          relativePath: '0001.webp',
          mime: 'image/webp',
        );
        await localContentService.completeCopy(
          copyId,
          galleryUrl: 'https://e-hentai.org/g/2025/token/',
          title: 'MOVE sample',
          expectedPages: 1,
        );
        server.holdManifestMove = true;
        final oldId = await service.requestUpload(
          copyId,
          cleanupAfterUpload: true,
        );
        await server.moveStarted.future.timeout(const Duration(seconds: 3));
        final repo = ContentRepository(appDb);
        await appDb.transaction(() async {
          await appDb.customStatement(
            "UPDATE content_work_item SET state = 'cancelled', finish_action = 'keep' WHERE work_item_id = ?",
            [oldId],
          );
          final successor = await repo.createWorkItem(
            kind: 'content',
            targetNamespace: webDavSetting.connection.namespace,
            copyId: copyId,
            inputJson: jsonEncode({'copyId': copyId}),
          );
          await repo.updateWorkItemState(successor.workItemId, 'waiting_input');
        });
        var joined = false;
        final stop = service
            .onBeforeMutation(copyId)
            .then((_) => joined = true);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(joined, false);
        server.moveGate.complete();
        await stop.timeout(const Duration(seconds: 3));
        expect((await repo.getWorkItem(oldId))!.state, 'cancelled');
        expect(await root.exists(), true);
        expect(
          await repo.listManifestHeads(
            webDavSetting.connection.namespace,
            2025,
            'original',
          ),
          hasLength(1),
        );
      } finally {
        if (!server.moveGate.isCompleted) server.moveGate.complete();
        await server.server.close(force: true);
        await appDb.close();
        await home.delete(recursive: true);
      }
    },
  );

  test('publishes after a lost MOVE response, discovers, and restores exact bytes', () async {
    final home = await Directory.systemTemp.createTemp('gallery-sync-test-');
    final server = await _DavServer.start();
    pathService.appDocDir = home;
    pathService.appSupportDir = home;
    pathService.tempDir = home;
    appDb = AppDb();
    localContentService = LocalContentService(
      repository: ContentRepository(appDb),
    );
    final service = GallerySyncService(repository: ContentRepository(appDb));
    final bytes = List<int>.generate(4000, (index) => (index * 37) % 256);
    final completionGate = Completer<void>();
    try {
      await downloadSetting.doInitBean();
      downloadSetting.downloadPath.value = '${home.path}/downloads';
      await webDavSetting.save(
        address: 'http://localhost:${server.server.port}/v1/dav/sync/',
        username: 'test',
        password: 'test',
        rootPath: '',
      );
      await service.doInitBean();
      final original = Directory('${home.path}/original');
      await original.create(recursive: true);
      await File('${original.path}/0001.webp').writeAsBytes(bytes);
      final copyId = await localContentService.ensureCopy(
        gid: 1024,
        representation: 'original',
        rootPath: original.path,
      );
      await localContentService.recordPage(
        copyId: copyId,
        ordinal: 0,
        relativePath: '0001.webp',
        mime: 'image/webp',
      );
      await localContentService.completeCopy(
        copyId,
        galleryUrl: 'https://e-hentai.org/g/1024/token/',
        title: 'Sync sample',
        expectedPages: 1,
      );
      server.loseNextMoveResponse = true;
      server.seedPartialStageHash = sha256.convert(bytes).toString();
      final workId = await service.requestUpload(copyId);
      await _waitUntil(
        () async =>
            (await ContentRepository(appDb).getWorkItem(workId))?.state ==
            'completed',
      );
      expect(server.moves, 2);
      // The object and manifest each have a staging PUT. The seeded
      // partial object stage must be overwritten with the full source.
      expect(server.objectPuts, 2);
      expect(
        server.files.values.where((data) => data.length == bytes.length),
        isNotEmpty,
      );
      final namespace = webDavSetting.connection.namespace;
      expect(
        await ContentRepository(appDb)
            .listManifestHeads(namespace, 1024, 'original'),
        hasLength(1),
      );
      final manifestId = (await ContentRepository(appDb).getWorkItem(workId))!
          .pendingManifestId!;
      final partition = manifestId.substring(0, 2);
      final staleHref =
          'manifests/$partition/$partition${List.filled(62, 'f').join()}.sqlite';
      final vanishedHref =
          'manifests/$partition/$partition${List.filled(62, 'e').join()}.sqlite';
      await ContentRepository(appDb).recordRemoteResource(
        targetNamespace: namespace,
        href: staleHref,
        kind: 'manifest',
        partition: partition,
      );
      await ContentRepository(appDb).recordRemoteResource(
        targetNamespace: namespace,
        href: vanishedHref,
        kind: 'manifest',
        partition: partition,
      );
      await appDb.customStatement('DELETE FROM content_manifest');
      await ContentRepository(appDb).commitPartitionScan(
        targetNamespace: namespace,
        partition: '__root__',
        scanState: 'complete',
        deletedHrefs: const [],
      );
      server.reportPartial = true;
      server.reportGhostManifestHref = vanishedHref;
      server.holdSecondReport = true;
      final interruptedScan = service.refresh();
      await server.secondReportStarted.future.timeout(
        const Duration(seconds: 3),
      );
      await webDavSetting.save(
        address: 'http://localhost:${server.server.port}/v1/dav/sync/',
        username: 'test',
        password: 'test',
        rootPath: 'new-target',
      );
      await service.targetChanged().timeout(const Duration(seconds: 3));
      await interruptedScan.timeout(const Duration(seconds: 3));
      server.holdSecondReport = false;
      server.secondReportGate.complete();
      await webDavSetting.save(
        address: 'http://localhost:${server.server.port}/v1/dav/sync/',
        username: 'test',
        password: 'test',
        rootPath: '',
      );
      await service.targetChanged().timeout(const Duration(seconds: 3));
      expect(server.reportCalls, 4);
      expect(
        await appDb
            .customSelect(
              'SELECT 1 FROM content_remote_resource WHERE target_namespace = ? AND href = ?',
              variables: [
                Variable.withString(namespace),
                Variable.withString(staleHref),
              ],
            )
            .get(),
        isEmpty,
      );
      expect(
        await appDb
            .customSelect(
              'SELECT 1 FROM content_remote_resource WHERE target_namespace = ? AND href = ?',
              variables: [
                Variable.withString(namespace),
                Variable.withString(vanishedHref),
              ],
            )
            .get(),
        isEmpty,
      );
      final entries = await service.listCloudEntries();
      expect(entries, hasLength(1));
      expect(entries.single.title, 'Sync sample');
      // Simulate a process stopping after completed was committed but
      // before the owner consumed its cleanup intent.
      await appDb.customStatement(
        "UPDATE content_work_item SET finish_action = 'release' WHERE work_item_id = ?",
        [workId],
      );
      final restarted = GallerySyncService(
        repository: ContentRepository(appDb),
      );
      await restarted.doInitBean();
      await restarted.resumePending();
      await _waitUntil(() async {
        final rows = await appDb
            .customSelect(
              'SELECT cleanup_state FROM content_copy WHERE copy_id = ?',
              variables: [Variable.withString(copyId)],
            )
            .get();
        return rows.single.readNullable<String>('cleanup_state') == 'completed';
      });
      expect(await original.exists(), false);
      server.holdObjectGet = true;
      final interruptedRestore = restarted.restore(entries.single.manifestId);
      await server.getStarted.future.timeout(const Duration(seconds: 3));
      await webDavSetting.save(
        address: 'http://localhost:${server.server.port}/v1/dav/sync/',
        username: 'test',
        password: 'test',
        rootPath: 'new-target',
      );
      await restarted.targetChanged().timeout(const Duration(seconds: 3));
      final pausedId = await interruptedRestore.timeout(
        const Duration(seconds: 3),
      );
      final paused = (await ContentRepository(
        appDb,
      ).listWorkItems(kind: 'restore', includeFinished: true)).single;
      expect(paused.state, 'paused');
      expect(await localContentService.completedInput(pausedId), isNull);
      server.holdObjectGet = false;
      server.getGate.complete();
      await webDavSetting.save(
        address: 'http://localhost:${server.server.port}/v1/dav/sync/',
        username: 'test',
        password: 'test',
        rootPath: '',
      );
      await restarted.targetChanged();
      final completionStarted = Completer<void>();
      final originalCallback = localContentService.onCompleted;
      localContentService.onCompleted = (input) async {
        if (!completionStarted.isCompleted) {
          completionStarted.complete();
          await completionGate.future;
        }
        await originalCallback?.call(input);
      };
      final completingRestore = restarted.restore(entries.single.manifestId);
      await completionStarted.future.timeout(const Duration(seconds: 3));
      await webDavSetting.save(
        address: 'http://localhost:${server.server.port}/v1/dav/sync/',
        username: 'test',
        password: 'test',
        rootPath: 'new-target',
      );
      final leavingDuringCompletion = restarted.targetChanged();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      completionGate.complete();
      await leavingDuringCompletion.timeout(const Duration(seconds: 3));
      final restoredId = await completingRestore.timeout(
        const Duration(seconds: 3),
      );
      localContentService.onCompleted = originalCallback;
      await webDavSetting.save(
        address: 'http://localhost:${server.server.port}/v1/dav/sync/',
        username: 'test',
        password: 'test',
        rootPath: '',
      );
      await restarted.targetChanged();
      expect(restoredId, pausedId);
      final restored = await localContentService.completedInput(restoredId);
      expect(restored, isNotNull);
      final restoredBytes = await File(
        '${restored!.rootPath}/${restored.pages.single.relativePath}',
      ).readAsBytes();
      expect(restoredBytes, bytes);
      final restoredEntry = (await restarted.listCloudEntries()).single;
      await restarted.cleanupLocal(restoredEntry);
      await _waitUntil(() async {
        final rows = await appDb
            .customSelect(
              'SELECT cleanup_state FROM content_copy WHERE copy_id = ?',
              variables: [Variable.withString(restoredId)],
            )
            .get();
        return rows.single.readNullable<String>('cleanup_state') == 'completed';
      });
      expect(await Directory(restored.rootPath).exists(), false);
      server.reportPartial = false;
      final unscannedPartition = partition == 'ff' ? 'ee' : 'ff';
      final unscannedHref =
          'manifests/$unscannedPartition/$unscannedPartition${List.filled(62, '0').join()}.sqlite';
      await ContentRepository(appDb).recordRemoteResource(
        targetNamespace: namespace,
        href: unscannedHref,
        kind: 'manifest',
        partition: unscannedPartition,
      );
      server.files.removeWhere(
        (path, _) => path.contains('/manifests/') && path.endsWith('.sqlite'),
      );
      await restarted.refresh();
      expect(await restarted.listCloudEntries(), isEmpty);
      expect(
        await appDb
            .customSelect(
              'SELECT 1 FROM content_remote_resource WHERE target_namespace = ? AND href = ?',
              variables: [
                Variable.withString(namespace),
                Variable.withString(unscannedHref),
              ],
            )
            .get(),
        isEmpty,
      );
    } finally {
      if (!server.getGate.isCompleted) server.getGate.complete();
      if (!server.secondReportGate.isCompleted)
        server.secondReportGate.complete();
      if (!completionGate.isCompleted) completionGate.complete();
      await server.server.close(force: true);
      await appDb.close();
      await home.delete(recursive: true);
    }
  });
}

Future<void> _configureServer(_DavServer server) => webDavSetting.save(
  address: 'http://localhost:${server.server.port}/v1/dav/sync/',
  username: 'test',
  password: 'test',
  rootPath: '',
);

Future<String> _fixtureCopy(
  Directory home,
  int gid,
  String name, {
  List<ManifestLineage> lineage = const [],
  String? jpegComment,
}) async {
  final root = Directory('${home.path}/copy-$gid');
  await root.create();
  final source = File('native/tests/fixtures/$name');
  if (jpegComment == null) {
    await source.copy('${root.path}/$name');
  } else {
    // A legal JPEG COM segment gives the real fixture a distinct raw identity.
    final bytes = await source.readAsBytes();
    final comment = utf8.encode(jpegComment);
    final length = comment.length + 2;
    await File('${root.path}/$name').writeAsBytes([
      ...bytes.take(2),
      0xff,
      0xfe,
      length >> 8,
      length & 0xff,
      ...comment,
      ...bytes.skip(2),
    ]);
  }
  final copy = await localContentService.ensureCopy(
    gid: gid,
    representation: 'original',
    rootPath: root.path,
  );
  await localContentService.recordPage(
    copyId: copy,
    ordinal: 0,
    relativePath: name,
    mime: name.endsWith('.jpg')
        ? 'image/jpeg'
        : name.endsWith('.png')
        ? 'image/png'
        : 'image/webp',
  );
  await localContentService.completeCopy(
    copy,
    galleryUrl: 'https://e-hentai.org/g/$gid/0123456789/',
    title: 'Gallery $gid',
    lineage: lineage,
    expectedPages: 1,
  );
  return copy;
}

Future<String> _multiPageCopy(Directory home, int gid, int count) async {
  final root = Directory('${home.path}/copy-$gid');
  await root.create();
  final bytes = await File('native/tests/fixtures/passthrough.webp')
      .readAsBytes();
  final copy = await localContentService.ensureCopy(
    gid: gid,
    representation: 'original',
    rootPath: root.path,
  );
  for (var ordinal = 0; ordinal < count; ordinal++) {
    final name = '$ordinal.webp';
    await File('${root.path}/$name')
        .writeAsBytes([...bytes, ...utf8.encode('$gid:$ordinal')]);
    await localContentService.recordPage(
      copyId: copy,
      ordinal: ordinal,
      relativePath: name,
      mime: 'image/webp',
      sourcePageUrl: 'https://e-hentai.org/s/page$ordinal/$gid-$ordinal',
    );
  }
  await localContentService.completeCopy(
    copy,
    galleryUrl: 'https://e-hentai.org/g/$gid/0123456789/',
    title: 'Gallery $gid',
    expectedPages: count,
  );
  return copy;
}

Future<void> _workFinished(
  GallerySyncService service,
  ContentRepository repo,
  String id, {
  bool cleanup = false,
}) async {
  final done = Completer<void>();
  Future<void> inspect() async {
    try {
      final work = await repo.getWorkItem(id);
      if (work == null || done.isCompleted) {
        return;
      }
      if (work.state == 'failed') {
        throw StateError('Work $id failed: ${service.lastError}');
      }
      final copy = cleanup && work.copyId != null
          ? await repo.db
                .customSelect(
                  'SELECT lifecycle, cleanup_state, root_path FROM content_copy WHERE copy_id = ?',
                  variables: [Variable.withString(work.copyId!)],
                )
                .getSingleOrNull()
          : null;
      final released =
          copy == null ||
          (copy.read<String>('lifecycle') == 'retiring' &&
              copy.readNullable<String>('cleanup_state') == 'completed' &&
              !await Directory(copy.read<String>('root_path')).exists());
      if (work.state == 'completed' && (!cleanup || released)) {
        done.complete();
      }
    } catch (error, stack) {
      if (!done.isCompleted) {
        done.completeError(error, stack);
      }
    }
  }

  void listener() {
    unawaited(inspect());
  }

  service.addListener(listener);
  try {
    await inspect();
    await done.future.timeout(const Duration(seconds: 10));
  } finally {
    service.removeListener(listener);
  }
}

Future<void> _waitUntil(Future<bool> Function() condition) async {
  for (var i = 0; i < 100; i++) {
    if (await condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  throw TimeoutException('Gallery work did not complete');
}

class _DavRequest {
  final String method;
  final String path;
  String? token;
  _DavRequest(this.method, this.path);
}

class _DavServer {
  final HttpServer server;
  final Map<String, List<int>> files = {};
  final Set<String> directories = {'/v1/dav/sync/'};
  bool loseNextMoveResponse = false;
  int? putFailureStatus;
  int? manifestListingFailureStatus;
  String? manifestListingAuthorization;
  int? objectGetFailureStatus;
  bool holdObjectPut = false;
  bool holdManifestListing = false;
  bool holdObjectGet = false;
  bool holdManifestGet = false;
  bool holdManifestMove = false;
  bool reportPartial = false;
  bool holdSecondReport = false;
  String? reportGhostManifestHref;
  String? seedPartialStageHash;
  int objectPuts = 0;
  int pagePuts = 0;
  int activePuts = 0;
  int maxActivePuts = 0;
  int maxArtifacts = 0;
  bool completeReports = false;
  bool holdPagePuts = false;
  int expectedPagePuts = 8;
  Directory? artifactRoot;
  final requests = <_DavRequest>[];
  final partitionTokens = <String, String>{};
  final invalidTokenStatuses = <String, int>{};
  final partitionListGates = <String, Completer<void>>{};
  final partitionListStarted = <String, Completer<void>>{};
  final partitionListFinished = <String, Completer<void>>{};
  final partitionListFailures = <String, int>{};
  final pagePutsStarted = Completer<void>();
  final pagePutGate = Completer<void>();
  final objectPutGates = <String, Completer<void>>{};
  final objectPutFailures = <String, int>{};

  Future<int> countArtifacts() async {
    final root = artifactRoot;
    if (root == null) {
      return 0;
    }
    return (await root
            .list(recursive: true)
            .where((entry) => entry is File && entry.path.endsWith('.artifact'))
            .toList())
        .length;
  }

  Future<void> measureArtifacts() async {
    final count = await countArtifacts();
    if (count > maxArtifacts) {
      maxArtifacts = count;
    }
  }

  int reportCalls = 0;
  final Completer<void> putStarted = Completer<void>();
  final Completer<void> putGate = Completer<void>();
  final Completer<void> listStarted = Completer<void>();
  final Completer<void> listGate = Completer<void>();
  final Completer<void> getStarted = Completer<void>();
  final Completer<void> getGate = Completer<void>();
  final Completer<void> manifestGetStarted = Completer<void>();
  final Completer<void> manifestGetGate = Completer<void>();
  final Completer<void> secondReportStarted = Completer<void>();
  final Completer<void> secondReportGate = Completer<void>();
  final Completer<void> moveStarted = Completer<void>();
  final Completer<void> moveGate = Completer<void>();
  int moves = 0;

  _DavServer(this.server);

  static Future<_DavServer> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final dav = _DavServer(server);
    server.listen(dav._handle);
    return dav;
  }

  Future<void> _handle(HttpRequest request) async {
    final path = request.uri.path;
    final record = _DavRequest(request.method, path);
    requests.add(record);
    var countedPut = false;
    final listPartition = request.method == 'PROPFIND'
        ? RegExp(r'/manifests/([0-9a-f]{2})/$').firstMatch(path)?.group(1)
        : null;
    try {
      await measureArtifacts();
      final unauthorizedListing =
          request.method == 'PROPFIND' &&
          path.endsWith('/manifests/') &&
          manifestListingAuthorization != null &&
          request.headers.value(HttpHeaders.authorizationHeader) !=
              manifestListingAuthorization;
      final failureStatus = unauthorizedListing
          ? HttpStatus.unauthorized
          : request.method == 'PUT'
          ? putFailureStatus
          : request.method == 'PROPFIND' && path.endsWith('/manifests/')
          ? manifestListingFailureStatus
          : request.method == 'GET' && path.contains('/objects/')
          ? objectGetFailureStatus
          : null;
      if (failureStatus != null) {
        await request.drain<void>();
        request.response.statusCode = failureStatus;
        return;
      }
      switch (request.method) {
        case 'MKCOL':
          final directory = path.endsWith('/') ? path : '$path/';
          if (directories.contains(directory)) {
            request.response.statusCode = 405;
            break;
          }
          if (!directories.contains(Uri.parse(directory).resolve('../').path)) {
            request.response.statusCode = 409;
            break;
          }
          directories.add(directory);
          if (seedPartialStageHash != null &&
              path.contains('/staging/') &&
              !path.endsWith('/staging/')) {
            files['${path.endsWith('/') ? path : '$path/'}$seedPartialStageHash'] =
                [1, 2, 3];
            seedPartialStageHash = null;
          }
          request.response.statusCode = 201;
        case 'PUT':
          countedPut = true;
          activePuts++;
          if (activePuts > maxActivePuts) {
            maxActivePuts = activePuts;
          }
          if (path.contains('/staging/') && !path.endsWith('.sqlite'))
            objectPuts++;
          files[path] = await request.fold<List<int>>(
            <int>[],
            (all, chunk) => all..addAll(chunk),
          );
          final isManifest =
              files[path]!.length >= 16 &&
              utf8.decode(
                    files[path]!.take(16).toList(),
                    allowMalformed: true,
                  ) ==
                  'SQLite format 3\u0000';
          if (!isManifest) {
            pagePuts++;
            final objectHash = path.split('/').last;
            if (objectPutFailures[objectHash] case final status?) {
              request.response.statusCode = status;
              return;
            }
            if (objectPutGates[objectHash] case final gate?) {
              await gate.future;
            }
            await measureArtifacts();
            if (holdPagePuts) {
              if (pagePuts == expectedPagePuts &&
                  !pagePutsStarted.isCompleted) {
                pagePutsStarted.complete();
              }
              await pagePutGate.future;
            }
          }
          if (holdObjectPut &&
              path.contains('/staging/') &&
              !path.endsWith('.sqlite')) {
            if (!putStarted.isCompleted) putStarted.complete();
            await putGate.future;
          }
          request.response.statusCode = 201;
        case 'MOVE':
          moves++;
          final target = Uri.parse(request.headers.value('Destination')!).path;
          final data = files.remove(path);
          if (data == null) {
            request.response.statusCode = 404;
          } else {
            files[target] = data;
            if (holdManifestMove && target.contains('/manifests/')) {
              if (!moveStarted.isCompleted) moveStarted.complete();
              await moveGate.future;
            }
            request.response.statusCode = loseNextMoveResponse ? 500 : 201;
            loseNextMoveResponse = false;
          }
        case 'GET':
          if (holdManifestGet &&
              path.contains('/manifests/') &&
              path.endsWith('.sqlite')) {
            if (!manifestGetStarted.isCompleted) manifestGetStarted.complete();
            await manifestGetGate.future;
          }
          if (holdObjectGet && path.contains('/objects/')) {
            if (!getStarted.isCompleted) getStarted.complete();
            await getGate.future;
          }
          final data = files[path];
          if (data == null) {
            request.response.statusCode = 404;
          } else {
            request.response.statusCode = 200;
            request.response.headers.contentLength = data.length;
            request.response.add(data);
          }
        case 'PROPFIND':
          if (listPartition != null) {
            final started = partitionListStarted[listPartition];
            if (started != null && !started.isCompleted) {
              started.complete();
            }
            if (partitionListGates[listPartition] case final gate?) {
              await gate.future;
            }
            if (partitionListFailures[listPartition] case final status?) {
              request.response.statusCode = status;
              break;
            }
          }
          if (holdManifestListing &&
              path.endsWith('/manifests/') &&
              !path.contains('/new-target/') &&
              request.headers.value('Depth') == '1') {
            if (!listStarted.isCompleted) listStarted.complete();
            await listGate.future;
          }
          final directory = path.endsWith('/') ? path : '$path/';
          final isDirectory = directories.contains(directory);
          final isFile = files.containsKey(path);
          if (!isDirectory && !isFile) {
            request.response.statusCode = 404;
          } else {
            request.response.statusCode = 207;
            request.response.headers.contentType = ContentType(
              'application',
              'xml',
            );
            final children = <String>[];
            if (request.headers.value('Depth') == '1' && isDirectory) {
              for (final child in directories.where(
                (item) => item != directory && item.startsWith(directory),
              )) {
                if (!child
                    .substring(directory.length)
                    .replaceAll(RegExp(r'/$'), '')
                    .contains('/'))
                  children.add(_response(child, true));
              }
              for (final child in files.keys.where(
                (item) => item.startsWith(directory),
              )) {
                if (!child.substring(directory.length).contains('/'))
                  children.add(_response(child, false));
              }
            }
            request.response.write(
              '<?xml version="1.0"?><d:multistatus xmlns:d="DAV:">${_response(isDirectory ? directory : path, isDirectory)}${children.join()}</d:multistatus>',
            );
          }
        case 'REPORT':
          if (completeReports) {
            final body = await utf8.decoder.bind(request).join();
            final token = RegExp(r'<d:sync-token>(.*?)</d:sync-token>')
                .firstMatch(body)!
                .group(1)!;
            record.token = token;
            final partition = path
                .split('/')
                .where((part) => part.isNotEmpty)
                .last;
            final invalid = token.isEmpty
                ? null
                : invalidTokenStatuses.remove(partition);
            if (invalid != null) {
              request.response.statusCode = invalid;
              break;
            }
            final newToken = 'sync://$partition/${requests.length}';
            partitionTokens[partition] = newToken;
            final children = files.keys
                .where(
                  (file) => file.startsWith(path) && file.endsWith('.sqlite'),
                )
                .map((file) => _response(file, false))
                .join();
            request.response.statusCode = 207;
            request.response.headers.contentType = ContentType(
              'application',
              'xml',
            );
            request.response.write(
              '<?xml version="1.0"?><d:multistatus xmlns:d="DAV:">$children<d:sync-token>$newToken</d:sync-token></d:multistatus>',
            );
          } else if (!reportPartial) {
            request.response.statusCode = 405;
          } else {
            reportCalls++;
            final body = await utf8.decoder.bind(request).join();
            final firstPage = body.contains('<d:sync-token></d:sync-token>');
            if (holdSecondReport && !firstPage) {
              if (!secondReportStarted.isCompleted)
                secondReportStarted.complete();
              await secondReportGate.future;
            }
            final children = firstPage
                ? files.keys
                      .where(
                        (file) =>
                            file.startsWith(path) && file.endsWith('.sqlite'),
                      )
                      .map((file) => _response(file, false))
                      .join()
                : '';
            final ghost = firstPage && reportGhostManifestHref != null
                ? _response(
                    '/v1/dav/sync/hclient-v1/$reportGhostManifestHref',
                    false,
                  )
                : '';
            final truncated = firstPage
                ? '<d:response><d:href>$path</d:href><d:status>HTTP/1.1 507 Insufficient Storage</d:status></d:response>'
                : '';
            request.response.statusCode = 207;
            request.response.headers.contentType = ContentType(
              'application',
              'xml',
            );
            request.response.write(
              '<?xml version="1.0"?><d:multistatus xmlns:d="DAV:">$children$ghost$truncated<d:sync-token>sync://$reportCalls</d:sync-token></d:multistatus>',
            );
          }
        default:
          request.response.statusCode = 405;
      }
    } finally {
      await request.response.close();
      final finished = partitionListFinished[listPartition];
      if (finished != null && !finished.isCompleted) {
        finished.complete();
      }
      if (countedPut) {
        activePuts--;
      }
    }
  }

  String _response(String path, bool collection) =>
      '<d:response><d:href>${const HtmlEscape().convert(path)}</d:href><d:propstat><d:prop><d:resourcetype>${collection ? '<d:collection/>' : ''}</d:resourcetype><d:getetag>"one"</d:getetag></d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>';
}

class _WebsiteMetadataRequest extends EHRequest {
  int calls = 0;
  final Completer<void>? detailGate;
  final detailStarted = Completer<void>();
  final int? returnedGid;
  final String coverUrl;
  _WebsiteMetadataRequest({
    this.detailGate,
    this.returnedGid,
    this.coverUrl = 'https://example.org/cover.jpg',
  });
  @override
  Future<T> requestDetailPage<T>({
    required String galleryUrl,
    int thumbnailsPageIndex = 0,
    bool useCacheIfAvailable = true,
    CancelToken? cancelToken,
    required HtmlParser<T> parser,
  }) async {
    calls++;
    if (!detailStarted.isCompleted) detailStarted.complete();
    await detailGate?.future;
    return (
      galleryDetails: GalleryDetail(
        galleryUrl: GalleryUrl.parse(
          returnedGid == null
              ? galleryUrl
              : 'https://e-hentai.org/g/$returnedGid/0123456789/',
        ),
        rawTitle: 'Website title',
        japaneseTitle: '日本語',
        category: 'Manga',
        cover: GalleryImage(url: coverUrl),
        pageCount: 999,
        rating: 5,
        realRating: 4.25,
        hasRated: true,
        ratingCount: 20,
        favoriteCount: 10,
        language: 'Japanese',
        uploader: 'Site uploader',
        publishTime: '2026-11-15',
        isExpunged: false,
        tags: LinkedHashMap(),
        size: '1 MB',
        torrentCount: '0',
        torrentPageUrl: '',
        archivePageUrl: '',
        childrenGalleries: [
          (
            galleryUrl: GalleryUrl.parse(
              'https://e-hentai.org/g/7203/0123456789/',
            ),
            title: 'New version',
            updateTime: '',
          ),
        ],
        comments: [],
        thumbnails: [],
        thumbnailsPageCount: 1,
      ),
      apikey: '',
    ) as T;
  }
}

Future<CloudGalleryEntry> _seedMetadataEntry(
  ContentRepository repo,
  Directory home,
  int gid, {
  String? fileName,
}) async {
  final manifest = PortableManifest(
    gid: gid,
    representation: 'original',
    galleryUrl: 'https://e-hentai.org/g/$gid/0123456789/',
    title: 'Original title',
    collections: ['Original group'],
    tags: [],
    pages: [
      PortablePage(
        rawHash: 'a' * 64,
        rawLength: 1,
        objectHash: 'a' * 64,
        storedLength: 1,
        codecProfile: 'raw',
        mime: 'image/png',
      ),
    ],
  );
  final artifact = PortableManifestCodec.write(
    File('${home.path}/${fileName ?? 'seed-$gid'}.sqlite'),
    manifest,
  );
  await repo.importManifest(webDavSetting.connection.namespace, artifact);
  await repo.recordRemoteResource(
    targetNamespace: webDavSetting.connection.namespace,
    href:
        'manifests/${artifact.manifestId.substring(0, 2)}/${artifact.manifestId}.sqlite',
    kind: 'manifest',
    objectHash: artifact.manifestId,
    partition: artifact.manifestId.substring(0, 2),
  );
  return CloudGalleryEntry(
    gid: gid,
    representation: manifest.representation,
    title: manifest.title,
    manifestId: artifact.manifestId,
    manifest: manifest,
    equivalentManifestIds: [artifact.manifestId],
    localCopyId: null,
    localState: CloudLocalState.none,
  );
}

class _RevisionBarrierRepository extends ContentRepository {
  final reads = <String, int>{};
  final allRevisionsEntered = Completer<void>();
  final releaseRevisions = Completer<void>();
  int entered = 0;
  _RevisionBarrierRepository(super.db);
  @override
  Future<ContentWorkRecord?> getWorkItem(String id) async {
    final work = await super.getWorkItem(id);
    if (work?.kind == 'revision') {
      final count = reads.update(id, (value) => value + 1, ifAbsent: () => 1);
      if (count == 2) {
        entered++;
        if (entered == 8) allRevisionsEntered.complete();
        await releaseRevisions.future;
      }
    }
    return work;
  }
}

Future<void> _withAutomaticFixture(
  Future<void> Function(
    Directory,
    _DavServer,
    ContentRepository,
    GallerySyncService,
  )
  action, {
  ContentRepository Function(AppDb)? repositoryFactory,
  bool initiallyForeground = true,
  QueryInterceptor? queryInterceptor,
  ContentCodec? codec,
}) async {
  final home = await Directory.systemTemp.createTemp('gallery-automatic-');
  final server = await _DavServer.start();
  pathService.appDocDir = home;
  pathService.appSupportDir = home;
  pathService.tempDir = home;
  await downloadSetting.doInitBean();
  downloadSetting.downloadPath.value = home.path;
  appDb = queryInterceptor == null
      ? AppDb()
      : AppDb.testing(NativeDatabase.memory().interceptWith(queryInterceptor));
  final repo = repositoryFactory?.call(appDb) ?? ContentRepository(appDb);
  localContentService = LocalContentService(repository: repo);
  final service = GallerySyncService(repository: repo, codec: codec);
  try {
    await _configureServer(server);
    webDavSetting.autoSync.value = false;
    await service.doInitBean();
    if (initiallyForeground)
      await service.handleAppLifecycleState(AppLifecycleState.resumed);
    await action(home, server, repo, service);
  } finally {
    for (final gate in server.objectPutGates.values) {
      if (!gate.isCompleted) gate.complete();
    }
    if (!server.putGate.isCompleted) server.putGate.complete();
    if (!server.pagePutGate.isCompleted) server.pagePutGate.complete();
    if (!server.moveGate.isCompleted) server.moveGate.complete();
    if (!server.getGate.isCompleted) server.getGate.complete();
    await service.setAutoSync(false);
    await service.handleAppLifecycleState(AppLifecycleState.hidden);
    for (final work in await repo.listWorkItems(includeFinished: true)) {
      await service.cancel(work.workItemId);
    }
    service.dispose();
    await server.server.close(force: true);
    await appDb.close();
    await home.delete(recursive: true);
  }
}

Future<String?> _libraryNamespace(
  ContentRepository repo,
  String copyId,
) async =>
    (await repo.db
            .customSelect(
              'SELECT library_namespace FROM content_copy WHERE copy_id = ?',
              variables: [Variable.withString(copyId)],
            )
            .getSingle())
        .readNullable<String>('library_namespace');

Future<void> _waitForHandoff(ContentRepository repo, String copyId) =>
    _waitUntil(
      () async =>
          await _libraryNamespace(repo, copyId) ==
          webDavSetting.connection.namespace,
    );

Future<ContentWorkRecord> _waitForCopyState(
  ContentRepository repo,
  String copyId,
  String state,
) async {
  late ContentWorkRecord result;
  await _waitUntil(() async {
    final jobs = await repo.listWorkItems(
      copyId: copyId,
      includeFinished: true,
    );
    if (jobs.isEmpty || jobs.last.state != state) return false;
    result = jobs.last;
    return true;
  });
  return result;
}

Future<void> _replaceFixturePage(String copyId, String name) async {
  final replacement = await localContentService.enqueuePageReplacement(
    copyId: copyId,
    ordinal: 0,
    newRelativePath: name,
  );
  final bytes = await File('native/tests/fixtures/$name').readAsBytes();
  await File(replacement.tempPath).writeAsBytes(bytes);
  await localContentService.finishDownloadedReplacement(
    replacement.replacementId,
    rawHash: sha256.convert(bytes).toString(),
    rawLength: bytes.length,
    mime: 'image/png',
  );
}

class _CatalogLocalReadInterceptor extends QueryInterceptor {
  final gids = <int>[];
  final copyIds = <String>[];

  void clear() {
    gids.clear();
    copyIds.clear();
  }

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    if (statement.contains(
      'FROM content_copy WHERE gid = ? AND representation = ?',
    )) {
      gids.add(args.first as int);
    }
    if (statement.contains('FROM content_page WHERE copy_id = ?')) {
      copyIds.add(args.first as String);
    }
    return executor.runSelect(statement, args);
  }
}

class _AutomaticScanInterceptor extends QueryInterceptor {
  final bool holdFirstScan;
  final firstScanEntered = Completer<void>();
  final releaseFirstScan = Completer<void>();
  int fullScans = 0;

  _AutomaticScanInterceptor({this.holdFirstScan = false});

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    if (statement.trim() ==
        "SELECT copy_id FROM content_copy WHERE lifecycle = 'active' AND metadata_json IS NOT NULL") {
      fullScans++;
      if (holdFirstScan && fullScans == 1) {
        firstScanEntered.complete();
        await releaseFirstScan.future;
      }
    }
    return executor.runSelect(statement, args);
  }
}

class _AutomaticTailRepository extends ContentRepository {
  bool holdTail = false;
  final tailEntered = Completer<void>();
  final releaseTail = Completer<void>();
  _AutomaticTailRepository(super.db);
  @override
  Future<List<ContentWorkRecord>> listWorkItems({
    String? kind,
    String? copyId,
    String? targetNamespace,
    bool includeFinished = false,
  }) async {
    if (holdTail &&
        kind == 'content' &&
        targetNamespace != null &&
        copyId == null) {
      holdTail = false;
      tailEntered.complete();
      await releaseTail.future;
    }
    return super.listWorkItems(
      kind: kind,
      copyId: copyId,
      targetNamespace: targetNamespace,
      includeFinished: includeFinished,
    );
  }
}

class _RecordingAwakeService extends ScreenAwakeService {
  _RecordingAwakeService({super.toggle});
  void Function(Object, bool)? onDemand;
  @override
  Future<void> setRequested(Object owner, bool requested) {
    onDemand?.call(owner, requested);
    return super.setRequested(owner, requested);
  }
}

class _RestoreBarrierRepository extends ContentRepository {
  bool hold = false;
  final entered = Completer<void>();
  final release = Completer<void>();
  _RestoreBarrierRepository(super.db);
  @override
  Future<ContentWorkRecord?> getWorkItem(String id) async {
    final work = await super.getWorkItem(id);
    if (hold && work?.kind == 'restore') {
      hold = false;
      entered.complete();
      await release.future;
    }
    return work;
  }
}

class _EncodingCounter implements ContentCodec {
  int encodes = 0;
  int displayReads = 0;

  @override
  Future<Uint8List> decodeImageForDisplay({
    required String inputPath,
    required String codecProfile,
  }) {
    displayReads++;
    return ContentCodec().decodeImageForDisplay(
      inputPath: inputPath,
      codecProfile: codecProfile,
    );
  }

  @override
  Future<ContentCodecArtifact> encodeFile({
    required String inputPath,
    required String outputPath,
  }) {
    encodes++;
    return ContentCodec().encodeFile(
      inputPath: inputPath,
      outputPath: outputPath,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
