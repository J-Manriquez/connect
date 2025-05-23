import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connect/services/firebase_service.dart';
import 'package:flutter/material.dart';
import 'package:connect/services/notification_filter_service.dart';  // Add this import

class EmisorScreen extends StatefulWidget {
  final List<Map<String, dynamic>> notifications;
  final bool isServiceRunning;

  const EmisorScreen({
    super.key, 
    required this.notifications,
    required this.isServiceRunning,
  });

  @override
  State<EmisorScreen> createState() => _EmisorScreenState();
}

class _EmisorScreenState extends State<EmisorScreen> with WidgetsBindingObserver {
  List<Map<String, dynamic>> _filteredNotifications = [];
  bool _isLoading = true;
  bool _isLinked = false; // Estado de vinculación
  String _deviceId = ''; // ID del dispositivo
  
  // Añadir un timer para actualizar periódicamente
  late final Stream _updateStream;
  late final StreamSubscription _updateSubscription;
  final FirebaseService _firebaseService = FirebaseService();

  @override
  void initState() {
    super.initState();
    _filterNotifications();
    _loadDeviceId();
    _checkLinkStatus();
    
    // Crear un stream que se ejecute cada 2 segundos para actualizar las notificaciones
    _updateStream = Stream.periodic(const Duration(seconds: 2));
    _updateSubscription = _updateStream.listen((_) {
      if (mounted) {
        _filterNotifications();
        _checkLinkStatus();
      }
    });
    
    // Registrar el observer para detectar cuando la app vuelve al primer plano
    WidgetsBinding.instance.addObserver(this);
  }
  
  // Cargar el ID del dispositivo desde SharedPreferences
  Future<void> _loadDeviceId() async {
    final deviceId = await _firebaseService.getDeviceId();
    setState(() {
      _deviceId = deviceId;
    });
  }
  
  // Verificar el estado de vinculación desde Firebase
  Future<void> _checkLinkStatus() async {
    try {
      final deviceId = await _firebaseService.getDeviceId();
      final docRef = FirebaseFirestore.instance.collection('dispositivos').doc(deviceId);
      final docSnapshot = await docRef.get();
      
      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        setState(() {
          _isLinked = data?['status-vinculacion'] ?? false;
        });
      }
    } catch (e) {
      print('Error al verificar estado de vinculación: $e');
    }
  }

  @override
  void didUpdateWidget(EmisorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si las notificaciones cambiaron, actualizar el filtro
    if (widget.notifications != oldWidget.notifications) {
      _filterNotifications();
    }
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Cuando la app vuelve al primer plano, actualizar las notificaciones
    if (state == AppLifecycleState.resumed) {
      _filterNotifications();
    }
  }

  Future<void> _filterNotifications() async {
    setState(() {
      _isLoading = true;
    });

    final filteredList = await NotificationFilterService.filterNotifications(widget.notifications);
    
    setState(() {
      _filteredNotifications = filteredList;
      _isLoading = false;
    });
  }
  
  @override
  void dispose() {
    // Cancelar la suscripción al stream y eliminar el observer
    _updateSubscription.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emisor de Notificaciones'),
      ),
      body: Column(
        children: [
          // Contenedor para el estado del servicio
          Container(
            margin: const EdgeInsets.all(8.0),
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: widget.isServiceRunning ? Colors.green[100] : Colors.red[100],
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(
                color: widget.isServiceRunning ? Colors.green : Colors.red,
                width: 1.0,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  widget.isServiceRunning ? Icons.check_circle : Icons.error,
                  color: widget.isServiceRunning ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8.0),
                Text(
                  'Estado del Servicio: ${widget.isServiceRunning ? 'Activo' : 'Inactivo'}',
                  style: TextStyle(
                    color: widget.isServiceRunning ? Colors.green[800] : Colors.red[800],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          
          // Contenedor para el estado de vinculación
          Container(
            margin: const EdgeInsets.all(8.0),
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: _isLinked ? Colors.green[100] : Colors.red[100],
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(
                color: _isLinked ? Colors.green : Colors.red,
                width: 1.0,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  _isLinked ? Icons.link : Icons.link_off,
                  color: _isLinked ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8.0),
                Text(
                  'Estado de Vinculación: ${_isLinked ? 'Vinculado' : 'No Vinculado'}',
                  style: TextStyle(
                    color: _isLinked ? Colors.green[800] : Colors.red[800],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          
          // Tarjeta para mostrar el ID del dispositivo
          Card(
            margin: const EdgeInsets.all(8.0),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    _deviceId,
                    style: const TextStyle(
                      fontSize: 50,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  const Text(
                    'Ingresa este código para vincular tu dispositivo',
                    style: TextStyle(
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          
          // Lista de notificaciones
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredNotifications.isEmpty
                    ? const Center(
                        child: Text(
                          'No hay notificaciones de las apps seleccionadas',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredNotifications.length,
                        itemBuilder: (context, index) {
                          final notification = _filteredNotifications[index];
                          return ListTile(
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
                          );
                        },
                      ),
          ),
        ],
      ),
      // Agregar el Bottom Navigation Bar
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1, // Índice actual (Emisor - ahora en el centro)
        onTap: (index) {
          // Navegar a la pantalla correspondiente según el índice
          switch (index) {
            case 0:
              // Navegar a la pantalla de configuración
              Navigator.pushNamed(context, '/settings');
              break;
            case 1:
              // Ya estamos en la pantalla Emisor
              break;
            case 2:
              // Navegar a la pantalla de lista de apps
              Navigator.pushNamed(context, '/app_list').then((_) {
                // Actualizar el filtro cuando regrese de la pantalla de apps
                _filterNotifications();
              });
              break;
          }
        },
        selectedFontSize: 14.0,
        unselectedFontSize: 12.0,
        selectedIconTheme: const IconThemeData(size: 37.5), // 2.5 veces el tamaño normal (15*2.5)
        unselectedIconTheme: const IconThemeData(size: 22.5), // 1.5 veces el tamaño normal (15*1.5)
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Configuración',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.send), // Icono que refleja emisión
            label: 'Emisor',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.apps),
            label: 'Aplicaciones',
          ),
        ],
      ),
    );
  }
}