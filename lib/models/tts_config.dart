class TtsConfig {
  final bool enabled;
  final String provider;
  final String piperVoiceId;
  final int volumePercent;
  final double pitch;
  final int repeatCount;
  final int repeatDelaySeconds;
  final double speechRate;
  final bool usePrefix;
  final String localeHint;

  const TtsConfig({
    required this.enabled,
    required this.provider,
    required this.piperVoiceId,
    required this.volumePercent,
    required this.pitch,
    required this.repeatCount,
    required this.repeatDelaySeconds,
    required this.speechRate,
    required this.usePrefix,
    required this.localeHint,
  });

  static const String providerPiper = 'piper';

  factory TtsConfig.defaults({String localeHint = 'es-MX'}) {
    return TtsConfig(
      enabled: true,
      provider: providerPiper,
      piperVoiceId: _defaultVoiceForLocale(localeHint),
      volumePercent: 100,
      pitch: 1.0,
      repeatCount: 1,
      repeatDelaySeconds: 0,
      speechRate: 0.5,
      usePrefix: false,
      localeHint: localeHint,
    );
  }

  static String _defaultVoiceForLocale(String localeHint) {
    final normalized = localeHint.toLowerCase();
    if (normalized.startsWith('es')) {
      return 'es_ES-carlfm-x_low';
    }
    return 'en_US-lessac-medium';
  }

  TtsConfig copyWith({
    bool? enabled,
    String? provider,
    String? piperVoiceId,
    int? volumePercent,
    double? pitch,
    int? repeatCount,
    int? repeatDelaySeconds,
    double? speechRate,
    bool? usePrefix,
    String? localeHint,
  }) {
    return TtsConfig(
      enabled: enabled ?? this.enabled,
      provider: provider ?? this.provider,
      piperVoiceId: piperVoiceId ?? this.piperVoiceId,
      volumePercent: volumePercent ?? this.volumePercent,
      pitch: pitch ?? this.pitch,
      repeatCount: repeatCount ?? this.repeatCount,
      repeatDelaySeconds: repeatDelaySeconds ?? this.repeatDelaySeconds,
      speechRate: speechRate ?? this.speechRate,
      usePrefix: usePrefix ?? this.usePrefix,
      localeHint: localeHint ?? this.localeHint,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled,
      'provider': provider,
      'piperVoiceId': piperVoiceId,
      'volumePercent': volumePercent,
      'pitch': pitch,
      'repeatCount': repeatCount,
      'repeatDelaySeconds': repeatDelaySeconds,
      'speechRate': speechRate,
      'usePrefix': usePrefix,
      'localeHint': localeHint,
    };
  }

  factory TtsConfig.fromMap(Map<String, dynamic> map) {
    return TtsConfig(
      enabled: (map['enabled'] as bool?) ?? true,
      provider: (map['provider'] as String?) ?? providerPiper,
      piperVoiceId: (map['piperVoiceId'] as String?) ??
          _defaultVoiceForLocale((map['localeHint'] as String?) ?? 'es-MX'),
      volumePercent: ((map['volumePercent'] as num?)?.toInt() ?? 100)
          .clamp(0, 100),
      pitch: ((map['pitch'] as num?)?.toDouble() ?? 1.0).clamp(0.5, 2.0),
      repeatCount: (map['repeatCount'] as num?)?.toInt() ?? 1,
      repeatDelaySeconds:
          ((map['repeatDelaySeconds'] as num?)?.toInt() ?? 0).clamp(0, 30),
      speechRate:
          ((map['speechRate'] as num?)?.toDouble() ?? 0.5).clamp(0.1, 1.2),
      usePrefix: (map['usePrefix'] as bool?) ?? false,
      localeHint: (map['localeHint'] as String?) ?? 'es-MX',
    );
  }
}
