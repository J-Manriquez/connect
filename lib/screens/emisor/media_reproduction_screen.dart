import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connect/models/device_data.dart';
import 'package:connect/screens/emisor/svg_icon_gallery_screen.dart';
import 'package:connect/services/firebase_service.dart';
import 'package:connect/services/ble_service.dart';
import 'package:connect/services/preferences_service.dart';
import 'package:connect/services/receptor_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart' as vg;
import 'package:shared_preferences/shared_preferences.dart';

class MediaReproductionScreen extends StatefulWidget {
  final bool useLinkedDevice;

  const MediaReproductionScreen({
    super.key,
    this.useLinkedDevice = false,
  });

  @override
  State<MediaReproductionScreen> createState() =>
      _MediaReproductionScreenState();
}

class _MediaReproductionScreenState extends State<MediaReproductionScreen> {
  static const MethodChannel _appListChannel =
      MethodChannel('com.example.connect/app_list');
  final FirebaseService _firebaseService = FirebaseService();
  final ReceptorService _receptorService = ReceptorService();
  final String _prefsKey = 'media_default_app_package';
  final String _prefsIconKey = 'media_default_app_icon_base64';
  final String _prefsInstalledKey = 'media_default_app_installed';
  final String _prefsInstalledPkgKey = 'media_default_app_installed_pkg';
  final String _prefsWidget2IconOverrideKey = 'media_default_app_widget2_icon_base64';
  final String _prefsWidget2IconSourceKey = 'media_default_app_widget2_icon_source';
  final String _prefsWidget2IconSvgPathKey = 'media_default_app_widget2_icon_svg_path';
  final String _prefsWidget2IconSvgColorArgbKey =
      'media_default_app_widget2_icon_svg_color_argb';
  final String _prefsWidget2IconSvgSizePxKey =
      'media_default_app_widget2_icon_svg_size_px';

  bool _isLoading = true;
  String? _error;
  List<AppData> _apps = [];
  String? _selectedPackage;
  final Map<String, Map<String, dynamic>> _metaByPkg = {};
  bool _prioritizeLocalMedia = false;
  String? _widget2IconOverrideBase64;
  String? _defaultAppIconBase64FromPrefs;
  String _widget2IconSource = '';
  String? _widget2SvgPath;
  int _widget2SvgColorArgb = 0xFFFFFFFF;
  int _widget2SvgSizePx = 128;

  @override
  void initState() {
    super.initState();
    _loadData();
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

  String? _defaultAppIconBase64() {
    final pkg = _selectedPackage?.trim() ?? '';
    if (pkg.isEmpty) return null;
    final meta = _metaByPkg[pkg];
    final iconBase64 = (meta?['icon'] ?? '').toString().trim();
    if (iconBase64.isNotEmpty) return iconBase64;
    final fallback = _defaultAppIconBase64FromPrefs?.trim() ?? '';
    if (fallback.isEmpty) return null;
    return fallback;
  }

  Future<String?> _resolveNativeAppIconBase64(String packageName) async {
    try {
      final pkg = packageName.trim();
      if (pkg.isEmpty) return null;
      print('[media_reproduction] resolveNativeAppIconBase64 pkg="$pkg"');
      final res = await _appListChannel.invokeMethod(
        'searchAppByPackage',
        <String, dynamic>{'packageName': pkg},
      );
      final map = res is Map ? Map<String, dynamic>.from(res) : null;
      final icon = (map?['icon'] ?? '').toString().trim();
      print('[media_reproduction] resolveNativeAppIconBase64 got iconLen=${icon.length}');
      if (icon.isEmpty) return null;
      return icon;
    } catch (e) {
      print('[media_reproduction] resolveNativeAppIconBase64 error=$e');
      return null;
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await BtHiveStorageService.ensureInitialized();
      _prioritizeLocalMedia = await PreferencesService.getPrioritizeLocalMedia();
      final prefs = await SharedPreferences.getInstance();
      String? storedPackage;
      String? hivePackage;
      if (!widget.useLinkedDevice) {
        storedPackage = prefs.getString(_prefsKey);
        hivePackage = await BtHiveStorageService.getDefaultMediaAppPackage();
      }
      final widget2Override = prefs.getString(_prefsWidget2IconOverrideKey);
      final defaultIcon = prefs.getString(_prefsIconKey);
      final widget2Source =
          (prefs.getString(_prefsWidget2IconSourceKey) ?? '').trim();
      final widget2SvgPath =
          (prefs.getString(_prefsWidget2IconSvgPathKey) ?? '').trim();
      final widget2SvgColorArgb =
          prefs.getInt(_prefsWidget2IconSvgColorArgbKey) ?? 0xFFFFFFFF;
      final widget2SvgSizePx =
          prefs.getInt(_prefsWidget2IconSvgSizePxKey) ?? 128;

      final deviceId = widget.useLinkedDevice
          ? await _receptorService.getLinkedDeviceId()
          : await _firebaseService.getDeviceId();
      final targetDeviceId = deviceId?.trim() ?? '';
      if (targetDeviceId.isEmpty) {
        setState(() {
          _error = 'No hay un emisor vinculado.';
          _isLoading = false;
        });
        return;
      }

      String? firebasePackage;
      try {
        final doc = await FirebaseFirestore.instance
            .collection('dispositivos')
            .doc(targetDeviceId)
            .get();
        final raw = (doc.data()?['media_default_app_package'] ?? '')
            .toString()
            .trim();
        firebasePackage = raw.isEmpty ? null : raw;
      } catch (_) {}

      final List<AppData> apps = widget.useLinkedDevice
          ? await _firebaseService.getAppListForDeviceId(targetDeviceId)
          : await _firebaseService.getAppList();
      final Map<String, Map<String, dynamic>> meta = {};
      for (final app in apps) {
        final m = await BtHiveStorageService.getAppMeta(app.packageName);
        if (m != null) meta[app.packageName] = m;
      }

      setState(() {
        _apps = apps;
        _metaByPkg
          ..clear()
          ..addAll(meta);
        _widget2IconOverrideBase64 = widget2Override?.trim().isEmpty == true
            ? null
            : widget2Override?.trim();
        _defaultAppIconBase64FromPrefs =
            defaultIcon?.trim().isEmpty == true ? null : defaultIcon?.trim();
        _widget2IconSource = widget2Source;
        _widget2SvgPath = widget2SvgPath.isEmpty ? null : widget2SvgPath;
        _widget2SvgColorArgb = widget2SvgColorArgb;
        _widget2SvgSizePx = widget2SvgSizePx;
        if (widget.useLinkedDevice) {
          _selectedPackage = firebasePackage;
        } else {
          _selectedPackage = storedPackage?.trim().isNotEmpty == true
              ? storedPackage!.trim()
              : hivePackage?.trim().isNotEmpty == true
                  ? hivePackage!.trim()
                  : firebasePackage;
        }
        _isLoading = false;
      });
      _ensureDefaultIconLoaded();
    } catch (e) {
      setState(() {
        _error = 'Error al cargar aplicaciones: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _ensureDefaultIconLoaded() async {
    try {
      final pkg = _selectedPackage?.trim() ?? '';
      if (pkg.isEmpty) return;
      final hasIcon = (_defaultAppIconBase64FromPrefs?.trim().isNotEmpty == true);
      if (hasIcon) return;
      final native = await _resolveNativeAppIconBase64(pkg);
      if (native == null || native.trim().isEmpty) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsIconKey, native.trim());
      print('[media_reproduction] ensureDefaultIconLoaded stored iconLen=${native.length} for pkg="$pkg"');
      if (!mounted) return;
      setState(() {
        _defaultAppIconBase64FromPrefs = native.trim();
      });
      try {
        final updated = await BleService.updateWidget();
        print('[media_reproduction] updateWidget after ensureDefaultIconLoaded result=$updated');
      } catch (e) {
        print('[media_reproduction] updateWidget after ensureDefaultIconLoaded error=$e');
      }
    } catch (e) {
      print('[media_reproduction] ensureDefaultIconLoaded error=$e');
    }
  }

  Future<void> _openWidget2IconPicker() async {
    try {
      final defaultIconBase64 = _defaultAppIconBase64();
      final currentOverride = _widget2IconOverrideBase64?.trim();
      print('[media_reproduction] openWidget2IconPicker defaultIconLen=${defaultIconBase64?.length ?? 0} overrideLen=${currentOverride?.length ?? 0} source=$_widget2IconSource svgPath=${_widget2SvgPath ?? ""} svgColor=$_widget2SvgColorArgb svgSize=$_widget2SvgSizePx');
      final picked = await Navigator.push<Map<String, dynamic>?>(
        context,
        MaterialPageRoute(
          builder: (context) => _Widget2DefaultAppIconPickerScreen(
            defaultAppIconBase64: defaultIconBase64,
            currentOverrideBase64: currentOverride,
            currentSource: _widget2IconSource,
            currentSvgPath: _widget2SvgPath,
            currentSvgColorArgb: _widget2SvgColorArgb,
            currentSvgSizePx: _widget2SvgSizePx,
          ),
        ),
      );
      if (picked == null) return;
      final prefs = await SharedPreferences.getInstance();
      final action = (picked['action'] ?? '').toString();
      if (action == 'use_default') {
        print('[media_reproduction] widget2Icon override cleared -> use default app icon');
        await prefs.remove(_prefsWidget2IconOverrideKey);
        await prefs.remove(_prefsWidget2IconSourceKey);
        await prefs.remove(_prefsWidget2IconSvgPathKey);
        await prefs.remove(_prefsWidget2IconSvgColorArgbKey);
        await prefs.remove(_prefsWidget2IconSvgSizePxKey);
        setState(() {
          _widget2IconOverrideBase64 = null;
          _widget2IconSource = '';
          _widget2SvgPath = null;
          _widget2SvgColorArgb = 0xFFFFFFFF;
          _widget2SvgSizePx = 128;
        });
      } else {
        final png = (picked['pngBase64'] ?? '').toString().trim();
        final source = (picked['source'] ?? '').toString().trim();
        final svgPath = (picked['svgPath'] ?? '').toString().trim();
        final svgColorArgb = picked['svgColorArgb'];
        final svgSizePx = picked['svgSizePx'];
        if (png.isEmpty) return;
        print('[media_reproduction] widget2Icon override set iconLen=${png.length} source=$source svgPath=${svgPath.isNotEmpty} svgColorArgb=$svgColorArgb svgSizePx=$svgSizePx');
        await prefs.setString(_prefsWidget2IconOverrideKey, png);
        if (source.isEmpty) {
          await prefs.remove(_prefsWidget2IconSourceKey);
        } else {
          await prefs.setString(_prefsWidget2IconSourceKey, source);
        }
        if (source == 'svg') {
          if (svgPath.isEmpty) {
            await prefs.remove(_prefsWidget2IconSvgPathKey);
          } else {
            await prefs.setString(_prefsWidget2IconSvgPathKey, svgPath);
          }
          if (svgColorArgb is int) {
            await prefs.setInt(_prefsWidget2IconSvgColorArgbKey, svgColorArgb);
          }
          if (svgSizePx is int) {
            await prefs.setInt(_prefsWidget2IconSvgSizePxKey, svgSizePx);
          }
        } else {
          await prefs.remove(_prefsWidget2IconSvgPathKey);
          await prefs.remove(_prefsWidget2IconSvgColorArgbKey);
          await prefs.remove(_prefsWidget2IconSvgSizePxKey);
        }
        setState(() {
          _widget2IconOverrideBase64 = png;
          _widget2IconSource = source;
          _widget2SvgPath = (source == 'svg' && svgPath.isNotEmpty) ? svgPath : null;
          _widget2SvgColorArgb =
              (source == 'svg' && svgColorArgb is int) ? svgColorArgb : 0xFFFFFFFF;
          _widget2SvgSizePx =
              (source == 'svg' && svgSizePx is int) ? svgSizePx : 128;
        });
      }
      try {
        final updated = await BleService.updateWidget();
        print('[media_reproduction] updateWidget after widget2Icon result=$updated');
      } catch (e) {
        print('[media_reproduction] updateWidget after widget2Icon error=$e');
      }
    } catch (e) {
      print('[media_reproduction] openWidget2IconPicker error=$e');
    }
  }

  Future<void> _saveSelectedApp(String? packageName) async {
    setState(() {
      _selectedPackage = packageName;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final pkg = packageName?.trim() ?? '';
      print('[media_reproduction] saveSelectedApp pkg="$pkg" useLinkedDevice=${widget.useLinkedDevice}');
      if (pkg.isEmpty) {
        await prefs.remove(_prefsKey);
        await prefs.remove(_prefsIconKey);
        await prefs.remove(_prefsInstalledKey);
        await prefs.remove(_prefsInstalledPkgKey);
        setState(() {
          _defaultAppIconBase64FromPrefs = null;
        });
      } else {
        await prefs.setString(_prefsKey, pkg);
        final meta = _metaByPkg[pkg];
        String iconBase64 = (meta?['icon'] ?? '').toString().trim();
        if (iconBase64.isEmpty) {
          final native = await _resolveNativeAppIconBase64(pkg);
          if (native != null && native.trim().isNotEmpty) {
            iconBase64 = native.trim();
          }
        }
        print('[media_reproduction] saveSelectedApp metaKeys=${meta?.keys.toList() ?? []} iconLen=${iconBase64.length}');
        if (iconBase64.isEmpty) {
          await prefs.remove(_prefsIconKey);
          setState(() {
            _defaultAppIconBase64FromPrefs = null;
          });
        } else {
          await prefs.setString(_prefsIconKey, iconBase64);
          setState(() {
            _defaultAppIconBase64FromPrefs = iconBase64;
          });
        }
        await prefs.setBool(_prefsInstalledKey, true);
        await prefs.setString(_prefsInstalledPkgKey, pkg);
      }

      final targetDeviceId = widget.useLinkedDevice
          ? (await _receptorService.getLinkedDeviceId())?.trim() ?? ''
          : await _firebaseService.getDeviceId();
      if (targetDeviceId.isEmpty) return;

      if (!widget.useLinkedDevice) {
        await BtHiveStorageService.setDefaultMediaAppPackage(packageName ?? '');
      }

      final docRef = FirebaseFirestore.instance
          .collection('dispositivos')
          .doc(targetDeviceId);

      await docRef.set({
        'media_default_app_package': packageName ?? '',
        'ultima-actualizacion': FieldValue.arrayUnion([
          {
            'fecha': Timestamp.now(),
            'tipo-actualizacion': 'media-default-app',
          },
        ]),
      }, SetOptions(merge: true));

      try {
        final updated = await BleService.updateWidget();
        print('[media_reproduction] updateWidget result=$updated');
      } catch (e) {
        print('[media_reproduction] updateWidget error=$e');
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reproducción multimedia'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : _apps.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'No hay aplicaciones disponibles. Activa el guardado en Firebase y sincroniza la lista de aplicaciones.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _apps.length + 2,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, thickness: 1),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          final overrideBytes = _decodeBase64(_widget2IconOverrideBase64);
                          final defaultBytes = _decodeBase64(_defaultAppIconBase64());
                          final shownBytes = overrideBytes ?? defaultBytes;
                          final modeLabel = overrideBytes != null
                              ? 'Icono personalizado'
                              : 'Icono de la app predeterminada';
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.transparent,
                              child: shownBytes == null
                                  ? const Icon(Icons.image)
                                  : Image.memory(
                                      shownBytes,
                                      errorBuilder: (_, __, ___) =>
                                          const Icon(Icons.image),
                                    ),
                            ),
                            title: const Text('Seleccionar icono'),
                            subtitle: Text('Widget 2 • Abrir predeterminada • $modeLabel'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: _openWidget2IconPicker,
                          );
                        }
                        if (index == 1) {
                          return CheckboxListTile(
                            title: const Text('Priorizar multimedia local'),
                            subtitle: const Text(
                              'Si está activado, los controles también se aplican al contenido multimedia del dispositivo receptor cuando esté reproduciendo.',
                            ),
                            value: _prioritizeLocalMedia,
                            onChanged: (v) async {
                              final next = v == true;
                              setState(() => _prioritizeLocalMedia = next);
                              await PreferencesService.savePrioritizeLocalMedia(next);
                            },
                          );
                        }
                        final app = _apps[index - 2];
                        final isSelected = app.packageName == _selectedPackage;
                        final meta = _metaByPkg[app.packageName];
                        final iconBase64 =
                            (meta?['icon'] ?? '').toString().trim();
                        return ListTile(
                          leading: iconBase64.isEmpty
                              ? const CircleAvatar(child: Icon(Icons.apps))
                              : CircleAvatar(
                                  backgroundColor: Colors.transparent,
                                  child: Image.memory(
                                    UriData.parse('data:image/png;base64,$iconBase64')
                                        .contentAsBytes(),
                                    errorBuilder: (_, __, ___) =>
                                        const Icon(Icons.apps),
                                  ),
                                ),
                          title: Text(app.nombre),
                          subtitle: Text(app.packageName),
                          trailing: Checkbox(
                            value: isSelected,
                            onChanged: (_) =>
                                _saveSelectedApp(app.packageName),
                          ),
                          onTap: () => _saveSelectedApp(app.packageName),
                        );
                      },
                    ),
    );
  }
}

class _Widget2DefaultAppIconPickerScreen extends StatefulWidget {
  final String? defaultAppIconBase64;
  final String? currentOverrideBase64;
  final String currentSource;
  final String? currentSvgPath;
  final int currentSvgColorArgb;
  final int currentSvgSizePx;

  const _Widget2DefaultAppIconPickerScreen({
    required this.defaultAppIconBase64,
    required this.currentOverrideBase64,
    required this.currentSource,
    required this.currentSvgPath,
    required this.currentSvgColorArgb,
    required this.currentSvgSizePx,
  });

  @override
  State<_Widget2DefaultAppIconPickerScreen> createState() =>
      _Widget2DefaultAppIconPickerScreenState();
}

class _Widget2DefaultAppIconPickerScreenState
    extends State<_Widget2DefaultAppIconPickerScreen> {
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
      print('[media_reproduction][icon_picker] renderIconPngBase64 error=$e');
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
      print('[media_reproduction][icon_picker] renderSvgFilePngBase64 error=$e');
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
        print('[media_reproduction][icon_picker] picked svg id=${entry.id}');
        final png = await _renderSvgFilePngBase64(
          entry.filePath,
          sizePx: _svgSizePx,
          color: Color(_svgColorArgb),
        );
        if (png == null || png.trim().isEmpty) return;
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
      print('[media_reproduction][icon_picker] picked flutter id=$id');
      final png = await _renderIconPngBase64(icon, sizePx: 128);
      if (png == null || png.trim().isEmpty) return;
      Navigator.pop(context, <String, dynamic>{
        'action': 'override',
        'source': 'flutter',
        'pngBase64': png,
      });
    } catch (e) {
      print('[media_reproduction][icon_picker] pickFromGallery error=$e');
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
                      'Widget 2 • Abrir predeterminada',
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
                print('[media_reproduction][icon_picker] svg color -> $picked');
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
                print('[media_reproduction][icon_picker] svg size -> $picked');
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
              subtitle: const Text('Re-renderiza el icono con el color y tamaño seleccionados'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final path = widget.currentSvgPath!.trim();
                print('[media_reproduction][icon_picker] rerender current svg path="$path" color=$_svgColorArgb size=$_svgSizePx');
                final png = await _renderSvgFilePngBase64(
                  path,
                  sizePx: _svgSizePx,
                  color: Color(_svgColorArgb),
                );
                if (png == null || png.trim().isEmpty) return;
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
            subtitle: const Text('Recomendado si cambias la app predeterminada con frecuencia'),
            trailing: const Icon(Icons.check),
            onTap: () {
              print('[media_reproduction][icon_picker] pick default app icon (clear override)');
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
                child: overrideBytes == null
                    ? const Icon(Icons.image)
                    : Image.memory(
                        overrideBytes,
                        errorBuilder: (_, __, ___) => const Icon(Icons.image),
                      ),
              ),
              title: const Text('Mantener icono personalizado actual'),
              subtitle: const Text('No cambia nada'),
              trailing: const Icon(Icons.chevron_left),
              onTap: () {
                print('[media_reproduction][icon_picker] keep current override icon');
                Navigator.pop<Map<String, dynamic>?>(context, null);
              },
            ),
          ],
        ],
      ),
    );
  }
}
