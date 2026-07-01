import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CalcHistoryEntry {
  final String id;
  String name;
  final String expr;
  final String result;
  final int updatedAt;

  CalcHistoryEntry({
    required this.id,
    required this.name,
    required this.expr,
    required this.result,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'expr': expr,
        'result': result,
        'updatedAt': updatedAt,
      };

  factory CalcHistoryEntry.fromJson(Map<String, dynamic> j) => CalcHistoryEntry(
        id: j['id'] as String,
        name: (j['name'] as String?) ?? '',
        expr: j['expr'] as String,
        result: j['result'] as String,
        updatedAt: j['updatedAt'] as int,
      );
}

/// CRUD sobre `calc_history_json`. Tras cada cambio notifica al widget nativo.
/// El historial se almacena del más reciente al más antiguo.
class CalculatorHistoryStore {
  static const String _kHistory = 'calc_history_json';
  static const int _maxEntries = 200;

  static const MethodChannel _channel = MethodChannel('com.example.connect/ble');

  static Future<List<CalcHistoryEntry>> loadAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kHistory);
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(CalcHistoryEntry.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Agrega un ejercicio al inicio. Si ya hay >=_maxEntries, quita el más antiguo.
  static Future<void> append(String expr, String result) async {
    final entries = await loadAll();
    final entry = CalcHistoryEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: '',
      expr: expr,
      result: result,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    entries.insert(0, entry);
    if (entries.length > _maxEntries) entries.removeRange(_maxEntries, entries.length);
    await _save(entries);
  }

  /// Cambia el nombre de una entrada. Solo in-app (el widget no tiene teclado).
  static Future<void> rename(String id, String name) async {
    final entries = await loadAll();
    for (final e in entries) {
      if (e.id == id) {
        e.name = name;
        break;
      }
    }
    await _save(entries);
  }

  static Future<void> delete(String id) async {
    final entries = await loadAll();
    entries.removeWhere((e) => e.id == id);
    await _save(entries);
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kHistory);
    await _notify();
  }

  static Future<void> _save(List<CalcHistoryEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kHistory, jsonEncode(entries.map((e) => e.toJson()).toList()));
    await _notify();
  }

  static Future<void> _notify() async {
    try {
      await _channel.invokeMethod('updateCalculatorWidget');
    } catch (_) {}
  }
}
