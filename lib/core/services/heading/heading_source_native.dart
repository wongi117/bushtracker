import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:sensors_plus/sensors_plus.dart';

import 'device_tilt.dart';
import 'heading_fusion.dart';
import 'magnetic_bearing.dart';
import 'one_euro_filter.dart';

import 'heading_reading.dart';
import 'heading_source.dart';

HeadingSource makeHeadingSource() => SensorHeadingSource();

/// Tilt-compensated compass from the raw magnetometer and accelerometer.
///
/// The old code did `atan2(mag.x, mag.y)` straight off the magnetometer. That
/// is only correct when the phone is lying dead flat — the moment you hold it
/// up to look at it, the reading swings by tens of degrees. This uses the same
/// rotation-matrix maths as Android's `SensorManager.getRotationMatrix` +
/// `getOrientation`, which projects the magnetic vector onto the true
/// horizontal plane using gravity, so the bearing holds while the phone tilts.
class SensorHeadingSource implements HeadingSource {
  /// Low-pass weight for the raw gravity vector. Lower = steadier but laggier.
  ///
  /// Tilt wants this heavily smoothed: pitch and roll feed the horizon, and an
  /// unsteady horizon moves everything drawn against it.
  static const double _accelSmoothing = 0.2;

  /// And for the magnetic vector, which wants the opposite.
  ///
  /// A complementary filter cannot undo lag that is already in its reference:
  /// during a steady turn the fused bearing settles wherever the magnetometer
  /// says, so smoothing the magnetic vector hard put that lag straight back
  /// into the AR overlay — at 0.2 it was eighty milliseconds, which is twenty
  /// degrees at the rate you sweep a phone around. The right division of
  /// labour is a prompt but noisy reference, with [_fusion] doing the
  /// smoothing against the gyro. Kept slightly damped rather than raw because
  /// the magnetometer is genuinely noisy and there is no point handing all of
  /// it to the fusion to remove.
  static const double _magSmoothing = 0.6;


  final _headingFilter = OneEuroAngleFilter();

  /// Gyro + magnetometer. Carries the heading whenever a gyroscope is present,
  /// which is every phone worth running this on; [_headingFilter] is the
  /// fallback for one without.
  final _fusion = HeadingFusion();

  /// Fallback smoother for the lens bearing on a handset with no gyroscope.
  final _cameraFilter = OneEuroAngleFilter();

  /// Last lens bearing worth having. Null until one is measured.
  double? _cameraDegrees;

  // Radians, not degrees — the adaptation is rate-based, so the units matter.
  final _pitchFilter = OneEuroFilter.radians();
  final _rollFilter = OneEuroFilter.radians();
  DateTime? _lastSample;

  /// Earth's magnetic field is ~25–65 uT. Outside this band we are reading
  /// a vehicle body, a speaker magnet, or an uncalibrated sensor.
  static const double _minFieldUt = 20.0;
  static const double _maxFieldUt = 70.0;

  /// The sensors fire far faster than a compass needs to redraw, and every
  /// emission rebuilds widgets. Matched to a 30 fps camera preview: at 20 Hz
  /// the AR overlay and the picture behind it updated on different cadences,
  /// and markers juddered against the scene even when the maths was right.
  static const Duration _minInterval = Duration(milliseconds: 33);
  static const double _minDegreeChange = 0.2;

  /// Tilt has to get through the rate limiter on its own account.
  ///
  /// The gate used to ask only whether the *heading* had moved. Stand still
  /// facing a pin and tilt the phone up and down and the bearing never
  /// changes by [_minDegreeChange], so nothing was emitted at all: the
  /// horizon — and every marker hung off it — stayed put while the phone
  /// moved, then jumped when the heading finally happened to shift.
  static const double _minTiltChangeRad = 0.004; // about a quarter degree

  final StreamController<HeadingReading> _controller =
      StreamController<HeadingReading>.broadcast();

  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<MagnetometerEvent>? _magSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;

  List<double>? _accel;
  List<double>? _mag;

  /// Latest angular rate, unsmoothed: the whole point of it is speed.
  List<double>? _gyro;

  /// True once a gyroscope sample has actually arrived. A phone without one
  /// gives an error or simply never emits, and then the magnetometer has to
  /// carry the heading on its own.
  bool _gyroLive = false;
  double? _smoothedDegrees;
  bool _started = false;

  final Stopwatch _sinceEmit = Stopwatch();
  double? _lastEmittedDegrees;
  double? _lastEmittedPitch;
  double? _lastEmittedRoll;
  HeadingQuality? _lastEmittedQuality;

  /// Roll from the last time it could actually be measured.
  ///
  /// Held so a phone lying flat does not spin the overlay: see [_recompute].
  double _lastGoodRoll = 0;

  /// Log what the compass is actually producing, twice a second.
  ///
  /// Build with --dart-define=DEBUG_AR=true. Worth having on its own line
  /// rather than inferring it from the overlay: a bearing that never changes
  /// while the handset turns and a bearing that changes but is wrong look
  /// identical through the camera, and only one of them is a maths problem.
  static const bool _debug = bool.fromEnvironment('DEBUG_AR');
  final Stopwatch _sinceLog = Stopwatch();

  @override
  Stream<HeadingReading> get readings => _controller.stream;

  @override
  Future<bool> requestPermission() async => true;

  @override
  void start() {
    if (_started) return;
    _started = true;
    _emit(const HeadingReading.waiting(HeadingSourceKind.sensors));

    try {
      // The compass wants a steady, fairly quick feed; the game interval is
      // what these sensors are tuned for and keeps the needle smooth without
      // waking the CPU at UI rate.
      _accelSub = accelerometerEventStream(
        samplingPeriod: SensorInterval.gameInterval,
      ).listen(
        (e) {
          _accel = _lowPass(_accel, e.x, e.y, e.z, _accelSmoothing);
          _recompute();
        },
        onError: (_) => _unavailable(),
        cancelOnError: false,
      );
      _magSub = magnetometerEventStream(
        samplingPeriod: SensorInterval.gameInterval,
      ).listen(
        (e) {
          _mag = _lowPass(_mag, e.x, e.y, e.z, _magSmoothing);
          _recompute();
        },
        onError: (_) => _unavailable(),
        cancelOnError: false,
      );
      // Not smoothed and not required. A missing gyroscope is not a failure —
      // the compass still works, just less well when you turn quickly — so an
      // error here leaves the heading alone rather than marking it dead.
      _gyroSub = gyroscopeEventStream(
        samplingPeriod: SensorInterval.gameInterval,
      ).listen(
        (e) {
          _gyro = <double>[e.x, e.y, e.z];
          _gyroLive = true;
        },
        onError: (_) {
          _gyro = null;
          _gyroLive = false;
        },
        cancelOnError: false,
      );
    } catch (_) {
      _unavailable();
    }
  }

  List<double> _lowPass(
      List<double>? prev, double x, double y, double z, double a) {
    if (prev == null) return <double>[x, y, z];
    return <double>[
      prev[0] + (x - prev[0]) * a,
      prev[1] + (y - prev[1]) * a,
      prev[2] + (z - prev[2]) * a,
    ];
  }

  void _recompute() {
    final a = _accel;
    final m = _mag;
    if (a == null || m == null) return;

    final bearing = MagneticBearing.from(accel: a, mag: m);
    // Free fall, no field, or a field running parallel to gravity: nothing to
    // take a bearing from.
    if (bearing == null) return;

    final aLen = math.sqrt(a[0] * a[0] + a[1] * a[1] + a[2] * a[2]);
    if (aLen < 0.1) return;

    final now = DateTime.now();
    final dt = _lastSample == null
        ? 1 / 50
        : (now.difference(_lastSample!).inMicroseconds / 1e6).clamp(1 / 200, 0.2);
    _lastSample = now;

    final quality = bearing.fieldStrengthUt >= _minFieldUt &&
            bearing.fieldStrengthUt <= _maxFieldUt
        ? HeadingQuality.good
        : HeadingQuality.interference;

    // Tilt of the camera, from the already-smoothed gravity vector. The sign
    // conventions live in DeviceTilt, where they are tested against known
    // handset positions — see device_tilt.dart for why that matters. Filtered
    // as well: an unfiltered pitch makes the whole horizon, and everything
    // hung off it, jump on every sensor step.
    final tilt = DeviceTilt.fromGravity(a[0], a[1], a[2]);
    if (tilt == null) return;

    final pitch = _pitchFilter.filter(tilt.pitchRad, dt);
    if (tilt.rollMeasurable) {
      _lastGoodRoll = _rollFilter.filter(tilt.rollRad, dt);
    }
    final roll = _lastGoodRoll;

    // Which way the top edge points, for a compass rose held flat like a map.
    // Adaptive smoothing, since a fixed alpha has to choose between shimmering
    // while still and lagging while turning.
    _smoothedDegrees = _headingFilter.filter(bearing.topAzimuthDeg, dt);

    // And which way the lens points, which is a different question and the one
    // the AR overlay needs. See magnetic_bearing.dart: the top-edge azimuth is
    // degenerate exactly when the phone is held up to look through it, so it
    // could never have anchored a marker.
    //
    // The gyro carries this one where there is a gyro. At a 65 degree field of
    // view across a phone screen one degree is about sixteen pixels, so the
    // magnetometer's few degrees of wander is thirty or forty pixels of
    // shimmer, and its lag through a sweep is most of the width of the screen.
    // Integrating the gyroscope and letting the magnetometer pull it back
    // slowly beats either sensor alone.
    //
    // Pointed at the ground or the sky the lens bearing means nothing, so it
    // holds its last real value rather than handing the overlay noise.
    final g = _gyro;
    final yawRate = (_gyroLive && g != null)
        ? HeadingFusion.yawRateFromGyro(
            gx: g[0],
            gy: g[1],
            gz: g[2],
            upX: a[0] / aLen,
            upY: a[1] / aLen,
            upZ: a[2] / aLen,
          )
        : 0.0;

    if (bearing.cameraUsable) {
      _cameraDegrees = _gyroLive
          ? _fusion.update(
              dt: dt,
              yawRateDegPerSec: yawRate,
              magneticHeadingDeg: bearing.cameraAzimuthDeg,
            )
          : _cameraFilter.filter(bearing.cameraAzimuthDeg, dt);
    } else if (_gyroLive && _cameraDegrees != null) {
      // Coast: the gyro still knows how far you have turned even while the
      // bearing itself cannot be measured.
      _cameraDegrees = _fusion.update(dt: dt, yawRateDegPerSec: yawRate);
    }

    if (!_shouldEmit(_smoothedDegrees!, quality, pitch, roll)) return;

    _emit(HeadingReading(
      degrees: _smoothedDegrees!,
      cameraDegrees: _cameraDegrees,
      quality: quality,
      source: HeadingSourceKind.sensors,
      fieldStrengthUt: bearing.fieldStrengthUt,
      pitchRad: pitch,
      rollRad: roll,
    ));
  }

  /// Rate-limit the stream: skip anything that arrives inside [_minInterval]
  /// and has not moved far enough to be visible. Quality changes always pass.
  bool _shouldEmit(
      double degrees, HeadingQuality quality, double pitch, double roll) {
    if (quality != _lastEmittedQuality) return true;
    if (!_sinceEmit.isRunning) return true;
    if (_sinceEmit.elapsed < _minInterval) return false;

    final last = _lastEmittedDegrees;
    final turned = last == null ||
        HeadingReading.delta(last, degrees).abs() >= _minDegreeChange;
    final tilted = _lastEmittedPitch == null ||
        (pitch - _lastEmittedPitch!).abs() >= _minTiltChangeRad ||
        (roll - _lastEmittedRoll!).abs() >= _minTiltChangeRad;

    return turned || tilted;
  }

  void _unavailable() {
    _emit(const HeadingReading.unavailable(HeadingSourceKind.sensors));
  }

  void _emit(HeadingReading reading) {
    if (_controller.isClosed) return;

    if (_debug && (!_sinceLog.isRunning || _sinceLog.elapsedMilliseconds > 500)) {
      _sinceLog
        ..reset()
        ..start();
      debugPrint('🧭 heading=${reading.degrees.toStringAsFixed(1)} '
          '${reading.cardinal} '
          'pitch=${(reading.pitchRad * 180 / math.pi).toStringAsFixed(1)} '
          'roll=${(reading.rollRad * 180 / math.pi).toStringAsFixed(1)} '
          'quality=${reading.quality.name} '
          'field=${reading.fieldStrengthUt?.toStringAsFixed(1) ?? '-'}uT '
          'accel=${_accel == null ? 'none' : 'ok'} '
          'mag=${_mag == null ? 'NONE' : 'ok'} '
          'gyro=${_gyroLive ? 'fused' : 'NONE'} '
          'lens=${reading.cameraDegrees?.toStringAsFixed(1) ?? 'none'}');
    }

    _lastEmittedDegrees = reading.degrees;
    _lastEmittedPitch = reading.pitchRad;
    _lastEmittedRoll = reading.rollRad;
    _lastEmittedQuality = reading.quality;
    _sinceEmit
      ..reset()
      ..start();
    _controller.add(reading);
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    _magSub?.cancel();
    _gyroSub?.cancel();
    _controller.close();
  }
}
