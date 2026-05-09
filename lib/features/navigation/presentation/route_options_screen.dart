import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:bush_track/theme/app_colors.dart';
import 'package:bush_track/features/navigation/providers/navigation_provider.dart';

class RouteOptionsScreen extends ConsumerStatefulWidget {
  const RouteOptionsScreen({super.key});

  @override
  ConsumerState<RouteOptionsScreen> createState() => _RouteOptionsScreenState();
}

class _RouteOptionsScreenState extends ConsumerState<RouteOptionsScreen> {
  // Sample route options for demonstration
  final List<RouteOption> _routeOptions = [
    RouteOption(
      name: "Direct Track",
      distanceKm: 45.2,
      estimatedTimeMin: 54,
      tradeoffs: ["Unsealed road", "Faster", "4WD recommended"],
      terrainDifficulty: "Hard",
      polyline: "_lh~Dmjyu@r@o@|@}@~@}@|@}@~@}@|@}@~@}@|@}@~@}@|@}@~@}@",
    ),
    RouteOption(
      name: "Sealed Road Via Leonora",
      distanceKm: 67.8,
      estimatedTimeMin: 72,
      tradeoffs: ["Sealed road", "Longer", "All vehicles"],
      terrainDifficulty: "Easy",
      polyline: "_lh~Dmjyu@r@o@|@}@~@}@|@}@~@}@|@}@~@}@|@}@~@}@|@}@~@}@|@}@~@}@|@}@~@}@",
    ),
    RouteOption(
      name: "Scenic Route Via Norseman",
      distanceKm: 82.3,
      estimatedTimeMin: 95,
      tradeoffs: ["Scenic views", "Longest", "All vehicles"],
      terrainDifficulty: "Medium",
      polyline: "_lh~Dmjyu@r@o@|@}@~@}@|@}@~@}@|@}@~@}@|@}@~@}@|@}@~@}@|@}@~@}@|@}@~@}@|@}@~@}@",
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final selectedRoute = ref.watch(navigationProvider).selectedRoute;

    return Scaffold(
      appBar: AppBar(
        title: const Text('🛤️ ROUTE OPTIONS'),
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _routeOptions.length,
        itemBuilder: (context, index) {
          final route = _routeOptions[index];
          final isSelected = selectedRoute?.name == route.name;
          
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.panelLight : AppColors.panelMatte,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? AppColors.primaryOrange : Colors.transparent,
                width: 2,
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              title: Text(
                route.name,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isSelected ? AppColors.primaryOrange : Colors.white,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.route, size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Text(
                        '${route.distanceKm.toStringAsFixed(1)} km',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(width: 16),
                      const Icon(Icons.timer, size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Text(
                        '${route.estimatedTimeMin} min',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getDifficultyColor(route.terrainDifficulty),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      route.terrainDifficulty,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: route.tradeoffs.map((tradeoff) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.panelLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          tradeoff,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              trailing: isSelected
                  ? const Icon(Icons.check, color: AppColors.primaryOrange)
                  : null,
              onTap: () {
                ref.read(navigationProvider.notifier).selectRoute(route);
                setState(() {}); // Update UI to show selection
              },
            ),
          );
        },
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: AppColors.panelMatte,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              padding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: selectedRoute != null
                ? _startNavigation
                : null,
          child: const Text(
            '🧭 START NAVIGATION',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
  
  void _startNavigation() {
    final selectedRoute = ref.read(navigationProvider).selectedRoute;
    if (selectedRoute == null) return;
    
    // Create sample navigation steps based on the selected route
    final steps = [
      NavigationStep(
        instruction: "Head north on selected route",
        distanceM: selectedRoute.distanceKm * 1000 * 0.3,
        bearing: 0,
        location: const LatLng(-25.3444, 131.0369),
        manoeuvreType: "straight",
      ),
      NavigationStep(
        instruction: "Continue on route",
        distanceM: selectedRoute.distanceKm * 1000 * 0.5,
        bearing: 45,
        location: const LatLng(-25.3400, 131.0369),
        manoeuvreType: "straight",
      ),
      NavigationStep(
        instruction: "You have arrived at your destination",
        distanceM: selectedRoute.distanceKm * 1000 * 0.2,
        bearing: 0,
        location: const LatLng(-25.3300, 131.0500),
        manoeuvreType: "arrive",
      ),
    ];
    
    ref.read(navigationProvider.notifier).startNavigation(steps, route: selectedRoute);
    Navigator.pop(context);
  }
  
  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'hard':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}