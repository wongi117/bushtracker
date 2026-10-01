// This migration runs over a handset holding the only copy of months of field
// work, so these tests are mostly about what happens when it goes wrong: a
// photo that will not decode, a write that fails, a second run, a rollback.
// Nothing here is allowed to lose a photo.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bush_track/core/models/photo_paths_codec.dart';
import 'package:bush_track/core/services/db_migrations.dart';
import 'package:bush_track/core/services/photo_file_store.dart';
import 'package:bush_track/core/services/photo_migration.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late Database db;
  late Directory temp;
  late PhotoFileStore store;

  /// Real bytes, so a decode either works or does not.
  Uint8List bytesOf(int n) =>
      Uint8List.fromList(List.generate(n, (i) => (i * 31) % 256));

  String dataUri(int n) => 'data:image/jpeg;base64,${base64Encode(bytesOf(n))}';

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('pin_photos_test');
    store = PhotoFileStore(baseDirectory: temp);

    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    addTearDown(db.close);
    addTearDown(() => temp.delete(recursive: true));

    await db.execute('''
      CREATE TABLE waypoints(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        label TEXT, photo_paths TEXT, updated_at INTEGER
      )''');
    await DbMigrations.upgrade(db, from: 2, to: 3); // the backup table
  });

  Future<int> addPin(String label, List<String> photos) => db.insert(
        'waypoints',
        {'label': label, 'photo_paths': PhotoPathsCodec.encode(photos)},
      );

  Future<List<String>> photosOf(int id) async {
    final row = (await db.query('waypoints', where: 'id = ?', whereArgs: [id]))
        .single;
    return PhotoPathsCodec.decode(row['photo_paths']) ?? const [];
  }

  PhotoMigration migration() => PhotoMigration(db: db, store: store);

  group('the dry run', () {
    test('counts what would move and weighs it, and writes nothing', () async {
      await addPin('one', [dataUri(400)]);
      await addPin('two', [dataUri(400), dataUri(600)]);

      final report = await migration().dryRun();

      expect(report.dryRun, isTrue);
      expect(report.pinsWithPhotos, 2);
      expect(report.photosToMove, 3);
      expect(report.bytesToMove, 1400);
      expect(report.photosMoved, 0);

      // Nothing on disk, nothing changed in the database.
      expect(await temp.list().isEmpty, isTrue);
      expect((await photosOf(1)).single, startsWith('data:'));
    });

    test('says plainly when there is nothing to do', () async {
      final report = await migration().dryRun();
      expect(report.nothingToDo, isTrue);
      expect(report.pinsWithPhotos, 0);
    });

    test('ignores pins with no photos', () async {
      await db.insert('waypoints', {'label': 'bare'});
      await db.insert('waypoints', {'label': 'empty', 'photo_paths': ''});
      final report = await migration().dryRun();
      expect(report.pinsWithPhotos, 0);
    });

    test('reports a size a person can read', () async {
      await addPin('big', [dataUri(2 * 1024 * 1024)]);
      final report = await migration().dryRun();
      expect(report.humanBytes, contains('MB'));
    });
  });

  group('migrating', () {
    test('photos end up on disk and the column holds file names', () async {
      final id = await addPin('one', [dataUri(500)]);

      final report = await migration().migrate();
      expect(report.photosMoved, 1);
      expect(report.pinsMigrated, 1);
      expect(report.failures, isEmpty);

      final after = await photosOf(id);
      expect(after.single, isNot(startsWith('data:')));

      // And the file is really there, with the right bytes.
      final read = await store.read(after.single);
      expect(read, isNotNull);
      expect(read!.length, 500);
      expect(read, bytesOf(500));
    });

    test('several photos on one pin keep their order', () async {
      final id = await addPin('many', [dataUri(100), dataUri(200), dataUri(300)]);
      await migration().migrate();

      final after = await photosOf(id);
      expect(after, hasLength(3));
      expect((await store.read(after[0]))!.length, 100);
      expect((await store.read(after[1]))!.length, 200);
      expect((await store.read(after[2]))!.length, 300);
    });

    test('each photo gets its own file', () async {
      await addPin('a', [dataUri(100), dataUri(100)]);
      await migration().migrate();
      final files = await temp
          .list(recursive: true)
          .where((e) => e is File)
          .length;
      expect(files, 2, reason: 'identical photos must not share a file');
    });

    test('updated_at is bumped, so a sync sees the change', () async {
      final id = await addPin('one', [dataUri(100)]);
      await migration().migrate();
      final row = (await db.query('waypoints', where: 'id = ?', whereArgs: [id]))
          .single;
      expect(row['updated_at'], isNotNull);
    });
  });

  group('photos that cannot be read are kept, not discarded', () {
    test('a shredded data URI is left exactly as it was', () async {
      // The leftovers of the old comma-joined column look like this.
      final id = await addPin('broken', ['data:image/jpeg;base64']);

      final report = await migration().migrate();
      expect(report.photosUnreadable, 1);
      expect(report.photosMoved, 0);

      // Still there. Unreadable is still evidence of what was photographed,
      // and throwing it away is not this code's decision.
      expect((await photosOf(id)).single, 'data:image/jpeg;base64');
    });

    test('a readable photo on the same pin still moves', () async {
      final id = await addPin('mixed', ['data:image/jpeg;base64', dataUri(300)]);

      final report = await migration().migrate();
      expect(report.photosMoved, 1);
      expect(report.photosUnreadable, 1);

      final after = await photosOf(id);
      expect(after[0], 'data:image/jpeg;base64', reason: 'kept');
      expect(after[1], isNot(startsWith('data:')), reason: 'moved');
    });

    test('rubbish base64 does not throw', () async {
      final id = await addPin('junk', ['data:image/jpeg;base64,!!!not base64!!!']);
      final report = await migration().migrate();
      expect(report.photosUnreadable, 1);
      expect((await photosOf(id)).single, startsWith('data:'));
    });
  });

  group('running it again', () {
    test('does not move an already-migrated photo twice', () async {
      await addPin('one', [dataUri(400)]);
      await migration().migrate();

      final second = await migration().migrate();
      expect(second.photosMoved, 0);
      expect(second.photosAlreadyFiles, 1);
    });

    test('and does not duplicate the files', () async {
      await addPin('one', [dataUri(400)]);
      await migration().migrate();
      await migration().migrate();

      final files =
          await temp.list(recursive: true).where((e) => e is File).length;
      expect(files, 1);
    });

    test('a pin added after the migration is handled next time', () async {
      await addPin('first', [dataUri(100)]);
      await migration().migrate();

      await addPin('later', [dataUri(200)]);
      final report = await migration().migrate();
      expect(report.photosMoved, 1);
      expect(report.photosAlreadyFiles, 1);
    });
  });

  group('rollback', () {
    test('puts the base64 back exactly as it was', () async {
      final original = dataUri(500);
      final id = await addPin('one', [original]);

      await migration().migrate();
      expect((await photosOf(id)).single, isNot(startsWith('data:')));

      final restored = await migration().rollback();
      expect(restored, 1);
      expect((await photosOf(id)).single, original);
    });

    test('restores every migrated pin', () async {
      await addPin('a', [dataUri(100)]);
      await addPin('b', [dataUri(200)]);
      await addPin('c', [dataUri(300)]);

      await migration().migrate();
      expect(await migration().rollback(), 3);

      for (var id = 1; id <= 3; id++) {
        expect((await photosOf(id)).single, startsWith('data:'));
      }
    });

    test('leaves the files on disk, so the rollback is itself undoable',
        () async {
      await addPin('one', [dataUri(400)]);
      await migration().migrate();
      await migration().rollback();

      final files =
          await temp.list(recursive: true).where((e) => e is File).length;
      expect(files, 1,
          reason: 'deleting them would make the rollback irreversible');
    });

    test('does nothing when there is nothing to roll back', () async {
      expect(await migration().rollback(), 0);
    });

    test('a pin left as base64 is not touched by a rollback', () async {
      final id = await addPin('broken', ['data:image/jpeg;base64']);
      await migration().migrate();
      await migration().rollback();
      expect((await photosOf(id)).single, 'data:image/jpeg;base64');
    });
  });

  group('orphan files', () {
    test('a file no pin refers to is findable', () async {
      final id = await addPin('one', [dataUri(200)]);
      await migration().migrate();

      // The pin loses its photo, as a delete would do.
      await db.update('waypoints', {'photo_paths': null},
          where: 'id = ?', whereArgs: [id]);

      final referenced = await migration().referencedFiles();
      final loose = await store.orphans(referenced);
      expect(loose, hasLength(1));
    });

    test('a file still in use is not an orphan', () async {
      await addPin('one', [dataUri(200)]);
      await migration().migrate();

      final referenced = await migration().referencedFiles();
      expect(await store.orphans(referenced), isEmpty);
    });
  });

  group('the file store', () {
    test('stores relative names, not absolute paths', () async {
      final name = await store.write(bytesOf(50));
      expect(name, isNot(contains(Platform.pathSeparator)),
          reason: 'an absolute path breaks when the app directory moves');
    });

    test('a missing file reads as null rather than throwing', () async {
      expect(await store.read('nothing-here.jpg'), isNull);
    });

    test('deleting something already gone is not an error', () async {
      await store.delete('nothing-here.jpg');
    });

    test('total size adds up', () async {
      await store.write(bytesOf(100));
      await store.write(bytesOf(250));
      expect(await store.totalBytes(), 350);
    });

    test('a data URI is not a file reference', () async {
      expect(await store.resolve(dataUri(10)), isNull);
      expect(PhotoFileStore.isDataUri(dataUri(10)), isTrue);
      expect(PhotoFileStore.isDataUri('abc.jpg'), isFalse);
    });

    test('decoding a data URI gives back the original bytes', () {
      expect(PhotoFileStore.decodeDataUri(dataUri(300)), bytesOf(300));
    });

    test('and refuses the broken forms', () {
      expect(PhotoFileStore.decodeDataUri('data:image/jpeg;base64'), isNull);
      expect(PhotoFileStore.decodeDataUri('data:image/jpeg;base64,'), isNull);
      expect(PhotoFileStore.decodeDataUri('not a uri'), isNull);
    });
  });
}
