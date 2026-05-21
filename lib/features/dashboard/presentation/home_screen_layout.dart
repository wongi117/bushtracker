import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bush_track/theme/app_colors.dart';
import 'package:bush_track/theme/tactical_theme_constants.dart';
import 'package:bush_track/theme/tactical_widgets.dart';
import '../../tracking/providers/location_provider.dart';
import '../../mesh/providers/mesh_provider.dart';
import '../../ai/providers/ai_assistant_provider.dart';
import '../../mesh/providers/mesh_sync_provider.dart';
import 'package:bush_track/features/map/widgets/compass_rose.dart';
import 'package:bush_track/features/map/widgets/scale_bar.dart';
import 'package:bush_track/features/map/widgets/coordinate_display.dart';
import 'package:bush_track/core/utils/coordinate_utils.dart';
import 'package:bush_track/features/map/widgets/waypoint_marker.dart';
import 'package:bush_track/features/map/widgets/measurement_tool.dart';
import 'package:bush_track/features/map/widgets/trail_creation_overlay.dart';
import 'package:bush_track/features/map/providers/trail_provider.dart';
import 'package:bush_track/features/dashboard/presentation/widgets/mesh_bottom_sheet.dart';
import 'package:bush_track/features/dashboard/presentation/widgets/ai_voice_overlay.dart';
import 'package:bush_track/features/weather/widgets/weather_overlay.dart';
import 'package:bush_track/features/map/widgets/map_loading_indicator.dart';
import 'package:bush_track/core/models/waypoint.dart';
import 'package:bush_track/features/places/presentation/places_search_screen.dart';
import 'package:bush_track/features/search/presentation/natural_language_search_screen.dart';
import 'package:bush_track/features/ar/presentation/ar_compass_screen.dart';
import 'package:bush_track/features/map/widgets/waypoint_editor.dart';
import 'package:bush_track/core/config/secrets.dart';

class HomeScreenLayout extends ConsumerStatefulWidget {
  const HomeScreenLayout({super.key});

  @override
  ConsumerState<HomeScreenLayout> createState() => _HomeScreenLayoutState();
}

class _HomeScreenLayoutState extends ConsumerState<HomeScreenLayout> {
  final MapController _mapController = MapController();
  bool _isSatellite = false;
  double _currentZoom = 13.0;
  final double _currentRotation = 0.0;
  bool _mapInitialized = false;
  bool _tilesLoading = true;
  bool _hasAutocentered = false;
  LatLng? _targetPin;
  CoordinateFormat _coordinateFormat = CoordinateFormat.decimalDegrees;
  bool _showCoordinatePanel = false;
  final GlobalKey<MeasurementToolState> _measurementKey =
      GlobalKey<MeasurementToolState>();
  bool _showMeasurementTool = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _mapInitialized = true;
          _tilesLoading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final locationState = ref.watch(locationProvider);
    final meshState = ref.watch(meshProvider);
    final trailState = ref.watch(trailProvider);
    ref.watch(aiAssistantProvider);

    // Auto-center map on first real GPS fix
    ref.listen<LocationState>(locationProvider, (_, next) {
      if (!_hasAutocentered &&
          next.stats.currentLat != null &&
          next.stats.currentLon != null) {
        _hasAutocentered = true;
        _mapController.move(
          LatLng(next.stats.currentLat!, next.stats.currentLon!),
          15.0,
        );
      }
    });

    try {
      ref.watch(meshSyncProvider);
    } catch (e) {
      debugPrint('Mesh sync error: $e');
    }

    final pinWaypoints = locationState.waypoints
        .where((w) => w.isPin == true || w.type == WaypointType.manual)
        .toList();

    final userLat = locationState.stats.currentLat ?? -25.3444;
    final userLon = locationState.stats.currentLon ?? 131.0369;

    return Scaffold(
      backgroundColor: kDarkBg,
      body: Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onScaleStart: trailState.isCreating ? null : (_) {},
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: LatLng(userLat, userLon),
                initialZoom: _currentZoom,
                minZoom: 2.0,
                maxZoom: 18.0,
                interactionOptions: const InteractionOptions(
                  enableScrollWheel: true,
                  flags: InteractiveFlag.all,
                ),
                onTap: (tapPosition, point) => _onMapTap(point, trailState),
                onLongPress: (tapPosition, point) => _onMapLongPress(point),
                onPositionChanged: (position, hasGesture) {
                  setState(() {
                    _currentZoom = position.zoom ?? 13.0;
                  });
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: _isSatellite
                      ? (AppSecrets.maptilerKey.isNotEmpty
                          ? 'https://api.maptiler.com/maps/satellite/{z}/{x}/{y}.jpg?key=${AppSecrets.maptilerKey}'
                          : 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}')
                      : (AppSecrets.maptilerKey.isNotEmpty
                          ? 'https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key=${AppSecrets.maptilerKey}'
                          : 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png'),
                  subdomains: AppSecrets.maptilerKey.isEmpty
                      ? const ['a', 'b', 'c']
                      : const [],
                  maxZoom: 18.0,
                  minZoom: 2.0,
                  tileSize: 256,
                  retinaMode: true,
                  panBuffer: 2,
                  keepBuffer: 6,
                  tileDisplay: const TileDisplay.fadeIn(),
                ),
                ..._buildTrailLayers(trailState),
                if (trailState.isCreating && trailState.draftPoints.length > 1)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: trailState.draftPoints,
                        color: const Color(0xFFFF5722),
                        strokeWidth: 4.0,
                      ),
                    ],
                  ),
                if (trailState.isCreating && trailState.draftPoints.length > 1)
                  _trailDistLabel(
                      trailState.draftPoints, const Color(0xFFFF5722)),
                if (trailState.isCreating)
                  MarkerLayer(
                    markers: [
                      for (int i = 0; i < trailState.draftPoints.length; i++)
                        Marker(
                          point: trailState.draftPoints[i],
                          width: 50,
                          height: 50,
                          child: _buildNumberedMarker(
                              i + 1, const Color(0xFFFF5722)),
                        ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    if (locationState.stats.currentLat != null &&
                        locationState.stats.currentLon != null)
                      Marker(
                        point: LatLng(locationState.stats.currentLat!,
                            locationState.stats.currentLon!),
                        width: 60,
                        height: 60,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: const BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.blueAccent,
                                      blurRadius: 10,
                                      spreadRadius: 5)
                                ],
                              ),
                            ),
                            const Icon(Icons.navigation,
                                color: Colors.white, size: 20),
                          ],
                        ),
                      ),
                    ...pinWaypoints.map((w) {
                      final wPos =
                          LatLng(w.latitude ?? 0.0, w.longitude ?? 0.0);
                      final hasUser =
                          locationState.stats.currentLat != null &&
                              locationState.stats.currentLon != null;
                      final distLabel = hasUser
                          ? _fmtDist(_distM(
                              LatLng(locationState.stats.currentLat!,
                                  locationState.stats.currentLon!),
                              wPos))
                          : null;
                      return Marker(
                        point: wPos,
                        width: 62,
                        height: 66,
                        alignment: Alignment.bottomCenter,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (distLabel != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1A1A1A)
                                      .withValues(alpha: 0.85),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color:
                                        Colors.white.withValues(alpha: 0.25),
                                    width: 0.5,
                                  ),
                                ),
                                child: Text(
                                  distLabel,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    height: 1.1,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 2),
                            SizedBox(
                              width: 50,
                              height: 50,
                              child: WaypointMarker(
                                waypoint: w,
                                onEdit: () => _editWaypoint(w),
                                onDelete: () => ref
                                    .read(locationProvider.notifier)
                                    .deleteWaypoint(w.id!),
                                onColorChanged: (color) => ref
                                    .read(locationProvider.notifier)
                                    .updateWaypointColor(w.id!, color),
                                onIconChanged: (icon) => ref
                                    .read(locationProvider.notifier)
                                    .updateWaypointIcon(w.id!, icon),
                                onNavigate: () {
                                  ref.read(aiAssistantProvider.notifier).speak(
                                        "Setting navigation target to ${w.label ?? 'waypoint'}.",
                                      );
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
                if (_targetPin != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _targetPin!,
                        width: 70,
                        height: 70,
                        alignment: Alignment.bottomCenter,
                        child: Builder(builder: (context) {
                          final hasUser =
                              locationState.stats.currentLat != null;
                          final distLabel = hasUser
                              ? _fmtDist(_distM(
                                  LatLng(locationState.stats.currentLat!,
                                      locationState.stats.currentLon!),
                                  _targetPin!))
                              : null;
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (distLabel != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent.withValues(
                                        alpha: 0.9),
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.3),
                                          blurRadius: 4),
                                    ],
                                  ),
                                  child: Text(
                                    distLabel,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 2),
                              const Icon(Icons.location_history,
                                  color: Colors.redAccent, size: 50),
                            ],
                          );
                        }),
                      )
                    ],
                  ),
                if (meshState.peerLocations.isNotEmpty)
                  MarkerLayer(
                    markers: meshState.peerLocations.values.map((packet) {
                      return Marker(
                        point: LatLng(packet.latitude!, packet.longitude!),
                        width: 40,
                        height: 40,
                        child: const Icon(Icons.person_pin_circle,
                            color: Colors.blueAccent, size: 40),
                      );
                    }).toList(),
                  ),
                if (_showMeasurementTool &&
                    _measurementKey.currentState != null) ...[
                  PolylineLayer(
                    polylines:
                        _measurementKey.currentState!.getMeasurementPolylines(),
                  ),
                  PolygonLayer(
                    polygons:
                        _measurementKey.currentState!.getMeasurementPolygons(),
                  ),
                  MarkerLayer(
                    markers:
                        _measurementKey.currentState!.getMeasurementMarkers(),
                  ),
                ],
              ],
            ),
          ),
          if (!_mapInitialized || _tilesLoading)
            const Center(child: MapSkeletonLoader()),
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: TacticalGlassContainer(
              borderRadius: 50.0,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  const Icon(Icons.search, color: Colors.white70, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _openSearch(),
                      child: Text("Search location or ask AI...",
                          style:
                              kBodyTextStyle.copyWith(color: Colors.white70)),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _openChat(),
                    child: const Icon(Icons.chat_bubble_outline,
                        color: Colors.white70, size: 30),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 20,
            top: 140,
            child: Column(
              children: [
                _buildTacticalButton(Icons.layers,
                    () => setState(() => _isSatellite = !_isSatellite)),
                const SizedBox(height: 16),
                _buildTacticalButton(
                    Icons.compass_calibration, () => _openCompass()),
              ],
            ),
          ),
          // SOS button — distinct red, always visible, pulses to draw attention
          Positioned(
            right: 16,
            bottom: 290,
            child: Column(
              children: [
                GestureDetector(
                  onTap: _sendSOS,
                  child: Container(
                    width: 66,
                    height: 66,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        colors: [Color(0xFFFF3B30), Color(0xFFB80000)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF3B30).withValues(alpha: 0.55),
                          blurRadius: 18,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.sos_rounded, color: Colors.white, size: 32),
                  ),
                )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(
                      begin: const Offset(1.0, 1.0),
                      end: const Offset(1.08, 1.08),
                      duration: 900.ms,
                      curve: Curves.easeInOut,
                    ),
                const SizedBox(height: 5),
                const Text(
                  'SOS',
                  style: TextStyle(
                    color: Color(0xFFFF3B30),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 220,
            left: 20,
            child: GestureDetector(
              onTap: () =>
                  setState(() => _showCoordinatePanel = !_showCoordinatePanel),
              child: _showCoordinatePanel
                  ? SizedBox(
                      width: 280,
                      child: CoordinateDisplay(
                        position: LatLng(userLat, userLon),
                        format: _coordinateFormat,
                        showAllFormats: true,
                        onFormatChanged: () {
                          setState(() {
                            const formats = CoordinateFormat.values;
                            final currentIndex =
                                formats.indexOf(_coordinateFormat);
                            _coordinateFormat =
                                formats[(currentIndex + 1) % formats.length];
                          });
                        },
                      ),
                    )
                  : CoordinateDisplay(
                      position: LatLng(userLat, userLon),
                      format: _coordinateFormat,
                      onFormatChanged: () {
                        setState(() {
                          const formats = CoordinateFormat.values;
                          final currentIndex =
                              formats.indexOf(_coordinateFormat);
                          _coordinateFormat =
                              formats[(currentIndex + 1) % formats.length];
                        });
                      },
                    ),
            ),
          ),
          Positioned(
            bottom: 260,
            left: 20,
            child: ScaleBar(
              zoom: _currentZoom,
              latitude: userLat,
            ),
          ),
          Positioned(
            top: 60,
            right: 80,
            child: CompassRose(
              rotation: _currentRotation,
              onTap: () {
                _mapController.rotate(0);
              },
            ),
          ),
          if (trailState.isCreating)
            TrailCreationOverlay(
              draftPoints: trailState.draftPoints,
              onCancel: () {
                ref.read(trailProvider.notifier).cancelCreatingTrail();
                ref
                    .read(aiAssistantProvider.notifier)
                    .speak("Trail creation cancelled.");
              },
              onUndo: () =>
                  ref.read(trailProvider.notifier).removeLastDraftPoint(),
              onClear: () =>
                  ref.read(trailProvider.notifier).clearDraftPoints(),
              onSave: (name, color, lineStyle) {
                ref.read(trailProvider.notifier).saveDraftTrail(
                      name: name,
                      color: color,
                      lineStyle: lineStyle,
                    );
                ref.read(aiAssistantProvider.notifier).speak(
                      "Trail '$name' saved with ${trailState.draftPoints.length} points.",
                    );
              },
            ),
          if (_showMeasurementTool)
            MeasurementTool(
              key: _measurementKey,
              mapController: _mapController,
              onMeasurementComplete: () {
                setState(() => _showMeasurementTool = false);
              },
            ),
          const Align(
            alignment: Alignment.bottomCenter,
            child: MeshBottomSheet(),
          ),
          const AiVoiceOverlay(),
          const WeatherOverlay(),
        ],
      ),
    );
  }

  Widget _buildTacticalButton(IconData icon, VoidCallback onPressed,
      {double size = 60.0}) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.panelMatte,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Icon(icon, color: Colors.white, size: size * 0.5),
      ),
    );
  }

  Widget _buildNumberedMarker(int number, Color color) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Icon(Icons.location_on, color: color, size: 44),
        Positioned(
          top: 4,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Center(
              child: Text(
                number.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── distance helpers ───────────────────────────────────────────────────
  String _fmtDist(double m) =>
      m >= 1000 ? '${(m / 1000).toStringAsFixed(2)} km' : '${m.toInt()} m';

  double _distM(LatLng a, LatLng b) => const Distance()(a, b);

  double _trailTotalDist(List<LatLng> pts) {
    if (pts.length < 2) return 0;
    double d = 0;
    for (int i = 0; i < pts.length - 1; i++) {
      d += _distM(pts[i], pts[i + 1]);
    }
    return d;
  }

  /// Distance label marker floating above a trail midpoint.
  MarkerLayer _trailDistLabel(List<LatLng> pts, Color color) {
    final total = _trailTotalDist(pts);
    final mid = pts[pts.length ~/ 2];
    return MarkerLayer(
      markers: [
        Marker(
          point: mid,
          width: 96,
          height: 26,
          alignment: Alignment.bottomCenter, // label floats above the LatLng
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35), blurRadius: 4),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.straighten, color: Colors.white, size: 11),
                const SizedBox(width: 3),
                Text(
                  _fmtDist(total),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildTrailLayers(TrailState trailState) {
    final layers = <Widget>[];

    if (trailState.activeTrail != null) {
      final points = trailState.activeTrail!.getWaypoints();
      final color = WaypointColors.fromHex(trailState.activeTrail!.color);

      layers.add(
        PolylineLayer(
          polylines: [
            Polyline(
              points: points,
              color: color,
              strokeWidth: 5.0,
            ),
          ],
        ),
      );
      if (points.length >= 2) layers.add(_trailDistLabel(points, color));
    }

    for (final trail
        in trailState.trails.where((t) => t.id != trailState.activeTrail?.id)) {
      final points = trail.getWaypoints();
      if (points.isEmpty) continue;

      final color = WaypointColors.fromHex(trail.color);

      layers.add(
        PolylineLayer(
          polylines: [
            Polyline(
              points: points,
              color: color.withValues(alpha: 0.6),
              strokeWidth: 3.0,
            ),
          ],
        ),
      );
      if (points.length >= 2) {
        layers.add(_trailDistLabel(points, color.withValues(alpha: 0.8)));
      }
    }

    return layers;
  }

  void _onMapTap(LatLng point, TrailState trailState) {
    if (_showMeasurementTool && _measurementKey.currentState != null) {
      _measurementKey.currentState!.handleMapTap(point);
      return;
    }

    if (trailState.isCreating) {
      ref.read(trailProvider.notifier).addDraftPoint(point);
      ref.read(aiAssistantProvider.notifier).speak(
            "Point ${trailState.draftPoints.length + 1} added.",
          );
    }
  }

  void _onMapLongPress(LatLng point) {
    setState(() => _targetPin = point);
    ref
        .read(aiAssistantProvider.notifier)
        .speak("Pin dropped at this location.");
  }

  void _editWaypoint(Waypoint waypoint) {
    showWaypointEditor(context, waypoint: waypoint);
  }

  void _openSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PlacesSearchScreen()),
    );
  }

  void _openChat() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NaturalLanguageSearchScreen()),
    );
  }

  void _openCompass() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ARCompassScreen()),
    );
  }

  void _sendSOS() {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Send SOS?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will broadcast an emergency SOS beacon to all nearby mesh nodes.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('SEND SOS', style: TextStyle(color: Color(0xFFFF3B30))),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true) {
        ref.read(meshProvider.notifier).sendSOS();
        ref.read(aiAssistantProvider.notifier).speak(
            'S.O.S. Beacon activated. Broadcasting position to all nearby mesh nodes.');
      }
    });
  }
}
