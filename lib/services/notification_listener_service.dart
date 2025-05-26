import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connect/models/notification_data.dart';
import 'package:connect/services/firebase_service.dart';
import 'package:connect/services/local_notification_service.dart';

class NotificationListenerService {
  // Implementación del patrón Singleton
  static final NotificationListenerService _instance = NotificationListenerService._internal();
  factory NotificationListenerService() => _instance;
  static NotificationListenerService get instance => _instance;
  NotificationListenerService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseService _firebaseService = FirebaseService();
  StreamSubscription? _notificationStreamSubscription;
  Map<String, Map<String, dynamic>> _lastKnownNotifications = {}; // Para rastrear notificaciones existentes
  DateTime? _lastNotificationShownTime; // Para limitar la frecuencia
  final Duration _minShowInterval = const Duration(seconds: 5); // Intervalo mínimo entre notificaciones
  bool _isListening = false; // Estado de escucha

  // Método para verificar si está escuchando
  bool get isListening => _isListening;

  // Método para habilitar/deshabilitar la escucha
  Future<void> setListeningEnabled(bool enabled) async {
    if (enabled && !_isListening) {
      await startListening();
    } else if (!enabled && _isListening) {
      stopListening();
    }
  }

  // Inicia la escucha de nuevas notificaciones
  Future<void> startListening() async {
    if (_isListening) return; // Evitar iniciar múltiples veces
    
    final deviceId = await _firebaseService.getDeviceId();
    if (deviceId.isEmpty) {
      print('NotificationListenerService: Device ID not available.');
      return;
    }

    // Escuchar cambios en la subcolección 'notificaciones' (documentos diarios)
    _notificationStreamSubscription = _firestore
        .collection('dispositivos')
        .doc(deviceId)
        .collection('notificaciones')
        .snapshots()
        .listen(
      (snapshot) async {
        // Procesar cada documento diario que ha cambiado
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added || change.type == DocumentChangeType.modified) {
            final dayDoc = change.doc;
            final data = dayDoc.data();
            if (data != null && data.containsKey('notificaciones')) {
              final currentNotificationsMap = Map<String, dynamic>.from(data['notificaciones']);

              // Identificar nuevas notificaciones comparando con el estado anterior
              final String dateId = dayDoc.id;
              final lastDayNotifications = _lastKnownNotifications[dateId] ?? {};

              currentNotificationsMap.forEach((notificationId, notificationDataMap) async {
                // Si la notificación no estaba en el estado anterior para este día, es nueva
                if (!lastDayNotifications.containsKey(notificationId)) {
                  try {
                    if (notificationDataMap != null && notificationDataMap is Map<String, dynamic>) {
                       // Añadir el ID del día al mapa para consistencia si es necesario
                      final Map<String, dynamic> fullNotificationDataMap = Map<String, dynamic>.from(notificationDataMap);
                      fullNotificationDataMap['dateId'] = dateId; // Asegurar que dateId está presente

                      // Convertir a NotificationData para acceso seguro a campos
                      final notificationData = NotificationData.fromMap(fullNotificationDataMap);

                      // Verificar si se debe mostrar la notificación local
                      if (_shouldShowLocalNotification()) {
                         print('NotificationListenerService: Nueva notificación detectada: ${notificationData.title}');
                        await _showLocalNotification(notificationData.toMap()); // Mostrar notificación local
                      } else {
                         print('NotificationListenerService: Nueva notificación detectada pero no mostrada (límite de frecuencia)');
                      }

                    } else {
                      print('NotificationListenerService: Datos de notificación inválidos para $notificationId en $dateId');
                    }
                  } catch (e) {
                    print('NotificationListenerService: Error al procesar nueva notificación $notificationId en $dateId: $e');
                  }
                }
              });

              // Actualizar el estado conocido para este día
              _lastKnownNotifications[dateId] = currentNotificationsMap;
            }
          }
           // Si un documento diario es eliminado, removerlo de nuestro estado conocido
          if (change.type == DocumentChangeType.removed) {
             final String dateId = change.doc.id;
             _lastKnownNotifications.remove(dateId);
             print('NotificationListenerService: Documento diario eliminado: $dateId');
          }
        }
      },
      onError: (error) {
        print('NotificationListenerService: Error listening for notifications: $error');
      },
    );
    
    _isListening = true;
    print('NotificationListenerService: Started listening for notifications.');
  }

  // Detiene la escucha
  void stopListening() {
    if (!_isListening) return; // Evitar detener si ya está detenido
    
    _notificationStreamSubscription?.cancel();
    _notificationStreamSubscription = null;
    _lastKnownNotifications.clear(); // Limpiar estado al detener
    _isListening = false;
    print('NotificationListenerService: Stopped listening for notifications.');
  }

  // Método para mostrar notificaciones locales (adaptado del código proporcionado)
  Future<void> _showLocalNotification(Map<String, dynamic> notification) async {
    try {
      // Mostrar la notificación local
      await LocalNotificationService.showNotification(
        title: notification['title'] ?? 'Nueva notificación',
        body: notification['text'] ?? '',
        packageName: notification['packageName'] ?? '',
        appName: notification['appName'] ?? 'Desconocida',
      );
       _lastNotificationShownTime = DateTime.now(); // Actualizar tiempo de última notificación mostrada

      // Obtener notificationId y dateId de la notificación
      final String notificationId = notification['id'];
        // 2. Convertir el String de milisegundos a un entero
        final int millisecondsSinceEpoch = int.parse(notificationId);
        print('Milisegundos (int): $millisecondsSinceEpoch');

        // 3. Crear un objeto DateTime a partir de los milisegundos
        final DateTime dateTimeObject = DateTime.fromMillisecondsSinceEpoch(
          millisecondsSinceEpoch,
        );
        print(
          'Objeto DateTime: $dateTimeObject',
        ); // Esto mostrará la fecha y la hora completas

        // 4. Formatear el objeto DateTime a "aaaa-mm-dd"
        // Para esto, nos aseguramos de que el mes y el día tengan dos dígitos (ej. 05 en lugar de 5)

        final String year = dateTimeObject.year.toString();
        final String month = dateTimeObject.month.toString().padLeft(
          2,
          '0',
        ); // Añade un 0 a la izquierda si es necesario
        final String day = dateTimeObject.day.toString().padLeft(
          2,
          '0',
        ); // Añade un 0 a la izquierda si es necesario

        final String dateId = '$year-$month-$day';
      // Actualizar el estado de visualización en Firebase
      await _firebaseService.updateNotificationVisualizationStatus(
        notificationId,
        dateId,
        true, // Marcar como visualizado
      );

    } catch (e) {
      print('NotificationListenerService: Error al mostrar notificación local: $e');
    }
  }

  // Verifica si se debe mostrar una notificación local basada en la frecuencia
  bool _shouldShowLocalNotification() {
    if (_lastNotificationShownTime == null) {
      return true; // Mostrar la primera notificación
    }
    final now = DateTime.now();
    return now.difference(_lastNotificationShownTime!) >= _minShowInterval;
  }
}