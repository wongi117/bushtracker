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

    test('Mapbox uses x/y, the {r} placeholder, and jpeg', () {
      final url = SatelliteSource.mapbox.urlTemplate;
      expect(url, contains('/{z}/{x}/{y}'));
      // Satellite imagery is photographic; PNG would triple the bytes over a
      // mobile connection for no visible gain.
      expect(url, contains('jpg90'));
    });

    test('Mapbox asks for retina with {r}, never a hardcoded @2x', () {
      // This one is billable. flutter_map fills {r} with "@2x" on a
      // high-density screen and nothing otherwise — one request either way.
      // With @2x written in and no {r} present it *simulates* retina instead,
      // "requesting four tiles at a larger zoom level and combining them", so
      // every tile becomes four already-doubled requests and the top zoom
      // level is lost.
      final url = SatelliteSource.mapbox.urlTemplate;
      expect(url, contains('{r}'));
      expect(url, isNot(contains('@2x')),
          reason: 'a hardcoded @2x quadruples the Mapbox bill');
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
    test('starts on Mapbox where there is a token, Esri where there is not',
        () {
      // Esri was the default for as long as this app existed. It is now the
      // comparison option only: its licence is the Esri Master License
      // Agreement and its stated use is "in various ArcGIS apps", which this
      // is not. A build with no Mapbox token still falls back rather than
      // failing.
      expect(
          SatelliteSourceNotifier().state,
          SatelliteSource.mapbox.isAvailable
              ? SatelliteSource.mapbox
              : SatelliteSource.esri);
    });

    test('toggling moves to the other source and back', () async {
      // Start-agnostic on purpose: which source it opens on depends on whether
      // the build has a Mapbox token, and the toggle has to work either way.
      final n = SatelliteSourceNotifier();
      final started = n.state;

      if (!SatelliteSource.mapbox.isAvailable) {
        // Without a token there is only one usable source, so toggling must
        // change nothing rather than leave the map on one that cannot load.
        await n.toggle();
        expect(n.state, SatelliteSource.esri);
        return;
      }

      await n.toggle();
      expect(n.state, isNot(started));
      await n.toggle();
      expect(n.state, started);
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
