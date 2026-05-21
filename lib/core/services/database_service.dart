import 'dart:async';
import 'dart:collection';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:sqflite_common/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' show sqfliteFfiInit, databaseFactoryFfi;
import 'package:path/path.dart';

/// Database service that works on both mobile and web
/// On web, uses in-memory storage since SQLite isn't natively supported
class DatabaseService {
  Database? _db;
  bool _initialized = false;
  bool get _isWeb => kIsWeb;
  
  // In-memory storage for web
  final HashMap<String, List<Map<String, dynamic>>> _webStorage = HashMap();
  int _webIdCounter = 1;
  
  Future<void> initialize() async {
    if (_initialized) return;
    
    if (_isWeb) {
      // For web, initialize in-memory storage
      _initialized = true;
      debugPrint('Web in-memory database initialized');
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
        // Verify tables exist
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
        is_pin INTEGER DEFAULT 0
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
        is_active INTEGER DEFAULT 0
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
  }
  
  // Helper to get storage for table
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
      
      // Remove existing peer with same peer_id
      _getTable('mesh_peers').removeWhere((item) => item['peer_id'] == data['peer_id']);
      _getTable('mesh_peers').add(data);
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
