import 'dart:async';
import 'package:connect/theme_colors.dart';
import 'package:flutter/material.dart';
import '../../services/sensor_service.dart';

/// Pantalla HR del EMISOR — solo lectura de datos recibidos por BT.
class EmisorHrScreen extends StatefulWidget {
  const EmisorHrScreen({super.key});

  @override
  State<EmisorHrScreen> createState() => _EmisorHrScreenState();
}

class _EmisorHrScreenState extends State<EmisorHrScreen> {
  int _bpm = 0;
  String _zona = 'reposo';
  double _kcal = 0;
  final List<int> _history = [];
  static const int _maxHistory = 60;

  StreamSubscription<Map<String, dynamic>>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = SensorService.debugLogStream.listen((log) {
      final src = log['source']?.toString() ?? '';
      final msg = log['message']?.toString() ?? '';
      if (src != 'bt_sensor_rx') return;
      if (!mounted) return;
      if (msg.startsWith('HR:')) {
        final bpm = int.tryParse(msg.substring(3)) ?? 0;
        setState(() {
          _bpm = bpm;
          if (_history.length >= _maxHistory) _history.removeAt(0);
          _history.add(bpm);
        });
      } else if (msg.startsWith('HR_ZONA:')) {
        setState(() => _zona = msg.substring(8));
      } else if (msg.startsWith('KCAL:')) {
        setState(() => _kcal = double.tryParse(msg.substring(5)) ?? _kcal);
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Color get _zonaColor => Color(HrData.zonaColor(_zona));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HR del receptor'),
        backgroundColor: customColor[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: () => Navigator.pushNamed(context, '/emisor_salud_debug'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: _zonaColor.withValues(alpha: 0.08),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: _zonaColor, width: 2),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(Icons.favorite, color: _zonaColor, size: 40),
                  const SizedBox(height: 8),
                  Text(
                    _bpm > 0 ? '$_bpm' : '—',
                    style: TextStyle(
                        fontSize: 64,
                        fontWeight: FontWeight.bold,
                        color: _zonaColor),
                  ),
                  Text('bpm',
                      style: TextStyle(
                          fontSize: 18,
                          color: _zonaColor.withValues(alpha: 0.7))),
                  const SizedBox(height: 4),
                  Chip(
                    label: Text(HrData.zonaLabel(_zona),
                        style: const TextStyle(
                            color: Colors.white, fontSize: 13)),
                    backgroundColor: _zonaColor,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.local_fire_department,
                      color: Colors.orange),
                  const SizedBox(width: 8),
                  Text('${_kcal.toStringAsFixed(1)} kcal sesión',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
          if (_history.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Historial recibido',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 80,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: _history.map((bpm) {
                          final maxBpm = _history.reduce((a, b) => a > b ? a : b);
                          final h = (maxBpm > 0 ? bpm / maxBpm : 0.05).clamp(0.05, 1.0);
                          return Expanded(
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              height: 80 * h,
                              decoration: BoxDecoration(
                                color: Color(HrData.zonaColor(
                                    HrData.zona(bpm, 190))).withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (_bpm == 0)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Sin datos de HR del receptor.\n'
                'Asegúrate de que el receptor tenga el sensor HR activo\ny esté conectado por BT.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
            ),
        ],
      ),
    );
  }
}
