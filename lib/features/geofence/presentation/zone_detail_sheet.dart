import 'package:flutter/material.dart';

import 'package:bush_track/core/models/geofence.dart';
import 'package:bush_track/core/utils/geo_geometry.dart';
import 'package:bush_track/features/geofence/services/zone_selection.dart';
import 'package:bush_track/theme/app_colors.dart';

/// What the person chose from a zone's sheet.
enum ZoneSheetAction { track, edit, delete }

/// A zone's details, opened by tapping it on the map (Phase 4.3).
///
/// Only offers what works today. "Show in AR" waits for 4.5 and "Share" for
/// 4.4; a button that does nothing is a claim the app cannot keep.
class ZoneDetailSheet extends StatelessWidget {
  final Geofence zone;
  final ZoneAccess access;

  /// The project it is filed under, or null for Unsorted.
  final String? projectName;

  /// Whether the phone is standing in it now; null with no GPS fix, in which
  /// case nothing is said rather than a guess.
  final bool? inside;

  /// False where the actions make no sense, as through the AR camera: there
  /// is no map there to edit corners on or track across.
  final bool showActions;

  const ZoneDetailSheet({
    super.key,
    required this.zone,
    required this.access,
    this.projectName,
    this.inside,
    this.showActions = true,
  });

  @override
  Widget build(BuildContext context) {
    final colour = Color(zone.category.colorValue);
    final notes = zone.notes?.trim() ?? '';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(zone.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
              ),
              if (inside != null)
                Container(
                  key: const ValueKey('zone-inside'),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (inside! ? colour : Colors.white24)
                        .withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(inside! ? 'You are inside' : 'Outside',
                      style: const TextStyle(color: Colors.white, fontSize: 11)),
                ),
            ]),
            const SizedBox(height: 4),
            Text(
              '${zone.category.label} · '
              '${zone.isPolygon ? '${zone.points.length} corners' : '${formatDistance(zone.radiusMeters)} radius'}'
              '${zone.isActive ? '' : ' · alerts off'}',
              style: const TextStyle(color: Colors.white60, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Row(children: [
              _fact('Area', formatArea(zone.areaSqMetres)),
              _fact('Perimeter', formatDistance(zone.perimeterMetres)),
              _fact('Project', projectName ?? 'Unsorted'),
            ]),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(notes,
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ],
            if (!access.canEdit) ...[
              const SizedBox(height: 12),
              const Text('Shared with you to view. You cannot change it.',
                  key: ValueKey('zone-view-only'),
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
            ],
            if (showActions) ...[
            const SizedBox(height: 14),
            Row(children: [
              TextButton.icon(
                onPressed: () => Navigator.pop(context, ZoneSheetAction.track),
                icon: const Icon(Icons.navigation_outlined,
                    color: Color(0xFF4CAF50)),
                label: const Text('Track to',
                    style: TextStyle(color: Color(0xFF4CAF50))),
              ),
              if (access.canEdit)
                TextButton.icon(
                  onPressed: () => Navigator.pop(context, ZoneSheetAction.edit),
                  icon: const Icon(Icons.edit, color: AppColors.primaryOrange),
                  label: Text(zone.isPolygon ? 'Edit corners' : 'Resize',
                      style: const TextStyle(color: AppColors.primaryOrange)),
                ),
              const Spacer(),
              if (access.canDelete)
                IconButton(
                  tooltip: 'Delete zone',
                  onPressed: () =>
                      Navigator.pop(context, ZoneSheetAction.delete),
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.redAccent),
                ),
            ]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _fact(String label, String value) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(color: Colors.white38, fontSize: 11)),
            const SizedBox(height: 2),
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );
}
