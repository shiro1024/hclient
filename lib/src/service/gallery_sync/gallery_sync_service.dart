import '../transfer_activity_service.dart';
import '../screen_awake_service.dart';
import 'upload_speed.dart';

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';

import 'package:drift/drift.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../database/database.dart';
import '../../model/gallery_detail.dart';
import '../../model/gallery_url.dart';
import '../../setting/download_setting.dart';
import '../../setting/webdav_setting.dart';
import '../content_codec.dart';
import '../content_sync/content_repository.dart';
import '../content_sync/content_transfer_concurrency.dart';
import '../content_sync/portable_manifest.dart';
import '../jh_service.dart';
import '../local_content_service.dart';
import '../log.dart';
import '../../network/eh_request.dart';
import '../../utils/eh_spider_parser.dart';
import '../path_service.dart';
import '../webdav/webdav_client.dart';
import '../webdav/webdav_error_text.dart';
import '../../widget/app_manager.dart';

part 'gallery_sync_statistics.dart';

GallerySyncService gallerySyncService = GallerySyncService();

class CloudGalleryEntry {
  final int gid;
  final String representation;
  final String title;
  final String manifestId;
  final PortableManifest manifest;
  final List<String> equivalentManifestIds;
  final String? localCopyId;
  final CloudLocalState localState;
  final List<PortableTag>? aggregatedTags;
  final List<String>? aggregatedCollections;
  List<PortableTag> get tags => aggregatedTags ?? manifest.tags;
  List<String> get collections => aggregatedCollections ?? manifest.collections;
  int familyKey;
  bool preferred;

  bool get locallyAvailable => localState == CloudLocalState.available;

  CloudGalleryEntry({
    required this.gid,
    required this.representation,
    required this.title,
    required this.manifestId,
    required this.manifest,
    required this.equivalentManifestIds,
    required this.localCopyId,
    required this.localState,
    this.aggregatedTags,
    this.aggregatedCollections,
  }) : familyKey = gid,
       preferred = true;
}

class CloudGalleryFacets {
  final List<String> categories;
  final List<String> collections;
  final List<PortableTag> tags;
  const CloudGalleryFacets({
    required this.categories,
    required this.collections,
    required this.tags,
  });
}

enum CloudLocalState { none, available, releasing, released }

class CloudSyncJob {
  final String workItemId;
  final String kind;
  final String title;
  final String state;
  final int completedPages;
  final int totalPages;
  final WebDavFailure? error;
  final String finishAction;
  final ValueListenable<String?>? uploadSpeed;
  bool get cleanupAfterUpload => finishAction == 'release';

  const CloudSyncJob(
    this.workItemId,
    this.kind,
    this.title,
    this.state,
    this.completedPages,
    this.totalPages, {
    this.error,
    this.finishAction = 'keep',
    this.uploadSpeed,
  });
}

class _Stopped implements Exception {}

class _Runner {
  final uploadSpeed = UploadSpeed();
  bool _stop = false;
  final stopped = Completer<void>();
  bool get stop => _stop;
  set stop(bool value) {
    _stop = value;
    if (value) uploadSpeed.dispose();
    if (value && !stopped.isCompleted) stopped.complete();
  }

  String? copyId;
  String title = '';
  String phase = 'cloudQueued';
  int completedPages = 0;
  int totalPages = 0;
  bool automaticSuspension = false;
  final uploadReady = Completer<void>();
  bool uploadHasProgress = false;
  final cancelPut = CancelToken();
  late Future<void> done;
}

class _ScanRunner {
  final String namespace;
  final cancel = CancelToken();
  bool stop = false;
  late Future<void> done;
  _ScanRunner(this.namespace);
}

class _SlotWaiter {
  final int count;
  final Completer<void> ready = Completer<void>();
  _SlotWaiter(this.count);
}

class _SlotLease {
  final _SlotPool pool;
  final int count;
  bool _released = false;
  _SlotLease(this.pool, this.count);

  void release() {
    if (_released) return;
    _released = true;
    pool._release(count);
  }
}

class _SlotPool {
  final int capacity;
  int _available;
  final Queue<_SlotWaiter> _waiting = Queue<_SlotWaiter>();
  _SlotPool(this.capacity) : _available = capacity;

  Future<_SlotLease> acquire(int count, {Future<void>? stopped}) async {
    if (count < 1 || count > capacity) {
      throw ArgumentError.value(count, 'count');
    }
    if (_waiting.isNotEmpty || _available < count) {
      final waiter = _SlotWaiter(count);
      _waiting.add(waiter);
      if (stopped == null) {
        await waiter.ready.future;
      } else {
        await Future.any([waiter.ready.future, stopped]);
        if (!waiter.ready.isCompleted) {
          _waiting.remove(waiter);
          _release(0);
          throw _Stopped();
        }
      }
    } else {
      _available -= count;
    }
    return _SlotLease(this, count);
  }

  void _release(int count) {
    _available += count;
    while (_waiting.isNotEmpty && _available >= _waiting.first.count) {
      final waiter = _waiting.removeFirst();
      _available -= waiter.count;
      waiter.ready.complete();
    }
  }

  Future<T> withSlots<T>(int count, Future<T> Function() action) async {
    final lease = await acquire(count);
    try {
      return await action();
    } finally {
      lease.release();
    }
  }
}

/// A target-bound, restartable coordinator for immutable gallery manifests.
class GallerySyncService
    with JHLifeCircleBeanErrorCatch, ChangeNotifier
    implements JHLifeCircleBean {
  final ContentRepository repository;
  final ContentCodec codec;
  final Map<String, _Runner> _runners = {};
  final List<_Runner> _uploadWaiting = [];
  _Runner? _uploadHead;
  final Map<String, _Runner> _restores = {};
  final Map<String, Future<void>> _releaseInFlight = {};
  final Map<int, Future<GalleryDetail>> _websiteLookups = {};
  final Map<String, Future<File?>> _thumbnailReads = {};
  static final _artifactSlots = _SlotPool(contentTransferConcurrency);
  _ScanRunner? _scan;
  Future<void> _switchTail = Future<void>.value();
  late Directory _artifactDir;
  String? _activeNamespace;

  /// Only failures discovering the current target's library belong here.
  String? lastError;
  bool scanning = false;
  int catalogRevision = 0;
  void Function(String title)? onHandoffCompleted;
  bool _foreground = false;
  bool _automaticScanRequested = false;
  bool _retryAutomaticNetworkErrors = false;
  final Set<String> _automaticCopies = {};
  Future<void>? _automaticPass;
  Future<void>? _automaticSettlement;

  Future<void> _suspendForSystem() async {
    final running = [..._runners.values, ..._restores.values];
    for (final runner in running) {
      runner.stop = true;
      runner.cancelPut.cancel('System dataSync timeout');
    }
    _updateScreenAwake();
    await Future.wait(
      running.map(
        (runner) => runner.done.catchError((Object _, StackTrace __) {}),
      ),
    );
    await _automaticPass;
  }

  Future<void> _resumeAfterSystem() async {
    await resumePending();
    await synchronizeAutomatic(retryNetworkErrors: true);
  }

  void _updateScreenAwake() {
    transferActivityService.replace(this, [
      for (final entry in _runners.entries)
        if (!entry.value.stop)
          TransferActivity(
            id: 'cloud:${entry.key}',
            title: entry.value.title,
            target: 'cloud',
            upload: true,
            phase: entry.value.phase,
            progress: entry.value.completedPages,
            total: entry.value.totalPages,
            waiting: _uploadWaiting.contains(entry.value),
            bytesPerSecond: () => entry.value.uploadSpeed.bytesPerSecond,
          ),
      for (final entry in _restores.entries)
        if (!entry.value.stop)
          TransferActivity(
            id: 'cloud:${entry.key}',
            title: entry.value.title,
            target: 'cloud',
            phase: entry.value.phase,
            progress: entry.value.completedPages,
            total: entry.value.totalPages,
            bytesPerSecond: () => entry.value.uploadSpeed.bytesPerSecond,
          ),
    ]);
    screenAwakeService.setRequested(
      this,
      _runners.values.any(
            (runner) =>
                !runner.stop ||
                (_canRunAutomatic && runner.automaticSuspension),
          ) ||
          _restores.values.any((runner) => !runner.stop),
    );
  }

  @override
  void notifyListeners() {
    _updateScreenAwake();
    super.notifyListeners();
  }

  Future<void> _notifyLocalLibrary() async {
    try {
      await localContentService.onLibraryChanged?.call();
    } catch (error, stack) {
      log.error('Local library projection refresh failed', error, stack);
    }
  }

  void _notifyCatalog() {
    catalogRevision++;
    notifyListeners();
  }

  GallerySyncService({ContentRepository? repository, ContentCodec? codec})
    : repository = repository ?? ContentRepository(appDb),
      codec = codec ?? ContentCodec();

  @override
  List<JHLifeCircleBean> get initDependencies => [
    pathService,
    webDavSetting,
    localContentService,
    screenAwakeService,
    log,
    transferActivityService,
  ];

  @override
  Future<void> doInitBean() async {
    transferActivityService.register(
      this,
      suspend: _suspendForSystem,
      resume: _resumeAfterSystem,
    );
    final home =
        pathService.appSupportDir ??
        pathService.appDocDir ??
        pathService.getVisibleDir();
    _artifactDir = Directory(p.join(home.path, 'gallery-sync-artifacts'));
    await _artifactDir.create(recursive: true);
    localContentService.onCompleted = onCompleted;
    localContentService.onBeforeMutation = onBeforeMutation;
    localContentService.currentLibraryNamespace = () =>
        webDavSetting.isConfigured ? _connection().namespace : null;
    AppManager.registerDidChangeAppLifecycleStateCallback(_onAppLifecycle);
    if (webDavSetting.isConfigured)
      _activeNamespace = webDavSetting.connection.namespace;
  }

  @override
  Future<void> doAfterBeanReady() async {
    await resumePending();
    unawaited(
      ensureInitialDiscovery().catchError((Object error, StackTrace stack) {
        log.error('Initial gallery discovery failed', error, stack);
      }),
    );
  }

  bool get _canRunAutomatic =>
      transferActivityService.canAdmit &&
      (_foreground || transferActivityService.hasBackgroundSession) &&
      webDavSetting.isConfigured &&
      webDavSetting.autoSync.value;

  void _onAppLifecycle(ui.AppLifecycleState state) {
    unawaited(
      handleAppLifecycleState(state)
          .catchError((Object error, StackTrace stack) {
            log.error('Automatic gallery lifecycle failed', error, stack);
          }),
    );
  }

  Future<void> handleAppLifecycleState(ui.AppLifecycleState state) async {
    if (state == ui.AppLifecycleState.inactive) return;
    _foreground = state == ui.AppLifecycleState.resumed;
    _updateScreenAwake();
    if (_foreground) {
      await _automaticSettlement;
      if (!_foreground) return;
      await synchronizeAutomatic(retryNetworkErrors: true);
      await resumePending();
    } else {
      if (!transferActivityService.hasBackgroundSession)
        await _settleAutomatic();
    }
  }

  Future<void> setAutoSync(bool enabled) async {
    if (enabled) _connection();
    await webDavSetting.setAutoSync(enabled);
    _updateScreenAwake();
    if (enabled) {
      await _automaticSettlement;
      await synchronizeAutomatic();
    } else {
      await _settleAutomatic();
    }
    notifyListeners();
  }

  Future<void> _settleAutomatic() =>
      _automaticSettlement ??= _settleAutomaticRunners().whenComplete(() {
        _automaticSettlement = null;
      });

  Future<void> _settleAutomaticRunners() async {
    await _automaticPass;
    final items = await repository.listWorkItems(includeFinished: true);
    final settling = <Future<void>>[];
    for (final work in items.where((item) => item.source == 'automatic')) {
      final runner = _runners[work.workItemId];
      if (runner == null) continue;
      // Finish the request/conversion already in progress. The next input
      // checks stop; automatic suspension is distinct from user pause.
      if (!runner.stop) {
        runner.automaticSuspension = const [
          'queued',
          'running',
          'publishing',
        ].contains(work.state);
        runner.stop = true;
      }
      _updateScreenAwake();
      settling.add(runner.done);
    }
    await Future.wait(settling);
  }

  /// Full scans are requested only by enable/start/resume. Completion events
  /// append their owner IDs to the same pass, including events arriving mid-pass.
  Future<void> synchronizeAutomatic({
    String? copyId,
    bool retryNetworkErrors = false,
  }) {
    if (!_canRunAutomatic) return Future<void>.value();
    if (copyId == null) {
      _automaticScanRequested = true;
    } else {
      _automaticCopies.add(copyId);
    }
    _retryAutomaticNetworkErrors |= retryNetworkErrors;
    return _startAutomaticPass();
  }

  Future<void> _startAutomaticPass() =>
      _automaticPass ??= _drainAutomaticInputs().whenComplete(() {
        _automaticPass = null;
        if (_canRunAutomatic &&
            (_automaticScanRequested || _automaticCopies.isNotEmpty)) {
          return _startAutomaticPass();
        }
      });

  Future<void> _drainAutomaticInputs() async {
    while (_canRunAutomatic &&
        (_automaticScanRequested || _automaticCopies.isNotEmpty)) {
      final connection = _connection();
      await _switchTarget(connection);
      final retryNetwork = _retryAutomaticNetworkErrors;
      _retryAutomaticNetworkErrors = false;
      if (_automaticScanRequested) {
        _automaticScanRequested = false;
        final rows = await repository.db
            .customSelect(
              "SELECT copy_id FROM content_copy WHERE lifecycle = 'active' AND metadata_json IS NOT NULL",
            )
            .get();
        _automaticCopies.addAll(rows.map((row) => row.read<String>('copy_id')));
      }
      final copies = _automaticCopies.toList();
      _automaticCopies.clear();
      for (final id in copies) {
        if (!_canRunAutomatic ||
            _connection().namespace != connection.namespace)
          break;
        try {
          await _scheduleAutomaticCopy(
            id,
            connection,
            retryNetwork: retryNetwork,
          );
        } catch (error, stack) {
          log.error('Automatic gallery input failed: $id', error, stack);
        }
      }
    }
    await resumePending();
  }

  PortableManifest _contentManifest(
    CompletedContent content, {
    PortableManifest? inherit,
  }) {
    final provider = {
      ...?inherit?.providerMetadata,
      ...content.providerMetadata,
    };
    final lineage = {
      for (final edge in [...?inherit?.lineage, ...content.lineage])
        '${edge.fromGid}:${edge.toGid}:${edge.kind}': edge,
    }.values.toList();
    return PortableManifest(
      gid: content.gid,
      representation: content.representation,
      galleryUrl: content.galleryUrl,
      title: content.title,
      tags: content.tags,
      rawTitle: provider['rawTitle'] as String?,
      japaneseTitle: provider['japaneseTitle'] as String?,
      category: provider['category'] as String?,
      uploader: provider['uploader'] as String?,
      publishTime: provider['publishTime'] as String?,
      language: provider['language'] as String?,
      rating: (provider['rating'] as num?)?.toDouble(),
      coverUrl: provider['coverUrl'] as String?,
      collections: content.collections,
      lineage: lineage,
      thumbnail: inherit?.thumbnail,
      codecProfiles: inherit?.codecProfiles ?? const {},
      pages: [
        for (var index = 0; index < content.pages.length; index++)
          if (inherit != null)
            PortablePage(
              rawHash: inherit.pages[index].rawHash,
              rawLength: inherit.pages[index].rawLength,
              objectHash: inherit.pages[index].objectHash,
              storedLength: inherit.pages[index].storedLength,
              codecProfile: inherit.pages[index].codecProfile,
              mime: inherit.pages[index].mime,
              width: inherit.pages[index].width,
              height: inherit.pages[index].height,
              sourcePageUrl:
                  content.pages[index].sourcePageUrl ??
                  inherit.pages[index].sourcePageUrl,
            )
          else
            PortablePage(
              rawHash: content.pages[index].rawHash,
              rawLength: content.pages[index].rawLength,
              objectHash: content.pages[index].rawHash,
              storedLength: content.pages[index].rawLength,
              codecProfile: 'raw',
              mime: content.pages[index].mime,
              width: content.pages[index].width,
              height: content.pages[index].height,
              sourcePageUrl: content.pages[index].sourcePageUrl,
            ),
      ],
    );
  }

  PortableManifest? _frozenContentManifest(ContentWorkRecord work) {
    var input = jsonDecode(work.inputJson) as Map<String, dynamic>;
    if (work.kind == 'revision') {
      final frozen = input['contentInput'];
      if (frozen is! String) return null;
      input = jsonDecode(frozen) as Map<String, dynamic>;
    }
    if (input['pages'] is! List) return null;
    return PortableManifest.fromPortableJson(
      jsonEncode({
        ...input,
        ...?(input['providerMetadata'] as Map?),
        'collections': input['collections'] ?? [],
        'thumbnail': null,
        'codecProfiles': {},
        'pages': [
          for (final page in input['pages'] as List)
            {
              ...page as Map,
              'objectHash': page['rawHash'],
              'storedLength': page['rawLength'],
              'codecProfile': 'raw',
            },
        ],
      }),
    );
  }

  bool _sameInput(ContentWorkRecord work, CompletedContent content) =>
      _frozenContentManifest(work)
          ?.businessEquivalentTo(_contentManifest(content)) ??
      false;

  Future<void> _scheduleAutomaticCopy(
    String copyId,
    WebDavConnection connection, {
    required bool retryNetwork,
  }) async {
    final restores = await repository.listWorkItems(
      kind: 'restore',
      copyId: copyId,
    );
    if (restores.isNotEmpty) return;
    final content = await localContentService.completedInput(copyId);
    if (content == null) return;
    final items =
        (await repository.listWorkItems(
              copyId: copyId,
              targetNamespace: connection.namespace,
              includeFinished: true,
            ))
            .where((item) => item.kind == 'content' || item.kind == 'revision')
            .toList();
    final unfinished = items
        .where((item) => item.state != 'completed' && item.state != 'cancelled')
        .toList();
    if (unfinished.isNotEmpty) {
      final work = unfinished.last;
      if (work.finishAction == 'keep') {
        await repository.db.customStatement(
          "UPDATE content_work_item SET finish_action = 'handoff' WHERE work_item_id = ?",
          [work.workItemId],
        );
      }
      if (work.state == 'failed' &&
          work.source == 'automatic' &&
          retryNetwork) {
        final failure = WebDavFailure.fromJson(
          (jsonDecode(work.artifactsJson) as Map)['_error'],
        );
        if (failure?.kind == 'network' ||
            (failure?.kind == 'server' &&
                (failure?.statusCode ?? 0) >= 500 &&
                (failure?.statusCode ?? 0) <= 599)) {
          await _refreezeChangedInput(work, content);
          await _clearWorkError(work.workItemId);
          await repository.updateWorkItemState(work.workItemId, 'queued');
        }
      }
      if (work.state == 'waiting_input') await _bindInput(work, content);
      return;
    }
    final latest = items.lastOrNull;
    if (latest?.state == 'cancelled' && _sameInput(latest!, content)) return;
    final heads = await _availableHeads(
      connection.namespace,
      content.gid,
      content.representation,
    );
    final matching = heads
        .where(
          (head) => _contentManifest(content).samePagesAs(head.representative),
        )
        .toList();
    final owner = await repository.db
        .customSelect(
          'SELECT library_namespace FROM content_copy WHERE copy_id = ?',
          variables: [Variable.withString(copyId)],
        )
        .getSingle();
    final representationsSelected = content.pages.every(
      (page) => page.codecProfile != null,
    );
    if (owner.readNullable<String>('library_namespace') ==
            connection.namespace &&
        representationsSelected &&
        matching.isNotEmpty &&
        ((latest != null &&
                latest.state == 'completed' &&
                _sameInput(latest, content)) ||
            matching.any(
              (head) => _contentManifest(
                content,
                inherit: head.representative,
              ).businessEquivalentTo(head.representative),
            )))
      return;
    if (matching.isNotEmpty) {
      final head = matching.first;
      // New owners and replaced pages select their resident representation
      // through ordinary work, even when every remote object already exists.
      final needsSelection =
          owner.readNullable<String>('library_namespace') !=
              connection.namespace ||
          !representationsSelected;
      if (needsSelection) {
        await repository.createWorkItem(
          kind: 'content',
          targetNamespace: connection.namespace,
          copyId: copyId,
          inputJson: _freezeInput(content, [
            for (final candidate in matching) ...candidate.manifestIds,
          ]),
          inputManifestId: head.manifestIds.first,
          source: 'automatic',
          finishAction: 'handoff',
        );
        return;
      }
      final desired = _contentManifest(content, inherit: head.representative);
      await _createContentRevision(
        content,
        connection,
        head.manifestIds.first,
        desired.copyWith(
          supersedes: [for (final head in matching) ...head.manifestIds],
        ),
        source: 'automatic',
        finishAction: 'handoff',
      );
      return;
    }
    final baseId = await _previousManifest(copyId, connection.namespace);
    await repository.createWorkItem(
      kind: 'content',
      targetNamespace: connection.namespace,
      copyId: copyId,
      inputManifestId: baseId,
      inputJson: _freezeInput(
        content,
        await _baseHeadIds(connection.namespace, baseId),
      ),
      source: 'automatic',
      finishAction: 'handoff',
    );
    // The automatic pass admits the complete batch through resumePending,
    // where durable progress takes precedence over untouched books.
  }

  Future<ContentWorkRecord> _createContentRevision(
    CompletedContent content,
    WebDavConnection connection,
    String baseId,
    PortableManifest revision, {
    required String source,
    required String finishAction,
    bool launch = true,
  }) async {
    final artifact = await PortableManifestCodec.writeAsync(
      File(
        p.join(_artifactDir.path, 'revisions', '${const Uuid().v4()}.sqlite'),
      ),
      revision,
    );
    final work = await repository.createWorkItem(
      kind: 'revision',
      targetNamespace: connection.namespace,
      copyId: content.copyId,
      inputManifestId: baseId,
      inputJson: jsonEncode({
        'manifestId': artifact.manifestId,
        'contentInput': _freezeInput(content, revision.supersedes),
      }),
      localArtifactPath: artifact.file.path,
      remoteDestination: _manifestPath(artifact.manifestId),
      source: source,
      finishAction: finishAction,
    );
    if (launch && (source != 'automatic' || _canRunAutomatic))
      unawaited(_launchRevision(work.workItemId, connection));
    return work;
  }

  @override
  void dispose() {
    transferActivityService.unregister(this);
    _foreground = false;
    screenAwakeService.setRequested(this, false);
    AppManager.unRegisterDidChangeAppLifecycleStateCallback(_onAppLifecycle);
    super.dispose();
  }

  WebDavConnection _connection() {
    if (!webDavSetting.isConfigured) throw StateError('请先配置 WebDAV');
    return webDavSetting.connection;
  }

  Future<void> _switchTarget(WebDavConnection connection) {
    final next = _switchTail.then((_) => _switchTargetNow(connection));
    _switchTail = next.catchError((Object _, StackTrace __) {});
    return next;
  }

  Future<void> _switchTargetNow(WebDavConnection connection) async {
    if (_activeNamespace == connection.namespace) return;
    final previous = _activeNamespace;
    final running = [..._runners.values, ..._restores.values];
    for (final runner in running) {
      runner.automaticSuspension = false;
      runner.stop = true;
      _updateScreenAwake();
      runner.cancelPut.cancel('WebDAV target changed');
    }
    final scan = _scan;
    if (scan != null && scan.namespace != connection.namespace) {
      scan.stop = true;
      scan.cancel.cancel('WebDAV target changed');
    }
    await Future.wait([
      ...running.map(
        (runner) => runner.done.catchError((Object _, StackTrace __) {}),
      ),
      if (scan != null && scan.namespace != connection.namespace)
        scan.done.catchError((Object _, StackTrace __) {}),
    ]);
    if (previous != null) {
      await repository.db.customStatement(
        "UPDATE content_work_item SET state = 'paused' WHERE target_namespace = ? AND kind IN ('content', 'revision', 'restore') AND state IN ('queued', 'running', 'publishing')",
        [previous],
      );
    }
    _activeNamespace = connection.namespace;
    lastError = null;
    _notifyCatalog();
    await _notifyLocalLibrary();
  }

  Future<void> targetChanged() async {
    if (!webDavSetting.isConfigured) return;
    await _switchTarget(_connection());
    await resumePending();
    if (lastError != null) {
      await refresh();
    } else {
      await ensureInitialDiscovery();
    }
    await synchronizeAutomatic();
  }

  /// An incomplete copy keeps a durable intent and binds a snapshot only when complete.
  Future<String> requestUpload(
    String copyId, {
    bool cleanupAfterUpload = false,
  }) async {
    final connection = _connection();
    await _switchTarget(connection);
    final existing = await repository.listWorkItems(
      targetNamespace: connection.namespace,
    );
    final match = existing
        .where(
          (item) =>
              item.copyId == copyId &&
              (item.kind == 'content' || item.kind == 'revision'),
        )
        .toList();
    if (match.isNotEmpty) {
      final work = match.last;
      await repository.db.customStatement(
        "UPDATE content_work_item SET source = 'manual' WHERE work_item_id = ?",
        [work.workItemId],
      );
      if (cleanupAfterUpload) await _setReleaseAction(work.workItemId);
      if (work.state == 'failed' ||
          work.state == 'paused' ||
          _runners[work.workItemId]?.stop == true) {
        await resume(work.workItemId);
        return work.workItemId;
      }
      if (work.state == 'waiting_input') {
        final content = await localContentService.completedInput(copyId);
        if (content != null) await _bindInput(work, content);
      }
      unawaited(resumePending());
      return work.workItemId;
    }
    final content = await localContentService.completedInput(copyId);
    final baseManifestId = await _previousManifest(
      copyId,
      connection.namespace,
    );
    final supersedes = await _baseHeadIds(connection.namespace, baseManifestId);
    final work = await repository.createWorkItem(
      kind: 'content',
      targetNamespace: connection.namespace,
      copyId: copyId,
      inputManifestId: baseManifestId,
      inputJson: content == null
          ? jsonEncode({'copyId': copyId})
          : _freezeInput(content, supersedes),
      finishAction: cleanupAfterUpload ? 'release' : 'keep',
    );
    if (content == null) {
      await repository.updateWorkItemState(work.workItemId, 'waiting_input');
    } else {
      unawaited(_launch(work, connection));
    }
    notifyListeners();
    return work.workItemId;
  }

  Future<void> _setReleaseAction(String workId) async {
    await repository.db.customStatement(
      "UPDATE content_work_item SET finish_action = 'release' WHERE work_item_id = ? AND state NOT IN ('completed', 'cancelled')",
      [workId],
    );
  }

  String _freezeInput(CompletedContent content, List<String> supersedes) =>
      jsonEncode({
        'copyId': content.copyId,
        'gid': content.gid,
        'representation': content.representation,
        'rootPath': content.rootPath,
        'galleryUrl': content.galleryUrl,
        'title': content.title,
        'providerMetadata': content.providerMetadata,
        'collections': content.collections,
        'tags': content.tags.map((tag) => [tag.namespace, tag.name]).toList(),
        'lineage': content.lineage
            .map((edge) => [edge.fromGid, edge.toGid, edge.kind])
            .toList(),
        'supersedes': supersedes,
        'pages': content.pages
            .map(
              (page) => {
                'ordinal': page.ordinal,
                'relativePath': page.relativePath,
                'rawHash': page.rawHash,
                'rawLength': page.rawLength,
                'mime': page.mime,
                'width': page.width,
                'height': page.height,
                'sourcePageUrl': page.sourcePageUrl,
              },
            )
            .toList(),
      });

  Future<void> _bindInput(
    ContentWorkRecord work,
    CompletedContent content,
  ) async {
    final baseManifestId =
        work.inputManifestId ??
        await _previousManifest(content.copyId, work.targetNamespace);
    final supersedes = await _baseHeadIds(work.targetNamespace, baseManifestId);
    await repository.db.customStatement(
      "UPDATE content_work_item SET input_json = ?, input_manifest_id = ?, state = 'queued', updated_at = ? WHERE work_item_id = ? AND state = 'waiting_input'",
      [
        _freezeInput(content, supersedes),
        baseManifestId,
        DateTime.now().toUtc().toIso8601String(),
        work.workItemId,
      ],
    );
    notifyListeners();
  }

  Future<String?> _previousManifest(String copyId, String namespace) async {
    final rows = await repository.db
        .customSelect(
          "SELECT COALESCE(pending_manifest_id, input_manifest_id) AS pending_manifest_id FROM content_work_item WHERE copy_id = ? AND target_namespace = ? AND kind IN ('content', 'revision', 'restore') AND state = 'completed' AND COALESCE(pending_manifest_id, input_manifest_id) IS NOT NULL ORDER BY created_at DESC, work_item_id DESC LIMIT 1",
          variables: [
            Variable.withString(copyId),
            Variable.withString(namespace),
          ],
        )
        .get();
    return rows.isEmpty
        ? null
        : rows.single.read<String>('pending_manifest_id');
  }

  Future<List<String>> _baseHeadIds(
    String namespace,
    String? baseManifestId,
  ) async {
    if (baseManifestId == null) return [];
    final rows = await repository.db
        .customSelect(
          'SELECT gid, representation FROM content_manifest WHERE target_namespace = ? AND manifest_id = ?',
          variables: [
            Variable.withString(namespace),
            Variable.withString(baseManifestId),
          ],
        )
        .get();
    if (rows.isEmpty) return [baseManifestId];
    final heads = await _availableHeads(
      namespace,
      rows.single.read<int>('gid'),
      rows.single.read<String>('representation'),
    );
    for (final group in heads) {
      if (group.manifestIds.contains(baseManifestId)) {
        return List.unmodifiable(group.manifestIds);
      }
    }
    return [baseManifestId];
  }

  Future<void> onCompleted(CompletedContent content) async {
    final items = await repository.listWorkItems(kind: 'content');
    for (final work in items.where(
      (item) => item.copyId == content.copyId && item.state == 'waiting_input',
    )) {
      await _bindInput(work, content);
    }
    // Keep the completing executor's existing activity until its successor is
    // admitted. Scheduling itself must not await a pass that called this hook.
    final scheduling =
        (() async {
          await synchronizeAutomatic(copyId: content.copyId);
          await resumePending();
        })().catchError((Object error, StackTrace stack) {
          log.error('Cloud work scheduling failed', error, stack);
        });
    transferActivityService.keepSessionUntil(content.copyId, scheduling);
    unawaited(scheduling);
  }

  /// Stops new local reads and PUTs; MOVE already sent is allowed to settle.
  Future<void> onBeforeMutation(String copyId) async {
    // The owner may already have journaled a cancelled predecessor. Its
    // in-memory runner still needs to stop before the old input is released.
    final active = await repository.listWorkItems(includeFinished: true);
    final ids = active
        .where(
          (item) =>
              item.copyId == copyId &&
              (item.kind == 'content' || item.kind == 'revision') &&
              item.state != 'waiting_input' &&
              item.state != 'completed' &&
              _runners.containsKey(item.workItemId),
        )
        .map((item) => item.workItemId)
        .toSet();
    for (final id in ids) {
      final runner = _runners[id];
      if (runner != null) {
        runner.automaticSuspension = false;
        runner.stop = true;
        _updateScreenAwake();
        runner.cancelPut.cancel('Local content changed');
      }
    }
    await Future.wait(
      ids.map((id) => _runners[id]?.done ?? Future<void>.value()),
      eagerError: false,
    );
    await repository.db.customStatement(
      "UPDATE content_work_item SET state = 'cancelled', finish_action = 'keep' WHERE copy_id = ? AND kind IN ('content', 'revision') AND "
      "(state IN ('queued', 'running', 'publishing') OR (? AND state IN ('waiting_input', 'paused', 'failed')))",
      [copyId, localContentService.isRetiringCopy(copyId)],
    );
    for (final id in ids) {
      await _cleanupCancelled(id);
    }
    notifyListeners();
  }

  /// A move changes only the physical root. Keep the fixed content work and
  /// cleanup intent while its current network requests settle.
  Future<void> prepareCopyRelocation(String copyId) async {
    final rows = await repository.db
        .customSelect(
          'SELECT work_item_id FROM content_work_item WHERE copy_id = ?',
          variables: [Variable.withString(copyId)],
        )
        .get();
    final ids = rows.map((row) => row.read<String>('work_item_id')).toSet();
    final running = <_Runner>[
      for (final id in ids)
        if (_runners[id] case final runner?) runner,
      for (final id in ids)
        if (_restores[id] case final runner?) runner,
    ];
    for (final runner in running) {
      runner.automaticSuspension = false;
      runner.stop = true;
      _updateScreenAwake();
      runner.cancelPut.cancel('Local copy is moving');
    }
    await Future.wait(
      running.map(
        (runner) => runner.done.catchError((Object _, StackTrace __) {}),
      ),
    );
  }

  Future<void> finishCopyRelocation(String copyId, bool usable) async {
    if (usable) await resumePending(copyId: copyId);
  }

  Future<void> pause(String workId) async {
    final runner = _runners[workId] ?? _restores[workId];
    if (runner != null) {
      runner.automaticSuspension = false;
      runner.stop = true;
      _updateScreenAwake();
      runner.cancelPut.cancel('Paused');
    }
    final current = await repository.getWorkItem(workId);
    if (current == null ||
        current.state == 'completed' ||
        current.state == 'cancelled')
      return;
    await repository.updateWorkItemState(workId, 'paused');
    if (runner != null) await runner.done;
    notifyListeners();
  }

  Future<void> cancel(String workId) async {
    final runner = _runners[workId] ?? _restores[workId];
    if (runner != null) {
      runner.automaticSuspension = false;
      runner.stop = true;
      _updateScreenAwake();
      runner.cancelPut.cancel('Cancelled');
    }
    // Revoke completion disposition before awaiting a MOVE already in flight.
    // Its remote result still enters the index, but cannot hand off this owner.
    await repository.db.customStatement(
      "UPDATE content_work_item SET state = 'cancelled', finish_action = 'keep' WHERE work_item_id = ? AND state != 'completed'",
      [workId],
    );
    if (runner != null) await runner.done;
    await _cleanupCancelled(workId);
    notifyListeners();
  }

  Future<void> _cleanupCancelled(String workId) async {
    final work = await repository.getWorkItem(workId);
    if (work == null || work.state != 'cancelled') return;
    final registered = jsonDecode(work.artifactsJson) as Map<String, dynamic>;
    for (final entry in registered.values.whereType<Map>()) {
      if (entry['temporary'] != true || entry['path'] is! String) continue;
      final temporary = File(entry['path'] as String);
      if (await temporary.exists()) await temporary.delete();
    }
    final directory = Directory(p.join(_artifactDir.path, workId));
    if (await directory.exists()) await directory.delete(recursive: true);
    if (!webDavSetting.isConfigured ||
        _connection().namespace != work.targetNamespace)
      return;
    final client = WebDavClient(_connection());
    try {
      final staging = await client.list('staging/$workId');
      for (final resource in staging.where((item) => !item.isCollection)) {
        await client.delete(_relative(client.connection, resource.uri));
      }
    } on WebDavException {
      // Local mutation must not depend on staging cleanup availability.
    } catch (_) {
      // A later cleanup can retry without affecting immutable remote objects.
    } finally {
      client.close();
    }
  }

  Future<void> _refreezeChangedInput(
    ContentWorkRecord work,
    CompletedContent content,
  ) async {
    if (_sameInput(work, content)) return;
    final base =
        work.pendingManifestId ??
        work.inputManifestId ??
        await _previousManifest(content.copyId, work.targetNamespace);
    final supersedes = await _baseHeadIds(work.targetNamespace, base);
    await repository.db.customStatement(
      "UPDATE content_work_item SET kind = 'content', input_json = ?, input_manifest_id = ?, "
      "artifacts_json = '{}', pending_manifest_id = NULL, local_artifact_path = NULL, remote_destination = NULL WHERE work_item_id = ?",
      [_freezeInput(content, supersedes), base, work.workItemId],
    );
  }

  Future<void> resume(String workId) async {
    final work = await repository.getWorkItem(workId);
    if (work == null || work.state == 'cancelled' || work.state == 'completed')
      return;
    await (_runners[workId] ?? _restores[workId])?.done;
    if (work.kind == 'restore') {
      await _clearWorkError(workId);
      await repository.updateWorkItemState(workId, 'queued');
      await resumePending();
      return;
    }
    if (work.copyId case final copy?) {
      final content = await localContentService.completedInput(copy);
      if (content != null) {
        await _refreezeChangedInput(work, content);
      } else {
        await repository.db.customStatement(
          "UPDATE content_work_item SET source = 'manual', kind = 'content', state = 'waiting_input', input_json = ?, "
          "input_manifest_id = COALESCE(pending_manifest_id, input_manifest_id), pending_manifest_id = NULL, artifacts_json = '{}', "
          "local_artifact_path = NULL, remote_destination = NULL WHERE work_item_id = ?",
          [
            jsonEncode({'copyId': copy}),
            workId,
          ],
        );
        notifyListeners();
        return;
      }
    }
    await _clearWorkError(workId);
    await repository.db.customStatement(
      "UPDATE content_work_item SET source = 'manual' WHERE work_item_id = ?",
      [workId],
    );
    await repository.updateWorkItemState(workId, 'queued');
    await resumePending();
  }

  Future<void> resumePending({String? copyId}) async {
    if (!transferActivityService.canAdmit) return;
    if (!webDavSetting.isConfigured) return;
    final connection = _connection();
    await _switchTarget(connection);
    final items = await repository.listWorkItems(
      kind: 'content',
      targetNamespace: connection.namespace,
      copyId: copyId,
    );
    // Finish durable progress before opening untouched books. Preserve the
    // repository's FIFO order within each group.
    final ordered = [
      ...items.where(_hasUploadProgress),
      ...items.where((work) => !_hasUploadProgress(work)),
    ];
    for (final work in ordered) {
      if (work.source == 'automatic' && !_canRunAutomatic) continue;
      if (work.state == 'waiting_input') {
        final input = await localContentService.completedInput(work.copyId!);
        if (input != null) {
          await _bindInput(work, input);
          unawaited(_launch(work, connection));
        }
        continue;
      }
      if (work.state == 'queued' ||
          work.state == 'running' ||
          work.state == 'publishing') {
        unawaited(_launch(work, connection));
      }
    }
    final completed = await repository.listWorkItems(
      targetNamespace: connection.namespace,
      includeFinished: true,
      copyId: copyId,
    );
    for (final work in completed.where(
      (item) =>
          item.state == 'completed' &&
          item.finishAction == 'release' &&
          item.pendingManifestId != null,
    )) {
      unawaited(_resumeRelease(work.workItemId));
    }
    final restores = await repository.listWorkItems(
      kind: 'restore',
      targetNamespace: connection.namespace,
      copyId: copyId,
    );
    for (final work in restores.where(
      (item) => item.state == 'queued' || item.state == 'running',
    )) {
      unawaited(
        _launchRestore(
          work,
          connection,
        ).catchError((Object _, StackTrace __) {}),
      );
    }
    final revisions = await repository.listWorkItems(
      kind: 'revision',
      targetNamespace: connection.namespace,
      copyId: copyId,
    );
    for (final work in revisions.where(
      (item) =>
          item.state == 'queued' ||
          item.state == 'running' ||
          item.state == 'publishing',
    )) {
      if (work.source == 'automatic' && !_canRunAutomatic) continue;
      unawaited(_launchRevision(work.workItemId, connection));
    }
  }

  bool _hasUploadProgress(ContentWorkRecord work) {
    if (work.state == 'publishing' ||
        work.pendingManifestId != null ||
        (jsonDecode(work.committedObjectsJson) as List).isNotEmpty) {
      return true;
    }
    final artifacts = jsonDecode(work.artifactsJson) as Map;
    return (artifacts['_completedOrdinals'] as List? ?? const []).isNotEmpty ||
        artifacts.keys.any((key) => int.tryParse(key.toString()) != null);
  }

  void _pumpUploads() {
    if (_uploadHead != null) return;
    _uploadWaiting.removeWhere((runner) => runner.stop);
    if (_uploadWaiting.isEmpty) return;
    final runner = _uploadWaiting.removeAt(0);
    _uploadHead = runner;
    runner.uploadReady.complete();
    _updateScreenAwake();
  }

  void _releaseUploadTurn(_Runner runner) {
    _uploadWaiting.remove(runner);
    if (identical(_uploadHead, runner)) _uploadHead = null;
    _pumpUploads();
  }

  Future<void> _launch(ContentWorkRecord work, WebDavConnection connection) {
    if (!transferActivityService.canAdmit) return Future<void>.value();
    final id = work.workItemId;
    final existing = _runners[id];
    if (existing != null) return existing.done;
    final input = jsonDecode(work.inputJson) as Map<String, dynamic>;
    final runner = _Runner()
      ..uploadHasProgress = _hasUploadProgress(work)
      ..title = input['title'] as String? ?? ''
      ..totalPages = (input['pages'] as List?)?.length ?? 0
      ..completedPages =
          ((jsonDecode(work.artifactsJson) as Map)['_completedOrdinals']
                  as List?)
              ?.length ??
          0;
    _runners[id] = runner;
    // Prioritize interrupted books when they rejoin a live queue. Already
    // admitted books keep their turn; each priority group remains FIFO.
    final untouched = runner.uploadHasProgress
        ? _uploadWaiting.indexWhere((queued) => !queued.uploadHasProgress)
        : -1;
    if (untouched < 0) {
      _uploadWaiting.add(runner);
    } else {
      _uploadWaiting.insert(untouched, runner);
    }
    _updateScreenAwake();
    runner.done = _run(id, connection, runner).whenComplete(() async {
      _runners.remove(id);
      runner.uploadSpeed.dispose();
      notifyListeners();
      await _resumeRelease(id);
    });
    _pumpUploads();
    return runner.done;
  }

  void _check(_Runner runner) {
    if (runner.stop) throw _Stopped();
  }

  Future<void> _clearWorkError(String id) async {
    final work = await repository.getWorkItem(id);
    if (work == null) {
      return;
    }
    final artifacts = jsonDecode(work.artifactsJson) as Map<String, dynamic>;
    if (artifacts.remove('_error') == null) {
      return;
    }
    await repository.db.customStatement(
      'UPDATE content_work_item SET artifacts_json = ? WHERE work_item_id = ?',
      [jsonEncode(artifacts), id],
    );
  }

  Future<void> _failWork(String id, Object error) async {
    final work = await repository.getWorkItem(id);
    if (work == null) {
      return;
    }
    final artifacts = jsonDecode(work.artifactsJson) as Map<String, dynamic>;
    artifacts['_error'] = WebDavFailure.fromError(error).toJson();
    await repository.db.customStatement(
      "UPDATE content_work_item SET state = 'failed', artifacts_json = ?, updated_at = ? "
      "WHERE work_item_id = ? AND state NOT IN ('cancelled', 'paused', 'completed')",
      [jsonEncode(artifacts), DateTime.now().toUtc().toIso8601String(), id],
    );
  }

  Future<void> _progress(
    ContentWorkRecord work,
    String state,
    Map<String, dynamic> artifacts,
    Set<String> committed,
    String? manifestId,
  ) async {
    final current = await repository.getWorkItem(work.workItemId);
    if (current == null ||
        current.state == 'cancelled' ||
        current.state == 'paused')
      throw _Stopped();
    final runner = _runners[work.workItemId];
    if (runner != null) {
      runner.phase = state == 'publishing'
          ? 'cloudPublishing'
          : 'cloudUploading';
      runner.completedPages =
          (artifacts['_completedOrdinals'] as List? ?? []).length;
    }
    await repository.updateContentWorkProgress(
      workItemId: work.workItemId,
      state: state,
      artifactsJson: jsonEncode(artifacts),
      committedObjectsJson: jsonEncode(committed.toList()),
      pendingManifestId: manifestId,
    );
    notifyListeners();
  }

  Future<void> _run(
    String id,
    WebDavConnection connection,
    _Runner runner,
  ) async {
    final client = WebDavClient(connection);
    _SlotLease? publicationLease;
    try {
      await Future.any([runner.uploadReady.future, runner.stopped.future]);
      _check(runner);
      final work = await repository.getWorkItem(id);
      if (work == null || work.targetNamespace != connection.namespace) return;
      await _clearWorkError(id);
      if (work.copyId != null && localContentService.isRelocating(work.copyId!))
        throw _Stopped();
      final currentRoot = await localContentService.rootPath(work.copyId!);
      final input = jsonDecode(work.inputJson) as Map<String, dynamic>;
      if (input['pages'] is! List) return;
      final artifactDir = await localContentService.representationWorkDirectory(
        work.copyId!,
        id,
      );
      final artifacts =
          (jsonDecode(work.artifactsJson) as Map<String, dynamic>);
      artifacts.remove('_error');
      final completedPages = (artifacts['_completedOrdinals'] as List? ?? [])
          .cast<int>()
          .toSet();
      final committed = (jsonDecode(work.committedObjectsJson) as List)
          .cast<String>()
          .toSet();
      Future<void> progressTail = Future<void>.value();
      Future<void> saveProgress(String state, String? manifestId) {
        return progressTail = progressTail.then(
          (_) => _progress(work, state, artifacts, committed, manifestId),
        );
      }

      final inputs = (input['pages'] as List).cast<Map<String, dynamic>>()
        ..sort((a, b) => (a['ordinal'] as int).compareTo(b['ordinal'] as int));
      final pages = List<PortablePage?>.filled(inputs.length, null);
      final directoryReady = Completer<void>();
      final objects = <String, Future<PortablePage>>{};
      var nextPage = 0;
      var activePages = 0;
      Object? pageError;
      StackTrace? pageStack;
      Future<PortablePage> uploadPage(Map<String, dynamic> source) async {
        final ordinal = source['ordinal'] as int;
        final rawHash = source['rawHash'] as String;
        final rawLength = source['rawLength'] as int;
        ObjectRepresentationRecord? reused;
        for (final representation in await repository.findObjectRepresentations(
          connection.namespace,
          rawHash,
        )) {
          if (!ContentCodec.supportsProfile(representation.codecProfile))
            continue;
          if (await client.exists(_objectPath(representation.objectHash))) {
            reused = representation;
            break;
          }
        }
        ContentCodecArtifact? encoded;
        final cached = artifacts['$ordinal'] as Map<String, dynamic>?;
        _check(runner);
        // Frozen inputs describe raw content. Only the owner chooses its
        // current physical file, including after representation installation.
        await localContentService.withResidentPageInput(work.copyId!, ordinal, (
          file,
          resident,
        ) async {
          if (resident.rawHash != rawHash || resident.rawLength != rawLength) {
            throw StateError('Local page changed during upload');
          }
          if (resident.codecProfile != null) {
            encoded = ContentCodecArtifact(
              path: file.path,
              codecProfile: resident.codecProfile!,
              rawHash: rawHash,
              rawLength: rawLength,
              objectHash: resident.objectHash ?? rawHash,
              storedLength: resident.storedLength ?? rawLength,
              isTemporary: false,
            );
          } else if (cached != null &&
              cached['temporary'] == true &&
              await File(cached['path'] as String).exists()) {
            var cachedFile = File(cached['path'] as String);
            if (!p.isWithin(currentRoot, cachedFile.path)) {
              final localFile = await cachedFile.copy(
                p.join(artifactDir.path, '$ordinal.artifact'),
              );
              await cachedFile.delete();
              cachedFile = localFile;
            }
            encoded = ContentCodecArtifact(
              path: cachedFile.path,
              codecProfile: cached['profile'] as String,
              rawHash: rawHash,
              rawLength: rawLength,
              objectHash: cached['objectHash'] as String,
              storedLength: cached['storedLength'] as int,
              isTemporary: true,
            );
          } else {
            if (!ContentCodec.isEncodingCandidate(source['mime'] as String?)) {
              encoded = ContentCodecArtifact(
                path: file.path,
                codecProfile: 'raw',
                rawHash: rawHash,
                rawLength: rawLength,
                objectHash: rawHash,
                storedLength: rawLength,
                isTemporary: false,
              );
            } else {
              _check(runner);
              final output = p.join(artifactDir.path, '$ordinal.artifact');
              final temporary = File(output);
              if (await temporary.exists()) await temporary.delete();
              encoded = await codec.encodeFile(
                inputPath: file.path,
                outputPath: output,
              );
            }
          }
        });
        if (encoded != null) {
          _check(runner);
          if (encoded!.rawHash != rawHash || encoded!.rawLength != rawLength) {
            throw StateError('Local page changed during upload');
          }
          artifacts['$ordinal'] = {
            'path': encoded!.path,
            'profile': encoded!.codecProfile,
            'objectHash': encoded!.objectHash,
            'storedLength': encoded!.storedLength,
            'temporary': encoded!.isTemporary,
          };
          await saveProgress('running', work.pendingManifestId);
          // Local selection and remote deduplication are independent. Keep a
          // reusable remote object while installing the selected resident below.
        }
        var objectHash = reused?.objectHash ?? encoded!.objectHash;
        var profile = reused?.codecProfile ?? encoded!.codecProfile;
        var storedLength = reused?.storedLength ?? encoded!.storedLength;
        Future<void> uploadObject(
          File file,
          ContentPageRecord? resident,
        ) async {
          if (resident != null) {
            if (resident.rawHash != rawHash ||
                resident.rawLength != rawLength) {
              throw StateError('Local page changed during upload');
            }
            // This lease owns the chosen representation until PUT settles.
            profile = resident.codecProfile ?? 'raw';
            objectHash = resident.objectHash ?? rawHash;
            storedLength = resident.storedLength ?? rawLength;
            encoded = ContentCodecArtifact(
              path: file.path,
              codecProfile: profile,
              rawHash: rawHash,
              rawLength: rawLength,
              objectHash: objectHash,
              storedLength: storedLength,
              isTemporary: false,
            );
          }
          if (committed.contains(objectHash)) return;
          final destination = _objectPath(objectHash);
          await client.ensureCollection(
            'objects/${objectHash.substring(0, 2)}',
          );
          if (!await client.exists(destination)) {
            final stage = 'staging/$id/$objectHash';
            _check(runner);
            await client.putFile(
              stage,
              file,
              cancelToken: runner.cancelPut,
              onSendProgress: runner.uploadSpeed.requestProgress(),
            );
            _check(runner);
            try {
              await client.move(stage, destination);
            } on WebDavException {
              if (!await client.exists(destination)) rethrow;
            }
          }
          committed.add(objectHash);
          await repository.recordRemoteResource(
            targetNamespace: connection.namespace,
            href: destination,
            kind: 'object',
            objectHash: objectHash,
          );
          await repository.db.customStatement(
            'INSERT OR IGNORE INTO content_object_representation (target_namespace, raw_hash, object_hash, codec_profile, stored_length) VALUES (?, ?, ?, ?, ?)',
            [connection.namespace, rawHash, objectHash, profile, storedLength],
          );
          await saveProgress('running', work.pendingManifestId);
        }

        if (reused == null) {
          if (encoded!.isTemporary) {
            await uploadObject(File(encoded!.path), null);
          } else {
            await localContentService.withResidentPageInput(
              work.copyId!,
              ordinal,
              uploadObject,
            );
          }
        }
        final page = PortablePage(
          rawHash: rawHash,
          rawLength: rawLength,
          objectHash: objectHash,
          storedLength: storedLength,
          codecProfile: profile,
          mime: source['mime'] as String,
          width: source['width'] as int?,
          height: source['height'] as int?,
          sourcePageUrl: source['sourcePageUrl'] as String?,
        );
        if (encoded != null) {
          // Serialize ownership transfer with progress snapshots so another
          // finishing page cannot re-register an artifact already owned locally.
          progressTail = progressTail.then((_) async {
            final installed = await localContentService
                .installPageRepresentation(
                  copyId: work.copyId!,
                  ordinal: ordinal,
                  artifact: encoded!,
                  workItemId: id,
                );
            if (installed) {
              artifacts.remove('$ordinal');
            } else if (encoded!.isTemporary) {
              final unused = File(encoded!.path);
              if (await unused.exists()) await unused.delete();
              artifacts.remove('$ordinal');
            }
          });
          await progressTail;
        }
        return page;
      }

      Future<void> uploadPages() async {
        while (nextPage < inputs.length && pageError == null) {
          _SlotLease? lease;
          try {
            lease = await _artifactSlots.acquire(
              1,
              stopped: runner.stopped.future,
            );
            _check(runner);
            if (pageError != null || nextPage >= inputs.length) return;
            final index = nextPage++;
            activePages++;
            try {
              if (index == 0) {
                try {
                  await client.ensureCollection('objects');
                  _check(runner);
                  await client.ensureCollection('manifests');
                  _check(runner);
                  await client.ensureCollection('staging/$id');
                  _check(runner);
                } finally {
                  directoryReady.complete();
                }
              } else {
                await directoryReady.future;
                _check(runner);
                if (pageError != null) return;
              }
              // Every remaining page is now using an existing slot. The next
              // book can fill slots released by this book's final pages.
              if (nextPage == inputs.length) _releaseUploadTurn(runner);
              final source = inputs[index];
              final hash = source['rawHash'] as String;
              final duplicate = objects.containsKey(hash);
              final object = await objects.putIfAbsent(
                hash,
                () => uploadPage(source),
              );
              if (duplicate) {
                final representative =
                    inputs.firstWhere(
                          (page) => page['rawHash'] == hash,
                        )['ordinal']
                        as int;
                ContentCodecArtifact? sharedArtifact;
                await localContentService.withResidentPageInput(
                  work.copyId!,
                  representative,
                  (file, resident) async {
                    final duplicateOrdinal = source['ordinal'] as int;
                    if ((await repository.getPage(
                          work.copyId!,
                          duplicateOrdinal,
                        )).codecProfile !=
                        null)
                      return;
                    if (resident.rawHash != object.rawHash ||
                        resident.rawLength != object.rawLength ||
                        resident.codecProfile == null) {
                      throw StateError(
                        'Shared local representation is unavailable',
                      );
                    }
                    final target = resident.codecProfile == 'raw'
                        ? null
                        : await file.copy(
                            p.join(
                              artifactDir.path,
                              '${source['ordinal']}.artifact',
                            ),
                          );
                    sharedArtifact = ContentCodecArtifact(
                      path: target?.path ?? file.path,
                      codecProfile: resident.codecProfile!,
                      rawHash: resident.rawHash!,
                      rawLength: resident.rawLength!,
                      objectHash: resident.objectHash ?? resident.rawHash!,
                      storedLength:
                          resident.storedLength ?? resident.rawLength!,
                      isTemporary: target != null,
                    );
                  },
                );
                if (sharedArtifact != null) {
                  final duplicateOrdinal = source['ordinal'] as int;
                  artifacts['$duplicateOrdinal'] = {
                    'path': sharedArtifact!.path,
                    'profile': sharedArtifact!.codecProfile,
                    'objectHash': sharedArtifact!.objectHash,
                    'storedLength': sharedArtifact!.storedLength,
                    'temporary': sharedArtifact!.isTemporary,
                  };
                  await saveProgress('running', work.pendingManifestId);
                  try {
                    progressTail = progressTail.then((_) async {
                      await localContentService.installPageRepresentation(
                        copyId: work.copyId!,
                        ordinal: duplicateOrdinal,
                        artifact: sharedArtifact!,
                        workItemId: id,
                      );
                      artifacts.remove('$duplicateOrdinal');
                    });
                    await progressTail;
                  } finally {
                    final journalOwnsFile =
                        (await repository.listPageReplacements(work.copyId!))
                            .any(
                              (entry) => entry.tempPath == sharedArtifact!.path,
                            );
                    if (!journalOwnsFile &&
                        sharedArtifact!.isTemporary &&
                        await File(sharedArtifact!.path).exists())
                      await File(sharedArtifact!.path).delete();
                  }
                }
              }
              // Object bytes can be shared; ordinal metadata remains independent.
              pages[index] = PortablePage(
                rawHash: object.rawHash,
                rawLength: object.rawLength,
                objectHash: object.objectHash,
                storedLength: object.storedLength,
                codecProfile: object.codecProfile,
                mime: source['mime'] as String,
                width: source['width'] as int?,
                height: source['height'] as int?,
                sourcePageUrl: source['sourcePageUrl'] as String?,
              );
              completedPages.add(source['ordinal'] as int);
              artifacts['_completedOrdinals'] = completedPages.toList()..sort();
              await saveProgress('running', work.pendingManifestId);
            } finally {
              activePages--;
            }
            if (activePages == 0 &&
                nextPage == inputs.length &&
                pageError == null &&
                !runner.stop) {
              // Publish on the last finishing page's lease, so a complete book
              // never rejoins the queue behind untouched books.
              publicationLease = lease;
              lease = null;
            }
          } catch (error, stack) {
            pageError ??= error;
            pageStack ??= stack;
          } finally {
            lease?.release();
          }
        }
      }

      // Default Future.wait drains active pages before closing their client or
      // reporting failure. No page acquires another artifact lease.
      await Future.wait(
        List.generate(contentTransferConcurrency, (_) => uploadPages()),
      );
      if (pageError != null) {
        Error.throwWithStackTrace(pageError!, pageStack!);
      }
      var orderedPages = pages.cast<PortablePage>();
      _check(runner);
      final heads = await _availableHeads(
        connection.namespace,
        input['gid'] as int,
        input['representation'] as String,
      );
      final supersedes =
          (input['supersedes'] as List?)?.cast<String>() ??
          (work.inputManifestId == null
              ? <String>[]
              : <String>[work.inputManifestId!]);
      // The admitted base supplies the same inherited business facts as an
      // owner metadata revision, independently of local storage selection.
      PortableManifest? inherited;
      if (work.inputManifestId case final baseId?) {
        final baseRows = await repository.db
            .customSelect(
              'SELECT portable_json FROM content_manifest WHERE target_namespace = ? AND manifest_id = ?',
              variables: [
                Variable.withString(connection.namespace),
                Variable.withString(baseId),
              ],
            )
            .get();
        if (baseRows.isNotEmpty) {
          final base = PortableManifest.fromPortableJson(
            baseRows.single.read<String>('portable_json'),
          );
          if (_frozenContentManifest(work)?.samePagesAs(base) == true) {
            inherited = base;
            orderedPages = [
              for (var index = 0; index < orderedPages.length; index++)
                PortablePage(
                  rawHash: orderedPages[index].rawHash,
                  rawLength: orderedPages[index].rawLength,
                  objectHash: orderedPages[index].objectHash,
                  storedLength: orderedPages[index].storedLength,
                  codecProfile: orderedPages[index].codecProfile,
                  mime: base.pages[index].mime,
                  width: base.pages[index].width,
                  height: base.pages[index].height,
                  sourcePageUrl:
                      inputs[index]['sourcePageUrl'] as String? ??
                      base.pages[index].sourcePageUrl,
                ),
            ];
          }
        }
      }
      final providerMetadata = {
        ...?inherited?.providerMetadata,
        ...?(input['providerMetadata'] as Map?)?.cast<String, Object?>(),
      };
      final usedProfiles = orderedPages
          .map((page) => page.codecProfile)
          .where((profile) => profile != 'raw')
          .toSet();
      PortableThumbnail? thumbnail = inherited?.thumbnail;
      final thumbnailFile = _generatedThumbnailFile(orderedPages.first.rawHash);
      if (inherited == null) {
        _check(runner);
        try {
          if (!await thumbnailFile.exists()) {
            await _renderThumbnailBytes(
              await localContentService.readPageForDisplay(work.copyId!, 0),
              thumbnailFile,
            );
          }
          thumbnail = await _thumbnailReference(thumbnailFile);
        } catch (error, stack) {
          log.error('Generate upload thumbnail failed', error, stack);
        }
        if (thumbnail case final readyThumbnail?) {
          await _publishThumbnail(
            client,
            id,
            thumbnailFile,
            readyThumbnail,
            runner,
          );
        }
      }
      final manifest = PortableManifest(
        thumbnail: thumbnail,
        gid: input['gid'] as int,
        representation: input['representation'] as String,
        galleryUrl: input['galleryUrl'] as String,
        title: input['title'] as String,
        rawTitle: providerMetadata['rawTitle'] as String?,
        japaneseTitle: providerMetadata['japaneseTitle'] as String?,
        category: providerMetadata['category'] as String?,
        uploader: providerMetadata['uploader'] as String?,
        publishTime: providerMetadata['publishTime'] as String?,
        language: providerMetadata['language'] as String?,
        coverUrl: providerMetadata['coverUrl'] as String?,
        rating: (providerMetadata['rating'] as num?)?.toDouble(),
        collections:
            (input['collections'] as List?)?.cast<String>() ?? const [],
        tags: (input['tags'] as List)
            .map(
              (tag) =>
                  PortableTag((tag as List)[0] as String, tag[1] as String),
            )
            .toList(),
        lineage: {
          for (final edge in [
            ...?inherited?.lineage,
            for (final entry in input['lineage'] as List)
              ManifestLineage(
                entry[0] as int,
                entry[1] as int,
                entry[2] as String,
              ),
          ])
            '${edge.fromGid}:${edge.toGid}:${edge.kind}': edge,
        }.values.toList(),
        pages: orderedPages,
        supersedes: supersedes,
        codecProfiles: {
          for (final profile in usedProfiles)
            profile: ContentCodec.profileDefinitions[profile]!
                .cast<String, Object?>(),
        },
      );
      final equivalent = heads
          .where((group) => group.representative.businessEquivalentTo(manifest))
          .toList();
      if (equivalent.isNotEmpty) {
        await _progress(
          work,
          'publishing',
          artifacts,
          committed,
          equivalent.first.manifestIds.first,
        );
        await _finishPublication(
          id,
          connection,
          equivalent.first.manifestIds.first,
          equivalent.first.representative,
        );
        return;
      }
      {
        final file = File(p.join(artifactDir.path, 'manifest.sqlite'));
        ManifestArtifact artifact;
        if (work.pendingManifestId != null && await file.exists()) {
          artifact = ManifestArtifact(file, work.pendingManifestId!);
        } else {
          if (await file.exists()) await file.delete();
          artifact = await PortableManifestCodec.writeAsync(file, manifest);
        }
        await _progress(
          work,
          'publishing',
          artifacts,
          committed,
          artifact.manifestId,
        );
        final destination = _manifestPath(artifact.manifestId);
        await client.ensureCollection(
          'manifests/${artifact.manifestId.substring(0, 2)}',
        );
        if (!await client.exists(destination)) {
          final stage = 'staging/$id/${artifact.manifestId}';
          await client.putFile(
            stage,
            file,
            cancelToken: runner.cancelPut,
            onSendProgress: runner.uploadSpeed.requestProgress(),
          );
          _check(runner);
          try {
            await client.move(stage, destination);
          } on WebDavException {
            if (!await client.exists(destination)) rethrow;
          }
        }
        await _finishPublication(
          id,
          connection,
          artifact.manifestId,
          await PortableManifestCodec.readAsync(artifact.file),
          artifact: artifact,
        );
      }
    } on _Stopped {
      // The caller chooses paused or cancelled after outstanding MOVE settles.
    } catch (error, stack) {
      if (runner.stop) return;
      await _failWork(id, error);
      log.error('Gallery sync failed', error, stack);
      notifyListeners();
    } finally {
      _releaseUploadTurn(runner);
      publicationLease?.release();
      client.close();
    }
  }

  Future<void> _maybeRelease(String workId, String manifestId) async {
    // The owner checks the current intent and manifest again before retirement.
    final work = await repository.getWorkItem(workId);
    if (work?.finishAction != 'release') return;
    // LocalContentService provides the conditional retirement API.
    await localContentService.executeRelease(work!.copyId!, workId, manifestId);
  }

  Future<void> _resumeRelease(String workId) {
    final existing = _releaseInFlight[workId];
    if (existing != null) return existing;
    final future = () async {
      final work = await repository.getWorkItem(workId);
      if (work?.state != 'completed' ||
          work?.finishAction != 'release' ||
          work?.pendingManifestId == null)
        return;
      try {
        await _maybeRelease(workId, work!.pendingManifestId!);
      } catch (error) {
        log.warning('Gallery cleanup deferred', error, true);
      } finally {
        _notifyCatalog();
      }
    }();
    _releaseInFlight[workId] = future.whenComplete(() {
      _releaseInFlight.remove(workId);
    });
    return _releaseInFlight[workId]!;
  }

  /// Object publication is already complete. The remote index, work result and
  /// local browsing handoff now commit together against the latest owner facts.
  Future<void> _finishPublication(
    String id,
    WebDavConnection connection,
    String manifestId,
    PortableManifest manifest, {
    ManifestArtifact? artifact,
  }) async {
    final result = await repository.db.transaction(() async {
      await repository.recordRemoteResource(
        targetNamespace: connection.namespace,
        href: _manifestPath(manifestId),
        kind: 'manifest',
        objectHash: manifestId,
        partition: manifestId.substring(0, 2),
      );
      if (artifact != null)
        await repository.importManifest(connection.namespace, artifact);
      final work = await repository.getWorkItem(id);
      if (work == null)
        return (
          next: null as ContentWorkRecord?,
          handoff: null as CompletedContent?,
          metadataCopies: <String>[],
        );
      await repository.db.customStatement(
        'UPDATE content_work_item SET pending_manifest_id = ? WHERE work_item_id = ?',
        [manifestId, id],
      );
      if (work.state == 'cancelled' || work.state == 'paused')
        return (
          next: null as ContentWorkRecord?,
          handoff: null as CompletedContent?,
          metadataCopies: <String>[],
        );
      CompletedContent? current;
      if (work.copyId != null)
        current = await localContentService.completedInput(work.copyId!);
      ContentWorkRecord? next;
      if (current != null && !_sameInput(work, current)) {
        final currentSnapshot = _contentManifest(current);
        if (currentSnapshot.samePagesAs(manifest)) {
          final heads = await _availableHeads(
            connection.namespace,
            current.gid,
            current.representation,
          );
          final revision = _contentManifest(current, inherit: manifest)
              .copyWith(
                supersedes: {
                  manifestId,
                  for (final head in heads)
                    if (head.representative.samePagesAs(manifest))
                      ...head.manifestIds,
                }.toList(),
              );
          next = await _createContentRevision(
            current,
            connection,
            manifestId,
            revision,
            source: work.source,
            finishAction: work.finishAction,
            launch: false,
          );
        } else {
          next = await repository.createWorkItem(
            kind: 'content',
            targetNamespace: connection.namespace,
            copyId: current.copyId,
            inputManifestId: manifestId,
            inputJson: _freezeInput(current, [manifestId]),
            source: work.source,
            finishAction: work.finishAction,
          );
        }
        await repository.db.customStatement(
          "UPDATE content_work_item SET finish_action = 'keep' WHERE work_item_id = ?",
          [id],
        );
      }
      final completed = await _completeWork(id);
      final handoff =
          completed && next == null && work.finishAction == 'handoff'
          ? current
          : null;
      if (handoff != null)
        await repository.handoffCopy(handoff.copyId, connection.namespace);
      final patch = (jsonDecode(
        work.inputJson,
      ) as Map<String, dynamic>)['ownerMetadataPatch'];
      final metadataCopies = completed && patch is Map<String, dynamic>
          ? await localContentService.applyPublishedMetadataRevision(
              targetNamespace: connection.namespace,
              manifest: manifest,
              patch: patch,
            )
          : <String>[];
      return (next: next, handoff: handoff, metadataCopies: metadataCopies);
    });
    _notifyCatalog();
    await localContentService.finishPublishedMetadataRevision(
      result.metadataCopies,
    );
    if (result.handoff case final content?) {
      try {
        await localContentService.finishCloudHandoff(content.copyId);
      } catch (error, stack) {
        // Database ownership is committed. Projection/UI work is recoverable
        // and must never turn this successful transfer into a failed job.
        log.error('Cloud handoff projection update deferred', error, stack);
      }
      try {
        onHandoffCompleted?.call(content.title);
      } catch (error, stack) {
        log.error('Cloud handoff notification failed', error, stack);
      }
    }
    if (result.handoff == null &&
        webDavSetting.isConfigured &&
        _connection().namespace == connection.namespace) {
      await _notifyLocalLibrary();
    }
    final next = result.next;
    if (next != null &&
        webDavSetting.isConfigured &&
        _connection().namespace == connection.namespace &&
        (next.source != 'automatic' || _canRunAutomatic)) {
      if (next.kind == 'revision') {
        unawaited(_launchRevision(next.workItemId, connection));
      } else {
        unawaited(_launch(next, connection));
      }
    }
  }

  Future<bool> _completeWork(String id) async {
    await repository.db.customStatement(
      "UPDATE content_work_item SET state = 'completed', updated_at = ? WHERE work_item_id = ? AND state NOT IN ('cancelled', 'paused')",
      [DateTime.now().toUtc().toIso8601String(), id],
    );
    return (await repository.getWorkItem(id))?.state == 'completed';
  }

  /// Creates a new portable revision using remote page references only.
  Future<String> requestMetadataRevision(
    String baseManifestId, {
    String? title,
    List<PortableTag>? tags,
    List<ManifestLineage>? lineageAdded,
    List<ManifestLineage>? lineageRemoved,
    Map<String, Object?>? providerMetadata,
    List<String>? collections,
    PortableThumbnail? thumbnail,
    File? thumbnailArtifact,
  }) => _requestMetadataRevision(
    baseManifestId,
    title: title,
    tags: tags,
    lineageAdded: lineageAdded,
    lineageRemoved: lineageRemoved,
    providerMetadata: providerMetadata,
    collections: collections,
    thumbnail: thumbnail,
    thumbnailArtifact: thumbnailArtifact,
  );

  Future<String> _requestMetadataRevision(
    String baseManifestId, {
    String? title,
    List<PortableTag>? tags,
    List<ManifestLineage>? lineageAdded,
    List<ManifestLineage>? lineageRemoved,
    Map<String, Object?>? providerMetadata,
    List<String>? collections,
    PortableThumbnail? thumbnail,
    File? thumbnailArtifact,
    GalleryDetail? websiteDetail,
    WebDavConnection? target,
  }) async {
    final connection = target ?? _connection();
    if (target == null) await _switchTarget(connection);
    final rows = await repository.db
        .customSelect(
          'SELECT portable_json FROM content_manifest WHERE target_namespace = ? AND manifest_id = ?',
          variables: [
            Variable.withString(connection.namespace),
            Variable.withString(baseManifestId),
          ],
        )
        .get();
    if (rows.isEmpty) throw StateError('Unknown cloud manifest');
    final base = PortableManifest.fromPortableJson(
      rows.single.read<String>('portable_json'),
    );
    final heads = await _availableHeads(
      connection.namespace,
      base.gid,
      base.representation,
    );
    final compatible = heads
        .where((group) => group.representative.samePagesAs(base))
        .toList();
    final current = compatible.isNotEmpty
        ? compatible.first.representative
        : base;
    final currentFacts = compatible.isEmpty
        ? [base]
        : compatible.map((group) => group.representative);
    final supersedes = <String>{
      baseManifestId,
      for (final group in compatible) ...group.manifestIds,
    }.toList();
    final patch = <String, dynamic>{
      if (websiteDetail == null && title != null) 'title': title,
      if (tags != null)
        'tags': tags.map((tag) => [tag.namespace, tag.name]).toList(),
      if (websiteDetail == null && collections != null)
        'collections': collections,
      if (providerMetadata != null) 'providerMetadata': providerMetadata,
    };
    if (websiteDetail != null) patch['sourceParentGid'] = base.gid;
    if (lineageAdded != null) {
      patch['lineageAdded'] = lineageAdded
          .map((edge) => [edge.fromGid, edge.toGid, edge.kind])
          .toList();
    }
    if (lineageRemoved != null) {
      patch['lineageRemoved'] = lineageRemoved
          .map((edge) => [edge.fromGid, edge.toGid, edge.kind])
          .toList();
    }
    final mergedLineage = <String, ManifestLineage>{
      for (final manifest in currentFacts)
        for (final edge in manifest.lineage)
          jsonEncode([edge.fromGid, edge.toGid, edge.kind]): edge,
    };
    if (websiteDetail != null) {
      mergedLineage.removeWhere(
        (_, edge) =>
            edge.kind == 'source_parent' &&
            (edge.fromGid == base.gid || edge.toGid == base.gid),
      );
    }
    for (final edge in patch['lineageRemoved'] as List? ?? const []) {
      mergedLineage.remove(jsonEncode(edge));
    }
    for (final edge in patch['lineageAdded'] as List? ?? const []) {
      mergedLineage[jsonEncode(edge)] = ManifestLineage(
        edge[0] as int,
        edge[1] as int,
        edge[2] as String,
      );
    }
    final revision = current.copyWith(
      title: websiteDetail == null ? title : current.title,
      tags:
          tags ??
          <String, PortableTag>{
            for (final manifest in currentFacts)
              for (final tag in manifest.tags)
                jsonEncode([tag.namespace, tag.name]): tag,
          }.values.toList(),
      lineage: mergedLineage.values.toList(),
      supersedes: supersedes,
      providerMetadata: {...current.providerMetadata, ...?providerMetadata},
      collections:
          collections ??
          {for (final manifest in currentFacts) ...manifest.collections}
              .toList(),
      thumbnail: thumbnail,
    );
    if (revision.businessEquivalentTo(base) && supersedes.length == 1) {
      final changed = await repository.db.transaction(
        () => localContentService.applyPublishedMetadataRevision(
          targetNamespace: connection.namespace,
          manifest: base,
          patch: patch,
        ),
      );
      await localContentService.finishPublishedMetadataRevision(changed);
      if (changed.isNotEmpty) await _notifyLocalLibrary();
      return baseManifestId;
    }
    final artifactPath = File(
      p.join(_artifactDir.path, 'revisions', '${const Uuid().v4()}.sqlite'),
    );
    final artifact = await PortableManifestCodec.writeAsync(
      artifactPath,
      revision,
    );
    final work = await repository.createWorkItem(
      kind: 'revision',
      targetNamespace: connection.namespace,
      inputManifestId: baseManifestId,
      inputJson: jsonEncode({
        'manifestId': artifact.manifestId,
        'ownerMetadataPatch': patch,
        if (thumbnailArtifact != null) 'thumbnailPath': thumbnailArtifact.path,
      }),
      localArtifactPath: artifact.file.path,
      remoteDestination: _manifestPath(artifact.manifestId),
    );
    if (webDavSetting.isConfigured &&
        _connection().namespace == connection.namespace) {
      unawaited(_launchRevision(work.workItemId, connection));
    }
    // A website request can finish after the selected target changed. Keep
    // its queued work bound to the original target; it resumes on that target.
    return work.workItemId;
  }

  Future<String> requestWebsiteMetadataRevision(CloudGalleryEntry entry) async {
    final connection = _connection();
    await _switchTarget(connection);
    final lookup = _websiteLookups.putIfAbsent(entry.gid, () async {
      final url = GalleryUrl.tryParse(entry.manifest.galleryUrl);
      if (url == null) throw StateError('Gallery URL is unavailable');
      final response = await ehRequest
          .requestDetailPage<({GalleryDetail galleryDetails, String apikey})>(
            galleryUrl: url.url,
            parser: EHSpiderParser.detailPage2GalleryAndDetailAndApikey,
            useCacheIfAvailable: false,
          );
      return response.galleryDetails;
    });
    late GalleryDetail detail;
    try {
      detail = await lookup;
    } finally {
      if (identical(_websiteLookups[entry.gid], lookup))
        _websiteLookups.remove(entry.gid);
    }
    if (detail.galleryUrl.gid != entry.gid) {
      throw FormatException(
        'Website returned gallery ${detail.galleryUrl.gid} for ${entry.gid}',
      );
    }
    final lineage = <ManifestLineage>[
      if (detail.parentGalleryUrl case final parent?)
        ManifestLineage(parent.gid, entry.gid, 'source_parent'),
      for (final child in detail.childrenGalleries ?? const [])
        ManifestLineage(entry.gid, child.galleryUrl.gid, 'source_parent'),
    ];
    final provider = <String, Object?>{
      'rawTitle': detail.rawTitle,
      'japaneseTitle': detail.japaneseTitle,
      'category': detail.category,
      'uploader': detail.uploader,
      'publishTime': detail.publishTime,
      'language': detail.language,
      'rating': detail.realRating,
      'coverUrl': detail.cover.url,
    };
    final updated = entry.manifest.copyWith(providerMetadata: provider);
    File? thumbnail;
    PortableThumbnail? thumb;
    try {
      thumbnail = await _thumbnailFile(
        CloudGalleryEntry(
          gid: entry.gid,
          representation: entry.representation,
          title: entry.title,
          manifestId: entry.manifestId,
          manifest: updated,
          equivalentManifestIds: entry.equivalentManifestIds,
          localCopyId: entry.localCopyId,
          localState: entry.localState,
        ),
        connection,
      );
      thumb = thumbnail == null ? null : await _thumbnailReference(thumbnail);
      if (thumb?.rawHash == entry.manifest.thumbnail?.rawHash) {
        thumb = entry.manifest.thumbnail;
      }
    } catch (error, stack) {
      // Cover enrichment is optional. An existing reference stays in the
      // revision while the newly obtained website facts can still publish.
      thumbnail = null;
      thumb = null;
      log.error('Website metadata cover enrichment failed', error, stack);
    }
    return _requestMetadataRevision(
      entry.manifestId,
      tags: [
        for (final namespace in detail.tags.entries)
          for (final tag in namespace.value)
            PortableTag(namespace.key, tag.tagData.key),
      ],
      lineageAdded: lineage,
      providerMetadata: provider,
      websiteDetail: detail,
      target: connection,
      thumbnail: thumb,
      thumbnailArtifact: thumbnail,
    );
  }

  Future<List<CloudGalleryEntry>> listHistory(CloudGalleryEntry head) async {
    final namespace = _connection().namespace;
    final rows = await repository.db
        .customSelect(
          "SELECT m.manifest_id, m.portable_json FROM content_manifest m "
          "JOIN content_remote_resource r ON r.target_namespace = m.target_namespace "
          "AND r.kind = 'manifest' AND r.object_hash = m.manifest_id "
          "WHERE m.target_namespace = ? AND m.gid = ? AND m.representation = ? "
          "ORDER BY m.imported_at DESC, m.manifest_id",
          variables: [
            Variable.withString(namespace),
            Variable.withInt(head.gid),
            Variable.withString(head.representation),
          ],
        )
        .get();
    final all = <String, PortableManifest>{
      for (final row in rows)
        row.read<String>('manifest_id'): PortableManifest.fromPortableJson(
          row.read<String>('portable_json'),
        ),
    };
    final visited = <String>{...head.equivalentManifestIds};
    final pending = <String>[...head.equivalentManifestIds];
    final history = <CloudGalleryEntry>[];
    for (final id in head.equivalentManifestIds) {
      final source = all[id];
      if (source == null || id == head.manifestId) continue;
      final local = await _localStatus(source);
      history.add(
        CloudGalleryEntry(
          gid: source.gid,
          representation: source.representation,
          title: source.title,
          manifestId: id,
          manifest: source,
          equivalentManifestIds: [id],
          localCopyId: local.copyId,
          localState: local.state,
        ),
      );
    }
    while (pending.isNotEmpty) {
      final id = pending.removeLast();
      final manifest = all[id];
      if (manifest == null) continue;
      for (final previousId in manifest.supersedes) {
        if (!visited.add(previousId)) continue;
        pending.add(previousId);
        final previous = all[previousId];
        if (previous == null) continue;
        final local = await _localStatus(previous);
        history.add(
          CloudGalleryEntry(
            gid: previous.gid,
            representation: previous.representation,
            title: previous.title,
            manifestId: previousId,
            manifest: previous,
            equivalentManifestIds: [previousId],
            localCopyId: local.copyId,
            localState: local.state,
          ),
        );
      }
    }
    return history;
  }

  Future<void> _launchRevision(String id, WebDavConnection connection) {
    if (!transferActivityService.canAdmit) return Future<void>.value();
    final existing = _runners[id];
    if (existing != null) return existing.done;
    final runner = _Runner();
    _runners[id] = runner;
    _updateScreenAwake();
    runner.done = _artifactSlots
        .withSlots(1, () async {
          await _runRevision(id, connection, runner);
        })
        .whenComplete(() async {
          _runners.remove(id);
          runner.uploadSpeed.dispose();
          notifyListeners();
          await _resumeRelease(id);
        });
    return runner.done;
  }

  Future<void> _runRevision(
    String id,
    WebDavConnection connection,
    _Runner runner,
  ) async {
    final client = WebDavClient(connection);
    try {
      _check(runner);
      final work = await repository.getWorkItem(id);
      if (work == null ||
          work.localArtifactPath == null ||
          work.remoteDestination == null)
        return;
      final manifestId =
          (jsonDecode(work.inputJson) as Map<String, dynamic>)['manifestId']
              as String;
      final artifact = ManifestArtifact(
        File(work.localArtifactPath!),
        manifestId,
      );
      final destination = work.remoteDestination!;
      final input = jsonDecode(work.inputJson) as Map<String, dynamic>;
      final manifest = await PortableManifestCodec.readAsync(artifact.file);
      runner.title = manifest.title;
      runner.phase = 'cloudPublishing';
      _updateScreenAwake();
      if (input['thumbnailPath'] case final String thumbnailPath) {
        final manifest = await PortableManifestCodec.readAsync(artifact.file);
        if (manifest.thumbnail case final thumbnail?) {
          await _publishThumbnail(
            client,
            id,
            File(thumbnailPath),
            thumbnail,
            runner,
          );
        }
      }
      await _clearWorkError(id);
      await client.ensureCollection('manifests/${manifestId.substring(0, 2)}');
      await client.ensureCollection('staging/$id');
      if (!await client.exists(destination)) {
        final stage = 'staging/$id/$manifestId';
        _check(runner);
        await client.putFile(
          stage,
          artifact.file,
          cancelToken: runner.cancelPut,
          onSendProgress: runner.uploadSpeed.requestProgress(),
        );
        _check(runner);
        try {
          await client.move(stage, destination);
        } on WebDavException {
          if (!await client.exists(destination)) rethrow;
        }
      }
      await _finishPublication(
        id,
        connection,
        manifestId,
        await PortableManifestCodec.readAsync(artifact.file),
        artifact: artifact,
      );
    } on _Stopped {
      // The work remains restartable.
    } catch (error, stack) {
      if (runner.stop) return;
      await _failWork(id, error);
      log.error('Cloud metadata revision failed', error, stack);
    } finally {
      client.close();
    }
  }

  Future<void> refresh() async {
    final connection = _connection();
    await _switchTarget(connection);
    final existing = _scan;
    if (existing != null && existing.namespace == connection.namespace)
      return existing.done;
    final runner = _ScanRunner(connection.namespace);
    _scan = runner;
    runner.done = _discover(connection, runner).whenComplete(() {
      if (identical(_scan, runner)) _scan = null;
      scanning = false;
      notifyListeners();
    });
    scanning = true;
    lastError = null;
    notifyListeners();
    return runner.done;
  }

  Future<void> ensureInitialDiscovery() async {
    if (!webDavSetting.isConfigured) return;
    final namespace = _connection().namespace;
    final rows = await repository.db
        .customSelect(
          "SELECT scan_state FROM content_remote_partition WHERE target_namespace = ? AND partition = '__root__'",
          variables: [Variable.withString(namespace)],
        )
        .get();
    final pendingImports = await repository.db
        .customSelect(
          "SELECT 1 FROM content_remote_resource r LEFT JOIN content_manifest m "
          "ON m.target_namespace = r.target_namespace AND m.manifest_id = r.object_hash "
          "WHERE r.target_namespace = ? AND r.kind = 'manifest' "
          'AND r.object_hash IS NOT NULL AND m.manifest_id IS NULL LIMIT 1',
          variables: [Variable.withString(namespace)],
        )
        .get();
    final partialPartitions = await repository.db
        .customSelect(
          "SELECT 1 FROM content_remote_partition WHERE target_namespace = ? AND partition != '__root__' AND scan_state = 'partial' LIMIT 1",
          variables: [Variable.withString(namespace)],
        )
        .get();
    if (rows.isEmpty ||
        rows.single.read<String>('scan_state') != 'complete' ||
        pendingImports.isNotEmpty ||
        partialPartitions.isNotEmpty) {
      await refresh();
    }
  }

  void _checkScan(_ScanRunner runner) {
    if (runner.stop) throw _Stopped();
  }

  Future<void> _discover(
    WebDavConnection connection,
    _ScanRunner runner,
  ) async {
    final client = WebDavClient(connection);
    try {
      _checkScan(runner);
      List<WebDavResource> root;
      try {
        root = await client.list('manifests', cancelToken: runner.cancel);
      } on WebDavException catch (error) {
        if (error.kind != WebDavErrorKind.missing) rethrow;
        _checkScan(runner);
        await _removeMissingPartitions(connection.namespace, const []);
        await repository.commitPartitionScan(
          targetNamespace: connection.namespace,
          partition: '__root__',
          scanState: 'complete',
          deletedHrefs: const [],
        );
        lastError = null;
        return;
      }
      _checkScan(runner);
      final partitions =
          root
              .where((item) => item.isCollection)
              .map((item) => _relative(connection, item.uri).split('/').last)
              .where((name) => RegExp(r'^[0-9a-f]{2}$').hasMatch(name))
              .toList()
            ..sort();
      final remaining = partitions.iterator;
      var failed = false;
      await Future.wait(
        partitions.take(contentTransferConcurrency).map((_) async {
          while (!failed) {
            _checkScan(runner);
            if (!remaining.moveNext()) return;
            final partition = remaining.current;
            try {
              await _scanPartition(client, connection, partition, runner);
            } catch (_) {
              failed = true;
              rethrow;
            }
          }
        }),
      );
      _checkScan(runner);
      await _removeMissingPartitions(connection.namespace, partitions);
      await repository.commitPartitionScan(
        targetNamespace: connection.namespace,
        partition: '__root__',
        scanState: 'complete',
        deletedHrefs: const [],
      );
      lastError = null;
    } on _Stopped {
      // The old target's scan stops before starting another request.
    } catch (error, stack) {
      if (runner.stop) return;
      lastError = webDavErrorText(error);
      log.error('Gallery discovery failed', error, stack);
      if (error is! WebDavException) {
        rethrow;
      }
    } finally {
      client.close();
      if (webDavSetting.isConfigured &&
          _connection().namespace == connection.namespace)
        await _notifyLocalLibrary();
    }
  }

  Future<void> _removeMissingPartitions(
    String namespace,
    List<String> present,
  ) async {
    final rows = await repository.db
        .customSelect(
          "SELECT partition FROM content_remote_partition WHERE target_namespace = ? AND partition != '__root__' "
          "UNION SELECT partition FROM content_remote_resource WHERE target_namespace = ? AND kind = 'manifest' AND partition IS NOT NULL",
          variables: [
            Variable.withString(namespace),
            Variable.withString(namespace),
          ],
        )
        .get();
    for (final row in rows) {
      final partition = row.read<String>('partition');
      if (present.contains(partition)) continue;
      await _markMissingPartition(namespace, partition);
    }
  }

  Future<void> _markMissingPartition(String namespace, String partition) async {
    final resources = await repository.db
        .customSelect(
          "SELECT href FROM content_remote_resource WHERE target_namespace = ? AND kind = 'manifest' AND partition = ?",
          variables: [
            Variable.withString(namespace),
            Variable.withString(partition),
          ],
        )
        .get();
    await repository.commitPartitionScan(
      targetNamespace: namespace,
      partition: partition,
      scanState: 'missing',
      deletedHrefs: resources.map((item) => item.read<String>('href')).toList(),
    );
    if (resources.isNotEmpty) _notifyCatalog();
  }

  Future<void> _scanPartition(
    WebDavClient client,
    WebDavConnection connection,
    String partition,
    _ScanRunner runner,
  ) async {
    try {
      await _scanPresentPartition(client, connection, partition, runner);
    } on WebDavException catch (error) {
      if (error.kind != WebDavErrorKind.missing) rethrow;
      _checkScan(runner);
      await _markMissingPartition(connection.namespace, partition);
    }
  }

  Future<void> _scanPresentPartition(
    WebDavClient client,
    WebDavConnection connection,
    String partition,
    _ScanRunner runner,
  ) async {
    _checkScan(runner);
    final existing = await repository.db
        .customSelect(
          'SELECT href, etag FROM content_remote_resource WHERE target_namespace = ? AND kind = ? AND partition = ?',
          variables: [
            Variable.withString(connection.namespace),
            Variable.withString('manifest'),
            Variable.withString(partition),
          ],
        )
        .get();
    final old = {
      for (final row in existing)
        row.read<String>('href'): row.readNullable<String>('etag'),
    };
    final tokenRows = await repository.db
        .customSelect(
          'SELECT sync_token, scan_state FROM content_remote_partition WHERE target_namespace = ? AND partition = ?',
          variables: [
            Variable.withString(connection.namespace),
            Variable.withString(partition),
          ],
        )
        .get();
    String? token = tokenRows.isEmpty
        ? null
        : tokenRows.single.read<String>('scan_state') == 'partial'
        ? null
        : tokenRows.single.readNullable<String>('sync_token');
    WebDavSyncResult? delta;
    try {
      delta = await client.syncCollection(
        'manifests/$partition',
        token,
        cancelToken: runner.cancel,
      );
    } on WebDavException catch (error) {
      if (token == null || (error.statusCode != 403 && error.statusCode != 409))
        rethrow;
      // A server may expire an old token. Start this partition again.
      token = null;
      _checkScan(runner);
      delta = await client.syncCollection(
        'manifests/$partition',
        null,
        cancelToken: runner.cancel,
      );
    }
    final fullEnumeration = token == null;
    if (delta != null) {
      final observed = <String>{};
      do {
        _checkScan(runner);
        final changed = <({String href, String id, String? etag})>[];
        for (final resource in delta!.changed.where(
          (item) => !item.isCollection,
        )) {
          final item = _manifestResource(connection, partition, resource);
          if (item != null) {
            observed.add(item.href);
            changed.add(item);
          }
        }
        final deleted = delta.deleted
            .map((uri) => _relative(connection, uri))
            .toList();
        await repository.db.transaction(() async {
          for (final item in changed) {
            await repository.recordRemoteResource(
              targetNamespace: connection.namespace,
              href: item.href,
              kind: 'manifest',
              objectHash: item.id,
              etag: item.etag,
              partition: partition,
            );
          }
          await repository.commitPartitionScan(
            targetNamespace: connection.namespace,
            partition: partition,
            scanState: delta!.truncated ? 'partial' : 'complete',
            syncToken: delta.syncToken,
            deletedHrefs: [
              ...deleted,
              if (!delta.truncated && fullEnumeration)
                ...old.keys.where((href) => !observed.contains(href)),
            ],
          );
        });
        await _materializePendingManifests(
          client,
          connection,
          partition,
          runner,
        );
        token = delta.syncToken;
        _notifyCatalog();
        if (!delta.truncated) break;
        _checkScan(runner);
        delta = await client.syncCollection(
          'manifests/$partition',
          token,
          cancelToken: runner.cancel,
        );
        if (delta == null)
          throw const WebDavException(
            WebDavErrorKind.invalidResponse,
            'WebDAV sync support changed',
          );
      } while (true);
      return;
    }
    _checkScan(runner);
    final resources = await client.list(
      'manifests/$partition',
      cancelToken: runner.cancel,
    );
    final observed = <String>{};
    final changed = <({String href, String id, String? etag})>[];
    for (final resource in resources.where((item) => !item.isCollection)) {
      final item = _manifestResource(connection, partition, resource);
      if (item == null) continue;
      observed.add(item.href);
      changed.add(item);
    }
    await repository.db.transaction(() async {
      for (final item in changed) {
        await repository.recordRemoteResource(
          targetNamespace: connection.namespace,
          href: item.href,
          kind: 'manifest',
          objectHash: item.id,
          etag: item.etag,
          partition: partition,
        );
      }
      await repository.commitPartitionScan(
        targetNamespace: connection.namespace,
        partition: partition,
        scanState: 'complete',
        deletedHrefs: old.keys
            .where((href) => !observed.contains(href))
            .toList(),
      );
    });
    await _materializePendingManifests(client, connection, partition, runner);
    _notifyCatalog();
  }

  ({String href, String id, String? etag})? _manifestResource(
    WebDavConnection connection,
    String partition,
    WebDavResource resource,
  ) {
    final href = _relative(connection, resource.uri);
    final match = RegExp(r'^manifests/([0-9a-f]{2})/([0-9a-f]{64})\.sqlite$')
        .firstMatch(href);
    if (match == null ||
        match.group(1) != partition ||
        match.group(2)!.substring(0, 2) != partition)
      return null;
    final id = match.group(2)!;
    return (href: href, id: id, etag: resource.etag);
  }

  Future<void> _materializePendingManifests(
    WebDavClient client,
    WebDavConnection connection,
    String partition,
    _ScanRunner runner,
  ) async {
    final missing = await repository.db
        .customSelect(
          "SELECT r.href, r.object_hash FROM content_remote_resource r "
          "LEFT JOIN content_manifest m ON m.target_namespace = r.target_namespace AND m.manifest_id = r.object_hash "
          "WHERE r.target_namespace = ? AND r.kind = 'manifest' AND r.partition = ? "
          'AND r.object_hash IS NOT NULL AND m.manifest_id IS NULL ORDER BY r.href',
          variables: [
            Variable.withString(connection.namespace),
            Variable.withString(partition),
          ],
        )
        .get();
    for (final row in missing) {
      _checkScan(runner);
      final href = row.read<String>('href');
      final id = row.read<String>('object_hash');
      final artifact = File(
        p.join(_artifactDir.path, 'discovery', '$id.sqlite'),
      );
      await artifact.parent.create(recursive: true);
      if (await artifact.exists()) await artifact.delete();
      try {
        final receivedHash = await client.getFile(
          href,
          artifact,
          resume: false,
          cancelToken: runner.cancel,
        );
        if (receivedHash != id) {
          throw const FormatException('Downloaded manifest hash mismatch');
        }
        await repository.importManifest(
          connection.namespace,
          ManifestArtifact(artifact, id),
        );
      } on WebDavException catch (error) {
        if (error.kind != WebDavErrorKind.missing) rethrow;
        await repository.db.customStatement(
          'DELETE FROM content_remote_resource WHERE target_namespace = ? AND href = ?',
          [connection.namespace, href],
        );
        _notifyCatalog();
        continue;
      } finally {
        if (await artifact.exists()) await artifact.delete();
      }
      _notifyCatalog();
    }
  }

  static String _relative(WebDavConnection connection, Uri resource) {
    final prefix = connection
        .uri('', directory: true)
        .pathSegments
        .where((item) => item.isNotEmpty)
        .toList();
    final parts = resource.pathSegments
        .where((item) => item.isNotEmpty)
        .toList();
    if (resource.origin != connection.address.origin ||
        parts.length < prefix.length ||
        !listEquals(parts.take(prefix.length).toList(), prefix)) {
      throw const WebDavException(
        WebDavErrorKind.invalidResponse,
        'WebDAV resource escaped the configured root',
      );
    }
    return parts.skip(prefix.length).join('/');
  }

  Future<List<ManifestHeadGroup>> _availableHeads(
    String namespace,
    int gid,
    String representation,
  ) async {
    final rows = await repository.db
        .customSelect(
          "SELECT m.manifest_id, m.portable_json FROM content_manifest m "
          "JOIN content_remote_resource r ON r.target_namespace = m.target_namespace "
          "AND r.kind = 'manifest' AND r.object_hash = m.manifest_id "
          "WHERE m.target_namespace = ? AND m.gid = ? AND m.representation = ? "
          "ORDER BY m.imported_at DESC, m.manifest_id",
          variables: [
            Variable.withString(namespace),
            Variable.withInt(gid),
            Variable.withString(representation),
          ],
        )
        .get();
    final manifests = <String, PortableManifest>{
      for (final row in rows)
        row.read<String>('manifest_id'): PortableManifest.fromPortableJson(
          row.read<String>('portable_json'),
        ),
    };
    final superseded = <String>{
      for (final item in manifests.values) ...item.supersedes,
    };
    final groups = <ManifestHeadGroup>[];
    for (final entry in manifests.entries) {
      if (superseded.contains(entry.key)) continue;
      final existing = groups.indexWhere(
        (group) => group.representative.businessEquivalentTo(entry.value),
      );
      if (existing < 0) {
        groups.add(ManifestHeadGroup(entry.value, [entry.key]));
      } else {
        groups[existing].manifestIds.add(entry.key);
      }
    }
    return groups;
  }

  /// One index read; facets and list grouping never reopen page files.
  Future<
    List<
      ({
        PortableManifest manifest,
        List<String> ids,
        List<PortableTag> tags,
        List<String> collections,
      })
    >
  >
  _catalogHeads({String? namespace}) async {
    if (!webDavSetting.isConfigured) return [];
    final rows = await repository.db
        .customSelect(
          "SELECT m.manifest_id, m.portable_json FROM content_manifest m "
          "JOIN content_remote_resource r ON r.target_namespace = m.target_namespace "
          "AND r.kind = 'manifest' AND r.object_hash = m.manifest_id "
          "WHERE m.target_namespace = ? ORDER BY m.imported_at DESC, m.manifest_id",
          variables: [
            Variable.withString(namespace ?? _connection().namespace),
          ],
        )
        .get();
    final manifests = {
      for (final row in rows)
        row.read<String>('manifest_id'): PortableManifest.fromPortableJson(
          row.read<String>('portable_json'),
        ),
    };
    final superseded = {
      for (final manifest in manifests.values) ...manifest.supersedes,
    };
    final groups =
        <
          ({
            PortableManifest manifest,
            List<String> ids,
            List<PortableTag> tags,
            List<String> collections,
          })
        >[];
    for (final entry in manifests.entries) {
      if (superseded.contains(entry.key)) continue;
      final index = groups.indexWhere(
        (group) => group.manifest.samePagesAs(entry.value),
      );
      if (index < 0) {
        groups.add((
          manifest: entry.value,
          ids: [entry.key],
          tags: [...entry.value.tags],
          collections: [...entry.value.collections],
        ));
      } else {
        final group = groups[index];
        group.ids.add(entry.key);
        for (final tag in entry.value.tags) {
          if (!group.tags.any(
            (old) => old.namespace == tag.namespace && old.name == tag.name,
          ))
            group.tags.add(tag);
        }
        for (final collection in entry.value.collections) {
          if (!group.collections.contains(collection))
            group.collections.add(collection);
        }
        // Relations from concurrent current heads remain visible until an
        // explicit revision supersedes those heads.
        final edges = {
          for (final edge in [
            ...group.manifest.lineage,
            ...entry.value.lineage,
          ])
            '${edge.fromGid}:${edge.toGid}:${edge.kind}': edge,
        }.values.toList();
        groups[index] = (
          manifest: group.manifest.copyWith(lineage: edges),
          ids: group.ids,
          tags: group.tags,
          collections: group.collections,
        );
      }
    }
    return groups;
  }

  Future<CloudGalleryFacets> listCloudFacets() async {
    final heads = await _catalogHeads();
    final categories = {
      for (final head in heads)
        if (head.manifest.category case final category?) category,
    }.toList()..sort();
    final collections = {for (final head in heads) ...head.collections}.toList()
      ..sort();
    final tags =
        {
          for (final head in heads)
            for (final tag in head.tags)
              '${tag.namespace}\u0000${tag.name}': tag,
        }.values.toList()..sort(
          (a, b) =>
              '${a.namespace}:${a.name}'.compareTo('${b.namespace}:${b.name}'),
        );
    return CloudGalleryFacets(
      categories: categories,
      collections: collections,
      tags: tags,
    );
  }

  Future<List<CloudGalleryEntry>> listCloudEntries({
    String search = '',
    String? representation,
    String? category,
    String? collection,
    PortableTag? tag,
    int offset = 0,
    int limit = 40,
  }) async {
    if (!webDavSetting.isConfigured) return [];
    final groups = await _catalogHeads();
    final familyIndex = _GalleryFamilyIndex(
      groups.map((group) => group.manifest),
    );
    final needle = search.trim().toLowerCase();
    final filtered = groups.where((group) {
      final manifest = group.manifest;
      if (representation != null && manifest.representation != representation)
        return false;
      if (category != null && manifest.category != category) return false;
      if (collection != null && !group.collections.contains(collection))
        return false;
      if (tag != null &&
          !group.tags.any(
            (value) =>
                value.namespace == tag.namespace && value.name == tag.name,
          ))
        return false;
      final searchable = [
        manifest.title,
        manifest.rawTitle,
        manifest.japaneseTitle,
        '${manifest.gid}',
        manifest.uploader,
        for (final value in group.tags) '${value.namespace}:${value.name}',
      ];
      return needle.isEmpty ||
          searchable.any(
            (value) => value?.toLowerCase().contains(needle) ?? false,
          );
    }).toList();
    filtered.sort((a, b) {
      final family = familyIndex
          .find(b.manifest.gid)
          .compareTo(familyIndex.find(a.manifest.gid));
      if (family != 0) return family;
      final aPreferred = !familyIndex.supersededGids.contains(a.manifest.gid);
      final bPreferred = !familyIndex.supersededGids.contains(b.manifest.gid);
      if (aPreferred != bPreferred) return aPreferred ? -1 : 1;
      return b.manifest.gid.compareTo(a.manifest.gid);
    });
    final families = filtered
        .map((group) => familyIndex.find(group.manifest.gid))
        .toSet()
        .toList();
    final page = families.skip(offset).take(limit).toSet();
    final entries = <CloudGalleryEntry>[];
    for (final group in filtered) {
      final manifest = group.manifest;
      final family = familyIndex.find(manifest.gid);
      if (!page.contains(family)) continue;
      final local = await _localStatus(manifest);
      entries.add(
        CloudGalleryEntry(
            gid: manifest.gid,
            representation: manifest.representation,
            title: manifest.title,
            manifestId: group.ids.first,
            manifest: manifest,
            equivalentManifestIds: List.unmodifiable(group.ids),
            aggregatedTags: List.unmodifiable(group.tags),
            aggregatedCollections: List.unmodifiable(group.collections),
            localCopyId: local.copyId,
            localState: local.state,
          )
          ..familyKey = family
          ..preferred = !familyIndex.supersededGids.contains(manifest.gid),
      );
    }
    return entries;
  }

  Future<File?> thumbnailFile(CloudGalleryEntry entry) =>
      _thumbnailFile(entry, _connection());

  Future<File?> _thumbnailFile(
    CloudGalleryEntry entry,
    WebDavConnection connection,
  ) async {
    final key = '${connection.namespace}:${entry.manifestId}';
    final pending = _thumbnailReads.putIfAbsent(key, () async {
      final cached = entry.manifest.thumbnail == null
          ? _generatedThumbnailFile(entry.manifest.pages.first.rawHash)
          : File(
              p.join(
                _artifactDir.path,
                'thumbnails',
                entry.manifest.thumbnail!.objectHash,
              ),
            );
      if (await cached.exists()) return cached;
      // The same existing lease covers input, decode, render and temporary
      // cleanup. Helpers below never acquire another lease.
      return _artifactSlots.withSlots(
        1,
        () => _readThumbnail(entry, connection),
      );
    });
    try {
      return await pending;
    } finally {
      if (identical(_thumbnailReads[key], pending)) _thumbnailReads.remove(key);
    }
  }

  Future<File?> _readThumbnail(
    CloudGalleryEntry entry,
    WebDavConnection connection,
  ) async {
    final client = WebDavClient(connection);
    final stage = Directory(
      p.join(_artifactDir.path, 'thumbnail-work', const Uuid().v4()),
    );
    await stage.create(recursive: true);
    try {
      if (entry.manifest.thumbnail case final thumbnail?) {
        final target = File(
          p.join(_artifactDir.path, 'thumbnails', thumbnail.objectHash),
        );
        if (await target.exists()) return target;
        final temporary = File(p.join(stage.path, 'thumbnail'));
        try {
          final hash = await client.getFile(
            _objectPath(thumbnail.objectHash),
            temporary,
            resume: false,
          );
          if (hash != thumbnail.rawHash ||
              await temporary.length() != thumbnail.rawLength) {
            throw const FormatException('Invalid cloud thumbnail');
          }
          await target.parent.create(recursive: true);
          return await temporary.rename(target.path);
        } catch (error, stack) {
          log.error(
            'Read cloud thumbnail failed; trying cover sources',
            error,
            stack,
          );
        }
      }
      final first = entry.manifest.pages.first;
      final target = _generatedThumbnailFile(first.rawHash);
      if (await target.exists()) return target;
      final copyId = entry.localCopyId ?? await _matchingCopy(entry.manifest);
      if (copyId != null) {
        try {
          return await _renderThumbnailBytes(
            await localContentService.readPageForDisplay(copyId, 0),
            target,
          );
        } catch (error, stack) {
          log.error(
            'Generate local thumbnail failed; trying cover sources',
            error,
            stack,
          );
        }
      }
      if (entry.manifest.coverUrl case final url? when url.isNotEmpty) {
        final cover = File(p.join(stage.path, 'cover'));
        try {
          await ehRequest.download(url: url, path: cover.path);
          return await _renderThumbnail(cover, target);
        } catch (error, stack) {
          log.error(
            'Read website cover failed; trying first cloud page',
            error,
            stack,
          );
        }
      }
      final object = File(p.join(stage.path, 'page.object'));
      final objectHash = await client.getFile(
        _objectPath(first.objectHash),
        object,
        resume: false,
      );
      if (objectHash != first.objectHash ||
          await object.length() != first.storedLength) {
        throw const FormatException('Cloud cover page identity mismatch');
      }
      return await _renderThumbnailBytes(
        await codec.decodeImageForDisplay(
          inputPath: object.path,
          codecProfile: first.codecProfile,
        ),
        target,
      );
    } finally {
      client.close();
      if (await stage.exists()) await stage.delete(recursive: true);
    }
  }

  File _generatedThumbnailFile(String rawHash) =>
      File(p.join(_artifactDir.path, 'thumbnails', '$rawHash-small.png'));

  Future<File> _renderThumbnail(File source, File target) async =>
      _renderThumbnailBytes(await source.readAsBytes(), target);

  Future<File> _renderThumbnailBytes(Uint8List bytes, File target) async {
    // The list cover is 88 logical pixels wide. 264 physical pixels preserves
    // its detail on 3x displays; this is display sizing, not an input limit.
    final decoder = await ui.instantiateImageCodec(bytes, targetWidth: 264);
    try {
      final frame = await decoder.getNextFrame();
      try {
        final data = await frame.image.toByteData(
          format: ui.ImageByteFormat.png,
        );
        if (data == null) throw StateError('Could not encode thumbnail');
        await target.parent.create(recursive: true);
        final temporary = File('${target.path}.${const Uuid().v4()}.tmp');
        try {
          await temporary.writeAsBytes(
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          );
          return await temporary.rename(target.path);
        } finally {
          if (await temporary.exists()) await temporary.delete();
        }
      } finally {
        frame.image.dispose();
      }
    } finally {
      decoder.dispose();
    }
  }

  Future<PortableThumbnail> _thumbnailReference(File file) async {
    final hash = (await sha256.bind(file.openRead()).first).toString();
    return PortableThumbnail(
      rawHash: hash,
      rawLength: await file.length(),
      objectHash: hash,
      mime: 'image/png',
    );
  }

  Future<void> _publishThumbnail(
    WebDavClient client,
    String id,
    File file,
    PortableThumbnail thumbnail,
    _Runner runner,
  ) async {
    final destination = _objectPath(thumbnail.objectHash);
    await client.ensureCollection(
      'objects/${thumbnail.objectHash.substring(0, 2)}',
    );
    await client.ensureCollection('staging/$id');
    if (await client.exists(destination)) return;
    _check(runner);
    final stage = 'staging/$id/${thumbnail.objectHash}';
    await client.putFile(
      stage,
      file,
      cancelToken: runner.cancelPut,
      onSendProgress: runner.uploadSpeed.requestProgress(),
    );
    _check(runner);
    try {
      await client.move(stage, destination);
    } on WebDavException {
      if (!await client.exists(destination)) rethrow;
    }
  }

  Future<List<CloudSyncJob>> listSyncJobs({String? finishAction}) async {
    if (!webDavSetting.isConfigured) return [];
    final rows = await repository.db
        .customSelect(
          r'''
        SELECT w.work_item_id, w.kind, w.state, w.finish_action,
          CASE WHEN w.kind IN ('revision', 'restore') THEN COALESCE(m.title, '')
            ELSE COALESCE(json_extract(w.input_json, '$.title'), 'cloudWaitingInput') END AS title,
          CASE WHEN w.kind = 'restore' THEN COALESCE(json_array_length(m.portable_json, '$.pages'), 0)
            WHEN w.kind = 'revision' THEN 0
            ELSE COALESCE(json_array_length(w.input_json, '$.pages'), 0) END AS total_pages,
          CASE WHEN w.kind = 'restore' THEN (SELECT COUNT(*) FROM content_page p WHERE p.copy_id = w.copy_id AND p.state = 'completed')
            WHEN w.kind = 'revision' THEN 0
            ELSE COALESCE(json_array_length(w.artifacts_json, '$._completedOrdinals'), 0) END AS completed_pages,
          CASE WHEN json_type(w.artifacts_json, '$._error') = 'object'
            THEN json_extract(w.artifacts_json, '$._error') END AS error_json
        FROM content_work_item w
        LEFT JOIN content_manifest m ON w.kind IN ('revision', 'restore')
          AND m.target_namespace = w.target_namespace AND m.manifest_id = w.input_manifest_id
        WHERE w.target_namespace = ? AND w.kind IN ('content', 'revision', 'restore')
          AND w.state NOT IN ('completed', 'cancelled')
      ''' +
              (finishAction == null ? '' : ' AND w.finish_action = ?') +
              ' ORDER BY w.created_at, w.work_item_id',
          variables: [
            Variable.withString(_connection().namespace),
            if (finishAction != null) Variable.withString(finishAction),
          ],
        )
        .get();
    return rows.map((row) {
      final error = row.readNullable<String>('error_json');
      return CloudSyncJob(
        row.read<String>('work_item_id'),
        row.read<String>('kind'),
        row.read<String>('title'),
        row.read<String>('state'),
        row.read<int>('completed_pages'),
        row.read<int>('total_pages'),
        error: WebDavFailure.fromJson(error == null ? null : jsonDecode(error)),
        finishAction: row.read<String>('finish_action'),
        uploadSpeed:
            (_runners[row.read<String>('work_item_id')] ??
                    _restores[row.read<String>('work_item_id')])
                ?.uploadSpeed
                .listenable,
      );
    }).toList();
  }

  Future<({String? copyId, CloudLocalState state})> _localStatus(
    PortableManifest manifest,
  ) async {
    final rows = await repository.db
        .customSelect(
          "SELECT copy_id, lifecycle, cleanup_state FROM content_copy WHERE gid = ? AND representation = ? AND metadata_json IS NOT NULL ORDER BY created_at DESC",
          variables: [
            Variable.withInt(manifest.gid),
            Variable.withString(manifest.representation),
          ],
        )
        .get();
    ({String? copyId, CloudLocalState state}) result = (
      copyId: null,
      state: CloudLocalState.none,
    );
    for (final row in rows) {
      final pages = await repository.listPages(row.read<String>('copy_id'));
      if (pages.length != manifest.pages.length) continue;
      if (pages.asMap().entries.every(
        (entry) =>
            entry.value.state == 'completed' &&
            entry.value.ordinal == entry.key &&
            entry.value.rawHash == manifest.pages[entry.key].rawHash,
      )) {
        if (row.read<String>('lifecycle') == 'active') {
          return (
            copyId: row.read<String>('copy_id'),
            state: CloudLocalState.available,
          );
        }
        if (result.state == CloudLocalState.none) {
          result = (
            copyId: null,
            state: row.readNullable<String>('cleanup_state') == 'completed'
                ? CloudLocalState.released
                : CloudLocalState.releasing,
          );
        }
      }
    }
    return result;
  }

  Future<String> cleanupLocal(CloudGalleryEntry entry) {
    final copyId = entry.localCopyId;
    if (copyId == null || entry.localState != CloudLocalState.available) {
      throw StateError('No local copy to clean');
    }
    return requestUpload(copyId, cleanupAfterUpload: true);
  }

  /// Returns the local copy ID. Restoration is journaled and replayable.
  Future<String> restore(String manifestId) async {
    final connection = _connection();
    await _switchTarget(connection);
    final remote = await repository.db
        .customSelect(
          "SELECT 1 FROM content_remote_resource WHERE target_namespace = ? AND kind = 'manifest' AND object_hash = ? LIMIT 1",
          variables: [
            Variable.withString(connection.namespace),
            Variable.withString(manifestId),
          ],
        )
        .get();
    if (remote.isEmpty) throw StateError('云端清单已不可用，请刷新');
    final rows = await repository.db
        .customSelect(
          'SELECT portable_json FROM content_manifest WHERE target_namespace = ? AND manifest_id = ?',
          variables: [
            Variable.withString(connection.namespace),
            Variable.withString(manifestId),
          ],
        )
        .get();
    if (rows.isEmpty) throw StateError('云端内容尚未发现');
    final manifest = PortableManifest.fromPortableJson(
      rows.single.read<String>('portable_json'),
    );
    final pending = await repository.listWorkItems(
      kind: 'restore',
      targetNamespace: connection.namespace,
    );
    for (final work in pending.where(
      (item) => item.inputManifestId == manifestId,
    )) {
      if (work.state == 'failed' || work.state == 'paused')
        await repository.updateWorkItemState(work.workItemId, 'queued');
      await _launchRestore(work, connection);
      return work.copyId!;
    }
    final local = await _matchingCopy(manifest);
    if (local != null) return local;
    final copyId = const Uuid().v4();
    final root = p.join(
      downloadSetting.downloadPath.value,
      'cloud-${manifest.gid}-$copyId',
    );
    final work = await repository.createWorkItem(
      kind: 'restore',
      targetNamespace: connection.namespace,
      inputManifestId: manifestId,
      inputJson: jsonEncode({
        'manifestId': manifestId,
        'title': manifest.title,
        'pageCount': manifest.pages.length,
        'copyId': copyId,
        'rootPath': root,
      }),
      copyId: copyId,
    );
    await _launchRestore(work, connection);
    return copyId;
  }

  Future<void> _launchRestore(
    ContentWorkRecord work,
    WebDavConnection connection,
  ) {
    if (work.copyId != null && localContentService.isRelocating(work.copyId!)) {
      return Future<void>.value();
    }
    if (!transferActivityService.canAdmit) return Future<void>.value();
    final existing = _restores[work.workItemId];
    if (existing != null) return existing.done;
    final input = jsonDecode(work.inputJson) as Map<String, dynamic>;
    final runner = _Runner()
      ..copyId = work.copyId
      ..title = input['title'] as String? ?? 'cloudDownloading'
      ..totalPages = input['pageCount'] as int? ?? 0
      ..phase = 'cloudDownloading';
    _restores[work.workItemId] = runner;
    _updateScreenAwake();
    runner.done = _restoreWork(work, connection, runner)
        .catchError((Object error, StackTrace stack) async {
          if (runner.stop || error is _Stopped) return;
          await _failWork(work.workItemId, error);
          Error.throwWithStackTrace(error, stack);
        })
        .whenComplete(() {
          _restores.remove(work.workItemId);
          runner.uploadSpeed.dispose();
          notifyListeners();
        });
    return runner.done;
  }

  Future<String?> _matchingCopy(PortableManifest manifest) async {
    final rows = await repository.db
        .customSelect(
          "SELECT copy_id FROM content_copy WHERE gid = ? AND representation = ? AND lifecycle = 'active' AND metadata_json IS NOT NULL",
          variables: [
            Variable.withInt(manifest.gid),
            Variable.withString(manifest.representation),
          ],
        )
        .get();
    for (final row in rows) {
      final copyId = row.read<String>('copy_id');
      final pages = await repository.listPages(copyId);
      if (pages.length == manifest.pages.length &&
          pages.asMap().entries.every(
            (entry) =>
                entry.value.state == 'completed' &&
                entry.value.ordinal == entry.key &&
                entry.value.rawHash == manifest.pages[entry.key].rawHash,
          )) {
        if (await localContentService.completedInput(copyId) != null)
          return copyId;
      }
    }
    return null;
  }

  Future<void> _restoreWork(
    ContentWorkRecord work,
    WebDavConnection connection,
    _Runner runner,
  ) async {
    _check(runner);
    await _clearWorkError(work.workItemId);
    final data = jsonDecode(work.inputJson) as Map<String, dynamic>;
    final copyId = data['copyId'] as String;
    final root =
        localContentService.registeredRoot(copyId) ??
        data['rootPath'] as String;
    final manifestId = data['manifestId'] as String;
    final rows = await repository.db
        .customSelect(
          'SELECT portable_json FROM content_manifest WHERE target_namespace = ? AND manifest_id = ?',
          variables: [
            Variable.withString(connection.namespace),
            Variable.withString(manifestId),
          ],
        )
        .get();
    if (rows.isEmpty) throw StateError('Missing manifest $manifestId');
    final manifest = PortableManifest.fromPortableJson(
      rows.single.read<String>('portable_json'),
    );
    runner.title = manifest.title;
    runner.phase = 'cloudDownloading';
    runner.totalPages = manifest.pages.length;
    runner.completedPages = 0;
    _check(runner);
    final started = await repository.db.customUpdate(
      "UPDATE content_work_item SET state = 'running' WHERE work_item_id = ? AND state IN ('queued', 'running')",
      variables: [Variable.withString(work.workItemId)],
    );
    if (started == 0) throw _Stopped();
    _check(runner);
    notifyListeners();
    await Directory(root).create(recursive: true);
    await localContentService.ensureCopy(
      copyId: copyId,
      gid: manifest.gid,
      representation: manifest.representation,
      rootPath: root,
      makeCurrent: false,
    );
    final client = WebDavClient(connection);
    try {
      for (var index = 0; index < manifest.pages.length; index++) {
        _check(runner);
        final page = manifest.pages[index];
        ContentPageRecord? current;
        try {
          current = await repository.getPage(copyId, index);
        } on StateError {
          // The page has not been restored yet.
        }
        if (current != null &&
            current.state == 'completed' &&
            current.rawHash == page.rawHash &&
            await File(p.join(root, current.relativePath)).exists()) {
          runner.completedPages++;
          _updateScreenAwake();
          continue;
        }
        final pageLease = await _artifactSlots.acquire(1);
        try {
          _check(runner);
          final extension = _extension(page.mime);
          final relative =
              '${(index + 1).toString().padLeft(4, '0')}.$extension${page.codecProfile == 'raw' ? '' : '.pcf'}';
          final destination = File(p.join(root, relative));
          final localStage = Directory(p.join(root, '.content-work'));
          await localStage.create(recursive: true);
          final object = File(p.join(localStage.path, '$index.object'));
          final objectHash = await client.getFile(
            _objectPath(page.objectHash),
            object,
            cancelToken: runner.cancelPut,
            onReceiveProgress: runner.uploadSpeed.requestProgress(),
          );
          _check(runner);
          if (objectHash != page.objectHash ||
              await object.length() != page.storedLength) {
            if (await object.exists()) await object.delete();
            throw const FormatException('Cloud object identity mismatch');
          }
          if (await destination.exists()) await destination.delete();
          await object.rename(destination.path);
          await localContentService.recordPage(
            copyId: copyId,
            ordinal: index,
            relativePath: relative,
            rawHash: page.rawHash,
            rawLength: page.rawLength,
            mime: page.mime,
            width: page.width,
            height: page.height,
            sourcePageUrl: page.sourcePageUrl,
            codecProfile: page.codecProfile,
            objectHash: page.codecProfile == 'raw' ? null : page.objectHash,
            storedLength: page.codecProfile == 'raw' ? null : page.storedLength,
          );
          runner.completedPages++;
          notifyListeners();
        } finally {
          pageLease.release();
        }
      }
      _check(runner);
      await localContentService.completeCopy(
        copyId,
        galleryUrl: manifest.galleryUrl,
        title: manifest.title,
        tags: manifest.tags,
        providerMetadata: manifest.providerMetadata,
        collections: manifest.collections,
        lineage: manifest.lineage,
        expectedPages: manifest.pages.length,
      );
      await repository.db.transaction(() async {
        _check(runner);
        final current = await repository.getWorkItem(work.workItemId);
        _check(runner);
        if (current?.state != 'running') throw _Stopped();
        await repository.handoffCopy(copyId, connection.namespace);
        _check(runner);
        final completed = await repository.db.customUpdate(
          "UPDATE content_work_item SET state = 'completed' WHERE work_item_id = ? AND state = 'running'",
          variables: [Variable.withString(work.workItemId)],
        );
        if (completed == 0) throw _Stopped();
      });
      await localContentService.finishCloudHandoff(copyId);
      _notifyCatalog();
    } finally {
      client.close();
    }
  }

  static String _extension(String mime) => switch (mime) {
    'image/jpeg' => 'jpg',
    'image/png' => 'png',
    'image/webp' => 'webp',
    'image/avif' => 'avif',
    'image/gif' => 'gif',
    _ => 'bin',
  };

  static String _objectPath(String hash) =>
      'objects/${hash.substring(0, 2)}/$hash';
  static String _manifestPath(String id) =>
      'manifests/${id.substring(0, 2)}/$id.sqlite';
}
