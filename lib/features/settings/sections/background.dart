import 'package:flutter/material.dart';
import 'package:teleport/features/settings/widgets.dart';

class BackgroundSection extends StatelessWidget {
  final bool notificationGranted;
  final bool ignoresBatteryOptimizations;
  final VoidCallback onRequestNotifications;
  final VoidCallback onRequestBatteryOptimization;

  const BackgroundSection({
    super.key,
    required this.notificationGranted,
    required this.ignoresBatteryOptimizations,
    required this.onRequestNotifications,
    required this.onRequestBatteryOptimization,
  });

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      title: 'Background',
      icon: Icons.notifications_active,
      children: [
        SettingsTile(
          icon: Icons.notifications_active,
          title: 'Notifications',
          subtitle: notificationGranted ? 'Granted' : 'Not granted',
          onTap: onRequestNotifications,
          trailing: notificationGranted
              ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
              : const Icon(Icons.warning_amber, size: 20),
        ),
        SettingsTile(
          icon: Icons.battery_saver,
          title: 'Battery optimization',
          subtitle: ignoresBatteryOptimizations ? 'Ignored' : 'Optimized',
          onTap: onRequestBatteryOptimization,
          trailing: ignoresBatteryOptimizations
              ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
              : const Icon(Icons.warning_amber, size: 20),
        ),
      ],
    );
  }
}
