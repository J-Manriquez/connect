import 'dart:async';
import 'package:connect/theme_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/sensor_service.dart';
import '../../services/preferences_service.dart';

class ReceptorSaludScreen extends StatefulWidget {
  const ReceptorSaludScreen({super.key});

  @override
  State<ReceptorSaludScreen> createState() => _ReceptorSaludScreenState();
}

class _ReceptorSaludScreenState extends State<ReceptorSaludScreen> {
  static const _svcChannel = MethodChannel('connect/sensor_service');

  bool _isLoading = true;
  bool _serviceRunning = false;

  // Últimas lecturas para mostrar en las cards del hub
  int _lastBpm = 0;
  int _lastSteps = 0;
  int _stepsGoal = 10000;
  double _lastAzimuth = 0;
  String _wristState = 'desconocido';

  StreamSubscription<HrData>? _hrSub;
  StreamSubscription<StepsData>? _stepsSub;
  StreamSubscription<double>? _compassSub;
  StreamSubscription<String>? _wristSub;

  @override
  void initState() {
    super.initState();
    SensorService.initDebugStream();
    _load();
  }

  Future<void> _load() async {
    final profile = await PreferencesService.getBodyProfile();
    if (!mounted) return;
    setState(() {
      _stepsGoal = profile['steps_goal'] ?? 10000;
      _isLoading = false;
    });
    _subscribeStreams();
  }

  void _subscribeStreams() {
    _hrSub = SensorService.heartRateStream.listen((data) {
      if (!mounted) return;
      setState(() => _lastBpm = data.bpm);
    });
    _stepsSub = SensorService.stepsStream.listen((data) {
      if (!mounted) return;
      setState(() => _lastSteps = data.steps);
    });
    _compassSub = SensorService.compassStream.listen((az) {
      if (!mounted) return;
      setState(() => _lastAzimuth = az);
    });
    _wristSub = SensorService.wristStream.listen((state) {
      if (!mounted) return;
      setState(() => _wristState = state == 'on_wrist' ? 'puesta' : 'quitada');
    });
  }

  @override
  void dispose() {
    _hrSub?.cancel();
    _stepsSub?.cancel();
    _compassSub?.cancel();
    _wristSub?.cancel();
    super.dispose();
  }

  Future<void> _toggleService() async {
    try {
      if (_serviceRunning) {
        await _svcChannel.invokeMethod('stop');
        SensorService.addDebugLog('service', 'detenido por usuario');
      } else {
        await _svcChannel.invokeMethod('start');
        SensorService.addDebugLog('service', 'iniciado por usuario');
      }
      setState(() => _serviceRunning = !_serviceRunning);
    } catch (e) {
      SensorService.addDebugLog('service', 'error toggle: $e');
    }
  }

  // ── UI helpers ────────────────────────────────────────────────────────────

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

  Widget _navCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
    required VoidCallback onTap,
    Color? color,
  }) {
    final c = color ?? customColor[600]!;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: c, size: 26),
        ),
        title: Text(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        subtitle: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitle,
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
            if (value.isNotEmpty)
              Text(value,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: c)),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  // ── Pestañas ──────────────────────────────────────────────────────────────

  Widget _buildSensoresTab() => _tabPage([
        _tabHeader('Sensores activos',
            'Controla el servicio de sensores en segundo plano.'),
        Card(
          child: SwitchListTile(
            secondary: Icon(
              _serviceRunning ? Icons.sensors : Icons.sensors_off,
              color: _serviceRunning ? Colors.green : Colors.grey,
            ),
            title: Text(_serviceRunning
                ? 'Servicio de sensores activo'
                : 'Servicio de sensores inactivo'),
            subtitle: Text(_serviceRunning
                ? 'Monitoreando HR, pasos, brújula y muñeca'
                : 'Toca para iniciar el monitoreo en segundo plano'),
            value: _serviceRunning,
            onChanged: (_) => _toggleService(),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          color: Colors.grey.shade50,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Estado en tiempo real',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                _stateRow(Icons.favorite, 'HR', _lastBpm > 0 ? '$_lastBpm bpm' : '—'),
                _stateRow(Icons.directions_walk, 'Pasos hoy', '$_lastSteps'),
                _stateRow(Icons.explore, 'Brújula',
                    '${_lastAzimuth.toStringAsFixed(1)}°'),
                _stateRow(Icons.watch, 'Muñeca', _wristState),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.person),
          label: const Text('Perfil corporal'),
          onPressed: () => Navigator.pushNamed(context, '/user_body_profile'),
        ),
      ]);

  Widget _stateRow(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Text('$label: ', style: const TextStyle(fontSize: 13)),
            Text(value,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      );

  Widget _buildCorazonTab() => _tabPage([
        _tabHeader('Frecuencia cardíaca',
            'Monitor de HR en tiempo real, zonas de entrenamiento y calorías.'),
        _navCard(
          icon: Icons.favorite,
          title: 'Monitor cardíaco',
          subtitle: 'BPM en vivo, zona y calorías',
          value: _lastBpm > 0 ? '$_lastBpm bpm' : 'Sin datos',
          color: Colors.red[600],
          onTap: () => Navigator.pushNamed(context, '/receptor_salud_hr'),
        ),
      ]);

  Widget _buildPasosTab() => _tabPage([
        _tabHeader('Pasos y distancia',
            'Pedómetro por software sobre el acelerómetro.'),
        _navCard(
          icon: Icons.directions_walk,
          title: 'Contador de pasos',
          subtitle: 'Pasos, distancia y meta diaria',
          value: '$_lastSteps / $_stepsGoal pasos',
          color: Colors.green[700],
          onTap: () => Navigator.pushNamed(context, '/receptor_salud_pasos'),
        ),
      ]);

  Widget _buildBrujulaTab() => _tabPage([
        _tabHeader('Brújula',
            'Orientación cardinal usando el sensor GeoMag Rotation Vector.'),
        _navCard(
          icon: Icons.explore,
          title: 'Brújula',
          subtitle: 'Azimuth y cardinal en tiempo real',
          value: '${_lastAzimuth.toStringAsFixed(1)}°',
          color: Colors.blue[700],
          onTap: () => Navigator.pushNamed(context, '/receptor_brujula'),
        ),
      ]);

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Salud — Receptor'),
          backgroundColor: customColor[700],
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.bug_report),
              tooltip: 'Debug sensores',
              onPressed: () =>
                  Navigator.pushNamed(context, '/receptor_salud_debug'),
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
                    Tab(text: 'Sensores', icon: Icon(Icons.sensors)),
                    Tab(text: 'Corazón', icon: Icon(Icons.favorite)),
                    Tab(text: 'Pasos', icon: Icon(Icons.directions_walk)),
                    Tab(text: 'Brújula', icon: Icon(Icons.explore)),
                  ],
                ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildSensoresTab(),
                  _buildCorazonTab(),
                  _buildPasosTab(),
                  _buildBrujulaTab(),
                ],
              ),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(height: 3, color: customColor[700]),
            BottomNavigationBar(
              currentIndex: 3,
              onTap: (index) {
                switch (index) {
                  case 0:
                    Navigator.pushReplacementNamed(context, '/receptor_settings');
                    break;
                  case 1:
                    Navigator.pushReplacementNamed(context, '/receptor');
                    break;
                  case 2:
                    Navigator.pushReplacementNamed(context, '/unread_notifications');
                    break;
                  case 3:
                    break;
                }
              },
              selectedFontSize: 14.0,
              unselectedFontSize: 12.0,
              selectedIconTheme: const IconThemeData(size: 37.5),
              unselectedIconTheme: const IconThemeData(size: 22.5),
              selectedItemColor: customColor[700],
              unselectedItemColor: Colors.black,
              items: [
                const BottomNavigationBarItem(
                    icon: Icon(Icons.settings), label: 'Configuración'),
                BottomNavigationBarItem(
                  icon: Icon(Icons.radio_button_checked,
                      color: _serviceRunning ? Colors.green : Colors.red),
                  label: 'Conexión',
                ),
                const BottomNavigationBarItem(
                    icon: Icon(Icons.mark_email_unread),
                    label: 'Notificaciones'),
                const BottomNavigationBarItem(
                    icon: Icon(Icons.monitor_heart), label: 'Salud'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
