import 'dart:convert';
import 'package:connect/services/notification_filter_service.dart';
import 'package:connect/theme_colors.dart';
import 'package:flutter/cupertino.dart';
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
  List<Map<String, dynamic>> _systemApps = [];
  List<Map<String, dynamic>> _thirdPartyApps = [];
  List<Map<String, dynamic>> _filteredSystemApps = [];
  List<Map<String, dynamic>> _filteredThirdPartyApps = [];

  bool _isLoading = true;
  String _searchQuery = '';
  String? _error;
  String _lastUpdateDate = 'Desconocido';
  bool _showActiveApps = false; // To be replaced
  bool _showAddAppCard = true; // To be replaced

  // New state variables for card expansion
  bool _activeAppsCardExpanded = false;
  bool _addSystemAppCardExpanded = false;
  bool _isLoadingApps = true;

  // Variables para paginación
  // int _systemCurrentPage = 0;
  // int _thirdPartyCurrentPage = 0;
  // final int _itemsPerPage = 100; // Or whatever value it had, will be removed

  // Variables para la búsqueda de aplicaciones por paquete
  final TextEditingController _packageController = TextEditingController();
  bool _isSearchingApp = false;
  String? _searchAppError;
  Map<String, dynamic>? _foundApp;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadApps();
    });
    platform.setMethodCallHandler(_handleMethodCall);
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onAppListUpdated':
        await NotificationFilterService.syncEnabledAppsWithFirebase();
        break;
    }
  }

  @override
  void dispose() {
    _packageController.dispose();
    super.dispose();
  }

  Future<void> _loadApps() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final List<dynamic> apps = await platform.invokeMethod(
        'getInstalledApps',
      );
      final String lastUpdate = await platform.invokeMethod(
        'getLastUpdateDate',
      );

      setState(() {
        _apps = apps
            .map((app) => Map<String, dynamic>.from(app as Map))
            .toList();
        _lastUpdateDate = lastUpdate;
        _separateApps();
        _filterApps();
        _isLoading = false;
        _isLoadingApps = false;
      });
    } on PlatformException catch (e) {
      setState(() {
        _error = "Error al cargar aplicaciones: ${e.message}";
        _isLoading = false;
        _isLoadingApps = false;
      });
    }
  }

  Future<void> _reloadAppsFromSystem() async {
    setState(() {
      _isLoadingApps = true;
    });

    try {
      final List<dynamic> apps = await platform.invokeMethod(
        'loadAppsFromSystem',
      );
      final String lastUpdate = await platform.invokeMethod(
        'getLastUpdateDate',
      );

      setState(() {
        _apps = apps
            .map((app) => Map<String, dynamic>.from(app as Map))
            .toList();
        _lastUpdateDate = lastUpdate;
        _separateApps();
        _filterApps();
        _isLoadingApps = false;
      });

      await NotificationFilterService.syncEnabledAppsWithFirebase();
    } on PlatformException catch (e) {
      setState(() {
        _error = "Error al recargar aplicaciones: ${e.message}";
        _isLoadingApps = false;
      });
    }
  }

  void _separateApps() {
    _systemApps = _apps.where((app) => app['isSystemApp'] == true).toList();
    _thirdPartyApps = _apps.where((app) => app['isSystemApp'] != true).toList();

    // Ordenar alfabéticamente por nombre de aplicación
    _systemApps.sort((a, b) {
      final nameA = (a['appName'] as String? ?? '').toLowerCase();
      final nameB = (b['appName'] as String? ?? '').toLowerCase();
      return nameA.compareTo(nameB);
    });

    _thirdPartyApps.sort((a, b) {
      final nameA = (a['appName'] as String? ?? '').toLowerCase();
      final nameB = (b['appName'] as String? ?? '').toLowerCase();
      return nameA.compareTo(nameB);
    });
  }

  Future<void> _updateAppState(String packageName, bool isEnabled) async {
    try {
      await platform.invokeMethod('updateAppState', {
        'packageName': packageName,
        'isEnabled': isEnabled,
      });

      setState(() {
        for (var i = 0; i < _apps.length; i++) {
          if (_apps[i]['packageName'] == packageName) {
            _apps[i] = {..._apps[i], 'isEnabled': isEnabled};
            break;
          }
        }

        if (_foundApp != null && _foundApp!['packageName'] == packageName) {
          _foundApp = {..._foundApp!, 'isEnabled': isEnabled};
        }

        _separateApps();
        _filterApps();
      });

      await NotificationFilterService.syncEnabledAppsWithFirebase();
    } on PlatformException catch (e) {
      print("Error al actualizar estado de la aplicación: ${e.message}");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al actualizar estado: ${e.message}")),
      );
    }
  }

  void _filterApps() {
    setState(() {
      _filteredSystemApps = _systemApps.where((app) {
        final appName = app['appName'] as String? ?? '';
        final packageName = app['packageName'] as String? ?? '';
        return appName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            packageName.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();

      _filteredThirdPartyApps = _thirdPartyApps.where((app) {
        final appName = app['appName'] as String? ?? '';
        final packageName = app['packageName'] as String? ?? '';
        return appName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            packageName.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    });
  }

  Future<void> _searchAppByPackage(String packageName) async {
    if (packageName.isEmpty) {
      setState(() {
        _searchAppError = "Ingrese un nombre de paquete";
        _foundApp = null;
      });
      return;
    }

    setState(() {
      _isSearchingApp = true;
      _searchAppError = null;
      _foundApp = null;
    });

    try {
      final result = await platform.invokeMethod('searchAppByPackage', {
        'packageName': packageName,
      });

      setState(() {
        _isSearchingApp = false;
        if (result != null) {
          _foundApp = Map<String, dynamic>.from(result as Map);
          _searchAppError = null;
          _loadApps();
        } else {
          _foundApp = null;
          _searchAppError = "Aplicación no encontrada";
        }
      });
    } on PlatformException catch (e) {
      setState(() {
        _isSearchingApp = false;
        _foundApp = null;
        _searchAppError = "Error: ${e.message}";
      });
    } catch (e) {
      setState(() {
        _isSearchingApp = false;
        _foundApp = null;
        _searchAppError = "Error inesperado: $e";
      });
    }
  }

  Widget _buildAppListTile(Map<String, dynamic> app) {
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
        inactiveTrackColor: customColor[200],
        inactiveThumbColor: Colors.grey[300],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final enabledAppsCount = _apps
        .where((app) => app['isEnabled'] == true)
        .length;
    final activeApps = _apps.where((app) => app['isEnabled'] == true).toList();

    // Determine if any card is expanded to adjust layout
    final bool isAnyCardExpanded =
        _activeAppsCardExpanded || _addSystemAppCardExpanded;

    Widget activeAppsCard = Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),

      // padding: const EdgeInsets.only(left:0),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _activeAppsCardExpanded = !_activeAppsCardExpanded;
            if (_activeAppsCardExpanded) {
              _addSystemAppCardExpanded = false; // Collapse other card
            }
          });
        },
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: _activeAppsCardExpanded
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                if (_activeAppsCardExpanded) const SizedBox(width: 18),
                Text(
                  'Apps Activas',
                  style: TextStyle(
                    fontSize: _activeAppsCardExpanded ? 20 : 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  constraints: BoxConstraints(maxWidth: 15),
                  icon: Icon(
                    _activeAppsCardExpanded
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() {
                      _activeAppsCardExpanded = !_activeAppsCardExpanded;
                      if (_activeAppsCardExpanded) {
                        _addSystemAppCardExpanded =
                            false; // Collapse other card
                      }
                    });
                  },
                ),
              ],
            ),
            if (_activeAppsCardExpanded ||
                !_addSystemAppCardExpanded) // Show content if expanded or if the other card is not expanded (default view)
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return SizeTransition(sizeFactor: animation, child: child);
                },
                child: _activeAppsCardExpanded
                    ? Column(
                        children: activeApps.map((app) {
                          final packageName =
                              app['packageName'] as String? ?? '';
                          final appName =
                              app['appName'] as String? ?? 'Sin nombre';
                          return ListTile(
                            leading: _buildAppIcon(app['icon'] as String?),
                            title: Text(appName),
                            subtitle: Text(packageName),
                            trailing: Switch(
                              value: true,
                              onChanged: (value) {
                                _updateAppState(packageName, value);
                              },
                              inactiveTrackColor: customColor[200],
                              inactiveThumbColor: Colors.grey[300],
                            ),
                          );
                        }).toList(),
                      )
                    : const SizedBox.shrink(), // Hidden when not expanded
              ),
          ],
        ),
      ),
    );

    Widget addSystemAppCard = Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _addSystemAppCardExpanded = !_addSystemAppCardExpanded;
            if (_addSystemAppCardExpanded) {
              _activeAppsCardExpanded = false; // Collapse other card
            }
          });
        },
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: _addSystemAppCardExpanded
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                if (_addSystemAppCardExpanded) const SizedBox(width: 18),
                Text(
                  'Apps del Sistema',
                  style: TextStyle(
                    fontSize: _addSystemAppCardExpanded ? 20 : 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  constraints: BoxConstraints(maxWidth: 30),
                  icon: Icon(
                    _addSystemAppCardExpanded
                        ? Icons.visibility_off
                        : Icons.add_circle,
                  ),
                  onPressed: () {
                    setState(() {
                      _addSystemAppCardExpanded = !_addSystemAppCardExpanded;
                      if (_addSystemAppCardExpanded) {
                        _activeAppsCardExpanded = false; // Collapse other card
                      }
                    });
                  },
                ),
              ],
            ),
            if (_addSystemAppCardExpanded ||
                !_activeAppsCardExpanded) // Show content if expanded or if the other card is not expanded (default view)
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return SizeTransition(sizeFactor: animation, child: child);
                },
                child: _addSystemAppCardExpanded
                    ? Padding(
                        padding: const EdgeInsets.only(
                          left: 8.0,
                          right: 8.0,
                          bottom: 8.0,
                          top: 8.0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Si la app que buscas no esta en la lista, ingresa el nombre del paquete de la aplicacion, busca en los resultados y activala.',
                              textAlign: TextAlign.justify,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                // fontStyle: FontStyle.italic,
                              ),
                            ),

                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _packageController,
                                    decoration: const InputDecoration(
                                      labelText: 'com.ejemplo.aplicacion',
                                      hintText: 'com.ejemplo.aplicacion',
                                      border: OutlineInputBorder(),
                                      enabledBorder: OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: Colors.black,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Container(
                                  padding: const EdgeInsets.all(0),
                                  child: Material(
                                    // Wrap with Material
                                    borderRadius: BorderRadius.circular(
                                      5.0,
                                    ), // Apply border radius here
                                    color:
                                        customColor[600], // Optional: Set background color
                                    child: InkWell(
                                      // Use InkWell for splash effect
                                      borderRadius: BorderRadius.circular(
                                        5.0,
                                      ), // Match InkWell's radius
                                      onTap: _isSearchingApp
                                          ? null
                                          : () => _searchAppByPackage(
                                              _packageController.text.trim(),
                                            ),
                                      child: Container(
                                        // Wrap with Container to control size and make it square
                                        width: 55.0, // Set a fixed width
                                        height:
                                            55.0, // Set a fixed height to make it square
                                        alignment: Alignment.center,
                                        child: _isSearchingApp
                                            ? const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                            : const Icon(
                                                Icons.search,
                                                size: 40,
                                                color: Colors.white,
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            if (_searchAppError != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  _searchAppError!,
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ),
                            const SizedBox(height: 8),
                            // const Text(
                            //   'Ejemplo: com.android.vending (Play Store)',
                            //   style: TextStyle(
                            //     fontSize: 12,
                            //     fontStyle: FontStyle.italic,
                            //   ),
                            // ),
                            if (_foundApp != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Card(
                                  color: Colors.green[50],
                                  child: ListTile(
                                    leading: _buildAppIcon(
                                      _foundApp!['icon'] as String?,
                                    ),
                                    title: Text(
                                      _foundApp!['appName'] as String? ??
                                          'Sin nombre',
                                    ),
                                    subtitle: Text(
                                      _foundApp!['packageName'] as String? ??
                                          '',
                                    ),
                                    trailing: Switch(
                                      value:
                                          _foundApp!['isEnabled'] as bool? ??
                                          false,
                                      onChanged: (value) {
                                        _updateAppState(
                                          _foundApp!['packageName'] as String,
                                          value,
                                        );
                                      },
                                      inactiveTrackColor: customColor[200],
                                      inactiveThumbColor: Colors.grey[300],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(), // Hidden when not expanded
              ),
          ],
        ),
      ),
    );

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('Lista de Aplicaciones'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _isLoadingApps ? null : _reloadAppsFromSystem,
              ),
            ],
          ),
          body: Column(
            children: [
              // Row for cards
              if (!isAnyCardExpanded) // Show side-by-side if neither is expanded
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: activeAppsCard),
                    Expanded(child: addSystemAppCard),
                  ],
                )
              else if (_activeAppsCardExpanded) // Show active apps card expanded
                activeAppsCard // This will take full width or as defined by its parent Column
              else if (_addSystemAppCardExpanded) // Show add system app card expanded
                addSystemAppCard, // This will take full width or as defined by its parent Column
              // Información de última actualización

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

              // Lista de aplicaciones expandida
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                    ? Center(child: Text(_error!))
                    : DefaultTabController(
                        length: 2,
                        child: Column(
                          children: [
                            TabBar(
                              labelColor: customColor[700],
                              unselectedLabelColor: Colors.grey,
                              indicatorColor: customColor[700],
                              tabs: [
                                Tab(
                                  text:
                                      'Sistema (${_filteredSystemApps.length})',
                                  icon: const Icon(
                                    Icons.app_settings_alt_sharp,
                                  ),
                                ),
                                Tab(
                                  text:
                                      'Terceros (${_filteredThirdPartyApps.length})',
                                  icon: const Icon(Icons.app_shortcut),
                                ),
                              ],
                            ),
                            Expanded(
                              child: TabBarView(
                                children: [
                                  // Tab de aplicaciones del sistema
                                  _filteredSystemApps.isEmpty
                                      ? const Center(
                                          child: Text(
                                            'No se encontraron aplicaciones del sistema',
                                          ),
                                        )
                                      : ListView.builder(
                                          itemCount: _filteredSystemApps.length,
                                          itemBuilder: (context, index) {
                                            return _buildAppListTile(
                                              _filteredSystemApps[index],
                                            );
                                          },
                                        ),
                                  // Tab de aplicaciones de terceros
                                  _filteredThirdPartyApps.isEmpty
                                      ? const Center(
                                          child: Text(
                                            'No se encontraron aplicaciones de terceros',
                                          ),
                                        )
                                      : ListView.builder(
                                          itemCount: _filteredThirdPartyApps.length,
                                          itemBuilder: (context, index) {
                                            return _buildAppListTile(
                                              _filteredThirdPartyApps[index],
                                            );
                                          },
                                        ),
                                 
                                ],
                              ),
                            ),
                          ],
                        ),
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
                      'Sistema: ${_filteredSystemApps.length} | Terceros: ${_filteredThirdPartyApps.length} | Total: ${_apps.length}',
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
            ],
          ),

          bottomNavigationBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(height: 3, color: customColor[700]),
              BottomNavigationBar(
                currentIndex: 2,
                onTap: _isLoadingApps
                    ? null
                    : (index) {
                        switch (index) {
                          case 0:
                            Navigator.pushReplacementNamed(
                              context,
                              '/settings',
                            );
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
                  BottomNavigationBarItem(
                    icon: Icon(Icons.send),
                    label: 'Emisor',
                  ),
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
                        style: TextStyle(fontSize: 14, color: Colors.grey),
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
        width: 30,
        height: 30,
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
