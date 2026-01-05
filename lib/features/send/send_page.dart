import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:teleport/data/state/teleport_store.dart';
import 'package:teleport/features/pairing/pairing_page.dart';
import 'package:teleport/src/rust/api/teleport.dart';

class SendPage extends StatefulWidget {
  const SendPage({super.key});

  @override
  State<SendPage> createState() => _SendPageState();
}

class _SendPageState extends State<SendPage> {
  String? _selectedPeer;

  void _openPairingTab() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PairingPage()));
  }

  Future<void> _handleSendFile(TeleportStore store) async {
    if (_selectedPeer == null) return;

    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.path == null) throw Exception("File path is null");

    await store.sendFile(
      peer: _selectedPeer!,
      path: file.path!,
      name: file.name,
      onDone: () {
        if (mounted) {
          _showSnackBar("File sent successfully", isError: false);
        }
      },
      onError: (msg) {
        if (mounted) {
          _showSnackBar("Failed to send: $msg", isError: true);
        }
      },
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : null,
      ),
    );
  }

  String _formatBytes(num bytes) {
    const units = ["B", "KB", "MB", "GB", "TB"];
    var value = bytes.toDouble();
    var unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }
    final decimals = value >= 100 ? 0 : 1;
    return "${value.toStringAsFixed(decimals)} ${units[unitIndex]}";
  }

  String _formatSpeed(double bytesPerSecond) {
    if (bytesPerSecond <= 0) return "Starting...";
    return "${_formatBytes(bytesPerSecond)}/s";
  }

  Widget _transferCard({
    required String title,
    required IconData icon,
    required Map<String, TransferProgress> transfers,
    required Map<String, String> peerLabels,
    required Color accentColor,
  }) {
    return Card(
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: accentColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: accentColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...transfers.entries.map((entry) {
              final progress = entry.value;
              final peerLabel = peerLabels[progress.peer] ?? "Unknown device";
              double percent = 0.0;
              if (progress.size > BigInt.zero) {
                percent = progress.offset.toDouble() / progress.size.toDouble();
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.insert_drive_file,
                          size: 18,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                progress.name,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "$peerLabel | ${_formatSpeed(progress.bytesPerSecond)}",
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Text("${(percent * 100).toStringAsFixed(0)}%"),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: percent,
                      color: accentColor,
                      backgroundColor: accentColor.withValues(alpha: 0.2),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _getConnQuality(
    String peer,
    Map<String, UIConnectionQuality> qualityMap,
  ) {
    var quality = qualityMap[peer];
    if (quality == null) return const SizedBox();

    Chip chip(Color color, String label, IconData icon) => Chip(
      visualDensity: VisualDensity(horizontal: -4, vertical: -4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      side: BorderSide(color: color),
      backgroundColor: color.withValues(alpha: 0.1),
      materialTapTargetSize: .shrinkWrap,
      label: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
      avatar: Icon(icon, color: color, size: 14),
    );

    switch (quality) {
      case UIConnectionQuality.direct:
        return chip(Colors.green, "Direct", Icons.bolt);
      case UIConnectionQuality.mixed:
        return chip(Colors.blue, "Mixed", Icons.alt_route);
      case UIConnectionQuality.relay:
        return chip(Colors.orange, "Relay", Icons.router);
      case UIConnectionQuality.none:
        return chip(Colors.red, "Disconnected", Icons.signal_cellular_off);
    }
  }

  String _shortPeerId(String peer) {
    const maxLen = 12;
    if (peer.length <= maxLen) return peer;
    return peer.substring(0, maxLen);
  }

  TextStyle? _peerIdStyle(BuildContext context) {
    final base = Theme.of(context).textTheme.bodySmall?.copyWith(
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
    );
    if (base == null) return null;
    return GoogleFonts.jetBrainsMono(textStyle: base);
  }

  @override
  Widget build(BuildContext context) {
    final store = TeleportScope.of(context);
    final peers = store.peers;
    final peerLabels = {for (final peer in peers) peer.$2: peer.$1};
    final downloadProgress = store.downloadProgress;
    final uploadProgress = store.uploadProgress;

    if (peers.isEmpty) {
      return Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.devices_other,
                  size: 56,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  "No paired devices yet",
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  "Pair a device to start sending files instantly.",
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _openPairingTab,
                  icon: const Icon(Icons.link),
                  label: const Text("Go to pairing"),
                ),
              ],
            ),
          ),
        ),
      );
    }

    String? selectedLabel;
    for (final peer in peers) {
      if (peer.$2 == _selectedPeer) {
        selectedLabel = peer.$1;
        break;
      }
    }

    final hasTransfers =
        uploadProgress.isNotEmpty || downloadProgress.isNotEmpty;
    return ListView(
      children: [
        Text("Quick send", style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.12),
                      child: Icon(
                        Icons.send_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selectedLabel ?? "No device selected",
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _selectedPeer == null
                                ? "Choose a device below to send a file"
                                : _shortPeerId(_selectedPeer!),
                            style: _peerIdStyle(context),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _selectedPeer == null
                      ? null
                      : () => _handleSendFile(store),
                  icon: const Icon(Icons.attach_file),
                  label: const Text("Choose file & send"),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                "Devices",
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const PairingPage()));
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
                side: BorderSide(color: Theme.of(context).colorScheme.primary),
              ),
              icon: const Icon(Icons.link),
              label: const Text("Pair new"),
            ),
          ],
        ),
        const SizedBox(height: 8),
        RadioGroup<String>(
          groupValue: _selectedPeer,
          onChanged: (val) => setState(() => _selectedPeer = val),
          child: ListView.separated(
            itemCount: peers.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final peer = peers[index];
              return Card(
                child: RadioListTile<String>(
                  value: peer.$2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  title: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.12),
                        child: Icon(
                          Icons.device_hub,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              peer.$1,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _shortPeerId(peer.$2),
                              style: _peerIdStyle(context),
                            ),
                          ],
                        ),
                      ),
                      _getConnQuality(peer.$2, store.connQuality),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (hasTransfers) ...[
          const SizedBox(height: 16),
          if (uploadProgress.isNotEmpty)
            _transferCard(
              title: "Outgoing",
              icon: Icons.upload_rounded,
              transfers: uploadProgress,
              peerLabels: peerLabels,
              accentColor: Theme.of(context).colorScheme.primary,
            ),
          if (uploadProgress.isNotEmpty && downloadProgress.isNotEmpty)
            const SizedBox(height: 10),
          if (downloadProgress.isNotEmpty)
            _transferCard(
              title: "Incoming",
              icon: Icons.download_rounded,
              transfers: downloadProgress,
              peerLabels: peerLabels,
              accentColor: Theme.of(context).colorScheme.secondaryContainer,
            ),
        ],
      ],
    );
  }
}
