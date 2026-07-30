import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/models/breadcrumb.dart';
import '../../../core/models/waypoint.dart';
import '../../../core/services/database_service.dart';
import '../../map/services/offline_map_manager.dart';
import '../../../main.dart';

// Use the database service provider from main.dart for cross-platform support

class TrackStats {
  final double distanceMeters;
  final double currentSpeedMs;
  final double currentAccuracyM;
  final Duration elapsed;
  final double? currentLat;
  final double? currentLon;
  final double? currentAltitude;

  const TrackStats({
    this.distanceMeters = 0,
    this.currentSpeedMs = 0,
    this.currentAccuracyM = 0,
    this.elapsed = Duration.zero,
    this.currentLat,
    this.currentLon,
    this.currentAltitude,
  });

  String get distanceFormatted {
    if (distanceMeters < 1000) return '${distanceMeters.toStringAsFixed(0)}m';
    return '${(distanceMeters / 1000).toStringAsFixed(2)}km';
  }

  String get speedFormatted =>
      '${(currentSpeedMs * 3.6).toStringAsFixed(1)} km/h';

  String get gpsAccuracyFormatted {
    if (currentAccuracyM <= 0) return 'GPS: --';
    return currentAccuracyM < 10
        ? 'GPS: ±${currentAccuracyM.toStringAsFixed(0)}m'
        : 'GPS: ±${currentAccuracyM.toStringAsFixed(0)}m (poor)';
  }

  String get elapsedFormatted {
    final h = elapsed.inHours;
    final m = elapsed.inMinutes.remainder(60);
    final s = elapsed.inSeconds.remainder(60);
    return h > 0 ? '${h}h ${m}m' : '${m}m ${s}s';
  }

  String get coordsDecimal {
    if (currentLat == null || currentLon == null) return 'Acquiring GPS...';
    return '${currentLat!.toStringAsFixed(6)}, ${currentLon!.toStringAsFixed(6)}';
  }

  String get coordsDMS {
    if (currentLat == null || currentLon == null) return 'Acquiring GPS...';
    return '${_toDMS(currentLat!, 'NS')} ${_toDMS(currentLon!, 'EW')}';
  }

  static String _toDMS(double decimal, String dirs) {
    final dir = decimal >= 0 ? dirs[0] : dirs[1];
    final abs = decimal.abs();
    final deg = abs.floor();
    final minFull = (abs - deg) * 60;
    final min = minFull.floor();
    final sec = (minFull - min) * 60;
    return "$deg° $min' ${sec.toStringAsFixed(1)}\" $dir";
  }

  TrackStats copyWith({
    double? distanceMeters,
    double? currentSpeedMs,
    double? currentAccuracyM,
    Duration? elapsed,
    double? currentLat,
    double? currentLon,
    double? currentAltitude,
  }) {
    return TrackStats(
      distanceMeters: distanceMeters ?? this.distanceMeters,
      currentSpeedMs: currentSpeedMs ?? this.currentSpeedMs,
      currentAccuracyM: currentAccuracyM ?? this.currentAccuracyM,
      elapsed: elapsed ?? this.elapsed,
      currentLat: currentLat ?? this.currentLat,
      currentLon: currentLon ?? this.currentLon,
      currentAltitude: currentAltitude ?? this.currentAltitude,
    );
  }
}

class LocationState {
  final List<Waypoint> waypoints;
  final List<Breadcrumb> breadcrumbs;
  final TrackStats stats;

  const LocationState({
    this.waypoints = const [],
    this.breadcrumbs = const [],
    this.stats = const TrackStats(),
  });

  LocationState copyWith(
      {List<Waypoint>? waypoints,
      List<Breadcrumb>? breadcrumbs,
      TrackStats? stats}) {
    return LocationState(
      waypoints: waypoints ?? this.waypoints,
      breadcrumbs: breadcrumbs ?? this.breadcrumbs,
      stats: stats ?? this.stats,
    );
  }
}

enum _TrackingProfile { highAccuracy, balanced, navigation, batterySaver }

class LocationNotifier extends StateNotifier<LocationState> {
  final DatabaseService databaseService;
  StreamSubscription<Position>? _positionSub;
  Timer? _elapsedTimer;
  Timer? _mockTimer;
  Timer? _breadcrumbTimer;
  Position? _lastPosition;
  final List<Position> _recentPositions = <Position>[];
  double _totalDistance = 0;
  DateTime? _trackStart;
  DateTime? _lastEmissionAt;
  DateTime? _stationarySince;
  bool _batterySaver = false;
  _TrackingProfile _profile = _TrackingProfile.highAccuracy;
  final String _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
  bool _autoRegionTriggered = false;

  LocationNotifier(this.databaseService) : super(const LocationState()) {
    _loadWaypoints();
    _loadBreadcrumbs();
    _startGpsTracking();
    _startElapsedTimer();
    _startBreadcrumbTimer();
  }

  Future<void> _loadWaypoints() async {
    try {
      final List<Map<String, dynamic>> maps =
          await databaseService.getWaypoints();
      final waypoints = maps.map((map) => Waypoint.fromMap(map)).toList();
      state = state.copyWith(waypoints: waypoints);
    } catch (e) {
      debugPrint('Error loading waypoints: $e');
    }
  }

  Future<void> _loadBreadcrumbs() async {
    try {
      final List<Map<String, dynamic>> maps =
          await databaseService.getBreadcrumbs(_sessionId);
      final breadcrumbs = maps.map((map) => Breadcrumb.fromMap(map)).toList();
      state = state.copyWith(breadcrumbs: breadcrumbs);
    } catch (e) {
      debugPrint('Error loading breadcrumbs: $e');
    }
  }

  Future<void> _startGpsTracking() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _startMockTracking();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) {
      _startMockTracking();
      return;
    }

    _trackStart = DateTime.now();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
      ),
    ).listen((Position position) {
      _onNewPosition(position);
    });
  }

  void _onNewPosition(Position position) async {
    _recentPositions.add(position);
    if (_recentPositions.length > 5) {
      _recentPositions.removeAt(0);
    }

    final averaged = _averageRecentPosition();
    final now = DateTime.now();
    final speedKmh = (averaged.speed < 0 ? 0.0 : averaged.speed) * 3.6;
    final nextProfile = _profileForSpeed(speedKmh);
    _updateTrackingProfile(nextProfile);

    final shouldEmit = _lastEmissionAt == null ||
        now.difference(_lastEmissionAt!) >=
            _updateIntervalForProfile(nextProfile);

    if (!shouldEmit) {
      return;
    }

    _lastEmissionAt = now;

    // Calculate incremental distance
    if (_lastPosition != null) {
      final dist = Geolocator.distanceBetween(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        averaged.latitude,
        averaged.longitude,
      );
      _totalDistance += dist;
    }
    // Trigger auto region download on very first GPS fix (mobile only)
    if (!kIsWeb && !_autoRegionTriggered && _lastPosition == null) {
      _autoRegionTriggered = true;
      _maybeAutoDownloadRegion(averaged.latitude, averaged.longitude);
    }

    _lastPosition = averaged;

    if (speedKmh < 2.0) {
      _stationarySince ??= now;
      if (!_batterySaver && now.difference(_stationarySince!).inMinutes >= 5) {
        _batterySaver = true;
      }
    } else {
      _stationarySince = null;
      _batterySaver = false;
    }

    final elapsed = _trackStart != null
        ? DateTime.now().difference(_trackStart!)
        : Duration.zero;

    state = state.copyWith(
      stats: state.stats.copyWith(
        distanceMeters: _totalDistance,
        currentSpeedMs: averaged.speed < 0 ? 0 : averaged.speed,
        currentAccuracyM: averaged.accuracy,
        elapsed: elapsed,
        currentLat: averaged.latitude,
        currentLon: averaged.longitude,
        currentAltitude: averaged.altitude,
      ),
    );

    // Save breadcrumb trail separately from user pins.
    final breadcrumb = Breadcrumb(
      latitude: averaged.latitude,
      longitude: averaged.longitude,
      altitude: averaged.altitude,
      accuracy: averaged.accuracy,
      speed: averaged.speed,
      timestamp: now,
      sessionId: _sessionId,
    );
    await databaseService.insertBreadcrumb(breadcrumb.toMap());
    await _loadBreadcrumbs();

    // Also save a track waypoint for compatibility with existing route logic.
    final waypoint = Waypoint(
      latitude: averaged.latitude,
      longitude: averaged.longitude,
      altitude: averaged.altitude,
      accuracy: averaged.accuracy,
      speed: averaged.speed,
      timestamp: now,
      label: 'Track',
      type: WaypointType.track,
    );

    await databaseService.insertWaypoint(waypoint.toMap());
    _loadWaypoints();
  }

  Future<void> _maybeAutoDownloadRegion(double lat, double lon) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final done = prefs.getBool('auto_region_downloaded') ?? false;
      if (done) return;
      await prefs.setBool('auto_region_downloaded', true);
      await OfflineMapManager().autoDetectAndDownloadRegion(LatLng(lat, lon));
    } catch (e) {
      debugPrint('Auto region detection error: $e');
    }
  }

  Position _averageRecentPosition() {
    final samples = _recentPositions.isEmpty
        ? <Position>[_lastPosition ?? _recentPositions.last]
        : _recentPositions;
    double lat = 0;
    double lon = 0;
    double alt = 0;
    double acc = 0;
    double speed = 0;
    double speedAccuracy = 0;
    double heading = 0;
    double headingAccuracy = 0;
    for (final p in samples) {
      lat += p.latitude;
      lon += p.longitude;
      alt += p.altitude;
      acc += p.accuracy;
      speed += p.speed < 0 ? 0 : p.speed;
      speedAccuracy += p.speedAccuracy;
      heading += p.heading;
      headingAccuracy += p.headingAccuracy;
    }
    final count = samples.length;
    return Position(
      latitude: lat / count,
      longitude: lon / count,
      timestamp: DateTime.now(),
      accuracy: acc / count,
      altitude: alt / count,
      altitudeAccuracy: 0,
      heading: heading / count,
      headingAccuracy: headingAccuracy / count,
      speed: speed / count,
      speedAccuracy: speedAccuracy / count,
      floor: null,
      isMocked: samples.last.isMocked,
    );
  }

  _TrackingProfile _profileForSpeed(double speedKmh) {
    if (_batterySaver) return _TrackingProfile.batterySaver;
    if (speedKmh < 2) return _TrackingProfile.highAccuracy;
    if (speedKmh <= 30) return _TrackingProfile.balanced;
    return _TrackingProfile.navigation;
  }

  Duration _updateIntervalForProfile(_TrackingProfile profile) {
    switch (profile) {
      case _TrackingProfile.highAccuracy:
      case _TrackingProfile.navigation:
        return const Duration(seconds: 1);
      case _TrackingProfile.balanced:
        return const Duration(seconds: 3);
      case _TrackingProfile.batterySaver:
        return const Duration(seconds: 30);
    }
  }

  void _updateTrackingProfile(_TrackingProfile profile) {
    if (profile == _profile) return;
    _profile = profile;
  }

  void _startMockTracking() {
    // Fallback mock for emulator/no GPS
    double lat = -25.3444;
    double lon = 131.0369;
    _trackStart = DateTime.now();

    _mockTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      lat += 0.0001;
      lon += 0.0001;

      final fakePosition = Position(
        latitude: lat,
        longitude: lon,
        altitude: 450.0,
        altitudeAccuracy: 5.0,
        accuracy: 5.0,
        speed: 1.4,
        speedAccuracy: 1.0,
        heading: 45.0,
        headingAccuracy: 5.0,
        timestamp: DateTime.now(),
        floor: null,
        isMocked: true,
      );
      _onNewPosition(fakePosition);
    });
  }

  void _startElapsedTimer() {
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_trackStart != null) {
        state = state.copyWith(
          stats: state.stats.copyWith(
            elapsed: DateTime.now().difference(_trackStart!),
          ),
        );
      }
    });
  }

  /// Saves a breadcrumb every 30 seconds regardless of movement distance,
  /// fulfilling the "record position every 30 seconds automatically" requirement.
  void _startBreadcrumbTimer() {
    _breadcrumbTimer =
        Timer.periodic(const Duration(seconds: 30), (_) async {
      final lat = state.stats.currentLat;
      final lon = state.stats.currentLon;
      if (lat == null || lon == null) return;
      final crumb = Breadcrumb(
        latitude: lat,
        longitude: lon,
        altitude: state.stats.currentAltitude ?? 0,
        accuracy: state.stats.currentAccuracyM,
        speed: state.stats.currentSpeedMs,
        timestamp: DateTime.now(),
        sessionId: _sessionId,
      );
      await databaseService.insertBreadcrumb(crumb.toMap());
      await _loadBreadcrumbs();
    });
  }

  Future<void> addManualWaypoint(double lat, double lon, String label,
      {String? notes, String? color, String? icon, int? order}) async {
    final waypoint = Waypoint(
      latitude: lat,
      longitude: lon,
      timestamp: DateTime.now(),
      label: label,
      notes: notes,
      type: WaypointType.manual,
      color: color ?? WaypointColors.emberOrange,
      icon: icon ?? WaypointIcon.pin,
      order: order,
      isPin: true,
    );

    await databaseService.insertWaypoint(waypoint.toMap());
    _loadWaypoints();
  }

  /// Drop a pin at the given location with an attached photo.
  Future<Waypoint> addPhotoWaypoint({
    required double lat,
    required double lon,
    required String photoPath,
    required String thumbnailPath,
    String? label,
    String? notes,
    double? altitude,
  }) async {
    final waypoint = Waypoint(
      latitude: lat,
      longitude: lon,
      altitude: altitude,
      timestamp: DateTime.now(),
      label: label ?? 'Photo Pin',
      notes: notes,
      type: WaypointType.manual,
      color: WaypointColors.neonCyan,
      icon: WaypointIcon.pin,
      isPin: true,
      photoPaths: [photoPath],
      thumbnailPath: thumbnailPath,
    );

    await databaseService.insertWaypoint(waypoint.toMap());
    _loadWaypoints();
    return waypoint;
  }

  Future<void> updateWaypoint(Waypoint waypoint) async {
    await databaseService.updateWaypoint(waypoint.toMap());
    _loadWaypoints();
  }

  Future<void> deleteWaypoint(int id) async {
    await databaseService.deleteWaypoint(id);
    _loadWaypoints();
  }

  Future<void> deleteAllWaypoints() async {
    await databaseService.deleteAllWaypoints();
    _loadWaypoints();
  }

  /// Update waypoint position (for drag and drop)
  Future<void> updateWaypointPosition(int id, double lat, double lon) async {
    final waypoints = state.waypoints;
    final waypoint = waypoints.firstWhere(
      (w) => w.id == id,
      orElse: () => throw Exception('Waypoint not found'),
    );

    final updated = Waypoint(
      id: waypoint.id,
      latitude: lat,
      longitude: lon,
      altitude: waypoint.altitude,
      accuracy: waypoint.accuracy,
      speed: waypoint.speed,
      label: waypoint.label,
      notes: waypoint.notes,
      timestamp: waypoint.timestamp,
      type: waypoint.type,
      photoPaths: waypoint.photoPaths,
      thumbnailPath: waypoint.thumbnailPath,
      color: waypoint.color,
      icon: waypoint.icon,
      order: waypoint.order,
      isPin: waypoint.isPin,
    );

    await updateWaypoint(updated);
  }

  /// Update waypoint color
  Future<void> updateWaypointColor(int id, String color) async {
    final waypoints = state.waypoints;
    final waypoint = waypoints.firstWhere(
      (w) => w.id == id,
      orElse: () => throw Exception('Waypoint not found'),
    );

    final updated = Waypoint(
      id: waypoint.id,
      latitude: waypoint.latitude,
      longitude: waypoint.longitude,
      altitude: waypoint.altitude,
      accuracy: waypoint.accuracy,
      speed: waypoint.speed,
      label: waypoint.label,
      notes: waypoint.notes,
      timestamp: waypoint.timestamp,
      type: waypoint.type,
      photoPaths: waypoint.photoPaths,
      thumbnailPath: waypoint.thumbnailPath,
      color: color,
      icon: waypoint.icon,
      order: waypoint.order,
      isPin: waypoint.isPin,
    );

    await updateWaypoint(updated);
  }

  /// Update waypoint icon
  Future<void> updateWaypointIcon(int id, String icon) async {
    final waypoints = state.waypoints;
    final waypoint = waypoints.firstWhere(
      (w) => w.id == id,
      orElse: () => throw Exception('Waypoint not found'),
    );

    final updated = Waypoint(
      id: waypoint.id,
      latitude: waypoint.latitude,
      longitude: waypoint.longitude,
      altitude: waypoint.altitude,
      accuracy: waypoint.accuracy,
      speed: waypoint.speed,
      label: waypoint.label,
      notes: waypoint.notes,
      timestamp: waypoint.timestamp,
      type: waypoint.type,
      photoPaths: waypoint.photoPaths,
      thumbnailPath: waypoint.thumbnailPath,
      color: waypoint.color,
      icon: icon,
      order: waypoint.order,
      isPin: waypoint.isPin,
    );

    await updateWaypoint(updated);
  }

  /// Set battery saver mode - reduce GPS update frequency
  void setBatterySaverMode(bool enabled) {
    _batterySaver = enabled;
    _updateTrackingProfile(enabled
        ? _TrackingProfile.batterySaver
        : _profileForSpeed(state.stats.currentSpeedMs * 3.6));
  }

  Future<void> clearBreadcrumbs() async {
    await databaseService.clearBreadcrumbs(_sessionId);
    state = state.copyWith(breadcrumbs: []);
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _elapsedTimer?.cancel();
    _mockTimer?.cancel();
    _breadcrumbTimer?.cancel();
    super.dispose();
  }
}

final locationProvider =
    StateNotifierProvider<LocationNotifier, LocationState>((ref) {
  final databaseService = ref.watch(databaseServiceProvider);
  return LocationNotifier(databaseService);
});
