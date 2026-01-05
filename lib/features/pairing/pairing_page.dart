import 'package:flutter/material.dart';
import 'package:teleport/core/widgets/teleport_background.dart';
import 'package:teleport/features/pairing/pairing_tab.dart';

class PairingPage extends StatelessWidget {
  const PairingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(title: const Text("Pair a device")),
      body: const TeleportBackground(
        padding: EdgeInsets.zero,
        child: PairingTab(),
      ),
    );
  }
}
