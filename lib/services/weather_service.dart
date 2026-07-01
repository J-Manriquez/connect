import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:connect/models/weather_models.dart';

/// Cliente de la API gratuita Open-Meteo (https://open-meteo.com).
///
/// No requiere API key. Dos endpoints:
///  - Geocoding: busca ciudades por nombre -> coordenadas.
///  - Forecast: clima actual + por horas + por días dadas las coordenadas.
///
/// Gratis para uso NO comercial.
class WeatherService {
  static const String _geocodingBase =
      'https://geocoding-api.open-meteo.com/v1/search';
  static const String _forecastBase = 'https://api.open-meteo.com/v1/forecast';

  static const Duration _timeout = Duration(seconds: 15);

  /// Busca ciudades por nombre. Por defecto prioriza Chile (`country=CL`) pero
  /// la API igual devuelve coincidencias globales si no hay locales.
  static Future<List<WeatherCity>> searchCities(
    String query, {
    String language = 'es',
    int count = 10,
  }) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return const [];

    final uri = Uri.parse(_geocodingBase).replace(queryParameters: {
      'name': trimmed,
      'count': '$count',
      'language': language,
      'format': 'json',
    });

    try {
      final res = await http.get(uri).timeout(_timeout);
      if (res.statusCode != 200) return const [];
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final results = body['results'] as List<dynamic>?;
      if (results == null) return const [];
      final cities = results
          .whereType<Map<String, dynamic>>()
          .map(WeatherCity.fromGeocoding)
          .toList();
      // Chile primero, manteniendo el orden de relevancia dentro de cada grupo.
      cities.sort((a, b) {
        final aCl = a.countryCode == 'CL' ? 0 : 1;
        final bCl = b.countryCode == 'CL' ? 0 : 1;
        return aCl.compareTo(bCl);
      });
      return cities;
    } catch (_) {
      return const [];
    }
  }

  /// Obtiene el clima de una ciudad. Lanza [WeatherException] en caso de error
  /// para que la UI pueda mostrar un mensaje y un botón de reintento.
  static Future<WeatherData> fetchWeather(WeatherCity city) async {
    final uri = Uri.parse(_forecastBase).replace(queryParameters: {
      'latitude': city.latitude.toString(),
      'longitude': city.longitude.toString(),
      'current':
          'temperature_2m,relative_humidity_2m,apparent_temperature,is_day,weather_code,wind_speed_10m',
      'hourly': 'temperature_2m,weather_code,precipitation_probability',
      'daily':
          'weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max',
      'timezone': 'auto',
      'forecast_days': '7',
    });

    final http.Response res;
    try {
      res = await http.get(uri).timeout(_timeout);
    } catch (_) {
      throw const WeatherException('Sin conexión con el servicio de clima.');
    }

    if (res.statusCode != 200) {
      throw WeatherException('Error del servicio de clima (${res.statusCode}).');
    }

    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final current = CurrentWeather.fromJson(
        (body['current'] as Map<String, dynamic>?) ?? const {},
      );

      final hourly = _parseHourly(body['hourly'] as Map<String, dynamic>?);
      final daily = _parseDaily(body['daily'] as Map<String, dynamic>?);

      return WeatherData(
        city: city,
        current: current,
        hourly: hourly,
        daily: daily,
        fetchedAt: DateTime.now(),
      );
    } catch (_) {
      throw const WeatherException('No se pudo leer la respuesta del clima.');
    }
  }

  /// Devuelve las próximas [maxHours] horas a partir de la hora actual.
  static List<HourlyWeather> _parseHourly(
    Map<String, dynamic>? hourly, {
    int maxHours = 24,
  }) {
    if (hourly == null) return const [];
    final times = (hourly['time'] as List<dynamic>?) ?? const [];
    final temps = (hourly['temperature_2m'] as List<dynamic>?) ?? const [];
    final codes = (hourly['weather_code'] as List<dynamic>?) ?? const [];
    final precs =
        (hourly['precipitation_probability'] as List<dynamic>?) ?? const [];

    final now = DateTime.now();
    final all = <HourlyWeather>[];
    for (var i = 0; i < times.length; i++) {
      final t = DateTime.tryParse(times[i].toString());
      if (t == null) continue;
      all.add(HourlyWeather(
        time: t,
        temperature: (temps.elementAtOrNull(i) as num?)?.toDouble() ?? 0,
        weatherCode: (codes.elementAtOrNull(i) as num?)?.toInt() ?? 0,
        precipitationProbability:
            (precs.elementAtOrNull(i) as num?)?.toInt() ?? 0,
      ));
    }

    // Empezar desde la hora actual (descartar horas ya pasadas de hoy).
    final upcoming = all
        .where((h) => h.time.isAfter(now.subtract(const Duration(hours: 1))))
        .take(maxHours)
        .toList();
    return upcoming.isEmpty ? all.take(maxHours).toList() : upcoming;
  }

  static List<DailyWeather> _parseDaily(Map<String, dynamic>? daily) {
    if (daily == null) return const [];
    final dates = (daily['time'] as List<dynamic>?) ?? const [];
    final maxs = (daily['temperature_2m_max'] as List<dynamic>?) ?? const [];
    final mins = (daily['temperature_2m_min'] as List<dynamic>?) ?? const [];
    final codes = (daily['weather_code'] as List<dynamic>?) ?? const [];
    final precs =
        (daily['precipitation_probability_max'] as List<dynamic>?) ?? const [];

    final out = <DailyWeather>[];
    for (var i = 0; i < dates.length; i++) {
      final d = DateTime.tryParse(dates[i].toString());
      if (d == null) continue;
      out.add(DailyWeather(
        date: d,
        tempMax: (maxs.elementAtOrNull(i) as num?)?.toDouble() ?? 0,
        tempMin: (mins.elementAtOrNull(i) as num?)?.toDouble() ?? 0,
        weatherCode: (codes.elementAtOrNull(i) as num?)?.toInt() ?? 0,
        precipitationProbability:
            (precs.elementAtOrNull(i) as num?)?.toInt() ?? 0,
      ));
    }
    return out;
  }
}

/// Error legible mostrable al usuario.
class WeatherException implements Exception {
  final String message;
  const WeatherException(this.message);

  @override
  String toString() => message;
}
