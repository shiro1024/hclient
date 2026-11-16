import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/l18n/locale_text.dart';
import 'package:jhentai/src/pages/download/cloud/cloud_gallery_page.dart';
import 'package:jhentai/src/pages/download/cloud/cloud_gallery_card.dart';
import 'package:jhentai/src/pages/layout/mobile_v2/notification/tap_menu_button_notification.dart';
import 'package:jhentai/src/model/jh_layout.dart';
import 'package:jhentai/src/setting/style_setting.dart';
import 'package:jhentai/src/pages/download/cloud/cloud_transfer_sheet.dart';
import 'package:jhentai/src/pages/download/cloud/cloud_upload_sheet.dart';
import 'package:jhentai/src/pages/download/download_base_page.dart';
import 'package:jhentai/src/pages/download/list/local/local_gallery_list_page.dart';
import 'package:jhentai/src/pages/download/list/gallery/gallery_list_download_page.dart';
import 'package:jhentai/src/pages/download/list/archive/archive_list_download_page.dart';
import 'package:jhentai/src/pages/download/grid/local/local_gallery_grid_page.dart';
import 'package:jhentai/src/pages/download/mixin/basic/webdav_actions.dart';
import 'package:jhentai/src/service/content_sync/content_repository.dart';
import 'package:jhentai/src/service/content_sync/portable_manifest.dart';
import 'package:jhentai/src/service/gallery_sync/gallery_sync_service.dart';
import 'package:jhentai/src/service/gallery_sync/upload_speed.dart';
import 'package:jhentai/src/service/local_content_service.dart';
import 'package:jhentai/src/service/log.dart';
import 'package:jhentai/src/service/tag_translation_service.dart';
import 'package:jhentai/src/widget/eh_gallery_card_content.dart';
import 'package:jhentai/src/widget/eh_tag.dart';
import 'package:jhentai/src/setting/my_tags_setting.dart';
import 'package:jhentai/src/model/tag_set.dart';
import 'package:jhentai/src/model/gallery_tag.dart';
import 'package:jhentai/src/service/webdav/webdav_error_text.dart';
import 'package:jhentai/src/setting/webdav_setting.dart';

import 'support/test_log_service.dart';

class FakeCloudUiService extends GallerySyncService {
  List<CloudGalleryEntry> entries = [];
  List<CloudSyncJob> jobs = [];
  bool failQuery = false;
  int queries = 0;
  final heldEntries = <Completer<List<CloudGalleryEntry>>>[];
  int retries = 0;
  final List<String> restores = [];
  Completer<String>? heldRestore;
  @override
  Future<String> restore(String manifestId) async {
    restores.add(manifestId);
    if (heldRestore != null) return heldRestore!.future;
    throw const FormatException('fixture restore unavailable');
  }

  int jobQueries = 0;
  Completer<List<CloudSyncJob>>? heldJobs;
  void announceJobs() => notifyListeners();
  String? queriedCategory;
  String? queriedCollection;
  String? queriedSearch;
  PortableTag? queriedTag;
  final List<String> metadataRequests = [];
  final List<String> uploadRequests = [];
  @override
  Future<String> requestUpload(
    String copyId, {
    bool cleanupAfterUpload = false,
  }) async {
    uploadRequests.add(copyId);
    return 'work-$copyId';
  }

  String? serverTitle;
  final List<
    ({
      String? title,
      List<PortableTag>? tags,
      List<String>? collections,
      List<ManifestLineage>? added,
      List<ManifestLineage>? removed,
    })
  >
  revisionEdits = [];
  final List<String> thumbnailRequests = [];
  final Map<String, File> thumbnailFiles = {};
  CloudGalleryFacets facets = const CloudGalleryFacets(
    categories: [],
    collections: [],
    tags: [],
  );

  @override
  Future<List<CloudGalleryEntry>> listCloudEntries({
    String search = '',
    String? representation,
    String? category,
    String? collection,
    PortableTag? tag,
    int limit = 40,
    int offset = 0,
  }) async {
    queries++;
    queriedCategory = category;
    queriedCollection = collection;
    queriedTag = tag;
    queriedSearch = search;
    if (heldEntries.isNotEmpty) return heldEntries.removeAt(0).future;
    if (failQuery) throw const FormatException('broken local query');
    return entries;
  }

  @override
  Future<CloudGalleryFacets> listCloudFacets() async => facets;

  @override
  Future<File?> thumbnailFile(CloudGalleryEntry entry) async {
    thumbnailRequests.add(entry.manifestId);
    return thumbnailFiles[entry.manifestId];
  }

  @override
  Future<String> requestWebsiteMetadataRevision(CloudGalleryEntry entry) async {
    metadataRequests.add(entry.manifestId);
    return 'work-${entry.manifestId}';
  }

  @override
  Future<String> requestMetadataRevision(
    String baseManifestId, {
    String? title,
    List<PortableTag>? tags,
    List<ManifestLineage>? lineageAdded,
    List<ManifestLineage>? lineageRemoved,
    Map<String, Object?>? providerMetadata,
    List<String>? collections,
    PortableThumbnail? thumbnail,
    File? thumbnailArtifact,
  }) async {
    revisionEdits.add((
      title: title,
      tags: tags,
      collections: collections,
      added: lineageAdded,
      removed: lineageRemoved,
    ));
    if (title != null) serverTitle = title;
    return 'metadata-work';
  }

  @override
  Future<List<CloudSyncJob>> listSyncJobs({String? finishAction}) async {
    jobQueries++;
    if (heldJobs != null) return heldJobs!.future;
    return finishAction == null
        ? jobs
        : jobs.where((job) => job.finishAction == finishAction).toList();
  }

  @override
  Future<void> ensureInitialDiscovery() async {}
  @override
  Future<void> refresh() async {
    failQuery = false;
    lastError = null;
  }

  @override
  Future<void> resume(String workId) async {
    retries++;
  }
}

class FakeTagTranslationService extends TagTranslationService {
  @override
  Future<List<TagData>> translateTagDatasIfNeeded(List<TagData> tags) async => [
    for (final tag in tags)
      tag.key == 'sample-tag'
          ? TagData(
              namespace: tag.namespace,
              key: tag.key,
              tagName: '示例标签',
              translatedNamespace: '艺术家',
            )
          : tag,
  ];
}

CloudGalleryEntry cloudFixture(int gid, {bool metadata = true}) =>
    CloudGalleryEntry(
      gid: gid,
      representation: 'original',
      title: 'Public sample $gid',
      manifestId: 'manifest-$gid',
      manifest: PortableManifest(
        gid: gid,
        representation: 'original',
        galleryUrl: 'https://e-hentai.org/g/$gid/token/',
        title: 'Public sample $gid',
        tags: const [PortableTag('artist', 'sample-tag')],
        pages: const [],
        category: metadata ? 'Manga' : null,
        uploader: metadata ? 'Example uploader' : null,
        publishTime: metadata ? '2026-11-15 12:00' : null,
        rating: metadata ? 4.5 : null,
        collections: const ['My group'],
      ),
      equivalentManifestIds: ['manifest-$gid'],
      localCopyId: null,
      localState: CloudLocalState.none,
      aggregatedTags: const [
        PortableTag('artist', 'sample-tag'),
        PortableTag('language', 'chinese'),
      ],
      aggregatedCollections: const ['My group', 'Second device group'],
    );

CloudGalleryEntry metadataDialogFixture() {
  final base = cloudFixture(3);
  return CloudGalleryEntry(
    gid: base.gid,
    representation: base.representation,
    title: base.title,
    manifestId: base.manifestId,
    manifest: base.manifest.copyWith(
      lineage: const [
        ManifestLineage(10, 3, 'source_parent'),
        ManifestLineage(20, 3, 'source_parent'),
        ManifestLineage(30, 3, 'download_upgrade'),
      ],
    ),
    equivalentManifestIds: base.equivalentManifestIds,
    localCopyId: null,
    localState: CloudLocalState.none,
  );
}

CloudGalleryEntry publicCloudFixture(int gid, {bool missingMetadata = false}) {
  final file = File('test/fixtures/cloud_gallery/nursery_alice_cover.jpg');
  final bytes = file.readAsBytesSync();
  final hash = sha256.convert(bytes).toString();
  return CloudGalleryEntry(
    gid: gid,
    representation: 'original',
    title: missingMetadata
        ? 'The Nursery Alice — missing cover'
        : 'The Nursery Alice — illustrated cover (1889)',
    manifestId: 'public-$gid',
    manifest: PortableManifest(
      gid: gid,
      representation: 'original',
      galleryUrl: 'https://www.gutenberg.org/ebooks/55040',
      title: 'The Nursery Alice',
      category: missingMetadata ? null : 'Image Set',
      uploader: missingMetadata ? null : 'E. Gertrude Thomson',
      publishTime: missingMetadata ? null : '1889-01-01 12:00',
      rating: missingMetadata ? null : 4.5,
      language: 'english',
      collections: const ['Public domain'],
      tags: const [
        PortableTag('language', 'english'),
        PortableTag('artist', 'e. gertrude thomson'),
      ],
      pages: [
        PortablePage(
          rawHash: hash,
          rawLength: bytes.length,
          objectHash: hash,
          storedLength: bytes.length,
          codecProfile: 'raw',
          mime: 'image/jpeg',
          width: 600,
          height: 759,
        ),
      ],
    ),
    equivalentManifestIds: ['public-$gid'],
    localCopyId: null,
    localState: CloudLocalState.none,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late GallerySyncService oldSync;
  late WebDavSetting oldSetting;
  late FakeCloudUiService fake;
  late AppDb db;
  late AppDb oldDb;
  late LocalContentService oldContent;
  late LogService oldLog;
  late TagTranslationService oldTags;
  late LayoutMode oldLayout;
  late MyTagsSetting oldMyTags;

  setUp(() {
    oldLayout = styleSetting.actualLayout;
    styleSetting.actualLayout = LayoutMode.mobileV2;
    oldSync = gallerySyncService;
    oldSetting = webDavSetting;
    oldDb = appDb;
    oldContent = localContentService;
    oldLog = log;
    oldMyTags = myTagsSetting;
    myTagsSetting = MyTagsSetting();
    oldTags = tagTranslationService;
    tagTranslationService = FakeTagTranslationService();
    log = TestLogService();
    db = AppDb.testing(NativeDatabase.memory());
    appDb = db;
    localContentService = LocalContentService(
      repository: ContentRepository(db),
    );
    fake = FakeCloudUiService();
    gallerySyncService = fake;
    webDavSetting = WebDavSetting()..address.value = 'https://dav.example/sync';
    Get.testMode = true;
  });
  tearDown(() async {
    styleSetting.actualLayout = oldLayout;
    gallerySyncService = oldSync;
    webDavSetting = oldSetting;
    localContentService = oldContent;
    appDb = oldDb;
    log = oldLog;
    tagTranslationService = oldTags;
    myTagsSetting = oldMyTags;
    await db.close();
    Get.reset();
  });

  Future<void> mount(
    WidgetTester tester,
    Widget home, {
    double scale = 1,
    double keyboard = 0,
    double bottomPadding = 0,
    TargetPlatform? platform,
    Size size = const Size(360, 800),
    bool settle = true,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      GetMaterialApp(
        translations: LocaleText(),
        locale: const Locale('zh', 'CN'),
        theme: ThemeData(
          platform: platform,
          useMaterial3: true,
          colorSchemeSeed: const Color(0xff6750a4),
        ),
        builder: (_, child) => MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(scale),
            viewInsets: EdgeInsets.only(bottom: keyboard),
            padding: EdgeInsets.only(bottom: keyboard > 0 ? 0 : bottomPadding),
            viewPadding: EdgeInsets.only(bottom: bottomPadding),
          ),
          child: child!,
        ),
        home: home,
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  Future<void> openRevisionDialog(WidgetTester tester) async {
    await tester.longPress(find.text('Public sample 3'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('cloudEditRevision'.tr));
    await tester.pumpAndSettle();
  }

  Finder revisionFields() => find.descendant(
    of: find.byType(AlertDialog),
    matching: find.byType(TextField),
  );

  testWidgets(
    'catalog updates coalesce without hiding the first completed list',
    (tester) async {
      final first = Completer<List<CloudGalleryEntry>>();
      final latest = Completer<List<CloudGalleryEntry>>();
      fake.heldEntries.addAll([first, latest]);
      await mount(tester, const CloudGalleryPage(), settle: false);
      for (var i = 0; i < 80; i++) {
        fake.catalogRevision++;
        fake.notifyListeners();
      }
      expect(fake.queries, 1);
      first.complete([cloudFixture(1)]);
      await tester.pump();
      await tester.pump();
      expect(fake.queries, 2);
      expect(find.text('Public sample 1'), findsOneWidget);
      latest.complete([cloudFixture(2)]);
      await tester.pumpAndSettle();
      expect(fake.queries, 2);
      expect(find.text('Public sample 2'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('connection changes discard the old pending catalog result', (
    tester,
  ) async {
    final oldTarget = Completer<List<CloudGalleryEntry>>();
    final newTarget = Completer<List<CloudGalleryEntry>>();
    fake.heldEntries.addAll([oldTarget, newTarget]);
    await mount(tester, const CloudGalleryPage(), settle: false);
    webDavSetting.address.value = 'https://new-dav.example/sync';
    fake.notifyListeners();
    oldTarget.complete([cloudFixture(1)]);
    await tester.pump();
    await tester.pump();
    expect(fake.queries, 2);
    expect(find.text('Public sample 1'), findsNothing);
    newTarget.complete([cloudFixture(2)]);
    await tester.pumpAndSettle();
    expect(find.text('Public sample 2'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('failed catalog reads release the pending refresh', (
    tester,
  ) async {
    final first = Completer<List<CloudGalleryEntry>>();
    final next = Completer<List<CloudGalleryEntry>>();
    fake.heldEntries.addAll([first, next]);
    await mount(tester, const CloudGalleryPage(), settle: false);
    fake.catalogRevision++;
    fake.notifyListeners();
    first.completeError(const FormatException('local query failed'));
    await tester.pump();
    await tester.pump();
    expect(fake.queries, 2);
    next.complete([cloudFixture(2)]);
    await tester.pumpAndSettle();
    expect(find.text('Public sample 2'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'all four real download toolbars keep tabs aligned and wide toolbars use one row',
    (tester) async {
      late GalleryListDownloadPage gallery;
      late ArchiveListDownloadPage archive;
      final local = LocalGalleryListPage();
      await tester.runAsync(() async {
        gallery = GalleryListDownloadPage();
        archive = ArchiveListDownloadPage();
        await Future.wait([
          gallery.state.displayGroupsCompleter.future,
          archive.state.displayGroupsCompleter.future,
        ]);
      });
      for (final platform in [
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.windows,
        TargetPlatform.macOS,
      ]) {
        for (final item in [
          (411.0, 1.0),
          (320.0, 1.0),
          (320.0, 1.8),
          (411.0, 1.8),
          (370.0, 1.0),
          (800.0, 1.0),
        ]) {
          Rect? shared;
          for (final type in DownloadPageGalleryType.values) {
            Widget page;
            if (type == DownloadPageGalleryType.cloud) {
              page = const CloudGalleryPage();
            } else {
              page = DownloadPageToolbarLayout(
                builder: (context) => Scaffold(
                  appBar: switch (type) {
                    DownloadPageGalleryType.download => gallery.buildAppBar(
                      context,
                    ),
                    DownloadPageGalleryType.archive => archive.buildAppBar(
                      context,
                    ),
                    _ => local.buildAppBar(context),
                  },
                ),
              );
            }
            await mount(
              tester,
              Row(
                children: [
                  SizedBox(width: item.$1, child: page),
                  const Expanded(child: SizedBox()),
                ],
              ),
              size: const Size(1200, 900),
              scale: item.$2,
              platform: platform,
            );
            final navigation = find.byType(TabBar);
            expect(navigation, findsOneWidget);
            expect(
              find.byType(DropdownButton<DownloadPageGalleryType>),
              findsNothing,
            );
            final bounds = tester.getRect(navigation);
            if (shared != null) {
              expect(
                bounds.left,
                closeTo(shared.left, .01),
                reason: '$platform ${item.$1} $type leading alignment',
              );
              expect(
                bounds.width,
                closeTo(shared.width, .01),
                reason: '$platform ${item.$1} $type common navigation width',
              );
            }
            shared = bounds;
            if (item.$1 == 800) {
              expect(
                tester.widget<AppBar>(find.byType(DownloadPageAppBar)).bottom,
                isNull,
              );
              expect(
                bounds.width,
                lessThan(item.$1 - 3 * kMinInteractiveDimension),
              );
            }
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
          }
        }
      }
    },
  );

  testWidgets(
    'cover uses two fifths of card constraints and fills content height without a portrait minimum',
    (tester) async {
      for (final scale in [1.0, 1.8]) {
        for (final width in [379.0, 288.0, 200.0, 600.0]) {
          await mount(
            tester,
            Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: width,
                  child: Card(
                    key: const ValueKey('responsive-card'),
                    margin: EdgeInsets.zero,
                    clipBehavior: Clip.antiAlias,
                    child: CloudGalleryCardBody(
                      entry: cloudFixture(1),
                      cover: const ColoredBox(
                        key: ValueKey('responsive-cover'),
                        color: Colors.blue,
                      ),
                      metadataLine: 'GID 1',
                      representationLabel: 'Original',
                    ),
                  ),
                ),
              ),
            ),
            scale: scale,
            size: Size(width + 32, 1400),
          );
          final card = tester.getRect(
            find.byKey(const ValueKey('responsive-card')),
          );
          final cover = tester.getRect(
            find.byKey(const ValueKey('responsive-cover')),
          );
          expect(cover.width / card.width, closeTo(.4, .0001));
          expect(cover.left, card.left);
          expect(cover.top, card.top);
          expect(cover.bottom, card.bottom);
          if (width == 600 && scale == 1) {
            expect(card.height, lessThan(cover.width * 4 / 3));
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        }
      }
    },
  );

  testWidgets(
    'tabs and toolbar actions remain reachable in narrow panes and large text',
    (tester) async {
      for (final platform in [TargetPlatform.android, TargetPlatform.windows]) {
        for (final width in [320.0, 411.0]) {
          for (final scale in [1.0, 1.8]) {
            final selected = <DownloadPageGalleryType>[];
            var actionTaps = 0;
            await mount(
              tester,
              Row(
                children: [
                  SizedBox(
                    width: width,
                    child:
                        NotificationListener<
                          DownloadPageBodyTypeChangeNotification
                        >(
                          onNotification: (notification) {
                            selected.add(notification.galleryType!);
                            return true;
                          },
                          child: DownloadPageToolbarLayout(
                            builder: (context) => Scaffold(
                              appBar: DownloadPageAppBar(
                                context: context,
                                galleryType: DownloadPageGalleryType.cloud,
                                actions: [
                                  for (final icon in [
                                    Icons.search,
                                    Icons.filter_alt_outlined,
                                    Icons.more_vert,
                                  ])
                                    IconButton(
                                      onPressed: () => actionTaps++,
                                      icon: Icon(icon),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                  ),
                  const Expanded(child: SizedBox()),
                ],
              ),
              size: const Size(1200, 800),
              scale: scale,
              platform: platform,
            );
            expect(find.byType(TabBar), findsOneWidget);
            expect(
              find.byType(DropdownButton<DownloadPageGalleryType>),
              findsNothing,
            );
            for (final key in ['download', 'archive', 'local', 'cloud']) {
              final label = find.descendant(
                of: find.byType(TabBar),
                matching: find.text(key.tr),
              );
              await tester.ensureVisible(label);
              await tester.pumpAndSettle();
              await tester.tap(label);
              await tester.pumpAndSettle();
            }
            expect(selected, DownloadPageGalleryType.values);
            for (final icon in [
              Icons.search,
              Icons.filter_alt_outlined,
              Icons.more_vert,
            ]) {
              await tester.tap(find.byIcon(icon));
            }
            expect(actionTaps, 3);
            final tabs = tester.getRect(find.byType(TabBar));
            final actions = tester.getRect(find.byIcon(Icons.search));
            if (width == 320 || scale == 1.8) {
              expect(tabs.top, greaterThan(actions.bottom));
            } else {
              expect(tabs.center.dy, closeTo(actions.center.dy, 1));
            }
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
          }
        }
      }
    },
  );

  testWidgets(
    'pushed download categories keep the native back affordance above all tabs',
    (tester) async {
      for (final type in DownloadPageGalleryType.values) {
        await mount(
          tester,
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => DownloadPageToolbarLayout(
                      builder: (context) => Scaffold(
                        appBar: DownloadPageAppBar(
                          context: context,
                          galleryType: type,
                          actions: [
                            IconButton(
                              onPressed: () {},
                              icon: const Icon(Icons.more_vert),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                child: const Text('Open page'),
              ),
            ),
          ),
          size: const Size(411, 800),
        );
        await tester.tap(find.text('Open page'));
        await tester.pumpAndSettle();
        expect(find.byType(BackButton), findsOneWidget);
        expect(find.byType(TabBar), findsOneWidget);
        expect(find.byType(Tab), findsNWidgets(4));
        expect(
          find.byType(DropdownButton<DownloadPageGalleryType>),
          findsNothing,
        );
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.text('Open page'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );

  testWidgets(
    'root cloud navigation menu dispatches from the page below the popup route',
    (tester) async {
      var opened = 0;
      await mount(
        tester,
        NotificationListener<TapMenuButtonNotification>(
          onNotification: (_) {
            opened++;
            return true;
          },
          child: const CloudGalleryPage(),
        ),
      );
      await tester.tap(find.byTooltip('cloudMoreActions'.tr));
      await tester.pumpAndSettle();
      await tester.tap(find.text('navigationMenu'.tr));
      await tester.pumpAndSettle();
      expect(opened, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'local list and grid retain help and root drawer actions in the overflow menu',
    (tester) async {
      for (final appBar in [
        LocalGalleryListPage().buildAppBar,
        LocalGalleryGridPage().buildAppBar,
      ]) {
        var opened = 0;
        await mount(
          tester,
          NotificationListener<TapMenuButtonNotification>(
            onNotification: (_) {
              opened++;
              return true;
            },
            child: Builder(
              builder: (context) => Scaffold(appBar: appBar(context)),
            ),
          ),
          size: const Size(411, 800),
        );
        expect(find.byType(BackButton), findsNothing);
        final menu = find.byWidgetPredicate((w) => w is PopupMenuButton);
        await tester.tap(menu);
        await tester.pumpAndSettle();
        expect(find.text('localGalleryHelp'.tr), findsOneWidget);
        await tester.tap(find.text('navigationMenu'.tr));
        await tester.pumpAndSettle();
        expect(opened, 1);
        await tester.tap(menu);
        await tester.pumpAndSettle();
        await tester.tap(find.text('localGalleryHelp'.tr));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );

  testWidgets(
    'cloud views merge in-flight job refreshes and consume the newest event',
    (tester) async {
      for (final home in [
        const CloudGalleryPage(),
        const Scaffold(body: CloudTransferSheet()),
      ]) {
        final held = Completer<List<CloudSyncJob>>();
        fake.heldJobs = held;
        final before = fake.jobQueries;
        await mount(tester, home, settle: false);
        for (var event = 0; event < 30; event++) {
          fake.announceJobs();
        }
        await tester.pump();
        expect(fake.jobQueries - before, 1);
        fake.heldJobs = null;
        fake.jobs = const [
          CloudSyncJob('latest', 'content', 'Latest event', 'paused', 0, 1),
        ];
        if (home is CloudGalleryPage) {
          held.complete(const []);
        } else {
          held.completeError(const FormatException('first query failed'));
        }
        await tester.pumpAndSettle();
        expect(fake.jobQueries - before, 2);
        if (home is Scaffold) expect(find.text('Latest event'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );

  testWidgets('upload speed ticks refresh the task row without querying jobs', (
    tester,
  ) async {
    var elapsed = Duration.zero;
    final speed = UploadSpeed(elapsed: () => elapsed);
    fake.jobs = [
      CloudSyncJob(
        'upload',
        'content',
        'Uploading sample',
        'running',
        2,
        10,
        uploadSpeed: speed.listenable,
      ),
    ];
    await mount(tester, const Scaffold(body: CloudTransferSheet()));
    final queries = fake.jobQueries;
    final progress = speed.requestProgress();
    progress(2048, 4096);
    elapsed = const Duration(seconds: 1);
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('2 KB/s'), findsOneWidget);
    expect(fake.jobQueries, queries);
    elapsed = const Duration(seconds: 2);
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('0 B/s'), findsOneWidget);
    speed.dispose();
    await tester.pump();
    expect(find.textContaining('B/s'), findsNothing);
    expect(fake.jobQueries, queries);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('saving an unchanged metadata dialog publishes no snapshot', (
    tester,
  ) async {
    fake.entries = [metadataDialogFixture()];
    await mount(tester, const CloudGalleryPage());
    await openRevisionDialog(tester);
    await tester.tap(find.widgetWithText(TextButton, 'save'.tr));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(fake.revisionEdits, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'clearing an observed parent sends only its edges and keeps an in-flight remote title',
    (tester) async {
      fake.entries = [metadataDialogFixture()];
      await mount(tester, const CloudGalleryPage());
      await openRevisionDialog(tester);
      fake.serverTitle = 'A newer remote title';
      await tester.enterText(revisionFields().at(1), '');
      await tester.tap(find.widgetWithText(TextButton, 'save'.tr));
      await tester.pumpAndSettle();
      final edit = fake.revisionEdits.single;
      expect(edit.title, isNull);
      expect(fake.serverTitle, 'A newer remote title');
      expect(edit.tags, isNull);
      expect(edit.collections, isNull);
      expect(edit.added, isNull);
      expect(
        edit.removed!.map((edge) => (edge.fromGid, edge.toGid, edge.kind)),
        [(10, 3, 'source_parent'), (20, 3, 'source_parent')],
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'editing only the display title sends no lineage or retained user snapshots',
    (tester) async {
      fake.entries = [metadataDialogFixture()];
      await mount(tester, const CloudGalleryPage());
      await openRevisionDialog(tester);
      await tester.enterText(revisionFields().first, 'My display title');
      await tester.tap(find.widgetWithText(TextButton, 'save'.tr));
      await tester.pumpAndSettle();
      final edit = fake.revisionEdits.single;
      expect(edit.title, 'My display title');
      expect(edit.added, isNull);
      expect(edit.removed, isNull);
      expect(edit.tags, isNull);
      expect(edit.collections, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'compact transfer rows show direction and expose controls without a button row',
    (tester) async {
      fake.jobs = const [
        CloudSyncJob(
          'upload',
          'content',
          'Uploading gallery',
          'running',
          1,
          10,
        ),
        CloudSyncJob(
          'restore',
          'restore',
          'Restoring gallery',
          'paused',
          2,
          10,
        ),
      ];
      await mount(tester, const Scaffold(body: CloudTransferSheet()));
      expect(find.textContaining('cloudUpload'.tr), findsOneWidget);
      expect(find.textContaining('cloudRestore'.tr), findsOneWidget);
      expect(find.byTooltip('cloudPause'.tr), findsOneWidget);
      expect(find.byTooltip('cloudResume'.tr), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
      expect(
        tester.getSize(find.text('Uploading gallery')).height,
        lessThan(50),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'real public cover and missing cover fit two useful phone cards',
    (tester) async {
      fake.entries = [
        publicCloudFixture(55040),
        publicCloudFixture(55041, missingMetadata: true),
      ];
      fake.thumbnailFiles['public-55040'] = File(
        'test/fixtures/cloud_gallery/nursery_alice_cover.jpg',
      );
      await tester.runAsync(() => mount(tester, const CloudGalleryPage()));
      final image = tester.widget<Image>(find.byType(Image));
      await tester.runAsync(() async {
        final loaded = Completer<void>();
        final stream = image.image.resolve(ImageConfiguration.empty);
        late ImageStreamListener listener;
        listener = ImageStreamListener(
          (info, _) {
            expect(info.image.width, 600);
            expect(info.image.height, 759);
            stream.removeListener(listener);
            loaded.complete();
          },
          onError: (Object error, StackTrace? stack) =>
              loaded.completeError(error, stack),
        );
        stream.addListener(listener);
        await loaded.future;
      });
      await tester.pumpAndSettle();
      expect(image.fit, BoxFit.cover);
      expect(image.alignment, Alignment.topLeft);
      final body = find.byType(CloudGalleryCardBody).first;
      final coverSlot = find
          .descendant(
            of: body,
            matching: find.byWidgetPredicate(
              (w) =>
                  w is Positioned &&
                  w.left == 0 &&
                  w.top == 0 &&
                  w.bottom == 0 &&
                  w.width != null,
            ),
          )
          .first;
      final bodyBounds = tester.getRect(body);
      final coverBounds = tester.getRect(coverSlot);
      expect(coverBounds.width, closeTo(bodyBounds.width * 2 / 5, .01));
      expect(coverBounds.top, bodyBounds.top);
      expect(coverBounds.bottom, bodyBounds.bottom);
      expect(find.text('1P'), findsNWidgets(2));
      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
      expect(
        tester.getBottomRight(find.byKey(const ValueKey('public-55041'))).dy,
        lessThanOrEqualTo(800),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'failed upload belongs to its task, with explicit retry and permission details',
    (tester) async {
      fake.jobs = [
        const CloudSyncJob(
          'upload',
          'content',
          'A long gallery title with fifty five pages',
          'failed',
          1,
          55,
          error: WebDavFailure('authentication', statusCode: 403),
        ),
      ];
      await mount(tester, const CloudGalleryPage(), scale: 1.8);
      expect(find.text('还没有云端图库'), findsOneWidget);
      expect(find.textContaining('HTTP 403'), findsNothing);
      await tester.tap(find.textContaining('1').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('HTTP 403'), findsOneWidget);
      expect(find.byTooltip('cloudRetry'.tr), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsNothing);
      await tester.tap(find.byTooltip('cloudRetry'.tr));
      await tester.pumpAndSettle();
      expect(fake.retries, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'library retry renews a failed local query even without a catalog revision',
    (tester) async {
      fake.failQuery = true;
      await mount(tester, const CloudGalleryPage());
      expect(find.text('还没有云端图库'), findsNothing);
      final priorQueries = fake.queries;
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      expect(fake.queries, greaterThan(priorQueries));
      expect(find.text('还没有云端图库'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('pagination counts gallery families rather than version rows', (
    tester,
  ) async {
    final manifest = PortableManifest(
      gid: 1,
      representation: 'original',
      galleryUrl: 'https://e-hentai.org/g/1/token/',
      title: 'Public sample',
      tags: const [],
      pages: const [],
    );
    fake.entries = List.generate(
      41,
      (i) => CloudGalleryEntry(
        gid: i + 1,
        representation: 'original',
        title: 'Version $i',
        manifestId: '$i',
        manifest: manifest,
        equivalentManifestIds: ['$i'],
        localCopyId: null,
        localState: CloudLocalState.none,
      )..familyKey = 1,
    );
    await mount(tester, const CloudGalleryPage());
    expect(find.text('加载更多'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('folded version groups never start hidden thumbnail fetches', (
    tester,
  ) async {
    fake.entries = [cloudFixture(1), cloudFixture(2)..familyKey = 1];
    await mount(tester, const CloudGalleryPage());
    expect(fake.thumbnailRequests, ['manifest-1']);
    await tester.tap(find.byTooltip('2 ${'cloudVersions'.tr}'));
    await tester.pumpAndSettle();
    expect(fake.thumbnailRequests, ['manifest-1', 'manifest-2']);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'cloud card keeps all facts beside the cover and preserves raw tag information',
    (tester) async {
      fake.entries = [cloudFixture(1)];
      await mount(tester, const CloudGalleryPage());
      expect(find.byType(EHGalleryCardHeader), findsOneWidget);
      expect(find.text('Example uploader'), findsOneWidget);
      expect(find.text('Manga'), findsOneWidget);
      expect(find.byType(EHGalleryCardRating), findsOneWidget);
      expect(find.byType(EHGalleryCardTime), findsOneWidget);
      final cardMaterial = find
          .descendant(
            of: find.byKey(const ValueKey('manifest-1')),
            matching: find.byType(Material),
          )
          .first;
      expect(tester.widget<Material>(cardMaterial).elevation, 1);
      expect(find.text('Second device group'), findsOneWidget);
      expect(find.text('示例标签'), findsOneWidget);
      expect(find.byTooltip('artist:sample-tag'), findsOneWidget);
      final cardBounds = tester.getRect(
        find.byKey(const ValueKey('manifest-1')),
      );
      expect(cardBounds.left, 16);
      final contentLeft = cardBounds.left + cardBounds.width * 2 / 5;
      expect(
        tester.getTopLeft(find.text('Second device group')).dx,
        greaterThan(contentLeft),
      );
      expect(tester.getTopLeft(find.text('示例标签')).dx, greaterThan(contentLeft));
      expect(find.byTooltip('cloudActions'.tr), findsNothing);
      expect(find.text('cloudOpen'.tr), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());

      fake.entries = [cloudFixture(2, metadata: false)];
      await mount(tester, const CloudGalleryPage());
      expect(find.byType(EHGalleryCardRating), findsNothing);
      expect(find.text('Manga'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'three independent natural tag rows preserve source order and share horizontal scrolling',
    (tester) async {
      final base = cloudFixture(1);
      fake.entries = [
        CloudGalleryEntry(
          gid: base.gid,
          representation: base.representation,
          title: base.title,
          manifestId: base.manifestId,
          manifest: base.manifest,
          equivalentManifestIds: base.equivalentManifestIds,
          localCopyId: null,
          localState: base.localState,
          aggregatedTags: const [
            PortableTag('test', 'a'),
            PortableTag(
              'test',
              'a very long tag that must not stretch the other row',
            ),
            PortableTag('test', 'b'),
            PortableTag('test', 'c'),
            PortableTag('test', 'd'),
            PortableTag('test', 'e'),
          ],
        ),
      ];
      await mount(tester, const CloudGalleryPage());
      Finder chip(String text) =>
          find.ancestor(of: find.text(text), matching: find.byType(EHTag));
      final labels = [
        'a',
        'a very long tag that must not stretch the other row',
        'b',
        'c',
        'd',
        'e',
      ];
      final bounds = [for (final label in labels) tester.getRect(chip(label))];
      expect(bounds[0].top, lessThan(bounds[1].top));
      expect(bounds[1].top, lessThan(bounds[2].top));
      expect(bounds[0].left, bounds[1].left);
      expect(bounds[1].left, bounds[2].left);
      for (var i = 3; i < bounds.length; i++) {
        expect(bounds[i].top, bounds[2].top);
        expect(bounds[i].left - bounds[i - 1].right, closeTo(4, .01));
      }
      for (final tag in tester.widgetList<EHTag>(find.byType(EHTag))) {
        expect(tag.height, isNull);
      }
      await tester.drag(
        find.byKey(const PageStorageKey('cloud-tags:manifest-1')),
        const Offset(-80, 0),
      );
      await tester.pumpAndSettle();
      final firstShift = tester.getTopLeft(chip('a')).dx - bounds.first.left;
      final lastShift = tester.getTopLeft(chip('e')).dx - bounds.last.left;
      expect(firstShift, lessThan(0));
      expect(firstShift, closeTo(lastShift, .01));
      expect(fake.restores, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'short tags share one row and an oversized tag does not separate short neighbours',
    (tester) async {
      final base = cloudFixture(1);
      for (final scale in [1.0, 1.8]) {
        for (final labels in [
          ['a'],
          ['a', 'b'],
          ['a', 'b', 'c'],
          [
            'a very long tag that needs horizontal scrolling by itself',
            'b',
            'c',
          ],
        ]) {
          final entry = CloudGalleryEntry(
            gid: base.gid,
            representation: base.representation,
            title: base.title,
            manifestId: base.manifestId,
            manifest: base.manifest,
            equivalentManifestIds: base.equivalentManifestIds,
            localCopyId: null,
            localState: base.localState,
            aggregatedTags: [
              for (final label in labels) PortableTag('test', label),
            ],
          );
          await mount(
            tester,
            Scaffold(
              body: SizedBox(
                width: 379,
                child: CloudGalleryCardBody(
                  entry: entry,
                  cover: const ColoredBox(color: Colors.blue),
                  metadataLine: 'GID 1',
                  representationLabel: 'Original',
                ),
              ),
            ),
            scale: scale,
          );
          final bounds = [
            for (final label in labels)
              tester.getRect(
                find.ancestor(
                  of: find.text(label),
                  matching: find.byType(EHTag),
                ),
              ),
          ];
          if (labels.first == 'a') {
            expect(bounds.map((rect) => rect.top).toSet(), hasLength(1));
          } else {
            expect(bounds[0].top, lessThan(bounds[1].top));
            expect(bounds[1].top, bounds[2].top);
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        }
      }
    },
  );

  testWidgets(
    'tag rows change at their measured available width without constraining font scale',
    (tester) async {
      final base = cloudFixture(1, metadata: false);
      final entry = CloudGalleryEntry(
        gid: base.gid,
        representation: base.representation,
        title: base.title,
        manifestId: base.manifestId,
        manifest: base.manifest,
        equivalentManifestIds: base.equivalentManifestIds,
        localCopyId: null,
        localState: base.localState,
        aggregatedTags: const [
          PortableTag('test', 'a'),
          PortableTag('test', 'b'),
          PortableTag('test', 'c'),
        ],
      );
      for (final scale in [1.0, 1.8]) {
        Future<void> card(double width) => mount(
          tester,
          Scaffold(
            body: SizedBox(
              width: width,
              child: CloudGalleryCardBody(
                entry: entry,
                cover: const ColoredBox(color: Colors.blue),
                metadataLine: 'GID 1',
                representationLabel: 'Original',
              ),
            ),
          ),
          scale: scale,
        );
        await card(379);
        final tagWidth =
            tester
                .widgetList<EHTag>(find.byType(EHTag))
                .fold<double>(
                  0,
                  (sum, tag) => sum + tester.getSize(find.byWidget(tag)).width,
                ) +
            8;
        final boundary = (tagWidth + 16) / .6;
        await card(boundary + 1);
        expect(
          tester.getTopLeft(find.text('a')).dy,
          tester.getTopLeft(find.text('c')).dy,
        );
        await card(boundary - 1);
        expect(
          tester.getTopLeft(find.text('a')).dy,
          lessThan(tester.getTopLeft(find.text('c')).dy),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );

  testWidgets(
    'cached tag highlights retain source order within groups and survive translation',
    (tester) async {
      final base = cloudFixture(1);
      myTagsSetting.onlineTags[1] = (
        enable: true,
        tagSetBackGroundColor: Colors.yellow,
        tags: [
          WatchedTag(
            tagId: 1,
            tagData: TagData(namespace: 'artist', key: 'sample-tag'),
            watched: true,
            hidden: false,
            weight: 1,
          ),
          WatchedTag(
            tagId: 2,
            tagData: TagData(namespace: 'test', key: 'b'),
            watched: true,
            hidden: false,
            backgroundColor: Colors.black,
            weight: 1,
          ),
        ],
      );
      fake.entries = [
        CloudGalleryEntry(
          gid: base.gid,
          representation: base.representation,
          title: base.title,
          manifestId: base.manifestId,
          manifest: base.manifest,
          equivalentManifestIds: base.equivalentManifestIds,
          localCopyId: null,
          localState: base.localState,
          aggregatedTags: const [
            PortableTag('test', 'a'),
            PortableTag('artist', 'sample-tag'),
            PortableTag('test', 'b'),
            PortableTag('test', 'c'),
          ],
        ),
      ];
      await mount(tester, const CloudGalleryPage());
      final tags = tester.widgetList<EHTag>(find.byType(EHTag)).toList();
      expect(tags.map((tag) => tag.tag.tagData.key), [
        'sample-tag',
        'b',
        'a',
        'c',
      ]);
      expect(tags.first.tag.tagData.tagName, '示例标签');
      expect(tags.first.tag.backgroundColor, Colors.yellow);
      expect(tags.first.tag.color, const Color.fromRGBO(9, 9, 9, 1));
      expect(tags[1].tag.backgroundColor, Colors.black);
      expect(tags[1].tag.color, const Color(0xFFF1F1F1));
      expect(tags[2].tag.backgroundColor, isNull);
      expect(find.byTooltip('artist:sample-tag'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'natural tag height follows system text size while the existing default stays 24',
    (tester) async {
      for (final scale in [1.0, 1.8]) {
        await mount(
          tester,
          Scaffold(
            body: Column(
              children: [
                EHTag(
                  key: const ValueKey('default-tag'),
                  tag: GalleryTag(
                    tagData: TagData(namespace: 'test', key: 'default'),
                  ),
                ),
                EHTag(
                  key: const ValueKey('natural-tag'),
                  tag: GalleryTag(
                    tagData: TagData(namespace: 'test', key: 'natural'),
                  ),
                  height: null,
                ),
              ],
            ),
          ),
          scale: scale,
        );
        expect(
          tester.getSize(find.byKey(const ValueKey('default-tag'))).height,
          24,
        );
        final bounds = tester.getRect(
          find.byKey(const ValueKey('natural-tag')),
        );
        final label = tester.getRect(find.text('natural'));
        expect(bounds.contains(label.topLeft), isTrue);
        expect(bounds.contains(label.bottomRight), isTrue);
        if (scale == 1.8) expect(bounds.height, greaterThan(24));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );

  testWidgets(
    'collections wrap visibly below website facts while version actions stay independent',
    (tester) async {
      fake.entries = [cloudFixture(1), cloudFixture(2)..familyKey = 1];
      await mount(
        tester,
        const CloudGalleryPage(),
        size: const Size(320, 800),
        scale: 1.8,
      );
      final version = find.byTooltip('2 ${'cloudVersions'.tr}');
      final before = tester.getRect(version);
      final facts = find.byKey(const PageStorageKey('cloud-facts:manifest-1'));
      final category = find.text('Manga').first;
      final group = find.text('My group').first;
      expect(
        tester.getTopLeft(group).dy,
        greaterThan(tester.getBottomLeft(category).dy),
      );
      expect(tester.widget(facts), isA<Wrap>());
      final factBounds = tester.getRect(facts);
      for (final label in ['My group', 'Second device group']) {
        final bounds = tester.getRect(find.text(label).first);
        expect(bounds.left, greaterThanOrEqualTo(factBounds.left));
        expect(bounds.right, lessThanOrEqualTo(factBounds.right + .01));
      }
      expect(tester.getRect(version), before);
      expect(fake.restores, isEmpty);
      await tester.longPress(version);
      await tester.pumpAndSettle();
      expect(find.text('cloudEditCollections'.tr), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await tester.tap(version);
      await tester.pumpAndSettle();
      expect(find.text('Public sample 2'), findsOneWidget);
      expect(fake.restores, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'raw cloud tags remain visible when tag translation is unavailable',
    (tester) async {
      tagTranslationService = TagTranslationService();
      fake.entries = [cloudFixture(1)];
      fake.facets = const CloudGalleryFacets(
        categories: [],
        collections: [],
        tags: [PortableTag('artist', 'sample-tag')],
      );
      await mount(tester, const CloudGalleryPage());
      expect(find.text('sample-tag'), findsOneWidget);
      await tester.tap(find.byTooltip('筛选图库'));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(FilterChip, 'artist:sample-tag'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'keyword and category collection facets remain usable with keyboard and larger text',
    (tester) async {
      fake.entries = [cloudFixture(1)];
      fake.facets = const CloudGalleryFacets(
        categories: ['Manga'],
        collections: ['My group'],
        tags: [PortableTag('artist', 'sample-tag')],
      );
      await mount(tester, const CloudGalleryPage(), scale: 1.8, keyboard: 260);
      await tester.ensureVisible(find.text('Public sample 1'));
      await tester.pumpAndSettle();
      final tagLabel = find.text('示例标签');
      final displayChip = find.ancestor(
        of: tagLabel,
        matching: find.byType(EHTag),
      );
      final bounds = tester.getRect(displayChip);
      final labelBounds = tester.getRect(tagLabel);
      expect(bounds.contains(labelBounds.topLeft), isTrue);
      expect(bounds.contains(labelBounds.bottomRight), isTrue);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('cloudSearch'.tr));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Example uploader');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(fake.queriedSearch, 'Example uploader');
      await tester.tap(find.byTooltip('筛选图库'));
      await tester.pumpAndSettle();
      final groupChip = find.widgetWithText(FilterChip, 'My group');
      await tester.ensureVisible(groupChip);
      await tester.tap(groupChip);
      await tester.pumpAndSettle();
      expect(fake.queriedCollection, 'My group');
      final categoryChip = find.widgetWithText(FilterChip, 'Manga');
      await tester.ensureVisible(categoryChip);
      await tester.tap(categoryChip);
      await tester.pumpAndSettle();
      expect(fake.queriedCategory, 'Manga');
      final tagChip = find.widgetWithText(FilterChip, '艺术家:示例标签');
      await tester.ensureVisible(tagChip);
      await tester.tap(tagChip);
      await tester.pumpAndSettle();
      expect(fake.queriedTag?.name, 'sample-tag');
      await tester.tap(find.byTooltip('cloudClearFilters'.tr));
      await tester.pumpAndSettle();
      expect(fake.queriedCategory, isNull);
      expect(fake.queriedCollection, isNull);
      expect(fake.queriedTag, isNull);
      expect(fake.queriedSearch, '');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'single and multi-selection publish website metadata from cloud actions',
    (tester) async {
      fake.entries = [cloudFixture(1), cloudFixture(2)];
      await mount(
        tester,
        const CloudGalleryPage(),
        size: const Size(1200, 900),
      );
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('manifest-1'))).dy,
        tester.getTopLeft(find.byKey(const ValueKey('manifest-2'))).dy,
      );
      await tester.longPress(find.text('Public sample 1'));
      await tester.pumpAndSettle();
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.byType(Tab), findsNWidgets(4));
      await tester.tap(find.text('同步网站元数据'));
      await tester.pumpAndSettle();
      expect(fake.metadataRequests, ['manifest-1']);
      await tester.tap(find.byTooltip('cloudFilter'.tr));
      await tester.pumpAndSettle();
      await tester.tap(find.text('cloudSelect'.tr));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Public sample 1'));
      await tester.tap(find.text('Public sample 2'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('cloudSyncWebsiteMetadata'.tr));
      await tester.pumpAndSettle();
      expect(fake.metadataRequests, ['manifest-1', 'manifest-1', 'manifest-2']);
      expect(find.byType(Checkbox), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'long titles groups and many tags grow naturally at phone and large text widths',
    (tester) async {
      final base = cloudFixture(1);
      fake.entries = [
        CloudGalleryEntry(
          gid: base.gid,
          representation: base.representation,
          title: List.filled(20, '很长的标题 Long gallery title').join(' '),
          manifestId: base.manifestId,
          manifest: base.manifest,
          equivalentManifestIds: base.equivalentManifestIds,
          localCopyId: null,
          localState: base.localState,
          aggregatedCollections: ['a' * 120, '長い分組 📚 ' * 8],
          aggregatedTags: List.generate(
            60,
            (i) => PortableTag('artist', 'tag-$i' * 8),
          ),
        ),
      ];
      for (final scenario in [
        (const Size(360, 800), 1.0),
        (const Size(320, 800), 1.8),
      ]) {
        await mount(
          tester,
          const CloudGalleryPage(),
          size: scenario.$1,
          scale: scenario.$2,
        );
        expect(tester.takeException(), isNull);
        expect(
          tester.getSize(find.byKey(const ValueKey('manifest-1'))).width,
          scenario.$1.width - 32,
        );
        final title = tester.widget<Text>(find.text(fake.entries.single.title));
        expect(title.maxLines, 2);
        expect(find.byIcon(Icons.image_outlined), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );

  testWidgets(
    'group editing starts with aggregated heads, skips unchanged and publishes clear or added groups',
    (tester) async {
      final base = cloudFixture(1);
      fake.entries = [
        CloudGalleryEntry(
          gid: base.gid,
          representation: base.representation,
          title: base.title,
          manifestId: base.manifestId,
          manifest: base.manifest,
          equivalentManifestIds: base.equivalentManifestIds,
          localCopyId: null,
          localState: base.localState,
          aggregatedCollections: ['First head', 'Second head'],
        ),
      ];
      fake.facets = const CloudGalleryFacets(
        categories: [],
        collections: ['Other group'],
        tags: [],
      );
      await mount(tester, const CloudGalleryPage());
      Future<void> edit() async {
        await tester.longPress(find.text('Public sample 1'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('cloudEditCollections'.tr));
        await tester.pumpAndSettle();
      }

      await edit();
      final checks = tester.widgetList<CheckboxListTile>(
        find.byType(CheckboxListTile),
      );
      expect(checks.where((c) => c.value == true).length, 2);
      await tester.tap(find.widgetWithText(TextButton, 'save'.tr));
      await tester.pumpAndSettle();
      expect(fake.revisionEdits, isEmpty);
      await edit();
      await tester.tap(find.widgetWithText(TextButton, 'clear'.tr));
      await tester.tap(find.widgetWithText(TextButton, 'save'.tr));
      await tester.pumpAndSettle();
      expect(fake.revisionEdits.single.collections, isEmpty);
      await edit();
      await tester.enterText(find.byType(TextField), 'New group');
      await tester.tap(find.widgetWithText(TextButton, 'save'.tr));
      await tester.pumpAndSettle();
      expect(fake.revisionEdits.last.collections, [
        'First head',
        'Second head',
        'New group',
      ]);
      expect(fake.revisionEdits.last.title, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'row subregions open directly and right click and keyboard share the context menu',
    (tester) async {
      fake.entries = [cloudFixture(1)];
      await mount(tester, const CloudGalleryPage());
      await tester.tap(find.text('示例标签'));
      await tester.pumpAndSettle();
      expect(fake.restores, ['manifest-1']);
      expect(fake.queriedTag, isNull);
      await tester.ensureVisible(find.text('Second device group'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Second device group'));
      await tester.pumpAndSettle();
      expect(fake.restores.length, 2);
      await tester.longPress(find.text('示例标签'));
      await tester.pumpAndSettle();
      expect(find.text('cloudEditCollections'.tr), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      final mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await mouse.down(tester.getCenter(find.text('Public sample 1')));
      await mouse.up();
      await tester.pumpAndSettle();
      expect(find.text('cloudEditCollections'.tr), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      final ink = find
          .ancestor(
            of: find.text('Public sample 1'),
            matching: find.byType(InkWell),
          )
          .first;
      final inkContext = tester.element(
        find.descendant(of: ink, matching: find.byType(MouseRegion)).first,
      );
      Focus.of(inkContext).requestFocus();
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.f10);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
      expect(find.text('cloudEditCollections'.tr), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'restore and open keeps one pending user flow and releases it after failure',
    (tester) async {
      fake.entries = [cloudFixture(1), cloudFixture(2)];
      final restore = Completer<String>();
      fake.heldRestore = restore;
      await mount(tester, const CloudGalleryPage());
      await tester.tap(find.text('Public sample 1'));
      await tester.pump();
      expect(fake.restores, ['manifest-1']);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.text('Public sample 2'));
      await tester.pump();
      expect(fake.restores, ['manifest-1']);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      fake.heldRestore = null;
      restore.completeError(
        const FormatException('fixture restore unavailable'),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.tap(find.text('Public sample 2'));
      await tester.pumpAndSettle();
      expect(fake.restores, ['manifest-1', 'manifest-2']);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('search keeps all tabs visible and closing clears the query', (
    tester,
  ) async {
    fake.entries = [cloudFixture(1)];
    await mount(
      tester,
      const CloudGalleryPage(),
      size: const Size(320, 800),
      scale: 1.8,
    );
    expect(find.byType(TabBar), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.byTooltip('cloudSearch'.tr));
    await tester.pumpAndSettle();
    expect(find.byType(TabBar), findsOneWidget);
    expect(find.byType(Tab), findsNWidgets(4));
    await tester.enterText(find.byType(TextField), 'Query');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(fake.queriedSearch, 'Query');
    await tester.tap(find.byTooltip('close'.tr));
    await tester.pumpAndSettle();
    expect(fake.queriedSearch, '');
    expect(find.byType(TextField), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'queued uploads show a five second material notice and open the transfer panel',
    (tester) async {
      fake.jobs = const [
        CloudSyncJob('work-copy', 'content', 'Queued gallery', 'queued', 0, 3),
      ];
      await mount(
        tester,
        Scaffold(
          body: TextButton(
            onPressed: () => queueCloudUploads([
              () async => 'copy',
            ], cleanupAfterUpload: false),
            child: const Text('Queue upload'),
          ),
        ),
      );
      await tester.tap(find.text('Queue upload'));
      await tester.pumpAndSettle();
      expect(fake.uploadRequests, ['copy']);
      final notice = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(notice.duration, const Duration(seconds: 5));
      expect(notice.persist, isFalse);
      expect(
        find.text('cloudQueuedFeedback'.trParams({'count': '1'})),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(
        find.widgetWithText(SnackBarAction, 'cloudViewTransfers'.tr),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CloudTransferSheet), findsOneWidget);
      expect(find.text('Queued gallery'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'upload picker footer avoids system navigation padding with and without keyboard',
    (tester) async {
      for (final keyboard in [0.0, 260.0]) {
        await mount(
          tester,
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showCloudUploadPicker(context),
                child: const Text('Open picker'),
              ),
            ),
          ),
          scale: 1.8,
          keyboard: keyboard,
          bottomPadding: 48,
        );
        await tester.tap(find.text('Open picker'));
        await tester.pump();
        await tester.runAsync(() async {
          await db.customSelect('SELECT 1').get();
        });
        await tester.pumpAndSettle();
        final submit = find.widgetWithIcon(
          FilledButton,
          Icons.cloud_upload_outlined,
        );
        expect(
          tester.getBottomRight(submit).dy,
          lessThanOrEqualTo(800 - (keyboard > 0 ? keyboard : 48)),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );

  testWidgets(
    'transfer sheet bottom content excludes system navigation padding',
    (tester) async {
      fake.jobs = List.generate(
        8,
        (i) => CloudSyncJob('work-$i', 'content', 'Gallery $i', 'paused', 0, 1),
      );
      await mount(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showCloudTransfers(context),
              child: const Text('Open transfers'),
            ),
          ),
        ),
        bottomPadding: 48,
      );
      await tester.tap(find.text('Open transfers'));
      await tester.pumpAndSettle();
      final list = find.descendant(
        of: find.byType(CloudTransferSheet),
        matching: find.byType(ListView),
      );
      expect(tester.getBottomRight(list).dy, lessThanOrEqualTo(752));
      await tester.drag(list, const Offset(0, -1000));
      await tester.pumpAndSettle();
      final lastMenu = find.byTooltip('cloudActions'.tr).last;
      expect(tester.getBottomRight(lastMenu).dy, lessThanOrEqualTo(752));
      await tester.tap(lastMenu);
      await tester.pumpAndSettle();
      expect(find.text('cloudCancelUpload'.tr), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'upload picker selects completed copies and keeps actions visible with keyboard and larger text',
    (tester) async {
      await tester.runAsync(() async {
        for (var gid = 1; gid <= 3; gid++) {
          final id = await localContentService.ensureCopy(
            gid: gid,
            representation: 'original',
            rootPath: '/fixture/$gid',
            makeCurrent: false,
          );
          await localContentService.recordPage(
            copyId: id,
            ordinal: 0,
            relativePath: '001.webp',
            rawHash: List.filled(64, 'a').join(),
            rawLength: 1,
          );
          await db.customStatement(
            'UPDATE content_copy SET metadata_json=? WHERE copy_id=?',
            [
              jsonEncode({
                'title': 'Public gallery $gid',
                'expectedPages': gid == 2 ? 2 : 1,
              }),
              id,
            ],
          );
          if (gid == 3)
            await localContentService.repository.enqueuePageReplacement(
              copyId: id,
              ordinal: 0,
              oldPath: '/fixture/3/001.webp',
              newPath: '/fixture/3/001.webp',
              tempPath: '/fixture/3/temp',
              retainedPath: '/fixture/3/old',
            );
        }
      });
      await mount(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => showCloudUploadPicker(context),
                child: const Text('Open picker'),
              ),
            ),
          ),
        ),
        scale: 1.8,
        keyboard: 260,
      );
      await tester.tap(find.text('Open picker'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await db.customSelect('SELECT 1').get();
      });
      await tester.pumpAndSettle();
      expect(find.text('Public gallery 1'), findsOneWidget);
      expect(find.text('Public gallery 2'), findsNothing);
      expect(find.text('Public gallery 3'), findsNothing);
      await tester.ensureVisible(find.byType(CheckboxListTile).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CheckboxListTile).first);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CheckboxListTile>(find.byType(CheckboxListTile).first)
            .value,
        isTrue,
      );
      await tester.pumpAndSettle();
      final submit = find.widgetWithIcon(
        FilledButton,
        Icons.cloud_upload_outlined,
      );
      expect(tester.getBottomRight(submit).dy, lessThanOrEqualTo(540));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
