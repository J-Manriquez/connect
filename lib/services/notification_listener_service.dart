import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connect/models/notification_data.dart';
import 'package:connect/services/dismissed_notifications_service.dart';
import 'package:connect/services/firebase_service.dart';
import 'package:connect/services/local_notification_service.dart';
import 'package:connect/services/notification_cache_service.dart';

class NotificationListenerService {
  // Implementación del patrón Singleton
  static final NotificationListenerService _instance = NotificationListenerService._internal();
  factory NotificationListenerService() => _instance;
  static NotificationListenerService get instance => _instance;
  NotificationListenerService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseService _firebaseService = FirebaseService();
  StreamSubscription? _notificationStreamSubscription;
  
  // Optimización: Solo rastrear IDs de notificaciones en lugar de objetos completos
  Map<String, Set<String>> _lastKnownNotificationIds = {}; // dateId -> Set<notificationId>
  
  DateTime? _lastNotificationShownTime;
  final Duration _minShowInterval = const Duration(seconds: 10);
  bool _isListening = false;
  bool _isInitialLoad = true;
  DateTime? _serviceStartTime;

  bool get isListening => _isListening;

  Future<void> setListeningEnabled(bool enabled) async {
    if (enabled && !_isListening) {
      _serviceStartTime = DateTime.now();
      _isInitialLoad = true;
      
      await DismissedNotificationsService.cleanOldDismissedNotifications();
      await NotificationCacheService.cleanOldCache();
      await _markExistingNotificationsAsKnown();
      await startListening();
      
      Future.delayed(const Duration(seconds: 5), () {
        _isInitialLoad = false;
        print('NotificationListenerService: Período inicial completado');
      });
    } else if (!enabled && _isListening) {
      stopListening();
    }
  }

  // Optimización: Solo almacenar IDs en lugar de objetos completos
  Future<void> _markExistingNotificationsAsKnown() async {
    try {
      final deviceId = await _firebaseService.getDeviceId();
      if (deviceId.isEmpty) return;
      
      final snapshot = await _firestore
          .collection('dispositivos')
          .doc(deviceId)
          .collection('notificaciones')
          .get();
      
      Set<String> allExistingIds = {};
      
      for (var dayDoc in snapshot.docs) {
        final data = dayDoc.data();
        if (data.containsKey('notificaciones')) {
          final notificationsMap = Map<String, dynamic>.from(data['notificaciones']);
          final notificationIds = notificationsMap.keys.toSet();
          
          _lastKnownNotificationIds[dayDoc.id] = notificationIds;
          allExistingIds.addAll(notificationIds);
        }
      }
      
      // Registrar todas las notificaciones existentes como pre-existentes
      await NotificationCacheService.registerPreExistingNotifications(allExistingIds);
      
      print('NotificationListenerService: ${allExistingIds.length} notificaciones marcadas como conocidas');
    } catch (e) {
      print('NotificationListenerService: Error al marcar notificaciones existentes: $e');
    }
  }

  Future<void> startListening() async {
    if (_isListening) return;
    
    final deviceId = await _firebaseService.getDeviceId();
    if (deviceId.isEmpty) {
      print('NotificationListenerService: Device ID not available.');
      return;
    }

    _notificationStreamSubscription = _firestore
        .collection('dispositivos')
        .doc(deviceId)
        .collection('notificaciones')
        .snapshots()
        .listen(
      (snapshot) async {
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added || change.type == DocumentChangeType.modified) {
            await _processDocumentChange(change.doc);
          } else if (change.type == DocumentChangeType.removed) {
            final String dateId = change.doc.id;
            _lastKnownNotificationIds.remove(dateId);
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

  // Optimización: Procesar solo las notificaciones nuevas
  Future<void> _processDocumentChange(DocumentSnapshot dayDoc) async {
    final data = dayDoc.data() as Map<String, dynamic>?;
    if (data == null || !data.containsKey('notificaciones')) return;

    final currentNotificationsMap = Map<String, dynamic>.from(data['notificaciones']);
    final String dateId = dayDoc.id;
    final lastKnownIds = _lastKnownNotificationIds[dateId] ?? <String>{};
    final currentIds = currentNotificationsMap.keys.toSet();

    // Encontrar solo las notificaciones realmente nuevas
    final newNotificationIds = currentIds.difference(lastKnownIds);

    if (newNotificationIds.isNotEmpty) {
      print('NotificationListenerService: ${newNotificationIds.length} nuevas notificaciones en $dateId');
      
      for (final notificationId in newNotificationIds) {
        await _processNewNotification(
          notificationId, 
          currentNotificationsMap[notificationId], 
          dateId
        );
      }
    }

    // Actualizar el estado conocido solo con los IDs
    _lastKnownNotificationIds[dateId] = currentIds;
  }

  Future<void> _processNewNotification(
    String notificationId, 
    dynamic notificationDataMap, 
    String dateId
  ) async {
    try {
      if (notificationDataMap == null || notificationDataMap is! Map<String, dynamic>) {
        print('NotificationListenerService: Datos inválidos para $notificationId');
        return;
      }

      // Verificar si ya fue procesada
      if (await NotificationCacheService.isProcessed(notificationId)) {
        print('NotificationListenerService: Notificación ya procesada: $notificationId');
        return;
      }

      final Map<String, dynamic> fullNotificationDataMap = Map<String, dynamic>.from(notificationDataMap);
      fullNotificationDataMap['dateId'] = dateId;
      fullNotificationDataMap['id'] = notificationId;

      final notificationData = NotificationData.fromMap(fullNotificationDataMap);

      if (_shouldShowLocalNotification()) {
        print('NotificationListenerService: Procesando nueva notificación: ${notificationData.title}');
        await _showLocalNotification(notificationData.toMap());
      } else {
        print('NotificationListenerService: Notificación no mostrada (límite de frecuencia)');
      }
    } catch (e) {
      print('NotificationListenerService: Error al procesar $notificationId: $e');
    }
  }

  void stopListening() {
    if (!_isListening) return;
    
    _notificationStreamSubscription?.cancel();
    _notificationStreamSubscription = null;
    _lastKnownNotificationIds.clear();
    _isListening = false;
    print('NotificationListenerService: Stopped listening for notifications.');
  }

  Future<void> _showLocalNotification(Map<String, dynamic> notification) async {
    try {
      final String notificationId = notification['id'];
      
      if (_isInitialLoad) {
        print('NotificationListenerService: Notificación ignorada durante carga inicial: $notificationId');
        return;
      }
      
      // Verificar si es pre-existente
      if (await NotificationCacheService.isPreExisting(notificationId)) {
        print('NotificationListenerService: Notificación pre-existente ignorada: $notificationId');
        return;
      }
      
      // Verificar si ya fue visualizada
      if (await NotificationCacheService.isVisualized(notificationId)) {
        print('NotificationListenerService: Notificación ya visualizada: $notificationId');
        return;
      }
      
      if (await DismissedNotificationsService.isDismissed(notificationId)) {
        print('NotificationListenerService: Notificación previamente eliminada: $notificationId');
        return;
      }
      
      if (!_shouldShowLocalNotification()) {
        print('NotificationListenerService: Notificación no mostrada por intervalo mínimo: $notificationId');
        return;
      }
      
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
      
      // Marcar como procesada y visualizada
      await NotificationCacheService.markAsProcessed(notificationId);
      await NotificationCacheService.markAsVisualized(notificationId);
      
      // Actualizar estado en Firebase
      await _updateVisualizationStatus(notificationId, notification['dateId']);
      
    } catch (e) {
      print('NotificationListenerService: Error al mostrar notificación local: $e');
    }
  }

  Future<void> _updateVisualizationStatus(String notificationId, String? dateId) async {
    if (dateId == null) return;
    
    try {
      final deviceId = await _firebaseService.getDeviceId();
      final docRef = _firestore
          .collection('dispositivos')
          .doc(deviceId)
          .collection('notificaciones')
          .doc(dateId);
          
      await docRef.update({
        'notificaciones.$notificationId.visualizada': true,
      });
      
      print('NotificationListenerService: Estado de visualización actualizado: $notificationId');
    } catch (e) {
      print('NotificationListenerService: Error al actualizar visualización: $e');
    }
  }

  bool _shouldShowLocalNotification() {
    if (_lastNotificationShownTime == null) {
      return true;
    }
    final now = DateTime.now();
    return now.difference(_lastNotificationShownTime!) >= _minShowInterval;
  }
}