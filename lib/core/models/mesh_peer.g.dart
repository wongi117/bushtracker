// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mesh_peer.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetMeshPeerCollection on Isar {
  IsarCollection<MeshPeer> get meshPeers => this.collection();
}

const MeshPeerSchema = CollectionSchema(
  name: r'MeshPeer',
  id: 5961093302063815327,
  properties: {
    r'deviceType': PropertySchema(
      id: 0,
      name: r'deviceType',
      type: IsarType.string,
    ),
    r'displayName': PropertySchema(
      id: 1,
      name: r'displayName',
      type: IsarType.string,
    ),
    r'firstSeen': PropertySchema(
      id: 2,
      name: r'firstSeen',
      type: IsarType.dateTime,
    ),
    r'isConnected': PropertySchema(
      id: 3,
      name: r'isConnected',
      type: IsarType.bool,
    ),
    r'lastAltitude': PropertySchema(
      id: 4,
      name: r'lastAltitude',
      type: IsarType.double,
    ),
    r'lastLatitude': PropertySchema(
      id: 5,
      name: r'lastLatitude',
      type: IsarType.double,
    ),
    r'lastLongitude': PropertySchema(
      id: 6,
      name: r'lastLongitude',
      type: IsarType.double,
    ),
    r'lastSeen': PropertySchema(
      id: 7,
      name: r'lastSeen',
      type: IsarType.dateTime,
    ),
    r'peerId': PropertySchema(
      id: 8,
      name: r'peerId',
      type: IsarType.string,
    ),
    r'publicKey': PropertySchema(
      id: 9,
      name: r'publicKey',
      type: IsarType.string,
    ),
    r'signalStrength': PropertySchema(
      id: 10,
      name: r'signalStrength',
      type: IsarType.long,
    )
  },
  estimateSize: _meshPeerEstimateSize,
  serialize: _meshPeerSerialize,
  deserialize: _meshPeerDeserialize,
  deserializeProp: _meshPeerDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},
  getId: _meshPeerGetId,
  getLinks: _meshPeerGetLinks,
  attach: _meshPeerAttach,
  version: '3.1.0+1',
);

int _meshPeerEstimateSize(
  MeshPeer object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.deviceType;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.displayName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.peerId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.publicKey;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _meshPeerSerialize(
  MeshPeer object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.deviceType);
  writer.writeString(offsets[1], object.displayName);
  writer.writeDateTime(offsets[2], object.firstSeen);
  writer.writeBool(offsets[3], object.isConnected);
  writer.writeDouble(offsets[4], object.lastAltitude);
  writer.writeDouble(offsets[5], object.lastLatitude);
  writer.writeDouble(offsets[6], object.lastLongitude);
  writer.writeDateTime(offsets[7], object.lastSeen);
  writer.writeString(offsets[8], object.peerId);
  writer.writeString(offsets[9], object.publicKey);
  writer.writeLong(offsets[10], object.signalStrength);
}

MeshPeer _meshPeerDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = MeshPeer(
    deviceType: reader.readStringOrNull(offsets[0]),
    displayName: reader.readStringOrNull(offsets[1]),
    firstSeen: reader.readDateTimeOrNull(offsets[2]),
    id: id,
    isConnected: reader.readBoolOrNull(offsets[3]),
    lastAltitude: reader.readDoubleOrNull(offsets[4]),
    lastLatitude: reader.readDoubleOrNull(offsets[5]),
    lastLongitude: reader.readDoubleOrNull(offsets[6]),
    lastSeen: reader.readDateTimeOrNull(offsets[7]),
    peerId: reader.readStringOrNull(offsets[8]),
    publicKey: reader.readStringOrNull(offsets[9]),
    signalStrength: reader.readLongOrNull(offsets[10]),
  );
  return object;
}

P _meshPeerDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readStringOrNull(offset)) as P;
    case 1:
      return (reader.readStringOrNull(offset)) as P;
    case 2:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 3:
      return (reader.readBoolOrNull(offset)) as P;
    case 4:
      return (reader.readDoubleOrNull(offset)) as P;
    case 5:
      return (reader.readDoubleOrNull(offset)) as P;
    case 6:
      return (reader.readDoubleOrNull(offset)) as P;
    case 7:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 8:
      return (reader.readStringOrNull(offset)) as P;
    case 9:
      return (reader.readStringOrNull(offset)) as P;
    case 10:
      return (reader.readLongOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _meshPeerGetId(MeshPeer object) {
  return object.id ?? Isar.autoIncrement;
}

List<IsarLinkBase<dynamic>> _meshPeerGetLinks(MeshPeer object) {
  return [];
}

void _meshPeerAttach(IsarCollection<dynamic> col, Id id, MeshPeer object) {
  object.id = id;
}

extension MeshPeerQueryWhereSort on QueryBuilder<MeshPeer, MeshPeer, QWhere> {
  QueryBuilder<MeshPeer, MeshPeer, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension MeshPeerQueryWhere on QueryBuilder<MeshPeer, MeshPeer, QWhereClause> {
  QueryBuilder<MeshPeer, MeshPeer, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterWhereClause> idNotEqualTo(Id id) {
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

  QueryBuilder<MeshPeer, MeshPeer, QAfterWhereClause> idGreaterThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterWhereClause> idBetween(
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

extension MeshPeerQueryFilter
    on QueryBuilder<MeshPeer, MeshPeer, QFilterCondition> {
  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition> deviceTypeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'deviceType',
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition>
      deviceTypeIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'deviceType',
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition> deviceTypeEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deviceType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition> deviceTypeGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'deviceType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition> deviceTypeLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'deviceType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition> deviceTypeBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'deviceType',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition> deviceTypeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'deviceType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition> deviceTypeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'deviceType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition> deviceTypeContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'deviceType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition> deviceTypeMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'deviceType',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition> deviceTypeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deviceType',
        value: '',
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition>
      deviceTypeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'deviceType',
        value: '',
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition> displayNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'displayName',
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition>
      displayNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'displayName',
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition> displayNameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'displayName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition>
      displayNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'displayName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition> displayNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'displayName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition> displayNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'displayName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition> displayNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'displayName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition> displayNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'displayName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition> displayNameContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'displayName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition> displayNameMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'displayName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition> displayNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'displayName',
        value: '',
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition>
      displayNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'displayName',
        value: '',
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition> firstSeenIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'firstSeen',
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition> firstSeenIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'firstSeen',
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition> firstSeenEqualTo(
      DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'firstSeen',
        value: value,
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition> firstSeenGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'firstSeen',
        value: value,
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition> firstSeenLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'firstSeen',
        value: value,
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition> firstSeenBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'firstSeen',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition> idIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'id',
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition> idIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'id',
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition> idEqualTo(Id? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition> idGreaterThan(
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

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition> idLessThan(
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

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition> idBetween(
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

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition> isConnectedIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'isConnected',
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition>
      isConnectedIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'isConnected',
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition> isConnectedEqualTo(
      bool? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isConnected',
        value: value,
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition> lastAltitudeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'lastAltitude',
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition>
      lastAltitudeIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'lastAltitude',
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition> lastAltitudeEqualTo(
    double? value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastAltitude',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition>
      lastAltitudeGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lastAltitude',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition> lastAltitudeLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lastAltitude',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition> lastAltitudeBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lastAltitude',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition> lastLatitudeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'lastLatitude',
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition>
      lastLatitudeIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'lastLatitude',
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition> lastLatitudeEqualTo(
    double? value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastLatitude',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition>
      lastLatitudeGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lastLatitude',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition> lastLatitudeLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lastLatitude',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition> lastLatitudeBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lastLatitude',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition>
      lastLongitudeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'lastLongitude',
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition>
      lastLongitudeIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'lastLongitude',
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition> lastLongitudeEqualTo(
    double? value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastLongitude',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition>
      lastLongitudeGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lastLongitude',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition> lastLongitudeLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lastLongitude',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition> lastLongitudeBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lastLongitude',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition> lastSeenIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'lastSeen',
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition> lastSeenIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'lastSeen',
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition> lastSeenEqualTo(
      DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastSeen',
        value: value,
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition> lastSeenGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lastSeen',
        value: value,
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition> lastSeenLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lastSeen',
        value: value,
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition> lastSeenBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lastSeen',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition> peerIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'peerId',
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition> peerIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'peerId',
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition> peerIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'peerId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition> peerIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'peerId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition> peerIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'peerId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition> peerIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'peerId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition> peerIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'peerId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition> peerIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'peerId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition> peerIdContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'peerId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition> peerIdMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'peerId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition> peerIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'peerId',
        value: '',
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition> peerIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'peerId',
        value: '',
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition> publicKeyIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'publicKey',
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition> publicKeyIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'publicKey',
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition> publicKeyEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'publicKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition> publicKeyGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'publicKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition> publicKeyLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'publicKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition> publicKeyBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'publicKey',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition> publicKeyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'publicKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition> publicKeyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'publicKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition> publicKeyContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'publicKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition> publicKeyMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'publicKey',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition> publicKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'publicKey',
        value: '',
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition>
      publicKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'publicKey',
        value: '',
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition>
      signalStrengthIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'signalStrength',
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition>
      signalStrengthIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'signalStrength',
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition> signalStrengthEqualTo(
      int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'signalStrength',
        value: value,
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition>
      signalStrengthGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'signalStrength',
        value: value,
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition>
      signalStrengthLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'signalStrength',
        value: value,
      ));
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterFilterCondition> signalStrengthBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'signalStrength',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension MeshPeerQueryObject
    on QueryBuilder<MeshPeer, MeshPeer, QFilterCondition> {}

extension MeshPeerQueryLinks
    on QueryBuilder<MeshPeer, MeshPeer, QFilterCondition> {}

extension MeshPeerQuerySortBy on QueryBuilder<MeshPeer, MeshPeer, QSortBy> {
  QueryBuilder<MeshPeer, MeshPeer, QAfterSortBy> sortByDeviceType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deviceType', Sort.asc);
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterSortBy> sortByDeviceTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deviceType', Sort.desc);
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterSortBy> sortByDisplayName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'displayName', Sort.asc);
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterSortBy> sortByDisplayNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'displayName', Sort.desc);
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterSortBy> sortByFirstSeen() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firstSeen', Sort.asc);
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterSortBy> sortByFirstSeenDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firstSeen', Sort.desc);
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterSortBy> sortByIsConnected() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isConnected', Sort.asc);
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterSortBy> sortByIsConnectedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isConnected', Sort.desc);
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterSortBy> sortByLastAltitude() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastAltitude', Sort.asc);
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterSortBy> sortByLastAltitudeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastAltitude', Sort.desc);
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterSortBy> sortByLastLatitude() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastLatitude', Sort.asc);
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterSortBy> sortByLastLatitudeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastLatitude', Sort.desc);
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterSortBy> sortByLastLongitude() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastLongitude', Sort.asc);
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterSortBy> sortByLastLongitudeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastLongitude', Sort.desc);
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterSortBy> sortByLastSeen() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSeen', Sort.asc);
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterSortBy> sortByLastSeenDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSeen', Sort.desc);
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterSortBy> sortByPeerId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'peerId', Sort.asc);
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterSortBy> sortByPeerIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'peerId', Sort.desc);
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterSortBy> sortByPublicKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'publicKey', Sort.asc);
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterSortBy> sortByPublicKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'publicKey', Sort.desc);
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterSortBy> sortBySignalStrength() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'signalStrength', Sort.asc);
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterSortBy> sortBySignalStrengthDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'signalStrength', Sort.desc);
    });
  }
}

extension MeshPeerQuerySortThenBy
    on QueryBuilder<MeshPeer, MeshPeer, QSortThenBy> {
  QueryBuilder<MeshPeer, MeshPeer, QAfterSortBy> thenByDeviceType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deviceType', Sort.asc);
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterSortBy> thenByDeviceTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deviceType', Sort.desc);
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterSortBy> thenByDisplayName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'displayName', Sort.asc);
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterSortBy> thenByDisplayNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'displayName', Sort.desc);
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterSortBy> thenByFirstSeen() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firstSeen', Sort.asc);
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterSortBy> thenByFirstSeenDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firstSeen', Sort.desc);
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterSortBy> thenByIsConnected() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isConnected', Sort.asc);
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterSortBy> thenByIsConnectedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isConnected', Sort.desc);
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterSortBy> thenByLastAltitude() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastAltitude', Sort.asc);
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterSortBy> thenByLastAltitudeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastAltitude', Sort.desc);
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterSortBy> thenByLastLatitude() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastLatitude', Sort.asc);
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterSortBy> thenByLastLatitudeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastLatitude', Sort.desc);
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterSortBy> thenByLastLongitude() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastLongitude', Sort.asc);
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterSortBy> thenByLastLongitudeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastLongitude', Sort.desc);
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterSortBy> thenByLastSeen() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSeen', Sort.asc);
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterSortBy> thenByLastSeenDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSeen', Sort.desc);
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterSortBy> thenByPeerId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'peerId', Sort.asc);
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterSortBy> thenByPeerIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'peerId', Sort.desc);
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterSortBy> thenByPublicKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'publicKey', Sort.asc);
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterSortBy> thenByPublicKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'publicKey', Sort.desc);
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterSortBy> thenBySignalStrength() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'signalStrength', Sort.asc);
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QAfterSortBy> thenBySignalStrengthDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'signalStrength', Sort.desc);
    });
  }
}

extension MeshPeerQueryWhereDistinct
    on QueryBuilder<MeshPeer, MeshPeer, QDistinct> {
  QueryBuilder<MeshPeer, MeshPeer, QDistinct> distinctByDeviceType(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'deviceType', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QDistinct> distinctByDisplayName(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'displayName', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QDistinct> distinctByFirstSeen() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'firstSeen');
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QDistinct> distinctByIsConnected() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isConnected');
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QDistinct> distinctByLastAltitude() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastAltitude');
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QDistinct> distinctByLastLatitude() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastLatitude');
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QDistinct> distinctByLastLongitude() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastLongitude');
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QDistinct> distinctByLastSeen() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastSeen');
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QDistinct> distinctByPeerId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'peerId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QDistinct> distinctByPublicKey(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'publicKey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MeshPeer, MeshPeer, QDistinct> distinctBySignalStrength() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'signalStrength');
    });
  }
}

extension MeshPeerQueryProperty
    on QueryBuilder<MeshPeer, MeshPeer, QQueryProperty> {
  QueryBuilder<MeshPeer, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<MeshPeer, String?, QQueryOperations> deviceTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deviceType');
    });
  }

  QueryBuilder<MeshPeer, String?, QQueryOperations> displayNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'displayName');
    });
  }

  QueryBuilder<MeshPeer, DateTime?, QQueryOperations> firstSeenProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'firstSeen');
    });
  }

  QueryBuilder<MeshPeer, bool?, QQueryOperations> isConnectedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isConnected');
    });
  }

  QueryBuilder<MeshPeer, double?, QQueryOperations> lastAltitudeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastAltitude');
    });
  }

  QueryBuilder<MeshPeer, double?, QQueryOperations> lastLatitudeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastLatitude');
    });
  }

  QueryBuilder<MeshPeer, double?, QQueryOperations> lastLongitudeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastLongitude');
    });
  }

  QueryBuilder<MeshPeer, DateTime?, QQueryOperations> lastSeenProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastSeen');
    });
  }

  QueryBuilder<MeshPeer, String?, QQueryOperations> peerIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'peerId');
    });
  }

  QueryBuilder<MeshPeer, String?, QQueryOperations> publicKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'publicKey');
    });
  }

  QueryBuilder<MeshPeer, int?, QQueryOperations> signalStrengthProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'signalStrength');
    });
  }
}
