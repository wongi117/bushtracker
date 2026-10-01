// The reported bug: driving at 61 km/h along a road running ENE, the arrow
// still pointed north. These cover the logic that decides which way it should
// point — course while moving, compass while stopped, and no flapping between
// the two at the changeover.
import 'package:bush_track/features/map/services/locate_mode.dart';
import 'package:bush_track/features/map/services/travel_heading.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const dt = 1 / 5; // fixes arrive a few times a second

  /// Run the same reading in until the filter settles on it.
  double? settle(
    TravelHeading th, {
    required double speedMs,
    double? course,
    double? compass,
    int ticks = 40,
  }) {
    double? out;
    for (var i = 0; i < ticks; i++) {
      out = th.update(
          speedMs: speedMs, dt: dt, gpsCourseDeg: course, compassDeg: compass);
    }
    return out;
  }

  group('moving', () {
    test('at 61 km/h the arrow follows the road, not north', () {
      // The exact case from the field: 61 km/h, road running ENE.
      final th = TravelHeading();
      final out = settle(th, speedMs: 61 / 3.6, course: 67.5, compass: 0);
      expect(out, isNotNull);
      expect(out!, closeTo(67.5, 2),
          reason: 'should point along the road, not at north');
      expect(th.fromCourse, isTrue);
    });

    test('the course wins over a compass pointing somewhere else', () {
      // A phone in a cradle points at the windscreen, which is not where the
      // vehicle is going.
      final th = TravelHeading();
      final out = settle(th, speedMs: 20, course: 90, compass: 300);
      expect(out!, closeTo(90, 2));
    });

    test('every direction is followed, not just the easy ones', () {
      for (final bearing in [0.0, 45.0, 135.0, 225.0, 315.0, 359.0]) {
        final th = TravelHeading();
        final out = settle(th, speedMs: 15, course: bearing, compass: 180);
        var error = (out! - bearing).abs();
        if (error > 180) error = 360 - error;
        expect(error, lessThan(2), reason: 'course $bearing came back as $out');
      }
    });
  });

  group('stopped', () {
    test('a standstill uses the compass, not the course', () {
      // Standing still the course is whatever the last metre of noise pointed
      // at, which is what made the arrow spin.
      final th = TravelHeading();
      final out = settle(th, speedMs: 0, course: 12, compass: 270);
      expect(out!, closeTo(270, 2));
      expect(th.fromCourse, isFalse);
    });

    test('walking pace still uses the compass', () {
      final th = TravelHeading();
      final out = settle(th, speedMs: 0.5, course: 12, compass: 270);
      expect(out!, closeTo(270, 2));
    });

    test('declination is added to the compass but never to the course', () {
      // A compass reads magnetic; the GPS course is already true.
      final still = TravelHeading();
      var out = 0.0;
      for (var i = 0; i < 40; i++) {
        out = still.update(
            speedMs: 0, dt: dt, compassDeg: 100, declinationDeg: 8)!;
      }
      expect(out, closeTo(108, 2));

      final moving = TravelHeading();
      for (var i = 0; i < 40; i++) {
        out = moving.update(
            speedMs: 20,
            dt: dt,
            gpsCourseDeg: 100,
            compassDeg: 100,
            declinationDeg: 8)!;
      }
      expect(out, closeTo(100, 2), reason: 'the course must not be shifted');
    });
  });

  group('the changeover does not flap', () {
    test('it takes more speed to start trusting the course than to keep it', () {
      final th = TravelHeading();

      // Crawling: compass.
      th.update(speedMs: 1.0, dt: dt, gpsCourseDeg: 10, compassDeg: 200);
      expect(th.fromCourse, isFalse);

      // Over the line: course.
      th.update(speedMs: 1.5, dt: dt, gpsCourseDeg: 10, compassDeg: 200);
      expect(th.fromCourse, isTrue);

      // Back below the upper threshold but above the lower one: still course,
      // which is the whole point — one threshold would swap sources here.
      th.update(speedMs: 1.0, dt: dt, gpsCourseDeg: 10, compassDeg: 200);
      expect(th.fromCourse, isTrue);

      // Properly stopped: compass again.
      th.update(speedMs: 0.3, dt: dt, gpsCourseDeg: 10, compassDeg: 200);
      expect(th.fromCourse, isFalse);
    });

    test('hovering at the changeover speed does not swap every tick', () {
      final th = TravelHeading();
      th.update(speedMs: 2, dt: dt, gpsCourseDeg: 10, compassDeg: 200);

      var swaps = 0;
      var was = th.fromCourse;
      // Jittering around 5 km/h, as a speed reading does.
      for (final s in [1.3, 1.5, 1.2, 1.45, 1.1, 1.5, 1.35, 1.2]) {
        th.update(speedMs: s, dt: dt, gpsCourseDeg: 10, compassDeg: 200);
        if (th.fromCourse != was) swaps++;
        was = th.fromCourse;
      }
      expect(swaps, 0, reason: 'the source should hold through speed jitter');
    });
  });

  group('noisy and missing readings', () {
    test('a jittery course at low speed does not spin the arrow', () {
      // Stationary GPS course flails through the whole dial. The compass is
      // what should be showing, steadily.
      final th = TravelHeading();
      final courses = [10.0, 190.0, 95.0, 300.0, 25.0, 170.0, 350.0];
      double? out;
      for (var i = 0; i < 40; i++) {
        out = th.update(
            speedMs: 0.2,
            dt: dt,
            gpsCourseDeg: courses[i % courses.length],
            compassDeg: 80);
      }
      expect(out!, closeTo(80, 3));
    });

    test('a steady turn is followed without lagging far behind', () {
      final th = TravelHeading();
      var course = 0.0;
      double? out;
      // Swinging round a bend at 60 degrees a second.
      for (var i = 0; i < 25; i++) {
        course += 60 * dt;
        out = th.update(speedMs: 15, dt: dt, gpsCourseDeg: course % 360);
      }
      var error = (out! - (course % 360)).abs();
      if (error > 180) error = 360 - error;
      expect(error, lessThan(15));
    });

    test('no sensors at all gives no answer rather than north', () {
      final th = TravelHeading();
      expect(th.update(speedMs: 0, dt: dt), isNull);
      expect(th.degrees, isNull);
    });

    test('moving with no compass still uses the course', () {
      final th = TravelHeading();
      final out = settle(th, speedMs: 20, course: 150);
      expect(out!, closeTo(150, 2));
    });

    test('losing the compass holds the last answer instead of jumping', () {
      final th = TravelHeading();
      settle(th, speedMs: 0, compass: 90);
      final before = th.degrees;
      final after = th.update(speedMs: 0, dt: dt);
      expect(after, before);
    });

    test('the answer is always a valid bearing', () {
      final th = TravelHeading();
      for (var i = 0; i < 200; i++) {
        final out = th.update(
            speedMs: i % 7, dt: dt, gpsCourseDeg: (i * 37) % 360, compassDeg: 5);
        expect(out!, greaterThanOrEqualTo(0));
        expect(out, lessThan(360));
      }
    });

    test('crossing north does not swing the long way round', () {
      final th = TravelHeading();
      settle(th, speedMs: 20, course: 355);
      double? out;
      for (var i = 0; i < 10; i++) {
        out = th.update(speedMs: 20, dt: dt, gpsCourseDeg: 5);
      }
      final fromNorth = out! < 180 ? out : 360 - out;
      expect(fromNorth, lessThan(25), reason: 'ended at $out, not near north');
    });
  });

  group('magnetic declination', () {
    test('it grows eastwards across the country', () {
      final perth = MagneticDeclination.forPosition(-31.95, 115.86);
      final sydney = MagneticDeclination.forPosition(-33.87, 151.21);
      expect(sydney, greaterThan(perth));
    });

    test('the Goldfields figure is small, as it should be', () {
      // Leonora. A degree or two, which is inside the handset compass's own
      // wander — worth correcting, not worth agonising over.
      final leonora = MagneticDeclination.forPosition(-28.88, 121.33);
      expect(leonora, greaterThan(0));
      expect(leonora, lessThan(5));
    });

    test('outside Australia it declines to guess', () {
      expect(MagneticDeclination.forPosition(51.5, -0.12), 0);
      expect(MagneticDeclination.forPosition(40.7, -74.0), 0);
    });
  });

  group('the locate button cycle', () {
    test('tapping walks through centre, follow, heading up', () {
      expect(LocateMode.off.next, LocateMode.centred);
      expect(LocateMode.centred.next, LocateMode.follow);
      expect(LocateMode.follow.next, LocateMode.headingUp);
    });

    test('tapping again comes back to north up, still following', () {
      expect(LocateMode.headingUp.next, LocateMode.follow);
      expect(LocateMode.follow.isFollowing, isTrue);
      expect(LocateMode.follow.rotatesMap, isFalse);
    });

    test('only the two follow modes pull the map back', () {
      expect(LocateMode.off.isFollowing, isFalse);
      expect(LocateMode.centred.isFollowing, isFalse);
      expect(LocateMode.follow.isFollowing, isTrue);
      expect(LocateMode.headingUp.isFollowing, isTrue);
    });

    test('only heading up turns the map', () {
      expect(LocateMode.headingUp.rotatesMap, isTrue);
      for (final m in [LocateMode.off, LocateMode.centred, LocateMode.follow]) {
        expect(m.rotatesMap, isFalse);
      }
    });

    test('dragging the map stops it following', () {
      expect(LocateMode.follow.afterPan, LocateMode.centred);
      expect(LocateMode.headingUp.afterPan, LocateMode.centred);
    });

    test('dragging when not following changes nothing', () {
      expect(LocateMode.off.afterPan, LocateMode.off);
      expect(LocateMode.centred.afterPan, LocateMode.centred);
    });

    test('and the next tap after a drag goes straight back to following', () {
      expect(LocateMode.follow.afterPan.next, LocateMode.follow);
    });

    test('every mode has its own icon and its own words', () {
      final icons = LocateMode.values.map((m) => m.icon).toSet();
      expect(icons, hasLength(LocateMode.values.length));
      final labels = LocateMode.values.map((m) => m.label).toSet();
      expect(labels, hasLength(LocateMode.values.length));
    });
  });
}
