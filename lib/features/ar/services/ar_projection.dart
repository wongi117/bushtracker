import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

/// Where a real-world point lands on the camera image.
///
/// The AR overlay used to fake this: horizontal position came from the
/// bearing, but vertical position was `height * (0.55 + nearness * 0.35)` —
/// a guess from distance that ignored how the phone was held. Every beam sat
/// a couple of metres in front of you with its rings at your feet, whether
/// the pin was 20 m away or 4 km, and tilting the phone did nothing.
///
/// This does it properly: bearing across the horizontal field of view, the
/// angle below the horizon from the camera's height above the ground, the
/// horizon itself moved by the phone's pitch, and the whole frame turned back
/// by the phone's roll so a marker stays on its feature while you tilt.
class ArProjection {
  const ArProjection({
    required this.size,
    required this.headingDeg,
    required this.pitchRad,
    this.rollRad = 0,
    this.horizontalFovDeg = 65,
    this.cameraHeightM = 1.5,
  });

  final Size size;

  /// Where the camera is pointed, clockwise from north.
  final double headingDeg;

  /// Camera tilt, positive up.
  final double pitchRad;

  /// Rotation about the camera's own axis, positive clockwise from portrait.
  final double rollRad;

  /// Horizontal field of view of the camera.
  final double horizontalFovDeg;

  /// Roughly eye height for someone holding a phone up.
  final double cameraHeightM;

  /// Pitch never gets closer than this to straight up or straight down.
  ///
  /// `tan(90 degrees)` is infinite, so without a clamp pointing the phone at
  /// the sky or at your boots turns the horizon — and every marker computed
  /// from it — into infinity or NaN, and the overlay either vanishes or draws
  /// in garbage places.
  static const double _maxPitch = 85 * math.pi / 180;

  double get _pitch => pitchRad.clamp(-_maxPitch, _maxPitch);

  double get _halfFovH => horizontalFovDeg * math.pi / 360;

  /// Vertical field of view follows from the aspect ratio.
  double get _halfFovV =>
      math.atan(math.tan(_halfFovH) * (size.height / size.width));

  /// Pixels per unit of tangent, horizontally and vertically.
  ///
  /// These come out equal, because the vertical field of view is derived from
  /// the horizontal one by the aspect ratio. That equality is what makes
  /// [applyRoll] legitimate: rotating a position in pixel space is only the
  /// same as rotating it in angle space when a degree is worth the same
  /// number of pixels both ways. A test holds this, because if the two fields
  /// of view are ever set independently the roll correction quietly starts
  /// skewing every marker.
  double get scaleX => (size.width / 2) / math.tan(_halfFovH);

  double get scaleY => (size.height / 2) / math.tan(_halfFovV);

  /// The horizon's height on screen, before roll. Tilting the camera up
  /// pushes it down the image, and vice versa.
  double get horizonY =>
      size.height / 2 +
      (math.tan(_pitch) / math.tan(_halfFovV)) * (size.height / 2);

  /// Signed angle from where the camera points to [bearingDeg], in radians.
  /// Negative is to the left.
  double relativeBearing(double bearingDeg) {
    var rel = (bearingDeg - headingDeg) % 360;
    if (rel > 180) rel -= 360;
    if (rel < -180) rel += 360;
    return rel * math.pi / 180;
  }

  /// True when the point is within the camera's view, with a little margin
  /// so things do not pop in exactly at the edge.
  bool isInView(double bearingDeg) =>
      relativeBearing(bearingDeg).abs() < _halfFovH * 1.15;

  /// Horizontal screen position for a bearing, in the level-camera frame.
  ///
  /// Uses tan rather than a straight proportion: a camera is a projection,
  /// so an object 30 degrees off-axis is further from centre than twice one
  /// at 15 degrees.
  double screenX(double bearingDeg) {
    final rel = relativeBearing(bearingDeg);
    // Beyond about 80 degrees tan runs away; anything out there is off
    // screen regardless, so clamp rather than produce infinities.
    final clamped = rel.clamp(-1.4, 1.4);
    return size.width / 2 +
        (math.tan(clamped) / math.tan(_halfFovH)) * (size.width / 2);
  }

  /// Screen height of a point [metresAboveGround] high at [distanceM], in the
  /// level-camera frame.
  ///
  /// Ground level is `metresAboveGround: 0`, which is below the horizon by
  /// atan(cameraHeight / distance) — a few degrees close up, and effectively
  /// nothing at a kilometre, so distant things sit on the horizon where they
  /// belong.
  double screenY(double distanceM, {double metresAboveGround = 0}) {
    final safeDistance = math.max(distanceM, 1.0);
    // Positive when the point is above the camera, negative below.
    final elevation =
        math.atan((metresAboveGround - cameraHeightM) / safeDistance);
    return horizonY -
        (math.tan(elevation) / math.tan(_halfFovV)) * (size.height / 2);
  }

  /// Both at once, for a point on the ground, in the level-camera frame.
  Offset groundPoint(double bearingDeg, double distanceM) =>
      Offset(screenX(bearingDeg), screenY(distanceM));

  /// Where the point actually lands on the rolled camera image.
  ///
  /// This is what the overlay draws against. [groundPoint] answers "where
  /// would this be if the phone were held square", and [applyRoll] turns that
  /// into where it is on the picture the camera is really producing.
  Offset project(double bearingDeg, double distanceM,
          {double metresAboveGround = 0}) =>
      applyRoll(Offset(screenX(bearingDeg),
          screenY(distanceM, metresAboveGround: metresAboveGround)));

  /// Turn a level-frame position into its place on the rolled image.
  ///
  /// Rolling the phone clockwise swings the scene anticlockwise in the frame,
  /// so a marker's position has to swing with it — that is what keeps it on
  /// its tree while you tilt. Rotating about the centre of the image, which
  /// is where the lens axis is.
  Offset applyRoll(Offset levelPoint) => _rotate(levelPoint, -rollRad);

  /// The reverse, for turning a finger on the glass back into a direction.
  Offset unroll(Offset imagePoint) => _rotate(imagePoint, rollRad);

  Offset _rotate(Offset p, double angle) {
    if (angle == 0 || !angle.isFinite) return p;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final dx = p.dx - cx;
    final dy = p.dy - cy;
    final c = math.cos(angle);
    final s = math.sin(angle);
    return Offset(cx + dx * c - dy * s, cy + dx * s + dy * c);
  }

  /// The patch of ground under a point on the screen.
  ///
  /// The reverse of everything above: point the camera at a tree two hundred
  /// metres off, touch it on screen, and this works out which direction and
  /// how far away that piece of ground is — so a pin can be dropped there
  /// without walking to it. The roll comes off first, or a pin dropped with
  /// the phone held at an angle lands off to one side of what you aimed at.
  ///
  /// Returns null for anything on or above the horizon, where the ray never
  /// meets the ground and the distance would be infinite. [maxDistanceM]
  /// caps the answer just below the horizon, where a pixel is worth
  /// kilometres and the number stops meaning anything.
  ({double bearingDeg, double distanceM})? groundAt(
    Offset point, {
    double maxDistanceM = 5000,
  }) {
    final level = unroll(point);
    final below = level.dy - horizonY;
    // At or above the horizon there is no ground along that ray.
    if (below <= 0) return null;

    // How far the ray is tilted down from level.
    final depression =
        math.atan((below / (size.height / 2)) * math.tan(_halfFovV));
    if (depression <= 0) return null;

    final distance = cameraHeightM / math.tan(depression);
    if (!distance.isFinite || distance <= 0) return null;

    // Horizontal angle off the centre of the image, undoing the tan mapping.
    final acrossFromCentre = (level.dx - size.width / 2) / (size.width / 2);
    final rel = math.atan(acrossFromCentre * math.tan(_halfFovH));

    return (
      bearingDeg: (headingDeg + rel * 180 / math.pi) % 360,
      distanceM: math.min(distance, maxDistanceM),
    );
  }

  /// How wide something [widthM] across appears at [distanceM], in pixels.
  ///
  /// Used to shrink beams and rings with distance instead of drawing them
  /// all the same size.
  double apparentWidth(double widthM, double distanceM) {
    final safeDistance = math.max(distanceM, 1.0);
    final angle = 2 * math.atan((widthM / 2) / safeDistance);
    return (angle / (_halfFovH * 2)) * size.width;
  }
}
