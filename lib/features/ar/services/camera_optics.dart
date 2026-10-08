import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// How much of the world the AR camera picture covers.
///
/// The overlay assumed a 65 degree horizontal field of view and derived the
/// vertical from the screen's shape -- about 108 degrees on this phone, where
/// a typical main camera at 16:9 sees about 69. Every wall and pin was drawn at
/// roughly half its real height, squashed onto the horizon: reported as a
/// hazard wall that looked like "a thin floating band near the horizon".
///
/// The real figure comes from the camera itself, through Camera2 (see
/// MainActivity.kt): sensor size and focal length give the angle across the
/// sensor. [fallback] is a typical 26 mm-equivalent main camera, used only
/// when the phone will not say.
class CameraOptics {
  const CameraOptics({
    required this.sensorLongMm,
    required this.sensorShortMm,
    required this.focalLengthMm,
    required this.measured,
  });

  /// A 26 mm-equivalent lens on a 4:3 sensor: about 69 x 54 degrees.
  static const fallback = CameraOptics(
    sensorLongMm: 36,
    sensorShortMm: 27,
    focalLengthMm: 26,
    measured: false,
  );

  final double sensorLongMm;
  final double sensorShortMm;
  final double focalLengthMm;

  /// False when these are [fallback]'s guesses rather than the phone's.
  final bool measured;

  /// Half-angle tangents of the preview picture, along its long and short
  /// sides, for a preview of aspect [previewAspect] (long / short, e.g. 16/9).
  ///
  /// A preview narrower than the sensor (16:9 from a 4:3 sensor) keeps the
  /// sensor's long side and crops the short; one wider than the sensor keeps
  /// the short side and crops the long.
  ({double long, double short}) previewTangents(double previewAspect) {
    final sensorAspect = sensorLongMm / sensorShortMm;
    if (sensorAspect <= previewAspect) {
      final long = (sensorLongMm / 2) / focalLengthMm;
      return (long: long, short: long / previewAspect);
    }
    final short = (sensorShortMm / 2) / focalLengthMm;
    return (long: short * previewAspect, short: short);
  }

  /// The horizontal field of view, in degrees, of a portrait [screen] that
  /// the preview *covers* -- scaled evenly and cropped, never stretched.
  ///
  /// Even scaling keeps a degree worth the same number of pixels both ways,
  /// which is what ArProjection assumes when it derives the vertical field
  /// of view from the horizontal and when it corrects for roll. On a screen
  /// taller than the preview the whole long side shows top to bottom and the
  /// sides are cropped; on a wider one, the reverse.
  double horizontalFovDegFor(Size screen, double previewAspect) {
    final t = previewTangents(previewAspect);
    final screenAspect = screen.width / screen.height; // < 1 in portrait
    final tanH = math.min(t.short, t.long * screenAspect);
    return 2 * math.atan(tanH) * 180 / math.pi;
  }

  /// The camera's optics, read once from the phone and kept.
  static Future<CameraOptics> load() => _loaded ??= _read();
  static Future<CameraOptics>? _loaded;

  static const _channel = MethodChannel('pinage/camera_optics');

  static Future<CameraOptics> _read() async {
    if (kIsWeb) return fallback;
    try {
      final m = await _channel.invokeMapMethod<String, Object?>('backCamera');
      if (m == null) return fallback;
      double n(String k) => (m[k] as num?)?.toDouble() ?? 0;
      var w = n('sensorWidthMm'), h = n('sensorHeightMm');
      final f = n('focalLengthMm');
      // The physical size covers the whole pixel array; the picture comes from
      // the active part of it.
      if (n('pixelArrayWidth') > 0 && n('activeWidth') > 0) {
        w *= n('activeWidth') / n('pixelArrayWidth');
      }
      if (n('pixelArrayHeight') > 0 && n('activeHeight') > 0) {
        h *= n('activeHeight') / n('pixelArrayHeight');
      }
      if (w <= 0 || h <= 0 || f <= 0) return fallback;
      final optics = CameraOptics(
        sensorLongMm: math.max(w, h),
        sensorShortMm: math.min(w, h),
        focalLengthMm: f,
        measured: true,
      );
      final t = optics.previewTangents(16 / 9);
      debugPrint('AR optics: camera ${m['cameraId']} sensor '
          '${w.toStringAsFixed(2)}x${h.toStringAsFixed(2)} mm, '
          'f ${f.toStringAsFixed(2)} mm -> 16:9 preview '
          '${(2 * math.atan(t.long) * 180 / math.pi).toStringAsFixed(1)} x '
          '${(2 * math.atan(t.short) * 180 / math.pi).toStringAsFixed(1)} deg');
      return optics;
    } catch (e) {
      debugPrint('AR optics: unavailable ($e), using a typical camera');
      return fallback;
    }
  }
}
