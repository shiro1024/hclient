part of 'local_content_service.dart';

extension LocalContentRepresentation on LocalContentService {
  /// Upload encoders write beside their owner so installing an object is a move.
  Future<Directory> representationWorkDirectory(
    String copyId,
    String workId,
  ) async {
    final directory = Directory(
      path.join(await rootPath(copyId), '.content-work', workId),
    );
    await directory.create(recursive: true);
    return directory;
  }

  /// Transfers a completed artifact into the page journal. Work cleanup loses
  /// its registration in the same transaction that makes the journal resumable.
  Future<bool> installPageRepresentation({
    required String copyId,
    required int ordinal,
    required ContentCodecArtifact artifact,
    String? workItemId,
  }) async {
    final commitTimer = Stopwatch()..start();
    if (_retiring.contains(copyId) || isRelocating(copyId)) return false;
    final root = await rootPath(copyId);
    final current = await repository.getPage(copyId, ordinal);
    if (current.rawHash != artifact.rawHash ||
        current.rawLength != artifact.rawLength ||
        current.state != 'completed')
      return false;
    if ((await repository.listPageReplacements(copyId))
        .any((entry) => entry.ordinal == ordinal))
      return false;
    if (current.codecProfile != null) return !artifact.isTemporary;
    final id = const Uuid().v4();
    final isRaw = artifact.codecProfile == ContentCodec.rawProfile;
    final relative = isRaw
        ? current.relativePath
        : '${current.relativePath}.pcf';
    final destination = LocalContentService._pageFile(root, relative);
    // A raw fallback selects the current resident without rewriting its bytes.
    if (isRaw) {
      final selected = await repository.db.transaction(() async {
        if (_retiring.contains(copyId) ||
            isRelocating(copyId) ||
            (await repository.listPageReplacements(copyId))
                .any((entry) => entry.ordinal == ordinal))
          return false;
        final latest = await repository.getPage(copyId, ordinal);
        if (latest.rawHash != artifact.rawHash ||
            latest.rawLength != artifact.rawLength ||
            latest.codecProfile != null)
          return false;
        if (_retiring.contains(copyId) || isRelocating(copyId)) return false;
        await repository.db.customStatement(
          "UPDATE content_page SET codec_profile = 'raw' WHERE copy_id = ? AND ordinal = ? AND raw_hash = ? AND codec_profile IS NULL",
          [copyId, ordinal, artifact.rawHash],
        );
        await _forgetArtifact(workItemId, ordinal);
        return true;
      });
      if (!selected) return false;
      await rebuildProjection(copyId);
      log.info(
        'Selected local raw page: $copyId/$ordinal, bytes=${artifact.rawLength}, commitMs=${commitTimer.elapsedMilliseconds}',
      );
      return true;
    }
    if (!path.isWithin(root, path.absolute(artifact.path))) {
      throw StateError('Representation artifact must be inside its owner');
    }
    final accepted = await repository.db.transaction(() async {
      final latest = await repository.getPage(copyId, ordinal);
      if (await rootPath(copyId) != root) return false;
      if (_retiring.contains(copyId) ||
          isRelocating(copyId) ||
          latest.rawHash != artifact.rawHash ||
          latest.rawLength != artifact.rawLength ||
          latest.codecProfile != null ||
          (await repository.listPageReplacements(copyId))
              .any((entry) => entry.ordinal == ordinal))
        return false;
      if (_retiring.contains(copyId) || isRelocating(copyId)) return false;
      await repository.enqueuePageReplacement(
        replacementId: id,
        copyId: copyId,
        ordinal: ordinal,
        oldPath: LocalContentService._pageFile(root, current.relativePath).path,
        newPath: destination.path,
        tempPath: artifact.path,
        retainedPath: path.join(root, '.content-work', '$id.old'),
        representationOnly: true,
      );
      await repository.setPageReplacementReady(
        id,
        jsonEncode({
          'representationOnly': true,
          'rawHash': current.rawHash,
          'rawLength': current.rawLength,
          'mime':
              current.mime ?? LocalContentService._mime(current.relativePath),
          'width': current.width,
          'height': current.height,
          'codecProfile': artifact.codecProfile,
          'objectHash': artifact.objectHash,
          'storedLength': artifact.storedLength,
        }),
      );
      await _forgetArtifact(workItemId, ordinal);
      return true;
    });
    if (!accepted) return false;
    _replacementDone.putIfAbsent(id, Completer<void>.new);
    await commitPageReplacement(id);
    log.info(
      'Installed local representation: $copyId/$ordinal, rawBytes=${artifact.rawLength}, storedBytes=${artifact.storedLength}, savedBytes=${artifact.rawLength - artifact.storedLength}, adoptedBytes=${artifact.storedLength}, commitMs=${commitTimer.elapsedMilliseconds}',
    );
    return true;
  }

  Future<void> _forgetArtifact(String? workItemId, int ordinal) async {
    if (workItemId == null) return;
    final work = await repository.getWorkItem(workItemId);
    if (work == null) return;
    final artifacts = jsonDecode(work.artifactsJson) as Map<String, dynamic>;
    artifacts.remove('$ordinal');
    await repository.db.customStatement(
      'UPDATE content_work_item SET artifacts_json = ? WHERE work_item_id = ?',
      [jsonEncode(artifacts), workItemId],
    );
  }
}
