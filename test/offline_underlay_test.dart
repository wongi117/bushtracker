// "when we are offline the maps are blury until im online and have to manually
// switch maps should make it auto matic"
//
// The satellite layer most people use is Mapbox, which may not be stored
// offline outside their SDK. With no signal it drew nothing, and the user had
// to switch to Sentinel-2 by hand and back again later. A downloaded region is
// now drawn underneath, from disk only, and shows through wherever the layer
// above has no tile -- decided tile by tile, so nothing needs to know whether
// there is signal.
import 'dart:io';

import 'package:bush_track/features/map/providers/satellite_source_provider.dart';
import 'package:bush_track/features/map/services/offline_first_tile_provider.dart';
import 'package:bush_track/features/map/services/offline_map_manager.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:latlong2/latlong.dart';

void main() {
  group('which download goes under which layer', () {
    MapStyle? pick(bool imagery, List<MapStyle> have) =>
        OfflineMapManager.underlayFor(imagery: imagery, downloaded: have);

    test('satellite imagery under a satellite layer', () {
      expect(pick(true, [MapStyle.topo, MapStyle.sentinel2]), MapStyle.sentinel2);
    });

    test('a map under a map', () {
      expect(pick(false, [MapStyle.sentinel2, MapStyle.topo]), MapStyle.topo);
    });

    test('imagery under a map beats a blank screen', () {
      // Sentinel-2 is all the test phone has. Offline on the topo layer it
      // should still show the ground.
      expect(pick(false, [MapStyle.sentinel2]), MapStyle.sentinel2);
    });

    test('nothing downloaded, nothing underneath', () {
      expect(pick(true, const []), isNull);
    });
  });

  // A region is complete only when every tile saved, and the test phone had
  // none that were. Serving only "completed" regions would have shown nothing
  // offline at all -- not even the tiles that are on disk.
  group('tiles on disk are served, whatever the region says', () {
    late Directory temp;
    final bounds =
        LatLngBounds(const LatLng(-28.95, 121.28), const LatLng(-28.81, 121.38));
    // A tile inside those bounds at z14.
    const z = 14, x = 13713, y = 9565;

    OfflineMapRegion region(String id, DownloadStatus status, {int saved = 1}) =>
        OfflineMapRegion(
          id: id,
          name: id,
          bounds: bounds,
          minZoom: 12,
          maxZoom: 14,
          style: MapStyle.sentinel2,
          totalTiles: 10,
          downloadedTiles: saved,
          failedTiles: 10 - saved,
          status: status,
          createdAt: DateTime(2026, 10, 7),
        );

    Future<void> putTile(String regionId) async {
      final d = Directory('${temp.path}/$regionId');
      await d.create(recursive: true);
      await File('${d.path}/${z}_${x}_$y').writeAsBytes([1, 2, 3]);
    }

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('underlay_test');
    });
    tearDown(() async {
      OfflineMapManager().attachForTest(null);
      await temp.delete(recursive: true);
    });

    test('an incomplete region serves the tiles it has', () async {
      await putTile('r1');
      OfflineMapManager()
          .attachForTest(temp.path, [region('r1', DownloadStatus.failed)]);
      expect(OfflineMapManager().tileFileFor(MapStyle.sentinel2, z, x, y),
          isNotNull);
    });

    test('a tile not on disk is not claimed, even in a completed region',
        () async {
      // It used to be: the map drew a hole instead of falling back.
      OfflineMapManager().attachForTest(
          temp.path, [region('r1', DownloadStatus.completed, saved: 10)]);
      expect(OfflineMapManager().tileFileFor(MapStyle.sentinel2, z, x, y),
          isNull);
    });

    test('a region still downloading is not read from', () async {
      // Its newest file may be half written.
      await putTile('r1');
      OfflineMapManager()
          .attachForTest(temp.path, [region('r1', DownloadStatus.downloading)]);
      expect(OfflineMapManager().tileFileFor(MapStyle.sentinel2, z, x, y),
          isNull);
    });

    test('a failed region with tiles counts as something to draw underneath',
        () async {
      await putTile('r1');
      OfflineMapManager()
          .attachForTest(temp.path, [region('r1', DownloadStatus.failed)]);
      expect(OfflineMapManager().underlayStyle(imagery: true), MapStyle.sentinel2);
    });

    test('one that saved nothing does not', () async {
      OfflineMapManager().attachForTest(
          temp.path, [region('r1', DownloadStatus.failed, saved: 0)]);
      expect(OfflineMapManager().underlayStyle(imagery: true), isNull);
    });

    test('the underlay hands back the file, or a transparent tile', () async {
      await putTile('r1');
      OfflineMapManager()
          .attachForTest(temp.path, [region('r1', DownloadStatus.failed)]);
      final provider = DownloadedOnlyTileProvider(style: MapStyle.sentinel2);
      final layer = TileLayer(urlTemplate: MapStyle.sentinel2.urlTemplate);

      expect(provider.getImage(const TileCoordinates(x, y, z), layer),
          isA<FileImage>());
      expect(provider.getImage(const TileCoordinates(x + 1, y, z), layer),
          same(DownloadedOnlyTileProvider.transparent));
    });
  });

  test('the stand-in tile really is transparent', () {
    // Anything opaque here would paint over the layer it is meant to sit
    // under, or blank out ground where nothing is downloaded.
    final decoded =
        img.decodePng(DownloadedOnlyTileProvider.transparent.bytes)!;
    expect(decoded.width, 1);
    expect(decoded.height, 1);
    expect(decoded.getPixel(0, 0).a, 0);
  });

  test('both places that credit Sentinel-2 say the same thing', () {
    // CC BY 4.0 wants the credit and the word "modified". The live layer and
    // the offline underlay word it separately; this keeps them from drifting.
    expect(MapStyle.sentinel2.attribution, SatelliteSource.sentinel2.attribution);
    expect(MapStyle.sentinel2.attribution, contains('modified'));
  });
}
