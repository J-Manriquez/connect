import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:connect/screens/emisor/svg_icon_gallery_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart' as vg;

/// Selector de icono reutilizable para los iconos de control de los widgets de
/// música (anterior / play / pausa / siguiente / volumen).
///
/// Devuelve por [Navigator.pop] un `Map<String, dynamic>`:
/// - `{'action': 'use_default'}` para volver al icono original integrado.
/// - `{'action': 'override', 'pngBase64': '...'}` para usar un icono propio.
/// Si se cierra sin cambios devuelve `null`.
class WidgetIconPickerScreen extends StatefulWidget {
  final String title;
  final String? currentOverrideBase64;

  const WidgetIconPickerScreen({
    super.key,
    required this.title,
    required this.currentOverrideBase64,
  });

  @override
  State<WidgetIconPickerScreen> createState() => _WidgetIconPickerScreenState();
}

class _WidgetIconPickerScreenState extends State<WidgetIconPickerScreen> {
  int _svgColorArgb = 0xFFFFFFFF;
  int _svgSizePx = 96;

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
      print('[widget_icon_picker] renderIconPngBase64 error=$e');
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
      print('[widget_icon_picker] renderSvgFilePngBase64 error=$e');
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
          'pngBase64': png,
        });
        return;
      }
      final icon = picked.flutterIcon;
      if (icon == null) return;
      final png = await _renderIconPngBase64(
        icon,
        sizePx: _svgSizePx,
        color: Color(_svgColorArgb),
      );
      if (png == null || png.trim().isEmpty) return;
      if (!mounted) return;
      Navigator.pop(context, <String, dynamic>{
        'action': 'override',
        'pngBase64': png,
      });
    } catch (e) {
      print('[widget_icon_picker] pickFromGallery error=$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final overrideBytes = _decodeBase64(widget.currentOverrideBase64);
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
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
                  color: Colors.black.withValues(alpha: 0.6),
                ),
                clipBehavior: Clip.antiAlias,
                padding: const EdgeInsets.all(8),
                child: overrideBytes == null
                    ? const Icon(Icons.music_note, color: Colors.white)
                    : Image.memory(
                        overrideBytes,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.image, color: Colors.white),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  overrideBytes == null
                      ? 'Usando el icono original'
                      : 'Usando un icono personalizado',
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Opciones del icono de la galería',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Color'),
            subtitle: Text(
              '#${_svgColorArgb.toRadixString(16).padLeft(8, '0').toUpperCase()}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: _pickSvgColor,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Tamaño de renderizado'),
            subtitle: Text('${_svgSizePx}px'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _pickSvgSize,
          ),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(child: Icon(Icons.collections)),
            title: const Text('Elegir de la galería'),
            subtitle: const Text('Iconos SVG y lista de iconos de Flutter'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _pickFromGallery,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(child: Icon(Icons.restore)),
            title: const Text('Usar el icono original'),
            subtitle: const Text('Quita el icono personalizado'),
            trailing: const Icon(Icons.check),
            onTap: () =>
                Navigator.pop(context, <String, dynamic>{'action': 'use_default'}),
          ),
        ],
      ),
    );
  }

  Future<void> _pickSvgColor() async {
    final picked = await showDialog<int>(
      context: context,
      builder: (context) {
        int next = _svgColorArgb;
        return AlertDialog(
          title: const Text('Color del icono'),
          content: StatefulBuilder(
            builder: (context, setStateDialog) {
              Widget dot(Color c) => InkWell(
                    onTap: () => setStateDialog(() => next = c.value),
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
              return Wrap(
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
                  dot(Colors.yellow),
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
    setState(() => _svgColorArgb = picked);
  }

  Future<void> _pickSvgSize() async {
    final picked = await showDialog<int>(
      context: context,
      builder: (context) {
        int next = _svgSizePx;
        return AlertDialog(
          title: const Text('Tamaño de renderizado (px)'),
          content: StatefulBuilder(
            builder: (context, setStateDialog) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Slider(
                    value: next.toDouble(),
                    min: 48,
                    max: 192,
                    divisions: 12,
                    label: '$next',
                    onChanged: (v) => setStateDialog(() => next = v.round()),
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
    setState(() => _svgSizePx = picked.clamp(48, 192));
  }
}
