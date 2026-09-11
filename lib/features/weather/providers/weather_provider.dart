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

  // The overlay called fetchWeather on every location-state change, and the
  // location state ticks every second (elapsed time) — so the app fetched the
  // forecast about once a second, forever. Weather barely changes in 30 min
  // or 5 km, and Open-Meteo's free tier is 10,000 calls/day.
  static const _refreshAfter = Duration(minutes: 30);
  static const _refetchBeyondMetres = 5000.0;
  DateTime? _lastFetchAt;
  LatLng? _lastFetchLocation;

  Future<void> fetchWeather(LatLng location) async {
    if (state.isLoading) return;
    final last = _lastFetchAt;
    final lastLoc = _lastFetchLocation;
    if (last != null &&
        lastLoc != null &&
        DateTime.now().difference(last) < _refreshAfter &&
        const Distance()(lastLoc, location) < _refetchBeyondMetres) {
      return;
    }
    _lastFetchAt = DateTime.now();
    _lastFetchLocation = location;

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