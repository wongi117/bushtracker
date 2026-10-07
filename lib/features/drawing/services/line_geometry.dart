import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// The arithmetic behind the drawing tools, with no map widget in it.
///
/// Kept apart from any overlay on purpose: the map widget may yet change (the
/// Mapbox SDK question, PINAGE_BUILD_PLAN_4.md 5.2 Option B), and everything
/// here -- lengths, bearings, simplification, snapping, undo -- has to survive
/// that unchanged.

/// Not rounded. latlong2's default rounds every distance to the metre, which
/// is fine for one leg and wrong summed over a few hundred freehand points.
const Distance _distance = Distance(roundResult: false);

/// One leg of a drawn line.
class LineSegment {
  final LatLng from;
  final LatLng to;

  /// Ellipsoidal (Vincenty) length in metres.
  final double metres;

  /// Initial bearing from [from] to [to], degrees from true north, 0 to <360.
  ///
  /// Initial, not average: on a long leg the bearing changes along the way,
  /// and this is the one to set off on. Never averaged with its neighbours --
  /// bearings are circular, and 350 and 10 average to 180.
  final double bearing;

  const LineSegment(this.from, this.to, this.metres, this.bearing);
}

class LineMeasure {
  const LineMeasure._();

  static List<LineSegment> segments(List<LatLng> points) => [
        for (var i = 1; i < points.length; i++)
          LineSegment(points[i - 1], points[i],
              _distance(points[i - 1], points[i]), bearing(points[i - 1], points[i])),
      ];

  static double totalMetres(List<LatLng> points) {
    var total = 0.0;
    for (var i = 1; i < points.length; i++) {
      total += _distance(points[i - 1], points[i]);
    }
    return total;
  }

  /// Degrees from true north, normalised to 0 to <360.
  static double bearing(LatLng a, LatLng b) =>
      (_distance.bearing(a, b) % 360 + 360) % 360;

  /// Eight-point compass name for a bearing, for a label beside the number.
  static String compassPoint(double bearing) {
    const names = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    return names[(((bearing % 360) + 22.5) ~/ 45) % 8];
  }
}

/// Ramer-Douglas-Peucker, with the tolerance in metres.
///
/// A finger drawing a stroke reports a point every frame -- hundreds for a
/// short line, most of them saying nothing the line's shape does not already
/// say. This keeps the fewest points such that **no original point is further
/// than [toleranceMetres] from the simplified line**, which is the property the
/// tests hold it to. The ends are always kept.
///
/// Distances are taken on a local flat projection centred on the stroke. Over
/// the size of anything drawn by hand that is accurate to well under a percent
/// of the tolerance, and it keeps the comparison in metres rather than in
/// degrees, which are not the same size east-west as north-south.
class LineSimplifier {
  const LineSimplifier._();

  static List<LatLng> simplify(List<LatLng> points, double toleranceMetres) {
    if (points.length < 3) return List.of(points);

    final plane = _LocalPlane.around(points);
    final xy = points.map(plane.project).toList();
    final keep = List<bool>.filled(points.length, false)
      ..[0] = true
      ..[points.length - 1] = true;

    // Iterative, not recursive: a long freehand stroke is thousands of points
    // and recursion that deep is a stack overflow waiting for a long walk.
    final stack = <(int, int)>[(0, points.length - 1)];
    while (stack.isNotEmpty) {
      final (start, end) = stack.removeLast();
      var worst = -1.0;
      var worstIndex = -1;
      for (var i = start + 1; i < end; i++) {
        final d = _distanceToSegment(xy[i], xy[start], xy[end]);
        if (d > worst) {
          worst = d;
          worstIndex = i;
        }
      }
      if (worstIndex != -1 && worst > toleranceMetres) {
        keep[worstIndex] = true;
        stack
          ..add((start, worstIndex))
          ..add((worstIndex, end));
      }
    }

    return [
      for (var i = 0; i < points.length; i++)
        if (keep[i]) points[i],
    ];
  }

  /// The furthest any of [original] lies from the polyline [simplified], in
  /// metres. Exposed so the fidelity guarantee can be checked, in the tests
  /// and anywhere else that wants to know.
  static double maxDeviationMetres(List<LatLng> original, List<LatLng> simplified) {
    if (simplified.isEmpty) return double.infinity;
    final plane = _LocalPlane.around(original);
    final line = simplified.map(plane.project).toList();
    var worst = 0.0;
    for (final p in original.map(plane.project)) {
      var best = double.infinity;
      if (line.length == 1) {
        best = (p - line[0]).length;
      }
      for (var i = 1; i < line.length; i++) {
        best = math.min(best, _distanceToSegment(p, line[i - 1], line[i]));
      }
      worst = math.max(worst, best);
    }
    return worst;
  }

  static double _distanceToSegment(_Xy p, _Xy a, _Xy b) {
    final ab = b - a;
    final len2 = ab.x * ab.x + ab.y * ab.y;
    if (len2 == 0) return (p - a).length;
    final t = (((p - a).x * ab.x + (p - a).y * ab.y) / len2).clamp(0.0, 1.0);
    return (p - _Xy(a.x + ab.x * t, a.y + ab.y * t)).length;
  }
}

class _Xy {
  final double x, y;
  const _Xy(this.x, this.y);
  _Xy operator -(_Xy o) => _Xy(x - o.x, y - o.y);
  double get length => math.sqrt(x * x + y * y);
}

/// Equirectangular projection about the middle of a set of points, in metres.
class _LocalPlane {
  static const _earthRadius = 6371008.8;
  final double lat0, lon0, cosLat0;

  _LocalPlane(this.lat0, this.lon0) : cosLat0 = math.cos(lat0 * math.pi / 180);

  factory _LocalPlane.around(List<LatLng> points) {
    var lat = 0.0, lon = 0.0;
    for (final p in points) {
      lat += p.latitude;
      lon += p.longitude;
    }
    return _LocalPlane(lat / points.length, lon / points.length);
  }

  _Xy project(LatLng p) => _Xy(
        (p.longitude - lon0) * math.pi / 180 * _earthRadius * cosLat0,
        (p.latitude - lat0) * math.pi / 180 * _earthRadius,
      );
}

/// Something a vertex can snap to: a pin, a waypoint, another line's end.
class SnapTarget {
  final LatLng point;
  final String? label;

  /// Whatever the caller uses to tell targets apart, such as a waypoint id.
  final Object? key;

  const SnapTarget(this.point, {this.label, this.key});
}

class Snapping {
  const Snapping._();

  /// The nearest target within [radiusMetres] of [tap], or null.
  ///
  /// The radius is in metres so this stays free of any map widget; the overlay
  /// turns "a fingertip's width on screen" into metres at the current zoom.
  static SnapTarget? nearest(
      LatLng tap, Iterable<SnapTarget> targets, double radiusMetres) {
    SnapTarget? best;
    var bestMetres = radiusMetres;
    for (final t in targets) {
      final d = _distance(tap, t.point);
      if (d <= bestMetres) {
        best = t;
        bestMetres = d;
      }
    }
    return best;
  }
}

/// A line being drawn or edited, with undo.
///
/// Every change is one undo step, including a whole freehand stroke and a
/// whole vertex drag: undoing a drag one frame at a time would take a hundred
/// presses to put a vertex back.
class LineDraft {
  LineDraft([List<LatLng> initial = const []]) : _history = [List.of(initial)];

  final List<List<LatLng>> _history;
  bool _dragging = false;

  List<LatLng> get points => List.unmodifiable(_history.last);
  bool get canUndo => _history.length > 1;
  bool get isEmpty => _history.last.isEmpty;

  void _push(List<LatLng> next) {
    _dragging = false;
    _history.add(next);
  }

  void add(LatLng p) => _push([..._history.last, p]);

  /// A finished freehand stroke, appended as one step.
  void addStroke(List<LatLng> stroke) {
    if (stroke.isEmpty) return;
    _push([..._history.last, ...stroke]);
  }

  /// Put a vertex between [index] - 1 and [index].
  void insert(int index, LatLng p) {
    final cur = _history.last;
    if (index <= 0 || index > cur.length) return;
    _push([...cur]..insert(index, p));
  }

  void remove(int index) {
    final cur = _history.last;
    if (index < 0 || index >= cur.length) return;
    _push([...cur]..removeAt(index));
  }

  /// Move a vertex. Call repeatedly during a drag and then [endDrag]; the
  /// whole drag is a single undo step.
  void drag(int index, LatLng p) {
    final cur = _history.last;
    if (index < 0 || index >= cur.length) return;
    if (!_dragging) {
      _push([...cur]);
      _dragging = true;
    }
    _history.last[index] = p;
  }

  void endDrag() => _dragging = false;

  void undo() {
    _dragging = false;
    if (canUndo) _history.removeLast();
  }

  /// Where to offer a new vertex on each segment: its midpoint. Close enough
  /// to the true geodesic midpoint over anything drawn by hand.
  List<LatLng> get midpoints {
    final p = _history.last;
    return [
      for (var i = 1; i < p.length; i++)
        LatLng((p[i - 1].latitude + p[i].latitude) / 2,
            (p[i - 1].longitude + p[i].longitude) / 2),
    ];
  }
}
