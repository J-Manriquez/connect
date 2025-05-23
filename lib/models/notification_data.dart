import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationData {
  final String id;
  final String title;
  final String text;
  final String packageName;
  final String appName;
  final DateTime timestamp;
  final Map<String, dynamic> extras;

  NotificationData({
    required this.id,
    required this.title,
    required this.text,
    required this.packageName,
    required this.appName,
    required this.timestamp,
    required this.extras,
  });

  factory NotificationData.fromMap(Map<String, dynamic> map) {
    return NotificationData(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      text: map['text'] ?? '',
      packageName: map['packageName'] ?? '',
      appName: map['appName'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      extras: Map<String, dynamic>.from(map['extras'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'text': text,
      'packageName': packageName,
      'appName': appName,
      'timestamp': Timestamp.fromDate(timestamp),
      'extras': extras,
    };
  }

  factory NotificationData.fromNotificationMap(Map<String, dynamic> notification) {
    final DateTime now = DateTime.now();
    final String uniqueId = '${now.hour}${now.minute}${now.second}_${_generateRandomCode()}';
    
    return NotificationData(
      id: uniqueId,
      title: notification['title'] ?? '',
      text: notification['text'] ?? '',
      packageName: notification['packageName'] ?? '',
      appName: notification['appName'] ?? '',
      timestamp: now,
      extras: Map<String, dynamic>.from(notification['extras'] ?? {}),
    );
  }
  
  static String _generateRandomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    String result = '';
    for (int i = 0; i < 4; i++) {
      result += chars[DateTime.now().microsecond % chars.length];
    }
    return result;
  }
}