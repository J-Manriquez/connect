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
  Map<String, List<NotificationData>> _groupedNotifications =
      {}; // Notificaciones agrupadas por día
  Map<String, bool> _expandedDays = {}; // Control de expansión para cada día
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

      // Agrupar notificaciones por día
      final Map<String, List<NotificationData>> grouped = {};

      for (var notification in notifications) {
        // Obtener la fecha en formato YYYY-MM-DD
        final DateTime date = notification.timestamp;
        final String dateKey =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

        if (!grouped.containsKey(dateKey)) {
          grouped[dateKey] = [];
          // Inicializar el estado de expansión si no existe
          if (!_expandedDays.containsKey(dateKey)) {
            _expandedDays[dateKey] = true; // Por defecto expandido
          }
        }

        grouped[dateKey]!.add(notification);
      }

      setState(() {
        _groupedNotifications = grouped;
        _isLoading = false;
      });

      // print('Notificaciones cargadas desde Firebase: ${notifications.length}');
    } catch (e) {
      print('Error al cargar notificaciones desde Firebase: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Método para marcar una notificación como leída
  Future<void> _markNotificationAsRead(NotificationData notification) async {
    try {
      // Solo proceder si la notificación no está ya marcada como leída
      if (!notification.statusVisualizacion) {
        // Obtener dateId del campo correcto
        final uniqueId = notification.id;
        // 2. Convertir el String de milisegundos a un entero
        final int millisecondsSinceEpoch = int.parse(uniqueId);
        print('Milisegundos (int): $millisecondsSinceEpoch');

        // 3. Crear un objeto DateTime a partir de los milisegundos
        final DateTime dateTimeObject = DateTime.fromMillisecondsSinceEpoch(
          millisecondsSinceEpoch,
        );
        print(
          'Objeto DateTime: $dateTimeObject',
        ); // Esto mostrará la fecha y la hora completas

        // 4. Formatear el objeto DateTime a "aaaa-mm-dd"
        // Para esto, nos aseguramos de que el mes y el día tengan dos dígitos (ej. 05 en lugar de 5)

        final String year = dateTimeObject.year.toString();
        final String month = dateTimeObject.month.toString().padLeft(
          2,
          '0',
        ); // Añade un 0 a la izquierda si es necesario
        final String day = dateTimeObject.day.toString().padLeft(
          2,
          '0',
        ); // Añade un 0 a la izquierda si es necesario

        final String dateId = '$year-$month-$day';

        await _firebaseService.updateNotificationVisualizationStatus(
          notification.id,
          dateId,
          true,
        );
        // Recargar notificaciones después de actualizar
        await _loadStoredNotifications();
      }
    } catch (e) {
      print('Error al marcar notificación como leída: $e');
    }
  }

  // Método para eliminar una notificación
  Future<void> _deleteNotification(NotificationData notification) async {
    try {
      final uniqueId = notification.id;
      // 2. Convertir el String de milisegundos a un entero
      final int millisecondsSinceEpoch = int.parse(uniqueId);
      print('Milisegundos (int): $millisecondsSinceEpoch');

      // 3. Crear un objeto DateTime a partir de los milisegundos
      final DateTime dateTimeObject = DateTime.fromMillisecondsSinceEpoch(
        millisecondsSinceEpoch,
      );
      print(
        'Objeto DateTime: $dateTimeObject',
      ); // Esto mostrará la fecha y la hora completas

      // 4. Formatear el objeto DateTime a "aaaa-mm-dd"
      // Para esto, nos aseguramos de que el mes y el día tengan dos dígitos (ej. 05 en lugar de 5)

      final String year = dateTimeObject.year.toString();
      final String month = dateTimeObject.month.toString().padLeft(
        2,
        '0',
      ); // Añade un 0 a la izquierda si es necesario
      final String day = dateTimeObject.day.toString().padLeft(
        2,
        '0',
      ); // Añade un 0 a la izquierda si es necesario

      final String dateId = '$year-$month-$day';

      await _firebaseService.deleteNotification(notification.id, dateId);
      // Recargar notificaciones después de eliminar
      await _loadStoredNotifications();
    } catch (e) {
      print('Error al eliminar notificación: $e');
    }
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
      body: SingleChildScrollView(
        child: Column(
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
                    // const Padding(
                    //   padding: EdgeInsets.only(left: 16.0, bottom: 8.0),
                    //   child: Text(
                    //     'Notificaciones Almacenadas',
                    //     style: TextStyle(
                    //       fontSize: 16,
                    //       fontWeight: FontWeight.bold,
                    //     ),
                    //   ),
                    // ),
                    Container(
                      height: 300, // Aumentar altura para mostrar más contenido
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _groupedNotifications.isEmpty
                          ? const Center(
                              child: Text(
                                'No hay notificaciones almacenadas',
                                style: TextStyle(fontSize: 16),
                                textAlign: TextAlign.center,
                              ),
                            )
                          : ListView.builder(
                              itemCount: _groupedNotifications.keys.length,
                              itemBuilder: (context, index) {
                                // Obtener la clave de fecha ordenada (más reciente primero)
                                final dateKeys =
                                    _groupedNotifications.keys.toList()
                                      ..sort((a, b) => b.compareTo(a));
                                final dateKey = dateKeys[index];
                                final notifications =
                                    _groupedNotifications[dateKey]!;

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Encabezado del día con botón para expandir/colapsar
                                    ListTile(
                                      title: Text(
                                        _formatDate(dateKey),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      trailing: IconButton(
                                        icon: Icon(
                                          _expandedDays[dateKey]!
                                              ? Icons.visibility
                                              : Icons.visibility_off,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _expandedDays[dateKey] =
                                                !_expandedDays[dateKey]!;
                                          });
                                        },
                                      ),
                                    ),
                                    // Lista de notificaciones del día (expandible)
                                    if (_expandedDays[dateKey]!)
                                      ...notifications.map((notification) {
                                        final dismissibleKey =
                                            UniqueKey(); // Usar UniqueKey para cada Dismissible
                                        return Dismissible(
                                          key:
                                              dismissibleKey, // Usar clave única en lugar de Key(notification.id)
                                          // Deslizar a la derecha (solo para no leídas)
                                          confirmDismiss: (direction) async {
                                            if (direction ==
                                                DismissDirection.endToStart) {
                                              // Eliminar (deslizar a la izquierda)
                                              await _deleteNotification(
                                                notification,
                                              );
                                              return true;
                                            } else if (direction ==
                                                DismissDirection.startToEnd) {
                                              // Marcar como leída (deslizar a la derecha)
                                              if (!notification
                                                  .statusVisualizacion) {
                                                await _markNotificationAsRead(
                                                  notification,
                                                );
                                                return true;
                                              }
                                              return false; // No permitir deslizar si ya está leída
                                            }
                                            return false;
                                          },
                                          // Fondo al deslizar a la izquierda (eliminar)
                                          background: Container(
                                            color: Colors.green,
                                            alignment: Alignment.centerLeft,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 20,
                                            ),
                                            child: const Icon(
                                              Icons.check_circle,
                                              color: Colors.white,
                                            ),
                                          ),
                                          // Fondo al deslizar a la derecha (marcar como leída)
                                          secondaryBackground: Container(
                                            color: Colors.red,
                                            alignment: Alignment.centerRight,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 20,
                                            ),
                                            child: const Icon(
                                              Icons.delete,
                                              color: Colors.white,
                                            ),
                                          ),
                                          child: ListTile(
                                            leading: Icon(
                                              notification.statusVisualizacion
                                                  ? Icons.mark_email_read
                                                  : Icons.mark_email_unread,
                                              color:
                                                  notification
                                                      .statusVisualizacion
                                                  ? Colors.green
                                                  : Colors.red,
                                            ),
                                            title: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    notification
                                                            .title
                                                            .isNotEmpty
                                                        ? notification.title
                                                        : 'Sin título',
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                Text(
                                                  _formatTime(
                                                    notification.timestamp,
                                                  ),
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            subtitle: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  notification.text.isNotEmpty
                                                      ? notification.text
                                                      : 'Sin contenido',
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
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
                                                    color:
                                                        notification
                                                            .statusVisualizacion
                                                        ? Colors.green[700]
                                                        : Colors.red[700],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    const Divider(),
                                  ],
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
