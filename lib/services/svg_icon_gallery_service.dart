import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SvgIconEntry {
  final String id;
  final String name;
  final String filePath;
  final DateTime createdAt;

  const SvgIconEntry({
    required this.id,
    required this.name,
    required this.filePath,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'filePath': filePath,
        'createdAt': createdAt.toIso8601String(),
      };

  static SvgIconEntry? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final id = (raw['id'] ?? '').toString().trim();
    final name = (raw['name'] ?? '').toString().trim();
    final filePath = (raw['filePath'] ?? '').toString().trim();
    final createdAtRaw = (raw['createdAt'] ?? '').toString().trim();
    if (id.isEmpty || name.isEmpty || filePath.isEmpty || createdAtRaw.isEmpty) {
      return null;
    }
    DateTime createdAt;
    try {
      createdAt = DateTime.parse(createdAtRaw);
    } catch (_) {
      return null;
    }
    return SvgIconEntry(
      id: id,
      name: name,
      filePath: filePath,
      createdAt: createdAt,
    );
  }
}

class SvgIconGalleryService {
  static const String _keyGalleryJson = 'svg_icon_gallery_json';

  static String _newId() {
    final ms = DateTime.now().millisecondsSinceEpoch;
    return 'svg_$ms';
  }

  static Future<Directory> _ensureDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}${Platform.pathSeparator}svg_icons');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<List<SvgIconEntry>> getAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyGalleryJson);
      if (raw == null || raw.trim().isEmpty) return <SvgIconEntry>[];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <SvgIconEntry>[];
      final out = <SvgIconEntry>[];
      for (final e in decoded) {
        final entry = SvgIconEntry.fromJson(e);
        if (entry == null) continue;
        if (!File(entry.filePath).existsSync()) continue;
        out.add(entry);
      }
      out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return out;
    } catch (_) {
      return <SvgIconEntry>[];
    }
  }

  static Future<bool> addFromFilePath({
    required String sourcePath,
    required String displayName,
  }) async {
    final cleanName = displayName.trim();
    if (cleanName.isEmpty) return false;
    try {
      final src = File(sourcePath);
      if (!await src.exists()) return false;
      final bytes = await src.readAsBytes();
      if (bytes.isEmpty) return false;

      final dir = await _ensureDir();
      final id = _newId();
      final dest = File('${dir.path}${Platform.pathSeparator}$id.svg');
      await dest.writeAsBytes(bytes, flush: true);

      final next = await getAll();
      next.removeWhere((e) => e.filePath == dest.path);
      next.insert(
        0,
        SvgIconEntry(
          id: id,
          name: cleanName,
          filePath: dest.path,
          createdAt: DateTime.now(),
        ),
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _keyGalleryJson,
        jsonEncode(next.map((e) => e.toJson()).toList()),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> deleteById(String id) async {
    final cleanId = id.trim();
    if (cleanId.isEmpty) return false;
    try {
      final all = await getAll();
      SvgIconEntry? toDelete;
      final remaining = <SvgIconEntry>[];
      for (final e in all) {
        if (e.id == cleanId) {
          toDelete = e;
        } else {
          remaining.add(e);
        }
      }
      if (toDelete == null) return false;
      try {
        final f = File(toDelete.filePath);
        if (await f.exists()) {
          await f.delete();
        }
      } catch (_) {}
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _keyGalleryJson,
        jsonEncode(remaining.map((e) => e.toJson()).toList()),
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}

