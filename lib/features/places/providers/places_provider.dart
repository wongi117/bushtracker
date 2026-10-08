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

  /// [error] is replaced outright, null included. It was `error ??
  /// this.error`, so the `error: null` every new search passed did nothing:
  /// one failure and the screen showed it forever, over every later result.
  PlacesState copyWith({
    List<Place>? places,
    bool? isLoading,
    required String? error,
  }) {
    return PlacesState(
      places: places ?? this.places,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class PlacesNotifier extends StateNotifier<PlacesState> {
  PlacesNotifier() : super(PlacesState());

  /// Says it could not look, not that there is nothing there -- and what still
  /// works, because out here that is the next question.
  static const unavailableMessage =
      'Place search could not reach its service, so nothing was looked up. '
      'Maps, pins and zones on the phone still work.';

  Future<void> searchNearbyPlaces(LatLng location, {double radius = 50000}) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final places = await PlacesService.getNearbyPlaces(location, radius: radius);
      state = state.copyWith(places: places, isLoading: false, error: null);
    } catch (e) {
      state = state.copyWith(
          places: const [], isLoading: false, error: unavailableMessage);
    }
  }

  Future<void> searchPlaces(String query, {LatLng? proximity}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final places = await PlacesService.searchPlaces(query, proximity: proximity);
      state = state.copyWith(places: places, isLoading: false, error: null);
    } catch (e) {
      state = state.copyWith(
          places: const [], isLoading: false, error: unavailableMessage);
    }
  }
}

final placesProvider = StateNotifierProvider<PlacesNotifier, PlacesState>((ref) {
  return PlacesNotifier();
});
