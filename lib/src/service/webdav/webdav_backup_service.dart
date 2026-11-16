import '../transfer_activity_service.dart';
import '../gallery_sync/upload_speed.dart';

import 'package:dio/dio.dart';

import '../screen_awake_service.dart';

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../database/database.dart';
import '../../setting/webdav_setting.dart';
import '../content_sync/content_repository.dart';
import '../jh_service.dart';
import '../local_backup_service.dart';
import '../log.dart';
import '../path_service.dart';
import 'webdav_client.dart';

WebDavBackupService webDavBackupService = WebDavBackupService();

class WebDavBackupSnapshot {
  final String deviceId;
  final String snapshotId;
  final String remotePath;
  final DateTime? modified;
  final int? size;

  const WebDavBackupSnapshot({
    required this.deviceId,
    required this.snapshotId,
    required this.remotePath,
    this.modified,
    this.size,
  });
}

class WebDavBackupService
    with JHLifeCircleBeanErrorCatch
    implements JHLifeCircleBean {
  late final Directory _artifactDirectory;
  late final String deviceId;
  final Map<String, Future<void>> _inflight = {};
  final Set<String> _queued = {};
  final Map<String, CancelToken> _tokens = {};
  final Map<String, UploadSpeed> _speeds = {};
  final Map<String, bool> _directions = {};
  final Map<String, int> _progress = {}, _totals = {};

  ProgressCallback _requestProgress(String id) {
    final recordSpeed = _speeds[id]!.requestProgress();
    return (current, total) {
      _progress[id] = current;
      if (total > 0) _totals[id] = total;
      recordSpeed(current, total);
    };
  }

  void _updateActivities() {
    transferActivityService.replace(this, [
      for (final id in _queued)
        if (!_tokens.containsKey(id))
          TransferActivity(
            id: 'backup:$id',
            title: 'webdavBackupTransfer',
            target: 'cloud',
            upload: true,
            waiting: true,
            bytesPerSecond: () => 0,
          ),
      for (final entry in _tokens.entries)
        if (!entry.value.isCancelled)
          TransferActivity(
            id: 'backup:${entry.key}',
            title: 'webdavBackupTransfer',
            target: 'cloud',
            upload: _directions[entry.key] ?? true,
            byteProgress: true,
            readProgress: () => _progress[entry.key],
            readTotal: () => _totals[entry.key],
            bytesPerSecond: () => _speeds[entry.key]?.bytesPerSecond ?? 0,
          ),
    ]);
  }

  Future<void> _suspendForSystem() async {
    for (final token in _tokens.values) {
      token.cancel('System dataSync timeout');
    }
    _updateActivities();
    await Future.wait([
      ..._inflight.values.map(
        (work) => work.catchError((Object _, StackTrace __) {}),
      ),
      ..._downloadAttempts.values.map(
        (work) =>
            work.then<void>((_) {}, onError: (Object _, StackTrace __) {}),
      ),
    ]);
  }

  void _beginActivity(String id, bool upload) {
    _tokens[id] = CancelToken();
    _speeds[id] = UploadSpeed();
    _directions[id] = upload;
    _updateActivities();
  }

  void _endActivity(String id) {
    _tokens.remove(id);
    _speeds.remove(id)?.dispose();
    _directions.remove(id);
    _progress.remove(id);
    _totals.remove(id);
    _updateActivities();
  }

  final Map<String, Future<String>> _downloads = {};
  final Map<String, Future<String>> _downloadAttempts = {};

  @override
  List<JHLifeCircleBean> get initDependencies => [
    pathService,
    log,
    webDavSetting,
    screenAwakeService,
    transferActivityService,
  ];

  @override
  Future<void> doInitBean() async {
    transferActivityService.register(
      this,
      suspend: _suspendForSystem,
      resume: resumePending,
    );
    final home =
        pathService.appSupportDir ??
        pathService.appDocDir ??
        pathService.getVisibleDir();
    _artifactDirectory = Directory(
      p.join(home.path, 'webdav-backup-artifacts'),
    );
    await _artifactDirectory.create(recursive: true);
    final idFile = File(p.join(_artifactDirectory.path, 'device-id'));
    if (await idFile.exists()) {
      deviceId = (await idFile.readAsString()).trim();
    } else {
      deviceId = const Uuid().v4();
      await idFile.writeAsString(deviceId);
    }
  }

  @override
  Future<void> doAfterBeanReady() => resumePending();

  WebDavClient _client() {
    if (!webDavSetting.isConfigured)
      throw const FormatException('Configure WebDAV before backing up');
    return WebDavClient(webDavSetting.connection);
  }

  /// Freezes the exported JSON before registering the retryable work item.
  Future<WebDavBackupSnapshot> createBackup(
    LocalBackupSelection selection,
  ) async {
    final client = _client();
    try {
      final contents = await localBackupService.export(selection);
      final bytes = utf8.encode(contents);
      final hash = sha256.convert(bytes).toString();
      final artifact = File(p.join(_artifactDirectory.path, '$hash.json'));
      if (!await artifact.exists()) {
        final temporary = File('${artifact.path}.tmp-${const Uuid().v4()}');
        await temporary.writeAsBytes(bytes);
        await temporary.rename(artifact.path);
      }
      final destination = 'backups/$deviceId/$hash.json';
      final item = await ContentRepository(appDb).createWorkItem(
        kind: 'backup',
        targetNamespace: client.connection.namespace,
        inputJson: jsonEncode({'snapshotId': hash, 'deviceId': deviceId}),
        localArtifactPath: artifact.path,
        remoteDestination: destination,
      );
      await _upload(item, client);
      return WebDavBackupSnapshot(
        deviceId: deviceId,
        snapshotId: hash,
        remotePath: destination,
        modified: DateTime.now(),
        size: bytes.length,
      );
    } finally {
      client.close();
    }
  }

  /// Call after beans and database are ready. Only the current namespace resumes.
  Future<void> resumePending() async {
    if (!transferActivityService.canAdmit) return;
    if (!webDavSetting.isConfigured) return;
    final client = _client();
    try {
      final items = await ContentRepository(appDb).listWorkItems(
        kind: 'backup',
        targetNamespace: client.connection.namespace,
      );
      _queued.addAll(items.map((item) => item.workItemId));
      _updateActivities();
      for (final item in items) {
        if (!transferActivityService.canAdmit ||
            !webDavSetting.isConfigured ||
            webDavSetting.connection.namespace != client.connection.namespace)
          break;
        try {
          await _upload(item, client);
        } catch (e) {
          log.warning('WebDAV backup retry failed', e, true);
        } finally {
          _queued.remove(item.workItemId);
          _updateActivities();
        }
      }
    } finally {
      _queued.clear();
      _updateActivities();
      client.close();
    }
  }

  Future<void> _upload(ContentWorkRecord item, WebDavClient client) {
    if (!transferActivityService.canAdmit)
      return Future<void>.error(StateError('System-stopped transfer'));
    final active = _inflight[item.workItemId];
    if (active != null) return active;
    final awakeOwner = Object();
    _beginActivity(item.workItemId, true);
    screenAwakeService.setRequested(awakeOwner, true);
    final work = _doUpload(item, client).whenComplete(() {
      _inflight.remove(item.workItemId);
      _endActivity(item.workItemId);
      screenAwakeService.setRequested(awakeOwner, false);
    });
    _inflight[item.workItemId] = work;
    return work;
  }

  Future<void> _doUpload(ContentWorkRecord item, WebDavClient client) async {
    final repository = ContentRepository(appDb);
    final destination = item.remoteDestination;
    final artifactPath = item.localArtifactPath;
    if (destination == null || artifactPath == null)
      throw const FormatException('Incomplete backup work item');
    final artifact = File(artifactPath);
    if (!await artifact.exists())
      throw const FileSystemException('Backup artifact is missing');
    final hash = (jsonDecode(item.inputJson) as Map)['snapshotId'] as String;
    final staging = 'staging/${item.workItemId}/$hash';
    try {
      _requireCurrentTarget(client);
      await repository.updateWorkItemState(item.workItemId, 'transferring');
      await client.ensureCollection(
        'backups/${(jsonDecode(item.inputJson) as Map)['deviceId']}',
      );
      _requireCurrentTarget(client);
      if (!await client.exists(destination)) {
        _requireCurrentTarget(client);
        await client.ensureCollection('staging/${item.workItemId}');
        _requireCurrentTarget(client);
        await client.putFile(
          staging,
          artifact,
          cancelToken: _tokens[item.workItemId],
          onSendProgress: _requestProgress(item.workItemId),
        );
        _requireCurrentTarget(client);
        try {
          await client.move(staging, destination);
        } on WebDavException catch (e) {
          if (e.kind != WebDavErrorKind.conflict ||
              !await client.exists(destination))
            rethrow;
        }
      }
      await repository.updateWorkItemState(item.workItemId, 'completed');
      try {
        await client.delete(staging);
      } on WebDavException catch (e) {
        if (e.kind != WebDavErrorKind.missing)
          log.warning('Could not remove WebDAV backup staging file', e);
      }
    } catch (_) {
      final sameTarget =
          webDavSetting.isConfigured &&
          webDavSetting.connection.namespace == client.connection.namespace;
      await repository.updateWorkItemState(
        item.workItemId,
        !transferActivityService.canAdmit
            ? 'queued'
            : sameTarget
            ? 'failed'
            : 'paused',
      );
      rethrow;
    }
  }

  void _requireCurrentTarget(WebDavClient client) {
    if (!webDavSetting.isConfigured ||
        webDavSetting.connection.namespace != client.connection.namespace) {
      throw const WebDavException(
        WebDavErrorKind.conflict,
        'WebDAV connection changed; backup is paused',
      );
    }
  }

  Future<List<WebDavBackupSnapshot>> listBackups() async {
    final client = _client();
    try {
      List<WebDavResource> devices;
      try {
        devices = await client.list('backups');
      } on WebDavException catch (e) {
        if (e.kind == WebDavErrorKind.missing) return [];
        rethrow;
      }
      final snapshots = <WebDavBackupSnapshot>[];
      for (final device in devices.where((r) => r.isCollection)) {
        final id = device.uri.pathSegments.where((s) => s.isNotEmpty).last;
        if (id == '.' || id == '..') continue;
        for (final resource in await client.list('backups/$id')) {
          if (resource.isCollection) continue;
          final name = resource.uri.pathSegments.last;
          if (!RegExp(r'^[0-9a-f]{64}\.json$').hasMatch(name)) continue;
          snapshots.add(
            WebDavBackupSnapshot(
              deviceId: id,
              snapshotId: name.substring(0, 64),
              remotePath: 'backups/$id/$name',
              modified: resource.modified,
              size: resource.length,
            ),
          );
        }
      }
      snapshots.sort(
        (a, b) => (b.modified ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(a.modified ?? DateTime.fromMillisecondsSinceEpoch(0)),
      );
      return snapshots;
    } finally {
      client.close();
    }
  }

  Future<String> downloadBackup(WebDavBackupSnapshot snapshot) async {
    await transferActivityService.whenAdmitted;
    if (!webDavSetting.isConfigured) {
      throw const FormatException('Configure WebDAV before backing up');
    }
    final connection = webDavSetting.connection;
    final key = '${connection.namespace}:${snapshot.snapshotId}';
    final pending = _downloads.putIfAbsent(
      key,
      () => _downloadResumable(key, snapshot, connection),
    );
    try {
      return await pending;
    } finally {
      if (identical(_downloads[key], pending)) {
        _downloads.remove(key);
      }
    }
  }

  Future<String> _downloadResumable(
    String key,
    WebDavBackupSnapshot snapshot,
    WebDavConnection connection,
  ) async {
    while (true) {
      await transferActivityService.whenAdmitted;
      final attempt = _downloadBackup(snapshot, connection);
      _downloadAttempts[key] = attempt;
      try {
        return await attempt;
      } catch (_) {
        if (transferActivityService.canAdmit) rethrow;
        // The same user operation survives a system stop and retains its prefix.
      } finally {
        if (identical(_downloadAttempts[key], attempt))
          _downloadAttempts.remove(key);
      }
    }
  }

  Future<String> _downloadBackup(
    WebDavBackupSnapshot snapshot,
    WebDavConnection connection,
  ) async {
    final client = WebDavClient(connection);
    final targetId = sha256.convert(utf8.encode(connection.namespace));
    final file = File(
      p.join(
        _artifactDirectory.path,
        'restore-$targetId-${snapshot.snapshotId}.json',
      ),
    );
    final awakeOwner = Object();
    final activityId = 'restore:${snapshot.snapshotId}';
    _beginActivity(activityId, false);
    screenAwakeService.setRequested(awakeOwner, true);
    try {
      final receivedHash = await client.getFile(
        snapshot.remotePath,
        file,
        cancelToken: _tokens[activityId],
        onReceiveProgress: _requestProgress(activityId),
        resume: true,
      );
      if (receivedHash != snapshot.snapshotId) {
        await file.delete();
        throw const FormatException('Backup checksum does not match');
      }
      try {
        return utf8.decode(await file.readAsBytes());
      } finally {
        await file.delete();
      }
    } finally {
      _endActivity(activityId);
      screenAwakeService.setRequested(awakeOwner, false);
      client.close();
    }
  }

  Future<({bool legacy, bool needsRestart})> restoreBackup(
    WebDavBackupSnapshot snapshot, {
    LocalBackupSelection? selection,
  }) async {
    final contents = await downloadBackup(snapshot);
    return localBackupService.import(contents, selection: selection);
  }
}
