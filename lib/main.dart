import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sharing_intent/model/sharing_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'package:teleport/onboarding_page.dart';
import 'package:teleport/pairing.dart';
import 'package:teleport/src/rust/api/teleport.dart';
import 'package:teleport/src/rust/frb_generated.dart';
import 'package:teleport/send_page.dart';
import 'package:teleport/incoming_pairing_sheet.dart';
import 'package:teleport/background_service.dart';
import 'package:teleport/notifications.dart';
import 'package:teleport/shared_peer_sheet.dart';
import 'package:flutter_sharing_intent/flutter_sharing_intent.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();

  if (!Platform.isAndroid) {
    await windowManager.ensureInitialized();
  } else {
    await BackgroundService().init();
    await BackgroundService().startService();
  }

  await NotificationService().init();

  final persistentDirectory = await getApplicationDocumentsDirectory();
  final tempDirectory = await getApplicationCacheDirectory();

  final state = await AppState.init(
    persistenceDir: persistentDirectory.path,
    tempDir: tempDirectory.path,
  );

  runApp(TeleportApp(state: state));
}

class TeleportApp extends StatelessWidget {
  final AppState state;
  const TeleportApp({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Teleport',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      home: HomePage(state: state),
    );
  }
}

class HomePage extends StatefulWidget {
  final AppState state;
  const HomePage({super.key, required this.state});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TrayListener, WindowListener {
  // State variables
  List<(String, String)> _peers = [];
  HashMap<String, UIConnectionQuality> _connQuality = HashMap();
  String? _pairingInfo;
  String? _targetDir;
  final Map<String, (BigInt, BigInt)> _downloadProgress =
      {}; // Key: "$peer/$filename"
  bool _isOnboarding = false;

  // Stream Subscriptions for cleanup
  StreamSubscription? _pairingSub;
  StreamSubscription? _fileSub;
  StreamSubscription? _qualitySub;

  @override
  void initState() {
    super.initState();
    _initDesktopIntegration();
    _initTeleportCore();
  }

  @override
  void dispose() {
    _pairingSub?.cancel();
    _fileSub?.cancel();
    _qualitySub?.cancel();
    if (!Platform.isAndroid) {
      trayManager.removeListener(this);
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  // --- Initialization Logic ---

  Future<void> _initDesktopIntegration() async {
    if (Platform.isAndroid) return;

    trayManager.addListener(this);
    windowManager.addListener(this);

    await windowManager.setPreventClose(true);
    await trayManager.setIcon(
      Platform.isWindows ? 'images/tray_icon.ico' : 'images/tray_icon.png',
    );
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: 'toggle', label: 'Show/Hide'),
          MenuItem.separator(),
          MenuItem(key: 'quit', label: 'Quit'),
        ],
      ),
    );
  }

  Future<void> _initTeleportCore() async {
    // 1. Initial Data Fetch
    final peers = await widget.state.peers();
    final pairingInfo = await widget.state.getAddr();
    final targetDir = await widget.state.getTargetDir();

    if (!mounted) return;

    setState(() {
      _peers = peers;
      _pairingInfo = pairingInfo;
      _targetDir = targetDir;
    });

    // 2. Onboarding Check
    if (_targetDir == null) {
      if (mounted) setState(() => _isOnboarding = true);
    }

    // 3. Subscribe to Pairing Requests
    _pairingSub = widget.state.pairingSubscription().listen((pair) {
      if (!mounted) return;
      _showIncomingPairingRequest(pair);
    });

    // 4. Subscribe to Incoming Files
    _fileSub = widget.state.fileSubscription().listen((event) async {
      final key = "${event.peer}/${event.name}";

      event.event.when(
        progress: (offset, size) {
          if (mounted) {
            setState(() {
              _downloadProgress[key] = (offset, size);
            });
          }
          // Update Background Notification
          if (Platform.isAndroid) {
            final percent = ((offset / size) * 100).toInt();
            BackgroundService().updateNotification(
              title: "Downloading ${event.name}",
              text: "$percent%",
            );
          }
        },
        done: (path, name) async {
          if (mounted) {
            setState(() {
              _downloadProgress.remove(key);
            });
          }

          // Reset Background Notification
          if (Platform.isAndroid) {
            BackgroundService().updateNotification(
              title: "Teleport is running",
              text: "Ready to receive files",
            );
          }

          if (_targetDir == null) return;

          try {
            final tempFile = File(path);
            final destPath = "$_targetDir/$name";
            await tempFile.copy(destPath);
            await tempFile.delete(); // Cleanup temp

            // Show Local Notification
            NotificationService().showFileReceived(destPath, name);

            if (mounted) {
              _showSnackBar(
                "Received: $name from ${event.name}",
                isError: false,
              );
            }
          } catch (e) {
            if (mounted) {
              _showSnackBar("Error saving $name: $e", isError: true);
            }
          }
        },
        error: (msg) {
          if (mounted) {
            setState(() {
              _downloadProgress.remove(key);
            });
            _showSnackBar("Error receiving ${event.name}: $msg", isError: true);
          }

          // Show Error Notification
          NotificationService().showError(event.name, msg);

          // Update Background Notification to Error
          if (Platform.isAndroid) {
            BackgroundService().updateNotification(
              title: "Transfer Failed",
              text: msg,
            );
          }
        },
      );
    });

    _qualitySub = widget.state.connQualitySubscription().listen((event) {
      setState(() {
        _connQuality[event.peer] = event.quality;
      });
    });

    // 6. Subscribe to Share Intents
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

    // Get initial share intent
    FlutterSharingIntent.instance.getInitialSharing().then((
      List<SharedFile> value,
    ) {
      if (value.isNotEmpty && mounted) {
        _handleSharedFiles(value.map((f) => f.value!).toList());
      }
    });
  }

  void _handleSharedFiles(List<String> files) {
    if (files.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SharedPeerSheet(
        state: widget.state,
        peers: _peers,
        files: files,
        onSent: () {
          // Callback after sending started (and before minimize)
        },
      ),
    );
  }

  Future<void> _selectTargetDirectory() async {
    String? target = await FilePicker.platform.getDirectoryPath(
      dialogTitle: "Select download folder",
    );

    if (target != null && target != "/") {
      await widget.state.setTargetDir(dir: target);
      setState(() => _targetDir = target);
    }
  }

  // --- UI Action Handlers ---

  void _showIncomingPairingRequest(InboundPair pair) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => IncomingPairingSheet(
        pair: pair,
        onRespond: (reaction) async {
          Navigator.pop(ctx);
          try {
            await pair.react(reaction: reaction);

            // Refresh address info (secret rotation)
            final newInfo = await widget.state.getAddr();
            if (mounted) setState(() => _pairingInfo = newInfo);

            if (reaction == UIPairReaction.accept) {
              final newPeers = await widget.state.peers();
              if (mounted) {
                setState(() => _peers = newPeers);
                _showSnackBar("Device paired successfully");
              }
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
            if (mounted) {
              _showSnackBar("Error during pairing: $e", isError: true);
            }
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

  // --- Build Method ---

  @override
  Widget build(BuildContext context) {
    if (_isOnboarding) {
      return OnboardingPage(
        state: widget.state,
        onComplete: () async {
          // Refresh state after onboarding
          final newTarget = await widget.state.getTargetDir();
          final newPeers = await widget.state.peers();
          if (mounted) {
            setState(() {
              _isOnboarding = false;
              _targetDir = newTarget;
              _peers = newPeers;
            });
          }
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
            if (_targetDir != null)
              IconButton(
                icon: const Icon(Icons.folder_open),
                tooltip: _targetDir,
                onPressed: _selectTargetDirectory,
              ),
          ],
        ),
        body: TabBarView(
          children: [
            SendPage(
              state: widget.state,
              peers: _peers,
              downloadProgress: _downloadProgress,
              connQuality: _connQuality,
            ),
            PairingTab(
              state: widget.state,
              pairingInfo: _pairingInfo,
              onPeersUpdated: () async {
                final newPeers = await widget.state.peers();
                if (mounted) setState(() => _peers = newPeers);
                _showSnackBar("Successfully paired!");
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- Tray & Window Listeners (Desktop) ---

  @override
  void onTrayIconMouseDown() => _toggleWindow();

  @override
  void onTrayIconRightMouseDown() => trayManager.popUpContextMenu();

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    switch (menuItem.key) {
      case 'toggle':
        await _toggleWindow();
        break;
      case 'quit':
        await windowManager.setPreventClose(false);
        await trayManager.destroy();
        await windowManager.destroy();
        break;
    }
  }

  @override
  void onWindowClose() async {
    final prevent = await windowManager.isPreventClose();
    if (prevent) await windowManager.hide();
  }

  Future<void> _toggleWindow() async {
    if (await windowManager.isVisible()) {
      await windowManager.hide();
    } else {
      await windowManager.show();
      await windowManager.focus();
    }
  }
}
