import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  final bool isServiceRunning;
  final bool isPermissionGranted;
  final bool isSavingToFirebase;
  final Function() checkPermissionStatus;
  final Function() openNotificationSettings;
  final Function() startService;
  final Function() stopService;
  final Function(bool) toggleSaveToFirebase;

  const SettingsScreen({
    super.key,
    required this.isServiceRunning,
    required this.isPermissionGranted,
    required this.isSavingToFirebase,
    required this.checkPermissionStatus,
    required this.openNotificationSettings,
    required this.startService,
    required this.stopService,
    required this.toggleSaveToFirebase,
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
              Card(
                margin: const EdgeInsets.only(bottom: 16.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Opciones de Firebase:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('Guardar notificaciones en Firebase'),
                        subtitle: const Text(
                          'Las notificaciones se guardarán automáticamente en la base de datos',
                        ),
                        value: isSavingToFirebase,
                        onChanged: toggleSaveToFirebase,
                        activeColor: Colors.green,
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
                '3. Las notificaciones recibidas aparecerán en la pantalla principal.\n'
                '4. Activa la opción de guardar en Firebase para mantener un historial.',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
      // Agregar el Bottom Navigation Bar
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0, // Índice actual (Configuración - ahora a la izquierda)
        onTap: (index) {
          // Navegar a la pantalla correspondiente según el índice
          switch (index) {
            case 0:
              // Ya estamos en la pantalla de configuración
              break;
            case 1:
              // Navegar a la pantalla Emisor
              Navigator.pushReplacementNamed(context, '/');
              break;
            case 2:
              // Navegar a la pantalla de lista de apps
              Navigator.pushReplacementNamed(context, '/app_list');
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