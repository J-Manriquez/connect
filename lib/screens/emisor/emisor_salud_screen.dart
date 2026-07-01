import 'dart:async';
import 'package:connect/theme_colors.dart';
import 'package:flutter/material.dart';
import '../../services/sensor_service.dart';

/// Pantalla hub de Salud para el EMISOR.
/// Solo muestra datos recibidos del receptor por BT — no ejecuta sensores.
class EmisorSaludScreen extends StatefulWidget {
  const EmisorSaludScreen({super.key});

  @override
  State<EmisorSaludScreen> createState() => _EmisorSaludScreenState();
}

class _EmisorSaludScreenState extends State<EmisorSaludScreen> {
  // Datos recibidos por BT (parseados en BtClassicServerService)
  int _lastBpm = 0;
  int _lastSteps = 0;
  String _lastZona = '—';
  String _wristState = '—';
  DateTime? _lastUpdate;

  StreamSubscription<Map<String, dynamic>>? _debugSub;

  @override
  void initState() {
    super.initState();
    SensorService.initDebugStream();
    // Escuchar logs del SensorService para parsear datos BT entrantes
    _debugSub = SensorService.debugLogStream.listen(_onDebugLog);
  }

  void _onDebugLog(Map<String, dynamic> log) {
    final src = log['source']?.toString() ?? '';
    final msg = log['message']?.toString() ?? '';
    // Parsear datos BT que vienen del receptor
    if (src == 'bt_sensor_rx') {
      if (msg.startsWith('HR:')) {
        final bpm = int.tryParse(msg.substring(3)) ?? 0;
        if (!mounted) return;
        setState(() { _lastBpm = bpm; _lastUpdate = DateTime.now(); });
      } else if (msg.startsWith('STEPS:')) {
        final steps = int.tryParse(msg.substring(6)) ?? 0;
        if (!mounted) return;
        setState(() { _lastSteps = steps; _lastUpdate = DateTime.now(); });
      } else if (msg.startsWith('HR_ZONA:')) {
        if (!mounted) return;
        setState(() { _lastZona = msg.substring(8); _lastUpdate = DateTime.now(); });
      } else if (msg.startsWith('WRIST:')) {
        if (!mounted) return;
        setState(() {
          _wristState = msg.substring(6) == 'ON' ? 'Puesta' : 'Quitada';
          _lastUpdate = DateTime.now();
        });
      }
    }
  }

  @override
  void dispose() {
    _debugSub?.cancel();
    super.dispose();
  }

  String get _lastUpdateStr {
    if (_lastUpdate == null) return 'Sin datos del receptor';
    final dt = _lastUpdate!;
    return 'Última actualización: ${dt.hour.toString().padLeft(2,'0')}:'
        '${dt.minute.toString().padLeft(2,'0')}:'
        '${dt.second.toString().padLeft(2,'0')}';
  }

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
              borderRadius: BorderRadius.circular(10)),
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
                      fontSize: 20, fontWeight: FontWeight.bold, color: c)),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  Widget _buildResumenTab() => _tabPage([
        _tabHeader('Resumen del receptor',
            'Datos recibidos en tiempo real por Bluetooth.'),
        Card(
          color: customColor[50],
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _row(Icons.watch, 'Muñeca', _wristState),
                _row(Icons.favorite, 'Corazón',
                    _lastBpm > 0 ? '$_lastBpm bpm · ${HrData.zonaLabel(_lastZona)}' : '—'),
                _row(Icons.directions_walk, 'Pasos hoy', '$_lastSteps'),
                const SizedBox(height: 4),
                Text(_lastUpdateStr,
                    style: const TextStyle(
                        fontSize: 11, color: Colors.black38)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (_lastBpm == 0 && _lastSteps == 0)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Sin datos del receptor.\n'
                'Asegúrate de que el receptor tenga el servicio\n'
                'de sensores activo y esté conectado por BT.',
                style: TextStyle(color: Colors.black54),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ]);

  Widget _row(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Text('$label: ', style: const TextStyle(fontSize: 13)),
            Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );

  Widget _buildCorazonTab() => _tabPage([
        _tabHeader('Corazón', 'Historial de HR recibido del receptor.'),
        _navCard(
          icon: Icons.favorite,
          title: 'Monitor cardíaco',
          subtitle: 'Historial BPM, zona y calorías',
          value: _lastBpm > 0 ? '$_lastBpm bpm' : 'Sin datos',
          color: Colors.red[600],
          onTap: () => Navigator.pushNamed(context, '/emisor_salud_hr'),
        ),
      ]);

  Widget _buildPasosTab() => _tabPage([
        _tabHeader('Pasos', 'Contador de pasos del receptor recibido por BT.'),
        _navCard(
          icon: Icons.directions_walk,
          title: 'Pasos del día',
          subtitle: 'Pasos y distancia estimada',
          value: '$_lastSteps pasos',
          color: Colors.green[700],
          onTap: () => Navigator.pushNamed(context, '/emisor_salud_pasos'),
        ),
      ]);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
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
                  Navigator.pushNamed(context, '/emisor_salud_debug'),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'Resumen', icon: Icon(Icons.dashboard)),
              Tab(text: 'Corazón', icon: Icon(Icons.favorite)),
              Tab(text: 'Pasos', icon: Icon(Icons.directions_walk)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildResumenTab(),
            _buildCorazonTab(),
            _buildPasosTab(),
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
                    Navigator.pushReplacementNamed(context, '/settings');
                    break;
                  case 1:
                    Navigator.pushReplacementNamed(context, '/');
                    break;
                  case 2:
                    Navigator.pushReplacementNamed(context, '/app_list');
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
              items: const [
                BottomNavigationBarItem(
                    icon: Icon(Icons.settings), label: 'Configuración'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.send), label: 'Emisor'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.apps), label: 'Aplicaciones'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.monitor_heart), label: 'Salud'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
