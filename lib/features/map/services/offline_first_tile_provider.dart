import 'dart:convert';

import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';

import 'package:bush_track/features/map/services/offline_map_manager.dart';

/// Serves a downloaded tile from disk, and falls back to the network for
/// anything not downloaded.
///
/// This is the piece the offline feature was missing. `OfflineMapManager` has
/// downloaded tiles into the documents directory since the first commit of the
/// app, and `getOfflineTile` has sat there the whole time with no caller: every
/// `TileLayer` went straight to the network. So a download would run to
/// completion, report success, take up storage -- and the map was still blank
/// with no signal. Nothing was broken; the read side was never connected.
///
/// Offline-first rather than network-first, deliberately. A tile already on the
/// phone is faster, costs no data and costs nothing per request, which matters
/// on a metered provider. The region was downloaded precisely so it would be
/// used.
class OfflineFirstTileProvider extends TileProvider {
  OfflineFirstTileProvider({
    required this.fallback,
    required this.style,
    super.headers,
  });

  /// Where tiles come from when they are not on the phone. Normally the
  /// caching network provider, so a tile fetched once is kept for as long as
  /// the server's headers allow.
  final TileProvider fallback;

  /// Which imagery is being drawn, so only regions downloaded for *this*
  /// source are served.
  ///
  /// Without the check a region downloaded as MapTiler satellite would be
  /// served while the map is set to Mapbox or Esri: real imagery, of the right
  /// ground, from the wrong provider, with nothing on screen saying so. That
  /// would also quietly invalidate the field comparison between them.
  final MapStyle style;

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final file = OfflineMapManager()
        .tileFileFor(style, coordinates.z, coordinates.x, coordinates.y);
    if (file != null) return FileImage(file);
    return fallback.getImage(coordinates, options);
  }

  // Cancellation is the fallback's business: a file read is not worth
  // cancelling, and dropping support here would lose the network provider's
  // ability to abandon a request for a tile that has scrolled away.
  @override
  bool get supportsCancelLoading => fallback.supportsCancelLoading;

  @override
  ImageProvider getImageWithCancelLoadingSupport(
    TileCoordinates coordinates,
    TileLayer options,
    Future<void> cancelLoading,
  ) {
    final file = OfflineMapManager()
        .tileFileFor(style, coordinates.z, coordinates.x, coordinates.y);
    if (file != null) return FileImage(file);
    return fallback.getImageWithCancelLoadingSupport(
        coordinates, options, cancelLoading);
  }

  @override
  void dispose() {
    fallback.dispose();
    super.dispose();
  }
}

/// Downloaded tiles only. Never the network.
///
/// For drawing a downloaded region *underneath* a layer that has no offline
/// copy of its own -- Mapbox satellite, whose terms allow offline storage only
/// through their SDK. Online, the layer above covers this completely. Offline,
/// wherever the layer above has no tile, the download shows through instead
/// of a blank square, with no switching of layers and no guessing at whether
/// there is signal: it is decided tile by tile.
///
/// Reported as "when we are offline the maps are blury until im online and
/// have to manually switch maps". Never fetching is the point -- a tile it
/// does not hold is transparent, so this costs nothing online and cannot be
/// mistaken for a source of its own.
class DownloadedOnlyTileProvider extends TileProvider {
  DownloadedOnlyTileProvider({required this.style});

  final MapStyle style;

  /// A 1x1 fully transparent PNG, for every tile not on the phone.
  static final MemoryImage transparent = MemoryImage(base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII='));

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final file = OfflineMapManager()
        .tileFileFor(style, coordinates.z, coordinates.x, coordinates.y);
    if (file != null) return FileImage(file);
    return transparent;
  }
}
