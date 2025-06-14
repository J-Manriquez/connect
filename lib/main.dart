import 'package:connect/services/notification_filter_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import for MethodChannel
import 'package:connect/services/notification_filter_service.dart'; // Añadir esta importación
import 'package:firebase_core/firebase_core.dart';
import 'package:connect/firebase_options.dart';
import 'package:connect/services/firebase_service.dart';
import 'screens/emisor_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/app_list_screen.dart';

void main() async {
  // Asegurar que Flutter esté inicializado
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

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

  // Servicio de Firebase
  final FirebaseService _firebaseService = FirebaseService();

  // List to hold received notifications
  List<Map<String, dynamic>> _notifications = [];
  bool _isServiceRunning = false;
  bool _isPermissionGranted = false;
  bool _isSavingToFirebase = false;

  @override
  void initState() {
    super.initState();
    // Set up the method call handler to receive notifications from native
    platform.setMethodCallHandler(_handleMethodCall);
    // Verificar el estado inicial del servicio y el permiso
    _checkServiceStatus();
    _checkPermissionStatus();

    // Inicializar la estructura de datos en Firebase
    _initializeFirebaseData();

    // Intentar iniciar el servicio automáticamente si no está corriendo
    // y el permiso está concedido
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoStartServiceIfNeeded();
    });
  }

  // Método para inicializar la estructura de datos en Firebase
  Future<void> _initializeFirebaseData() async {
    try {
      await _firebaseService.initializeFirebaseData(_isServiceRunning);

      // Obtener el estado de guardado desde Firebase
      _isSavingToFirebase = await _firebaseService.getSaveStatus();

      print('Estructura de datos inicializada en Firebase');
    } catch (e) {
      print('Error al inicializar datos en Firebase: $e');
    }
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

        // Si está habilitado el guardado en Firebase, guardar la notificación
        if (_isSavingToFirebase) {
          try {
            await _firebaseService.saveNotification(notificationData);
          } catch (e) {
            print('Error al guardar notificación en Firebase: $e');
          }
        }
        break;
      case 'serviceConnected':
        setState(() {
          _isServiceRunning = true;
        });
        print('Notification service connected.');

        // Actualizar el estado del servicio en Firebase
        try {
          await _firebaseService.updateServiceStatus(true);
        } catch (e) {
          print('Error al actualizar estado del servicio en Firebase: $e');
        }
        break;
      case 'serviceDisconnected':
        setState(() {
          _isServiceRunning = false;
        });
        print('Notification service disconnected.');

        // Actualizar el estado del servicio en Firebase
        try {
          await _firebaseService.updateServiceStatus(false);
        } catch (e) {
          print('Error al actualizar estado del servicio en Firebase: $e');
        }
        break;
      default:
        print('Unknown method ${call.method}');
    }
  }

  // Método para verificar si el permiso está concedido
  Future<void> _checkPermissionStatus() async {
    try {
      final bool isEnabled = await platform.invokeMethod(
        'isNotificationServiceEnabled',
      );
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
      final bool started = await platform.invokeMethod(
        'startNotificationService',
      );
      if (started) {
        print('Service start intent sent.');
        // El estado _isServiceRunning se actualizará cuando el servicio llame a serviceConnected
      } else {
        print('Permission not granted, opened settings.');
        // El estado _isPermissionGranted se actualizará después de que el usuario regrese de settings
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

  // Método para cambiar el estado de guardado en Firebase
  Future<void> _toggleSaveToFirebase(bool isSaving) async {
    try {
      // Actualizar el estado local
      setState(() {
        _isSavingToFirebase = isSaving;
      });

      // Actualizar el estado en Firebase
      await _firebaseService.updateSaveStatus(isSaving);

      // Si se activa el guardado, sincronizar la lista de apps
      if (isSaving) {
        await NotificationFilterService.syncEnabledAppsWithFirebase();
      }

      print('Estado de guardado en Firebase actualizado: $isSaving');
    } catch (e) {
      print('Error al actualizar estado de guardado en Firebase: $e');
      // Revertir el cambio local si hay error
      setState(() {
        _isSavingToFirebase = !isSaving;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Connect',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      initialRoute: '/',
      routes: {
        '/': (context) => EmisorScreen(
          notifications: _notifications,
          isServiceRunning: _isServiceRunning,
          isSavingToFirebase: _isSavingToFirebase, // Pasar el estado
          toggleSaveToFirebase: _toggleSaveToFirebase, // Pasar la función
        ),
        '/settings': (context) => SettingsScreen(
          isServiceRunning: _isServiceRunning,
          isPermissionGranted: _isPermissionGranted,
          isSavingToFirebase: _isSavingToFirebase,
          checkPermissionStatus: _checkPermissionStatus,
          openNotificationSettings: _openNotificationSettings,
          startService: _startService,
          stopService: _stopService,
          toggleSaveToFirebase: _toggleSaveToFirebase,
        ),
        '/app_list': (context) => const AppListScreen(),
      },
    );
  }
}
