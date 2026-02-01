import 'dart:io';
import 'package:teleport/core/services/notification_service.dart';
import 'package:teleport/src/rust/api/teleport.dart';

class FileSender {
  static Future<void> sendFile({
    required AppState state,
    required String peer,
    required String name,
    required SendFileSource source,
    Function(double, BigInt, BigInt, double)? onProgress,
    required Function(String) onError,
    required Function() onDone,
  }) async {
    try {
      final progress = state.sendFile(peer: peer, name: name, source: source);
      int lastUpdateMs = 0;
      int? lastPercent;
      final progressId = _notificationIdForSend(peer, name);

      progress.listen((event) {
        event.when(
          progress: (offset, size, bytesPerSecond) {
            double percent = 0.0;
            if (size > BigInt.zero) {
              percent = offset.toDouble() / size.toDouble();
            }
            onProgress?.call(percent, offset, size, bytesPerSecond);

            if (Platform.isAndroid) {
              final percentInt = (percent * 100).toInt().clamp(0, 100);
              final nowMs = DateTime.now().millisecondsSinceEpoch;
              if (_shouldUpdateNotification(
                lastPercent,
                percentInt,
                lastUpdateMs,
                nowMs,
              )) {
                lastUpdateMs = nowMs;
                lastPercent = percentInt;
                NotificationService().showTransferProgress(
                  id: progressId,
                  title: "Sending $name",
                  body: "$percentInt%",
                  progress: percentInt,
                );
              }
            }
          },
          done: () {
            // Show Local Notification
            NotificationService().cancelTransferProgress(progressId);
            NotificationService().showFileSent(name);
            onDone();
          },
          error: (msg) {
            NotificationService().cancelTransferProgress(progressId);
            NotificationService().showError(name, "Send failed: $msg");
            onError(msg);
          },
        );
      });
    } catch (e) {
      onError(e.toString());
    }
  }

  static bool _shouldUpdateNotification(
    int? lastPercent,
    int percent,
    int lastMs,
    int nowMs,
  ) {
    if (lastPercent == null) return true;
    if (percent == 100) return true;
    if (nowMs - lastMs >= 1000 && percent != lastPercent) return true;
    if ((percent - lastPercent).abs() >= 5 && nowMs - lastMs >= 500) {
      return true;
    }
    return false;
  }

  static int _notificationIdForSend(String peer, String name) {
    return "send:$peer/$name".hashCode & 0x7fffffff;
  }
}
