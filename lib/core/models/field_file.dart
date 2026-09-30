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

  const FieldFile({
    this.id,
    required this.name,
    this.description,
    this.latitude,
    this.longitude,
    required this.createdAt,
    required this.updatedAt,
  });

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
      );

  FieldFile copyWith({
    int? id,
    String? name,
    String? description,
    double? latitude,
    double? longitude,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      FieldFile(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
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
