import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:bush_track/theme/app_colors.dart';
import 'package:bush_track/theme/tactical_theme_constants.dart';
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
import 'package:bush_track/features/chat/presentation/ai_chat_screen.dart';
import 'package:bush_track/features/ai/providers/ai_control_provider.dart';
import 'package:bush_track/features/ai/presentation/camp_finder_screen.dart';
import 'package:bush_track/features/geofence/presentation/geofence_screen.dart';
import 'package:bush_track/features/ar/presentation/ar_compass_screen.dart';
import 'package:bush_track/features/map/widgets/waypoint_editor.dart';
import 'package:bush_track/features/map/presentation/photo_pin_screen.dart';
import 'package:bush_track/features/map/services/photo_geotagging_service.dart';
import 'package:bush_track/features/navigation/presentation/navigation_screen.dart';
import 'package:bush_track/features/navigation/presentation/route_options_screen.dart';
import 'package:bush_track/features/navigation/providers/navigation_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:bush_track/features/settings/presentation/settings_screen.dart';
import 'package:bush_track/core/config/secrets.dart';
import 'package:bush_track/core/services/gpx_service.dart';
import 'package:bush_track/core/models/trail.dart';

class HomeScreenLayout extends ConsumerStatefulWidget {
  const HomeScreenLayout({super.key});

  @override
  ConsumerState<HomeScreenLayout> createState() => _HomeScreenLayoutState();
}

// Map style enum
enum _MapStyle { streets, satellite, dark }

class _HomeScreenLayoutState extends ConsumerState<HomeScreenLayout> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final MapController _mapController = MapController();
  _MapStyle _mapStyle = _MapStyle.streets;
  double _currentZoom = 13.0;
  bool _mapInitialized = false;
  bool _tilesLoading = true;
  bool _hasAutocentered = false;
  LatLng? _targetPin;
  CoordinateFormat _coordinateFormat = CoordinateFormat.decimalDegrees;
  bool _showCoordinatePanel = false;
  final GlobalKey<MeasurementToolState> _measurementKey =
      GlobalKey<MeasurementToolState>();
  bool _showMeasurementTool = false;

  // Live compass heading (radians) from magnetometer
  double _headingRad = 0.0;
  StreamSubscription<MagnetometerEvent>? _magSub;

  @override
  void initState() {
    super.initState();
    // Show map immediately — no artificial delay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() { _mapInitialized = true; _tilesLoading = false; });
    });
    // Subscribe to magnetometer for compass + user-dot heading
    try {
      _magSub = magnetometerEvents.listen((event) {
        // Heading in radians clockwise from north
        final heading = math.atan2(event.x, event.y);
        if (mounted) setState(() => _headingRad = heading);
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _magSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locationState = ref.watch(locationProvider);
    final meshState = ref.watch(meshProvider);
    final trailState = ref.watch(trailProvider);
    ref.watch(aiAssistantProvider);
    ref.watch(aiControlProvider); // activates deadman switch monitoring

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
      key: _scaffoldKey,
      backgroundColor: kDarkBg,
      drawer: _buildDrawer(),
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
                  urlTemplate: _tileUrl(),
                  subdomains: AppSecrets.maptilerKey.isEmpty &&
                          _mapStyle == _MapStyle.streets
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
                // Breadcrumb trail — live GPS path
                if (locationState.breadcrumbs.length > 1)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: locationState.breadcrumbs
                            .where((b) =>
                                b.latitude != null && b.longitude != null)
                            .map((b) => LatLng(b.latitude!, b.longitude!))
                            .toList(),
                        color: const Color(0xFF00BFFF).withValues(alpha: 0.7),
                        strokeWidth: 2.5,
                      ),
                    ],
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
                            // Accuracy halo
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.blue.withValues(alpha: 0.4),
                                    width: 1.5),
                              ),
                            ),
                            // Blue dot
                            Container(
                              width: 18,
                              height: 18,
                              decoration: const BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.blueAccent,
                                      blurRadius: 8,
                                      spreadRadius: 3)
                                ],
                              ),
                            ),
                            // Bearing arrow rotates with magnetometer
                            Transform.rotate(
                              angle: _headingRad,
                              child: const Icon(Icons.navigation,
                                  color: Colors.white, size: 18),
                            ),
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
                            GestureDetector(
                              onTap: () => _showPinInfo(w, distLabel),
                              child: SizedBox(
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
                            )),
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
          // ── Top header bar ──────────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Row(
                  children: [
                    _headerButton(
                      Icons.menu,
                      () => _scaffoldKey.currentState?.openDrawer(),
                    ),
                    const Spacer(),
                    _headerButton(
                      Icons.camera_alt_outlined,
                      () => _openAR(),
                    ),
                    const SizedBox(width: 8),
                    _headerButton(
                      Icons.search,
                      () => _openSearch(),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // ── Right-side map controls ──────────────────────────────────────
          Positioned(
            right: 12,
            top: 120,
            child: Column(
              children: [
                _buildTacticalButton(_mapStyleIcon(), _cycleMapStyle),
                const SizedBox(height: 12),
                _buildTacticalButton(Icons.my_location, _centerOnUser),
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
            top: 120,
            left: 12,
            child: CompassRose(
              rotation: _headingRad,
              onTap: () => _mapController.rotate(0),
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

  // ── Header icon button ───────────────────────────────────────────────────
  Widget _headerButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }

  // ── Drawer ───────────────────────────────────────────────────────────────
  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF0A0A18),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(children: [
                const Icon(Icons.explore, color: Color(0xFFFF6D00), size: 28),
                const SizedBox(width: 10),
                const Text('PINAGE MAPS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                    )),
              ]),
            ),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 8),
            _drawerItem(Icons.sos_rounded, 'SOS Emergency', const Color(0xFFFF3B30),
                () { Navigator.pop(context); _sendSOS(); }),
            const Divider(color: Colors.white12, height: 24, indent: 16, endIndent: 16),
            _drawerItem(Icons.location_on_outlined, 'Saved Pins', Colors.white70,
                () { Navigator.pop(context); }),
            _drawerItem(Icons.route, 'My Trails', Colors.white70,
                () { Navigator.pop(context); }),
            _drawerItem(Icons.directions_outlined, 'Directions', Colors.white70,
                () { Navigator.pop(context);
                     Navigator.push(context, MaterialPageRoute(builder: (_) => const RouteOptionsScreen())); }),
            _drawerItem(Icons.reply_outlined, 'Return to Start', Colors.white70,
                () { Navigator.pop(context); _showReturnToStart(); }),
            _drawerItem(Icons.upload_file_outlined, 'Import GPX / KML', Colors.white70,
                () { Navigator.pop(context); _importGpxKml(); }),
            _drawerItem(Icons.near_me_outlined, 'Nearby Places', Colors.white70,
                () { Navigator.pop(context); _openSearch(); }),
            _drawerItem(Icons.chat_bubble_outline, 'AI Assistant', Colors.white70,
                () { Navigator.pop(context); _openChat(); }),
            _drawerItem(Icons.explore_outlined, 'AR Compass', Colors.white70,
                () { Navigator.pop(context); _openCompass(); }),
            _drawerItem(Icons.terrain_outlined, 'Camp Finder', Colors.white70,
                () { Navigator.pop(context);
                     Navigator.push(context, MaterialPageRoute(builder: (_) => const CampFinderScreen())); }),
            _drawerItem(Icons.location_searching_outlined, 'Geofences', Colors.white70,
                () { Navigator.pop(context);
                     Navigator.push(context, MaterialPageRoute(builder: (_) => const GeofenceScreen())); }),
            const Divider(color: Colors.white12, height: 24, indent: 16, endIndent: 16),
            _drawerItem(Icons.settings_outlined, 'Settings', Colors.white70,
                () { Navigator.pop(context);
                     Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())); }),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Text('Future Gen AI Pty Ltd',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.25),
                      fontSize: 11)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(IconData icon, String label, Color color, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: color, size: 22),
      title: Text(label,
          style: TextStyle(
              color: color, fontSize: 14, fontWeight: FontWeight.w500)),
      onTap: onTap,
      dense: true,
      horizontalTitleGap: 8,
    );
  }

  void _centerOnUser() {
    final loc = ref.read(locationProvider);
    if (loc.stats.currentLat != null) {
      _mapController.move(
        LatLng(loc.stats.currentLat!, loc.stats.currentLon!),
        15.0,
      );
    }
  }

  void _openAR() {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const ARCompassScreen()));
  }

  void _showReturnToStart() {
    final locState = ref.read(locationProvider);
    final crumbs = locState.breadcrumbs
        .where((b) => b.latitude != null && b.longitude != null)
        .toList();
    if (crumbs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No breadcrumb trail recorded yet'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    final start = LatLng(crumbs.first.latitude!, crumbs.first.longitude!);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ReturnToStartSheet(start: start),
    );
  }

  void _startNavigationTo(Waypoint w) {
    if (w.latitude == null || w.longitude == null) return;
    ref.read(aiAssistantProvider.notifier)
        .speak("Starting navigation to ${w.label ?? 'waypoint'}.");
    // Push screen first so spinner shows while OSRM responds
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const NavigationScreen()));
    ref.read(navigationProvider.notifier)
        .navigateTo(w.latitude!, w.longitude!, w.label ?? 'Waypoint');
  }

  Future<void> _importGpxKml() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['gpx', 'kml'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;
    final content = String.fromCharCodes(file.bytes!);
    if (content.isEmpty) return;
    final ext = (file.extension ?? '').toLowerCase();
    List<Waypoint> waypoints;
    if (ext == 'kml') {
      waypoints = GPXService.parseKML(content);
    } else {
      waypoints = GPXService.parseGPX(content);
    }
    for (final wp in waypoints) {
      await ref.read(locationProvider.notifier).addManualWaypoint(
            wp.latitude ?? 0,
            wp.longitude ?? 0,
            wp.label ?? 'Imported',
            notes: wp.notes,
          );
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Imported ${waypoints.length} pin(s) from ${file.name}'),
      duration: const Duration(seconds: 3),
    ));
  }

  Future<void> _openCameraPin(LatLng point) async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Camera pins require the mobile app'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    final loc = ref.read(locationProvider);
    final pinLocation = (loc.stats.currentLat != null)
        ? LatLng(loc.stats.currentLat!, loc.stats.currentLon!)
        : point;
    final svc = PhotoGeotaggingService();
    final photo = await svc.takePhoto(location: pinLocation);
    if (photo == null) return; // user cancelled
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PhotoPinScreen(photo: photo, location: pinLocation),
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
  /// Pass [trail] to enable share-as-GPX on tap.
  MarkerLayer _trailDistLabel(List<LatLng> pts, Color color, {Trail? trail}) {
    final total = _trailTotalDist(pts);
    final mid = pts[pts.length ~/ 2];
    return MarkerLayer(
      markers: [
        Marker(
          point: mid,
          width: 110,
          height: 26,
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: trail != null ? () => _shareTrailAsGpx(trail) : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 4),
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
                  if (trail != null) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.share, color: Colors.white70, size: 10),
                  ],
                ],
              ),
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
      if (points.length >= 2) {
        layers.add(_trailDistLabel(points, color,
            trail: trailState.activeTrail));
      }
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
        layers.add(_trailDistLabel(points, color.withValues(alpha: 0.8),
            trail: trail));
      }
    }

    return layers;
  }

  // ── Quick pin info sheet ─────────────────────────────────────────────────

  void _showPinInfo(Waypoint w, String? distLabel) {
    final color = WaypointColors.fromHex(w.color);
    final iconData = WaypointIcon.getIconData(w.icon);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0D1035),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.fromLTRB(
            20, 16, 20, MediaQuery.of(ctx).padding.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(iconData, color: color, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(w.label ?? 'Waypoint',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold)),
                      if (w.notes != null && w.notes!.isNotEmpty)
                        Text(w.notes!,
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.55),
                                fontSize: 12),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      if (w.latitude != null)
                        Text(
                            '${w.latitude!.toStringAsFixed(5)}, ${w.longitude!.toStringAsFixed(5)}',
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 11)),
                    ]),
              ),
              if (distLabel != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: color.withValues(alpha: 0.5), width: 1)),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.straighten, color: color, size: 14),
                    Text(distLabel,
                        style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ]),
                ),
            ]),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: _actionChip(ctx, Icons.edit_outlined, 'Edit', Colors.blue,
                    () => _editWaypoint(w)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _actionChip(
                    ctx,
                    Icons.navigation_outlined,
                    'Navigate',
                    Colors.green,
                    () => _startNavigationTo(w)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _actionChip(ctx, Icons.delete_outline, 'Delete',
                    Colors.red, () {
                  Navigator.pop(ctx);
                  ref.read(locationProvider.notifier).deleteWaypoint(w.id!);
                }),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _actionChip(BuildContext ctx, IconData icon, String label, Color color,
      VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(ctx);
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ]),
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
      ref.read(aiAssistantProvider.notifier).speak(
            "Point ${trailState.draftPoints.length + 1} added.",
          );
    }
  }

  void _onMapLongPress(LatLng point) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        decoration: const BoxDecoration(
          color: Color(0xFF0D1035),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Drop a pin here?',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: _pinOption(ctx, Icons.location_on_outlined, 'Drop Pin',
                    const Color(0xFF2196F3), () {
                  Navigator.pop(ctx);
                  showWaypointEditor(context, position: point);
                }),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _pinOption(ctx, Icons.camera_alt_outlined, 'Photo Pin',
                    const Color(0xFFFF9800), () {
                  Navigator.pop(ctx);
                  _openCameraPin(point);
                }),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _pinOption(BuildContext ctx, IconData icon, String label, Color color,
      VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  void _editWaypoint(Waypoint waypoint) {
    showWaypointEditor(context, waypoint: waypoint);
  }

  // ── Map style ────────────────────────────────────────────────────────────

  String _tileUrl() {
    final k = AppSecrets.maptilerKey;
    switch (_mapStyle) {
      case _MapStyle.satellite:
        return k.isNotEmpty
            ? 'https://api.maptiler.com/maps/satellite/{z}/{x}/{y}.jpg?key=$k'
            : 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
      case _MapStyle.dark:
        return k.isNotEmpty
            ? 'https://api.maptiler.com/maps/dataviz-dark/{z}/{x}/{y}.png?key=$k'
            : 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png';
      case _MapStyle.streets:
        return k.isNotEmpty
            ? 'https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key=$k'
            : 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png';
    }
  }

  IconData _mapStyleIcon() {
    switch (_mapStyle) {
      case _MapStyle.streets:
        return Icons.map;
      case _MapStyle.satellite:
        return Icons.satellite_alt;
      case _MapStyle.dark:
        return Icons.nightlight_round;
    }
  }

  void _cycleMapStyle() {
    setState(() {
      switch (_mapStyle) {
        case _MapStyle.streets:
          _mapStyle = _MapStyle.satellite;
          break;
        case _MapStyle.satellite:
          _mapStyle = _MapStyle.dark;
          break;
        case _MapStyle.dark:
          _mapStyle = _MapStyle.streets;
          break;
      }
    });
  }

  // ── GPX share ────────────────────────────────────────────────────────────

  Future<void> _shareTrailAsGpx(trail) async {
    try {
      final gpx = GPXService.exportTrail(trail);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${trail.name}.gpx');
      await file.writeAsString(gpx);
      final uri = Uri.parse('mailto:?subject=Trail: ${trail.name}'
          '&body=See attached GPX file: ${file.path}');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        // Fallback: open via file manager
        await launchUrl(Uri.file(file.path));
      }
    } catch (e) {
      debugPrint('GPX share error: $e');
    }
  }

  // ── Search & pin ─────────────────────────────────────────────────────────

  void _openSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PlacesSearchScreen()),
    );
  }

  void _openChat() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AIChatScreen()),
    );
  }

  void _openCompass() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ARCompassScreen()),
    );
  }

  void _sendSOS() {
    final locationState = ref.read(locationProvider);
    final lat = locationState.stats.currentLat;
    final lon = locationState.stats.currentLon;
    final hasLocation = lat != null && lon != null;
    final mapsLink = hasLocation
        ? 'https://maps.google.com/?q=$lat,$lon'
        : 'Location unknown';

    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Send SOS?', style: TextStyle(color: Colors.white)),
        content: Text(
          hasLocation
              ? 'Broadcasts SOS to nearby mesh nodes AND opens SMS with your location:\n$mapsLink'
              : 'Broadcasts SOS to nearby mesh nodes. (GPS not yet available)',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('SEND SOS',
                style: TextStyle(color: Color(0xFFFF3B30))),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true) {
        ref.read(meshProvider.notifier).sendSOS();
        ref.read(aiAssistantProvider.notifier).speak(
            'S.O.S. Beacon activated. Broadcasting position to all nearby mesh nodes.');
        // Also open SMS app pre-filled with location
        if (hasLocation) {
          final msg = Uri.encodeComponent(
              'EMERGENCY SOS — I need help!\nMy location: $mapsLink\n(BushTrack alert)');
          launchUrl(Uri.parse('sms:?body=$msg'),
              mode: LaunchMode.externalApplication);
        }
      }
    });
  }
}

// ── Return-to-Start live bearing sheet ───────────────────────────────────────

class _ReturnToStartSheet extends ConsumerStatefulWidget {
  final LatLng start;
  const _ReturnToStartSheet({required this.start});

  @override
  ConsumerState<_ReturnToStartSheet> createState() =>
      _ReturnToStartSheetState();
}

class _ReturnToStartSheetState extends ConsumerState<_ReturnToStartSheet> {
  double _bearingDeg = 0;
  double _distM = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _update();
  }

  void _update() {
    final loc = ref.read(locationProvider);
    final lat = loc.stats.currentLat;
    final lon = loc.stats.currentLon;
    if (lat == null || lon == null) return;
    final b = Geolocator.bearingBetween(lat, lon,
        widget.start.latitude, widget.start.longitude);
    final d = const Distance()(LatLng(lat, lon), widget.start);
    if (mounted) setState(() { _bearingDeg = b; _distM = d; });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<LocationState>(locationProvider, (_, __) => _update());
    final dist = _distM >= 1000
        ? '${(_distM / 1000).toStringAsFixed(2)} km'
        : '${_distM.toInt()} m';
    final cardinal = _cardinal(_bearingDeg);

    return Container(
      padding: EdgeInsets.fromLTRB(
          24, 20, 24, MediaQuery.of(context).padding.bottom + 24),
      decoration: const BoxDecoration(
        color: Color(0xFF0D1035),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(
          child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2))),
        ),
        const SizedBox(height: 16),
        const Text('RETURN TO START',
            style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 3)),
        const SizedBox(height: 24),
        Transform.rotate(
          angle: _bearingDeg * math.pi / 180,
          child: const Icon(Icons.navigation,
              color: Color(0xFFFF6D00), size: 72),
        ),
        const SizedBox(height: 16),
        Text('$cardinal  •  ${_bearingDeg.toStringAsFixed(0)}°',
            style: const TextStyle(
                color: Colors.white70, fontSize: 16, letterSpacing: 2)),
        const SizedBox(height: 8),
        Text(dist,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE',
                style: TextStyle(color: Colors.white38, fontSize: 13)),
          ),
        ),
      ]),
    );
  }

  String _cardinal(double deg) {
    const dirs = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    return dirs[((deg % 360) / 45).round() % 8];
  }
}
