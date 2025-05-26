import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connect/models/device_data.dart';
import 'package:connect/models/notification_data.dart';
import 'dart:math';

class FirebaseService {
  static const String _deviceIdKey = 'device_id';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Método para obtener o generar el ID del dispositivo
  Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString(_deviceIdKey);
    
    if (deviceId == null) {
      // Generar un ID numérico de 6 dígitos
      deviceId = _generateDeviceId();
      await prefs.setString(_deviceIdKey, deviceId);
    }
    
    return deviceId;
  }

  // Elimina una notificación específica de Firebase
  Future<void> deleteNotification(String notificationId, String dateId) async {
    final deviceId = await getDeviceId();
    
    // Referencia al documento que contiene la notificación
    final dayDocRef = _firestore
        .collection('dispositivos')
        .doc(deviceId)
        .collection('notificaciones')
        .doc(dateId);
    
    try {
      // Eliminar la notificación específica usando FieldValue.delete()
      await dayDocRef.update({
        'notificaciones.$notificationId': FieldValue.delete(),
      });
      
      print('Notificación eliminada: $notificationId');
      
      // Verificar si quedan notificaciones en el documento
      final docSnapshot = await dayDocRef.get();
      final data = docSnapshot.data();
      
      if (data != null && data.containsKey('notificaciones')) {
        final Map<String, dynamic> notificationsMap = data['notificaciones'] as Map<String, dynamic>;
        
        // Si no quedan notificaciones, eliminar el documento del día
        if (notificationsMap.isEmpty) {
          await dayDocRef.delete();
          print('Documento del día eliminado: $dateId (sin notificaciones)');
        }
      }
    } catch (e) {
      print('Error al eliminar notificación: $e');
    }
  }

  // Genera un ID numérico de 6 dígitos
  String _generateDeviceId() {
    final random = Random();
    int id = random.nextInt(900000) + 100000; // Asegura que sea de 6 dígitos
    return id.toString();
  }
  
  // Inicializa la estructura de datos en Firebase si no existe
  Future<void> initializeFirebaseData(bool isServiceRunning) async {
    final deviceId = await getDeviceId();
    final docRef = _firestore.collection('dispositivos').doc(deviceId);
    
    // Verificar si el documento ya existe
    final docSnapshot = await docRef.get();
    if (!docSnapshot.exists) {
      // Crear el documento con la estructura inicial
      final DeviceData deviceData = DeviceData(
        id: deviceId,
        statusServicio: isServiceRunning,
        ultimaActualizacion: [
          ActualizacionData(
            fecha: DateTime.now(),
            tipoActualizacion: 'inicialización',
          ),
        ],
        listaApps: [],
      );
      
      await docRef.set(deviceData.toMap());
      print('Documento inicializado en Firebase con ID: $deviceId');
    } else {
      print('El documento ya existe en Firebase con ID: $deviceId');
    }
  }
  
  // Actualiza el estado del servicio
  Future<void> updateServiceStatus(bool isRunning) async {
    final deviceId = await getDeviceId();
    final docRef = _firestore.collection('dispositivos').doc(deviceId);
    
    await docRef.update({
      'status-servicio': isRunning,
      'ultima-actualizacion': FieldValue.arrayUnion([
        {
          'fecha': Timestamp.now(),
          'tipo-actualizacion': 'cambio-estado-servicio',
        }
      ]),
    });
    
    print('Estado del servicio actualizado: $isRunning');
  }
  
  // Actualiza el estado de vinculación
  Future<void> updateLinkStatus(bool isLinked, String deviceId) async {
    // final deviceId = await getDeviceId();
    final docRef = _firestore.collection('dispositivos').doc(deviceId);
    
    await docRef.update({
      'status-vinculacion': isLinked,
      'ultima-actualizacion': FieldValue.arrayUnion([
        {
          'fecha': Timestamp.now(),
          'tipo-actualizacion': 'cambio-estado-vinculacion',
        }
      ]),
    });
    
    print('Estado de vinculación actualizado: $isLinked');
  }
  
  // Actualiza el estado de guardado
  Future<void> updateSaveStatus(bool isSaving) async {
    final deviceId = await getDeviceId();
    final docRef = _firestore.collection('dispositivos').doc(deviceId);
    
    await docRef.update({
      'status-guardado': isSaving,
      'ultima-actualizacion': FieldValue.arrayUnion([
        {
          'fecha': Timestamp.now(),
          'tipo-actualizacion': 'cambio-estado-guardado',
        }
      ]),
    });
    
    print('Estado de guardado actualizado: $isSaving');
  }
  
  // Actualiza la lista de aplicaciones
  Future<void> updateAppList(List<AppData> apps) async {
    final deviceId = await getDeviceId();
    final docRef = _firestore.collection('dispositivos').doc(deviceId);
    
    try {
      // Verificar si el guardado está habilitado
      final docSnapshot = await docRef.get();
      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        final isSaving = data?['status-guardado'] ?? false;
        
        if (!isSaving) {
          print('Guardado en Firebase no está habilitado, omitiendo actualización de apps');
          return;
        }
      }
      
      // Actualizar la lista de aplicaciones
      await docRef.update({
        'lista-apps': apps.map((app) => app.toMap()).toList(),
        'ultima-actualizacion': FieldValue.arrayUnion([
          {
            'fecha': Timestamp.now(),
            'tipo-actualizacion': 'actualizacion-lista-apps',
          }
        ]),
      });
      
      print('Lista de aplicaciones actualizada en Firebase: ${apps.length} apps');
    } catch (e) {
      print('Error al actualizar lista de aplicaciones en Firebase: $e');
      throw e;
    }
  }
  
  // Obtiene la lista de aplicaciones
  Future<List<AppData>> getAppList() async {
    final deviceId = await getDeviceId();
    final docRef = _firestore.collection('dispositivos').doc(deviceId);
    
    try {
      final docSnapshot = await docRef.get();
      if (!docSnapshot.exists) {
        return [];
      }
      
      final data = docSnapshot.data();
      if (data == null || !data.containsKey('lista-apps')) {
        return [];
      }
      
      final List<dynamic> appsList = data['lista-apps'];
      return appsList.map((appData) => AppData.fromMap(appData)).toList();
    } catch (e) {
      print('Error al obtener lista de aplicaciones desde Firebase: $e');
      return [];
    }
  }
  
  // Obtiene el estado de guardado
  Future<bool> getSaveStatus() async {
    final deviceId = await getDeviceId();
    final docRef = _firestore.collection('dispositivos').doc(deviceId);
    
    try {
      final docSnapshot = await docRef.get();
      if (!docSnapshot.exists) {
        return false;
      }
      
      final data = docSnapshot.data();
      return data?['status-guardado'] ?? false;
    } catch (e) {
      print('Error al obtener estado de guardado desde Firebase: $e');
      return false;
    }
  }
  
  // Obtiene el estado de vinculación
  Future<bool> getLinkStatus() async {
    final deviceId = await getDeviceId();
    print('[DEBUG] getLinkStatus: deviceId = \$deviceId');
    final docRef = _firestore.collection('dispositivos').doc(deviceId);
    try {
      final docSnapshot = await docRef.get();
      print('[DEBUG] getLinkStatus: docSnapshot.exists = \${docSnapshot.exists}');
      if (!docSnapshot.exists) {
        return false;
      }
      final data = docSnapshot.data();
      final status = data?['status-vinculacion'] ?? false;
      print('[DEBUG] getLinkStatus: status-vinculacion = \$status');
      return status;
    } catch (e) {
      print('Error al obtener estado de vinculación desde Firebase: \$e');
      return false;
    }
  }
  
  // Guarda una notificación en Firebase
  Future<void> saveNotification(Map<String, dynamic> notification) async {
    final deviceId = await getDeviceId();
    final notificationData = NotificationData.fromNotificationMap(notification);
    
    // Obtener la fecha actual en formato YYYY-MM-DD para usar como ID del documento
    final DateTime now = DateTime.now();
    final String dateId = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    
    // Referencia al documento que agrupa las notificaciones del día
    final dayDocRef = _firestore
        .collection('dispositivos')
        .doc(deviceId)
        .collection('notificaciones')
        .doc(dateId);
    
    // Verificar si necesitamos crear el documento del día
    final dayDoc = await dayDocRef.get();
    if (!dayDoc.exists) {
      await dayDocRef.set({
        'fecha': Timestamp.fromDate(DateTime(now.year, now.month, now.day)),
      });
    }
    
    // Guardar la notificación como un campo en el documento del día
    await dayDocRef.update({
      'notificaciones.${notificationData.id}': notificationData.toMap(),
    });
    
    print('Notificación guardada con ID: ${notificationData.id}');
  }
  
  // Actualiza el estado de visualización de una notificación
  Future<void> updateNotificationVisualizationStatus(String notificationId, String dateId, bool visualizado) async {
    final deviceId = await getDeviceId();
    
    // Referencia al documento que contiene la notificación
    final dayDocRef = _firestore
        .collection('dispositivos')
        .doc(deviceId)
        .collection('notificaciones')
        .doc(dateId);
    
    // Actualizar solo el campo de estado de visualización
    await dayDocRef.update({
      'notificaciones.$notificationId.status-visualizacion': visualizado,
    });
    
    print('Estado de visualización actualizado para notificación $notificationId: $visualizado');
  }
  
  // Obtiene todas las notificaciones almacenadas para el dispositivo
  Future<List<NotificationData>> getStoredNotifications() async {
    final deviceId = await getDeviceId();
    final List<NotificationData> allNotifications = [];
    
    try {
      // Obtener todos los documentos de la colección de notificaciones
      final querySnapshot = await _firestore
          .collection('dispositivos')
          .doc(deviceId)
          .collection('notificaciones')
          .get();
      
      // Iterar sobre cada documento (cada día)
      for (final dayDoc in querySnapshot.docs) {
        final data = dayDoc.data();
        if (data.containsKey('notificaciones')) {
          // Convertir el mapa de notificaciones a una lista de NotificationData
          final Map<String, dynamic> notificationsMap = data['notificaciones'] as Map<String, dynamic>;
          
          notificationsMap.forEach((notificationId, notificationData) {
            try {
              if (notificationData != null && notificationData is Map<String, dynamic>) {
                // Añadir el ID del día al mapa para poder actualizar el estado después
                final Map<String, dynamic> notificationDataMap = Map<String, dynamic>.from(notificationData);
                notificationDataMap['dateId'] = dayDoc.id;
                
                // Verificar que timestamp existe y es un Timestamp
                if (notificationDataMap.containsKey('timestamp') && 
                    notificationDataMap['timestamp'] is Timestamp) {
                  allNotifications.add(NotificationData.fromMap(notificationDataMap));
                } else {
                  // print('Error: timestamp inválido en notificación $notificationId');
                }
              } else {
                print('Error: datos de notificación inválidos para $notificationId');
              }
            } catch (e) {
              print('Error al procesar notificación $notificationId: $e');
              // Continuar con la siguiente notificación
            }
          });
        }
      }
      
      // Ordenar las notificaciones por fecha, más recientes primero
      allNotifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      
      // print('Notificaciones procesadas correctamente: ${allNotifications.length}');
      return allNotifications;
    } catch (e, stackTrace) {
      print('Error al obtener notificaciones almacenadas: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }
}