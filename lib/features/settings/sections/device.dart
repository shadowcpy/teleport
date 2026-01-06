import 'package:flutter/material.dart';
import 'package:teleport/features/settings/widgets.dart';

class DeviceSection extends StatelessWidget {
  final String deviceName;
  final VoidCallback onEditDeviceName;

  const DeviceSection({
    super.key,
    required this.deviceName,
    required this.onEditDeviceName,
  });

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      title: 'Device',
      icon: Icons.phone_android,
      children: [
        SettingsTile(
          icon: Icons.computer,
          title: 'Device Name',
          subtitle: deviceName,
          onTap: onEditDeviceName,
          trailing: const Icon(Icons.edit, size: 20),
        ),
      ],
    );
  }
}
