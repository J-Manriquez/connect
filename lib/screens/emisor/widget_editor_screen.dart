import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:connect/services/ble_service.dart';
import 'package:connect/services/widget_config_service.dart';
import 'package:connect/widgets/color_input_widget.dart';
import 'package:connect/widgets/widget_default_app_icon_picker.dart';
import 'package:connect/widgets/widget_icon_picker.dart';
import 'package:connect/widgets/widget_music_preview.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Editor de un widget de música. Lee/escribe la configuración con
/// [WidgetConfigService]; cada cambio refresca el widget local del dispositivo.
class WidgetEditorScreen extends StatefulWidget {
  final WidgetConfigSpec spec;

  const WidgetEditorScreen({super.key, required this.spec});

  @override
  State<WidgetEditorScreen> createState() => _WidgetEditorScreenState();
}

class _WidgetEditorScreenState extends State<WidgetEditorScreen> {
  WidgetConfig? _cfg;
  final TextEditingController _noMediaTitleCtrl = TextEditingController();
  final TextEditingController _noMediaSubtitleCtrl = TextEditingController();
  Timer? _textDebounce;

  // Icono del botón "abrir app de música por defecto" (solo widget centrado).
  // Usa las mismas claves globales que lee el lado nativo (applyDefaultAppIcon).
  static const String _kAppBtnOverride = 'media_default_app_widget2_icon_base64';
  static const String _kAppBtnSource = 'media_default_app_widget2_icon_source';
  static const String _kAppBtnSvgPath = 'media_default_app_widget2_icon_svg_path';
  static const String _kAppBtnSvgColor =
      'media_default_app_widget2_icon_svg_color_argb';
  static const String _kAppBtnSvgSize =
      'media_default_app_widget2_icon_svg_size_px';
  static const String _kDefaultAppIcon = 'media_default_app_icon_base64';

  String? _appBtnOverrideB64;
  String _appBtnSource = '';
  String? _appBtnSvgPath;
  int _appBtnSvgColorArgb = 0xFFFFFFFF;
  int _appBtnSvgSizePx = 128;
  String? _defaultAppIconB64;

  bool _previewNoMedia = false;

  WidgetConfigSpec get spec => widget.spec;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _textDebounce?.cancel();
    _noMediaTitleCtrl.dispose();
    _noMediaSubtitleCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final cfg = await WidgetConfigService.load(spec);
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _cfg = cfg;
      _noMediaTitleCtrl.text = cfg.noMediaTitle;
      _noMediaSubtitleCtrl.text = cfg.noMediaSubtitle;
      if (spec.hasDefaultAppButton) {
        final ov = p.getString(_kAppBtnOverride)?.trim();
        _appBtnOverrideB64 = (ov == null || ov.isEmpty) ? null : ov;
        _appBtnSource = (p.getString(_kAppBtnSource) ?? '').trim();
        final sp = (p.getString(_kAppBtnSvgPath) ?? '').trim();
        _appBtnSvgPath = sp.isEmpty ? null : sp;
        _appBtnSvgColorArgb = p.getInt(_kAppBtnSvgColor) ?? 0xFFFFFFFF;
        _appBtnSvgSizePx = p.getInt(_kAppBtnSvgSize) ?? 128;
        final dai = p.getString(_kDefaultAppIcon)?.trim();
        _defaultAppIconB64 = (dai == null || dai.isEmpty) ? null : dai;
      }
    });
  }

  Future<void> _setInt(String prop, int value) =>
      WidgetConfigService.setInt(spec.id, prop, value);
  Future<void> _setBool(String prop, bool value) =>
      WidgetConfigService.setBool(spec.id, prop, value);
  Future<void> _setString(String prop, String value) =>
      WidgetConfigService.setString(spec.id, prop, value);

  void _debouncedText(String prop, String value) {
    _textDebounce?.cancel();
    _textDebounce = Timer(const Duration(milliseconds: 500), () {
      _setString(prop, value);
    });
  }

  Uint8List? _decode(String b64) {
    if (b64.trim().isEmpty) return null;
    try {
      return const Base64Decoder().convert(b64.replaceAll(RegExp(r'\s+'), ''));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cfg = _cfg;
    return DefaultTabController(
      length: 5,
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
                          Tab(text: 'Tamaño'),
                          Tab(text: 'Fondo'),
                          Tab(text: 'Iconos'),
                          Tab(text: 'Barras'),
                          Tab(text: 'Textos'),
                        ],
                      ),
                    ),
                  ),
                ],
                body: TabBarView(
                  children: [
                    _tabPage([_sizeSection(cfg)]),
                    _tabPage([_backgroundSection(cfg)]),
                    _tabPage([
                      _iconsSection(cfg),
                      if (spec.hasDefaultAppButton) _defaultAppButtonSection(),
                    ]),
                    _tabPage([_barsSection(cfg)]),
                    _tabPage([_textsSection(cfg), _noMediaSection(cfg)]),
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

  Widget _previewArea(WidgetConfig cfg) {
    final appBtnBytes =
        _decode(_appBtnOverrideB64 ?? '') ?? _decode(_defaultAppIconB64 ?? '');
    return Container(
      width: double.infinity,
      color: Colors.grey.shade100,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: Column(
        children: [
          WidgetMusicPreview(
            cfg: cfg,
            widgetId: spec.id,
            noMedia: _previewNoMedia,
            appButtonIcon: appBtnBytes,
            showDefaultApp: spec.hasDefaultAppButton && cfg.showDefaultAppBtn,
          ),
          Row(
            children: [
              const Text('Vista previa',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              const Text('Sin multimedia',
                  style: TextStyle(fontSize: 13, color: Colors.black54)),
              Switch(
                value: _previewNoMedia,
                onChanged: (v) => setState(() => _previewNoMedia = v),
              ),
            ],
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
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _sizeSection(WidgetConfig cfg) {
    return _card('Tamaño', [
      _sliderTile(
        label: 'Escala del contenido',
        value: cfg.contentScalePct.toDouble(),
        min: 50,
        max: 200,
        divisions: 30,
        display: '${cfg.contentScalePct}%',
        onChanged: (v) => setState(() => cfg.contentScalePct = v.round()),
        onChangeEnd: (v) => _setInt('content_scale_pct', v.round()),
      ),
      if (spec.hasRowSpacing)
        _sliderTile(
          label: 'Espacio entre filas',
          value: cfg.rowSpacingDp.toDouble(),
          min: 0,
          max: 48,
          divisions: 48,
          display: '${cfg.rowSpacingDp}dp',
          onChanged: (v) => setState(() => cfg.rowSpacingDp = v.round()),
          onChangeEnd: (v) => _setInt('row_spacing_dp', v.round()),
        ),
      const Text(
        'El tamaño exacto del widget en la pantalla de inicio se ajusta '
        'manteniéndolo presionado y arrastrando los bordes.',
        style: TextStyle(color: Colors.grey, fontSize: 12),
      ),
    ]);
  }

  Widget _backgroundSection(WidgetConfig cfg) {
    return _card('Fondo', [
      if (spec.hasArtBackground) ...[
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Carátula como fondo'),
          subtitle: const Text(
            'Usa la imagen del álbum como fondo completo en lugar de miniatura lateral.',
          ),
          value: cfg.artAsBackground,
          onChanged: (v) {
            setState(() => cfg.artAsBackground = v);
            _setBool('art_as_background', v);
          },
        ),
        const Divider(),
      ],
      _scaleTypeTile(cfg),
      const Divider(),
      _colorTile(
        label: 'Color de fondo (sin carátula)',
        argb: cfg.bgNoImageArgb,
        withAlpha: true,
        onPicked: (v) {
          setState(() => cfg.bgNoImageArgb = v);
          _setInt('bg_no_image_argb', v);
        },
      ),
      _colorTile(
        label: 'Velo sobre la carátula',
        argb: cfg.scrimArgb,
        withAlpha: true,
        onPicked: (v) {
          setState(() => cfg.scrimArgb = v);
          _setInt('scrim_argb', v);
        },
      ),
      _sliderTile(
        label: 'Opacidad de la carátula',
        value: cfg.artAlpha.toDouble(),
        min: 0,
        max: 255,
        divisions: 51,
        display: '${(cfg.artAlpha * 100 / 255).round()}%',
        onChanged: (v) => setState(() => cfg.artAlpha = v.round()),
        onChangeEnd: (v) => _setInt('art_alpha', v.round()),
      ),
    ]);
  }

  static const _scaleTypeOptions = [
    ('crop',    'Rellenar (recortar)',   'Rellena el espacio recortando los bordes de la imagen'),
    ('contain', 'Contener',             'Muestra la imagen completa con barras laterales/superiores'),
    ('stretch', 'Estirar',              'Estira la imagen para llenar el espacio (puede distorsionar)'),
    ('center',  'Centrar',              'Muestra la imagen a tamaño original centrada'),
    ('inside',  'Interior',             'Como contener, pero nunca amplía la imagen'),
    ('start',   'Inicio',               'Ajusta la imagen alineándola arriba/izquierda'),
    ('end',     'Final',                'Ajusta la imagen alineándola abajo/derecha'),
  ];

  Widget _scaleTypeTile(WidgetConfig cfg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ajuste de la carátula',
              style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            value: cfg.artScaleType,
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: _scaleTypeOptions.map((opt) {
              return DropdownMenuItem(
                value: opt.$1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(opt.$2, style: const TextStyle(fontSize: 14)),
                    Text(opt.$3,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.grey)),
                  ],
                ),
              );
            }).toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() => cfg.artScaleType = v);
              _setString('art_scale_type', v);
            },
          ),
        ],
      ),
    );
  }

  Widget _iconsSection(WidgetConfig cfg) {
    final colorEnabled = cfg.iconColorArgb != null;
    return _card('Iconos', [
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Pintar iconos con un color'),
        subtitle: const Text('Si está apagado, se usan los iconos originales'),
        value: colorEnabled,
        onChanged: (on) {
          setState(() => cfg.iconColorArgb = on ? (cfg.iconColorArgb ?? 0xFFFFFFFF) : null);
          if (on) {
            _setInt('icon_color_argb', cfg.iconColorArgb!);
          } else {
            WidgetConfigService.remove(spec.id, 'icon_color_argb');
          }
        },
      ),
      if (colorEnabled)
        _colorTile(
          label: 'Color de los iconos',
          argb: cfg.iconColorArgb!,
          withAlpha: false,
          onPicked: (v) {
            setState(() => cfg.iconColorArgb = v);
            _setInt('icon_color_argb', v);
          },
        ),
      _sliderTile(
        label: 'Tamaño de los iconos',
        value: cfg.iconSizeDp.toDouble(),
        min: 0,
        max: 64,
        divisions: 64,
        display: cfg.iconSizeDp == 0 ? 'Original' : '${cfg.iconSizeDp}dp',
        onChanged: (v) => setState(() => cfg.iconSizeDp = v.round()),
        onChangeEnd: (v) => _setInt('icon_size_dp', v.round()),
      ),
      const Divider(),
      _iconTile('Icono anterior', cfg.iconPrev, 'icon_prev_b64',
          (b64) => setState(() => cfg.iconPrev = b64)),
      _iconTile('Icono reproducir', cfg.iconPlay, 'icon_play_b64',
          (b64) => setState(() => cfg.iconPlay = b64)),
      _iconTile('Icono pausa', cfg.iconPause, 'icon_pause_b64',
          (b64) => setState(() => cfg.iconPause = b64)),
      _iconTile('Icono siguiente', cfg.iconNext, 'icon_next_b64',
          (b64) => setState(() => cfg.iconNext = b64)),
      _iconTile('Icono volumen', cfg.iconVolume, 'icon_volume_b64',
          (b64) => setState(() => cfg.iconVolume = b64)),
    ]);
  }

  Widget _barsSection(WidgetConfig cfg) {
    return _card('Barras de reproducción y volumen', [
      _colorTile(
        label: 'Color de la pista',
        argb: cfg.barTrackArgb,
        withAlpha: true,
        onPicked: (v) {
          setState(() => cfg.barTrackArgb = v);
          _setInt('bar_track_argb', v);
        },
      ),
      _colorTile(
        label: 'Color del relleno',
        argb: cfg.barFillArgb,
        withAlpha: true,
        onPicked: (v) {
          setState(() => cfg.barFillArgb = v);
          _setInt('bar_fill_argb', v);
        },
      ),
      _sliderTile(
        label: 'Grosor de la barra de progreso',
        value: cfg.barProgressThicknessDp.toDouble(),
        min: 1,
        max: 48,
        divisions: 47,
        display: '${cfg.barProgressThicknessDp}dp',
        onChanged: (v) =>
            setState(() => cfg.barProgressThicknessDp = v.round()),
        onChangeEnd: (v) => _setInt('bar_progress_thickness_dp', v.round()),
      ),
      _sliderTile(
        label: 'Grosor de la barra de volumen',
        value: cfg.barVolumeThicknessDp.toDouble(),
        min: 1,
        max: 48,
        divisions: 47,
        display: '${cfg.barVolumeThicknessDp}dp',
        onChanged: (v) => setState(() => cfg.barVolumeThicknessDp = v.round()),
        onChangeEnd: (v) => _setInt('bar_volume_thickness_dp', v.round()),
      ),
    ]);
  }

  Widget _textsSection(WidgetConfig cfg) {
    return _card('Textos', [
      _textGroup(
        title: 'Título',
        sizeSp: cfg.titleSizeSp,
        color: cfg.titleColor,
        bold: cfg.titleBold,
        onSize: (v) => setState(() => cfg.titleSizeSp = v),
        onSizeEnd: (v) => _setInt('title_size_sp', v),
        onColor: (v) {
          setState(() => cfg.titleColor = v);
          _setInt('title_color_argb', v);
        },
        onBold: (v) {
          setState(() => cfg.titleBold = v);
          _setBool('title_bold', v);
        },
      ),
      const Divider(),
      _textGroup(
        title: 'Subtítulo',
        sizeSp: cfg.subtitleSizeSp,
        color: cfg.subtitleColor,
        bold: cfg.subtitleBold,
        onSize: (v) => setState(() => cfg.subtitleSizeSp = v),
        onSizeEnd: (v) => _setInt('subtitle_size_sp', v),
        onColor: (v) {
          setState(() => cfg.subtitleColor = v);
          _setInt('subtitle_color_argb', v);
        },
        onBold: (v) {
          setState(() => cfg.subtitleBold = v);
          _setBool('subtitle_bold', v);
        },
      ),
      const Divider(),
      _textGroup(
        title: 'Tiempos',
        sizeSp: cfg.timeSizeSp,
        color: cfg.timeColor,
        bold: cfg.timeBold,
        onSize: (v) => setState(() => cfg.timeSizeSp = v),
        onSizeEnd: (v) => _setInt('time_size_sp', v),
        onColor: (v) {
          setState(() => cfg.timeColor = v);
          _setInt('time_color_argb', v);
        },
        onBold: (v) {
          setState(() => cfg.timeBold = v);
          _setBool('time_bold', v);
        },
      ),
    ]);
  }

  Widget _noMediaSection(WidgetConfig cfg) {
    return _card('Textos sin multimedia', [
      const Text(
        'Lo que muestra el widget cuando no hay reproducción.',
        style: TextStyle(color: Colors.grey, fontSize: 12),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: _noMediaTitleCtrl,
        decoration: const InputDecoration(
          labelText: 'Título',
          border: OutlineInputBorder(),
          isDense: true,
        ),
        onChanged: (v) => _debouncedText('no_media_title', v),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _noMediaSubtitleCtrl,
        decoration: const InputDecoration(
          labelText: 'Subtítulo',
          border: OutlineInputBorder(),
          isDense: true,
        ),
        onChanged: (v) => _debouncedText('no_media_subtitle', v),
      ),
    ]);
  }

  Widget _defaultAppButtonSection() {
    final overrideBytes = _decode(_appBtnOverrideB64 ?? '');
    final defaultBytes = _decode(_defaultAppIconB64 ?? '');
    final shownBytes = overrideBytes ?? defaultBytes;
    final modeLabel = overrideBytes != null
        ? 'Icono personalizado'
        : 'Icono de la app predeterminada';
    final cfg = _cfg!;
    return _card('Botón de app de música', [
      const Text(
        'Botón que abre la app de música por defecto seleccionada en el emisor.',
        style: TextStyle(color: Colors.grey, fontSize: 12),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Mostrar el botón'),
        subtitle: const Text('Muéstralo u ocúltalo en este widget'),
        value: cfg.showDefaultAppBtn,
        onChanged: (v) {
          setState(() => cfg.showDefaultAppBtn = v);
          _setBool('show_default_app_btn', v);
        },
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          width: 40,
          height: 40,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(8),
          ),
          child: shownBytes == null
              ? const Icon(Icons.music_note, color: Colors.white54, size: 18)
              : Image.memory(shownBytes, fit: BoxFit.contain),
        ),
        title: const Text('Seleccionar icono'),
        subtitle: Text(
          modeLabel,
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: _openDefaultAppIconPicker,
      ),
    ]);
  }

  Future<void> _openDefaultAppIconPicker() async {
    final picked = await Navigator.push<Map<String, dynamic>?>(
      context,
      MaterialPageRoute(
        builder: (context) => WidgetDefaultAppIconPickerScreen(
          defaultAppIconBase64: _defaultAppIconB64,
          currentOverrideBase64: _appBtnOverrideB64,
          currentSource: _appBtnSource,
          currentSvgPath: _appBtnSvgPath,
          currentSvgColorArgb: _appBtnSvgColorArgb,
          currentSvgSizePx: _appBtnSvgSizePx,
        ),
      ),
    );
    if (picked == null) return;
    final p = await SharedPreferences.getInstance();
    final action = (picked['action'] ?? '').toString();
    if (action == 'use_default') {
      await p.remove(_kAppBtnOverride);
      await p.remove(_kAppBtnSource);
      await p.remove(_kAppBtnSvgPath);
      await p.remove(_kAppBtnSvgColor);
      await p.remove(_kAppBtnSvgSize);
      setState(() {
        _appBtnOverrideB64 = null;
        _appBtnSource = '';
        _appBtnSvgPath = null;
        _appBtnSvgColorArgb = 0xFFFFFFFF;
        _appBtnSvgSizePx = 128;
      });
    } else if (action == 'override') {
      final png = (picked['pngBase64'] ?? '').toString().trim();
      if (png.isEmpty) return;
      final source = (picked['source'] ?? '').toString().trim();
      final svgPath = (picked['svgPath'] ?? '').toString().trim();
      final svgColorArgb = picked['svgColorArgb'];
      final svgSizePx = picked['svgSizePx'];
      await p.setString(_kAppBtnOverride, png);
      if (source.isEmpty) {
        await p.remove(_kAppBtnSource);
      } else {
        await p.setString(_kAppBtnSource, source);
      }
      if (source == 'svg') {
        if (svgPath.isEmpty) {
          await p.remove(_kAppBtnSvgPath);
        } else {
          await p.setString(_kAppBtnSvgPath, svgPath);
        }
        if (svgColorArgb is int) await p.setInt(_kAppBtnSvgColor, svgColorArgb);
        if (svgSizePx is int) await p.setInt(_kAppBtnSvgSize, svgSizePx);
      } else {
        await p.remove(_kAppBtnSvgPath);
        await p.remove(_kAppBtnSvgColor);
        await p.remove(_kAppBtnSvgSize);
      }
      setState(() {
        _appBtnOverrideB64 = png;
        _appBtnSource = source;
        _appBtnSvgPath =
            (source == 'svg' && svgPath.isNotEmpty) ? svgPath : null;
        _appBtnSvgColorArgb =
            (source == 'svg' && svgColorArgb is int) ? svgColorArgb : 0xFFFFFFFF;
        _appBtnSvgSizePx =
            (source == 'svg' && svgSizePx is int) ? svgSizePx : 128;
      });
    }
    try {
      await BleService.updateWidget();
    } catch (_) {}
  }

  // ===== Controles reutilizables =====

  Widget _textGroup({
    required String title,
    required int sizeSp,
    required int color,
    required bool bold,
    required ValueChanged<int> onSize,
    required ValueChanged<int> onSizeEnd,
    required ValueChanged<int> onColor,
    required ValueChanged<bool> onBold,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        _sliderTile(
          label: 'Tamaño',
          value: sizeSp.toDouble(),
          min: 8,
          max: 80,
          divisions: 72,
          display: '${sizeSp}sp',
          onChanged: (v) => onSize(v.round()),
          onChangeEnd: (v) => onSizeEnd(v.round()),
        ),
        _colorTile(
          label: 'Color',
          argb: color,
          withAlpha: false,
          onPicked: onColor,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: const Text('Negrita'),
          value: bold,
          onChanged: onBold,
        ),
      ],
    );
  }

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

  Widget _iconTile(
    String label,
    String currentB64,
    String prop,
    ValueChanged<String> onChangedLocal,
  ) {
    final bytes = _decode(currentB64);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(8),
        ),
        child: bytes == null
            ? const Icon(Icons.music_note, color: Colors.white54, size: 18)
            : Image.memory(bytes, fit: BoxFit.contain),
      ),
      title: Text(label),
      subtitle: Text(
        bytes == null ? 'Original' : 'Personalizado',
        style: const TextStyle(color: Colors.grey, fontSize: 12),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        final result = await Navigator.push<Map<String, dynamic>?>(
          context,
          MaterialPageRoute(
            builder: (context) => WidgetIconPickerScreen(
              title: label,
              currentOverrideBase64: currentB64.isEmpty ? null : currentB64,
            ),
          ),
        );
        if (result == null) return;
        final action = (result['action'] ?? '').toString();
        if (action == 'use_default') {
          onChangedLocal('');
          await _setString(prop, '');
        } else if (action == 'override') {
          final png = (result['pngBase64'] ?? '').toString();
          if (png.isEmpty) return;
          onChangedLocal(png);
          await _setString(prop, png);
        }
      },
    );
  }

  Future<void> _confirmReset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restablecer widget'),
        content: Text(
            'Se borrará toda la personalización de "${spec.name}" y volverá a sus valores por defecto. ¿Continuar?'),
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
    await WidgetConfigService.resetAll(spec.id);
    await _load();
  }
}

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

/// Diálogo de selección de color con paleta, hex y (opcional) opacidad.
Future<int?> showWidgetColorPicker(
  BuildContext context, {
  required int initialArgb,
  required bool withAlpha,
}) {
  return showDialog<int>(
    context: context,
    builder: (context) {
      int rgb = initialArgb & 0x00FFFFFF;
      int alpha = (initialArgb >> 24) & 0xFF;
      return StatefulBuilder(
        builder: (context, setSt) {
          int current() => withAlpha ? ((alpha << 24) | rgb) : (0xFF000000 | rgb);
          Widget dot(Color c) => InkWell(
                onTap: () => setSt(() => rgb = c.value & 0x00FFFFFF),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Color(0xFF000000 | (c.value & 0x00FFFFFF)),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.black26),
                  ),
                ),
              );
          return AlertDialog(
            title: const Text('Color'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      dot(Colors.white),
                      dot(Colors.black),
                      dot(Colors.red),
                      dot(Colors.green),
                      dot(Colors.blue),
                      dot(Colors.orange),
                      dot(Colors.purple),
                      dot(Colors.yellow),
                      dot(Colors.cyan),
                      dot(Colors.grey),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ColorInputWidget(
                    label: 'Hex / RGB',
                    initialColor:
                        '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}',
                    onColorChanged: (_) {},
                    onParsedColorChanged: (c) {
                      if (c == null) return;
                      setSt(() {
                        rgb = c.value & 0x00FFFFFF;
                        final a = (c.value >> 24) & 0xFF;
                        if (withAlpha && a != 0xFF) alpha = a;
                      });
                    },
                  ),
                  if (withAlpha) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Opacidad'),
                        Text('${(alpha * 100 / 255).round()}%',
                            style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                    Slider(
                      value: alpha.toDouble(),
                      min: 0,
                      max: 255,
                      divisions: 51,
                      onChanged: (v) => setSt(() => alpha = v.round()),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Resultado: '),
                      Container(
                        width: 40,
                        height: 26,
                        decoration: BoxDecoration(
                          color: Color(current()),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.black38),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, current()),
                child: const Text('Aceptar'),
              ),
            ],
          );
        },
      );
    },
  );
}
