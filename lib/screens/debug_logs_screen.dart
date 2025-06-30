import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../services/local_notification_service.dart';
import '../theme_colors.dart';

class DebugLogsScreen extends StatefulWidget {
  const DebugLogsScreen({Key? key}) : super(key: key);

  @override
  State<DebugLogsScreen> createState() => _DebugLogsScreenState();
}

class _DebugLogsScreenState extends State<DebugLogsScreen> {
  List<String> _logs = [];
  bool _isAutoScrollEnabled = true;
  final ScrollController _scrollController = ScrollController();
  Timer? _logTimer;
  
  // Configuración actual
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _screenWakeEnabled = false;
  bool _autoOpenEnabled = false;
  bool _notificationsEnabled = true;
  
  // Canal para comunicación con Android
  static const MethodChannel _channel = MethodChannel('com.example.connect/debug_logs');

  @override
  void initState() {
    super.initState();
    _loadConfiguration();
    _addLog('=== DEBUG LOGS INICIADO ===');
    _addLog('Pantalla de debugging para Android 8.0');
    _addLog('Monitoreando configuración de notificaciones...');
    _startLogMonitoring();
  }

  @override
  void dispose() {
    _logTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _addLog(String message) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    setState(() {
      _logs.add('[$timestamp] $message');
      if (_logs.length > 500) {
        _logs.removeAt(0); // Mantener solo los últimos 500 logs
      }
    });
    
    if (_isAutoScrollEnabled && _scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      });
    }
  }

  Future<void> _loadConfiguration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      setState(() {
        _soundEnabled = prefs.getBool(LocalNotificationService.KEY_SOUND_ENABLED) ?? true;
        _vibrationEnabled = prefs.getBool(LocalNotificationService.KEY_VIBRATION_ENABLED) ?? true;
        _screenWakeEnabled = prefs.getBool(LocalNotificationService.KEY_SCREEN_WAKE_ENABLED) ?? false;
        _autoOpenEnabled = prefs.getBool(LocalNotificationService.KEY_AUTO_OPEN_ENABLED) ?? false;
        _notificationsEnabled = prefs.getBool(LocalNotificationService.KEY_NOTIFICATIONS_ENABLED) ?? true;
      });
      
      _addLog('=== CONFIGURACIÓN ACTUAL ===');
      _addLog('Notificaciones habilitadas: $_notificationsEnabled');
      _addLog('Sonido habilitado: $_soundEnabled');
      _addLog('Vibración habilitada: $_vibrationEnabled');
      _addLog('Screen Wake habilitado: $_screenWakeEnabled');
      _addLog('Auto Open habilitado: $_autoOpenEnabled');
      _addLog('Todas las claves: ${prefs.getKeys()}');
      _addLog('============================');
      
    } catch (e) {
      _addLog('ERROR al cargar configuración: $e');
    }
  }

  void _startLogMonitoring() {
    // Monitorear logs cada 2 segundos
    _logTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _captureAndroidLogs();
    });
  }
  
  Future<void> _captureAndroidLogs() async {
    try {
      // Intentar capturar logs del sistema Android relacionados con notificaciones
      final result = await _channel.invokeMethod('getRecentLogs');
      if (result != null && result is List) {
        for (String log in result) {
          if (log.contains('LocalNotificationManager') || 
              log.contains('DeviceFinderManager') ||
              log.contains('NotificationManager') ||
              log.contains('screenWakeEnabled') ||
              log.contains('PRIORITY') ||
              log.contains('IMPORTANCE')) {
            _addLog('[ANDROID] $log');
          }
        }
      }
    } catch (e) {
      // Silencioso - no todos los dispositivos permiten acceso a logs
    }
  }

  Future<void> _testNotification() async {
    _addLog('=== INICIANDO PRUEBA DE NOTIFICACIÓN ===');
    
    try {
      await LocalNotificationService.showNotification(
        title: 'Prueba Debug',
        body: 'Notificación de prueba para debugging Android 8.0',
        packageName: 'com.example.connect',
        appName: 'Connect Debug',
        notificationId: 'debug_test_${DateTime.now().millisecondsSinceEpoch}',
      );
      
      _addLog('Notificación de prueba enviada exitosamente');
      
      // Esperar un momento y capturar logs
      await Future.delayed(const Duration(milliseconds: 500));
      await _captureAndroidLogs();
    } catch (e) {
      _addLog('ERROR en notificación de prueba: $e');
    }
  }
  
  Future<void> _testDeviceFinder() async {
    _addLog('=== INICIANDO PRUEBA DE DEVICE FINDER ===');
    
    try {
      // Simular activación de device finder
      const MethodChannel deviceFinderChannel = MethodChannel('com.example.connect/device_finder');
      await deviceFinderChannel.invokeMethod('startDeviceSearch');
      
      _addLog('Device Finder iniciado para prueba');
      
      // Esperar un momento y capturar logs
      await Future.delayed(const Duration(milliseconds: 500));
      await _captureAndroidLogs();
    } catch (e) {
      _addLog('ERROR en prueba de Device Finder: $e');
    }
  }

  void _clearLogs() {
    setState(() {
      _logs.clear();
    });
    _addLog('Logs limpiados');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Debug Logs - Android 8.0',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(_isAutoScrollEnabled ? Icons.pause : Icons.play_arrow),
            onPressed: () {
              setState(() {
                _isAutoScrollEnabled = !_isAutoScrollEnabled;
              });
              _addLog('Auto-scroll ${_isAutoScrollEnabled ? "habilitado" : "deshabilitado"}');
            },
          ),
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: _clearLogs,
          ),
        ],
      ),
      body: Column(
        children: [
          // Panel de configuración actual
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Configuración Actual:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Notificaciones: ${_notificationsEnabled ? "✅" : "❌"}'),
                          Text('Sonido: ${_soundEnabled ? "✅" : "❌"}'),
                          Text('Vibración: ${_vibrationEnabled ? "✅" : "❌"}'),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Screen Wake: ${_screenWakeEnabled ? "✅" : "❌"}'),
                          Text('Auto Open: ${_autoOpenEnabled ? "✅" : "❌"}'),
                          Text('Android API: ${Theme.of(context).platform}'),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: _loadConfiguration,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Recargar Config'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _testNotification,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Probar Notificación'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _testDeviceFinder,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Probar Device Finder'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Lista de logs
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(8),
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  final log = _logs[index];
                  Color textColor = Colors.white;
                  
                  // Colorear logs según el tipo
                  if (log.contains('ERROR')) {
                    textColor = Colors.red;
                  } else if (log.contains('WARNING')) {
                    textColor = Colors.orange;
                  } else if (log.contains('✅') || log.contains('exitosamente')) {
                    textColor = Colors.green;
                  } else if (log.contains('===')) {
                    textColor = Colors.cyan;
                  }
                  
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Text(
                      log,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}