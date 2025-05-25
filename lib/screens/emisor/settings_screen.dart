import 'package:connect/theme_colors.dart';
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
        backgroundColor: customColor[700],
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                elevation: 3,
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
                      Center(
                        child: Text(
                          isServiceRunning ? 'Corriendo' : 'Detenido',
                          style: TextStyle(
                            fontSize: 16,
                            color: isServiceRunning ? Colors.green : Colors.red,
                          ),
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
                      Center(
                        child: Text(
                          isPermissionGranted ? 'Concedido' : 'No concedido',
                          style: TextStyle(
                            fontSize: 16,
                            color: isPermissionGranted
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    customColor[600], // Color ligeramente más claro
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: checkPermissionStatus,
                              child: const Text('Verificar Permiso'),
                            ),
                          ),
                          const SizedBox(width: 8), // Espacio entre botones
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    customColor[600], // Color ligeramente más claro
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: openNotificationSettings,
                              child: const Text('Configuración'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isServiceRunning
                                    ? Colors.grey[400]
                                    : customColor[600], // Color ligeramente más claro
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: isServiceRunning ? null : startService,
                              child: const Text('Iniciar Servicio'),
                            ),
                          ),
                          const SizedBox(width: 8), // Espacio entre botones
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isServiceRunning
                                    ? customColor[600]
                                    : Colors
                                          .grey[400], // Color ligeramente más claro
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: isServiceRunning ? stopService : null,
                              child: const Text('Detener Servicio'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                elevation: 3,
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
                        inactiveTrackColor: customColor[200],
                        inactiveThumbColor: Colors.grey[300],
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ),
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Acerca de',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Esta aplicación permite monitorear las notificaciones recibidas en tu dispositivo.',
                        style: TextStyle(fontSize: 16),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Instrucciones:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
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
            ],
          ),
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(height: 3, color: customColor[700]),
          BottomNavigationBar(
            currentIndex: 0,
            onTap: (index) {
              switch (index) {
                case 0:
                  break;
                case 1:
                  Navigator.pushReplacementNamed(context, '/');
                  break;
                case 2:
                  Navigator.pushReplacementNamed(context, '/app_list');
                  break;
              }
            },
            selectedFontSize: 14.0,
            unselectedFontSize: 12.0,
            selectedIconTheme: const IconThemeData(size: 37.5),
            unselectedIconTheme: const IconThemeData(size: 22.5),
            selectedItemColor: customColor[700],
            unselectedItemColor: Colors.black,
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
