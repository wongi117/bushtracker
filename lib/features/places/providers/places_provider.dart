import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:bush_track/features/places/services/places_service.dart';

class PlacesState {
  final List<Place> places;
  final bool isLoading;
  final String? error;

  PlacesState({
    this.places = const [],
    this.isLoading = false,
    this.error,
  });

  PlacesState copyWith({
    List<Place>? places,
    bool? isLoading,
    String? error,
  }) {
    return PlacesState(
      places: places ?? this.places,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class PlacesNotifier extends StateNotifier<PlacesState> {
  PlacesNotifier() : super(PlacesState());

  Future<void> searchNearbyPlaces(LatLng location, {double radius = 50000}) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final places = await PlacesService.getNearbyPlaces(location, radius: radius);
      state = state.copyWith(
        places: places,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to fetch nearby places',
      );
    }
  }

  Future<void> searchPlaces(String query, {LatLng? proximity}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final places = await PlacesService.searchPlaces(query, proximity: proximity);
      state = state.copyWith(places: places, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to search places');
    }
  }
}

final placesProvider = StateNotifierProvider<PlacesNotifier, PlacesState>((ref) {
  return PlacesNotifier();
});
