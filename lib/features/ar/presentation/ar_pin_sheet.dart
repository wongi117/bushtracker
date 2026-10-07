import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:bush_track/core/models/waypoint.dart';
import 'package:bush_track/core/services/heading/heading_reading.dart';
import 'package:bush_track/features/ar/services/ar_targets.dart';
import 'package:bush_track/features/map/services/pin_photo_editing.dart';
import 'package:bush_track/features/map/widgets/pin_photo_image.dart';
import 'package:bush_track/features/map/widgets/pin_photo_viewer.dart';
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
    // Draggable so the photo strip has somewhere to live: the sheet opens at
    // the size of the summary and its actions, and pulling it up brings the
    // photos into view without covering the camera when they are not wanted.
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.42,
      minChildSize: 0.3,
      maxChildSize: 0.88,
      expand: false,
      builder: (_, controller) => _ArPinSheet(
        target: target,
        onShowOnMap: onShowOnMap,
        scrollController: controller,
      ),
    ),
  );
}

class _ArPinSheet extends ConsumerStatefulWidget {
  const _ArPinSheet({
    required this.target,
    required this.onShowOnMap,
    required this.scrollController,
  });

  final ArTarget target;
  final VoidCallback onShowOnMap;
  final ScrollController scrollController;

  @override
  ConsumerState<_ArPinSheet> createState() => _ArPinSheetState();
}

class _ArPinSheetState extends ConsumerState<_ArPinSheet> {
  /// Held here so the badge, the strip and the thumbnail all move the moment a
  /// photo is added or removed, rather than on the next time the sheet opens.
  late List<String> _photos;

  @override
  void initState() {
    super.initState();
    _photos = List<String>.from(widget.target.waypoint.photoPaths ?? const []);
  }

  @override
  Widget build(BuildContext context) {
    final target = widget.target;
    final onShowOnMap = widget.onShowOnMap;
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

    final firstPhoto = _photos.isEmpty ? null : _photos.first;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.panelMatte,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      padding: EdgeInsets.fromLTRB(
          18, 10, 18, MediaQuery.of(context).viewPadding.bottom + 18),
      child: ListView(
        controller: widget.scrollController,
        padding: EdgeInsets.zero,
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
            _thumbnail(firstPhoto, colour),
            const SizedBox(width: 12),
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

          // ── Photos, revealed by pulling the sheet up ──────────────────────
          if (_photos.isNotEmpty) ...[
            const SizedBox(height: 18),
            Row(children: [
              const Text('PHOTOS',
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2)),
              const SizedBox(width: 8),
              Text('${_photos.length}',
                  style: const TextStyle(
                      color: AppColors.accentLight, fontSize: 10)),
              const Spacer(),
              GestureDetector(
                onTap: () => _openViewer(0),
                child: const Text('VIEW ALL',
                    style: TextStyle(
                        color: AppColors.accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w800)),
              ),
            ]),
            const SizedBox(height: 8),
            SizedBox(
              height: 64,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _photos.length + 1,
                itemBuilder: (_, i) {
                  if (i == _photos.length) return _addTile();
                  return GestureDetector(
                    key: ValueKey('ar-thumb-$i'),
                    onTap: () => _openViewer(i),
                    onLongPress: () => _removeAt(i),
                    child: Container(
                      width: 62,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _small(_photos[i]),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 4),
            Text('Tap to view · long-press to remove',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.25),
                    fontSize: 9.5)),
          ] else ...[
            const SizedBox(height: 14),
            GestureDetector(
              onTap: _addPhotos,
              child: Row(children: [
                const Icon(Icons.add_a_photo_outlined,
                    color: AppColors.accent, size: 16),
                const SizedBox(width: 8),
                const Text('Add a photo to this pin',
                    style: TextStyle(color: AppColors.accent, fontSize: 12)),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  /// The pin's first photo, tappable, with how many there are.
  Widget _thumbnail(String? photo, Color colour) {
    final count = _photos.length;

    return GestureDetector(
      onTap: count == 0 ? _addPhotos : () => _openViewer(0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (photo != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 56,
                height: 56,
                child: PinPhotoImage(reference: photo, showLabel: false),
              ),
            )
          else
            _noPhoto(colour),

          // Only worth saying when there is more than one; a badge reading "1"
          // tells nobody anything.
          if (count > 1)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: AppColors.panelMatte, width: 1.5),
                ),
                child: Text('$count',
                    style: const TextStyle(
                        color: Colors.black,
                        fontSize: 10,
                        fontWeight: FontWeight.w900)),
              ),
            ),

          if (photo != null)
            Positioned(
              left: 3,
              bottom: 3,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: const Icon(Icons.zoom_out_map,
                    color: Colors.white70, size: 11),
              ),
            ),
        ],
      ),
    );
  }

  Widget _addTile() => GestureDetector(
        onTap: _addPhotos,
        child: Container(
          width: 62,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            color: Colors.white.withValues(alpha: 0.04),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
          ),
          child: const Center(
              child: Icon(Icons.add, color: AppColors.accent, size: 20)),
        ),
      );

  Widget _small(String src) => PinPhotoImage(reference: src, showLabel: false);

  /// The same viewer the pin detail sheet uses, with the same add and remove.
  ///
  /// Pushed as a route over this sheet, so closing it comes straight back here
  /// with the pin still selected and the camera still behind.
  Future<void> _openViewer(int index) async {
    final wp = widget.target.waypoint;
    final next = await openPinPhotoViewer(
      context,
      photos: _photos,
      initialIndex: index,
      title: wp.label ?? 'Pin',
      notes: wp.notes,
      takenAt: wp.timestamp,
      // The viewer's list, not _photos: ours does not move until it closes.
      onAdd: (current) => PinPhotoEditing.addPhotos(context, ref,
          waypoint: wp, current: current),
      onDelete: (current, i) => PinPhotoEditing.confirmRemove(context, ref,
          waypoint: wp, current: current, index: i),
    );
    if (next != null && mounted) setState(() => _photos = next);
  }

  Future<void> _addPhotos() async {
    final next = await PinPhotoEditing.addPhotos(context, ref,
        waypoint: widget.target.waypoint, current: _photos);
    if (next != null && mounted) setState(() => _photos = next);
  }

  Future<void> _removeAt(int index) async {
    final next = await PinPhotoEditing.confirmRemove(context, ref,
        waypoint: widget.target.waypoint, current: _photos, index: index);
    if (next != null && mounted) setState(() => _photos = next);
  }

  Widget _noPhoto(Color colour) => Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: colour.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colour.withValues(alpha: 0.4)),
        ),
        child: Icon(WaypointIcon.getIconData(widget.target.waypoint.icon),
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
