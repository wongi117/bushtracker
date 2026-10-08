// The sheet a zone opens when tapped on the map (Phase 4.3), and the
// read-only path the plan asks to be proven before sharing exists.
import 'dart:math' as math;

import 'package:bush_track/core/models/geofence.dart';
import 'package:bush_track/features/geofence/presentation/zone_detail_sheet.dart';
import 'package:bush_track/features/geofence/services/zone_selection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  const leonora = LatLng(-28.88, 121.33);
  LatLng at(double metres, double bearing) =>
      const Distance(roundResult: false).offset(leonora, metres, bearing);

  final square = Geofence.polygon(
    id: 1,
    name: 'Old shaft',
    points: [
      for (final b in [315.0, 45.0, 135.0, 225.0]) at(100 * math.sqrt2, b),
    ],
    isActive: true,
    createdAt: DateTime(2026, 10, 8),
    category: ZoneCategory.hazard,
  );

  Future<ZoneSheetAction?> open(WidgetTester tester, ZoneAccess access,
      {bool? inside, String? project, String tap = ''}) async {
    ZoneSheetAction? chosen;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              chosen = await showModalBottomSheet<ZoneSheetAction>(
                context: context,
                builder: (_) => ZoneDetailSheet(
                  zone: square,
                  access: access,
                  projectName: project,
                  inside: inside,
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    if (tap.isNotEmpty) {
      await tester.tap(find.text(tap));
      await tester.pumpAndSettle();
    }
    return chosen;
  }

  testWidgets('the facts: category, corners, area, perimeter, project',
      (tester) async {
    await open(tester, ZoneAccess.owner, project: 'Kookynie');
    expect(find.text('Old shaft'), findsOneWidget);
    expect(find.text('Hazard · 4 corners'), findsOneWidget);
    expect(find.text('4.0 ha'), findsOneWidget);
    expect(find.text('800 m'), findsOneWidget);
    expect(find.text('Kookynie'), findsOneWidget);
  });

  testWidgets('unfiled reads as Unsorted', (tester) async {
    await open(tester, ZoneAccess.owner);
    expect(find.text('Unsorted'), findsOneWidget);
  });

  testWidgets('the owner can track, edit and delete', (tester) async {
    await open(tester, ZoneAccess.owner);
    expect(find.text('Track to'), findsOneWidget);
    expect(find.text('Edit corners'), findsOneWidget);
    expect(find.byTooltip('Delete zone'), findsOneWidget);
    expect(find.byKey(const ValueKey('zone-view-only')), findsNothing);
  });

  testWidgets('view-only: no edit, no delete, and it says why',
      (tester) async {
    await open(tester, ZoneAccess.view);
    expect(find.text('Edit corners'), findsNothing);
    expect(find.byTooltip('Delete zone'), findsNothing);
    expect(find.byKey(const ValueKey('zone-view-only')), findsOneWidget);
    // Tracking to a zone changes nothing about it, so it stays.
    expect(find.text('Track to'), findsOneWidget);
  });

  testWidgets('shared to edit: edit, but not delete', (tester) async {
    await open(tester, ZoneAccess.edit);
    expect(find.text('Edit corners'), findsOneWidget);
    expect(find.byTooltip('Delete zone'), findsNothing);
  });

  testWidgets('the buttons say what was chosen', (tester) async {
    expect(await open(tester, ZoneAccess.owner, tap: 'Track to'),
        ZoneSheetAction.track);
    expect(await open(tester, ZoneAccess.owner, tap: 'Edit corners'),
        ZoneSheetAction.edit);
  });

  testWidgets('inside or outside only when known', (tester) async {
    await open(tester, ZoneAccess.owner, inside: true);
    expect(find.text('You are inside'), findsOneWidget);
    await open(tester, ZoneAccess.owner, inside: null);
    expect(find.byKey(const ValueKey('zone-inside')), findsNothing);
  });

  group('the phone only says inside when the fix can tell', () {
    test('a good fix in the middle: inside', () {
      expect(insideIfKnown(square, leonora, 5), isTrue);
    });

    test('a good fix well outside: outside', () {
      expect(insideIfKnown(square, at(300, 90), 5), isFalse);
    });

    test('a rough fix beside the edge: says nothing', () {
      // 20 m inside the edge with a ±500 m fix could be either side.
      expect(insideIfKnown(square, at(80, 90), 500), isNull);
    });

    test('no fix, or unknown accuracy: says nothing', () {
      expect(insideIfKnown(square, null, 5), isNull);
      expect(insideIfKnown(square, leonora, 0), isNull,
          reason: 'accuracy defaults to 0 when the phone has not said');
    });
  });
}
