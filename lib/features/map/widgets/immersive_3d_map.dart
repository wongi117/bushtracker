import 'dart:convert';

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

  /// A style that needs no API key.
  ///
  /// The terrain view asked MapTiler for a style with `?key=` and nothing
  /// after it, because MAPTILER_KEY is a build-time value that is empty in
  /// any build without it — so the whole view came up blank with no
  /// explanation. This draws the same keyless contour tiles the flat map
  /// already uses, tilted, so the feature works on its own.
  static String get _keylessStyle => jsonEncode({
        'version': 8,
        'sources': {
          'topo': {
            'type': 'raster',
            'tiles': [
              'https://a.tile.opentopomap.org/{z}/{x}/{y}.png',
              'https://b.tile.opentopomap.org/{z}/{x}/{y}.png',
              'https://c.tile.opentopomap.org/{z}/{x}/{y}.png',
            ],
            'tileSize': 256,
            'maxzoom': 17,
            'attribution': '© OpenTopoMap (CC-BY-SA), © OpenStreetMap',
          },
        },
        'layers': [
          {'id': 'background', 'type': 'background',
            'paint': {'background-color': '#0A0A0A'}},
          {'id': 'topo', 'type': 'raster', 'source': 'topo'},
        ],
      });

  /// MapTiler's outdoor style when a key is configured, otherwise the
  /// keyless one. A paid style is better; no style at all is not an option.
  String get _style => AppSecrets.maptilerKey.isEmpty
      ? _keylessStyle
      : AppSecrets.maptilerStyleUrl('outdoor-v2');

  void _onMapCreated(MapLibreMapController controller) {
    _controller = controller;
    _controller?.setSymbolIconAllowOverlap(true);
    _controller?.setSymbolTextAllowOverlap(true);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MapLibreMap(
          onMapCreated: _onMapCreated,
          initialCameraPosition: CameraPosition(
            target: widget.initialPosition,
            zoom: widget.initialZoom,
            tilt: 60.0,
            bearing: 0.0,
          ),
          styleString: _style,
          myLocationEnabled: true,
          trackCameraPosition: true,
        ),
        // Say which source is being drawn, and that a key would improve it,
        // rather than leaving a worse-looking map unexplained.
        if (AppSecrets.maptilerKey.isEmpty)
          Positioned(
            left: 12,
            bottom: 12,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Contours · OpenTopoMap',
                style: TextStyle(color: Colors.white70, fontSize: 10),
              ),
            ),
          ),
      ],
    );
  }
}
