// Every model is saved by handing its toMap() straight to sqflite, so a key
// that does not match a real column is a silent data-loss bug: the insert
// throws at runtime and the record is simply never stored. Waypoint.toMap()
// used to emit 'order' against a column named 'order_index' ("order" is also
// a reserved SQL keyword), so no dropped pin ever survived a reload.
//
// These tests run the real CREATE TABLE statements against in-memory SQLite
// and push each model through them.
import 'package:bush_track/core/models/artifact.dart';
import 'package:bush_track/core/models/breadcrumb.dart';
import 'package:bush_track/core/models/field_file.dart';
import 'package:bush_track/core/models/geofence.dart';
import 'package:bush_track/core/models/trail.dart';
import 'package:bush_track/core/models/waypoint.dart';
import 'package:bush_track/core/services/database_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await DatabaseService().createTablesForTest(db);
  });

  tearDown(() => db.close());

  // The photo bug, against real SQLite rather than against the codec alone.
  // This is what "kill the app and reopen it" actually exercises: toMap into a
  // column, and fromMap back out of it.
  group('photos survive the database', () {
    String jpegUri(String payload) => 'data:image/jpeg;base64,$payload';

    Future<Waypoint> reload(Waypoint pin) async {
      await db.insert('waypoints', pin.toMap());
      final rows = await db.query('waypoints');
      return Waypoint.fromMap(rows.single);
    }

    test('one photo comes back as one photo', () async {
      // Reported as "2 photos" with a 1/2 counter and two placeholders, from a
      // single photo: the column was joined on a comma and split on a comma,
      // and every base64 data URI contains one.
      final pin = Waypoint(
        latitude: -28.88,
        longitude: 121.33,
        isPin: true,
        photoPaths: [jpegUri('AAECAwQFBgcICQoLDA0ODw==')],
      );

      final back = await reload(pin);
      expect(back.photoPaths, hasLength(1));
      expect(back.photoCount, 1);
      expect(back.photoPaths!.single, jpegUri('AAECAwQFBgcICQoLDA0ODw=='));
    });

    test('several photos come back in order and intact', () async {
      final photos = [jpegUri('AAAA'), jpegUri('BBBB'), jpegUri('CCCC')];
      final back = await reload(Waypoint(
        latitude: -28.88,
        longitude: 121.33,
        isPin: true,
        photoPaths: photos,
      ));
      expect(back.photoPaths, photos);
      expect(back.photoCount, 3);
    });

    test('a pin with no photos still has none', () async {
      final back = await reload(
          Waypoint(latitude: -28.88, longitude: 121.33, isPin: true));
      expect(back.hasPhotos, isFalse);
      expect(back.photoCount, 0);
    });

    test('a row written by the old code is recovered, not lost', () async {
      // Simulating a phone that already has photos saved the broken way.
      final photo = jpegUri('AAECAwQFBgcICQoLDA0ODw==');
      await db.insert('waypoints', {
        'latitude': -28.88,
        'longitude': 121.33,
        'is_pin': 1,
        'photo_paths': [photo].join(','), // exactly what the old toMap wrote
      });

      final rows = await db.query('waypoints');
      final back = Waypoint.fromMap(rows.single);
      expect(back.photoCount, 1, reason: 'existing photos must come back');
      expect(back.photoPaths!.single, photo);
    });
  });

  test('a dropped pin survives a save and reload', () async {
    final pin = Waypoint(
      latitude: -28.8833,
      longitude: 121.3333,
      label: 'Camp',
      notes: 'water 200m east',
      timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      type: 'manual',
      color: '#FF6D00',
      icon: 'pin',
      order: 3,
      isPin: true,
      rating: 5,
    );

    await db.insert('waypoints', pin.toMap());

    final rows = await db.query('waypoints');
    expect(rows, hasLength(1));

    final back = Waypoint.fromMap(rows.first);
    expect(back.label, 'Camp');
    expect(back.notes, 'water 200m east');
    expect(back.latitude, closeTo(-28.8833, 1e-9));
    expect(back.longitude, closeTo(121.3333, 1e-9));
    expect(back.isPin, isTrue);
    expect(back.order, 3, reason: 'trail numbering must round-trip');
    expect(back.rating, 5);
    expect(back.timestamp, DateTime.fromMillisecondsSinceEpoch(1700000000000));
  });

  test('a trail survives a save and reload', () async {
    final trail = Trail(
      name: 'Leonora loop',
      description: 'north track',
      createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(1700000100000),
      totalDistance: 1234.5,
      totalElevation: 42.0,
      durationSeconds: 3600,
      difficulty: 'easy',
      isSaved: true,
      waypointsJson: '[]',
      color: '#7B2FFF',
      lineStyle: 'solid',
      showDirection: true,
      isActive: false,
    );

    await db.insert('trails', trail.toMap());

    final rows = await db.query('trails');
    expect(rows, hasLength(1));
    final back = Trail.fromMap(rows.first);
    expect(back.name, 'Leonora loop');
    expect(back.totalDistance, closeTo(1234.5, 1e-9));
    expect(back.isSaved, isTrue);
  });

  test('a breadcrumb survives a save and reload', () async {
    final crumb = Breadcrumb(
      latitude: -28.88,
      longitude: 121.33,
      altitude: 375.0,
      accuracy: 5.0,
      speed: 1.2,
      timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      sessionId: 'session-1',
    );

    await db.insert('breadcrumbs', crumb.toMap());

    final rows = await db.query('breadcrumbs');
    expect(rows, hasLength(1));
    expect(Breadcrumb.fromMap(rows.first).sessionId, 'session-1');
  });

  test('a flagged zone survives a save and reload', () async {
    final zone = Geofence(
      name: 'Heritage site',
      latitude: -28.88,
      longitude: 121.33,
      radiusMeters: 250,
      isActive: true,
      createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
    );

    await db.insert('geofences', zone.toMap());

    final rows = await db.query('geofences');
    expect(rows, hasLength(1));
    final back = Geofence.fromMap(rows.first);
    expect(back.name, 'Heritage site');
    expect(back.radiusMeters, closeTo(250, 1e-9));
    expect(back.isActive, isTrue);
  });

  test('a drawn boundary survives a save and reload', () async {
    const corners = [
      LatLng(-28.900, 121.300),
      LatLng(-28.900, 121.310),
      LatLng(-28.890, 121.310),
      LatLng(-28.890, 121.300),
    ];
    final zone = Geofence.polygon(
      name: 'Lease edge',
      points: corners,
      isActive: true,
      createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      category: ZoneCategory.survey,
      notes: 'pegged 12/09',
    );

    await db.insert('geofences', zone.toMap());

    final rows = await db.query('geofences');
    expect(rows, hasLength(1));
    final back = Geofence.fromMap(rows.first);
    expect(back.shape, ZoneShape.polygon);
    expect(back.points, hasLength(4));
    expect(back.category, ZoneCategory.survey);
    expect(back.notes, 'pegged 12/09');
  });

  test('a field file survives a save and reload', () async {
    final file = FieldFile(
      name: 'Leonora survey',
      description: 'north lease walkover',
      latitude: -28.8833,
      longitude: 121.3333,
      createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(1700000900000),
    );

    await db.insert('field_files', file.toMap());

    final rows = await db.query('field_files');
    expect(rows, hasLength(1));
    final back = FieldFile.fromMap(rows.first);
    expect(back.name, 'Leonora survey');
    expect(back.description, 'north lease walkover');
    expect(back.position!.latitude, closeTo(-28.8833, 1e-9));
    expect(back.updatedAt,
        DateTime.fromMillisecondsSinceEpoch(1700000900000));
  });

  test('a note survives a save and reload, with where it was written',
      () async {
    final note = FileNote(
      fileId: 3,
      body: 'old shaft, unfenced, 20 m off the track',
      latitude: -28.8840,
      longitude: 121.3341,
      createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
    );

    await db.insert('file_notes', note.toMap());

    final rows = await db.query('file_notes');
    expect(rows, hasLength(1));
    final back = FileNote.fromMap(rows.first);
    expect(back.fileId, 3);
    expect(back.body, 'old shaft, unfenced, 20 m off the track');
    expect(back.position!.longitude, closeTo(121.3341, 1e-9));
  });

  test('a pin and a zone remember which file they were collected under',
      () async {
    final pin = Waypoint(
      latitude: -28.88,
      longitude: 121.33,
      label: 'Sample point',
      timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      isPin: true,
      fileId: 7,
    );
    final zone = Geofence(
      name: 'Work area',
      latitude: -28.88,
      longitude: 121.33,
      radiusMeters: 300,
      isActive: true,
      createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      fileId: 7,
    );

    await db.insert('waypoints', pin.toMap());
    await db.insert('geofences', zone.toMap());

    expect(Waypoint.fromMap((await db.query('waypoints')).first).fileId, 7);
    expect(Geofence.fromMap((await db.query('geofences')).first).fileId, 7);
  });

  test('an artifact record survives a save and reload', () async {
    final artifact = Artifact(
      label: 'Quartz sample',
      materialType: 'quartz',
      latitude: -28.88,
      longitude: 121.33,
      createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
    );

    await db.insert('artifacts', artifact.toMap());

    final rows = await db.query('artifacts');
    expect(rows, hasLength(1));
    expect(Artifact.fromMap(rows.first).label, 'Quartz sample');
  });
}
