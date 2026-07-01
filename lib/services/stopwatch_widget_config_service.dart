import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Specs de los 3 estilos ─────────────────────────────────────────────────────────────

class StopwatchWidgetConfigSpec {
  final String id;
  final String name;
  final String description;
  final bool hasRing;
  final bool hasLaps;
  final bool hasTimerBar;
  final int maxLapsVisible;

  const StopwatchWidgetConfigSpec({
    required this.id,
    required this.name,
    required this.description,
    required this.hasRing,
    required this.hasLaps,
    required this.hasTimerBar,
    required this.maxLapsVisible,
  });

  static const List<StopwatchWidgetConfigSpec> widgets = [
    StopwatchWidgetConfigSpec(
      id: 'style1',
      name: 'Compacto',
      description: 'Título + tiempo + botones con visibilidad según modo',
      hasRing: false,
      hasLaps: false,
      hasTimerBar: false,
      maxLapsVisible: 0,
    ),
    StopwatchWidgetConfigSpec(
      id: 'style3',
      name: 'Circular',
      description: 'Anillo de progreso con tiempo centrado y lista de vueltas',
      hasRing: true,
      hasLaps: true,
      hasTimerBar: false,
      maxLapsVisible: 3,
    ),
  ];
}

// ── Snapshot mutable de configuración (el editor trabaja sobre este objeto) ────────────

class StopwatchWidgetCfg {
  // Fondo
  int bgArgb;

  // Tiempo principal
  int timeColor;
  int timeSizeSp;
  bool timeBold;
  bool showMs;
  String timeFormat;       // 'hms' | 'ms' | 's_ms'

  // Vueltas
  int lapColor;
  int lapSizeSp;
  bool lapBold;
  int lapCount;            // 1-5
  bool showLapNumber;
  bool showLapDelta;

  // Etiqueta de modo
  int modeLabelColor;
  int modeLabelSizeSp;

  // Iconos
  int iconColor;
  bool iconColorEnabled;
  int iconSizeDp;
  String iconPlay;
  String iconPause;
  String iconReset;
  String iconLap;
  String iconToggleMode;

  // Anillo (style3)
  int ringTrackArgb;
  int ringFillArgb;
  int ringThicknessDp;

  // Barra de timer (style2)
  int barTrackArgb;
  int barFillArgb;
  int barThicknessDp;

  // Layout
  int cornerRadiusDp;
  int rowSpacingDp;
  int contentScalePct;

  // Textos
  String labelIdle;
  String labelPaused;
  String labelStopwatch;
  String labelTimer;
  String lapPrefix;
  String defaultMode;

  // Temporizador: minutos por paso de +/− (botones en style1)
  int timerStepMinutes;

  StopwatchWidgetCfg({
    required this.bgArgb,
    required this.timeColor,
    required this.timeSizeSp,
    required this.timeBold,
    required this.showMs,
    required this.timeFormat,
    required this.lapColor,
    required this.lapSizeSp,
    required this.lapBold,
    required this.lapCount,
    required this.showLapNumber,
    required this.showLapDelta,
    required this.modeLabelColor,
    required this.modeLabelSizeSp,
    required this.iconColor,
    required this.iconColorEnabled,
    required this.iconSizeDp,
    required this.iconPlay,
    required this.iconPause,
    required this.iconReset,
    required this.iconLap,
    required this.iconToggleMode,
    required this.ringTrackArgb,
    required this.ringFillArgb,
    required this.ringThicknessDp,
    required this.barTrackArgb,
    required this.barFillArgb,
    required this.barThicknessDp,
    required this.cornerRadiusDp,
    required this.rowSpacingDp,
    required this.contentScalePct,
    required this.labelIdle,
    required this.labelPaused,
    required this.labelStopwatch,
    required this.labelTimer,
    required this.lapPrefix,
    required this.defaultMode,
    required this.timerStepMinutes,
  });
}

// ── Servicio de persistencia ───────────────────────────────────────────────────────────

class StopwatchWidgetConfigService {
  static const _channel = MethodChannel('com.example.connect/ble');

  // ── Defaults (DEBEN ser idénticos a readWidgetCfg en StopwatchWidgetProvider.kt) ──────
  static const defBgArgb           = 0xCC000000;
  static const defTimeColor        = 0xFFFFFFFF;
  static const defTimeSizeSp       = 28;
  static const defTimeBold         = true;
  static const defShowMs           = true;
  static const defTimeFormat       = 'hms';
  static const defLapColor         = 0xFFCCCCCC;
  static const defLapSizeSp        = 11;
  static const defLapBold          = false;
  static const defLapCount         = 3;
  static const defShowLapNumber    = true;
  static const defShowLapDelta     = true;
  static const defModeLabelColor   = 0xFF88AAFF;
  static const defModeLabelSizeSp  = 9;
  static const defIconColor        = 0xFFFFFFFF;
  static const defIconColorEnabled = true;
  static const defIconSizeDp       = 24;
  static const defRingTrackArgb    = 0x33FFFFFF;
  static const defRingFillArgb     = 0xFF4488FF;
  static const defRingThicknessDp  = 8;
  static const defBarTrackArgb     = 0x33FFFFFF;
  static const defBarFillArgb      = 0xFF4488FF;
  static const defBarThicknessDp   = 4;
  static const defCornerRadiusDp   = 12;
  static const defRowSpacingDp     = 4;
  static const defContentScalePct  = 100;
  static const defTimerStepMinutes = 5;

  static String _k(String id, String prop) => 'stopwatch_cfg_${id}_$prop';

  static Future<StopwatchWidgetCfg> load(StopwatchWidgetConfigSpec spec) async {
    final p = await SharedPreferences.getInstance();
    final id = spec.id;
    int i(String prop, int def)    => p.getInt(_k(id, prop)) ?? def;
    bool b(String prop, bool def)  => p.getBool(_k(id, prop)) ?? def;
    String s(String prop, String def) => p.getString(_k(id, prop)) ?? def;

    return StopwatchWidgetCfg(
      bgArgb:          i('bgArgb',          defBgArgb),
      timeColor:       i('timeColor',       defTimeColor),
      timeSizeSp:      i('timeSizeSp',      defTimeSizeSp),
      timeBold:        b('timeBold',        defTimeBold),
      showMs:          b('showMs',          defShowMs),
      timeFormat:      s('timeFormat',      defTimeFormat),
      lapColor:        i('lapColor',        defLapColor),
      lapSizeSp:       i('lapSizeSp',       defLapSizeSp),
      lapBold:         b('lapBold',         defLapBold),
      lapCount:        i('lapCount',        defLapCount),
      showLapNumber:   b('showLapNumber',   defShowLapNumber),
      showLapDelta:    b('showLapDelta',    defShowLapDelta),
      modeLabelColor:  i('modeLabelColor',  defModeLabelColor),
      modeLabelSizeSp: i('modeLabelSizeSp', defModeLabelSizeSp),
      iconColor:       i('iconColor',       defIconColor),
      iconColorEnabled: b('iconColorEnabled', defIconColorEnabled),
      iconSizeDp:      i('iconSizeDp',      defIconSizeDp),
      iconPlay:        s('iconPlay',        ''),
      iconPause:       s('iconPause',       ''),
      iconReset:       s('iconReset',       ''),
      iconLap:         s('iconLap',         ''),
      iconToggleMode:  s('iconToggleMode',  ''),
      ringTrackArgb:   i('ringTrackArgb',   defRingTrackArgb),
      ringFillArgb:    i('ringFillArgb',    defRingFillArgb),
      ringThicknessDp: i('ringThicknessDp', defRingThicknessDp),
      barTrackArgb:    i('barTrackArgb',    defBarTrackArgb),
      barFillArgb:     i('barFillArgb',     defBarFillArgb),
      barThicknessDp:  i('barThicknessDp',  defBarThicknessDp),
      cornerRadiusDp:  i('cornerRadiusDp',  defCornerRadiusDp),
      rowSpacingDp:    i('rowSpacingDp',    defRowSpacingDp),
      contentScalePct: i('contentScalePct', defContentScalePct),
      labelIdle:       s('labelIdle',       'Listo'),
      labelPaused:     s('labelPaused',     'Pausado'),
      labelStopwatch:  s('labelStopwatch',  'CRONÓMETRO'),
      labelTimer:      s('labelTimer',      'TEMPORIZADOR'),
      lapPrefix:       s('lapPrefix',       'V'),
      defaultMode:      s('defaultMode',      'stopwatch'),
      timerStepMinutes: i('timerStepMinutes', defTimerStepMinutes),
    );
  }

  static Future<void> setInt(String id, String prop, int value) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_k(id, prop), value);
    await _notify();
  }

  static Future<void> setBool(String id, String prop, bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_k(id, prop), value);
    await _notify();
  }

  static Future<void> setString(String id, String prop, String value) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_k(id, prop), value);
    await _notify();
  }

  static Future<void> resetAll(String id) async {
    final p  = await SharedPreferences.getInstance();
    final prefix = 'stopwatch_cfg_${id}_';
    final keys = p.getKeys().where((k) => k.startsWith(prefix)).toList();
    for (final k in keys) { await p.remove(k); }
    await _notify();
  }

  static Future<void> _notify() async {
    try {
      await _channel.invokeMethod('updateStopwatchWidget');
    } catch (_) {}
  }
}
