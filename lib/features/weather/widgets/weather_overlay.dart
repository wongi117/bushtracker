import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:bush_track/theme/app_colors.dart';
import 'package:bush_track/features/weather/providers/weather_provider.dart';
import 'package:bush_track/features/tracking/providers/location_provider.dart';

class WeatherOverlay extends ConsumerWidget {
  const WeatherOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(locationProvider);
    final weatherState = ref.watch(weatherProvider);
    
    // Fetch weather data when location changes
    ref.listen<LocationState>(locationProvider, (previous, next) {
      if (next.stats.currentLat != null && next.stats.currentLon != null) {
        final location = LatLng(
          next.stats.currentLat!,
          next.stats.currentLon!,
        );
        ref.read(weatherProvider.notifier).fetchWeather(location);
      }
    });
    
    if (weatherState.isLoading) {
      return const Positioned(
        top: 100,
        right: 20,
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryOrange),
        ),
      );
    }
    
    if (weatherState.weatherData == null) {
      return const SizedBox.shrink();
    }
    
    final weather = weatherState.weatherData!;
    
    return Positioned(
      top: 100,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.panelMatte,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              spreadRadius: 2,
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current weather
            Row(
              children: [
                Icon(
                  _getWeatherIcon(weather.weatherCode),
                  color: AppColors.primaryOrange,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${weather.currentTemperature.toStringAsFixed(0)}°C',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '${weather.windSpeed.toStringAsFixed(0)} km/h',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                // Rain icon
                if (weather.precipitation > 0)
                  Icon(
                    Icons.water_drop,
                    color: weather.precipitation > 5 ? Colors.blue : Colors.lightBlue,
                    size: 24,
                  ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Weather alerts
            if (weather.precipitation > 0)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.deepOrange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Precipitation: ${weather.precipitation.toStringAsFixed(1)}mm',
                  style: const TextStyle(
                    color: AppColors.primaryOrange,
                    fontSize: 12,
                  ),
                ),
              ),
            
            if (weather.windSpeed > 30)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.deepOrange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'High winds',
                  style: TextStyle(
                    color: AppColors.primaryOrange,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  IconData _getWeatherIcon(int weatherCode) {
    // Simplified weather code mapping
    if (weatherCode < 30) return Icons.wb_sunny; // Clear sky
    if (weatherCode < 50) return Icons.cloud; // Mainly clear, partly cloudy
    if (weatherCode < 70) return Icons.cloud_queue; // Overcast
    if (weatherCode < 80) return Icons.grain; // Fog
    if (weatherCode < 90) return Icons.water_drop; // Drizzle
    return Icons.thunderstorm; // Thunderstorm
  }
}