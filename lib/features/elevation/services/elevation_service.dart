import 'package:latlong2/latlong.dart';

class ElevationService {
  // Fetch elevation data for a given location
  static Future<double?> getElevation(LatLng location) async {
    try {
      // Convert lat/lon to tile coordinates
      // const zoom = 12;
      // final tileX = ((location.longitude + 180) / 360 * (1 << zoom)).floor();
      // final tileY = ((1 - (log(tan(location.latitude * pi / 180) + 1 / cos(location.latitude * pi / 180))) / pi) / 2 * (1 << zoom)).floor();
      
      // For simplicity, we'll return a mock elevation
      // In a real implementation, you would fetch the actual DEM tile and extract elevation
      return _mockElevation(location);
    } catch (e) {
      // Handle error or return null for offline mode
      return null;
    }
  }
  
  // Generate mock elevation data for demonstration
  static double _mockElevation(LatLng location) {
    // Simple sine wave pattern to simulate terrain
    final latFactor = (location.latitude * 1000).remainder(360);
    final lonFactor = (location.longitude * 1000).remainder(360);
    final elevation = (latFactor + lonFactor) % 200; // Elevation between 0-200m
    return elevation;
  }
  
  // Calculate elevation profile for a route
  static Future<List<ElevationPoint>> getElevationProfile(List<LatLng> route) async {
    final profile = <ElevationPoint>[];
    
    for (int i = 0; i < route.length; i++) {
      final elevation = await getElevation(route[i]);
      profile.add(ElevationPoint(
        point: route[i],
        elevation: elevation ?? 0.0,
        distance: i.toDouble() * 100, // Mock distance
      ));
    }
    
    return profile;
  }
}

class ElevationPoint {
  final LatLng point;
  final double elevation;
  final double distance;

  ElevationPoint({
    required this.point,
    required this.elevation,
    required this.distance,
  });
}