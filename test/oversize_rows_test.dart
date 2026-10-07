// On the test phone one pin's photos grew past Android's 2 MB row window, and
// from then on "SELECT * FROM waypoints" threw -- no pin loaded at all -- and
// the photo migration, the one thing that could shrink that row, threw on its
// first query every launch.
//
// Desktop SQLite has no such window, so the throw cannot be reproduced here.
// What can be: that reading in slices hands back exactly what a plain query
// would, which these drive with a tiny limit so every value takes the slow
// path.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bush_track/core/models/photo_paths_codec.dart';
import 'package:bush_track/core/services/db_migrations.dart';
import 'package:bush_track/core/services/oversize_rows.dart';
import 'package:bush_track/core/services/photo_file_store.dart';
import 'package:bush_track/core/services/photo_migration.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late Database db;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    addTearDown(db.close);
    await db.execute('''
      CREATE TABLE waypoints(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        label TEXT, timestamp INTEGER,
        photo_paths TEXT, thumbnail_path TEXT, updated_at INTEGER
      )''');
  });

  String text(int n) => List.generate(n, (i) => 'abcdefghij'[i % 10]).join();

  group('a guarded query returns what a plain one would', () {
    // 7 is the limit: lengths below, at, one past, and several times over it.
    const limit = 7;
    final lengths = [0, 3, 7, 8, 14, 15, 100];

    setUp(() async {
      for (var i = 0; i < lengths.length; i++) {
        await db.insert('waypoints', {
          'label': 'pin $i',
          'timestamp': i,
          'photo_paths': text(lengths[i]),
          'thumbnail_path': text(lengths[lengths.length - 1 - i]),
        });
      }
      await db.insert('waypoints', {'label': 'no photos', 'timestamp': 99});
    });

    test('every row, every column, byte for byte', () async {
      final plain = await db.query('waypoints', orderBy: 'timestamp DESC');
      final guarded = await OversizeRows.query(db, 'waypoints',
          bigColumns: const ['photo_paths', 'thumbnail_path'],
          orderBy: 'timestamp DESC',
          limit: limit);
      expect(guarded, plain);
    });

    test('only the columns asked for, with no id smuggled in', () async {
      final guarded = await OversizeRows.query(db, 'waypoints',
          columns: const ['photo_paths'],
          bigColumns: const ['photo_paths'],
          limit: limit);
      expect(guarded.first.keys, ['photo_paths']);
      expect(guarded.map((r) => r['photo_paths']),
          (await db.query('waypoints', columns: ['photo_paths']))
              .map((r) => r['photo_paths']));
    });

    test('a where clause still applies', () async {
      final guarded = await OversizeRows.query(db, 'waypoints',
          bigColumns: const ['photo_paths'],
          where: 'timestamp = ?',
          whereArgs: [6],
          limit: limit);
      expect(guarded.single['photo_paths'], text(100));
    });

    test('a NULL stays NULL rather than becoming empty', () async {
      final guarded = await OversizeRows.query(db, 'waypoints',
          bigColumns: const ['photo_paths'], where: 'timestamp = 99', limit: limit);
      expect(guarded.single['photo_paths'], isNull);
    });
  });

  test('a table keyed on something other than id', () async {
    // The photo backup is keyed on waypoint_id, and holds the original,
    // oversized text -- so rollback needs the same read.
    await DbMigrations.upgrade(db, from: 2, to: 3);
    await db.insert(PhotoMigration.backupTable,
        {'waypoint_id': 42, 'photo_paths': text(50), 'backed_up_at': 1});
    final rows = await OversizeRows.query(db, PhotoMigration.backupTable,
        bigColumns: const ['photo_paths'], idColumn: 'waypoint_id', limit: 7);
    expect(rows.single['photo_paths'], text(50));
    expect(rows.single['waypoint_id'], 42);
  });

  test('the migration moves the photos out of a row over the limit', () async {
    // Two photos of 150 KB: a row of about 400,000 characters, past the
    // default limit, so this goes through the sliced read for real.
    await DbMigrations.upgrade(db, from: 2, to: 3);
    final temp = await Directory.systemTemp.createTemp('oversize_migration');
    addTearDown(() => temp.delete(recursive: true));
    final store = PhotoFileStore(baseDirectory: temp);

    Uint8List bytes(int seed) =>
        Uint8List.fromList(List.generate(150 * 1024, (i) => (i * seed) % 256));
    final photos = [
      for (final seed in [7, 13])
        'data:image/jpeg;base64,${base64Encode(bytes(seed))}',
    ];
    final id = await db.insert('waypoints',
        {'label': 'heaps of photos', 'photo_paths': PhotoPathsCodec.encode(photos)});
    final stored = (await db.rawQuery(
            'SELECT length(photo_paths) AS n FROM waypoints WHERE id = ?', [id]))
        .first['n'] as int;
    expect(stored, greaterThan(OversizeRows.defaultLimit));

    final report = await PhotoMigration(db: db, store: store).migrate();

    expect(report.photosMoved, 2);
    expect(report.failures, isEmpty);
    final after = PhotoPathsCodec.decode(
        (await db.query('waypoints', where: 'id = ?', whereArgs: [id]))
            .single['photo_paths'])!;
    expect(after.every((r) => !PhotoFileStore.isDataUri(r)), isTrue);
    expect(await store.read(after[0]), bytes(7));
    expect(await store.read(after[1]), bytes(13));
  });
}
