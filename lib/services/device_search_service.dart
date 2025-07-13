import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connect/services/firebase_service.dart';
import 'package:connect/services/preferences_service.dart';
import 'package:connect/services/device_finder_service.dart';
import 'dart:async';

import 'package:connect/services/receptor_service.dart';

class DeviceSearchService {
  static final DeviceSearchService _instance = DeviceSearchService._internal();
  factory DeviceSearchService() => _instance;
  static DeviceSearchService get instance => _instance;
  DeviceSearchService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseService _firebaseService = FirebaseService();
  final ReceptorService _receptorService = ReceptorService();
  StreamSubscription? _searchListenerSubscription;
  bool _isListening = false;

  // Actualizar campo buscarEmisor en Firebase
  Future<void> updateBuscarEmisor(bool value) async {
    try {
      // ✅ OBTENER EL ID DEL DISPOSITIVO VINCULADO, NO EL PROPIO
      final linkedDeviceId = await _receptorService.getLinkedDeviceId();
      
      if (linkedDeviceId == null || linkedDeviceId.isEmpty) {
        throw Exception('No hay dispositivo vinculado');
      }
      
      await _firestore.collection('dispositivos').doc(linkedDeviceId).update({
        'buscar-receptor': value,
      });
      print('Campo buscar-emisor actualizado en dispositivo vinculado: $linkedDeviceId, valor: $value');
    } catch (e) {
      print('Error al actualizar buscar-emisor: $e');
      rethrow; // ✅ PROPAGAR EL ERROR PARA MOSTRARLO EN LA UI
    }
  }

  // Actualizar campo buscarReceptor en Firebase
  Future<void> updateBuscarReceptor(bool value) async {
    try {
      // ✅ USAR LA NUEVA FUNCIÓN getIdVinculado EN LUGAR DE getLinkedDeviceId
      final linkedDeviceId = await getIdVinculado();
      
      if (linkedDeviceId == null || linkedDeviceId.isEmpty) {
        throw Exception('No hay dispositivo vinculado en el campo idVinculado');
      }
      
      await _firestore.collection('dispositivos').doc(linkedDeviceId).update({
        'buscar-emisor': value,
      });
      print('Campo buscar-receptor actualizado usando idVinculado: $linkedDeviceId, valor: $value');
    } catch (e) {
      print('Error al actualizar buscar-receptor: $e');
      rethrow; // ✅ PROPAGAR EL ERROR PARA MOSTRARLO EN LA UI
    }
  }

  // Iniciar escucha de cambios en los campos de búsqueda
  Future<void> startListeningForSearchChanges() async {
    if (_isListening) return;

    try {
      final deviceId = await _firebaseService.getDeviceId();
      // ❌ ELIMINAR ESTA LÍNEA - no obtener isUseAsReceptor aquí
      // final isUseAsReceptor = await PreferencesService.getUseAsReceptor();
      
      _searchListenerSubscription = _firestore
          .collection('dispositivos')
          .doc(deviceId)
          .snapshots()
          .listen((snapshot) async { // ✅ HACER ASYNC
        if (snapshot.exists) {
          final data = snapshot.data() as Map<String, dynamic>;
          final buscarEmisor = data['buscar-emisor'] ?? false;
          final buscarReceptor = data['buscar-receptor'] ?? false;
          
          // ✅ USAR getDisableAutoRedirect EN LUGAR DE getUseAsReceptor
          final disableAutoRedirect = await PreferencesService.getDisableAutoRedirect();
          
          _handleSearchFieldChanges(buscarEmisor, buscarReceptor, disableAutoRedirect);
        }
      });
      
      _isListening = true;
      print('DeviceSearchService: Iniciada escucha de cambios de búsqueda');
    } catch (e) {
      print('Error al iniciar escucha de búsqueda: $e');
    }
  }

  // ✅ CORREGIR LA LÓGICA DE ROLES
  void _handleSearchFieldChanges(bool buscarEmisor, bool buscarReceptor, bool disableAutoRedirect) {
    print('=== CAMBIO DETECTADO ===');
    print('buscarEmisor: $buscarEmisor');
    print('buscarReceptor: $buscarReceptor');
    print('disableAutoRedirect: $disableAutoRedirect (${disableAutoRedirect ? "RECEPTOR" : "EMISOR"})');
    print('========================');
    
    // Si el dispositivo es EMISOR (disableAutoRedirect = false) y buscarEmisor es true
    if (!disableAutoRedirect && buscarEmisor) {
      print('✅ Activando búsqueda para dispositivo EMISOR');
      DeviceFinderService.instance.startDeviceSearch();
      // ✅ NO resetear inmediatamente, dejar que el DeviceFinderService maneje el auto-reset después de 30s
    }
    // Si el dispositivo es RECEPTOR (disableAutoRedirect = true) y buscarReceptor es true
    else if (disableAutoRedirect && buscarReceptor) {
      print('✅ Activando búsqueda para dispositivo RECEPTOR');
      DeviceFinderService.instance.startDeviceSearch();
      // ✅ NO resetear inmediatamente, dejar que el DeviceFinderService maneje el auto-reset después de 30s
    }
    // Si el campo cambió a false, detener la búsqueda local
    else if ((!disableAutoRedirect && !buscarEmisor && DeviceFinderService.instance.isSearching) ||
             (disableAutoRedirect && !buscarReceptor && DeviceFinderService.instance.isSearching)) {
      print('✅ Deteniendo búsqueda por cambio de campo a false');
      DeviceFinderService.instance.stopDeviceSearch();
    }
    else {
      print('❌ Ninguna condición se cumplió para activar/desactivar búsqueda');
      print('   - Dispositivo es: ${disableAutoRedirect ? "RECEPTOR" : "EMISOR"}');
      print('   - buscarEmisor: $buscarEmisor, buscarReceptor: $buscarReceptor');
      print('   - isSearching: ${DeviceFinderService.instance.isSearching}');
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

  // ✅ NUEVA FUNCIÓN: Obtener el ID del dispositivo vinculado desde el campo idVinculado
  Future<String?> getIdVinculado() async {
    try {
      final deviceId = await _firebaseService.getDeviceId();
      final doc = await _firestore.collection('dispositivos').doc(deviceId).get();
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final idVinculado = data['id-vinculado'] as String?;
        print('[DEBUG] getIdVinculado: deviceId=$deviceId, idVinculado=$idVinculado');
        return idVinculado;
      }
      
      print('[DEBUG] getIdVinculado: Documento no existe para deviceId=$deviceId');
      return null;
    } catch (e) {
      print('Error al obtener idVinculado: $e');
      return null;
    }
  }

  // ✅ Resetear manualmente el campo buscar-emisor
  Future<void> resetBuscarEmisor() async {
    try {
      final linkedDeviceId = await _receptorService.getLinkedDeviceId();
      
      if (linkedDeviceId == null || linkedDeviceId.isEmpty) {
        throw Exception('No hay dispositivo vinculado');
      }
      
      await _firestore.collection('dispositivos').doc(linkedDeviceId).update({
        'buscar-receptor': false,
      });
      print('Campo buscar-emisor reseteado manualmente en dispositivo: $linkedDeviceId');
    } catch (e) {
      print('Error al resetear buscar-emisor: $e');
    }
  }

  // ✅ Resetear manualmente el campo buscar-receptor
  Future<void> resetBuscarReceptor() async {
    try {
      final linkedDeviceId = await getIdVinculado();
      
      if (linkedDeviceId == null || linkedDeviceId.isEmpty) {
        throw Exception('No hay dispositivo vinculado en el campo idVinculado');
      }
      
      await _firestore.collection('dispositivos').doc(linkedDeviceId).update({
        'buscar-emisor': false,
      });
      print('Campo buscar-receptor reseteado manualmente en dispositivo: $linkedDeviceId');
    } catch (e) {
      print('Error al resetear buscar-receptor: $e');
    }
  }
}