// Boundaries that are not circles are only useful if "am I inside it" is
// right, so the maths is tested directly rather than through the map.
import 'package:bush_track/core/models/geofence.dart';
import 'package:bush_track/core/utils/geo_geometry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  // A square about 1.1 km on a side, out near Leonora.
  const sw = LatLng(-28.900, 121.300);
  const se = LatLng(-28.900, 121.310);
  const ne = LatLng(-28.890, 121.310);
  const nw = LatLng(-28.890, 121.300);
  const square = [sw, se, ne, nw];

  group('isPointInPolygon', () {
    test('a point in the middle is inside', () {
      expect(isPointInPolygon(const LatLng(-28.895, 121.305), square), isTrue);
    });

    test('a point outside is outside', () {
      expect(isPointInPolygon(const LatLng(-28.880, 121.305), square), isFalse);
      expect(isPointInPolygon(const LatLng(-28.895, 121.400), square), isFalse);
    });

    test('a concave boundary excludes the notch', () {
      // An L-shape. A circle around the centre would wrongly include the
      // corner that was deliberately left out — this is the case that makes
      // drawn boundaries worth having.
      const lShape = [
        LatLng(-28.900, 121.300),
        LatLng(-28.900, 121.310),
        LatLng(-28.895, 121.310),
        LatLng(-28.895, 121.305),
        LatLng(-28.890, 121.305),
        LatLng(-28.890, 121.300),
      ];

      // In the arm of the L.
      expect(isPointInPolygon(const LatLng(-28.8975, 121.308), lShape), isTrue);
      // In the notch: inside the bounding box, outside the shape.
      expect(isPointInPolygon(const LatLng(-28.892, 121.308), lShape), isFalse);
    });

    test('fewer than three corners encloses nothing', () {
      expect(isPointInPolygon(const LatLng(-28.895, 121.305), const [sw, se]),
          isFalse);
      expect(isPointInPolygon(const LatLng(-28.895, 121.305), const []), isFalse);
    });
  });

  group('measurements', () {
    test('area of the square is about 1.1 square kilometres', () {
      // 0.01 degrees of latitude is ~1113 m; the same longitude span at 28.9
      // south is ~974 m. So roughly 1.08 million square metres.
      final area = polygonAreaSqMetres(square);
      expect(area, closeTo(1084000, 20000));
    });

    test('perimeter closes the loop back to the first corner', () {
      // Four sides, not three: ~1113 + ~974 twice over.
      expect(polygonPerimeterMetres(square), closeTo(4174, 100));
    });

    test('centroid of the square is its middle', () {
      final c = polygonCentroid(square);
      expect(c.latitude, closeTo(-28.895, 1e-6));
      expect(c.longitude, closeTo(121.305, 1e-6));
    });

    test('centroid survives corners in a straight line', () {
      // Collinear points enclose no area and would divide by zero.
      const line = [
        LatLng(-28.900, 121.300),
        LatLng(-28.895, 121.300),
        LatLng(-28.890, 121.300),
      ];
      expect(polygonCentroid(line).longitude, closeTo(121.300, 1e-9));
      expect(polygonCentroid(line).latitude, closeTo(-28.895, 1e-6));
    });

    test('distance to the edge is measured from the nearest side', () {
      // Just inside the northern edge: about 55 m from it, and much further
      // from the centre of the zone.
      final d = distanceToPolygonEdgeMetres(
          const LatLng(-28.8905, 121.305), square);
      expect(d, closeTo(55, 15));
    });

    test('area reads in units land is actually talked about in', () {
      expect(formatArea(850), '850 m²');
      expect(formatArea(42000), '4.2 ha');
      expect(formatArea(2500000), '2.50 km²');
    });
  });

  group('Geofence shapes', () {
    test('a circle contains what is within its radius', () {
      final zone = Geofence(
        name: 'Bore',
        latitude: -28.895,
        longitude: 121.305,
        radiusMeters: 200,
        isActive: true,
        createdAt: DateTime.now(),
      );

      expect(zone.contains(const LatLng(-28.8955, 121.305)), isTrue);
      expect(zone.contains(const LatLng(-28.900, 121.305)), isFalse);
      expect(zone.isPolygon, isFalse);
    });

    test('a drawn boundary derives its centre and reach', () {
      final zone = Geofence.polygon(
        name: 'Heritage site',
        points: square,
        isActive: true,
        createdAt: DateTime.now(),
        category: ZoneCategory.heritage,
      );

      expect(zone.isPolygon, isTrue);
      expect(zone.latitude, closeTo(-28.895, 1e-6));
      expect(zone.longitude, closeTo(121.305, 1e-6));
      // Reach is centre to furthest corner, i.e. half the diagonal.
      expect(zone.radiusMeters, closeTo(739, 40));
      expect(zone.contains(const LatLng(-28.895, 121.305)), isTrue);
      expect(zone.contains(const LatLng(-28.880, 121.305)), isFalse);
    });

    test('a boundary survives being written and read back', () {
      final original = Geofence.polygon(
        name: 'Exclusion',
        points: square,
        isActive: true,
        createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        category: ZoneCategory.hazard,
        notes: 'open shaft, do not approach',
      );

      final back = Geofence.fromMap(original.toMap());

      expect(back.name, 'Exclusion');
      expect(back.shape, ZoneShape.polygon);
      expect(back.points, hasLength(4));
      expect(back.points.first.latitude, closeTo(-28.900, 1e-9));
      expect(back.points.first.longitude, closeTo(121.300, 1e-9));
      expect(back.category, ZoneCategory.hazard);
      expect(back.notes, 'open shaft, do not approach');
      expect(back.contains(const LatLng(-28.895, 121.305)), isTrue);
    });

    test('a zone saved before boundaries existed still loads as a circle', () {
      // No shape, points_json, category or notes columns in the old schema.
      final back = Geofence.fromMap({
        'id': 7,
        'name': 'Old fence',
        'latitude': -28.895,
        'longitude': 121.305,
        'radius_meters': 300.0,
        'is_active': 1,
        'created_at': 1700000000000,
      });

      expect(back.shape, ZoneShape.circle);
      expect(back.points, isEmpty);
      expect(back.isPolygon, isFalse);
      expect(back.contains(const LatLng(-28.896, 121.305)), isTrue);
    });

    test('corrupt corner data falls back to a circle instead of throwing', () {
      final back = Geofence.fromMap({
        'name': 'Truncated',
        'latitude': -28.895,
        'longitude': 121.305,
        'radius_meters': 300.0,
        'is_active': 1,
        'created_at': 1700000000000,
        'shape': 'polygon',
        'points_json': '[[-28.9,121.3],[bad',
      });

      expect(back.points, isEmpty);
      expect(back.isPolygon, isFalse,
          reason: 'a boundary with no corners must not claim to be one');
    });
  });
}
