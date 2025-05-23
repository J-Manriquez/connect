import 'package:flutter/services.dart';

class NotificationFilterService {
  static const platform = MethodChannel('com.example.connect/app_list');
  
  // Cache para almacenar los paquetes habilitados y reducir llamadas nativas
  static List<dynamic>? _cachedEnabledPackages;
  static DateTime _lastCacheUpdate = DateTime.fromMillisecondsSinceEpoch(0);
  
  // Método para filtrar notificaciones según las apps habilitadas
  static Future<List<Map<String, dynamic>>> filterNotifications(
      List<Map<String, dynamic>> notifications) async {
    try {
      // Obtener la lista de paquetes habilitados, usando caché si es reciente
      final List<dynamic> enabledPackages = await _getEnabledPackages();
      
      // Si no hay paquetes habilitados, devolver todas las notificaciones
      if (enabledPackages.isEmpty) {
        return notifications;
      }
      
      // Filtrar las notificaciones para mostrar solo las de apps habilitadas
      final filteredNotifications = notifications.where((notification) {
        final String packageName = notification['packageName'] as String? ?? '';
        return enabledPackages.contains(packageName);
      }).toList();
      
      return filteredNotifications;
    } on PlatformException catch (e) {
      print('Error al filtrar notificaciones: ${e.message}');
      // En caso de error, devolver todas las notificaciones
      return notifications;
    }
  }
  
  // Método para verificar si una notificación específica debe mostrarse
  static Future<bool> shouldShowNotification(String packageName) async {
    try {
      // Obtener la lista de paquetes habilitados
      final List<dynamic> enabledPackages = await _getEnabledPackages();
      
      // Si no hay paquetes habilitados, mostrar todas las notificaciones
      if (enabledPackages.isEmpty) {
        return true;
      }
      
      // Verificar si el paquete está en la lista de habilitados
      return enabledPackages.contains(packageName);
    } on PlatformException catch (e) {
      print('Error al verificar notificación: ${e.message}');
      // En caso de error, permitir mostrar la notificación
      return true;
    }
  }
  
  // Método privado para obtener los paquetes habilitados con caché
  static Future<List<dynamic>> _getEnabledPackages() async {
    // Si la caché es reciente (menos de 5 segundos), usarla
    final now = DateTime.now();
    if (_cachedEnabledPackages != null && 
        now.difference(_lastCacheUpdate).inSeconds < 5) {
      return _cachedEnabledPackages!;
    }
    
    // Si no hay caché o está obsoleta, obtener los paquetes del código nativo
    try {
      final List<dynamic> enabledPackages = await platform.invokeMethod('getEnabledPackages');
      
      // Actualizar la caché
      _cachedEnabledPackages = enabledPackages;
      _lastCacheUpdate = now;
      
      return enabledPackages;
    } catch (e) {
      // En caso de error, devolver la caché si existe, o una lista vacía
      return _cachedEnabledPackages ?? [];
    }
  }
  
  // Método para limpiar la caché (útil cuando se cambian las apps habilitadas)
  static void clearCache() {
    _cachedEnabledPackages = null;
  }
}