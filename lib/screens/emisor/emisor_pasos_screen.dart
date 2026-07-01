import 'dart:async';
import 'package:connect/theme_colors.dart';
import 'package:flutter/material.dart';
import '../../services/sensor_service.dart';

/// Pantalla de pasos del EMISOR — solo lectura de datos recibidos por BT.
class EmisorPasosScreen extends StatefulWidget {
  const EmisorPasosScreen({super.key});

  @override
  State<EmisorPasosScreen> createState() => _EmisorPasosScreenState();
}

class _EmisorPasosScreenState extends State<EmisorPasosScreen> {
  int _steps = 0;
  int _distM = 0;

  StreamSubscription<Map<String, dynamic>>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = SensorService.debugLogStream.listen((log) {
      final src = log['source']?.toString() ?? '';
      final msg = log['message']?.toString() ?? '';
      if (src != 'bt_sensor_rx' || !mounted) return;
      if (msg.startsWith('STEPS:')) {
        final parts = msg.substring(6).split(':');
        setState(() => _steps = int.tryParse(parts[0]) ?? _steps);
      } else if (msg.startsWith('DIST:')) {
        setState(() => _distM = int.tryParse(msg.substring(5)) ?? _distM);
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final distKm = _distM / 1000.0;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pasos del receptor'),
        backgroundColor: customColor[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: () => Navigator.pushNamed(context, '/emisor_salud_debug'),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.directions_walk,
                  size: 80, color: customColor[600]),
              const SizedBox(height: 16),
              Text(
                '$_steps',
                style: TextStyle(
                    fontSize: 72,
                    fontWeight: FontWeight.bold,
                    color: customColor[700]),
              ),
              const Text('pasos hoy',
                  style: TextStyle(fontSize: 18, color: Colors.black54)),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.straighten, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        distKm >= 1
                            ? '${distKm.toStringAsFixed(2)} km'
                            : '$_distM m',
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
              if (_steps == 0) ...[
                const SizedBox(height: 24),
                const Text(
                  'Sin datos de pasos del receptor.\n'
                  'Activa el servicio de sensores en el receptor.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
