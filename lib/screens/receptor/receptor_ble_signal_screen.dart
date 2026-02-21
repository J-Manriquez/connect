import 'package:flutter/material.dart';
import 'package:connect/services/ble_service.dart';
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';

class ReceptorBleSignalScreen extends StatefulWidget {
  const ReceptorBleSignalScreen({super.key});
  @override
  State<ReceptorBleSignalScreen> createState() => _ReceptorBleSignalScreenState();
}

class _ReceptorBleSignalScreenState extends State<ReceptorBleSignalScreen> {
  String _address = '';
  String _name = '';
  bool _busy = false;
  bool _serverRunning = false;
  int _connectedCount = 0;
  String? _lastPeerName;
  String? _lastPeerAddress;
  final List<String> _logs = [];
  StreamSubscription? _sub;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _loadInfo();
    _refreshServerStatus();
    _statusTimer = Timer.periodic(const Duration(seconds: 2), (_) => _refreshServerStatus());
    _sub = BleService.logStream.listen((e) {
      final ts = DateTime.fromMillisecondsSinceEpoch((e['timestamp'] as int?) ?? DateTime.now().millisecondsSinceEpoch).toIso8601String();
      final src = e['source']?.toString() ?? 'unknown';
      final ev = e['event']?.toString() ?? 'event';
      final pretty = const JsonEncoder.withIndent(' ').convert(e);
      final line = '[$ts][$src] $ev $pretty';
      _logs.add(line);
      if (mounted) setState(() {});
    });
  }

  Future<void> _refreshServerStatus() async {
    try {
      final status = await BleService.getBtServerStatus();
      if (!mounted) return;
      setState(() {
        _serverRunning = status['running'] == true;
        _connectedCount = (status['connectedCount'] as num?)?.toInt() ?? 0;
        _lastPeerName = status['lastPeerName']?.toString();
        _lastPeerAddress = status['lastPeerAddress']?.toString();
      });
    } catch (_) {
    }
  }

  Future<void> _loadInfo() async {
    final info = await BleService.getAdapterInfo();
    setState(() {
      _address = info['address'] ?? '';
      _name = info['name'] ?? '';
    });
    try {
      final env = await BleService.getBleEnv();
      final enabled = env['enabled'];
      final hasScanPerm = env['hasScanPerm'];
      final hasConnectPerm = env['hasConnectPerm'];
      final hasFineLocation = env['hasFineLocation'];
      final locationEnabled = env['locationEnabled'];
      _logs.add('[${DateTime.now().toIso8601String()}][env] enabled=$enabled scanPerm=$hasScanPerm connectPerm=$hasConnectPerm fineLocation=$hasFineLocation locationEnabled=$locationEnabled');
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _startServer() async {
    setState(() { _busy = true; });
    _logs.add('[${DateTime.now().toIso8601String()}][ui] start_bt_server');
    await BleService.requestPermissions();
    await BleService.startBtServer();
    await _refreshServerStatus();
    if (mounted) setState(() { _busy = false; });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Receptor Bluetooth iniciado')),
      );
    }
  }

  Future<void> _makeDiscoverable() async {
    setState(() { _busy = true; });
    _logs.add('[${DateTime.now().toIso8601String()}][ui] make_discoverable');
    await BleService.requestPermissions();
    await BleService.makeDiscoverable(seconds: 300);
    await _refreshServerStatus();
    if (mounted) setState(() { _busy = false; });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Visibilidad solicitada (5 min)')),
      );
    }
  }

  Future<void> _saveAndShareLogs() async {
    try {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/ble_receptor_logs_$ts.txt');
      final header = 'Nombre: ${_name.isEmpty ? 'Desconocido' : _name}\nDirección: ${_address.isEmpty ? 'No disponible' : _address}\n';
      final body = _logs.join('\n');
      await file.writeAsString('$header\n$body');
      await BleService.shareLogFile(file.path);
    } catch (_) {}
  }

  @override
  void dispose() {
    _sub?.cancel();
    _statusTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connectionLabel = _connectedCount > 0 ? 'Conexión activa con un emisor' : 'Sin conexión activa';
    final connectionDetail = _connectedCount > 0
        ? 'Emisor: ${(_lastPeerName?.isNotEmpty == true) ? _lastPeerName : 'Desconocido'} (${(_lastPeerAddress?.isNotEmpty == true) ? _lastPeerAddress : 'No disponible'})'
        : (_serverRunning ? 'Receptor iniciado, esperando conexión' : 'Receptor no iniciado');

    return Scaffold(
      appBar: AppBar(title: const Text('Conexión Bluetooth')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(connectionLabel, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(connectionDetail),
            const SizedBox(height: 16),
            const Text('Identificador del dispositivo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Nombre: ${_name.isEmpty ? 'Desconocido' : _name}'),
            const SizedBox(height: 4),
            Text('Dirección: ${_address.isEmpty ? 'No disponible' : _address}'),
            const SizedBox(height: 12),
            const Text(
              'Para vincular por primera vez: activa Bluetooth, pulsa "Hacer visible" y empareja desde el teléfono.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(8),
                child: ListView.builder(
                  itemCount: _logs.length,
                  itemBuilder: (context, i) {
                    return Text(_logs[i], style: const TextStyle(fontSize: 12));
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _busy ? null : _startServer,
                    child: const Text('Iniciar como receptor'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _busy ? null : _makeDiscoverable,
                    child: const Text('Hacer visible'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _saveAndShareLogs,
                child: const Text('Guardar y compartir logs'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
