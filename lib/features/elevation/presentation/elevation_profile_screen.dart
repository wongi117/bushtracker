import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:bush_track/theme/app_colors.dart';
import 'package:bush_track/features/elevation/providers/elevation_provider.dart';

class ElevationProfileScreen extends ConsumerStatefulWidget {
  const ElevationProfileScreen({super.key});

  @override
  ConsumerState<ElevationProfileScreen> createState() => _ElevationProfileScreenState();
}

class _ElevationProfileScreenState extends ConsumerState<ElevationProfileScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize with sample route for demonstration
    Future.microtask(() => _generateSampleProfile());
  }

  void _generateSampleProfile() {
    // Sample route points for demonstration
    final route = [
      const LatLng(-25.3444, 131.0369),
      const LatLng(-25.3400, 131.0400),
      const LatLng(-25.3350, 131.0450),
      const LatLng(-25.3300, 131.0500),
      const LatLng(-25.3250, 131.0550),
    ];
    
    ref.read(elevationProvider.notifier).generateElevationProfile(route);
  }

  @override
  Widget build(BuildContext context) {
    final elevationState = ref.watch(elevationProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('ELEVATION PROFILE'),
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (elevationState.isLoading)
              const Center(child: CircularProgressIndicator(color: AppColors.primaryOrange))
            else if (elevationState.error != null)
              Center(
                child: Text(
                  elevationState.error!,
                  style: const TextStyle(color: Colors.red),
                ),
              )
            else
              const Expanded(
                child: Center(
                  child: Text(
                    'Elevation data would be displayed here',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ),
            
            const SizedBox(height: 24),
            
            // Terrain analysis
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.panelMatte,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TERRAIN ANALYSIS',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Your route has 340m total elevation gain.',
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Steepest section has 18% grade.',
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Estimated difficulty: Medium. Allow extra time.',
                    style: TextStyle(color: AppColors.primaryOrange),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Real-time altitude
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.panelMatte,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'CURRENT ALTITUDE',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '450m',
                    style: TextStyle(
                      color: AppColors.primaryOrange,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}