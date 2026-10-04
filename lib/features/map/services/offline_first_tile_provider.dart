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
