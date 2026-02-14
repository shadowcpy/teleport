import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mime/mime.dart';
import 'package:open_filex/open_filex.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const LinuxInitializationSettings initializationSettingsLinux =
        LinuxInitializationSettings(defaultActionName: 'Open notification');

    final InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          linux: initializationSettingsLinux,
        );

    await _flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        if (details.payload != null) {
          final path = details.payload!;
          OpenFilex.open(path, type: lookupMimeType(path));
        }
      },
    );
  }

  Future<void> showFileReceived(String path, String filename) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'teleport_files',
          'File Transfers',
          channelDescription: 'Notifications for received files',
          importance: Importance.high,
          priority: Priority.high,
        );

    const LinuxNotificationDetails linuxDetails = LinuxNotificationDetails();

    final NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      linux: linuxDetails,
    );

    await _flutterLocalNotificationsPlugin.show(
      id: DateTime.now().millisecond, // Unique ID
      title: 'File Received',
      body: filename,
      notificationDetails: platformDetails,
      payload: path,
    );
  }

  Future<void> showError(String filename, String errorMessage) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'teleport_errors',
          'Transfer Errors',
          channelDescription: 'Notifications for failed transfers',
          importance: Importance.high,
          priority: Priority.high,
        );

    const LinuxNotificationDetails linuxDetails = LinuxNotificationDetails();

    final NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      linux: linuxDetails,
    );

    await _flutterLocalNotificationsPlugin.show(
      id: DateTime.now().millisecond, // Unique ID
      title: 'Transfer Failed',
      body: '$filename: $errorMessage',
      notificationDetails: platformDetails,
    );
  }

  Future<void> showFileSent(String filename) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'teleport_status',
          'File Status',
          channelDescription: 'Notifications for sent files',
          importance: Importance.low,
          priority: Priority.low,
        );

    const LinuxNotificationDetails linuxDetails = LinuxNotificationDetails();

    final NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      linux: linuxDetails,
    );

    await _flutterLocalNotificationsPlugin.show(
      id: DateTime.now().millisecond,
      title: 'File Sent',
      body: filename,
      notificationDetails: platformDetails,
    );
  }

  final Map<int, int> _lastUpdateMs = {};
  final Map<int, int> _lastUpdatePercent = {};

  Future<void> updateTransferProgress({
    required int id,
    required String title,
    required String body,
    required int progress,
  }) async {
    if (!Platform.isAndroid) return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final lastMs = _lastUpdateMs[id] ?? 0;
    final lastPercent = _lastUpdatePercent[id];

    if (!_shouldUpdate(lastPercent, progress, lastMs, nowMs)) return;

    _lastUpdateMs[id] = nowMs;
    _lastUpdatePercent[id] = progress;

    await showTransferProgress(
      id: id,
      title: title,
      body: body,
      progress: progress,
    );
  }

  bool _shouldUpdate(int? lastPercent, int percent, int lastMs, int nowMs) {
    if (lastPercent == null) return true;
    if (percent == 100) return true;
    if (nowMs - lastMs >= 1000 && percent != lastPercent) return true;
    if ((percent - lastPercent).abs() >= 5 && nowMs - lastMs >= 500) {
      return true;
    }
    return false;
  }

  Future<void> showTransferProgress({
    required int id,
    required String title,
    required String body,
    required int progress,
  }) async {
    if (!Platform.isAndroid) return;

    final androidDetails = AndroidNotificationDetails(
      'teleport_progress',
      'Transfer Progress',
      channelDescription: 'Progress for active transfers',
      importance: Importance.low,
      priority: Priority.low,
      onlyAlertOnce: true,
      ongoing: true,
      showProgress: true,
      maxProgress: 100,
      progress: progress.clamp(0, 100),
    );

    final platformDetails = NotificationDetails(android: androidDetails);

    await _flutterLocalNotificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: platformDetails,
    );
  }

  Future<void> cancelTransferProgress(int id) async {
    _lastUpdateMs.remove(id);
    _lastUpdatePercent.remove(id);
    await _flutterLocalNotificationsPlugin.cancel(id: id);
  }
}
