import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/enum/config_enum.dart';
import 'package:jhentai/src/network/eh_cookie_manager.dart';
import 'package:jhentai/src/service/archive_download_service.dart';
import 'package:jhentai/src/service/isolate_service.dart';
import 'package:jhentai/src/service/local_backup_service.dart';
import 'package:jhentai/src/service/local_config_service.dart';
import 'package:jhentai/src/service/log.dart';
import 'package:jhentai/src/service/path_service.dart';
import 'package:jhentai/src/setting/archive_bot_setting.dart';
import 'package:jhentai/src/setting/download_setting.dart';
import 'package:jhentai/src/setting/user_setting.dart';

import 'support/test_log_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late LogService previousLog;
  setUpAll(() async {
    previousLog = log;
    log = TestLogService();
    await isolateService.doInitBean();
  });
  tearDownAll(() => log = previousLog);
  setUp(() async {
    root = await Directory.systemTemp.createTemp('hclient-backup-');
    pathService.appDocDir = root;
    pathService.tempDir = root;
    appDb = AppDb();
    await downloadSetting.doInitBean();
  });
  tearDown(() async {
    await appDb.close();
    await root.delete(recursive: true);
  });

  Future<void> config(ConfigEnum key, Object value) =>
      localConfigService.write(configKey: key, value: jsonEncode(value));

  test('v2 restores selected settings, Bot credential, cookies and groups without archive tasks', () async {
    final downloads =
        jsonDecode(downloadSetting.toConfigString()) as Map<String, dynamic>;
    downloads['downloadPath'] = '${root.path}/shared-downloads';
    await config(ConfigEnum.downloadSetting, downloads);
    await config(ConfigEnum.archiveBotSetting, {
      'apiAddress': 'https://example.com',
      'apiKey': 'test-key',
      'botType': 1,
    });
    await config(ConfigEnum.userSetting, {
      'ipbMemberId': 123,
      'ipbPassHash': 'test-password-hash',
      'userName': 'test-user',
    });
    await config(ConfigEnum.ehCookie, [
      'ipb_member_id=123',
      'ipb_pass_hash=test-password-hash',
      'igneous=test-cookie',
    ]);
    await localConfigService.write(
      configKey: ConfigEnum.frameRateMode,
      value: 'auto',
    );
    await localConfigService.write(
      configKey: ConfigEnum.searchConfig,
      subConfigKey: 'home',
      value: jsonEncode({'keyword': 'test'}),
    );
    final archive = ArchiveDownloadedData(
      gid: 12,
      token: 'token',
      title: 'Archive',
      category: 'Manga',
      pageCount: 1,
      galleryUrl: 'https://example.com/g/12/token/',
      coverUrl: 'https://example.com/cover',
      size: 123,
      publishTime: '2026-01-01',
      archiveStatusCode: ArchiveStatus.downloading.code,
      archivePageUrl: 'https://example.com/archive',
      isOriginal: true,
      insertTime: '2026-01-01',
      sortOrder: 4,
      groupName: 'saved',
      tags: 'artist:test',
      parseSource: ArchiveParseSource.bot.code,
    );
    await appDb.into(appDb.archiveDownloaded).insert(archive);
    await appDb
        .into(appDb.archiveGroup)
        .insert(const ArchiveGroupData(groupName: 'saved', sortOrder: 7));
    final backup = await localBackupService.export(
      const LocalBackupSelection(botCredential: true),
    );
    expect(jsonDecode(backup)['version'], 2);
    expect(backup, isNot(contains('shared-downloads')));
    expect(backup, isNot(contains('archiveStatusCode')));
    await appDb.delete(appDb.localConfig).go();
    await appDb.delete(appDb.archiveDownloaded).go();
    final result = await localBackupService.import(backup);
    expect(result, (legacy: false, needsRestart: true));
    await appDb.close();
    appDb = AppDb();
    userSetting.applyBeanConfig(
      (await localConfigService.read(configKey: ConfigEnum.userSetting))!,
    );
    archiveBotSetting.applyBeanConfig(
      (await localConfigService.read(configKey: ConfigEnum.archiveBotSetting))!,
    );
    downloadSetting.applyBeanConfig(
      (await localConfigService.read(configKey: ConfigEnum.downloadSetting))!,
    );
    final cookies = EHCookieManager(localConfigService);
    await cookies.initCookies();
    expect(userSetting.hasLoggedIn(), isTrue);
    expect(
      await localConfigService.read(
        configKey: ConfigEnum.searchConfig,
        subConfigKey: 'home',
      ),
      jsonEncode({'keyword': 'test'}),
    );
    expect(userSetting.ipbPassHash.value, 'test-password-hash');
    expect(archiveBotSetting.apiKey.value, 'test-key');
    expect(
      downloadSetting.downloadPath.value,
      downloadSetting.defaultDownloadPath,
    );
    expect(
      cookies.cookies.singleWhere((cookie) => cookie.name == 'igneous').value,
      'test-cookie',
    );
    expect(await appDb.select(appDb.archiveDownloaded).get(), isEmpty);
    expect(
      (await appDb.select(appDb.archiveGroup).getSingle()).groupName,
      'saved',
    );
    expect((await appDb.select(appDb.archiveGroup).getSingle()).sortOrder, 7);
    await localBackupService.import(backup);
    expect(await appDb.select(appDb.archiveDownloaded).get(), isEmpty);
  });

  test(
    'deselected local sections never export credentials or Bot keys',
    () async {
      await config(ConfigEnum.userSetting, {'ipbPassHash': 'test-secret'});
      await config(ConfigEnum.ehCookie, ['ipb_pass_hash=test-secret']);
      await config(ConfigEnum.archiveBotSetting, {'apiKey': 'test-bot-secret'});
      final backup = await localBackupService.export(
        const LocalBackupSelection(
          settings: false,
          login: false,
          archives: false,
        ),
      );
      expect(backup, isNot(contains('test-secret')));
      expect(backup, isNot(contains('test-bot-secret')));
    },
  );

  test('v2 keeps device paths, WebDAV connection and unselected units while clearing omitted bound credentials', () async {
    await config(ConfigEnum.downloadSetting, {
      'downloadPath': '/source/download',
      'singleImageSavePath': '/source/single',
      'extraGalleryScanPath': ['/source/scan'],
      'defaultGalleryGroup': 'source-group',
    });
    await config(ConfigEnum.readSetting, {
      'useThirdPartyViewer': true,
      'thirdPartyViewerPath': '/source/reader',
      'isDefaultReadModeLeftToRight': true,
    });
    await config(ConfigEnum.networkSetting, {
      'proxyAddress': 'source:8080',
      'proxyUsername': 'source-user',
      'proxyPassword': 'source-secret',
    });
    await config(ConfigEnum.archiveBotSetting, {
      'apiAddress': 'https://source.example',
      'apiKey': 'source-bot',
    });
    final backup = await localBackupService.export(
      const LocalBackupSelection(login: false, archives: false),
    );
    expect(backup, isNot(contains('/source/download')));
    expect(backup, isNot(contains('thirdPartyViewerPath')));
    expect(backup, isNot(contains('useThirdPartyViewer')));
    expect(backup, isNot(contains('source-secret')));
    expect(backup, isNot(contains('source-bot')));
    await config(ConfigEnum.downloadSetting, {
      'downloadPath': '/target/download',
      'singleImageSavePath': '/target/single',
      'extraGalleryScanPath': ['/target/scan'],
    });
    await config(ConfigEnum.readSetting, {
      'useThirdPartyViewer': true,
      'thirdPartyViewerPath': '/target/reader',
    });
    await config(ConfigEnum.networkSetting, {
      'proxyAddress': 'target:8080',
      'proxyPassword': 'target-secret',
    });
    await config(ConfigEnum.archiveBotSetting, {
      'apiAddress': 'https://target.example',
      'apiKey': 'target-bot',
    });
    await config(ConfigEnum.webdavSetting, {
      'address': 'https://target.example/dav',
      'password': 'keep',
    });
    final oldBackup = jsonDecode(backup) as Map<String, dynamic>;
    final readRow = (oldBackup['settings'] as List).cast<Map>().singleWhere(
      (row) => row['configKey'] == ConfigEnum.readSetting.key,
    );
    readRow['value'] = jsonEncode({
      'useThirdPartyViewer': true,
      'thirdPartyViewerPath': '/source/reader',
      'isDefaultReadModeLeftToRight': true,
    });
    await localBackupService.import(
      jsonEncode(oldBackup),
      selection: const LocalBackupSelection(
        dataTypes: [],
        login: false,
        archives: false,
        groups: false,
        settingUnits: {
          ConfigEnum.downloadSetting,
          ConfigEnum.readSetting,
          ConfigEnum.archiveBotSetting,
        },
      ),
    );
    final downloads = jsonDecode(
      (await localConfigService.read(configKey: ConfigEnum.downloadSetting))!,
    ) as Map;
    final read = jsonDecode(
      (await localConfigService.read(configKey: ConfigEnum.readSetting))!,
    ) as Map;
    final network = jsonDecode(
      (await localConfigService.read(configKey: ConfigEnum.networkSetting))!,
    ) as Map;
    final bot = jsonDecode(
      (await localConfigService.read(configKey: ConfigEnum.archiveBotSetting))!,
    ) as Map;
    expect(downloads['downloadPath'], '/target/download');
    expect(downloads['extraGalleryScanPath'], ['/target/scan']);
    expect(downloads['defaultGalleryGroup'], 'source-group');
    expect(read.containsKey('thirdPartyViewerPath'), isFalse);
    expect(read.containsKey('useThirdPartyViewer'), isFalse);
    expect(read['isDefaultReadModeLeftToRight'], true);
    expect(network['proxyAddress'], 'target:8080');
    expect(network['proxyPassword'], 'target-secret');
    expect(bot['apiAddress'], 'https://source.example');
    expect(bot['apiKey'], isNull);
    expect(
      await localConfigService.read(configKey: ConfigEnum.webdavSetting),
      isNotNull,
    );
  });

  test('v2 imports group order and creates missing default groups without changing other groups', () async {
    await config(ConfigEnum.downloadSetting, {
      'defaultGalleryGroup': 'new-default',
      'defaultArchiveGroup': 'new-archive',
    });
    await appDb
        .into(appDb.galleryGroup)
        .insert(const GalleryGroupData(groupName: 'shared', sortOrder: 3));
    final backup = await localBackupService.export(
      const LocalBackupSelection(login: false),
    );
    await appDb.delete(appDb.galleryGroup).go();
    await appDb
        .into(appDb.galleryGroup)
        .insert(const GalleryGroupData(groupName: 'shared', sortOrder: 1));
    await appDb
        .into(appDb.galleryGroup)
        .insert(const GalleryGroupData(groupName: 'local', sortOrder: 10));
    await localBackupService.import(backup);
    final groups = await appDb.select(appDb.galleryGroup).get();
    expect(groups.singleWhere((v) => v.groupName == 'shared').sortOrder, 3);
    expect(groups.singleWhere((v) => v.groupName == 'local').sortOrder, 10);
    expect(
      groups.singleWhere((v) => v.groupName == 'new-default').sortOrder,
      11,
    );
    expect(
      (await appDb.select(appDb.archiveGroup).get())
          .singleWhere((v) => v.groupName == 'new-archive')
          .sortOrder,
      1,
    );
  });

  test('v2 keeps local unlock settings and forces blur when resume authentication is enabled', () async {
    await config(ConfigEnum.securitySetting, {
      'enableBlur': false,
      'hideImagesInAlbum': true,
      'encryptedPassword': 'source-hash',
      'enablePasswordAuth': true,
      'enableBiometricAuth': true,
      'enableAuthOnResume': false,
    });
    final backup = await localBackupService.export(
      const LocalBackupSelection(login: false, groups: false),
    );
    expect(backup, isNot(contains('source-hash')));
    await config(ConfigEnum.securitySetting, {
      'enableBlur': true,
      'hideImagesInAlbum': false,
      'encryptedPassword': 'target-hash',
      'enablePasswordAuth': true,
      'enableBiometricAuth': false,
      'enableAuthOnResume': true,
    });
    await localBackupService.import(
      backup,
      selection: const LocalBackupSelection(
        settingUnits: {ConfigEnum.securitySetting},
        login: false,
        groups: false,
        archives: false,
      ),
    );
    final value = jsonDecode(
      (await localConfigService.read(configKey: ConfigEnum.securitySetting))!,
    ) as Map;
    expect(value['encryptedPassword'], 'target-hash');
    expect(value['enableAuthOnResume'], true);
    expect(value['enableBlur'], true);
    expect(value['hideImagesInAlbum'], true);
  });

  test(
    'v2 missing security row still preserves resume authentication with blur',
    () async {
      final backup = await localBackupService.export(
        const LocalBackupSelection(
          login: false,
          groups: false,
          settingUnits: {ConfigEnum.securitySetting},
        ),
      );
      await config(ConfigEnum.securitySetting, {
        'enableBlur': false,
        'encryptedPassword': 'local-hash',
        'enablePasswordAuth': true,
        'enableAuthOnResume': true,
      });
      await localBackupService.import(backup);
      final value = jsonDecode(
        (await localConfigService.read(configKey: ConfigEnum.securitySetting))!,
      ) as Map;
      expect(value['encryptedPassword'], 'local-hash');
      expect(value['enableAuthOnResume'], true);
      expect(value['enableBlur'], true);
    },
  );

  test(
    'rejects invalid backup sections before changing existing settings',
    () async {
      await config(ConfigEnum.archiveBotSetting, {'apiKey': 'keep'});
      final backup = jsonDecode(
        await localBackupService.export(const LocalBackupSelection()),
      ) as Map<String, dynamic>;
      backup['archives'] = [
        {'gid': 'invalid'},
      ];
      await expectLater(
        localBackupService.import(jsonEncode(backup)),
        throwsA(anything),
      );
      expect(
        jsonDecode(
          (await localConfigService.read(
            configKey: ConfigEnum.archiveBotSetting,
          ))!,
        )['apiKey'],
        'keep',
      );
    },
  );

  test('v1 imports reading preferences and drops removed viewer settings', () async {
    await config(ConfigEnum.readSetting, {
      'useThirdPartyViewer': true,
      'thirdPartyViewerPath': '/old/reader',
      'isDefaultReadModeLeftToRight': true,
    });
    final row = await (appDb.select(appDb.localConfig)
          ..where((row) => row.configKey.equals(ConfigEnum.readSetting.key)))
        .getSingle();
    await appDb.delete(appDb.localConfig).go();
    final result = await localBackupService.import(jsonEncode({
      'format': 'hclient-local-backup',
      'version': 1,
      'settings': [row.toJson()],
    }));
    expect(result, (legacy: false, needsRestart: true));
    expect(
      jsonDecode((await localConfigService.read(
        configKey: ConfigEnum.readSetting,
      ))!),
      {'isDefaultReadModeLeftToRight': true},
    );
  });

  test('old data-only backups retain their original contract', () async {
    final result = await localBackupService.import(
      jsonEncode([
        {
          'id': -1,
          'shareCode': 'local',
          'identificationCode': 'local',
          'type': 1,
          'version': '1.0.0',
          'ctime': 0,
          'config': jsonEncode([
            {
              'configKey': 'readIndexRecord',
              'subConfigKey': '123',
              'value': '9',
              'utime': '2026-01-01',
            },
          ]),
        },
      ]),
    );
    expect(result, (legacy: true, needsRestart: false));
    expect(
      await localConfigService.read(
        configKey: ConfigEnum.readIndexRecord,
        subConfigKey: '123',
      ),
      '9',
    );
    expect(
      await localConfigService.read(configKey: ConfigEnum.userSetting),
      isNull,
    );
  });
}
