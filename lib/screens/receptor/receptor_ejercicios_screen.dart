import 'package:connect/theme_colors.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class _Ejercicio {
  final String nombre;
  final IconData icon;
  final String descripcion;
  final double kcalPorRep;     // 0 si esTiempo
  final double kcalPorSegundo; // 0 si no esTiempo
  final bool esTiempo;

  const _Ejercicio({
    required this.nombre,
    required this.icon,
    required this.descripcion,
    this.kcalPorRep = 0,
    this.kcalPorSegundo = 0,
    this.esTiempo = false,
  });
}

// Factores kcal calibrados para una persona de ~70 kg.
const _ejercicios = [
  _Ejercicio(
    nombre: 'Flexiones',
    icon: Icons.fitness_center,
    kcalPorRep: 0.35,
    descripcion: 'Brazos separados al ancho de hombros, bajar hasta 90°',
  ),
  _Ejercicio(
    nombre: 'Sentadillas',
    icon: Icons.accessibility_new,
    kcalPorRep: 0.32,
    descripcion: 'Pies al ancho de caderas, bajar hasta muslos paralelos al suelo',
  ),
  _Ejercicio(
    nombre: 'Abdominales',
    icon: Icons.self_improvement,
    kcalPorRep: 0.24,
    descripcion: 'Manos en la nuca, elevar el torso hasta 45°',
  ),
  _Ejercicio(
    nombre: 'Burpees',
    icon: Icons.directions_run,
    kcalPorRep: 0.90,
    descripcion: 'Desde parado: sentadilla → plancha → flexión → salto',
  ),
  _Ejercicio(
    nombre: 'Zancadas',
    icon: Icons.transfer_within_a_station,
    kcalPorRep: 0.30,
    descripcion: 'Un paso adelante, bajar la rodilla trasera sin tocar el suelo',
  ),
  _Ejercicio(
    nombre: 'Plancha',
    icon: Icons.horizontal_rule,
    kcalPorSegundo: 0.07,
    esTiempo: true,
    descripcion: 'Apoyar antebrazos y puntas de pies, mantener cuerpo recto',
  ),
  _Ejercicio(
    nombre: 'Mountain climbers',
    icon: Icons.terrain,
    kcalPorRep: 0.15,
    descripcion: 'Desde plancha, alternar rodillas al pecho rápidamente',
  ),
  _Ejercicio(
    nombre: 'Saltos de tijera',
    icon: Icons.open_with,
    kcalPorRep: 0.20,
    descripcion: 'Jumping jacks: salto separando piernas y juntando manos arriba',
  ),
];

class ReceptorEjerciciosScreen extends StatefulWidget {
  const ReceptorEjerciciosScreen({super.key});

  @override
  State<ReceptorEjerciciosScreen> createState() =>
      _ReceptorEjerciciosScreenState();
}

class _ReceptorEjerciciosScreenState extends State<ReceptorEjerciciosScreen> {
  bool _isLoading = true;

  // nombre → {series, reps, segundos}
  final Map<String, Map<String, int>> _contadores = {};

  @override
  void initState() {
    super.initState();
    for (final e in _ejercicios) {
      _contadores[e.nombre] = {'series': 0, 'reps': 0, 'segundos': 0};
    }
    _load();
  }

  Future<void> _load() async {
    await Hive.initFlutter();
    await Hive.openBox('ejercicios_log');
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  double _kcalDe(_Ejercicio e) {
    final c = _contadores[e.nombre]!;
    if (e.esTiempo) return e.kcalPorSegundo * (c['segundos'] ?? 0);
    return e.kcalPorRep * (c['series'] ?? 0) * (c['reps'] ?? 0);
  }

  double get _totalKcal =>
      _ejercicios.fold(0.0, (total, e) => total + _kcalDe(e));

  bool get _haySesion =>
      _contadores.values.any((c) => c.values.any((v) => v > 0));

  Future<void> _guardarSesion() async {
    final box = Hive.box('ejercicios_log');
    await box.add({
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'kcal_total': _totalKcal,
      'detalle': _contadores.map(
          (k, v) => MapEntry(k, Map<String, dynamic>.from(v))),
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              'Sesión guardada: ${_totalKcal.toStringAsFixed(1)} kcal')),
    );
    setState(() {
      for (final c in _contadores.values) {
        c.updateAll((_, __) => 0);
      }
    });
  }

  void _ajustar(String nombre, String campo, int delta) {
    setState(() {
      final c = _contadores[nombre]!;
      c[campo] = ((c[campo] ?? 0) + delta).clamp(0, 9999);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ejercicios'),
        backgroundColor: customColor[700],
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Total de la sesión actual (fijo arriba)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Card(
                    color: Colors.orange.shade50,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.local_fire_department,
                              color: Colors.orange),
                          const SizedBox(width: 8),
                          Text(
                            'Sesión actual: ${_totalKcal.toStringAsFixed(1)} kcal',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                    children: _ejercicios
                        .map((e) => _EjercicioCard(
                              ejercicio: e,
                              contador: _contadores[e.nombre]!,
                              kcal: _kcalDe(e),
                              onAjustar: (campo, delta) =>
                                  _ajustar(e.nombre, campo, delta),
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
      floatingActionButton: _haySesion
          ? FloatingActionButton.extended(
              backgroundColor: customColor[700],
              foregroundColor: Colors.white,
              icon: const Icon(Icons.save),
              label: const Text('Guardar sesión'),
              onPressed: _guardarSesion,
            )
          : null,
    );
  }
}

class _EjercicioCard extends StatelessWidget {
  final _Ejercicio ejercicio;
  final Map<String, int> contador;
  final double kcal;
  final void Function(String campo, int delta) onAjustar;

  const _EjercicioCard({
    required this.ejercicio,
    required this.contador,
    required this.kcal,
    required this.onAjustar,
  });

  Widget _contadorRow(String label, String campo) {
    final valor = contador[campo] ?? 0;
    return Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          iconSize: 22,
          visualDensity: VisualDensity.compact,
          onPressed: valor > 0 ? () => onAjustar(campo, -1) : null,
        ),
        SizedBox(
          width: 40,
          child: Text(
            '$valor',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          iconSize: 22,
          visualDensity: VisualDensity.compact,
          onPressed: () => onAjustar(campo, 1),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = customColor[600]!;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(ejercicio.icon, color: c, size: 24),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ejercicio.nombre,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                      Text(ejercicio.descripcion,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.black54)),
                    ],
                  ),
                ),
                if (kcal > 0)
                  Text(
                    '${kcal.toStringAsFixed(1)} kcal',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            if (ejercicio.esTiempo)
              _contadorRow('Segundos', 'segundos')
            else ...[
              _contadorRow('Series', 'series'),
              _contadorRow('Reps por serie', 'reps'),
            ],
          ],
        ),
      ),
    );
  }
}
