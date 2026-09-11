import 'package:flutter_test/flutter_test.dart';
import 'package:bush_track/features/navigation/providers/navigation_provider.dart';

void main() {
  group('describeManoeuvre', () {
    String d(String? t, String? m, String? r) =>
        NavigationNotifier.describeManoeuvre(t, m, r);

    test('turns say which way and onto what', () {
      expect(d('turn', 'left', 'Leonora-Gwalia Road'),
          'Turn left onto Leonora-Gwalia Road');
      expect(d('turn', 'slight right', 'Tower St'), 'Turn slight right onto Tower St');
    });

    test('straight is not "turn straight"', () {
      expect(d('turn', 'straight', 'Main St'), 'Continue straight onto Main St');
    });

    test('depart, arrive, roundabout, u-turn', () {
      expect(d('depart', null, 'Queen Victoria St'), 'Head off along Queen Victoria St');
      expect(d('arrive', null, 'anything'), 'Arrive at your destination');
      expect(d('roundabout', 'right', 'Hoover St'), 'Take the roundabout onto Hoover St');
      expect(d('turn', 'uturn', 'Hoover St'), 'Make a U-turn along Hoover St');
    });

    test('no road name still reads naturally', () {
      expect(d('turn', 'right', ''), 'Turn right');
      expect(d('turn', 'right', null), 'Turn right');
    });
  });

  group('formatSpokenDistance', () {
    String f(double m) => NavigationNotifier.formatSpokenDistance(m);
    test('rounds metres to 50', () {
      expect(f(430), '450 metres');
      expect(f(120), '100 metres');
    });
    test('kilometres', () {
      expect(f(2340), '2.3 kilometres');
      expect(f(45200), '45 kilometres');
    });
  });
}
