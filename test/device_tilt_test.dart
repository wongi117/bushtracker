// The AR overlay's accuracy rests on these two angles, and a wrong sign does
// not read as "slightly off" — it reads as markers leaning with the phone
// instead of against it, and a horizon that flies off the screen when you
// tilt. None of that is visible by reading the code, so it gets pinned down
// here against handset positions you can hold in your hand and check.
import 'dart:math' as math;

import 'package:bush_track/core/services/heading/device_tilt.dart';
import 'package:flutter_test/flutter_test.dart';

/// The gravity an accelerometer reads with the camera [pitchDeg] above level
/// and the handset rolled [rollDeg] clockwise from portrait.
///
/// Derived from the definitions, not from the implementation, so that a round
/// trip through [DeviceTilt.fromGravity] is a real check rather than the same
/// arithmetic twice: the "up" direction in device axes is
/// (-cos p sin r, cos p cos r, -sin p).
({double x, double y, double z}) gravity({
  double pitchDeg = 0,
  double rollDeg = 0,
}) {
  const g = 9.81;
  final p = pitchDeg * math.pi / 180;
  final r = rollDeg * math.pi / 180;
  return (
    x: -g * math.cos(p) * math.sin(r),
    y: g * math.cos(p) * math.cos(r),
    z: -g * math.sin(p),
  );
}

double deg(double rad) => rad * 180 / math.pi;

void main() {
  DeviceTilt read({double pitchDeg = 0, double rollDeg = 0}) {
    final a = gravity(pitchDeg: pitchDeg, rollDeg: rollDeg);
    final tilt = DeviceTilt.fromGravity(a.x, a.y, a.z);
    expect(tilt, isNotNull, reason: 'gravity of that size must be readable');
    return tilt!;
  }

  group('positions you can check by holding the phone', () {
    test('upright portrait, camera at the horizon, is level and square', () {
      final tilt = read();
      expect(deg(tilt.pitchRad), closeTo(0, 0.01));
      expect(deg(tilt.rollRad), closeTo(0, 0.01));
    });

    test('flat on its back points the camera at the ground', () {
      // Face up on a bonnet: gravity entirely on z.
      final tilt = DeviceTilt.fromGravity(0, 0, 9.81)!;
      expect(deg(tilt.pitchRad), closeTo(-90, 0.01));
    });

    test('face down points the camera at the sky', () {
      final tilt = DeviceTilt.fromGravity(0, 0, -9.81)!;
      expect(deg(tilt.pitchRad), closeTo(90, 0.01));
    });

    test('tipping the top of the phone right is a positive roll', () {
      // Clockwise as you look at the screen. The right edge drops, so the
      // device x axis tilts downwards and "up" gains a negative x.
      expect(read(rollDeg: 30).rollRad, greaterThan(0));
      expect(read(rollDeg: -30).rollRad, lessThan(0));
    });

    test('tilting the camera up is a positive pitch', () {
      expect(read(pitchDeg: 25).pitchRad, greaterThan(0));
      expect(read(pitchDeg: -25).pitchRad, lessThan(0));
    });
  });

  group('pitch and roll do not contaminate each other', () {
    test('every combination comes back as it went in', () {
      for (final p in [-60.0, -30.0, -5.0, 0.0, 5.0, 30.0, 60.0]) {
        for (final r in [-80.0, -45.0, -10.0, 0.0, 10.0, 45.0, 80.0]) {
          final tilt = read(pitchDeg: p, rollDeg: r);
          expect(deg(tilt.pitchRad), closeTo(p, 0.01),
              reason: 'pitch $p with roll $r came back as '
                  '${deg(tilt.pitchRad).toStringAsFixed(2)}');
          expect(deg(tilt.rollRad), closeTo(r, 0.01),
              reason: 'roll $r with pitch $p came back as '
                  '${deg(tilt.rollRad).toStringAsFixed(2)}');
        }
      }
    });

    test('rolling the phone does not change the pitch', () {
      // This is the one that matters. The old code took pitch as
      // atan2(-z, y), which is only right at zero roll: as y shrinks the
      // answer runs away towards 90 degrees, and the horizon — with every
      // marker measured from it — leaves the screen while the camera has not
      // moved off the thing you are pointing at.
      const held = 15.0;
      final square = read(pitchDeg: held).pitchRad;
      for (final r in [20.0, 45.0, 70.0, 85.0, -45.0, -85.0]) {
        expect(deg(read(pitchDeg: held, rollDeg: r).pitchRad),
            closeTo(deg(square), 0.01),
            reason: 'pitch moved when the phone was rolled $r degrees');
      }
    });
  });

  group('when the numbers stop meaning anything', () {
    test('free fall has no answer at all', () {
      expect(DeviceTilt.fromGravity(0, 0, 0), isNull);
      expect(DeviceTilt.fromGravity(0.01, 0.02, 0.01), isNull);
    });

    test('flat on its back, roll is not measurable', () {
      // x and y are both noise here, and atan2 of noise over noise walks the
      // whole dial — which spun the overlay while the phone sat still.
      expect(DeviceTilt.fromGravity(0.02, -0.03, 9.81)!.rollMeasurable,
          isFalse);
    });

    test('held up to look at, roll is measurable', () {
      expect(read(pitchDeg: 0).rollMeasurable, isTrue);
      expect(read(pitchDeg: -30).rollMeasurable, isTrue);
      expect(read(pitchDeg: 45, rollDeg: 20).rollMeasurable, isTrue);
    });

    test('a short vector still normalises rather than blowing up', () {
      final tilt = DeviceTilt.fromGravity(0, 0.5, 0);
      expect(tilt, isNotNull);
      expect(tilt!.pitchRad, closeTo(0, 0.01));
    });
  });
}
