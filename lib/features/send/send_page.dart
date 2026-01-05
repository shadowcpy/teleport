import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:teleport/data/state/teleport_store.dart';
import 'package:teleport/src/rust/api/teleport.dart';
import 'file_sender.dart';

class SendPage extends StatefulWidget {
  const SendPage({super.key});

  @override
  State<SendPage> createState() => _SendPageState();
}

class _SendPageState extends State<SendPage> {
  String? _selectedPeer;
  double? _uploadProgress; // null = not sending, 0.0-1.0 = sending

  Future<void> _handleSendFile(TeleportStore store) async {
    if (_selectedPeer == null) return;

    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;

    setState(() => _uploadProgress = 0.0);

    final file = result.files.first;
    if (file.path == null) throw Exception("File path is null");

    await FileSender.sendFile(
      state: store.state,
      peer: _selectedPeer!,
      path: file.path!,
      name: file.name,
      onProgress: (percent) {
        if (mounted) setState(() => _uploadProgress = percent);
      },
      onDone: () {
        if (mounted) {
          _showSnackBar("File sent successfully", isError: false);
          setState(() => _uploadProgress = null);
        }
      },
      onError: (msg) {
        if (mounted) {
          _showSnackBar("Failed to send: $msg", isError: true);
          setState(() => _uploadProgress = null);
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

  Widget _getConnQuality(
    String peer,
    Map<String, UIConnectionQuality> qualityMap,
  ) {
    var quality = qualityMap[peer];
    if (quality == null) return SizedBox();

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

  @override
  Widget build(BuildContext context) {
    final store = TeleportScope.of(context);
    final peers = store.peers;
    final downloadProgress = store.downloadProgress;

    if (peers.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.devices_other, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text("No paired devices."),
            Text("Go to the 'Pair' tab to connect."),
          ],
        ),
      );
    }

    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            "Select a device to send to:",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: RadioGroup<String>(
            groupValue: _selectedPeer,
            onChanged: (val) => setState(() => _selectedPeer = val),
            child: ListView.builder(
              itemCount: peers.length,
              itemBuilder: (context, index) {
                final peer = peers[index];
                return RadioListTile<String>(
                  title: Row(
                    children: [
                      Text(peer.$1),
                      SizedBox(width: 10),
                      _getConnQuality(peer.$2, store.connQuality),
                    ],
                  ),
                  subtitle: Text(peer.$2, style: const TextStyle(fontSize: 10)),
                  value: peer.$2,
                );
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: _uploadProgress != null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      LinearProgressIndicator(value: _uploadProgress),
                      const SizedBox(height: 5),
                      Text(
                        "Sending... ${(_uploadProgress! * 100).toStringAsFixed(0)}%",
                      ),
                    ],
                  )
                : FilledButton.icon(
                    onPressed: _selectedPeer == null
                        ? null
                        : () => _handleSendFile(store),
                    icon: const Icon(Icons.send),
                    label: const Text("Select File & Send"),
                  ),
          ),
        ),
        if (downloadProgress.isNotEmpty) ...[
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text(
              "Incoming Files",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 0,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 150),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: downloadProgress.length,
                itemBuilder: (context, index) {
                  final entry = downloadProgress.entries.elementAt(index);
                  // entry.key is "peer/filename"
                  final name = entry.key.split('/').last;
                  final (offset, size) = entry.value;
                  // Handle potential division by zero just in case
                  double progress = 0.0;
                  if (size > BigInt.zero) {
                    progress = offset.toDouble() / size.toDouble();
                  }
                  return ListTile(
                    leading: const Icon(Icons.download),
                    title: Text(name),
                    subtitle: LinearProgressIndicator(value: progress),
                    trailing: Text("${(progress * 100).toStringAsFixed(0)}%"),
                  );
                },
              ),
            ),
          ),
        ],
      ],
    );
  }
}
