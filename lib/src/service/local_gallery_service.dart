import 'dart:async';
import 'dart:io';

import 'package:get/get.dart';
import 'package:jhentai/src/extension/list_extension.dart';
import 'package:jhentai/src/utils/file_util.dart';
import 'package:path/path.dart';

import '../model/gallery_image.dart';
import '../pages/download/grid/mixin/grid_download_page_service_mixin.dart';
import '../setting/download_setting.dart';
import 'jh_service.dart';
import 'path_service.dart';
import 'log.dart';
import '../widget/loading_state_indicator.dart';
import 'local_content_service.dart';
import 'archive_download_service.dart';
import 'gallery_download/gallery_download_service.dart';

/// Load galleries in download directory but is not downloaded by JHenTai
LocalGalleryService localGalleryService = LocalGalleryService();

class LocalGalleryService extends GetxController
    with GridBasePageServiceMixin, JHLifeCircleBeanErrorCatch
    implements JHLifeCircleBean {
  @override
  List<JHLifeCircleBean> get initDependencies => [
    ...super.initDependencies,
    localContentService,
    galleryDownloadService,
    archiveDownloadService,
  ];

  static const String rootPath = '';

  LoadingState loadingState = LoadingState.idle;
  Future<void> _refreshTail = Future<void>.value();
  Future<void>? _diskRefresh;

  Future<void> _enqueueRefresh(Future<void> Function() refresh) {
    final next = _refreshTail.then((_) => refresh());
    _refreshTail = next.catchError((Object error, StackTrace stack) {
      log.error('Local library projection failed', error, stack);
    });
    return next;
  }

  Future<void> refreshManagedCopies() => _enqueueRefresh(() async {
    final parents = allGalleries
        .where((g) => g.copyId != null)
        .map((g) => dirname(g.path))
        .toSet();
    allGalleries.removeWhere((g) => g.copyId != null);
    for (final galleries in path2GalleryDir.values) {
      galleries.removeWhere((g) => g.copyId != null);
    }
    for (final parent in parents) {
      if ((path2GalleryDir[parent]?.isEmpty ?? true) &&
          (path2SubDir[parent]?.isEmpty ?? true)) {
        path2SubDir[rootPath]?.remove(parent);
      }
    }
    await _loadStandaloneCopies();
    _sortGalleries();
    update([galleryCountChangedId]);
  });

  List<LocalGallery> allGalleries = [];
  Map<String, List<LocalGallery>> path2GalleryDir = {};
  Map<String, List<String>> path2SubDir = {};

  Map<int, LocalGallery> gid2EHViewerGallery = {};

  List<String> get rootDirectories => path2SubDir[rootPath] ?? [];

  @override
  Future<void> doInitBean() async {
    Get.put(this, permanent: true);
    localContentService.onRetired = _removeRetiredCopy;
    localContentService.onLibraryChanged = refreshManagedCopies;

    await refreshLocalGalleries();
  }

  @override
  Future<void> doAfterBeanReady() async {}

  Future<void> refreshLocalGalleries() {
    return _diskRefresh ??= _enqueueRefresh(_refreshFromDisk).whenComplete(() {
      _diskRefresh = null;
    });
  }

  Future<void> _refreshFromDisk() {
    loadingState = LoadingState.loading;

    int preCount = allGalleries.length;

    allGalleries.clear();
    path2GalleryDir.clear();
    path2SubDir.clear();
    update([galleryCountChangedId]);

    DateTime start = DateTime.now();
    return _loadGalleriesFromDisk().whenComplete(() {
      log.info(
        'Refresh local galleries, preCount:$preCount, newCount: ${allGalleries.length}, timeCost: ${DateTime.now().difference(start).inMilliseconds}ms',
      );
      loadingState = LoadingState.success;
      update([galleryCountChangedId]);
    });
  }

  List<GalleryImage> getGalleryImages(LocalGallery gallery) {
    List<File> imageFiles =
        Directory(gallery.path)
            .listSync()
            .whereType<File>()
            .where((image) => FileUtil.isImageExtension(image.path))
            .toList()
          ..sort(FileUtil.naturalCompareFile);

    return imageFiles
        .map(
          (file) => GalleryImage(
            url: '',
            path: relative(file.path, from: pathService.getVisibleDir().path),
            downloadStatus: DownloadStatus.downloaded,
          ),
        )
        .toList();
  }

  Future<void> deleteGallery(LocalGallery gallery, String parentPath) async {
    if (gallery.copyId case final copyId?) {
      await localContentService.retireCopy(copyId);
      return;
    }
    log.info('Delete local gallery: ${gallery.title}');

    Directory dir = Directory(gallery.path);

    List<File> allFiles = dir.listSync().whereType<File>().toList();
    List<File> imageFiles = dir
        .listSync()
        .whereType<File>()
        .where((image) => FileUtil.isImageExtension(image.path))
        .toList();
    if (allFiles.length == imageFiles.length) {
      dir.delete(recursive: true).catchError((e) {
        log.error('Delete local gallery error!', e);
        log.uploadError(e);
      });
    } else {
      for (File file in imageFiles) {
        file.delete().catchError((e) {
          log.error('Delete local gallery error!', e);
          log.uploadError(e);
        });
      }
    }

    allGalleries.removeWhere((g) => g.path == gallery.path);
    path2GalleryDir[parentPath]?.removeWhere((g) => g.path == gallery.path);

    update([galleryCountChangedId]);
  }

  void _removeRetiredCopy(String copyId) {
    allGalleries.removeWhere((gallery) => gallery.copyId == copyId);
    for (final galleries in path2GalleryDir.values) {
      galleries.removeWhere((gallery) => gallery.copyId == copyId);
    }
    update([galleryCountChangedId]);
  }

  Future<void> _loadStandaloneCopies() async {
    for (final copy in await localContentService.standaloneCopies()) {
      final parent = dirname(copy.rootPath);
      final gallery = LocalGallery(
        title: copy.title,
        path: copy.rootPath,
        copyId: copy.copyId,
        gid: copy.gid,
        cover: GalleryImage(
          url: '',
          managedPage: localContentService.managedPageForPathSync(
            join(copy.rootPath, copy.cover),
          ),
          path: relative(
            join(copy.rootPath, copy.cover),
            from: pathService.getVisibleDir().path,
          ),
          downloadStatus: DownloadStatus.downloaded,
        ),
      );
      allGalleries.add(gallery);
      (path2GalleryDir[parent] ??= []).add(gallery);
      (path2SubDir[rootPath] ??= []).addIfNotExists(parent);
    }
  }

  Future<void> _loadGalleriesFromDisk() {
    List<Future> futures = downloadSetting.extraGalleryScanPath
        .map((path) => _parseDirectory(Directory(path), true))
        .toList();

    return Future.wait(futures)
        .onError((error, stackTrace) {
          log.error(
            '_loadGalleriesFromDisk failed, path: ${downloadSetting.extraGalleryScanPath}',
            error,
            stackTrace,
          );
          return [];
        })
        .then((_) => _loadStandaloneCopies())
        .whenComplete(() {
          _sortGalleries();
        });
  }

  void _sortGalleries() {
    allGalleries.sort((a, b) => FileUtil.naturalCompare(a.title, b.title));
    for (final galleries in path2GalleryDir.values) {
      galleries.sort((a, b) => FileUtil.naturalCompare(a.title, b.title));
    }
  }

  Future<LocalGalleryParseResult> _parseDirectory(
    Directory directory,
    bool isRootDir,
  ) {
    Completer<LocalGalleryParseResult> completer = Completer();
    LocalGalleryParseResult result = LocalGalleryParseResult();

    if (localContentService.isManagedDirectory(directory.path)) {
      return Future.value(result);
    }
    Future<bool> future = directory.exists();

    /// Managed content is listed by the download and cloud pages.
    future = future
        .then<bool>((success) {
          if (success) {
            return File(join(directory.path, ".content.sqlite"))
                .exists()
                .then((value) => !value);
          } else {
            completer.isCompleted ? null : completer.complete(result);
            return false;
          }
        })
        .catchError((e, stack) {
          completer.isCompleted ? null : completer.completeError(e, stack);
          return false;
        });

    /// recursively list all files in directory
    future = future
        .then<bool>((success) {
          if (success) {
            List<Future> subFutures = [];
            List<File> images = [];
            String parentPath = isRootDir ? rootPath : directory.parent.path;

            directory.list().listen(
              (entity) {
                if (entity is File &&
                    FileUtil.isImageExtension(entity.path) &&
                    result.isLegalGalleryDir == false) {
                  result.isLegalGalleryDir = true;
                  images.add(entity);
                } else if (entity is Directory) {
                  subFutures.add(
                    _parseDirectory(entity, false).then((subResult) {
                      if (subResult.isLegalGalleryDir ||
                          subResult.isLegalNestedGalleryDir) {
                        result.isLegalNestedGalleryDir = true;
                        (path2SubDir[parentPath] ??= []).addIfNotExists(
                          directory.path,
                        );
                        path2SubDir[parentPath]!.sort(
                          (a, b) => FileUtil.naturalCompare(
                            basenameWithoutExtension(a),
                            basenameWithoutExtension(b),
                          ),
                        );
                      }
                    }),
                  );
                }
              },
              onDone: () {
                if (result.isLegalGalleryDir) {
                  images.sort(FileUtil.naturalCompareFile);
                  _initGalleryInfoInMemory(directory, images[0], parentPath);
                }

                Future.wait(subFutures).then((_) {
                  completer.isCompleted ? null : completer.complete(result);
                });
              },
              onError: completer.completeError,
            );
          } else {
            completer.isCompleted ? null : completer.complete(result);
          }
          return success;
        })
        .catchError((e, stack) {
          completer.isCompleted ? null : completer.completeError(e, stack);
          return false;
        });

    return completer.future;
  }

  void _initGalleryInfoInMemory(
    Directory galleryDir,
    File coverImage,
    String parentPath,
  ) {
    LocalGallery gallery = LocalGallery(
      title: basename(galleryDir.path),
      path: galleryDir.path,
      cover: GalleryImage(
        url: '',
        path: relative(coverImage.path, from: pathService.getVisibleDir().path),
        downloadStatus: DownloadStatus.downloaded,
      ),
    );

    allGalleries.add(gallery);
    (path2GalleryDir[parentPath] ??= []).add(gallery);
  }
}

class LocalGallery {
  String title;
  String path;
  GalleryImage cover;
  final String? copyId;
  final int? gid;

  LocalGallery({
    required this.title,
    required this.path,
    required this.cover,
    this.copyId,
    this.gid,
  });
}

class LocalGalleryParseResult {
  /// has images
  bool isLegalGalleryDir = false;

  /// has subDirectory that has images
  bool isLegalNestedGalleryDir = false;
}
