// Drawings against real SQLite, on the schema a phone actually runs:
// createTablesForTest then markFresh (CLAUDE.md -- CREATE TABLE alone is a
// schema the app never runs on).
import 'dart:convert';

import 'package:bush_track/core/models/field_file.dart';
import 'package:bush_track/core/services/database_service.dart';
import 'package:bush_track/core/services/db_migrations.dart';
import 'package:bush_track/features/drawing/models/drawing.dart';
import 'package:bush_track/features/drawing/providers/drawings_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
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

  const leonora = LatLng(-28.88, 121.33);
  const fence = [LatLng(-28.88, 121.33), LatLng(-28.885, 121.34), LatLng(-28.89, 121.335)];

  Drawing line({int? fileId}) => Drawing(
      kind: DrawingKind.line, name: 'north fence', points: fence, fileId: fileId);

  group('saving and reading back', () {
    test('a drawing comes back as it went in', () async {
      final d = line();
      final id = await service.insertDrawing(d.toMap());
      final back = Drawing.fromMap((await service.getDrawings()).single);

      expect(back.id, id);
      expect(back.uuid, d.uuid);
      expect(back.kind, DrawingKind.line);
      expect(back.name, 'north fence');
      expect(back.points, fence);
      expect(back.colour, d.colour);
      expect(back.width, d.width);
      expect(back.fileId, isNull);
    });

    test('stored latitude first, which is not GeoJSON order', () async {
      // Deliberately pinned: an export that forgot to flip this would put
      // Leonora off the coast of Somalia.
      await service.insertDrawing(line().toMap());
      final raw = (await db.query('drawings')).single['points'] as String;
      final first = (jsonDecode(raw) as List).first as List;
      expect(first, [leonora.latitude, leonora.longitude]);
    });

    test('every drawing gets its own uuid when it is made', () {
      // Nothing backfills uuids for new rows; a drawing without one could
      // never be matched to its shared copy later.
      expect(line().uuid, isNot(line().uuid));
      expect(line().uuid, hasLength(36));
    });
  });

  group('deleting leaves a tombstone', () {
    test('gone from the list, still in the table', () async {
      final id = await service.insertDrawing(line().toMap());
      await service.deleteDrawing(id);

      expect(await service.getDrawings(), isEmpty);
      final row = (await db.query('drawings')).single;
      expect(row['deleted_at'], isNotNull,
          reason: 'the deletion has to be able to sync');
    });
  });

  group('deleting the project it is filed under', () {
    Future<int> project() => db.insert('field_files',
        {'name': 'Kookynie', 'created_at': 1, 'updated_at': 1});

    test('is counted in what the confirmation says will go', () async {
      final p = await project();
      await service.insertDrawing(line(fileId: p).toMap());
      await service.insertDrawing(line(fileId: p).toMap());
      final gone = await service.insertDrawing(line(fileId: p).toMap());
      await service.deleteDrawing(gone);
      await service.insertDrawing(line().toMap()); // not in the project

      final c = await service.countFieldFileContents(p);
      expect(c.drawings, 2);
      expect(c.fieldItems, 2);
      expect(c.describe(), '2 drawings');
    });

    test('keeping the contents moves it to Unsorted, not into limbo',
        () async {
      // Left out of the cascade it would stay filed under a project that no
      // longer exists: in no project's list and not in Unsorted either.
      final p = await project();
      await service.insertDrawing(line(fileId: p).toMap());

      await service.deleteFieldFile(p);

      final back = Drawing.fromMap((await service.getDrawings()).single);
      expect(back.fileId, isNull);
    });

    test('deleting the contents takes it, as a tombstone', () async {
      final p = await project();
      await service.insertDrawing(line(fileId: p).toMap());

      await service.deleteFieldFile(p, withContents: true);

      expect(await service.getDrawings(), isEmpty);
      expect((await db.query('drawings')).single['deleted_at'], isNotNull);
    });

    test('and leaves other projects alone', () async {
      final p = await project();
      final other = await project();
      await service.insertDrawing(line(fileId: other).toMap());

      await service.deleteFieldFile(p, withContents: true);

      expect(Drawing.fromMap((await service.getDrawings()).single).fileId,
          other);
    });
  });

  group('the provider', () {
    test('will not save a line with nothing to draw', () async {
      final n = DrawingsNotifier(service);
      expect(
          await n.add(Drawing(kind: DrawingKind.line, points: const [leonora])),
          isNull);
      expect(await service.getDrawings(), isEmpty);
    });

    test('Unsorted is stored as NULL, never as -1', () async {
      final n = DrawingsNotifier(service);
      final p = await db.insert('field_files',
          {'name': 'Kookynie', 'created_at': 1, 'updated_at': 1});
      final d = (await n.add(line(fileId: p)))!;

      await n.moveToFile(d, FieldFile.unsortedId);

      expect((await db.query('drawings')).single['file_id'], isNull);
      expect(n.state.single.fileId, isNull);
    });
  });

  group('a damaged points column', () {
    test('reads as an empty line rather than throwing', () {
      for (final bad in ['', 'not json', '{"a":1}', '[1,2,3]', null, 42]) {
        expect(Drawing.decodePoints(bad), isEmpty, reason: '$bad');
      }
    });

    test('drops only the positions that cannot be real', () {
      expect(
          Drawing.decodePoints('[[-28.9,121.3],[200,121],["x",1],[-29,121.4]]'),
          const [LatLng(-28.9, 121.3), LatLng(-29, 121.4)]);
    });
  });

  test('migration 6 is safe to run twice', () async {
    // markFresh already ran it in setUp.
    await DbMigrations.upgrade(db, from: 5, to: 6);
    await service.insertDrawing(line().toMap());
    expect(await service.getDrawings(), hasLength(1));
  });
}
