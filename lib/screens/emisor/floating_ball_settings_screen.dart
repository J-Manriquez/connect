import 'package:connect/screens/emisor/floating_ball_app_picker_screen.dart';
import 'package:connect/services/floating_ball_service.dart';
import 'package:connect/theme_colors.dart';
import 'package:flutter/material.dart';

class FloatingBallSettingsScreen extends StatefulWidget {
  const FloatingBallSettingsScreen({super.key});

  @override
  State<FloatingBallSettingsScreen> createState() =>
      _FloatingBallSettingsScreenState();
}

class _FloatingBallSettingsScreenState extends State<FloatingBallSettingsScreen>
    with WidgetsBindingObserver {
  bool _enabled = false;
  bool _overlayGranted = false;
  bool _accessibilityEnabled = false;
  bool _batteryIgnored = false;
  bool _loading = true;
  List<String> _selectedApps = <String>[];
  bool _gesturesEnabled = false;
  int _gestureLongPressMs = 450;
  int _gestureVibrationMs = 35;
  int _gestureVibrationAmplitude = 180;
  bool _gestureNotificationsUseCustomScreen = false;
  String _gestureUpAction = 'notifications';
  String _gestureRightAction = 'home';
  String _gestureDownAction = 'recents';
  String _gestureLeftAction = 'back';
  String? _gestureUpApp;
  String? _gestureRightApp;
  String? _gestureDownApp;
  String? _gestureLeftApp;

  static const Map<String, String> _gestureActionLabels = <String, String>{
    'back': 'Back',
    'home': 'Home',
    'recents': 'Recientes',
    'volume': 'Volumen',
    'brightness': 'Brillo',
    'settings': 'Ajustes',
    'notifications': 'Barra de notificaciones',
    'app': 'Abrir app',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadState();
    }
  }

  Future<void> _loadState() async {
    setState(() {
      _loading = true;
    });
    try {
      final enabled = await FloatingBallService.isEnabled();
      final overlay = await FloatingBallService.isOverlayPermissionGranted();
      final acc = await FloatingBallService.isAccessibilityEnabled();
      final batt = await FloatingBallService.isBatteryOptimizationIgnored();
      final apps = await FloatingBallService.getSelectedApps();
      final gesturesEnabled = await FloatingBallService.isGesturesEnabled();
      final longPressMs = await FloatingBallService.getGestureLongPressMs();
      final upAction = await FloatingBallService.getGestureUpAction();
      final rightAction = await FloatingBallService.getGestureRightAction();
      final downAction = await FloatingBallService.getGestureDownAction();
      final leftAction = await FloatingBallService.getGestureLeftAction();
      final upApp = await FloatingBallService.getGestureUpApp();
      final rightApp = await FloatingBallService.getGestureRightApp();
      final downApp = await FloatingBallService.getGestureDownApp();
      final leftApp = await FloatingBallService.getGestureLeftApp();
      final vibMs = await FloatingBallService.getGestureVibrationMs();
      final vibAmp = await FloatingBallService.getGestureVibrationAmplitude();
      final notifsCustom = await FloatingBallService
          .isGestureNotificationsUseCustomScreenEnabled();
      if (mounted) {
        setState(() {
          _enabled = enabled;
          _overlayGranted = overlay;
          _accessibilityEnabled = acc;
          _batteryIgnored = batt;
          _selectedApps = apps;
          _gesturesEnabled = gesturesEnabled;
          _gestureLongPressMs = longPressMs;
          _gestureUpAction = upAction;
          _gestureRightAction = rightAction;
          _gestureDownAction = downAction;
          _gestureLeftAction = leftAction;
          _gestureUpApp = upApp;
          _gestureRightApp = rightApp;
          _gestureDownApp = downApp;
          _gestureLeftApp = leftApp;
          _gestureVibrationMs = vibMs;
          _gestureVibrationAmplitude = vibAmp;
          _gestureNotificationsUseCustomScreen = notifsCustom;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _pickApps() async {
    final res = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => FloatingBallAppPickerScreen(
          initialSelectedPackages: _selectedApps,
        ),
      ),
    );
    if (res == null) return;
    setState(() {
      _selectedApps = res;
    });
    await FloatingBallService.setSelectedApps(res);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aplicaciones actualizadas')),
      );
    }
  }

  Future<void> _activate() async {
    final overlay = await FloatingBallService.isOverlayPermissionGranted();
    if (!overlay) {
      await FloatingBallService.openOverlayPermissionSettings();
      return;
    }
    await FloatingBallService.setSelectedApps(_selectedApps);
    await FloatingBallService.setFullScreenEnabled(true);
    await FloatingBallService.enableAndStart();
    await _loadState();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bola flotante activada permanentemente')),
      );
    }
  }

  Future<void> _deactivate() async {
    await FloatingBallService.setEnabledFalse();
    await _loadState();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bola flotante desactivada')),
      );
    }
  }

  Future<void> _pickGestureApp({
    required String direction,
    required String? currentPackage,
  }) async {
    final res = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => FloatingBallAppPickerScreen(
          initialSelectedPackages: currentPackage == null ? <String>[] : <String>[currentPackage],
          singleSelection: true,
          title: 'Seleccionar aplicación',
        ),
      ),
    );
    if (res == null) return;
    final pkg = res.isEmpty ? null : res.first;

    if (!mounted) return;
    setState(() {
      if (direction == 'up') _gestureUpApp = pkg;
      if (direction == 'right') _gestureRightApp = pkg;
      if (direction == 'down') _gestureDownApp = pkg;
      if (direction == 'left') _gestureLeftApp = pkg;
    });

    if (direction == 'up') await FloatingBallService.setGestureUpApp(pkg);
    if (direction == 'right') await FloatingBallService.setGestureRightApp(pkg);
    if (direction == 'down') await FloatingBallService.setGestureDownApp(pkg);
    if (direction == 'left') await FloatingBallService.setGestureLeftApp(pkg);
  }

  Widget _buildGestureTile({
    required String title,
    required String action,
    required ValueChanged<String> onActionChanged,
    required String? packageName,
    required VoidCallback onPickApp,
  }) {
    final actionLabel = _gestureActionLabels[action] ?? action;
    final subtitle = action == 'app'
        ? (packageName == null ? '$actionLabel: sin app' : '$actionLabel: $packageName')
        : actionLabel;
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _gestureActionLabels.containsKey(action) ? action : 'back',
              items: _gestureActionLabels.entries
                  .map(
                    (e) => DropdownMenuItem<String>(
                      value: e.key,
                      child: Text(e.value),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                onActionChanged(v);
              },
            ),
          ),
        ),
        if (action == 'app')
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onPickApp,
              child: const Text('Seleccionar app'),
            ),
          ),
        const Divider(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración bola flotante'),
        backgroundColor: customColor,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                _enabled ? Icons.check_circle : Icons.cancel,
                                color: _enabled ? Colors.green : Colors.red,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _enabled
                                      ? 'Activada (no se desactiva nunca)'
                                      : 'Desactivada',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Column(
                                children: [
                                  ElevatedButton(
                                    onPressed: _enabled ? null : _activate,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: customColor,
                                    ),
                                    child: const Text('Activar'),
                                  ),
                                  const SizedBox(height: 8),
                                  ElevatedButton(
                                    onPressed: _enabled ? _deactivate : null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                    ),
                                    child: const Text('Desactivar'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Permiso sobre otras apps'),
                            subtitle: Text(
                              _overlayGranted
                                  ? 'Concedido'
                                  : 'Requerido para mostrar la bola',
                            ),
                            trailing: TextButton(
                              onPressed: _overlayGranted
                                  ? null
                                  : () async {
                                      await FloatingBallService
                                          .openOverlayPermissionSettings();
                                    },
                              child: const Text('Abrir'),
                            ),
                          ),
                          const Divider(),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Accesibilidad (Home/Recientes/Back)'),
                            subtitle: Text(
                              _accessibilityEnabled
                                  ? 'Activada'
                                  : 'Requerida para acciones globales',
                            ),
                            trailing: TextButton(
                              onPressed: () async {
                                await FloatingBallService
                                    .openAccessibilitySettings();
                              },
                              child: const Text('Abrir'),
                            ),
                          ),
                          const Divider(),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Optimización de batería'),
                            subtitle: Text(
                              _batteryIgnored
                                  ? 'Ignorada'
                                  : 'Recomendado para que no se cierre',
                            ),
                            trailing: TextButton(
                              onPressed: _batteryIgnored
                                  ? null
                                  : () async {
                                      await FloatingBallService
                                          .requestBatteryOptimizationPermission();
                                    },
                              child: const Text('Permitir'),
                            ),
                          ),
                          const Divider(),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Personalizar bola'),
                            subtitle: const Text('Color, icono y modo pantalla completa'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.pushNamed(
                              context,
                              '/floating_ball_style',
                            ),
                          ),
                          const Divider(),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Gestos fuera de la bola'),
                            subtitle: const Text(
                              'Mantiene la bola estática y permite acciones por direcciones',
                            ),
                            value: _gesturesEnabled,
                            onChanged: (v) async {
                              setState(() => _gesturesEnabled = v);
                              await FloatingBallService.setGesturesEnabled(v);
                            },
                          ),
                          if (_gesturesEnabled) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Mantener presionado para mover: $_gestureLongPressMs ms',
                              style: const TextStyle(fontSize: 13),
                            ),
                            Slider(
                              value: _gestureLongPressMs.toDouble(),
                              min: 150,
                              max: 2000,
                              divisions: 37,
                              label: '${_gestureLongPressMs}ms',
                              onChanged: (v) {
                                setState(() => _gestureLongPressMs = v.round());
                              },
                              onChangeEnd: (v) async {
                                final ms = v.round();
                                await FloatingBallService.setGestureLongPressMs(ms);
                              },
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Vibración (duración): $_gestureVibrationMs ms',
                              style: const TextStyle(fontSize: 13),
                            ),
                            Slider(
                              value: _gestureVibrationMs.toDouble(),
                              min: 0,
                              max: 500,
                              divisions: 50,
                              label: '${_gestureVibrationMs}ms',
                              onChanged: (v) {
                                setState(
                                  () => _gestureVibrationMs = v.round(),
                                );
                              },
                              onChangeEnd: (v) async {
                                final ms = v.round();
                                await FloatingBallService.setGestureVibrationMs(ms);
                              },
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Vibración (potencia): $_gestureVibrationAmplitude',
                              style: const TextStyle(fontSize: 13),
                            ),
                            Slider(
                              value: _gestureVibrationAmplitude.toDouble(),
                              min: 1,
                              max: 255,
                              divisions: 254,
                              label: '$_gestureVibrationAmplitude',
                              onChanged: (v) {
                                setState(
                                  () => _gestureVibrationAmplitude = v.round(),
                                );
                              },
                              onChangeEnd: (v) async {
                                final amp = v.round();
                                await FloatingBallService.setGestureVibrationAmplitude(
                                  amp,
                                );
                              },
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                'Usar pantalla de notificaciones personalizada',
                              ),
                              subtitle: const Text(
                                'Aplica a la acción "Barra de notificaciones"',
                              ),
                              value: _gestureNotificationsUseCustomScreen,
                              onChanged: (v) async {
                                setState(
                                  () => _gestureNotificationsUseCustomScreen = v,
                                );
                                await FloatingBallService
                                    .setGestureNotificationsUseCustomScreenEnabled(
                                  v,
                                );
                              },
                            ),
                            _buildGestureTile(
                              title: 'Gesto hacia arriba',
                              action: _gestureUpAction,
                              onActionChanged: (v) async {
                                setState(() => _gestureUpAction = v);
                                await FloatingBallService.setGestureUpAction(v);
                              },
                              packageName: _gestureUpApp,
                              onPickApp: () => _pickGestureApp(
                                direction: 'up',
                                currentPackage: _gestureUpApp,
                              ),
                            ),
                            _buildGestureTile(
                              title: 'Gesto hacia la derecha',
                              action: _gestureRightAction,
                              onActionChanged: (v) async {
                                setState(() => _gestureRightAction = v);
                                await FloatingBallService.setGestureRightAction(v);
                              },
                              packageName: _gestureRightApp,
                              onPickApp: () => _pickGestureApp(
                                direction: 'right',
                                currentPackage: _gestureRightApp,
                              ),
                            ),
                            _buildGestureTile(
                              title: 'Gesto hacia abajo',
                              action: _gestureDownAction,
                              onActionChanged: (v) async {
                                setState(() => _gestureDownAction = v);
                                await FloatingBallService.setGestureDownAction(v);
                              },
                              packageName: _gestureDownApp,
                              onPickApp: () => _pickGestureApp(
                                direction: 'down',
                                currentPackage: _gestureDownApp,
                              ),
                            ),
                            _buildGestureTile(
                              title: 'Gesto hacia la izquierda',
                              action: _gestureLeftAction,
                              onActionChanged: (v) async {
                                setState(() => _gestureLeftAction = v);
                                await FloatingBallService.setGestureLeftAction(v);
                              },
                              packageName: _gestureLeftApp,
                              onPickApp: () => _pickGestureApp(
                                direction: 'left',
                                currentPackage: _gestureLeftApp,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Aplicaciones en el menú',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: _pickApps,
                                child: const Text('Seleccionar'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (_selectedApps.isEmpty)
                            const Text('No hay aplicaciones seleccionadas')
                          else
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: _selectedApps
                                  .take(8)
                                  .map((e) => Text('• $e'))
                                  .toList(),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
