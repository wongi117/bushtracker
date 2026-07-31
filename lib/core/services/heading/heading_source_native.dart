import 'dart:async';
import 'dart:math' as math;

import 'package:sensors_plus/sensors_plus.dart';

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
  /// Low-pass weight for the raw vectors. Lower = steadier but laggier.
  static const double _vectorSmoothing = 0.2;

  /// Low-pass weight applied to the resulting bearing.
  static const double _headingSmoothing = 0.25;

  /// Earth's magnetic field is ~25–65 uT. Outside this band we are reading
  /// a vehicle body, a speaker magnet, or an uncalibrated sensor.
  static const double _minFieldUt = 20.0;
  static const double _maxFieldUt = 70.0;

  /// The sensors fire far faster than a compass needs to redraw, and every
  /// emission rebuilds widgets. 20 Hz is smooth to the eye and cheap on
  /// battery — which matters when the phone is the only nav device out there.
  static const Duration _minInterval = Duration(milliseconds: 50);
  static const double _minDegreeChange = 0.2;

  final StreamController<HeadingReading> _controller =
      StreamController<HeadingReading>.broadcast();

  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<MagnetometerEvent>? _magSub;

  List<double>? _accel;
  List<double>? _mag;
  double? _smoothedDegrees;
  bool _started = false;

  final Stopwatch _sinceEmit = Stopwatch();
  double? _lastEmittedDegrees;
  HeadingQuality? _lastEmittedQuality;

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
      _accelSub = accelerometerEvents.listen(
        (e) {
          _accel = _lowPass(_accel, e.x, e.y, e.z);
          _recompute();
        },
        onError: (_) => _unavailable(),
        cancelOnError: false,
      );
      _magSub = magnetometerEvents.listen(
        (e) {
          _mag = _lowPass(_mag, e.x, e.y, e.z);
          _recompute();
        },
        onError: (_) => _unavailable(),
        cancelOnError: false,
      );
    } catch (_) {
      _unavailable();
    }
  }

  List<double> _lowPass(List<double>? prev, double x, double y, double z) {
    if (prev == null) return <double>[x, y, z];
    const a = _vectorSmoothing;
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

    // East = m x a
    final hx = m[1] * a[2] - m[2] * a[1];
    final hy = m[2] * a[0] - m[0] * a[2];
    final hz = m[0] * a[1] - m[1] * a[0];
    final hLen = math.sqrt(hx * hx + hy * hy + hz * hz);

    final aLen = math.sqrt(a[0] * a[0] + a[1] * a[1] + a[2] * a[2]);
    // Free-fall, or the magnetic vector is parallel to gravity (phone pointed
    // at the pole) — no horizontal component to derive a bearing from.
    if (hLen < 0.1 || aLen < 0.1) return;

    final ax = a[0] / aLen, az = a[2] / aLen;
    final ex = hx / hLen, ey = hy / hLen, ez = hz / hLen;

    // North = a x East (only the y component is needed for the azimuth).
    final ny = az * ex - ax * ez;

    final degrees = HeadingReading.normalize(
      math.atan2(ey, ny) * 180.0 / math.pi,
    );

    _smoothedDegrees = _smoothedDegrees == null
        ? degrees
        : HeadingReading.normalize(
            _smoothedDegrees! +
                HeadingReading.delta(_smoothedDegrees!, degrees) *
                    _headingSmoothing,
          );

    final fieldUt = math.sqrt(m[0] * m[0] + m[1] * m[1] + m[2] * m[2]);
    final clean = fieldUt >= _minFieldUt && fieldUt <= _maxFieldUt;
    final quality =
        clean ? HeadingQuality.good : HeadingQuality.interference;

    if (!_shouldEmit(_smoothedDegrees!, quality)) return;

    _emit(HeadingReading(
      degrees: _smoothedDegrees!,
      quality: quality,
      source: HeadingSourceKind.sensors,
      fieldStrengthUt: fieldUt,
    ));
  }

  /// Rate-limit the stream: skip anything that arrives inside [_minInterval]
  /// and has not moved far enough to be visible. Quality changes always pass.
  bool _shouldEmit(double degrees, HeadingQuality quality) {
    if (quality != _lastEmittedQuality) return true;
    if (!_sinceEmit.isRunning) return true;
    if (_sinceEmit.elapsed < _minInterval) return false;
    final last = _lastEmittedDegrees;
    if (last != null &&
        HeadingReading.delta(last, degrees).abs() < _minDegreeChange) {
      return false;
    }
    return true;
  }

  void _unavailable() {
    _emit(const HeadingReading.unavailable(HeadingSourceKind.sensors));
  }

  void _emit(HeadingReading reading) {
    if (_controller.isClosed) return;
    _lastEmittedDegrees = reading.degrees;
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
    _controller.close();
  }
}
