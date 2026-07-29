export '../models/waypoint.dart';
export '../models/trail.dart';
export '../models/breadcrumb.dart';
export '../models/map_region.dart';
export '../models/mesh_peer.dart';

/// Isar has been removed — all data goes through DatabaseService (SQLite).
/// This stub keeps the conditional import in main.dart working.
Future<dynamic> initializeIsar() async {
  return null;
}
