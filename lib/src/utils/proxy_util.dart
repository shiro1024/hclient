import 'package:flutter/cupertino.dart';
import 'package:jhentai/src/service/log.dart';
import 'package:jhentai/src/utils/string_uril.dart';
import 'package:platform_proxy/platform_proxy.dart';

import '../setting/network_setting.dart';

Future<String> getSystemProxyAddress() async {
  String systemProxyAddress = '';

  final proxies = await PlatformProxy().getPlatformProxies(url: 'https://e-hentai.org');
  for (final proxy in proxies) {
    if ((proxy.type == 'http' || proxy.type == 'https') && proxy.host.isNotEmpty && proxy.port.isNotEmpty) {
      systemProxyAddress = '${proxy.host}:${proxy.port}';
      break;
    }
  }

  log.info('systemProxyAddress: $systemProxyAddress');
  return systemProxyAddress;
}

Future<String Function(Uri)> findProxySettingFunc(ValueGetter<String> systemProxyAddress) async {
  String configProxyAddress() {
    String configAddress;
    if (isEmptyOrNull(networkSetting.proxyUsername.value?.trim()) && isEmptyOrNull(networkSetting.proxyPassword.value?.trim())) {
      configAddress = networkSetting.proxyAddress.value;
    } else {
      configAddress = '${networkSetting.proxyUsername.value ?? ''}:${networkSetting.proxyPassword.value ?? ''}@${networkSetting.proxyAddress.value}';
    }
    return configAddress;
  }

  return (_) {
    switch (networkSetting.proxyType.value) {
      case JProxyType.system:
        return isEmptyOrNull(systemProxyAddress.call()) ? 'DIRECT' : 'PROXY ${systemProxyAddress.call()}; DIRECT';
      case JProxyType.http:
        return 'PROXY ${configProxyAddress()}; DIRECT';
      case JProxyType.socks5:
        return 'SOCKS5 ${configProxyAddress()}; DIRECT';
      case JProxyType.socks4:
        return 'SOCKS4 ${configProxyAddress()}; DIRECT';
      case JProxyType.direct:
        return 'DIRECT';
    }
  };
}
