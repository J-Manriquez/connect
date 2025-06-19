import 'package:connect/theme_colors.dart';
import 'package:flutter/material.dart';
import 'package:connect/services/local_notification_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _autoOpenEnabled = false; // ✅ Agregar variable para auto-apertura
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });

    final soundEnabled = await LocalNotificationService.isSoundEnabled();
    final vibrationEnabled =
        await LocalNotificationService.isVibrationEnabled();
    final autoOpenEnabled = await LocalNotificationService.isAutoOpenEnabled(); // ✅ Cargar configuración

    setState(() {
      _soundEnabled = soundEnabled;
      _vibrationEnabled = vibrationEnabled;
      _autoOpenEnabled = autoOpenEnabled; // ✅ Asignar valor
      _isLoading = false;
    });
  }

  Future<void> _toggleSound(bool value) async {
    await LocalNotificationService.setSoundEnabled(value);
    setState(() {
      _soundEnabled = value;
    });
  }

  Future<void> _toggleVibration(bool value) async {
    await LocalNotificationService.setVibrationEnabled(value);
    setState(() {
      _vibrationEnabled = value;
    });
  }

  // // ✅ Agregar método para toggle de auto-apertura
  // Future<void> _toggleAutoOpen(bool value) async {
  //   await LocalNotificationService.setAutoOpenEnabled(value);
  //   setState(() {
  //     _autoOpenEnabled = value;
  //   });
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración de Notificaciones')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                const SizedBox(height: 16),
                const Text(
                  'Opciones de Sonido y Vibración',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Sonido'),
                  subtitle: const Text(
                    'Reproducir sonido al recibir notificaciones',
                  ),
                  value: _soundEnabled,
                  onChanged: _toggleSound,
                  activeColor: Colors.green,
                  inactiveTrackColor: customColor[200],
                  inactiveThumbColor: Colors.grey[300],
                ),
                SwitchListTile(
                  title: const Text('Vibración'),
                  subtitle: const Text('Vibrar al recibir notificaciones'),
                  value: _vibrationEnabled,
                  onChanged: _toggleVibration,
                  activeColor: Colors.green,
                  inactiveTrackColor: customColor[200],
                  inactiveThumbColor: Colors.grey[300],
                ),
                const SizedBox(height: 24), // ✅ Separador
                // const Text(
                //   'Opciones de Apertura Automática',
                //   style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                // ),
                // const SizedBox(height: 8),
                // // ✅ Agregar switch para auto-apertura
                // SwitchListTile(
                //   title: const Text('Abrir Aplicación Automáticamente'),
                //   subtitle: const Text(
                //     'Abrir la app y mostrar el detalle cuando llega una notificación',
                //   ),
                //   value: _autoOpenEnabled,
                //   onChanged: _toggleAutoOpen,
                //   activeColor: Colors.green,
                //   inactiveTrackColor: customColor[200],
                //   inactiveThumbColor: Colors.grey[300],
                // ),
              ],
            ),
    );
  }
}
