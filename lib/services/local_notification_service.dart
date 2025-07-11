import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dismissed_notifications_service.dart';
import 'package:connect/services/vibration_pattern_service.dart';
import 'package:connect/services/notification_settings_service.dart';
import 'package:connect/services/custom_sound_service.dart';
import 'package:vibration/vibration.dart';

class LocalNotificationService {
  static const MethodChannel _channel = MethodChannel('com.example.connect/local_notifications');
  
  // Claves para SharedPreferences
  static const String KEY_NOTIFICATIONS_ENABLED = 'local_notifications_enabled';
  static const String KEY_SOUND_ENABLED = 'local_notifications_sound';
  static const String KEY_VIBRATION_ENABLED = 'vibration_enabled'; // ✅ SINCRONIZADO con VibrationPatternService
  // ✅ NUEVAS CLAVES SEPARADAS
  static const String KEY_SCREEN_WAKE_ENABLED = 'local_notifications_screen_wake';
  static const String KEY_AUTO_OPEN_ENABLED = 'local_notifications_auto_open';
  
  // Callback para manejar cuando se toca una notificación
  static Function(Map<String, dynamic>)? onNotificationTapped;
  
  // ✅ Nuevo callback para manejar auto-apertura
  static Function(Map<String, dynamic>)? onNotificationAutoOpened;
  
  // Manejar llamadas desde el código nativo
  static Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onNotificationTapped':
        if (onNotificationTapped != null) {
          final Map<String, dynamic> data = Map<String, dynamic>.from(call.arguments);
          onNotificationTapped!(data);
        }
        break;
      case 'onNotificationAutoOpened':
        if (onNotificationAutoOpened != null) {
          final Map<String, dynamic> data = Map<String, dynamic>.from(call.arguments);
          onNotificationAutoOpened!(data);
        }
        break;
      case 'onNotificationDismissed':
        final Map<String, dynamic> data = Map<String, dynamic>.from(call.arguments);
        final String notificationId = data['notificationId'] ?? '';
        if (notificationId.isNotEmpty) {
          await DismissedNotificationsService.markAsDismissed(notificationId);
          print('Notificación marcada como eliminada desde Android: $notificationId');
        }
        break;
    }
  }
  
  // ✅ Método corregido para sincronizar notificaciones canceladas con Android
  static Future<void> syncCancelledNotificationsWithAndroid() async {
    try {
      final dismissedList = await DismissedNotificationsService.getDismissedNotificationIds();
      
      await _channel.invokeMethod('syncCancelledNotifications', {
        'cancelledIds': dismissedList,
      });
      
      print('Sincronizadas ${dismissedList.length} notificaciones canceladas con Android');
    } catch (e) {
      print('Error al sincronizar notificaciones canceladas: $e');
    }
  }
  
  // Inicializar el servicio de notificaciones
  static Future<void> initialize() async {
    _channel.setMethodCallHandler(_handleMethodCall);
  }
  
  // Mostrar una notificación (método modificado)
  // ✅ MEJORAR: Método showNotification con validación
  static Future<void> showNotification({
    required String title,
    required String body,
    required String packageName,
    required String appName,
    required String notificationId,
    Map<String, dynamic>? extras,
  }) async {
    // Verificar si las notificaciones están habilitadas
    if (!await areNotificationsEnabled()) {
      print('Notificaciones deshabilitadas, no se muestra: $notificationId');
      return;
    }
    
    // Verificar si la notificación fue eliminada previamente
    if (await DismissedNotificationsService.isDismissed(notificationId)) {
      print('Notificación previamente eliminada, no se muestra: $notificationId');
      return;
    }

    // Crear datos de la notificación para verificar configuraciones personalizadas
    final notificationData = {
      'title': title,
      'text': body,
      'packageName': packageName,
      'appName': appName,
      'extras': extras ?? {},
    };

    // Verificar si la notificación debe ser bloqueada
    final notificationSettingsService = NotificationSettingsService();
    final isBlocked = await notificationSettingsService.shouldBlockNotification(notificationData);
    if (isBlocked) {
      print('Notificación bloqueada por configuración personalizada: $notificationId');
      return;
    }
    
    // Obtener configuración
    final prefs = await SharedPreferences.getInstance();
    final soundEnabled = prefs.getBool(KEY_SOUND_ENABLED) ?? true;
    final vibrationEnabled = prefs.getBool(KEY_VIBRATION_ENABLED) ?? true;
    final screenWakeEnabled = prefs.getBool(KEY_SCREEN_WAKE_ENABLED) ?? false;
    final autoOpenEnabled = prefs.getBool(KEY_AUTO_OPEN_ENABLED) ?? false;
    
    // ✅ VERIFICAR CONFIGURACIONES PERSONALIZADAS DE VIBRACIÓN Y SONIDO
    final customVibrationConfig = await notificationSettingsService.getCustomVibrationConfig(notificationData);
    final customSoundConfig = await notificationSettingsService.getCustomSoundConfig(notificationData);
    
    // ✅ PREPARAR CONFIGURACIÓN DE VIBRACIÓN PARA EJECUTAR DESPUÉS
    final isVibrationEnabledInSettings = await VibrationPatternService.isVibrationEnabled();
    final hasCustomVibration = customVibrationConfig != null;
    final shouldVibrate = (vibrationEnabled && isVibrationEnabledInSettings) || hasCustomVibration;
    
    // ✅ PREPARAR CONFIGURACIÓN DE SONIDO
    final hasCustomSound = customSoundConfig != null;
    final effectiveSoundEnabled = hasCustomSound ? false : soundEnabled; // Deshabilitar sonido nativo si hay sonido personalizado
    
    print('🔍 Vibración habilitada en configuración: $isVibrationEnabledInSettings');
    print('🔍 Vibración habilitada en notificación: $vibrationEnabled');
    print('🔍 Configuración personalizada de vibración: $hasCustomVibration');
    print('🔍 Configuración personalizada de sonido: $hasCustomSound');
    print('🔍 Se ejecutará vibración después del auto-open: $shouldVibrate');
    
    // ✅ DEBUGGING: Verificar valores en SharedPreferences
     print('=== VALORES EN SHAREDPREFERENCES ===');
     print('KEY_SCREEN_WAKE_ENABLED ($KEY_SCREEN_WAKE_ENABLED): $screenWakeEnabled');
     print('KEY_AUTO_OPEN_ENABLED ($KEY_AUTO_OPEN_ENABLED): $autoOpenEnabled');
     print('Todas las claves: ${prefs.getKeys()}');
     print('🔍 VERIFICACIÓN CRÍTICA: autoOpenEnabled = $autoOpenEnabled');
     print('====================================');
    
    // ✅ CAMBIO: Auto-open ahora funciona independientemente de screen wake
    final effectiveAutoOpenEnabled = autoOpenEnabled; // Sin dependencia de screenWakeEnabled
    
    // ✅ LOGGING mejorado
    print('=== CONFIGURACIÓN DE NOTIFICACIÓN ===');
    print('Screen Wake Enabled: $screenWakeEnabled');
    print('Auto Open Requested: $autoOpenEnabled');
    print('Auto Open Effective: $effectiveAutoOpenEnabled (independiente)');
    print('Sound Enabled: $soundEnabled');
    print('Vibration Enabled: $vibrationEnabled');
    print('Notification ID: $notificationId');
    print('=====================================');
    
    try {
      // ✅ PRIMERO: Enviar notificación al lado nativo (esto activará auto-open inmediatamente)
      await _channel.invokeMethod('showNotification', {
        'title': title,
        'body': body,
        'packageName': packageName,
        'appName': appName,
        'notificationId': notificationId,
        'soundEnabled': effectiveSoundEnabled,
        'vibrationEnabled': false, // Deshabilitamos vibración nativa ya que la manejamos directamente
        'screenWakeEnabled': screenWakeEnabled,
        'autoOpenEnabled': effectiveAutoOpenEnabled, // ✅ Usar valor efectivo
      });
      
      print('Notificación enviada exitosamente a Android');
      
      // ✅ SEGUNDO: Ejecutar sonido personalizado si está configurado
      if (hasCustomSound) {
        try {
          final soundId = customSoundConfig!['soundId'] as String?;
          if (soundId != null) {
            final customSound = await CustomSoundService.getSoundById(soundId);
            if (customSound != null) {
              print('🔊 Reproduciendo sonido personalizado: ${customSound.name}');
              await CustomSoundService.playSound(customSound);
            }
          }
        } catch (e) {
          print('❌ Error al reproducir sonido personalizado: $e');
        }
      }
      
      // ✅ TERCERO: Ejecutar vibración DESPUÉS del auto-open
      if (shouldVibrate) {
        try {
          if (hasCustomVibration) {
            // Usar patrón personalizado de la configuración
            final pattern = customVibrationConfig!['pattern'] as List<dynamic>?;
            if (pattern != null) {
              final vibrationPattern = pattern.cast<int>();
              print('🔊 Ejecutando patrón de vibración personalizado de configuración');
              await VibrationPatternService.playPatternFromList(vibrationPattern);
            }
          } else {
            // Usar patrón seleccionado globalmente
            final selectedPattern = await VibrationPatternService.getSelectedPattern();
            if (selectedPattern != null) {
              print('🔊 Ejecutando patrón de vibración global después del auto-open: ${selectedPattern.name}');
              await VibrationPatternService.playPattern(selectedPattern);
            } else {
              print('🔊 No hay patrón seleccionado, usando vibración simple después del auto-open');
              await Vibration.vibrate(duration: 500);
            }
          }
        } catch (e) {
          print('❌ Error al ejecutar vibración después del auto-open: $e');
          // Fallback a vibración simple
          try {
            await Vibration.vibrate(duration: 500);
          } catch (fallbackError) {
            print('❌ Error en vibración de fallback después del auto-open: $fallbackError');
          }
        }
      } else if (!isVibrationEnabledInSettings && !hasCustomVibration) {
        print('⚠️ Vibración deshabilitada en configuración, saltando vibración');
      } else {
        print('⚠️ Vibración deshabilitada para esta notificación, saltando vibración');
      }
      
    } catch (e) {
      print('Error al mostrar notificación: $e');
    }
  }
  
  // ✅ CAMBIO: Validación simplificada sin dependencia entre configuraciones
  static Future<bool> validateConfiguration() async {
    // Ya no hay dependencias entre auto-open y screen wake
    print('Configuración validada - Auto-open independiente de screen wake');
    return true;
  }
  
  // ✅ CAMBIO: setAutoOpenEnabled sin validación de screen wake + ACTUALIZACIÓN EN TIEMPO REAL
  static Future<void> setAutoOpenEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Auto-open ahora funciona independientemente
    await prefs.setBool(KEY_AUTO_OPEN_ENABLED, enabled);
    print('Auto-open ${enabled ? 'habilitado' : 'deshabilitado'} (independiente de screen wake)');
    
    // ✅ ACTUALIZAR CONFIGURACIÓN EN TIEMPO REAL EN EL LADO NATIVO
    await _updateNativeSettings();
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
    
    // ✅ ACTUALIZAR CONFIGURACIÓN EN TIEMPO REAL EN EL LADO NATIVO
    await _updateNativeSettings();
  }
  
  // ✅ ELIMINADO: setVibrationEnabled - usar VibrationPatternService.setVibrationEnabled en su lugar
  // para mantener sincronización con la configuración global de vibración
  
  // Habilitar o deshabilitar apertura automática
  // ✅ NUEVOS MÉTODOS PARA MANEJAR ACTIVACIÓN DE PANTALLA + ACTUALIZACIÓN EN TIEMPO REAL
  static Future<void> setScreenWakeEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(KEY_SCREEN_WAKE_ENABLED, enabled);
    
    // ✅ ACTUALIZAR CONFIGURACIÓN EN TIEMPO REAL EN EL LADO NATIVO
    await _updateNativeSettings();
  }
  
  static Future<bool> isScreenWakeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(KEY_SCREEN_WAKE_ENABLED) ?? false;
  }
  
  // ✅ MODIFICAR MÉTODOS DE AUTO-APERTURA PARA QUE DEPENDAN DE SCREEN_WAKE
  // Método eliminado - ya existe una versión mejorada arriba
  
  static Future<bool> isAutoOpenEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(KEY_AUTO_OPEN_ENABLED) ?? false;
  }
  
  // Obtener configuración de sonido
  static Future<bool> isSoundEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(KEY_SOUND_ENABLED) ?? true;
  }
  
  // ✅ MODIFICADO: isVibrationEnabled - usar VibrationPatternService para consistencia
  static Future<bool> isVibrationEnabled() async {
    return await VibrationPatternService.isVibrationEnabled();
  }
  
  // ✅ MÉTODO PRIVADO PARA ACTUALIZAR CONFIGURACIÓN EN TIEMPO REAL EN EL LADO NATIVO
  static Future<void> _updateNativeSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final screenWakeEnabled = prefs.getBool(KEY_SCREEN_WAKE_ENABLED) ?? false;
      final autoOpenEnabled = prefs.getBool(KEY_AUTO_OPEN_ENABLED) ?? false;
      final soundEnabled = prefs.getBool(KEY_SOUND_ENABLED) ?? true;
      
      await _channel.invokeMethod('updateNotificationSettings', {
        'screenWakeEnabled': screenWakeEnabled,
        'autoOpenEnabled': autoOpenEnabled,
        'soundEnabled': soundEnabled,
      });
      
      print('⚡ CONFIGURACIÓN NATIVA ACTUALIZADA EN TIEMPO REAL:');
      print('   screenWakeEnabled: $screenWakeEnabled');
      print('   autoOpenEnabled: $autoOpenEnabled');
      print('   soundEnabled: $soundEnabled');
    } catch (e) {
      print('❌ Error al actualizar configuración nativa: $e');
    }
  }
}