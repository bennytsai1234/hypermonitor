// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data_model.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetHyperDataCollection on Isar {
  IsarCollection<HyperData> get hyperDatas => this.collection();
}

const HyperDataSchema = CollectionSchema(
  name: r'HyperData',
  id: 5613103073810397301,
  properties: {
    r'btc': PropertySchema(
      id: 0,
      name: r'btc',
      type: IsarType.object,
      target: r'CoinPosition',
    ),
    r'eth': PropertySchema(
      id: 1,
      name: r'eth',
      type: IsarType.object,
      target: r'CoinPosition',
    ),
    r'longVolDisplay': PropertySchema(
      id: 2,
      name: r'longVolDisplay',
      type: IsarType.string,
    ),
    r'longVolNum': PropertySchema(
      id: 3,
      name: r'longVolNum',
      type: IsarType.double,
    ),
    r'lossCount': PropertySchema(
      id: 4,
      name: r'lossCount',
      type: IsarType.long,
    ),
    r'netVolDisplay': PropertySchema(
      id: 5,
      name: r'netVolDisplay',
      type: IsarType.string,
    ),
    r'netVolNum': PropertySchema(
      id: 6,
      name: r'netVolNum',
      type: IsarType.double,
    ),
    r'openPositionCount': PropertySchema(
      id: 7,
      name: r'openPositionCount',
      type: IsarType.long,
    ),
    r'openPositionPct': PropertySchema(
      id: 8,
      name: r'openPositionPct',
      type: IsarType.string,
    ),
    r'profitCount': PropertySchema(
      id: 9,
      name: r'profitCount',
      type: IsarType.long,
    ),
    r'sentiment': PropertySchema(
      id: 10,
      name: r'sentiment',
      type: IsarType.string,
    ),
    r'shortVolDisplay': PropertySchema(
      id: 11,
      name: r'shortVolDisplay',
      type: IsarType.string,
    ),
    r'shortVolNum': PropertySchema(
      id: 12,
      name: r'shortVolNum',
      type: IsarType.double,
    ),
    r'timestamp': PropertySchema(
      id: 13,
      name: r'timestamp',
      type: IsarType.dateTime,
    ),
    r'walletCount': PropertySchema(
      id: 14,
      name: r'walletCount',
      type: IsarType.long,
    )
  },
  estimateSize: _hyperDataEstimateSize,
  serialize: _hyperDataSerialize,
  deserialize: _hyperDataDeserialize,
  deserializeProp: _hyperDataDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {r'CoinPosition': CoinPositionSchema},
  getId: _hyperDataGetId,
  getLinks: _hyperDataGetLinks,
  attach: _hyperDataAttach,
  version: '3.1.0+1',
);

int _hyperDataEstimateSize(
  HyperData object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.btc;
    if (value != null) {
      bytesCount += 3 +
          CoinPositionSchema.estimateSize(
              value, allOffsets[CoinPosition]!, allOffsets);
    }
  }
  {
    final value = object.eth;
    if (value != null) {
      bytesCount += 3 +
          CoinPositionSchema.estimateSize(
              value, allOffsets[CoinPosition]!, allOffsets);
    }
  }
  bytesCount += 3 + object.longVolDisplay.length * 3;
  bytesCount += 3 + object.netVolDisplay.length * 3;
  bytesCount += 3 + object.openPositionPct.length * 3;
  bytesCount += 3 + object.sentiment.length * 3;
  bytesCount += 3 + object.shortVolDisplay.length * 3;
  return bytesCount;
}

void _hyperDataSerialize(
  HyperData object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeObject<CoinPosition>(
    offsets[0],
    allOffsets,
    CoinPositionSchema.serialize,
    object.btc,
  );
  writer.writeObject<CoinPosition>(
    offsets[1],
    allOffsets,
    CoinPositionSchema.serialize,
    object.eth,
  );
  writer.writeString(offsets[2], object.longVolDisplay);
  writer.writeDouble(offsets[3], object.longVolNum);
  writer.writeLong(offsets[4], object.lossCount);
  writer.writeString(offsets[5], object.netVolDisplay);
  writer.writeDouble(offsets[6], object.netVolNum);
  writer.writeLong(offsets[7], object.openPositionCount);
  writer.writeString(offsets[8], object.openPositionPct);
  writer.writeLong(offsets[9], object.profitCount);
  writer.writeString(offsets[10], object.sentiment);
  writer.writeString(offsets[11], object.shortVolDisplay);
  writer.writeDouble(offsets[12], object.shortVolNum);
  writer.writeDateTime(offsets[13], object.timestamp);
  writer.writeLong(offsets[14], object.walletCount);
}

HyperData _hyperDataDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = HyperData(
    btc: reader.readObjectOrNull<CoinPosition>(
      offsets[0],
      CoinPositionSchema.deserialize,
      allOffsets,
    ),
    eth: reader.readObjectOrNull<CoinPosition>(
      offsets[1],
      CoinPositionSchema.deserialize,
      allOffsets,
    ),
    longVolDisplay: reader.readString(offsets[2]),
    longVolNum: reader.readDouble(offsets[3]),
    lossCount: reader.readLong(offsets[4]),
    netVolDisplay: reader.readString(offsets[5]),
    netVolNum: reader.readDouble(offsets[6]),
    openPositionCount: reader.readLong(offsets[7]),
    openPositionPct: reader.readString(offsets[8]),
    profitCount: reader.readLong(offsets[9]),
    sentiment: reader.readString(offsets[10]),
    shortVolDisplay: reader.readString(offsets[11]),
    shortVolNum: reader.readDouble(offsets[12]),
    timestamp: reader.readDateTime(offsets[13]),
    walletCount: reader.readLong(offsets[14]),
  );
  object.id = id;
  return object;
}

P _hyperDataDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readObjectOrNull<CoinPosition>(
        offset,
        CoinPositionSchema.deserialize,
        allOffsets,
      )) as P;
    case 1:
      return (reader.readObjectOrNull<CoinPosition>(
        offset,
        CoinPositionSchema.deserialize,
        allOffsets,
      )) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readDouble(offset)) as P;
    case 4:
      return (reader.readLong(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    case 6:
      return (reader.readDouble(offset)) as P;
    case 7:
      return (reader.readLong(offset)) as P;
    case 8:
      return (reader.readString(offset)) as P;
    case 9:
      return (reader.readLong(offset)) as P;
    case 10:
      return (reader.readString(offset)) as P;
    case 11:
      return (reader.readString(offset)) as P;
    case 12:
      return (reader.readDouble(offset)) as P;
    case 13:
      return (reader.readDateTime(offset)) as P;
    case 14:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _hyperDataGetId(HyperData object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _hyperDataGetLinks(HyperData object) {
  return [];
}

void _hyperDataAttach(IsarCollection<dynamic> col, Id id, HyperData object) {
  object.id = id;
}

extension HyperDataQueryWhereSort
    on QueryBuilder<HyperData, HyperData, QWhere> {
  QueryBuilder<HyperData, HyperData, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension HyperDataQueryWhere
    on QueryBuilder<HyperData, HyperData, QWhereClause> {
  QueryBuilder<HyperData, HyperData, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterWhereClause> idNotEqualTo(Id id) {
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

  QueryBuilder<HyperData, HyperData, QAfterWhereClause> idGreaterThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterWhereClause> idBetween(
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

extension HyperDataQueryFilter
    on QueryBuilder<HyperData, HyperData, QFilterCondition> {
  QueryBuilder<HyperData, HyperData, QAfterFilterCondition> btcIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'btc',
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition> btcIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'btc',
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition> ethIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'eth',
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition> ethIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'eth',
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition> idGreaterThan(
    Id value, {
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

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition> idLessThan(
    Id value, {
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

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
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

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition>
      longVolDisplayEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'longVolDisplay',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition>
      longVolDisplayGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'longVolDisplay',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition>
      longVolDisplayLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'longVolDisplay',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition>
      longVolDisplayBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'longVolDisplay',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition>
      longVolDisplayStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'longVolDisplay',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition>
      longVolDisplayEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'longVolDisplay',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition>
      longVolDisplayContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'longVolDisplay',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition>
      longVolDisplayMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'longVolDisplay',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition>
      longVolDisplayIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'longVolDisplay',
        value: '',
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition>
      longVolDisplayIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'longVolDisplay',
        value: '',
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition> longVolNumEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'longVolNum',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition>
      longVolNumGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'longVolNum',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition> longVolNumLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'longVolNum',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition> longVolNumBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'longVolNum',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition> lossCountEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lossCount',
        value: value,
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition>
      lossCountGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lossCount',
        value: value,
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition> lossCountLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lossCount',
        value: value,
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition> lossCountBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lossCount',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition>
      netVolDisplayEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'netVolDisplay',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition>
      netVolDisplayGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'netVolDisplay',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition>
      netVolDisplayLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'netVolDisplay',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition>
      netVolDisplayBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'netVolDisplay',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition>
      netVolDisplayStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'netVolDisplay',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition>
      netVolDisplayEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'netVolDisplay',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition>
      netVolDisplayContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'netVolDisplay',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition>
      netVolDisplayMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'netVolDisplay',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition>
      netVolDisplayIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'netVolDisplay',
        value: '',
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition>
      netVolDisplayIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'netVolDisplay',
        value: '',
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition> netVolNumEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'netVolNum',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition>
      netVolNumGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'netVolNum',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition> netVolNumLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'netVolNum',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition> netVolNumBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'netVolNum',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition>
      openPositionCountEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'openPositionCount',
        value: value,
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition>
      openPositionCountGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'openPositionCount',
        value: value,
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition>
      openPositionCountLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'openPositionCount',
        value: value,
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition>
      openPositionCountBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'openPositionCount',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition>
      openPositionPctEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'openPositionPct',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition>
      openPositionPctGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'openPositionPct',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition>
      openPositionPctLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'openPositionPct',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition>
      openPositionPctBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'openPositionPct',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition>
      openPositionPctStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'openPositionPct',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition>
      openPositionPctEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'openPositionPct',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition>
      openPositionPctContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'openPositionPct',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition>
      openPositionPctMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'openPositionPct',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition>
      openPositionPctIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'openPositionPct',
        value: '',
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition>
      openPositionPctIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'openPositionPct',
        value: '',
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition> profitCountEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'profitCount',
        value: value,
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition>
      profitCountGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'profitCount',
        value: value,
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition> profitCountLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'profitCount',
        value: value,
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition> profitCountBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'profitCount',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition> sentimentEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sentiment',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition>
      sentimentGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'sentiment',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition> sentimentLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'sentiment',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition> sentimentBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'sentiment',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition> sentimentStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'sentiment',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition> sentimentEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'sentiment',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition> sentimentContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'sentiment',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition> sentimentMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'sentiment',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition> sentimentIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sentiment',
        value: '',
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition>
      sentimentIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'sentiment',
        value: '',
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition>
      shortVolDisplayEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'shortVolDisplay',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition>
      shortVolDisplayGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'shortVolDisplay',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition>
      shortVolDisplayLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'shortVolDisplay',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition>
      shortVolDisplayBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'shortVolDisplay',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition>
      shortVolDisplayStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'shortVolDisplay',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition>
      shortVolDisplayEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'shortVolDisplay',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition>
      shortVolDisplayContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'shortVolDisplay',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition>
      shortVolDisplayMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'shortVolDisplay',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition>
      shortVolDisplayIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'shortVolDisplay',
        value: '',
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition>
      shortVolDisplayIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'shortVolDisplay',
        value: '',
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition> shortVolNumEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'shortVolNum',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition>
      shortVolNumGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'shortVolNum',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition> shortVolNumLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'shortVolNum',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition> shortVolNumBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'shortVolNum',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition> timestampEqualTo(
      DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'timestamp',
        value: value,
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition>
      timestampGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'timestamp',
        value: value,
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition> timestampLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'timestamp',
        value: value,
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition> timestampBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'timestamp',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition> walletCountEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'walletCount',
        value: value,
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition>
      walletCountGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'walletCount',
        value: value,
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition> walletCountLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'walletCount',
        value: value,
      ));
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition> walletCountBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'walletCount',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension HyperDataQueryObject
    on QueryBuilder<HyperData, HyperData, QFilterCondition> {
  QueryBuilder<HyperData, HyperData, QAfterFilterCondition> btc(
      FilterQuery<CoinPosition> q) {
    return QueryBuilder.apply(this, (query) {
      return query.object(q, r'btc');
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterFilterCondition> eth(
      FilterQuery<CoinPosition> q) {
    return QueryBuilder.apply(this, (query) {
      return query.object(q, r'eth');
    });
  }
}

extension HyperDataQueryLinks
    on QueryBuilder<HyperData, HyperData, QFilterCondition> {}

extension HyperDataQuerySortBy on QueryBuilder<HyperData, HyperData, QSortBy> {
  QueryBuilder<HyperData, HyperData, QAfterSortBy> sortByLongVolDisplay() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'longVolDisplay', Sort.asc);
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterSortBy> sortByLongVolDisplayDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'longVolDisplay', Sort.desc);
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterSortBy> sortByLongVolNum() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'longVolNum', Sort.asc);
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterSortBy> sortByLongVolNumDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'longVolNum', Sort.desc);
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterSortBy> sortByLossCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lossCount', Sort.asc);
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterSortBy> sortByLossCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lossCount', Sort.desc);
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterSortBy> sortByNetVolDisplay() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'netVolDisplay', Sort.asc);
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterSortBy> sortByNetVolDisplayDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'netVolDisplay', Sort.desc);
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterSortBy> sortByNetVolNum() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'netVolNum', Sort.asc);
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterSortBy> sortByNetVolNumDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'netVolNum', Sort.desc);
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterSortBy> sortByOpenPositionCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'openPositionCount', Sort.asc);
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterSortBy>
      sortByOpenPositionCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'openPositionCount', Sort.desc);
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterSortBy> sortByOpenPositionPct() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'openPositionPct', Sort.asc);
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterSortBy> sortByOpenPositionPctDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'openPositionPct', Sort.desc);
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterSortBy> sortByProfitCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'profitCount', Sort.asc);
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterSortBy> sortByProfitCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'profitCount', Sort.desc);
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterSortBy> sortBySentiment() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sentiment', Sort.asc);
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterSortBy> sortBySentimentDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sentiment', Sort.desc);
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterSortBy> sortByShortVolDisplay() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'shortVolDisplay', Sort.asc);
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterSortBy> sortByShortVolDisplayDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'shortVolDisplay', Sort.desc);
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterSortBy> sortByShortVolNum() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'shortVolNum', Sort.asc);
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterSortBy> sortByShortVolNumDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'shortVolNum', Sort.desc);
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterSortBy> sortByTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.asc);
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterSortBy> sortByTimestampDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.desc);
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterSortBy> sortByWalletCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'walletCount', Sort.asc);
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterSortBy> sortByWalletCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'walletCount', Sort.desc);
    });
  }
}

extension HyperDataQuerySortThenBy
    on QueryBuilder<HyperData, HyperData, QSortThenBy> {
  QueryBuilder<HyperData, HyperData, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterSortBy> thenByLongVolDisplay() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'longVolDisplay', Sort.asc);
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterSortBy> thenByLongVolDisplayDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'longVolDisplay', Sort.desc);
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterSortBy> thenByLongVolNum() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'longVolNum', Sort.asc);
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterSortBy> thenByLongVolNumDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'longVolNum', Sort.desc);
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterSortBy> thenByLossCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lossCount', Sort.asc);
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterSortBy> thenByLossCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lossCount', Sort.desc);
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterSortBy> thenByNetVolDisplay() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'netVolDisplay', Sort.asc);
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterSortBy> thenByNetVolDisplayDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'netVolDisplay', Sort.desc);
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterSortBy> thenByNetVolNum() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'netVolNum', Sort.asc);
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterSortBy> thenByNetVolNumDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'netVolNum', Sort.desc);
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterSortBy> thenByOpenPositionCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'openPositionCount', Sort.asc);
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterSortBy>
      thenByOpenPositionCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'openPositionCount', Sort.desc);
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterSortBy> thenByOpenPositionPct() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'openPositionPct', Sort.asc);
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterSortBy> thenByOpenPositionPctDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'openPositionPct', Sort.desc);
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterSortBy> thenByProfitCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'profitCount', Sort.asc);
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterSortBy> thenByProfitCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'profitCount', Sort.desc);
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterSortBy> thenBySentiment() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sentiment', Sort.asc);
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterSortBy> thenBySentimentDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sentiment', Sort.desc);
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterSortBy> thenByShortVolDisplay() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'shortVolDisplay', Sort.asc);
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterSortBy> thenByShortVolDisplayDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'shortVolDisplay', Sort.desc);
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterSortBy> thenByShortVolNum() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'shortVolNum', Sort.asc);
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterSortBy> thenByShortVolNumDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'shortVolNum', Sort.desc);
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterSortBy> thenByTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.asc);
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterSortBy> thenByTimestampDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.desc);
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterSortBy> thenByWalletCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'walletCount', Sort.asc);
    });
  }

  QueryBuilder<HyperData, HyperData, QAfterSortBy> thenByWalletCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'walletCount', Sort.desc);
    });
  }
}

extension HyperDataQueryWhereDistinct
    on QueryBuilder<HyperData, HyperData, QDistinct> {
  QueryBuilder<HyperData, HyperData, QDistinct> distinctByLongVolDisplay(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'longVolDisplay',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<HyperData, HyperData, QDistinct> distinctByLongVolNum() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'longVolNum');
    });
  }

  QueryBuilder<HyperData, HyperData, QDistinct> distinctByLossCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lossCount');
    });
  }

  QueryBuilder<HyperData, HyperData, QDistinct> distinctByNetVolDisplay(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'netVolDisplay',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<HyperData, HyperData, QDistinct> distinctByNetVolNum() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'netVolNum');
    });
  }

  QueryBuilder<HyperData, HyperData, QDistinct> distinctByOpenPositionCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'openPositionCount');
    });
  }

  QueryBuilder<HyperData, HyperData, QDistinct> distinctByOpenPositionPct(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'openPositionPct',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<HyperData, HyperData, QDistinct> distinctByProfitCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'profitCount');
    });
  }

  QueryBuilder<HyperData, HyperData, QDistinct> distinctBySentiment(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sentiment', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<HyperData, HyperData, QDistinct> distinctByShortVolDisplay(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'shortVolDisplay',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<HyperData, HyperData, QDistinct> distinctByShortVolNum() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'shortVolNum');
    });
  }

  QueryBuilder<HyperData, HyperData, QDistinct> distinctByTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'timestamp');
    });
  }

  QueryBuilder<HyperData, HyperData, QDistinct> distinctByWalletCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'walletCount');
    });
  }
}

extension HyperDataQueryProperty
    on QueryBuilder<HyperData, HyperData, QQueryProperty> {
  QueryBuilder<HyperData, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<HyperData, CoinPosition?, QQueryOperations> btcProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'btc');
    });
  }

  QueryBuilder<HyperData, CoinPosition?, QQueryOperations> ethProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'eth');
    });
  }

  QueryBuilder<HyperData, String, QQueryOperations> longVolDisplayProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'longVolDisplay');
    });
  }

  QueryBuilder<HyperData, double, QQueryOperations> longVolNumProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'longVolNum');
    });
  }

  QueryBuilder<HyperData, int, QQueryOperations> lossCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lossCount');
    });
  }

  QueryBuilder<HyperData, String, QQueryOperations> netVolDisplayProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'netVolDisplay');
    });
  }

  QueryBuilder<HyperData, double, QQueryOperations> netVolNumProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'netVolNum');
    });
  }

  QueryBuilder<HyperData, int, QQueryOperations> openPositionCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'openPositionCount');
    });
  }

  QueryBuilder<HyperData, String, QQueryOperations> openPositionPctProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'openPositionPct');
    });
  }

  QueryBuilder<HyperData, int, QQueryOperations> profitCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'profitCount');
    });
  }

  QueryBuilder<HyperData, String, QQueryOperations> sentimentProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sentiment');
    });
  }

  QueryBuilder<HyperData, String, QQueryOperations> shortVolDisplayProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'shortVolDisplay');
    });
  }

  QueryBuilder<HyperData, double, QQueryOperations> shortVolNumProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'shortVolNum');
    });
  }

  QueryBuilder<HyperData, DateTime, QQueryOperations> timestampProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'timestamp');
    });
  }

  QueryBuilder<HyperData, int, QQueryOperations> walletCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'walletCount');
    });
  }
}

// **************************************************************************
// IsarEmbeddedGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

const CoinPositionSchema = Schema(
  name: r'CoinPosition',
  id: -6544638894819215014,
  properties: {
    r'longDisplay': PropertySchema(
      id: 0,
      name: r'longDisplay',
      type: IsarType.string,
    ),
    r'longVol': PropertySchema(
      id: 1,
      name: r'longVol',
      type: IsarType.double,
    ),
    r'netDisplay': PropertySchema(
      id: 2,
      name: r'netDisplay',
      type: IsarType.string,
    ),
    r'netVol': PropertySchema(
      id: 3,
      name: r'netVol',
      type: IsarType.double,
    ),
    r'shortDisplay': PropertySchema(
      id: 4,
      name: r'shortDisplay',
      type: IsarType.string,
    ),
    r'shortVol': PropertySchema(
      id: 5,
      name: r'shortVol',
      type: IsarType.double,
    ),
    r'symbol': PropertySchema(
      id: 6,
      name: r'symbol',
      type: IsarType.string,
    ),
    r'totalDisplay': PropertySchema(
      id: 7,
      name: r'totalDisplay',
      type: IsarType.string,
    ),
    r'totalVol': PropertySchema(
      id: 8,
      name: r'totalVol',
      type: IsarType.double,
    )
  },
  estimateSize: _coinPositionEstimateSize,
  serialize: _coinPositionSerialize,
  deserialize: _coinPositionDeserialize,
  deserializeProp: _coinPositionDeserializeProp,
);

int _coinPositionEstimateSize(
  CoinPosition object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.longDisplay;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.netDisplay;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.shortDisplay;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.symbol;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.totalDisplay;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _coinPositionSerialize(
  CoinPosition object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.longDisplay);
  writer.writeDouble(offsets[1], object.longVol);
  writer.writeString(offsets[2], object.netDisplay);
  writer.writeDouble(offsets[3], object.netVol);
  writer.writeString(offsets[4], object.shortDisplay);
  writer.writeDouble(offsets[5], object.shortVol);
  writer.writeString(offsets[6], object.symbol);
  writer.writeString(offsets[7], object.totalDisplay);
  writer.writeDouble(offsets[8], object.totalVol);
}

CoinPosition _coinPositionDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = CoinPosition(
    longDisplay: reader.readStringOrNull(offsets[0]),
    longVol: reader.readDoubleOrNull(offsets[1]),
    netDisplay: reader.readStringOrNull(offsets[2]),
    netVol: reader.readDoubleOrNull(offsets[3]),
    shortDisplay: reader.readStringOrNull(offsets[4]),
    shortVol: reader.readDoubleOrNull(offsets[5]),
    symbol: reader.readStringOrNull(offsets[6]),
    totalDisplay: reader.readStringOrNull(offsets[7]),
    totalVol: reader.readDoubleOrNull(offsets[8]),
  );
  return object;
}

P _coinPositionDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readStringOrNull(offset)) as P;
    case 1:
      return (reader.readDoubleOrNull(offset)) as P;
    case 2:
      return (reader.readStringOrNull(offset)) as P;
    case 3:
      return (reader.readDoubleOrNull(offset)) as P;
    case 4:
      return (reader.readStringOrNull(offset)) as P;
    case 5:
      return (reader.readDoubleOrNull(offset)) as P;
    case 6:
      return (reader.readStringOrNull(offset)) as P;
    case 7:
      return (reader.readStringOrNull(offset)) as P;
    case 8:
      return (reader.readDoubleOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

extension CoinPositionQueryFilter
    on QueryBuilder<CoinPosition, CoinPosition, QFilterCondition> {
  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      longDisplayIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'longDisplay',
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      longDisplayIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'longDisplay',
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      longDisplayEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'longDisplay',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      longDisplayGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'longDisplay',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      longDisplayLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'longDisplay',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      longDisplayBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'longDisplay',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      longDisplayStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'longDisplay',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      longDisplayEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'longDisplay',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      longDisplayContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'longDisplay',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      longDisplayMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'longDisplay',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      longDisplayIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'longDisplay',
        value: '',
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      longDisplayIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'longDisplay',
        value: '',
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      longVolIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'longVol',
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      longVolIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'longVol',
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      longVolEqualTo(
    double? value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'longVol',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      longVolGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'longVol',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      longVolLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'longVol',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      longVolBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'longVol',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      netDisplayIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'netDisplay',
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      netDisplayIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'netDisplay',
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      netDisplayEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'netDisplay',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      netDisplayGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'netDisplay',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      netDisplayLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'netDisplay',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      netDisplayBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'netDisplay',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      netDisplayStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'netDisplay',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      netDisplayEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'netDisplay',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      netDisplayContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'netDisplay',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      netDisplayMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'netDisplay',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      netDisplayIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'netDisplay',
        value: '',
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      netDisplayIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'netDisplay',
        value: '',
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      netVolIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'netVol',
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      netVolIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'netVol',
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition> netVolEqualTo(
    double? value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'netVol',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      netVolGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'netVol',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      netVolLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'netVol',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition> netVolBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'netVol',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      shortDisplayIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'shortDisplay',
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      shortDisplayIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'shortDisplay',
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      shortDisplayEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'shortDisplay',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      shortDisplayGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'shortDisplay',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      shortDisplayLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'shortDisplay',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      shortDisplayBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'shortDisplay',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      shortDisplayStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'shortDisplay',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      shortDisplayEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'shortDisplay',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      shortDisplayContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'shortDisplay',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      shortDisplayMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'shortDisplay',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      shortDisplayIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'shortDisplay',
        value: '',
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      shortDisplayIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'shortDisplay',
        value: '',
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      shortVolIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'shortVol',
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      shortVolIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'shortVol',
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      shortVolEqualTo(
    double? value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'shortVol',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      shortVolGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'shortVol',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      shortVolLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'shortVol',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      shortVolBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'shortVol',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      symbolIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'symbol',
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      symbolIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'symbol',
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition> symbolEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'symbol',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      symbolGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'symbol',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      symbolLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'symbol',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition> symbolBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'symbol',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      symbolStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'symbol',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      symbolEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'symbol',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      symbolContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'symbol',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition> symbolMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'symbol',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      symbolIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'symbol',
        value: '',
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      symbolIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'symbol',
        value: '',
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      totalDisplayIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'totalDisplay',
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      totalDisplayIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'totalDisplay',
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      totalDisplayEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'totalDisplay',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      totalDisplayGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'totalDisplay',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      totalDisplayLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'totalDisplay',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      totalDisplayBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'totalDisplay',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      totalDisplayStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'totalDisplay',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      totalDisplayEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'totalDisplay',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      totalDisplayContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'totalDisplay',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      totalDisplayMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'totalDisplay',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      totalDisplayIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'totalDisplay',
        value: '',
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      totalDisplayIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'totalDisplay',
        value: '',
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      totalVolIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'totalVol',
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      totalVolIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'totalVol',
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      totalVolEqualTo(
    double? value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'totalVol',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      totalVolGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'totalVol',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      totalVolLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'totalVol',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<CoinPosition, CoinPosition, QAfterFilterCondition>
      totalVolBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'totalVol',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }
}

extension CoinPositionQueryObject
    on QueryBuilder<CoinPosition, CoinPosition, QFilterCondition> {}
