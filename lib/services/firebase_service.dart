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
  Future<void> updateLinkStatus(bool isLinked) async {
    final deviceId = await getDeviceId();
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
    
    final List<Map<String, dynamic>> appMaps = apps.map((app) => app.toMap()).toList();
    
    await docRef.update({
      'lista-apps': appMaps,
      'ultima-actualizacion': FieldValue.arrayUnion([
        {
          'fecha': Timestamp.now(),
          'tipo-actualizacion': 'actualización-lista-apps',
        }
      ]),
    });
    
    print('Lista de aplicaciones actualizada');
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
  
  // Obtiene el estado de guardado actual
  Future<bool> getSaveStatus() async {
    final deviceId = await getDeviceId();
    final docRef = _firestore.collection('dispositivos').doc(deviceId);
    
    final docSnapshot = await docRef.get();
    if (docSnapshot.exists) {
      final data = docSnapshot.data();
      return data?['status-guardado'] ?? false;
    }
    
    return false;
  }
  
  // Obtiene la lista de aplicaciones desde Firebase
  Future<List<AppData>> getAppList() async {
    final deviceId = await getDeviceId();
    final docRef = _firestore.collection('dispositivos').doc(deviceId);
    
    final docSnapshot = await docRef.get();
    if (docSnapshot.exists) {
      final data = docSnapshot.data();
      if (data != null && data['lista-apps'] != null) {
        return List<AppData>.from(
          (data['lista-apps'] as List).map(
            (x) => AppData.fromMap(x),
          ),
        );
      }
    }
    
    return [];
  }
}