import 'dart:math' as math;

/// Compass bearings derived from gravity and the magnetic field.
///
/// Two of them, because a phone has two reasonable ideas of "which way am I
/// facing" and they are well-conditioned in opposite situations.
///
/// The textbook azimuth — Android's `getRotationMatrix` followed by
/// `getOrientation` — gives [topAzimuthDeg], the bearing of the handset's top
/// edge. That is the right answer when the phone is held flat like a map, and
/// it is what a compass rose wants.
///
/// It is also completely wrong for an AR camera, which was the bug this class
/// exists to fix. Hold the phone up to look through the camera and the top edge
/// points at the sky: its horizontal projection is almost nothing, so the
/// azimuth is `atan2` of two near-zero noisy numbers. It does not track turning
/// about the vertical, which is why AR markers appeared to travel with the
/// camera instead of staying on their feature — the bearing genuinely was not
/// changing as the handset turned.
///
/// [cameraAzimuthDeg] is the bearing of where the lens actually points, along
/// the handset's -z axis. It is best conditioned exactly where the other one is
/// worst: upright, camera at the horizon. It degrades when the phone is near
/// flat and the lens points at the ground or the sky, which [cameraUsable]
/// reports so a caller can hold its last good value.
class MagneticBearing {
  const MagneticBearing({
    required this.topAzimuthDeg,
    required this.cameraAzimuthDeg,
    required this.fieldStrengthUt,
    required this.cameraUsable,
  });

  /// Bearing of the handset's top edge, clockwise from north.
  final double topAzimuthDeg;

  /// Bearing the lens is pointed, clockwise from north.
  final double cameraAzimuthDeg;

  /// Magnitude of the measured field, in microtesla.
  final double fieldStrengthUt;

  /// False when the lens is within about fifteen degrees of straight up or
  /// straight down, where its bearing stops meaning anything.
  final bool cameraUsable;

  /// Below this much horizontal component, the lens direction is noise.
  static const double _cameraFloor = 0.26; // about 75 degrees of pitch

  /// Null in free fall, or where the field runs parallel to gravity and there
  /// is no horizontal component to take a bearing from.
  ///
  /// [accel] reads +g along whichever device axis points at the sky; [mag] is
  /// the magnetic field in device axes. Both as [x, y, z].
  static MagneticBearing? from({
    required List<double> accel,
    required List<double> mag,
  }) {
    final a = accel;
    final m = mag;

    // East = magnetic x gravity, the same construction Android uses.
    final hx = m[1] * a[2] - m[2] * a[1];
    final hy = m[2] * a[0] - m[0] * a[2];
    final hz = m[0] * a[1] - m[1] * a[0];
    final hLen = math.sqrt(hx * hx + hy * hy + hz * hz);

    final aLen = math.sqrt(a[0] * a[0] + a[1] * a[1] + a[2] * a[2]);
    if (hLen < 0.1 || aLen < 0.1 || !hLen.isFinite || !aLen.isFinite) {
      return null;
    }

    final ax = a[0] / aLen, ay = a[1] / aLen, az = a[2] / aLen;
    final ex = hx / hLen, ey = hy / hLen, ez = hz / hLen;

    // North = gravity x East.
    final nx = ay * ez - az * ey;
    final ny = az * ex - ax * ez;
    final nz = ax * ey - ay * ex;

    // Where the top edge points: the east and north components of the +y axis.
    final top = math.atan2(ey, ny) * 180 / math.pi;

    // Where the lens points: the same, for -z. Negated because the camera looks
    // out the back of the handset, opposite the screen normal.
    final camera = math.atan2(-ez, -nz) * 180 / math.pi;

    // How much of the lens direction lies in the horizontal plane. Straight
    // down the -z axis this is cos(pitch); near zero the bearing is noise.
    final cameraHorizontal = math.sqrt(ez * ez + nz * nz);

    return MagneticBearing(
      topAzimuthDeg: _normalize(top),
      cameraAzimuthDeg: _normalize(camera),
      fieldStrengthUt: math.sqrt(m[0] * m[0] + m[1] * m[1] + m[2] * m[2]),
      cameraUsable: cameraHorizontal > _cameraFloor && nx.isFinite,
    );
  }

  static double _normalize(double deg) => (deg % 360 + 360) % 360;
}
