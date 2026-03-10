import 'dart:async';
import 'package:flutter/services.dart';
import 'local_notification_service.dart';
import 'preferences_service.dart';
import 'receptor_service.dart';

class BleService {
  static const MethodChannel _channel = MethodChannel('com.example.connect/ble');
  static const MethodChannel _btHiveBridge = MethodChannel('com.example.connect/bt_hive_bridge');
  static final StreamController<Map<String, dynamic>> _logController = StreamController<Map<String, dynamic>>.broadcast();
  static Stream<Map<String, dynamic>> get logStream => _logController.stream;
  static final StreamController<Map<String, dynamic>> _scanResultsController = StreamController<Map<String, dynamic>>.broadcast();
  static Stream<Map<String, dynamic>> get scanResultsStream => _scanResultsController.stream;

  static void initialize() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onBleNotificationReceived') {
        final Map<String, dynamic> data = Map<String, dynamic>.from(call.arguments as Map);
        _logController.add({'source': 'flutter', 'event': 'notification_received', 'data': data, 'timestamp': DateTime.now().millisecondsSinceEpoch});
        try {
          final payload = Map<String, dynamic>.from(data);
          payload['id'] = (payload['id'] ?? payload['notificationId'] ?? DateTime.now().millisecondsSinceEpoch.toString()).toString();
          final id = payload['id'].toString();
          final pkg = (payload['packageName'] ?? '').toString();
          final title = (payload['title'] ?? '').toString();
          print('[ble_rx] enqueue start id=$id pkg=$pkg title="${title.length > 40 ? title.substring(0, 40) : title}"');
          try {
            await _btHiveBridge.invokeMethod('sendDebugLog', {
              'source': 'ble_rx',
              'message': 'enqueue_start id=$id pkg=$pkg title="${title.length > 60 ? title.substring(0, 60) : title}" keys=${payload.keys.length}',
            });
          } catch (_) {}
          await BtHiveStorageService.enqueueBtNotification(payload);
          await BtHiveSyncService.syncOutboxToFirebase();
          print('[ble_rx] enqueue+sync done id=$id');
          try {
            await _btHiveBridge.invokeMethod('sendDebugLog', {
              'source': 'ble_rx',
              'message': 'enqueue_sync_done id=$id',
            });
          } catch (_) {}
        } catch (_) {}
        await LocalNotificationService.showNotification(
          title: data['title'] ?? 'Nueva notificación',
          body: data['text'] ?? '',
          packageName: data['packageName'] ?? '',
          appName: data['appName'] ?? 'Desconocida',
          notificationId: data['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
          extras: data,
        );
      } else if (call.method == 'onBleScanResult') {
        final Map<String, dynamic> data = Map<String, dynamic>.from(call.arguments as Map);
        _scanResultsController.add(data);
        _logController.add({'source': 'client', 'event': 'scan_result', 'data': data, 'timestamp': DateTime.now().millisecondsSinceEpoch});
      } else if (call.method == 'onBlePeerFound') {
        final Map<String, dynamic> data = Map<String, dynamic>.from(call.arguments as Map);
        final address = data['address'] as String?;
        if (address != null && address.isNotEmpty) {
          await PreferencesService.saveBlePeerAddress(address);
        }
        _logController.add({'source': 'client', 'event': 'peer_found', 'data': data, 'timestamp': DateTime.now().millisecondsSinceEpoch});
      } else if (call.method == 'onBleLog') {
        final Map<String, dynamic> data = Map<String, dynamic>.from(call.arguments as Map);
        _logController.add(data);
      }
    });
  }

  static Future<bool> requestPermissions() async {
    final res = await _channel.invokeMethod('requestBlePermissions');
    return res == true;
  }

  static Future<bool> startGattServer() async {
    final res = await _channel.invokeMethod('startGattServer');
    return res == true;
  }

  static Future<bool> stopGattServer() async {
    final res = await _channel.invokeMethod('stopGattServer');
    return res == true;
  }

  static Future<bool> startGattClient() async {
    final res = await _channel.invokeMethod('startGattClient');
    return res == true;
  }

  static Future<bool> stopGattClient() async {
    final res = await _channel.invokeMethod('stopGattClient');
    return res == true;
  }

  static Future<bool> sendNotification(Map<String, dynamic> data) async {
    final res = await _channel.invokeMethod('sendNotification', data);
    return res == true;
  }

  static Future<bool> startBleScan() async {
    _logController.add({'source': 'flutter', 'event': 'startBleScan', 'timestamp': DateTime.now().millisecondsSinceEpoch});
    try {
      final env = await _channel.invokeMethod('getBleEnv');
      _logController.add({'source': 'env', 'event': 'ble_env', 'data': env, 'timestamp': DateTime.now().millisecondsSinceEpoch});
    } catch (e) {
      _logController.add({
        'source': 'flutter',
        'event': 'ble_env_error',
        'error': e.toString(),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    }
    final res = await _channel.invokeMethod('startBtDiscovery');
    return res == true;
  }

  static Future<Map<String, dynamic>> getBleEnv() async {
    final res = await _channel.invokeMethod('getBleEnv');
    return Map<String, dynamic>.from(res as Map);
  }

  static Future<bool> stopBleScan() async {
    _logController.add({'source': 'flutter', 'event': 'stopBleScan', 'timestamp': DateTime.now().millisecondsSinceEpoch});
    final res = await _channel.invokeMethod('stopBtDiscovery');
    return res == true;
  }

  static Future<bool> connectToPeer(String address) async {
    _logController.add({'source': 'flutter', 'event': 'connectToPeer', 'address': address, 'timestamp': DateTime.now().millisecondsSinceEpoch});
    final res = await _channel.invokeMethod('connectToPeer', { 'address': address });
    return res == true;
  }

  static Future<Map<String, String>> getAdapterInfo() async {
    final res = await _channel.invokeMethod('getAdapterInfo');
    return Map<String, String>.from(res as Map);
  }

  static Future<bool> openLocationSettings() async {
    final res = await _channel.invokeMethod('openLocationSettings');
    return res == true;
  }

  static Future<bool> sendConnectionPing() async {
    _logController.add({'source': 'flutter', 'event': 'sendConnectionPing', 'timestamp': DateTime.now().millisecondsSinceEpoch});
    final res = await _channel.invokeMethod('sendConnectionPing');
    return res == true;
  }

  static Future<List<Map<String, dynamic>>> getBondedDevices() async {
    final res = await _channel.invokeMethod('getBondedDevices');
    final list = (res as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    return list;
  }

  static Future<bool> startBtServer() async {
    final res = await _channel.invokeMethod('startBtServer');
    return res == true;
  }

  static Future<bool> stopBtServer() async {
    final res = await _channel.invokeMethod('stopBtServer');
    return res == true;
  }

  static Future<bool> makeDiscoverable({int seconds = 300}) async {
    final res = await _channel.invokeMethod('makeDiscoverable', {'seconds': seconds});
    return res == true;
  }

  static Future<Map<String, dynamic>> getBtServerStatus() async {
    final res = await _channel.invokeMethod('getBtServerStatus');
    return Map<String, dynamic>.from(res as Map);
  }

  static Future<Map<String, dynamic>?> getLastBtMediaState() async {
    final res = await _channel.invokeMethod('getLastBtMediaState');
    final map = Map<String, dynamic>.from(res as Map);
    final json = (map['json'] ?? '').toString();
    if (json.trim().isEmpty) return null;
    return map;
  }

  static Future<Map<String, dynamic>?> getLastLocalMediaState() async {
    final res = await _channel.invokeMethod('getLastLocalMediaState');
    final map = Map<String, dynamic>.from(res as Map);
    final json = (map['json'] ?? '').toString();
    if (json.trim().isEmpty) return null;
    return map;
  }

  static Future<bool> sendBtServerMessage(Map<String, dynamic> data) async {
    final res = await _channel.invokeMethod('sendBtServerMessage', data);
    return res == true;
  }

  static Future<bool> shareLogFile(String path, {String mime = 'text/plain', String package = 'com.whatsapp'}) async {
    final res = await _channel.invokeMethod('shareLogFile', { 'path': path, 'mime': mime, 'package': package });
    return res == true;
  }

  static Future<bool> updateWidget() async {
    final res = await _channel.invokeMethod('updateWidget');
    return res == true;
  }
}
