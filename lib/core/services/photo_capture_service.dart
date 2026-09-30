import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

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
  static Future<List<String>> fromCamera() async {
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

      final encoded = await _toDataUri(shot);
      if (encoded != null) photos.add(encoded);
    }

    return photos;
  }

  /// Pick any number of photos from the gallery in one go.
  static Future<List<String>> fromGallery() async {
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
      final encoded = await _toDataUri(file);
      if (encoded != null) photos.add(encoded);
    }
    return photos;
  }

  static Future<String?> _toDataUri(XFile file) async {
    try {
      final raw = await file.readAsBytes();
      final compressed = await compute(compressForStorage, raw);
      return 'data:image/jpeg;base64,${base64Encode(compressed)}';
    } catch (e) {
      debugPrint('Could not read photo: $e');
      return null;
    }
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
