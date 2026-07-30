import 'package:connect/theme_colors.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../services/sensor_service.dart';

class ReceptorHrHistoryScreen extends StatefulWidget {
  const ReceptorHrHistoryScreen({super.key});

  @override
  State<ReceptorHrHistoryScreen> createState() =>
      _ReceptorHrHistoryScreenState();
}

class _ReceptorHrHistoryScreenState extends State<ReceptorHrHistoryScreen> {
  bool _isLoading = true;
  List<Map> _entradas = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await Hive.initFlutter();
    final box = await Hive.openBox('hr_log');
    final hoy = DateTime.now();
    final entradas = box.values
        .cast<Map>()
        .where((e) {
          final ts = DateTime.fromMillisecondsSinceEpoch(e['timestamp'] as int);
          return ts.year == hoy.year &&
              ts.month == hoy.month &&
              ts.day == hoy.day;
        })
        .toList()
      ..sort((a, b) =>
          (a['timestamp'] as int).compareTo(b['timestamp'] as int));
    if (!mounted) return;
    setState(() {
      _entradas = entradas;
      _isLoading = false;
    });
  }

  Future<void> _borrarHistorial() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Borrar historial'),
        content: const Text(
            '¿Borrar todas las lecturas de frecuencia cardíaca del día?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Borrar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    final box = Hive.box('hr_log');
    await box.clear();
    if (!mounted) return;
    setState(() => _entradas = []);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Historial del día borrado')),
    );
  }

  int get _bpmMin => _entradas.isEmpty
      ? 0
      : _entradas.map((e) => e['bpm'] as int).reduce((a, b) => a < b ? a : b);
  int get _bpmMax => _entradas.isEmpty
      ? 0
      : _entradas.map((e) => e['bpm'] as int).reduce((a, b) => a > b ? a : b);
  int get _bpmProm => _entradas.isEmpty
      ? 0
      : _entradas.map((e) => e['bpm'] as int).reduce((a, b) => a + b) ~/
          _entradas.length;

  /// Promedio de BPM por hora del día (0-23), 0 si no hay lecturas en esa hora.
  Map<int, int> get _porHora {
    final sums = <int, int>{};
    final counts = <int, int>{};
    for (final e in _entradas) {
      final h =
          DateTime.fromMillisecondsSinceEpoch(e['timestamp'] as int).hour;
      sums[h] = (sums[h] ?? 0) + (e['bpm'] as int);
      counts[h] = (counts[h] ?? 0) + 1;
    }
    return sums.map((h, s) => MapEntry(h, s ~/ counts[h]!));
  }

  String _hora(int ts) {
    final d = DateTime.fromMillisecondsSinceEpoch(ts);
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial HR — hoy'),
        backgroundColor: customColor[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Borrar historial del día',
            onPressed: _entradas.isEmpty ? null : _borrarHistorial,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _entradas.isEmpty
              ? const Center(
                  child: Text('Sin lecturas registradas hoy',
                      style: TextStyle(color: Colors.black54)),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildResumen(),
                    const SizedBox(height: 12),
                    _buildGraficaPorHora(),
                    const SizedBox(height: 12),
                    _buildListaEntradas(),
                  ],
                ),
    );
  }

  Widget _buildResumen() {
    Widget stat(String label, int bpm, IconData icon, Color color) => Expanded(
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 4),
              Text('$bpm',
                  style: TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold, color: color)),
              Text(label,
                  style:
                      const TextStyle(fontSize: 12, color: Colors.black54)),
            ],
          ),
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            stat('Mínimo', _bpmMin, Icons.arrow_downward, Colors.blue),
            stat('Promedio', _bpmProm, Icons.favorite, Colors.red),
            stat('Máximo', _bpmMax, Icons.arrow_upward, Colors.orange),
          ],
        ),
      ),
    );
  }

  Widget _buildGraficaPorHora() {
    final porHora = _porHora;
    final maxBpm = porHora.values.isEmpty
        ? 1
        : porHora.values.reduce((a, b) => a > b ? a : b);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('BPM promedio por hora',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SizedBox(
              height: 100,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(24, (h) {
                  final bpm = porHora[h] ?? 0;
                  final frac =
                      bpm > 0 ? (bpm / maxBpm).clamp(0.05, 1.0) : 0.0;
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      height: 100 * frac,
                      decoration: BoxDecoration(
                        color: bpm > 0
                            ? Colors.red.withValues(alpha: 0.7)
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 4),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('0 h',
                    style: TextStyle(fontSize: 11, color: Colors.black54)),
                Text('12 h',
                    style: TextStyle(fontSize: 11, color: Colors.black54)),
                Text('23 h',
                    style: TextStyle(fontSize: 11, color: Colors.black54)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListaEntradas() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Lecturas (${_entradas.length})',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ..._entradas.reversed.map((e) {
              final zona = e['zona'] as String? ?? 'reposo';
              final kcal = (e['kcal_acum'] as num?)?.toDouble() ?? 0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Text(_hora(e['timestamp'] as int),
                        style: const TextStyle(
                            fontSize: 13,
                            fontFamily: 'monospace',
                            color: Colors.black54)),
                    const SizedBox(width: 10),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Color(HrData.zonaColor(zona)),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('${e['bpm']} bpm · ${HrData.zonaLabel(zona)}',
                          style: const TextStyle(fontSize: 13)),
                    ),
                    Text('${kcal.toStringAsFixed(1)} kcal',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black54)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
