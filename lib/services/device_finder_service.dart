import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:connect/services/device_search_service.dart';
import 'package:connect/services/preferences_service.dart';

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
    // Configurar el manejador para navegación desde nativo
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  // Manejar llamadas desde el canal nativo
  static Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'navigateToRoute':
        final String route = call.arguments as String;
        // print('DeviceFinderService: Navegación solicitada a $route');
        
        if (navigatorKey?.currentState != null) {
          try {
            navigatorKey!.currentState!.pushNamed(route);
            // print('DeviceFinderService: Navegación exitosa a $route');
          } catch (e) {
            // print('DeviceFinderService: Error navegando a $route: $e');
          }
        } else {
          // print('DeviceFinderService: NavigatorKey no disponible');
        }
        break;
      default:
        // print('DeviceFinderService: Método no implementado: ${call.method}');
    }
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
      
      // print('DeviceFinderService: Búsqueda de dispositivo iniciada');
      
      // Auto-detener después de 30 segundos si no se detiene manualmente
      _searchTimer = Timer(const Duration(seconds: 30), () {
        stopDeviceSearch();
      });
      
    } catch (e) {
      // print('Error al iniciar búsqueda de dispositivo: $e');
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
      
      // ✅ Resetear el campo correspondiente en Firebase
      try {
        final bool disableAutoRedirect = await PreferencesService.getDisableAutoRedirect();
        
        if (disableAutoRedirect) {
          // Es receptor, resetear buscar-receptor en el dispositivo emisor
          await DeviceSearchService.instance.resetBuscarReceptor();
          // print('DeviceFinderService: Campo buscar-receptor reseteado (dispositivo receptor)');
        } else {
          // Es emisor, resetear buscar-emisor en el dispositivo receptor
          await DeviceSearchService.instance.resetBuscarEmisor();
          // print('DeviceFinderService: Campo buscar-emisor reseteado (dispositivo emisor)');
        }
      } catch (e) {
        // print('DeviceFinderService: Error al resetear campos de Firebase: $e');
      }
      
      // print('DeviceFinderService: Búsqueda de dispositivo detenida');
    } catch (e) {
      // print('Error al detener búsqueda de dispositivo: $e');
    }
  }



  // Test de vibración para diagnóstico
  Future<void> testVibration() async {
    try {
      await _channel.invokeMethod('testVibration');
      // print('DeviceFinderService: Test de vibración ejecutado');
    } catch (e) {
      // print('Error al ejecutar test de vibración: $e');
    }
  }

  // Verificar si está buscando
  bool get isSearching => _isSearching;
}