import 'dart:async';
import 'dart:collection';

import 'package:bush_track/core/models/photo_paths_codec.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common/sqflite.dart';
import 'package:path/path.dart';
import 'db_migrations.dart';
import 'photo_migration.dart';
import 'oversize_rows.dart';

import 'native_db_factory_stub.dart'
    if (dart.library.io) 'native_db_factory_io.dart';
import 'web_db_factory_stub.dart'
    if (dart.library.js_interop) 'web_db_factory_web.dart';

/// Database service that works on both mobile and web.
///
/// Web used to keep everything in memory, so every pin, trail, zone and note
/// vanished on refresh. It now opens real SQLite in the browser (the same
/// schema and queries as the phone). The in-memory store is kept only as a
/// fallback for browsers where that cannot open — private windows, or storage
/// blocked — so the app still runs, just without saving.
class DatabaseService {
  Database? _db;
  bool _initialized = false;

  /// False when the app fell back to memory — nothing survives a refresh.
  /// Surfaced in the menu, because release web builds print nothing.
  bool get isPersistent => _db != null;

  /// The open database, for code that needs to run its own SQL.
  ///
  /// Null on web where no factory would open, and before [initialize]. Callers
  /// must handle that rather than assuming — the outbox and the photo
  /// migration both do.
  Database? get database => _db;

  /// Why the browser database could not open, when it could not.
  String? storageFailure;

  /// What storage actually did this boot, e.g. "boot 3 · 7 pins".
  ///
  /// Opening a database is not proof that it saves: the browser stack falls
  /// back to an in-memory filesystem silently, so every boot looks healthy
  /// while nothing survives a refresh. The counter below is written on one
  /// boot and read on the next, which is the only thing that actually
  /// distinguishes the two.
  String storageReport = 'not checked';

  /// True once a previous boot's counter has been read back — i.e. storage is
  /// genuinely surviving reloads, not merely open.
  bool provenAcrossReloads = false;
  bool get _isWeb => kIsWeb;
  
  // In-memory storage for web
  final HashMap<String, List<Map<String, dynamic>>> _webStorage = HashMap();
  int _webIdCounter = 1;
  
  Future<void> initialize() async {
    if (_initialized) return;
    
    // Platform check — NOT "_db == null". Getting that wrong sends native
    // down the web path and leaves the phone app in memory too.
    if (_isWeb) {
      for (final factory in webDatabaseFactories) {
        try {
          databaseFactory = factory;
          _db = await factory.openDatabase(
            'bush_track.db',
            options: OpenDatabaseOptions(
              version: DbMigrations.currentVersion,
              onCreate: (db, version) async {
                await _createTables(db);
                await DbMigrations.markFresh(db);
              },
              onUpgrade: (db, from, to) =>
                  DbMigrations.upgrade(db, from: from, to: to),
              onOpen: _onOpen,
            ),
          );
          _initialized = true;
          await _runStorageSelfTest();
          debugPrint('Web SQLite initialized: $storageReport');
          return;
        } catch (e) {
          // Private windows, blocked storage, or a browser that refuses the
          // shared worker. Keep the reason: release web builds do not print
          // to the console, so this is the only way to see it.
          storageFailure = '$e';
          debugPrint('Web SQLite factory failed: $e');
          _db = null;
        }
      }
      _initialized = true;
      debugPrint('Web in-memory database (data will NOT persist)');
      return;
    }

    // The phone uses the sqflite plugin; only desktop uses FFI. Forcing FFI
    // here meant the database never opened on Android.
    final factory = nativeDatabaseFactory();
    if (factory == null) {
      _initialized = true;
      storageFailure = 'No database available on this platform';
      return;
    }
    databaseFactory = factory;

    final databasesPath = await factory.getDatabasesPath();
    final path = join(databasesPath, 'bush_track.db');

    _db = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: DbMigrations.currentVersion,
        onCreate: (db, version) async {
          await _createTables(db);
          await DbMigrations.markFresh(db);
        },
        // There was no upgrade path at all. CREATE TABLE IF NOT EXISTS makes
        // what is missing and silently leaves a table whose columns have
        // changed, so the first added column would have started dropping
        // inserts on every phone that already had data.
        onUpgrade: (db, from, to) =>
            DbMigrations.upgrade(db, from: from, to: to),
        onOpen: _onOpen,
      ),
    );
    
    _initialized = true;
    await _runStorageSelfTest();
    debugPrint('Native SQLite initialized at $path: $storageReport');
    await _photoStorageStep();
  }
  
  /// Report what the photo migration would do, and run it only when asked.
  ///
  /// The dry run is unconditional and writes nothing: it is the only way to
  /// see, from a real handset, how many photos are sitting in table rows and
  /// what they weigh. The move itself is behind a build flag so it happens
  /// deliberately, with those numbers already in hand, rather than the first
  /// launch of a new build quietly rewriting every pin on a phone carrying
  /// months of field work.
  ///
  /// Both are best-effort: a failure here must never stop the app opening.
  ///
  /// It runs by default now that it has been verified on a handset carrying
  /// real data — 4 pins, 15 photos, 5.2 MB moved with nothing failed, and a
  /// second launch reporting nothing left to do. The escape hatch is for
  /// diagnosing a phone, not for normal use; `PhotoMigration.rollback()`
  /// restores from the backup table either way.
  static const bool _skipPhotoMigration =
      bool.fromEnvironment('SKIP_PHOTO_MIGRATION');

  Future<void> _photoStorageStep() async {
    final db = _db;
    if (db == null) return;
    try {
      final migration = PhotoMigration(db: db);
      final dry = await migration.dryRun();
      if (dry.nothingToDo || _skipPhotoMigration) return;
      await migration.migrate();
    } catch (e) {
      debugPrint('Photo storage step skipped: $e');
    }
  }

  /// Count this boot, and report whether previous boots were remembered.
  Future<void> _runStorageSelfTest() async {
    try {
      await _db!.execute(
          'CREATE TABLE IF NOT EXISTS app_meta(key TEXT PRIMARY KEY, value TEXT)');
      final rows = await _db!
          .query('app_meta', where: 'key = ?', whereArgs: ['boot_count']);
      final previous =
          rows.isEmpty ? 0 : int.tryParse('${rows.first['value']}') ?? 0;
      final boot = previous + 1;
      await _db!.insert(
        'app_meta',
        {'key': 'boot_count', 'value': '$boot'},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      final counted =
          await _db!.rawQuery('SELECT COUNT(*) AS c FROM waypoints');
      final pins = (counted.first['c'] as int?) ?? 0;
      provenAcrossReloads = previous > 0;
      storageReport = 'boot $boot · $pins saved';
    } catch (e) {
      storageReport = 'self-test failed: $e';
    }
    publishStorageReport(storageReport);
  }

  Future<void> _onOpen(Database db) async {
    // Verify tables exist
    try {
      await db.query('waypoints', limit: 1);
    } catch (e) {
      await _createTables(db);
    }
    // Migrate: add columns introduced after initial schema
    final waypointCols = (await db.rawQuery('PRAGMA table_info(waypoints)'))
        .map((c) => c['name'] as String)
        .toSet();
    if (!waypointCols.contains('rating')) {
      await db.execute('ALTER TABLE waypoints ADD COLUMN rating INTEGER');
    }
    if (!waypointCols.contains('weather_conditions')) {
      await db.execute(
          'ALTER TABLE waypoints ADD COLUMN weather_conditions TEXT');
    }
    // Migrate: create geofences table if missing
    try {
      await db.query('geofences', limit: 1);
    } catch (_) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS geofences(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT,
          latitude REAL,
          longitude REAL,
          radius_meters REAL,
          is_active INTEGER DEFAULT 1,
          created_at INTEGER,
          shape TEXT DEFAULT 'circle',
          points_json TEXT,
          category TEXT,
          notes TEXT,
          file_id INTEGER
        )
      ''');
    }
    // Migrate: zones gained shapes, categories and notes after launch, so a
    // database created before that has the table but not the columns.
    final zoneCols = (await db.rawQuery('PRAGMA table_info(geofences)'))
        .map((c) => c['name'] as String)
        .toSet();
    if (!zoneCols.contains('shape')) {
      await db.execute(
          "ALTER TABLE geofences ADD COLUMN shape TEXT DEFAULT 'circle'");
    }
    if (!zoneCols.contains('points_json')) {
      await db.execute('ALTER TABLE geofences ADD COLUMN points_json TEXT');
    }
    if (!zoneCols.contains('category')) {
      await db.execute('ALTER TABLE geofences ADD COLUMN category TEXT');
    }
    if (!zoneCols.contains('notes')) {
      await db.execute('ALTER TABLE geofences ADD COLUMN notes TEXT');
    }

    // Migrate: files arrived after launch, so an existing database has
    // neither the tables nor the file_id links on what they collect.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS field_files(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        description TEXT,
        latitude REAL,
        longitude REAL,
        created_at INTEGER,
        updated_at INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS file_notes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        file_id INTEGER,
        body TEXT,
        latitude REAL,
        longitude REAL,
        created_at INTEGER
      )
    ''');
    if (!waypointCols.contains('file_id')) {
      await db.execute('ALTER TABLE waypoints ADD COLUMN file_id INTEGER');
    }
    if (!zoneCols.contains('file_id')) {
      await db.execute('ALTER TABLE geofences ADD COLUMN file_id INTEGER');
    }
    final trailCols = (await db.rawQuery('PRAGMA table_info(trails)'))
        .map((c) => c['name'] as String)
        .toSet();
    if (!trailCols.contains('file_id')) {
      await db.execute('ALTER TABLE trails ADD COLUMN file_id INTEGER');
    }

    // Migrate: create artifacts table if missing
    try {
      await db.query('artifacts', limit: 1);
    } catch (_) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS artifacts(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          label TEXT,
          material_type TEXT,
          dimensions TEXT,
          condition TEXT,
          field_notes TEXT,
          latitude REAL,
          longitude REAL,
          altitude REAL,
          photo_paths TEXT,
          geologist TEXT,
          signed_off INTEGER DEFAULT 0,
          created_at INTEGER
        )
      ''');
    }
  }

  /// The real schema, for tests that check every model's toMap() against it.
  /// A column name that does not match is otherwise invisible until a save
  /// fails on a device.
  @visibleForTesting
  Future<void> createTablesForTest(Database db) => _createTables(db);

  /// Point the service at a test database.
  ///
  /// Without this a test can build a schema with [createTablesForTest] and
  /// then exercise methods that never look at it: with no database attached
  /// they fall through to the in-memory maps, pass, and prove nothing about
  /// the SQL. Deletion is the last place to find that out.
  @visibleForTesting
  void attachForTest(Database db) {
    _db = db;
    _initialized = true;
  }

  Future<void> _createTables(Database db) async {
    // Waypoints table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS waypoints(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        latitude REAL,
        longitude REAL,
        altitude REAL,
        accuracy REAL,
        speed REAL,
        label TEXT,
        notes TEXT,
        timestamp INTEGER,
        type TEXT,
        photo_paths TEXT,
        thumbnail_path TEXT,
        color TEXT,
        icon TEXT,
        order_index INTEGER,
        is_pin INTEGER DEFAULT 0,
        rating INTEGER,
        weather_conditions TEXT,
        file_id INTEGER
      )
    ''');
    
    // Trails table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS trails(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        description TEXT,
        created_at INTEGER,
        updated_at INTEGER,
        total_distance REAL,
        total_elevation REAL,
        duration_seconds INTEGER,
        difficulty TEXT,
        is_saved INTEGER,
        waypoints_json TEXT,
        color TEXT DEFAULT '#7B2FFF',
        line_style TEXT DEFAULT 'solid',
        show_direction INTEGER DEFAULT 1,
        is_active INTEGER DEFAULT 0,
        file_id INTEGER
      )
    ''');
    
    // Breadcrumbs table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS breadcrumbs(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        latitude REAL,
        longitude REAL,
        altitude REAL,
        accuracy REAL,
        speed REAL,
        timestamp INTEGER,
        session_id TEXT
      )
    ''');
    
    // Map regions table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS map_regions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        region_id TEXT,
        name TEXT,
        min_lat REAL,
        max_lat REAL,
        min_lng REAL,
        max_lng REAL,
        zoom_level INTEGER,
        tile_data_path TEXT,
        downloaded_at INTEGER,
        expires_at INTEGER,
        is_offline INTEGER,
        size_bytes INTEGER
      )
    ''');
    
    // Mesh peers table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS mesh_peers(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        peer_id TEXT,
        display_name TEXT,
        last_latitude REAL,
        last_longitude REAL,
        last_altitude REAL,
        last_seen INTEGER,
        first_seen INTEGER,
        device_type TEXT,
        signal_strength INTEGER,
        is_connected INTEGER,
        public_key TEXT
      )
    ''');

    // Field files: a folder per job, site or trip.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS field_files(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        description TEXT,
        latitude REAL,
        longitude REAL,
        created_at INTEGER,
        updated_at INTEGER
      )
    ''');

    // Notes written inside a file, each stamped with where it was written.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS file_notes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        file_id INTEGER,
        body TEXT,
        latitude REAL,
        longitude REAL,
        created_at INTEGER
      )
    ''');

    // Geofences table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS geofences(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        latitude REAL,
        longitude REAL,
        radius_meters REAL,
        is_active INTEGER DEFAULT 1,
        created_at INTEGER,
        shape TEXT DEFAULT 'circle',
        points_json TEXT,
        category TEXT,
        notes TEXT,
        file_id INTEGER
      )
    ''');

    // Heritage Artifact Logger table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS artifacts(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        label TEXT,
        material_type TEXT,
        dimensions TEXT,
        condition TEXT,
        field_notes TEXT,
        latitude REAL,
        longitude REAL,
        altitude REAL,
        photo_paths TEXT,
        geologist TEXT,
        signed_off INTEGER DEFAULT 0,
        created_at INTEGER
      )
    ''');
  }
  
  // Helper to get storage for table
  List<Map<String, dynamic>> _getTable(String table) {
    return _webStorage.putIfAbsent(table, () => []);
  }
  
  // Waypoint operations
  Future<int> insertWaypoint(Map<String, dynamic> waypoint) async {
    if (_db == null) {
      final data = Map<String, dynamic>.from(waypoint);
      data['id'] = _webIdCounter++;
      data['timestamp'] ??= DateTime.now().millisecondsSinceEpoch;
      _getTable('waypoints').add(data);
      return data['id'];
    }
    return await _db!.insert('waypoints', waypoint);
  }
  
  Future<List<Map<String, dynamic>>> getWaypoints() async {
    if (_db == null) {
      final list = _getTable('waypoints');
      list.sort((a, b) => (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0));
      return list.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    // Guarded: one pin whose photos outgrew Android's 2 MB row window made
    // this throw, and then no waypoint loaded at all. See OversizeRows.
    return await OversizeRows.query(_db!, 'waypoints',
        bigColumns: const ['photo_paths', 'thumbnail_path'],
        orderBy: 'timestamp DESC');
  }
  
  Future<int> deleteWaypoint(int id) async {
    if (_db == null) {
      _getTable('waypoints').removeWhere((item) => item['id'] == id);
      return 1;
    }
    return await _db!.delete('waypoints', where: 'id = ?', whereArgs: [id]);
  }
  
  Future<int> updateWaypoint(Map<String, dynamic> waypoint) async {
    final id = waypoint['id'];
    if (id == null) return 0;
    
    if (_db == null) {
      final table = _getTable('waypoints');
      final index = table.indexWhere((item) => item['id'] == id);
      if (index >= 0) {
        table[index] = Map<String, dynamic>.from(waypoint);
        return 1;
      }
      return 0;
    }
    return await _db!.update(
      'waypoints',
      waypoint,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  Future<int> deleteAllWaypoints() async {
    if (_db == null) {
      final count = _getTable('waypoints').length;
      _getTable('waypoints').clear();
      return count;
    }
    return await _db!.delete('waypoints');
  }
   
  // Trail operations
  Future<int> insertTrail(Map<String, dynamic> trail) async {
    if (_db == null) {
      final data = Map<String, dynamic>.from(trail);
      data['id'] = _webIdCounter++;
      data['created_at'] ??= DateTime.now().millisecondsSinceEpoch;
      data['updated_at'] ??= DateTime.now().millisecondsSinceEpoch;
      _getTable('trails').add(data);
      return data['id'];
    }
    return await _db!.insert('trails', trail);
  }
  
  Future<List<Map<String, dynamic>>> getTrails() async {
    if (_db == null) {
      final list = _getTable('trails');
      list.sort((a, b) => (b['updated_at'] ?? 0).compareTo(a['updated_at'] ?? 0));
      return list.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return await _db!.query('trails', orderBy: 'updated_at DESC');
  }
  
  Future<int> updateTrail(Map<String, dynamic> trail) async {
    final id = trail['id'];
    if (id == null) return 0;
    
    if (_db == null) {
      final table = _getTable('trails');
      final index = table.indexWhere((item) => item['id'] == id);
      if (index >= 0) {
        table[index] = Map<String, dynamic>.from(trail);
        return 1;
      }
      return 0;
    }
    return await _db!.update(
      'trails',
      trail,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  Future<int> deleteTrail(int id) async {
    if (_db == null) {
      _getTable('trails').removeWhere((item) => item['id'] == id);
      return 1;
    }
    return await _db!.delete('trails', where: 'id = ?', whereArgs: [id]);
  }
   
  // Breadcrumb operations
  Future<int> insertBreadcrumb(Map<String, dynamic> breadcrumb) async {
    if (_db == null) {
      final data = Map<String, dynamic>.from(breadcrumb);
      data['id'] = _webIdCounter++;
      data['timestamp'] ??= DateTime.now().millisecondsSinceEpoch;
      _getTable('breadcrumbs').add(data);
      return data['id'];
    }
    return await _db!.insert('breadcrumbs', breadcrumb);
  }
  
  Future<List<Map<String, dynamic>>> getBreadcrumbs(String sessionId) async {
    if (_db == null) {
      final list = _getTable('breadcrumbs')
          .where((item) => item['session_id'] == sessionId)
          .toList();
      list.sort((a, b) => (a['timestamp'] ?? 0).compareTo(b['timestamp'] ?? 0));
      return list.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return await _db!.query(
      'breadcrumbs',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'timestamp ASC',
    );
  }
  
  Future<void> clearBreadcrumbs(String sessionId) async {
    if (_db == null) {
      _getTable('breadcrumbs').removeWhere((item) => item['session_id'] == sessionId);
      return;
    }
    await _db!.delete('breadcrumbs', where: 'session_id = ?', whereArgs: [sessionId]);
  }

  // Map region operations
  Future<int> insertMapRegion(Map<String, dynamic> region) async {
    if (_db == null) {
      final data = Map<String, dynamic>.from(region);
      data['id'] = _webIdCounter++;
      _getTable('map_regions').add(data);
      return data['id'];
    }
    return await _db!.insert('map_regions', region);
  }
  
  Future<List<Map<String, dynamic>>> getMapRegions() async {
    if (_db == null) {
      return _getTable('map_regions').map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return await _db!.query('map_regions');
  }
  
  // Mesh peer operations
  Future<int> insertMeshPeer(Map<String, dynamic> peer) async {
    if (_db == null) {
      final data = Map<String, dynamic>.from(peer);
      data['id'] = _webIdCounter++;
      data['last_seen'] ??= DateTime.now().millisecondsSinceEpoch;
      
      // Remove existing peer with same peer_id
      _getTable('mesh_peers').removeWhere((item) => item['peer_id'] == data['peer_id']);
      _getTable('mesh_peers').add(data);
      return data['id'];
    }
    return await _db!.insert('mesh_peers', peer, conflictAlgorithm: ConflictAlgorithm.replace);
  }
  
  Future<List<Map<String, dynamic>>> getMeshPeers() async {
    if (_db == null) {
      final list = _getTable('mesh_peers');
      list.sort((a, b) => (b['last_seen'] ?? 0).compareTo(a['last_seen'] ?? 0));
      return list.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return await _db!.query('mesh_peers', orderBy: 'last_seen DESC');
  }
  
  // Field file operations
  Future<int> insertFieldFile(Map<String, dynamic> file) async {
    if (_db == null) {
      final data = Map<String, dynamic>.from(file);
      data['id'] = _webIdCounter++;
      _getTable('field_files').add(data);
      return data['id'];
    }
    return await _db!.insert('field_files', file);
  }

  Future<List<Map<String, dynamic>>> getFieldFiles() async {
    if (_db == null) {
      final list = _getTable('field_files');
      list.sort((a, b) =>
          (b['updated_at'] ?? 0).compareTo(a['updated_at'] ?? 0));
      return list.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return await _db!.query('field_files', orderBy: 'updated_at DESC');
  }

  Future<int> updateFieldFile(Map<String, dynamic> file) async {
    final id = file['id'] as int;
    if (_db == null) {
      final list = _getTable('field_files');
      final idx = list.indexWhere((e) => e['id'] == id);
      if (idx >= 0) list[idx] = Map<String, dynamic>.from(file);
      return idx >= 0 ? 1 : 0;
    }
    return await _db!
        .update('field_files', file, where: 'id = ?', whereArgs: [id]);
  }

  /// Deleting a file takes its notes with it, but leaves the pins, zones and
  /// trails alone - they are records of the ground, not paperwork. They just
  /// stop being filed under anything.
  /// Delete a project.
  ///
  /// [withContents] false -- the default, and what the delete button has always
  /// done -- unfiles the pins, zones and trails and leaves them on the map.
  /// They become Unsorted, which is a view over `file_id IS NULL` and so needs
  /// no row to point at.
  ///
  /// [withContents] true deletes them outright. That is the only operation in
  /// the app that can lose field data, so it is spelled out at the call site
  /// rather than being a flag somebody passes by accident, and the caller is
  /// expected to have shown the counts first.
  ///
  /// One transaction either way. The previous version ran four statements
  /// loose: an interruption between them left the notes deleted and the
  /// project still there, or the pins unfiled under a project that still
  /// claimed them.
  Future<int> deleteFieldFile(int id, {bool withContents = false}) async {
    if (_db == null) {
      _getTable('field_files').removeWhere((e) => e['id'] == id);
      _getTable('file_notes').removeWhere((e) => e['file_id'] == id);
      for (final table in ['waypoints', 'geofences', 'trails']) {
        if (withContents) {
          _getTable(table).removeWhere((e) => e['file_id'] == id);
        } else {
          for (final row in _getTable(table)) {
            if (row['file_id'] == id) row['file_id'] = null;
          }
        }
      }
      return 1;
    }

    return await _db!.transaction((txn) async {
      await txn.delete('file_notes', where: 'file_id = ?', whereArgs: [id]);
      for (final table in ['waypoints', 'geofences', 'trails']) {
        if (withContents) {
          await txn.delete(table, where: 'file_id = ?', whereArgs: [id]);
        } else {
          await txn.update(table, {'file_id': null},
              where: 'file_id = ?', whereArgs: [id]);
        }
      }
      return await txn.delete('field_files', where: 'id = ?', whereArgs: [id]);
    });
  }

  /// How much is filed under a project, so a delete can say what it will take.
  ///
  /// Counted from the database rather than from whatever the providers happen
  /// to be holding, because the number in the confirmation has to be the real
  /// one -- a scoped or filtered list would undercount, and undercounting here
  /// means somebody agrees to lose more than they were told.
  Future<ProjectContents> countFieldFileContents(int id) async {
    if (_db == null) {
      int n(String t) =>
          _getTable(t).where((e) => e['file_id'] == id).length;
      return ProjectContents(
          pins: n('waypoints'),
          zones: n('geofences'),
          trails: n('trails'),
          notes: n('file_notes'));
    }

    Future<int> n(String table) async {
      final rows = await _db!.rawQuery(
          'SELECT COUNT(*) AS c FROM $table WHERE file_id = ?', [id]);
      return (rows.first['c'] as int?) ?? 0;
    }

    return ProjectContents(
      pins: await n('waypoints'),
      zones: await n('geofences'),
      trails: await n('trails'),
      notes: await n('file_notes'),
    );
  }

  /// The photo references still pointed at by some waypoint.
  ///
  /// Fed to [PhotoFileStore.orphans] after a delete, so files on disk are
  /// removed by being unreferenced rather than by path arithmetic. Deleting by
  /// the paths that were just removed would take a photo that another pin also
  /// points at, which is possible as soon as anything is duplicated.
  Future<Set<String>> referencedPhotoPaths() async {
    final rows = _db == null
        ? _getTable('waypoints')
        : await OversizeRows.query(_db!, 'waypoints',
            columns: const ['photo_paths'],
            bigColumns: const ['photo_paths']);
    final out = <String>{};
    for (final row in rows) {
      final raw = row['photo_paths'];
      if (raw is String && raw.isNotEmpty) {
        // A column that will not decode yields null. Treated as "cannot say
        // what this pin references", so nothing is added and the orphan sweep
        // keeps the files -- erring towards an unused photo on disk rather
        // than deleting one that is still in use.
        out.addAll(PhotoPathsCodec.decode(raw) ?? const <String>[]);
      }
    }
    return out;
  }

  Future<int> insertFileNote(Map<String, dynamic> note) async {
    if (_db == null) {
      final data = Map<String, dynamic>.from(note);
      data['id'] = _webIdCounter++;
      _getTable('file_notes').add(data);
      return data['id'];
    }
    return await _db!.insert('file_notes', note);
  }

  Future<List<Map<String, dynamic>>> getFileNotes(int fileId) async {
    if (_db == null) {
      final list = _getTable('file_notes')
          .where((e) => e['file_id'] == fileId)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      list.sort((a, b) =>
          (b['created_at'] ?? 0).compareTo(a['created_at'] ?? 0));
      return list;
    }
    return await _db!.query('file_notes',
        where: 'file_id = ?', whereArgs: [fileId], orderBy: 'created_at DESC');
  }

  Future<int> deleteFileNote(int id) async {
    if (_db == null) {
      _getTable('file_notes').removeWhere((e) => e['id'] == id);
      return 1;
    }
    return await _db!.delete('file_notes', where: 'id = ?', whereArgs: [id]);
  }

  // Geofence operations
  Future<int> insertGeofence(Map<String, dynamic> geofence) async {
    if (_db == null) {
      final data = Map<String, dynamic>.from(geofence);
      data['id'] = _webIdCounter++;
      data['created_at'] ??= DateTime.now().millisecondsSinceEpoch;
      _getTable('geofences').add(data);
      return data['id'];
    }
    return await _db!.insert('geofences', geofence);
  }

  Future<List<Map<String, dynamic>>> getGeofences() async {
    if (_db == null) {
      return _getTable('geofences').map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return await _db!.query('geofences', orderBy: 'created_at DESC');
  }

  Future<int> updateGeofence(Map<String, dynamic> geofence) async {
    final id = geofence['id'] as int;
    if (_db == null) {
      final list = _getTable('geofences');
      final idx = list.indexWhere((e) => e['id'] == id);
      if (idx >= 0) list[idx] = Map<String, dynamic>.from(geofence);
      return 1;
    }
    return await _db!.update('geofences', geofence, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteGeofence(int id) async {
    if (_db == null) {
      _getTable('geofences').removeWhere((e) => e['id'] == id);
      return 1;
    }
    return await _db!.delete('geofences', where: 'id = ?', whereArgs: [id]);
  }

  // ─── Artifact operations ────────────────────────────────────────────────────

  Future<int> insertArtifact(Map<String, dynamic> artifact) async {
    if (_db == null) {
      final data = Map<String, dynamic>.from(artifact);
      data['id'] = _webIdCounter++;
      data['created_at'] ??= DateTime.now().millisecondsSinceEpoch;
      _getTable('artifacts').add(data);
      return data['id'];
    }
    return await _db!.insert('artifacts', artifact);
  }

  Future<List<Map<String, dynamic>>> getArtifacts() async {
    if (_db == null) {
      final list = _getTable('artifacts');
      list.sort((a, b) => (b['created_at'] ?? 0).compareTo(a['created_at'] ?? 0));
      return list.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return await _db!.query('artifacts', orderBy: 'created_at DESC');
  }

  Future<int> updateArtifact(Map<String, dynamic> artifact) async {
    final id = artifact['id'] as int;
    if (_db == null) {
      final list = _getTable('artifacts');
      final idx = list.indexWhere((e) => e['id'] == id);
      if (idx >= 0) list[idx] = Map<String, dynamic>.from(artifact);
      return 1;
    }
    return await _db!.update('artifacts', artifact, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteArtifact(int id) async {
    if (_db == null) {
      _getTable('artifacts').removeWhere((e) => e['id'] == id);
      return 1;
    }
    return await _db!.delete('artifacts', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> close() async {
    if (_db == null) {
      _webStorage.clear();
    } else {
      await _db?.close();
    }
    _db = null;
    _initialized = false;
  }
}

/// What a project is holding, for a delete confirmation.
class ProjectContents {
  const ProjectContents({
    this.pins = 0,
    this.zones = 0,
    this.trails = 0,
    this.notes = 0,
  });

  final int pins;
  final int zones;
  final int trails;
  final int notes;

  /// Notes are excluded: they belong to the project and go with it either way,
  /// so they are not part of what the user is being asked to risk.
  int get fieldItems => pins + zones + trails;

  bool get isEmpty => fieldItems == 0;

  /// "12 pins, 3 boundaries and 1 trail", for the confirmation.
  String describe() {
    final parts = <String>[
      if (pins > 0) '$pins ${pins == 1 ? 'pin' : 'pins'}',
      if (zones > 0) '$zones ${zones == 1 ? 'boundary' : 'boundaries'}',
      if (trails > 0) '$trails ${trails == 1 ? 'trail' : 'trails'}',
    ];
    if (parts.isEmpty) return 'nothing';
    if (parts.length == 1) return parts.first;
    return '${parts.sublist(0, parts.length - 1).join(', ')} and ${parts.last}';
  }
}
