import 'package:flutter/material.dart';
import 'package:connect/services/local_notification_service.dart';
import 'package:permission_handler/permission_handler.dart';

class ReceptorSettingsScreen extends StatefulWidget {
  const ReceptorSettingsScreen({Key? key}) : super(key: key);

  @override
  State<ReceptorSettingsScreen> createState() => _ReceptorSettingsScreenState();
}

class _ReceptorSettingsScreenState extends State<ReceptorSettingsScreen> {
  bool _notificationsEnabled = false;
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

    final notificationsEnabled = await LocalNotificationService.areNotificationsEnabled();
    final soundEnabled = await LocalNotificationService.isSoundEnabled();
    final vibrationEnabled = await LocalNotificationService.isVibrationEnabled();

    setState(() {
      _notificationsEnabled = notificationsEnabled;
      _soundEnabled = soundEnabled;
      _vibrationEnabled = vibrationEnabled;
      _isLoading = false;
    });
  }

  Future<void> _toggleNotifications(bool value) async {
    if (value && await Permission.notification.isDenied) {
      final status = await Permission.notification.request();
      if (status.isDenied) {
        // El usuario rechazó los permisos
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Se requieren permisos de notificación para esta función'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    await LocalNotificationService.setNotificationsEnabled(value);
    setState(() {
      _notificationsEnabled = value;
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
        title: const Text('Configuración Receptor'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                const SizedBox(height: 16),
                const Text(
                  'Notificaciones',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Mostrar notificaciones locales'),
                  subtitle: const Text(
                      'Muestra las notificaciones recibidas en la barra de notificaciones'),
                  value: _notificationsEnabled,
                  onChanged: _toggleNotifications,
                ),
                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  'Configuración de notificaciones',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Sonido'),
                  subtitle: const Text('Reproducir sonido al recibir notificaciones'),
                  value: _soundEnabled,
                  onChanged: _notificationsEnabled ? _toggleSound : null,
                ),
                SwitchListTile(
                  title: const Text('Vibración'),
                  subtitle: const Text('Vibrar al recibir notificaciones'),
                  value: _vibrationEnabled,
                  onChanged: _notificationsEnabled ? _toggleVibration : null,
                ),
              ],
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1, // 0: Notificaciones, 1: Configuración, 2: No Leídas
        onTap: (index) {
          switch (index) {
            case 0:
              Navigator.pushReplacementNamed(context, '/notificaciones');
              break;
            case 1:
              // Ya estamos en configuración
              break;
            case 2:
              Navigator.pushReplacementNamed(context, '/unread_notifications');
              break;
          }
        },
        selectedFontSize: 14.0,
        unselectedFontSize: 12.0,
        selectedIconTheme: const IconThemeData(size: 37.5),
        unselectedIconTheme: const IconThemeData(size: 22.5),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Notificaciones',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Configuración',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.mark_email_unread),
            label: 'No Leídas',
          ),
        ],
      ),
    );
  }
}