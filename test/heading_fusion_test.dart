// The magnetometer on its own cannot follow a fast turn, which is why AR
// markers slid along with the camera through a 360 and only settled once the
// phone stopped. These check that the gyro actually carries the movement, that
// the magnetometer still owns where north is, and that the sign conventions
// line up — a yaw rate with the wrong sign would make markers move twice as
// fast the wrong way, which is worse than the lag it replaced.
import 'dart:math' as math;

import 'package:bush_track/core/services/heading/heading_fusion.dart';
import 'package:bush_track/core/services/heading/heading_reading.dart';
import 'package:bush_track/core/services/heading/one_euro_filter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const dt = 1 / 50;

  double offBy(double a, double b) => HeadingReading.delta(a, b).abs();

  group('yaw rate from the gyroscope', () {
    test('a phone flat on its back turns about its own z axis', () {
      // Up is device +z. Anticlockwise seen from above is positive on the gyro
      // and *decreases* a compass bearing, so the sign has to flip.
      final rate = HeadingFusion.yawRateFromGyro(
          gx: 0, gy: 0, gz: 1, upX: 0, upY: 0, upZ: 1);
      expect(rate, closeTo(-180 / math.pi, 0.01));
    });

    test('held upright, the turn is about the y axis instead', () {
      // Up is device +y when the phone is held to look at.
      final rate = HeadingFusion.yawRateFromGyro(
          gx: 0, gy: 1, gz: 0, upX: 0, upY: 1, upZ: 0);
      expect(rate, closeTo(-180 / math.pi, 0.01));
    });

    test('rotation across the vertical does not change the bearing', () {
      // Tipping the phone forwards is rotation about its x axis, which is at
      // right angles to gravity when held upright: no change of heading.
      final rate = HeadingFusion.yawRateFromGyro(
          gx: 2, gy: 0, gz: 0, upX: 0, upY: 1, upZ: 0);
      expect(rate, closeTo(0, 0.01));
    });
  });

  group('following a turn', () {
    test('a fast sweep is tracked without dragging behind', () {
      // The symptom, as a number. A 250 deg/s whip, with the magnetometer
      // modelled as it actually behaves once the source stops over-smoothing
      // it: prompt to within a couple of samples, and noisy.
      //
      // The lesson that produced this test: a complementary filter cannot undo
      // lag that is already in its reference. During a steady turn the fused
      // bearing settles wherever the magnetometer says it is, so the reference
      // has to be kept prompt — see _magSmoothing in heading_source_native.
      final fused = HeadingFusion();
      final reference = OneEuroAngleFilter();
      final noise = math.Random(4);
      final history = <double>[];

      var truth = 0.0;
      fused.update(dt: dt, yawRateDegPerSec: 0, magneticHeadingDeg: 0);

      var worstFused = 0.0;
      var worstMagOnly = 0.0;
      for (var i = 0; i < 100; i++) {
        truth += 250 * dt;
        history.add(truth);

        final laggedIndex = history.length - 2;
        final magnetic = HeadingReading.normalize(
            (laggedIndex < 0 ? 0.0 : history[laggedIndex]) +
                (noise.nextDouble() - 0.5) * 6);

        final out = fused.update(
          dt: dt,
          yawRateDegPerSec: 250,
          magneticHeadingDeg: magnetic,
        );
        // What the magnetometer alone gives, smoothed enough to be watchable.
        final magOnly = reference.filter(magnetic, dt);

        if (i > 20) {
          final want = HeadingReading.normalize(truth);
          worstFused = math.max(worstFused, offBy(out, want));
          worstMagOnly = math.max(worstMagOnly, offBy(magOnly, want));
        }
      }

      expect(worstFused, lessThan(8),
          reason: 'fused bearing was $worstFused degrees out during a whip');
      // The point of the exercise: better than the magnetometer on its own.
      expect(worstFused, lessThan(worstMagOnly),
          reason: 'fused $worstFused vs magnetometer alone $worstMagOnly — '
              'the gyro is meant to be an improvement');
    });

    test('a full 360 comes back to where it started', () {
      final fusion = HeadingFusion();
      fusion.update(dt: dt, yawRateDegPerSec: 0, magneticHeadingDeg: 90);

      var truth = 90.0;
      for (var i = 0; i < 180; i++) {
        truth += 120 * dt; // two seconds for a full turn... twice
        fusion.update(
          dt: dt,
          yawRateDegPerSec: 120,
          magneticHeadingDeg: HeadingReading.normalize(truth),
        );
      }
      expect(offBy(fusion.heading!, HeadingReading.normalize(truth)),
          lessThan(5));
    });
  });

  group('holding still', () {
    test('magnetometer wander is largely filtered out', () {
      final fusion = HeadingFusion();
      final noise = math.Random(12);
      fusion.update(dt: dt, yawRateDegPerSec: 0, magneticHeadingDeg: 200);

      var worst = 0.0;
      for (var i = 0; i < 400; i++) {
        // Six degrees of wander, as logged off the phone on a bench.
        final out = fusion.update(
          dt: dt,
          yawRateDegPerSec: 0,
          magneticHeadingDeg: 200 + (noise.nextDouble() - 0.5) * 6,
        );
        if (i > 100) worst = math.max(worst, offBy(out, 200));
      }
      expect(worst, lessThan(1.0),
          reason: 'a still phone should not shimmer: was $worst degrees');
    });

    test('gyro bias creeps only a little before the magnetometer catches it', () {
      // Half a degree a second of bias, which is typical, and no real turning.
      final fusion = HeadingFusion();
      fusion.update(dt: dt, yawRateDegPerSec: 0, magneticHeadingDeg: 10);

      for (var i = 0; i < 500; i++) {
        fusion.update(dt: dt, yawRateDegPerSec: 0.5, magneticHeadingDeg: 10);
      }
      // Ten seconds of unchecked bias would be five degrees off.
      expect(offBy(fusion.heading!, 10), lessThan(1.0));
    });
  });

  group('degrading gracefully', () {
    test('without a gyroscope it is a plain smoother, not a break', () {
      final fusion = HeadingFusion();
      fusion.update(dt: dt, yawRateDegPerSec: 0, magneticHeadingDeg: 0);
      for (var i = 0; i < 300; i++) {
        fusion.update(dt: dt, yawRateDegPerSec: 0, magneticHeadingDeg: 75);
      }
      expect(offBy(fusion.heading!, 75), lessThan(1.0));
    });

    test('it coasts on the gyro when the magnetometer is not worth trusting',
        () {
      final fusion = HeadingFusion();
      fusion.update(dt: dt, yawRateDegPerSec: 0, magneticHeadingDeg: 0);
      // Walking past a vehicle: no usable field for a second, still turning.
      for (var i = 0; i < 50; i++) {
        fusion.update(dt: dt, yawRateDegPerSec: 90);
      }
      expect(fusion.heading!, closeTo(90, 1));
    });

    test('there is no bearing at all until the magnetometer speaks', () {
      // Starting at zero would mean drawing the world as though facing north.
      final fusion = HeadingFusion();
      fusion.update(dt: dt, yawRateDegPerSec: 40);
      expect(fusion.heading, isNull);

      fusion.update(dt: dt, yawRateDegPerSec: 40, magneticHeadingDeg: 123);
      expect(fusion.heading, closeTo(123, 0.001));
    });

    test('the output is always a valid bearing', () {
      final fusion = HeadingFusion();
      final noise = math.Random(8);
      fusion.update(dt: dt, yawRateDegPerSec: 0, magneticHeadingDeg: 0);
      for (var i = 0; i < 500; i++) {
        final out = fusion.update(
          dt: dt,
          yawRateDegPerSec: (noise.nextDouble() - 0.5) * 600,
          magneticHeadingDeg: noise.nextDouble() * 360,
        );
        expect(out, greaterThanOrEqualTo(0));
        expect(out, lessThan(360));
      }
    });

    test('a silly dt does not blow it up', () {
      final fusion = HeadingFusion();
      fusion.update(dt: 0, yawRateDegPerSec: 0, magneticHeadingDeg: 45);
      final out = fusion.update(dt: -1, yawRateDegPerSec: 10, magneticHeadingDeg: 45);
      expect(out.isFinite, isTrue);
    });

    test('crossing north does not swing round the dial', () {
      final fusion = HeadingFusion();
      fusion.update(dt: dt, yawRateDegPerSec: 0, magneticHeadingDeg: 355);
      for (var i = 0; i < 40; i++) {
        final out =
            fusion.update(dt: dt, yawRateDegPerSec: 30, magneticHeadingDeg: 3);
        final fromNorth = math.min(out, 360 - out);
        expect(fromNorth, lessThan(25),
            reason: 'ended up at $out, nowhere near north');
      }
    });
  });
}
