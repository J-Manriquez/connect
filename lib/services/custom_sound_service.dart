import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart';

class CustomSound {
  final String id;
  final String name;
  final String filePath;
  final DateTime createdAt;
  final bool isDefault;
  final int duration; // Duración en milisegundos
  final String fileName;

  CustomSound({
    required this.id,
    required this.name,
    required this.filePath,
    required this.createdAt,
    this.isDefault = false,
    this.duration = 0,
    String? fileName,
  }) : fileName = fileName ?? name;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'filePath': filePath,
      'createdAt': createdAt.toIso8601String(),
      'isDefault': isDefault,
      'duration': duration,
      'fileName': fileName,
    };
  }

  factory CustomSound.fromJson(Map<String, dynamic> json) {
    return CustomSound(
      id: json['id'],
      name: json['name'],
      filePath: json['filePath'],
      createdAt: DateTime.parse(json['createdAt']),
      isDefault: json['isDefault'] ?? false,
      duration: json['duration'] ?? 0,
      fileName: json['fileName'],
    );
  }
}

class CustomSoundService {
  static const String _soundsKey = 'custom_sounds';
  static const String _selectedSoundKey = 'selected_custom_sound';
  static const String _soundEnabledKey = 'custom_sound_enabled';
  
  // Canal para comunicación con el código nativo
  static const MethodChannel _channel = MethodChannel('com.example.connect/local_notifications');

  // Sonido predeterminado (sistema)
  static CustomSound get defaultSound => CustomSound(
    id: 'default',
    name: 'Sonido del Sistema',
    filePath: 'system_default',
    createdAt: DateTime.now(),
    isDefault: true,
    duration: 1000,
    fileName: 'Sonido del Sistema',
  );

  // Obtener todos los sonidos guardados
  static Future<List<CustomSound>> getAllSounds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final soundsJson = prefs.getString(_soundsKey);
      
      List<CustomSound> sounds = [defaultSound]; // Siempre incluir el predeterminado
      
      if (soundsJson != null) {
        final List<dynamic> soundsList = json.decode(soundsJson);
        final customSounds = soundsList
            .map((json) => CustomSound.fromJson(json))
            .where((sound) => !sound.isDefault) // Excluir duplicados del predeterminado
            .where((sound) => File(sound.filePath).existsSync()) // Solo archivos que existen
            .toList();
        sounds.addAll(customSounds);
      }
      
      // Ordenar por fecha de creación (más recientes primero)
      sounds.sort((a, b) {
        if (a.isDefault) return -1; // El predeterminado siempre primero
        if (b.isDefault) return 1;
        return b.createdAt.compareTo(a.createdAt);
      });
      
      return sounds;
    } catch (e) {
      // print('Error al obtener sonidos personalizados: $e');
      return [defaultSound];
    }
  }

  // Guardar un nuevo sonido
  static Future<bool> saveSound(CustomSound sound) async {
    try {
      final sounds = await getAllSounds();
      
      // Verificar que no sea el sonido predeterminado
      if (sound.isDefault) {
        // print('No se puede guardar el sonido predeterminado');
        return false;
      }
      
      // Verificar que el archivo existe
      if (!File(sound.filePath).existsSync()) {
        // print('El archivo de sonido no existe: ${sound.filePath}');
        return false;
      }
      
      // Agregar el nuevo sonido
      sounds.add(sound);
      
      // Filtrar solo los sonidos personalizados para guardar
      final customSounds = sounds.where((s) => !s.isDefault).toList();
      
      final prefs = await SharedPreferences.getInstance();
      final soundsJson = json.encode(customSounds.map((s) => s.toJson()).toList());
      
      await prefs.setString(_soundsKey, soundsJson);
      // print('✅ Sonido personalizado guardado: ${sound.name}');
      return true;
    } catch (e) {
      // print('❌ Error al guardar sonido personalizado: $e');
      return false;
    }
  }

  // Eliminar un sonido
  static Future<bool> deleteSound(String soundId) async {
    try {
      if (soundId == 'default') {
        // print('No se puede eliminar el sonido predeterminado');
        return false;
      }
      
      final sounds = await getAllSounds();
      final customSounds = sounds
          .where((s) => !s.isDefault && s.id != soundId)
          .toList();
      
      final prefs = await SharedPreferences.getInstance();
      final soundsJson = json.encode(customSounds.map((s) => s.toJson()).toList());
      
      await prefs.setString(_soundsKey, soundsJson);
      
      // Si el sonido eliminado era el seleccionado, volver al predeterminado
      final selectedSound = await getSelectedSound();
      if (selectedSound?.id == soundId) {
        await setSelectedSound('default');
      }
      
      // print('✅ Sonido personalizado eliminado: $soundId');
      return true;
    } catch (e) {
      // print('❌ Error al eliminar sonido personalizado: $e');
      return false;
    }
  }

  // Obtener el sonido seleccionado actualmente
  static Future<CustomSound?> getSelectedSound() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final selectedId = prefs.getString(_selectedSoundKey) ?? 'default';
      
      final sounds = await getAllSounds();
      return sounds.firstWhere(
        (sound) => sound.id == selectedId,
        orElse: () => defaultSound,
      );
    } catch (e) {
      // print('Error al obtener sonido seleccionado: $e');
      return defaultSound;
    }
  }

  // Establecer el sonido seleccionado
  static Future<bool> setSelectedSound(String soundId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_selectedSoundKey, soundId);
      // print('✅ Sonido personalizado seleccionado: $soundId');
      return true;
    } catch (e) {
      // print('❌ Error al seleccionar sonido personalizado: $e');
      return false;
    }
  }

  // Instancia global del reproductor de audio
  static final AudioPlayer _audioPlayer = AudioPlayer();

  // Reproducir un sonido personalizado
  static Future<void> playSound(CustomSound sound) async {
    try {
      // print('🔍 Iniciando reproducción de sonido: ${sound.name}');
      
      // Verificar si el sonido personalizado está habilitado
      final isEnabled = await isSoundEnabled();
      // print('🔍 Sonido personalizado habilitado: $isEnabled');
      if (!isEnabled) {
        // print('❌ El sonido personalizado está deshabilitado');
        return;
      }
      
      // Detener cualquier sonido que esté reproduciéndose
      await _audioPlayer.stop();
      
      if (sound.isDefault) {
        // Usar el sonido del sistema a través del SoundNotificationService
        // print('🔊 Reproduciendo sonido del sistema');
        await _channel.invokeMethod('playNotificationSound');
      } else {
        // Verificar que el archivo existe
        if (!File(sound.filePath).existsSync()) {
          // print('❌ El archivo de sonido no existe: ${sound.filePath}');
          // Fallback al sonido del sistema
          await _channel.invokeMethod('playNotificationSound');
          return;
        }
        
        // Reproducir archivo personalizado usando audioplayers
        // print('🔊 Reproduciendo sonido personalizado: ${sound.filePath}');
        await _audioPlayer.play(DeviceFileSource(sound.filePath));
      }
      
      // print('✅ Sonido reproducido exitosamente');
    } catch (e) {
      // print('❌ Error al reproducir sonido: $e');
      
      // Fallback al sonido del sistema
      try {
        // print('🔄 Intentando sonido del sistema como fallback...');
        await _channel.invokeMethod('playNotificationSound');
        // print('✅ Sonido del sistema de fallback exitoso');
      } catch (fallbackError) {
        // print('❌ Error en sonido de fallback: $fallbackError');
      }
    }
  }

  // Reproducir el sonido seleccionado actualmente
  static Future<void> playSelectedSound() async {
    final sound = await getSelectedSound();
    if (sound != null) {
      await playSound(sound);
    }
  }

  // Verificar si el sonido personalizado está habilitado
  static Future<bool> isSoundEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_soundEnabledKey) ?? true; // Por defecto habilitado
    } catch (e) {
      // print('Error al verificar estado de sonido: $e');
      return true;
    }
  }

  // Habilitar/deshabilitar sonido personalizado
  static Future<bool> setSoundEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_soundEnabledKey, enabled);
      // print('✅ Sonido personalizado ${enabled ? "habilitado" : "deshabilitado"}');
      return true;
    } catch (e) {
      // print('❌ Error al cambiar estado de sonido: $e');
      return false;
    }
  }

  // Generar un ID único para un nuevo sonido
  static String generateSoundId() {
    return 'sound_${DateTime.now().millisecondsSinceEpoch}';
  }

  // Verificar permisos de almacenamiento
  static Future<bool> checkStoragePermission() async {
    try {
      // Para Android 13+ (API 33+), usar permisos específicos de media
      if (Platform.isAndroid) {
        // Verificar permiso de audio específico para Android 13+
        final audioStatus = await Permission.audio.status;
        if (audioStatus.isGranted) {
          return true;
        }
        
        // Intentar solicitar permiso de audio
        final audioResult = await Permission.audio.request();
        if (audioResult.isGranted) {
          return true;
        }
        
        // Fallback a permiso de almacenamiento general
        final storageStatus = await Permission.storage.status;
        if (storageStatus.isGranted) {
          return true;
        }
        
        final storageResult = await Permission.storage.request();
        return storageResult.isGranted;
      }
      
      // Para otras plataformas
      final status = await Permission.storage.status;
      if (status.isGranted) {
        return true;
      }
      
      final result = await Permission.storage.request();
      return result.isGranted;
    } catch (e) {
      // print('Error al verificar permisos de almacenamiento: $e');
      return false;
    }
  }

  // Obtener información de un archivo de audio
  static Future<Map<String, dynamic>?> getAudioFileInfo(String filePath) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        return null;
      }
      
      final stat = await file.stat();
      final fileName = file.path.split('/').last;
      final extension = fileName.split('.').last.toLowerCase();
      
      // Verificar que sea un archivo de audio válido
      final validExtensions = ['mp3', 'wav', 'ogg', 'm4a', 'aac', 'flac'];
      if (!validExtensions.contains(extension)) {
        return null;
      }
      
      return {
        'name': fileName,
        'size': stat.size,
        'extension': extension,
        'modified': stat.modified,
      };
    } catch (e) {
      // print('Error al obtener información del archivo: $e');
      return null;
    }
  }

  // Limpiar todos los sonidos personalizados (mantener solo el predeterminado)
  static Future<bool> clearAllCustomSounds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_soundsKey);
      await setSelectedSound('default');
      // print('✅ Todos los sonidos personalizados eliminados');
      return true;
    } catch (e) {
      // print('❌ Error al limpiar sonidos: $e');
      return false;
    }
  }

  // Validar archivo de sonido
  static bool isValidAudioFile(String filePath) {
    try {
      final file = File(filePath);
      if (!file.existsSync()) return false;
      
      final extension = filePath.split('.').last.toLowerCase();
      final validExtensions = ['mp3', 'wav', 'ogg', 'm4a', 'aac', 'flac'];
      
      return validExtensions.contains(extension);
    } catch (e) {
      return false;
    }
  }

  // Agregar un nuevo sonido desde un archivo
  static Future<bool> addSound(String filePath, String displayName) async {
    try {
      // Validar el archivo
      if (!isValidAudioFile(filePath)) {
        // print('❌ Archivo de audio inválido: $filePath');
        return false;
      }

      // Obtener información del archivo
      final fileInfo = await getAudioFileInfo(filePath);
      if (fileInfo == null) {
        // print('❌ No se pudo obtener información del archivo');
        return false;
      }

      // Crear el objeto CustomSound
      final sound = CustomSound(
        id: generateSoundId(),
        name: displayName,
        filePath: filePath,
        createdAt: DateTime.now(),
        isDefault: false,
        duration: 0, // Se podría calcular la duración real si es necesario
        fileName: fileInfo['name'],
      );

      // Guardar el sonido
      return await saveSound(sound);
    } catch (e) {
      // print('❌ Error al agregar sonido: $e');
      return false;
    }
  }

  // Obtener un sonido por su ID
  static Future<CustomSound?> getSoundById(String soundId) async {
    try {
      final sounds = await getAllSounds();
      return sounds.firstWhere(
        (sound) => sound.id == soundId,
        orElse: () => defaultSound,
      );
    } catch (e) {
      // print('Error al obtener sonido por ID: $e');
      return null;
    }
  }
}