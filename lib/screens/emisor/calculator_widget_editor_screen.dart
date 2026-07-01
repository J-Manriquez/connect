import 'dart:convert';
import 'dart:typed_data';

import 'package:connect/services/calculator_style_service.dart';
import 'package:connect/widgets/calculator_widget_preview.dart';
import 'package:connect/widgets/color_input_widget.dart';
import 'package:connect/widgets/widget_icon_picker.dart';
import 'package:flutter/material.dart';

/// Editor de estilo del widget de calculadora. Preview fija arriba, pestañas de secciones.
class CalculatorWidgetEditorScreen extends StatefulWidget {
  const CalculatorWidgetEditorScreen({super.key});

  @override
  State<CalculatorWidgetEditorScreen> createState() =>
      _CalculatorWidgetEditorScreenState();
}

class _CalculatorWidgetEditorScreenState
    extends State<CalculatorWidgetEditorScreen> {
  CalculatorStyleConfig? _cfg;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cfg = await CalculatorStyleService.load();
    if (!mounted) return;
    setState(() => _cfg = cfg);
  }

  Future<void> _setInt(String prop, int v) =>
      CalculatorStyleService.setInt(prop, v);
  Future<void> _setString(String prop, String v) =>
      CalculatorStyleService.setString(prop, v);

  @override
  Widget build(BuildContext context) {
    final cfg = _cfg;
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Widget calculadora'),
          actions: [
            IconButton(
              tooltip: 'Restablecer',
              icon: const Icon(Icons.restore),
              onPressed: cfg == null ? null : _confirmReset,
            ),
          ],
        ),
        body: cfg == null
            ? const Center(child: CircularProgressIndicator())
            : NestedScrollView(
                headerSliverBuilder: (ctx, _) => [
                  SliverToBoxAdapter(child: _previewArea(cfg)),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _TabBarDelegate(
                      const TabBar(
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        tabs: [
                          Tab(text: 'Contorno'),
                          Tab(text: 'Display'),
                          Tab(text: 'Botones'),
                          Tab(text: 'Layout'),
                          Tab(text: 'Iconos'),
                        ],
                      ),
                    ),
                  ),
                ],
                body: TabBarView(
                  children: [
                    _tabPage([_contourSection(cfg)]),
                    _tabPage([_displaySection(cfg)]),
                    _tabPage([
                      _btnGroupSection('Números', cfg.numBgArgb, cfg.numTextColor,
                          cfg.numTextSizeSp, cfg.numRadius,
                          bgProp: 'num_bg_argb', textColorProp: 'num_text_color',
                          textSizeProp: 'num_text_size_sp', radiusProp: 'num_radius',
                          onBg: (v) => setState(() => cfg.numBgArgb = v),
                          onText: (v) => setState(() => cfg.numTextColor = v),
                          onSize: (v) => setState(() => cfg.numTextSizeSp = v),
                          onRadius: (v) => setState(() => cfg.numRadius = v)),
                      _btnGroupSection('Operadores  + − × ÷', cfg.opBgArgb, cfg.opTextColor,
                          cfg.opTextSizeSp, cfg.opRadius,
                          bgProp: 'op_bg_argb', textColorProp: 'op_text_color',
                          textSizeProp: 'op_text_size_sp', radiusProp: 'op_radius',
                          onBg: (v) => setState(() => cfg.opBgArgb = v),
                          onText: (v) => setState(() => cfg.opTextColor = v),
                          onSize: (v) => setState(() => cfg.opTextSizeSp = v),
                          onRadius: (v) => setState(() => cfg.opRadius = v)),
                      _btnGroupSection('Funciones  C ⌫ ( ) %', cfg.fnBgArgb, cfg.fnTextColor,
                          cfg.fnTextSizeSp, cfg.fnRadius,
                          bgProp: 'fn_bg_argb', textColorProp: 'fn_text_color',
                          textSizeProp: 'fn_text_size_sp', radiusProp: 'fn_radius',
                          onBg: (v) => setState(() => cfg.fnBgArgb = v),
                          onText: (v) => setState(() => cfg.fnTextColor = v),
                          onSize: (v) => setState(() => cfg.fnTextSizeSp = v),
                          onRadius: (v) => setState(() => cfg.fnRadius = v)),
                      _btnGroupSection('Igual  =', cfg.eqBgArgb, cfg.eqTextColor,
                          cfg.eqTextSizeSp, cfg.eqRadius,
                          bgProp: 'eq_bg_argb', textColorProp: 'eq_text_color',
                          textSizeProp: 'eq_text_size_sp', radiusProp: 'eq_radius',
                          onBg: (v) => setState(() => cfg.eqBgArgb = v),
                          onText: (v) => setState(() => cfg.eqTextColor = v),
                          onSize: (v) => setState(() => cfg.eqTextSizeSp = v),
                          onRadius: (v) => setState(() => cfg.eqRadius = v)),
                    ]),
                    _tabPage([_layoutSection(cfg)]),
                    _tabPage([_iconsSection(cfg)]),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _previewArea(CalculatorStyleConfig cfg) {
    return Container(
      width: double.infinity,
      color: Colors.grey.shade200,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      child: Column(
        children: [
          CalculatorWidgetPreview(cfg: cfg),
          const SizedBox(height: 4),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Vista previa',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _tabPage(List<Widget> children) => ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: children,
      );

  // ─── Secciones ───────────────────────────────────────────────────────────

  Widget _contourSection(CalculatorStyleConfig cfg) {
    return _card('Contorno del widget', [
      _colorTile('Color de fondo', cfg.bgArgb, withAlpha: false, onPicked: (v) {
        setState(() => cfg.bgArgb = v);
        _setInt('bg_argb', v);
      }),
      _sliderTile(
        label: 'Transparencia del fondo',
        value: cfg.bgAlpha.toDouble(),
        min: 0, max: 255, divisions: 51,
        display: '${(cfg.bgAlpha * 100 / 255).round()}%',
        onChanged: (v) => setState(() => cfg.bgAlpha = v.round()),
        onChangeEnd: (v) => _setInt('bg_alpha', v.round()),
      ),
      _sliderTile(
        label: 'Radio de esquinas del widget',
        value: cfg.borderRadius.toDouble(),
        min: 0, max: 48, divisions: 48,
        display: '${cfg.borderRadius}dp',
        onChanged: (v) => setState(() => cfg.borderRadius = v.round()),
        onChangeEnd: (v) => _setInt('border_radius', v.round()),
      ),
    ]);
  }

  Widget _displaySection(CalculatorStyleConfig cfg) {
    return _card('Área de display', [
      _colorTile('Color de fondo del display', cfg.displayBgArgb, withAlpha: true,
          onPicked: (v) {
        setState(() => cfg.displayBgArgb = v);
        _setInt('display_bg_argb', v);
      }),
      _sliderTile(
        label: 'Radio de esquinas del display',
        value: cfg.displayRadius.toDouble(),
        min: 0, max: 32, divisions: 32,
        display: '${cfg.displayRadius}dp',
        onChanged: (v) => setState(() => cfg.displayRadius = v.round()),
        onChangeEnd: (v) => _setInt('display_radius', v.round()),
      ),
      const Divider(),
      const Text('Expresión', style: TextStyle(fontWeight: FontWeight.w600)),
      _colorTile('Color de la expresión', cfg.exprColor, withAlpha: false,
          onPicked: (v) {
        setState(() => cfg.exprColor = v);
        _setInt('expr_color', v);
      }),
      _sliderTile(
        label: 'Tamaño de la expresión',
        value: cfg.exprSizeSp.toDouble(),
        min: 10, max: 50, divisions: 40,
        display: '${cfg.exprSizeSp}sp',
        onChanged: (v) => setState(() => cfg.exprSizeSp = v.round()),
        onChangeEnd: (v) => _setInt('expr_size_sp', v.round()),
      ),
      const Divider(),
      const Text('Resultado', style: TextStyle(fontWeight: FontWeight.w600)),
      _colorTile('Color del resultado', cfg.resultColor, withAlpha: false,
          onPicked: (v) {
        setState(() => cfg.resultColor = v);
        _setInt('result_color', v);
      }),
      _sliderTile(
        label: 'Tamaño del resultado',
        value: cfg.resultSizeSp.toDouble(),
        min: 16, max: 72, divisions: 56,
        display: '${cfg.resultSizeSp}sp',
        onChanged: (v) => setState(() => cfg.resultSizeSp = v.round()),
        onChangeEnd: (v) => _setInt('result_size_sp', v.round()),
      ),
      const Divider(),
      const Text('Botón de historial', style: TextStyle(fontWeight: FontWeight.w600)),
      _sliderTile(
        label: 'Radio de esquinas del botón de historial',
        value: cfg.histRadius.toDouble(),
        min: 0, max: 32, divisions: 32,
        display: '${cfg.histRadius}dp',
        onChanged: (v) => setState(() => cfg.histRadius = v.round()),
        onChangeEnd: (v) => _setInt('hist_radius', v.round()),
      ),
    ]);
  }

  Widget _btnGroupSection(
    String title,
    int bgArgb, int textColor, int textSizeSp, int radius, {
    required String bgProp, required String textColorProp,
    required String textSizeProp, required String radiusProp,
    required ValueChanged<int> onBg, required ValueChanged<int> onText,
    required ValueChanged<int> onSize, required ValueChanged<int> onRadius,
  }) {
    return _card(title, [
      _colorTile('Color de fondo', bgArgb, withAlpha: true, onPicked: (v) {
        onBg(v);
        _setInt(bgProp, v);
      }),
      _colorTile('Color de texto/icono', textColor, withAlpha: false,
          onPicked: (v) {
        onText(v);
        _setInt(textColorProp, v);
      }),
      _sliderTile(
        label: 'Tamaño de texto',
        value: textSizeSp.toDouble(),
        min: 10, max: 50, divisions: 40,
        display: '${textSizeSp}sp',
        onChanged: (v) => onSize(v.round()),
        onChangeEnd: (v) => _setInt(textSizeProp, v.round()),
      ),
      _sliderTile(
        label: 'Radio de esquinas',
        value: radius.toDouble(),
        min: 0, max: 32, divisions: 32,
        display: '${radius}dp',
        onChanged: (v) => onRadius(v.round()),
        onChangeEnd: (v) => _setInt(radiusProp, v.round()),
      ),
    ]);
  }

  Widget _layoutSection(CalculatorStyleConfig cfg) {
    return _card('Layout', [
      _sliderTile(
        label: 'Escala del contenido',
        value: cfg.contentScalePct.toDouble(),
        min: 50, max: 150, divisions: 20,
        display: '${cfg.contentScalePct}%',
        onChanged: (v) => setState(() => cfg.contentScalePct = v.round()),
        onChangeEnd: (v) => _setInt('content_scale_pct', v.round()),
      ),
      _sliderTile(
        label: 'Espaciado entre botones',
        value: cfg.btnSpacingDp.toDouble(),
        min: 0, max: 24, divisions: 24,
        display: '${cfg.btnSpacingDp}dp',
        onChanged: (v) => setState(() => cfg.btnSpacingDp = v.round()),
        onChangeEnd: (v) => _setInt('btn_spacing_dp', v.round()),
      ),
      _sliderTile(
        label: 'Padding del teclado',
        value: cfg.keypadPaddingDp.toDouble(),
        min: 0, max: 32, divisions: 32,
        display: '${cfg.keypadPaddingDp}dp',
        onChanged: (v) => setState(() => cfg.keypadPaddingDp = v.round()),
        onChangeEnd: (v) => _setInt('keypad_padding_dp', v.round()),
      ),
    ]);
  }

  Widget _iconsSection(CalculatorStyleConfig cfg) {
    return _card('Iconos de acción', [
      const Text(
        'Reemplaza los iconos de los botones de acción con imágenes personalizadas.',
        style: TextStyle(color: Colors.grey, fontSize: 12),
      ),
      const SizedBox(height: 8),
      _iconTile('Botón Igual (=)', cfg.iconEquals, 'icon_equals_b64',
          (b64) => setState(() => cfg.iconEquals = b64)),
      _iconTile('Borrar (⌫)', cfg.iconBackspace, 'icon_backspace_b64',
          (b64) => setState(() => cfg.iconBackspace = b64)),
      _iconTile('Historial', cfg.iconHistory, 'icon_history_b64',
          (b64) => setState(() => cfg.iconHistory = b64)),
    ]);
  }

  // ─── Controles reutilizables ─────────────────────────────────────────────

  Widget _card(String title, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            ...children,
          ],
        ),
      ),
    );
  }

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

  Widget _colorTile(String label, int argb,
      {required bool withAlpha, required ValueChanged<int> onPicked}) {
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
        final picked = await _showColorPicker(context,
            initialArgb: argb, withAlpha: withAlpha);
        if (picked != null) onPicked(picked);
      },
    );
  }

  Widget _iconTile(String label, String currentB64, String prop,
      ValueChanged<String> onChangedLocal) {
    final bytes = _decode(currentB64);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40, height: 40,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(8),
        ),
        child: bytes == null
            ? const Icon(Icons.calculate, color: Colors.white54, size: 18)
            : Image.memory(bytes, fit: BoxFit.contain),
      ),
      title: Text(label),
      subtitle: Text(bytes == null ? 'Original' : 'Personalizado',
          style: const TextStyle(color: Colors.grey, fontSize: 12)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        final result = await Navigator.push<Map<String, dynamic>?>(
          context,
          MaterialPageRoute(
            builder: (_) => WidgetIconPickerScreen(
              title: label,
              currentOverrideBase64: currentB64.isEmpty ? null : currentB64,
            ),
          ),
        );
        if (result == null) return;
        final action = (result['action'] ?? '').toString();
        if (action == 'use_default') {
          onChangedLocal('');
          await _setString(prop, '');
        } else if (action == 'override') {
          final png = (result['pngBase64'] ?? '').toString();
          if (png.isEmpty) return;
          onChangedLocal(png);
          await _setString(prop, png);
        }
      },
    );
  }

  Uint8List? _decode(String b64) {
    if (b64.trim().isEmpty) return null;
    try {
      return const Base64Decoder().convert(b64.replaceAll(RegExp(r'\s+'), ''));
    } catch (_) {
      return null;
    }
  }

  Future<void> _confirmReset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Restablecer estilo'),
        content: const Text(
            'Se borrará toda la personalización de la calculadora y volverá a los valores por defecto. ¿Continuar?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Restablecer')),
        ],
      ),
    );
    if (ok != true) return;
    await CalculatorStyleService.resetAll();
    await _load();
  }
}

// ─── Sliver para mantener TabBar fijo bajo la preview ───────────────────────

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  const _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext ctx, double shrinkOffset, bool overlapsContent) {
    return Material(
      color: Theme.of(ctx).scaffoldBackgroundColor,
      elevation: overlapsContent ? 2 : 0,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate old) => tabBar != old.tabBar;
}

// ─── Selector de color reutilizable (mismo patrón que widget_editor_screen) ─

Future<int?> _showColorPicker(
  BuildContext context, {
  required int initialArgb,
  required bool withAlpha,
}) {
  return showDialog<int>(
    context: context,
    builder: (context) {
      int rgb = initialArgb & 0x00FFFFFF;
      int alpha = (initialArgb >> 24) & 0xFF;
      return StatefulBuilder(
        builder: (context, setSt) {
          int current() =>
              withAlpha ? ((alpha << 24) | rgb) : (0xFF000000 | rgb);
          Widget dot(Color c) => InkWell(
                onTap: () => setSt(() => rgb = c.toARGB32() & 0x00FFFFFF),
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: Color(0xFF000000 | (c.toARGB32() & 0x00FFFFFF)),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.black26),
                  ),
                ),
              );
          return AlertDialog(
            title: const Text('Color'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: [
                      dot(Colors.white), dot(Colors.black),
                      dot(Colors.red), dot(Colors.green), dot(Colors.blue),
                      dot(Colors.orange), dot(Colors.purple),
                      dot(Colors.yellow), dot(Colors.cyan), dot(Colors.grey),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ColorInputWidget(
                    label: 'Hex / RGB',
                    initialColor:
                        '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}',
                    onColorChanged: (_) {},
                    onParsedColorChanged: (c) {
                      if (c == null) return;
                      setSt(() {
                        rgb = c.toARGB32() & 0x00FFFFFF;
                        final a = (c.toARGB32() >> 24) & 0xFF;
                        if (withAlpha && a != 0xFF) alpha = a;
                      });
                    },
                  ),
                  if (withAlpha) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Opacidad'),
                        Text('${(alpha * 100 / 255).round()}%',
                            style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                    Slider(
                      value: alpha.toDouble(), min: 0, max: 255, divisions: 51,
                      onChanged: (v) => setSt(() => alpha = v.round()),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Resultado: '),
                      Container(
                        width: 40, height: 26,
                        decoration: BoxDecoration(
                          color: Color(current()),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.black38),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar')),
              TextButton(
                  onPressed: () => Navigator.pop(context, current()),
                  child: const Text('Aceptar')),
            ],
          );
        },
      );
    },
  );
}
