import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:teleport/core/widgets/teleport_background.dart';
import 'package:teleport/features/onboarding/pages/background_info_page.dart';
import 'package:teleport/features/onboarding/pages/next_steps_page.dart';
import 'package:teleport/features/onboarding/pages/permissions_page.dart';
import 'package:teleport/features/onboarding/pages/setup_page.dart';
import 'package:teleport/src/rust/api/teleport.dart';

class Onboarding extends StatefulWidget {
  final AppState state;
  final VoidCallback onComplete;

  const Onboarding({super.key, required this.state, required this.onComplete});

  @override
  State<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<Onboarding> {
  final _nameController = TextEditingController();
  String? _targetDir;
  bool _isLoading = true;
  int _pageIndex = 0;
  final PageController _pageController = PageController();
  bool _notificationGranted = true;
  bool _ignoresBatteryOptimizations = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _refreshPermissionStatus();
  }

  Future<void> _loadInitialData() async {
    try {
      final name = await widget.state.getDeviceName();
      final target = await widget.state.getTargetDir();
      if (mounted) {
        setState(() {
          _nameController.text = name;
          _targetDir = target;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load settings: $e')));
      }
    }
  }

  Future<void> _selectTargetDirectory() async {
    String? target = await FilePicker.platform.getDirectoryPath(
      dialogTitle: "Select download folder",
    );

    if (target != null) {
      setState(() => _targetDir = target);
    }
  }

  Future<void> _completeOnboarding() async {
    if (_nameController.text.isEmpty || _targetDir == null) return;

    setState(() => _isLoading = true);

    try {
      await widget.state.setDeviceName(name: _nameController.text);
      await widget.state.setTargetDir(dir: _targetDir!);
      widget.onComplete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save settings: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _refreshPermissionStatus() async {
    if (!Platform.isAndroid) {
      if (mounted) {
        setState(() {
          _notificationGranted = true;
          _ignoresBatteryOptimizations = true;
        });
      }
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

  Future<void> _requestBackgroundPermissions() async {
    if (!Platform.isAndroid) return;
    await FlutterForegroundTask.requestNotificationPermission();
    final ignoresBattery =
        await FlutterForegroundTask.isIgnoringBatteryOptimizations;
    if (!ignoresBattery) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }
    await _refreshPermissionStatus();
  }

  void _goToPage(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Widget _buildMobileOnboarding(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: TeleportBackground(
        useSafeArea: true,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Text(
                    "Step ${_pageIndex + 1} of 3",
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (index) {
                      final isActive = index == _pageIndex;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isActive ? 20 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isActive
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _pageIndex = index);
                },
                children: [
                  SetupPage(
                    nameController: _nameController,
                    targetDir: _targetDir,
                    onSelectTargetDirectory: _selectTargetDirectory,
                    onNameChanged: () => setState(() {}),
                  ),
                  Platform.isAndroid
                      ? PermissionsPage(
                          notificationGranted: _notificationGranted,
                          ignoresBatteryOptimizations:
                              _ignoresBatteryOptimizations,
                          permissionsGranted:
                              _notificationGranted &&
                              _ignoresBatteryOptimizations,
                          onRequestPermissions: _requestBackgroundPermissions,
                        )
                      : const BackgroundInfoPage(),
                  const NextStepsPage(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  if (_pageIndex > 0)
                    TextButton(
                      onPressed: () => _goToPage(_pageIndex - 1),
                      child: const Text("Back"),
                    )
                  else
                    const SizedBox(width: 64),
                  const Spacer(),
                  if (_pageIndex < 2)
                    FilledButton.icon(
                      onPressed:
                          (_nameController.text.isNotEmpty &&
                              _targetDir != null)
                          ? () => _goToPage(_pageIndex + 1)
                          : null,
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text("Next"),
                    )
                  else
                    FilledButton.icon(
                      onPressed:
                          (_nameController.text.isNotEmpty &&
                              _targetDir != null)
                          ? _completeOnboarding
                          : () {
                              _goToPage(0);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Finish device setup first."),
                                ),
                              );
                            },
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text("Continue to pairing"),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (Platform.isAndroid || Platform.isIOS) {
      return _buildMobileOnboarding(context);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: TeleportBackground(
        useSafeArea: true,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Text(
                        "Step ${_pageIndex + 1} of 3",
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                      ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(3, (index) {
                          final isActive = index == _pageIndex;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: isActive ? 20 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.onSurface
                                        .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() => _pageIndex = index);
                    },
                    children: [
                      SetupPage(
                        nameController: _nameController,
                        targetDir: _targetDir,
                        onSelectTargetDirectory: _selectTargetDirectory,
                        onNameChanged: () => setState(() {}),
                      ),
                      const BackgroundInfoPage(),
                      const NextStepsPage(),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      if (_pageIndex > 0)
                        TextButton(
                          onPressed: () => _goToPage(_pageIndex - 1),
                          child: const Text("Back"),
                        )
                      else
                        const SizedBox(width: 64),
                      const Spacer(),
                      if (_pageIndex < 2)
                        FilledButton.icon(
                          onPressed:
                              (_nameController.text.isNotEmpty &&
                                  _targetDir != null)
                              ? () => _goToPage(_pageIndex + 1)
                              : null,
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text("Next"),
                        )
                      else
                        FilledButton.icon(
                          onPressed:
                              (_nameController.text.isNotEmpty &&
                                  _targetDir != null)
                              ? _completeOnboarding
                              : () {
                                  _goToPage(0);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        "Finish device setup first.",
                                      ),
                                    ),
                                  );
                                },
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text("Continue to pairing"),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
