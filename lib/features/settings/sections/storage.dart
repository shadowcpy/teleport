import 'package:flutter/material.dart';
import 'package:teleport/features/settings/widgets.dart';

class StorageSection extends StatelessWidget {
  final String? targetDir;
  final VoidCallback onSelectDownloadDirectory;

  const StorageSection({
    super.key,
    required this.targetDir,
    required this.onSelectDownloadDirectory,
  });

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      title: 'Storage',
      icon: Icons.folder,
      children: [
        SettingsTile(
          icon: Icons.download,
          title: 'Download Directory',
          subtitle: targetDir ?? 'Not set',
          onTap: onSelectDownloadDirectory,
          trailing: const Icon(Icons.folder_open, size: 20),
        ),
      ],
    );
  }
}
