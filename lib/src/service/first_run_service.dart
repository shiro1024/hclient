import 'dart:async';

import '../enum/config_enum.dart';
import '../setting/preference_setting.dart';
import 'jh_service.dart';
import 'local_config_service.dart';
import 'tag_translation_service.dart';

FirstRunService firstRunService = FirstRunService();

class FirstRunService
    with JHLifeCircleBeanErrorCatch
    implements JHLifeCircleBean {
  @override
  List<JHLifeCircleBean> get initDependencies =>
      [localConfigService, preferenceSetting, tagTranslationService];

  @override
  Future<void> doInitBean() async {}

  @override
  Future<void> doAfterBeanReady() async {
    if (await localConfigService.read(configKey: ConfigEnum.firstOpenInited) !=
        null) {
      return;
    }
    if (preferenceSetting.locale.value.languageCode == 'zh') {
      await preferenceSetting.saveEnableTagZHTranslation(true);
      unawaited(tagTranslationService.fetchDataFromGithub());
    }
    await localConfigService.write(
        configKey: ConfigEnum.firstOpenInited, value: 'true');
  }
}
