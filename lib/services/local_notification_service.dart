import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  
  // Claves para SharedPreferences
  static const String KEY_NOTIFICATIONS_ENABLED = 'local_notifications_enabled';
  static const String KEY_SOUND_ENABLED = 'local_notifications_sound';
  static const String KEY_VIBRATION_ENABLED = 'local_notifications_vibration';
  
  // Canal de notificaciones para Android
  static const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'receptor_notifications_channel',
    'Notificaciones del Receptor',
    description: 'Canal para mostrar notificaciones recibidas en el receptor',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  // Inicializar el servicio de notificaciones
  static Future<void> initialize() async {
    // Configuración para Android
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // Configuración para iOS
    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestSoundPermission: false,
      requestBadgePermission: false,
      requestAlertPermission: false,
    );
    
    // Configuración general
    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    
    // Inicializar el plugin
    await _notificationsPlugin.initialize(
      initializationSettings,
    );
    
    // Crear el canal de notificaciones para Android
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }
  
  // Solicitar permisos de notificaciones
  static Future<bool> requestPermissions() async {
    // Solicitar permisos para Android 13+
    if (await Permission.notification.isDenied) {
      final status = await Permission.notification.request();
      return status.isGranted;
    }
    
    // Para iOS
    final settings = await _notificationsPlugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
    
    return settings ?? false;
  }
  
  // Mostrar una notificación
  static Future<void> showNotification({
    required String title,
    required String body,
    required String packageName,
    required String appName,
  }) async {
    // Verificar si las notificaciones están habilitadas
    if (!await areNotificationsEnabled()) {
      return;
    }
    
    // Obtener configuración de sonido y vibración
    final prefs = await SharedPreferences.getInstance();
    final soundEnabled = prefs.getBool(KEY_SOUND_ENABLED) ?? true;
    final vibrationEnabled = prefs.getBool(KEY_VIBRATION_ENABLED) ?? true;
    
    // Configuración para Android
    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      channel.id,
      channel.name,
      channelDescription: channel.description,
      importance: Importance.high,
      priority: Priority.high,
      playSound: soundEnabled,
      enableVibration: vibrationEnabled,
      icon: '@mipmap/ic_launcher',
    );
    
    // Configuración para iOS
    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentSound: true,
      presentBadge: true,
      presentAlert: true,
    );
    
    // Configuración general
    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );
    
    // Mostrar la notificación
    await _notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000), // ID único basado en tiempo
      title,
      body,
      platformChannelSpecifics,
      payload: packageName,
    );
  }
  
  // Verificar si las notificaciones están habilitadas
  static Future<bool> areNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(KEY_NOTIFICATIONS_ENABLED) ?? false;
  }
  
  // Habilitar o deshabilitar notificaciones
  static Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(KEY_NOTIFICATIONS_ENABLED, enabled);
  }
  
  // Habilitar o deshabilitar sonido
  static Future<void> setSoundEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(KEY_SOUND_ENABLED, enabled);
  }
  
  // Habilitar o deshabilitar vibración
  static Future<void> setVibrationEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(KEY_VIBRATION_ENABLED, enabled);
  }
  
  // Obtener configuración de sonido
  static Future<bool> isSoundEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(KEY_SOUND_ENABLED) ?? true;
  }
  
  // Obtener configuración de vibración
  static Future<bool> isVibrationEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(KEY_VIBRATION_ENABLED) ?? true;
  }
}