import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:teleport/src/rust/api/teleport.dart';

class OnboardingPage extends StatefulWidget {
  final AppState state;
  final VoidCallback onComplete;

  const OnboardingPage({
    super.key,
    required this.state,
    required this.onComplete,
  });

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _nameController = TextEditingController();
  String? _targetDir;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.rocket_launch,
                  size: 80,
                  color: Colors.blueAccent,
                ),
                const SizedBox(height: 32),
                const Text(
                  "Welcome to Teleport!",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  "Let's get you set up to share files securely and fast.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 48),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: "Device Name",
                    border: OutlineInputBorder(),
                    helperText: "This name will be visible to other devices.",
                    prefixIcon: Icon(Icons.computer),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 24),
                ListTile(
                  title: const Text("Download Folder"),
                  subtitle: Text(_targetDir ?? "None selected"),
                  leading: const Icon(Icons.folder_open),
                  tileColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onTap: _selectTargetDirectory,
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                ),
                if (_targetDir == null)
                  const Padding(
                    padding: EdgeInsets.only(top: 8, left: 12),
                    child: Text(
                      "Please select a folder",
                      style: TextStyle(color: Colors.redAccent, fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 48),
                FilledButton.icon(
                  onPressed:
                      (_nameController.text.isNotEmpty && _targetDir != null)
                      ? _completeOnboarding
                      : null,
                  icon: const Icon(Icons.check),
                  label: const Text("Get Started"),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.all(20),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
