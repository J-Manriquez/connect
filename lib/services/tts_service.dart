import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:connect/models/tts_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:piper_tts_plugin/piper_tts_plugin.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TtsService extends ChangeNotifier {
  static const MethodChannel _audioChannel =
      MethodChannel('com.example.connect/tts_audio');

  static const String _configKey = 'tts_config_v2';
  static const String _migrationKey = 'tts_migration_v2_done';

  static const List<_PiperVoice> _catalog = [
    _PiperVoice(
      id: 'es_ES-carlfm-x_low',
      locale: 'es-ES',
      name: 'Carlos (es-ES, x_low)',
      modelUrl:
          'https://huggingface.co/rhasspy/piper-voices/resolve/main/es/es_ES/carlfm/x_low/es_ES-carlfm-x_low.onnx?download=true',
      configUrl:
          'https://huggingface.co/rhasspy/piper-voices/resolve/main/es/es_ES/carlfm/x_low/es_ES-carlfm-x_low.onnx.json?download=true',
    ),
    _PiperVoice(
      id: 'es_ES-sharvard-medium',
      locale: 'es-ES',
      name: 'Sharvard (es-ES, medium)',
      modelUrl:
          'https://huggingface.co/rhasspy/piper-voices/resolve/main/es/es_ES/sharvard/medium/es_ES-sharvard-medium.onnx?download=true',
      configUrl:
          'https://huggingface.co/rhasspy/piper-voices/resolve/main/es/es_ES/sharvard/medium/es_ES-sharvard-medium.onnx.json?download=true',
    ),
    _PiperVoice(
      id: 'en_US-lessac-medium',
      locale: 'en-US',
      name: 'Lessac (en-US, medium)',
      modelUrl:
          'https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/medium/en_US-lessac-medium.onnx?download=true',
      configUrl:
          'https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/medium/en_US-lessac-medium.onnx.json?download=true',
    ),
    _PiperVoice(
      id: 'en_US-hfc_female-medium',
      locale: 'en-US',
      name: 'HFC Female (en-US, medium)',
      modelUrl:
          'https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/hfc_female/medium/en_US-hfc_female-medium.onnx?download=true',
      configUrl:
          'https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/hfc_female/medium/en_US-hfc_female-medium.onnx.json?download=true',
    ),
  ];

  bool isPlaying = false;
  double speechRate = 0.5;
  double pitch = 1.0;
  double volume = 1.0;
  String language = 'es-MX';
  Map<String, String>? selectedVoice;
  VoidCallback? onComplete;

  TtsConfig _config = TtsConfig.defaults();
  final PiperTtsPlugin _piper = PiperTtsPlugin();
  final AudioPlayer _player = AudioPlayer();
  String? _loadedVoiceId;
  Future<void> _ready = Future<void>.value();
  int _playSessionId = 0;
  int? _cachedMusicVolume;
  String? _activeWavPath;
  final Map<String, double> _downloadProgress = {};

  TtsService() {
    _ready = _init();
  }

  TtsConfig get config => _config;

  bool get enabled => _config.enabled;

  int get repeatCount => _config.repeatCount;

  int get repeatDelaySeconds => _config.repeatDelaySeconds;

  double? getDownloadProgress(String voiceId) => _downloadProgress[voiceId];

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    await _migrateLegacyIfNeeded(prefs);
    final raw = prefs.getString(_configKey);
    if (raw != null && raw.isNotEmpty) {
      _config = TtsConfig.fromMap(jsonDecode(raw) as Map<String, dynamic>);
    } else {
      _config = TtsConfig.defaults();
      await _saveConfig();
    }

    _syncPublicFieldsFromConfig();
    await _reloadPiperInstance();
  }

  Future<void> _migrateLegacyIfNeeded(SharedPreferences prefs) async {
    final done = prefs.getBool(_migrationKey) ?? false;
    if (done) return;

    final legacyEnabled = prefs.getBool('enableTts');
    final legacyVolumeNum = prefs.getDouble('ttsVolume') ??
        prefs.getInt('ttsVolume')?.toDouble() ??
        prefs.getDouble('volume');
    final legacyPitch = prefs.getDouble('ttsPitch') ?? prefs.getDouble('pitch');
    final legacyRepeatCount =
        prefs.getInt('ttsRepeatCount') ?? prefs.getInt('repeatCount');
    final legacyRepeatDelay = prefs.getInt('ttsRepeatDelaySeconds') ??
        prefs.getInt('repeatDelaySeconds');
    final legacySpeechRate =
        prefs.getDouble('ttsSpeechRate') ?? prefs.getDouble('speechRate');
    final legacyLanguage = prefs.getString('ttsLanguage') ??
        prefs.getString('language') ??
        'es-MX';
    final legacyVoiceId = prefs.getString('piperVoiceId') ??
        prefs.getString('ttsVoiceId') ??
        prefs.getString('voiceId');

    final defaultConfig = TtsConfig.defaults(localeHint: legacyLanguage);
    final normalizedVolume = () {
      if (legacyVolumeNum == null) return defaultConfig.volumePercent;
      if (legacyVolumeNum <= 1.0) {
        return (legacyVolumeNum * 100).round().clamp(0, 100);
      }
      return legacyVolumeNum.round().clamp(0, 100);
    }();

    final migrated = defaultConfig.copyWith(
      enabled: legacyEnabled ?? defaultConfig.enabled,
      piperVoiceId: legacyVoiceId ?? defaultConfig.piperVoiceId,
      volumePercent: normalizedVolume,
      pitch: (legacyPitch ?? defaultConfig.pitch).clamp(0.5, 2.0),
      repeatCount: legacyRepeatCount ?? defaultConfig.repeatCount,
      repeatDelaySeconds:
          (legacyRepeatDelay ?? defaultConfig.repeatDelaySeconds).clamp(0, 30),
      speechRate:
          (legacySpeechRate ?? defaultConfig.speechRate).clamp(0.1, 1.2),
      localeHint: legacyLanguage,
      provider: TtsConfig.providerPiper,
    );

    await prefs.setString(_configKey, jsonEncode(migrated.toMap()));
    await prefs.setBool(_migrationKey, true);
  }

  Future<void> _saveConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_configKey, jsonEncode(_config.toMap()));
  }

  void _syncPublicFieldsFromConfig() {
    speechRate = _config.speechRate;
    pitch = _config.pitch;
    volume = _config.volumePercent / 100.0;
    language = _config.localeHint;

    _PiperVoice? voice;
    for (final item in _catalog) {
      if (item.id == _config.piperVoiceId) {
        voice = item;
        break;
      }
    }
    selectedVoice = voice == null
        ? null
        : {
            'name': voice.name,
            'locale': voice.locale,
            'id': voice.id,
          };
  }

  Future<Directory> _voicesDir() async {
    final supportDir = await getApplicationSupportDirectory();
    final dir = Directory('${supportDir.path}${Platform.pathSeparator}tts${Platform.pathSeparator}piper_models');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<String> _modelPath(String voiceId) async {
    final dir = await _voicesDir();
    return '${dir.path}${Platform.pathSeparator}$voiceId.onnx';
  }

  Future<String> _modelConfigPath(String voiceId) async {
    final dir = await _voicesDir();
    return '${dir.path}${Platform.pathSeparator}$voiceId.onnx.json';
  }

  Future<void> _reloadPiperInstance() async {
    final voiceId = _config.piperVoiceId;
    if (!await isModelDownloaded(voiceId)) {
      _loadedVoiceId = null;
      return;
    }

    await _piper.loadViaPath(
      modelPath: await _modelPath(voiceId),
      configPath: await _modelConfigPath(voiceId),
    );
    _loadedVoiceId = voiceId;
  }

  Future<List<Map<dynamic, dynamic>>> getVoices() async {
    return _catalog
        .map((v) => {
              'name': v.name,
              'locale': v.locale,
              'id': v.id,
            })
        .toList();
  }

  Future<List<String>> getLanguages() async {
    final set = <String>{};
    for (final voice in _catalog) {
      set.add(voice.locale);
    }
    final list = set.toList()..sort();
    return list;
  }

  Future<void> setLanguage(String lang) async {
    await _ready;
    language = lang;
    final langPrefix = lang.trim().toLowerCase();
    final langKey = langPrefix.length >= 2 ? langPrefix.substring(0, 2) : langPrefix;
    _PiperVoice? preferredVoice;
    for (final voice in _catalog) {
      if (langKey.isNotEmpty && voice.locale.toLowerCase().startsWith(langKey)) {
        preferredVoice = voice;
        break;
      }
    }
    final nextVoiceId = preferredVoice?.id ?? _config.piperVoiceId;
    _config = _config.copyWith(localeHint: lang, piperVoiceId: nextVoiceId);
    _syncPublicFieldsFromConfig();
    await _saveConfig();
    await _reloadPiperInstance();
    notifyListeners();
  }

  Future<void> setVoice(Map<String, String> voice) async {
    await _ready;
    String? voiceId = voice['id'];
    if (voiceId == null) {
      for (final item in _catalog) {
        if (item.name == voice['name']) {
          voiceId = item.id;
          break;
        }
      }
    }
    if (voiceId == null) {
      throw Exception('Voz Piper inválida');
    }
    final selected = _catalog.where((v) => v.id == voiceId).first;
    _config = _config.copyWith(
      piperVoiceId: selected.id,
      localeHint: selected.locale,
    );
    _syncPublicFieldsFromConfig();
    await _saveConfig();
    await _reloadPiperInstance();
    notifyListeners();
  }

  Future<void> setSpeechRate(double rate) async {
    await _ready;
    _config = _config.copyWith(speechRate: rate.clamp(0.1, 1.2));
    _syncPublicFieldsFromConfig();
    await _saveConfig();
    notifyListeners();
  }

  Future<void> setPitch(double p) async {
    await _ready;
    _config = _config.copyWith(pitch: p.clamp(0.5, 2.0));
    _syncPublicFieldsFromConfig();
    await _saveConfig();
    notifyListeners();
  }

  Future<void> setVolume(double v) async {
    await _ready;
    final volumePercent = (v.clamp(0.0, 1.0) * 100).round().clamp(0, 100);
    _config = _config.copyWith(volumePercent: volumePercent);
    _syncPublicFieldsFromConfig();
    await _saveConfig();
    notifyListeners();
  }

  Future<void> setEnabled(bool enabled) async {
    await _ready;
    _config = _config.copyWith(enabled: enabled);
    await _saveConfig();
    notifyListeners();
  }

  Future<void> setRepeatCount(int count) async {
    await _ready;
    _config = _config.copyWith(repeatCount: count);
    await _saveConfig();
    notifyListeners();
  }

  Future<void> setRepeatDelaySeconds(int seconds) async {
    await _ready;
    _config = _config.copyWith(repeatDelaySeconds: seconds.clamp(0, 30));
    await _saveConfig();
    notifyListeners();
  }

  Future<bool> isModelDownloaded([String? voiceId]) async {
    final id = voiceId ?? _config.piperVoiceId;
    final model = File(await _modelPath(id));
    final cfg = File(await _modelConfigPath(id));
    return await model.exists() && await cfg.exists();
  }

  Future<void> downloadVoice(
    String voiceId, {
    void Function(double progress)? onProgress,
  }) async {
    await _ready;
    _PiperVoice? voice;
    for (final item in _catalog) {
      if (item.id == voiceId) {
        voice = item;
        break;
      }
    }
    if (voice == null) {
      throw Exception('VoiceId Piper no soportado: $voiceId');
    }

    final modelPath = await _modelPath(voiceId);
    final configPath = await _modelConfigPath(voiceId);

    await _downloadWithProgress(
      url: voice.modelUrl,
      targetPath: modelPath,
      progressKey: voiceId,
      onProgress: onProgress,
      fromProgress: 0.0,
      toProgress: 0.9,
    );

    await _downloadWithProgress(
      url: voice.configUrl,
      targetPath: configPath,
      progressKey: voiceId,
      onProgress: onProgress,
      fromProgress: 0.9,
      toProgress: 1.0,
    );

    _downloadProgress.remove(voiceId);
    if (_config.piperVoiceId == voiceId) {
      await _reloadPiperInstance();
    }
    notifyListeners();
  }

  Future<void> _downloadWithProgress({
    required String url,
    required String targetPath,
    required String progressKey,
    required double fromProgress,
    required double toProgress,
    void Function(double progress)? onProgress,
  }) async {
    final request = http.Request('GET', Uri.parse(url));
    final response = await request.send();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Descarga fallida (${response.statusCode}) para $url');
    }

    final file = File(targetPath);
    if (await file.exists()) {
      await file.delete();
    }

    final sink = file.openWrite();
    final totalBytes = response.contentLength ?? -1;
    var receivedBytes = 0;

    await for (final chunk in response.stream) {
      sink.add(chunk);
      receivedBytes += chunk.length;
      if (totalBytes > 0) {
        final local = receivedBytes / totalBytes;
        final progress = fromProgress + ((toProgress - fromProgress) * local);
        _downloadProgress[progressKey] = progress.clamp(0.0, 1.0);
        onProgress?.call(_downloadProgress[progressKey]!);
        notifyListeners();
      }
    }

    await sink.flush();
    await sink.close();
    _downloadProgress[progressKey] = toProgress;
    onProgress?.call(toProgress);
  }

  Future<void> deleteVoice(String voiceId) async {
    await _ready;
    final model = File(await _modelPath(voiceId));
    final cfg = File(await _modelConfigPath(voiceId));
    if (await model.exists()) await model.delete();
    if (await cfg.exists()) await cfg.delete();

    if (_config.piperVoiceId == voiceId) {
      _loadedVoiceId = null;
    }
    notifyListeners();
  }

  Future<void> _synthesizeAndPlay(String text, String voiceId) async {
    final tempDir = await getTemporaryDirectory();
    final wavPath =
        '${tempDir.path}${Platform.pathSeparator}tts_${DateTime.now().microsecondsSinceEpoch}.wav';
    _activeWavPath = wavPath;

    await _piper.synthesizeToFile(
      text: text,
      outputPath: wavPath,
    );

    final completer = Completer<void>();
    late final StreamSubscription<void> completeSub;

    completeSub = _player.onPlayerComplete.listen((_) {
      if (!completer.isCompleted) completer.complete();
    });

    await _player.stop();
    await _player.play(DeviceFileSource(wavPath));
    await completer.future;

    await completeSub.cancel();

    final temp = File(wavPath);
    if (await temp.exists()) {
      await temp.delete();
    }
    _activeWavPath = null;
  }

  Future<void> speak(String text) async {
    await _ready;
    final normalized = text.trim();
    if (normalized.isEmpty) return;
    if (!_config.enabled) {
      throw TtsDisabledException();
    }

    final voiceId = _config.piperVoiceId;
    if (!await isModelDownloaded(voiceId)) {
      _emitEvent('tts_model_missing', {'voiceId': voiceId});
      throw TtsModelMissingException(voiceId);
    }

    if (_loadedVoiceId != voiceId) {
      await _reloadPiperInstance();
    }

    if (_loadedVoiceId != voiceId || !_piper.isLoaded) {
      throw Exception('No se pudo inicializar Piper para $voiceId');
    }

    await stop();

    isPlaying = true;
    notifyListeners();
    _emitEvent('tts_play_requested', {'voiceId': voiceId});

    final mySession = ++_playSessionId;
    await _cacheAndSetPlaybackVolume();

    try {
      final repeats = _config.repeatCount;
      final totalRuns = repeats == -1 ? 1 : repeats.clamp(1, 50);
      for (var i = 0; i < totalRuns; i++) {
        if (mySession != _playSessionId) return;

        _emitEvent('tts_synthesis_started', {'voiceId': voiceId, 'run': i + 1});
        await _synthesizeAndPlay(normalized, voiceId);

        if (_config.repeatDelaySeconds > 0 && i < (totalRuns - 1)) {
          await Future<void>.delayed(
            Duration(seconds: _config.repeatDelaySeconds),
          );
        }
      }

      if (repeats == -1) {
        while (mySession == _playSessionId) {
          await Future<void>.delayed(
            Duration(seconds: _config.repeatDelaySeconds.clamp(1, 30)),
          );
          if (mySession != _playSessionId) break;
          await _synthesizeAndPlay(normalized, voiceId);
        }
      }

      _emitEvent('tts_play_completed', {'voiceId': voiceId});
    } catch (e) {
      _emitEvent('tts_synthesis_failed', {
        'voiceId': voiceId,
        'errorType': e.runtimeType.toString(),
      });
      rethrow;
    } finally {
      if (mySession == _playSessionId) {
        isPlaying = false;
        notifyListeners();
        onComplete?.call();
      }
      await _restorePlaybackVolume();
    }
  }

  Future<void> _cacheAndSetPlaybackVolume() async {
    try {
      final previous = await _audioChannel.invokeMethod<int>(
        'cacheAndSetMusicVolumePercent',
        {'percent': _config.volumePercent},
      );
      _cachedMusicVolume = previous;
    } catch (_) {
      _cachedMusicVolume = null;
    }
  }

  Future<void> _restorePlaybackVolume() async {
    final prev = _cachedMusicVolume;
    _cachedMusicVolume = null;
    if (prev == null) return;
    try {
      await _audioChannel.invokeMethod<void>(
        'restoreMusicVolume',
        {'volume': prev},
      );
      _emitEvent('tts_volume_restored', {'restoredVolume': prev});
    } catch (_) {}
  }

  Future<void> stop() async {
    await _ready;
    _playSessionId++;
    try {
      await _player.stop();
      final wavPath = _activeWavPath;
      _activeWavPath = null;
      if (wavPath != null) {
        final f = File(wavPath);
        if (await f.exists()) {
          await f.delete();
        }
      }
    } catch (_) {}
    isPlaying = false;
    notifyListeners();
    await _restorePlaybackVolume();
    _emitEvent('tts_play_stopped', {'voiceId': _config.piperVoiceId});
  }

  void _emitEvent(String event, Map<String, Object?> payload) {
    debugPrint('[TTS][$event] ${jsonEncode(payload)}');
  }

  @override
  void dispose() {
    _playSessionId++;
    try {
      _player.stop();
      _player.dispose();
    } catch (_) {}
    _loadedVoiceId = null;
    super.dispose();
  }
}

class TtsModelMissingException implements Exception {
  final String voiceId;

  TtsModelMissingException(this.voiceId);

  @override
  String toString() =>
      'Falta modelo Piper para la voz $voiceId. Descarga la voz y reintenta.';
}

class TtsDisabledException implements Exception {
  @override
  String toString() => 'El TTS está desactivado en la configuración.';
}

class _PiperVoice {
  final String id;
  final String locale;
  final String name;
  final String modelUrl;
  final String configUrl;

  const _PiperVoice({
    required this.id,
    required this.locale,
    required this.name,
    required this.modelUrl,
    required this.configUrl,
  });
}
