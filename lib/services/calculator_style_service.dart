import 'package:connect/services/ble_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Snapshot mutable de la configuración visual de la calculadora.
/// Todos los colores son ARGB enteros (0xAARRGGBB).
class CalculatorStyleConfig {
  // ── Contorno del widget ──────────────────────────────────────────────────
  int bgArgb;
  int bgAlpha;       // 0–255 (opacidad del fondo)
  int borderRadius;  // dp, radio de esquinas del widget

  // ── Display (área de expresión + resultado) ──────────────────────────────
  int displayBgArgb;
  int displayRadius;
  int exprColor;
  int exprSizeSp;
  int resultColor;
  int resultSizeSp;

  // ── Botones: números ─────────────────────────────────────────────────────
  int numBgArgb;
  int numTextColor;
  int numTextSizeSp;
  int numRadius;

  // ── Botones: operadores (+ − × ÷) ───────────────────────────────────────
  int opBgArgb;
  int opTextColor;
  int opTextSizeSp;
  int opRadius;

  // ── Botones: funciones (C ⌫ ( ) %) ──────────────────────────────────────
  int fnBgArgb;
  int fnTextColor;
  int fnTextSizeSp;
  int fnRadius;

  // ── Botón igual (=) ─────────────────────────────────────────────────────
  int eqBgArgb;
  int eqTextColor;
  int eqTextSizeSp;
  int eqRadius;

  // ── Layout ───────────────────────────────────────────────────────────────
  int btnSpacingDp;
  int keypadPaddingDp;
  int contentScalePct;

  // ── Icono de historial ───────────────────────────────────────────────────
  int histRadius;   // radio de esquinas del botón de historial (ImageView cuadrado)

  // ── Iconos override (PNG base64, '' = original) ──────────────────────────
  String iconEquals;
  String iconBackspace;
  String iconHistory;

  CalculatorStyleConfig({
    required this.bgArgb,
    required this.bgAlpha,
    required this.borderRadius,
    required this.displayBgArgb,
    required this.displayRadius,
    required this.exprColor,
    required this.exprSizeSp,
    required this.resultColor,
    required this.resultSizeSp,
    required this.numBgArgb,
    required this.numTextColor,
    required this.numTextSizeSp,
    required this.numRadius,
    required this.opBgArgb,
    required this.opTextColor,
    required this.opTextSizeSp,
    required this.opRadius,
    required this.fnBgArgb,
    required this.fnTextColor,
    required this.fnTextSizeSp,
    required this.fnRadius,
    required this.eqBgArgb,
    required this.eqTextColor,
    required this.eqTextSizeSp,
    required this.eqRadius,
    required this.btnSpacingDp,
    required this.keypadPaddingDp,
    required this.contentScalePct,
    required this.histRadius,
    required this.iconEquals,
    required this.iconBackspace,
    required this.iconHistory,
  });
}

/// Persiste y carga la configuración visual de la calculadora.
/// Claves: `widget_cfg_calc_<prop>` → el nativo las lee con prefijo `flutter.`.
/// Tras cada escritura refresca el widget vía [BleService.updateCalculatorWidget].
class CalculatorStyleService {
  // ─── Defaults (ESPEJO DEL KOTLIN readCalcCfg) ────────────────────────────
  static const int defBgArgb           = 0xFF1C1C1E;
  static const int defBgAlpha          = 255;
  static const int defBorderRadius     = 20;
  static const int defDisplayBgArgb    = 0xFF2C2C2E;
  static const int defDisplayRadius    = 12;
  static const int defExprColor        = 0xFFAAAAAA;
  static const int defExprSizeSp       = 22;
  static const int defResultColor      = 0xFFFFFFFF;
  static const int defResultSizeSp     = 40;
  static const int defNumBgArgb        = 0xFF3A3A3C;
  static const int defNumTextColor     = 0xFFFFFFFF;
  static const int defNumTextSizeSp    = 26;
  static const int defNumRadius        = 12;
  static const int defOpBgArgb         = 0xFFFF9F0A;
  static const int defOpTextColor      = 0xFFFFFFFF;
  static const int defOpTextSizeSp     = 28;
  static const int defOpRadius         = 12;
  static const int defFnBgArgb         = 0xFF636366;
  static const int defFnTextColor      = 0xFFFFFFFF;
  static const int defFnTextSizeSp     = 22;
  static const int defFnRadius         = 12;
  static const int defEqBgArgb         = 0xFFFF9F0A;
  static const int defEqTextColor      = 0xFFFFFFFF;
  static const int defEqTextSizeSp     = 30;
  static const int defEqRadius         = 12;
  static const int defBtnSpacingDp     = 10;
  static const int defKeypadPaddingDp  = 12;
  static const int defContentScalePct  = 100;
  static const int defHistRadius       = 8;
  // ────────────────────────────────────────────────────────────────────────

  static const String _id = 'calc';
  static String _k(String prop) => 'widget_cfg_${_id}_$prop';

  static Future<CalculatorStyleConfig> load() async {
    final p = await SharedPreferences.getInstance();
    int gi(String prop, int def) => p.getInt(_k(prop)) ?? def;
    String gs(String prop) {
      final v = p.getString(_k(prop));
      return (v == null || v.isEmpty) ? '' : v;
    }

    return CalculatorStyleConfig(
      bgArgb:          gi('bg_argb',           defBgArgb),
      bgAlpha:         gi('bg_alpha',           defBgAlpha),
      borderRadius:    gi('border_radius',      defBorderRadius),
      displayBgArgb:   gi('display_bg_argb',    defDisplayBgArgb),
      displayRadius:   gi('display_radius',     defDisplayRadius),
      exprColor:       gi('expr_color',         defExprColor),
      exprSizeSp:      gi('expr_size_sp',       defExprSizeSp),
      resultColor:     gi('result_color',       defResultColor),
      resultSizeSp:    gi('result_size_sp',     defResultSizeSp),
      numBgArgb:       gi('num_bg_argb',        defNumBgArgb),
      numTextColor:    gi('num_text_color',     defNumTextColor),
      numTextSizeSp:   gi('num_text_size_sp',   defNumTextSizeSp),
      numRadius:       gi('num_radius',         defNumRadius),
      opBgArgb:        gi('op_bg_argb',         defOpBgArgb),
      opTextColor:     gi('op_text_color',      defOpTextColor),
      opTextSizeSp:    gi('op_text_size_sp',    defOpTextSizeSp),
      opRadius:        gi('op_radius',          defOpRadius),
      fnBgArgb:        gi('fn_bg_argb',         defFnBgArgb),
      fnTextColor:     gi('fn_text_color',      defFnTextColor),
      fnTextSizeSp:    gi('fn_text_size_sp',    defFnTextSizeSp),
      fnRadius:        gi('fn_radius',          defFnRadius),
      eqBgArgb:        gi('eq_bg_argb',         defEqBgArgb),
      eqTextColor:     gi('eq_text_color',      defEqTextColor),
      eqTextSizeSp:    gi('eq_text_size_sp',    defEqTextSizeSp),
      eqRadius:        gi('eq_radius',          defEqRadius),
      btnSpacingDp:    gi('btn_spacing_dp',     defBtnSpacingDp),
      keypadPaddingDp: gi('keypad_padding_dp',  defKeypadPaddingDp),
      contentScalePct: gi('content_scale_pct',  defContentScalePct),
      histRadius:    gi('hist_radius',          defHistRadius),
      iconEquals:    gs('icon_equals_b64'),
      iconBackspace: gs('icon_backspace_b64'),
      iconHistory:   gs('icon_history_b64'),
    );
  }

  static Future<void> setInt(String prop, int value) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_k(prop), value);
    await _notify();
  }

  static Future<void> setString(String prop, String value) async {
    final p = await SharedPreferences.getInstance();
    if (value.isEmpty) {
      await p.remove(_k(prop));
    } else {
      await p.setString(_k(prop), value);
    }
    await _notify();
  }

  static Future<void> remove(String prop) async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_k(prop));
    await _notify();
  }

  static Future<void> resetAll() async {
    final p = await SharedPreferences.getInstance();
    final prefix = 'widget_cfg_${_id}_';
    final keys = p.getKeys().where((k) => k.startsWith(prefix)).toList();
    for (final k in keys) {
      await p.remove(k);
    }
    await _notify();
  }

  static Future<void> _notify() async {
    try {
      await BleService.updateCalculatorWidget();
    } catch (_) {}
  }
}
