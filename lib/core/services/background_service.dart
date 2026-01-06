import 'dart:io';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

class BackgroundService {
  static final BackgroundService _instance = BackgroundService._internal();

  factory BackgroundService() => _instance;

  BackgroundService._internal();

  Future<void> init() async {
    if (!Platform.isAndroid) return;

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'teleport_service',
        channelName: 'Teleport Background Service',
        channelDescription: 'Keeps Teleport running for file transfers.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  Future<void> startService() async {
    if (!Platform.isAndroid) return;

    if (await FlutterForegroundTask.isRunningService) {
      return;
    }

    await FlutterForegroundTask.startService(
      serviceId: 1665,
      serviceTypes: [ForegroundServiceTypes.remoteMessaging],
      notificationTitle: 'Teleport is running',
      notificationText: 'Ready to receive files',
      callback: startCallback,
    );
  }
}

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(MyTaskHandler());
}

class MyTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // No-op: The service is just to keep the isolate alive.
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // No-op
  }
  @override
  Future<void> onDestroy(DateTime timestamp, bool what) async {
    // No-op
  }
}
