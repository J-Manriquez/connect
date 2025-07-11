import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connect/models/notification_settings.dart';
import 'package:connect/services/firebase_service.dart';

class NotificationSettingsService {
  final FirebaseService _firebaseService = FirebaseService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Obtener todas las configuraciones de notificaciones para el dispositivo actual
  Future<List<NotificationSettings>> getAllNotificationSettings() async {
    try {
      final deviceId = await _firebaseService.getDeviceId();
      final querySnapshot = await _firestore
          .collection('dispositivos')
          .doc(deviceId)
          .collection('notifSettings')
          .orderBy('updatedAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => NotificationSettings.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print('Error al obtener configuraciones de notificaciones: $e');
      return [];
    }
  }

  // Guardar una nueva configuración de notificación
  Future<bool> saveNotificationSettings(NotificationSettings settings) async {
    try {
      final deviceId = await _firebaseService.getDeviceId();
      await _firestore
          .collection('dispositivos')
          .doc(deviceId)
          .collection('notifSettings')
          .doc(settings.id)
          .set(settings.toMap());

      print('Configuración de notificación guardada: ${settings.id}');
      return true;
    } catch (e) {
      print('Error al guardar configuración de notificación: $e');
      return false;
    }
  }

  // Actualizar una configuración existente
  Future<bool> updateNotificationSettings(NotificationSettings settings) async {
    try {
      final deviceId = await _firebaseService.getDeviceId();
      final updatedSettings = settings.copyWith();
      
      await _firestore
          .collection('dispositivos')
          .doc(deviceId)
          .collection('notifSettings')
          .doc(settings.id)
          .update(updatedSettings.toMap());

      print('Configuración de notificación actualizada: ${settings.id}');
      return true;
    } catch (e) {
      print('Error al actualizar configuración de notificación: $e');
      return false;
    }
  }

  // Eliminar una configuración de notificación
  Future<bool> deleteNotificationSettings(String settingsId) async {
    try {
      final deviceId = await _firebaseService.getDeviceId();
      await _firestore
          .collection('dispositivos')
          .doc(deviceId)
          .collection('notifSettings')
          .doc(settingsId)
          .delete();

      print('Configuración de notificación eliminada: $settingsId');
      return true;
    } catch (e) {
      print('Error al eliminar configuración de notificación: $e');
      return false;
    }
  }

  // Obtener una configuración específica por ID
  Future<NotificationSettings?> getNotificationSettings(String settingsId) async {
    try {
      final deviceId = await _firebaseService.getDeviceId();
      final doc = await _firestore
          .collection('dispositivos')
          .doc(deviceId)
          .collection('notifSettings')
          .doc(settingsId)
          .get();

      if (doc.exists && doc.data() != null) {
        return NotificationSettings.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      print('Error al obtener configuración de notificación: $e');
      return null;
    }
  }

  // Verificar si una notificación debe ser bloqueada
  Future<bool> shouldBlockNotification(Map<String, dynamic> notification) async {
    try {
      final settings = await getAllNotificationSettings();
      
      for (final setting in settings) {
        if (setting.bloqueado && setting.matchesNotification(notification)) {
          print('Notificación bloqueada por configuración: ${setting.id}');
          return true;
        }
      }
      
      return false;
    } catch (e) {
      print('Error al verificar bloqueo de notificación: $e');
      return false;
    }
  }

  // Obtener configuración de vibración personalizada para una notificación
  Future<Map<String, dynamic>?> getCustomVibrationConfig(Map<String, dynamic> notification) async {
    try {
      final settings = await getAllNotificationSettings();
      
      for (final setting in settings) {
        if (setting.vibrationEnabled && setting.matchesNotification(notification)) {
          final vibrationConfig = setting.additionalData['vibration'];
          if (vibrationConfig != null) {
            print('Configuración de vibración personalizada encontrada: ${setting.id}');
            return Map<String, dynamic>.from(vibrationConfig);
          }
        }
      }
      
      return null;
    } catch (e) {
      print('Error al obtener configuración de vibración: $e');
      return null;
    }
  }

  // Obtener configuración de sonido personalizada para una notificación
  Future<Map<String, dynamic>?> getCustomSoundConfig(Map<String, dynamic> notification) async {
    try {
      final settings = await getAllNotificationSettings();
      
      for (final setting in settings) {
        if (setting.soundEnabled && setting.matchesNotification(notification)) {
          final soundConfig = setting.additionalData['sound'];
          if (soundConfig != null) {
            print('Configuración de sonido personalizada encontrada: ${setting.id}');
            return Map<String, dynamic>.from(soundConfig);
          }
        }
      }
      
      return null;
    } catch (e) {
      print('Error al obtener configuración de sonido: $e');
      return null;
    }
  }

  // Actualizar solo la configuración de vibración
  Future<bool> updateVibrationConfig(String settingsId, Map<String, dynamic> vibrationConfig) async {
    try {
      final deviceId = await _firebaseService.getDeviceId();
      
      await _firestore
          .collection('dispositivos')
          .doc(deviceId)
          .collection('notifSettings')
          .doc(settingsId)
          .update({
            'vibrationEnabled': true,
            'additionalData.vibration': vibrationConfig,
            'updatedAt': Timestamp.now(),
          });

      print('Configuración de vibración actualizada: $settingsId');
      return true;
    } catch (e) {
      print('Error al actualizar configuración de vibración: $e');
      return false;
    }
  }

  // Actualizar solo la configuración de sonido
  Future<bool> updateSoundConfig(String settingsId, Map<String, dynamic> soundConfig) async {
    try {
      final deviceId = await _firebaseService.getDeviceId();
      
      await _firestore
          .collection('dispositivos')
          .doc(deviceId)
          .collection('notifSettings')
          .doc(settingsId)
          .update({
            'soundEnabled': true,
            'additionalData.sound': soundConfig,
            'updatedAt': Timestamp.now(),
          });

      print('Configuración de sonido actualizada: $settingsId');
      return true;
    } catch (e) {
      print('Error al actualizar configuración de sonido: $e');
      return false;
    }
  }

  // Stream para escuchar cambios en las configuraciones
  Stream<List<NotificationSettings>> watchNotificationSettings() {
    return _firebaseService.getDeviceId().asStream().asyncExpand((deviceId) {
      return _firestore
          .collection('dispositivos')
          .doc(deviceId)
          .collection('notifSettings')
          .orderBy('updatedAt', descending: true)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs
                .map((doc) => NotificationSettings.fromMap(doc.data(), doc.id))
                .toList();
          });
    }).handleError((error) {
      print('Error en stream de configuraciones: $error');
      return <NotificationSettings>[];
    });
  }

  // Verificar si existe una configuración para una notificación específica
  Future<NotificationSettings?> findMatchingSettings(Map<String, dynamic> notification) async {
    try {
      final settings = await getAllNotificationSettings();
      
      for (final setting in settings) {
        if (setting.matchesNotification(notification)) {
          return setting;
        }
      }
      
      return null;
    } catch (e) {
      print('Error al buscar configuración coincidente: $e');
      return null;
    }
  }
}