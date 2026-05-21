import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

enum MapActionType { moveTo, zoomIn, zoomOut, fitWaypoints }

class MapAction {
  final MapActionType type;
  final LatLng? location;
  final double? zoom;

  const MapAction(this.type, {this.location, this.zoom});
}

final pendingMapActionProvider = StateProvider<MapAction?>((ref) => null);
