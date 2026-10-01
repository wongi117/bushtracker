import 'dart:io';

import 'package:flutter/material.dart';

import 'package:bush_track/core/services/photo_file_store.dart';

/// A pin photo, however it happens to be stored.
///
/// Photos are moving from base64 in the database to files on disk, and both
/// forms exist at once: a phone part-way through the migration, a pin added by
/// an older build, a photo whose file write failed and was left as base64 on
/// purpose. Every place that draws a photo therefore has to handle both, and
/// the decode logic was already copied into four of them — so it lives here
/// once instead.
///
/// It is also the one place that decides what "unreadable" looks like, which
/// matters: a mute placeholder is indistinguishable from a pin with no photos,
/// and that is how a storage bug went unnoticed for weeks.
class PinPhotoImage extends StatefulWidget {
  const PinPhotoImage({
    super.key,
    required this.reference,
    this.store,
    this.resolve,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.showLabel = true,
  });

  /// Either a `data:` URI or a file name relative to the photo directory.
  final String reference;

  /// Injected by the tests; the default store is used otherwise.
  final PhotoFileStore? store;

  /// How a file reference becomes a file. Overridable so a widget test can
  /// exercise the branches without real disk I/O, which does not run under the
  /// fake clock a widget test uses — the file behaviour itself is covered
  /// against a real directory in photo_migration_test.
  final Future<File?> Function(String reference)? resolve;

  final BoxFit fit;
  final double? width;
  final double? height;

  /// Whether to spell out "Photo unavailable". Off in a thumbnail, where the
  /// words do not fit and the icon has to carry it.
  final bool showLabel;

  @override
  State<PinPhotoImage> createState() => _PinPhotoImageState();
}

class _PinPhotoImageState extends State<PinPhotoImage> {
  /// Resolved once, in initState — not in build.
  ///
  /// A Future created inside build is remade on every rebuild, so a photo in a
  /// scrolling list would hit the file system again on every frame, and in a
  /// widget test the FutureBuilder never left its waiting state at all.
  Future<File?>? _file;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(PinPhotoImage old) {
    super.didUpdateWidget(old);
    // A recycled list tile gets a different photo without being rebuilt from
    // scratch; without this it would keep showing the previous one.
    if (old.reference != widget.reference) _resolve();
  }

  void _resolve() {
    if (PhotoFileStore.isDataUri(widget.reference)) {
      _file = null;
      return;
    }
    final resolver =
        widget.resolve ?? (widget.store ?? PhotoFileStore()).resolve;
    _file = resolver(widget.reference);
  }

  @override
  Widget build(BuildContext context) {
    final reference = widget.reference;
    final fit = widget.fit;
    final width = widget.width;
    final height = widget.height;
    // A data URI needs no file system, so it draws synchronously — no flicker
    // on a list that is scrolling.
    final bytes = PhotoFileStore.decodeDataUri(reference);
    if (bytes != null) {
      return Image.memory(
        bytes,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (_, __, ___) => _unavailable(),
      );
    }

    if (PhotoFileStore.isDataUri(reference)) {
      // It claims to be a data URI and is not readable as one — the shredded
      // leftovers of the old comma-joined column look exactly like this.
      return _unavailable();
    }

    return FutureBuilder<File?>(
      future: _file,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return _placeholder();
        }
        final file = snap.data;
        if (file == null) return _unavailable();
        return Image.file(
          file,
          fit: fit,
          width: width,
          height: height,
          errorBuilder: (_, __, ___) => _unavailable(),
        );
      },
    );
  }

  Widget _placeholder() => Container(
        width: widget.width,
        height: widget.height,
        color: Colors.white.withValues(alpha: 0.04),
      );

  Widget _unavailable() => Container(
        width: widget.width,
        height: widget.height,
        color: Colors.white.withValues(alpha: 0.05),
        alignment: Alignment.center,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // The same widget fills a 220 px viewer and a 56 px thumbnail. The
            // words only go where they fit; in a thumbnail they would overflow
            // the tile.
            final room = widget.showLabel &&
                constraints.maxHeight >= 90 &&
                constraints.maxWidth >= 90;
            if (!room) {
              return const Icon(Icons.broken_image_outlined,
                  color: Colors.white24, size: 22);
            }
            return Padding(
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
          },
        ),
      );
}
