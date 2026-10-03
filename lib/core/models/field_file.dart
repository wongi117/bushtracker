import 'package:latlong2/latlong.dart';

/// A folder for one job, site or trip.
///
/// The point is to be able to come back later and see everything from where
/// you were working — the notes you wrote, the pins you dropped, the
/// boundaries you flagged — instead of all of it sitting in one undifferentiated
/// pile. One file is "open" at a time, and anything created while it is open
/// is filed under it.
class FieldFile {
  final int? id;
  final String name;
  final String? description;

  /// Where the file was started. Null when there was no fix at the time.
  final double? latitude;
  final double? longitude;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// Hex colour, or null for the default.
  ///
  /// Shared with the pin palette rather than having one of its own: a project
  /// coloured the same as the pins in it reads as one thing, and two palettes
  /// would drift apart.
  final String? colour;

  /// When it was archived, or null if it is live.
  ///
  /// Archived rather than deleted, because a finished job is not rubbish — the
  /// survey still has to be findable next year — but it should not be in the
  /// way every time someone opens the list.
  final DateTime? archivedAt;

  /// Where it sits in the list. Lower is higher up.
  final int sortOrder;

  const FieldFile({
    this.id,
    required this.name,
    this.description,
    this.latitude,
    this.longitude,
    required this.createdAt,
    required this.updatedAt,
    this.colour,
    this.archivedAt,
    this.sortOrder = 0,
  });

  bool get isArchived => archivedAt != null;

  /// The id that means "everything filed under nothing".
  ///
  /// Unsorted is a view over `file_id IS NULL`, not a row in the table. There
  /// are already hundreds of unfiled items on a field phone, and rewriting
  /// every one of them to point at a new project would be a large write over
  /// data that is perfectly fine as it is — with a chance of losing something
  /// in the move, and a project that could then be deleted out from under them.
  /// A view cannot be deleted and cannot drop a record.
  static const int unsortedId = -1;

  /// The standing pseudo-project for unfiled work.
  static FieldFile unsorted() => FieldFile(
        id: unsortedId,
        name: 'Unsorted',
        description: 'Everything not filed under a project',
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
        // Always last: it is where things end up, not somewhere you choose.
        sortOrder: 1 << 30,
      );

  bool get isUnsorted => id == unsortedId;

  LatLng? get position =>
      latitude == null || longitude == null ? null : LatLng(latitude!, longitude!);

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'description': description,
        'latitude': latitude,
        'longitude': longitude,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
        'colour': colour,
        'archived_at': archivedAt?.millisecondsSinceEpoch,
        'sort_order': sortOrder,
      };

  factory FieldFile.fromMap(Map<String, dynamic> map) => FieldFile(
        id: map['id'] as int?,
        name: map['name'] as String? ?? '',
        description: map['description'] as String?,
        latitude: (map['latitude'] as num?)?.toDouble(),
        longitude: (map['longitude'] as num?)?.toDouble(),
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int? ?? 0),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
            map['updated_at'] as int? ?? map['created_at'] as int? ?? 0),
        colour: map['colour'] as String?,
        archivedAt: map['archived_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(map['archived_at'] as int),
        sortOrder: (map['sort_order'] as int?) ?? 0,
      );

  /// [clearArchived] un-archives and [clearColour] goes back to the default
  /// colour. Both exist because a null argument cannot express either: null
  /// means "leave it as it is". Rebuilding the object by hand instead is how
  /// fields get silently dropped -- it is what lost fileId, rating and
  /// weatherConditions off a Waypoint once already.
  FieldFile copyWith({
    int? id,
    String? name,
    String? description,
    double? latitude,
    double? longitude,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? colour,
    DateTime? archivedAt,
    int? sortOrder,
    bool clearArchived = false,
    bool clearColour = false,
  }) =>
      FieldFile(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        colour: clearColour ? null : colour ?? this.colour,
        archivedAt: clearArchived ? null : archivedAt ?? this.archivedAt,
        sortOrder: sortOrder ?? this.sortOrder,
      );
}

/// A written note inside a file, stamped with when and where it was made.
///
/// Where matters as much as what: "shaft here, unfenced" is close to useless
/// without the position it was written at.
class FileNote {
  final int? id;
  final int fileId;
  final String body;
  final double? latitude;
  final double? longitude;
  final DateTime createdAt;

  const FileNote({
    this.id,
    required this.fileId,
    required this.body,
    this.latitude,
    this.longitude,
    required this.createdAt,
  });

  LatLng? get position =>
      latitude == null || longitude == null ? null : LatLng(latitude!, longitude!);

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'file_id': fileId,
        'body': body,
        'latitude': latitude,
        'longitude': longitude,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory FileNote.fromMap(Map<String, dynamic> map) => FileNote(
        id: map['id'] as int?,
        fileId: map['file_id'] as int? ?? 0,
        body: map['body'] as String? ?? '',
        latitude: (map['latitude'] as num?)?.toDouble(),
        longitude: (map['longitude'] as num?)?.toDouble(),
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int? ?? 0),
      );
}
