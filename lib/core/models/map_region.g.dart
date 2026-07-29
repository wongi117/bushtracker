// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'map_region.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetMapRegionCollection on Isar {
  IsarCollection<MapRegion> get mapRegions => this.collection();
}

const MapRegionSchema = CollectionSchema(
  name: r'MapRegion',
  id: 2903950951, // truncated for JS compat (web build only)
  properties: {
    r'downloadedAt': PropertySchema(
      id: 0,
      name: r'downloadedAt',
      type: IsarType.dateTime,
    ),
    r'expiresAt': PropertySchema(
      id: 1,
      name: r'expiresAt',
      type: IsarType.dateTime,
    ),
    r'isOffline': PropertySchema(
      id: 2,
      name: r'isOffline',
      type: IsarType.bool,
    ),
    r'maxLat': PropertySchema(
      id: 3,
      name: r'maxLat',
      type: IsarType.double,
    ),
    r'maxLng': PropertySchema(
      id: 4,
      name: r'maxLng',
      type: IsarType.double,
    ),
    r'minLat': PropertySchema(
      id: 5,
      name: r'minLat',
      type: IsarType.double,
    ),
    r'minLng': PropertySchema(
      id: 6,
      name: r'minLng',
      type: IsarType.double,
    ),
    r'name': PropertySchema(
      id: 7,
      name: r'name',
      type: IsarType.string,
    ),
    r'regionId': PropertySchema(
      id: 8,
      name: r'regionId',
      type: IsarType.string,
    ),
    r'sizeBytes': PropertySchema(
      id: 9,
      name: r'sizeBytes',
      type: IsarType.long,
    ),
    r'tileDataPath': PropertySchema(
      id: 10,
      name: r'tileDataPath',
      type: IsarType.string,
    ),
    r'zoomLevel': PropertySchema(
      id: 11,
      name: r'zoomLevel',
      type: IsarType.long,
    )
  },
  estimateSize: _mapRegionEstimateSize,
  serialize: _mapRegionSerialize,
  deserialize: _mapRegionDeserialize,
  deserializeProp: _mapRegionDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},
  getId: _mapRegionGetId,
  getLinks: _mapRegionGetLinks,
  attach: _mapRegionAttach,
  version: '3.1.0+1',
);

int _mapRegionEstimateSize(
  MapRegion object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.name;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.regionId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.tileDataPath;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _mapRegionSerialize(
  MapRegion object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.downloadedAt);
  writer.writeDateTime(offsets[1], object.expiresAt);
  writer.writeBool(offsets[2], object.isOffline);
  writer.writeDouble(offsets[3], object.maxLat);
  writer.writeDouble(offsets[4], object.maxLng);
  writer.writeDouble(offsets[5], object.minLat);
  writer.writeDouble(offsets[6], object.minLng);
  writer.writeString(offsets[7], object.name);
  writer.writeString(offsets[8], object.regionId);
  writer.writeLong(offsets[9], object.sizeBytes);
  writer.writeString(offsets[10], object.tileDataPath);
  writer.writeLong(offsets[11], object.zoomLevel);
}

MapRegion _mapRegionDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = MapRegion(
    downloadedAt: reader.readDateTimeOrNull(offsets[0]),
    expiresAt: reader.readDateTimeOrNull(offsets[1]),
    id: id,
    isOffline: reader.readBoolOrNull(offsets[2]),
    maxLat: reader.readDoubleOrNull(offsets[3]),
    maxLng: reader.readDoubleOrNull(offsets[4]),
    minLat: reader.readDoubleOrNull(offsets[5]),
    minLng: reader.readDoubleOrNull(offsets[6]),
    name: reader.readStringOrNull(offsets[7]),
    regionId: reader.readStringOrNull(offsets[8]),
    sizeBytes: reader.readLongOrNull(offsets[9]),
    tileDataPath: reader.readStringOrNull(offsets[10]),
    zoomLevel: reader.readLongOrNull(offsets[11]),
  );
  return object;
}

P _mapRegionDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 1:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 2:
      return (reader.readBoolOrNull(offset)) as P;
    case 3:
      return (reader.readDoubleOrNull(offset)) as P;
    case 4:
      return (reader.readDoubleOrNull(offset)) as P;
    case 5:
      return (reader.readDoubleOrNull(offset)) as P;
    case 6:
      return (reader.readDoubleOrNull(offset)) as P;
    case 7:
      return (reader.readStringOrNull(offset)) as P;
    case 8:
      return (reader.readStringOrNull(offset)) as P;
    case 9:
      return (reader.readLongOrNull(offset)) as P;
    case 10:
      return (reader.readStringOrNull(offset)) as P;
    case 11:
      return (reader.readLongOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _mapRegionGetId(MapRegion object) {
  return object.id ?? Isar.autoIncrement;
}

List<IsarLinkBase<dynamic>> _mapRegionGetLinks(MapRegion object) {
  return [];
}

void _mapRegionAttach(IsarCollection<dynamic> col, Id id, MapRegion object) {
  object.id = id;
}

extension MapRegionQueryWhereSort
    on QueryBuilder<MapRegion, MapRegion, QWhere> {
  QueryBuilder<MapRegion, MapRegion, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension MapRegionQueryWhere
    on QueryBuilder<MapRegion, MapRegion, QWhereClause> {
  QueryBuilder<MapRegion, MapRegion, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterWhereClause> idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterWhereClause> idGreaterThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension MapRegionQueryFilter
    on QueryBuilder<MapRegion, MapRegion, QFilterCondition> {
  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition>
      downloadedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'downloadedAt',
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition>
      downloadedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'downloadedAt',
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition> downloadedAtEqualTo(
      DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'downloadedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition>
      downloadedAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'downloadedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition>
      downloadedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'downloadedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition> downloadedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'downloadedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition> expiresAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'expiresAt',
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition>
      expiresAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'expiresAt',
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition> expiresAtEqualTo(
      DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'expiresAt',
        value: value,
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition>
      expiresAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'expiresAt',
        value: value,
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition> expiresAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'expiresAt',
        value: value,
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition> expiresAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'expiresAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition> idIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'id',
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition> idIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'id',
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition> idEqualTo(
      Id? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition> idGreaterThan(
    Id? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition> idLessThan(
    Id? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition> idBetween(
    Id? lower,
    Id? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition> isOfflineIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'isOffline',
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition>
      isOfflineIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'isOffline',
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition> isOfflineEqualTo(
      bool? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isOffline',
        value: value,
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition> maxLatIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'maxLat',
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition> maxLatIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'maxLat',
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition> maxLatEqualTo(
    double? value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'maxLat',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition> maxLatGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'maxLat',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition> maxLatLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'maxLat',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition> maxLatBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'maxLat',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition> maxLngIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'maxLng',
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition> maxLngIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'maxLng',
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition> maxLngEqualTo(
    double? value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'maxLng',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition> maxLngGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'maxLng',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition> maxLngLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'maxLng',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition> maxLngBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'maxLng',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition> minLatIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'minLat',
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition> minLatIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'minLat',
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition> minLatEqualTo(
    double? value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'minLat',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition> minLatGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'minLat',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition> minLatLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'minLat',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition> minLatBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'minLat',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition> minLngIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'minLng',
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition> minLngIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'minLng',
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition> minLngEqualTo(
    double? value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'minLng',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition> minLngGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'minLng',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition> minLngLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'minLng',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition> minLngBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'minLng',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition> nameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'name',
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition> nameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'name',
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition> nameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition> nameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition> nameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition> nameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'name',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition> nameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition> nameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition> nameContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition> nameMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'name',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition> nameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'name',
        value: '',
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition> nameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'name',
        value: '',
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition> regionIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'regionId',
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition>
      regionIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'regionId',
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition> regionIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'regionId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition> regionIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'regionId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition> regionIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'regionId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition> regionIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'regionId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition> regionIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'regionId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition> regionIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'regionId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition> regionIdContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'regionId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition> regionIdMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'regionId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition> regionIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'regionId',
        value: '',
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition>
      regionIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'regionId',
        value: '',
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition> sizeBytesIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'sizeBytes',
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition>
      sizeBytesIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'sizeBytes',
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition> sizeBytesEqualTo(
      int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sizeBytes',
        value: value,
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition>
      sizeBytesGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'sizeBytes',
        value: value,
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition> sizeBytesLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'sizeBytes',
        value: value,
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition> sizeBytesBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'sizeBytes',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition>
      tileDataPathIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'tileDataPath',
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition>
      tileDataPathIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'tileDataPath',
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition> tileDataPathEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'tileDataPath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition>
      tileDataPathGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'tileDataPath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition>
      tileDataPathLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'tileDataPath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition> tileDataPathBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'tileDataPath',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition>
      tileDataPathStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'tileDataPath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition>
      tileDataPathEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'tileDataPath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition>
      tileDataPathContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'tileDataPath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition> tileDataPathMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'tileDataPath',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition>
      tileDataPathIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'tileDataPath',
        value: '',
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition>
      tileDataPathIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'tileDataPath',
        value: '',
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition> zoomLevelIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'zoomLevel',
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition>
      zoomLevelIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'zoomLevel',
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition> zoomLevelEqualTo(
      int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'zoomLevel',
        value: value,
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition>
      zoomLevelGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'zoomLevel',
        value: value,
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition> zoomLevelLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'zoomLevel',
        value: value,
      ));
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterFilterCondition> zoomLevelBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'zoomLevel',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension MapRegionQueryObject
    on QueryBuilder<MapRegion, MapRegion, QFilterCondition> {}

extension MapRegionQueryLinks
    on QueryBuilder<MapRegion, MapRegion, QFilterCondition> {}

extension MapRegionQuerySortBy on QueryBuilder<MapRegion, MapRegion, QSortBy> {
  QueryBuilder<MapRegion, MapRegion, QAfterSortBy> sortByDownloadedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'downloadedAt', Sort.asc);
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterSortBy> sortByDownloadedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'downloadedAt', Sort.desc);
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterSortBy> sortByExpiresAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'expiresAt', Sort.asc);
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterSortBy> sortByExpiresAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'expiresAt', Sort.desc);
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterSortBy> sortByIsOffline() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isOffline', Sort.asc);
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterSortBy> sortByIsOfflineDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isOffline', Sort.desc);
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterSortBy> sortByMaxLat() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'maxLat', Sort.asc);
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterSortBy> sortByMaxLatDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'maxLat', Sort.desc);
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterSortBy> sortByMaxLng() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'maxLng', Sort.asc);
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterSortBy> sortByMaxLngDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'maxLng', Sort.desc);
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterSortBy> sortByMinLat() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'minLat', Sort.asc);
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterSortBy> sortByMinLatDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'minLat', Sort.desc);
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterSortBy> sortByMinLng() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'minLng', Sort.asc);
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterSortBy> sortByMinLngDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'minLng', Sort.desc);
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterSortBy> sortByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterSortBy> sortByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterSortBy> sortByRegionId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'regionId', Sort.asc);
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterSortBy> sortByRegionIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'regionId', Sort.desc);
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterSortBy> sortBySizeBytes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sizeBytes', Sort.asc);
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterSortBy> sortBySizeBytesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sizeBytes', Sort.desc);
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterSortBy> sortByTileDataPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tileDataPath', Sort.asc);
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterSortBy> sortByTileDataPathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tileDataPath', Sort.desc);
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterSortBy> sortByZoomLevel() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'zoomLevel', Sort.asc);
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterSortBy> sortByZoomLevelDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'zoomLevel', Sort.desc);
    });
  }
}

extension MapRegionQuerySortThenBy
    on QueryBuilder<MapRegion, MapRegion, QSortThenBy> {
  QueryBuilder<MapRegion, MapRegion, QAfterSortBy> thenByDownloadedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'downloadedAt', Sort.asc);
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterSortBy> thenByDownloadedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'downloadedAt', Sort.desc);
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterSortBy> thenByExpiresAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'expiresAt', Sort.asc);
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterSortBy> thenByExpiresAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'expiresAt', Sort.desc);
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterSortBy> thenByIsOffline() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isOffline', Sort.asc);
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterSortBy> thenByIsOfflineDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isOffline', Sort.desc);
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterSortBy> thenByMaxLat() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'maxLat', Sort.asc);
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterSortBy> thenByMaxLatDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'maxLat', Sort.desc);
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterSortBy> thenByMaxLng() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'maxLng', Sort.asc);
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterSortBy> thenByMaxLngDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'maxLng', Sort.desc);
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterSortBy> thenByMinLat() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'minLat', Sort.asc);
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterSortBy> thenByMinLatDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'minLat', Sort.desc);
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterSortBy> thenByMinLng() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'minLng', Sort.asc);
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterSortBy> thenByMinLngDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'minLng', Sort.desc);
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterSortBy> thenByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterSortBy> thenByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterSortBy> thenByRegionId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'regionId', Sort.asc);
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterSortBy> thenByRegionIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'regionId', Sort.desc);
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterSortBy> thenBySizeBytes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sizeBytes', Sort.asc);
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterSortBy> thenBySizeBytesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sizeBytes', Sort.desc);
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterSortBy> thenByTileDataPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tileDataPath', Sort.asc);
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterSortBy> thenByTileDataPathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tileDataPath', Sort.desc);
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterSortBy> thenByZoomLevel() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'zoomLevel', Sort.asc);
    });
  }

  QueryBuilder<MapRegion, MapRegion, QAfterSortBy> thenByZoomLevelDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'zoomLevel', Sort.desc);
    });
  }
}

extension MapRegionQueryWhereDistinct
    on QueryBuilder<MapRegion, MapRegion, QDistinct> {
  QueryBuilder<MapRegion, MapRegion, QDistinct> distinctByDownloadedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'downloadedAt');
    });
  }

  QueryBuilder<MapRegion, MapRegion, QDistinct> distinctByExpiresAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'expiresAt');
    });
  }

  QueryBuilder<MapRegion, MapRegion, QDistinct> distinctByIsOffline() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isOffline');
    });
  }

  QueryBuilder<MapRegion, MapRegion, QDistinct> distinctByMaxLat() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'maxLat');
    });
  }

  QueryBuilder<MapRegion, MapRegion, QDistinct> distinctByMaxLng() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'maxLng');
    });
  }

  QueryBuilder<MapRegion, MapRegion, QDistinct> distinctByMinLat() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'minLat');
    });
  }

  QueryBuilder<MapRegion, MapRegion, QDistinct> distinctByMinLng() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'minLng');
    });
  }

  QueryBuilder<MapRegion, MapRegion, QDistinct> distinctByName(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'name', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MapRegion, MapRegion, QDistinct> distinctByRegionId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'regionId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MapRegion, MapRegion, QDistinct> distinctBySizeBytes() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sizeBytes');
    });
  }

  QueryBuilder<MapRegion, MapRegion, QDistinct> distinctByTileDataPath(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'tileDataPath', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MapRegion, MapRegion, QDistinct> distinctByZoomLevel() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'zoomLevel');
    });
  }
}

extension MapRegionQueryProperty
    on QueryBuilder<MapRegion, MapRegion, QQueryProperty> {
  QueryBuilder<MapRegion, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<MapRegion, DateTime?, QQueryOperations> downloadedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'downloadedAt');
    });
  }

  QueryBuilder<MapRegion, DateTime?, QQueryOperations> expiresAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'expiresAt');
    });
  }

  QueryBuilder<MapRegion, bool?, QQueryOperations> isOfflineProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isOffline');
    });
  }

  QueryBuilder<MapRegion, double?, QQueryOperations> maxLatProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'maxLat');
    });
  }

  QueryBuilder<MapRegion, double?, QQueryOperations> maxLngProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'maxLng');
    });
  }

  QueryBuilder<MapRegion, double?, QQueryOperations> minLatProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'minLat');
    });
  }

  QueryBuilder<MapRegion, double?, QQueryOperations> minLngProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'minLng');
    });
  }

  QueryBuilder<MapRegion, String?, QQueryOperations> nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'name');
    });
  }

  QueryBuilder<MapRegion, String?, QQueryOperations> regionIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'regionId');
    });
  }

  QueryBuilder<MapRegion, int?, QQueryOperations> sizeBytesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sizeBytes');
    });
  }

  QueryBuilder<MapRegion, String?, QQueryOperations> tileDataPathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'tileDataPath');
    });
  }

  QueryBuilder<MapRegion, int?, QQueryOperations> zoomLevelProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'zoomLevel');
    });
  }
}
