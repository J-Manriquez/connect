import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connect/services/ble_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Modelo de configuración ────────────────────────────────────────────────

class ImageWidgetCfg {
  String folderPath;
  List<String> imageList;
  int currentIndex;
  bool shuffle;
  bool loop;
  int intervalSec;
  int controlsHideDelaySec;
  bool controlsVisible;

  // Efectos de transición
  int fxType;
  int fxZoomPct;
  int fxColor;

  // Marco
  int cornerRadiusDp;
  int paddingDp;
  bool borderShow;
  int borderColor;
  int borderThicknessDp;

  // Imagen
  int scaleType;
  int bgColor;
  bool scrimShow;
  int scrimColor;
  int scrimOpacity;

  // Pie de foto
  bool captionShow;
  int captionSource;
  int captionColor;
  int captionSizeSp;
  bool captionBold;
  int captionPosition;
  int captionBg;
  int captionPadDp;

  // Indicador de posición
  bool dotsShow;
  int dotsActiveColor;
  int dotsInactiveColor;
  int dotsSizeDp;
  int dotsSpacingDp;
  int dotsPosition;

  // Estilo de controles
  int ctrlIconColor;
  int ctrlBgColor;
  int ctrlCornerRadiusDp;
  int ctrlHorizPos;   // 0=expandido (izq/der), 1=centrado
  int ctrlVertPos;    // 0=arriba, 1=centro, 2=abajo

  ImageWidgetCfg({
    this.folderPath = '',
    this.imageList = const [],
    this.currentIndex = 0,
    this.shuffle = false,
    this.loop = true,
    this.intervalSec = ImageWidgetService.defIntervalSec,
    this.controlsHideDelaySec = ImageWidgetService.defControlsHideDelay,
    this.controlsVisible = false,
    this.fxType = 0,
    this.fxZoomPct = ImageWidgetService.defFxZoomPct,
    this.fxColor = 0xFF000000,
    this.cornerRadiusDp = ImageWidgetService.defCornerRadiusDp,
    this.paddingDp = 0,
    this.borderShow = false,
    this.borderColor = 0xFFFFFFFF,
    this.borderThicknessDp = ImageWidgetService.defBorderThicknessDp,
    this.scaleType = 0,
    this.bgColor = 0xFF000000,
    this.scrimShow = false,
    this.scrimColor = 0x80000000,
    this.scrimOpacity = ImageWidgetService.defScrimOpacity,
    this.captionShow = false,
    this.captionSource = 0,
    this.captionColor = 0xFFFFFFFF,
    this.captionSizeSp = ImageWidgetService.defCaptionSizeSp,
    this.captionBold = false,
    this.captionPosition = ImageWidgetService.defCaptionPosition,
    this.captionBg = 0x99000000,
    this.captionPadDp = ImageWidgetService.defCaptionPadDp,
    this.dotsShow = false,
    this.dotsActiveColor = 0xFFFFFFFF,
    this.dotsInactiveColor = 0x80FFFFFF,
    this.dotsSizeDp = ImageWidgetService.defDotsSizeDp,
    this.dotsSpacingDp = ImageWidgetService.defDotsSpacingDp,
    this.dotsPosition = ImageWidgetService.defDotsPosition,
    this.ctrlIconColor = ImageWidgetService.defCtrlIconColor,
    this.ctrlBgColor = ImageWidgetService.defCtrlBgColor,
    this.ctrlCornerRadiusDp = ImageWidgetService.defCtrlCornerRadiusDp,
    this.ctrlHorizPos = ImageWidgetService.defCtrlHorizPos,
    this.ctrlVertPos = ImageWidgetService.defCtrlVertPos,
  });
}

// ─── Servicio ────────────────────────────────────────────────────────────────

class ImageWidgetService {
  static const _channel = MethodChannel('com.example.connect/ble');
  static const _tag = 'img_widget';

  // Helper: print local + reenvío BT al emisor (patrón exacto de la skill bt-debug-logging)
  static void _log(String message) {
    print('[$_tag] $message');
    try {
      unawaited(BleService.sendDebugLogToPeers(_tag, message));
    } catch (_) {}
  }

  // Defaults — espejo exacto de ImageSlideShowWidgetProvider.kt
  static const defIntervalSec        = 10;
  static const defControlsHideDelay  = 5;
  static const defFxZoomPct          = 115;
  static const defCornerRadiusDp     = 16;
  static const defBorderThicknessDp  = 2;
  static const defScrimOpacity       = 50;
  static const defCaptionSizeSp      = 14;
  static const defCaptionPosition    = 1;
  static const defCaptionPadDp       = 8;
  static const defDotsSizeDp         = 8;
  static const defDotsSpacingDp      = 6;
  static const defDotsPosition       = 1;
  static const defCtrlIconColor      = 0xFFFFFFFF;
  static const defCtrlBgColor        = 0x66000000;
  static const defCtrlCornerRadiusDp = 4;
  static const defCtrlHorizPos       = 0;
  static const defCtrlVertPos        = 1;

  static String _k(String prop) => 'widget_cfg_img_$prop';

  static Future<ImageWidgetCfg> load() async {
    final p = await SharedPreferences.getInstance();
    final listJson = p.getString(_k('file_list')) ?? '[]';
    List<String> imageList;
    try {
      imageList = (jsonDecode(listJson) as List).cast<String>();
    } catch (_) {
      imageList = [];
    }

    return ImageWidgetCfg(
      folderPath           : p.getString(_k('folder_path')) ?? '',
      imageList            : imageList,
      currentIndex         : (p.getInt(_k('current_index')) ?? 0).clamp(0, imageList.isEmpty ? 0 : imageList.length - 1),
      shuffle              : p.getBool(_k('shuffle')) ?? false,
      loop                 : p.getBool(_k('loop')) ?? true,
      intervalSec          : (p.getInt(_k('interval_sec')) ?? defIntervalSec).clamp(3, 300),
      controlsHideDelaySec : (p.getInt(_k('controls_hide_delay_sec')) ?? defControlsHideDelay).clamp(2, 30),
      controlsVisible      : p.getBool(_k('controls_visible')) ?? false,
      fxType               : (p.getInt(_k('fx_type')) ?? 0).clamp(0, 3),
      fxZoomPct            : (p.getInt(_k('fx_zoom_pct')) ?? defFxZoomPct).clamp(100, 160),
      fxColor              : p.getInt(_k('fx_color')) ?? 0xFF000000,
      cornerRadiusDp       : (p.getInt(_k('corner_radius_dp')) ?? defCornerRadiusDp).clamp(0, 80),
      paddingDp            : (p.getInt(_k('padding_dp')) ?? 0).clamp(0, 32),
      borderShow           : p.getBool(_k('border_show')) ?? false,
      borderColor          : p.getInt(_k('border_color')) ?? 0xFFFFFFFF,
      borderThicknessDp    : (p.getInt(_k('border_thickness_dp')) ?? defBorderThicknessDp).clamp(0, 16),
      scaleType            : (p.getInt(_k('scale_type')) ?? 0).clamp(0, 4),
      bgColor              : p.getInt(_k('bg_color')) ?? 0xFF000000,
      scrimShow            : p.getBool(_k('scrim_show')) ?? false,
      scrimColor           : p.getInt(_k('scrim_color')) ?? 0x80000000,
      scrimOpacity         : (p.getInt(_k('scrim_opacity')) ?? defScrimOpacity).clamp(0, 100),
      captionShow          : p.getBool(_k('caption_show')) ?? false,
      captionSource        : (p.getInt(_k('caption_source')) ?? 0).clamp(0, 1),
      captionColor         : p.getInt(_k('caption_color')) ?? 0xFFFFFFFF,
      captionSizeSp        : (p.getInt(_k('caption_size_sp')) ?? defCaptionSizeSp).clamp(8, 36),
      captionBold          : p.getBool(_k('caption_bold')) ?? false,
      captionPosition      : (p.getInt(_k('caption_position')) ?? defCaptionPosition).clamp(0, 1),
      captionBg            : p.getInt(_k('caption_bg')) ?? 0x99000000,
      captionPadDp         : (p.getInt(_k('caption_pad_dp')) ?? defCaptionPadDp).clamp(0, 24),
      dotsShow             : p.getBool(_k('dots_show')) ?? false,
      dotsActiveColor      : p.getInt(_k('dots_active_color')) ?? 0xFFFFFFFF,
      dotsInactiveColor    : p.getInt(_k('dots_inactive_color')) ?? 0x80FFFFFF,
      dotsSizeDp           : (p.getInt(_k('dots_size_dp')) ?? defDotsSizeDp).clamp(4, 16),
      dotsSpacingDp        : (p.getInt(_k('dots_spacing_dp')) ?? defDotsSpacingDp).clamp(2, 16),
      dotsPosition         : (p.getInt(_k('dots_position')) ?? defDotsPosition).clamp(0, 1),
      ctrlIconColor        : p.getInt(_k('ctrl_icon_color')) ?? defCtrlIconColor,
      ctrlBgColor          : p.getInt(_k('ctrl_bg_color')) ?? defCtrlBgColor,
      ctrlCornerRadiusDp   : (p.getInt(_k('ctrl_corner_radius_dp')) ?? defCtrlCornerRadiusDp).clamp(0, 40),
      ctrlHorizPos         : (p.getInt(_k('ctrl_horiz_pos')) ?? defCtrlHorizPos).clamp(0, 1),
      ctrlVertPos          : (p.getInt(_k('ctrl_vert_pos')) ?? defCtrlVertPos).clamp(0, 2),
    );
  }

  static Future<ImageWidgetCfg> loadWithLog() async {
    final t0 = DateTime.now().millisecondsSinceEpoch;
    final cfg = await load();
    final dt = DateTime.now().millisecondsSinceEpoch - t0;
    _log('load() completado en ${dt}ms'
        ' | imgs=${cfg.imageList.length}'
        ' | idx=${cfg.currentIndex}'
        ' | scaleType=${cfg.scaleType}'
        ' | ctrlVisible=${cfg.controlsVisible}'
        ' | ctrlHideDelay=${cfg.controlsHideDelaySec}s'
        ' | ctrlHorizPos=${cfg.ctrlHorizPos}'
        ' | ctrlVertPos=${cfg.ctrlVertPos}'
        ' | ctrlIconColor=0x${cfg.ctrlIconColor.toRadixString(16)}'
        ' | ctrlBgColor=0x${cfg.ctrlBgColor.toRadixString(16)}'
        ' | ctrlCornerR=${cfg.ctrlCornerRadiusDp}dp'
        ' | bgColor=0x${cfg.bgColor.toRadixString(16)}'
        ' | folder=${cfg.folderPath}');
    return cfg;
  }

  static Future<void> setInt(String prop, int v) async {
    _log('setInt prop=$prop valor=$v');
    final p = await SharedPreferences.getInstance();
    await p.setInt(_k(prop), v);
    await _notify();
  }

  static Future<void> setBool(String prop, bool v) async {
    _log('setBool prop=$prop valor=$v');
    final p = await SharedPreferences.getInstance();
    await p.setBool(_k(prop), v);
    await _notify();
  }

  static Future<void> setString(String prop, String v) async {
    final preview = v.length > 40 ? '${v.substring(0, 40)}...' : v;
    _log('setString prop=$prop valor=$preview');
    final p = await SharedPreferences.getInstance();
    await p.setString(_k(prop), v);
    await _notify();
  }

  /// Lee y elimina los logs nativos que el widget Kotlin escribió en SharedPreferences.
  /// Llamar periódicamente mientras el editor está abierto para verlos en flutter run.
  static Future<void> pollNativeLogs() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.reload(); // fuerza relecture desde disco
      final raw = p.getString('img_widget_log') ?? '';
      if (raw.isEmpty) return;
      await p.remove('img_widget_log');
      for (final line in raw.split('\n')) {
        if (line.trim().isEmpty) continue;
        // Formato: "<timestamp_ms>|<mensaje>"
        final sep = line.indexOf('|');
        final msg = sep >= 0 ? line.substring(sep + 1) : line;
        print('[img_widget_native] $msg');
      }
    } catch (_) {}
  }

  static Future<void> resetAll() async {
    final p = await SharedPreferences.getInstance();
    final keys = p.getKeys().where((k) => k.startsWith('widget_cfg_img_')).toList();
    for (final k in keys) await p.remove(k);
    await _notify();
  }

  static Future<void> _notify() async {
    final t0 = DateTime.now().millisecondsSinceEpoch;
    _log('notify → updateImageWidget t=$t0');
    try {
      await _channel.invokeMethod('updateImageWidget');
      _log('notify OK dt=${DateTime.now().millisecondsSinceEpoch - t0}ms');
    } catch (e) {
      _log('notify ERROR dt=${DateTime.now().millisecondsSinceEpoch - t0}ms: $e');
    }
  }

  // ── Selección de carpeta ──────────────────────────────────────────────────

  static const _imageExts = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp'];

  /// Selecciona carpeta, copia las imágenes al filesDir de la app (accesible
  /// por el widget sin permisos) y guarda las rutas internas.
  /// [onProgress] recibe (done, total).
  static Future<String?> pickFolderAndCopyImages({
    void Function((int, int))? onProgress,
  }) async {
    _log('pickFolder: abriendo selector de carpeta');
    final folderPath = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Seleccionar carpeta de imágenes',
    );
    if (folderPath == null) {
      _log('pickFolder: cancelado por el usuario');
      return null;
    }
    _log('pickFolder: carpeta=$folderPath');

    final dir = Directory(folderPath);
    final files = dir.listSync()
        .whereType<File>()
        .where((f) => _imageExts.any((ext) => f.path.toLowerCase().endsWith(ext)))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    _log('pickFolder: imágenes encontradas=${files.length}');
    if (files.isEmpty) return 'empty';

    String internalBase;
    try {
      final result = await _channel.invokeMethod<String>('getInternalFilesDir');
      internalBase = '${result!}/widget_images';
      _log('pickFolder: destDir=$internalBase');
    } catch (e) {
      _log('pickFolder: getInternalFilesDir ERROR $e');
      return 'error';
    }

    final destDir = Directory(internalBase);
    if (destDir.existsSync()) {
      for (final f in destDir.listSync().whereType<File>()) {
        try { f.deleteSync(); } catch (_) {}
      }
    } else {
      destDir.createSync(recursive: true);
    }

    final total = files.length;
    final destPaths = <String>[];

    for (int i = 0; i < files.length; i++) {
      onProgress?.call((i, total));
      final src = files[i];
      final ext = src.path.split('.').last.toLowerCase();
      final destPath = '$internalBase/${i.toString().padLeft(5, '0')}.$ext';
      try {
        src.copySync(destPath);
        destPaths.add(destPath);
      } catch (e) {
        _log('pickFolder: copy ERROR ${src.path} → $e');
      }
    }
    onProgress?.call((total, total));
    _log('pickFolder: copiadas=${destPaths.length}/$total');

    if (destPaths.isEmpty) return 'empty';

    final p = await SharedPreferences.getInstance();
    await p.setString(_k('folder_path'), folderPath);
    await p.setString(_k('file_list'), jsonEncode(destPaths));
    await p.setInt(_k('current_index'), 0);
    _log('pickFolder: prefs guardadas, llamando notify');
    await _notify();

    return null;
  }
}
