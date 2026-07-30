import 'dart:async';
import 'dart:convert';
import 'package:connect/services/stopwatch_timer_service.dart';
import 'package:connect/services/stopwatch_widget_config_service.dart';
import 'package:connect/widgets/color_input_widget.dart';
import 'package:connect/widgets/stopwatch_widget_preview.dart';
import 'package:connect/widgets/widget_icon_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Editor de un estilo del widget de cronómetro/temporizador.
/// Preview fija arriba + TabBar con 6 pestañas de ajustes.
class StopwatchWidgetEditorScreen extends StatefulWidget {
  final StopwatchWidgetConfigSpec spec;
  const StopwatchWidgetEditorScreen({super.key, required this.spec});

  @override
  State<StopwatchWidgetEditorScreen> createState() => _StopwatchWidgetEditorScreenState();
}

class _StopwatchWidgetEditorScreenState extends State<StopwatchWidgetEditorScreen> {
  StopwatchWidgetCfg? _cfg;
  Timer? _textDebounce;

  StopwatchWidgetConfigSpec get spec => widget.spec;

  // Preview usa datos de ejemplo
  final _previewState = StopwatchSnapshot(
    mode: StopwatchMode.stopwatch,
    state: StopwatchStateEnum.paused,
    elapsed: const Duration(minutes: 1, seconds: 23, milliseconds: 456),
    remaining: const Duration(minutes: 3, seconds: 41),
    timerTarget: const Duration(minutes: 5),
    laps: [
      LapEntry(number: 1, totalElapsed: const Duration(seconds: 43, milliseconds: 210), delta: const Duration(seconds: 43, milliseconds: 210)),
      LapEntry(number: 2, totalElapsed: const Duration(minutes: 1, seconds: 23, milliseconds: 456), delta: const Duration(seconds: 40, milliseconds: 246)),
    ],
  );

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _textDebounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final cfg = await StopwatchWidgetConfigService.load(spec);
    if (!mounted) return;
    setState(() => _cfg = cfg);
  }

  // ── Helpers de persistencia ──────────────────────────────────────────────────────────

  Future<void> _setInt(String prop, int value) =>
      StopwatchWidgetConfigService.setInt(spec.id, prop, value);
  Future<void> _setBool(String prop, bool value) =>
      StopwatchWidgetConfigService.setBool(spec.id, prop, value);
  Future<void> _setString(String prop, String value) =>
      StopwatchWidgetConfigService.setString(spec.id, prop, value);

  void _debounceText(String prop, String value) {
    _textDebounce?.cancel();
    _textDebounce = Timer(const Duration(milliseconds: 500), () => _setString(prop, value));
  }

  Future<void> _confirmReset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Restablecer'),
        content: const Text('¿Volver a los valores predeterminados?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true),  child: const Text('Restablecer')),
        ],
      ),
    );
    if (ok == true) {
      await StopwatchWidgetConfigService.resetAll(spec.id);
      await _load();
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cfg = _cfg;
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: Text(spec.name),
          actions: [
            IconButton(
              tooltip: 'Restablecer',
              icon: const Icon(Icons.restore),
              onPressed: cfg == null ? null : _confirmReset,
            ),
          ],
        ),
        body: cfg == null
            ? const Center(child: CircularProgressIndicator())
            : NestedScrollView(
                headerSliverBuilder: (context, _) => [
                  SliverToBoxAdapter(child: _previewArea(cfg)),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _SliverTabBarDelegate(
                      const TabBar(
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        tabs: [
                          Tab(text: 'Pantalla'),
                          Tab(text: 'Colores'),
                          Tab(text: 'Tamaños'),
                          Tab(text: 'Iconos'),
                          Tab(text: 'Textos'),
                          Tab(text: 'Audio'),
                        ],
                      ),
                    ),
                  ),
                ],
                body: TabBarView(
                  children: [
                    _tabPage([_tabPantalla(cfg)]),
                    _tabPage([_tabColores(cfg)]),
                    _tabPage([_tabTamanos(cfg)]),
                    _tabPage([_tabIconos(cfg)]),
                    _tabPage([_tabTextos(cfg)]),
                    _tabPage([_tabAudio()]),
                  ],
                ),
              ),
      ),
    );
  }

  // ── Preview ──────────────────────────────────────────────────────────────────────────

  Widget _previewArea(StopwatchWidgetCfg cfg) {
    return LayoutBuilder(builder: (context, constraints) {
      final availW = constraints.maxWidth;
      final widgetW = _previewWidgetWidth(availW);
      final widgetH = _previewWidgetHeight(availW);
      return Container(
        color: const Color(0xFF1C2030), // fondo tipo pantalla de inicio
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: widgetW,
              height: widgetH,
              child: StopwatchWidgetPreview(spec: spec, cfg: cfg, previewState: _previewState),
            ),
            const SizedBox(height: 6),
            Text(
              'Vista previa — ${spec.name}',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
      );
    });
  }

  double _previewWidgetWidth(double availW) => switch (spec.id) {
    'style1' => availW - 32,
    'style3' => (availW - 32) * 0.55,
    _ => availW - 32,
  };

  double _previewWidgetHeight(double availW) {
    final w = _previewWidgetWidth(availW);
    return switch (spec.id) {
      'style1' => (w * 0.38).clamp(90, 130),
      'style3' => w.clamp(140, 260),
      _ => w,
    };
  }

  Widget _tabPage(List<Widget> sections) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: sections),
  );

  // ── TAB 1: Pantalla ──────────────────────────────────────────────────────────────────

  Widget _tabPantalla(StopwatchWidgetCfg cfg) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (spec.hasLaps) ...[
          _sectionHeader('Vueltas'),
          _sliderTile(
            label: 'Vueltas a mostrar',
            value: cfg.lapCount.toDouble(),
            min: 1, max: 5, divisions: 4,
            display: cfg.lapCount.toString(),
            onChanged: (v) => setState(() => cfg.lapCount = v.round()),
            onChangeEnd: (v) => _setInt('lapCount', v.round()),
          ),
          _switchTile(
            label: 'Mostrar número de vuelta',
            value: cfg.showLapNumber,
            onChanged: (v) { setState(() => cfg.showLapNumber = v); _setBool('showLapNumber', v); },
          ),
          _switchTile(
            label: 'Mostrar tiempo delta',
            value: cfg.showLapDelta,
            onChanged: (v) { setState(() => cfg.showLapDelta = v); _setBool('showLapDelta', v); },
          ),
        ],
        _sectionHeader('Escala global'),
        _sliderTile(
          label: 'Escala del contenido',
          value: cfg.contentScalePct.toDouble(),
          min: 50, max: 150, divisions: 20,
          display: '${cfg.contentScalePct}%',
          onChanged: (v) => setState(() => cfg.contentScalePct = v.round()),
          onChangeEnd: (v) => _setInt('contentScalePct', v.round()),
        ),
        _sectionHeader('Modo por defecto'),
        _dropdownTile(
          label: 'Al añadir el widget',
          value: cfg.defaultMode,
          items: const {'stopwatch': 'Cronómetro', 'timer': 'Temporizador'},
          onChanged: (v) {
            setState(() => cfg.defaultMode = v);
            _setString('defaultMode', v);
          },
        ),
        if (spec.id == 'style1') ...[
          _sectionHeader('Temporizador'),
          _sliderTile(
            label: 'Paso de +/− minutos',
            value: cfg.timerStepMinutes.toDouble(),
            min: 1, max: 30, divisions: 29,
            display: '${cfg.timerStepMinutes} min',
            onChanged: (v) => setState(() => cfg.timerStepMinutes = v.round()),
            onChangeEnd: (v) => _setInt('timerStepMinutes', v.round()),
          ),
        ],
      ],
    );
  }

  // ── TAB 2: Colores ───────────────────────────────────────────────────────────────────

  Widget _tabColores(StopwatchWidgetCfg cfg) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Fondo'),
        _colorTile(
          label: 'Color de fondo',
          value: cfg.bgArgb,
          onChanged: (v) { setState(() => cfg.bgArgb = v); _setInt('bgArgb', v); },
        ),
        _sectionHeader('Tiempo principal'),
        _colorTile(
          label: 'Color del tiempo',
          value: cfg.timeColor,
          onChanged: (v) { setState(() => cfg.timeColor = v); _setInt('timeColor', v); },
        ),
        if (spec.hasLaps) ...[
          _sectionHeader('Vueltas'),
          _colorTile(
            label: 'Color de texto de vuelta',
            value: cfg.lapColor,
            onChanged: (v) { setState(() => cfg.lapColor = v); _setInt('lapColor', v); },
          ),
        ],
        _sectionHeader('Etiqueta de modo'),
        _colorTile(
          label: 'Color de etiqueta',
          value: cfg.modeLabelColor,
          onChanged: (v) { setState(() => cfg.modeLabelColor = v); _setInt('modeLabelColor', v); },
        ),
        _sectionHeader('Iconos de botones'),
        _switchTile(
          label: 'Aplicar tinte a iconos',
          value: cfg.iconColorEnabled,
          onChanged: (v) { setState(() => cfg.iconColorEnabled = v); _setBool('iconColorEnabled', v); },
        ),
        if (cfg.iconColorEnabled)
          _colorTile(
            label: 'Color de iconos',
            value: cfg.iconColor,
            onChanged: (v) { setState(() => cfg.iconColor = v); _setInt('iconColor', v); },
          ),
        if (spec.hasRing) ...[
          _sectionHeader('Anillo de progreso'),
          _colorTile(
            label: 'Color de pista',
            value: cfg.ringTrackArgb,
            onChanged: (v) { setState(() => cfg.ringTrackArgb = v); _setInt('ringTrackArgb', v); },
          ),
          _colorTile(
            label: 'Color de relleno',
            value: cfg.ringFillArgb,
            onChanged: (v) { setState(() => cfg.ringFillArgb = v); _setInt('ringFillArgb', v); },
          ),
        ],
        if (spec.hasTimerBar) ...[
          _sectionHeader('Barra de temporizador'),
          _colorTile(
            label: 'Color de pista',
            value: cfg.barTrackArgb,
            onChanged: (v) { setState(() => cfg.barTrackArgb = v); _setInt('barTrackArgb', v); },
          ),
          _colorTile(
            label: 'Color de relleno',
            value: cfg.barFillArgb,
            onChanged: (v) { setState(() => cfg.barFillArgb = v); _setInt('barFillArgb', v); },
          ),
        ],
      ],
    );
  }

  // ── TAB 3: Tamaños ───────────────────────────────────────────────────────────────────

  Widget _tabTamanos(StopwatchWidgetCfg cfg) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Tiempo principal'),
        _sliderTile(
          label: 'Tamaño del texto (sp)',
          value: cfg.timeSizeSp.toDouble(),
          min: 8, max: 80, divisions: 72,
          display: '${cfg.timeSizeSp}sp',
          onChanged: (v) => setState(() => cfg.timeSizeSp = v.round()),
          onChangeEnd: (v) => _setInt('timeSizeSp', v.round()),
        ),
        _switchTile(
          label: 'Negrita',
          value: cfg.timeBold,
          onChanged: (v) { setState(() => cfg.timeBold = v); _setBool('timeBold', v); },
        ),
        if (spec.hasLaps) ...[
          _sectionHeader('Vueltas'),
          _sliderTile(
            label: 'Tamaño del texto (sp)',
            value: cfg.lapSizeSp.toDouble(),
            min: 8, max: 40, divisions: 32,
            display: '${cfg.lapSizeSp}sp',
            onChanged: (v) => setState(() => cfg.lapSizeSp = v.round()),
            onChangeEnd: (v) => _setInt('lapSizeSp', v.round()),
          ),
          _switchTile(
            label: 'Negrita',
            value: cfg.lapBold,
            onChanged: (v) { setState(() => cfg.lapBold = v); _setBool('lapBold', v); },
          ),
          _sliderTile(
            label: 'Espaciado entre filas (dp)',
            value: cfg.rowSpacingDp.toDouble(),
            min: 0, max: 32, divisions: 32,
            display: '${cfg.rowSpacingDp}dp',
            onChanged: (v) => setState(() => cfg.rowSpacingDp = v.round()),
            onChangeEnd: (v) => _setInt('rowSpacingDp', v.round()),
          ),
        ],
        _sectionHeader('Etiqueta de modo'),
        _sliderTile(
          label: 'Tamaño del texto (sp)',
          value: cfg.modeLabelSizeSp.toDouble(),
          min: 6, max: 24, divisions: 18,
          display: '${cfg.modeLabelSizeSp}sp',
          onChanged: (v) => setState(() => cfg.modeLabelSizeSp = v.round()),
          onChangeEnd: (v) => _setInt('modeLabelSizeSp', v.round()),
        ),
        _sectionHeader('Iconos de botones'),
        _sliderTile(
          label: 'Tamaño de iconos (dp)',
          value: cfg.iconSizeDp.toDouble(),
          min: 16, max: 64, divisions: 48,
          display: '${cfg.iconSizeDp}dp',
          onChanged: (v) => setState(() => cfg.iconSizeDp = v.round()),
          onChangeEnd: (v) => _setInt('iconSizeDp', v.round()),
        ),
        if (spec.hasRing) ...[
          _sectionHeader('Anillo'),
          _sliderTile(
            label: 'Grosor del anillo (dp)',
            value: cfg.ringThicknessDp.toDouble(),
            min: 2, max: 24, divisions: 22,
            display: '${cfg.ringThicknessDp}dp',
            onChanged: (v) => setState(() => cfg.ringThicknessDp = v.round()),
            onChangeEnd: (v) => _setInt('ringThicknessDp', v.round()),
          ),
        ],
        if (spec.hasTimerBar) ...[
          _sectionHeader('Barra de temporizador'),
          _sliderTile(
            label: 'Grosor de la barra (dp)',
            value: cfg.barThicknessDp.toDouble(),
            min: 2, max: 16, divisions: 14,
            display: '${cfg.barThicknessDp}dp',
            onChanged: (v) => setState(() => cfg.barThicknessDp = v.round()),
            onChangeEnd: (v) => _setInt('barThicknessDp', v.round()),
          ),
        ],
        _sectionHeader('Fondo'),
        _sliderTile(
          label: 'Radio de esquinas (dp)',
          value: cfg.cornerRadiusDp.toDouble(),
          min: 0, max: 32, divisions: 32,
          display: '${cfg.cornerRadiusDp}dp',
          onChanged: (v) => setState(() => cfg.cornerRadiusDp = v.round()),
          onChangeEnd: (v) => _setInt('cornerRadiusDp', v.round()),
        ),
      ],
    );
  }

  // ── TAB 4: Iconos ────────────────────────────────────────────────────────────────────

  Widget _tabIconos(StopwatchWidgetCfg cfg) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Botones'),
        _iconTile('Icono Play', 'iconPlay', cfg.iconPlay,
          onChanged: (b64) { setState(() => cfg.iconPlay = b64); _setString('iconPlay', b64); }),
        _iconTile('Icono Pausa', 'iconPause', cfg.iconPause,
          onChanged: (b64) { setState(() => cfg.iconPause = b64); _setString('iconPause', b64); }),
        _iconTile('Icono Reiniciar', 'iconReset', cfg.iconReset,
          onChanged: (b64) { setState(() => cfg.iconReset = b64); _setString('iconReset', b64); }),
        if (spec.hasLaps)
          _iconTile('Icono Vuelta', 'iconLap', cfg.iconLap,
            onChanged: (b64) { setState(() => cfg.iconLap = b64); _setString('iconLap', b64); }),
        _iconTile('Icono Cambio de modo', 'iconToggleMode', cfg.iconToggleMode,
          onChanged: (b64) { setState(() => cfg.iconToggleMode = b64); _setString('iconToggleMode', b64); }),
      ],
    );
  }

  // ── TAB 5: Textos ────────────────────────────────────────────────────────────────────

  Widget _tabTextos(StopwatchWidgetCfg cfg) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Etiquetas de estado'),
        _textFieldTile('Texto "Listo"',    cfg.labelIdle,    (v) { setState(() => cfg.labelIdle = v);    _debounceText('labelIdle', v); }),
        _textFieldTile('Texto "Pausado"',  cfg.labelPaused,  (v) { setState(() => cfg.labelPaused = v);  _debounceText('labelPaused', v); }),
        _sectionHeader('Etiquetas de modo'),
        _textFieldTile('Etiqueta cronómetro', cfg.labelStopwatch, (v) { setState(() => cfg.labelStopwatch = v); _debounceText('labelStopwatch', v); }),
        _textFieldTile('Etiqueta temporizador', cfg.labelTimer,  (v) { setState(() => cfg.labelTimer = v);  _debounceText('labelTimer', v); }),
        if (spec.hasLaps) ...[
          _sectionHeader('Vueltas'),
          _textFieldTile('Prefijo de vuelta (ej: "V", "Lap")', cfg.lapPrefix, (v) { setState(() => cfg.lapPrefix = v); _debounceText('lapPrefix', v); }),
        ],
      ],
    );
  }

  // ── TAB 6: Audio y vibración ─────────────────────────────────────────────────────────

  Widget _tabAudio() {
    return _AudioVibConfigSection(
      onPickSound:     (isLap) => _pickSound(isLap: isLap),
      onPickVibration: _pickVibration,
    );
  }

  Future<void> _pickSound({bool isLap = false}) async {
    final result = await Navigator.pushNamed(context, '/custom_sound_selection');
    if (result is String && result.isNotEmpty) {
      final key = isLap ? 'stopwatch_lap_sound_uri' : 'stopwatch_sound_uri';
      final p = await SharedPreferences.getInstance();
      await p.setString(key, result);
      if (mounted) setState(() {});
    }
  }

  Future<void> _pickVibration() async {
    await Navigator.pushNamed(context, '/vibration_patterns');
  }

  // ── Controles reutilizables ──────────────────────────────────────────────────────────

  Widget _sectionHeader(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 16, 0, 4),
    child: Text(title.toUpperCase(),
      style: const TextStyle(color: Colors.black38, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
  );

  Widget _sliderTile({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String display,
    required void Function(double) onChanged,
    required void Function(double) onChangeEnd,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: Colors.black87)),
              Text(display, style: const TextStyle(color: Colors.black38, fontSize: 12)),
            ],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min, max: max, divisions: divisions,
            activeColor: const Color(0xFF4488FF),
            inactiveColor: Colors.grey.shade300,
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
        ],
      ),
    );
  }

  Widget _switchTile({required String label, required bool value, required void Function(bool) onChanged}) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      value: value,
      activeThumbColor: const Color(0xFF4488FF),
      onChanged: onChanged,
    );
  }

  Widget _colorTile({required String label, required int value, required void Function(int) onChanged}) {
    final hex = '#${value.toRadixString(16).padLeft(8, '0').toUpperCase()}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.black87)),
          const SizedBox(height: 4),
          ColorInputWidget(
            initialColor: hex,
            onColorChanged: (hexStr) {
              if (hexStr == null || hexStr.isEmpty) return;
              final clean = hexStr.replaceAll('#', '');
              final parsed = int.tryParse(clean, radix: 16);
              if (parsed != null) onChanged(parsed);
            },
          ),
        ],
      ),
    );
  }

  Widget _dropdownTile({
    required String label,
    required String value,
    required Map<String, String> items,
    required void Function(String) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          DropdownButton<String>(
            value: value,
            underline: const SizedBox.shrink(),
            items: items.entries
                .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
            onChanged: (v) { if (v != null) onChanged(v); },
          ),
        ],
      ),
    );
  }

  Widget _iconTile(String label, String prop, String b64Value, {required void Function(String) onChanged}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // Thumbnail del icono actual (si hay)
          _IconThumb(b64: b64Value),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          if (b64Value.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear, size: 18),
              tooltip: 'Quitar override',
              onPressed: () => onChanged(''),
            ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF4488FF)),
            onPressed: () async {
              final result = await Navigator.push<Map<String, dynamic>>(context, MaterialPageRoute(
                builder: (_) => WidgetIconPickerScreen(title: 'Elegir icono', currentOverrideBase64: b64Value.isEmpty ? null : b64Value),
              ));
              final b64 = result?['action'] == 'override' ? result!['pngBase64'] as String? : null;
              if (b64 != null && b64.isNotEmpty) onChanged(b64);
            },
            child: Text(b64Value.isEmpty ? 'Elegir' : 'Cambiar'),
          ),
        ],
      ),
    );
  }

  Widget _textFieldTile(String label, String value, void Function(String) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextField(
        controller: TextEditingController(text: value),
        decoration: InputDecoration(
          labelText: label,
          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF4488FF))),
        ),
        onChanged: onChanged,
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────────────

class _IconThumb extends StatelessWidget {
  final String b64;
  const _IconThumb({required this.b64});

  @override
  Widget build(BuildContext context) {
    if (b64.isEmpty) {
      return Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: Colors.grey.shade200, borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(Icons.image_not_supported_outlined, size: 16),
      );
    }
    try {
      final bytes = base64Decode(b64.replaceAll(RegExp(r'\s+'), ''));
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.memory(bytes, width: 32, height: 32, fit: BoxFit.cover),
      );
    } catch (_) {
      return Container(width: 32, height: 32, color: Colors.grey.shade200);
    }
  }
}

class _AudioVibConfigSection extends StatefulWidget {
  final Future<void> Function(bool isLap) onPickSound;
  final Future<void> Function() onPickVibration;
  const _AudioVibConfigSection({required this.onPickSound, required this.onPickVibration});

  @override
  State<_AudioVibConfigSection> createState() => _AudioVibConfigSectionState();
}

class _AudioVibConfigSectionState extends State<_AudioVibConfigSection> {
  bool _soundEnabled     = true;
  bool _vibrationEnabled = true;
  String _soundUri       = '';
  bool _lapVibrate       = false;
  bool _lapSound         = false;
  String _lapSoundUri    = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cfg = await StopwatchTimerService.getAudioConfig();
    if (!mounted) return;
    setState(() {
      _soundEnabled     = cfg['soundEnabled'] as bool;
      _vibrationEnabled = cfg['vibrationEnabled'] as bool;
      _soundUri         = cfg['soundUri'] as String;
      _lapVibrate       = cfg['lapVibrate'] as bool;
      _lapSound         = cfg['lapSound'] as bool;
      _lapSoundUri      = cfg['lapSoundUri'] as String;
    });
  }

  @override
  Widget build(BuildContext context) {
    final soundName    = _soundUri.isEmpty    ? 'Sonido del sistema' : _soundUri.split('/').last;
    final lapSoundName = _lapSoundUri.isEmpty ? 'Sonido del sistema' : _lapSoundUri.split('/').last;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header('Al terminar el temporizador'),
        _row(Icons.volume_up_outlined, 'Sonido al terminar', _soundEnabled, (v) async {
          setState(() => _soundEnabled = v);
          await StopwatchTimerService.setSoundEnabled(v);
        }),
        if (_soundEnabled)
          _fileTile(soundName, () async {
            await widget.onPickSound(false);
            await _load();
          }),
        _row(Icons.vibration, 'Vibración al terminar', _vibrationEnabled, (v) async {
          setState(() => _vibrationEnabled = v);
          await StopwatchTimerService.setVibrationEnabled(v);
        }),
        if (_vibrationEnabled)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Patrón de vibración', style: TextStyle(color: Colors.black54, fontSize: 13)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async { await widget.onPickVibration(); await _load(); },
          ),
        const Divider(),
        _header('En cada vuelta (cronómetro)'),
        _row(Icons.vibration, 'Vibrar en cada vuelta', _lapVibrate, (v) async {
          setState(() => _lapVibrate = v);
          await StopwatchTimerService.setLapVibrate(v);
        }),
        _row(Icons.volume_up_outlined, 'Sonido en cada vuelta', _lapSound, (v) async {
          setState(() => _lapSound = v);
          await StopwatchTimerService.setLapSound(v);
        }),
        if (_lapSound)
          _fileTile(lapSoundName, () async {
            await widget.onPickSound(true);
            await _load();
          }),
      ],
    );
  }

  Widget _header(String t) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 16, 0, 4),
    child: Text(t.toUpperCase(),
      style: const TextStyle(color: Colors.black38, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
  );

  Widget _row(IconData icon, String label, bool value, Future<void> Function(bool) onChanged) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      secondary: Icon(icon, size: 20),
      title: Text(label),
      value: value,
      activeThumbColor: const Color(0xFF4488FF),
      onChanged: (v) => onChanged(v),
    );
  }

  Widget _fileTile(String name, VoidCallback onTap) => ListTile(
    contentPadding: EdgeInsets.zero,
    dense: true,
    title: Text(name, style: const TextStyle(color: Colors.black54, fontSize: 12)),
    trailing: const Icon(Icons.chevron_right, size: 18),
    onTap: onTap,
  );
}

// ── SliverPersistentHeaderDelegate para la TabBar ─────────────────────────────────────

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  const _SliverTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate old) => false;
}
