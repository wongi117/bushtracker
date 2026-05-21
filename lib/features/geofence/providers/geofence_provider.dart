import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:bush_track/core/models/geofence.dart';
import 'package:bush_track/core/services/database_service.dart';
import 'package:bush_track/features/tracking/providers/location_provider.dart';
import 'package:bush_track/main.dart';

class GeofenceState {
  final List<Geofence> geofences;
  final Set<int> insideIds;
  // Entry/exit announcement pending for ai_monitor_service to speak and clear.
  final String? pendingVoiceAnnouncement;

  const GeofenceState({
    this.geofences = const [],
    this.insideIds = const {},
    this.pendingVoiceAnnouncement,
  });

  GeofenceState copyWith({
    List<Geofence>? geofences,
    Set<int>? insideIds,
    String? pendingVoiceAnnouncement,
    bool clearVoiceAnnouncement = false,
  }) =>
      GeofenceState(
        geofences: geofences ?? this.geofences,
        insideIds: insideIds ?? this.insideIds,
        pendingVoiceAnnouncement: clearVoiceAnnouncement
            ? null
            : pendingVoiceAnnouncement ?? this.pendingVoiceAnnouncement,
      );
}

class GeofenceNotifier extends StateNotifier<GeofenceState> {
  final Ref ref;
  final DatabaseService db;
  Timer? _checkTimer;

  GeofenceNotifier(this.ref, this.db) : super(const GeofenceState()) {
    _load();
    // Check geofence crossings every 20 seconds.
    _checkTimer = Timer.periodic(const Duration(seconds: 20), (_) => _check());
  }

  Future<void> _load() async {
    try {
      final rows = await db.getGeofences();
      final fences = rows.map(Geofence.fromMap).toList();
      state = state.copyWith(geofences: fences);
    } catch (e) {
      debugPrint('GeofenceNotifier load error: $e');
    }
  }

  Future<void> addGeofence({
    required String name,
    required double latitude,
    required double longitude,
    double radiusMeters = 200,
  }) async {
    final fence = Geofence(
      name: name,
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
      isActive: true,
      createdAt: DateTime.now(),
    );
    await db.insertGeofence(fence.toMap());
    await _load();
  }

  Future<void> toggleGeofence(int id) async {
    final fence = state.geofences.firstWhere((f) => f.id == id);
    final updated = fence.copyWith(isActive: !fence.isActive);
    await db.updateGeofence(updated.toMap());
    await _load();
  }

  Future<void> deleteGeofence(int id) async {
    await db.deleteGeofence(id);
    final inside = Set<int>.from(state.insideIds)..remove(id);
    state = state.copyWith(insideIds: inside);
    await _load();
  }

  void clearVoiceAnnouncement() {
    state = state.copyWith(clearVoiceAnnouncement: true);
  }

  void _check() {
    try {
      final locationState = ref.read(locationProvider);
      final lat = locationState.stats.currentLat;
      final lon = locationState.stats.currentLon;
      if (lat == null || lon == null) return;

      final activeFences = state.geofences.where((f) => f.isActive);
      final newInside = <int>{};

      for (final fence in activeFences) {
        final dist = Geolocator.distanceBetween(
            lat, lon, fence.latitude, fence.longitude);
        if (dist <= fence.radiusMeters) {
          newInside.add(fence.id!);
        }
      }

      // Detect crossings
      String? announcement;
      for (final id in newInside) {
        if (!state.insideIds.contains(id)) {
          final name = state.geofences.firstWhere((f) => f.id == id).name;
          announcement = 'Entering $name.';
        }
      }
      for (final id in state.insideIds) {
        if (!newInside.contains(id)) {
          final matches = state.geofences.where((f) => f.id == id);
          if (matches.isNotEmpty) {
            announcement = 'Leaving ${matches.first.name}.';
          }
        }
      }

      state = state.copyWith(
        insideIds: newInside,
        pendingVoiceAnnouncement: announcement,
      );
    } catch (e) {
      debugPrint('GeofenceNotifier check error: $e');
    }
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    super.dispose();
  }
}

final geofenceProvider =
    StateNotifierProvider<GeofenceNotifier, GeofenceState>((ref) {
  final db = ref.watch(databaseServiceProvider);
  return GeofenceNotifier(ref, db);
});
