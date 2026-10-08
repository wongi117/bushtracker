// Phase 4.5: zones standing up in AR. Hazard, heritage and "No entry" as tall
// no-go walls seen from a distance; every other boundary as a knee-high wall,
// and only within 20 m of it -- as asked for from the field.
import 'dart:math' as math;
import 'dart:ui';

import 'package:bush_track/core/models/geofence.dart';
import 'package:bush_track/features/ar/presentation/ar_wall_painter.dart';
import 'package:bush_track/features/ar/services/ar_projection.dart';
import 'package:bush_track/features/ar/services/ar_walls.dart';
import 'package:bush_track/features/ar/services/camera_optics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' hide Path;

void main() {
  const here = LatLng(-28.88, 121.33);
  LatLng at(double metres, double bearing) =>
      const Distance(roundResult: false).offset(here, metres, bearing);

  /// A square zone [half] metres from its centre to each side, centred
  /// [away] metres from here on [bearing].
  Geofence square(ZoneCategory category,
      {double away = 300, double bearing = 0, double half = 50, bool active = true}) {
    final c = at(away, bearing);
    LatLng corner(double b) =>
        const Distance(roundResult: false).offset(c, half * math.sqrt2, b);
    return Geofence.polygon(
      id: category.index,
      name: category.label,
      points: [corner(315), corner(45), corner(135), corner(225)],
      isActive: active,
      createdAt: DateTime(2026, 10, 8),
      category: category,
    );
  }

  ArProjection facing(double heading) => ArProjection(
        size: const Size(400, 800),
        headingDeg: heading,
        pitchRad: 0,
      );

  group('which zones are no-go', () {
    test('hazard, heritage and No entry', () {
      for (final c in [
        ZoneCategory.hazard,
        ZoneCategory.heritage,
        ZoneCategory.exclusion,
      ]) {
        expect(wallStyleFor(c), WallStyle.noGo, reason: c.label);
      }
    });

    test('everything else is a low wall', () {
      for (final c in [
        ZoneCategory.work,
        ZoneCategory.water,
        ZoneCategory.camp,
        ZoneCategory.survey,
      ]) {
        expect(wallStyleFor(c), WallStyle.low, reason: c.label);
      }
    });
  });

  group('a no-go zone', () {
    test('ahead: a wall, standing up, with its name', () {
      final w = buildArWalls(
          zones: [square(ZoneCategory.hazard)], here: here, projection: facing(0));
      expect(w.panels, isNotEmpty);
      for (final p in w.panels) {
        expect(p.topA.dy, lessThan(p.bottomA.dy), reason: 'tops above bottoms');
      }
      expect(w.labels.single.zone.name, 'Hazard');
      expect(w.labels.single.edgeDistanceM, closeTo(250, 2));
    });

    test('never drawn as a sliver, however far off', () {
      // Physically 30 m is ~36 px at 250 m and ~9 px at a kilometre on this
      // screen: not the wall you cannot miss. So it keeps a minimum height.
      for (final away in [300.0, 1000.0, 1400.0]) {
        final w = buildArWalls(
            zones: [square(ZoneCategory.heritage, away: away)],
            here: here,
            projection: facing(0));
        for (final p in w.panels) {
          expect(p.bottomA.dy - p.topA.dy,
              greaterThanOrEqualTo(WallSpec.noGoMinPixels - 1e-6),
              reason: '$away m');
        }
      }
    });

    test('and its true height close up', () {
      // Centre 60 m off, half-width 50: the near edge is 10 m away, where
      // 30 m stands far taller than the minimum.
      final near = buildArWalls(
              zones: [square(ZoneCategory.hazard, away: 60)],
              here: here,
              projection: facing(0))
          .panels
          .last;
      expect(near.bottomA.dy - near.topA.dy,
          greaterThan(WallSpec.noGoMinPixels * 2));
    });

    test('behind you: nothing drawn', () {
      final w = buildArWalls(
          zones: [square(ZoneCategory.hazard)],
          here: here,
          projection: facing(180));
      expect(w.panels, isEmpty);
    });

    test('beyond 1.5 km: not drawn', () {
      final w = buildArWalls(
          zones: [square(ZoneCategory.hazard, away: 2000)],
          here: here,
          projection: facing(0));
      expect(w.panels, isEmpty);
    });

    test('alerts switched off: not drawn', () {
      final w = buildArWalls(
          zones: [square(ZoneCategory.hazard, active: false)],
          here: here,
          projection: facing(0));
      expect(w.panels, isEmpty);
    });

    test('a circle zone gets a wall too', () {
      final bore = Geofence(
        name: 'shaft',
        latitude: at(200, 0).latitude,
        longitude: at(200, 0).longitude,
        radiusMeters: 40,
        isActive: true,
        createdAt: DateTime(2026, 10, 8),
        category: ZoneCategory.hazard,
      );
      expect(
          buildArWalls(zones: [bore], here: here, projection: facing(0)).panels,
          isNotEmpty);
    });
  });

  group('an ordinary boundary', () {
    test('more than 20 m from its edge: nothing', () {
      final w = buildArWalls(
          zones: [square(ZoneCategory.work, away: 80, half: 20)],
          here: here,
          projection: facing(0));
      expect(w.panels, isEmpty);
    });

    test('within 20 m: a low wall', () {
      // Centre 30 m north, half-width 20: the near edge is 10 m away.
      final w = buildArWalls(
          zones: [square(ZoneCategory.work, away: 30, half: 20)],
          here: here,
          projection: facing(0));
      expect(w.panels, isNotEmpty);
      expect(w.panels.every((p) => p.style == WallStyle.low), isTrue);
    });

    test('much lower than a no-go wall at the same place', () {
      double tallest(ZoneCategory c) => buildArWalls(
              zones: [square(c, away: 30, half: 20)],
              here: here,
              projection: facing(0))
          .panels
          .map((p) => p.bottomA.dy - p.topA.dy)
          .reduce(math.max);
      expect(tallest(ZoneCategory.work), lessThan(tallest(ZoneCategory.hazard) / 10));
    });
  });

  group('standing in a no-go zone', () {
    final hazard = square(ZoneCategory.hazard, away: 0, half: 200);

    test('is said with a good fix', () {
      final w = buildArWalls(
          zones: [hazard], here: here, projection: facing(0), accuracyM: 5);
      expect(w.insideNoGo.single.name, 'Hazard');
    });

    test('is not said with no idea of accuracy', () {
      final w = buildArWalls(
          zones: [hazard], here: here, projection: facing(0), accuracyM: 0);
      expect(w.insideNoGo, isEmpty);
    });

    test('is not said when the fix is looser than the distance to the edge', () {
      final w = buildArWalls(
          zones: [hazard], here: here, projection: facing(0), accuracyM: 500);
      expect(w.insideNoGo, isEmpty);
    });

    test('an ordinary zone never raises it', () {
      final w = buildArWalls(
          zones: [square(ZoneCategory.camp, away: 0, half: 200)],
          here: here,
          projection: facing(0),
          accuracyM: 5);
      expect(w.insideNoGo, isEmpty);
    });
  });

  group('tapping a wall', () {
    test('a tap on the wall finds its zone', () {
      final w = buildArWalls(
          zones: [square(ZoneCategory.hazard)], here: here, projection: facing(0));
      final p = w.panels.last;
      final middle = Offset(
          (p.bottomA.dx + p.bottomB.dx + p.topA.dx + p.topB.dx) / 4,
          (p.bottomA.dy + p.bottomB.dy + p.topA.dy + p.topB.dy) / 4);
      expect(wallAt(w, middle)?.name, 'Hazard');
    });

    test('a tap on open sky finds nothing', () {
      final w = buildArWalls(
          zones: [square(ZoneCategory.hazard)], here: here, projection: facing(0));
      expect(wallAt(w, const Offset(200, 20)), isNull);
    });
  });

  test('a big zone close by stays a manageable number of pieces', () {
    // A 3 km square no-go zone with its edge 30 m away: fine pieces near, long
    // ones far, nothing beyond 1.5 km. Every piece is a path per frame.
    final big = square(ZoneCategory.hazard, away: 1530, half: 1500);
    final w = buildArWalls(zones: [big], here: here, projection: facing(0));
    expect(w.panels, isNotEmpty);
    expect(w.panels.length, lessThan(600));
  });

  test('far panels come first, so near ones paint over them', () {
    final w = buildArWalls(
        zones: [square(ZoneCategory.hazard)], here: here, projection: facing(0));
    for (var i = 1; i < w.panels.length; i++) {
      expect(w.panels[i].distanceM, lessThanOrEqualTo(w.panels[i - 1].distanceM));
    }
  });

  test('with the phone rolled, the minimum height turns with the picture', () {
    // The minimum is "up" in the level frame; rolled, it must still measure
    // that tall along the wall, not just in screen y.
    const roll = 0.4; // about 23 degrees
    final w = buildArWalls(
        zones: [square(ZoneCategory.hazard, away: 1000)],
        here: here,
        projection: ArProjection(
            size: const Size(400, 800), headingDeg: 0, pitchRad: 0, rollRad: roll));
    expect(w.panels, isNotEmpty);
    for (final p in w.panels) {
      expect((p.bottomA - p.topA).distance,
          greaterThanOrEqualTo(WallSpec.noGoMinPixels - 1e-6));
    }
  });

  test('the painter draws both kinds of wall without throwing', () {
    final w = buildArWalls(
      zones: [
        square(ZoneCategory.heritage),
        square(ZoneCategory.camp, away: 30, half: 20),
      ],
      here: here,
      projection: facing(0),
    );
    expect(w.labels, hasLength(2));
    final recorder = PictureRecorder();
    ArWallPainter(w).paint(Canvas(recorder), const Size(400, 800));
    recorder.endRecording().dispose();
  });

  group('the look asked for', () {
    // A phone screen with the camera's real field of view, as the AR screen
    // now builds it.
    const phone = Size(411, 891);
    final real = CameraOptics.fallback.horizontalFovDegFor(phone, 16 / 9);
    ArProjection level() => ArProjection(
        size: phone, headingDeg: 0, pitchRad: 0, horizontalFovDeg: real);

    test('from 57 m, a large part of the screen', () {
      // Centre 107 m north, half-width 50: the near face 57 m away.
      final w = buildArWalls(
          zones: [square(ZoneCategory.hazard, away: 107)],
          here: here,
          projection: level());
      final near = w.panels.last;
      expect(near.distanceM, closeTo(57, 1));
      expect((near.bottomA.dy - near.topA.dy) / phone.height, greaterThan(0.33));
    });

    test('the base sits on the ground: just below the horizon at 57 m', () {
      final p = level();
      final w = buildArWalls(
          zones: [square(ZoneCategory.hazard, away: 107)],
          here: here,
          projection: p);
      final base = w.panels.last.bottomA.dy;
      // Ground 57 m off is atan(1.5/57) below level: below the horizon, by
      // the same amount the projection puts any ground point there.
      expect(base, greaterThan(p.horizonY));
      expect(base, closeTo(p.screenY(57), 2));
    });

    test('stripes on a no-go wall, none on an ordinary one', () {
      final noGo = buildArWalls(
          zones: [square(ZoneCategory.hazard, away: 107)],
          here: here,
          projection: level());
      expect(noGo.panels.any((p) => p.stripes.isNotEmpty), isTrue);
      final low = buildArWalls(
          zones: [square(ZoneCategory.camp, away: 30, half: 20)],
          here: here,
          projection: level());
      expect(low.panels.every((p) => p.stripes.isEmpty && p.glow == null),
          isTrue);
    });

    test('every stripe lies on its own piece of wall', () {
      final w = buildArWalls(
          zones: [square(ZoneCategory.hazard, away: 107)],
          here: here,
          projection: level());
      for (final p in w.panels) {
        final box = p.path.getBounds().inflate(1);
        for (final s in p.stripes) {
          for (final o in s) {
            expect(box.contains(o), isTrue);
          }
        }
      }
    });

    test('stripes keep their real size: bigger on screen close up', () {
      double stripeWidth(double away) {
        final w = buildArWalls(
            zones: [square(ZoneCategory.hazard, away: away)],
            here: here,
            projection: level());
        final p = w.panels.last.stripes.isNotEmpty
            ? w.panels.last
            : w.panels.lastWhere((p) => p.stripes.isNotEmpty);
        final xs = p.stripes.first.map((o) => o.dx);
        return xs.reduce(math.max) - xs.reduce(math.min);
      }

      expect(stripeWidth(80), greaterThan(stripeWidth(300)));
    });

    test('a red tint on the ground in front of the wall', () {
      final w = buildArWalls(
          zones: [square(ZoneCategory.hazard, away: 107)],
          here: here,
          projection: level());
      final g = w.panels.last.glow!;
      // Base first, then the near edge: nearer ground is lower on screen.
      expect(g[3].dy, greaterThan(g[0].dy));
      expect(g[2].dy, greaterThan(g[1].dy));
    });

    test('the label is on the wall face, low down', () {
      final w = buildArWalls(
          zones: [square(ZoneCategory.hazard, away: 107)],
          here: here,
          projection: level());
      final l = w.labels.single;
      final p = w.panels.lastWhere((p) => p.distanceM <= w.panels.last.distanceM + 1);
      expect(l.at.dy, lessThan(p.bottomA.dy));
      expect(l.at.dy, greaterThan((p.bottomA.dy + p.topA.dy) / 2),
          reason: 'in the lower half of the face');
    });

    test('readable text at any distance', () {
      for (final d in [5.0, 57.0, 300.0, 1400.0]) {
        final l = WallLabel(square(ZoneCategory.hazard), WallStyle.noGo,
            Offset.zero, d);
        expect(l.fontSize, inInclusiveRange(13, 22), reason: '$d m');
      }
      expect(
          WallLabel(square(ZoneCategory.hazard), WallStyle.noGo, Offset.zero, 20)
              .fontSize,
          greaterThan(WallLabel(square(ZoneCategory.hazard), WallStyle.noGo,
                  Offset.zero, 800)
              .fontSize));
    });

    test('within 50 m it counts as near', () {
      final near = buildArWalls(
          zones: [square(ZoneCategory.hazard, away: 90)],
          here: here,
          projection: level());
      expect(near.labels.single.isNear, isTrue);
      expect(near.panels.last.isNear, isTrue);
      final far = buildArWalls(
          zones: [square(ZoneCategory.hazard, away: 300)],
          here: here,
          projection: level());
      expect(far.labels.single.isNear, isFalse);
    });

    test('the painter draws stripes, glow and a pulse without throwing', () {
      final w = buildArWalls(
          zones: [square(ZoneCategory.hazard, away: 90)],
          here: here,
          projection: level());
      for (final pulse in [0.0, 0.25, 0.5, 0.99]) {
        final recorder = PictureRecorder();
        ArWallPainter(w, pulse: pulse).paint(Canvas(recorder), phone);
        recorder.endRecording().dispose();
      }
    });
  });
}
