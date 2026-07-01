import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  // Canal de la bola flotante: se usa para avisar al lado nativo que recargue
  // su configuración cuando cambian las apps con conversación activa (el menú
  // de la bola decide con eso si mostrar el botón "Chats").
  static const MethodChannel _floatingBallChannel =
      MethodChannel('com.example.connect/floating_ball');

  // Espejo legible por el lado nativo de la lista de apps con conversación
  // activa (el plugin guarda la StringList con una codificación que el nativo
  // no lee fácilmente, así que lo duplicamos como JSON string).
  static const String KEY_CONVERSATION_ENABLED_PACKAGES_JSON =
      'conversation_enabled_packages_json';
  // Claves para las preferencias
  static const String KEY_USE_AS_RECEPTOR = 'use_as_receptor';
  static const String KEY_DISABLE_AUTO_REDIRECT = 'disable_auto_redirect'; // ✅ NUEVA CLAVE
  static const String KEY_KEEP_APP_ACTIVE = 'keep_app_active'; // ✅ NUEVA CLAVE PARA MANTENER APP ACTIVA
  static const String KEY_BLE_ENABLED = 'ble_enabled';
  static const String KEY_BLE_SERVICE_UUID = 'ble_service_uuid';
  static const String KEY_BLE_PEER_ADDRESS = 'ble_peer_address';
  static const String KEY_WIDGET_STYLE = 'widget_style';
  static const String KEY_WIDGET_TEXT_SP = 'widget_text_sp';
  static const String KEY_WIDGET_ICON_SP = 'widget_icon_sp';
  static const String KEY_PRIORITIZE_LOCAL_MEDIA = 'prioritize_local_media';
  static const String KEY_CONVERSATION_ENABLED_PACKAGES =
      'conversation_enabled_packages_v1';
  static const String KEY_STT_SOUND_ENABLED = 'stt_sound_enabled';

  // ── Perfil corporal del usuario (sensores de salud) ───────────────────────
  static const String KEY_BODY_NAME           = 'bodyProfile_name';
  static const String KEY_BODY_AGE            = 'bodyProfile_age';
  static const String KEY_BODY_SEX            = 'bodyProfile_sex'; // 'M' | 'F'
  static const String KEY_BODY_WEIGHT_KG      = 'bodyProfile_weight_kg';
  static const String KEY_BODY_HEIGHT_CM      = 'bodyProfile_height_cm';
  static const String KEY_BODY_FC_MAX         = 'bodyProfile_fc_max'; // 0 = calcular 220-edad
  static const String KEY_BODY_STEPS_GOAL     = 'bodyProfile_steps_goal';
  static const String KEY_BODY_HR_ALERT_HIGH  = 'bodyProfile_hr_alert_high';
  static const String KEY_BODY_HR_ALERT_LOW   = 'bodyProfile_hr_alert_low';

  static Future<Map<String, dynamic>> getBodyProfile() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'name':         prefs.getString(KEY_BODY_NAME) ?? '',
      'age':          prefs.getInt(KEY_BODY_AGE) ?? 30,
      'sex':          prefs.getString(KEY_BODY_SEX) ?? 'M',
      'weight_kg':    prefs.getDouble(KEY_BODY_WEIGHT_KG) ?? 70.0,
      'height_cm':    prefs.getDouble(KEY_BODY_HEIGHT_CM) ?? 170.0,
      'fc_max':       prefs.getInt(KEY_BODY_FC_MAX) ?? 0,
      'steps_goal':   prefs.getInt(KEY_BODY_STEPS_GOAL) ?? 10000,
      'hr_alert_high':prefs.getInt(KEY_BODY_HR_ALERT_HIGH) ?? 120,
      'hr_alert_low': prefs.getInt(KEY_BODY_HR_ALERT_LOW) ?? 50,
    };
  }

  static Future<void> saveBodyProfile(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    if (data['name'] != null) await prefs.setString(KEY_BODY_NAME, data['name']);
    if (data['age'] != null) await prefs.setInt(KEY_BODY_AGE, data['age']);
    if (data['sex'] != null) await prefs.setString(KEY_BODY_SEX, data['sex']);
    if (data['weight_kg'] != null) await prefs.setDouble(KEY_BODY_WEIGHT_KG, data['weight_kg']);
    if (data['height_cm'] != null) await prefs.setDouble(KEY_BODY_HEIGHT_CM, data['height_cm']);
    if (data['fc_max'] != null) await prefs.setInt(KEY_BODY_FC_MAX, data['fc_max']);
    if (data['steps_goal'] != null) await prefs.setInt(KEY_BODY_STEPS_GOAL, data['steps_goal']);
    if (data['hr_alert_high'] != null) await prefs.setInt(KEY_BODY_HR_ALERT_HIGH, data['hr_alert_high']);
    if (data['hr_alert_low'] != null) await prefs.setInt(KEY_BODY_HR_ALERT_LOW, data['hr_alert_low']);
  }

  static int calcFcMax(int age, int fcMaxManual) =>
      fcMaxManual > 0 ? fcMaxManual : (220 - age).clamp(100, 220);

  // Sonido de inicio/fin de grabación del modal STT (activado por defecto).
  static Future<bool> getSttSoundEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(KEY_STT_SOUND_ENABLED) ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<bool> saveSttSoundEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(KEY_STT_SOUND_ENABLED, enabled);
      return true;
    } catch (_) {
      return false;
    }
  }

  // Guardar preferencia de usar como receptor
  static Future<bool> saveUseAsReceptor(bool useAsReceptor) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(KEY_USE_AS_RECEPTOR, useAsReceptor);
      // print('Preferencia de usar como receptor guardada: $useAsReceptor');
      return true;
    } catch (e) {
      // print('Error al guardar preferencia de usar como receptor: $e');
      return false;
    }
  }
  
  // Obtener preferencia de usar como receptor
  static Future<bool> getUseAsReceptor() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(KEY_USE_AS_RECEPTOR) ?? false;
    } catch (e) {
      // print('Error al obtener preferencia de usar como receptor: $e');
      return false;
    }
  }

  // ✅ NUEVOS MÉTODOS PARA CONTROLAR EL BLOQUEO AUTOMÁTICO
  
  // Guardar preferencia para desactivar redirección automática
  static Future<bool> saveDisableAutoRedirect(bool disable) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(KEY_DISABLE_AUTO_REDIRECT, disable);
      // print('Preferencia de desactivar redirección automática guardada: $disable');
      return true;
    } catch (e) {
      // print('Error al guardar preferencia de desactivar redirección automática: $e');
      return false;
    }
  }
  
  // Obtener preferencia para desactivar redirección automática
  static Future<bool> getDisableAutoRedirect() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(KEY_DISABLE_AUTO_REDIRECT) ?? true;
    } catch (e) {
      // print('Error al obtener preferencia de desactivar redirección automática: $e');
      return false;
    }
  }

  // ✅ NUEVOS MÉTODOS PARA MANTENER LA APLICACIÓN ACTIVA
  
  // Guardar preferencia para mantener la aplicación activa
  static Future<bool> saveKeepAppActive(bool keepActive) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(KEY_KEEP_APP_ACTIVE, keepActive);
      // print('Preferencia de mantener aplicación activa guardada: $keepActive');
      return true;
    } catch (e) {
      // print('Error al guardar preferencia de mantener aplicación activa: $e');
      return false;
    }
  }
  
  // Obtener preferencia para mantener la aplicación activa
  static Future<bool> getKeepAppActive() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(KEY_KEEP_APP_ACTIVE) ?? false;
    } catch (e) {
      // print('Error al obtener preferencia de mantener aplicación activa: $e');
      return false;
    }
  }

  static Future<bool> saveBleEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(KEY_BLE_ENABLED, enabled);
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> getBleEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(KEY_BLE_ENABLED) ?? true;
    } catch (e) {
      return true;
    }
  }

  static Future<bool> saveBleServiceUuid(String uuid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(KEY_BLE_SERVICE_UUID, uuid);
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<String> getBleServiceUuid() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(KEY_BLE_SERVICE_UUID) ?? 'b3d9f8a0-6b6f-4d74-9a0c-0f5868e9a1f1';
    } catch (e) {
      return 'b3d9f8a0-6b6f-4d74-9a0c-0f5868e9a1f1';
    }
  }

  static Future<bool> saveBlePeerAddress(String address) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(KEY_BLE_PEER_ADDRESS, address);
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<String?> getBlePeerAddress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(KEY_BLE_PEER_ADDRESS);
    } catch (e) {
      return null;
    }
  }

  static Future<bool> saveWidgetStyle(int style) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(KEY_WIDGET_STYLE, style.clamp(1, 5).toInt());
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<int> getWidgetStyle() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getInt(KEY_WIDGET_STYLE) ?? 1).clamp(1, 5);
    } catch (e) {
      return 1;
    }
  }

  static Future<bool> saveWidgetTextSp(int sp) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(KEY_WIDGET_TEXT_SP, sp.clamp(10, 26).toInt());
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<int> getWidgetTextSp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getInt(KEY_WIDGET_TEXT_SP) ?? 16).clamp(10, 26);
    } catch (e) {
      return 16;
    }
  }

  static Future<bool> saveWidgetIconSp(int sp) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(KEY_WIDGET_ICON_SP, sp.clamp(18, 48).toInt());
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<int> getWidgetIconSp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getInt(KEY_WIDGET_ICON_SP) ?? 28).clamp(18, 48);
    } catch (e) {
      return 28;
    }
  }

  static Future<bool> savePrioritizeLocalMedia(bool prioritize) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(KEY_PRIORITIZE_LOCAL_MEDIA, prioritize);
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> getPrioritizeLocalMedia() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(KEY_PRIORITIZE_LOCAL_MEDIA) ?? false;
    } catch (e) {
      return false;
    }
  }

  static Future<List<String>> getConversationEnabledPackages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw =
          prefs.getStringList(KEY_CONVERSATION_ENABLED_PACKAGES) ?? const [];
      final normalized = raw
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();
      // Migración perezosa: asegura que el espejo JSON exista para usuarios
      // que ya tenían apps con conversación activa antes de esta función.
      await _syncConversationEnabledMirror(prefs, normalized);
      return normalized;
    } catch (e) {
      return const [];
    }
  }

  static Future<bool> saveConversationEnabledPackages(
    List<String> packageNames,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final normalized = packageNames
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();
      await prefs.setStringList(KEY_CONVERSATION_ENABLED_PACKAGES, normalized);
      await _syncConversationEnabledMirror(prefs, normalized);
      // Avisar al lado nativo para que recargue la configuración del menú de la
      // bola y actualice la visibilidad del botón "Chats".
      try {
        await _floatingBallChannel.invokeMethod('updateConfig');
      } catch (_) {}
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Duplica la lista como JSON string en una clave que el lado nativo lee con
  /// facilidad. Solo escribe si cambió, para evitar escrituras innecesarias.
  static Future<void> _syncConversationEnabledMirror(
    SharedPreferences prefs,
    List<String> normalized,
  ) async {
    try {
      final json = jsonEncode(normalized);
      final current = prefs.getString(KEY_CONVERSATION_ENABLED_PACKAGES_JSON);
      if (current != json) {
        await prefs.setString(KEY_CONVERSATION_ENABLED_PACKAGES_JSON, json);
      }
    } catch (_) {}
  }
}
