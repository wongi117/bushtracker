import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/models/breadcrumb.dart';
import '../../../core/models/waypoint.dart';
import '../../../core/services/database_service.dart';
import '../../../core/utils/startup_trace.dart';
import '../../files/providers/files_provider.dart';
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
    // Was "< 10": a normal 10 m phone fix showed as "(poor)".
    return currentAccuracyM <= 25
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
  Timer? _gpsRetryTimer;
  Timer? _gpsRestartTimer;
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

  /// Reading the open field file needs the container, so a pin dropped while
  /// a file is open is filed under it without every caller having to know.
  final Ref ref;

  LocationNotifier(this.databaseService, this.ref) : super(const LocationState()) {
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
      // The screen can be torn down while this load is in flight; touching
      // state after dispose throws and the catch below would swallow it.
      if (!mounted) return;
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
      if (!mounted) return;
      final breadcrumbs = maps.map((map) => Breadcrumb.fromMap(map)).toList();
      state = state.copyWith(breadcrumbs: breadcrumbs);
    } catch (e) {
      debugPrint('Error loading breadcrumbs: $e');
    }
  }

  /// Seed from the position the OS already has, before waiting on a fix.
  ///
  /// A cold GPS fix takes tens of seconds, and the map was opening zoomed out
  /// on the whole country in the meantime. The last known position is
  /// returned instantly and is almost always right to within a street, which
  /// is enough to open the map where you actually are and refine from there.
  Future<void> _seedFromLastKnown() async {
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last == null || !mounted) return;
      // Never overwrite a real fix that beat us to it.
      if (state.stats.currentLat != null) return;
      StartupTrace.mark('last_known_position');
      _recentPositions.add(last);
      state = state.copyWith(
        stats: state.stats.copyWith(
          currentLat: last.latitude,
          currentLon: last.longitude,
          currentAccuracyM: last.accuracy,
        ),
      );
    } catch (e) {
      debugPrint('No last known position: $e');
    }
  }

  Future<void> _startGpsTracking() async {
    // Kick this off without waiting: it either helps immediately or not
    // at all, and the live fix carries on regardless.
    unawaited(_seedFromLastKnown());

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _scheduleGpsRetry();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) {
      _scheduleGpsRetry();
      return;
    }
    _gpsRetryTimer?.cancel();
    _gpsRetryTimer = null;

    StartupTrace.mark('gps_permission_ok');
    _trackStart = DateTime.now();
    _listenToPosition();
  }

  void _listenToPosition() {
    _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
      ),
    ).listen(
      (Position position) {
        _onNewPosition(position);
      },
      // GPS drops out routinely — tree cover, gullies, near buildings — and
      // the plugin reports that as an error on this stream ("Something went
      // wrong while listening for position updates"). With no handler it was
      // an unhandled exception, and on web index.html's error overlay then
      // blacked out the whole app. Keep the last known position (and the
      // trip's distance/time) and start listening again shortly.
      onError: (Object e) {
        debugPrint('GPS stream error: $e');
        _restartGpsSoon();
      },
      cancelOnError: true,
    );
  }

  void _restartGpsSoon() {
    _positionSub = null;
    _gpsRestartTimer?.cancel();
    _gpsRestartTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) _listenToPosition();
    });
  }

  void _onNewPosition(Position position) async {
    // A junk fix should not even enter the buffer while we still hold good
    // ones — better to keep showing the last real position than to leap
    // across town and come back.
    if (position.accuracy > maxUsableAccuracyMetres &&
        _recentPositions
            .any((p) => p.accuracy <= maxUsableAccuracyMetres)) {
      debugPrint('Ignoring ${position.accuracy.round()} m fix '
          '(worse than ${maxUsableAccuracyMetres.round()} m)');
      return;
    }

    StartupTrace.mark('first_gps_fix');
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

  Position _averageRecentPosition() => smoothFixes(_recentPositions);

  /// Smooth GPS jitter without dragging the position behind real movement.
  ///
  /// This used to be a plain mean of the last 5 fixes. On a straight path
  /// that sits two fixes BEHIND you — ~10 m walking, 50-60 m driving — and
  /// because distanceFilter stops new fixes once you're still, it never
  /// caught up after you stopped: the pin-tracking arrival check (15 m) could
  /// fail to fire, and SOS, off-route and turn advance all used the lagged
  /// point. Now only fixes that agree with the newest one (within ~2x its
  /// accuracy) are averaged: jitter while standing still gets smoothed, and
  /// as soon as you've really moved the older fixes drop out.
  @visibleForTesting
  /// Worse than this and a fix did not come from GPS. Real satellite fixes
  /// are a few metres to a few tens of metres; hundreds means the phone fell
  /// back to wifi or a phone tower, which puts you on the wrong street.
  static const double maxUsableAccuracyMetres = 100;

  static Position smoothFixes(List<Position> recent) {
    // Throw out fixes far worse than the best we have before averaging
    // anything. There was no accuracy check at all: a tower fix reporting
    // hundreds of metres was averaged in like any other, which is what
    // dragged the marker onto a different street and made it jump about.
    final best = recent.map((p) => p.accuracy).reduce(math.min);
    final limit = math.min(math.max(best * 3, 15.0), maxUsableAccuracyMetres);
    final usable = recent.where((p) => p.accuracy <= limit).toList();

    final newest = usable.isEmpty ? recent.last : usable.last;
    if (usable.isEmpty) {
      // Nothing trustworthy — return the latest rather than inventing one.
      return newest;
    }
    recent = usable;
    final radius = (newest.accuracy * 2).clamp(10.0, 60.0);
    const distance = Distance();
    final here = LatLng(newest.latitude, newest.longitude);
    final samples = recent
        .where((p) =>
            distance(here, LatLng(p.latitude, p.longitude)) <= radius)
        .toList();
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

  /// No GPS: leave the position empty and check again every 20 seconds.
  ///
  /// This used to start a FAKE position — at Uluru, walking north-east at
  /// 1.4 m/s with "±5 m" accuracy — and feed it in exactly like a real fix:
  /// into the map, the breadcrumb trail, pin distances and the SOS message.
  /// For a survival app a wrong position is far worse than no position.
  void _scheduleGpsRetry() {
    if (_gpsRetryTimer != null) return;
    _gpsRetryTimer = Timer.periodic(const Duration(seconds: 20), (_) async {
      if (!mounted) return;
      final enabled = await Geolocator.isLocationServiceEnabled();
      final perm = await Geolocator.checkPermission(); // never re-prompts
      if (enabled &&
          (perm == LocationPermission.always ||
              perm == LocationPermission.whileInUse)) {
        _gpsRetryTimer?.cancel();
        _gpsRetryTimer = null;
        _startGpsTracking();
      }
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
      {String? notes,
      String? color,
      String? icon,
      int? order,
      double? accuracy,
      double? altitude}) async {
    // How good the fix was when this pin was made.
    //
    // Nothing recorded accuracy before, so every pin looked equally precise
    // whether it came from a ±4 m fix or a ±80 m one — and you could not
    // tell which when you came back to find it.
    //
    // A pin dropped where you are standing inherits the live fix. One placed
    // by tapping the map is an exact chosen coordinate with no GPS error at
    // all, so it keeps a null accuracy rather than borrowing yours.
    var recordedAccuracy = accuracy;
    var recordedAltitude = altitude;
    final stats = state.stats;
    if (recordedAccuracy == null && stats.currentLat != null) {
      final standing = const Distance()(
          LatLng(stats.currentLat!, stats.currentLon!), LatLng(lat, lon));
      if (standing <= 10) {
        recordedAccuracy = stats.currentAccuracyM;
        recordedAltitude ??= stats.currentAltitude;
      }
    }

    final waypoint = Waypoint(
      latitude: lat,
      longitude: lon,
      accuracy: recordedAccuracy,
      altitude: recordedAltitude,
      timestamp: DateTime.now(),
      label: label,
      notes: notes,
      type: WaypointType.manual,
      color: color ?? WaypointColors.emberOrange,
      icon: icon ?? WaypointIcon.pin,
      order: order,
      isPin: true,
      fileId: ref.read(filesProvider).activeFileId,
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
    double? accuracy,
    String? type,
    String? color,
    String? icon,
    // Which file to file it under. Defaults to whichever is open, but the
    // camera lets you pick a different one as you save.
    int? fileId,
    bool useOpenFile = true,
  }) async {
    // Same rule as a dropped pin: a photo taken where you are standing
    // inherits how good the fix was, so you can judge it later.
    var recordedAccuracy = accuracy;
    var recordedAltitude = altitude;
    final stats = state.stats;
    if (recordedAccuracy == null && stats.currentLat != null) {
      final standing = const Distance()(
          LatLng(stats.currentLat!, stats.currentLon!), LatLng(lat, lon));
      if (standing <= 10) {
        recordedAccuracy = stats.currentAccuracyM;
        recordedAltitude ??= stats.currentAltitude;
      }
    }

    final waypoint = Waypoint(
      latitude: lat,
      longitude: lon,
      altitude: recordedAltitude,
      accuracy: recordedAccuracy,
      timestamp: DateTime.now(),
      label: label ?? 'Photo Pin',
      notes: notes,
      type: type ?? WaypointType.manual,
      color: color ?? WaypointColors.neonCyan,
      icon: icon ?? WaypointIcon.pin,
      isPin: true,
      photoPaths: [photoPath],
      thumbnailPath: thumbnailPath,
      fileId: fileId ?? (useOpenFile ? ref.read(filesProvider).activeFileId : null),
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
    await updateWaypoint(
        _find(id).copyWith(latitude: lat, longitude: lon));
  }

  Waypoint _find(int id) => state.waypoints.firstWhere(
        (w) => w.id == id,
        orElse: () => throw Exception('Waypoint not found'),
      );

  /// Update waypoint color
  Future<void> updateWaypointColor(int id, String color) async {
    await updateWaypoint(_find(id).copyWith(color: color));
  }

  /// Replace a pin's photos.
  ///
  /// Takes the whole list rather than an add and a remove, because the sheet
  /// holds the order on screen and one write keeps the stored list and the one
  /// being looked at from drifting apart. An empty list is a pin with no
  /// photos, not "leave them alone".
  Future<void> setWaypointPhotos(int id, List<String> photos) async {
    await updateWaypoint(_find(id).copyWith(photoPaths: photos));
  }

  /// Move a pin into a project, or out of every project with a null [fileId].
  ///
  /// The counterpart of filing a zone, which zones have had all along. Without
  /// it, work collected before a project existed could never be gathered into
  /// it, and "add the pins to it" meant dropping them again.
  Future<void> setWaypointFile(int id, int? fileId) async {
    await updateWaypoint(
        _find(id).copyWith(fileId: fileId, clearFile: fileId == null));
  }

  /// Update waypoint icon
  Future<void> updateWaypointIcon(int id, String icon) async {
    await updateWaypoint(_find(id).copyWith(icon: icon));
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
    if (!mounted) return;
    state = state.copyWith(breadcrumbs: []);
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _elapsedTimer?.cancel();
    _gpsRetryTimer?.cancel();
    _gpsRestartTimer?.cancel();
    _breadcrumbTimer?.cancel();
    super.dispose();
  }
}

final locationProvider =
    StateNotifierProvider<LocationNotifier, LocationState>((ref) {
  final databaseService = ref.watch(databaseServiceProvider);
  return LocationNotifier(databaseService, ref);
});
