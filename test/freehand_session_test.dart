// A freehand session: strokes kept simplified, taps dropped, one undo per
// stroke.
import 'package:bush_track/features/drawing/services/freehand.dart';
import 'package:bush_track/features/drawing/services/line_geometry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  const leonora = LatLng(-28.88, 121.33);
  LatLng at(double metres, double bearing) =>
      const Distance(roundResult: false).offset(leonora, metres, bearing);

  /// A finger dragged east, one sample per metre, with a little jitter.
  void drag(FreehandSession s, int metres) {
    s.beginStroke(leonora);
    for (var i = 1; i <= metres; i++) {
      s.extendStroke(const Distance(roundResult: false)
          .offset(at(i.toDouble(), 90), (i % 3) * 0.1, 0));
    }
  }

  test('a stroke is kept simplified and inside the tolerance', () {
    final s = FreehandSession();
    drag(s, 200);
    final raw = s.current!;
    final kept = s.endStroke(1.0)!;

    expect(kept.length, lessThan(raw.length));
    expect(LineSimplifier.maxDeviationMetres(raw, kept),
        lessThanOrEqualTo(1.0 + 1e-6));
    expect(s.strokes, hasLength(1));
    expect(s.current, isNull);
  });

  test('a tap is not a stroke', () {
    final s = FreehandSession()..beginStroke(leonora);
    expect(s.endStroke(1), isNull);
    expect(s.isEmpty, isTrue);

    // Nor is a finger that came down and went up in the same place.
    s
      ..beginStroke(leonora)
      ..extendStroke(leonora)
      ..extendStroke(leonora);
    expect(s.endStroke(1), isNull);
    expect(s.strokes, isEmpty);
  });

  test('undo takes off a whole stroke', () {
    final s = FreehandSession();
    drag(s, 50);
    s.endStroke(1);
    drag(s, 80);
    s.endStroke(1);
    expect(s.strokes, hasLength(2));

    s.undo();
    expect(s.strokes, hasLength(1));
    expect(s.totalMetres, closeTo(50, 1));
    s
      ..undo()
      ..undo();
    expect(s.isEmpty, isTrue);
  });

  test('a stroke abandoned part way leaves nothing behind', () {
    final s = FreehandSession();
    drag(s, 30);
    s.cancelStroke();
    expect(s.isEmpty, isTrue);
  });

  test('the strokes handed out cannot be edited behind the session', () {
    final s = FreehandSession();
    drag(s, 30);
    s.endStroke(1);
    expect(() => s.strokes.first.add(leonora), throwsUnsupportedError);
    expect(() => s.strokes.add(const []), throwsUnsupportedError);
  });
}
