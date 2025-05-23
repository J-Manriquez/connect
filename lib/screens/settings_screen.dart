import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  final bool isServiceRunning;
  final bool isPermissionGranted;
  final Function() checkPermissionStatus;
  final Function() openNotificationSettings;
  final Function() startService;
  final Function() stopService;

  const SettingsScreen({
    super.key,
    required this.isServiceRunning,
    required this.isPermissionGranted,
    required this.checkPermissionStatus,
    required this.openNotificationSettings,
    required this.startService,
    required this.stopService,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                margin: const EdgeInsets.only(bottom: 16.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Estado del Servicio:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isServiceRunning ? 'Corriendo' : 'Detenido',
                        style: TextStyle(
                          fontSize: 16,
                          color: isServiceRunning ? Colors.green : Colors.red,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Permiso de Notificaciones:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isPermissionGranted ? 'Concedido' : 'No concedido',
                        style: TextStyle(
                          fontSize: 16,
                          color: isPermissionGranted ? Colors.green : Colors.red,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton(
                            onPressed: checkPermissionStatus,
                            child: const Text('Verificar Permiso'),
                          ),
                          ElevatedButton(
                            onPressed: openNotificationSettings,
                            child: const Text('Abrir Configuración'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton(
                            onPressed: isServiceRunning ? null : startService,
                            child: const Text('Iniciar Servicio'),
                          ),
                          ElevatedButton(
                            onPressed: isServiceRunning ? stopService : null,
                            child: const Text('Detener Servicio'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const Text(
                'Acerca de',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Esta aplicación permite monitorear las notificaciones recibidas en tu dispositivo.',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              const Text(
                'Instrucciones:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '1. Concede el permiso de acceso a notificaciones.\n'
                '2. Inicia el servicio de monitoreo.\n'
                '3. Las notificaciones recibidas aparecerán en la pantalla principal.',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}