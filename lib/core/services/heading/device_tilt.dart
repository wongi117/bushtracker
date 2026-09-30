import 'dart:math' as math;

/// Which way the camera is pointing, worked out from gravity alone.
///
/// This lives on its own, away from the sensor plumbing, because the sign
/// conventions matter more than anything else in the AR overlay and they are
/// impossible to check by reading the code. Getting the roll backwards does
/// not look like a missing correction — it looks like twice the tilt, leaning
/// the same way as the phone. So the maths is a plain function over three
/// numbers, and [DeviceTilt] round-trips against known handset positions in
/// the tests.
///
/// Device axes in portrait: x out the right edge, y out the top edge, z out
/// through the glass towards your face. The camera looks the other way, along
/// -z. An accelerometer at rest reads +g along whichever axis points at the
/// sky, so the vector handed in here is "up" as the handset sees it.
class DeviceTilt {
  const DeviceTilt({
    required this.pitchRad,
    required this.rollRad,
    required this.rollMeasurable,
  });

  /// Elevation of the camera above level, positive up. Straight at the
  /// horizon is zero; flat on its back, camera at the ground, is -pi/2.
  final double pitchRad;

  /// Lean about the camera's own axis, positive clockwise from portrait.
  final double rollRad;

  /// False when the handset is too near flat for roll to mean anything.
  ///
  /// Lying on its back, x and y are both about zero, and atan2 of noise over
  /// noise wanders through the whole dial — which spins the overlay while the
  /// phone sits still on a bonnet. Callers hold their last real roll instead.
  final bool rollMeasurable;

  /// Below this much of gravity in the plane of the screen, roll is noise.
  /// 0.15 is about nine degrees off flat.
  static const double _rollFloor = 0.15;

  /// Null in free fall, or anywhere else the vector is too short to normalise.
  static DeviceTilt? fromGravity(double ax, double ay, double az) {
    final length = math.sqrt(ax * ax + ay * ay + az * az);
    if (!length.isFinite || length < 0.1) return null;

    final ux = ax / length;
    final uy = ay / length;
    final uz = az / length;

    // The camera looks along -z, so the sine of its elevation is just -z once
    // the vector is a unit vector. This used to be atan2(-z, y), which agrees
    // only while the handset is held square: roll it and y shrinks towards
    // zero while z stays put, so atan2 swung towards +/-90 degrees and threw
    // the horizon — and every marker measured from it — off the screen. asin
    // does not involve y at all, so roll cannot contaminate it.
    final pitch = math.asin((-uz).clamp(-1.0, 1.0));

    // Roll is the lean of gravity within the plane of the screen. Negating x
    // makes it positive clockwise: tip the top of the handset to the right
    // and its x axis tilts downwards, so "up" acquires a negative x.
    final inPlane = math.sqrt(ux * ux + uy * uy);
    return DeviceTilt(
      pitchRad: pitch,
      rollRad: math.atan2(-ux, uy),
      rollMeasurable: inPlane > _rollFloor,
    );
  }
}
