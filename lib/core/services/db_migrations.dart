import 'package:flutter/foundation.dart';
import 'package:sqflite_common/sqlite_api.dart';

/// One step from one schema version to the next.
class Migration {
  const Migration({
    required this.to,
    required this.describe,
    required this.run,
  });

  /// The schema version this migration produces.
  final int to;

  /// What it does, for the log. A field phone's upgrade is invisible unless it
  /// says something, and "the app lost my pins" is the report you get when a
  /// migration failed quietly.
  final String describe;

  /// Typed against DatabaseExecutor, not Database: migrations run inside a
  /// transaction, and a Transaction is not a Database. Casting one to the
  /// other compiles and then throws at runtime, which is how the first
  /// version of this failed every test at once.
  final Future<void> Function(DatabaseExecutor db) run;
}

/// Bringing an existing database up to the current schema.
///
/// There was no upgrade path at all: the schema sat at version 1 and tables
/// were made with `CREATE TABLE IF NOT EXISTS`, which creates what is missing
/// and silently ignores a table whose columns have changed. That works exactly
/// until the first column is added — and then a phone that already has data
/// opens an old table, the insert fails against a column that is not there,
/// and the record is dropped. On a phone carrying the only copy of a day's
/// survey, that is the worst bug this app could have.
///
/// So: numbered steps, run in order, each one idempotent, inside a transaction,
/// with the version recorded by sqflite itself.
class DbMigrations {
  const DbMigrations._();

  /// The version the code expects. Bump this when adding a migration.
  static const int currentVersion = 2;

  /// Every step, in order. A gap in the numbering is a bug, and
  /// [assertWellFormed] catches it in the tests rather than on a phone.
  static List<Migration> get all => const [
        Migration(
          to: 2,
          describe: 'sync columns: uuid, updated_at, deleted_at',
          run: _v2SyncColumns,
        ),
      ];

  /// Apply everything newer than [from], up to and including [to].
  ///
  /// Each migration is its own transaction. One failing step therefore leaves
  /// the database at the last version that did succeed, rather than halfway
  /// through a change, and the next launch retries from there.
  static Future<void> upgrade(
    Database db, {
    required int from,
    required int to,
  }) async {
    for (final migration in all) {
      if (migration.to <= from || migration.to > to) continue;
      debugPrint('DB migrate ${migration.to - 1} -> ${migration.to}: '
          '${migration.describe}');
      await db.transaction(migration.run);
    }
  }

  /// Bring a brand new database up to the current schema.
  ///
  /// A fresh install runs every migration too, rather than relying on
  /// CREATE TABLE already listing the newest columns. That is deliberate: it
  /// makes "freshly created" and "upgraded from version 1" the same schema by
  /// construction instead of by remembering to edit two places. A column added
  /// to a migration but not to CREATE TABLE — or the reverse — is the classic
  /// way these drift, and then a bug reproduces on existing phones but not on
  /// a new install, which is the hardest kind to chase.
  ///
  /// Every migration is idempotent, so running them over tables that already
  /// have the columns is a no-op.
  static Future<void> markFresh(Database db) =>
      upgrade(db, from: 1, to: currentVersion);

  /// Guards the list itself. Called from the tests.
  static void assertWellFormed() {
    final versions = all.map((m) => m.to).toList();
    assert(versions.length == versions.toSet().length,
        'two migrations claim the same version');
    for (var i = 0; i < versions.length; i++) {
      assert(versions[i] == i + 2,
          'migrations must run 2, 3, 4... with no gaps; found $versions');
    }
    assert(versions.isEmpty || versions.last == currentVersion,
        'currentVersion ($currentVersion) does not match the last migration '
        '(${versions.isEmpty ? 'none' : versions.last})');
  }

  // ── Migrations ─────────────────────────────────────────────────────────────

  /// Everything that will have to sync needs a stable id, a modification time
  /// and a tombstone.
  ///
  /// An autoincrement integer is unique on one handset and collides across
  /// two, so it cannot identify a row that has been shared. `updated_at` is
  /// what decides which of two edits is newer. `deleted_at` is what lets a
  /// deletion travel: a row simply vanishing cannot be told apart from a row
  /// that never arrived.
  static Future<void> _v2SyncColumns(DatabaseExecutor db) async {
    const tables = ['waypoints', 'geofences', 'trails', 'field_files', 'file_notes'];
    for (final table in tables) {
      if (!await _hasTable(db, table)) continue;
      await addColumnIfMissing(db, table, 'uuid', 'TEXT');
      await addColumnIfMissing(db, table, 'updated_at', 'INTEGER');
      await addColumnIfMissing(db, table, 'deleted_at', 'INTEGER');

      // Backfill, so existing rows are syncable rather than being left behind
      // as a second class of record forever.
      await db.execute(
        'UPDATE $table SET uuid = '
        "lower(hex(randomblob(4))) || '-' || lower(hex(randomblob(2))) || '-4' "
        "|| substr(lower(hex(randomblob(2))),2) || '-' "
        "|| substr('89ab', abs(random()) % 4 + 1, 1) "
        "|| substr(lower(hex(randomblob(2))),2) || '-' "
        '|| lower(hex(randomblob(6))) '
        'WHERE uuid IS NULL',
      );
      await db.execute(
        'UPDATE $table SET updated_at = ? WHERE updated_at IS NULL',
        [DateTime.now().millisecondsSinceEpoch],
      );
    }

    // Unique per table, and only over rows that have one, so the backfill
    // above cannot trip over itself on a partially migrated database.
    for (final table in tables) {
      if (!await _hasTable(db, table)) continue;
      await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS '
          'idx_${table}_uuid ON $table(uuid)');
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Add a column unless it is already there.
  ///
  /// SQLite has no `ADD COLUMN IF NOT EXISTS`, and re-running a migration on a
  /// database that already has the column throws. Checking first makes every
  /// step safe to run twice, which matters because a migration interrupted by
  /// the app being killed will be run again.
  @visibleForTesting
  static Future<void> addColumnIfMissing(
    DatabaseExecutor db,
    String table,
    String column,
    String type,
  ) async {
    if (await hasColumn(db, table, column)) return;
    await db.execute('ALTER TABLE $table ADD COLUMN $column $type');
  }

  @visibleForTesting
  static Future<bool> hasColumn(
      DatabaseExecutor db, String table, String column) async {
    final rows = await db.rawQuery('PRAGMA table_info($table)');
    return rows.any((r) => r['name'] == column);
  }

  static Future<bool> _hasTable(DatabaseExecutor db, String table) async {
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [table],
    );
    return rows.isNotEmpty;
  }
}
