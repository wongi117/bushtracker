import 'dart:ui' show ImageFilter;

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
    final weatherState = ref.watch(weatherProvider);

    // Fetch when the position changes (the provider throttles further). This
    // used to also ref.watch(locationProvider), rebuilding every second for
    // the elapsed-time tick, and fetched on every one of those ticks.
    ref.listen<LocationState>(locationProvider, (previous, next) {
      if (previous?.stats.currentLat == next.stats.currentLat &&
          previous?.stats.currentLon == next.stats.currentLon) {
        return;
      }
      if (next.stats.currentLat != null && next.stats.currentLon != null) {
        final location = LatLng(
          next.stats.currentLat!,
          next.stats.currentLon!,
        );
        ref.read(weatherProvider.notifier).fetchWeather(location);
      }
    });
    
    // No spinner: it sat at top-right on top of the SOS button, flickering
    // on every fetch. Weather isn't urgent — show it when it arrives.
    if (weatherState.weatherData == null) {
      return const SizedBox.shrink();
    }

    final weather = weatherState.weatherData!;

    // Top-left under the menu button. At top-right it covered the compass,
    // the SOS button and the top of the pin-tracking panel.
    return Positioned(
      top: MediaQuery.of(context).padding.top + 76,
      left: 14,
      // Semi-transparent so the map reads through it, with a blur behind so
      // the text stays legible over busy satellite imagery — a flat 65% panel
      // over scrub is hard to read.
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.panelMatte.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
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
        ),
      ),
    );
  }
  
  IconData _getWeatherIcon(int weatherCode) {
    // Simplified weather code mapping
    // WMO weather codes as used by Open-Meteo. The old ranges showed rain
    // (61-67) as "overcast" and snow (71-77) as "fog".
    if (weatherCode == 0) return Icons.wb_sunny; // clear
    if (weatherCode <= 2) return Icons.wb_cloudy; // mainly clear / partly cloudy
    if (weatherCode == 3) return Icons.cloud; // overcast
    if (weatherCode == 45 || weatherCode == 48) return Icons.cloud; // fog
    if (weatherCode >= 51 && weatherCode <= 67) return Icons.grain; // drizzle / rain
    if (weatherCode >= 71 && weatherCode <= 77) return Icons.ac_unit; // snow
    if (weatherCode >= 80 && weatherCode <= 82) return Icons.water_drop; // showers
    if (weatherCode >= 85 && weatherCode <= 86) return Icons.ac_unit; // snow showers
    return Icons.thunderstorm; // 95-99
  }
}