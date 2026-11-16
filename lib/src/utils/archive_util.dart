import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

import 'dart:io';

/// SHA-256 is taken from the decompressed bytes while writing each output.
/// A null result means the archive was not fully unpacked.
Future<Map<String, String>?> extractZipArchiveWithHashes(
  String archivePath,
  String extractPath,
) {
  return compute(_extractZipArchiveWithHashes, [archivePath, extractPath]);
}

Future<Map<String, String>?> _extractZipArchiveWithHashes(
  List<String> arguments,
) async {
  InputFileStream? input;
  try {
    input = InputFileStream(arguments[0]);
    final root = arguments[1];
    final hashes = <String, String>{};
    await Directory(root).create(recursive: true);
    final archive = ZipDecoder().decodeBuffer(input);
    for (final entry in archive.files) {
      if (!entry.isFile || entry.isSymbolicLink) continue;
      final relativePath = path.normalize(entry.name);
      final absolute = path.join(root, relativePath);
      if (path.isAbsolute(relativePath) ||
          !path.isWithin(
            path.canonicalize(root),
            path.canonicalize(absolute),
          )) {
        throw const FormatException('Archive output path escapes root');
      }
      final bytes = entry.content as List<int>;
      final output = File(absolute);
      await output.parent.create(recursive: true);
      final sink = await output.open(mode: FileMode.write);
      try {
        Stream<List<int>> writeChunks() async* {
          const chunkSize = 64 * 1024;
          for (var start = 0; start < bytes.length; start += chunkSize) {
            final end = (start + chunkSize).clamp(0, bytes.length);
            await sink.writeFrom(bytes, start, end);
            yield bytes.sublist(start, end);
          }
        }

        hashes[relativePath] = (await sha256.bind(writeChunks()).first)
            .toString();
      } finally {
        await sink.close();
      }
      entry.clear();
    }
    return hashes;
  } on Exception {
    return null;
  } finally {
    input?.close();
  }
}

Future<bool> extractZipArchive(String archivePath, String extractPath) {
  return compute((List<String> path) async {
    InputFileStream? inputStream;
    try {
      inputStream = InputFileStream(path[0]);
      await extractArchiveToDisk(
        ZipDecoder().decodeBuffer(inputStream),
        path[1],
      );
    } on Exception catch (_) {
      return false;
    } finally {
      inputStream?.close();
    }
    return true;
  }, [archivePath, extractPath]);
}

Future<List<int>> extractGZipArchive(String archivePath) {
  return compute((String path) async {
    InputFileStream inputStream = InputFileStream(path);
    try {
      return GZipDecoder().decodeBuffer(inputStream);
    } on Exception catch (_) {
      return [];
    } finally {
      inputStream.close();
    }
  }, archivePath);
}
