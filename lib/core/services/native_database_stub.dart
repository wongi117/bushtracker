// Stub for web platforms - Isar is not supported on web
// This file is used when compiling for web

// Stub type for Isar
class Isar {
  static const autoIncrement = 0;
}

// Stub schema classes for web - just return empty lists
class WaypointSchema {
  static List<Never> get schemas => [];
}

class TrailSchema {
  static List<Never> get schemas => [];
}

class BreadcrumbSchema {
  static List<Never> get schemas => [];
}

class MapRegionSchema {
  static List<Never> get schemas => [];
}

class MeshPeerSchema {
  static List<Never> get schemas => [];
}

// Stub class for Isar instance
class IsarInstance {
  Future<void> close() async {}
}

/// Stub initialization for web - returns null
Future<dynamic> initializeIsar() async {
  // Isar is not supported on web
  return null;
}
