import 'dart:convert';

import 'package:connect/models/device_data.dart';
import 'package:connect/services/firebase_service.dart';
import 'package:connect/services/notification_filter_service.dart';
import 'package:connect/services/preferences_service.dart';
import 'package:connect/services/receptor_service.dart';
import 'package:connect/theme_colors.dart';
import 'package:flutter/material.dart';

class ConversationAppsScreen extends StatefulWidget {
  const ConversationAppsScreen({super.key});

  @override
  State<ConversationAppsScreen> createState() => _ConversationAppsScreenState();
}

class _ConversationAppsScreenState extends State<ConversationAppsScreen> {
  final ReceptorService _receptorService = ReceptorService();
  final FirebaseService _firebaseService = FirebaseService();

  bool _isLoading = true;
  List<AppData> _apps = [];
  Set<String> _conversationEnabled = {};
  Map<String, String> _iconByPackage = {};
  String _linkedDeviceId = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final enabled = await PreferencesService.getConversationEnabledPackages();
      final linkedDeviceId = await _receptorService.getLinkedDeviceId();

      List<AppData> apps = [];
      if (linkedDeviceId != null && linkedDeviceId.trim().isNotEmpty) {
        _linkedDeviceId = linkedDeviceId.trim();
        apps = await _firebaseService.getAppListForDeviceId(linkedDeviceId);
      }

      final filtered = apps.where((a) => a.activa).toList();
      filtered.sort((a, b) {
        final an = a.nombre.toLowerCase();
        final bn = b.nombre.toLowerCase();
        return an.compareTo(bn);
      });

      Map<String, String> iconByPackage = {};
      try {
        final List<dynamic> result =
            await NotificationFilterService.platform.invokeMethod(
          'getInstalledApps',
        );
        final installed = result
            .map((item) => Map<String, dynamic>.from(item as Map))
            .where((m) => (m['packageName'] ?? '').toString().isNotEmpty)
            .toList();
        for (final m in installed) {
          final pkg = (m['packageName'] ?? '').toString().trim();
          final icon = (m['icon'] ?? '').toString();
          if (pkg.isEmpty || icon.isEmpty) continue;
          iconByPackage[pkg] = icon;
        }
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _apps = filtered;
        _conversationEnabled = enabled.toSet();
        _iconByPackage = iconByPackage;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _toggle(String packageName, bool value) async {
    final updated = {..._conversationEnabled};
    if (value) {
      updated.add(packageName);
    } else {
      updated.remove(packageName);
    }
    setState(() {
      _conversationEnabled = updated;
    });
    await PreferencesService.saveConversationEnabledPackages(updated.toList());
    if (_linkedDeviceId.isNotEmpty) {
      try {
        await _firebaseService.updateConversationEnabledPackagesForDeviceId(
          _linkedDeviceId,
          updated.toList(),
        );
      } catch (_) {}
    }
  }

  Widget _buildIcon(String packageName) {
    final iconBase64 = _iconByPackage[packageName] ?? '';
    if (iconBase64.isEmpty) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: customColor[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.apps, color: customColor[700]),
      );
    }
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: customColor[100],
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(6),
      child: Image.memory(
        const Base64Decoder().convert(iconBase64),
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Icon(Icons.apps, color: customColor[700]);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conversaciones'),
        backgroundColor: customColor[700],
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _apps.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'No hay aplicaciones habilitadas desde el emisor.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: _apps.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final app = _apps[index];
                    final pkg = app.packageName;
                    final enabled = _conversationEnabled.contains(pkg);
                    final title = app.nombre.trim().isNotEmpty
                        ? app.nombre.trim()
                        : pkg;
                    return Card(
                      child: ListTile(
                        leading: _buildIcon(pkg),
                        title: Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(pkg),
                        trailing: Switch(
                          value: enabled,
                          onChanged: (v) => _toggle(pkg, v),
                          activeColor: Colors.green,
                          inactiveTrackColor: customColor[200],
                          inactiveThumbColor: Colors.grey[300],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
