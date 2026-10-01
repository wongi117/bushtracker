// AR labels had no touch target at all. These cover the geometry the painter
// and the tap handler now share — including the case that matters most, two
// labels on top of each other, where the tap has to pick the one in front
// rather than whichever happens to be first in the list.
import 'dart:ui';

import 'package:bush_track/core/models/waypoint.dart';
import 'package:bush_track/features/ar/services/ar_projection.dart';
import 'package:bush_track/features/ar/services/ar_targets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  const size = Size(1080, 2340);
  final here = LatLng(-28.8833, 121.3333);

  ArProjection facing(double headingDeg) => ArProjection(
        size: size,
        headingDeg: headingDeg,
        pitchRad: 0,
      );

  /// A pin [distanceM] away on [bearingDeg].
  Waypoint pinAt(double bearingDeg, double distanceM, {int? id, String? name}) {
    final at = const Distance().offset(here, distanceM, bearingDeg);
    return Waypoint(
      id: id,
      latitude: at.latitude,
      longitude: at.longitude,
      label: name ?? 'Pin',
      isPin: true,
    );
  }

  List<ArTarget> build(List<Waypoint> pins, {double heading = 0}) =>
      buildArTargets(
        waypoints: pins,
        currentLocation: here,
        projection: facing(heading),
        size: size,
        beamHeightM: 60,
        minBeamPixels: 80,
      );

  group('what is in view', () {
    test('a pin straight ahead is a target', () {
      final targets = build([pinAt(0, 100)]);
      expect(targets, hasLength(1));
      expect(targets.single.distanceM, closeTo(100, 2));
      expect(targets.single.bearingDeg, closeTo(0, 1));
    });

    test('a pin behind you is not', () {
      expect(build([pinAt(180, 100)]), isEmpty);
    });

    test('a pin with no position is skipped rather than crashing', () {
      expect(build([Waypoint(id: 1, label: 'nowhere', isPin: true)]), isEmpty);
    });

    test('targets come back farthest first, matching the draw order', () {
      final targets = build([pinAt(0, 50), pinAt(2, 400), pinAt(-2, 150)]);
      expect(targets.map((t) => t.distanceM.round()),
          [400, 150, 50].map((d) => closeTo(d, 3)));
    });
  });

  group('the touch target', () {
    test('is at least 48 across, however thin the beam is drawn', () {
      // A pin four kilometres off is a couple of pixels wide on screen.
      final t = build([pinAt(0, 4000)]).single;
      expect(t.tapTarget.width, greaterThanOrEqualTo(48));
    });

    test('covers the beam from its foot to its label', () {
      final t = build([pinAt(0, 60)]).single;
      expect(t.tapTarget.top, lessThanOrEqualTo(t.beamTop.dy));
      expect(t.tapTarget.bottom, greaterThanOrEqualTo(t.base.dy));
    });

    test('a tap counts at the foot or at the label, not in between', () {
      // Deliberately not the whole length: see buildArTargets.
      final t = build([pinAt(0, 30)]).single;
      expect(t.hotSpots, hasLength(2));
      expect(t.hotSpots.first, t.base);
      expect(t.hotSpots.last, t.beamTop);
    });

    test('is centred on the beam', () {
      final t = build([pinAt(10, 200)]).single;
      expect(t.tapTarget.center.dx, closeTo(t.base.dx, 0.5));
    });
  });

  group('tapping', () {
    test('a tap on the beam finds the pin', () {
      final targets = build([pinAt(0, 100, id: 7)]);
      final hit = hitTest(targets, targets.single.base);
      expect(hit?.waypoint.id, 7);
    });

    test('a tap on the label finds the pin', () {
      final targets = build([pinAt(0, 100, id: 7)]);
      expect(hitTest(targets, targets.single.beamTop)?.waypoint.id, 7);
    });

    test('a tap in empty sky finds nothing', () {
      final targets = build([pinAt(0, 100)]);
      expect(hitTest(targets, const Offset(60, 60)), isNull);
    });

    test('a near miss still counts, so a thin beam is not unhittable', () {
      final targets = build([pinAt(0, 2000, id: 3)]);
      final t = targets.single;
      // Twenty pixels to the side of a beam only a few pixels wide.
      final near = Offset(t.base.dx + 30, t.base.dy);
      expect(hitTest(targets, near)?.waypoint.id, 3);
    });

    test('but a long way off does not', () {
      final targets = build([pinAt(0, 2000)]);
      final t = targets.single;
      expect(hitTest(targets, Offset(t.base.dx + 300, t.base.dy)), isNull);
    });
  });

  group('overlapping labels', () {
    test('the nearer pin wins when two sit on top of each other', () {
      // Same bearing, different distances: their beams share a column of the
      // screen. The near one is drawn over the far one, so a tap there means
      // the near one.
      final targets = build([
        pinAt(0, 500, id: 1, name: 'far'),
        pinAt(0, 40, id: 2, name: 'near'),
      ]);
      expect(targets, hasLength(2));

      final near = targets.firstWhere((t) => t.waypoint.id == 2);
      final hit = hitTest(targets, near.base);
      expect(hit?.waypoint.id, 2, reason: 'should pick the pin in front');
    });

    test('the far pin is still reachable where the near one is not', () {
      final targets = build([
        pinAt(0, 500, id: 1, name: 'far'),
        pinAt(0, 40, id: 2, name: 'near'),
      ]);
      final far = targets.firstWhere((t) => t.waypoint.id == 1);
      final near = targets.firstWhere((t) => t.waypoint.id == 2);

      // A close pin's 60 m beam towers off the top of the screen, so its
      // label is far above the frame; a distant pin's sits near the horizon.
      expect(near.beamTop.dy, lessThan(far.beamTop.dy));
      // Tapping the far one's label must not be swallowed by the near one's
      // beam passing through that column.
      final hit = hitTest(targets, far.beamTop);
      expect(hit?.waypoint.id, 1);
    });

    test('three in a row all stay individually reachable', () {
      final targets = build([
        pinAt(-12, 200, id: 1),
        pinAt(0, 200, id: 2),
        pinAt(12, 200, id: 3),
      ]);
      for (final t in targets) {
        expect(hitTest(targets, t.base)?.waypoint.id, t.waypoint.id);
      }
    });
  });

  group('turning on the spot', () {
    test('a pin leaves the list as you turn away from it', () {
      final pin = pinAt(0, 100);
      expect(build([pin], heading: 0), hasLength(1));
      expect(build([pin], heading: 90), isEmpty);
    });

    test('and its target moves across the screen as you turn', () {
      final pin = pinAt(0, 100);
      final ahead = build([pin], heading: 0).single;
      final toTheLeft = build([pin], heading: 20).single;
      expect(toTheLeft.base.dx, lessThan(ahead.base.dx),
          reason: 'turning right moves a pin left across the image');
    });
  });
}
