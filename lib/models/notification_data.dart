import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationData {
  final String id;
  final String title;
  final String text;
  final String packageName;
  final String appName;
  final DateTime timestamp;
  final Map<String, dynamic> extras;
  final bool statusVisualizacion; // Nuevo campo para el estado de visualización

  NotificationData({
    required this.id,
    required this.title,
    required this.text,
    required this.packageName,
    required this.appName,
    required this.timestamp,
    required this.extras,
    this.statusVisualizacion = false, // Valor por defecto: false
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
      statusVisualizacion: map['status-visualizacion'] ?? false, // Leer el campo desde el mapa
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
      'status-visualizacion': statusVisualizacion, // Guardar el campo en el mapa
    };
  }

  factory NotificationData.fromNotificationMap(Map<String, dynamic> notification) {
    final DateTime now = DateTime.now();
    // Usar el timestamp como ID en formato de milisegundos desde la época
    final String uniqueId = now.millisecondsSinceEpoch.toString();
    
    return NotificationData(
      id: uniqueId,
      title: notification['title'] ?? '',
      text: notification['text'] ?? '',
      packageName: notification['packageName'] ?? '',
      appName: notification['appName'] ?? '',
      timestamp: now,
      extras: Map<String, dynamic>.from(notification['extras'] ?? {}),
      statusVisualizacion: false, // Siempre inicializar como false para nuevas notificaciones
    );
  }
  
  // Método para crear una copia de la notificación con el estado de visualización actualizado
  NotificationData copyWithVisualizacion(bool visualizado) {
    return NotificationData(
      id: id,
      title: title,
      text: text,
      packageName: packageName,
      appName: appName,
      timestamp: timestamp,
      extras: extras,
      statusVisualizacion: visualizado,
    );
  }
}