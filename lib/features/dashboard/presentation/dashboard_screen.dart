import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'package:sensors_plus/sensors_plus.dart';
import 'package:bush_track/core/utils/web_helpers.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:mesh_gradient/mesh_gradient.dart';
import 'package:bush_track/core/widgets/glass_panel.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bush_track/features/map/widgets/immersive_3d_map.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as mgl;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bush_track/theme/app_colors.dart';
import 'widgets/mesh_bottom_sheet.dart';
import '../../tracking/providers/location_provider.dart';
import '../../mesh/providers/mesh_provider.dart';
import '../../ai/providers/ai_assistant_provider.dart';
import 'package:bush_track/features/ai/services/ai_monitor_service.dart';
import 'package:bush_track/features/geofence/providers/geofence_provider.dart';
import 'package:bush_track/features/gallery/presentation/photo_gallery_screen.dart';
import 'widgets/ai_voice_overlay.dart';
import '../../mesh/providers/mesh_sync_provider.dart';
import 'package:bush_track/features/weather/widgets/weather_overlay.dart';
import 'package:bush_track/features/places/presentation/places_search_screen.dart';
import 'package:bush_track/features/navigation/presentation/route_options_screen.dart';
import 'package:bush_track/features/navigation/providers/navigation_provider.dart';
import 'package:bush_track/features/map/providers/map_action_provider.dart';
import 'package:bush_track/features/ar/presentation/ar_compass_screen.dart';
import 'package:bush_track/features/ar/presentation/ar_camera_screen.dart';
import 'package:bush_track/features/settings/presentation/settings_screen.dart';
import 'package:bush_track/features/map/widgets/measurement_tool.dart';
import 'package:bush_track/features/search/presentation/natural_language_search_screen.dart';
import 'package:bush_track/features/trip/presentation/trip_statistics_screen.dart';
import 'package:bush_track/features/places/presentation/coordinate_input_screen.dart';
import 'package:bush_track/core/services/connectivity_service.dart';
import 'package:bush_track/features/map/widgets/coordinate_display.dart';
import 'package:bush_track/core/utils/coordinate_utils.dart';
import 'package:bush_track/features/map/services/photo_geotagging_service.dart';
import 'package:bush_track/features/map/services/offline_map_manager.dart';
import 'package:bush_track/features/map/widgets/compass_rose.dart';
import 'package:bush_track/features/map/widgets/scale_bar.dart';
import 'package:bush_track/features/map/widgets/map_loading_indicator.dart';
import 'package:bush_track/features/map/widgets/waypoint_marker.dart';
import 'package:bush_track/features/map/widgets/waypoint_editor.dart';
import 'package:bush_track/features/map/widgets/trail_creation_overlay.dart';
import 'package:bush_track/features/map/providers/trail_provider.dart';
import 'package:bush_track/core/models/breadcrumb.dart';
import 'package:bush_track/core/models/waypoint.dart';
import 'package:bush_track/core/models/trail.dart';
import 'package:bush_track/features/ai/presentation/agent_manager_screen.dart';
import 'package:bush_track/features/map/presentation/offline_maps_screen.dart';
import 'package:bush_track/features/map/widgets/pinage_chooser.dart';
import 'package:bush_track/features/map/widgets/pinage_editor.dart';
import 'package:bush_track/features/map/widgets/pinage_viewer.dart';

class _DwellCell {
  final LatLng center;
  int totalMs = 0;
  _DwellCell(this.center);
  void add(int ms) => totalMs += ms;
}

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  final GlobalKey _screenshotKey = GlobalKey();

  // Map style: 0=Street, 1=Satellite, 2=Dark, 3=Topo
  int _mapStyleIndex = 0;
  static const _tileUrls = [
    // 0 — Satellite: ESRI World Imagery — free, best remote-AU coverage, same source as Avenza/Gaia
    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    // 1 — Topo: OpenTopoMap — elevation contours, great for bush navigation
    'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png',
    // 2 — Street: OpenStreetMap — standard, no API key needed
    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  ];
  // maxNativeZoom: ESRI?19, OpenTopoMap?17, OSM?19
  static const _tileMaxNativeZoom = [19, 17, 19];
  static const _tileNames = ['Satellite', 'Topo', 'Street'];
  static const _tileIcons = [
    Icons.satellite_alt,
    Icons.terrain,
    Icons.map,
  ];

  LatLng? _targetPin;

  // Map state
  bool _mapInitialized = false;
  bool _tilesLoading = true;
  bool _hasAutocentered = false;
  double _currentZoom = 13.0;
  double _currentRotation = 0.0;
  StreamSubscription<MagnetometerEvent>? _magnetometerSub;

  // NEW: Measurement tool
  final GlobalKey<MeasurementToolState> _measurementKey =
      GlobalKey<MeasurementToolState>();
  bool _showMeasurementTool = false;

  // NEW: Coordinate display
  CoordinateFormat _coordinateFormat = CoordinateFormat.decimalDegrees;
  bool _showCoordinatePanel = false;

  // NEW: Services
  final PhotoGeotaggingService _photoService = PhotoGeotaggingService();
  final OfflineMapManager _offlineMapManager = OfflineMapManager();

  // NEW: Trail creation mode
  final bool _isCreatingTrail = false;
  bool _is3DMode = false;

  // Offline map banner
  bool _showOfflineBanner = false;

  // Breadcrumb trail
  bool _showBreadcrumbs = false;
  bool _isRetracing = false;
  bool _showDwellMap = false;

  // Hamburger drawer
  bool _drawerOpen = false;

  late AnimatedMeshGradientController _meshController;

  @override
  void initState() {
    super.initState();
    _meshController = AnimatedMeshGradientController();
    _initializeServices();
    _setupMapListeners();
    if (!kIsWeb) {
      _magnetometerSub = magnetometerEvents.listen((event) {
        final heading = math.atan2(event.y, event.x);
        if (mounted) setState(() => _currentRotation = heading);
      });
    }
  }

  Future<void> _initializeServices() async {
    await _photoService.initialize();
    await _offlineMapManager.initialize();
  }

  void _setupMapListeners() {
    // Mark map as initialized immediately — tile loading state is managed by TileLayer itself
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _mapInitialized = true;
          _tilesLoading = false;
        });
      }
    });
  }

  void _executeMapAction(MapAction action) {
    switch (action.type) {
      case MapActionType.moveTo:
        if (action.location != null) {
          _mapController.move(action.location!, action.zoom ?? 14.0);
        }
      case MapActionType.zoomIn:
        final z = (_mapController.camera.zoom + 1).clamp(3.0, 19.0);
        _mapController.move(_mapController.camera.center, z);
      case MapActionType.zoomOut:
        final z = (_mapController.camera.zoom - 1).clamp(3.0, 19.0);
        _mapController.move(_mapController.camera.center, z);
      case MapActionType.fitWaypoints:
        final ws = ref.read(locationProvider).waypoints;
        if (ws.isNotEmpty) _zoomToFitWaypoints(ws);
    }
  }

  Widget _buildNavHUD(NavigationState navState) {
    final step = navState.currentStep!;
    final distText = step.distanceM >= 1000
        ? '${(step.distanceM / 1000).toStringAsFixed(1)} km'
        : '${step.distanceM.toInt()} m';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.statusBlue.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            const Icon(Icons.navigation, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                step.instruction,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
                maxLines: 2,
              ),
            ),
            GestureDetector(
              onTap: () => ref.read(navigationProvider.notifier).stopNavigation(),
              child: const Icon(Icons.close, color: Colors.white70, size: 18),
            ),
          ]),
          if (step.distanceM > 0) ...[
            const SizedBox(height: 3),
            Text(
              '$distText  ·  ${navState.selectedRoute?.name ?? ''}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
          if (navState.steps.length > 1) ...[
            const SizedBox(height: 6),
            Row(children: [
              GestureDetector(
                onTap: () => ref.read(navigationProvider.notifier).previousStep(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(8)),
                  child: const Text('PREV',
                      style: TextStyle(color: Colors.white, fontSize: 11)),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Step ${navState.currentStepIndex + 1}/${navState.steps.length}',
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => ref.read(navigationProvider.notifier).nextStep(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(8)),
                  child: const Text('NEXT',
                      style: TextStyle(color: Colors.white, fontSize: 11)),
                ),
              ),
            ]),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('?? DASHBOARD BUILD STARTING');
    final locationState = ref.watch(locationProvider);
    final meshState = ref.watch(meshProvider);
    final trailState = ref.watch(trailProvider);
    ref.watch(aiAssistantProvider);
    final navState = ref.watch(navigationProvider);
    // Initialize monitoring services so their timers start.
    ref.watch(aiMonitorServiceProvider);
    ref.watch(geofenceProvider);

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

    // Execute pending AI map actions
    ref.listen<MapAction?>(pendingMapActionProvider, (_, action) {
      if (action == null) return;
      _executeMapAction(action);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(pendingMapActionProvider.notifier).state = null;
      });
    });

    // Initialize mesh sync bridge
    try {
      ref.watch(meshSyncProvider);
    } catch (e) {
      debugPrint('?? Mesh sync error: $e');
    }
    debugPrint(
        '?? DASHBOARD PROVIDERS LOADED - waypoints: ${locationState.waypoints.length}');

    // Get pin waypoints (not track points)
    final pinWaypoints = locationState.waypoints
        .where((w) => w.isPin == true || w.type == WaypointType.manual)
        .toList();

    final baseTileUrl = _tileUrls[_mapStyleIndex];

    return Scaffold(
      body: Stack(
        children: [
          // Premium Mesh Gradient Background
          Positioned.fill(
            child: AnimatedMeshGradient(
              colors: [
                AppColors.primaryOrange.withValues(alpha: 0.3),
                AppColors.panelMatte.withValues(alpha: 0.8),
                AppColors.primaryOrange.withValues(alpha: 0.1),
                Colors.black,
              ],
              options: AnimatedMeshGradientOptions(
                speed: 1.5,
                amplitude: 30,
              ),
              controller: _meshController,
            ),
          ),
          // Map with gesture handling — wrapped for screenshot capture
          RepaintBoundary(
            key: _screenshotKey,
            child: _is3DMode
                ? Immersive3DMap(
                    initialPosition: mgl.LatLng(
                        locationState.stats.currentLat ??
                            _mapController.camera.center.latitude,
                        locationState.stats.currentLon ??
                            _mapController.camera.center.longitude),
                  )
                : GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onScaleStart: _isCreatingTrail ? null : (_) {},
                    child: FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: locationState.stats.currentLat != null
                            ? LatLng(locationState.stats.currentLat!,
                                locationState.stats.currentLon!)
                            : const LatLng(-25.3444, 131.0369), // Uluru
                        initialZoom: _currentZoom,
                        minZoom: 3.0,
                        maxZoom: 19.0,
                        interactionOptions: const InteractionOptions(
                          enableScrollWheel: true,
                          flags: InteractiveFlag.all,
                        ),
                        onTap: (tapPosition, point) =>
                            _onMapTap(point, trailState),
                        onLongPress: (tapPosition, point) =>
                            _onMapLongPress(point),
                        onPositionChanged: (position, hasGesture) {
                          setState(() {
                            _currentZoom = position.zoom ?? 13.0;
                          });
                        },
                      ),
                      children: [
                        // Tile layer with OpenStreetMap
                        TileLayer(
                          urlTemplate: baseTileUrl,
                          // OpenTopoMap uses {s} subdomain rotation
                          subdomains: _mapStyleIndex == 1 ? const ['a', 'b', 'c'] : const [],
                          maxZoom: 19.0,
                          maxNativeZoom: _tileMaxNativeZoom[_mapStyleIndex],
                          minZoom: 3.0,
                          tileSize: 256,
                          retinaMode: RetinaMode.isHighDensity(context),
                          panBuffer: 3,
                          keepBuffer: 8,
                          errorTileCallback: (tile, error, stackTrace) {
                            debugPrint('Tile error: $error');
                            setState(() => _showOfflineBanner = true);
                          },
                          tileDisplay: TileDisplay.fadeIn(
                            duration: const Duration(milliseconds: 80),
                          ),
                        ),
                        // Trail lines layer
                        ..._buildTrailLayers(trailState, locationState, navState),
                        // Trail draft line
                        if (trailState.isCreating &&
                            trailState.draftPoints.length > 1)
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: trailState.draftPoints,
                                color: const Color(0xFFFF5722),
                                strokeWidth: 4.0,
                                borderStrokeWidth: 1.0,
                                borderColor: Colors.black,
                                isDotted: false,
                              ),
                            ],
                          ),
                        // Draft points with numbers
                        if (trailState.isCreating)
                          MarkerLayer(
                            markers: [
                              for (int i = 0;
                                  i < trailState.draftPoints.length;
                                  i++)
                                Marker(
                                  point: trailState.draftPoints[i],
                                  width: 50,
                                  height: 50,
                                  child: _buildNumberedMarker(
                                      i + 1, const Color(0xFFFF5722)),
                                ),
                            ],
                          ),
                        // Waypoint markers with interaction
                        MarkerLayer(
                          markers: [
                            // User Current Position Marker
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
                                      decoration: BoxDecoration(
                                        color: AppColors.statusBlue,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                              color: AppColors.statusBlue.withValues(alpha: 0.6),
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
                            // Pin Waypoints with interaction
                            ...pinWaypoints.map((w) {
                              return Marker(
                                point: LatLng(
                                    w.latitude ?? 0.0, w.longitude ?? 0.0),
                                width: 50,
                                height: 50,
                                child: WaypointMarker(
                                  waypoint: w,
                                  onEdit: () => w.isPinage ? _showPinageViewer(w) : _editWaypoint(w),
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
                                        "Setting navigation target to ${w.label ?? 'waypoint'}.");
                                  },
                                ),
                              );
                            }),
                          ],
                        ),
                        if (locationState.stats.currentLat != null &&
                            locationState.stats.currentLon != null &&
                            locationState.stats.currentAccuracyM >= 10)
                          CircleLayer(
                            circles: [
                              CircleMarker(
                                point: LatLng(locationState.stats.currentLat!,
                                    locationState.stats.currentLon!),
                                radius: locationState.stats.currentAccuracyM,
                                useRadiusInMeter: true,
                                color: const Color(0xFF7B2FFF)
                                    .withValues(alpha: 0.15),
                                borderColor: const Color(0xFF7B2FFF)
                                    .withValues(alpha: 0.4),
                                borderStrokeWidth: 1,
                              ),
                            ],
                          ),
                        // Target Pin
                        if (_targetPin != null)
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: _targetPin!,
                                width: 50,
                                height: 50,
                                child: const Icon(Icons.location_history,
                                    color: AppColors.statusRed, size: 50),
                              )
                            ],
                          ),
                        // Mesh Peers
                        if (meshState.peerLocations.isNotEmpty)
                          MarkerLayer(
                            markers:
                                meshState.peerLocations.values.map((packet) {
                              return Marker(
                                point:
                                    LatLng(packet.latitude!, packet.longitude!),
                                width: 40,
                                height: 40,
                                child: const Icon(Icons.person_pin_circle,
                                    color: AppColors.statusBlue, size: 40),
                              );
                            }).toList(),
                          ),
                        if (meshState.isAdvertising || meshState.isDiscovering)
                          _buildMeshOverlay(),
                        // Measurement Tool Layers
                        if (_showMeasurementTool &&
                            _measurementKey.currentState != null) ...[
                          PolylineLayer(
                            polylines: _measurementKey.currentState!
                                .getMeasurementPolylines(),
                          ),
                          PolygonLayer(
                            polygons: _measurementKey.currentState!
                                .getMeasurementPolygons(),
                          ),
                          MarkerLayer(
                            markers: _measurementKey.currentState!
                                .getMeasurementMarkers(),
                          ),
                        ],
                      ],
                    ),
                  ),
          ), // RepaintBoundary

          // Loading indicators
          if (!_mapInitialized || _tilesLoading)
            const Center(child: MapSkeletonLoader()),

          // Map loading indicator
          if (_tilesLoading && _mapInitialized)
            Positioned(
              top: 80,
              left: 0,
              right: 0,
              child: Center(
                child: MapLoadingIndicator(
                  isLoading: _tilesLoading,
                  message: 'Loading map tiles...',
                ),
              ),
            ),

          // Offline banner
          if (_showOfflineBanner)
            Positioned(
              top: 50,
              left: 20,
              right: 20,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.wifi_off, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Some map tiles need internet. Core survival features work fully offline.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _showOfflineBanner = false),
                      child: const Icon(Icons.close,
                          color: Colors.white, size: 20),
                    ),
                  ],
                ),
              ),
            ),

          // Floating top buttons — no background bar, sit directly over the map
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 14,
            right: 14,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 480;

                // Hamburger button
                final hamburger = GestureDetector(
                  onTap: () => setState(() => _drawerOpen = true),
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFAA00), Color(0xFFFF6A00)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF8C00).withValues(alpha: 0.65),
                          blurRadius: 18,
                          spreadRadius: 1,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _hamburgerLine(),
                        const SizedBox(height: 5),
                        _hamburgerLine(),
                        const SizedBox(height: 5),
                        _hamburgerLine(),
                      ],
                    ),
                  ),
                );

                // Camera button — opens AR camera (live feed + pin save)
                final camera = GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ARCameraScreen()),
                  ),
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF9B4FFF), Color(0xFF5B1FDF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF7B2FFF).withValues(alpha: 0.6),
                          blurRadius: 18,
                          spreadRadius: 1,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.camera_alt_rounded,
                        color: Colors.white, size: 26),
                  ),
                );

                // Search button
                final search = GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PlacesSearchScreen()),
                  ),
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.18),
                          Colors.white.withValues(alpha: 0.08),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(Icons.search_rounded,
                        color: Colors.white.withValues(alpha: 0.9), size: 26),
                  ),
                );

                if (compact) {
                  return Row(children: [
                    hamburger,
                    const Spacer(),
                    camera,
                    const Spacer(),
                    search,
                  ]);
                }

                // Wide (tablet / desktop): full pill bar with branding
                return Row(children: [
                  hamburger,
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      ShaderMask(
                        shaderCallback: (b) =>
                            AppColors.accentGradient.createShader(b),
                        child: const Icon(Icons.explore, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'BUSHTRACK',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7B2FFF).withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                              color: const Color(0xFF7B2FFF).withValues(alpha: 0.45)),
                        ),
                        child: const Text('v3.0',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                      ),
                    ]),
                  ),
                  const SizedBox(width: 10),
                  camera,
                  const SizedBox(width: 8),
                  search,
                  const Spacer(),
                  _buildAIStatusIndicator(),
                  const SizedBox(width: 8),
                  _buildConnectivityIndicator(),
                ]);
              },
            ),
          ),

          // Compass Rose — below the top bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 76,
            right: 80,
            child: CompassRose(
              rotation: _currentRotation,
              onTap: () {
                _mapController.rotate(0);
              },
            ),
          ),

          // Scale Bar (Bottom Left, above coordinate display)
          Positioned(
            bottom: 260,
            left: 20,
            child: ScaleBar(
              zoom: _currentZoom,
              latitude: locationState.stats.currentLat ?? -25.3444,
            ),
          ),

          // Hamburger drawer overlay
          if (_drawerOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _drawerOpen = false),
                child: Container(color: Colors.black.withValues(alpha: 0.45)),
              ),
            ),
          if (_drawerOpen)
            Positioned(
              top: 0,
              left: 0,
              bottom: 0,
              width: 300,
              child: _HamburgerDrawer(
                onClose: () => setState(() => _drawerOpen = false),
                is3DMode: _is3DMode,
                mapStyleIndex: _mapStyleIndex,
                showBreadcrumbs: _showBreadcrumbs,
                showDwellMap: _showDwellMap,
                showMeasurementTool: _showMeasurementTool,
                isCreatingTrail: trailState.isCreating,
                hasGps: locationState.stats.currentLat != null,
                hasWaypoints: locationState.waypoints.isNotEmpty,
                onToggle3D: () => setState(() => _is3DMode = !_is3DMode),
                onMapStyle: () {
                  final next = (_mapStyleIndex + 1) % _tileUrls.length;
                  setState(() => _mapStyleIndex = next);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Map style: ${_tileNames[next]}'),
                    duration: const Duration(seconds: 1),
                    backgroundColor: AppColors.primaryOrange,
                  ));
                },
                onToggleBreadcrumbs: () => setState(() => _showBreadcrumbs = !_showBreadcrumbs),
                onRecenter: () {
                  if (locationState.stats.currentLat != null) {
                    _mapController.move(
                      LatLng(locationState.stats.currentLat!, locationState.stats.currentLon!),
                      16.0,
                    );
                  }
                },
                onZoomIn: () {
                  _mapController.move(_mapController.camera.center,
                      (_mapController.camera.zoom + 1).clamp(3.0, 19.0));
                },
                onZoomOut: () {
                  _mapController.move(_mapController.camera.center,
                      (_mapController.camera.zoom - 1).clamp(3.0, 19.0));
                },
                onScanBounds: () {
                  if (locationState.waypoints.isNotEmpty) {
                    _zoomToFitWaypoints(locationState.waypoints);
                  }
                },
                onElevationProfile: () => setState(() {
                  _showDwellMap = !_showDwellMap;
                }),
                onAddWaypoint: () {
                  showWaypointEditor(context, position: _mapController.camera.center);
                },
                onTrackRecord: () {
                  ref.read(trailProvider.notifier).startCreatingTrail();
                  ref.read(aiAssistantProvider.notifier).speak(
                      "Trail creation mode activated. Tap on the map to drop points.");
                },
                onExportTrack: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const TripStatisticsScreen())),
                onLayerManager: () => setState(() {
                  final next = (_mapStyleIndex + 1) % _tileUrls.length;
                  _mapStyleIndex = next;
                }),
                onMeasure: () {
                  setState(() => _showMeasurementTool = !_showMeasurementTool);
                  if (_showMeasurementTool) {
                    ref.read(aiAssistantProvider.notifier).speak(
                        "Measurement tool activated. Tap the map to measure distance.");
                  }
                },
                onScreenshot: _takeScreenshot,
                onDeviceInfo: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => CoordinateInputScreen(
                      onCoordinateEntered: (c) => _mapController.move(c, 14.0),
                    ))),
                onNavigation: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const RouteOptionsScreen())),
                onAIAssistant: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => NaturalLanguageSearchScreen(
                      onLocationFound: (c) => _mapController.move(c, 14.0),
                    ))),
                onSearchPlace: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const PlacesSearchScreen())),
                onCompassNav: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ARCompassScreen())),
                onMeshSignal: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const OfflineMapsScreen())),
                onSettings: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen())),
                onAnalytics: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AgentManagerScreen())),
                onGallery: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => PhotoGalleryScreen(
                      onJumpToMap: (loc) => _mapController.move(loc, 16.0),
                    ))),
                onSOS: _showSOSConfirmation,
              ),
            ),

          // Trail creation overlay — minimal floating bar
          if (trailState.isCreating)
            TrailCreationOverlay(
              draftPoints: trailState.draftPoints,
              onCancel: () {
                ref.read(trailProvider.notifier).cancelCreatingTrail();
                ref.read(aiAssistantProvider.notifier).speak("Trail creation cancelled.");
              },
              onUndo: () => ref.read(trailProvider.notifier).removeLastDraftPoint(),
              onClear: () => ref.read(trailProvider.notifier).clearDraftPoints(),
              onSave: (name, color, lineStyle) {
                ref.read(trailProvider.notifier).saveDraftTrail(
                  name: name,
                  color: color,
                  lineStyle: lineStyle,
                );
                ref.read(aiAssistantProvider.notifier).speak(
                    "Trail '$name' saved. Long-press the trail to edit details.");
              },
            ),

          // Navigation HUD — turn-by-turn instructions
          if (navState.isActive && navState.currentStep != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 56,
              left: 16,
              right: 80,
              child: _buildNavHUD(navState),
            ),

          // Trail following overlay
          if (trailState.isFollowing && trailState.activeTrail != null)
            TrailFollowingOverlay(
              message: trailState.navigationMessage,
              distanceToNext: trailState.distanceToNextPoint,
              bearing: trailState.bearingToNextPoint,
              currentPointIndex: trailState.currentPointIndex ?? 0,
              totalPoints: trailState.activeTrail!.getWaypoints().length,
              onStop: () {
                ref.read(trailProvider.notifier).stopFollowingTrail();
                ref
                    .read(aiAssistantProvider.notifier)
                    .speak("Trail following stopped.");
              },
            ),

          // Breadcrumb controls overlay — visible when trail is shown
          if (_showBreadcrumbs)
            Positioned(
              bottom: 160,
              left: 0,
              right: 0,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Retrace button
                    GestureDetector(
                      onTap: () {
                        final crumbs = ref.read(locationProvider).breadcrumbs
                            .where((b) => b.latitude != null && b.longitude != null)
                            .toList();
                        setState(() => _isRetracing = !_isRetracing);
                        if (!_isRetracing) return;
                        if (crumbs.length < 2) return;
                        // Fit map to show entire trail
                        final lats = crumbs.map((b) => b.latitude!).toList();
                        final lons = crumbs.map((b) => b.longitude!).toList();
                        final bounds = LatLngBounds(
                          LatLng(lats.reduce((a, b) => a < b ? a : b),
                              lons.reduce((a, b) => a < b ? a : b)),
                          LatLng(lats.reduce((a, b) => a > b ? a : b),
                              lons.reduce((a, b) => a > b ? a : b)),
                        );
                        _mapController.fitCamera(
                          CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(48)),
                        );
                        ref.read(aiAssistantProvider.notifier).speak(
                            _isRetracing ? "Retrace mode on. Follow the cyan trail back to start." : "Retrace mode off.");
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        decoration: BoxDecoration(
                          color: _isRetracing ? AppColors.statusBlue.withValues(alpha: 0.9) : AppColors.panelMatte.withValues(alpha: 0.92),
                          borderRadius: const BorderRadius.horizontal(left: Radius.circular(30)),
                          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 6)],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.undo, color: _isRetracing ? Colors.black : Colors.white, size: 20),
                            const SizedBox(width: 6),
                            Text(
                              _isRetracing ? 'RETRACING' : 'RETRACE',
                              style: TextStyle(
                                color: _isRetracing ? Colors.black : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Clear trail button
                    GestureDetector(
                      onTap: () {
                        setState(() { _isRetracing = false; });
                        ref.read(locationProvider.notifier).clearBreadcrumbs();
                        ref.read(aiAssistantProvider.notifier).speak("Trail cleared.");
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade800.withValues(alpha: 0.92),
                          borderRadius: const BorderRadius.horizontal(right: Radius.circular(30)),
                          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 6)],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.delete_outline, color: Colors.white, size: 20),
                            SizedBox(width: 6),
                            Text('CLEAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Trail Distance HUD — auto-shows when a trail is active
          if (trailState.activeTrail != null)
            Positioned(
              top: 60,
              left: 16,
              right: 16,
              child: _buildTrailDistanceHUD(trailState),
            ),

          // Coordinate Display — hidden when drawer is open to prevent z-order clash.
          if (!_drawerOpen)
          Positioned(
            bottom: 130,
            left: 20,
            child: GestureDetector(
              onTap: () =>
                  setState(() => _showCoordinatePanel = !_showCoordinatePanel),
              child: _showCoordinatePanel
                  ? SizedBox(
                      width: 280,
                      child: CoordinateDisplay(
                        position: LatLng(
                          locationState.stats.currentLat ?? -25.3444,
                          locationState.stats.currentLon ?? 131.0369,
                        ),
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
                      position: LatLng(
                        locationState.stats.currentLat ?? -25.3444,
                        locationState.stats.currentLon ?? 131.0369,
                      ),
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

          // Bottom Sheet Overlay — renders on top of coordinate display
          Align(
            alignment: Alignment.bottomCenter,
            child: MeshBottomSheet(
              onWaypointTapped: (coords) {
                _mapController.move(coords, 15.0);
              },
            ),
          ),
          const AiVoiceOverlay(),
          const WeatherOverlay(),

          // Measurement Tool
          if (_showMeasurementTool)
            MeasurementTool(
              key: _measurementKey,
              mapController: _mapController,
              onMeasurementComplete: () {
                setState(() => _showMeasurementTool = false);
              },
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _magnetometerSub?.cancel();
    _meshController.dispose();
    super.dispose();
  }

  Widget _buildTrailDistanceHUD(TrailState trailState) {
    final trail = trailState.activeTrail!;
    final waypoints = trail.getWaypoints();
    final totalKm = (trail.totalDistance ?? 0) / 1000;
    final currentIdx = trailState.currentPointIndex ?? 0;

    // Sum distance of completed segments
    double coveredM = 0;
    const dist = Distance();
    for (int i = 0; i < currentIdx && i < waypoints.length - 1; i++) {
      coveredM += dist.as(LengthUnit.Meter, waypoints[i], waypoints[i + 1]);
    }
    final coveredKm = coveredM / 1000;
    final remainingKm = totalKm - coveredKm;
    final progress = totalKm > 0 ? (coveredKm / totalKm).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF7B2FFF).withValues(alpha: 0.6)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.route, color: Color(0xFF7B2FFF), size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  trail.name ?? 'Active Trail',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${totalKm.toStringAsFixed(2)} km total',
                style: GoogleFonts.outfit(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation(Color(0xFF7B2FFF)),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _hudStat('Covered', '${coveredKm.toStringAsFixed(2)} km', Colors.greenAccent),
              _hudStat('Remaining', '${remainingKm.clamp(0, double.infinity).toStringAsFixed(2)} km', const Color(0xFFFF9800)),
              if (trailState.distanceToNextPoint != null)
                _hudStat('Next pin', trailState.distanceToNextPoint! < 1000 ? '${trailState.distanceToNextPoint!.toInt()} m' : '${(trailState.distanceToNextPoint! / 1000).toStringAsFixed(1)} km', AppColors.statusBlue),
            ],
          ),
        ],
      ),
    );
  }

  Widget _hudStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.outfit(color: Colors.white38, fontSize: 10)),
        Text(value, style: GoogleFonts.outfit(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }

  void _showSOSConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black.withValues(alpha: 0.95),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Colors.red, size: 28),
            const SizedBox(width: 12),
            Text(
              'SOS ALERT',
              style: GoogleFonts.outfit(
                color: AppColors.statusRed,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will broadcast your emergency location via all available channels.',
              style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 12),
            _sosChannel(Icons.hub, 'Mesh broadcast', 'All nearby BushTrack devices'),
            _sosChannel(Icons.sms, 'SMS link', 'Opens SMS with your GPS coords'),
            _sosChannel(Icons.share, 'Web Share', 'Share to WhatsApp, Signal, etc.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CANCEL',
                style: GoogleFonts.outfit(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(context);
              _activateSOS();
            },
            child: Text('ACTIVATE SOS',
                style: GoogleFonts.outfit(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _sosChannel(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: AppColors.statusRed, size: 18),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              Text(subtitle, style: GoogleFonts.outfit(color: Colors.white38, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _activateSOS() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Send SOS?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will broadcast an emergency SOS via mesh, SMS, and share. Only use in a real emergency.',
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
    );
    if (confirmed != true) return;
    if (!mounted) return;

    final locationState = ref.read(locationProvider);
    final lat = locationState.stats.currentLat ?? -25.3444;
    final lon = locationState.stats.currentLon ?? 131.0369;
    final msg = 'SOS EMERGENCY! GPS: $lat, $lon — BushTrack beacon activated. Send help!';

    // 1. Mesh broadcast (devices with app)
    try { ref.read(meshProvider.notifier).sendSOS(); } catch (_) {}

    // 2. SMS link (works on mobile and web)
    try { await openSmsUrl(msg); } catch (_) {}

    // 3. Share API (any app — WhatsApp, Signal, etc.)
    try { await shareText('SOS EMERGENCY', msg); } catch (_) {}

    ref.read(aiAssistantProvider.notifier).speak(
        "SOS activated. Broadcasting on all channels. Stay calm. Help is on the way.");

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.sos, color: Colors.white),
          const SizedBox(width: 12),
          Text('SOS activated on all channels!', style: GoogleFonts.outfit(color: Colors.white)),
        ]),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 8),
      ),
    );
  }

  void _onMapTap(LatLng point, TrailState trailState) {
    if (_showMeasurementTool && _measurementKey.currentState != null) {
      _measurementKey.currentState!.handleMapTap(point);
      return;
    }

    if (trailState.isCreating) {
      ref.read(trailProvider.notifier).addDraftPoint(point);
      ref.read(aiAssistantProvider.notifier)
          .speak("Point ${trailState.draftPoints.length + 1} added.");
      return;
    }

    // Tap near a saved trail ? open edit sheet
    final near = _findNearestTrail(point, trailState.trails);
    if (near != null) {
      _showTrailEditSheet(near);
    }
  }

  void _onMapLongPress(LatLng point) {
    // Long-press near a trail ? edit it instead of dropping a pin
    final trailState = ref.read(trailProvider);
    final near = _findNearestTrail(point, trailState.trails);
    if (near != null) {
      _showTrailEditSheet(near);
      return;
    }
    setState(() => _targetPin = point);
    showPinageChooser(
      context,
      position: point,
      onNormalPin: () => showWaypointEditor(context, position: point),
      onPinage: () => showPinageEditor(context, position: point),
    );
  }

  // Returns the closest trail within a zoom-adaptive hit radius, or null.
  // Base 0.0012 keeps the pixel-radius ~45px constant across all zoom levels,
  // which is comfortably within a finger-width on both web and mobile.
  Trail? _findNearestTrail(LatLng tap, List<Trail> trails) {
    final threshold = 0.0012 * math.pow(2, (16 - _currentZoom).clamp(-3.0, 4.0));
    Trail? nearest;
    double nearestDist = double.infinity;
    for (final trail in trails) {
      final points = trail.getWaypoints();
      if (points.isEmpty) continue;
      for (int i = 0; i < points.length; i++) {
        final d = _latlngDeg(tap, points[i]);
        if (d < threshold && d < nearestDist) { nearestDist = d; nearest = trail; }
        if (i < points.length - 1) {
          final sd = _segDeg(tap, points[i], points[i + 1]);
          if (sd < threshold && sd < nearestDist) { nearestDist = sd; nearest = trail; }
        }
      }
    }
    return nearest;
  }

  double _latlngDeg(LatLng a, LatLng b) {
    final dlat = a.latitude - b.latitude, dlon = a.longitude - b.longitude;
    return math.sqrt(dlat * dlat + dlon * dlon);
  }

  double _segDeg(LatLng p, LatLng a, LatLng b) {
    final dx = b.longitude - a.longitude, dy = b.latitude - a.latitude;
    final len2 = dx * dx + dy * dy;
    if (len2 == 0) return _latlngDeg(p, a);
    final t = ((p.longitude - a.longitude) * dx + (p.latitude - a.latitude) * dy) / len2;
    final tc = t.clamp(0.0, 1.0);
    final ex = p.longitude - (a.longitude + tc * dx);
    final ey = p.latitude - (a.latitude + tc * dy);
    return math.sqrt(ex * ex + ey * ey);
  }

  List<CircleMarker> _buildDwellCircles(List<Breadcrumb> crumbs) {
    if (crumbs.length < 2) return [];
    final sorted = [...crumbs]
      ..sort((a, b) =>
          (a.timestamp?.millisecondsSinceEpoch ?? 0)
              .compareTo(b.timestamp?.millisecondsSinceEpoch ?? 0));
    const grid = 0.0005; // ~55 m per cell
    final Map<String, _DwellCell> cells = {};
    for (int i = 0; i < sorted.length - 1; i++) {
      final a = sorted[i];
      final b = sorted[i + 1];
      final alat = a.latitude; final alon = a.longitude;
      final ats = a.timestamp; final bts = b.timestamp;
      if (alat == null || alon == null || ats == null || bts == null) continue;
      final ms = bts.millisecondsSinceEpoch - ats.millisecondsSinceEpoch;
      if (ms <= 0 || ms > 120000) continue; // skip gaps > 2 min
      final glat = (alat / grid).round() * grid;
      final glon = (alon / grid).round() * grid;
      final key = '${glat.toStringAsFixed(4)},${glon.toStringAsFixed(4)}';
      cells.putIfAbsent(key, () => _DwellCell(LatLng(glat, glon)));
      cells[key]!.add(ms);
    }
    final circles = <CircleMarker>[];
    for (final cell in cells.values) {
      if (cell.totalMs < 30000) continue; // < 30 s — skip noise
      final mins = cell.totalMs / 60000;
      final color = mins > 10
          ? AppColors.statusRed
          : mins > 2
              ? AppColors.accent
              : AppColors.statusYellow;
      circles.add(CircleMarker(
        point: cell.center,
        radius: (30 + (mins * 8).clamp(0, 200)).toDouble(),
        useRadiusInMeter: true,
        color: color.withValues(alpha: 0.28),
        borderColor: color.withValues(alpha: 0.75),
        borderStrokeWidth: 1.5,
      ));
    }
    return circles;
  }

  List<Widget> _buildTrailLayers(TrailState trailState, LocationState locationState, NavigationState navState) {
    final layers = <Widget>[];

    // Active navigation route — blue polyline + destination flag
    if (navState.isActive && navState.routePolyline.isNotEmpty) {
      layers.add(PolylineLayer(polylines: [
        Polyline(
          points: navState.routePolyline,
          color: AppColors.statusBlue,
          strokeWidth: 6.0,
          borderStrokeWidth: 2.0,
          borderColor: Colors.black,
        ),
      ]));
      layers.add(MarkerLayer(markers: [
        Marker(
          point: navState.routePolyline.last,
          width: 44,
          height: 44,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8)],
            ),
            child: const Icon(Icons.flag, color: Colors.white, size: 22),
          ),
        ),
      ]));
    }

    // Active trail (highlighted)
    if (trailState.activeTrail != null) {
      final points = trailState.activeTrail!.getWaypoints();
      final color = WaypointColors.fromHex(trailState.activeTrail!.color);
      final pattern =
          TrailLineStyle.getPattern(trailState.activeTrail!.lineStyle);

      layers.add(
        PolylineLayer(
          polylines: [
            Polyline(
              points: points,
              color: color,
              strokeWidth: 5.0,
              borderStrokeWidth: 2.0,
              borderColor: Colors.black,
              isDotted: pattern != null && pattern.first == 5.0,
            ),
          ],
        ),
      );

      // Add numbered markers for trail points — tappable to open edit sheet
      final activeTrailRef = trailState.activeTrail!;
      layers.add(
        MarkerLayer(
          markers: [
            for (int i = 0; i < points.length; i++)
              Marker(
                point: points[i],
                width: 50,
                height: 50,
                child: GestureDetector(
                  onTap: () => _showTrailEditSheet(activeTrailRef),
                  child: _buildNumberedMarker(i + 1, color),
                ),
              ),
          ],
        ),
      );
    }

    // Other saved trails + edit markers at midpoint
    for (final trail
        in trailState.trails.where((t) => t.id != trailState.activeTrail?.id)) {
      final points = trail.getWaypoints();
      if (points.isEmpty) continue;

      final color = WaypointColors.fromHex(trail.color);
      final pattern = TrailLineStyle.getPattern(trail.lineStyle);

      layers.add(
        PolylineLayer(
          polylines: [
            Polyline(
              points: points,
              color: color.withValues(alpha: 0.6),
              strokeWidth: 3.0,
              isDotted: pattern != null && pattern.first == 5.0,
            ),
          ],
        ),
      );

      // Name chip at trail midpoint — tappable edit button
      final mid = points[points.length ~/ 2];
      final trailName = trail.name ?? 'Trail';
      layers.add(MarkerLayer(markers: [
        Marker(
          point: mid,
          width: trailName.length * 8.0 + 52,
          height: 32,
          child: GestureDetector(
            onTap: () => _showTrailEditSheet(trail),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 4)],
                border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(
                  trailName,
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(width: 5),
                const Icon(Icons.edit, color: Colors.white70, size: 11),
              ]),
            ),
          ),
        ),
      ]));
    }

    // -- Dwell heatmap ---------------------------------------------------------
    if (_showDwellMap) {
      final circles = _buildDwellCircles(locationState.breadcrumbs
          .where((b) => b.latitude != null && b.longitude != null)
          .toList());
      if (circles.isNotEmpty) {
        layers.add(CircleLayer(circles: circles));
      }
    }

    // -- Breadcrumb trail ------------------------------------------------------
    if (_showBreadcrumbs) {
      final crumbs = locationState.breadcrumbs
          .where((b) => b.latitude != null && b.longitude != null)
          .toList();

      if (crumbs.length > 1) {
        final pts = crumbs.map((b) => LatLng(b.latitude!, b.longitude!)).toList();
        final displayPts = _isRetracing ? pts.reversed.toList() : pts;

        // Trail line — red when recording, cyan when retracing
        layers.add(PolylineLayer(
          polylines: [
            Polyline(
              points: displayPts,
              color: _isRetracing ? AppColors.statusBlue : Colors.red,
              strokeWidth: 4.0,
              borderStrokeWidth: 1.5,
              borderColor: Colors.black.withValues(alpha: 0.6),
            ),
          ],
        ));

        // Origin marker (green flag = where you started)
        layers.add(MarkerLayer(markers: [
          Marker(
            point: pts.first,
            width: 44,
            height: 44,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.statusGreen.withValues(alpha: 0.85),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 4)],
              ),
              child: const Icon(Icons.flag, color: Colors.white, size: 22),
            ),
          ),
        ]));
      }
    }

    return layers;
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

  void _showTrailEditSheet(Trail trail) {
    String name = trail.name ?? 'Trail';
    String color = trail.color ?? TrailColors.electricPurple;
    String lineStyle = trail.lineStyle ?? TrailLineStyle.solid;
    final nameCtrl = TextEditingController(text: name);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            left: 20, right: 20, top: 20,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A2E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Edit Trail',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Trail name',
                  labelStyle: TextStyle(color: Colors.white54),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.orange)),
                ),
                onChanged: (v) => name = v,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: color,
                dropdownColor: const Color(0xFF1A1A2E),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Color',
                  labelStyle: TextStyle(color: Colors.white54),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                ),
                items: TrailColors.allColors
                    .map((c) => DropdownMenuItem(
                          value: c,
                          child: Row(children: [
                            Container(width: 16, height: 16,
                                decoration: BoxDecoration(color: WaypointColors.fromHex(c), shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Text(c),
                          ]),
                        ))
                    .toList(),
                onChanged: (v) { if (v != null) setState(() => color = v); },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: lineStyle,
                dropdownColor: const Color(0xFF1A1A2E),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Line style',
                  labelStyle: TextStyle(color: Colors.white54),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                ),
                items: const [
                  DropdownMenuItem(value: TrailLineStyle.solid, child: Text('Solid')),
                  DropdownMenuItem(value: TrailLineStyle.dashed, child: Text('Dashed')),
                  DropdownMenuItem(value: TrailLineStyle.dotted, child: Text('Dotted')),
                ],
                onChanged: (v) { if (v != null) setState(() => lineStyle = v); },
              ),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      ref.read(trailProvider.notifier).deleteTrail(trail.id!);
                    },
                    child: const Text('DELETE'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                    onPressed: () {
                      Navigator.pop(ctx);
                      trail.name = nameCtrl.text.trim().isEmpty ? 'Trail' : nameCtrl.text.trim();
                      trail.color = color;
                      trail.lineStyle = lineStyle;
                      ref.read(trailProvider.notifier).updateTrail(trail);
                    },
                    child: const Text('SAVE'),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  void _zoomToFitWaypoints(List<Waypoint> waypoints) {
    final valid = waypoints.where((w) => w.latitude != null && w.longitude != null).toList();
    if (valid.isEmpty) return;

    final lats = valid.map((w) => w.latitude!).toList();
    final lons = valid.map((w) => w.longitude!).toList();

    final minLat = lats.reduce((a, b) => a < b ? a : b);
    final maxLat = lats.reduce((a, b) => a > b ? a : b);
    final minLon = lons.reduce((a, b) => a < b ? a : b);
    final maxLon = lons.reduce((a, b) => a > b ? a : b);

    final center = LatLng(
      (minLat + maxLat) / 2,
      (minLon + maxLon) / 2,
    );

    final latDelta = maxLat - minLat;
    final lonDelta = maxLon - minLon;
    final maxDelta = latDelta > lonDelta ? latDelta : lonDelta;

    // Calculate zoom level to fit
    double zoom = 18;
    if (maxDelta > 0) {
      zoom = 18 - (maxDelta / 0.005).floor().clamp(0, 16).toDouble();
    }

    _mapController.move(center, zoom);
  }

  void _editWaypoint(Waypoint waypoint) {
    showWaypointEditor(context, waypoint: waypoint);
  }

  void _showPinageViewer(Waypoint waypoint) {
    showPinageViewer(
      context,
      waypoint: waypoint,
      onEdit: () => showPinageEditor(
        context,
        position: LatLng(waypoint.latitude!, waypoint.longitude!),
        existing: waypoint,
      ),
      onDelete: () => ref.read(locationProvider.notifier).deleteWaypoint(waypoint.id!),
      onJumpToMap: () {
        if (waypoint.latitude != null && waypoint.longitude != null) {
          _mapController.move(
              LatLng(waypoint.latitude!, waypoint.longitude!), 16.0);
        }
      },
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
      filled: true,
      fillColor: const Color(0xFF2C2C2C),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  void _showClearWaypointsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Clear All Waypoints?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'This will permanently delete all your saved waypoints. This action cannot be undone.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('CANCEL', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              ref.read(locationProvider.notifier).deleteAllWaypoints();
              Navigator.pop(context);
              ref
                  .read(aiAssistantProvider.notifier)
                  .speak("All waypoints cleared.");
            },
            child: const Text('CLEAR ALL', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _takeScreenshot() async {
    try {
      final boundary = _screenshotKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final bytes = byteData.buffer.asUint8List();
      await downloadBytes(
          'bushtrack_${DateTime.now().millisecondsSinceEpoch}.png', bytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Screenshot saved.'),
            backgroundColor: AppColors.primaryOrange,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Screenshot error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Screenshot failed: $e')),
        );
      }
    }
  }

  Widget _buildMeshOverlay() {
    return PolylineLayer(
      polylines: [
        Polyline(
          points: [
            const LatLng(-25.3444, 131.0369),
            const LatLng(-25.3500, 131.0500),
          ],
          color: AppColors.primaryOrange,
          strokeWidth: 4.0,
        ),
      ],
    );
  }

  Widget _hamburgerLine() => Container(
        width: 18,
        height: 2,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(1),
        ),
      );

  Widget _buildFloatingButton(
    IconData icon,
    VoidCallback onPressed, {
    bool isActive = false,
    bool isAlert = false,
    String? tooltip,
    String? description,
  }) {
    // Bug #1 fix: Use MouseRegion tooltip instead of Tooltip widget which
    // intercepts pointer events on Flutter Web and breaks the entire sidebar.
    return _SidebarButton(
      icon: icon,
      onPressed: onPressed,
      isActive: isActive,
      isAlert: isAlert,
      tooltip: tooltip,
    );
  }

  Widget _buildBushTrackLogo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '?? BUSHTRACK',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            shadows: [
              Shadow(
                color: AppColors.primaryOrange.withValues(alpha: 0.5),
                blurRadius: 15,
              ),
            ],
          ),
        ).animate().fadeIn(duration: 800.ms).slideX(begin: -0.2),
        Text(
          'ULTRA-OFFLINE v3.0',
          style: GoogleFonts.outfit(
            color: AppColors.primaryOrange,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 3,
          ),
        )
            .animate()
            .fadeIn(delay: 400.ms, duration: 600.ms)
            .shimmer(color: Colors.white),
      ],
    );
  }

  Widget _buildAIStatusIndicator() {
    final aiState = ref.watch(aiAssistantProvider);

    Color tierColor;
    String tierLabel;
    IconData tierIcon;

    if (aiState.isOfflineMode) {
      if (aiState.isOnDeviceMode) {
        tierColor = AppColors.purplePrimary;
        tierLabel = 'ON-DEVICE AI';
        tierIcon = Icons.auto_awesome;
      } else {
        tierColor = AppColors.statusYellow;
        tierLabel = 'OFFLINE MODE';
        tierIcon = Icons.cloud_off;
      }
    } else {
      tierColor = AppColors.statusGreen;
      tierLabel = 'ONLINE SYNC';
      tierIcon = Icons.cloud_done;
    }

    return GestureDetector(
      onTap: () async {
        final fullStatus =
            await ref.read(aiAssistantProvider.notifier).getFullAiStatus();
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.black.withValues(alpha: 0.9),
            title: Text(
              '? FUTURE GEN AI AI STATUS',
              style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            content: GlassPanel(
              padding: const EdgeInsets.all(12),
              child: SingleChildScrollView(
                child: Text(
                  fullStatus,
                  style: GoogleFonts.jetBrainsMono(
                      color: Colors.white70, fontSize: 11),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('CLOSE',
                    style: GoogleFonts.outfit(color: AppColors.primaryOrange)),
              ),
            ],
          ),
        );
      },
      child: GlassPanel(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        borderRadius: 25,
        borderColor: tierColor.withValues(alpha: 0.3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(tierIcon, color: tierColor, size: 14)
                .animate(onPlay: (controller) => controller.repeat())
                .shimmer(duration: 2.seconds),
            const SizedBox(width: 8),
            Text(
              tierLabel,
              style: GoogleFonts.outfit(
                color: tierColor,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
            if (aiState.isProcessing) ...[
              const SizedBox(width: 10),
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ).animate().rotate(),
            ],
          ],
        ),
      ).animate().fadeIn().scale(begin: const Offset(0.8, 0.8)),
    );
  }

  Widget _buildConnectivityIndicator() {
    final connectivityState = ref.watch(connectivityProvider);

    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppColors.panelMatte,
            title: Row(
              children: [
                Icon(
                  connectivityState.isConnected ? Icons.wifi : Icons.wifi_off,
                  color: connectivityState.statusColor,
                ),
                const SizedBox(width: 12),
                const Text('Connection Status',
                    style: TextStyle(color: Colors.white)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusRow(
                    'Status',
                    connectivityState.isConnected ? 'Connected' : 'Offline',
                    connectivityState.statusColor),
                const SizedBox(height: 8),
                _buildStatusRow(
                    'Type',
                    connectivityState.connectionType.toUpperCase(),
                    connectivityState.statusColor),
                const SizedBox(height: 8),
                _buildStatusRow(
                    'Last Checked',
                    connectivityState.lastChecked?.toString() ?? 'Unknown',
                    AppColors.textSecondary),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.statusGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: AppColors.statusGreen, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Offline mode is always available. Your data stays on device.',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CLOSE',
                    style: TextStyle(color: AppColors.primaryOrange)),
              ),
            ],
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: connectivityState.statusColor, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(connectivityState.statusIcon,
                color: connectivityState.statusColor, size: 14),
            const SizedBox(width: 6),
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: connectivityState.statusColor,
                boxShadow: [
                  BoxShadow(
                    color: connectivityState.statusColor.withValues(alpha: 0.5),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Text(
              connectivityState.statusText,
              style: TextStyle(
                color: connectivityState.statusColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary)),
        Text(value,
            style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

/// A sidebar button that uses [MouseRegion] instead of Flutter's [Tooltip]
/// widget. On Flutter Web, [Tooltip] renders an overlay that intercepts
/// subsequent pointer events on the parent [Column], causing all sibling
/// buttons to disappear until a page refresh. [MouseRegion] + a custom
/// overlay avoids this entirely while still showing a hover label on desktop.
class _SidebarButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool isActive;
  final bool isAlert;
  final String? tooltip;

  const _SidebarButton({
    required this.icon,
    required this.onPressed,
    this.isActive = false,
    this.isAlert = false,
    this.tooltip,
  });

  @override
  State<_SidebarButton> createState() => _SidebarButtonState();
}

class _SidebarButtonState extends State<_SidebarButton> {
  bool _hovered = false;
  bool _pressed = false;
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();

  void _showTooltip() {
    if (widget.tooltip == null || widget.tooltip!.isEmpty) return;
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        child: CompositedTransformFollower(
          link: _layerLink,
          targetAnchor: Alignment.centerLeft,
          followerAnchor: Alignment.centerRight,
          offset: const Offset(-8, 0),
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: AppColors.primaryOrange.withValues(alpha: 0.4)),
              ),
              child: Text(
                widget.tooltip!,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideTooltip() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _hideTooltip();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color iconColor = widget.isAlert
        ? const Color(0xFFFF2D55)
        : (widget.isActive ? const Color(0xFFFF6B35) : Colors.white);

    final Color borderColor = widget.isActive
        ? const Color(0xFF1E2A5E)
        : (_hovered
            ? const Color(0xFF7B2FFF).withValues(alpha: 0.6)
            : const Color(0xFF1E2A5E));

    return CompositedTransformTarget(
      link: _layerLink,
      child: MouseRegion(
        onEnter: (_) {
          setState(() => _hovered = true);
          _showTooltip();
        },
        onExit: (_) {
          setState(() => _hovered = false);
          _hideTooltip();
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          onTap: widget.onPressed,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 120),
            scale: _pressed ? 0.95 : (_hovered ? 1.05 : 1.0),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: widget.isAlert
                      ? [const Color(0xFFFF2D55), const Color(0xFFB10028)]
                      : [const Color(0xFF131A42), const Color(0xFF0D1235)],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor, width: 1),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(widget.icon, color: iconColor, size: 22),
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Hamburger Drawer
// -----------------------------------------------------------------------------

class _HamburgerDrawer extends StatelessWidget {
  final VoidCallback onClose;
  final bool is3DMode;
  final int mapStyleIndex;
  final bool showBreadcrumbs;
  final bool showDwellMap;
  final bool showMeasurementTool;
  final bool isCreatingTrail;
  final bool hasGps;
  final bool hasWaypoints;
  final VoidCallback onToggle3D;
  final VoidCallback onMapStyle;
  final VoidCallback onToggleBreadcrumbs;
  final VoidCallback onRecenter;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onScanBounds;
  final VoidCallback onElevationProfile;
  final VoidCallback onAddWaypoint;
  final VoidCallback onTrackRecord;
  final VoidCallback onExportTrack;
  final VoidCallback onLayerManager;
  final VoidCallback onMeasure;
  final VoidCallback onScreenshot;
  final VoidCallback onDeviceInfo;
  final VoidCallback onNavigation;
  final VoidCallback onAIAssistant;
  final VoidCallback onSearchPlace;
  final VoidCallback onCompassNav;
  final VoidCallback onMeshSignal;
  final VoidCallback onSettings;
  final VoidCallback onAnalytics;
  final VoidCallback onGallery;
  final VoidCallback onSOS;

  const _HamburgerDrawer({
    required this.onClose,
    required this.is3DMode,
    required this.mapStyleIndex,
    required this.showBreadcrumbs,
    required this.showDwellMap,
    required this.showMeasurementTool,
    required this.isCreatingTrail,
    required this.hasGps,
    required this.hasWaypoints,
    required this.onToggle3D,
    required this.onMapStyle,
    required this.onToggleBreadcrumbs,
    required this.onRecenter,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onScanBounds,
    required this.onElevationProfile,
    required this.onAddWaypoint,
    required this.onTrackRecord,
    required this.onExportTrack,
    required this.onLayerManager,
    required this.onMeasure,
    required this.onScreenshot,
    required this.onDeviceInfo,
    required this.onNavigation,
    required this.onAIAssistant,
    required this.onSearchPlace,
    required this.onCompassNav,
    required this.onMeshSignal,
    required this.onSettings,
    required this.onAnalytics,
    required this.onGallery,
    required this.onSOS,
  });

  void _go(VoidCallback fn) {
    onClose();
    fn();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0D0F1E),
          boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 24, offset: Offset(8, 0))],
        ),
        child: SafeArea(
          child: Column(
            children: [
              _header(context),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _section('MAP LAYERS'),
                      _item(context, Icons.landscape, const Color(0xFFFF8C00), 'Terrain Layer', is3DMode ? '3D active' : '2D view', 'Switch between flat 2D tactical view and immersive 3D terrain rendering.', () => _go(onToggle3D)),
                      _item(context, Icons.layers, const Color(0xFF9C60F0), 'Layer Manager', 'Cycle map style', 'Cycle through Street, Satellite (Esri), Dark, and Topo map styles.', () => _go(onLayerManager)),

                      _section('NAVIGATION'),
                      _item(context, Icons.my_location, const Color(0xFF2196F3), 'Re-centre GPS', 'Jump to my location', 'Centres the map on your current GPS position at zoom 16.', () => _go(onRecenter)),
                      _item(context, Icons.add, const Color(0xFF4CAF50), 'Zoom In', 'Increase detail', 'Zoom in one level for more map detail.', () => _go(onZoomIn)),
                      _item(context, Icons.remove, const Color(0xFFF44336), 'Zoom Out', 'Decrease detail', 'Zoom out one level to see a wider area.', () => _go(onZoomOut)),
                      _item(context, Icons.fit_screen, const Color(0xFF00BCD4), 'Scan Bounds', 'Fit all waypoints', 'Zooms and pans to show all your saved waypoints on screen at once.', () => _go(onScanBounds)),

                      _section('TRACKING'),
                      _item(context, Icons.route, const Color(0xFF2196F3), 'Breadcrumb Trail', showBreadcrumbs ? 'Trail on · RETRACE shown' : 'Show your path', 'Records and displays your movement path. Shows RETRACE and CLEAR controls on the map.', () => _go(onToggleBreadcrumbs)),
                      _item(context, Icons.thermostat, const Color(0xFFFFB300), 'Dwell Heatmap', showDwellMap ? 'Heatmap on' : 'Show dwell heatmap', 'Shows where you spent the most time. Yellow = brief stop, Red = long stay.', () => _go(onElevationProfile)),
                      _item(context, Icons.add_location_alt, const Color(0xFF4CAF50), 'Add Waypoint', 'Drop a pin', 'Drop a waypoint marker at the current map centre.', () => _go(onAddWaypoint)),
                      _item(context, Icons.timeline, const Color(0xFF9C60F0), 'Track Record', isCreatingTrail ? 'Recording…' : 'Record a trail', 'Activate trail recording mode — tap the map to drop route points.', () => _go(onTrackRecord)),
                      _item(context, Icons.analytics, const Color(0xFF2196F3), 'Export Track', 'Trip stats & export', 'View trip statistics, distance, speed and export your track data.', () => _go(onExportTrack)),

                      _section('TOOLS'),
                      _item(context, Icons.straighten, const Color(0xFF00BCD4), 'Measure Distance', showMeasurementTool ? 'Active' : 'Tap to measure', 'Tap points on the map to measure distance, area, and bearing.', () => _go(onMeasure)),
                      _item(context, Icons.screenshot, Colors.white70, 'Map Screenshot', 'Save as PNG', 'Saves the current map view as a PNG image to your device.', () => _go(onScreenshot)),
                      _item(context, Icons.pin_drop, const Color(0xFFFFB300), 'Enter Coordinates', 'Go to GPS location', 'Manually enter GPS coordinates in decimal, DMS, or UTM format to jump to a location.', () => _go(onDeviceInfo)),
                      _item(context, Icons.directions, const Color(0xFF2196F3), 'Navigation Mode', 'Route guidance', 'Get turn-by-turn directions to any destination using OSRM routing.', () => _go(onNavigation)),
                      _item(context, Icons.psychology, const Color(0xFF9C60F0), 'AI Assistant', 'Natural language search', 'Search in plain English — "nearest water source" or "fuel under 50 km".', () => _go(onAIAssistant)),
                      _item(context, Icons.place, const Color(0xFF4CAF50), 'Search Place', 'Find places & POIs', 'Search for towns, landmarks, and points of interest near you.', () => _go(onSearchPlace)),
                      _item(context, Icons.compass_calibration, const Color(0xFFFF8C00), 'Compass Nav', 'AR compass overlay', 'Augmented reality compass overlay on your device camera view.', () => _go(onCompassNav)),
                      _item(context, Icons.download_for_offline, const Color(0xFF00BCD4), 'Offline Maps', 'Download map regions', 'Download map regions for use without an internet connection.', () => _go(onMeshSignal)),

                      _section('MEDIA'),
                      _item(context, Icons.photo_library, const Color(0xFFFFB300), 'Photo Gallery', 'Geotagged photos', 'Browse all geotagged photos — tap the pin icon to jump to that location on the map.', () => _go(onGallery)),

                      _section('SYSTEM'),
                      _item(context, Icons.settings, Colors.grey, 'Settings', 'App preferences', 'Configure vehicle profile, privacy settings, and app preferences.', () => _go(onSettings)),
                      _item(context, Icons.support_agent_rounded, const Color(0xFF9C60F0), 'Analytics', 'AI personas', 'Select your AI persona — Scout, Navigator, Rescue, or Tactical.', () => _go(onAnalytics)),

                      const SizedBox(height: 20),
                      _sosItem(context),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: Row(children: [
        ShaderMask(
          shaderCallback: (b) => const LinearGradient(
            colors: [Color(0xFFFF8C00), Color(0xFFFF6A00)],
          ).createShader(b),
          child: const Icon(Icons.explore, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 8),
        const Text('BUSHTRACK',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1)),
        const Spacer(),
        GestureDetector(
          onTap: onClose,
          child: Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.close, color: Colors.white60, size: 18),
          ),
        ),
      ]),
    );
  }

  Widget _section(String label) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 18, 0, 6),
        child: Text(label,
            style: const TextStyle(
                color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
      );

  Widget _item(BuildContext context, IconData icon, Color color, String name, String subtitle,
      String description, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
              Text(subtitle,
                  style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ]),
          ),
          _infoBtn(context, name, description, isRed: false),
        ]),
      ),
    );
  }

  Widget _sosItem(BuildContext context) {
    return GestureDetector(
      onLongPress: () => _go(onSOS),
      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hold the SOS button for 3 seconds to activate.'),
          duration: Duration(seconds: 2),
          backgroundColor: Color(0xFFFF2D55),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFF2D55).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFF2D55).withValues(alpha: 0.4)),
        ),
        child: Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFFF2D55).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.sos, color: Color(0xFFFF2D55), size: 19),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('SOS — 505',
                  style: TextStyle(
                      color: Color(0xFFFF2D55),
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      letterSpacing: 0.5)),
              Text('Hold 3 sec · broadcasts GPS coords via mesh',
                  style: TextStyle(
                      color: Color(0xFFFF2D55), fontSize: 10, fontWeight: FontWeight.w500)),
            ]),
          ),
          _infoBtn(context, 'SOS — 505',
              'Emergency broadcast to all mesh nodes. Hold for 3 seconds to activate. Sends your GPS coordinates to all nearby mesh devices. USE ONLY IN A GENUINE EMERGENCY.',
              isRed: true),
        ]),
      ),
    );
  }

  static Widget _infoBtn(BuildContext context, String title, String desc, {required bool isRed}) {
    return GestureDetector(
      onTap: () => showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF0D0F1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
                color: isRed
                    ? const Color(0xFFFF2D55).withValues(alpha: 0.5)
                    : const Color(0xFF9C60F0).withValues(alpha: 0.5)),
          ),
          title: Text(title,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          content: Text(desc,
              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK', style: TextStyle(color: Color(0xFFFF8C00))),
            ),
          ],
        ),
      ),
      child: Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: const Color(0xFF0D0F1E),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: isRed
                ? const Color(0xFFFF2D55).withValues(alpha: 0.6)
                : const Color(0xFF9C60F0).withValues(alpha: 0.5),
          ),
        ),
        child: Icon(Icons.info_outline, size: 14,
            color: isRed ? const Color(0xFFFF2D55) : const Color(0xFFC9A8FF)),
      ),
    );
  }
}

