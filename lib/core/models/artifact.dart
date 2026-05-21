class Artifact {
  final int? id;
  final String label;
  final String? materialType;
  final String? dimensions;
  final String? condition;
  final String? fieldNotes;
  final double? latitude;
  final double? longitude;
  final double? altitude;
  final List<String> photoPaths;
  final String? geologist;
  final bool signedOff;
  final DateTime createdAt;

  const Artifact({
    this.id,
    required this.label,
    this.materialType,
    this.dimensions,
    this.condition,
    this.fieldNotes,
    this.latitude,
    this.longitude,
    this.altitude,
    this.photoPaths = const [],
    this.geologist,
    this.signedOff = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'label': label,
        'material_type': materialType,
        'dimensions': dimensions,
        'condition': condition,
        'field_notes': fieldNotes,
        'latitude': latitude,
        'longitude': longitude,
        'altitude': altitude,
        'photo_paths': photoPaths.join('||'),
        'geologist': geologist,
        'signed_off': signedOff ? 1 : 0,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory Artifact.fromMap(Map<String, dynamic> m) => Artifact(
        id: m['id'] as int?,
        label: (m['label'] as String?) ?? 'Artifact',
        materialType: m['material_type'] as String?,
        dimensions: m['dimensions'] as String?,
        condition: m['condition'] as String?,
        fieldNotes: m['field_notes'] as String?,
        latitude: (m['latitude'] as num?)?.toDouble(),
        longitude: (m['longitude'] as num?)?.toDouble(),
        altitude: (m['altitude'] as num?)?.toDouble(),
        photoPaths: ((m['photo_paths'] as String?) ?? '')
            .split('||')
            .where((s) => s.isNotEmpty)
            .toList(),
        geologist: m['geologist'] as String?,
        signedOff: (m['signed_off'] as int? ?? 0) == 1,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            m['created_at'] as int? ?? 0),
      );

  Artifact copyWith({
    int? id,
    String? label,
    String? materialType,
    String? dimensions,
    String? condition,
    String? fieldNotes,
    double? latitude,
    double? longitude,
    double? altitude,
    List<String>? photoPaths,
    String? geologist,
    bool? signedOff,
    DateTime? createdAt,
  }) =>
      Artifact(
        id: id ?? this.id,
        label: label ?? this.label,
        materialType: materialType ?? this.materialType,
        dimensions: dimensions ?? this.dimensions,
        condition: condition ?? this.condition,
        fieldNotes: fieldNotes ?? this.fieldNotes,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        altitude: altitude ?? this.altitude,
        photoPaths: photoPaths ?? this.photoPaths,
        geologist: geologist ?? this.geologist,
        signedOff: signedOff ?? this.signedOff,
        createdAt: createdAt ?? this.createdAt,
      );
}
