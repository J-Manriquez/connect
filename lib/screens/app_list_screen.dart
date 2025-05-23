import 'dart:convert';
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
  
  // Set para almacenar los paquetes habilitados
  final Set<String> _enabledPackages = {};

  @override
  void initState() {
    super.initState();
    _loadApps();
  }

  Future<void> _loadApps() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Obtener la lista de aplicaciones desde el código nativo
      final List<dynamic> result = await platform.invokeMethod('getInstalledApps');
      
      // Convertir correctamente cada elemento a Map<String, dynamic>
      final List<Map<String, dynamic>> apps = result.map((item) {
        // Convertir explícitamente cada elemento a Map<String, dynamic>
        final Map<String, dynamic> app = Map<String, dynamic>.from(item as Map);
        return app;
      }).toList();
      
      // Actualizar el estado con las aplicaciones cargadas
      setState(() {
        _apps = apps;
        _filterApps();
        _isLoading = false;
      });
    } on PlatformException catch (e) {
      setState(() {
        _error = "Error al cargar aplicaciones: ${e.message}";
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = "Error inesperado: $e";
        _isLoading = false;
      });
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lista de Aplicaciones'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadApps,
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de búsqueda
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Buscar aplicaciones',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  _filterApps();
                });
              },
            ),
          ),
          
          // Opción para mostrar aplicaciones del sistema
          SwitchListTile(
            title: const Text('Mostrar aplicaciones del sistema'),
            value: _showSystemApps,
            onChanged: (value) {
              setState(() {
                _showSystemApps = value;
                _filterApps();
              });
            },
          ),
          
          // Contador de aplicaciones
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Mostrando ${_filteredApps.length} de ${_apps.length} aplicaciones',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Habilitadas: ${_enabledPackages.length}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                ),
              ],
            ),
          ),
          
          // Lista de aplicaciones
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                    : _filteredApps.isEmpty
                        ? const Center(child: Text('No se encontraron aplicaciones'))
                        : ListView.builder(
                            itemCount: _filteredApps.length,
                            itemBuilder: (context, index) {
                              final app = _filteredApps[index];
                              final packageName = app['packageName'] as String? ?? '';
                              final isEnabled = _enabledPackages.contains(packageName);
                              
                              return ListTile(
                                leading: _buildAppIcon(app['icon'] as String?),
                                title: Text(app['appName'] as String? ?? 'Sin nombre'),
                                subtitle: Text(packageName),
                                trailing: Switch(
                                  value: isEnabled,
                                  onChanged: (value) {
                                    setState(() {
                                      if (value) {
                                        _enabledPackages.add(packageName);
                                      } else {
                                        _enabledPackages.remove(packageName);
                                      }
                                    });
                                  },
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
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