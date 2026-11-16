import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/utils/legacy_storage_path.dart';

void main() {
  const currentRoot = '/storage/emulated/0/Android/data/shiro.hclient/files';

  test('old private download and scan paths follow the restored installation', () {
    for (final prefix in ['/storage/emulated/0', '/storage/emulated/10', '/sdcard']) {
      expect(
        restoreLegacyAndroidStoragePath('$prefix/Android/data/top.jtmonster.jhentai/files/download', currentRoot),
        '$currentRoot/download',
      );
    }
    expect(restoreLegacyAndroidStoragePath('/sdcard/Android/data/top.jtmonster.jhentai/files', currentRoot), currentRoot);
  });

  test('shared folders and other package paths remain usable', () {
    for (final value in [
      '/storage/emulated/0/Download/JHenTai',
      '/storage/emulated/0/Android/data/shiro.hclient/files/download',
      '/sdcard/Android/data/top.jtmonster.jhentai.other/files/download',
      '/sdcard/Android/data/top.jtmonster.jhentai/files-other/download',
      'download/relative-path',
    ]) {
      expect(restoreLegacyAndroidStoragePath(value, currentRoot), value);
    }
  });
}
