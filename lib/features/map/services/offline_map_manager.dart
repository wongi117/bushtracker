import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:path_provider/path_provider.dart';
import 'package:bush_track/core/config/api_config.dart';

/// The imagery an offline region can hold.
///
/// Mapbox is deliberately absent and must stay absent: their terms permit
/// offline storage of their tiles only through their own SDK, which is what
/// Option B is about. Esri is absent too, pending an answer on its licence.
/// Sentinel-2 is here because it is the one satellite source whose imagery is
/// unambiguously ours to store -- CC BY 4.0, modified Copernicus data.
enum MapStyle { streets, satellite, topo, outdoor, dark, sentinel2 }

enum DownloadStatus { pending, downloading, paused, completed, failed, cancelled }

extension MapStyleExt on MapStyle {
  String get label {
    switch (this) {
      case MapStyle.streets: return 'Streets';
      case MapStyle.satellite: return 'Satellite';
      case MapStyle.topo: return 'Topographic';
      case MapStyle.outdoor: return 'Outdoor';
      case MapStyle.dark: return 'Dark';
      case MapStyle.sentinel2: return 'Satellite (Sentinel-2)';
    }
  }

  String tileUrl(int z, int x, int y) {
    const k = ApiConfig.maptilerKey;
    switch (this) {
      case MapStyle.streets:   return 'https://api.maptiler.com/maps/streets-v2/$z/$x/$y.png?key=$k';
      case MapStyle.satellite: return 'https://api.maptiler.com/maps/satellite/$z/$x/$y.jpg?key=$k';
      case MapStyle.topo:      return 'https://api.maptiler.com/maps/topo-v2/$z/$x/$y.png?key=$k';
      case MapStyle.outdoor:   return 'https://api.maptiler.com/maps/outdoor-v2/$z/$x/$y.png?key=$k';
      case MapStyle.dark:      return 'https://api.maptiler.com/maps/dataviz-dark/$z/$x/$y.png?key=$k';
      // WMTS: row before column, so $y comes before $x. The opposite of every
      // other line here, and getting it backwards downloads the wrong part of
      // the world into a region that then looks like real ground.
      case MapStyle.sentinel2:
        return 'https://tiles.maps.eox.at/wmts/1.0.0/s2cloudless-2024_3857/'
            'default/g/$z/$y/$x.jpg';
    }
  }

  String get urlTemplate {
    const k = ApiConfig.maptilerKey;
    switch (this) {
      case MapStyle.streets:   return 'https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key=$k';
      case MapStyle.satellite: return 'https://api.maptiler.com/maps/satellite/{z}/{x}/{y}.jpg?key=$k';
      case MapStyle.topo:      return 'https://api.maptiler.com/maps/topo-v2/{z}/{x}/{y}.png?key=$k';
      case MapStyle.outdoor:   return 'https://api.maptiler.com/maps/outdoor-v2/{z}/{x}/{y}.png?key=$k';
      case MapStyle.dark:      return 'https://api.maptiler.com/maps/dataviz-dark/{z}/{x}/{y}.png?key=$k';
      case MapStyle.sentinel2:
        return 'https://tiles.maps.eox.at/wmts/1.0.0/s2cloudless-2024_3857/'
            'default/g/{z}/{y}/{x}.jpg';
    }
  }

  /// The highest zoom with real imagery behind it.
  ///
  /// Downloading past this fills a region with upscaled tiles: more bytes, no
  /// more detail, and for Sentinel-2 the service answers to 16 while its
  /// resolution runs out at 14.
  int get maxUsefulZoom => switch (this) {
        MapStyle.sentinel2 => 14,
        _ => 17,
      };

  /// Whether this imagery may be stored on the device.
  ///
  /// Here so that adding a source to the picker cannot quietly add one we are
  /// not allowed to keep. Mapbox and Esri are not in this enum at all, which
  /// is the stronger guarantee; this flag is for sources whose terms are known
  /// but conditional.
  bool get mayStoreOffline => switch (this) {
        // CC BY 4.0, modified Copernicus data: ours to store and redistribute.
        MapStyle.sentinel2 => true,
        // MapTiler, under whatever the account's plan allows. These have been
        // downloadable since the app's first commit, so the flag reflects
        // today's behaviour rather than changing it -- but the plan's
        // offline/caching terms are still unconfirmed, and if they turn out to
        // forbid it this is the one place to switch them off.
        _ => true,
      };
}

class _Tile {
  final int x, y, z;
  const _Tile(this.x, this.y, this.z);
}

class OfflineMapRegion {
  final String id;
  String name;
  final LatLngBounds bounds;
  final int minZoom;
  final int maxZoom;
  final MapStyle style;
  final int totalTiles;
  int downloadedTiles;
  int failedTiles;
  DownloadStatus status;
  final DateTime createdAt;
  DateTime? completedAt;
  int storedBytes;

  OfflineMapRegion({
    required this.id,
    required this.name,
    required this.bounds,
    required this.minZoom,
    required this.maxZoom,
    required this.style,
    required this.totalTiles,
    this.downloadedTiles = 0,
    this.failedTiles = 0,
    required this.status,
    required this.createdAt,
    this.completedAt,
    this.storedBytes = 0,
  });

  double get progress => totalTiles > 0 ? downloadedTiles / totalTiles : 0;
  int get remainingTiles => totalTiles - downloadedTiles - failedTiles;

  String get formattedSize {
    if (storedBytes < 1024 * 1024) return '${(storedBytes / 1024).toStringAsFixed(1)} KB';
    if (storedBytes < 1024 * 1024 * 1024) return '${(storedBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(storedBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'minLat': bounds.southWest.latitude,
    'minLon': bounds.southWest.longitude,
    'maxLat': bounds.northEast.latitude,
    'maxLon': bounds.northEast.longitude,
    'minZoom': minZoom,
    'maxZoom': maxZoom,
    'style': style.index,
    'totalTiles': totalTiles,
    'downloadedTiles': downloadedTiles,
    'failedTiles': failedTiles,
    'status': status.index,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'completedAt': completedAt?.millisecondsSinceEpoch,
    'storedBytes': storedBytes,
  };

  factory OfflineMapRegion.fromJson(Map<String, dynamic> j) => OfflineMapRegion(
    id: j['id'],
    name: j['name'],
    bounds: LatLngBounds(
      LatLng(j['minLat'], j['minLon']),
      LatLng(j['maxLat'], j['maxLon']),
    ),
    minZoom: j['minZoom'],
    maxZoom: j['maxZoom'],
    style: MapStyle.values[j['style'] ?? 0],
    totalTiles: j['totalTiles'],
    downloadedTiles: j['downloadedTiles'] ?? 0,
    failedTiles: j['failedTiles'] ?? 0,
    status: DownloadStatus.values[j['status'] ?? 0],
    createdAt: DateTime.fromMillisecondsSinceEpoch(j['createdAt']),
    completedAt: j['completedAt'] != null
        ? DateTime.fromMillisecondsSinceEpoch(j['completedAt'])
        : null,
    storedBytes: j['storedBytes'] ?? 0,
  );
}

class DownloadProgress {
  final String regionId;
  final int downloaded;
  final int total;
  final int failed;
  final DownloadStatus status;

  DownloadProgress({
    required this.regionId,
    required this.downloaded,
    required this.total,
    required this.failed,
    required this.status,
  });

  double get fraction => total > 0 ? downloaded / total : 0;
  int get percent => (fraction * 100).round();
}

class SizeEstimate {
  final int tileCount;
  final int estimatedBytes;

  SizeEstimate(this.tileCount, this.estimatedBytes);

  String get formattedSize {
    if (estimatedBytes < 1024 * 1024) return '${(estimatedBytes / 1024).toStringAsFixed(0)} KB';
    if (estimatedBytes < 1024 * 1024 * 1024) return '${(estimatedBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(estimatedBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

class OfflineMapManager {
  static final OfflineMapManager _instance = OfflineMapManager._internal();
  factory OfflineMapManager() => _instance;
  OfflineMapManager._internal();

  String? _tilesDir;
  bool _isInitialized = false;
  final Map<String, OfflineMapRegion> _regions = {};
  final Map<String, bool> _pauseFlags = {};
  final Map<String, bool> _cancelFlags = {};

  final _progressCtrl = StreamController<DownloadProgress>.broadcast();
  Stream<DownloadProgress> get downloadProgress => _progressCtrl.stream;

  bool get isInitialized => _isInitialized;
  List<OfflineMapRegion> get regions => List.unmodifiable(_regions.values.toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt)));

  Future<void> initialize() async {
    if (_isInitialized || kIsWeb) return;
    try {
      final appDir = await getApplicationDocumentsDirectory();
      _tilesDir = '${appDir.path}/offline_tiles';
      await Directory(_tilesDir!).create(recursive: true);
      await _loadRegions();
      _isInitialized = true;
    } catch (e) {
      debugPrint('OfflineMapManager init error: $e');
    }
  }

  // ─── Tile math (correct) ────────────────────────────────────────────────────

  static _Tile _latLonToTile(double lat, double lon, int z) {
    final latRad = lat * math.pi / 180;
    final n = math.pow(2, z).toInt();
    final x = ((lon + 180) / 360 * n).floor().clamp(0, n - 1);
    final y = ((1 - math.log(math.tan(latRad) + 1 / math.cos(latRad)) / math.pi) / 2 * n)
        .floor()
        .clamp(0, n - 1);
    return _Tile(x, y, z);
  }

  /// The deepest zoom worth downloading for this imagery.
  ///
  /// Clamped here, at the one point both the estimate and the download go
  /// through, so a zoom preset cannot ask for more than the source has. The
  /// presets run to 19 and 20; Sentinel-2's resolution stops at 14, and the
  /// tiles past it are the same picture enlarged. Asking for z19 over a region
  /// would fetch roughly a thousand times as many tiles as z14 for no extra
  /// detail -- real storage on the phone and a great deal of somebody else's
  /// bandwidth.
  static int effectiveMaxZoom(MapStyle style, int requested) =>
      requested < style.maxUsefulZoom ? requested : style.maxUsefulZoom;

  static List<_Tile> _tilesForBounds(LatLngBounds b, int minZ, int maxZ) {
    final tiles = <_Tile>[];
    for (int z = minZ; z <= maxZ; z++) {
      final sw = _latLonToTile(b.southWest.latitude, b.southWest.longitude, z);
      final ne = _latLonToTile(b.northEast.latitude, b.northEast.longitude, z);
      for (int x = sw.x; x <= ne.x; x++) {
        for (int y = ne.y; y <= sw.y; y++) {
          tiles.add(_Tile(x, y, z));
        }
      }
    }
    return tiles;
  }

  // ─── Estimation ─────────────────────────────────────────────────────────────

  SizeEstimate estimate(LatLngBounds bounds, int minZoom, int maxZoom, MapStyle style) {
    // Same clamp as the download, so the figure shown is the one that happens.
    final tiles = _tilesForBounds(
        bounds, minZoom, effectiveMaxZoom(style, maxZoom));
    final bytesPerTile = style == MapStyle.satellite ? 65 * 1024 : 35 * 1024;
    return SizeEstimate(tiles.length, tiles.length * bytesPerTile);
  }

  // ─── Download ───────────────────────────────────────────────────────────────

  Future<OfflineMapRegion> startDownload({
    required String name,
    required LatLngBounds bounds,
    required int minZoom,
    required int maxZoom,
    required MapStyle style,
  }) async {
    if (!_isInitialized) await initialize();

    // Clamped before the tiles are enumerated, and the region records the
    // clamped value -- tileFileFor decides coverage from region.maxZoom, so a
    // region claiming a zoom it never downloaded would serve gaps instead of
    // letting the network fill them in.
    final cappedMax = effectiveMaxZoom(style, maxZoom);
    final tiles = _tilesForBounds(bounds, minZoom, cappedMax);
    final id = DateTime.now().millisecondsSinceEpoch.toString();

    final region = OfflineMapRegion(
      id: id,
      name: name,
      bounds: bounds,
      minZoom: minZoom,
      maxZoom: cappedMax,
      style: style,
      totalTiles: tiles.length,
      status: DownloadStatus.downloading,
      createdAt: DateTime.now(),
    );

    _regions[id] = region;
    _pauseFlags[id] = false;
    _cancelFlags[id] = false;
    await _saveRegions();

    _runDownload(region, tiles);
    return region;
  }

  void pauseDownload(String id) {
    _pauseFlags[id] = true;
    _regions[id]?.status = DownloadStatus.paused;
    _emitProgress(_regions[id]!);
  }

  void resumeDownload(String id) {
    _pauseFlags[id] = false;
    if (_regions[id]?.status == DownloadStatus.paused) {
      _regions[id]!.status = DownloadStatus.downloading;
      final tiles = _tilesForBounds(
        _regions[id]!.bounds,
        _regions[id]!.minZoom,
        _regions[id]!.maxZoom,
      );
      _runDownload(_regions[id]!, tiles);
    }
  }

  void cancelDownload(String id) {
    _cancelFlags[id] = true;
    _pauseFlags[id] = false;
    _regions[id]?.status = DownloadStatus.cancelled;
    _emitProgress(_regions[id]!);
  }

  Future<void> deleteRegion(String id) async {
    cancelDownload(id);
    final dir = Directory('$_tilesDir/$id');
    if (await dir.exists()) await dir.delete(recursive: true);
    _regions.remove(id);
    _pauseFlags.remove(id);
    _cancelFlags.remove(id);
    await _saveRegions();
  }

  // ─── Internal download ───────────────────────────────────────────────────────

  Future<void> _runDownload(OfflineMapRegion region, List<_Tile> tiles) async {
    final id = region.id;
    final dir = Directory('$_tilesDir/$id');
    await dir.create(recursive: true);

    // Skip already-downloaded tiles on resume
    final startIdx = region.downloadedTiles.clamp(0, tiles.length);
    final remaining = tiles.sublist(startIdx);

    const workers = 5;
    int sharedCursor = 0;

    Future<void> safeWorker() async {
      while (true) {
        final idx = sharedCursor++;
        if (idx >= remaining.length) break;
        if (_cancelFlags[id] == true) return;
        while (_pauseFlags[id] == true) {
          await Future.delayed(const Duration(milliseconds: 300));
        }
        if (_cancelFlags[id] == true) return;

        final tile = remaining[idx];
        try {
          final url = region.style.tileUrl(tile.z, tile.x, tile.y);
          final resp = await http.get(Uri.parse(url))
              .timeout(const Duration(seconds: 10));
          if (resp.statusCode == 200) {
            final path = '${dir.path}/${tile.z}_${tile.x}_${tile.y}';
            await File(path).writeAsBytes(resp.bodyBytes);
            region.downloadedTiles++;
            region.storedBytes += resp.bodyBytes.length;
          } else {
            region.failedTiles++;
          }
        } catch (_) {
          region.failedTiles++;
        }
        if ((region.downloadedTiles + region.failedTiles) % 10 == 0) {
          _emitProgress(region);
        }
      }
    }

    await Future.wait(List.generate(workers, (_) => safeWorker()));

    if (_cancelFlags[id] != true) {
      region.status = DownloadStatus.completed;
      region.completedAt = DateTime.now();
    }
    _emitProgress(region);
    await _saveRegions();
  }

  void _emitProgress(OfflineMapRegion r) {
    _progressCtrl.add(DownloadProgress(
      regionId: r.id,
      downloaded: r.downloadedTiles,
      total: r.totalTiles,
      failed: r.failedTiles,
      status: r.status,
    ));
  }

  // ─── Offline tile serving ────────────────────────────────────────────────────

  /// The file holding this tile, if a completed region covers it.
  ///
  /// Synchronous on purpose. flutter_map's TileProvider.getImage must return an
  /// ImageProvider immediately, so an async existence check cannot be used --
  /// which is the reason [getOfflineTile] below, written at the same time as
  /// the downloader, was never called from anywhere and offline maps have
  /// never actually worked.
  ///
  /// Coverage is decided from the region's bounds and zoom range, using the
  /// same tile arithmetic the download used to enumerate them, rather than by
  /// touching the filesystem. A completed region with a tile missing therefore
  /// shows a gap rather than falling back to the network; that is the trade for
  /// being able to answer synchronously, and it only applies to regions marked
  /// completed.
  File? tileFileFor(MapStyle style, int z, int x, int y) {
    final dir = _tilesDir;
    if (dir == null) return null;

    for (final region in _regions.values) {
      if (region.status != DownloadStatus.completed) continue;
      if (region.style != style) continue;
      if (z < region.minZoom || z > region.maxZoom) continue;

      final sw = _latLonToTile(
          region.bounds.southWest.latitude, region.bounds.southWest.longitude, z);
      final ne = _latLonToTile(
          region.bounds.northEast.latitude, region.bounds.northEast.longitude, z);
      // y is inverted: north is a smaller row number.
      if (x < sw.x || x > ne.x) continue;
      if (y < ne.y || y > sw.y) continue;

      return File('$dir/${region.id}/${z}_${x}_$y');
    }
    return null;
  }

  /// The downloadable style that serves *exactly* this URL template, if any.
  ///
  /// Matched on the template string rather than by a hand-written mapping of
  /// layer to style, because the two drifted completely apart without anyone
  /// noticing: the downloader fetches MapTiler streets/satellite/topo while the
  /// live map draws OpenStreetMap, OpenTopoMap and Mapbox/Esri satellite. There
  /// was no overlap at all, so even with the read side connected a downloaded
  /// region could never have matched what was on screen.
  ///
  /// An exact string match guarantees the tiles on disk are the same imagery
  /// from the same provider as the layer being drawn. No match means no offline
  /// tiles for that layer, which is the honest answer rather than serving
  /// somebody a different provider's picture of the same ground.
  static MapStyle? styleServing(String urlTemplate) {
    for (final style in MapStyle.values) {
      if (style.urlTemplate == urlTemplate) return style;
    }
    return null;
  }

  /// Whether anything at all has been downloaded for this imagery.
  ///
  /// Used to tell "no signal and nothing downloaded" apart from "no signal but
  /// you have this area", which are different things to say to somebody.
  bool hasAnyRegionFor(MapStyle style) => _regions.values.any(
      (r) => r.status == DownloadStatus.completed && r.style == style);

  Future<List<int>?> getOfflineTile(int z, int x, int y) async {
    for (final region in _regions.values) {
      if (region.status != DownloadStatus.completed) continue;
      final path = '$_tilesDir/${region.id}/${z}_${x}_$y';
      final f = File(path);
      if (await f.exists()) return f.readAsBytes();
    }
    return null;
  }

  bool hasCoverageAt(LatLng point, int zoom) {
    for (final region in _regions.values) {
      if (region.status != DownloadStatus.completed) continue;
      if (zoom < region.minZoom || zoom > region.maxZoom) continue;
      if (region.bounds.contains(point)) return true;
    }
    return false;
  }

  // ─── Persistence ─────────────────────────────────────────────────────────────

  Future<void> _saveRegions() async {
    if (_tilesDir == null) return;
    try {
      final file = File('$_tilesDir/regions.json');
      final json = jsonEncode(_regions.values.map((r) => r.toJson()).toList());
      await file.writeAsString(json);
    } catch (e) {
      debugPrint('Save regions error: $e');
    }
  }

  Future<void> _loadRegions() async {
    try {
      final file = File('$_tilesDir/regions.json');
      if (!await file.exists()) return;
      final list = jsonDecode(await file.readAsString()) as List;
      for (final item in list) {
        final r = OfflineMapRegion.fromJson(item as Map<String, dynamic>);
        // Mark any in-progress downloads as failed (interrupted by app close)
        if (r.status == DownloadStatus.downloading) {
          r.status = DownloadStatus.paused;
        }
        _regions[r.id] = r;
      }
    } catch (e) {
      debugPrint('Load regions error: $e');
    }
  }

  Future<int> totalStorageBytes() async {
    if (_tilesDir == null) return 0;
    int total = 0;
    final dir = Directory(_tilesDir!);
    if (!await dir.exists()) return 0;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) total += (await entity.stat()).size;
    }
    return total;
  }

  // ─── Auto region detection ───────────────────────────────────────────────────

  /// Automatically download a ~50 km region around the user's first GPS fix.
  /// Safe to call multiple times — subsequent calls are no-ops if a region
  /// named "Auto Region" already exists or is downloading.
  Future<void> autoDetectAndDownloadRegion(LatLng position) async {
    if (kIsWeb) return;
    await initialize();

    // Skip if we already have a completed or in-progress auto region
    final alreadyExists = _regions.values.any((r) =>
        r.name == 'Auto Region' &&
        (r.status == DownloadStatus.completed ||
            r.status == DownloadStatus.downloading));
    if (alreadyExists) return;

    // ~0.45° ≈ 50 km at most latitudes
    const half = 0.45;
    final bounds = LatLngBounds(
      LatLng(position.latitude - half, position.longitude - half),
      LatLng(position.latitude + half, position.longitude + half),
    );

    // Zoom 6–13: good overview + navigation detail, manageable tile count
    await startDownload(
      name: 'Auto Region',
      bounds: bounds,
      minZoom: 6,
      maxZoom: 13,
      style: MapStyle.outdoor,
    );
    debugPrint('OfflineMapManager: auto region download started at $position');
  }

}
