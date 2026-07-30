import 'dart:async';
import 'package:connect/theme_colors.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../services/sensor_service.dart';
import '../../services/preferences_service.dart';

class ReceptorHrScreen extends StatefulWidget {
  const ReceptorHrScreen({super.key});

  @override
  State<ReceptorHrScreen> createState() => _ReceptorHrScreenState();
}

class _ReceptorHrScreenState extends State<ReceptorHrScreen> {
  bool _isLoading = true;
  int _bpm = 0;
  int _confidence = 0;
  String _zona = 'reposo';
  double _kcalSession = 0;
  DateTime? _sessionStart;

  int _fcMax = 190;
  double _pesoKg = 70;
  int _edad = 30;
  bool _esMasculino = true;
  int _hrAlertHigh = 120;
  int _hrAlertLow = 50;

  // Historial de lecturas para la gráfica simple
  final List<_HrPoint> _history = [];
  static const int _maxHistory = 60;

  // Tiempo acumulado por zona en segundos
  final Map<String, int> _zonaTiempo = {
    'reposo': 0, 'fat_burn': 0, 'cardio': 0, 'aerobico': 0, 'peak': 0,
  };
  DateTime? _lastZonaTs;

  StreamSubscription<HrData>? _hrSub;
  Timer? _kcalTimer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await Hive.initFlutter();
    await Hive.openBox('hr_log');
    final profile = await PreferencesService.getBodyProfile();
    if (!mounted) return;
    final age = profile['age'] ?? 30;
    final fcManual = profile['fc_max'] ?? 0;
    setState(() {
      _edad = age;
      _pesoKg = (profile['weight_kg'] as num?)?.toDouble() ?? 70.0;
      _esMasculino = (profile['sex'] ?? 'M') == 'M';
      _fcMax = PreferencesService.calcFcMax(age, fcManual);
      _hrAlertHigh = profile['hr_alert_high'] ?? 120;
      _hrAlertLow = profile['hr_alert_low'] ?? 50;
      _isLoading = false;
    });
    _hrSub = SensorService.heartRateStream.listen(_onHr);
  }

  void _onHr(HrData data) {
    if (!mounted) return;
    final now = DateTime.now();
    final zona = HrData.zona(data.bpm, _fcMax);

    // Acumular tiempo en zona
    if (_lastZonaTs != null && _zona.isNotEmpty) {
      _zonaTiempo[_zona] =
          (_zonaTiempo[_zona] ?? 0) + now.difference(_lastZonaTs!).inSeconds;
    }
    _lastZonaTs = now;

    // Calorías
    final kcalMin = SensorService.calcKcalPerMin(
      bpm: data.bpm,
      pesoKg: _pesoKg,
      edad: _edad,
      esMasculino: _esMasculino,
    );
    _sessionStart ??= now;
    final minElapsed = now.difference(_sessionStart!).inSeconds / 60.0;
    final kcal = (kcalMin * minElapsed).clamp(0, double.infinity);

    // Agregar al historial
    if (_history.length >= _maxHistory) _history.removeAt(0);
    _history.add(_HrPoint(bpm: data.bpm, ts: now));

    setState(() {
      _bpm = data.bpm;
      _confidence = data.confidence;
      _zona = zona;
      _kcalSession = kcal.toDouble();
    });

    // Persistir lectura en Hive (historial del día)
    final box = Hive.box('hr_log');
    box.add({
      'timestamp': now.millisecondsSinceEpoch,
      'bpm': data.bpm,
      'zona': zona,
      'kcal_acum': _kcalSession,
    });
    // Limitar a 1440 entradas (≈ 24 h a 1 lectura/min)
    if (box.length > 1440) box.deleteAt(0);

    // Alertas
    if (data.bpm > _hrAlertHigh) {
      SensorService.addDebugLog('hr_monitor',
          'ALERTA BPM alto: ${data.bpm} > $_hrAlertHigh');
    } else if (data.bpm < _hrAlertLow) {
      SensorService.addDebugLog('hr_monitor',
          'ALERTA BPM bajo: ${data.bpm} < $_hrAlertLow');
    }
  }

  @override
  void dispose() {
    _hrSub?.cancel();
    _kcalTimer?.cancel();
    super.dispose();
  }

  String _zonaLabel(String z) => HrData.zonaLabel(z);
  Color _zonaColor(String z) => Color(HrData.zonaColor(z));

  String _formatSegundos(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Frecuencia cardíaca'),
        backgroundColor: customColor[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Historial del día',
            onPressed: () =>
                Navigator.pushNamed(context, '/receptor_hr_history'),
          ),
          IconButton(
            icon: const Icon(Icons.bug_report),
            tooltip: 'Debug',
            onPressed: () =>
                Navigator.pushNamed(context, '/receptor_salud_debug'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // BPM principal
                _BpmCard(bpm: _bpm, zona: _zona, confidence: _confidence),
                const SizedBox(height: 12),
                // Zona y calorías
                Row(
                  children: [
                    Expanded(
                      child: _InfoCard(
                        icon: Icons.local_fire_department,
                        label: 'Calorías sesión',
                        value: '${_kcalSession.toStringAsFixed(1)} kcal',
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _InfoCard(
                        icon: Icons.speed,
                        label: 'Zona activa',
                        value: _zonaLabel(_zona),
                        color: _zonaColor(_zona),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Gráfica simple de historial
                if (_history.isNotEmpty) _buildHistogram(),
                const SizedBox(height: 12),
                // Tiempo por zona
                _buildZoneTimes(),
                const SizedBox(height: 12),
                // FCmáx info
                Card(
                  color: customColor[50],
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'FCmáx: $_fcMax bpm · Alertas: <$_hrAlertLow o >$_hrAlertHigh bpm',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHistogram() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Últimas lecturas',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SizedBox(
              height: 80,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: _history.map((p) {
                  final h = (_history.isEmpty
                          ? 0.0
                          : p.bpm /
                              _history
                                  .map((e) => e.bpm)
                                  .reduce((a, b) => a > b ? a : b))
                      .clamp(0.05, 1.0);
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      height: 80 * h,
                      decoration: BoxDecoration(
                        color: _zonaColor(HrData.zona(p.bpm, _fcMax))
                            .withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                    '${_history.isEmpty ? 0 : _history.map((e) => e.bpm).reduce((a, b) => a < b ? a : b)} bpm mín',
                    style: const TextStyle(fontSize: 11, color: Colors.black54)),
                Text(
                    '${_history.isEmpty ? 0 : _history.map((e) => e.bpm).reduce((a, b) => a > b ? a : b)} bpm máx',
                    style: const TextStyle(fontSize: 11, color: Colors.black54)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZoneTimes() {
    final zones = ['reposo', 'fat_burn', 'cardio', 'aerobico', 'peak'];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tiempo por zona',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...zones.map((z) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                              color: _zonaColor(z), shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(_zonaLabel(z),
                              style: const TextStyle(fontSize: 13))),
                      Text(_formatSegundos(_zonaTiempo[z] ?? 0),
                          style: const TextStyle(
                              fontSize: 13,
                              fontFamily: 'monospace',
                              color: Colors.black54)),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _HrPoint {
  final int bpm;
  final DateTime ts;
  _HrPoint({required this.bpm, required this.ts});
}

class _BpmCard extends StatelessWidget {
  final int bpm;
  final String zona;
  final int confidence;
  const _BpmCard({required this.bpm, required this.zona, required this.confidence});

  @override
  Widget build(BuildContext context) {
    final color = Color(HrData.zonaColor(zona));
    return Card(
      color: color.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: color, width: 2)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.favorite, color: color, size: 40),
            const SizedBox(height: 8),
            Text(
              bpm > 0 ? '$bpm' : '—',
              style: TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.bold,
                  color: color),
            ),
            Text('bpm',
                style: TextStyle(fontSize: 18, color: color.withValues(alpha: 0.7))),
            const SizedBox(height: 4),
            Chip(
              label: Text(HrData.zonaLabel(zona),
                  style: const TextStyle(color: Colors.white, fontSize: 13)),
              backgroundColor: color,
            ),
            if (confidence < 3)
              Text('Señal: ${confidence == 2 ? "regular" : "baja"}',
                  style: const TextStyle(fontSize: 12, color: Colors.orange)),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _InfoCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 4),
            Text(label,
                style:
                    const TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
