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

    test('toggling cycles every usable source and comes back round', () async {
      // Was a two-way flip. With Sentinel-2 added that would never reach the
      // third source, so the field comparison could not be driven from the
      // one button it is meant to be driven from.
      //
      // Start-agnostic on purpose: which source it opens on depends on whether
      // the build has a Mapbox token, and this has to work either way.
      final n = SatelliteSourceNotifier();
      final started = n.state;
      final usable =
          SatelliteSource.values.where((s) => s.isAvailable).toList();

      final seen = <SatelliteSource>{started};
      for (var i = 0; i < usable.length; i++) {
        await n.toggle();
        seen.add(n.state);
      }

      expect(seen.length, usable.length,
          reason: 'every usable source should be reachable by tapping');
      expect(n.state, started,
          reason: 'a full cycle returns to where it began');
    });

    test('and never lands on a source that cannot load', () async {
      final n = SatelliteSourceNotifier();
      for (var i = 0; i < SatelliteSource.values.length + 1; i++) {
        await n.toggle();
        expect(n.state.isAvailable, isTrue);
      }
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

  group('Sentinel-2, the only one that can be stored offline', () {
    test('it needs no token, which is half its argument', () {
      expect(SatelliteSource.sentinel2.isAvailable, isTrue);
      expect(SatelliteSource.sentinel2.urlTemplate,
          isNot(contains('access_token')));
    });

    test('y comes before x, because WMTS orders the path row-then-column', () {
      // Swapping them returns tiles from the wrong part of the world, which on
      // a satellite basemap looks like real ground rather than like an error.
      final t = SatelliteSource.sentinel2.urlTemplate;
      expect(t.indexOf('{y}'), lessThan(t.indexOf('{x}')));
      expect(SatelliteSource.mapbox.urlTemplate.indexOf('{x}'),
          lessThan(SatelliteSource.mapbox.urlTemplate.indexOf('{y}')));
    });

    test('it stops at 14, where 10 m resolution runs out', () {
      // The service answers past this, but the tiles get smaller as the zoom
      // climbs -- 16.5 KB at z13 against 10.7 KB at z16 over Leonora, measured
      // against the live endpoint. That is upscaling compressing well, not
      // detail arriving. A z14 tile at this latitude is about 8.4 m/px.
      expect(SatelliteSource.sentinel2.maxNativeZoom, 14);
    });

    test('and it is the coarsest of the three, which is the trade-off', () {
      expect(SatelliteSource.sentinel2.maxNativeZoom,
          lessThan(SatelliteSource.esri.maxNativeZoom));
      expect(SatelliteSource.esri.maxNativeZoom,
          lessThan(SatelliteSource.mapbox.maxNativeZoom));
    });

    test('the attribution credits EOX and says the data is modified', () {
      // CC BY 4.0 requires both.
      final a = SatelliteSource.sentinel2.attribution;
      expect(a, contains('EOX'));
      expect(a.toLowerCase(), contains('modified'));
      expect(a, contains('Copernicus'));
    });
  });

  group('one chosen source, every screen', () {
    test('resolved keeps an available source as it is', () {
      expect(SatelliteSource.sentinel2.resolved, SatelliteSource.sentinel2);
      expect(SatelliteSource.esri.resolved, SatelliteSource.esri);
    });

    test('and falls back rather than drawing nothing', () {
      // Three screens used to each decide for themselves whether to use
      // Mapbox, which would have made the field comparison report whichever
      // screen happened to be open rather than the imagery being judged.
      expect(SatelliteSource.mapbox.resolved.isAvailable, isTrue);
    });

    test('MapLibre gets @2x outright, because it has no {r} placeholder', () {
      // It would otherwise request a URL containing a literal "{r}". One
      // request per tile either way; it is only flutter_map that turns a
      // hardcoded @2x into four.
      final t = SatelliteSource.mapbox.urlTemplateForMapLibre;
      expect(t, contains('@2x'));
      expect(t, isNot(contains('{r}')));
    });

    test('and a template with no {r} is left alone', () {
      expect(SatelliteSource.sentinel2.urlTemplateForMapLibre,
          SatelliteSource.sentinel2.urlTemplate);
      expect(SatelliteSource.esri.urlTemplateForMapLibre,
          SatelliteSource.esri.urlTemplate);
    });
  });
}
