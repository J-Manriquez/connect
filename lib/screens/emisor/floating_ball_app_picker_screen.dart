import 'dart:convert';
import 'package:connect/services/notification_filter_service.dart';
import 'package:flutter/material.dart';

class FloatingBallAppPickerScreen extends StatefulWidget {
  final List<String> initialSelectedPackages;
  final bool singleSelection;
  final String title;

  const FloatingBallAppPickerScreen({
    super.key,
    required this.initialSelectedPackages,
    this.singleSelection = false,
    this.title = 'Seleccionar aplicaciones',
  });

  @override
  State<FloatingBallAppPickerScreen> createState() =>
      _FloatingBallAppPickerScreenState();
}

class _FloatingBallAppPickerScreenState
    extends State<FloatingBallAppPickerScreen> {
  bool _loading = true;
  String _query = '';
  List<Map<String, dynamic>> _apps = <Map<String, dynamic>>[];
  late Set<String> _selected;
  String? _selectedSingle;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialSelectedPackages.toSet();
    if (widget.singleSelection) {
      _selectedSingle = widget.initialSelectedPackages.isEmpty
          ? null
          : widget.initialSelectedPackages.first;
    }
    _loadApps();
  }

  Future<void> _loadApps() async {
    setState(() {
      _loading = true;
    });
    List<Map<String, dynamic>> nextApps = <Map<String, dynamic>>[];
    try {
      final res = await NotificationFilterService.platform
          .invokeMethod('getInstalledApps');
      final list = (res as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      list.sort((a, b) {
        final an = (a['appName'] ?? '').toString().toLowerCase();
        final bn = (b['appName'] ?? '').toString().toLowerCase();
        return an.compareTo(bn);
      });
      nextApps = list;
    } catch (_) {
      nextApps = <Map<String, dynamic>>[];
    }
    if (!mounted) return;
    setState(() {
      _apps = nextApps;
      _loading = false;
    });
  }

  Widget _buildAppIcon(String? base64Icon) {
    if (base64Icon == null || base64Icon.isEmpty) {
      return const Icon(Icons.android);
    }
    try {
      final cleanBase64 = base64Icon.replaceAll(RegExp(r'\s+'), '');
      final bytes = base64Decode(cleanBase64);
      return Image.memory(
        bytes,
        width: 28,
        height: 28,
        errorBuilder: (context, error, stackTrace) {
          return const Icon(Icons.android);
        },
      );
    } catch (_) {
      return const Icon(Icons.android);
    }
  }

  List<Map<String, dynamic>> get _filteredApps {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _apps;
    return _apps.where((a) {
      final name = (a['appName'] ?? '').toString().toLowerCase();
      final pkg = (a['packageName'] ?? '').toString().toLowerCase();
      return name.contains(q) || pkg.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          TextButton(
            onPressed: () {
              if (widget.singleSelection) {
                final v = _selectedSingle;
                Navigator.pop(context, v == null ? <String>[] : <String>[v]);
                return;
              }
              Navigator.pop(context, _selected.toList());
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar por nombre o paquete',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          if (_loading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _filteredApps.length,
                itemBuilder: (context, index) {
                  final app = _filteredApps[index];
                  final pkg = (app['packageName'] ?? '').toString();
                  final name = (app['appName'] ?? '').toString();
                  final icon = app['iconBase64']?.toString();
                  if (widget.singleSelection) {
                    return RadioListTile<String>(
                      value: pkg,
                      groupValue: _selectedSingle,
                      onChanged: (v) {
                        setState(() {
                          _selectedSingle = v;
                        });
                      },
                      secondary: _buildAppIcon(icon),
                      title: Text(name.isEmpty ? pkg : name),
                      subtitle: Text(pkg),
                      controlAffinity: ListTileControlAffinity.trailing,
                    );
                  }
                  final selected = _selected.contains(pkg);
                  return CheckboxListTile(
                    value: selected,
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          _selected.add(pkg);
                        } else {
                          _selected.remove(pkg);
                        }
                      });
                    },
                    secondary: _buildAppIcon(icon),
                    title: Text(name.isEmpty ? pkg : name),
                    subtitle: Text(pkg),
                    controlAffinity: ListTileControlAffinity.trailing,
                  );
                },
              ),
            )
        ],
      ),
    );
  }
}
