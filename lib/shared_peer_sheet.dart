import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:teleport/file_sender.dart';
import 'package:teleport/src/rust/api/teleport.dart';

class SharedPeerSheet extends StatefulWidget {
  final AppState state;
  final List<(String, String)> peers;
  final List<String> files;
  final Function() onSent;

  const SharedPeerSheet({
    super.key,
    required this.state,
    required this.peers,
    required this.files,
    required this.onSent,
  });

  @override
  State<SharedPeerSheet> createState() => _SharedPeerSheetState();
}

class _SharedPeerSheetState extends State<SharedPeerSheet> {
  static const platform = MethodChannel('com.example.teleport/app');

  Future<void> _minimize() async {
    try {
      await platform.invokeMethod('minimize');
    } on PlatformException catch (e) {
      debugPrint("Failed to minimize: ${e.message}");
    }
  }

  Future<void> _sendToPeer(String peerId) async {
    Navigator.pop(context); // Close sheet
    widget.onSent(); // Notify parent

    for (final path in widget.files) {
      final name = path.split('/').last;

      await FileSender.sendFile(
        state: widget.state,
        peer: peerId,
        path: path,
        name: name,
        onProgress: (p) {}, // Handled by background service
        onError: (e) {}, // Handled by notifications
        onDone: () {}, // Handled by notifications
      );
    }

    // Minimize immediately after starting send
    await _minimize();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Send ${widget.files.length} file(s) to...",
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          if (widget.peers.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text("No paired devices found.")),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              itemCount: widget.peers.length,
              itemBuilder: (context, index) {
                final peer = widget.peers[index];
                return ListTile(
                  leading: const Icon(Icons.device_hub),
                  title: Text(peer.$1),
                  subtitle: Text(peer.$2),
                  onTap: () => _sendToPeer(peer.$2),
                );
              },
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
