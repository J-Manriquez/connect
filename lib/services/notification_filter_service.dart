import 'package:flutter/services.dart';
import 'package:connect/models/device_data.dart';
import 'package:connect/services/firebase_service.dart';

class NotificationFilterService {
  static const platform = MethodChannel('com.example.connect/app_list');
  
  // Cache para almacenar los paquetes habilitados y reducir llamadas nativas
  static List<dynamic>? _cachedEnabledPackages;
  static DateTime _lastCacheUpdate = DateTime.fromMillisecondsSinceEpoch(0);
  static final FirebaseService _firebaseService = FirebaseService();
  
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
    
    // Intentar obtener la lista de apps desde Firebase
    try {
      final List<AppData> appList = await _firebaseService.getAppList();
      if (appList.isNotEmpty) {
        // Filtrar solo las apps activas y obtener sus packageNames
        final List<String> enabledPackages = appList
            .where((app) => app.activa)
            .map((app) => app.packageName)
            .toList();
        
        // Actualizar la caché
        _cachedEnabledPackages = enabledPackages;
        _lastCacheUpdate = now;
        
        return enabledPackages;
      }
    } catch (e) {
      print('Error al obtener lista de apps desde Firebase: $e');
    }
    
    // Si no hay datos en Firebase o hubo un error, usar el método nativo
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
  
  // Método para sincronizar las apps habilitadas con Firebase
  static Future<void> syncEnabledAppsWithFirebase() async {
    try {
      print('Iniciando sincronización con Firebase...');
      
      // Obtener los paquetes habilitados desde el dispositivo
      final List<dynamic> nativeEnabledPackages = await platform.invokeMethod('getEnabledPackages');
      print('Paquetes habilitados obtenidos: ${nativeEnabledPackages.length}');
      
      // Obtener todas las aplicaciones instaladas
      final List<dynamic> result = await platform.invokeMethod('getInstalledApps');
      final List<Map<String, dynamic>> allPackages = result.map((item) {
        return Map<String, dynamic>.from(item as Map);
      }).toList();
      
      print('Total de paquetes obtenidos: ${allPackages.length}');
      
      if (allPackages.isEmpty) {
        print('No se encontraron aplicaciones para sincronizar');
        return;
      }
      
      // Convertir a lista de AppData
      final List<AppData> appList = [];
      for (final package in allPackages) {
        appList.add(AppData(
          nombre: package['appName'] ?? '',
          packageName: package['packageName'] ?? '',
          activa: nativeEnabledPackages.contains(package['packageName']),
        ));
      }
      
      print('Sincronizando ${appList.length} aplicaciones con Firebase');
      
      // Guardar en Firebase
      await _firebaseService.updateAppList(appList);
      
      // Actualizar la caché
      _cachedEnabledPackages = nativeEnabledPackages;
      _lastCacheUpdate = DateTime.now();
      
      print('Sincronización con Firebase completada exitosamente');
      
    } catch (e) {
      print('Error al sincronizar apps con Firebase: $e');
    }
  }
}