import 'package:flutter/foundation.dart';
import 'package:sqflite_common/sqlite_api.dart';

import 'package:bush_track/core/models/photo_paths_codec.dart';
import 'package:bush_track/core/services/photo_file_store.dart';
import 'package:bush_track/core/services/oversize_rows.dart';

/// What a migration run did, or would do.
@immutable
class PhotoMigrationReport {
  const PhotoMigrationReport({
    this.pinsWithPhotos = 0,
    this.photosToMove = 0,
    this.photosAlreadyFiles = 0,
    this.photosUnreadable = 0,
    this.bytesToMove = 0,
    this.pinsMigrated = 0,
    this.photosMoved = 0,
    this.failures = const [],
    this.dryRun = true,
  });

  final int pinsWithPhotos;

  /// Base64 photos that would move to disk.
  final int photosToMove;

  /// Already a file path — a second run, or a photo added after the migration.
  final int photosAlreadyFiles;

  /// Claims to be a data URI but will not decode. **Left exactly as it is.**
  /// Something unreadable is still evidence of what was there, and throwing it
  /// away during a migration is not this code's decision to make.
  final int photosUnreadable;

  final int bytesToMove;
  final int pinsMigrated;
  final int photosMoved;

  /// Pin ids that failed, with the reason.
  final List<String> failures;

  final bool dryRun;

  bool get nothingToDo => photosToMove == 0;

  String get humanBytes {
    if (bytesToMove < 1024) return '$bytesToMove B';
    if (bytesToMove < 1024 * 1024) {
      return '${(bytesToMove / 1024).toStringAsFixed(0)} KB';
    }
    return '${(bytesToMove / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  String toString() => dryRun
      ? 'DRY RUN: $pinsWithPhotos pins, $photosToMove photos to move '
          '($humanBytes), $photosAlreadyFiles already files, '
          '$photosUnreadable unreadable'
      : 'MIGRATED: $pinsMigrated pins, $photosMoved photos moved, '
          '${failures.length} failed';
}

/// Moving pin photos out of the database and onto disk.
///
/// Written to be run in anger on a handset holding the only copy of months of
/// field work, so the order of operations is the whole design:
///
///  1. **Dry run first.** Count what would move and how much it weighs, touch
///     nothing. Numbers get reported before anything is written.
///  2. **Back up the column before changing it.** The original `photo_paths`
///     text goes into `photo_migration_backup` first. Until that row exists,
///     the pin is not touched.
///  3. **Write the file, read it back, and only then rewrite the column.** A
///     file that cannot be read straight after writing is a failure, and the
///     pin keeps its base64.
///  4. **Per pin, not per batch.** One bad photo costs one pin, not the run.
///  5. **Rollback restores from the backup**, and leaves the files alone — they
///     are harmless, and deleting them is a separate, reversible decision.
///
/// The base64 is never deleted as a side effect of anything. It is replaced
/// only once its file is on disk and readable, and the backup means even that
/// is undoable.
class PhotoMigration {
  PhotoMigration({required this.db, PhotoFileStore? store})
      : store = store ?? PhotoFileStore();

  final DatabaseExecutor db;
  final PhotoFileStore store;

  static const String backupTable = 'photo_migration_backup';

  /// Count what would happen. Writes nothing.
  Future<PhotoMigrationReport> dryRun() => _run(write: false);

  /// Do it.
  Future<PhotoMigrationReport> migrate() => _run(write: true);

  Future<PhotoMigrationReport> _run({required bool write}) async {
    // Read through OversizeRows. A plain query here threw on the one row this
    // migration most needed to shrink -- a pin past Android's 2 MB row window
    // -- so the step failed on every launch and the row could never be fixed.
    final rows = await OversizeRows.query(
      db,
      'waypoints',
      columns: const ['id', 'photo_paths'],
      bigColumns: const ['photo_paths'],
      where: "photo_paths IS NOT NULL AND photo_paths != ''",
    );

    var pinsWithPhotos = 0;
    var toMove = 0;
    var alreadyFiles = 0;
    var unreadable = 0;
    var bytes = 0;
    var pinsMigrated = 0;
    var photosMoved = 0;
    final failures = <String>[];

    for (final row in rows) {
      final id = row['id'] as int?;
      if (id == null) continue;

      final photos = PhotoPathsCodec.decode(row['photo_paths']);
      if (photos == null || photos.isEmpty) continue;
      pinsWithPhotos++;

      final rewritten = <String>[];
      var changedThisPin = false;
      var failedThisPin = false;

      for (final reference in photos) {
        if (!PhotoFileStore.isDataUri(reference)) {
          alreadyFiles++;
          rewritten.add(reference);
          continue;
        }

        final decoded = PhotoFileStore.decodeDataUri(reference);
        if (decoded == null) {
          // Kept, not discarded. See the class comment.
          unreadable++;
          rewritten.add(reference);
          continue;
        }

        toMove++;
        bytes += decoded.length;

        if (!write) {
          rewritten.add(reference);
          continue;
        }

        try {
          final name = await store.write(decoded);
          // Read it back before trusting it. A write that reports success and
          // produces nothing readable is exactly the case that would lose a
          // photo.
          final verify = await store.read(name);
          if (verify == null || verify.length != decoded.length) {
            failures.add('pin $id: wrote $name but could not read it back');
            failedThisPin = true;
            rewritten.add(reference);
            continue;
          }
          rewritten.add(name);
          changedThisPin = true;
          photosMoved++;
        } catch (e) {
          failures.add('pin $id: $e');
          failedThisPin = true;
          rewritten.add(reference);
        }
      }

      if (!write || !changedThisPin) continue;

      try {
        // The backup goes in before the column is touched, so there is never a
        // moment where the base64 exists in neither place.
        await _backup(id, row['photo_paths']?.toString());
        await db.update(
          'waypoints',
          {
            'photo_paths': PhotoPathsCodec.encode(rewritten),
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          },
          where: 'id = ?',
          whereArgs: [id],
        );
        pinsMigrated++;
      } catch (e) {
        failures.add('pin $id: backup or update failed, left as base64: $e');
      }

      if (failedThisPin) {
        debugPrint('Photo migration: pin $id partly moved, base64 kept for '
            'the photos that failed');
      }
    }

    final report = PhotoMigrationReport(
      pinsWithPhotos: pinsWithPhotos,
      photosToMove: toMove,
      photosAlreadyFiles: alreadyFiles,
      photosUnreadable: unreadable,
      bytesToMove: bytes,
      pinsMigrated: pinsMigrated,
      photosMoved: photosMoved,
      failures: failures,
      dryRun: !write,
    );
    debugPrint('📷 $report');
    return report;
  }

  /// Put every migrated pin back the way it was.
  ///
  /// Restores the column from the backup and leaves the files on disk. They
  /// cost space and nothing else, and deleting them would make the rollback
  /// itself irreversible — which is the one thing a rollback must not be.
  /// [PhotoFileStore.orphans] finds them later, once someone has decided.
  Future<int> rollback() async {
    if (!await _backupExists()) return 0;

    // The backup holds the original, oversized text; same window, same read.
    final saved = await OversizeRows.query(db, backupTable,
        bigColumns: const ['photo_paths'], idColumn: 'waypoint_id');
    var restored = 0;
    for (final row in saved) {
      final id = row['waypoint_id'] as int?;
      final original = row['photo_paths']?.toString();
      if (id == null || original == null) continue;
      try {
        await db.update(
          'waypoints',
          {'photo_paths': original},
          where: 'id = ?',
          whereArgs: [id],
        );
        restored++;
      } catch (e) {
        debugPrint('Photo rollback failed for pin $id: $e');
      }
    }
    debugPrint('📷 Rolled back $restored pins');
    return restored;
  }

  /// Every file name the database still refers to, for an orphan scan.
  Future<Set<String>> referencedFiles() async {
    final rows = await OversizeRows.query(db, 'waypoints',
        columns: const ['photo_paths'], bigColumns: const ['photo_paths']);
    final names = <String>{};
    for (final row in rows) {
      final photos = PhotoPathsCodec.decode(row['photo_paths']);
      if (photos == null) continue;
      for (final reference in photos) {
        if (!PhotoFileStore.isDataUri(reference)) names.add(reference);
      }
    }
    return names;
  }

  Future<void> _backup(int waypointId, String? original) async {
    if (original == null) return;
    await db.insert(
      backupTable,
      {
        'waypoint_id': waypointId,
        'photo_paths': original,
        'backed_up_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<bool> _backupExists() async {
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [backupTable],
    );
    return rows.isNotEmpty;
  }
}
