import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:sqflite/sqflite.dart';

class SavedPlace {
  final int? id;
  final String name;
  final String description;
  final LatLng location;
  final String category;
  final DateTime createdAt;
  final bool isFavorite;

  SavedPlace({
    this.id,
    required this.name,
    required this.description,
    required this.location,
    required this.category,
    required this.createdAt,
    this.isFavorite = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'latitude': location.latitude,
      'longitude': location.longitude,
      'category': category,
      'created_at': createdAt.millisecondsSinceEpoch,
      'is_favorite': isFavorite ? 1 : 0,
    };
  }

  factory SavedPlace.fromMap(Map<String, dynamic> map) {
    return SavedPlace(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      location: LatLng(map['latitude'], map['longitude']),
      category: map['category'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      isFavorite: map['is_favorite'] == 1,
    );
  }
}

class SavedPlacesService {
  final Database database;

  SavedPlacesService(this.database);

  // Create the saved_places table if it doesn't exist
  Future<void> init() async {
    await database.execute('''
      CREATE TABLE IF NOT EXISTS saved_places (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        category TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        is_favorite INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  // Add a new saved place
  Future<int> addPlace(SavedPlace place) async {
    return await database.insert('saved_places', place.toMap());
  }

  // Get all saved places
  Future<List<SavedPlace>> getAllPlaces() async {
    final List<Map<String, dynamic>> maps = await database.query('saved_places');
    return maps.map((map) => SavedPlace.fromMap(map)).toList();
  }

  // Get places by category
  Future<List<SavedPlace>> getPlacesByCategory(String category) async {
    final List<Map<String, dynamic>> maps = await database.query(
      'saved_places',
      where: 'category = ?',
      whereArgs: [category],
    );
    return maps.map((map) => SavedPlace.fromMap(map)).toList();
  }

  // Get favorite places
  Future<List<SavedPlace>> getFavoritePlaces() async {
    final List<Map<String, dynamic>> maps = await database.query(
      'saved_places',
      where: 'is_favorite = 1',
    );
    return maps.map((map) => SavedPlace.fromMap(map)).toList();
  }

  // Update a place
  Future<int> updatePlace(SavedPlace place) async {
    return await database.update(
      'saved_places',
      place.toMap(),
      where: 'id = ?',
      whereArgs: [place.id],
    );
  }

  // Delete a place
  Future<int> deletePlace(int id) async {
    return await database.delete(
      'saved_places',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Toggle favorite status
  Future<void> toggleFavorite(int id, bool isFavorite) async {
    await database.update(
      'saved_places',
      {'is_favorite': isFavorite ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

// Provider for the saved places service
final savedPlacesServiceProvider = Provider<SavedPlacesService>((ref) {
  throw UnimplementedError('SavedPlacesService should be provided in main()');
});