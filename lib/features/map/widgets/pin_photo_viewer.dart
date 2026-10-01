import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:bush_track/core/models/photo_paths_codec.dart';

/// A pin's photos, full screen.
///
/// One viewer, opened from the pin detail sheet and from the AR sheet alike.
/// Building a second one for the camera would have meant two sets of behaviour
/// to keep in step — and the add and delete actions only existed in one of
/// them, so the camera would have been the poor relation.
///
/// Pushed as a route rather than drawn as an overlay inside a sheet, which is
/// what makes closing it land back exactly where it came from with the same pin
/// still selected.
class PinPhotoViewer extends StatefulWidget {
  const PinPhotoViewer({
    super.key,
    required this.photos,
    this.initialIndex = 0,
    this.title,
    this.notes,
    this.takenAt,
    this.onAdd,
    this.onDelete,
  });

  final List<String> photos;
  final int initialIndex;

  /// The pin's name, shown along the top.
  final String? title;

  /// The pin's notes, shown as the caption.
  final String? notes;

  final DateTime? takenAt;

  /// Add more photos. Returns the new list, or null if nothing was added.
  /// Omit to show no add button — which is how a read-only pin is handled once
  /// there are shared pins to be read-only about.
  final Future<List<String>?> Function()? onAdd;

  /// Remove the photo at an index. Returns the new list, or null if cancelled.
  final Future<List<String>?> Function(int index)? onDelete;

  @override
  State<PinPhotoViewer> createState() => _PinPhotoViewerState();
}

class _PinPhotoViewerState extends State<PinPhotoViewer> {
  late PageController _pages;
  late List<String> _photos;
  late int _index;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _photos = [...widget.photos];
    _index = widget.initialIndex.clamp(0, _photos.isEmpty ? 0 : _photos.length - 1);
    // Held in state, not built in build. The old viewer made a new
    // PageController on every rebuild, which leaks them and snaps the page back
    // to wherever the index happened to be.
    _pages = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  /// What the caller should take away: the photo list as it now stands.
  void _close() => Navigator.pop(context, _photos);

  @override
  Widget build(BuildContext context) {
    if (_photos.isEmpty) {
      // Everything was deleted while in here. Nothing left to look at.
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: BackButton(color: Colors.white, onPressed: _close),
        ),
        body: const Center(
          child: Text('No photos on this pin',
              style: TextStyle(color: Colors.white54)),
        ),
      );
    }

    final taken = widget.takenAt;
    final caption = widget.notes?.trim();

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Pinch to zoom, swipe to move between photos. One InteractiveViewer
            // per page, so zooming one does not carry over to the next.
            PageView.builder(
              controller: _pages,
              itemCount: _photos.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) => InteractiveViewer(
                maxScale: 5,
                child: Center(child: _image(_photos[i])),
              ),
            ),

            // ── Top bar
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Row(children: [
                _round(Icons.close, _close),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.title ?? 'Photos',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                if (widget.onAdd != null)
                  _round(Icons.add_a_photo_outlined, _busy ? null : _add),
                if (widget.onDelete != null) ...[
                  const SizedBox(width: 8),
                  _round(Icons.delete_outline, _busy ? null : _delete,
                      tint: const Color(0xFFFF453A)),
                ],
              ]),
            ),

            // ── Bottom: counter, caption, date
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.75),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('${_index + 1} / ${_photos.length}',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12)),
                      ),
                      if (taken != null) ...[
                        const SizedBox(width: 10),
                        Text(_formatDate(taken),
                            style: const TextStyle(
                                color: Colors.white60, fontSize: 11)),
                      ],
                    ]),
                    if (caption != null && caption.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(caption,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12.5,
                              height: 1.4)),
                    ],
                    if (widget.onDelete != null) ...[
                      const SizedBox(height: 6),
                      const Text('Swipe between photos · pinch to zoom',
                          style:
                              TextStyle(color: Colors.white24, fontSize: 10)),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _add() async {
    setState(() => _busy = true);
    final next = await widget.onAdd!.call();
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (next != null) {
        _photos = next;
        // Land on the last of the new ones, which is what was just taken.
        _index = _photos.length - 1;
      }
    });
    _jumpTo(_index);
  }

  Future<void> _delete() async {
    setState(() => _busy = true);
    final next = await widget.onDelete!.call(_index);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (next != null) {
        _photos = next;
        // The index has to come back inside the list, or the page builder reads
        // off the end of it.
        if (_index >= _photos.length) _index = _photos.length - 1;
        if (_index < 0) _index = 0;
      }
    });
    _jumpTo(_index);
  }

  /// Move the PageView to [target] once it has been rebuilt with the new count.
  ///
  /// Two things make this fiddlier than it looks. Jumping inside the setState
  /// that changes the list does not work, because the PageView still has the
  /// old itemCount at that moment, so a jump to a newly added last page is out
  /// of range and gets clamped one short. And the target has to be captured
  /// rather than read from the field in the callback: rebuilding with a new
  /// itemCount makes the PageView fire onPageChanged for where it currently
  /// sits, which overwrites _index before the callback runs — so reading the
  /// field again jumped back to the photo we were trying to leave.
  void _jumpTo(int target) {
    if (_photos.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pages.hasClients) return;
      final safe = target.clamp(0, _photos.length - 1);
      _pages.jumpToPage(safe);
      if (_index != safe) setState(() => _index = safe);
    });
  }

  Widget _round(IconData icon, VoidCallback? onTap, {Color? tint}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: Icon(icon,
              color: onTap == null ? Colors.white24 : (tint ?? Colors.white),
              size: 19),
        ),
      );

  Widget _image(String src) {
    if (!PhotoPathsCodec.looksLikeImage(src)) return const _Unavailable();
    try {
      return Image.memory(
        base64Decode(src.substring(src.indexOf(',') + 1)),
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const _Unavailable(),
      );
    } catch (_) {
      return const _Unavailable();
    }
  }

  static String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final h = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
    final ampm = d.hour >= 12 ? 'pm' : 'am';
    return '${months[d.month - 1]} ${d.day}, ${d.year}  '
        '$h:${d.minute.toString().padLeft(2, '0')}$ampm';
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable();

  @override
  Widget build(BuildContext context) => const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.broken_image_outlined, color: Colors.white24, size: 40),
            SizedBox(height: 10),
            Text('Photo unavailable',
                style: TextStyle(color: Colors.white38, fontSize: 12)),
          ],
        ),
      );
}

/// Open the viewer, and hand back the photo list as it stands on close.
///
/// Returns null if nothing was added or removed, so a caller can tell "closed"
/// from "changed" without comparing lists.
Future<List<String>?> openPinPhotoViewer(
  BuildContext context, {
  required List<String> photos,
  int initialIndex = 0,
  String? title,
  String? notes,
  DateTime? takenAt,
  Future<List<String>?> Function()? onAdd,
  Future<List<String>?> Function(int index)? onDelete,
}) async {
  final before = photos.length;
  final out = await Navigator.push<List<String>>(
    context,
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => PinPhotoViewer(
        photos: photos,
        initialIndex: initialIndex,
        title: title,
        notes: notes,
        takenAt: takenAt,
        onAdd: onAdd,
        onDelete: onDelete,
      ),
    ),
  );
  if (out == null) return null;
  // Same length and same contents means nothing happened in there.
  if (out.length == before && out.join() == photos.join()) return null;
  return out;
}
