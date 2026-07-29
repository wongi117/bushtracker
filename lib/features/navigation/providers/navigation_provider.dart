import 'dart:async';
import 'dart:convert';
import 'package:bush_track/core/config/api_config.dart';
import 'package:bush_track/features/navigation/services/navigation_service.dart';
import 'package:bush_track/features/places/services/places_service.dart';
import 'package:bush_track/features/tracking/providers/location_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class NavigationStep {
  final String instruction;
  final String? bannerInstruction;
  final String? voiceInstruction;
  final double distanceM;
  final double bearing;
  final LatLng location;
  final String manoeuvreType;

  NavigationStep({
    required this.instruction,
    this.bannerInstruction,
    this.voiceInstruction,
    required this.distanceM,
    required this.bearing,
    required this.location,
    required this.manoeuvreType,
  });
}

class RouteOption {
  final String name;
  final double distanceKm;
  final int estimatedTimeMin;
  final List<String> tradeoffs;
  final String terrainDifficulty;
  final String? polyline; // Encoded polyline for the route

  RouteOption({
    required this.name,
    required this.distanceKm,
    required this.estimatedTimeMin,
    required this.tradeoffs,
    required this.terrainDifficulty,
    this.polyline,
  });
}

class NavigationState {
  final List<NavigationStep> steps;
  final bool isActive;
  final int currentStepIndex;
  final RouteOption? selectedRoute;
  final List<LatLng> routePolyline; // Decoded polyline points
  final bool isOffRoute;
  final double offRouteDistanceM;

  NavigationState({
    this.steps = const [],
    this.isActive = false,
    this.currentStepIndex = 0,
    this.selectedRoute,
    this.routePolyline = const [],
    this.isOffRoute = false,
    this.offRouteDistanceM = 0.0,
  });

  NavigationStep? get currentStep {
    if (steps.isEmpty || currentStepIndex >= steps.length) {
      return null;
    }
    return steps[currentStepIndex];
  }

  NavigationState copyWith({
    List<NavigationStep>? steps,
    bool? isActive,
    int? currentStepIndex,
    RouteOption? selectedRoute,
    List<LatLng>? routePolyline,
    bool? isOffRoute,
    double? offRouteDistanceM,
  }) {
    return NavigationState(
      steps: steps ?? this.steps,
      isActive: isActive ?? this.isActive,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      selectedRoute: selectedRoute ?? this.selectedRoute,
      routePolyline: routePolyline ?? this.routePolyline,
      isOffRoute: isOffRoute ?? this.isOffRoute,
      offRouteDistanceM: offRouteDistanceM ?? this.offRouteDistanceM,
    );
  }
}

class NavigationNotifier extends StateNotifier<NavigationState> {
  final Ref ref;
  NavigationNotifier(this.ref) : super(NavigationState());
  Timer? _offRouteTimer;

  void startNavigation(List<NavigationStep> steps, {RouteOption? route}) {
    // Decode polyline if available
    List<LatLng> polyline = [];
    if (route?.polyline != null && route!.polyline!.isNotEmpty) {
      polyline = NavigationService.decodePolyline(route.polyline!);
    }
    
    state = state.copyWith(
      steps: steps,
      isActive: true,
      currentStepIndex: 0,
      selectedRoute: route,
      routePolyline: polyline,
      isOffRoute: false,
      offRouteDistanceM: 0.0,
    );
    
    // Start off-route monitoring
    _startOffRouteMonitoring();
  }

  void nextStep() {
    if (state.currentStepIndex < state.steps.length - 1) {
      state = state.copyWith(
        currentStepIndex: state.currentStepIndex + 1,
      );
    }
  }

  void previousStep() {
    if (state.currentStepIndex > 0) {
      state = state.copyWith(
        currentStepIndex: state.currentStepIndex - 1,
      );
    }
  }

  void stopNavigation() {
    _stopOffRouteMonitoring();
    state = state.copyWith(
      isActive: false,
      steps: const [],
      currentStepIndex: 0,
      selectedRoute: null,
      routePolyline: const [],
      isOffRoute: false,
      offRouteDistanceM: 0.0,
    );
  }

  void selectRoute(RouteOption route) {
    state = state.copyWith(selectedRoute: route);
  }

  /// Calculate a route to a destination with Mapbox.
  Future<void> calculateRoute(String destination) async {
    final locationState = ref.read(locationProvider);
    final originLat = locationState.stats.currentLat;
    final originLon = locationState.stats.currentLon;
    if (originLat == null || originLon == null) return;

    final key = ApiConfig.mapboxToken;
    if (key.isEmpty) return;

    final matches = await PlacesService.searchPlaces(
      destination,
      proximity: LatLng(originLat, originLon),
    );
    if (matches.isEmpty) return;

    final target = matches.first.location;
    final url = Uri.parse(
      'https://api.mapbox.com/directions/v5/mapbox/driving/${originLon},${originLat};${target.longitude},${target.latitude}?geometries=geojson&steps=true&voice_instructions=true&banner_instructions=true&access_token=$key',
    );

    final response = await http.get(url);
    if (response.statusCode != 200) return;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final routes = (data['routes'] as List<dynamic>? ?? const []);
    if (routes.isEmpty) return;

    final routeData = routes.first as Map<String, dynamic>;
    final legs = (routeData['legs'] as List<dynamic>? ?? const []);
    final geometry = routeData['geometry'] as Map<String, dynamic>?;
    final coords = (geometry?['coordinates'] as List<dynamic>? ?? const []);
    final polyline = coords.map((point) {
      final pair = point as List<dynamic>;
      return LatLng((pair[1] as num).toDouble(), (pair[0] as num).toDouble());
    }).toList();

    final steps = <NavigationStep>[];
    for (final leg in legs) {
      final legMap = leg as Map<String, dynamic>;
      final legSteps = (legMap['steps'] as List<dynamic>? ?? const []);
      for (final step in legSteps) {
        final stepMap = step as Map<String, dynamic>;
        final maneuver = (stepMap['maneuver'] as Map<String, dynamic>? ?? const {});
        final banner = (stepMap['banner_instructions'] as List<dynamic>? ?? const []);
        final voice = (stepMap['voice_instructions'] as List<dynamic>? ?? const []);
        final loc = maneuver['location'] as List<dynamic>? ?? const [];

        steps.add(NavigationStep(
          instruction: maneuver['instruction']?.toString() ?? stepMap['name']?.toString() ?? 'Continue',
          bannerInstruction: banner.isNotEmpty ? banner.first.toString() : null,
          voiceInstruction: voice.isNotEmpty ? voice.first.toString() : null,
          distanceM: (stepMap['distance'] as num? ?? 0).toDouble(),
          bearing: (maneuver['bearing_after'] as num? ?? 0).toDouble(),
          location: loc.length >= 2
              ? LatLng((loc[1] as num).toDouble(), (loc[0] as num).toDouble())
              : target,
          manoeuvreType: maneuver['type']?.toString() ?? 'straight',
        ));
      }
    }

    final route = RouteOption(
      name: 'Route to ${matches.first.name}',
      distanceKm: ((routeData['distance'] as num? ?? 0) / 1000.0),
      estimatedTimeMin: ((routeData['duration'] as num? ?? 0) / 60).round(),
      tradeoffs: const ['Mapbox road data', 'Voice + banner instructions'],
      terrainDifficulty: 'Mapbox',
      polyline: NavigationService.encodePolyline(polyline),
    );

    startNavigation(steps, route: route);
  }


  /// Start monitoring for off-route conditions
  void _startOffRouteMonitoring() {
    _stopOffRouteMonitoring(); // Stop any existing timer
    
    _offRouteTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      // In a real implementation, this would check the user's current position
      // against the route polyline and trigger alerts if they're off-route
      // For now, we'll just simulate the check
      _checkOffRouteCondition();
    });
  }

  /// Stop off-route monitoring
  void _stopOffRouteMonitoring() {
    _offRouteTimer?.cancel();
    _offRouteTimer = null;
  }

  /// Check if the user is off-route
  void _checkOffRouteCondition() {
    // This would be implemented with real location data
    // For now, we'll keep it simple
  }

  /// Update off-route status based on user's current position
  void updateOffRouteStatus(LatLng userPosition) {
    // If no route polyline, can't determine off-route status
    if (state.routePolyline.isEmpty) return;
    
    // Find the closest point on the route polyline to the user's position
    double minDistance = double.infinity;
    
    // Check distance to each segment of the polyline
    for (int i = 0; i < state.routePolyline.length - 1; i++) {
      final start = state.routePolyline[i];
      final end = state.routePolyline[i + 1];
      
      final distance = NavigationService.distanceToSegment(userPosition, start, end);
      if (distance < minDistance) {
        minDistance = distance;
      }
    }
    
    // Convert distance to meters
    final distanceM = minDistance;
    final isOffRoute = distanceM > 100.0; // Off-route threshold is 100m
    
    // Update state if changed
    if (state.isOffRoute != isOffRoute || state.offRouteDistanceM != distanceM) {
      state = state.copyWith(
        isOffRoute: isOffRoute,
        offRouteDistanceM: distanceM,
      );
      
      // Trigger voice alert if off-route and distance > 100m
      if (isOffRoute) {
        // In a real implementation, this would trigger a voice alert
        // through the AI assistant or TTS system
        // For example: "You are off route. You are {distance} meters away from the route."
      }
    }
  }

  @override
  void dispose() {
    _stopOffRouteMonitoring();
    super.dispose();
  }
}

final navigationProvider = StateNotifierProvider<NavigationNotifier, NavigationState>((ref) {
  return NavigationNotifier(ref);
});
