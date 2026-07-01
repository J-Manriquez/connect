import 'dart:convert';
import 'dart:typed_data';

import 'package:connect/services/widget_config_service.dart';
import 'package:flutter/material.dart';

/// Vista previa interactiva (en Flutter) de un widget de música. Refleja la
/// [WidgetConfig] en vivo para probar visualmente los ajustes. El botón de
/// volumen muestra/oculta la barra de volumen, igual que el widget real.
class WidgetMusicPreview extends StatefulWidget {
  final WidgetConfig cfg;
  final String widgetId; // 'style2' | 'style3' | 'wide'
  final bool noMedia;
  final Uint8List? appButtonIcon; // icono del botón "abrir app"
  final bool showDefaultApp; // mostrar el botón "abrir app"

  const WidgetMusicPreview({
    super.key,
    required this.cfg,
    required this.widgetId,
    required this.noMedia,
    this.appButtonIcon,
    this.showDefaultApp = true,
  });

  @override
  State<WidgetMusicPreview> createState() => _WidgetMusicPreviewState();
}

class _WidgetMusicPreviewState extends State<WidgetMusicPreview> {
  bool _volumeExpanded = false;

  WidgetConfig get cfg => widget.cfg;
  double get _scale => (cfg.contentScalePct / 100).clamp(0.5, 2.0);
  bool get _noMedia => widget.noMedia;

  // Datos de ejemplo cuando "hay" reproducción.
  static const String _sampleTitle = 'Nombre de la canción';
  static const String _sampleArtist = 'Artista';
  static const String _sampleApp = 'Música';
  static const double _sampleProgress = 0.42;
  static const double _sampleVolume = 0.6;
  static const String _sampleTimeCur = '1:34';
  static const String _sampleTimeTotal = '3:45';

  Uint8List? _decode(String b64) {
    if (b64.trim().isEmpty) return null;
    try {
      return const Base64Decoder().convert(b64.replaceAll(RegExp(r'\s+'), ''));
    } catch (_) {
      return null;
    }
  }

  Color get _iconColor =>
      cfg.iconColorArgb != null ? Color(cfg.iconColorArgb!) : Colors.white;

  double _iconPx(double base) {
    final s = cfg.iconSizeDp > 0 ? cfg.iconSizeDp.toDouble() : base;
    return (s * _scale).clamp(10, 72);
  }

  Widget _ctrlIcon(String overrideB64, IconData fallback, double basePx) {
    final px = _iconPx(basePx);
    final bytes = _decode(overrideB64);
    if (bytes != null) {
      return Image.memory(bytes, width: px, height: px, fit: BoxFit.contain);
    }
    return Icon(fallback, size: px, color: _iconColor);
  }

  // Botón "abrir app de música por defecto".
  Widget _defaultAppBtn(double basePx) {
    final px = _iconPx(basePx);
    if (widget.appButtonIcon != null) {
      return Image.memory(widget.appButtonIcon!,
          width: px, height: px, fit: BoxFit.contain);
    }
    return Icon(Icons.play_circle_fill, size: px, color: _iconColor);
  }

  Widget _text(
    String s,
    int sizeSp,
    int colorArgb,
    bool bold, {
    TextAlign align = TextAlign.start,
  }) {
    return Text(
      s,
      textAlign: align,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: (sizeSp * _scale).clamp(6, 60),
        color: Color(colorArgb),
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        height: 1.1,
      ),
    );
  }

  Widget _bar(int thicknessDp, double progress) {
    final t = (thicknessDp * 1.0).clamp(2.0, 48.0);
    return SizedBox(
      height: t,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Color(cfg.barTrackArgb),
              borderRadius: BorderRadius.circular(t / 2),
            ),
          ),
          FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress.clamp(0.0, 1.0),
            heightFactor: 1.0,
            child: Container(
              decoration: BoxDecoration(
                color: Color(cfg.barFillArgb),
                borderRadius: BorderRadius.circular(t / 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Carátula de ejemplo (degradado + nota), respeta la opacidad y el ajuste de carátula.
  Widget _sampleArt({BoxFit? fitOverride}) {
    final fit = fitOverride ?? _artBoxFit();
    return Opacity(
      opacity: (cfg.artAlpha / 255).clamp(0.0, 1.0),
      child: FittedBox(
        fit: fit,
        clipBehavior: Clip.hardEdge,
        child: Container(
          width: 300,
          height: 300,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
            ),
          ),
          child: const Center(
            child: Icon(Icons.music_note, color: Colors.white24, size: 48),
          ),
        ),
      ),
    );
  }

  BoxFit _artBoxFit() {
    switch (cfg.artScaleType) {
      case 'contain':
        return BoxFit.contain;
      case 'stretch':
        return BoxFit.fill;
      case 'center':
        return BoxFit.none;
      case 'inside':
        return BoxFit.scaleDown;
      case 'start':
      case 'end':
        return BoxFit.contain;
      default:
        return BoxFit.cover;
    }
  }

  void _toggleVolume() => setState(() => _volumeExpanded = !_volumeExpanded);

  @override
  Widget build(BuildContext context) {
    final Widget widgetMock;
    switch (widget.widgetId) {
      case 'style3':
        widgetMock = _boxTall(_buildStyle3());
        break;
      case 'wide':
        widgetMock = _boxWide(_buildWide());
        break;
      case 'style2':
      default:
        widgetMock = _boxTall(_buildStyle2());
    }
    // Fondo a cuadros tenue para evidenciar transparencias.
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(child: widgetMock),
    );
  }

  Widget _boxTall(Widget child) => ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(width: 168, height: 300, child: child),
      );

  Widget _boxWide(Widget child) => ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(width: 320, height: 150, child: child),
      );

  // Fondo común para los widgets altos (carátula a pantalla completa + velo).
  Widget _fullBleedBackground() {
    if (_noMedia) {
      return Container(color: Color(cfg.bgNoImageArgb));
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        _sampleArt(),
        Container(color: Color(cfg.scrimArgb)),
      ],
    );
  }

  double get _pad => 12 * _scale;

  // ===== style2: texto centrado =====
  Widget _buildStyle2() {
    final showVol = _volumeExpanded;
    return Stack(
      fit: StackFit.expand,
      children: [
        _fullBleedBackground(),
        Padding(
          padding: EdgeInsets.all(_pad),
          child: Column(
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: _toggleVolume,
                    child: _ctrlIcon(cfg.iconVolume, Icons.volume_up, 30),
                  ),
                  Expanded(
                    child: showVol
                        ? Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: _bar(cfg.barVolumeThicknessDp, _sampleVolume),
                          )
                        : const SizedBox.shrink(),
                  ),
                  if (!showVol && widget.showDefaultApp) _defaultAppBtn(30),
                ],
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _text(
                      _noMedia ? cfg.noMediaTitle : _sampleTitle,
                      cfg.titleSizeSp,
                      cfg.titleColor,
                      cfg.titleBold,
                      align: TextAlign.center,
                    ),
                    SizedBox(height: 4 * _scale),
                    _text(
                      _noMedia ? cfg.noMediaSubtitle : _sampleArtist,
                      cfg.subtitleSizeSp,
                      cfg.subtitleColor,
                      cfg.subtitleBold,
                      align: TextAlign.center,
                    ),
                    SizedBox(height: 6 * _scale),
                    _text(
                      _noMedia ? '0:00 / 0:00' : '$_sampleTimeCur / $_sampleTimeTotal',
                      cfg.timeSizeSp,
                      cfg.timeColor,
                      cfg.timeBold,
                      align: TextAlign.center,
                    ),
                  ],
                ),
              ),
              _bar(cfg.barProgressThicknessDp, _noMedia ? 0 : _sampleProgress),
              SizedBox(height: 8 * _scale),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ctrlIcon(cfg.iconPrev, Icons.skip_previous, 30),
                  _ctrlIcon(
                    _noMedia ? cfg.iconPlay : cfg.iconPause,
                    _noMedia ? Icons.play_arrow : Icons.pause,
                    34,
                  ),
                  _ctrlIcon(cfg.iconNext, Icons.skip_next, 30),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===== style3: texto a la izquierda + barra con tiempos =====
  Widget _buildStyle3() {
    final showVol = _volumeExpanded;
    return Stack(
      fit: StackFit.expand,
      children: [
        _fullBleedBackground(),
        Padding(
          padding: EdgeInsets.all(10 * _scale),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Expanded(
                    child: showVol
                        ? _bar(cfg.barVolumeThicknessDp, _sampleVolume)
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _text(
                                _noMedia ? cfg.noMediaTitle : _sampleTitle,
                                cfg.titleSizeSp,
                                cfg.titleColor,
                                cfg.titleBold,
                              ),
                              SizedBox(height: 4 * _scale),
                              _text(
                                _noMedia ? cfg.noMediaSubtitle : _sampleArtist,
                                cfg.subtitleSizeSp,
                                cfg.subtitleColor,
                                cfg.subtitleBold,
                              ),
                            ],
                          ),
                  ),
                  SizedBox(width: 6 * _scale),
                  GestureDetector(
                    onTap: _toggleVolume,
                    child: _ctrlIcon(cfg.iconVolume, Icons.volume_up, 26),
                  ),
                ],
              ),
              SizedBox(height: 8 * _scale + cfg.rowSpacingDp),
              _bar(cfg.barProgressThicknessDp, _noMedia ? 0 : _sampleProgress),
              SizedBox(height: 4 * _scale),
              Row(
                children: [
                  Expanded(
                    child: _text(_noMedia ? '0:00' : _sampleTimeCur,
                        cfg.timeSizeSp, cfg.timeColor, cfg.timeBold),
                  ),
                  Expanded(
                    child: _text(_noMedia ? '' : _sampleApp, cfg.timeSizeSp,
                        cfg.timeColor, cfg.timeBold,
                        align: TextAlign.center),
                  ),
                  Expanded(
                    child: _text(_noMedia ? '0:00' : _sampleTimeTotal,
                        cfg.timeSizeSp, cfg.timeColor, cfg.timeBold,
                        align: TextAlign.end),
                  ),
                ],
              ),
              SizedBox(height: 8 * _scale + cfg.rowSpacingDp),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (widget.showDefaultApp) _defaultAppBtn(26),
                  _ctrlIcon(cfg.iconPrev, Icons.skip_previous, 28),
                  _ctrlIcon(
                    _noMedia ? cfg.iconPlay : cfg.iconPause,
                    _noMedia ? Icons.play_arrow : Icons.pause,
                    30,
                  ),
                  _ctrlIcon(cfg.iconNext, Icons.skip_next, 28),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===== wide: miniatura o carátula de fondo + controles a la derecha =====
  Widget _buildWide() {
    final showVol = _volumeExpanded;
    final artBg = cfg.artAsBackground;

    // Columna de contenido (textos + controles), compartida por ambos modos.
    Widget contentColumn = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _text(_noMedia ? cfg.noMediaTitle : _sampleTitle,
            cfg.titleSizeSp, cfg.titleColor, cfg.titleBold),
        SizedBox(height: 2 * _scale),
        _text(_noMedia ? cfg.noMediaSubtitle : _sampleArtist,
            cfg.subtitleSizeSp, cfg.subtitleColor, cfg.subtitleBold),
        SizedBox(height: 6 * _scale),
        _bar(cfg.barProgressThicknessDp, _noMedia ? 0 : _sampleProgress),
        SizedBox(height: 2 * _scale),
        _text(
          _noMedia ? '0:00 / 0:00' : '$_sampleTimeCur / $_sampleTimeTotal',
          cfg.timeSizeSp,
          cfg.timeColor,
          cfg.timeBold,
          align: TextAlign.end,
        ),
        SizedBox(height: 6 * _scale),
        // Fila de controles con igual espaciado (igual que en el XML: weight=1 por icono)
        Row(
          children: [
            Expanded(
              child: showVol
                  ? _bar(cfg.barVolumeThicknessDp, _sampleVolume)
                  : Row(
                      children: [
                        if (widget.showDefaultApp)
                          Expanded(child: Center(child: _defaultAppBtn(24))),
                        Expanded(
                            child: Center(
                                child: _ctrlIcon(
                                    cfg.iconPrev, Icons.skip_previous, 24))),
                        Expanded(
                            child: Center(
                                child: _ctrlIcon(
                                  _noMedia ? cfg.iconPlay : cfg.iconPause,
                                  _noMedia ? Icons.play_arrow : Icons.pause,
                                  24,
                                ))),
                        Expanded(
                            child: Center(
                                child: _ctrlIcon(
                                    cfg.iconNext, Icons.skip_next, 24))),
                      ],
                    ),
            ),
            GestureDetector(
              onTap: _toggleVolume,
              child: SizedBox(
                width: 40,
                height: 40,
                child: Center(
                    child: _ctrlIcon(cfg.iconVolume, Icons.volume_up, 24)),
              ),
            ),
          ],
        ),
      ],
    );

    if (artBg) {
      // Modo fondo completo (igual que style2/style3).
      return Stack(
        fit: StackFit.expand,
        children: [
          _fullBleedBackground(),
          Padding(
            padding: EdgeInsets.all(10 * _scale),
            child: contentColumn,
          ),
        ],
      );
    }

    // Modo miniatura: imagen 84×84 a la izquierda.
    return Container(
      color: _noMedia ? Color(cfg.bgNoImageArgb) : Color(cfg.scrimArgb),
      padding: EdgeInsets.all(10 * _scale),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 84,
            height: 84,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _noMedia
                  ? Container(color: Colors.white12)
                  : _sampleArt(),
            ),
          ),
          SizedBox(width: 10 * _scale),
          Expanded(child: contentColumn),
        ],
      ),
    );
  }
}
