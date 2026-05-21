import 'package:flutter/material.dart';
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
import 'widgets/ai_voice_overlay.dart';
import '../../mesh/providers/mesh_sync_provider.dart';
import 'package:bush_track/features/weather/widgets/weather_overlay.dart';
import 'package:bush_track/features/places/presentation/places_search_screen.dart';
import 'package:bush_track/features/navigation/presentation/route_options_screen.dart';
import 'package:bush_track/features/ar/presentation/ar_compass_screen.dart';
import 'package:bush_track/features/settings/presentation/settings_screen.dart';
import 'package:bush_track/features/map/widgets/measurement_tool.dart';
import 'package:bush_track/features/search/presentation/natural_language_search_screen.dart';
import 'package:bush_track/features/trip/presentation/trip_statistics_screen.dart';
import 'package:bush_track/features/places/presentation/coordinate_input_screen.dart';
import 'package:bush_track/features/places/presentation/street_view_screen.dart';
import 'package:bush_track/core/services/connectivity_service.dart';
import 'package:bush_track/features/map/widgets/coordinate_display.dart';
import 'package:bush_track/core/utils/coordinate_utils.dart';
import 'package:bush_track/features/map/services/photo_geotagging_service.dart';
import 'package:bush_track/features/map/presentation/photo_pin_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:bush_track/features/map/services/offline_map_manager.dart';
import 'package:bush_track/features/map/widgets/compass_rose.dart';
import 'package:bush_track/features/map/widgets/scale_bar.dart';
import 'package:bush_track/features/map/widgets/map_loading_indicator.dart';
import 'package:bush_track/features/map/widgets/waypoint_marker.dart';
import 'package:bush_track/features/map/widgets/waypoint_editor.dart';
import 'package:bush_track/features/map/widgets/trail_creation_overlay.dart';
import 'package:bush_track/features/map/providers/trail_provider.dart';
import 'package:bush_track/core/config/api_config.dart';
import 'package:bush_track/core/models/waypoint.dart';
import 'package:bush_track/core/models/trail.dart';
import 'package:bush_track/features/ai/presentation/agent_manager_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  bool _isSatellite = false;
  LatLng? _targetPin;

  // Map state
  bool _mapInitialized = false;
  bool _tilesLoading = true;
  double _currentZoom = 13.0;
  double _currentRotation = 0.0;

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

  late AnimatedMeshGradientController _meshController;

  @override
  void initState() {
    super.initState();
    _meshController = AnimatedMeshGradientController();
    _initializeServices();
    _setupMapListeners();
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

  @override
  Widget build(BuildContext context) {
    debugPrint('🟢 DASHBOARD BUILD STARTING');
    final locationState = ref.watch(locationProvider);
    final meshState = ref.watch(meshProvider);
    final trailState = ref.watch(trailProvider);
    final aiState = ref.watch(aiAssistantProvider);

    // Initialize mesh sync bridge
    try {
      ref.watch(meshSyncProvider);
    } catch (e) {
      debugPrint('⚠️ Mesh sync error: $e');
    }
    debugPrint(
        '🟢 DASHBOARD PROVIDERS LOADED - waypoints: ${locationState.waypoints.length}');

    // Get pin waypoints (not track points)
    final pinWaypoints = locationState.waypoints
        .where((w) => w.isPin == true || w.type == WaypointType.manual)
        .toList();

    final baseTileUrl = ApiConfig.mapboxToken.isEmpty
        ? 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png'
        : (_isSatellite
            ? ApiConfig.mapboxTilesUrl('mapbox/satellite-streets-v12', 'jpg')
            : ApiConfig.mapboxTilesUrl('mapbox/dark-v11', 'png'));

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
          // Map with gesture handling
          _is3DMode
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
                      minZoom: 2.0,
                      maxZoom: 18.0,
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
                          _currentRotation =
                              0.0; // MapPosition doesn't have rotation in this version
                        });
                      },
                    ),
                    children: [
                      // Tile layer with OpenStreetMap
                      TileLayer(
                        urlTemplate: baseTileUrl,
                        subdomains: const ['a', 'b', 'c'],
                        maxZoom: 18.0,
                        minZoom: 2.0,
                        tileSize: 256,
                        retinaMode: true,
                        // Preload surrounding tiles
                        panBuffer: 2,
                        keepBuffer: 6,
                        errorTileCallback: (tile, error, stackTrace) {
                          debugPrint('Tile error: $error');
                          setState(() => _showOfflineBanner = true);
                        },
                        tileDisplay: const TileDisplay.fadeIn(),
                      ),
                      // Trail lines layer
                      ..._buildTrailLayers(trailState),
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
                          // Pin Waypoints with interaction
                          ...pinWaypoints.map((w) {
                            return Marker(
                              point:
                                  LatLng(w.latitude ?? 0.0, w.longitude ?? 0.0),
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
                                  color: Colors.redAccent, size: 50),
                            )
                          ],
                        ),
                      // Mesh Peers
                      if (meshState.peerLocations.isNotEmpty)
                        MarkerLayer(
                          markers: meshState.peerLocations.values.map((packet) {
                            return Marker(
                              point:
                                  LatLng(packet.latitude!, packet.longitude!),
                              width: 40,
                              height: 40,
                              child: const Icon(Icons.person_pin_circle,
                                  color: Colors.blueAccent, size: 40),
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
                  color: Colors.orange.withValues(alpha: 0.9),
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

          // Unified top bar — sits flush at the top, respects system status bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            right: 12,
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xF2080B1A),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFF1E2A5E), width: 1),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black54,
                      blurRadius: 16,
                      offset: Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  Text(
                    '🌿 BUSHTRACK',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7B2FFF).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                          color:
                              const Color(0xFF7B2FFF).withValues(alpha: 0.35)),
                    ),
                    child: const Text('v3.0',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ),
                  const Spacer(),
                  _buildAIStatusIndicator(),
                  const SizedBox(width: 8),
                  _buildConnectivityIndicator(),
                ],
              ),
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

          // Right-side floating action buttons — starts below the top bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 80,
            right: 20,
            child: Column(
              children: [
                // 3D Terrain Toggle
                _buildFloatingButton(
                  _is3DMode ? Icons.view_in_ar : Icons.landscape,
                  () => setState(() => _is3DMode = !_is3DMode),
                  tooltip:
                      _is3DMode ? 'Switch to 2D Map' : 'Switch to 3D Terrain',
                  description: _is3DMode
                      ? 'Return to flat tactical view'
                      : 'Activate immersive 3D terrain and topographical rendering',
                  isActive: _is3DMode,
                ),
                const SizedBox(height: 12),
                // Agent Manager (Antigravity Personas)
                _buildFloatingButton(
                  Icons.support_agent_rounded,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const AgentManagerScreen()),
                    );
                  },
                  tooltip: 'Agent Manager',
                  description:
                      'Select your AI persona (Scout, Navigator, Rescue, Tactical)',
                  isActive: false,
                ),
                const SizedBox(height: 12),
                // Map Style Toggle
                _buildFloatingButton(
                  _isSatellite ? Icons.map : Icons.satellite,
                  () => setState(() => _isSatellite = !_isSatellite),
                  tooltip: _isSatellite
                      ? 'Switch to Street Map'
                      : 'Switch to Satellite',
                  description: _isSatellite
                      ? 'Shows detailed street map with roads'
                      : 'Shows aerial satellite imagery',
                ),
                const SizedBox(height: 12),
                // Zoom In
                _buildFloatingButton(Icons.add, () {
                  final newZoom =
                      (_mapController.camera.zoom + 1).clamp(2.0, 18.0);
                  _mapController.move(_mapController.camera.center, newZoom);
                },
                    tooltip: 'Zoom In',
                    description: 'Increase map detail and zoom level'),
                const SizedBox(height: 8),
                // Zoom Out
                _buildFloatingButton(Icons.remove, () {
                  final newZoom =
                      (_mapController.camera.zoom - 1).clamp(2.0, 18.0);
                  _mapController.move(_mapController.camera.center, newZoom);
                },
                    tooltip: 'Zoom Out',
                    description: 'Decrease zoom to see larger area'),
                const SizedBox(height: 12),
                // Center on me
                _buildFloatingButton(Icons.my_location, () {
                  if (locationState.stats.currentLat != null) {
                    _mapController.move(
                      LatLng(locationState.stats.currentLat!,
                          locationState.stats.currentLon!),
                      16.0,
                    );
                  }
                },
                    tooltip: 'Go to My Location',
                    description: 'Center map on your current GPS position',
                    isActive: locationState.stats.currentLat != null),
                const SizedBox(height: 12),
                // Zoom to fit all waypoints
                _buildFloatingButton(Icons.fit_screen, () {
                  if (locationState.waypoints.isNotEmpty) {
                    _zoomToFitWaypoints(locationState.waypoints);
                  }
                },
                    tooltip: 'Fit All Waypoints',
                    description:
                        'Zoom to show all your saved waypoints on screen'),
                const SizedBox(height: 12),
                // Create Trail
                _buildFloatingButton(
                  Icons.timeline,
                  () {
                    ref.read(trailProvider.notifier).startCreatingTrail();
                    ref.read(aiAssistantProvider.notifier).speak(
                        "Trail creation mode activated. Tap on the map to drop points.");
                  },
                  isActive: trailState.isCreating,
                  tooltip: 'Record New Trail',
                  description:
                      'Start recording your travel path. Tap points to mark route.',
                ),
                const SizedBox(height: 12),
                // Add Waypoint
                _buildFloatingButton(Icons.add_location_alt, () {
                  final center = _mapController.camera.center;
                  showWaypointEditor(context, position: center);
                },
                    tooltip: 'Drop Pin Here',
                    description:
                        'Add a waypoint marker at the center of the screen'),
                const SizedBox(height: 12),
                // Camera / AR — opens live AR waypoint overlay with capture
                _buildFloatingButton(
                  Icons.camera_alt,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const ARCompassScreen()),
                    );
                  },
                  tooltip: 'AR Camera',
                  description:
                      'See your waypoints floating in AR through the camera',
                ),
                const SizedBox(height: 12),
                // Clear all waypoints
                _buildFloatingButton(Icons.delete_sweep, () {
                  _showClearWaypointsDialog(context);
                },
                    tooltip: 'Clear All Waypoints',
                    description: 'Delete all saved waypoints from the map'),
                const SizedBox(height: 12),
                // Measurement tool
                _buildFloatingButton(
                  _showMeasurementTool ? Icons.close : Icons.straighten,
                  () {
                    setState(
                        () => _showMeasurementTool = !_showMeasurementTool);
                    if (_showMeasurementTool) {
                      ref.read(aiAssistantProvider.notifier).speak(
                          "Measurement tool activated. Tap the map to measure distance, bearing, or area.");
                    }
                  },
                  isActive: _showMeasurementTool,
                  tooltip: _showMeasurementTool
                      ? 'Close Measure Tool'
                      : 'Measure Distance',
                  description: _showMeasurementTool
                      ? 'Close the measurement tool'
                      : 'Measure distance, area, and bearing between points',
                ),
                const SizedBox(height: 12),
                // Street View
                _buildFloatingButton(Icons.panorama, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => StreetViewScreen(
                              initialPosition: _mapController.camera.center,
                            )),
                  );
                },
                    tooltip: 'Street View',
                    description:
                        'View 360° panorama from this location (requires internet)'),
                const SizedBox(height: 12),
                // Search places
                _buildFloatingButton(Icons.place, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const PlacesSearchScreen()),
                  );
                },
                    tooltip: 'Search Places',
                    description:
                        'Search for towns, landmarks, and points of interest'),
                const SizedBox(height: 12),
                // Navigation
                _buildFloatingButton(Icons.directions, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const RouteOptionsScreen()),
                  );
                },
                    tooltip: 'Route Navigation',
                    description:
                        'Get turn-by-turn directions to any destination'),
                const SizedBox(height: 12),
                // SOS - with confirmation dialog for safety
                _buildFloatingButton(Icons.sos, () {
                  _showSOSConfirmation();
                },
                    tooltip: '🚨 SOS Emergency',
                    description:
                        'Broadcast emergency alert to all mesh nodes - USE ONLY IN EMERGENCY',
                    isAlert: true),
                const SizedBox(height: 12),
                // Settings
                _buildFloatingButton(Icons.settings, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const SettingsScreen()),
                  );
                },
                    tooltip: 'Settings',
                    description:
                        'Configure vehicle profile, privacy settings, and app preferences'),
                const SizedBox(height: 12),
                // Trip Statistics
                _buildFloatingButton(Icons.analytics, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const TripStatisticsScreen()),
                  );
                },
                    tooltip: 'Trip Statistics',
                    description:
                        'View distance traveled, time, speed stats, and export trip data'),
                const SizedBox(height: 12),
                // Coordinate Input
                _buildFloatingButton(Icons.pin_drop, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => CoordinateInputScreen(
                              onCoordinateEntered: (coords) {
                                _mapController.move(coords, 14.0);
                              },
                            )),
                  );
                },
                    tooltip: 'Enter Coordinates',
                    description:
                        'Enter GPS coordinates manually - decimal, DMS, or UTM format'),
                const SizedBox(height: 12),
                // AI Search
                _buildFloatingButton(Icons.search, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => NaturalLanguageSearchScreen(
                              onLocationFound: (coords) {
                                _mapController.move(coords, 14.0);
                              },
                            )),
                  );
                },
                    tooltip: 'AI Search',
                    description:
                        'Natural language search - try "nearest water" or "fuel under 50km"'),
              ],
            ),
          ),

          // Trail creation overlay
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
                    "Trail '$name' saved with ${trailState.draftPoints.length} points.");
              },
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

          // Bottom Sheet Overlay
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

          // Coordinate Display
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
    _meshController.dispose();
    super.dispose();
  }

  /// Opens a bottom sheet so the user can choose camera or selfie,
  /// then navigates to PhotoPinScreen to label and drop the pin.
  Future<void> _takePhotoAndDropPin(LocationState locationState) async {
    final lat = locationState.stats.currentLat;
    final lon = locationState.stats.currentLon;

    if (lat == null || lon == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Waiting for GPS fix — try again in a moment.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Let user pick camera or selfie
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF0D1A0D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PHOTO PIN',
                style: GoogleFonts.outfit(
                  color: const Color(0xFFE8A020),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Take a photo — a GPS pin drops automatically.',
                style: GoogleFonts.outfit(
                    color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 20),
              _CameraOption(
                icon: Icons.camera_alt,
                label: 'Camera',
                subtitle: 'Rear-facing camera',
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              const SizedBox(height: 12),
              _CameraOption(
                icon: Icons.camera_front,
                label: 'Selfie',
                subtitle: 'Front-facing camera',
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );

    if (source == null || !mounted) return;

    final location = LatLng(lat, lon);

    // Show loading while camera opens
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Opening camera...'),
          duration: Duration(seconds: 1),
          backgroundColor: Color(0xFF1B5E20),
        ),
      );
    }

    GeotaggedPhoto? photo;
    if (source == ImageSource.camera) {
      photo = await _photoService.takePhoto(
        location: location,
        altitude: locationState.stats.currentAltitude,
      );
    } else {
      // Selfie — use camera source, front camera handled by OS
      photo = await _photoService.takePhoto(
        location: location,
        altitude: locationState.stats.currentAltitude,
      );
    }

    if (photo == null || !mounted) return;

    // Navigate to confirm/label screen
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PhotoPinScreen(
          photo: photo!,
          location: location,
        ),
      ),
    );

    if (saved == true && mounted) {
      // Centre map on the new pin
      _mapController.move(location, 16.0);
    }
  }

  void _showSOSConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black.withOpacity(0.95),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Colors.red, size: 28),
            const SizedBox(width: 12),
            Text(
              '🚨 SOS ALERT',
              style: GoogleFonts.outfit(
                color: Colors.red,
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
              'This will broadcast your emergency location to all nearby BushTrack mesh nodes.',
              style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Text(
              'Your GPS coordinates will be sent with an emergency beacon.',
              style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12),
            ),
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
              ref.read(meshProvider.notifier).sendSOS();
              ref.read(aiAssistantProvider.notifier).speak(
                  "S.O.S. Beacon activated. Broadcasting position to all nearby mesh nodes. Stay calm. Help is on the way.");
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.sos, color: Colors.white),
                      const SizedBox(width: 12),
                      Text('SOS broadcasted!',
                          style: GoogleFonts.outfit(color: Colors.white)),
                    ],
                  ),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 5),
                ),
              );
            },
            child: Text('CONFIRM SOS',
                style: GoogleFonts.outfit(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _onMapTap(LatLng point, TrailState trailState) {
    // Handle measurement tool taps
    if (_showMeasurementTool && _measurementKey.currentState != null) {
      _measurementKey.currentState!.handleMapTap(point);
      return;
    }

    // Handle trail creation
    if (trailState.isCreating) {
      ref.read(trailProvider.notifier).addDraftPoint(point);
      ref
          .read(aiAssistantProvider.notifier)
          .speak("Point ${trailState.draftPoints.length + 1} added.");
      return;
    }
  }

  void _onMapLongPress(LatLng point) {
    setState(() => _targetPin = point);
    showWaypointEditor(context, position: point);
    ref
        .read(aiAssistantProvider.notifier)
        .speak("Pin dropped at this location. Adding waypoint details...");
  }

  List<Widget> _buildTrailLayers(TrailState trailState) {
    final layers = <Widget>[];

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

      // Add numbered markers for trail points
      layers.add(
        MarkerLayer(
          markers: [
            for (int i = 0; i < points.length; i++)
              Marker(
                point: points[i],
                width: 50,
                height: 50,
                child: _buildNumberedMarker(i + 1, color),
              ),
          ],
        ),
      );
    }

    // Other saved trails
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

  void _zoomToFitWaypoints(List<Waypoint> waypoints) {
    if (waypoints.isEmpty) return;

    final lats = waypoints.map((w) => w.latitude!).toList();
    final lons = waypoints.map((w) => w.longitude!).toList();

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
          '🌿 BUSHTRACK',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            shadows: [
              Shadow(
                color: AppColors.primaryOrange.withOpacity(0.5),
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
        tierColor = Colors.orange;
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
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.black.withOpacity(0.9),
            title: Text(
              '🤖 ANTIGRAVITY AI SYSTEMS',
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
        borderColor: tierColor.withOpacity(0.3),
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
                color: Colors.black.withOpacity(0.85),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: AppColors.primaryOrange.withOpacity(0.4)),
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
            ? const Color(0xFF7B2FFF).withOpacity(0.6)
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

// ── Camera option row for the bottom sheet ────────────────────

class _CameraOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _CameraOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF111F11),
          border: Border.all(color: const Color(0xFF2E4A2E)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFE8A020).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: const Color(0xFFE8A020), size: 22),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Icon(Icons.chevron_right,
                color: Colors.white.withOpacity(0.3), size: 20),
          ],
        ),
      ),
    );
  }
}
