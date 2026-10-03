import 'dart:convert';

import 'package:bush_track/core/models/geofence.dart';
import 'package:bush_track/core/models/trail.dart';
import 'package:bush_track/core/models/waypoint.dart';

/// Export formats offered for a project.
enum ExportFormat {
  /// Everything, with boundaries as real geometry. The one to use for anything
  /// that matters.
  geoJson,

  /// Waypoints and trails. GPX has no polygon type at all, so boundaries come
  /// out as single waypoints and the shape is lost.
  gpx,

  /// Waypoints, trails and boundaries, openable in Google Earth.
  kml;

  String get label => switch (this) {
        ExportFormat.geoJson => 'GeoJSON',
        ExportFormat.gpx => 'GPX',
        ExportFormat.kml => 'KML',
      };

  String get extension => switch (this) {
        ExportFormat.geoJson => 'geojson',
        ExportFormat.gpx => 'gpx',
        ExportFormat.kml => 'kml',
      };

  /// Said plainly in the picker, because choosing GPX for a heritage boundary
  /// and getting a single point back is a data loss that looks like a success.
  String get caveat => switch (this) {
        ExportFormat.geoJson => 'Pins, boundaries and trails, with shapes kept',
        ExportFormat.gpx => 'Pins and trails only -- boundaries lose their shape',
        ExportFormat.kml => 'Pins, boundaries and trails, for Google Earth',
      };

  /// Whether a boundary survives this format as an area rather than a point.
  bool get keepsZoneShape => this != ExportFormat.gpx;
}

/// Turns a project's contents into a file somebody else can open.
///
/// Boundaries are the reason this exists. GPXService already handled waypoints
/// and trails in GPX and KML, but zones were exportable in no format at all --
/// and on this app a zone is often a heritage or exclusion boundary, which is
/// the single most important thing to be able to hand to somebody.
class ProjectExport {
  /// GeoJSON FeatureCollection.
  ///
  /// Coordinates are `[longitude, latitude]`. That is the specification's
  /// order and the opposite of how every other part of this app and every
  /// human says it, so it is the standing mistake in anything that writes
  /// GeoJSON: get it backwards and the export lands off the coast of Somalia
  /// while still being a valid file that opens without complaint.
  static String geoJson({
    required String projectName,
    List<Waypoint> pins = const [],
    List<Geofence> zones = const [],
    List<Trail> trails = const [],
  }) {
    final features = <Map<String, dynamic>>[
      for (final p in pins)
        if (p.latitude != null && p.longitude != null)
          {
            'type': 'Feature',
            'geometry': {
              'type': 'Point',
              'coordinates': [p.longitude, p.latitude],
            },
            'properties': {
              'kind': 'pin',
              'name': p.label ?? 'Pin',
              if (p.notes != null && p.notes!.isNotEmpty) 'notes': p.notes,
              if (p.color != null) 'marker-color': p.color,
              if (p.icon != null) 'icon': p.icon,
              // Omitted rather than faked with the export time: a
              // recorded_at that is really when the file was written is
              // worse than no field at all.
              if (p.timestamp != null)
                'recorded_at': p.timestamp!.toUtc().toIso8601String(),
            },
          },
      for (final z in zones) _zoneFeature(z),
      for (final t in trails) ..._trailFeature(t),
    ];

    return const JsonEncoder.withIndent('  ').convert({
      'type': 'FeatureCollection',
      // Not part of the spec, but every tool passes unknown members through
      // and it is the only place to record which project a file came from.
      'name': projectName,
      'features': features,
    });
  }

  /// A zone as the closest thing GeoJSON has.
  ///
  /// A polygon zone is a Polygon. A circular one has no GeoJSON equivalent --
  /// there is no circle type -- so it becomes a Point carrying `radius_m`
  /// rather than being silently approximated into a many-sided polygon. A
  /// reader that understands the property gets the exact circle; one that does
  /// not at least gets the centre, instead of a shape nobody drew.
  static Map<String, dynamic> _zoneFeature(Geofence z) {
    final props = <String, dynamic>{
      'kind': 'zone',
      'name': z.name,
      'category': z.category.label,
      if (z.notes != null && z.notes!.isNotEmpty) 'notes': z.notes,
    };

    final ring = z.points;
    if (z.isPolygon && ring.length >= 3) {
      // GeoJSON requires the ring to be closed: the last position repeats the
      // first. Leaving it open is the other standard way to produce a file
      // that some readers accept and others reject.
      final coords = [
        for (final p in ring) [p.longitude, p.latitude],
      ];
      if (coords.first[0] != coords.last[0] ||
          coords.first[1] != coords.last[1]) {
        coords.add([coords.first[0], coords.first[1]]);
      }
      return {
        'type': 'Feature',
        'geometry': {'type': 'Polygon', 'coordinates': [coords]},
        'properties': props,
      };
    }

    return {
      'type': 'Feature',
      'geometry': {
        'type': 'Point',
        'coordinates': [z.longitude, z.latitude],
      },
      'properties': {...props, 'radius_m': z.radiusMeters},
    };
  }

  static List<Map<String, dynamic>> _trailFeature(Trail t) {
    final points = t.getWaypoints();
    if (points.length < 2) return const [];
    return [
      {
        'type': 'Feature',
        'geometry': {
          'type': 'LineString',
          'coordinates': [
            for (final p in points) [p.longitude, p.latitude],
          ],
        },
        'properties': {
          'kind': 'trail',
          'name': t.name ?? 'Trail',
          if (t.color != null) 'stroke': t.color,
          if (t.totalDistance != null) 'distance_m': t.totalDistance,
        },
      }
    ];
  }

  /// A filename that will survive being emailed, put on a USB stick and opened
  /// on somebody else's Windows machine.
  ///
  /// Spaces and punctuation out, because a project is named by a person in the
  /// field -- "Kookynie 12/10 (Dennis's)" is a perfectly reasonable thing to
  /// type and not a filename on any system.
  static String fileName(String projectName, ExportFormat format) {
    var base = projectName
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '')
        .replaceAll(RegExp(r'\s+'), '_');
    if (base.isEmpty) base = 'project';
    if (base.length > 60) base = base.substring(0, 60);
    return '$base.${format.extension}';
  }
}
