import 'dart:async';

import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'ble_service.dart';

/// Servicio singleton que envuelve [SpeechToText] con:
/// - Inicialización lazy con caché de disponibilidad.
/// - Configuración de locale en español por defecto.
/// - Callbacks tipados para resultado, error y estado.
///
/// Solo usa reconocimiento **online** (`onDevice: false`). El modo offline
/// (`onDevice: true`) se quitó: en dispositivos sin el modelo de idioma
/// instalado localmente, el engine fallaba casi instantáneamente y el
/// reintento automático a online disparaba una SEGUNDA llamada nativa a
/// `listen()` — cada llamada nativa reproduce el sonido de "inicio de
/// escucha" del sistema, así que el síntoma era exactamente "sonido dos
/// veces al inicio y no graba nada" (el primer intento offline fallaba sin
/// grabar, y a veces el segundo intento online tampoco alcanzaba a iniciar
/// bien por la carrera entre cancel()/listen()).
class SttService {
  SttService._();
  static final SttService instance = SttService._();

  final SpeechToText _stt = SpeechToText();
  bool? _available;

  /// Callback de error de la escucha activa (no hay fallback: se reporta
  /// directo a quien llamó `listen()`).
  void Function(String msg, bool permanent)? _activeErrorHandler;

  bool get isListening => _stt.isListening;

  /// Print simple (no `debugPrint`, para que no se trunque/throttle) que
  /// además reenvía al emisor por BT con la llamada nativa directa (ver
  /// BleService.sendDebugLogToPeers) — el mismo mecanismo confiable que usa
  /// `media_state`, sin Intent/startForegroundService.
  void _log(String message) {
    print('[STT] $message');
    try {
      unawaited(BleService.sendDebugLogToPeers('stt_service', message));
    } catch (_) {}
  }

  /// Inicializa el engine STT y cachea si está disponible.
  Future<bool> initialize() async {
    if (_available != null) return _available!;
    try {
      _available = await _stt.initialize(
        onError: (e) {
          _log('initError: ${e.errorMsg} permanent=${e.permanent}');
          _activeErrorHandler?.call(e.errorMsg, e.permanent);
        },
        onStatus: (s) => _log('status: $s'),
      );
    } catch (e) {
      _log('initialize exception: $e');
      _available = false;
    }
    _log('available=$_available');
    return _available!;
  }

  /// Inicia la escucha con locale español, siempre **online**.
  ///
  /// [onResult] se invoca con el texto parcial/final conforme llegan resultados.
  /// [onListening] se invoca cuando el motor confirma que está escuchando.
  /// [onDone] se invoca al finalizar (usuario detuvo o silencio detectado).
  /// [onError] se invoca si ocurre un error.
  Future<bool> listen({
    required void Function(String text, bool isFinal) onResult,
    required void Function() onDone,
    required void Function(String errorMsg) onError,
    void Function()? onListening,
    Duration listenFor = const Duration(seconds: 30),
    String localeId = 'es',
  }) async {
    final ok = await initialize();
    if (!ok) {
      _log('listen() abortado — engine no disponible');
      onError('STT no disponible en este dispositivo');
      return false;
    }
    if (_stt.isListening) {
      _log('listen() — ya estaba escuchando, parando primero');
      await _stt.stop();
    }

    _activeErrorHandler = (msg, permanent) {
      _log('error recibido: $msg permanent=$permanent');
      onError(msg);
    };

    // SpeechToText llama onResult con finalResult=true cuando termina.
    // No hay un onDone nativo, así que usamos onStatus para detectar "done".
    _stt.statusListener = (status) {
      _log('statusListener: $status');
      if (status == SpeechToText.doneStatus || status == SpeechToText.notListeningStatus) {
        onDone();
      } else if (status == SpeechToText.listeningStatus) {
        onListening?.call();
      }
    };

    try {
      _log('listen() locale=$localeId onDevice=false');
      await _stt.listen(
        onResult: (SpeechRecognitionResult result) {
          _log('result: "${result.recognizedWords}" final=${result.finalResult}');
          onResult(result.recognizedWords, result.finalResult);
        },
        onSoundLevelChange: (level) {},
        listenOptions: SpeechListenOptions(
          cancelOnError: false,
          partialResults: true,
          listenFor: const Duration(minutes: 10),
          pauseFor: const Duration(minutes: 10),
          localeId: localeId,
          onDevice: false,
        ),
      );
      return true;
    } catch (e) {
      _log('listen() exception: $e');
      onError(e.toString());
      return false;
    }
  }

  /// Detiene la escucha activa.
  Future<void> stop() async {
    _log('stop()');
    _activeErrorHandler = null;
    if (_stt.isListening) await _stt.stop();
  }

  /// Cancela sin procesar resultado.
  Future<void> cancel() async {
    _log('cancel()');
    _activeErrorHandler = null;
    if (_stt.isListening) await _stt.cancel();
  }

  /// Lista de locales soportados por el engine (útil para diagnóstico).
  Future<List<LocaleName>> locales() async {
    final ok = await initialize();
    if (!ok) return [];
    return _stt.locales();
  }
}
