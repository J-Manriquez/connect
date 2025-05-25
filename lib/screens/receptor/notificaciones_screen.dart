import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connect/theme_colors.dart';
import 'package:flutter/material.dart';
import 'package:connect/services/receptor_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connect/services/preferences_service.dart';
import 'package:connect/services/local_notification_service.dart';

class NotificacionesScreen extends StatefulWidget {
  const NotificacionesScreen({Key? key}) : super(key: key);

  @override
  State<NotificacionesScreen> createState() => _NotificacionesScreenState();
}

class _NotificacionesScreenState extends State<NotificacionesScreen> {
  final ReceptorService _receptorService = ReceptorService();

  bool _isLoading = false;
  List<Map<String, dynamic>> _notifications = [];
  StreamSubscription? _notificationSubscription;
  String? _linkedDeviceId;
  bool _notificationsEnabled = false; // Add state for the toggle
  bool _showSubtitle = false;

  @override
  void initState() {
    super.initState();
    _loadLinkedDevice();
    _loadNotificationSettings(); // Load initial state for the toggle
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  // Load initial state for the notification toggle
  Future<void> _loadNotificationSettings() async {
    final notificationsEnabled =
        await LocalNotificationService.areNotificationsEnabled();
    setState(() {
      _notificationsEnabled = notificationsEnabled;
    });
  }

  // Cargar el dispositivo vinculado y comenzar a escuchar notificaciones
  Future<void> _loadLinkedDevice() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Obtener el ID del dispositivo emisor vinculado
      final deviceId = await _receptorService.getLinkedDeviceId();

      if (deviceId != null) {
        setState(() {
          _linkedDeviceId = deviceId;
        });

        // Iniciar escucha de notificaciones
        _startListeningForNotifications();
      } else {
        // Si no hay dispositivo vinculado, redirigir a la pantalla de vinculación
        Navigator.pushReplacementNamed(context, '/receptor');
      }
    } catch (e) {
      print('Error al cargar dispositivo vinculado: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Iniciar escucha de notificaciones
  // Añadir este import al inicio del archivo
  // import 'package:connect/services/local_notification_service.dart';

  // En la clase _NotificacionesScreenState, añadir este método para mostrar notificaciones locales
  // Añadir después del método _startListeningForNotifications

  void _startListeningForNotifications() {
    // Escuchar todas las notificaciones y filtrar las visualizadas para mostrar en la lista
    _notificationSubscription = _receptorService
        .listenForNotifications() // Listen to all notifications
        .listen(
          (allNotifications) {
            // Filter only the visualized notifications (status-visualizacion = true)
            final visualizedNotifications = allNotifications.where((
              notification,
            ) {
              return notification['status-visualizacion'] == true;
            }).toList();

            setState(() {
              _notifications = visualizedNotifications;
            });

            // Removed the call to _showLocalNotification and _updateVisualizedNotificationsList()
            // Local notification logic should be handled elsewhere (e.g., main.dart)
          },
          onError: (error) {
            print('Error en la suscripción de notificaciones: -$error');
          },
        );
  }

  // Removed the _updateVisualizedNotificationsList method

  // Añadir este método para mostrar notificaciones locales
  //  Future<void> _showLocalNotification(Map<String, dynamic> notification) async {
  //   try {
  //     // Mostrar la notificación local
  //     await LocalNotificationService.showNotification(
  //       title: notification['title'] ?? 'Nueva notificación',
  //       body: notification['text'] ?? '',
  //       packageName: notification['packageName'] ?? '',
  //       appName: notification['appName'] ?? 'Desconocida',
  //     );

  //     // Actualizar el estado de visualización a true
  //     final String notificationId = notification['id'] ?? '';
  //     if (notificationId.isNotEmpty) {
  //       await _receptorService.updateNotificationVisualizationStatus(notificationId, true);
  //       print('Notificación marcada como visualizada: $notificationId');
  //     }
  //   } catch (e) {
  //     print('Error al mostrar notificación local: $e');
  //   }
  // }

  // Desvincular dispositivo (Moved to ReceptorSettingsScreen)
  // Future<void> _unlinkDevice() async { ... }

  // Método para volver a la pantalla emisor (Moved to ReceptorSettingsScreen)
  // Future<void> _backToEmisor() async { ... }

  // Toggle for local notifications (Moved from ReceptorSettingsScreen)
  Future<void> _toggleNotifications(bool value) async {
    if (value && await Permission.notification.isDenied) {
      final status = await Permission.notification.request();
      if (status.isDenied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Se requieren permisos de notificación para esta función',
            ),
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

  Widget _buildNotificationToggle() {
    final isActive = _notificationsEnabled;
    return GestureDetector(
      onTap: () {
        setState(() {
          _showSubtitle = !_showSubtitle;
        });
        // if (_showSubtitle) {
        //   ScaffoldMessenger.of(context).showSnackBar(
        //     const SnackBar(
        //       content: Text('Muestra las notificaciones recibidas en la barra de notificaciones'),
        //       duration: Duration(seconds: 2),
        //     ),
        //   );
        // }
      },
      child: Container(
        decoration: BoxDecoration(
          color: isActive ? Colors.green[50] : Colors.red[50],
          border: Border.all(
            color: isActive ? Colors.green : Colors.red,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        margin: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mostrar notificaciones locales',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isActive ? Colors.green[900] : Colors.red[900],
                      fontSize: 16,
                    ),
                  ),
                  if (_showSubtitle)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        'Muestra las notificaciones recibidas en la barra de notificaciones',
                        style: TextStyle(
                          color: isActive ? Colors.green[700] : Colors.red[700],
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Switch(
              value: _notificationsEnabled,
              onChanged: _toggleNotifications,
              activeColor: Colors.green,
              inactiveThumbColor: Colors.red,
              inactiveTrackColor: Colors.red[200],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receptor de Notificaciones'),
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          const Icon(Icons.link, color: Colors.green),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Dispositivo vinculado',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                                Text(
                                  'ID: $_linkedDeviceId',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildNotificationToggle(),
                  const Divider(),
                  const SizedBox(height: 16),
                  const Text(
                    'Notificaciones recibidas:',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _notifications.isEmpty
                        ? const Center(
                            child: Text('No hay notificaciones recibidas'),
                          )
                        : ListView.builder(
                            itemCount: _notifications.length,
                            itemBuilder: (context, index) {
                              final notification = _notifications[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8.0),
                                child: ListTile(
                                  title: Text(
                                    notification['title'] ?? 'Sin título',
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        notification['text'] ?? 'Sin contenido',
                                      ),
                                      Text(
                                        'App: ${notification['appName'] ?? notification['packageName'] ?? 'Desconocida'}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: Text(
                                    _formatTimestamp(notification['timestamp']),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
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
                1, // 0: Configuración, 1: Notificaciones, 2: No Leídas
            onTap: (index) {
              switch (index) {
                case 0:
                  Navigator.pushReplacementNamed(context, '/receptor_settings');
                  break;
                case 1:
                  Navigator.pushReplacementNamed(context, '/receptor_settings');
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

  // Formatear timestamp para mostrar
  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';

    final DateTime date = (timestamp as Timestamp).toDate();
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
