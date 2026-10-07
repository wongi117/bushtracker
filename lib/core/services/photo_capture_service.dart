import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import 'photo_file_store.dart';

/// Photos, from the camera or the gallery, ready to store on a pin.
///
/// Compression happens off the UI thread. Adding half a dozen photos in a row
/// means half a dozen decode-resize-encode passes, and doing that on the main
/// isolate freezes the sheet mid-tap.
class PhotoCaptureService {
  const PhotoCaptureService._();

  /// Longest edge kept, matching what the AR camera already writes so photos
  /// from either route are the same size on disk.
  static const int _maxWidth = 1200;
  static const int _quality = 80;

  /// A safety rail on the take-several-in-a-row loop, so a stuck picker cannot
  /// spin forever.
  static const int _maxInOneGo = 30;

  /// Take photos until the camera is dismissed.
  ///
  /// The camera reopens after each shot, so several can be taken in a row and
  /// every one is returned; dismissing it ends the run. Returns what was taken
  /// before that, which may be nothing.
  ///
  /// [onShot] runs after each photo, with that photo's reference, and is how a
  /// caller saves as it goes. Saving only once the camera was dismissed meant
  /// a long run held every photo in memory and nothing in the database: if
  /// Android reclaimed the app while the camera had the screen -- which it is
  /// entitled to do -- the whole run was gone.
  static Future<List<String>> fromCamera({
    Future<void> Function(String reference)? onShot,
    PhotoFileStore? store,
  }) async {
    final picker = ImagePicker();
    final photos = <String>[];

    while (photos.length < _maxInOneGo) {
      final XFile? shot;
      try {
        shot = await picker.pickImage(source: ImageSource.camera);
      } catch (e) {
        debugPrint('Camera unavailable: $e');
        break;
      }
      // Dismissed: that is how you say "done", so keep what came before it.
      if (shot == null) break;

      final reference = await _toReference(shot, store);
      if (reference != null) {
        photos.add(reference);
        await onShot?.call(reference);
      }
    }

    return photos;
  }

  /// Pick any number of photos from the gallery in one go.
  static Future<List<String>> fromGallery({PhotoFileStore? store}) async {
    final picker = ImagePicker();
    List<XFile> picked;
    try {
      picked = await picker.pickMultiImage();
    } catch (e) {
      debugPrint('Gallery unavailable: $e');
      return const [];
    }

    final photos = <String>[];
    for (final file in picked.take(_maxInOneGo)) {
      final reference = await _toReference(file, store);
      if (reference != null) photos.add(reference);
    }
    return photos;
  }

  static Future<String?> _toReference(XFile file, PhotoFileStore? store) async {
    final Uint8List compressed;
    try {
      final raw = await file.readAsBytes();
      compressed = await compute(compressForStorage, raw);
    } catch (e) {
      debugPrint('Could not read photo: $e');
      return null;
    }
    return keep(compressed, store: store);
  }

  /// Store a compressed photo and return the reference to put on the pin.
  ///
  /// A file in the photo store, read back before it is trusted. Every capture
  /// path used to put a base64 data URI in the pin's row instead -- 220 to 420
  /// KB a photo, measured on real phone photos -- and Android reads a row
  /// through a 2 MB window, so about six photos on one pin made a row the
  /// platform will not hand back. The migration moved old photos out; nothing
  /// stopped new ones going straight back in.
  ///
  /// Falls back to the data URI when there is no store (web) or the write
  /// does not read back. That is the old behaviour, and keeping a photo badly
  /// is better than dropping it.
  static Future<String> keep(Uint8List jpeg, {PhotoFileStore? store}) async {
    final files = store ?? PhotoFileStore();
    try {
      if (await files.isAvailable) {
        final reference = await files.write(jpeg);
        final back = await files.read(reference);
        if (back != null && back.length == jpeg.length) return reference;
        debugPrint('Photo $reference did not read back; keeping it inline');
      }
    } catch (e) {
      debugPrint('Photo store write failed; keeping it inline: $e');
    }
    return 'data:image/jpeg;base64,${base64Encode(jpeg)}';
  }

  /// Shrink and re-encode as JPEG.
  ///
  /// Top level so it can run in another isolate through [compute]. Hands back
  /// the original bytes if they cannot be decoded, which is better than losing
  /// the photo over a format this build cannot read.
  @visibleForTesting
  static Uint8List compressForStorage(Uint8List raw) => _compress(raw);
}

Uint8List _compress(Uint8List raw) {
  final decoded = img.decodeImage(raw);
  if (decoded == null) return raw;
  final resized = img.copyResize(
    decoded,
    width: decoded.width > PhotoCaptureService._maxWidth
        ? PhotoCaptureService._maxWidth
        : decoded.width,
  );
  return Uint8List.fromList(
      img.encodeJpg(resized, quality: PhotoCaptureService._quality));
}

/// The isolate entry point for [compute].
Uint8List compressForStorage(Uint8List raw) => _compress(raw);
