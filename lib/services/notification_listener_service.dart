import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connect/models/notification_data.dart';
import 'package:connect/services/dismissed_notifications_service.dart';
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
  final Duration _minShowInterval = const Duration(seconds: 10); // Intervalo mínimo entre notificaciones
  bool _isListening = false; // Estado de escucha

  bool _isInitialLoad = true; // Flag para controlar la carga inicial
  DateTime? _serviceStartTime; // Tiempo de inicio del servicio

  // Método para verificar si está escuchando
  bool get isListening => _isListening;

  // Método para habilitar/deshabilitar la escucha
  Future<void> setListeningEnabled(bool enabled) async {
    if (enabled && !_isListening) {
      _serviceStartTime = DateTime.now();
      _isInitialLoad = true;
      
      // Limpiar notificaciones eliminadas antiguas
      await DismissedNotificationsService.cleanOldDismissedNotifications();
      
      // Marcar todas las notificaciones existentes como "conocidas"
      await _markExistingNotificationsAsKnown();
      
      await startListening();
      
      // Después de 5 segundos, permitir mostrar notificaciones nuevas
      Future.delayed(const Duration(seconds: 5), () {
        _isInitialLoad = false;
        print('NotificationListenerService: Período inicial completado, ahora mostrando notificaciones nuevas');
      });
    } else if (!enabled && _isListening) {
      stopListening();
    }
  }
  

  // Nuevo método para marcar notificaciones existentes como conocidas
  Future<void> _markExistingNotificationsAsKnown() async {
    try {
      final deviceId = await _firebaseService.getDeviceId();
      if (deviceId.isEmpty) return;
      
      final snapshot = await _firestore
          .collection('dispositivos')
          .doc(deviceId)
          .collection('notificaciones')
          .get();
      
      for (var dayDoc in snapshot.docs) {
        final data = dayDoc.data();
        if (data.containsKey('notificaciones')) {
          final notificationsMap = Map<String, dynamic>.from(data['notificaciones']);
          _lastKnownNotifications[dayDoc.id] = notificationsMap;
        }
      }
      
      print('NotificationListenerService: ${_lastKnownNotifications.length} documentos diarios marcados como conocidos');
    } catch (e) {
      print('NotificationListenerService: Error al marcar notificaciones existentes: $e');
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
      final String notificationId = notification['id'];
      
      // No mostrar durante la carga inicial
      if (_isInitialLoad) {
        print('NotificationListenerService: Notificación ignorada durante carga inicial: $notificationId');
        return;
      }
      
      // Verificar si fue eliminada previamente
      if (await DismissedNotificationsService.isDismissed(notificationId)) {
        print('NotificationListenerService: Notificación previamente eliminada: $notificationId');
        return;
      }
      
      // Verificar si ya está visualizada en Firebase
      final deviceId = await _firebaseService.getDeviceId();
      final dateId = _parseDateFromNotificationId(notificationId);
      
      if (dateId != null) {
        final docRef = _firestore
            .collection('dispositivos')
            .doc(deviceId)
            .collection('notificaciones')
            .doc(dateId);
            
        final docSnapshot = await docRef.get();
        if (docSnapshot.exists) {
          final data = docSnapshot.data();
          if (data != null && data.containsKey('notificaciones')) {
            final notificationsMap = data['notificaciones'] as Map<String, dynamic>;
            if (notificationsMap.containsKey(notificationId)) {
              final notificationData = notificationsMap[notificationId] as Map<String, dynamic>;
              final bool isVisualized = notificationData['visualizada'] ?? false;
              
              if (isVisualized) {
                print('NotificationListenerService: Notificación ya visualizada: $notificationId');
                return;
              }
            }
          }
        }
      }
      
      // Verificar intervalo mínimo
      if (!_shouldShowLocalNotification()) {
        print('NotificationListenerService: Notificación no mostrada por intervalo mínimo: $notificationId');
        return;
      }
      
      // Verificar que la notificación sea realmente nueva (después del inicio del servicio)
      if (_serviceStartTime != null && notification['timestamp'] is Timestamp) {
        final notificationTime = (notification['timestamp'] as Timestamp).toDate();
        if (notificationTime.isBefore(_serviceStartTime!)) {
          print('NotificationListenerService: Notificación anterior al inicio del servicio: $notificationId');
          return;
        }
      }
      
      // Mostrar la notificación local
      await LocalNotificationService.showNotification(
        title: notification['title'] ?? 'Nueva notificación',
        body: notification['text'] ?? '',
        packageName: notification['packageName'] ?? '',
        appName: notification['appName'] ?? 'Desconocida',
        notificationId: notificationId,
      );
      
      _lastNotificationShownTime = DateTime.now();
      
      // IMPORTANTE: Marcar como visualizada en Firebase
      if (dateId != null) {
        try {
          final docRef = _firestore
              .collection('dispositivos')
              .doc(deviceId)
              .collection('notificaciones')
              .doc(dateId);
              
          await docRef.update({
            'notificaciones.$notificationId.visualizada': true,
          });
          
          print('NotificationListenerService: Notificación marcada como visualizada: $notificationId');
        } catch (e) {
          print('NotificationListenerService: Error al marcar como visualizada: $e');
        }
      }
      
    } catch (e) {
      print('NotificationListenerService: Error al mostrar notificación local: $e');
    }
  }
  
  // Método auxiliar para extraer la fecha del ID de notificación
  String? _parseDateFromNotificationId(String notificationId) {
    try {
      // Asumiendo que el ID tiene formato: timestamp_packageName_hash
      // Extraer el timestamp y convertirlo a fecha
      final parts = notificationId.split('_');
      if (parts.isNotEmpty) {
        final timestamp = int.tryParse(parts[0]);
        if (timestamp != null) {
          final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
          return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        }
      }
    } catch (e) {
      print('Error al parsear fecha del ID de notificación: $e');
    }
    return null;
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