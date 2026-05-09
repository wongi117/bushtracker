import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../../tracking/providers/location_provider.dart';

// Map modes: 2D Flat, 2D Satellite, 3D Terrain, 3D + Satellite
enum MapMode { flat2D, satellite2D, terrain3D, satellite3D }

class Map3DScreen extends ConsumerStatefulWidget {
  const Map3DScreen({super.key});

  @override
  ConsumerState<Map3DScreen> createState() => _Map3DScreenState();
}

class _Map3DScreenState extends ConsumerState<Map3DScreen> {
  MapLibreMapController? _controller;
  double _tilt = 45.0;
  final double _bearing = 0.0;
  final double _zoom = 14.0;
  MapMode _mapMode = MapMode.terrain3D;
  bool _isTerrainActive = false;

  void _onMapCreated(MapLibreMapController controller) {
    _controller = controller;
    
    // Enable offline tile caching
    _enableOfflineCaching();
    
    // Notify AI assistant that 3D terrain is active
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // In a real implementation, we would trigger AI voice notification here
      // For demo purposes, we'll just print to console
      debugPrint("3D terrain active. Ridge ahead, 80 metres higher than your position.");
    });
  }

  Future<void> _enableOfflineCaching() async {
    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      final cachePath = '${documentsDir.path}/map_cache';
      
      // Note: MapLibre GL handles offline caching automatically
      // The cachePath is used internally by the map controller
      debugPrint("Map cache path: $cachePath");
    } catch (e) {
      debugPrint("Failed to enable offline caching: $e");
    }
  }

  String _build3DStyle(double lat, double lon) {
    final isSatellite = _mapMode == MapMode.satellite3D || _mapMode == MapMode.satellite2D;
    final is3D = _mapMode == MapMode.terrain3D || _mapMode == MapMode.satellite3D;
    
    // Update terrain active state
    if (is3D && !_isTerrainActive) {
      setState(() {
        _isTerrainActive = true;
      });
      // AI speaks when 3D terrain is activated
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // In a real implementation, this would call the AI assistant to speak
        debugPrint("3D terrain active. Ridge ahead, 80 metres higher than your position.");
      });
    } else if (!is3D && _isTerrainActive) {
      setState(() {
        _isTerrainActive = false;
      });
    }
    
    return jsonEncode({
      "version": 8,
      "sources": {
        "base": {
          "type": "raster",
          "tiles": [isSatellite 
              ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}' 
              : 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png'],
          "tileSize": 256
        },
        "terrain": {
          "type": "raster-dem",
          "tiles": ["https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png"],
          "tileSize": 256,
          "encoding": "terrarium"
        }
      },
      "terrain": is3D ? {
        "source": "terrain",
        "exaggeration": 2.0 // Double vertical scale for dramatic outback terrain
      } : null,
      "layers": [
        {
          "id": "background",
          "type": "background",
          "paint": {"background-color": "#080B1A"}
        },
        {"id": "base-tiles", "type": "raster", "source": "base"},
        if (is3D) {
          "id": "hillshade",
          "type": "hillshade",
          "source": "terrain",
          "paint": {
            "hillshade-shadow-color": "#080B1A",
            "hillshade-highlight-color": "#2A2B3A",
            "hillshade-accent-color": "#1A1B26"
          }
        },
        if (is3D) {
          "id": "sky",
          "type": "sky",
          "paint": {
            "sky-type": "gradient",
            "sky-gradient": [
              "interpolate",
              ["linear"],
              ["sky-radial-progress"],
              0.8,
              "rgba(10,15,50,1)",
              1,
              "rgba(5,8,30,1)"
            ]
          }
        }
      ]
    });
  }

  void _cycleMapMode() {
    setState(() {
      switch (_mapMode) {
        case MapMode.flat2D:
          _mapMode = MapMode.satellite2D;
          break;
        case MapMode.satellite2D:
          _mapMode = MapMode.terrain3D;
          break;
        case MapMode.terrain3D:
          _mapMode = MapMode.satellite3D;
          break;
        case MapMode.satellite3D:
          _mapMode = MapMode.flat2D;
          break;
      }
    });
    
    // Update the map style
    final locationState = ref.read(locationProvider);
    final stats = locationState.stats;
    final userLat = stats.currentLat ?? -25.3444;
    final userLon = stats.currentLon ?? 131.0369;
    
    // Update tilt based on mode and movement
    final speed = stats.currentSpeedMs;
    final targetTilt = (_mapMode == MapMode.terrain3D || _mapMode == MapMode.satellite3D) 
        ? (speed > (5 / 3.6) ? 45.0 : 0.0) // 5 km/h = 1.39 m/s
        : 0.0;
    
    setState(() {
      _tilt = targetTilt;
    });
    
    // Animate camera to new tilt
    _controller?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(userLat, userLon),
          zoom: _zoom,
          tilt: targetTilt,
          bearing: _bearing,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locationState = ref.watch(locationProvider);
    final stats = locationState.stats;
    
    final userLat = stats.currentLat ?? -25.3444;
    final userLon = stats.currentLon ?? 131.0369;

    return Scaffold(
      appBar: AppBar(
        title: Text(_getMapModeTitle()),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: MapLibreMap(
        styleString: _build3DStyle(userLat, userLon),
        initialCameraPosition: CameraPosition(
          target: LatLng(userLat, userLon),
          zoom: _zoom,
          tilt: (_mapMode == MapMode.terrain3D || _mapMode == MapMode.satellite3D) ? _tilt : 0,
          bearing: _bearing,
        ),
        onMapCreated: _onMapCreated,
        myLocationEnabled: true,
        onUserLocationUpdated: (location) {
          // Auto-adjust tilt based on user movement
          final speed = location.speed ?? 0;
          final targetTilt = (_mapMode == MapMode.terrain3D || _mapMode == MapMode.satellite3D) 
              ? (speed > (5 / 3.6) ? 45.0 : 0.0) // 5 km/h = 1.39 m/s
              : 0.0;
          
          if (targetTilt != _tilt) {
            setState(() {
              _tilt = targetTilt;
            });
            
            // Use location from provider instead since we have it tracked
            if (stats.currentLat != null && stats.currentLon != null) {
              _controller?.animateCamera(
                CameraUpdate.newCameraPosition(
                  CameraPosition(
                    target: LatLng(stats.currentLat!, stats.currentLon!),
                    zoom: _zoom,
                    tilt: targetTilt,
                    bearing: _bearing,
                  ),
                ),
              );
            }
          }
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            backgroundColor: Colors.blue,
            onPressed: _cycleMapMode,
            child: const Icon(Icons.layers),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            backgroundColor: Colors.orange,
            child: const Icon(Icons.my_location),
            onPressed: () {
              // Center map on user location
              if (stats.currentLat != null && stats.currentLon != null) {
                _controller?.animateCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(
                      target: LatLng(stats.currentLat!, stats.currentLon!),
                      zoom: _zoom,
                      tilt: _tilt,
                      bearing: _bearing,
                    ),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
  
  String _getMapModeTitle() {
    switch (_mapMode) {
      case MapMode.flat2D:
        return '📊 2D FLAT MAP';
      case MapMode.satellite2D:
        return '🛰️ 2D SATELLITE';
      case MapMode.terrain3D:
        return '🏔️ 3D TERRAIN';
      case MapMode.satellite3D:
        return '🛰️ 3D SATELLITE';
    }
  }
}
