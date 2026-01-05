import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:teleport/data/state/teleport_store.dart';
import 'package:teleport/core/widgets/teleport_background.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  String _deviceName = '';
  String? _targetDir;
  bool _isLoading = true;

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
    _loadSettings();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final store = TeleportScope.of(context);
    try {
      final name = await store.state.getDeviceName();
      final dir = await store.state.getTargetDir();

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
                    _buildSection(
                      title: 'Device',
                      icon: Icons.phone_android,
                      children: [
                        _buildSettingTile(
                          icon: Icons.computer,
                          title: 'Device Name',
                          subtitle: _deviceName,
                          onTap: _editDeviceName,
                          trailing: const Icon(Icons.edit, size: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildSection(
                      title: 'Storage',
                      icon: Icons.folder,
                      children: [
                        _buildSettingTile(
                          icon: Icons.download,
                          title: 'Download Directory',
                          subtitle: _targetDir ?? 'Not set',
                          onTap: _selectDownloadDirectory,
                          trailing: const Icon(Icons.folder_open, size: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildSection(
                      title: 'About',
                      icon: Icons.info_outline,
                      children: [
                        _buildSettingTile(
                          icon: Icons.apps,
                          title: 'Version',
                          subtitle: '1.0.0',
                          onTap: null,
                        ),
                        _buildSettingTile(
                          icon: Icons.security,
                          title: 'Privacy & Security',
                          subtitle: 'End-to-end encrypted transfers',
                          onTap: () => _showPrivacyInfo(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Teleport uses peer-to-peer connections with QUIC encryption for secure, fast file transfers.',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
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

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.primaryContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(
                    alpha: 0.6,
                  ),
            ),
      ),
      trailing:
          trailing ??
          (onTap != null
              ? const Icon(Icons.arrow_forward_ios, size: 16)
              : null),
      onTap: onTap,
      enabled: onTap != null,
    );
  }

  void _showPrivacyInfo() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.security, color: Colors.green),
            SizedBox(width: 12),
            Text('Privacy & Security'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Your privacy is our priority',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 16),
              _SecurityFeature(
                icon: Icons.lock,
                title: 'End-to-End Encryption',
                description:
                    'All file transfers are encrypted with QUIC/TLS 1.3',
              ),
              SizedBox(height: 12),
              _SecurityFeature(
                icon: Icons.cloud_off,
                title: 'No Cloud Storage',
                description:
                    'Files are transferred directly between devices. Nothing is stored on our servers.',
              ),
              SizedBox(height: 12),
              _SecurityFeature(
                icon: Icons.verified_user,
                title: 'Verified Pairing',
                description:
                    'Two-factor pairing with QR code and 6-digit verification code',
              ),
              SizedBox(height: 12),
              _SecurityFeature(
                icon: Icons.vpn_lock,
                title: 'NAT Traversal',
                description:
                    'Direct peer-to-peer connections with automatic NAT traversal',
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

class _SecurityFeature extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _SecurityFeature({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.green.shade700),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
