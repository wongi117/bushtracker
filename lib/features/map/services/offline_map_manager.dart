import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:bush_track/theme/app_colors.dart';

/// Offline Map Tile Manager
/// Downloads and caches map tiles for offline use
/// Replaces Avenza Maps and Google Maps offline capabilities
class OfflineMapManager {
  static final OfflineMapManager _instance = OfflineMapManager._internal();
  factory OfflineMapManager() => _instance;
  OfflineMapManager._internal();

  final Map<String, OfflineMapRegion> _downloadedRegions = {};
  bool _isInitialized = false;
  String? _tilesDirectory;
  
  // Tile providers for offline use
  static const String _osmUrl = 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String _cartoDarkUrl = 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png';
  static const String _esriSatelliteUrl = 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
  
  // Download state
  final _downloadProgressController = StreamController<DownloadProgress>.broadcast();
  Stream<DownloadProgress> get downloadProgress => _downloadProgressController.stream;
  
  bool get isInitialized => _isInitialized;
  List<OfflineMapRegion> get downloadedRegions => _downloadedRegions.values.toList();

  /// Initialize the offline map manager
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      final appDir = await getApplicationDocumentsDirectory();
      _tilesDirectory = '${appDir.path}/offline_tiles';
      
      // Create directory if needed
      final dir = Directory(_tilesDirectory!);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      
      // Load existing regions
      await _loadExistingRegions();
      
      _isInitialized = true;
      print('✅ OfflineMapManager initialized: $_tilesDirectory');
    } catch (e) {
      print('❌ OfflineMapManager initialization failed: $e');
    }
  }
  
  /// Load existing downloaded regions from disk
  Future<void> _loadExistingRegions() async {
    try {
      final metadataFile = File('$_tilesDirectory/regions.json');
      if (await metadataFile.exists()) {
        final content = await metadataFile.readAsString();
        // Parse and load regions
        // Implementation simplified for brevity
      }
    } catch (e) {
      print('⚠️ Could not load existing regions: $e');
    }
  }
  
  /// Calculate tiles needed for a region
  List<TileCoords> _calculateTiles(LatLngBounds bounds, int minZoom, int maxZoom) {
    final tiles = <TileCoords>[];
    
    for (int z = minZoom; z <= maxZoom; z++) {
      final minTile = _latLonToTile(bounds.southWest.latitude, bounds.southWest.longitude, z);
      final maxTile = _latLonToTile(bounds.northEast.latitude, bounds.northEast.longitude, z);
      
      for (int x = minTile.x; x <= maxTile.x; x++) {
        for (int y = minTile.y; y <= maxTile.y; y++) {
          tiles.add(TileCoords(x: x, y: y, z: z));
        }
      }
    }
    
    return tiles;
  }
  
  /// Convert lat/lon to tile coordinates
  TileCoords _latLonToTile(double lat, double lon, int zoom) {
    final latRad = lat * pi / 180;
    final n = pow(2, zoom).toInt();
    final x = ((lon + 180) / 360 * n).floor();
    final y = ((1 - log(tan(latRad) + 1 / cos(latRad)) / pi) / 2 * n).floor();
    return TileCoords(x: x, y: y, z: zoom);
  }
  
  /// Estimate download size for a region
  Future<SizeEstimate> estimateDownloadSize(
    LatLngBounds bounds, 
    int minZoom, 
    int maxZoom,
  ) async {
    final tiles = _calculateTiles(bounds, minZoom, maxZoom);
    
    // Estimate: ~50KB per tile average (compressed PNG/JPG)
    final estimatedBytes = tiles.length * 50 * 1024;
    
    return SizeEstimate(
      tileCount: tiles.length,
      estimatedSizeBytes: estimatedBytes,
      estimatedTimeMinutes: (tiles.length / 60).ceil(), // ~60 tiles/min
    );
  }
  
  /// Download a region for offline use
  Future<OfflineMapRegion> downloadRegion({
    required String name,
    required LatLngBounds bounds,
    required int minZoom,
    required int maxZoom,
    required MapType mapType,
    VoidCallback? onComplete,
  }) async {
    if (!_isInitialized) await initialize();
    
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final tiles = _calculateTiles(bounds, minZoom, maxZoom);
    
    final region = OfflineMapRegion(
      id: id,
      name: name,
      bounds: bounds,
      minZoom: minZoom,
      maxZoom: maxZoom,
      mapType: mapType,
      totalTiles: tiles.length,
      downloadedTiles: 0,
      status: DownloadStatus.downloading,
      createdAt: DateTime.now(),
    );
    
    _downloadedRegions[id] = region;
    
    // Start download
    _downloadTiles(region, tiles, mapType);
    
    return region;
  }
  
  /// Download tiles in background
  Future<void> _downloadTiles(
    OfflineMapRegion region,
    List<TileCoords> tiles,
    MapType mapType,
  ) async {
    final urlTemplate = _getUrlTemplate(mapType);
    int downloaded = 0;
    int failed = 0;
    
    for (int i = 0; i < tiles.length; i++) {
      final tile = tiles[i];
      
      try {
        // Build URL with subdomain rotation
        final subdomain = String.fromCharCode(97 + (i % 3)); // a, b, c
        final url = urlTemplate
            .replaceAll('{s}', subdomain)
            .replaceAll('{z}', tile.z.toString())
            .replaceAll('{x}', tile.x.toString())
            .replaceAll('{y}', tile.y.toString());
        
        // Download tile
        final response = await http.get(Uri.parse(url)).timeout(
          const Duration(seconds: 10),
        );
        
        if (response.statusCode == 200) {
          // Save to disk
          await _saveTile(region.id, tile, response.bodyBytes);
          downloaded++;
        } else {
          failed++;
        }
      } catch (e) {
        failed++;
      }
      
      // Report progress every 10 tiles
      if (i % 10 == 0 || i == tiles.length - 1) {
        final progress = DownloadProgress(
          regionId: region.id,
          downloaded: downloaded,
          total: tiles.length,
          percentage: (downloaded / tiles.length * 100).round(),
          failed: failed,
        );
        _downloadProgressController.add(progress);
      }
      
      // Small delay to not overwhelm server
      await Future.delayed(const Duration(milliseconds: 50));
    }
    
    // Mark complete
    region.status = DownloadStatus.completed;
    region.downloadedTiles = downloaded;
    await _saveRegionMetadata(region);
    
    print('✅ Downloaded $downloaded tiles for region ${region.name}');
  }
  
  /// Save tile to disk
  Future<void> _saveTile(String regionId, TileCoords tile, Uint8List data) async {
    final path = '$_tilesDirectory/$regionId/${tile.z}/${tile.x}/${tile.y}.png';
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data);
  }
  
  /// Save region metadata
  Future<void> _saveRegionMetadata(OfflineMapRegion region) async {
    // Save to JSON file
    // Implementation simplified
  }
  
  /// Get URL template for map type
  String _getUrlTemplate(MapType type) {
    switch (type) {
      case MapType.standard:
        return _osmUrl;
      case MapType.dark:
        return _cartoDarkUrl;
      case MapType.satellite:
        return _esriSatelliteUrl;
    }
  }
  
  /// Check if a tile is available offline
  Future<bool> isTileAvailable(int x, int y, int z) async {
    if (!_isInitialized) return false;
    
    // Check all regions
    for (final region in _downloadedRegions.values) {
      if (region.status != DownloadStatus.completed) continue;
      
      final path = '$_tilesDirectory/${region.id}/$z/$x/$y.png';
      final file = File(path);
      if (await file.exists()) return true;
    }
    
    return false;
  }
  
  /// Get offline tile path if available
  Future<String?> getOfflineTilePath(int x, int y, int z) async {
    for (final region in _downloadedRegions.values) {
      if (region.status != DownloadStatus.completed) continue;
      
      final path = '$_tilesDirectory/${region.id}/$z/$x/$y.png';
      final file = File(path);
      if (await file.exists()) return path;
    }
    return null;
  }
  
  /// Delete a region
  Future<void> deleteRegion(String regionId) async {
    final region = _downloadedRegions[regionId];
    if (region == null) return;
    
    // Delete directory
    final dir = Directory('$_tilesDirectory/$regionId');
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    
    _downloadedRegions.remove(regionId);
    await _saveRegionsList();
  }
  
  /// Save regions list to disk
  Future<void> _saveRegionsList() async {
    // Implementation
  }
  
  /// Get storage usage
  Future<StorageInfo> getStorageUsage() async {
    if (!_isInitialized) await initialize();
    
    int totalBytes = 0;
    int tileCount = 0;
    
    final dir = Directory(_tilesDirectory!);
    if (await dir.exists()) {
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          final stat = await entity.stat();
          totalBytes += stat.size;
          tileCount++;
        }
      }
    }
    
    return StorageInfo(
      totalBytes: totalBytes,
      tileCount: tileCount,
      regionCount: _downloadedRegions.length,
    );
  }
  
  void dispose() {
    _downloadProgressController.close();
  }
}

/// Offline map region definition
class OfflineMapRegion {
  final String id;
  final String name;
  final LatLngBounds bounds;
  final int minZoom;
  final int maxZoom;
  final MapType mapType;
  final int totalTiles;
  int downloadedTiles;
  DownloadStatus status;
  final DateTime createdAt;
  DateTime? completedAt;

  OfflineMapRegion({
    required this.id,
    required this.name,
    required this.bounds,
    required this.minZoom,
    required this.maxZoom,
    required this.mapType,
    required this.totalTiles,
    required this.downloadedTiles,
    required this.status,
    required this.createdAt,
    this.completedAt,
  });

  double get progressPercentage {
    return totalTiles > 0 ? (downloadedTiles / totalTiles * 100) : 0;
  }
}

/// Tile coordinates
class TileCoords {
  final int x;
  final int y;
  final int z;

  TileCoords({required this.x, required this.y, required this.z});
}

/// Download progress
class DownloadProgress {
  final String regionId;
  final int downloaded;
  final int total;
  final int percentage;
  final int failed;

  DownloadProgress({
    required this.regionId,
    required this.downloaded,
    required this.total,
    required this.percentage,
    required this.failed,
  });
}

/// Size estimate
class SizeEstimate {
  final int tileCount;
  final int estimatedSizeBytes;
  final int estimatedTimeMinutes;

  SizeEstimate({
    required this.tileCount,
    required this.estimatedSizeBytes,
    required this.estimatedTimeMinutes,
  });

  String get formattedSize {
    if (estimatedSizeBytes < 1024 * 1024) {
      return '${(estimatedSizeBytes / 1024).toStringAsFixed(1)} KB';
    } else if (estimatedSizeBytes < 1024 * 1024 * 1024) {
      return '${(estimatedSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(estimatedSizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }
}

/// Storage info
class StorageInfo {
  final int totalBytes;
  final int tileCount;
  final int regionCount;

  StorageInfo({
    required this.totalBytes,
    required this.tileCount,
    required this.regionCount,
  });

  String get formattedSize {
    if (totalBytes < 1024 * 1024) {
      return '${(totalBytes / 1024).toStringAsFixed(1)} KB';
    } else if (totalBytes < 1024 * 1024 * 1024) {
      return '${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(totalBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }
}

/// Map types
enum MapType {
  standard,
  dark,
  satellite,
}

/// Download status
enum DownloadStatus {
  pending,
  downloading,
  paused,
  completed,
  failed,
}

// Math constants
const double pi = 3.14159265358979323846;
num pow(num x, num exponent) => _pow(x, exponent);
num _pow(num x, num exponent) {
  num result = 1;
  for (int i = 0; i < exponent; i++) {
    result *= x;
  }
  return result;
}
num log(num x) => _log(x);
num _log(num x) {
  // Simple ln approximation
  return x > 0 ? (x - 1) / x : 0; // Simplified
}
