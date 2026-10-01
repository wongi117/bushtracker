import 'dart:math' as math;
import 'dart:ui' show Offset, Rect, Size;

import 'package:latlong2/latlong.dart';

import 'package:bush_track/core/models/waypoint.dart';
import 'package:bush_track/features/ar/services/ar_compass_service.dart';
import 'package:bush_track/features/ar/services/ar_projection.dart';

/// One pin as it appears through the camera this frame.
///
/// The painter and the tap handler both need the same geometry, and working it
/// out twice is how they come to disagree: a label drawn in one place and
/// tappable in another is worse than a label that cannot be tapped at all,
/// because it looks like the tap was ignored. So it is worked out once, here,
/// and handed to both.
class ArTarget {
  const ArTarget({
    required this.waypoint,
    required this.base,
    required this.beamPixels,
    required this.bearingDeg,
    required this.distanceM,
    required this.tapTarget,
    required this.tapRadius,
  });

  final Waypoint waypoint;

  /// Where the pin's patch of ground lands on the image.
  final Offset base;

  /// How tall its beam stands from there, in pixels.
  final double beamPixels;

  final double bearingDeg;
  final double distanceM;

  /// The whole extent of the pin on screen, beam and label. Used for layout
  /// questions; [hotSpots] is what a tap is actually measured against.
  final Rect tapTarget;

  /// How close a finger has to get to a hot spot. Half of the minimum touch
  /// size, so the two together make a target at least that wide.
  final double tapRadius;

  /// The places a tap counts: the foot of the beam, and the label above it.
  List<Offset> get hotSpots => [base, beamTop];

  /// The top of the beam, where the label sits.
  Offset get beamTop => Offset(base.dx, base.dy - beamPixels);
}

/// Work out where every visible pin lands, nearest last.
///
/// Ordered farthest first, matching the order they are drawn, so a nearer pin
/// paints over a farther one. [hitTest] then searches from the end, which is
/// how a tap on two overlapping labels picks the one on top.
List<ArTarget> buildArTargets({
  required List<Waypoint> waypoints,
  required LatLng currentLocation,
  required ArProjection projection,
  required Size size,
  required double beamHeightM,
  required double minBeamPixels,
  double minTapSize = 48,
}) {
  final targets = <ArTarget>[];

  for (final wp in waypoints) {
    if (wp.latitude == null || wp.longitude == null) continue;
    final position = LatLng(wp.latitude!, wp.longitude!);
    // The static form, so this needs no Riverpod Ref and can be tested on
    // its own. The instance methods are only wrappers around these.
    final bearing = ARCompassService.staticBearing(currentLocation, position);
    if (!projection.isInView(bearing)) continue;

    final distance = ARCompassService.staticDistance(currentLocation, position);
    final base = projection.project(bearing, distance);
    final beamPixels = math.max(
      projection.screenY(distance) -
          projection.screenY(distance, metresAboveGround: beamHeightM),
      minBeamPixels,
    );

    if (!base.dx.isFinite || !base.dy.isFinite) continue;

    // Two places a finger can land: the foot of the beam, and its label at
    // the top. Not the whole length of it — a pin ten metres away throws a
    // 60 m beam clean off the top of the screen, and a tap bar that long
    // swallows every distant label sharing that column, making them
    // unreachable. Two hot spots keep a near pin and a far one on the same
    // bearing both selectable, each where it actually appears.
    final top = base.dy - beamPixels;
    final rect = Rect.fromLTRB(
      base.dx - minTapSize / 2,
      math.min(top, base.dy) - minTapSize / 2,
      base.dx + minTapSize / 2,
      math.max(top, base.dy) + minTapSize / 2,
    );

    targets.add(ArTarget(
      waypoint: wp,
      base: base,
      beamPixels: beamPixels,
      bearingDeg: bearing,
      distanceM: distance,
      tapTarget: rect,
      tapRadius: minTapSize / 2,
    ));
  }

  // Farthest first, so nearer pins draw — and get picked — on top.
  targets.sort((a, b) => b.distanceM.compareTo(a.distanceM));
  return targets;
}

/// Which pin a tap at [point] meant, or null for none.
///
/// Measured to the nearest hot spot of each pin — the foot of its beam or its
/// label — and the closest wins. Where two pins genuinely sit on top of each
/// other the nearer one is in front and is the one picked, which is both what
/// the eye expects and what was asked for. Where they only share a column, each
/// is still reachable at its own label.
///
/// [slop] is how far outside a hot spot still counts, so a beam a few pixels
/// wide is not unhittable.
ArTarget? hitTest(
  List<ArTarget> targets,
  Offset point, {
  double slop = 24,
}) {
  ArTarget? best;
  var bestScore = double.infinity;

  for (final t in targets) {
    final reach = t.tapRadius + slop;
    var nearest = double.infinity;
    for (final spot in t.hotSpots) {
      final away = (spot - point).distance;
      if (away < nearest) nearest = away;
    }
    if (nearest > reach) continue;

    // Ties go to the nearer pin: it is the one drawn in front.
    final score = nearest + t.distanceM * 0.0001;
    if (score < bestScore) {
      bestScore = score;
      best = t;
    }
  }

  return best;
}
