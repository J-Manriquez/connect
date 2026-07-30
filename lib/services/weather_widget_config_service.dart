import 'package:shared_preferences/shared_preferences.dart';

import 'package:connect/services/weather_store.dart';

/// Modos de fondo del widget de clima.
enum WeatherBgMode { dynamic, solid, gradient }

/// Snapshot mutable de la personalización del widget de clima. El editor muta
/// una instancia y persiste cada cambio con [WeatherWidgetConfigService].
class WeatherWidgetConfig {
  // Cabecera
  int cityLabelSizeSp;
  int cityLabelColorArgb;
  bool cityLabelBold;
  bool showLocationPin;
  int viewLabelSizeSp;
  int viewLabelColorArgb;

  // Vista "Ahora"
  int tempSizeSp;
  int tempColorArgb;
  bool tempBold;
  int descSizeSp;
  int descColorArgb;
  int apparentSizeSp;
  int apparentColorArgb;
  int emojiSizeSp;
  int statSizeSp;
  int statColorArgb;

  // Filas de listas (por horas / por días)
  int rowLabelSizeSp;
  int rowLabelColorArgb;
  int rowEmojiSizeSp;
  int rowValueSizeSp;
  int rowValueColorArgb;
  bool rowValueBold;
  int rowPpSizeSp;
  int rowPpColorArgb;
  int rowSpacingDp;

  // Indicadores de página y flechas de navegación.
  // ◀ ▶ visibles en app y widget nativo; ▲ ▼ en ambos desde ahora.
  int dotSizeDp;
  int dotActiveColorArgb;
  int dotInactiveColorArgb;
  int arrowColorArgb;
  int arrowSizeSp;
  int scrollArrowSizeSp;

  // Iconos personalizados por categoría climática (PNG en base64).
  // null → usa el icono por defecto de Flutter.
  String? iconClearDayPng;
  String? iconClearNightPng;
  String? iconCloudsPng;
  String? iconFogPng;
  String? iconRainPng;
  String? iconSnowPng;
  String? iconThunderPng;

  // Iconos personalizados de las flechas de navegación (solo app).
  // null → usa el carácter de texto por defecto (◀ ▶ ▲ ▼).
  String? arrowPrevPng;
  String? arrowNextPng;
  String? arrowUpPng;
  String? arrowDownPng;

  // Fondo
  WeatherBgMode bgMode;
  int bgSolidArgb;
  int bgGradientTopArgb;
  int bgGradientBottomArgb;
  int bgDarkenPct; // 0-80, oscurece el fondo mezclándolo hacia negro
  int cornerRadiusDp;
  bool animatedBgEnabled; // solo afecta a la app (el widget nativo es estático)

  // Animación de frames en el widget nativo (solo modo dinámico).
  // 1 = solo el frame t=0 (sin animación); >1 = N frames animados.
  int animFrameCount;
  // 0 = ping-pong (1-2-3-2-1), 1 = loop (1-2-3-1-2-3).
  int animLoopMode;
  // 0 = toque en el widget, 1 = foco de pantalla (desbloqueo), 2 = ambos.
  int animTrigger;

  WeatherWidgetConfig({
    required this.cityLabelSizeSp,
    required this.cityLabelColorArgb,
    required this.cityLabelBold,
    required this.showLocationPin,
    required this.viewLabelSizeSp,
    required this.viewLabelColorArgb,
    required this.tempSizeSp,
    required this.tempColorArgb,
    required this.tempBold,
    required this.descSizeSp,
    required this.descColorArgb,
    required this.apparentSizeSp,
    required this.apparentColorArgb,
    required this.emojiSizeSp,
    required this.statSizeSp,
    required this.statColorArgb,
    required this.rowLabelSizeSp,
    required this.rowLabelColorArgb,
    required this.rowEmojiSizeSp,
    required this.rowValueSizeSp,
    required this.rowValueColorArgb,
    required this.rowValueBold,
    required this.rowPpSizeSp,
    required this.rowPpColorArgb,
    required this.rowSpacingDp,
    required this.dotSizeDp,
    required this.dotActiveColorArgb,
    required this.dotInactiveColorArgb,
    required this.arrowColorArgb,
    required this.arrowSizeSp,
    required this.scrollArrowSizeSp,
    this.iconClearDayPng,
    this.iconClearNightPng,
    this.iconCloudsPng,
    this.iconFogPng,
    this.iconRainPng,
    this.iconSnowPng,
    this.iconThunderPng,
    this.arrowPrevPng,
    this.arrowNextPng,
    this.arrowUpPng,
    this.arrowDownPng,
    required this.bgMode,
    required this.bgSolidArgb,
    required this.bgGradientTopArgb,
    required this.bgGradientBottomArgb,
    required this.bgDarkenPct,
    required this.cornerRadiusDp,
    required this.animatedBgEnabled,
    required this.animFrameCount,
    required this.animLoopMode,
    required this.animTrigger,
  });
}

/// Lee y escribe la personalización del widget de clima. Claves con el formato
/// `weather_widget_cfg_<prop>`, que el lado nativo lee como
/// `flutter.weather_widget_cfg_<prop>` en `WeatherWidgetProvider.kt`. Tras cada
/// escritura se refresca el widget nativo.
class WeatherWidgetConfigService {
  static const String _prefix = 'weather_widget_cfg_';

  // ===== Defaults (ESPEJO de WeatherWidgetProvider.kt readWeatherWidgetCfg) =====
  static const int defWhite = 0xFFFFFFFF;
  static const int defWhite70 = 0xB3FFFFFF;
  static const int defWhite40 = 0x66FFFFFF;
  static const int defDotOff = 0x5CFFFFFF;
  static const int defPpColor = 0xFF80D8FF;

  static const int defCityLabelSizeSp = 16;
  static const int defCityLabelColorArgb = defWhite;
  static const bool defCityLabelBold = true;
  static const bool defShowLocationPin = true;
  static const int defViewLabelSizeSp = 12;
  static const int defViewLabelColorArgb = defWhite70;

  static const int defTempSizeSp = 48;
  static const int defTempColorArgb = defWhite;
  static const bool defTempBold = false;
  static const int defDescSizeSp = 15;
  static const int defDescColorArgb = defWhite;
  static const int defApparentSizeSp = 13;
  static const int defApparentColorArgb = defWhite70;
  static const int defEmojiSizeSp = 50;
  static const int defStatSizeSp = 13;
  static const int defStatColorArgb = defWhite;

  static const int defRowLabelSizeSp = 13;
  static const int defRowLabelColorArgb = defWhite;
  static const int defRowEmojiSizeSp = 18;
  static const int defRowValueSizeSp = 14;
  static const int defRowValueColorArgb = defWhite;
  static const bool defRowValueBold = true;
  static const int defRowPpSizeSp = 12;
  static const int defRowPpColorArgb = defPpColor;
  static const int defRowSpacingDp = 3;

  static const int defDotSizeDp = 6;
  static const int defDotActiveColorArgb = defWhite;
  static const int defDotInactiveColorArgb = defDotOff;
  static const int defArrowColorArgb = defWhite;
  static const int defArrowSizeSp = 16;
  static const int defScrollArrowSizeSp = 14;

  static const WeatherBgMode defBgMode = WeatherBgMode.dynamic;
  static const int defBgSolidArgb = 0xFF2C3E73;
  static const int defBgGradientTopArgb = 0xFF4A6FA5;
  static const int defBgGradientBottomArgb = 0xFF2C3E73;
  static const int defBgDarkenPct = 0;
  static const int defCornerRadiusDp = 20;
  static const bool defAnimatedBgEnabled = true;
  static const int defAnimFrameCount = 1;
  static const int defAnimLoopMode = 0;
  static const int defAnimTrigger = 0;

  static String _k(String prop) => '$_prefix$prop';

  static Future<WeatherWidgetConfig> load() async {
    final p = await SharedPreferences.getInstance();
    int gi(String prop, int def) => p.getInt(_k(prop)) ?? def;
    bool gb(String prop, bool def) => p.getBool(_k(prop)) ?? def;

    final modeIdx = gi('bg_mode', defBgMode.index)
        .clamp(0, WeatherBgMode.values.length - 1);

    return WeatherWidgetConfig(
      cityLabelSizeSp: gi('city_label_size_sp', defCityLabelSizeSp),
      cityLabelColorArgb: gi('city_label_color_argb', defCityLabelColorArgb),
      cityLabelBold: gb('city_label_bold', defCityLabelBold),
      showLocationPin: gb('show_location_pin', defShowLocationPin),
      viewLabelSizeSp: gi('view_label_size_sp', defViewLabelSizeSp),
      viewLabelColorArgb: gi('view_label_color_argb', defViewLabelColorArgb),
      tempSizeSp: gi('temp_size_sp', defTempSizeSp),
      tempColorArgb: gi('temp_color_argb', defTempColorArgb),
      tempBold: gb('temp_bold', defTempBold),
      descSizeSp: gi('desc_size_sp', defDescSizeSp),
      descColorArgb: gi('desc_color_argb', defDescColorArgb),
      apparentSizeSp: gi('apparent_size_sp', defApparentSizeSp),
      apparentColorArgb: gi('apparent_color_argb', defApparentColorArgb),
      emojiSizeSp: gi('emoji_size_sp', defEmojiSizeSp),
      statSizeSp: gi('stat_size_sp', defStatSizeSp),
      statColorArgb: gi('stat_color_argb', defStatColorArgb),
      rowLabelSizeSp: gi('row_label_size_sp', defRowLabelSizeSp),
      rowLabelColorArgb: gi('row_label_color_argb', defRowLabelColorArgb),
      rowEmojiSizeSp: gi('row_emoji_size_sp', defRowEmojiSizeSp),
      rowValueSizeSp: gi('row_value_size_sp', defRowValueSizeSp),
      rowValueColorArgb: gi('row_value_color_argb', defRowValueColorArgb),
      rowValueBold: gb('row_value_bold', defRowValueBold),
      rowPpSizeSp: gi('row_pp_size_sp', defRowPpSizeSp),
      rowPpColorArgb: gi('row_pp_color_argb', defRowPpColorArgb),
      rowSpacingDp: gi('row_spacing_dp', defRowSpacingDp),
      dotSizeDp: gi('dot_size_dp', defDotSizeDp),
      dotActiveColorArgb: gi('dot_active_color_argb', defDotActiveColorArgb),
      dotInactiveColorArgb:
          gi('dot_inactive_color_argb', defDotInactiveColorArgb),
      arrowColorArgb: gi('arrow_color_argb', defArrowColorArgb),
      arrowSizeSp: gi('arrow_size_sp', defArrowSizeSp),
      scrollArrowSizeSp: gi('scroll_arrow_size_sp', defScrollArrowSizeSp),
      iconClearDayPng: p.getString(_k('icon_clear_day_png')),
      iconClearNightPng: p.getString(_k('icon_clear_night_png')),
      iconCloudsPng: p.getString(_k('icon_clouds_png')),
      iconFogPng: p.getString(_k('icon_fog_png')),
      iconRainPng: p.getString(_k('icon_rain_png')),
      iconSnowPng: p.getString(_k('icon_snow_png')),
      iconThunderPng: p.getString(_k('icon_thunder_png')),
      arrowPrevPng: p.getString(_k('arrow_prev_png')),
      arrowNextPng: p.getString(_k('arrow_next_png')),
      arrowUpPng: p.getString(_k('arrow_up_png')),
      arrowDownPng: p.getString(_k('arrow_down_png')),
      bgMode: WeatherBgMode.values[modeIdx],
      bgSolidArgb: gi('bg_solid_argb', defBgSolidArgb),
      bgGradientTopArgb: gi('bg_gradient_top_argb', defBgGradientTopArgb),
      bgGradientBottomArgb:
          gi('bg_gradient_bottom_argb', defBgGradientBottomArgb),
      bgDarkenPct: gi('bg_darken_pct', defBgDarkenPct).clamp(0, 80),
      cornerRadiusDp: gi('corner_radius_dp', defCornerRadiusDp),
      animatedBgEnabled: gb('animated_bg_enabled', defAnimatedBgEnabled),
      animFrameCount: gi('anim_frame_count', defAnimFrameCount).clamp(1, 36),
      animLoopMode: gi('anim_loop_mode', defAnimLoopMode).clamp(0, 1),
      animTrigger: gi('anim_trigger', defAnimTrigger).clamp(0, 2),
    );
  }

  static Future<void> setInt(String prop, int value) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_k(prop), value);
    await _notify();
  }

  static Future<void> setBool(String prop, bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_k(prop), value);
    await _notify();
  }

  /// Persiste un icono personalizado (base64 PNG) para una categoría climática.
  /// [categoryKey] es uno de: clear_day, clear_night, clouds, fog, rain, snow, thunder.
  static Future<void> setIcon(String categoryKey, String pngBase64) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_k('icon_${categoryKey}_png'), pngBase64);
    await _notify();
  }

  /// Persiste el icono de una flecha (base64 PNG).
  /// [arrowKey] es uno de: arrow_prev, arrow_next, arrow_up, arrow_down.
  static Future<void> setArrow(String arrowKey, String pngBase64) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_k('${arrowKey}_png'), pngBase64);
    await _notify();
  }

  /// Elimina el icono de flecha personalizado (vuelve al carácter por defecto).
  static Future<void> clearArrow(String arrowKey) async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_k('${arrowKey}_png'));
    await _notify();
  }

  /// Elimina el icono personalizado de una categoría (vuelve al por defecto).
  static Future<void> clearIcon(String categoryKey) async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_k('icon_${categoryKey}_png'));
    await _notify();
  }

  /// Borra TODA la personalización (vuelve a los valores por defecto).
  static Future<void> resetAll() async {
    final p = await SharedPreferences.getInstance();
    final keys = p.getKeys().where((k) => k.startsWith(_prefix)).toList();
    for (final k in keys) {
      await p.remove(k);
    }
    await _notify();
  }

  static Future<void> _notify() async {
    // El widget nativo lee la misma config; solo hace falta repintar (los
    // datos del clima no cambian al ajustar estilos).
    await WeatherStore.notifyWidget();
  }
}
