import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connect/models/notification_data.dart';
import 'package:connect/services/firebase_service.dart';
import 'package:connect/services/local_notification_service.dart';
import 'package:connect/services/notification_cache_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReceptorService {
  final FirebaseService _firebaseService = FirebaseService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Clave para almacenar el ID del dispositivo emisor vinculado
  static const String KEY_LINKED_DEVICE_ID = 'linked_device_id';

  // Verificar si un código de vinculación existe en Firestore
  Future<String?> verifyLinkCode(String code) async {
    try {
      final QuerySnapshot querySnapshot = await _firestore
          .collection('dispositivos')
          .get();

      for (var doc in querySnapshot.docs) {
        if (doc.id == code) {
          print('Dispositivo encontrado con ID: ${doc.id}');
          return doc.id;
        }
      }

      print('No se encontró ningún dispositivo con el código: $code');
      return null;
    } catch (e) {
      print('Error al verificar código de vinculación: $e');
      return null;
    }
  }

  // Guardar el ID del dispositivo emisor vinculado en SharedPreferences
  Future<bool> saveLinkedDeviceId(String deviceId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(KEY_LINKED_DEVICE_ID, deviceId);

      await _firebaseService.updateLinkStatus(true, deviceId);

      print('ID del dispositivo emisor guardado: $deviceId');
      return true;
    } catch (e) {
      print('Error al guardar ID del dispositivo emisor: $e');
      return false;
    }
  }

  // Obtener el ID del dispositivo emisor vinculado
  Future<String?> getLinkedDeviceId() async {
    try {
      print('[DEBUG] getLinkedDeviceId: Start');
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString(KEY_LINKED_DEVICE_ID);
      print('[DEBUG] getLinkedDeviceId: Result = $id');
      return id;
    } catch (e) {
      print('Error al obtener ID del dispositivo emisor: $e');
      return null;
    }
  }

  // Método para actualizar el estado de visualización de una notificación
  Future<void> updateNotificationVisualizationStatus(
    String notificationId,
    bool visualizado,
  ) async {
    try {
      final deviceId = await getLinkedDeviceId();
      if (deviceId == null) {
        print('No hay dispositivo emisor vinculado');
        return;
      }

      final uniqueId = notificationId;
      final int millisecondsSinceEpoch = int.parse(uniqueId);
      print('Milisegundos (int): $millisecondsSinceEpoch');

      final DateTime dateTimeObject = DateTime.fromMillisecondsSinceEpoch(
        millisecondsSinceEpoch,
      );
      print('Objeto DateTime: $dateTimeObject');

      final String year = dateTimeObject.year.toString();
      final String month = dateTimeObject.month.toString().padLeft(2, '0');
      final String day = dateTimeObject.day.toString().padLeft(2, '0');

      final String dateId = '$year-$month-$day';
      final docRef = _firestore
          .collection('dispositivos')
          .doc(deviceId)
          .collection('notificaciones')
          .doc(dateId);

      await docRef.update({
        'notificaciones.$notificationId.status-visualizacion': visualizado,
      });
      print(
        'Estado de visualización actualizado para notificación $notificationId: $visualizado',
      );
    } catch (e) {
      print('Error al actualizar estado de visualización: $e');
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
      print('Error al filtrar notificaciones visualizadas: $e');
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
      print('Error al filtrar notificaciones no visualizadas: $e');
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
                print(
                  'Error: datos de notificación inválidos para $notificationId',
                );
              }
            } catch (e) {
              print('Error al procesar notificación $notificationId: $e');
            }
          });
        }
      }

      allNotifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      return allNotifications;
    } catch (e, stackTrace) {
      print('Error al obtener notificaciones almacenadas: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }

  // Iniciar escucha de notificaciones desde Firebase
  // Modificar el método listenForNotifications
  Stream<List<Map<String, dynamic>>> listenForNotifications() async* {
  try {
    final deviceId = await getLinkedDeviceId();
    if (deviceId == null) {
      print('No hay dispositivo emisor vinculado');
      yield [];
      return;
    }

    final DateTime now = DateTime.now();
    final String dateId =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final dayDocRef = _firestore
        .collection('dispositivos')
        .doc(deviceId)
        .collection('notificaciones')
        .doc(dateId);

    // Variable para controlar si es la primera carga
    bool isFirstLoad = true;

    yield* dayDocRef.snapshots().map((snapshot) {
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
            notif['notificationId'] = entry.key;

            if (notif['timestamp'] is Timestamp) {
              // Solo procesar notificaciones nuevas después de la primera carga
              if (!isFirstLoad) {
                _showLocalNotificationIfNew(notif, entry.key);
              }
              return notif;
            } else {
              return null;
            }
          })
          .where((notif) => notif != null)
          .cast<Map<String, dynamic>>()
          .toList();

      // Marcar que ya no es la primera carga
      isFirstLoad = false;

      notificationsList.sort((a, b) {
        final DateTime timeA = (a['timestamp'] as Timestamp).toDate();
        final DateTime timeB = (b['timestamp'] as Timestamp).toDate();
        return timeB.compareTo(timeA);
      });

      return notificationsList;
    });
  } catch (e) {
    print('Error al escuchar notificaciones: $e');
    yield <Map<String, dynamic>>[];
  }
}

  // Método privado para mostrar notificación local cuando se detecta una nueva
  // Método mejorado para inicializar el receptor sin mostrar notificaciones existentes
  Future<void> initializeReceptorWithoutNotifications() async {
    try {
      final deviceId = await getLinkedDeviceId();
      if (deviceId == null) {
        print('No hay dispositivo emisor vinculado');
        return;
      }
  
      // Obtener todas las notificaciones existentes
      final existingNotifications = await getStoredNotifications();
  
      // Crear un Set con los IDs de notificaciones existentes
      final Set<String> existingNotificationIds = existingNotifications
          .map((notification) => notification.id)
          .toSet();
  
      // Usar el nuevo servicio de caché
      await NotificationCacheService.registerPreExistingNotifications(existingNotificationIds);
  
      print(
        'Receptor inicializado. ${existingNotificationIds.length} notificaciones existentes registradas como pre-existentes.',
      );
    } catch (e) {
      print('Error al inicializar receptor: $e');
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
      print('Notificación filtrada: Contenido vacío - Package: $packageName');
      return true;
    }
    
    // Solo aplicar filtros específicos a WhatsApp
    if (packageName == 'com.whatsapp' || packageName == 'com.whatsapp.w4b') {
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
      
      // Filtros específicos de WhatsApp...
      final List<RegExp> messagePatterns = [
        RegExp(r'\d+\s*mensajes?\s*de\s*\d+\s*chats?'),
        RegExp(r'\d+\s*messages?\s*from\s*\d+\s*chats?'),
        RegExp(r'\d+\s*nuevos?\s*mensajes?'),
        RegExp(r'\d+\s*new\s*messages?'),
        RegExp(r'\d+\s*mensajes?\s*nuevos?'),
      ];
      
      for (final pattern in messagePatterns) {
        if (pattern.hasMatch(normalizedContent)) {
          return true;
        }
      }
      
      final List<String> callKeywords = [
        'llamando', 'calling', 'llamada entrante', 'incoming call',
        'llamada perdida', 'missed call', 'llamada de', 'call from',
        'videollamada', 'video call',
      ];
      
      for (final keyword in callKeywords) {
        if (normalizedContent.contains(keyword)) {
          return true;
        }
      }
      
      final List<String> backupKeywords = [
        'copia de seguridad', 'backup', 'respaldo', 'copia de seg',
        'backing up', 'guardando copia',
      ];
      
      for (final keyword in backupKeywords) {
        if (normalizedContent.contains(keyword)) {
          return true;
        }
      }
      
      // Filtros genéricos para WhatsApp
      final List<String> genericKeywords = [
        'nueva notificacion', 'new notification', 'contenido no disponible',
        'content not available', 'content unavailable', 'mensaje no disponible',
        'message not available', 'sin contenido', 'no content',
      ];
      
      for (final keyword in genericKeywords) {
        if (normalizedContent.contains(keyword)) {
          return true;
        }
      }
    }
    
    return false;
  }


  // Método actualizado para mostrar notificaciones locales
  void _showLocalNotificationIfNew(
    Map<String, dynamic> notificationData,
    String notificationId,
  ) async {
    // Verificar si la notificación debe ser filtrada
    if (_shouldFilterNotification(notificationData)) {
      print('Notificación filtrada en receptor: $notificationId');
      return;
    }

    // Verificar si es pre-existente
    if (await NotificationCacheService.isPreExisting(notificationId)) {
      print('Notificación pre-existente ignorada: $notificationId');
      return;
    }

    // Verificar si ya fue procesada
    if (await NotificationCacheService.isProcessed(notificationId)) {
      print('Notificación ya procesada: $notificationId');
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
      } else if (notificationData['body'] != null &&
          notificationData['body'].toString().isNotEmpty) {
        body = notificationData['body'].toString();
      } else if (notificationData['bigText'] != null &&
          notificationData['bigText'].toString().isNotEmpty) {
        body = notificationData['bigText'].toString();
      } else if (notificationData['mensaje'] != null &&
          notificationData['mensaje'].toString().isNotEmpty) {
        body = notificationData['mensaje'].toString();
      } else if (notificationData['contenido'] != null &&
          notificationData['contenido'].toString().isNotEmpty) {
        body = notificationData['contenido'].toString();
      }

      // Mostrar la notificación local con todos los datos
      await LocalNotificationService.showNotification(
        title: title,
        body: body,
        packageName: notificationData['packageName'] ??
            notificationData['paquete'] ??
            '',
        appName: notificationData['appName'] ??
            notificationData['aplicacion'] ??
            'Aplicación desconocida',
        notificationId: notificationId,
        fullNotificationData: notificationData, // Pasar todos los datos
      );
      
      // Marcar como procesada y visualizada
      await NotificationCacheService.markAsProcessed(notificationId);
      await NotificationCacheService.markAsVisualized(notificationId);
      
      // Actualizar estado en Firebase (solo para notificaciones nuevas)
      await _updateNotificationVisualizationStatus(notificationId, true);
    }
  }

  // Método mejorado para actualizar el estado de visualización en Firebase
  Future<void> _updateNotificationVisualizationStatus(String notificationId, bool visualized) async {
    try {
      // Verificar si es una notificación pre-existente
      if (await NotificationCacheService.isPreExisting(notificationId)) {
        print('No se actualiza estado de notificación pre-existente: $notificationId');
        return;
      }
      
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
          
      // Actualizar ambos campos de estado de visualización
      await docRef.update({
        'notificaciones.$notificationId.status-visualizacion': visualized,
        'notificaciones.$notificationId.visualizada': visualized,
      });
      
      print('Estado de visualización actualizado para $notificationId: $visualized');
    } catch (e) {
      print('Error al actualizar estado de visualización: $e');
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
      print('Error al extraer fecha del ID: $e');
    }
    return null;
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
