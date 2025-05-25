import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connect/services/firebase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReceptorService {
  final FirebaseService _firebaseService = FirebaseService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Clave para almacenar el ID del dispositivo emisor vinculado
  static const String KEY_LINKED_DEVICE_ID = 'linked_device_id';

  // Verificar si un código de vinculación existe en Firestore
  Future<String?> verifyLinkCode(String code) async {
    try {
      // Buscar en todos los documentos de la colección 'dispositivos'
      final QuerySnapshot querySnapshot = await _firestore
          .collection('dispositivos')
          .get();
      
      // Recorrer todos los documentos para encontrar el que coincida con el código
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
      
      // Actualizar el estado de vinculación en Firebase
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
      print('[DEBUG] getLinkedDeviceId: Result = \$id');
      return id;
    } catch (e) {
      print('Error al obtener ID del dispositivo emisor: \$e');
      return null;
    }
  }

  // Método para actualizar el estado de visualización de una notificación
  Future<void> updateNotificationVisualizationStatus(String notificationId, bool visualizado) async {
    try {
      final deviceId = await getLinkedDeviceId();
      if (deviceId == null) {
        print('No hay dispositivo emisor vinculado');
        return;
      }
      final DateTime now = DateTime.now();
      final String dateId = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final docRef = _firestore
          .collection('dispositivos')
          .doc(deviceId)
          .collection('notificaciones')
          .doc(dateId);
      await docRef.set({
        'notificaciones': {
          notificationId: {'status-visualizacion': visualizado}
        }
      }, SetOptions(merge: true));
      print('Estado de visualización actualizado para notificación $notificationId: $visualizado');
    } catch (e) {
      print('Error al actualizar estado de visualización: $e');
    }
  }

  // Nuevo método para filtrar notificaciones no visualizadas
  Stream<List<Map<String, dynamic>>> listenForUnseenNotifications() async* {
    try {
      // Obtener el stream de todas las notificaciones
      final allNotificationsStream = listenForNotifications();
      
      // Filtrar solo las notificaciones con status-visualizacion = false
      yield* allNotificationsStream.map((notifications) {
        return notifications.where((notification) {
          // Verificar si el campo status-visualizacion existe y es false
          return notification['status-visualizacion'] == false;
        }).toList();
      });
    } catch (e) {
      print('Error al filtrar notificaciones no visualizadas: $e');
      yield <Map<String, dynamic>>[];
    }
  }

  // Iniciar escucha de notificaciones desde Firebase
  Stream<List<Map<String, dynamic>>> listenForNotifications() async* {
    try {
      // Obtener el ID del dispositivo emisor vinculado
      final deviceId = await getLinkedDeviceId();
      
      if (deviceId == null) {
        print('No hay dispositivo emisor vinculado');
        yield [];
        return;
      }
      
      final DateTime now = DateTime.now();
      final String dateId = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      
      // Referencia al documento que contiene las notificaciones del día
      final dayDocRef = _firestore
          .collection('dispositivos')
          .doc(deviceId)
          .collection('notificaciones')
          .doc(dateId);
      
      // Escuchar cambios en el documento
      yield* dayDocRef.snapshots().map((snapshot) {
        if (!snapshot.exists || !snapshot.data()!.containsKey('notificaciones')) {
          return <Map<String, dynamic>>[];
        }
        
        final Map<String, dynamic> notificationsMap = 
            snapshot.data()!['notificaciones'] as Map<String, dynamic>;
        
        // Convertir el mapa a una lista de notificaciones
        final List<Map<String, dynamic>> notificationsList = notificationsMap.entries
            .map((entry) {
              final notif = Map<String, dynamic>.from(entry.value as Map);
              // Validar timestamp
              if (notif['timestamp'] is Timestamp) {
                return notif;
              } else {
                print('Notificación con timestamp inválido: $notif');
                return null;
              }
            })
            .where((notif) => notif != null)
            .cast<Map<String, dynamic>>()
            .toList();
        
        // Ordenar por timestamp (más reciente primero)
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
  // Obtener el estado del dispositivo emisor
  Future<Map<String, dynamic>> getDeviceStatus(String deviceId) async {
    try {
      // Verificar si el dispositivo existe
      final deviceDoc = await _firestore.collection('dispositivos').doc(deviceId).get();
      
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