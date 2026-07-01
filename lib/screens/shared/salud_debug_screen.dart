import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/sensor_service.dart';

/// Pantalla de debug de sensores corporales.
/// Muestra logs en tiempo real del [SensorService], con filtro, copia y descarga.
/// Patrón idéntico a RemoteDebugScreen pero con fuente sensor_service.
class SaludDebugScreen extends StatefulWidget {
  final String side; // 'receptor' | 'emisor'
  const SaludDebugScreen({super.key, required this.side});

  @override
  State<SaludDebugScreen> createState() => _SaludDebugScreenState();
}

class _SaludDebugScreenState extends State<SaludDebugScreen> {
  final List<_LogEntry> _logs = [];
  StreamSubscription<Map<String, dynamic>>? _sub;
  final ScrollController _scroll = ScrollController();
  String _filter = '';
  bool _autoScroll = true;

  @override
  void initState() {
    super.initState();
    for (final msg in SensorService.debugLogBuffer) {
      _logs.add(_fromMap(msg));
    }
    _sub = SensorService.debugLogStream.listen((msg) {
      if (!mounted) return;
      setState(() => _logs.add(_fromMap(msg)));
      if (_autoScroll) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scroll.hasClients) {
            _scroll.animateTo(_scroll.position.maxScrollExtent,
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut);
          }
        });
      }
    });
  }

  _LogEntry _fromMap(Map<String, dynamic> m) => _LogEntry(
        source: (m['source'] ?? '').toString(),
        message: (m['message'] ?? '').toString(),
        timestamp: m['timestamp'] is int
            ? m['timestamp'] as int
            : DateTime.now().millisecondsSinceEpoch,
      );

  @override
  void dispose() {
    _sub?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  List<_LogEntry> get _filtered {
    if (_filter.isEmpty) return _logs;
    final q = _filter.toLowerCase();
    return _logs
        .where((e) =>
            e.source.toLowerCase().contains(q) ||
            e.message.toLowerCase().contains(q))
        .toList();
  }

  String get _allText =>
      _filtered.map((e) => '[${e.timeLabel}][${e.source}] ${e.message}').join('\n');

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: Text('Debug sensores (${widget.side})'),
        actions: [
          IconButton(
            tooltip: _autoScroll ? 'Auto-scroll ON' : 'Auto-scroll OFF',
            icon: Icon(_autoScroll
                ? Icons.vertical_align_bottom
                : Icons.vertical_align_center),
            onPressed: () => setState(() => _autoScroll = !_autoScroll),
          ),
          IconButton(
            tooltip: 'Copiar todo',
            icon: const Icon(Icons.copy),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _allText));
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Logs copiados')));
            },
          ),
          IconButton(
            tooltip: 'Limpiar',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => setState(() => _logs.clear()),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Filtrar por fuente o mensaje',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _filter = v),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text(
                      'Sin logs — inicia el servicio de sensores\nen la pantalla de Salud del receptor.',
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => _LogTile(entry: filtered[i]),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text('${filtered.length} entradas',
                style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _LogEntry {
  final String source;
  final String message;
  final int timestamp;
  _LogEntry({required this.source, required this.message, required this.timestamp});

  String get timeLabel {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}:'
        '${dt.second.toString().padLeft(2, '0')}.'
        '${(dt.millisecond ~/ 10).toString().padLeft(2, '0')}';
  }
}

class _LogTile extends StatelessWidget {
  final _LogEntry entry;
  const _LogTile({required this.entry});

  Color _color() {
    const colors = [
      Colors.blue, Colors.green, Colors.orange, Colors.purple,
      Colors.teal, Colors.red, Colors.brown, Colors.indigo,
    ];
    return colors[entry.source.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final c = _color();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(entry.timeLabel,
              style: TextStyle(
                  fontSize: 11, color: Colors.grey.shade600, fontFamily: 'monospace')),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
                color: c.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4)),
            child: Text(entry.source,
                style: TextStyle(
                    fontSize: 11, color: c, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(entry.message,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
          ),
        ],
      ),
    );
  }
}
