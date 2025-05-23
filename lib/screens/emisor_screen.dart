import 'package:flutter/material.dart';

class EmisorScreen extends StatelessWidget {
  final List<Map<String, dynamic>> notifications;
  final bool isServiceRunning;

  const EmisorScreen({
    super.key, 
    required this.notifications,
    required this.isServiceRunning,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emisor de Notificaciones'),
        actions: [
          IconButton(
            icon: const Icon(Icons.apps),
            onPressed: () {
              Navigator.pushNamed(context, '/app_list');
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
              color: isServiceRunning ? Colors.green.shade100 : Colors.red.shade100,
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(
                color: isServiceRunning ? Colors.green : Colors.red,
                width: 2.0,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isServiceRunning ? Icons.check_circle : Icons.error,
                  color: isServiceRunning ? Colors.green : Colors.red,
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
                        text: isServiceRunning ? 'ACTIVO' : 'INACTIVO',
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
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Notificaciones Recibidas:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          // Lista de notificaciones
          Expanded(
            child: notifications.isEmpty
                ? const Center(
                    child: Text(
                      'No hay notificaciones recibidas',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final notification = notifications[index];
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