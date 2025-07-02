import 'package:connect/services/firebase_service.dart';
import 'package:connect/services/notification_listener_service.dart';
import 'package:connect/theme_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:connect/services/local_notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connect/services/receptor_service.dart';
import 'package:connect/services/preferences_service.dart';
import 'package:connect/screens/debug_logs_screen.dart';

class ReceptorSettingsScreen extends StatefulWidget {
  const ReceptorSettingsScreen({Key? key}) : super(key: key);

  @override
  State<ReceptorSettingsScreen> createState() => _ReceptorSettingsScreenState();
}

class _ReceptorSettingsScreenState extends State<ReceptorSettingsScreen>
    with WidgetsBindingObserver {
  bool _notificationsEnabled = false;
  // ✅ SEPARAR EN DOS VARIABLES
  bool _screenWakeEnabled = false;
  bool _autoOpenEnabled = false;
  bool _isLoading = true;

  // ✅ SOLUCIÓN: Añadir referencia al servicio
  final NotificationListenerService _notificationService =
      NotificationListenerService.instance;

  final ReceptorService _receptorService = ReceptorService();

  @override
  Future<void> initState() async {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // ✅ Añadir observer
    _loadSettings();
    _ensureNotificationServiceActive(); // ✅ Asegurar que el servicio esté activo
    
    // ✅ VERIFICACIÓN ADICIONAL: Confirmar sincronización al inicializar
    // await _reloadAutoOpenState();
    
    print('🏁 INICIALIZACIÓN COMPLETA: autoOpenEnabled = $_autoOpenEnabled');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // ✅ Remover observer
    super.dispose();
  }

  // ✅ SOLUCIÓN: Detectar cuando la app vuelve al primer plano
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _ensureNotificationServiceActive();
    }
  }

  // ✅ SOLUCIÓN: Método para asegurar que el servicio esté activo
  Future<void> _ensureNotificationServiceActive() async {
    try {
      final notificationsEnabled =
          await LocalNotificationService.areNotificationsEnabled();

      if (notificationsEnabled && !_notificationService.isListening) {
        print('ReceptorSettingsScreen: Reactivando servicio de notificaciones');
        await _notificationService.setListeningEnabled(true);
      }
    } catch (e) {
      print('ReceptorSettingsScreen: Error al reactivar servicio: $e');
    }
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final notificationsEnabled = await LocalNotificationService.areNotificationsEnabled();
      final screenWakeEnabled = await LocalNotificationService.isScreenWakeEnabled();
      final autoOpenEnabled = await LocalNotificationService.isAutoOpenEnabled();

      setState(() {
        _notificationsEnabled = notificationsEnabled;
        _screenWakeEnabled = screenWakeEnabled;
        _autoOpenEnabled = autoOpenEnabled;
        _isLoading = false;
      });

      print('✅ CONFIGURACIÓN CARGADA:');
      print('- Notificaciones: $notificationsEnabled');
      print('- Screen Wake: $screenWakeEnabled');
      print('- Auto Open: $autoOpenEnabled (independiente)');
      
      // ✅ SINCRONIZAR CONFIGURACIÓN NATIVA AL CARGAR
      await LocalNotificationService.setScreenWakeEnabled(screenWakeEnabled);
      await LocalNotificationService.setAutoOpenEnabled(autoOpenEnabled);
      print('🎯 CONFIGURACIÓN NATIVA SINCRONIZADA AL INICIALIZAR');
      
      _ensureNotificationServiceActive();
    } catch (e) {
      print('❌ Error al cargar configuración: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // ✅ CAMBIO: Métodos independientes para los dos switches
  void _toggleScreenWake(bool? value) async {
    if (value == null) return;
    
    print('🔄 INICIANDO _toggleScreenWake: $value');
    
    // ✅ 1. Actualizar UI inmediatamente
    setState(() {
      _screenWakeEnabled = value;
    });
    print('✅ UI actualizada inmediatamente: $_screenWakeEnabled');
    
    try {
      // ✅ 2. Guardar en SharedPreferences Y ACTUALIZAR CONFIGURACIÓN NATIVA EN TIEMPO REAL
      await LocalNotificationService.setScreenWakeEnabled(value);
      print('✅ setScreenWakeEnabled($value) ejecutado - Configuración nativa actualizada automáticamente');
      
      print('🎉 SCREEN WAKE CONFIGURADO EN TIEMPO REAL: $value');
      
    } catch (e) {
      print('❌ ERROR en _toggleScreenWake: $e');
      // Revertir UI en caso de error
      setState(() {
        _screenWakeEnabled = !value;
      });
    }
  }

  void _toggleAutoOpen(bool? value) async {
    if (value == null) return;
    
    print('🔄 INICIANDO _toggleAutoOpen: $value');
    
    // ✅ 1. Actualizar UI inmediatamente
    setState(() {
      _autoOpenEnabled = value;
    });
    print('✅ UI actualizada inmediatamente: $_autoOpenEnabled');
    
    try {
      // ✅ 2. Guardar en SharedPreferences Y ACTUALIZAR CONFIGURACIÓN NATIVA EN TIEMPO REAL
      await LocalNotificationService.setAutoOpenEnabled(value);
      print('✅ setAutoOpenEnabled($value) ejecutado - Configuración nativa actualizada automáticamente');
      
      // ✅ 3. Verificar que se guardó correctamente
      final savedValue = await LocalNotificationService.isAutoOpenEnabled();
      print('✅ VERIFICACIÓN: Valor guardado en SharedPreferences: $savedValue');
      
      if (savedValue != value) {
        print('❌ ERROR: El valor no se guardó correctamente');
        // Revertir UI en caso de error
        setState(() {
          _autoOpenEnabled = !value;
        });
        return;
      }
      
      print('🎉 AUTO-OPEN CONFIGURADO EN TIEMPO REAL: $value');
      
      // ✅ SOLUCIÓN: Reinicio forzado SOLO cuando se DESACTIVA autoOpenEnabled
      if (!value) {
        print('🔄 AUTO-OPEN DESACTIVADO: Iniciando reinicio forzado de la aplicación');
        _showRestartDialog();
      }
      
    } catch (e) {
      print('❌ ERROR en _toggleAutoOpen: $e');
      // Revertir UI en caso de error
      setState(() {
        _autoOpenEnabled = !value;
      });
    }
  }
  


  // ✅ SOLUCIÓN: Mostrar diálogo de reinicio cuando se desactiva autoOpenEnabled
  void _showRestartDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // No se puede cerrar tocando fuera
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Reinicio Requerido',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Para aplicar correctamente la desactivación del auto-open, '
            'es necesario reiniciar la aplicación.\n\n'
            '¿Deseas reiniciar ahora?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                print('🚫 Usuario canceló el reinicio');
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _forceAppRestart();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Reiniciar'),
            ),
          ],
        );
      },
    );
  }

  // ✅ SOLUCIÓN: Método para forzar el reinicio de la aplicación
  Future<void> _forceAppRestart() async {
    try {
      print('🔄 INICIANDO REINICIO FORZADO DE LA APLICACIÓN');
      
      // Mostrar indicador de carga
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const AlertDialog(
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text('Reiniciando aplicación...'),
              ],
            ),
          );
        },
      );
      
      // Esperar un momento para que se muestre el diálogo
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Usar SystemNavigator para cerrar la aplicación
      // En Android, esto cerrará la app y el usuario tendrá que abrirla manualmente
      await SystemNavigator.pop();
      
      print('✅ APLICACIÓN CERRADA - El usuario debe abrirla manualmente');
      
    } catch (e) {
      print('❌ ERROR durante el reinicio forzado: $e');
      
      // Cerrar diálogo de carga si hay error
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      
      // Mostrar mensaje de error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al reiniciar: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // Desvincular dispositivo
  Future<void> _unlinkDevice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceId = await _receptorService.getLinkedDeviceId();
      await prefs.remove(ReceptorService.KEY_LINKED_DEVICE_ID);

      if (deviceId != null) {
        final firebaseservice = FirebaseService();
        await firebaseservice.updateLinkStatus(false, deviceId);
      }

      await PreferencesService.saveUseAsReceptor(false);
      await LocalNotificationService.setNotificationsEnabled(false);
      await NotificationListenerService.instance.setListeningEnabled(false);

      setState(() {
        _notificationsEnabled = false;
      });

      Navigator.pushReplacementNamed(context, '/');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dispositivo desvinculado correctamente'),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      print('Error al desvincular dispositivo: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al desvincular dispositivo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración Receptor')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(5.0),
              children: [
                // Opciones de Dispositivo
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(15.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Opciones de Dispositivo',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          margin: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 8,
                          ),
                          child: ElevatedButton.icon(
                            onPressed: _unlinkDevice,
                            icon: const Icon(Icons.link_off),
                            label: const Text(
                              'Desvincular Dispositivo',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: customColor[400],
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Configuración de Notificaciones
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 8,
                          ),
                          child: Text(
                            'Configuración de Notificaciones',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        // ✅ PRIMER SWITCH: ACTIVAR PANTALLA
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(left: 15),
                                  child: Text(
                                    'Activar pantalla',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.only(left: 15),
                                  child: Text(
                                    'Enciende la pantalla cuando \nllega una notificación',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Switch(
                              value: _screenWakeEnabled,
                              onChanged: _toggleScreenWake,
                              activeColor: Colors.green,
                              inactiveTrackColor: customColor[200],
                              inactiveThumbColor: Colors.grey[300],
                            ),
                          ],
                        ),
                        // ✅ CAMBIO: SEGUNDO SWITCH: AUTO-APERTURA (AHORA INDEPENDIENTE)
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(left: 15),
                                  child: Text(
                                    'Abrir aplicación automáticamente',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.only(left: 15),
                                  child: Text(
                                    'Abre la aplicación automáticamente \ncuando llega una notificación\n(funciona independientemente)',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Switch(
                              value: _autoOpenEnabled,
                              onChanged: _toggleAutoOpen,
                              activeColor: Colors.green,
                              inactiveTrackColor: customColor[200],
                              inactiveThumbColor: Colors.grey[300],
                            ),
                          ],
                        ),
                        const Divider(),
                        // Botón para configuraciones avanzadas
                        ListTile(
                          title: const Text(
                            'Configuraciones Avanzadas',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: const Text(
                            'Sonido, vibración y más opciones',
                            style: TextStyle(
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios),
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              '/notification_settings',
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Card de Debug Logs para Android 8.0
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 8,
                          ),
                          child: const Text(
                            'Debugging Android 8.0',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.orange[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.bug_report,
                              color: Colors.orange[700],
                              size: 24,
                            ),
                          ),
                          title: const Text(
                            'Logs de Debugging',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: const Text(
                            'Ver logs en tiempo real de notificaciones\ny configuración para Android 8.0',
                            style: TextStyle(
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const DebugLogsScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
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
                  Navigator.pushReplacementNamed(context, '/notificaciones');
                  break;
                case 2:
                  Navigator.pushReplacementNamed(
                    context,
                    '/unread_notifications',
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
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.settings),
                label: 'Configuración',
              ),
              BottomNavigationBarItem(
                icon: Icon(
                  Icons.radio_button_checked,
                  color: _notificationsEnabled ? Colors.green : Colors.red,
                ),
                label: 'Notificaciones',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.mark_email_unread),
                label: 'No Leídas',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
