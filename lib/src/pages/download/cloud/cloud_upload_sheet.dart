import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../service/local_content_service.dart';
import '../../../service/webdav/webdav_error_text.dart';
import '../mixin/basic/webdav_actions.dart';

Future<void> showCloudUploadPicker(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => const _CloudUploadPicker(),
    );

class _CloudUploadPicker extends StatefulWidget {
  const _CloudUploadPicker();
  @override
  State<_CloudUploadPicker> createState() => _CloudUploadPickerState();
}

class _UploadCopy {
  final String id;
  final int gid;
  final String title;
  final int pages;
  const _UploadCopy(this.id, this.gid, this.title, this.pages);
}

class _CloudUploadPickerState extends State<_CloudUploadPicker> {
  late final Future<List<_UploadCopy>> _copies = _load();
  final _selected = <String>{};
  String _search = '';
  bool _cleanup = false;

  Future<List<_UploadCopy>> _load() async {
    final rows = await localContentService.repository.db.customSelect(r'''
      SELECT c.copy_id, c.gid, c.metadata_json, COUNT(p.ordinal) AS page_count
      FROM content_copy c JOIN content_page p ON p.copy_id = c.copy_id
      WHERE c.lifecycle = 'active' AND c.metadata_json IS NOT NULL
        AND NOT EXISTS (
          SELECT 1 FROM content_page_replacement r
          WHERE r.copy_id = c.copy_id AND r.state != 'completed'
        )
      GROUP BY c.copy_id
      HAVING COUNT(p.ordinal) = json_extract(c.metadata_json, '$.expectedPages')
        AND MIN(p.ordinal) = 0 AND MAX(p.ordinal) = COUNT(p.ordinal) - 1
        AND SUM(CASE WHEN p.state = 'completed' THEN 1 ELSE 0 END) = COUNT(p.ordinal)
      ORDER BY c.created_at DESC
    ''').get();
    return rows.map((row) {
      final metadata = jsonDecode(row.read<String>('metadata_json')) as Map;
      return _UploadCopy(
        row.read<String>('copy_id'),
        row.read<int>('gid'),
        metadata['title'] as String,
        row.read<int>('page_count'),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SizedBox(
      height:
          (MediaQuery.sizeOf(context).height -
              MediaQuery.viewInsetsOf(context).bottom) *
          .86,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'cloudChooseUploads'.tr,
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
            child: FutureBuilder<List<_UploadCopy>>(
              future: _copies,
              builder: (context, snapshot) {
                final copies = (snapshot.data ?? const <_UploadCopy>[])
                    .where(
                      (copy) =>
                          copy.title.toLowerCase().contains(_search) ||
                          copy.gid.toString().contains(_search),
                    )
                    .toList();
                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'cloudSearchLocal'.tr,
                            prefixIcon: const Icon(Icons.search),
                            border: const OutlineInputBorder(),
                          ),
                          onChanged: (text) => setState(
                            () => _search = text.trim().toLowerCase(),
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SwitchListTile.adaptive(
                        title: Text('cloudUploadAndClean'.tr),
                        subtitle: Text('cloudUploadAndCleanHint'.tr),
                        value: _cleanup,
                        onChanged: (value) => setState(() => _cleanup = value),
                      ),
                    ),
                    if (snapshot.hasError)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(webDavErrorText(snapshot.error!)),
                        ),
                      )
                    else if (!snapshot.hasData)
                      const SliverToBoxAdapter(
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (copies.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _search.isEmpty
                                ? 'cloudNoCompleted'.tr
                                : 'cloudNoMatches'.tr,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    else
                      SliverList.builder(
                        itemCount: copies.length,
                        itemBuilder: (_, index) {
                          final copy = copies[index];
                          return CheckboxListTile(
                            value: _selected.contains(copy.id),
                            onChanged: (selected) => setState(
                              () => selected == true
                                  ? _selected.add(copy.id)
                                  : _selected.remove(copy.id),
                            ),
                            title: Text(
                              copy.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${copy.pages} ${'cloudPages'.tr} · GID ${copy.gid}',
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                          );
                        },
                      ),
                  ],
                );
              },
            ),
          ),
          const Divider(height: 1),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: FilledButton.icon(
                onPressed: _selected.isEmpty
                    ? null
                    : () {
                        final ids = _selected.toList();
                        Navigator.pop(context);
                        queueCloudUploads(
                          ids.map(
                            (id) =>
                                () async => id,
                          ),
                          cleanupAfterUpload: _cleanup,
                        );
                      },
                icon: const Icon(Icons.cloud_upload_outlined),
                label: Text(
                  'cloudUploadSelected'.trParams({
                    'count': '${_selected.length}',
                  }),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
