import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_rust/native_toolchain_rust.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) {
      return;
    }
    final code = input.config.code;
    final iosVersion = code.targetOS == OS.iOS
        ? code.iOS.deploymentVersion
        : null;
    await RustBuilder(
      assetName: 'src/service/content_codec.dart',
      cratePath: 'native',
      extraCargoEnvironmentVariables: {
        if (iosVersion != null)
          'IPHONEOS_DEPLOYMENT_TARGET':
              '${iosVersion.major}.${iosVersion.minor}.${iosVersion.patch}',
      },
    ).run(input: input, output: output);
  });
}
