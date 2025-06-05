import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connect/models/notification_data.dart';
import 'package:connect/services/firebase_service.dart';
import 'package:connect/services/local_notification_service.dart';
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
          final Map<String, dynamic> notificationsMap = data['notificaciones'] as Map<String, dynamic>;
          
          notificationsMap.forEach((notificationId, notificationData) {
            try {
              if (notificationData != null && notificationData is Map<String, dynamic>) {
                final Map<String, dynamic> notificationDataMap = Map<String, dynamic>.from(notificationData);
                notificationDataMap['dateId'] = dayDoc.id;
                
                if (notificationDataMap.containsKey('timestamp') && 
                    notificationDataMap['timestamp'] is Timestamp) {
                  allNotifications.add(NotificationData.fromMap(notificationDataMap));
                }
              } else {
                print('Error: datos de notificación inválidos para $notificationId');
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
              notif['notificationId'] = entry.key; // Agregar el ID de la notificación
              
              if (notif['timestamp'] is Timestamp) {
                // Mostrar notificación local cuando se detecta una nueva
                _showLocalNotificationIfNew(notif, entry.key);
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
      print('Error al escuchar notificaciones: $e');
      yield <Map<String, dynamic>>[];
    }
  }
  
  // Método privado para mostrar notificación local cuando se detecta una nueva
  // Nuevo método para inicializar el receptor sin mostrar notificaciones existentes
  Future<void> initializeReceptorWithoutNotifications() async {
    try {
      final deviceId = await getLinkedDeviceId();
      if (deviceId == null) {
        print('No hay dispositivo emisor vinculado');
        return;
      }
      
      // Obtener todas las notificaciones existentes y marcarlas como "procesadas"
      // para que no se muestren como notificaciones locales
      final existingNotifications = await getStoredNotifications();
      
      // Crear un Set con los IDs de notificaciones existentes
      final Set<String> existingNotificationIds = existingNotifications
          .map((notification) => notification.id)
          .toSet();
      
      // Guardar estos IDs en SharedPreferences para referencia futura
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('existing_notification_ids', existingNotificationIds.toList());
      
      print('Receptor inicializado. ${existingNotificationIds.length} notificaciones existentes no se mostrarán como locales.');
    } catch (e) {
      print('Error al inicializar receptor: $e');
    }
  }
  
  // Método modificado para verificar si una notificación es nueva
  bool _isNewNotification(String notificationId) {
    // Verificar si la notificación ya existía cuando se inicializó el receptor
    final prefs = SharedPreferences.getInstance();
    return prefs.then((prefs) {
      final existingIds = prefs.getStringList('existing_notification_ids') ?? [];
      return !existingIds.contains(notificationId);
    }) as bool;
  }
  
  // Método para verificar si una notificación debe ser filtrada (mismo que en FirebaseService)
bool _shouldFilterNotification(Map<String, dynamic> notificationData) {
  final String packageName = notificationData['packageName'] ?? notificationData['paquete'] ?? '';
  final String title = notificationData['title'] ?? notificationData['titulo'] ?? '';
  final String text = notificationData['text'] ?? notificationData['contenido'] ?? '';
  final String bigText = notificationData['bigText'] ?? '';
  
  // Solo aplicar filtros a WhatsApp
  if (packageName == 'com.whatsapp' || packageName == 'com.whatsapp.w4b') {
    // Combinar todos los textos posibles para verificar
    final String content = '$title $text $bigText'.toLowerCase();
    
    // Filtro 1: Mensajes que comienzan con '{numero} mensajes de {numero} chats'
    final RegExp messagesPattern = RegExp(r'^\d+\s+mensajes?\s+de\s+\d+\s+chats?', caseSensitive: false);
    if (messagesPattern.hasMatch(content)) {
      return true;
    }
    
    // Filtro 2: Mensajes que comienzan con 'llamando...' o 'llamada entrante'
    if (content.startsWith('llamando') || content.startsWith('llamada entrante')) {
      return true;
    }
    
    // Filtro 3: Mensajes que comienzan con 'copia de seg'
    if (content.startsWith('copia de seg')) {
      return true;
    }
  }
  
  return false;
}

  // Método privado modificado para mostrar notificación local solo si es nueva y no filtrada
  void _showLocalNotificationIfNew(Map<String, dynamic> notificationData, String notificationId) async {
    // Verificar si la notificación debe ser filtrada
    if (_shouldFilterNotification(notificationData)) {
      print('Notificación filtrada en receptor: $notificationId');
      return;
    }
    
    // Solo mostrar si la notificación no ha sido visualizada Y es nueva (no existía al inicializar)
    if (notificationData['status-visualizacion'] == false) {
      final prefs = await SharedPreferences.getInstance();
      final existingIds = prefs.getStringList('existing_notification_ids') ?? [];
      
      // Solo mostrar si es una notificación nueva (no estaba en la lista inicial)
      if (!existingIds.contains(notificationId)) {
        // Extraer el contenido dinámico de la notificación
        String title = 'Nueva notificación';
        String body = 'Contenido no disponible';
        
        // Intentar obtener título de diferentes campos posibles
        if (notificationData['title'] != null && notificationData['title'].toString().isNotEmpty) {
          title = notificationData['title'].toString();
        } else if (notificationData['titulo'] != null && notificationData['titulo'].toString().isNotEmpty) {
          title = notificationData['titulo'].toString();
        }
        
        // Intentar obtener contenido de diferentes campos posibles
        if (notificationData['text'] != null && notificationData['text'].toString().isNotEmpty) {
          body = notificationData['text'].toString();
        } else if (notificationData['contenido'] != null && notificationData['contenido'].toString().isNotEmpty) {
          body = notificationData['contenido'].toString();
        } else if (notificationData['body'] != null && notificationData['body'].toString().isNotEmpty) {
          body = notificationData['body'].toString();
        } else if (notificationData['bigText'] != null && notificationData['bigText'].toString().isNotEmpty) {
          body = notificationData['bigText'].toString();
        }
        
        LocalNotificationService.showNotification(
          title: title,
          body: body,
          packageName: notificationData['packageName'] ?? notificationData['paquete'] ?? '',
          appName: notificationData['appName'] ?? notificationData['aplicacion'] ?? 'Aplicación desconocida',
          notificationId: notificationId,
        );
      }
    }
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
