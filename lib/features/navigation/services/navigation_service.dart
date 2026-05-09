import 'dart:math' show sqrt, sin, cos, atan2;
import 'package:latlong2/latlong.dart';

class NavigationService {
  /// Decodes an encoded polyline string into a list of LatLng points
  static List<LatLng> decodePolyline(String encoded) {
    List<LatLng> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      LatLng p = LatLng(lat / 1E5, lng / 1E5);
      poly.add(p);
    }

    return poly;
  }

  /// Encodes a list of LatLng points into an encoded polyline string
  static String encodePolyline(List<LatLng> points) {
    StringBuffer encoded = StringBuffer();
    int lastLat = 0, lastLng = 0;

    for (LatLng point in points) {
      int lat = (point.latitude * 1E5).round();
      int lng = (point.longitude * 1E5).round();

      encoded.write(_encodeSignedNumber(lat - lastLat));
      encoded.write(_encodeSignedNumber(lng - lastLng));

      lastLat = lat;
      lastLng = lng;
    }

    return encoded.toString();
  }

  /// Helper method for encoding signed numbers
  static String _encodeSignedNumber(int num) {
    num = num < 0 ? ~(num << 1) : num << 1;
    StringBuffer encoded = StringBuffer();

    while (num >= 0x20) {
      encoded.write(String.fromCharCode((0x20 | (num & 0x1f)) + 63));
      num >>= 5;
    }

    encoded.write(String.fromCharCode(num + 63));
    return encoded.toString();
  }

  /// Calculates the distance from a point to a line segment
  static double distanceToSegment(LatLng point, LatLng start, LatLng end) {
    double segmentLength = _distance(start, end);
    if (segmentLength == 0) return _distance(point, start);

    double t = ((point.longitude - start.longitude) * (end.longitude - start.longitude) +
                (point.latitude - start.latitude) * (end.latitude - start.latitude)) /
               (segmentLength * segmentLength);

    t = t.clamp(0.0, 1.0);

    LatLng projection = LatLng(
      start.latitude + t * (end.latitude - start.latitude),
      start.longitude + t * (end.longitude - start.longitude),
    );

    return _distance(point, projection);
  }

  /// Calculates the distance between two points in meters using Haversine formula
  static double _distance(LatLng from, LatLng to) {
    const R = 6371000.0; // Earth radius in meters
    double dLat = _toRadians(to.latitude - from.latitude);
    double dLon = _toRadians(to.longitude - from.longitude);
    double a = sin(dLat / 2) * sin(dLat / 2) +
               cos(_toRadians(from.latitude)) * cos(_toRadians(to.latitude)) *
               sin(dLon / 2) * sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  /// Converts degrees to radians
  static double _toRadians(double degrees) {
    return degrees * (3.14159265358979323846 / 180);
  }
}