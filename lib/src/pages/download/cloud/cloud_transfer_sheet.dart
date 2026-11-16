import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../routes/routes.dart';
import '../../../service/gallery_sync/gallery_sync_service.dart';
import '../../../service/webdav/webdav_error_text.dart';
import '../../../utils/route_util.dart' as route;

Future<void> showCloudTransfers(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => const SafeArea(top: false, child: CloudTransferSheet()),
    );

class CloudTransferSheet extends StatefulWidget {
  const CloudTransferSheet({super.key});

  @override
  State<CloudTransferSheet> createState() => _CloudTransferSheetState();
}

class _CloudTransferSheetState extends State<CloudTransferSheet> {
  late Future<List<CloudSyncJob>> _jobs;
  bool _loadingJobs = false;
  bool _refreshJobsAgain = false;
  final Set<String> _working = {};

  @override
  void initState() {
    super.initState();
    gallerySyncService.addListener(_reload);
    _reload();
  }

  void _reload() {
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
            if (_refreshJobsAgain && mounted) _reload();
          }),
    );
  }

  @override
  void dispose() {
    gallerySyncService.removeListener(_reload);
    super.dispose();
  }

  Future<void> _act(CloudSyncJob job, Future<void> Function() action) async {
    setState(() => _working.add(job.workItemId));
    try {
      await action();
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(webDavErrorText(error))));
    } finally {
      if (mounted) {
        setState(() => _working.remove(job.workItemId));
        _reload();
      }
    }
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: MediaQuery.sizeOf(context).height * .78,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 8, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'cloudSyncJobs'.tr,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
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
          child: FutureBuilder<List<CloudSyncJob>>(
            future: _jobs,
            builder: (context, snapshot) {
              if (snapshot.hasError)
                return Center(child: Text(webDavErrorText(snapshot.error!)));
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());
              final jobs = snapshot.data!;
              if (jobs.isEmpty)
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.cloud_done_outlined,
                          size: 48,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'cloudNoTransfers'.tr,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'cloudNoTransfersHint'.tr,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: jobs.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, index) => _job(jobs[index]),
              );
            },
          ),
        ),
      ],
    ),
  );

  Widget _progressText(CloudSyncJob job, bool failed, [String? speed]) {
    final scheme = Theme.of(context).colorScheme;
    return Text(
      '${job.kind == 'restore' ? 'cloudRestore'.tr : 'cloudUpload'.tr} · ${_state(job.state, restoring: job.kind == 'restore')}${job.totalPages > 0 ? ' · ${job.completedPages}/${job.totalPages} ${'cloudPages'.tr}' : ''}${speed == null ? '' : ' · $speed'}',
      style: TextStyle(
        color: failed ? scheme.error : scheme.onSurfaceVariant,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }

  Widget _job(CloudSyncJob job) {
    final scheme = Theme.of(context).colorScheme;
    final running =
        job.state == 'queued' ||
        job.state == 'running' ||
        job.state == 'publishing';
    final failed = job.state == 'failed';
    final busy = _working.contains(job.workItemId);
    final waiting = job.state == 'waiting_input';
    final restoring = job.kind == 'restore';
    final actionLabel = running
        ? 'cloudPause'.tr
        : failed
        ? 'cloudRetry'.tr
        : 'cloudResume'.tr;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  job.title.isEmpty ? 'cloudEditRevision'.tr : job.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              if (!waiting)
                IconButton(
                  tooltip: actionLabel,
                  onPressed: busy
                      ? null
                      : () => _act(
                          job,
                          () => running
                              ? gallerySyncService.pause(job.workItemId)
                              : gallerySyncService.resume(job.workItemId),
                        ),
                  icon: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          running
                              ? Icons.pause
                              : failed
                              ? Icons.refresh
                              : Icons.play_arrow,
                        ),
                ),
              PopupMenuButton<String>(
                tooltip: 'cloudActions'.tr,
                enabled: !busy,
                onSelected: (_) =>
                    _act(job, () => gallerySyncService.cancel(job.workItemId)),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'cancel',
                    child: Text(
                      restoring
                          ? 'cloudCancelRestore'.tr
                          : 'cloudCancelUpload'.tr,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (job.uploadSpeed == null)
            _progressText(job, failed)
          else
            ValueListenableBuilder<String?>(
              valueListenable: job.uploadSpeed!,
              builder: (_, speed, __) => _progressText(job, failed, speed),
            ),
          if (job.totalPages > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: LinearProgressIndicator(
                minHeight: 2,
                value: (job.completedPages / job.totalPages).clamp(0, 1),
                color: failed ? scheme.error : null,
              ),
            ),
          if (failed)
            InkWell(
              onTap: () => showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('cloudFailed'.tr),
                  content: SingleChildScrollView(
                    child: SelectableText(
                      job.error == null
                          ? 'cloudFailureDetailsUnavailable'.tr
                          : webDavFailureText(job.error!),
                    ),
                  ),
                  actions: [
                    if (job.error?.kind == 'authentication')
                      TextButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          Navigator.pop(this.context);
                          await route.toRoute(Routes.settingWebDav);
                        },
                        child: Text('webdavEditConnection'.tr),
                      ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('close'.tr),
                    ),
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  job.error == null
                      ? 'cloudFailureDetailsUnavailable'.tr
                      : webDavFailureText(job.error!),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: scheme.error),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _state(String state, {bool restoring = false}) => switch (state) {
    'waiting_input' => 'cloudWaitingInput'.tr,
    'queued' => 'cloudQueuedState'.tr,
    'paused' => 'cloudPaused'.tr,
    'failed' => 'cloudFailed'.tr,
    'publishing' => 'cloudPublishing'.tr,
    _ => restoring ? 'cloudDownloading'.tr : 'cloudUploading'.tr,
  };
}
