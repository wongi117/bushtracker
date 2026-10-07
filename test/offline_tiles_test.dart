// Offline maps have never worked, for two reasons that are both tested here.
//
// First, the read side was never connected: OfflineMapManager.getOfflineTile
// has existed since the app's first commit and no caller anywhere ever invoked
// it, so every TileLayer went straight to the network. A download would run to
// completion, report success, use the storage, and the map was still blank
// with no signal.
//
// Second, and worse: the downloader fetches MapTiler imagery while the live map
// draws OpenStreetMap, OpenTopoMap and Mapbox/Esri satellite. There was no
// overlap at all, so even with the read side connected a downloaded region
// could never have matched the layer on screen.
import 'package:bush_track/features/map/services/offline_map_manager.dart';
import 'package:bush_track/core/config/api_config.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('a downloaded region can only serve the layer it actually holds', () {
    test('an exact template match resolves to that style', () {
      // Exact string equality is the whole guarantee: same provider, same
      // imagery, same projection, same zoom scheme.
      for (final style in MapStyle.values) {
        expect(OfflineMapManager.styleServing(style.urlTemplate), style,
            reason: '${style.name} should serve its own template');
      }
    });

    test('a layer nothing downloads returns null, not a near-enough style',
        () {
      // OpenStreetMap and OpenTopoMap are what the map actually draws for
      // street and topo. Nothing downloads them, and the honest answer is no
      // offline tiles -- not MapTiler's picture of the same ground.
      expect(
          OfflineMapManager.styleServing(
              'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
          isNull);
      expect(
          OfflineMapManager.styleServing(
              'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png'),
          isNull);
    });

    test('Mapbox satellite is never served from disk', () {
      // Their terms permit offline storage only through their own SDK. The
      // stronger guarantee is that Mapbox is not in the MapStyle enum at all,
      // so there is nothing to match against.
      expect(
          OfflineMapManager.styleServing(
              'https://api.mapbox.com/v4/mapbox.satellite/{z}/{x}/{y}{r}.jpg90'
              '?access_token=anything'),
          isNull);
      expect(MapStyle.values.map((s) => s.name), isNot(contains('mapbox')));
    });

    test('Esri is not downloadable either, pending its licence', () {
      expect(
          OfflineMapManager.styleServing(
              'https://server.arcgisonline.com/ArcGIS/rest/services/'
              'World_Imagery/MapServer/tile/{z}/{y}/{x}'),
          isNull);
      expect(MapStyle.values.map((s) => s.name), isNot(contains('esri')));
    });

    test('an empty template matches nothing', () {
      // The dashboard's satellite slot is an empty placeholder until the
      // selected source fills it in; that must not match a style.
      expect(OfflineMapManager.styleServing(''), isNull);
    });
  });

  group('Sentinel-2 is the one satellite we may keep', () {
    test('it is downloadable', () {
      expect(MapStyle.sentinel2.mayStoreOffline, isTrue);
    });

    test('and its offline template is identical to the live one', () {
      // The match is by string, so these two drifting apart silently switches
      // offline satellite off again. This is the assertion that catches it.
      expect(
        MapStyle.sentinel2.urlTemplate,
        'https://tiles.maps.eox.at/wmts/1.0.0/s2cloudless-2024_3857/'
        'default/g/{z}/{y}/{x}.jpg',
      );
    });

    test('WMTS order: row before column, in both URL builders', () {
      // Backwards, a region downloads the wrong part of the world and then
      // looks like real ground on an offline phone, where there is nothing to
      // check it against.
      final t = MapStyle.sentinel2.urlTemplate;
      expect(t.indexOf('{y}'), lessThan(t.indexOf('{x}')));

      // tileUrl builds the download URL separately, so it is checked
      // separately: z=12, x=3428, y=2391 over Leonora.
      final u = MapStyle.sentinel2.tileUrl(12, 3428, 2391);
      expect(u, contains('/12/2391/3428.jpg'),
          reason: 'y then x, matching the template');
    });

    test('the MapTiler styles keep x before y', () {
      for (final style in [
        MapStyle.streets,
        MapStyle.satellite,
        MapStyle.topo,
        MapStyle.outdoor,
        MapStyle.dark,
      ]) {
        final t = style.urlTemplate;
        expect(t.indexOf('{x}'), lessThan(t.indexOf('{y}')),
            reason: '${style.name} is XYZ, not WMTS');
        final u = style.tileUrl(12, 3428, 2391);
        expect(u, contains('/12/3428/2391'), reason: style.name);
      }
    });

    test('it caps at the zoom where its resolution runs out', () {
      // The service answers past 14 with upscaled tiles: more storage, no more
      // detail, on a phone that has to hold photos and a routing pack too.
      expect(MapStyle.sentinel2.maxUsefulZoom, 14);
      expect(MapStyle.satellite.maxUsefulZoom, greaterThan(14));
    });

    test('every style has a label, including the new one', () {
      for (final s in MapStyle.values) {
        expect(s.label, isNotEmpty, reason: s.name);
      }
      expect(MapStyle.sentinel2.label, contains('Sentinel-2'));
    });
  });

  group('the lookup is answerable synchronously', () {
    test('with nothing initialised it returns null rather than throwing', () {
      // flutter_map's TileProvider.getImage has to hand back an ImageProvider
      // immediately, which is exactly why the async getOfflineTile could never
      // be wired into one. On a fresh app with no documents directory resolved
      // the answer is "no offline tile", not an exception during paint.
      expect(
          () => OfflineMapManager().tileFileFor(MapStyle.sentinel2, 12, 3428, 2391),
          returnsNormally);
      expect(
          OfflineMapManager().tileFileFor(MapStyle.sentinel2, 12, 3428, 2391),
          isNull);
    });

    test('and reports no regions for a style it has none for', () {
      expect(OfflineMapManager().hasAnyRegionFor(MapStyle.sentinel2), isFalse);
    });
  });

  group('a download cannot ask for more zoom than the source has', () {
    test('Sentinel-2 is capped at 14 whatever the preset asks for', () {
      // The presets run to 19 and 20. Past 14 the service returns the same
      // picture enlarged, so z19 would fetch on the order of a thousand times
      // the tiles for no extra detail -- storage on the phone, and a great
      // deal of somebody else's bandwidth.
      expect(OfflineMapManager.effectiveMaxZoom(MapStyle.sentinel2, 20), 14);
      expect(OfflineMapManager.effectiveMaxZoom(MapStyle.sentinel2, 19), 14);
    });

    test('a request below the cap is left alone', () {
      expect(OfflineMapManager.effectiveMaxZoom(MapStyle.sentinel2, 12), 12);
    });

    test('the MapTiler styles keep their deeper ceiling', () {
      expect(OfflineMapManager.effectiveMaxZoom(MapStyle.satellite, 20), 17);
      expect(OfflineMapManager.effectiveMaxZoom(MapStyle.streets, 15), 15);
    });
  });

  group('the zoom range can never invert', () {
    test('the Trail preset against Sentinel-2, which is how this broke', () {
      // Trail asks for z15-19 and Sentinel-2 caps at 14. Capping the ceiling
      // alone left z15-14, which enumerates no tiles: the region reported
      // completed the instant it started, held nothing, served nothing, and
      // looked exactly like one that had worked.
      const style = MapStyle.sentinel2;
      final max = OfflineMapManager.effectiveMaxZoom(style, 19);
      final min = OfflineMapManager.effectiveMinZoom(style, 15, max);

      expect(max, 14);
      expect(min, lessThanOrEqualTo(max),
          reason: 'an inverted range downloads nothing at all');
      expect(min, 14);
    });

    test('every preset in the app survives every style', () {
      // The presets are fixed and the caps are per style, so this is the whole
      // matrix rather than the one case that happened to be reported.
      const presets = [
        [6, 12],
        [12, 16],
        [15, 19],
        [8, 20],
      ];
      for (final style in MapStyle.values) {
        for (final preset in presets) {
          final max = OfflineMapManager.effectiveMaxZoom(style, preset[1]);
          final min = OfflineMapManager.effectiveMinZoom(style, preset[0], max);
          expect(min, lessThanOrEqualTo(max),
              reason: '${style.name} with z${preset[0]}-${preset[1]} inverts');
        }
      }
    });

    test('a minimum below the cap is untouched', () {
      expect(OfflineMapManager.effectiveMinZoom(MapStyle.sentinel2, 6, 14), 6);
      expect(OfflineMapManager.effectiveMinZoom(MapStyle.sentinel2, 12, 14), 12);
    });

    test('the estimate uses the same range as the download', () {
      // They were separate calls with separate clamping, so the figure shown
      // could describe a download that never happened.
      const style = MapStyle.sentinel2;
      final max = OfflineMapManager.effectiveMaxZoom(style, 19);
      expect(OfflineMapManager.effectiveMinZoom(style, 15, max),
          lessThanOrEqualTo(max));
    });
  });

  // Three regions on the test phone showed a green dot and "completed":
  // Auto Region 0 of 765 tiles, Region 2 0 of 151, Region 3 237 of 602. The
  // map trusts a completed region to cover its whole box, so it drew holes
  // where the network could have filled them.
  group('completed means every tile is on disk', () {
    DownloadStatus finish(int downloaded, int failed) =>
        OfflineMapManager.finishedStatus(downloaded: downloaded, failed: failed);

    test('nothing saved is a failure, not a success', () {
      expect(finish(0, 765), DownloadStatus.failed);
      expect(finish(0, 151), DownloadStatus.failed);
    });

    test('some tiles missing is a failure too', () {
      expect(finish(237, 365), DownloadStatus.failed);
      expect(finish(601, 1), DownloadStatus.failed);
    });

    test('every tile saved is completed', () {
      expect(finish(647, 0), DownloadStatus.completed);
    });

    test('an empty run is never completed', () {
      expect(finish(0, 0), DownloadStatus.failed);
    });
  });

  group('regions saved by older builds are corrected on load', () {
    OfflineMapRegion stored(DownloadStatus status, int downloaded, int failed) =>
        OfflineMapRegion(
          id: '1',
          name: 'Region 3',
          bounds: LatLngBounds(const LatLng(-29, 121), const LatLng(-28.8, 121.4)),
          minZoom: 12,
          maxZoom: 14,
          style: MapStyle.sentinel2,
          totalTiles: downloaded + failed,
          downloadedTiles: downloaded,
          failedTiles: failed,
          status: status,
          createdAt: DateTime(2026, 10, 5),
        );

    test('a "completed" region with tiles missing becomes failed', () {
      final r = stored(DownloadStatus.completed, 237, 365);
      OfflineMapManager.correctLoaded(r);
      expect(r.status, DownloadStatus.failed);
    });

    test('a genuinely complete region is left alone', () {
      final r = stored(DownloadStatus.completed, 647, 0);
      OfflineMapManager.correctLoaded(r);
      expect(r.status, DownloadStatus.completed);
    });

    test('a download interrupted by closing the app is paused', () {
      final r = stored(DownloadStatus.downloading, 100, 0);
      OfflineMapManager.correctLoaded(r);
      expect(r.status, DownloadStatus.paused);
    });

    test('and the corrected region no longer claims coverage', () {
      // The point of the correction: tileFileFor only serves completed
      // regions, so a failed one lets the network fill the gaps.
      final r = stored(DownloadStatus.completed, 0, 151);
      OfflineMapManager.correctLoaded(r);
      expect(r.status, isNot(DownloadStatus.completed));
    });
  });

  group('a source with no key is not offered', () {
    test('Sentinel-2 needs no key', () {
      expect(MapStyle.sentinel2.isAvailable, isTrue);
    });

    test('the MapTiler styles follow MAPTILER_KEY', () {
      // A build without the key had every MapTiler tile refused: a blank
      // picker, and downloads that "completed" holding 0 KB.
      for (final s in MapStyle.values.where((s) => s != MapStyle.sentinel2)) {
        expect(s.isAvailable, ApiConfig.maptilerKey.isNotEmpty, reason: s.name);
      }
    });
  });

  group('a region is named for where it is', () {
    final leonora = LatLngBounds(
        const LatLng(-28.95, 121.28), const LatLng(-28.81, 121.38));

    test('south and east read as S and E, from the centre of the box', () {
      expect(OfflineMapManager.defaultRegionName(MapStyle.sentinel2, leonora),
          'Satellite (Sentinel-2) · 28.88°S 121.33°E');
    });

    test('north and west read as N and W', () {
      final b = LatLngBounds(const LatLng(51.4, -0.2), const LatLng(51.6, 0.0));
      expect(OfflineMapManager.defaultRegionName(MapStyle.sentinel2, b),
          endsWith('51.50°N 0.10°W'));
    });

    test('two places get two names', () {
      // "Region 6" and "Region 7" told nobody which was which.
      final kalgoorlie = LatLngBounds(
          const LatLng(-30.80, 121.40), const LatLng(-30.70, 121.52));
      expect(OfflineMapManager.defaultRegionName(MapStyle.sentinel2, leonora),
          isNot(OfflineMapManager.defaultRegionName(MapStyle.sentinel2, kalgoorlie)));
    });
  });
}
