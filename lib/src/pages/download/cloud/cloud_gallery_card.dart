import 'package:flutter/material.dart';

import '../../../config/ui_config.dart';
import '../../../consts/locale_consts.dart';
import '../../../database/database.dart';
import '../../../model/gallery_tag.dart';
import '../../../service/gallery_sync/gallery_sync_service.dart';
import '../../../service/tag_translation_service.dart';
import '../../../setting/my_tags_setting.dart';
import '../../../widget/eh_gallery_card_content.dart';
import '../../../widget/eh_gallery_category_tag.dart';
import '../../../widget/eh_tag.dart';

class CloudGalleryCardBody extends StatefulWidget {
  final CloudGalleryEntry entry;
  final Widget cover;
  final String metadataLine;
  final String representationLabel;
  final Widget? versionControl;

  const CloudGalleryCardBody({
    super.key,
    required this.entry,
    required this.cover,
    required this.metadataLine,
    required this.representationLabel,
    this.versionControl,
  });

  @override
  State<CloudGalleryCardBody> createState() => _CloudGalleryCardBodyState();
}

class _CloudGalleryCardBodyState extends State<CloudGalleryCardBody> {
  late List<GalleryTag> _tags;
  late Future<List<TagData>> _translated;

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  @override
  void didUpdateWidget(covariant CloudGalleryCardBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry != widget.entry) _loadTags();
  }

  void _loadTags() {
    _tags = widget.entry.tags
        .map(
          (tag) => GalleryTag(
            tagData: TagData(namespace: tag.namespace, key: tag.name),
          ),
        )
        .toList();
    for (final tag in _tags) {
      final info = myTagsSetting.getOnlineTagSetByTagData(tag.tagData);
      if (info == null) continue;
      final background = info.tag.backgroundColor ?? info.tagSetBackGroundColor;
      final hidden = info.tag.hidden || info.tag.weight < 0;
      tag.backgroundColor =
          background ??
          (hidden
              ? UIConfig.ehHiddenTagDefaultBackGroundColor
              : UIConfig.ehWatchedTagDefaultBackGroundColor);
      tag.color =
          background == null ||
              ThemeData.estimateBrightnessForColor(background) ==
                  Brightness.dark
          ? const Color(0xFFF1F1F1)
          : const Color.fromRGBO(9, 9, 9, 1);
    }
    // Keep the source order within each group, as in the website card.
    _tags = [
      ..._tags.where((tag) => tag.backgroundColor != null),
      ..._tags.where((tag) => tag.backgroundColor == null),
    ];
    _translated = tagTranslationService.translateTagDatasIfNeeded(
      _tags.map((tag) => tag.tagData).toList(),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<TagData>>(
    key: ObjectKey(widget.entry),
    future: _translated,
    builder: (context, snapshot) {
      final manifest = widget.entry.manifest;
      final translated = snapshot.data;
      final tags = translated != null && translated.length == _tags.length
          ? [
              for (var i = 0; i < _tags.length; i++)
                _tags[i].copyWith(tagData: translated[i]),
            ]
          : _tags;
      final small = TextStyle(
        fontSize: UIConfig.galleryCardTextSize,
        color: UIConfig.galleryCardTextColor(context),
      );
      return LayoutBuilder(
        builder: (context, constraints) {
          final coverWidth = constraints.maxWidth * 2 / 5;
          const contentPadding = EdgeInsets.fromLTRB(6, 6, 10, 5);
          final availableWidth =
              constraints.maxWidth - coverWidth - contentPadding.horizontal;
          final tagStyle = DefaultTextStyle.of(context).style
              .merge(EHTag.labelStyle);
          final widths = <double>[];
          for (final tag in tags) {
            final painter = TextPainter(
              text: TextSpan(
                text: tag.tagData.tagName ?? tag.tagData.key,
                style: tagStyle,
              ),
              textDirection: Directionality.of(context),
              textScaler: MediaQuery.textScalerOf(context),
              locale: Localizations.maybeLocaleOf(context),
            )..layout();
            widths.add(painter.width + EHTag.contentPadding.horizontal);
            painter.dispose();
          }
          // Measure the same labels EHTag renders, including inherited fonts and
          // system scaling. Three rows is a limit, not a reason to leave gaps.
          final tagRows = <List<int>>[];
          if (tags.isNotEmpty) {
            const spacing = 4.0;
            final totalWidth =
                widths.reduce((a, b) => a + b) + spacing * (tags.length - 1);
            final neededRows = availableWidth > 0
                ? (totalWidth / availableWidth).ceil()
                : 3;
            final rowCount = neededRows.clamp(
              1,
              tags.length < 3 ? tags.length : 3,
            );
            var row = <int>[];
            var rowWidth = 0.0;
            var remainingWidth = totalWidth;
            for (var i = 0; i < tags.length; i++) {
              final balancedWidth =
                  remainingWidth / (rowCount - tagRows.length);
              // One oversized label must not split short neighbours that fit.
              final targetWidth = balancedWidth < availableWidth
                  ? availableWidth
                  : balancedWidth;
              if (row.isNotEmpty &&
                  tagRows.length < rowCount - 1 &&
                  rowWidth + spacing + widths[i] > targetWidth) {
                tagRows.add(row);
                remainingWidth -= rowWidth + spacing;
                row = [];
                rowWidth = 0;
              }
              rowWidth += (row.isEmpty ? 0 : spacing) + widths[i];
              row.add(i);
            }
            tagRows.add(row);
          }
          return Stack(
            children: [
              Padding(
                padding: EdgeInsets.only(left: coverWidth),
                child: Padding(
                  padding: contentPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      EHGalleryCardHeader(
                        title: widget.entry.title,
                        uploader: manifest.uploader,
                      ),
                      if (tags.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: SingleChildScrollView(
                            key: PageStorageKey(
                              'cloud-tags:${widget.entry.manifestId}',
                            ),
                            scrollDirection: Axis.horizontal,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (var row = 0; row < tagRows.length; row++)
                                  Padding(
                                    padding: EdgeInsets.only(
                                      top: row == 0 ? 0 : 4,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        for (final i in tagRows[row])
                                          Padding(
                                            padding: EdgeInsets.only(
                                              left: i == tagRows[row].first
                                                  ? 0
                                                  : 4,
                                            ),
                                            child: Tooltip(
                                              triggerMode:
                                                  TooltipTriggerMode.manual,
                                              message:
                                                  '${_tags[i].tagData.namespace}:${_tags[i].tagData.key}',
                                              child: EHTag(
                                                tag: tags[i],
                                                height: null,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Wrap(
                          spacing: 7,
                          runSpacing: 3,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (manifest.category != null)
                              IntrinsicWidth(
                                child: EHGalleryCategoryTag(
                                  category: manifest.category!,
                                  textStyle: const TextStyle(
                                    fontSize: 10,
                                    color: UIConfig.galleryCategoryTagTextColor,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 3,
                                  ),
                                ),
                              ),
                            if (manifest.language?.isNotEmpty == true)
                              Text(
                                LocaleConsts.language2Abbreviation[manifest
                                        .language] ??
                                    manifest.language!,
                                style: small,
                              ),
                            Text('${manifest.pages.length}P', style: small),
                          ],
                        ),
                      ),
                      if (manifest.rating != null ||
                          manifest.publishTime?.isNotEmpty == true)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Wrap(
                            spacing: 7,
                            runSpacing: 3,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (manifest.rating != null)
                                EHGalleryCardRating(rating: manifest.rating!),
                              if (manifest.publishTime?.isNotEmpty == true)
                                EHGalleryCardTime(time: manifest.publishTime!),
                            ],
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Wrap(
                                key: PageStorageKey(
                                  'cloud-facts:${widget.entry.manifestId}',
                                ),
                                spacing: 7,
                                runSpacing: 3,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    widget.representationLabel,
                                    style: small,
                                  ),
                                  for (final group in widget.entry.collections)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.folder_outlined,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(group, style: small),
                                        ),
                                      ],
                                    ),
                                  Text(widget.metadataLine, style: small),
                                ],
                              ),
                            ),
                            if (widget.versionControl != null)
                              widget.versionControl!,
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: coverWidth,
                child: widget.cover,
              ),
            ],
          );
        },
      );
    },
  );
}

class CloudGalleryTagLabel extends StatefulWidget {
  final String namespace;
  final String name;

  const CloudGalleryTagLabel({
    super.key,
    required this.namespace,
    required this.name,
  });

  @override
  State<CloudGalleryTagLabel> createState() => _CloudGalleryTagLabelState();
}

class _CloudGalleryTagLabelState extends State<CloudGalleryTagLabel> {
  late Future<List<TagData>> _translation;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant CloudGalleryTagLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.namespace != widget.namespace ||
        oldWidget.name != widget.name)
      _load();
  }

  void _load() {
    _translation = tagTranslationService.translateTagDatasIfNeeded([
      TagData(namespace: widget.namespace, key: widget.name),
    ]);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<TagData>>(
    key: ValueKey('${widget.namespace}:${widget.name}'),
    future: _translation,
    builder: (context, snapshot) {
      final tag = snapshot.data?.isNotEmpty == true
          ? snapshot.data!.first
          : null;
      return Text(
        '${tag?.translatedNamespace ?? widget.namespace}:${tag?.tagName ?? widget.name}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    },
  );
}
