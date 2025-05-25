import 'package:connect/services/firebase_service.dart';
import 'package:connect/theme_colors.dart';
import 'package:flutter/material.dart';
import 'package:connect/services/local_notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import SharedPreferences
import 'package:connect/services/receptor_service.dart'; // Import ReceptorService
import 'package:connect/services/preferences_service.dart'; // Import PreferencesService

class ReceptorSettingsScreen extends StatefulWidget {
  const ReceptorSettingsScreen({Key? key}) : super(key: key);

  @override
  State<ReceptorSettingsScreen> createState() => _ReceptorSettingsScreenState();
}

class _ReceptorSettingsScreenState extends State<ReceptorSettingsScreen> {
  bool _notificationsEnabled = false;
  bool _isLoading = true;

  final ReceptorService _receptorService =
      ReceptorService(); // Instantiate ReceptorService

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadNotificationSettings();
  }

  Future<void> _loadNotificationSettings() async {
    final notificationsEnabled =
        await LocalNotificationService.areNotificationsEnabled();
    setState(() {
      _notificationsEnabled = notificationsEnabled;
    });
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });

    // Removed loading of notification settings
    // final notificationsEnabled = await LocalNotificationService.areNotificationsEnabled();
    // final soundEnabled = await LocalNotificationService.isSoundEnabled();
    // final vibrationEnabled = await LocalNotificationService.isVibrationEnabled();

    setState(() {
      // Removed setting notification settings state
      // _notificationsEnabled = notificationsEnabled;
      // _soundEnabled = soundEnabled;
      // _vibrationEnabled = vibrationEnabled;
      _isLoading = false;
    });
  }

  // Removed toggle methods for notifications, sound, and vibration
  // Future<void> _toggleNotifications(bool value) async { ... }
  // Future<void> _toggleSound(bool value) async { ... }
  // Future<void> _toggleVibration(bool value) async { ... }

  // Desvincular dispositivo (Moved from NotificacionesScreen)
  Future<void> _unlinkDevice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Retrieve the linked device ID before removing it
      final deviceId = await _receptorService.getLinkedDeviceId();
      // Remove the device ID from preferences
      await prefs.remove(ReceptorService.KEY_LINKED_DEVICE_ID);
      // Update link status in Firebase if deviceId exists
      if (deviceId != null) {
        final firebaseservice = FirebaseService();
        await firebaseservice.updateLinkStatus(false, deviceId);
      }
      // Guardar preferencia de no usar como receptor
      await PreferencesService.saveUseAsReceptor(false);
      // Redirigir a la pantalla emisor
      Navigator.pushReplacementNamed(context, '/');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dispositivo desvinculado correctamente'),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      print('Error al desvincular dispositivo: \$e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al desvincular dispositivo: \$e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Método para volver a la pantalla emisor (Moved from NotificacionesScreen)
  Future<void> _backToEmisor() async {
    // Guardar preferencia de no usar como receptor
    await PreferencesService.saveUseAsReceptor(false);

    // Navegar a la pantalla emisor
    Navigator.pushReplacementNamed(context, '/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración Receptor')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // Removed Notificaciones section and toggles
                // const SizedBox(height: 16),
                // const Text(
                //   'Notificaciones',
                //   style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                // ),
                // const SizedBox(height: 8),
                // SwitchListTile( ... ),
                // const Divider(),

                // Add Card for Unlinking and Back to Emisor
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Opciones de Dispositivo',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: _unlinkDevice,
                          icon: const Icon(Icons.link_off),
                          label: const Text(
                            'Desvincular Dispositivo',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            backgroundColor: customColor[400],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        // const SizedBox(height: 8),
                        // ElevatedButton.icon(
                        //   onPressed: _backToEmisor,
                        //   icon: const Icon(Icons.arrow_back),
                        //   label: const Text(
                        //     'Volver a Pantalla Emisor',
                        //     style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        //   ),
                        //   style: ElevatedButton.styleFrom(
                        //     minimumSize: const Size.fromHeight(48),
                        //     padding: const EdgeInsets.symmetric(vertical: 12),
                        //     backgroundColor: customColor[400],
                        //     foregroundColor: Colors.white,
                        //     shape: RoundedRectangleBorder(
                        //       borderRadius: BorderRadius.circular(8),
                        //     ),
                        //   ),
                        // ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Add button to navigate to Notification Settings
                Card(
                  child: ListTile(
                    title: const Text('Configuración de Notificaciones'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        '/notification_settings',
                      ); // Navigate to new screen
                    },
                  ),
                ),

                // Removed Notification Settings section and toggles
                // const SizedBox(height: 8),
                // const Text(
                //   'Configuración de notificaciones',
                //   style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                // ),
                // const SizedBox(height: 8),
                // SwitchListTile( ... ),
                // SwitchListTile( ... ),
              ],
            ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 3,
            color: customColor[700], // Barra divisoria con customColor
          ),
          BottomNavigationBar(
            currentIndex:
                0, // 0: Configuración, 1: Notificaciones, 2: No Leídas
            onTap: (index) {
              switch (index) {
                case 0:
                  // Ya estamos en configuración
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
            selectedItemColor:
                customColor[700], // Color para el ítem seleccionado
            unselectedItemColor:
                Colors.black, // Color para los ítems no seleccionados
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
