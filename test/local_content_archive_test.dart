import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/utils/archive_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ZIP extraction reports hashes of decompressed page bytes', () async {
    final root = await Directory.systemTemp.createTemp('hclient-archive-hash-');
    try {
      final archive = Archive()
        ..addFile(ArchiveFile('002.png', 3, [4, 5, 6]))
        ..addFile(ArchiveFile('001.jpg', 3, [1, 2, 3]));
      final zip = File('${root.path}/pages.zip');
      await zip.writeAsBytes(ZipEncoder().encode(archive)!);
      final output = '${root.path}/unpacked';
      final hashes = await extractZipArchiveWithHashes(zip.path, output);
      expect(hashes?['001.jpg'], sha256.convert([1, 2, 3]).toString());
      expect(hashes?['002.png'], sha256.convert([4, 5, 6]).toString());
      expect(await File('$output/001.jpg').readAsBytes(), [1, 2, 3]);
      expect(await File('$output/002.png').readAsBytes(), [4, 5, 6]);
    } finally {
      await root.delete(recursive: true);
    }
  });
}
