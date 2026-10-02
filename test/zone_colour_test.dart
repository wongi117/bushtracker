// Reported: picked Heritage (purple), the circle on the map was orange.
//
// The orange was the unsaved draft. AppColors.accent is 0xFFFF6B00, which is
// what a zone is drawn in while you are still dragging it out — before a
// category has been chosen, because the category is picked in the sheet that
// opens afterwards. The zone never became a saved zone because SAVE was behind
// the navigation bar and could not be pressed, so the draft was all there was
// to look at. Same bug, wearing a different hat.
//
// These pin down the part that was never actually broken, so it stays that way.
import 'package:bush_track/core/models/geofence.dart';
import 'package:bush_track/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// What a zone being dragged out is drawn in. Mirrors draftColor in
/// zone_drawing.dart.
const kZoneDraftColour = Colors.white;

void main() {
  group('a saved zone takes its category colour', () {
    test('Heritage is purple, not orange', () {
      final zone = Geofence(
        id: 1,
        name: 'Old camp',
        latitude: -28.8833,
        longitude: 121.3333,
        radiusMeters: 200,
        isActive: true,
        createdAt: DateTime.utc(2026, 10, 2),
        category: ZoneCategory.heritage,
      );

      final drawn = Color(zone.category.colorValue);
      expect(drawn, const Color(0xFFAB47BC), reason: 'Heritage is purple');
      expect(drawn, isNot(AppColors.accent),
          reason: 'and must not come out as the draft orange');
    });

    test('every category has its own colour', () {
      final colours =
          ZoneCategory.values.map((c) => c.colorValue).toSet();
      expect(colours, hasLength(ZoneCategory.values.length),
          reason: 'two categories sharing a colour cannot be told apart');
    });

    test('no category is the draft colour, or saving would look like drawing',
        () {
      // This test is why the draft is white. It used to be AppColors.accent,
      // which is byte-identical to "No entry" — the default category — so a
      // zone that saved perfectly looked exactly like one still being dragged
      // out, and a save that silently failed looked exactly like one that
      // worked.
      for (final category in ZoneCategory.values) {
        expect(Color(category.colorValue), isNot(kZoneDraftColour),
            reason: '${category.label} is the same colour as an unsaved '
                'draft, so a saved zone would look unsaved');
      }
    });

    test('every category colour is fully opaque', () {
      for (final category in ZoneCategory.values) {
        expect(Color(category.colorValue).a, 1.0, reason: category.label);
      }
    });
  });

  group('the category survives being stored', () {
    test('a Heritage zone comes back as Heritage', () {
      final zone = Geofence(
        id: 1,
        name: 'Old camp',
        latitude: -28.8833,
        longitude: 121.3333,
        radiusMeters: 200,
        isActive: true,
        createdAt: DateTime.utc(2026, 10, 2),
        category: ZoneCategory.heritage,
      );

      final back = Geofence.fromMap(zone.toMap());
      expect(back.category, ZoneCategory.heritage);
      expect(Color(back.category.colorValue), const Color(0xFFAB47BC));
    });

    test('every category round-trips', () {
      for (final category in ZoneCategory.values) {
        final zone = Geofence(
        id: 1,
        name: 'Zone',
        latitude: -28.88,
        longitude: 121.33,
        radiusMeters: 100,
        isActive: true,
        createdAt: DateTime.utc(2026, 10, 2),
        category: category,
        );
        expect(Geofence.fromMap(zone.toMap()).category, category,
            reason: '${category.label} did not survive');
      }
    });

    test('an unknown category id falls back rather than crashing', () {
      // A zone written by a future version, or a corrupt row.
      final map = Geofence(
        id: 1,
        name: 'Zone',
        latitude: -28.88,
        longitude: 121.33,
        radiusMeters: 100,
        isActive: true,
        createdAt: DateTime.utc(2026, 10, 2),
        category: ZoneCategory.heritage,
      ).toMap();
      map['category'] = 'something_new';

      final back = Geofence.fromMap(map);
      expect(back.category, isNotNull);
      expect(Color(back.category.colorValue).a, 1.0);
    });
  });

  group('the draft is deliberately a different colour', () {
    test('it is not a category colour, and must never become one', () {
      // Before the sheet opens there is no category to colour a draft by, so
      // it needs a colour of its own. If someone later "tidies" this into a
      // category colour, the test above fails and says why.
      expect(ZoneCategory.values.map((c) => Color(c.colorValue)),
          isNot(contains(kZoneDraftColour)));
    });

    test('the old draft colour clashed with the default category', () {
      // Kept as a record of the bug: accent is still exactly "No entry".
      expect(AppColors.accent,
          Color(ZoneCategory.exclusion.colorValue),
          reason: 'if this ever stops being true, the comment in '
              'zone_drawing explaining why the draft is white is stale');
    });
  });
}
