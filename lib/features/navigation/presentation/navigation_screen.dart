import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:bush_track/theme/app_colors.dart';
import 'package:bush_track/features/navigation/providers/navigation_provider.dart';
import 'package:bush_track/features/tracking/providers/location_provider.dart';
import 'package:bush_track/core/config/api_config.dart';

class NavigationScreen extends ConsumerStatefulWidget {
  const NavigationScreen({super.key});

  @override
  ConsumerState<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends ConsumerState<NavigationScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize with sample navigation steps for demonstration
    Future.microtask(() => _initializeSampleNavigation());
  }

  void _initializeSampleNavigation() {
    // In a real implementation, this would be calculated using OSRM
    final steps = [
      NavigationStep(
        instruction: "Head north on Outback Track",
        distanceM: 500,
        bearing: 0,
        location: const LatLng(-25.3444, 131.0369),
        manoeuvreType: "straight",
      ),
      NavigationStep(
        instruction: "Turn right onto Laverton Road",
        distanceM: 200,
        bearing: 90,
        location: const LatLng(-25.3400, 131.0369),
        manoeuvreType: "right",
      ),
      NavigationStep(
        instruction: "Continue straight for 12 kilometres",
        distanceM: 12000,
        bearing: 90,
        location: const LatLng(-25.3400, 131.0400),
        manoeuvreType: "straight",
      ),
      NavigationStep(
        instruction: "You have arrived at your destination",
        distanceM: 0,
        bearing: 0,
        location: const LatLng(-25.3300, 131.0500),
        manoeuvreType: "arrive",
      ),
    ];

    // Sample encoded polyline for demonstration
    // This represents a simple route from Uluru to a point northeast
    const samplePolyline = "_lh~Dmjyu@r@o@|@}@~@}@|@}@~@}@|@}@~@}@|@}@~@}@|@}@~@}@";
    
    final route = RouteOption(
      name: "Sample Route",
      distanceKm: 15.2,
      estimatedTimeMin: 30,
      tradeoffs: ["Unsealed road", "Scenic views"],
      terrainDifficulty: "Medium",
      polyline: samplePolyline,
    );

    ref.read(navigationProvider.notifier).startNavigation(steps, route: route);
  }

  @override
  Widget build(BuildContext context) {
    final navigationState = ref.watch(navigationProvider);
    final locationState = ref.watch(locationProvider);
    
    // Update off-route status when location changes
    ref.listen<LocationState>(locationProvider, (previous, next) {
      if (next.stats.currentLat != null && next.stats.currentLon != null && navigationState.isActive) {
        final userPosition = LatLng(next.stats.currentLat!, next.stats.currentLon!);
        ref.read(navigationProvider.notifier).updateOffRouteStatus(userPosition);
      }
    });
    
    if (!navigationState.isActive) {
      return const Scaffold(
        body: Center(
          child: Text('No active navigation'),
        ),
      );
    }

    final currentStep = navigationState.currentStep;
    if (currentStep == null) {
      return const Scaffold(
        body: Center(
          child: Text('Navigation complete'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('🧭 NAVIGATION'),
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            ref.read(navigationProvider.notifier).stopNavigation();
            Navigator.pop(context);
          },
        ),
        // Off-route indicator
        actions: [
          if (navigationState.isOffRoute)
            IconButton(
              icon: const Icon(Icons.warning, color: Colors.red),
              onPressed: () {
                // In a real implementation, this would show more details about being off-route
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Navigation instruction panel
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: AppColors.panelMatte,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // Off-route warning
                if (navigationState.isOffRoute)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '⚠️ OFF ROUTE - ${navigationState.offRouteDistanceM.toStringAsFixed(0)}m from route',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Text(
                  currentStep.instruction,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  '${(currentStep.distanceM / 1000).toStringAsFixed(1)} km',
                  style: const TextStyle(
                    fontSize: 18,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                // Progress indicator
                LinearProgressIndicator(
                  value: (navigationState.currentStepIndex + 1) / navigationState.steps.length,
                  backgroundColor: AppColors.panelLight,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryOrange),
                ),
                const SizedBox(height: 8),
                Text(
                  '${navigationState.currentStepIndex + 1} of ${navigationState.steps.length}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (currentStep.bannerInstruction != null)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primaryOrange.withValues(alpha: 0.3)),
              ),
              child: Text(
                currentStep.bannerInstruction!,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          
          // Map view with route polyline
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: currentStep.location,
                initialZoom: 15.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: ApiConfig.mapboxToken.isEmpty
                      ? 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png'
                      : ApiConfig.mapboxTilesUrl('mapbox/navigation-night-v1', 'png'),
                ),
                // Route polyline
                if (navigationState.routePolyline.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: navigationState.routePolyline,
                        color: AppColors.primaryOrange,
                        strokeWidth: 4.0,
                      ),
                    ],
                  ),
                // Current step marker
                MarkerLayer(
                  markers: [
                    Marker(
                      point: currentStep.location,
                      width: 40,
                      height: 40,
                      child: Icon(
                        _getManoeuvreIcon(currentStep.manoeuvreType),
                        color: AppColors.primaryOrange,
                        size: 40,
                      ),
                    ),
                  ],
                ),
                // User location marker (if available)
                if (locationState.stats.currentLat != null && locationState.stats.currentLon != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(
                          locationState.stats.currentLat!,
                          locationState.stats.currentLon!,
                        ),
                        width: 30,
                        height: 30,
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.blue,
                          size: 30,
                        ),
                      ),
                    ],
                  ),
                if (locationState.stats.currentLat != null && locationState.stats.currentLon != null && locationState.stats.currentAccuracyM >= 10)
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: LatLng(locationState.stats.currentLat!, locationState.stats.currentLon!),
                        radius: locationState.stats.currentAccuracyM,
                        useRadiusInMeter: true,
                        color: const Color(0xFF7B2FFF).withValues(alpha: 0.15),
                        borderColor: const Color(0xFF7B2FFF).withValues(alpha: 0.4),
                        borderStrokeWidth: 1,
                      ),
                    ],
                  ),
              ],
            ),
          ),
          
          // Navigation controls
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: AppColors.panelMatte,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, size: 32),
                  color: AppColors.textPrimary,
                  onPressed: navigationState.currentStepIndex > 0 
                    ? () => ref.read(navigationProvider.notifier).previousStep()
                    : null,
                ),
                FloatingActionButton(
                  backgroundColor: AppColors.primaryOrange,
                  child: const Icon(Icons.navigation, size: 32),
                  onPressed: () {
                    // In a real implementation, this would trigger voice guidance
                    // For now, we'll just move to the next step
                    if (navigationState.currentStepIndex < navigationState.steps.length - 1) {
                      ref.read(navigationProvider.notifier).nextStep();
                    } else {
                      // Navigation complete
                      ref.read(navigationProvider.notifier).stopNavigation();
                      Navigator.pop(context);
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward, size: 32),
                  color: AppColors.textPrimary,
                  onPressed: navigationState.currentStepIndex < navigationState.steps.length - 1
                    ? () => ref.read(navigationProvider.notifier).nextStep()
                    : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  IconData _getManoeuvreIcon(String manoeuvreType) {
    switch (manoeuvreType) {
      case 'left':
        return Icons.turn_left;
      case 'right':
        return Icons.turn_right;
      case 'straight':
        return Icons.arrow_upward;
      case 'arrive':
        return Icons.flag;
      default:
        return Icons.navigation;
    }
  }
  
  // ignore: unused_element
  String _getManoeuvreDescription(String manoeuvreType) {
    switch (manoeuvreType) {
      case 'left':
        return 'Turn left';
      case 'right':
        return 'Turn right';
      case 'straight':
        return 'Continue straight';
      case 'arrive':
        return 'You have arrived';
      default:
        return 'Follow route';
    }
  }
}
