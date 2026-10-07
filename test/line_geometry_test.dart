// The drawing tools' arithmetic, held to outside facts where there are any --
// a degree of meridian arc, the compass, the simplifier's distance guarantee --
// rather than to its own output.
import 'dart:math' as math;

import 'package:bush_track/features/drawing/services/line_geometry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  const leonora = LatLng(-28.88, 121.33);

  /// A point [metres] from [from] along [bearing], via latlong2's offset.
  LatLng offset(LatLng from, double metres, double bearing) =>
      const Distance(roundResult: false).offset(from, metres, bearing);

  /// A point [metres] from [from] along [bearing], worked out on a sphere
  /// here rather than by the library under test -- latlong2's own offset and
  /// bearing disagree by 0.05° at 350°, so using one to check the other
  /// checks nothing.
  LatLng onSphere(LatLng from, double metres, double bearing) {
    const r = 6371008.8;
    final b = bearing * math.pi / 180;
    final dLat = metres * math.cos(b) / r * 180 / math.pi;
    final dLon = metres * math.sin(b) /
        (r * math.cos(from.latitude * math.pi / 180)) * 180 / math.pi;
    return LatLng(from.latitude + dLat, from.longitude + dLon);
  }

  group('lengths', () {
    test('one degree of meridian matches the WGS84 radius of curvature', () {
      // M = a(1-e²) / (1 - e² sin²φ)^1.5, per radian, at the midpoint 28.5°S.
      // Worked here from the ellipsoid's constants, not taken from a library:
      // 110,827.6 m. (110,868, the figure first written into this test from
      // memory, was wrong -- the formula is the authority.)
      const a = 6378137.0, e2 = 0.00669437999014;
      final s2 = math.pow(math.sin(28.5 * math.pi / 180), 2);
      final perDegree =
          a * (1 - e2) / math.pow(1 - e2 * s2, 1.5) * math.pi / 180;
      final m = LineMeasure.totalMetres(
          const [LatLng(-28.0, 121.0), LatLng(-29.0, 121.0)]);
      expect(m, closeTo(perDegree, 2));
    });

    test('the total is the sum of the legs', () {
      final pts = [leonora, offset(leonora, 300, 45), offset(leonora, 800, 120)];
      final segs = LineMeasure.segments(pts);
      expect(segs, hasLength(2));
      expect(LineMeasure.totalMetres(pts),
          closeTo(segs[0].metres + segs[1].metres, 1e-6));
    });

    test('hundreds of short legs are not rounded away', () {
      // latlong2 rounds to the metre by default: 500 legs of 0.4 m would sum
      // to zero. A freehand stroke is exactly that shape.
      final pts = [for (var i = 0; i <= 500; i++) offset(leonora, i * 0.4, 90)];
      expect(LineMeasure.totalMetres(pts), closeTo(200, 0.5));
    });

    test('one point or none is no length, not an error', () {
      expect(LineMeasure.totalMetres(const []), 0);
      expect(LineMeasure.totalMetres(const [leonora]), 0);
      expect(LineMeasure.segments(const [leonora]), isEmpty);
    });
  });

  group('bearings', () {
    test('the four quarters', () {
      for (final b in [0.0, 90.0, 180.0, 270.0]) {
        expect(LineMeasure.bearing(leonora, onSphere(leonora, 500, b)),
            closeTo(b, 0.01));
      }
    });

    test('never negative, never 360', () {
      // latlong2 hands back -180..180. West of north must come out as 3xx.
      final b = LineMeasure.bearing(leonora, onSphere(leonora, 500, 350));
      expect(b, closeTo(350, 0.01));
      for (var d = 0.0; d < 360; d += 7.5) {
        final got = LineMeasure.bearing(leonora, onSphere(leonora, 200, d));
        expect(got, inInclusiveRange(0, 360 - 1e-9));
        expect(got, closeTo(d, 0.01));
      }
    });

    test('compass names, including either side of north', () {
      expect(LineMeasure.compassPoint(350), 'N');
      expect(LineMeasure.compassPoint(10), 'N');
      expect(LineMeasure.compassPoint(22.4), 'N');
      expect(LineMeasure.compassPoint(22.5), 'NE');
      expect(LineMeasure.compassPoint(180), 'S');
      expect(LineMeasure.compassPoint(337.4), 'NW');
      expect(LineMeasure.compassPoint(337.5), 'N');
    });
  });

  group('simplification keeps the shape', () {
    List<LatLng> circle(double radius, int n) => [
          for (var i = 0; i <= n; i++) offset(leonora, radius, i * 360 / n),
        ];

    test('no original point ends up further than the tolerance', () {
      // The guarantee itself, over a shape with no straight parts at all.
      final stroke = circle(100, 720);
      for (final tol in [0.5, 1.0, 3.0, 10.0]) {
        final out = LineSimplifier.simplify(stroke, tol);
        expect(LineSimplifier.maxDeviationMetres(stroke, out),
            lessThanOrEqualTo(tol + 1e-6),
            reason: 'tolerance $tol m');
        expect(out.length, lessThan(stroke.length), reason: 'tolerance $tol m');
      }
    });

    test('a straight stroke comes down to its two ends', () {
      final stroke = [for (var i = 0; i <= 200; i++) offset(leonora, i * 2.0, 60)];
      final out = LineSimplifier.simplify(stroke, 0.5);
      expect(out, [stroke.first, stroke.last]);
    });

    test('a sharp corner survives', () {
      // An L: 100 m east, then 100 m north. Losing the corner would cut it
      // into a diagonal 70 m from where the line really turned.
      final corner = offset(leonora, 100, 90);
      final stroke = [
        for (var i = 0; i <= 50; i++) offset(leonora, i * 2.0, 90),
        for (var i = 1; i <= 50; i++) offset(corner, i * 2.0, 0),
      ];
      final out = LineSimplifier.simplify(stroke, 1);
      expect(out, hasLength(3));
      expect(const Distance()(out[1], corner), lessThan(2.1));
    });

    test('the ends are always kept', () {
      final stroke = circle(50, 90);
      final out = LineSimplifier.simplify(stroke, 25);
      expect(out.first, stroke.first);
      expect(out.last, stroke.last);
    });

    test('a long walk does not overflow the stack', () {
      // 20,000 points of gentle wander: recursion this deep is how a naive
      // RDP falls over on a real stroke.
      final rnd = math.Random(4);
      var p = leonora;
      final stroke = <LatLng>[p];
      for (var i = 0; i < 20000; i++) {
        p = offset(p, 1, 90 + rnd.nextDouble() * 20 - 10);
        stroke.add(p);
      }
      final out = LineSimplifier.simplify(stroke, 2);
      expect(LineSimplifier.maxDeviationMetres(stroke, out),
          lessThanOrEqualTo(2 + 1e-6));
    });

    test('fewer than three points come back as they are', () {
      expect(LineSimplifier.simplify(const [leonora], 5), [leonora]);
      expect(LineSimplifier.simplify(const [], 5), isEmpty);
    });
  });

  group('snapping', () {
    final pin = SnapTarget(offset(leonora, 8, 0), label: 'pin', key: 1);
    final far = SnapTarget(offset(leonora, 40, 0), label: 'far', key: 2);

    test('snaps to a pin within reach', () {
      expect(Snapping.nearest(leonora, [pin, far], 10)?.key, 1);
    });

    test('and to nothing outside it', () {
      expect(Snapping.nearest(leonora, [far], 10), isNull);
    });

    test('the nearest of two in reach wins, whatever order they come in', () {
      final near = SnapTarget(offset(leonora, 3, 180), key: 3);
      expect(Snapping.nearest(leonora, [pin, near], 10)?.key, 3);
      expect(Snapping.nearest(leonora, [near, pin], 10)?.key, 3);
    });
  });

  group('drawing and undoing', () {
    final a = leonora, b = offset(leonora, 100, 90), c = offset(leonora, 200, 90);

    test('each tap is one undo', () {
      final d = LineDraft()..add(a)..add(b)..add(c);
      d.undo();
      expect(d.points, [a, b]);
      d..undo()..undo();
      expect(d.isEmpty, isTrue);
      expect(d.canUndo, isFalse);
      d.undo(); // nothing to undo is not an error
      expect(d.isEmpty, isTrue);
    });

    test('a whole drag is one undo, however many frames it took', () {
      final d = LineDraft([a, b, c]);
      for (var i = 1; i <= 60; i++) {
        d.drag(1, offset(b, i.toDouble(), 0));
      }
      d.endDrag();
      expect(d.points[1], offset(b, 60, 0));
      d.undo();
      expect(d.points, [a, b, c]);
    });

    test('two drags are two undos', () {
      final d = LineDraft([a, b, c])
        ..drag(0, offset(a, 5, 0))
        ..endDrag()
        ..drag(2, offset(c, 5, 0))
        ..endDrag();
      d.undo();
      expect(d.points, [offset(a, 5, 0), b, c]);
    });

    test('a freehand stroke is one undo', () {
      final d = LineDraft()..addStroke([a, b, c]);
      d.undo();
      expect(d.isEmpty, isTrue);
    });

    test('insert and remove a vertex', () {
      final d = LineDraft([a, c])..insert(1, b);
      expect(d.points, [a, b, c]);
      d.remove(1);
      expect(d.points, [a, c]);
    });

    test('out-of-range edits change nothing and add no undo step', () {
      final d = LineDraft([a, b])
        ..insert(0, c)
        ..insert(5, c)
        ..remove(9)
        ..drag(-1, c);
      expect(d.points, [a, b]);
      expect(d.canUndo, isFalse);
    });

    test('the list handed out cannot be edited behind the draft', () {
      final d = LineDraft([a]);
      expect(() => d.points.add(b), throwsUnsupportedError);
    });

    test('midpoints sit between their vertices', () {
      final d = LineDraft([a, c]);
      expect(const Distance()(d.midpoints.single, b), lessThan(0.5));
    });
  });
}
