// Colour, rename and archive. The parts worth pinning are the two places a
// null means something: clearing a colour and un-archiving, neither of which a
// plain copyWith can express.
import 'package:bush_track/core/models/field_file.dart';
import 'package:bush_track/core/models/waypoint.dart';
import 'package:bush_track/features/files/providers/files_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  FieldFile project({
    int? id = 1,
    String name = 'Kookynie',
    String? colour,
    DateTime? archivedAt,
  }) =>
      FieldFile(
        id: id,
        name: name,
        description: 'survey',
        createdAt: DateTime.utc(2026, 10, 1),
        updatedAt: DateTime.utc(2026, 10, 2),
        colour: colour,
        archivedAt: archivedAt,
      );

  group('clearing a colour needs saying out loud', () {
    test('a null colour through copyWith leaves it alone', () {
      final red = project(colour: '#FF2D55');
      expect(red.copyWith(colour: null).colour, '#FF2D55',
          reason: 'null means "unchanged", which is why clearColour exists');
    });

    test('clearColour goes back to the default', () {
      final red = project(colour: '#FF2D55');
      expect(red.copyWith(clearColour: true).colour, isNull);
    });

    test('and it does not take anything else with it', () {
      // The bug this guards: rebuilding the object by hand to clear one field
      // is how fileId, rating and weatherConditions came off a Waypoint once.
      final before = project(colour: '#FF2D55', archivedAt: DateTime.utc(2026, 9, 1));
      final after = before.copyWith(name: 'Renamed', clearColour: true);

      expect(after.name, 'Renamed');
      expect(after.colour, isNull);
      expect(after.description, before.description);
      expect(after.archivedAt, before.archivedAt);
      expect(after.createdAt, before.createdAt);
      expect(after.sortOrder, before.sortOrder);
      expect(after.id, before.id);
    });

    test('renaming and recolouring in one step keeps both', () {
      final after =
          project().copyWith(name: 'Mount Ida', colour: '#2E7BFF');
      expect(after.name, 'Mount Ida');
      expect(after.colour, '#2E7BFF');
    });
  });

  group('the colour comes from the pin palette', () {
    test('every project colour the picker offers is a real hex', () {
      for (final c in WaypointColors.allColors) {
        final parsed = WaypointColors.fromHex(c);
        expect(parsed.a, 1.0, reason: '$c should be fully opaque');
      }
    });

    test('and each one has a name, since colour alone is a poor label', () {
      // It cannot be read out over the radio and is no use to someone who
      // cannot tell two of these apart.
      for (final c in WaypointColors.allColors) {
        expect(WaypointColors.names[c], isNotNull, reason: c);
      }
    });

    test('an unparseable stored colour falls back instead of throwing', () {
      expect(() => WaypointColors.fromHex('not a colour'), returnsNormally);
      expect(() => WaypointColors.fromHex(null), returnsNormally);
    });
  });

  group('archiving is not deleting', () {
    test('an archived project is still in files, just not in the list', () {
      // Kept in `files` on purpose: an archived project that is still the
      // active one, or still scoped on the map, has to be findable by id
      // rather than silently resolving to null.
      final state = FilesState(files: [
        project(id: 1),
        project(id: 2, name: 'Finished', archivedAt: DateTime.utc(2026, 9, 1)),
      ]);

      expect(state.files, hasLength(2));
      expect(state.liveFiles.map((f) => f.id), [1]);
      expect(state.archivedFiles.map((f) => f.id), [2]);
    });

    test('nothing is archived by default', () {
      final state = FilesState(files: [project(id: 1), project(id: 2)]);
      expect(state.liveFiles, hasLength(2));
      expect(state.archivedFiles, isEmpty);
    });

    test('an archived project keeps its colour and its name', () {
      final before = project(colour: '#FFD60A');
      final after = before.copyWith(archivedAt: DateTime.utc(2026, 9, 1));

      expect(after.isArchived, isTrue);
      expect(after.colour, '#FFD60A');
      expect(after.name, before.name);
    });

    test('restoring puts it back exactly as it was', () {
      final live = project(colour: '#00FF88');
      final archived = live.copyWith(archivedAt: DateTime.utc(2026, 9, 1));
      final restored = archived.copyWith(clearArchived: true);

      expect(restored.isArchived, isFalse);
      expect(restored.colour, live.colour);
      expect(restored.name, live.name);
      expect(restored.sortOrder, live.sortOrder);
    });

    test('the archive round-trips through storage', () {
      final archived = project(
          colour: '#FF2BD6', archivedAt: DateTime.utc(2026, 9, 1));
      final loaded = FieldFile.fromMap(archived.toMap());

      expect(loaded.isArchived, isTrue);
      expect(loaded.colour, '#FF2BD6');
      expect(
          loaded.archivedAt!.isAtSameMomentAs(archived.archivedAt!), isTrue);
    });

    test('and an un-archive round-trips as a live project', () {
      final restored = project(archivedAt: DateTime.utc(2026, 9, 1))
          .copyWith(clearArchived: true);
      final loaded = FieldFile.fromMap(restored.toMap());

      expect(loaded.isArchived, isFalse,
          reason: 'toMap must write a null archived_at, not omit the key');
    });
  });

  group('Unsorted is not editable like a project', () {
    test('it has no colour of its own to save', () {
      expect(FieldFile.unsorted().colour, isNull);
    });

    test('and it is not in the archived or live lists', () {
      // It is a view, not a row, so it never comes back from the database and
      // cannot appear in either list by accident.
      final state = FilesState(files: [project(id: 1)]);
      expect(state.liveFiles.any((f) => f.isUnsorted), isFalse);
      expect(state.archivedFiles.any((f) => f.isUnsorted), isFalse);
    });
  });
}
