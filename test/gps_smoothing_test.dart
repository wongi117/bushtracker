import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:bush_track/features/tracking/providers/location_provider.dart';

Position fix(double lat, double lon, {double accuracy = 8}) => Position(
      latitude: lat,
      longitude: lon,
      timestamp: DateTime(2026),
      accuracy: accuracy,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

double metres(Position a, double lat, double lon) =>
    const Distance()(LatLng(a.latitude, a.longitude), LatLng(lat, lon));

void main() {
  const lat0 = -28.88875, lon0 = 121.33617; // Leonora
  const oneMetre = 1 / 111320; // degrees of latitude

  test('standing still: jitter is averaged towards the true spot', () {
    final fixes = [
      fix(lat0 + 3 * oneMetre, lon0),
      fix(lat0 - 2 * oneMetre, lon0),
      fix(lat0 + 1 * oneMetre, lon0),
      fix(lat0 - 3 * oneMetre, lon0),
      fix(lat0 + 1 * oneMetre, lon0), // newest
    ];
    final p = LocationNotifier.smoothFixes(fixes);
    expect(metres(p, lat0, lon0), lessThan(1.0));
  });

  test('driving (fixes ~28 m apart): no lag — the newest fix wins', () {
    final fixes = [
      for (var i = 0; i < 5; i++) fix(lat0 + i * 28 * oneMetre, lon0),
    ];
    final p = LocationNotifier.smoothFixes(fixes);
    // The old plain mean sat on fix #3, 56 m behind.
    expect(metres(p, fixes.last.latitude, lon0), lessThan(0.5));
  });

  test('walking (fixes 5 m apart): lag stays a few metres, not two fixes', () {
    final fixes = [
      for (var i = 0; i < 5; i++) fix(lat0 + i * 5 * oneMetre, lon0, accuracy: 5),
    ];
    final p = LocationNotifier.smoothFixes(fixes);
    expect(metres(p, fixes.last.latitude, lon0), lessThan(6));
  });

  test('a single fix is returned as-is', () {
    final p = LocationNotifier.smoothFixes([fix(lat0, lon0)]);
    expect(metres(p, lat0, lon0), lessThan(0.01));
  });

  // The field report: "it's showing the wrong place, I'm in a different
  // street, and the pin bounces around a lot."
  group('rubbish fixes', () {
    test('a tower fix on another street does not move the marker', () {
      final fixes = [
        fix(lat0, lon0, accuracy: 6),
        fix(lat0 + oneMetre, lon0, accuracy: 6),
        fix(lat0 + 2 * oneMetre, lon0, accuracy: 5),
        // 400 m away, reported as accurate to 1.2 km — a wifi/tower fix.
        fix(lat0 + 400 * oneMetre, lon0, accuracy: 1200),
      ];
      final p = LocationNotifier.smoothFixes(fixes);
      expect(metres(p, lat0, lon0), lessThan(10),
          reason: 'the tower fix should have been discarded, not averaged in');
    });

    test('a merely mediocre fix is still used', () {
      // 25 m accuracy is a real GPS fix under tree cover. Dropping these
      // would leave the marker frozen whenever the sky is poor.
      final fixes = [
        fix(lat0, lon0, accuracy: 20),
        fix(lat0 + 2 * oneMetre, lon0, accuracy: 25),
      ];
      final p = LocationNotifier.smoothFixes(fixes);
      expect(metres(p, lat0, lon0), lessThan(3));
    });

    test('when every fix is poor, the newest is still returned', () {
      // Indoors with no GPS at all: show something, and let the accuracy
      // readout tell the truth about it.
      final fixes = [
        fix(lat0, lon0, accuracy: 900),
        fix(lat0 + 50 * oneMetre, lon0, accuracy: 800),
      ];
      final p = LocationNotifier.smoothFixes(fixes);
      expect(p.accuracy, greaterThan(100));
      expect(metres(p, lat0 + 50 * oneMetre, lon0), lessThan(5));
    });
  });
}
