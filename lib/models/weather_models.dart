import 'package:flutter/material.dart';

/// Una ciudad devuelta por el geocoding de Open-Meteo (o seleccionada por el
/// usuario). Se persiste como JSON en [PreferencesService].
class WeatherCity {
  final String name;
  final double latitude;
  final double longitude;
  final String? admin1; // Región / estado
  final String? country;
  final String? countryCode; // p. ej. 'CL'
  final String? timezone;

  const WeatherCity({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.admin1,
    this.country,
    this.countryCode,
    this.timezone,
  });

  /// Texto legible: "Valparaíso, Valparaíso, Chile".
  String get displayName {
    final parts = <String>[name];
    if (admin1 != null && admin1!.isNotEmpty && admin1 != name) {
      parts.add(admin1!);
    }
    if (country != null && country!.isNotEmpty) parts.add(country!);
    return parts.join(', ');
  }

  factory WeatherCity.fromGeocoding(Map<String, dynamic> json) {
    return WeatherCity(
      name: (json['name'] ?? '').toString(),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      admin1: json['admin1']?.toString(),
      country: json['country']?.toString(),
      countryCode: json['country_code']?.toString(),
      timezone: json['timezone']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'admin1': admin1,
        'country': country,
        'country_code': countryCode,
        'timezone': timezone,
      };

  factory WeatherCity.fromJson(Map<String, dynamic> json) {
    return WeatherCity(
      name: (json['name'] ?? '').toString(),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      admin1: json['admin1']?.toString(),
      country: json['country']?.toString(),
      countryCode: json['country_code']?.toString(),
      timezone: json['timezone']?.toString(),
    );
  }
}

/// Clima actual de la ciudad.
class CurrentWeather {
  final double temperature;
  final double apparentTemperature;
  final int humidity;
  final double windSpeed;
  final int weatherCode;
  final bool isDay;

  const CurrentWeather({
    required this.temperature,
    required this.apparentTemperature,
    required this.humidity,
    required this.windSpeed,
    required this.weatherCode,
    required this.isDay,
  });

  factory CurrentWeather.fromJson(Map<String, dynamic> json) {
    return CurrentWeather(
      temperature: (json['temperature_2m'] as num?)?.toDouble() ?? 0,
      apparentTemperature:
          (json['apparent_temperature'] as num?)?.toDouble() ?? 0,
      humidity: (json['relative_humidity_2m'] as num?)?.toInt() ?? 0,
      windSpeed: (json['wind_speed_10m'] as num?)?.toDouble() ?? 0,
      weatherCode: (json['weather_code'] as num?)?.toInt() ?? 0,
      isDay: ((json['is_day'] as num?)?.toInt() ?? 1) == 1,
    );
  }

  /// Serialización para el caché local (usa las mismas claves que la API para
  /// poder reusar [fromJson]).
  Map<String, dynamic> toCache() => {
        'temperature_2m': temperature,
        'apparent_temperature': apparentTemperature,
        'relative_humidity_2m': humidity,
        'wind_speed_10m': windSpeed,
        'weather_code': weatherCode,
        'is_day': isDay ? 1 : 0,
      };
}

/// Un punto horario del pronóstico.
class HourlyWeather {
  final DateTime time;
  final double temperature;
  final int weatherCode;
  final int precipitationProbability;

  const HourlyWeather({
    required this.time,
    required this.temperature,
    required this.weatherCode,
    required this.precipitationProbability,
  });

  Map<String, dynamic> toCache() => {
        't': time.toIso8601String(),
        'temp': temperature,
        'code': weatherCode,
        'pp': precipitationProbability,
      };

  factory HourlyWeather.fromCache(Map<String, dynamic> json) => HourlyWeather(
        time: DateTime.tryParse(json['t']?.toString() ?? '') ?? DateTime.now(),
        temperature: (json['temp'] as num?)?.toDouble() ?? 0,
        weatherCode: (json['code'] as num?)?.toInt() ?? 0,
        precipitationProbability: (json['pp'] as num?)?.toInt() ?? 0,
      );
}

/// Un día del pronóstico.
class DailyWeather {
  final DateTime date;
  final double tempMax;
  final double tempMin;
  final int weatherCode;
  final int precipitationProbability;

  const DailyWeather({
    required this.date,
    required this.tempMax,
    required this.tempMin,
    required this.weatherCode,
    required this.precipitationProbability,
  });

  Map<String, dynamic> toCache() => {
        'd': date.toIso8601String(),
        'max': tempMax,
        'min': tempMin,
        'code': weatherCode,
        'pp': precipitationProbability,
      };

  factory DailyWeather.fromCache(Map<String, dynamic> json) => DailyWeather(
        date: DateTime.tryParse(json['d']?.toString() ?? '') ?? DateTime.now(),
        tempMax: (json['max'] as num?)?.toDouble() ?? 0,
        tempMin: (json['min'] as num?)?.toDouble() ?? 0,
        weatherCode: (json['code'] as num?)?.toInt() ?? 0,
        precipitationProbability: (json['pp'] as num?)?.toInt() ?? 0,
      );
}

/// Paquete completo de datos del clima para una ciudad.
class WeatherData {
  final WeatherCity city;
  final CurrentWeather current;
  final List<HourlyWeather> hourly;
  final List<DailyWeather> daily;
  final DateTime fetchedAt;

  const WeatherData({
    required this.city,
    required this.current,
    required this.hourly,
    required this.daily,
    required this.fetchedAt,
  });

  /// Serializa todo el paquete para el caché local.
  Map<String, dynamic> toCache() => {
        'city': city.toJson(),
        'current': current.toCache(),
        'hourly': hourly.map((h) => h.toCache()).toList(),
        'daily': daily.map((d) => d.toCache()).toList(),
        'fetchedAt': fetchedAt.toIso8601String(),
      };

  factory WeatherData.fromCache(Map<String, dynamic> json) => WeatherData(
        city: WeatherCity.fromJson(json['city'] as Map<String, dynamic>),
        current: CurrentWeather.fromJson(
            (json['current'] as Map<String, dynamic>?) ?? const {}),
        hourly: ((json['hourly'] as List<dynamic>?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(HourlyWeather.fromCache)
            .toList(),
        daily: ((json['daily'] as List<dynamic>?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(DailyWeather.fromCache)
            .toList(),
        fetchedAt: DateTime.tryParse(json['fetchedAt']?.toString() ?? '') ??
            DateTime.now(),
      );
}

/// Traducción de los códigos WMO (weather_code de Open-Meteo) a texto en
/// español, icono y un color representativo. https://open-meteo.com/en/docs
class WeatherCodeInfo {
  final String description;
  final IconData icon;
  final Color color;

  const WeatherCodeInfo(this.description, this.icon, this.color);

  /// Categoría visual del clima (para fondos dinámicos). Una de:
  /// 'clear', 'clouds', 'fog', 'rain', 'snow', 'thunder'.
  static String category(int code) {
    switch (code) {
      case 0:
      case 1:
        return 'clear';
      case 2:
      case 3:
        return 'clouds';
      case 45:
      case 48:
        return 'fog';
      case 51:
      case 53:
      case 55:
      case 56:
      case 57:
      case 61:
      case 63:
      case 65:
      case 66:
      case 67:
      case 80:
      case 81:
      case 82:
        return 'rain';
      case 71:
      case 73:
      case 75:
      case 77:
      case 85:
      case 86:
        return 'snow';
      case 95:
      case 96:
      case 99:
        return 'thunder';
      default:
        return 'clouds';
    }
  }

  /// Par de colores [arriba, abajo] del degradado de fondo según el clima y si
  /// es de día o de noche. Lo usan tanto el fondo animado de Flutter como el
  /// snapshot del widget nativo, para que ambos coincidan.
  static List<Color> gradientColors(int code, {bool isDay = true}) {
    switch (category(code)) {
      case 'clear':
        return isDay
            ? const [Color(0xFF4FA4E8), Color(0xFF2D6FB5)]
            : const [Color(0xFF1B2A4A), Color(0xFF0B1020)];
      case 'clouds':
        return isDay
            ? const [Color(0xFF7E96AB), Color(0xFF4A5D70)]
            : const [Color(0xFF2A3340), Color(0xFF161C24)];
      case 'fog':
        return isDay
            ? const [Color(0xFF9AA7B0), Color(0xFF6B7780)]
            : const [Color(0xFF2B333A), Color(0xFF181D22)];
      case 'rain':
        return isDay
            ? const [Color(0xFF4A6075, ), Color(0xFF2A3845)]
            : const [Color(0xFF1E2730), Color(0xFF10151B)];
      case 'snow':
        return isDay
            ? const [Color(0xFF8FB4D6), Color(0xFF5E7E9C)]
            : const [Color(0xFF26303C), Color(0xFF141A21)];
      case 'thunder':
        return const [Color(0xFF2A2E45), Color(0xFF14161F)];
      default:
        return const [Color(0xFF4A6FA5), Color(0xFF2C3E73)];
    }
  }

  /// Emoji representativo del código WMO. Se usa en el widget nativo de la
  /// pantalla de inicio (RemoteViews no admite los iconos de Flutter).
  static String emojiFor(int code, {bool isDay = true}) {
    switch (code) {
      case 0:
      case 1:
        return isDay ? '☀️' : '🌙';
      case 2:
        return isDay ? '⛅' : '☁️';
      case 3:
        return '☁️';
      case 45:
      case 48:
        return '🌫️';
      case 51:
      case 53:
      case 55:
      case 56:
      case 57:
        return '🌦️';
      case 61:
      case 63:
      case 65:
      case 66:
      case 67:
      case 80:
      case 81:
      case 82:
        return '🌧️';
      case 71:
      case 73:
      case 75:
      case 77:
      case 85:
      case 86:
        return '❄️';
      case 95:
      case 96:
      case 99:
        return '⛈️';
      default:
        return '🌡️';
    }
  }

  /// [isDay] cambia el icono entre sol y luna para cielo despejado.
  static WeatherCodeInfo from(int code, {bool isDay = true}) {
    switch (code) {
      case 0:
        return WeatherCodeInfo(
          'Despejado',
          isDay ? Icons.wb_sunny : Icons.nightlight_round,
          isDay ? const Color(0xFFFFB300) : const Color(0xFF5C6BC0),
        );
      case 1:
        return WeatherCodeInfo(
          'Mayormente despejado',
          isDay ? Icons.wb_sunny : Icons.nightlight_round,
          isDay ? const Color(0xFFFFB300) : const Color(0xFF5C6BC0),
        );
      case 2:
        return const WeatherCodeInfo(
          'Parcialmente nublado',
          Icons.wb_cloudy,
          Color(0xFF90A4AE),
        );
      case 3:
        return const WeatherCodeInfo(
          'Nublado',
          Icons.cloud,
          Color(0xFF78909C),
        );
      case 45:
      case 48:
        return const WeatherCodeInfo(
          'Niebla',
          Icons.foggy,
          Color(0xFFB0BEC5),
        );
      case 51:
      case 53:
      case 55:
        return const WeatherCodeInfo(
          'Llovizna',
          Icons.grain,
          Color(0xFF4FC3F7),
        );
      case 56:
      case 57:
        return const WeatherCodeInfo(
          'Llovizna helada',
          Icons.ac_unit,
          Color(0xFF4FC3F7),
        );
      case 61:
      case 63:
      case 65:
        return const WeatherCodeInfo(
          'Lluvia',
          Icons.umbrella,
          Color(0xFF29B6F6),
        );
      case 66:
      case 67:
        return const WeatherCodeInfo(
          'Lluvia helada',
          Icons.ac_unit,
          Color(0xFF29B6F6),
        );
      case 71:
      case 73:
      case 75:
        return const WeatherCodeInfo(
          'Nieve',
          Icons.ac_unit,
          Color(0xFF81D4FA),
        );
      case 77:
        return const WeatherCodeInfo(
          'Granos de nieve',
          Icons.ac_unit,
          Color(0xFF81D4FA),
        );
      case 80:
      case 81:
      case 82:
        return const WeatherCodeInfo(
          'Chubascos',
          Icons.grain,
          Color(0xFF29B6F6),
        );
      case 85:
      case 86:
        return const WeatherCodeInfo(
          'Chubascos de nieve',
          Icons.ac_unit,
          Color(0xFF81D4FA),
        );
      case 95:
        return const WeatherCodeInfo(
          'Tormenta',
          Icons.thunderstorm,
          Color(0xFF5C6BC0),
        );
      case 96:
      case 99:
        return const WeatherCodeInfo(
          'Tormenta con granizo',
          Icons.thunderstorm,
          Color(0xFF5C6BC0),
        );
      default:
        return const WeatherCodeInfo(
          'Desconocido',
          Icons.help_outline,
          Color(0xFF90A4AE),
        );
    }
  }
}
