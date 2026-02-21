import 'dart:async';
import 'dart:ui';
import 'package:connect/screens/buscar_emisor_screen.dart';
import 'package:connect/screens/emisor/seleccion_bl_screen.dart';
import 'package:connect/screens/receptor/conexion_screen.dart';
import 'package:connect/screens/receptor/notifications_screen.dart';
import 'package:connect/screens/receptor/receptor_ble_signal_screen.dart';
import 'package:connect/screens/receptor/notification_detail_screen.dart';
import 'package:connect/screens/receptor/receptor_screen.dart';
import 'package:connect/screens/receptor/vibration_patterns_screen.dart';
import 'package:connect/screens/receptor/create_vibration_pattern_screen.dart';
import 'package:connect/screens/receptor/custom_sound_selection_screen.dart';
import 'package:connect/screens/receptor/notification_settings_list_screen.dart';
import 'package:connect/screens/receptor/configure_notification_screen.dart';
import 'package:connect/services/notification_filter_service.dart';
import 'package:connect/services/notification_cache_service.dart';
import 'package:connect/services/notification_listener_service.dart';
import 'package:connect/services/receptor_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import for MethodChannel
import 'package:connect/services/preferences_service.dart'; // Añadir esta importación
import 'package:firebase_core/firebase_core.dart';
import 'package:connect/firebase_options.dart';
import 'package:connect/services/firebase_service.dart';
import 'screens/emisor/emisor_screen.dart';
import 'screens/emisor/settings_screen.dart';
import 'screens/emisor/app_list_screen.dart';
import 'screens/emisor/media_reproduction_screen.dart';
import 'screens/receptor/receptor_settings_screen.dart';

// Añadir este import al inicio del archivo
import 'package:connect/services/local_notification_service.dart';
import 'package:connect/theme_colors.dart';
import 'package:connect/services/device_search_service.dart';
import 'package:connect/services/device_finder_service.dart';
import 'package:connect/screens/buscar_dispositivo_screen.dart';
import 'package:connect/services/notification_sound_handler.dart';
import 'package:connect/services/ble_service.dart';

// reiniciar la app
import 'package:flutter_phoenix/flutter_phoenix.dart';

// Add this global navigator key
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// En el método main, añadir la inicialización del servicio de notificaciones locales
void main() async {
  // Asegurar que Flutter esté inicializado
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await BtHiveStorageService.ensureInitialized();

  // Inicializar el servicio de notificaciones locales
  // await LocalNotificationService.initialize();
  initializeNotificationHandling();
  // final notificationListenerService = NotificationListenerService();
  // notificationListenerService.startListening(); // Iniciar la escucha

  runApp(Phoenix(child: const MainApp()));
}

@pragma('vm:entry-point')
Future<void> btHiveMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await BtHiveStorageService.ensureInitialized();

  final btChannel = MethodChannel('com.example.connect/bt_hive_bridge');
  Future<void> sendDebug(String source, String message) async {
    try {
      await btChannel.invokeMethod('sendDebugLog', {
        'source': source,
        'message': message,
      });
    } catch (_) {}
  }
  btChannel.setMethodCallHandler((call) async {
    switch (call.method) {
      case 'onBtNotification':
        final payload = Map<String, dynamic>.from(call.arguments as Map);
        await BtHiveStorageService.enqueueBtNotification(payload);
        await BtHiveSyncService.syncOutboxToFirebase();
        return;
      case 'onBtMediaState':
        final payload = Map<String, dynamic>.from(call.arguments as Map);
        final title = (payload['title'] ?? '').toString();
        final appName = (payload['appName'] ?? '').toString();
        final pos = (payload['positionMs'] ?? '').toString();
        final dur = (payload['durationMs'] ?? '').toString();
        await sendDebug(
          'receptor_dart',
          'onBtMediaState rx title="$title" app="$appName" posMs=$pos durMs=$dur',
        );
        try {
          await BtHiveStorageService.setBtMediaState(payload);
          await sendDebug('receptor_dart', 'setBtMediaState ok');
        } catch (_) {
          await sendDebug('receptor_dart', 'setBtMediaState failed');
        }
        return;
      case 'onBtVolumeState':
        final payload = Map<String, dynamic>.from(call.arguments as Map);
        final pct = (payload['pct'] ?? '').toString();
        await sendDebug('receptor_dart', 'onBtVolumeState rx pct=$pct');
        try {
          await BtHiveStorageService.setBtVolumeState(payload);
        } catch (_) {}
        return;
      case 'onBtVisualizationUpdate':
        final payload = Map<String, dynamic>.from(call.arguments as Map);
        final deviceId = (payload['deviceId'] ?? '').toString().trim();
        final dateId = (payload['dateId'] ?? '').toString().trim();
        final notificationId = (payload['notificationId'] ?? '')
            .toString()
            .trim();
        final visualizado = payload['visualizado'] == true;

        if (deviceId.isNotEmpty &&
            dateId.isNotEmpty &&
            notificationId.isNotEmpty) {
          await FirebaseService().updateNotificationVisualizationStatusForDevice(
            deviceId,
            notificationId,
            dateId,
            visualizado,
          );
        }
        return;
      case 'syncNow':
        await BtHiveSyncService.syncOutboxToFirebase();
        return;
    }
  });
  await sendDebug('receptor_dart', 'btHiveMain_ready');

  Timer.periodic(const Duration(minutes: 1), (_) async {
    await BtHiveSyncService.syncOutboxToFirebase();
  });
}

void initializeNotificationHandling() {
  // Inicializar el manejador de sonidos personalizados
  NotificationSoundHandler.initialize();
  
  String? lastOpenedNotificationId;
  int lastOpenedAtMs = 0;

  Future<void> openDetail(Map<String, dynamic> data) async {
    final context = navigatorKey.currentContext;
    if (context == null || !context.mounted) return;

    final notificationId =
        (data['notificationId'] ?? data['id'] ?? '').toString().trim();
    final now = DateTime.now().millisecondsSinceEpoch;
    if (notificationId.isNotEmpty) {
      if (notificationId == lastOpenedNotificationId &&
          (now - lastOpenedAtMs) < 1500) {
        return;
      }

      final alreadyVisualized = data['status-visualizacion'] == true ||
          await NotificationCacheService.isVisualized(notificationId);
      if (alreadyVisualized) return;

      lastOpenedNotificationId = notificationId;
      lastOpenedAtMs = now;
    }

    final freshContext = navigatorKey.currentContext;
    if (freshContext == null || !freshContext.mounted) return;

    Navigator.of(freshContext).push(
      MaterialPageRoute(
        builder: (context) => NotificationDetailScreen(notificationData: data),
      ),
    );
  }

  // Configurar el callback para manejar cuando se toca una notificación
  LocalNotificationService.onNotificationTapped = (Map<String, dynamic> data) {
    // print('Notificación tocada: $data');

    // Navegar a la pantalla de detalle cuando se toca una notificación
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(openDetail(data));
    });
  };

  // ✅ MEJORAR: Callback para auto-apertura más robusto
  LocalNotificationService.onNotificationAutoOpened =
      (Map<String, dynamic> data) {
        // print('=== NOTIFICACIÓN AUTO-ABIERTA ===');
        // print('Datos recibidos: $data');
        // print('===============================');

        WidgetsBinding.instance.addPostFrameCallback((_) {
          unawaited(openDetail(data));
        });
      };

  LocalNotificationService.initialize();
  BleService.initialize();
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> with WidgetsBindingObserver {
  // Define the MethodChannel
  static const platform = MethodChannel('com.example.connect/notifications');
  static const batteryPlatform = MethodChannel('com.example.connect/battery');

  // Servicio de Firebase
  final FirebaseService _firebaseService = FirebaseService();

  // List to hold received notifications
  final List<Map<String, dynamic>> _notifications = [];
  bool _isServiceRunning = false;
  bool _isPermissionGranted = false;
  bool _isSavingToFirebase = false;
  bool _keepAppActive = false; // ✅ NUEVA VARIABLE PARA MANTENER APP ACTIVA

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Set up the method call handler to receive notifications from native
    platform.setMethodCallHandler(_handleMethodCall);
    // Verificar el estado inicial del servicio y el permiso
    _checkServiceStatus();
    _checkPermissionStatus();

    // Inicializar la estructura de datos en Firebase
    _initializeFirebaseData();

    // ✅ INICIALIZAR EL SERVICIO DE BÚSQUEDA DE DISPOSITIVOS
    _initializeDeviceSearchService();

    // Intentar iniciar el servicio automáticamente si no está corriendo
    // y el permiso está concedido
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoStartServiceIfNeeded();
      _checkInitialRoute();
      _loadKeepAppActivePreference(); // ✅ CARGAR PREFERENCIA DE MANTENER APP ACTIVA
      _initializeBleRole();
      BtHiveSyncService.syncOutboxToFirebase();
    });
  }

  // ✅ NUEVO MÉTODO PARA INICIALIZAR EL SERVICIO DE BÚSQUEDA
  Future<void> _initializeDeviceSearchService() async {
    try {
      await DeviceSearchService.instance.startListeningForSearchChanges();
      // print('DeviceSearchService inicializado correctamente');
    } catch (e) {
      // print('Error al inicializar DeviceSearchService: $e');
    }
  }

  // Método para inicializar la estructura de datos en Firebase
  Future<void> _initializeFirebaseData() async {
    try {
      await _firebaseService.initializeFirebaseData(_isServiceRunning);

      // Obtener el estado de guardado desde Firebase
      _isSavingToFirebase = await _firebaseService.getSaveStatus();

      // print('Estructura de datos inicializada en Firebase');
    } catch (e) {
      // print('Error al inicializar datos en Firebase: $e');
    }
  }

  // Método para iniciar automáticamente el servicio si es necesario
  Future<void> _autoStartServiceIfNeeded() async {
    // Verificar si la app está configurada como emisor
    final isConfiguredAsEmisor = await PreferencesService.getDisableAutoRedirect();
    
    // Solo iniciar automáticamente si está configurado como emisor,
    // los permisos están concedidos y el servicio no está corriendo
    if (isConfiguredAsEmisor && !_isServiceRunning && _isPermissionGranted) {
      // print('App configurada como emisor - Iniciando servicio automáticamente');
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
        // print('Received notification: $notificationData');

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
            } else {
              // print(                'Notificación filtrada, no se guarda en Firebase: $packageName',              );
            }
          } catch (e) {
            // print('Error al guardar notificación en Firebase: $e');
            // En caso de error, NO guardar la notificación
          }
        }
        break;
      case 'serviceConnected':
        setState(() {
          _isServiceRunning = true;
        });
        // print('Notification service connected.');

        // Actualizar el estado del servicio en Firebase
        try {
          await _firebaseService.updateServiceStatus(true);
        } catch (e) {
          // print('Error al actualizar estado del servicio en Firebase: $e');
        }
        break;
      case 'serviceDisconnected':
        setState(() {
          _isServiceRunning = false;
        });
        // print('Notification service disconnected.');

        try {
          await _firebaseService.updateServiceStatus(false);
        } catch (e) {
          // print('Error al actualizar estado del servicio en Firebase: $e');
        }

        await _ensureServicesActive();
        break;
      default:
        // print('Unknown method ${call.method}');
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
      // print('Permission granted: $_isPermissionGranted');
    } on PlatformException {
      // print("Failed to check permission status: '${e.message}'.");
    }
  }

  // Método para verificar si el servicio está corriendo
  Future<void> _checkServiceStatus() async {
    try {
      final bool isRunning = await platform.invokeMethod('isServiceRunning');
      setState(() {
        _isServiceRunning = isRunning;
      });
      // print('Service running: $_isServiceRunning');
    } on PlatformException {
      // print("Failed to check service status: '${e.message}'.");
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
        // print('Service start intent sent.');
        // El estado _isServiceRunning se actualizará cuando el servicio llame a serviceConnected
      } else {
        // print('Permission not granted, opened settings.');
        // El estado _isPermissionGranted se actualizará después de que el usuario regrese de settings
      }
    } on PlatformException {
      // print("Failed to start service: '${e.message}'.");
    }
  }

  // Método para detener el servicio
  Future<void> _stopService() async {
    try {
      await platform.invokeMethod('stopNotificationService');
      // print('Service stop intent sent.');
      // El estado _isServiceRunning se actualizará cuando el servicio llame a serviceDisconnected o onDestroy
    } on PlatformException {
      // print("Failed to stop service: '${e.message}'.");
    }
  }

  // Método para abrir la configuración de escucha de notificaciones
  Future<void> _openNotificationSettings() async {
    try {
      await platform.invokeMethod('openNotificationSettings');
      // print('Opened notification settings.');
      // Puedes añadir un listener para cuando la app vuelve a primer plano para verificar el permiso después
    } on PlatformException {
      // print("Failed to open settings: '${e.message}'.");
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

      // print('Estado de guardado en Firebase actualizado: $isSaving');
    } catch (e) {
      // print('Error al actualizar estado de guardado en Firebase: $e');
      // Revertir el cambio local si hay error
      setState(() {
        _isSavingToFirebase = !isSaving;
      });
    }
  }

  // ✅ SOLUCIÓN: Manejar cambios en el ciclo de vida de la app
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        // print('App resumed - Verificando servicios');
        _ensureServicesActive();
        _handleAppResumed(); // ✅ MANEJAR REANUDACIÓN DE APP
        break;
      case AppLifecycleState.paused:
        // print('App paused');
        _handleAppPaused(); // ✅ MANEJAR PAUSA DE APP
        break;
      case AppLifecycleState.detached:
        // print('App detached');
        _handleAppDetached(); // ✅ MANEJAR DESCONEXIÓN DE APP
        break;
      case AppLifecycleState.inactive:
        // print('App inactive');
        break;
      case AppLifecycleState.hidden:
        // print('App hidden');
        break;
    }
  }

  // ✅ SOLUCIÓN: Método para asegurar que los servicios estén activos
  Future<void> _ensureServicesActive() async {
    try {
      // Verificar estado actual del servicio y permisos
      await _checkServiceStatus();
      await _checkPermissionStatus();
      
      // Verificar si la app está configurada como emisor
      final isConfiguredAsEmisor = await PreferencesService.getDisableAutoRedirect();
      
      // Si está configurado como emisor, permisos concedidos pero servicio inactivo,
      // reactivar automáticamente
      if (isConfiguredAsEmisor && !_isServiceRunning && _isPermissionGranted) {
        // print('Emisor detectado inactivo - Reactivando servicio automáticamente');
        await _startService();
      }
      
      await NotificationListenerService.instance.ensureServiceActive();
    } catch (e) {
      // print('Error ensuring services active: $e');
    }
  }

  // ✅ NUEVO MÉTODO PARA CARGAR LA PREFERENCIA DE MANTENER APP ACTIVA
  Future<void> _loadKeepAppActivePreference() async {
    try {
      final keepActive = await PreferencesService.getKeepAppActive();
      setState(() {
        _keepAppActive = keepActive;
      });
      
      if (_keepAppActive) {
        await _requestBatteryOptimizationPermission();
      }
      
      // print('Preferencia de mantener app activa cargada: $_keepAppActive');
    } catch (e) {
      // print('Error al cargar preferencia de mantener aplicación activa: $e');
    }
  }

  // ✅ NUEVO MÉTODO PARA SOLICITAR PERMISOS DE OPTIMIZACIÓN DE BATERÍA
  Future<void> _requestBatteryOptimizationPermission() async {
    try {
      // Verificar primero si ya está exenta de optimización
      final bool isIgnored = await batteryPlatform.invokeMethod('isBatteryOptimizationIgnored');
      
      if (isIgnored) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('La aplicación ya está exenta de optimización de batería'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        // print('La aplicación ya está exenta de optimización de batería');
        return;
      }
      
      // Solicitar permisos de optimización de batería
      await batteryPlatform.invokeMethod('requestBatteryOptimizationPermission');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Solicitando permisos de optimización de batería...'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      // print('Solicitando permisos de optimización de batería');
    } catch (e) {
      // print('Error al solicitar permisos de optimización de batería: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al solicitar permisos: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // ✅ NUEVO MÉTODO PARA MANEJAR REANUDACIÓN DE APP
  Future<void> _handleAppResumed() async {
    await BtHiveSyncService.syncOutboxToFirebase();
    if (_keepAppActive) {
      // print('App reanudada - Mantener app activa está habilitado');
      // Aquí podrías agregar lógica adicional si es necesario
    }
  }

  // ✅ NUEVO MÉTODO PARA MANEJAR PAUSA DE APP
  Future<void> _handleAppPaused() async {
    if (_keepAppActive) {
      // print('App pausada - Intentando mantener activa en segundo plano');
      try {
        await platform.invokeMethod('keepAppInBackground');
      } catch (e) {
        // print('Error al mantener app en segundo plano: $e');
      }
    }
  }

  // ✅ NUEVO MÉTODO PARA MANEJAR DESCONEXIÓN DE APP
  Future<void> _handleAppDetached() async {
    if (_keepAppActive) {
      // print('App desconectada - Intentando prevenir cierre completo');
      try {
        await platform.invokeMethod('preventAppTermination');
      } catch (_) {
        // print('Error al prevenir terminación de app: $e');
      }
    }
  }

  // Método para verificar la ruta inicial según las preferencias del usuario
  // ✅ MODIFICAR EL MÉTODO _checkInitialRoute (líneas 311-350)
  Future<void> _checkInitialRoute() async {
    try {
      // print('[DEBUG] _checkInitialRoute: Start');
      final linkStatus = await _firebaseService.getLinkStatus();
      // print(        '[DEBUG] _checkInitialRoute: linkStatus from Firebase = $linkStatus',      );

      // ✅ VERIFICAR SI EL BLOQUEO AUTOMÁTICO ESTÁ DESACTIVADO
      final disableAutoRedirect =
          await PreferencesService.getDisableAutoRedirect();
      // print(        '[DEBUG] _checkInitialRoute: disableAutoRedirect = $disableAutoRedirect',      );

      // En el método _checkInitialRoute, después de verificar el linkStatus
      if (linkStatus && !disableAutoRedirect) {
        // print(          '[DEBUG] _checkInitialRoute: Dispositivo vinculado como receptor',        );

        // Inicializar el receptor sin mostrar notificaciones existentes
        final receptorService = ReceptorService();
        await receptorService.initializeReceptorWithoutNotifications();

        // Navegar a la pantalla del receptor
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/receptor');
      } else if (linkStatus && disableAutoRedirect) {
        // print(          '[DEBUG] _checkInitialRoute: Dispositivo vinculado pero bloqueo automático desactivado - permaneciendo en emisor',        );
      } else {
        // print(          '[DEBUG] _checkInitialRoute: Dispositivo no vinculado, mantener en emisor',        );
      }

      final useAsReceptor = await PreferencesService.getUseAsReceptor();
      // print(        '[DEBUG] _checkInitialRoute: useAsReceptor = \$useAsReceptor, _isPermissionGranted = \$_isPermissionGranted',      );
      if (useAsReceptor && _isPermissionGranted && !disableAutoRedirect) {
        // print('[DEBUG] _checkInitialRoute: Navigating to /receptor');
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/receptor');
      }
      // print('[DEBUG] _checkInitialRoute: Staying on EmisorScreen');
    } catch (_) {
      // print('Error al verificar ruta inicial: $e');
      // print('Stacktrace: $stack');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Configurar la clave de navegación para DeviceFinderService
    DeviceFinderService.setNavigatorKey(navigatorKey);

    return MaterialApp(
      navigatorKey: navigatorKey, // Add this line
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
          foregroundColor:
              Colors.white, // Color de los iconos y texto del AppBar
          titleTextStyle: TextStyle(
            color: Colors.white, // Color del título del AppBar
            fontSize: 20, // Ajusta el tamaño de fuente si es necesario
            fontWeight:
                FontWeight.bold, // Ajusta el peso de fuente si es necesario
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
        '/media_reproduction': (context) => const MediaReproductionScreen(),
        '/receptor': (context) => const ReceptorScreen(),
        '/notificaciones': (context) => const NotificacionesScreen(),
        '/receptor_settings': (context) => const ReceptorSettingsScreen(),
        '/unread_notifications': (context) => const UnreadNotificationsScreen(),
        '/notification_detail': (context) => const NotificationDetailScreen(
          notificationData: {},
        ),
        '/vibration_patterns': (context) => const VibrationPatternsScreen(),
        '/create_vibration_pattern': (context) => const CreateVibrationPatternScreen(),
        '/custom_sound_selection': (context) => const CustomSoundSelectionScreen(),
        '/buscar_dispositivo': (context) => const BuscarDispositivoScreen(),
        '/buscar_emisor': (context) => const BuscarEmisorScreen(),
        '/ble_devices': (context) => const BleDeviceSelectionScreen(),
        '/receptor_ble_signal': (context) => const ReceptorBleSignalScreen(),
        '/notification_settings_list': (context) => const NotificationSettingsListScreen(),
        '/configure_notification': (context) {
          final notificationData = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return ConfigureNotificationScreen(notificationData: notificationData);
        },
      }
    );
  }
}
  Future<void> _initializeBleRole() async {
    final enabled = await PreferencesService.getBleEnabled();
    if (!enabled) return;
    await BleService.requestPermissions();
    final isConfiguredAsReceptor = await PreferencesService.getDisableAutoRedirect();
    if (!isConfiguredAsReceptor) {
      try {
        final addr = await PreferencesService.getBlePeerAddress();
        if (addr != null && addr.isNotEmpty) {
          await BleService.connectToPeer(addr);
        }
      } catch (_) {}
    } else {
      try {
        await BleService.startBtServer();
      } catch (_) {}
    }
  }
