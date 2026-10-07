import 'dart:convert';

import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

import 'package:bush_track/features/drawing/services/line_geometry.dart';

enum DrawingKind {
  /// Tapped vertex by vertex, with a length and bearing on every leg.
  line,

  /// Drawn with a finger and simplified to a tolerance in metres.
  freehand,
}

/// A line drawn on the map: a fence to check, a track not yet driven, the edge
/// of a burn.
///
/// Stored as geographic coordinates, never screen positions, so it lands on
/// the same ground at any zoom and any rotation.
class Drawing {
  final int? id;

  /// Set when the drawing is made, not backfilled later: it is what a shared
  /// copy will be matched on once there is a server.
  final String uuid;

  /// The project, or null for Unsorted. Never [FieldFile.unsortedId] -- see
  /// CLAUDE.md: Unsorted is a view over NULL, and -1 would file the drawing
  /// under a project that does not exist, hiding it everywhere.
  final int? fileId;

  final DrawingKind kind;
  final String? name;
  final String? notes;

  /// Hex, as the pin palette uses.
  final String colour;

  /// Stroke width in logical pixels.
  final double width;

  final List<LatLng> points;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// A tombstone rather than a delete, so the deletion can travel once there
  /// is anywhere for it to travel to.
  final DateTime? deletedAt;

  Drawing({
    this.id,
    String? uuid,
    this.fileId,
    required this.kind,
    this.name,
    this.notes,
    this.colour = '#FF6B00',
    this.width = 4,
    required List<LatLng> points,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.deletedAt,
  })  : uuid = uuid ?? const Uuid().v4(),
        points = List.unmodifiable(points),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? createdAt ?? DateTime.now();

  double get lengthMetres => LineMeasure.totalMetres(points);

  bool get isDeleted => deletedAt != null;

  Drawing copyWith({
    int? id,
    int? fileId,
    bool clearFile = false,
    String? name,
    String? notes,
    String? colour,
    double? width,
    List<LatLng>? points,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) =>
      Drawing(
        id: id ?? this.id,
        uuid: uuid,
        fileId: clearFile ? null : (fileId ?? this.fileId),
        kind: kind,
        name: name ?? this.name,
        notes: notes ?? this.notes,
        colour: colour ?? this.colour,
        width: width ?? this.width,
        points: points ?? this.points,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: deletedAt ?? this.deletedAt,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'uuid': uuid,
        'file_id': fileId,
        'kind': kind.name,
        'name': name,
        'notes': notes,
        'colour': colour,
        'width': width,
        'points': encodePoints(points),
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
        'deleted_at': deletedAt?.millisecondsSinceEpoch,
      };

  factory Drawing.fromMap(Map<String, dynamic> m) {
    DateTime? at(Object? v) =>
        v is int ? DateTime.fromMillisecondsSinceEpoch(v) : null;
    return Drawing(
      id: m['id'] as int?,
      uuid: m['uuid'] as String?,
      fileId: m['file_id'] as int?,
      kind: DrawingKind.values.firstWhere((k) => k.name == m['kind'],
          orElse: () => DrawingKind.line),
      name: m['name'] as String?,
      notes: m['notes'] as String?,
      colour: (m['colour'] as String?) ?? '#FF6B00',
      width: (m['width'] as num?)?.toDouble() ?? 4,
      points: decodePoints(m['points']),
      createdAt: at(m['created_at']),
      updatedAt: at(m['updated_at']),
      deletedAt: at(m['deleted_at']),
    );
  }

  /// `[[lat, lon], ...]` -- latitude first, the way this app and everyone in
  /// it says a position.
  ///
  /// **Not GeoJSON order.** GeoJSON is `[lon, lat]`, and an export has to
  /// flip it (CLAUDE.md: backwards, a Leonora file opens off Somalia). Kept
  /// as the plan's schema states rather than borrowing GeoJSON's order, so
  /// nothing here can be mistaken for a GeoJSON fragment and passed through
  /// unflipped.
  static String encodePoints(List<LatLng> points) =>
      jsonEncode([for (final p in points) [p.latitude, p.longitude]]);

  /// Tolerant of a damaged column: what cannot be read is skipped, and an
  /// unreadable column is an empty line, rather than a throw that would take
  /// every other drawing down with it.
  static List<LatLng> decodePoints(Object? raw) {
    if (raw is! String || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      return [
        for (final p in list)
          if (p is List &&
              p.length >= 2 &&
              p[0] is num &&
              p[1] is num &&
              (p[0] as num).abs() <= 90 &&
              (p[1] as num).abs() <= 180)
            LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()),
      ];
    } catch (_) {
      return const [];
    }
  }
}
