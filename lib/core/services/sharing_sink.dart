import 'dart:async';
import 'package:flutter/services.dart';

enum SharingItemType { text, url, image, video, file, webSearch, other }

class SharingItem {
  final String value;
  final SharingItemType type;
  final String? mimeType;

  const SharingItem({required this.value, required this.type, this.mimeType});

  factory SharingItem.fromMap(Map<dynamic, dynamic> map) {
    final typeIndex = map["type"];
    final type = typeIndex is int && typeIndex >= 0
        ? SharingItemType.values[typeIndex]
        : SharingItemType.other;
    return SharingItem(
      value: map["value"] as String? ?? "",
      type: type,
      mimeType: map["mimeType"] as String?,
    );
  }
}

class SharingSink {
  static const _events = EventChannel("sharing_sink/events");
  static final SharingSink instance = SharingSink._internal();

  SharingSink._internal();

  Stream<List<SharingItem>>? _stream;

  Stream<List<SharingItem>> get stream {
    _stream ??= _events.receiveBroadcastStream().map((data) {
      if (data is List) {
        return data
            .whereType<Map<dynamic, dynamic>>()
            .map(SharingItem.fromMap)
            .where((item) => item.value.isNotEmpty)
            .toList();
      }
      return const <SharingItem>[];
    });
    return _stream!;
  }
}
