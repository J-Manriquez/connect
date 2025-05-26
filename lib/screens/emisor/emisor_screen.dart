import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connect/models/notification_data.dart';
import 'package:connect/services/firebase_service.dart';
import 'package:connect/services/preferences_service.dart'; // Añadir esta importación
import 'package:connect/services/receptor_service.dart';
import 'package:flutter/material.dart';
import 'package:connect/services/notification_filter_service.dart'; // Add this import
import 'package:connect/theme_colors.dart';

class EmisorScreen extends StatefulWidget {
  final List<Map<String, dynamic>> notifications;
  final bool isServiceRunning;
  final bool isSavingToFirebase;
  final Function(bool) toggleSaveToFirebase;
  final Function() checkPermissionStatus; // Añadir este parámetro
  final Function() openNotificationSettings; // Añadir este parámetro

  const EmisorScreen({
    super.key,
    required this.notifications,
    required this.isServiceRunning,
    required this.isSavingToFirebase,
    required this.toggleSaveToFirebase,
    required this.checkPermissionStatus, // Requerido
    required this.openNotificationSettings, // Requerido
  });

  @override
  State<EmisorScreen> createState() => _EmisorScreenState();
}

class _EmisorScreenState extends State<EmisorScreen>
    with WidgetsBindingObserver {
  List<Map<String, dynamic>> _filteredNotifications = [];
  List<NotificationData> _storedNotifications =
      []; // Nueva lista para notificaciones almacenadas
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
    _loadStoredNotifications(); // Cargar notificaciones almacenadas

    // Crear un stream que se ejecute cada 2 segundos para actualizar las notificaciones
    _updateStream = Stream.periodic(const Duration(seconds: 2));
    _updateSubscription = _updateStream.listen((_) {
      if (mounted) {
        _filterNotifications();
        _checkLinkStatus();
        _loadStoredNotifications(); // Actualizar notificaciones almacenadas
      }
    });

    // Registrar el observer para detectar cuando la app vuelve al primer plano
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkInitialRoute(context);
    });
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
      final docRef = FirebaseFirestore.instance
          .collection('dispositivos')
          .doc(deviceId);
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
      _checkLinkStatus();
      _loadStoredNotifications(); // Actualizar notificaciones almacenadas
    }
  }

  Future<void> _filterNotifications() async {
    setState(() {
      _isLoading = true;
    });

    final filteredList = await NotificationFilterService.filterNotifications(
      widget.notifications,
    );

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

  // Método para cargar las notificaciones almacenadas en Firebase
  Future<void> _loadStoredNotifications() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Obtener las notificaciones almacenadas desde Firebase
      final notifications = await _firebaseService.getStoredNotifications();

      setState(() {
        _storedNotifications = notifications;
        _isLoading = false;
      });

      print('Notificaciones cargadas desde Firebase: ${notifications.length}');
    } catch (e) {
      print('Error al cargar notificaciones desde Firebase: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Método para navegar a la pantalla de receptor y verificar permisos
  Future<void> _navigateToReceptor(BuildContext context) async {
    // Verificar si el permiso está concedido
    widget.checkPermissionStatus();

    // Si el permiso no está concedido, mostrar diálogo
    if (!widget.isServiceRunning) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: Colors.grey[100],
            title: Text(
              'Permiso requerido',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: customColor[600],
              ),
            ),
            content: const Text(
              'Para usar la app como receptor, necesitas conceder permiso para acceder a las notificaciones.',
              style: TextStyle(fontSize: 16),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text(
                  'Cancelar',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.openNotificationSettings();
                },
                style: TextButton.styleFrom(
                  backgroundColor: customColor[400],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
                child: const Text('Abrir configuración'),
              ),
            ],
          );
        },
      );

      return;
    }

    // Guardar preferencia de usar como receptor
    await PreferencesService.saveUseAsReceptor(true);

    // Navegar a la pantalla de receptor (usar pushReplacementNamed en lugar de pushNamed)
    Navigator.pushReplacementNamed(context, '/receptor');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emisor de Notificaciones'),
        actions: [
          // Icono para activar/desactivar guardado en Firebase
          IconButton(
            icon: Icon(
              widget.isSavingToFirebase ? Icons.cloud_done : Icons.cloud_off,
              size: 40,
              color: widget.isSavingToFirebase ? Colors.green : Colors.grey,
            ),
            tooltip: widget.isSavingToFirebase
                ? 'Desactivar guardado en Firebase'
                : 'Activar guardado en Firebase',
            onPressed: () =>
                widget.toggleSaveToFirebase(!widget.isSavingToFirebase),
          ),
        ],
      ),
      body: Column(
        children: [
          // Botón para navegar a la pantalla Receptor
          Padding(
            padding: const EdgeInsets.only(
              top: 20.0,
              left: 16.0,
              right: 16.0,
              bottom: 10.0,
            ),
            child: ElevatedButton.icon(
              onPressed: () => _navigateToReceptor(context),
              icon: const Icon(Icons.watch, color: Colors.white),
              label: const Text(
                'Usar App como Receptor',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                backgroundColor:
                    customColor[400], // Dos tonos más claro que el original
              ),
            ),
          ),
          // Contenedor para el estado del servicio
          Container(
            margin: const EdgeInsets.only(
              left: 16.0,
              right: 16.0,
              bottom: 10.0,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 8.0,
              vertical: 16.0,
            ),
            decoration: BoxDecoration(
              color: widget.isServiceRunning
                  ? Colors.green[100]
                  : Colors.red[100],
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
                    color: widget.isServiceRunning
                        ? Colors.green[800]
                        : Colors.red[800],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Contenedor para el estado de vinculación
          Container(
            margin: const EdgeInsets.only(
              left: 16.0,
              right: 16.0,
              bottom: 10.0,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 8.0,
              vertical: 16.0,
            ),
            decoration: BoxDecoration(
              color: _isLinked ? Colors.green[100] : Colors.red[100],
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(
                color: _isLinked ? Colors.green : Colors.red,
                width: 1.0,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
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
            margin: const EdgeInsets.only(
              left: 16.0,
              right: 16.0,
              bottom: 10.0,
            ), // <-- Espacio alrededor de la card
            elevation: 1, // <-- Sombra
            shape: RoundedRectangleBorder(
              // <-- Borde redondeado
              borderRadius: BorderRadius.circular(10), // <-- Radio del borde
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 20.0,
              ), // <-- Espacio interno
              // <-- Eliminar Center y ajustar Column
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.stretch, // <-- Estirar hijos
                // mainAxisSize: MainAxisSize.min, // Ajustar tamaño de la columna al contenido
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment
                        .spaceEvenly, // Distribuir uniformemente
                    children: _deviceId
                        .toUpperCase()
                        .split('')
                        .map(
                          (char) => Container(
                            // <-- Contenedor para el fondo blanco y borde
                            width:
                                50, // Ancho del contenedor (ajusta según necesites)
                            height:
                                60, // Altura del contenedor (ajusta según necesites)
                            // color: Colors.white, // <-- Eliminar color directo
                            decoration: BoxDecoration(
                              // <-- Añadir decoración
                              color: Colors.white, // Color de fondo blanco
                              border: Border.all(
                                color: Colors.transparent,
                                width: 1.0,
                              ), // <-- Añadir borde
                              borderRadius: BorderRadius.circular(
                                5,
                              ), // Opcional: bordes redondeados para el rectángulo
                              boxShadow: [
                                // Aquí se define la sombra
                                BoxShadow(
                                  color: Colors.grey.withOpacity(
                                    0.3,
                                  ), // Color de la sombra con opacidad
                                  spreadRadius:
                                      1, // Cuánto se extiende la sombra en todas las direcciones
                                  blurRadius:
                                      5, // Qué tan difuminada es la sombra
                                  offset: const Offset(
                                    0,
                                    3,
                                  ), // Desplazamiento de la sombra (eje X, eje Y)
                                ),
                              ],
                            ),
                            alignment: Alignment
                                .center, // Centrar el contenido (el texto) vertical y horizontalmente
                            child: Padding(
                              // <-- Envuelve el Text con Padding
                              padding: const EdgeInsets.only(
                                bottom: 5.0,
                              ), // Ajusta este valor (5.0) según sea necesario
                              child: Text(
                                // <-- El texto del carácter
                                char,
                                style: const TextStyle(
                                  fontSize: 50,
                                  fontWeight: FontWeight.bold,
                                  color: Colors
                                      .black, // Color del texto para que contraste con el fondo blanco
                                  height:
                                      1.2, // <--- EXPERIMENT WITH THIS VALUE (e.g., 0.9, 1.0, 1.1, 1.2)
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  // -------------------------------------------------------------
                  const SizedBox(height: 10),
                  const Text(
                    'Ingresa este codigo para vincular dispositivos',
                    style: TextStyle(fontSize: 16),
                    textAlign: TextAlign.center, // <-- Centrar el texto
                  ),
                ],
              ),
            ),
          ),

          // Lista de notificaciones enviadas y guardadas en firebase, leidas y no leidas
          Card(
            margin: const EdgeInsets.only(
              left: 16.0,
              right: 16.0,
              bottom: 10.0,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 16.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 16.0, bottom: 8.0),
                    child: Text(
                      'Notificaciones Almacenadas',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    height: 200, // Altura fija para la lista
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _storedNotifications.isEmpty
                        ? const Center(
                            child: Text(
                              'No hay notificaciones almacenadas',
                              style: TextStyle(fontSize: 16),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : ListView.builder(
                            itemCount: _storedNotifications.length,
                            itemBuilder: (context, index) {
                              final notification = _storedNotifications[index];
                              return ListTile(
                                leading: Icon(
                                  notification.statusVisualizacion
                                      ? Icons.mark_email_read
                                      : Icons.mark_email_unread,
                                  color: notification.statusVisualizacion
                                      ? Colors.green
                                      : Colors.red,
                                ),
                                title: Text(
                                  notification.title.isNotEmpty
                                      ? notification.title
                                      : 'Sin título',
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      notification.text.isNotEmpty
                                          ? notification.text
                                          : 'Sin contenido',
                                    ),
                                    Text(
                                      'App: ${notification.appName.isNotEmpty ? notification.appName : notification.packageName}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                    Text(
                                      'Estado: ${notification.statusVisualizacion ? "Leído" : "No leído"}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: notification.statusVisualizacion
                                            ? Colors.green[700]
                                            : Colors.red[700],
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
            ),
          ),
        ],
      ),
      // Añade el Divider justo antes del BottomNavigationBar
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 3,
            color: customColor[700], // Barra divisora con customColor
          ),
          BottomNavigationBar(
            currentIndex: 1,
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
            selectedIconTheme: const IconThemeData(size: 37.5),
            unselectedIconTheme: const IconThemeData(size: 22.5),
            selectedItemColor:
                customColor[700], // Color para el ítem seleccionado
            unselectedItemColor:
                Colors.black, // Color para los ítems no seleccionados
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.settings),
                label: 'Configuración',
              ),
              BottomNavigationBarItem(icon: Icon(Icons.send), label: 'Emisor'),
              BottomNavigationBarItem(
                icon: Icon(Icons.apps),
                label: 'Aplicaciones',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> _checkInitialRoute(BuildContext context) async {
  try {
    final receptorService = ReceptorService();
    final deviceId = await receptorService.getLinkedDeviceId();
    final linkStatus = await FirebaseService().getLinkStatus();
    if (linkStatus) {
      Navigator.pushReplacementNamed(context, '/notificaciones');
      return;
    }
    final useAsReceptor = await PreferencesService.getUseAsReceptor();
    if (useAsReceptor) {
      Navigator.pushReplacementNamed(context, '/receptor');
    }
  } catch (e, stack) {
    print('Error al verificar ruta inicial: $e');
    print('Stacktrace: $stack');
  }
}
