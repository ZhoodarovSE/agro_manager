import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class City {
  const City(this.name, this.region, this.lat, this.lon);
  final String name;
  final String region;
  final double lat;
  final double lon;
}

/// Города Кыргызстана для прогноза погоды.
const kCities = <City>[
  City('Бишкек', 'Чуйская обл.', 42.87, 74.59),
  City('Токмок', 'Чуйская обл.', 42.84, 75.30),
  City('Кара-Балта', 'Чуйская обл.', 42.81, 73.85),
  City('Ош', 'Ошская обл.', 40.51, 72.80),
  City('Узген', 'Ошская обл.', 40.77, 73.30),
  City('Джалал-Абад', 'Джалал-Абадская обл.', 40.93, 73.00),
  City('Каракол', 'Иссык-Кульская обл.', 42.49, 78.39),
  City('Чолпон-Ата', 'Иссык-Кульская обл.', 42.65, 77.08),
  City('Нарын', 'Нарынская обл.', 41.43, 75.99),
  City('Талас', 'Таласская обл.', 42.52, 72.24),
  City('Баткен', 'Баткенская обл.', 40.06, 70.82),
];

City cityByName(String name) =>
    kCities.firstWhere((c) => c.name == name, orElse: () => kCities.first);

class CurrentWeather {
  const CurrentWeather({
    required this.temperature,
    required this.humidity,
    required this.precipitation,
    required this.windSpeed,
    required this.code,
  });
  final double temperature;
  final double humidity;
  final double precipitation;
  final double windSpeed;
  final int code;
}

class DayForecast {
  const DayForecast({
    required this.date,
    required this.tMax,
    required this.tMin,
    required this.precipitation,
    required this.precipProbability,
    required this.code,
  });
  final DateTime date;
  final double tMax;
  final double tMin;
  final double precipitation;
  final int precipProbability;
  final int code;
}

class WeatherData {
  const WeatherData({required this.current, required this.days, required this.fetchedAt});
  final CurrentWeather current;
  final List<DayForecast> days;
  final DateTime fetchedAt;

  /// Предупреждения для фермера: заморозки, жара, сильные осадки.
  List<WeatherAlert> get alerts {
    final result = <WeatherAlert>[];
    final frost = days.where((d) => d.tMin <= 0).toList();
    final nearFrost = days.where((d) => d.tMin > 0 && d.tMin <= 2).toList();
    if (frost.isNotEmpty) {
      final min = frost.map((d) => d.tMin).reduce((a, b) => a < b ? a : b);
      result.add(WeatherAlert(
        AlertLevel.danger,
        'Заморозки',
        'Ожидается до ${min.round()}°C (${frost.length} дн.). Укройте рассаду и молодые посевы, '
            'перенесите полив на дневное время.',
      ));
    } else if (nearFrost.isNotEmpty) {
      result.add(const WeatherAlert(
        AlertLevel.warning,
        'Риск заморозков на почве',
        'Ночью температура опустится до +2°C и ниже. Следите за теплолюбивыми культурами.',
      ));
    }
    if (days.any((d) => d.tMax >= 35)) {
      result.add(const WeatherAlert(
        AlertLevel.warning,
        'Сильная жара',
        'Температура поднимется до +35°C и выше. Поливайте рано утром или вечером.',
      ));
    }
    if (days.any((d) => d.precipitation >= 15)) {
      result.add(const WeatherAlert(
        AlertLevel.info,
        'Сильные осадки',
        'Ожидается более 15 мм осадков за день. Полив можно отложить.',
      ));
    }
    return result;
  }
}

enum AlertLevel { info, warning, danger }

class WeatherAlert {
  const WeatherAlert(this.level, this.title, this.message);
  final AlertLevel level;
  final String title;
  final String message;

  Color get color => switch (level) {
        AlertLevel.danger => Colors.red,
        AlertLevel.warning => Colors.orange,
        AlertLevel.info => Colors.blue,
      };

  IconData get icon => switch (level) {
        AlertLevel.danger => Icons.ac_unit,
        AlertLevel.warning => Icons.warning_amber,
        AlertLevel.info => Icons.info_outline,
      };
}

/// Описание и иконка по коду погоды WMO (используется Open-Meteo).
({String label, IconData icon}) weatherInfo(int code) => switch (code) {
      0 => (label: 'Ясно', icon: Icons.wb_sunny),
      1 || 2 => (label: 'Переменная облачность', icon: Icons.wb_cloudy),
      3 => (label: 'Пасмурно', icon: Icons.cloud),
      45 || 48 => (label: 'Туман', icon: Icons.foggy),
      >= 51 && <= 57 => (label: 'Морось', icon: Icons.grain),
      >= 61 && <= 67 => (label: 'Дождь', icon: Icons.umbrella),
      >= 71 && <= 77 => (label: 'Снег', icon: Icons.ac_unit),
      >= 80 && <= 82 => (label: 'Ливень', icon: Icons.umbrella),
      85 || 86 => (label: 'Снегопад', icon: Icons.ac_unit),
      >= 95 => (label: 'Гроза', icon: Icons.thunderstorm),
      _ => (label: 'Нет данных', icon: Icons.help_outline),
    };

class WeatherService {
  WeatherService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Future<WeatherData> fetch(City city) async {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': '${city.lat}',
      'longitude': '${city.lon}',
      'current': 'temperature_2m,relative_humidity_2m,precipitation,weather_code,wind_speed_10m',
      'daily': 'weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum,'
          'precipitation_probability_max',
      'timezone': 'auto',
      'forecast_days': '7',
      'wind_speed_unit': 'ms',
    });
    final res = await _client.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception('Сервер погоды ответил кодом ${res.statusCode}');
    }
    return parse(jsonDecode(res.body) as Map<String, dynamic>);
  }

  static WeatherData parse(Map<String, dynamic> j) {
    double n(Object? v) => (v as num?)?.toDouble() ?? 0;
    final c = j['current'] as Map<String, dynamic>;
    final d = j['daily'] as Map<String, dynamic>;
    final dates = (d['time'] as List).cast<String>();
    List<dynamic> col(String k) => (d[k] as List?) ?? List.filled(dates.length, null);
    final codes = col('weather_code');
    final tMax = col('temperature_2m_max');
    final tMin = col('temperature_2m_min');
    final precip = col('precipitation_sum');
    final prob = col('precipitation_probability_max');
    return WeatherData(
      current: CurrentWeather(
        temperature: n(c['temperature_2m']),
        humidity: n(c['relative_humidity_2m']),
        precipitation: n(c['precipitation']),
        windSpeed: n(c['wind_speed_10m']),
        code: (c['weather_code'] as num?)?.toInt() ?? -1,
      ),
      days: [
        for (var i = 0; i < dates.length; i++)
          DayForecast(
            date: DateTime.parse(dates[i]),
            tMax: n(tMax[i]),
            tMin: n(tMin[i]),
            precipitation: n(precip[i]),
            precipProbability: (prob[i] as num?)?.toInt() ?? 0,
            code: (codes[i] as num?)?.toInt() ?? -1,
          ),
      ],
      fetchedAt: DateTime.now(),
    );
  }
}

/// Кэширует прогноз, чтобы не дёргать сервер при каждом открытии экрана.
class WeatherState extends ChangeNotifier {
  WeatherState({WeatherService? service}) : _service = service ?? WeatherService();
  final WeatherService _service;

  String? city;
  WeatherData? data;
  bool loading = false;
  String? error;

  Future<void> load(String cityName, {bool force = false}) async {
    if (loading) return;
    final fresh = data != null &&
        city == cityName &&
        DateTime.now().difference(data!.fetchedAt) < const Duration(minutes: 30);
    if (fresh && !force) return;
    if (city != cityName) data = null;
    city = cityName;
    loading = true;
    error = null;
    notifyListeners();
    try {
      data = await _service.fetch(cityByName(cityName));
    } catch (e) {
      error = 'Не удалось загрузить погоду. Проверьте интернет.';
      debugPrint('Weather error: $e');
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
