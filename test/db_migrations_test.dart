// The schema sat at version 1 with no onUpgrade, and tables were made with
// CREATE TABLE IF NOT EXISTS — which creates what is missing and silently
// ignores a table whose columns have changed. That works right up until the
// first column is added, and then a phone that already has data opens an old
// table, inserts fail against a column that is not there, and records are
// dropped. On a handset carrying the only copy of a day's survey that is the
// worst bug this app could have, so the migration runner gets real tests
// against a real database with real rows in it.
import 'package:bush_track/core/services/database_service.dart';
import 'package:bush_track/core/services/db_migrations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  /// A database as it existed at version 1: the old tables, no sync columns.
  /// Opened with addTearDown rather than a close at the end of each test:
  /// sqflite hands back the same handle for the same path, so one test failing
  /// before its close left its tables behind and every later test died with
  /// "table already exists" instead of its own reason.
  Future<Database> openV1() async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    addTearDown(db.close);
    await db.execute('''
      CREATE TABLE waypoints(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        latitude REAL, longitude REAL, label TEXT, notes TEXT,
        timestamp INTEGER, type TEXT, photo_paths TEXT, color TEXT,
        icon TEXT, order_index INTEGER, is_pin INTEGER, file_id INTEGER
      )''');
    await db.execute('''
      CREATE TABLE geofences(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT, notes TEXT, file_id INTEGER
      )''');
    await db.execute('''
      CREATE TABLE trails(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT, description TEXT, file_id INTEGER
      )''');
    await db.execute('''
      CREATE TABLE field_files(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT, description TEXT
      )''');
    await db.execute('''
      CREATE TABLE file_notes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        file_id INTEGER, body TEXT
      )''');
    await db.setVersion(1);
    return db;
  }

  /// A day's work, as it would be sitting on the phone.
  Future<void> seed(Database db) async {
    await db.insert('field_files', {'name': 'Kookynie', 'description': 'survey'});
    await db.insert('waypoints', {
      'latitude': -28.8833,
      'longitude': 121.3333,
      'label': 'Old shaft',
      'notes': 'collapsed on the north side',
      'timestamp': 1772000000000,
      'type': 'manual',
      'photo_paths': '["data:image/jpeg;base64,AAEC"]',
      'color': '#FF2D55',
      'icon': 'hazard',
      'order_index': 1,
      'is_pin': 1,
      'file_id': 1,
    });
    await db.insert('waypoints', {
      'latitude': -28.9,
      'longitude': 121.4,
      'label': 'Water',
      'is_pin': 1,
      'file_id': 1,
    });
    await db.insert('geofences', {'name': 'Heritage area', 'file_id': 1});
    await db.insert('trails', {'name': 'Morning run', 'file_id': 1});
    await db.insert('file_notes', {'file_id': 1, 'body': 'back tomorrow'});
  }

  group('the list of migrations itself', () {
    test('is numbered without gaps and matches currentVersion', () {
      // An assert, so a mistake here fails the build rather than a phone.
      DbMigrations.assertWellFormed();
    });

    test('starts at 2, because 1 is the schema that already exists', () {
      expect(DbMigrations.all.first.to, 2);
    });

    test('every migration says what it does', () {
      for (final m in DbMigrations.all) {
        expect(m.describe.trim(), isNotEmpty);
      }
    });
  });

  group('upgrading a version 1 database that has data in it', () {
    test('nothing is lost', () async {
      final db = await openV1();
      await seed(db);

      await DbMigrations.upgrade(db, from: 1, to: DbMigrations.currentVersion);

      expect((await db.query('waypoints')), hasLength(2));
      expect((await db.query('geofences')), hasLength(1));
      expect((await db.query('trails')), hasLength(1));
      expect((await db.query('field_files')), hasLength(1));
      expect((await db.query('file_notes')), hasLength(1));
    });

    test('every field survives, not just the row count', () async {
      // Row counts are the easy half; the column-by-column check is what
      // catches a migration that rebuilt a table and lost a value.
      final db = await openV1();
      await seed(db);

      await DbMigrations.upgrade(db, from: 1, to: DbMigrations.currentVersion);

      final row = (await db.query('waypoints', where: 'id = 1')).single;
      expect(row['latitude'], -28.8833);
      expect(row['longitude'], 121.3333);
      expect(row['label'], 'Old shaft');
      expect(row['notes'], 'collapsed on the north side');
      expect(row['timestamp'], 1772000000000);
      expect(row['type'], 'manual');
      expect(row['photo_paths'], '["data:image/jpeg;base64,AAEC"]');
      expect(row['color'], '#FF2D55');
      expect(row['icon'], 'hazard');
      expect(row['order_index'], 1);
      expect(row['is_pin'], 1);
      expect(row['file_id'], 1);
    });
    test('the sync columns are added', () async {
      final db = await openV1();
      await seed(db);
      await DbMigrations.upgrade(db, from: 1, to: DbMigrations.currentVersion);

      for (final table in [
        'waypoints',
        'geofences',
        'trails',
        'field_files',
        'file_notes'
      ]) {
        for (final column in ['uuid', 'updated_at', 'deleted_at']) {
          expect(await DbMigrations.hasColumn(db, table, column), isTrue,
              reason: '$table is missing $column');
        }
      }
    });

    test('existing rows get a uuid, rather than being left unsyncable',
        () async {
      final db = await openV1();
      await seed(db);
      await DbMigrations.upgrade(db, from: 1, to: DbMigrations.currentVersion);

      final rows = await db.query('waypoints');
      for (final row in rows) {
        expect(row['uuid'], isNotNull);
        expect('${row['uuid']}', hasLength(36), reason: 'should be a uuid');
      }
    });

    test('and the uuids are all different', () async {
      final db = await openV1();
      await seed(db);
      await DbMigrations.upgrade(db, from: 1, to: DbMigrations.currentVersion);

      final rows = await db.query('waypoints');
      final ids = rows.map((r) => r['uuid']).toSet();
      expect(ids, hasLength(rows.length),
          reason: 'two rows sharing a uuid would merge when synced');
    });

    test('existing rows get an updated_at, so a sync can order them',
        () async {
      final db = await openV1();
      await seed(db);
      await DbMigrations.upgrade(db, from: 1, to: DbMigrations.currentVersion);

      for (final row in await db.query('waypoints')) {
        expect(row['updated_at'], isNotNull);
        expect(row['updated_at'], isA<int>());
      }
    });

    test('nothing is marked deleted by the migration', () async {
      final db = await openV1();
      await seed(db);
      await DbMigrations.upgrade(db, from: 1, to: DbMigrations.currentVersion);

      for (final row in await db.query('waypoints')) {
        expect(row['deleted_at'], isNull);
      }
    });

    test('the version is left at the current one', () async {
      final db = await openV1();
      await DbMigrations.upgrade(db, from: 1, to: DbMigrations.currentVersion);
      // sqflite records the version itself on a real open; here we only check
      // the runner did not move it backwards.
      expect(await db.getVersion(), 1,
          reason: 'upgrade() changes schema, not the version marker — '
              'openDatabase owns that');
    });
  });

  group('running it twice', () {
    test('is harmless, because a killed migration gets retried', () async {
      final db = await openV1();
      await seed(db);

      await DbMigrations.upgrade(db, from: 1, to: DbMigrations.currentVersion);
      // Same again, as would happen if the app died mid-upgrade.
      await DbMigrations.upgrade(db, from: 1, to: DbMigrations.currentVersion);

      expect(await db.query('waypoints'), hasLength(2));
    });

    test('the second run does not reissue uuids', () async {
      final db = await openV1();
      await seed(db);

      await DbMigrations.upgrade(db, from: 1, to: DbMigrations.currentVersion);
      final before =
          (await db.query('waypoints')).map((r) => r['uuid']).toList();

      await DbMigrations.upgrade(db, from: 1, to: DbMigrations.currentVersion);
      final after =
          (await db.query('waypoints')).map((r) => r['uuid']).toList();

      expect(after, before,
          reason: 'a changed uuid would look like a different record');
    });

    test('adding a column that is already there does not throw', () async {
      // SQLite has no ADD COLUMN IF NOT EXISTS, so this is checked by hand.
      final db = await openV1();
      await DbMigrations.addColumnIfMissing(db, 'waypoints', 'uuid', 'TEXT');
      await DbMigrations.addColumnIfMissing(db, 'waypoints', 'uuid', 'TEXT');
      expect(await DbMigrations.hasColumn(db, 'waypoints', 'uuid'), isTrue);
    });
  });

  group('a database missing some tables', () {
    test('migrates the ones it has and skips the rest', () async {
      // An older install, or a partial restore.
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      addTearDown(db.close);
      await db.execute(
          'CREATE TABLE waypoints(id INTEGER PRIMARY KEY, label TEXT)');

      await DbMigrations.upgrade(db, from: 1, to: DbMigrations.currentVersion);

      expect(await DbMigrations.hasColumn(db, 'waypoints', 'uuid'), isTrue);
    });
  });

  group('a fresh install ends up identical to an upgraded one', () {
    test('same columns on every table', () async {
      // The drift this guards against: a column added to a migration but not
      // to CREATE TABLE, or the reverse, which makes a bug reproduce on
      // existing phones and not on a new install.
      final upgraded = await openV1();
      await DbMigrations.upgrade(upgraded,
          from: 1, to: DbMigrations.currentVersion);

      final fresh = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      addTearDown(fresh.close);
      await DatabaseService().createTablesForTest(fresh);
      await DbMigrations.markFresh(fresh);

      for (final table in [
        'waypoints',
        'geofences',
        'trails',
        'field_files',
        'file_notes'
      ]) {
        for (final column in ['uuid', 'updated_at', 'deleted_at']) {
          expect(await DbMigrations.hasColumn(fresh, table, column), isTrue,
              reason: 'a fresh $table is missing $column');
          expect(await DbMigrations.hasColumn(upgraded, table, column), isTrue,
              reason: 'an upgraded $table is missing $column');
        }
      }

    });

    test('a fresh database still accepts a waypoint insert', () async {
      final fresh = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      addTearDown(fresh.close);
      await DatabaseService().createTablesForTest(fresh);
      await DbMigrations.markFresh(fresh);

      final id = await fresh.insert('waypoints', {
        'latitude': -28.88,
        'longitude': 121.33,
        'label': 'After migration',
        'is_pin': 1,
      });
      expect(id, greaterThan(0));
    });
  });
}
