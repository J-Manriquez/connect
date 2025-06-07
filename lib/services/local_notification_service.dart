import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dismissed_notifications_service.dart';

class LocalNotificationService {
  static const MethodChannel _channel = MethodChannel('com.example.connect/local_notifications');
  
  // Claves para SharedPreferences
  static const String KEY_NOTIFICATIONS_ENABLED = 'local_notifications_enabled';
  static const String KEY_SOUND_ENABLED = 'local_notifications_sound';
  static const String KEY_VIBRATION_ENABLED = 'local_notifications_vibration';
  static const String KEY_AUTO_OPEN_ENABLED = 'local_notifications_auto_open';
  
  // Callback para manejar cuando se toca una notificación
  static Function(Map<String, dynamic>)? onNotificationTapped;
  
  // Inicializar el servicio de notificaciones
  static Future<void> initialize() async {
    _channel.setMethodCallHandler(_handleMethodCall);
  }
  
  // Manejar llamadas desde el código nativo
  static Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onNotificationTapped':
        if (onNotificationTapped != null) {
          final Map<String, dynamic> data = Map<String, dynamic>.from(call.arguments);
          onNotificationTapped!(data);
        }
        break;
      case 'onNotificationDismissed':
        final Map<String, dynamic> data = Map<String, dynamic>.from(call.arguments);
        final String notificationId = data['notificationId'] ?? '';
        if (notificationId.isNotEmpty) {
          await DismissedNotificationsService.markAsDismissed(notificationId);
        }
        break;
    }
  }
  
  // Mostrar una notificación (método modificado)
  static Future<void> showNotification({
    required String title,
    required String body,
    required String packageName,
    required String appName,
    required String notificationId,
    Map<String, dynamic>? fullNotificationData, // Nuevo parámetro
  }) async {
    // Verificar si las notificaciones están habilitadas
    if (!await areNotificationsEnabled()) {
      return;
    }
    
    // Verificar si la notificación fue eliminada previamente
    if (await DismissedNotificationsService.isDismissed(notificationId)) {
      print('Notificación previamente eliminada, no se muestra: $notificationId');
      return;
    }
    
    // Obtener configuración
    final prefs = await SharedPreferences.getInstance();
    final soundEnabled = prefs.getBool(KEY_SOUND_ENABLED) ?? true;
    final vibrationEnabled = prefs.getBool(KEY_VIBRATION_ENABLED) ?? true;
    final autoOpenEnabled = prefs.getBool(KEY_AUTO_OPEN_ENABLED) ?? false;
    
    try {
      // Preparar datos completos para enviar al callback
      final Map<String, dynamic> notificationPayload = {
        'title': title,
        'body': body,
        'packageName': packageName,
        'appName': appName,
        'notificationId': notificationId,
        'soundEnabled': soundEnabled,
        'vibrationEnabled': vibrationEnabled,
        'autoOpenEnabled': autoOpenEnabled,
        // Incluir todos los datos adicionales de la notificación
        if (fullNotificationData != null) ...fullNotificationData,
      };
      
      await _channel.invokeMethod('showNotification', notificationPayload);
    } catch (e) {
      print('Error al mostrar notificación: $e');
    }
  }
  
  // Cancelar una notificación
  static Future<void> cancelNotification(String notificationId) async {
    try {
      await _channel.invokeMethod('cancelNotification', {
        'notificationId': notificationId,
      });
    } catch (e) {
      print('Error al cancelar notificación: $e');
    }
  }
  
  // Verificar si las notificaciones están habilitadas
  static Future<bool> areNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(KEY_NOTIFICATIONS_ENABLED) ?? false;
  }
  
  // Habilitar o deshabilitar notificaciones
  static Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(KEY_NOTIFICATIONS_ENABLED, enabled);
  }
  
  // Habilitar o deshabilitar sonido
  static Future<void> setSoundEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(KEY_SOUND_ENABLED, enabled);
  }
  
  // Habilitar o deshabilitar vibración
  static Future<void> setVibrationEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(KEY_VIBRATION_ENABLED, enabled);
  }
  
  // Habilitar o deshabilitar apertura automática
  static Future<void> setAutoOpenEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(KEY_AUTO_OPEN_ENABLED, enabled);
  }
  
  // Obtener configuración de sonido
  static Future<bool> isSoundEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(KEY_SOUND_ENABLED) ?? true;
  }
  
  // Obtener configuración de vibración
  static Future<bool> isVibrationEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(KEY_VIBRATION_ENABLED) ?? true;
  }
  
  // Obtener configuración de apertura automática
  static Future<bool> isAutoOpenEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(KEY_AUTO_OPEN_ENABLED) ?? false;
  }
}