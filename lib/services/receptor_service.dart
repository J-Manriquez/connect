import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connect/models/notification_data.dart';
import 'package:connect/services/ble_service.dart';
import 'package:connect/services/firebase_service.dart';
import 'package:connect/services/local_notification_service.dart';
import 'package:connect/services/notification_cache_service.dart';
import 'package:connect/services/notification_filters_config_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReceptorService {
  final FirebaseService _firebaseService = FirebaseService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Clave para almacenar el ID del dispositivo emisor vinculado
  static const String keyLinkedDeviceId = 'linked_device_id';
  static const String _lastNotificationKey = 'receptor_last_notification_hash';
  static const String _recentNotificationHashesKey =
      'receptor_recent_notification_hashes_v1';
  static const int _recentNotificationMaxEntries = 2000;
  static const int _recentNotificationTtlMs = 24 * 60 * 60 * 1000;

  // Verificar si un código de vinculación existe en Firestore
  Future<String?> verifyLinkCode(String code) async {
    try {
      final QuerySnapshot querySnapshot = await _firestore
          .collection('dispositivos')
          .get();

      for (var doc in querySnapshot.docs) {
        if (doc.id == code) {
          // print('Dispositivo encontrado con ID: ${doc.id}');
          return doc.id;
        }
      }

      // print('No se encontró ningún dispositivo con el código: $code');
      return null;
    } catch (e) {
      // print('Error al verificar código de vinculación: $e');
      return null;
    }
  }



  // Guardar el ID del dispositivo emisor vinculado en SharedPreferences
  Future<bool> saveLinkedDeviceId(String deviceId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(keyLinkedDeviceId, deviceId);

      await _firebaseService.updateLinkStatus(true, deviceId);
      await NotificationFiltersConfigService.restartRemoteSync();
      

      // print('ID del dispositivo emisor guardado: $deviceId');
      return true;
    } catch (e) {
      // print('Error al guardar ID del dispositivo emisor: $e');
      return false;
    }
  }

  // Obtener el ID del dispositivo emisor vinculado
  Future<String?> getLinkedDeviceId() async {
    try {
      // print('[DEBUG] getLinkedDeviceId: Start');
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString(keyLinkedDeviceId);
      // print('[DEBUG] getLinkedDeviceId: Result = $id');
      return id;
    } catch (e) {
      // print('Error al obtener ID del dispositivo emisor: $e');
      return null;
    }
  }

  // Método para actualizar el estado de visualización de una notificación
  Future<void> updateNotificationVisualizationStatus(
    String notificationId,
    bool visualizado,
  ) async {
    String? dateId;
    String? deviceId;
    try {
      deviceId = await getLinkedDeviceId();
      if (deviceId == null) {
        // print('No hay dispositivo emisor vinculado');
        return;
      }

      final uniqueId = notificationId;
      final int millisecondsSinceEpoch = int.parse(uniqueId);
      // print('Milisegundos (int): $millisecondsSinceEpoch');

      final DateTime dateTimeObject = DateTime.fromMillisecondsSinceEpoch(
        millisecondsSinceEpoch,
      );
      // print('Objeto DateTime: $dateTimeObject');

      final String year = dateTimeObject.year.toString();
      final String month = dateTimeObject.month.toString().padLeft(2, '0');
      final String day = dateTimeObject.day.toString().padLeft(2, '0');

      dateId = '$year-$month-$day';
      final docRef = _firestore
          .collection('dispositivos')
          .doc(deviceId)
          .collection('notificaciones')
          .doc(dateId);

      await docRef.update({
        'notificaciones.$notificationId.status-visualizacion': visualizado,
      });
      // print(        'Estado de visualización actualizado para notificación $notificationId: $visualizado',      );
    } catch (e) {
      try {
        if (visualizado != true) return;

        if (deviceId == null || deviceId.isEmpty) {
          deviceId = await getLinkedDeviceId();
        }
        if (dateId == null || dateId.isEmpty) {
          final int millisecondsSinceEpoch = int.parse(notificationId);
          final DateTime dateTimeObject = DateTime.fromMillisecondsSinceEpoch(
            millisecondsSinceEpoch,
          );
          final String year = dateTimeObject.year.toString();
          final String month = dateTimeObject.month.toString().padLeft(2, '0');
          final String day = dateTimeObject.day.toString().padLeft(2, '0');
          dateId = '$year-$month-$day';
        }

        final resolvedDeviceId = (deviceId ?? '').trim();
        final resolvedDateId = dateId.trim();
        if (resolvedDeviceId.isEmpty || resolvedDateId.isEmpty) return;

        final hasInternet = await _hasInternetConnection();
        if (hasInternet) return;

        await BleService.sendBtServerMessage({
          'type': 'visualization_update',
          'notificationId': notificationId,
          'dateId': resolvedDateId,
          'visualizado': true,
          'deviceId': resolvedDeviceId,
        });
      } catch (_) {}
    }
  }

  static Future<bool> _hasInternetConnection() async {
    try {
      final res = await InternetAddress.lookup(
        'example.com',
      ).timeout(const Duration(seconds: 2));
      return res.isNotEmpty && res.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // Nuevo método para filtrar notificaciones visualizadas
  Stream<List<Map<String, dynamic>>> listenForSeenNotifications() async* {
    try {
      final allNotificationsStream = listenForAllNotificationsAcrossDays();

      yield* allNotificationsStream.map((notifications) {
        return notifications.where((notification) {
          return notification['status-visualizacion'] == true;
        }).toList();
      });
    } catch (e) {
      // print('Error al filtrar notificaciones visualizadas: $e');
      yield <Map<String, dynamic>>[];
    }
  }

  // Nuevo método para filtrar notificaciones no visualizadas
  Stream<List<Map<String, dynamic>>> listenForUnseenNotifications() async* {
    try {
      final allNotificationsStream = listenForAllNotificationsAcrossDays();

      yield* allNotificationsStream.map((notifications) {
        return notifications.where((notification) {
          return notification['status-visualizacion'] == false;
        }).toList();
      });
    } catch (e) {
      // print('Error al filtrar notificaciones no visualizadas: $e');
      yield <Map<String, dynamic>>[];
    }
  }

  Stream<List<Map<String, dynamic>>> listenForAllNotificationsAcrossDays() async* {
    try {
      final deviceId = await getLinkedDeviceId();
      if (deviceId == null || deviceId.trim().isEmpty) {
        yield <Map<String, dynamic>>[];
        return;
      }

      final colRef = _firestore
          .collection('dispositivos')
          .doc(deviceId)
          .collection('notificaciones');

      yield* colRef.snapshots().asyncMap((snapshot) async {
        final List<Map<String, dynamic>> notificationsList = [];

        for (final dayDoc in snapshot.docs) {
          final data = dayDoc.data();
          final raw = data['notificaciones'];
          if (raw is! Map) continue;

          for (final entry in raw.entries) {
            final notificationId = entry.key?.toString() ?? '';
            if (notificationId.trim().isEmpty) continue;
            final value = entry.value;
            if (value is! Map) continue;

            final notif = Map<String, dynamic>.from(value);
            notif['notificationId'] = notificationId;
            notif['dateId'] = dayDoc.id;
            notificationsList.add(notif);
          }
        }

        notificationsList.sort((a, b) {
          final ta = (a['timestamp'] as Timestamp?)?.toDate() ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final tb = (b['timestamp'] as Timestamp?)?.toDate() ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return tb.compareTo(ta);
        });

        try {
          await BtHiveStorageService.cacheFirebaseNotifications(notificationsList);
        } catch (_) {}

        final filtered = <Map<String, dynamic>>[];
        final seenStableKeys = <String>{};
        final seenSignatureIds = <String>{};
        for (final n in notificationsList) {
          final ts = n['timestamp'];
          if (ts is! Timestamp) continue;
          if (await _shouldFilterNotification(n)) continue;
          final stableKey = _extractStableSbnKey(n);
          final signatureId = _extractStoredSignatureId(n).isNotEmpty
              ? _extractStoredSignatureId(n)
              : _generateStableSignatureId(n);
          if (stableKey.isNotEmpty && seenStableKeys.contains(stableKey)) continue;
          if (signatureId.isNotEmpty && seenSignatureIds.contains(signatureId)) continue;
          if (stableKey.isNotEmpty) seenStableKeys.add(stableKey);
          if (signatureId.isNotEmpty) seenSignatureIds.add(signatureId);
          filtered.add(n);
        }

        try {
          await BtHiveStorageService.cacheFirebaseNotifications(filtered);
        } catch (_) {}
        return filtered;
      });
    } catch (_) {
      yield <Map<String, dynamic>>[];
    }
  }

  Future<List<Map<String, dynamic>>> fetchAllNotificationsAcrossDaysOnce() async {
    final deviceId = await getLinkedDeviceId();
    if (deviceId == null || deviceId.trim().isEmpty) return const [];

    try {
      final querySnapshot = await _firestore
          .collection('dispositivos')
          .doc(deviceId)
          .collection('notificaciones')
          .get();

      final List<Map<String, dynamic>> notificationsList = [];
      for (final dayDoc in querySnapshot.docs) {
        final data = dayDoc.data();
        final raw = data['notificaciones'];
        if (raw is! Map) continue;

        for (final entry in raw.entries) {
          final notificationId = entry.key?.toString() ?? '';
          if (notificationId.trim().isEmpty) continue;
          final value = entry.value;
          if (value is! Map) continue;

          final notif = Map<String, dynamic>.from(value);
          notif['notificationId'] = notificationId;
          notif['dateId'] = dayDoc.id;
          notificationsList.add(notif);
        }
      }

      notificationsList.sort((a, b) {
        final ta = (a['timestamp'] as Timestamp?)?.toDate() ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final tb = (b['timestamp'] as Timestamp?)?.toDate() ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return tb.compareTo(ta);
      });

      try {
        await BtHiveStorageService.cacheFirebaseNotifications(notificationsList);
      } catch (_) {}

      final filtered = <Map<String, dynamic>>[];
      final seenStableKeys = <String>{};
      final seenSignatureIds = <String>{};
      for (final n in notificationsList) {
        final ts = n['timestamp'];
        if (ts is! Timestamp) continue;
        if (await _shouldFilterNotification(n)) continue;
        final stableKey = _extractStableSbnKey(n);
        final signatureId = _extractStoredSignatureId(n).isNotEmpty
            ? _extractStoredSignatureId(n)
            : _generateStableSignatureId(n);
        if (stableKey.isNotEmpty && seenStableKeys.contains(stableKey)) continue;
        if (signatureId.isNotEmpty && seenSignatureIds.contains(signatureId)) continue;
        if (stableKey.isNotEmpty) seenStableKeys.add(stableKey);
        if (signatureId.isNotEmpty) seenSignatureIds.add(signatureId);
        filtered.add(n);
      }

      try {
        await BtHiveStorageService.cacheFirebaseNotifications(filtered);
      } catch (_) {}
      return filtered;
    } catch (_) {
      return const [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchAllNotificationsAcrossDaysRawOnce() async {
    final deviceId = await getLinkedDeviceId();
    if (deviceId == null || deviceId.trim().isEmpty) return const [];

    try {
      final querySnapshot = await _firestore
          .collection('dispositivos')
          .doc(deviceId)
          .collection('notificaciones')
          .get();

      final List<Map<String, dynamic>> notificationsList = [];
      for (final dayDoc in querySnapshot.docs) {
        final data = dayDoc.data();
        final raw = data['notificaciones'];
        if (raw is! Map) continue;

        for (final entry in raw.entries) {
          final notificationId = entry.key?.toString() ?? '';
          if (notificationId.trim().isEmpty) continue;
          final value = entry.value;
          if (value is! Map) continue;

          final notif = Map<String, dynamic>.from(value);
          notif['notificationId'] = notificationId;
          notif['dateId'] = dayDoc.id;
          notificationsList.add(notif);
        }
      }

      notificationsList.sort((a, b) {
        final ta = (a['timestamp'] as Timestamp?)?.toDate() ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final tb = (b['timestamp'] as Timestamp?)?.toDate() ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return tb.compareTo(ta);
      });

      try {
        await BtHiveStorageService.cacheFirebaseNotifications(notificationsList);
      } catch (_) {}

      return notificationsList;
    } catch (_) {
      return const [];
    }
  }

  // Obtiene todas las notificaciones almacenadas para el dispositivo
  Future<List<NotificationData>> getStoredNotifications() async {
    final deviceId = await getLinkedDeviceId();
    final List<NotificationData> allNotifications = [];

    try {
      final querySnapshot = await _firestore
          .collection('dispositivos')
          .doc(deviceId)
          .collection('notificaciones')
          .get();

      for (final dayDoc in querySnapshot.docs) {
        final data = dayDoc.data();
        if (data.containsKey('notificaciones')) {
          final Map<String, dynamic> notificationsMap =
              data['notificaciones'] as Map<String, dynamic>;

          notificationsMap.forEach((notificationId, notificationData) {
            try {
              if (notificationData != null &&
                  notificationData is Map<String, dynamic>) {
                final Map<String, dynamic> notificationDataMap =
                    Map<String, dynamic>.from(notificationData);
                notificationDataMap['dateId'] = dayDoc.id;

                if (notificationDataMap.containsKey('timestamp') &&
                    notificationDataMap['timestamp'] is Timestamp) {
                  allNotifications.add(
                    NotificationData.fromMap(notificationDataMap),
                  );
                }
              } else {
              }
            } catch (e) {
              // print('Error al procesar notificación $notificationId: $e');
            }
          });
        }
      }

      allNotifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      return allNotifications;
    } catch (e) {
      // print('Error al obtener notificaciones almacenadas: $e');
      return [];
    }
  }

  Future<void> syncFirebaseNotificationsToHiveCache() async {
    final deviceId = await getLinkedDeviceId();
    if (deviceId == null || deviceId.trim().isEmpty) return;

    try {
      final querySnapshot = await _firestore
          .collection('dispositivos')
          .doc(deviceId)
          .collection('notificaciones')
          .get();

      final List<Map<String, dynamic>> all = [];
      for (final dayDoc in querySnapshot.docs) {
        final data = dayDoc.data();
        final raw = data['notificaciones'];
        if (raw is! Map) continue;

        for (final entry in raw.entries) {
          final notificationId = entry.key?.toString() ?? '';
          if (notificationId.trim().isEmpty) continue;

          final value = entry.value;
          if (value is! Map) continue;

          final notif = Map<String, dynamic>.from(value);
          notif['notificationId'] = notificationId;
          final existingId = (notif['id'] ?? '').toString().trim();
          if (existingId.isEmpty) {
            notif['id'] = notificationId;
          }
          all.add(notif);
        }
      }

      await BtHiveStorageService.cacheFirebaseNotifications(all);
    } catch (_) {}
  }

  // Variables para rastrear notificaciones conocidas y evitar mostrar históricas
  final Map<String, Set<String>> _lastKnownNotificationIds = {}; // dateId -> Set<notificationId>
  DateTime? _receptorStartTime;
  bool _isReceptorInitialLoad = true;

  // Iniciar escucha de notificaciones desde Firebase
  Stream<List<Map<String, dynamic>>> listenForNotifications() async* {
    try {
      final deviceId = await getLinkedDeviceId();

      if (deviceId == null) {
        // print('No hay dispositivo emisor vinculado');
        yield [];
        return;
      }

      // Marcar el tiempo de inicio del receptor
      _receptorStartTime = DateTime.now();
      _isReceptorInitialLoad = true;
      
      // Después de 5 segundos, permitir mostrar notificaciones nuevas
      Future.delayed(const Duration(seconds: 5), () {
        _isReceptorInitialLoad = false;
        // print('ReceptorService: Período inicial completado, ahora mostrando notificaciones nuevas');
      });

      final DateTime now = DateTime.now();
      final String dateId =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final dayDocRef = _firestore
          .collection('dispositivos')
          .doc(deviceId)
          .collection('notificaciones')
          .doc(dateId);

      yield* dayDocRef.snapshots().asyncMap((snapshot) async {
        if (!snapshot.exists ||
            !snapshot.data()!.containsKey('notificaciones')) {
          return <Map<String, dynamic>>[];
        }

        final Map<String, dynamic> notificationsMap =
            snapshot.data()!['notificaciones'] as Map<String, dynamic>;

        final List<Map<String, dynamic>> notificationsList = notificationsMap
            .entries
            .map((entry) {
              final notif = Map<String, dynamic>.from(entry.value as Map);
              notif['notificationId'] =
                  entry.key; // Agregar el ID de la notificación

              if (notif['timestamp'] is Timestamp) {
                return notif;
              } else {
                return null;
              }
            })
            .where((notif) => notif != null)
            .cast<Map<String, dynamic>>()
            .toList();

        notificationsList.sort((a, b) {
          final DateTime timeA = (a['timestamp'] as Timestamp).toDate();
          final DateTime timeB = (b['timestamp'] as Timestamp).toDate();
          return timeB.compareTo(timeA);
        });

        final filtered = <Map<String, dynamic>>[];
        final seenStableKeys = <String>{};
        final seenSignatureIds = <String>{};
        for (final n in notificationsList) {
          if (await _shouldFilterNotification(n)) continue;
          final stableKey = _extractStableSbnKey(n);
          final signatureId = _extractStoredSignatureId(n).isNotEmpty
              ? _extractStoredSignatureId(n)
              : _generateStableSignatureId(n);
          if (stableKey.isNotEmpty && seenStableKeys.contains(stableKey)) continue;
          if (signatureId.isNotEmpty && seenSignatureIds.contains(signatureId)) continue;
          if (stableKey.isNotEmpty) seenStableKeys.add(stableKey);
          if (signatureId.isNotEmpty) seenSignatureIds.add(signatureId);
          filtered.add(n);
        }
        try {
          await BtHiveStorageService.cacheFirebaseNotifications(filtered);
        } catch (_) {}
        return filtered;
      });
    } catch (e) {
      // print('Error al escuchar notificaciones: $e');
      yield <Map<String, dynamic>>[];
    }
  }

  // Nuevo método para procesar solo notificaciones nuevas para mostrar localmente
  void _processNewNotificationsForLocalDisplay(
    Map<String, dynamic> currentNotificationsMap, 
    String dateId
  ) {
    try {
      final lastKnownIds = _lastKnownNotificationIds[dateId] ?? <String>{};
      final currentIds = currentNotificationsMap.keys.toSet();
      
      // Encontrar solo las notificaciones realmente nuevas
      final newNotificationIds = currentIds.difference(lastKnownIds);
      
      if (newNotificationIds.isNotEmpty && !_isReceptorInitialLoad) {
        // print('ReceptorService: ${newNotificationIds.length} nuevas notificaciones detectadas en $dateId');
        
        for (final notificationId in newNotificationIds) {
          final notificationData = currentNotificationsMap[notificationId];
          if (notificationData != null) {
            // Verificar que la notificación sea posterior al inicio del receptor
            if (_receptorStartTime != null && notificationData['timestamp'] is Timestamp) {
              final notificationTime = (notificationData['timestamp'] as Timestamp).toDate();
              if (notificationTime.isAfter(_receptorStartTime!)) {
                _showLocalNotificationIfNew(notificationData, notificationId);
              } else {
                // print('ReceptorService: Notificación anterior al inicio del receptor ignorada: $notificationId');
              }
            }
          }
        }
      } else if (_isReceptorInitialLoad) {
        // print('ReceptorService: Carga inicial - ${currentIds.length} notificaciones existentes ignoradas');
      }
      
      // Actualizar el estado conocido
      _lastKnownNotificationIds[dateId] = currentIds;
    } catch (e) {
      // print('ReceptorService: Error al procesar notificaciones nuevas: $e');
    }
  }

  // Método privado para mostrar notificación local cuando se detecta una nueva
  // Método mejorado para inicializar el receptor sin mostrar notificaciones existentes
  Future<void> initializeReceptorWithoutNotifications() async {
    try {
      final deviceId = await getLinkedDeviceId();
      if (deviceId == null) {
        // print('No hay dispositivo emisor vinculado');
        return;
      }
  
      // Limpiar estado previo
      _lastKnownNotificationIds.clear();
      _receptorStartTime = DateTime.now();
      _isReceptorInitialLoad = true;
  
      // Obtener todas las notificaciones existentes y marcarlas como conocidas
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
          
          // Almacenar IDs conocidos por fecha
          _lastKnownNotificationIds[dayDoc.id] = notificationIds;
          allExistingIds.addAll(notificationIds);
        }
      }
  
      // Usar el nuevo servicio de caché
      await NotificationCacheService.registerPreExistingNotifications(allExistingIds);
  
      // print(        'Receptor inicializado. ${allExistingIds.length} notificaciones existentes registradas como pre-existentes.',      );
      
      // Después de 3 segundos, permitir mostrar notificaciones nuevas
      Future.delayed(const Duration(seconds: 3), () {
        _isReceptorInitialLoad = false;
        // print('ReceptorService: Inicialización completada, listo para mostrar notificaciones nuevas');
      });
    } catch (e) {
      // print('Error al inicializar receptor: $e');
    }
  }

  // Método para verificar si una notificación debe ser filtrada (mismo que en FirebaseService)
  // Método mejorado para verificar si una notificación debe ser filtrada
  Future<bool> _shouldFilterNotification(Map<String, dynamic> notification) async {
    final config = await NotificationFiltersConfigService.getConfig();
    final String packageName = notification['packageName'] ?? '';

    // Filtro universal: Notificaciones vacías (aplicar a todas las aplicaciones)
    String clean(dynamic v) {
      final raw = (v ?? '').toString().trim();
      final lower = raw.toLowerCase();
      if (lower == 'null' || lower == 'undefined') return '';
      return raw;
    }

    final String title = clean(notification['title']);
    final String text = clean(notification['text']);
    final String bigText = clean(notification['bigText']);
    final String subText = clean(notification['subText']);
    final String summaryText = clean(notification['summaryText']);
    final String infoText = clean(notification['infoText']);
    final String contentInfo = clean(notification['contentInfo']);
    final String body = clean(notification['body']);
    final String mensaje = clean(notification['mensaje']);
    final String contenido = clean(notification['contenido']);
    
    final bool hasAnyBody =
        title.isNotEmpty ||
        text.isNotEmpty ||
        bigText.isNotEmpty ||
        subText.isNotEmpty ||
        summaryText.isNotEmpty ||
        infoText.isNotEmpty ||
        contentInfo.isNotEmpty ||
        body.isNotEmpty ||
        mensaje.isNotEmpty ||
        contenido.isNotEmpty;
    if (config.isEnabled('filter_empty', fallback: true) && !hasAnyBody) {
      return true;
    }

    final String normalizedContent =
        NotificationFiltersConfigService.normalizedNotificationContent(notification);

    if (config.isEnabled('filter_global_message_patterns', fallback: true)) {
      final List<RegExp> globalMessagePatterns = [
        RegExp(r'\b\d+\s*mensajes?\s*nuevos?\b'),
        RegExp(r'\b\d+\s*new\s*messages?\b'),
      ];
      for (final pattern in globalMessagePatterns) {
        if (pattern.hasMatch(normalizedContent)) {
          return true;
        }
      }
    }

    if (packageName == 'com.instagram.android') {
      if (config.isEnabled('instagram_filter_upload', fallback: true)) {
        final List<String> uploadKeywords = [
          'subiendo contenido multimedia',
          'uploading media content',
          'subiendo contenido',
          'uploading content',
        ];
        for (final keyword in uploadKeywords) {
          if (normalizedContent.contains(keyword)) {
            return true;
          }
        }
      }

      if (config.isEnabled('instagram_filter_story', fallback: true)) {
        final List<String> storyKeywords = [
          'subiendo historia',
          'uploading story',
          'se subio la historia',
          'story uploaded',
          'historia subida',
          'story posted',
        ];
        for (final keyword in storyKeywords) {
          if (normalizedContent.contains(keyword)) {
            return true;
          }
        }
      }

      if (config.isEnabled('instagram_filter_calls', fallback: true)) {
        final List<String> callKeywords = [
          'llamando',
          'llamada en curso',
          'calling',
          'llamada entrante',
          'incoming call',
          'llamada perdida',
          'missed call',
          'llamada de',
          'call from',
          'videollamada',
          'video call',
          'video calling',
          'llamada de video',
        ];
        for (final keyword in callKeywords) {
          if (normalizedContent.contains(keyword)) {
            return true;
          }
        }
      }
    }

    if (packageName == 'com.whatsapp' || packageName == 'com.whatsapp.w4b') {
      if (config.isEnabled('whatsapp_filter_sending', fallback: true)) {
        final List<String> sendingKeywords = [
          'enviando',
          'sending',
        ];
        for (final keyword in sendingKeywords) {
          if (normalizedContent.contains(keyword)) {
            return true;
          }
        }
      }

      if (config.isEnabled('whatsapp_filter_message_summary', fallback: true)) {
        final List<RegExp> messagePatterns = [
          RegExp(r'\d+\s*mensajes?\s*de\s*\d+\s*chats?'),
          RegExp(r'\d+\s*mensajes?\s*de\s*\d+\s*chat\s*s?'),
          RegExp(r'\d+\s*messages?\s*from\s*\d+\s*chats?'),
          RegExp(r'\d+\s*nuevos?\s*mensajes?'),
          RegExp(r'\d+\s*new\s*messages?'),
          RegExp(r'\d+\s*mensajes?\s*nuevos?'),
          RegExp(r'\d+\s*mensajes?\s*nuevos?\s*de\s*\d+\s*chats?'),
          RegExp(r'\d+\s*mensajes?\s*nuevos?\s*\d+\s*chats?'),
          RegExp(r'\d+\s*mensajes?\s*en\s*\d+\s*chats?'),
          RegExp(r'\d+\s*messages?\s*in\s*\d+\s*chats?'),
          RegExp(r'\d+\s*new\s*messages?\s*\d+\s*chats?'),
        ];

        for (final pattern in messagePatterns) {
          if (pattern.hasMatch(normalizedContent)) {
            return true;
          }
        }

        if (normalizedContent.contains('mensajes') &&
            normalizedContent.contains('chat') &&
            RegExp(r'\b\d+\s*mensajes?\b').hasMatch(normalizedContent) &&
            RegExp(r'\b\d+\s*chat').hasMatch(normalizedContent)) {
          return true;
        }
      }

      if (config.isEnabled('whatsapp_filter_calls', fallback: true)) {
        final List<String> callKeywords = [
          'llamando',
          'llamada',
          'llamada en curso',
          'calling',
          'llamada entrante',
          'incoming call',
          'llamada perdida',
          'missed call',
          'llamada de',
          'call from',
          'videollamada',
          'video call',
        ];

        for (final keyword in callKeywords) {
          if (normalizedContent.contains(keyword)) {
            return true;
          }
        }
      }

      if (config.isEnabled('whatsapp_filter_backup', fallback: true)) {
        final List<String> backupKeywords = [
          'copia de seguridad',
          'backup',
          'respaldo',
          'copia de seg',
          'backing up',
          'guardando copia',
        ];

        for (final keyword in backupKeywords) {
          if (normalizedContent.contains(keyword)) {
            return true;
          }
        }
      }

      if (config.isEnabled('whatsapp_filter_checking', fallback: true)) {
        if (normalizedContent.contains('comprobando si hay mensajes nuevos') ||
            normalizedContent.contains('checking for new messages')) {
          return true;
        }
      }

      if (config.isEnabled('whatsapp_filter_generic', fallback: true)) {
        final List<String> genericKeywords = [
          'nueva notificacion',
          'new notification',
          'contenido no disponible',
          'content not available',
          'content unavailable',
          'mensaje no disponible',
          'message not available',
          'sin contenido',
          'no content',
        ];

        for (final keyword in genericKeywords) {
          if (normalizedContent.contains(keyword)) {
            return true;
          }
        }
      }
    }

    if (NotificationFiltersConfigService.shouldFilterByCustomRules(
      config: config,
      packageName: packageName,
      normalizedContent: normalizedContent,
    )) {
      return true;
    }

    return false;
  }


  // Método para generar un hash único de la notificación (mismo que en FirebaseService)
  String _generateNotificationHash(Map<String, dynamic> notification) {
    final String packageName = notification['packageName'] ?? '';
    final String title = notification['title'] ?? '';
    final String text = notification['text'] ?? '';
    final String bigText = notification['bigText'] ?? '';
    final String body = notification['body'] ?? '';
    final String mensaje = notification['mensaje'] ?? '';
    final String contenido = notification['contenido'] ?? '';
    
    final String combinedContent = '$packageName|$title|$text|$bigText|$body|$mensaje|$contenido';
    return combinedContent.hashCode.toString();
  }

  String _extractStableSbnKey(Map<String, dynamic> notification) {
    String clean(dynamic v) {
      final raw = (v ?? '').toString().trim();
      final lower = raw.toLowerCase();
      if (lower == 'null' || lower == 'undefined') return '';
      return raw;
    }

    final direct = clean(notification['sbnKey']);
    if (direct.isNotEmpty) return direct;
    final alt = clean(notification['key']);
    if (alt.isNotEmpty) return alt;

    final nested = notification['extras'];
    if (nested is Map) {
      final m = Map<String, dynamic>.from(nested);
      final nestedKey = clean(m['sbnKey']);
      if (nestedKey.isNotEmpty) return nestedKey;
      final nestedAlt = clean(m['key']);
      if (nestedAlt.isNotEmpty) return nestedAlt;
    }

    return '';
  }

  String _extractStoredSignatureId(Map<String, dynamic> notification) {
    String clean(dynamic v) {
      final raw = (v ?? '').toString().trim();
      final lower = raw.toLowerCase();
      if (lower == 'null' || lower == 'undefined') return '';
      return raw;
    }

    final direct = clean(notification['signatureId']);
    if (direct.isNotEmpty) return direct;

    final nested = notification['extras'];
    if (nested is Map) {
      final m = Map<String, dynamic>.from(nested);
      final nestedSig = clean(m['signatureId']);
      if (nestedSig.isNotEmpty) return nestedSig;
    }

    return '';
  }

  String _fnv1a32Hex(String input) {
    final data = utf8.encode(input);
    int hash = 0x811c9dc5;
    for (final b in data) {
      hash ^= b;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  String _generateStableSignatureId(Map<String, dynamic> notification) {
    final pkg = (notification['packageName'] ?? '').toString().trim();
    final normalized =
        NotificationFiltersConfigService.normalizedNotificationContent(notification);
    final source = '$pkg|$normalized';
    return _fnv1a32Hex(source);
  }

  // Método para verificar si la notificación es duplicada en el receptor
  Future<bool> _isDuplicateNotification(Map<String, dynamic> notification) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String currentHash = _generateNotificationHash(notification);
      final String stableKey = _extractStableSbnKey(notification);
      final String signatureId = _extractStoredSignatureId(notification).isNotEmpty
          ? _extractStoredSignatureId(notification)
          : _generateStableSignatureId(notification);
      final String stableKeyEntry = stableKey.isEmpty ? '' : 'k:$stableKey';
      final String signatureEntry = signatureId.isEmpty ? '' : 's:$signatureId';
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      final raw = prefs.getString(_recentNotificationHashesKey);
      Map<String, dynamic> map;
      try {
        map = raw == null || raw.isEmpty
            ? <String, dynamic>{}
            : (jsonDecode(raw) as Map).cast<String, dynamic>();
      } catch (_) {
        map = <String, dynamic>{};
      }

      final cutoffMs = nowMs - _recentNotificationTtlMs;
      final keysToRemove = <String>[];
      for (final entry in map.entries) {
        final ts = entry.value;
        final tsMs = ts is int ? ts : int.tryParse(ts.toString());
        if (tsMs == null || tsMs < cutoffMs) {
          keysToRemove.add(entry.key);
        }
      }
      for (final k in keysToRemove) {
        map.remove(k);
      }

      if (map.containsKey(currentHash) ||
          (stableKeyEntry.isNotEmpty && map.containsKey(stableKeyEntry)) ||
          (signatureEntry.isNotEmpty && map.containsKey(signatureEntry))) {
        await prefs.setString(_lastNotificationKey, currentHash);
        await prefs.setString(_recentNotificationHashesKey, jsonEncode(map));
        return true;
      }

      map[currentHash] = nowMs;
      if (stableKeyEntry.isNotEmpty) map[stableKeyEntry] = nowMs;
      if (signatureEntry.isNotEmpty) map[signatureEntry] = nowMs;
      if (map.length > _recentNotificationMaxEntries) {
        final sorted = map.entries.toList()
          ..sort((a, b) {
            final ta = a.value is int
                ? a.value as int
                : int.tryParse(a.value.toString()) ?? 0;
            final tb = b.value is int
                ? b.value as int
                : int.tryParse(b.value.toString()) ?? 0;
            return ta.compareTo(tb);
          });
        final toDrop = sorted.length - _recentNotificationMaxEntries;
        for (var i = 0; i < toDrop; i++) {
          map.remove(sorted[i].key);
        }
      }

      await prefs.setString(_lastNotificationKey, currentHash);
      await prefs.setString(_recentNotificationHashesKey, jsonEncode(map));
      return false;
    } catch (e) {
      // print('Error al verificar notificación duplicada en receptor: $e');
      return false;
    }
  }

  // Método actualizado para mostrar notificaciones locales
  void _showLocalNotificationIfNew(
    Map<String, dynamic> notificationData,
    String notificationId,
  ) async {
    // Verificar si la notificación debe ser filtrada
    if (await _shouldFilterNotification(notificationData)) {
      // print('Notificación filtrada en receptor: $notificationId');
      return;
    }

    // Verificar si es una notificación duplicada
    if (await _isDuplicateNotification(notificationData)) {
      // print('Notificación duplicada en receptor, no se mostrará: $notificationId');
      return;
    }

    // Verificar si es pre-existente
    if (await NotificationCacheService.isPreExisting(notificationId)) {
      // print('Notificación pre-existente ignorada: $notificationId');
      return;
    }

    // Verificar si ya fue procesada
    if (await NotificationCacheService.isProcessed(notificationId)) {
      // print('Notificación ya procesada: $notificationId');
      return;
    }

    // Solo mostrar si la notificación no ha sido visualizada
    if (notificationData['status-visualizacion'] == false) {
      String clean(dynamic v) {
        final raw = (v ?? '').toString().trim();
        final lower = raw.toLowerCase();
        if (lower == 'null' || lower == 'undefined') return '';
        return raw;
      }

      String title = clean(notificationData['title']);
      if (title.isEmpty) title = clean(notificationData['titulo']);

      String body = clean(notificationData['text']);
      if (body.isEmpty) body = clean(notificationData['contenido']);
      if (body.isEmpty) body = clean(notificationData['body']);
      if (body.isEmpty) body = clean(notificationData['bigText']);

      if (body.isEmpty) return;

      if (title.isEmpty) title = 'Notificación';

      final stableKey = _extractStableSbnKey(notificationData);
      final signatureId = _extractStoredSignatureId(notificationData).isNotEmpty
          ? _extractStoredSignatureId(notificationData)
          : _generateStableSignatureId(notificationData);
      final localNotificationId =
          stableKey.isNotEmpty ? stableKey : (signatureId.isNotEmpty ? signatureId : notificationId);

      await LocalNotificationService.showNotification(
        title: title,
        body: body,
        packageName:
            notificationData['packageName'] ??
            notificationData['paquete'] ??
            '',
        appName:
            notificationData['appName'] ??
            notificationData['aplicacion'] ??
            'Aplicación desconocida',
        notificationId: localNotificationId,
        extras: notificationData,
      );
      
      // Marcar como procesada y visualizada
      await NotificationCacheService.markAsProcessed(notificationId);
      await NotificationCacheService.markAsVisualized(notificationId);
      
      // Actualizar estado en Firebase (solo para notificaciones nuevas)
      await _updateNotificationVisualizationStatus(notificationId, true);
    }
  }
  
  // Nuevo método para actualizar el estado de visualización en Firebase
  Future<void> _updateNotificationVisualizationStatus(String notificationId, bool visualized) async {
    try {
      final deviceId = await getLinkedDeviceId();
      if (deviceId == null) return;
      
      // Extraer la fecha del ID de notificación
      final dateId = _extractDateFromNotificationId(notificationId);
      if (dateId == null) return;
      
      final docRef = _firestore
          .collection('dispositivos')
          .doc(deviceId)
          .collection('notificaciones')
          .doc(dateId);
          
      await docRef.update({
        'notificaciones.$notificationId.visualizada': visualized,
      });
      
      // print('Estado de visualización actualizado para $notificationId: $visualized');
    } catch (e) {
      // print('Error al actualizar estado de visualización: $e');
    }
  }
  
  // Método auxiliar para extraer la fecha del ID de notificación
  String? _extractDateFromNotificationId(String notificationId) {
    try {
      final parts = notificationId.split('_');
      if (parts.isNotEmpty) {
        final timestamp = int.tryParse(parts[0]);
        if (timestamp != null) {
          final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
          return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        }
      }
    } catch (e) {
      // print('Error al extraer fecha del ID: $e');
    }
    return null;
  }

  // Método para limpiar el estado del receptor al desconectar
  void clearReceptorState() {
    _lastKnownNotificationIds.clear();
    _receptorStartTime = null;
    _isReceptorInitialLoad = true;
    // print('ReceptorService: Estado del receptor limpiado');
  }

  // Obtener el estado del dispositivo emisor
  Future<Map<String, dynamic>> getDeviceStatus(String deviceId) async {
    try {
      final deviceDoc = await _firestore
          .collection('dispositivos')
          .doc(deviceId)
          .get();

      if (!deviceDoc.exists) {
        throw Exception('Dispositivo no encontrado');
      }

      final data = deviceDoc.data() ?? {};

      return {
        'isServiceRunning': data['status-servicio'] ?? false,
        'isLinked': data['status-vinculacion'] ?? false,
      };
    } catch (e) {
      throw Exception('Error al obtener estado del dispositivo: $e');
    }
  }
}

class BtHiveStorageService {
  static const String _outboxBoxName = 'bt_notification_outbox_v1';
  static const String _poisonBoxName = 'bt_notification_poison_v1';
  static const String _firebaseCacheBoxName = 'bt_notification_firebase_cache_v1';
  static const String _appsBoxName = 'bt_apps_v1';
  static const String _mediaStateBoxName = 'bt_media_state_v1';
  static const String _volumeStateBoxName = 'bt_volume_state_v1';
  static const String _mediaPrefsBoxName = 'bt_media_prefs_v1';

  static bool _initialized = false;

  static Future<void> ensureInitialized() async {
    if (_initialized) return;
    await Hive.initFlutter();
    await Hive.openBox<Map>(_outboxBoxName);
    await Hive.openBox<Map>(_poisonBoxName);
    await Hive.openBox<Map>(_firebaseCacheBoxName);
    await Hive.openBox<Map>(_appsBoxName);
    await Hive.openBox<Map>(_mediaStateBoxName);
    await Hive.openBox<Map>(_volumeStateBoxName);
    await Hive.openBox<Map>(_mediaPrefsBoxName);
    _initialized = true;
  }

  static Future<void> setDefaultMediaAppPackage(String packageName) async {
    await ensureInitialized();
    final Box<Map> box = Hive.box<Map>(_mediaPrefsBoxName);
    box.put('default_app', {
      'packageName': packageName,
      'updatedAtMs': DateTime.now().millisecondsSinceEpoch,
    });
  }

  static Future<String?> getDefaultMediaAppPackage() async {
    await ensureInitialized();
    final Box<Map> box = Hive.box<Map>(_mediaPrefsBoxName);
    final value = box.get('default_app');
    if (value == null) return null;
    final map = Map<String, dynamic>.from(value);
    final pkg = (map['packageName'] ?? '').toString().trim();
    if (pkg.isEmpty) return null;
    return pkg;
  }

  static Future<Map<String, dynamic>?> getAppMeta(String packageName) async {
    await ensureInitialized();
    if (packageName.trim().isEmpty) return null;
    final Box<Map> apps = Hive.box<Map>(_appsBoxName);
    final value = apps.get(packageName);
    if (value == null) return null;
    return Map<String, dynamic>.from(value);
  }

  static Future<void> enqueueBtNotification(Map<String, dynamic> payload) async {
    await ensureInitialized();

    final String id = (payload['id'] ?? '').toString().trim();
    if (id.isEmpty) return;

    final Box<Map> outbox = Hive.box<Map>(_outboxBoxName);
    if (outbox.containsKey(id)) return;

    final int timestampMs = _extractTimestampMs(payload) ??
        DateTime.now().millisecondsSinceEpoch;

    final Map<String, dynamic> normalized = _normalizePayload(payload);
    final String payloadJson = jsonEncode(normalized);

    outbox.put(id, {
      'id': id,
      'timestampMs': timestampMs,
      'createdAtMs': DateTime.now().millisecondsSinceEpoch,
      'attempts': 0,
      'nextAttemptMs': 0,
      'lastAttemptMs': 0,
      'lastError': '',
      'visualizado': false,
      'payloadJson': payloadJson,
    });

    final String packageName = (payload['packageName'] ?? '').toString();
    if (packageName.isNotEmpty) {
      final String appName = (payload['appName'] ?? '').toString();
      final String iconBase64 = (payload['icon'] ?? '').toString();
      if (appName.isNotEmpty || iconBase64.isNotEmpty) {
        final Box<Map> apps = Hive.box<Map>(_appsBoxName);
        apps.put(packageName, {
          'packageName': packageName,
          'appName': appName,
          'icon': iconBase64,
          'updatedAtMs': DateTime.now().millisecondsSinceEpoch,
        });
      }
    }
  }

  static Future<void> setBtMediaState(Map<String, dynamic> payload) async {
    await ensureInitialized();
    final Box<Map> box = Hive.box<Map>(_mediaStateBoxName);
    box.put('current', {
      ...payload,
      'updatedAtMs': DateTime.now().millisecondsSinceEpoch,
    });
  }

  static Future<Map<String, dynamic>?> getBtMediaState() async {
    await ensureInitialized();
    final Box<Map> box = Hive.box<Map>(_mediaStateBoxName);
    final value = box.get('current');
    if (value == null) return null;
    return Map<String, dynamic>.from(value);
  }

  static Future<void> setBtVolumeState(Map<String, dynamic> payload) async {
    await ensureInitialized();
    final Box<Map> box = Hive.box<Map>(_volumeStateBoxName);
    box.put('current', {
      ...payload,
      'updatedAtMs': DateTime.now().millisecondsSinceEpoch,
    });
  }

  static Future<Map<String, dynamic>?> getBtVolumeState() async {
    await ensureInitialized();
    final Box<Map> box = Hive.box<Map>(_volumeStateBoxName);
    final value = box.get('current');
    if (value == null) return null;
    return Map<String, dynamic>.from(value);
  }

  static Future<void> markVisualized(String id, bool visualized) async {
    await ensureInitialized();
    final Box<Map> outbox = Hive.box<Map>(_outboxBoxName);
    final existing = outbox.get(id);
    if (existing != null) {
      outbox.put(id, {
        ...Map<String, dynamic>.from(existing),
        'visualizado': visualized,
      });
      return;
    }

    final Box<Map> cache = Hive.box<Map>(_firebaseCacheBoxName);
    final cached = cache.get(id);
    if (cached == null) return;
    cache.put(id, {
      ...Map<String, dynamic>.from(cached),
      'visualizado': visualized,
    });
  }

  static Future<List<Map<String, dynamic>>> getLocalNotificationsForUi({
    bool includeVisualized = true,
  }) async {
    await ensureInitialized();
    final Box<Map> outbox = Hive.box<Map>(_outboxBoxName);
    final Box<Map> cache = Hive.box<Map>(_firebaseCacheBoxName);

    final Map<String, Map<String, dynamic>> byId = {};

    void collectFromBox(Box<Map> box) {
      for (final key in box.keys) {
        final value = box.get(key);
        if (value == null) continue;

        final map = Map<String, dynamic>.from(value);
        final String id = (map['id'] ?? '').toString().trim();
        if (id.isEmpty) continue;

        final bool visualizado = map['visualizado'] == true;
        if (!includeVisualized && visualizado) continue;

        final payloadJson = (map['payloadJson'] ?? '').toString();
        final payload = _safeDecodePayload(payloadJson);
        final int timestampMs = (map['timestampMs'] as int?) ??
            _extractTimestampMs(payload) ??
            DateTime.now().millisecondsSinceEpoch;

        byId.putIfAbsent(id, () {
          return {
            'notificationId': id,
            'id': id,
            'title': payload['title'] ?? '',
            'text': payload['text'] ?? '',
            'packageName': payload['packageName'] ?? '',
            'appName': payload['appName'] ?? '',
            'timestamp': Timestamp.fromMillisecondsSinceEpoch(timestampMs),
            'extras': Map<String, dynamic>.from(payload['extras'] ?? {}),
            'status-visualizacion': visualizado,
          };
        });
      }
    }

    collectFromBox(cache);
    collectFromBox(outbox);

    final items = byId.values.toList();
    items.sort((a, b) {
      final ta = (a['timestamp'] as Timestamp).toDate();
      final tb = (b['timestamp'] as Timestamp).toDate();
      return tb.compareTo(ta);
    });

    return items;
  }

  static Iterable<MapEntry<String, Map<String, dynamic>>> getOutboxEntries() {
    final Box<Map> outbox = Hive.box<Map>(_outboxBoxName);
    return outbox.keys.map((k) {
      final key = k.toString();
      final value = outbox.get(k);
      return MapEntry(key, Map<String, dynamic>.from(value ?? {}));
    }).where((e) => e.value.isNotEmpty);
  }

  static Future<void> updateOutboxEntry(
    String id,
    Map<String, dynamic> updated,
  ) async {
    await ensureInitialized();
    final Box<Map> outbox = Hive.box<Map>(_outboxBoxName);
    outbox.put(id, updated);
  }

  static Future<void> deleteOutboxEntry(String id) async {
    await ensureInitialized();
    final Box<Map> outbox = Hive.box<Map>(_outboxBoxName);
    await outbox.delete(id);
    final Box<Map> cache = Hive.box<Map>(_firebaseCacheBoxName);
    await cache.delete(id);
  }

  static Future<void> cacheFirebaseNotifications(
    List<Map<String, dynamic>> notifications,
  ) async {
    await ensureInitialized();
    final Box<Map> cache = Hive.box<Map>(_firebaseCacheBoxName);
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    for (final n in notifications) {
      final String id =
          (n['notificationId'] ?? n['id'] ?? '').toString().trim();
      if (id.isEmpty) continue;

      final dynamic ts = n['timestamp'];
      final int? tsMs = ts is Timestamp
          ? ts.millisecondsSinceEpoch
          : (ts is int ? ts : int.tryParse(ts?.toString() ?? ''));
      final int timestampMs = tsMs ?? nowMs;

      final bool visualizado = n['status-visualizacion'] == true;

      final Map<String, dynamic> payload = Map<String, dynamic>.from(n);
      payload['id'] = id;
      payload['time'] = timestampMs;
      if ((payload['icon'] ?? '').toString().trim().isEmpty) {
        final icon = (payload['appIcon'] ?? '').toString().trim();
        if (icon.isNotEmpty) {
          payload['icon'] = icon;
        }
      }
      final normalized = _normalizePayload(payload);
      final payloadJson = jsonEncode(normalized);

      final existing = cache.get(id);
      if (existing != null) {
        final existingMap = Map<String, dynamic>.from(existing);
        final int existingMs = (existingMap['timestampMs'] as int?) ?? 0;
        final bool existingVisual = existingMap['visualizado'] == true;
        final String existingPayload = (existingMap['payloadJson'] ?? '').toString();

        final shouldUpdate = existingMs != timestampMs ||
            existingVisual != visualizado ||
            existingPayload != payloadJson;

        if (!shouldUpdate) continue;
      }

      cache.put(id, {
        'id': id,
        'timestampMs': timestampMs,
        'createdAtMs': nowMs,
        'visualizado': visualizado,
        'payloadJson': payloadJson,
      });
    }
  }

  static Future<void> moveToPoison(String id, Map<String, dynamic> entry) async {
    await ensureInitialized();
    final Box<Map> poison = Hive.box<Map>(_poisonBoxName);
    await poison.put(id, entry);
    await deleteOutboxEntry(id);
  }

  static int? _extractTimestampMs(Map<String, dynamic> payload) {
    final dynamic time = payload['time'] ?? payload['timestampMs'];
    if (time is int) return time;
    if (time is String) return int.tryParse(time);
    return null;
  }

  static Map<String, dynamic> _normalizePayload(Map<String, dynamic> payload) {
    final normalized = Map<String, dynamic>.from(payload);
    final dynamic rawExtras = payload['extras'];
    final Map<String, dynamic> extras = rawExtras is Map
        ? Map<String, dynamic>.from(rawExtras)
        : <String, dynamic>{};

    for (final key in payload.keys) {
      if (key == 'id' ||
          key == 'title' ||
          key == 'text' ||
          key == 'packageName' ||
          key == 'appName' ||
          key == 'time' ||
          key == 'timestampMs' ||
          key == 'extras' ||
          key == 'icon') {
        continue;
      }
      extras[key] = payload[key];
    }

    normalized['extras'] = extras;
    return normalized;
  }

  static Map<String, dynamic> _safeDecodePayload(String payloadJson) {
    try {
      final decoded = jsonDecode(payloadJson);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return {};
    } catch (_) {
      return {};
    }
  }
}

class BtHiveSyncService {
  static const int _maxAttemptsBeforePoison = 30;
  static const String _recentWhatsAppPayloadKey =
      'bt_hive_recent_whatsapp_payload_hashes_v1';
  static const int _recentWhatsAppPayloadMaxEntries = 2000;
  static const int _recentWhatsAppPayloadTtlMs = 24 * 60 * 60 * 1000;

  static Future<void> syncOutboxToFirebase() async {
    await BtHiveStorageService.ensureInitialized();

    final receptorService = ReceptorService();
    final linkedDeviceId = await receptorService.getLinkedDeviceId();
    if (linkedDeviceId == null || linkedDeviceId.isEmpty) return;

    final firestore = FirebaseFirestore.instance;
    final linkedDoc = await firestore
        .collection('dispositivos')
        .doc(linkedDeviceId)
        .get();

    final linkedData = linkedDoc.data();
    final bool saveEnabled = linkedData?['status-guardado'] == true;
    if (!saveEnabled) return;

    final int nowMs = DateTime.now().millisecondsSinceEpoch;

    final entries = BtHiveStorageService.getOutboxEntries().toList();
    entries.sort((a, b) {
      final int ca = (a.value['createdAtMs'] as int?) ?? 0;
      final int cb = (b.value['createdAtMs'] as int?) ?? 0;
      return ca.compareTo(cb);
    });

    for (final entry in entries) {
      final String id = entry.key;
      final Map<String, dynamic> value = entry.value;

      final int nextAttemptMs = (value['nextAttemptMs'] as int?) ?? 0;
      if (nextAttemptMs > nowMs) continue;

      final String payloadJson = (value['payloadJson'] ?? '').toString();
      final payload = BtHiveStorageService._safeDecodePayload(payloadJson);

      final int timestampMs = (value['timestampMs'] as int?) ??
          BtHiveStorageService._extractTimestampMs(payload) ??
          DateTime.now().millisecondsSinceEpoch;

      final int attempts = (value['attempts'] as int?) ?? 0;

      try {
        final bool duplicateContent = await _isDuplicateWhatsAppPayloadContent(payload);
        if (duplicateContent) {
          await BtHiveStorageService.deleteOutboxEntry(id);
          continue;
        }

        final bool alreadyInFirebase = await _isAlreadyInFirebase(
          linkedDeviceId,
          id,
          timestampMs,
        );

        if (alreadyInFirebase) {
          await BtHiveStorageService.deleteOutboxEntry(id);
          continue;
        }

        await _uploadToFirebase(
          linkedDeviceId: linkedDeviceId,
          id: id,
          timestampMs: timestampMs,
          payload: payload,
        );

        final bool verified = await _isAlreadyInFirebase(
          linkedDeviceId,
          id,
          timestampMs,
        );

        if (verified) {
          await BtHiveStorageService.deleteOutboxEntry(id);
          continue;
        }

        throw StateError('No se pudo verificar existencia en Firestore');
      } catch (e) {
        final int nextAttempts = attempts + 1;
        final int backoffMs = _computeBackoffMs(nextAttempts);
        final Map<String, dynamic> updated = {
          ...value,
          'attempts': nextAttempts,
          'lastAttemptMs': nowMs,
          'nextAttemptMs': nowMs + backoffMs,
          'lastError': e.toString(),
        };

        if (_isPermanentError(e) && nextAttempts >= 3) {
          await BtHiveStorageService.moveToPoison(id, updated);
          continue;
        }

        if (nextAttempts >= _maxAttemptsBeforePoison) {
          await BtHiveStorageService.moveToPoison(id, updated);
          continue;
        }

        await BtHiveStorageService.updateOutboxEntry(id, updated);
      }
    }
  }

  static Future<bool> _isDuplicateWhatsAppPayloadContent(
    Map<String, dynamic> payload,
  ) async {
    final packageName = (payload['packageName'] ?? '').toString();
    if (packageName != 'com.whatsapp' && packageName != 'com.whatsapp.w4b') {
      return false;
    }

    final title = (payload['title'] ?? '').toString();
    final text = (payload['text'] ?? '').toString();
    final normalized = _normalizeForHash('$packageName|$title|$text');
    if (normalized.isEmpty) return false;
    final hash = normalized.hashCode.toString();
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_recentWhatsAppPayloadKey);
    Map<String, dynamic> map;
    try {
      map = raw == null || raw.isEmpty
          ? <String, dynamic>{}
          : (jsonDecode(raw) as Map).cast<String, dynamic>();
    } catch (_) {
      map = <String, dynamic>{};
    }

    final cutoffMs = nowMs - _recentWhatsAppPayloadTtlMs;
    final keysToRemove = <String>[];
    for (final entry in map.entries) {
      final ts = entry.value;
      final tsMs = ts is int ? ts : int.tryParse(ts.toString());
      if (tsMs == null || tsMs < cutoffMs) {
        keysToRemove.add(entry.key);
      }
    }
    for (final k in keysToRemove) {
      map.remove(k);
    }

    if (map.containsKey(hash)) {
      await prefs.setString(_recentWhatsAppPayloadKey, jsonEncode(map));
      return true;
    }

    map[hash] = nowMs;
    if (map.length > _recentWhatsAppPayloadMaxEntries) {
      final sorted = map.entries.toList()
        ..sort((a, b) {
          final ta = a.value is int ? a.value as int : int.tryParse(a.value.toString()) ?? 0;
          final tb = b.value is int ? b.value as int : int.tryParse(b.value.toString()) ?? 0;
          return ta.compareTo(tb);
        });
      final toDrop = sorted.length - _recentWhatsAppPayloadMaxEntries;
      for (var i = 0; i < toDrop; i++) {
        map.remove(sorted[i].key);
      }
    }

    await prefs.setString(_recentWhatsAppPayloadKey, jsonEncode(map));
    return false;
  }

  static String _normalizeForHash(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[áàäâ]'), 'a')
        .replaceAll(RegExp(r'[éèëê]'), 'e')
        .replaceAll(RegExp(r'[íìïî]'), 'i')
        .replaceAll(RegExp(r'[óòöô]'), 'o')
        .replaceAll(RegExp(r'[úùüû]'), 'u')
        .replaceAll(RegExp(r'[ñ]'), 'n')
        .replaceAll(RegExp(r'[^a-z0-9\s\|]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static int _computeBackoffMs(int attempts) {
    final int capped = attempts.clamp(0, 12);
    final int seconds = 5 * (1 << capped);
    final int maxSeconds = 60 * 60;
    return (seconds > maxSeconds ? maxSeconds : seconds) * 1000;
  }

  static bool _isPermanentError(Object e) {
    if (e is FirebaseException) {
      final code = e.code.toLowerCase();
      if (code.contains('permission-denied')) return true;
      if (code.contains('invalid-argument')) return true;
      if (code.contains('failed-precondition')) return true;
    }
    final msg = e.toString().toLowerCase();
    if (msg.contains('permission-denied')) return true;
    if (msg.contains('invalid-argument')) return true;
    if (msg.contains('failed-precondition')) return true;
    return false;
  }

  static String _dateIdFromTimestampMs(int timestampMs) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestampMs);
    final y = date.year.toString();
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static Future<bool> _isAlreadyInFirebase(
    String linkedDeviceId,
    String notificationId,
    int timestampMs,
  ) async {
    final firestore = FirebaseFirestore.instance;
    final dateId = _dateIdFromTimestampMs(timestampMs);

    final dayDocRef = firestore
        .collection('dispositivos')
        .doc(linkedDeviceId)
        .collection('notificaciones')
        .doc(dateId);

    final dayDoc = await dayDocRef.get();
    if (!dayDoc.exists) return false;

    final data = dayDoc.data();
    if (data == null) return false;

    final notificaciones = data['notificaciones'];
    if (notificaciones is Map) {
      return notificaciones.containsKey(notificationId);
    }
    return false;
  }

  static Future<void> _uploadToFirebase({
    required String linkedDeviceId,
    required String id,
    required int timestampMs,
    required Map<String, dynamic> payload,
  }) async {
    final firestore = FirebaseFirestore.instance;
    final dateId = _dateIdFromTimestampMs(timestampMs);

    final dayDocRef = firestore
        .collection('dispositivos')
        .doc(linkedDeviceId)
        .collection('notificaciones')
        .doc(dateId);

    final dayDoc = await dayDocRef.get();
    if (!dayDoc.exists) {
      final now = DateTime.fromMillisecondsSinceEpoch(timestampMs);
      await dayDocRef.set({
        'fecha': Timestamp.fromDate(DateTime(now.year, now.month, now.day)),
      });
    }

    final notificationData = NotificationData(
      id: id,
      title: (payload['title'] ?? '').toString(),
      text: (payload['text'] ?? '').toString(),
      packageName: (payload['packageName'] ?? '').toString(),
      appName: (payload['appName'] ?? '').toString(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(timestampMs),
      extras: payload['extras'] is Map
          ? Map<String, dynamic>.from(payload['extras'] as Map)
          : <String, dynamic>{},
      statusVisualizacion: false,
    );

    await dayDocRef.update({
      'notificaciones.$id': notificationData.toMap(),
    });
  }
}
