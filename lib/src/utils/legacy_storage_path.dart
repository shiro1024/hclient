import 'package:path/path.dart' as path;

/// Rebase paths from a copied Android backup onto this installation's storage.
/// Shared folders and paths outside the old app sandbox keep their locations.
String restoreLegacyAndroidStoragePath(String storedPath, String currentStorageRoot) {
  const legacyRoot = '/Android/data/top.jtmonster.jhentai/files';
  final normalized = path.posix.normalize(storedPath);
  final index = normalized.indexOf(legacyRoot);
  if (!normalized.startsWith('/') || index < 0) {
    return storedPath;
  }
  final suffix = normalized.substring(index + legacyRoot.length);
  if (suffix.isNotEmpty && !suffix.startsWith('/')) {
    return storedPath;
  }
  return path.posix.join(currentStorageRoot, suffix.isEmpty ? '' : suffix.substring(1));
}
