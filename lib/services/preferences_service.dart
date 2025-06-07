import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  // Claves para las preferencias
  static const String KEY_USE_AS_RECEPTOR = 'use_as_receptor';
  
  // Guardar preferencia de usar como receptor
  static Future<bool> saveUseAsReceptor(bool useAsReceptor) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(KEY_USE_AS_RECEPTOR, useAsReceptor);
      //print('Preferencia de usar como receptor guardada: $useAsReceptor');
      return true;
    } catch (e) {
      print('Error al guardar preferencia de usar como receptor: $e');
      return false;
    }
  }
  
  // Obtener preferencia de usar como receptor
  static Future<bool> getUseAsReceptor() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(KEY_USE_AS_RECEPTOR) ?? false;
    } catch (e) {
      print('Error al obtener preferencia de usar como receptor: $e');
      return false;
    }
  }
}