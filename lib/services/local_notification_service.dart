import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dismissed_notifications_service.dart';
import 'package:connect/services/vibration_pattern_service.dart';
import 'package:connect/services/notification_settings_service.dart';
import 'package:connect/services/custom_sound_service.dart';
import 'package:connect/services/notification_cache_service.dart';

class LocalNotificationService {
  static const MethodChannel _channel = MethodChannel('com.example.connect/local_notifications');
  
  // Claves para SharedPreferences
  static const String KEY_NOTIFICATIONS_ENABLED = 'local_notifications_enabled';
  static const String KEY_SOUND_ENABLED = 'local_notifications_sound';
  static const String KEY_VIBRATION_ENABLED = 'vibration_enabled'; // ✅ SINCRONIZADO con VibrationPatternService
  // ✅ NUEVAS CLAVES SEPARADAS
  static const String KEY_SCREEN_WAKE_ENABLED = 'local_notifications_screen_wake';
  static const String KEY_AUTO_OPEN_ENABLED = 'local_notifications_auto_open';
  static const String _recentWhatsAppContentKey = 'recent_whatsapp_notification_content_v1';
  static const int _recentWhatsAppMaxEntries = 2000;
  static const int _recentWhatsAppTtlMs = 24 * 60 * 60 * 1000;
  
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
          // print('Notificación marcada como eliminada desde Android: $notificationId');
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
      
      // print('Sincronizadas ${dismissedList.length} notificaciones canceladas con Android');
    } catch (e) {
      // print('Error al sincronizar notificaciones canceladas: $e');
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
      // print('Notificaciones deshabilitadas, no se muestra: $notificationId');
      return;
    }
    
    // Verificar si la notificación fue eliminada previamente
    if (await DismissedNotificationsService.isDismissed(notificationId)) {
      // print('Notificación previamente eliminada, no se muestra: $notificationId');
      return;
    }

    final String effectiveTitle = title.trim();
    final String trimmedBody = body.trim();
    final String effectiveBody =
        (trimmedBody.toLowerCase() == 'null' ||
                trimmedBody.toLowerCase() == 'undefined')
            ? ''
            : trimmedBody;
    if (effectiveBody.isEmpty) return;

    String? tryReadString(dynamic v) {
      if (v is String && v.trim().isNotEmpty) return v;
      return null;
    }

    String? extractAppIcon(Map<String, dynamic>? map) {
      if (map == null) return null;
      final nested = map['extras'];
      if (nested is Map) {
        final m = Map<String, dynamic>.from(nested);
        return tryReadString(m['appIcon']) ?? tryReadString(m['icon']);
      }
      return tryReadString(map['appIcon']) ?? tryReadString(map['icon']);
    }

    final String? appIcon = extractAppIcon(extras);

    // Crear datos de la notificación para verificar configuraciones personalizadas
    final notificationData = {
      'title': effectiveTitle,
      'text': effectiveBody,
      'packageName': packageName,
      'appName': appName,
      'extras': extras ?? {},
    };

    try {
      final suppress = await NotificationCacheService.shouldSuppressLocalEcho(
        packageName: packageName,
        title: effectiveTitle,
        text: effectiveBody,
      );
      if (suppress) {
        return;
      }
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    if (await _isDuplicateWhatsAppContent(prefs, notificationData)) {
      return;
    }

    // Verificar si la notificación debe ser bloqueada
    final notificationSettingsService = NotificationSettingsService();
    final isBlocked = await notificationSettingsService.shouldBlockNotification(notificationData);
    if (isBlocked) {
      // print('Notificación bloqueada por configuración personalizada: $notificationId');
      return;
    }
    
    // Obtener configuración
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

    List<int>? customVibrationPattern;
    if (shouldVibrate) {
      if (hasCustomVibration) {
        final pattern = customVibrationConfig!['pattern'] as List<dynamic>?;
        if (pattern != null) {
          customVibrationPattern = pattern.cast<int>();
        }
      } else {
        final selectedPattern = await VibrationPatternService.getSelectedPattern();
        customVibrationPattern = selectedPattern?.pattern;
      }
    }
    
    // print('🔍 Vibración habilitada en configuración: $isVibrationEnabledInSettings');
    // print('🔍 Vibración habilitada en notificación: $vibrationEnabled');
    // print('🔍 Configuración personalizada de vibración: $hasCustomVibration');
    // print('🔍 Configuración personalizada de sonido: $hasCustomSound');
    // print('🔍 Se ejecutará vibración después del auto-open: $shouldVibrate');
    
    // ✅ DEBUGGING: Verificar valores en SharedPreferences
     // print('=== VALORES EN SHAREDPREFERENCES ===');
     // print('KEY_SCREEN_WAKE_ENABLED ($KEY_SCREEN_WAKE_ENABLED): $screenWakeEnabled');
     // print('KEY_AUTO_OPEN_ENABLED ($KEY_AUTO_OPEN_ENABLED): $autoOpenEnabled');
     // print('Todas las claves: ${prefs.getKeys()}');
     // print('🔍 VERIFICACIÓN CRÍTICA: autoOpenEnabled = $autoOpenEnabled');
     // print('====================================');
    
    // ✅ CAMBIO: Auto-open ahora funciona independientemente de screen wake
    final effectiveAutoOpenEnabled = autoOpenEnabled; // Sin dependencia de screenWakeEnabled
    
    // ✅ LOGGING mejorado
    // print('=== CONFIGURACIÓN DE NOTIFICACIÓN ===');
    // print('Screen Wake Enabled: $screenWakeEnabled');
    // print('Auto Open Requested: $autoOpenEnabled');
    // print('Auto Open Effective: $effectiveAutoOpenEnabled (independiente)');
    // print('Sound Enabled: $soundEnabled');
    // print('Vibration Enabled: $vibrationEnabled');
    // print('Notification ID: $notificationId');
    // print('=====================================');
    
    try {
      // ✅ PRIMERO: Enviar notificación al lado nativo (esto activará auto-open inmediatamente)
      await _channel.invokeMethod('showNotification', {
        'title': effectiveTitle,
        'body': effectiveBody,
        'packageName': packageName,
        'appName': appName,
        'appIcon': appIcon ?? '',
        'notificationId': notificationId,
        'soundEnabled': effectiveSoundEnabled,
        'vibrationEnabled': shouldVibrate,
        'customVibrationPattern': customVibrationPattern,
        'screenWakeEnabled': screenWakeEnabled,
        'autoOpenEnabled': effectiveAutoOpenEnabled, // ✅ Usar valor efectivo
      });
      
      // print('Notificación enviada exitosamente a Android');
      
      // ✅ SEGUNDO: Ejecutar sonido personalizado si está configurado
      if (hasCustomSound) {
        try {
          final soundId = customSoundConfig!['soundId'] as String?;
          if (soundId != null) {
            final customSound = await CustomSoundService.getSoundById(soundId);
            if (customSound != null) {
              // print('🔊 Reproduciendo sonido personalizado: ${customSound.name}');
              await CustomSoundService.playSound(customSound);
            }
          }
        } catch (e) {
          // print('❌ Error al reproducir sonido personalizado: $e');
        }
      }
      
    } catch (e) {
      // print('Error al mostrar notificación: $e');
    }
  }

  static Future<bool> _isDuplicateWhatsAppContent(
    SharedPreferences prefs,
    Map<String, dynamic> notificationData,
  ) async {
    final packageName = (notificationData['packageName'] ?? '').toString();
    if (packageName != 'com.whatsapp' && packageName != 'com.whatsapp.w4b') {
      return false;
    }

    final title = (notificationData['title'] ?? '').toString();
    final text = (notificationData['text'] ?? '').toString();
    final normalized = _normalizeForHash('$packageName|$title|$text');
    if (normalized.isEmpty) return false;
    final hash = normalized.hashCode.toString();
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    final raw = prefs.getString(_recentWhatsAppContentKey);
    Map<String, dynamic> map;
    try {
      map = raw == null || raw.isEmpty
          ? <String, dynamic>{}
          : (jsonDecode(raw) as Map).cast<String, dynamic>();
    } catch (_) {
      map = <String, dynamic>{};
    }

    final cutoffMs = nowMs - _recentWhatsAppTtlMs;
    final keysToRemove = <String>[];
    for (final entry in map.entries) {
      final ts = entry.value;
      final tsMs = ts is int ? ts : int.tryParse(ts.toString());
      if (tsMs == null || tsMs < cutoffMs) {
        keysToRemove.add(entry.key);
      }
    }
    for (final k in keysToRemove) {
      map.remove(k);
    }

    if (map.containsKey(hash)) {
      return true;
    }

    map[hash] = nowMs;
    if (map.length > _recentWhatsAppMaxEntries) {
      final sorted = map.entries.toList()
        ..sort((a, b) {
          final ta = a.value is int ? a.value as int : int.tryParse(a.value.toString()) ?? 0;
          final tb = b.value is int ? b.value as int : int.tryParse(b.value.toString()) ?? 0;
          return ta.compareTo(tb);
        });
      final toDrop = sorted.length - _recentWhatsAppMaxEntries;
      for (var i = 0; i < toDrop; i++) {
        map.remove(sorted[i].key);
      }
    }

    await prefs.setString(_recentWhatsAppContentKey, jsonEncode(map));
    return false;
  }

  static String _normalizeForHash(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[áàäâ]'), 'a')
        .replaceAll(RegExp(r'[éèëê]'), 'e')
        .replaceAll(RegExp(r'[íìïî]'), 'i')
        .replaceAll(RegExp(r'[óòöô]'), 'o')
        .replaceAll(RegExp(r'[úùüû]'), 'u')
        .replaceAll(RegExp(r'[ñ]'), 'n')
        .replaceAll(RegExp(r'[^a-z0-9\s\|]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
  
  // ✅ CAMBIO: Validación simplificada sin dependencia entre configuraciones
  static Future<bool> validateConfiguration() async {
    // Ya no hay dependencias entre auto-open y screen wake
    // print('Configuración validada - Auto-open independiente de screen wake');
    return true;
  }
  
  // ✅ CAMBIO: setAutoOpenEnabled sin validación de screen wake + ACTUALIZACIÓN EN TIEMPO REAL
  static Future<void> setAutoOpenEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Auto-open ahora funciona independientemente
    await prefs.setBool(KEY_AUTO_OPEN_ENABLED, enabled);
    // print('Auto-open ${enabled ? 'habilitado' : 'deshabilitado'} (independiente de screen wake)');
    
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
      // print('Error al cancelar notificación: $e');
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
      
      // print('⚡ CONFIGURACIÓN NATIVA ACTUALIZADA EN TIEMPO REAL:');
      // print('   screenWakeEnabled: $screenWakeEnabled');
      // print('   autoOpenEnabled: $autoOpenEnabled');
      // print('   soundEnabled: $soundEnabled');
    } catch (e) {
      // print('❌ Error al actualizar configuración nativa: $e');
    }
  }
}
