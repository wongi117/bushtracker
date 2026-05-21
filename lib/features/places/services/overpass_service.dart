import 'dart:convert';
import 'dart:math' show atan2, cos, sin, sqrt, pi;
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class OverpassPlace {
  final String name;
  final double lat;
  final double lon;
  final String type;
  final String subtype;
  final double distanceM;
  final double bearingDeg;

  OverpassPlace({
    required this.name,
    required this.lat,
    required this.lon,
    required this.type,
    required this.subtype,
    required this.distanceM,
    required this.bearingDeg,
  });

  String get distanceLabel {
    if (distanceM < 1000) return '${distanceM.round()}m';
    return '${(distanceM / 1000).toStringAsFixed(1)}km';
  }

  String get bearingLabel {
    const dirs = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    return dirs[((bearingDeg + 22.5) / 45).floor() % 8];
  }

  String get displayName {
    if (name.isNotEmpty) return name;
    return subtype.replaceAll('_', ' ');
  }

  String get categoryLabel {
    switch (type) {
      case 'shop':
        return subtype.replaceAll('_', ' ');
      case 'amenity':
        return subtype.replaceAll('_', ' ');
      case 'place':
        return subtype; // village, town, city, hamlet
      case 'building':
        return 'building';
      default:
        return type;
    }
  }

  Map<String, dynamic> toMap() => {
        'name': displayName,
        'lat': lat,
        'lon': lon,
        'type': type,
        'subtype': subtype,
        'distanceM': distanceM,
        'bearingDeg': bearingDeg,
        'distanceLabel': distanceLabel,
        'bearingLabel': bearingLabel,
        'categoryLabel': categoryLabel,
      };
}

enum OverpassSearchType { shops, settlements, amenities, fuel, medical, water, allNearby }

class OverpassService {
  // Primary and fallback mirrors — all support CORS
  static const _mirrors = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
    'https://overpass.openstreetmap.fr/api/interpreter',
  ];

  static Future<List<OverpassPlace>> findNearby({
    required double lat,
    required double lon,
    double radiusM = 10000,
    OverpassSearchType searchType = OverpassSearchType.allNearby,
  }) async {
    if (lat == 0 && lon == 0) return [];

    final query = _buildQuery(lat, lon, radiusM, searchType);

    for (final mirror in _mirrors) {
      try {
        final response = await http
            .post(
              Uri.parse(mirror),
              headers: {'Content-Type': 'application/x-www-form-urlencoded'},
              body: 'data=${Uri.encodeComponent(query)}',
            )
            .timeout(const Duration(seconds: 20));

        if (response.statusCode == 200) {
          return _parse(response.body, lat, lon);
        }
        debugPrint('Overpass mirror $mirror returned ${response.statusCode}');
      } catch (e) {
        debugPrint('Overpass mirror $mirror failed: $e');
      }
    }
    return [];
  }

  static String _buildQuery(
      double lat, double lon, double radiusM, OverpassSearchType type) {
    final r = radiusM.round();
    final settleR = (radiusM * 8).round(); // settlements need wider radius

    switch (type) {
      case OverpassSearchType.shops:
        return '[out:json][timeout:15];'
            '(node["shop"](around:$r,$lat,$lon);'
            'way["shop"](around:$r,$lat,$lon););'
            'out body center 20;';

      case OverpassSearchType.settlements:
        return '[out:json][timeout:15];'
            '(node["place"~"village|town|city|hamlet|suburb"](around:$settleR,$lat,$lon);'
            'node["amenity"~"fuel|hospital|clinic"](around:$r,$lat,$lon);'
            'node["shop"](around:$r,$lat,$lon););'
            'out body center 20;';

      case OverpassSearchType.fuel:
        return '[out:json][timeout:15];'
            '(node["amenity"="fuel"](around:$settleR,$lat,$lon);'
            'way["amenity"="fuel"](around:$settleR,$lat,$lon););'
            'out body center 10;';

      case OverpassSearchType.medical:
        return '[out:json][timeout:15];'
            '(node["amenity"~"hospital|clinic|doctors|pharmacy"](around:$settleR,$lat,$lon);'
            'way["amenity"~"hospital|clinic|doctors|pharmacy"](around:$settleR,$lat,$lon););'
            'out body center 10;';

      case OverpassSearchType.water:
        return '[out:json][timeout:15];'
            '(node["amenity"="drinking_water"](around:$r,$lat,$lon);'
            'node["natural"~"spring|water"](around:$r,$lat,$lon);'
            'node["man_made"="water_well"](around:$r,$lat,$lon););'
            'out body center 10;';

      case OverpassSearchType.amenities:
        return '[out:json][timeout:15];'
            '(node["amenity"](around:$r,$lat,$lon);'
            'way["amenity"](around:$r,$lat,$lon););'
            'out body center 20;';

      case OverpassSearchType.allNearby:
        return '[out:json][timeout:20];'
            '(node["shop"](around:$r,$lat,$lon);'
            'way["shop"](around:$r,$lat,$lon);'
            'node["amenity"](around:$r,$lat,$lon);'
            'way["amenity"](around:$r,$lat,$lon);'
            'node["place"~"village|town|city|hamlet"](around:$settleR,$lat,$lon););'
            'out body center 30;';
    }
  }

  static List<OverpassPlace> _parse(String body, double fromLat, double fromLon) {
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      final elements = (data['elements'] as List<dynamic>? ?? []);

      final places = <OverpassPlace>[];
      for (final el in elements) {
        final m = el as Map<String, dynamic>;
        final tags = (m['tags'] as Map<String, dynamic>?) ?? {};

        double? elLat, elLon;
        if (m['type'] == 'node') {
          elLat = (m['lat'] as num?)?.toDouble();
          elLon = (m['lon'] as num?)?.toDouble();
        } else {
          final center = m['center'] as Map<String, dynamic>?;
          elLat = (center?['lat'] as num?)?.toDouble();
          elLon = (center?['lon'] as num?)?.toDouble();
        }
        if (elLat == null || elLon == null) continue;

        final name = tags['name']?.toString() ??
            tags['brand']?.toString() ??
            tags['operator']?.toString() ??
            '';

        String type = 'place', subtype = 'unknown';
        if (tags.containsKey('shop')) {
          type = 'shop';
          subtype = tags['shop']!.toString();
        } else if (tags.containsKey('amenity')) {
          type = 'amenity';
          subtype = tags['amenity']!.toString();
        } else if (tags.containsKey('place')) {
          type = 'place';
          subtype = tags['place']!.toString();
        } else if (tags.containsKey('building')) {
          type = 'building';
          subtype = tags['building']!.toString();
        } else if (tags.containsKey('natural')) {
          type = 'natural';
          subtype = tags['natural']!.toString();
        } else if (tags.containsKey('man_made')) {
          type = 'man_made';
          subtype = tags['man_made']!.toString();
        }

        // Skip unnamed non-settlement nodes with generic tags
        if (name.isEmpty && type == 'building') continue;

        places.add(OverpassPlace(
          name: name,
          lat: elLat,
          lon: elLon,
          type: type,
          subtype: subtype,
          distanceM: _haversineM(fromLat, fromLon, elLat, elLon),
          bearingDeg: _bearing(fromLat, fromLon, elLat, elLon),
        ));
      }

      places.sort((a, b) => a.distanceM.compareTo(b.distanceM));

      // Deduplicate by display name
      final seen = <String>{};
      return places.where((p) {
        final key = '${p.displayName.toLowerCase()}_${p.subtype}';
        return seen.add(key);
      }).take(15).toList();
    } catch (e) {
      debugPrint('Overpass parse error: $e');
      return [];
    }
  }

  static double _haversineM(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(lat1)) * cos(_rad(lat2)) * (sin(dLon / 2) * sin(dLon / 2));
    return 2 * r * atan2(sqrt(a), sqrt(1 - a));
  }

  static double _bearing(double lat1, double lon1, double lat2, double lon2) {
    final dLon = _rad(lon2 - lon1);
    final y = sin(dLon) * cos(_rad(lat2));
    final x = cos(_rad(lat1)) * sin(_rad(lat2)) -
        sin(_rad(lat1)) * cos(_rad(lat2)) * cos(dLon);
    return (atan2(y, x) * 180 / pi + 360) % 360;
  }

  static double _rad(double deg) => deg * pi / 180;
}
