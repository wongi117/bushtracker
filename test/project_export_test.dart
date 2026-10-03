// GeoJSON export. Two mistakes here produce a valid file that opens without
// complaint and is wrong: coordinates in the human order, and an unclosed
// polygon ring. Both are checked against parsed output rather than against a
// string, so the assertions are about the data and not the formatting.
import 'dart:convert';

import 'package:bush_track/core/models/geofence.dart';
import 'package:bush_track/core/models/trail.dart';
import 'package:bush_track/core/models/waypoint.dart';
import 'package:bush_track/core/services/project_export.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  // Leonora. Latitude is negative and longitude is well over 100, so the two
  // can never be mistaken for each other if they are swapped.
  const lat = -28.8833;
  const lon = 121.33;

  Waypoint pin({String? label = 'Shaft', double? la = lat, double? lo = lon}) =>
      Waypoint(
        id: 1,
        label: label,
        latitude: la,
        longitude: lo,
        isPin: true,
        color: '#FF2D55',
        timestamp: DateTime.utc(2026, 10, 1, 7, 30),
      );

  Geofence circle({double radius = 200}) => Geofence(
        id: 1,
        name: 'Heritage',
        latitude: lat,
        longitude: lon,
        radiusMeters: radius,
        isActive: true,
        createdAt: DateTime.utc(2026, 10, 1),
      );

  Geofence poly(List<LatLng> points) => Geofence.polygon(
        id: 1,
        name: 'Poly',
        points: points,
        isActive: true,
        createdAt: DateTime.utc(2026, 10, 1),
      );

  Map<String, dynamic> parse(String out) =>
      jsonDecode(out) as Map<String, dynamic>;

  List<dynamic> featuresOf(String out) =>
      (parse(out)['features'] as List<dynamic>);

  Map<String, dynamic> only(String out) =>
      featuresOf(out).single as Map<String, dynamic>;

  group('it is valid GeoJSON', () {
    test('a FeatureCollection with the project name on it', () {
      final out = ProjectExport.geoJson(
          projectName: 'Kookynie', pins: [pin()]);
      final doc = parse(out);

      expect(doc['type'], 'FeatureCollection');
      expect(doc['name'], 'Kookynie');
      expect(doc['features'], isA<List<dynamic>>());
    });

    test('an empty project still produces a readable file', () {
      // Rather than an empty string or a crash: a project with nothing in it
      // is a normal thing to export by accident.
      final out = ProjectExport.geoJson(projectName: 'Empty');
      expect(parse(out)['features'], isEmpty);
    });

    test('and it parses, which a hand-built string often does not', () {
      final out = ProjectExport.geoJson(
        projectName: 'All',
        pins: [pin()],
        zones: [
          Geofence(
              id: 1,
              name: 'Heritage',
              latitude: lat,
              longitude: lon,
              radiusMeters: 200, isActive: true, createdAt: DateTime.utc(2026, 10, 1))
        ],
        trails: [Trail(id: 1, name: 'Track')..setWaypoints(const [
              LatLng(lat, lon),
              LatLng(-28.89, 121.34),
            ])],
      );
      expect(() => jsonDecode(out), returnsNormally);
      expect(featuresOf(out), hasLength(3));
    });
  });

  group('coordinates are [longitude, latitude]', () {
    test('a pin, in the specification order and not the human one', () {
      // Backwards, this file lands off the coast of Somalia and still opens
      // without complaint. Longitude here is 121 and latitude is -28, so a
      // swap cannot hide.
      final coords =
          (only(ProjectExport.geoJson(projectName: 'P', pins: [pin()]))
              ['geometry'] as Map<String, dynamic>)['coordinates'] as List<dynamic>;

      expect(coords[0], lon, reason: 'longitude comes first');
      expect(coords[1], lat, reason: 'latitude comes second');
    });

    test('a circular zone centre', () {
      final out = ProjectExport.geoJson(projectName: 'P', zones: [
        Geofence(
            id: 1,
            name: 'Z',
            latitude: lat,
            longitude: lon,
            radiusMeters: 50, isActive: true, createdAt: DateTime.utc(2026, 10, 1))
      ]);
      final coords = ((only(out)['geometry'] as Map<String, dynamic>)
          ['coordinates'] as List<dynamic>);
      expect(coords[0], lon);
      expect(coords[1], lat);
    });

    test('a trail line', () {
      final out = ProjectExport.geoJson(projectName: 'P', trails: [
        Trail(id: 1, name: 'T')
          ..setWaypoints(const [LatLng(lat, lon), LatLng(-28.9, 121.4)])
      ]);
      final line = ((only(out)['geometry'] as Map<String, dynamic>)
          ['coordinates'] as List<dynamic>);
      expect((line.first as List<dynamic>)[0], lon);
      expect((line.first as List<dynamic>)[1], lat);
    });

    test('and every ring position of a polygon', () {
      final out = ProjectExport.geoJson(projectName: 'P', zones: [
        Geofence.polygon(id: 1, name: 'Poly', isActive: true, createdAt: DateTime.utc(2026, 10, 1), points: const [
          LatLng(lat, lon),
          LatLng(-28.89, 121.34),
          LatLng(-28.88, 121.35),
        ])
      ]);
      final ring = (((only(out)['geometry'] as Map<String, dynamic>)
          ['coordinates'] as List<dynamic>).first as List<dynamic>);

      for (final pos in ring) {
        final p = pos as List<dynamic>;
        expect(p[0], greaterThan(100), reason: 'longitude is the big one here');
        expect(p[1], lessThan(0), reason: 'latitude is negative in WA');
      }
    });
  });

  group('a polygon ring is closed', () {
    test('the last position repeats the first', () {
      // An open ring is accepted by some readers and rejected by others, which
      // is the worst kind of wrong: it works on the machine it was tested on.
      final out = ProjectExport.geoJson(projectName: 'P', zones: [
        Geofence.polygon(id: 1, name: 'Poly', isActive: true, createdAt: DateTime.utc(2026, 10, 1), points: const [
          LatLng(lat, lon),
          LatLng(-28.89, 121.34),
          LatLng(-28.88, 121.35),
        ])
      ]);
      final ring = (((only(out)['geometry'] as Map<String, dynamic>)
          ['coordinates'] as List<dynamic>).first as List<dynamic>);

      expect(ring.first, ring.last);
      expect(ring, hasLength(4), reason: '3 corners plus the repeat');
    });

    test('and it is not closed twice when it already was', () {
      final out = ProjectExport.geoJson(projectName: 'P', zones: [
        Geofence.polygon(id: 1, name: 'Poly', isActive: true, createdAt: DateTime.utc(2026, 10, 1), points: const [
          LatLng(lat, lon),
          LatLng(-28.89, 121.34),
          LatLng(-28.88, 121.35),
          LatLng(lat, lon),
        ])
      ]);
      final ring = (((only(out)['geometry'] as Map<String, dynamic>)
          ['coordinates'] as List<dynamic>).first as List<dynamic>);

      expect(ring, hasLength(4));
      expect(ring.first, ring.last);
    });
  });

  group('a circle keeps its radius instead of being guessed at', () {
    test('it exports as a Point carrying radius_m', () {
      // GeoJSON has no circle. Approximating it into a many-sided polygon
      // would hand somebody a boundary nobody drew; a Point plus the radius
      // gives an exact circle to a reader that understands it and the centre
      // to one that does not.
      final out = ProjectExport.geoJson(projectName: 'P', zones: [
        Geofence(
            id: 1,
            name: 'Exclusion',
            latitude: lat,
            longitude: lon,
            radiusMeters: 250, isActive: true, createdAt: DateTime.utc(2026, 10, 1))
      ]);
      final f = only(out);

      expect((f['geometry'] as Map<String, dynamic>)['type'], 'Point');
      expect((f['properties'] as Map<String, dynamic>)['radius_m'], 250);
      expect((f['properties'] as Map<String, dynamic>)['kind'], 'zone');
    });

    test('a polygon with too few corners falls back to its centre', () {
      // Two points is not an area. Better a point than a malformed ring.
      final out = ProjectExport.geoJson(projectName: 'P', zones: [
        Geofence(
            id: 1,
            name: 'Thin',
            latitude: lat,
            longitude: lon,
            radiusMeters: 10,
            isActive: true,
            createdAt: DateTime.utc(2026, 10, 1),
            shape: ZoneShape.polygon,
            points: const [LatLng(lat, lon), LatLng(-28.89, 121.34)])
      ]);
      expect((only(out)['geometry'] as Map<String, dynamic>)['type'], 'Point');
    });
  });

  group('what gets left out', () {
    test('a pin with no position is skipped, not exported at 0,0', () {
      // Null island is a real place on every map and a pin there is a lie.
      final out = ProjectExport.geoJson(
          projectName: 'P', pins: [pin(la: null, lo: null)]);
      expect(featuresOf(out), isEmpty);
    });

    test('a trail with one point is not a line', () {
      final out = ProjectExport.geoJson(projectName: 'P', trails: [
        Trail(id: 1, name: 'T')..setWaypoints(const [LatLng(lat, lon)])
      ]);
      expect(featuresOf(out), isEmpty);
    });

    test('a pin with no timestamp omits recorded_at rather than faking it', () {
      final out = ProjectExport.geoJson(
          projectName: 'P',
          pins: [
            Waypoint(
                id: 1,
                label: 'No time',
                latitude: lat,
                longitude: lon,
                isPin: true)
          ]);
      final props = only(out)['properties'] as Map<String, dynamic>;
      expect(props.containsKey('recorded_at'), isFalse);
      expect(props['name'], 'No time');
    });
  });

  group('the formats say what they cost', () {
    test('GPX admits it loses boundary shapes', () {
      // Choosing GPX for a heritage boundary and getting a single point back
      // is a data loss that looks like a success, so the picker has to say so.
      expect(ExportFormat.gpx.keepsZoneShape, isFalse);
      expect(ExportFormat.gpx.caveat.toLowerCase(), contains('boundaries'));
    });

    test('GeoJSON and KML keep them', () {
      expect(ExportFormat.geoJson.keepsZoneShape, isTrue);
      expect(ExportFormat.kml.keepsZoneShape, isTrue);
    });

    test('each has a label, an extension and a caveat', () {
      for (final f in ExportFormat.values) {
        expect(f.label, isNotEmpty);
        expect(f.extension, isNotEmpty);
        expect(f.caveat, isNotEmpty, reason: '${f.name} needs its trade-off');
      }
    });
  });

  group('the filename survives leaving the phone', () {
    test('spaces and punctuation a person would really type come out', () {
      final name = ProjectExport.fileName(
          "Kookynie 12/10 (Dennis's)", ExportFormat.geoJson);
      expect(name, endsWith('.geojson'));
      expect(name, isNot(contains(' ')));
      expect(name, isNot(contains('/')));
      expect(name, isNot(contains("'")));
      expect(name, isNot(contains('(')));
    });

    test('a name of nothing but punctuation still gives a filename', () {
      expect(ProjectExport.fileName('///', ExportFormat.gpx), 'project.gpx');
      expect(ProjectExport.fileName('   ', ExportFormat.kml), 'project.kml');
    });

    test('a very long name is cut, not left to break the write', () {
      final name =
          ProjectExport.fileName('A' * 300, ExportFormat.geoJson);
      expect(name.length, lessThanOrEqualTo(70));
      expect(name, endsWith('.geojson'));
    });

    test('the extension matches the format', () {
      expect(ProjectExport.fileName('P', ExportFormat.gpx), 'P.gpx');
      expect(ProjectExport.fileName('P', ExportFormat.kml), 'P.kml');
      expect(ProjectExport.fileName('P', ExportFormat.geoJson), 'P.geojson');
    });
  });
}
