import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:connect/models/floating_ball_config_backup.dart';
import 'package:connect/services/firebase_service.dart';
import 'package:connect/services/floating_ball_service.dart';

/// Respalda y restaura en Firebase TODA la configuración de la bola flotante.
///
/// Toma una "foto" de las claves `floating_ball_*` de SharedPreferences (que
/// incluyen estilo, gestos, apps/herramientas seleccionadas, orden, chats e
/// iconos personalizados) y la guarda por dispositivo en Firestore, en:
///   `dispositivos/{deviceId}/respaldos/bola_flotante`
class FloatingBallBackupService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseService _firebaseService = FirebaseService();

  static const String _devicesCollection = 'dispositivos';
  static const String _backupsCollection = 'respaldos';
  static const String _backupDocId = 'bola_flotante';

  static const String _prefix = FloatingBallService.prefsKeyPrefix;

  DocumentReference<Map<String, dynamic>> _docRef(String deviceId) {
    return _firestore
        .collection(_devicesCollection)
        .doc(deviceId)
        .collection(_backupsCollection)
        .doc(_backupDocId);
  }

  /// Lee todas las claves `floating_ball_*` de SharedPreferences y las codifica
  /// como mapa tipado `clave -> { t, v }`.
  Future<Map<String, dynamic>> exportEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final entries = <String, dynamic>{};
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(_prefix)) continue;
      final encoded = FloatingBallConfigBackup.encodeValue(prefs.get(key));
      if (encoded != null) entries[key] = encoded;
    }
    return entries;
  }

  /// Construye un respaldo a partir de la configuración local actual.
  Future<FloatingBallConfigBackup> buildLocalBackup() async {
    final deviceId = await _firebaseService.getDeviceId();
    final entries = await exportEntries();
    return FloatingBallConfigBackup(
      version: FloatingBallConfigBackup.schemaVersion,
      deviceId: deviceId,
      updatedAt: DateTime.now(),
      entries: entries,
    );
  }

  /// Sube a Firestore el respaldo de la configuración actual y lo devuelve.
  Future<FloatingBallConfigBackup> backupToCloud() async {
    final backup = await buildLocalBackup();
    final data = backup.toMap();
    data['serverUpdatedAt'] = FieldValue.serverTimestamp();
    await _docRef(backup.deviceId).set(data);
    return backup;
  }

  /// Obtiene el último respaldo guardado en la nube (o `null` si no existe).
  Future<FloatingBallConfigBackup?> fetchCloudBackup() async {
    final deviceId = await _firebaseService.getDeviceId();
    final snap = await _docRef(deviceId).get();
    final data = snap.data();
    if (!snap.exists || data == null) return null;
    return FloatingBallConfigBackup.fromMap(data);
  }

  /// Escribe en SharedPreferences las entradas tipadas y reaplica al overlay.
  /// Devuelve la cantidad de claves aplicadas.
  Future<int> applyEntries(Map<String, dynamic> entries) async {
    final prefs = await SharedPreferences.getInstance();
    int applied = 0;
    for (final entry in entries.entries) {
      final key = entry.key;
      if (!key.startsWith(_prefix)) continue;
      final value = entry.value;
      if (value is! Map) continue;
      final type = (value['t'] ?? '').toString();
      final v = value['v'];
      try {
        switch (type) {
          case 'b':
            await prefs.setBool(key, v == true);
            applied++;
            break;
          case 'i':
            await prefs.setInt(key, (v as num).toInt());
            applied++;
            break;
          case 'd':
            await prefs.setDouble(key, (v as num).toDouble());
            applied++;
            break;
          case 's':
            await prefs.setString(key, v.toString());
            applied++;
            break;
          case 'sl':
            final list =
                (v as List?)?.map((e) => e.toString()).toList() ?? <String>[];
            await prefs.setStringList(key, list);
            applied++;
            break;
        }
      } catch (_) {
        // Ignora una clave corrupta sin abortar toda la restauración.
      }
    }
    await FloatingBallService.applyConfigToOverlay();
    return applied;
  }

  /// Restaura la configuración de la bola desde la nube.
  /// Devuelve el nº de claves aplicadas, o `null` si no había respaldo.
  Future<int?> restoreFromCloud() async {
    final backup = await fetchCloudBackup();
    if (backup == null) return null;
    return applyEntries(backup.entries);
  }

  /// Serializa la configuración actual de la bola como JSON legible (indentado).
  /// El JSON tiene el mismo formato que el respaldo en la nube, por lo que
  /// también sirve para reimportar más adelante.
  Future<String> buildConfigJson() async {
    final backup = await buildLocalBackup();
    return const JsonEncoder.withIndent('  ').convert(backup.toMap());
  }

  /// Exporta la configuración a un archivo `.json` en la ubicación que elija el
  /// usuario (selector de almacenamiento del sistema / SAF en Android).
  ///
  /// Devuelve la ruta/URI donde se guardó, o `null` si el usuario cancela.
  Future<String?> exportConfigToFile() async {
    final json = await buildConfigJson();
    final bytes = Uint8List.fromList(utf8.encode(json));
    final ts = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final fileName =
        'bola_estilos_${ts.year}${two(ts.month)}${two(ts.day)}_${two(ts.hour)}${two(ts.minute)}.json';
    return FilePicker.platform.saveFile(
      dialogTitle: 'Guardar configuración de la bola',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: const ['json'],
      bytes: bytes,
    );
  }

  /// Importa un archivo `.json` (con el formato de este respaldo) elegido por el
  /// usuario y aplica su configuración a la bola.
  ///
  /// Devuelve el nº de claves aplicadas, o `null` si el usuario cancela.
  /// Lanza [FormatException] si el archivo no es válido.
  Future<int?> importConfigFromFile() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Selecciona el archivo de configuración (.json)',
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;

    final bytes = result.files.first.bytes;
    if (bytes == null) {
      throw const FormatException('No se pudo leer el archivo seleccionado.');
    }

    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map) {
      throw const FormatException('El archivo no tiene un formato válido.');
    }

    final backup =
        FloatingBallConfigBackup.fromMap(Map<String, dynamic>.from(decoded));
    if (backup.entries.isEmpty) {
      throw const FormatException(
        'El archivo no contiene configuración de la bola flotante.',
      );
    }
    return applyEntries(backup.entries);
  }
}
