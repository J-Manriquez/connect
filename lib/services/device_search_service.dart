import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connect/services/firebase_service.dart';
import 'package:connect/services/preferences_service.dart';
import 'package:connect/services/device_finder_service.dart';
import 'dart:async';

class DeviceSearchService {
  static final DeviceSearchService _instance = DeviceSearchService._internal();
  factory DeviceSearchService() => _instance;
  static DeviceSearchService get instance => _instance;
  DeviceSearchService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseService _firebaseService = FirebaseService();
  StreamSubscription? _searchListenerSubscription;
  bool _isListening = false;

  // Actualizar campo buscarEmisor en Firebase
  Future<void> updateBuscarEmisor(bool value) async {
    try {
      final deviceId = await _firebaseService.getDeviceId();
      await _firestore.collection('dispositivos').doc(deviceId).update({
        'buscar-emisor': value,
      });
      print('Campo buscar-emisor actualizado: $value');
    } catch (e) {
      print('Error al actualizar buscar-emisor: $e');
    }
  }

  // Actualizar campo buscarReceptor en Firebase
  Future<void> updateBuscarReceptor(bool value) async {
    try {
      final deviceId = await _firebaseService.getDeviceId();
      await _firestore.collection('dispositivos').doc(deviceId).update({
        'buscar-receptor': value,
      });
      print('Campo buscar-receptor actualizado: $value');
    } catch (e) {
      print('Error al actualizar buscar-receptor: $e');
    }
  }

  // Iniciar escucha de cambios en los campos de búsqueda
  Future<void> startListeningForSearchChanges() async {
    if (_isListening) return;

    try {
      final deviceId = await _firebaseService.getDeviceId();
      final isUseAsReceptor = await PreferencesService.getUseAsReceptor();
      
      _searchListenerSubscription = _firestore
          .collection('dispositivos')
          .doc(deviceId)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.exists) {
          final data = snapshot.data() as Map<String, dynamic>;
          final buscarEmisor = data['buscar-emisor'] ?? false;
          final buscarReceptor = data['buscar-receptor'] ?? false;
          
          _handleSearchFieldChanges(buscarEmisor, buscarReceptor, isUseAsReceptor);
        }
      });
      
      _isListening = true;
      print('DeviceSearchService: Iniciada escucha de cambios de búsqueda');
    } catch (e) {
      print('Error al iniciar escucha de búsqueda: $e');
    }
  }

  // Manejar cambios en los campos de búsqueda
  void _handleSearchFieldChanges(bool buscarEmisor, bool buscarReceptor, bool isUseAsReceptor) {
    print('Cambio detectado - buscarEmisor: $buscarEmisor, buscarReceptor: $buscarReceptor, isUseAsReceptor: $isUseAsReceptor');
    
    // Si el dispositivo está configurado como emisor y buscarEmisor es true
    if (!isUseAsReceptor && buscarEmisor) {
      print('Activando búsqueda para dispositivo EMISOR');
      DeviceFinderService.instance.startDeviceSearch();
      // Resetear el campo después de activar
      updateBuscarEmisor(false);
    }
    // Si el dispositivo está configurado como receptor y buscarReceptor es true
    else if (isUseAsReceptor && buscarReceptor) {
      print('Activando búsqueda para dispositivo RECEPTOR');
      DeviceFinderService.instance.startDeviceSearch();
      // Resetear el campo después de activar
      updateBuscarReceptor(false);
    }
  }

  // Detener escucha
  void stopListening() {
    if (!_isListening) return;
    
    _searchListenerSubscription?.cancel();
    _searchListenerSubscription = null;
    _isListening = false;
    print('DeviceSearchService: Detenida escucha de cambios de búsqueda');
  }

  // Verificar si está escuchando
  bool get isListening => _isListening;
}