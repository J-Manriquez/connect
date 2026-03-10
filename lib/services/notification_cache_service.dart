import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class NotificationCacheService {
  static const String _processedNotificationsKey = 'processed_notifications';
  static const String _preExistingNotificationsKey = 'pre_existing_notifications';
  static const String _visualizedNotificationsKey = 'visualized_notifications';
  static const String _recentSentRepliesKey = 'recent_sent_replies_v1';
  
  // Máximo de notificaciones en caché para evitar problemas de memoria
  static const int _maxCacheSize = 1000;
  
  // Registrar notificaciones que existían antes de la vinculación
  static Future<void> registerPreExistingNotifications(Set<String> notificationIds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_preExistingNotificationsKey, notificationIds.toList());
    // print('NotificationCacheService: ${notificationIds.length} notificaciones pre-existentes registradas');
  }
  
  // Verificar si una notificación existía antes de la vinculación
  static Future<bool> isPreExisting(String notificationId) async {
    final prefs = await SharedPreferences.getInstance();
    final preExisting = prefs.getStringList(_preExistingNotificationsKey) ?? [];
    return preExisting.contains(notificationId);
  }
  
  // Marcar una notificación como procesada (mostrada localmente)
  static Future<void> markAsProcessed(String notificationId) async {
    final prefs = await SharedPreferences.getInstance();
    final processed = prefs.getStringList(_processedNotificationsKey) ?? [];
    
    if (!processed.contains(notificationId)) {
      processed.add(notificationId);
      
      // Limitar el tamaño del caché
      if (processed.length > _maxCacheSize) {
        processed.removeRange(0, processed.length - _maxCacheSize);
      }
      
      await prefs.setStringList(_processedNotificationsKey, processed);
    }
  }
  
  // Verificar si una notificación ya fue procesada
  static Future<bool> isProcessed(String notificationId) async {
    final prefs = await SharedPreferences.getInstance();
    final processed = prefs.getStringList(_processedNotificationsKey) ?? [];
    return processed.contains(notificationId);
  }
  
  // Marcar una notificación como visualizada
  static Future<void> markAsVisualized(String notificationId) async {
    final prefs = await SharedPreferences.getInstance();
    final visualized = prefs.getStringList(_visualizedNotificationsKey) ?? [];
    
    if (!visualized.contains(notificationId)) {
      visualized.add(notificationId);
      
      // Limitar el tamaño del caché
      if (visualized.length > _maxCacheSize) {
        visualized.removeRange(0, visualized.length - _maxCacheSize);
      }
      
      await prefs.setStringList(_visualizedNotificationsKey, visualized);
    }
  }
  
  // Verificar si una notificación ya fue visualizada
  static Future<bool> isVisualized(String notificationId) async {
    final prefs = await SharedPreferences.getInstance();
    final visualized = prefs.getStringList(_visualizedNotificationsKey) ?? [];
    return visualized.contains(notificationId);
  }
  
  // Limpiar cachés antiguos (llamar periódicamente)
  static Future<void> cleanOldCache() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Limpiar notificaciones procesadas más antiguas
    final processed = prefs.getStringList(_processedNotificationsKey) ?? [];
    if (processed.length > _maxCacheSize ~/ 2) {
      final newProcessed = processed.sublist(processed.length - (_maxCacheSize ~/ 2));
      await prefs.setStringList(_processedNotificationsKey, newProcessed);
    }
    
    // Limpiar notificaciones visualizadas más antiguas
    final visualized = prefs.getStringList(_visualizedNotificationsKey) ?? [];
    if (visualized.length > _maxCacheSize ~/ 2) {
      final newVisualized = visualized.sublist(visualized.length - (_maxCacheSize ~/ 2));
      await prefs.setStringList(_visualizedNotificationsKey, newVisualized);
    }
    
    // print('NotificationCacheService: Caché limpiado');
  }

  static String _normalizeForMatch(String s) {
    var out = s.trim().toLowerCase();
    if (out.isEmpty) return '';
    out = out
        .replaceAll(RegExp(r'[áàäâ]'), 'a')
        .replaceAll(RegExp(r'[éèëê]'), 'e')
        .replaceAll(RegExp(r'[íìïî]'), 'i')
        .replaceAll(RegExp(r'[óòöô]'), 'o')
        .replaceAll(RegExp(r'[úùüû]'), 'u')
        .replaceAll('ñ', 'n');
    out = out.replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
    out = out.replaceAll(RegExp(r'\s+'), ' ').trim();
    return out;
  }

  static Future<void> recordSentReply({
    required String packageName,
    required String conversationTitle,
    required String replyText,
    int? timestampMs,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final tsMs = timestampMs ?? nowMs;
    final pkg = packageName.trim();
    if (pkg.isEmpty) return;
    final titleNorm = _normalizeForMatch(conversationTitle);
    final textNorm = _normalizeForMatch(replyText);
    if (textNorm.isEmpty) return;

    final raw = prefs.getString(_recentSentRepliesKey) ?? '[]';
    List<dynamic> list;
    try {
      list = jsonDecode(raw) as List<dynamic>;
    } catch (_) {
      list = [];
    }

    final next = <Map<String, dynamic>>[];
    for (final e in list) {
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(e);
      final int t = (m['tsMs'] as int?) ?? 0;
      if (t <= 0) continue;
      if ((nowMs - t) > 2 * 60 * 1000) continue;
      next.add(m);
    }

    next.add({
      'pkg': pkg,
      'titleNorm': titleNorm,
      'textNorm': textNorm,
      'tsMs': tsMs,
    });

    await prefs.setString(_recentSentRepliesKey, jsonEncode(next));
  }

  static Future<bool> shouldSuppressLocalEcho({
    required String packageName,
    required String title,
    required String text,
    int withinMs = 20000,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final raw = prefs.getString(_recentSentRepliesKey) ?? '[]';

    List<dynamic> list;
    try {
      list = jsonDecode(raw) as List<dynamic>;
    } catch (_) {
      list = [];
    }

    final pkg = packageName.trim();
    if (pkg.isEmpty) return false;
    final titleNorm = _normalizeForMatch(title);
    final textNorm = _normalizeForMatch(text);
    if (textNorm.isEmpty) return false;

    bool match = false;
    final next = <Map<String, dynamic>>[];
    for (final e in list) {
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(e);
      final spkg = (m['pkg'] ?? '').toString().trim();
      final stitle = (m['titleNorm'] ?? '').toString().trim();
      final stext = (m['textNorm'] ?? '').toString().trim();
      final int tsMs = (m['tsMs'] as int?) ?? 0;
      if (spkg.isEmpty || stext.isEmpty || tsMs <= 0) continue;
      if ((nowMs - tsMs) > 2 * 60 * 1000) continue;
      next.add(m);

      if (spkg != pkg) continue;
      if (withinMs > 0 && (nowMs - tsMs) > withinMs) continue;
      final titleOk = stitle.isEmpty || titleNorm.isEmpty
          ? true
          : (titleNorm.contains(stitle) || stitle.contains(titleNorm));
      final textOk = textNorm.contains(stext) || stext.contains(textNorm);
      if (titleOk && textOk) {
        match = true;
      }
    }

    if (next.length != list.length) {
      try {
        await prefs.setString(_recentSentRepliesKey, jsonEncode(next));
      } catch (_) {}
    }

    return match;
  }
}
