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

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 720;
        final qrCard = Card(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                Text(
                  "Your pairing QR",
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Container(
                  height: 220,
                  width: 220,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withValues(alpha: 0.2),
                    ),
                  ),
                  child: pairingInfo == null
                      ? const Center(child: CircularProgressIndicator())
                      : PrettyQrView.data(data: pairingInfo),
                ),
                const SizedBox(height: 12),
                Text(
                  "Scan this QR on the other device",
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        );

        final scanCard = Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Pair from this device",
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  "Scan another device's QR code, then confirm the 6-digit code.",
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                if (Platform.isAndroid || Platform.isIOS)
                  FilledButton.icon(
                    onPressed: () => _handleScanQrCode(store),
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text("Scan QR Code"),
                  )
                else
                  Text(
                    "Use the mobile app to scan",
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  "Keep both devices open and match the 6-digit code.",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        );

        return SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: qrCard),
                    const SizedBox(width: 16),
                    Expanded(child: scanCard),
                  ],
                )
              : Column(
                  children: [qrCard, const SizedBox(height: 16), scanCard],
                ),
        );
      },
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
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Text(
                  "Scan QR Code",
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
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
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Hold the camera steady inside the frame.",
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
