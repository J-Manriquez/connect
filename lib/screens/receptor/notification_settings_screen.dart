import 'package:connect/theme_colors.dart';
import 'package:flutter/material.dart';
import 'package:connect/services/local_notification_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
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
    final vibrationEnabled = await LocalNotificationService.isVibrationEnabled();

    setState(() {
      _soundEnabled = soundEnabled;
      _vibrationEnabled = vibrationEnabled;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración de Notificaciones'),
      ),
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
                  subtitle: const Text('Reproducir sonido al recibir notificaciones'),
                  value: _soundEnabled,
                  onChanged: _toggleSound,
                  activeTrackColor: customColor[300],
                  inactiveTrackColor: Colors.grey[300],
                  activeColor: customColor[700],
                ),
                SwitchListTile(
                  title: const Text('Vibración'),
                  subtitle: const Text('Vibrar al recibir notificaciones'),
                  value: _vibrationEnabled,
                  onChanged: _toggleVibration,
                  activeTrackColor: customColor[300],
                  inactiveTrackColor: Colors.grey[300],
                  activeColor: customColor[700],
                ),
              ],
            ),
    );
  }
}
