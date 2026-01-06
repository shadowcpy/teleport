import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:teleport/data/state/teleport_store.dart';
import 'package:teleport/core/widgets/teleport_background.dart';
import 'package:teleport/features/settings/sections/background.dart';
import 'package:teleport/features/settings/sections/device.dart';
import 'package:teleport/features/settings/sections/storage.dart';

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  String _deviceName = '';
  String? _targetDir;
  bool _isLoading = true;
  bool _notificationGranted = true;
  bool _ignoresBatteryOptimizations = true;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isLoading) {
      _loadSettings();
    }
  }

  Future<void> _loadSettings() async {
    final store = TeleportScope.of(context);
    try {
      final name = await store.state.getDeviceName();
      final dir = await store.state.getTargetDir();
      await _refreshBackgroundPermissions();

      if (mounted) {
        setState(() {
          _deviceName = name;
          _targetDir = dir;
          _isLoading = false;
        });
        _animController.forward();
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to load settings: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _editDeviceName() async {
    final controller = TextEditingController(text: _deviceName);

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Device Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Device Name',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.computer),
          ),
          autofocus: true,
          maxLength: 32,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != _deviceName) {
      await _updateDeviceName(newName);
    }
  }

  Future<void> _updateDeviceName(String name) async {
    final store = TeleportScope.of(context);
    try {
      await store.state.setDeviceName(name: name);
      setState(() => _deviceName = name);
      _showSuccess('Device name updated');
    } catch (e) {
      _showError('Failed to update device name: $e');
    }
  }

  Future<void> _selectDownloadDirectory() async {
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select download folder',
    );

    if (path != null && path != '/' && path != _targetDir) {
      await _updateDownloadDirectory(path);
    }
  }

  Future<void> _updateDownloadDirectory(String path) async {
    final store = TeleportScope.of(context);
    try {
      await store.setTargetDir(path);
      setState(() => _targetDir = path);
      _showSuccess('Download directory updated');
    } catch (e) {
      _showError('Failed to update directory: $e');
    }
  }

  Future<void> _refreshBackgroundPermissions() async {
    if (!Platform.isAndroid) {
      setState(() {
        _notificationGranted = true;
        _ignoresBatteryOptimizations = true;
      });
      return;
    }

    final notificationStatus =
        await FlutterForegroundTask.checkNotificationPermission();
    final ignoresBattery =
        await FlutterForegroundTask.isIgnoringBatteryOptimizations;
    if (!mounted) return;
    setState(() {
      _notificationGranted =
          notificationStatus == NotificationPermission.granted;
      _ignoresBatteryOptimizations = ignoresBattery;
    });
  }

  Future<void> _requestNotificationPermission() async {
    if (!Platform.isAndroid) return;
    await FlutterForegroundTask.requestNotificationPermission();
    await _refreshBackgroundPermissions();
    if (_notificationGranted) {
      _showSuccess('Notifications enabled');
    }
  }

  Future<void> _requestBatteryOptimizationPermission() async {
    if (!Platform.isAndroid) return;
    final ignoresBattery =
        await FlutterForegroundTask.isIgnoringBatteryOptimizations;
    if (!ignoresBattery) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }
    await _refreshBackgroundPermissions();
    if (_ignoresBatteryOptimizations) {
      _showSuccess('Battery optimization disabled');
    }
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Settings'), elevation: 0),
      body: TeleportBackground(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : FadeTransition(
                opacity: _fadeAnimation,
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    DeviceSection(
                      deviceName: _deviceName,
                      onEditDeviceName: _editDeviceName,
                    ),
                    const SizedBox(height: 16),
                    StorageSection(
                      targetDir: _targetDir,
                      onSelectDownloadDirectory: _selectDownloadDirectory,
                    ),
                    if (Platform.isAndroid) ...[
                      const SizedBox(height: 16),
                      BackgroundSection(
                        notificationGranted: _notificationGranted,
                        ignoresBatteryOptimizations:
                            _ignoresBatteryOptimizations,
                        onRequestNotifications: _requestNotificationPermission,
                        onRequestBatteryOptimization:
                            _requestBatteryOptimizationPermission,
                      ),
                    ],
                    const SizedBox(height: 16),
                    const SizedBox(height: 28),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Version 1.0.0',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
