import 'package:flutter_test/flutter_test.dart';
import 'package:bush_track/features/weather/services/weather_service.dart';

// Shape of a real Open-Meteo response for the app's query (Leonora, Sept 2026),
// trimmed. Note the mix of int and double values JSON can hand back.
Map<String, dynamic> response({bool withDaily = true, bool withCurrent = true}) => {
      'latitude': -28.875,
      'longitude': 121.375,
      if (withCurrent)
        'current': {
          'time': '2026-09-11T15:00',
          'temperature_2m': 27, // an int — used to throw in the VM
          'precipitation': 0.0,
          'wind_speed_10m': 14.3,
          'weather_code': 1,
        },
      'hourly': {
        'time': ['2026-09-11T00:00', '2026-09-11T01:00'],
        'temperature_2m': [13.8, 17],
        'precipitation': [0.0, 0],
        'wind_speed_10m': [6.1, 7.4],
        'weather_code': [0, 1],
      },
      if (withDaily)
        'daily': {
          'time': ['2026-09-11', '2026-09-12', '2026-09-13'],
          'temperature_2m_max': [29.1, 31, 30.4],
          'temperature_2m_min': [11.2, 12.8, 14],
        },
    };

void main() {
  test('uses the API\'s current conditions, not the midnight hourly slot', () {
    final w = WeatherData.fromJson(response());
    expect(w.currentTemperature, 27.0); // not 13.8 (hourly[0] = midnight)
    expect(w.windSpeed, 14.3);
    expect(w.weatherCode, 1);
    expect(w.dailyForecast.length, 3);
    expect(w.dailyForecast[1].maxTemperature, 31.0);
  });

  test('a response without daily data no longer throws', () {
    // This was every response the app ever received: the query never asked
    // for daily data, the parser required it, and the card never appeared.
    final w = WeatherData.fromJson(response(withDaily: false));
    expect(w.dailyForecast, isEmpty);
    expect(w.hourlyForecast.length, 2);
  });

  test('without a current block it falls back to the first hourly slot', () {
    final w = WeatherData.fromJson(response(withCurrent: false));
    expect(w.currentTemperature, 13.8);
  });
}
