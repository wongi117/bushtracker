import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:bush_track/features/navigation/services/navigation_service.dart';
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
  // Tracks whether an off-route alert is currently pending so the AI monitor
  // can pick it up without re-triggering every 5 seconds.
  bool offRouteFlagged = false;

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

  /// Geocode destination with Nominatim then route with OSRM.
  Future<void> calculateRoute(String destination) async {
    final locationState = ref.read(locationProvider);
    final originLat = locationState.stats.currentLat;
    final originLon = locationState.stats.currentLon;
    if (originLat == null || originLon == null) return;

    try {
      // Geocode destination via Nominatim
      final geoUri = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeQueryComponent(destination)}&format=json&limit=1');
      final geoResp = await http.get(geoUri, headers: {'User-Agent': 'BushTrack/1.0'})
          .timeout(const Duration(seconds: 10));
      if (geoResp.statusCode != 200) return;
      final geoData = jsonDecode(geoResp.body) as List<dynamic>;
      if (geoData.isEmpty) return;

      final place = geoData.first as Map<String, dynamic>;
      final destLat = double.tryParse(place['lat']?.toString() ?? '') ?? 0;
      final destLon = double.tryParse(place['lon']?.toString() ?? '') ?? 0;
      final placeName = place['display_name']?.toString().split(',').first ?? destination;

      await navigateTo(destLat, destLon, placeName);
    } catch (e) {
      debugPrint('calculateRoute error: $e');
    }
  }

  /// Navigate directly to coordinates using OSRM (free, no API key).
  Future<void> navigateTo(double destLat, double destLon, String name) async {
    final locationState = ref.read(locationProvider);
    final originLat = locationState.stats.currentLat;
    final originLon = locationState.stats.currentLon;
    if (originLat == null || originLon == null) return;

    // OSRM public routing API — lon,lat order (GeoJSON)
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '$originLon,$originLat;$destLon,$destLat'
      '?overview=full&geometries=geojson&steps=true',
    );

    try {
      final response = await http.get(url, headers: {'User-Agent': 'BushTrack/1.0'})
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        _fallbackNavigation(destLat, destLon, name);
        return;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = (data['routes'] as List<dynamic>? ?? const []);
      if (routes.isEmpty) {
        _fallbackNavigation(destLat, destLon, name);
        return;
      }

      final routeData = routes.first as Map<String, dynamic>;
      final geometry = routeData['geometry'] as Map<String, dynamic>?;
      final coords = (geometry?['coordinates'] as List<dynamic>? ?? const []);
      final polyline = coords.map((pt) {
        final pair = pt as List<dynamic>;
        return LatLng((pair[1] as num).toDouble(), (pair[0] as num).toDouble());
      }).toList();

      final steps = <NavigationStep>[];
      for (final leg in (routeData['legs'] as List<dynamic>? ?? const [])) {
        for (final step in (leg['steps'] as List<dynamic>? ?? const [])) {
          final s = step as Map<String, dynamic>;
          final m = (s['maneuver'] as Map<String, dynamic>? ?? const {});
          final loc = m['location'] as List<dynamic>? ?? const [];
          steps.add(NavigationStep(
            instruction: m['instruction']?.toString() ??
                s['name']?.toString() ??
                'Continue',
            distanceM: (s['distance'] as num? ?? 0).toDouble(),
            bearing: (m['bearing_after'] as num? ?? 0).toDouble(),
            location: loc.length >= 2
                ? LatLng((loc[1] as num).toDouble(), (loc[0] as num).toDouble())
                : LatLng(destLat, destLon),
            manoeuvreType: m['type']?.toString() ?? 'straight',
          ));
        }
      }

      startNavigation(steps,
          route: RouteOption(
            name: 'To $name',
            distanceKm: (routeData['distance'] as num? ?? 0) / 1000.0,
            estimatedTimeMin:
                ((routeData['duration'] as num? ?? 0) / 60).round(),
            tradeoffs: const [],
            terrainDifficulty: 'OSRM',
            polyline: NavigationService.encodePolyline(polyline),
          ));
    } catch (e) {
      debugPrint('navigateTo error: $e');
      _fallbackNavigation(destLat, destLon, name);
    }
  }

  void _fallbackNavigation(double destLat, double destLon, String name) {
    startNavigation([
      NavigationStep(
        instruction: 'Head toward $name',
        distanceM: 0,
        bearing: 0,
        location: LatLng(destLat, destLon),
        manoeuvreType: 'straight',
      )
    ],
        route: RouteOption(
          name: 'To $name',
          distanceKm: 0,
          estimatedTimeMin: 0,
          tradeoffs: const [],
          terrainDifficulty: 'straight-line',
        ));
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

  /// Check if the user is off-route using live GPS position.
  void _checkOffRouteCondition() {
    if (!state.isActive || state.routePolyline.isEmpty) return;
    final locationState = ref.read(locationProvider);
    final lat = locationState.stats.currentLat;
    final lon = locationState.stats.currentLon;
    if (lat == null || lon == null) return;
    updateOffRouteStatus(LatLng(lat, lon));
  }

  /// Update off-route status based on user's current position.
  void updateOffRouteStatus(LatLng userPosition) {
    if (state.routePolyline.isEmpty) return;

    double minDistance = double.infinity;
    for (int i = 0; i < state.routePolyline.length - 1; i++) {
      final d = NavigationService.distanceToSegment(
          userPosition, state.routePolyline[i], state.routePolyline[i + 1]);
      if (d < minDistance) minDistance = d;
    }

    final distanceM = minDistance;
    final isOffRoute = distanceM > 100.0;

    if (state.isOffRoute != isOffRoute ||
        (distanceM - state.offRouteDistanceM).abs() > 10) {
      state = state.copyWith(
        isOffRoute: isOffRoute,
        offRouteDistanceM: distanceM,
      );
    }

    // Flag new off-route transitions so ai_monitor_service can speak the alert.
    if (isOffRoute && !offRouteFlagged) {
      offRouteFlagged = true;
    } else if (!isOffRoute) {
      offRouteFlagged = false;
    }
  }

  @override
  void dispose() {
    _stopOffRouteMonitoring();
    super.dispose();
  }
}

final navigationProvider =
    StateNotifierProvider<NavigationNotifier, NavigationState>((ref) {
  return NavigationNotifier(ref);
});
