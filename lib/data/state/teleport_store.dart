import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:teleport/src/rust/api/teleport.dart';
import 'package:teleport/src/rust/lib.dart';
import 'package:teleport/core/services/background_service.dart';
import 'package:teleport/core/services/notification_service.dart';

class TeleportStore extends ChangeNotifier {
  final AppState state;
  final bool isAndroid;

  // State
  List<(String, String)> _peers = [];
  final HashMap<String, UIConnectionQuality> _connQuality = HashMap();
  String? _pairingInfo;
  String? _targetDir;
  final Map<String, (BigInt, BigInt)> _downloadProgress = {};

  // Getters
  List<(String, String)> get peers => List.unmodifiable(_peers);
  Map<String, UIConnectionQuality> get connQuality =>
      Map.unmodifiable(_connQuality);
  String? get pairingInfo => _pairingInfo;
  String? get targetDir => _targetDir;
  Map<String, (BigInt, BigInt)> get downloadProgress =>
      Map.unmodifiable(_downloadProgress);
  bool get isOnboarding => _targetDir == null;

  // Subscriptions
  StreamSubscription? _pairingSub;
  StreamSubscription? _fileSub;
  StreamSubscription? _qualitySub;

  TeleportStore({required this.state, required this.isAndroid}) {
    _init();
  }

  Future<void> _init() async {
    await _refreshData();
    _subscribe();
  }

  Future<void> _refreshData() async {
    _peers = await state.peers();
    _pairingInfo = await state.getAddr();
    _targetDir = await state.getTargetDir();
    notifyListeners();
  }

  void _subscribe() {
    _pairingSub = state.pairingSubscription().listen(_handlePairingRequest);
    _fileSub = state.fileSubscription().listen(_handleFileEvent);
    _qualitySub = state.connQualitySubscription().listen(_handleQualityEvent);
  }

  @override
  void dispose() {
    _pairingSub?.cancel();
    _fileSub?.cancel();
    _qualitySub?.cancel();
    super.dispose();
  }

  // --- Handling Events ---

  void _handlePairingRequest(InboundPair pair) {
    // We will expose a stream or callback for UI to handle this interactive event
    // Ideally, we use a global event bus or a ValueNotifier for "current dialog"
    // For now, let's expose specific streams for UI events that need user interaction
    _pairingRequestController.add(pair);
  }

  final StreamController<InboundPair> _pairingRequestController =
      StreamController.broadcast();
  Stream<InboundPair> get pairingRequests => _pairingRequestController.stream;

  final StreamController<({String name, String type})> _notificationController =
      StreamController.broadcast();
  Stream<({String name, String type})> get notifications =>
      _notificationController.stream;

  void _handleFileEvent(InboundFileEvent event) {
    final key = "${event.peer}/${event.name}";

    event.event.when(
      progress: (offset, size) {
        _downloadProgress[key] = (offset, size);
        notifyListeners();

        if (isAndroid) {
          final percent = ((offset / size) * 100).toInt();
          BackgroundService().updateNotification(
            title: "Downloading ${event.name}",
            text: "$percent%",
          );
        }
      },
      done: (path, name) async {
        _downloadProgress.remove(key);
        notifyListeners();

        if (isAndroid) {
          BackgroundService().updateNotification(
            title: "Teleport is running",
            text: "Ready to receive files",
          );
        }

        if (_targetDir != null) {
          try {
            final tempFile = File(path);
            final destPath = "$_targetDir/$name";
            await tempFile.copy(destPath);
            await tempFile.delete();

            NotificationService().showFileReceived(destPath, name);
            _notificationController.add((
              name: "Received $name",
              type: 'success',
            ));
          } catch (e) {
            _notificationController.add((
              name: "Error saving $name: $e",
              type: 'error',
            ));
          }
        }
      },
      error: (msg) {
        _downloadProgress.remove(key);
        notifyListeners();

        NotificationService().showError(event.name, msg);
        if (isAndroid) {
          BackgroundService().updateNotification(
            title: "Transfer Failed",
            text: msg,
          );
        }
        _notificationController.add((
          name: "Error receiving ${event.name}: $msg",
          type: 'error',
        ));
      },
    );
  }

  void _handleQualityEvent(UIConnectionQualityUpdate event) {
    _connQuality[event.peer] = event.quality;
    notifyListeners();
  }

  // --- Public Methods ---

  Future<void> setTargetDir(String path) async {
    await state.setTargetDir(dir: path);
    _targetDir = path;
    notifyListeners();
  }

  Future<void> refreshPeers() async {
    _peers = await state.peers();
    notifyListeners();
  }

  Future<PairingResponse> pairWith({
    required String info,
    required U8Array6 pairingCode,
  }) {
    return state.pairWith(info: info, pairingCode: pairingCode);
  }
}

class TeleportScope extends InheritedNotifier<TeleportStore> {
  const TeleportScope({
    super.key,
    required TeleportStore notifier,
    required super.child,
  }) : super(notifier: notifier);

  static TeleportStore of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<TeleportScope>()!
        .notifier!;
  }
}
