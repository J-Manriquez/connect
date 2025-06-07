import 'dart:convert';
import 'package:connect/services/notification_filter_service.dart';
import 'package:connect/theme_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppListScreen extends StatefulWidget {
  const AppListScreen({super.key});

  @override
  State<AppListScreen> createState() => _AppListScreenState();
}

class _AppListScreenState extends State<AppListScreen> {
  static const platform = MethodChannel('com.example.connect/app_list');

  List<Map<String, dynamic>> _apps = [];
  List<Map<String, dynamic>> _filteredApps = [];
  bool _isLoading = true;
  bool _showSystemApps = false;
  String _searchQuery = '';
  String? _error;
  String _lastUpdateDate = 'Desconocido';
  bool _showActiveApps = true;
  // Agregar esta variable para controlar el modal de carga
  bool _isLoadingApps = false;

  @override
  void initState() {
    super.initState();
    _loadApps();

    // Configurar listener para actualizaciones desde el código nativo
    platform.setMethodCallHandler(_handleMethodCall);
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onAppListUpdated':
        // Sincronizar con Firebase cuando se actualice la lista de apps
        await NotificationFilterService.syncEnabledAppsWithFirebase();
        break;
      default:
        print('Método desconocido: ${call.method}');
    }
  }

  @override
  void dispose() {
    // Limpiar el handler al destruir el widget
    platform.setMethodCallHandler(null);
    super.dispose();
  }

  Future<void> _loadApps() async {
    try {
      setState(() {
        _isLoading = true;
        _isLoadingApps = true; // Mostrar modal de carga
        _error = null;
      });

      // Obtener la lista de aplicaciones desde el código nativo
      final List<dynamic> result = await platform.invokeMethod(
        'getInstalledApps',
      );

      // Obtener la fecha de última actualización
      final String lastUpdateDate = await platform.invokeMethod(
        'getLastUpdateDate',
      );

      // Convertir correctamente cada elemento a Map<String, dynamic>
      final List<Map<String, dynamic>> apps = result.map((item) {
        final Map<String, dynamic> app = Map<String, dynamic>.from(item as Map);
        return app;
      }).toList();

      // Actualizar el estado con las aplicaciones cargadas
      setState(() {
        _apps = apps;
        _lastUpdateDate = lastUpdateDate;
        _filterApps();
        _isLoading = false;
        _isLoadingApps = false; // Ocultar modal de carga
      });
    } on PlatformException catch (e) {
      setState(() {
        _error = "Error al cargar aplicaciones: ${e.message}";
        _isLoading = false;
        _isLoadingApps = false; // Ocultar modal de carga
      });
    } catch (e) {
      setState(() {
        _error = "Error inesperado: $e";
        _isLoading = false;
        _isLoadingApps = false; // Ocultar modal de carga
      });
    }
  }

  Future<void> _reloadAppsFromSystem() async {
    try {
      setState(() {
        _isLoading = true;
        _isLoadingApps = true; // Mostrar modal de carga
        _error = null;
      });

      // Forzar la carga de aplicaciones desde el sistema
      final List<dynamic> result = await platform.invokeMethod(
        'loadAppsFromSystem',
      );

      // Obtener la fecha de última actualización
      final String lastUpdateDate = await platform.invokeMethod(
        'getLastUpdateDate',
      );

      // Convertir correctamente cada elemento a Map<String, dynamic>
      final List<Map<String, dynamic>> apps = result.map((item) {
        final Map<String, dynamic> app = Map<String, dynamic>.from(item as Map);
        return app;
      }).toList();

      // Actualizar el estado con las aplicaciones cargadas
      setState(() {
        _apps = apps;
        _lastUpdateDate = lastUpdateDate;
        _filterApps();
        _isLoading = false;
        _isLoadingApps = false; // Ocultar modal de carga
      });

      // Sincronizar con Firebase después de recargar las aplicaciones
      await NotificationFilterService.syncEnabledAppsWithFirebase();
    } on PlatformException catch (e) {
      setState(() {
        _error = "Error al recargar aplicaciones: ${e.message}";
        _isLoading = false;
        _isLoadingApps = false; // Ocultar modal de carga
      });
    } catch (e) {
      setState(() {
        _error = "Error inesperado: $e";
        _isLoading = false;
        _isLoadingApps = false; // Ocultar modal de carga
      });
    }
  }

  Future<void> _updateAppState(String packageName, bool isEnabled) async {
    try {
      // Llamar al método nativo para actualizar el estado
      await platform.invokeMethod('updateAppState', {
        'packageName': packageName,
        'isEnabled': isEnabled,
      });

      // Actualizar el estado local
      setState(() {
        for (var i = 0; i < _apps.length; i++) {
          if (_apps[i]['packageName'] == packageName) {
            _apps[i] = {..._apps[i], 'isEnabled': isEnabled};
            break;
          }
        }
        _filterApps();
      });

      // Sincronizar con Firebase después de actualizar el estado
      await NotificationFilterService.syncEnabledAppsWithFirebase();
    } on PlatformException catch (e) {
      print("Error al actualizar estado de la aplicación: ${e.message}");
      // Mostrar un snackbar con el error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al actualizar estado: ${e.message}")),
      );
    }
  }

  void _filterApps() {
    setState(() {
      _filteredApps = _apps.where((app) {
        // Filtrar por aplicaciones del sistema si es necesario
        if (!_showSystemApps && app['isSystemApp'] == true) {
          return false;
        }

        // Filtrar por búsqueda
        final appName = app['appName'] as String? ?? '';
        final packageName = app['packageName'] as String? ?? '';

        return appName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            packageName.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final enabledAppsCount = _apps
        .where((app) => app['isEnabled'] == true)
        .length;
    final activeApps = _apps.where((app) => app['isEnabled'] == true).toList();

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('Lista de Aplicaciones'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _isLoadingApps ? null : _reloadAppsFromSystem, // Deshabilitar durante carga
              ),
            ],
          ),
          body: Column(
            children: [
              // Opción para mostrar aplicaciones del sistema
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Column(
                  children: [
                    ListTile(
                      leading: IconButton(
                        icon: Icon(
                          _showActiveApps ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _showActiveApps = !_showActiveApps;
                          });
                        },
                      ),
                      title: const Text('Aplicaciones Activas'),
                    ),
                    if (_showActiveApps)
                      Column(
                        children: activeApps.map((app) {
                          final packageName = app['packageName'] as String? ?? '';
                          final appName = app['appName'] as String? ?? 'Sin nombre';
                          return ListTile(
                            leading: _buildAppIcon(app['icon'] as String?),
                            title: Text(appName),
                            subtitle: Text(packageName),
                            trailing: Switch(
                              value: true,
                              onChanged: (value) {
                                _updateAppState(
                                  packageName,
                                  false,
                                ); // Deactivate app
                              },
                              activeColor: Colors.green,
                              inactiveTrackColor: customColor[200],
                              inactiveThumbColor: Colors.grey[300],
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),

              // Información de última actualización
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'Última actualización: $_lastUpdateDate',
                  style: const TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey,
                  ),
                ),
              ),

              // Barra de búsqueda
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Buscar aplicaciones',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.black),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                      _filterApps();
                    });
                  },
                ),
              ),

              // Contador de aplicaciones
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Mostrando ${_filteredApps.length} de ${_apps.length} aplicaciones',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Habilitadas: $enabledAppsCount',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color.fromARGB(255, 0, 0, 0),
                      ),
                    ),
                  ],
                ),
              ),

              // Lista de aplicaciones
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                    ? Center(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      )
                    : _filteredApps.isEmpty
                    ? const Center(child: Text('No se encontraron aplicaciones'))
                    : ListView.builder(
                        itemCount: _filteredApps.length,
                        itemBuilder: (context, index) {
                          final app = _filteredApps[index];
                          final packageName = app['packageName'] as String? ?? '';
                          final isEnabled = app['isEnabled'] as bool? ?? false;

                          return ListTile(
                            leading: _buildAppIcon(app['icon'] as String?),
                            title: Text(app['appName'] as String? ?? 'Sin nombre'),
                            subtitle: Text(packageName),
                            trailing: Switch(
                              value: isEnabled,
                              onChanged: (value) {
                                _updateAppState(packageName, value);
                              },
                              inactiveTrackColor:
                                  customColor[200], // <-- add this line
                              inactiveThumbColor: Colors.grey[300], // <-- optional
                            ),
                          );
                        },
                      ),
              ),

              // Card for active apps
            ],
          ),
          bottomNavigationBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 3,
                color: customColor[700],
              ),
              BottomNavigationBar(
                currentIndex: 2,
                onTap: _isLoadingApps ? null : (index) { // Deshabilitar durante carga
                  switch (index) {
                    case 0:
                      Navigator.pushReplacementNamed(context, '/settings');
                      break;
                    case 1:
                      Navigator.pushReplacementNamed(context, '/');
                      break;
                    case 2:
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
        ),
        // Modal de carga
        if (_isLoadingApps)
          Container(
            color: Colors.black54,
            child: const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        'Cargando aplicaciones...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Por favor espere',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAppIcon(String? base64Icon) {
    if (base64Icon == null || base64Icon.isEmpty) {
      return const Icon(Icons.android);
    }

    try {
      // Limpiar la cadena Base64 eliminando saltos de línea y espacios
      final cleanBase64 = base64Icon.replaceAll(RegExp(r'\s+'), '');

      final bytes = base64Decode(cleanBase64);
      return Image.memory(
        bytes,
        width: 40,
        height: 40,
        errorBuilder: (context, error, stackTrace) {
          // Si hay un error al cargar la imagen, mostrar un icono genérico
          return const Icon(Icons.android);
        },
      );
    } catch (e) {
      // Si hay un error al decodificar, mostrar un icono genérico
      return const Icon(Icons.android);
    }
  }
}

// Función para decodificar Base64
Uint8List base64Decode(String str) {
  try {
    return base64.decode(str);
  } catch (e) {
    // En caso de error, devolver un array vacío
    return Uint8List(0);
  }
}
