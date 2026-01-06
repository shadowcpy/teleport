import 'package:flutter/material.dart';
import 'package:teleport/features/onboarding/widgets.dart';

class PermissionsPage extends StatelessWidget {
  final bool notificationGranted;
  final bool ignoresBatteryOptimizations;
  final bool permissionsGranted;
  final VoidCallback onRequestPermissions;

  const PermissionsPage({
    super.key,
    required this.notificationGranted,
    required this.ignoresBatteryOptimizations,
    required this.permissionsGranted,
    required this.onRequestPermissions,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Background permissions",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "Recommended",
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Enable notifications and battery optimization exemption so Teleport can receive files reliably in the background.",
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  StatusRow(
                    icon: Icons.notifications_active,
                    title: "Notifications",
                    enabled: notificationGranted,
                    enabledText: "Granted",
                    disabledText: "Not granted",
                  ),
                  const SizedBox(height: 8),
                  StatusRow(
                    icon: Icons.battery_saver,
                    title: "Battery optimization",
                    enabled: ignoresBatteryOptimizations,
                    enabledText: "Ignored",
                    disabledText: "Optimized",
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: permissionsGranted
                          ? null
                          : onRequestPermissions,
                      icon: const Icon(Icons.notifications_active),
                      label: Text(
                        permissionsGranted ? "Enabled" : "Enable background",
                      ),
                    ),
                  ),
                  if (!permissionsGranted) ...[
                    const SizedBox(height: 6),
                    Text(
                      "You can skip this for now and enable it later in system settings.",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
