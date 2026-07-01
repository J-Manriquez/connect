import 'dart:async';
import 'dart:math' show min;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/remote_control_service.dart';
import '../../theme_colors.dart';
import 'remote_apps_screen.dart';
// ignore: unused_import — RemoteDebugScreen se usa desde el icono de debug
// (actualmente oculto) para detectar errores del receptor. No eliminar.
import 'remote_debug_screen.dart';

class RemoteControlScreen extends StatefulWidget {
  const RemoteControlScreen({super.key});

  @override
  State<RemoteControlScreen> createState() => _RemoteControlScreenState();
}

class _RemoteControlScreenState extends State<RemoteControlScreen> {
  List<RemoteDevice> _devices = [];
  RemoteDevice? _selectedDevice;
  bool _connected = false;
  bool _connecting = false;
  bool _keyboardOpen = false;
  RemoteControlMode _mode = RemoteControlMode.cursor;
  double _sensitivity = 1.0;
  List<RemoteAppEntry> _appShortcuts = [];

  // HID: se refresca cada 3 s para mostrar estado en la barra
  bool _hidConnected = false;
  String _hidState = 'IDLE';
  Timer? _hidPollTimer;

  // Banner de estado: mostrar/ocultar detalle de conexión
  bool _statusDetailExpanded = false;

  // D-pad long-press repeat (mantener pulsado = enviar tecla repetidamente)
  Timer? _repeatTimer;

  // Teclado en tiempo real
  final FocusNode _keyboardFocusNode = FocusNode();
  final TextEditingController _textController = TextEditingController();

  StreamSubscription<bool>? _connectionSub;

  static const String _kSensitivityKey = 'remote_sensitivity';

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

  Future<void> _disconnect() async {
    await RemoteControlService.disconnect();
    _stopHidPolling();
    if (mounted) setState(() { _connected = false; _selectedDevice = null; });
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

  // Usa Listener (pointer events) en vez de GestureDetector para evitar el
  // arena de gestos que en Android 8 causa dobles toques o direcciones erróneas.
  void _startRepeatPointer(String key) {
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

  // -------------------------------------------------------------------------
  // Teclado en tiempo real
  // -------------------------------------------------------------------------

  void _onKeyboardChanged(String newText) {
    // Texto COMPLETO → ACTION_SET_TEXT en receptor. Evita bug de hint text en
    // Android 8+ y race conditions al tipear rápido.
    RemoteControlService.sendSetText(newText);
  }

  // -------------------------------------------------------------------------
  // Etiquetas
  // -------------------------------------------------------------------------

  String get _titleLabel {
    if (_connecting) return 'Conectando…';
    if (_connected && _selectedDevice != null) {
      final name = _selectedDevice!.name;
      return name.isNotEmpty ? name : _selectedDevice!.address;
    }
    return 'Control remoto';
  }

  // -------------------------------------------------------------------------
  // Build principal
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
                  style: Theme.of(context).appBarTheme.titleTextStyle ??
                      const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 2),
              const Icon(Icons.arrow_drop_down, size: 20),
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
              _mode == RemoteControlMode.cursor ? Icons.mouse : Icons.gamepad,
            ),
            onPressed: _connected ? _toggleMode : null,
          ),
          IconButton(
            tooltip: 'Apps del receptor',
            icon: const Icon(Icons.apps),
            onPressed: _connected ? _openAppsScreen : null,
          ),
          // DEBUG: No eliminar — diagnóstico de errores del receptor.
          IconButton(
            tooltip: 'Debug receptor',
            icon: const Icon(Icons.bug_report_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RemoteDebugScreen()),
            ),
          ),
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
      color = Colors.grey;
    }

    return GestureDetector(
      onTap: detailLabel != null
          ? () => setState(() => _statusDetailExpanded = !_statusDetailExpanded)
          : null,
      child: Container(
        width: double.infinity,
        color: color.withValues(alpha: 0.12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (detailLabel != null) ...[
                  Icon(
                    _statusDetailExpanded
                        ? Icons.info
                        : Icons.info_outline,
                    size: 16,
                    color: color,
                  ),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(mainLabel, style: TextStyle(color: color)),
                ),
              ],
            ),
            if (_statusDetailExpanded && detailLabel != null) ...[
              const SizedBox(height: 4),
              Text(
                detailLabel,
                style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Modo cursor (touchpad)
  // -------------------------------------------------------------------------

  Widget _buildCursorView() {
    return LayoutBuilder(builder: (context, constraints) {
      // En pantallas pequeñas (smartwatch), reducir la altura del slider para
      // dar más espacio al touchpad.
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
      onDoubleTap:
          _connected ? () => RemoteControlService.sendDoubleTap() : null,
      onLongPress: _connected
          ? () => RemoteControlService.sendTap(rightButton: true)
          : null,
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: customColor[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: customColor[200]!),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.touch_app, size: 48, color: Colors.grey),
              SizedBox(height: 8),
              Text(
                '1 dedo = mover  ·  2 dedos = scroll',
                style: TextStyle(color: Colors.grey, fontSize: 12),
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
              onPressed:
                  _connected ? () => RemoteControlService.sendTap() : null,
              child: const Text('Click izq.'),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: _keyboardOpen ? 'Cerrar teclado' : 'Teclado',
            icon: Icon(
              _keyboardOpen ? Icons.keyboard_hide : Icons.keyboard,
              color: _keyboardOpen
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            onPressed: _connected ? _toggleKeyboard : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: _connected
                  ? () => RemoteControlService.sendTap(rightButton: true)
                  : null,
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
          const Icon(Icons.speed, size: 18),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                // En pantalla pequeña, slider más delgado para ahorrar altura
                trackHeight: compact ? 2.0 : null,
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
              style: const TextStyle(fontSize: 12),
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
      // Altura aproximada de los botones de navegación y volumen
      const bottomRowsHeight = 96.0;
      // Espacio mínimo reservado para las flechas del D-pad
      const minArrowsHeight = 80.0;
      // Altura disponible para el grid de apps: lo que queda después de flechas y botones
      final availableForApps = constraints.maxHeight - minArrowsHeight - bottomRowsHeight;

      // En pantallas pequeñas usar filas más compactas para que quepan
      final compact = availableForApps < 100;
      final rows = compact ? 2 : 3;
      final rowHeight = compact ? 32.0 : 44.0;

      return Column(
        children: [
          // En pantallas grandes: mostrar grid de apps sobre el D-pad
          // En pantallas pequeñas (smartwatch): el grid no cabe → popup en el D-pad
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

    // Transponer índices: GridView rellena por columna, queremos por fila.
    final transposed = List<RemoteAppEntry?>.generate(rows * numCols, (j) {
      final row = j % rows;
      final col = j ~/ rows;
      final idx = row * numCols + col;
      return idx < items.length ? items[idx] : null;
    });

    // Centrar horizontalmente: calcular el ancho real del contenido y aplicar
    // padding simétrico para que los items no queden pegados al borde izquierdo
    // cuando no llenan toda la pantalla.
    return LayoutBuilder(builder: (context, constraints) {
      final contentWidth = numCols * (mainExtent + spacing) - spacing;
      final padH = ((constraints.maxWidth - contentWidth) / 2).clamp(0.0, constraints.maxWidth / 2);

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
                side: BorderSide(color: customColor[300]!),
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

  /// D-pad con popup menú de apps en la esquina superior izquierda.
  /// [showPopup] solo es true en pantallas pequeñas (smartwatch), donde el
  /// grid de apps no cabe y el popup es el único acceso rápido.
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

  /// Popup menú con todas las apps seleccionadas, en 3 columnas orden fila.
  Widget _buildAppsPopupButton() {
    final items = _appShortcuts;
    const numCols = 3;
    final numRows = (items.length / numCols).ceil();

    // Construir items en orden por fila usando transposición de GridView
    final List<PopupMenuEntry<RemoteAppEntry>> entries = [];
    // Agrupar en filas de numCols
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
          children: rowItems.map((app) => Expanded(
            child: InkWell(
              onTap: _connected
                  ? () {
                      RemoteControlService.sendLaunchApp(app.packageName);
                      Navigator.pop(context);
                    }
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Text(
                  app.label,
                  style: const TextStyle(fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          )).toList()
          ..addAll(List.generate(numCols - rowItems.length,
              (_) => const Expanded(child: SizedBox()))),
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
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: customColor[200]!),
        ),
        child: Icon(
          Icons.grid_view_rounded,
          size: 18,
          color: _connected
              ? Theme.of(context).colorScheme.primary
              : Colors.grey,
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
    final color = _connected
        ? Theme.of(context).colorScheme.primary
        : Colors.grey;
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _connected ? (_) => _startRepeatPointer(key) : null,
      onPointerUp: (_) => _stopRepeat(),
      onPointerCancel: (_) => _stopRepeat(),
      child: Container(
        padding: EdgeInsets.all(size * 0.12),
        child: Icon(icon, size: size, color: color),
      ),
    );
  }

  Widget _dpadCenterBtn(double size) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _connected
          ? (_) => RemoteControlService.sendKey('dpad_center')
          : null,
      child: Container(
        padding: EdgeInsets.all(size * 0.12),
        child: Icon(
          Icons.radio_button_checked,
          size: size,
          color: _connected
              ? Theme.of(context).colorScheme.primary
              : Colors.grey,
        ),
      ),
    );
  }

  Widget _buildVolumeRow() {
    final style = OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      minimumSize: const Size(0, 40),
      side: BorderSide(color: customColor[300]!),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _connected
                  ? () => RemoteControlService.sendVolumeDown()
                  : null,
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
              color: _keyboardOpen
                  ? Theme.of(context).colorScheme.primary
                  : null,
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

  // -------------------------------------------------------------------------
  // Fila Atrás / Inicio / Recientes — común a ambos modos
  // -------------------------------------------------------------------------

  Widget _buildNavButtonsRow() {
    final style = OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      minimumSize: const Size(0, 40),
      textStyle: const TextStyle(fontSize: 12),
      side: BorderSide(color: customColor[300]!),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed:
                  _connected ? () => RemoteControlService.sendBack() : null,
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text('Atrás', overflow: TextOverflow.ellipsis),
              style: style,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: OutlinedButton.icon(
              onPressed:
                  _connected ? () => RemoteControlService.sendHome() : null,
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
  // Teclado en tiempo real — visible en ambos modos
  // -------------------------------------------------------------------------

  Widget _buildKeyboardPanel() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: customColor[200]!)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.keyboard_alt_outlined, size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Escribe con el teclado del teléfono → se envía en tiempo real',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                visualDensity: VisualDensity.compact,
                onPressed: _toggleKeyboard,
              ),
            ],
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _textController,
            focusNode: _keyboardFocusNode,
            decoration: const InputDecoration(
              hintText: 'Toca aquí para activar el teclado…',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
