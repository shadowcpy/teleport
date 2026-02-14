import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:teleport/src/rust/api/teleport.dart';
import 'package:teleport/src/rust/lib.dart';
import 'package:teleport/core/services/notification_service.dart';

class TransferProgress {
  final String peer;
  final String name;
  BigInt offset;
  BigInt size;
  double bytesPerSecond;

  TransferProgress({
    required this.peer,
    required this.name,
    BigInt? offset,
    BigInt? size,
    this.bytesPerSecond = 0.0,
  }) : offset = offset ?? BigInt.zero,
       size = size ?? BigInt.zero;

  void update(BigInt newOffset, BigInt newSize, double newBytesPerSecond) {
    offset = newOffset;
    size = newSize;
    bytesPerSecond = newBytesPerSecond;
  }
}

class TeleportStore extends ChangeNotifier {
  final AppState state;
  final bool isAndroid;

  // State
  List<(String, String)> _peers = [];
  final HashMap<String, UIConnectionQuality> _connQuality = HashMap();
  String? _pairingInfo;
  String? _targetDir;
  final Map<String, TransferProgress> _downloadProgress = {};
  final Map<String, TransferProgress> _uploadProgress = {};

  // Getters
  List<(String, String)> get peers => List.unmodifiable(_peers);
  Map<String, UIConnectionQuality> get connQuality =>
      Map.unmodifiable(_connQuality);
  String? get pairingInfo => _pairingInfo;
  String? get targetDir => _targetDir;
  Map<String, TransferProgress> get downloadProgress =>
      Map.unmodifiable(_downloadProgress);
  Map<String, TransferProgress> get uploadProgress =>
      Map.unmodifiable(_uploadProgress);
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

  Future<void> _handlePairingRequest(InboundPair pair) async {
    // We will expose a stream or callback for UI to handle this interactive event
    // Ideally, we use a global event bus or a ValueNotifier for "current dialog"
    // For now, let's expose specific streams for UI events that need user interaction
    _pairingRequestController.add(pair);
    try {
      _pairingInfo = await state.getAddr();
      notifyListeners();
    } catch (_) {}
  }

  final StreamController<InboundPair> _pairingRequestController =
      StreamController.broadcast();
  Stream<InboundPair> get pairingRequests => _pairingRequestController.stream;

  final StreamController<({String name, String type})> _notificationController =
      StreamController.broadcast();
  Stream<({String name, String type})> get notifications =>
      _notificationController.stream;

  void _handleFileEvent(InboundFileEvent event) {
    final key = "${event.peer}/${event.fileName}";
    final notificationId = key.hashCode & 0x7fffffff;

    event.event.when(
      progress: (offset, size, bytesPerSecond) {
        final current =
            _downloadProgress[key] ??
            TransferProgress(peer: event.peer, name: event.fileName);
        current.update(offset, size, bytesPerSecond);
        _downloadProgress[key] = current;
        notifyListeners();

        if (isAndroid) {
          final percent = size == BigInt.zero
              ? 0
              : ((offset / size) * 100).toInt().clamp(0, 100);

          NotificationService().updateTransferProgress(
            id: notificationId,
            title: "Downloading ${event.fileName}",
            body: "$percent%",
            progress: percent,
          );
        }
      },
      done: (path, name) async {
        _downloadProgress.remove(key);
        NotificationService().cancelTransferProgress(notificationId);
        notifyListeners();

        NotificationService().showFileReceived(path, name);
        _notificationController.add((name: "Received $name", type: 'success'));
      },
      error: (msg) {
        _downloadProgress.remove(key);
        NotificationService().cancelTransferProgress(notificationId);
        notifyListeners();

        NotificationService().showError(event.fileName, msg);

        _notificationController.add((
          name: "Error receiving ${event.fileName}: $msg",
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

  Future<void> sendFile({
    required String peer,
    required String path,
    required String name,
    void Function()? onDone,
    void Function(String)? onError,
  }) async {
    return sendFileWithSource(
      peer: peer,
      name: name,
      source: SendFileSource.path(path),
      onDone: onDone,
      onError: onError,
    );
  }

  Future<void> sendFileWithSource({
    required String peer,
    required String name,
    required SendFileSource source,
    void Function()? onDone,
    void Function(String)? onError,
  }) async {
    final id = _transferId(peer, name);
    // Unique ID for notifications based on the transfer ID
    final notificationId = id.hashCode & 0x7fffffff;

    _uploadProgress[id] = TransferProgress(peer: peer, name: name);
    notifyListeners();

    try {
      final stream = state.sendFile(peer: peer, name: name, source: source);

      stream.listen((event) {
        event.when(
          progress: (offset, size, bytesPerSecond) {
            final current = _uploadProgress[id];
            if (current != null) {
              current.update(offset, size, bytesPerSecond);
              notifyListeners();

              if (isAndroid && size > BigInt.zero) {
                final percent = ((offset / size) * 100).toInt().clamp(0, 100);
                NotificationService().updateTransferProgress(
                  id: notificationId,
                  title: "Sending $name",
                  body: "$percent%",
                  progress: percent,
                );
              }
            }
          },
          done: () {
            _uploadProgress.remove(id);
            NotificationService().cancelTransferProgress(notificationId);
            NotificationService().showFileSent(name);
            notifyListeners();
            onDone?.call();
          },
          error: (msg) {
            _uploadProgress.remove(id);
            NotificationService().cancelTransferProgress(notificationId);
            NotificationService().showError(name, "Send failed: $msg");
            notifyListeners();
            onError?.call(msg);
          },
        );
      });
    } catch (e) {
      _uploadProgress.remove(id);
      notifyListeners();
      onError?.call(e.toString());
    }
  }

  String _transferId(String peer, String name) {
    return "$peer/$name/${DateTime.now().microsecondsSinceEpoch}";
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
