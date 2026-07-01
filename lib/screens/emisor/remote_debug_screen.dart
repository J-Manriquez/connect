import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/remote_control_service.dart';

/// Visor de logs de depuración enviados por el receptor (connect remote control)
/// a través del mismo socket RFCOMM. Permite diagnosticar sin cable USB.
class RemoteDebugScreen extends StatefulWidget {
  const RemoteDebugScreen({super.key});

  @override
  State<RemoteDebugScreen> createState() => _RemoteDebugScreenState();
}

class _RemoteDebugScreenState extends State<RemoteDebugScreen> {
  final List<_LogEntry> _logs = [];
  StreamSubscription<Map<String, dynamic>>? _sub;
  final ScrollController _scroll = ScrollController();
  String _filter = '';
  bool _autoScroll = true;

  @override
  void initState() {
    super.initState();
    // Carga los logs que ya llegaron antes de abrir esta pantalla.
    final buffered = RemoteControlService.debugLogBuffer;
    for (final msg in buffered) {
      _logs.add(_entryFromMap(msg));
    }
    // Suscripción a nuevos logs en tiempo real.
    _sub = RemoteControlService.debugLogStream.listen((msg) {
      if (!mounted) return;
      setState(() => _logs.add(_entryFromMap(msg)));
      if (_autoScroll) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scroll.hasClients) {
            _scroll.animateTo(
              _scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });
  }

  _LogEntry _entryFromMap(Map<String, dynamic> msg) => _LogEntry(
        source: (msg['source'] ?? '').toString(),
        message: (msg['message'] ?? '').toString(),
        timestamp: msg['timestamp'] is int
            ? msg['timestamp'] as int
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
      _filtered.map((e) => '[${e.sourceLabel}] ${e.message}').join('\n');

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug receptor'),
        actions: [
          IconButton(
            tooltip: _autoScroll ? 'Auto-scroll ON' : 'Auto-scroll OFF',
            icon: Icon(
              _autoScroll ? Icons.vertical_align_bottom : Icons.vertical_align_center,
            ),
            onPressed: () => setState(() => _autoScroll = !_autoScroll),
          ),
          IconButton(
            tooltip: 'Copiar todo',
            icon: const Icon(Icons.copy),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _allText));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Logs copiados al portapapeles')),
              );
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
                      'Sin logs — conecta el receptor\ny activa el servicio de accesibilidad.',
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final e = filtered[i];
                      return _LogTile(entry: e);
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              '${filtered.length} entradas',
              style: Theme.of(context).textTheme.bodySmall,
            ),
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

  _LogEntry({
    required this.source,
    required this.message,
    required this.timestamp,
  });

  String get sourceLabel => source.isEmpty ? '?' : source;

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

  Color _sourceColor(BuildContext context) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.red,
      Colors.brown,
      Colors.indigo,
    ];
    return colors[entry.source.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.timeLabel,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: _sourceColor(context).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              entry.sourceLabel,
              style: TextStyle(
                fontSize: 11,
                color: _sourceColor(context),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              entry.message,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}
