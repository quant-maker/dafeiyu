// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'db.dart';

// ignore_for_file: type=lint
class $EpisodesTable extends Episodes with TableInfo<$EpisodesTable, Episode> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EpisodesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _atMeta = const VerificationMeta('at');
  @override
  late final GeneratedColumn<int> at = GeneratedColumn<int>(
    'at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionMeta = const VerificationMeta(
    'session',
  );
  @override
  late final GeneratedColumn<String> session = GeneratedColumn<String>(
    'session',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _placeMeta = const VerificationMeta('place');
  @override
  late final GeneratedColumn<String> place = GeneratedColumn<String>(
    'place',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rawRefMeta = const VerificationMeta('rawRef');
  @override
  late final GeneratedColumn<String> rawRef = GeneratedColumn<String>(
    'raw_ref',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _weightMeta = const VerificationMeta('weight');
  @override
  late final GeneratedColumn<double> weight = GeneratedColumn<double>(
    'weight',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _vecMeta = const VerificationMeta('vec');
  @override
  late final GeneratedColumn<Uint8List> vec = GeneratedColumn<Uint8List>(
    'vec',
    aliasedName,
    true,
    type: DriftSqlType.blob,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _vecDimsMeta = const VerificationMeta(
    'vecDims',
  );
  @override
  late final GeneratedColumn<int> vecDims = GeneratedColumn<int>(
    'vec_dims',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _localOnlyMeta = const VerificationMeta(
    'localOnly',
  );
  @override
  late final GeneratedColumn<bool> localOnly = GeneratedColumn<bool>(
    'local_only',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("local_only" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    at,
    session,
    place,
    title,
    body,
    rawRef,
    weight,
    vec,
    vecDims,
    localOnly,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'episodes';
  @override
  VerificationContext validateIntegrity(
    Insertable<Episode> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('at')) {
      context.handle(_atMeta, at.isAcceptableOrUnknown(data['at']!, _atMeta));
    } else if (isInserting) {
      context.missing(_atMeta);
    }
    if (data.containsKey('session')) {
      context.handle(
        _sessionMeta,
        session.isAcceptableOrUnknown(data['session']!, _sessionMeta),
      );
    }
    if (data.containsKey('place')) {
      context.handle(
        _placeMeta,
        place.isAcceptableOrUnknown(data['place']!, _placeMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('raw_ref')) {
      context.handle(
        _rawRefMeta,
        rawRef.isAcceptableOrUnknown(data['raw_ref']!, _rawRefMeta),
      );
    }
    if (data.containsKey('weight')) {
      context.handle(
        _weightMeta,
        weight.isAcceptableOrUnknown(data['weight']!, _weightMeta),
      );
    }
    if (data.containsKey('vec')) {
      context.handle(
        _vecMeta,
        vec.isAcceptableOrUnknown(data['vec']!, _vecMeta),
      );
    }
    if (data.containsKey('vec_dims')) {
      context.handle(
        _vecDimsMeta,
        vecDims.isAcceptableOrUnknown(data['vec_dims']!, _vecDimsMeta),
      );
    }
    if (data.containsKey('local_only')) {
      context.handle(
        _localOnlyMeta,
        localOnly.isAcceptableOrUnknown(data['local_only']!, _localOnlyMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Episode map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Episode(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      at: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}at'],
      )!,
      session: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session'],
      ),
      place: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}place'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      rawRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw_ref'],
      ),
      weight: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}weight'],
      )!,
      vec: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}vec'],
      ),
      vecDims: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}vec_dims'],
      )!,
      localOnly: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}local_only'],
      )!,
    );
  }

  @override
  $EpisodesTable createAlias(String alias) {
    return $EpisodesTable(attachedDatabase, alias);
  }
}

class Episode extends DataClass implements Insertable<Episode> {
  final int id;
  final int at;
  final String? session;
  final String? place;
  final String title;
  final String body;
  final String? rawRef;
  final double weight;
  final Uint8List? vec;
  final int vecDims;
  final bool localOnly;
  const Episode({
    required this.id,
    required this.at,
    this.session,
    this.place,
    required this.title,
    required this.body,
    this.rawRef,
    required this.weight,
    this.vec,
    required this.vecDims,
    required this.localOnly,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['at'] = Variable<int>(at);
    if (!nullToAbsent || session != null) {
      map['session'] = Variable<String>(session);
    }
    if (!nullToAbsent || place != null) {
      map['place'] = Variable<String>(place);
    }
    map['title'] = Variable<String>(title);
    map['body'] = Variable<String>(body);
    if (!nullToAbsent || rawRef != null) {
      map['raw_ref'] = Variable<String>(rawRef);
    }
    map['weight'] = Variable<double>(weight);
    if (!nullToAbsent || vec != null) {
      map['vec'] = Variable<Uint8List>(vec);
    }
    map['vec_dims'] = Variable<int>(vecDims);
    map['local_only'] = Variable<bool>(localOnly);
    return map;
  }

  EpisodesCompanion toCompanion(bool nullToAbsent) {
    return EpisodesCompanion(
      id: Value(id),
      at: Value(at),
      session: session == null && nullToAbsent
          ? const Value.absent()
          : Value(session),
      place: place == null && nullToAbsent
          ? const Value.absent()
          : Value(place),
      title: Value(title),
      body: Value(body),
      rawRef: rawRef == null && nullToAbsent
          ? const Value.absent()
          : Value(rawRef),
      weight: Value(weight),
      vec: vec == null && nullToAbsent ? const Value.absent() : Value(vec),
      vecDims: Value(vecDims),
      localOnly: Value(localOnly),
    );
  }

  factory Episode.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Episode(
      id: serializer.fromJson<int>(json['id']),
      at: serializer.fromJson<int>(json['at']),
      session: serializer.fromJson<String?>(json['session']),
      place: serializer.fromJson<String?>(json['place']),
      title: serializer.fromJson<String>(json['title']),
      body: serializer.fromJson<String>(json['body']),
      rawRef: serializer.fromJson<String?>(json['rawRef']),
      weight: serializer.fromJson<double>(json['weight']),
      vec: serializer.fromJson<Uint8List?>(json['vec']),
      vecDims: serializer.fromJson<int>(json['vecDims']),
      localOnly: serializer.fromJson<bool>(json['localOnly']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'at': serializer.toJson<int>(at),
      'session': serializer.toJson<String?>(session),
      'place': serializer.toJson<String?>(place),
      'title': serializer.toJson<String>(title),
      'body': serializer.toJson<String>(body),
      'rawRef': serializer.toJson<String?>(rawRef),
      'weight': serializer.toJson<double>(weight),
      'vec': serializer.toJson<Uint8List?>(vec),
      'vecDims': serializer.toJson<int>(vecDims),
      'localOnly': serializer.toJson<bool>(localOnly),
    };
  }

  Episode copyWith({
    int? id,
    int? at,
    Value<String?> session = const Value.absent(),
    Value<String?> place = const Value.absent(),
    String? title,
    String? body,
    Value<String?> rawRef = const Value.absent(),
    double? weight,
    Value<Uint8List?> vec = const Value.absent(),
    int? vecDims,
    bool? localOnly,
  }) => Episode(
    id: id ?? this.id,
    at: at ?? this.at,
    session: session.present ? session.value : this.session,
    place: place.present ? place.value : this.place,
    title: title ?? this.title,
    body: body ?? this.body,
    rawRef: rawRef.present ? rawRef.value : this.rawRef,
    weight: weight ?? this.weight,
    vec: vec.present ? vec.value : this.vec,
    vecDims: vecDims ?? this.vecDims,
    localOnly: localOnly ?? this.localOnly,
  );
  Episode copyWithCompanion(EpisodesCompanion data) {
    return Episode(
      id: data.id.present ? data.id.value : this.id,
      at: data.at.present ? data.at.value : this.at,
      session: data.session.present ? data.session.value : this.session,
      place: data.place.present ? data.place.value : this.place,
      title: data.title.present ? data.title.value : this.title,
      body: data.body.present ? data.body.value : this.body,
      rawRef: data.rawRef.present ? data.rawRef.value : this.rawRef,
      weight: data.weight.present ? data.weight.value : this.weight,
      vec: data.vec.present ? data.vec.value : this.vec,
      vecDims: data.vecDims.present ? data.vecDims.value : this.vecDims,
      localOnly: data.localOnly.present ? data.localOnly.value : this.localOnly,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Episode(')
          ..write('id: $id, ')
          ..write('at: $at, ')
          ..write('session: $session, ')
          ..write('place: $place, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('rawRef: $rawRef, ')
          ..write('weight: $weight, ')
          ..write('vec: $vec, ')
          ..write('vecDims: $vecDims, ')
          ..write('localOnly: $localOnly')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    at,
    session,
    place,
    title,
    body,
    rawRef,
    weight,
    $driftBlobEquality.hash(vec),
    vecDims,
    localOnly,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Episode &&
          other.id == this.id &&
          other.at == this.at &&
          other.session == this.session &&
          other.place == this.place &&
          other.title == this.title &&
          other.body == this.body &&
          other.rawRef == this.rawRef &&
          other.weight == this.weight &&
          $driftBlobEquality.equals(other.vec, this.vec) &&
          other.vecDims == this.vecDims &&
          other.localOnly == this.localOnly);
}

class EpisodesCompanion extends UpdateCompanion<Episode> {
  final Value<int> id;
  final Value<int> at;
  final Value<String?> session;
  final Value<String?> place;
  final Value<String> title;
  final Value<String> body;
  final Value<String?> rawRef;
  final Value<double> weight;
  final Value<Uint8List?> vec;
  final Value<int> vecDims;
  final Value<bool> localOnly;
  const EpisodesCompanion({
    this.id = const Value.absent(),
    this.at = const Value.absent(),
    this.session = const Value.absent(),
    this.place = const Value.absent(),
    this.title = const Value.absent(),
    this.body = const Value.absent(),
    this.rawRef = const Value.absent(),
    this.weight = const Value.absent(),
    this.vec = const Value.absent(),
    this.vecDims = const Value.absent(),
    this.localOnly = const Value.absent(),
  });
  EpisodesCompanion.insert({
    this.id = const Value.absent(),
    required int at,
    this.session = const Value.absent(),
    this.place = const Value.absent(),
    required String title,
    required String body,
    this.rawRef = const Value.absent(),
    this.weight = const Value.absent(),
    this.vec = const Value.absent(),
    this.vecDims = const Value.absent(),
    this.localOnly = const Value.absent(),
  }) : at = Value(at),
       title = Value(title),
       body = Value(body);
  static Insertable<Episode> custom({
    Expression<int>? id,
    Expression<int>? at,
    Expression<String>? session,
    Expression<String>? place,
    Expression<String>? title,
    Expression<String>? body,
    Expression<String>? rawRef,
    Expression<double>? weight,
    Expression<Uint8List>? vec,
    Expression<int>? vecDims,
    Expression<bool>? localOnly,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (at != null) 'at': at,
      if (session != null) 'session': session,
      if (place != null) 'place': place,
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      if (rawRef != null) 'raw_ref': rawRef,
      if (weight != null) 'weight': weight,
      if (vec != null) 'vec': vec,
      if (vecDims != null) 'vec_dims': vecDims,
      if (localOnly != null) 'local_only': localOnly,
    });
  }

  EpisodesCompanion copyWith({
    Value<int>? id,
    Value<int>? at,
    Value<String?>? session,
    Value<String?>? place,
    Value<String>? title,
    Value<String>? body,
    Value<String?>? rawRef,
    Value<double>? weight,
    Value<Uint8List?>? vec,
    Value<int>? vecDims,
    Value<bool>? localOnly,
  }) {
    return EpisodesCompanion(
      id: id ?? this.id,
      at: at ?? this.at,
      session: session ?? this.session,
      place: place ?? this.place,
      title: title ?? this.title,
      body: body ?? this.body,
      rawRef: rawRef ?? this.rawRef,
      weight: weight ?? this.weight,
      vec: vec ?? this.vec,
      vecDims: vecDims ?? this.vecDims,
      localOnly: localOnly ?? this.localOnly,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (at.present) {
      map['at'] = Variable<int>(at.value);
    }
    if (session.present) {
      map['session'] = Variable<String>(session.value);
    }
    if (place.present) {
      map['place'] = Variable<String>(place.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (rawRef.present) {
      map['raw_ref'] = Variable<String>(rawRef.value);
    }
    if (weight.present) {
      map['weight'] = Variable<double>(weight.value);
    }
    if (vec.present) {
      map['vec'] = Variable<Uint8List>(vec.value);
    }
    if (vecDims.present) {
      map['vec_dims'] = Variable<int>(vecDims.value);
    }
    if (localOnly.present) {
      map['local_only'] = Variable<bool>(localOnly.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EpisodesCompanion(')
          ..write('id: $id, ')
          ..write('at: $at, ')
          ..write('session: $session, ')
          ..write('place: $place, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('rawRef: $rawRef, ')
          ..write('weight: $weight, ')
          ..write('vec: $vec, ')
          ..write('vecDims: $vecDims, ')
          ..write('localOnly: $localOnly')
          ..write(')'))
        .toString();
  }
}

class $FactsTable extends Facts with TableInfo<$FactsTable, Fact> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FactsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subjectMeta = const VerificationMeta(
    'subject',
  );
  @override
  late final GeneratedColumn<String> subject = GeneratedColumn<String>(
    'subject',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _predicateMeta = const VerificationMeta(
    'predicate',
  );
  @override
  late final GeneratedColumn<String> predicate = GeneratedColumn<String>(
    'predicate',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _objectMeta = const VerificationMeta('object');
  @override
  late final GeneratedColumn<String> object = GeneratedColumn<String>(
    'object',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _confidenceMeta = const VerificationMeta(
    'confidence',
  );
  @override
  late final GeneratedColumn<double> confidence = GeneratedColumn<double>(
    'confidence',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.7),
  );
  static const VerificationMeta _importanceMeta = const VerificationMeta(
    'importance',
  );
  @override
  late final GeneratedColumn<int> importance = GeneratedColumn<int>(
    'importance',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(3),
  );
  static const VerificationMeta _firstSeenMeta = const VerificationMeta(
    'firstSeen',
  );
  @override
  late final GeneratedColumn<int> firstSeen = GeneratedColumn<int>(
    'first_seen',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSeenMeta = const VerificationMeta(
    'lastSeen',
  );
  @override
  late final GeneratedColumn<int> lastSeen = GeneratedColumn<int>(
    'last_seen',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hitCountMeta = const VerificationMeta(
    'hitCount',
  );
  @override
  late final GeneratedColumn<int> hitCount = GeneratedColumn<int>(
    'hit_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _evidenceEpisodeMeta = const VerificationMeta(
    'evidenceEpisode',
  );
  @override
  late final GeneratedColumn<int> evidenceEpisode = GeneratedColumn<int>(
    'evidence_episode',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _invalidatedAtMeta = const VerificationMeta(
    'invalidatedAt',
  );
  @override
  late final GeneratedColumn<int> invalidatedAt = GeneratedColumn<int>(
    'invalidated_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localOnlyMeta = const VerificationMeta(
    'localOnly',
  );
  @override
  late final GeneratedColumn<bool> localOnly = GeneratedColumn<bool>(
    'local_only',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("local_only" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    content,
    subject,
    predicate,
    object,
    confidence,
    importance,
    firstSeen,
    lastSeen,
    hitCount,
    evidenceEpisode,
    invalidatedAt,
    localOnly,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'facts';
  @override
  VerificationContext validateIntegrity(
    Insertable<Fact> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('subject')) {
      context.handle(
        _subjectMeta,
        subject.isAcceptableOrUnknown(data['subject']!, _subjectMeta),
      );
    }
    if (data.containsKey('predicate')) {
      context.handle(
        _predicateMeta,
        predicate.isAcceptableOrUnknown(data['predicate']!, _predicateMeta),
      );
    }
    if (data.containsKey('object')) {
      context.handle(
        _objectMeta,
        object.isAcceptableOrUnknown(data['object']!, _objectMeta),
      );
    }
    if (data.containsKey('confidence')) {
      context.handle(
        _confidenceMeta,
        confidence.isAcceptableOrUnknown(data['confidence']!, _confidenceMeta),
      );
    }
    if (data.containsKey('importance')) {
      context.handle(
        _importanceMeta,
        importance.isAcceptableOrUnknown(data['importance']!, _importanceMeta),
      );
    }
    if (data.containsKey('first_seen')) {
      context.handle(
        _firstSeenMeta,
        firstSeen.isAcceptableOrUnknown(data['first_seen']!, _firstSeenMeta),
      );
    } else if (isInserting) {
      context.missing(_firstSeenMeta);
    }
    if (data.containsKey('last_seen')) {
      context.handle(
        _lastSeenMeta,
        lastSeen.isAcceptableOrUnknown(data['last_seen']!, _lastSeenMeta),
      );
    } else if (isInserting) {
      context.missing(_lastSeenMeta);
    }
    if (data.containsKey('hit_count')) {
      context.handle(
        _hitCountMeta,
        hitCount.isAcceptableOrUnknown(data['hit_count']!, _hitCountMeta),
      );
    }
    if (data.containsKey('evidence_episode')) {
      context.handle(
        _evidenceEpisodeMeta,
        evidenceEpisode.isAcceptableOrUnknown(
          data['evidence_episode']!,
          _evidenceEpisodeMeta,
        ),
      );
    }
    if (data.containsKey('invalidated_at')) {
      context.handle(
        _invalidatedAtMeta,
        invalidatedAt.isAcceptableOrUnknown(
          data['invalidated_at']!,
          _invalidatedAtMeta,
        ),
      );
    }
    if (data.containsKey('local_only')) {
      context.handle(
        _localOnlyMeta,
        localOnly.isAcceptableOrUnknown(data['local_only']!, _localOnlyMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Fact map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Fact(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      subject: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject'],
      ),
      predicate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}predicate'],
      ),
      object: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}object'],
      ),
      confidence: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}confidence'],
      )!,
      importance: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}importance'],
      )!,
      firstSeen: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}first_seen'],
      )!,
      lastSeen: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_seen'],
      )!,
      hitCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}hit_count'],
      )!,
      evidenceEpisode: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}evidence_episode'],
      ),
      invalidatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}invalidated_at'],
      ),
      localOnly: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}local_only'],
      )!,
    );
  }

  @override
  $FactsTable createAlias(String alias) {
    return $FactsTable(attachedDatabase, alias);
  }
}

class Fact extends DataClass implements Insertable<Fact> {
  final int id;

  /// 人话版本。列名不能叫 text——那会和 drift 的 `Table.text()` 撞名。
  final String content;

  /// 三元组在结构化抽取后才填，旧数据只有 [content]。
  final String? subject;
  final String? predicate;
  final String? object;
  final double confidence;
  final int importance;
  final int firstSeen;
  final int lastSeen;
  final int hitCount;
  final int? evidenceEpisode;
  final int? invalidatedAt;
  final bool localOnly;
  const Fact({
    required this.id,
    required this.content,
    this.subject,
    this.predicate,
    this.object,
    required this.confidence,
    required this.importance,
    required this.firstSeen,
    required this.lastSeen,
    required this.hitCount,
    this.evidenceEpisode,
    this.invalidatedAt,
    required this.localOnly,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['content'] = Variable<String>(content);
    if (!nullToAbsent || subject != null) {
      map['subject'] = Variable<String>(subject);
    }
    if (!nullToAbsent || predicate != null) {
      map['predicate'] = Variable<String>(predicate);
    }
    if (!nullToAbsent || object != null) {
      map['object'] = Variable<String>(object);
    }
    map['confidence'] = Variable<double>(confidence);
    map['importance'] = Variable<int>(importance);
    map['first_seen'] = Variable<int>(firstSeen);
    map['last_seen'] = Variable<int>(lastSeen);
    map['hit_count'] = Variable<int>(hitCount);
    if (!nullToAbsent || evidenceEpisode != null) {
      map['evidence_episode'] = Variable<int>(evidenceEpisode);
    }
    if (!nullToAbsent || invalidatedAt != null) {
      map['invalidated_at'] = Variable<int>(invalidatedAt);
    }
    map['local_only'] = Variable<bool>(localOnly);
    return map;
  }

  FactsCompanion toCompanion(bool nullToAbsent) {
    return FactsCompanion(
      id: Value(id),
      content: Value(content),
      subject: subject == null && nullToAbsent
          ? const Value.absent()
          : Value(subject),
      predicate: predicate == null && nullToAbsent
          ? const Value.absent()
          : Value(predicate),
      object: object == null && nullToAbsent
          ? const Value.absent()
          : Value(object),
      confidence: Value(confidence),
      importance: Value(importance),
      firstSeen: Value(firstSeen),
      lastSeen: Value(lastSeen),
      hitCount: Value(hitCount),
      evidenceEpisode: evidenceEpisode == null && nullToAbsent
          ? const Value.absent()
          : Value(evidenceEpisode),
      invalidatedAt: invalidatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(invalidatedAt),
      localOnly: Value(localOnly),
    );
  }

  factory Fact.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Fact(
      id: serializer.fromJson<int>(json['id']),
      content: serializer.fromJson<String>(json['content']),
      subject: serializer.fromJson<String?>(json['subject']),
      predicate: serializer.fromJson<String?>(json['predicate']),
      object: serializer.fromJson<String?>(json['object']),
      confidence: serializer.fromJson<double>(json['confidence']),
      importance: serializer.fromJson<int>(json['importance']),
      firstSeen: serializer.fromJson<int>(json['firstSeen']),
      lastSeen: serializer.fromJson<int>(json['lastSeen']),
      hitCount: serializer.fromJson<int>(json['hitCount']),
      evidenceEpisode: serializer.fromJson<int?>(json['evidenceEpisode']),
      invalidatedAt: serializer.fromJson<int?>(json['invalidatedAt']),
      localOnly: serializer.fromJson<bool>(json['localOnly']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'content': serializer.toJson<String>(content),
      'subject': serializer.toJson<String?>(subject),
      'predicate': serializer.toJson<String?>(predicate),
      'object': serializer.toJson<String?>(object),
      'confidence': serializer.toJson<double>(confidence),
      'importance': serializer.toJson<int>(importance),
      'firstSeen': serializer.toJson<int>(firstSeen),
      'lastSeen': serializer.toJson<int>(lastSeen),
      'hitCount': serializer.toJson<int>(hitCount),
      'evidenceEpisode': serializer.toJson<int?>(evidenceEpisode),
      'invalidatedAt': serializer.toJson<int?>(invalidatedAt),
      'localOnly': serializer.toJson<bool>(localOnly),
    };
  }

  Fact copyWith({
    int? id,
    String? content,
    Value<String?> subject = const Value.absent(),
    Value<String?> predicate = const Value.absent(),
    Value<String?> object = const Value.absent(),
    double? confidence,
    int? importance,
    int? firstSeen,
    int? lastSeen,
    int? hitCount,
    Value<int?> evidenceEpisode = const Value.absent(),
    Value<int?> invalidatedAt = const Value.absent(),
    bool? localOnly,
  }) => Fact(
    id: id ?? this.id,
    content: content ?? this.content,
    subject: subject.present ? subject.value : this.subject,
    predicate: predicate.present ? predicate.value : this.predicate,
    object: object.present ? object.value : this.object,
    confidence: confidence ?? this.confidence,
    importance: importance ?? this.importance,
    firstSeen: firstSeen ?? this.firstSeen,
    lastSeen: lastSeen ?? this.lastSeen,
    hitCount: hitCount ?? this.hitCount,
    evidenceEpisode: evidenceEpisode.present
        ? evidenceEpisode.value
        : this.evidenceEpisode,
    invalidatedAt: invalidatedAt.present
        ? invalidatedAt.value
        : this.invalidatedAt,
    localOnly: localOnly ?? this.localOnly,
  );
  Fact copyWithCompanion(FactsCompanion data) {
    return Fact(
      id: data.id.present ? data.id.value : this.id,
      content: data.content.present ? data.content.value : this.content,
      subject: data.subject.present ? data.subject.value : this.subject,
      predicate: data.predicate.present ? data.predicate.value : this.predicate,
      object: data.object.present ? data.object.value : this.object,
      confidence: data.confidence.present
          ? data.confidence.value
          : this.confidence,
      importance: data.importance.present
          ? data.importance.value
          : this.importance,
      firstSeen: data.firstSeen.present ? data.firstSeen.value : this.firstSeen,
      lastSeen: data.lastSeen.present ? data.lastSeen.value : this.lastSeen,
      hitCount: data.hitCount.present ? data.hitCount.value : this.hitCount,
      evidenceEpisode: data.evidenceEpisode.present
          ? data.evidenceEpisode.value
          : this.evidenceEpisode,
      invalidatedAt: data.invalidatedAt.present
          ? data.invalidatedAt.value
          : this.invalidatedAt,
      localOnly: data.localOnly.present ? data.localOnly.value : this.localOnly,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Fact(')
          ..write('id: $id, ')
          ..write('content: $content, ')
          ..write('subject: $subject, ')
          ..write('predicate: $predicate, ')
          ..write('object: $object, ')
          ..write('confidence: $confidence, ')
          ..write('importance: $importance, ')
          ..write('firstSeen: $firstSeen, ')
          ..write('lastSeen: $lastSeen, ')
          ..write('hitCount: $hitCount, ')
          ..write('evidenceEpisode: $evidenceEpisode, ')
          ..write('invalidatedAt: $invalidatedAt, ')
          ..write('localOnly: $localOnly')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    content,
    subject,
    predicate,
    object,
    confidence,
    importance,
    firstSeen,
    lastSeen,
    hitCount,
    evidenceEpisode,
    invalidatedAt,
    localOnly,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Fact &&
          other.id == this.id &&
          other.content == this.content &&
          other.subject == this.subject &&
          other.predicate == this.predicate &&
          other.object == this.object &&
          other.confidence == this.confidence &&
          other.importance == this.importance &&
          other.firstSeen == this.firstSeen &&
          other.lastSeen == this.lastSeen &&
          other.hitCount == this.hitCount &&
          other.evidenceEpisode == this.evidenceEpisode &&
          other.invalidatedAt == this.invalidatedAt &&
          other.localOnly == this.localOnly);
}

class FactsCompanion extends UpdateCompanion<Fact> {
  final Value<int> id;
  final Value<String> content;
  final Value<String?> subject;
  final Value<String?> predicate;
  final Value<String?> object;
  final Value<double> confidence;
  final Value<int> importance;
  final Value<int> firstSeen;
  final Value<int> lastSeen;
  final Value<int> hitCount;
  final Value<int?> evidenceEpisode;
  final Value<int?> invalidatedAt;
  final Value<bool> localOnly;
  const FactsCompanion({
    this.id = const Value.absent(),
    this.content = const Value.absent(),
    this.subject = const Value.absent(),
    this.predicate = const Value.absent(),
    this.object = const Value.absent(),
    this.confidence = const Value.absent(),
    this.importance = const Value.absent(),
    this.firstSeen = const Value.absent(),
    this.lastSeen = const Value.absent(),
    this.hitCount = const Value.absent(),
    this.evidenceEpisode = const Value.absent(),
    this.invalidatedAt = const Value.absent(),
    this.localOnly = const Value.absent(),
  });
  FactsCompanion.insert({
    this.id = const Value.absent(),
    required String content,
    this.subject = const Value.absent(),
    this.predicate = const Value.absent(),
    this.object = const Value.absent(),
    this.confidence = const Value.absent(),
    this.importance = const Value.absent(),
    required int firstSeen,
    required int lastSeen,
    this.hitCount = const Value.absent(),
    this.evidenceEpisode = const Value.absent(),
    this.invalidatedAt = const Value.absent(),
    this.localOnly = const Value.absent(),
  }) : content = Value(content),
       firstSeen = Value(firstSeen),
       lastSeen = Value(lastSeen);
  static Insertable<Fact> custom({
    Expression<int>? id,
    Expression<String>? content,
    Expression<String>? subject,
    Expression<String>? predicate,
    Expression<String>? object,
    Expression<double>? confidence,
    Expression<int>? importance,
    Expression<int>? firstSeen,
    Expression<int>? lastSeen,
    Expression<int>? hitCount,
    Expression<int>? evidenceEpisode,
    Expression<int>? invalidatedAt,
    Expression<bool>? localOnly,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (content != null) 'content': content,
      if (subject != null) 'subject': subject,
      if (predicate != null) 'predicate': predicate,
      if (object != null) 'object': object,
      if (confidence != null) 'confidence': confidence,
      if (importance != null) 'importance': importance,
      if (firstSeen != null) 'first_seen': firstSeen,
      if (lastSeen != null) 'last_seen': lastSeen,
      if (hitCount != null) 'hit_count': hitCount,
      if (evidenceEpisode != null) 'evidence_episode': evidenceEpisode,
      if (invalidatedAt != null) 'invalidated_at': invalidatedAt,
      if (localOnly != null) 'local_only': localOnly,
    });
  }

  FactsCompanion copyWith({
    Value<int>? id,
    Value<String>? content,
    Value<String?>? subject,
    Value<String?>? predicate,
    Value<String?>? object,
    Value<double>? confidence,
    Value<int>? importance,
    Value<int>? firstSeen,
    Value<int>? lastSeen,
    Value<int>? hitCount,
    Value<int?>? evidenceEpisode,
    Value<int?>? invalidatedAt,
    Value<bool>? localOnly,
  }) {
    return FactsCompanion(
      id: id ?? this.id,
      content: content ?? this.content,
      subject: subject ?? this.subject,
      predicate: predicate ?? this.predicate,
      object: object ?? this.object,
      confidence: confidence ?? this.confidence,
      importance: importance ?? this.importance,
      firstSeen: firstSeen ?? this.firstSeen,
      lastSeen: lastSeen ?? this.lastSeen,
      hitCount: hitCount ?? this.hitCount,
      evidenceEpisode: evidenceEpisode ?? this.evidenceEpisode,
      invalidatedAt: invalidatedAt ?? this.invalidatedAt,
      localOnly: localOnly ?? this.localOnly,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (subject.present) {
      map['subject'] = Variable<String>(subject.value);
    }
    if (predicate.present) {
      map['predicate'] = Variable<String>(predicate.value);
    }
    if (object.present) {
      map['object'] = Variable<String>(object.value);
    }
    if (confidence.present) {
      map['confidence'] = Variable<double>(confidence.value);
    }
    if (importance.present) {
      map['importance'] = Variable<int>(importance.value);
    }
    if (firstSeen.present) {
      map['first_seen'] = Variable<int>(firstSeen.value);
    }
    if (lastSeen.present) {
      map['last_seen'] = Variable<int>(lastSeen.value);
    }
    if (hitCount.present) {
      map['hit_count'] = Variable<int>(hitCount.value);
    }
    if (evidenceEpisode.present) {
      map['evidence_episode'] = Variable<int>(evidenceEpisode.value);
    }
    if (invalidatedAt.present) {
      map['invalidated_at'] = Variable<int>(invalidatedAt.value);
    }
    if (localOnly.present) {
      map['local_only'] = Variable<bool>(localOnly.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FactsCompanion(')
          ..write('id: $id, ')
          ..write('content: $content, ')
          ..write('subject: $subject, ')
          ..write('predicate: $predicate, ')
          ..write('object: $object, ')
          ..write('confidence: $confidence, ')
          ..write('importance: $importance, ')
          ..write('firstSeen: $firstSeen, ')
          ..write('lastSeen: $lastSeen, ')
          ..write('hitCount: $hitCount, ')
          ..write('evidenceEpisode: $evidenceEpisode, ')
          ..write('invalidatedAt: $invalidatedAt, ')
          ..write('localOnly: $localOnly')
          ..write(')'))
        .toString();
  }
}

class $EntitiesTable extends Entities with TableInfo<$EntitiesTable, Entity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EntitiesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _aliasMeta = const VerificationMeta('alias');
  @override
  late final GeneratedColumn<String> alias = GeneratedColumn<String>(
    'alias',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('thing'),
  );
  static const VerificationMeta _importanceMeta = const VerificationMeta(
    'importance',
  );
  @override
  late final GeneratedColumn<int> importance = GeneratedColumn<int>(
    'importance',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(3),
  );
  static const VerificationMeta _strengthMeta = const VerificationMeta(
    'strength',
  );
  @override
  late final GeneratedColumn<double> strength = GeneratedColumn<double>(
    'strength',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _firstSeenMeta = const VerificationMeta(
    'firstSeen',
  );
  @override
  late final GeneratedColumn<int> firstSeen = GeneratedColumn<int>(
    'first_seen',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastTouchedMeta = const VerificationMeta(
    'lastTouched',
  );
  @override
  late final GeneratedColumn<int> lastTouched = GeneratedColumn<int>(
    'last_touched',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _summaryMeta = const VerificationMeta(
    'summary',
  );
  @override
  late final GeneratedColumn<String> summary = GeneratedColumn<String>(
    'summary',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _xMeta = const VerificationMeta('x');
  @override
  late final GeneratedColumn<double> x = GeneratedColumn<double>(
    'x',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _yMeta = const VerificationMeta('y');
  @override
  late final GeneratedColumn<double> y = GeneratedColumn<double>(
    'y',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    alias,
    kind,
    importance,
    strength,
    firstSeen,
    lastTouched,
    summary,
    x,
    y,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'entities';
  @override
  VerificationContext validateIntegrity(
    Insertable<Entity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('alias')) {
      context.handle(
        _aliasMeta,
        alias.isAcceptableOrUnknown(data['alias']!, _aliasMeta),
      );
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    }
    if (data.containsKey('importance')) {
      context.handle(
        _importanceMeta,
        importance.isAcceptableOrUnknown(data['importance']!, _importanceMeta),
      );
    }
    if (data.containsKey('strength')) {
      context.handle(
        _strengthMeta,
        strength.isAcceptableOrUnknown(data['strength']!, _strengthMeta),
      );
    }
    if (data.containsKey('first_seen')) {
      context.handle(
        _firstSeenMeta,
        firstSeen.isAcceptableOrUnknown(data['first_seen']!, _firstSeenMeta),
      );
    } else if (isInserting) {
      context.missing(_firstSeenMeta);
    }
    if (data.containsKey('last_touched')) {
      context.handle(
        _lastTouchedMeta,
        lastTouched.isAcceptableOrUnknown(
          data['last_touched']!,
          _lastTouchedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastTouchedMeta);
    }
    if (data.containsKey('summary')) {
      context.handle(
        _summaryMeta,
        summary.isAcceptableOrUnknown(data['summary']!, _summaryMeta),
      );
    }
    if (data.containsKey('x')) {
      context.handle(_xMeta, x.isAcceptableOrUnknown(data['x']!, _xMeta));
    }
    if (data.containsKey('y')) {
      context.handle(_yMeta, y.isAcceptableOrUnknown(data['y']!, _yMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Entity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Entity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      alias: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}alias'],
      ),
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      importance: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}importance'],
      )!,
      strength: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}strength'],
      )!,
      firstSeen: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}first_seen'],
      )!,
      lastTouched: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_touched'],
      )!,
      summary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary'],
      ),
      x: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}x'],
      ),
      y: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}y'],
      ),
    );
  }

  @override
  $EntitiesTable createAlias(String alias) {
    return $EntitiesTable(attachedDatabase, alias);
  }
}

class Entity extends DataClass implements Insertable<Entity> {
  final int id;
  final String name;
  final String? alias;

  /// person | project | place | topic | promise | thing
  final String kind;
  final int importance;
  final double strength;
  final int firstSeen;
  final int lastTouched;
  final String? summary;
  final double? x;
  final double? y;
  const Entity({
    required this.id,
    required this.name,
    this.alias,
    required this.kind,
    required this.importance,
    required this.strength,
    required this.firstSeen,
    required this.lastTouched,
    this.summary,
    this.x,
    this.y,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || alias != null) {
      map['alias'] = Variable<String>(alias);
    }
    map['kind'] = Variable<String>(kind);
    map['importance'] = Variable<int>(importance);
    map['strength'] = Variable<double>(strength);
    map['first_seen'] = Variable<int>(firstSeen);
    map['last_touched'] = Variable<int>(lastTouched);
    if (!nullToAbsent || summary != null) {
      map['summary'] = Variable<String>(summary);
    }
    if (!nullToAbsent || x != null) {
      map['x'] = Variable<double>(x);
    }
    if (!nullToAbsent || y != null) {
      map['y'] = Variable<double>(y);
    }
    return map;
  }

  EntitiesCompanion toCompanion(bool nullToAbsent) {
    return EntitiesCompanion(
      id: Value(id),
      name: Value(name),
      alias: alias == null && nullToAbsent
          ? const Value.absent()
          : Value(alias),
      kind: Value(kind),
      importance: Value(importance),
      strength: Value(strength),
      firstSeen: Value(firstSeen),
      lastTouched: Value(lastTouched),
      summary: summary == null && nullToAbsent
          ? const Value.absent()
          : Value(summary),
      x: x == null && nullToAbsent ? const Value.absent() : Value(x),
      y: y == null && nullToAbsent ? const Value.absent() : Value(y),
    );
  }

  factory Entity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Entity(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      alias: serializer.fromJson<String?>(json['alias']),
      kind: serializer.fromJson<String>(json['kind']),
      importance: serializer.fromJson<int>(json['importance']),
      strength: serializer.fromJson<double>(json['strength']),
      firstSeen: serializer.fromJson<int>(json['firstSeen']),
      lastTouched: serializer.fromJson<int>(json['lastTouched']),
      summary: serializer.fromJson<String?>(json['summary']),
      x: serializer.fromJson<double?>(json['x']),
      y: serializer.fromJson<double?>(json['y']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'alias': serializer.toJson<String?>(alias),
      'kind': serializer.toJson<String>(kind),
      'importance': serializer.toJson<int>(importance),
      'strength': serializer.toJson<double>(strength),
      'firstSeen': serializer.toJson<int>(firstSeen),
      'lastTouched': serializer.toJson<int>(lastTouched),
      'summary': serializer.toJson<String?>(summary),
      'x': serializer.toJson<double?>(x),
      'y': serializer.toJson<double?>(y),
    };
  }

  Entity copyWith({
    int? id,
    String? name,
    Value<String?> alias = const Value.absent(),
    String? kind,
    int? importance,
    double? strength,
    int? firstSeen,
    int? lastTouched,
    Value<String?> summary = const Value.absent(),
    Value<double?> x = const Value.absent(),
    Value<double?> y = const Value.absent(),
  }) => Entity(
    id: id ?? this.id,
    name: name ?? this.name,
    alias: alias.present ? alias.value : this.alias,
    kind: kind ?? this.kind,
    importance: importance ?? this.importance,
    strength: strength ?? this.strength,
    firstSeen: firstSeen ?? this.firstSeen,
    lastTouched: lastTouched ?? this.lastTouched,
    summary: summary.present ? summary.value : this.summary,
    x: x.present ? x.value : this.x,
    y: y.present ? y.value : this.y,
  );
  Entity copyWithCompanion(EntitiesCompanion data) {
    return Entity(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      alias: data.alias.present ? data.alias.value : this.alias,
      kind: data.kind.present ? data.kind.value : this.kind,
      importance: data.importance.present
          ? data.importance.value
          : this.importance,
      strength: data.strength.present ? data.strength.value : this.strength,
      firstSeen: data.firstSeen.present ? data.firstSeen.value : this.firstSeen,
      lastTouched: data.lastTouched.present
          ? data.lastTouched.value
          : this.lastTouched,
      summary: data.summary.present ? data.summary.value : this.summary,
      x: data.x.present ? data.x.value : this.x,
      y: data.y.present ? data.y.value : this.y,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Entity(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('alias: $alias, ')
          ..write('kind: $kind, ')
          ..write('importance: $importance, ')
          ..write('strength: $strength, ')
          ..write('firstSeen: $firstSeen, ')
          ..write('lastTouched: $lastTouched, ')
          ..write('summary: $summary, ')
          ..write('x: $x, ')
          ..write('y: $y')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    alias,
    kind,
    importance,
    strength,
    firstSeen,
    lastTouched,
    summary,
    x,
    y,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Entity &&
          other.id == this.id &&
          other.name == this.name &&
          other.alias == this.alias &&
          other.kind == this.kind &&
          other.importance == this.importance &&
          other.strength == this.strength &&
          other.firstSeen == this.firstSeen &&
          other.lastTouched == this.lastTouched &&
          other.summary == this.summary &&
          other.x == this.x &&
          other.y == this.y);
}

class EntitiesCompanion extends UpdateCompanion<Entity> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> alias;
  final Value<String> kind;
  final Value<int> importance;
  final Value<double> strength;
  final Value<int> firstSeen;
  final Value<int> lastTouched;
  final Value<String?> summary;
  final Value<double?> x;
  final Value<double?> y;
  const EntitiesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.alias = const Value.absent(),
    this.kind = const Value.absent(),
    this.importance = const Value.absent(),
    this.strength = const Value.absent(),
    this.firstSeen = const Value.absent(),
    this.lastTouched = const Value.absent(),
    this.summary = const Value.absent(),
    this.x = const Value.absent(),
    this.y = const Value.absent(),
  });
  EntitiesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.alias = const Value.absent(),
    this.kind = const Value.absent(),
    this.importance = const Value.absent(),
    this.strength = const Value.absent(),
    required int firstSeen,
    required int lastTouched,
    this.summary = const Value.absent(),
    this.x = const Value.absent(),
    this.y = const Value.absent(),
  }) : name = Value(name),
       firstSeen = Value(firstSeen),
       lastTouched = Value(lastTouched);
  static Insertable<Entity> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? alias,
    Expression<String>? kind,
    Expression<int>? importance,
    Expression<double>? strength,
    Expression<int>? firstSeen,
    Expression<int>? lastTouched,
    Expression<String>? summary,
    Expression<double>? x,
    Expression<double>? y,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (alias != null) 'alias': alias,
      if (kind != null) 'kind': kind,
      if (importance != null) 'importance': importance,
      if (strength != null) 'strength': strength,
      if (firstSeen != null) 'first_seen': firstSeen,
      if (lastTouched != null) 'last_touched': lastTouched,
      if (summary != null) 'summary': summary,
      if (x != null) 'x': x,
      if (y != null) 'y': y,
    });
  }

  EntitiesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String?>? alias,
    Value<String>? kind,
    Value<int>? importance,
    Value<double>? strength,
    Value<int>? firstSeen,
    Value<int>? lastTouched,
    Value<String?>? summary,
    Value<double?>? x,
    Value<double?>? y,
  }) {
    return EntitiesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      alias: alias ?? this.alias,
      kind: kind ?? this.kind,
      importance: importance ?? this.importance,
      strength: strength ?? this.strength,
      firstSeen: firstSeen ?? this.firstSeen,
      lastTouched: lastTouched ?? this.lastTouched,
      summary: summary ?? this.summary,
      x: x ?? this.x,
      y: y ?? this.y,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (alias.present) {
      map['alias'] = Variable<String>(alias.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (importance.present) {
      map['importance'] = Variable<int>(importance.value);
    }
    if (strength.present) {
      map['strength'] = Variable<double>(strength.value);
    }
    if (firstSeen.present) {
      map['first_seen'] = Variable<int>(firstSeen.value);
    }
    if (lastTouched.present) {
      map['last_touched'] = Variable<int>(lastTouched.value);
    }
    if (summary.present) {
      map['summary'] = Variable<String>(summary.value);
    }
    if (x.present) {
      map['x'] = Variable<double>(x.value);
    }
    if (y.present) {
      map['y'] = Variable<double>(y.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EntitiesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('alias: $alias, ')
          ..write('kind: $kind, ')
          ..write('importance: $importance, ')
          ..write('strength: $strength, ')
          ..write('firstSeen: $firstSeen, ')
          ..write('lastTouched: $lastTouched, ')
          ..write('summary: $summary, ')
          ..write('x: $x, ')
          ..write('y: $y')
          ..write(')'))
        .toString();
  }
}

class $EdgesTable extends Edges with TableInfo<$EdgesTable, Edge> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EdgesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _srcMeta = const VerificationMeta('src');
  @override
  late final GeneratedColumn<int> src = GeneratedColumn<int>(
    'src',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dstMeta = const VerificationMeta('dst');
  @override
  late final GeneratedColumn<int> dst = GeneratedColumn<int>(
    'dst',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('semantic'),
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _weightMeta = const VerificationMeta('weight');
  @override
  late final GeneratedColumn<double> weight = GeneratedColumn<double>(
    'weight',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _firstSeenMeta = const VerificationMeta(
    'firstSeen',
  );
  @override
  late final GeneratedColumn<int> firstSeen = GeneratedColumn<int>(
    'first_seen',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSeenMeta = const VerificationMeta(
    'lastSeen',
  );
  @override
  late final GeneratedColumn<int> lastSeen = GeneratedColumn<int>(
    'last_seen',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _evidenceEpisodeMeta = const VerificationMeta(
    'evidenceEpisode',
  );
  @override
  late final GeneratedColumn<int> evidenceEpisode = GeneratedColumn<int>(
    'evidence_episode',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _invalidatedAtMeta = const VerificationMeta(
    'invalidatedAt',
  );
  @override
  late final GeneratedColumn<int> invalidatedAt = GeneratedColumn<int>(
    'invalidated_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    src,
    dst,
    kind,
    label,
    weight,
    firstSeen,
    lastSeen,
    evidenceEpisode,
    invalidatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'edges';
  @override
  VerificationContext validateIntegrity(
    Insertable<Edge> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('src')) {
      context.handle(
        _srcMeta,
        src.isAcceptableOrUnknown(data['src']!, _srcMeta),
      );
    } else if (isInserting) {
      context.missing(_srcMeta);
    }
    if (data.containsKey('dst')) {
      context.handle(
        _dstMeta,
        dst.isAcceptableOrUnknown(data['dst']!, _dstMeta),
      );
    } else if (isInserting) {
      context.missing(_dstMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    }
    if (data.containsKey('weight')) {
      context.handle(
        _weightMeta,
        weight.isAcceptableOrUnknown(data['weight']!, _weightMeta),
      );
    }
    if (data.containsKey('first_seen')) {
      context.handle(
        _firstSeenMeta,
        firstSeen.isAcceptableOrUnknown(data['first_seen']!, _firstSeenMeta),
      );
    } else if (isInserting) {
      context.missing(_firstSeenMeta);
    }
    if (data.containsKey('last_seen')) {
      context.handle(
        _lastSeenMeta,
        lastSeen.isAcceptableOrUnknown(data['last_seen']!, _lastSeenMeta),
      );
    } else if (isInserting) {
      context.missing(_lastSeenMeta);
    }
    if (data.containsKey('evidence_episode')) {
      context.handle(
        _evidenceEpisodeMeta,
        evidenceEpisode.isAcceptableOrUnknown(
          data['evidence_episode']!,
          _evidenceEpisodeMeta,
        ),
      );
    }
    if (data.containsKey('invalidated_at')) {
      context.handle(
        _invalidatedAtMeta,
        invalidatedAt.isAcceptableOrUnknown(
          data['invalidated_at']!,
          _invalidatedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Edge map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Edge(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      src: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}src'],
      )!,
      dst: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}dst'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      ),
      weight: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}weight'],
      )!,
      firstSeen: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}first_seen'],
      )!,
      lastSeen: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_seen'],
      )!,
      evidenceEpisode: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}evidence_episode'],
      ),
      invalidatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}invalidated_at'],
      ),
    );
  }

  @override
  $EdgesTable createAlias(String alias) {
    return $EdgesTable(attachedDatabase, alias);
  }
}

class Edge extends DataClass implements Insertable<Edge> {
  final int id;
  final int src;
  final int dst;

  /// semantic | temporal | causal | entity | mentions
  final String kind;
  final String? label;
  final double weight;
  final int firstSeen;
  final int lastSeen;
  final int? evidenceEpisode;
  final int? invalidatedAt;
  const Edge({
    required this.id,
    required this.src,
    required this.dst,
    required this.kind,
    this.label,
    required this.weight,
    required this.firstSeen,
    required this.lastSeen,
    this.evidenceEpisode,
    this.invalidatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['src'] = Variable<int>(src);
    map['dst'] = Variable<int>(dst);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || label != null) {
      map['label'] = Variable<String>(label);
    }
    map['weight'] = Variable<double>(weight);
    map['first_seen'] = Variable<int>(firstSeen);
    map['last_seen'] = Variable<int>(lastSeen);
    if (!nullToAbsent || evidenceEpisode != null) {
      map['evidence_episode'] = Variable<int>(evidenceEpisode);
    }
    if (!nullToAbsent || invalidatedAt != null) {
      map['invalidated_at'] = Variable<int>(invalidatedAt);
    }
    return map;
  }

  EdgesCompanion toCompanion(bool nullToAbsent) {
    return EdgesCompanion(
      id: Value(id),
      src: Value(src),
      dst: Value(dst),
      kind: Value(kind),
      label: label == null && nullToAbsent
          ? const Value.absent()
          : Value(label),
      weight: Value(weight),
      firstSeen: Value(firstSeen),
      lastSeen: Value(lastSeen),
      evidenceEpisode: evidenceEpisode == null && nullToAbsent
          ? const Value.absent()
          : Value(evidenceEpisode),
      invalidatedAt: invalidatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(invalidatedAt),
    );
  }

  factory Edge.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Edge(
      id: serializer.fromJson<int>(json['id']),
      src: serializer.fromJson<int>(json['src']),
      dst: serializer.fromJson<int>(json['dst']),
      kind: serializer.fromJson<String>(json['kind']),
      label: serializer.fromJson<String?>(json['label']),
      weight: serializer.fromJson<double>(json['weight']),
      firstSeen: serializer.fromJson<int>(json['firstSeen']),
      lastSeen: serializer.fromJson<int>(json['lastSeen']),
      evidenceEpisode: serializer.fromJson<int?>(json['evidenceEpisode']),
      invalidatedAt: serializer.fromJson<int?>(json['invalidatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'src': serializer.toJson<int>(src),
      'dst': serializer.toJson<int>(dst),
      'kind': serializer.toJson<String>(kind),
      'label': serializer.toJson<String?>(label),
      'weight': serializer.toJson<double>(weight),
      'firstSeen': serializer.toJson<int>(firstSeen),
      'lastSeen': serializer.toJson<int>(lastSeen),
      'evidenceEpisode': serializer.toJson<int?>(evidenceEpisode),
      'invalidatedAt': serializer.toJson<int?>(invalidatedAt),
    };
  }

  Edge copyWith({
    int? id,
    int? src,
    int? dst,
    String? kind,
    Value<String?> label = const Value.absent(),
    double? weight,
    int? firstSeen,
    int? lastSeen,
    Value<int?> evidenceEpisode = const Value.absent(),
    Value<int?> invalidatedAt = const Value.absent(),
  }) => Edge(
    id: id ?? this.id,
    src: src ?? this.src,
    dst: dst ?? this.dst,
    kind: kind ?? this.kind,
    label: label.present ? label.value : this.label,
    weight: weight ?? this.weight,
    firstSeen: firstSeen ?? this.firstSeen,
    lastSeen: lastSeen ?? this.lastSeen,
    evidenceEpisode: evidenceEpisode.present
        ? evidenceEpisode.value
        : this.evidenceEpisode,
    invalidatedAt: invalidatedAt.present
        ? invalidatedAt.value
        : this.invalidatedAt,
  );
  Edge copyWithCompanion(EdgesCompanion data) {
    return Edge(
      id: data.id.present ? data.id.value : this.id,
      src: data.src.present ? data.src.value : this.src,
      dst: data.dst.present ? data.dst.value : this.dst,
      kind: data.kind.present ? data.kind.value : this.kind,
      label: data.label.present ? data.label.value : this.label,
      weight: data.weight.present ? data.weight.value : this.weight,
      firstSeen: data.firstSeen.present ? data.firstSeen.value : this.firstSeen,
      lastSeen: data.lastSeen.present ? data.lastSeen.value : this.lastSeen,
      evidenceEpisode: data.evidenceEpisode.present
          ? data.evidenceEpisode.value
          : this.evidenceEpisode,
      invalidatedAt: data.invalidatedAt.present
          ? data.invalidatedAt.value
          : this.invalidatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Edge(')
          ..write('id: $id, ')
          ..write('src: $src, ')
          ..write('dst: $dst, ')
          ..write('kind: $kind, ')
          ..write('label: $label, ')
          ..write('weight: $weight, ')
          ..write('firstSeen: $firstSeen, ')
          ..write('lastSeen: $lastSeen, ')
          ..write('evidenceEpisode: $evidenceEpisode, ')
          ..write('invalidatedAt: $invalidatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    src,
    dst,
    kind,
    label,
    weight,
    firstSeen,
    lastSeen,
    evidenceEpisode,
    invalidatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Edge &&
          other.id == this.id &&
          other.src == this.src &&
          other.dst == this.dst &&
          other.kind == this.kind &&
          other.label == this.label &&
          other.weight == this.weight &&
          other.firstSeen == this.firstSeen &&
          other.lastSeen == this.lastSeen &&
          other.evidenceEpisode == this.evidenceEpisode &&
          other.invalidatedAt == this.invalidatedAt);
}

class EdgesCompanion extends UpdateCompanion<Edge> {
  final Value<int> id;
  final Value<int> src;
  final Value<int> dst;
  final Value<String> kind;
  final Value<String?> label;
  final Value<double> weight;
  final Value<int> firstSeen;
  final Value<int> lastSeen;
  final Value<int?> evidenceEpisode;
  final Value<int?> invalidatedAt;
  const EdgesCompanion({
    this.id = const Value.absent(),
    this.src = const Value.absent(),
    this.dst = const Value.absent(),
    this.kind = const Value.absent(),
    this.label = const Value.absent(),
    this.weight = const Value.absent(),
    this.firstSeen = const Value.absent(),
    this.lastSeen = const Value.absent(),
    this.evidenceEpisode = const Value.absent(),
    this.invalidatedAt = const Value.absent(),
  });
  EdgesCompanion.insert({
    this.id = const Value.absent(),
    required int src,
    required int dst,
    this.kind = const Value.absent(),
    this.label = const Value.absent(),
    this.weight = const Value.absent(),
    required int firstSeen,
    required int lastSeen,
    this.evidenceEpisode = const Value.absent(),
    this.invalidatedAt = const Value.absent(),
  }) : src = Value(src),
       dst = Value(dst),
       firstSeen = Value(firstSeen),
       lastSeen = Value(lastSeen);
  static Insertable<Edge> custom({
    Expression<int>? id,
    Expression<int>? src,
    Expression<int>? dst,
    Expression<String>? kind,
    Expression<String>? label,
    Expression<double>? weight,
    Expression<int>? firstSeen,
    Expression<int>? lastSeen,
    Expression<int>? evidenceEpisode,
    Expression<int>? invalidatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (src != null) 'src': src,
      if (dst != null) 'dst': dst,
      if (kind != null) 'kind': kind,
      if (label != null) 'label': label,
      if (weight != null) 'weight': weight,
      if (firstSeen != null) 'first_seen': firstSeen,
      if (lastSeen != null) 'last_seen': lastSeen,
      if (evidenceEpisode != null) 'evidence_episode': evidenceEpisode,
      if (invalidatedAt != null) 'invalidated_at': invalidatedAt,
    });
  }

  EdgesCompanion copyWith({
    Value<int>? id,
    Value<int>? src,
    Value<int>? dst,
    Value<String>? kind,
    Value<String?>? label,
    Value<double>? weight,
    Value<int>? firstSeen,
    Value<int>? lastSeen,
    Value<int?>? evidenceEpisode,
    Value<int?>? invalidatedAt,
  }) {
    return EdgesCompanion(
      id: id ?? this.id,
      src: src ?? this.src,
      dst: dst ?? this.dst,
      kind: kind ?? this.kind,
      label: label ?? this.label,
      weight: weight ?? this.weight,
      firstSeen: firstSeen ?? this.firstSeen,
      lastSeen: lastSeen ?? this.lastSeen,
      evidenceEpisode: evidenceEpisode ?? this.evidenceEpisode,
      invalidatedAt: invalidatedAt ?? this.invalidatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (src.present) {
      map['src'] = Variable<int>(src.value);
    }
    if (dst.present) {
      map['dst'] = Variable<int>(dst.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (weight.present) {
      map['weight'] = Variable<double>(weight.value);
    }
    if (firstSeen.present) {
      map['first_seen'] = Variable<int>(firstSeen.value);
    }
    if (lastSeen.present) {
      map['last_seen'] = Variable<int>(lastSeen.value);
    }
    if (evidenceEpisode.present) {
      map['evidence_episode'] = Variable<int>(evidenceEpisode.value);
    }
    if (invalidatedAt.present) {
      map['invalidated_at'] = Variable<int>(invalidatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EdgesCompanion(')
          ..write('id: $id, ')
          ..write('src: $src, ')
          ..write('dst: $dst, ')
          ..write('kind: $kind, ')
          ..write('label: $label, ')
          ..write('weight: $weight, ')
          ..write('firstSeen: $firstSeen, ')
          ..write('lastSeen: $lastSeen, ')
          ..write('evidenceEpisode: $evidenceEpisode, ')
          ..write('invalidatedAt: $invalidatedAt')
          ..write(')'))
        .toString();
  }
}

class $BlocksTable extends Blocks with TableInfo<$BlocksTable, Block> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BlocksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _tierMeta = const VerificationMeta('tier');
  @override
  late final GeneratedColumn<int> tier = GeneratedColumn<int>(
    'tier',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _topicMeta = const VerificationMeta('topic');
  @override
  late final GeneratedColumn<String> topic = GeneratedColumn<String>(
    'topic',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _summaryMeta = const VerificationMeta(
    'summary',
  );
  @override
  late final GeneratedColumn<String> summary = GeneratedColumn<String>(
    'summary',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _directIdsMeta = const VerificationMeta(
    'directIds',
  );
  @override
  late final GeneratedColumn<String> directIds = GeneratedColumn<String>(
    'direct_ids',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _effectiveIdsMeta = const VerificationMeta(
    'effectiveIds',
  );
  @override
  late final GeneratedColumn<String> effectiveIds = GeneratedColumn<String>(
    'effective_ids',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _spanFromMeta = const VerificationMeta(
    'spanFrom',
  );
  @override
  late final GeneratedColumn<int> spanFrom = GeneratedColumn<int>(
    'span_from',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _spanToMeta = const VerificationMeta('spanTo');
  @override
  late final GeneratedColumn<int> spanTo = GeneratedColumn<int>(
    'span_to',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tier,
    topic,
    summary,
    directIds,
    effectiveIds,
    createdAt,
    spanFrom,
    spanTo,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'blocks';
  @override
  VerificationContext validateIntegrity(
    Insertable<Block> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('tier')) {
      context.handle(
        _tierMeta,
        tier.isAcceptableOrUnknown(data['tier']!, _tierMeta),
      );
    } else if (isInserting) {
      context.missing(_tierMeta);
    }
    if (data.containsKey('topic')) {
      context.handle(
        _topicMeta,
        topic.isAcceptableOrUnknown(data['topic']!, _topicMeta),
      );
    }
    if (data.containsKey('summary')) {
      context.handle(
        _summaryMeta,
        summary.isAcceptableOrUnknown(data['summary']!, _summaryMeta),
      );
    } else if (isInserting) {
      context.missing(_summaryMeta);
    }
    if (data.containsKey('direct_ids')) {
      context.handle(
        _directIdsMeta,
        directIds.isAcceptableOrUnknown(data['direct_ids']!, _directIdsMeta),
      );
    } else if (isInserting) {
      context.missing(_directIdsMeta);
    }
    if (data.containsKey('effective_ids')) {
      context.handle(
        _effectiveIdsMeta,
        effectiveIds.isAcceptableOrUnknown(
          data['effective_ids']!,
          _effectiveIdsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_effectiveIdsMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('span_from')) {
      context.handle(
        _spanFromMeta,
        spanFrom.isAcceptableOrUnknown(data['span_from']!, _spanFromMeta),
      );
    }
    if (data.containsKey('span_to')) {
      context.handle(
        _spanToMeta,
        spanTo.isAcceptableOrUnknown(data['span_to']!, _spanToMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Block map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Block(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      tier: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tier'],
      )!,
      topic: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}topic'],
      ),
      summary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary'],
      )!,
      directIds: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}direct_ids'],
      )!,
      effectiveIds: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}effective_ids'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      spanFrom: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}span_from'],
      ),
      spanTo: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}span_to'],
      ),
    );
  }

  @override
  $BlocksTable createAlias(String alias) {
    return $BlocksTable(attachedDatabase, alias);
  }
}

class Block extends DataClass implements Insertable<Block> {
  final int id;
  final int tier;
  final String? topic;
  final String summary;

  /// JSON 数组：上一层 block id 或 episode id。
  final String directIds;

  /// JSON 数组：覆盖到的全部 episode id。
  final String effectiveIds;
  final int createdAt;
  final int? spanFrom;
  final int? spanTo;
  const Block({
    required this.id,
    required this.tier,
    this.topic,
    required this.summary,
    required this.directIds,
    required this.effectiveIds,
    required this.createdAt,
    this.spanFrom,
    this.spanTo,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['tier'] = Variable<int>(tier);
    if (!nullToAbsent || topic != null) {
      map['topic'] = Variable<String>(topic);
    }
    map['summary'] = Variable<String>(summary);
    map['direct_ids'] = Variable<String>(directIds);
    map['effective_ids'] = Variable<String>(effectiveIds);
    map['created_at'] = Variable<int>(createdAt);
    if (!nullToAbsent || spanFrom != null) {
      map['span_from'] = Variable<int>(spanFrom);
    }
    if (!nullToAbsent || spanTo != null) {
      map['span_to'] = Variable<int>(spanTo);
    }
    return map;
  }

  BlocksCompanion toCompanion(bool nullToAbsent) {
    return BlocksCompanion(
      id: Value(id),
      tier: Value(tier),
      topic: topic == null && nullToAbsent
          ? const Value.absent()
          : Value(topic),
      summary: Value(summary),
      directIds: Value(directIds),
      effectiveIds: Value(effectiveIds),
      createdAt: Value(createdAt),
      spanFrom: spanFrom == null && nullToAbsent
          ? const Value.absent()
          : Value(spanFrom),
      spanTo: spanTo == null && nullToAbsent
          ? const Value.absent()
          : Value(spanTo),
    );
  }

  factory Block.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Block(
      id: serializer.fromJson<int>(json['id']),
      tier: serializer.fromJson<int>(json['tier']),
      topic: serializer.fromJson<String?>(json['topic']),
      summary: serializer.fromJson<String>(json['summary']),
      directIds: serializer.fromJson<String>(json['directIds']),
      effectiveIds: serializer.fromJson<String>(json['effectiveIds']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      spanFrom: serializer.fromJson<int?>(json['spanFrom']),
      spanTo: serializer.fromJson<int?>(json['spanTo']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'tier': serializer.toJson<int>(tier),
      'topic': serializer.toJson<String?>(topic),
      'summary': serializer.toJson<String>(summary),
      'directIds': serializer.toJson<String>(directIds),
      'effectiveIds': serializer.toJson<String>(effectiveIds),
      'createdAt': serializer.toJson<int>(createdAt),
      'spanFrom': serializer.toJson<int?>(spanFrom),
      'spanTo': serializer.toJson<int?>(spanTo),
    };
  }

  Block copyWith({
    int? id,
    int? tier,
    Value<String?> topic = const Value.absent(),
    String? summary,
    String? directIds,
    String? effectiveIds,
    int? createdAt,
    Value<int?> spanFrom = const Value.absent(),
    Value<int?> spanTo = const Value.absent(),
  }) => Block(
    id: id ?? this.id,
    tier: tier ?? this.tier,
    topic: topic.present ? topic.value : this.topic,
    summary: summary ?? this.summary,
    directIds: directIds ?? this.directIds,
    effectiveIds: effectiveIds ?? this.effectiveIds,
    createdAt: createdAt ?? this.createdAt,
    spanFrom: spanFrom.present ? spanFrom.value : this.spanFrom,
    spanTo: spanTo.present ? spanTo.value : this.spanTo,
  );
  Block copyWithCompanion(BlocksCompanion data) {
    return Block(
      id: data.id.present ? data.id.value : this.id,
      tier: data.tier.present ? data.tier.value : this.tier,
      topic: data.topic.present ? data.topic.value : this.topic,
      summary: data.summary.present ? data.summary.value : this.summary,
      directIds: data.directIds.present ? data.directIds.value : this.directIds,
      effectiveIds: data.effectiveIds.present
          ? data.effectiveIds.value
          : this.effectiveIds,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      spanFrom: data.spanFrom.present ? data.spanFrom.value : this.spanFrom,
      spanTo: data.spanTo.present ? data.spanTo.value : this.spanTo,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Block(')
          ..write('id: $id, ')
          ..write('tier: $tier, ')
          ..write('topic: $topic, ')
          ..write('summary: $summary, ')
          ..write('directIds: $directIds, ')
          ..write('effectiveIds: $effectiveIds, ')
          ..write('createdAt: $createdAt, ')
          ..write('spanFrom: $spanFrom, ')
          ..write('spanTo: $spanTo')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    tier,
    topic,
    summary,
    directIds,
    effectiveIds,
    createdAt,
    spanFrom,
    spanTo,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Block &&
          other.id == this.id &&
          other.tier == this.tier &&
          other.topic == this.topic &&
          other.summary == this.summary &&
          other.directIds == this.directIds &&
          other.effectiveIds == this.effectiveIds &&
          other.createdAt == this.createdAt &&
          other.spanFrom == this.spanFrom &&
          other.spanTo == this.spanTo);
}

class BlocksCompanion extends UpdateCompanion<Block> {
  final Value<int> id;
  final Value<int> tier;
  final Value<String?> topic;
  final Value<String> summary;
  final Value<String> directIds;
  final Value<String> effectiveIds;
  final Value<int> createdAt;
  final Value<int?> spanFrom;
  final Value<int?> spanTo;
  const BlocksCompanion({
    this.id = const Value.absent(),
    this.tier = const Value.absent(),
    this.topic = const Value.absent(),
    this.summary = const Value.absent(),
    this.directIds = const Value.absent(),
    this.effectiveIds = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.spanFrom = const Value.absent(),
    this.spanTo = const Value.absent(),
  });
  BlocksCompanion.insert({
    this.id = const Value.absent(),
    required int tier,
    this.topic = const Value.absent(),
    required String summary,
    required String directIds,
    required String effectiveIds,
    required int createdAt,
    this.spanFrom = const Value.absent(),
    this.spanTo = const Value.absent(),
  }) : tier = Value(tier),
       summary = Value(summary),
       directIds = Value(directIds),
       effectiveIds = Value(effectiveIds),
       createdAt = Value(createdAt);
  static Insertable<Block> custom({
    Expression<int>? id,
    Expression<int>? tier,
    Expression<String>? topic,
    Expression<String>? summary,
    Expression<String>? directIds,
    Expression<String>? effectiveIds,
    Expression<int>? createdAt,
    Expression<int>? spanFrom,
    Expression<int>? spanTo,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tier != null) 'tier': tier,
      if (topic != null) 'topic': topic,
      if (summary != null) 'summary': summary,
      if (directIds != null) 'direct_ids': directIds,
      if (effectiveIds != null) 'effective_ids': effectiveIds,
      if (createdAt != null) 'created_at': createdAt,
      if (spanFrom != null) 'span_from': spanFrom,
      if (spanTo != null) 'span_to': spanTo,
    });
  }

  BlocksCompanion copyWith({
    Value<int>? id,
    Value<int>? tier,
    Value<String?>? topic,
    Value<String>? summary,
    Value<String>? directIds,
    Value<String>? effectiveIds,
    Value<int>? createdAt,
    Value<int?>? spanFrom,
    Value<int?>? spanTo,
  }) {
    return BlocksCompanion(
      id: id ?? this.id,
      tier: tier ?? this.tier,
      topic: topic ?? this.topic,
      summary: summary ?? this.summary,
      directIds: directIds ?? this.directIds,
      effectiveIds: effectiveIds ?? this.effectiveIds,
      createdAt: createdAt ?? this.createdAt,
      spanFrom: spanFrom ?? this.spanFrom,
      spanTo: spanTo ?? this.spanTo,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (tier.present) {
      map['tier'] = Variable<int>(tier.value);
    }
    if (topic.present) {
      map['topic'] = Variable<String>(topic.value);
    }
    if (summary.present) {
      map['summary'] = Variable<String>(summary.value);
    }
    if (directIds.present) {
      map['direct_ids'] = Variable<String>(directIds.value);
    }
    if (effectiveIds.present) {
      map['effective_ids'] = Variable<String>(effectiveIds.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (spanFrom.present) {
      map['span_from'] = Variable<int>(spanFrom.value);
    }
    if (spanTo.present) {
      map['span_to'] = Variable<int>(spanTo.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BlocksCompanion(')
          ..write('id: $id, ')
          ..write('tier: $tier, ')
          ..write('topic: $topic, ')
          ..write('summary: $summary, ')
          ..write('directIds: $directIds, ')
          ..write('effectiveIds: $effectiveIds, ')
          ..write('createdAt: $createdAt, ')
          ..write('spanFrom: $spanFrom, ')
          ..write('spanTo: $spanTo')
          ..write(')'))
        .toString();
  }
}

class $MetaRowsTable extends MetaRows with TableInfo<$MetaRowsTable, MetaRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MetaRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meta_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<MetaRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  MetaRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MetaRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $MetaRowsTable createAlias(String alias) {
    return $MetaRowsTable(attachedDatabase, alias);
  }
}

class MetaRow extends DataClass implements Insertable<MetaRow> {
  final String key;
  final String value;
  const MetaRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  MetaRowsCompanion toCompanion(bool nullToAbsent) {
    return MetaRowsCompanion(key: Value(key), value: Value(value));
  }

  factory MetaRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MetaRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  MetaRow copyWith({String? key, String? value}) =>
      MetaRow(key: key ?? this.key, value: value ?? this.value);
  MetaRow copyWithCompanion(MetaRowsCompanion data) {
    return MetaRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MetaRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MetaRow && other.key == this.key && other.value == this.value);
}

class MetaRowsCompanion extends UpdateCompanion<MetaRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const MetaRowsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MetaRowsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<MetaRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MetaRowsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return MetaRowsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MetaRowsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$MemoryDb extends GeneratedDatabase {
  _$MemoryDb(QueryExecutor e) : super(e);
  $MemoryDbManager get managers => $MemoryDbManager(this);
  late final $EpisodesTable episodes = $EpisodesTable(this);
  late final $FactsTable facts = $FactsTable(this);
  late final $EntitiesTable entities = $EntitiesTable(this);
  late final $EdgesTable edges = $EdgesTable(this);
  late final $BlocksTable blocks = $BlocksTable(this);
  late final $MetaRowsTable metaRows = $MetaRowsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    episodes,
    facts,
    entities,
    edges,
    blocks,
    metaRows,
  ];
}

typedef $$EpisodesTableCreateCompanionBuilder =
    EpisodesCompanion Function({
      Value<int> id,
      required int at,
      Value<String?> session,
      Value<String?> place,
      required String title,
      required String body,
      Value<String?> rawRef,
      Value<double> weight,
      Value<Uint8List?> vec,
      Value<int> vecDims,
      Value<bool> localOnly,
    });
typedef $$EpisodesTableUpdateCompanionBuilder =
    EpisodesCompanion Function({
      Value<int> id,
      Value<int> at,
      Value<String?> session,
      Value<String?> place,
      Value<String> title,
      Value<String> body,
      Value<String?> rawRef,
      Value<double> weight,
      Value<Uint8List?> vec,
      Value<int> vecDims,
      Value<bool> localOnly,
    });

class $$EpisodesTableFilterComposer
    extends Composer<_$MemoryDb, $EpisodesTable> {
  $$EpisodesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get session => $composableBuilder(
    column: $table.session,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get place => $composableBuilder(
    column: $table.place,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rawRef => $composableBuilder(
    column: $table.rawRef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get weight => $composableBuilder(
    column: $table.weight,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get vec => $composableBuilder(
    column: $table.vec,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get vecDims => $composableBuilder(
    column: $table.vecDims,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get localOnly => $composableBuilder(
    column: $table.localOnly,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EpisodesTableOrderingComposer
    extends Composer<_$MemoryDb, $EpisodesTable> {
  $$EpisodesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get session => $composableBuilder(
    column: $table.session,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get place => $composableBuilder(
    column: $table.place,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rawRef => $composableBuilder(
    column: $table.rawRef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get weight => $composableBuilder(
    column: $table.weight,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get vec => $composableBuilder(
    column: $table.vec,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get vecDims => $composableBuilder(
    column: $table.vecDims,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get localOnly => $composableBuilder(
    column: $table.localOnly,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EpisodesTableAnnotationComposer
    extends Composer<_$MemoryDb, $EpisodesTable> {
  $$EpisodesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get at =>
      $composableBuilder(column: $table.at, builder: (column) => column);

  GeneratedColumn<String> get session =>
      $composableBuilder(column: $table.session, builder: (column) => column);

  GeneratedColumn<String> get place =>
      $composableBuilder(column: $table.place, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get rawRef =>
      $composableBuilder(column: $table.rawRef, builder: (column) => column);

  GeneratedColumn<double> get weight =>
      $composableBuilder(column: $table.weight, builder: (column) => column);

  GeneratedColumn<Uint8List> get vec =>
      $composableBuilder(column: $table.vec, builder: (column) => column);

  GeneratedColumn<int> get vecDims =>
      $composableBuilder(column: $table.vecDims, builder: (column) => column);

  GeneratedColumn<bool> get localOnly =>
      $composableBuilder(column: $table.localOnly, builder: (column) => column);
}

class $$EpisodesTableTableManager
    extends
        RootTableManager<
          _$MemoryDb,
          $EpisodesTable,
          Episode,
          $$EpisodesTableFilterComposer,
          $$EpisodesTableOrderingComposer,
          $$EpisodesTableAnnotationComposer,
          $$EpisodesTableCreateCompanionBuilder,
          $$EpisodesTableUpdateCompanionBuilder,
          (Episode, BaseReferences<_$MemoryDb, $EpisodesTable, Episode>),
          Episode,
          PrefetchHooks Function()
        > {
  $$EpisodesTableTableManager(_$MemoryDb db, $EpisodesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EpisodesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EpisodesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EpisodesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> at = const Value.absent(),
                Value<String?> session = const Value.absent(),
                Value<String?> place = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<String?> rawRef = const Value.absent(),
                Value<double> weight = const Value.absent(),
                Value<Uint8List?> vec = const Value.absent(),
                Value<int> vecDims = const Value.absent(),
                Value<bool> localOnly = const Value.absent(),
              }) => EpisodesCompanion(
                id: id,
                at: at,
                session: session,
                place: place,
                title: title,
                body: body,
                rawRef: rawRef,
                weight: weight,
                vec: vec,
                vecDims: vecDims,
                localOnly: localOnly,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int at,
                Value<String?> session = const Value.absent(),
                Value<String?> place = const Value.absent(),
                required String title,
                required String body,
                Value<String?> rawRef = const Value.absent(),
                Value<double> weight = const Value.absent(),
                Value<Uint8List?> vec = const Value.absent(),
                Value<int> vecDims = const Value.absent(),
                Value<bool> localOnly = const Value.absent(),
              }) => EpisodesCompanion.insert(
                id: id,
                at: at,
                session: session,
                place: place,
                title: title,
                body: body,
                rawRef: rawRef,
                weight: weight,
                vec: vec,
                vecDims: vecDims,
                localOnly: localOnly,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EpisodesTableProcessedTableManager =
    ProcessedTableManager<
      _$MemoryDb,
      $EpisodesTable,
      Episode,
      $$EpisodesTableFilterComposer,
      $$EpisodesTableOrderingComposer,
      $$EpisodesTableAnnotationComposer,
      $$EpisodesTableCreateCompanionBuilder,
      $$EpisodesTableUpdateCompanionBuilder,
      (Episode, BaseReferences<_$MemoryDb, $EpisodesTable, Episode>),
      Episode,
      PrefetchHooks Function()
    >;
typedef $$FactsTableCreateCompanionBuilder =
    FactsCompanion Function({
      Value<int> id,
      required String content,
      Value<String?> subject,
      Value<String?> predicate,
      Value<String?> object,
      Value<double> confidence,
      Value<int> importance,
      required int firstSeen,
      required int lastSeen,
      Value<int> hitCount,
      Value<int?> evidenceEpisode,
      Value<int?> invalidatedAt,
      Value<bool> localOnly,
    });
typedef $$FactsTableUpdateCompanionBuilder =
    FactsCompanion Function({
      Value<int> id,
      Value<String> content,
      Value<String?> subject,
      Value<String?> predicate,
      Value<String?> object,
      Value<double> confidence,
      Value<int> importance,
      Value<int> firstSeen,
      Value<int> lastSeen,
      Value<int> hitCount,
      Value<int?> evidenceEpisode,
      Value<int?> invalidatedAt,
      Value<bool> localOnly,
    });

class $$FactsTableFilterComposer extends Composer<_$MemoryDb, $FactsTable> {
  $$FactsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subject => $composableBuilder(
    column: $table.subject,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get predicate => $composableBuilder(
    column: $table.predicate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get object => $composableBuilder(
    column: $table.object,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get importance => $composableBuilder(
    column: $table.importance,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get firstSeen => $composableBuilder(
    column: $table.firstSeen,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastSeen => $composableBuilder(
    column: $table.lastSeen,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get hitCount => $composableBuilder(
    column: $table.hitCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get evidenceEpisode => $composableBuilder(
    column: $table.evidenceEpisode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get invalidatedAt => $composableBuilder(
    column: $table.invalidatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get localOnly => $composableBuilder(
    column: $table.localOnly,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FactsTableOrderingComposer extends Composer<_$MemoryDb, $FactsTable> {
  $$FactsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subject => $composableBuilder(
    column: $table.subject,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get predicate => $composableBuilder(
    column: $table.predicate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get object => $composableBuilder(
    column: $table.object,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get importance => $composableBuilder(
    column: $table.importance,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get firstSeen => $composableBuilder(
    column: $table.firstSeen,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSeen => $composableBuilder(
    column: $table.lastSeen,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get hitCount => $composableBuilder(
    column: $table.hitCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get evidenceEpisode => $composableBuilder(
    column: $table.evidenceEpisode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get invalidatedAt => $composableBuilder(
    column: $table.invalidatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get localOnly => $composableBuilder(
    column: $table.localOnly,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FactsTableAnnotationComposer extends Composer<_$MemoryDb, $FactsTable> {
  $$FactsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get subject =>
      $composableBuilder(column: $table.subject, builder: (column) => column);

  GeneratedColumn<String> get predicate =>
      $composableBuilder(column: $table.predicate, builder: (column) => column);

  GeneratedColumn<String> get object =>
      $composableBuilder(column: $table.object, builder: (column) => column);

  GeneratedColumn<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => column,
  );

  GeneratedColumn<int> get importance => $composableBuilder(
    column: $table.importance,
    builder: (column) => column,
  );

  GeneratedColumn<int> get firstSeen =>
      $composableBuilder(column: $table.firstSeen, builder: (column) => column);

  GeneratedColumn<int> get lastSeen =>
      $composableBuilder(column: $table.lastSeen, builder: (column) => column);

  GeneratedColumn<int> get hitCount =>
      $composableBuilder(column: $table.hitCount, builder: (column) => column);

  GeneratedColumn<int> get evidenceEpisode => $composableBuilder(
    column: $table.evidenceEpisode,
    builder: (column) => column,
  );

  GeneratedColumn<int> get invalidatedAt => $composableBuilder(
    column: $table.invalidatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get localOnly =>
      $composableBuilder(column: $table.localOnly, builder: (column) => column);
}

class $$FactsTableTableManager
    extends
        RootTableManager<
          _$MemoryDb,
          $FactsTable,
          Fact,
          $$FactsTableFilterComposer,
          $$FactsTableOrderingComposer,
          $$FactsTableAnnotationComposer,
          $$FactsTableCreateCompanionBuilder,
          $$FactsTableUpdateCompanionBuilder,
          (Fact, BaseReferences<_$MemoryDb, $FactsTable, Fact>),
          Fact,
          PrefetchHooks Function()
        > {
  $$FactsTableTableManager(_$MemoryDb db, $FactsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FactsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FactsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FactsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String?> subject = const Value.absent(),
                Value<String?> predicate = const Value.absent(),
                Value<String?> object = const Value.absent(),
                Value<double> confidence = const Value.absent(),
                Value<int> importance = const Value.absent(),
                Value<int> firstSeen = const Value.absent(),
                Value<int> lastSeen = const Value.absent(),
                Value<int> hitCount = const Value.absent(),
                Value<int?> evidenceEpisode = const Value.absent(),
                Value<int?> invalidatedAt = const Value.absent(),
                Value<bool> localOnly = const Value.absent(),
              }) => FactsCompanion(
                id: id,
                content: content,
                subject: subject,
                predicate: predicate,
                object: object,
                confidence: confidence,
                importance: importance,
                firstSeen: firstSeen,
                lastSeen: lastSeen,
                hitCount: hitCount,
                evidenceEpisode: evidenceEpisode,
                invalidatedAt: invalidatedAt,
                localOnly: localOnly,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String content,
                Value<String?> subject = const Value.absent(),
                Value<String?> predicate = const Value.absent(),
                Value<String?> object = const Value.absent(),
                Value<double> confidence = const Value.absent(),
                Value<int> importance = const Value.absent(),
                required int firstSeen,
                required int lastSeen,
                Value<int> hitCount = const Value.absent(),
                Value<int?> evidenceEpisode = const Value.absent(),
                Value<int?> invalidatedAt = const Value.absent(),
                Value<bool> localOnly = const Value.absent(),
              }) => FactsCompanion.insert(
                id: id,
                content: content,
                subject: subject,
                predicate: predicate,
                object: object,
                confidence: confidence,
                importance: importance,
                firstSeen: firstSeen,
                lastSeen: lastSeen,
                hitCount: hitCount,
                evidenceEpisode: evidenceEpisode,
                invalidatedAt: invalidatedAt,
                localOnly: localOnly,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FactsTableProcessedTableManager =
    ProcessedTableManager<
      _$MemoryDb,
      $FactsTable,
      Fact,
      $$FactsTableFilterComposer,
      $$FactsTableOrderingComposer,
      $$FactsTableAnnotationComposer,
      $$FactsTableCreateCompanionBuilder,
      $$FactsTableUpdateCompanionBuilder,
      (Fact, BaseReferences<_$MemoryDb, $FactsTable, Fact>),
      Fact,
      PrefetchHooks Function()
    >;
typedef $$EntitiesTableCreateCompanionBuilder =
    EntitiesCompanion Function({
      Value<int> id,
      required String name,
      Value<String?> alias,
      Value<String> kind,
      Value<int> importance,
      Value<double> strength,
      required int firstSeen,
      required int lastTouched,
      Value<String?> summary,
      Value<double?> x,
      Value<double?> y,
    });
typedef $$EntitiesTableUpdateCompanionBuilder =
    EntitiesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String?> alias,
      Value<String> kind,
      Value<int> importance,
      Value<double> strength,
      Value<int> firstSeen,
      Value<int> lastTouched,
      Value<String?> summary,
      Value<double?> x,
      Value<double?> y,
    });

class $$EntitiesTableFilterComposer
    extends Composer<_$MemoryDb, $EntitiesTable> {
  $$EntitiesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get alias => $composableBuilder(
    column: $table.alias,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get importance => $composableBuilder(
    column: $table.importance,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get strength => $composableBuilder(
    column: $table.strength,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get firstSeen => $composableBuilder(
    column: $table.firstSeen,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastTouched => $composableBuilder(
    column: $table.lastTouched,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get x => $composableBuilder(
    column: $table.x,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get y => $composableBuilder(
    column: $table.y,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EntitiesTableOrderingComposer
    extends Composer<_$MemoryDb, $EntitiesTable> {
  $$EntitiesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get alias => $composableBuilder(
    column: $table.alias,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get importance => $composableBuilder(
    column: $table.importance,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get strength => $composableBuilder(
    column: $table.strength,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get firstSeen => $composableBuilder(
    column: $table.firstSeen,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastTouched => $composableBuilder(
    column: $table.lastTouched,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get x => $composableBuilder(
    column: $table.x,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get y => $composableBuilder(
    column: $table.y,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EntitiesTableAnnotationComposer
    extends Composer<_$MemoryDb, $EntitiesTable> {
  $$EntitiesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get alias =>
      $composableBuilder(column: $table.alias, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get importance => $composableBuilder(
    column: $table.importance,
    builder: (column) => column,
  );

  GeneratedColumn<double> get strength =>
      $composableBuilder(column: $table.strength, builder: (column) => column);

  GeneratedColumn<int> get firstSeen =>
      $composableBuilder(column: $table.firstSeen, builder: (column) => column);

  GeneratedColumn<int> get lastTouched => $composableBuilder(
    column: $table.lastTouched,
    builder: (column) => column,
  );

  GeneratedColumn<String> get summary =>
      $composableBuilder(column: $table.summary, builder: (column) => column);

  GeneratedColumn<double> get x =>
      $composableBuilder(column: $table.x, builder: (column) => column);

  GeneratedColumn<double> get y =>
      $composableBuilder(column: $table.y, builder: (column) => column);
}

class $$EntitiesTableTableManager
    extends
        RootTableManager<
          _$MemoryDb,
          $EntitiesTable,
          Entity,
          $$EntitiesTableFilterComposer,
          $$EntitiesTableOrderingComposer,
          $$EntitiesTableAnnotationComposer,
          $$EntitiesTableCreateCompanionBuilder,
          $$EntitiesTableUpdateCompanionBuilder,
          (Entity, BaseReferences<_$MemoryDb, $EntitiesTable, Entity>),
          Entity,
          PrefetchHooks Function()
        > {
  $$EntitiesTableTableManager(_$MemoryDb db, $EntitiesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EntitiesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EntitiesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EntitiesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> alias = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<int> importance = const Value.absent(),
                Value<double> strength = const Value.absent(),
                Value<int> firstSeen = const Value.absent(),
                Value<int> lastTouched = const Value.absent(),
                Value<String?> summary = const Value.absent(),
                Value<double?> x = const Value.absent(),
                Value<double?> y = const Value.absent(),
              }) => EntitiesCompanion(
                id: id,
                name: name,
                alias: alias,
                kind: kind,
                importance: importance,
                strength: strength,
                firstSeen: firstSeen,
                lastTouched: lastTouched,
                summary: summary,
                x: x,
                y: y,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String?> alias = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<int> importance = const Value.absent(),
                Value<double> strength = const Value.absent(),
                required int firstSeen,
                required int lastTouched,
                Value<String?> summary = const Value.absent(),
                Value<double?> x = const Value.absent(),
                Value<double?> y = const Value.absent(),
              }) => EntitiesCompanion.insert(
                id: id,
                name: name,
                alias: alias,
                kind: kind,
                importance: importance,
                strength: strength,
                firstSeen: firstSeen,
                lastTouched: lastTouched,
                summary: summary,
                x: x,
                y: y,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EntitiesTableProcessedTableManager =
    ProcessedTableManager<
      _$MemoryDb,
      $EntitiesTable,
      Entity,
      $$EntitiesTableFilterComposer,
      $$EntitiesTableOrderingComposer,
      $$EntitiesTableAnnotationComposer,
      $$EntitiesTableCreateCompanionBuilder,
      $$EntitiesTableUpdateCompanionBuilder,
      (Entity, BaseReferences<_$MemoryDb, $EntitiesTable, Entity>),
      Entity,
      PrefetchHooks Function()
    >;
typedef $$EdgesTableCreateCompanionBuilder =
    EdgesCompanion Function({
      Value<int> id,
      required int src,
      required int dst,
      Value<String> kind,
      Value<String?> label,
      Value<double> weight,
      required int firstSeen,
      required int lastSeen,
      Value<int?> evidenceEpisode,
      Value<int?> invalidatedAt,
    });
typedef $$EdgesTableUpdateCompanionBuilder =
    EdgesCompanion Function({
      Value<int> id,
      Value<int> src,
      Value<int> dst,
      Value<String> kind,
      Value<String?> label,
      Value<double> weight,
      Value<int> firstSeen,
      Value<int> lastSeen,
      Value<int?> evidenceEpisode,
      Value<int?> invalidatedAt,
    });

class $$EdgesTableFilterComposer extends Composer<_$MemoryDb, $EdgesTable> {
  $$EdgesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get src => $composableBuilder(
    column: $table.src,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dst => $composableBuilder(
    column: $table.dst,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get weight => $composableBuilder(
    column: $table.weight,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get firstSeen => $composableBuilder(
    column: $table.firstSeen,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastSeen => $composableBuilder(
    column: $table.lastSeen,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get evidenceEpisode => $composableBuilder(
    column: $table.evidenceEpisode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get invalidatedAt => $composableBuilder(
    column: $table.invalidatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EdgesTableOrderingComposer extends Composer<_$MemoryDb, $EdgesTable> {
  $$EdgesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get src => $composableBuilder(
    column: $table.src,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dst => $composableBuilder(
    column: $table.dst,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get weight => $composableBuilder(
    column: $table.weight,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get firstSeen => $composableBuilder(
    column: $table.firstSeen,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSeen => $composableBuilder(
    column: $table.lastSeen,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get evidenceEpisode => $composableBuilder(
    column: $table.evidenceEpisode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get invalidatedAt => $composableBuilder(
    column: $table.invalidatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EdgesTableAnnotationComposer extends Composer<_$MemoryDb, $EdgesTable> {
  $$EdgesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get src =>
      $composableBuilder(column: $table.src, builder: (column) => column);

  GeneratedColumn<int> get dst =>
      $composableBuilder(column: $table.dst, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<double> get weight =>
      $composableBuilder(column: $table.weight, builder: (column) => column);

  GeneratedColumn<int> get firstSeen =>
      $composableBuilder(column: $table.firstSeen, builder: (column) => column);

  GeneratedColumn<int> get lastSeen =>
      $composableBuilder(column: $table.lastSeen, builder: (column) => column);

  GeneratedColumn<int> get evidenceEpisode => $composableBuilder(
    column: $table.evidenceEpisode,
    builder: (column) => column,
  );

  GeneratedColumn<int> get invalidatedAt => $composableBuilder(
    column: $table.invalidatedAt,
    builder: (column) => column,
  );
}

class $$EdgesTableTableManager
    extends
        RootTableManager<
          _$MemoryDb,
          $EdgesTable,
          Edge,
          $$EdgesTableFilterComposer,
          $$EdgesTableOrderingComposer,
          $$EdgesTableAnnotationComposer,
          $$EdgesTableCreateCompanionBuilder,
          $$EdgesTableUpdateCompanionBuilder,
          (Edge, BaseReferences<_$MemoryDb, $EdgesTable, Edge>),
          Edge,
          PrefetchHooks Function()
        > {
  $$EdgesTableTableManager(_$MemoryDb db, $EdgesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EdgesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EdgesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EdgesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> src = const Value.absent(),
                Value<int> dst = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String?> label = const Value.absent(),
                Value<double> weight = const Value.absent(),
                Value<int> firstSeen = const Value.absent(),
                Value<int> lastSeen = const Value.absent(),
                Value<int?> evidenceEpisode = const Value.absent(),
                Value<int?> invalidatedAt = const Value.absent(),
              }) => EdgesCompanion(
                id: id,
                src: src,
                dst: dst,
                kind: kind,
                label: label,
                weight: weight,
                firstSeen: firstSeen,
                lastSeen: lastSeen,
                evidenceEpisode: evidenceEpisode,
                invalidatedAt: invalidatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int src,
                required int dst,
                Value<String> kind = const Value.absent(),
                Value<String?> label = const Value.absent(),
                Value<double> weight = const Value.absent(),
                required int firstSeen,
                required int lastSeen,
                Value<int?> evidenceEpisode = const Value.absent(),
                Value<int?> invalidatedAt = const Value.absent(),
              }) => EdgesCompanion.insert(
                id: id,
                src: src,
                dst: dst,
                kind: kind,
                label: label,
                weight: weight,
                firstSeen: firstSeen,
                lastSeen: lastSeen,
                evidenceEpisode: evidenceEpisode,
                invalidatedAt: invalidatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EdgesTableProcessedTableManager =
    ProcessedTableManager<
      _$MemoryDb,
      $EdgesTable,
      Edge,
      $$EdgesTableFilterComposer,
      $$EdgesTableOrderingComposer,
      $$EdgesTableAnnotationComposer,
      $$EdgesTableCreateCompanionBuilder,
      $$EdgesTableUpdateCompanionBuilder,
      (Edge, BaseReferences<_$MemoryDb, $EdgesTable, Edge>),
      Edge,
      PrefetchHooks Function()
    >;
typedef $$BlocksTableCreateCompanionBuilder =
    BlocksCompanion Function({
      Value<int> id,
      required int tier,
      Value<String?> topic,
      required String summary,
      required String directIds,
      required String effectiveIds,
      required int createdAt,
      Value<int?> spanFrom,
      Value<int?> spanTo,
    });
typedef $$BlocksTableUpdateCompanionBuilder =
    BlocksCompanion Function({
      Value<int> id,
      Value<int> tier,
      Value<String?> topic,
      Value<String> summary,
      Value<String> directIds,
      Value<String> effectiveIds,
      Value<int> createdAt,
      Value<int?> spanFrom,
      Value<int?> spanTo,
    });

class $$BlocksTableFilterComposer extends Composer<_$MemoryDb, $BlocksTable> {
  $$BlocksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tier => $composableBuilder(
    column: $table.tier,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get topic => $composableBuilder(
    column: $table.topic,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get directIds => $composableBuilder(
    column: $table.directIds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get effectiveIds => $composableBuilder(
    column: $table.effectiveIds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get spanFrom => $composableBuilder(
    column: $table.spanFrom,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get spanTo => $composableBuilder(
    column: $table.spanTo,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BlocksTableOrderingComposer extends Composer<_$MemoryDb, $BlocksTable> {
  $$BlocksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tier => $composableBuilder(
    column: $table.tier,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get topic => $composableBuilder(
    column: $table.topic,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get directIds => $composableBuilder(
    column: $table.directIds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get effectiveIds => $composableBuilder(
    column: $table.effectiveIds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get spanFrom => $composableBuilder(
    column: $table.spanFrom,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get spanTo => $composableBuilder(
    column: $table.spanTo,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BlocksTableAnnotationComposer
    extends Composer<_$MemoryDb, $BlocksTable> {
  $$BlocksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get tier =>
      $composableBuilder(column: $table.tier, builder: (column) => column);

  GeneratedColumn<String> get topic =>
      $composableBuilder(column: $table.topic, builder: (column) => column);

  GeneratedColumn<String> get summary =>
      $composableBuilder(column: $table.summary, builder: (column) => column);

  GeneratedColumn<String> get directIds =>
      $composableBuilder(column: $table.directIds, builder: (column) => column);

  GeneratedColumn<String> get effectiveIds => $composableBuilder(
    column: $table.effectiveIds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get spanFrom =>
      $composableBuilder(column: $table.spanFrom, builder: (column) => column);

  GeneratedColumn<int> get spanTo =>
      $composableBuilder(column: $table.spanTo, builder: (column) => column);
}

class $$BlocksTableTableManager
    extends
        RootTableManager<
          _$MemoryDb,
          $BlocksTable,
          Block,
          $$BlocksTableFilterComposer,
          $$BlocksTableOrderingComposer,
          $$BlocksTableAnnotationComposer,
          $$BlocksTableCreateCompanionBuilder,
          $$BlocksTableUpdateCompanionBuilder,
          (Block, BaseReferences<_$MemoryDb, $BlocksTable, Block>),
          Block,
          PrefetchHooks Function()
        > {
  $$BlocksTableTableManager(_$MemoryDb db, $BlocksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BlocksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BlocksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BlocksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> tier = const Value.absent(),
                Value<String?> topic = const Value.absent(),
                Value<String> summary = const Value.absent(),
                Value<String> directIds = const Value.absent(),
                Value<String> effectiveIds = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int?> spanFrom = const Value.absent(),
                Value<int?> spanTo = const Value.absent(),
              }) => BlocksCompanion(
                id: id,
                tier: tier,
                topic: topic,
                summary: summary,
                directIds: directIds,
                effectiveIds: effectiveIds,
                createdAt: createdAt,
                spanFrom: spanFrom,
                spanTo: spanTo,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int tier,
                Value<String?> topic = const Value.absent(),
                required String summary,
                required String directIds,
                required String effectiveIds,
                required int createdAt,
                Value<int?> spanFrom = const Value.absent(),
                Value<int?> spanTo = const Value.absent(),
              }) => BlocksCompanion.insert(
                id: id,
                tier: tier,
                topic: topic,
                summary: summary,
                directIds: directIds,
                effectiveIds: effectiveIds,
                createdAt: createdAt,
                spanFrom: spanFrom,
                spanTo: spanTo,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BlocksTableProcessedTableManager =
    ProcessedTableManager<
      _$MemoryDb,
      $BlocksTable,
      Block,
      $$BlocksTableFilterComposer,
      $$BlocksTableOrderingComposer,
      $$BlocksTableAnnotationComposer,
      $$BlocksTableCreateCompanionBuilder,
      $$BlocksTableUpdateCompanionBuilder,
      (Block, BaseReferences<_$MemoryDb, $BlocksTable, Block>),
      Block,
      PrefetchHooks Function()
    >;
typedef $$MetaRowsTableCreateCompanionBuilder =
    MetaRowsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$MetaRowsTableUpdateCompanionBuilder =
    MetaRowsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$MetaRowsTableFilterComposer
    extends Composer<_$MemoryDb, $MetaRowsTable> {
  $$MetaRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MetaRowsTableOrderingComposer
    extends Composer<_$MemoryDb, $MetaRowsTable> {
  $$MetaRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MetaRowsTableAnnotationComposer
    extends Composer<_$MemoryDb, $MetaRowsTable> {
  $$MetaRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$MetaRowsTableTableManager
    extends
        RootTableManager<
          _$MemoryDb,
          $MetaRowsTable,
          MetaRow,
          $$MetaRowsTableFilterComposer,
          $$MetaRowsTableOrderingComposer,
          $$MetaRowsTableAnnotationComposer,
          $$MetaRowsTableCreateCompanionBuilder,
          $$MetaRowsTableUpdateCompanionBuilder,
          (MetaRow, BaseReferences<_$MemoryDb, $MetaRowsTable, MetaRow>),
          MetaRow,
          PrefetchHooks Function()
        > {
  $$MetaRowsTableTableManager(_$MemoryDb db, $MetaRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MetaRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MetaRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MetaRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MetaRowsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => MetaRowsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MetaRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$MemoryDb,
      $MetaRowsTable,
      MetaRow,
      $$MetaRowsTableFilterComposer,
      $$MetaRowsTableOrderingComposer,
      $$MetaRowsTableAnnotationComposer,
      $$MetaRowsTableCreateCompanionBuilder,
      $$MetaRowsTableUpdateCompanionBuilder,
      (MetaRow, BaseReferences<_$MemoryDb, $MetaRowsTable, MetaRow>),
      MetaRow,
      PrefetchHooks Function()
    >;

class $MemoryDbManager {
  final _$MemoryDb _db;
  $MemoryDbManager(this._db);
  $$EpisodesTableTableManager get episodes =>
      $$EpisodesTableTableManager(_db, _db.episodes);
  $$FactsTableTableManager get facts =>
      $$FactsTableTableManager(_db, _db.facts);
  $$EntitiesTableTableManager get entities =>
      $$EntitiesTableTableManager(_db, _db.entities);
  $$EdgesTableTableManager get edges =>
      $$EdgesTableTableManager(_db, _db.edges);
  $$BlocksTableTableManager get blocks =>
      $$BlocksTableTableManager(_db, _db.blocks);
  $$MetaRowsTableTableManager get metaRows =>
      $$MetaRowsTableTableManager(_db, _db.metaRows);
}
