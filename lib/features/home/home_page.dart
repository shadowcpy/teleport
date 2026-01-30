import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:mime/mime.dart';
import 'package:teleport/core/services/sharing_sink.dart';
import 'package:teleport/state/teleport_store.dart';
import 'package:teleport/core/widgets/teleport_background.dart';
import 'package:teleport/features/onboarding/onboarding.dart';
import 'package:teleport/features/pairing/incoming_pairing_sheet.dart';
import 'package:teleport/features/pairing/pairing_tab.dart';
import 'package:teleport/features/send/send_page.dart';
import 'package:teleport/features/settings/settings.dart';
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
  bool _notificationGranted = true;
  bool _ignoresBatteryOptimizations = true;
  static const MethodChannel _platform = MethodChannel('gd.nexus.teleport/app');

  @override
  void initState() {
    super.initState();
    _initListeners();
    _initSharing();
    _refreshBackgroundPermissions();
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
    _sharingSub = SharingSink.instance.stream.listen(
      (items) async {
        if (items.isNotEmpty && mounted) {
          await _handleSharedFiles(items);
        }
      },
      onError: (err) {
        debugPrint("sharing_sink stream error: $err");
      },
    );
  }

  Future<void> _refreshBackgroundPermissions() async {
    if (!Platform.isAndroid) return;
    final notificationStatus =
        await FlutterForegroundTask.checkNotificationPermission();
    final ignoresBattery =
        await FlutterForegroundTask.isIgnoringBatteryOptimizations;
    if (!mounted) return;
    setState(() {
      _notificationGranted =
          notificationStatus == NotificationPermission.granted;
      _ignoresBatteryOptimizations = ignoresBattery;
    });
  }

  @override
  void dispose() {
    _pairingRequestSub?.cancel();
    _notificationSub?.cancel();
    _sharingSub?.cancel();
    super.dispose();
  }

  Future<void> _handleSharedFiles(List<SharingItem> files) async {
    if (files.isEmpty) return;
    final resolved = await _resolveSharedFiles(files);
    if (resolved.isEmpty) {
      _showSnackBar("Unable to access shared files", isError: true);
      return;
    }
    final store = TeleportScope.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SharedPeerSheet(
        store: store,
        files: resolved,
        onSent: () {
          // Callback
        },
      ),
    );
  }

  Future<List<SharedTransfer>> _resolveSharedFiles(
    List<SharingItem> files,
  ) async {
    final resolved = <SharedTransfer>[];
    for (final file in files) {
      final value = file.value;
      if (value.isEmpty) {
        continue;
      }
      if (file.type == SharingItemType.text ||
          file.type == SharingItemType.url ||
          file.type == SharingItemType.webSearch ||
          (file.mimeType?.startsWith("text/") ?? false)) {
        final tempDir = await getApplicationCacheDirectory();
        final name = "shared_text_${DateTime.now().microsecondsSinceEpoch}.txt";
        final tempFile = File("${tempDir.path}/$name");
        await tempFile.writeAsString(value);
        resolved.add(SharedTransfer(name: name, path: tempFile.path));
        continue;
      }
      if (value.startsWith("content://")) {
        try {
          final result = await _platform.invokeMethod<Map<dynamic, dynamic>>(
            "openSharedFd",
            {"uri": value},
          );
          final fd = result?["fd"] as int?;
          final name = result?["name"] as String?;
          if (fd != null) {
            resolved.add(SharedTransfer(name: name ?? "shared_file", fd: fd));
            continue;
          }
        } catch (e) {
          debugPrint("Failed to open shared fd: $e");
        }
      } else {
        final name = value.split('/').last;
        resolved.add(SharedTransfer(name: name, path: value));
      }
    }
    return resolved;
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
            await pair.result();

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

  Future<void> _openSettings() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const Settings()));
    await _refreshBackgroundPermissions();
  }

  Future<void> _openTargetDirectory(TeleportStore store) async {
    final target = store.targetDir;
    if (target == null || target == "/") return;
    final exists = await Directory(target).exists();
    if (!exists) {
      _showSnackBar("Download folder not found", isError: true);
      return;
    }
    final result = await OpenFilex.open(
      target,
      type: lookupMimeType(target) ?? "vnd.android.document/directory",
    );
    if (result.type != ResultType.done) {
      _showSnackBar("Unable to open download folder", isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = TeleportScope.of(context);

    if (store.isOnboarding) {
      return Onboarding(
        state: store.state,
        onComplete: () async {
          await store.refreshPeers();
          await store.setTargetDir((await store.state.getTargetDir())!);
          await _refreshBackgroundPermissions();
        },
      );
    }

    final hasPeers = store.peers.isNotEmpty;
    final isBackgroundReady =
        _notificationGranted && _ignoresBatteryOptimizations;
    final showBackgroundWarning =
        Platform.isAndroid && hasPeers && !isBackgroundReady;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Teleport"),
            const SizedBox(height: 2),
            InkWell(
              onTap: showBackgroundWarning ? _openSettings : null,
              borderRadius: BorderRadius.circular(6),
              child: Text(
                showBackgroundWarning
                    ? "Missing permissions for background service"
                    : hasPeers
                    ? "Ready for background transfers"
                    : "Pair your first device to unlock transfers",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: showBackgroundWarning
                      ? Colors.orange.shade700
                      : Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                  fontWeight: showBackgroundWarning
                      ? FontWeight.w700
                      : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: "Settings",
            onPressed: _openSettings,
          ),
          if (store.targetDir != null && !Platform.isAndroid)
            IconButton(
              icon: const Icon(Icons.folder_open),
              tooltip: store.targetDir,
              onPressed: () => _openTargetDirectory(store),
            ),
        ],
      ),
      body: TeleportBackground(
        padding: hasPeers
            ? const EdgeInsets.symmetric(horizontal: 12, vertical: 12)
            : EdgeInsets.zero,
        child: hasPeers ? const SendPage() : const PairingTab(),
      ),
    );
  }
}
