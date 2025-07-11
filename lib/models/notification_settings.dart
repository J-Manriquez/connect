import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationSettings {
  final String id;
  final Map<String, dynamic> notificationData;
  final Map<String, dynamic> additionalData;
  final bool vibrationEnabled;
  final bool bloqueado;
  final bool soundEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  NotificationSettings({
    required this.id,
    required this.notificationData,
    required this.additionalData,
    this.vibrationEnabled = false,
    this.bloqueado = false,
    this.soundEnabled = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory NotificationSettings.fromMap(Map<String, dynamic> map, String documentId) {
    return NotificationSettings(
      id: documentId,
      notificationData: Map<String, dynamic>.from(map['notificationData'] ?? {}),
      additionalData: Map<String, dynamic>.from(map['additionalData'] ?? {}),
      vibrationEnabled: map['vibrationEnabled'] ?? false,
      bloqueado: map['bloqueado'] ?? false,
      soundEnabled: map['soundEnabled'] ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'notificationData': notificationData,
      'additionalData': additionalData,
      'vibrationEnabled': vibrationEnabled,
      'bloqueado': bloqueado,
      'soundEnabled': soundEnabled,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  // Método para crear una nueva configuración
  factory NotificationSettings.create({
    required Map<String, dynamic> notificationData,
    Map<String, dynamic>? additionalData,
    bool vibrationEnabled = false,
    bool bloqueado = false,
    bool soundEnabled = false,
  }) {
    final now = DateTime.now();
    return NotificationSettings(
      id: now.millisecondsSinceEpoch.toString(),
      notificationData: notificationData,
      additionalData: additionalData ?? {},
      vibrationEnabled: vibrationEnabled,
      bloqueado: bloqueado,
      soundEnabled: soundEnabled,
      createdAt: now,
      updatedAt: now,
    );
  }

  // Método para actualizar la configuración
  NotificationSettings copyWith({
    Map<String, dynamic>? notificationData,
    Map<String, dynamic>? additionalData,
    bool? vibrationEnabled,
    bool? bloqueado,
    bool? soundEnabled,
  }) {
    return NotificationSettings(
      id: id,
      notificationData: notificationData ?? this.notificationData,
      additionalData: additionalData ?? this.additionalData,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      bloqueado: bloqueado ?? this.bloqueado,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  // Método para verificar si una notificación coincide con esta configuración
  bool matchesNotification(Map<String, dynamic> notification) {
    final packageName = notificationData['packageName'];
    if (packageName != null && notification['packageName'] != packageName) {
      return false;
    }

    // Verificar título si está configurado
    final configTitle = notificationData['title'];
    if (configTitle != null && configTitle.isNotEmpty) {
      final notificationTitle = notification['title'] ?? '';
      if (!notificationTitle.toLowerCase().contains(configTitle.toLowerCase())) {
        return false;
      }
    }

    // Verificar contenido si está configurado
    final configText = notificationData['text'];
    if (configText != null && configText.isNotEmpty) {
      final notificationText = notification['text'] ?? '';
      if (!notificationText.toLowerCase().contains(configText.toLowerCase())) {
        return false;
      }
    }

    // Verificar información adicional si está configurada
    final configExtras = notificationData['extras'];
    if (configExtras != null && configExtras is Map) {
      final notificationExtras = notification['extras'] ?? {};
      for (final key in configExtras.keys) {
        if (configExtras[key] != null && 
            notificationExtras[key] != configExtras[key]) {
          return false;
        }
      }
    }

    return true;
  }

  @override
  String toString() {
    return 'NotificationSettings(id: $id, bloqueado: $bloqueado, vibrationEnabled: $vibrationEnabled, soundEnabled: $soundEnabled)';
  }
}

// Clase para los datos de configuración seleccionados por el usuario
class NotificationConfigSelection {
  final bool titleSelected;
  final bool textSelected;
  final bool extrasSelected;
  final Map<String, dynamic> originalNotification;

  NotificationConfigSelection({
    required this.titleSelected,
    required this.textSelected,
    required this.extrasSelected,
    required this.originalNotification,
  });

  // Método para generar los datos de notificación basados en la selección
  Map<String, dynamic> generateNotificationData() {
    final Map<String, dynamic> data = {
      'packageName': originalNotification['packageName'],
    };

    if (titleSelected) {
      data['title'] = originalNotification['title'] ?? '';
    }

    if (textSelected) {
      data['text'] = originalNotification['text'] ?? '';
    }

    if (extrasSelected) {
      data['extras'] = originalNotification['extras'] ?? {};
    }

    return data;
  }

  bool get hasSelection => titleSelected || textSelected || extrasSelected;
}