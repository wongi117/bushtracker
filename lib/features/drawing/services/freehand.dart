import 'package:latlong2/latlong.dart';

import 'package:bush_track/features/drawing/services/line_geometry.dart';

/// A freehand drawing session: finished strokes, the one under the finger,
/// and the pen. No map widget in here, for the same reason as
/// line_geometry.dart.
class FreehandSession {
  FreehandSession({this.colour = '#FF6B00', this.width = 4});

  final List<List<LatLng>> _strokes = [];
  List<LatLng>? _current;

  String colour;
  double width;

  /// True while the map is locked for drawing; false while it pans.
  bool drawing = true;

  List<List<LatLng>> get strokes =>
      List.unmodifiable(_strokes.map(List<LatLng>.unmodifiable));

  /// The stroke under the finger, raw, or null between strokes.
  List<LatLng>? get current =>
      _current == null ? null : List.unmodifiable(_current!);

  bool get isEmpty => _strokes.isEmpty && _current == null;
  bool get canUndo => _strokes.isNotEmpty;

  double get totalMetres =>
      _strokes.fold(0.0, (m, s) => m + LineMeasure.totalMetres(s));

  void beginStroke(LatLng p) => _current = [p];

  void extendStroke(LatLng p) => _current?.add(p);

  /// End the stroke under the finger and keep it, simplified.
  ///
  /// [toleranceMetres] should be what a couple of screen pixels cover at the
  /// zoom it was drawn: the stroke then looks the same as it did under the
  /// finger, at a fraction of the points. A tap -- a stroke that never went
  /// anywhere -- is dropped rather than kept as a dot nobody meant.
  ///
  /// Returns the stroke as kept, or null if it was dropped.
  List<LatLng>? endStroke(double toleranceMetres) {
    final raw = _current;
    _current = null;
    if (raw == null || raw.length < 2) return null;
    final kept = LineSimplifier.simplify(raw, toleranceMetres);
    if (kept.length < 2 || LineMeasure.totalMetres(kept) == 0) return null;
    _strokes.add(kept);
    return kept;
  }

  /// A stroke abandoned part way, as when a second finger comes down.
  void cancelStroke() => _current = null;

  /// Takes off the last whole stroke.
  void undo() {
    _current = null;
    if (_strokes.isNotEmpty) _strokes.removeLast();
  }
}
