/// Modelo de datos para respaldar/restaurar TODA la configuración de la bola
/// flotante (estilo, gestos, apps seleccionadas, herramientas, orden, chats,
/// etc.) en Firebase.
///
/// Todas esas opciones se guardan en `SharedPreferences` bajo el prefijo
/// [FloatingBallService.prefsKeyPrefix] (`floating_ball_`). Este modelo toma
/// una "foto" tipada de esas claves para poder reconstruirlas exactamente al
/// restaurar, sin depender de cómo Firestore normalice los números.
///
/// Cada entrada se serializa como `{ 't': tipo, 'v': valor }` donde el tipo
/// es uno de:
///   - `'b'`  -> bool
///   - `'i'`  -> int
///   - `'d'`  -> double
///   - `'s'`  -> String
///   - `'sl'` -> `List<String>`
class FloatingBallConfigBackup {
  /// Versión del esquema del respaldo. Subir si cambia el formato de [entries].
  static const int schemaVersion = 1;

  /// Versión del esquema con el que se generó este respaldo.
  final int version;

  /// Id del dispositivo que generó el respaldo (`FirebaseService.getDeviceId`).
  final String deviceId;

  /// Momento en que se generó el respaldo.
  final DateTime updatedAt;

  /// Mapa `clave -> { 't': tipo, 'v': valor }` con todas las claves
  /// `floating_ball_*` capturadas.
  final Map<String, dynamic> entries;

  const FloatingBallConfigBackup({
    required this.version,
    required this.deviceId,
    required this.updatedAt,
    required this.entries,
  });

  int get entryCount => entries.length;

  Map<String, dynamic> toMap() => {
        'version': version,
        'deviceId': deviceId,
        'updatedAt': updatedAt.toIso8601String(),
        'entryCount': entries.length,
        'entries': entries,
      };

  factory FloatingBallConfigBackup.fromMap(Map<String, dynamic> map) {
    final rawEntries = map['entries'];
    final entries = <String, dynamic>{};
    if (rawEntries is Map) {
      rawEntries.forEach((k, v) => entries[k.toString()] = v);
    }
    return FloatingBallConfigBackup(
      version: (map['version'] as num?)?.toInt() ?? schemaVersion,
      deviceId: (map['deviceId'] ?? '').toString(),
      updatedAt: DateTime.tryParse((map['updatedAt'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      entries: entries,
    );
  }

  /// Codifica un valor tipado de SharedPreferences a `{ 't', 'v' }`.
  /// Devuelve `null` para tipos no soportados (se omiten del respaldo).
  static Map<String, dynamic>? encodeValue(Object? value) {
    if (value is bool) return {'t': 'b', 'v': value};
    if (value is int) return {'t': 'i', 'v': value};
    if (value is double) return {'t': 'd', 'v': value};
    if (value is String) return {'t': 's', 'v': value};
    if (value is List<String>) return {'t': 'sl', 'v': value};
    if (value is List) {
      return {'t': 'sl', 'v': value.map((e) => e.toString()).toList()};
    }
    return null;
  }
}
