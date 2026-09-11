import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class WeatherService {
  static const String _baseUrl = 'https://api.open-meteo.com/v1/forecast';
  
  // Fetch weather data for a given location
  static Future<WeatherData?> getWeatherData(LatLng location) async {
    try {
      final response = await http.get(Uri.parse(
        '$_baseUrl?latitude=${location.latitude}&longitude=${location.longitude}'
        '&hourly=temperature_2m,precipitation,wind_speed_10m,weather_code'
        // `current` is the conditions now; `daily` feeds the 3-day forecast.
        // The parser always needed `daily` but it was never requested, so
        // every parse threw and the weather card has never appeared.
        '&current=temperature_2m,precipitation,wind_speed_10m,weather_code'
        '&daily=temperature_2m_max,temperature_2m_min'
        '&timezone=auto'
        '&forecast_days=3'
      ));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return WeatherData.fromJson(data);
      }
    } catch (e) {
      // Handle error or return null for offline mode
      return null;
    }
    return null;
  }
}

class WeatherData {
  final double currentTemperature;
  final double windSpeed;
  final double precipitation;
  final int weatherCode;
  final List<HourlyForecast> hourlyForecast;
  final List<DailyForecast> dailyForecast;

  WeatherData({
    required this.currentTemperature,
    required this.windSpeed,
    required this.precipitation,
    required this.weatherCode,
    required this.hourlyForecast,
    required this.dailyForecast,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    // JSON numbers can arrive as int or double (and null for gaps); a bare
    // List<double>.from throws on an int in the Dart VM.
    List<double> nums(dynamic v) =>
        (v as List? ?? const []).map((e) => (e as num?)?.toDouble() ?? 0.0).toList();
    List<int> ints(dynamic v) =>
        (v as List? ?? const []).map((e) => (e as num?)?.toInt() ?? 0).toList();

    final hourly = json['hourly'] as Map<String, dynamic>? ?? const {};
    final daily = json['daily'] as Map<String, dynamic>? ?? const {};
    final current = json['current'] as Map<String, dynamic>?;

    final hourlyTimes = List<String>.from(hourly['time'] as List? ?? const []);
    final temperatures = nums(hourly['temperature_2m']);
    final precipitation = nums(hourly['precipitation']);
    final windSpeeds = nums(hourly['wind_speed_10m']);
    final weatherCodes = ints(hourly['weather_code']);

    final dailyTimes = List<String>.from(daily['time'] as List? ?? const []);
    final maxTemps = nums(daily['temperature_2m_max']);
    final minTemps = nums(daily['temperature_2m_min']);

    final hourlyForecast = <HourlyForecast>[];
    for (int i = 0;
        i < hourlyTimes.length && i < 24 && i < temperatures.length &&
            i < precipitation.length && i < windSpeeds.length &&
            i < weatherCodes.length;
        i++) {
      hourlyForecast.add(HourlyForecast(
        time: hourlyTimes[i],
        temperature: temperatures[i],
        precipitation: precipitation[i],
        windSpeed: windSpeeds[i],
        weatherCode: weatherCodes[i],
      ));
    }
    
    final dailyForecast = <DailyForecast>[];
    for (int i = 0;
        i < dailyTimes.length && i < 3 && i < maxTemps.length && i < minTemps.length;
        i++) {
      dailyForecast.add(DailyForecast(
        date: dailyTimes[i],
        maxTemperature: maxTemps[i],
        minTemperature: minTemps[i],
      ));
    }
    
    return WeatherData(
      // Was temperatures.first — the first HOURLY slot, i.e. midnight UTC,
      // which is 8 am in WA. Use the API's actual current conditions.
      currentTemperature: (current?['temperature_2m'] as num?)?.toDouble() ??
          (temperatures.isNotEmpty ? temperatures.first : 0.0),
      windSpeed: (current?['wind_speed_10m'] as num?)?.toDouble() ??
          (windSpeeds.isNotEmpty ? windSpeeds.first : 0.0),
      precipitation: (current?['precipitation'] as num?)?.toDouble() ??
          (precipitation.isNotEmpty ? precipitation.first : 0.0),
      weatherCode: (current?['weather_code'] as num?)?.toInt() ??
          (weatherCodes.isNotEmpty ? weatherCodes.first : 0),
      hourlyForecast: hourlyForecast,
      dailyForecast: dailyForecast,
    );
  }
}

class HourlyForecast {
  final String time;
  final double temperature;
  final double precipitation;
  final double windSpeed;
  final int weatherCode;

  HourlyForecast({
    required this.time,
    required this.temperature,
    required this.precipitation,
    required this.windSpeed,
    required this.weatherCode,
  });
}

class DailyForecast {
  final String date;
  final double maxTemperature;
  final double minTemperature;

  DailyForecast({
    required this.date,
    required this.maxTemperature,
    required this.minTemperature,
  });
}