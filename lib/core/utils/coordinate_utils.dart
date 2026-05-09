import 'dart:math';
import 'package:latlong2/latlong.dart';

/// Utility class for coordinate conversions and calculations
/// Supports: Decimal Degrees, DMS, UTM, MGRS
class CoordinateUtils {
  static const double PI = 3.14159265358979323846;
  static const double DEG_TO_RAD = PI / 180.0;
  static const double RAD_TO_DEG = 180.0 / PI;

  // UTM Constants
  static const double SM_A = 6378137.0; // Major axis (WGS84)
  static const double SM_B = 6356752.314; // Minor axis
  static const double UTM_SCALE_FACTOR = 0.9996;

  /// Calculate distance between two points using Haversine formula
  static double calculateDistance(LatLng point1, LatLng point2) {
    const R = 6371000; // Earth radius in meters

    final lat1Rad = point1.latitude * DEG_TO_RAD;
    final lat2Rad = point2.latitude * DEG_TO_RAD;
    final deltaLat = (point2.latitude - point1.latitude) * DEG_TO_RAD;
    final deltaLon = (point2.longitude - point1.longitude) * DEG_TO_RAD;

    final a = sin(deltaLat / 2) * sin(deltaLat / 2) +
        cos(lat1Rad) * cos(lat2Rad) * sin(deltaLon / 2) * sin(deltaLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return R * c;
  }

  /// Calculate bearing (forward azimuth) from point1 to point2
  static double calculateBearing(LatLng point1, LatLng point2) {
    final lat1Rad = point1.latitude * DEG_TO_RAD;
    final lat2Rad = point2.latitude * DEG_TO_RAD;
    final deltaLon = (point2.longitude - point1.longitude) * DEG_TO_RAD;

    final y = sin(deltaLon) * cos(lat2Rad);
    final x = cos(lat1Rad) * sin(lat2Rad) -
        sin(lat1Rad) * cos(lat2Rad) * cos(deltaLon);

    final bearing = atan2(y, x) * RAD_TO_DEG;
    return (bearing + 360) % 360;
  }

  /// Get cardinal direction from bearing
  static String getCardinalDirection(double bearing) {
    const directions = [
      'N',
      'NNE',
      'NE',
      'ENE',
      'E',
      'ESE',
      'SE',
      'SSE',
      'S',
      'SSW',
      'SW',
      'WSW',
      'W',
      'WNW',
      'NW',
      'NNW'
    ];
    final index = ((bearing + 11.25) % 360 / 22.5).floor();
    return directions[index % 16];
  }

  /// Format distance for display
  static String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(1)} m';
    } else if (meters < 10000) {
      return '${(meters / 1000).toStringAsFixed(2)} km';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
  }

  /// Format bearing with degrees and cardinal
  static String formatBearing(double degrees) {
    final cardinal = getCardinalDirection(degrees);
    return '${degrees.toStringAsFixed(1)}° $cardinal';
  }

  /// Convert Decimal Degrees to DMS (Degrees Minutes Seconds)
  static DmsCoordinate decimalToDms(double decimal, bool isLatitude) {
    final absDecimal = decimal.abs();
    final degrees = absDecimal.floor();
    final minutesFull = (absDecimal - degrees) * 60;
    final minutes = minutesFull.floor();
    final seconds = (minutesFull - minutes) * 60;

    final direction =
        isLatitude ? (decimal >= 0 ? 'N' : 'S') : (decimal >= 0 ? 'E' : 'W');

    return DmsCoordinate(
      degrees: degrees,
      minutes: minutes,
      seconds: seconds,
      direction: direction,
    );
  }

  /// Convert DMS to Decimal Degrees
  static double dmsToDecimal(DmsCoordinate dms) {
    final decimal = dms.degrees + dms.minutes / 60 + dms.seconds / 3600;
    final multiplier = (dms.direction == 'S' || dms.direction == 'W') ? -1 : 1;
    return decimal * multiplier;
  }

  /// Convert to UTM (Universal Transverse Mercator)
  static UtmCoordinate decimalToUtm(double latitude, double longitude) {
    final latRad = latitude * DEG_TO_RAD;
    final lonRad = longitude * DEG_TO_RAD;

    // Determine UTM zone
    final zoneNumber = ((longitude + 180) / 6).floor() + 1;
    final zoneLetter = _getUtmZoneLetter(latitude);

    // Calculate central meridian for zone
    final centralMeridian = (zoneNumber - 1) * 6 - 180 + 3;
    final centralMeridianRad = centralMeridian * DEG_TO_RAD;

    // UTM calculations
    const eccPrimeSquared = (SM_A * SM_A - SM_B * SM_B) / (SM_B * SM_B);

    final N = SM_A / sqrt(1 - eccPrimeSquared * sin(latRad) * sin(latRad));
    final T = tan(latRad) * tan(latRad);
    final C = eccPrimeSquared * cos(latRad) * cos(latRad);
    final A = cos(latRad) * (lonRad - centralMeridianRad);

    final M = SM_A *
        ((1 -
                    eccPrimeSquared / 4 -
                    3 * eccPrimeSquared * eccPrimeSquared / 64 -
                    5 *
                        eccPrimeSquared *
                        eccPrimeSquared *
                        eccPrimeSquared /
                        256) *
                latRad -
            (3 * eccPrimeSquared / 8 +
                    3 * eccPrimeSquared * eccPrimeSquared / 32 +
                    45 *
                        eccPrimeSquared *
                        eccPrimeSquared *
                        eccPrimeSquared /
                        1024) *
                sin(2 * latRad) +
            (15 * eccPrimeSquared * eccPrimeSquared / 256 +
                    45 *
                        eccPrimeSquared *
                        eccPrimeSquared *
                        eccPrimeSquared /
                        1024) *
                sin(4 * latRad) -
            (35 * eccPrimeSquared * eccPrimeSquared * eccPrimeSquared / 3072) *
                sin(6 * latRad));

    final utmEasting = (UTM_SCALE_FACTOR *
            N *
            (A +
                (1 - T + C) * A * A * A / 6 +
                (5 - 18 * T + T * T + 72 * C - 58 * eccPrimeSquared) *
                    A *
                    A *
                    A *
                    A *
                    A /
                    120) +
        500000.0);

    var utmNorthing = (UTM_SCALE_FACTOR *
        (M +
            N *
                tan(latRad) *
                (A * A / 2 +
                    (5 - T + 9 * C + 4 * C * C) * A * A * A * A / 24 +
                    (61 - 58 * T + T * T + 600 * C - 330 * eccPrimeSquared) *
                        A *
                        A *
                        A *
                        A *
                        A *
                        A /
                        720)));

    if (latitude < 0) {
      utmNorthing += 10000000.0; // Offset for southern hemisphere
    }

    return UtmCoordinate(
      easting: utmEasting,
      northing: utmNorthing,
      zoneNumber: zoneNumber,
      zoneLetter: zoneLetter,
      hemisphere: latitude >= 0 ? 'N' : 'S',
    );
  }

  /// Get UTM zone letter based on latitude
  static String _getUtmZoneLetter(double latitude) {
    const letters = [
      'C',
      'D',
      'E',
      'F',
      'G',
      'H',
      'J',
      'K',
      'L',
      'M',
      'N',
      'P',
      'Q',
      'R',
      'S',
      'T',
      'U',
      'V',
      'W',
      'X'
    ];

    if (latitude < -80 || latitude > 84) return 'Z';

    final index = ((latitude + 80) / 8).floor();
    return letters[index.clamp(0, 19)];
  }

  /// Convert to MGRS (Military Grid Reference System)
  static String decimalToMgrs(double latitude, double longitude) {
    final utm = decimalToUtm(latitude, longitude);

    // Get 100km square identification
    final col = (utm.easting / 100000).floor();
    final row = (utm.northing / 100000).floor() % 20;

    final easting100k = utm.easting % 100000;
    final northing100k = utm.northing % 100000;

    // Format MGRS: Zone ID + 100km ID + 5-digit easting + 5-digit northing
    final zoneId = '${utm.zoneNumber}${utm.zoneLetter}';
    final gridId =
        '${String.fromCharCode(65 + col % 24)}${String.fromCharCode(65 + row)}';
    final eastingStr = easting100k.toInt().toString().padLeft(5, '0');
    final northingStr = northing100k.toInt().toString().padLeft(5, '0');

    return '$zoneId $gridId $eastingStr $northingStr';
  }

  /// Calculate area of polygon in square meters
  static double calculatePolygonArea(List<LatLng> points) {
    if (points.length < 3) return 0;

    double area = 0;
    for (int i = 0; i < points.length; i++) {
      final j = (i + 1) % points.length;
      area += points[i].longitude * points[j].latitude;
      area -= points[j].longitude * points[i].latitude;
    }

    area = area.abs() * cos(points[0].latitude * DEG_TO_RAD) / 2.0;
    return area * 111319.9 * 111319.9; // Approximate conversion
  }

  /// Format area for display
  static String formatArea(double squareMeters) {
    if (squareMeters < 10000) {
      return '${squareMeters.toStringAsFixed(0)} m²';
    } else if (squareMeters < 1000000) {
      return '${(squareMeters / 10000).toStringAsFixed(2)} ha';
    } else {
      return '${(squareMeters / 1000000).toStringAsFixed(3)} km²';
    }
  }
}

/// DMS Coordinate representation
class DmsCoordinate {
  final int degrees;
  final int minutes;
  final double seconds;
  final String direction;

  DmsCoordinate({
    required this.degrees,
    required this.minutes,
    required this.seconds,
    required this.direction,
  });

  @override
  String toString() {
    return '$degrees° $minutes\' ${seconds.toStringAsFixed(2)}" $direction';
  }

  String toCompactString() {
    return '$degrees°$minutes\'${seconds.toInt()}"$direction';
  }
}

/// UTM Coordinate representation
class UtmCoordinate {
  final double easting;
  final double northing;
  final int zoneNumber;
  final String zoneLetter;
  final String hemisphere;

  UtmCoordinate({
    required this.easting,
    required this.northing,
    required this.zoneNumber,
    required this.zoneLetter,
    required this.hemisphere,
  });

  @override
  String toString() {
    return '$zoneNumber$zoneLetter ${easting.toStringAsFixed(1)}mE ${northing.toStringAsFixed(1)}mN';
  }

  String toCompactString() {
    return '$zoneNumber$zoneLetter ${easting.toInt()}E ${northing.toInt()}N';
  }
}

/// Coordinate format types
enum CoordinateFormat {
  decimalDegrees,
  dms,
  utm,
  mgrs,
}

/// Measurement types
enum MeasurementType {
  distance,
  bearing,
  area,
}

/// Represents a measurement result
class Measurement {
  final MeasurementType type;
  final double value;
  final LatLng? point1;
  final LatLng? point2;
  final List<LatLng>? polygon;
  final DateTime timestamp;

  Measurement({
    required this.type,
    required this.value,
    this.point1,
    this.point2,
    this.polygon,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  String get formattedValue {
    switch (type) {
      case MeasurementType.distance:
        return CoordinateUtils.formatDistance(value);
      case MeasurementType.bearing:
        return CoordinateUtils.formatBearing(value);
      case MeasurementType.area:
        return CoordinateUtils.formatArea(value);
    }
  }
}
