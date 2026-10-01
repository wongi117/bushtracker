import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'package:bush_track/core/config/api_config.dart';

/// One street-level photo.
@immutable
class StreetPhoto {
  const StreetPhoto({
    required this.id,
    required this.position,
    this.capturedAt,
    this.compassAngle,
    this.thumbUrl,
    this.fullUrl,
  });

  final String id;
  final LatLng position;
  final DateTime? capturedAt;

  /// Which way the camera was facing, so the viewer can say so.
  final double? compassAngle;

  final String? thumbUrl;
  final String? fullUrl;

  StreetPhoto withUrls({String? thumb, String? full}) => StreetPhoto(
        id: id,
        position: position,
        capturedAt: capturedAt,
        compassAngle: compassAngle,
        thumbUrl: thumb ?? thumbUrl,
        fullUrl: full ?? fullUrl,
      );
}

/// Street-level imagery from Mapillary.
///
/// **Online only, deliberately.** Everything else in this app works with no
/// signal; this cannot, because it is someone else's imagery of somewhere you
/// are not. Rather than pretend otherwise, the layer greys itself out when
/// there is no connection and says why.
///
/// Nothing is written to disk. Mapillary's terms on storing their imagery need
/// checking before any of it is cached, and the offline promise this app makes
/// about *your* photos must not be quietly extended to someone else's.
class MapillaryService {
  MapillaryService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const String _graph = 'https://graph.mapillary.com';

  /// Mapillary hands out two tokens and they are not interchangeable.
  ///
  /// The **client** token authenticates and returns an empty list with HTTP
  /// 200; the **access** token returns imagery. A genuinely bad token returns
  /// 401. So "authenticated, empty" is the signature of the wrong credential —
  /// and it looks exactly like a region with no coverage, which is how it
  /// costs an afternoon.
  bool get hasToken => ApiConfig.hasMapillary;

  /// Photos inside a bounding box, for drawing coverage.
  ///
  /// [limit] keeps a dense city from returning thousands of points to plot.
  Future<List<StreetPhoto>> coverage({
    required LatLng southWest,
    required LatLng northEast,
    int limit = 200,
  }) async {
    if (!hasToken) return const [];

    final bbox = '${southWest.longitude},${southWest.latitude},'
        '${northEast.longitude},${northEast.latitude}';
    final uri = Uri.parse('$_graph/images'
        '?bbox=$bbox&limit=$limit'
        '&fields=id,computed_geometry,geometry,captured_at,compass_angle');

    try {
      final res = await _client.get(uri, headers: _headers).timeout(
            const Duration(seconds: 12),
          );
      if (res.statusCode != 200) {
        debugPrint('Mapillary coverage HTTP ${res.statusCode}: ${res.body}');
        return const [];
      }
      return _parseList(res.body);
    } catch (e) {
      // No signal, a timeout, bad JSON — all the same to the caller, which
      // shows an empty layer rather than an error over the map.
      debugPrint('Mapillary coverage failed: $e');
      return const [];
    }
  }

  /// The photo nearest [to], within [withinMetres], or null.
  ///
  /// Searches a small box around the point rather than asking Mapillary for a
  /// nearest-neighbour, which its API does not offer.
  Future<StreetPhoto?> nearest(
    LatLng to, {
    double withinMetres = 60,
  }) async {
    if (!hasToken) return null;

    const distance = Distance();
    final sw = distance.offset(distance.offset(to, withinMetres, 180),
        withinMetres, 270);
    final ne = distance.offset(distance.offset(to, withinMetres, 0),
        withinMetres, 90);

    final found = await coverage(southWest: sw, northEast: ne, limit: 25);
    if (found.isEmpty) return null;

    found.sort((a, b) =>
        distance(to, a.position).compareTo(distance(to, b.position)));
    final closest = found.first;
    if (distance(to, closest.position) > withinMetres) return null;

    return withImageUrls(closest);
  }

  /// Fill in the image URLs for one photo.
  ///
  /// A separate call because the coverage query does not return them, and
  /// asking for them across two hundred points would be a lot of response for
  /// photos nobody has tapped.
  Future<StreetPhoto> withImageUrls(StreetPhoto photo) async {
    if (!hasToken) return photo;

    final uri = Uri.parse(
        '$_graph/${photo.id}?fields=thumb_1024_url,thumb_2048_url');
    try {
      final res = await _client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return photo;
      final body = jsonDecode(res.body);
      if (body is! Map) return photo;
      return photo.withUrls(
        thumb: body['thumb_1024_url']?.toString(),
        full: body['thumb_2048_url']?.toString() ??
            body['thumb_1024_url']?.toString(),
      );
    } catch (e) {
      debugPrint('Mapillary image urls failed: $e');
      return photo;
    }
  }

  Map<String, String> get _headers =>
      {'Authorization': 'OAuth ${ApiConfig.mapillaryToken}'};

  @visibleForTesting
  static List<StreetPhoto> parseList(String body) => _parseList(body);

  static List<StreetPhoto> _parseList(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) return const [];
      final data = decoded['data'];
      if (data is! List) return const [];

      final out = <StreetPhoto>[];
      for (final entry in data) {
        if (entry is! Map) continue;
        final id = entry['id']?.toString();
        if (id == null) continue;

        // computed_geometry is Mapillary's corrected position and is the
        // better one where it exists; geometry is the raw GPS off the camera.
        final position = _coords(entry['computed_geometry']) ??
            _coords(entry['geometry']);
        if (position == null) continue;

        final capturedMs = entry['captured_at'];
        out.add(StreetPhoto(
          id: id,
          position: position,
          capturedAt: capturedMs is int
              ? DateTime.fromMillisecondsSinceEpoch(capturedMs)
              : null,
          compassAngle: (entry['compass_angle'] as num?)?.toDouble(),
        ));
      }
      return out;
    } catch (e) {
      debugPrint('Mapillary parse failed: $e');
      return const [];
    }
  }

  /// GeoJSON order is [longitude, latitude] — the opposite of how every
  /// coordinate elsewhere in this app is written, and an easy way to plot all
  /// of Western Australia somewhere off Somalia.
  static LatLng? _coords(Object? geometry) {
    if (geometry is! Map) return null;
    final coords = geometry['coordinates'];
    if (coords is! List || coords.length < 2) return null;
    final lon = (coords[0] as num?)?.toDouble();
    final lat = (coords[1] as num?)?.toDouble();
    if (lon == null || lat == null) return null;
    if (lat.abs() > 90 || lon.abs() > 180) return null;
    return LatLng(lat, lon);
  }

  void dispose() => _client.close();
}
