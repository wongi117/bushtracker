// The bug these exist for: the textbook azimuth is the bearing of the phone's
// TOP EDGE, and when you hold a phone up to look through its camera the top
// edge points at the sky. Its horizontal projection is nearly nothing, so the
// azimuth is atan2 of two near-zero noisy numbers and stops tracking the turn —
// which is why AR markers travelled along with the camera rather than staying
// on their feature.
//
// So these build sensor readings for handset positions with a known answer, and
// check that the camera bearing comes back right at every one.
import 'dart:math' as math;

import 'package:bush_track/core/services/heading/magnetic_bearing.dart';
import 'package:flutter_test/flutter_test.dart';

/// World frame: x east, y north, z up.
typedef Vec = ({double x, double y, double z});

Vec _v(double x, double y, double z) => (x: x, y: y, z: z);
double _dot(Vec a, Vec b) => a.x * b.x + a.y * b.y + a.z * b.z;
Vec _scale(Vec a, double k) => _v(a.x * k, a.y * k, a.z * k);
Vec _add(Vec a, Vec b) => _v(a.x + b.x, a.y + b.y, a.z + b.z);

/// The accelerometer and magnetometer a handset would report when its lens is
/// pointed at [bearingDeg], raised [pitchDeg] above level, and the handset is
/// rolled [rollDeg] clockwise.
///
/// Built from the world frame down, independently of the code under test, so
/// agreement means something.
({List<double> accel, List<double> mag}) sensors({
  required double bearingDeg,
  double pitchDeg = 0,
  double rollDeg = 0,
  // Leonora is deep in the southern hemisphere, where the field tilts upward.
  double inclinationDeg = -64,
}) {
  final b = bearingDeg * math.pi / 180;
  final p = pitchDeg * math.pi / 180;
  final r = rollDeg * math.pi / 180;
  final inc = inclinationDeg * math.pi / 180;

  // Where the lens points, and the handset axes that follow from it.
  final camera = _v(math.sin(b) * math.cos(p), math.cos(b) * math.cos(p), math.sin(p));
  final zd0 = _scale(camera, -1);
  // Top edge, before any roll: perpendicular to the lens in the vertical plane.
  final yd0 = _v(-math.sin(b) * math.sin(p), -math.cos(b) * math.sin(p), math.cos(p));
  // Right edge: ninety degrees clockwise of the bearing, on the level.
  final xd0 = _v(math.cos(b), -math.sin(b), 0);

  // Rolling turns x and y about the lens axis.
  final xd = _add(_scale(xd0, math.cos(r)), _scale(yd0, -math.sin(r)));
  final yd = _add(_scale(xd0, math.sin(r)), _scale(yd0, math.cos(r)));
  final zd = zd0;

  // An accelerometer at rest reads +g towards the sky.
  const up = (x: 0.0, y: 0.0, z: 1.0);
  // Field pointing north and, at a negative inclination, upwards.
  final field = _v(0, math.cos(inc) * 50, -math.sin(inc) * 50);

  return (
    accel: <double>[_dot(up, xd) * 9.81, _dot(up, yd) * 9.81, _dot(up, zd) * 9.81],
    mag: <double>[_dot(field, xd), _dot(field, yd), _dot(field, zd)],
  );
}

double offBy(double a, double b) {
  var d = (a - b) % 360;
  if (d > 180) d -= 360;
  if (d < -180) d += 360;
  return d.abs();
}

MagneticBearing read({
  required double bearingDeg,
  double pitchDeg = 0,
  double rollDeg = 0,
}) {
  final s = sensors(bearingDeg: bearingDeg, pitchDeg: pitchDeg, rollDeg: rollDeg);
  final out = MagneticBearing.from(accel: s.accel, mag: s.mag);
  expect(out, isNotNull, reason: 'these readings should give a bearing');
  return out!;
}

void main() {
  group('the lens bearing, held up to look through', () {
    test('pointing north reads north', () {
      expect(read(bearingDeg: 0).cameraAzimuthDeg, closeTo(0, 0.1));
    });

    test('the four quarters come back right', () {
      for (final b in [0.0, 90.0, 180.0, 270.0]) {
        expect(read(bearingDeg: b).cameraAzimuthDeg, closeTo(b, 0.1),
            reason: 'lens pointed at $b');
      }
    });

    test('every bearing all the way round', () {
      for (var b = 0.0; b < 360; b += 7.5) {
        expect(offBy(read(bearingDeg: b).cameraAzimuthDeg, b), lessThan(0.1),
            reason: 'lens pointed at $b');
      }
    });

    test('turning right increases the bearing', () {
      // The direction that matters. If this ran backwards, markers would move
      // with the camera at twice the rate — worse than not moving at all.
      final from = read(bearingDeg: 100).cameraAzimuthDeg;
      final to = read(bearingDeg: 130).cameraAzimuthDeg;
      expect(to, greaterThan(from));
      expect(to - from, closeTo(30, 0.2));
    });

    test('tilting and rolling do not move it', () {
      // Nothing about how you hold the handset changes where the lens is
      // aimed, so nothing about how you hold it may change this bearing.
      const aimed = 215.0;
      for (final p in [-60.0, -30.0, 0.0, 30.0, 60.0]) {
        for (final r in [-70.0, -20.0, 0.0, 20.0, 70.0]) {
          expect(
              offBy(read(bearingDeg: aimed, pitchDeg: p, rollDeg: r)
                  .cameraAzimuthDeg,
                  aimed),
              lessThan(0.1),
              reason: 'aimed at $aimed, held at pitch $p roll $r');
        }
      }
    });
  });

  group('why the old azimuth could not do this job', () {
    test('the top edge bearing is useless when held upright', () {
      // Upright, the top edge points at the sky and its bearing is noise. This
      // is not a bug in the formula — it is the formula being asked a question
      // with no answer, which is why the AR overlay needed a different one.
      final s = sensors(bearingDeg: 0, pitchDeg: 0);
      final clean = MagneticBearing.from(accel: s.accel, mag: s.mag)!;

      // A whisper of sensor noise, far less than a real phone produces.
      final noisy = MagneticBearing.from(
        accel: <double>[s.accel[0] + 0.02, s.accel[1], s.accel[2] + 0.02],
        mag: <double>[s.mag[0] + 0.05, s.mag[1], s.mag[2] + 0.05],
      )!;

      // The lens bearing barely notices.
      expect(offBy(clean.cameraAzimuthDeg, noisy.cameraAzimuthDeg),
          lessThan(1.0));
      // The top edge bearing swings wildly on the same input.
      expect(offBy(clean.topAzimuthDeg, noisy.topAzimuthDeg), greaterThan(10),
          reason: 'if this is stable, the premise of the fix is wrong');
    });

    test('but it is the right answer with the phone flat, like a map', () {
      // Which is why it is kept for the compass rose. Lens almost straight
      // down, top edge lying along the ground pointing where you face.
      for (final b in [0.0, 75.0, 200.0, 310.0]) {
        final r = read(bearingDeg: b, pitchDeg: -88);
        expect(offBy(r.topAzimuthDeg, b), lessThan(0.5),
            reason: 'flat, facing $b');
        // And there the lens bearing is the one that has given up.
        expect(r.cameraUsable, isFalse);
      }
    });
  });

  group('when to believe the lens bearing', () {
    test('usable through the whole range you would hold it at', () {
      for (final p in [-70.0, -45.0, -20.0, 0.0, 20.0, 45.0, 70.0]) {
        expect(read(bearingDeg: 30, pitchDeg: p).cameraUsable, isTrue,
            reason: 'pitch $p is a normal way to hold a phone');
      }
    });

    test('not usable pointed at your boots or straight up', () {
      expect(read(bearingDeg: 30, pitchDeg: -88).cameraUsable, isFalse);
      expect(read(bearingDeg: 30, pitchDeg: 89).cameraUsable, isFalse);
    });
  });

  group('bad input', () {
    test('free fall gives nothing', () {
      expect(
          MagneticBearing.from(
              accel: <double>[0, 0, 0], mag: <double>[0, 30, -40]),
          isNull);
    });

    test('no measurable field gives nothing', () {
      expect(
          MagneticBearing.from(
              accel: <double>[0, 9.81, 0], mag: <double>[0, 0, 0]),
          isNull);
    });

    test('a field parallel to gravity gives nothing', () {
      // Standing on the magnetic pole, or next to something that looks like it.
      expect(
          MagneticBearing.from(
              accel: <double>[0, 9.81, 0], mag: <double>[0, 48, 0]),
          isNull);
    });

    test('field strength is reported as measured', () {
      final s = sensors(bearingDeg: 10);
      expect(MagneticBearing.from(accel: s.accel, mag: s.mag)!.fieldStrengthUt,
          closeTo(50, 0.01));
    });

    test('both bearings are always valid compass readings', () {
      for (var b = 0.0; b < 360; b += 13) {
        for (final p in [-80.0, -25.0, 15.0, 70.0]) {
          final r = read(bearingDeg: b, pitchDeg: p, rollDeg: 35);
          expect(r.cameraAzimuthDeg, greaterThanOrEqualTo(0));
          expect(r.cameraAzimuthDeg, lessThan(360));
          expect(r.topAzimuthDeg, greaterThanOrEqualTo(0));
          expect(r.topAzimuthDeg, lessThan(360));
        }
      }
    });
  });
}
