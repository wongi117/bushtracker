// Scoping is a feature whose failure mode looks exactly like data loss: a pin
// that is not on the map reads as "I have lost this morning's work", not as
// "that is filtered out". So the rules worth testing are the ones that stop a
// scope hiding something nobody asked it to hide.
import 'package:bush_track/core/models/field_file.dart';
import 'package:bush_track/features/files/services/project_scope.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('nothing is hidden until somebody asks', () {
    test('the default shows everything', () {
      const scope = ProjectScope.all();
      expect(scope.isFiltered, isFalse);
      expect(scope.isVisible(1), isTrue);
      expect(scope.isVisible(999), isTrue);
      expect(scope.isVisible(null), isTrue, reason: 'unfiled work too');
    });

    test('an empty selection means everything, not nothing', () {
      // The rule that stops the map going blank. An honest empty scope is
      // indistinguishable on screen from a database that failed to load.
      expect(ProjectScope.only({}).isFiltered, isFalse);
      expect(ProjectScope.only({}).isVisible(7), isTrue);
    });

    test('turning the last project off goes back to everything', () {
      final one = ProjectScope.only({3});
      expect(one.toggle(3).isFiltered, isFalse,
          reason: 'not an empty map with no way to tell why');
    });

    test('a scope that cannot be read restores to everything', () {
      expect(ProjectScope.decode(null).isFiltered, isFalse);
      expect(ProjectScope.decode([]).isFiltered, isFalse);
      expect(ProjectScope.decode(['not a number']).isFiltered, isFalse,
          reason: 'garbage must not become a blank map');
    });
  });

  group('showing only some projects', () {
    test('the chosen ones are visible and the rest are not', () {
      final scope = ProjectScope.only({1, 2});
      expect(scope.isVisible(1), isTrue);
      expect(scope.isVisible(2), isTrue);
      expect(scope.isVisible(3), isFalse);
    });

    test('unfiled work is hidden unless Unsorted is picked', () {
      expect(ProjectScope.only({1}).isVisible(null), isFalse);
      expect(
          ProjectScope.only({FieldFile.unsortedId}).isVisible(null), isTrue);
    });

    test('Unsorted does not drag real projects in with it', () {
      final scope = ProjectScope.only({FieldFile.unsortedId});
      expect(scope.isVisible(1), isFalse);
    });

    test('the first tap means "only this one", not "all but this one"', () {
      // Picking one project out of a crowded map is the whole point; starting
      // from everything, a tap that merely *removed* one would leave the
      // overload the user complained about.
      final scope = const ProjectScope.all().toggle(5);
      expect(scope.isVisible(5), isTrue);
      expect(scope.isVisible(6), isFalse);
    });

    test('a second project can be added to the view', () {
      final scope = const ProjectScope.all().toggle(5).toggle(6);
      expect(scope.isVisible(5), isTrue);
      expect(scope.isVisible(6), isTrue);
      expect(scope.isVisible(7), isFalse);
    });

    test('selected is a different question from visible', () {
      // With nothing filtered everything is visible but nothing is selected,
      // or every checkbox would show ticked and "show only this" would look
      // like it had already happened.
      const all = ProjectScope.all();
      expect(all.isVisible(4), isTrue);
      expect(all.isSelected(4), isFalse);
    });
  });

  group('a deleted project cannot keep hiding the map', () {
    test('ids that no longer exist are dropped', () {
      final scope = ProjectScope.only({1, 2, 3}).prune({1, 3});
      expect(scope.isVisible(1), isTrue);
      expect(scope.isVisible(2), isFalse);
      expect(scope.count, 2);
    });

    test('pruning everything away shows everything again', () {
      expect(ProjectScope.only({9}).prune({1, 2}).isFiltered, isFalse,
          reason: 'deleting the only project in scope must not blank the map');
    });

    test('Unsorted survives pruning, having no row to be missing from', () {
      final scope =
          ProjectScope.only({FieldFile.unsortedId, 4}).prune(<int>{});
      expect(scope.isVisible(null), isTrue);
      expect(scope.isFiltered, isTrue);
    });

    test('pruning an unfiltered scope changes nothing', () {
      const all = ProjectScope.all();
      expect(all.prune({1}), all);
    });
  });

  group('it survives a restart', () {
    test('a round trip through storage keeps the same projects', () {
      final before = ProjectScope.only({2, 5, FieldFile.unsortedId});
      final after = ProjectScope.decode(before.encode());
      expect(after, before);
      expect(after.isVisible(null), isTrue);
      expect(after.isVisible(2), isTrue);
      expect(after.isVisible(3), isFalse);
    });

    test('unfiltered stores nothing, so an upgrade starts unfiltered', () {
      expect(const ProjectScope.all().encode(), isEmpty);
    });

    test('order does not matter to equality', () {
      expect(ProjectScope.only({1, 2}), ProjectScope.only({2, 1}));
      expect(ProjectScope.only({1, 2}).hashCode,
          ProjectScope.only({2, 1}).hashCode);
    });

    test('filtered and unfiltered are never equal', () {
      expect(ProjectScope.only({1}), isNot(const ProjectScope.all()));
    });
  });

  group('showAll is always one step away', () {
    test('from any amount of filtering', () {
      final deep = ProjectScope.only({1, 2, 3, 4, 5});
      expect(deep.clear().isFiltered, isFalse);
      expect(deep.clear().isVisible(99), isTrue);
    });
  });
}
