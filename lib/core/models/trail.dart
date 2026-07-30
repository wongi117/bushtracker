import 'package:isar/isar.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';

part 'trail.g.dart';

@Collection()
class Trail {
  Id? id;

  String? name;
  String? description;
  DateTime? createdAt;
  DateTime? updatedAt;
  double? totalDistance;
  double? totalElevation;
  int? durationSeconds;
  String? difficulty;
  bool? isSaved;
  
  // Trail waypoints as JSON string or separate relation
  String? waypointsJson;
  
  // Trail styling
  String? color; // Hex color for trail line
  String? lineStyle; // solid, dashed, dotted
  bool? showDirection; // Show arrows along the trail
  bool? isActive; // Currently being followed

  Trail({
    this.id,
    this.name,
    this.description,
    this.createdAt,
    this.updatedAt,
    this.totalDistance,
    this.totalElevation,
    this.durationSeconds,
    this.difficulty,
    this.isSaved,
    this.waypointsJson,
    this.color,
    this.lineStyle,
    this.showDirection,
    this.isActive,
  });

  /// Get trail waypoints as list of LatLng
  List<LatLng> getWaypoints() {
    if (waypointsJson == null || waypointsJson!.isEmpty) return [];
    try {
      final List<dynamic> decoded = jsonDecode(waypointsJson!);
      return decoded
          .map((w) => LatLng(w['lat'] as double, w['lon'] as double))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Set trail waypoints from list of LatLng
  void setWaypoints(List<LatLng> waypoints) {
    waypointsJson = jsonEncode(
      waypoints.map((w) => {'lat': w.latitude, 'lon': w.longitude}).toList(),
    );
  }

  /// Convert from database map
  factory Trail.fromMap(Map<String, dynamic> map) {
    return Trail(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      createdAt: map['created_at'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['created_at']) 
          : null,
      updatedAt: map['updated_at'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['updated_at']) 
          : null,
      totalDistance: map['total_distance']?.toDouble(),
      totalElevation: map['total_elevation']?.toDouble(),
      durationSeconds: map['duration_seconds'],
      difficulty: map['difficulty'],
      isSaved: map['is_saved'] == 1,
      waypointsJson: map['waypoints_json'],
      color: map['color'] ?? '#7B2FFF',
      lineStyle: map['line_style'] ?? 'solid',
      showDirection: map['show_direction'] == 1,
      isActive: map['is_active'] == 1,
    );
  }

  /// Convert to database map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'created_at': createdAt?.millisecondsSinceEpoch,
      'updated_at': updatedAt?.millisecondsSinceEpoch,
      'total_distance': totalDistance,
      'total_elevation': totalElevation,
      'duration_seconds': durationSeconds,
      'difficulty': difficulty,
      'is_saved': isSaved == true ? 1 : 0,
      'waypoints_json': waypointsJson,
      'color': color,
      'line_style': lineStyle,
      'show_direction': showDirection == true ? 1 : 0,
      'is_active': isActive == true ? 1 : 0,
    };
  }

  /// Get trail color with default
  String getTrailColor() {
    return color ?? '#7B2FFF';
  }

  /// Get line style with default
  String getLineStyle() {
    return lineStyle ?? 'solid';
  }
}

/// Trail line styles
class TrailLineStyle {
  static const String solid = 'solid';
  static const String dashed = 'dashed';
  static const String dotted = 'dotted';
  
  static List<double>? getPattern(String? style) {
    switch (style) {
      case dashed:
        return [15.0, 10.0];
      case dotted:
        return [5.0, 5.0];
      case solid:
      default:
        return null;
    }
  }
}

/// Predefined trail colors
class TrailColors {
  static const String electricPurple = '#7B2FFF';
  static const String neonCyan = '#00E5FF';
  static const String emberOrange = '#FF6B35';
  static const String neonGreen = '#00FF88';
  static const String dangerRed = '#FF2D55';
  static const String white = '#FFFFFF';
  
  static const List<String> allColors = [
    electricPurple,
    neonCyan,
    emberOrange,
    neonGreen,
    dangerRed,
    white,
  ];
  
  static const List<String> colorNames = [
    'Electric Purple',
    'Neon Cyan',
    'Ember Orange',
    'Neon Green',
    'Danger Red',
    'White',
  ];
}
