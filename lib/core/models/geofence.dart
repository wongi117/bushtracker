class Geofence {
  final int? id;
  final String name;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final bool isActive;
  final DateTime createdAt;

  const Geofence({
    this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.isActive,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'radius_meters': radiusMeters,
        'is_active': isActive ? 1 : 0,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory Geofence.fromMap(Map<String, dynamic> map) => Geofence(
        id: map['id'] as int?,
        name: map['name'] as String? ?? '',
        latitude: (map['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (map['longitude'] as num?)?.toDouble() ?? 0,
        radiusMeters: (map['radius_meters'] as num?)?.toDouble() ?? 200,
        isActive: (map['is_active'] as int? ?? 1) == 1,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            map['created_at'] as int? ?? 0),
      );

  Geofence copyWith({
    int? id,
    String? name,
    double? latitude,
    double? longitude,
    double? radiusMeters,
    bool? isActive,
    DateTime? createdAt,
  }) =>
      Geofence(
        id: id ?? this.id,
        name: name ?? this.name,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        radiusMeters: radiusMeters ?? this.radiusMeters,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt ?? this.createdAt,
      );
}
