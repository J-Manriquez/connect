import 'package:connect/screens/emisor/floating_ball_app_picker_screen.dart';
import 'package:connect/screens/emisor/floating_ball_tool_picker_screen.dart';
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
  List<String> _selectedTools = <String>[];
  final Map<String, int> _toolOffsetsX = {};
  final Map<String, int> _toolOffsetsY = {};
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
      final tools = await FloatingBallService.getSelectedTools();
      const toolIds = ['tool:tts', 'tool:dict', 'tool:trans', 'tool:search'];
      final toolOffX = <String, int>{};
      final toolOffY = <String, int>{};
      for (final id in toolIds) {
        toolOffX[id] = await FloatingBallService.getToolOffsetX(id);
        toolOffY[id] = await FloatingBallService.getToolOffsetY(id);
      }
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
          _selectedTools = tools;
          _toolOffsetsX
            ..clear()
            ..addAll(toolOffX);
          _toolOffsetsY
            ..clear()
            ..addAll(toolOffY);
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

  Future<void> _pickTools() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const FloatingBallToolPickerScreen(),
      ),
    );
    await _loadState();
  }

  String _toolLabel(String toolId) {
    switch (toolId) {
      case 'tool:tts':    return 'Lector TTS';
      case 'tool:dict':   return 'Diccionario';
      case 'tool:trans':  return 'Traductor';
      case 'tool:search': return 'Buscar';
      default:            return toolId;
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
    await FloatingBallService.setFullScreenConversationEnabled(true);
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
        ? (packageName == null
            ? 'Acción: $actionLabel • App: sin seleccionar'
            : 'Acción: $actionLabel • App: $packageName')
        : 'Acción: $actionLabel';
    final selectedAction =
        _gestureActionLabels.containsKey(action) ? action : 'back';
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedAction,
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
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Aplicación para esta acción'),
            subtitle: const Text('Se usa cuando la acción es “Abrir app”.'),
            trailing: TextButton(
              onPressed: onPickApp,
              child: const Text('Seleccionar'),
            ),
          ),
      ],
    );
  }

  IconData _toolIcon(String toolId) {
    switch (toolId) {
      case 'tool:tts':    return Icons.record_voice_over;
      case 'tool:dict':   return Icons.menu_book;
      case 'tool:trans':  return Icons.translate;
      case 'tool:search': return Icons.search;
      default:            return Icons.build;
    }
  }

  Widget _buildOffsetRow(
      String label, String toolId, String axis, ButtonStyle linkBtnStyle) {
    final value =
        axis == 'x' ? (_toolOffsetsX[toolId] ?? 40) : (_toolOffsetsY[toolId] ?? 200);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$label: $value dp',
                    style: const TextStyle(fontSize: 13)),
                Slider(
                  min: 0,
                  max: 800,
                  divisions: 80,
                  value: value.toDouble().clamp(0, 800),
                  activeColor: customColor[600],
                  onChanged: (v) {
                    setState(() {
                      if (axis == 'x') {
                        _toolOffsetsX[toolId] = v.toInt();
                      } else {
                        _toolOffsetsY[toolId] = v.toInt();
                      }
                    });
                  },
                  onChangeEnd: (v) async {
                    if (axis == 'x') {
                      await FloatingBallService.setToolOffsetX(
                          toolId, v.toInt());
                    } else {
                      await FloatingBallService.setToolOffsetY(
                          toolId, v.toInt());
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Contenedor desplazable de una pestaña (reemplaza a las tarjetas
  // expandibles): cada pestaña muestra directamente su contenido.
  Widget _tabPage(List<Widget> children) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: children,
    );
  }

  // Encabezado descriptivo al inicio de cada pestaña.
  Widget _tabHeader(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const Divider(height: 20),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusText = _enabled ? 'Activada' : 'Desactivada';
    final statusDesc = _enabled
        ? 'La bola está activa y se mantiene en ejecución.'
        : 'La bola no se muestra hasta que la actives.';
    final selectedAppsText = _selectedApps.isEmpty
        ? 'Sin aplicaciones seleccionadas'
        : '${_selectedApps.length} seleccionadas';
    final primaryBtnStyle = ElevatedButton.styleFrom(
      backgroundColor: customColor[600],
      foregroundColor: Colors.white,
      minimumSize: const Size.fromHeight(48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    );
    final destructiveBtnStyle = ElevatedButton.styleFrom(
      backgroundColor: Colors.red,
      foregroundColor: Colors.white,
      minimumSize: const Size.fromHeight(48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    );
    final linkBtnStyle = TextButton.styleFrom(
      foregroundColor: customColor[600],
      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    );
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Configuración bola flotante'),
          backgroundColor: customColor[700],
          foregroundColor: Colors.white,
          bottom: _loading
              ? null
              : const TabBar(
                  isScrollable: true,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  indicatorColor: Colors.white,
                  tabAlignment: TabAlignment.start,
                  tabs: [
                    Tab(text: 'Estado'),
                    Tab(text: 'Menú'),
                    Tab(text: 'Gestos'),
                  ],
                ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _tabPage([
                    _tabHeader(
                      'Estado y permisos',
                      'Activa la bola y revisa los permisos necesarios para que funcione en segundo plano.',
                    ),
                        // Estado actual
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Icon(
                                _enabled ? Icons.check_circle : Icons.cancel,
                                color: _enabled ? Colors.green : Colors.red,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      statusText,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600),
                                    ),
                                    Text(
                                      statusDesc,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Botones Activar / Desactivar en fila
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _enabled ? null : _activate,
                                style: primaryBtnStyle,
                                child: const Text('Activar'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _enabled ? _deactivate : null,
                                style: destructiveBtnStyle,
                                child: const Text('Desactivar'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Botón centrar bola
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _enabled
                                ? () async {
                                    await FloatingBallService.centerBall();
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content:
                                              Text('Bola centrada en pantalla'),
                                        ),
                                      );
                                    }
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: customColor[500],
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(44),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              textStyle: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                            icon: const Icon(Icons.my_location, size: 18),
                            label: const Text('Centrar bola flotante'),
                          ),
                        ),
                        const Divider(),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Permiso sobre otras apps'),
                          subtitle: Text(
                            _overlayGranted
                                ? 'Concedido • Permite mostrar la bola por encima de otras apps.'
                                : 'Requerido para mostrar la bola por encima de otras apps.',
                          ),
                          trailing: TextButton(
                            onPressed: _overlayGranted
                                ? null
                                : () async {
                                    await FloatingBallService
                                        .openOverlayPermissionSettings();
                                  },
                            style: linkBtnStyle,
                            child: const Text('Abrir'),
                          ),
                        ),
                        const Divider(),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Accesibilidad (Home/Recientes/Back)'),
                          subtitle: Text(
                            _accessibilityEnabled
                                ? 'Activada • Habilita acciones globales como Home/Recientes/Back.'
                                : 'Requerida para acciones globales como Home/Recientes/Back.',
                          ),
                          trailing: TextButton(
                            onPressed: () async {
                              await FloatingBallService.openAccessibilitySettings();
                            },
                            style: linkBtnStyle,
                            child: const Text('Abrir'),
                          ),
                        ),
                        const Divider(),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Optimización de batería'),
                          subtitle: Text(
                            _batteryIgnored
                                ? 'Ignorada • Reduce cortes del servicio por ahorro de batería.'
                                : 'Recomendado para evitar que el sistema cierre el servicio.',
                          ),
                          trailing: TextButton(
                            onPressed: _batteryIgnored
                                ? null
                                : () async {
                                    await FloatingBallService
                                        .requestBatteryOptimizationPermission();
                                  },
                            style: linkBtnStyle,
                            child: const Text('Permitir'),
                          ),
                        ),
                  ]),
                  _tabPage([
                    _tabHeader(
                      'Personalización',
                      'Ajusta el estilo de la bola y el contenido del menú (apps, pantalla completa y más).',
                    ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Personalizar bola'),
                          subtitle: const Text(
                            'Color, icono, modo pantalla completa, popup y pantallas asociadas.',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.pushNamed(
                            context,
                            '/floating_ball_style',
                          ),
                        ),
                        const Divider(),
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: const Text('Aplicaciones del menú'),
                          subtitle: const Text(
                            'Se muestran al abrir la bola (acceso rápido a apps).',
                          ),
                          childrenPadding: const EdgeInsets.only(bottom: 8),
                          children: [
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Seleccionar aplicaciones'),
                              subtitle: Text(selectedAppsText),
                              trailing: TextButton(
                                onPressed: _pickApps,
                                style: linkBtnStyle,
                                child: const Text('Seleccionar'),
                              ),
                            ),
                            if (_selectedApps.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: _selectedApps
                                      .take(8)
                                      .map((e) => Text('• $e'))
                                      .toList(),
                                ),
                              ),
                            const Divider(),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Herramientas del menú'),
                              subtitle: Text(
                                _selectedTools.isEmpty
                                    ? 'Sin herramientas seleccionadas'
                                    : '${_selectedTools.length} seleccionada(s): ${_selectedTools.map(_toolLabel).join(', ')}',
                              ),
                              trailing: TextButton(
                                onPressed: _pickTools,
                                style: linkBtnStyle,
                                child: const Text('Seleccionar'),
                              ),
                            ),
                          ],
                        ),
                  if (_selectedTools.isNotEmpty) ...[
                    const Divider(height: 28),
                    _tabHeader(
                      'Posición de widgets flotantes',
                      'Ajusta dónde aparece cada widget al abrirse.',
                    ),
                          for (final toolId in _selectedTools) ...[
                            Padding(
                              padding: const EdgeInsets.only(top: 12, bottom: 4),
                              child: Row(
                                children: [
                                  Icon(
                                    _toolIcon(toolId),
                                    color: customColor[600],
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _toolLabel(toolId),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: customColor[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _buildOffsetRow(
                                'Posición X', toolId, 'x', linkBtnStyle),
                            _buildOffsetRow(
                                'Posición Y', toolId, 'y', linkBtnStyle),
                            if (toolId != _selectedTools.last)
                              const Divider(height: 20),
                          ],
                  ],
                  ]),
                  _tabPage([
                    _tabHeader(
                      'Gestos',
                      'Acciones al deslizar fuera de la bola. Útil si quieres mantener la bola estática.',
                    ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Habilitar gestos'),
                          subtitle: const Text(
                            'Permite acciones por dirección y configura vibración/tiempos.',
                          ),
                          value: _gesturesEnabled,
                          activeColor: Colors.green,
                          inactiveTrackColor: customColor[200],
                          inactiveThumbColor: Colors.grey[300],
                          onChanged: (v) async {
                            setState(() => _gesturesEnabled = v);
                            await FloatingBallService.setGesturesEnabled(v);
                          },
                        ),
                        if (_gesturesEnabled) ...[
                          const Divider(),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Mantener presionado para mover'),
                            subtitle: Text('$_gestureLongPressMs ms • Duración requerida'),
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
                          const Divider(),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Vibración (duración)'),
                            subtitle: Text('$_gestureVibrationMs ms • 0 desactiva'),
                          ),
                          Slider(
                            value: _gestureVibrationMs.toDouble(),
                            min: 0,
                            max: 500,
                            divisions: 50,
                            label: '${_gestureVibrationMs}ms',
                            onChanged: (v) {
                              setState(() => _gestureVibrationMs = v.round());
                            },
                            onChangeEnd: (v) async {
                              final ms = v.round();
                              await FloatingBallService.setGestureVibrationMs(ms);
                            },
                          ),
                          const Divider(),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Vibración (potencia)'),
                            subtitle: Text('$_gestureVibrationAmplitude • 1–255'),
                          ),
                          Slider(
                            value: _gestureVibrationAmplitude.toDouble(),
                            min: 1,
                            max: 255,
                            divisions: 254,
                            label: '$_gestureVibrationAmplitude',
                            onChanged: (v) {
                              setState(() => _gestureVibrationAmplitude = v.round());
                            },
                            onChangeEnd: (v) async {
                              final amp = v.round();
                              await FloatingBallService.setGestureVibrationAmplitude(
                                amp,
                              );
                            },
                          ),
                          const Divider(),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Pantalla de notificaciones personalizada'),
                            subtitle: const Text(
                              'Cuando la acción es “Barra de notificaciones”, usa la pantalla personalizada.',
                            ),
                            value: _gestureNotificationsUseCustomScreen,
                            activeColor: Colors.green,
                            inactiveTrackColor: customColor[200],
                            inactiveThumbColor: Colors.grey[300],
                            onChanged: (v) async {
                              setState(() => _gestureNotificationsUseCustomScreen = v);
                              await FloatingBallService
                                  .setGestureNotificationsUseCustomScreenEnabled(
                                v,
                              );
                            },
                          ),
                          const Divider(),
                          ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            title: const Text('Acciones por dirección'),
                            subtitle: const Text(
                              'Configura qué hace cada gesto (arriba/derecha/abajo/izquierda).',
                            ),
                            children: [
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
                              const Divider(),
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
                              const Divider(),
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
                              const Divider(),
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
                          ),
                        ],
                  ]),
                ],
              ),
        ),
    );
  }
}
