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
      initializationSettings,
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
      DateTime.now().millisecond, // Unique ID
      'File Received',
      filename,
      platformDetails,
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
      DateTime.now().millisecond, // Unique ID
      'Transfer Failed',
      '$filename: $errorMessage',
      platformDetails,
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
      DateTime.now().millisecond,
      'File Sent',
      filename,
      platformDetails,
    );
  }
}
