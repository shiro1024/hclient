part of 'local_content_service.dart';

extension LocalContentRelocation on LocalContentService {
  Future<void> _copyRelocationDirectory(
    String source,
    String destination,
  ) async {
    await Directory(destination).create(recursive: true);
    await for (final entity in Directory(source).list(followLinks: false)) {
      final target = path.join(destination, path.basename(entity.path));
      if (entity is Directory) {
        await _copyRelocationDirectory(entity.path, target);
      } else if (entity is Link) {
        await Link(target).create(await entity.target());
      } else if (entity is File) {
        await entity.copy(target);
      }
    }
  }

  Future<void> _deleteRelocationDirectory(String directory) async {
    if (await Directory(directory).exists()) {
      await Directory(directory).delete(recursive: true);
    }
  }

  bool isRelocating(String copyId) => _relocating.contains(copyId);

  /// Moves one owned root without changing content identity or upload intent.
  Future<void> relocateCopy(String copyId, String targetParent) {
    final operation = _relocationTail.then((_) async {
      if (_retiring.contains(copyId)) {
        throw StateError('Copy is retiring');
      }
      final parent = path.normalize(path.absolute(targetParent));
      if (isManagedDirectory(parent)) {
        throw ArgumentError.value(targetParent, 'targetParent');
      }
      _relocating.add(copyId);
      var journaled = false;
      try {
        final pending = await repository.listWorkItems(
          kind: 'local_relocation',
        );
        for (final work in pending) {
          if (work.copyId == copyId) {
            journaled = true;
            await _runRelocation(work);
            journaled = false;
            _relocating.add(copyId);
            break;
          }
        }
        if (_retiring.contains(copyId)) {
          throw StateError('Copy is retiring');
        }
        final source = path.normalize(path.absolute(await rootPath(copyId)));
        if (path.dirname(source) == parent) {
          return;
        }
        if (parent == source || path.isWithin(source, parent)) {
          throw ArgumentError('Destination is inside the source directory');
        }
        await Directory(parent).create(recursive: true);
        var target = path.join(parent, path.basename(source));
        var suffix = 1;
        while (await FileSystemEntity.type(target) !=
                FileSystemEntityType.notFound ||
            await isRootReserved(target) ||
            pending.any(
              (work) =>
                  (jsonDecode(work.inputJson) as Map)['targetRoot'] == target,
            )) {
          target = path.join(parent, '${path.basename(source)}-${suffix++}');
        }
        final work = await repository.createWorkItem(
          kind: 'local_relocation',
          targetNamespace: 'local',
          copyId: copyId,
          inputJson: jsonEncode({'sourceRoot': source, 'targetRoot': target}),
        );
        journaled = true;
        await _runRelocation(work);
      } finally {
        if (!journaled) {
          _relocating.remove(copyId);
        }
      }
    });
    _relocationTail = operation.catchError((Object _) {});
    return operation;
  }

  /// Runs before consumers are initialized, using the persisted source/target
  /// and actual directory locations to finish an interrupted move.
  Future<void> recoverRelocations() async {
    for (final work in await repository.listWorkItems(
      kind: 'local_relocation',
    )) {
      try {
        await _runRelocation(work);
      } catch (error, stack) {
        log.error(
          'Resume local relocation failed: ${work.copyId}',
          error,
          stack,
        );
      }
    }
  }

  /// Retirement owns the current root; discard only the extra directories
  /// left by its unfinished move before allowing retirement to complete.
  Future<void> _cancelRetiredRelocations(String copyId, String root) async {
    _retiring.add(copyId);
    _retiringRoots.add(path.normalize(root));
    for (final work in await repository.listWorkItems(
      kind: 'local_relocation',
      copyId: copyId,
    )) {
      final input = jsonDecode(work.inputJson) as Map<String, dynamic>;
      final source = input['sourceRoot'] as String;
      final target = input['targetRoot'] as String;
      final staging = path.join(
        path.dirname(target),
        '.content-relocation-${work.workItemId}',
      );
      final roots = {source, target, staging};
      _relocationRoots.addAll(roots);
      for (final extra in roots) {
        if (extra != root) {
          await _deleteRelocationDirectory(extra);
        }
      }
      await repository.updateWorkItemState(work.workItemId, 'cancelled');
      _relocationRoots.removeAll(roots);
    }
    _copiesByRoot.removeWhere((_, owner) => owner == copyId);
    _relocating.remove(copyId);
    _relocationGates.remove(copyId)?.complete();
  }

  Future<void> _runRelocation(ContentWorkRecord work) async {
    final copyId = work.copyId!;
    final owner = await repository.db
        .customSelect(
          'SELECT lifecycle, root_path FROM content_copy WHERE copy_id = ?',
          variables: [Variable.withString(copyId)],
        )
        .getSingle();
    if (owner.read<String>('lifecycle') != 'active') {
      await _cancelRetiredRelocations(copyId, owner.read<String>('root_path'));
      return;
    }
    final input = jsonDecode(work.inputJson) as Map<String, dynamic>;
    final source = input['sourceRoot'] as String;
    final target = input['targetRoot'] as String;
    final staging = path.join(
      path.dirname(target),
      '.content-relocation-${work.workItemId}',
    );
    _relocating.add(copyId);
    _relocationRoots.addAll([source, target, staging]);
    var usable = false;
    try {
      // Producers may still require page inputs to settle their current work.
      await onBeforeRelocation?.call(copyId);
      final replacements = await repository.listPageReplacements(copyId);
      for (final replacement in replacements) {
        if (replacement.state == 'committing' ||
            replacement.state == 'committed') {
          if (replacements.any(
            (earlier) =>
                earlier.ordinal == replacement.ordinal &&
                earlier.queueOrder < replacement.queueOrder &&
                earlier.state == 'downloading',
          )) {
            throw StateError(
              'An earlier page replacement must finish downloading before relocation',
            );
          }
          await commitPageReplacement(replacement.replacementId);
        }
      }
      _relocationGates.putIfAbsent(copyId, Completer<void>.new);
      final gates = _pageGates.entries
          .where((entry) => entry.key.startsWith('$copyId:'))
          .map((entry) => entry.value)
          .toList();
      for (final gate in gates) {
        while (gate.readers > 0) {
          await gate.wait();
        }
      }
      await flushProjection(source);
      final currentRoot = await rootPath(copyId);
      if (currentRoot != source && currentRoot != target) {
        throw StateError(
          'Relocation owner no longer matches the recorded roots',
        );
      }
      if (currentRoot == source) {
        if (await Directory(source).exists()) {
          // Until the owner transaction commits, source remains authoritative
          // and may have resumed writes after an earlier failed attempt.
          // An installed but uncommitted target is therefore only a snapshot.
          await _deleteRelocationDirectory(target);
          try {
            await Directory(source).rename(target);
          } on FileSystemException catch (error) {
            // EXDEV on POSIX, ERROR_NOT_SAME_DEVICE on Windows.
            if (error.osError?.errorCode != (Platform.isWindows ? 17 : 18)) {
              rethrow;
            }
            await _deleteRelocationDirectory(staging);
            await _copyRelocationDirectory(source, staging);
            await Directory(staging).rename(target);
          }
        } else if (!await Directory(target).exists()) {
          throw StateError('Relocation source and target are missing: $source');
        }
        await repository.relocateCopyRoot(
          copyId,
          source,
          target,
          visibleRoot: pathService.getVisibleDir().path,
        );
      }
      _copiesByRoot.remove(source);
      _copiesByRoot[target] = copyId;
      final movedPages = _managedPages.entries
          .where(
            (entry) =>
                entry.value.copyId == copyId &&
                path.isWithin(source, entry.key),
          )
          .toList();
      for (final entry in movedPages) {
        _managedPages.remove(entry.key);
        _managedPages[path.join(
              target,
              path.relative(entry.key, from: source),
            )] =
            entry.value;
      }
      await _deleteRelocationDirectory(source);
      await _deleteRelocationDirectory(staging);
      await repository.updateWorkItemState(work.workItemId, 'completed');
      _relocationRoots.removeAll([source, target, staging]);
      _relocating.remove(copyId);
      _relocationGates.remove(copyId)?.complete();
      usable = true;
    } finally {
      if (!usable) {
        // Failed copying leaves the source usable; failed old-root cleanup
        // leaves the committed destination usable. Neither blocks reading.
        usable = await Directory(await rootPath(copyId)).exists();
        if (!usable) {
          _relocationGates.putIfAbsent(copyId, Completer<void>.new);
        }
        if (usable) {
          _relocating.remove(copyId);
          _relocationGates.remove(copyId)?.complete();
        }
      }
      await onAfterRelocation?.call(copyId, usable);
    }
  }
}
