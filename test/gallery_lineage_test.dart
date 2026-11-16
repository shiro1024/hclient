import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/service/gallery_download/gallery_download_service.dart';

void main() {
  test('selected reuse base across a skipped gid is an upgrade edge', () {
    final edges = GalleryDownloadService.lineageForSelectedUpgradeBase(
      'https://e-hentai.org/g/100/0123456789/',
      305,
    );
    expect(edges, hasLength(1));
    expect(edges.single.fromGid, 100);
    expect(edges.single.toGid, 305);
    expect(edges.single.kind, 'upgrade');
  });
}
