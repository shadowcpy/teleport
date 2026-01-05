import 'dart:io';
import 'package:teleport/core/services/background_service.dart';
import 'package:teleport/core/services/notification_service.dart';
import 'package:teleport/src/rust/api/teleport.dart';

class FileSender {
  static Future<void> sendFile({
    required AppState state,
    required String peer,
    required String name,
    required SendFileSource source,
    Function(double, BigInt, BigInt)? onProgress,
    required Function(String) onError,
    required Function() onDone,
  }) async {
    try {
      final progress = state.sendFile(peer: peer, name: name, source: source);

      progress.listen((event) {
        event.when(
          progress: (offset, size) {
            double percent = 0.0;
            if (size > BigInt.zero) {
              percent = offset.toDouble() / size.toDouble();
            }
            onProgress?.call(percent, offset, size);

            // Update Background Notification
            if (Platform.isAndroid) {
              BackgroundService().updateNotification(
                title: "Sending $name",
                text: "${(percent * 100).toStringAsFixed(0)}%",
              );
            }
          },
          done: () {
            // Reset Background Notification
            if (Platform.isAndroid) {
              BackgroundService().updateNotification(
                title: "Teleport is running",
                text: "Ready to receive files",
              );
            }
            // Show Local Notification
            NotificationService().showFileSent(name);
            onDone();
          },
          error: (msg) {
            // Update Background Notification
            if (Platform.isAndroid) {
              BackgroundService().updateNotification(
                title: "Send Failed",
                text: "$name: $msg",
              );
            }
            NotificationService().showError(name, "Send failed: $msg");
            onError(msg);
          },
        );
      });
    } catch (e) {
      onError(e.toString());
    }
  }
}
