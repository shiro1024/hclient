import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../enum/config_enum.dart';
import '../enum/config_type_enum.dart';
import '../service/local_backup_service.dart';

class EHLocalBackupSelectDialog extends StatefulWidget {
  final LocalBackupSelection? available;
  final bool restore;

  const EHLocalBackupSelectDialog({
    super.key,
    this.available,
    this.restore = false,
  });

  @override
  State<EHLocalBackupSelectDialog> createState() =>
      _EHLocalBackupSelectDialogState();
}

class _EHLocalBackupSelectDialogState extends State<EHLocalBackupSelectDialog> {
  late final Set<CloudConfigTypeEnum> selected;
  late final Set<ConfigEnum> settingUnits;
  bool login = false;
  bool botCredential = false;
  bool proxyCredential = false;
  bool groups = true;
  bool archives = false;

  @override
  void initState() {
    super.initState();
    selected = (widget.available?.dataTypes ?? CloudConfigTypeEnum.values)
        .toSet();
    settingUnits =
        (widget.available?.settingUnits ??
                LocalBackupService.portableSettingsKeys)
            .toSet();
  }

  @override
  Widget build(BuildContext context) {
    final availableUnits =
        widget.available?.settingUnits ??
        LocalBackupService.portableSettingsKeys;
    return AlertDialog(
      title: Text(widget.restore ? 'webdavRestore'.tr : 'selectExportItems'.tr),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.restore ? 'backupRestartNotice'.tr : 'localBackupHint'.tr,
          ),
          ExpansionTile(
            title: Text('backupSettings'.tr),
            subtitle: Text('${settingUnits.length}/${availableUnits.length}'),
            children: [
              ...availableUnits.map(
                (unit) => CheckboxListTile(
                  dense: true,
                  title: Text(unit.key.tr),
                  value: settingUnits.contains(unit),
                  onChanged: (value) => setState(() {
                    if (value == true) {
                      settingUnits.add(unit);
                    } else {
                      settingUnits.remove(unit);
                    }
                  }),
                ),
              ),
            ],
          ),
          if (settingUnits.contains(ConfigEnum.archiveBotSetting) &&
              (!widget.restore || widget.available?.botCredential == true))
            CheckboxListTile(
              title: Text('backupBotCredential'.tr),
              value: botCredential,
              onChanged: (value) =>
                  setState(() => botCredential = value ?? false),
            ),
          if (settingUnits.contains(ConfigEnum.networkSetting) &&
              (!widget.restore || widget.available?.proxyCredential == true))
            CheckboxListTile(
              title: Text('backupProxyCredential'.tr),
              value: proxyCredential,
              onChanged: (value) =>
                  setState(() => proxyCredential = value ?? false),
            ),
          if (widget.available == null || widget.available!.login)
            CheckboxListTile(
              title: Text('backupLogin'.tr),
              value: login,
              onChanged: (value) => setState(() => login = value ?? false),
            ),
          if (widget.available == null || widget.available!.groups)
            CheckboxListTile(
              title: Text('backupGroups'.tr),
              value: groups,
              onChanged: (value) => setState(() => groups = value ?? false),
            ),
          if (widget.restore && widget.available?.archives == true)
            CheckboxListTile(
              title: Text('backupArchives'.tr),
              value: archives,
              onChanged: (value) => setState(() => archives = value ?? false),
            ),
          ...CloudConfigTypeEnum.values
              .where(
                (type) =>
                    widget.available == null ||
                    widget.available!.dataTypes.contains(type),
              )
              .map(
                (type) => CheckboxListTile(
                  title: Text(type.name.tr),
                  value: selected.contains(type),
                  onChanged: (value) => setState(() {
                    if (value == true) {
                      selected.add(type);
                    } else {
                      selected.remove(type);
                    }
                  }),
                ),
              ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('cancel'.tr),
        ),
        TextButton(
          onPressed: () => Navigator.pop(
            context,
            LocalBackupSelection(
              dataTypes: selected.toList(),
              settings: settingUnits.isNotEmpty,
              settingUnits: settingUnits,
              login: login,
              archives: archives,
              groups: groups,
              botCredential: botCredential,
              proxyCredential: proxyCredential,
            ),
          ),
          child: Text('OK'.tr),
        ),
      ],
    );
  }
}
