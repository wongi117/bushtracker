// Projects gain colour, archiving, and an ordering. The decision worth testing
// is the one that is not obvious: "Unsorted" is a view over `file_id IS NULL`,
// not a row in the table.
import 'package:bush_track/core/models/field_file.dart';
import 'package:bush_track/core/services/db_migrations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  FieldFile project({
    int? id = 1,
    String name = 'Kookynie',
    String? colour,
    DateTime? archivedAt,
    int sortOrder = 0,
  }) =>
      FieldFile(
        id: id,
        name: name,
        description: 'survey',
        createdAt: DateTime.utc(2026, 10, 1),
        updatedAt: DateTime.utc(2026, 10, 2),
        colour: colour,
        archivedAt: archivedAt,
        sortOrder: sortOrder,
      );

  group('Unsorted is not a row', () {
    test('it has a reserved id that cannot collide with a real one', () {
      // Autoincrement ids start at 1, so a negative id can never be a project
      // somebody made.
      expect(FieldFile.unsortedId, lessThan(0));
    });

    test('and it knows itself', () {
      expect(FieldFile.unsorted().isUnsorted, isTrue);
      expect(project().isUnsorted, isFalse);
    });

    test('it sorts last, because it is where things end up', () {
      expect(FieldFile.unsorted().sortOrder,
          greaterThan(project(sortOrder: 999).sortOrder));
    });

    test('nothing is rewritten to point at it', () async {
      // The reason it is a view: there are already hundreds of unfiled items on
      // a field phone. Rewriting every one to point at a new project would be a
      // large write over data that is fine as it is, with a chance of losing
      // something, and a project that could then be deleted out from under
      // them. The migration must leave null file_ids alone.
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      addTearDown(db.close);

      await db.execute('''
        CREATE TABLE field_files(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT, description TEXT, latitude REAL, longitude REAL,
          created_at INTEGER, updated_at INTEGER
        )''');
      await db.execute(
          'CREATE TABLE waypoints(id INTEGER PRIMARY KEY, file_id INTEGER)');
      await db.insert('waypoints', {'id': 1, 'file_id': null});
      await db.insert('waypoints', {'id': 2, 'file_id': null});

      await DbMigrations.upgrade(db, from: 4, to: 5);

      final unfiled = await db
          .query('waypoints', where: 'file_id IS NULL');
      expect(unfiled, hasLength(2), reason: 'they should be untouched');

      // And no Unsorted row was invented.
      expect(await db.query('field_files'), isEmpty);
    });
  });

  group('archiving', () {
    test('a live project is not archived', () {
      expect(project().isArchived, isFalse);
    });

    test('an archived one says when', () {
      final at = DateTime.utc(2026, 9, 1);
      expect(project(archivedAt: at).isArchived, isTrue);
      expect(project(archivedAt: at).archivedAt, at);
    });

    test('un-archiving needs saying out loud', () {
      // A null archivedAt in copyWith means "leave it alone", so restoring
      // needs its own flag — the same reasoning as clearFile on a waypoint.
      final archived = project(archivedAt: DateTime.utc(2026, 9, 1));
      expect(archived.copyWith(archivedAt: null).isArchived, isTrue);
      expect(archived.copyWith(clearArchived: true).isArchived, isFalse);
    });

    test('archiving keeps everything else about the project', () {
      final before = project(colour: '#FF2D55', sortOrder: 7);
      final after = before.copyWith(archivedAt: DateTime.utc(2026, 9, 1));
      expect(after.name, before.name);
      expect(after.colour, before.colour);
      expect(after.sortOrder, before.sortOrder);
      expect(after.description, before.description);
    });
  });

  group('storage', () {
    test('colour, archive and order survive a round trip', () {
      final before = project(
          colour: '#AB47BC',
          archivedAt: DateTime.utc(2026, 9, 1),
          sortOrder: 3);
      final after = FieldFile.fromMap(before.toMap());

      expect(after.colour, '#AB47BC');
      // Compared as instants, not as DateTime objects. These store as epoch
      // milliseconds and come back from fromMillisecondsSinceEpoch as LOCAL
      // time — the same moment, a different representation. Local is the right
      // choice for display: a timestamp on a pin should read in the time the
      // person was standing there.
      expect(after.archivedAt!.isAtSameMomentAs(before.archivedAt!), isTrue);
      expect(after.sortOrder, 3);
      expect(after.name, before.name);
    });

    test('a project written before these columns existed still loads', () {
      // A row from schema 4: no colour, no archived_at, no sort_order.
      final old = {
        'id': 2,
        'name': 'Old job',
        'description': null,
        'latitude': null,
        'longitude': null,
        'created_at': DateTime.utc(2026, 1, 1).millisecondsSinceEpoch,
        'updated_at': DateTime.utc(2026, 1, 1).millisecondsSinceEpoch,
      };
      final loaded = FieldFile.fromMap(old);

      expect(loaded.name, 'Old job');
      expect(loaded.colour, isNull, reason: 'default colour, not a crash');
      expect(loaded.isArchived, isFalse);
      expect(loaded.sortOrder, 0);
    });

    test('the migration backfills an order from creation time', () async {
      // So a list that was ordered by age stays in the order the user knows.
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      addTearDown(db.close);
      await db.execute('''
        CREATE TABLE field_files(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT, description TEXT, latitude REAL, longitude REAL,
          created_at INTEGER, updated_at INTEGER
        )''');
      await db.insert('field_files', {'name': 'older', 'created_at': 1000});
      await db.insert('field_files', {'name': 'newer', 'created_at': 5000});

      await DbMigrations.upgrade(db, from: 4, to: 5);

      final rows =
          await db.query('field_files', orderBy: 'sort_order ASC');
      expect(rows.map((r) => r['name']), ['older', 'newer']);
      expect(rows.first['sort_order'], 1000);
    });

    test('and is safe to run twice', () async {
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      addTearDown(db.close);
      await db.execute('''
        CREATE TABLE field_files(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT, created_at INTEGER
        )''');
      await db.insert('field_files', {'name': 'one', 'created_at': 1000});

      await DbMigrations.upgrade(db, from: 4, to: 5);
      await db.update('field_files', {'sort_order': 42});
      await DbMigrations.upgrade(db, from: 4, to: 5);

      final row = (await db.query('field_files')).single;
      expect(row['sort_order'], 42,
          reason: 'a second run must not reset an order the user set');
    });
  });
}
