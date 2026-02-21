import 'package:connect/theme_colors.dart';
import 'package:flutter/material.dart';
import 'package:connect/services/preferences_service.dart'; // ✅ AGREGAR IMPORT

class SettingsScreen extends StatefulWidget {
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
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoadingFirebase = false;
  bool _disableAutoRedirect = false; // ✅ NUEVA VARIABLE DE ESTADO
  bool _isLoadingAutoRedirect = false; // ✅ LOADING STATE
  bool _keepAppActive = false; // ✅ NUEVA VARIABLE PARA MANTENER APP ACTIVA
  bool _isLoadingKeepAppActive = false; // ✅ LOADING STATE PARA MANTENER APP ACTIVA

  // ✅ AGREGAR EN initState()
  @override
  void initState() {
    super.initState();
    _loadAutoRedirectPreference(); // Cargar la preferencia al inicializar
    _loadKeepAppActivePreference(); // Cargar la preferencia de mantener app activa
    _checkAndAutoStartServiceIfNeeded(); // Verificar y activar servicio si es necesario
  }

  // ✅ NUEVO MÉTODO PARA VERIFICAR Y ACTIVAR SERVICIO AUTOMÁTICAMENTE
  Future<void> _checkAndAutoStartServiceIfNeeded() async {
    try {
      // Esperar un poco para que se carguen las preferencias
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Verificar si está configurado como emisor, permisos concedidos pero servicio inactivo
      if (_disableAutoRedirect && widget.isPermissionGranted && !widget.isServiceRunning) {
        // print('SettingsScreen: Emisor detectado inactivo - Activando servicio automáticamente');
        widget.startService();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Servicio reactivado automáticamente para el emisor'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      // print('Error al verificar y activar servicio automáticamente: $e');
    }
  }

  // ✅ NUEVO MÉTODO PARA CARGAR LA PREFERENCIA
  Future<void> _loadAutoRedirectPreference() async {
    try {
      final disable = await PreferencesService.getDisableAutoRedirect();
      setState(() {
        _disableAutoRedirect = disable;
      });
    } catch (e) {
      // print('Error al cargar preferencia de redirección automática: $e');
    }
  }

  // ✅ NUEVO MÉTODO PARA CARGAR LA PREFERENCIA DE MANTENER APP ACTIVA
  Future<void> _loadKeepAppActivePreference() async {
    try {
      final keepActive = await PreferencesService.getKeepAppActive();
      setState(() {
        _keepAppActive = keepActive;
      });
    } catch (e) {
      // print('Error al cargar preferencia de mantener aplicación activa: $e');
    }
  }

  Future<void> _handleFirebaseToggle(bool value) async {
    setState(() {
      _isLoadingFirebase = true;
    });

    try {
      await widget.toggleSaveToFirebase(value);
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingFirebase = false;
        });
      }
    }
  }

  // ✅ NUEVO MÉTODO PARA MANEJAR EL TOGGLE DE REDIRECCIÓN AUTOMÁTICA
  Future<void> _handleAutoRedirectToggle(bool value) async {
    setState(() {
      _isLoadingAutoRedirect = true;
    });

    try {
      final success = await PreferencesService.saveDisableAutoRedirect(value);
      if (success) {
        setState(() {
          _disableAutoRedirect = value;
        });

        // ✅ NUEVA FUNCIONALIDAD: Si se configura como emisor (value = true),
        // verificar y activar automáticamente el servicio si es necesario
        if (value && widget.isPermissionGranted && !widget.isServiceRunning) {
          // print('Configurado como emisor - Activando servicio automáticamente');
          widget.startService();
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Servicio activado automáticamente para el emisor'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      }
    } catch (e) {
      // print('Error al cambiar preferencia de redirección automática: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al guardar la configuración'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAutoRedirect = false;
        });
      }
    }
  }

  // ✅ NUEVO MÉTODO PARA MANEJAR EL TOGGLE DE MANTENER APP ACTIVA
  Future<void> _handleKeepAppActiveToggle(bool value) async {
    setState(() {
      _isLoadingKeepAppActive = true;
    });

    try {
      final success = await PreferencesService.saveKeepAppActive(value);
      if (success) {
        setState(() {
          _keepAppActive = value;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                value 
                  ? 'Aplicación configurada para mantenerse activa'
                  : 'Aplicación ya no se mantendrá activa automáticamente'
              ),
              backgroundColor: value ? Colors.green : Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      // print('Error al cambiar preferencia de mantener aplicación activa: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al guardar la configuración'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingKeepAppActive = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
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
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
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
                              widget.isServiceRunning
                                  ? 'Corriendo'
                                  : 'Detenido',
                              style: TextStyle(
                                fontSize: 16,
                                color: widget.isServiceRunning
                                    ? Colors.green
                                    : Colors.red,
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
                              widget.isPermissionGranted
                                  ? 'Concedido'
                                  : 'No concedido',
                              style: TextStyle(
                                fontSize: 16,
                                color: widget.isPermissionGranted
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
                                  onPressed: widget.checkPermissionStatus,
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
                                  onPressed: widget.openNotificationSettings,
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
                                    backgroundColor: widget.isServiceRunning
                                        ? Colors.grey[400]
                                        : customColor[600], // Color ligeramente más claro
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: widget.isServiceRunning
                                      ? null
                                      : widget.startService,
                                  child: const Text('Iniciar Servicio'),
                                ),
                              ),
                              const SizedBox(width: 8), // Espacio entre botones
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: widget.isServiceRunning
                                        ? customColor[600]
                                        : Colors
                                              .grey[400], // Color ligeramente más claro
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: widget.isServiceRunning
                                      ? widget.stopService
                                      : null,
                                  child: const Text('Detener Servicio'),
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton.icon(
                            onPressed: () => Navigator.pushNamed(context, '/ble_devices'),
                            icon: const Icon(Icons.bluetooth),
                            label: const Text('Seleccionar dispositivo Bluetooth'),
                          ),
                        ),
                        ],
                      ),
                    ),
                  ),
                  Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
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
                            title: const Text(
                              'Guardar notificaciones en Firebase',
                            ),
                            subtitle: const Text(
                              'Las notificaciones se guardarán automáticamente en la base de datos',
                            ),
                            value: widget.isSavingToFirebase,
                            onChanged: _isLoadingFirebase
                                ? null
                                : _handleFirebaseToggle, // Deshabilitar durante carga
                            activeColor: Colors.green,
                            inactiveTrackColor: customColor[200],
                            inactiveThumbColor: Colors.grey[300],
                            contentPadding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Card Configuración de Vinculación
                  Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    elevation: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Configuración de Vinculación:',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_disableAutoRedirect ?
                                      'Configurardo como Emisor:' : 'Configurardo como Receptor:',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _disableAutoRedirect
                                          ? 'No serás redirigido al receptor cuando un dispositivo sea vinculado'
                                          : 'Serás redirigido al receptor cuando un dispositivo sea vinculado',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: _disableAutoRedirect
                                            ? Colors.green[700]
                                            : Colors.red[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _isLoadingAutoRedirect
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Switch(
                                      value: _disableAutoRedirect,
                                      onChanged: _handleAutoRedirectToggle,
                                      activeColor: Colors.green,
                                      inactiveTrackColor: customColor[200],
                                      inactiveThumbColor: Colors.grey[300],
                                    ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue[200]!),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.blue[700],
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                // Expanded(
                                  // child:
                                   Text(
                                    'Si la aplicacion en este dispositivo sera usada para enviar las notificaciones a otro dispositivo, debes activar esta opcion. Si no, te redirigira automaticamente a la pantalla vincular dispositivo cuando se cuando se conecte un dispositivo como receptor mediante el codigo.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.blue[700],
                                    ),
                                  ),
                                // ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ✅ NUEVO CARD PARA MANTENER APLICACIÓN ACTIVA
                  Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    elevation: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Configuración de Aplicación:',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Reproducción multimedia'),
                            subtitle: const Text(
                              'Selecciona la aplicación por defecto para iniciar reproducción desde widgets',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () =>
                                Navigator.pushNamed(context, '/media_reproduction'),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Mantener aplicación activa:',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _keepAppActive
                                          ? 'La aplicación se mantendrá activa y se iniciará automáticamente'
                                          : 'La aplicación puede cerrarse normalmente',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: _keepAppActive
                                            ? Colors.green[700]
                                            : Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _isLoadingKeepAppActive
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Switch(
                                      value: _keepAppActive,
                                      onChanged: _handleKeepAppActiveToggle,
                                      activeColor: Colors.green,
                                      inactiveTrackColor: customColor[200],
                                      inactiveThumbColor: Colors.grey[300],
                                    ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange[200]!),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.warning_amber_outlined,
                                  color: Colors.orange[700],
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Cuando esta opción esté activada, la aplicación se iniciará automáticamente al encender el dispositivo y se mantendrá activa en segundo plano. Esto puede afectar el rendimiento de la batería.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.orange[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
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
                onTap: _isLoadingFirebase
                    ? null
                    : (index) {
                        // Deshabilitar durante carga
                        switch (index) {
                          case 0:
                            break;
                          case 1:
                            Navigator.pushReplacementNamed(context, '/');
                            break;
                          case 2:
                            Navigator.pushReplacementNamed(
                              context,
                              '/app_list',
                            );
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
        // Modal de carga para Firebase
        if (_isLoadingFirebase)
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
                        'Configurando Firebase...',
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
}
