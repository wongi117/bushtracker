// A filter you cannot see is indistinguishable from lost data, so the rules
// about what gets drawn have to be exactly right — and they compose three ways,
// which is where the bugs live.
import 'package:bush_track/features/map/providers/marker_visibility_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('nothing filtered', () {
    const all = MarkerVisibility();

    test('everything is drawn', () {
      expect(all.showsPin(id: 1, fileId: 7), isTrue);
      expect(all.showsPin(id: 2), isTrue);
      expect(all.showsZone(id: 3, fileId: 9), isTrue);
      expect(all.showsZone(id: 4), isTrue);
    });

    test('and the map has nothing to warn about', () {
      expect(all.isFiltered, isFalse);
      expect(all.isScoped, isFalse);
      expect(all.isSoloed, isFalse);
    });
  });

  group('opening a project', () {
    const scoped = MarkerVisibility(scopeFileId: 5);

    test('shows that project and nothing else', () {
      expect(scoped.showsPin(id: 1, fileId: 5), isTrue);
      expect(scoped.showsPin(id: 2, fileId: 6), isFalse);
      expect(scoped.showsZone(id: 3, fileId: 5), isTrue);
      expect(scoped.showsZone(id: 4, fileId: 6), isFalse);
    });

    test('loose work is out of scope too', () {
      // "Open a project folder and only see the pins in that project" means
      // pins belonging to no project are not in it either.
      expect(scoped.showsPin(id: 1), isFalse);
      expect(scoped.showsZone(id: 2), isFalse);
    });

    test('a pin filed under the project but put away by hand stays away', () {
      const s = MarkerVisibility(scopeFileId: 5, hiddenPins: {1});
      expect(s.showsPin(id: 1, fileId: 5), isFalse);
      expect(s.showsPin(id: 2, fileId: 5), isTrue);
    });

    test('the scope survives a pin that did not exist when it was set', () {
      // The bug in the old approach: isolating wrote every other id into a
      // hidden list, so anything created afterwards was not on the list and
      // turned up anyway. A rule about filing does not have that problem.
      const s = MarkerVisibility(scopeFileId: 5);
      // A brand new pin, id higher than anything around when the scope was set.
      expect(s.showsPin(id: 99999, fileId: 6), isFalse);
      expect(s.showsPin(id: 99999, fileId: 5), isTrue);
    });

    test('the map knows to say it is not showing everything', () {
      expect(scoped.isFiltered, isTrue);
      expect(scoped.isScoped, isTrue);
    });
  });

  group('one thing on its own', () {
    test('a soloed pin is the only pin, and there are no zones', () {
      const s = MarkerVisibility(soloPinId: 3);
      expect(s.showsPin(id: 3), isTrue);
      expect(s.showsPin(id: 4), isFalse);
      expect(s.showsZone(id: 3), isFalse);
      expect(s.showsZone(id: 5), isFalse);
    });

    test('a soloed zone is the only zone, and there are no pins', () {
      const s = MarkerVisibility(soloZoneId: 3);
      expect(s.showsZone(id: 3), isTrue);
      expect(s.showsZone(id: 4), isFalse);
      expect(s.showsPin(id: 3), isFalse);
    });

    test('solo beats a hand-hidden entry, so it cannot show nothing at all', () {
      // Soloing something you had previously put away has to show it, or the
      // button appears to do nothing.
      const s = MarkerVisibility(soloPinId: 3, hiddenPins: {3});
      expect(s.showsPin(id: 3), isTrue);
    });

    test('solo beats the project scope as well', () {
      // Same reasoning: picking one pin out of a list shows that pin, whatever
      // it is filed under.
      const s = MarkerVisibility(soloPinId: 3, scopeFileId: 5);
      expect(s.showsPin(id: 3, fileId: 88), isTrue);
      expect(s.showsPin(id: 4, fileId: 5), isFalse);
    });
  });

  group('the notifier', () {
    test('opening a project sets the scope and drops any solo', () {
      final n = MarkerVisibilityNotifier();
      n.state = const MarkerVisibility(soloPinId: 9);
      n.openProject(4);
      expect(n.state.scopeFileId, 4);
      expect(n.state.soloPinId, isNull,
          reason: 'a project plus a solo would show one pin and look empty');
    });

    test('closing a project goes back to everything', () {
      final n = MarkerVisibilityNotifier();
      n.state = const MarkerVisibility(scopeFileId: 4);
      n.closeProject();
      expect(n.state.scopeFileId, isNull);
      expect(n.state.isFiltered, isFalse);
    });

    test('closing a project keeps what was put away by hand', () {
      // Those are two separate decisions and one should not undo the other.
      final n = MarkerVisibilityNotifier();
      n.state = const MarkerVisibility(scopeFileId: 4, hiddenPins: {1, 2});
      n.closeProject();
      expect(n.state.hiddenPins, {1, 2});
    });

    test('deleting the open project stops scoping to it', () {
      // Otherwise the map scopes to a project that no longer exists and shows
      // nothing, with no obvious way back.
      final n = MarkerVisibilityNotifier();
      n.state = const MarkerVisibility(scopeFileId: 4);
      n.forgetProject(4);
      expect(n.state.scopeFileId, isNull);
    });

    test('deleting some other project leaves the scope alone', () {
      final n = MarkerVisibilityNotifier();
      n.state = const MarkerVisibility(scopeFileId: 4);
      n.forgetProject(7);
      expect(n.state.scopeFileId, 4);
    });

    test('soloing a pin replaces a soloed zone rather than adding to it', () {
      final n = MarkerVisibilityNotifier();
      n.state = const MarkerVisibility(soloZoneId: 2);
      n.soloPin(5);
      expect(n.state.soloPinId, 5);
      expect(n.state.soloZoneId, isNull,
          reason: 'both at once draws nothing at all');
    });

    test('soloing keeps the project you are working in', () {
      final n = MarkerVisibilityNotifier();
      n.state = const MarkerVisibility(scopeFileId: 4);
      n.soloPin(5);
      expect(n.state.scopeFileId, 4);
    });

    test('hiding something by hand ends a solo', () {
      // Reaching for the eye on a list means going back to a list view; leaving
      // the solo on would make every other row look broken.
      final n = MarkerVisibilityNotifier();
      n.state = const MarkerVisibility(soloPinId: 9);
      n.togglePin(3);
      expect(n.state.soloPinId, isNull);
      expect(n.state.hiddenPins, {3});
    });

    test('toggling twice puts it back', () {
      final n = MarkerVisibilityNotifier();
      n.togglePin(3);
      expect(n.state.showsPin(id: 3), isFalse);
      n.togglePin(3);
      expect(n.state.showsPin(id: 3), isTrue);
    });

    test('show everything clears all three mechanisms at once', () {
      final n = MarkerVisibilityNotifier();
      n.state = const MarkerVisibility(
        hiddenPins: {1, 2},
        hiddenZones: {3},
        scopeFileId: 4,
        soloPinId: 5,
      );
      n.showEverything();
      expect(n.state.isFiltered, isFalse);
      expect(n.state.showsPin(id: 1, fileId: 88), isTrue);
      expect(n.state.showsZone(id: 3), isTrue);
    });
  });

  group('counting', () {
    test('only hand-hidden things are counted', () {
      // The badge means "you put these away". A project scope holds back far
      // more than that and says so in its own words, so mixing the two into one
      // number would be alarming and useless.
      const s = MarkerVisibility(
          hiddenPins: {1, 2}, hiddenZones: {3}, scopeFileId: 9);
      expect(s.hiddenCount, 3);
    });
  });
}
