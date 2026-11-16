import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../model/image_source_info.dart';
import '../../service/content_codec.dart';
import '../../service/content_sync/content_repository.dart';
import '../../utils/byte_util.dart';

/// Current-page facts, using owner metadata and the existing image decode.
class ReadingImageInfo extends StatelessWidget {
  final Future<ContentPageRecord?> metadata;
  final ImageSourceInfo? source;
  final bool managed;

  const ReadingImageInfo({
    super.key,
    required this.metadata,
    this.source,
    this.managed = false,
  });

  @override
  Widget build(BuildContext context) => FutureBuilder<ContentPageRecord?>(
    future: metadata,
    builder: (context, snapshot) {
      // Replacing a future retains old data; never label the new page with it.
      final page = snapshot.connectionState == ConnectionState.done
          ? snapshot.data
          : null;
      final mime = page?.mime?.startsWith('image/') == true
          ? page!.mime
          : managed
          ? null
          : source?.mime;
      final width = _positive(source?.width) ?? _positive(page?.width);
      final height = _positive(source?.height) ?? _positive(page?.height);
      final rawLength =
          _nonnegative(page?.rawLength) ??
          (managed ? null : _nonnegative(source?.encodedLength));
      final storedLength = _nonnegative(
        page?.storedLength ??
            (page?.codecProfile == ContentCodec.rawProfile
                ? page?.rawLength
                : null),
      );
      final facts = <String>[
        if (mime != null) mime.substring('image/'.length).toUpperCase(),
        if (width != null && height != null) '$width × $height',
      ];
      final original = rawLength == null
          ? null
          : byte2String(rawLength.toDouble());
      final stored = storedLength == null
          ? null
          : byte2String(storedLength.toDouble());
      final originalLabel = original == null
          ? null
          : 'readingImageSourceSize'.trParams({'size': original});
      final storedLabel = stored == null
          ? null
          : 'readingImageStoredSize'.trParams({'size': stored});
      String? sizes;
      String? sizesLabel;
      if (original != null && stored != null) {
        var change = '';
        if (rawLength! > 0) {
          final difference = storedLength! - rawLength;
          final percent = (difference.abs() / rawLength * 100).toStringAsFixed(
            1,
          );
          final sign = percent == '0.0'
              ? ''
              : difference < 0
              ? '−'
              : '+';
          change = '（$sign$percent%）';
        }
        sizes = '$original → $stored$change';
        sizesLabel = '$originalLabel → $storedLabel$change';
      } else {
        sizes = original ?? storedLabel;
        sizesLabel = originalLabel ?? storedLabel;
      }
      if (facts.isEmpty && sizes == null) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: Text(
          [...facts, if (sizes != null) sizes].join(' · '),
          semanticsLabel: [
            ...facts,
            if (sizesLabel != null) sizesLabel,
          ].join(' · '),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: const ColorScheme.dark().onSurface),
        ),
      );
    },
  );

  static int? _positive(int? value) =>
      value != null && value > 0 ? value : null;
  static int? _nonnegative(int? value) =>
      value != null && value >= 0 ? value : null;
}
