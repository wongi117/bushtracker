// AR markers were shivering while the phone sat still. A plain exponential
// filter cannot fix that without adding lag when you turn, so these check the
// adaptive behaviour actually holds: steady when still, keeps up when moving,
// and sane across north.
import 'dart:math' as math;

import 'package:bush_track/core/services/heading/one_euro_filter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const dt = 1 / 50; // the sensors run at about 50 Hz

  group('holding still', () {
    test('noise is flattened out', () {
      final filter = OneEuroFilter();
      final noise = math.Random(7);

      var worst = 0.0;
      for (var i = 0; i < 200; i++) {
        // A true value of 100 with plus or minus 2 units of sensor noise.
        final reading = 100 + (noise.nextDouble() - 0.5) * 4;
        final out = filter.filter(reading, dt);
        if (i > 50) worst = math.max(worst, (out - 100).abs());
      }

      // Raw noise is up to 2; anything near that means no smoothing at all.
      expect(worst, lessThan(0.5),
          reason: 'a still signal should not wobble more than half a unit');
    });
  });

  group('moving', () {
    test('keeps up with a real turn instead of lagging behind', () {
      final filter = OneEuroFilter();
      var value = 0.0;
      double out = 0;

      // Turning at 90 units per second for a second.
      for (var i = 0; i < 50; i++) {
        value += 90 * dt;
        out = filter.filter(value, dt);
      }

      // Within a few units of the truth: visible lag would be much worse.
      expect((out - value).abs(), lessThan(6),
          reason: 'should track a steady turn closely');
    });

    test('a whipped turn is followed without a big excursion', () {
      // A 360 degree sweep is the hardest case for the overlay: at a 65 degree
      // field of view one degree is about sixteen pixels, so lag shows up as
      // markers sliding along with the camera. This holds the worst error over
      // a fast sweep from a standing start, which is where it peaks.
      //
      // Measured at 4.4 degrees at 120 deg/s and 7.1 at a 250 deg/s whip; the
      // tuning before this was 7.8 and 12.5. The bound is set above the
      // measurement, not at it, so ordinary noise does not fail the build.
      final filter = OneEuroFilter();
      final noise = math.Random(5);

      // Settled and standing still first, which is the state you start a turn
      // from.
      var value = 0.0;
      for (var i = 0; i < 50; i++) {
        filter.filter(value + (noise.nextDouble() - 0.5) * 4, dt);
      }

      var worst = 0.0;
      for (var i = 0; i < 25; i++) {
        value += 250 * dt;
        final out = filter.filter(value + (noise.nextDouble() - 0.5) * 4, dt);
        worst = math.max(worst, (out - value).abs());
      }

      expect(worst, lessThan(10),
          reason: 'lagging $worst degrees through a sweep drags markers '
              'across the screen');
    });

    test('a slow deliberate pan is tracked closely', () {
      // The case a speed floor can quietly ruin: panning slowly to find a
      // waypoint is only a couple of dozen degrees a second, and if the floor
      // swallows that the filter never adapts and the lag is worse than it was
      // before any of this.
      final filter = OneEuroFilter();
      final noise = math.Random(9);
      var value = 0.0;
      for (var i = 0; i < 50; i++) {
        filter.filter(value + (noise.nextDouble() - 0.5) * 4, dt);
      }

      var worst = 0.0;
      for (var i = 0; i < 60; i++) {
        value += 25 * dt;
        final out = filter.filter(value + (noise.nextDouble() - 0.5) * 4, dt);
        worst = math.max(worst, (out - value).abs());
      }

      expect(worst, lessThan(4), reason: 'a slow pan should not lag');
    });

    test('adapts — a fast move is followed better than heavy smoothing', () {
      // Same filter, two signals: the still one should be damped far harder
      // than the moving one. That difference IS the adaptation.
      final still = OneEuroFilter();
      final moving = OneEuroFilter();
      final noise = math.Random(3);

      var stillWorst = 0.0;
      var value = 0.0;
      var movingError = 0.0;
      for (var i = 0; i < 100; i++) {
        final s = still.filter(50 + (noise.nextDouble() - 0.5) * 4, dt);
        if (i > 40) stillWorst = math.max(stillWorst, (s - 50).abs());

        value += 120 * dt;
        movingError = (moving.filter(value, dt) - value).abs();
      }

      expect(stillWorst, lessThan(0.5));
      expect(movingError, lessThan(8));
    });
  });

  group('bearings', () {
    test('crossing north does not swing all the way round the dial', () {
      final filter = OneEuroAngleFilter();
      // Walk from 355 up through north to 005.
      for (final deg in [355.0, 357.0, 359.0, 1.0, 3.0, 5.0]) {
        final out = filter.filter(deg, dt);
        // Must stay near north — a wrap bug parks it around 180.
        final fromNorth = math.min(out, 360 - out);
        expect(fromNorth, lessThan(20),
            reason: 'reading $deg produced $out, which is nowhere near north');
      }
    });

    test('output is always a valid bearing', () {
      final filter = OneEuroAngleFilter();
      final noise = math.Random(11);
      for (var i = 0; i < 300; i++) {
        final out = filter.filter(noise.nextDouble() * 360, dt);
        expect(out, greaterThanOrEqualTo(0));
        expect(out, lessThan(360));
      }
    });

    test('a steady spin is followed all the way round', () {
      final filter = OneEuroAngleFilter();
      var truth = 0.0;
      double out = 0;
      // Two full turns at 180 degrees a second.
      for (var i = 0; i < 200; i++) {
        truth += 180 * dt;
        out = filter.filter(truth % 360, dt);
      }
      final expected = truth % 360;
      var error = (out - expected).abs();
      if (error > 180) error = 360 - error;
      expect(error, lessThan(12));
    });
  });

  test('a reset forgets the previous signal', () {
    final filter = OneEuroFilter();
    for (var i = 0; i < 50; i++) {
      filter.filter(100, dt);
    }
    filter.reset();
    // First reading after a reset is taken at face value, not blended with
    // the old one.
    expect(filter.filter(5, dt), closeTo(5, 0.001));
  });
}
