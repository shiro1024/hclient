import 'dart:convert';

import 'package:get/get.dart';

import '../enum/config_enum.dart';
import '../service/jh_service.dart';
import '../service/local_config_service.dart';
import '../service/webdav/webdav_client.dart';

WebDavSetting webDavSetting = WebDavSetting();

class WebDavSetting
    with JHLifeCircleBeanWithConfigStorage
    implements JHLifeCircleBean {
  final RxString address = ''.obs;
  final RxString username = ''.obs;
  final RxString password = ''.obs;
  final RxString rootPath = ''.obs;
  final RxBool autoSync = false.obs;

  @override
  ConfigEnum get configEnum => ConfigEnum.webdavSetting;

  bool get isConfigured => address.value.trim().isNotEmpty;

  WebDavConnection get connection => WebDavConnection.fromFields(
    address: address.value,
    username: username.value,
    password: password.value,
    rootPath: rootPath.value,
  );

  @override
  void applyBeanConfig(String configString) {
    final map = jsonDecode(configString) as Map<String, dynamic>;
    address.value = map['address'] as String? ?? '';
    username.value = map['username'] as String? ?? '';
    password.value = map['password'] as String? ?? '';
    rootPath.value = map['rootPath'] as String? ?? '';
    autoSync.value = map['autoSync'] as bool? ?? false;
  }

  @override
  String toConfigString() => jsonEncode({
    'address': address.value,
    'username': username.value,
    'password': password.value,
    'rootPath': rootPath.value,
    'autoSync': autoSync.value,
  });

  @override
  Future<void> doInitBean() async {}

  @override
  void doAfterBeanReady() {}

  Future<void> save({
    required String address,
    required String username,
    required String password,
    required String rootPath,
  }) async {
    final connection = WebDavConnection.fromFields(
      address: address,
      username: username,
      password: password,
      rootPath: rootPath,
    );
    final retainAutoSync =
        isConfigured &&
        this.connection.namespace == connection.namespace &&
        autoSync.value;
    final config = jsonEncode({
      'address': connection.address.toString(),
      'username': username,
      'password': password,
      'rootPath': connection.rootSegments.join('/'),
      'autoSync': retainAutoSync,
    });
    await localConfigService.write(configKey: configEnum, value: config);
    applyBeanConfig(config);
  }

  Future<void> setAutoSync(bool enabled) async {
    final config = jsonEncode({
      'address': address.value,
      'username': username.value,
      'password': password.value,
      'rootPath': rootPath.value,
      'autoSync': enabled,
    });
    await localConfigService.write(configKey: configEnum, value: config);
    applyBeanConfig(config);
  }
}
