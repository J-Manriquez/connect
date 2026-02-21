import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connect/models/notification_data.dart';
import 'package:connect/services/ble_service.dart';
import 'package:connect/services/firebase_service.dart';
import 'package:connect/services/local_notification_service.dart';
import 'package:connect/services/notification_cache_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReceptorService {
  final FirebaseService _firebaseService = FirebaseService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Clave para almacenar el ID del dispositivo emisor vinculado
  static const String keyLinkedDeviceId = 'linked_device_id';
  static const String _lastNotificationKey = 'receptor_last_notification_hash';

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
      final allNotificationsStream = listenForNotifications();

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
      final allNotificationsStream = listenForNotifications();

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

      yield* dayDocRef.snapshots().map((snapshot) {
        if (!snapshot.exists ||
            !snapshot.data()!.containsKey('notificaciones')) {
          return <Map<String, dynamic>>[];
        }

        final Map<String, dynamic> notificationsMap =
            snapshot.data()!['notificaciones'] as Map<String, dynamic>;

        // Procesar solo notificaciones nuevas para mostrar localmente
        _processNewNotificationsForLocalDisplay(notificationsMap, dateId);

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

        return notificationsList;
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
  bool _shouldFilterNotification(Map<String, dynamic> notification) {
    final String packageName = notification['packageName'] ?? '';

    // Filtro universal: Notificaciones vacías (aplicar a todas las aplicaciones)
    final String title = (notification['title'] ?? '').toString().trim();
    final String text = (notification['text'] ?? '').toString().trim();
    final String bigText = (notification['bigText'] ?? '').toString().trim();
    final String body = (notification['body'] ?? '').toString().trim();
    final String mensaje = (notification['mensaje'] ?? '').toString().trim();
    final String contenido = (notification['contenido'] ?? '').toString().trim();
    
    // Si todos los campos de contenido están vacíos, filtrar la notificación
    if (title.isEmpty && text.isEmpty && bigText.isEmpty && 
        body.isEmpty && mensaje.isEmpty && contenido.isEmpty) {
      //// print('Notificación filtrada: Contenido vacío - Package: $packageName');
      return true;
    }
    
    // Solo aplicar filtros a WhatsApp e Instagram
    if (packageName == 'com.whatsapp' || packageName == 'com.whatsapp.w4b' || 
        packageName == 'com.instagram.android') {
      // Recopilar TODOS los textos posibles de la notificación
      final List<String> allTexts = [
        notification['title'] ?? '',
        notification['text'] ?? '',
        notification['bigText'] ?? '',
        notification['subText'] ?? '',
        notification['summaryText'] ?? '',
        notification['infoText'] ?? '',
        notification['contentInfo'] ?? '',
        notification['body'] ?? '',
        notification['mensaje'] ?? '',
        notification['contenido'] ?? '',
        notification['titulo'] ?? '',
      ];
      
      // Combinar todos los textos y normalizar
      final String allContent = allTexts.join(' ').toLowerCase();
      // Normalizar: remover acentos, caracteres especiales y espacios múltiples
      final String normalizedContent = allContent
          .replaceAll(RegExp(r'[áàäâ]'), 'a')
          .replaceAll(RegExp(r'[éèëê]'), 'e')
          .replaceAll(RegExp(r'[íìïî]'), 'i')
          .replaceAll(RegExp(r'[óòöô]'), 'o')
          .replaceAll(RegExp(r'[úùüû]'), 'u')
          .replaceAll(RegExp(r'[ñ]'), 'n')
          .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      
      // print('Contenido normalizado para filtro: "$normalizedContent"');
      
      // Filtros específicos para Instagram
      if (packageName == 'com.instagram.android') {
        // Filtro 1: Subida de contenido multimedia
        final List<String> uploadKeywords = [
          'subiendo contenido multimedia',
          'uploading media content',
          'subiendo contenido',
          'uploading content',
        ];
        
        for (final keyword in uploadKeywords) {
          if (normalizedContent.contains(keyword)) {
            // print('Notificación filtrada: Subida de contenido - "$normalizedContent"');
            return true;
          }
        }
        
        // Filtro 2: Historias
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
            // print('Notificación filtrada: Historia - "$normalizedContent"');
            return true;
          }
        }
        
        // Filtro 3: Llamadas y videollamadas (similar a WhatsApp)
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
            // print('Notificación filtrada: Llamada Instagram - "$normalizedContent"');
            return true;
          }
        }
      }
      
      // Filtros existentes para WhatsApp (mantener como están)
      if (packageName == 'com.whatsapp' || packageName == 'com.whatsapp.w4b') {
        // Filtro 1: Resúmenes de mensajes
        final List<RegExp> messagePatterns = [
          RegExp(r'\d+\s*mensajes?\s*de\s*\d+\s*chats?'),
          RegExp(r'\d+\s*messages?\s*from\s*\d+\s*chats?'),
          RegExp(r'\d+\s*nuevos?\s*mensajes?'),
          RegExp(r'\d+\s*new\s*messages?'),
          RegExp(r'\d+\s*mensajes?\s*nuevos?'), // Nuevo filtro
        ];
        
        for (final pattern in messagePatterns) {
          if (pattern.hasMatch(normalizedContent)) {
            // print('Notificación filtrada: Resumen de mensajes - "$normalizedContent"');
            return true;
          }
        }
        
        // Filtro 2: Llamadas
        final List<String> callKeywords = [
          'llamando',
          'Llamada en curso'
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
            // print('Notificación filtrada: Llamada - "$normalizedContent"');
            return true;
          }
        }
        
        // Filtro 3: Copias de seguridad
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
            // print('Notificación filtrada: Copia de seguridad - "$normalizedContent"');
            return true;
          }
        }
        
        // Filtro 4: Notificaciones genéricas y contenido no disponible (NUEVOS FILTROS)
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
            // print('Notificación filtrada: Contenido genérico - "$normalizedContent"');
            return true;
          }
        }
      }
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

  // Método para verificar si la notificación es duplicada en el receptor
  Future<bool> _isDuplicateNotification(Map<String, dynamic> notification) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String currentHash = _generateNotificationHash(notification);
      final String? lastHash = prefs.getString(_lastNotificationKey);
      
      if (lastHash != null && lastHash == currentHash) {
        // print('Notificación duplicada detectada en receptor: $currentHash');
        return true;
      }
      
      // Guardar el hash de la notificación actual
      await prefs.setString(_lastNotificationKey, currentHash);
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
    if (_shouldFilterNotification(notificationData)) {
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
      // Extraer el contenido dinámico de la notificación
      String title = 'Nueva notificación';
      String body = 'Contenido no disponible';

      // Intentar obtener título de diferentes campos posibles
      if (notificationData['title'] != null &&
          notificationData['title'].toString().isNotEmpty) {
        title = notificationData['title'].toString();
      } else if (notificationData['titulo'] != null &&
          notificationData['titulo'].toString().isNotEmpty) {
        title = notificationData['titulo'].toString();
      }

      // Intentar obtener contenido de diferentes campos posibles
      if (notificationData['text'] != null &&
          notificationData['text'].toString().isNotEmpty) {
        body = notificationData['text'].toString();
      } else if (notificationData['contenido'] != null &&
          notificationData['contenido'].toString().isNotEmpty) {
        body = notificationData['contenido'].toString();
      } else if (notificationData['body'] != null &&
          notificationData['body'].toString().isNotEmpty) {
        body = notificationData['body'].toString();
      } else if (notificationData['bigText'] != null &&
          notificationData['bigText'].toString().isNotEmpty) {
        body = notificationData['bigText'].toString();
      }

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
        notificationId: notificationId,
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
    if (existing == null) return;
    outbox.put(id, {
      ...Map<String, dynamic>.from(existing),
      'visualizado': visualized,
    });
  }

  static Future<List<Map<String, dynamic>>> getLocalNotificationsForUi({
    bool includeVisualized = true,
  }) async {
    await ensureInitialized();
    final Box<Map> outbox = Hive.box<Map>(_outboxBoxName);

    final List<Map<String, dynamic>> items = [];
    for (final key in outbox.keys) {
      final value = outbox.get(key);
      if (value == null) continue;

      final map = Map<String, dynamic>.from(value);
      final bool visualizado = map['visualizado'] == true;
      if (!includeVisualized && visualizado) continue;

      final payloadJson = (map['payloadJson'] ?? '').toString();
      final payload = _safeDecodePayload(payloadJson);
      final int timestampMs = (map['timestampMs'] as int?) ??
          _extractTimestampMs(payload) ??
          DateTime.now().millisecondsSinceEpoch;

      items.add({
        'notificationId': map['id']?.toString() ?? '',
        'id': map['id']?.toString() ?? '',
        'title': payload['title'] ?? '',
        'text': payload['text'] ?? '',
        'packageName': payload['packageName'] ?? '',
        'appName': payload['appName'] ?? '',
        'timestamp': Timestamp.fromMillisecondsSinceEpoch(timestampMs),
        'extras': Map<String, dynamic>.from(payload['extras'] ?? {}),
        'status-visualizacion': visualizado,
      });
    }

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
