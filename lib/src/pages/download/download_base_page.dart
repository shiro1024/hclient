import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/enum/config_enum.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:jhentai/src/pages/download/grid/local/local_gallery_grid_page.dart';
import 'package:jhentai/src/service/local_config_service.dart';
import 'package:jhentai/src/setting/preference_setting.dart';
import 'package:jhentai/src/setting/style_setting.dart';
import 'package:jhentai/src/model/jh_layout.dart';

import '../layout/mobile_v2/notification/tap_menu_button_notification.dart';

import 'package:simple_animations/animation_controller_extension/animation_controller_extension.dart';
import 'package:simple_animations/animation_mixin/animation_mixin.dart';

import 'grid/archive/archive_grid_download_page.dart';
import 'grid/gallery/gallery_grid_download_page.dart';
import 'list/archive/archive_list_download_page.dart';
import 'list/gallery/gallery_list_download_page.dart';
import 'list/local/local_gallery_list_page.dart';
import 'cloud/cloud_gallery_page.dart';
import 'cloud/cloud_transfer_sheet.dart';

class DownloadPage extends StatefulWidget {
  final DownloadPageGalleryType? initialGalleryType;
  final bool initialShowCloudTransfers;

  const DownloadPage({
    Key? key,
    this.initialGalleryType,
    this.initialShowCloudTransfers = false,
  }) : super(key: key);

  @override
  State<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage> {
  DownloadPageGalleryType galleryType =
      preferenceSetting.defaultDownloadTab.value;
  DownloadPageBodyType bodyType = GetPlatform.isMobile
      ? DownloadPageBodyType.list
      : DownloadPageBodyType.grid;
  Completer<void> bodyTypeCompleter = Completer<void>();

  @override
  void initState() {
    super.initState();
    galleryType = widget.initialGalleryType ?? galleryType;
    if (widget.initialShowCloudTransfers) {
      galleryType = DownloadPageGalleryType.cloud;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showCloudTransfers(context);
      });
    }

    localConfigService
        .read(configKey: ConfigEnum.downloadPageBodyType)
        .then((bodyTypeString) {
          if (bodyTypeString != null) {
            bodyType =
                DownloadPageBodyType.values[int.tryParse(bodyTypeString) ?? 0];
          }
        })
        .whenComplete(() {
          bodyTypeCompleter.complete();
        });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: NotificationListener<DownloadPageBodyTypeChangeNotification>(
        onNotification: (DownloadPageBodyTypeChangeNotification notification) {
          setState(() {
            galleryType = notification.galleryType ?? galleryType;
            bodyType = notification.bodyType ?? bodyType;
          });
          localConfigService.write(
            configKey: ConfigEnum.downloadPageBodyType,
            value: (notification.bodyType ?? bodyType).index.toString(),
          );
          return true;
        },
        child: FutureBuilder(
          future: bodyTypeCompleter.future,
          builder: (_, __) => !bodyTypeCompleter.isCompleted
              ? const Center()
              : galleryType == DownloadPageGalleryType.download
              ? bodyType == DownloadPageBodyType.list
                    ? GalleryListDownloadPage(
                        key: const PageStorageKey('GalleryListDownloadBody'),
                      )
                    : GalleryGridDownloadPage(
                        key: const PageStorageKey('GalleryGridDownloadBody'),
                      )
              : galleryType == DownloadPageGalleryType.archive
              ? bodyType == DownloadPageBodyType.list
                    ? ArchiveListDownloadPage(
                        key: const PageStorageKey('ArchiveListDownloadBody'),
                      )
                    : ArchiveGridDownloadPage(
                        key: const PageStorageKey('ArchiveGridDownloadBody'),
                      )
              : galleryType == DownloadPageGalleryType.cloud
              ? const CloudGalleryPage(key: PageStorageKey('CloudGalleryBody'))
              : bodyType == DownloadPageBodyType.list
              ? LocalGalleryListPage(
                  key: const PageStorageKey('LocalGalleryListBody'),
                )
              : LocalGalleryGridPage(
                  key: const PageStorageKey('LocalGalleryGridBody'),
                ),
        ),
      ),
    ).enableMouseDrag();
  }
}

enum DownloadPageGalleryType { download, archive, local, cloud }

enum DownloadPageBodyType { list, grid }

class DownloadPageBodyTypeChangeNotification extends Notification {
  DownloadPageGalleryType? galleryType;
  DownloadPageBodyType? bodyType;

  DownloadPageBodyTypeChangeNotification({this.galleryType, this.bodyType});
}

/// Supplies the actual pane width before Scaffold reads the app bar height.
class DownloadPageToolbarLayout extends StatelessWidget {
  final WidgetBuilder builder;

  const DownloadPageToolbarLayout({super.key, required this.builder});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => _DownloadPageToolbarWidth(
      width: constraints.maxWidth,
      child: Builder(builder: builder),
    ),
  );
}

class _DownloadPageToolbarWidth extends InheritedWidget {
  final double width;

  const _DownloadPageToolbarWidth({required this.width, required super.child});

  @override
  bool updateShouldNotify(_DownloadPageToolbarWidth oldWidget) =>
      width != oldWidget.width;
}

/// Keeps all four categories available when toolbar actions need their own row.
class DownloadPageAppBar extends AppBar {
  factory DownloadPageAppBar({
    Key? key,
    required BuildContext context,
    required DownloadPageGalleryType galleryType,
    Widget? title,
    Widget? leading,
    List<Widget> actions = const [],
  }) {
    final theme = Theme.of(context);
    final labels = _downloadTabLabels;
    final labelPadding = (theme.tabBarTheme.labelPadding ?? kTabLabelPadding)
        .resolve(Directionality.of(context));
    var navigationWidth = 0.0;
    var tabHeight = kMinInteractiveDimension;
    for (final label in labels) {
      var labelWidth = 0.0;
      // TabBar interpolates selected and unselected styles; measure both.
      for (final style in [
        theme.textTheme.titleSmall!.merge(theme.tabBarTheme.labelStyle),
        theme.textTheme.titleSmall!.merge(
          theme.tabBarTheme.unselectedLabelStyle ??
              theme.tabBarTheme.labelStyle,
        ),
      ]) {
        final painter = TextPainter(
          text: TextSpan(text: label, style: style),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        labelWidth = math.max(labelWidth, painter.width);
        tabHeight = math.max(tabHeight, painter.height + labelPadding.vertical);
        painter.dispose();
      }
      navigationWidth += labelWidth + labelPadding.horizontal;
    }
    final paneWidth =
        context
            .dependOnInheritedWidgetOfExactType<_DownloadPageToolbarWidth>()
            ?.width ??
        MediaQuery.sizeOf(context).width;
    final leadingWidth =
        leading != null ||
            (ModalRoute.of(context)?.impliesAppBarDismissal ?? false)
        ? theme.appBarTheme.leadingWidth ?? kToolbarHeight
        : 0.0;
    final actionWidth =
        theme.materialTapTargetSize == MaterialTapTargetSize.padded
        ? kMinInteractiveDimension
        : 40.0;
    // Keep the layout stable when changing categories with fewer actions.
    final availableWidth =
        paneWidth -
        MediaQuery.paddingOf(context).horizontal -
        leadingWidth -
        2 *
            (theme.appBarTheme.titleSpacing ??
                NavigationToolbar.kMiddleSpacing) -
        math.max(3, actions.length) * actionWidth;
    final stacked = title != null || navigationWidth > availableWidth;
    final navigation = DownloadPageTabBar(
      galleryType: galleryType,
      tabHeight: tabHeight,
    );
    return DownloadPageAppBar._(
      key: key,
      title:
          title ??
          (stacked
              ? null
              : SizedBox(width: navigationWidth, child: navigation)),
      leading: leading,
      actions: actions,
      toolbarHeight: stacked
          ? null
          : math.max(
              theme.appBarTheme.toolbarHeight ?? kToolbarHeight,
              tabHeight + 2,
            ),
      bottom: stacked
          ? PreferredSize(
              preferredSize: Size.fromHeight(tabHeight + 2),
              child: navigation,
            )
          : null,
    );
  }

  DownloadPageAppBar._({
    super.key,
    super.title,
    super.leading,
    super.actions,
    super.toolbarHeight,
    super.bottom,
  }) : super(centerTitle: false);
}

const downloadNavigationMenuAction = -1;

bool showDownloadNavigationMenu(BuildContext pageContext) =>
    styleSetting.actualLayout == LayoutMode.mobileV2 &&
    !(ModalRoute.of(pageContext)?.impliesAppBarDismissal ?? false);

PopupMenuItem<T> downloadNavigationMenuItem<T>(T value) =>
    PopupMenuItem<T>(value: value, child: Text('navigationMenu'.tr));

void openDownloadNavigationMenu(BuildContext pageContext) =>
    TapMenuButtonNotification().dispatch(pageContext);

List<String> get _downloadTabLabels => [
  'download'.tr,
  'archive'.tr,
  'local'.tr,
  'cloud'.tr,
];

class DownloadPageTabBar extends StatelessWidget {
  final DownloadPageGalleryType galleryType;
  final double tabHeight;

  const DownloadPageTabBar({
    super.key,
    required this.galleryType,
    required this.tabHeight,
  });

  @override
  Widget build(BuildContext context) => DefaultTabController(
    key: ValueKey(galleryType),
    length: DownloadPageGalleryType.values.length,
    initialIndex: galleryType.index,
    child: TabBar(
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      tabs: [
        for (final label in _downloadTabLabels)
          Tab(height: tabHeight, text: label),
      ],
      onTap: (index) => DownloadPageBodyTypeChangeNotification(
        galleryType: DownloadPageGalleryType.values[index],
      ).dispatch(context),
    ),
  );
}

class GroupOpenIndicator extends StatefulWidget {
  final bool isOpen;

  const GroupOpenIndicator({Key? key, required this.isOpen}) : super(key: key);

  @override
  State<GroupOpenIndicator> createState() => _GroupOpenIndicatorState();
}

class _GroupOpenIndicatorState extends State<GroupOpenIndicator>
    with AnimationMixin {
  bool isOpen = false;
  late Animation<double> animation = Tween<double>(
    begin: 0.0,
    end: -0.25,
  ).animate(controller);

  @override
  void initState() {
    super.initState();

    isOpen = widget.isOpen;
    if (isOpen) {
      controller.forward(from: 1);
    }
  }

  @override
  void didUpdateWidget(covariant GroupOpenIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.isOpen == widget.isOpen) {
      return;
    }

    isOpen = widget.isOpen;
    if (isOpen) {
      controller.play(duration: const Duration(milliseconds: 150));
    } else {
      controller.playReverse(duration: const Duration(milliseconds: 150));
    }
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: animation,
      child: const Icon(Icons.keyboard_arrow_left),
    );
  }
}
