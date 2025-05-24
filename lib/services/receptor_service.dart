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
      await _firebaseService.updateLinkStatus(true);
      
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
            .map((entry) => Map<String, dynamic>.from(entry.value as Map))
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