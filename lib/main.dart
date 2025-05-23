import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import for MethodChannel
import 'screens/emisor_screen.dart';
import 'screens/settings_screen.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  // Define the MethodChannel
  static const platform = MethodChannel('com.example.connect/notifications');

  // List to hold received notifications
  List<Map<String, dynamic>> _notifications = [];
  bool _isServiceRunning = false;
  bool _isPermissionGranted = false;

  @override
  void initState() {
    super.initState();
    // Set up the method call handler to receive notifications from native
    platform.setMethodCallHandler(_handleMethodCall);
    // Verificar el estado inicial del servicio y el permiso
    _checkServiceStatus();
    _checkPermissionStatus();
    
    // Intentar iniciar el servicio automáticamente si no está corriendo
    // y el permiso está concedido
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoStartServiceIfNeeded();
    });
  }

  // Método para iniciar automáticamente el servicio si es necesario
  Future<void> _autoStartServiceIfNeeded() async {
    if (!_isServiceRunning && _isPermissionGranted) {
      await _startService();
    }
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onNotificationReceived':
        // Received a new notification
        final notificationData = Map<String, dynamic>.from(call.arguments);
        setState(() {
          _notifications.add(notificationData);
        });
        print('Received notification: $notificationData');
        break;
      case 'serviceConnected':
        setState(() {
          _isServiceRunning = true;
        });
        print('Notification service connected.');
        break;
      case 'serviceDisconnected':
        setState(() {
          _isServiceRunning = false;
        });
        print('Notification service disconnected.');
        break;
      default:
        print('Unknown method ${call.method}');
    }
  }

  // Método para verificar si el permiso está concedido
  Future<void> _checkPermissionStatus() async {
    try {
      final bool isEnabled = await platform.invokeMethod('isNotificationServiceEnabled');
      setState(() {
        _isPermissionGranted = isEnabled;
      });
      print('Permission granted: $_isPermissionGranted');
    } on PlatformException catch (e) {
      print("Failed to check permission status: '${e.message}'.");
    }
  }

  // Método para verificar si el servicio está corriendo
  Future<void> _checkServiceStatus() async {
    try {
      final bool isRunning = await platform.invokeMethod('isServiceRunning');
      setState(() {
        _isServiceRunning = isRunning;
      });
      print('Service running: $_isServiceRunning');
    } on PlatformException catch (e) {
      print("Failed to check service status: '${e.message}'.");
    }
  }

  // Método para iniciar el servicio
  Future<void> _startService() async {
    try {
      // La llamada nativa verificará el permiso y abrirá la configuración si es necesario
      final bool started = await platform.invokeMethod('startNotificationService');
      if (started) {
        print('Service start intent sent.');
        // El estado _isServiceRunning se actualizará cuando el servicio llame a serviceConnected
      } else {
        print('Permission not granted, opened settings.');
        // El estado _isPermissionGranted se actualizará después de que el usuario regrese de settings
        // Puedes añadir un listener para cuando la app vuelve a primer plano si necesitas verificar inmediatamente
      }
    } on PlatformException catch (e) {
      print("Failed to start service: '${e.message}'.");
    }
  }

  // Método para detener el servicio
  Future<void> _stopService() async {
    try {
      await platform.invokeMethod('stopNotificationService');
      print('Service stop intent sent.');
      // El estado _isServiceRunning se actualizará cuando el servicio llame a serviceDisconnected o onDestroy
    } on PlatformException catch (e) {
      print("Failed to stop service: '${e.message}'.");
    }
  }

  // Método para abrir la configuración de escucha de notificaciones
  Future<void> _openNotificationSettings() async {
    try {
      await platform.invokeMethod('openNotificationSettings');
      print('Opened notification settings.');
      // Puedes añadir un listener para cuando la app vuelve a primer plano para verificar el permiso después
    } on PlatformException catch (e) {
      print("Failed to open settings: '${e.message}'.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Connect',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => EmisorScreen(
              notifications: _notifications,
              isServiceRunning: _isServiceRunning,
            ),
        '/settings': (context) => SettingsScreen(
              isServiceRunning: _isServiceRunning,
              isPermissionGranted: _isPermissionGranted,
              checkPermissionStatus: _checkPermissionStatus,
              openNotificationSettings: _openNotificationSettings,
              startService: _startService,
              stopService: _stopService,
            ),
      },
    );
  }
}
