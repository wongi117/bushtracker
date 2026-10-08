// Phase 4.3: which zone a tap means, who may change it, and reshaping one
// without losing anything about it.
import 'dart:math' as math;

import 'package:bush_track/core/models/geofence.dart';
import 'package:bush_track/features/drawing/services/line_geometry.dart';
import 'package:bush_track/features/geofence/services/zone_selection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  const leonora = LatLng(-28.88, 121.33);
  LatLng at(double metres, double bearing) =>
      const Distance(roundResult: false).offset(leonora, metres, bearing);

  /// A square boundary [half] metres from the centre to each side.
  Geofence square(double half, {int? id, String name = 'zone', int? fileId}) =>
      Geofence.polygon(
        id: id,
        name: name,
        points: [
          at(half * math.sqrt2, 315),
          at(half * math.sqrt2, 45),
          at(half * math.sqrt2, 135),
          at(half * math.sqrt2, 225),
        ],
        isActive: true,
        createdAt: DateTime(2026, 10, 8),
        fileId: fileId,
      );

  Geofence circle(double radius, {int? id}) => Geofence(
        id: id,
        name: 'bore',
        latitude: leonora.latitude,
        longitude: leonora.longitude,
        radiusMeters: radius,
        isActive: true,
        createdAt: DateTime(2026, 10, 8),
      );

  group('which zone a tap means', () {
    test('inside picks it', () {
      expect(zoneAt(leonora, [square(100, id: 1)], 10)?.id, 1);
    });

    test('just outside the edge, within a fingertip, picks it too', () {
      expect(zoneAt(at(105, 90), [square(100, id: 1)], 10)?.id, 1);
    });

    test('further out, nothing', () {
      expect(zoneAt(at(150, 90), [square(100, id: 1)], 10), isNull);
    });

    test('nested: the smaller one wins, in either order', () {
      // A hazard inside a lease. The lease is reachable by tapping anywhere
      // else in it; the hazard only by aiming at it.
      final lease = square(2000, id: 1);
      final hazard = square(50, id: 2);
      expect(zoneAt(leonora, [lease, hazard], 10)?.id, 2);
      expect(zoneAt(leonora, [hazard, lease], 10)?.id, 2);
      expect(zoneAt(at(500, 0), [lease, hazard], 10)?.id, 1);
    });

    test('circles count the same way', () {
      expect(zoneAt(at(80, 0), [circle(100, id: 3)], 10)?.id, 3);
      expect(zoneAt(at(108, 0), [circle(100, id: 3)], 10)?.id, 3);
      expect(zoneAt(at(130, 0), [circle(100, id: 3)], 10), isNull);
    });
  });

  group('perimeter', () {
    test('a 200 m square is 800 m round', () {
      expect(square(100).perimeterMetres, closeTo(800, 2));
    });

    test('a circle is 2πr', () {
      expect(circle(100).perimeterMetres, closeTo(2 * math.pi * 100, 1e-6));
    });
  });

  group('reshaping a boundary keeps everything else', () {
    test('its project, name, category, notes and state survive', () {
      // Rebuilding field by field dropped fileId: moving a corner took the
      // zone out of its project.
      final was = square(100, id: 9, name: 'old shaft', fileId: 4).copyWith(
          category: ZoneCategory.heritage, notes: 'fenced 1998', isActive: false);
      final moved = was.withPolygon([...was.points.take(3), at(200, 225)]);

      expect(moved.fileId, 4);
      expect(moved.id, 9);
      expect(moved.name, 'old shaft');
      expect(moved.category, ZoneCategory.heritage);
      expect(moved.notes, 'fenced 1998');
      expect(moved.isActive, isFalse);
      expect(moved.createdAt, was.createdAt);
    });

    test('and the shape and its centre do change', () {
      final was = square(100);
      final moved = was.withPolygon([
        for (final p in was.points)
          const Distance(roundResult: false).offset(p, 1000, 0),
      ]);
      expect(moved.isPolygon, isTrue);
      expect(const Distance()(moved.centre, was.centre), closeTo(1000, 5));
    });

    test('a circle turned into a boundary becomes a polygon', () {
      final moved = circle(100).withPolygon(square(50).points);
      expect(moved.shape, ZoneShape.polygon);
      expect(moved.isPolygon, isTrue);
    });
  });

  group('who may change a zone', () {
    test('until sharing exists, every zone is the owner\'s', () {
      expect(accessFor(square(100)), ZoneAccess.owner);
    });

    test('view-only means no edit and no delete', () {
      expect(ZoneAccess.view.canEdit, isFalse);
      expect(ZoneAccess.view.canDelete, isFalse);
    });

    test('shared to edit means edit, but not delete', () {
      expect(ZoneAccess.edit.canEdit, isTrue);
      expect(ZoneAccess.edit.canDelete, isFalse);
    });
  });

  group('a boundary as a closed ring', () {
    final corners = square(100).points;

    test('the closing edge has a + too', () {
      final ring = LineDraft(corners, true);
      expect(ring.midpoints, hasLength(4));
      // The last one sits between the last corner and the first.
      final closing = ring.midpoints.last;
      final expected = LatLng((corners.last.latitude + corners.first.latitude) / 2,
          (corners.last.longitude + corners.first.longitude) / 2);
      expect(const Distance()(closing, expected), lessThan(0.01));
    });

    test('inserting on the closing edge goes between the last and first', () {
      final ring = LineDraft(corners, true);
      ring.insert(4, ring.midpoints[3]);
      expect(ring.points, hasLength(5));
      expect(ring.points.first, corners.first);
      expect(ring.points[3], corners[3]);
    });

    test('a line has no closing edge', () {
      expect(LineDraft(corners).midpoints, hasLength(3));
    });

    test('an edited boundary cannot drop below three corners', () {
      final ring = LineDraft(corners.take(3).toList(), true, 3);
      ring.remove(0);
      expect(ring.points, hasLength(3));
      expect(ring.canUndo, isFalse, reason: 'a refused remove is no step');
    });
  });
}
