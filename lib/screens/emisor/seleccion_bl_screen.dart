import 'dart:async';

import 'package:flutter/material.dart';
import 'package:connect/services/ble_service.dart';
import 'package:connect/services/preferences_service.dart';

class BleDeviceSelectionScreen extends StatefulWidget {
  const BleDeviceSelectionScreen({super.key});
  @override
  State<BleDeviceSelectionScreen> createState() => _BleDeviceSelectionScreenState();
}

class _BleDeviceSelectionScreenState extends State<BleDeviceSelectionScreen> {
  final List<Map<String, dynamic>> _devices = [];
  bool _scanning = false;
  Timer? _noResultTimer;
  bool _locationEnabled = true;
  bool _loadedBonded = false;

  @override
  void initState() {
    super.initState();
    _startScan();
    _loadEnv();
    BleService.scanResultsStream.listen((data) {
        final addr = data['address'] as String? ?? '';
        if (addr.isEmpty) return;
        final index = _devices.indexWhere((d) => d['address'] == addr);
        if (index == -1) {
          _devices.add({
            'address': addr,
            'name': (data['name'] as String?) ?? '',
            'rssi': (data['rssi'] as int?) ?? 0,
            'ping': (data['ping'] as bool?) ?? false,
            'compatible': (data['compatible'] as bool?) ?? false,
          });
        } else {
          _devices[index]['name'] = (data['name'] as String?) ?? _devices[index]['name'];
          _devices[index]['rssi'] = (data['rssi'] as int?) ?? _devices[index]['rssi'];
          _devices[index]['ping'] = (data['ping'] as bool?) ?? _devices[index]['ping'];
          _devices[index]['compatible'] = (data['compatible'] as bool?) ?? _devices[index]['compatible'];
        }
      if (mounted) setState(() {});
    });
    BleService.logStream.listen((e) {
      final ts = DateTime.fromMillisecondsSinceEpoch((e['timestamp'] as int?) ?? DateTime.now().millisecondsSinceEpoch).toIso8601String();
      final src = e['source']?.toString() ?? 'unknown';
      final ev = e['event']?.toString() ?? 'event';
      final dataStr = e['data']?.toString() ?? '';
      debugPrint('[$ts][$src] $ev $dataStr');
    });
  }

  Future<void> _loadEnv() async {
    try {
      final env = await BleService.getBleEnv();
      setState(() {
        _locationEnabled = (env['locationEnabled'] as bool?) ?? true;
      });
    } catch (_) {}
  }

  Future<void> _startScan() async {
    await BleService.requestPermissions();
    setState(() { _scanning = true; });
    if (!_loadedBonded) {
      await _loadBondedDevices();
      _loadedBonded = true;
    }
    await BleService.startBleScan();
    debugPrint('[${DateTime.now().toIso8601String()}][ui] scan_started');
    await _loadEnv();
    _noResultTimer?.cancel();
    _noResultTimer = Timer(const Duration(seconds: 10), () {
      if (_devices.isEmpty) {
        debugPrint('[${DateTime.now().toIso8601String()}][ui] sin_dispositivos_tras_10s. Revisar: Bluetooth encendido, permisos concedidos, emparejar primero el receptor en ajustes de Bluetooth, y permitir visibilidad temporal en el receptor.');
      }
    });
  }

  Future<void> _loadBondedDevices() async {
    try {
      final bonded = await BleService.getBondedDevices();
      for (final d in bonded) {
        final addr = (d['address'] as String?) ?? '';
        if (addr.isEmpty) continue;
        if (_devices.any((e) => e['address'] == addr)) continue;
        _devices.add({
          'address': addr,
          'name': (d['name'] as String?) ?? '',
          'rssi': 0,
          'ping': false,
          'compatible': true,
          'paired': true,
        });
      }
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _stopScan() async {
    if (mounted) {
      setState(() {
        _scanning = false;
      });
    }
    await BleService.stopBleScan();
    debugPrint('[${DateTime.now().toIso8601String()}][ui] scan_stopped');
  }

  Future<void> _connect(String address) async {
    await PreferencesService.saveBlePeerAddress(address);
    await BleService.connectToPeer(address);
    await _stopScan();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Conectado a $address')),
      );
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    try {
      BleService.stopBleScan();
    } catch (_) {}
    _noResultTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Seleccionar dispositivo Bluetooth')),
      body: Column(
        children: [
          if (!_locationEnabled)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Ubicación deshabilitada. Actívala para mejorar el escaneo BLE.',
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      await BleService.openLocationSettings();
                      await Future.delayed(const Duration(seconds: 1));
                      await _loadEnv();
                    },
                    child: const Text('Abrir ajustes de ubicación'),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _scanning ? null : _startScan,
                    child: const Text('Escanear'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _scanning ? _stopScan : null,
                    child: const Text('Detener'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _devices.isEmpty
                ? Center(
                    child: Text(_scanning ? 'Buscando dispositivos...' : 'Sin dispositivos'),
                  )
                : ListView.separated(
                    itemCount: _devices.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final d = _devices[i];
                      final name = (d['name'] as String?)?.trim();
                      final addr = d['address'] as String;
                      final rssi = d['rssi'] as int;
                      final ping = d['ping'] as bool? ?? false;
                      final compatible = d['compatible'] as bool? ?? false;
                      final paired = d['paired'] as bool? ?? false;
                      return ListTile(
                        leading: const Icon(Icons.bluetooth),
                        title: Text(name?.isNotEmpty == true ? name! : 'Desconocido'),
                        subtitle: Text('${paired ? 'Vinculado' : 'Disponible'}${compatible ? '' : ' · No compatible'}${ping ? ' · Señal recibida' : ''} · $addr${rssi != 0 ? ' · RSSI $rssi' : ''}'),
                        trailing: ElevatedButton(
                          onPressed: () => _connect(addr),
                          child: const Text('Conectar'),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
