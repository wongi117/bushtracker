// Place search on the phone: it called relative /api/... URLs, which the
// phone cannot resolve, and every failure came back as an empty list -- so a
// search that never happened read "No results". On 8 Oct the site itself was
// answering 402 (deployment disabled), which made it every search.
import 'package:bush_track/features/places/providers/places_provider.dart';
import 'package:bush_track/features/places/services/places_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

void main() {
  const leonora = LatLng(-28.88, 121.33);

  test('the phone calls the deployed site, not a relative path', () {
    // Tests run as the phone does (not web).
    expect(PlacesService.proxied('/api/nominatim'),
        startsWith('https://'));
    expect(Uri.parse(PlacesService.proxied('/api/overpass')).host, isNotEmpty);
  });

  test('a search goes to that host', () async {
    Uri? asked;
    await http.runWithClient(
      () => PlacesService.searchPlaces('Leonora'),
      () => MockClient((r) async {
        asked = r.url;
        return http.Response('[]', 200);
      }),
    );
    expect(asked!.host, isNotEmpty);
    expect(asked!.path, '/api/nominatim');
    expect(asked!.queryParameters['q'], 'Leonora');
  });

  test('a service that answers 402 is unavailable, not empty', () async {
    final call = http.runWithClient(
      () => PlacesService.searchPlaces('Leonora'),
      () => MockClient((_) async => http.Response('Payment required', 402)),
    );
    await expectLater(call, throwsA(isA<PlacesUnavailable>()));
  });

  test('so is a nearby lookup that cannot connect', () async {
    final call = http.runWithClient(
      () => PlacesService.getNearbyPlaces(leonora),
      () => MockClient((_) async => throw http.ClientException('no signal')),
    );
    await expectLater(call, throwsA(isA<PlacesUnavailable>()));
  });

  test('a real empty answer is still empty', () async {
    final places = await http.runWithClient(
      () => PlacesService.searchPlaces('nowhere at all'),
      () => MockClient((_) async => http.Response('[]', 200)),
    );
    expect(places, isEmpty);
  });

  group('the screen is told which it was', () {
    test('unavailable says so, and that the phone still works', () async {
      final n = PlacesNotifier();
      await http.runWithClient(
        () => n.searchPlaces('Leonora'),
        () => MockClient((_) async => http.Response('', 402)),
      );
      expect(n.state.error, PlacesNotifier.unavailableMessage);
      expect(n.state.places, isEmpty);
    });

    test('a later good search clears it', () async {
      // copyWith used `error ?? this.error`, so this error stuck forever.
      final n = PlacesNotifier();
      await http.runWithClient(
        () => n.searchPlaces('Leonora'),
        () => MockClient((_) async => http.Response('', 402)),
      );
      await http.runWithClient(
        () => n.searchPlaces('Leonora'),
        () => MockClient((_) async => http.Response('[]', 200)),
      );
      expect(n.state.error, isNull);
    });
  });
}
