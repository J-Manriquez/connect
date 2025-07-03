import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';

class VibrationPattern {
  final String id;
  final String name;
  final List<int> pattern; // Duración en milisegundos: [vibrar, pausa, vibrar, pausa, ...]
  final DateTime createdAt;
  final bool isDefault;

  VibrationPattern({
    required this.id,
    required this.name,
    required this.pattern,
    required this.createdAt,
    this.isDefault = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'pattern': pattern,
      'createdAt': createdAt.toIso8601String(),
      'isDefault': isDefault,
    };
  }

  factory VibrationPattern.fromJson(Map<String, dynamic> json) {
    return VibrationPattern(
      id: json['id'],
      name: json['name'],
      pattern: List<int>.from(json['pattern']),
      createdAt: DateTime.parse(json['createdAt']),
      isDefault: json['isDefault'] ?? false,
    );
  }
}

class VibrationPatternService {
  static const String _patternsKey = 'vibration_patterns';
  static const String _selectedPatternKey = 'selected_vibration_pattern';
  static const String _vibrationEnabledKey = 'vibration_enabled';
  
  // Canal para comunicación con el código nativo (fallback)
  static const MethodChannel _channel = MethodChannel('com.example.connect/local_notifications');

  // Patrón predeterminado
  static VibrationPattern get defaultPattern => VibrationPattern(
    id: 'default',
    name: 'Predeterminado',
    pattern: [0, 300, 100, 300], // Pausa inicial, vibrar 300ms, pausa 100ms, vibrar 300ms
    createdAt: DateTime.now(),
    isDefault: true,
  );

  // Obtener todos los patrones guardados
  static Future<List<VibrationPattern>> getAllPatterns() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final patternsJson = prefs.getString(_patternsKey);
      
      List<VibrationPattern> patterns = [defaultPattern]; // Siempre incluir el predeterminado
      
      if (patternsJson != null) {
        final List<dynamic> patternsList = json.decode(patternsJson);
        final customPatterns = patternsList
            .map((json) => VibrationPattern.fromJson(json))
            .where((pattern) => !pattern.isDefault) // Excluir duplicados del predeterminado
            .toList();
        patterns.addAll(customPatterns);
      }
      
      // Ordenar por fecha de creación (más recientes primero)
      patterns.sort((a, b) {
        if (a.isDefault) return -1; // El predeterminado siempre primero
        if (b.isDefault) return 1;
        return b.createdAt.compareTo(a.createdAt);
      });
      
      return patterns;
    } catch (e) {
      print('Error al obtener patrones de vibración: $e');
      return [defaultPattern];
    }
  }

  // Guardar un nuevo patrón
  static Future<bool> savePattern(VibrationPattern pattern) async {
    try {
      final patterns = await getAllPatterns();
      
      // Verificar que no sea el patrón predeterminado
      if (pattern.isDefault) {
        print('No se puede guardar el patrón predeterminado');
        return false;
      }
      
      // Agregar el nuevo patrón
      patterns.add(pattern);
      
      // Filtrar solo los patrones personalizados para guardar
      final customPatterns = patterns.where((p) => !p.isDefault).toList();
      
      final prefs = await SharedPreferences.getInstance();
      final patternsJson = json.encode(customPatterns.map((p) => p.toJson()).toList());
      
      await prefs.setString(_patternsKey, patternsJson);
      print('✅ Patrón de vibración guardado: ${pattern.name}');
      return true;
    } catch (e) {
      print('❌ Error al guardar patrón de vibración: $e');
      return false;
    }
  }

  // Eliminar un patrón
  static Future<bool> deletePattern(String patternId) async {
    try {
      if (patternId == 'default') {
        print('No se puede eliminar el patrón predeterminado');
        return false;
      }
      
      final patterns = await getAllPatterns();
      final customPatterns = patterns
          .where((p) => !p.isDefault && p.id != patternId)
          .toList();
      
      final prefs = await SharedPreferences.getInstance();
      final patternsJson = json.encode(customPatterns.map((p) => p.toJson()).toList());
      
      await prefs.setString(_patternsKey, patternsJson);
      
      // Si el patrón eliminado era el seleccionado, volver al predeterminado
      final selectedPattern = await getSelectedPattern();
      if (selectedPattern?.id == patternId) {
        await setSelectedPattern('default');
      }
      
      print('✅ Patrón de vibración eliminado: $patternId');
      return true;
    } catch (e) {
      print('❌ Error al eliminar patrón de vibración: $e');
      return false;
    }
  }

  // Obtener el patrón seleccionado actualmente
  static Future<VibrationPattern?> getSelectedPattern() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final selectedId = prefs.getString(_selectedPatternKey) ?? 'default';
      
      final patterns = await getAllPatterns();
      return patterns.firstWhere(
        (pattern) => pattern.id == selectedId,
        orElse: () => defaultPattern,
      );
    } catch (e) {
      print('Error al obtener patrón seleccionado: $e');
      return defaultPattern;
    }
  }

  // Establecer el patrón seleccionado
  static Future<bool> setSelectedPattern(String patternId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_selectedPatternKey, patternId);
      print('✅ Patrón de vibración seleccionado: $patternId');
      return true;
    } catch (e) {
      print('❌ Error al seleccionar patrón de vibración: $e');
      return false;
    }
  }

  // Reproducir un patrón de vibración
  static Future<void> playPattern(VibrationPattern pattern) async {
    try {
      print('🔍 Iniciando reproducción de patrón: ${pattern.name}');
      
      // Verificar si el dispositivo soporta vibración usando el paquete vibration
      final hasVibrator = await Vibration.hasVibrator() ?? false;
      print('🔍 Dispositivo tiene vibrador: $hasVibrator');
      if (!hasVibrator) {
        print('❌ El dispositivo no soporta vibración');
        return;
      }
      
      // Verificar si la vibración está habilitada
      final isEnabled = await isVibrationEnabled();
      print('🔍 Vibración habilitada: $isEnabled');
      if (!isEnabled) {
        print('❌ La vibración está deshabilitada');
        return;
      }
      
      print('🔊 Reproduciendo patrón: ${pattern.name}');
      print('📱 Patrón original: ${pattern.pattern}');
      
      // Convertir a List<int> para el patrón
      final vibrationPattern = pattern.pattern.map((e) => e.toInt()).toList();
      print('📱 Patrón convertido: $vibrationPattern');
      
      // Verificar si el dispositivo soporta patrones personalizados
      final hasCustomVibrationsSupport = await Vibration.hasCustomVibrationsSupport() ?? false;
      print('🔍 Soporte para patrones personalizados: $hasCustomVibrationsSupport');
      
      if (hasCustomVibrationsSupport) {
        // Usar el paquete vibration para reproducir el patrón
        await Vibration.vibrate(pattern: vibrationPattern);
        print('✅ Patrón reproducido con paquete vibration');
      } else {
        // Fallback: usar vibración simple repetida
        print('🔄 Dispositivo no soporta patrones, usando vibración simple repetida');
        for (int i = 0; i < vibrationPattern.length; i++) {
          if (i % 2 == 1) { // Solo vibrar en índices impares (las pausas están en pares)
            await Vibration.vibrate(duration: vibrationPattern[i]);
            if (i < vibrationPattern.length - 1) {
              await Future.delayed(Duration(milliseconds: vibrationPattern[i + 1]));
            }
          }
        }
        print('✅ Patrón simulado con vibraciones simples');
      }
      
      print('✅ Patrón de vibración reproducido exitosamente');
    } catch (e) {
      print('❌ Error al reproducir patrón de vibración: $e');
      print('❌ Stack trace: ${StackTrace.current}');
      
      // Intentar vibración simple como fallback
      try {
        print('🔄 Intentando vibración simple como fallback...');
        await Vibration.vibrate(duration: 500);
        print('✅ Vibración simple de fallback exitosa');
      } catch (fallbackError) {
        print('❌ Error en vibración de fallback: $fallbackError');
      }
    }
  }

  // Reproducir el patrón seleccionado actualmente
  static Future<void> playSelectedPattern() async {
    final pattern = await getSelectedPattern();
    if (pattern != null) {
      await playPattern(pattern);
    }
  }
  
  // Reproducir vibración simple
  static Future<void> playSimpleVibration({int duration = 500}) async {
    try {
      print('🔍 Iniciando vibración simple de ${duration}ms');
      
      // Verificar si el dispositivo soporta vibración usando el paquete vibration
      final hasVibrator = await Vibration.hasVibrator() ?? false;
      print('🔍 Dispositivo tiene vibrador: $hasVibrator');
      if (!hasVibrator) {
        print('❌ El dispositivo no soporta vibración');
        return;
      }
      
      // Verificar si la vibración está habilitada
      final isEnabled = await isVibrationEnabled();
      print('🔍 Vibración habilitada: $isEnabled');
      if (!isEnabled) {
        print('❌ La vibración está deshabilitada');
        return;
      }
      
      // Reproducir vibración simple usando el paquete vibration
      await Vibration.vibrate(duration: duration);
      
      print('✅ Vibración simple reproducida exitosamente');
    } catch (e) {
      print('❌ Error al reproducir vibración simple: $e');
      rethrow;
    }
  }
  
  // Método para probar la vibración (usado para debugging)
  static Future<void> testVibration() async {
    try {
      print('🔍 Iniciando test de vibración');
      
      // Verificar capacidades del dispositivo
      final hasVibrator = await Vibration.hasVibrator() ?? false;
      final hasAmplitudeControl = await Vibration.hasAmplitudeControl() ?? false;
      final hasCustomVibrationsSupport = await Vibration.hasCustomVibrationsSupport() ?? false;
      
      print('🔍 Capacidades del dispositivo:');
      print('  - Tiene vibrador: $hasVibrator');
      print('  - Control de amplitud: $hasAmplitudeControl');
      print('  - Patrones personalizados: $hasCustomVibrationsSupport');
      
      if (!hasVibrator) {
        print('❌ El dispositivo no tiene vibrador');
        return;
      }
      
      // Test de vibración simple
      print('🔄 Probando vibración simple...');
      await Vibration.vibrate(duration: 500);
      await Future.delayed(const Duration(milliseconds: 1000));
      
      // Test de patrón si está soportado
      if (hasCustomVibrationsSupport) {
        print('🔄 Probando patrón de vibración...');
        await Vibration.vibrate(pattern: [0, 300, 100, 300, 100, 300]);
      } else {
        print('🔄 Simulando patrón con vibraciones simples...');
        await Vibration.vibrate(duration: 300);
        await Future.delayed(const Duration(milliseconds: 100));
        await Vibration.vibrate(duration: 300);
        await Future.delayed(const Duration(milliseconds: 100));
        await Vibration.vibrate(duration: 300);
      }
      
      print('✅ Test de vibración completado');
    } catch (e) {
      print('❌ Error en test de vibración: $e');
      rethrow;
    }
  }

  // Verificar si la vibración está habilitada
  static Future<bool> isVibrationEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_vibrationEnabledKey) ?? true; // Por defecto habilitada
    } catch (e) {
      print('Error al verificar estado de vibración: $e');
      return true;
    }
  }

  // Habilitar/deshabilitar vibración
  static Future<bool> setVibrationEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_vibrationEnabledKey, enabled);
      print('✅ Vibración ${enabled ? "habilitada" : "deshabilitada"}');
      return true;
    } catch (e) {
      print('❌ Error al cambiar estado de vibración: $e');
      return false;
    }
  }

  // Generar un ID único para un nuevo patrón
  static String generatePatternId() {
    return 'pattern_${DateTime.now().millisecondsSinceEpoch}';
  }

  // Validar un patrón de vibración
  static bool isValidPattern(List<int> pattern) {
    if (pattern.isEmpty) return false;
    if (pattern.length % 2 != 0) return false; // Debe tener pares (vibrar, pausa)
    if (pattern.any((duration) => duration < 0)) return false; // No negativos
    if (pattern.any((duration) => duration > 5000)) return false; // Máximo 5 segundos por segmento
    return true;
  }

  // Limpiar todos los patrones personalizados (mantener solo el predeterminado)
  static Future<bool> clearAllCustomPatterns() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_patternsKey);
      await setSelectedPattern('default');
      print('✅ Todos los patrones personalizados eliminados');
      return true;
    } catch (e) {
      print('❌ Error al limpiar patrones: $e');
      return false;
    }
  }
}