// The on-screen half of the line tool: what the panel says, what the map
// draws, and which lines are shown under a project filter.
import 'package:bush_track/core/models/field_file.dart';
import 'package:bush_track/features/drawing/models/drawing.dart';
import 'package:bush_track/features/drawing/presentation/line_drawing.dart';
import 'package:bush_track/features/drawing/services/line_geometry.dart';
import 'package:bush_track/features/files/services/project_scope.dart';
import 'package:bush_track/features/map/providers/marker_visibility_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  const leonora = LatLng(-28.88, 121.33);
  final east = const Distance(roundResult: false).offset(leonora, 240, 90);
  final north = const Distance(roundResult: false).offset(east, 100, 0);

  group('a leg reads as length, compass point and degrees', () {
    test('240 m due east', () {
      final s = LineMeasure.segments([leonora, east]).single;
      expect(describeSegment(s), '240 m · E 90°');
    });

    test('a bearing that rounds up to 360 reads as 0', () {
      const s = LineSegment(leonora, leonora, 10, 359.7);
      expect(describeSegment(s), '10 m · N 0°');
    });
  });

  group('the panel', () {
    Future<void> pump(WidgetTester tester, List<LatLng> points,
        {bool canUndo = true, String? snapped}) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: LineDrawPanel(
              points: points,
              canUndo: canUndo,
              snappedTo: snapped,
              onUndo: () {},
              onCancel: () {},
              onDone: () {},
            ),
          ),
        ),
      ));
    }

    testWidgets('says what to do before the first tap', (tester) async {
      await pump(tester, const [], canUndo: false);
      expect(find.text('Tap the map to start the line'), findsOneWidget);
    });

    testWidgets('a running total and every leg', (tester) async {
      await pump(tester, [leonora, east, north]);
      expect(find.text('340 m  ·  2 legs'), findsOneWidget);
      expect(find.text('240 m · E 90°'), findsOneWidget);
      expect(find.text('100 m · N 0°'), findsOneWidget);
    });

    testWidgets('Done waits for a second point', (tester) async {
      await pump(tester, const [leonora]);
      final done = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(done.onPressed, isNull);
    });

    testWidgets('Undo is off with nothing to undo', (tester) async {
      await pump(tester, const [], canUndo: false);
      final undo = tester.widget<IconButton>(find.byType(IconButton));
      expect(undo.onPressed, isNull);
    });

    testWidgets('a snap is announced', (tester) async {
      await pump(tester, [leonora, east], snapped: 'Old shaft');
      expect(find.text('Snapped to Old shaft'), findsOneWidget);
    });
  });

  group('the map layers', () {
    Future<void> pump(WidgetTester tester, List<Widget> layers) =>
        tester.pumpWidget(MaterialApp(
          home: FlutterMap(
            options: const MapOptions(initialCenter: leonora, initialZoom: 16),
            children: layers,
          ),
        ));

    testWidgets('a handle on every point and a + on every leg', (tester) async {
      await pump(
          tester,
          buildDrawingMapLayers(
            drawings: const [],
            draft: LineDraft([leonora, east, north]),
            onMidpointTap: (_) {},
          ));
      for (var i = 0; i < 3; i++) {
        expect(find.byKey(ValueKey('line-vertex-$i')), findsOneWidget);
      }
      expect(find.byKey(const ValueKey('line-midpoint-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('line-midpoint-1')), findsOneWidget);
    });

    testWidgets('tapping a + asks for a vertex in that leg', (tester) async {
      int? asked;
      await pump(
          tester,
          buildDrawingMapLayers(
            drawings: const [],
            draft: LineDraft([leonora, east, north]),
            onMidpointTap: (i) => asked = i,
          ));
      await tester.tap(find.byKey(const ValueKey('line-midpoint-1')));
      // The map listens for double taps, so a single tap is only settled once
      // the double-tap window has passed.
      await tester.pump(const Duration(milliseconds: 400));
      expect(asked, 2, reason: 'between vertices 1 and 2');
    });

    test('the line being edited is not also drawn as its saved self', () {
      final saved = Drawing(
          id: 7, kind: DrawingKind.line, points: [leonora, east]);
      int lines(List<Widget> layers) => layers
          .whereType<PolylineLayer>()
          .fold(0, (n, l) => n + l.polylines.length);
      // Not editing it: the saved line and the draft both draw.
      expect(
          lines(buildDrawingMapLayers(
              drawings: [saved], draft: LineDraft(saved.points))),
          2);
      // Editing it: only the draft, or the old shape would sit under the new
      // one and a moved point would look as if it had not moved.
      expect(
          lines(buildDrawingMapLayers(
              drawings: [saved], draft: LineDraft(saved.points), editingId: 7)),
          1);
    });
  });

  group('a long-press finds a line, not a closed shape', () {
    test('a point near where the line would close is not near the line', () {
      // An L: leonora -> east -> north. A closed-polygon distance would add
      // an edge from north back to leonora; a point on that phantom edge is
      // about 50 m from the real line.
      final onPhantomEdge = LatLng(
          (north.latitude + leonora.latitude) / 2,
          (north.longitude + leonora.longitude) / 2);
      final m = LineMeasure.distanceToLineMetres(
          onPhantomEdge, [leonora, east, north]);
      expect(m, greaterThan(40));
    });

    test('a point on a leg is on the line', () {
      final mid = LatLng((leonora.latitude + east.latitude) / 2,
          (leonora.longitude + east.longitude) / 2);
      expect(LineMeasure.distanceToLineMetres(mid, [leonora, east]),
          lessThan(0.5));
    });
  });

  test('a press on a vertex with no movement adds no undo step', () {
    final d = LineDraft([leonora, east]);
    expect(d.isDragging, isFalse);
    d.drag(0, leonora);
    expect(d.isDragging, isTrue);
    d.endDrag();
    expect(d.isDragging, isFalse);
  });

  group('drawings follow the project filter', () {
    test('everything shows with no filter, filed or not', () {
      const v = MarkerVisibility();
      expect(v.showsDrawing(fileId: null), isTrue);
      expect(v.showsDrawing(fileId: 3), isTrue);
    });

    test('a filter shows only its projects', () {
      final v = MarkerVisibility(scope: ProjectScope.only({3}));
      expect(v.showsDrawing(fileId: 3), isTrue);
      expect(v.showsDrawing(fileId: 4), isFalse);
    });

    test('Unsorted in the filter shows unfiled lines', () {
      final v =
          MarkerVisibility(scope: ProjectScope.only({FieldFile.unsortedId}));
      expect(v.showsDrawing(fileId: null), isTrue);
      expect(v.showsDrawing(fileId: 3), isFalse);
    });

    test('they step aside while a pin is soloed', () {
      const v = MarkerVisibility(soloPinId: 1);
      expect(v.showsDrawing(fileId: null), isFalse);
    });
  });
}
