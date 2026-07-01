import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:connect/services/ble_service.dart';

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

  // ── Sensores ──
  bool _sensorsLoading = false;
  String _sensorsError = '';
  int _sensorCount = 0;
  List<Map<String, dynamic>> _sensors = [];

  // ── Consola de log en pantalla (útil en el reloj, sin USB) ──
  final List<String> _logLines = [];

  /// Log unificado: imprime localmente, lo reenvía por BT al emisor
  /// (método recomendado de la skill bt-debug-logging) y lo acumula para
  /// mostrarlo en pantalla.
  void _log(String message) {
    // print simple (no debugPrint: no se trunca ni throttlea)
    // ignore: avoid_print
    print('[device_diag] $message');
    final ts = DateTime.now().toIso8601String();
    final line = '${ts.substring(11, ts.length.clamp(0, 23))} $message';
    if (mounted) {
      setState(() {
        _logLines.add(line);
        if (_logLines.length > 500) {
          _logLines.removeRange(0, _logLines.length - 500);
        }
      });
    } else {
      _logLines.add(line);
    }
    try {
      unawaited(BleService.sendDebugLogToPeers('device_diag', message));
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _log('initState: pantalla de diagnóstico abierta');
    _loadAll();
  }

  Future<void> _loadAll() async {
    _log('loadAll: inicio de carga de diagnóstico');
    setState(() => _loading = true);
    await Future.wait([
      _loadProcFiles(),
      _loadBuildInfo(),
      _loadNetworkAndAdb(),
      _loadSensors(),
    ]);
    setState(() => _loading = false);
    _log('loadAll: carga completa');
  }

  Future<void> _loadProcFiles() async {
    try {
      final cpu = await File('/proc/cpuinfo').readAsString();
      setState(() => _cpuInfo = cpu.trim());
      _log('proc/cpuinfo OK: ${_countCpuCores()} núcleos, '
          'modelo="${_parseCpuModel()}", ${cpu.length} bytes');
    } catch (e) {
      setState(() => _cpuInfo = 'Error: $e');
      _log('proc/cpuinfo ERROR: $e');
    }
    try {
      final mem = await File('/proc/meminfo').readAsString();
      setState(() => _memInfo = mem.trim());
      _log('proc/meminfo OK: MemTotal=${_parseMemValue('MemTotal')}, '
          'MemAvailable=${_parseMemValue('MemAvailable')}');
    } catch (e) {
      setState(() => _memInfo = 'Error: $e');
      _log('proc/meminfo ERROR: $e');
    }
    try {
      final ver = await File('/proc/version').readAsString();
      setState(() => _kernelVersion = ver.trim());
      final v = ver.trim();
      _log('proc/version OK: "${v.length > 80 ? v.substring(0, 80) : v}"');
    } catch (e) {
      setState(() => _kernelVersion = 'Error: $e');
      _log('proc/version ERROR: $e');
    }
  }

  Future<void> _loadBuildInfo() async {
    try {
      final result = await _channel.invokeMethod<Map>('getAndroidBuildInfo');
      setState(() => _buildInfo = Map<String, dynamic>.from(result ?? {}));
      _log('buildInfo OK: ${_buildInfo['manufacturer']}/${_buildInfo['model']} '
          'Android ${_buildInfo['androidVersion']} (SDK ${_buildInfo['sdkInt']}) '
          'abis=${(_buildInfo['supportedAbis'] as List?)?.join(',')}');
    } catch (e) {
      setState(() => _buildInfo = {'error': '$e'});
      _log('buildInfo ERROR: $e');
    }
  }

  Future<void> _loadSensors() async {
    setState(() {
      _sensorsLoading = true;
      _sensorsError = '';
    });
    _log('getSensors: solicitando lista de sensores…');
    try {
      final raw = await _channel.invokeMethod<Map>('getSensors');
      final sensorsRaw = (raw?['sensors'] as List?) ?? [];
      final parsed = sensorsRaw
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      setState(() {
        _sensorCount = (raw?['count'] as num?)?.toInt() ?? parsed.length;
        _sensors = parsed;
      });
      _log('getSensors OK: $_sensorCount sensores detectados');
      // Loguea el resumen por categoría de salud/hardware relevante.
      for (final cap in _capabilities) {
        final matches = _sensorsMatching(cap);
        if (matches.isEmpty) {
          _log('  [${cap.label}] NO detectado');
        } else {
          final names = matches
              .map((s) => s['name'] ?? s['stringType'] ?? '?')
              .join(' | ');
          _log('  [${cap.label}] SÍ (${matches.length}): $names');
        }
      }
      // Loguea cada sensor crudo (nombre + tipo + vendor) para depuración total.
      for (final s in _sensors) {
        _log('  sensor type=${s['type']} "${s['name']}" '
            'vendor="${s['vendor']}" stringType=${s['stringType'] ?? '-'}');
      }
    } catch (e) {
      setState(() => _sensorsError = '$e');
      _log('getSensors ERROR: $e');
    } finally {
      setState(() => _sensorsLoading = false);
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
    } catch (e) {
      _log('red: error listando interfaces: $e');
    }

    setState(() => _wifiIp = ip.isEmpty ? 'No disponible' : ip);
    _log('red: IP=${ip.isEmpty ? 'No disponible' : ip}');

    if (ip.isNotEmpty) {
      try {
        final socket = await Socket.connect(ip, 5555,
            timeout: const Duration(seconds: 3));
        socket.destroy();
        setState(() => _adbPortOpen = true);
        _log('adb: puerto 5555 ABIERTO en $ip');
      } on SocketException catch (e) {
        setState(() => _adbPortOpen = false);
        _log('adb: puerto 5555 CERRADO ($e)');
      } catch (e) {
        setState(() => _adbPortOpen = false);
        _log('adb: error comprobando 5555: $e');
      }
    } else {
      setState(() => _adbPortOpen = null);
      _log('adb: sin IP, no se comprueba puerto 5555');
    }
  }

  Future<void> _tryRootEnableDeveloperOptions() async {
    setState(() {
      _rootLoading = true;
      _rootResult = '';
    });
    _log('root: intentando "su -c settings put global development_settings_enabled 1"');
    try {
      final result = await _channel.invokeMethod<String>(
          'tryRootEnableDeveloperOptions');
      setState(() => _rootResult = result ?? 'Sin respuesta');
      _log('root: resultado="${result ?? 'Sin respuesta'}"');
    } catch (e) {
      setState(() => _rootResult = 'Error: $e');
      _log('root: ERROR $e');
    } finally {
      setState(() => _rootLoading = false);
    }
  }

  Future<void> _exportToFile() async {
    _log('export: generando TXT de diagnóstico…');
    final ts = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final fileName =
        'diagnostico_${ts.year}${two(ts.month)}${two(ts.day)}_'
        '${two(ts.hour)}${two(ts.minute)}${two(ts.second)}.txt';

    final buf = StringBuffer();
    buf.writeln('=== Diagnóstico del dispositivo ===');
    buf.writeln('Generado: ${ts.toIso8601String()}');
    buf.writeln();

    // ── Build info ──
    buf.writeln('--- Android Build ---');
    for (final e in _buildInfo.entries) {
      final v = e.value;
      buf.writeln('${e.key}: ${v is List ? v.join(', ') : v}');
    }
    buf.writeln();

    // ── Kernel / CPU / Memoria ──
    buf.writeln('--- Kernel ---');
    buf.writeln(_kernelVersion);
    buf.writeln();
    buf.writeln('--- CPU (/proc/cpuinfo) ---');
    buf.writeln(_cpuInfo);
    buf.writeln();
    buf.writeln('--- Memoria (/proc/meminfo) ---');
    buf.writeln(_memInfo);
    buf.writeln();

    // ── Red ──
    buf.writeln('--- Red ---');
    buf.writeln('IP WiFi: $_wifiIp');
    buf.writeln(
        'Puerto ADB 5555: ${_adbPortOpen == null ? 'no comprobado' : _adbPortOpen! ? 'ABIERTO' : 'cerrado'}');
    buf.writeln();

    // ── Sensores ──
    buf.writeln('--- Sensores ($_sensorCount total) ---');
    if (_sensorsError.isNotEmpty) {
      buf.writeln('ERROR al leer sensores: $_sensorsError');
    } else {
      buf.writeln('Resumen por categoría:');
      for (final cap in _capabilities) {
        final matches = _sensorsMatching(cap);
        if (matches.isEmpty) {
          buf.writeln('  [NO] ${cap.label}');
        } else {
          final names =
              matches.map((s) => s['name'] ?? s['stringType'] ?? '?').join(' | ');
          buf.writeln('  [SÍ x${matches.length}] ${cap.label}: $names');
        }
      }
      buf.writeln();
      buf.writeln('Lista completa de sensores:');
      for (final s in _sensors) {
        buf.writeln(
            '  type=${s['type']} "${s['name']}" vendor="${s['vendor']}" '
            'stringType=${s['stringType'] ?? '-'} '
            'power=${s['power']}mA maxRange=${s['maximumRange']} '
            'wakeUp=${s['isWakeUp']} minDelay=${s['minDelay']}µs '
            'maxDelay=${s['maxDelay']}µs '
            'fifoMax=${s['fifoMaxEventCount']}');
      }
    }
    buf.writeln();

    // ── Resultados de root / devOptions ──
    if (_rootResult.isNotEmpty) {
      buf.writeln('--- Resultado root ---');
      buf.writeln(_rootResult);
      buf.writeln();
    }
    if (_devOpResults.isNotEmpty) {
      buf.writeln('--- Resultados openDeveloperOptions ---');
      for (final r in _devOpResults) {
        buf.writeln('  ${r.method}: ${r.result}');
      }
      buf.writeln();
    }

    // ── Log de esta sesión ──
    if (_logLines.isNotEmpty) {
      buf.writeln('--- Log de sesión ---');
      for (final l in _logLines) {
        buf.writeln(l);
      }
      buf.writeln();
    }

    final content = buf.toString();
    _log('export: TXT generado (${content.length} chars), abriendo selector…');

    try {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Guardar diagnóstico del dispositivo',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: const ['txt'],
        bytes: utf8.encode(content),
      );
      if (path == null) {
        _log('export: cancelado por el usuario');
      } else {
        _log('export: guardado en "$path"');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Guardado: $path')),
          );
        }
      }
    } catch (e) {
      _log('export: ERROR $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    }
  }

  Future<void> _openDevOptions(String method) async {
    _log('devOptions: lanzando método "$method"');
    try {
      final result =
          await _channel.invokeMethod<String>('openDeveloperOptions', {'method': method});
      setState(() {
        _devOpResults.add(_DevOpResult(method: method, result: result ?? 'OK'));
      });
      _log('devOptions: "$method" -> ${result ?? 'OK'}');
    } catch (e) {
      setState(() {
        _devOpResults.add(_DevOpResult(method: method, result: 'Error: $e'));
      });
      _log('devOptions: "$method" ERROR $e');
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

  // ---- sensores: categorización ----

  /// Capacidades de salud/hardware que interesa detectar. Se detectan por
  /// tipo estándar de Android y/o por palabras clave en el nombre/stringType
  /// (los sensores de salud propietarios — SpO2, presión, sueño — no tienen
  /// tipo estándar y solo se reconocen por nombre del fabricante).
  static final List<_SensorCapability> _capabilities = [
    _SensorCapability('Frecuencia cardíaca', Icons.favorite,
        types: {21, 31}, keywords: ['heart', 'hrm', 'pulse', 'ppg']),
    _SensorCapability('Oxígeno en sangre (SpO₂)', Icons.bloodtype,
        keywords: ['spo2', 'oxygen', 'oxig', 'saturat', 'blood oxygen']),
    _SensorCapability('Presión arterial', Icons.monitor_heart,
        keywords: ['blood pressure', 'blood_pressure', 'presion arterial', 'bp_sensor']),
    _SensorCapability('Sueño', Icons.bedtime,
        keywords: ['sleep', 'sueno']),
    _SensorCapability('ECG / electrocardiograma', Icons.timeline,
        keywords: ['ecg', 'ekg', 'electrocardio']),
    _SensorCapability('Temperatura corporal/piel', Icons.thermostat,
        keywords: ['skin temp', 'skin_temp', 'body temp', 'body_temp',
          'temperatura corporal', 'temperatura piel']),
    _SensorCapability('Bioimpedancia / composición', Icons.fitness_center,
        keywords: ['bia', 'bioimped', 'body composition', 'composition']),
    _SensorCapability('Estrés / GSR / EDA', Icons.psychology,
        keywords: ['stress', 'gsr', 'skin conduct', 'eda']),
    _SensorCapability('Acelerómetro', Icons.speed,
        types: {1, 35, 38}),
    _SensorCapability('Giroscopio', Icons.threed_rotation,
        types: {4, 16}),
    _SensorCapability('Magnetómetro / brújula', Icons.explore,
        types: {2, 14}),
    _SensorCapability('Podómetro (pasos)', Icons.directions_walk,
        types: {18, 19}),
    _SensorCapability('Barómetro (presión atmosférica)', Icons.compress,
        types: {6}),
    _SensorCapability('Luz ambiental', Icons.light_mode,
        types: {5}),
    _SensorCapability('Proximidad', Icons.sensors,
        types: {8}),
    _SensorCapability('Temperatura ambiente', Icons.device_thermostat,
        types: {13, 7}),
    _SensorCapability('Humedad relativa', Icons.water_drop,
        types: {12}),
    _SensorCapability('Detección en muñeca (off-body)', Icons.watch,
        types: {34}, keywords: ['off-body', 'offbody', 'off_body', 'on-body']),
    _SensorCapability('Movimiento / gestos', Icons.gesture,
        types: {17, 22, 23, 24, 25, 26, 29, 30}),
  ];

  List<Map<String, dynamic>> _sensorsMatching(_SensorCapability cap) {
    return _sensors.where((s) {
      final t = (s['type'] as num?)?.toInt();
      if (cap.types != null && t != null && cap.types!.contains(t)) {
        return true;
      }
      if (cap.keywords != null) {
        final hay =
            '${s['name'] ?? ''} ${s['stringType'] ?? ''}'.toLowerCase();
        for (final k in cap.keywords!) {
          if (hay.contains(k)) return true;
        }
      }
      return false;
    }).toList();
  }

  static const Map<int, String> _typeNames = {
    1: 'Acelerómetro',
    2: 'Campo magnético',
    3: 'Orientación (obsoleto)',
    4: 'Giroscopio',
    5: 'Luz',
    6: 'Presión (barómetro)',
    7: 'Temperatura (obsoleto)',
    8: 'Proximidad',
    9: 'Gravedad',
    10: 'Aceleración lineal',
    11: 'Vector de rotación',
    12: 'Humedad relativa',
    13: 'Temperatura ambiente',
    14: 'Campo magnético (sin calibrar)',
    15: 'Vector de rotación (juego)',
    16: 'Giroscopio (sin calibrar)',
    17: 'Movimiento significativo',
    18: 'Detector de pasos',
    19: 'Contador de pasos',
    20: 'Vector rotación geomagnético',
    21: 'Frecuencia cardíaca',
    22: 'Detector de inclinación',
    23: 'Gesto de despertar',
    24: 'Gesto de vistazo',
    25: 'Gesto de levantar',
    26: 'Gesto de muñeca',
    27: 'Orientación del dispositivo',
    28: 'Pose 6DOF',
    29: 'Detección estacionaria',
    30: 'Detección de movimiento',
    31: 'Latido cardíaco',
    32: 'Meta sensor dinámico',
    33: 'Sensor adicional',
    34: 'Detección off-body (baja latencia)',
    35: 'Acelerómetro (sin calibrar)',
    36: 'Ángulo de bisagra',
    37: 'Head tracker',
  };

  String _typeLabel(Map<String, dynamic> s) {
    final t = (s['type'] as num?)?.toInt();
    if (t != null && _typeNames.containsKey(t)) return _typeNames[t]!;
    return 'Tipo ${t ?? '?'}';
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
            icon: const Icon(Icons.download),
            onPressed: _exportToFile,
            tooltip: 'Exportar diagnóstico a TXT',
          ),
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

                // ── Sensores: resumen de salud/hardware ──
                _buildSensorsSection(),

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

                // ── Consola de log en pantalla ──
                _buildLogConsole(),
              ],
            ),
    );
  }

  Widget _buildSensorsSection() {
    return _section(
      'Sensores de hardware y salud',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_sensorsLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 8),
                  Text('Leyendo sensores…', style: TextStyle(fontSize: 13)),
                ],
              ),
            )
          else if (_sensorsError.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(6),
              ),
              child: SelectableText('Error: $_sensorsError',
                  style: const TextStyle(
                      fontSize: 12, color: Colors.red, fontFamily: 'monospace')),
            )
          else ...[
            _row('Sensores totales', '$_sensorCount'),
            const SizedBox(height: 8),
            const Text('Detección por categoría:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: _capabilities.map((cap) {
                final matches = _sensorsMatching(cap);
                final present = matches.isNotEmpty;
                final color = present ? Colors.green : Colors.grey;
                return Chip(
                  avatar: Icon(cap.icon, color: color, size: 16),
                  label: Text(
                    present ? '${cap.label} (${matches.length})' : cap.label,
                    style: TextStyle(color: color, fontSize: 12),
                  ),
                  backgroundColor: color.withOpacity(0.10),
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            const Text(
              'Nota: listar sensores no requiere permisos, pero leer datos de '
              'frecuencia cardíaca / SpO₂ requiere el permiso BODY_SENSORS. Los '
              'sensores propietarios del fabricante (SpO₂, presión, sueño) suelen '
              'aparecer con nombres no estándar.',
              style: TextStyle(fontSize: 11, color: Colors.black54),
            ),
            const SizedBox(height: 6),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text('Ver lista completa de sensores ($_sensorCount)',
                  style: const TextStyle(fontSize: 13)),
              children: _sensors.map(_buildSensorTile).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSensorTile(Map<String, dynamic> s) {
    final lines = <String>[
      'tipo: ${s['type']} (${_typeLabel(s)})',
      if (s['stringType'] != null) 'stringType: ${s['stringType']}',
      'vendor: ${s['vendor'] ?? '?'}',
      'versión: ${s['version'] ?? '?'}',
      'potencia: ${s['power'] ?? '?'} mA',
      'resolución: ${s['resolution'] ?? '?'}',
      'rango máx: ${s['maximumRange'] ?? '?'}',
      if (s['minDelay'] != null) 'minDelay: ${s['minDelay']} µs',
      if (s['maxDelay'] != null) 'maxDelay: ${s['maxDelay']} µs',
      if (s['isWakeUp'] != null) 'wakeUp: ${s['isWakeUp']}',
      if (s['fifoMaxEventCount'] != null)
        'fifoMax: ${s['fifoMaxEventCount']}',
    ];
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${s['name'] ?? 'Sensor'}',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 2),
          SelectableText(
            lines.join('\n'),
            style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }

  Widget _buildLogConsole() {
    return _section(
      'Registro de diagnóstico (${_logLines.length})',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Todo lo de esta pantalla se imprime por print, se reenvía por '
            'Bluetooth al emisor (source "device_diag") y se muestra aquí.',
            style: TextStyle(fontSize: 11, color: Colors.black54),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 260),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(6),
            ),
            child: SingleChildScrollView(
              reverse: true,
              child: SelectableText(
                _logLines.isEmpty ? '(sin entradas)' : _logLines.join('\n'),
                style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: Color(0xFF8AE234)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton.icon(
                onPressed: () => setState(() => _logLines.clear()),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Limpiar'),
              ),
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(
                      ClipboardData(text: _logLines.join('\n')));
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Log copiado')),
                    );
                  }
                },
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copiar'),
              ),
            ],
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

class _SensorCapability {
  final String label;
  final IconData icon;
  final Set<int>? types;
  final List<String>? keywords;
  const _SensorCapability(this.label, this.icon, {this.types, this.keywords});
}
