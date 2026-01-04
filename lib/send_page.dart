import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:teleport/src/rust/api/teleport.dart';

class SendPage extends StatefulWidget {
  final AppState state;
  final List<(String, String)> peers;
  final Map<String, (BigInt, BigInt)> downloadProgress;

  const SendPage({
    super.key,
    required this.state,
    required this.peers,
    required this.downloadProgress,
  });

  @override
  State<SendPage> createState() => _SendPageState();
}

class _SendPageState extends State<SendPage> {
  String? _selectedPeer;
  double? _uploadProgress; // null = not sending, 0.0-1.0 = sending

  Future<void> _handleSendFile() async {
    if (_selectedPeer == null) return;

    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;

    setState(() => _uploadProgress = 0.0);

    final file = result.files.first;
    if (file.path == null) throw Exception("File path is null");

    final progress = widget.state.sendFile(
      peer: _selectedPeer!,
      name: file.name,
      path: file.path!,
    );

    progress.listen((event) {
      event.when(
        progress: (offset, size) {
          if (mounted) {
            setState(() {
              // Convert BigInt to double for progress calculation
              // Assuming size is not 0 to avoid division by zero which might happen briefly
              if (size > BigInt.zero) {
                _uploadProgress = offset.toDouble() / size.toDouble();
              }
            });
          }
        },
        done: () {
          if (mounted) {
            _showSnackBar("File sent successfully", isError: false);
            setState(() => _uploadProgress = null);
          }
        },
        error: (msg) {
          if (mounted) {
            _showSnackBar("Failed to send: $msg", isError: true);
            setState(() => _uploadProgress = null);
          }
        },
      );
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.peers.isEmpty) {
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
              itemCount: widget.peers.length,
              itemBuilder: (context, index) {
                final peer = widget.peers[index];
                return RadioListTile<String>(
                  title: Text(peer.$1),
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
                    onPressed: _selectedPeer == null ? null : _handleSendFile,
                    icon: const Icon(Icons.send),
                    label: const Text("Select File & Send"),
                  ),
          ),
        ),
        if (widget.downloadProgress.isNotEmpty) ...[
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
                itemCount: widget.downloadProgress.length,
                itemBuilder: (context, index) {
                  final entry = widget.downloadProgress.entries.elementAt(
                    index,
                  );
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

// Helper widget since RadioListTile doesn't support a groupValue that is managed externally well without a parent
// Actually RadioListTile works fine, but we need to manage the group value state. The original code had a RadioGroup widget?
// Let's check main.dart again.
// Ah, the original code had `RadioGroup`. I need to see if it's a custom widget or if I missed it in main.dart.
// I reviewed main.dart content in Step 27.
// Line 368: `child: RadioGroup(`
// Wait, `RadioGroup` is NOT a standard Flutter widget. It must be defined somewhere else or I missed it in `main.dart`.
// Scanning `main.dart` again...
// I don't see `class RadioGroup` in `main.dart`. It might be in another file or I missed it.
// Let me check `lib` directory contents again.
