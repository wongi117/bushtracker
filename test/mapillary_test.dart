// Street imagery is the only online-only feature in this app, so most of what
// matters is how it behaves when it cannot work: no token, no signal, zoomed
// too far out, or a response that is empty for a reason other than "no
// coverage here".
import 'dart:convert';

import 'package:bush_track/features/streetview/providers/mapillary_provider.dart';
import 'package:bush_track/features/streetview/services/mapillary_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('parsing a Mapillary response', () {
    test('reads id, position, date and bearing', () {
      final photos = MapillaryService.parseList(jsonEncode({
        'data': [
          {
            'id': '1238554193213546',
            'geometry': {
              'type': 'Point',
              'coordinates': [121.3333, -28.8833],
            },
            'captured_at': 1548731950447,
            'compass_angle': 275.5,
          },
        ],
      }));

      expect(photos, hasLength(1));
      final p = photos.single;
      expect(p.id, '1238554193213546');
      expect(p.position.latitude, closeTo(-28.8833, 0.0001));
      expect(p.position.longitude, closeTo(121.3333, 0.0001));
      expect(p.capturedAt!.year, 2019);
      expect(p.compassAngle, 275.5);
    });

    test('GeoJSON order is longitude first, and getting it wrong is obvious',
        () {
      // [lon, lat], the opposite of how every other coordinate in this app is
      // written. Reading it the usual way round would plot Western Australia
      // off the coast of Somalia.
      final photos = MapillaryService.parseList(jsonEncode({
        'data': [
          {
            'id': '1',
            'geometry': {'coordinates': [121.3333, -28.8833]},
          },
        ],
      }));
      expect(photos.single.position.latitude, lessThan(0),
          reason: 'latitude should be the southern one');
      expect(photos.single.position.longitude, greaterThan(100));
    });

    test('prefers the corrected position over the raw camera GPS', () {
      // computed_geometry is Mapillary's own correction and is the better one.
      final photos = MapillaryService.parseList(jsonEncode({
        'data': [
          {
            'id': '1',
            'geometry': {'coordinates': [121.0, -28.0]},
            'computed_geometry': {'coordinates': [121.5, -28.5]},
          },
        ],
      }));
      expect(photos.single.position.longitude, 121.5);
    });

    test('falls back to raw geometry when there is no correction', () {
      final photos = MapillaryService.parseList(jsonEncode({
        'data': [
          {'id': '1', 'geometry': {'coordinates': [121.0, -28.0]}},
        ],
      }));
      expect(photos.single.position.longitude, 121.0);
    });

    test('an empty list is no coverage, not an error', () {
      expect(MapillaryService.parseList('{"data":[]}'), isEmpty);
    });

    test('entries with no usable position are skipped, not guessed at', () {
      final photos = MapillaryService.parseList(jsonEncode({
        'data': [
          {'id': '1'},
          {'id': '2', 'geometry': {'coordinates': []}},
          {'id': '3', 'geometry': {'coordinates': [121.0, -28.0]}},
        ],
      }));
      expect(photos.map((p) => p.id), ['3']);
    });

    test('an out-of-range coordinate is refused', () {
      final photos = MapillaryService.parseList(jsonEncode({
        'data': [
          {'id': '1', 'geometry': {'coordinates': [500.0, 200.0]}},
        ],
      }));
      expect(photos, isEmpty);
    });

    test('rubbish does not throw', () {
      expect(MapillaryService.parseList('not json'), isEmpty);
      expect(MapillaryService.parseList('{"data":"not a list"}'), isEmpty);
      expect(MapillaryService.parseList('{}'), isEmpty);
    });

    test('a photo with no date still parses', () {
      final photos = MapillaryService.parseList(jsonEncode({
        'data': [
          {'id': '1', 'geometry': {'coordinates': [121.0, -28.0]}},
        ],
      }));
      expect(photos.single.capturedAt, isNull);
    });
  });

  group('why the layer is unavailable', () {
    test('every reason has wording, so the toggle can explain itself', () {
      for (final blocked in StreetViewBlocked.values) {
        final state = StreetViewState(blocked: blocked);
        if (blocked == StreetViewBlocked.none) {
          expect(state.reason, isEmpty);
          expect(state.usable, isTrue);
        } else {
          expect(state.reason.trim(), isNotEmpty,
              reason: '$blocked has no explanation');
          expect(state.usable, isFalse);
        }
      }
    });

    test('offline says it needs a connection, not that it failed', () {
      const state = StreetViewState(blocked: StreetViewBlocked.offline);
      expect(state.reason.toLowerCase(), contains('connection'));
    });

    test('a missing token says so, rather than looking like no coverage', () {
      // The trap this guards: the wrong Mapillary token returns HTTP 200 with
      // an empty list, which is indistinguishable from a region with no
      // photos. If the token is missing entirely we can at least say so.
      const state = StreetViewState(blocked: StreetViewBlocked.noToken);
      expect(state.reason.toLowerCase(), contains('token'));
    });

    test('zoomed out asks the user to zoom in', () {
      const state = StreetViewState(blocked: StreetViewBlocked.zoomedOut);
      expect(state.reason.toLowerCase(), contains('zoom'));
    });
  });

  group('the layer state', () {
    test('starts off, with nothing loaded', () {
      const state = StreetViewState();
      expect(state.enabled, isFalse);
      expect(state.photos, isEmpty);
      expect(state.loading, isFalse);
    });

    test('copyWith leaves the rest alone', () {
      const before = StreetViewState(enabled: true, loading: true);
      final after = before.copyWith(loading: false);
      expect(after.enabled, isTrue);
      expect(after.loading, isFalse);
    });

    test('the minimum zoom is high enough not to ask for a continent', () {
      // A bbox query over WA at low zoom would return a meaningless sample of
      // an enormous area.
      expect(StreetViewNotifier.minZoom, greaterThanOrEqualTo(12));
    });
  });

  group('the service with no token', () {
    test('returns nothing rather than calling out', () async {
      // In a test build there is no token, so these must short-circuit — not
      // hit the network and not throw.
      final service = MapillaryService();
      addTearDown(service.dispose);

      if (service.hasToken) return; // a build with a token; nothing to prove

      // Corners around Leonora.
      expect(
          await service.coverage(
            southWest: LatLng(-28.92, 121.28),
            northEast: LatLng(-28.84, 121.38),
          ),
          isEmpty);
      expect(await service.nearest(LatLng(-28.88, 121.33)), isNull);
    });
  });
}
