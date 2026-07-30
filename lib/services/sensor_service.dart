import 'dart:async';
import 'package:flutter/services.dart';

/// Datos de frecuencia cardíaca recibidos del sensor HR del receptor.
class HrData {
  final int bpm;
  final int confidence;
  final int timestamp;

  const HrData({required this.bpm, required this.confidence, required this.timestamp});

  factory HrData.fromMap(Map<dynamic, dynamic> map) => HrData(
        bpm: (map['bpm'] as num?)?.toInt() ?? 0,
        confidence: (map['confidence'] as num?)?.toInt() ?? 0,
        timestamp: (map['timestamp'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      );

  /// Zona de entrenamiento según % de FCmáx.
  static String zona(int bpm, int fcMax) {
    final pct = fcMax > 0 ? bpm / fcMax : 0.0;
    if (pct < 0.50) return 'reposo';
    if (pct < 0.60) return 'fat_burn';
    if (pct < 0.70) return 'cardio';
    if (pct < 0.80) return 'aerobico';
    return 'peak';
  }

  /// Nombre legible de la zona.
  static String zonaLabel(String zona) => const {
        'reposo':   'Reposo',
        'fat_burn': 'Fat-burn',
        'cardio':   'Cardio',
        'aerobico': 'Aeróbico',
        'peak':     'Peak',
      }[zona] ?? zona;

  /// Color de la zona (índice de Material swatch).
  static int zonaColor(String zona) => const {
        'reposo':   0xFF42A5F5, // azul
        'fat_burn': 0xFF66BB6A, // verde
        'cardio':   0xFFFFCA28, // amarillo
        'aerobico': 0xFFFFA726, // naranja
        'peak':     0xFFEF5350, // rojo
      }[zona] ?? 0xFF9E9E9E;
}

/// Datos de pasos recibidos del pedómetro software del receptor.
class StepsData {
  final int steps;
  final int distanciaM;
  final int timestamp;

  const StepsData({required this.steps, required this.distanciaM, required this.timestamp});

  factory StepsData.fromMap(Map<dynamic, dynamic> map) => StepsData(
        steps: (map['steps'] as num?)?.toInt() ?? 0,
        distanciaM: (map['distancia_m'] as num?)?.toInt() ?? 0,
        timestamp: (map['timestamp'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      );
}

/// Servicio que abstrae todos los canales de sensores corporales del receptor.
/// Fuente de datos tanto para [ReceptorSaludScreen] como para [EmisorSaludScreen]
/// (el emisor recibe los mismos datos via BT, parseados en BtClassicServerService).
class SensorService {
  SensorService._();

  static const _chHr     = EventChannel('connect/heart_rate');
  static const _chSteps  = EventChannel('connect/steps');
  static const _chDebug  = EventChannel('connect/sensor_debug');
  static const _chRotary = MethodChannel('connect/rotary');
  static const _chSvc    = MethodChannel('connect/sensor_service');

  // ── Streams públicos ──────────────────────────────────────────────────────

  static Stream<HrData> get heartRateStream =>
      _chHr.receiveBroadcastStream().map((e) => HrData.fromMap(e as Map));

  static Stream<StepsData> get stepsStream =>
      _chSteps.receiveBroadcastStream().map((e) => StepsData.fromMap(e as Map));

  // ── Debug logs ────────────────────────────────────────────────────────────

  static final List<Map<String, dynamic>> _debugBuffer = [];
  static List<Map<String, dynamic>> get debugLogBuffer => List.unmodifiable(_debugBuffer);

  static final StreamController<Map<String, dynamic>> _debugCtrl =
      StreamController<Map<String, dynamic>>.broadcast();
  static Stream<Map<String, dynamic>> get debugLogStream => _debugCtrl.stream;

  static StreamSubscription<dynamic>? _debugSub;

  static void initDebugStream() {
    _debugSub?.cancel();
    _debugSub = _chDebug.receiveBroadcastStream().listen((event) {
      final map = Map<String, dynamic>.from(event as Map);
      if (_debugBuffer.length >= 500) _debugBuffer.removeAt(0);
      _debugBuffer.add(map);
      _debugCtrl.add(map);
    });
  }

  static void addDebugLog(String source, String message) {
    final entry = {
      'source': source,
      'message': message,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    print('[sensor][$source] $message');
    if (_debugBuffer.length >= 500) _debugBuffer.removeAt(0);
    _debugBuffer.add(entry);
    _debugCtrl.add(entry);
  }

  // ── Control del servicio nativo ───────────────────────────────────────────

  static Future<void> startService() async {
    try {
      await _chSvc.invokeMethod('start');
      addDebugLog('service', 'SensorForegroundService iniciado desde Flutter');
    } catch (e) {
      addDebugLog('service', 'error al iniciar: $e');
    }
  }

  static Future<void> stopService() async {
    try {
      await _chSvc.invokeMethod('stop');
      addDebugLog('service', 'SensorForegroundService detenido desde Flutter');
    } catch (e) {
      addDebugLog('service', 'error al detener: $e');
    }
  }

  // ── Control de la corona giratoria ───────────────────────────────────────

  static Future<void> startRotary() async {
    try {
      await _chRotary.invokeMethod('start');
      addDebugLog('rotary', 'escucha de corona iniciada');
    } catch (e) {
      addDebugLog('rotary', 'error: $e');
    }
  }

  static Future<void> stopRotary() async {
    try {
      await _chRotary.invokeMethod('stop');
      addDebugLog('rotary', 'escucha de corona detenida');
    } catch (e) {
      addDebugLog('rotary', 'error al detener: $e');
    }
  }

  // ── Estimación de calorías (Keytel et al.) ────────────────────────────────

  /// Retorna kcal/min según HR, datos del usuario y tiempo transcurrido en minutos.
  static double calcKcalPerMin({
    required int bpm,
    required double pesoKg,
    required int edad,
    required bool esMasculino,
  }) {
    if (bpm <= 0 || pesoKg <= 0 || edad <= 0) return 0.0;
    final hr = bpm.toDouble();
    if (esMasculino) {
      return (-55.0969 + 0.6309 * hr + 0.1988 * pesoKg + 0.2017 * edad) / 4.184;
    } else {
      return (-20.4022 + 0.4472 * hr - 0.1263 * pesoKg + 0.074 * edad) / 4.184;
    }
  }
}
