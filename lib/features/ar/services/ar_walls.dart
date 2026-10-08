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

/// Every number behind the walls, in one place, to tune from the field.
class WallSpec {
  const WallSpec._();

  /// How tall a no-go wall stands, in metres.
  static const double noGoHeightM = 30;

  /// A no-go wall is never drawn shorter than this on screen.
  ///
  /// Physically right, 30 m is a sliver at a kilometre; like a pin's beam it
  /// keeps a minimum on-screen height. Close up it is its true height.
  static const double noGoMinPixels = 140;

  /// Knee height: a line on the ground you can see, not a fence.
  static const double lowHeightM = 0.8;

  /// No-go walls are drawn out to here. Beyond it a wall is a sliver on the
  /// horizon and only costs frame rate.
  static const double noGoRangeM = 1500;

  /// A low wall appears once you are this close to the boundary...
  static const double lowShowWithinM = 20;

  /// ...and is drawn out to here, so you see the stretch around you.
  static const double lowRangeM = 60;

  /// Closer than this, a no-go wall is drawn stronger and pulses.
  static const double nearM = 50;

  /// Warning stripes: one band this wide in every [stripePeriodM], running
  /// diagonally across the face, in metres of wall -- so they shrink with
  /// distance like paint on a real wall.
  static const double stripePeriodM = 6;
  static const double stripeWidthM = 3;

  /// Past this, stripes would be a few pixels apart; the fill alone reads.
  static const double stripeRangeM = 400;

  /// The red tint on the ground in front of a no-go wall: how deep, and out
  /// to what distance it is drawn.
  static const double glowDepthM = 4;
  static const double glowRangeM = 150;

  /// Where the label sits on the wall face: about eye level.
  static const double labelHeightM = 2;
}

/// One upright piece of wall, ready to paint.
class WallPanel {
  final Geofence zone;
  final WallStyle style;

  /// Ground and top of each end, on the camera image.
  final Offset bottomA, bottomB, topB, topA;

  /// Distance to the nearer end, for drawing far panels first.
  final double distanceM;

  /// Warning stripes on this piece's face, each a polygon on the image.
  final List<List<Offset>> stripes;

  /// The tinted strip of ground in front of it: the base, then the near edge.
  final List<Offset>? glow;

  const WallPanel({
    required this.zone,
    required this.style,
    required this.bottomA,
    required this.bottomB,
    required this.topB,
    required this.topA,
    required this.distanceM,
    this.stripes = const [],
    this.glow,
  });

  bool get isNear => distanceM < WallSpec.nearM;

  Path get path => Path()
    ..moveTo(bottomA.dx, bottomA.dy)
    ..lineTo(bottomB.dx, bottomB.dy)
    ..lineTo(topB.dx, topB.dy)
    ..lineTo(topA.dx, topA.dy)
    ..close();
}

/// A zone's name and distance, pinned to its wall.
class WallLabel {
  final Geofence zone;
  final WallStyle style;

  /// On the wall face, [WallSpec.labelHeightM] up the nearest piece that is
  /// on screen.
  final Offset at;
  final double edgeDistanceM;

  const WallLabel(this.zone, this.style, this.at, this.edgeDistanceM);

  bool get isNear => edgeDistanceM < WallSpec.nearM;

  /// Larger close up; never too small to read, never too big to fit.
  double get fontSize {
    final t = ((edgeDistanceM - 30) / (600 - 30)).clamp(0.0, 1.0);
    return 22 - t * (22 - 13);
  }
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

    final wall = _WallBuilder(zone, style, here, projection);
    final ring = _ring(zone);
    WallPanel? labelled;

    // Metres round the boundary, so stripes run on unbroken from one piece to
    // the next -- including across a stretch skipped for being out of range.
    var along = 0.0;
    for (var i = 0; i < ring.length; i++) {
      final a = ring[i], b = ring[(i + 1) % ring.length];
      for (final (from, to, startsAt) in _pieces(a, b, here, range)) {
        final length = _d(from, to);
        final panel = wall.panel(from, to, along + startsAt, length);
        if (panel == null) continue;
        panels.add(panel);
        final mid = (panel.bottomA.dx + panel.bottomB.dx) / 2;
        final onScreen = mid >= 0 && mid <= projection.size.width;
        if (onScreen &&
            (labelled == null || panel.distanceM < labelled.distanceM)) {
          labelled = panel;
        }
      }
      along += _d(a, b);
    }

    if (labelled != null) {
      labels.add(WallLabel(zone, style, wall.labelPoint(labelled), edge));
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

const Distance _distance = Distance(roundResult: false);
double _d(LatLng a, LatLng b) => _distance(a, b);

LatLng _lerp(LatLng a, LatLng b, double t) => LatLng(
    a.latitude + (b.latitude - a.latitude) * t,
    a.longitude + (b.longitude - a.longitude) * t);

/// The boundary as a closed ring: a polygon's corners, or a circle traced
/// with a point every ~10 m (at least 24, at most 180).
List<LatLng> _ring(Geofence zone) {
  if (zone.isPolygon) return zone.points;
  final n = (2 * math.pi * zone.radiusMeters / 10).round().clamp(24, 180);
  return [
    for (var i = 0; i < n; i++)
      _distance.offset(zone.centre, zone.radiusMeters, i * 360 / n),
  ];
}

/// An edge cut into pieces short enough to stay straight on screen -- finer
/// close to you, since a 25 m piece at your feet would bend through half the
/// view -- with whatever lies beyond [range] left out. Each piece comes with
/// how far along the edge it starts, in metres.
Iterable<(LatLng, LatLng, double)> _pieces(
    LatLng a, LatLng b, LatLng here, double range) sync* {
  final length = _d(a, b);
  if (length == 0) return;
  var t = 0.0;
  var from = a;
  while (t < 1) {
    final away = _d(here, from);
    final step = (away * 0.15).clamp(1.0, 50.0) / length;
    final next = math.min(1.0, t + step);
    final to = _lerp(a, b, next);
    if (away <= range || _d(here, to) <= range) yield (from, to, t * length);
    t = next;
    from = to;
  }
}

/// Projects one zone's wall, piece by piece.
class _WallBuilder {
  _WallBuilder(this.zone, this.style, this.here, this.p)
      : height = style == WallStyle.noGo
            ? WallSpec.noGoHeightM
            : WallSpec.lowHeightM,
        minPixels = style == WallStyle.noGo ? WallSpec.noGoMinPixels : 0;

  final Geofence zone;
  final WallStyle style;
  final LatLng here;
  final ArProjection p;
  final double height;
  final double minPixels;

  /// Ground and top of the wall where it stands at [at], on the image.
  ///
  /// The base is the point on the ground, projected from the camera height
  /// (ArProjection.cameraHeightM, 1.5 m): the wall stands on the ground, it
  /// does not float. Worked out level, then rolled, because the minimum
  /// height is "up" in the level frame and has to turn with the picture.
  /// On a vertical line at a fixed distance, height is linear in metres on
  /// screen, so any point up the wall is a straight blend of these two.
  (Offset bottom, Offset top) ends(LatLng at) {
    final bearing = ARCompassService.staticBearing(here, at);
    final distance = ARCompassService.staticDistance(here, at);
    final x = p.screenX(bearing);
    final bottom = p.screenY(distance);
    final top = math.min(
        p.screenY(distance, metresAboveGround: height), bottom - minPixels);
    return (p.applyRoll(Offset(x, bottom)), p.applyRoll(Offset(x, top)));
  }

  /// A piece of wall from [a] to [b], or null if it cannot be drawn
  /// truthfully this frame. [along] is how far round the boundary [a] is.
  ///
  /// Both ends must lie within about 75 degrees of where the camera points:
  /// past that the projection's tan runs away and a piece would smear across
  /// the screen. At least one end must be in view.
  WallPanel? panel(LatLng a, LatLng b, double along, double length) {
    final bearingA = ARCompassService.staticBearing(here, a);
    final bearingB = ARCompassService.staticBearing(here, b);
    const limit = 1.3; // radians, ~75 degrees
    if (p.relativeBearing(bearingA).abs() > limit ||
        p.relativeBearing(bearingB).abs() > limit) {
      return null;
    }
    if (!p.isInView(bearingA) && !p.isInView(bearingB)) return null;

    final (bottomA, topA) = ends(a);
    final (bottomB, topB) = ends(b);
    for (final o in [bottomA, bottomB, topA, topB]) {
      if (!o.dx.isFinite || !o.dy.isFinite) return null;
    }
    final distance = math.min(ARCompassService.staticDistance(here, a),
        ARCompassService.staticDistance(here, b));

    final noGo = style == WallStyle.noGo;
    return WallPanel(
      zone: zone,
      style: style,
      bottomA: bottomA,
      bottomB: bottomB,
      topB: topB,
      topA: topA,
      distanceM: distance,
      stripes: noGo && distance < WallSpec.stripeRangeM
          ? _stripes(a, b, along, length)
          : const [],
      glow: noGo && distance < WallSpec.glowRangeM ? _glow(a, b) : null,
    );
  }

  /// The diagonal bands on this piece's face, in metres of wall.
  ///
  /// A band is where (metres along + metres up) falls in the first
  /// [WallSpec.stripeWidthM] of each [WallSpec.stripePeriodM]. Each band is
  /// clipped to this piece's rectangle in (along, up), and its corners are
  /// projected one by one: the stripes keep their real size, shrinking with
  /// distance like paint, and line up from one piece to the next.
  List<List<Offset>> _stripes(LatLng a, LatLng b, double along, double length) {
    if (length <= 0) return const [];
    const period = WallSpec.stripePeriodM, width = WallSpec.stripeWidthM;
    final rect = [(0.0, 0.0), (length, 0.0), (length, height), (0.0, height)];
    final cache = <double, (Offset, Offset)>{};
    Offset toScreen((double, double) uv) {
      final (u, v) = uv;
      final (bottom, top) =
          cache.putIfAbsent(u, () => ends(_lerp(a, b, u / length)));
      return Offset.lerp(bottom, top, v / height)!;
    }

    final out = <List<Offset>>[];
    final first = (along / period).floor();
    final last = ((along + length + height) / period).floor();
    for (var k = first; k <= last; k++) {
      final lo = k * period - along, hi = lo + width;
      var poly = _clip(rect, (u, v) => u + v - lo); // u + v >= lo
      poly = _clip(poly, (u, v) => hi - (u + v)); //    u + v <= hi
      if (poly.length >= 3) out.add(poly.map(toScreen).toList());
    }
    return out;
  }

  /// The strip of ground just in front of the wall, from its base to a few
  /// metres back towards you.
  List<Offset> _glow(LatLng a, LatLng b) {
    LatLng towardsYou(LatLng at) {
      final d = _d(at, here);
      if (d == 0) return at;
      return _lerp(at, here, math.min(WallSpec.glowDepthM, d * 0.5) / d);
    }

    Offset ground(LatLng at) => p.project(
        ARCompassService.staticBearing(here, at),
        ARCompassService.staticDistance(here, at));

    return [ground(a), ground(b), ground(towardsYou(b)), ground(towardsYou(a))];
  }

  /// [WallSpec.labelHeightM] up the middle of [panel]'s face.
  Offset labelPoint(WallPanel panel) {
    final bottom = Offset.lerp(panel.bottomA, panel.bottomB, 0.5)!;
    final top = Offset.lerp(panel.topA, panel.topB, 0.5)!;
    return Offset.lerp(bottom, top, WallSpec.labelHeightM / height)!;
  }
}

/// Sutherland-Hodgman against one half-plane: keeps where [inside] >= 0.
List<(double, double)> _clip(List<(double, double)> poly,
    double Function(double u, double v) inside) {
  final out = <(double, double)>[];
  for (var i = 0; i < poly.length; i++) {
    final cur = poly[i], next = poly[(i + 1) % poly.length];
    final fc = inside(cur.$1, cur.$2), fn = inside(next.$1, next.$2);
    if (fc >= 0) out.add(cur);
    if ((fc >= 0) != (fn >= 0)) {
      final t = fc / (fc - fn);
      out.add(
          (cur.$1 + (next.$1 - cur.$1) * t, cur.$2 + (next.$2 - cur.$2) * t));
    }
  }
  return out;
}
