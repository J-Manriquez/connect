import 'package:connect/services/ble_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Describe un widget de pantalla de inicio configurable. Pensado para escalar:
/// cuando se añadan más widgets, basta con agregarlos a [WidgetConfigService.widgets].
class WidgetConfigSpec {
  final String id; // coincide con el sufijo del provider Kotlin: 'style2', 'style3'
  final String name;
  final String description;
  final int defaultProgressThicknessDp;

  /// true si el widget muestra el botón "abrir app de música por defecto".
  final bool hasDefaultAppButton;

  /// true si el widget permite ajustar el espacio entre filas (solo "con progreso").
  final bool hasRowSpacing;

  /// true si el widget soporta el modo "carátula como fondo" (solo "ancho").
  final bool hasArtBackground;

  const WidgetConfigSpec({
    required this.id,
    required this.name,
    required this.description,
    required this.defaultProgressThicknessDp,
    this.hasDefaultAppButton = false,
    this.hasRowSpacing = false,
    this.hasArtBackground = false,
  });
}

/// Snapshot mutable de la configuración de un widget. El editor trabaja sobre
/// una instancia de esta clase y persiste cada cambio con [WidgetConfigService].
class WidgetConfig {
  int contentScalePct;

  int titleSizeSp;
  int titleColor;
  bool titleBold;

  int subtitleSizeSp;
  int subtitleColor;
  bool subtitleBold;

  int timeSizeSp;
  int timeColor;
  bool timeBold;

  int bgNoImageArgb;
  int scrimArgb;
  int artAlpha;

  /// null = sin override (se usa blanco y NO se fuerza color de iconos nativos).
  int? iconColorArgb;
  int iconSizeDp; // 0 = tamaño original

  String iconPrev; // base64 PNG ('' = icono original)
  String iconPlay;
  String iconPause;
  String iconNext;
  String iconVolume;

  int barTrackArgb;
  int barFillArgb;
  int barProgressThicknessDp;
  int barVolumeThicknessDp;

  String noMediaTitle;
  String noMediaSubtitle;

  bool showDefaultAppBtn;
  int rowSpacingDp;
  bool artAsBackground;
  String artScaleType; // 'crop' | 'contain' | 'stretch' | 'center' | 'inside' | 'start' | 'end'

  WidgetConfig({
    required this.contentScalePct,
    required this.titleSizeSp,
    required this.titleColor,
    required this.titleBold,
    required this.subtitleSizeSp,
    required this.subtitleColor,
    required this.subtitleBold,
    required this.timeSizeSp,
    required this.timeColor,
    required this.timeBold,
    required this.bgNoImageArgb,
    required this.scrimArgb,
    required this.artAlpha,
    required this.iconColorArgb,
    required this.iconSizeDp,
    required this.iconPrev,
    required this.iconPlay,
    required this.iconPause,
    required this.iconNext,
    required this.iconVolume,
    required this.barTrackArgb,
    required this.barFillArgb,
    required this.barProgressThicknessDp,
    required this.barVolumeThicknessDp,
    required this.noMediaTitle,
    required this.noMediaSubtitle,
    required this.showDefaultAppBtn,
    required this.rowSpacingDp,
    required this.artAsBackground,
    required this.artScaleType,
  });
}

/// Lee y escribe la configuración de los widgets de música. Las claves usan el
/// formato `widget_cfg_<id>_<prop>` que el lado nativo lee como
/// `flutter.widget_cfg_<id>_<prop>` en [MediaWidgetProvider.kt]. Tras cada
/// escritura se refresca el widget local con [BleService.updateWidget].
class WidgetConfigService {
  static const List<WidgetConfigSpec> widgets = [
    WidgetConfigSpec(
      id: 'style2',
      name: 'Música (centrado)',
      description:
          'Título y subtítulo centrados, carátula de fondo y botón para abrir la app de música.',
      defaultProgressThicknessDp: 8,
      hasDefaultAppButton: true,
    ),
    WidgetConfigSpec(
      id: 'style3',
      name: 'Música (con progreso)',
      description:
          'Título a la izquierda y barra de progreso grande con tiempos (actual · app · total).',
      defaultProgressThicknessDp: 24,
      hasDefaultAppButton: true,
      hasRowSpacing: true,
    ),
    WidgetConfigSpec(
      id: 'wide',
      name: 'Música (ancho)',
      description:
          'Más ancho que alto: carátula a la izquierda y controles + volumen a la derecha.',
      defaultProgressThicknessDp: 8,
      hasDefaultAppButton: true,
      hasArtBackground: true,
    ),
  ];

  // Defaults espejo de los del Kotlin (readWidgetCfg).
  static const int defWhite = 0xFFFFFFFF;
  static const int defTitleSp = 33;
  static const int defSubtitleSp = 21;
  static const int defTimeSp = 18;
  static const int defBgNoImage = 0xFF000000;
  static const int defScrim = 0x80000000;
  static const int defArtAlpha = 255;
  static const int defBarTrack = 0x33FFFFFF;
  static const int defBarFill = 0xFFFFFFFF;
  static const int defVolThick = 28;
  static const String defNoMediaTitle = 'Sin reproducción';
  static const String defNoMediaSubtitle = 'Conecta el emisor para controlar';

  static WidgetConfigSpec specById(String id) =>
      widgets.firstWhere((w) => w.id == id, orElse: () => widgets.first);

  static String _k(String id, String prop) => 'widget_cfg_${id}_$prop';

  static Future<WidgetConfig> load(WidgetConfigSpec spec) async {
    final p = await SharedPreferences.getInstance();
    final id = spec.id;
    int gi(String prop, int def) => p.getInt(_k(id, prop)) ?? def;
    bool gb(String prop, bool def) => p.getBool(_k(id, prop)) ?? def;
    String gs(String prop, String def) {
      final v = p.getString(_k(id, prop));
      return (v == null || v.isEmpty) ? def : v;
    }

    return WidgetConfig(
      contentScalePct: gi('content_scale_pct', 100),
      titleSizeSp: gi('title_size_sp', defTitleSp),
      titleColor: gi('title_color_argb', defWhite),
      titleBold: gb('title_bold', true),
      subtitleSizeSp: gi('subtitle_size_sp', defSubtitleSp),
      subtitleColor: gi('subtitle_color_argb', defWhite),
      subtitleBold: gb('subtitle_bold', false),
      timeSizeSp: gi('time_size_sp', defTimeSp),
      timeColor: gi('time_color_argb', defWhite),
      timeBold: gb('time_bold', false),
      bgNoImageArgb: gi('bg_no_image_argb', defBgNoImage),
      scrimArgb: gi('scrim_argb', defScrim),
      artAlpha: gi('art_alpha', defArtAlpha),
      iconColorArgb:
          p.containsKey(_k(id, 'icon_color_argb')) ? gi('icon_color_argb', defWhite) : null,
      iconSizeDp: gi('icon_size_dp', 0),
      iconPrev: gs('icon_prev_b64', ''),
      iconPlay: gs('icon_play_b64', ''),
      iconPause: gs('icon_pause_b64', ''),
      iconNext: gs('icon_next_b64', ''),
      iconVolume: gs('icon_volume_b64', ''),
      barTrackArgb: gi('bar_track_argb', defBarTrack),
      barFillArgb: gi('bar_fill_argb', defBarFill),
      barProgressThicknessDp:
          gi('bar_progress_thickness_dp', spec.defaultProgressThicknessDp),
      barVolumeThicknessDp: gi('bar_volume_thickness_dp', defVolThick),
      noMediaTitle: gs('no_media_title', defNoMediaTitle),
      noMediaSubtitle: gs('no_media_subtitle', defNoMediaSubtitle),
      showDefaultAppBtn: gb('show_default_app_btn', true),
      rowSpacingDp: gi('row_spacing_dp', 0),
      artAsBackground: gb('art_as_background', false),
      artScaleType: gs('art_scale_type', 'crop'),
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
    if (value.isEmpty) {
      await p.remove(_k(id, prop));
    } else {
      await p.setString(_k(id, prop), value);
    }
    await _notify();
  }

  static Future<void> remove(String id, String prop) async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_k(id, prop));
    await _notify();
  }

  /// Borra TODA la configuración del widget (vuelve a los valores por defecto).
  static Future<void> resetAll(String id) async {
    final p = await SharedPreferences.getInstance();
    final prefix = 'widget_cfg_${id}_';
    final keys = p.getKeys().where((k) => k.startsWith(prefix)).toList();
    for (final k in keys) {
      await p.remove(k);
    }
    await _notify();
  }

  static Future<void> _notify() async {
    try {
      await BleService.updateWidget();
    } catch (_) {}
  }
}
