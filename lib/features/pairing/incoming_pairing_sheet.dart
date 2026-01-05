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
          const Text(
            "Incoming Pairing Request",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            "Device: ${widget.pair.friendlyName}",
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          const Text(
            "Enter the 6-digit code displayed on the other device:",
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: "Pairing Code",
              errorText: _errorText,
              counterText: "",
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, letterSpacing: 5),
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
