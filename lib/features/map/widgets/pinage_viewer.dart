import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bush_track/core/models/waypoint.dart';
import 'package:bush_track/features/map/services/pin_photo_editing.dart';
import 'package:bush_track/features/map/widgets/pin_photo_image.dart';
import 'package:bush_track/features/map/widgets/pin_photo_viewer.dart';
import 'package:bush_track/core/services/waypoint_share_service.dart';

/// Opens the Pinage viewer as a bottom sheet.
void showPinageViewer(
  BuildContext context, {
  required Waypoint waypoint,
  required VoidCallback onEdit,
  required VoidCallback onDelete,
  VoidCallback? onJumpToMap,
  VoidCallback? onTrack,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Color(0xFF0D0F1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: PinageViewerSheet(
        waypoint: waypoint,
        onEdit: onEdit,
        onDelete: onDelete,
        onJumpToMap: onJumpToMap,
        onTrack: onTrack,
      ),
    ),
  );
}

class PinageViewerSheet extends ConsumerStatefulWidget {
  final Waypoint waypoint;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onJumpToMap;
  final VoidCallback? onTrack;

  const PinageViewerSheet({
    required this.waypoint,
    required this.onEdit,
    required this.onDelete,
    this.onJumpToMap,
    this.onTrack,
    super.key,
  });

  @override
  ConsumerState<PinageViewerSheet> createState() => _PinageViewerSheetState();
}

class _PinageViewerSheetState extends ConsumerState<PinageViewerSheet> {
  int _currentImageIndex = 0;

  /// Held here as well as in the database so the strip, the count and the
  /// counter all move the moment a photo is added or removed, rather than on
  /// the next time the sheet is opened.
  late List<String> _photos;

  /// True while the camera or the compressor is busy.
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _photos = List<String>.from(widget.waypoint.photoPaths ?? const []);
  }

  List<String> get _media => _photos;

  @override
  Widget build(BuildContext context) {
    final w = widget.waypoint;
    final hasMedia = _media.isNotEmpty;
    final hasStory = w.notes != null && w.notes!.trim().isNotEmpty;

    return Stack(
      children: [
        Column(
          children: [
            // ── Header ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 0),
              child: Row(children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    // The pin's own colour, not a fixed amber. Choosing a
                    // colour is no use if the screen that shows the pin
                    // ignores it.
                    color:
                        WaypointColors.fromHex(w.color).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: WaypointColors.fromHex(w.color)
                            .withValues(alpha: 0.5)),
                  ),
                  child: Icon(WaypointIcon.getIconData(w.icon),
                      color: WaypointColors.fromHex(w.color), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        w.label ?? 'Pinage',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold),
                      ),
                      Text(
                        _formatDate(w.timestamp),
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white38),
                  onPressed: () => Navigator.pop(context),
                ),
              ]),
            ),

            // Photo count chip
            if (hasMedia)
              Padding(
                padding: const EdgeInsets.only(left: 20, top: 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB300).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color:
                              const Color(0xFFFFB300).withValues(alpha: 0.3)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.photo_library_outlined,
                          color: Color(0xFFFFB300), size: 12),
                      const SizedBox(width: 5),
                      Text(
                        '${_media.length} photo${_media.length == 1 ? '' : 's'}',
                        style: const TextStyle(
                            color: Color(0xFFFFB300),
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                    ]),
                  ),
                ),
              ),

            const Divider(color: Colors.white10, height: 20),

            // ── Scrollable body ────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                    20, 0, 20, MediaQuery.of(context).padding.bottom + 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Photo gallery ────────────────────────────────────
                    if (!hasMedia) _emptyViewer(),
                    if (hasMedia) ...[
                      // Main image
                      GestureDetector(
                        onTap: () => _openViewer(_currentImageIndex),
                        child: Container(
                          height: 220,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              _imageWidget(_media[_currentImageIndex]),
                              // Expand icon hint
                              Positioned(
                                top: 10,
                                right: 10,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.55),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.open_in_full,
                                      color: Colors.white70, size: 14),
                                ),
                              ),
                              // Image counter
                              if (_media.length > 1)
                                Positioned(
                                  bottom: 10,
                                  right: 10,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.black.withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${_currentImageIndex + 1} / ${_media.length}',
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 11),
                                    ),
                                  ),
                                ),
                              // Add more, mirroring the counter on the right.
                              Positioned(
                                bottom: 10,
                                left: 10,
                                child: GestureDetector(
                                  onTap: _busy ? null : _addPhotos,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.black.withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                          color: const Color(0xFFFFB300)
                                              .withValues(alpha: 0.7)),
                                    ),
                                    child: Row(children: [
                                      if (_busy)
                                        const SizedBox(
                                          width: 13,
                                          height: 13,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Color(0xFFFFB300)),
                                        )
                                      else
                                        const Icon(Icons.add_a_photo_outlined,
                                            color: Color(0xFFFFB300), size: 14),
                                      const SizedBox(width: 6),
                                      Text(_busy ? 'Saving' : 'Add',
                                          style: const TextStyle(
                                              color: Color(0xFFFFB300),
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold)),
                                    ]),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Shown from the very first photo, not just from the
                      // second, because the strip is where the + tile lives.
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 58,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          // One past the end, for the + tile.
                          itemCount: _media.length + 1,
                          itemBuilder: (_, i) {
                            if (i == _media.length) return _addTile();
                            return GestureDetector(
                              key: ValueKey('pin-thumb-$i'),
                              onTap: () =>
                                  setState(() => _currentImageIndex = i),
                              onLongPress: () => _confirmRemovePhoto(i),
                              child: Container(
                                width: 56,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: i == _currentImageIndex
                                        ? const Color(0xFFFFB300)
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: _imageWidget(_media[i]),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Long-press a photo to remove it',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.25),
                            fontSize: 10),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // ── Story ────────────────────────────────────────────
                    if (hasStory) ...[
                      const Text(
                        'STORY',
                        style: TextStyle(
                            color: Colors.white38,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Text(
                          w.notes!,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14, height: 1.6),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    if (!hasStory) ...[
                      const SizedBox(height: 14),
                      Text(
                        'No story yet. Tap Edit to write one.',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.3),
                            fontSize: 12),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // ── Metadata ─────────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(children: [
                        _metaRow(Icons.location_on_outlined, 'Coordinates',
                            '${w.latitude?.toStringAsFixed(5)}, ${w.longitude?.toStringAsFixed(5)}'),
                        if (w.timestamp != null) ...[
                          const Divider(color: Colors.white10, height: 14),
                          _metaRow(Icons.calendar_today_outlined, 'Pinned',
                              _formatDate(w.timestamp)),
                        ],
                      ]),
                    ),
                    const SizedBox(height: 20),

                    // ── Track: the point of dropping a pin is getting back to it.
                    if (widget.onTrack != null) ...[
                      SizedBox(
                        width: double.infinity,
                        child: _actionBtn(_ActionSpec(
                          Icons.navigation_outlined,
                          'TRACK TO THIS PIN',
                          const Color(0xFF4CAF50),
                          () {
                            Navigator.pop(context);
                            widget.onTrack!();
                          },
                        )),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // ── Action buttons, two to a row ──────────────────────
                    //
                    // All four used to share one row. On a 360 px phone that
                    // left about 72 px a button, and "Show on Map" needs over a
                    // hundred, so it ran into Share. Two to a row gives each
                    // one 155 px, which fits with room to spare.
                    ..._actionGrid([
                      _ActionSpec(
                        Icons.edit_outlined,
                        'Edit',
                        const Color(0xFFFFB300),
                        () {
                          Navigator.pop(context);
                          widget.onEdit();
                        },
                      ),
                      if (widget.onJumpToMap != null)
                        _ActionSpec(
                          Icons.location_on,
                          'Show on Map',
                          const Color(0xFF00E5FF),
                          () {
                            Navigator.pop(context);
                            widget.onJumpToMap!();
                          },
                        ),
                      _ActionSpec(
                        Icons.share_outlined,
                        'Share',
                        const Color(0xFF7B2FFF),
                        () async {
                          final ok = await WaypointShareService.shareWaypoint(
                              widget.waypoint);
                          if (!ok && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Nothing to share — pin has no location.')),
                            );
                          }
                        },
                      ),
                      _ActionSpec(
                        Icons.delete_outline,
                        'Delete',
                        const Color(0xFFFF3B30),
                        () => _confirmDelete(context),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// The shared full-screen viewer, pushed as a route.
  ///
  /// Was an overlay drawn inside this sheet, with its own PageView, its own
  /// counter and no caption — and the AR sheet had no viewer at all. One
  /// component now serves both, so the add button and long-press delete work
  /// in the camera too, and closing it lands back on whichever sheet opened it.
  Future<void> _openViewer(int index) async {
    final next = await openPinPhotoViewer(
      context,
      photos: _photos,
      initialIndex: index,
      title: widget.waypoint.label ?? 'Pin',
      notes: widget.waypoint.notes,
      takenAt: widget.waypoint.timestamp,
      onAdd: () => PinPhotoEditing.addPhotos(context, ref,
          waypoint: widget.waypoint, current: _photos),
      onDelete: (i) => PinPhotoEditing.confirmRemove(context, ref,
          waypoint: widget.waypoint, current: _photos, index: i),
    );
    if (next == null || !mounted) return;
    setState(() {
      _photos = next;
      if (_currentImageIndex >= _photos.length) {
        _currentImageIndex = _photos.isEmpty ? 0 : _photos.length - 1;
      }
    });
  }

  /// Handles a photo stored either way — base64 in the database, or a file on
  /// disk after the migration. See PinPhotoImage.
  Widget _imageWidget(String src) =>
      PinPhotoImage(reference: src, width: double.infinity);

  /// The viewer when the pin has no photos at all.
  Widget _emptyViewer() => GestureDetector(
        onTap: _busy ? null : _addPhotos,
        child: Container(
          height: 160,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white.withValues(alpha: 0.04),
            border: Border.all(
                color: const Color(0xFFFFB300).withValues(alpha: 0.35)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_busy)
                const CircularProgressIndicator(
                    strokeWidth: 2.5, color: Color(0xFFFFB300))
              else
                const Icon(Icons.add_a_photo_outlined,
                    color: Color(0xFFFFB300), size: 34),
              const SizedBox(height: 10),
              Text(_busy ? 'Saving photos…' : 'Add photo',
                  style: const TextStyle(
                      color: Color(0xFFFFB300),
                      fontSize: 14,
                      fontWeight: FontWeight.bold)),
              if (!_busy) ...[
                const SizedBox(height: 4),
                Text('Camera or gallery',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 11)),
              ],
            ],
          ),
        ),
      );

  /// The + at the end of the thumbnail strip.
  Widget _addTile() => GestureDetector(
        onTap: _busy ? null : _addPhotos,
        child: Container(
          width: 56,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: Colors.white.withValues(alpha: 0.04),
            border: Border.all(
                color: const Color(0xFFFFB300).withValues(alpha: 0.5)),
          ),
          child: Center(
            child: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Color(0xFFFFB300)),
                  )
                : const Icon(Icons.add, color: Color(0xFFFFB300), size: 22),
          ),
        ),
      );

  /// Ask camera or gallery, then append whatever comes back.
  Future<void> _addPhotos() async {
    // The spinner belongs to the capture, not to the question: it used to come
    // on while the camera-or-gallery sheet was still open, which read as
    // "saving" before anything had been chosen.
    final next = await PinPhotoEditing.addPhotos(
      context,
      ref,
      waypoint: widget.waypoint,
      current: _photos,
      onBusy: (b) {
        if (mounted) setState(() => _busy = b);
      },
    );
    if (!mounted) return;
    setState(() {
      if (next != null) {
        _photos = next;
        // Land on the first of the new ones, which is what was just taken.
        _currentImageIndex = _photos.length - 1;
      }
    });
  }

  Future<void> _confirmRemovePhoto(int index) async {
    final next = await PinPhotoEditing.confirmRemove(context, ref,
        waypoint: widget.waypoint, current: _photos, index: index);
    if (next == null || !mounted) return;
    setState(() {
      _photos = next;
      // The index has to come back inside the list, or the main viewer reads
      // off the end of it.
      if (_currentImageIndex >= next.length) {
        _currentImageIndex = next.isEmpty ? 0 : next.length - 1;
      }
    });
  }

  Widget _metaRow(IconData icon, String label, String? value) {
    // The value gets whatever room is left and shortens if it has to. It used
    // to be a plain Text after a Spacer, so a long one — a coordinate pair at
    // five decimal places, a date and time — had nowhere to go and pushed the
    // row past the edge of the sheet.
    return Row(children: [
      Icon(icon, color: Colors.white24, size: 14),
      const SizedBox(width: 8),
      Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12)),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          value ?? '—',
          textAlign: TextAlign.right,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
      ),
    ]);
  }

  /// Lay the actions out two to a row.
  ///
  /// Built from a list rather than written out, because "Show on Map" is only
  /// there when the caller can jump the map — so the grid has to read the same
  /// whether there are three buttons or four, and an odd one out should fill
  /// its row rather than sit at half width next to a gap.
  List<Widget> _actionGrid(List<_ActionSpec> actions) {
    final rows = <Widget>[];
    for (var i = 0; i < actions.length; i += 2) {
      final left = actions[i];
      final right = i + 1 < actions.length ? actions[i + 1] : null;
      if (rows.isNotEmpty) rows.add(const SizedBox(height: 10));
      rows.add(Row(children: [
        Expanded(child: _actionBtn(left)),
        if (right != null) ...[
          const SizedBox(width: 10),
          Expanded(child: _actionBtn(right)),
        ],
      ]));
    }
    return rows;
  }

  Widget _actionBtn(_ActionSpec a) {
    return GestureDetector(
      onTap: a.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
        decoration: BoxDecoration(
          color: a.color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: a.color.withValues(alpha: 0.35)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(a.icon, color: a.color, size: 18),
          const SizedBox(width: 7),
          // Never wrapped and never clipped mid-word: a label that cannot fit
          // shortens at the end instead of breaking across two lines and
          // changing the button's height.
          Flexible(
            child: Text(
              a.label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: a.color, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ]),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0D0F1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.red.withValues(alpha: 0.3)),
        ),
        title: const Text('Delete Pinage?',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Text(
          'Delete "${widget.waypoint.label ?? 'this pinage'}"?\nThis will also remove all attached photos.',
          style:
              const TextStyle(color: Colors.white60, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('CANCEL', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // close dialog
              Navigator.pop(context); // close viewer sheet
              widget.onDelete();
            },
            child: const Text('DELETE',
                style:
                    TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'Unknown';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}  $h:${dt.minute.toString().padLeft(2, '0')} $ampm';
  }
}

enum _PhotoSource { camera, gallery }

/// One button in the action grid.
class _ActionSpec {
  const _ActionSpec(this.icon, this.label, this.color, this.onTap);

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
}

