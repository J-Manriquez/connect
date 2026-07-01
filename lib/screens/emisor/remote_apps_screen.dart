import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/remote_control_service.dart';
import '../../theme_colors.dart';

/// Pantalla para ver las apps instaladas en el receptor y elegir cuáles
/// mostrar como accesos rápidos en el modo D-pad. Las seleccionadas se
/// guardan junto con el dispositivo conectado, en el mismo orden en que se
/// seleccionan, para recargarlas automáticamente en futuras conexiones.
class RemoteAppsScreen extends StatefulWidget {
  final String deviceAddress;
  final String deviceName;

  const RemoteAppsScreen({
    super.key,
    required this.deviceAddress,
    required this.deviceName,
  });

  @override
  State<RemoteAppsScreen> createState() => _RemoteAppsScreenState();
}

class _RemoteAppsScreenState extends State<RemoteAppsScreen> {
  List<RemoteAppEntry> _available = [];
  List<RemoteAppEntry> _selected = [];
  bool _loadingAvailable = true;
  StreamSubscription<List<RemoteAppEntry>>? _appsSub;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _appsSub = RemoteControlService.appsListStream.listen((apps) {
      if (!mounted) return;
      setState(() {
        _available = apps;
        _loadingAvailable = false;
      });
    });
    _loadSelected();
    RemoteControlService.requestAppsList();
  }

  @override
  void dispose() {
    _appsSub?.cancel();
    super.dispose();
  }

  Future<void> _loadSelected() async {
    final saved = await RemoteControlService.loadAppShortcuts(
      widget.deviceAddress,
    );
    if (mounted) setState(() => _selected = saved);
  }

  Future<void> _persist() {
    return RemoteControlService.saveAppShortcuts(
      widget.deviceAddress,
      widget.deviceName,
      _selected,
    );
  }

  void _addShortcut(RemoteAppEntry app) {
    if (_selected.any((e) => e.packageName == app.packageName)) return;
    setState(() => _selected = [..._selected, app]);
    _persist();
  }

  void _removeShortcut(RemoteAppEntry app) {
    setState(
      () => _selected = _selected
          .where((e) => e.packageName != app.packageName)
          .toList(),
    );
    _persist();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _available
        .where(
          (a) => a.label.toLowerCase().contains(_search.toLowerCase()),
        )
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Apps de ${widget.deviceName}'),
        actions: [
          IconButton(
            tooltip: 'Actualizar lista',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _loadingAvailable = true);
              RemoteControlService.requestAppsList();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_selected.isNotEmpty) _buildSelectedSection(),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar app instalada (p. ej. YouTube)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          Expanded(child: _buildAvailableList(filtered)),
        ],
      ),
    );
  }

  Widget _buildSelectedSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Accesos rápidos (orden de selección)',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selected
                .map(
                  (app) => Chip(
                    avatar: const Icon(Icons.apps, size: 18),
                    label: Text(app.label),
                    onDeleted: () => _removeShortcut(app),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailableList(List<RemoteAppEntry> filtered) {
    if (_loadingAvailable) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_available.isEmpty) {
      return const Center(
        child: Text('No se pudo obtener la lista de apps del receptor.'),
      );
    }
    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final app = filtered[index];
        final added = _selected.any((e) => e.packageName == app.packageName);
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: customColor[50],
            child: Icon(Icons.apps, color: customColor[500]),
          ),
          title: Text(app.label),
          subtitle: Text(app.packageName),
          trailing: added
              ? const Icon(Icons.check_circle, color: Colors.green)
              : IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => _addShortcut(app),
                ),
          onTap: added ? () => _removeShortcut(app) : () => _addShortcut(app),
        );
      },
    );
  }
}
