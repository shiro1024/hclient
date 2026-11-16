import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

import '../config/ui_config.dart';
import '../consts/locale_consts.dart';
import '../extension/widget_extension.dart';
import '../model/gallery_tag.dart';
import '../setting/preference_setting.dart';
import '../utils/date_util.dart';
import 'eh_gallery_category_tag.dart';
import 'eh_tag.dart';

/// Gallery facts shared by website lists and the cloud library. Account and
/// download-task state belong to the caller, not this presentation layer.
class EHGalleryCardHeader extends StatelessWidget {
  final String title;
  final String? uploader;
  final int titleLines;
  final int uploaderLines;

  const EHGalleryCardHeader({
    super.key,
    required this.title,
    this.uploader,
    this.titleLines = 2,
    this.uploaderLines = 2,
  });

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        maxLines: titleLines,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: UIConfig.galleryCardTitleSize,
          height: 1.2,
        ),
      ),
      if (uploader != null && uploader!.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            uploader!,
            maxLines: uploaderLines,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: UIConfig.galleryCardTextSize,
              color: UIConfig.galleryCardTextColor(context),
            ),
          ),
        ),
    ],
  );
}

class EHGalleryCardRating extends StatelessWidget {
  final double rating;
  final bool hasRated;
  final double size;

  const EHGalleryCardRating({
    super.key,
    required this.rating,
    this.hasRated = false,
    this.size = 16,
  });

  @override
  Widget build(BuildContext context) => RatingBar.builder(
    unratedColor: UIConfig.galleryRatingStarUnRatedColor(context),
    initialRating: rating,
    itemCount: 5,
    allowHalfRating: true,
    itemSize: size,
    ignoreGestures: true,
    itemBuilder: (context, _) => Icon(
      Icons.star,
      color: hasRated
          ? UIConfig.galleryRatingStarRatedColor(context)
          : UIConfig.galleryRatingStarColor,
    ),
    onRatingUpdate: (_) {},
  );
}

class EHGalleryCardTime extends StatelessWidget {
  final String time;
  final bool expunged;

  const EHGalleryCardTime({
    super.key,
    required this.time,
    this.expunged = false,
  });

  @override
  Widget build(BuildContext context) => Text(
    preferenceSetting.showUtcTime.value
        ? time
        : DateUtil.transformUtc2LocalTimeString(time),
    style: TextStyle(
      fontSize: UIConfig.galleryCardTextSize,
      color: UIConfig.galleryCardTextColor(context),
      decoration: expunged ? TextDecoration.lineThrough : null,
    ),
  );
}

/// A naturally sized body: cloud cards can grow with text size while retaining
/// the website card's typography, category, rating and translated tag widgets.
class EHGalleryCardContent extends StatelessWidget {
  final Widget cover;
  final String title;
  final String? category;
  final String? uploader;
  final String? publishTime;
  final String? language;
  final double? rating;
  final int pageCount;
  final List<GalleryTag> tags;
  final ValueChanged<GalleryTag>? onTagTap;
  final Key? tagsKey;
  final String? metadataLine;
  final List<Widget> additionalLabels;

  const EHGalleryCardContent({
    super.key,
    required this.cover,
    required this.title,
    required this.pageCount,
    this.category,
    this.uploader,
    this.publishTime,
    this.language,
    this.rating,
    this.tags = const [],
    this.onTagTap,
    this.tagsKey,
    this.metadataLine,
    this.additionalLabels = const [],
  });

  @override
  Widget build(BuildContext context) {
    final small = TextStyle(
      fontSize: UIConfig.galleryCardTextSize,
      color: UIConfig.galleryCardTextColor(context),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(width: 76, height: 104, child: cover),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EHGalleryCardHeader(
                    title: title,
                    uploader: uploader,
                    uploaderLines: 1,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 7,
                    runSpacing: 3,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (category != null)
                        IntrinsicWidth(
                          child: EHGalleryCategoryTag(
                            category: category!,
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
                      Text('${pageCount}P', style: small),
                      if (language != null)
                        Text(
                          LocaleConsts.language2Abbreviation[language] ??
                              language!,
                          style: small,
                        ),
                    ],
                  ),
                  if (rating != null ||
                      (publishTime != null && publishTime!.isNotEmpty))
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Wrap(
                        spacing: 7,
                        runSpacing: 3,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (rating != null)
                            EHGalleryCardRating(rating: rating!, size: 13),
                          if (publishTime != null && publishTime!.isNotEmpty)
                            EHGalleryCardTime(time: publishTime!),
                        ],
                      ),
                    ),
                  if (metadataLine != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(metadataLine!, style: small),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (tags.isNotEmpty || additionalLabels.isNotEmpty)
          SingleChildScrollView(
            key: tagsKey,
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final tag in tags)
                  Semantics(
                    button: onTagTap != null,
                    label:
                        '${tag.tagData.namespace}:${tag.tagData.tagName ?? tag.tagData.key}',
                    child: InkWell(
                      onTap: onTagTap == null ? null : () => onTagTap!(tag),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(0, 12, 6, 12),
                        child: EHTag(
                          tag: tag,
                          height:
                              (MediaQuery.textScalerOf(context).scale(12) + 12)
                                  .clamp(24, double.infinity),
                        ),
                      ),
                    ),
                  ),
                ...additionalLabels,
              ],
            ),
          ).enableMouseDrag(withScrollBar: false),
      ],
    );
  }
}
