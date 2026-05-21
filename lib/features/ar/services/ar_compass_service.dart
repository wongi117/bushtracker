import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math';

class ARCompassService {
  ARCompassService(Ref ref);

  // ── Static helpers used by the AR overlay ──────────────────────────────

  static double staticBearing(LatLng from, LatLng to) {
    final lat1 = _rad(from.latitude);
    final lon1 = _rad(from.longitude);
    final lat2 = _rad(to.latitude);
    final lon2 = _rad(to.longitude);
    final dLon = lon2 - lon1;
    final y = sin(dLon) * cos(lat2);
    final x =
        cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);
    return (_deg(atan2(y, x)) + 360) % 360;
  }

  static double staticDistance(LatLng from, LatLng to) {
    return Geolocator.distanceBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
  }

  // ── Instance wrappers (keep backward compat) ───────────────────────────

  double calculateBearing(LatLng from, LatLng to) =>
      staticBearing(from, to);

  double calculateDistance(LatLng from, LatLng to) =>
      staticDistance(from, to);

  // ── Private ─────────────────────────────────────────────────────────────

  static double _rad(double deg) => deg * pi / 180;
  static double _deg(double rad) => rad * 180 / pi;
}

final arCompassServiceProvider = Provider((ref) => ARCompassService(ref));
