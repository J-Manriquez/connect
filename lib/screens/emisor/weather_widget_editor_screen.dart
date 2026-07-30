import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:connect/screens/emisor/widget_editor_screen.dart' show showWidgetColorPicker;
import 'package:connect/widgets/widget_icon_picker.dart';
import 'package:connect/services/weather_widget_config_service.dart';
import 'package:connect/widgets/weather_widget.dart';

/// Editor de personalización del widget de clima. Mismo contrato que el editor
/// de los widgets de música: preview en vivo fija arriba, pestañas de
/// secciones, persistencia en `onChangeEnd` y botón de restablecer.
class WeatherWidgetEditorScreen extends StatefulWidget {
  const WeatherWidgetEditorScreen({super.key});

  @override
  State<WeatherWidgetEditorScreen> createState() =>
      _WeatherWidgetEditorScreenState();
}

class _WeatherWidgetEditorScreenState extends State<WeatherWidgetEditorScreen> {
  final GlobalKey<WeatherWidgetState> _previewKey =
      GlobalKey<WeatherWidgetState>();
  WeatherWidgetConfig? _cfg;

  // ── Estado del modo test ──
  bool _testRunning = false;
  int _testWeatherIdx = 0;
  int _testSeqIdx = 0;
  Timer? _testTimer;

  static const _testWeathers = [
    (emoji: '☀️', label: 'Despejado', code: 0, isDay: true),
    (emoji: '🌙', label: 'Noche', code: 0, isDay: false),
    (emoji: '☁️', label: 'Nubes', code: 3, isDay: true),
    (emoji: '🌫️', label: 'Niebla', code: 45, isDay: true),
    (emoji: '🌧️', label: 'Lluvia', code: 61, isDay: true),
    (emoji: '❄️', label: 'Nieve', code: 71, isDay: true),
    (emoji: '⛈️', label: 'Tormenta', code: 95, isDay: true),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _testTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final cfg = await WeatherWidgetConfigService.load();
    if (!mounted) return;
    setState(() => _cfg = cfg);
  }

  Future<void> _setInt(String prop, int value) =>
      WeatherWidgetConfigService.setInt(prop, value);
  Future<void> _setBool(String prop, bool value) =>
      WeatherWidgetConfigService.setBool(prop, value);

  /// Tras persistir, recarga la preview (lee la config recién guardada).
  void _refreshPreview() => _previewKey.currentState?.reload();

  // ── Modo test ──

  static double _testCycleDuration(String cat, bool isDay) {
    switch (cat) {
      case 'rain': case 'thunder': return 2.0;
      case 'snow': return 5.0;
      case 'fog': return 6.0;
      case 'clouds': return 8.0;
      default: return isDay ? 4.0 : 3.0;
    }
  }

  static String _testCategory(int code) {
    if (code <= 2) return 'clear';
    if (code == 3) return 'clouds';
    if (code == 45 || code == 48) return 'fog';
    if (code >= 51 && code <= 67) return 'rain';
    if (code >= 71 && code <= 77) return 'snow';
    if (code >= 80 && code <= 82) return 'rain';
    if (code >= 85 && code <= 86) return 'snow';
    if (code >= 95) return 'thunder';
    return 'clear';
  }

  static List<int> _testBuildSequence(int n, int loopMode) {
    if (n <= 1) return [0];
    if (loopMode == 1) return List.generate(n, (i) => i);
    return [
      ...List.generate(n, (i) => i),
      ...List.generate(n - 2, (i) => n - 2 - i),
    ];
  }

  double _testTForSeqIdx(int seqIdx, WeatherWidgetConfig cfg) {
    final w = _testWeathers[_testWeatherIdx];
    final n = cfg.animFrameCount;
    final seq = _testBuildSequence(n, cfg.animLoopMode);
    final frameIdx = seq[seqIdx % seq.length];
    final cycle = _testCycleDuration(_testCategory(w.code), w.isDay);
    return n <= 1 ? 0 : (frameIdx / n) * cycle;
  }

  void _testToggle(WeatherWidgetConfig cfg) {
    if (_testRunning) {
      _testStop();
    } else {
      _testStart(cfg);
    }
  }

  void _testStart(WeatherWidgetConfig cfg) {
    _testTimer?.cancel();
    setState(() {
      _testRunning = true;
      _testSeqIdx = 0;
    });
    final w = _testWeathers[_testWeatherIdx];
    _previewKey.currentState?.setTestBackground(
        w.code, w.isDay, _testTForSeqIdx(0, cfg));
    _testTimer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      if (!mounted) return;
      setState(() => _testSeqIdx++);
      final t = _testTForSeqIdx(_testSeqIdx, cfg);
      _previewKey.currentState?.setTestBackground(w.code, w.isDay, t);
    });
  }

  void _testStop() {
    _testTimer?.cancel();
    _testTimer = null;
    setState(() {
      _testRunning = false;
      _testSeqIdx = 0;
    });
    _previewKey.currentState?.setTestBackground(null, true, null);
  }

  void _testSelectWeather(int idx, WeatherWidgetConfig cfg) {
    setState(() => _testWeatherIdx = idx);
    if (_testRunning) {
      _testStop();
      _testStart(cfg);
    } else {
      // Actualiza el fondo del preview sin animar (frame 0 del clima elegido).
      final w = _testWeathers[idx];
      _previewKey.currentState?.setTestBackground(
          w.code, w.isDay, _testTForSeqIdx(0, cfg));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cfg = _cfg;
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Personalizar widget de clima'),
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
                  SliverToBoxAdapter(child: _previewArea()),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _SliverTabBarDelegate(
                      const TabBar(
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        tabs: [
                          Tab(text: 'Tamaño'),
                          Tab(text: 'Colores'),
                          Tab(text: 'Fondo'),
                          Tab(text: 'Indicadores'),
                          Tab(text: 'Iconos'),
                          Tab(text: 'Animación'),
                        ],
                      ),
                    ),
                  ),
                ],
                body: TabBarView(
                  children: [
                    _tabPage([_headerSizeSection(cfg), _currentSizeSection(cfg), _rowSizeSection(cfg)]),
                    _tabPage([_headerColorSection(cfg), _currentColorSection(cfg), _rowColorSection(cfg)]),
                    _tabPage([_backgroundSection(cfg)]),
                    _tabPage([_indicatorsSection(cfg)]),
                    _tabPage([_iconsSection(cfg)]),
                    _tabPage([_animSection(cfg)]),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _tabPage(List<Widget> children) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: children,
    );
  }

  Widget _previewArea() {
    return Container(
      width: double.infinity,
      color: Colors.grey.shade100,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: Column(
        children: [
          WeatherWidget(key: _previewKey),
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Vista previa',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  // ===== Secciones =====

  Widget _card(String title, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            ...children,
          ],
        ),
      ),
    );
  }

  // --- Tamaño ---

  Widget _headerSizeSection(WeatherWidgetConfig cfg) {
    return _card('Cabecera', [
      _sliderTile(
        label: 'Tamaño del nombre de ciudad',
        value: cfg.cityLabelSizeSp.toDouble(),
        min: 10,
        max: 28,
        divisions: 18,
        display: '${cfg.cityLabelSizeSp}sp',
        onChanged: (v) => setState(() => cfg.cityLabelSizeSp = v.round()),
        onChangeEnd: (v) async {
          await _setInt('city_label_size_sp', v.round());
          _refreshPreview();
        },
      ),
      _sliderTile(
        label: 'Tamaño de la etiqueta de vista',
        value: cfg.viewLabelSizeSp.toDouble(),
        min: 8,
        max: 20,
        divisions: 12,
        display: '${cfg.viewLabelSizeSp}sp',
        onChanged: (v) => setState(() => cfg.viewLabelSizeSp = v.round()),
        onChangeEnd: (v) async {
          await _setInt('view_label_size_sp', v.round());
          _refreshPreview();
        },
      ),
    ]);
  }

  Widget _currentSizeSection(WeatherWidgetConfig cfg) {
    return _card('Vista "Ahora"', [
      _sliderTile(
        label: 'Tamaño de la temperatura',
        value: cfg.tempSizeSp.toDouble(),
        min: 24,
        max: 72,
        divisions: 48,
        display: '${cfg.tempSizeSp}sp',
        onChanged: (v) => setState(() => cfg.tempSizeSp = v.round()),
        onChangeEnd: (v) async {
          await _setInt('temp_size_sp', v.round());
          _refreshPreview();
        },
      ),
      _sliderTile(
        label: 'Tamaño del emoji/icono',
        value: cfg.emojiSizeSp.toDouble(),
        min: 24,
        max: 80,
        divisions: 56,
        display: '${cfg.emojiSizeSp}sp',
        onChanged: (v) => setState(() => cfg.emojiSizeSp = v.round()),
        onChangeEnd: (v) async {
          await _setInt('emoji_size_sp', v.round());
          _refreshPreview();
        },
      ),
      _sliderTile(
        label: 'Tamaño de la descripción',
        value: cfg.descSizeSp.toDouble(),
        min: 10,
        max: 28,
        divisions: 18,
        display: '${cfg.descSizeSp}sp',
        onChanged: (v) => setState(() => cfg.descSizeSp = v.round()),
        onChangeEnd: (v) async {
          await _setInt('desc_size_sp', v.round());
          _refreshPreview();
        },
      ),
      _sliderTile(
        label: 'Tamaño de "Sensación"',
        value: cfg.apparentSizeSp.toDouble(),
        min: 9,
        max: 22,
        divisions: 13,
        display: '${cfg.apparentSizeSp}sp',
        onChanged: (v) => setState(() => cfg.apparentSizeSp = v.round()),
        onChangeEnd: (v) async {
          await _setInt('apparent_size_sp', v.round());
          _refreshPreview();
        },
      ),
      _sliderTile(
        label: 'Tamaño de humedad / viento',
        value: cfg.statSizeSp.toDouble(),
        min: 9,
        max: 22,
        divisions: 13,
        display: '${cfg.statSizeSp}sp',
        onChanged: (v) => setState(() => cfg.statSizeSp = v.round()),
        onChangeEnd: (v) async {
          await _setInt('stat_size_sp', v.round());
          _refreshPreview();
        },
      ),
    ]);
  }

  Widget _rowSizeSection(WeatherWidgetConfig cfg) {
    return _card('Filas (Por horas / Por días)', [
      _sliderTile(
        label: 'Tamaño de la etiqueta (hora/día)',
        value: cfg.rowLabelSizeSp.toDouble(),
        min: 9,
        max: 20,
        divisions: 11,
        display: '${cfg.rowLabelSizeSp}sp',
        onChanged: (v) => setState(() => cfg.rowLabelSizeSp = v.round()),
        onChangeEnd: (v) async {
          await _setInt('row_label_size_sp', v.round());
          _refreshPreview();
        },
      ),
      _sliderTile(
        label: 'Tamaño del icono por fila',
        value: cfg.rowEmojiSizeSp.toDouble(),
        min: 12,
        max: 32,
        divisions: 20,
        display: '${cfg.rowEmojiSizeSp}sp',
        onChanged: (v) => setState(() => cfg.rowEmojiSizeSp = v.round()),
        onChangeEnd: (v) async {
          await _setInt('row_emoji_size_sp', v.round());
          _refreshPreview();
        },
      ),
      _sliderTile(
        label: 'Tamaño del valor (temperatura)',
        value: cfg.rowValueSizeSp.toDouble(),
        min: 10,
        max: 24,
        divisions: 14,
        display: '${cfg.rowValueSizeSp}sp',
        onChanged: (v) => setState(() => cfg.rowValueSizeSp = v.round()),
        onChangeEnd: (v) async {
          await _setInt('row_value_size_sp', v.round());
          _refreshPreview();
        },
      ),
      _sliderTile(
        label: 'Tamaño de probabilidad de lluvia',
        value: cfg.rowPpSizeSp.toDouble(),
        min: 8,
        max: 18,
        divisions: 10,
        display: '${cfg.rowPpSizeSp}sp',
        onChanged: (v) => setState(() => cfg.rowPpSizeSp = v.round()),
        onChangeEnd: (v) async {
          await _setInt('row_pp_size_sp', v.round());
          _refreshPreview();
        },
      ),
      _sliderTile(
        label: 'Espacio entre filas',
        value: cfg.rowSpacingDp.toDouble(),
        min: 0,
        max: 16,
        divisions: 16,
        display: '${cfg.rowSpacingDp}dp',
        onChanged: (v) => setState(() => cfg.rowSpacingDp = v.round()),
        onChangeEnd: (v) async {
          await _setInt('row_spacing_dp', v.round());
          _refreshPreview();
        },
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: const Text('Valor en negrita'),
        value: cfg.rowValueBold,
        onChanged: (v) async {
          setState(() => cfg.rowValueBold = v);
          await _setBool('row_value_bold', v);
          _refreshPreview();
        },
      ),
    ]);
  }

  // --- Colores ---

  Widget _headerColorSection(WeatherWidgetConfig cfg) {
    return _card('Cabecera', [
      _colorTile(
        label: 'Color del nombre de ciudad',
        argb: cfg.cityLabelColorArgb,
        withAlpha: false,
        onPicked: (v) async {
          setState(() => cfg.cityLabelColorArgb = v);
          await _setInt('city_label_color_argb', v);
          _refreshPreview();
        },
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: const Text('Nombre de ciudad en negrita'),
        value: cfg.cityLabelBold,
        onChanged: (v) async {
          setState(() => cfg.cityLabelBold = v);
          await _setBool('city_label_bold', v);
          _refreshPreview();
        },
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: const Text('Mostrar pin de ubicación 📍'),
        value: cfg.showLocationPin,
        onChanged: (v) async {
          setState(() => cfg.showLocationPin = v);
          await _setBool('show_location_pin', v);
          _refreshPreview();
        },
      ),
      _colorTile(
        label: 'Color de la etiqueta de vista',
        argb: cfg.viewLabelColorArgb,
        withAlpha: true,
        onPicked: (v) async {
          setState(() => cfg.viewLabelColorArgb = v);
          await _setInt('view_label_color_argb', v);
          _refreshPreview();
        },
      ),
    ]);
  }

  Widget _currentColorSection(WeatherWidgetConfig cfg) {
    return _card('Vista "Ahora"', [
      _colorTile(
        label: 'Color de la temperatura',
        argb: cfg.tempColorArgb,
        withAlpha: false,
        onPicked: (v) async {
          setState(() => cfg.tempColorArgb = v);
          await _setInt('temp_color_argb', v);
          _refreshPreview();
        },
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: const Text('Temperatura en negrita'),
        value: cfg.tempBold,
        onChanged: (v) async {
          setState(() => cfg.tempBold = v);
          await _setBool('temp_bold', v);
          _refreshPreview();
        },
      ),
      _colorTile(
        label: 'Color de la descripción',
        argb: cfg.descColorArgb,
        withAlpha: false,
        onPicked: (v) async {
          setState(() => cfg.descColorArgb = v);
          await _setInt('desc_color_argb', v);
          _refreshPreview();
        },
      ),
      _colorTile(
        label: 'Color de "Sensación"',
        argb: cfg.apparentColorArgb,
        withAlpha: true,
        onPicked: (v) async {
          setState(() => cfg.apparentColorArgb = v);
          await _setInt('apparent_color_argb', v);
          _refreshPreview();
        },
      ),
      _colorTile(
        label: 'Color de humedad / viento',
        argb: cfg.statColorArgb,
        withAlpha: false,
        onPicked: (v) async {
          setState(() => cfg.statColorArgb = v);
          await _setInt('stat_color_argb', v);
          _refreshPreview();
        },
      ),
    ]);
  }

  Widget _rowColorSection(WeatherWidgetConfig cfg) {
    return _card('Filas (Por horas / Por días)', [
      _colorTile(
        label: 'Color de la etiqueta (hora/día)',
        argb: cfg.rowLabelColorArgb,
        withAlpha: false,
        onPicked: (v) async {
          setState(() => cfg.rowLabelColorArgb = v);
          await _setInt('row_label_color_argb', v);
          _refreshPreview();
        },
      ),
      _colorTile(
        label: 'Color del valor (temperatura)',
        argb: cfg.rowValueColorArgb,
        withAlpha: false,
        onPicked: (v) async {
          setState(() => cfg.rowValueColorArgb = v);
          await _setInt('row_value_color_argb', v);
          _refreshPreview();
        },
      ),
      _colorTile(
        label: 'Color de probabilidad de lluvia',
        argb: cfg.rowPpColorArgb,
        withAlpha: false,
        onPicked: (v) async {
          setState(() => cfg.rowPpColorArgb = v);
          await _setInt('row_pp_color_argb', v);
          _refreshPreview();
        },
      ),
    ]);
  }

  // --- Fondo ---

  Widget _backgroundSection(WeatherWidgetConfig cfg) {
    return _card('Fondo', [
      const Text(
        'El modo dinámico imita el clima real (nubes, lluvia, niebla, sol, '
        'nieve, tormenta) y cambia de día/noche automáticamente.',
        style: TextStyle(color: Colors.grey, fontSize: 12),
      ),
      const SizedBox(height: 8),
      SegmentedButton<WeatherBgMode>(
        segments: const [
          ButtonSegment(value: WeatherBgMode.dynamic, label: Text('Dinámico')),
          ButtonSegment(value: WeatherBgMode.solid, label: Text('Sólido')),
          ButtonSegment(value: WeatherBgMode.gradient, label: Text('Degradado')),
        ],
        selected: {cfg.bgMode},
        onSelectionChanged: (selection) async {
          final mode = selection.first;
          setState(() => cfg.bgMode = mode);
          await _setInt('bg_mode', mode.index);
          _refreshPreview();
        },
      ),
      if (cfg.bgMode == WeatherBgMode.dynamic)
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: const Text('Animación'),
          subtitle: const Text(
            'Desactívala para un degradado fijo (solo afecta a la app; el '
            'widget de la pantalla de inicio siempre es estático).',
          ),
          value: cfg.animatedBgEnabled,
          onChanged: (v) async {
            setState(() => cfg.animatedBgEnabled = v);
            await _setBool('animated_bg_enabled', v);
            _refreshPreview();
          },
        ),
      if (cfg.bgMode == WeatherBgMode.solid)
        _colorTile(
          label: 'Color de fondo',
          argb: cfg.bgSolidArgb,
          withAlpha: false,
          onPicked: (v) async {
            setState(() => cfg.bgSolidArgb = v);
            await _setInt('bg_solid_argb', v);
            _refreshPreview();
          },
        ),
      if (cfg.bgMode == WeatherBgMode.gradient) ...[
        _colorTile(
          label: 'Color superior',
          argb: cfg.bgGradientTopArgb,
          withAlpha: false,
          onPicked: (v) async {
            setState(() => cfg.bgGradientTopArgb = v);
            await _setInt('bg_gradient_top_argb', v);
            _refreshPreview();
          },
        ),
        _colorTile(
          label: 'Color inferior',
          argb: cfg.bgGradientBottomArgb,
          withAlpha: false,
          onPicked: (v) async {
            setState(() => cfg.bgGradientBottomArgb = v);
            await _setInt('bg_gradient_bottom_argb', v);
            _refreshPreview();
          },
        ),
      ],
      _sliderTile(
        label: 'Oscurecer el fondo',
        value: cfg.bgDarkenPct.toDouble(),
        min: 0,
        max: 80,
        divisions: 16,
        display: '${cfg.bgDarkenPct}%',
        onChanged: (v) => setState(() => cfg.bgDarkenPct = v.round()),
        onChangeEnd: (v) async {
          await _setInt('bg_darken_pct', v.round());
          _refreshPreview();
        },
      ),
      _sliderTile(
        label: 'Radio de las esquinas',
        value: cfg.cornerRadiusDp.toDouble(),
        min: 0,
        max: 32,
        divisions: 32,
        display: '${cfg.cornerRadiusDp}dp',
        onChanged: (v) => setState(() => cfg.cornerRadiusDp = v.round()),
        onChangeEnd: (v) async {
          await _setInt('corner_radius_dp', v.round());
          _refreshPreview();
        },
      ),
    ]);
  }

  // --- Indicadores ---

  Widget _indicatorsSection(WeatherWidgetConfig cfg) {
    return _card('Indicadores de página', [
      _colorTile(
        label: 'Color activo',
        argb: cfg.dotActiveColorArgb,
        withAlpha: false,
        onPicked: (v) async {
          setState(() => cfg.dotActiveColorArgb = v);
          await _setInt('dot_active_color_argb', v);
          _refreshPreview();
        },
      ),
      _colorTile(
        label: 'Color inactivo',
        argb: cfg.dotInactiveColorArgb,
        withAlpha: true,
        onPicked: (v) async {
          setState(() => cfg.dotInactiveColorArgb = v);
          await _setInt('dot_inactive_color_argb', v);
          _refreshPreview();
        },
      ),
      _sliderTile(
        label: 'Tamaño de los puntos',
        value: cfg.dotSizeDp.toDouble(),
        min: 3,
        max: 12,
        divisions: 9,
        display: '${cfg.dotSizeDp}dp',
        onChanged: (v) => setState(() => cfg.dotSizeDp = v.round()),
        onChangeEnd: (v) async {
          await _setInt('dot_size_dp', v.round());
          _refreshPreview();
        },
      ),
      const Divider(),
      const Text(
        'Las flechas ◀ ▶ y ▲ ▼ aparecen tanto en la app como en el widget '
        'de la pantalla de inicio.',
        style: TextStyle(color: Colors.grey, fontSize: 12),
      ),
      _sliderTile(
        label: 'Tamaño de las flechas ◀ ▶',
        value: cfg.arrowSizeSp.toDouble(),
        min: 10,
        max: 28,
        divisions: 18,
        display: '${cfg.arrowSizeSp}sp',
        onChanged: (v) => setState(() => cfg.arrowSizeSp = v.round()),
        onChangeEnd: (v) async {
          await _setInt('arrow_size_sp', v.round());
          _refreshPreview();
        },
      ),
      _sliderTile(
        label: 'Tamaño de las flechas ▲ ▼ (listas)',
        value: cfg.scrollArrowSizeSp.toDouble(),
        min: 10,
        max: 28,
        divisions: 18,
        display: '${cfg.scrollArrowSizeSp}sp',
        onChanged: (v) => setState(() => cfg.scrollArrowSizeSp = v.round()),
        onChangeEnd: (v) async {
          await _setInt('scroll_arrow_size_sp', v.round());
          _refreshPreview();
        },
      ),
      _colorTile(
        label: 'Color de las flechas ◀ ▶ ▲ ▼',
        argb: cfg.arrowColorArgb,
        withAlpha: false,
        onPicked: (v) async {
          setState(() => cfg.arrowColorArgb = v);
          await _setInt('arrow_color_argb', v);
          _refreshPreview();
        },
      ),
      const Divider(),
      const Text(
        'Iconos de las flechas (solo en la app)',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 4),
      _iconTile(label: '◀  Anterior', category: 'arrow_prev', cfg: cfg,
          defaultLabel: '◀', arrowField: true),
      _iconTile(label: '▶  Siguiente', category: 'arrow_next', cfg: cfg,
          defaultLabel: '▶', arrowField: true),
      _iconTile(label: '▲  Subir lista', category: 'arrow_up', cfg: cfg,
          defaultLabel: '▲', arrowField: true),
      _iconTile(label: '▼  Bajar lista', category: 'arrow_down', cfg: cfg,
          defaultLabel: '▼', arrowField: true),
    ]);
  }

  // --- Iconos ---

  static const _iconCategories = <String, String>{
    'clear_day': 'Sol (día despejado)',
    'clear_night': 'Luna (noche despejada)',
    'clouds': 'Nubes',
    'fog': 'Niebla',
    'rain': 'Lluvia',
    'snow': 'Nieve',
    'thunder': 'Tormenta',
  };

  static const _iconDefaults = <String, IconData>{
    'clear_day': Icons.wb_sunny,
    'clear_night': Icons.nightlight_round,
    'clouds': Icons.cloud,
    'fog': Icons.foggy,
    'rain': Icons.umbrella,
    'snow': Icons.ac_unit,
    'thunder': Icons.thunderstorm,
  };

  String? _iconPngOf(WeatherWidgetConfig cfg, String cat) => switch (cat) {
        'clear_day' => cfg.iconClearDayPng,
        'clear_night' => cfg.iconClearNightPng,
        'clouds' => cfg.iconCloudsPng,
        'fog' => cfg.iconFogPng,
        'rain' => cfg.iconRainPng,
        'snow' => cfg.iconSnowPng,
        'thunder' => cfg.iconThunderPng,
        _ => null,
      };

  void _setIconOnCfg(WeatherWidgetConfig cfg, String cat, String? png) {
    switch (cat) {
      case 'clear_day':
        cfg.iconClearDayPng = png;
      case 'clear_night':
        cfg.iconClearNightPng = png;
      case 'clouds':
        cfg.iconCloudsPng = png;
      case 'fog':
        cfg.iconFogPng = png;
      case 'rain':
        cfg.iconRainPng = png;
      case 'snow':
        cfg.iconSnowPng = png;
      case 'thunder':
        cfg.iconThunderPng = png;
      case 'arrow_prev':
        cfg.arrowPrevPng = png;
      case 'arrow_next':
        cfg.arrowNextPng = png;
      case 'arrow_up':
        cfg.arrowUpPng = png;
      case 'arrow_down':
        cfg.arrowDownPng = png;
      default:
        break;
    }
  }

  String? _arrowPngOf(WeatherWidgetConfig cfg, String cat) => switch (cat) {
        'arrow_prev' => cfg.arrowPrevPng,
        'arrow_next' => cfg.arrowNextPng,
        'arrow_up' => cfg.arrowUpPng,
        'arrow_down' => cfg.arrowDownPng,
        _ => null,
      };

  Widget _iconsSection(WeatherWidgetConfig cfg) {
    return _card('Iconos del clima', [
      const Text(
        'Elige un icono SVG o de la galería para cada condición. '
        'Los iconos personalizados se muestran en la app. '
        'El widget de la pantalla de inicio siempre usa emojis de texto.',
        style: TextStyle(color: Colors.grey, fontSize: 12),
      ),
      const SizedBox(height: 4),
      ..._iconCategories.entries.map(
        (e) => _iconTile(label: e.value, category: e.key, cfg: cfg),
      ),
    ]);
  }

  Widget _iconTile({
    required String label,
    required String category,
    required WeatherWidgetConfig cfg,
    String? defaultLabel,
    bool arrowField = false,
  }) {
    final pngB64 = arrowField ? _arrowPngOf(cfg, category) : _iconPngOf(cfg, category);
    Widget preview;
    if (pngB64 != null && pngB64.isNotEmpty) {
      try {
        final bytes = base64Decode(pngB64.replaceAll(RegExp(r'\s+'), ''));
        preview = Image.memory(bytes, fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _iconTileDefault(category, defaultLabel));
      } catch (_) {
        preview = _iconTileDefault(category, defaultLabel);
      }
    } else {
      preview = _iconTileDefault(category, defaultLabel);
    }
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(6),
        child: preview,
      ),
      title: Text(label),
      subtitle: Text(pngB64 != null && pngB64.isNotEmpty ? 'Personalizado' : 'Por defecto'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _openIconPicker(category, pngB64, cfg),
    );
  }

  Widget _iconTileDefault(String category, String? label) {
    if (label != null) {
      return Center(
        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 20)),
      );
    }
    final icon = _iconDefaults[category];
    return Icon(icon ?? Icons.image_not_supported, color: Colors.white, size: 24);
  }

  Future<void> _openIconPicker(
      String category, String? currentPng, WeatherWidgetConfig cfg) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => WidgetIconPickerScreen(
          title: _iconCategories[category] ?? category,
          currentOverrideBase64: currentPng,
        ),
      ),
    );
    if (result == null || !mounted) return;
    final isArrow = category.startsWith('arrow_');
    if (result['action'] == 'use_default') {
      if (isArrow) {
        await WeatherWidgetConfigService.clearArrow(category);
      } else {
        await WeatherWidgetConfigService.clearIcon(category);
      }
      setState(() => _setIconOnCfg(cfg, category, null));
    } else if (result['action'] == 'override') {
      final png = result['pngBase64'] as String?;
      if (png != null && png.isNotEmpty) {
        if (isArrow) {
          await WeatherWidgetConfigService.setArrow(category, png);
        } else {
          await WeatherWidgetConfigService.setIcon(category, png);
        }
        setState(() => _setIconOnCfg(cfg, category, png));
      }
    }
    _refreshPreview();
  }

  // --- Animación (widget nativo) ---

  Widget _animSection(WeatherWidgetConfig cfg) {
    return _card('Animación del widget de inicio', [
      const Text(
        'Solo aplica en modo fondo dinámico. Con 1 frame el fondo es estático. '
        'Los frames se generan automáticamente al actualizar el clima.',
        style: TextStyle(color: Colors.grey, fontSize: 12),
      ),
      const SizedBox(height: 8),
      _sliderTile(
        label: 'Frames de animación',
        value: cfg.animFrameCount.toDouble(),
        min: 1,
        max: 36,
        divisions: 35,
        display: cfg.animFrameCount == 1
            ? '1 (estático)'
            : '${cfg.animFrameCount} frames',
        onChanged: (v) => setState(() => cfg.animFrameCount = v.round()),
        onChangeEnd: (v) async {
          await _setInt('anim_frame_count', v.round());
          _refreshPreview();
        },
      ),
      const SizedBox(height: 12),
      // Modo de secuencia
      const Text('Modo de secuencia', style: TextStyle(fontSize: 13)),
      const SizedBox(height: 6),
      SegmentedButton<int>(
        segments: const [
          ButtonSegment(value: 0, label: Text('Ping-pong'), icon: Icon(Icons.swap_horiz, size: 16)),
          ButtonSegment(value: 1, label: Text('Loop'), icon: Icon(Icons.loop, size: 16)),
        ],
        selected: {cfg.animLoopMode},
        onSelectionChanged: (s) async {
          final v = s.first;
          setState(() => cfg.animLoopMode = v);
          await _setInt('anim_loop_mode', v);
          _refreshPreview();
        },
      ),
      const SizedBox(height: 4),
      Text(
        cfg.animLoopMode == 0
            ? 'Ping-pong: reproduce hacia adelante y luego hacia atrás (1-2-3-2-1).'
            : 'Loop: reproduce siempre hacia adelante en ciclo (1-2-3-1-2-3).',
        style: const TextStyle(color: Colors.grey, fontSize: 11),
      ),
      const SizedBox(height: 12),
      // Trigger de animación
      const Text('Disparador de animación', style: TextStyle(fontSize: 13)),
      const SizedBox(height: 6),
      SegmentedButton<int>(
        segments: const [
          ButtonSegment(value: 0, label: Text('Toque'), icon: Icon(Icons.touch_app, size: 16)),
          ButtonSegment(value: 1, label: Text('Al encender'), icon: Icon(Icons.brightness_high, size: 16)),
          ButtonSegment(value: 2, label: Text('Ambos'), icon: Icon(Icons.all_inclusive, size: 16)),
        ],
        selected: {cfg.animTrigger},
        onSelectionChanged: (s) async {
          final v = s.first;
          setState(() => cfg.animTrigger = v);
          await _setInt('anim_trigger', v);
          _refreshPreview();
        },
      ),
      const SizedBox(height: 4),
      Text(
        cfg.animTrigger == 0
            ? 'La animación se inicia al tocar el widget o sus flechas de navegación.'
            : cfg.animTrigger == 1
                ? 'La animación se inicia cuando se enciende la pantalla o se desbloquea el dispositivo. '
                  'Android no permite detectar cambios de página del launcher.'
                : 'La animación se inicia al tocar el widget Y al encender la pantalla.',
        style: const TextStyle(color: Colors.grey, fontSize: 11),
      ),
      // ── Modo test ──
      const SizedBox(height: 4),
      _testCard(cfg),
    ]);
  }

  Widget _testCard(WeatherWidgetConfig cfg) {
    final n = cfg.animFrameCount;
    final seq = _testBuildSequence(n, cfg.animLoopMode);
    final frameIdx = seq.isEmpty ? 0 : seq[_testSeqIdx % seq.length];

    return Card(
      margin: const EdgeInsets.only(top: 6),
      color: Theme.of(context).colorScheme.surfaceContainerHighest
          .withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.play_circle_outline, size: 18),
                const SizedBox(width: 6),
                const Text('Modo test',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                const Spacer(),
                if (_testRunning)
                  Text(
                    'Frame ${frameIdx + 1} / $n',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'La animación se reproduce en el widget de previsualización de arriba.',
              style: TextStyle(color: Colors.grey, fontSize: 11),
            ),
            const SizedBox(height: 10),
            const Text('Clima a visualizar:',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: List.generate(_testWeathers.length, (i) {
                final w = _testWeathers[i];
                final selected = i == _testWeatherIdx;
                return GestureDetector(
                  onTap: () => _testSelectWeather(i, cfg),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey.shade300,
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Text(
                      '${w.emoji} ${w.label}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: selected
                            ? Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer
                            : null,
                      ),
                    ),
                  ),
                );
              }),
            ),
            if (_testRunning) ...[
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: seq.isEmpty
                    ? 0
                    : (_testSeqIdx % seq.length) / seq.length,
                minHeight: 4,
                borderRadius: BorderRadius.circular(2),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: n <= 1 ? null : () => _testToggle(cfg),
                icon: Icon(_testRunning
                    ? Icons.stop_rounded
                    : Icons.play_arrow_rounded),
                label: Text(_testRunning
                    ? 'Detener test'
                    : 'Iniciar test en el widget'),
                style: _testRunning
                    ? FilledButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).colorScheme.error,
                        foregroundColor:
                            Theme.of(context).colorScheme.onError,
                      )
                    : null,
              ),
            ),
            if (n <= 1)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Aumenta el número de frames para activar el modo test.',
                  style: TextStyle(
                      color: Colors.grey.shade500, fontSize: 11),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ===== Controles reutilizables =====

  Widget _sliderTile({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String display,
    required ValueChanged<double> onChanged,
    required ValueChanged<double> onChangeEnd,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: Text(label)),
              Text(display, style: const TextStyle(color: Colors.grey)),
            ],
          ),
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
          onChangeEnd: onChangeEnd,
        ),
      ],
    );
  }

  Widget _colorTile({
    required String label,
    required int argb,
    required bool withAlpha,
    required ValueChanged<int> onPicked,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(
        '#${argb.toRadixString(16).padLeft(8, '0').toUpperCase()}',
        style: const TextStyle(color: Colors.grey, fontSize: 12),
      ),
      trailing: Container(
        width: 36,
        height: 28,
        decoration: BoxDecoration(
          color: Color(argb),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.black38),
        ),
      ),
      onTap: () async {
        final picked = await showWidgetColorPicker(
          context,
          initialArgb: argb,
          withAlpha: withAlpha,
        );
        if (picked != null) onPicked(picked);
      },
    );
  }

  Future<void> _confirmReset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restablecer widget de clima'),
        content: const Text(
            'Se borrará toda la personalización del widget de clima y volverá a sus valores por defecto. ¿Continuar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restablecer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await WeatherWidgetConfigService.resetAll();
    await _load();
    _refreshPreview();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
/// Mantiene el [TabBar] fijo bajo la vista previa mientras el resto se desplaza.
class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _SliverTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      elevation: overlapsContent ? 2 : 0,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) =>
      tabBar != oldDelegate.tabBar;
}
