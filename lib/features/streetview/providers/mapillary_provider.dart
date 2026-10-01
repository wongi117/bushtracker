import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:bush_track/core/config/api_config.dart';
import 'package:bush_track/core/services/connectivity_service.dart';
import 'package:bush_track/features/streetview/services/mapillary_service.dart';

/// Why the street-imagery layer cannot be used, if it cannot.
enum StreetViewBlocked { none, noToken, offline, zoomedOut }

@immutable
class StreetViewState {
  const StreetViewState({
    this.enabled = false,
    this.loading = false,
    this.photos = const [],
    this.blocked = StreetViewBlocked.none,
  });

  final bool enabled;
  final bool loading;
  final List<StreetPhoto> photos;
  final StreetViewBlocked blocked;

  bool get usable => blocked == StreetViewBlocked.none;

  /// Shown on the disabled control. Greyed out and explained beats hidden:
  /// hiding it looks like a feature that does not exist.
  String get reason => switch (blocked) {
        StreetViewBlocked.none => '',
        StreetViewBlocked.noToken => 'Needs a Mapillary token in config',
        StreetViewBlocked.offline => 'Street photos need a connection',
        StreetViewBlocked.zoomedOut => 'Zoom in to load street photos',
      };

  StreetViewState copyWith({
    bool? enabled,
    bool? loading,
    List<StreetPhoto>? photos,
    StreetViewBlocked? blocked,
  }) =>
      StreetViewState(
        enabled: enabled ?? this.enabled,
        loading: loading ?? this.loading,
        photos: photos ?? this.photos,
        blocked: blocked ?? this.blocked,
      );
}

/// The street-level imagery layer.
///
/// The only online-only feature in the app, so it is explicit about it rather
/// than failing quietly: the toggle greys out with a reason when there is no
/// token, no signal, or the map is too far out to ask a sensible question.
class StreetViewNotifier extends StateNotifier<StreetViewState> {
  StreetViewNotifier(this._ref, {MapillaryService? service})
      : _service = service ?? MapillaryService(),
        super(const StreetViewState()) {
    _refreshBlocked();
  }

  final Ref _ref;
  final MapillaryService _service;

  /// Below this, a bounding box over WA would ask for a continent's worth of
  /// points to plot.
  static const double minZoom = 13;

  /// Coverage already fetched, keyed by a rounded bbox.
  ///
  /// Memory only, for the session. Nothing goes to disk: Mapillary's terms on
  /// storing their imagery need checking first, and this app's offline promise
  /// is about your own data, not someone else's photos.
  final Map<String, List<StreetPhoto>> _cache = {};

  void _refreshBlocked() {
    // At construction the map's zoom is not known yet, so this only answers
    // the two questions that do not depend on it: token and signal.
    state = state.copyWith(blocked: _currentBlock(minZoom));
  }

  StreetViewBlocked _currentBlock(double zoom) {
    if (!ApiConfig.hasMapillary) return StreetViewBlocked.noToken;
    if (!_ref.read(connectivityProvider).isConnected) {
      return StreetViewBlocked.offline;
    }
    if (zoom < minZoom) return StreetViewBlocked.zoomedOut;
    return StreetViewBlocked.none;
  }

  /// Turn the layer on or off. Refuses when it cannot work, and says why.
  Future<void> toggle({required double zoom}) async {
    if (state.enabled) {
      state = state.copyWith(enabled: false, photos: const []);
      return;
    }

    final blocked = _currentBlock(zoom);
    state = state.copyWith(blocked: blocked);
    if (blocked != StreetViewBlocked.none) return;

    state = state.copyWith(enabled: true);
  }

  /// Load coverage for what is on screen. Called as the map settles.
  Future<void> loadFor({
    required LatLng southWest,
    required LatLng northEast,
    required double zoom,
  }) async {
    if (!state.enabled) return;

    final blocked = _currentBlock(zoom);
    if (blocked != StreetViewBlocked.none) {
      // Losing signal with the layer on empties it rather than leaving stale
      // dots that cannot be opened.
      state = state.copyWith(
          blocked: blocked,
          photos: blocked == StreetViewBlocked.offline ? const [] : state.photos);
      return;
    }

    final key = _cacheKey(southWest, northEast);
    final cached = _cache[key];
    if (cached != null) {
      state = state.copyWith(photos: cached, blocked: StreetViewBlocked.none);
      return;
    }

    state = state.copyWith(loading: true, blocked: StreetViewBlocked.none);
    final found = await _service.coverage(
      southWest: southWest,
      northEast: northEast,
    );
    if (!mounted) return;

    _cache[key] = found;
    state = state.copyWith(photos: found, loading: false);
  }

  /// The photo nearest a tap, or null.
  Future<StreetPhoto?> photoNear(LatLng point) async {
    if (_currentBlock(minZoom) != StreetViewBlocked.none) return null;
    return _service.nearest(point);
  }

  /// Rounded to about a tile, so panning a few metres reuses the last answer
  /// instead of asking again.
  String _cacheKey(LatLng sw, LatLng ne) =>
      '${sw.latitude.toStringAsFixed(2)},${sw.longitude.toStringAsFixed(2)},'
      '${ne.latitude.toStringAsFixed(2)},${ne.longitude.toStringAsFixed(2)}';

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}

final streetViewProvider =
    StateNotifierProvider<StreetViewNotifier, StreetViewState>(
        (ref) => StreetViewNotifier(ref));
