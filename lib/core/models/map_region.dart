import 'package:isar/isar.dart';

part 'map_region.g.dart';

@Collection()
class MapRegion {
  Id? id;

  String? regionId;
  String? name;
  double? minLat;
  double? maxLat;
  double? minLng;
  double? maxLng;
  int? zoomLevel;
  String? tileDataPath;
  DateTime? downloadedAt;
  DateTime? expiresAt;
  bool? isOffline;
  int? sizeBytes;

  MapRegion({
    this.id,
    this.regionId,
    this.name,
    this.minLat,
    this.maxLat,
    this.minLng,
    this.maxLng,
    this.zoomLevel,
    this.tileDataPath,
    this.downloadedAt,
    this.expiresAt,
    this.isOffline,
    this.sizeBytes,
  });
}
