import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connect/screens/receptor/notification_detail_screen.dart';
import 'package:connect/services/local_notification_service.dart';
import 'package:connect/theme_colors.dart';
import 'package:flutter/material.dart';
import 'package:connect/services/receptor_service.dart';

class UnreadNotificationsScreen extends StatefulWidget {
  const UnreadNotificationsScreen({Key? key}) : super(key: key);

  @override
  State<UnreadNotificationsScreen> createState() =>
      _UnreadNotificationsScreenState();
}

class _UnreadNotificationsScreenState extends State<UnreadNotificationsScreen> {
  final ReceptorService _receptorService = ReceptorService();

  bool _isLoading = false;
  List<Map<String, dynamic>> _unreadNotifications = [];
  StreamSubscription? _notificationSubscription;
  bool _notificationsEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadUnreadNotifications();
    _loadNotificationSettings();
  }

  Future<void> _loadNotificationSettings() async {
    final notificationsEnabled =
        await LocalNotificationService.areNotificationsEnabled();
    setState(() {
      _notificationsEnabled = notificationsEnabled;
    });
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  // Cargar notificaciones no leídas
  Future<void> _loadUnreadNotifications() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Iniciar escucha de notificaciones no leídas
      _startListeningForUnreadNotifications();
    } catch (e) {
      print('Error al cargar notificaciones no leídas: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Iniciar escucha de notificaciones no leídas
  void _startListeningForUnreadNotifications() {
    _notificationSubscription = _receptorService
        .listenForUnseenNotifications()
        .listen(
          (notifications) {
            setState(() {
              _unreadNotifications = notifications;
            });
          },
          onError: (error) {
            print(
              'Error en la suscripción de notificaciones no leídas: $error',
            );
          },
        );
  }

  // Marcar notificación como leída
  Future<void> _markAsRead(Map<String, dynamic> notification) async {
    try {
      final String notificationId = notification['id'] ?? '';
      if (notificationId.isNotEmpty) {
        await _receptorService.updateNotificationVisualizationStatus(
          notificationId,
          true,
        );

        // Eliminar la notificación de la lista local
        setState(() {
          _unreadNotifications.removeWhere(
            (item) => item['id'] == notificationId,
          );
        });
      }
    } catch (e) {
      print('Error al marcar notificación como leída: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al marcar como leída: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones No Leídas'),
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // const Text(
                  //   'Notificaciones pendientes:',
                  //   style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  // ),
                  // const SizedBox(height: 8),
                  Expanded(
                    child: _unreadNotifications.isEmpty
                        ? const Center(
                            child: Text('No hay notificaciones pendientes'),
                          )
                        : ListView.builder(
                            itemCount: _unreadNotifications.length,
                            itemBuilder: (context, index) {
                              final notification = _unreadNotifications[index];
                              return 
                              GestureDetector(
                                onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                   NotificationDetailScreen(notificationData: notification),
                                              ),
                                            );
                                          },
                                child: Card(
                                margin: const EdgeInsets.only(left: 5, right: 5, bottom: 5, top: 5),
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
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _formatTimestamp(
                                          notification['timestamp'],
                                        ),
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.check_circle_outline,
                                        ),
                                        tooltip: 'Marcar como leída',
                                        onPressed: () =>
                                            _markAsRead(notification),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            
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
                2, // 0: Configuración, 1: Notificaciones, 2: No Leídas
            onTap: (index) {
              switch (index) {
                case 0:
                  Navigator.pushReplacementNamed(context, '/receptor_settings');
                  break;
                case 1:
                  Navigator.pushReplacementNamed(context, '/notificaciones');
                  break;
                case 2:
                  // Ya estamos en no leídas
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
