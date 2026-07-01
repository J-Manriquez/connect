import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum StopwatchMode { stopwatch, timer }
enum StopwatchStateEnum { idle, running, paused, finished }

class LapEntry {
  final int number;
  final Duration totalElapsed;
  final Duration delta;
  const LapEntry({required this.number, required this.totalElapsed, required this.delta});
}

class StopwatchSnapshot {
  final StopwatchMode mode;
  final StopwatchStateEnum state;
  final Duration elapsed;
  final Duration remaining;
  final Duration timerTarget;
  final List<LapEntry> laps;

  const StopwatchSnapshot({
    required this.mode,
    required this.state,
    required this.elapsed,
    required this.remaining,
    required this.timerTarget,
    required this.laps,
  });

  Duration get currentLapElapsed {
    if (laps.isEmpty) return elapsed;
    return elapsed - laps.last.totalElapsed;
  }

  static const StopwatchSnapshot initial = StopwatchSnapshot(
    mode: StopwatchMode.stopwatch,
    state: StopwatchStateEnum.idle,
    elapsed: Duration.zero,
    remaining: Duration(minutes: 5),
    timerTarget: Duration(minutes: 5),
    laps: [],
  );
}

// ── Servicio principal ─────────────────────────────────────────────────────────────────

class StopwatchTimerService {
  static const _channel = MethodChannel('com.example.connect/stopwatch');

  // SharedPreferences keys (sin prefijo; el puente lo añade)
  static const _kMode     = 'stopwatch_mode';
  static const _kState    = 'stopwatch_state';
  static const _kStart    = 'stopwatch_start_epoch';
  static const _kAccum    = 'stopwatch_accumulated';
  static const _kLaps     = 'stopwatch_laps_json';
  static const _kTimerTgt = 'stopwatch_timer_target';
  static const _kTimerRem = 'stopwatch_timer_remaining';

  // Config de audio/vibración
  static const _kSndEnabled  = 'stopwatch_sound_enabled';
  static const _kSndUri      = 'stopwatch_sound_uri';
  static const _kVibEnabled  = 'stopwatch_vibration_enabled';
  static const _kVibPattern  = 'stopwatch_vibration_pattern';
  static const _kLapVib      = 'stopwatch_lap_vibrate';
  static const _kLapSnd      = 'stopwatch_lap_sound';
  static const _kLapSndUri   = 'stopwatch_lap_sound_uri';

  // Stream para la UI
  static final _controller = StreamController<StopwatchSnapshot>.broadcast();
  static Stream<StopwatchSnapshot> get stateStream => _controller.stream;

  static Timer? _ticker;
  static StopwatchSnapshot _last = StopwatchSnapshot.initial;
  static StopwatchSnapshot get current => _last;

  // ── Acciones ────────────────────────────────────────────────────────────────────────

  static Future<void> start() async {
    await _send('start');
    await _refreshAndStartTicker();
  }

  static Future<void> pause() async {
    await _send('pause');
    _stopTicker();
    await _refresh();
  }

  static Future<void> reset() async {
    await _send('reset');
    _stopTicker();
    await _refresh();
  }

  static Future<void> lap() async {
    await _send('lap');
    await _refresh();
  }

  static Future<void> setTimer(Duration duration) async {
    await _channel.invokeMethod('set_timer', {'duration_ms': duration.inMilliseconds});
    _stopTicker();
    await _refresh();
  }

  static Future<void> setMode(StopwatchMode mode) async {
    await _channel.invokeMethod('set_mode', {'mode': mode == StopwatchMode.timer ? 'timer' : 'stopwatch'});
    _stopTicker();
    await _refresh();
  }

  // ── Configuración sonido/vibración ──────────────────────────────────────────────────

  static Future<void> setSoundEnabled(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kSndEnabled, v);
  }

  static Future<void> setSoundUri(String uri) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kSndUri, uri);
  }

  static Future<void> setVibrationEnabled(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kVibEnabled, v);
  }

  static Future<void> setVibrationPattern(String patternJson) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kVibPattern, patternJson);
  }

  static Future<void> setLapVibrate(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kLapVib, v);
  }

  static Future<void> setLapSound(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kLapSnd, v);
  }

  static Future<void> setLapSoundUri(String uri) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kLapSndUri, uri);
  }

  // Lectura de config de audio/vibración
  static Future<Map<String, dynamic>> getAudioConfig() async {
    final p = await SharedPreferences.getInstance();
    return {
      'soundEnabled':    p.getBool(_kSndEnabled)  ?? true,
      'soundUri':        p.getString(_kSndUri)    ?? '',
      'vibrationEnabled': p.getBool(_kVibEnabled) ?? true,
      'vibrationPattern': p.getString(_kVibPattern) ?? '',
      'lapVibrate':      p.getBool(_kLapVib)      ?? false,
      'lapSound':        p.getBool(_kLapSnd)       ?? false,
      'lapSoundUri':     p.getString(_kLapSndUri)  ?? '',
    };
  }

  // ── Lectura de estado desde SharedPreferences ────────────────────────────────────────

  static Future<StopwatchSnapshot> getState() async {
    final p = await SharedPreferences.getInstance();
    return _readSnapshot(p);
  }

  static StopwatchSnapshot _readSnapshot(SharedPreferences p) {
    final modeStr  = p.getString(_kMode)  ?? 'stopwatch';
    final stateStr = p.getString(_kState) ?? 'idle';
    final start    = p.getInt(_kStart)    ?? 0;
    final accum    = p.getInt(_kAccum)    ?? 0;
    final tgtMs    = p.getInt(_kTimerTgt) ?? 5 * 60000;
    final remMs    = p.getInt(_kTimerRem) ?? tgtMs;

    final mode  = modeStr == 'timer' ? StopwatchMode.timer : StopwatchMode.stopwatch;
    final state = _parseState(stateStr);

    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsed = state == StopwatchStateEnum.running && mode == StopwatchMode.stopwatch
        ? Duration(milliseconds: accum + (now - start))
        : Duration(milliseconds: accum);

    final remaining = state == StopwatchStateEnum.running && mode == StopwatchMode.timer
        ? Duration(milliseconds: (tgtMs - (now - start)).clamp(0, tgtMs))
        : Duration(milliseconds: remMs);

    final lapsJson = p.getString(_kLaps) ?? '[]';
    final laps = _parseLaps(lapsJson);

    return StopwatchSnapshot(
      mode: mode,
      state: state,
      elapsed: elapsed,
      remaining: remaining,
      timerTarget: Duration(milliseconds: tgtMs),
      laps: laps,
    );
  }

  static StopwatchStateEnum _parseState(String s) {
    switch (s) {
      case 'running':  return StopwatchStateEnum.running;
      case 'paused':   return StopwatchStateEnum.paused;
      case 'finished': return StopwatchStateEnum.finished;
      default:         return StopwatchStateEnum.idle;
    }
  }

  static List<LapEntry> _parseLaps(String json) {
    try {
      final list = jsonDecode(json) as List<dynamic>;
      return list.map((e) => LapEntry(
        number: (e['number'] as int?) ?? 0,
        totalElapsed: Duration(milliseconds: (e['elapsed'] as int?) ?? 0),
        delta: Duration(milliseconds: (e['delta'] as int?) ?? 0),
      )).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Ticker interno de Flutter ────────────────────────────────────────────────────────

  static Future<void> _refreshAndStartTicker() async {
    await _refresh();
    _stopTicker();
    _ticker = Timer.periodic(const Duration(milliseconds: 80), (_) async {
      final p = await SharedPreferences.getInstance();
      final snap = _readSnapshot(p);
      _last = snap;
      _controller.add(snap);
      if (snap.state != StopwatchStateEnum.running) {
        _stopTicker();
      }
    });
  }

  static void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  static Future<void> _refresh() async {
    final snap = await getState();
    _last = snap;
    _controller.add(snap);
    if (snap.state == StopwatchStateEnum.running) {
      if (_ticker == null) await _refreshAndStartTicker();
    }
  }

  static Future<void> _send(String method) async {
    try {
      await _channel.invokeMethod(method);
    } catch (_) {}
  }

  // Inicializar: leer estado actual y arrancar ticker si estaba corriendo
  static Future<void> init() async {
    final snap = await getState();
    _last = snap;
    _controller.add(snap);
    if (snap.state == StopwatchStateEnum.running) {
      await _refreshAndStartTicker();
    }
  }

  static void dispose() {
    _stopTicker();
  }
}

// ── Helpers de formato ────────────────────────────────────────────────────────────────

String formatStopwatchTime(Duration d, {bool showMs = true, String format = 'hms'}) {
  final total = d.inMilliseconds.clamp(0, double.infinity.toInt());
  final h   = total ~/ 3600000;
  final m   = (total % 3600000) ~/ 60000;
  final s   = (total % 60000)   ~/ 1000;
  final ms  = total % 1000;

  if (format == 's_ms') {
    final totalS = total ~/ 1000;
    return '${totalS.toString().padLeft(2, '0')}.${ms.toString().padLeft(3, '0')}';
  }
  if (!showMs) {
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  if (h > 0) {
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}.${ms.toString().padLeft(3, '0')}';
  }
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}.${ms.toString().padLeft(3, '0')}';
}
