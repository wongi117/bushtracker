import 'dart:async';
import 'dart:math' show atan2, sin, cos;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../tracking/providers/location_provider.dart';
import '../providers/ai_assistant_provider.dart';
import '../services/geographic_analysis_service.dart';
import '../services/environmental_calculation_service.dart';

class AIControlState {
  final bool isProactiveMonitoring;
  final bool isEmergencyMode;
  final String? lastAlert;
  final DateTime? lastMovementTimestamp;
  final double? lastBatteryLevel;

  AIControlState({
    this.isProactiveMonitoring = true,
    this.isEmergencyMode = false,
    this.lastAlert,
    this.lastMovementTimestamp,
    this.lastBatteryLevel,
  });

  AIControlState copyWith({
    bool? isProactiveMonitoring,
    bool? isEmergencyMode,
    String? lastAlert,
    DateTime? lastMovementTimestamp,
    double? lastBatteryLevel,
  }) {
    return AIControlState(
      isProactiveMonitoring: isProactiveMonitoring ?? this.isProactiveMonitoring,
      isEmergencyMode: isEmergencyMode ?? this.isEmergencyMode,
      lastAlert: lastAlert ?? this.lastAlert,
      lastMovementTimestamp: lastMovementTimestamp ?? this.lastMovementTimestamp,
      lastBatteryLevel: lastBatteryLevel ?? this.lastBatteryLevel,
    );
  }
}

class AIControlNotifier extends StateNotifier<AIControlState> {
  final Ref _ref;
  Timer? _monitorTimer;
  Timer? _campFinderTimer;
  Timer? _deadmanTimer;
  Timer? _duplicateCheckTimer;
  DateTime? _lastMovementTime;

  AIControlNotifier(this._ref) : super(AIControlState()) {
    _startMonitoring();
    _startCampFinderMonitoring();
    _startDeadmanMonitoring();
    _startDuplicateCheck();
    _lastMovementTime = DateTime.now();
  }

  void _startMonitoring() {
    _monitorTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (state.isProactiveMonitoring) {
        _performSafetyChecks();
      }
    });
  }

  void _startCampFinderMonitoring() {
    // Check for campsite recommendations every 30 minutes when stationary
    _campFinderTimer = Timer.periodic(const Duration(minutes: 30), (timer) {
      if (state.isProactiveMonitoring) {
        _checkForCampsiteOpportunity();
      }
    });
  }

  void _startDeadmanMonitoring() {
    // Check for deadman switch every minute
    _deadmanTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (state.isProactiveMonitoring) {
        _checkDeadmanSwitch();
      }
    });
  }

  void _startDuplicateCheck() {
    // Check for duplicate waypoints every hour
    _duplicateCheckTimer = Timer.periodic(const Duration(hours: 1), (timer) {
      if (state.isProactiveMonitoring) {
        _checkDuplicateWaypoints();
      }
    });
  }

  void _performSafetyChecks() async {
    final locationState = _ref.read(locationProvider);
    final stats = locationState.stats;

    // 1. Movement check - update last movement time
    if (stats.currentSpeedMs > 0.5) { // Moving faster than 0.5 m/s
      _lastMovementTime = DateTime.now();
      state = state.copyWith(lastMovementTimestamp: _lastMovementTime);
    }

    // 2. Battery check (Mocked for now as we don't have battery package yet)
    final batteryLevel = await _getBatteryLevel();
    if (batteryLevel != null) {
      state = state.copyWith(lastBatteryLevel: batteryLevel);
      
      // Battery saver mode
      if (batteryLevel < 20.0) {
        _activateBatterySaver();
      } else if (state.lastBatteryLevel != null && state.lastBatteryLevel! < 20.0) {
        // Battery recovered from low state
        _deactivateBatterySaver();
      }
    }
    
    // 3. Sunset check
    await _checkSunsetAlert(locationState);
  }

  /// Check if it's a good time to look for a campsite
  void _checkForCampsiteOpportunity() async {
    final locationState = _ref.read(locationProvider);
    final stats = locationState.stats;
    
    // Only suggest campsites when moving slowly or stopped for a while
    if (stats.currentSpeedMs > 2.0) { // 2 m/s = ~7 km/h
      return;
    }
    
    // Only suggest if we have a valid location
    if (stats.currentLat == null || stats.currentLon == null) {
      return;
    }
    
    final currentLocation = LatLng(stats.currentLat!, stats.currentLon!);
    final bestCampsite = await GeographicAnalysisService.findBestCampsite(currentLocation);
    
    if (bestCampsite != null && bestCampsite.overallScore > 70) {
      // Good campsite found, notify the user
      final direction = _calculateBearing(currentLocation, bestCampsite.location);
      final cardinalDirection = _getCardinalDirection(direction);
      final distance = GeographicAnalysisService.calculateDistance(currentLocation, bestCampsite.location);
      
      final message = "I've found a potential campsite ${distance.toStringAsFixed(0)} meters to the $cardinalDirection. "
          "It scores ${bestCampsite.overallScore.toStringAsFixed(0)} out of 100 for flatness and water proximity.";
      
      _ref.read(aiAssistantProvider.notifier).speak(message);
      state = state.copyWith(lastAlert: message);
    }
  }

  /// Check for sunset and alert user
  Future<void> _checkSunsetAlert(LocationState locationState) async {
    if (locationState.stats.currentLat == null || locationState.stats.currentLon == null) {
      return;
    }
    
    final location = LatLng(locationState.stats.currentLat!, locationState.stats.currentLon!);
    final hoursUntilSunset = await _getHoursUntilSunset(location);
    
    if (hoursUntilSunset != null && hoursUntilSunset <= 1 && hoursUntilSunset > 0) {
      final message = "Sunset in ${(hoursUntilSunset * 60).round()} minutes. "
          "Recommend finding camp in next 30 minutes.";
      _ref.read(aiAssistantProvider.notifier).speak(message);
      state = state.copyWith(lastAlert: message);
    }
  }

  /// Proactively scan for duplicate waypoints
  void _checkDuplicateWaypoints() {
    final locationState = _ref.read(locationProvider);
    final waypoints = locationState.waypoints;
    
    if (waypoints.length < 2) return;
    
    int duplicatesFound = 0;
    int redundantLabelsFound = 0;
    final Set<int> flaggedIds = {};
    
    for (int i = 0; i < waypoints.length; i++) {
      if (flaggedIds.contains(waypoints[i].id)) continue;
      
      final wp1 = waypoints[i];
      if (wp1.latitude == null || wp1.longitude == null) continue;
      
      final pos1 = LatLng(wp1.latitude!, wp1.longitude!);
      
      for (int j = i + 1; j < waypoints.length; j++) {
        final wp2 = waypoints[j];
        if (wp2.latitude == null || wp2.longitude == null) continue;
        
        final pos2 = LatLng(wp2.latitude!, wp2.longitude!);
        final distance = GeographicAnalysisService.calculateDistance(pos1, pos2);
        
        // 1. Check for physical proximity (within 15 meters)
        if (distance < 15.0) {
          duplicatesFound++;
          flaggedIds.add(wp2.id!);
        } 
        // 2. Check for identical labels (case insensitive)
        else if (wp1.label != null && wp2.label != null && 
                 wp1.label!.trim().toLowerCase() == wp2.label!.trim().toLowerCase() &&
                 wp1.label!.isNotEmpty) {
          redundantLabelsFound++;
        }
      }
    }
    
    if (duplicatesFound > 0 || redundantLabelsFound > 0) {
      String message = "Future Gen AI alert: ";
      if (duplicatesFound > 0) {
        message += "I've detected $duplicatesFound duplicate waypoint${duplicatesFound > 1 ? 's' : ''} in close proximity. ";
      }
      if (redundantLabelsFound > 0) {
        message += "There are $redundantLabelsFound waypoints with identical labels. ";
      }
      message += "Consider merging them to maintain tactical clarity.";
      
      _ref.read(aiAssistantProvider.notifier).speak(message);
      state = state.copyWith(lastAlert: message);
    }
  }

  /// Check deadman switch - if no movement for 4 hours in remote area
  void _checkDeadmanSwitch() {
    if (_lastMovementTime == null) return;
    
    final now = DateTime.now();
    final timeSinceLastMovement = now.difference(_lastMovementTime!);
    
    // If no movement for 4 hours
    if (timeSinceLastMovement.inHours >= 4) {
      // Check if in remote area (mock implementation)
      final locationState = _ref.read(locationProvider);
      if (locationState.stats.currentLat != null && locationState.stats.currentLon != null) {
        // In a real implementation, we would check if this is a remote area
        // For now, we'll assume it is
        
        // Start deadman countdown
        _startDeadmanCountdown();
      }
    }
  }

  /// Start deadman countdown to SOS
  void _startDeadmanCountdown() {
    // Speak warning
    _ref.read(aiAssistantProvider.notifier).speak(
      "Warning: No movement detected for 4 hours. Initiating emergency protocol in 10 minutes unless canceled."
    );
    
    // Start 10-minute countdown
    Timer(const Duration(minutes: 10), () {
      // Double-check that there's still no movement
      if (_lastMovementTime != null) {
        final timeSinceLastMovement = DateTime.now().difference(_lastMovementTime!);
        if (timeSinceLastMovement.inHours >= 4) {
          // Trigger SOS
          triggerEmergency();
        }
      }
    });
  }

  /// Activate battery saver mode
  void _activateBatterySaver() {
    // Reduce LocationProvider update frequency
    _ref.read(locationProvider.notifier).setBatterySaverMode(true);
    
    const message = "Battery level below 20%. Activating power saving mode. "
        "Reducing GPS update frequency to conserve power.";
    _ref.read(aiAssistantProvider.notifier).speak(message);
    state = state.copyWith(lastAlert: message);
  }

  /// Deactivate battery saver mode
  void _deactivateBatterySaver() {
    // Restore normal LocationProvider update frequency
    _ref.read(locationProvider.notifier).setBatterySaverMode(false);
    
    const message = "Battery level restored. Returning to normal GPS update frequency.";
    _ref.read(aiAssistantProvider.notifier).speak(message);
    state = state.copyWith(lastAlert: message);
  }

  /// Calculate bearing between two points
  double _calculateBearing(LatLng from, LatLng to) {
    final lat1 = _toRadians(from.latitude);
    final lon1 = _toRadians(from.longitude);
    final lat2 = _toRadians(to.latitude);
    final lon2 = _toRadians(to.longitude);
    
    final dLon = lon2 - lon1;
    
    final y = sin(dLon) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);
    final bearing = atan2(y, x);
    
    // Convert from radians to degrees
    var degrees = _toDegrees(bearing);
    
    // Normalize to 0-360 range
    degrees = (degrees + 360) % 360;
    
    return degrees;
  }

  /// Convert degrees to cardinal direction
  String _getCardinalDirection(double degrees) {
    const directions = ['north', 'northeast', 'east', 'southeast', 'south', 'southwest', 'west', 'northwest'];
    int index = ((degrees + 22.5) % 360 / 45).floor();
    return directions[index];
  }

  /// Convert degrees to radians
  double _toRadians(double degrees) {
    return degrees * (pi / 180);
  }

  /// Convert radians to degrees
  double _toDegrees(double radians) {
    return radians * (180 / pi);
  }

  /// Get battery level (mock implementation)
  Future<double?> _getBatteryLevel() async {
    // In a real implementation, we would use a battery plugin like 'battery_plus'
    // For now, we'll use our environmental calculation service
    return await EnvironmentalCalculationService.getBatteryLevel();
  }

  /// Calculate hours until sunset (mock implementation)
  Future<double?> _getHoursUntilSunset(LatLng location) async {
    // In a real implementation, we would calculate this based on location and date
    // For now, we'll use our environmental calculation service
    return await EnvironmentalCalculationService.getHoursUntilSunset(location);
  }

  void triggerEmergency() {
    state = state.copyWith(isEmergencyMode: true);
    _ref.read(aiAssistantProvider.notifier).speak(
      "Emergency mode activated. Broadcasting your location across the mesh. Do not move unless in immediate danger."
    );
    // Here we would also trigger the Mesh SOS broadcast
  }

  @override
  void dispose() {
    _monitorTimer?.cancel();
    _campFinderTimer?.cancel();
    _deadmanTimer?.cancel();
    _duplicateCheckTimer?.cancel();
    super.dispose();
  }
}

final aiControlProvider = StateNotifierProvider<AIControlNotifier, AIControlState>((ref) {
  return AIControlNotifier(ref);
});
