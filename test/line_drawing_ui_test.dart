// The on-screen half of the line tool: what the panel says, what the map
// draws, and which lines are shown under a project filter.
import 'package:bush_track/core/models/field_file.dart';
import 'package:bush_track/features/drawing/models/drawing.dart';
import 'package:bush_track/features/drawing/presentation/line_drawing.dart';
import 'package:bush_track/features/drawing/services/line_geometry.dart';
import 'package:bush_track/features/files/services/project_scope.dart';
import 'package:bush_track/features/map/providers/marker_visibility_provider.dart';
import 'dart:math' as math;

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
              colour: '#FF6B00',
              width: 4,
              onColour: (_) {},
              onWidth: (_) {},
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

  group('handles sit exactly on their points, at any rotation', () {
    // mapOffsetOf is the inverse of the offsetToCrs that the finger already
    // goes through. If the two disagree, a handle is drawn somewhere other
    // than where dragging it would put the point.
    for (final rotation in [0.0, 30.0, 137.0, -90.0]) {
      test('rotated $rotation°', () {
        final camera = MapCamera(
          crs: const Epsg3857(),
          center: leonora,
          zoom: 15,
          rotation: rotation,
          nonRotatedSize: const math.Point(400, 800),
        );
        expect(mapOffsetOf(camera, leonora), const Offset(200, 400));
        for (final p in [east, north, LatLng(-28.875, 121.325)]) {
          final back = camera.offsetToCrs(mapOffsetOf(camera, p));
          expect(const Distance()(back, p), lessThan(0.05), reason: '$p');
        }
      });
    }
  });

  // On the phone a drag that started on a point moved the whole map: the
  // handles were markers inside the map's own gesture handling. They are now
  // drawn above the map, and these hold that against a real FlutterMap.
  group('dragging a point does not move the map', () {
    late MapController controller;
    late List<Offset> dragged;
    late List<int> inserted;

    Future<void> pump(WidgetTester tester) async {
      controller = MapController();
      dragged = [];
      inserted = [];
      Widget tree() => MaterialApp(
        home: Stack(children: [
          FlutterMap(
            mapController: controller,
            options: const MapOptions(initialCenter: leonora, initialZoom: 16),
            children: const [],
          ),
          Positioned.fill(
            child: Builder(builder: (context) {
              final draft = LineDraft([leonora, east]);
              return LineHandles(
                vertices: [
                  for (final p in draft.points)
                    mapOffsetOf(controller.camera, p),
                ],
                midpoints: [
                  for (final m in draft.midpoints)
                    mapOffsetOf(controller.camera, m),
                ],
                onDragTo: (i, g) => dragged.add(g),
                onDragEnd: (_) {},
                onRemove: (_) {},
                onInsert: inserted.add,
              );
            }),
          ),
        ]),
      );
      // The map has no size until it is laid out, so the handles are placed
      // again once it has -- as the dashboard does, which shows them only
      // after the map is ready and rebuilds on every camera move.
      await tester.pumpWidget(tree());
      await tester.pump();
      await tester.pumpWidget(tree());
    }

    testWidgets('a drag on a point moves the point and not the map',
        (tester) async {
      await pump(tester);
      final before = controller.camera.center;
      await tester.drag(
          find.byKey(const ValueKey('line-vertex-1')), const Offset(0, 120));
      await tester.pumpAndSettle();

      expect(dragged, isNotEmpty, reason: 'the point is told where to go');
      expect(controller.camera.center, before, reason: 'the map stays put');
    });

    testWidgets('a drag on open ground still pans the map', (tester) async {
      // The other half: the handles must not swallow the map either.
      await pump(tester);
      final before = controller.camera.center;
      await tester.dragFrom(const Offset(60, 500), const Offset(0, -150));
      await tester.pumpAndSettle();

      expect(dragged, isEmpty);
      expect(controller.camera.center, isNot(before));
    });

    testWidgets('a + answers at once, with no double-tap wait', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const ValueKey('line-midpoint-0')));
      expect(inserted, [1]);
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
