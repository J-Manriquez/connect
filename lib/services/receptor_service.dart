import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connect/services/firebase_service.dart';

class ReceptorService {
  final FirebaseService _firebaseService = FirebaseService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Verificar si un código de vinculación existe en Firestore
  Future<String?> verifyLinkCode(String code) async {
    try {
      // Buscar el documento con el ID igual al código ingresado
      final QuerySnapshot querySnapshot = await _firestore
          .collection('dispositivos')
          .where('id', isEqualTo: code)
          .limit(1)
          .get();

      // Si encontramos un documento, devolver su ID
      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.id;
      }
      return null;
    } catch (e) {
      print('Error al verificar código de vinculación: $e');
      return null;
    }
  }

  // Actualizar el estado de vinculación a true
  Future<bool> updateLinkStatus(String deviceId) async {
    try {
      // Actualizar el estado de vinculación en Firebase
      await _firebaseService.updateLinkStatus(true);
      print('Estado de vinculación actualizado a true para el dispositivo: $deviceId');
      return true;
    } catch (e) {
      print('Error al actualizar estado de vinculación: $e');
      return false;
    }
  }

  // Iniciar escucha de notificaciones desde Firebase
  Stream<List<Map<String, dynamic>>> listenForNotifications() async* {
    try {
      final deviceId = await _firebaseService.getDeviceId();
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
        'isServiceRunning': data['service-running'] ?? false,
        'isLinked': data['status-vinculacion'] ?? false,
      };
    } catch (e) {
      throw Exception('Error al obtener estado del dispositivo: $e');
    }
  }

  // Obtener las notificaciones del dispositivo emisor
  Future<List<Map<String, dynamic>>> getNotifications(String deviceId) async {
    try {
      // Obtener la colección de notificaciones del dispositivo
      final notificationsSnapshot = await _firestore
          .collection('dispositivos')
          .doc(deviceId)
          .collection('notificaciones')
          .orderBy('timestamp', descending: true)
          .get();
      
      // Convertir los documentos a una lista de mapas
      return notificationsSnapshot.docs
          .map((doc) => doc.data())
          .toList();
    } catch (e) {
      throw Exception('Error al obtener notificaciones: $e');
    }
  }
}