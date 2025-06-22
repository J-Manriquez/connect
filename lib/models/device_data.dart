import 'package:cloud_firestore/cloud_firestore.dart';

class DeviceData {
  final String id;
  final bool statusServicio;
  final bool statusVinculacion;
  final bool statusGuardado;
  final bool buscarEmisor; // ✅ NUEVO CAMPO
  final bool buscarReceptor; // ✅ NUEVO CAMPO
  final List<ActualizacionData> ultimaActualizacion;
  final List<AppData> listaApps;
  final String? idVinculado; // ✅ NUEVO CAMPO

  DeviceData({
    required this.id,
    required this.statusServicio,
    this.statusVinculacion = false,
    this.statusGuardado = false,
    this.buscarEmisor = false, // ✅ VALOR POR DEFECTO
    this.buscarReceptor = false, // ✅ VALOR POR DEFECTO
    required this.ultimaActualizacion,
    required this.listaApps,
    this.idVinculado, // ✅ NUEVO CAMPO    
  });

  factory DeviceData.fromMap(Map<String, dynamic> map) {
    return DeviceData(
      id: map['id'] ?? '',
      statusServicio: map['status-servicio'] ?? false,
      statusVinculacion: map['status-vinculacion'] ?? false,
      statusGuardado: map['status-guardado'] ?? false,
      buscarEmisor: map['buscar-emisor'] ?? false, // ✅ NUEVO CAMPO
      buscarReceptor: map['buscar-receptor'] ?? false, // ✅ NUEVO CAMPO
      ultimaActualizacion: List<ActualizacionData>.from(
        (map['ultima-actualizacion'] as List? ?? []).map(
          (x) => ActualizacionData.fromMap(x),
        ),
      ),
      listaApps: List<AppData>.from(
        (map['lista-apps'] as List? ?? []).map(
          (x) => AppData.fromMap(x),
        ),
      ),
      idVinculado: map['id-vinculado']?? '', // ✅ NUEVO CAMPO
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'status-servicio': statusServicio,
      'status-vinculacion': statusVinculacion,
      'status-guardado': statusGuardado,
      'buscar-emisor': buscarEmisor, // ✅ NUEVO CAMPO
      'buscar-receptor': buscarReceptor, // ✅ NUEVO CAMPO
      'ultima-actualizacion': ultimaActualizacion.map((x) => x.toMap()).toList(),
      'lista-apps': listaApps.map((x) => x.toMap()).toList(),
      'id-vinculado': idVinculado, // ✅ NUEVO CAMPO
    };
  }
}

class ActualizacionData {
  final DateTime fecha;
  final String tipoActualizacion;

  ActualizacionData({
    required this.fecha,
    required this.tipoActualizacion,
  });

  factory ActualizacionData.fromMap(Map<String, dynamic> map) {
    return ActualizacionData(
      fecha: (map['fecha'] as Timestamp).toDate(),
      tipoActualizacion: map['tipo-actualizacion'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fecha': Timestamp.fromDate(fecha),
      'tipo-actualizacion': tipoActualizacion,
    };
  }
}

class AppData {
  final String nombre;
  final String packageName;
  final bool activa;

  AppData({
    required this.nombre,
    required this.packageName,
    required this.activa,
  });

  factory AppData.fromMap(Map<String, dynamic> map) {
    return AppData(
      nombre: map['nombre'] ?? '',
      packageName: map['package'] ?? '',
      activa: map['activa'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'package': packageName,
      'activa': activa,
    };
  }
}