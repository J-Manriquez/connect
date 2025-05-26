import 'package:connect/screens/receptor/receptor_screen.dart';
import 'package:connect/screens/receptor/notificaciones_screen.dart'; // Añadir esta importación
import 'package:connect/services/notification_filter_service.dart';
import 'package:connect/services/receptor_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import for MethodChannel
import 'package:connect/services/notification_filter_service.dart'; // Añadir esta importación
import 'package:connect/services/preferences_service.dart'; // Añadir esta importación
import 'package:firebase_core/firebase_core.dart';
import 'package:connect/firebase_options.dart';
import 'package:connect/services/firebase_service.dart';
import 'screens/emisor/emisor_screen.dart';
import 'screens/emisor/settings_screen.dart';
import 'screens/emisor/app_list_screen.dart';
import 'screens/receptor/receptor_settings_screen.dart';

// Añadir este import al inicio del archivo
import 'package:connect/services/local_notification_service.dart';
import 'package:connect/screens/receptor/unread_notifications_screen.dart';
import 'package:connect/screens/receptor/notification_settings_screen.dart'; // Import the new screen
import 'package:connect/theme_colors.dart';

// En el método main, añadir la inicialización del servicio de notificaciones locales
void main() async {
  // Asegurar que Flutter esté inicializado
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Inicializar el servicio de notificaciones locales
  await LocalNotificationService.initialize();

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
      _checkInitialRoute(); // Añadir esta línea
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

        // Si está habilitado el guardado en Firebase, verificar si la notificación debe guardarse
        if (_isSavingToFirebase) {
          try {
            // Obtener el packageName de la notificación
            final String packageName =
                notificationData['packageName'] as String? ?? '';

            // Verificar si la notificación debe mostrarse según las apps habilitadas
            final bool shouldShow =
                await NotificationFilterService.shouldShowNotification(
                  packageName,
                );

            // Solo guardar la notificación si debe mostrarse
            if (shouldShow) {
              await _firebaseService.saveNotification(notificationData);
              print('Notificación guardada en Firebase: $packageName');

              // Mostrar notificación local y actualizar estado de visualización
              await _showLocalNotification(notificationData);
            } else {
              print(
                'Notificación filtrada, no se guarda en Firebase: $packageName',
              );
            }
          } catch (e) {
            print('Error al guardar notificación en Firebase: $e');
            // En caso de error, NO guardar la notificación
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

  // Método para verificar la ruta inicial según las preferencias del usuario
  Future<void> _checkInitialRoute() async {
    try {
      print('[DEBUG] _checkInitialRoute: Start');
      final receptorService = ReceptorService();
      final deviceId = await receptorService.getLinkedDeviceId();
      print(
        '[DEBUG] _checkInitialRoute: deviceId from SharedPreferences = \$deviceId',
      );
      final linkStatus = await _firebaseService.getLinkStatus();
      print(
        '[DEBUG] _checkInitialRoute: linkStatus from Firebase = $linkStatus',
      );
      if (linkStatus) {
        print('[DEBUG] _checkInitialRoute: Navigating to /notificaciones');
        Navigator.pushReplacementNamed(context, '/notificaciones');
        print('[DEBUG] _checkInitialRoute: Navigation to /notificaciones done');
        return;
      }
      final useAsReceptor = await PreferencesService.getUseAsReceptor();
      print(
        '[DEBUG] _checkInitialRoute: useAsReceptor = \$useAsReceptor, _isPermissionGranted = \$_isPermissionGranted',
      );
      if (useAsReceptor && _isPermissionGranted) {
        print('[DEBUG] _checkInitialRoute: Navigating to /receptor');
        Navigator.pushReplacementNamed(context, '/receptor');
      }
      print('[DEBUG] _checkInitialRoute: Staying on EmisorScreen');
    } catch (e, stack) {
      print('Error al verificar ruta inicial: $e');
      print('Stacktrace: $stack');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Connect',
      theme: ThemeData(
        primarySwatch: customColor, // Usando el MaterialColor personalizado
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: customColor,
          accentColor: customColor[900],
        ),
        useMaterial3: true,
        // Añadir o modificar appBarTheme aquí
        appBarTheme: AppBarTheme(
          backgroundColor: customColor[700], // Color de fondo del AppBar
          foregroundColor: Colors.white, // Color de los iconos y texto del AppBar
          titleTextStyle: TextStyle(
            color: Colors.white, // Color del título del AppBar
            fontSize: 20, // Ajusta el tamaño de fuente si es necesario
            fontWeight: FontWeight.bold, // Ajusta el peso de fuente si es necesario
          ),
          centerTitle: true, // Centrar el título del AppBar
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => EmisorScreen(
          notifications: _notifications,
          isServiceRunning: _isServiceRunning,
          isSavingToFirebase: _isSavingToFirebase,
          toggleSaveToFirebase: _toggleSaveToFirebase,
          checkPermissionStatus: _checkPermissionStatus,
          openNotificationSettings: _openNotificationSettings,
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
        '/receptor': (context) => const ReceptorScreen(),
        '/notificaciones': (context) => const NotificacionesScreen(),
        '/receptor_settings': (context) => const ReceptorSettingsScreen(),
        '/unread_notifications': (context) =>
            const UnreadNotificationsScreen(), // Añadir esta nueva ruta
        '/notification_settings': (context) =>
            const NotificationSettingsScreen(), // Add the new route
      },
    );
  }
}

// Método para mostrar notificaciones locales y actualizar estado de visualización
Future<void> _showLocalNotification(Map<String, dynamic> notification) async {
  try {
    // Mostrar la notificación local
    await LocalNotificationService.showNotification(
      title: notification['title'] ?? 'Nueva notificación',
      body: notification['text'] ?? '',
      packageName: notification['packageName'] ?? '',
      appName: notification['appName'] ?? 'Desconocida',
    );

    // Actualizar el estado de visualización a true
    final String notificationId = notification['id'] ?? '';
    if (notificationId.isNotEmpty) {
      // Usar ReceptorService para actualizar el estado
      final ReceptorService receptorService = ReceptorService();
      await receptorService.updateNotificationVisualizationStatus(
        notificationId,
        true,
      );
      print('Notificación marcada como visualizada: $notificationId');
    }
  } catch (e) {
    print('Error al mostrar notificación local: $e');
  }
}
