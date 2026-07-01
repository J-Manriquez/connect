import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Dispositivo Bluetooth detectado (emparejado o por descubrimiento).
class RemoteDevice {
  final String address;
  final String name;

  RemoteDevice({required this.address, required this.name});

  factory RemoteDevice.fromMap(Map<dynamic, dynamic> map) {
    return RemoteDevice(
      address: (map['address'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
    );
  }
}

/// App lanzable reportada por el receptor (lista completa instalada en el
/// dispositivo controlado).
class RemoteAppEntry {
  final String packageName;
  final String label;

  RemoteAppEntry({required this.packageName, required this.label});

  factory RemoteAppEntry.fromMap(Map<dynamic, dynamic> map) {
    return RemoteAppEntry(
      packageName: (map['packageName'] ?? '').toString(),
      label: (map['label'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'packageName': packageName,
    'label': label,
  };

  factory RemoteAppEntry.fromJson(Map<String, dynamic> json) {
    return RemoteAppEntry(
      packageName: (json['packageName'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
    );
  }
}

/// Modos de control soportados por el receptor "connect remote control".
enum RemoteControlMode { cursor, dpad }

/// Puente Dart <-> Kotlin (`com.example.connect/remote_control`) para el
/// touchpad/teclado del control remoto. Aísla el throttling de los eventos
/// de movimiento para no saturar el socket RFCOMM con el receptor.
class RemoteControlService {
  static const MethodChannel _channel = MethodChannel(
    'com.example.connect/remote_control',
  );

  static final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();
  static Stream<bool> get connectionStream => _connectionController.stream;

  static final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();
  static Stream<Map<String, dynamic>> get messageStream =>
      _messageController.stream;

  static bool _initialized = false;

  /// Buffer circular de los últimos 500 debug_log del receptor. Permite que
  /// [RemoteDebugScreen] muestre logs recibidos antes de que se abra la pantalla.
  static final List<Map<String, dynamic>> _debugLogBuffer = [];
  static List<Map<String, dynamic>> get debugLogBuffer =>
      List.unmodifiable(_debugLogBuffer);

  static double _pendingDx = 0;
  static double _pendingDy = 0;
  static Timer? _moveThrottleTimer;
  static const Duration _moveInterval = Duration(milliseconds: 16); // ~60 Hz

  static void initialize() {
    if (_initialized) return;
    _initialized = true;
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onRemoteConnectionChanged':
          final connected = call.arguments == true;
          _connectionController.add(connected);
          break;
        case 'onRemoteMessage':
          try {
            final raw = call.arguments as String;
            final decoded = _decodeJson(raw);
            if (decoded != null) {
              _messageController.add(decoded);
              // Buffer + consola para debug_log del receptor.
              if (decoded['type'] == 'debug_log') {
                final src = decoded['source'] ?? '';
                final msg = decoded['message'] ?? '';
                // ignore: avoid_print
                print('[REMOTE][$src] $msg');
                _debugLogBuffer.add(decoded);
                if (_debugLogBuffer.length > 500) _debugLogBuffer.removeAt(0);
              }
            }
          } catch (_) {}
          break;
      }
    });
  }

  static Map<String, dynamic>? _decodeJson(String raw) {
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  static Future<List<RemoteDevice>> getBondedDevices() async {
    final res = await _channel.invokeMethod('getBondedDevices');
    final list = (res as List?) ?? [];
    return list
        .map((e) => RemoteDevice.fromMap(Map<dynamic, dynamic>.from(e as Map)))
        .toList();
  }

  static Future<void> startDiscovery() async {
    await _channel.invokeMethod('startDiscovery');
  }

  static Future<void> stopDiscovery() async {
    await _channel.invokeMethod('stopDiscovery');
  }

  static Future<bool> connect(String address) async {
    final res = await _channel.invokeMethod('connectRemote', {
      'address': address,
    });
    return res == true;
  }

  static Future<void> disconnect() async {
    await _channel.invokeMethod('disconnectRemote');
  }

  static Future<bool> isConnected() async {
    final res = await _channel.invokeMethod('isRemoteConnected');
    return res == true;
  }

  static Future<String?> getConnectedAddress() async {
    try {
      final res = await _channel.invokeMethod<String>('getConnectedAddress');
      return res?.isNotEmpty == true ? res : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _send(Map<String, dynamic> payload) async {
    try {
      await _channel.invokeMethod('sendRemote', payload);
    } catch (_) {}
  }

  /// Acumula los deltas del touchpad y los envía a ~60 Hz para no saturar
  /// el socket RFCOMM con un mensaje por cada frame de `onPanUpdate`.
  static void sendMove(double dx, double dy) {
    _pendingDx += dx;
    _pendingDy += dy;
    _moveThrottleTimer ??= Timer(_moveInterval, _flushMove);
  }

  static void _flushMove() {
    _moveThrottleTimer = null;
    if (_pendingDx == 0 && _pendingDy == 0) return;
    final dx = _pendingDx;
    final dy = _pendingDy;
    _pendingDx = 0;
    _pendingDy = 0;
    _send({
      'type': 'remote_input',
      'action': 'move',
      'dx': dx,
      'dy': dy,
      't': DateTime.now().millisecondsSinceEpoch,
    });
  }

  static Future<void> sendTap({bool rightButton = false}) {
    return _send({
      'type': 'remote_input',
      'action': 'tap',
      if (rightButton) 'button': 'right',
    });
  }

  static Future<void> sendDoubleTap() {
    return _send({'type': 'remote_input', 'action': 'double_tap'});
  }

  static Future<void> sendDragDown() {
    return _send({'type': 'remote_input', 'action': 'down'});
  }

  static Future<void> sendDragUp() {
    return _send({'type': 'remote_input', 'action': 'up'});
  }

  static Future<void> sendScroll(double dx, double dy) {
    return _send({
      'type': 'remote_input',
      'action': 'scroll',
      'dx': dx,
      'dy': dy,
    });
  }

  static Future<void> sendText(String value) {
    if (value.isEmpty) return Future.value();
    return _send({'type': 'text', 'value': value});
  }

  /// key: backspace|enter|space|tab|dpad_up|dpad_down|dpad_left|dpad_right|
  ///      dpad_center|home|back
  ///
  /// Para teclas dpad_*, intenta primero el canal HID nativo (BluetoothHidDevice,
  /// API 28+). El TV box recibe un KeyEvent real que YouTube y otras apps
  /// de leanback/RecyclerView atienden correctamente. Si HID no está conectado
  /// o la plataforma no lo soporta, cae al canal RFCOMM de siempre.
  static Future<void> sendKey(String key) async {
    if (key.startsWith('dpad_')) {
      try {
        final ok = await _channel.invokeMethod<bool>('hidSendDpad', {'key': key});
        if (ok == true) return;
      } catch (_) {}
    }
    return _send({'type': 'key', 'key': key});
  }

  static Future<void> sendMode(RemoteControlMode mode) {
    return _send({
      'type': 'config',
      'mode': mode == RemoteControlMode.dpad ? 'dpad' : 'cursor',
    });
  }

  static Future<void> sendSensitivity(double sensitivity) {
    return _send({'type': 'config', 'sensitivity': sensitivity});
  }

  static void dispose() {
    _moveThrottleTimer?.cancel();
    _moveThrottleTimer = null;
  }

  // ---------------------------------------------------------------------
  // Botones de navegación (home/back/recientes) y volumen
  // ---------------------------------------------------------------------

  static Future<void> sendHome() => sendKey('home');
  static Future<void> sendBack() => sendKey('back');
  static Future<void> sendRecents() => sendKey('recents');
  static Future<void> sendVolumeUp() => sendKey('volume_up');
  static Future<void> sendVolumeDown() => sendKey('volume_down');

  // ---------------------------------------------------------------------
  // Logs de depuración del receptor (reenviados por BT)
  // ---------------------------------------------------------------------

  /// Stream de mensajes debug_log enviados por el receptor vía RFCOMM.
  static Stream<Map<String, dynamic>> get debugLogStream =>
      messageStream.where((msg) => msg['type'] == 'debug_log');

  // ---------------------------------------------------------------------
  // Apps del receptor (accesos rápidos desde el D-pad)
  // ---------------------------------------------------------------------

  /// Stream de la respuesta `apps_list` del receptor, ya parseada a entradas.
  static Stream<List<RemoteAppEntry>> get appsListStream => messageStream
      .where((msg) => msg['type'] == 'apps_list')
      .map((msg) {
        final list = (msg['apps'] as List?) ?? [];
        return list
            .map((e) => RemoteAppEntry.fromMap(Map<dynamic, dynamic>.from(e as Map)))
            .toList();
      });

  static Future<void> requestAppsList() {
    return _send({'type': 'apps_list_request'});
  }

  static Future<void> sendLaunchApp(String packageName) {
    return _send({'type': 'launch_app', 'packageName': packageName});
  }

  /// Establece el texto COMPLETO del campo enfocado en el receptor.
  /// Usado por el teclado en tiempo real: evita el bug de hint text de
  /// Android 8+ y race conditions. El receptor usa ACTION_SET_TEXT directamente.
  static Future<void> sendSetText(String fullText) {
    return _send({'type': 'set_text', 'value': fullText});
  }

  /// Estado actual del perfil HID (BluetoothHidDevice) en el teléfono.
  /// Devuelve `{'supported': bool, 'connected': bool, 'state': String}`.
  static Future<Map<String, dynamic>> hidStatus() async {
    try {
      final res = await _channel.invokeMethod('hidStatus');
      return Map<String, dynamic>.from(res as Map);
    } catch (_) {
      return {'supported': false, 'connected': false, 'state': 'ERROR'};
    }
  }

  // ---------------------------------------------------------------------
  // Persistencia de accesos rápidos por dispositivo receptor
  // ---------------------------------------------------------------------

  static String _shortcutsPrefsKey(String deviceAddress) =>
      'remote_control_shortcuts_$deviceAddress';

  /// Guarda los accesos rápidos seleccionados para `deviceAddress`, junto
  /// con el nombre del dispositivo (para identificarlo al volver a listar),
  /// preservando el orden de selección.
  static Future<void> saveAppShortcuts(
    String deviceAddress,
    String deviceName,
    List<RemoteAppEntry> shortcuts,
  ) async {
    if (deviceAddress.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final payload = {
      'deviceName': deviceName,
      'apps': shortcuts.map((e) => e.toJson()).toList(),
    };
    await prefs.setString(_shortcutsPrefsKey(deviceAddress), jsonEncode(payload));
  }

  static Future<List<RemoteAppEntry>> loadAppShortcuts(String deviceAddress) async {
    if (deviceAddress.isEmpty) return [];
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_shortcutsPrefsKey(deviceAddress));
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final apps = (decoded['apps'] as List?) ?? [];
      return apps
          .map((e) => RemoteAppEntry.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
