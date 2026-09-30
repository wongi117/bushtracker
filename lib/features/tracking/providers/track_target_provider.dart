import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

/// Whatever is currently being walked or driven to.
///
/// Tracking used to understand only a dropped pin, so a flagged zone — the
/// thing a ranger or a geo actually navigates to — could not be a
/// destination. This describes any of them the same way, which also lets the
/// AR camera draw a track towards it without knowing what kind it is.
@immutable
class TrackTarget {
  const TrackTarget({
    required this.name,
    required this.position,
    required this.colour,
    this.arriveWithinMetres = 15,
    this.isZone = false,
  });

  final String name;
  final LatLng position;
  final Color colour;

  /// How close counts as arrived. A pin is a spot; a zone is arrived at when
  /// its boundary is reached, so this carries its radius instead.
  final double arriveWithinMetres;

  final bool isZone;

  @override
  bool operator ==(Object other) =>
      other is TrackTarget &&
      other.name == name &&
      other.position == position &&
      other.isZone == isZone;

  @override
  int get hashCode => Object.hash(name, position, isZone);
}

/// Shared so the map screen sets it and the AR camera can read it.
final trackTargetProvider = StateProvider<TrackTarget?>((ref) => null);
