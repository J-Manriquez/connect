import 'package:cloud_firestore/cloud_firestore.dart';

class DeviceData {
  final String id;
  final bool statusServicio;
  final bool statusVinculacion;
  final bool statusGuardado;
  final List<ActualizacionData> ultimaActualizacion;
  final List<AppData> listaApps;

  DeviceData({
    required this.id,
    required this.statusServicio,
    this.statusVinculacion = false,
    this.statusGuardado = false,
    required this.ultimaActualizacion,
    required this.listaApps,
  });

  factory DeviceData.fromMap(Map<String, dynamic> map) {
    return DeviceData(
      id: map['id'] ?? '',
      statusServicio: map['status-servicio'] ?? false,
      statusVinculacion: map['status-vinculacion'] ?? false,
      statusGuardado: map['status-guardado'] ?? false,
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
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'status-servicio': statusServicio,
      'status-vinculacion': statusVinculacion,
      'status-guardado': statusGuardado,
      'ultima-actualizacion': ultimaActualizacion.map((x) => x.toMap()).toList(),
      'lista-apps': listaApps.map((x) => x.toMap()).toList(),
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