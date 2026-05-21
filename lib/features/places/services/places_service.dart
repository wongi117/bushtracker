import 'dart:math' show atan2, cos, sin, sqrt;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:flutter/material.dart';

class PlacesService {
  // Routes through Vercel serverless proxies to avoid CORS on Flutter Web.
  static const _nominatimProxy = '/api/nominatim';
  static const _overpassProxy  = '/api/overpass';
  static const _headers = <String, String>{};

  /// Global text search via Nominatim — works for any town, city, landmark.
  static Future<List<Place>> searchPlaces(String query, {LatLng? proximity}) async {
    try {
      final params = <String, String>{
        'q': query,
      };
      if (proximity != null) {
        params['lat'] = proximity.latitude.toString();
        params['lon'] = proximity.longitude.toString();
      }
      final url = Uri.parse(_nominatimProxy).replace(queryParameters: params);
      final response = await http.get(url, headers: _headers)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body) as List;
      return data.map((item) {
        final lat = double.tryParse(item['lat']?.toString() ?? '') ?? 0.0;
        final lon = double.tryParse(item['lon']?.toString() ?? '') ?? 0.0;
        final loc  = LatLng(lat, lon);
        final full = item['display_name']?.toString() ?? '';
        final type = item['type']?.toString() ?? '';
        final cls  = item['class']?.toString() ?? '';
        final addr = item['address'] as Map? ?? {};
        final country = addr['country']?.toString() ?? '';
        final state   = addr['state']?.toString() ?? addr['region']?.toString() ?? '';
        final subtitle = [state, country].where((s) => s.isNotEmpty).join(', ');
        return Place(
          id: item['place_id']?.toString() ?? full,
          name: _shortName(full),
          location: loc,
          category: _categoryFromOsmType(type, cls),
          distance: proximity != null ? _distanceBetween(proximity, loc) : 0,
          openingHours: subtitle.isEmpty ? full.split(',').skip(1).take(2).join(', ') : subtitle,
        );
      }).toList();
    } catch (e) {
      debugPrint('Nominatim search error: $e');
      return [];
    }
  }

  /// Nearby POI search via OpenStreetMap Overpass — real data, any location.
  static Future<List<Place>> getNearbyPlaces(LatLng location,
      {double radius = 50000}) async {
    try {
      final lat = location.latitude;
      final lon = location.longitude;
      final r   = radius.toInt();

      final query = '[out:json][timeout:20];('
          'node["amenity"="fuel"](around:$r,$lat,$lon);'
          'node["amenity"="hospital"](around:$r,$lat,$lon);'
          'node["amenity"="clinic"](around:$r,$lat,$lon);'
          'node["amenity"="pharmacy"](around:$r,$lat,$lon);'
          'node["amenity"="pub"](around:$r,$lat,$lon);'
          'node["amenity"="bar"](around:$r,$lat,$lon);'
          'node["amenity"="restaurant"](around:$r,$lat,$lon);'
          'node["tourism"="camp_site"](around:$r,$lat,$lon);'
          'node["tourism"="caravan_site"](around:$r,$lat,$lon);'
          'node["natural"="spring"](around:$r,$lat,$lon);'
          'node["amenity"="water_point"](around:$r,$lat,$lon);'
          'node["amenity"="drinking_water"](around:$r,$lat,$lon);'
          'node["shop"="car_repair"](around:$r,$lat,$lon);'
          'node["amenity"="car_repair"](around:$r,$lat,$lon);'
          ');out body 30;';

      final response = await http
          .post(Uri.parse(_overpassProxy), body: query, headers: _headers)
          .timeout(const Duration(seconds: 25));

      if (response.statusCode != 200) return [];

      final data     = jsonDecode(response.body) as Map<String, dynamic>;
      final elements = (data['elements'] as List? ?? []);

      final places = <Place>[];
      for (final el in elements) {
        final tags   = (el['tags'] as Map?) ?? {};
        final name   = tags['name']?.toString() ?? '';
        if (name.isEmpty) continue;

        final elLat  = (el['lat'] as num?)?.toDouble() ?? lat;
        final elLon  = (el['lon'] as num?)?.toDouble() ?? lon;
        final loc    = LatLng(elLat, elLon);
        final amenity = tags['amenity']?.toString() ?? '';
        final tourism = tags['tourism']?.toString() ?? '';
        final hours   = tags['opening_hours']?.toString() ?? '';
        final phone   = tags['phone']?.toString() ?? '';
        final subtitle = hours.isNotEmpty ? hours : (phone.isNotEmpty ? phone : '');

        places.add(Place(
          id: el['id']?.toString() ?? name,
          name: name,
          location: loc,
          category: _categoryFromOsmAmenity(amenity, tourism, tags),
          distance: _distanceBetween(location, loc),
          openingHours: subtitle,
        ));
      }

      places.sort((a, b) => a.distance.compareTo(b.distance));
      return places;
    } catch (e) {
      debugPrint('Overpass error: $e');
      return [];
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  static String _shortName(String displayName) {
    final parts = displayName.split(',');
    return parts.first.trim();
  }

  static PlaceCategory _categoryFromOsmType(String type, String cls) {
    if (cls == 'amenity') {
      if (type == 'fuel' || type == 'gas_station') return PlaceCategory.fuel;
      if (type == 'hospital' || type == 'clinic' || type == 'pharmacy') return PlaceCategory.medical;
      if (type == 'pub' || type == 'bar' || type == 'restaurant' || type == 'fast_food') return PlaceCategory.pub;
      if (type == 'drinking_water' || type == 'water_point') return PlaceCategory.water;
      if (type == 'car_repair') return PlaceCategory.mechanic;
    }
    if (cls == 'tourism') {
      if (type == 'camp_site' || type == 'caravan_site') return PlaceCategory.camp;
    }
    if (cls == 'natural' && type == 'spring') return PlaceCategory.water;
    if (cls == 'place') return PlaceCategory.camp;
    return PlaceCategory.camp;
  }

  static PlaceCategory _categoryFromOsmAmenity(
      String amenity, String tourism, Map tags) {
    if (amenity == 'fuel') return PlaceCategory.fuel;
    if (amenity == 'hospital' || amenity == 'clinic' || amenity == 'pharmacy') {
      return PlaceCategory.medical;
    }
    if (amenity == 'pub' || amenity == 'bar' || amenity == 'restaurant' ||
        amenity == 'fast_food') return PlaceCategory.pub;
    if (amenity == 'drinking_water' || amenity == 'water_point') {
      return PlaceCategory.water;
    }
    if (amenity == 'car_repair' || tags['shop'] == 'car_repair') {
      return PlaceCategory.mechanic;
    }
    if (tourism == 'camp_site' || tourism == 'caravan_site') {
      return PlaceCategory.camp;
    }
    if (tags['natural'] == 'spring') { return PlaceCategory.water; }
    return PlaceCategory.camp;
  }

  static double _distanceBetween(LatLng a, LatLng b) {
    const r   = 6371000.0;
    final dLat = _toRad(b.latitude - a.latitude);
    final dLon = _toRad(b.longitude - a.longitude);
    final la1  = _toRad(a.latitude);
    final la2  = _toRad(b.latitude);
    final h = (sin(dLat / 2) * sin(dLat / 2)) +
        cos(la1) * cos(la2) * (sin(dLon / 2) * sin(dLon / 2));
    return 2 * r * atan2(sqrt(h), sqrt(1 - h));
  }

  static double _toRad(double deg) => deg * (3.141592653589793 / 180);
}

// ─────────────────────────────────────────────────────────────────────────────

class Place {
  final String id;
  final String name;
  final LatLng location;
  final PlaceCategory category;
  final double distance;
  final String openingHours;

  Place({
    required this.id,
    required this.name,
    required this.location,
    required this.category,
    required this.distance,
    required this.openingHours,
  });
}

enum PlaceCategory { fuel, pub, medical, water, camp, mechanic }

extension PlaceCategoryExtension on PlaceCategory {
  String get displayName => switch (this) {
        PlaceCategory.fuel     => 'Fuel',
        PlaceCategory.pub      => 'Food & Drink',
        PlaceCategory.medical  => 'Medical',
        PlaceCategory.water    => 'Water',
        PlaceCategory.camp     => 'Camp',
        PlaceCategory.mechanic => 'Mechanic',
      };

  IconData get icon => switch (this) {
        PlaceCategory.fuel     => Icons.local_gas_station,
        PlaceCategory.pub      => Icons.local_bar,
        PlaceCategory.medical  => Icons.local_hospital,
        PlaceCategory.water    => Icons.water_drop,
        PlaceCategory.camp     => Icons.outdoor_grill,
        PlaceCategory.mechanic => Icons.build,
      };

  Color get color => switch (this) {
        PlaceCategory.fuel     => Colors.green,
        PlaceCategory.pub      => Colors.purple,
        PlaceCategory.medical  => Colors.red,
        PlaceCategory.water    => Colors.blue,
        PlaceCategory.camp     => const Color(0xFF8D6E63),
        PlaceCategory.mechanic => Colors.orange,
      };
}
