import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:waterfall_flow/waterfall_flow.dart';

import '../../../routes/routes.dart';
import '../../../service/content_sync/portable_manifest.dart';
import '../../../service/gallery_sync/gallery_sync_service.dart';
import '../../../service/local_content_service.dart';
import '../../../service/read_progress_service.dart';
import '../../../service/webdav/webdav_error_text.dart';
import 'cloud_transfer_sheet.dart';
import 'cloud_statistics_dialog.dart';
import 'cloud_gallery_card.dart';
import 'cloud_upload_sheet.dart';
import '../../../setting/webdav_setting.dart';
import '../../../utils/route_util.dart' as route;
import '../download_base_page.dart';

class CloudGalleryPage extends StatefulWidget {
  const CloudGalleryPage({super.key});

  @override
  State<CloudGalleryPage> createState() => _CloudGalleryPageState();
}

class _CloudGalleryPageState extends State<CloudGalleryPage> {
  final _search = TextEditingController();
  AsyncSnapshot<List<CloudGalleryEntry>> _entries =
      const AsyncSnapshot.nothing();
  bool _loadingCatalog = false;
  bool _reloadCatalogAgain = false;
  Object? _catalogRequest;
  Object? _visibleCatalogScope;
  Future<List<CloudSyncJob>>? _jobs;
  bool _loadingJobs = false;
  bool _refreshJobsAgain = false;
  int _seenCatalogRevision = -1;
  String? _representation;
  String? _category;
  String? _collection;
  PortableTag? _tag;
  Future<CloudGalleryFacets>? _facets;
  final Set<String> _selectedManifestIds = {};
  bool _syncingMetadata = false;
  bool _selecting = false;
  bool _searching = false;
  final Set<int> _expandedFamilies = {};
  int _limit = 40;
  String? _restoring;
  Timer? _searchDebounce;
  final Map<String, Future<File?>> _thumbnails = {};

  @override
  void initState() {
    super.initState();
    gallerySyncService.addListener(_reload);
    _reload();
    if (webDavSetting.isConfigured) {
      unawaited(_refresh(initial: true));
    }
  }

  @override
  void dispose() {
    gallerySyncService.removeListener(_reload);
    _searchDebounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Object get _catalogScope => (
    webDavSetting.isConfigured ? webDavSetting.connection.namespace : null,
    _search.text,
    _representation,
    _category,
    _collection,
    _tag?.namespace,
    _tag?.name,
  );

  Object get _currentCatalogRequest => (_catalogScope, _limit);

  void _reload() {
    if (!mounted) return;
    if (_visibleCatalogScope != _catalogScope) {
      setState(() {
        _visibleCatalogScope = _catalogScope;
        _entries = const AsyncSnapshot.waiting();
      });
    }
    if (_seenCatalogRevision != gallerySyncService.catalogRevision ||
        _catalogRequest != _currentCatalogRequest) {
      _facets = null;
      _reloadCatalogAgain = true;
      if (!_loadingCatalog) unawaited(_readCatalog());
    }
    _reloadJobs();
  }

  Future<void> _readCatalog() async {
    _loadingCatalog = true;
    try {
      do {
        _reloadCatalogAgain = false;
        final request = _currentCatalogRequest;
        _catalogRequest = request;
        _seenCatalogRevision = gallerySyncService.catalogRevision;
        final entries = gallerySyncService.listCloudEntries(
          search: _search.text,
          representation: _representation,
          category: _category,
          collection: _collection,
          tag: _tag,
          limit: _limit,
        );
        try {
          final result = await entries;
          if (mounted && request == _currentCatalogRequest) {
            setState(() {
              _entries = AsyncSnapshot.withData(ConnectionState.done, result);
            });
          }
        } catch (error, stack) {
          if (mounted && request == _currentCatalogRequest) {
            setState(() {
              _entries = AsyncSnapshot.withError(
                ConnectionState.done,
                error,
                stack,
              );
            });
          }
        }
      } while (mounted && _reloadCatalogAgain);
    } finally {
      _loadingCatalog = false;
    }
  }

  void _reloadJobs() {
    if (!mounted) return;
    if (_loadingJobs) {
      _refreshJobsAgain = true;
      return;
    }
    _loadingJobs = true;
    _refreshJobsAgain = false;
    final jobs = gallerySyncService.listSyncJobs();
    setState(() {
      _jobs = jobs;
    });
    unawaited(
      jobs
          .then<void>((_) {}, onError: (Object error, StackTrace stack) {})
          .whenComplete(() {
            _loadingJobs = false;
            if (_refreshJobsAgain && mounted) _reloadJobs();
          }),
    );
  }

  Future<void> _restoreAndOpen(CloudGalleryEntry entry) async {
    if (_restoring != null) return;
    setState(() => _restoring = entry.manifestId);
    try {
      final copyId = await gallerySyncService.restore(entry.manifestId);
      if (!mounted) return;
      final initialIndex = await readProgressService.getReadProgress(entry.gid);
      final info = await localContentService.readPageInfoForCopy(
        copyId,
        initialIndex: initialIndex,
      );
      info.readProgressRecordStorageKey = entry.gid.toString();
      route.toRoute(Routes.read, arguments: info);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(webDavErrorText(error))));
      }
    } finally {
      if (mounted) setState(() => _restoring = null);
    }
  }

  Future<void> _cleanLocal(CloudGalleryEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('cloudCleanLocal'.tr),
        content: Text('cloudCleanConfirm'.tr),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('cancel'.tr),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('cloudCleanLocal'.tr),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await gallerySyncService.cleanupLocal(entry);
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('cloudQueued'.tr)));
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('cloudSyncFailed'.tr)));
    }
  }

  Future<void> _editRevision(CloudGalleryEntry entry) async {
    var editedTitle = entry.title;
    final parent = entry.manifest.lineage
        .where(
          (edge) => edge.toGid == entry.gid && edge.kind == 'source_parent',
        )
        .firstOrNull;
    var editedParent = parent?.fromGid.toString() ?? '';
    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('cloudEditRevision'.tr),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: editedTitle,
                  onChanged: (value) => editedTitle = value,
                  decoration: InputDecoration(labelText: 'cloudTitle'.tr),
                ),
                TextFormField(
                  initialValue: editedParent,
                  onChanged: (value) => editedParent = value,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'cloudParentGid'.tr),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('cancel'.tr),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('save'.tr),
            ),
          ],
        ),
      );
      if (saved != true) return;
      final text = editedTitle.trim();
      final parentText = editedParent.trim();
      final parsedParent = parentText.isEmpty ? null : int.tryParse(parentText);
      if (text.isEmpty ||
          (parentText.isNotEmpty &&
              (parsedParent == null ||
                  parsedParent <= 0 ||
                  parsedParent == entry.gid))) {
        throw const FormatException('Invalid metadata revision');
      }
      final changedTitle = editedTitle == entry.title || text == entry.title
          ? null
          : text;
      final parentChanged = parsedParent != parent?.fromGid;
      final observedLineage = entry.manifest.lineage;
      final lineage = parentChanged
          ? <ManifestLineage>[
              ...observedLineage.where(
                (edge) =>
                    !(edge.toGid == entry.gid && edge.kind == 'source_parent'),
              ),
              if (parsedParent != null)
                ManifestLineage(parsedParent, entry.gid, 'source_parent'),
            ]
          : observedLineage;
      (int, int, String) identity(ManifestLineage edge) =>
          (edge.fromGid, edge.toGid, edge.kind);
      final observedEdges = observedLineage.map(identity).toSet();
      final editedEdges = lineage.map(identity).toSet();
      final added = lineage
          .where((edge) => !observedEdges.contains(identity(edge)))
          .toList();
      final removed = observedLineage
          .where((edge) => !editedEdges.contains(identity(edge)))
          .toList();
      if (changedTitle == null && added.isEmpty && removed.isEmpty) return;
      await gallerySyncService.requestMetadataRevision(
        entry.manifestId,
        title: changedTitle,
        lineageAdded: added.isEmpty ? null : added,
        lineageRemoved: removed.isEmpty ? null : removed,
      );
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('cloudQueued'.tr)));
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('cloudSyncFailed'.tr)));
    }
  }

  Future<void> _refreshWebsiteMetadata(CloudGalleryEntry entry) async {
    try {
      await gallerySyncService.requestWebsiteMetadataRevision(entry);
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('cloudQueued'.tr)));
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('cloudSourceLookupFailed'.tr)));
    }
  }

  Future<void> _showHistory(CloudGalleryEntry entry) async {
    final history = await gallerySyncService.listHistory(entry);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.55,
          child: Column(
            children: [
              ListTile(title: Text('cloudHistory'.tr)),
              Expanded(
                child: history.isEmpty
                    ? Center(child: Text('cloudNoHistory'.tr))
                    : ListView.builder(
                        itemCount: history.length,
                        itemBuilder: (context, index) {
                          final past = history[index];
                          return ListTile(
                            title: Text(
                              past.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${past.manifest.pages.length} ${'cloudPages'.tr} · ${_localStateText(past.localState)}',
                            ),
                            trailing: TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _restoreAndOpen(past);
                              },
                              child: Text(
                                past.locallyAvailable
                                    ? 'cloudOpen'.tr
                                    : 'cloudRestore'.tr,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _configure() async {
    await route.toRoute(Routes.settingWebDav);
    if (!mounted) return;
    _seenCatalogRevision = -1;
    _thumbnails.clear();
    _reload();
    if (webDavSetting.isConfigured) await _refresh(initial: true);
  }

  Future<void> _refresh({bool initial = false}) async {
    try {
      if (initial) {
        await gallerySyncService.ensureInitialDiscovery();
      } else {
        await gallerySyncService.refresh();
      }
    } catch (_) {
      // Discovery publishes its error through gallerySyncService.lastError.
    } finally {
      if (mounted) {
        _seenCatalogRevision = -1;
        _reload();
      }
    }
  }

  void _queryChanged() {
    _searchDebounce?.cancel();
    _limit = 40;
    _selectedManifestIds.clear();
    _seenCatalogRevision = -1;
    _reload();
  }

  bool get _filtered =>
      _search.text.trim().isNotEmpty ||
      _representation != null ||
      _category != null ||
      _collection != null ||
      _tag != null;

  void _clearFilters() {
    _search.clear();
    _representation = null;
    _category = null;
    _collection = null;
    _tag = null;
    _queryChanged();
  }

  Future<void> _syncSelectedMetadata() async {
    final entries = _entries.data;
    if (!mounted || entries == null) return;
    final selected = entries
        .where((entry) => _selectedManifestIds.contains(entry.manifestId))
        .toList();
    setState(() => _syncingMetadata = true);
    var failed = 0;
    for (final entry in selected) {
      try {
        await gallerySyncService.requestWebsiteMetadataRevision(entry);
      } catch (_) {
        failed++;
      }
    }
    if (!mounted) return;
    setState(() {
      _syncingMetadata = false;
      _selectedManifestIds.clear();
      _selecting = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failed == 0
              ? 'cloudQueued'.tr
              : 'cloudMetadataBatchFailed'.trParams({'count': '$failed'}),
        ),
      ),
    );
  }

  Future<CloudGalleryFacets> _loadFacets() =>
      _facets ??= gallerySyncService.listCloudFacets();

  Future<void> _showFilters() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * .7,
            child: StatefulBuilder(
              builder: (context, updateSheet) => Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'cloudFilter'.tr,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            setState(() => _selecting = true);
                          },
                          child: Text('cloudSelect'.tr),
                        ),
                        IconButton(
                          tooltip: 'cloudClearFilters'.tr,
                          icon: const Icon(Icons.filter_alt_off_outlined),
                          onPressed: () {
                            _clearFilters();
                            updateSheet(() {});
                          },
                        ),
                        IconButton(
                          tooltip: 'close'.tr,
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: FutureBuilder<CloudGalleryFacets>(
                      future: _loadFacets(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError)
                          return Center(
                            child: Text(webDavErrorText(snapshot.error!)),
                          );
                        if (!snapshot.hasData)
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        final facets = snapshot.data!;
                        Widget section(String title, List<Widget> chips) =>
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall,
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: chips,
                                  ),
                                ],
                              ),
                            );
                        void change(VoidCallback mutate) {
                          mutate();
                          _queryChanged();
                          updateSheet(() {});
                        }

                        return ListView(
                          children: [
                            section('cloudAllTypes'.tr, [
                              for (final value in [
                                'original',
                                'resampled',
                                'unspecified',
                              ])
                                FilterChip(
                                  label: Text(_modeText(value)),
                                  selected: _representation == value,
                                  onSelected: (selected) => change(
                                    () => _representation = selected
                                        ? value
                                        : null,
                                  ),
                                ),
                            ]),
                            section('cloudCollections'.tr, [
                              for (final value in facets.collections)
                                FilterChip(
                                  label: Text(value),
                                  selected: _collection == value,
                                  onSelected: (selected) => change(
                                    () => _collection = selected ? value : null,
                                  ),
                                ),
                            ]),
                            section('cloudCategories'.tr, [
                              for (final value in facets.categories)
                                FilterChip(
                                  label: Text(value),
                                  selected: _category == value,
                                  onSelected: (selected) => change(
                                    () => _category = selected ? value : null,
                                  ),
                                ),
                            ]),
                            section('cloudTags'.tr, [
                              for (final value in facets.tags)
                                FilterChip(
                                  label: CloudGalleryTagLabel(
                                    namespace: value.namespace,
                                    name: value.name,
                                  ),
                                  selected:
                                      _tag?.namespace == value.namespace &&
                                      _tag?.name == value.name,
                                  onSelected: (selected) => change(
                                    () => _tag = selected ? value : null,
                                  ),
                                ),
                            ]),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  int get _filterCount => [
    _representation,
    _category,
    _collection,
    _tag,
  ].where((value) => value != null).length;

  void _closeSearch() {
    setState(() => _searching = false);
    _search.clear();
    _queryChanged();
  }

  @override
  Widget build(BuildContext context) => DownloadPageToolbarLayout(
    builder: (context) => Scaffold(
      appBar: DownloadPageAppBar(
        context: context,
        galleryType: DownloadPageGalleryType.cloud,
        leading: _selecting || _searching
            ? IconButton(
                tooltip: 'close'.tr,
                onPressed: _syncingMetadata
                    ? null
                    : () {
                        if (_selecting) {
                          setState(() {
                            _selecting = false;
                            _selectedManifestIds.clear();
                          });
                        } else {
                          _closeSearch();
                        }
                      },
                icon: const Icon(Icons.close),
              )
            : null,
        title: _selecting
            ? Text(
                'cloudSelectedCount'.trParams({
                  'count': '${_selectedManifestIds.length}',
                }),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : _searching
            ? TextField(
                controller: _search,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'cloudSearch'.tr,
                  border: InputBorder.none,
                ),
                onChanged: (_) {
                  _searchDebounce?.cancel();
                  _searchDebounce = Timer(
                    const Duration(milliseconds: 250),
                    _queryChanged,
                  );
                },
                onSubmitted: (_) => _queryChanged(),
              )
            : null,
        actions: _selecting
            ? [
                if (_selectedManifestIds.length == 1)
                  Builder(
                    builder: (_) {
                      final entry = _entries.data
                          ?.where(
                            (e) => _selectedManifestIds.contains(e.manifestId),
                          )
                          .firstOrNull;
                      return entry == null
                          ? const SizedBox.shrink()
                          : _entryMenu(entry);
                    },
                  ),
                IconButton(
                  tooltip: 'cloudSyncWebsiteMetadata'.tr,
                  onPressed: _syncingMetadata || _selectedManifestIds.isEmpty
                      ? null
                      : _syncSelectedMetadata,
                  icon: _syncingMetadata
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync),
                ),
              ]
            : [
                if (!_searching)
                  IconButton(
                    tooltip: 'cloudSearch'.tr,
                    onPressed: () => setState(() => _searching = true),
                    icon: const Icon(Icons.search),
                  ),
                IconButton(
                  tooltip: 'cloudFilter'.tr,
                  onPressed: !webDavSetting.isConfigured ? null : _showFilters,
                  icon: Badge(
                    isLabelVisible: _filterCount > 0,
                    label: Text('$_filterCount'),
                    child: const Icon(Icons.filter_alt_outlined),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'cloudMoreActions'.tr,
                  onSelected: (action) {
                    switch (action) {
                      case 'navigation':
                        openDownloadNavigationMenu(context);
                      case 'upload':
                        showCloudUploadPicker(context);
                      case 'refresh':
                        _refresh();
                      case 'statistics':
                        showCloudStatistics(context);
                      case 'settings':
                        _configure();
                    }
                  },
                  itemBuilder: (_) => [
                    if (showDownloadNavigationMenu(context))
                      downloadNavigationMenuItem('navigation'),
                    if (webDavSetting.isConfigured) ...[
                      PopupMenuItem(
                        value: 'upload',
                        child: Text('cloudUpload'.tr),
                      ),
                      PopupMenuItem(
                        value: 'refresh',
                        enabled: !gallerySyncService.scanning,
                        child: Text('cloudRefresh'.tr),
                      ),
                      PopupMenuItem(
                        value: 'statistics',
                        child: Text('cloudStatistics'.tr),
                      ),
                      PopupMenuItem<String>(
                        enabled: false,
                        child: Text(webDavSetting.connection.address.host),
                      ),
                    ],
                    PopupMenuItem(
                      value: 'settings',
                      child: Text('cloudWebDavSettings'.tr),
                    ),
                  ],
                ),
              ],
      ),
      body: !webDavSetting.isConfigured
          ? SingleChildScrollView(
              child: _empty(
                Icons.cloud_outlined,
                'cloudStartTitle'.tr,
                'cloudConfigureWebDav'.tr,
                action: FilledButton.icon(
                  onPressed: _configure,
                  icon: const Icon(Icons.add_link),
                  label: Text('webdavConfigureConnection'.tr),
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _refresh,
              child: CustomScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _transferSummary()),
                  if (gallerySyncService.scanning)
                    const SliverToBoxAdapter(child: LinearProgressIndicator()),
                  _entriesSliver(_entries),
                ],
              ),
            ),
    ),
  );

  Widget _transferSummary() => FutureBuilder<List<CloudSyncJob>>(
    future: _jobs,
    builder: (context, snapshot) {
      final jobs = snapshot.data ?? const <CloudSyncJob>[];
      if (jobs.isEmpty && !snapshot.hasError) return const SizedBox.shrink();
      final failures = jobs.where((job) => job.state == 'failed').length;
      return InkWell(
        onTap: () => showCloudTransfers(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Icon(failures > 0 ? Icons.error_outline : Icons.sync, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  [
                    'cloudTaskCount'.trParams({'count': '${jobs.length}'}),
                    if (snapshot.hasError) 'cloudTaskListFailed'.tr,
                    if (failures > 0)
                      'cloudFailedCount'.trParams({'count': '$failures'}),
                  ].join(' · '),
                ),
              ),
              const Icon(Icons.chevron_right, size: 20),
            ],
          ),
        ),
      );
    },
  );

  Widget _entriesSliver(AsyncSnapshot<List<CloudGalleryEntry>> snapshot) {
    final entries = snapshot.data ?? const <CloudGalleryEntry>[];
    final error =
        gallerySyncService.lastError ??
        (snapshot.hasError ? webDavErrorText(snapshot.error!) : null);
    if (entries.isEmpty) {
      Widget empty;
      if (error != null) {
        empty = _empty(
          Icons.cloud_off_outlined,
          'cloudLoadFailed'.tr,
          error,
          action: FilledButton.tonalIcon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            label: Text('cloudRetry'.tr),
          ),
        );
      } else if (!snapshot.hasData || gallerySyncService.scanning) {
        empty = _empty(
          Icons.cloud_download_outlined,
          'cloudLoadingLibrary'.tr,
          'cloudLoadingHint'.tr,
          loading: true,
        );
      } else {
        empty = _empty(
          _filtered ? Icons.search_off : Icons.cloud_upload_outlined,
          _filtered ? 'cloudNoMatches'.tr : 'cloudEmpty'.tr,
          _filtered ? 'cloudNoMatchesHint'.tr : 'cloudEmptyHint'.tr,
          action: _filtered
              ? TextButton(
                  onPressed: _clearFilters,
                  child: Text('cloudClearFilters'.tr),
                )
              : FilledButton.icon(
                  onPressed: () => showCloudUploadPicker(context),
                  icon: const Icon(Icons.add),
                  label: Text('cloudChooseUploads'.tr),
                ),
        );
      }
      return SliverToBoxAdapter(child: empty);
    }
    final families = <int, List<CloudGalleryEntry>>{};
    for (final entry in entries) {
      families.putIfAbsent(entry.familyKey, () => []).add(entry);
    }
    final groups = families.values.toList();
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      sliver: SliverMainAxisGroup(
        slivers: [
          if (error != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'cloudCachedLibrary'.tr,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    Text(error),
                    TextButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh),
                      label: Text('cloudRetry'.tr),
                    ),
                  ],
                ),
              ),
            ),
          SliverWaterfallFlow(
            gridDelegate:
                const SliverWaterfallFlowDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 600,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final versions = groups[index];
              final expanded = _expandedFamilies.contains(
                versions.first.familyKey,
              );
              return Column(
                children: [
                  _entryCard(
                    versions.first,
                    versionControl: versions.length == 1
                        ? null
                        : Tooltip(
                            triggerMode: TooltipTriggerMode.manual,
                            message: '${versions.length} ${'cloudVersions'.tr}',
                            child: TextButton.icon(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () => setState(() {
                                expanded
                                    ? _expandedFamilies.remove(
                                        versions.first.familyKey,
                                      )
                                    : _expandedFamilies.add(
                                        versions.first.familyKey,
                                      );
                              }),
                              icon: Icon(
                                expanded
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                size: 18,
                              ),
                              label: Text('${versions.length}'),
                            ),
                          ),
                  ),
                  if (expanded)
                    for (final version in versions.skip(1))
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: _entryCard(version),
                      ),
                ],
              );
            }, childCount: groups.length),
          ),
          if (groups.length >= _limit)
            SliverToBoxAdapter(
              child: TextButton(
                onPressed: () {
                  _limit += 40;
                  _seenCatalogRevision = -1;
                  _reload();
                },
                child: Text('cloudMore'.tr),
              ),
            ),
        ],
      ),
    );
  }

  Widget _empty(
    IconData icon,
    String title,
    String message, {
    Widget? action,
    bool loading = false,
  }) => Padding(
    padding: const EdgeInsets.fromLTRB(28, 40, 28, 24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 20),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 20),
        if (loading)
          const CircularProgressIndicator()
        else if (action != null)
          action,
      ],
    ),
  );

  Widget _entryCard(CloudGalleryEntry entry, {Widget? versionControl}) {
    final selected = _selectedManifestIds.contains(entry.manifestId);
    final scheme = Theme.of(context).colorScheme;
    void activate() {
      if (_selecting) {
        if (!_syncingMetadata)
          setState(() {
            selected
                ? _selectedManifestIds.remove(entry.manifestId)
                : _selectedManifestIds.add(entry.manifestId);
          });
      } else if (_restoring == null) {
        _restoreAndOpen(entry);
      }
    }

    return Builder(
      builder: (cardContext) => CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.contextMenu): () =>
              _showEntryMenu(entry, cardContext),
          const SingleActivator(LogicalKeyboardKey.f10, shift: true): () =>
              _showEntryMenu(entry, cardContext),
        },
        child: Card(
          key: ValueKey(entry.manifestId),
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          color: selected ? scheme.secondaryContainer : null,
          child: InkWell(
            onTap: activate,
            onLongPress: () => _showEntryMenu(entry, cardContext),
            onSecondaryTap: () => _showEntryMenu(entry, cardContext),
            child: Stack(
              children: [
                CloudGalleryCardBody(
                  entry: entry,
                  cover: Stack(
                    fit: StackFit.expand,
                    children: [
                      _cover(entry),
                      if (_restoring == entry.manifestId)
                        const ColoredBox(
                          color: Colors.black38,
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                  representationLabel: _modeText(entry.representation),
                  metadataLine:
                      'GID ${entry.gid} · ${_restoring == entry.manifestId ? 'cloudDownloading'.tr : _localStateText(entry.localState)}',
                  versionControl: versionControl,
                ),
                if (_selecting)
                  Positioned(
                    top: 4,
                    left: 4,
                    child: IgnorePointer(
                      child: Checkbox(value: selected, onChanged: (_) {}),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<PopupMenuEntry<String>> _entryMenuItems(CloudGalleryEntry entry) => [
    PopupMenuItem(value: 'collections', child: Text('cloudEditCollections'.tr)),
    PopupMenuItem(value: 'edit', child: Text('cloudEditRevision'.tr)),
    PopupMenuItem(value: 'source', child: Text('cloudSyncWebsiteMetadata'.tr)),
    PopupMenuItem(value: 'history', child: Text('cloudHistory'.tr)),
    if (entry.locallyAvailable)
      PopupMenuItem(value: 'clean', child: Text('cloudCleanLocal'.tr)),
  ];

  void _entryAction(CloudGalleryEntry entry, String action) {
    switch (action) {
      case 'collections':
        _editCollections(entry);
      case 'edit':
        _editRevision(entry);
      case 'source':
        _refreshWebsiteMetadata(entry);
      case 'history':
        _showHistory(entry);
      case 'clean':
        _cleanLocal(entry);
    }
  }

  Future<void> _showEntryMenu(
    CloudGalleryEntry entry,
    BuildContext cardContext,
  ) async {
    if (_syncingMetadata) return;
    final box = cardContext.findRenderObject()! as RenderBox;
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final rect = box.localToGlobal(Offset.zero, ancestor: overlay) & box.size;
    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(rect, Offset.zero & overlay.size),
      items: _entryMenuItems(entry),
    );
    if (action != null && mounted) _entryAction(entry, action);
  }

  Widget _entryMenu(CloudGalleryEntry entry) => PopupMenuButton<String>(
    tooltip: 'cloudActions'.tr,
    onSelected: (action) => _entryAction(entry, action),
    itemBuilder: (_) => _entryMenuItems(entry),
  );

  Future<void> _editCollections(CloudGalleryEntry entry) async {
    final CloudGalleryFacets facets;
    try {
      facets = await _loadFacets();
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(webDavErrorText(error))));
      return;
    }
    if (!mounted) return;
    final selected = entry.collections.toSet();
    final names = {...facets.collections, ...selected};
    var newName = '';
    var fieldRevision = 0;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, updateDialog) => AlertDialog(
          title: Text('cloudEditCollections'.tr),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final name in names)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(name),
                      value: selected.contains(name),
                      onChanged: (value) => updateDialog(() {
                        value == true
                            ? selected.add(name)
                            : selected.remove(name);
                      }),
                    ),
                  TextFormField(
                    key: ValueKey(fieldRevision),
                    initialValue: newName,
                    onChanged: (value) => newName = value,
                    decoration: InputDecoration(
                      labelText: 'cloudNewCollection'.tr,
                    ),
                    onFieldSubmitted: (value) {
                      if (value.trim().isNotEmpty)
                        updateDialog(() {
                          names.add(value.trim());
                          selected.add(value.trim());
                          newName = '';
                          fieldRevision++;
                        });
                    },
                  ),
                  TextButton.icon(
                    onPressed: () {
                      if (newName.trim().isNotEmpty)
                        updateDialog(() {
                          names.add(newName.trim());
                          selected.add(newName.trim());
                          newName = '';
                          fieldRevision++;
                        });
                    },
                    icon: const Icon(Icons.add),
                    label: Text('cloudAddCollection'.tr),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => updateDialog(() {
                selected.clear();
                newName = '';
                fieldRevision++;
              }),
              child: Text('clear'.tr),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('cancel'.tr),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('save'.tr),
            ),
          ],
        ),
      ),
    );
    final pendingName = newName.trim();
    if (saved != true) return;
    final result = {...selected, if (pendingName.isNotEmpty) pendingName};
    if (result.length == entry.collections.toSet().length &&
        result.containsAll(entry.collections))
      return;
    try {
      await gallerySyncService.requestMetadataRevision(
        entry.manifestId,
        collections: result.toList(),
      );
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('cloudQueued'.tr)));
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(webDavErrorText(error))));
    }
  }

  String _modeText(String representation) => switch (representation) {
    'original' => 'cloudOriginal'.tr,
    'resampled' => 'cloudResampled'.tr,
    _ => 'cloudUnspecified'.tr,
  };

  String _localStateText(CloudLocalState state) => switch (state) {
    CloudLocalState.available => 'cloudLocalAvailable'.tr,
    CloudLocalState.releasing => 'cloudReleasing'.tr,
    CloudLocalState.released => 'cloudReleased'.tr,
    CloudLocalState.none => 'cloudRemoteAvailable'.tr,
  };

  Widget _cover(CloudGalleryEntry entry) {
    final future = _thumbnails.putIfAbsent(
      entry.manifestId,
      () => gallerySyncService.thumbnailFile(entry),
    );
    return FutureBuilder<File?>(
      future: future,
      builder: (context, snapshot) {
        final file = snapshot.data;
        if (file == null) return const Icon(Icons.image_outlined);
        return Image.file(
          file,

          fit: BoxFit.cover,
          alignment: Alignment.topLeft,
          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined),
        );
      },
    );
  }
}
