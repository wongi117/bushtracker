// The freehand panel and layers.
import 'package:bush_track/features/drawing/presentation/freehand_drawing.dart';
import 'package:bush_track/features/drawing/services/freehand.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  const leonora = LatLng(-28.88, 121.33);
  LatLng east(double m) =>
      const Distance(roundResult: false).offset(leonora, m, 90);

  FreehandSession withStroke() {
    final s = FreehandSession()..beginStroke(leonora);
    for (var i = 1; i <= 100; i++) {
      s.extendStroke(east(i.toDouble()));
    }
    s.endStroke(0.5);
    return s;
  }

  Future<void> pump(WidgetTester tester, FreehandSession s,
      {ValueChanged<bool>? mode,
      ValueChanged<String>? colour,
      ValueChanged<double>? width}) {
    return tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: FreehandPanel(
            session: s,
            onDrawingChanged: mode ?? (_) {},
            onColour: colour ?? (_) {},
            onWidth: width ?? (_) {},
            onUndo: () {},
            onCancel: () {},
            onDone: () {},
          ),
        ),
      ),
    ));
  }

  testWidgets('says what to do before the first stroke', (tester) async {
    await pump(tester, FreehandSession());
    expect(find.text('Draw on the map with your finger'), findsOneWidget);
    final done = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(done.onPressed, isNull);
  });

  testWidgets('and in Pan mode, how to get back to drawing', (tester) async {
    await pump(tester, FreehandSession()..drawing = false);
    expect(find.text('Move the map, then switch back to Draw'), findsOneWidget);
  });

  testWidgets('counts strokes and their length', (tester) async {
    await pump(tester, withStroke());
    expect(find.text('1 stroke  ·  100 m'), findsOneWidget);
    final done = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(done.onPressed, isNotNull);
  });

  testWidgets('Pan hands the map back', (tester) async {
    bool? drawing;
    await pump(tester, FreehandSession(), mode: (v) => drawing = v);
    await tester.tap(find.text('Pan'));
    expect(drawing, isFalse);
  });

  testWidgets('a colour and a width can be picked', (tester) async {
    String? c;
    double? w;
    await pump(tester, FreehandSession(),
        colour: (v) => c = v, width: (v) => w = v);
    await tester.tap(find.byKey(const ValueKey('freehand-colour-#00E5FF')));
    await tester.tap(find.byKey(const ValueKey('freehand-width-7')));
    expect(c, '#00E5FF');
    expect(w, 7.0);
  });

  testWidgets('fits a 360 px phone without overflowing', (tester) async {
    // The colour and width row is 282 px of the 328 left inside the padding.
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pump(tester, withStroke());
    expect(tester.takeException(), isNull);
  });

  group('layers', () {
    int lines(List<Widget> layers) => layers
        .whereType<PolylineLayer>()
        .fold(0, (n, l) => n + l.polylines.length);

    test('nothing to draw, no layer', () {
      expect(buildFreehandLayers(null), isEmpty);
      expect(buildFreehandLayers(FreehandSession()), isEmpty);
    });

    test('the stroke under the finger draws as it goes', () {
      final s = withStroke()
        ..beginStroke(leonora)
        ..extendStroke(east(5));
      expect(lines(buildFreehandLayers(s)), 2);
    });

    test('in the pen colour and width', () {
      final s = withStroke()
        ..colour = '#00E5FF'
        ..width = 7;
      final line =
          buildFreehandLayers(s).whereType<PolylineLayer>().single.polylines.single;
      expect(line.color, const Color(0xFF00E5FF));
      expect(line.strokeWidth, 7);
    });
  });
}
