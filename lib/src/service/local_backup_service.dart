import 'dart:convert';

import 'package:drift/drift.dart';

import '../database/database.dart';
import '../enum/config_enum.dart';
import '../enum/config_type_enum.dart';
import '../model/config.dart';
import 'archive_download_service.dart';
import 'cloud_service.dart';

const localBackupService = LocalBackupService();

class LocalBackupSelection {
  final List<CloudConfigTypeEnum> dataTypes;
  final bool settings;
  final bool login;
  final bool archives;
  final bool groups;

  /// Null means all portable setting units, preserving existing callers.
  final Set<ConfigEnum>? settingUnits;
  final bool botCredential;
  final bool proxyCredential;

  const LocalBackupSelection({
    this.dataTypes = const [],
    this.settings = true,
    this.login = true,
    this.archives = true,
    this.groups = true,
    this.settingUnits,
    this.botCredential = false,
    this.proxyCredential = false,
  });

  bool get isEmpty =>
      dataTypes.isEmpty && !settings && !login && !groups && !archives;
}

class LocalBackupService {
  const LocalBackupService();

  // Only local file backups contain credentials. Cloud/shared configs keep their
  // original five data types and never include these sections.
  static const settingsKeys = {
    ConfigEnum.favoriteSetting,
    ConfigEnum.advancedSetting,
    ConfigEnum.downloadSetting,
    ConfigEnum.EHSetting,
    ConfigEnum.mouseSetting,
    ConfigEnum.networkSetting,
    ConfigEnum.performanceSetting,
    ConfigEnum.preferenceSetting,
    ConfigEnum.readSetting,
    ConfigEnum.securitySetting,
    ConfigEnum.siteSetting,
    ConfigEnum.styleSetting,
    ConfigEnum.archiveBotSetting,
    ConfigEnum.keyboardShortcutSetting,
    ConfigEnum.downloadSearchPageType,
    ConfigEnum.windowFullScreen,
    ConfigEnum.windowMaximize,
    ConfigEnum.windowWidth,
    ConfigEnum.windowHeight,
    ConfigEnum.leftColumnWidthRatio,
    ConfigEnum.frameRateMode,
    ConfigEnum.searchConfig,
    ConfigEnum.downloadPageBodyType,
    ConfigEnum.displayArchiveGroups,
    ConfigEnum.displayGalleryGroups,
    ConfigEnum.enableSearchHistoryTranslation,
    ConfigEnum.displayBlockingRulesGroup,
  };
  static const loginKeys = {ConfigEnum.userSetting, ConfigEnum.ehCookie};

  static const portableSettingsKeys = {
    ConfigEnum.favoriteSetting,
    ConfigEnum.advancedSetting,
    ConfigEnum.downloadSetting,
    ConfigEnum.EHSetting,
    ConfigEnum.mouseSetting,
    ConfigEnum.networkSetting,
    ConfigEnum.performanceSetting,
    ConfigEnum.preferenceSetting,
    ConfigEnum.readSetting,
    ConfigEnum.securitySetting,
    ConfigEnum.siteSetting,
    ConfigEnum.styleSetting,
    ConfigEnum.archiveBotSetting,
    ConfigEnum.keyboardShortcutSetting,
    ConfigEnum.downloadSearchPageType,
    ConfigEnum.frameRateMode,
    ConfigEnum.searchConfig,
    ConfigEnum.downloadPageBodyType,
    ConfigEnum.displayArchiveGroups,
    ConfigEnum.displayGalleryGroups,
    ConfigEnum.enableSearchHistoryTranslation,
    ConfigEnum.displayBlockingRulesGroup,
  };

  static const _localFields = <ConfigEnum, Set<String>>{
    ConfigEnum.downloadSetting: {
      'downloadPath',
      'singleImageSavePath',
      'extraGalleryScanPath',
    },
    ConfigEnum.securitySetting: {
      'encryptedPassword',
      'enablePasswordAuth',
      'enableBiometricAuth',
      'enableAuthOnResume',
    },
  };

  static const _credentialFields = <ConfigEnum, String>{
    ConfigEnum.archiveBotSetting: 'apiKey',
    ConfigEnum.networkSetting: 'proxyPassword',
  };

  Future<String> export(LocalBackupSelection selection) =>
      appDb.transaction(() async {
        final data = <CloudConfig>[];
        for (final type in selection.dataTypes) {
          final value = await cloudConfigService.getLocalConfig(type);
          if (value != null) data.add(value);
        }
        final selectedSettings = selection.settings
            ? (selection.settingUnits ?? portableSettingsKeys).intersection(
                portableSettingsKeys,
              )
            : <ConfigEnum>{};
        final selectedKeys = {
          ...selectedSettings.map((key) => key.key),
          if (selection.login) ...loginKeys.map((key) => key.key),
        };
        final configs = await (appDb.select(
          appDb.localConfig,
        )..where((row) => row.configKey.isIn(selectedKeys))).get();
        return jsonEncode({
          'format': 'hclient-local-backup',
          'version': 2,
          'units': {
            'settings': selectedSettings.map((key) => key.key).toList()..sort(),
            'login': selection.login,
            'dataTypes': selection.dataTypes.map((type) => type.code).toList(),
            'botCredential':
                selection.botCredential &&
                selectedSettings.contains(ConfigEnum.archiveBotSetting),
            'proxyCredential':
                selection.proxyCredential &&
                selectedSettings.contains(ConfigEnum.networkSetting),
            'groups': selection.groups,
          },
          'data': data.map((value) => value.toJson()).toList(),
          'settings': configs
              .where(
                (row) =>
                    selectedSettings.any((key) => key.key == row.configKey),
              )
              .map((row) => _portableRow(row, selection))
              .toList(),
          'login': configs
              .where((row) => loginKeys.any((key) => key.key == row.configKey))
              .map((row) => row.toJson())
              .toList(),
          if (selection.groups)
            'galleryGroups': (await appDb.select(appDb.galleryGroup).get())
                .map((row) => row.toJson())
                .toList(),
          if (selection.groups)
            'archiveGroups': (await appDb.select(appDb.archiveGroup).get())
                .map((row) => row.toJson())
                .toList(),
        });
      });

  Map<String, dynamic> _portableRow(
    LocalConfigData row,
    LocalBackupSelection selection,
  ) {
    final result = row.toJson();
    final key = ConfigEnum.from(row.configKey);
    result['value'] = _withoutRemovedReadSettings(key, row.value);
    if (_localFields.containsKey(key) || _credentialFields.containsKey(key)) {
      final value = Map<String, dynamic>.from(jsonDecode(row.value) as Map);
      for (final field in _localFields[key] ?? const <String>{}) {
        value.remove(field);
      }
      final credential = _credentialFields[key];
      if (credential != null &&
          !(key == ConfigEnum.archiveBotSetting
              ? selection.botCredential
              : selection.proxyCredential)) {
        value[credential] = null;
      }
      result['value'] = jsonEncode(value);
    }
    return result;
  }

  /// Additional local sections are loaded on the next launch. Restarting also
  /// recreates cookie managers, network clients and download services together.
  Future<({bool legacy, bool needsRestart})> import(
    String contents, {
    LocalBackupSelection? selection,
  }) async {
    final raw = jsonDecode(contents);
    if (raw is List) {
      final data = raw
          .map(
            (value) =>
                CloudConfig.fromJson(Map<String, dynamic>.from(value as Map)),
          )
          .where(
            (value) =>
                selection == null || selection.dataTypes.contains(value.type),
          )
          .toList();
      for (final config in data) {
        await cloudConfigService.importConfig(config);
      }
      return (legacy: true, needsRestart: false);
    }
    if (raw is! Map ||
        raw['format'] != 'hclient-local-backup' ||
        (raw['version'] != 1 && raw['version'] != 2)) {
      throw const FormatException('Unsupported local backup format');
    }
    if (raw['version'] == 2)
      return _importV2(Map<String, dynamic>.from(raw), selection: selection);
    List<Map<String, dynamic>> rows(String key) => (raw[key] as List? ?? [])
        .map((value) => Map<String, dynamic>.from(value as Map))
        .toList();
    final data = rows('data')
        .map(CloudConfig.fromJson)
        .where((v) => selection == null || selection.dataTypes.contains(v.type))
        .toList();
    List<LocalConfigData> configRows(String section, Set<ConfigEnum> allowed) {
      return rows(section).map((value) {
        final row = LocalConfigData.fromJson(value);
        if (!allowed.any((key) => key.key == row.configKey) ||
            (section == 'login' && row.subConfigKey.isNotEmpty)) {
          throw FormatException('Invalid $section config key');
        }
        if (row.configKey.endsWith('Setting')) {
          if (jsonDecode(row.value) is! Map)
            throw const FormatException('Invalid settings object');
        }
        if (row.configKey == ConfigEnum.ehCookie.key) {
          final cookies = jsonDecode(row.value);
          if (cookies is! List || cookies.any((value) => value is! String)) {
            throw const FormatException('Invalid cookie list');
          }
        }
        return row.copyWith(
          value: _withoutRemovedReadSettings(
            ConfigEnum.from(row.configKey),
            row.value,
          ),
        );
      }).toList();
    }

    final configs = [
      if (selection == null || selection.settings)
        ...configRows('settings', settingsKeys).where(
          (row) =>
              selection?.settingUnits == null ||
              selection!.settingUnits!.any((key) => key.key == row.configKey),
        ),
      if (selection == null || selection.login)
        ...configRows('login', loginKeys),
    ];
    final archives =
        (selection == null || selection.archives
                ? rows('archives')
                : <Map<String, dynamic>>[])
            .map(ArchiveDownloadedData.fromJson)
            .map((row) {
              ArchiveStatus.fromCode(row.archiveStatusCode);
              ArchiveParseSource.fromCode(row.parseSource);
              // An imported task must not automatically start spending quota or writing
              // files. Completed archives keep their status; active ones become paused.
              if (row.archiveStatusCode >= ArchiveStatus.unlocking.code &&
                  row.archiveStatusCode < ArchiveStatus.completed.code) {
                return row.copyWith(
                  archiveStatusCode: ArchiveStatus.paused.code,
                );
              }
              return row;
            })
            .toList();
    final groups =
        (selection == null || selection.groups
                ? rows('archiveGroups')
                : <Map<String, dynamic>>[])
            .map(ArchiveGroupData.fromJson)
            .toList();

    await appDb.transaction(() async {
      for (final row in configs) {
        await appDb.into(appDb.localConfig).insertOnConflictUpdate(row);
      }
      for (final group in groups) {
        await appDb
            .into(appDb.archiveGroup)
            .insert(group, mode: InsertMode.insertOrIgnore);
      }
      for (final archive in archives) {
        await appDb
            .into(appDb.archiveGroup)
            .insert(
              ArchiveGroupCompanion.insert(groupName: archive.groupName),
              mode: InsertMode.insertOrIgnore,
            );
        // Preserve an existing task and its current progress when re-importing.
        await appDb
            .into(appDb.archiveDownloaded)
            .insert(archive, mode: InsertMode.insertOrIgnore);
      }
      for (final config in data) {
        await cloudConfigService.importConfig(config);
      }
    });
    return (
      legacy: false,
      needsRestart:
          configs.isNotEmpty || archives.isNotEmpty || groups.isNotEmpty,
    );
  }

  LocalBackupSelection availableSelection(String contents) {
    final raw = jsonDecode(contents);
    if (raw is List) {
      return LocalBackupSelection(
        dataTypes: raw
            .map((v) => CloudConfigTypeEnum.fromCode((v as Map)['type'] as int))
            .toList(),
        settings: false,
        login: false,
        archives: false,
        groups: false,
        settingUnits: const {},
      );
    }
    if (raw is! Map || raw['format'] != 'hclient-local-backup')
      throw const FormatException('Unsupported local backup format');
    if (raw['version'] == 1) {
      final settings = (raw['settings'] as List? ?? []);
      return LocalBackupSelection(
        dataTypes: (raw['data'] as List? ?? [])
            .map((v) => CloudConfigTypeEnum.fromCode((v as Map)['type'] as int))
            .toList(),
        settings: settings.isNotEmpty,
        settingUnits: settings
            .map((v) => ConfigEnum.from((v as Map)['configKey'] as String))
            .toSet(),
        login: (raw['login'] as List? ?? []).isNotEmpty,
        archives: raw.containsKey('archives'),
        groups: raw.containsKey('archiveGroups'),
      );
    }
    if (raw['version'] != 2)
      throw const FormatException('Unsupported local backup format');
    final units = Map<String, dynamic>.from(raw['units'] as Map);
    final settingUnits = (units['settings'] as List)
        .map((v) => ConfigEnum.from(v as String))
        .toSet();
    return LocalBackupSelection(
      dataTypes: (units['dataTypes'] as List)
          .map((v) => CloudConfigTypeEnum.fromCode(v as int))
          .toList(),
      settings: settingUnits.isNotEmpty,
      settingUnits: settingUnits,
      login: units['login'] == true,
      archives: false,
      groups: units['groups'] == true,
      botCredential: units['botCredential'] == true,
      proxyCredential: units['proxyCredential'] == true,
    );
  }

  Future<({bool legacy, bool needsRestart})> _importV2(
    Map<String, dynamic> raw, {
    LocalBackupSelection? selection,
  }) async {
    if (raw.containsKey('archives')) {
      throw const FormatException('Archive tasks are not part of backup v2');
    }
    final available = availableSelection(jsonEncode(raw));
    final chosen = selection ?? available;
    final selectedSettings = chosen.settings
        ? (chosen.settingUnits ?? available.settingUnits ?? <ConfigEnum>{})
              .intersection(available.settingUnits ?? <ConfigEnum>{})
        : <ConfigEnum>{};
    List<Map<String, dynamic>> rows(String key) => (raw[key] as List? ?? [])
        .map((v) => Map<String, dynamic>.from(v as Map))
        .toList();
    final selectedDataTypes = chosen.dataTypes.toSet().intersection(
      available.dataTypes.toSet(),
    );
    final data = rows('data')
        .map(CloudConfig.fromJson)
        .where((v) => selectedDataTypes.contains(v.type))
        .toList();
    final includedSettings = <String, List<LocalConfigData>>{};
    for (final value in rows('settings')) {
      final row = LocalConfigData.fromJson(value);
      if (!portableSettingsKeys.any((key) => key.key == row.configKey) ||
          !available.settingUnits!.any((key) => key.key == row.configKey)) {
        throw const FormatException('Invalid settings unit');
      }
      final key = ConfigEnum.from(row.configKey);
      if (row.configKey.endsWith('Setting') && jsonDecode(row.value) is! Map)
        throw const FormatException('Invalid settings object');
      includedSettings.putIfAbsent(key.key, () => []).add(row);
    }
    final login = rows('login').map(LocalConfigData.fromJson).toList();
    final galleryGroups = available.groups && chosen.groups
        ? rows('galleryGroups').map(GalleryGroupData.fromJson).toList()
        : <GalleryGroupData>[];
    final archiveGroups = available.groups && chosen.groups
        ? rows('archiveGroups').map(ArchiveGroupData.fromJson).toList()
        : <ArchiveGroupData>[];
    for (final row in login) {
      if (!loginKeys.any((key) => key.key == row.configKey) ||
          row.subConfigKey.isNotEmpty ||
          !available.login) {
        throw const FormatException('Invalid login unit');
      }
      if (row.configKey == ConfigEnum.userSetting.key &&
          jsonDecode(row.value) is! Map)
        throw const FormatException('Invalid login settings');
      if (row.configKey == ConfigEnum.ehCookie.key) {
        final cookies = jsonDecode(row.value);
        if (cookies is! List || cookies.any((v) => v is! String))
          throw const FormatException('Invalid cookie list');
      }
    }

    await appDb.transaction(() async {
      for (final key in selectedSettings) {
        final previous = await (appDb.select(
          appDb.localConfig,
        )..where((r) => r.configKey.equals(key.key))).get();
        await (appDb.delete(
          appDb.localConfig,
        )..where((r) => r.configKey.equals(key.key))).go();
        for (final row
            in includedSettings[key.key] ?? const <LocalConfigData>[]) {
          final old = previous
              .where((v) => v.subConfigKey == row.subConfigKey)
              .firstOrNull;
          final value = _restorePortableValue(
            key,
            row.value,
            old?.value,
            chosen,
          );
          await appDb
              .into(appDb.localConfig)
              .insert(row.copyWith(value: value));
        }
        if ((includedSettings[key.key] ?? const <LocalConfigData>[]).isEmpty &&
            previous.isNotEmpty &&
            _localFields.containsKey(key)) {
          for (final row in previous) {
            final oldValue = Map<String, dynamic>.from(
              jsonDecode(row.value) as Map,
            );
            final localOnly = <String, dynamic>{};
            for (final field in _localFields[key]!) {
              if (oldValue.containsKey(field))
                localOnly[field] = oldValue[field];
            }
            if (key == ConfigEnum.securitySetting &&
                localOnly['enableAuthOnResume'] == true) {
              localOnly['enableBlur'] = true;
            }
            if (localOnly.isNotEmpty)
              await appDb
                  .into(appDb.localConfig)
                  .insert(row.copyWith(value: jsonEncode(localOnly)));
          }
        }
      }
      if (chosen.login && available.login) {
        await (appDb.delete(appDb.localConfig)
              ..where((r) => r.configKey.isIn(loginKeys.map((key) => key.key))))
            .go();
        for (final row in login) {
          await appDb.into(appDb.localConfig).insert(row);
        }
      }
      for (final group in galleryGroups) {
        await appDb.into(appDb.galleryGroup).insertOnConflictUpdate(group);
      }
      for (final group in archiveGroups) {
        await appDb.into(appDb.archiveGroup).insertOnConflictUpdate(group);
      }
      if (selectedSettings.contains(ConfigEnum.downloadSetting)) {
        final row =
            await (appDb.select(appDb.localConfig)..where(
                  (r) => r.configKey.equals(ConfigEnum.downloadSetting.key),
                ))
                .getSingleOrNull();
        if (row != null) {
          final map = Map<String, dynamic>.from(jsonDecode(row.value) as Map);
          await _ensureDefaultGroups(map);
        }
      }
      for (final config in data) {
        await cloudConfigService.importConfig(config);
      }
    });
    return (
      legacy: false,
      needsRestart:
          selectedSettings.isNotEmpty ||
          (chosen.login && available.login) ||
          galleryGroups.isNotEmpty ||
          archiveGroups.isNotEmpty,
    );
  }

  String _withoutRemovedReadSettings(ConfigEnum key, String contents) {
    if (key != ConfigEnum.readSetting) {
      return contents;
    }
    final value = Map<String, dynamic>.from(jsonDecode(contents) as Map);
    value.remove('useThirdPartyViewer');
    value.remove('thirdPartyViewerPath');
    return jsonEncode(value);
  }

  String _restorePortableValue(
    ConfigEnum key,
    String contents,
    String? current,
    LocalBackupSelection selection,
  ) {
    contents = _withoutRemovedReadSettings(key, contents);
    if (!_localFields.containsKey(key) && !_credentialFields.containsKey(key))
      return contents;
    final incoming = Map<String, dynamic>.from(jsonDecode(contents) as Map);
    final old = current == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(jsonDecode(current) as Map);
    for (final field in _localFields[key] ?? const <String>{}) {
      incoming.remove(field);
      if (old.containsKey(field)) incoming[field] = old[field];
    }
    if (key == ConfigEnum.securitySetting && old['enableAuthOnResume'] == true)
      incoming['enableBlur'] = true;
    final credential = _credentialFields[key];
    if (credential != null &&
        !(key == ConfigEnum.archiveBotSetting
            ? selection.botCredential
            : selection.proxyCredential)) {
      incoming[credential] = null;
    }
    return jsonEncode(incoming);
  }

  Future<void> _ensureDefaultGroups(
    Map<String, dynamic> downloadSettings,
  ) async {
    final gallery = downloadSettings['defaultGalleryGroup'] as String?;
    if (gallery != null && gallery.isNotEmpty) {
      final rows = await appDb.select(appDb.galleryGroup).get();
      if (!rows.any((row) => row.groupName == gallery)) {
        final max = rows.fold<int>(
          0,
          (value, row) => row.sortOrder > value ? row.sortOrder : value,
        );
        await appDb
            .into(appDb.galleryGroup)
            .insert(GalleryGroupData(groupName: gallery, sortOrder: max + 1));
      }
    }
    final archive = downloadSettings['defaultArchiveGroup'] as String?;
    if (archive != null && archive.isNotEmpty) {
      final rows = await appDb.select(appDb.archiveGroup).get();
      if (!rows.any((row) => row.groupName == archive)) {
        final max = rows.fold<int>(
          0,
          (value, row) => row.sortOrder > value ? row.sortOrder : value,
        );
        await appDb
            .into(appDb.archiveGroup)
            .insert(ArchiveGroupData(groupName: archive, sortOrder: max + 1));
      }
    }
  }
}
