// Moving items between projects. The one that would quietly lose work is
// writing FieldFile.unsortedId into file_id instead of null -- the items would
// be filed under a project that does not exist and drop out of every list, the
// Unsorted view included.
import 'package:bush_track/core/models/field_file.dart';
import 'package:bush_track/features/files/services/item_move.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  FieldFile project(int id, String name, {String? colour, bool archived = false}) =>
      FieldFile(
        id: id,
        name: name,
        colour: colour,
        archivedAt: archived ? DateTime.utc(2026, 9, 1) : null,
        createdAt: DateTime.utc(2026, 10, 1),
        updatedAt: DateTime.utc(2026, 10, 1),
      );

  group('moving to Unsorted clears the column', () {
    test('it writes null, not the reserved id', () {
      // Writing -1 would file the items under a project that does not exist,
      // hiding them from the project lists AND from the Unsorted view, which
      // matches on null. They would be gone with nothing deleted.
      expect(const MoveDestination.unsorted().targetFileId, isNull);
      expect(const MoveDestination.unsorted().targetFileId,
          isNot(FieldFile.unsortedId));
    });

    test('and it knows what it is', () {
      expect(const MoveDestination.unsorted().isUnsorted, isTrue);
      expect(const MoveDestination.unsorted().name, 'Unsorted');
      expect(const MoveDestination.unsorted().colour, isNull);
    });

    test('a project destination writes its own id', () {
      final d = MoveDestination.project(project(7, 'Kookynie'));
      expect(d.targetFileId, 7);
      expect(d.isUnsorted, isFalse);
      expect(d.name, 'Kookynie');
    });

    test('and carries its colour, so the chip matches the folder', () {
      final d = MoveDestination.project(project(7, 'K', colour: '#FFD60A'));
      expect(d.colour, '#FFD60A');
    });
  });

  group('where items can go', () {
    test('every other project is offered', () {
      final d = destinationsFor(
        [project(1, 'A'), project(2, 'B'), project(3, 'C')],
        currentFileId: 2,
      );
      expect(d.map((x) => x.name), containsAll(['A', 'C']));
    });

    test('the list being moved out of is not offered', () {
      // Moving something to where it already is reads as a no-op that did
      // nothing wrong but also did nothing, and leaves the user unsure which.
      final d = destinationsFor(
        [project(1, 'A'), project(2, 'B')],
        currentFileId: 2,
      );
      expect(d.map((x) => x.name), isNot(contains('B')));
    });

    test('Unsorted is offered from inside a project', () {
      final d = destinationsFor([project(1, 'A')], currentFileId: 1);
      expect(d.any((x) => x.isUnsorted), isTrue,
          reason: 'taking something out of a project is the same gesture');
    });

    test('but not from the Unsorted view itself', () {
      final d = destinationsFor([project(1, 'A')], currentFileId: null);
      expect(d.any((x) => x.isUnsorted), isFalse);
      expect(d.map((x) => x.name), ['A']);
    });

    test('Unsorted sorts last, being where things end up', () {
      final d = destinationsFor(
        [project(1, 'A'), project(2, 'B')],
        currentFileId: 1,
      );
      expect(d.last.isUnsorted, isTrue);
    });

    test('archived projects are still offered', () {
      // Filing a pin into last season's survey is reasonable, and refusing it
      // silently would be worse than allowing it.
      final d = destinationsFor(
        [project(1, 'A'), project(2, 'Finished', archived: true)],
        currentFileId: 1,
      );
      expect(d.map((x) => x.name), contains('Finished'));
    });

    test('the Unsorted pseudo-project never appears as a real one', () {
      // If it ever got into the files list it must not be offered twice, once
      // as a row and once as the view.
      final d = destinationsFor(
        [project(1, 'A'), FieldFile.unsorted()],
        currentFileId: 1,
      );
      expect(d.where((x) => x.isUnsorted), hasLength(1));
      expect(d.where((x) => x.name == 'Unsorted'), hasLength(1));
    });

    test('a project with no id is skipped rather than crashing a move', () {
      final unsaved = FieldFile(
        name: 'Never saved',
        createdAt: DateTime.utc(2026, 10, 1),
        updatedAt: DateTime.utc(2026, 10, 1),
      );
      final d = destinationsFor([unsaved], currentFileId: 1);
      expect(d.where((x) => !x.isUnsorted), isEmpty);
    });

    test('with one project and nowhere else, only Unsorted is offered', () {
      final d = destinationsFor([project(1, 'Only')], currentFileId: 1);
      expect(d, hasLength(1));
      expect(d.single.isUnsorted, isTrue);
    });

    test('and from Unsorted with no projects there is nowhere to go', () {
      // The sheet says so rather than offering an empty row of buttons.
      expect(destinationsFor([], currentFileId: null), isEmpty);
    });
  });

  group('what the confirmation says', () {
    test('it counts, so a wrong tick is noticeable', () {
      expect(describeMove(1, 'Kookynie'), '1 item moved to Kookynie');
      expect(describeMove(12, 'Kookynie'), '12 items moved to Kookynie');
    });

    test('and names the destination, including Unsorted', () {
      expect(describeMove(3, 'Unsorted'), '3 items moved to Unsorted');
    });
  });
}
