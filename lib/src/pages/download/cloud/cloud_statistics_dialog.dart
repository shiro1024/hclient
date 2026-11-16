import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../service/gallery_sync/gallery_sync_service.dart';
import '../../../service/webdav/webdav_error_text.dart';
import '../../../utils/byte_util.dart';

Future<void> showCloudStatistics(BuildContext context) => showDialog<void>(
  context: context,
  builder: (_) => const CloudStatisticsDialog(),
);

class CloudStatisticsDialog extends StatefulWidget {
  const CloudStatisticsDialog({super.key});

  @override
  State<CloudStatisticsDialog> createState() => _CloudStatisticsDialogState();
}

class _CloudStatisticsDialogState extends State<CloudStatisticsDialog> {
  late Future<CloudGalleryStatistics> _statistics;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _statistics = gallerySyncService.statistics();
  }

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    try {
      await gallerySyncService.refresh();
      if (mounted)
        setState(() => _statistics = gallerySyncService.statistics());
    } catch (error) {
      if (mounted) {
        setState(() => _statistics = gallerySyncService.statistics());
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(webDavErrorText(error))));
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: AlertDialog(
      insetPadding: const EdgeInsets.all(16),
      titlePadding: const EdgeInsets.fromLTRB(20, 8, 4, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      title: Row(
        children: [
          Expanded(child: Text('cloudStatistics'.tr)),
          IconButton(
            tooltip: 'cloudRefresh'.tr,
            onPressed: _refreshing ? null : _refresh,
            icon: _refreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'close'.tr,
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      content: SizedBox(
        width: 640,
        height: MediaQuery.sizeOf(context).height * .72,
        child: FutureBuilder<CloudGalleryStatistics>(
          future: _statistics,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text(webDavErrorText(snapshot.error!)));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final stats = snapshot.data!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  stats.host,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                TabBar(
                  tabs: [
                    Tab(text: 'cloudStatsOverview'.tr),
                    Tab(text: 'cloudStatsDetails'.tr),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [_overview(stats), _details(stats)],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );

  Widget _overview(CloudGalleryStatistics stats) => ListView(
    padding: const EdgeInsets.only(top: 12),
    children: [
      Text(
        'cloudStatsIndexed'.tr,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      if (stats.indexedAt case final date?)
        Text(
          'cloudStatsIndexedAt'.trParams({
            'time': DateFormat('yyyy-MM-dd HH:mm').format(date.toLocal()),
          }),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      if (stats.indexing || !stats.indexComplete || stats.refreshError != null)
        Text(
          (stats.indexing
                  ? 'cloudStatsRefreshing'
                  : stats.refreshError != null
                  ? 'cloudStatsCached'
                  : 'cloudStatsPartial')
              .tr,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      const SizedBox(height: 12),
      _value('cloudStatsFamilies'.tr, '${stats.familyCount}'),
      _value('cloudStatsGids'.tr, '${stats.gidCount}'),
      _value('cloudStatsMultiVersion'.tr, '${stats.multiVersionFamilyCount}'),
      _value('cloudStatsContentCopies'.tr, '${stats.entries.length}'),
      _value('cloudStatsPages'.tr, '${stats.pageCount}'),
      const Divider(),
      _value('cloudStatsRawBytes'.tr, _bytes(stats.rawBytes)),
      _value('cloudStatsStoredBytes'.tr, _bytes(stats.storedBytes)),
      _value('cloudStatsCompression'.tr, _ratio(stats.compressionRatio)),
      _value('cloudStatsUniqueObjects'.tr, '${stats.uniqueObjectCount}'),
      _value('cloudStatsUniqueBytes'.tr, _bytes(stats.uniqueStoredBytes)),
      _value('cloudStatsReuseSavings'.tr, _bytes(stats.reusedStoredBytes)),
      const Divider(),
      for (final representation
          in stats.entries
              .map((entry) => entry.manifest.representation)
              .toSet())
        _value(
          _mode(representation),
          '${stats.entries.where((entry) => entry.manifest.representation == representation).length}',
        ),
    ],
  );

  Widget _details(CloudGalleryStatistics stats) => ListView.separated(
    padding: const EdgeInsets.only(top: 12),
    itemCount: stats.entries.length,
    separatorBuilder: (_, __) => const Divider(height: 20),
    itemBuilder: (context, index) {
      final entry = stats.entries[index];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.manifest.title,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          Text(
            'GID ${entry.manifest.gid} · '
            '${_mode(entry.manifest.representation)} · '
            '${entry.manifest.pages.length} ${'cloudPages'.tr}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          _value('cloudStatsRawBytes'.tr, _bytes(entry.rawBytes)),
          _value('cloudStatsStoredBytes'.tr, _bytes(entry.storedBytes)),
          _value('cloudStatsCompression'.tr, _ratio(entry.compressionRatio)),
        ],
      );
    },
  );

  Widget _value(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: Text(label)),
        const SizedBox(width: 12),
        Flexible(
          flex: 2,
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    ),
  );

  String _mode(String representation) => switch (representation) {
    'original' => 'cloudOriginal'.tr,
    'resampled' => 'cloudResampled'.tr,
    _ => 'cloudUnspecified'.tr,
  };

  String _bytes(int bytes) => byte2String(bytes.toDouble());
  String _ratio(double? value) =>
      value == null ? '—' : '${(value * 100).toStringAsFixed(1)}%';
}
