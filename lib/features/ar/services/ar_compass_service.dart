import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math';

class ARCompassService {
  final Ref ref;
  
  // In a real implementation, this would integrate with device sensors
  // For now, we'll simulate the functionality
  
  ARCompassService(this.ref);

  // Get the user's current heading (in degrees)
  Future<double> getCurrentHeading() async {
    // In a real implementation, this would use the device's compass/magnetometer
    // For now, we'll return a simulated value
    return 45.0; // Facing northeast
  }

  // Calculate the bearing to a waypoint
  double calculateBearing(LatLng currentLocation, LatLng targetLocation) {
    final lat1 = _toRadians(currentLocation.latitude);
    final lon1 = _toRadians(currentLocation.longitude);
    final lat2 = _toRadians(targetLocation.latitude);
    final lon2 = _toRadians(targetLocation.longitude);
    
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

  // Calculate the distance to a waypoint (in meters)
  double calculateDistance(LatLng currentLocation, LatLng targetLocation) {
    return Geolocator.distanceBetween(
      currentLocation.latitude,
      currentLocation.longitude,
      targetLocation.latitude,
      targetLocation.longitude,
    );
  }

  // Convert degrees to radians
  double _toRadians(double degrees) {
    return degrees * (pi / 180);
  }

  // Convert radians to degrees
  double _toDegrees(double radians) {
    return radians * (180 / pi);
  }
}

// Provider for the AR compass service
final arCompassServiceProvider = Provider((ref) {
  return ARCompassService(ref);
});