import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class ElevationService {
  static const _batchUrl = 'https://api.open-elevation.com/api/v1/lookup';

  /// Fetch elevation for a single point. Returns null on failure.
  static Future<double?> getElevation(LatLng location) async {
    try {
      final resp = await http.get(
        Uri.parse('$_batchUrl?locations=${location.latitude},${location.longitude}'),
      ).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        return (data['results'][0]['elevation'] as num).toDouble();
      }
    } catch (e) {
      debugPrint('ElevationService single lookup failed: $e');
    }
    return null;
  }

  /// Fetch elevation profile for a route. Batches all points in one POST request.
  static Future<List<ElevationPoint>> getElevationProfile(List<LatLng> route) async {
    if (route.isEmpty) return [];

    // Downsample to max 100 points to keep the request fast
    final sampled = _downsample(route, 100);

    List<double?> elevations;
    try {
      elevations = await _batchLookup(sampled);
    } catch (_) {
      elevations = List.filled(sampled.length, null);
    }

    final profile = <ElevationPoint>[];
    double cumDist = 0;
    for (int i = 0; i < sampled.length; i++) {
      if (i > 0) {
        cumDist += _haversineM(sampled[i - 1], sampled[i]);
      }
      profile.add(ElevationPoint(
        point: sampled[i],
        elevation: elevations[i] ?? 0.0,
        distance: cumDist,
      ));
    }
    return profile;
  }

  static Future<List<double?>> _batchLookup(List<LatLng> points) async {
    final locations = points
        .map((p) => {'latitude': p.latitude, 'longitude': p.longitude})
        .toList();
    final resp = await http
        .post(
          Uri.parse(_batchUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'locations': locations}),
        )
        .timeout(const Duration(seconds: 15));

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      final results = data['results'] as List;
      return results
          .map((r) => (r['elevation'] as num?)?.toDouble())
          .toList();
    }
    throw Exception('Open-Elevation returned ${resp.statusCode}');
  }

  static List<LatLng> _downsample(List<LatLng> pts, int maxPoints) {
    if (pts.length <= maxPoints) return pts;
    final step = pts.length / maxPoints;
    return List.generate(maxPoints, (i) => pts[(i * step).floor()]);
  }

  static double _haversineM(LatLng a, LatLng b) {
    const r = 6371000.0;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLon = (b.longitude - a.longitude) * math.pi / 180;
    final s = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(a.latitude * math.pi / 180) *
            math.cos(b.latitude * math.pi / 180) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return r * 2 * math.atan2(math.sqrt(s), math.sqrt(1 - s));
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
