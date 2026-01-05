import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sharing_intent/flutter_sharing_intent.dart';
import 'package:flutter_sharing_intent/model/sharing_file.dart';
import 'package:teleport/data/state/teleport_store.dart';
import 'package:teleport/features/onboarding/onboarding_page.dart';
import 'package:teleport/features/pairing/incoming_pairing_sheet.dart';
import 'package:teleport/features/pairing/pairing_tab.dart';
import 'package:teleport/features/send/send_page.dart';
import 'package:teleport/features/sharing/shared_peer_sheet.dart';
import 'package:teleport/src/rust/api/teleport.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Streams for one-off events
  StreamSubscription? _pairingRequestSub;
  StreamSubscription? _notificationSub;
  StreamSubscription? _sharingSub;

  @override
  void initState() {
    super.initState();
    _initListeners();
    _initSharing();
  }

  void _initListeners() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final store = TeleportScope.of(context);

      _pairingRequestSub = store.pairingRequests.listen((pair) {
        if (!mounted) return;
        _showIncomingPairingRequest(pair, store);
      });

      _notificationSub = store.notifications.listen((event) {
        if (!mounted) return;
        if (event.type == 'error') {
          _showSnackBar(event.name, isError: true);
        } else {
          _showSnackBar(event.name, isError: false);
        }
      });
    });
  }

  void _initSharing() {
    if (!Platform.isAndroid) return;
    // Sharing intent listener
    FlutterSharingIntent.instance.getMediaStream().listen(
      (List<SharedFile> value) {
        if (value.isNotEmpty && mounted) {
          _handleSharedFiles(value.map((f) => f.value!).toList());
        }
      },
      onError: (err) {
        debugPrint("getIntentDataStream error: $err");
      },
    );

    FlutterSharingIntent.instance.getInitialSharing().then((
      List<SharedFile> value,
    ) {
      if (value.isNotEmpty && mounted) {
        _handleSharedFiles(value.map((f) => f.value!).toList());
      }
    });
  }

  @override
  void dispose() {
    _pairingRequestSub?.cancel();
    _notificationSub?.cancel();
    _sharingSub?.cancel();
    super.dispose();
  }

  void _handleSharedFiles(List<String> files) {
    if (files.isEmpty) return;
    final store = TeleportScope.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SharedPeerSheet(
        state: store.state,
        peers: store.peers,
        files: files,
        onSent: () {
          // Callback
        },
      ),
    );
  }

  void _showIncomingPairingRequest(InboundPair pair, TeleportStore store) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => IncomingPairingSheet(
        pair: pair,
        onRespond: (reaction) async {
          Navigator.pop(ctx);
          try {
            await pair.react(reaction: reaction);

            // Trigger refresh in store
            await store.refreshPeers();

            if (reaction == UIPairReaction.accept) {
              _showSnackBar("Device paired successfully");
            } else if (reaction == UIPairReaction.wrongPairingCode) {
              if (mounted) {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
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
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text("OK"),
                      ),
                    ],
                  ),
                );
              }
            }
          } catch (e) {
            _showSnackBar("Error during pairing: $e", isError: true);
          }
        },
      ),
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

  Future<void> _selectTargetDirectory(TeleportStore store) async {
    String? target = await FilePicker.platform.getDirectoryPath(
      dialogTitle: "Select download folder",
    );

    if (target != null && target != "/") {
      await store.setTargetDir(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = TeleportScope.of(context);

    if (store.isOnboarding) {
      return OnboardingPage(
        state: store.state,
        onComplete: () async {
          await store.refreshPeers();
          await store.setTargetDir((await store.state.getTargetDir())!);
        },
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Teleport"),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.send), text: "Send"),
              Tab(icon: Icon(Icons.link), text: "Pair"),
            ],
          ),
          actions: [
            if (store.targetDir != null)
              IconButton(
                icon: const Icon(Icons.folder_open),
                tooltip: store.targetDir,
                onPressed: () => _selectTargetDirectory(store),
              ),
          ],
        ),
        body: const TabBarView(children: [SendPage(), PairingTab()]),
      ),
    );
  }
}
