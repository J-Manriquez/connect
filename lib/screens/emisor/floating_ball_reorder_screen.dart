import 'dart:convert';
import 'package:connect/services/floating_ball_service.dart';
import 'package:connect/services/notification_filter_service.dart';
import 'package:connect/theme_colors.dart';
import 'package:flutter/material.dart';

class FloatingBallReorderScreen extends StatefulWidget {
  const FloatingBallReorderScreen({super.key});

  @override
  State<FloatingBallReorderScreen> createState() => _FloatingBallReorderScreenState();
}

class _FloatingBallReorderScreenState extends State<FloatingBallReorderScreen> {
  bool _loading = true;

  int _fsBgColor = 0xDD111111;
  int _fsButtonColor = 0x22111111;
  int _fsIconColor = 0xFFFFFFFF;
  int _fsTextColor = 0xFFFFFFFF;
  bool _fsHideText = false;
  int _fsIconSizeDp = 34;
  int _fsTextSizeSp = 14;
  int _fsTileGapDp = 10;
  int _fsTilePaddingDp = 0;
  int _fsTileInnerGapDp = 10;

  List<String> _order = <String>[];
  final Map<String, Map<String, dynamic>> _appsByPkg = <String, Map<String, dynamic>>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final fsBgColor = await FloatingBallService.getFullScreenBgColor();
      final fsButtonColor = await FloatingBallService.getFullScreenButtonColor();
      final fsIconColor = await FloatingBallService.getFullScreenIconColor();
      final fsTextColor = await FloatingBallService.getFullScreenTextColor();
      final fsHideText = await FloatingBallService.isFullScreenHideTextEnabled();
      final fsIconSizeDp = await FloatingBallService.getFullScreenIconSizeDp();
      final fsTextSizeSp = await FloatingBallService.getFullScreenTextSizeSp();
      final fsTileGapDp = await FloatingBallService.getFullScreenTileGapDp();
      final fsTilePaddingDp = await FloatingBallService.getFullScreenTilePaddingDp();
      final fsTileInnerGapDp = await FloatingBallService.getFullScreenTileInnerGapDp();
      final selectedApps = await FloatingBallService.getSelectedApps();
      final selectedTools = await FloatingBallService.getSelectedTools();
      final savedOrder = await FloatingBallService.getFullScreenOrder();

      final defaultOrder = <String>[
        'back',
        'home',
        'volume',
        'brightness',
        'recents',
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

      Map<String, Map<String, dynamic>> appsByPkg = <String, Map<String, dynamic>>{};
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
        _fsBgColor = fsBgColor;
        _fsButtonColor = fsButtonColor;
        _fsIconColor = fsIconColor;
        _fsTextColor = fsTextColor;
        _fsHideText = fsHideText;
        _fsIconSizeDp = fsIconSizeDp;
        _fsTextSizeSp = fsTextSizeSp;
        _fsTileGapDp = fsTileGapDp;
        _fsTilePaddingDp = fsTilePaddingDp;
        _fsTileInnerGapDp = fsTileInnerGapDp;
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
    if (id.startsWith('pkg:')) {
      final pkg = id.substring(4);
      final app = _appsByPkg[pkg];
      final raw = (app?['iconBase64'] ?? app?['icon']).toString();
      final clean = raw.replaceAll(RegExp(r'\s+'), '').trim();
      if (clean.isNotEmpty) {
        try {
          final bytes = base64Decode(clean);
          return Image.memory(
            bytes,
            width: _fsIconSizeDp.toDouble(),
            height: _fsIconSizeDp.toDouble(),
            errorBuilder: (context, error, stackTrace) {
              return Icon(
                Icons.android,
                color: Color(_fsIconColor),
                size: _fsIconSizeDp.toDouble(),
              );
            },
          );
        } catch (_) {}
      }
      return Icon(
        Icons.android,
        color: Color(_fsIconColor),
        size: _fsIconSizeDp.toDouble(),
      );
    }
    IconData icon = Icons.info;
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
        break;
    }
    // Herramientas
    if (id.startsWith('tool:')) {
      switch (id) {
        case 'tool:tts':    icon = Icons.record_voice_over; break;
        case 'tool:dict':   icon = Icons.menu_book; break;
        case 'tool:trans':  icon = Icons.translate; break;
        case 'tool:search': icon = Icons.search; break;
        default:            icon = Icons.build; break;
      }
    }
    return Icon(icon, color: Color(_fsIconColor), size: _fsIconSizeDp.toDouble());
  }

  void _move(int from, int to) {
    if (from == to) return;
    setState(() {
      final id = _order.removeAt(from);
      final idx = to.clamp(0, _order.length);
      _order.insert(idx, id);
    });
  }

  Future<void> _save() async {
    await FloatingBallService.setFullScreenOrder(_order);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final gap = _fsTileGapDp.toDouble();
    final pad = _fsTilePaddingDp.toDouble();
    final inner = _fsTileInnerGapDp.toDouble();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reordenar botones'),
        backgroundColor: customColor[600],
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _loading ? null : _save,
            child: const Text('Guardar'),
          ),
        ],
      ),
      backgroundColor: Color(_fsBgColor),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final cellW = (constraints.maxWidth - (gap * 2)) / 3;
                  final cellH = cellW * 0.9;
                  return GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: gap,
                      mainAxisSpacing: gap,
                      childAspectRatio: cellW / cellH,
                    ),
                    itemCount: _order.length,
                    itemBuilder: (context, index) {
                      final id = _order[index];
                      final title = _titleForId(id);
                      return DragTarget<String>(
                        onWillAcceptWithDetails: (details) =>
                            details.data != id,
                        onAcceptWithDetails: (details) {
                          final from = _order.indexOf(details.data);
                          final to = index;
                          if (from >= 0) _move(from, to);
                        },
                        builder: (context, candidates, rejects) {
                          final highlighted = candidates.isNotEmpty;
                          final tile = Container(
                            decoration: BoxDecoration(
                              color: Color(_fsButtonColor),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: highlighted
                                    ? Colors.white.withValues(alpha: 0.5)
                                    : Colors.white.withValues(alpha: 0.12),
                                width: highlighted ? 2 : 1,
                              ),
                            ),
                            padding: EdgeInsets.all(pad),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _iconForId(id),
                                if (!_fsHideText) ...[
                                  SizedBox(height: inner),
                                  Text(
                                    title,
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Color(_fsTextColor),
                                      fontSize: _fsTextSizeSp.toDouble(),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );

                          return LongPressDraggable<String>(
                            data: id,
                            feedback: Material(
                              color: Colors.transparent,
                              child: SizedBox(
                                width: cellW,
                                height: cellH,
                                child: Opacity(opacity: 0.9, child: tile),
                              ),
                            ),
                            childWhenDragging: Opacity(opacity: 0.35, child: tile),
                            child: tile,
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
    );
  }
}
