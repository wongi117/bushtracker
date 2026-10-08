// The AR camera's field of view. It was assumed to be 65 degrees across,
// which on a tall phone screen implied ~108 degrees top to bottom where the
// camera sees ~69: every wall and pin drawn at about half height, squashed
// onto the horizon.
import 'dart:math' as math;
import 'dart:ui';

import 'package:bush_track/features/ar/services/ar_projection.dart';
import 'package:bush_track/features/ar/services/camera_optics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  double deg(double tanHalf) => 2 * math.atan(tanHalf) * 180 / math.pi;
  const phone = Size(411, 891); // a 1080x2340 Samsung at 2.625 dpr

  test('a 26 mm-equivalent lens sees ~69 by ~43 degrees at 16:9', () {
    final t = CameraOptics.fallback.previewTangents(16 / 9);
    expect(deg(t.long), closeTo(69.4, 0.1));
    expect(deg(t.short), closeTo(42.6, 0.2));
  });

  test('covering a tall screen shows the whole long side top to bottom', () {
    // Scaled evenly and cropped at the sides: the screen is taller than 16:9.
    const o = CameraOptics.fallback;
    final h = o.horizontalFovDegFor(phone, 16 / 9);
    final tanH = math.tan(h * math.pi / 360);
    // What ArProjection derives for the vertical from that and the aspect.
    final tanV = tanH * phone.height / phone.width;
    expect(deg(tanV), closeTo(69.4, 0.1));
    expect(h, closeTo(35.4, 0.3));
  });

  test('on a wider screen the short side fills it instead', () {
    const o = CameraOptics.fallback;
    const squat = Size(600, 800); // wider than 9:16
    expect(o.horizontalFovDegFor(squat, 16 / 9), closeTo(42.6, 0.2));
  });

  test('a sensor wider than the preview keeps its short side', () {
    // A 2:1 sensor making a 16:9 picture crops its long side.
    const wide = CameraOptics(
        sensorLongMm: 8, sensorShortMm: 4, focalLengthMm: 4, measured: true);
    final t = wide.previewTangents(16 / 9);
    expect(t.short, closeTo(0.5, 1e-9));
    expect(t.long, closeTo(0.5 * 16 / 9, 1e-9));
  });

  test('the old guess drew things at about half their real height', () {
    // Height on screen of a 30 m wall 57 m away, level, both ways.
    double wallPx(double hFov) {
      final p = ArProjection(
          size: phone, headingDeg: 0, pitchRad: 0, horizontalFovDeg: hFov);
      return p.screenY(57) - p.screenY(57, metresAboveGround: 30);
    }

    final real = wallPx(CameraOptics.fallback.horizontalFovDegFor(phone, 16 / 9));
    final old = wallPx(65);
    expect(real / old, closeTo(2, 0.1));
    // And at 57 m the real one is over a third of the screen's height.
    expect(real / phone.height, greaterThan(0.33));
  });
}
