import 'dart:math' show atan2, cos, sin, sqrt;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:flutter/material.dart';
import 'package:bush_track/core/config/api_config.dart';

class PlacesService {
  // In a real implementation, this would fetch from OSM Overpass API
  // For now, we'll return mock data for demonstration
  static Future<List<Place>> searchPlaces(String query, {LatLng? proximity}) async {
    final key = ApiConfig.mapboxToken;
    if (key.isEmpty) {
      return getNearbyPlaces(proximity ?? const LatLng(-25.3444, 131.0369));
    }

    final proximityPart = proximity == null ? '' : '&proximity=${proximity.longitude},${proximity.latitude}';
    final url = Uri.parse(
      'https://api.mapbox.com/geocoding/v5/mapbox.places/${Uri.encodeComponent(query)}.json?country=AU&limit=10$proximityPart&access_token=$key',
    );

    final response = await http.get(url);
    if (response.statusCode != 200) {
      return getNearbyPlaces(proximity ?? const LatLng(-25.3444, 131.0369));
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final features = (data['features'] as List<dynamic>? ?? const []);

    return features.map((feature) {
      final props = feature as Map<String, dynamic>;
      final center = (props['center'] as List<dynamic>? ?? const [131.0369, -25.3444]);
      final context = (props['place_type'] as List<dynamic>? ?? const ['place']).first.toString();
      return Place(
        id: props['id']?.toString() ?? props['place_name']?.toString() ?? query,
        name: props['place_name']?.toString() ?? query,
        location: LatLng((center[1] as num).toDouble(), (center[0] as num).toDouble()),
        category: _categoryFromMapboxType(context),
        distance: proximity == null
            ? 0
            : _distanceBetween(proximity, LatLng((center[1] as num).toDouble(), (center[0] as num).toDouble())),
        openingHours: 'Mapbox geocoded',
      );
    }).toList();
  }
  
  static Future<List<Place>> getNearbyPlaces(LatLng location, {double radius = 50000}) async {
    // Mock places data for demonstration
    await Future.delayed(const Duration(milliseconds: 500)); // Simulate network delay
    
    return [
      Place(
        id: '1',
        name: 'Leonora BP',
        location: const LatLng(-25.3400, 131.0400),
        category: PlaceCategory.fuel,
        distance: 34000, // 34km
        openingHours: 'Open until 6pm',
      ),
      Place(
        id: '2',
        name: 'Menzies Hotel',
        location: const LatLng(-25.3300, 131.0500),
        category: PlaceCategory.pub,
        distance: 45000, // 45km
        openingHours: 'Open 24 hours',
      ),
      Place(
        id: '3',
        name: 'Medical Clinic',
        location: const LatLng(-25.3200, 131.0600),
        category: PlaceCategory.medical,
        distance: 56000, // 56km
        openingHours: 'Open 9am-5pm',
      ),
      Place(
        id: '4',
        name: 'Water Tank',
        location: const LatLng(-25.3100, 131.0700),
        category: PlaceCategory.water,
        distance: 67000, // 67km
        openingHours: 'Always available',
      ),
      Place(
        id: '5',
        name: 'Camping Area',
        location: const LatLng(-25.3000, 131.0800),
        category: PlaceCategory.camp,
        distance: 78000, // 78km
        openingHours: 'Free camping',
      ),
    ];
  }

  static PlaceCategory _categoryFromMapboxType(String type) {
    switch (type) {
      case 'poi':
      case 'place':
        return PlaceCategory.camp;
      case 'address':
        return PlaceCategory.mechanic;
      default:
        return PlaceCategory.camp;
    }
  }

  static double _distanceBetween(LatLng a, LatLng b) {
    const r = 6371000.0;
    final dLat = _toRadians(b.latitude - a.latitude);
    final dLon = _toRadians(b.longitude - a.longitude);
    final la1 = _toRadians(a.latitude);
    final la2 = _toRadians(b.latitude);
    final h = (sin(dLat / 2) * sin(dLat / 2)) + cos(la1) * cos(la2) * (sin(dLon / 2) * sin(dLon / 2));
    return 2 * r * atan2(sqrt(h), sqrt(1 - h));
  }

  static double _toRadians(double degrees) => degrees * (3.141592653589793 / 180);
}

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

enum PlaceCategory {
  fuel,
  pub,
  medical,
  water,
  camp,
  mechanic,
}

extension PlaceCategoryExtension on PlaceCategory {
  String get displayName {
    switch (this) {
      case PlaceCategory.fuel:
        return 'Fuel';
      case PlaceCategory.pub:
        return 'Pub';
      case PlaceCategory.medical:
        return 'Medical';
      case PlaceCategory.water:
        return 'Water';
      case PlaceCategory.camp:
        return 'Camp';
      case PlaceCategory.mechanic:
        return 'Mechanic';
    }
  }
  
  IconData get icon {
    switch (this) {
      case PlaceCategory.fuel:
        return Icons.local_gas_station;
      case PlaceCategory.pub:
        return Icons.local_bar;
      case PlaceCategory.medical:
        return Icons.local_hospital;
      case PlaceCategory.water:
        return Icons.water_drop;
      case PlaceCategory.camp:
        return Icons.outdoor_grill;
      case PlaceCategory.mechanic:
        return Icons.build;
    }
  }
  
  Color get color {
    switch (this) {
      case PlaceCategory.fuel:
        return Colors.green;
      case PlaceCategory.pub:
        return Colors.purple;
      case PlaceCategory.medical:
        return Colors.red;
      case PlaceCategory.water:
        return Colors.blue;
      case PlaceCategory.camp:
        return Colors.brown;
      case PlaceCategory.mechanic:
        return Colors.orange;
    }
  }
}
