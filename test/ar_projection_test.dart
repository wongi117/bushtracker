// The AR overlay is only as good as this maths, and "looks about right on a
// phone" is not a check. These pin down the behaviour the field report asked
// for: distant pins on the horizon, near pins low, and the horizon moving
// when the phone tilts.
import 'dart:math' as math;
import 'dart:ui';

import 'package:bush_track/features/ar/services/ar_projection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const size = Size(1080, 2340); // portrait phone
  ArProjection level({double heading = 0, double pitch = 0}) => ArProjection(
        size: size,
        headingDeg: heading,
        pitchRad: pitch,
      );

  group('horizon', () {
    test('a level camera puts the horizon across the middle', () {
      expect(level().horizonY, closeTo(size.height / 2, 0.01));
    });

    test('tilting up pushes the horizon down the screen, and back', () {
      final up = level(pitch: 10 * math.pi / 180).horizonY;
      final down = level(pitch: -10 * math.pi / 180).horizonY;

      expect(up, greaterThan(size.height / 2));
      expect(down, lessThan(size.height / 2));
      // Symmetric either side of level.
      expect(up - size.height / 2, closeTo(size.height / 2 - down, 0.01));
    });
  });

  group('horizontal placement', () {
    test('straight ahead is the centre of the image', () {
      expect(level(heading: 90).screenX(90), closeTo(size.width / 2, 0.01));
    });

    test('to the right is right of centre, to the left is left', () {
      final p = level(heading: 0);
      expect(p.screenX(20), greaterThan(size.width / 2));
      expect(p.screenX(340), lessThan(size.width / 2));
    });

    test('bearing wraps around north without flipping sides', () {
      // Heading 350, target 010: twenty degrees to the RIGHT, not 340 left.
      final p = level(heading: 350);
      expect(p.screenX(10), greaterThan(size.width / 2));
    });

    test('a camera is a projection, not a ruler', () {
      // Double the angle is more than double the offset from centre.
      final p = level(heading: 0);
      final at15 = p.screenX(15) - size.width / 2;
      final at30 = p.screenX(30) - size.width / 2;
      expect(at30, greaterThan(at15 * 2));
    });

    test('things behind the camera are not in view', () {
      final p = level(heading: 0);
      expect(p.isInView(0), isTrue);
      expect(p.isInView(180), isFalse);
      expect(p.isInView(90), isFalse);
    });
  });

  group('distance and height', () {
    test('a pin kilometres away sits essentially on the horizon', () {
      final p = level();
      final far = p.screenY(4300); // 4.3 km, as reported from the field
      expect((far - p.horizonY).abs(), lessThan(size.height * 0.01),
          reason: 'a pin 4.3 km away should be within 1% of the horizon');
    });

    test('a pin close by sits well below the horizon', () {
      final p = level();
      final near = p.screenY(10);
      expect(near, greaterThan(p.horizonY + size.height * 0.05));
    });

    test('ground points march up towards the horizon with distance', () {
      final p = level();
      final ys = [5.0, 20.0, 100.0, 1000.0].map(p.screenY).toList();
      for (var i = 1; i < ys.length; i++) {
        expect(ys[i], lessThan(ys[i - 1]),
            reason: 'further away must be higher up the image');
      }
    });

    test('something tall rises above the horizon when it is close', () {
      final p = level();
      // A 60 m beam 30 m away towers over you.
      expect(p.screenY(30, metresAboveGround: 60), lessThan(p.horizonY));
      // The same beam 5 km away does not.
      expect(p.screenY(5000, metresAboveGround: 60),
          closeTo(p.horizonY, size.height * 0.02));
    });
  });

  group('touching the ground through the camera', () {
    test('what goes out comes back: bearing and distance survive a round trip',
        () {
      final p = level(heading: 120);
      for (final bearing in [100.0, 120.0, 145.0]) {
        for (final distance in [15.0, 60.0, 400.0]) {
          final onScreen = p.groundPoint(bearing, distance);
          final back = p.groundAt(onScreen);

          expect(back, isNotNull,
              reason: 'ground at $bearing/$distance should be recoverable');
          expect(back!.bearingDeg, closeTo(bearing, 0.5));
          // Further away, a pixel covers more ground, so allow proportional
          // slack rather than a fixed number of metres.
          expect(back.distanceM, closeTo(distance, distance * 0.02));
        }
      }
    });

    test('nothing on or above the horizon has a ground position', () {
      final p = level();
      expect(p.groundAt(Offset(size.width / 2, p.horizonY)), isNull);
      expect(p.groundAt(Offset(size.width / 2, p.horizonY - 50)), isNull);
      expect(p.groundAt(const Offset(100, 0)), isNull);
    });

    test('lower on screen is closer to you', () {
      final p = level();
      final near = p.groundAt(Offset(size.width / 2, size.height * 0.95))!;
      final far = p.groundAt(Offset(size.width / 2, p.horizonY + 60))!;
      expect(near.distanceM, lessThan(far.distanceM));
    });

    test('touching left of centre gives a bearing left of where you face', () {
      final p = level(heading: 90);
      final left = p.groundAt(Offset(size.width * 0.2, size.height * 0.8))!;
      final right = p.groundAt(Offset(size.width * 0.8, size.height * 0.8))!;
      expect(left.bearingDeg, lessThan(90));
      expect(right.bearingDeg, greaterThan(90));
    });

    test('just under the horizon is capped rather than running to infinity',
        () {
      final p = level();
      final sliver = p.groundAt(Offset(size.width / 2, p.horizonY + 0.5),
          maxDistanceM: 5000)!;
      expect(sliver.distanceM, lessThanOrEqualTo(5000));
      expect(sliver.distanceM.isFinite, isTrue);
    });

    test('the bearing stays a valid compass reading across north', () {
      final p = level(heading: 5);
      final left = p.groundAt(Offset(size.width * 0.1, size.height * 0.8))!;
      expect(left.bearingDeg, greaterThanOrEqualTo(0));
      expect(left.bearingDeg, lessThan(360));
    });
  });

  group('roll', () {
    ArProjection rolled(double rollDeg, {double heading = 0, double pitch = 0}) =>
        ArProjection(
          size: size,
          headingDeg: heading,
          pitchRad: pitch,
          rollRad: rollDeg * math.pi / 180,
        );

    test('a degree is worth the same pixels across as it is down', () {
      // What makes the roll correction legitimate. Rotating a position in
      // pixel space only matches rotating it in angle space while these two
      // agree; if the fields of view are ever set independently the
      // correction starts quietly skewing every marker instead.
      final p = level();
      expect(p.scaleX, closeTo(p.scaleY, 0.001));
    });

    test('holding the phone square changes nothing', () {
      final square = level(heading: 90);
      final p = rolled(0, heading: 90);
      expect(p.project(110, 200), equals(square.groundPoint(110, 200)));
    });

    test('a marker keeps its distance from the centre of the image', () {
      // Roll turns the frame; it does not move anything nearer or further
      // from the lens axis. A marker that drifted in or out would be sliding
      // off its feature.
      final centre = Offset(size.width / 2, size.height / 2);
      final square = level(heading: 90).groundPoint(105, 300);
      final was = (square - centre).distance;

      for (final r in [15.0, -25.0, 60.0, -80.0]) {
        final now = (rolled(r, heading: 90).project(105, 300) - centre).distance;
        expect(now, closeTo(was, 0.01),
            reason: 'rolled $r degrees, the marker moved radially');
      }
    });

    test('rolling clockwise swings the scene the other way', () {
      // A marker straight ahead sits below the centre, on the middle line.
      // Tip the top of the phone to the right and the image turns
      // anticlockwise, which carries the bottom of the frame rightwards — so
      // the marker moves right, against the phone, and stays on its tree.
      final p = rolled(30, heading: 90);
      final at = p.project(90, 50);
      expect(at.dx, greaterThan(size.width / 2),
          reason: 'a clockwise roll should push a marker ahead of you right');

      final other = rolled(-30, heading: 90).project(90, 50);
      expect(other.dx, lessThan(size.width / 2));
    });

    test('the correction is undone exactly, so a tilted pin drop still lands '
        'where it was aimed', () {
      // The three-second hold reads the ground through the same maths in
      // reverse. Before the roll went into the projection, a pin dropped with
      // the phone held at an angle landed off to one side of the thing on
      // screen.
      for (final r in [0.0, 12.0, -35.0, 55.0]) {
        final p = rolled(r, heading: 200, pitch: -12 * math.pi / 180);
        for (final bearing in [185.0, 200.0, 215.0]) {
          for (final distance in [20.0, 90.0, 500.0]) {
            final onScreen = p.project(bearing, distance);
            final back = p.groundAt(onScreen);
            expect(back, isNotNull, reason: 'roll $r lost $bearing/$distance');
            expect(back!.bearingDeg, closeTo(bearing, 0.5));
            expect(back.distanceM, closeTo(distance, distance * 0.02));
          }
        }
      }
    });
  });

  group('pointing at the sky or at your boots', () {
    test('an extreme pitch still produces real numbers', () {
      // tan(90 degrees) is infinite. Without a clamp the horizon, and every
      // marker measured from it, becomes infinity or NaN — and the overlay
      // either vanishes or draws in nonsense places.
      for (final deg in [-89.9, -90.0, -120.0, 89.9, 90.0, 150.0]) {
        final p = ArProjection(
          size: size,
          headingDeg: 40,
          pitchRad: deg * math.pi / 180,
          rollRad: 0.4,
        );
        expect(p.horizonY.isFinite, isTrue, reason: 'horizon at $deg pitch');
        final at = p.project(40, 120);
        expect(at.dx.isFinite, isTrue, reason: 'x at $deg pitch');
        expect(at.dy.isFinite, isTrue, reason: 'y at $deg pitch');
      }
    });
  });

  group('apparent size', () {
    test('the same object shrinks with distance', () {
      final p = level();
      final near = p.apparentWidth(3, 20);
      final far = p.apparentWidth(3, 2000);
      expect(far, lessThan(near / 10));
    });

    test('nothing divides by zero at zero distance', () {
      final p = level();
      expect(p.apparentWidth(3, 0).isFinite, isTrue);
      expect(p.screenY(0).isFinite, isTrue);
    });
  });
}
