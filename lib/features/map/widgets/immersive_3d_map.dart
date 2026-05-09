import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:bush_track/core/config/secrets.dart';

class Immersive3DMap extends StatefulWidget {
  final LatLng initialPosition;
  final double initialZoom;

  const Immersive3DMap({
    super.key,
    required this.initialPosition,
    this.initialZoom = 14.0,
  });

  @override
  State<Immersive3DMap> createState() => _Immersive3DMapState();
}

class _Immersive3DMapState extends State<Immersive3DMap> {
  MapLibreMapController? _controller;

  void _onMapCreated(MapLibreMapController controller) {
    _controller = controller;
    
    // Add 3D terrain once map is created
    _controller?.setSymbolIconAllowOverlap(true);
    _controller?.setSymbolTextAllowOverlap(true);
  }

  @override
  Widget build(BuildContext context) {
    return MapLibreMap(
      onMapCreated: _onMapCreated,
      initialCameraPosition: CameraPosition(
        target: widget.initialPosition,
        zoom: widget.initialZoom,
        tilt: 60.0,
        bearing: 0.0,
      ),
      styleString: AppSecrets.maptilerStyleUrl('outdoor-v2'),
      myLocationEnabled: true,
      trackCameraPosition: true,
      // The style outdoor-v2 already includes terrain by default in many MapTiler styles,
      // but we can ensure it's active.
    );
  }
}
