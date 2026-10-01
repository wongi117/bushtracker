// Two satellite providers, swapped in the field. The point of the setting is a
// like-for-like comparison, so the things that must hold are that each source
// produces a usable tile template, carries its required attribution, and that
// the map never ends up on a source it cannot load.
import 'package:bush_track/core/config/api_config.dart';
import 'package:bush_track/features/map/providers/satellite_source_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('tile templates', () {
    test('ESRI uses the y/x order its service expects', () {
      // ESRI's REST tile endpoint is /{z}/{y}/{x}, not /{z}/{x}/{y}. Getting
      // this the usual way round silently serves imagery from the wrong place.
      expect(SatelliteSource.esri.urlTemplate, contains('/{z}/{y}/{x}'));
    });

    test('Mapbox uses x/y, retina and jpeg', () {
      final url = SatelliteSource.mapbox.urlTemplate;
      expect(url, contains('/{z}/{x}/{y}'));
      expect(url, contains('@2x'));
      // Satellite imagery is photographic; PNG would triple the bytes over a
      // mobile connection for no visible gain.
      expect(url, contains('jpg90'));
    });

    test('Mapbox carries the access token', () {
      expect(SatelliteSource.mapbox.urlTemplate, contains('access_token='));
    });

    test('every source has a template with all three placeholders', () {
      for (final source in SatelliteSource.values) {
        for (final token in ['{z}', '{x}', '{y}']) {
          expect(source.urlTemplate, contains(token),
              reason: '${source.name} is missing $token');
        }
      }
    });
  });

  group('zoom caps', () {
    test('ESRI stops at 17, where remote WA runs out of imagery', () {
      // Measured across Leonora, the Gibson, the Nullarbor, the Pilbara and
      // the Kimberley: past 17 it returns a 2 KB grey placeholder.
      expect(SatelliteSource.esri.maxNativeZoom, 17);
    });

    test('Mapbox goes deeper, which is the reason to try it', () {
      expect(SatelliteSource.mapbox.maxNativeZoom,
          greaterThan(SatelliteSource.esri.maxNativeZoom));
    });

    test('no source claims a zoom flutter_map would refuse', () {
      for (final source in SatelliteSource.values) {
        expect(source.maxNativeZoom, inInclusiveRange(1, 22));
      }
    });
  });

  group('attribution', () {
    test('every source has some, because every licence requires it', () {
      for (final source in SatelliteSource.values) {
        expect(source.attribution.trim(), isNotEmpty);
      }
    });

    test('Mapbox credits both Mapbox and OpenStreetMap, as its terms require',
        () {
      expect(SatelliteSource.mapbox.attribution, contains('Mapbox'));
      expect(SatelliteSource.mapbox.attribution, contains('OpenStreetMap'));
    });

    test('ESRI credits Esri', () {
      expect(SatelliteSource.esri.attribution, contains('Esri'));
    });

    test('each source has its own wording and its own short name', () {
      final full = SatelliteSource.values.map((s) => s.attribution).toSet();
      final short = SatelliteSource.values.map((s) => s.shortLabel).toSet();
      expect(full, hasLength(SatelliteSource.values.length));
      expect(short, hasLength(SatelliteSource.values.length));
    });
  });

  group('availability', () {
    test('ESRI always works — no key, no account', () {
      expect(SatelliteSource.esri.isAvailable, isTrue);
    });

    test('Mapbox depends on a token being in the build', () {
      // Which is the whole fallback design: a build with no config/pinage.json
      // behaves exactly as the app did before any of this.
      expect(SatelliteSource.mapbox.isAvailable, ApiConfig.hasMapbox);
    });

    test('and there is always at least one source that works', () {
      expect(SatelliteSource.values.any((s) => s.isAvailable), isTrue);
    });
  });

  group('the setting', () {
    test('starts on ESRI, which is what the app has always shown', () {
      expect(SatelliteSourceNotifier().state, SatelliteSource.esri);
    });

    test('toggling moves to the other source and back', () async {
      final n = SatelliteSourceNotifier();
      if (!SatelliteSource.mapbox.isAvailable) {
        // Without a token in the test build, toggling must change nothing
        // rather than leave the map on a source that cannot load.
        await n.toggle();
        expect(n.state, SatelliteSource.esri);
        return;
      }
      await n.toggle();
      expect(n.state, SatelliteSource.mapbox);
      await n.toggle();
      expect(n.state, SatelliteSource.esri);
    });

    test('an unavailable source is refused rather than selected', () async {
      final n = SatelliteSourceNotifier();
      await n.use(SatelliteSource.mapbox);
      if (ApiConfig.hasMapbox) {
        expect(n.state, SatelliteSource.mapbox);
      } else {
        expect(n.state, SatelliteSource.esri,
            reason: 'a source with no token must not be selectable');
      }
    });
  });
}
