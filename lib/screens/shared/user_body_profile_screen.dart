import 'package:connect/theme_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/preferences_service.dart';

class UserBodyProfileScreen extends StatefulWidget {
  const UserBodyProfileScreen({super.key});

  @override
  State<UserBodyProfileScreen> createState() => _UserBodyProfileScreenState();
}

class _UserBodyProfileScreenState extends State<UserBodyProfileScreen> {
  bool _isLoading = true;
  bool _saving = false;

  // Perfil
  final _nameCtrl       = TextEditingController();
  int    _age           = 30;
  String _sex           = 'M';
  double _weightKg      = 70.0;
  double _heightCm      = 170.0;

  // Salud / umbrales
  int _fcMaxManual  = 0;   // 0 = calcular automáticamente
  int _stepsGoal    = 10000;
  int _hrAlertHigh  = 120;
  int _hrAlertLow   = 50;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final data = await PreferencesService.getBodyProfile();
    if (!mounted) return;
    setState(() {
      _nameCtrl.text = data['name'] ?? '';
      _age           = data['age'] ?? 30;
      _sex           = data['sex'] ?? 'M';
      _weightKg      = (data['weight_kg'] as num?)?.toDouble() ?? 70.0;
      _heightCm      = (data['height_cm'] as num?)?.toDouble() ?? 170.0;
      _fcMaxManual   = data['fc_max'] ?? 0;
      _stepsGoal     = data['steps_goal'] ?? 10000;
      _hrAlertHigh   = data['hr_alert_high'] ?? 120;
      _hrAlertLow    = data['hr_alert_low'] ?? 50;
      _isLoading     = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await PreferencesService.saveBodyProfile({
      'name':          _nameCtrl.text.trim(),
      'age':           _age,
      'sex':           _sex,
      'weight_kg':     _weightKg,
      'height_cm':     _heightCm,
      'fc_max':        _fcMaxManual,
      'steps_goal':    _stepsGoal,
      'hr_alert_high': _hrAlertHigh,
      'hr_alert_low':  _hrAlertLow,
    });
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Perfil guardado')),
    );
  }

  // ── Helpers de UI ─────────────────────────────────────────────────────────

  Widget _tabPage(List<Widget> children) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: children,
      );

  Widget _tabHeader(String title, String subtitle) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(subtitle,
                style: const TextStyle(fontSize: 13, color: Colors.black54)),
            const Divider(height: 20),
          ],
        ),
      );

  Widget _numberField({
    required String label,
    required String hint,
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
    String suffix = '',
  }) {
    final ctrl = TextEditingController(text: value.toString());
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          suffixText: suffix,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        onChanged: (v) {
          final n = int.tryParse(v) ?? value;
          onChanged(n.clamp(min, max));
        },
      ),
    );
  }

  Widget _decimalField({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
    String suffix = '',
  }) {
    final ctrl = TextEditingController(text: value.toStringAsFixed(1));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          suffixText: suffix,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        onChanged: (v) {
          final n = double.tryParse(v.replaceAll(',', '.')) ?? value;
          onChanged(n.clamp(min, max));
        },
      ),
    );
  }

  // ── Pestaña Perfil ────────────────────────────────────────────────────────

  Widget _buildPerfilTab() => _tabPage([
        _tabHeader('Perfil personal',
            'Datos usados para calcular calorías, distancia y zonas de entrenamiento.'),
        // Nombre
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Nombre',
              hintText: 'Tu nombre',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        // Edad
        _numberField(
          label: 'Edad',
          hint: '30',
          value: _age,
          min: 10,
          max: 100,
          suffix: 'años',
          onChanged: (v) => setState(() => _age = v),
        ),
        // Sexo
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              const Text('Sexo biológico:',
                  style: TextStyle(fontSize: 15)),
              const SizedBox(width: 16),
              ChoiceChip(
                label: const Text('Masculino'),
                selected: _sex == 'M',
                onSelected: (_) => setState(() => _sex = 'M'),
                selectedColor: customColor[100],
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Femenino'),
                selected: _sex == 'F',
                onSelected: (_) => setState(() => _sex = 'F'),
                selectedColor: customColor[100],
              ),
            ],
          ),
        ),
        // Peso
        _decimalField(
          label: 'Peso',
          value: _weightKg,
          min: 20,
          max: 300,
          suffix: 'kg',
          onChanged: (v) => setState(() => _weightKg = v),
        ),
        // Altura
        _decimalField(
          label: 'Altura',
          value: _heightCm,
          min: 50,
          max: 250,
          suffix: 'cm',
          onChanged: (v) => setState(() => _heightCm = v),
        ),
        const SizedBox(height: 8),
        // Resumen de longitud de zancada calculada
        Card(
          color: customColor[50],
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Calculado automáticamente',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: customColor[700])),
                const SizedBox(height: 4),
                Text(
                  'Zancada (caminar): ${(_heightCm * 0.415 / 100).toStringAsFixed(2)} m\n'
                  'Zancada (correr):  ${(_heightCm * 0.55 / 100).toStringAsFixed(2)} m\n'
                  'FCmáx estimada:    ${PreferencesService.calcFcMax(_age, 0)} bpm',
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                ),
              ],
            ),
          ),
        ),
      ]);

  // ── Pestaña Salud ─────────────────────────────────────────────────────────

  Widget _buildSaludTab() => _tabPage([
        _tabHeader('Parámetros de salud',
            'FCmáx, metas de pasos y umbrales de alerta de frecuencia cardíaca.'),
        // FCmáx manual
        _numberField(
          label: 'FCmáx manual (0 = calcular 220−edad)',
          hint: '0',
          value: _fcMaxManual,
          min: 0,
          max: 230,
          suffix: 'bpm',
          onChanged: (v) => setState(() => _fcMaxManual = v),
        ),
        Card(
          color: customColor[50],
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'FCmáx efectiva: ${PreferencesService.calcFcMax(_age, _fcMaxManual)} bpm\n'
              '(${_fcMaxManual > 0 ? "valor manual" : "220 − $_age años"})',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Meta de pasos
        _numberField(
          label: 'Meta de pasos diaria',
          hint: '10000',
          value: _stepsGoal,
          min: 1000,
          max: 50000,
          suffix: 'pasos',
          onChanged: (v) => setState(() => _stepsGoal = v),
        ),
        const SizedBox(height: 12),
        const Text('Alertas de frecuencia cardíaca',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        const Text('Se enviará una alerta al emisor si el BPM supera estos umbrales.',
            style: TextStyle(fontSize: 13, color: Colors.black54)),
        const SizedBox(height: 8),
        _numberField(
          label: 'Umbral alto (taquicardia)',
          hint: '120',
          value: _hrAlertHigh,
          min: 80,
          max: 220,
          suffix: 'bpm',
          onChanged: (v) => setState(() => _hrAlertHigh = v),
        ),
        _numberField(
          label: 'Umbral bajo (bradicardia)',
          hint: '50',
          value: _hrAlertLow,
          min: 20,
          max: 80,
          suffix: 'bpm',
          onChanged: (v) => setState(() => _hrAlertLow = v),
        ),
        const SizedBox(height: 8),
        // Visualización de zonas
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Zonas de entrenamiento calculadas',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                ..._buildZoneRows(),
              ],
            ),
          ),
        ),
      ]);

  List<Widget> _buildZoneRows() {
    final fcMax = PreferencesService.calcFcMax(_age, _fcMaxManual);
    final zones = [
      ('Reposo',    0,    (fcMax * 0.50).round(), const Color(0xFF42A5F5)),
      ('Fat-burn',  (fcMax * 0.50).round(), (fcMax * 0.60).round(), const Color(0xFF66BB6A)),
      ('Cardio',    (fcMax * 0.60).round(), (fcMax * 0.70).round(), const Color(0xFFFFCA28)),
      ('Aeróbico',  (fcMax * 0.70).round(), (fcMax * 0.80).round(), const Color(0xFFFFA726)),
      ('Peak',      (fcMax * 0.80).round(), fcMax, const Color(0xFFEF5350)),
    ];
    return zones.map((z) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Container(
                  width: 12, height: 12,
                  decoration: BoxDecoration(color: z.$4, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(child: Text(z.$1, style: const TextStyle(fontSize: 13))),
              Text('${z.$2}–${z.$3} bpm',
                  style: const TextStyle(fontSize: 13, color: Colors.black54)),
            ],
          ),
        )).toList();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Perfil corporal'),
          backgroundColor: customColor[700],
          foregroundColor: Colors.white,
          actions: [
            if (_saving)
              const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                ),
              )
            else
              IconButton(
                icon: const Icon(Icons.save),
                tooltip: 'Guardar perfil',
                onPressed: _save,
              ),
          ],
          bottom: _isLoading
              ? null
              : const TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  indicatorColor: Colors.white,
                  tabs: [
                    Tab(text: 'Perfil', icon: Icon(Icons.person)),
                    Tab(text: 'Salud', icon: Icon(Icons.favorite)),
                  ],
                ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildPerfilTab(),
                  _buildSaludTab(),
                ],
              ),
      ),
    );
  }
}
