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
}
