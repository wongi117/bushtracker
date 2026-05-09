import 'package:flutter/material.dart';
import 'package:isar/isar.dart';

part 'waypoint.g.dart';

@Collection()
class Waypoint {
  Id? id;

  double? latitude;
  double? longitude;
  double? altitude;
  double? accuracy;
  double? speed;
  String? label;
  String? notes;
  DateTime? timestamp;
  String? type;
  
  // Photo geotagging support
  List<String>? photoPaths; // List of photo file paths
  String? thumbnailPath; // Thumbnail for quick display
  
  // Pin customization
  String? color; // Hex color string (e.g., "#FF5722")
  String? icon; // Icon type: camp, water, hazard, fuel, road, custom
  int? order; // For trail numbering
  bool? isPin; // Whether this is a pinned waypoint (not just a track point)

  Waypoint({
    this.id,
    this.latitude,
    this.longitude,
    this.altitude,
    this.accuracy,
    this.speed,
    this.label,
    this.notes,
    this.timestamp,
    this.type,
    this.photoPaths,
    this.thumbnailPath,
    this.color,
    this.icon,
    this.order,
    this.isPin,
  });

  // Convert from database map (for backward compatibility)
  factory Waypoint.fromMap(Map<String, dynamic> map) {
    return Waypoint(
      id: map['id'],
      latitude: map['latitude']?.toDouble(),
      longitude: map['longitude']?.toDouble(),
      altitude: map['altitude']?.toDouble(),
      accuracy: map['accuracy']?.toDouble(),
      speed: map['speed']?.toDouble(),
      label: map['label'],
      notes: map['notes'],
      timestamp: map['timestamp'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['timestamp']) 
          : null,
      type: map['type'],
      photoPaths: map['photo_paths'] != null 
          ? List<String>.from(map['photo_paths'].split(','))
          : null,
      thumbnailPath: map['thumbnail_path'],
      color: map['color'],
      icon: map['icon'],
      order: map['order'],
      isPin: map['is_pin'] == 1,
    );
  }

  // Convert to database map (for backward compatibility)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'accuracy': accuracy,
      'speed': speed,
      'label': label,
      'notes': notes,
      'timestamp': timestamp?.millisecondsSinceEpoch,
      'type': type,
      'photo_paths': photoPaths?.join(','),
      'thumbnail_path': thumbnailPath,
      'color': color,
      'icon': icon,
      'order': order,
      'is_pin': isPin == true ? 1 : 0,
    };
  }

  /// Check if waypoint has photos
  bool get hasPhotos => photoPaths != null && photoPaths!.isNotEmpty;

  /// Get number of photos
  int get photoCount => photoPaths?.length ?? 0;
}

// Waypoint types
class WaypointType {
  static const String track = 'track';
  static const String manual = 'manual';
  static const String trail = 'trail';
}

// Waypoint icons
class WaypointIcon {
  static const String camp = 'camp';
  static const String water = 'water';
  static const String hazard = 'hazard';
  static const String fuel = 'fuel';
  static const String road = 'road';
  static const String custom = 'custom';
  static const String pin = 'pin';
  
  static IconData getIconData(String? iconType) {
    switch (iconType) {
      case camp:
        return Icons.local_fire_department;
      case water:
        return Icons.water_drop;
      case hazard:
        return Icons.warning;
      case fuel:
        return Icons.local_gas_station;
      case road:
        return Icons.add_road;
      case pin:
      default:
        return Icons.location_on;
    }
  }
}

// Predefined colors for waypoints and trails
class WaypointColors {
  // Electric Purple (default)
  static const String electricPurple = '#7B2FFF';
  // Neon Cyan
  static const String neonCyan = '#00E5FF';
  // Ember Orange
  static const String emberOrange = '#FF6B35';
  // Neon Green
  static const String neonGreen = '#00FF88';
  // Danger Red
  static const String dangerRed = '#FF2D55';
  // White
  static const String white = '#FFFFFF';
  
  static Color fromHex(String? hex) {
    if (hex == null || hex.isEmpty) return const Color(0xFFFF5722);
    try {
      final buffer = StringBuffer();
      if (hex.length == 6 || hex.length == 7) buffer.write('ff');
      buffer.write(hex.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (e) {
      return const Color(0xFFFF5722);
    }
  }
  
  static const List<String> allColors = [
    electricPurple,
    neonCyan,
    emberOrange,
    neonGreen,
    dangerRed,
    white,
  ];
}
