import 'dart:math' as math;
import 'dart:ui' show Offset, Path;

import 'package:latlong2/latlong.dart' hide Path;

import 'package:bush_track/core/models/geofence.dart';
import 'package:bush_track/features/ar/services/ar_compass_service.dart';
import 'package:bush_track/features/ar/services/ar_projection.dart';

/// How a zone stands up in AR (Phase 4.5).
///
/// Asked for from the field: hazard and heritage zones as giant walls you
/// cannot miss -- a no-go zone -- and ordinary boundaries as a small wall on
/// the ground, only once you are within 20 m of them.
enum WallStyle {
  /// Tall, striped, seen from a long way off. A place not to go.
  noGo,

  /// Knee-high along the ground, and only close up.
  low,
}

/// Hazard, heritage and "No entry" are no-go; everything else is low.
///
/// "No entry" is included because its own name already says no-go. Kept here,
/// in one place, so changing which categories count is one line.
WallStyle wallStyleFor(ZoneCategory c) => switch (c) {
      ZoneCategory.hazard ||
      ZoneCategory.heritage ||
      ZoneCategory.exclusion =>
        WallStyle.noGo,
      _ => WallStyle.low,
    };

/// The numbers behind the two styles, in one place so they can be tuned
/// from the field without hunting for them.
class WallSpec {
  const WallSpec._();

  /// Tall enough to stand clear of scrub and read from across a paddock.
  static const double noGoHeightM = 30;

  /// A no-go wall is never drawn shorter than this on screen.
  ///
  /// Physically right, 30 m is about 36 px at 250 m and 9 px at a kilometre on
  /// a phone screen -- a sliver, not the wall you cannot miss that was asked
  /// for. Like a pin's beam, it keeps a minimum on-screen height; close up it
  /// is its true 30 m.
  static const double noGoMinPixels = 140;

  /// Knee height: a line on the ground you can see, not a fence.
  static const double lowHeightM = 0.8;

  /// No-go walls are drawn out to here. The plan's ~1.5 km: beyond it a wall
  /// is a sliver on the horizon and only costs frame rate.
  static const double noGoRangeM = 1500;

  /// A low wall appears once you are this close to the boundary.
  static const double lowShowWithinM = 20;

  /// ...and is drawn out to here, so you see the stretch around you rather
  /// than a stub at your feet.
  static const double lowRangeM = 60;
}

/// One upright piece of wall, ready to paint.
class WallPanel {
  final Geofence zone;
  final WallStyle style;

  /// Ground and top of each end, on the camera image.
  final Offset bottomA, bottomB, topB, topA;

  /// Distance to the nearer end, for drawing far panels first.
  final double distanceM;

  const WallPanel({
    required this.zone,
    required this.style,
    required this.bottomA,
    required this.bottomB,
    required this.topB,
    required this.topA,
    required this.distanceM,
  });

  Path get path => Path()
    ..moveTo(bottomA.dx, bottomA.dy)
    ..lineTo(bottomB.dx, bottomB.dy)
    ..lineTo(topB.dx, topB.dy)
    ..lineTo(topA.dx, topA.dy)
    ..close();
}

/// A zone's name and distance, where its wall is.
class WallLabel {
  final Geofence zone;
  final WallStyle style;
  final Offset at;
  final double edgeDistanceM;

  const WallLabel(this.zone, this.style, this.at, this.edgeDistanceM);
}

class ArWalls {
  final List<WallPanel> panels;
  final List<WallLabel> labels;

  /// No-go zones the phone is standing in, as far as the fix can tell.
  final List<Geofence> insideNoGo;

  const ArWalls(this.panels, this.labels, this.insideNoGo);

  static const empty = ArWalls([], [], []);
}

/// Every wall that should be on screen this frame.
///
/// [accuracyM] decides whether "you are inside" can be said at all; see
/// insideIfKnown. Only zones the caller passes in are considered, so hiding
/// or project-filtering happens before this, as on the map.
ArWalls buildArWalls({
  required Iterable<Geofence> zones,
  required LatLng here,
  required ArProjection projection,
  double accuracyM = 0,
}) {
  final panels = <WallPanel>[];
  final labels = <WallLabel>[];
  final inside = <Geofence>[];

  for (final zone in zones) {
    if (!zone.isActive) continue;
    final style = wallStyleFor(zone.category);
    final edge = zone.distanceToEdgeMetres(here);

    if (style == WallStyle.noGo &&
        accuracyM > 0 &&
        accuracyM < edge &&
        zone.contains(here)) {
      inside.add(zone);
    }

    final range =
        style == WallStyle.noGo ? WallSpec.noGoRangeM : WallSpec.lowRangeM;
    if (style == WallStyle.low && edge > WallSpec.lowShowWithinM) continue;
    if (edge > range) continue;

    final height =
        style == WallStyle.noGo ? WallSpec.noGoHeightM : WallSpec.lowHeightM;
    final ring = _ring(zone);
    WallPanel? nearest;

    for (var i = 0; i < ring.length; i++) {
      final a = ring[i], b = ring[(i + 1) % ring.length];
      for (final piece in _pieces(a, b, here, range)) {
        final panel = _panel(zone, style, piece.$1, piece.$2, here, projection,
            height);
        if (panel == null) continue;
        panels.add(panel);
        if (nearest == null || panel.distanceM < nearest.distanceM) {
          nearest = panel;
        }
      }
    }

    if (nearest != null) {
      labels.add(WallLabel(
        zone,
        style,
        Offset((nearest.topA.dx + nearest.topB.dx) / 2,
            math.min(nearest.topA.dy, nearest.topB.dy)),
        edge,
      ));
    }
  }

  // Far first, so a near wall paints over a far one.
  panels.sort((a, b) => b.distanceM.compareTo(a.distanceM));
  return ArWalls(panels, labels, inside);
}

/// The wall a tap at [point] landed on, nearest wall first.
Geofence? wallAt(ArWalls walls, Offset point) {
  for (final p in walls.panels.reversed) {
    if (p.path.contains(point)) return p.zone;
  }
  return null;
}

/// The boundary as a closed ring: a polygon's corners, or a circle traced
/// with a point every ~10 m (at least 24, at most 180).
List<LatLng> _ring(Geofence zone) {
  if (zone.isPolygon) return zone.points;
  final n = (2 * math.pi * zone.radiusMeters / 10).round().clamp(24, 180);
  const d = Distance(roundResult: false);
  return [
    for (var i = 0; i < n; i++) d.offset(zone.centre, zone.radiusMeters, i * 360 / n),
  ];
}

/// An edge cut into pieces short enough to stay straight on screen, finer
/// close to you -- a 25 m piece at your feet would bend through half the
/// view -- and dropping whatever lies beyond [range].
Iterable<(LatLng, LatLng)> _pieces(
    LatLng a, LatLng b, LatLng here, double range) sync* {
  const d = Distance(roundResult: false);
  final length = d(a, b);
  if (length == 0) return;
  var t = 0.0;
  var from = a;
  while (t < 1) {
    final away = d(here, from);
    final step = (away * 0.15).clamp(1.0, 50.0) / length;
    final next = math.min(1.0, t + step);
    final to = LatLng(a.latitude + (b.latitude - a.latitude) * next,
        a.longitude + (b.longitude - a.longitude) * next);
    if (away <= range || d(here, to) <= range) yield (from, to);
    t = next;
    from = to;
  }
}

/// A piece of wall projected onto the image, or null if it cannot be drawn
/// truthfully this frame.
///
/// Both ends must lie within about 75 degrees of where the camera points:
/// past that the projection's tan runs away and a piece would smear across
/// the screen. At least one end must be in view, or there is nothing to draw.
WallPanel? _panel(Geofence zone, WallStyle style, LatLng a, LatLng b,
    LatLng here, ArProjection projection, double height) {
  final bearingA = ARCompassService.staticBearing(here, a);
  final bearingB = ARCompassService.staticBearing(here, b);
  const limit = 1.3; // radians, ~75 degrees
  if (projection.relativeBearing(bearingA).abs() > limit ||
      projection.relativeBearing(bearingB).abs() > limit) {
    return null;
  }
  if (!projection.isInView(bearingA) && !projection.isInView(bearingB)) {
    return null;
  }
  final distA = ARCompassService.staticDistance(here, a);
  final distB = ARCompassService.staticDistance(here, b);
  final minPixels = style == WallStyle.noGo ? WallSpec.noGoMinPixels : 0.0;

  // Worked out level, then rolled: the minimum height is "up" on the level
  // frame, and has to turn with the picture like everything else.
  (Offset, Offset) ends(double bearing, double distance) {
    final x = projection.screenX(bearing);
    final bottom = projection.screenY(distance);
    final top = math.min(
        projection.screenY(distance, metresAboveGround: height),
        bottom - minPixels);
    return (
      projection.applyRoll(Offset(x, bottom)),
      projection.applyRoll(Offset(x, top)),
    );
  }

  final (bottomA, topA) = ends(bearingA, distA);
  final (bottomB, topB) = ends(bearingB, distB);
  final panel = WallPanel(
    zone: zone,
    style: style,
    bottomA: bottomA,
    bottomB: bottomB,
    topB: topB,
    topA: topA,
    distanceM: math.min(distA, distB),
  );
  for (final o in [panel.bottomA, panel.bottomB, panel.topA, panel.topB]) {
    if (!o.dx.isFinite || !o.dy.isFinite) return null;
  }
  return panel;
}
