import 'dart:async';

import 'package:connect/screens/emisor/widget_editor_screen.dart' show showWidgetColorPicker;
import 'package:connect/services/image_widget_service.dart';
import 'package:connect/widgets/image_widget_preview.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class ImageWidgetEditorScreen extends StatefulWidget {
  final bool autoPickFolder;
  const ImageWidgetEditorScreen({super.key, this.autoPickFolder = false});

  @override
  State<ImageWidgetEditorScreen> createState() => _ImageWidgetEditorScreenState();
}

class _ImageWidgetEditorScreenState extends State<ImageWidgetEditorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  ImageWidgetCfg? _cfg;
  bool _loading = true;
  bool _copying = false;
  int _copyDone = 0;
  int _copyTotal = 0;
  Timer? _textDebounce;
  int _previewIdx = 0;
  bool _autoPickChecked = false;
  bool _shouldAutoPick = false;

  static const _tabLabels = ['Fuente', 'Transición', 'Marco', 'Imagen', 'Texto', 'Indicador'];
  static const _fxLabels = ['Ninguno', 'Ken Burns', 'Fundido negro', 'Fundido blanco'];
  static const _scaleLabels = ['Rellenar', 'Contener', 'Estirar', 'Centro', 'Ancho'];
  static const _captionSrcLabels = ['Nombre del archivo', 'Fecha de modificación'];
  static const _captionPosLabels = ['Arriba', 'Abajo'];
  static const _dotsPosLabels = ['Arriba', 'Abajo'];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Capturar el argumento aquí (antes del async gap) para auto-abrir el selector
    if (!_autoPickChecked) {
      _autoPickChecked = true;
      final args = ModalRoute.of(context)?.settings.arguments;
      _shouldAutoPick = widget.autoPickFolder ||
          (args is Map && args['autoPickFolder'] == true);
    }
  }

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _tabLabels.length, vsync: this);
    _load().then((_) {
      if (_shouldAutoPick && _cfg?.imageList.isEmpty == true) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _pickFolder();
        });
      }
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _textDebounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final cfg = await ImageWidgetService.load();
    if (!mounted) return;
    setState(() { _cfg = cfg; _loading = false; });
  }

  Future<void> _persist(String prop, dynamic value) async {
    if (value is int) {
      await ImageWidgetService.setInt(prop, value);
    } else if (value is bool) {
      await ImageWidgetService.setBool(prop, value);
    } else if (value is String) {
      await ImageWidgetService.setString(prop, value);
    }
  }

  void _set(void Function(ImageWidgetCfg c) update) {
    if (_cfg == null) return;
    setState(() => update(_cfg!));
  }

  void _setAndPersist(void Function(ImageWidgetCfg c) update, String prop, dynamic value) {
    _set(update);
    _persist(prop, value);
  }

  Future<void> _pickFolder() async {
    // Solicitar permiso de lectura de imágenes (Android 13+)
    final status = await Permission.photos.request();
    if (status.isDenied || status.isPermanentlyDenied) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Se necesita permiso para leer imágenes'),
          action: status.isPermanentlyDenied
              ? SnackBarAction(label: 'Ajustes', onPressed: openAppSettings)
              : null,
        ),
      );
      return;
    }
    setState(() { _copying = true; _copyDone = 0; _copyTotal = 0; });
    final error = await ImageWidgetService.pickFolderAndCopyImages(
      onProgress: (p) {
        if (mounted) setState(() { _copyDone = p.$1; _copyTotal = p.$2; });
      },
    );
    if (!mounted) return;
    if (error == 'empty') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se encontraron imágenes en la carpeta seleccionada')),
      );
    }
    await _load();
    if (mounted) setState(() => _copying = false);
  }

  Future<void> _resetAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Restablecer todo'),
        content: const Text('Se borrarán todas las configuraciones del widget de imágenes. ¿Continuar?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Restablecer')),
        ],
      ),
    );
    if (ok != true) return;
    await ImageWidgetService.resetAll();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final cfg = _cfg;
    if (_loading || cfg == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Widget de imágenes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            tooltip: 'Restablecer todo',
            onPressed: _resetAll,
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Preview — scrolleable junto con el contenido
          SliverToBoxAdapter(child: _buildPreview(cfg)),
          // TabBar — sticky
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              TabBar(
                controller: _tabs,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: _tabLabels.map((l) => Tab(text: l)).toList(),
              ),
            ),
          ),
          // Contenido de la tab activa
          SliverToBoxAdapter(
            child: AnimatedBuilder(
              animation: _tabs,
              builder: (_, __) {
                final cfg = _cfg;
                if (cfg == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: switch (_tabs.index) {
                    0 => _buildTabSource(cfg),
                    1 => _buildTabTransition(cfg),
                    2 => _buildTabFrame(cfg),
                    3 => _buildTabImage(cfg),
                    4 => _buildTabCaption(cfg),
                    5 => _buildTabDots(cfg),
                    _ => const SizedBox.shrink(),
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(ImageWidgetCfg cfg) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Stack(
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: ImageWidgetPreview(cfg: cfg, overrideIndex: _previewIdx),
                ),
                if (cfg.imageList.length > 1) ...[
                  Positioned(
                    left: 4, top: 0, bottom: 0,
                    child: Center(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _previewIdx = (_previewIdx - 1 + cfg.imageList.length) % cfg.imageList.length;
                        }),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(Icons.chevron_left, color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 4, top: 0, bottom: 0,
                    child: Center(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _previewIdx = (_previewIdx + 1) % cfg.imageList.length;
                        }),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(Icons.chevron_right, color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (cfg.imageList.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${_previewIdx + 1} / ${cfg.imageList.length} imágenes',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
        ],
      ),
    );
  }

  // ── Tab 0: Fuente ──────────────────────────────────────────────────────────

  Widget _buildTabSource(ImageWidgetCfg cfg) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Carpeta de imágenes'),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.folder_open),
          title: Text(
            cfg.folderPath.isEmpty ? 'Ninguna carpeta seleccionada' : cfg.folderPath.split('/').last,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: cfg.imageList.isEmpty
              ? const Text('Sin imágenes')
              : Text('${cfg.imageList.length} imagen${cfg.imageList.length != 1 ? "es" : ""}'),
          trailing: ElevatedButton.icon(
            icon: const Icon(Icons.folder_open, size: 18),
            label: const Text('Seleccionar'),
            onPressed: _copying ? null : _pickFolder,
          ),
        ),
        if (_copying) ...[
          const SizedBox(height: 8),
          LinearProgressIndicator(value: _copyTotal > 0 ? _copyDone / _copyTotal : null),
          const SizedBox(height: 4),
          Text(
            _copyTotal > 0 ? 'Copiando $_copyDone / $_copyTotal...' : 'Preparando...',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
        const SizedBox(height: 16),
        _sectionHeader('Reproducción'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Barajar imágenes'),
          subtitle: const Text('Orden aleatorio'),
          value: cfg.shuffle,
          onChanged: (v) => _setAndPersist((c) => c.shuffle = v, 'shuffle', v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Bucle infinito'),
          subtitle: const Text('Volver a la primera al terminar'),
          value: cfg.loop,
          onChanged: (v) => _setAndPersist((c) => c.loop = v, 'loop', v),
        ),
        const SizedBox(height: 8),
        _sliderTile(
          label: 'Segundos por imagen',
          value: cfg.intervalSec.toDouble(),
          min: 3, max: 300, divisions: 297,
          display: _formatSeconds(cfg.intervalSec),
          onChanged: (v) => _set((c) => c.intervalSec = v.round()),
          onChangeEnd: (v) => _persist('interval_sec', v.round()),
        ),
        _sliderTile(
          label: 'Ocultar controles tras (s)',
          value: cfg.controlsHideDelaySec.toDouble(),
          min: 2, max: 30, divisions: 28,
          display: '${cfg.controlsHideDelaySec}s',
          onChanged: (v) => _set((c) => c.controlsHideDelaySec = v.round()),
          onChangeEnd: (v) => _persist('controls_hide_delay_sec', v.round()),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Previsualizar con controles visibles'),
          value: cfg.controlsVisible,
          onChanged: (v) => _setAndPersist((c) => c.controlsVisible = v, 'controls_visible', v),
        ),
      ],
    );
  }

  // ── Tab 1: Transición ──────────────────────────────────────────────────────

  Widget _buildTabTransition(ImageWidgetCfg cfg) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Efecto de transición'),
        ...List.generate(_fxLabels.length, (i) => RadioListTile<int>(
          contentPadding: EdgeInsets.zero,
          title: Text(_fxLabels[i]),
          value: i,
          groupValue: cfg.fxType,
          onChanged: (v) => _setAndPersist((c) => c.fxType = v ?? 0, 'fx_type', v ?? 0),
        )),
        if (cfg.fxType == 1) ...[
          const SizedBox(height: 8),
          _sectionHeader('Ken Burns'),
          _sliderTile(
            label: 'Intensidad del zoom (%)',
            value: cfg.fxZoomPct.toDouble(),
            min: 100, max: 160, divisions: 60,
            display: '${cfg.fxZoomPct}%',
            onChanged: (v) => _set((c) => c.fxZoomPct = v.round()),
            onChangeEnd: (v) => _persist('fx_zoom_pct', v.round()),
          ),
        ],
        if (cfg.fxType == 2 || cfg.fxType == 3) ...[
          const SizedBox(height: 8),
          _sectionHeader('Color de cortina'),
          _colorTile(
            label: 'Color',
            argb: cfg.fxColor,
            withAlpha: false,
            onPicked: (c) => _setAndPersist((cfg) => cfg.fxColor = c, 'fx_color', c),
          ),
        ],
      ],
    );
  }

  // ── Tab 2: Marco ──────────────────────────────────────────────────────────

  Widget _buildTabFrame(ImageWidgetCfg cfg) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Forma del widget'),
        _sliderTile(
          label: 'Radio de esquinas (dp)',
          value: cfg.cornerRadiusDp.toDouble(),
          min: 0, max: 80, divisions: 80,
          display: '${cfg.cornerRadiusDp}dp',
          onChanged: (v) => _set((c) => c.cornerRadiusDp = v.round()),
          onChangeEnd: (v) => _persist('corner_radius_dp', v.round()),
        ),
        _sliderTile(
          label: 'Relleno interno (dp)',
          value: cfg.paddingDp.toDouble(),
          min: 0, max: 32, divisions: 32,
          display: '${cfg.paddingDp}dp',
          onChanged: (v) => _set((c) => c.paddingDp = v.round()),
          onChangeEnd: (v) => _persist('padding_dp', v.round()),
        ),
        if (cfg.paddingDp > 0) ...[
          const SizedBox(height: 8),
          _colorTile(
            label: 'Color de fondo (relleno)',
            argb: cfg.bgColor,
            withAlpha: true,
            onPicked: (c) => _setAndPersist((cfg) => cfg.bgColor = c, 'bg_color', c),
          ),
        ],
        const SizedBox(height: 16),
        _sectionHeader('Borde'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Mostrar borde'),
          value: cfg.borderShow,
          onChanged: (v) => _setAndPersist((c) => c.borderShow = v, 'border_show', v),
        ),
        if (cfg.borderShow) ...[
          _colorTile(
            label: 'Color del borde',
            argb: cfg.borderColor,
            withAlpha: true,
            onPicked: (c) => _setAndPersist((cfg) => cfg.borderColor = c, 'border_color', c),
          ),
          _sliderTile(
            label: 'Grosor del borde (dp)',
            value: cfg.borderThicknessDp.toDouble(),
            min: 0, max: 16, divisions: 16,
            display: '${cfg.borderThicknessDp}dp',
            onChanged: (v) => _set((c) => c.borderThicknessDp = v.round()),
            onChangeEnd: (v) => _persist('border_thickness_dp', v.round()),
          ),
        ],
      ],
    );
  }

  // ── Tab 3: Imagen ─────────────────────────────────────────────────────────

  Widget _buildTabImage(ImageWidgetCfg cfg) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Modo de ajuste'),
        ...List.generate(_scaleLabels.length, (i) => RadioListTile<int>(
          contentPadding: EdgeInsets.zero,
          title: Text(_scaleLabels[i]),
          subtitle: Text(_scaleSubtitle(i), style: const TextStyle(fontSize: 12)),
          value: i,
          groupValue: cfg.scaleType,
          onChanged: (v) => _setAndPersist((c) => c.scaleType = v ?? 0, 'scale_type', v ?? 0),
        )),
        if (cfg.scaleType == 1 || cfg.scaleType == 3) ...[
          const SizedBox(height: 8),
          _colorTile(
            label: 'Color de bandas de fondo',
            argb: cfg.bgColor,
            withAlpha: true,
            onPicked: (c) => _setAndPersist((cfg) => cfg.bgColor = c, 'bg_color', c),
          ),
        ],
        const SizedBox(height: 16),
        _sectionHeader('Superposición (scrim)'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Mostrar superposición'),
          value: cfg.scrimShow,
          onChanged: (v) => _setAndPersist((c) => c.scrimShow = v, 'scrim_show', v),
        ),
        if (cfg.scrimShow) ...[
          _colorTile(
            label: 'Color de superposición',
            argb: cfg.scrimColor,
            withAlpha: false,
            onPicked: (c) => _setAndPersist((cfg) => cfg.scrimColor = c, 'scrim_color', c),
          ),
          _sliderTile(
            label: 'Opacidad (%)',
            value: cfg.scrimOpacity.toDouble(),
            min: 0, max: 100, divisions: 100,
            display: '${cfg.scrimOpacity}%',
            onChanged: (v) => _set((c) => c.scrimOpacity = v.round()),
            onChangeEnd: (v) => _persist('scrim_opacity', v.round()),
          ),
        ],
      ],
    );
  }

  // ── Tab 4: Texto / Pie de foto ─────────────────────────────────────────────

  Widget _buildTabCaption(ImageWidgetCfg cfg) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Pie de foto'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Mostrar pie de foto'),
          value: cfg.captionShow,
          onChanged: (v) => _setAndPersist((c) => c.captionShow = v, 'caption_show', v),
        ),
        if (cfg.captionShow) ...[
          const SizedBox(height: 8),
          _sectionHeader('Contenido'),
          ...List.generate(_captionSrcLabels.length, (i) => RadioListTile<int>(
            contentPadding: EdgeInsets.zero,
            title: Text(_captionSrcLabels[i]),
            value: i,
            groupValue: cfg.captionSource,
            onChanged: (v) => _setAndPersist((c) => c.captionSource = v ?? 0, 'caption_source', v ?? 0),
          )),
          const SizedBox(height: 8),
          _sectionHeader('Posición'),
          ...List.generate(_captionPosLabels.length, (i) => RadioListTile<int>(
            contentPadding: EdgeInsets.zero,
            title: Text(_captionPosLabels[i]),
            value: i,
            groupValue: cfg.captionPosition,
            onChanged: (v) => _setAndPersist((c) => c.captionPosition = v ?? 1, 'caption_position', v ?? 1),
          )),
          const SizedBox(height: 8),
          _sectionHeader('Estilo del texto'),
          _colorTile(
            label: 'Color del texto',
            argb: cfg.captionColor,
            withAlpha: true,
            onPicked: (c) => _setAndPersist((cfg) => cfg.captionColor = c, 'caption_color', c),
          ),
          _sliderTile(
            label: 'Tamaño del texto (sp)',
            value: cfg.captionSizeSp.toDouble(),
            min: 8, max: 36, divisions: 28,
            display: '${cfg.captionSizeSp}sp',
            onChanged: (v) => _set((c) => c.captionSizeSp = v.round()),
            onChangeEnd: (v) => _persist('caption_size_sp', v.round()),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Negrita'),
            value: cfg.captionBold,
            onChanged: (v) => _setAndPersist((c) => c.captionBold = v, 'caption_bold', v),
          ),
          const SizedBox(height: 8),
          _sectionHeader('Fondo del pie'),
          _colorTile(
            label: 'Color de fondo',
            argb: cfg.captionBg,
            withAlpha: true,
            onPicked: (c) => _setAndPersist((cfg) => cfg.captionBg = c, 'caption_bg', c),
          ),
          _sliderTile(
            label: 'Relleno interno (dp)',
            value: cfg.captionPadDp.toDouble(),
            min: 0, max: 24, divisions: 24,
            display: '${cfg.captionPadDp}dp',
            onChanged: (v) => _set((c) => c.captionPadDp = v.round()),
            onChangeEnd: (v) => _persist('caption_pad_dp', v.round()),
          ),
        ],
      ],
    );
  }

  // ── Tab 5: Indicador de posición ──────────────────────────────────────────

  Widget _buildTabDots(ImageWidgetCfg cfg) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Indicador de posición'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Mostrar indicador (dots)'),
          value: cfg.dotsShow,
          onChanged: (v) => _setAndPersist((c) => c.dotsShow = v, 'dots_show', v),
        ),
        if (cfg.dotsShow) ...[
          const SizedBox(height: 8),
          _sectionHeader('Posición'),
          ...List.generate(_dotsPosLabels.length, (i) => RadioListTile<int>(
            contentPadding: EdgeInsets.zero,
            title: Text(_dotsPosLabels[i]),
            value: i,
            groupValue: cfg.dotsPosition,
            onChanged: (v) => _setAndPersist((c) => c.dotsPosition = v ?? 1, 'dots_position', v ?? 1),
          )),
          const SizedBox(height: 8),
          _sectionHeader('Colores'),
          _colorTile(
            label: 'Color del dot activo',
            argb: cfg.dotsActiveColor,
            withAlpha: true,
            onPicked: (c) => _setAndPersist((cfg) => cfg.dotsActiveColor = c, 'dots_active_color', c),
          ),
          _colorTile(
            label: 'Color del dot inactivo',
            argb: cfg.dotsInactiveColor,
            withAlpha: true,
            onPicked: (c) => _setAndPersist((cfg) => cfg.dotsInactiveColor = c, 'dots_inactive_color', c),
          ),
          const SizedBox(height: 8),
          _sectionHeader('Tamaño'),
          _sliderTile(
            label: 'Tamaño del dot (dp)',
            value: cfg.dotsSizeDp.toDouble(),
            min: 4, max: 16, divisions: 12,
            display: '${cfg.dotsSizeDp}dp',
            onChanged: (v) => _set((c) => c.dotsSizeDp = v.round()),
            onChangeEnd: (v) => _persist('dots_size_dp', v.round()),
          ),
          _sliderTile(
            label: 'Espaciado entre dots (dp)',
            value: cfg.dotsSpacingDp.toDouble(),
            min: 2, max: 16, divisions: 14,
            display: '${cfg.dotsSpacingDp}dp',
            onChanged: (v) => _set((c) => c.dotsSpacingDp = v.round()),
            onChangeEnd: (v) => _persist('dots_spacing_dp', v.round()),
          ),
        ],
      ],
    );
  }

  // ── Helpers de UI ─────────────────────────────────────────────────────────

  Widget _sectionHeader(String text) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 4),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
  );

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
          min: min, max: max, divisions: divisions,
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
        width: 36, height: 28,
        decoration: BoxDecoration(
          color: Color(argb),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.black38),
        ),
      ),
      onTap: () async {
        final picked = await showWidgetColorPicker(
          context, initialArgb: argb, withAlpha: withAlpha,
        );
        if (picked != null) onPicked(picked);
      },
    );
  }

  String _formatSeconds(int s) {
    if (s < 60) return '${s}s';
    final m = s ~/ 60; final r = s % 60;
    return r == 0 ? '${m}m' : '${m}m ${r}s';
  }

  String _scaleSubtitle(int i) {
    const subtitles = [
      'Sin bordes, puede recortar bordes',
      'Imagen completa visible, con bandas',
      'Ocupa todo, puede distorsionar',
      'Tamaño real, recorta si es grande',
      'Ajusta al ancho del widget',
    ];
    return subtitles[i];
  }
}

// ── Delegate para la TabBar sticky ────────────────────────────────────────────

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  const _TabBarDelegate(this.tabBar);

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: tabBar,
    );
  }

  @override
  double get maxExtent => tabBar.preferredSize.height;
  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  bool shouldRebuild(_TabBarDelegate old) => old.tabBar != tabBar;
}
