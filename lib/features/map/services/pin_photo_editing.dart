import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bush_track/core/models/waypoint.dart';
import 'package:bush_track/core/services/photo_capture_service.dart';
import 'package:bush_track/features/tracking/providers/location_provider.dart';
import 'package:bush_track/theme/app_colors.dart';

/// Adding and removing a pin's photos, in one place.
///
/// The pin detail sheet and the AR sheet both offer this, and both need the
/// same behaviour: the camera reopening after each shot, a confirm before a
/// photo comes off, and the list written to the database as a whole so what is
/// stored and what is on screen cannot drift apart. Two copies of that would be
/// two sets of bugs, so there is one.
///
/// Every call returns the new photo list, or null when nothing changed —
/// cancelled, or no photos picked. Callers hold the list themselves so their
/// counters update on the spot rather than on the next open.
class PinPhotoEditing {
  const PinPhotoEditing._();

  /// Ask camera or gallery, then append whatever comes back.
  /// [onBusy] is called true once a source has been chosen and the real work
  /// starts, and false when it ends. Separate from the call itself because
  /// spinning a progress indicator while merely *asking* camera-or-gallery
  /// tells the user something is being saved when nothing is happening yet —
  /// and an indefinite animation also means a widget test can never settle.
  static Future<List<String>?> addPhotos(
    BuildContext context,
    WidgetRef ref, {
    required Waypoint waypoint,
    required List<String> current,
    void Function(bool busy)? onBusy,
  }) async {
    final source = await showModalBottomSheet<_Source>(
      context: context,
      backgroundColor: const Color(0xFF13162A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded,
                  color: Color(0xFFFFB300)),
              title: const Text('Take photos',
                  style: TextStyle(color: Colors.white, fontSize: 14)),
              subtitle: const Text(
                  'The camera reopens after each shot — take as many as you '
                  'need, then dismiss it',
                  style: TextStyle(color: Colors.white38, fontSize: 11)),
              onTap: () => Navigator.pop(sheet, _Source.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded,
                  color: Color(0xFF00E5FF)),
              title: const Text('Choose from gallery',
                  style: TextStyle(color: Colors.white, fontSize: 14)),
              subtitle: const Text('Pick one or several',
                  style: TextStyle(color: Colors.white38, fontSize: 11)),
              onTap: () => Navigator.pop(sheet, _Source.gallery),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
    if (source == null || !context.mounted) return null;

    onBusy?.call(true);
    // Read before the camera opens. Each shot is saved while the camera still
    // has the screen, and a ref from a sheet that has gone by then cannot be
    // read at all.
    final notifier = ref.read(locationProvider.notifier);
    var next = current;
    try {
      final List<String> added;
      if (source == _Source.camera) {
        // Saved shot by shot, so a run cut short -- Android reclaiming the app
        // behind the camera, a crash, a flat battery -- keeps what it took.
        added = await PhotoCaptureService.fromCamera(onShot: (reference) async {
          next = [...next, reference];
          await _persist(notifier, waypoint, next);
        });
      } else {
        added = await PhotoCaptureService.fromGallery();
        if (added.isNotEmpty) {
          next = [...current, ...added];
          await _persist(notifier, waypoint, next);
        }
      }
      if (added.isEmpty) return null;

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '${added.length} photo${added.length == 1 ? '' : 's'} added'),
        ));
      }
      return next;
    } finally {
      onBusy?.call(false);
    }
  }

  /// Confirm, then take one photo off the pin.
  static Future<List<String>?> confirmRemove(
    BuildContext context,
    WidgetRef ref, {
    required Waypoint waypoint,
    required List<String> current,
    required int index,
  }) async {
    if (index < 0 || index >= current.length) return null;

    final yes = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: const Color(0xFF0D0F1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.red.withValues(alpha: 0.3)),
        ),
        title: const Text('Remove this photo?',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Text(
          'Photo ${index + 1} of ${current.length} comes off this pin. The pin '
          'itself stays.',
          style:
              const TextStyle(color: Colors.white60, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child:
                const Text('CANCEL', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('REMOVE',
                style:
                    TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (yes != true) return null;

    final next = [...current]..removeAt(index);
    await _persist(ref.read(locationProvider.notifier), waypoint, next);
    return next;
  }

  static Future<void> _persist(
      LocationNotifier notifier, Waypoint waypoint, List<String> photos) async {
    final id = waypoint.id;
    if (id == null) return;
    await notifier.setWaypointPhotos(id, photos);
    // Keep the object the caller was handed in step with what was written, so
    // anything still holding it sees the same photos.
    waypoint.photoPaths = photos;
  }

  /// A short line for the "no photos" case, kept here so both sheets say the
  /// same thing.
  static const String emptyHint = 'Camera or gallery';

  static Color get accent => AppColors.accent;
}

enum _Source { camera, gallery }
