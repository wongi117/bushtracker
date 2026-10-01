import 'package:bush_track/core/services/heading/one_euro_filter.dart';

/// Which way to point the arrow that marks where you are.
///
/// Two sensors answer this and neither answers it alone. The GPS course over
/// ground is what you want while moving — it is referenced to true north and it
/// describes where the vehicle is actually going, whatever the phone is doing in
/// the cradle. It is also meaningless when you stop: standing still, the course
/// is whatever direction the last metre of noise happened to point, so the arrow
/// spins. The compass is the opposite: steady at a standstill, and describing
/// where the handset is pointed rather than where you are going.
///
/// So: course while moving, compass while stopped, with hysteresis across the
/// changeover so the arrow does not flap between two different answers while
/// crawling, and smoothing so neither source jitters.
class TravelHeading {
  TravelHeading({
    this.startTrustingCourseMs = 1.4, // 5 km/h
    this.stopTrustingCourseMs = 0.8, // 3 km/h
  });

  /// Above this speed the GPS course is trusted. About 5 km/h.
  final double startTrustingCourseMs;

  /// And below this it is not. Lower than [startTrustingCourseMs] on purpose:
  /// one threshold for both would have the arrow swapping sources back and
  /// forth every few seconds while walking at exactly the changeover speed,
  /// and the two sources rarely agree — a phone in a cradle points at the
  /// windscreen while the ute goes up the road.
  final double stopTrustingCourseMs;

  final _filter = OneEuroAngleFilter();

  bool _usingCourse = false;
  double? _smoothed;

  /// The last answer, or null before there is one.
  double? get degrees => _smoothed;

  /// True when the arrow is showing where you are going rather than where the
  /// handset is pointed. Worth knowing on screen: the two mean different things.
  bool get fromCourse => _usingCourse;

  /// Feed in what the sensors say; get back the bearing to draw, or null if
  /// neither sensor has anything usable yet.
  ///
  /// [gpsCourseDeg] is course over ground, already true-north referenced.
  /// [compassDeg] is the device compass, which needs [declinationDeg] adding to
  /// bring it from magnetic to true north.
  double? update({
    required double speedMs,
    required double dt,
    double? gpsCourseDeg,
    double? compassDeg,
    double declinationDeg = 0,
  }) {
    // Hysteresis: it takes more speed to start trusting the course than to
    // keep trusting it.
    if (_usingCourse) {
      if (speedMs < stopTrustingCourseMs) _usingCourse = false;
    } else {
      if (speedMs >= startTrustingCourseMs) _usingCourse = true;
    }

    double? target;
    if (_usingCourse && gpsCourseDeg != null) {
      target = gpsCourseDeg;
    } else if (compassDeg != null) {
      target = compassDeg + declinationDeg;
    } else if (gpsCourseDeg != null && speedMs >= startTrustingCourseMs) {
      // No compass on this handset, but we are moving: course is better than
      // an arrow stuck pointing north.
      target = gpsCourseDeg;
      _usingCourse = true;
    }

    if (target == null) return _smoothed;

    _smoothed = _filter.filter(target, dt);
    return _smoothed;
  }

  void reset() {
    _filter.reset();
    _smoothed = null;
    _usingCourse = false;
  }
}

/// Magnetic declination — how far a compass needle sits from true north.
///
/// The GPS course needs no correction, so this only matters for the arrow while
/// you are standing still, and for the compass rose.
///
/// This is a coarse linear fit over the Australian mainland, not a geomagnetic
/// model. Across the continent the real figure runs from about 0 degrees in the
/// west to about 12 degrees east in the far south-east, and this gets within a
/// couple of degrees of that — which is well inside the handset compass's own
/// error, measured at a degree or two of wander with the phone sitting still on
/// a bench. Outside those bounds it returns zero rather than extrapolating a
/// number it has no basis for; a proper fix would be the WMM or IGRF model, and
/// is worth doing if the app is ever used outside Australia.
class MagneticDeclination {
  const MagneticDeclination._();

  /// Degrees to add to a magnetic bearing to get a true one.
  static double forPosition(double latitude, double longitude) {
    final inAustralia = latitude >= -44 &&
        latitude <= -10 &&
        longitude >= 112 &&
        longitude <= 154;
    if (!inAustralia) return 0;

    // Roughly: declination grows eastwards, and grows faster the further south.
    final eastwards = (longitude - 112) / 42; // 0 at the west coast, 1 at the east
    final southwards = (-latitude - 10) / 34; // 0 at the top, 1 at the bottom
    return eastwards * (6 + 6 * southwards);
  }
}
