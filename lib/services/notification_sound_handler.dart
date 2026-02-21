import 'dart:async';
import 'package:flutter/services.dart';
import 'package:connect/services/custom_sound_service.dart';

class NotificationSoundHandler {
  static const MethodChannel _channel = MethodChannel('com.example.connect/notification_sound');
  static const EventChannel _eventChannel = EventChannel('com.example.connect/sound_events');
  
  static StreamSubscription? _soundEventSubscription;
  static bool _isInitialized = false;

  // Inicializar el manejador de sonidos
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // print('🔊 Inicializando NotificationSoundHandler');
      
      // Configurar el canal de métodos para recibir comandos desde Android
      _channel.setMethodCallHandler(_handleMethodCall);
      
      // Escuchar eventos de sonido desde Android
      _soundEventSubscription = _eventChannel.receiveBroadcastStream().listen(
        (event) {
          // print('🔊 Evento de sonido recibido: $event');
          if (event == 'PLAY_CUSTOM_SOUND') {
            _playCustomSoundFromAndroid();
          }
        },
        onError: (error) {
          // print('❌ Error en stream de eventos de sonido: $error');
        },
      );
      
      _isInitialized = true;
      // print('✅ NotificationSoundHandler inicializado correctamente');
    } catch (e) {
      // print('❌ Error al inicializar NotificationSoundHandler: $e');
    }
  }

  // Manejar llamadas de métodos desde Android
  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    try {
      // print('🔊 Método recibido desde Android: ${call.method}');
      
      switch (call.method) {
        case 'playCustomSound':
          await _playCustomSoundFromAndroid();
          return 'success';
        
        case 'getSelectedSoundInfo':
          final selectedSound = await CustomSoundService.getSelectedSound();
          return {
            'id': selectedSound?.id ?? 'default',
            'name': selectedSound?.name ?? 'Sonido del Sistema',
            'isDefault': selectedSound?.isDefault ?? true,
          };
        
        case 'isSoundEnabled':
          return await CustomSoundService.isSoundEnabled();
        
        default:
          // print('⚠️ Método no reconocido: ${call.method}');
          throw PlatformException(
            code: 'UNIMPLEMENTED',
            message: 'Método ${call.method} no implementado',
          );
      }
    } catch (e) {
      // print('❌ Error al manejar método ${call.method}: $e');
      rethrow;
    }
  }

  // Reproducir sonido personalizado cuando es llamado desde Android
  static Future<void> _playCustomSoundFromAndroid() async {
    try {
      // print('🔊 Reproduciendo sonido personalizado desde comando de Android');
      
      // Verificar si los sonidos personalizados están habilitados
      final isEnabled = await CustomSoundService.isSoundEnabled();
      if (!isEnabled) {
        // print('❌ Sonidos personalizados deshabilitados');
        return;
      }
      
      // Obtener y reproducir el sonido seleccionado
      final selectedSound = await CustomSoundService.getSelectedSound();
      if (selectedSound != null) {
        // print('🎵 Reproduciendo sonido: ${selectedSound.name}');
        await CustomSoundService.playSound(selectedSound);
        // print('✅ Sonido personalizado reproducido exitosamente');
      } else {
        // print('⚠️ No hay sonido seleccionado');
      }
    } catch (e) {
      // print('❌ Error al reproducir sonido personalizado: $e');
    }
  }

  // Reproducir sonido personalizado manualmente (para testing)
  static Future<void> playSelectedSound() async {
    try {
      // print('🔊 Reproduciendo sonido personalizado manualmente');
      await CustomSoundService.playSelectedSound();
    } catch (e) {
      // print('❌ Error al reproducir sonido manualmente: $e');
    }
  }

  // Notificar a Android sobre cambios en la configuración de sonido
  static Future<void> notifySoundConfigurationChanged() async {
    try {
      final selectedSound = await CustomSoundService.getSelectedSound();
      final isEnabled = await CustomSoundService.isSoundEnabled();
      
      await _channel.invokeMethod('onSoundConfigurationChanged', {
        'selectedSoundId': selectedSound?.id ?? 'default',
        'selectedSoundName': selectedSound?.name ?? 'Sonido del Sistema',
        'isDefault': selectedSound?.isDefault ?? true,
        'isEnabled': isEnabled,
      });
      
      // print('✅ Configuración de sonido notificada a Android');
    } catch (e) {
      // print('❌ Error al notificar configuración de sonido: $e');
    }
  }

  // Limpiar recursos
  static Future<void> dispose() async {
    try {
      await _soundEventSubscription?.cancel();
      _soundEventSubscription = null;
      _isInitialized = false;
      // print('✅ NotificationSoundHandler limpiado');
    } catch (e) {
      // print('❌ Error al limpiar NotificationSoundHandler: $e');
    }
  }

  // Verificar si está inicializado
  static bool get isInitialized => _isInitialized;

  // Test de conectividad con Android
  static Future<bool> testConnection() async {
    try {
      final result = await _channel.invokeMethod('ping');
      // print('🔊 Test de conexión con Android: $result');
      return result == 'pong';
    } catch (e) {
      // print('❌ Error en test de conexión: $e');
      return false;
    }
  }
}