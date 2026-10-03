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
  mapbox,

  /// Sentinel-2 cloudless, served by EOX.
  ///
  /// In the comparison for a specific reason: it is the only one of the three
  /// whose imagery can legally be stored offline. Mapbox permits offline only
  /// through their own SDK, and Esri's terms are the same shape -- so if
  /// offline satellite for crews with no signal is the goal, the licence is
  /// the constraint, not the renderer.
  ///
  /// It is 10 m/px against Mapbox's sub-metre, so it will look worse on a
  /// screenshot. The question the field test actually answers is whether it is
  /// worse *at the job*: on scrub, tracks, drainage and old workings, coarse
  /// imagery you can take into a dead zone may beat sharp imagery you cannot.
  ///
  /// **The tile service here is EOX's public one, which is for the comparison,
  /// not for production.** The imagery is CC BY 4.0 (modified Copernicus
  /// Sentinel data) and so is ours to host, but EOX's free endpoint is a
  /// fair-use courtesy and a crew hammering it is not that. Shipping this as
  /// the real offline source means generating our own pack from Copernicus and
  /// serving it from Supabase Storage -- route B3 in PINAGE_OPTION_B_PLAN.md.
  sentinel2;

  String get label => switch (this) {
        SatelliteSource.esri => 'ESRI World Imagery',
        SatelliteSource.mapbox => 'Mapbox Satellite',
        SatelliteSource.sentinel2 => 'Sentinel-2 cloudless',
      };

  String get shortLabel => switch (this) {
        SatelliteSource.esri => 'ESRI',
        SatelliteSource.mapbox => 'Mapbox',
        SatelliteSource.sentinel2 => 'Sentinel-2',
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
        // WMTS, so {y} comes before {x} -- the opposite of the Mapbox
        // template above, and an easy way to end up looking at the wrong
        // hemisphere. "g" is the GoogleMapsCompatible tile matrix set.
        //
        // 2024 is the newest year the service answers for; the year is in the
        // layer name rather than being a "latest" alias, so this needs bumping
        // when a newer mosaic appears.
        SatelliteSource.sentinel2 =>
          'https://tiles.maps.eox.at/wmts/1.0.0/s2cloudless-2024_3857/'
              'default/g/{z}/{y}/{x}.jpg',
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
        // Measured, not assumed. The service answers past this, but the tiles
        // get *smaller* as the zoom climbs -- 16.5 KB at z13, 10.7 KB at z16
        // over Leonora -- which is upscaling compressing well, not detail
        // arriving. Sentinel-2 is 10 m/px, and a z14 tile at this latitude is
        // about 8.4 m/px, so z14 is where the real resolution runs out.
        SatelliteSource.sentinel2 => 14,
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
        // CC BY 4.0 requires the credit, and requires naming that the data is
        // modified. Taken from EOX's own stated attribution.
        SatelliteSource.sentinel2 =>
          'Sentinel-2 cloudless by EOX (modified Copernicus Sentinel data)',
      };

  /// The template to hand MapLibre, which does not understand {r}.
  ///
  /// flutter_map fills {r} with "@2x" or with nothing. MapLibre has no such
  /// placeholder and would request a URL containing a literal "{r}", getting
  /// nothing back -- so @2x is asked for outright. That is still one request
  /// per tile; it is only flutter_map that turns a hardcoded @2x into four.
  String get urlTemplateForMapLibre => urlTemplate.replaceAll('{r}', '@2x');

  /// This source if it can load, else Esri.
  ///
  /// Every map surface goes through here, so a source chosen on one screen is
  /// the source every screen draws. Three of them used to decide for
  /// themselves, which would have made the field comparison report whichever
  /// screen happened to be open rather than the imagery being judged.
  SatelliteSource get resolved => isAvailable ? this : SatelliteSource.esri;

  /// Whether this source can actually be used right now.
  bool get isAvailable => switch (this) {
        SatelliteSource.esri => true,
        SatelliteSource.mapbox => ApiConfig.hasMapbox,
        // No token, so always available -- which is part of the argument for
        // it.
        SatelliteSource.sentinel2 => true,
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

  /// Step to the next usable source, for a single button in the field.
  ///
  /// A cycle rather than a flip, now there are three. Sources that cannot load
  /// -- Mapbox in a build with no token -- are stepped over instead of being
  /// offered and then failing.
  Future<void> toggle() {
    final usable =
        SatelliteSource.values.where((s) => s.isAvailable).toList();
    if (usable.isEmpty) return Future.value();
    final at = usable.indexOf(state);
    return use(usable[(at + 1) % usable.length]);
  }
}

final satelliteSourceProvider =
    StateNotifierProvider<SatelliteSourceNotifier, SatelliteSource>(
        (ref) => SatelliteSourceNotifier());
