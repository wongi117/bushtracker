import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:bush_track/features/elevation/services/elevation_service.dart';

class ElevationState {
  final List<ElevationPoint> elevationProfile;
  final bool isLoading;
  final String? error;

  ElevationState({
    this.elevationProfile = const [],
    this.isLoading = false,
    this.error,
  });

  ElevationState copyWith({
    List<ElevationPoint>? elevationProfile,
    bool? isLoading,
    String? error,
  }) {
    return ElevationState(
      elevationProfile: elevationProfile ?? this.elevationProfile,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
  
  double get maxElevation {
    if (elevationProfile.isEmpty) return 0;
    return elevationProfile.map((p) => p.elevation).reduce((a, b) => a > b ? a : b);
  }
  
  double get minElevation {
    if (elevationProfile.isEmpty) return 0;
    return elevationProfile.map((p) => p.elevation).reduce((a, b) => a < b ? a : b);
  }
  
  double get totalDistance {
    if (elevationProfile.isEmpty) return 0;
    return elevationProfile.last.distance;
  }
}

class ElevationNotifier extends StateNotifier<ElevationState> {
  ElevationNotifier() : super(ElevationState());

  Future<void> generateElevationProfile(List<LatLng> route) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final profile = await ElevationService.getElevationProfile(route);
      state = state.copyWith(
        elevationProfile: profile,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to generate elevation profile',
      );
    }
  }
}

final elevationProvider = StateNotifierProvider<ElevationNotifier, ElevationState>((ref) {
  return ElevationNotifier();
});