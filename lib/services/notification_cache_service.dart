import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class NotificationCacheService {
  static const String _processedNotificationsKey = 'processed_notifications';
  static const String _preExistingNotificationsKey = 'pre_existing_notifications';
  static const String _visualizedNotificationsKey = 'visualized_notifications';
  
  // Máximo de notificaciones en caché para evitar problemas de memoria
  static const int _maxCacheSize = 1000;
  
  // Registrar notificaciones que existían antes de la vinculación
  static Future<void> registerPreExistingNotifications(Set<String> notificationIds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_preExistingNotificationsKey, notificationIds.toList());
    print('NotificationCacheService: ${notificationIds.length} notificaciones pre-existentes registradas');
  }
  
  // Verificar si una notificación existía antes de la vinculación
  static Future<bool> isPreExisting(String notificationId) async {
    final prefs = await SharedPreferences.getInstance();
    final preExisting = prefs.getStringList(_preExistingNotificationsKey) ?? [];
    return preExisting.contains(notificationId);
  }
  
  // Marcar una notificación como procesada (mostrada localmente)
  static Future<void> markAsProcessed(String notificationId) async {
    final prefs = await SharedPreferences.getInstance();
    final processed = prefs.getStringList(_processedNotificationsKey) ?? [];
    
    if (!processed.contains(notificationId)) {
      processed.add(notificationId);
      
      // Limitar el tamaño del caché
      if (processed.length > _maxCacheSize) {
        processed.removeRange(0, processed.length - _maxCacheSize);
      }
      
      await prefs.setStringList(_processedNotificationsKey, processed);
    }
  }
  
  // Verificar si una notificación ya fue procesada
  static Future<bool> isProcessed(String notificationId) async {
    final prefs = await SharedPreferences.getInstance();
    final processed = prefs.getStringList(_processedNotificationsKey) ?? [];
    return processed.contains(notificationId);
  }
  
  // Marcar una notificación como visualizada
  static Future<void> markAsVisualized(String notificationId) async {
    final prefs = await SharedPreferences.getInstance();
    final visualized = prefs.getStringList(_visualizedNotificationsKey) ?? [];
    
    if (!visualized.contains(notificationId)) {
      visualized.add(notificationId);
      
      // Limitar el tamaño del caché
      if (visualized.length > _maxCacheSize) {
        visualized.removeRange(0, visualized.length - _maxCacheSize);
      }
      
      await prefs.setStringList(_visualizedNotificationsKey, visualized);
    }
  }
  
  // Verificar si una notificación ya fue visualizada
  static Future<bool> isVisualized(String notificationId) async {
    final prefs = await SharedPreferences.getInstance();
    final visualized = prefs.getStringList(_visualizedNotificationsKey) ?? [];
    return visualized.contains(notificationId);
  }
  
  // Limpiar cachés antiguos (llamar periódicamente)
  static Future<void> cleanOldCache() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Limpiar notificaciones procesadas más antiguas
    final processed = prefs.getStringList(_processedNotificationsKey) ?? [];
    if (processed.length > _maxCacheSize ~/ 2) {
      final newProcessed = processed.sublist(processed.length - (_maxCacheSize ~/ 2));
      await prefs.setStringList(_processedNotificationsKey, newProcessed);
    }
    
    // Limpiar notificaciones visualizadas más antiguas
    final visualized = prefs.getStringList(_visualizedNotificationsKey) ?? [];
    if (visualized.length > _maxCacheSize ~/ 2) {
      final newVisualized = visualized.sublist(visualized.length - (_maxCacheSize ~/ 2));
      await prefs.setStringList(_visualizedNotificationsKey, newVisualized);
    }
    
    print('NotificationCacheService: Caché limpiado');
  }
}