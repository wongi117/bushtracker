import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bush_track/features/tracking/providers/location_provider.dart';
import 'package:bush_track/features/mesh/providers/mesh_provider.dart';
import 'package:uuid/uuid.dart';

class LocationSharingService {
  final Ref ref;
  Timer? _sharingTimer;
  String? _sharingToken;
  DateTime? _sharingExpiry;
  bool _isSharing = false;
  
  // Sharing durations
  static const Duration oneHour = Duration(hours: 1);
  static const Duration fourHours = Duration(hours: 4);
  static const Duration eightHours = Duration(hours: 8);
  static const Duration untilStopped = Duration(days: 365); // Effectively "until stopped"

  LocationSharingService(this.ref);

  String startSharing(Duration duration) {
    if (_isSharing) {
      stopSharing();
    }
    
    _isSharing = true;
    _sharingToken = const Uuid().v4();
    _sharingExpiry = DateTime.now().add(duration);
    
    // Start sharing location every 30 seconds
    _sharingTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _broadcastLocation();
    });
    
    return _sharingToken!;
  }

  void stopSharing() {
    _sharingTimer?.cancel();
    _isSharing = false;
    _sharingToken = null;
    _sharingExpiry = null;
  }

  bool get isSharing => _isSharing;
  
  String? get sharingToken => _sharingToken;
  
  DateTime? get sharingExpiry => _sharingExpiry;

  Future<void> _broadcastLocation() async {
    if (!_isSharing || _sharingExpiry == null) return;
    
    // Check if sharing has expired
    if (DateTime.now().isAfter(_sharingExpiry!)) {
      stopSharing();
      return;
    }
    
    final locationState = ref.read(locationProvider);
    final lat = locationState.stats.currentLat;
    final lon = locationState.stats.currentLon;
    
    if (lat != null && lon != null) {
      // Broadcast location via mesh network
      await ref.read(meshProvider.notifier).broadcastLocation(lat, lon);
    }
  }
  
  void dispose() {
    stopSharing();
  }
}

// Provider for the location sharing service
final locationSharingServiceProvider = Provider((ref) {
  return LocationSharingService(ref);
});