import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'dart:async';

class DeviceFinderService {
  static final DeviceFinderService _instance = DeviceFinderService._internal();
  factory DeviceFinderService() => _instance;
  static DeviceFinderService get instance => _instance;
  DeviceFinderService._internal();

  static const MethodChannel _channel = MethodChannel('com.example.connect/device_finder');
  static GlobalKey<NavigatorState>? navigatorKey;
  
  bool _isSearching = false;
  Timer? _searchTimer;

  // Configurar la clave de navegación global
  static void setNavigatorKey(GlobalKey<NavigatorState> key) {
    navigatorKey = key;
  }

  // Iniciar búsqueda de dispositivo
  Future<void> startDeviceSearch() async {
    if (_isSearching) return;
    
    try {
      _isSearching = true;
      
      // Activar sonido, vibración y encender pantalla
      await _channel.invokeMethod('startDeviceSearch');
      
      // Navegar a la pantalla de búsqueda
      if (navigatorKey?.currentState != null) {
        navigatorKey!.currentState!.pushNamed('/buscar_dispositivo');
      }
      
      print('DeviceFinderService: Búsqueda de dispositivo iniciada');
      
      // Auto-detener después de 30 segundos si no se detiene manualmente
      _searchTimer = Timer(const Duration(seconds: 30), () {
        stopDeviceSearch();
      });
      
    } catch (e) {
      print('Error al iniciar búsqueda de dispositivo: $e');
      _isSearching = false;
    }
  }

  // Detener búsqueda de dispositivo
  Future<void> stopDeviceSearch() async {
    if (!_isSearching) return;
    
    try {
      // Detener sonido y vibración
      await _channel.invokeMethod('stopDeviceSearch');
      
      _isSearching = false;
      _searchTimer?.cancel();
      _searchTimer = null;
      
      print('DeviceFinderService: Búsqueda de dispositivo detenida');
    } catch (e) {
      print('Error al detener búsqueda de dispositivo: $e');
    }
  }

  // Verificar si está buscando
  bool get isSearching => _isSearching;
}