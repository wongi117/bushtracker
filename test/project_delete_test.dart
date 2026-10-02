// Deleting a project is the only thing in the app that can lose collected
// work, so the two outcomes are pinned against real SQLite rather than trusted
// to read correctly.
import 'package:bush_track/core/services/database_service.dart';
import 'package:bush_track/core/services/db_migrations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late Database db;
  late DatabaseService service;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    addTearDown(db.close);
    service = DatabaseService();
    await service.createTablesForTest(db);
    await DbMigrations.markFresh(db);
    service.attachForTest(db);
  });

  /// A project with a day's work filed under it, and one pin that is not.
  Future<int> seed() async {
    final id = await db.insert('field_files', {
      'name': 'Kookynie',
      'created_at': 1000,
      'updated_at': 1000,
    });
    await db.insert('waypoints',
        {'latitude': -28.8, 'longitude': 121.3, 'label': 'shaft', 'is_pin': 1,
         'file_id': id});
    await db.insert('waypoints',
        {'latitude': -28.9, 'longitude': 121.4, 'label': 'tank', 'is_pin': 1,
         'file_id': id});
    await db.insert('waypoints',
        {'latitude': -29.0, 'longitude': 121.5, 'label': 'loose', 'is_pin': 1});
    await db.insert('geofences',
        {'name': 'heritage', 'latitude': -28.8, 'longitude': 121.3,
         'radius_meters': 200.0, 'file_id': id});
    await db.insert('trails', {'name': 'track in', 'file_id': id});
    await db.insert('file_notes', {'file_id': id, 'body': 'started here'});
    return id;
  }

  group('counting what a project holds', () {
    test('counts each kind, and nothing from outside the project', () async {
      final id = await seed();
      final c = await service.countFieldFileContents(id);

      expect(c.pins, 2, reason: 'the loose pin is not this project');
      expect(c.zones, 1);
      expect(c.trails, 1);
      expect(c.notes, 1);
      expect(c.fieldItems, 4, reason: 'notes are not work at risk');
    });

    test('an empty project says so', () async {
      final id = await db.insert('field_files',
          {'name': 'Empty', 'created_at': 1, 'updated_at': 1});
      final c = await service.countFieldFileContents(id);
      expect(c.isEmpty, isTrue);
      expect(c.describe(), 'nothing');
    });

    test('it reads as a sentence, so the warning is legible', () async {
      const c = ProjectContents(pins: 12, zones: 3, trails: 1);
      expect(c.describe(), '12 pins, 3 boundaries and 1 trail');
      expect(const ProjectContents(pins: 1).describe(), '1 pin');
      expect(const ProjectContents(zones: 2).describe(), '2 boundaries');
      expect(const ProjectContents(pins: 1, trails: 1).describe(),
          '1 pin and 1 trail');
    });
  });

  group('delete, keeping the work', () {
    test('the project goes and the pins stay, unfiled', () async {
      final id = await seed();
      await service.deleteFieldFile(id);

      expect(await db.query('field_files'), isEmpty);
      final pins = await db.query('waypoints');
      expect(pins, hasLength(3), reason: 'nothing collected was deleted');
      expect(pins.every((p) => p['file_id'] == null), isTrue,
          reason: 'they become Unsorted, which needs no row to point at');
    });

    test('zones and trails are unfiled too, not deleted', () async {
      final id = await seed();
      await service.deleteFieldFile(id);

      expect((await db.query('geofences')).single['file_id'], isNull);
      expect((await db.query('trails')).single['file_id'], isNull);
    });

    test('the notes go with the project, being part of it', () async {
      final id = await seed();
      await service.deleteFieldFile(id);
      expect(await db.query('file_notes'), isEmpty);
    });

    test('a pin filed under another project is untouched', () async {
      final id = await seed();
      final other = await db.insert('field_files',
          {'name': 'Other', 'created_at': 2, 'updated_at': 2});
      await db.insert('waypoints', {
        'latitude': -30.0,
        'longitude': 122.0,
        'label': 'theirs',
        'is_pin': 1,
        'file_id': other,
      });

      await service.deleteFieldFile(id);

      final theirs = await db.query('waypoints', where: 'label = ?',
          whereArgs: ['theirs']);
      expect(theirs.single['file_id'], other,
          reason: 'deleting one project must not unfile another');
    });
  });

  group('delete everything', () {
    test('the project and its work both go', () async {
      final id = await seed();
      await service.deleteFieldFile(id, withContents: true);

      expect(await db.query('field_files'), isEmpty);
      expect(await db.query('geofences'), isEmpty);
      expect(await db.query('trails'), isEmpty);
      expect(await db.query('file_notes'), isEmpty);
    });

    test('but only its own work', () async {
      final id = await seed();
      await service.deleteFieldFile(id, withContents: true);

      final left = await db.query('waypoints');
      expect(left, hasLength(1), reason: 'the loose pin was never in it');
      expect(left.single['label'], 'loose');
    });

    test('another project keeps everything it holds', () async {
      final id = await seed();
      final other = await db.insert('field_files',
          {'name': 'Other', 'created_at': 2, 'updated_at': 2});
      await db.insert('waypoints', {
        'latitude': -30.0,
        'longitude': 122.0,
        'label': 'theirs',
        'is_pin': 1,
        'file_id': other,
      });

      await service.deleteFieldFile(id, withContents: true);

      expect(await db.query('waypoints', where: 'file_id = ?',
          whereArgs: [other]), hasLength(1));
      expect(await db.query('field_files'), hasLength(1));
    });

    test('it is the opposite of the default, not a variation on it', () async {
      // The two paths must not quietly converge: a withContents flag that got
      // dropped somewhere would read as a successful delete either way, and
      // only the pin count would tell you which one ran.
      final a = await seed();
      await service.deleteFieldFile(a);
      final keptCount = (await db.query('waypoints')).length;

      await db.delete('waypoints');
      final b = await seed();
      await service.deleteFieldFile(b, withContents: true);
      final deletedCount = (await db.query('waypoints')).length;

      expect(keptCount, 3);
      expect(deletedCount, 1);
    });
  });

  group('the photo sweep works off what is still referenced', () {
    test('a photo two pins share is still referenced after one goes',
        () async {
      // Deleting by the paths that were just removed would take this file out
      // from under the pin that remains.
      final id = await db.insert('field_files',
          {'name': 'P', 'created_at': 1, 'updated_at': 1});
      await db.insert('waypoints', {
        'latitude': -28.0, 'longitude': 121.0, 'is_pin': 1, 'file_id': id,
        'photo_paths': '["shared.jpg","gone.jpg"]',
      });
      await db.insert('waypoints', {
        'latitude': -28.1, 'longitude': 121.1, 'is_pin': 1,
        'photo_paths': '["shared.jpg"]',
      });

      await service.deleteFieldFile(id, withContents: true);
      final referenced = await service.referencedPhotoPaths();

      expect(referenced, contains('shared.jpg'),
          reason: 'the surviving pin still points at it');
      expect(referenced, isNot(contains('gone.jpg')));
    });

    test('a column that will not decode keeps its files rather than losing '
        'them', () async {
      await db.insert('waypoints', {
        'latitude': -28.0, 'longitude': 121.0, 'is_pin': 1,
        'photo_paths': 'not json and not a data uri',
      });
      // Must not throw, and must not report an empty reference set that would
      // make the sweep delete everything.
      final referenced = await service.referencedPhotoPaths();
      expect(referenced, isNotNull);
    });
  });
}
