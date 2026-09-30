import 'dart:convert';

/// Turns a pin's list of photos into one database column, and back.
///
/// It used to be `join(',')` on the way out and `split(',')` on the way in,
/// which worked only while photos were file paths. Photos are stored as base64
/// data URIs, and every data URI contains a comma — the one separating the
/// header from the payload:
///
///     data:image/jpeg;base64,/9j/4AAQSkZJRg...
///
/// So one saved photo came back as two entries, `data:image/jpeg;base64` and
/// the payload on its own. Neither is a usable image, and the pin reported
/// "2 photos" with a 1/2 counter and drew the placeholder twice. Two photos
/// read back as four, and so on.
///
/// Now the column holds a JSON array, which cannot be confused by anything in
/// its contents. [decode] still reads both of the older shapes, so photos
/// already saved on a phone come back rather than being written off.
class PhotoPathsCodec {
  const PhotoPathsCodec._();

  /// What goes into the `photo_paths` column. Null for no photos, so the column
  /// stays empty rather than holding `[]`.
  static String? encode(List<String>? photos) {
    if (photos == null || photos.isEmpty) return null;
    return jsonEncode(photos);
  }

  /// Read the column back, whatever era wrote it.
  ///
  /// Three shapes, in the order they are checked:
  ///
  ///  * a JSON array — everything written from now on;
  ///  * comma-joined data URIs — recoverable, because a data URI has exactly
  ///    one comma and always begins `data:`, so the pieces can be put back
  ///    together by cutting at each `data:` rather than at each comma;
  ///  * comma-joined file paths — the shape the old code was actually written
  ///    for, split on the comma as before.
  static List<String>? decode(Object? raw) {
    if (raw == null) return null;
    final text = raw.toString();
    if (text.trim().isEmpty) return null;

    final asJson = _tryJson(text);
    if (asJson != null) return asJson.isEmpty ? null : asJson;

    final recovered = _recoverDataUris(text);
    if (recovered != null) return recovered;

    final parts = text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return parts.isEmpty ? null : parts;
  }

  static List<String>? _tryJson(String text) {
    if (!text.trimLeft().startsWith('[')) return null;
    try {
      final decoded = jsonDecode(text);
      if (decoded is! List) return null;
      return decoded
          .map((e) => e?.toString() ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
    } catch (_) {
      // Not JSON after all — fall through to the older shapes.
      return null;
    }
  }

  /// Put comma-shredded data URIs back together.
  ///
  /// Cuts the string at every `data:` instead of at every comma. That is safe
  /// because base64 has no commas and no colons: everything between one
  /// `data:` and the next belongs to a single photo, however many commas it
  /// contains. Returns null when the text holds no data URI at all, so plain
  /// file paths are left to the caller.
  static List<String>? _recoverDataUris(String text) {
    const marker = 'data:';
    if (!text.contains(marker)) return null;

    final starts = <int>[];
    var at = text.indexOf(marker);
    while (at != -1) {
      starts.add(at);
      at = text.indexOf(marker, at + marker.length);
    }
    if (starts.isEmpty) return null;

    final photos = <String>[];
    for (var i = 0; i < starts.length; i++) {
      final end = i + 1 < starts.length ? starts[i + 1] : text.length;
      // Trim the comma the old join left behind between two photos.
      final piece = text.substring(starts[i], end).replaceAll(RegExp(r'[,\s]+$'), '');
      if (piece.length > marker.length) photos.add(piece);
    }
    return photos.isEmpty ? null : photos;
  }

  /// True when this looks like something [decode] could read an image out of.
  ///
  /// Used by the viewer to tell "this photo is broken" from "this pin has no
  /// photos", which are different things to show on screen.
  static bool looksLikeImage(String src) {
    if (src.startsWith('data:')) {
      final comma = src.indexOf(',');
      return comma > 0 && comma < src.length - 1;
    }
    return false;
  }
}
