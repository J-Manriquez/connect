import 'dart:convert';
import 'dart:typed_data';

import 'package:connect/services/calculator_style_service.dart';
import 'package:flutter/material.dart';

/// Vista previa del widget de calculadora. Coincide con el layout nativo RemoteViews.
///
/// Diferencias respecto a RemoteViews que aquí se replican fielmente:
/// - Botones texto (dígitos, ops, fn, .): fondo plano (sin radius) — igual que nativo donde
///   setBackgroundColor no admite esquinas redondeadas sobre TextView.
/// - Display: esquinas superiores redondeadas = cfg.borderRadius (bitmap compuesto en nativo).
/// - Botón 0 (bottom-left): esquina inferior-izquierda = cfg.borderRadius.
/// - Botón = (bottom-right): esquina inferior-derecha = cfg.borderRadius.
/// - Botón historial (ImageView cuadrado): radius = cfg.histRadius (bitmap compuesto en nativo).
/// - ⌫ (ImageView rectangular): fondo plano.
/// - Padding horizontal del teclado = 0; vertical = cfg.keypadPaddingDp.
class CalculatorWidgetPreview extends StatelessWidget {
  final CalculatorStyleConfig cfg;

  const CalculatorWidgetPreview({super.key, required this.cfg});

  double get _scale => (cfg.contentScalePct / 100).clamp(0.5, 2.0);
  double get _br => cfg.borderRadius.toDouble();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 220 * _scale,
        color: Color(cfg.bgArgb).withAlpha(cfg.bgAlpha),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _display(),
            Padding(
              padding: EdgeInsets.only(
                top: cfg.keypadPaddingDp.toDouble() * _scale,
                bottom: 0,
                left: 0,
                right: 0,
              ),
              child: Column(
                children: [
                  _row(['(', ')', 'C', '÷'], _fnStyle, _opStyle, lastIsOp: true),
                  SizedBox(height: cfg.btnSpacingDp.toDouble() * _scale),
                  _row(['7', '8', '9', '×'], _numStyle, _opStyle, lastIsOp: true),
                  SizedBox(height: cfg.btnSpacingDp.toDouble() * _scale),
                  _row(['4', '5', '6', '−'], _numStyle, _opStyle, lastIsOp: true),
                  SizedBox(height: cfg.btnSpacingDp.toDouble() * _scale),
                  _row(['1', '2', '3', '+'], _numStyle, _opStyle, lastIsOp: true),
                  SizedBox(height: cfg.btnSpacingDp.toDouble() * _scale),
                  _bottomRow(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _display() {
    // Esquinas superiores redondeadas con cfg.borderRadius (espejo del bitmap en nativo).
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 6 * _scale, vertical: 6 * _scale),
      decoration: BoxDecoration(
        color: Color(cfg.displayBgArgb),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(_br),
          topRight: Radius.circular(_br),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: _historyBtn(),
          ),
          SizedBox(height: 4 * _scale),
          Text(
            '1 + 2 × (3 − 4)',
            style: TextStyle(
              color: Color(cfg.exprColor),
              fontSize: (cfg.exprSizeSp * _scale).clamp(10, 60),
            ),
            textAlign: TextAlign.end,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '−1',
            style: TextStyle(
              color: Color(cfg.resultColor),
              fontSize: (cfg.resultSizeSp * _scale).clamp(12, 80),
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.end,
          ),
        ],
      ),
    );
  }

  Widget _historyBtn() {
    final bytes = _decode(cfg.iconHistory);
    final h = (32 * _scale).clamp(20.0, 48.0);
    return Container(
      width: h, height: h,
      decoration: BoxDecoration(
        color: Color(cfg.fnBgArgb),
        borderRadius: BorderRadius.circular(cfg.histRadius.toDouble()),
      ),
      child: Center(
        child: bytes != null
            ? Image.memory(bytes, width: h * 0.6, height: h * 0.6, fit: BoxFit.contain)
            : Icon(Icons.history, color: Color(cfg.fnTextColor), size: h * 0.6),
      ),
    );
  }

  Widget _row(List<String> labels, _BtnStyle numS, _BtnStyle opS,
      {bool lastIsOp = false}) {
    return Row(
      children: List.generate(labels.length, (i) {
        final isLast = i == labels.length - 1;
        final style = (lastIsOp && isLast) ? opS : numS;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: i == 0 ? 0 : cfg.btnSpacingDp / 2 * _scale,
              right: isLast ? 0 : cfg.btnSpacingDp / 2 * _scale,
            ),
            child: _calcBtn(labels[i], style),
          ),
        );
      }),
    );
  }

  Widget _bottomRow() {
    final spacing = cfg.btnSpacingDp.toDouble() * _scale;
    return Row(
      children: [
        // 0: primera celda, sin padding izquierdo, esquina inferior-izquierda = borderRadius
        Expanded(
          child: _calcBtn(
            '0', _numStyle,
            radius: BorderRadius.only(
              bottomLeft: Radius.circular(_br),
            ),
          ),
        ),
        SizedBox(width: spacing),
        Expanded(child: _calcBtn('.', _fnStyle)),
        SizedBox(width: spacing),
        // ⌫: ImageView rectangular en nativo → fondo plano
        Expanded(child: _backspaceBtn()),
        SizedBox(width: spacing),
        // =: esquina inferior-derecha = borderRadius
        Expanded(
          child: _calcBtn(
            '=', _eqStyle,
            radius: BorderRadius.only(
              bottomRight: Radius.circular(_br),
            ),
          ),
        ),
      ],
    );
  }

  // Botones de texto: planos salvo la esquina específica indicada.
  Widget _calcBtn(String label, _BtnStyle s, {BorderRadius? radius}) {
    final h = (44 * _scale).clamp(28.0, 80.0);
    return Container(
      height: h,
      decoration: BoxDecoration(
        color: Color(s.bgArgb),
        borderRadius: radius,
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: Color(s.textColor),
            fontSize: (s.textSizeSp * _scale).clamp(10, 50),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _backspaceBtn() {
    final h = (44 * _scale).clamp(28.0, 80.0);
    final bytes = _decode(cfg.iconBackspace);
    return Container(
      height: h,
      color: Color(cfg.fnBgArgb),
      child: Center(
        child: bytes != null
            ? Image.memory(bytes,
                width: h * 0.5, height: h * 0.5, fit: BoxFit.contain)
            : Icon(Icons.backspace_outlined,
                color: Color(cfg.fnTextColor),
                size: (cfg.fnTextSizeSp * _scale).clamp(10, 40)),
      ),
    );
  }

  _BtnStyle get _numStyle =>
      _BtnStyle(cfg.numBgArgb, cfg.numTextColor, cfg.numTextSizeSp);
  _BtnStyle get _opStyle =>
      _BtnStyle(cfg.opBgArgb, cfg.opTextColor, cfg.opTextSizeSp);
  _BtnStyle get _fnStyle =>
      _BtnStyle(cfg.fnBgArgb, cfg.fnTextColor, cfg.fnTextSizeSp);
  _BtnStyle get _eqStyle =>
      _BtnStyle(cfg.eqBgArgb, cfg.eqTextColor, cfg.eqTextSizeSp);

  Uint8List? _decode(String b64) {
    if (b64.trim().isEmpty) return null;
    try {
      return const Base64Decoder().convert(b64.replaceAll(RegExp(r'\s+'), ''));
    } catch (_) {
      return null;
    }
  }
}

class _BtnStyle {
  final int bgArgb, textColor, textSizeSp;
  const _BtnStyle(this.bgArgb, this.textColor, this.textSizeSp);
}
