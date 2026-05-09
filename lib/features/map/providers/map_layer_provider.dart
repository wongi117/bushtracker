import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';

enum MapLayerType {
  street,
  satellite,
  contours,
  hillshading,
  topo,
}

class MapLayerState {
  final MapLayerType baseLayer;
  final Set<MapLayerType> overlayLayers;
  final double hillshadingOpacity;
  final double contourOpacity;
  
  const MapLayerState({
    this.baseLayer = MapLayerType.street,
    this.overlayLayers = const {},
    this.hillshadingOpacity = 0.4,
    this.contourOpacity = 0.6,
  });
  
  MapLayerState copyWith({
    MapLayerType? baseLayer,
    Set<MapLayerType>? overlayLayers,
    double? hillshadingOpacity,
    double? contourOpacity,
  }) {
    return MapLayerState(
      baseLayer: baseLayer ?? this.baseLayer,
      overlayLayers: overlayLayers ?? this.overlayLayers,
      hillshadingOpacity: hillshadingOpacity ?? this.hillshadingOpacity,
      contourOpacity: contourOpacity ?? this.contourOpacity,
    );
  }
  
  bool hasOverlay(MapLayerType type) => overlayLayers.contains(type);
  
  String getBaseLayerUrl() {
    switch (baseLayer) {
      case MapLayerType.street:
        return 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png';
      case MapLayerType.satellite:
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
      case MapLayerType.topo:
        return 'https://tile.opentopomap.org/{z}/{x}/{y}.png';
      default:
        return 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png';
    }
  }
  
  String getBaseLayerName() {
    switch (baseLayer) {
      case MapLayerType.street:
        return 'Street';
      case MapLayerType.satellite:
        return 'Satellite';
      case MapLayerType.topo:
        return 'Topographic';
      default:
        return 'Street';
    }
  }
}

class MapLayerNotifier extends StateNotifier<MapLayerState> {
  MapLayerNotifier() : super(const MapLayerState());
  
  void setBaseLayer(MapLayerType type) {
    state = state.copyWith(baseLayer: type);
  }
  
  void toggleOverlay(MapLayerType type) {
    final newOverlays = Set<MapLayerType>.from(state.overlayLayers);
    if (newOverlays.contains(type)) {
      newOverlays.remove(type);
    } else {
      newOverlays.add(type);
    }
    state = state.copyWith(overlayLayers: newOverlays);
  }
  
  void setHillshadingOpacity(double opacity) {
    state = state.copyWith(hillshadingOpacity: opacity);
  }
  
  void setContourOpacity(double opacity) {
    state = state.copyWith(contourOpacity: opacity);
  }
  
  List<Widget> getOverlayTiles(MapLayerState state, double zoom) {
    final tiles = <Widget>[];
    
    if (state.hasOverlay(MapLayerType.contours)) {
      tiles.add(
        TileLayer(
          urlTemplate: 'https://api.opentopodata.org/v1/astergdem?locations={lat},{lon}',
          tileBuilder: (context, tileWidget, tile) {
            return tileWidget;
          },
        ),
      );
    }
    
    return tiles;
  }
}

final mapLayerProvider = StateNotifierProvider<MapLayerNotifier, MapLayerState>((ref) {
  return MapLayerNotifier();
});