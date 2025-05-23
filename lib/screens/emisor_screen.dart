import 'dart:async';

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
  
  // Añadir un timer para actualizar periódicamente
  late final Stream _updateStream;
  late final StreamSubscription _updateSubscription;

  @override
  void initState() {
    super.initState();
    _filterNotifications();
    
    // Crear un stream que se ejecute cada 2 segundos para actualizar las notificaciones
    _updateStream = Stream.periodic(const Duration(seconds: 2));
    _updateSubscription = _updateStream.listen((_) {
      if (mounted) {
        _filterNotifications();
      }
    });
    
    // Registrar el observer para detectar cuando la app vuelve al primer plano
    WidgetsBinding.instance.addObserver(this);
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
        actions: [
          IconButton(
            icon: const Icon(Icons.apps),
            onPressed: () {
              Navigator.pushNamed(context, '/app_list').then((_) {
                // Actualizar el filtro cuando regrese de la pantalla de apps
                _filterNotifications();
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Contenedor de estado del servicio
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12.0),
            margin: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: widget.isServiceRunning ? Colors.green.shade100 : Colors.red.shade100,
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(
                color: widget.isServiceRunning ? Colors.green : Colors.red,
                width: 2.0,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.isServiceRunning ? Icons.check_circle : Icons.error,
                  color: widget.isServiceRunning ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8.0),
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 16.0,
                      color: Colors.black87,
                    ),
                    children: [
                      const TextSpan(text: 'El servicio está '),
                      TextSpan(
                        text: widget.isServiceRunning ? 'ACTIVO' : 'INACTIVO',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Título de notificaciones
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Notificaciones Recibidas:',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  ),
              ],
            ),
          ),
          
          // Lista de notificaciones filtradas
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
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
                            subtitle: Text(
                                '${notification['appName'] ?? notification['packageName'] ?? 'Desconocido'}\n${notification['text'] ?? 'Sin texto'}'),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}