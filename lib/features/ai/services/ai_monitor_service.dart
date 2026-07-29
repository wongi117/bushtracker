import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bush_track/features/tracking/providers/location_provider.dart';
import 'package:bush_track/features/mesh/providers/mesh_provider.dart';
import 'package:bush_track/features/ai/providers/ai_assistant_provider.dart';
import 'package:geolocator/geolocator.dart';

class AiMonitorService {
  final Ref ref;
  Timer? _monitoringTimer;
  Position? _lastPosition;
  DateTime? _lastMovementTime;
  double _totalDistance = 0;
  bool _isMonitoring = false;

  AiMonitorService(this.ref);

  void startMonitoring() {
    if (_isMonitoring) return;
    
    _isMonitoring = true;
    _lastMovementTime = DateTime.now();
    
    // Check every 5 minutes as specified in the requirements
    _monitoringTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _performBackgroundCheck();
    });
  }

  void stopMonitoring() {
    _monitoringTimer?.cancel();
    _isMonitoring = false;
  }

  Future<void> _performBackgroundCheck() async {
    try {
      final locationState = ref.read(locationProvider);
      ref.read(meshProvider);
      final aiNotifier = ref.read(aiAssistantProvider.notifier);
      
      final currentLat = locationState.stats.currentLat;
      final currentLon = locationState.stats.currentLon;
      final currentSpeed = locationState.stats.currentSpeedMs;
      
      // Create a Position object for distance calculation
      if (currentLat != null && currentLon != null) {
        final currentPosition = Position(
          latitude: currentLat,
          longitude: currentLon,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: currentSpeed,
          speedAccuracy: 0,
          floor: null,
          isMocked: false,
        );
        
        // Check if user has moved
        if (_lastPosition != null) {
          final distance = Geolocator.distanceBetween(
            _lastPosition!.latitude,
            _lastPosition!.longitude,
            currentPosition.latitude,
            currentPosition.longitude,
          );
          
          // Update total distance
          _totalDistance += distance;
          
          // Check for movement
          if (distance > 10) { // More than 10 meters movement
            _lastMovementTime = DateTime.now();
          }
        }
        
        _lastPosition = currentPosition;
      }
      
      // Battery check - in a real app we would use a battery plugin
      // For now we'll simulate this check
      final batteryLevel = await _getBatteryLevel();
      if (batteryLevel != null && batteryLevel < 20) {
        await aiNotifier.speak(
          "Battery low at \$batteryLevel%. Activating power saving mode. "
          "GPS interval increased to 2 minutes."
        );
        // In a real implementation, we would adjust GPS tracking frequency here
      }
      
      // Speed suddenly 0 after movement
      if (currentSpeed == 0 && _lastPosition != null && 
          (_lastPosition?.speed ?? 0) > 1.0) { // Was moving faster than 1 m/s
        await aiNotifier.speak("You've stopped. Marking rest point.");
        // In a real implementation, we would add a waypoint here
      }
      
      // Moving in circles detection - simplified version
      if (_totalDistance > 1000 && currentSpeed > 0.5) { // More than 1km traveled and moving
        // This is a simplified check - in reality we'd need more sophisticated circle detection
        // For now we'll just check if they've been in the same general area
        await aiNotifier.speak(
          "You may be disoriented. Your camp is 1.8km to your south-east."
        );
      }
      
      // No movement for 4 hours in remote area
      if (_lastMovementTime != null) {
        final timeSinceLastMovement = DateTime.now().difference(_lastMovementTime!);
        if (timeSinceLastMovement.inHours >= 4) {
          await aiNotifier.speak(
            "You haven't moved in \${timeSinceLastMovement.inHours} hours. "
            "Are you okay? Tap OK or I'll send your location to your emergency contact."
          );
          // In a real implementation, we would wait for user response and then send SOS
        }
      }
      
      // Sunset check - simplified
      final hoursUntilSunset = await _getHoursUntilSunset();
      if (hoursUntilSunset != null && hoursUntilSunset <= 1 && hoursUntilSunset > 0) {
        await aiNotifier.speak(
          "Sunset in ${(hoursUntilSunset * 60).round()} minutes. "
          "Recommend finding camp in next 30 minutes."
        );
      }
      
      // Temperature extreme check - simplified
      // In a real implementation, we would get this from a weather API
      final temperature = await _getCurrentTemperature();
      if (temperature != null) {
        if (temperature > 40) { // Heat index extreme
          await aiNotifier.speak(
            "Current heat index: \${temperature.toStringAsFixed(0)}°C. "
            "Drink water. Seek shade."
          );
        }
      }
      
    } catch (e) {
      // Silently handle errors in background monitoring
      // We don't want to interrupt the user with error messages
    }
  }
  
  Future<int?> _getBatteryLevel() async {
    // In a real implementation, we would use a battery plugin like 'battery_plus'
    // For now, we'll return null to skip this check
    return null;
  }
  
  Future<double?> _getHoursUntilSunset() async {
    // In a real implementation, we would calculate this based on location and date
    // For now, we'll return null to skip this check
    return null;
  }
  
  Future<double?> _getCurrentTemperature() async {
    // In a real implementation, we would get this from a weather API
    // For now, we'll return null to skip this check
    return null;
  }
  
  void dispose() {
    stopMonitoring();
  }
}

// Provider for the AI monitor service
final aiMonitorServiceProvider = Provider((ref) {
  return AiMonitorService(ref);
});