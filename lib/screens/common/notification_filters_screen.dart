import 'package:connect/services/notification_filter_service.dart';
import 'package:connect/services/notification_filters_config_service.dart';
import 'package:connect/theme_colors.dart';
import 'package:flutter/material.dart';

class NotificationFiltersScreen extends StatefulWidget {
  const NotificationFiltersScreen({super.key});

  @override
  State<NotificationFiltersScreen> createState() =>
      _NotificationFiltersScreenState();
}

class _NotificationFiltersScreenState extends State<NotificationFiltersScreen> {
  bool _isLoading = true;
  NotificationFiltersConfig _config = NotificationFiltersConfig.defaults();
  List<Map<String, dynamic>> _installedApps = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final config = await NotificationFiltersConfigService.getConfig();
      final apps = await _getInstalledApps();
      setState(() {
        _config = config;
        _installedApps = apps;
        _isLoading = false;
      });
      await NotificationFiltersConfigService.applyNativeFilterSettingsFromConfig(
        config,
      );
    } catch (_) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _getInstalledApps() async {
    try {
      final List<dynamic> result =
          await NotificationFilterService.platform.invokeMethod('getInstalledApps');
      final apps = result
          .map((item) => Map<String, dynamic>.from(item as Map))
          .where((m) => (m['packageName'] ?? '').toString().isNotEmpty)
          .toList();
      apps.sort((a, b) {
        final an = (a['appName'] ?? '').toString().toLowerCase();
        final bn = (b['appName'] ?? '').toString().toLowerCase();
        return an.compareTo(bn);
      });
      return apps;
    } catch (_) {
      return [];
    }
  }

  Future<void> _setBuiltIn(String key, bool value) async {
    final updated = _config.copyWith(
      builtIn: <String, bool>{..._config.builtIn, key: value},
    );
    setState(() {
      _config = updated;
    });
    await NotificationFiltersConfigService.saveConfig(updated);
  }

  String _appNameForPackage(String packageName) {
    for (final a in _installedApps) {
      if ((a['packageName'] ?? '').toString() == packageName) {
        final name = (a['appName'] ?? '').toString();
        if (name.isNotEmpty) return name;
      }
    }
    return packageName;
  }

  Future<void> _addCustomRule() async {
    final rule = await Navigator.of(context).push<NotificationFilterRule>(
      MaterialPageRoute(
        builder: (_) => NotificationFilterAddScreen(
          installedApps: _installedApps,
        ),
      ),
    );
    if (rule == null) return;

    final pkg = rule.packageName.trim();
    if (pkg.isEmpty) return;
    final current = <String, List<NotificationFilterRule>>{
      ..._config.customByPackage,
    };
    final list = current[pkg] == null
        ? <NotificationFilterRule>[]
        : List<NotificationFilterRule>.from(current[pkg]!);
    list.add(rule);
    current[pkg] = list;
    final updated = _config.copyWith(customByPackage: current);
    setState(() {
      _config = updated;
    });
    await NotificationFiltersConfigService.saveConfig(updated);
  }

  Future<void> _toggleCustomRule(
    NotificationFilterRule rule,
    bool enabled,
  ) async {
    final pkg = rule.packageName;
    final current = <String, List<NotificationFilterRule>>{
      ..._config.customByPackage,
    };
    final list = current[pkg] == null
        ? <NotificationFilterRule>[]
        : List<NotificationFilterRule>.from(current[pkg]!);
    final idx = list.indexWhere((r) => r.id == rule.id);
    if (idx >= 0) {
      list[idx] = NotificationFilterRule(
        id: rule.id,
        packageName: rule.packageName,
        pattern: rule.pattern,
        enabled: enabled,
        isRegex: rule.isRegex,
      );
      current[pkg] = list;
      final updated = _config.copyWith(customByPackage: current);
      setState(() {
        _config = updated;
      });
      await NotificationFiltersConfigService.saveConfig(updated);
    }
  }

  Future<void> _removeCustomRule(NotificationFilterRule rule) async {
    final pkg = rule.packageName;
    final current = <String, List<NotificationFilterRule>>{
      ..._config.customByPackage,
    };
    final list = current[pkg] == null
        ? <NotificationFilterRule>[]
        : List<NotificationFilterRule>.from(current[pkg]!);
    list.removeWhere((r) => r.id == rule.id);
    if (list.isEmpty) {
      current.remove(pkg);
    } else {
      current[pkg] = list;
    }
    final updated = _config.copyWith(customByPackage: current);
    setState(() {
      _config = updated;
    });
    await NotificationFiltersConfigService.saveConfig(updated);
  }

  Widget _builtInTile({
    required String title,
    required String subtitle,
    required String keyName,
    required bool defaultValue,
  }) {
    final value = _config.isEnabled(keyName, fallback: defaultValue);
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: (v) => _setBuiltIn(keyName, v),
    );
  }

  List<Widget> _customFiltersSection() {
    final entries = _config.customByPackage.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    if (entries.isEmpty) {
      return [
        const ListTile(
          title: Text('Filtros personalizados'),
          subtitle: Text('No hay filtros personalizados creados.'),
        ),
      ];
    }

    final widgets = <Widget>[
      const ListTile(
        title: Text('Filtros personalizados'),
        subtitle: Text(
          'Se evalúan sobre el contenido normalizado (incluye "contenido").',
        ),
      ),
    ];

    for (final e in entries) {
      final pkg = e.key;
      final rules = e.value;
      final appName = _appNameForPackage(pkg);
      widgets.add(
        ExpansionTile(
          title: Text(appName),
          subtitle: Text(pkg),
          children: rules.map((r) {
            return ListTile(
              title: Text(r.pattern),
              subtitle: Text(r.isRegex ? 'Regex' : 'Contiene'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch(
                    value: r.enabled,
                    onChanged: (v) => _toggleCustomRule(r, v),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _removeCustomRule(r),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      );
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Filtros de Notificaciones'),
        actions: [
          IconButton(
            onPressed: _addCustomRule,
            icon: const Icon(Icons.add),
            tooltip: 'Añadir filtro',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(8),
              children: [
                Card(
                  child: const ListTile(
                    title: Text('Cómo funcionan'),
                    subtitle: Text(
                      'Los filtros se evalúan sobre el texto normalizado generado desde: title, text, bigText, body, mensaje y "contenido". Si coincide un filtro, la notificación se bloquea.',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      _builtInTile(
                        title: 'Bloquear vacías',
                        subtitle: 'Filtra notificaciones sin contenido',
                        keyName: 'filter_empty',
                        defaultValue: true,
                      ),
                      _builtInTile(
                        title: 'Bloquear resúmenes globales',
                        subtitle: 'Filtra “X mensajes nuevos” (cualquier app)',
                        keyName: 'filter_global_message_patterns',
                        defaultValue: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      const ListTile(
                        title: Text('WhatsApp'),
                      ),
                      _builtInTile(
                        title: 'Enviando',
                        subtitle: 'Filtra estados tipo “enviando/sending”',
                        keyName: 'whatsapp_filter_sending',
                        defaultValue: true,
                      ),
                      _builtInTile(
                        title: 'Resúmenes de chats',
                        subtitle: 'Filtra “X mensajes de Y chats” y similares',
                        keyName: 'whatsapp_filter_message_summary',
                        defaultValue: true,
                      ),
                      _builtInTile(
                        title: 'Llamadas',
                        subtitle: 'Filtra llamadas/videollamadas',
                        keyName: 'whatsapp_filter_calls',
                        defaultValue: true,
                      ),
                      _builtInTile(
                        title: 'Copias de seguridad',
                        subtitle: 'Filtra estados de backup',
                        keyName: 'whatsapp_filter_backup',
                        defaultValue: true,
                      ),
                      _builtInTile(
                        title: 'Genéricas / sin contenido',
                        subtitle: 'Filtra “contenido no disponible” y similares',
                        keyName: 'whatsapp_filter_generic',
                        defaultValue: true,
                      ),
                      _builtInTile(
                        title: 'Comprobando mensajes nuevos',
                        subtitle:
                            'Filtra “comprobando si hay mensajes nuevos”',
                        keyName: 'whatsapp_filter_checking',
                        defaultValue: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      const ListTile(
                        title: Text('Instagram'),
                      ),
                      _builtInTile(
                        title: 'Subidas',
                        subtitle: 'Filtra “subiendo contenido”',
                        keyName: 'instagram_filter_upload',
                        defaultValue: true,
                      ),
                      _builtInTile(
                        title: 'Historias',
                        subtitle: 'Filtra “subiendo historia” y similares',
                        keyName: 'instagram_filter_story',
                        defaultValue: true,
                      ),
                      _builtInTile(
                        title: 'Llamadas',
                        subtitle: 'Filtra llamadas/videollamadas',
                        keyName: 'instagram_filter_calls',
                        defaultValue: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: _customFiltersSection(),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'Los filtros se aplican tanto al guardado como a la visualización y se sincronizan entre emisor y receptor.',
                    style: TextStyle(
                      color: customColor[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class NotificationFilterAddScreen extends StatefulWidget {
  final List<Map<String, dynamic>> installedApps;

  const NotificationFilterAddScreen({
    super.key,
    required this.installedApps,
  });

  @override
  State<NotificationFilterAddScreen> createState() =>
      _NotificationFilterAddScreenState();
}

class _NotificationFilterAddScreenState extends State<NotificationFilterAddScreen> {
  String _selectedPackage = '';
  String _pattern = '';
  bool _enabled = true;
  bool _isRegex = false;

  @override
  Widget build(BuildContext context) {
    final apps = List<Map<String, dynamic>>.from(widget.installedApps);
    apps.sort((a, b) {
      final an = (a['appName'] ?? '').toString().toLowerCase();
      final bn = (b['appName'] ?? '').toString().toLowerCase();
      return an.compareTo(bn);
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Añadir filtro'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cómo crear un filtro',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'El filtro se evalúa sobre el texto normalizado (incluye el campo "contenido").',
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Modo "Contiene": escribe una frase o palabra. Ejemplo: "comprobando si hay mensajes nuevos".',
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Modo "Regex": escribe una expresión regular. Ejemplo: "^\\d+\\s+mensajes?\\s+nuevos?\$".',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedPackage.isEmpty ? null : _selectedPackage,
            decoration: const InputDecoration(
              labelText: 'Aplicación',
              border: OutlineInputBorder(),
            ),
            items: apps.map((a) {
              final pkg = (a['packageName'] ?? '').toString();
              final name = (a['appName'] ?? '').toString();
              return DropdownMenuItem(
                value: pkg,
                child: Text(name.isEmpty ? pkg : name),
              );
            }).toList(),
            onChanged: (v) {
              setState(() {
                _selectedPackage = (v ?? '').toString();
              });
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            decoration: InputDecoration(
              labelText: _isRegex ? 'Regex' : 'Texto (contiene)',
              helperText:
                  'Se aplica contra el contenido normalizado (incluye "contenido").',
              border: const OutlineInputBorder(),
            ),
            onChanged: (v) {
              setState(() {
                _pattern = v;
              });
            },
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('Regex'),
            subtitle: const Text('Si está desactivado, usa coincidencia por texto'),
            value: _isRegex,
            onChanged: (v) {
              setState(() {
                _isRegex = v;
              });
            },
          ),
          SwitchListTile(
            title: const Text('Activo'),
            value: _enabled,
            onChanged: (v) {
              setState(() {
                _enabled = v;
              });
            },
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () {
              final pkg = _selectedPackage.trim();
              final p = _pattern.trim();
              if (pkg.isEmpty || p.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Selecciona una aplicación y escribe un patrón'),
                  ),
                );
                return;
              }
              final id = DateTime.now().millisecondsSinceEpoch.toString();
              final rule = NotificationFilterRule(
                id: id,
                packageName: pkg,
                pattern: p,
                enabled: _enabled,
                isRegex: _isRegex,
              );
              Navigator.of(context).pop(rule);
            },
            child: const Text('Guardar filtro'),
          ),
        ],
      ),
    );
  }
}
