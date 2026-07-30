import 'dart:math' show sqrt, atan2, sin, cos, Random, asin;
import 'package:latlong2/latlong.dart';
import 'package:bush_track/features/elevation/services/elevation_service.dart';

class GeographicAnalysisService {
  /// Calculate the distance between two points in meters using Haversine formula
  static double calculateDistance(LatLng point1, LatLng point2) {
    const R = 6371000.0; // Earth radius in meters
    double dLat = _toRadians(point2.latitude - point1.latitude);
    double dLon = _toRadians(point2.longitude - point1.longitude);
    double a = sin(dLat / 2) * sin(dLat / 2) +
               cos(_toRadians(point1.latitude)) * cos(_toRadians(point2.latitude)) *
               sin(dLon / 2) * sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  /// Calculate the gradient (slope) between two points
  static Future<double> calculateGradient(LatLng point1, LatLng point2) async {
    final elevation1 = await ElevationService.getElevation(point1) ?? 0.0;
    final elevation2 = await ElevationService.getElevation(point2) ?? 0.0;
    
    final distance = calculateDistance(point1, point2);
    if (distance == 0) return 0.0;
    
    final elevationDiff = elevation2 - elevation1;
    final gradient = (elevationDiff / distance) * 100; // Percentage grade
    
    return gradient.abs(); // Return absolute value for flatness assessment
  }

  /// Calculate average gradient around a point (sample points in a circle)
  static Future<double> calculateAreaFlatness(LatLng center, {double radiusMeters = 50}) async {
    const samplePoints = 8;
    double totalGradient = 0.0;
    
    for (int i = 0; i < samplePoints; i++) {
      final angle = (2 * pi * i) / samplePoints;
      final point = _destinationPoint(center, radiusMeters, angle);
      final gradient = await calculateGradient(center, point);
      totalGradient += gradient;
    }
    
    return totalGradient / samplePoints;
  }

  /// Estimate distance to nearest water source (mock implementation)
  static Future<double> estimateDistanceToWater(LatLng location) async {
    // In a real implementation, this would check against water body databases
    // For now, we'll use a mock algorithm based on coordinates
    
    // Simple mock: assume water sources at regular intervals
    // This is just for demonstration purposes
    final latGrid = (location.latitude * 10).round().toDouble() / 10;
    final lonGrid = (location.longitude * 10).round().toDouble() / 10;
    
    // Calculate distance to nearest "water source"
    final waterSource = LatLng(latGrid, lonGrid);
    final distance = calculateDistance(location, waterSource);
    
    // Add some randomness
    final randomFactor = 1.0 + (Random().nextDouble() * 0.5); // 0-50% variation
    
    return distance * randomFactor;
  }

  /// Score a potential campsite based on flatness and water proximity
  static Future<CampSiteScore> scoreCampsite(LatLng location) async {
    // Calculate flatness (lower is better for camping)
    final flatness = await calculateAreaFlatness(location);
    final flatnessScore = _calculateFlatnessScore(flatness);
    
    // Calculate water proximity (closer is better, but not too close)
    final waterDistance = await estimateDistanceToWater(location);
    final waterScore = _calculateWaterProximityScore(waterDistance);
    
    // Combine scores (weighted average)
    final finalScore = (flatnessScore * 0.6) + (waterScore * 0.4);
    
    return CampSiteScore(
      location: location,
      flatness: flatness,
      flatnessScore: flatnessScore,
      waterDistance: waterDistance,
      waterScore: waterScore,
      overallScore: finalScore,
    );
  }

  /// Find the best campsite in the vicinity
  static Future<CampSiteScore?> findBestCampsite(LatLng currentLocation, {double searchRadiusMeters = 500}) async {
    CampSiteScore? bestSite;
    double bestScore = 0.0;
    
    // Sample points in a grid around the current location
    const gridSize = 5; // 5x5 grid
    final stepSize = searchRadiusMeters / gridSize;
    
    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        // Calculate offset from current location
        final offsetLat = (i - gridSize ~/ 2) * (stepSize / 111000); // Rough conversion to degrees
        final offsetLon = (j - gridSize ~/ 2) * (stepSize / 85000);  // Rough conversion to degrees (varies with latitude)
        
        final candidateLocation = LatLng(
          currentLocation.latitude + offsetLat,
          currentLocation.longitude + offsetLon,
        );
        
        // Skip if too far from original search area
        if (calculateDistance(currentLocation, candidateLocation) > searchRadiusMeters) {
          continue;
        }
        
        final score = await scoreCampsite(candidateLocation);
        if (score.overallScore > bestScore) {
          bestScore = score.overallScore;
          bestSite = score;
        }
      }
    }
    
    return bestSite;
  }

  /// Convert degrees to radians
  static double _toRadians(double degrees) {
    return degrees * (pi / 180);
  }

  /// Calculate flatness score (0-100, where 100 is perfectly flat)
  static double _calculateFlatnessScore(double gradientPercent) {
    // Perfectly flat = 0% gradient = 100 score
    // Very steep = 50%+ gradient = 0 score
    if (gradientPercent <= 1.0) return 100.0;
    if (gradientPercent >= 30.0) return 0.0;
    
    // Linear interpolation between 1% and 30%
    return 100.0 - ((gradientPercent - 1.0) / 29.0) * 100.0;
  }

  /// Calculate water proximity score (0-100, where 100 is ideal distance)
  static double _calculateWaterProximityScore(double distanceMeters) {
    // Ideal camping distance: 50-200 meters from water
    // Too close (< 20m) = dangerous (flooding, insects) = 0 score
    // Too far (> 1000m) = inconvenient = 0 score
    if (distanceMeters < 20 || distanceMeters > 1000) return 0.0;
    if (distanceMeters >= 50 && distanceMeters <= 200) return 100.0;
    
    // Score decreases as you move away from ideal range
    if (distanceMeters < 50) {
      // Getting closer to dangerous zone
      return ((distanceMeters - 20) / 30) * 100;
    } else {
      // Getting farther from ideal zone
      return ((1000 - distanceMeters) / 800) * 100;
    }
  }

  /// Calculate destination point given start point, distance, and bearing
  static LatLng _destinationPoint(LatLng start, double distanceMeters, double bearingRadians) {
    const R = 6371000.0; // Earth radius in meters
    final lat1 = _toRadians(start.latitude);
    final lon1 = _toRadians(start.longitude);
    
    final angularDistance = distanceMeters / R;
    final bearing = bearingRadians;
    
    final lat2 = asin(sin(lat1) * cos(angularDistance) + 
                      cos(lat1) * sin(angularDistance) * cos(bearing));
    final lon2 = lon1 + atan2(sin(bearing) * sin(angularDistance) * cos(lat1),
                              cos(angularDistance) - sin(lat1) * sin(lat2));
    
    return LatLng(_toDegrees(lat2), _toDegrees(lon2));
  }

  /// Convert radians to degrees
  static double _toDegrees(double radians) {
    return radians * (180 / pi);
  }
}

class CampSiteScore {
  final LatLng location;
  final double flatness; // Gradient percentage
  final double flatnessScore; // 0-100 score
  final double waterDistance; // Meters to water
  final double waterScore; // 0-100 score
  final double overallScore; // Combined weighted score

  CampSiteScore({
    required this.location,
    required this.flatness,
    required this.flatnessScore,
    required this.waterDistance,
    required this.waterScore,
    required this.overallScore,
  });
}