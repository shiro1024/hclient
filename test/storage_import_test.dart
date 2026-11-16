import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/enum/config_enum.dart';
import 'package:jhentai/src/enum/config_type_enum.dart';
import 'package:jhentai/src/model/config.dart';
import 'package:jhentai/src/service/cloud_service.dart';
import 'package:jhentai/src/service/isolate_service.dart';
import 'package:jhentai/src/service/local_config_service.dart';
import 'package:jhentai/src/service/local_block_rule_service.dart';
import 'package:jhentai/src/service/log.dart';
import 'package:jhentai/src/service/path_service.dart';
import 'package:jhentai/src/setting/download_setting.dart';

import 'support/test_log_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late LogService previousLog;

  setUpAll(() {
    previousLog = log;
    log = TestLogService();
  });
  tearDownAll(() => log = previousLog);

  setUp(() async {
    root = await Directory.systemTemp.createTemp('hclient-storage-');
    pathService.appDocDir = root;
    pathService.tempDir = root;
    await downloadSetting.doInitBean();
    downloadSetting.downloadPath.value = '${root.path}/download';
    downloadSetting.restoreTasksAutomatically.value = false;
    await Directory(downloadSetting.downloadPath.value).create(recursive: true);
    appDb = AppDb();
  });

  tearDown(() async {
    await appDb.close();
    Get.reset();
    await root.delete(recursive: true);
  });

  test(
    'fresh baseline persists current tables and reopens without migration',
    () async {
      final tables = await appDb
          .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
          .get();
      final names = tables.map((row) => row.read<String>('name')).toSet();
      expect(
        names,
        containsAll([
          'archive_downloaded_v2',
          'gallery_downloaded_v2',
          'gallery_history_v2',
          'local_config',
        ]),
      );
      expect(names.where((name) => name.contains('super_resolution')), isEmpty);
      expect(names, isNot(contains('gallery_downloaded')));
      expect(
        (await appDb.customSelect('PRAGMA user_version').getSingle()).read<int>(
          'user_version',
        ),
        4,
      );
      await localConfigService.write(
        configKey: ConfigEnum.readIndexRecord,
        subConfigKey: '123',
        value: '7',
      );
      await appDb.close();
      appDb = AppDb();
      expect(
        await localConfigService.read(
          configKey: ConfigEnum.readIndexRecord,
          subConfigKey: '123',
        ),
        '7',
      );
    },
  );

  test(
    'legacy JSON reading progress imports through the public config service',
    () async {
      await isolateService.doInitBean();
      final config = CloudConfig.fromJson({
        'id': -1,
        'shareCode': 'local',
        'identificationCode': 'local',
        'type': CloudConfigTypeEnum.readIndexRecord.code,
        'version': '1.0.0',
        'ctime': 1700000000000,
        'config': jsonEncode([
          {
            'configKey': ConfigEnum.readIndexRecord.key,
            'subConfigKey': '456',
            'value': '12',
            'utime': '2023-11-14',
          },
        ]),
      });
      await cloudConfigService.importConfig(config);
      expect(
        await localConfigService.read(
          configKey: ConfigEnum.readIndexRecord,
          subConfigKey: '456',
        ),
        '12',
      );
      final exported = await cloudConfigService.getLocalConfig(
        CloudConfigTypeEnum.readIndexRecord,
      );
      expect(
        (jsonDecode(exported!.config) as List).single['subConfigKey'],
        '456',
      );
      await localBlockRuleService.doInitBean();
      final rule = LocalBlockRule(
        groupId: 'imported',
        target: LocalBlockTargetEnum.gallery,
        attribute: LocalBlockAttributeEnum.uploader,
        pattern: LocalBlockPatternEnum.equal,
        expression: 'example-uploader',
      );
      final rulesConfig = CloudConfig(
        id: -1,
        shareCode: 'local',
        identificationCode: 'local',
        type: CloudConfigTypeEnum.blockRules,
        version: '1.0.0',
        config: jsonEncode([rule.toJson()]),
        ctime: DateTime.now(),
      );
      await cloudConfigService.importConfig(rulesConfig);
      expect(
        (await localBlockRuleService.getBlockRules()).single.expression,
        'example-uploader',
      );
      await cloudConfigService.importConfig(rulesConfig);
      expect(await localBlockRuleService.getBlockRules(), hasLength(1));
    },
  );
}
