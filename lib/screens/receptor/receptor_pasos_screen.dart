import 'dart:async';
import 'package:connect/theme_colors.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../services/sensor_service.dart';
import '../../services/preferences_service.dart';

class ReceptorPasosScreen extends StatefulWidget {
  const ReceptorPasosScreen({super.key});

  @override
  State<ReceptorPasosScreen> createState() => _ReceptorPasosScreenState();
}

class _ReceptorPasosScreenState extends State<ReceptorPasosScreen> {
  bool _isLoading = true;
  int _steps = 0;
  int _distanciaM = 0;
  int _stepsGoal = 10000;
  double _heightCm = 170;
  double _pesoKg = 70;

  StreamSubscription<StepsData>? _sub;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await Hive.initFlutter();
    await Hive.openBox('steps_log');
    final profile = await PreferencesService.getBodyProfile();
    if (!mounted) return;
    setState(() {
      _stepsGoal = profile['steps_goal'] ?? 10000;
      _heightCm = (profile['height_cm'] as num?)?.toDouble() ?? 170.0;
      _pesoKg = (profile['weight_kg'] as num?)?.toDouble() ?? 70.0;
      _isLoading = false;
    });
    _sub = SensorService.stepsStream.listen((data) {
      if (!mounted) return;
      setState(() {
        _steps = data.steps;
        _distanciaM = data.distanciaM;
      });
      _persistir(data);
    });
  }

  /// Guarda una muestra en Hive como máximo una vez por minuto.
  void _persistir(StepsData data) {
    final box = Hive.box('steps_log');
    final ultima = box.isNotEmpty ? box.getAt(box.length - 1) as Map : null;
    final ahora = DateTime.now().millisecondsSinceEpoch;
    if (ultima == null || ahora - (ultima['timestamp'] as int) > 60000) {
      box.add({
        'timestamp': ahora,
        'steps': data.steps,
        'distancia_m': data.distanciaM,
      });
      if (box.length > 1440) box.deleteAt(0);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  double get _progress => (_stepsGoal > 0 ? _steps / _stepsGoal : 0.0).clamp(0.0, 1.0);
  double get _distanciaKm => _distanciaM / 1000.0;
  double get _zancadaCm => _heightCm * 0.415;
  double get _kcalSteps => _steps * 0.0005 * _pesoKg;

  @override
  Widget build(BuildContext context) {
    final progressColor = _progress >= 1.0 ? Colors.green : customColor[600]!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pasos y distancia'),
        backgroundColor: customColor[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            tooltip: 'Debug',
            onPressed: () => Navigator.pushNamed(context, '/receptor_salud_debug'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Contador principal circular
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        SizedBox(
                          width: 180,
                          height: 180,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CircularProgressIndicator(
                                value: _progress,
                                strokeWidth: 12,
                                backgroundColor: Colors.grey.shade200,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(progressColor),
                              ),
                              Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.directions_walk,
                                        size: 32, color: Colors.grey),
                                    Text(
                                      '$_steps',
                                      style: TextStyle(
                                          fontSize: 40,
                                          fontWeight: FontWeight.bold,
                                          color: progressColor),
                                    ),
                                    Text(
                                      'de $_stepsGoal',
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.black54),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _progress >= 1.0
                              ? '¡Meta alcanzada!'
                              : '${(_progress * 100).toStringAsFixed(1)}% completado',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: progressColor),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Distancia y zancada
                Row(
                  children: [
                    Expanded(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.straighten,
                                  color: customColor[600], size: 28),
                              const SizedBox(height: 4),
                              const Text('Distancia',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.black54)),
                              Text(
                                _distanciaKm >= 1
                                    ? '${_distanciaKm.toStringAsFixed(2)} km'
                                    : '$_distanciaM m',
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: customColor[700]),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.swap_horiz,
                                  color: customColor[600], size: 28),
                              const SizedBox(height: 4),
                              const Text('Zancada',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.black54)),
                              Text(
                                '${_zancadaCm.toStringAsFixed(0)} cm',
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: customColor[700]),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Calorías estimadas por pasos
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.local_fire_department,
                            color: Colors.orange, size: 28),
                        const SizedBox(height: 4),
                        const Text('Calorías estimadas',
                            style: TextStyle(
                                fontSize: 12, color: Colors.black54)),
                        Text(
                          '${_kcalSteps.toStringAsFixed(1)} kcal',
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange),
                        ),
                        const Text('(basado en pasos y peso)',
                            style: TextStyle(
                                fontSize: 11, color: Colors.black45)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Info de configuración
                Card(
                  color: customColor[50],
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'Meta: $_stepsGoal pasos · Altura: ${_heightCm.toStringAsFixed(0)} cm\n'
                      'Zancada calculada: ${_zancadaCm.toStringAsFixed(1)} cm (altura × 0.415)',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.person),
                  label: const Text('Editar perfil (meta de pasos)'),
                  onPressed: () =>
                      Navigator.pushNamed(context, '/user_body_profile'),
                ),
              ],
            ),
    );
  }
}
