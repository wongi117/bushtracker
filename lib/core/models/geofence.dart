import 'dart:convert';
import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import 'package:bush_track/core/utils/geo_geometry.dart';

/// What a zone is for. A ranger flagging a heritage site and a geologist
/// marking an open pit want the same tool but need to tell them apart on the
/// map at a glance, so the category carries the colour.
enum ZoneCategory {
  heritage('heritage', 'Heritage', 0xFFAB47BC),
  hazard('hazard', 'Hazard', 0xFFEF5350),
  exclusion('exclusion', 'No entry', 0xFFFF6B00),
  work('work', 'Work area', 0xFF42A5F5),
  water('water', 'Water', 0xFF26C6DA),
  camp('camp', 'Camp', 0xFF00E676),
  survey('survey', 'Survey', 0xFFFFEB3B);

  const ZoneCategory(this.id, this.label, this.colorValue);

  final String id;
  final String label;
  final int colorValue;

  static ZoneCategory fromId(String? id) => ZoneCategory.values.firstWhere(
        (c) => c.id == id,
        orElse: () => ZoneCategory.exclusion,
      );
}

/// A circle is enough for "stay 200 m clear of this bore". A boundary that
/// follows a creek, a lease edge or the actual extent of a site is not a
/// circle, so a zone can also be a polygon of hand-placed corners.
enum ZoneShape { circle, polygon }

/// A saved area on the map: a circle or a drawn boundary, with entry and exit
/// alerts. Still called Geofence internally because the alerting code, the
/// database table and the AI monitor all refer to it by that name; it is
/// presented as a "zone" everywhere the user sees it.
class Geofence {
  final int? id;
  final String name;

  /// For a circle, its centre. For a polygon, the centroid of [points] — kept
  /// so a zone can be sorted by distance and flown to without having to
  /// re-derive the centre every time.
  final double latitude;
  final double longitude;

  /// Only meaningful for a circle.
  final double radiusMeters;

  final bool isActive;
  final DateTime createdAt;

  final ZoneShape shape;

  /// The corners of a drawn boundary, in order. Empty for a circle.
  final List<LatLng> points;

  final ZoneCategory category;

  /// Free text — what was seen, who to call, why it is flagged.
  final String? notes;

  /// The field file this was flagged under, if one was open at the time.
  final int? fileId;

  const Geofence({
    this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.isActive,
    required this.createdAt,
    this.shape = ZoneShape.circle,
    this.points = const [],
    this.category = ZoneCategory.exclusion,
    this.notes,
    this.fileId,
  });

  /// A boundary drawn by hand. The centre and a nominal radius are derived so
  /// the rest of the app can treat every zone the same way.
  factory Geofence.polygon({
    int? id,
    required String name,
    required List<LatLng> points,
    required bool isActive,
    required DateTime createdAt,
    ZoneCategory category = ZoneCategory.exclusion,
    String? notes,
    int? fileId,
  }) {
    final centre = polygonCentroid(points);
    // Distance from the centre to the furthest corner: a usable stand-in
    // wherever something only understands circles, such as sorting a list.
    const distance = Distance();
    final reach = points.isEmpty
        ? 0.0
        : points.map((p) => distance(centre, p)).reduce(math.max);
    return Geofence(
      id: id,
      name: name,
      latitude: centre.latitude,
      longitude: centre.longitude,
      radiusMeters: reach,
      isActive: isActive,
      createdAt: createdAt,
      shape: ZoneShape.polygon,
      points: points,
      category: category,
      notes: notes,
      fileId: fileId,
    );
  }

  bool get isPolygon => shape == ZoneShape.polygon && points.length >= 3;

  LatLng get centre => LatLng(latitude, longitude);

  /// Ground covered, in square metres.
  double get areaSqMetres => isPolygon
      ? polygonAreaSqMetres(points)
      : math.pi * radiusMeters * radiusMeters;

  /// Whether a position is inside this zone, whatever shape it is.
  bool contains(LatLng position) {
    if (isPolygon) return isPointInPolygon(position, points);
    return const Distance()(centre, position) <= radiusMeters;
  }

  /// Distance to the boundary itself, for "you are approaching" warnings.
  /// Zero when the boundary is being stood on.
  double distanceToEdgeMetres(LatLng position) {
    if (isPolygon) return distanceToPolygonEdgeMetres(position, points);
    return (const Distance()(centre, position) - radiusMeters).abs();
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'radius_meters': radiusMeters,
        'is_active': isActive ? 1 : 0,
        'created_at': createdAt.millisecondsSinceEpoch,
        'shape': shape.name,
        'points_json': points.isEmpty
            ? null
            : jsonEncode(
                points.map((p) => [p.latitude, p.longitude]).toList()),
        'category': category.id,
        'notes': notes,
        'file_id': fileId,
      };

  factory Geofence.fromMap(Map<String, dynamic> map) {
    // Zones saved before boundaries existed have no shape column and are all
    // circles.
    final shape = (map['shape'] as String?) == 'polygon'
        ? ZoneShape.polygon
        : ZoneShape.circle;

    return Geofence(
      id: map['id'] as int?,
      name: map['name'] as String? ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0,
      radiusMeters: (map['radius_meters'] as num?)?.toDouble() ?? 200,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      createdAt:
          DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int? ?? 0),
      shape: shape,
      points: _pointsFromJson(map['points_json'] as String?),
      category: ZoneCategory.fromId(map['category'] as String?),
      notes: map['notes'] as String?,
      fileId: map['file_id'] as int?,
    );
  }

  /// Bad or truncated JSON must not take out the whole zone list, so a corner
  /// list that will not parse yields no corners and the zone falls back to
  /// being drawn as a circle.
  static List<LatLng> _pointsFromJson(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<List>()
          .where((p) => p.length >= 2 && p[0] is num && p[1] is num)
          .map((p) => LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Geofence copyWith({
    int? id,
    String? name,
    double? latitude,
    double? longitude,
    double? radiusMeters,
    bool? isActive,
    DateTime? createdAt,
    ZoneShape? shape,
    List<LatLng>? points,
    ZoneCategory? category,
    String? notes,
    int? fileId,
    // copyWith treats null as "leave alone", so taking a zone OUT of a file
    // needs to be said explicitly.
    bool clearFile = false,
  }) =>
      Geofence(
        id: id ?? this.id,
        name: name ?? this.name,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        radiusMeters: radiusMeters ?? this.radiusMeters,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt ?? this.createdAt,
        shape: shape ?? this.shape,
        points: points ?? this.points,
        category: category ?? this.category,
        notes: notes ?? this.notes,
        fileId: clearFile ? null : fileId ?? this.fileId,
      );
}
