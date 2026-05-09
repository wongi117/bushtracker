import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/models/trail.dart';
import '../../../core/services/database_service.dart';
import '../../../main.dart';

class TrailState {
  final List<Trail> trails;
  final Trail? activeTrail;
  final int? currentPointIndex;
  final List<LatLng> draftPoints;
  final bool isCreating;
  final bool isFollowing;
  final String? navigationMessage;
  final double? distanceToNextPoint;
  final double? bearingToNextPoint;

  const TrailState({
    this.trails = const [],
    this.activeTrail,
    this.currentPointIndex,
    this.draftPoints = const [],
    this.isCreating = false,
    this.isFollowing = false,
    this.navigationMessage,
    this.distanceToNextPoint,
    this.bearingToNextPoint,
  });

  TrailState copyWith({
    List<Trail>? trails,
    Trail? activeTrail,
    int? currentPointIndex,
    List<LatLng>? draftPoints,
    bool? isCreating,
    bool? isFollowing,
    String? navigationMessage,
    double? distanceToNextPoint,
    double? bearingToNextPoint,
    bool clearActiveTrail = false,
    bool clearNavigation = false,
  }) {
    return TrailState(
      trails: trails ?? this.trails,
      activeTrail: clearActiveTrail ? null : activeTrail ?? this.activeTrail,
      currentPointIndex: clearActiveTrail ? null : currentPointIndex ?? this.currentPointIndex,
      draftPoints: draftPoints ?? this.draftPoints,
      isCreating: isCreating ?? this.isCreating,
      isFollowing: isFollowing ?? this.isFollowing,
      navigationMessage: clearNavigation ? null : navigationMessage ?? this.navigationMessage,
      distanceToNextPoint: clearNavigation ? null : distanceToNextPoint ?? this.distanceToNextPoint,
      bearingToNextPoint: clearNavigation ? null : bearingToNextPoint ?? this.bearingToNextPoint,
    );
  }

  /// Get the current target point when following a trail
  LatLng? get currentTargetPoint {
    if (activeTrail == null || currentPointIndex == null) return null;
    final waypoints = activeTrail!.getWaypoints();
    if (currentPointIndex! >= waypoints.length) return null;
    return waypoints[currentPointIndex!];
  }

  /// Check if at the last point
  bool get isAtLastPoint {
    if (activeTrail == null || currentPointIndex == null) return false;
    return currentPointIndex! >= activeTrail!.getWaypoints().length - 1;
  }
}

class TrailNotifier extends StateNotifier<TrailState> {
  final DatabaseService databaseService;
  StreamSubscription<Position>? _positionSub;

  TrailNotifier(this.databaseService) : super(const TrailState()) {
    _loadTrails();
  }

  Future<void> _loadTrails() async {
    try {
      final List<Map<String, dynamic>> maps = await databaseService.getTrails();
      final trails = maps.map((map) => Trail.fromMap(map)).toList();
      state = state.copyWith(trails: trails);
    } catch (e) {
      debugPrint('Error loading trails: $e');
    }
  }

  /// Start creating a new trail
  void startCreatingTrail() {
    state = state.copyWith(
      isCreating: true,
      draftPoints: const [],
    );
  }

  /// Cancel trail creation
  void cancelCreatingTrail() {
    state = state.copyWith(
      isCreating: false,
      draftPoints: const [],
    );
  }

  /// Add a point to the draft trail
  void addDraftPoint(LatLng point) {
    final newPoints = [...state.draftPoints, point];
    state = state.copyWith(draftPoints: newPoints);
  }

  /// Remove last draft point
  void removeLastDraftPoint() {
    if (state.draftPoints.isEmpty) return;
    final newPoints = state.draftPoints.sublist(0, state.draftPoints.length - 1);
    state = state.copyWith(draftPoints: newPoints);
  }

  /// Clear all draft points
  void clearDraftPoints() {
    state = state.copyWith(draftPoints: const []);
  }

  /// Save draft as a new trail
  Future<void> saveDraftTrail({
    required String name,
    String? description,
    String color = TrailColors.electricPurple,
    String lineStyle = TrailLineStyle.solid,
    bool showDirection = true,
  }) async {
    if (state.draftPoints.length < 2) {
      throw Exception('Trail must have at least 2 points');
    }

    final trail = Trail(
      name: name,
      description: description,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      color: color,
      lineStyle: lineStyle,
      showDirection: showDirection,
      isSaved: true,
    );
    
    trail.setWaypoints(state.draftPoints);
    
    // Calculate total distance
    double totalDistance = 0;
    for (int i = 0; i < state.draftPoints.length - 1; i++) {
      totalDistance += Geolocator.distanceBetween(
        state.draftPoints[i].latitude,
        state.draftPoints[i].longitude,
        state.draftPoints[i + 1].latitude,
        state.draftPoints[i + 1].longitude,
      );
    }
    trail.totalDistance = totalDistance;

    await databaseService.insertTrail(trail.toMap());
    
    state = state.copyWith(
      isCreating: false,
      draftPoints: const [],
    );
    
    await _loadTrails();
  }

  /// Update trail
  Future<void> updateTrail(Trail trail) async {
    await databaseService.updateTrail(trail.toMap());
    await _loadTrails();
  }

  /// Delete trail
  Future<void> deleteTrail(int id) async {
    // Stop following if this is the active trail
    if (state.activeTrail?.id == id) {
      stopFollowingTrail();
    }
    await databaseService.deleteTrail(id);
    await _loadTrails();
  }

  /// Start following a trail
  void startFollowingTrail(Trail trail) {
    // Update trail as active
    final updated = Trail(
      id: trail.id,
      name: trail.name,
      description: trail.description,
      createdAt: trail.createdAt,
      updatedAt: trail.updatedAt,
      totalDistance: trail.totalDistance,
      totalElevation: trail.totalElevation,
      durationSeconds: trail.durationSeconds,
      difficulty: trail.difficulty,
      isSaved: trail.isSaved,
      waypointsJson: trail.waypointsJson,
      color: trail.color,
      lineStyle: trail.lineStyle,
      showDirection: trail.showDirection,
      isActive: true,
    );
    updateTrail(updated);

    state = state.copyWith(
      activeTrail: updated,
      currentPointIndex: 0,
      isFollowing: true,
    );

    // Start position tracking for navigation
    _startFollowingTracking();
  }

  /// Stop following trail
  void stopFollowingTrail() {
    if (state.activeTrail != null) {
      final updated = Trail(
        id: state.activeTrail!.id,
        name: state.activeTrail!.name,
        description: state.activeTrail!.description,
        createdAt: state.activeTrail!.createdAt,
        updatedAt: state.activeTrail!.updatedAt,
        totalDistance: state.activeTrail!.totalDistance,
        totalElevation: state.activeTrail!.totalElevation,
        durationSeconds: state.activeTrail!.durationSeconds,
        difficulty: state.activeTrail!.difficulty,
        isSaved: state.activeTrail!.isSaved,
        waypointsJson: state.activeTrail!.waypointsJson,
        color: state.activeTrail!.color,
        lineStyle: state.activeTrail!.lineStyle,
        showDirection: state.activeTrail!.showDirection,
        isActive: false,
      );
      updateTrail(updated);
    }

    _positionSub?.cancel();
    state = state.copyWith(
      clearActiveTrail: true,
      isFollowing: false,
      clearNavigation: true,
    );
  }

  /// Advance to next point when reached
  void advanceToNextPoint() {
    if (state.activeTrail == null || state.currentPointIndex == null) return;
    final nextIndex = state.currentPointIndex! + 1;
    if (nextIndex < state.activeTrail!.getWaypoints().length) {
      state = state.copyWith(currentPointIndex: nextIndex);
    }
  }

  /// Start GPS tracking for trail following
  void _startFollowingTracking() {
    _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5, // Update every 5 meters
      ),
    ).listen((position) {
      _updateNavigation(position);
    });
  }

  /// Update navigation information based on current position
  void _updateNavigation(Position position) {
    final target = state.currentTargetPoint;
    if (target == null) return;

    final distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      target.latitude,
      target.longitude,
    );

    final bearing = Geolocator.bearingBetween(
      position.latitude,
      position.longitude,
      target.latitude,
      target.longitude,
    );

    // Check if reached point (within 20 meters)
    if (distance < 20) {
      if (state.isAtLastPoint) {
        // Reached end of trail
        state = state.copyWith(
          navigationMessage: 'Trail complete! You have reached your destination.',
          distanceToNextPoint: distance,
          bearingToNextPoint: bearing,
        );
        stopFollowingTrail();
      } else {
        // Advance to next point
        advanceToNextPoint();
        final nextTarget = state.currentTargetPoint;
        if (nextTarget != null) {
          final newDistance = Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            nextTarget.latitude,
            nextTarget.longitude,
          );
          final newBearing = Geolocator.bearingBetween(
            position.latitude,
            position.longitude,
            nextTarget.latitude,
            nextTarget.longitude,
          );
          
          final nextIndex = (state.currentPointIndex ?? 0) + 1;
          state = state.copyWith(
            navigationMessage: 'Great! Proceed to point $nextIndex.',
            distanceToNextPoint: newDistance,
            bearingToNextPoint: newBearing,
          );
        }
      }
    } else {
      final nextIndex = (state.currentPointIndex ?? 0) + 1;
      state = state.copyWith(
        navigationMessage: 'Head to point $nextIndex, bearing ${bearing.toInt()}°, ${(distance / 1000).toStringAsFixed(1)}km ahead',
        distanceToNextPoint: distance,
        bearingToNextPoint: bearing,
      );
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }
}

final trailProvider = StateNotifierProvider<TrailNotifier, TrailState>((ref) {
  final databaseService = ref.watch(databaseServiceProvider);
  return TrailNotifier(databaseService);
});
