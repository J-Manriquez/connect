import 'package:connect/services/firebase_service.dart';
import 'package:connect/services/notification_listener_service.dart';
import 'package:connect/services/notification_cache_service.dart';
import 'package:connect/theme_colors.dart';
import 'package:flutter/material.dart';
import 'package:connect/services/local_notification_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connect/services/receptor_service.dart';
import 'package:connect/services/preferences_service.dart';
import 'package:connect/screens/receptor/vibration_patterns_screen.dart';
import 'package:connect/screens/receptor/custom_sound_selection_screen.dart';
import 'package:connect/services/vibration_pattern_service.dart';
import 'package:connect/screens/emisor/floating_ball_settings_screen.dart';
import 'package:connect/screens/emisor/media_reproduction_screen.dart';
import 'package:connect/screens/emisor/widgets_config_screen.dart';
import 'package:connect/screens/receptor/device_diagnostics_screen.dart';
import 'package:connect/services/floating_ball_service.dart';
import 'package:restart_app/restart_app.dart';
import 'package:flutter/services.dart';

/// Descriptor de un permiso mostrado en la pestaña "Permisos".
/// [check] devuelve si está concedido; [action] lo solicita o abre los ajustes.
class _PermItem {
  final String id;
  final IconData icon;
  final String title;
  final String subtitle;
  final Future<bool> Function() check;
  final Future<void> Function() action;
  final String actionLabel;

  const _PermItem({
    required this.id,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.check,
    required this.action,
    required this.actionLabel,
  });
}

class ReceptorSettingsScreen extends StatefulWidget {
  const ReceptorSettingsScreen({super.key});

  @override
  State<ReceptorSettingsScreen> createState() => _ReceptorSettingsScreenState();
}

class _ReceptorSettingsScreenState extends State<ReceptorSettingsScreen>
    with WidgetsBindingObserver {
  static const MethodChannel _emisorChannel =
      MethodChannel('com.example.connect/notifications');

  bool _notificationsEnabled = false;
  // ✅ SEPARAR EN DOS VARIABLES
  bool _screenWakeEnabled = false;
  bool _autoOpenEnabled = false;
  bool _vibrationEnabled = false;
  bool _soundEnabled = true; // ✅ NUEVA VARIABLE PARA SONIDO
  bool _showLocalNotificationsSubtitle = false;
  bool _isLoading = true;

  // Estado (concedido/no) de cada permiso de la pestaña "Permisos".
  Map<String, bool> _permStatus = {};

  // ✅ SOLUCIÓN: Añadir referencia al servicio
  final NotificationListenerService _notificationService =
      NotificationListenerService.instance;

  final ReceptorService _receptorService = ReceptorService();

  Future<void> _openNotificationListenerPermission() async {
    try {
      await _emisorChannel.invokeMethod('openNotificationSettings');
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // ✅ Añadir observer
    _initializeSettings(); // ✅ Mover lógica asíncrona a método separado
  }

  // ✅ Método separado para manejar la inicialización asíncrona
  Future<void> _initializeSettings() async {
    await _loadSettings();
    await _ensureNotificationServiceActive(); // ✅ Asegurar que el servicio esté activo
    await _loadPermissions();

    // ✅ VERIFICACIÓN ADICIONAL: Confirmar sincronización al inicializar
    // await _reloadAutoOpenState();

    // print('🏁 INICIALIZACIÓN COMPLETA: autoOpenEnabled = $_autoOpenEnabled');
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
      _loadPermissions();
    }
  }

  // ✅ SOLUCIÓN: Método para asegurar que el servicio esté activo
  Future<void> _ensureNotificationServiceActive() async {
    try {
      final notificationsEnabled =
          await LocalNotificationService.areNotificationsEnabled();

      if (notificationsEnabled && !_notificationService.isListening) {
        // print('ReceptorSettingsScreen: Reactivando servicio de notificaciones');
        await _notificationService.setListeningEnabled(true);
      }
    } catch (e) {
      // print('ReceptorSettingsScreen: Error al reactivar servicio: $e');
    }
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final notificationsEnabled =
          await LocalNotificationService.areNotificationsEnabled();
      final screenWakeEnabled =
          await LocalNotificationService.isScreenWakeEnabled();
      final autoOpenEnabled =
          await LocalNotificationService.isAutoOpenEnabled();
      final vibrationEnabled =
          await VibrationPatternService.isVibrationEnabled();
      final soundEnabled = await LocalNotificationService.isSoundEnabled(); // ✅ CARGAR CONFIGURACIÓN DE SONIDO

      setState(() {
        _notificationsEnabled = notificationsEnabled;
        _screenWakeEnabled = screenWakeEnabled;
        _autoOpenEnabled = autoOpenEnabled;
        _vibrationEnabled = vibrationEnabled;
        _soundEnabled = soundEnabled; // ✅ ASIGNAR VALOR DE SONIDO
        _isLoading = false;
      });

      // print('✅ CONFIGURACIÓN CARGADA:');
      // print('- Notificaciones: $notificationsEnabled');
      // print('- Screen Wake: $screenWakeEnabled');
      // print('- Auto Open: $autoOpenEnabled (independiente)');
      // print('- Vibración: $vibrationEnabled');
      // print('- Sonido: $soundEnabled'); // ✅ LOG PARA SONIDO

      // ✅ SINCRONIZAR CONFIGURACIÓN NATIVA AL CARGAR
      await LocalNotificationService.setScreenWakeEnabled(screenWakeEnabled);
      await LocalNotificationService.setAutoOpenEnabled(autoOpenEnabled);
      // print('🎯 CONFIGURACIÓN NATIVA SINCRONIZADA AL INICIALIZAR');

      _ensureNotificationServiceActive();
    } catch (e) {
      // print('❌ Error al cargar configuración: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // ✅ CAMBIO: Métodos independientes para los dos switches
  void _toggleScreenWake(bool? value) async {
    if (value == null) return;

    // print('🔄 INICIANDO _toggleScreenWake: $value');

    // ✅ 1. Actualizar UI inmediatamente
    setState(() {
      _screenWakeEnabled = value;
    });
    // print('✅ UI actualizada inmediatamente: $_screenWakeEnabled');

    try {
      // ✅ 2. Guardar en SharedPreferences Y ACTUALIZAR CONFIGURACIÓN NATIVA EN TIEMPO REAL
      await LocalNotificationService.setScreenWakeEnabled(value);
      // print(        '✅ setScreenWakeEnabled($value) ejecutado - Configuración nativa actualizada automáticamente',      );

      // print('🎉 SCREEN WAKE CONFIGURADO EN TIEMPO REAL: $value');
    } catch (e) {
      // print('❌ ERROR en _toggleScreenWake: $e');
      // Revertir UI en caso de error
      setState(() {
        _screenWakeEnabled = !value;
      });
    }
  }

  void _toggleAutoOpen(bool? value) async {
    if (value == null) return;

    // print('🔄 INICIANDO _toggleAutoOpen: $value');

    // ✅ 1. Actualizar UI inmediatamente
    setState(() {
      _autoOpenEnabled = value;
    });
    // print('✅ UI actualizada inmediatamente: $_autoOpenEnabled');

    try {
      // ✅ 2. Guardar en SharedPreferences Y ACTUALIZAR CONFIGURACIÓN NATIVA EN TIEMPO REAL
      await LocalNotificationService.setAutoOpenEnabled(value);
      // print('✅ setAutoOpenEnabled($value) ejecutado - Configuración nativa actualizada automáticamente',      );

      // ✅ 3. Verificar que se guardó correctamente
      final savedValue = await LocalNotificationService.isAutoOpenEnabled();
      // print('✅ VERIFICACIÓN: Valor guardado en SharedPreferences: $savedValue');

      if (savedValue != value) {
        // print('❌ ERROR: El valor no se guardó correctamente');
        // Revertir UI en caso de error
        setState(() {
          _autoOpenEnabled = !value;
        });
        return;
      }

      // print('🎉 AUTO-OPEN CONFIGURADO EN TIEMPO REAL: $value');

      // ✅ SOLUCIÓN: Reinicio forzado SOLO cuando se DESACTIVA autoOpenEnabled
      if (!value) {
        // print(          '🔄 AUTO-OPEN DESACTIVADO: Iniciando reinicio forzado de la aplicación',        );
        _forceAppRestart();
      }
    } catch (e) {
      // print('❌ ERROR en _toggleAutoOpen: $e');
      // Revertir UI en caso de error
      setState(() {
        _autoOpenEnabled = !value;
      });
    }
  }

  void _toggleVibration(bool? value) async {
    if (value == null) return;

    // print('🔄 INICIANDO _toggleVibration: $value');

    // ✅ 1. Actualizar UI inmediatamente
    setState(() {
      _vibrationEnabled = value;
    });
    // print('✅ UI actualizada inmediatamente: $_vibrationEnabled');

    try {
      // ✅ 2. Guardar en SharedPreferences
      await VibrationPatternService.setVibrationEnabled(value);
      // print('✅ setVibrationEnabled($value) ejecutado');

      // print('🎉 VIBRACIÓN CONFIGURADA: $value');
    } catch (e) {
      // print('❌ ERROR en _toggleVibration: $e');
      // Revertir UI en caso de error
      setState(() {
        _vibrationEnabled = !value;
      });
    }
  }

  // ✅ NUEVO MÉTODO PARA MANEJAR SONIDO
  void _toggleSound(bool? value) async {
    if (value == null) return;

    // print('🔄 INICIANDO _toggleSound: $value');

    // ✅ 1. Actualizar UI inmediatamente
    setState(() {
      _soundEnabled = value;
    });
    // print('✅ UI actualizada inmediatamente: $_soundEnabled');

    try {
      // ✅ 2. Guardar en SharedPreferences Y ACTUALIZAR CONFIGURACIÓN NATIVA EN TIEMPO REAL
      await LocalNotificationService.setSoundEnabled(value);
      // print('✅ setSoundEnabled($value) ejecutado - Configuración nativa actualizada automáticamente');

      // print('🎉 SONIDO CONFIGURADO EN TIEMPO REAL: $value');
    } catch (e) {
      // print('❌ ERROR en _toggleSound: $e');
      // Revertir UI en caso de error
      setState(() {
        _soundEnabled = !value;
      });
    }
  }

  // ✅ SOLUCIÓN: Método para forzar el reinicio de la aplicación
  Future<void> _forceAppRestart() async {
    try {
      // print('🔄 INICIANDO REINICIO FORZADO DE LA APLICACIÓN');

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
      // await SystemNavigator.pop();
      Restart.restartApp();
      // print('✅ APLICACIÓN CERRADA - El usuario debe abrirla manualmente');
    } catch (e) {
      // print('❌ ERROR durante el reinicio forzado: $e');

      // Cerrar diálogo de carga si hay error
      if (!mounted) return;
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
      await prefs.remove(ReceptorService.keyLinkedDeviceId);

      if (deviceId != null) {
        final firebaseservice = FirebaseService();
        await firebaseservice.updateLinkStatus(false, deviceId);
      }

      // Limpiar el estado del receptor para evitar mostrar notificaciones históricas
      _receptorService.clearReceptorState();
      
      // Limpiar caché de notificaciones
      await NotificationCacheService.cleanOldCache();

      await PreferencesService.saveUseAsReceptor(false);
      await LocalNotificationService.setNotificationsEnabled(false);
      await NotificationListenerService.instance.setListeningEnabled(false);

      if (!mounted) return;
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
      // print('Error al desvincular dispositivo: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al desvincular dispositivo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _toggleLocalNotificationsEnabled(bool value) async {
    if (value && await Permission.notification.isDenied) {
      final status = await Permission.notification.request();
      if (!mounted) return;
      if (status.isDenied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Se requieren permisos de notificación para esta función',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    await LocalNotificationService.setNotificationsEnabled(value);

    if (value) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Inicializando servicio de notificaciones...'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 2),
          ),
        );
      }

      await _receptorService.initializeReceptorWithoutNotifications();
      await NotificationListenerService.instance.setListeningEnabled(true);

      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Notificaciones locales habilitadas. Solo se mostrarán notificaciones nuevas.',
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      });
    } else {
      _receptorService.clearReceptorState();
      await NotificationListenerService.instance.setListeningEnabled(false);
    }

    if (!mounted) return;
    setState(() {
      _notificationsEnabled = value;
    });
  }

  Widget _buildLocalNotificationsToggleCard() {
    final isActive = _notificationsEnabled;
    return GestureDetector(
      onTap: () {
        setState(() {
          _showLocalNotificationsSubtitle = !_showLocalNotificationsSubtitle;
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.green[50] : Colors.red[50],
          border: Border.all(
            color: isActive ? Colors.green : Colors.red,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mostrar notificaciones locales',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isActive ? Colors.green[900] : Colors.red[900],
                      fontSize: 16,
                    ),
                  ),
                  if (_showLocalNotificationsSubtitle)
                    Padding(
                      padding: const EdgeInsets.only(top: 1.0),
                      child: Text(
                        'Muestra las notificaciones recibidas en la barra de notificaciones',
                        style: TextStyle(
                          color: isActive ? Colors.green[700] : Colors.red[700],
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Switch(
              value: _notificationsEnabled,
              onChanged: _toggleLocalNotificationsEnabled,
              activeThumbColor: Colors.green,
              inactiveThumbColor: Colors.red,
              inactiveTrackColor: Colors.red[200],
            ),
          ],
        ),
      ),
    );
  }

  // ===== Permisos =====
  List<_PermItem> get _permItems => [
        _PermItem(
          id: 'notif_access',
          icon: Icons.notifications_active,
          title: 'Acceso a notificaciones',
          subtitle: 'Permite leer y gestionar las notificaciones del sistema.',
          check: () async {
            try {
              final r =
                  await _emisorChannel.invokeMethod('isNotificationServiceEnabled');
              return r == true;
            } catch (_) {
              return false;
            }
          },
          action: _openNotificationListenerPermission,
          actionLabel: 'Abrir ajustes',
        ),
        _PermItem(
          id: 'post_notif',
          icon: Icons.notifications,
          title: 'Mostrar notificaciones',
          subtitle: 'Necesario para mostrar las notificaciones recibidas.',
          check: () async => (await Permission.notification.status).isGranted,
          action: () async => await Permission.notification.request(),
          actionLabel: 'Conceder',
        ),
        _PermItem(
          id: 'bt_connect',
          icon: Icons.bluetooth_connected,
          title: 'Bluetooth (conectar)',
          subtitle: 'Conexión con el dispositivo emisor por Bluetooth.',
          check: () async => (await Permission.bluetoothConnect.status).isGranted,
          action: () async => await Permission.bluetoothConnect.request(),
          actionLabel: 'Conceder',
        ),
        _PermItem(
          id: 'bt_scan',
          icon: Icons.bluetooth_searching,
          title: 'Bluetooth (buscar)',
          subtitle: 'Buscar dispositivos cercanos para vincular.',
          check: () async => (await Permission.bluetoothScan.status).isGranted,
          action: () async => await Permission.bluetoothScan.request(),
          actionLabel: 'Conceder',
        ),
        _PermItem(
          id: 'location',
          icon: Icons.location_on,
          title: 'Ubicación',
          subtitle:
              'El sistema la requiere para buscar dispositivos Bluetooth cercanos.',
          check: () async => (await Permission.location.status).isGranted,
          action: () async => await Permission.location.request(),
          actionLabel: 'Conceder',
        ),
        _PermItem(
          id: 'overlay',
          icon: Icons.layers,
          title: 'Mostrar sobre otras apps',
          subtitle:
              'Permite la bola flotante y abrir la app sobre la pantalla bloqueada.',
          check: FloatingBallService.isOverlayPermissionGranted,
          action: FloatingBallService.openOverlayPermissionSettings,
          actionLabel: 'Abrir ajustes',
        ),
        _PermItem(
          id: 'accessibility',
          icon: Icons.accessibility_new,
          title: 'Accesibilidad',
          subtitle:
              'Habilita acciones globales (Inicio/Atrás/Recientes) de la bola flotante.',
          check: FloatingBallService.isAccessibilityEnabled,
          action: FloatingBallService.openAccessibilitySettings,
          actionLabel: 'Abrir ajustes',
        ),
        _PermItem(
          id: 'battery',
          icon: Icons.battery_charging_full,
          title: 'Ignorar optimización de batería',
          subtitle: 'Evita que el sistema cierre el servicio en segundo plano.',
          check: FloatingBallService.isBatteryOptimizationIgnored,
          action: FloatingBallService.requestBatteryOptimizationPermission,
          actionLabel: 'Permitir',
        ),
        _PermItem(
          id: 'audio',
          icon: Icons.library_music,
          title: 'Audio / almacenamiento',
          subtitle: 'Para elegir sonidos personalizados de notificación.',
          check: () async => (await Permission.audio.status).isGranted,
          action: () async => await Permission.audio.request(),
          actionLabel: 'Conceder',
        ),
      ];

  Future<void> _loadPermissions() async {
    final items = _permItems;
    final results = <String, bool>{};
    for (final it in items) {
      try {
        results[it.id] = await it.check();
      } catch (_) {
        results[it.id] = false;
      }
    }
    if (!mounted) return;
    setState(() => _permStatus = results);
  }

  // ===== Helpers de pestañas =====
  Widget _tabPage(List<Widget> children) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: children,
    );
  }

  Widget _tabHeader(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, left: 4, right: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(subtitle,
              style: const TextStyle(fontSize: 13, color: Colors.black54)),
          const Divider(height: 20),
        ],
      ),
    );
  }

  // Tarjeta explicativa de navegación (reemplaza a los botones planos).
  Widget _navCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? color,
  }) {
    final c = color ?? customColor[600]!;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: c, size: 26),
        ),
        title: Text(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(subtitle,
              style: const TextStyle(fontSize: 13, color: Colors.black54)),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  // Tarjeta con switch y descripción.
  Widget _switchCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool?> onChanged,
    String? warning,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: customColor[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: customColor[600], size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style:
                          const TextStyle(fontSize: 13, color: Colors.black54)),
                  if (warning != null) ...[
                    const SizedBox(height: 4),
                    Text(warning,
                        style: const TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: Colors.red)),
                  ],
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: Colors.green,
              inactiveTrackColor: customColor[200],
              inactiveThumbColor: Colors.grey[300],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionCard(_PermItem it) {
    final granted = _permStatus[it.id] ?? false;
    final MaterialColor statusColor = granted ? Colors.green : Colors.red;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(it.icon, color: statusColor[700]),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(it.title,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(it.subtitle,
                          style: const TextStyle(
                              fontSize: 13, color: Colors.black54)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(granted ? Icons.check_circle : Icons.cancel,
                          size: 16, color: statusColor[700]),
                      const SizedBox(width: 6),
                      Text(granted ? 'Concedido' : 'No concedido',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: statusColor[800])),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    await it.action();
                    await _loadPermissions();
                  },
                  child: Text(granted ? 'Revisar' : it.actionLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ===== Pestañas =====
  Widget _buildDeviceTab() {
    return _tabPage([
      _tabHeader('Dispositivo',
          'Vinculación, conexión y herramientas del receptor.'),
      _navCard(
        icon: Icons.bluetooth_searching,
        title: 'Configurar conexión Bluetooth',
        subtitle: 'Ajusta la conexión Bluetooth con el dispositivo emisor.',
        color: customColor[500],
        onTap: () => Navigator.pushNamed(context, '/receptor_ble_signal'),
      ),
      _navCard(
        icon: Icons.play_circle_outline,
        title: 'Reproducción multimedia',
        subtitle: 'Controla la reproducción del dispositivo vinculado.',
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  const MediaReproductionScreen(useLinkedDevice: true),
            ),
          );
        },
      ),
      _navCard(
        icon: Icons.radio_button_checked,
        title: 'Configurar bola flotante',
        subtitle: 'Personaliza la bola flotante, gestos y menú.',
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const FloatingBallSettingsScreen()),
          );
        },
      ),
      _navCard(
        icon: Icons.developer_board,
        title: 'Diagnóstico del dispositivo',
        subtitle: 'Revisa el estado y los detalles técnicos del receptor.',
        color: Colors.grey[700],
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const DeviceDiagnosticsScreen()),
          );
        },
      ),
      const SizedBox(height: 8),
      _navCard(
        icon: Icons.link_off,
        title: 'Desvincular dispositivo',
        subtitle: 'Quita el vínculo con el emisor y detiene la recepción.',
        color: Colors.red,
        onTap: _unlinkDevice,
      ),
    ]);
  }

  Widget _buildNotificationsTab() {
    return _tabPage([
      _tabHeader('Notificaciones',
          'Comportamiento, sonido, vibración y filtros de las notificaciones recibidas.'),
      _buildLocalNotificationsToggleCard(),
      _switchCard(
        icon: Icons.brightness_high,
        title: 'Activar pantalla',
        subtitle: 'Enciende la pantalla cuando llega una notificación.',
        value: _screenWakeEnabled,
        onChanged: _toggleScreenWake,
      ),
      _switchCard(
        icon: Icons.open_in_new,
        title: 'Abrir aplicación automáticamente',
        subtitle: 'Abre la app automáticamente cuando llega una notificación.',
        value: _autoOpenEnabled,
        onChanged: _toggleAutoOpen,
        warning: _autoOpenEnabled
            ? 'Desactivar requiere reinicio de la app.'
            : null,
      ),
      _switchCard(
        icon: Icons.vibration,
        title: 'Vibración',
        subtitle: 'Activa la vibración cuando llega una notificación.',
        value: _vibrationEnabled,
        onChanged: _toggleVibration,
      ),
      if (_vibrationEnabled)
        _navCard(
          icon: Icons.graphic_eq,
          title: 'Patrones de vibración',
          subtitle: 'Crear y gestionar patrones personalizados.',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const VibrationPatternsScreen()),
          ),
        ),
      _switchCard(
        icon: Icons.volume_up,
        title: 'Sonido',
        subtitle: 'Activa el sonido cuando llega una notificación.',
        value: _soundEnabled,
        onChanged: _toggleSound,
      ),
      if (_soundEnabled)
        _navCard(
          icon: Icons.music_note,
          title: 'Sonidos personalizados',
          subtitle: 'Seleccionar sonidos desde el dispositivo.',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const CustomSoundSelectionScreen()),
          ),
        ),
      const SizedBox(height: 8),
      const Padding(
        padding: EdgeInsets.fromLTRB(4, 8, 4, 4),
        child: Text('Más opciones',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
      ),
      _navCard(
        icon: Icons.chat_bubble_outline,
        title: 'Conversaciones',
        subtitle: 'Activar vista tipo chat por aplicación.',
        onTap: () => Navigator.pushNamed(context, '/conversation_apps'),
      ),
      _navCard(
        icon: Icons.tune,
        title: 'Bloqueo, sonido y vibración por notificación',
        subtitle:
            'Reglas personalizadas según el contenido de las notificaciones.',
        onTap: () => Navigator.pushNamed(context, '/notification_settings_list'),
      ),
      _navCard(
        icon: Icons.filter_alt,
        title: 'Filtros de notificación',
        subtitle: 'Define qué notificaciones se reciben o se ignoran.',
        onTap: () => Navigator.pushNamed(context, '/notification_filters'),
      ),
    ]);
  }

  Widget _buildWidgetsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: _tabHeader('Widgets',
              'Widgets configurables de la app y de la pantalla de inicio.'),
        ),
        const Expanded(child: WidgetsConfigScreen(embedded: true)),
      ],
    );
  }

  Widget _buildPermissionsTab() {
    return _tabPage([
      _tabHeader('Permisos',
          'Estado de los permisos que necesita el receptor. Tócalos para concederlos.'),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: _loadPermissions,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Actualizar'),
        ),
      ),
      ..._permItems.map(_buildPermissionCard),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Configuración Receptor'),
          backgroundColor: customColor[700],
          foregroundColor: Colors.white,
          bottom: _isLoading
              ? null
              : const TabBar(
                  isScrollable: true,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  indicatorColor: Colors.white,
                  tabAlignment: TabAlignment.start,
                  tabs: [
                    Tab(text: 'Dispositivo'),
                    Tab(text: 'Notificaciones'),
                    Tab(text: 'Widgets'),
                    Tab(text: 'Permisos'),
                  ],
                ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildDeviceTab(),
                  _buildNotificationsTab(),
                  _buildWidgetsTab(),
                  _buildPermissionsTab(),
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
                label: 'Conexión',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.mark_email_unread),
                label: 'Notificaciones',
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }
}



