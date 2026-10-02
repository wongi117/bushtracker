import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bush_track/core/config/api_config.dart';

/// Which satellite imagery the map draws.
///
/// Two providers, chosen in the field rather than argued about at a desk: what
/// matters is which one actually shows the track you are standing on, and that
/// differs by region. Over Leonora, ESRI serves a grey "map data not yet
/// available" tile past zoom 17 while Mapbox returns real imagery to 20 — but
/// whether that imagery is *useful* at 20, or just upscaled, is a question for
/// eyes on a phone.
enum SatelliteSource {
  /// Esri World Imagery, via the unauthenticated ArcGIS REST endpoint.
  /// What this app has always used.
  ///
  /// **Licensing is unresolved — see PINAGE_BUILD_PLAN_4.md 5.5.** The item's
  /// own licenseInfo says "licensed under the Esri Master License Agreement"
  /// and describes its use cases as being "in various ArcGIS apps". This is
  /// not an ArcGIS app and there is no Esri agreement, so this may not be a
  /// licensed use. Not changed unilaterally, because it is what the app has
  /// always shipped and the field comparison needs both sources — but it
  /// should not be the default for a commercial release until answered.
  esri,

  /// Mapbox Satellite. Needs a public token; falls back to ESRI without one.
  mapbox;

  String get label => switch (this) {
        SatelliteSource.esri => 'ESRI World Imagery',
        SatelliteSource.mapbox => 'Mapbox Satellite',
      };

  String get shortLabel => switch (this) {
        SatelliteSource.esri => 'ESRI',
        SatelliteSource.mapbox => 'Mapbox',
      };

  /// Tile template for flutter_map.
  String get urlTemplate => switch (this) {
        SatelliteSource.esri =>
          'https://server.arcgisonline.com/ArcGIS/rest/services/'
              'World_Imagery/MapServer/tile/{z}/{y}/{x}',
        // {r}, not a hardcoded @2x — and the difference is billable.
        //
        // flutter_map fills {r} with "@2x" on a high-density screen and with
        // nothing otherwise: one request either way. With @2x written in and no
        // {r} present, it instead *simulates* retina by "requesting four tiles
        // at a larger zoom level and combining them" (its own docs), so every
        // tile became four already-double-resolution requests — 4x the Mapbox
        // bill to draw the same pixels — and cost a zoom level off the top.
        //
        // jpg90 because satellite imagery is photographic; PNG would triple
        // the bytes for no visible gain.
        SatelliteSource.mapbox =>
          'https://api.mapbox.com/v4/mapbox.satellite/{z}/{x}/{y}{r}.jpg90'
              '?access_token=${ApiConfig.mapboxPublicToken}',
      };

  /// Highest zoom the source has real imagery for around remote WA.
  ///
  /// Past this, flutter_map enlarges the last real tile instead of asking for
  /// one that does not exist. ESRI's 17 was measured across Leonora, the
  /// Gibson, the Nullarbor, the Pilbara and the Kimberley. Mapbox's 20 was
  /// measured over Leonora only — it returns 45 KB at z18 and 20 KB at z20
  /// where ESRI returns a 2 KB grey placeholder, so there is something there,
  /// but it is capped conservatively until it has been looked at in the field.
  int get maxNativeZoom => switch (this) {
        SatelliteSource.esri => 17,
        SatelliteSource.mapbox => 20,
      };

  /// Required by both providers' terms, and absent from this app until now.
  ///
  /// The Esri wording is taken verbatim from the service's own `copyrightText`
  /// and the ArcGIS Online item's `accessInformation`, not from memory — which
  /// matters, because it has changed: Maxar rebranded to Vantor, so an
  /// attribution written from recollection is already out of date and credits
  /// a company that no longer exists under that name.
  String get attribution => switch (this) {
        SatelliteSource.esri =>
          'Esri, Vantor, Earthstar Geographics, and the GIS User Community',
        SatelliteSource.mapbox => '© Mapbox © OpenStreetMap',
      };

  /// Whether this source can actually be used right now.
  bool get isAvailable => switch (this) {
        SatelliteSource.esri => true,
        SatelliteSource.mapbox => ApiConfig.hasMapbox,
      };
}

class SatelliteSourceNotifier extends StateNotifier<SatelliteSource> {
  /// Mapbox by default where there is a token, Esri where there is not.
  ///
  /// Esri was the default for as long as this app has existed, and is now the
  /// comparison option only: its licence is the Esri Master License Agreement
  /// and its stated use is "in various ArcGIS apps", which this is not. See
  /// PINAGE_BUILD_PLAN_4.md 5.5. Mapbox's own terms cover raster tiles through
  /// third-party libraries, billed per request.
  ///
  /// Still falling back rather than failing: a build with no token keeps
  /// working exactly as before.
  SatelliteSourceNotifier()
      : super(SatelliteSource.mapbox.isAvailable
            ? SatelliteSource.mapbox
            : SatelliteSource.esri) {
    _load();
  }

  static const _key = 'satellite_source';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      final saved = prefs.getString(_key);
      final match = SatelliteSource.values.where((s) => s.name == saved);
      if (match.isEmpty) return;
      // A remembered choice that is no longer usable — the token was removed
      // from the build — must not leave the map on a source that cannot load.
      if (!match.first.isAvailable) return;
      state = match.first;
    } catch (e) {
      debugPrint('SatelliteSource load error: $e');
    }
  }

  Future<void> use(SatelliteSource source) async {
    if (!source.isAvailable) return;
    state = source;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, source.name);
    } catch (e) {
      debugPrint('SatelliteSource save error: $e');
    }
  }

  /// Flip to the other one, for a single button in the field.
  Future<void> toggle() => use(state == SatelliteSource.esri
      ? SatelliteSource.mapbox
      : SatelliteSource.esri);
}

final satelliteSourceProvider =
    StateNotifierProvider<SatelliteSourceNotifier, SatelliteSource>(
        (ref) => SatelliteSourceNotifier());
