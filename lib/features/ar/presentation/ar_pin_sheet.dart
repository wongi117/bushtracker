import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:bush_track/core/models/photo_paths_codec.dart';
import 'package:bush_track/core/models/waypoint.dart';
import 'package:bush_track/core/services/heading/heading_reading.dart';
import 'package:bush_track/features/ar/services/ar_targets.dart';
import 'package:bush_track/features/map/widgets/waypoint_editor.dart';
import 'package:bush_track/features/tracking/providers/track_target_provider.dart';
import 'package:bush_track/theme/app_colors.dart';

/// What a pin tapped through the camera offers.
///
/// A tap on a beam used to do nothing at all — the labels were painted, not
/// built, so there was nothing to tap. Now the same pin you can see out there
/// can be tracked, edited or sent to the map without leaving the camera first.
Future<void> showArPinSheet(
  BuildContext context, {
  required ArTarget target,
  required VoidCallback onShowOnMap,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _ArPinSheet(target: target, onShowOnMap: onShowOnMap),
  );
}

class _ArPinSheet extends ConsumerWidget {
  const _ArPinSheet({required this.target, required this.onShowOnMap});

  final ArTarget target;
  final VoidCallback onShowOnMap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wp = target.waypoint;
    final colour = WaypointColors.fromHex(wp.color);
    final tracked = ref.watch(trackTargetProvider);
    final isTracked = tracked != null &&
        wp.latitude != null &&
        (tracked.position.latitude - wp.latitude!).abs() < 1e-9 &&
        (tracked.position.longitude - wp.longitude!).abs() < 1e-9;

    final away = target.distanceM >= 1000
        ? '${(target.distanceM / 1000).toStringAsFixed(2)} km'
        : '${target.distanceM.round()} m';
    final cardinal = HeadingReading(
      degrees: target.bearingDeg,
      quality: HeadingQuality.good,
      source: HeadingSourceKind.sensors,
    ).cardinal;

    final photo = _firstPhoto(wp);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.panelMatte,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      padding: EdgeInsets.fromLTRB(
          18, 10, 18, MediaQuery.of(context).padding.bottom + 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.panelHighlight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Row(children: [
            if (photo != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(
                  photo,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _noPhoto(colour),
                ),
              ),
              const SizedBox(width: 12),
            ] else ...[
              _noPhoto(colour),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    wp.label ?? 'Pin',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$away away  ·  $cardinal '
                    '${target.bearingDeg.round()}°',
                    style: const TextStyle(
                        color: AppColors.accentLight, fontSize: 12),
                  ),
                  if (wp.notes != null && wp.notes!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      wp.notes!.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
          ]),
          const SizedBox(height: 18),

          Row(children: [
            Expanded(
              child: _action(
                isTracked ? Icons.gps_off : Icons.navigation_outlined,
                isTracked ? 'STOP' : 'TRACK',
                isTracked ? AppColors.statusRed : const Color(0xFF4CAF50),
                () {
                  final notifier = ref.read(trackTargetProvider.notifier);
                  if (isTracked) {
                    notifier.state = null;
                  } else {
                    // The same tracking state "Track to this pin" sets on the
                    // map, so the edge-of-screen arrow and the ground track in
                    // the camera pick it up without a second mechanism.
                    notifier.state = TrackTarget(
                      name: wp.label ?? 'Pin',
                      position: LatLng(wp.latitude!, wp.longitude!),
                      colour: colour,
                    );
                  }
                  Navigator.pop(context);
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _action(
                Icons.edit_outlined,
                'EDIT',
                const Color(0xFFFFB300),
                () async {
                  Navigator.pop(context);
                  // Back to the camera afterwards: the editor is pushed over
                  // the AR screen rather than replacing it.
                  await showWaypointEditor(context, waypoint: wp);
                },
              ),
            ),
          ]),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: _action(Icons.map_outlined, 'SHOW ON MAP',
                const Color(0xFF00E5FF), onShowOnMap),
          ),
        ],
      ),
    );
  }

  Widget _noPhoto(Color colour) => Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: colour.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colour.withValues(alpha: 0.4)),
        ),
        child: Icon(WaypointIcon.getIconData(target.waypoint.icon),
            color: colour, size: 24),
      );

  Widget _action(
          IconData icon, String label, Color colour, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
          decoration: BoxDecoration(
            color: colour.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colour.withValues(alpha: 0.4)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: colour, size: 17),
            const SizedBox(width: 7),
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: colour,
                      fontWeight: FontWeight.w900,
                      fontSize: 12.5)),
            ),
          ]),
        ),
      );
}

/// The pin's first photo, decoded, or null if it has none that can be read.
Uint8List? _firstPhoto(Waypoint wp) {
  final photos = wp.photoPaths;
  if (photos == null || photos.isEmpty) return null;
  final first = photos.first;
  if (!PhotoPathsCodec.looksLikeImage(first)) return null;
  try {
    return base64Decode(first.substring(first.indexOf(',') + 1));
  } catch (_) {
    return null;
  }
}
