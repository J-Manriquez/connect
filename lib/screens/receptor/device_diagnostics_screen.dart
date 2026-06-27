import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DeviceDiagnosticsScreen extends StatefulWidget {
  const DeviceDiagnosticsScreen({super.key});

  @override
  State<DeviceDiagnosticsScreen> createState() =>
      _DeviceDiagnosticsScreenState();
}

class _DeviceDiagnosticsScreenState extends State<DeviceDiagnosticsScreen> {
  static const _channel =
      MethodChannel('com.example.connect/device_diagnostics');

  bool _loading = true;
  String _cpuInfo = '';
  String _memInfo = '';
  String _kernelVersion = '';
  Map<String, dynamic> _buildInfo = {};
  String _wifiIp = '';
  bool? _adbPortOpen;
  String _rootResult = '';
  bool _rootLoading = false;
  final List<_DevOpResult> _devOpResults = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    await Future.wait([
      _loadProcFiles(),
      _loadBuildInfo(),
      _loadNetworkAndAdb(),
    ]);
    setState(() => _loading = false);
  }

  Future<void> _loadProcFiles() async {
    try {
      final cpu = await File('/proc/cpuinfo').readAsString();
      setState(() => _cpuInfo = cpu.trim());
    } catch (e) {
      setState(() => _cpuInfo = 'Error: $e');
    }
    try {
      final mem = await File('/proc/meminfo').readAsString();
      setState(() => _memInfo = mem.trim());
    } catch (e) {
      setState(() => _memInfo = 'Error: $e');
    }
    try {
      final ver = await File('/proc/version').readAsString();
      setState(() => _kernelVersion = ver.trim());
    } catch (e) {
      setState(() => _kernelVersion = 'Error: $e');
    }
  }

  Future<void> _loadBuildInfo() async {
    try {
      final result = await _channel.invokeMethod<Map>('getAndroidBuildInfo');
      setState(() => _buildInfo = Map<String, dynamic>.from(result ?? {}));
    } catch (e) {
      setState(() => _buildInfo = {'error': '$e'});
    }
  }

  Future<void> _loadNetworkAndAdb() async {
    String ip = '';
    try {
      final interfaces = await NetworkInterface.list(
        includeLinkLocal: false,
        type: InternetAddressType.IPv4,
      );
      for (final iface in interfaces) {
        final name = iface.name.toLowerCase();
        if (name.contains('wlan') || name.contains('wifi') || name.contains('eth')) {
          for (final addr in iface.addresses) {
            if (!addr.isLoopback) {
              ip = addr.address;
              break;
            }
          }
        }
        if (ip.isNotEmpty) break;
      }
      if (ip.isEmpty && interfaces.isNotEmpty) {
        for (final iface in interfaces) {
          for (final addr in iface.addresses) {
            if (!addr.isLoopback) {
              ip = addr.address;
              break;
            }
          }
          if (ip.isNotEmpty) break;
        }
      }
    } catch (_) {}

    setState(() => _wifiIp = ip.isEmpty ? 'No disponible' : ip);

    if (ip.isNotEmpty) {
      try {
        final socket = await Socket.connect(ip, 5555,
            timeout: const Duration(seconds: 3));
        socket.destroy();
        setState(() => _adbPortOpen = true);
      } on SocketException {
        setState(() => _adbPortOpen = false);
      } catch (_) {
        setState(() => _adbPortOpen = false);
      }
    } else {
      setState(() => _adbPortOpen = null);
    }
  }

  Future<void> _tryRootEnableDeveloperOptions() async {
    setState(() {
      _rootLoading = true;
      _rootResult = '';
    });
    try {
      final result = await _channel.invokeMethod<String>(
          'tryRootEnableDeveloperOptions');
      setState(() => _rootResult = result ?? 'Sin respuesta');
    } catch (e) {
      setState(() => _rootResult = 'Error: $e');
    } finally {
      setState(() => _rootLoading = false);
    }
  }

  Future<void> _openDevOptions(String method) async {
    try {
      final result =
          await _channel.invokeMethod<String>('openDeveloperOptions', {'method': method});
      setState(() {
        _devOpResults.add(_DevOpResult(method: method, result: result ?? 'OK'));
      });
    } catch (e) {
      setState(() {
        _devOpResults.add(_DevOpResult(method: method, result: 'Error: $e'));
      });
    }
  }

  // ---- helpers de parseo ----

  String _parseCpuModel() {
    final lines = _cpuInfo.split('\n');
    for (final line in lines) {
      if (line.toLowerCase().startsWith('hardware') ||
          line.toLowerCase().startsWith('processor') ||
          line.toLowerCase().startsWith('model name')) {
        final parts = line.split(':');
        if (parts.length >= 2) return parts.sublist(1).join(':').trim();
      }
    }
    return 'No disponible';
  }

  int _countCpuCores() {
    return RegExp(r'^processor\s*:', multiLine: true, caseSensitive: false)
        .allMatches(_cpuInfo)
        .length;
  }

  String _parseMemValue(String key) {
    final match = RegExp(r'^' + RegExp.escape(key) + r'\s*:\s*(\d+)',
            multiLine: true, caseSensitive: false)
        .firstMatch(_memInfo);
    if (match == null) return 'N/A';
    final kb = int.tryParse(match.group(1) ?? '') ?? 0;
    return _kbToReadable(kb);
  }

  String _kbToReadable(int kb) {
    if (kb >= 1024 * 1024) return '${(kb / 1024 / 1024).toStringAsFixed(1)} GB';
    if (kb >= 1024) return '${(kb / 1024).toStringAsFixed(0)} MB';
    return '$kb KB';
  }

  // ---- widgets ----

  Widget _section(String title, Widget child) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const Divider(),
            child,
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w500, fontSize: 13)),
          ),
          Expanded(
            child: SelectableText(value,
                style:
                    const TextStyle(fontSize: 13, color: Colors.black87)),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String label, bool? ok) {
    final color = ok == null
        ? Colors.grey
        : ok
            ? Colors.green
            : Colors.red;
    final icon = ok == null
        ? Icons.help_outline
        : ok
            ? Icons.check_circle
            : Icons.cancel;
    return Chip(
      avatar: Icon(icon, color: color, size: 18),
      label: Text(label, style: TextStyle(color: color, fontSize: 13)),
      backgroundColor: color.withOpacity(0.1),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnóstico del dispositivo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAll,
            tooltip: 'Recargar',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(8),
              children: [
                // ── CPU ──
                _section(
                  'Procesador (fuente: /proc/cpuinfo)',
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _row('Modelo', _parseCpuModel()),
                      _row('Núcleos detectados', '${_countCpuCores()}'),
                      _row('ABI soportados',
                          (_buildInfo['supportedAbis'] as List?)
                                  ?.join(', ') ??
                              'N/A'),
                      const SizedBox(height: 6),
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: const Text('Ver /proc/cpuinfo completo',
                            style: TextStyle(fontSize: 13)),
                        children: [
                          SelectableText(
                            _cpuInfo,
                            style: const TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ── Memoria ──
                _section(
                  'Memoria (fuente: /proc/meminfo)',
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _row('RAM total (real)', _parseMemValue('MemTotal')),
                      _row('RAM libre', _parseMemValue('MemFree')),
                      _row('RAM disponible', _parseMemValue('MemAvailable')),
                      _row('Buffers', _parseMemValue('Buffers')),
                      _row('Cached', _parseMemValue('Cached')),
                      _row('SwapTotal', _parseMemValue('SwapTotal')),
                      const SizedBox(height: 6),
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: const Text('Ver /proc/meminfo completo',
                            style: TextStyle(fontSize: 13)),
                        children: [
                          SelectableText(
                            _memInfo,
                            style: const TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ── Android Build info ──
                _section(
                  'Info Android (Build.*)',
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _row('Fabricante',
                          '${_buildInfo['manufacturer'] ?? 'N/A'}'),
                      _row('Marca', '${_buildInfo['brand'] ?? 'N/A'}'),
                      _row('Modelo', '${_buildInfo['model'] ?? 'N/A'}'),
                      _row('Dispositivo',
                          '${_buildInfo['device'] ?? 'N/A'}'),
                      _row('Producto', '${_buildInfo['product'] ?? 'N/A'}'),
                      _row('Hardware',
                          '${_buildInfo['hardware'] ?? 'N/A'}'),
                      _row('Board', '${_buildInfo['board'] ?? 'N/A'}'),
                      _row('Android',
                          '${_buildInfo['androidVersion'] ?? 'N/A'} (SDK ${_buildInfo['sdkInt'] ?? 'N/A'})'),
                      _row('Kernel', _kernelVersion),
                      _row('Fingerprint',
                          '${_buildInfo['fingerprint'] ?? 'N/A'}'),
                    ],
                  ),
                ),

                // ── Red / ADB ──
                _section(
                  'Red y ADB',
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _row('IP WiFi', _wifiIp),
                      _row('Puerto ADB (5555)',
                          _adbPortOpen == null
                              ? 'Sin IP — no comprobado'
                              : _adbPortOpen!
                                  ? 'ABIERTO — prueba: adb connect $_wifiIp:5555'
                                  : 'CERRADO (o sin respuesta)'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          _statusChip('WiFi IP',
                              _wifiIp != 'No disponible' && _wifiIp.isNotEmpty),
                          _statusChip('Puerto 5555', _adbPortOpen),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _loadNetworkAndAdb,
                        icon: const Icon(Icons.network_check),
                        label: const Text('Reintentar comprobación ADB'),
                      ),
                    ],
                  ),
                ),

                // ── Root ──
                _section(
                  'Prueba root',
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Intenta ejecutar "su -c settings put global development_settings_enabled 1". '
                        'Si el dispositivo tiene root, activará las opciones de desarrollador.',
                        style: TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _rootLoading ? null : _tryRootEnableDeveloperOptions,
                        icon: _rootLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.security),
                        label: const Text('Activar opciones via root'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepOrange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      if (_rootResult.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: SelectableText(
                            _rootResult,
                            style: const TextStyle(
                                fontSize: 12, fontFamily: 'monospace'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // ── Abrir opciones de desarrollador ──
                _section(
                  'Abrir opciones de desarrollador',
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Prueba cada método — aunque el menú esté oculto, '
                        'puede que la pantalla exista bajo una de estas rutas.',
                        style: TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 10),
                      _devButton(
                        'Método 1 — ACTION_APPLICATION_DEVELOPMENT_SETTINGS',
                        'Intento estándar de Android (Settings.ACTION_APPLICATION_DEVELOPMENT_SETTINGS)',
                        () => _openDevOptions('settings'),
                        Colors.blue,
                      ),
                      _devButton(
                        'Método 2 — Componente explícito (DevelopmentSettings)',
                        'Lanza directamente com.android.settings/.DevelopmentSettings',
                        () => _openDevOptions('component'),
                        Colors.indigo,
                      ),
                      _devButton(
                        'Método 3 — Componente alternativo (DeviceInfoSettings)',
                        'Lanza com.android.settings/.DeviceInfoSettings (toca "Número de compilación" 7 veces)',
                        () => _openDevOptions('device_info'),
                        Colors.purple,
                      ),
                      _devButton(
                        'Método 4 — ACTION_DEVICE_INFO_SETTINGS',
                        'Abre "Información del dispositivo" donde suele estar el número de compilación',
                        () => _openDevOptions('device_info_action'),
                        Colors.teal,
                      ),
                      if (_devOpResults.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Text('Resultados:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        ..._devOpResults.reversed.take(6).map((r) => Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '${r.method}: ${r.result}',
                                style: const TextStyle(
                                    fontSize: 12, fontFamily: 'monospace'),
                              ),
                            )),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _devButton(
      String label, String subtitle, VoidCallback onTap, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(subtitle,
                style:
                    const TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}

class _DevOpResult {
  final String method;
  final String result;
  _DevOpResult({required this.method, required this.result});
}
