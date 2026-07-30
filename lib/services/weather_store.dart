import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:connect/models/weather_models.dart';
import 'package:connect/services/weather_service.dart';

/// Fuente única de datos del widget de clima.
///
/// Responsabilidades:
///  - Lista de ciudades guardadas por el usuario (para el dropdown).
///  - Ciudad seleccionada actualmente.
///  - Caché LOCAL de los datos del clima por ciudad: al actualizar se BORRA el
///    caché viejo y se guarda el nuevo, así no crece el tamaño de la app y los
///    datos solo se refrescan cuando el usuario lo pide.
///  - Snapshot que el widget nativo de la pantalla de inicio lee para pintarse.
///
/// Las claves se guardan con `shared_preferences`, por lo que el lado nativo las
/// ve con el prefijo `flutter.` (igual que el resto de la config de widgets).
class WeatherStore {
  static const String _kCities = 'weather_cities_json';
  static const String _kSelectedKey = 'weather_selected_key';
  static const String _kDataPrefix = 'weather_data_'; // + cityKey
  static const String _kWidgetSnapshot = 'weather_widget_json';

  // Canal para pedirle al lado nativo que repinte el widget de la pantalla de
  // inicio tras refrescar los datos.
  static const MethodChannel _bleChannel =
      MethodChannel('com.example.connect/ble');

  /// Clave estable por ciudad a partir de sus coordenadas.
  static String cityKey(WeatherCity c) =>
      '${c.latitude.toStringAsFixed(4)},${c.longitude.toStringAsFixed(4)}';

  // ===== Ciudades guardadas =====

  static Future<List<WeatherCity>> getSavedCities() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kCities);
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(WeatherCity.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _saveCities(List<WeatherCity> cities) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kCities,
      jsonEncode(cities.map((c) => c.toJson()).toList()),
    );
  }

  /// Añade (o reutiliza) una ciudad y la deja como seleccionada. Devuelve la
  /// lista actualizada.
  static Future<List<WeatherCity>> addCity(WeatherCity city) async {
    final cities = await getSavedCities();
    final key = cityKey(city);
    final exists = cities.any((c) => cityKey(c) == key);
    if (!exists) cities.add(city);
    await _saveCities(cities);
    await setSelectedCity(city);
    return cities;
  }

  /// Quita una ciudad y borra su caché.
  static Future<List<WeatherCity>> removeCity(WeatherCity city) async {
    final cities = await getSavedCities();
    final key = cityKey(city);
    cities.removeWhere((c) => cityKey(c) == key);
    await _saveCities(cities);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_kDataPrefix$key');

    if (cities.isEmpty) {
      await prefs.remove(_kSelectedKey);
      await prefs.remove(_kWidgetSnapshot);
      await _notifyWidget();
      return cities;
    }

    // Si era la seleccionada, mover la selección a la primera disponible
    // (setSelectedCity ya reconstruye el snapshot); si no, reconstruir igual
    // para que el snapshot deje de incluir la ciudad eliminada.
    final selected = await getSelectedCity();
    if (selected == null || cityKey(selected) == key) {
      await setSelectedCity(cities.first);
    } else {
      await rebuildWidgetSnapshot();
    }
    return cities;
  }

  // ===== Selección =====

  static Future<WeatherCity?> getSelectedCity() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(_kSelectedKey);
    final cities = await getSavedCities();
    if (cities.isEmpty) return null;
    if (key == null) return cities.first;
    return cities.firstWhere(
      (c) => cityKey(c) == key,
      orElse: () => cities.first,
    );
  }

  static Future<void> setSelectedCity(WeatherCity city) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSelectedKey, cityKey(city));
    await rebuildWidgetSnapshot();
  }

  // ===== Caché de datos por ciudad =====

  static Future<WeatherData?> getCachedWeather(WeatherCity city) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_kDataPrefix${cityKey(city)}');
      if (raw == null || raw.isEmpty) return null;
      return WeatherData.fromCache(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Refresca desde la red: BORRA el caché anterior de esa ciudad y guarda el
  /// nuevo. Si la ciudad es la seleccionada, actualiza el snapshot del widget
  /// nativo. Lanza [WeatherException] si falla la red.
  static Future<WeatherData> refreshWeather(WeatherCity city) async {
    final data = await WeatherService.fetchWeather(city);
    final prefs = await SharedPreferences.getInstance();
    final dataKey = '$_kDataPrefix${cityKey(city)}';
    await prefs.remove(dataKey); // borra el viejo
    await prefs.setString(dataKey, jsonEncode(data.toCache())); // guarda el nuevo

    await rebuildWidgetSnapshot();
    return data;
  }

  // ===== Snapshot para el widget nativo =====

  static const List<String> _dayNames = [
    'Lun',
    'Mar',
    'Mié',
    'Jue',
    'Vie',
    'Sáb',
    'Dom',
  ];

  /// Reconstruye el snapshot que lee el widget nativo: incluye TODAS las
  /// ciudades guardadas que ya tienen datos en caché, cada una con su clima
  /// actual + pronóstico por horas + por días (para las 3 vistas del widget).
  /// Luego pide al lado nativo que repinte.
  static Future<void> rebuildWidgetSnapshot() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cities = await getSavedCities();
      final selected = await getSelectedCity();
      final selectedK = selected != null ? cityKey(selected) : null;

      final citiesJson = <Map<String, dynamic>>[];
      int selectedIndex = 0;
      for (final city in cities) {
        final data = await getCachedWeather(city);
        if (data == null) continue; // sin caché aún: se omite
        if (cityKey(city) == selectedK) selectedIndex = citiesJson.length;
        citiesJson.add(_cityToSnapshot(data));
      }

      final snapshot = {
        'updatedAtMs': DateTime.now().millisecondsSinceEpoch,
        'selectedIndex': selectedIndex,
        'cities': citiesJson,
      };
      await prefs.setString(_kWidgetSnapshot, jsonEncode(snapshot));
    } catch (_) {}
    await _notifyWidget();
  }

  static Map<String, dynamic> _cityToSnapshot(WeatherData data) {
    final c = data.current;
    final info = WeatherCodeInfo.from(c.weatherCode, isDay: c.isDay);
    final now = DateTime.now();

    final hourly = data.hourly.take(12).toList();
    final daily = data.daily.take(7).toList();

    return {
      'name': data.city.name,
      'temp': c.temperature.round(),
      'desc': info.description,
      'emoji': WeatherCodeInfo.emojiFor(c.weatherCode, isDay: c.isDay),
      'apparent': c.apparentTemperature.round(),
      'humidity': c.humidity,
      'wind': c.windSpeed.round(),
      // Fondo dinámico del widget nativo (estático según condición + día/noche).
      'bg': WeatherCodeInfo.category(c.weatherCode),
      'isDay': c.isDay ? 1 : 0,
      'hourly': [
        for (final h in hourly)
          {
            'label': (h.time.hour == now.hour && h.time.day == now.day)
                ? 'Ahora'
                : '${h.time.hour.toString().padLeft(2, '0')}:00',
            'emoji': WeatherCodeInfo.emojiFor(h.weatherCode,
                isDay: h.time.hour >= 7 && h.time.hour < 20),
            'bg': WeatherCodeInfo.category(h.weatherCode),
            'isDay': (h.time.hour >= 7 && h.time.hour < 20) ? 1 : 0,
            'temp': h.temperature.round(),
            'pp': h.precipitationProbability,
          }
      ],
      'daily': [
        for (var i = 0; i < daily.length; i++)
          {
            'day': i == 0
                ? 'Hoy'
                : _dayNames[(daily[i].date.weekday - 1) % 7],
            'emoji': WeatherCodeInfo.emojiFor(daily[i].weatherCode),
            'bg': WeatherCodeInfo.category(daily[i].weatherCode),
            'max': daily[i].tempMax.round(),
            'min': daily[i].tempMin.round(),
            'pp': daily[i].precipitationProbability,
          }
      ],
    };
  }

  /// Pide al lado nativo que repinte el widget sin tocar el snapshot de datos.
  /// La usa [WeatherWidgetConfigService] tras cambiar solo la personalización.
  static Future<void> notifyWidget() => _notifyWidget();

  static Future<void> _notifyWidget() async {
    try {
      await _bleChannel.invokeMethod('updateWeatherWidget');
    } catch (_) {}
  }
}
