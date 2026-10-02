// The scope went from one project to several. These cover the parts that are
// not the ProjectScope value type (which has its own test): how the three
// filtering mechanisms interact, and the upgrade path for somebody who had a
// project open when they installed this build.
import 'package:bush_track/core/models/field_file.dart';
import 'package:bush_track/features/files/services/project_scope.dart';
import 'package:bush_track/features/map/providers/marker_visibility_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('several projects can be on screen at once', () {
    test('a pin in any chosen project is drawn', () {
      final v = MarkerVisibility(scope: ProjectScope.only({1, 2}));
      expect(v.showsPin(id: 10, fileId: 1), isTrue);
      expect(v.showsPin(id: 11, fileId: 2), isTrue);
      expect(v.showsPin(id: 12, fileId: 3), isFalse);
    });

    test('and so is a zone: a survey plus the boundaries that bound it', () {
      // The case the single-project version could not express, and the reason
      // for the change: the heritage boundaries and the job inside them are
      // two projects you need together.
      final v = MarkerVisibility(scope: ProjectScope.only({1, 2}));
      expect(v.showsZone(id: 5, fileId: 2), isTrue);
      expect(v.showsZone(id: 6, fileId: 9), isFalse);
    });

    test('unfiled work needs Unsorted picked', () {
      expect(
          MarkerVisibility(scope: ProjectScope.only({1}))
              .showsPin(id: 1, fileId: null),
          isFalse);
      expect(
          MarkerVisibility(scope: ProjectScope.only({FieldFile.unsortedId}))
              .showsPin(id: 1, fileId: null),
          isTrue);
    });

    test('showsProject answers the checkbox, not the visibility', () {
      const v = MarkerVisibility();
      expect(v.showsPin(id: 1, fileId: 4), isTrue, reason: 'nothing filtered');
      expect(v.showsProject(4), isFalse, reason: 'but nothing is chosen');
    });
  });

  group('the three mechanisms still stack narrowest first', () {
    test('solo beats a project scope', () {
      final v = MarkerVisibility(scope: ProjectScope.only({1}), soloPinId: 7);
      expect(v.showsPin(id: 7, fileId: 99), isTrue,
          reason: 'solo is the narrowest request, and it wins');
      expect(v.showsPin(id: 8, fileId: 1), isFalse);
    });

    test('a hand-hidden pin stays hidden inside a scoped project', () {
      final v = MarkerVisibility(
          hiddenPins: const {8}, scope: ProjectScope.only({1}));
      expect(v.showsPin(id: 8, fileId: 1), isFalse);
      expect(v.showsPin(id: 9, fileId: 1), isTrue);
    });

    test('isFiltered is true for any of them, so the pill always shows', () {
      expect(const MarkerVisibility().isFiltered, isFalse);
      expect(
          MarkerVisibility(scope: ProjectScope.only({1})).isFiltered, isTrue);
      expect(const MarkerVisibility(hiddenPins: {1}).isFiltered, isTrue);
      expect(const MarkerVisibility(soloPinId: 1).isFiltered, isTrue);
    });

    test('hiddenCount does not count what a scope holds back', () {
      // They get different wording in the UI, so they must not be conflated:
      // "37 markers hidden" about a project scope is alarming and wrong.
      final v = MarkerVisibility(scope: ProjectScope.only({1}));
      expect(v.hiddenCount, 0);
    });
  });

  group('upgrading from the single-project build', () {
    test('a project that was open stays open', () async {
      SharedPreferences.setMockInitialValues({'marker_scope_file_id': 4});
      final n = MarkerVisibilityNotifier();
      await n.restored;
      expect(n.state.scope.isSelected(4), isTrue,
          reason: 'the old key must still be honoured once');
    });

    test('and the new key wins where both exist', () async {
      SharedPreferences.setMockInitialValues({
        'marker_scope_file_id': 4,
        'marker_scope_file_ids': ['7', '8'],
      });
      final n = MarkerVisibilityNotifier();
      await n.restored;
      expect(n.state.scope, ProjectScope.only({7, 8}));
    });

    test('the old key is dropped on the next save, not left to resurface',
        () async {
      SharedPreferences.setMockInitialValues({'marker_scope_file_id': 4});
      final n = MarkerVisibilityNotifier();
      await n.restored;
      await n.closeProject();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('marker_scope_file_id'), isNull,
          reason: 'otherwise show-all is undone by the next restart');
      expect(n.state.scope.isFiltered, isFalse);
    });

    test('nothing stored means everything shown', () async {
      final n = MarkerVisibilityNotifier();
      await n.restored;
      expect(n.state.scope.isFiltered, isFalse);
    });
  });

  group('a project that vanished stops hiding the map', () {
    test('forgetProject drops one without closing the others', () async {
      final n = MarkerVisibilityNotifier();
      await n.showOnlyProjects({1, 2, 3});
      await n.forgetProject(2);

      expect(n.state.scope.isSelected(1), isTrue);
      expect(n.state.scope.isSelected(2), isFalse);
      expect(n.state.scope.isSelected(3), isTrue,
          reason: 'deleting one of three open projects keeps the other two');
    });

    test('forgetting the only one goes back to everything', () async {
      final n = MarkerVisibilityNotifier();
      await n.openProject(1);
      await n.forgetProject(1);
      expect(n.state.scope.isFiltered, isFalse);
    });

    test('pruning catches a project that went by some other route', () async {
      final n = MarkerVisibilityNotifier();
      await n.showOnlyProjects({1, 2});
      await n.pruneProjects({1});
      expect(n.state.scope, ProjectScope.only({1}));
    });

    test('a scope restored AFTER the prune is still checked', () async {
      // The ordering bug: restoring from preferences is async, so the project
      // list can land first. If the only prune happened before the scope
      // existed, a deleted project would keep filtering all session.
      SharedPreferences.setMockInitialValues({
        'marker_scope_file_ids': ['1', '77'],
      });
      final n = MarkerVisibilityNotifier();
      await n.pruneProjects({1});
      await n.restored;

      expect(n.state.scope.isSelected(77), isFalse,
          reason: 'project 77 does not exist and must not survive the load');
      expect(n.state.scope.isSelected(1), isTrue);
    });
  });

  group('toggling', () {
    test('the first tap narrows to that project', () async {
      final n = MarkerVisibilityNotifier();
      await n.toggleProject(5);
      expect(n.state.scope, ProjectScope.only({5}));
    });

    test('a second tap on another adds it', () async {
      final n = MarkerVisibilityNotifier();
      await n.toggleProject(5);
      await n.toggleProject(6);
      expect(n.state.scope, ProjectScope.only({5, 6}));
    });

    test('tapping the last one off shows everything', () async {
      final n = MarkerVisibilityNotifier();
      await n.toggleProject(5);
      await n.toggleProject(5);
      expect(n.state.scope.isFiltered, isFalse);
    });

    test('and it clears a solo, which would otherwise show one marker',
        () async {
      final n = MarkerVisibilityNotifier();
      await n.soloPin(3);
      await n.toggleProject(5);
      expect(n.state.isSoloed, isFalse,
          reason: 'a scoped project showing a single pin looks empty');
    });

    test('the scope survives a round trip through preferences', () async {
      final n = MarkerVisibilityNotifier();
      await n.restored;
      await n.showOnlyProjects({2, 9});

      final again = MarkerVisibilityNotifier();
      await again.restored;
      expect(again.state.scope, ProjectScope.only({2, 9}));
    });

    test('showEverything clears the scope as well as the rest', () async {
      final n = MarkerVisibilityNotifier();
      await n.showOnlyProjects({2});
      await n.togglePin(4);
      await n.showEverything();

      expect(n.state.isFiltered, isFalse);
      expect(n.state.scope.isFiltered, isFalse);
      expect(n.state.hiddenPins, isEmpty);
    });
  });
}
