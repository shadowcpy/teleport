import 'dart:math';
import 'dart:typed_data';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:teleport/data/state/teleport_store.dart';

import 'package:teleport/src/rust/api/teleport.dart';
import 'package:teleport/src/rust/lib.dart';

class PairingTab extends StatefulWidget {
  const PairingTab({super.key});

  @override
  State<PairingTab> createState() => _PairingTabState();
}

class _PairingTabState extends State<PairingTab> {
  Future<void> _handleScanQrCode(TeleportStore store) async {
    // Logic for mobile scanner bottom sheet
    final scannedInfo = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => const _QrScannerSheet(),
    );

    if (scannedInfo != null) {
      _startPairingProcess(scannedInfo, store);
    }
  }

  Future<void> _startPairingProcess(
    String remoteInfo,
    TeleportStore store,
  ) async {
    final random = Random();
    final numbers = List.generate(6, (_) => random.nextInt(10));
    final displayCode = numbers.join();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PairingDialog(
        remoteInfo: remoteInfo,
        pairingCode: numbers,
        displayCode: displayCode,
        onPair: (info, code) => store.pairWith(info: info, pairingCode: code),
        onSuccess: (newPeers) {
          store.refreshPeers();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Successfully paired!")));
        },
        peersFetcher: store.state.peers,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = TeleportScope.of(context);
    final pairingInfo = store.pairingInfo;

    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (pairingInfo != null)
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SizedBox(
                    height: 200,
                    width: 200,
                    child: PrettyQrView.data(data: pairingInfo),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            const Text(
              "Scan this QR on the other device",
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 40),
            if (Platform.isAndroid || Platform.isIOS)
              FilledButton.icon(
                onPressed: () => _handleScanQrCode(store),
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text("Scan QR Code"),
              )
            else
              const Text(
                "Use mobile to scan",
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
          ],
        ),
      ),
    );
  }
}

class PairingDialog extends StatefulWidget {
  final String remoteInfo;
  final List<int> pairingCode;
  final String displayCode;
  final Future<PairingResponse> Function(String, U8Array6) onPair;
  final Future<List<(String, String)>> Function() peersFetcher;
  final void Function(List<(String, String)>) onSuccess;

  const PairingDialog({
    super.key,
    required this.remoteInfo,
    required this.pairingCode,
    required this.displayCode,
    required this.onPair,
    required this.peersFetcher,
    required this.onSuccess,
  });

  @override
  State<PairingDialog> createState() => _PairingDialogState();
}

class _PairingDialogState extends State<PairingDialog> {
  bool _isLoading = true;
  String? _errorMessage;
  bool _isSuccess = false;
  bool _isWrongCode = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final response = await widget.onPair(
        widget.remoteInfo,
        U8Array6(Uint8List.fromList(widget.pairingCode)),
      );

      if (!mounted) return;

      response.when(
        success: () async {
          final newPeers = await widget.peersFetcher();
          if (!mounted) return;
          widget.onSuccess(newPeers);
          setState(() {
            _isLoading = false;
            _isSuccess = true;
          });
        },
        wrongCode: () {
          setState(() {
            _isLoading = false;
            _isWrongCode = true;
            _errorMessage =
                "The code entered on the other device was incorrect.";
          });
        },
        wrongSecret: () {
          setState(() {
            _isLoading = false;
            _isWrongCode = true;
            _errorMessage = "The scanned QR code was invalid";
          });
        },
        error: (msg) {
          setState(() {
            _isLoading = false;
            _errorMessage = msg;
          });
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Exact match for "Standard" AlertDialog when showing wrong code error
    if (_isWrongCode) {
      return AlertDialog(
        title: const Text("Pairing Failed"),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.no_encryption_gmailerrorred,
              color: Colors.red,
              size: 48,
            ),
            SizedBox(height: 16),
            Text("Wrong Pairing Code"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      );
    }

    return AlertDialog(
      title: Text(
        _isSuccess
            ? "Pairing Successful"
            : _errorMessage != null
            ? "Pairing Failed"
            : "Pairing...",
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isLoading) ...[
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            const Text(
              "Enter this code on the other device:",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  widget.displayCode
                      .split('')
                      .join(' '), // Add space between digits
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          ] else if (_isSuccess) ...[
            const Icon(Icons.check_circle, color: Colors.green, size: 64),
            const SizedBox(height: 16),
            const Text("Devices are now connected."),
          ] else ...[
            const Icon(Icons.error, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? "Unknown error",
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ],
      ),
      actions: [
        if (!_isLoading)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_isSuccess ? "Done" : "Close"),
          ),
      ],
    );
  }
}

class _QrScannerSheet extends StatefulWidget {
  const _QrScannerSheet();

  @override
  State<_QrScannerSheet> createState() => _QrScannerSheetState();
}

class _QrScannerSheetState extends State<_QrScannerSheet> {
  bool _hasScanned = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: MobileScanner(
        onDetect: (result) {
          if (_hasScanned) return;
          final barcode = result.barcodes.firstOrNull;
          if (barcode?.rawValue != null) {
            setState(() => _hasScanned = true);
            Navigator.pop(context, barcode!.rawValue);
          }
        },
      ),
    );
  }
}
