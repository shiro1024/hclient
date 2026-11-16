import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../service/local_backup_service.dart';
import '../../../service/gallery_sync/gallery_sync_service.dart';
import '../../../service/webdav/webdav_backup_service.dart';
import '../../../service/webdav/webdav_client.dart';
import '../../../service/webdav/webdav_error_text.dart';
import '../../../setting/webdav_setting.dart';
import '../../../utils/byte_util.dart';
import '../../../widget/eh_local_backup_select_dialog.dart';

class SettingWebDavPage extends StatefulWidget {
  const SettingWebDavPage({super.key});

  @override
  State<SettingWebDavPage> createState() => _SettingWebDavPageState();
}

class _SettingWebDavPageState extends State<SettingWebDavPage> {
  late final Worker _connectionWorker;
  List<WebDavBackupSnapshot> _snapshots = [];
  String? _snapshotNamespace;
  bool _loading = false;
  bool _working = false;
  String? _listError;
  String? _status;
  String? _connectionStatus;
  String? _resumeError;
  String? _workingLabel;
  int _targetVersion = 0;
  int _listRequest = 0;
  bool _targetUpdateScheduled = false;
  bool _changingAutoSync = false;
  String? _autoSyncError;
  Future<List<CloudSyncJob>>? _autoSyncJobs;
  bool _loadingAutoSyncJobs = false;
  bool _refreshAutoSyncJobsAgain = false;

  @override
  void initState() {
    super.initState();
    gallerySyncService.addListener(_refreshAutoSyncJobs);
    _refreshAutoSyncJobs();
    _connectionWorker = everAll(
      [
        webDavSetting.address,
        webDavSetting.username,
        webDavSetting.password,
        webDavSetting.rootPath,
      ],
      (_) {
        // Invalidate results immediately, then read the complete saved fields.
        _targetVersion++;
        if (_targetUpdateScheduled) return;
        _targetUpdateScheduled = true;
        scheduleMicrotask(() {
          _targetUpdateScheduled = false;
          if (!mounted) return;
          setState(() {
            _snapshots = [];
            _snapshotNamespace = null;
            _listError = null;
            _status = null;
            _connectionStatus = null;
            _resumeError = null;
            _working = false;
            _changingAutoSync = false;
            _autoSyncError = null;
            _autoSyncJobs = null;
          });
          _refreshAutoSyncJobs();
          _refresh();
        });
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    gallerySyncService.removeListener(_refreshAutoSyncJobs);
    _connectionWorker.dispose();
    super.dispose();
  }

  bool _isCurrent(int version) => mounted && _targetVersion == version;

  Future<void> _editConnection() async {
    final previousVersion = _targetVersion;
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => const _ConnectionEditor(),
    );
    if (saved != true || !mounted) return;
    final version = _targetVersion;
    setState(() {
      _connectionStatus = 'webdavSaved'.tr;
      _resumeError = null;
    });
    // Saving is already complete. Network refresh and pending work have their
    // own feedback, so a remote failure never reports a failed save.
    // Changed fields refresh through the listener; unchanged saves still retry.
    if (version == previousVersion) unawaited(_refresh());
    try {
      await gallerySyncService.targetChanged();
      if (!_isCurrent(version)) return;
      await webDavBackupService.resumePending();
    } catch (e) {
      if (_isCurrent(version)) {
        setState(
          () => _resumeError =
              '${'webdavSyncResumeError'.tr}\n${webDavErrorText(e)}',
        );
      }
    }
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    final request = ++_listRequest;
    final version = _targetVersion;
    if (!webDavSetting.isConfigured) {
      setState(() {
        _loading = false;
        _snapshots = [];
        _listError = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _listError = null;
    });
    try {
      final namespace = webDavSetting.connection.namespace;
      if (_snapshotNamespace != namespace) {
        setState(() {
          _snapshots = [];
          _snapshotNamespace = namespace;
        });
      }
      final result = await webDavBackupService.listBackups();
      if (_isCurrent(version) && request == _listRequest) {
        setState(() => _snapshots = result);
      }
    } catch (e) {
      if (_isCurrent(version) && request == _listRequest) {
        setState(() => _listError = webDavErrorText(e));
      }
    } finally {
      if (_isCurrent(version) && request == _listRequest) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _runAction(String label, Future<void> Function(int) task) async {
    if (_working || !webDavSetting.isConfigured) return;
    final version = _targetVersion;
    setState(() {
      _working = true;
      _workingLabel = label;
      _status = null;
    });
    try {
      await task(version);
    } catch (e) {
      if (_isCurrent(version)) setState(() => _status = webDavErrorText(e));
    } finally {
      if (_isCurrent(version)) {
        setState(() => _working = false);
      }
    }
  }

  Future<void> _backup() async {
    final version = _targetVersion;
    final selection = await showDialog<LocalBackupSelection>(
      context: context,
      builder: (_) => const EHLocalBackupSelectDialog(),
    );
    if (selection == null || selection.isEmpty || !_isCurrent(version)) return;
    await _runAction('webdavBackupWorking'.tr, (version) async {
      await webDavBackupService.createBackup(selection);
      if (!_isCurrent(version)) return;
      setState(() => _status = 'webdavBackupComplete'.tr);
      await _refresh();
    });
  }

  Future<void> _restore(WebDavBackupSnapshot snapshot) =>
      _runAction('webdavRestoreWorking'.tr, (version) async {
        if (_snapshotNamespace != webDavSetting.connection.namespace) return;
        final contents = await webDavBackupService.downloadBackup(snapshot);
        if (!_isCurrent(version)) return;
        final available = localBackupService.availableSelection(contents);
        final selection = await showDialog<LocalBackupSelection>(
          context: context,
          builder: (_) =>
              EHLocalBackupSelectDialog(available: available, restore: true),
        );
        if (selection == null || selection.isEmpty || !_isCurrent(version))
          return;
        final result = await localBackupService.import(
          contents,
          selection: selection,
        );
        if (_isCurrent(version)) {
          setState(
            () => _status = result.needsRestart
                ? 'backupRestartNotice'.tr
                : 'webdavRestoreComplete'.tr,
          );
        }
      });

  Widget _message(String message, {bool error = false}) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Semantics(
      liveRegion: true,
      child: Text(
        message,
        style: error
            ? TextStyle(color: Theme.of(context).colorScheme.error)
            : null,
      ),
    ),
  );

  Widget _connectionSummary() {
    final theme = Theme.of(context);
    final configured = webDavSetting.isConfigured;
    final username = webDavSetting.username.value;
    final root = webDavSetting.rootPath.value;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.dns_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'webdavConnection'.tr,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              configured
                  ? webDavSetting.address.value
                  : 'webdavNotConfigured'.tr,
              style: theme.textTheme.titleMedium,
            ),
            if (configured) ...[
              const SizedBox(height: 8),
              Text(
                '${'webdavUsername'.tr}: ${username.isEmpty ? 'webdavAnonymous'.tr : username}',
              ),
              const SizedBox(height: 4),
              Text(
                '${'webdavRootPath'.tr}: ${root.isEmpty ? 'webdavServerRoot'.tr : root}',
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'webdavConnectionHint'.tr,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _editConnection,
              icon: Icon(configured ? Icons.edit_outlined : Icons.add),
              label: Text(
                (configured
                        ? 'webdavEditConnection'
                        : 'webdavConfigureConnection')
                    .tr,
              ),
            ),
            if (_connectionStatus != null) _message(_connectionStatus!),
            if (_resumeError != null) _message(_resumeError!, error: true),
          ],
        ),
      ),
    );
  }

  void _refreshAutoSyncJobs() {
    if (!mounted) return;
    if (!webDavSetting.isConfigured) {
      _refreshAutoSyncJobsAgain = false;
      setState(() => _autoSyncJobs = null);
      return;
    }
    if (_loadingAutoSyncJobs) {
      _refreshAutoSyncJobsAgain = true;
      return;
    }
    _loadingAutoSyncJobs = true;
    _refreshAutoSyncJobsAgain = false;
    final jobs = gallerySyncService.listSyncJobs(finishAction: 'release');
    setState(() {
      _autoSyncJobs = jobs;
    });
    unawaited(
      jobs
          .then<void>((_) {}, onError: (Object error, StackTrace stack) {})
          .whenComplete(() {
            _loadingAutoSyncJobs = false;
            if (_refreshAutoSyncJobsAgain && mounted) _refreshAutoSyncJobs();
          }),
    );
  }

  Future<void> _setAutoSync(bool enabled) async {
    if (_changingAutoSync) return;
    final version = _targetVersion;
    setState(() {
      _changingAutoSync = true;
      _autoSyncError = null;
    });
    try {
      await gallerySyncService.setAutoSync(enabled);
    } catch (error) {
      if (_isCurrent(version))
        setState(() => _autoSyncError = webDavErrorText(error));
    } finally {
      if (_isCurrent(version)) setState(() => _changingAutoSync = false);
    }
  }

  Widget _autoSyncSection() {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Obx(
              () => SwitchListTile.adaptive(
                title: Text(
                  'webdavAutoGallerySync'.tr,
                  style: theme.textTheme.titleMedium,
                ),
                value: webDavSetting.autoSync.value,
                onChanged: _changingAutoSync ? null : _setAutoSync,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'webdavAutoGallerySyncHint'.tr,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (_changingAutoSync)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: LinearProgressIndicator(),
              ),
            if (_autoSyncError != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _message(_autoSyncError!, error: true),
              ),
            FutureBuilder<List<CloudSyncJob>>(
              future: _autoSyncJobs,
              builder: (context, snapshot) {
                if (snapshot.hasError)
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _message(
                      webDavErrorText(snapshot.error!),
                      error: true,
                    ),
                  );
                final releases = snapshot.data ?? const <CloudSyncJob>[];
                if (releases.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: ExpansionTile(
                    title: Text(
                      'webdavExistingReleaseCount'.trParams({
                        'count': '${releases.length}',
                      }),
                    ),
                    subtitle: Text('webdavExistingReleaseHint'.tr),
                    children: [
                      for (final job in releases)
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.cleaning_services_outlined),
                          title: Text(job.title),
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _backupSection() {
    final theme = Theme.of(context);
    final configured = webDavSetting.isConfigured;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('webdavConfigBackup'.tr, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'webdavConfigBackupHint'.tr,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: configured && !_working ? _backup : null,
              icon: const Icon(Icons.backup_outlined),
              label: Text('webdavCreateBackup'.tr),
            ),
            if (_working) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
              _message(_workingLabel!),
            ],
            if (_status != null) _message(_status!),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'webdavSnapshots'.tr,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  onPressed: configured && !_loading ? _refresh : null,
                  tooltip: 'webdavRefresh'.tr,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            if (!configured)
              _message('webdavConnectionRequired'.tr)
            else if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_listError != null) ...[
              _message('webdavBackupsLoadError'.tr, error: true),
              _message(_listError!, error: true),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
                label: Text('webdavRetry'.tr),
              ),
            ] else if (_snapshots.isEmpty) ...[
              _message('webdavNoSnapshots'.tr),
              _message('webdavNoBackupsHint'.tr),
            ] else
              ..._snapshots.map(_snapshotTile),
          ],
        ),
      ),
    );
  }

  Widget _snapshotTile(WebDavBackupSnapshot snapshot) {
    final device = snapshot.deviceId;
    final shortDevice = device.length > 8 ? device.substring(0, 8) : device;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          Text(
            snapshot.modified == null
                ? 'webdavSnapshot'.tr
                : DateFormat('yyyy-MM-dd HH:mm')
                      .format(snapshot.modified!.toLocal()),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            '${'webdavDevice'.tr}: $shortDevice${snapshot.size == null ? '' : ' · ${byte2String(snapshot.size!.toDouble())}'}',
          ),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: _working ? null : () => _restore(snapshot),
            icon: const Icon(Icons.restore),
            label: Text('webdavRestore'.tr),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('webdavTitle'.tr), centerTitle: true),
    body: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _connectionSummary(),
            const SizedBox(height: 16),
            if (webDavSetting.isConfigured) ...[
              _autoSyncSection(),
              const SizedBox(height: 16),
            ],
            _backupSection(),
          ],
        ),
      ),
    ),
  );
}

class _ConnectionEditor extends StatefulWidget {
  const _ConnectionEditor();

  @override
  State<_ConnectionEditor> createState() => _ConnectionEditorState();
}

class _ConnectionEditorState extends State<_ConnectionEditor> {
  final _form = GlobalKey<FormState>();
  late final _address = TextEditingController(
    text: webDavSetting.address.value,
  );
  late final _username = TextEditingController(
    text: webDavSetting.username.value,
  );
  late final _password = TextEditingController(
    text: webDavSetting.password.value,
  );
  late final _root = TextEditingController(text: webDavSetting.rootPath.value);
  bool _showPassword = false;
  bool _saving = false;
  bool _testing = false;
  String? _result;
  bool _testFailed = false;
  int _draft = 0;
  CancelToken? _testCancelToken;

  @override
  void dispose() {
    _testCancelToken?.cancel('Connection test ended');
    _address.dispose();
    _username.dispose();
    _password.dispose();
    _root.dispose();
    super.dispose();
  }

  void _draftChanged(String _) => setState(() {
    _draft++;
    _result = null;
    _testing = false;
    _testCancelToken?.cancel('Connection test ended');
    _testCancelToken = null;
  });

  WebDavConnection _connection() => WebDavConnection.fromFields(
    address: _address.text,
    username: _username.text,
    password: _password.text,
    rootPath: _root.text,
  );

  Future<void> _test() async {
    if (!_form.currentState!.validate()) return;
    final draft = _draft;
    final client = WebDavClient(_connection());
    final cancelToken = CancelToken();
    _testCancelToken = cancelToken;
    setState(() {
      _testing = true;
      _result = null;
    });
    try {
      // PROPFIND only: testing never creates folders or temporary files.
      final exists = await client.exists(
        '',
        directory: true,
        cancelToken: cancelToken,
      );
      if (!mounted || draft != _draft) return;
      setState(() {
        _testFailed = false;
        _result =
            (exists ? 'webdavConnectionReady' : 'webdavConnectionFolderMissing')
                .tr;
      });
    } catch (e) {
      if (mounted && draft == _draft) {
        setState(() {
          _testFailed = true;
          _result = webDavErrorText(e);
        });
      }
    } finally {
      client.close();
      if (identical(_testCancelToken, cancelToken)) _testCancelToken = null;
      if (mounted && draft == _draft) setState(() => _testing = false);
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await webDavSetting.save(
        address: _address.text,
        username: _username.text,
        password: _password.text,
        rootPath: _root.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted)
        setState(() {
          _testFailed = true;
          _result = webDavErrorText(e);
        });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: Text('webdavEditConnection'.tr),
      scrollable: true,
      content: SizedBox(
        width: 480,
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('webdavDraftHint'.tr),
              const SizedBox(height: 20),
              TextFormField(
                controller: _address,
                enabled: !_saving,
                keyboardType: TextInputType.url,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                onChanged: _draftChanged,
                validator: (value) {
                  try {
                    WebDavConnection.fromFields(
                      address: value ?? '',
                      username: '',
                      password: '',
                    );
                    return null;
                  } on FormatException {
                    return 'webdavInvalidAddress'.tr;
                  }
                },
                decoration: InputDecoration(
                  labelText: 'webdavAddress'.tr,
                  hintText: 'https://example.com/dav/',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _username,
                enabled: !_saving,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                onChanged: _draftChanged,
                decoration: InputDecoration(
                  labelText: 'webdavUsername'.tr,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _password,
                enabled: !_saving,
                obscureText: !_showPassword,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.next,
                onChanged: _draftChanged,
                decoration: InputDecoration(
                  labelText: 'webdavPassword'.tr,
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => _showPassword = !_showPassword),
                    tooltip:
                        (_showPassword
                                ? 'webdavHidePassword'
                                : 'webdavShowPassword')
                            .tr,
                    icon: Icon(
                      _showPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _root,
                enabled: !_saving,
                autocorrect: false,
                onChanged: _draftChanged,
                validator: (value) {
                  try {
                    WebDavConnection.fromFields(
                      address: 'https://example.com',
                      username: '',
                      password: '',
                      rootPath: value ?? '',
                    );
                    return null;
                  } on FormatException {
                    return 'webdavInvalidRootPath'.tr;
                  }
                },
                decoration: InputDecoration(
                  labelText: 'webdavRootPath'.tr,
                  helperText: 'webdavRootPathHint'.tr,
                  helperMaxLines: 3,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _testing || _saving ? null : _test,
                icon: _testing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.wifi_tethering),
                label: Text(
                  (_testing ? 'webdavTesting' : 'webdavTestConnection').tr,
                ),
              ),
              if (_result != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      _result!,
                      style: _testFailed
                          ? TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            )
                          : null,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: Text('cancel'.tr),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text((_saving ? 'webdavSaving' : 'webdavSave').tr),
        ),
      ],
    ),
  );
}
