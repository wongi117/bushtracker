import 'dart:math' as math;

import 'heading_reading.dart';

/// A compass bearing that keeps up with a fast turn.
///
/// The magnetometer alone cannot do it. It is a slow, noisy sensor: sitting
/// still on a bench the derived bearing wanders several degrees, and no amount
/// of smoothing fixes both that and the lag when you sweep the phone around —
/// smooth it enough to stop the wander and it falls behind a turn; leave it
/// responsive and it shimmers. That is the whole reason AR markers appeared to
/// slide along with the camera during a 360 and only settle once the phone
/// stopped: the bearing genuinely was behind the handset.
///
/// A gyroscope has the opposite character — it measures rotation directly, at
/// full speed, with no reference to the world, so it tracks a whip perfectly
/// and then drifts away over tens of seconds. Putting the two together is the
/// standard answer: integrate the gyro for the fast movement, and let the
/// magnetometer pull the result gently back to true. Neither sensor's weakness
/// survives.
class HeadingFusion {
  HeadingFusion({this.magnetometerPull = 0.25});

  /// How hard the magnetometer corrects the integrated bearing, in Hz.
  ///
  /// This is the crossover between the two sensors. It can afford to be low —
  /// a time constant near two thirds of a second — precisely because the gyro
  /// is carrying the fast movement: smoothing the magnetometer this hard costs
  /// nothing in responsiveness and takes almost all of the wander out. Too low
  /// and gyro bias shows as a slow creep; 0.25 Hz holds a typical half-degree
  /// a second of bias to well under a degree of error.
  final double magnetometerPull;

  double? _heading;

  /// The fused bearing, clockwise from north, or null before the first update.
  double? get heading => _heading;

  /// Advance by [dt] seconds.
  ///
  /// [yawRateDegPerSec] is rotation about the world vertical, positive
  /// clockwise so it matches the bearing it is added to. Pass 0 when there is
  /// no gyroscope, and this degenerates to a plain low-pass on the
  /// magnetometer.
  ///
  /// [magneticHeadingDeg] is null when the magnetometer reading is not worth
  /// trusting, in which case the bearing coasts on the gyro alone — good for
  /// the few seconds it takes to walk past a vehicle, and drifting after that.
  double update({
    required double dt,
    required double yawRateDegPerSec,
    double? magneticHeadingDeg,
  }) {
    if (dt <= 0 || !dt.isFinite) dt = 1 / 50;

    final previous = _heading;
    if (previous == null) {
      // Nothing to integrate from yet; the magnetometer is the only thing that
      // knows where north is, so wait for it rather than starting at zero.
      if (magneticHeadingDeg == null) return 0;
      _heading = HeadingReading.normalize(magneticHeadingDeg);
      return _heading!;
    }

    // Dead-reckon: instant, and wrong in the long run.
    var predicted = previous + yawRateDegPerSec * dt;

    if (magneticHeadingDeg != null) {
      // Pull towards the measured bearing the short way round the dial, by a
      // fixed fraction of the remaining error per unit time. Framed as a time
      // constant so the behaviour does not change with the sample rate.
      final error = HeadingReading.delta(predicted, magneticHeadingDeg);
      final alpha =
          (1 - math.exp(-2 * math.pi * magnetometerPull * dt)).clamp(0.0, 1.0);
      predicted += error * alpha;
    }

    _heading = HeadingReading.normalize(predicted);
    return _heading!;
  }

  void reset() => _heading = null;

  /// Rotation about the world vertical, in degrees a second, positive
  /// clockwise — the direction a compass bearing increases.
  ///
  /// The gyroscope measures rotation about the handset's own axes, which is
  /// not what a bearing turns about unless the phone happens to be flat. The
  /// component that changes your heading is the part along gravity, which is
  /// the dot product of the two. It comes out negated because the gyro follows
  /// the right-hand rule — rotation anticlockwise seen from above is positive
  /// there, and that is the direction a compass bearing *decreases*.
  static double yawRateFromGyro({
    required double gx,
    required double gy,
    required double gz,
    required double upX,
    required double upY,
    required double upZ,
  }) {
    final aboutVertical = gx * upX + gy * upY + gz * upZ;
    return -aboutVertical * 180 / math.pi;
  }
}
