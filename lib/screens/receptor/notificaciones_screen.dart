import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connect/models/notification_data.dart';
import 'package:connect/services/firebase_service.dart';
import 'package:connect/services/notification_listener_service.dart';
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
  Map<String, List<Map<String, dynamic>>> _groupedNotifications = {};
  Map<String, bool> _expandedDays = {};

  @override
  void initState() {
    super.initState();
    _loadLinkedDevice();
    _loadNotificationSettings(); // Load initial state for the toggle
    _startListeningForReadNotifications();
  }

  // Load initial state for the notification toggle
  Future<void> _loadNotificationSettings() async {
    final notificationsEnabled =
        await LocalNotificationService.areNotificationsEnabled();
    setState(() {
      _notificationsEnabled = notificationsEnabled;
    });
    
    // Iniciar o detener el servicio según el estado del toggle
    await NotificationListenerService.instance.setListeningEnabled(notificationsEnabled);
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
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
        _startListeningForReadNotifications();
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


// Iniciar escucha de notificaciones no leídas
  void _startListeningForReadNotifications() {
    _notificationSubscription = _receptorService
        .listenForSeenNotifications()
        .listen(
          (notifications) {
            // Agrupar por día
            final Map<String, List<Map<String, dynamic>>> grouped = {};
            for (var notification in notifications) {
              final timestamp = notification['timestamp'] as Timestamp?;
              if (timestamp == null) continue;
              final date = timestamp.toDate();
              final dateKey =
                  '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
              if (!grouped.containsKey(dateKey)) {
                grouped[dateKey] = [];
                if (!_expandedDays.containsKey(dateKey)) {
                  _expandedDays[dateKey] = true;
                }
              }
              grouped[dateKey]!.add(notification);
            }

            setState(() {
              _notifications = notifications;
              _groupedNotifications = grouped;
            });
          },
          onError: (error) {
            print(
              'Error en la suscripción de notificaciones no leídas: $error',
            );
          },
        );
  }

  // Toggle for local notifications
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

    // Habilitar/deshabilitar notificaciones locales
    await LocalNotificationService.setNotificationsEnabled(value);
    
    // Habilitar/deshabilitar el servicio de escucha de notificaciones
    await NotificationListenerService.instance.setListeningEnabled(value);
    
    setState(() {
      _notificationsEnabled = value;
    });
  }

  Future<void> _deleteNotification(Map<String, dynamic> notification) async {
    try {
      final notificationId = notification['id'] as String?;
      final timestamp = notification['timestamp'] as Timestamp?;
      if (notificationId == null || timestamp == null) return;
      final date = timestamp.toDate();
      final dateId = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      // Usa tu servicio de Firebase para eliminar
      await FirebaseService().deleteNotification(notificationId, dateId);
    } catch (e) {
      print('Error al eliminar notificación: \$e');
    }
  }

  Widget _buildNotificationToggle() {
    final isActive = _notificationsEnabled;
    return GestureDetector(
      onTap: () {
        setState(() {
          _showSubtitle = !_showSubtitle;
        });
      },
      child: Container(
        margin: const EdgeInsets.all(0),
        decoration: BoxDecoration(
          color: isActive ? Colors.green[50] : Colors.red[50],
          border: Border.all(
            color: isActive ? Colors.green : Colors.red,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        // margin: const EdgeInsets.only(bottom: 12),
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
                      padding: const EdgeInsets.only(top: 1.0),
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
  // Método para formatear la fecha en formato legible
  String _formatDate(String dateKey) {
    try {
      final parts = dateKey.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final day = int.parse(parts[2]);

      final date = DateTime(year, month, day);
      final now = DateTime.now();
      final yesterday = DateTime.now().subtract(const Duration(days: 1));

      if (date.year == now.year &&
          date.month == now.month &&
          date.day == now.day) {
        return 'Hoy';
      } else if (date.year == yesterday.year &&
          date.month == yesterday.month &&
          date.day == yesterday.day) {
        return 'Ayer';
      } else {
        // Formato: 25 Mayo 2023
        final months = [
          'Enero',
          'Febrero',
          'Marzo',
          'Abril',
          'Mayo',
          'Junio',
          'Julio',
          'Agosto',
          'Septiembre',
          'Octubre',
          'Noviembre',
          'Diciembre',
        ];
        return '$day ${months[month - 1]} $year';
      }
    } catch (e) {
      return dateKey; // En caso de error, devolver la clave original
    }
  }

  // Método para formatear la hora
  String _formatTime(DateTime timestamp) {
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
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
              padding: const EdgeInsets.all(5.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  Card(
                    margin: const EdgeInsets.all(0),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          const Icon(Icons.link, color: Colors.green),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                  const SizedBox(height: 10),
                  _buildNotificationToggle(),
                  // const Divider(),
                  // const SizedBox(height: 8),
                  // const Text(
                  //   'Notificaciones recibidas:',
                  //   style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  // ),
                  // const SizedBox(height: 8),
                  Expanded(
      child: _groupedNotifications.isEmpty
          ? const Center(child: Text('No hay notificaciones recibidas'))
          : ListView(
              children: _groupedNotifications.entries.map((entry) {
                final dateKey = entry.key;
                final notifications = entry.value;
                final isExpanded = _expandedDays[dateKey] ?? true;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      title: Text(_formatDate(dateKey), style: const TextStyle(fontWeight: FontWeight.bold)),
                      trailing: IconButton(
                        icon: Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
                        onPressed: () {
                          setState(() {
                            _expandedDays[dateKey] = !isExpanded;
                          });
                        },
                      ),
                    ),
                    if (isExpanded)
                      ...notifications.map((notification) {
                        return Dismissible(
                          key: UniqueKey(),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            color: Colors.red,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          onDismissed: (direction) async {
                            await _deleteNotification(notification);
                          },
                          child: Card(
                            margin: const EdgeInsets.only(bottom: 8.0, left: 1, right: 1),
                            child: ListTile(
                              title: Text(notification['title'] ?? 'Sin título'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(notification['text'] ?? 'Sin contenido'),
                                  Text('App: ${notification['appName'] ?? notification['packageName'] ?? 'Desconocida'}', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                                ],
                              ),
                              trailing: Text(_formatTimestamp(notification['timestamp']), style: const TextStyle(fontSize: 12)),
                            ),
                          ),
                        );
                      }).toList(),
                  ],
                );
              }).toList(),
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
