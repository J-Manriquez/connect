import 'dart:convert';

import 'package:connect/services/floating_ball_service.dart';
import 'package:connect/services/notification_filter_service.dart';
import 'package:connect/theme_colors.dart';
import 'package:flutter/material.dart';

class FloatingBallPopupReorderScreen extends StatefulWidget {
  const FloatingBallPopupReorderScreen({super.key});

  @override
  State<FloatingBallPopupReorderScreen> createState() =>
      _FloatingBallPopupReorderScreenState();
}

class _FloatingBallPopupReorderScreenState
    extends State<FloatingBallPopupReorderScreen> {
  bool _loading = true;

  int _popupBgColor = 0xDD111111;
  int _popupButtonColor = 0x22111111;
  int _popupIconColor = 0xFFFFFFFF;

  List<String> _order = <String>[];
  final Map<String, Map<String, dynamic>> _appsByPkg =
      <String, Map<String, dynamic>>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final bgColor = await FloatingBallService.getPopupBgColor();
      final buttonColor = await FloatingBallService.getPopupButtonColor();
      final iconColor = await FloatingBallService.getPopupIconColor();
      final selectedApps = await FloatingBallService.getSelectedApps();
      final selectedTools = await FloatingBallService.getSelectedTools();
      final savedOrder = await FloatingBallService.getPopupOrder();

      const defaultOrder = [
        'back',
        'home',
        'recents',
        'volume',
        'brightness',
        'settings',
        'chats',
        'calculator',
        'remote_control',
      ];
      final nextOrder = <String>[];
      final used = <String>{};
      for (final id in savedOrder) {
        if (id.trim().isEmpty) continue;
        nextOrder.add(id);
        used.add(id);
      }
      for (final id in defaultOrder) {
        if (!used.contains(id)) {
          nextOrder.add(id);
          used.add(id);
        }
      }
      for (final pkg in selectedApps) {
        final id = 'pkg:$pkg';
        if (!used.contains(id)) {
          nextOrder.add(id);
          used.add(id);
        }
      }
      for (final toolId in selectedTools) {
        if (!used.contains(toolId)) {
          nextOrder.add(toolId);
          used.add(toolId);
        }
      }

      final Map<String, Map<String, dynamic>> appsByPkg = {};
      try {
        final res = await NotificationFilterService.platform
            .invokeMethod('getInstalledApps');
        final list = (res as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        for (final a in list) {
          final pkg = (a['packageName'] ?? '').toString();
          if (pkg.isEmpty) continue;
          appsByPkg[pkg] = a;
        }
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _popupBgColor = bgColor;
        _popupButtonColor = buttonColor;
        _popupIconColor = iconColor;
        _order = nextOrder;
        _appsByPkg
          ..clear()
          ..addAll(appsByPkg);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String _titleForId(String id) {
    switch (id) {
      case 'back':
        return 'Back';
      case 'home':
        return 'Home';
      case 'volume':
        return 'Volumen';
      case 'brightness':
        return 'Brillo';
      case 'recents':
        return 'Recientes';
      case 'settings':
        return 'Configuración';
      case 'chats':
        return 'Chats';
      case 'calculator':
        return 'Calculadora';
      case 'remote_control':
        return 'Control remoto';
    }
    if (id.startsWith('pkg:')) {
      final pkg = id.substring(4);
      final app = _appsByPkg[pkg];
      final name = (app?['appName'] ?? '').toString();
      return name.isEmpty ? pkg : name;
    }
    if (id.startsWith('tool:')) {
      switch (id) {
        case 'tool:tts':    return 'Lector TTS';
        case 'tool:dict':   return 'Diccionario';
        case 'tool:trans':  return 'Traductor';
        case 'tool:search': return 'Buscar';
        default:            return id;
      }
    }
    return id;
  }

  Widget _iconForId(String id) {
    const double size = 28;
    if (id.startsWith('pkg:')) {
      final pkg = id.substring(4);
      final app = _appsByPkg[pkg];
      final raw =
          (app?['iconBase64'] ?? app?['icon'] ?? '').toString();
      final clean = raw.replaceAll(RegExp(r'\s+'), '').trim();
      if (clean.isNotEmpty) {
        try {
          final bytes = base64Decode(clean);
          return Image.memory(
            bytes,
            width: size,
            height: size,
            errorBuilder: (_, __, ___) =>
                Icon(Icons.android, color: Color(_popupIconColor), size: size),
          );
        } catch (_) {}
      }
      return Icon(Icons.android, color: Color(_popupIconColor), size: size);
    }
    final IconData icon;
    switch (id) {
      case 'back':
        icon = Icons.arrow_back;
        break;
      case 'home':
        icon = Icons.home;
        break;
      case 'volume':
        icon = Icons.volume_up;
        break;
      case 'brightness':
        icon = Icons.brightness_6;
        break;
      case 'recents':
        icon = Icons.history;
        break;
      case 'settings':
        icon = Icons.settings;
        break;
      case 'chats':
        icon = Icons.chat;
        break;
      case 'calculator':
        icon = Icons.calculate;
        break;
      case 'remote_control':
        icon = Icons.gamepad;
        break;
      default:
        icon = Icons.android;
    }
    if (id.startsWith('tool:')) {
      switch (id) {
        case 'tool:tts':    return Icon(Icons.record_voice_over, color: Color(_popupIconColor), size: size);
        case 'tool:dict':   return Icon(Icons.menu_book, color: Color(_popupIconColor), size: size);
        case 'tool:trans':  return Icon(Icons.translate, color: Color(_popupIconColor), size: size);
        case 'tool:search': return Icon(Icons.search, color: Color(_popupIconColor), size: size);
        default:            return Icon(Icons.build, color: Color(_popupIconColor), size: size);
      }
    }
    return Icon(icon, color: Color(_popupIconColor), size: size);
  }

  Future<void> _save() async {
    await FloatingBallService.setPopupOrder(_order);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reordenar popup'),
        backgroundColor: customColor[600],
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _loading ? null : _save,
            child: const Text(
              'Guardar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      backgroundColor: Color(_popupBgColor),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ReorderableListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final item = _order.removeAt(oldIndex);
                  _order.insert(newIndex, item);
                });
              },
              children: [
                for (final id in _order)
                  Container(
                    key: ValueKey(id),
                    margin: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: Color(_popupButtonColor),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: ListTile(
                      leading: _iconForId(id),
                      title: Text(
                        _titleForId(id),
                        style: TextStyle(color: Color(_popupIconColor)),
                      ),
                      trailing: Icon(
                        Icons.drag_handle,
                        color: Color(_popupIconColor).withValues(alpha: 0.6),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
