import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../models/waypoint.dart';
import '../models/trail.dart';
import '../models/breadcrumb.dart';
import '../models/map_region.dart';
import '../models/mesh_peer.dart';

export '../models/waypoint.dart';
export '../models/trail.dart';
export '../models/breadcrumb.dart';
export '../models/map_region.dart';
export '../models/mesh_peer.dart';

/// Initialize Isar database for mobile platforms
Future<Isar> initializeIsar() async {
  final dir = await getApplicationDocumentsDirectory();
  final isar = await Isar.open(
    [
      WaypointSchema,
      TrailSchema,
      BreadcrumbSchema,
      MapRegionSchema,
      MeshPeerSchema,
    ],
    directory: dir.path,
  );
  return isar;
}
