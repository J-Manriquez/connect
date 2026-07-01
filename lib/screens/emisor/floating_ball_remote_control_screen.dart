import 'dart:async';
import 'dart:math' show min;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/floating_ball_service.dart';
import '../../services/remote_control_service.dart';
import 'remote_apps_screen.dart';
// ignore: unused_import — RemoteDebugScreen disponible para diagnóstico. No eliminar.
import 'remote_debug_screen.dart';

/// Control remoto BT accesible desde el menú de la bola flotante.
///
/// Es funcionalmente idéntico a [RemoteControlScreen] pero:
/// 1. Se abre sobre otras apps (Activity transparente propia).
/// 2. Se cierra con [SystemNavigator.pop] (finaliza la Activity), no con pop
///    de ruta, para volver a la app previa en vez de al home del emisor.
/// 3. El fondo y los colores se toman de [FloatingBallService] para que
///    coincidan con el resto de pantallas de la bola.
class FloatingBallRemoteControlScreen extends StatefulWidget {
  const FloatingBallRemoteControlScreen({super.key});

  @override
  State<FloatingBallRemoteControlScreen> createState() =>
      _FloatingBallRemoteControlScreenState();
}

class _FloatingBallRemoteControlScreenState
    extends State<FloatingBallRemoteControlScreen> {
  List<RemoteDevice> _devices = [];
  RemoteDevice? _selectedDevice;
  bool _connected = false;
  bool _connecting = false;
  bool _keyboardOpen = false;
  RemoteControlMode _mode = RemoteControlMode.cursor;
  double _sensitivity = 1.0;
  List<RemoteAppEntry> _appShortcuts = [];

  // HID: se refresca cada 3 s
  bool _hidConnected = false;
  String _hidState = 'IDLE';
  Timer? _hidPollTimer;

  // Banner de estado: mostrar/ocultar detalle de conexión
  bool _statusDetailExpanded = false;

  // D-pad long-press repeat
  Timer? _repeatTimer;

  // Teclado en tiempo real
  final FocusNode _keyboardFocusNode = FocusNode();
  final TextEditingController _textController = TextEditingController();

  StreamSubscription<bool>? _connectionSub;

  static const String _kSensitivityKey = 'remote_sensitivity';

  // Colores del estilo de la bola flotante
  Color _bgColor = const Color(0xDD111111);
  Color _contentColor = Colors.white;

  // -------------------------------------------------------------------------
  // Ciclo de vida
  // -------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    RemoteControlService.initialize();
    _connectionSub = RemoteControlService.connectionStream.listen((connected) {
      if (mounted) setState(() => _connected = connected);
      if (connected) {
        _startHidPolling();
      } else {
        _stopHidPolling();
      }
    });
    _loadDevices();
    _loadSensitivity();
    _loadStyle();
    _checkInitialConnection();
  }

  /// Detecta si ya había una conexión activa desde RemoteControlScreen y
  /// sincroniza el estado sin requerirle al usuario que vuelva a conectar.
  Future<void> _checkInitialConnection() async {
    final connected = await RemoteControlService.isConnected();
    if (!connected || !mounted) return;
    final address = await RemoteControlService.getConnectedAddress();
    if (!mounted) return;
    setState(() => _connected = true);
    _startHidPolling();
    if (address != null) {
      // Buscar el dispositivo en la lista (puede que aún esté cargando)
      var device = _devices.where((d) => d.address == address).firstOrNull;
      device ??= RemoteDevice(address: address, name: address);
      final shortcuts = await RemoteControlService.loadAppShortcuts(address);
      if (mounted) {
        setState(() {
          _selectedDevice = device;
          _appShortcuts = shortcuts;
        });
      }
    }
  }

  @override
  void dispose() {
    _connectionSub?.cancel();
    _hidPollTimer?.cancel();
    _repeatTimer?.cancel();
    _keyboardFocusNode.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _loadStyle() async {
    try {
      final bg = await FloatingBallService.getFullScreenBgColor();
      final content = await FloatingBallService.getFullScreenContentColor();
      if (mounted) {
        setState(() {
          _bgColor = Color(bg);
          _contentColor = Color(content);
        });
      }
    } catch (_) {}
  }

  // -------------------------------------------------------------------------
  // Cierre de overlay — NUNCA Navigator.pop(), siempre SystemNavigator.pop()
  // -------------------------------------------------------------------------

  void _close() => SystemNavigator.pop();

  Future<void> _disconnect() async {
    await RemoteControlService.disconnect();
    _stopHidPolling();
    if (mounted) setState(() { _connected = false; _selectedDevice = null; });
  }

  // -------------------------------------------------------------------------
  // HID polling
  // -------------------------------------------------------------------------

  void _startHidPolling() {
    _hidPollTimer?.cancel();
    _hidPollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _pollHidStatus(),
    );
    _pollHidStatus();
  }

  void _stopHidPolling() {
    _hidPollTimer?.cancel();
    _hidPollTimer = null;
    if (mounted) setState(() { _hidConnected = false; _hidState = 'IDLE'; });
  }

  Future<void> _pollHidStatus() async {
    if (!_connected) return;
    final status = await RemoteControlService.hidStatus();
    if (mounted) {
      setState(() {
        _hidConnected = status['connected'] == true;
        _hidState = (status['state'] ?? 'IDLE').toString();
      });
    }
  }

  // -------------------------------------------------------------------------
  // Carga datos
  // -------------------------------------------------------------------------

  Future<void> _loadSensitivity() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getDouble(_kSensitivityKey) ?? 1.0;
    if (mounted) setState(() => _sensitivity = saved.clamp(0.5, 5.0));
  }

  Future<void> _saveSensitivity(double v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kSensitivityKey, v);
  }

  Future<void> _loadDevices() async {
    try {
      final devices = await RemoteControlService.getBondedDevices();
      if (mounted) setState(() => _devices = devices);
    } catch (_) {}
  }

  Future<void> _connect(RemoteDevice device) async {
    setState(() {
      _selectedDevice = device;
      _connecting = true;
    });
    try {
      await RemoteControlService.connect(device.address);
      await RemoteControlService.sendMode(_mode);
      await RemoteControlService.sendSensitivity(_sensitivity);
      final saved = await RemoteControlService.loadAppShortcuts(device.address);
      if (mounted) setState(() => _appShortcuts = saved);
      _startHidPolling();
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _openAppsScreen() async {
    final device = _selectedDevice;
    if (device == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RemoteAppsScreen(
          deviceAddress: device.address,
          deviceName: device.name.isNotEmpty ? device.name : device.address,
        ),
      ),
    );
    final saved = await RemoteControlService.loadAppShortcuts(device.address);
    if (mounted) setState(() => _appShortcuts = saved);
  }

  void _toggleMode() {
    setState(() {
      _mode = _mode == RemoteControlMode.cursor
          ? RemoteControlMode.dpad
          : RemoteControlMode.cursor;
    });
    RemoteControlService.sendMode(_mode);
  }

  void _toggleKeyboard() {
    final open = !_keyboardOpen;
    setState(() => _keyboardOpen = open);
    if (open) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _keyboardFocusNode.requestFocus();
      });
    } else {
      _keyboardFocusNode.unfocus();
      _textController.clear();
    }
  }

  // -------------------------------------------------------------------------
  // D-pad long-press repeat
  // -------------------------------------------------------------------------

  void _startRepeat(String key) {
    RemoteControlService.sendKey(key);
    _repeatTimer?.cancel();
    _repeatTimer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      RemoteControlService.sendKey(key);
    });
  }

  void _stopRepeat() {
    _repeatTimer?.cancel();
    _repeatTimer = null;
  }

  void _onKeyboardChanged(String newText) {
    RemoteControlService.sendSetText(newText);
  }

  // -------------------------------------------------------------------------
  // Build principal
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // PopScope garantiza que el botón "atrás" del sistema finalice la Activity
    // (vuelve a la app previa) en vez de hacer pop a EmisorScreen.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: _bgColor,
        appBar: AppBar(
          backgroundColor: _bgColor.withValues(alpha: 0.95),
          foregroundColor: _contentColor,
          leading: IconButton(
            icon: Icon(Icons.close, color: _contentColor),
            tooltip: 'Cerrar',
            onPressed: _close,
          ),
          title: PopupMenuButton<Object>(
            tooltip: 'Seleccionar receptor',
            onSelected: (value) {
              if (value == 'disconnect') {
                _disconnect();
              } else if (value is RemoteDevice) {
                _connect(value);
              }
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    _titleLabel,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _contentColor,
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                Icon(Icons.arrow_drop_down, size: 20, color: _contentColor),
              ],
            ),
            itemBuilder: (context) {
              final items = <PopupMenuEntry<Object>>[];
              if (_devices.isEmpty) {
                items.add(const PopupMenuItem(
                  enabled: false,
                  child: Text('Sin dispositivos emparejados'),
                ));
              } else {
                items.addAll(_devices.map((d) => PopupMenuItem<Object>(
                  value: d,
                  child: Text(d.name.isNotEmpty ? d.name : d.address),
                )));
              }
              if (_connected) {
                items.add(const PopupMenuDivider());
                items.add(PopupMenuItem<Object>(
                  value: 'disconnect',
                  child: Row(
                    children: [
                      Icon(Icons.bluetooth_disabled,
                          size: 18, color: Colors.red[400]),
                      const SizedBox(width: 8),
                      Text('Desconectar',
                          style: TextStyle(color: Colors.red[400])),
                    ],
                  ),
                ));
              }
              return items;
            },
          ),
          actions: [
            IconButton(
              tooltip: _mode == RemoteControlMode.cursor
                  ? 'Cambiar a D-pad (TV)'
                  : 'Cambiar a cursor',
              icon: Icon(
                _mode == RemoteControlMode.cursor
                    ? Icons.mouse
                    : Icons.gamepad,
                color: _contentColor,
              ),
              onPressed: _connected ? _toggleMode : null,
            ),
            IconButton(
              tooltip: 'Apps del receptor',
              icon: Icon(Icons.apps, color: _contentColor),
              onPressed: _connected ? _openAppsScreen : null,
            ),
            // DEBUG: No eliminar — diagnóstico de errores del receptor.
            // IconButton(
            //   tooltip: 'Debug receptor',
            //   icon: Icon(Icons.bug_report_outlined, color: _contentColor),
            //   onPressed: () => Navigator.push(context,
            //       MaterialPageRoute(builder: (_) => const RemoteDebugScreen())),
            // ),
          ],
        ),
        body: Column(
          children: [
            _buildStatusBar(),
            Expanded(
              child: _mode == RemoteControlMode.cursor
                  ? _buildCursorView()
                  : _buildDpadView(),
            ),
            if (_keyboardOpen) _buildKeyboardPanel(),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Barra de estado
  // -------------------------------------------------------------------------

  Widget _buildStatusBar() {
    Color color;
    String mainLabel;
    String? detailLabel;

    if (_connecting) {
      mainLabel = 'Conectando a ${_selectedDevice?.name ?? ''}…';
      color = Colors.orange;
    } else if (_connected) {
      final deviceName = _selectedDevice?.name.isNotEmpty == true
          ? _selectedDevice!.name
          : (_selectedDevice?.address ?? '');
      mainLabel = 'Conectado a $deviceName';
      color = Colors.green;
      final modeLabel = _mode == RemoteControlMode.cursor ? 'Cursor' : 'D-pad';
      final hidLabel = _hidConnected ? 'HID activo' : 'HID: $_hidState · RFCOMM';
      detailLabel = 'Modo: $modeLabel · $hidLabel';
    } else {
      mainLabel = 'Sin conexión — toca el título para elegir un dispositivo';
      color = _contentColor.withValues(alpha: 0.5);
    }

    return GestureDetector(
      onTap: detailLabel != null
          ? () => setState(() => _statusDetailExpanded = !_statusDetailExpanded)
          : null,
      child: Container(
        width: double.infinity,
        color: color.withValues(alpha: 0.15),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (detailLabel != null) ...[
                  Icon(
                    _statusDetailExpanded ? Icons.info : Icons.info_outline,
                    size: 14,
                    color: color,
                  ),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    mainLabel,
                    style: TextStyle(color: color, fontSize: 12),
                  ),
                ),
              ],
            ),
            if (_statusDetailExpanded && detailLabel != null) ...[
              const SizedBox(height: 4),
              Text(
                detailLabel,
                style: TextStyle(
                  color: color.withValues(alpha: 0.8),
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String get _titleLabel {
    if (_connecting) return 'Conectando…';
    if (_connected && _selectedDevice != null) {
      final name = _selectedDevice!.name;
      return name.isNotEmpty ? name : _selectedDevice!.address;
    }
    return 'Control remoto';
  }

  // -------------------------------------------------------------------------
  // Modo cursor (touchpad)
  // -------------------------------------------------------------------------

  Widget _buildCursorView() {
    return LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxHeight < 280;
      return Column(
        children: [
          _buildSensitivitySlider(compact: compact),
          Expanded(flex: 3, child: _buildTouchpad()),
          Expanded(
            flex: 1,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildClickButtonsRow(),
                  _buildNavButtonsRow(),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildTouchpad() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onScaleStart: (_) {},
      onScaleUpdate: (details) {
        if (!_connected) return;
        if (details.pointerCount >= 2) {
          RemoteControlService.sendScroll(
            details.focalPointDelta.dx,
            details.focalPointDelta.dy,
          );
        } else {
          RemoteControlService.sendMove(
            details.focalPointDelta.dx * _sensitivity,
            details.focalPointDelta.dy * _sensitivity,
          );
        }
      },
      onTap: _connected ? () => RemoteControlService.sendTap() : null,
      onDoubleTap: _connected ? () => RemoteControlService.sendDoubleTap() : null,
      onLongPress:
          _connected ? () => RemoteControlService.sendTap(rightButton: true) : null,
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _contentColor.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _contentColor.withValues(alpha: 0.2)),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.touch_app, size: 48, color: _contentColor.withValues(alpha: 0.4)),
              const SizedBox(height: 8),
              Text(
                '1 dedo = mover  ·  2 dedos = scroll',
                style: TextStyle(
                    color: _contentColor.withValues(alpha: 0.4), fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClickButtonsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _connected ? () => RemoteControlService.sendTap() : null,
              style: OutlinedButton.styleFrom(foregroundColor: _contentColor),
              child: const Text('Click izq.'),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: _keyboardOpen ? 'Cerrar teclado' : 'Teclado',
            icon: Icon(
              _keyboardOpen ? Icons.keyboard_hide : Icons.keyboard,
              color: _keyboardOpen ? Colors.blue[300] : _contentColor,
            ),
            onPressed: _connected ? _toggleKeyboard : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: _connected
                  ? () => RemoteControlService.sendTap(rightButton: true)
                  : null,
              style: OutlinedButton.styleFrom(foregroundColor: _contentColor),
              child: const Text('Click der.'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSensitivitySlider({bool compact = false}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, compact ? 0 : 4, 16, 0),
      child: Row(
        children: [
          Icon(Icons.speed, size: 18, color: _contentColor),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: compact ? 2.0 : null,
                activeTrackColor: _contentColor.withValues(alpha: 0.8),
                thumbColor: _contentColor,
                inactiveTrackColor: _contentColor.withValues(alpha: 0.3),
              ),
              child: Slider(
                value: _sensitivity,
                min: 0.5,
                max: 5.0,
                divisions: 45,
                label: 'x${_sensitivity.toStringAsFixed(1)}',
                onChanged: (v) => setState(() => _sensitivity = v),
                onChangeEnd: (v) {
                  _saveSensitivity(v);
                  RemoteControlService.sendSensitivity(v);
                },
              ),
            ),
          ),
          SizedBox(
            width: 36,
            child: Text(
              'x${_sensitivity.toStringAsFixed(1)}',
              style: TextStyle(fontSize: 12, color: _contentColor),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Modo D-pad (TV)
  // -------------------------------------------------------------------------

  Widget _buildDpadView() {
    return LayoutBuilder(builder: (context, constraints) {
      const bottomRowsHeight = 96.0;
      const minArrowsHeight = 80.0;
      final availableForApps = constraints.maxHeight - minArrowsHeight - bottomRowsHeight;
      final compact = availableForApps < 100;
      final rows = compact ? 2 : 3;
      final rowHeight = compact ? 32.0 : 44.0;

      return Column(
        children: [
          if (_appShortcuts.isNotEmpty && !compact) ...[
            _buildAppShortcutsGrid(rows: rows, rowHeight: rowHeight),
            const SizedBox(height: 4),
          ],
          Expanded(child: _buildDpadWithPopup(showPopup: compact)),
          _buildVolumeRow(),
          _buildNavButtonsRow(),
        ],
      );
    });
  }

  Widget _buildAppShortcutsGrid({int rows = 3, double rowHeight = 44.0}) {
    const mainExtent = 110.0;
    const spacing = 6.0;
    final totalHeight = rows * rowHeight + (rows - 1) * spacing;
    final items = _appShortcuts;
    final numCols = (items.length + rows - 1) ~/ rows;

    final transposed = List<RemoteAppEntry?>.generate(rows * numCols, (j) {
      final row = j % rows;
      final col = j ~/ rows;
      final idx = row * numCols + col;
      return idx < items.length ? items[idx] : null;
    });

    return LayoutBuilder(builder: (context, constraints) {
      final contentWidth = numCols * (mainExtent + spacing) - spacing;
      final padH = ((constraints.maxWidth - contentWidth) / 2)
          .clamp(0.0, constraints.maxWidth / 2);

      return SizedBox(
        height: totalHeight,
        child: GridView.builder(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: padH),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: rows,
            mainAxisExtent: mainExtent,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
          ),
          itemCount: transposed.length,
          itemBuilder: (context, i) {
            final app = transposed[i];
            if (app == null) return const SizedBox.shrink();
            return OutlinedButton(
              onPressed: _connected
                  ? () => RemoteControlService.sendLaunchApp(app.packageName)
                  : null,
              style: OutlinedButton.styleFrom(
                shape: const StadiumBorder(),
                foregroundColor: _contentColor,
                side: BorderSide(color: _contentColor.withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                textStyle: TextStyle(fontSize: rowHeight < 44 ? 10 : 12),
              ),
              child: Text(
                app.label,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
                textAlign: TextAlign.center,
              ),
            );
          },
        ),
      );
    });
  }

  Widget _buildDpadWithPopup({bool showPopup = false}) {
    return Stack(
      children: [
        _buildDpadArrows(),
        if (_appShortcuts.isNotEmpty && showPopup)
          Positioned(
            top: 4,
            left: 4,
            child: _buildAppsPopupButton(),
          ),
      ],
    );
  }

  Widget _buildAppsPopupButton() {
    final items = _appShortcuts;
    const numCols = 3;
    final numRows = (items.length / numCols).ceil();

    final List<PopupMenuEntry<RemoteAppEntry>> entries = [];
    for (var r = 0; r < numRows; r++) {
      final rowItems = <RemoteAppEntry>[];
      for (var c = 0; c < numCols; c++) {
        final idx = r * numCols + c;
        if (idx < items.length) rowItems.add(items[idx]);
      }
      if (rowItems.isEmpty) continue;
      entries.add(PopupMenuItem<RemoteAppEntry>(
        enabled: false,
        padding: EdgeInsets.zero,
        height: 40,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            ...rowItems.map((app) => Expanded(
                  child: InkWell(
                    onTap: _connected
                        ? () {
                            RemoteControlService.sendLaunchApp(app.packageName);
                            Navigator.pop(context);
                          }
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 6),
                      child: Text(
                        app.label,
                        style: const TextStyle(fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                )),
            ...List.generate(
                numCols - rowItems.length,
                (_) => const Expanded(child: SizedBox())),
          ],
        ),
      ));
      if (r < numRows - 1) entries.add(const PopupMenuDivider(height: 1));
    }

    return PopupMenuButton<RemoteAppEntry>(
      tooltip: 'Apps',
      onSelected: (app) {
        if (_connected) RemoteControlService.sendLaunchApp(app.packageName);
      },
      itemBuilder: (_) => entries,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: _bgColor.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _contentColor.withValues(alpha: 0.3)),
        ),
        child: Icon(
          Icons.grid_view_rounded,
          size: 18,
          color: _connected ? Colors.blue[300] : _contentColor.withValues(alpha: 0.4),
        ),
      ),
    );
  }

  Widget _buildDpadArrows() {
    return LayoutBuilder(builder: (context, constraints) {
      final minDim = min(constraints.maxWidth, constraints.maxHeight);
      final arrowSize = (minDim / 3.5).clamp(40.0, 100.0);
      final centerSize = (arrowSize * 0.9).clamp(36.0, 90.0);

      return Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _dpadArrowBtn(Icons.keyboard_arrow_up, 'dpad_up', arrowSize),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _dpadArrowBtn(Icons.keyboard_arrow_left, 'dpad_left', arrowSize),
              _dpadCenterBtn(centerSize),
              _dpadArrowBtn(Icons.keyboard_arrow_right, 'dpad_right', arrowSize),
            ],
          ),
          _dpadArrowBtn(Icons.keyboard_arrow_down, 'dpad_down', arrowSize),
        ],
      );
    });
  }

  Widget _dpadArrowBtn(IconData icon, String key, double size) {
    final color = _connected ? _contentColor : _contentColor.withValues(alpha: 0.35);
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _connected ? (_) => _startRepeat(key) : null,
      onPointerUp: (_) => _stopRepeat(),
      onPointerCancel: (_) => _stopRepeat(),
      child: Container(
        padding: EdgeInsets.all(size * 0.12),
        child: Icon(icon, size: size, color: color),
      ),
    );
  }

  Widget _dpadCenterBtn(double size) {
    final color = _connected ? _contentColor : _contentColor.withValues(alpha: 0.35);
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _connected
          ? (_) => RemoteControlService.sendKey('dpad_center')
          : null,
      child: Container(
        padding: EdgeInsets.all(size * 0.12),
        child: Icon(Icons.radio_button_checked, size: size, color: color),
      ),
    );
  }

  Widget _buildVolumeRow() {
    final fgColor = _contentColor;
    final style = OutlinedButton.styleFrom(
      foregroundColor: fgColor,
      side: BorderSide(color: fgColor.withValues(alpha: 0.4)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      minimumSize: const Size(0, 40),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed:
                  _connected ? () => RemoteControlService.sendVolumeDown() : null,
              icon: const Icon(Icons.volume_down, size: 18),
              label: const Text('Vol −'),
              style: style,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: _keyboardOpen ? 'Cerrar teclado' : 'Teclado',
            icon: Icon(
              _keyboardOpen ? Icons.keyboard_hide : Icons.keyboard,
              color: _keyboardOpen ? Colors.blue[300] : _contentColor,
            ),
            onPressed: _connected ? _toggleKeyboard : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed:
                  _connected ? () => RemoteControlService.sendVolumeUp() : null,
              icon: const Icon(Icons.volume_up, size: 18),
              label: const Text('Vol +'),
              style: style,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavButtonsRow() {
    final style = OutlinedButton.styleFrom(
      foregroundColor: _contentColor,
      side: BorderSide(color: _contentColor.withValues(alpha: 0.4)),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      minimumSize: const Size(0, 40),
      textStyle: const TextStyle(fontSize: 12),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _connected ? () => RemoteControlService.sendBack() : null,
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text('Atrás', overflow: TextOverflow.ellipsis),
              style: style,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _connected ? () => RemoteControlService.sendHome() : null,
              icon: const Icon(Icons.home, size: 16),
              label: const Text('Inicio', overflow: TextOverflow.ellipsis),
              style: style,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: OutlinedButton.icon(
              onPressed:
                  _connected ? () => RemoteControlService.sendRecents() : null,
              icon: const Icon(Icons.apps, size: 16),
              label: const Text('Recientes', overflow: TextOverflow.ellipsis),
              style: style,
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Teclado en tiempo real
  // -------------------------------------------------------------------------

  Widget _buildKeyboardPanel() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      decoration: BoxDecoration(
        color: _bgColor.withValues(alpha: 0.95),
        border: Border(
            top: BorderSide(color: _contentColor.withValues(alpha: 0.2))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.keyboard_alt_outlined,
                  size: 16, color: _contentColor.withValues(alpha: 0.5)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Escribe con el teclado del teléfono → se envía en tiempo real',
                  style: TextStyle(
                      fontSize: 11,
                      color: _contentColor.withValues(alpha: 0.5)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: Icon(Icons.close,
                    size: 18, color: _contentColor),
                visualDensity: VisualDensity.compact,
                onPressed: _toggleKeyboard,
              ),
            ],
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _textController,
            focusNode: _keyboardFocusNode,
            style: TextStyle(color: _contentColor),
            decoration: InputDecoration(
              hintText: 'Toca aquí para activar el teclado…',
              hintStyle: TextStyle(color: _contentColor.withValues(alpha: 0.4)),
              border: OutlineInputBorder(
                borderSide: BorderSide(
                    color: _contentColor.withValues(alpha: 0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(
                    color: _contentColor.withValues(alpha: 0.3)),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              isDense: true,
            ),
            textInputAction: TextInputAction.send,
            onChanged: _onKeyboardChanged,
            onSubmitted: (value) {
              RemoteControlService.sendKey('enter');
              _textController.clear();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _keyboardFocusNode.requestFocus();
              });
            },
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
