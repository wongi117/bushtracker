import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' show sqfliteFfiInit, databaseFactoryFfi;
import 'package:path/path.dart';

class DatabaseService {
  Database? _db;
  bool _initialized = false;
  bool get _isWeb => kIsWeb;
  SharedPreferences? _prefs;

  // In-memory cache for web (backed by localStorage)
  final HashMap<String, List<Map<String, dynamic>>> _webStorage = HashMap();
  int _webIdCounter = 1;

  static const _tables = ['waypoints', 'trails', 'breadcrumbs', 'map_regions', 'mesh_peers'];
  static const _keyPrefix = 'pinage_db_';

  Future<void> initialize() async {
    if (_initialized) return;

    if (_isWeb) {
      _prefs = await SharedPreferences.getInstance();
      // Load persisted data from localStorage into in-memory cache
      for (final table in _tables) {
        final json = _prefs!.getString('$_keyPrefix$table');
        if (json != null) {
          try {
            final decoded = jsonDecode(json) as List;
            _webStorage[table] = decoded
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
          } catch (_) {
            _webStorage[table] = [];
          }
        }
      }
      // Restore ID counter above the highest existing ID
      for (final rows in _webStorage.values) {
        for (final row in rows) {
          final id = row['id'];
          if (id is int && id >= _webIdCounter) _webIdCounter = id + 1;
        }
      }
      _initialized = true;
      debugPrint('Web localStorage database initialized');
      return;
    }

    // sqflite_common_ffi is desktop-only (Linux/Windows/macOS).
    // On Android/iOS the sqflite plugin provides the factory automatically —
    // calling sqfliteFfiInit() on Android loads a non-existent native lib and crashes.
    if (!Platform.isAndroid && !Platform.isIOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'bush_track.db');

    _db = await openDatabase(
      path,
      onCreate: (db, version) async {
        await _createTables(db);
      },
      onOpen: (db) async {
        try {
          await db.query('waypoints', limit: 1);
        } catch (e) {
          await _createTables(db);
        }
      },
      version: 1,
    );

    _initialized = true;
    debugPrint('Native SQLite database initialized at: $path');
  }

  Future<void> _createTables(Database db) async {
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
        is_pin INTEGER DEFAULT 0
      )
    ''');

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
        is_active INTEGER DEFAULT 0
      )
    ''');

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
  }

  // Saves a single table to localStorage
  Future<void> _persistWeb(String table) async {
    if (!_isWeb || _prefs == null) return;
    final data = _webStorage[table] ?? [];
    await _prefs!.setString('$_keyPrefix$table', jsonEncode(data));
  }

  List<Map<String, dynamic>> _getTable(String table) {
    return _webStorage.putIfAbsent(table, () => []);
  }

  // Waypoint operations
  Future<int> insertWaypoint(Map<String, dynamic> waypoint) async {
    if (_isWeb) {
      final data = Map<String, dynamic>.from(waypoint);
      data['id'] = _webIdCounter++;
      data['timestamp'] ??= DateTime.now().millisecondsSinceEpoch;
      _getTable('waypoints').add(data);
      await _persistWeb('waypoints');
      return data['id'];
    }
    return await _db!.insert('waypoints', waypoint);
  }

  Future<List<Map<String, dynamic>>> getWaypoints() async {
    if (_isWeb) {
      final list = _getTable('waypoints');
      list.sort((a, b) => (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0));
      return list.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return await _db!.query('waypoints', orderBy: 'timestamp DESC');
  }

  Future<int> deleteWaypoint(int id) async {
    if (_isWeb) {
      _getTable('waypoints').removeWhere((item) => item['id'] == id);
      await _persistWeb('waypoints');
      return 1;
    }
    return await _db!.delete('waypoints', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateWaypoint(Map<String, dynamic> waypoint) async {
    final id = waypoint['id'];
    if (id == null) return 0;

    if (_isWeb) {
      final table = _getTable('waypoints');
      final index = table.indexWhere((item) => item['id'] == id);
      if (index >= 0) {
        table[index] = Map<String, dynamic>.from(waypoint);
        await _persistWeb('waypoints');
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
    if (_isWeb) {
      final count = _getTable('waypoints').length;
      _getTable('waypoints').clear();
      await _persistWeb('waypoints');
      return count;
    }
    return await _db!.delete('waypoints');
  }

  // Trail operations
  Future<int> insertTrail(Map<String, dynamic> trail) async {
    if (_isWeb) {
      final data = Map<String, dynamic>.from(trail);
      data['id'] = _webIdCounter++;
      data['created_at'] ??= DateTime.now().millisecondsSinceEpoch;
      data['updated_at'] ??= DateTime.now().millisecondsSinceEpoch;
      _getTable('trails').add(data);
      await _persistWeb('trails');
      return data['id'];
    }
    return await _db!.insert('trails', trail);
  }

  Future<List<Map<String, dynamic>>> getTrails() async {
    if (_isWeb) {
      final list = _getTable('trails');
      list.sort((a, b) => (b['updated_at'] ?? 0).compareTo(a['updated_at'] ?? 0));
      return list.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return await _db!.query('trails', orderBy: 'updated_at DESC');
  }

  Future<int> updateTrail(Map<String, dynamic> trail) async {
    final id = trail['id'];
    if (id == null) return 0;

    if (_isWeb) {
      final table = _getTable('trails');
      final index = table.indexWhere((item) => item['id'] == id);
      if (index >= 0) {
        table[index] = Map<String, dynamic>.from(trail);
        await _persistWeb('trails');
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
    if (_isWeb) {
      _getTable('trails').removeWhere((item) => item['id'] == id);
      await _persistWeb('trails');
      return 1;
    }
    return await _db!.delete('trails', where: 'id = ?', whereArgs: [id]);
  }

  // Breadcrumb operations
  Future<int> insertBreadcrumb(Map<String, dynamic> breadcrumb) async {
    if (_isWeb) {
      final data = Map<String, dynamic>.from(breadcrumb);
      data['id'] = _webIdCounter++;
      data['timestamp'] ??= DateTime.now().millisecondsSinceEpoch;
      _getTable('breadcrumbs').add(data);
      await _persistWeb('breadcrumbs');
      return data['id'];
    }
    return await _db!.insert('breadcrumbs', breadcrumb);
  }

  Future<List<Map<String, dynamic>>> getBreadcrumbs(String sessionId) async {
    if (_isWeb) {
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

  // Map region operations
  Future<int> insertMapRegion(Map<String, dynamic> region) async {
    if (_isWeb) {
      final data = Map<String, dynamic>.from(region);
      data['id'] = _webIdCounter++;
      _getTable('map_regions').add(data);
      await _persistWeb('map_regions');
      return data['id'];
    }
    return await _db!.insert('map_regions', region);
  }

  Future<List<Map<String, dynamic>>> getMapRegions() async {
    if (_isWeb) {
      return _getTable('map_regions').map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return await _db!.query('map_regions');
  }

  // Mesh peer operations
  Future<int> insertMeshPeer(Map<String, dynamic> peer) async {
    if (_isWeb) {
      final data = Map<String, dynamic>.from(peer);
      data['id'] = _webIdCounter++;
      data['last_seen'] ??= DateTime.now().millisecondsSinceEpoch;
      _getTable('mesh_peers').removeWhere((item) => item['peer_id'] == data['peer_id']);
      _getTable('mesh_peers').add(data);
      await _persistWeb('mesh_peers');
      return data['id'];
    }
    return await _db!.insert('mesh_peers', peer, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getMeshPeers() async {
    if (_isWeb) {
      final list = _getTable('mesh_peers');
      list.sort((a, b) => (b['last_seen'] ?? 0).compareTo(a['last_seen'] ?? 0));
      return list.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return await _db!.query('mesh_peers', orderBy: 'last_seen DESC');
  }

  Future<void> close() async {
    if (_isWeb) {
      _webStorage.clear();
    } else {
      await _db?.close();
    }
    _db = null;
    _initialized = false;
  }
}
