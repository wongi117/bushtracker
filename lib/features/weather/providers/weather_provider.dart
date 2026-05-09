import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:bush_track/features/weather/services/weather_service.dart';

class WeatherState {
  final WeatherData? weatherData;
  final bool isLoading;
  final String? error;

  WeatherState({
    this.weatherData,
    this.isLoading = false,
    this.error,
  });

  WeatherState copyWith({
    WeatherData? weatherData,
    bool? isLoading,
    String? error,
  }) {
    return WeatherState(
      weatherData: weatherData ?? this.weatherData,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class WeatherNotifier extends StateNotifier<WeatherState> {
  WeatherNotifier() : super(WeatherState());

  Future<void> fetchWeather(LatLng location) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final weatherData = await WeatherService.getWeatherData(location);
      state = state.copyWith(
        weatherData: weatherData,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to fetch weather data',
      );
    }
  }
}

final weatherProvider = StateNotifierProvider<WeatherNotifier, WeatherState>((ref) {
  return WeatherNotifier();
});