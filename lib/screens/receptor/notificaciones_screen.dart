import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:connect/services/receptor_service.dart';
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

  @override
  void initState() {
    super.initState();
    _loadLinkedDevice();
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
        .listen((allNotifications) {
      // Filter only the visualized notifications (status-visualizacion = true)
      final visualizedNotifications = allNotifications.where((notification) {
        return notification['status-visualizacion'] == true;
      }).toList();

      setState(() {
        _notifications = visualizedNotifications;
      });

      // Removed the call to _showLocalNotification and _updateVisualizedNotificationsList()
      // Local notification logic should be handled elsewhere (e.g., main.dart)
    }, onError: (error) {
      print('Error en la suscripción de notificaciones: -$error');
    });
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
  
  // Desvincular dispositivo
  Future<void> _unlinkDevice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(ReceptorService.KEY_LINKED_DEVICE_ID);
      
      // Cancelar la suscripción a notificaciones
      _notificationSubscription?.cancel();
      
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
      print('Error al desvincular dispositivo: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al desvincular dispositivo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Método para volver a la pantalla emisor
  Future<void> _backToEmisor() async {
    // Guardar preferencia de no usar como receptor
    await PreferencesService.saveUseAsReceptor(false);
    
    // Navegar a la pantalla emisor
    Navigator.pushReplacementNamed(context, '/');
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones Recibidas'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.link_off),
            tooltip: 'Desvincular',
            onPressed: _unlinkDevice,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Botón para volver a la pantalla emisor
                  ElevatedButton.icon(
                    onPressed: _backToEmisor,
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Volver a Emisor'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(40),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Sección de dispositivo vinculado
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
                  const Text(
                    'Notificaciones recibidas:',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
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
                                  title: Text(notification['title'] ?? 'Sin título'),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(notification['text'] ?? 'Sin contenido'),
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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0, // 0: Notificaciones, 1: Configuración, 2: No Leídas
        onTap: (index) {
          switch (index) {
            case 0:
              // Ya estamos en notificaciones
              break;
            case 1:
              Navigator.pushReplacementNamed(context, '/receptor_settings');
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

  // Formatear timestamp para mostrar
  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    
    final DateTime date = (timestamp as Timestamp).toDate();
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}