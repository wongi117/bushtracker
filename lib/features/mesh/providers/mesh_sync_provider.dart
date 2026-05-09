import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../tracking/providers/location_provider.dart';
import 'mesh_provider.dart';

/// This provider acts as a bridge between location and mesh.
/// It listens to location updates and broadcasts them to the mesh network.
final meshSyncProvider = Provider<void>((ref) {
  // Listen to location updates
  ref.listen(locationProvider, (previous, next) {
    final prevLat = previous?.stats.currentLat;
    final prevLon = previous?.stats.currentLon;
    final nextLat = next.stats.currentLat;
    final nextLon = next.stats.currentLon;

    // Only broadcast if location has changed significantly or every 30 seconds
    if (nextLat != null && nextLon != null) {
      if (prevLat == null || prevLon == null || 
          (nextLat - prevLat).abs() > 0.0001 || 
          (nextLon - prevLon).abs() > 0.0001) {
        ref.read(meshProvider.notifier).broadcastLocation(nextLat, nextLon);
      }
    }
  });
});
