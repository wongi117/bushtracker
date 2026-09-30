import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bush_track/core/models/photo_paths_codec.dart';
import 'package:bush_track/core/models/waypoint.dart';
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
  bool _showFullscreen = false;

  List<String> get _media => widget.waypoint.photoPaths ?? [];

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
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB300).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.photo_camera_rounded, color: Color(0xFFFFB300), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        w.label ?? 'Pinage',
                        style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        _formatDate(w.timestamp),
                        style: const TextStyle(color: Colors.white38, fontSize: 11),
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB300).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFFFB300).withValues(alpha: 0.3)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.photo_library_outlined, color: Color(0xFFFFB300), size: 12),
                      const SizedBox(width: 5),
                      Text(
                        '${_media.length} photo${_media.length == 1 ? '' : 's'}',
                        style: const TextStyle(color: Color(0xFFFFB300), fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ]),
                  ),
                ),
              ),

            const Divider(color: Colors.white10, height: 20),

            // ── Scrollable body ────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).padding.bottom + 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Photo gallery ────────────────────────────────────
                    if (hasMedia) ...[
                      // Main image
                      GestureDetector(
                        onTap: () => setState(() => _showFullscreen = true),
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
                                top: 10, right: 10,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.55),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.open_in_full, color: Colors.white70, size: 14),
                                ),
                              ),
                              // Image counter
                              if (_media.length > 1)
                                Positioned(
                                  bottom: 10, right: 10,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${_currentImageIndex + 1} / ${_media.length}',
                                      style: const TextStyle(color: Colors.white, fontSize: 11),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      if (_media.length > 1) ...[
                        const SizedBox(height: 10),
                        // Thumbnail strip
                        SizedBox(
                          height: 58,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _media.length,
                            itemBuilder: (_, i) => GestureDetector(
                              onTap: () => setState(() => _currentImageIndex = i),
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
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                    ],

                    // ── Story ────────────────────────────────────────────
                    if (hasStory) ...[
                      const Text(
                        'STORY',
                        style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Text(
                          w.notes!,
                          style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.6),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    if (!hasMedia && !hasStory) ...[
                      const SizedBox(height: 20),
                      Center(
                        child: Column(children: [
                          const Icon(Icons.photo_camera_outlined, color: Colors.white12, size: 48),
                          const SizedBox(height: 12),
                          Text(
                            'No photos or story yet.\nTap Edit to add them.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 13, height: 1.5),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 20),
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
                          _metaRow(Icons.calendar_today_outlined, 'Pinned', _formatDate(w.timestamp)),
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

        // ── Fullscreen image overlay ──────────────────────────────────────
        if (_showFullscreen)
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => _showFullscreen = false),
              child: Container(
                color: Colors.black.withValues(alpha: 0.92),
                child: Stack(
                  children: [
                    PageView.builder(
                      itemCount: _media.length,
                      controller: PageController(initialPage: _currentImageIndex),
                      onPageChanged: (i) => setState(() => _currentImageIndex = i),
                      itemBuilder: (_, i) => InteractiveViewer(
                        child: Center(child: _imageWidget(_media[i])),
                      ),
                    ),
                    Positioned(
                      top: 16, right: 16,
                      child: GestureDetector(
                        onTap: () => setState(() => _showFullscreen = false),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                    if (_media.length > 1)
                      Positioned(
                        bottom: 20, left: 0, right: 0,
                        child: Center(
                          child: Text(
                            '${_currentImageIndex + 1} / ${_media.length}',
                            style: const TextStyle(color: Colors.white60, fontSize: 13),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _imageWidget(String src) {
    if (!PhotoPathsCodec.looksLikeImage(src)) return const _BrokenImage();
    try {
      return Image.memory(
        base64Decode(src.substring(src.indexOf(',') + 1)),
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (_, __, ___) => const _BrokenImage(),
      );
    } catch (_) {
      // Malformed base64 throws here rather than reaching errorBuilder.
      return const _BrokenImage();
    }
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
        title: const Text('Delete Pinage?', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Text(
          'Delete "${widget.waypoint.label ?? 'this pinage'}"?\nThis will also remove all attached photos.',
          style: const TextStyle(color: Colors.white60, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // close dialog
              Navigator.pop(context); // close viewer sheet
              widget.onDelete();
            },
            child: const Text('DELETE', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'Unknown';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}  $h:${dt.minute.toString().padLeft(2, '0')} $ampm';
  }
}

/// One button in the action grid.
class _ActionSpec {
  const _ActionSpec(this.icon, this.label, this.color, this.onTap);

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
}

/// A photo that is on the pin but cannot be drawn.
///
/// Says so in words. It used to be a mute icon, indistinguishable at a glance
/// from a pin with no photos on it — so a real bug in how photos were stored
/// looked like nothing being there, and went unnoticed far longer than it
/// should have.
class _BrokenImage extends StatelessWidget {
  const _BrokenImage();

  @override
  Widget build(BuildContext context) => Container(
        color: Colors.white.withValues(alpha: 0.05),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.broken_image_outlined,
                color: Colors.white24, size: 28),
            const SizedBox(height: 6),
            Text('Photo unavailable',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 10)),
          ],
        ),
      );
}
