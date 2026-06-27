import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connect/models/notification_settings.dart';
import 'package:connect/services/firebase_service.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationSettingsService {
  final FirebaseService _firebaseService = FirebaseService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const MethodChannel _bleChannel = MethodChannel('com.example.connect/ble');
  static final Map<String, int> _lastDebugBySigMs = {};
  static int _lastRulesSyncMs = 0;

  Future<void> _relayDebugToEmisor(
    String source,
    String message, {
    String? sig,
    int throttleMs = 500,
  }) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final key = sig ?? '$source|$message';
    final last = _lastDebugBySigMs[key] ?? 0;
    if (throttleMs > 0 && (nowMs - last) < throttleMs) return;
    _lastDebugBySigMs[key] = nowMs;

    print('[$source][$nowMs] $message');
    // Llamada nativa directa y síncrona (sin Intent/startForegroundService):
    // no necesita chequear el estado del servidor BT antes, ya no-opea sola
    // si no hay peer conectado.
    try {
      await _bleChannel.invokeMethod('sendDebugLogToPeers', {
        'source': source,
        'message': message,
      });
    } catch (_) {}
  }

  Map<String, dynamic> _normalizeNotificationForMatch(
    Map<String, dynamic> notification,
  ) {
    String clean(dynamic v) {
      final raw = (v ?? '').toString().trim();
      final lower = raw.toLowerCase();
      if (lower == 'null' || lower == 'undefined') return '';
      return raw;
    }

    final title = clean(notification['title'] ?? notification['titulo']);
    final text = clean(notification['text'] ??
        notification['body'] ??
        notification['bigText'] ??
        notification['mensaje'] ??
        notification['contenido']);
    final packageName = clean(notification['packageName'] ?? notification['paquete']);
    final extrasRaw = notification['extras'];
    final extras = extrasRaw is Map ? Map<String, dynamic>.from(extrasRaw) : <String, dynamic>{};

    return {
      ...notification,
      'title': title,
      'text': text,
      'packageName': packageName,
      'extras': extras,
    };
  }

  String _normalizeForMatch(String s) {
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

  Future<void> _syncBlockedRulesToNativePrefsFromList(
    List<NotificationSettings> settings,
  ) async {
    try {
      final blocked = settings.where((s) => s.bloqueado).toList();
      final rules = <Map<String, dynamic>>[];
      for (final s in blocked) {
        final pkg = (s.notificationData['packageName'] ?? '').toString().trim();
        if (pkg.isEmpty) continue;
        final title = (s.notificationData['title'] ?? s.notificationData['titulo'] ?? '')
            .toString();
        final text = (s.notificationData['text'] ??
                s.notificationData['body'] ??
                s.notificationData['bigText'] ??
                s.notificationData['mensaje'] ??
                s.notificationData['contenido'] ??
                '')
            .toString();
        rules.add({
          'pkg': pkg,
          'titleNorm': _normalizeForMatch(title),
          'textNorm': _normalizeForMatch(text),
          'id': s.id,
        });
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('custom_block_rules_v1', jsonEncode(rules));
      await _relayDebugToEmisor(
        'receptor_bloqueo',
        'sync_rules blocked=${rules.length}',
        sig: 'sync_rules:${rules.length}',
        throttleMs: 0,
      );
    } catch (_) {}
  }

  Future<void> _maybeSyncBlockedRulesToNativePrefs(
    List<NotificationSettings> settings,
  ) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (_lastRulesSyncMs > 0 && (nowMs - _lastRulesSyncMs) < 10000) return;
    _lastRulesSyncMs = nowMs;
    await _syncBlockedRulesToNativePrefsFromList(settings);
  }

  // Obtener todas las configuraciones de notificaciones para el dispositivo actual
  Future<List<NotificationSettings>> getAllNotificationSettings() async {
    try {
      final deviceId = await _firebaseService.getDeviceId();
      final querySnapshot = await _firestore
          .collection('dispositivos')
          .doc(deviceId)
          .collection('notifSettings')
          .orderBy('updatedAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => NotificationSettings.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      // print('Error al obtener configuraciones de notificaciones: $e');
      return [];
    }
  }

  // Guardar una nueva configuración de notificación
  Future<bool> saveNotificationSettings(NotificationSettings settings) async {
    try {
      final deviceId = await _firebaseService.getDeviceId();
      await _firestore
          .collection('dispositivos')
          .doc(deviceId)
          .collection('notifSettings')
          .doc(settings.id)
          .set(settings.toMap());

      // print('Configuración de notificación guardada: ${settings.id}');
      await _syncBlockedRulesToNativePrefsFromList(await getAllNotificationSettings());
      return true;
    } catch (e) {
      // print('Error al guardar configuración de notificación: $e');
      return false;
    }
  }

  // Actualizar una configuración existente
  Future<bool> updateNotificationSettings(NotificationSettings settings) async {
    try {
      final deviceId = await _firebaseService.getDeviceId();
      final updatedSettings = settings.copyWith();
      
      await _firestore
          .collection('dispositivos')
          .doc(deviceId)
          .collection('notifSettings')
          .doc(settings.id)
          .update(updatedSettings.toMap());

      // print('Configuración de notificación actualizada: ${settings.id}');
      await _syncBlockedRulesToNativePrefsFromList(await getAllNotificationSettings());
      return true;
    } catch (e) {
      // print('Error al actualizar configuración de notificación: $e');
      return false;
    }
  }

  // Eliminar una configuración de notificación
  Future<bool> deleteNotificationSettings(String settingsId) async {
    try {
      final deviceId = await _firebaseService.getDeviceId();
      await _firestore
          .collection('dispositivos')
          .doc(deviceId)
          .collection('notifSettings')
          .doc(settingsId)
          .delete();

      // print('Configuración de notificación eliminada: $settingsId');
      await _syncBlockedRulesToNativePrefsFromList(await getAllNotificationSettings());
      return true;
    } catch (e) {
      // print('Error al eliminar configuración de notificación: $e');
      return false;
    }
  }

  // Obtener una configuración específica por ID
  Future<NotificationSettings?> getNotificationSettings(String settingsId) async {
    try {
      final deviceId = await _firebaseService.getDeviceId();
      final doc = await _firestore
          .collection('dispositivos')
          .doc(deviceId)
          .collection('notifSettings')
          .doc(settingsId)
          .get();

      if (doc.exists && doc.data() != null) {
        return NotificationSettings.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      // print('Error al obtener configuración de notificación: $e');
      return null;
    }
  }

  // Verificar si una notificación debe ser bloqueada
  Future<bool> shouldBlockNotification(Map<String, dynamic> notification) async {
    try {
      final normalized = _normalizeNotificationForMatch(notification);
      final settings = await getAllNotificationSettings();
      await _maybeSyncBlockedRulesToNativePrefs(settings);

      final pkg = (normalized['packageName'] ?? '').toString().trim();
      final title = (normalized['title'] ?? '').toString().trim();
      final text = (normalized['text'] ?? '').toString().trim();
      final candidates = settings.where((s) => s.bloqueado).toList();
      final pkgCandidates = candidates.where((s) {
        final spkg = (s.notificationData['packageName'] ?? '').toString().trim();
        return spkg.isEmpty || spkg == pkg;
      }).toList();

      if (pkgCandidates.isNotEmpty) {
        final tShort = title.length > 60 ? title.substring(0, 60) : title;
        final xShort = text.length > 80 ? text.substring(0, 80) : text;
        await _relayDebugToEmisor(
          'receptor_bloqueo',
          "check pkg='$pkg' title='$tShort' text='$xShort' blockedRules=${pkgCandidates.length}",
          sig: 'check:$pkg:$tShort:$xShort:${pkgCandidates.length}',
          throttleMs: 250,
        );
      }
      
      for (final setting in pkgCandidates) {
        final matches = setting.matchesNotification(normalized);
        if (matches) {
          final ruleTitle = (setting.notificationData['title'] ?? '').toString();
          final ruleText = (setting.notificationData['text'] ?? '').toString();
          final ruleExtras = setting.notificationData['extras'] is Map
              ? Map<String, dynamic>.from(setting.notificationData['extras'] as Map)
              : <String, dynamic>{};
          await _relayDebugToEmisor(
            'receptor_bloqueo',
            "BLOCK ruleId='${setting.id}' pkg='$pkg' ruleTitle='${ruleTitle.length > 40 ? ruleTitle.substring(0, 40) : ruleTitle}' ruleText='${ruleText.length > 60 ? ruleText.substring(0, 60) : ruleText}' ruleExtrasKeys=${ruleExtras.keys.length}",
            sig: 'block:${setting.id}:$pkg',
            throttleMs: 0,
          );
          return true;
        }
      }

      if (pkgCandidates.isNotEmpty) {
        int shown = 0;
        for (final setting in pkgCandidates) {
          if (shown >= 3) break;
          final rulePkg = (setting.notificationData['packageName'] ?? '').toString().trim();
          final ruleTitle = (setting.notificationData['title'] ?? setting.notificationData['titulo'] ?? '')
              .toString()
              .trim();
          final ruleText = (setting.notificationData['text'] ??
                  setting.notificationData['body'] ??
                  setting.notificationData['bigText'] ??
                  setting.notificationData['mensaje'] ??
                  setting.notificationData['contenido'] ??
                  '')
              .toString()
              .trim();
          final ruleExtras = setting.notificationData['extras'] is Map
              ? Map<String, dynamic>.from(setting.notificationData['extras'] as Map)
              : <String, dynamic>{};

          final pkgOk = rulePkg.isEmpty || rulePkg == pkg;
          final titleOk = ruleTitle.isEmpty ||
              title.toLowerCase().contains(ruleTitle.toLowerCase());
          final textOk = ruleText.isEmpty ||
              text.toLowerCase().contains(ruleText.toLowerCase());
          bool extrasOk = true;
          if (ruleExtras.isNotEmpty) {
            final extras = normalized['extras'] is Map
                ? Map<String, dynamic>.from(normalized['extras'] as Map)
                : <String, dynamic>{};
            for (final k in ruleExtras.keys) {
              final expected = ruleExtras[k];
              if (expected == null) continue;
              final actual = extras[k];
              if (actual == null) {
                extrasOk = false;
                break;
              }
              if ((expected is num || expected is bool) && actual != expected) {
                extrasOk = false;
                break;
              }
              final expectedStr = expected.toString().trim();
              final actualStr = actual.toString().trim();
              if (expectedStr.isNotEmpty && actualStr != expectedStr) {
                extrasOk = false;
                break;
              }
            }
          }

          await _relayDebugToEmisor(
            'receptor_bloqueo',
            "NO_MATCH ruleId='${setting.id}' pkgOk=$pkgOk titleOk=$titleOk textOk=$textOk extrasOk=$extrasOk",
            sig: 'no_match:${setting.id}:$pkg',
            throttleMs: 1200,
          );
          shown++;
        }
      }
      
      return false;
    } catch (e) {
      // print('Error al verificar bloqueo de notificación: $e');
      return false;
    }
  }

  // Obtener configuración de vibración personalizada para una notificación
  Future<Map<String, dynamic>?> getCustomVibrationConfig(Map<String, dynamic> notification) async {
    try {
      final settings = await getAllNotificationSettings();
      
      for (final setting in settings) {
        if (setting.vibrationEnabled && setting.matchesNotification(notification)) {
          final vibrationConfig = setting.additionalData['vibration'];
          if (vibrationConfig != null) {
            // print('Configuración de vibración personalizada encontrada: ${setting.id}');
            return Map<String, dynamic>.from(vibrationConfig);
          }
        }
      }
      
      return null;
    } catch (e) {
      // print('Error al obtener configuración de vibración: $e');
      return null;
    }
  }

  // Obtener configuración de sonido personalizada para una notificación
  Future<Map<String, dynamic>?> getCustomSoundConfig(Map<String, dynamic> notification) async {
    try {
      final settings = await getAllNotificationSettings();
      
      for (final setting in settings) {
        if (setting.soundEnabled && setting.matchesNotification(notification)) {
          final soundConfig = setting.additionalData['sound'];
          if (soundConfig != null) {
            // print('Configuración de sonido personalizada encontrada: ${setting.id}');
            return Map<String, dynamic>.from(soundConfig);
          }
        }
      }
      
      return null;
    } catch (e) {
      // print('Error al obtener configuración de sonido: $e');
      return null;
    }
  }

  // Actualizar solo la configuración de vibración
  Future<bool> updateVibrationConfig(String settingsId, Map<String, dynamic> vibrationConfig) async {
    try {
      final deviceId = await _firebaseService.getDeviceId();
      
      await _firestore
          .collection('dispositivos')
          .doc(deviceId)
          .collection('notifSettings')
          .doc(settingsId)
          .update({
            'vibrationEnabled': true,
            'additionalData.vibration': vibrationConfig,
            'updatedAt': Timestamp.now(),
          });

      // print('Configuración de vibración actualizada: $settingsId');
      return true;
    } catch (e) {
      // print('Error al actualizar configuración de vibración: $e');
      return false;
    }
  }

  // Actualizar solo la configuración de sonido
  Future<bool> updateSoundConfig(String settingsId, Map<String, dynamic> soundConfig) async {
    try {
      final deviceId = await _firebaseService.getDeviceId();
      
      await _firestore
          .collection('dispositivos')
          .doc(deviceId)
          .collection('notifSettings')
          .doc(settingsId)
          .update({
            'soundEnabled': true,
            'additionalData.sound': soundConfig,
            'updatedAt': Timestamp.now(),
          });

      // print('Configuración de sonido actualizada: $settingsId');
      return true;
    } catch (e) {
      // print('Error al actualizar configuración de sonido: $e');
      return false;
    }
  }

  // Stream para escuchar cambios en las configuraciones
  Stream<List<NotificationSettings>> watchNotificationSettings() {
    return _firebaseService.getDeviceId().asStream().asyncExpand((deviceId) {
      return _firestore
          .collection('dispositivos')
          .doc(deviceId)
          .collection('notifSettings')
          .orderBy('updatedAt', descending: true)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs
                .map((doc) => NotificationSettings.fromMap(doc.data(), doc.id))
                .toList();
          });
    }).handleError((error) {
      // print('Error en stream de configuraciones: $error');
      return <NotificationSettings>[];
    });
  }

  // Verificar si existe una configuración para una notificación específica
  Future<NotificationSettings?> findMatchingSettings(Map<String, dynamic> notification) async {
    try {
      final settings = await getAllNotificationSettings();
      
      for (final setting in settings) {
        if (setting.matchesNotification(notification)) {
          return setting;
        }
      }
      
      return null;
    } catch (e) {
      // print('Error al buscar configuración coincidente: $e');
      return null;
    }
  }
}
