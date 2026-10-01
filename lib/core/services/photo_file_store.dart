import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Pin photos as files on disk.
///
/// They were base64 data URIs inside the `photo_paths` column. That is durable
/// enough — it survives a restart, which was never the problem — but a 1200 px
/// JPEG is 150–250 KB of base64, so a pin with ten photos is a ~2 MB row, and
/// the whole row is read every time the waypoint list loads. With 516 pins on
/// the handset that is a lot of base64 being parsed to draw a map.
///
/// Paths are stored **relative** to the photo directory, never absolute. The
/// documents directory is not guaranteed to be the same string across an
/// install, a restore or an OS upgrade, and an absolute path baked into the
/// database would then point at nothing — the photo would still be on disk and
/// the app would say "Photo unavailable", which is the worst of both.
class PhotoFileStore {
  PhotoFileStore({Directory? baseDirectory}) : _override = baseDirectory;

  /// Injected by the tests, which have no platform channels.
  final Directory? _override;

  Directory? _resolved;

  static const String folderName = 'pin_photos';

  /// Where the files live, or null where there is nowhere to put them.
  ///
  /// Null on web, which has no documents directory, and in a widget test,
  /// which has no platform channels. Both have to degrade rather than throw:
  /// on web photos stay as base64 in the database and that is correct, and a
  /// viewer that threw instead of saying "Photo unavailable" would take the
  /// whole screen down over one bad photo.
  Future<Directory?> directory() async {
    final cached = _resolved;
    if (cached != null) return cached;

    try {
      final base = _override ?? await getApplicationDocumentsDirectory();
      final dir = Directory(p.join(base.path, folderName));
      if (!await dir.exists()) await dir.create(recursive: true);
      _resolved = dir;
      return dir;
    } catch (e) {
      debugPrint('PhotoFileStore has no directory available: $e');
      return null;
    }
  }

  /// True when photos can be kept on disk at all. False on web.
  Future<bool> get isAvailable async => await directory() != null;

  /// Write bytes and hand back the relative path to store in the database.
  Future<String> write(Uint8List bytes, {String? extension}) async {
    final dir = await directory();
    if (dir == null) {
      throw StateError('No photo directory on this platform');
    }
    final name = '${_id()}.${extension ?? 'jpg'}';
    final file = File(p.join(dir.path, name));
    await file.writeAsBytes(bytes, flush: true);
    return name;
  }

  /// Turn a stored reference into a file, or null if it is not one.
  ///
  /// Returns null for a `data:` URI, which is how an unmigrated photo is told
  /// apart from a migrated one without a separate flag.
  Future<File?> resolve(String reference) async {
    if (isDataUri(reference)) return null;
    final dir = await directory();
    if (dir == null) return null;
    // Absolute paths from an older build are honoured rather than rejected:
    // there should not be any, but failing to show a photo that is sitting
    // right there would be worse than a slightly odd code path.
    final path = p.isAbsolute(reference)
        ? reference
        : p.join(dir.path, reference);
    final file = File(path);
    return await file.exists() ? file : null;
  }

  Future<Uint8List?> read(String reference) async {
    final file = await resolve(reference);
    if (file == null) return null;
    try {
      return await file.readAsBytes();
    } catch (e) {
      debugPrint('PhotoFileStore read failed for $reference: $e');
      return null;
    }
  }

  /// Delete one photo. Missing is success: the goal is for it to be gone.
  Future<void> delete(String reference) async {
    final file = await resolve(reference);
    if (file == null) return;
    try {
      await file.delete();
    } catch (e) {
      debugPrint('PhotoFileStore delete failed for $reference: $e');
    }
  }

  /// How much room the photos take, for the storage screen.
  Future<int> totalBytes() async {
    final dir = await directory();
    if (dir == null) return 0;
    var total = 0;
    try {
      await for (final entry in dir.list()) {
        if (entry is File) total += await entry.length();
      }
    } catch (e) {
      debugPrint('PhotoFileStore sizing failed: $e');
    }
    return total;
  }

  /// Files on disk that no pin refers to any more.
  ///
  /// Deleting a pin's photo row and deleting its file are two steps, and a
  /// crash between them leaves the file behind. Worth being able to find them
  /// rather than slowly filling a phone.
  Future<List<String>> orphans(Set<String> referenced) async {
    final dir = await directory();
    if (dir == null) return const [];
    final loose = <String>[];
    try {
      await for (final entry in dir.list()) {
        if (entry is! File) continue;
        final name = p.basename(entry.path);
        if (!referenced.contains(name)) loose.add(name);
      }
    } catch (e) {
      debugPrint('PhotoFileStore orphan scan failed: $e');
    }
    return loose;
  }

  // ── Helpers shared with the migration and the widgets ─────────────────────

  static bool isDataUri(String reference) => reference.startsWith('data:');

  /// The bytes inside a `data:` URI, or null if it is malformed.
  ///
  /// Shared so the migration and the image widget agree on what counts as
  /// readable: a photo the migration skips must be a photo the viewer also
  /// refuses, or one of them is lying.
  static Uint8List? decodeDataUri(String reference) {
    if (!isDataUri(reference)) return null;
    final comma = reference.indexOf(',');
    if (comma <= 0 || comma >= reference.length - 1) return null;
    try {
      return base64Decode(reference.substring(comma + 1));
    } catch (_) {
      return null;
    }
  }

  static String _id() {
    final now = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final rand = math.Random().nextInt(1 << 32).toRadixString(36);
    return '${now}_$rand';
  }
}
