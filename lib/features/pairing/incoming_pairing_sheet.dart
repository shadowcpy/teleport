import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:teleport/src/rust/api/teleport.dart';

class IncomingPairingSheet extends StatefulWidget {
  final InboundPair pair;
  final Function(UIPairReaction) onRespond;

  const IncomingPairingSheet({
    super.key,
    required this.pair,
    required this.onRespond,
  });

  @override
  State<IncomingPairingSheet> createState() => _IncomingPairingSheetState();
}

class _IncomingPairingSheetState extends State<IncomingPairingSheet> {
  final _codeController = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _handleConnect() {
    final input = _codeController.text.trim();
    final expected = widget.pair.pairingCode.join();

    if (input == expected) {
      widget.onRespond(UIPairReaction.accept);
    } else {
      setState(() => _errorText = "Incorrect code");
      widget.onRespond(UIPairReaction.wrongPairingCode);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Push up for keyboard
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "Incoming pairing request",
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            "Confirm the 6-digit code shown on the other device.",
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.12),
                  child: Icon(
                    Icons.devices,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.pair.friendlyName,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: "Pairing Code",
              errorText: _errorText,
              counterText: "",
              prefixIcon: const Icon(Icons.pin),
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, letterSpacing: 6),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: FilledButton.tonal(
                  onPressed: () => widget.onRespond(UIPairReaction.reject),
                  child: const Text("Reject"),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton(
                  onPressed: _handleConnect,
                  child: const Text("Connect"),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
