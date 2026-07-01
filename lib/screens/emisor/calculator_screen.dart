import 'package:connect/services/calculator_engine.dart';
import 'package:connect/services/calculator_history_store.dart';
import 'package:connect/services/calculator_style_service.dart';
import 'package:flutter/material.dart';

/// Calculadora completa in-app. Comparte estilo con el widget de pantalla de inicio
/// y el historial con él (shared_preferences). Aquí además se puede renombrar,
/// editar y eliminar entradas del historial (lo que el widget nativo no admite).
class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  CalculatorStyleConfig? _cfg;
  List<CalcHistoryEntry> _history = [];

  String _expr = '';         // expresión en curso
  String _display = '0';    // resultado o expresión mostrada en el display
  bool _justEvaluated = false; // evita añadir al historial dos veces
  bool _showHistory = false; // panel historial visible

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final cfg = await CalculatorStyleService.load();
    final history = await CalculatorHistoryStore.loadAll();
    if (!mounted) return;
    setState(() {
      _cfg = cfg;
      _history = history;
    });
  }

  Future<void> _reloadHistory() async {
    final h = await CalculatorHistoryStore.loadAll();
    if (!mounted) return;
    setState(() => _history = h);
  }

  // ─── Lógica de calculadora ────────────────────────────────────────────────

  void _onKey(String key) {
    setState(() {
      if (_justEvaluated && _isDigitOrDot(key)) {
        // Nueva operación: limpia la expresión anterior
        _expr = key == '.' ? '0.' : key;
        _display = _expr;
        _justEvaluated = false;
        return;
      }
      if (_justEvaluated && _isOp(key)) {
        // Continuar operando sobre el resultado
        _expr = _display + key;
        _display = _expr;
        _justEvaluated = false;
        return;
      }
      _justEvaluated = false;

      if (key == 'C' || key == 'AC') {
        _expr = '';
        _display = '0';
        return;
      }
      if (key == '⌫') {
        if (_expr.isNotEmpty) {
          _expr = _expr.substring(0, _expr.length - 1);
        }
        _display = _expr.isEmpty ? '0' : _expr;
        return;
      }
      if (key == '=') {
        if (_expr.trim().isEmpty) return;
        final result = CalculatorEngine.evaluate(_expr);
        _commitToHistory(_expr, result);
        _display = result;
        _justEvaluated = true;
        return;
      }
      _expr += key;
      _display = _expr;
    });
  }

  bool _isDigitOrDot(String k) =>
      RegExp(r'^[0-9.]$').hasMatch(k);

  bool _isOp(String k) => '+-×÷−+'.contains(k) || k == '(' || k == ')';

  Future<void> _commitToHistory(String expr, String result) async {
    if (result == 'Error') return;
    await CalculatorHistoryStore.append(expr, result);
    await _reloadHistory();
  }

  void _loadFromHistory(CalcHistoryEntry entry) {
    setState(() {
      _expr = entry.result;
      _display = entry.result;
      _justEvaluated = true;
      _showHistory = false;
    });
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cfg = _cfg;
    if (cfg == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final scale = (cfg.contentScalePct / 100).clamp(0.5, 2.0);

    return Scaffold(
      backgroundColor: Color(cfg.bgArgb).withAlpha(cfg.bgAlpha),
      appBar: AppBar(
        title: const Text('Calculadora'),
        backgroundColor: Color(cfg.bgArgb),
        foregroundColor: Color(cfg.resultColor),
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Display
            _buildDisplay(cfg, scale),
            // Panel de historial o teclado
            Expanded(
              child: _showHistory
                  ? _buildHistoryPanel(cfg, scale)
                  : _buildKeypad(cfg, scale),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisplay(CalculatorStyleConfig cfg, double scale) {
    // Altura fija: 1/3 menos que el máximo anterior (240 → 160). Sin toggle de expansión.
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        minHeight: 140 * scale,
        maxHeight: 160 * scale,
      ),
      decoration: BoxDecoration(
        color: Color(cfg.displayBgArgb),
        borderRadius: BorderRadius.circular(cfg.displayRadius.toDouble()),
      ),
      padding: EdgeInsets.symmetric(
          horizontal: 16 * scale, vertical: 8 * scale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: Icon(Icons.history,
                  color: Color(cfg.fnTextColor), size: 22 * scale),
              onPressed: () => setState(() => _showHistory = !_showHistory),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
          const Spacer(),
          SingleChildScrollView(
            reverse: true,
            scrollDirection: Axis.vertical,
            child: Text(
              _expr.isEmpty ? '' : _expr,
              style: TextStyle(
                color: Color(cfg.exprColor),
                fontSize: (cfg.exprSizeSp * scale).clamp(10.0, 60.0),
              ),
              textAlign: TextAlign.end,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            _display,
            style: TextStyle(
              color: Color(cfg.resultColor),
              fontSize: (cfg.resultSizeSp * scale).clamp(16.0, 80.0),
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildKeypad(CalculatorStyleConfig cfg, double scale) {
    final sp = cfg.btnSpacingDp * scale;
    final pad = cfg.keypadPaddingDp * scale;
    return Padding(
      padding: EdgeInsets.all(pad),
      child: Column(
        children: [
          _keyRow(['(', ')', 'C', '÷'], cfg, scale, lastIsOp: true),
          SizedBox(height: sp),
          _keyRow(['7', '8', '9', '×'], cfg, scale, lastIsOp: true),
          SizedBox(height: sp),
          _keyRow(['4', '5', '6', '−'], cfg, scale, lastIsOp: true),
          SizedBox(height: sp),
          _keyRow(['1', '2', '3', '+'], cfg, scale, lastIsOp: true),
          SizedBox(height: sp),
          _bottomKeyRow(cfg, scale),
        ],
      ),
    );
  }

  Widget _keyRow(List<String> keys, CalculatorStyleConfig cfg, double scale,
      {bool lastIsOp = false}) {
    final sp = cfg.btnSpacingDp * scale;
    return Expanded(
      child: Row(
        children: List.generate(keys.length, (i) {
          final isOp = lastIsOp && i == keys.length - 1;
          final style = isOp ? _opStyle(cfg) : _isFn(keys[i])
              ? _fnStyle(cfg)
              : _numStyle(cfg);
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                left: i == 0 ? 0 : sp / 2,
                right: i == keys.length - 1 ? 0 : sp / 2,
              ),
              child: _calcButton(keys[i], style, scale, onTap: () => _onKey(keys[i])),
            ),
          );
        }),
      ),
    );
  }

  Widget _bottomKeyRow(CalculatorStyleConfig cfg, double scale) {
    final sp = cfg.btnSpacingDp * scale;
    return Expanded(
      child: Row(
        children: [
          Expanded(child: _calcButton('0', _numStyle(cfg), scale,
              onTap: () => _onKey('0'))),
          SizedBox(width: sp),
          Expanded(child: _calcButton('.', _fnStyle(cfg), scale,
              onTap: () => _onKey('.'))),
          SizedBox(width: sp),
          Expanded(
            child: _iconCalcButton(
              Icons.backspace_outlined,
              _fnStyle(cfg), scale,
              onTap: () => _onKey('⌫'),
            ),
          ),
          SizedBox(width: sp),
          Expanded(
            child: _calcButton('=', _eqStyle(cfg), scale,
                onTap: () => _onKey('=')),
          ),
        ],
      ),
    );
  }

  bool _isFn(String k) =>
      k == 'C' || k == 'AC' || k == '.' || k == '(' || k == ')';

  Widget _calcButton(String label, _BtnS style, double scale,
      {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Color(style.bg),
          borderRadius: BorderRadius.circular(style.radius.toDouble()),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: Color(style.fg),
              fontSize: (style.sz * scale).clamp(10.0, 50.0),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconCalcButton(IconData icon, _BtnS style, double scale,
      {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Color(style.bg),
          borderRadius: BorderRadius.circular(style.radius.toDouble()),
        ),
        child: Center(
          child: Icon(icon,
              color: Color(style.fg),
              size: (style.sz * scale).clamp(10.0, 40.0)),
        ),
      ),
    );
  }

  // ─── Panel de historial ───────────────────────────────────────────────────

  Widget _buildHistoryPanel(CalculatorStyleConfig cfg, double scale) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Text('Historial',
                  style: TextStyle(
                      color: Color(cfg.resultColor),
                      fontSize: 18 * scale,
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              if (_history.isNotEmpty)
                TextButton(
                  onPressed: _confirmClearAll,
                  child: const Text('Borrar todo',
                      style: TextStyle(color: Colors.redAccent)),
                ),
              IconButton(
                icon: Icon(Icons.close, color: Color(cfg.fnTextColor)),
                onPressed: () => setState(() => _showHistory = false),
              ),
            ],
          ),
        ),
        Expanded(
          child: _history.isEmpty
              ? Center(
                  child: Text('Sin historial',
                      style: TextStyle(color: Color(cfg.exprColor))))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: _history.length,
                  itemBuilder: (_, i) => _historyTile(_history[i], cfg, scale),
                ),
        ),
      ],
    );
  }

  Widget _historyTile(CalcHistoryEntry entry, CalculatorStyleConfig cfg, double scale) {
    return Card(
      color: Color(cfg.displayBgArgb),
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cfg.displayRadius.toDouble())),
      child: ListTile(
        title: Text(
          entry.name.isEmpty ? entry.expr : entry.name,
          style: TextStyle(
              color: Color(cfg.exprColor),
              fontSize: (cfg.exprSizeSp * 0.85 * scale).clamp(10.0, 40.0)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          entry.name.isEmpty ? '= ${entry.result}' : '${entry.expr} = ${entry.result}',
          style: TextStyle(
              color: Color(cfg.resultColor),
              fontSize: (cfg.resultSizeSp * 0.6 * scale).clamp(10.0, 30.0)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.edit, color: Color(cfg.fnTextColor), size: 20),
              tooltip: 'Renombrar',
              onPressed: () => _showRenameDialog(entry),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
              tooltip: 'Eliminar',
              onPressed: () => _deleteEntry(entry.id),
            ),
          ],
        ),
        onTap: () => _loadFromHistory(entry),
      ),
    );
  }

  Future<void> _showRenameDialog(CalcHistoryEntry entry) async {
    final ctrl = TextEditingController(text: entry.name);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Renombrar'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
              hintText: 'Nombre del ejercicio', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: const Text('Guardar')),
        ],
      ),
    );
    ctrl.dispose();
    if (result == null) return;
    await CalculatorHistoryStore.rename(entry.id, result);
    await _reloadHistory();
  }

  Future<void> _deleteEntry(String id) async {
    await CalculatorHistoryStore.delete(id);
    await _reloadHistory();
  }

  Future<void> _confirmClearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Borrar historial'),
        content: const Text('¿Eliminar todo el historial de cálculos?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Borrar todo',
                  style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (ok != true) return;
    await CalculatorHistoryStore.clearAll();
    await _reloadHistory();
  }

  // ─── Helpers de estilo ───────────────────────────────────────────────────

  _BtnS _numStyle(CalculatorStyleConfig c) =>
      _BtnS(c.numBgArgb, c.numTextColor, c.numTextSizeSp, c.numRadius);
  _BtnS _opStyle(CalculatorStyleConfig c) =>
      _BtnS(c.opBgArgb, c.opTextColor, c.opTextSizeSp, c.opRadius);
  _BtnS _fnStyle(CalculatorStyleConfig c) =>
      _BtnS(c.fnBgArgb, c.fnTextColor, c.fnTextSizeSp, c.fnRadius);
  _BtnS _eqStyle(CalculatorStyleConfig c) =>
      _BtnS(c.eqBgArgb, c.eqTextColor, c.eqTextSizeSp, c.eqRadius);
}

class _BtnS {
  final int bg, fg, sz, radius;
  const _BtnS(this.bg, this.fg, this.sz, this.radius);
}
