import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'package:bush_track/core/services/heading/heading_provider.dart';
import 'package:bush_track/core/config/build_info.dart';
import 'package:bush_track/core/utils/startup_trace.dart';
import 'package:bush_track/main.dart' show databaseServiceProvider;
import 'package:bush_track/core/utils/web_helpers.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:mesh_gradient/mesh_gradient.dart';
import 'package:bush_track/core/widgets/glass_panel.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bush_track/features/map/widgets/immersive_3d_map.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as mgl;
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' show Client;
import 'package:http/retry.dart' show RetryClient;
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bush_track/theme/app_colors.dart';
import 'widgets/mesh_bottom_sheet.dart';
import 'widgets/sos_hold_button.dart';
import '../../tracking/providers/location_provider.dart';
import '../../tracking/providers/track_target_provider.dart';
import '../../mesh/providers/mesh_provider.dart';
import 'package:bush_track/core/models/mesh_packet.dart';
import 'package:bush_track/features/ai/providers/ai_control_provider.dart';
import '../../ai/providers/ai_assistant_provider.dart';
import 'package:bush_track/features/ai/services/ai_monitor_service.dart';
import 'package:bush_track/core/models/geofence.dart';
import 'package:bush_track/core/utils/geo_geometry.dart'
    show formatArea, formatDistance;
import 'package:bush_track/features/geofence/presentation/geofence_screen.dart';
import 'package:bush_track/features/geofence/presentation/zone_drawing.dart';
import 'package:bush_track/features/drawing/models/drawing.dart';
import 'package:bush_track/features/drawing/presentation/line_drawing.dart';
import 'package:bush_track/features/drawing/presentation/freehand_drawing.dart';
import 'package:bush_track/features/drawing/presentation/pen_picker.dart';
import 'package:bush_track/features/drawing/services/freehand.dart';
import 'package:bush_track/features/drawing/providers/drawings_provider.dart';
import 'package:bush_track/features/drawing/services/line_geometry.dart';
import 'package:bush_track/features/geofence/providers/geofence_provider.dart';
import 'package:bush_track/features/chat/presentation/ai_chat_screen.dart'
    show showAIChat;
import 'package:bush_track/features/files/presentation/files_screen.dart';
import 'package:bush_track/features/files/providers/files_provider.dart';
import 'package:bush_track/features/gallery/presentation/photo_gallery_screen.dart';
import 'widgets/ai_voice_overlay.dart';
import '../../mesh/providers/mesh_sync_provider.dart';
import 'package:bush_track/features/weather/widgets/weather_overlay.dart';
import 'package:bush_track/features/places/presentation/places_search_screen.dart';
import 'package:bush_track/features/navigation/presentation/route_options_screen.dart';
import 'package:bush_track/features/navigation/providers/navigation_provider.dart';
import 'package:bush_track/features/map/presentation/marker_picker_screen.dart';
import 'package:bush_track/features/map/providers/map_action_provider.dart';
import 'package:bush_track/features/map/providers/marker_visibility_provider.dart';
import 'package:bush_track/features/map/providers/satellite_source_provider.dart';
import 'package:bush_track/core/providers/outbox_provider.dart';
import 'package:bush_track/features/dashboard/providers/sheet_metrics_provider.dart';
import 'package:bush_track/features/map/widgets/connectivity_pill.dart';
import 'package:bush_track/features/streetview/presentation/street_photo_viewer.dart';
import 'package:bush_track/features/streetview/providers/mapillary_provider.dart';
import 'package:bush_track/features/map/services/locate_mode.dart';
import 'package:bush_track/features/map/services/travel_heading.dart';
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
import 'package:bush_track/features/map/services/offline_first_tile_provider.dart';
import 'package:bush_track/features/map/services/offline_map_manager.dart';
import 'package:bush_track/features/map/widgets/compass_rose.dart';
import 'package:bush_track/features/map/widgets/scale_bar.dart';
import 'package:bush_track/features/map/widgets/map_loading_indicator.dart';
import 'package:bush_track/features/map/widgets/waypoint_marker.dart';
import 'package:bush_track/features/map/widgets/waypoint_editor.dart';
import 'package:bush_track/features/map/widgets/trail_creation_overlay.dart';
import 'package:bush_track/features/map/providers/trail_provider.dart';
import 'package:bush_track/core/models/breadcrumb.dart';
import 'package:bush_track/core/models/field_file.dart';
import 'package:bush_track/core/models/waypoint.dart';
import 'package:bush_track/core/models/trail.dart';
import 'package:bush_track/features/ai/presentation/agent_manager_screen.dart';
import 'package:bush_track/features/map/presentation/offline_maps_screen.dart';
import 'package:bush_track/features/map/widgets/pinage_chooser.dart';
import 'package:bush_track/features/map/widgets/pinage_editor.dart';
import 'package:bush_track/features/map/widgets/pinage_viewer.dart';
import 'package:bush_track/core/services/tile_cache.dart';

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

  /// What the locate button is doing. See locate_mode.dart for the cycle.
  LocateMode _locateMode = LocateMode.off;

  /// Which way to point the arrow: GPS course while moving, compass while
  /// stopped. See travel_heading.dart.
  final TravelHeading _travel = TravelHeading();
  double? _travelHeadingDeg;
  DateTime? _lastTravelSample;
  final GlobalKey _screenshotKey = GlobalKey();

  // Map style: 0=Street, 1=Satellite, 2=Dark, 3=Topo
  int _mapStyleIndex = 0;
  // Index 0 is whichever satellite source is selected — see
  // satellite_source_provider. It is a setting rather than a fourth style so
  // the comparison is like-for-like: the same slot, the same zoom, swapped
  // underneath while you stand in one place.
  //
  // Deliberately NOT wired into the offline downloader. Mapbox imagery may
  // only be cached through their own SDK, so bulk-downloading it here would
  // breach their terms; offline regions stay on the existing sources.
  static const _tileUrls = [
    // 0 — placeholder, replaced at build time by the selected source
    '',
    // 1 — Topo: OpenTopoMap — elevation contours, great for bush navigation
    'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png',
    // 2 — Street: OpenStreetMap — standard, no API key needed
    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  ];
  // Highest zoom each source actually has imagery for. Past this flutter_map
  // enlarges the last real tile instead of requesting a new one.
  //
  // ESRI was 19. Probed Sept 2026: around Leonora (town included) and across
  // remote WA — Gibson, Great Victoria Desert, Nullarbor, Pilbara, Kimberley,
  // Laverton, Wiluna — ESRI has real imagery to z17 everywhere, but at z18
  // and z19 it returns the same 2 KB grey tile reading "Map data not yet
  // available" (HTTP 200, so errorTileCallback never fires). Zooming in past
  // 17 filled the screen with that watermark.
  static const _tileMaxNativeZoom = [17, 17, 19];
  static const _tileNames = ['Satellite', 'Topo', 'Street'];
  static const _tileIcons = [
    Icons.satellite_alt,
    Icons.terrain,
    Icons.map,
  ];

  LatLng? _targetPin;

  /// Pin being tracked: live distance, direction and a compass arrow.
  Waypoint? _trackedPin;

  /// Whatever is being tracked — a pin or a zone. The map line, the
  /// heads-up panel and the AR ground track all read this rather than
  /// the pin, so a zone is a destination like any other.
  TrackTarget? get _trackTarget => ref.read(trackTargetProvider);

  // Map state
  bool _mapInitialized = false;
  bool _tilesLoading = true;
  bool _hasAutocentered = false;
  double _currentZoom = 13.0;

  // NEW: Measurement tool
  final GlobalKey<MeasurementToolState> _measurementKey =
      GlobalKey<MeasurementToolState>();
  bool _showMeasurementTool = false;

  /// The zone being drawn, or null when not drawing. Held here because the
  /// corners come from taps on the map.
  ZoneDraft? _zoneDraft;

  /// The line being drawn or edited (Phase 4.2), or null when not drawing.
  LineDraft? _lineDraft;

  /// The saved drawing being edited, so saving updates it rather than adding
  /// a second copy on top of it.
  Drawing? _editingDrawing;

  /// What the last tap snapped to, so the panel can say so.
  String? _lineSnappedTo;

  /// A freehand drawing session, or null.
  FreehandSession? _freehand;

  /// The line tool's pen. Kept between lines, so a run of fences drawn in
  /// one colour does not need the colour picked each time.
  String _lineColour = '#FF6B00';
  double _lineWidth = 4;

  /// The map's own coordinate space, for turning a finger position on screen
  /// back into a position on the ground while dragging a zone bigger.
  final GlobalKey _mapAreaKey = GlobalKey();

  /// Tiles that survive a flaky connection.
  ///
  /// Retries on ANY failure, not just 503: out here the failure is a dropped
  /// connection or a name that would not resolve, and those are exactly the
  /// ones worth trying again. Backs off so a genuinely offline phone is not
  /// hammering the radio and flattening the battery.
  /// Offline-first providers, one per imagery source, built once each.
  ///
  /// Must not be rebuilt per frame: this screen's build runs roughly once a
  /// second off the heading stream, and a fresh TileProvider instance makes
  /// flutter_map re-fetch every tile on screen. That is the same reason
  /// [_retryingTileProvider] is a field.
  final Map<MapStyle, TileProvider> _offlineFirstProviders = {};

  /// Same reason, for the downloaded-only layer drawn underneath.
  final Map<MapStyle, TileProvider> _underlayProviders = {};

  /// Last value logged, so the diagnostic fires on change rather than per frame.
  MapStyle? _loggedOfflineStyle;
  bool _loggedOfflineStyleOnce = false;

  /// Wraps the network provider so a downloaded tile is used before the
  /// network. Null style -- no downloadable source serves this exact layer --
  /// gives the plain network provider back.
  TileProvider _tileProviderFor(MapStyle? style) {
    final network = TileCache.instance.ready ?? _retryingTileProvider;
    if (style == null) return network;
    return _offlineFirstProviders.putIfAbsent(
      style,
      () => OfflineFirstTileProvider(fallback: network, style: style),
    );
  }

  late final _retryingTileProvider = NetworkTileProvider(
    httpClient: RetryClient(
      Client(),
      // Patient enough to outlast wifi associating after a cold start:
      // 0.5 + 1 + 2 + 4 + 8 seconds. The tile failures seen at launch were
      // all in the first few seconds while the radio was still coming up.
      retries: 5,
      when: (response) => response.statusCode >= 500,
      whenError: (_, __) => true,
      delay: (attempt) => Duration(milliseconds: 500 * (1 << attempt)),
    ),
  );

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
  }

  Future<void> _initializeServices() async {
    await _photoService.initialize();
    await _offlineMapManager.initialize();
  }

  void _setupMapListeners() {
    StartupTrace.mark('dashboard_build');
    // Mark map as initialized immediately — tile loading state is managed by TileLayer itself
    WidgetsBinding.instance.addPostFrameCallback((_) {
      StartupTrace.mark('dashboard_first_frame');
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
              onTap: () =>
                  ref.read(navigationProvider.notifier).stopNavigation(),
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
                onTap: () =>
                    ref.read(navigationProvider.notifier).previousStep(),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
    final geofenceState = ref.watch(geofenceProvider);

    // Auto-center map on first real GPS fix
    ref.listen<LocationState>(locationProvider, (_, next) {
      _checkTrackingArrival(next);
      _updateTravelHeading(next);
      if (!_hasAutocentered &&
          next.stats.currentLat != null &&
          next.stats.currentLon != null) {
        _hasAutocentered = true;
        _mapController.move(
          LatLng(next.stats.currentLat!, next.stats.currentLon!),
          15.0,
        );
      }
      _followIfAsked(next);
    });

    // Execute pending AI map actions
    // Another phone's SOS arrived over the mesh. Before this nothing on the
    // receiving phone reacted at all — the packet was filed away silently.
    ref.listen<MeshState>(meshProvider, (prev, next) {
      final sos = next.lastIncomingSos;
      if (sos == null || sos.id == prev?.lastIncomingSos?.id) return;
      _showIncomingSos(sos);
    });

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
    // Hidden markers are still saved — they just stop being drawn, so a
    // busy map can be narrowed to whatever the job actually is.
    final visibility = ref.watch(markerVisibilityProvider);
    final pinWaypoints = locationState.waypoints
        .where((w) => w.isPin == true || w.type == WaypointType.manual)
        .where((w) => visibility.showsPin(id: w.id, fileId: w.fileId))
        .toList();

    final streetView = ref.watch(streetViewProvider);

    // Where the bottom sheet currently is, so the right-hand controls can sit
    // above it instead of guessing. Every one of them used a hardcoded
    // `bottom:` picked by eye on one handset, which is how the compass ended up
    // half under the sheet on a phone whose navigation bar is a different
    // height.
    final systemInset = MediaQuery.of(context).viewPadding.bottom;
    final sheetHeight = ref.watch(sheetHeightProvider);
    final screenHeight = MediaQuery.of(context).size.height;
    final stackBase = controlsBottom(sheetHeight, systemInset);
    final hideStack = hideControlsFor(sheetHeight, screenHeight);

    // Stacked upward from the sheet: attribution, then compass, then locate.
    // Sizes are the widgets' own, so the gaps hold at any text scale.
    // Downloaded imagery drawn under a layer that has no offline copy of its
    // own (Mapbox), so that with no signal the download shows through instead
    // of blank squares -- without the user switching layers by hand. Read off
    // the phone only; see DownloadedOnlyTileProvider.
    final satelliteNow = ref.watch(satelliteSourceProvider);
    final layerUrl = _mapStyleIndex == 0
        ? satelliteNow.urlTemplate
        : _tileUrls[_mapStyleIndex];
    final underlay = kIsWeb ||
            OfflineMapManager.styleServing(layerUrl) != null
        ? null
        : OfflineMapManager().underlayStyle(imagery: _mapStyleIndex == 0);
    // Its licence wants the credit wherever it is seen. Online the layer above
    // covers it; offline it is what is on screen, so it gets a line of its own.
    final creditUnderlay =
        underlay != null && !ref.watch(connectivityProvider).isConnected;
    final attributionHeight = creditUnderlay ? 28.0 : 16.0;
    const compassSize = 60.0;
    const locateSize = 52.0;
    final attributionBottom = stackBase;
    final compassBottom = attributionBottom + attributionHeight + 6;
    final locateBottom = compassBottom + compassSize + 8;

    // The satellite slot is swapped by setting; the other two are fixed.
    final satellite = satelliteNow;
    final baseTileUrl = layerUrl;
    final maxNativeZoom = _mapStyleIndex == 0
        ? satellite.maxNativeZoom
        : _tileMaxNativeZoom[_mapStyleIndex];
    // Matched on the exact template, so the tiles on disk are guaranteed to be
    // the same imagery from the same provider as the layer being drawn.
    final offlineStyle = OfflineMapManager.styleServing(baseTileUrl);
    // Logged only when it changes, not every frame: this build runs about once
    // a second. Says whether the layer on screen has an offline source at all,
    // which is the other half of diagnosing a blank map with no signal.
    // The "once" flag matters: null is both the initial value and the most
    // important case to report, so comparing against it alone would stay silent
    // exactly when the layer has no offline source.
    if (!_loggedOfflineStyleOnce || offlineStyle != _loggedOfflineStyle) {
      _loggedOfflineStyleOnce = true;
      _loggedOfflineStyle = offlineStyle;
      // Query string dropped: it carries the access token.
      debugPrint('Offline: layer ${baseTileUrl.split('?').first} -> '
          '${offlineStyle == null ? 'NO offline source' : 'served by ${offlineStyle.name}'}');
    }

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
                      key: _mapAreaKey,
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: locationState.stats.currentLat != null
                            ? LatLng(locationState.stats.currentLat!,
                                locationState.stats.currentLon!)
                            : const LatLng(
                                -25.3444, 131.0369), // centre of Australia
                        // No fix: show the whole country so it's obvious we
                        // haven't located you. It used to open zoomed into
                        // Uluru at street level, which reads as "you are
                        // here". The first fix zooms to 15 (see listener).
                        initialZoom: locationState.stats.currentLat != null
                            ? _currentZoom
                            : 4.0,
                        minZoom: 3.0,
                        maxZoom: 19.0,
                        interactionOptions: const InteractionOptions(
                          enableScrollWheel: true,
                          flags: InteractiveFlag.all,
                        ),
                        onTap: (tapPosition, point) {
                          // With the layer on, a tap means "show me the
                          // street here" — otherwise it does what it always
                          // did.
                          if (ref.read(streetViewProvider).enabled) {
                            _openStreetPhoto(point);
                            return;
                          }
                          _onMapTap(point, trailState);
                        },
                        onLongPress: (tapPosition, point) =>
                            _onMapLongPress(point),
                        onPositionChanged: (position, hasGesture) {
                          _loadStreetCoverage(position);
                          setState(() {
                            _currentZoom = position.zoom ?? 13.0;
                            // Reaching for the map means "stop pulling me
                            // back". Only a real gesture counts: following
                            // moves the map itself, and that must not cancel
                            // itself on the next frame.
                            if (hasGesture && _locateMode.isFollowing) {
                              _locateMode = _locateMode.afterPan;
                            }
                          });
                        },
                      ),
                      children: [
                        if (underlay != null)
                          TileLayer(
                            // Required by TileLayer, never requested: the
                            // provider reads downloaded files and nothing else.
                            urlTemplate: underlay.urlTemplate,
                            tileProvider: _underlayProviders.putIfAbsent(
                                underlay,
                                () => DownloadedOnlyTileProvider(
                                    style: underlay)),
                            maxZoom: 19.0,
                            maxNativeZoom: underlay.maxUsefulZoom,
                            minZoom: 3.0,
                            tileSize: 256,
                            panBuffer: 1,
                            keepBuffer: 8,
                          ),
                        // Tile layer with OpenStreetMap
                        TileLayer(
                          urlTemplate: baseTileUrl,
                          // OpenStreetMap's tile policy rejects clients that
                          // do not identify themselves — without this their
                          // server returns 403 and the style shows "access
                          // blocked". OpenTopoMap asks for the same thing.
                          userAgentPackageName: 'au.com.futuregenai.pinagemaps',
                          // flutter_map already wraps tiles in a RetryClient,
                          // but its default only retries HTTP 503 — a DNS or
                          // socket failure is not retried at all. So one blip
                          // as the app opens leaves those tiles permanently
                          // blank, which reads as "the map never loaded".
                          // The caching provider where one could be set up,
                          // the retrying one otherwise. Resolved during
                          // startup so this is settled on the first frame:
                          // changing it later re-fetches every visible tile.
                          tileProvider: _tileProviderFor(offlineStyle),
                          // OpenTopoMap uses {s} subdomain rotation
                          subdomains: _mapStyleIndex == 1
                              ? const ['a', 'b', 'c']
                              : const [],
                          maxZoom: 19.0,
                          maxNativeZoom: maxNativeZoom,
                          minZoom: 3.0,
                          tileSize: 256,
                          // Only where the provider serves a retina tile
                          // itself, which is what {r} in the template means.
                          // Without it, flutter_map *simulates* retina: it
                          // adds 1 to zoomOffset, takes 1 off maxNativeZoom
                          // and fetches four tiles per displayed tile. That
                          // quadruples data use on a metered phone, and it
                          // shifts the zoom levels being requested away from
                          // the ones an offline region actually downloaded --
                          // so a correct region still misses.
                          retinaMode: baseTileUrl.contains('{r}') &&
                              RetinaMode.isHighDensity(context),
                          // Tiles fetched beyond the viewport. Was 3, which
                          // pre-loads three rings of tiles that may never be
                          // looked at — free against Esri and OSM, billed per
                          // request against Mapbox. 1 is the library default
                          // and still smooths a pan.
                          panBuffer: 1,
                          // Tiles KEPT once fetched, which is the opposite: it
                          // costs nothing and avoids re-fetching ground you
                          // have already paid for when panning back. Generous
                          // on purpose.
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
                        ..._buildTrailLayers(
                            trailState, locationState, navState),
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
                        // Line from you to the pin being tracked.
                        if (_trackTarget != null &&
                            locationState.stats.currentLat != null &&
                            locationState.stats.currentLon != null)
                          PolylineLayer(polylines: [
                            Polyline(
                              points: [
                                LatLng(locationState.stats.currentLat!,
                                    locationState.stats.currentLon!),
                                _trackTarget!.position,
                              ],
                              color: const Color(0xFF4CAF50),
                              strokeWidth: 3,
                              isDotted: true,
                            ),
                          ]),
                        // Waypoint markers with interaction
                        // Mapillary coverage, under everything of the
                        // user's own: it is context, not content.
                        if (streetView.enabled && streetView.photos.isNotEmpty)
                          CircleLayer(
                            circles: [
                              for (final photo in streetView.photos)
                                CircleMarker(
                                  point: photo.position,
                                  radius: 3.5,
                                  color: const Color(0xFF05CB63)
                                      .withValues(alpha: 0.85),
                                  borderColor:
                                      Colors.white.withValues(alpha: 0.5),
                                  borderStrokeWidth: 0.5,
                                ),
                            ],
                          ),

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
                                // Left to rotate with the map on purpose. The
                                // marker's own space is already turned by the
                                // map's rotation, so rotating the arrow by the
                                // true bearing puts it at bearing + rotation on
                                // screen — correct in north-up, and pointing
                                // straight up in heading-up, with no second
                                // correction to keep in step.
                                child: _userArrow(),
                              ),
                            // Pin Waypoints with interaction + live distance
                            ...pinWaypoints.map((w) {
                              final wPos =
                                  LatLng(w.latitude ?? 0.0, w.longitude ?? 0.0);
                              final userLat = locationState.stats.currentLat;
                              final userLon = locationState.stats.currentLon;
                              final distLabel = (userLat != null &&
                                      userLon != null)
                                  ? _fmtDist(
                                      _distM(LatLng(userLat, userLon), wPos))
                                  : null;
                              return Marker(
                                point: wPos,
                                width: 78,
                                height: 78,
                                // The whole marker sits ABOVE the point, so the
                                // pin's tip is on the coordinate and the chip
                                // is above it. flutter_map 6: "topCenter means
                                // the entire marker is located above the
                                // point". This was bottomCenter (9822c36),
                                // which drew every pin entirely BELOW its real
                                // spot — ~60 px, about 280 m at zoom 15.
                                alignment: Alignment.topCenter,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (distLabel != null)
                                      _distanceChip(distLabel),
                                    const SizedBox(height: 2),
                                    SizedBox(
                                      width: 50,
                                      height: 50,
                                      child: WaypointMarker(
                                        waypoint: w,
                                        distanceInfo: _pinDistanceInfo(w),
                                        onEdit: () => w.isPinage
                                            ? _showPinageViewer(w)
                                            : _editWaypoint(w),
                                        onDelete: () => ref
                                            .read(locationProvider.notifier)
                                            .deleteWaypoint(w.id!),
                                        onColorChanged: (color) => ref
                                            .read(locationProvider.notifier)
                                            .updateWaypointColor(w.id!, color),
                                        onIconChanged: (icon) => ref
                                            .read(locationProvider.notifier)
                                            .updateWaypointIcon(w.id!, icon),
                                        // Used to only speak "Setting
                                        // navigation target" and stop there.
                                        onNavigate: () => _startTracking(w),
                                      ),
                                    ),
                                  ],
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
                        // Saved zones, and whatever is being drawn. Under the
                        // pins and the user's own marker so a boundary never
                        // hides them.
                        ...buildZoneMapLayers(
                          zones: geofenceState.geofences
                              .where((z) => visibility.showsZone(
                                  id: z.id, fileId: z.fileId))
                              .toList(),
                          insideIds: geofenceState.insideIds,
                          draft: _zoneDraft,
                          showLabels: _currentZoom >= 11,
                          onRadiusDragTo: _resizeZoneDraftTo,
                        ),

                        // Drawings (4.2): above zones, under the pins.
                        ...buildDrawingMapLayers(
                          drawings: ref
                              .watch(drawingsProvider)
                              .where((d) =>
                                  visibility.showsDrawing(fileId: d.fileId))
                              .toList(),
                          draft: _lineDraft,
                          editingId: _editingDrawing?.id,
                          showLabels: _currentZoom >= 13,
                          draftColour: _lineColour,
                          draftWidth: _lineWidth,
                        ),
                        ...buildFreehandLayers(_freehand),

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
                            // SOS packets used to carry no position, and this
                            // did packet.latitude! — so receiving an SOS threw
                            // during the map build. Skip positionless packets.
                            markers: meshState.peerLocations.values
                                .where((p) =>
                                    p.latitude != null && p.longitude != null)
                                .map((packet) {
                              final isSos = packet.packetType == 'sos';
                              return Marker(
                                point:
                                    LatLng(packet.latitude!, packet.longitude!),
                                width: isSos ? 52 : 40,
                                height: isSos ? 52 : 40,
                                child: Icon(
                                    isSos ? Icons.sos : Icons.person_pin_circle,
                                    color: isSos
                                        ? AppColors.statusRed
                                        : AppColors.statusBlue,
                                    size: isSos ? 52 : 40),
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

          // Freehand: while Draw is on, a finger on the map is a stroke, not a
          // pan. Sits directly above the map and under every control, so
          // nothing else on screen -- SOS above all -- is ever covered by it.
          if (_freehand != null && _freehand!.drawing && !_is3DMode)
            Positioned.fill(
              child: GestureDetector(
                key: const ValueKey('freehand-canvas'),
                behavior: HitTestBehavior.opaque,
                onPanStart: (d) => _freehandAt(d.globalPosition, start: true),
                onPanUpdate: (d) => _freehandAt(d.globalPosition),
                onPanEnd: (_) => _endFreehandStroke(),
                onPanCancel: () => setState(() => _freehand?.cancelStroke()),
              ),
            ),

          // The line's points and + buttons, above the map. As markers inside
          // it, a drag that began on a point moved the whole map instead (seen
          // on the phone). Up here a touch on a handle never reaches the map;
          // a touch anywhere else falls through to it as before.
          if (_lineDraft != null && _mapInitialized && !_is3DMode)
            Positioned.fill(
              child: LineHandles(
                vertices: [
                  for (final p in _lineDraft!.points)
                    mapOffsetOf(_mapController.camera, p),
                ],
                midpoints: [
                  for (final m in _lineDraft!.midpoints)
                    mapOffsetOf(_mapController.camera, m),
                ],
                onDragTo: _dragLineVertex,
                onDragEnd: _endLineVertexDrag,
                onRemove: (i) => setState(() {
                  _lineDraft?.remove(i);
                  _lineSnappedTo = null;
                }),
                onInsert: _insertLineVertex,
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

          // Floating top buttons — no background bar, sit directly over the map
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 14,
            right: 14,
            child: LayoutBuilder(
              builder: (context, constraints) {
                // The wide bar needs ~840px of content width. The old 480
                // breakpoint meant every width between 480 and ~865 rendered
                // the wide bar and clipped it — tablets, and any desktop
                // browser that isn't maximised. Phones (<480) were unaffected,
                // so it never showed up in field testing.
                final compact = constraints.maxWidth < 860;

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
                          color:
                              const Color(0xFFFF8C00).withValues(alpha: 0.65),
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
                  onTap: _openCamera,
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

                // Files button. Glows when a file is open, because anything
                // dropped while one is open gets filed under it and that
                // needs to be visible without opening a menu.
                final hasOpenFile =
                    ref.watch(filesProvider).activeFileId != null;
                final files = GestureDetector(
                  onTap: _showFiles,
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      // Brown, so the three buttons read apart at a glance.
                      // An open file keeps the brown but gains a lit rim and
                      // an open-folder icon — that state has to stay obvious,
                      // because everything dropped is being filed under it.
                      gradient: const LinearGradient(
                        colors: [Color(0xFFA9744F), Color(0xFF5D4037)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: hasOpenFile
                              ? AppColors.accentLight
                              : Colors.white.withValues(alpha: 0.18),
                          width: hasOpenFile ? 2 : 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: hasOpenFile
                              ? AppColors.accent.withValues(alpha: 0.5)
                              : Colors.black.withValues(alpha: 0.35),
                          blurRadius: hasOpenFile ? 18 : 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                        hasOpenFile
                            ? Icons.folder_open_rounded
                            : Icons.folder_rounded,
                        color: Colors.white,
                        size: 26),
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
                      // Green, matching the brown folder and purple camera as
                      // three distinguishable buttons rather than three greys.
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4CAF50), Color(0xFF1B5E20)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2E7D32).withValues(alpha: 0.5),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.search_rounded,
                        color: Colors.white, size: 26),
                  ),
                );

                if (compact) {
                  return Row(children: [
                    hamburger,
                    const Spacer(),
                    files,
                    const SizedBox(width: 8),
                    camera,
                    const SizedBox(width: 8),
                    search,
                  ]);
                }

                // Wide (tablet / desktop): full pill bar with branding
                return Row(children: [
                  hamburger,
                  const SizedBox(width: 12),
                  // Flexible so a large system font scale shrinks the branding
                  // instead of overflowing the bar again.
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        ShaderMask(
                          shaderCallback: (b) =>
                              AppColors.accentGradient.createShader(b),
                          child: const Icon(Icons.explore,
                              color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'BUSHTRACK',
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF7B2FFF).withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                                color: const Color(0xFF7B2FFF)
                                    .withValues(alpha: 0.45)),
                          ),
                          child: const Text('v3.0',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(width: 10),
                  files,
                  const SizedBox(width: 8),
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

          // Compass Rose — bottom right, out of the way of the top-of-screen
          // panels (pin tracking, navigation) and clear of the scale bar,
          // coordinates and breadcrumb buttons, which all sit left/centre.
          // Locate button, above the compass, above the sheet.
          if (!hideStack)
            Positioned(
              bottom: locateBottom,
              right: 18,
              child: _locateButton(locationState),
            ),

          if (!hideStack)
            Positioned(
              bottom: compassBottom,
              right: 14,
              child: Consumer(
                builder: (context, ref, _) {
                  final heading = ref.watch(headingProvider).valueOrNull ??
                      const HeadingReading.unavailable();
                  return CompassRose(
                    rotation: heading.isLive ? heading.radians : 0.0,
                    quality: heading.quality,
                    onTap: () async {
                      if (!heading.isLive) {
                        await requestHeadingPermission(ref);
                      }
                      _mapController.rotate(0);
                    },
                  );
                },
              ),
            ),

          // SOS — always on the map, directly under the search button. Spec §1
          // took it off the main screen; the BHP bug brief then found it
          // effectively missing (bottom of the drawer, and on the live build
          // hidden under the mesh sheet). A true 3 s hold stops pocket-fires.
          Positioned(
            top: MediaQuery.of(context).padding.top + 76,
            right: 14,
            child: SosHoldButton(onTriggered: _showSOSConfirmation),
          ),

          if (_trackTarget != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 146,
              left: 14,
              right: 14,
              child: Consumer(
                builder: (context, ref, _) => _buildTrackingHud(ref),
              ),
            ),

          // Weather sits under the bottom sheet (so an expanded sheet covers it)
          // and steps aside while the tracking or navigation panels are up.
          if (_trackTarget == null && !navState.isActive)
            const WeatherOverlay(),

          // Scale Bar (Bottom Left, above coordinate display)
          if (!hideStack)
            Positioned(
              bottom: stackBase + 108,
              left: 20,
              child: ScaleBar(
                zoom: _currentZoom,
                latitude: locationState.stats.currentLat ?? -25.3444,
              ),
            ),

          // Trail creation overlay — minimal floating bar
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
                        final crumbs = ref
                            .read(locationProvider)
                            .breadcrumbs
                            .where((b) =>
                                b.latitude != null && b.longitude != null)
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
                          CameraFit.bounds(
                              bounds: bounds,
                              padding: const EdgeInsets.all(48)),
                        );
                        ref.read(aiAssistantProvider.notifier).speak(_isRetracing
                            ? "Retrace mode on. Follow the cyan trail back to start."
                            : "Retrace mode off.");
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 12),
                        decoration: BoxDecoration(
                          color: _isRetracing
                              ? AppColors.statusBlue.withValues(alpha: 0.9)
                              : AppColors.panelMatte.withValues(alpha: 0.92),
                          borderRadius: const BorderRadius.horizontal(
                              left: Radius.circular(30)),
                          boxShadow: const [
                            BoxShadow(color: Colors.black45, blurRadius: 6)
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.undo,
                                color:
                                    _isRetracing ? Colors.black : Colors.white,
                                size: 20),
                            const SizedBox(width: 6),
                            Text(
                              _isRetracing ? 'RETRACING' : 'RETRACE',
                              style: TextStyle(
                                color:
                                    _isRetracing ? Colors.black : Colors.white,
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
                        setState(() {
                          _isRetracing = false;
                        });
                        ref.read(locationProvider.notifier).clearBreadcrumbs();
                        ref
                            .read(aiAssistantProvider.notifier)
                            .speak("Trail cleared.");
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade800.withValues(alpha: 0.92),
                          borderRadius: const BorderRadius.horizontal(
                              right: Radius.circular(30)),
                          boxShadow: const [
                            BoxShadow(color: Colors.black45, blurRadius: 6)
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.delete_outline,
                                color: Colors.white, size: 20),
                            SizedBox(width: 6),
                            Text('CLEAR',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13)),
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

          // Always-visible connection status. Top-left, clear of SOS on the
          // right. In this app "it didn't work" and "it hasn't sent yet" look
          // the same from outside, and after pressing SOS that is the
          // difference that matters.
          // Below the top button row, not on top of it. It was at
          // padding.top + 12 and the 54 px hamburger starts at padding.top +
          // 10, so it covered the menu button and ate its taps.
          Positioned(
            top: MediaQuery.of(context).padding.top + 10 + 54 + 8,
            left: 14,
            // The queue count makes "offline" and "offline with three things
            // waiting" different readings, which is the point of the badge.
            child: IgnorePointer(
              child: ConnectivityPill(
                  pendingCount: ref.watch(outboxStatusProvider).pending),
            ),
          ),

          // Imagery credit. Required by Esri's and Mapbox's terms alike, and
          // absent from this app until now — so this fixes a licence gap for
          // the existing sources as much as it serves the new one.
          //
          // Tapping it swaps satellite source, which is the quickest way to
          // compare two providers over the same patch of ground: no menus, no
          // losing your place on the map.
          // A licence requirement, so it is never hidden by the sheet and
          // never tucked under the compass. It keeps its place even when the
          // other controls hide, because the imagery is still on screen.
          if (!_drawerOpen)
            Positioned(
              bottom: attributionBottom,
              right: 6,
              child: GestureDetector(
                onTap: _mapStyleIndex == 0 ? _swapSatelliteSource : null,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  color: Colors.black.withValues(alpha: 0.45),
                  child: Text(
                    (_mapStyleIndex == 0
                            ? '${ref.watch(satelliteSourceProvider).attribution}  ·  tap to swap'
                            : _mapStyleIndex == 1
                                ? '© OpenTopoMap (CC-BY-SA)'
                                : '© OpenStreetMap contributors') +
                        (creditUnderlay
                            ? '\nOffline: ${underlay.attribution}'
                            : ''),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 8.5),
                  ),
                ),
              ),
            ),

          // Says so, on the map, when the map is not showing everything.
          //
          // A project scope can hide a great deal at once, and a filter you
          // cannot see is indistinguishable from lost work — the first thing
          // anyone thinks when their pins are missing is that the app threw
          // them away. This sits above the coordinates where the left column is
          // otherwise empty, and one tap puts everything back.
          if (!_drawerOpen && visibility.isFiltered && !hideStack)
            Positioned(
              bottom: stackBase + 54,
              left: 20,
              child: _filterPill(visibility),
            ),

          // Coordinate Display — hidden when drawer is open to prevent z-order clash.
          if (!_drawerOpen)
            Positioned(
              bottom: stackBase,
              left: 20,
              child: GestureDetector(
                onTap: () => setState(
                    () => _showCoordinatePanel = !_showCoordinatePanel),
                // With no fix this used to show -25.3444, 131.0369 — Uluru — as
                // if it were your position. Someone reading coordinates off the
                // screen to radio them in would have read out Uluru.
                child: locationState.stats.currentLat == null ||
                        locationState.stats.currentLon == null
                    ? _noGpsFixChip()
                    // A coarse fix is worse than no fix if it is presented as
                    // though it were exact — it puts you on the wrong street
                    // while looking perfectly confident.
                    : locationState.stats.currentAccuracyM >
                            LocationNotifier.maxUsableAccuracyMetres
                        ? _coarseFixChip(locationState.stats.currentAccuracyM)
                        : _showCoordinatePanel
                            ? SizedBox(
                                width: 280,
                                child: CoordinateDisplay(
                                  position: LatLng(
                                    locationState.stats.currentLat!,
                                    locationState.stats.currentLon!,
                                  ),
                                  format: _coordinateFormat,
                                  showAllFormats: true,
                                  onFormatChanged: () {
                                    setState(() {
                                      const formats = CoordinateFormat.values;
                                      final currentIndex =
                                          formats.indexOf(_coordinateFormat);
                                      _coordinateFormat = formats[
                                          (currentIndex + 1) % formats.length];
                                    });
                                  },
                                ),
                              )
                            : CoordinateDisplay(
                                position: LatLng(
                                  locationState.stats.currentLat!,
                                  locationState.stats.currentLon!,
                                ),
                                format: _coordinateFormat,
                                onFormatChanged: () {
                                  setState(() {
                                    const formats = CoordinateFormat.values;
                                    final currentIndex =
                                        formats.indexOf(_coordinateFormat);
                                    _coordinateFormat = formats[
                                        (currentIndex + 1) % formats.length];
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

          // Offline banner. Sits below the weather card and the SOS button
          // rather than on top of them, and paints late so nothing covers it.
          // It used to be at top:50 spanning the full width, directly under
          // the SOS button and the weather card, so its text was clipped
          // behind both.
          if (_showOfflineBanner && _trackTarget == null && !navState.isActive)
            Positioned(
              top: MediaQuery.of(context).padding.top + 180,
              left: 14,
              right: 14,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.wifi_off, color: Colors.white, size: 18),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Some map tiles need internet. Core survival features '
                        'work fully offline.',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _showOfflineBanner = false),
                      child: const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Icon(Icons.close, color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Zone drawing controls
          if (_zoneDraft != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ZoneDrawPanel(
                draft: _zoneDraft!,
                onShapeChanged: (shape) =>
                    setState(() => _zoneDraft = _zoneDraft!.withShape(shape)),
                onRadiusChanged: (r) => setState(
                    () => _zoneDraft = _zoneDraft!.copyWith(radiusMetres: r)),
                onUndo: () =>
                    setState(() => _zoneDraft = _zoneDraft!.undoLastPoint()),
                onCancel: () => setState(() => _zoneDraft = null),
                onSave: _saveZoneDraft,
              ),
            ),

          // Freehand controls
          if (_freehand != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: FreehandPanel(
                session: _freehand!,
                onDrawingChanged: (on) => setState(() {
                  _freehand!
                    ..cancelStroke()
                    ..drawing = on;
                }),
                onColour: (c) => setState(() => _freehand!.colour = c),
                onWidth: (w) => setState(() => _freehand!.width = w),
                onUndo: () => setState(() => _freehand!.undo()),
                onCancel: _cancelFreehand,
                onDone: _saveFreehand,
              ),
            ),

          // Line drawing controls
          if (_lineDraft != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: LineDrawPanel(
                points: _lineDraft!.points,
                canUndo: _lineDraft!.canUndo,
                editing: _editingDrawing != null,
                snappedTo: _lineSnappedTo,
                colour: _lineColour,
                width: _lineWidth,
                onColour: (c) => setState(() => _lineColour = c),
                onWidth: (w) => setState(() => _lineWidth = w),
                onUndo: () => setState(() {
                  _lineDraft!.undo();
                  _lineSnappedTo = null;
                }),
                onCancel: _cancelLineDrawing,
                onDone: _saveLineDraft,
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

          // Drawer LAST so it paints above the mesh sheet, voice and
          // weather overlays. It used to sit mid-Stack, so the
          // bottom-anchored mesh sheet covered the SOS button and
          // swallowed its taps.
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
                onToggleBreadcrumbs: () =>
                    setState(() => _showBreadcrumbs = !_showBreadcrumbs),
                onRecenter: () {
                  if (locationState.stats.currentLat != null) {
                    _mapController.move(
                      LatLng(locationState.stats.currentLat!,
                          locationState.stats.currentLon!),
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
                  showWaypointEditor(context,
                      position: _mapController.camera.center);
                },
                onTrackRecord: () {
                  ref.read(trailProvider.notifier).startCreatingTrail();
                  ref.read(aiAssistantProvider.notifier).speak(
                      "Trail creation mode activated. Tap on the map to drop points.");
                },
                onExportTrack: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const TripStatisticsScreen())),
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
                onDeviceInfo: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => CoordinateInputScreen(
                              onCoordinateEntered: (c) =>
                                  _mapController.move(c, 14.0),
                            ))),
                onNavigation: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const RouteOptionsScreen())),
                onAIAssistant: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => NaturalLanguageSearchScreen(
                              onLocationFound: (c) =>
                                  _mapController.move(c, 14.0),
                            ))),
                onSearchPlace: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PlacesSearchScreen())),
                onCompassNav: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ARCompassScreen())),
                onMeshSignal: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const OfflineMapsScreen())),
                onSettings: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen())),
                onAnalytics: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AgentManagerScreen())),
                onSavedPins: _showSavedPins,
                onMyTrails: _showMyTrails,
                onFiles: _showFiles,
                onMarkerPicker: _showMarkerPicker,
                onStreetView: _toggleStreetView,
                streetViewOn: streetView.enabled,
                streetViewReason: streetView.reason,
                hiddenCount: ref.watch(markerVisibilityProvider).hiddenCount,
                openFileName: ref.watch(filesProvider).activeFile?.name,
                onDrawZone: _startZoneDrawing,
                onDrawLine: _startLineDrawing,
                onDrawFreehand: _startFreehand,
                onZones: _showZones,
                zoneCount: geofenceState.geofences.length,
                deadmanArmed: ref.watch(aiControlProvider).deadmanArmed,
                storageOk: ref.read(databaseServiceProvider).isPersistent,
                storageNote: ref.read(databaseServiceProvider).storageReport,
                onToggleDeadman: () {
                  final armed = ref.read(aiControlProvider).deadmanArmed;
                  ref.read(aiControlProvider.notifier).setDeadmanArmed(!armed);
                },
                onGallery: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => PhotoGalleryScreen(
                              onJumpToMap: (loc) =>
                                  _mapController.move(loc, 16.0),
                            ))),
                onSOS: _showSOSConfirmation,
              ),
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
        border:
            Border.all(color: const Color(0xFF7B2FFF).withValues(alpha: 0.6)),
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
              _hudStat('Covered', '${coveredKm.toStringAsFixed(2)} km',
                  Colors.greenAccent),
              _hudStat(
                  'Remaining',
                  '${remainingKm.clamp(0, double.infinity).toStringAsFixed(2)} km',
                  const Color(0xFFFF9800)),
              if (trailState.distanceToNextPoint != null)
                _hudStat(
                    'Next pin',
                    trailState.distanceToNextPoint! < 1000
                        ? '${trailState.distanceToNextPoint!.toInt()} m'
                        : '${(trailState.distanceToNextPoint! / 1000).toStringAsFixed(1)} km',
                    AppColors.statusBlue),
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
        Text(label,
            style: GoogleFonts.outfit(color: Colors.white38, fontSize: 10)),
        Text(value,
            style: GoogleFonts.outfit(
                color: color, fontSize: 13, fontWeight: FontWeight.w600)),
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
              'If you have signal, call 000 first. Then this sends your location on every channel this phone has:',
              style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 12),
            // Say what each channel really does. The mesh can't run in a
            // browser, and SMS only opens the messages app.
            _sosChannel(
                Icons.hub,
                'Mesh broadcast',
                kIsWeb
                    ? 'Android app only — not in the browser'
                    : 'BushTrack phones in radio range'),
            _sosChannel(Icons.sms, 'SMS',
                'Opens your messages — you choose who to send to'),
            _sosChannel(Icons.share, 'Share', 'WhatsApp, Signal, etc.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CANCEL',
                style: GoogleFonts.outfit(color: Colors.white54)),
          ),
          // 000 is the only channel here that reaches emergency services, and
          // the SOS flow never offered it.
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(context);
              ref.read(aiAssistantProvider.notifier).callEmergencyServices();
            },
            icon: const Icon(Icons.phone, color: Colors.red, size: 18),
            label: Text('CALL 000',
                style: GoogleFonts.outfit(
                    color: Colors.red, fontWeight: FontWeight.bold)),
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
          // Expanded so subtitles wrap on a phone instead of running off the
          // edge of the dialog.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                Text(subtitle,
                    style: GoogleFonts.outfit(
                        color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _compass8(double bearingDeg) {
    const names = [
      'north',
      'north-east',
      'east',
      'south-east',
      'south',
      'south-west',
      'west',
      'north-west'
    ];
    return names[(((bearingDeg % 360) + 360) % 360 / 45).round() % 8];
  }

  void _showIncomingSos(MeshPacket sos) {
    if (!mounted) return;
    final here = _sosPosition();
    final there = (sos.latitude != null && sos.longitude != null)
        ? LatLng(sos.latitude!, sos.longitude!)
        : null;

    String where;
    String spoken;
    if (there == null) {
      where = 'Their location was not included.';
      spoken = 'SOS received from a nearby BushTrack phone. '
          'Their location was not included.';
    } else if (here == null) {
      where = 'At ${there.latitude.toStringAsFixed(5)}, '
          '${there.longitude.toStringAsFixed(5)}';
      spoken = 'SOS received from a nearby BushTrack phone.';
    } else {
      final dist = _fmtDist(_distM(here, there));
      final dir = _compass8(const Distance().bearing(here, there));
      where = '$dist to the $dir of you';
      spoken = 'SOS received. Someone needs help, $dist to the $dir.';
    }
    ref.read(aiAssistantProvider.notifier).speak(spoken);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A0000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.red, width: 2),
        ),
        title: Row(children: [
          const Icon(Icons.sos, color: Colors.red, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Text('SOS RECEIVED',
                style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900)),
          ),
        ]),
        content: Text(
          '${sos.senderId} has activated an SOS.\n\n$where',
          style: GoogleFonts.outfit(color: Colors.white, fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('DISMISS',
                style: GoogleFonts.outfit(color: Colors.white54)),
          ),
          if (there != null)
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.pop(ctx);
                _mapController.move(there, 15.0);
              },
              child: Text('SHOW ON MAP',
                  style: GoogleFonts.outfit(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  // ─── Track to a pin ─────────────────────────────────────────────────────
  // Bug brief #3: tapping a pin showed no distance or direction, and its
  // "Navigate" button only spoke a sentence. Tracking is straight-line on
  // purpose: off-road there is no road network to route along, and it works
  // with no signal.

  /// "340 m · north-east (42°) from you", or null with no GPS fix.
  String? _pinDistanceInfo(Waypoint w) {
    final here = _userLatLng();
    if (here == null || w.latitude == null || w.longitude == null) return null;
    final there = LatLng(w.latitude!, w.longitude!);
    final bearing =
        HeadingReading.normalize(const Distance().bearing(here, there));
    return '${_fmtDist(_distM(here, there))} · ${_compass8(bearing)} '
        '(${bearing.round()}°) from you';
  }

  /// Track a flagged zone. Arrival is its boundary, not its centre — walking
  /// to the middle of a 2 km exclusion area is not what anyone means.
  void _startTrackingZone(Geofence zone) {
    setState(() => _trackedPin = null);
    _setTrackTarget(TrackTarget(
      name: zone.name,
      position: zone.centre,
      colour: Color(zone.category.colorValue),
      arriveWithinMetres: math.max(zone.radiusMeters, 25),
      isZone: true,
    ));
    _announceTracking(zone.name, zone.centre);
  }

  void _setTrackTarget(TrackTarget? target) {
    ref.read(trackTargetProvider.notifier).state = target;
  }

  void _announceTracking(String name, LatLng there) {
    final here = _userLatLng();
    if (here == null) {
      ref
          .read(aiAssistantProvider.notifier)
          .speak('Tracking $name. Waiting for a GPS fix.');
      return;
    }
    final bearing =
        HeadingReading.normalize(const Distance().bearing(here, there));
    ref.read(aiAssistantProvider.notifier).speak('Tracking $name. '
        '${NavigationNotifier.formatSpokenDistance(_distM(here, there))} '
        'to the ${_compass8(bearing)}.');
  }

  void _startTracking(Waypoint w) {
    if (w.latitude == null || w.longitude == null) return;
    setState(() => _trackedPin = w);
    _setTrackTarget(TrackTarget(
      name: w.label ?? 'your pin',
      position: LatLng(w.latitude!, w.longitude!),
      colour: WaypointColors.fromHex(w.color),
    ));
    final name = w.label ?? 'your pin';
    final here = _userLatLng();
    if (here == null) {
      ref
          .read(aiAssistantProvider.notifier)
          .speak('Tracking $name. Waiting for a GPS fix.');
      return;
    }
    final there = LatLng(w.latitude!, w.longitude!);
    final bearing =
        HeadingReading.normalize(const Distance().bearing(here, there));
    ref.read(aiAssistantProvider.notifier).speak('Tracking $name. '
        '${NavigationNotifier.formatSpokenDistance(_distM(here, there))} '
        'to the ${_compass8(bearing)}.');
  }

  void _stopTracking() {
    setState(() => _trackedPin = null);
    _setTrackTarget(null);
  }

  void _checkTrackingArrival(LocationState next) {
    final target = ref.read(trackTargetProvider);
    final lat = next.stats.currentLat;
    final lon = next.stats.currentLon;
    if (target == null || lat == null || lon == null) return;
    final d = _distM(LatLng(lat, lon), target.position);
    // A zone is reached at its boundary; a pin at the spot itself.
    if (d > target.arriveWithinMetres) return;
    final name = target.name;
    ref.read(aiAssistantProvider.notifier).speak(target.isZone
        ? 'You have reached $name.'
        : 'You have arrived at $name.');
    setState(() => _trackedPin = null);
    _setTrackTarget(null);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Arrived at $name'),
      backgroundColor: const Color(0xFF2E7D32),
    ));
  }

  Widget _buildTrackingHud(WidgetRef ref) {
    final target = ref.watch(trackTargetProvider)!;
    final stats = ref.watch(locationProvider).stats;
    final heading = ref.watch(headingProvider).valueOrNull;
    final pin = target.position;

    double? dist;
    double? bearing;
    if (stats.currentLat != null && stats.currentLon != null) {
      final here = LatLng(stats.currentLat!, stats.currentLon!);
      dist = _distM(here, pin);
      bearing = HeadingReading.normalize(const Distance().bearing(here, pin));
    }
    final compassLive = heading != null && heading.isLive;
    // With a live compass the arrow is relative to where the phone points —
    // walk the way it shows. Without one it's relative to north (the map is
    // north-up), and the text says so.
    final arrowDeg = bearing == null
        ? 0.0
        : (compassLive ? bearing - heading.degrees : bearing);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF4CAF50), width: 1.5),
      ),
      child: Row(children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
          ),
          child: bearing == null
              ? const Icon(Icons.gps_not_fixed, color: Colors.orange, size: 30)
              : Transform.rotate(
                  angle: arrowDeg * math.pi / 180,
                  child: const Icon(Icons.navigation,
                      color: Color(0xFF4CAF50), size: 40),
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('TRACKING · ${target.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1)),
              Text(dist == null ? 'Waiting for GPS…' : _fmtDist(dist),
                  style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900)),
              if (bearing != null)
                Text(
                  '${_compass8(bearing)} · ${bearing.round()}°'
                  '${compassLive ? '' : ' · arrow is from north'}',
                  style: GoogleFonts.outfit(
                      color: const Color(0xFF81C784), fontSize: 12),
                ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Stop tracking',
          icon: const Icon(Icons.close, color: Colors.white70),
          onPressed: _stopTracking,
        ),
      ]),
    );
  }

  /// Best position to put in an SOS: the live fix, else the last breadcrumb.
  /// Returns null if we genuinely don't know — never a made-up location.
  LatLng? _sosPosition() {
    final locationState = ref.read(locationProvider);
    final lat = locationState.stats.currentLat;
    final lon = locationState.stats.currentLon;
    if (lat != null && lon != null) return LatLng(lat, lon);
    for (final b in locationState.breadcrumbs.reversed) {
      if (b.latitude != null && b.longitude != null) {
        return LatLng(b.latitude!, b.longitude!);
      }
    }
    return null;
  }

  // Confirmation is the 3-second hold plus the SOS ALERT dialog. This used to
  // open a SECOND "Send SOS?" dialog on top — two confirmations after a long
  // press is too slow in a real emergency.
  Future<void> _activateSOS() async {
    if (!mounted) return;

    // Previously fell back to -25.3444, 131.0369 — Uluru — when there was no
    // GPS fix, and sent THAT as the emergency location. Rescuers would have
    // been pointed 1,000 km from Leonora.
    final pos = _sosPosition();
    final where = pos == null
        ? 'Location unknown (no GPS fix)'
        : 'GPS: ${pos.latitude.toStringAsFixed(5)}, '
            '${pos.longitude.toStringAsFixed(5)} '
            'https://maps.google.com/?q=${pos.latitude},${pos.longitude}';
    final msg = 'SOS EMERGENCY - I need help. $where - sent from BushTrack';

    // 1. Mesh — BushTrack phones in radio range (Android app only).
    try {
      await ref.read(meshProvider.notifier).sendSOS(
            latitude: pos?.latitude,
            longitude: pos?.longitude,
          );
    } catch (_) {}

    // 2. SMS — opens the messages app with the text filled in. The user
    //    still picks who to send it to; nothing is sent automatically.
    try {
      await openSmsUrl(msg);
    } catch (_) {}

    // 3. Share sheet — WhatsApp, Signal, etc.
    try {
      await shareText('SOS EMERGENCY', msg);
    } catch (_) {}

    // This used to say "Help is on the way", which nothing here guarantees.
    ref.read(aiAssistantProvider.notifier).speak(kIsWeb
        ? "SOS message ready. Send it to someone who can help. "
            "If you have signal, call triple zero."
        : "SOS sent to nearby BushTrack phones, and your message is ready "
            "to send. If you have signal, call triple zero.");

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.sos, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              kIsWeb
                  ? 'SOS message ready — send it, or call 000'
                  : 'SOS broadcasting to nearby phones — call 000 if you can',
              style: GoogleFonts.outfit(color: Colors.white),
            ),
          ),
        ]),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: 'CALL 000',
          textColor: Colors.white,
          onPressed: () =>
              ref.read(aiAssistantProvider.notifier).callEmergencyServices(),
        ),
      ),
    );
  }

  void _onMapTap(LatLng point, TrailState trailState) {
    // Drawing a zone takes the tap before anything else, so placing a corner
    // near a trail cannot open that trail's edit sheet instead.
    final draft = _zoneDraft;
    if (draft != null) {
      setState(() => _zoneDraft = draft.withTap(point));
      return;
    }

    // Same for a line: every tap is a point, whatever is under it.
    if (_lineDraft != null) {
      _addLinePoint(point);
      return;
    }

    // Freehand in Pan mode: a tap is not a stroke, and not anything else.
    if (_freehand != null) return;

    if (_showMeasurementTool && _measurementKey.currentState != null) {
      _measurementKey.currentState!.handleMapTap(point);
      return;
    }

    if (trailState.isCreating) {
      ref.read(trailProvider.notifier).addDraftPoint(point);
      ref
          .read(aiAssistantProvider.notifier)
          .speak("Point ${trailState.draftPoints.length + 1} added.");
      return;
    }

    // Tap NEAR a pin counts as tapping it. The marker is 62 px wide and sits
    // above its point, so on a phone a fingertip regularly lands just off it
    // and the tap was treated as empty ground — which is what "tapping a pin
    // does nothing" actually was.
    final pin = _findNearestPin(point);
    if (pin != null) {
      _openPinSheet(pin);
      return;
    }

    // Tap near a saved trail ? open edit sheet
    final near = _findNearestTrail(point, trailState.trails);
    if (near != null) {
      _showTrailEditSheet(near);
    }
  }

  /// The closest dropped pin to [tap], within a zoom-scaled tolerance, or null
  /// if the tap was not near one. Same approach as _findNearestTrail.
  Waypoint? _findNearestPin(LatLng tap) {
    final threshold =
        0.0006 * math.pow(2, (16 - _currentZoom).clamp(-3.0, 4.0));
    Waypoint? nearest;
    var nearestDist = double.infinity;
    for (final w in ref.read(locationProvider).waypoints) {
      if (w.isPin != true || w.latitude == null || w.longitude == null)
        continue;
      final d = _latlngDeg(tap, LatLng(w.latitude!, w.longitude!));
      if (d < threshold && d < nearestDist) {
        nearestDist = d;
        nearest = w;
      }
    }
    return nearest;
  }

  /// The pin's sheet — distance, bearing and the Track button — opened from a
  /// map tap rather than from the marker itself.
  void _openPinSheet(Waypoint w) {
    showWaypointMenu(
      context,
      waypoint: w,
      distanceInfo: _pinDistanceInfo(w),
      onEdit: () => w.isPinage ? _showPinageViewer(w) : _editWaypoint(w),
      onDelete: () => ref.read(locationProvider.notifier).deleteWaypoint(w.id!),
      onColorChanged: (color) =>
          ref.read(locationProvider.notifier).updateWaypointColor(w.id!, color),
      onIconChanged: (icon) =>
          ref.read(locationProvider.notifier).updateWaypointIcon(w.id!, icon),
      onNavigate: () => _startTracking(w),
    );
  }

  Future<void> _onMapLongPress(LatLng point) async {
    // Drawing: a long press is never a dropped pin.
    if (_lineDraft != null || _freehand != null) return;

    // Long-press a saved line to edit or delete it, as with trails.
    final drawing = _findNearestDrawing(point);
    if (drawing != null) {
      _showDrawingSheet(drawing);
      return;
    }

    // Long-press near a trail ? edit it instead of dropping a pin
    final trailState = ref.read(trailProvider);
    final near = _findNearestTrail(point, trailState.trails);
    if (near != null) {
      _showTrailEditSheet(near);
      return;
    }

    // _targetPin is only a preview of where you pressed, shown while the
    // chooser is open. It used to be left set forever, so once the real
    // waypoint saved you got two pins stacked on the same spot — the
    // WaypointMarker plus this red one. Clear it when the chooser closes.
    setState(() => _targetPin = point);
    await showPinageChooser(
      context,
      position: point,
      onNormalPin: () => _dropNormalPin(point),
      onPinage: () => showPinageEditor(context, position: point),
    );
    if (mounted) setState(() => _targetPin = null);
  }

  /// Choose what is drawn and what to follow.
  Future<void> _showMarkerPicker() async {
    final choice = await Navigator.push<MarkerChoice>(
      context,
      MaterialPageRoute(builder: (_) => const MarkerPickerScreen()),
    );
    if (choice == null || !mounted) return;

    if (choice.waypoint != null) {
      _startTracking(choice.waypoint!);
      _mapController.move(
          LatLng(choice.waypoint!.latitude!, choice.waypoint!.longitude!), 16);
    } else if (choice.zone != null) {
      _startTrackingZone(choice.zone!);
      _mapController.move(
          choice.zone!.centre, _zoomForRadius(choice.zone!.radiusMeters));
    }
  }

  /// Open the camera. If a photo was identified and the user wants to talk
  /// about it, the chat opens with that result already asked.
  Future<void> _openCamera() async {
    final prompt = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ARCameraScreen()),
    );
    if (prompt == null || !mounted) return;
    showAIChat(context, initialMessage: prompt);
  }

  /// Open the files, and fly to whatever was tapped inside one.
  Future<void> _showFiles() async {
    final goTo = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(builder: (_) => const FilesScreen()),
    );
    if (goTo == null || !mounted) return;
    _mapController.move(goTo, 16.0);
  }

  /// Open the zone list, then either fly to the zone that was tapped or
  /// reopen it for resizing.
  Future<void> _showZones() async {
    final action = await Navigator.push<ZoneAction>(
      context,
      MaterialPageRoute(builder: (_) => const GeofenceScreen()),
    );
    if (action == null || !mounted) return;
    final zone = action.zone;

    if (action.track) {
      _startTrackingZone(zone);
      if (zone.isPolygon && zone.points.length >= 2) {
        _mapController.fitCamera(CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(zone.points),
          padding: const EdgeInsets.all(60),
        ));
      } else {
        _mapController.move(zone.centre, _zoomForRadius(zone.radiusMeters));
      }
      return;
    }

    if (action.resize) {
      setState(() {
        _showMeasurementTool = false;
        _zoneDraft = ZoneDraft.from(zone);
      });
      _mapController.move(zone.centre, _zoomForRadius(zone.radiusMeters));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(zone.isPolygon
            ? 'Tap out new corners for ${zone.name}.'
            : 'Drag the grip on the edge to resize ${zone.name}.'),
        duration: const Duration(seconds: 3),
        backgroundColor: AppColors.primaryOrange,
      ));
      return;
    }

    // Frame the whole zone rather than centring blindly: a 5 km boundary at
    // zoom 16 fills the screen with the middle of it and nothing else.
    if (zone.isPolygon && zone.points.length >= 2) {
      _mapController.fitCamera(CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(zone.points),
        padding: const EdgeInsets.all(60),
      ));
    } else {
      _mapController.move(zone.centre, _zoomForRadius(zone.radiusMeters));
    }
  }

  /// A zoom level that fits a circle of this radius on screen.
  double _zoomForRadius(double radiusMetres) {
    if (radiusMetres <= 0) return 16;
    // Each zoom level halves the ground covered; 156543 m/px is zoom 0 at the
    // equator. Aim for the circle taking about half the screen width.
    final target = (radiusMetres * 2.5) / 180;
    final zoom = math.log(156543 / target) / math.ln2;
    return zoom.clamp(5.0, 17.0);
  }

  /// Size the circle being drawn by dragging its edge handle.
  ///
  /// The radius is the real ground distance from the centre to wherever the
  /// finger is, so it stays correct however the map is rotated or zoomed —
  /// working from the pixel delta would drift on both.
  void _resizeZoneDraftTo(Offset globalPosition) {
    final draft = _zoneDraft;
    final centre = draft?.centre;
    if (draft == null || centre == null) return;

    final box = _mapAreaKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final local = box.globalToLocal(globalPosition);
    final underFinger = _mapController.camera.offsetToCrs(local);
    final metres = const Distance()(centre, underFinger);

    setState(() => _zoneDraft = draft.copyWith(
        radiusMetres: metres.clamp(kZoneMinRadius, kZoneMaxRadius)));
  }

  // ── Drawing lines (4.2) ───────────────────────────────────────────────────

  /// About a fingertip, in logical pixels: the reach of a snap, and of a
  /// long-press on a saved line.
  static const double _fingertipPixels = 36;

  /// Start a new line, or reopen [editing] to move, add and remove points.
  /// Closes anything else that wants map taps.
  void _startLineDrawing({Drawing? editing}) {
    setState(() {
      _showMeasurementTool = false;
      _zoneDraft = null;
      _freehand = null;
      _editingDrawing = editing;
      _lineDraft = LineDraft(editing?.points ?? const []);
      if (editing != null) {
        _lineColour = editing.colour;
        _lineWidth = editing.width;
      }
      _lineSnappedTo = null;
    });
    if (editing == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Tap the map to place points. A tap near a pin snaps to it.'),
        duration: Duration(seconds: 3),
        backgroundColor: AppColors.primaryOrange,
      ));
    }
  }

  void _cancelLineDrawing() => setState(() {
        _lineDraft = null;
        _editingDrawing = null;
        _lineSnappedTo = null;
      });

  /// Ground distance covered by [pixels] across the middle of the map, at the
  /// current zoom. Turns "a fingertip" into metres for the snapping arithmetic,
  /// which knows nothing about screens.
  double _metresForPixels(double pixels) {
    final box = _mapAreaKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return 0;
    final c = box.size.center(Offset.zero);
    final camera = _mapController.camera;
    return const Distance()(camera.offsetToCrs(c),
        camera.offsetToCrs(c + Offset(pixels, 0)));
  }

  LatLng? _globalToLatLng(Offset global) {
    final box = _mapAreaKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;
    return _mapController.camera.offsetToCrs(box.globalToLocal(global));
  }

  /// Pins and the ends of other lines, as far as they are on the map.
  List<SnapTarget> _lineSnapTargets() {
    final visibility = ref.read(markerVisibilityProvider);
    return [
      for (final w in ref.read(locationProvider).waypoints)
        if (w.latitude != null &&
            w.longitude != null &&
            visibility.showsPin(id: w.id, fileId: w.fileId))
          SnapTarget(LatLng(w.latitude!, w.longitude!),
              label: (w.label?.trim().isNotEmpty ?? false) ? w.label! : 'a pin'),
      for (final d in ref.read(drawingsProvider))
        if (d.id != _editingDrawing?.id &&
            d.points.length >= 2 &&
            visibility.showsDrawing(fileId: d.fileId)) ...[
          SnapTarget(d.points.first,
              label: 'the start of ${d.name ?? 'a line'}'),
          SnapTarget(d.points.last, label: 'the end of ${d.name ?? 'a line'}'),
        ],
    ];
  }

  /// [p], or the target it lands within a fingertip of. Records what it
  /// snapped to, so the panel can say -- a snap nobody was told about looks
  /// like the point landing in the wrong place.
  LatLng _snap(LatLng p) {
    final hit = Snapping.nearest(
        p, _lineSnapTargets(), _metresForPixels(_fingertipPixels));
    _lineSnappedTo = hit?.label;
    return hit?.point ?? p;
  }

  void _addLinePoint(LatLng point) =>
      setState(() => _lineDraft?.add(_snap(point)));

  void _insertLineVertex(int index) {
    final draft = _lineDraft;
    if (draft == null || index < 1 || index > draft.midpoints.length) return;
    setState(() {
      draft.insert(index, draft.midpoints[index - 1]);
      _lineSnappedTo = null;
    });
  }

  void _dragLineVertex(int index, Offset global) {
    final p = _globalToLatLng(global);
    if (p == null || _lineDraft == null) return;
    setState(() {
      _lineDraft!.drag(index, p);
      _lineSnappedTo = null;
    });
  }

  /// A dragged point snaps where it is let go, inside the same undo step.
  void _endLineVertexDrag(int index) {
    final draft = _lineDraft;
    if (draft == null || !draft.isDragging || index >= draft.points.length) {
      return;
    }
    setState(() {
      draft.drag(index, _snap(draft.points[index]));
      draft.endDrag();
    });
  }

  Future<void> _saveLineDraft() async {
    final draft = _lineDraft;
    if (draft == null || draft.points.length < 2) return;
    final points = draft.points;
    final notifier = ref.read(drawingsProvider.notifier);
    final editing = _editingDrawing;

    if (editing != null) {
      await notifier.save(editing.copyWith(
          points: points, colour: _lineColour, width: _lineWidth));
      if (!mounted) return;
      _cancelLineDrawing();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Saved "${editing.name ?? 'line'}" · '
            '${formatDistance(LineMeasure.totalMetres(points))}'),
        backgroundColor: AppColors.primaryOrange,
      ));
      return;
    }

    final name = await _askDrawingName(
        'Save line · ${formatDistance(LineMeasure.totalMetres(points))}',
        hint: 'Name (optional), e.g. north fence');
    // Backing out of the name keeps the line on screen to carry on with.
    if (name == null || !mounted) return;
    final saved = await notifier.add(Drawing(
      kind: DrawingKind.line,
      name: name.isEmpty ? null : name,
      colour: _lineColour,
      width: _lineWidth,
      points: points,
      // Filed under the open project, as a new pin would be.
      fileId: ref.read(filesProvider).activeFileId,
    ));
    if (!mounted) return;
    _cancelLineDrawing();
    if (saved != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Saved "${saved.name ?? 'line'}" · '
            '${formatDistance(saved.lengthMetres)}'),
        backgroundColor: AppColors.primaryOrange,
      ));
    }
  }

  Future<String?> _askDrawingName(String title, {required String hint}) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          textInputAction: TextInputAction.done,
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white38),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Back', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// The saved line within a fingertip of [p], nearest first.
  Drawing? _findNearestDrawing(LatLng p) {
    final visibility = ref.read(markerVisibilityProvider);
    var reach = _metresForPixels(_fingertipPixels);
    Drawing? best;
    for (final d in ref.read(drawingsProvider)) {
      if (d.points.length < 2) continue;
      if (!visibility.showsDrawing(fileId: d.fileId)) continue;
      final m = LineMeasure.distanceToLineMetres(p, d.points);
      if (m <= reach) {
        best = d;
        reach = m;
      }
    }
    return best;
  }

  void _showDrawingSheet(Drawing drawing) {
    var d = drawing;
    final legs = d.points.length - 1;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0F0F1A),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(d.name ?? (d.kind == DrawingKind.line ? 'Line' : 'Drawing'),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                  '${formatDistance(d.lengthMetres)} · $legs ${legs == 1 ? 'leg' : 'legs'}',
                  style: const TextStyle(color: Colors.white60)),
              const SizedBox(height: 14),
              // Recolour in place: saved as it is picked, nothing to confirm.
              PenPicker(
                colour: d.colour,
                width: d.width,
                onColour: (c) async {
                  d = d.copyWith(colour: c);
                  setSheet(() {});
                  await ref.read(drawingsProvider.notifier).save(d);
                },
                onWidth: (w) async {
                  d = d.copyWith(width: w);
                  setSheet(() {});
                  await ref.read(drawingsProvider.notifier).save(d);
                },
              ),
              const SizedBox(height: 8),
              Row(children: [
                if (d.kind == DrawingKind.line)
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _startLineDrawing(editing: d);
                  },
                  icon: const Icon(Icons.edit, color: AppColors.primaryOrange),
                  label: const Text('Edit points',
                      style: TextStyle(color: AppColors.primaryOrange)),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _confirmDeleteDrawing(d);
                  },
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  label: const Text('Delete',
                      style: TextStyle(color: Colors.redAccent)),
                ),
              ]),
            ],
          ),
        ),
      )),
    );
  }

  Future<void> _confirmDeleteDrawing(Drawing d) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text('Delete "${d.name ?? 'this line'}"?',
            style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (yes == true && d.id != null) {
      await ref.read(drawingsProvider.notifier).delete(d.id!);
    }
  }

  // ── Freehand (4.2) ────────────────────────────────────────────────────────

  void _startFreehand() {
    setState(() {
      _showMeasurementTool = false;
      _zoneDraft = null;
      _lineDraft = null;
      _editingDrawing = null;
      _freehand = FreehandSession();
    });
  }

  void _cancelFreehand() => setState(() => _freehand = null);

  void _freehandAt(Offset global, {bool start = false}) {
    final session = _freehand;
    final p = _globalToLatLng(global);
    if (session == null || p == null) return;
    setState(() => start ? session.beginStroke(p) : session.extendStroke(p));
  }

  /// Keep the stroke, simplified to what two screen pixels cover at this zoom:
  /// it looks as it did under the finger, at a fraction of the points.
  void _endFreehandStroke() {
    final session = _freehand;
    if (session == null) return;
    final tolerance = _metresForPixels(2).clamp(0.05, 50.0);
    setState(() => session.endStroke(tolerance));
  }

  Future<void> _saveFreehand() async {
    final session = _freehand;
    if (session == null || session.strokes.isEmpty) return;
    final name = await _askDrawingName(
        'Save drawing · ${formatDistance(session.totalMetres)}',
        hint: 'Name (optional), e.g. burn edge');
    if (name == null || !mounted) return;

    final notifier = ref.read(drawingsProvider.notifier);
    final fileId = ref.read(filesProvider).activeFileId;
    // One drawing per stroke: each can then be deleted on its own later.
    for (final stroke in session.strokes) {
      await notifier.add(Drawing(
        kind: DrawingKind.freehand,
        name: name.isEmpty ? null : name,
        colour: session.colour,
        width: session.width,
        points: stroke,
        fileId: fileId,
      ));
    }
    if (!mounted) return;
    final n = session.strokes.length;
    setState(() => _freehand = null);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Saved $n ${n == 1 ? 'stroke' : 'strokes'}'),
      backgroundColor: AppColors.primaryOrange,
    ));
  }

  /// Start drawing a zone. Closes anything that also wants map taps, so a
  /// corner tap cannot be claimed by the measuring tool at the same time.
  void _startZoneDrawing() {
    setState(() {
      _showMeasurementTool = false;
      _lineDraft = null;
      _editingDrawing = null;
      _freehand = null;
      _zoneDraft = const ZoneDraft();
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Tap the map to place the zone.'),
      duration: Duration(seconds: 2),
      backgroundColor: AppColors.primaryOrange,
    ));
  }

  /// Name the drawn zone and save it.
  Future<void> _saveZoneDraft() async {
    final draft = _zoneDraft;
    if (draft == null || !draft.isSaveable) return;

    final isCircle = draft.shape == ZoneShape.circle;
    final summary = isCircle
        ? '${formatDistance(draft.radiusMetres)} radius  •  ${formatArea(draft.areaSqMetres)}'
        : '${draft.points.length} corners  •  ${formatArea(draft.areaSqMetres)}';

    // Resizing an existing zone keeps its name, category and notes rather
    // than asking for them again; only the shape changed.
    final editingId = draft.editingId;
    if (editingId != null) {
      final existing =
          ref.read(geofenceProvider).geofences.where((z) => z.id == editingId);
      if (existing.isNotEmpty) {
        final was = existing.first;
        final updated = isCircle
            ? was.copyWith(
                latitude: draft.centre!.latitude,
                longitude: draft.centre!.longitude,
                radiusMeters: draft.radiusMetres,
                shape: ZoneShape.circle,
                points: const [],
              )
            : Geofence.polygon(
                id: was.id,
                name: was.name,
                points: draft.points,
                isActive: was.isActive,
                createdAt: was.createdAt,
                category: was.category,
                notes: was.notes,
              );
        await ref.read(geofenceProvider.notifier).updateZone(updated);
        if (!mounted) return;
        setState(() => _zoneDraft = null);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${was.name} resized to $summary'),
          backgroundColor: AppColors.statusGreen,
        ));
        return;
      }
    }

    final details = await showZoneDetailsSheet(context, summary: summary);
    if (details == null || !mounted) return;

    final zones = ref.read(geofenceProvider.notifier);
    if (isCircle) {
      await zones.addGeofence(
        name: details.name,
        latitude: draft.centre!.latitude,
        longitude: draft.centre!.longitude,
        radiusMeters: draft.radiusMetres,
        category: details.category,
        notes: details.notes,
      );
    } else {
      await zones.addPolygonZone(
        name: details.name,
        points: draft.points,
        category: details.category,
        notes: details.notes,
      );
    }

    if (!mounted) return;
    setState(() => _zoneDraft = null);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Zone saved: ${details.name}'),
      backgroundColor: AppColors.statusGreen,
    ));
  }

  /// Drops a normal pin, then reports how far it landed from the user.
  Future<void> _dropNormalPin(LatLng point) async {
    await showWaypointEditor(context, position: point);
    if (!mounted) return;

    // Only announce a distance if a pin actually saved at this spot —
    // backing out of the editor should stay silent.
    final locationState = ref.read(locationProvider);
    final saved = locationState.waypoints.any((w) =>
        w.latitude != null &&
        w.longitude != null &&
        _distM(LatLng(w.latitude!, w.longitude!), point) < 1.0);
    if (!saved) return;

    final lat = locationState.stats.currentLat;
    final lon = locationState.stats.currentLon;
    if (lat == null || lon == null) return;

    final distance = _fmtDist(_distM(LatLng(lat, lon), point));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Pin dropped — $distance from you'),
        backgroundColor: AppColors.statusBlue,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Returns the closest trail within a zoom-adaptive hit radius, or null.
  // Base 0.0012 keeps the pixel-radius ~45px constant across all zoom levels,
  // which is comfortably within a finger-width on both web and mobile.
  Trail? _findNearestTrail(LatLng tap, List<Trail> trails) {
    final threshold =
        0.0012 * math.pow(2, (16 - _currentZoom).clamp(-3.0, 4.0));
    Trail? nearest;
    double nearestDist = double.infinity;
    for (final trail in trails) {
      final points = trail.getWaypoints();
      if (points.isEmpty) continue;
      for (int i = 0; i < points.length; i++) {
        final d = _latlngDeg(tap, points[i]);
        if (d < threshold && d < nearestDist) {
          nearestDist = d;
          nearest = trail;
        }
        if (i < points.length - 1) {
          final sd = _segDeg(tap, points[i], points[i + 1]);
          if (sd < threshold && sd < nearestDist) {
            nearestDist = sd;
            nearest = trail;
          }
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
    final t =
        ((p.longitude - a.longitude) * dx + (p.latitude - a.latitude) * dy) /
            len2;
    final tc = t.clamp(0.0, 1.0);
    final ex = p.longitude - (a.longitude + tc * dx);
    final ey = p.latitude - (a.latitude + tc * dy);
    return math.sqrt(ex * ex + ey * ey);
  }

  List<CircleMarker> _buildDwellCircles(List<Breadcrumb> crumbs) {
    if (crumbs.length < 2) return [];
    final sorted = [...crumbs]..sort((a, b) =>
        (a.timestamp?.millisecondsSinceEpoch ?? 0)
            .compareTo(b.timestamp?.millisecondsSinceEpoch ?? 0));
    const grid = 0.0005; // ~55 m per cell
    final Map<String, _DwellCell> cells = {};
    for (int i = 0; i < sorted.length - 1; i++) {
      final a = sorted[i];
      final b = sorted[i + 1];
      final alat = a.latitude;
      final alon = a.longitude;
      final ats = a.timestamp;
      final bts = b.timestamp;
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

  List<Widget> _buildTrailLayers(TrailState trailState,
      LocationState locationState, NavigationState navState) {
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
              boxShadow: const [
                BoxShadow(color: Colors.black45, blurRadius: 8)
              ],
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
                boxShadow: const [
                  BoxShadow(color: Colors.black45, blurRadius: 4)
                ],
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3), width: 1),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(
                  trailName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
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
        final pts =
            crumbs.map((b) => LatLng(b.latitude!, b.longitude!)).toList();
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
                boxShadow: const [
                  BoxShadow(color: Colors.black45, blurRadius: 4)
                ],
              ),
              child: const Icon(Icons.flag, color: Colors.white, size: 22),
            ),
          ),
        ]));
      }
    }

    return layers;
  }

  // ─── Saved Pins / My Trails ────────────────────────────────────────────
  // Ported from home_screen_layout.dart, which nothing imports — these were
  // wired into that dead screen in 51155c8 so they never reached the app.

  void _showSavedPins() {
    final pins = ref
        .read(locationProvider)
        .waypoints
        .where((w) => w.isPin == true || w.type == WaypointType.manual)
        .toList();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0D1035),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(children: [
                Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2))),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                const Icon(Icons.location_on,
                    color: Color(0xFFFF6D00), size: 20),
                const SizedBox(width: 8),
                Text('SAVED PINS  (${pins.length})',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2)),
              ]),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: pins.isEmpty
                  ? const Center(
                      child: Text(
                          'No pins yet — long-press the map to drop one',
                          style: TextStyle(color: Colors.white38, fontSize: 14),
                          textAlign: TextAlign.center))
                  : ListView.separated(
                      controller: ctrl,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      itemCount: pins.length,
                      separatorBuilder: (_, __) =>
                          const Divider(color: Colors.white12, height: 1),
                      itemBuilder: (_, i) {
                        final w = pins[i];
                        final icon = WaypointIcon.getIconData(w.icon);
                        final color = WaypointColors.fromHex(w.color);
                        final here = _userLatLng();
                        final wPos = (w.latitude != null && w.longitude != null)
                            ? LatLng(w.latitude!, w.longitude!)
                            : null;
                        final distLabel = (here != null && wPos != null)
                            ? _fmtDist(_distM(here, wPos))
                            : null;
                        return ListTile(
                          leading: Icon(icon, color: color, size: 22),
                          title: Text(w.label ?? 'Pin',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 14)),
                          subtitle: wPos != null
                              ? Text(
                                  '${w.latitude!.toStringAsFixed(4)}, ${w.longitude!.toStringAsFixed(4)}'
                                  '${distLabel != null ? '  ·  $distLabel away' : ''}',
                                  style: const TextStyle(
                                      color: Colors.white38, fontSize: 11))
                              : null,
                          trailing: IconButton(
                            tooltip: 'Track to this pin',
                            icon: const Icon(Icons.navigation,
                                color: Color(0xFF4CAF50), size: 20),
                            onPressed: wPos == null
                                ? null
                                : () {
                                    Navigator.pop(ctx);
                                    _startTracking(w);
                                  },
                          ),
                          dense: true,
                          onTap: wPos == null
                              ? null
                              : () {
                                  Navigator.pop(ctx);
                                  _mapController.move(wPos, 15);
                                },
                        );
                      },
                    ),
            ),
          ]),
        ),
      ),
    );
  }

  void _showMyTrails() {
    final trails = ref.read(trailProvider).trails;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.85,
        minChildSize: 0.3,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0D1035),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(children: [
                Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2))),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                const Icon(Icons.route, color: Color(0xFFFF6D00), size: 20),
                const SizedBox(width: 8),
                Text('MY TRAILS  (${trails.length})',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2)),
              ]),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: trails.isEmpty
                  ? const Center(
                      child: Text(
                          'No trails yet — use Trail Creation on the map',
                          style: TextStyle(color: Colors.white38, fontSize: 14),
                          textAlign: TextAlign.center))
                  : ListView.separated(
                      controller: ctrl,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      itemCount: trails.length,
                      separatorBuilder: (_, __) =>
                          const Divider(color: Colors.white12, height: 1),
                      itemBuilder: (_, i) {
                        final t = trails[i];
                        final color = WaypointColors.fromHex(t.color);
                        final pts = t.getWaypoints();
                        return ListTile(
                          leading: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: color, width: 3),
                            ),
                          ),
                          title: Text(t.name ?? 'Trail',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 14)),
                          subtitle: Text('${pts.length} points',
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 11)),
                          trailing: IconButton(
                            icon: const Icon(Icons.fit_screen,
                                color: Colors.white38, size: 18),
                            onPressed: pts.isNotEmpty
                                ? () {
                                    Navigator.pop(ctx);
                                    _mapController.move(pts.first, 14);
                                  }
                                : null,
                          ),
                          dense: true,
                          onTap: pts.isNotEmpty
                              ? () {
                                  Navigator.pop(ctx);
                                  _mapController.move(pts.first, 14);
                                }
                              : null,
                        );
                      },
                    ),
            ),
          ]),
        ),
      ),
    );
  }

  // ─── distance helpers ──────────────────────────────────────────────────

  /// Current position as a LatLng, or null before the first GPS fix.
  LatLng? _userLatLng() {
    final stats = ref.read(locationProvider).stats;
    final lat = stats.currentLat;
    final lon = stats.currentLon;
    return (lat == null || lon == null) ? null : LatLng(lat, lon);
  }

  String _fmtDist(double m) =>
      m >= 1000 ? '${(m / 1000).toStringAsFixed(2)} km' : '${m.toInt()} m';

  double _distM(LatLng a, LatLng b) => const Distance()(a, b);

  /// Small readout above a pin showing how far it is from the user.
  Widget _distanceChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.25),
          width: 0.5,
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
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
            left: 20,
            right: 20,
            top: 20,
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
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Trail name',
                  labelStyle: TextStyle(color: Colors.white54),
                  enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.orange)),
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
                  enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24)),
                ),
                items: TrailColors.allColors
                    .map((c) => DropdownMenuItem(
                          value: c,
                          child: Row(children: [
                            Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                    color: WaypointColors.fromHex(c),
                                    shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Text(c),
                          ]),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => color = v);
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: lineStyle,
                dropdownColor: const Color(0xFF1A1A2E),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Line style',
                  labelStyle: TextStyle(color: Colors.white54),
                  enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24)),
                ),
                items: const [
                  DropdownMenuItem(
                      value: TrailLineStyle.solid, child: Text('Solid')),
                  DropdownMenuItem(
                      value: TrailLineStyle.dashed, child: Text('Dashed')),
                  DropdownMenuItem(
                      value: TrailLineStyle.dotted, child: Text('Dotted')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => lineStyle = v);
                },
              ),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
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
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange),
                    onPressed: () {
                      Navigator.pop(ctx);
                      trail.name = nameCtrl.text.trim().isEmpty
                          ? 'Trail'
                          : nameCtrl.text.trim();
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
    final valid = waypoints
        .where((w) => w.latitude != null && w.longitude != null)
        .toList();
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
      onDelete: () =>
          ref.read(locationProvider.notifier).deleteWaypoint(waypoint.id!),
      onTrack: () => _startTracking(waypoint),
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

  /// Lines from you to each mesh peer whose position we know. This used to be
  /// a hardcoded line between two points near Uluru, drawn whenever mesh was
  /// on — decoration pretending to be a mesh link, 1,000 km from Leonora.
  Widget _buildMeshOverlay() {
    final loc = ref.read(locationProvider).stats;
    final mesh = ref.read(meshProvider);
    if (loc.currentLat == null || loc.currentLon == null) {
      return const SizedBox.shrink();
    }
    final me = LatLng(loc.currentLat!, loc.currentLon!);
    final links = mesh.peerLocations.values
        .where((p) => p.latitude != null && p.longitude != null)
        .map((p) => Polyline(
              points: [me, LatLng(p.latitude!, p.longitude!)],
              color: p.packetType == 'sos'
                  ? AppColors.statusRed
                  : AppColors.primaryOrange,
              strokeWidth: 3.0,
            ))
        .toList();
    if (links.isEmpty) return const SizedBox.shrink();
    return PolylineLayer(polylines: links);
  }

  /// Shown when the only fix available is far too rough to trust. On Android
  /// the usual cause is the location permission being granted as "Approximate"
  /// rather than "Precise", which no amount of waiting will improve.
  Widget _coarseFixChip(double accuracyM) {
    return GestureDetector(
      onTap: () => showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.panelMatte,
          title: const Text('Rough position only',
              style: TextStyle(color: Colors.white, fontSize: 17)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your position is only accurate to about '
                '${accuracyM.round()} m, so the map cannot show which '
                'street you are on.',
                style: TextStyle(color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 12),
              const Text(
                'On Android this usually means location permission is set '
                'to Approximate. Open Settings > Apps > Pinage Maps > '
                'Permissions > Location and choose "Precise".',
                style: TextStyle(color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 12),
              const Text(
                'Otherwise step into the open — GPS cannot see satellites '
                'through a roof.',
                style: TextStyle(color: AppColors.textMuted, height: 1.4),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK',
                  style: TextStyle(color: AppColors.primaryOrange)),
            ),
          ],
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.6)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.gps_not_fixed, color: Colors.orange, size: 16),
          const SizedBox(width: 8),
          Text('Rough fix ±${accuracyM.round()} m — tap',
              style: GoogleFonts.outfit(
                  color: Colors.orange,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }

  /// A quiet marker that the map is filtered, and the way out of it.
  ///
  /// Worded for what was actually done rather than in numbers: "showing
  /// Kookynie only" is a thing someone remembers choosing, where "37 hidden"
  /// is just alarming.
  Widget _filterPill(MarkerVisibility visibility) {
    final scope = visibility.scope;
    final named = ref
        .watch(filesProvider)
        .files
        .where((f) => f.id != null && scope.isSelected(f.id!))
        .map((f) => f.name)
        .toList();
    if (scope.isSelected(FieldFile.unsortedId)) named.add('Unsorted');

    final String label;
    if (visibility.isSoloed) {
      label = 'Showing one marker';
    } else if (scope.isFiltered) {
      // One project is named. Several are counted, because three names do not
      // fit in a pill and a truncated list reads as if the rest were hidden
      // by something other than this.
      if (named.length == 1) {
        label = 'Showing ${named.first} only';
      } else if (named.isEmpty) {
        label = 'Showing ${scope.count} projects';
      } else {
        label = 'Showing ${named.length} projects';
      }
    } else {
      final n = visibility.hiddenCount;
      label = '$n ${n == 1 ? 'marker' : 'markers'} hidden';
    }

    return GestureDetector(
      onTap: () => ref.read(markerVisibilityProvider.notifier).showEverything(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.panelMatte.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.6)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(
              visibility.isScoped
                  ? Icons.folder_open_rounded
                  : Icons.visibility_off_rounded,
              color: AppColors.accent,
              size: 14),
          const SizedBox(width: 7),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 190),
            child: Text(label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          const Text('SHOW ALL',
              style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }

  /// Where you are, and which way you are going.
  ///
  /// The arrow used to be `const Icon(Icons.navigation)` with no rotation
  /// anywhere, so it could only ever point up the map: driving ENE at 61 km/h
  /// it still showed north. It now turns to the GPS course while moving and the
  /// compass while stopped — see travel_heading.dart for which and why.
  ///
  /// With no heading from either sensor it draws the dot alone rather than an
  /// arrow pointing north, because an arrow is a claim about direction and
  /// there is nothing to base one on.
  Widget _userArrow() {
    final heading = _travelHeadingDeg;

    return Stack(
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
        if (heading != null)
          Transform.rotate(
            angle: heading * math.pi / 180,
            child: const Icon(Icons.navigation, color: Colors.white, size: 20),
          ),
      ],
    );
  }

  /// Fetch Mapillary coverage for whatever is on screen.
  ///
  /// Driven off the map's own position changes rather than a timer, so it asks
  /// once the map settles and not while a pan is still moving.
  void _loadStreetCoverage(MapPosition position) {
    if (!ref.read(streetViewProvider).enabled) return;
    final bounds = position.bounds;
    if (bounds == null) return;
    ref.read(streetViewProvider.notifier).loadFor(
          southWest: bounds.southWest,
          northEast: bounds.northEast,
          zoom: position.zoom ?? _currentZoom,
        );
  }

  /// Turn the street-imagery layer on or off.
  ///
  /// Says why when it will not turn on. This is the one online-only feature in
  /// the app, and a toggle that silently does nothing is worse than one that
  /// explains itself.
  Future<void> _toggleStreetView() async {
    final notifier = ref.read(streetViewProvider.notifier);
    await notifier.toggle(zoom: _currentZoom);
    if (!mounted) return;

    final now = ref.read(streetViewProvider);
    if (!now.enabled) {
      if (!now.usable) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(now.reason),
          backgroundColor: AppColors.statusRed,
        ));
      }
      return;
    }

    // Load straight away rather than waiting for the next pan.
    try {
      final camera = _mapController.camera;
      await ref.read(streetViewProvider.notifier).loadFor(
            southWest: camera.visibleBounds.southWest,
            northEast: camera.visibleBounds.northEast,
            zoom: camera.zoom,
          );
    } catch (_) {
      // The map may not be laid out yet; the next pan will pick it up.
    }

    if (!mounted) return;
    final loaded = ref.read(streetViewProvider).photos.length;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(loaded == 0
          ? 'No street photos here — coverage is thin outside the towns'
          : 'Street photos on — $loaded nearby, tap one to open'),
      duration: const Duration(milliseconds: 1800),
      backgroundColor: AppColors.panelMatte,
    ));
  }

  /// Open the street photo nearest where the map was tapped.
  Future<void> _openStreetPhoto(LatLng point) async {
    final photo = await ref.read(streetViewProvider.notifier).photoNear(point);
    if (!mounted) return;
    if (photo == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No street photo within about 60 m of there'),
        duration: Duration(milliseconds: 1500),
      ));
      return;
    }
    await StreetPhotoViewer.open(context, photo);
  }

  /// Swap between satellite providers, in place.
  ///
  /// Says which one it moved to, because the imagery itself is often the only
  /// difference and over bare scrub the two can look alike until you zoom in.
  Future<void> _swapSatelliteSource() async {
    final before = ref.read(satelliteSourceProvider);
    await ref.read(satelliteSourceProvider.notifier).toggle();
    final after = ref.read(satelliteSourceProvider);

    if (!mounted) return;
    if (after == before) {
      // Only happens when the other source has no token in this build.
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Mapbox needs a token in config/pinage.json — '
            'staying on ESRI.'),
        backgroundColor: AppColors.statusRed,
      ));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Satellite: ${after.label}  ·  to zoom '
          '${after.maxNativeZoom}'),
      duration: const Duration(milliseconds: 1600),
      backgroundColor: AppColors.panelMatte,
    ));
  }

  /// Round button matching the compass rose and the other map controls.
  Widget _locateButton(LocationState locationState) {
    final mode = _locateMode;
    final live = mode != LocateMode.off;
    final hasFix = locationState.stats.currentLat != null;

    return GestureDetector(
      onTap: () => _cycleLocateMode(locationState),
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.panelMatte.withValues(alpha: 0.92),
          shape: BoxShape.circle,
          border: Border.all(
            color: live
                ? AppColors.accent.withValues(alpha: 0.9)
                : Colors.white.withValues(alpha: 0.12),
            width: live ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Center(
          child: Icon(
            mode.icon,
            size: 24,
            color: !hasFix
                ? AppColors.textMuted
                : live
                    ? AppColors.accent
                    : Colors.white70,
          ),
        ),
      ),
    );
  }

  void _cycleLocateMode(LocationState locationState) {
    final lat = locationState.stats.currentLat;
    final lon = locationState.stats.currentLon;
    if (lat == null || lon == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No GPS fix yet — nothing to centre on.'),
        backgroundColor: AppColors.statusRed,
      ));
      return;
    }

    final next = _locateMode.next;
    setState(() => _locateMode = next);

    // Every mode puts you back in the middle; only the follow modes keep you
    // there.
    _mapController.move(
        LatLng(lat, lon), math.max(_mapController.camera.zoom, 16.0));

    if (next.rotatesMap) {
      final heading = _travelHeadingDeg;
      if (heading != null) _mapController.rotate(-heading);
    } else {
      _mapController.rotate(0);
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(next.label),
      duration: const Duration(milliseconds: 1200),
      backgroundColor: AppColors.panelMatte,
    ));
  }

  /// Work out which way the arrow and, in heading-up, the map should point.
  void _updateTravelHeading(LocationState next) {
    final now = DateTime.now();
    final dt = _lastTravelSample == null
        ? 0.2
        : (now.difference(_lastTravelSample!).inMilliseconds / 1000)
            .clamp(0.02, 2.0);
    _lastTravelSample = now;

    final stats = next.stats;
    final compass = ref.read(headingProvider).valueOrNull;
    final declination = (stats.currentLat != null && stats.currentLon != null)
        ? MagneticDeclination.forPosition(stats.currentLat!, stats.currentLon!)
        : 0.0;

    final out = _travel.update(
      speedMs: stats.currentSpeedMs,
      dt: dt,
      gpsCourseDeg: stats.currentCourseDeg,
      compassDeg: compass != null && compass.isLive ? compass.degrees : null,
      declinationDeg: declination,
    );

    if (out == null || !mounted) return;
    // A tenth of a degree is a third of a pixel on the arrow; redrawing the
    // whole map for that is wasted work.
    if (_travelHeadingDeg != null && (out - _travelHeadingDeg!).abs() < 0.5) {
      return;
    }
    setState(() => _travelHeadingDeg = out);
  }

  /// Pull the map back to the user, and turn it if asked.
  void _followIfAsked(LocationState next) {
    if (!_locateMode.isFollowing) return;
    final lat = next.stats.currentLat;
    final lon = next.stats.currentLon;
    if (lat == null || lon == null) return;

    _mapController.move(LatLng(lat, lon), _mapController.camera.zoom);
    if (_locateMode.rotatesMap && _travelHeadingDeg != null) {
      _mapController.rotate(-_travelHeadingDeg!);
    }
  }

  Widget _noGpsFixChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.6)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.gps_not_fixed, color: Colors.orange, size: 16),
        const SizedBox(width: 8),
        Text('No GPS fix yet',
            style: GoogleFonts.outfit(
                color: Colors.orange,
                fontSize: 13,
                fontWeight: FontWeight.w700)),
      ]),
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
                border: Border.all(
                    color: AppColors.primaryOrange.withValues(alpha: 0.4)),
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
  final VoidCallback onSavedPins;
  final VoidCallback onMyTrails;
  final VoidCallback onFiles;
  final VoidCallback onMarkerPicker;

  /// Street-level imagery. Carries its own state and reason because it is the
  /// one thing in this menu that cannot work offline.
  final VoidCallback onStreetView;
  final bool streetViewOn;
  final String streetViewReason;

  /// How many pins and zones are currently hidden from view.
  final int hiddenCount;

  /// The open field file's name, or null when none is open.
  final String? openFileName;
  final VoidCallback onDrawZone;
  final VoidCallback onDrawLine;
  final VoidCallback onDrawFreehand;
  final VoidCallback onZones;
  final int zoneCount;
  final bool deadmanArmed;

  /// False when storage fell back to memory: nothing survives a refresh.
  final bool storageOk;
  final String storageNote;
  final VoidCallback onToggleDeadman;
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
    required this.onSavedPins,
    required this.onMyTrails,
    required this.onFiles,
    required this.onMarkerPicker,
    required this.onStreetView,
    required this.streetViewOn,
    required this.streetViewReason,
    required this.hiddenCount,
    required this.openFileName,
    required this.onDrawZone,
    required this.onDrawLine,
    required this.onDrawFreehand,
    required this.onZones,
    required this.zoneCount,
    required this.deadmanArmed,
    required this.storageOk,
    required this.storageNote,
    required this.onToggleDeadman,
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
          boxShadow: [
            BoxShadow(
                color: Colors.black54, blurRadius: 24, offset: Offset(8, 0))
          ],
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
                      _item(
                          context,
                          Icons.landscape,
                          const Color(0xFFFF8C00),
                          'Terrain Layer',
                          is3DMode ? '3D active' : '2D view',
                          'Switch between flat 2D tactical view and immersive 3D terrain rendering.',
                          () => _go(onToggle3D)),
                      _item(
                          context,
                          Icons.layers,
                          const Color(0xFF9C60F0),
                          'Layer Manager',
                          'Cycle map style',
                          'Cycle through Street, Satellite (Esri), Dark, and Topo map styles.',
                          () => _go(onLayerManager)),

                      _section('NAVIGATION'),
                      _item(
                          context,
                          Icons.my_location,
                          const Color(0xFF2196F3),
                          'Re-centre GPS',
                          'Jump to my location',
                          'Centres the map on your current GPS position at zoom 16.',
                          () => _go(onRecenter)),
                      _item(
                          context,
                          Icons.add,
                          const Color(0xFF4CAF50),
                          'Zoom In',
                          'Increase detail',
                          'Zoom in one level for more map detail.',
                          () => _go(onZoomIn)),
                      _item(
                          context,
                          Icons.remove,
                          const Color(0xFFF44336),
                          'Zoom Out',
                          'Decrease detail',
                          'Zoom out one level to see a wider area.',
                          () => _go(onZoomOut)),
                      _item(
                          context,
                          Icons.fit_screen,
                          const Color(0xFF00BCD4),
                          'Scan Bounds',
                          'Fit all waypoints',
                          'Zooms and pans to show all your saved waypoints on screen at once.',
                          () => _go(onScanBounds)),

                      _section('TRACKING'),
                      _item(
                          context,
                          Icons.route,
                          const Color(0xFF2196F3),
                          'Breadcrumb Trail',
                          showBreadcrumbs
                              ? 'Trail on · RETRACE shown'
                              : 'Show your path',
                          'Records and displays your movement path. Shows RETRACE and CLEAR controls on the map.',
                          () => _go(onToggleBreadcrumbs)),
                      _item(
                          context,
                          Icons.thermostat,
                          const Color(0xFFFFB300),
                          'Dwell Heatmap',
                          showDwellMap ? 'Heatmap on' : 'Show dwell heatmap',
                          'Shows where you spent the most time. Yellow = brief stop, Red = long stay.',
                          () => _go(onElevationProfile)),
                      _item(
                          context,
                          Icons.add_location_alt,
                          const Color(0xFF4CAF50),
                          'Add Waypoint',
                          'Drop a pin',
                          'Drop a waypoint marker at the current map centre.',
                          () => _go(onAddWaypoint)),
                      _item(
                          context,
                          Icons.timeline,
                          const Color(0xFF9C60F0),
                          'Track Record',
                          isCreatingTrail ? 'Recording…' : 'Record a trail',
                          'Activate trail recording mode — tap the map to drop route points.',
                          () => _go(onTrackRecord)),
                      _item(
                          context,
                          Icons.analytics,
                          const Color(0xFF2196F3),
                          'Export Track',
                          'Trip stats & export',
                          'View trip statistics, distance, speed and export your track data.',
                          () => _go(onExportTrack)),

                      _section('MY DATA'),
                      _item(
                          context,
                          Icons.location_on,
                          const Color(0xFFFF6D00),
                          'Saved Pins',
                          'All your dropped pins',
                          'Every pin you have dropped, with its distance from you. Tap one to jump to it on the map.',
                          () => _go(onSavedPins)),
                      _item(
                          context,
                          Icons.route,
                          const Color(0xFFFF6D00),
                          'My Trails',
                          'Recorded trails',
                          'Every trail you have recorded. Tap one to jump to its starting point.',
                          () => _go(onMyTrails)),

                      _item(
                          context,
                          Icons.folder_rounded,
                          const Color(0xFFFF6B00),
                          'Files',
                          openFileName == null
                              ? 'Notes and field records'
                              : 'Open: $openFileName',
                          'A folder per job, site or trip. While a file is open, every note, pin and zone you make is filed under it, so you can come back and see where you worked.',
                          () => _go(onFiles)),

                      _item(
                          context,
                          Icons.visibility,
                          const Color(0xFF00BCD4),
                          'Show & Follow',
                          hiddenCount == 0
                              ? 'Choose what is drawn'
                              : '$hiddenCount hidden',
                          'Pick which pins and zones appear on the map and through the camera, and choose one to follow. Hiding never deletes anything.',
                          () => _go(onMarkerPicker)),
                      // Greyed out rather than hidden when it cannot work: a
                      // missing row looks like a missing feature, while a
                      // disabled one with a reason explains itself.
                      _item(
                          context,
                          Icons.streetview,
                          streetViewReason.isEmpty
                              ? const Color(0xFF05CB63)
                              : AppColors.textMuted,
                          'Street Photos',
                          streetViewReason.isNotEmpty
                              ? streetViewReason
                              : streetViewOn
                                  ? 'On — tap the map to open one'
                                  : 'Mapillary street-level imagery',
                          'Street-level photos contributed to Mapillary. The '
                              'only part of this app that needs a connection: '
                              'coverage is thin outside the towns, and nothing is '
                              'stored on the phone.',
                          () => _go(onStreetView)),

                      _section('ZONES'),
                      _item(
                          context,
                          Icons.draw,
                          const Color(0xFFFF6B00),
                          'Draw Zone',
                          'Flag an area',
                          'Draw a circle, or tap out a boundary corner by corner around a site, hazard or heritage area. You get told when you cross in or out of it.',
                          () => _go(onDrawZone)),
                      _item(
                          context,
                          Icons.timeline,
                          const Color(0xFFFF6B00),
                          'Draw Line',
                          'Measure and mark a line',
                          'Tap out a line point by point. Every leg shows its length and bearing, and a tap near a pin snaps to it. Long-press a saved line to edit or delete it.',
                          () => _go(onDrawLine)),
                      _item(
                          context,
                          Icons.gesture,
                          const Color(0xFFFF6B00),
                          'Draw Freehand',
                          'Sketch on the map',
                          'Draw with your finger: a burn edge, a washout, a route you mean to take. Switch to Pan to move the map between strokes; Undo takes off the last stroke.',
                          () => _go(onDrawFreehand)),
                      _item(
                          context,
                          Icons.layers_outlined,
                          const Color(0xFFAB47BC),
                          'My Zones',
                          zoneCount == 0 ? 'No zones yet' : '$zoneCount saved',
                          'Every zone and boundary you have flagged. Tap one to jump to it on the map.',
                          () => _go(onZones)),

                      _section('TOOLS'),
                      _item(
                          context,
                          Icons.straighten,
                          const Color(0xFF00BCD4),
                          'Measure Distance',
                          showMeasurementTool ? 'Active' : 'Tap to measure',
                          'Tap points on the map to measure distance, area, and bearing.',
                          () => _go(onMeasure)),
                      _item(
                          context,
                          Icons.screenshot,
                          Colors.white70,
                          'Map Screenshot',
                          'Save as PNG',
                          'Saves the current map view as a PNG image to your device.',
                          () => _go(onScreenshot)),
                      _item(
                          context,
                          Icons.pin_drop,
                          const Color(0xFFFFB300),
                          'Enter Coordinates',
                          'Go to GPS location',
                          'Manually enter GPS coordinates in decimal, DMS, or UTM format to jump to a location.',
                          () => _go(onDeviceInfo)),
                      _item(
                          context,
                          Icons.directions,
                          const Color(0xFF2196F3),
                          'Navigation Mode',
                          'Route guidance',
                          'Get turn-by-turn directions to any destination using OSRM routing.',
                          () => _go(onNavigation)),
                      _item(
                          context,
                          Icons.psychology,
                          const Color(0xFF9C60F0),
                          'AI Assistant',
                          'Natural language search',
                          'Search in plain English — "nearest water source" or "fuel under 50 km".',
                          () => _go(onAIAssistant)),
                      _item(
                          context,
                          Icons.place,
                          const Color(0xFF4CAF50),
                          'Search Place',
                          'Find places & POIs',
                          'Search for towns, landmarks, and points of interest near you.',
                          () => _go(onSearchPlace)),
                      _item(
                          context,
                          Icons.compass_calibration,
                          const Color(0xFFFF8C00),
                          'Compass Nav',
                          'AR compass overlay',
                          'Augmented reality compass overlay on your device camera view.',
                          () => _go(onCompassNav)),
                      _item(
                          context,
                          Icons.download_for_offline,
                          const Color(0xFF00BCD4),
                          'Offline Maps',
                          'Download map regions',
                          'Download map regions for use without an internet connection.',
                          () => _go(onMeshSignal)),

                      _section('MEDIA'),
                      _item(
                          context,
                          Icons.photo_library,
                          const Color(0xFFFFB300),
                          'Photo Gallery',
                          'Geotagged photos',
                          'Browse all geotagged photos — tap the pin icon to jump to that location on the map.',
                          () => _go(onGallery)),

                      _section('SYSTEM'),
                      _item(
                          context,
                          Icons.settings,
                          Colors.grey,
                          'Settings',
                          'App preferences',
                          'Configure vehicle profile, privacy settings, and app preferences.',
                          () => _go(onSettings)),
                      _item(
                          context,
                          Icons.support_agent_rounded,
                          const Color(0xFF9C60F0),
                          'Analytics',
                          'AI personas',
                          'Select your AI persona — Scout, Navigator, Rescue, or Tactical.',
                          () => _go(onAnalytics)),

                      _section('SAFETY'),
                      _item(
                          context,
                          Icons.timer_outlined,
                          deadmanArmed ? Colors.red : Colors.white70,
                          'Deadman Switch',
                          deadmanArmed
                              ? 'ARMED — auto-SOS after 4h still'
                              : 'Off — tap to arm',
                          "Arm it before heading out alone. If you don't move for 4 hours you get a spoken warning, then an SOS goes to nearby BushTrack phones 10 minutes later. Walk a few metres to cancel.",
                          () => _go(onToggleDeadman)),

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
        border: Border(
            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: Row(children: [
        ShaderMask(
          shaderCallback: (b) => const LinearGradient(
            colors: [Color(0xFFFF8C00), Color(0xFFFF6A00)],
          ).createShader(b),
          child: const Icon(Icons.explore, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('BUSHTRACK',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    letterSpacing: 1)),
            // Which build is running, and whether anything saved will still
            // be here after a refresh. Both are invisible otherwise — a
            // stale copy and a memory-only session look completely normal.
            Text(
              storageOk
                  ? 'build $kBuildId · $storageNote'
                  : 'build $kBuildId · NOT SAVING',
              style: TextStyle(
                  color: storageOk ? Colors.white38 : const Color(0xFFFF6D00),
                  fontSize: 10),
            ),
          ],
        ),
        const Spacer(),
        GestureDetector(
          onTap: onClose,
          child: Container(
            width: 32,
            height: 32,
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
                color: Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 2)),
      );

  Widget _item(BuildContext context, IconData icon, Color color, String name,
      String subtitle, String description, VoidCallback onTap) {
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
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
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
          content: Text('Press and hold to open SOS.'),
          duration: Duration(seconds: 2),
          backgroundColor: Color(0xFFFF2D55),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFF2D55).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: const Color(0xFFFF2D55).withValues(alpha: 0.4)),
        ),
        child: Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFFF2D55).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.sos, color: Color(0xFFFF2D55), size: 19),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Was "SOS — 505": leetspeak that reads like a number to dial.
              Text('SOS',
                  style: TextStyle(
                      color: Color(0xFFFF2D55),
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      letterSpacing: 0.5)),
              Text('Press and hold · call 000 · mesh · SMS',
                  style: TextStyle(
                      color: Color(0xFFFF2D55),
                      fontSize: 10,
                      fontWeight: FontWeight.w500)),
            ]),
          ),
          _infoBtn(context, 'SOS',
              'Press and hold in this menu, or hold the red SOS button on the map for 3 seconds. You can call 000 straight from the SOS screen — do that first if you have signal. The SOS also broadcasts your GPS position to BushTrack phones in radio range (Android app only), and opens an SMS and share sheet with your location for you to send. USE ONLY IN A GENUINE EMERGENCY.',
              isRed: true),
        ]),
      ),
    );
  }

  static Widget _infoBtn(BuildContext context, String title, String desc,
      {required bool isRed}) {
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
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15)),
          // Scrollable: a long description used to overflow the dialog and
          // render behind the OK button, with no way to reach the rest of it.
          content: SingleChildScrollView(
            child: Text(desc,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 13, height: 1.5)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  const Text('OK', style: TextStyle(color: Color(0xFFFF8C00))),
            ),
          ],
        ),
      ),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: const Color(0xFF0D0F1E),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: isRed
                ? const Color(0xFFFF2D55).withValues(alpha: 0.6)
                : const Color(0xFF9C60F0).withValues(alpha: 0.5),
          ),
        ),
        child: Icon(Icons.info_outline,
            size: 14,
            color: isRed ? const Color(0xFFFF2D55) : const Color(0xFFC9A8FF)),
      ),
    );
  }
}
