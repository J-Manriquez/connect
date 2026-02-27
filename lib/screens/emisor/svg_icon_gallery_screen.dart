import 'dart:io';
import 'package:connect/services/svg_icon_gallery_service.dart';
import 'package:connect/theme_colors.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum IconGalleryPickType {
  svg,
  flutter,
}

class IconGalleryPick {
  final IconGalleryPickType type;
  final SvgIconEntry? svg;
  final String? flutterId;
  final IconData? flutterIcon;

  const IconGalleryPick._(
    this.type, {
    this.svg,
    this.flutterId,
    this.flutterIcon,
  });

  factory IconGalleryPick.svg(SvgIconEntry entry) {
    return IconGalleryPick._(IconGalleryPickType.svg, svg: entry);
  }

  factory IconGalleryPick.flutter({
    required String id,
    required IconData icon,
  }) {
    return IconGalleryPick._(
      IconGalleryPickType.flutter,
      flutterId: id,
      flutterIcon: icon,
    );
  }
}

class SvgIconGalleryScreen extends StatefulWidget {
  final bool pickMode;

  const SvgIconGalleryScreen({
    super.key,
    this.pickMode = true,
  });

  @override
  State<SvgIconGalleryScreen> createState() => _SvgIconGalleryScreenState();
}

class _SvgIconGalleryScreenState extends State<SvgIconGalleryScreen> {
  bool _loading = true;
  List<SvgIconEntry> _icons = <SvgIconEntry>[];

  final List<Map<String, dynamic>> _flutterIcons = const [
    {'id': 'info', 'icon': Icons.info},
    {'id': 'apps', 'icon': Icons.apps},
    {'id': 'play', 'icon': Icons.play_arrow},
    {'id': 'settings', 'icon': Icons.settings},
    {'id': 'flash', 'icon': Icons.flash_on},
    {'id': 'star', 'icon': Icons.star},
    {'id': 'home', 'icon': Icons.home},
    {'id': 'back', 'icon': Icons.arrow_back},
    {'id': 'recent', 'icon': Icons.history},
    {'id': 'search', 'icon': Icons.search},
    {'id': 'add', 'icon': Icons.add},
    {'id': 'edit', 'icon': Icons.edit},
    {'id': 'delete', 'icon': Icons.delete},
    {'id': 'close', 'icon': Icons.close},
    {'id': 'phone', 'icon': Icons.phone},
    {'id': 'sms', 'icon': Icons.sms},
    {'id': 'email', 'icon': Icons.email},
    {'id': 'camera', 'icon': Icons.camera_alt},
    {'id': 'photo', 'icon': Icons.photo},
    {'id': 'music', 'icon': Icons.music_note},
    {'id': 'volume', 'icon': Icons.volume_up},
    {'id': 'wifi', 'icon': Icons.wifi},
    {'id': 'bluetooth', 'icon': Icons.bluetooth},
    {'id': 'location', 'icon': Icons.location_on},
    {'id': 'map', 'icon': Icons.map},
    {'id': 'calendar', 'icon': Icons.calendar_today},
    {'id': 'alarm', 'icon': Icons.alarm},
    {'id': 'timer', 'icon': Icons.timer},
    {'id': 'lock', 'icon': Icons.lock},
    {'id': 'unlock', 'icon': Icons.lock_open},
    {'id': 'share', 'icon': Icons.share},
    {'id': 'send', 'icon': Icons.send},
    {'id': 'download', 'icon': Icons.download},
    {'id': 'upload', 'icon': Icons.upload},
    {'id': 'refresh', 'icon': Icons.refresh},
    {'id': 'power', 'icon': Icons.power_settings_new},
    {'id': 'battery', 'icon': Icons.battery_full},
    {'id': 'bolt', 'icon': Icons.bolt},
    {'id': 'folder', 'icon': Icons.folder},
    {'id': 'file', 'icon': Icons.insert_drive_file},
    {'id': 'chat', 'icon': Icons.chat},
    {'id': 'help', 'icon': Icons.help},
    {'id': 'warning', 'icon': Icons.warning},
    {'id': 'check', 'icon': Icons.check_circle},
    {'id': 'qr', 'icon': Icons.qr_code},
    {'id': 'link', 'icon': Icons.link},
    {'id': 'key', 'icon': Icons.key},
    {'id': 'shield', 'icon': Icons.shield},
    {'id': 'game', 'icon': Icons.videogame_asset},
    {'id': 'tv', 'icon': Icons.tv},
    {'id': 'car', 'icon': Icons.directions_car},
    {'id': 'walk', 'icon': Icons.directions_walk},
    {'id': 'watch', 'icon': Icons.watch},
    {'id': 'light', 'icon': Icons.lightbulb},
    {'id': 'brightness', 'icon': Icons.brightness_6},
    {'id': 'bookmark', 'icon': Icons.bookmark},
    {'id': 'cloud', 'icon': Icons.cloud},
    {'id': 'person', 'icon': Icons.person},
    {'id': 'person_add', 'icon': Icons.person_add},
    {'id': 'favorite', 'icon': Icons.favorite},
    {'id': 'favorite_border', 'icon': Icons.favorite_border},
    {'id': 'notifications', 'icon': Icons.notifications},
    {'id': 'notifications_off', 'icon': Icons.notifications_off},
    {'id': 'camera_front', 'icon': Icons.camera_front},
    {'id': 'camera_rear', 'icon': Icons.camera_rear},
    {'id': 'mic', 'icon': Icons.mic},
    {'id': 'mic_off', 'icon': Icons.mic_off},
    {'id': 'pause', 'icon': Icons.pause},
    {'id': 'stop', 'icon': Icons.stop},
    {'id': 'skip_next', 'icon': Icons.skip_next},
    {'id': 'skip_prev', 'icon': Icons.skip_previous},
    {'id': 'fast_forward', 'icon': Icons.fast_forward},
    {'id': 'fast_rewind', 'icon': Icons.fast_rewind},
    {'id': 'tune', 'icon': Icons.tune},
    {'id': 'filter', 'icon': Icons.filter_alt},
    {'id': 'security', 'icon': Icons.security},
    {'id': 'verified', 'icon': Icons.verified_user},
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final next = await SvgIconGalleryService.getAll();
    if (!mounted) return;
    setState(() {
      _icons = next;
      _loading = false;
    });
  }

  Future<void> _add() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const <String>['svg'],
        allowMultiple: true,
        dialogTitle: 'Seleccionar archivos SVG',
      );
      if (result == null || result.files.isEmpty) return;

      int added = 0;
      for (final f in result.files) {
        final path = f.path;
        if (path == null || path.trim().isEmpty) continue;
        final name = (f.name).replaceAll(RegExp(r'\.[^.]*$'), '');
        final ok = await SvgIconGalleryService.addFromFilePath(
          sourcePath: path,
          displayName: name,
        );
        if (ok) added++;
      }
      if (!mounted) return;
      if (added > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('SVG agregados: $added'),
            backgroundColor: Colors.green,
          ),
        );
        await _load();
      }
    } catch (_) {}
  }

  Future<void> _confirmDelete(SvgIconEntry entry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar SVG'),
        content: Text('Eliminar "${entry.name}" de la galería?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await SvgIconGalleryService.deleteById(entry.id);
    if (!mounted) return;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pickMode ? 'Seleccionar icono' : 'Galería de iconos'),
        backgroundColor: customColor[600],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _add,
            icon: const Icon(Icons.add),
            tooltip: 'Agregar SVG',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'SVG',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                if (_icons.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Text('No hay SVG en la galería'),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        childCount: _icons.length,
                        (context, index) {
                          final entry = _icons[index];
                          return InkWell(
                            onTap: () {
                              if (!widget.pickMode) return;
                              Navigator.pop(context, IconGalleryPick.svg(entry));
                            },
                            onLongPress: () => _confirmDelete(entry),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.black12),
                                color: Colors.black.withValues(alpha: 0.03),
                              ),
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                children: [
                                  Expanded(
                                    child: SvgPicture.file(
                                      File(entry.filePath),
                                      colorFilter: const ColorFilter.mode(
                                        Colors.black,
                                        BlendMode.srcIn,
                                      ),
                                      placeholderBuilder: (context) => const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    entry.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 18, 16, 8),
                    child: Text(
                      'Iconos de Flutter',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 6,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      childCount: _flutterIcons.length,
                      (context, index) {
                        final opt = _flutterIcons[index];
                        final id = opt['id'] as String;
                        final icon = opt['icon'] as IconData;
                        return InkWell(
                          onTap: () {
                            if (!widget.pickMode) return;
                            Navigator.pop(
                              context,
                              IconGalleryPick.flutter(id: id, icon: icon),
                            );
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.black12),
                            ),
                            child: Center(
                              child: Icon(icon, color: customColor, size: 22),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _add,
        backgroundColor: customColor[600],
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}
