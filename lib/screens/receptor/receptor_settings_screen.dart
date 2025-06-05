import 'package:connect/services/firebase_service.dart';
import 'package:connect/services/notification_listener_service.dart';
import 'package:connect/theme_colors.dart';
import 'package:flutter/material.dart';
import 'package:connect/services/local_notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connect/services/receptor_service.dart';
import 'package:connect/services/preferences_service.dart';

class ReceptorSettingsScreen extends StatefulWidget {
  const ReceptorSettingsScreen({Key? key}) : super(key: key);

  @override
  State<ReceptorSettingsScreen> createState() => _ReceptorSettingsScreenState();
}

class _ReceptorSettingsScreenState extends State<ReceptorSettingsScreen> {
  bool _notificationsEnabled = false;
  bool _autoOpenEnabled = false;
  bool _isLoading = true;

  final ReceptorService _receptorService = ReceptorService();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });

    final notificationsEnabled =
        await LocalNotificationService.areNotificationsEnabled();
    final autoOpenEnabled = await LocalNotificationService.isAutoOpenEnabled();

    setState(() {
      _notificationsEnabled = notificationsEnabled;
      _autoOpenEnabled = autoOpenEnabled;
      _isLoading = false;
    });
  }

  Future<void> _toggleAutoOpen(bool value) async {
    await LocalNotificationService.setAutoOpenEnabled(value);
    setState(() {
      _autoOpenEnabled = value;
    });
  }

  // Desvincular dispositivo
  Future<void> _unlinkDevice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceId = await _receptorService.getLinkedDeviceId();
      await prefs.remove(ReceptorService.KEY_LINKED_DEVICE_ID);

      if (deviceId != null) {
        final firebaseservice = FirebaseService();
        await firebaseservice.updateLinkStatus(false, deviceId);
      }

      await PreferencesService.saveUseAsReceptor(false);
      await LocalNotificationService.setNotificationsEnabled(false);
      await NotificationListenerService.instance.setListeningEnabled(false);

      setState(() {
        _notificationsEnabled = false;
      });

      Navigator.pushReplacementNamed(context, '/');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dispositivo desvinculado correctamente'),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      print('Error al desvincular dispositivo: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al desvincular dispositivo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración Receptor')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(5.0),
              children: [
                // Opciones de Dispositivo
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(15.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Opciones de Dispositivo',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          margin: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 8,
                          ),
                          child: ElevatedButton.icon(
                            onPressed: _unlinkDevice,
                            icon: const Icon(Icons.link_off),
                            label: const Text(
                              'Desvincular Dispositivo',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: customColor[400],
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Configuración de Notificaciones
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 8,
                          ),
                          child: Text(
                            'Configuración de Notificaciones',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(left: 15),
                                  child: Text(
                                    'Abrir aplicación automáticamente',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.only(left: 15),
                                  child: Text(
                                    'Abre la aplicación automáticamente \ncuando llega una notificación',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Switch(
                              value: _autoOpenEnabled,
                              onChanged: _toggleAutoOpen,
                              activeColor: Colors.green,
                              inactiveTrackColor: customColor[200],
                              inactiveThumbColor: Colors.grey[300],
                            ),
                          ],
                        ),
                        const Divider(),
                        // Botón para configuraciones avanzadas
                        ListTile(
                          title: const Text(
                            'Configuraciones Avanzadas',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: const Text(
                            'Sonido, vibración y más opciones',
                            style: TextStyle(
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios),
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              '/notification_settings',
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(height: 3, color: customColor[700]),
          BottomNavigationBar(
            currentIndex: 0,
            onTap: (index) {
              switch (index) {
                case 0:
                  break;
                case 1:
                  Navigator.pushReplacementNamed(context, '/notificaciones');
                  break;
                case 2:
                  Navigator.pushReplacementNamed(
                    context,
                    '/unread_notifications',
                  );
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
                icon: Icon(Icons.settings),
                label: 'Configuración',
              ),
              BottomNavigationBarItem(
                icon: Icon(
                  Icons.radio_button_checked,
                  color: _notificationsEnabled ? Colors.green : Colors.red,
                ),
                label: 'Notificaciones',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.mark_email_unread),
                label: 'No Leídas',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
