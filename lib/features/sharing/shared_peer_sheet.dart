import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:teleport/data/state/teleport_store.dart';

class SharedPeerSheet extends StatefulWidget {
  final TeleportStore store;
  final List<String> files;
  final Function() onSent;

  const SharedPeerSheet({
    super.key,
    required this.store,
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

      await widget.store.sendFile(peer: peerId, path: path, name: name);
    }

    // Minimize immediately after starting send
    await _minimize();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.12),
                child: Icon(
                  Icons.send,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Send ${widget.files.length} file(s)",
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            "Choose a paired device to start the transfer.",
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          if (widget.store.peers.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text("No paired devices found.")),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              itemCount: widget.store.peers.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final peer = widget.store.peers[index];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.12),
                      child: Icon(
                        Icons.device_hub,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    title: Text(peer.$1),
                    subtitle: Text(peer.$2),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => _sendToPeer(peer.$2),
                  ),
                );
              },
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
