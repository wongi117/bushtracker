import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Geometry for zones that are not circles.
///
/// A ranger flagging a heritage site, a geologist marking an exclusion area or
/// a station owner fencing off a paddock all need a shape that follows the
/// actual ground, not a circle drawn around one point. These are the pure
/// functions behind that: they take plain coordinates and return plain
/// numbers, so they can be tested without a map, a database or a device.
///
/// Longitude is treated as a plain number, so a boundary drawn across the
/// 180th meridian would be wrong. Nothing in Australia comes near it.
const double _earthRadiusMetres = 6378137.0;

/// Whether [point] falls inside [polygon], by ray casting: count how many
/// edges a line drawn east from the point crosses. Odd means inside.
///
/// Points exactly on an edge may land either way — that is inherent to the
/// method and harmless here, since a zone boundary is drawn by hand to begin
/// with.
bool isPointInPolygon(LatLng point, List<LatLng> polygon) {
  if (polygon.length < 3) return false;

  final x = point.longitude;
  final y = point.latitude;
  var inside = false;

  for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    final xi = polygon[i].longitude, yi = polygon[i].latitude;
    final xj = polygon[j].longitude, yj = polygon[j].latitude;

    // Does this edge straddle the point's latitude, and if so, is the
    // crossing to the east of the point?
    final straddles = (yi > y) != (yj > y);
    if (straddles && x < (xj - xi) * (y - yi) / (yj - yi) + xi) {
      inside = !inside;
    }
  }
  return inside;
}

/// Area enclosed by [polygon] in square metres, by spherical excess.
///
/// A flat approximation is out by a useful amount over the distances a mine
/// lease or a pastoral boundary covers, so this works on the sphere.
double polygonAreaSqMetres(List<LatLng> polygon) {
  if (polygon.length < 3) return 0;

  var total = 0.0;
  for (var i = 0; i < polygon.length; i++) {
    final a = polygon[i];
    final b = polygon[(i + 1) % polygon.length];
    total += _toRadians(b.longitude - a.longitude) *
        (2 + math.sin(_toRadians(a.latitude)) + math.sin(_toRadians(b.latitude)));
  }
  return (total * _earthRadiusMetres * _earthRadiusMetres / 2).abs();
}

/// Distance around the outside of [polygon] in metres, including the closing
/// edge back to the first point.
double polygonPerimeterMetres(List<LatLng> polygon) {
  if (polygon.length < 2) return 0;
  const distance = Distance();
  var total = 0.0;
  for (var i = 0; i < polygon.length; i++) {
    total += distance(polygon[i], polygon[(i + 1) % polygon.length]);
  }
  return total;
}

/// The centre of [polygon], used to label it, to sort a list by how far away
/// it is, and to fly the map to it.
///
/// This is the centroid of the enclosed area, not the average of the corners:
/// averaging corners drags the label towards whichever edge was drawn with
/// the most points.
LatLng polygonCentroid(List<LatLng> polygon) {
  if (polygon.isEmpty) return const LatLng(0, 0);
  if (polygon.length < 3) {
    final lat = polygon.map((p) => p.latitude).reduce((a, b) => a + b);
    final lon = polygon.map((p) => p.longitude).reduce((a, b) => a + b);
    return LatLng(lat / polygon.length, lon / polygon.length);
  }

  var twiceArea = 0.0, x = 0.0, y = 0.0;
  for (var i = 0; i < polygon.length; i++) {
    final a = polygon[i];
    final b = polygon[(i + 1) % polygon.length];
    final cross = a.longitude * b.latitude - b.longitude * a.latitude;
    twiceArea += cross;
    x += (a.longitude + b.longitude) * cross;
    y += (a.latitude + b.latitude) * cross;
  }

  // A polygon whose points are collinear encloses nothing and would divide by
  // zero; fall back to the average of the corners.
  if (twiceArea.abs() < 1e-12) {
    final lat = polygon.map((p) => p.latitude).reduce((a, b) => a + b);
    final lon = polygon.map((p) => p.longitude).reduce((a, b) => a + b);
    return LatLng(lat / polygon.length, lon / polygon.length);
  }

  final factor = 1 / (3 * twiceArea);
  return LatLng(y * factor, x * factor);
}

/// Shortest distance in metres from [point] to the outline of [polygon].
///
/// Used to warn that a boundary is close before it is crossed — the point may
/// be inside or outside, this only measures the edge.
double distanceToPolygonEdgeMetres(LatLng point, List<LatLng> polygon) {
  if (polygon.isEmpty) return double.infinity;
  if (polygon.length == 1) return const Distance()(point, polygon.first);

  var shortest = double.infinity;
  for (var i = 0; i < polygon.length; i++) {
    final d = _distanceToSegmentMetres(
        point, polygon[i], polygon[(i + 1) % polygon.length]);
    if (d < shortest) shortest = d;
  }
  return shortest;
}

/// Distance from [p] to the segment [a]–[b].
///
/// Over the length of one edge the curve of the earth does not matter, so the
/// segment maths is done on a local flat grid in metres, with longitude
/// scaled by the latitude so the two axes are the same size on the ground.
double _distanceToSegmentMetres(LatLng p, LatLng a, LatLng b) {
  const distance = Distance();
  const metresPerDegLat = _earthRadiusMetres * math.pi / 180;
  final metresPerDegLon =
      metresPerDegLat * math.cos(_toRadians(p.latitude)).abs();

  final px = (p.longitude - a.longitude) * metresPerDegLon;
  final py = (p.latitude - a.latitude) * metresPerDegLat;
  final bx = (b.longitude - a.longitude) * metresPerDegLon;
  final by = (b.latitude - a.latitude) * metresPerDegLat;

  final lengthSq = bx * bx + by * by;
  if (lengthSq == 0) return distance(p, a);

  // How far along the segment the closest point sits, clamped to its ends.
  final t = ((px * bx + py * by) / lengthSq).clamp(0.0, 1.0);
  final dx = px - bx * t;
  final dy = py - by * t;
  return math.sqrt(dx * dx + dy * dy);
}

/// Human-readable area, e.g. "4.2 ha" or "12.6 km²".
///
/// Hectares because that is what land is spoken about in on a station or a
/// lease; square metres below that, square kilometres once hectares get long.
String formatArea(double sqMetres) {
  if (sqMetres < 10000) return '${sqMetres.round()} m²';
  final hectares = sqMetres / 10000;
  if (hectares < 100) return '${hectares.toStringAsFixed(1)} ha';
  final sqKm = sqMetres / 1000000;
  if (sqKm < 10) return '${sqKm.toStringAsFixed(2)} km²';
  return '${sqKm.toStringAsFixed(1)} km²';
}

/// Human-readable distance, matching how the rest of the app reads out ranges.
String formatDistance(double metres) {
  if (metres < 1000) return '${metres.round()} m';
  return '${(metres / 1000).toStringAsFixed(metres < 10000 ? 2 : 1)} km';
}

double _toRadians(double degrees) => degrees * math.pi / 180;
