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
    final hourly = json['hourly'] as Map<String, dynamic>;
    final daily = json['daily'] as Map<String, dynamic>;
    
    final hourlyTimes = List<String>.from(hourly['time'] as List);
    final temperatures = List<double>.from(hourly['temperature_2m'] as List);
    final precipitation = List<double>.from(hourly['precipitation'] as List);
    final windSpeeds = List<double>.from(hourly['wind_speed_10m'] as List);
    final weatherCodes = List<int>.from(hourly['weather_code'] as List);
    
    final dailyTimes = List<String>.from(daily['time'] as List);
    final maxTemps = List<double>.from(daily['temperature_2m_max'] as List);
    final minTemps = List<double>.from(daily['temperature_2m_min'] as List);
    
    final hourlyForecast = <HourlyForecast>[];
    for (int i = 0; i < hourlyTimes.length && i < 24; i++) {
      hourlyForecast.add(HourlyForecast(
        time: hourlyTimes[i],
        temperature: temperatures[i],
        precipitation: precipitation[i],
        windSpeed: windSpeeds[i],
        weatherCode: weatherCodes[i],
      ));
    }
    
    final dailyForecast = <DailyForecast>[];
    for (int i = 0; i < dailyTimes.length && i < 3; i++) {
      dailyForecast.add(DailyForecast(
        date: dailyTimes[i],
        maxTemperature: maxTemps[i],
        minTemperature: minTemps[i],
      ));
    }
    
    return WeatherData(
      currentTemperature: temperatures.first,
      windSpeed: windSpeeds.first,
      precipitation: precipitation.first,
      weatherCode: weatherCodes.first,
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