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
    String clean(dynamic v) {
      final raw = (v ?? '').toString().trim();
      final lower = raw.toLowerCase();
      if (lower == 'null' || lower == 'undefined') return '';
      return raw;
    }

    String normalizeForMatch(String s) {
      var out = s.trim().toLowerCase();
      if (out.isEmpty) return '';
      out = out
          .replaceAll(RegExp(r'[áàäâ]'), 'a')
          .replaceAll(RegExp(r'[éèëê]'), 'e')
          .replaceAll(RegExp(r'[íìïî]'), 'i')
          .replaceAll(RegExp(r'[óòöô]'), 'o')
          .replaceAll(RegExp(r'[úùüû]'), 'u')
          .replaceAll('ñ', 'n');
      out = out.replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
      out = out.replaceAll(RegExp(r'\s+'), ' ').trim();
      return out;
    }

    final packageName = clean(notificationData['packageName']);
    final notificationPackage = clean(notification['packageName'] ?? notification['paquete']);
    if (packageName.isNotEmpty && notificationPackage != packageName) {
      return false;
    }

    // Verificar título si está configurado
    final configTitle = clean(notificationData['title'] ?? notificationData['titulo']);
    if (configTitle.isNotEmpty) {
      final notificationTitle = clean(notification['title'] ?? notification['titulo']);
      final cfg = normalizeForMatch(configTitle);
      final cur = normalizeForMatch(notificationTitle);
      if (cfg.isNotEmpty && !cur.contains(cfg)) {
        return false;
      }
    }

    // Verificar contenido si está configurado
    final configText = clean(notificationData['text'] ??
        notificationData['body'] ??
        notificationData['bigText'] ??
        notificationData['mensaje'] ??
        notificationData['contenido']);
    if (configText.isNotEmpty) {
      final notificationText = clean(notification['text'] ??
          notification['body'] ??
          notification['bigText'] ??
          notification['mensaje'] ??
          notification['contenido']);
      final cfg = normalizeForMatch(configText);
      final cur = normalizeForMatch(notificationText);
      if (cfg.isNotEmpty && !cur.contains(cfg)) {
        return false;
      }
    }

    // Verificar información adicional si está configurada
    final configExtras = notificationData['extras'];
    if (configExtras != null && configExtras is Map) {
      final notificationExtrasRaw = notification['extras'];
      if (notificationExtrasRaw is! Map) return false;
      final notificationExtras = Map<String, dynamic>.from(notificationExtrasRaw);
      final extras = Map<String, dynamic>.from(configExtras);
      for (final key in extras.keys) {
        final expected = extras[key];
        if (expected == null) continue;
        final actual = notificationExtras[key];
        if (actual == null) return false;
        if (expected is num || expected is bool) {
          if (actual != expected) return false;
          continue;
        }
        final expectedStr = clean(expected);
        final actualStr = clean(actual);
        if (expectedStr.isNotEmpty && actualStr != expectedStr) {
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
    String clean(dynamic v) {
      final raw = (v ?? '').toString().trim();
      final lower = raw.toLowerCase();
      if (lower == 'null' || lower == 'undefined') return '';
      return raw;
    }

    final Map<String, dynamic> data = {
      'packageName': clean(originalNotification['packageName'] ?? originalNotification['paquete']),
    };

    if (titleSelected) {
      data['title'] = clean(originalNotification['title'] ?? originalNotification['titulo']);
    }

    if (textSelected) {
      data['text'] = clean(originalNotification['text'] ??
          originalNotification['body'] ??
          originalNotification['bigText'] ??
          originalNotification['mensaje'] ??
          originalNotification['contenido']);
    }

    if (extrasSelected) {
      final raw = originalNotification['extras'];
      data['extras'] = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    }

    return data;
  }

  bool get hasSelection => titleSelected || textSelected || extrasSelected;
}
