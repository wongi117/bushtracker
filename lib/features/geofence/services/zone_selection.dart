import 'package:latlong2/latlong.dart';

import 'package:bush_track/core/models/geofence.dart';

/// Which zone a tap on the map means.
///
/// A tap inside a zone, or within [edgeReachMetres] of its edge from outside,
/// picks it. When several qualify the smallest wins: zones nest -- a hazard
/// inside a lease, a heritage site inside a work area -- and the one you meant
/// is the one you can only hit by aiming at it. The big one is reachable by
/// tapping anywhere else inside it.
///
/// [edgeReachMetres] is a fingertip at the current zoom, worked out by the
/// map; this stays free of any map widget.
Geofence? zoneAt(LatLng tap, Iterable<Geofence> zones, double edgeReachMetres) {
  Geofence? best;
  for (final z in zones) {
    final hit = z.contains(tap) || z.distanceToEdgeMetres(tap) <= edgeReachMetres;
    if (!hit) continue;
    if (best == null || z.areaSqMetres < best.areaSqMetres) best = z;
  }
  return best;
}

/// What the person holding this phone may do to a zone.
enum ZoneAccess {
  /// Theirs.
  owner,

  /// Someone else's, shared with permission to change it.
  edit,

  /// Someone else's, shared to look at only.
  view;

  bool get canEdit => this != ZoneAccess.view;
  bool get canDelete => this == ZoneAccess.owner;
}

/// Stubbed until accounts and sharing arrive (Phase 4.4).
///
/// Every zone on a phone today was drawn on that phone, so every answer is
/// [ZoneAccess.owner]. The question is asked anyway, at every place that
/// edits or deletes, so the read-only path exists and is tested before there
/// is anything shared to need it -- the sheet and the editor already behave
/// correctly for [ZoneAccess.view], and 4.4 only has to change this function.
///
/// When it does, this must be decided from the database (RLS on the shared
/// rows), not trusted from the UI: see CLAUDE.md, Supabase.
ZoneAccess accessFor(Geofence zone) => ZoneAccess.owner;

/// Whether [here] is inside [zone], or null when the fix cannot tell.
///
/// Null with no position, with unknown accuracy (reported as 0 or less), or
/// when the fix is looser than the distance to the edge: a ±500 m fix 100 m
/// from a boundary could be on either side of it, and saying "inside" would
/// be a claim the phone cannot back. CLAUDE.md: with no fix, say nothing.
bool? insideIfKnown(Geofence zone, LatLng? here, double accuracyMetres) {
  if (here == null || accuracyMetres <= 0) return null;
  if (accuracyMetres >= zone.distanceToEdgeMetres(here)) return null;
  return zone.contains(here);
}
