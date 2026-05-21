import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:bush_track/features/elevation/services/elevation_service.dart';

class GeographicAnalysisService {
  static double calculateDistance(LatLng point1, LatLng point2) {
    const R = 6371000.0;
    final dLat = _toRadians(point2.latitude - point1.latitude);
    final dLon = _toRadians(point2.longitude - point1.longitude);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(point1.latitude)) *
            math.cos(_toRadians(point2.latitude)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  /// Find the best campsite in a 500 m radius using real DEM + Overpass water data.
  static Future<CampSiteScore?> findBestCampsite(
    LatLng currentLocation, {
    double searchRadiusMeters = 500,
  }) async {
    const gridSize = 5;
    final stepSize = searchRadiusMeters / gridSize;

    // 1. Build candidate grid
    final candidates = <LatLng>[];
    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        final offsetLat = (i - gridSize ~/ 2) * (stepSize / 111000);
        final offsetLon = (j - gridSize ~/ 2) * (stepSize / 85000);
        final pt = LatLng(
          currentLocation.latitude + offsetLat,
          currentLocation.longitude + offsetLon,
        );
        if (calculateDistance(currentLocation, pt) <= searchRadiusMeters) {
          candidates.add(pt);
        }
      }
    }

    // 2. For each candidate build 4 surrounding sample points (N/S/E/W at 40 m).
    //    Batch ALL points in one Open-Elevation request.
    const sampleDist = 40.0;
    final allPoints = <LatLng>[];
    for (final c in candidates) {
      allPoints.add(c);
      allPoints.add(_dest(c, sampleDist, 0));             // N
      allPoints.add(_dest(c, sampleDist, math.pi));       // S
      allPoints.add(_dest(c, sampleDist, math.pi / 2));   // E
      allPoints.add(_dest(c, sampleDist, -math.pi / 2));  // W
    }

    List<double> elevations;
    try {
      final raw = await ElevationService.getElevationProfile(allPoints);
      elevations = raw.map((e) => e.elevation).toList();
    } catch (_) {
      elevations = List.filled(allPoints.length, 0.0);
    }

    // 3. Fetch nearest water via Overpass (single request)
    final waterDistM = await _nearestWaterDistance(currentLocation);

    // 4. Score each candidate
    CampSiteScore? best;
    for (int ci = 0; ci < candidates.length; ci++) {
      final base = ci * 5;
      final centerElev = elevations[base];
      final maxDiff = [1, 2, 3, 4]
          .map((k) => (elevations[base + k] - centerElev).abs())
          .reduce((a, b) => a > b ? a : b);
      final gradientPct = (maxDiff / sampleDist) * 100;

      final flatScore = _flatnessScore(gradientPct);
      final wScore = _waterScore(waterDistM);
      final overall = flatScore * 0.6 + wScore * 0.4;

      final score = CampSiteScore(
        location: candidates[ci],
        flatness: gradientPct,
        flatnessScore: flatScore,
        waterDistance: waterDistM,
        waterScore: wScore,
        overallScore: overall,
      );
      if (best == null || overall > best.overallScore) best = score;
    }
    return best;
  }

  /// Query Overpass for the nearest water body within 2 km.
  static Future<double> _nearestWaterDistance(LatLng loc) async {
    const radius = 2000;
    final query =
        '[out:json][timeout:10];(node["natural"="spring"](around:$radius,${loc.latitude},${loc.longitude});'
        'node["amenity"="drinking_water"](around:$radius,${loc.latitude},${loc.longitude});'
        'way["natural"="water"](around:$radius,${loc.latitude},${loc.longitude});'
        'way["waterway"](around:$radius,${loc.latitude},${loc.longitude}););out center 5;';
    try {
      final resp = await http
          .post(
            Uri.parse('https://overpass-api.de/api/interpreter'),
            body: query,
          )
          .timeout(const Duration(seconds: 12));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final elements = data['elements'] as List;
        if (elements.isEmpty) return 1200;
        double nearest = double.infinity;
        for (final el in elements) {
          final lat = (el['lat'] ?? el['center']?['lat']) as double?;
          final lon = (el['lon'] ?? el['center']?['lon']) as double?;
          if (lat == null || lon == null) continue;
          final d = calculateDistance(loc, LatLng(lat, lon));
          if (d < nearest) nearest = d;
        }
        return nearest == double.infinity ? 1200 : nearest;
      }
    } catch (e) {
      debugPrint('Overpass water query failed: $e');
    }
    return 800;
  }

  static double _flatnessScore(double gradientPct) {
    if (gradientPct <= 1.0) return 100.0;
    if (gradientPct >= 30.0) return 0.0;
    return 100.0 - ((gradientPct - 1.0) / 29.0) * 100.0;
  }

  static double _waterScore(double distanceM) {
    if (distanceM < 20 || distanceM > 1000) return 0.0;
    if (distanceM >= 50 && distanceM <= 200) return 100.0;
    if (distanceM < 50) return ((distanceM - 20) / 30) * 100;
    return ((1000 - distanceM) / 800) * 100;
  }

  static LatLng _dest(LatLng start, double distM, double bearingRad) {
    const R = 6371000.0;
    final lat1 = _toRadians(start.latitude);
    final lon1 = _toRadians(start.longitude);
    final d = distM / R;
    final lat2 = math.asin(
        math.sin(lat1) * math.cos(d) +
        math.cos(lat1) * math.sin(d) * math.cos(bearingRad));
    final lon2 = lon1 + math.atan2(
        math.sin(bearingRad) * math.sin(d) * math.cos(lat1),
        math.cos(d) - math.sin(lat1) * math.sin(lat2));
    return LatLng(_toDegrees(lat2), _toDegrees(lon2));
  }

  static double _toRadians(double deg) => deg * math.pi / 180;
  static double _toDegrees(double rad) => rad * 180 / math.pi;
}

class CampSiteScore {
  final LatLng location;
  final double flatness;
  final double flatnessScore;
  final double waterDistance;
  final double waterScore;
  final double overallScore;

  CampSiteScore({
    required this.location,
    required this.flatness,
    required this.flatnessScore,
    required this.waterDistance,
    required this.waterScore,
    required this.overallScore,
  });
}
