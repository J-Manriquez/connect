import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connect/services/firebase_service.dart';
import 'package:connect/services/receptor_service.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationFilterRule {
  final String id;
  final String packageName;
  final String pattern;
  final bool enabled;
  final bool isRegex;

  const NotificationFilterRule({
    required this.id,
    required this.packageName,
    required this.pattern,
    required this.enabled,
    required this.isRegex,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'packageName': packageName,
      'pattern': pattern,
      'enabled': enabled,
      'isRegex': isRegex,
    };
  }

  static NotificationFilterRule fromJson(Map<String, dynamic> json) {
    return NotificationFilterRule(
      id: (json['id'] ?? '').toString(),
      packageName: (json['packageName'] ?? '').toString(),
      pattern: (json['pattern'] ?? '').toString(),
      enabled: json['enabled'] == true,
      isRegex: json['isRegex'] == true,
    );
  }
}

class NotificationFiltersConfig {
  final Map<String, bool> builtIn;
  final Map<String, List<NotificationFilterRule>> customByPackage;

  const NotificationFiltersConfig({
    required this.builtIn,
    required this.customByPackage,
  });

  static NotificationFiltersConfig defaults() {
    return NotificationFiltersConfig(
      builtIn: <String, bool>{
        'filter_empty': true,
        'filter_global_message_patterns': true,
        'whatsapp_filter_sending': true,
        'whatsapp_filter_message_summary': true,
        'whatsapp_filter_calls': true,
        'whatsapp_filter_backup': true,
        'whatsapp_filter_generic': true,
        'whatsapp_filter_checking': true,
        'instagram_filter_upload': true,
        'instagram_filter_story': true,
        'instagram_filter_calls': true,
      },
      customByPackage: <String, List<NotificationFilterRule>>{},
    );
  }

  bool isEnabled(String key, {required bool fallback}) {
    final v = builtIn[key];
    return v ?? fallback;
  }

  Map<String, dynamic> toJson() {
    return {
      'builtIn': builtIn,
      'customByPackage': customByPackage.map((k, v) => MapEntry(k, v.map((r) => r.toJson()).toList())),
    };
  }

  static NotificationFiltersConfig fromJson(Map<String, dynamic> json) {
    final builtInRaw = json['builtIn'];
    final Map<String, bool> builtIn = <String, bool>{};
    if (builtInRaw is Map) {
      for (final e in builtInRaw.entries) {
        builtIn[e.key.toString()] = e.value == true;
      }
    }

    final customRaw = json['customByPackage'];
    final Map<String, List<NotificationFilterRule>> customByPackage =
        <String, List<NotificationFilterRule>>{};
    if (customRaw is Map) {
      for (final e in customRaw.entries) {
        final pkg = e.key.toString();
        final v = e.value;
        if (v is List) {
          customByPackage[pkg] = v
              .whereType<Map>()
              .map((m) => NotificationFilterRule.fromJson(Map<String, dynamic>.from(m)))
              .toList();
        }
      }
    }

    final defaults = NotificationFiltersConfig.defaults();
    final mergedBuiltIn = <String, bool>{...defaults.builtIn, ...builtIn};
    return NotificationFiltersConfig(
      builtIn: mergedBuiltIn,
      customByPackage: customByPackage,
    );
  }

  NotificationFiltersConfig copyWith({
    Map<String, bool>? builtIn,
    Map<String, List<NotificationFilterRule>>? customByPackage,
  }) {
    return NotificationFiltersConfig(
      builtIn: builtIn ?? this.builtIn,
      customByPackage: customByPackage ?? this.customByPackage,
    );
  }
}

class NotificationFiltersConfigService {
  static const String _prefsKey = 'notification_filters_config_v1';
  static final MethodChannel _channel =
      const MethodChannel('com.example.connect/local_notifications');

  static NotificationFiltersConfig? _cache;
  static int _cacheAtMs = 0;
  static StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _remoteSub;
  static String? _remoteEmitterId;
  static String? _localDeviceId;
  static bool _applyingRemote = false;

  static const String _remoteConfigField = 'notification_filters_config_v1';
  static const String _remoteUpdatedAtField =
      'notification_filters_config_updatedAt';
  static const String _remoteUpdatedByField =
      'notification_filters_config_updatedBy';

  static Future<NotificationFiltersConfig> getConfig() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_cache != null && (now - _cacheAtMs) < 3000) {
      return _cache!;
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    NotificationFiltersConfig config;
    try {
      if (raw == null || raw.isEmpty) {
        config = NotificationFiltersConfig.defaults();
      } else {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          config = NotificationFiltersConfig.fromJson(Map<String, dynamic>.from(decoded));
        } else {
          config = NotificationFiltersConfig.defaults();
        }
      }
    } catch (_) {
      config = NotificationFiltersConfig.defaults();
    }

    _cache = config;
    _cacheAtMs = now;
    return config;
  }

  static Future<void> saveConfig(NotificationFiltersConfig config) async {
    await _saveConfigInternal(config, syncRemote: true);
  }

  static Future<void> _saveConfigInternal(
    NotificationFiltersConfig config, {
    required bool syncRemote,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(config.toJson()));
    _cache = config;
    _cacheAtMs = DateTime.now().millisecondsSinceEpoch;
    await applyNativeFilterSettingsFromConfig(config);
    if (syncRemote && !_applyingRemote) {
      await _pushConfigToRemoteIfActive(config);
    }
  }

  static Future<void> applyNativeFilterSettingsFromConfig(
    NotificationFiltersConfig config,
  ) async {
    try {
      await _channel.invokeMethod('updateNotificationSettings', {
        'filterWhatsappMessageSummaries':
            config.isEnabled('whatsapp_filter_message_summary', fallback: true),
        'filterWhatsappCheckingNewMessages':
            config.isEnabled('whatsapp_filter_checking', fallback: true),
      });
    } catch (_) {}
  }

  static Future<void> startRemoteSync() async {
    if (_remoteSub != null) return;

    final localDeviceId = await _getLocalDeviceId();
    final emitterId = await _resolveEmitterIdForSync(localDeviceId);
    if (emitterId.isEmpty) return;

    _remoteEmitterId = emitterId;

    await _ensureRemoteHasInitialConfig(
      emitterId: emitterId,
      localDeviceId: localDeviceId,
    );

    _remoteSub = FirebaseFirestore.instance
        .collection('dispositivos')
        .doc(emitterId)
        .snapshots()
        .listen((snapshot) async {
      final data = snapshot.data();
      if (data == null) return;

      final remoteConfigRaw = data[_remoteConfigField];
      if (remoteConfigRaw is! Map) return;

      final remoteUpdatedBy = (data[_remoteUpdatedByField] ?? '').toString();
      if (remoteUpdatedBy.isNotEmpty && remoteUpdatedBy == localDeviceId) {
        return;
      }

      final current = await getConfig();
      final currentJson = jsonEncode(current.toJson());
      final remoteJson = jsonEncode(Map<String, dynamic>.from(remoteConfigRaw));
      if (currentJson == remoteJson) return;

      NotificationFiltersConfig remoteConfig;
      try {
        remoteConfig = NotificationFiltersConfig.fromJson(
          Map<String, dynamic>.from(remoteConfigRaw),
        );
      } catch (_) {
        return;
      }

      _applyingRemote = true;
      try {
        await _saveConfigInternal(remoteConfig, syncRemote: false);
      } finally {
        _applyingRemote = false;
      }
    });
  }

  static Future<void> restartRemoteSync() async {
    await stopRemoteSync();
    await startRemoteSync();
  }

  static Future<void> stopRemoteSync() async {
    final sub = _remoteSub;
    _remoteSub = null;
    _remoteEmitterId = null;
    if (sub != null) {
      try {
        await sub.cancel();
      } catch (_) {}
    }
  }

  static Future<String> _getLocalDeviceId() async {
    final cached = _localDeviceId;
    if (cached != null && cached.isNotEmpty) return cached;
    final id = await FirebaseService().getDeviceId();
    _localDeviceId = id;
    return id;
  }

  static Future<String> _resolveEmitterIdForSync(String localDeviceId) async {
    try {
      final linked = await ReceptorService().getLinkedDeviceId();
      if (linked != null && linked.trim().isNotEmpty) return linked.trim();
    } catch (_) {}
    return localDeviceId.trim();
  }

  static Future<void> _ensureRemoteHasInitialConfig({
    required String emitterId,
    required String localDeviceId,
  }) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('dispositivos')
          .doc(emitterId)
          .get();
      final data = doc.data();
      if (data != null && data[_remoteConfigField] is Map) {
        return;
      }
      final current = await getConfig();
      await FirebaseFirestore.instance
          .collection('dispositivos')
          .doc(emitterId)
          .set({
        _remoteConfigField: current.toJson(),
        _remoteUpdatedAtField: FieldValue.serverTimestamp(),
        _remoteUpdatedByField: localDeviceId,
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  static Future<void> _pushConfigToRemoteIfActive(
    NotificationFiltersConfig config,
  ) async {
    final emitterId = _remoteEmitterId;
    if (emitterId == null || emitterId.isEmpty) return;
    final localDeviceId = await _getLocalDeviceId();
    try {
      await FirebaseFirestore.instance
          .collection('dispositivos')
          .doc(emitterId)
          .set({
        _remoteConfigField: config.toJson(),
        _remoteUpdatedAtField: FieldValue.serverTimestamp(),
        _remoteUpdatedByField: localDeviceId,
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  static String normalizedNotificationContent(Map<String, dynamic> notification) {
    String clean(dynamic v) {
      final raw = (v ?? '').toString().trim();
      final lower = raw.toLowerCase();
      if (lower == 'null' || lower == 'undefined') return '';
      return raw;
    }

    final List<String> allTexts = [
      clean(notification['title']),
      clean(notification['text']),
      clean(notification['bigText']),
      clean(notification['subText']),
      clean(notification['summaryText']),
      clean(notification['infoText']),
      clean(notification['contentInfo']),
      clean(notification['body']),
      clean(notification['mensaje']),
      clean(notification['contenido']),
      clean(notification['titulo']),
    ];

    final String allContent = allTexts.join(' ').toLowerCase();
    return allContent
        .replaceAll(RegExp(r'[áàäâ]'), 'a')
        .replaceAll(RegExp(r'[éèëê]'), 'e')
        .replaceAll(RegExp(r'[íìïî]'), 'i')
        .replaceAll(RegExp(r'[óòöô]'), 'o')
        .replaceAll(RegExp(r'[úùüû]'), 'u')
        .replaceAll(RegExp(r'[ñ]'), 'n')
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static bool shouldFilterByCustomRules({
    required NotificationFiltersConfig config,
    required String packageName,
    required String normalizedContent,
  }) {
    final rules = config.customByPackage[packageName];
    if (rules == null || rules.isEmpty) return false;

    for (final r in rules) {
      if (!r.enabled) continue;
      final p = r.pattern.trim();
      if (p.isEmpty) continue;
      if (r.isRegex) {
        try {
          final re = RegExp(p, caseSensitive: false);
          if (re.hasMatch(normalizedContent)) return true;
        } catch (_) {}
      } else {
        final normalizedPattern = p
            .toLowerCase()
            .replaceAll(RegExp(r'[áàäâ]'), 'a')
            .replaceAll(RegExp(r'[éèëê]'), 'e')
            .replaceAll(RegExp(r'[íìïî]'), 'i')
            .replaceAll(RegExp(r'[óòöô]'), 'o')
            .replaceAll(RegExp(r'[úùüû]'), 'u')
            .replaceAll(RegExp(r'[ñ]'), 'n')
            .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        if (normalizedPattern.isNotEmpty &&
            normalizedContent.contains(normalizedPattern)) {
          return true;
        }
      }
    }
    return false;
  }
}
