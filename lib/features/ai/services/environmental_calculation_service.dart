import 'dart:math';
import 'package:latlong2/latlong.dart';

class EnvironmentalCalculationService {
  /// Calculate hours until sunset for a given location
  static Future<double?> getHoursUntilSunset(LatLng location) async {
    try {
      final now = DateTime.now();
      final sunset = _calculateSunset(location.latitude, location.longitude, now);
      
      if (sunset.isAfter(now)) {
        final difference = sunset.difference(now);
        return difference.inMinutes / 60.0;
      }
      
      return null;
    } catch (e) {
      // Return null for offline mode or errors
      return null;
    }
  }

  /// Calculate sunset time for a given location and date
  static DateTime _calculateSunset(double lat, double lon, DateTime date) {
    // Approximate calculation using standard astronomical formulas
    final dayOfYear = date.difference(DateTime(date.year, 1, 1)).inDays + 1;
    const zenith = 90.83333333333333; // Sunrise/set zenith angle
    
    // Convert latitude to radians
    final latRad = _toRadians(lat);
    
    // Calculate day angle
    final dayAngle = (2 * pi * (dayOfYear - 1)) / 365;
    
    // Calculate equation of time and solar declination
    final eqTime = 229.18 * (0.000075 + 0.001868 * cos(dayAngle) - 
                  0.032077 * sin(dayAngle) - 0.014615 * cos(2 * dayAngle) - 
                  0.040849 * sin(2 * dayAngle));
                  
    final decl = 0.006918 - 0.399912 * cos(dayAngle) + 0.070257 * sin(dayAngle) -
                 0.006758 * cos(2 * dayAngle) + 0.000907 * sin(2 * dayAngle) -
                 0.002697 * cos(3 * dayAngle) + 0.00148 * sin(3 * dayAngle);
                 
    // Calculate timezone offset (simplified)
    // final timezoneOffset = lon ~/ 15.0;
    
    // Calculate time offset
    // final timeOffset = eqTime + 4 * lon - 60 * timezoneOffset;
    
    // Calculate true solar time
    // tst = date.hour * 60 + date.minute + date.second / 60 + timeOffset;
    
    // Calculate hour angle
    final haRad = (cos(_toRadians(zenith)) / (cos(latRad) * cos(decl)) - 
                  tan(latRad) * tan(decl));
                  
    // Handle polar day/night
    if (haRad < -1 || haRad > 1) {
      // Polar day/night - return appropriate time
      return DateTime(date.year, date.month, date.day, 18, 0); // Default to 6PM
    }
    
    final ha = _toDegrees(acos(haRad));
    
    // Calculate sunset time
    final sunsetTime = 720 + 4 * lon - eqTime + ha;
    final sunsetHours = (sunsetTime ~/ 60) % 24;
    final sunsetMinutes = (sunsetTime % 60).toInt();
    
    return DateTime(date.year, date.month, date.day, sunsetHours, sunsetMinutes);
  }

  /// Convert degrees to radians
  static double _toRadians(double degrees) {
    return degrees * (pi / 180);
  }

  /// Convert radians to degrees
  static double _toDegrees(double radians) {
    return radians * (180 / pi);
  }

  /// Estimate battery level (mock implementation)
  static Future<double?> getBatteryLevel() async {
    // In a real implementation, this would use battery_plus package
    // For now, return null to indicate unavailable or return mock value for testing
    return null; // or return 85.0 for testing
  }
}