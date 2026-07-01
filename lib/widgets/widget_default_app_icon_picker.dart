import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:connect/screens/emisor/svg_icon_gallery_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart' as vg;

/// Selector del icono del botón "abrir app de música por defecto" del widget
/// **Música (centrado)**. Devuelve por [Navigator.pop] un `Map<String, dynamic>`:
/// - `{'action': 'use_default'}` para usar el icono de la app predeterminada.
/// - `{'action': 'override', 'source': 'svg'|'flutter', 'pngBase64': '...', ...}`
///   para un icono personalizado.
class WidgetDefaultAppIconPickerScreen extends StatefulWidget {
  final String? defaultAppIconBase64;
  final String? currentOverrideBase64;
  final String currentSource;
  final String? currentSvgPath;
  final int currentSvgColorArgb;
  final int currentSvgSizePx;

  const WidgetDefaultAppIconPickerScreen({
    super.key,
    required this.defaultAppIconBase64,
    required this.currentOverrideBase64,
    required this.currentSource,
    required this.currentSvgPath,
    required this.currentSvgColorArgb,
    required this.currentSvgSizePx,
  });

  @override
  State<WidgetDefaultAppIconPickerScreen> createState() =>
      _WidgetDefaultAppIconPickerScreenState();
}

class _WidgetDefaultAppIconPickerScreenState
    extends State<WidgetDefaultAppIconPickerScreen> {
  late int _svgColorArgb;
  late int _svgSizePx;

  @override
  void initState() {
    super.initState();
    _svgColorArgb = widget.currentSvgColorArgb;
    _svgSizePx = widget.currentSvgSizePx.clamp(64, 256);
  }

  Uint8List? _decodeBase64(String? raw) {
    final s = raw?.replaceAll(RegExp(r'\s+'), '').trim();
    if (s == null || s.isEmpty) return null;
    try {
      return const Base64Decoder().convert(s);
    } catch (_) {
      return null;
    }
  }

  Future<String?> _renderIconPngBase64(
    IconData icon, {
    int sizePx = 96,
    Color color = Colors.white,
  }) async {
    try {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final paint = ui.Paint()..color = Colors.transparent;
      canvas.drawRect(
        ui.Rect.fromLTWH(0, 0, sizePx.toDouble(), sizePx.toDouble()),
        paint,
      );

      final painter = TextPainter(
        textDirection: TextDirection.ltr,
        text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            fontSize: sizePx.toDouble(),
            fontFamily: icon.fontFamily,
            color: color,
          ),
        ),
      )..layout();

      painter.paint(
        canvas,
        ui.Offset((sizePx - painter.width) / 2, (sizePx - painter.height) / 2),
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(sizePx, sizePx);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return null;
      return base64Encode(bytes.buffer.asUint8List());
    } catch (e) {
      print('[widget_default_app_icon_picker] renderIconPngBase64 error=$e');
      return null;
    }
  }

  Future<String?> _renderSvgFilePngBase64(
    String filePath, {
    int sizePx = 96,
    Color color = Colors.white,
  }) async {
    vg.PictureInfo? pictureInfo;
    try {
      final raw = await File(filePath).readAsString();
      pictureInfo = await vg.vg.loadPicture(
        vg.SvgStringLoader(raw),
        null,
        clipViewbox: true,
      );
      final src = pictureInfo.size;
      final scale = math.min(
        sizePx / (src.width == 0 ? 1 : src.width),
        sizePx / (src.height == 0 ? 1 : src.height),
      );

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final outW = sizePx.toDouble();
      final outH = sizePx.toDouble();
      final drawW = src.width * scale;
      final drawH = src.height * scale;
      canvas.translate((outW - drawW) / 2, (outH - drawH) / 2);
      canvas.scale(scale, scale);
      canvas.drawPicture(pictureInfo.picture);
      final outPicture = recorder.endRecording();
      final image = await outPicture.toImage(sizePx, sizePx);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return null;
      final png = bytes.buffer.asUint8List();
      if (color == Colors.white) return base64Encode(png);

      final codec = await ui.instantiateImageCodec(png);
      final frame = await codec.getNextFrame();
      final recorder2 = ui.PictureRecorder();
      final canvas2 = ui.Canvas(recorder2);
      final paint = ui.Paint()
        ..colorFilter = ui.ColorFilter.mode(color, ui.BlendMode.srcIn);
      canvas2.drawImage(frame.image, ui.Offset.zero, paint);
      final pic = recorder2.endRecording();
      final outImg = await pic.toImage(sizePx, sizePx);
      final outBytes = await outImg.toByteData(format: ui.ImageByteFormat.png);
      if (outBytes == null) return base64Encode(png);
      return base64Encode(outBytes.buffer.asUint8List());
    } catch (e) {
      print('[widget_default_app_icon_picker] renderSvgFilePngBase64 error=$e');
      return null;
    } finally {
      try {
        pictureInfo?.picture.dispose();
      } catch (_) {}
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final picked = await Navigator.push<IconGalleryPick>(
        context,
        MaterialPageRoute(
          builder: (context) => const SvgIconGalleryScreen(pickMode: true),
        ),
      );
      if (picked == null) return;
      if (picked.type == IconGalleryPickType.svg) {
        final entry = picked.svg;
        if (entry == null) return;
        final png = await _renderSvgFilePngBase64(
          entry.filePath,
          sizePx: _svgSizePx,
          color: Color(_svgColorArgb),
        );
        if (png == null || png.trim().isEmpty) return;
        if (!mounted) return;
        Navigator.pop(context, <String, dynamic>{
          'action': 'override',
          'source': 'svg',
          'pngBase64': png,
          'svgPath': entry.filePath,
          'svgColorArgb': _svgColorArgb,
          'svgSizePx': _svgSizePx,
        });
        return;
      }
      final id = picked.flutterId;
      final icon = picked.flutterIcon;
      if (id == null || icon == null) return;
      final png = await _renderIconPngBase64(icon, sizePx: 128);
      if (png == null || png.trim().isEmpty) return;
      if (!mounted) return;
      Navigator.pop(context, <String, dynamic>{
        'action': 'override',
        'source': 'flutter',
        'pngBase64': png,
      });
    } catch (e) {
      print('[widget_default_app_icon_picker] pickFromGallery error=$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final defaultBytes = _decodeBase64(widget.defaultAppIconBase64);
    final overrideBytes = _decodeBase64(widget.currentOverrideBase64);
    final shownBytes = overrideBytes ?? defaultBytes;
    final modeLabel = overrideBytes != null ? 'Personalizado' : 'App predeterminada';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Seleccionar icono'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black12),
                  color: Colors.black.withValues(alpha: 0.04),
                ),
                clipBehavior: Clip.antiAlias,
                child: shownBytes == null
                    ? const Icon(Icons.image)
                    : Image.memory(
                        shownBytes,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(Icons.image),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Botón "abrir app de música"',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Modo actual: $modeLabel',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Opciones SVG',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Color'),
            subtitle: Text(
              '#${_svgColorArgb.toRadixString(16).padLeft(8, '0').toUpperCase()}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final picked = await showDialog<int>(
                context: context,
                builder: (context) {
                  int next = _svgColorArgb;
                  return AlertDialog(
                    title: const Text('Color del icono SVG'),
                    content: StatefulBuilder(
                      builder: (context, setStateDialog) {
                        Widget dot(Color c) => InkWell(
                              onTap: () {
                                setStateDialog(() {
                                  next = c.value;
                                });
                              },
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: c,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.black26),
                                ),
                              ),
                            );
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                dot(Colors.white),
                                dot(Colors.black),
                                dot(Colors.red),
                                dot(Colors.green),
                                dot(Colors.blue),
                                dot(Colors.orange),
                                dot(Colors.purple),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Text('Actual: '),
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: Color(next),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.black26),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancelar'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, next),
                        child: const Text('Aceptar'),
                      ),
                    ],
                  );
                },
              );
              if (picked == null) return;
              setState(() {
                _svgColorArgb = picked;
              });
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Tamaño'),
            subtitle: Text('${_svgSizePx}px'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final picked = await showDialog<int>(
                context: context,
                builder: (context) {
                  int next = _svgSizePx;
                  return AlertDialog(
                    title: const Text('Tamaño del icono SVG (px)'),
                    content: StatefulBuilder(
                      builder: (context, setStateDialog) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Slider(
                              value: next.toDouble(),
                              min: 64,
                              max: 256,
                              divisions: 8,
                              label: '$next',
                              onChanged: (v) {
                                setStateDialog(() {
                                  next = v.round();
                                });
                              },
                            ),
                            Text('$next px'),
                          ],
                        );
                      },
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancelar'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, next),
                        child: const Text('Aceptar'),
                      ),
                    ],
                  );
                },
              );
              if (picked == null) return;
              setState(() {
                _svgSizePx = picked.clamp(64, 256);
              });
            },
          ),
          const Divider(),
          if (widget.currentSource == 'svg' &&
              widget.currentSvgPath != null &&
              widget.currentSvgPath!.trim().isNotEmpty) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(child: Icon(Icons.refresh)),
              title: const Text('Aplicar ajustes al SVG actual'),
              subtitle: const Text(
                  'Re-renderiza el icono con el color y tamaño seleccionados'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final path = widget.currentSvgPath!.trim();
                final png = await _renderSvgFilePngBase64(
                  path,
                  sizePx: _svgSizePx,
                  color: Color(_svgColorArgb),
                );
                if (png == null || png.trim().isEmpty) return;
                if (!mounted) return;
                Navigator.pop(context, <String, dynamic>{
                  'action': 'override',
                  'source': 'svg',
                  'pngBase64': png,
                  'svgPath': path,
                  'svgColorArgb': _svgColorArgb,
                  'svgSizePx': _svgSizePx,
                });
              },
            ),
            const Divider(),
          ],
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: const ui.Color.fromARGB(0, 130, 130, 130),
              child: defaultBytes == null
                  ? const Icon(Icons.apps)
                  : Image.memory(
                      defaultBytes,
                      errorBuilder: (_, __, ___) => const Icon(Icons.apps),
                    ),
            ),
            title: const Text('Usar icono de la app predeterminada'),
            subtitle: const Text(
                'Recomendado si cambias la app predeterminada con frecuencia'),
            trailing: const Icon(Icons.check),
            onTap: () {
              Navigator.pop(context, <String, dynamic>{'action': 'use_default'});
            },
          ),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(child: Icon(Icons.collections)),
            title: const Text('Elegir otro icono'),
            subtitle: const Text('Galería (SVG) y lista de iconos de Flutter'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _pickFromGallery,
          ),
          if (overrideBytes != null) ...[
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: Colors.transparent,
                child: Image.memory(
                  overrideBytes,
                  errorBuilder: (_, __, ___) => const Icon(Icons.image),
                ),
              ),
              title: const Text('Mantener icono personalizado actual'),
              subtitle: const Text('No cambia nada'),
              trailing: const Icon(Icons.chevron_left),
              onTap: () {
                Navigator.pop<Map<String, dynamic>?>(context, null);
              },
            ),
          ],
        ],
      ),
    );
  }
}
