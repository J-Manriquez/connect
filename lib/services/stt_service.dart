import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Servicio singleton que envuelve [SpeechToText] con:
/// - Inicialización lazy con caché de disponibilidad.
/// - Configuración de locale en español por defecto.
/// - Callbacks tipados para resultado, error y estado.
class SttService {
  SttService._();
  static final SttService instance = SttService._();

  final SpeechToText _stt = SpeechToText();
  bool? _available;

  /// Handler de error de la escucha activa (se usa para el fallback offline→online).
  Future<void> Function(String msg, bool permanent)? _activeErrorHandler;

  bool get isListening => _stt.isListening;

  /// Inicializa el engine STT y cachea si está disponible.
  Future<bool> initialize() async {
    if (_available != null) return _available!;
    try {
      _available = await _stt.initialize(
        onError: (e) {
          debugPrint('[STT] initError: ${e.errorMsg} permanent=${e.permanent}');
          _activeErrorHandler?.call(e.errorMsg, e.permanent);
        },
        onStatus: (s) => debugPrint('[STT] status: $s'),
      );
    } catch (e) {
      debugPrint('[STT] initialize exception: $e');
      _available = false;
    }
    debugPrint('[STT] available=$_available');
    return _available!;
  }

  /// Inicia la escucha con locale español.
  ///
  /// [onResult] se invoca con el texto parcial/final conforme llegan resultados.
  /// [onDone] se invoca al finalizar (usuario detuvo o silencio detectado).
  /// [onError] se invoca si ocurre un error.
  /// Inicia la escucha.
  ///
  /// [preferOffline] intenta primero reconocimiento **en el dispositivo**
  /// (`onDevice: true`, sin internet). Requiere que el idioma tenga el modelo
  /// offline instalado en el sistema.
  /// [allowOnlineFallback]: si el intento offline falla, reintenta automáticamente
  /// con reconocimiento online (`onDevice: false`, requiere internet).
  Future<bool> listen({
    required void Function(String text, bool isFinal) onResult,
    required void Function() onDone,
    required void Function(String errorMsg) onError,
    Duration listenFor = const Duration(seconds: 30),
    String localeId = 'es',
    bool preferOffline = true,
    bool allowOnlineFallback = true,
  }) async {
    final ok = await initialize();
    if (!ok) {
      debugPrint('[STT] listen() abortado — engine no disponible');
      onError('STT no disponible en este dispositivo');
      return false;
    }
    if (_stt.isListening) {
      debugPrint('[STT] listen() — ya estaba escuchando, parando primero');
      await _stt.stop();
    }

    bool usedOnDevice = preferOffline;
    bool retried = false;

    Future<void> doListen(bool onDevice) async {
      debugPrint('[STT] listen() locale=$localeId onDevice=$onDevice');
      await _stt.listen(
        onResult: (SpeechRecognitionResult result) {
          debugPrint('[STT] result: "${result.recognizedWords}" final=${result.finalResult}');
          onResult(result.recognizedWords, result.finalResult);
        },
        onSoundLevelChange: (level) {},
        listenOptions: SpeechListenOptions(
          cancelOnError: true,
          partialResults: true,
          listenFor: listenFor,
          pauseFor: const Duration(seconds: 3),
          localeId: localeId,
          onDevice: onDevice,
        ),
      );
    }

    // Fallback offline→online: si el modo en-dispositivo falla, reintenta online.
    _activeErrorHandler = (msg, permanent) async {
      if (allowOnlineFallback && usedOnDevice && !retried) {
        retried = true;
        usedOnDevice = false;
        debugPrint('[STT] fallback a online (onDevice=false) tras error: $msg');
        try {
          await _stt.cancel();
        } catch (_) {}
        try {
          await doListen(false);
          return;
        } catch (e) {
          debugPrint('[STT] fallback online falló: $e');
        }
      }
      onError(msg);
    };

    // SpeechToText llama onResult con finalResult=true cuando termina.
    // No hay un onDone nativo, así que usamos onStatus para detectar "done".
    _stt.statusListener = (status) {
      debugPrint('[STT] statusListener: $status');
      if (status == SpeechToText.doneStatus || status == SpeechToText.notListeningStatus) {
        onDone();
      }
    };

    try {
      await doListen(usedOnDevice);
      return true;
    } catch (e) {
      debugPrint('[STT] listen() exception: $e');
      if (allowOnlineFallback && usedOnDevice && !retried) {
        retried = true;
        usedOnDevice = false;
        debugPrint('[STT] fallback a online tras excepción: $e');
        try {
          await doListen(false);
          return true;
        } catch (e2) {
          debugPrint('[STT] fallback online falló: $e2');
        }
      }
      onError(e.toString());
      return false;
    }
  }

  /// Detiene la escucha activa.
  Future<void> stop() async {
    debugPrint('[STT] stop()');
    _activeErrorHandler = null;
    if (_stt.isListening) await _stt.stop();
  }

  /// Cancela sin procesar resultado.
  Future<void> cancel() async {
    debugPrint('[STT] cancel()');
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
