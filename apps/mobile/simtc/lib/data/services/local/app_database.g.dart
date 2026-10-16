// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $SessionsTable extends Sessions with TableInfo<$SessionsTable, Session> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _companyNameMeta =
      const VerificationMeta('companyName');
  @override
  late final GeneratedColumn<String> companyName = GeneratedColumn<String>(
      'company_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _companyLogoUrlMeta =
      const VerificationMeta('companyLogoUrl');
  @override
  late final GeneratedColumn<String> companyLogoUrl = GeneratedColumn<String>(
      'company_logo_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _courseNameMeta =
      const VerificationMeta('courseName');
  @override
  late final GeneratedColumn<String> courseName = GeneratedColumn<String>(
      'course_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _cityMeta = const VerificationMeta('city');
  @override
  late final GeneratedColumn<String> city = GeneratedColumn<String>(
      'city', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
      'state', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
      'date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _totalParticipantsMeta =
      const VerificationMeta('totalParticipants');
  @override
  late final GeneratedColumn<int> totalParticipants = GeneratedColumn<int>(
      'total_participants', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _assessableParticipantsMeta =
      const VerificationMeta('assessableParticipants');
  @override
  late final GeneratedColumn<int> assessableParticipants = GeneratedColumn<int>(
      'assessable_participants', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _assessedParticipantsMeta =
      const VerificationMeta('assessedParticipants');
  @override
  late final GeneratedColumn<int> assessedParticipants = GeneratedColumn<int>(
      'assessed_participants', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _responsibleConsultantIdMeta =
      const VerificationMeta('responsibleConsultantId');
  @override
  late final GeneratedColumn<String> responsibleConsultantId =
      GeneratedColumn<String>('responsible_consultant_id', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _participantsSyncedAtMeta =
      const VerificationMeta('participantsSyncedAt');
  @override
  late final GeneratedColumn<DateTime> participantsSyncedAt =
      GeneratedColumn<DateTime>('participants_synced_at', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _cachedAtMeta =
      const VerificationMeta('cachedAt');
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
      'cached_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        companyName,
        companyLogoUrl,
        courseName,
        city,
        state,
        date,
        status,
        notes,
        totalParticipants,
        assessableParticipants,
        assessedParticipants,
        responsibleConsultantId,
        participantsSyncedAt,
        cachedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sessions';
  @override
  VerificationContext validateIntegrity(Insertable<Session> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('company_name')) {
      context.handle(
          _companyNameMeta,
          companyName.isAcceptableOrUnknown(
              data['company_name']!, _companyNameMeta));
    } else if (isInserting) {
      context.missing(_companyNameMeta);
    }
    if (data.containsKey('company_logo_url')) {
      context.handle(
          _companyLogoUrlMeta,
          companyLogoUrl.isAcceptableOrUnknown(
              data['company_logo_url']!, _companyLogoUrlMeta));
    }
    if (data.containsKey('course_name')) {
      context.handle(
          _courseNameMeta,
          courseName.isAcceptableOrUnknown(
              data['course_name']!, _courseNameMeta));
    } else if (isInserting) {
      context.missing(_courseNameMeta);
    }
    if (data.containsKey('city')) {
      context.handle(
          _cityMeta, city.isAcceptableOrUnknown(data['city']!, _cityMeta));
    } else if (isInserting) {
      context.missing(_cityMeta);
    }
    if (data.containsKey('state')) {
      context.handle(
          _stateMeta, state.isAcceptableOrUnknown(data['state']!, _stateMeta));
    } else if (isInserting) {
      context.missing(_stateMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
          _dateMeta, date.isAcceptableOrUnknown(data['date']!, _dateMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    if (data.containsKey('total_participants')) {
      context.handle(
          _totalParticipantsMeta,
          totalParticipants.isAcceptableOrUnknown(
              data['total_participants']!, _totalParticipantsMeta));
    }
    if (data.containsKey('assessable_participants')) {
      context.handle(
          _assessableParticipantsMeta,
          assessableParticipants.isAcceptableOrUnknown(
              data['assessable_participants']!, _assessableParticipantsMeta));
    }
    if (data.containsKey('assessed_participants')) {
      context.handle(
          _assessedParticipantsMeta,
          assessedParticipants.isAcceptableOrUnknown(
              data['assessed_participants']!, _assessedParticipantsMeta));
    }
    if (data.containsKey('responsible_consultant_id')) {
      context.handle(
          _responsibleConsultantIdMeta,
          responsibleConsultantId.isAcceptableOrUnknown(
              data['responsible_consultant_id']!,
              _responsibleConsultantIdMeta));
    }
    if (data.containsKey('participants_synced_at')) {
      context.handle(
          _participantsSyncedAtMeta,
          participantsSyncedAt.isAcceptableOrUnknown(
              data['participants_synced_at']!, _participantsSyncedAtMeta));
    }
    if (data.containsKey('cached_at')) {
      context.handle(_cachedAtMeta,
          cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta));
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Session map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Session(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      companyName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}company_name'])!,
      companyLogoUrl: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}company_logo_url']),
      courseName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}course_name'])!,
      city: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}city'])!,
      state: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}state'])!,
      date: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}date']),
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes']),
      totalParticipants: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}total_participants'])!,
      assessableParticipants: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}assessable_participants'])!,
      assessedParticipants: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}assessed_participants'])!,
      responsibleConsultantId: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}responsible_consultant_id']),
      participantsSyncedAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime,
          data['${effectivePrefix}participants_synced_at']),
      cachedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}cached_at'])!,
    );
  }

  @override
  $SessionsTable createAlias(String alias) {
    return $SessionsTable(attachedDatabase, alias);
  }
}

class Session extends DataClass implements Insertable<Session> {
  final String id;
  final String companyName;
  final String? companyLogoUrl;
  final String courseName;
  final String city;
  final String state;
  final DateTime? date;
  final String status;
  final String? notes;

  /// Total de participantes inscritos — mostrado na linha de meta do card.
  final int totalParticipants;

  /// Participantes que recebem avaliação prática: denominador do progresso.
  final int assessableParticipants;

  /// Avaliáveis já concluídos: numerador do progresso.
  final int assessedParticipants;

  /// `Consultant.id` do responsável — decide quem vê "Iniciar sessão".
  final String? responsibleConsultantId;

  /// Quando os participantes desta sessão foram baixados pela última vez.
  /// Nulo = nunca baixados, o que a tela distingue de "baixados e vazia".
  final DateTime? participantsSyncedAt;

  /// Quando esta linha veio da API — mostra ao usuário a idade do cache.
  final DateTime cachedAt;
  const Session(
      {required this.id,
      required this.companyName,
      this.companyLogoUrl,
      required this.courseName,
      required this.city,
      required this.state,
      this.date,
      required this.status,
      this.notes,
      required this.totalParticipants,
      required this.assessableParticipants,
      required this.assessedParticipants,
      this.responsibleConsultantId,
      this.participantsSyncedAt,
      required this.cachedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['company_name'] = Variable<String>(companyName);
    if (!nullToAbsent || companyLogoUrl != null) {
      map['company_logo_url'] = Variable<String>(companyLogoUrl);
    }
    map['course_name'] = Variable<String>(courseName);
    map['city'] = Variable<String>(city);
    map['state'] = Variable<String>(state);
    if (!nullToAbsent || date != null) {
      map['date'] = Variable<DateTime>(date);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['total_participants'] = Variable<int>(totalParticipants);
    map['assessable_participants'] = Variable<int>(assessableParticipants);
    map['assessed_participants'] = Variable<int>(assessedParticipants);
    if (!nullToAbsent || responsibleConsultantId != null) {
      map['responsible_consultant_id'] =
          Variable<String>(responsibleConsultantId);
    }
    if (!nullToAbsent || participantsSyncedAt != null) {
      map['participants_synced_at'] = Variable<DateTime>(participantsSyncedAt);
    }
    map['cached_at'] = Variable<DateTime>(cachedAt);
    return map;
  }

  SessionsCompanion toCompanion(bool nullToAbsent) {
    return SessionsCompanion(
      id: Value(id),
      companyName: Value(companyName),
      companyLogoUrl: companyLogoUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(companyLogoUrl),
      courseName: Value(courseName),
      city: Value(city),
      state: Value(state),
      date: date == null && nullToAbsent ? const Value.absent() : Value(date),
      status: Value(status),
      notes:
          notes == null && nullToAbsent ? const Value.absent() : Value(notes),
      totalParticipants: Value(totalParticipants),
      assessableParticipants: Value(assessableParticipants),
      assessedParticipants: Value(assessedParticipants),
      responsibleConsultantId: responsibleConsultantId == null && nullToAbsent
          ? const Value.absent()
          : Value(responsibleConsultantId),
      participantsSyncedAt: participantsSyncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(participantsSyncedAt),
      cachedAt: Value(cachedAt),
    );
  }

  factory Session.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Session(
      id: serializer.fromJson<String>(json['id']),
      companyName: serializer.fromJson<String>(json['companyName']),
      companyLogoUrl: serializer.fromJson<String?>(json['companyLogoUrl']),
      courseName: serializer.fromJson<String>(json['courseName']),
      city: serializer.fromJson<String>(json['city']),
      state: serializer.fromJson<String>(json['state']),
      date: serializer.fromJson<DateTime?>(json['date']),
      status: serializer.fromJson<String>(json['status']),
      notes: serializer.fromJson<String?>(json['notes']),
      totalParticipants: serializer.fromJson<int>(json['totalParticipants']),
      assessableParticipants:
          serializer.fromJson<int>(json['assessableParticipants']),
      assessedParticipants:
          serializer.fromJson<int>(json['assessedParticipants']),
      responsibleConsultantId:
          serializer.fromJson<String?>(json['responsibleConsultantId']),
      participantsSyncedAt:
          serializer.fromJson<DateTime?>(json['participantsSyncedAt']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'companyName': serializer.toJson<String>(companyName),
      'companyLogoUrl': serializer.toJson<String?>(companyLogoUrl),
      'courseName': serializer.toJson<String>(courseName),
      'city': serializer.toJson<String>(city),
      'state': serializer.toJson<String>(state),
      'date': serializer.toJson<DateTime?>(date),
      'status': serializer.toJson<String>(status),
      'notes': serializer.toJson<String?>(notes),
      'totalParticipants': serializer.toJson<int>(totalParticipants),
      'assessableParticipants': serializer.toJson<int>(assessableParticipants),
      'assessedParticipants': serializer.toJson<int>(assessedParticipants),
      'responsibleConsultantId':
          serializer.toJson<String?>(responsibleConsultantId),
      'participantsSyncedAt':
          serializer.toJson<DateTime?>(participantsSyncedAt),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
    };
  }

  Session copyWith(
          {String? id,
          String? companyName,
          Value<String?> companyLogoUrl = const Value.absent(),
          String? courseName,
          String? city,
          String? state,
          Value<DateTime?> date = const Value.absent(),
          String? status,
          Value<String?> notes = const Value.absent(),
          int? totalParticipants,
          int? assessableParticipants,
          int? assessedParticipants,
          Value<String?> responsibleConsultantId = const Value.absent(),
          Value<DateTime?> participantsSyncedAt = const Value.absent(),
          DateTime? cachedAt}) =>
      Session(
        id: id ?? this.id,
        companyName: companyName ?? this.companyName,
        companyLogoUrl:
            companyLogoUrl.present ? companyLogoUrl.value : this.companyLogoUrl,
        courseName: courseName ?? this.courseName,
        city: city ?? this.city,
        state: state ?? this.state,
        date: date.present ? date.value : this.date,
        status: status ?? this.status,
        notes: notes.present ? notes.value : this.notes,
        totalParticipants: totalParticipants ?? this.totalParticipants,
        assessableParticipants:
            assessableParticipants ?? this.assessableParticipants,
        assessedParticipants: assessedParticipants ?? this.assessedParticipants,
        responsibleConsultantId: responsibleConsultantId.present
            ? responsibleConsultantId.value
            : this.responsibleConsultantId,
        participantsSyncedAt: participantsSyncedAt.present
            ? participantsSyncedAt.value
            : this.participantsSyncedAt,
        cachedAt: cachedAt ?? this.cachedAt,
      );
  Session copyWithCompanion(SessionsCompanion data) {
    return Session(
      id: data.id.present ? data.id.value : this.id,
      companyName:
          data.companyName.present ? data.companyName.value : this.companyName,
      companyLogoUrl: data.companyLogoUrl.present
          ? data.companyLogoUrl.value
          : this.companyLogoUrl,
      courseName:
          data.courseName.present ? data.courseName.value : this.courseName,
      city: data.city.present ? data.city.value : this.city,
      state: data.state.present ? data.state.value : this.state,
      date: data.date.present ? data.date.value : this.date,
      status: data.status.present ? data.status.value : this.status,
      notes: data.notes.present ? data.notes.value : this.notes,
      totalParticipants: data.totalParticipants.present
          ? data.totalParticipants.value
          : this.totalParticipants,
      assessableParticipants: data.assessableParticipants.present
          ? data.assessableParticipants.value
          : this.assessableParticipants,
      assessedParticipants: data.assessedParticipants.present
          ? data.assessedParticipants.value
          : this.assessedParticipants,
      responsibleConsultantId: data.responsibleConsultantId.present
          ? data.responsibleConsultantId.value
          : this.responsibleConsultantId,
      participantsSyncedAt: data.participantsSyncedAt.present
          ? data.participantsSyncedAt.value
          : this.participantsSyncedAt,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Session(')
          ..write('id: $id, ')
          ..write('companyName: $companyName, ')
          ..write('companyLogoUrl: $companyLogoUrl, ')
          ..write('courseName: $courseName, ')
          ..write('city: $city, ')
          ..write('state: $state, ')
          ..write('date: $date, ')
          ..write('status: $status, ')
          ..write('notes: $notes, ')
          ..write('totalParticipants: $totalParticipants, ')
          ..write('assessableParticipants: $assessableParticipants, ')
          ..write('assessedParticipants: $assessedParticipants, ')
          ..write('responsibleConsultantId: $responsibleConsultantId, ')
          ..write('participantsSyncedAt: $participantsSyncedAt, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      companyName,
      companyLogoUrl,
      courseName,
      city,
      state,
      date,
      status,
      notes,
      totalParticipants,
      assessableParticipants,
      assessedParticipants,
      responsibleConsultantId,
      participantsSyncedAt,
      cachedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Session &&
          other.id == this.id &&
          other.companyName == this.companyName &&
          other.companyLogoUrl == this.companyLogoUrl &&
          other.courseName == this.courseName &&
          other.city == this.city &&
          other.state == this.state &&
          other.date == this.date &&
          other.status == this.status &&
          other.notes == this.notes &&
          other.totalParticipants == this.totalParticipants &&
          other.assessableParticipants == this.assessableParticipants &&
          other.assessedParticipants == this.assessedParticipants &&
          other.responsibleConsultantId == this.responsibleConsultantId &&
          other.participantsSyncedAt == this.participantsSyncedAt &&
          other.cachedAt == this.cachedAt);
}

class SessionsCompanion extends UpdateCompanion<Session> {
  final Value<String> id;
  final Value<String> companyName;
  final Value<String?> companyLogoUrl;
  final Value<String> courseName;
  final Value<String> city;
  final Value<String> state;
  final Value<DateTime?> date;
  final Value<String> status;
  final Value<String?> notes;
  final Value<int> totalParticipants;
  final Value<int> assessableParticipants;
  final Value<int> assessedParticipants;
  final Value<String?> responsibleConsultantId;
  final Value<DateTime?> participantsSyncedAt;
  final Value<DateTime> cachedAt;
  final Value<int> rowid;
  const SessionsCompanion({
    this.id = const Value.absent(),
    this.companyName = const Value.absent(),
    this.companyLogoUrl = const Value.absent(),
    this.courseName = const Value.absent(),
    this.city = const Value.absent(),
    this.state = const Value.absent(),
    this.date = const Value.absent(),
    this.status = const Value.absent(),
    this.notes = const Value.absent(),
    this.totalParticipants = const Value.absent(),
    this.assessableParticipants = const Value.absent(),
    this.assessedParticipants = const Value.absent(),
    this.responsibleConsultantId = const Value.absent(),
    this.participantsSyncedAt = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SessionsCompanion.insert({
    required String id,
    required String companyName,
    this.companyLogoUrl = const Value.absent(),
    required String courseName,
    required String city,
    required String state,
    this.date = const Value.absent(),
    required String status,
    this.notes = const Value.absent(),
    this.totalParticipants = const Value.absent(),
    this.assessableParticipants = const Value.absent(),
    this.assessedParticipants = const Value.absent(),
    this.responsibleConsultantId = const Value.absent(),
    this.participantsSyncedAt = const Value.absent(),
    required DateTime cachedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        companyName = Value(companyName),
        courseName = Value(courseName),
        city = Value(city),
        state = Value(state),
        status = Value(status),
        cachedAt = Value(cachedAt);
  static Insertable<Session> custom({
    Expression<String>? id,
    Expression<String>? companyName,
    Expression<String>? companyLogoUrl,
    Expression<String>? courseName,
    Expression<String>? city,
    Expression<String>? state,
    Expression<DateTime>? date,
    Expression<String>? status,
    Expression<String>? notes,
    Expression<int>? totalParticipants,
    Expression<int>? assessableParticipants,
    Expression<int>? assessedParticipants,
    Expression<String>? responsibleConsultantId,
    Expression<DateTime>? participantsSyncedAt,
    Expression<DateTime>? cachedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (companyName != null) 'company_name': companyName,
      if (companyLogoUrl != null) 'company_logo_url': companyLogoUrl,
      if (courseName != null) 'course_name': courseName,
      if (city != null) 'city': city,
      if (state != null) 'state': state,
      if (date != null) 'date': date,
      if (status != null) 'status': status,
      if (notes != null) 'notes': notes,
      if (totalParticipants != null) 'total_participants': totalParticipants,
      if (assessableParticipants != null)
        'assessable_participants': assessableParticipants,
      if (assessedParticipants != null)
        'assessed_participants': assessedParticipants,
      if (responsibleConsultantId != null)
        'responsible_consultant_id': responsibleConsultantId,
      if (participantsSyncedAt != null)
        'participants_synced_at': participantsSyncedAt,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SessionsCompanion copyWith(
      {Value<String>? id,
      Value<String>? companyName,
      Value<String?>? companyLogoUrl,
      Value<String>? courseName,
      Value<String>? city,
      Value<String>? state,
      Value<DateTime?>? date,
      Value<String>? status,
      Value<String?>? notes,
      Value<int>? totalParticipants,
      Value<int>? assessableParticipants,
      Value<int>? assessedParticipants,
      Value<String?>? responsibleConsultantId,
      Value<DateTime?>? participantsSyncedAt,
      Value<DateTime>? cachedAt,
      Value<int>? rowid}) {
    return SessionsCompanion(
      id: id ?? this.id,
      companyName: companyName ?? this.companyName,
      companyLogoUrl: companyLogoUrl ?? this.companyLogoUrl,
      courseName: courseName ?? this.courseName,
      city: city ?? this.city,
      state: state ?? this.state,
      date: date ?? this.date,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      totalParticipants: totalParticipants ?? this.totalParticipants,
      assessableParticipants:
          assessableParticipants ?? this.assessableParticipants,
      assessedParticipants: assessedParticipants ?? this.assessedParticipants,
      responsibleConsultantId:
          responsibleConsultantId ?? this.responsibleConsultantId,
      participantsSyncedAt: participantsSyncedAt ?? this.participantsSyncedAt,
      cachedAt: cachedAt ?? this.cachedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (companyName.present) {
      map['company_name'] = Variable<String>(companyName.value);
    }
    if (companyLogoUrl.present) {
      map['company_logo_url'] = Variable<String>(companyLogoUrl.value);
    }
    if (courseName.present) {
      map['course_name'] = Variable<String>(courseName.value);
    }
    if (city.present) {
      map['city'] = Variable<String>(city.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (totalParticipants.present) {
      map['total_participants'] = Variable<int>(totalParticipants.value);
    }
    if (assessableParticipants.present) {
      map['assessable_participants'] =
          Variable<int>(assessableParticipants.value);
    }
    if (assessedParticipants.present) {
      map['assessed_participants'] = Variable<int>(assessedParticipants.value);
    }
    if (responsibleConsultantId.present) {
      map['responsible_consultant_id'] =
          Variable<String>(responsibleConsultantId.value);
    }
    if (participantsSyncedAt.present) {
      map['participants_synced_at'] =
          Variable<DateTime>(participantsSyncedAt.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionsCompanion(')
          ..write('id: $id, ')
          ..write('companyName: $companyName, ')
          ..write('companyLogoUrl: $companyLogoUrl, ')
          ..write('courseName: $courseName, ')
          ..write('city: $city, ')
          ..write('state: $state, ')
          ..write('date: $date, ')
          ..write('status: $status, ')
          ..write('notes: $notes, ')
          ..write('totalParticipants: $totalParticipants, ')
          ..write('assessableParticipants: $assessableParticipants, ')
          ..write('assessedParticipants: $assessedParticipants, ')
          ..write('responsibleConsultantId: $responsibleConsultantId, ')
          ..write('participantsSyncedAt: $participantsSyncedAt, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ParticipantsTable extends Participants
    with TableInfo<$ParticipantsTable, Participant> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ParticipantsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sessionIdMeta =
      const VerificationMeta('sessionId');
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
      'session_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES sessions (id)'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _cpfMeta = const VerificationMeta('cpf');
  @override
  late final GeneratedColumn<String> cpf = GeneratedColumn<String>(
      'cpf', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
      'email', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _participationTypeMeta =
      const VerificationMeta('participationType');
  @override
  late final GeneratedColumn<String> participationType =
      GeneratedColumn<String>('participation_type', aliasedName, false,
          type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _assignedConsultantIdMeta =
      const VerificationMeta('assignedConsultantId');
  @override
  late final GeneratedColumn<String> assignedConsultantId =
      GeneratedColumn<String>('assigned_consultant_id', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _assignedConsultantNameMeta =
      const VerificationMeta('assignedConsultantName');
  @override
  late final GeneratedColumn<String> assignedConsultantName =
      GeneratedColumn<String>('assigned_consultant_name', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _scoreMeta = const VerificationMeta('score');
  @override
  late final GeneratedColumn<double> score = GeneratedColumn<double>(
      'score', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _assessedByConsultantIdMeta =
      const VerificationMeta('assessedByConsultantId');
  @override
  late final GeneratedColumn<String> assessedByConsultantId =
      GeneratedColumn<String>('assessed_by_consultant_id', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _assessedAtMeta =
      const VerificationMeta('assessedAt');
  @override
  late final GeneratedColumn<DateTime> assessedAt = GeneratedColumn<DateTime>(
      'assessed_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _cachedAtMeta =
      const VerificationMeta('cachedAt');
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
      'cached_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        sessionId,
        name,
        cpf,
        email,
        participationType,
        status,
        assignedConsultantId,
        assignedConsultantName,
        score,
        assessedByConsultantId,
        assessedAt,
        cachedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'participants';
  @override
  VerificationContext validateIntegrity(Insertable<Participant> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(_sessionIdMeta,
          sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta));
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('cpf')) {
      context.handle(
          _cpfMeta, cpf.isAcceptableOrUnknown(data['cpf']!, _cpfMeta));
    } else if (isInserting) {
      context.missing(_cpfMeta);
    }
    if (data.containsKey('email')) {
      context.handle(
          _emailMeta, email.isAcceptableOrUnknown(data['email']!, _emailMeta));
    }
    if (data.containsKey('participation_type')) {
      context.handle(
          _participationTypeMeta,
          participationType.isAcceptableOrUnknown(
              data['participation_type']!, _participationTypeMeta));
    } else if (isInserting) {
      context.missing(_participationTypeMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('assigned_consultant_id')) {
      context.handle(
          _assignedConsultantIdMeta,
          assignedConsultantId.isAcceptableOrUnknown(
              data['assigned_consultant_id']!, _assignedConsultantIdMeta));
    }
    if (data.containsKey('assigned_consultant_name')) {
      context.handle(
          _assignedConsultantNameMeta,
          assignedConsultantName.isAcceptableOrUnknown(
              data['assigned_consultant_name']!, _assignedConsultantNameMeta));
    }
    if (data.containsKey('score')) {
      context.handle(
          _scoreMeta, score.isAcceptableOrUnknown(data['score']!, _scoreMeta));
    }
    if (data.containsKey('assessed_by_consultant_id')) {
      context.handle(
          _assessedByConsultantIdMeta,
          assessedByConsultantId.isAcceptableOrUnknown(
              data['assessed_by_consultant_id']!, _assessedByConsultantIdMeta));
    }
    if (data.containsKey('assessed_at')) {
      context.handle(
          _assessedAtMeta,
          assessedAt.isAcceptableOrUnknown(
              data['assessed_at']!, _assessedAtMeta));
    }
    if (data.containsKey('cached_at')) {
      context.handle(_cachedAtMeta,
          cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta));
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Participant map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Participant(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      sessionId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}session_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      cpf: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}cpf'])!,
      email: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}email']),
      participationType: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}participation_type'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      assignedConsultantId: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}assigned_consultant_id']),
      assignedConsultantName: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}assigned_consultant_name']),
      score: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}score']),
      assessedByConsultantId: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}assessed_by_consultant_id']),
      assessedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}assessed_at']),
      cachedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}cached_at'])!,
    );
  }

  @override
  $ParticipantsTable createAlias(String alias) {
    return $ParticipantsTable(attachedDatabase, alias);
  }
}

class Participant extends DataClass implements Insertable<Participant> {
  /// Id do `TrainingParticipant` (não o do `Participant`).
  final String id;
  final String sessionId;
  final String name;
  final String cpf;
  final String? email;
  final String participationType;
  final String status;
  final String? assignedConsultantId;
  final String? assignedConsultantName;

  /// Score da avaliação já sincronizada, quando houver.
  final double? score;

  /// `PracticalAssessment.consultantId`: quem fez a avaliação — filtro "Meus".
  final String? assessedByConsultantId;

  /// Fim (ou início) da avaliação sincronizada — a linha "hoje 08:12".
  final DateTime? assessedAt;
  final DateTime cachedAt;
  const Participant(
      {required this.id,
      required this.sessionId,
      required this.name,
      required this.cpf,
      this.email,
      required this.participationType,
      required this.status,
      this.assignedConsultantId,
      this.assignedConsultantName,
      this.score,
      this.assessedByConsultantId,
      this.assessedAt,
      required this.cachedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['name'] = Variable<String>(name);
    map['cpf'] = Variable<String>(cpf);
    if (!nullToAbsent || email != null) {
      map['email'] = Variable<String>(email);
    }
    map['participation_type'] = Variable<String>(participationType);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || assignedConsultantId != null) {
      map['assigned_consultant_id'] = Variable<String>(assignedConsultantId);
    }
    if (!nullToAbsent || assignedConsultantName != null) {
      map['assigned_consultant_name'] =
          Variable<String>(assignedConsultantName);
    }
    if (!nullToAbsent || score != null) {
      map['score'] = Variable<double>(score);
    }
    if (!nullToAbsent || assessedByConsultantId != null) {
      map['assessed_by_consultant_id'] =
          Variable<String>(assessedByConsultantId);
    }
    if (!nullToAbsent || assessedAt != null) {
      map['assessed_at'] = Variable<DateTime>(assessedAt);
    }
    map['cached_at'] = Variable<DateTime>(cachedAt);
    return map;
  }

  ParticipantsCompanion toCompanion(bool nullToAbsent) {
    return ParticipantsCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      name: Value(name),
      cpf: Value(cpf),
      email:
          email == null && nullToAbsent ? const Value.absent() : Value(email),
      participationType: Value(participationType),
      status: Value(status),
      assignedConsultantId: assignedConsultantId == null && nullToAbsent
          ? const Value.absent()
          : Value(assignedConsultantId),
      assignedConsultantName: assignedConsultantName == null && nullToAbsent
          ? const Value.absent()
          : Value(assignedConsultantName),
      score:
          score == null && nullToAbsent ? const Value.absent() : Value(score),
      assessedByConsultantId: assessedByConsultantId == null && nullToAbsent
          ? const Value.absent()
          : Value(assessedByConsultantId),
      assessedAt: assessedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(assessedAt),
      cachedAt: Value(cachedAt),
    );
  }

  factory Participant.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Participant(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      name: serializer.fromJson<String>(json['name']),
      cpf: serializer.fromJson<String>(json['cpf']),
      email: serializer.fromJson<String?>(json['email']),
      participationType: serializer.fromJson<String>(json['participationType']),
      status: serializer.fromJson<String>(json['status']),
      assignedConsultantId:
          serializer.fromJson<String?>(json['assignedConsultantId']),
      assignedConsultantName:
          serializer.fromJson<String?>(json['assignedConsultantName']),
      score: serializer.fromJson<double?>(json['score']),
      assessedByConsultantId:
          serializer.fromJson<String?>(json['assessedByConsultantId']),
      assessedAt: serializer.fromJson<DateTime?>(json['assessedAt']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'name': serializer.toJson<String>(name),
      'cpf': serializer.toJson<String>(cpf),
      'email': serializer.toJson<String?>(email),
      'participationType': serializer.toJson<String>(participationType),
      'status': serializer.toJson<String>(status),
      'assignedConsultantId': serializer.toJson<String?>(assignedConsultantId),
      'assignedConsultantName':
          serializer.toJson<String?>(assignedConsultantName),
      'score': serializer.toJson<double?>(score),
      'assessedByConsultantId':
          serializer.toJson<String?>(assessedByConsultantId),
      'assessedAt': serializer.toJson<DateTime?>(assessedAt),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
    };
  }

  Participant copyWith(
          {String? id,
          String? sessionId,
          String? name,
          String? cpf,
          Value<String?> email = const Value.absent(),
          String? participationType,
          String? status,
          Value<String?> assignedConsultantId = const Value.absent(),
          Value<String?> assignedConsultantName = const Value.absent(),
          Value<double?> score = const Value.absent(),
          Value<String?> assessedByConsultantId = const Value.absent(),
          Value<DateTime?> assessedAt = const Value.absent(),
          DateTime? cachedAt}) =>
      Participant(
        id: id ?? this.id,
        sessionId: sessionId ?? this.sessionId,
        name: name ?? this.name,
        cpf: cpf ?? this.cpf,
        email: email.present ? email.value : this.email,
        participationType: participationType ?? this.participationType,
        status: status ?? this.status,
        assignedConsultantId: assignedConsultantId.present
            ? assignedConsultantId.value
            : this.assignedConsultantId,
        assignedConsultantName: assignedConsultantName.present
            ? assignedConsultantName.value
            : this.assignedConsultantName,
        score: score.present ? score.value : this.score,
        assessedByConsultantId: assessedByConsultantId.present
            ? assessedByConsultantId.value
            : this.assessedByConsultantId,
        assessedAt: assessedAt.present ? assessedAt.value : this.assessedAt,
        cachedAt: cachedAt ?? this.cachedAt,
      );
  Participant copyWithCompanion(ParticipantsCompanion data) {
    return Participant(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      name: data.name.present ? data.name.value : this.name,
      cpf: data.cpf.present ? data.cpf.value : this.cpf,
      email: data.email.present ? data.email.value : this.email,
      participationType: data.participationType.present
          ? data.participationType.value
          : this.participationType,
      status: data.status.present ? data.status.value : this.status,
      assignedConsultantId: data.assignedConsultantId.present
          ? data.assignedConsultantId.value
          : this.assignedConsultantId,
      assignedConsultantName: data.assignedConsultantName.present
          ? data.assignedConsultantName.value
          : this.assignedConsultantName,
      score: data.score.present ? data.score.value : this.score,
      assessedByConsultantId: data.assessedByConsultantId.present
          ? data.assessedByConsultantId.value
          : this.assessedByConsultantId,
      assessedAt:
          data.assessedAt.present ? data.assessedAt.value : this.assessedAt,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Participant(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('name: $name, ')
          ..write('cpf: $cpf, ')
          ..write('email: $email, ')
          ..write('participationType: $participationType, ')
          ..write('status: $status, ')
          ..write('assignedConsultantId: $assignedConsultantId, ')
          ..write('assignedConsultantName: $assignedConsultantName, ')
          ..write('score: $score, ')
          ..write('assessedByConsultantId: $assessedByConsultantId, ')
          ..write('assessedAt: $assessedAt, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      sessionId,
      name,
      cpf,
      email,
      participationType,
      status,
      assignedConsultantId,
      assignedConsultantName,
      score,
      assessedByConsultantId,
      assessedAt,
      cachedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Participant &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.name == this.name &&
          other.cpf == this.cpf &&
          other.email == this.email &&
          other.participationType == this.participationType &&
          other.status == this.status &&
          other.assignedConsultantId == this.assignedConsultantId &&
          other.assignedConsultantName == this.assignedConsultantName &&
          other.score == this.score &&
          other.assessedByConsultantId == this.assessedByConsultantId &&
          other.assessedAt == this.assessedAt &&
          other.cachedAt == this.cachedAt);
}

class ParticipantsCompanion extends UpdateCompanion<Participant> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<String> name;
  final Value<String> cpf;
  final Value<String?> email;
  final Value<String> participationType;
  final Value<String> status;
  final Value<String?> assignedConsultantId;
  final Value<String?> assignedConsultantName;
  final Value<double?> score;
  final Value<String?> assessedByConsultantId;
  final Value<DateTime?> assessedAt;
  final Value<DateTime> cachedAt;
  final Value<int> rowid;
  const ParticipantsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.name = const Value.absent(),
    this.cpf = const Value.absent(),
    this.email = const Value.absent(),
    this.participationType = const Value.absent(),
    this.status = const Value.absent(),
    this.assignedConsultantId = const Value.absent(),
    this.assignedConsultantName = const Value.absent(),
    this.score = const Value.absent(),
    this.assessedByConsultantId = const Value.absent(),
    this.assessedAt = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ParticipantsCompanion.insert({
    required String id,
    required String sessionId,
    required String name,
    required String cpf,
    this.email = const Value.absent(),
    required String participationType,
    required String status,
    this.assignedConsultantId = const Value.absent(),
    this.assignedConsultantName = const Value.absent(),
    this.score = const Value.absent(),
    this.assessedByConsultantId = const Value.absent(),
    this.assessedAt = const Value.absent(),
    required DateTime cachedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        sessionId = Value(sessionId),
        name = Value(name),
        cpf = Value(cpf),
        participationType = Value(participationType),
        status = Value(status),
        cachedAt = Value(cachedAt);
  static Insertable<Participant> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<String>? name,
    Expression<String>? cpf,
    Expression<String>? email,
    Expression<String>? participationType,
    Expression<String>? status,
    Expression<String>? assignedConsultantId,
    Expression<String>? assignedConsultantName,
    Expression<double>? score,
    Expression<String>? assessedByConsultantId,
    Expression<DateTime>? assessedAt,
    Expression<DateTime>? cachedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (name != null) 'name': name,
      if (cpf != null) 'cpf': cpf,
      if (email != null) 'email': email,
      if (participationType != null) 'participation_type': participationType,
      if (status != null) 'status': status,
      if (assignedConsultantId != null)
        'assigned_consultant_id': assignedConsultantId,
      if (assignedConsultantName != null)
        'assigned_consultant_name': assignedConsultantName,
      if (score != null) 'score': score,
      if (assessedByConsultantId != null)
        'assessed_by_consultant_id': assessedByConsultantId,
      if (assessedAt != null) 'assessed_at': assessedAt,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ParticipantsCompanion copyWith(
      {Value<String>? id,
      Value<String>? sessionId,
      Value<String>? name,
      Value<String>? cpf,
      Value<String?>? email,
      Value<String>? participationType,
      Value<String>? status,
      Value<String?>? assignedConsultantId,
      Value<String?>? assignedConsultantName,
      Value<double?>? score,
      Value<String?>? assessedByConsultantId,
      Value<DateTime?>? assessedAt,
      Value<DateTime>? cachedAt,
      Value<int>? rowid}) {
    return ParticipantsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      name: name ?? this.name,
      cpf: cpf ?? this.cpf,
      email: email ?? this.email,
      participationType: participationType ?? this.participationType,
      status: status ?? this.status,
      assignedConsultantId: assignedConsultantId ?? this.assignedConsultantId,
      assignedConsultantName:
          assignedConsultantName ?? this.assignedConsultantName,
      score: score ?? this.score,
      assessedByConsultantId:
          assessedByConsultantId ?? this.assessedByConsultantId,
      assessedAt: assessedAt ?? this.assessedAt,
      cachedAt: cachedAt ?? this.cachedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (cpf.present) {
      map['cpf'] = Variable<String>(cpf.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (participationType.present) {
      map['participation_type'] = Variable<String>(participationType.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (assignedConsultantId.present) {
      map['assigned_consultant_id'] =
          Variable<String>(assignedConsultantId.value);
    }
    if (assignedConsultantName.present) {
      map['assigned_consultant_name'] =
          Variable<String>(assignedConsultantName.value);
    }
    if (score.present) {
      map['score'] = Variable<double>(score.value);
    }
    if (assessedByConsultantId.present) {
      map['assessed_by_consultant_id'] =
          Variable<String>(assessedByConsultantId.value);
    }
    if (assessedAt.present) {
      map['assessed_at'] = Variable<DateTime>(assessedAt.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ParticipantsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('name: $name, ')
          ..write('cpf: $cpf, ')
          ..write('email: $email, ')
          ..write('participationType: $participationType, ')
          ..write('status: $status, ')
          ..write('assignedConsultantId: $assignedConsultantId, ')
          ..write('assignedConsultantName: $assignedConsultantName, ')
          ..write('score: $score, ')
          ..write('assessedByConsultantId: $assessedByConsultantId, ')
          ..write('assessedAt: $assessedAt, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SessionConsultantsTable extends SessionConsultants
    with TableInfo<$SessionConsultantsTable, SessionConsultantRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionConsultantsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sessionIdMeta =
      const VerificationMeta('sessionId');
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
      'session_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES sessions (id) ON DELETE CASCADE'));
  static const VerificationMeta _consultantIdMeta =
      const VerificationMeta('consultantId');
  @override
  late final GeneratedColumn<String> consultantId = GeneratedColumn<String>(
      'consultant_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
      'email', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [sessionId, consultantId, name, email];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'session_consultants';
  @override
  VerificationContext validateIntegrity(
      Insertable<SessionConsultantRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('session_id')) {
      context.handle(_sessionIdMeta,
          sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta));
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('consultant_id')) {
      context.handle(
          _consultantIdMeta,
          consultantId.isAcceptableOrUnknown(
              data['consultant_id']!, _consultantIdMeta));
    } else if (isInserting) {
      context.missing(_consultantIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('email')) {
      context.handle(
          _emailMeta, email.isAcceptableOrUnknown(data['email']!, _emailMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sessionId, consultantId};
  @override
  SessionConsultantRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SessionConsultantRow(
      sessionId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}session_id'])!,
      consultantId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}consultant_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      email: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}email']),
    );
  }

  @override
  $SessionConsultantsTable createAlias(String alias) {
    return $SessionConsultantsTable(attachedDatabase, alias);
  }
}

class SessionConsultantRow extends DataClass
    implements Insertable<SessionConsultantRow> {
  final String sessionId;

  /// `Consultant.id`.
  final String consultantId;
  final String name;
  final String? email;
  const SessionConsultantRow(
      {required this.sessionId,
      required this.consultantId,
      required this.name,
      this.email});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['session_id'] = Variable<String>(sessionId);
    map['consultant_id'] = Variable<String>(consultantId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || email != null) {
      map['email'] = Variable<String>(email);
    }
    return map;
  }

  SessionConsultantsCompanion toCompanion(bool nullToAbsent) {
    return SessionConsultantsCompanion(
      sessionId: Value(sessionId),
      consultantId: Value(consultantId),
      name: Value(name),
      email:
          email == null && nullToAbsent ? const Value.absent() : Value(email),
    );
  }

  factory SessionConsultantRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SessionConsultantRow(
      sessionId: serializer.fromJson<String>(json['sessionId']),
      consultantId: serializer.fromJson<String>(json['consultantId']),
      name: serializer.fromJson<String>(json['name']),
      email: serializer.fromJson<String?>(json['email']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sessionId': serializer.toJson<String>(sessionId),
      'consultantId': serializer.toJson<String>(consultantId),
      'name': serializer.toJson<String>(name),
      'email': serializer.toJson<String?>(email),
    };
  }

  SessionConsultantRow copyWith(
          {String? sessionId,
          String? consultantId,
          String? name,
          Value<String?> email = const Value.absent()}) =>
      SessionConsultantRow(
        sessionId: sessionId ?? this.sessionId,
        consultantId: consultantId ?? this.consultantId,
        name: name ?? this.name,
        email: email.present ? email.value : this.email,
      );
  SessionConsultantRow copyWithCompanion(SessionConsultantsCompanion data) {
    return SessionConsultantRow(
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      consultantId: data.consultantId.present
          ? data.consultantId.value
          : this.consultantId,
      name: data.name.present ? data.name.value : this.name,
      email: data.email.present ? data.email.value : this.email,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SessionConsultantRow(')
          ..write('sessionId: $sessionId, ')
          ..write('consultantId: $consultantId, ')
          ..write('name: $name, ')
          ..write('email: $email')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(sessionId, consultantId, name, email);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionConsultantRow &&
          other.sessionId == this.sessionId &&
          other.consultantId == this.consultantId &&
          other.name == this.name &&
          other.email == this.email);
}

class SessionConsultantsCompanion
    extends UpdateCompanion<SessionConsultantRow> {
  final Value<String> sessionId;
  final Value<String> consultantId;
  final Value<String> name;
  final Value<String?> email;
  final Value<int> rowid;
  const SessionConsultantsCompanion({
    this.sessionId = const Value.absent(),
    this.consultantId = const Value.absent(),
    this.name = const Value.absent(),
    this.email = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SessionConsultantsCompanion.insert({
    required String sessionId,
    required String consultantId,
    required String name,
    this.email = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : sessionId = Value(sessionId),
        consultantId = Value(consultantId),
        name = Value(name);
  static Insertable<SessionConsultantRow> custom({
    Expression<String>? sessionId,
    Expression<String>? consultantId,
    Expression<String>? name,
    Expression<String>? email,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sessionId != null) 'session_id': sessionId,
      if (consultantId != null) 'consultant_id': consultantId,
      if (name != null) 'name': name,
      if (email != null) 'email': email,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SessionConsultantsCompanion copyWith(
      {Value<String>? sessionId,
      Value<String>? consultantId,
      Value<String>? name,
      Value<String?>? email,
      Value<int>? rowid}) {
    return SessionConsultantsCompanion(
      sessionId: sessionId ?? this.sessionId,
      consultantId: consultantId ?? this.consultantId,
      name: name ?? this.name,
      email: email ?? this.email,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (consultantId.present) {
      map['consultant_id'] = Variable<String>(consultantId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionConsultantsCompanion(')
          ..write('sessionId: $sessionId, ')
          ..write('consultantId: $consultantId, ')
          ..write('name: $name, ')
          ..write('email: $email, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AssessmentCategoriesTable extends AssessmentCategories
    with TableInfo<$AssessmentCategoriesTable, AssessmentCategory> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AssessmentCategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
      'code', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _orderMeta = const VerificationMeta('order');
  @override
  late final GeneratedColumn<int> order = GeneratedColumn<int>(
      'order', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, code, name, description, order];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'assessment_categories';
  @override
  VerificationContext validateIntegrity(Insertable<AssessmentCategory> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('code')) {
      context.handle(
          _codeMeta, code.isAcceptableOrUnknown(data['code']!, _codeMeta));
    } else if (isInserting) {
      context.missing(_codeMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('order')) {
      context.handle(
          _orderMeta, order.isAcceptableOrUnknown(data['order']!, _orderMeta));
    } else if (isInserting) {
      context.missing(_orderMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AssessmentCategory map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AssessmentCategory(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      code: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}code'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
      order: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}order'])!,
    );
  }

  @override
  $AssessmentCategoriesTable createAlias(String alias) {
    return $AssessmentCategoriesTable(attachedDatabase, alias);
  }
}

class AssessmentCategory extends DataClass
    implements Insertable<AssessmentCategory> {
  final String id;
  final String code;
  final String name;
  final String? description;
  final int order;
  const AssessmentCategory(
      {required this.id,
      required this.code,
      required this.name,
      this.description,
      required this.order});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['code'] = Variable<String>(code);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['order'] = Variable<int>(order);
    return map;
  }

  AssessmentCategoriesCompanion toCompanion(bool nullToAbsent) {
    return AssessmentCategoriesCompanion(
      id: Value(id),
      code: Value(code),
      name: Value(name),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      order: Value(order),
    );
  }

  factory AssessmentCategory.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AssessmentCategory(
      id: serializer.fromJson<String>(json['id']),
      code: serializer.fromJson<String>(json['code']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
      order: serializer.fromJson<int>(json['order']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'code': serializer.toJson<String>(code),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
      'order': serializer.toJson<int>(order),
    };
  }

  AssessmentCategory copyWith(
          {String? id,
          String? code,
          String? name,
          Value<String?> description = const Value.absent(),
          int? order}) =>
      AssessmentCategory(
        id: id ?? this.id,
        code: code ?? this.code,
        name: name ?? this.name,
        description: description.present ? description.value : this.description,
        order: order ?? this.order,
      );
  AssessmentCategory copyWithCompanion(AssessmentCategoriesCompanion data) {
    return AssessmentCategory(
      id: data.id.present ? data.id.value : this.id,
      code: data.code.present ? data.code.value : this.code,
      name: data.name.present ? data.name.value : this.name,
      description:
          data.description.present ? data.description.value : this.description,
      order: data.order.present ? data.order.value : this.order,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AssessmentCategory(')
          ..write('id: $id, ')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('order: $order')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, code, name, description, order);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AssessmentCategory &&
          other.id == this.id &&
          other.code == this.code &&
          other.name == this.name &&
          other.description == this.description &&
          other.order == this.order);
}

class AssessmentCategoriesCompanion
    extends UpdateCompanion<AssessmentCategory> {
  final Value<String> id;
  final Value<String> code;
  final Value<String> name;
  final Value<String?> description;
  final Value<int> order;
  final Value<int> rowid;
  const AssessmentCategoriesCompanion({
    this.id = const Value.absent(),
    this.code = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.order = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AssessmentCategoriesCompanion.insert({
    required String id,
    required String code,
    required String name,
    this.description = const Value.absent(),
    required int order,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        code = Value(code),
        name = Value(name),
        order = Value(order);
  static Insertable<AssessmentCategory> custom({
    Expression<String>? id,
    Expression<String>? code,
    Expression<String>? name,
    Expression<String>? description,
    Expression<int>? order,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (code != null) 'code': code,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (order != null) 'order': order,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AssessmentCategoriesCompanion copyWith(
      {Value<String>? id,
      Value<String>? code,
      Value<String>? name,
      Value<String?>? description,
      Value<int>? order,
      Value<int>? rowid}) {
    return AssessmentCategoriesCompanion(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      description: description ?? this.description,
      order: order ?? this.order,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (order.present) {
      map['order'] = Variable<int>(order.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AssessmentCategoriesCompanion(')
          ..write('id: $id, ')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('order: $order, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $InfractionsTable extends Infractions
    with TableInfo<$InfractionsTable, Infraction> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InfractionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _categoryIdMeta =
      const VerificationMeta('categoryId');
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
      'category_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES assessment_categories (id)'));
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _orderMeta = const VerificationMeta('order');
  @override
  late final GeneratedColumn<int> order = GeneratedColumn<int>(
      'order', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, categoryId, description, order];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'infractions';
  @override
  VerificationContext validateIntegrity(Insertable<Infraction> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
          _categoryIdMeta,
          categoryId.isAcceptableOrUnknown(
              data['category_id']!, _categoryIdMeta));
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('order')) {
      context.handle(
          _orderMeta, order.isAcceptableOrUnknown(data['order']!, _orderMeta));
    } else if (isInserting) {
      context.missing(_orderMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Infraction map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Infraction(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      categoryId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category_id'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description'])!,
      order: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}order'])!,
    );
  }

  @override
  $InfractionsTable createAlias(String alias) {
    return $InfractionsTable(attachedDatabase, alias);
  }
}

class Infraction extends DataClass implements Insertable<Infraction> {
  final String id;
  final String categoryId;
  final String description;
  final int order;
  const Infraction(
      {required this.id,
      required this.categoryId,
      required this.description,
      required this.order});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['category_id'] = Variable<String>(categoryId);
    map['description'] = Variable<String>(description);
    map['order'] = Variable<int>(order);
    return map;
  }

  InfractionsCompanion toCompanion(bool nullToAbsent) {
    return InfractionsCompanion(
      id: Value(id),
      categoryId: Value(categoryId),
      description: Value(description),
      order: Value(order),
    );
  }

  factory Infraction.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Infraction(
      id: serializer.fromJson<String>(json['id']),
      categoryId: serializer.fromJson<String>(json['categoryId']),
      description: serializer.fromJson<String>(json['description']),
      order: serializer.fromJson<int>(json['order']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'categoryId': serializer.toJson<String>(categoryId),
      'description': serializer.toJson<String>(description),
      'order': serializer.toJson<int>(order),
    };
  }

  Infraction copyWith(
          {String? id, String? categoryId, String? description, int? order}) =>
      Infraction(
        id: id ?? this.id,
        categoryId: categoryId ?? this.categoryId,
        description: description ?? this.description,
        order: order ?? this.order,
      );
  Infraction copyWithCompanion(InfractionsCompanion data) {
    return Infraction(
      id: data.id.present ? data.id.value : this.id,
      categoryId:
          data.categoryId.present ? data.categoryId.value : this.categoryId,
      description:
          data.description.present ? data.description.value : this.description,
      order: data.order.present ? data.order.value : this.order,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Infraction(')
          ..write('id: $id, ')
          ..write('categoryId: $categoryId, ')
          ..write('description: $description, ')
          ..write('order: $order')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, categoryId, description, order);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Infraction &&
          other.id == this.id &&
          other.categoryId == this.categoryId &&
          other.description == this.description &&
          other.order == this.order);
}

class InfractionsCompanion extends UpdateCompanion<Infraction> {
  final Value<String> id;
  final Value<String> categoryId;
  final Value<String> description;
  final Value<int> order;
  final Value<int> rowid;
  const InfractionsCompanion({
    this.id = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.description = const Value.absent(),
    this.order = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  InfractionsCompanion.insert({
    required String id,
    required String categoryId,
    required String description,
    required int order,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        categoryId = Value(categoryId),
        description = Value(description),
        order = Value(order);
  static Insertable<Infraction> custom({
    Expression<String>? id,
    Expression<String>? categoryId,
    Expression<String>? description,
    Expression<int>? order,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (categoryId != null) 'category_id': categoryId,
      if (description != null) 'description': description,
      if (order != null) 'order': order,
      if (rowid != null) 'rowid': rowid,
    });
  }

  InfractionsCompanion copyWith(
      {Value<String>? id,
      Value<String>? categoryId,
      Value<String>? description,
      Value<int>? order,
      Value<int>? rowid}) {
    return InfractionsCompanion(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      description: description ?? this.description,
      order: order ?? this.order,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (order.present) {
      map['order'] = Variable<int>(order.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InfractionsCompanion(')
          ..write('id: $id, ')
          ..write('categoryId: $categoryId, ')
          ..write('description: $description, ')
          ..write('order: $order, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $InfractionNotesTable extends InfractionNotes
    with TableInfo<$InfractionNotesTable, InfractionNote> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InfractionNotesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _infractionIdMeta =
      const VerificationMeta('infractionId');
  @override
  late final GeneratedColumn<String> infractionId = GeneratedColumn<String>(
      'infraction_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES infractions (id)'));
  static const VerificationMeta _noteTypeMeta =
      const VerificationMeta('noteType');
  @override
  late final GeneratedColumn<String> noteType = GeneratedColumn<String>(
      'note_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _commentMeta =
      const VerificationMeta('comment');
  @override
  late final GeneratedColumn<String> comment = GeneratedColumn<String>(
      'comment', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _deductionMeta =
      const VerificationMeta('deduction');
  @override
  late final GeneratedColumn<int> deduction = GeneratedColumn<int>(
      'deduction', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, infractionId, noteType, comment, deduction];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'infraction_notes';
  @override
  VerificationContext validateIntegrity(Insertable<InfractionNote> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('infraction_id')) {
      context.handle(
          _infractionIdMeta,
          infractionId.isAcceptableOrUnknown(
              data['infraction_id']!, _infractionIdMeta));
    } else if (isInserting) {
      context.missing(_infractionIdMeta);
    }
    if (data.containsKey('note_type')) {
      context.handle(_noteTypeMeta,
          noteType.isAcceptableOrUnknown(data['note_type']!, _noteTypeMeta));
    } else if (isInserting) {
      context.missing(_noteTypeMeta);
    }
    if (data.containsKey('comment')) {
      context.handle(_commentMeta,
          comment.isAcceptableOrUnknown(data['comment']!, _commentMeta));
    }
    if (data.containsKey('deduction')) {
      context.handle(_deductionMeta,
          deduction.isAcceptableOrUnknown(data['deduction']!, _deductionMeta));
    } else if (isInserting) {
      context.missing(_deductionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  InfractionNote map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InfractionNote(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      infractionId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}infraction_id'])!,
      noteType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note_type'])!,
      comment: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}comment']),
      deduction: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}deduction'])!,
    );
  }

  @override
  $InfractionNotesTable createAlias(String alias) {
    return $InfractionNotesTable(attachedDatabase, alias);
  }
}

class InfractionNote extends DataClass implements Insertable<InfractionNote> {
  final String id;
  final String infractionId;

  /// `B`, `PM` ou `M`, como vem do backend.
  final String noteType;
  final String? comment;

  /// `deduction` do backend — o cálculo do score usa este valor, não constantes.
  final int deduction;
  const InfractionNote(
      {required this.id,
      required this.infractionId,
      required this.noteType,
      this.comment,
      required this.deduction});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['infraction_id'] = Variable<String>(infractionId);
    map['note_type'] = Variable<String>(noteType);
    if (!nullToAbsent || comment != null) {
      map['comment'] = Variable<String>(comment);
    }
    map['deduction'] = Variable<int>(deduction);
    return map;
  }

  InfractionNotesCompanion toCompanion(bool nullToAbsent) {
    return InfractionNotesCompanion(
      id: Value(id),
      infractionId: Value(infractionId),
      noteType: Value(noteType),
      comment: comment == null && nullToAbsent
          ? const Value.absent()
          : Value(comment),
      deduction: Value(deduction),
    );
  }

  factory InfractionNote.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InfractionNote(
      id: serializer.fromJson<String>(json['id']),
      infractionId: serializer.fromJson<String>(json['infractionId']),
      noteType: serializer.fromJson<String>(json['noteType']),
      comment: serializer.fromJson<String?>(json['comment']),
      deduction: serializer.fromJson<int>(json['deduction']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'infractionId': serializer.toJson<String>(infractionId),
      'noteType': serializer.toJson<String>(noteType),
      'comment': serializer.toJson<String?>(comment),
      'deduction': serializer.toJson<int>(deduction),
    };
  }

  InfractionNote copyWith(
          {String? id,
          String? infractionId,
          String? noteType,
          Value<String?> comment = const Value.absent(),
          int? deduction}) =>
      InfractionNote(
        id: id ?? this.id,
        infractionId: infractionId ?? this.infractionId,
        noteType: noteType ?? this.noteType,
        comment: comment.present ? comment.value : this.comment,
        deduction: deduction ?? this.deduction,
      );
  InfractionNote copyWithCompanion(InfractionNotesCompanion data) {
    return InfractionNote(
      id: data.id.present ? data.id.value : this.id,
      infractionId: data.infractionId.present
          ? data.infractionId.value
          : this.infractionId,
      noteType: data.noteType.present ? data.noteType.value : this.noteType,
      comment: data.comment.present ? data.comment.value : this.comment,
      deduction: data.deduction.present ? data.deduction.value : this.deduction,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InfractionNote(')
          ..write('id: $id, ')
          ..write('infractionId: $infractionId, ')
          ..write('noteType: $noteType, ')
          ..write('comment: $comment, ')
          ..write('deduction: $deduction')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, infractionId, noteType, comment, deduction);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InfractionNote &&
          other.id == this.id &&
          other.infractionId == this.infractionId &&
          other.noteType == this.noteType &&
          other.comment == this.comment &&
          other.deduction == this.deduction);
}

class InfractionNotesCompanion extends UpdateCompanion<InfractionNote> {
  final Value<String> id;
  final Value<String> infractionId;
  final Value<String> noteType;
  final Value<String?> comment;
  final Value<int> deduction;
  final Value<int> rowid;
  const InfractionNotesCompanion({
    this.id = const Value.absent(),
    this.infractionId = const Value.absent(),
    this.noteType = const Value.absent(),
    this.comment = const Value.absent(),
    this.deduction = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  InfractionNotesCompanion.insert({
    required String id,
    required String infractionId,
    required String noteType,
    this.comment = const Value.absent(),
    required int deduction,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        infractionId = Value(infractionId),
        noteType = Value(noteType),
        deduction = Value(deduction);
  static Insertable<InfractionNote> custom({
    Expression<String>? id,
    Expression<String>? infractionId,
    Expression<String>? noteType,
    Expression<String>? comment,
    Expression<int>? deduction,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (infractionId != null) 'infraction_id': infractionId,
      if (noteType != null) 'note_type': noteType,
      if (comment != null) 'comment': comment,
      if (deduction != null) 'deduction': deduction,
      if (rowid != null) 'rowid': rowid,
    });
  }

  InfractionNotesCompanion copyWith(
      {Value<String>? id,
      Value<String>? infractionId,
      Value<String>? noteType,
      Value<String?>? comment,
      Value<int>? deduction,
      Value<int>? rowid}) {
    return InfractionNotesCompanion(
      id: id ?? this.id,
      infractionId: infractionId ?? this.infractionId,
      noteType: noteType ?? this.noteType,
      comment: comment ?? this.comment,
      deduction: deduction ?? this.deduction,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (infractionId.present) {
      map['infraction_id'] = Variable<String>(infractionId.value);
    }
    if (noteType.present) {
      map['note_type'] = Variable<String>(noteType.value);
    }
    if (comment.present) {
      map['comment'] = Variable<String>(comment.value);
    }
    if (deduction.present) {
      map['deduction'] = Variable<int>(deduction.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InfractionNotesCompanion(')
          ..write('id: $id, ')
          ..write('infractionId: $infractionId, ')
          ..write('noteType: $noteType, ')
          ..write('comment: $comment, ')
          ..write('deduction: $deduction, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalAssessmentsTable extends LocalAssessments
    with TableInfo<$LocalAssessmentsTable, LocalAssessment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalAssessmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _trainingParticipantIdMeta =
      const VerificationMeta('trainingParticipantId');
  @override
  late final GeneratedColumn<String> trainingParticipantId =
      GeneratedColumn<String>('training_participant_id', aliasedName, false,
          type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sessionIdMeta =
      const VerificationMeta('sessionId');
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
      'session_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
      'date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _startTimeMeta =
      const VerificationMeta('startTime');
  @override
  late final GeneratedColumn<DateTime> startTime = GeneratedColumn<DateTime>(
      'start_time', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _endTimeMeta =
      const VerificationMeta('endTime');
  @override
  late final GeneratedColumn<DateTime> endTime = GeneratedColumn<DateTime>(
      'end_time', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  late final GeneratedColumnWithTypeConverter<LocalSyncStatus, String>
      syncStatus = GeneratedColumn<String>('sync_status', aliasedName, false,
              type: DriftSqlType.string, requiredDuringInsert: true)
          .withConverter<LocalSyncStatus>(
              $LocalAssessmentsTable.$convertersyncStatus);
  static const VerificationMeta _lastErrorMeta =
      const VerificationMeta('lastError');
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
      'last_error', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _lastAttemptAtMeta =
      const VerificationMeta('lastAttemptAt');
  @override
  late final GeneratedColumn<DateTime> lastAttemptAt =
      GeneratedColumn<DateTime>('last_attempt_at', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _attemptCountMeta =
      const VerificationMeta('attemptCount');
  @override
  late final GeneratedColumn<int> attemptCount = GeneratedColumn<int>(
      'attempt_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _ownerUserIdMeta =
      const VerificationMeta('ownerUserId');
  @override
  late final GeneratedColumn<String> ownerUserId = GeneratedColumn<String>(
      'owner_user_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _participantNameMeta =
      const VerificationMeta('participantName');
  @override
  late final GeneratedColumn<String> participantName = GeneratedColumn<String>(
      'participant_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _scoreMeta = const VerificationMeta('score');
  @override
  late final GeneratedColumn<double> score = GeneratedColumn<double>(
      'score', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        trainingParticipantId,
        sessionId,
        date,
        startTime,
        endTime,
        syncStatus,
        lastError,
        lastAttemptAt,
        attemptCount,
        createdAt,
        updatedAt,
        ownerUserId,
        participantName,
        score
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_assessments';
  @override
  VerificationContext validateIntegrity(Insertable<LocalAssessment> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('training_participant_id')) {
      context.handle(
          _trainingParticipantIdMeta,
          trainingParticipantId.isAcceptableOrUnknown(
              data['training_participant_id']!, _trainingParticipantIdMeta));
    } else if (isInserting) {
      context.missing(_trainingParticipantIdMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(_sessionIdMeta,
          sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta));
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
          _dateMeta, date.isAcceptableOrUnknown(data['date']!, _dateMeta));
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('start_time')) {
      context.handle(_startTimeMeta,
          startTime.isAcceptableOrUnknown(data['start_time']!, _startTimeMeta));
    } else if (isInserting) {
      context.missing(_startTimeMeta);
    }
    if (data.containsKey('end_time')) {
      context.handle(_endTimeMeta,
          endTime.isAcceptableOrUnknown(data['end_time']!, _endTimeMeta));
    }
    if (data.containsKey('last_error')) {
      context.handle(_lastErrorMeta,
          lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta));
    }
    if (data.containsKey('last_attempt_at')) {
      context.handle(
          _lastAttemptAtMeta,
          lastAttemptAt.isAcceptableOrUnknown(
              data['last_attempt_at']!, _lastAttemptAtMeta));
    }
    if (data.containsKey('attempt_count')) {
      context.handle(
          _attemptCountMeta,
          attemptCount.isAcceptableOrUnknown(
              data['attempt_count']!, _attemptCountMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('owner_user_id')) {
      context.handle(
          _ownerUserIdMeta,
          ownerUserId.isAcceptableOrUnknown(
              data['owner_user_id']!, _ownerUserIdMeta));
    }
    if (data.containsKey('participant_name')) {
      context.handle(
          _participantNameMeta,
          participantName.isAcceptableOrUnknown(
              data['participant_name']!, _participantNameMeta));
    }
    if (data.containsKey('score')) {
      context.handle(
          _scoreMeta, score.isAcceptableOrUnknown(data['score']!, _scoreMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {trainingParticipantId},
      ];
  @override
  LocalAssessment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalAssessment(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      trainingParticipantId: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}training_participant_id'])!,
      sessionId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}session_id'])!,
      date: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}date'])!,
      startTime: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}start_time'])!,
      endTime: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}end_time']),
      syncStatus: $LocalAssessmentsTable.$convertersyncStatus.fromSql(
          attachedDatabase.typeMapping.read(
              DriftSqlType.string, data['${effectivePrefix}sync_status'])!),
      lastError: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}last_error']),
      lastAttemptAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_attempt_at']),
      attemptCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}attempt_count'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      ownerUserId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}owner_user_id']),
      participantName: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}participant_name']),
      score: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}score']),
    );
  }

  @override
  $LocalAssessmentsTable createAlias(String alias) {
    return $LocalAssessmentsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<LocalSyncStatus, String, String>
      $convertersyncStatus =
      const EnumNameConverter<LocalSyncStatus>(LocalSyncStatus.values);
}

class LocalAssessment extends DataClass implements Insertable<LocalAssessment> {
  /// Id local (uuid), gerado no aparelho — o id do backend só existe após o sync.
  final String id;

  /// `TrainingParticipant.id`; um participante tem no máximo uma avaliação.
  final String trainingParticipantId;
  final String sessionId;
  final DateTime date;
  final DateTime startTime;
  final DateTime? endTime;
  final LocalSyncStatus syncStatus;

  /// Mensagem do último erro de envio, mostrada na tela de Sincronização.
  final String? lastError;
  final DateTime? lastAttemptAt;
  final int attemptCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// `AuthUser.id` de quem fez a avaliação (decisão de 29/09/2026). O backend
  /// atribui a avaliação ao dono do token que a envia, então a fila só pode
  /// sair no nome de quem a preencheu. Nulo nas avaliações de antes da Fase
  /// 5A — ficam com o primeiro usuário que entrar
  /// (`AssessmentRepository.claimUnowned`).
  final String? ownerUserId;

  /// Nome do participante no "Confirmar": a aba Sincronizar mostra a fila
  /// mesmo depois que um logout apaga o cache de participantes.
  final String? participantName;

  /// % geral no "Confirmar" — o que a tela 1.6 mostrou. A linha "Na fila" e
  /// a aba Sincronizar mostram sem recalcular.
  final double? score;
  const LocalAssessment(
      {required this.id,
      required this.trainingParticipantId,
      required this.sessionId,
      required this.date,
      required this.startTime,
      this.endTime,
      required this.syncStatus,
      this.lastError,
      this.lastAttemptAt,
      required this.attemptCount,
      required this.createdAt,
      required this.updatedAt,
      this.ownerUserId,
      this.participantName,
      this.score});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['training_participant_id'] = Variable<String>(trainingParticipantId);
    map['session_id'] = Variable<String>(sessionId);
    map['date'] = Variable<DateTime>(date);
    map['start_time'] = Variable<DateTime>(startTime);
    if (!nullToAbsent || endTime != null) {
      map['end_time'] = Variable<DateTime>(endTime);
    }
    {
      map['sync_status'] = Variable<String>(
          $LocalAssessmentsTable.$convertersyncStatus.toSql(syncStatus));
    }
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    if (!nullToAbsent || lastAttemptAt != null) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt);
    }
    map['attempt_count'] = Variable<int>(attemptCount);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || ownerUserId != null) {
      map['owner_user_id'] = Variable<String>(ownerUserId);
    }
    if (!nullToAbsent || participantName != null) {
      map['participant_name'] = Variable<String>(participantName);
    }
    if (!nullToAbsent || score != null) {
      map['score'] = Variable<double>(score);
    }
    return map;
  }

  LocalAssessmentsCompanion toCompanion(bool nullToAbsent) {
    return LocalAssessmentsCompanion(
      id: Value(id),
      trainingParticipantId: Value(trainingParticipantId),
      sessionId: Value(sessionId),
      date: Value(date),
      startTime: Value(startTime),
      endTime: endTime == null && nullToAbsent
          ? const Value.absent()
          : Value(endTime),
      syncStatus: Value(syncStatus),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      lastAttemptAt: lastAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastAttemptAt),
      attemptCount: Value(attemptCount),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      ownerUserId: ownerUserId == null && nullToAbsent
          ? const Value.absent()
          : Value(ownerUserId),
      participantName: participantName == null && nullToAbsent
          ? const Value.absent()
          : Value(participantName),
      score:
          score == null && nullToAbsent ? const Value.absent() : Value(score),
    );
  }

  factory LocalAssessment.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalAssessment(
      id: serializer.fromJson<String>(json['id']),
      trainingParticipantId:
          serializer.fromJson<String>(json['trainingParticipantId']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      date: serializer.fromJson<DateTime>(json['date']),
      startTime: serializer.fromJson<DateTime>(json['startTime']),
      endTime: serializer.fromJson<DateTime?>(json['endTime']),
      syncStatus: $LocalAssessmentsTable.$convertersyncStatus
          .fromJson(serializer.fromJson<String>(json['syncStatus'])),
      lastError: serializer.fromJson<String?>(json['lastError']),
      lastAttemptAt: serializer.fromJson<DateTime?>(json['lastAttemptAt']),
      attemptCount: serializer.fromJson<int>(json['attemptCount']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      ownerUserId: serializer.fromJson<String?>(json['ownerUserId']),
      participantName: serializer.fromJson<String?>(json['participantName']),
      score: serializer.fromJson<double?>(json['score']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'trainingParticipantId': serializer.toJson<String>(trainingParticipantId),
      'sessionId': serializer.toJson<String>(sessionId),
      'date': serializer.toJson<DateTime>(date),
      'startTime': serializer.toJson<DateTime>(startTime),
      'endTime': serializer.toJson<DateTime?>(endTime),
      'syncStatus': serializer.toJson<String>(
          $LocalAssessmentsTable.$convertersyncStatus.toJson(syncStatus)),
      'lastError': serializer.toJson<String?>(lastError),
      'lastAttemptAt': serializer.toJson<DateTime?>(lastAttemptAt),
      'attemptCount': serializer.toJson<int>(attemptCount),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'ownerUserId': serializer.toJson<String?>(ownerUserId),
      'participantName': serializer.toJson<String?>(participantName),
      'score': serializer.toJson<double?>(score),
    };
  }

  LocalAssessment copyWith(
          {String? id,
          String? trainingParticipantId,
          String? sessionId,
          DateTime? date,
          DateTime? startTime,
          Value<DateTime?> endTime = const Value.absent(),
          LocalSyncStatus? syncStatus,
          Value<String?> lastError = const Value.absent(),
          Value<DateTime?> lastAttemptAt = const Value.absent(),
          int? attemptCount,
          DateTime? createdAt,
          DateTime? updatedAt,
          Value<String?> ownerUserId = const Value.absent(),
          Value<String?> participantName = const Value.absent(),
          Value<double?> score = const Value.absent()}) =>
      LocalAssessment(
        id: id ?? this.id,
        trainingParticipantId:
            trainingParticipantId ?? this.trainingParticipantId,
        sessionId: sessionId ?? this.sessionId,
        date: date ?? this.date,
        startTime: startTime ?? this.startTime,
        endTime: endTime.present ? endTime.value : this.endTime,
        syncStatus: syncStatus ?? this.syncStatus,
        lastError: lastError.present ? lastError.value : this.lastError,
        lastAttemptAt:
            lastAttemptAt.present ? lastAttemptAt.value : this.lastAttemptAt,
        attemptCount: attemptCount ?? this.attemptCount,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        ownerUserId: ownerUserId.present ? ownerUserId.value : this.ownerUserId,
        participantName: participantName.present
            ? participantName.value
            : this.participantName,
        score: score.present ? score.value : this.score,
      );
  LocalAssessment copyWithCompanion(LocalAssessmentsCompanion data) {
    return LocalAssessment(
      id: data.id.present ? data.id.value : this.id,
      trainingParticipantId: data.trainingParticipantId.present
          ? data.trainingParticipantId.value
          : this.trainingParticipantId,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      date: data.date.present ? data.date.value : this.date,
      startTime: data.startTime.present ? data.startTime.value : this.startTime,
      endTime: data.endTime.present ? data.endTime.value : this.endTime,
      syncStatus:
          data.syncStatus.present ? data.syncStatus.value : this.syncStatus,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      lastAttemptAt: data.lastAttemptAt.present
          ? data.lastAttemptAt.value
          : this.lastAttemptAt,
      attemptCount: data.attemptCount.present
          ? data.attemptCount.value
          : this.attemptCount,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      ownerUserId:
          data.ownerUserId.present ? data.ownerUserId.value : this.ownerUserId,
      participantName: data.participantName.present
          ? data.participantName.value
          : this.participantName,
      score: data.score.present ? data.score.value : this.score,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalAssessment(')
          ..write('id: $id, ')
          ..write('trainingParticipantId: $trainingParticipantId, ')
          ..write('sessionId: $sessionId, ')
          ..write('date: $date, ')
          ..write('startTime: $startTime, ')
          ..write('endTime: $endTime, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('lastError: $lastError, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('ownerUserId: $ownerUserId, ')
          ..write('participantName: $participantName, ')
          ..write('score: $score')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      trainingParticipantId,
      sessionId,
      date,
      startTime,
      endTime,
      syncStatus,
      lastError,
      lastAttemptAt,
      attemptCount,
      createdAt,
      updatedAt,
      ownerUserId,
      participantName,
      score);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalAssessment &&
          other.id == this.id &&
          other.trainingParticipantId == this.trainingParticipantId &&
          other.sessionId == this.sessionId &&
          other.date == this.date &&
          other.startTime == this.startTime &&
          other.endTime == this.endTime &&
          other.syncStatus == this.syncStatus &&
          other.lastError == this.lastError &&
          other.lastAttemptAt == this.lastAttemptAt &&
          other.attemptCount == this.attemptCount &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.ownerUserId == this.ownerUserId &&
          other.participantName == this.participantName &&
          other.score == this.score);
}

class LocalAssessmentsCompanion extends UpdateCompanion<LocalAssessment> {
  final Value<String> id;
  final Value<String> trainingParticipantId;
  final Value<String> sessionId;
  final Value<DateTime> date;
  final Value<DateTime> startTime;
  final Value<DateTime?> endTime;
  final Value<LocalSyncStatus> syncStatus;
  final Value<String?> lastError;
  final Value<DateTime?> lastAttemptAt;
  final Value<int> attemptCount;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<String?> ownerUserId;
  final Value<String?> participantName;
  final Value<double?> score;
  final Value<int> rowid;
  const LocalAssessmentsCompanion({
    this.id = const Value.absent(),
    this.trainingParticipantId = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.date = const Value.absent(),
    this.startTime = const Value.absent(),
    this.endTime = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.lastError = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.ownerUserId = const Value.absent(),
    this.participantName = const Value.absent(),
    this.score = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalAssessmentsCompanion.insert({
    required String id,
    required String trainingParticipantId,
    required String sessionId,
    required DateTime date,
    required DateTime startTime,
    this.endTime = const Value.absent(),
    required LocalSyncStatus syncStatus,
    this.lastError = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.attemptCount = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.ownerUserId = const Value.absent(),
    this.participantName = const Value.absent(),
    this.score = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        trainingParticipantId = Value(trainingParticipantId),
        sessionId = Value(sessionId),
        date = Value(date),
        startTime = Value(startTime),
        syncStatus = Value(syncStatus),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<LocalAssessment> custom({
    Expression<String>? id,
    Expression<String>? trainingParticipantId,
    Expression<String>? sessionId,
    Expression<DateTime>? date,
    Expression<DateTime>? startTime,
    Expression<DateTime>? endTime,
    Expression<String>? syncStatus,
    Expression<String>? lastError,
    Expression<DateTime>? lastAttemptAt,
    Expression<int>? attemptCount,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? ownerUserId,
    Expression<String>? participantName,
    Expression<double>? score,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (trainingParticipantId != null)
        'training_participant_id': trainingParticipantId,
      if (sessionId != null) 'session_id': sessionId,
      if (date != null) 'date': date,
      if (startTime != null) 'start_time': startTime,
      if (endTime != null) 'end_time': endTime,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (lastError != null) 'last_error': lastError,
      if (lastAttemptAt != null) 'last_attempt_at': lastAttemptAt,
      if (attemptCount != null) 'attempt_count': attemptCount,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (ownerUserId != null) 'owner_user_id': ownerUserId,
      if (participantName != null) 'participant_name': participantName,
      if (score != null) 'score': score,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalAssessmentsCompanion copyWith(
      {Value<String>? id,
      Value<String>? trainingParticipantId,
      Value<String>? sessionId,
      Value<DateTime>? date,
      Value<DateTime>? startTime,
      Value<DateTime?>? endTime,
      Value<LocalSyncStatus>? syncStatus,
      Value<String?>? lastError,
      Value<DateTime?>? lastAttemptAt,
      Value<int>? attemptCount,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<String?>? ownerUserId,
      Value<String?>? participantName,
      Value<double?>? score,
      Value<int>? rowid}) {
    return LocalAssessmentsCompanion(
      id: id ?? this.id,
      trainingParticipantId:
          trainingParticipantId ?? this.trainingParticipantId,
      sessionId: sessionId ?? this.sessionId,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      syncStatus: syncStatus ?? this.syncStatus,
      lastError: lastError ?? this.lastError,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      attemptCount: attemptCount ?? this.attemptCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      participantName: participantName ?? this.participantName,
      score: score ?? this.score,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (trainingParticipantId.present) {
      map['training_participant_id'] =
          Variable<String>(trainingParticipantId.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (startTime.present) {
      map['start_time'] = Variable<DateTime>(startTime.value);
    }
    if (endTime.present) {
      map['end_time'] = Variable<DateTime>(endTime.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(
          $LocalAssessmentsTable.$convertersyncStatus.toSql(syncStatus.value));
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (lastAttemptAt.present) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt.value);
    }
    if (attemptCount.present) {
      map['attempt_count'] = Variable<int>(attemptCount.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (ownerUserId.present) {
      map['owner_user_id'] = Variable<String>(ownerUserId.value);
    }
    if (participantName.present) {
      map['participant_name'] = Variable<String>(participantName.value);
    }
    if (score.present) {
      map['score'] = Variable<double>(score.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalAssessmentsCompanion(')
          ..write('id: $id, ')
          ..write('trainingParticipantId: $trainingParticipantId, ')
          ..write('sessionId: $sessionId, ')
          ..write('date: $date, ')
          ..write('startTime: $startTime, ')
          ..write('endTime: $endTime, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('lastError: $lastError, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('ownerUserId: $ownerUserId, ')
          ..write('participantName: $participantName, ')
          ..write('score: $score, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalAssessmentItemsTable extends LocalAssessmentItems
    with TableInfo<$LocalAssessmentItemsTable, LocalAssessmentItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalAssessmentItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _localAssessmentIdMeta =
      const VerificationMeta('localAssessmentId');
  @override
  late final GeneratedColumn<String> localAssessmentId =
      GeneratedColumn<String>('local_assessment_id', aliasedName, false,
          type: DriftSqlType.string,
          requiredDuringInsert: true,
          defaultConstraints: GeneratedColumn.constraintIsAlways(
              'REFERENCES local_assessments (id)'));
  static const VerificationMeta _infractionIdMeta =
      const VerificationMeta('infractionId');
  @override
  late final GeneratedColumn<String> infractionId = GeneratedColumn<String>(
      'infraction_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _infractionNoteIdMeta =
      const VerificationMeta('infractionNoteId');
  @override
  late final GeneratedColumn<String> infractionNoteId = GeneratedColumn<String>(
      'infraction_note_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, localAssessmentId, infractionId, infractionNoteId, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_assessment_items';
  @override
  VerificationContext validateIntegrity(
      Insertable<LocalAssessmentItem> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('local_assessment_id')) {
      context.handle(
          _localAssessmentIdMeta,
          localAssessmentId.isAcceptableOrUnknown(
              data['local_assessment_id']!, _localAssessmentIdMeta));
    } else if (isInserting) {
      context.missing(_localAssessmentIdMeta);
    }
    if (data.containsKey('infraction_id')) {
      context.handle(
          _infractionIdMeta,
          infractionId.isAcceptableOrUnknown(
              data['infraction_id']!, _infractionIdMeta));
    } else if (isInserting) {
      context.missing(_infractionIdMeta);
    }
    if (data.containsKey('infraction_note_id')) {
      context.handle(
          _infractionNoteIdMeta,
          infractionNoteId.isAcceptableOrUnknown(
              data['infraction_note_id']!, _infractionNoteIdMeta));
    } else if (isInserting) {
      context.missing(_infractionNoteIdMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {localAssessmentId, infractionId},
      ];
  @override
  LocalAssessmentItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalAssessmentItem(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      localAssessmentId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}local_assessment_id'])!,
      infractionId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}infraction_id'])!,
      infractionNoteId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}infraction_note_id'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $LocalAssessmentItemsTable createAlias(String alias) {
    return $LocalAssessmentItemsTable(attachedDatabase, alias);
  }
}

class LocalAssessmentItem extends DataClass
    implements Insertable<LocalAssessmentItem> {
  final String id;
  final String localAssessmentId;
  final String infractionId;

  /// `InfractionNote.id` escolhido — é o que o sync envia.
  final String infractionNoteId;
  final DateTime updatedAt;
  const LocalAssessmentItem(
      {required this.id,
      required this.localAssessmentId,
      required this.infractionId,
      required this.infractionNoteId,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['local_assessment_id'] = Variable<String>(localAssessmentId);
    map['infraction_id'] = Variable<String>(infractionId);
    map['infraction_note_id'] = Variable<String>(infractionNoteId);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  LocalAssessmentItemsCompanion toCompanion(bool nullToAbsent) {
    return LocalAssessmentItemsCompanion(
      id: Value(id),
      localAssessmentId: Value(localAssessmentId),
      infractionId: Value(infractionId),
      infractionNoteId: Value(infractionNoteId),
      updatedAt: Value(updatedAt),
    );
  }

  factory LocalAssessmentItem.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalAssessmentItem(
      id: serializer.fromJson<String>(json['id']),
      localAssessmentId: serializer.fromJson<String>(json['localAssessmentId']),
      infractionId: serializer.fromJson<String>(json['infractionId']),
      infractionNoteId: serializer.fromJson<String>(json['infractionNoteId']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'localAssessmentId': serializer.toJson<String>(localAssessmentId),
      'infractionId': serializer.toJson<String>(infractionId),
      'infractionNoteId': serializer.toJson<String>(infractionNoteId),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  LocalAssessmentItem copyWith(
          {String? id,
          String? localAssessmentId,
          String? infractionId,
          String? infractionNoteId,
          DateTime? updatedAt}) =>
      LocalAssessmentItem(
        id: id ?? this.id,
        localAssessmentId: localAssessmentId ?? this.localAssessmentId,
        infractionId: infractionId ?? this.infractionId,
        infractionNoteId: infractionNoteId ?? this.infractionNoteId,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  LocalAssessmentItem copyWithCompanion(LocalAssessmentItemsCompanion data) {
    return LocalAssessmentItem(
      id: data.id.present ? data.id.value : this.id,
      localAssessmentId: data.localAssessmentId.present
          ? data.localAssessmentId.value
          : this.localAssessmentId,
      infractionId: data.infractionId.present
          ? data.infractionId.value
          : this.infractionId,
      infractionNoteId: data.infractionNoteId.present
          ? data.infractionNoteId.value
          : this.infractionNoteId,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalAssessmentItem(')
          ..write('id: $id, ')
          ..write('localAssessmentId: $localAssessmentId, ')
          ..write('infractionId: $infractionId, ')
          ..write('infractionNoteId: $infractionNoteId, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, localAssessmentId, infractionId, infractionNoteId, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalAssessmentItem &&
          other.id == this.id &&
          other.localAssessmentId == this.localAssessmentId &&
          other.infractionId == this.infractionId &&
          other.infractionNoteId == this.infractionNoteId &&
          other.updatedAt == this.updatedAt);
}

class LocalAssessmentItemsCompanion
    extends UpdateCompanion<LocalAssessmentItem> {
  final Value<String> id;
  final Value<String> localAssessmentId;
  final Value<String> infractionId;
  final Value<String> infractionNoteId;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const LocalAssessmentItemsCompanion({
    this.id = const Value.absent(),
    this.localAssessmentId = const Value.absent(),
    this.infractionId = const Value.absent(),
    this.infractionNoteId = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalAssessmentItemsCompanion.insert({
    required String id,
    required String localAssessmentId,
    required String infractionId,
    required String infractionNoteId,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        localAssessmentId = Value(localAssessmentId),
        infractionId = Value(infractionId),
        infractionNoteId = Value(infractionNoteId),
        updatedAt = Value(updatedAt);
  static Insertable<LocalAssessmentItem> custom({
    Expression<String>? id,
    Expression<String>? localAssessmentId,
    Expression<String>? infractionId,
    Expression<String>? infractionNoteId,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (localAssessmentId != null) 'local_assessment_id': localAssessmentId,
      if (infractionId != null) 'infraction_id': infractionId,
      if (infractionNoteId != null) 'infraction_note_id': infractionNoteId,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalAssessmentItemsCompanion copyWith(
      {Value<String>? id,
      Value<String>? localAssessmentId,
      Value<String>? infractionId,
      Value<String>? infractionNoteId,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return LocalAssessmentItemsCompanion(
      id: id ?? this.id,
      localAssessmentId: localAssessmentId ?? this.localAssessmentId,
      infractionId: infractionId ?? this.infractionId,
      infractionNoteId: infractionNoteId ?? this.infractionNoteId,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (localAssessmentId.present) {
      map['local_assessment_id'] = Variable<String>(localAssessmentId.value);
    }
    if (infractionId.present) {
      map['infraction_id'] = Variable<String>(infractionId.value);
    }
    if (infractionNoteId.present) {
      map['infraction_note_id'] = Variable<String>(infractionNoteId.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalAssessmentItemsCompanion(')
          ..write('id: $id, ')
          ..write('localAssessmentId: $localAssessmentId, ')
          ..write('infractionId: $infractionId, ')
          ..write('infractionNoteId: $infractionNoteId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SessionsTable sessions = $SessionsTable(this);
  late final $ParticipantsTable participants = $ParticipantsTable(this);
  late final $SessionConsultantsTable sessionConsultants =
      $SessionConsultantsTable(this);
  late final $AssessmentCategoriesTable assessmentCategories =
      $AssessmentCategoriesTable(this);
  late final $InfractionsTable infractions = $InfractionsTable(this);
  late final $InfractionNotesTable infractionNotes =
      $InfractionNotesTable(this);
  late final $LocalAssessmentsTable localAssessments =
      $LocalAssessmentsTable(this);
  late final $LocalAssessmentItemsTable localAssessmentItems =
      $LocalAssessmentItemsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        sessions,
        participants,
        sessionConsultants,
        assessmentCategories,
        infractions,
        infractionNotes,
        localAssessments,
        localAssessmentItems
      ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules(
        [
          WritePropagation(
            on: TableUpdateQuery.onTableName('sessions',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('session_consultants', kind: UpdateKind.delete),
            ],
          ),
        ],
      );
}

typedef $$SessionsTableCreateCompanionBuilder = SessionsCompanion Function({
  required String id,
  required String companyName,
  Value<String?> companyLogoUrl,
  required String courseName,
  required String city,
  required String state,
  Value<DateTime?> date,
  required String status,
  Value<String?> notes,
  Value<int> totalParticipants,
  Value<int> assessableParticipants,
  Value<int> assessedParticipants,
  Value<String?> responsibleConsultantId,
  Value<DateTime?> participantsSyncedAt,
  required DateTime cachedAt,
  Value<int> rowid,
});
typedef $$SessionsTableUpdateCompanionBuilder = SessionsCompanion Function({
  Value<String> id,
  Value<String> companyName,
  Value<String?> companyLogoUrl,
  Value<String> courseName,
  Value<String> city,
  Value<String> state,
  Value<DateTime?> date,
  Value<String> status,
  Value<String?> notes,
  Value<int> totalParticipants,
  Value<int> assessableParticipants,
  Value<int> assessedParticipants,
  Value<String?> responsibleConsultantId,
  Value<DateTime?> participantsSyncedAt,
  Value<DateTime> cachedAt,
  Value<int> rowid,
});

final class $$SessionsTableReferences
    extends BaseReferences<_$AppDatabase, $SessionsTable, Session> {
  $$SessionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ParticipantsTable, List<Participant>>
      _participantsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
          db.participants,
          aliasName:
              $_aliasNameGenerator(db.sessions.id, db.participants.sessionId));

  $$ParticipantsTableProcessedTableManager get participantsRefs {
    final manager = $$ParticipantsTableTableManager($_db, $_db.participants)
        .filter((f) => f.sessionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_participantsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$SessionConsultantsTable,
      List<SessionConsultantRow>> _sessionConsultantsRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.sessionConsultants,
          aliasName: $_aliasNameGenerator(
              db.sessions.id, db.sessionConsultants.sessionId));

  $$SessionConsultantsTableProcessedTableManager get sessionConsultantsRefs {
    final manager = $$SessionConsultantsTableTableManager(
            $_db, $_db.sessionConsultants)
        .filter((f) => f.sessionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_sessionConsultantsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$SessionsTableFilterComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get companyName => $composableBuilder(
      column: $table.companyName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get companyLogoUrl => $composableBuilder(
      column: $table.companyLogoUrl,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get courseName => $composableBuilder(
      column: $table.courseName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get city => $composableBuilder(
      column: $table.city, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get state => $composableBuilder(
      column: $table.state, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get date => $composableBuilder(
      column: $table.date, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get totalParticipants => $composableBuilder(
      column: $table.totalParticipants,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get assessableParticipants => $composableBuilder(
      column: $table.assessableParticipants,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get assessedParticipants => $composableBuilder(
      column: $table.assessedParticipants,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get responsibleConsultantId => $composableBuilder(
      column: $table.responsibleConsultantId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get participantsSyncedAt => $composableBuilder(
      column: $table.participantsSyncedAt,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
      column: $table.cachedAt, builder: (column) => ColumnFilters(column));

  Expression<bool> participantsRefs(
      Expression<bool> Function($$ParticipantsTableFilterComposer f) f) {
    final $$ParticipantsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.participants,
        getReferencedColumn: (t) => t.sessionId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ParticipantsTableFilterComposer(
              $db: $db,
              $table: $db.participants,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> sessionConsultantsRefs(
      Expression<bool> Function($$SessionConsultantsTableFilterComposer f) f) {
    final $$SessionConsultantsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.sessionConsultants,
        getReferencedColumn: (t) => t.sessionId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SessionConsultantsTableFilterComposer(
              $db: $db,
              $table: $db.sessionConsultants,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$SessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get companyName => $composableBuilder(
      column: $table.companyName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get companyLogoUrl => $composableBuilder(
      column: $table.companyLogoUrl,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get courseName => $composableBuilder(
      column: $table.courseName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get city => $composableBuilder(
      column: $table.city, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get state => $composableBuilder(
      column: $table.state, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get date => $composableBuilder(
      column: $table.date, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get totalParticipants => $composableBuilder(
      column: $table.totalParticipants,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get assessableParticipants => $composableBuilder(
      column: $table.assessableParticipants,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get assessedParticipants => $composableBuilder(
      column: $table.assessedParticipants,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get responsibleConsultantId => $composableBuilder(
      column: $table.responsibleConsultantId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get participantsSyncedAt => $composableBuilder(
      column: $table.participantsSyncedAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
      column: $table.cachedAt, builder: (column) => ColumnOrderings(column));
}

class $$SessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get companyName => $composableBuilder(
      column: $table.companyName, builder: (column) => column);

  GeneratedColumn<String> get companyLogoUrl => $composableBuilder(
      column: $table.companyLogoUrl, builder: (column) => column);

  GeneratedColumn<String> get courseName => $composableBuilder(
      column: $table.courseName, builder: (column) => column);

  GeneratedColumn<String> get city =>
      $composableBuilder(column: $table.city, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<int> get totalParticipants => $composableBuilder(
      column: $table.totalParticipants, builder: (column) => column);

  GeneratedColumn<int> get assessableParticipants => $composableBuilder(
      column: $table.assessableParticipants, builder: (column) => column);

  GeneratedColumn<int> get assessedParticipants => $composableBuilder(
      column: $table.assessedParticipants, builder: (column) => column);

  GeneratedColumn<String> get responsibleConsultantId => $composableBuilder(
      column: $table.responsibleConsultantId, builder: (column) => column);

  GeneratedColumn<DateTime> get participantsSyncedAt => $composableBuilder(
      column: $table.participantsSyncedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);

  Expression<T> participantsRefs<T extends Object>(
      Expression<T> Function($$ParticipantsTableAnnotationComposer a) f) {
    final $$ParticipantsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.participants,
        getReferencedColumn: (t) => t.sessionId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ParticipantsTableAnnotationComposer(
              $db: $db,
              $table: $db.participants,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> sessionConsultantsRefs<T extends Object>(
      Expression<T> Function($$SessionConsultantsTableAnnotationComposer a) f) {
    final $$SessionConsultantsTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $db.sessionConsultants,
            getReferencedColumn: (t) => t.sessionId,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$SessionConsultantsTableAnnotationComposer(
                  $db: $db,
                  $table: $db.sessionConsultants,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return f(composer);
  }
}

class $$SessionsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SessionsTable,
    Session,
    $$SessionsTableFilterComposer,
    $$SessionsTableOrderingComposer,
    $$SessionsTableAnnotationComposer,
    $$SessionsTableCreateCompanionBuilder,
    $$SessionsTableUpdateCompanionBuilder,
    (Session, $$SessionsTableReferences),
    Session,
    PrefetchHooks Function(
        {bool participantsRefs, bool sessionConsultantsRefs})> {
  $$SessionsTableTableManager(_$AppDatabase db, $SessionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> companyName = const Value.absent(),
            Value<String?> companyLogoUrl = const Value.absent(),
            Value<String> courseName = const Value.absent(),
            Value<String> city = const Value.absent(),
            Value<String> state = const Value.absent(),
            Value<DateTime?> date = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<int> totalParticipants = const Value.absent(),
            Value<int> assessableParticipants = const Value.absent(),
            Value<int> assessedParticipants = const Value.absent(),
            Value<String?> responsibleConsultantId = const Value.absent(),
            Value<DateTime?> participantsSyncedAt = const Value.absent(),
            Value<DateTime> cachedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SessionsCompanion(
            id: id,
            companyName: companyName,
            companyLogoUrl: companyLogoUrl,
            courseName: courseName,
            city: city,
            state: state,
            date: date,
            status: status,
            notes: notes,
            totalParticipants: totalParticipants,
            assessableParticipants: assessableParticipants,
            assessedParticipants: assessedParticipants,
            responsibleConsultantId: responsibleConsultantId,
            participantsSyncedAt: participantsSyncedAt,
            cachedAt: cachedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String companyName,
            Value<String?> companyLogoUrl = const Value.absent(),
            required String courseName,
            required String city,
            required String state,
            Value<DateTime?> date = const Value.absent(),
            required String status,
            Value<String?> notes = const Value.absent(),
            Value<int> totalParticipants = const Value.absent(),
            Value<int> assessableParticipants = const Value.absent(),
            Value<int> assessedParticipants = const Value.absent(),
            Value<String?> responsibleConsultantId = const Value.absent(),
            Value<DateTime?> participantsSyncedAt = const Value.absent(),
            required DateTime cachedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              SessionsCompanion.insert(
            id: id,
            companyName: companyName,
            companyLogoUrl: companyLogoUrl,
            courseName: courseName,
            city: city,
            state: state,
            date: date,
            status: status,
            notes: notes,
            totalParticipants: totalParticipants,
            assessableParticipants: assessableParticipants,
            assessedParticipants: assessedParticipants,
            responsibleConsultantId: responsibleConsultantId,
            participantsSyncedAt: participantsSyncedAt,
            cachedAt: cachedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$SessionsTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: (
              {participantsRefs = false, sessionConsultantsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (participantsRefs) db.participants,
                if (sessionConsultantsRefs) db.sessionConsultants
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (participantsRefs)
                    await $_getPrefetchedData<Session, $SessionsTable,
                            Participant>(
                        currentTable: table,
                        referencedTable: $$SessionsTableReferences
                            ._participantsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$SessionsTableReferences(db, table, p0)
                                .participantsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.sessionId == item.id),
                        typedResults: items),
                  if (sessionConsultantsRefs)
                    await $_getPrefetchedData<Session, $SessionsTable,
                            SessionConsultantRow>(
                        currentTable: table,
                        referencedTable: $$SessionsTableReferences
                            ._sessionConsultantsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$SessionsTableReferences(db, table, p0)
                                .sessionConsultantsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.sessionId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$SessionsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SessionsTable,
    Session,
    $$SessionsTableFilterComposer,
    $$SessionsTableOrderingComposer,
    $$SessionsTableAnnotationComposer,
    $$SessionsTableCreateCompanionBuilder,
    $$SessionsTableUpdateCompanionBuilder,
    (Session, $$SessionsTableReferences),
    Session,
    PrefetchHooks Function(
        {bool participantsRefs, bool sessionConsultantsRefs})>;
typedef $$ParticipantsTableCreateCompanionBuilder = ParticipantsCompanion
    Function({
  required String id,
  required String sessionId,
  required String name,
  required String cpf,
  Value<String?> email,
  required String participationType,
  required String status,
  Value<String?> assignedConsultantId,
  Value<String?> assignedConsultantName,
  Value<double?> score,
  Value<String?> assessedByConsultantId,
  Value<DateTime?> assessedAt,
  required DateTime cachedAt,
  Value<int> rowid,
});
typedef $$ParticipantsTableUpdateCompanionBuilder = ParticipantsCompanion
    Function({
  Value<String> id,
  Value<String> sessionId,
  Value<String> name,
  Value<String> cpf,
  Value<String?> email,
  Value<String> participationType,
  Value<String> status,
  Value<String?> assignedConsultantId,
  Value<String?> assignedConsultantName,
  Value<double?> score,
  Value<String?> assessedByConsultantId,
  Value<DateTime?> assessedAt,
  Value<DateTime> cachedAt,
  Value<int> rowid,
});

final class $$ParticipantsTableReferences
    extends BaseReferences<_$AppDatabase, $ParticipantsTable, Participant> {
  $$ParticipantsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SessionsTable _sessionIdTable(_$AppDatabase db) =>
      db.sessions.createAlias(
          $_aliasNameGenerator(db.participants.sessionId, db.sessions.id));

  $$SessionsTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<String>('session_id')!;

    final manager = $$SessionsTableTableManager($_db, $_db.sessions)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$ParticipantsTableFilterComposer
    extends Composer<_$AppDatabase, $ParticipantsTable> {
  $$ParticipantsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get cpf => $composableBuilder(
      column: $table.cpf, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get email => $composableBuilder(
      column: $table.email, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get participationType => $composableBuilder(
      column: $table.participationType,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get assignedConsultantId => $composableBuilder(
      column: $table.assignedConsultantId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get assignedConsultantName => $composableBuilder(
      column: $table.assignedConsultantName,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get score => $composableBuilder(
      column: $table.score, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get assessedByConsultantId => $composableBuilder(
      column: $table.assessedByConsultantId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get assessedAt => $composableBuilder(
      column: $table.assessedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
      column: $table.cachedAt, builder: (column) => ColumnFilters(column));

  $$SessionsTableFilterComposer get sessionId {
    final $$SessionsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $db.sessions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SessionsTableFilterComposer(
              $db: $db,
              $table: $db.sessions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ParticipantsTableOrderingComposer
    extends Composer<_$AppDatabase, $ParticipantsTable> {
  $$ParticipantsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get cpf => $composableBuilder(
      column: $table.cpf, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get email => $composableBuilder(
      column: $table.email, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get participationType => $composableBuilder(
      column: $table.participationType,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get assignedConsultantId => $composableBuilder(
      column: $table.assignedConsultantId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get assignedConsultantName => $composableBuilder(
      column: $table.assignedConsultantName,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get score => $composableBuilder(
      column: $table.score, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get assessedByConsultantId => $composableBuilder(
      column: $table.assessedByConsultantId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get assessedAt => $composableBuilder(
      column: $table.assessedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
      column: $table.cachedAt, builder: (column) => ColumnOrderings(column));

  $$SessionsTableOrderingComposer get sessionId {
    final $$SessionsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $db.sessions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SessionsTableOrderingComposer(
              $db: $db,
              $table: $db.sessions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ParticipantsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ParticipantsTable> {
  $$ParticipantsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get cpf =>
      $composableBuilder(column: $table.cpf, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get participationType => $composableBuilder(
      column: $table.participationType, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get assignedConsultantId => $composableBuilder(
      column: $table.assignedConsultantId, builder: (column) => column);

  GeneratedColumn<String> get assignedConsultantName => $composableBuilder(
      column: $table.assignedConsultantName, builder: (column) => column);

  GeneratedColumn<double> get score =>
      $composableBuilder(column: $table.score, builder: (column) => column);

  GeneratedColumn<String> get assessedByConsultantId => $composableBuilder(
      column: $table.assessedByConsultantId, builder: (column) => column);

  GeneratedColumn<DateTime> get assessedAt => $composableBuilder(
      column: $table.assessedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);

  $$SessionsTableAnnotationComposer get sessionId {
    final $$SessionsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $db.sessions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SessionsTableAnnotationComposer(
              $db: $db,
              $table: $db.sessions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ParticipantsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ParticipantsTable,
    Participant,
    $$ParticipantsTableFilterComposer,
    $$ParticipantsTableOrderingComposer,
    $$ParticipantsTableAnnotationComposer,
    $$ParticipantsTableCreateCompanionBuilder,
    $$ParticipantsTableUpdateCompanionBuilder,
    (Participant, $$ParticipantsTableReferences),
    Participant,
    PrefetchHooks Function({bool sessionId})> {
  $$ParticipantsTableTableManager(_$AppDatabase db, $ParticipantsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ParticipantsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ParticipantsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ParticipantsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> sessionId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> cpf = const Value.absent(),
            Value<String?> email = const Value.absent(),
            Value<String> participationType = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String?> assignedConsultantId = const Value.absent(),
            Value<String?> assignedConsultantName = const Value.absent(),
            Value<double?> score = const Value.absent(),
            Value<String?> assessedByConsultantId = const Value.absent(),
            Value<DateTime?> assessedAt = const Value.absent(),
            Value<DateTime> cachedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ParticipantsCompanion(
            id: id,
            sessionId: sessionId,
            name: name,
            cpf: cpf,
            email: email,
            participationType: participationType,
            status: status,
            assignedConsultantId: assignedConsultantId,
            assignedConsultantName: assignedConsultantName,
            score: score,
            assessedByConsultantId: assessedByConsultantId,
            assessedAt: assessedAt,
            cachedAt: cachedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String sessionId,
            required String name,
            required String cpf,
            Value<String?> email = const Value.absent(),
            required String participationType,
            required String status,
            Value<String?> assignedConsultantId = const Value.absent(),
            Value<String?> assignedConsultantName = const Value.absent(),
            Value<double?> score = const Value.absent(),
            Value<String?> assessedByConsultantId = const Value.absent(),
            Value<DateTime?> assessedAt = const Value.absent(),
            required DateTime cachedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              ParticipantsCompanion.insert(
            id: id,
            sessionId: sessionId,
            name: name,
            cpf: cpf,
            email: email,
            participationType: participationType,
            status: status,
            assignedConsultantId: assignedConsultantId,
            assignedConsultantName: assignedConsultantName,
            score: score,
            assessedByConsultantId: assessedByConsultantId,
            assessedAt: assessedAt,
            cachedAt: cachedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$ParticipantsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({sessionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (sessionId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.sessionId,
                    referencedTable:
                        $$ParticipantsTableReferences._sessionIdTable(db),
                    referencedColumn:
                        $$ParticipantsTableReferences._sessionIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$ParticipantsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ParticipantsTable,
    Participant,
    $$ParticipantsTableFilterComposer,
    $$ParticipantsTableOrderingComposer,
    $$ParticipantsTableAnnotationComposer,
    $$ParticipantsTableCreateCompanionBuilder,
    $$ParticipantsTableUpdateCompanionBuilder,
    (Participant, $$ParticipantsTableReferences),
    Participant,
    PrefetchHooks Function({bool sessionId})>;
typedef $$SessionConsultantsTableCreateCompanionBuilder
    = SessionConsultantsCompanion Function({
  required String sessionId,
  required String consultantId,
  required String name,
  Value<String?> email,
  Value<int> rowid,
});
typedef $$SessionConsultantsTableUpdateCompanionBuilder
    = SessionConsultantsCompanion Function({
  Value<String> sessionId,
  Value<String> consultantId,
  Value<String> name,
  Value<String?> email,
  Value<int> rowid,
});

final class $$SessionConsultantsTableReferences extends BaseReferences<
    _$AppDatabase, $SessionConsultantsTable, SessionConsultantRow> {
  $$SessionConsultantsTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $SessionsTable _sessionIdTable(_$AppDatabase db) =>
      db.sessions.createAlias($_aliasNameGenerator(
          db.sessionConsultants.sessionId, db.sessions.id));

  $$SessionsTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<String>('session_id')!;

    final manager = $$SessionsTableTableManager($_db, $_db.sessions)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$SessionConsultantsTableFilterComposer
    extends Composer<_$AppDatabase, $SessionConsultantsTable> {
  $$SessionConsultantsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get consultantId => $composableBuilder(
      column: $table.consultantId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get email => $composableBuilder(
      column: $table.email, builder: (column) => ColumnFilters(column));

  $$SessionsTableFilterComposer get sessionId {
    final $$SessionsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $db.sessions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SessionsTableFilterComposer(
              $db: $db,
              $table: $db.sessions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$SessionConsultantsTableOrderingComposer
    extends Composer<_$AppDatabase, $SessionConsultantsTable> {
  $$SessionConsultantsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get consultantId => $composableBuilder(
      column: $table.consultantId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get email => $composableBuilder(
      column: $table.email, builder: (column) => ColumnOrderings(column));

  $$SessionsTableOrderingComposer get sessionId {
    final $$SessionsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $db.sessions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SessionsTableOrderingComposer(
              $db: $db,
              $table: $db.sessions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$SessionConsultantsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SessionConsultantsTable> {
  $$SessionConsultantsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get consultantId => $composableBuilder(
      column: $table.consultantId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  $$SessionsTableAnnotationComposer get sessionId {
    final $$SessionsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $db.sessions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SessionsTableAnnotationComposer(
              $db: $db,
              $table: $db.sessions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$SessionConsultantsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SessionConsultantsTable,
    SessionConsultantRow,
    $$SessionConsultantsTableFilterComposer,
    $$SessionConsultantsTableOrderingComposer,
    $$SessionConsultantsTableAnnotationComposer,
    $$SessionConsultantsTableCreateCompanionBuilder,
    $$SessionConsultantsTableUpdateCompanionBuilder,
    (SessionConsultantRow, $$SessionConsultantsTableReferences),
    SessionConsultantRow,
    PrefetchHooks Function({bool sessionId})> {
  $$SessionConsultantsTableTableManager(
      _$AppDatabase db, $SessionConsultantsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionConsultantsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionConsultantsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SessionConsultantsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> sessionId = const Value.absent(),
            Value<String> consultantId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> email = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SessionConsultantsCompanion(
            sessionId: sessionId,
            consultantId: consultantId,
            name: name,
            email: email,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String sessionId,
            required String consultantId,
            required String name,
            Value<String?> email = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SessionConsultantsCompanion.insert(
            sessionId: sessionId,
            consultantId: consultantId,
            name: name,
            email: email,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$SessionConsultantsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({sessionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (sessionId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.sessionId,
                    referencedTable:
                        $$SessionConsultantsTableReferences._sessionIdTable(db),
                    referencedColumn: $$SessionConsultantsTableReferences
                        ._sessionIdTable(db)
                        .id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$SessionConsultantsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SessionConsultantsTable,
    SessionConsultantRow,
    $$SessionConsultantsTableFilterComposer,
    $$SessionConsultantsTableOrderingComposer,
    $$SessionConsultantsTableAnnotationComposer,
    $$SessionConsultantsTableCreateCompanionBuilder,
    $$SessionConsultantsTableUpdateCompanionBuilder,
    (SessionConsultantRow, $$SessionConsultantsTableReferences),
    SessionConsultantRow,
    PrefetchHooks Function({bool sessionId})>;
typedef $$AssessmentCategoriesTableCreateCompanionBuilder
    = AssessmentCategoriesCompanion Function({
  required String id,
  required String code,
  required String name,
  Value<String?> description,
  required int order,
  Value<int> rowid,
});
typedef $$AssessmentCategoriesTableUpdateCompanionBuilder
    = AssessmentCategoriesCompanion Function({
  Value<String> id,
  Value<String> code,
  Value<String> name,
  Value<String?> description,
  Value<int> order,
  Value<int> rowid,
});

final class $$AssessmentCategoriesTableReferences extends BaseReferences<
    _$AppDatabase, $AssessmentCategoriesTable, AssessmentCategory> {
  $$AssessmentCategoriesTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$InfractionsTable, List<Infraction>>
      _infractionsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.infractions,
              aliasName: $_aliasNameGenerator(
                  db.assessmentCategories.id, db.infractions.categoryId));

  $$InfractionsTableProcessedTableManager get infractionsRefs {
    final manager = $$InfractionsTableTableManager($_db, $_db.infractions)
        .filter((f) => f.categoryId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_infractionsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$AssessmentCategoriesTableFilterComposer
    extends Composer<_$AppDatabase, $AssessmentCategoriesTable> {
  $$AssessmentCategoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get code => $composableBuilder(
      column: $table.code, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get order => $composableBuilder(
      column: $table.order, builder: (column) => ColumnFilters(column));

  Expression<bool> infractionsRefs(
      Expression<bool> Function($$InfractionsTableFilterComposer f) f) {
    final $$InfractionsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.infractions,
        getReferencedColumn: (t) => t.categoryId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$InfractionsTableFilterComposer(
              $db: $db,
              $table: $db.infractions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$AssessmentCategoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $AssessmentCategoriesTable> {
  $$AssessmentCategoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get code => $composableBuilder(
      column: $table.code, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get order => $composableBuilder(
      column: $table.order, builder: (column) => ColumnOrderings(column));
}

class $$AssessmentCategoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $AssessmentCategoriesTable> {
  $$AssessmentCategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<int> get order =>
      $composableBuilder(column: $table.order, builder: (column) => column);

  Expression<T> infractionsRefs<T extends Object>(
      Expression<T> Function($$InfractionsTableAnnotationComposer a) f) {
    final $$InfractionsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.infractions,
        getReferencedColumn: (t) => t.categoryId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$InfractionsTableAnnotationComposer(
              $db: $db,
              $table: $db.infractions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$AssessmentCategoriesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AssessmentCategoriesTable,
    AssessmentCategory,
    $$AssessmentCategoriesTableFilterComposer,
    $$AssessmentCategoriesTableOrderingComposer,
    $$AssessmentCategoriesTableAnnotationComposer,
    $$AssessmentCategoriesTableCreateCompanionBuilder,
    $$AssessmentCategoriesTableUpdateCompanionBuilder,
    (AssessmentCategory, $$AssessmentCategoriesTableReferences),
    AssessmentCategory,
    PrefetchHooks Function({bool infractionsRefs})> {
  $$AssessmentCategoriesTableTableManager(
      _$AppDatabase db, $AssessmentCategoriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AssessmentCategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AssessmentCategoriesTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AssessmentCategoriesTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> code = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<int> order = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AssessmentCategoriesCompanion(
            id: id,
            code: code,
            name: name,
            description: description,
            order: order,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String code,
            required String name,
            Value<String?> description = const Value.absent(),
            required int order,
            Value<int> rowid = const Value.absent(),
          }) =>
              AssessmentCategoriesCompanion.insert(
            id: id,
            code: code,
            name: name,
            description: description,
            order: order,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$AssessmentCategoriesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({infractionsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (infractionsRefs) db.infractions],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (infractionsRefs)
                    await $_getPrefetchedData<AssessmentCategory,
                            $AssessmentCategoriesTable, Infraction>(
                        currentTable: table,
                        referencedTable: $$AssessmentCategoriesTableReferences
                            ._infractionsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$AssessmentCategoriesTableReferences(db, table, p0)
                                .infractionsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.categoryId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$AssessmentCategoriesTableProcessedTableManager
    = ProcessedTableManager<
        _$AppDatabase,
        $AssessmentCategoriesTable,
        AssessmentCategory,
        $$AssessmentCategoriesTableFilterComposer,
        $$AssessmentCategoriesTableOrderingComposer,
        $$AssessmentCategoriesTableAnnotationComposer,
        $$AssessmentCategoriesTableCreateCompanionBuilder,
        $$AssessmentCategoriesTableUpdateCompanionBuilder,
        (AssessmentCategory, $$AssessmentCategoriesTableReferences),
        AssessmentCategory,
        PrefetchHooks Function({bool infractionsRefs})>;
typedef $$InfractionsTableCreateCompanionBuilder = InfractionsCompanion
    Function({
  required String id,
  required String categoryId,
  required String description,
  required int order,
  Value<int> rowid,
});
typedef $$InfractionsTableUpdateCompanionBuilder = InfractionsCompanion
    Function({
  Value<String> id,
  Value<String> categoryId,
  Value<String> description,
  Value<int> order,
  Value<int> rowid,
});

final class $$InfractionsTableReferences
    extends BaseReferences<_$AppDatabase, $InfractionsTable, Infraction> {
  $$InfractionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $AssessmentCategoriesTable _categoryIdTable(_$AppDatabase db) =>
      db.assessmentCategories.createAlias($_aliasNameGenerator(
          db.infractions.categoryId, db.assessmentCategories.id));

  $$AssessmentCategoriesTableProcessedTableManager get categoryId {
    final $_column = $_itemColumn<String>('category_id')!;

    final manager =
        $$AssessmentCategoriesTableTableManager($_db, $_db.assessmentCategories)
            .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static MultiTypedResultKey<$InfractionNotesTable, List<InfractionNote>>
      _infractionNotesRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.infractionNotes,
              aliasName: $_aliasNameGenerator(
                  db.infractions.id, db.infractionNotes.infractionId));

  $$InfractionNotesTableProcessedTableManager get infractionNotesRefs {
    final manager =
        $$InfractionNotesTableTableManager($_db, $_db.infractionNotes).filter(
            (f) => f.infractionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_infractionNotesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$InfractionsTableFilterComposer
    extends Composer<_$AppDatabase, $InfractionsTable> {
  $$InfractionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get order => $composableBuilder(
      column: $table.order, builder: (column) => ColumnFilters(column));

  $$AssessmentCategoriesTableFilterComposer get categoryId {
    final $$AssessmentCategoriesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.categoryId,
        referencedTable: $db.assessmentCategories,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$AssessmentCategoriesTableFilterComposer(
              $db: $db,
              $table: $db.assessmentCategories,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<bool> infractionNotesRefs(
      Expression<bool> Function($$InfractionNotesTableFilterComposer f) f) {
    final $$InfractionNotesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.infractionNotes,
        getReferencedColumn: (t) => t.infractionId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$InfractionNotesTableFilterComposer(
              $db: $db,
              $table: $db.infractionNotes,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$InfractionsTableOrderingComposer
    extends Composer<_$AppDatabase, $InfractionsTable> {
  $$InfractionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get order => $composableBuilder(
      column: $table.order, builder: (column) => ColumnOrderings(column));

  $$AssessmentCategoriesTableOrderingComposer get categoryId {
    final $$AssessmentCategoriesTableOrderingComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.categoryId,
            referencedTable: $db.assessmentCategories,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$AssessmentCategoriesTableOrderingComposer(
                  $db: $db,
                  $table: $db.assessmentCategories,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return composer;
  }
}

class $$InfractionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $InfractionsTable> {
  $$InfractionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<int> get order =>
      $composableBuilder(column: $table.order, builder: (column) => column);

  $$AssessmentCategoriesTableAnnotationComposer get categoryId {
    final $$AssessmentCategoriesTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.categoryId,
            referencedTable: $db.assessmentCategories,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$AssessmentCategoriesTableAnnotationComposer(
                  $db: $db,
                  $table: $db.assessmentCategories,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return composer;
  }

  Expression<T> infractionNotesRefs<T extends Object>(
      Expression<T> Function($$InfractionNotesTableAnnotationComposer a) f) {
    final $$InfractionNotesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.infractionNotes,
        getReferencedColumn: (t) => t.infractionId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$InfractionNotesTableAnnotationComposer(
              $db: $db,
              $table: $db.infractionNotes,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$InfractionsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $InfractionsTable,
    Infraction,
    $$InfractionsTableFilterComposer,
    $$InfractionsTableOrderingComposer,
    $$InfractionsTableAnnotationComposer,
    $$InfractionsTableCreateCompanionBuilder,
    $$InfractionsTableUpdateCompanionBuilder,
    (Infraction, $$InfractionsTableReferences),
    Infraction,
    PrefetchHooks Function({bool categoryId, bool infractionNotesRefs})> {
  $$InfractionsTableTableManager(_$AppDatabase db, $InfractionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InfractionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$InfractionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$InfractionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> categoryId = const Value.absent(),
            Value<String> description = const Value.absent(),
            Value<int> order = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              InfractionsCompanion(
            id: id,
            categoryId: categoryId,
            description: description,
            order: order,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String categoryId,
            required String description,
            required int order,
            Value<int> rowid = const Value.absent(),
          }) =>
              InfractionsCompanion.insert(
            id: id,
            categoryId: categoryId,
            description: description,
            order: order,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$InfractionsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: (
              {categoryId = false, infractionNotesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (infractionNotesRefs) db.infractionNotes
              ],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (categoryId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.categoryId,
                    referencedTable:
                        $$InfractionsTableReferences._categoryIdTable(db),
                    referencedColumn:
                        $$InfractionsTableReferences._categoryIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (infractionNotesRefs)
                    await $_getPrefetchedData<Infraction, $InfractionsTable,
                            InfractionNote>(
                        currentTable: table,
                        referencedTable: $$InfractionsTableReferences
                            ._infractionNotesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$InfractionsTableReferences(db, table, p0)
                                .infractionNotesRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.infractionId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$InfractionsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $InfractionsTable,
    Infraction,
    $$InfractionsTableFilterComposer,
    $$InfractionsTableOrderingComposer,
    $$InfractionsTableAnnotationComposer,
    $$InfractionsTableCreateCompanionBuilder,
    $$InfractionsTableUpdateCompanionBuilder,
    (Infraction, $$InfractionsTableReferences),
    Infraction,
    PrefetchHooks Function({bool categoryId, bool infractionNotesRefs})>;
typedef $$InfractionNotesTableCreateCompanionBuilder = InfractionNotesCompanion
    Function({
  required String id,
  required String infractionId,
  required String noteType,
  Value<String?> comment,
  required int deduction,
  Value<int> rowid,
});
typedef $$InfractionNotesTableUpdateCompanionBuilder = InfractionNotesCompanion
    Function({
  Value<String> id,
  Value<String> infractionId,
  Value<String> noteType,
  Value<String?> comment,
  Value<int> deduction,
  Value<int> rowid,
});

final class $$InfractionNotesTableReferences extends BaseReferences<
    _$AppDatabase, $InfractionNotesTable, InfractionNote> {
  $$InfractionNotesTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $InfractionsTable _infractionIdTable(_$AppDatabase db) =>
      db.infractions.createAlias($_aliasNameGenerator(
          db.infractionNotes.infractionId, db.infractions.id));

  $$InfractionsTableProcessedTableManager get infractionId {
    final $_column = $_itemColumn<String>('infraction_id')!;

    final manager = $$InfractionsTableTableManager($_db, $_db.infractions)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_infractionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$InfractionNotesTableFilterComposer
    extends Composer<_$AppDatabase, $InfractionNotesTable> {
  $$InfractionNotesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get noteType => $composableBuilder(
      column: $table.noteType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get comment => $composableBuilder(
      column: $table.comment, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get deduction => $composableBuilder(
      column: $table.deduction, builder: (column) => ColumnFilters(column));

  $$InfractionsTableFilterComposer get infractionId {
    final $$InfractionsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.infractionId,
        referencedTable: $db.infractions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$InfractionsTableFilterComposer(
              $db: $db,
              $table: $db.infractions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$InfractionNotesTableOrderingComposer
    extends Composer<_$AppDatabase, $InfractionNotesTable> {
  $$InfractionNotesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get noteType => $composableBuilder(
      column: $table.noteType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get comment => $composableBuilder(
      column: $table.comment, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get deduction => $composableBuilder(
      column: $table.deduction, builder: (column) => ColumnOrderings(column));

  $$InfractionsTableOrderingComposer get infractionId {
    final $$InfractionsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.infractionId,
        referencedTable: $db.infractions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$InfractionsTableOrderingComposer(
              $db: $db,
              $table: $db.infractions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$InfractionNotesTableAnnotationComposer
    extends Composer<_$AppDatabase, $InfractionNotesTable> {
  $$InfractionNotesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get noteType =>
      $composableBuilder(column: $table.noteType, builder: (column) => column);

  GeneratedColumn<String> get comment =>
      $composableBuilder(column: $table.comment, builder: (column) => column);

  GeneratedColumn<int> get deduction =>
      $composableBuilder(column: $table.deduction, builder: (column) => column);

  $$InfractionsTableAnnotationComposer get infractionId {
    final $$InfractionsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.infractionId,
        referencedTable: $db.infractions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$InfractionsTableAnnotationComposer(
              $db: $db,
              $table: $db.infractions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$InfractionNotesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $InfractionNotesTable,
    InfractionNote,
    $$InfractionNotesTableFilterComposer,
    $$InfractionNotesTableOrderingComposer,
    $$InfractionNotesTableAnnotationComposer,
    $$InfractionNotesTableCreateCompanionBuilder,
    $$InfractionNotesTableUpdateCompanionBuilder,
    (InfractionNote, $$InfractionNotesTableReferences),
    InfractionNote,
    PrefetchHooks Function({bool infractionId})> {
  $$InfractionNotesTableTableManager(
      _$AppDatabase db, $InfractionNotesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InfractionNotesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$InfractionNotesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$InfractionNotesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> infractionId = const Value.absent(),
            Value<String> noteType = const Value.absent(),
            Value<String?> comment = const Value.absent(),
            Value<int> deduction = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              InfractionNotesCompanion(
            id: id,
            infractionId: infractionId,
            noteType: noteType,
            comment: comment,
            deduction: deduction,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String infractionId,
            required String noteType,
            Value<String?> comment = const Value.absent(),
            required int deduction,
            Value<int> rowid = const Value.absent(),
          }) =>
              InfractionNotesCompanion.insert(
            id: id,
            infractionId: infractionId,
            noteType: noteType,
            comment: comment,
            deduction: deduction,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$InfractionNotesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({infractionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (infractionId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.infractionId,
                    referencedTable:
                        $$InfractionNotesTableReferences._infractionIdTable(db),
                    referencedColumn: $$InfractionNotesTableReferences
                        ._infractionIdTable(db)
                        .id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$InfractionNotesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $InfractionNotesTable,
    InfractionNote,
    $$InfractionNotesTableFilterComposer,
    $$InfractionNotesTableOrderingComposer,
    $$InfractionNotesTableAnnotationComposer,
    $$InfractionNotesTableCreateCompanionBuilder,
    $$InfractionNotesTableUpdateCompanionBuilder,
    (InfractionNote, $$InfractionNotesTableReferences),
    InfractionNote,
    PrefetchHooks Function({bool infractionId})>;
typedef $$LocalAssessmentsTableCreateCompanionBuilder
    = LocalAssessmentsCompanion Function({
  required String id,
  required String trainingParticipantId,
  required String sessionId,
  required DateTime date,
  required DateTime startTime,
  Value<DateTime?> endTime,
  required LocalSyncStatus syncStatus,
  Value<String?> lastError,
  Value<DateTime?> lastAttemptAt,
  Value<int> attemptCount,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<String?> ownerUserId,
  Value<String?> participantName,
  Value<double?> score,
  Value<int> rowid,
});
typedef $$LocalAssessmentsTableUpdateCompanionBuilder
    = LocalAssessmentsCompanion Function({
  Value<String> id,
  Value<String> trainingParticipantId,
  Value<String> sessionId,
  Value<DateTime> date,
  Value<DateTime> startTime,
  Value<DateTime?> endTime,
  Value<LocalSyncStatus> syncStatus,
  Value<String?> lastError,
  Value<DateTime?> lastAttemptAt,
  Value<int> attemptCount,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<String?> ownerUserId,
  Value<String?> participantName,
  Value<double?> score,
  Value<int> rowid,
});

final class $$LocalAssessmentsTableReferences extends BaseReferences<
    _$AppDatabase, $LocalAssessmentsTable, LocalAssessment> {
  $$LocalAssessmentsTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$LocalAssessmentItemsTable,
      List<LocalAssessmentItem>> _localAssessmentItemsRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.localAssessmentItems,
          aliasName: $_aliasNameGenerator(db.localAssessments.id,
              db.localAssessmentItems.localAssessmentId));

  $$LocalAssessmentItemsTableProcessedTableManager
      get localAssessmentItemsRefs {
    final manager =
        $$LocalAssessmentItemsTableTableManager($_db, $_db.localAssessmentItems)
            .filter((f) =>
                f.localAssessmentId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_localAssessmentItemsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$LocalAssessmentsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalAssessmentsTable> {
  $$LocalAssessmentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get trainingParticipantId => $composableBuilder(
      column: $table.trainingParticipantId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sessionId => $composableBuilder(
      column: $table.sessionId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get date => $composableBuilder(
      column: $table.date, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get startTime => $composableBuilder(
      column: $table.startTime, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get endTime => $composableBuilder(
      column: $table.endTime, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<LocalSyncStatus, LocalSyncStatus, String>
      get syncStatus => $composableBuilder(
          column: $table.syncStatus,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<String> get lastError => $composableBuilder(
      column: $table.lastError, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastAttemptAt => $composableBuilder(
      column: $table.lastAttemptAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get attemptCount => $composableBuilder(
      column: $table.attemptCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get ownerUserId => $composableBuilder(
      column: $table.ownerUserId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get participantName => $composableBuilder(
      column: $table.participantName,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get score => $composableBuilder(
      column: $table.score, builder: (column) => ColumnFilters(column));

  Expression<bool> localAssessmentItemsRefs(
      Expression<bool> Function($$LocalAssessmentItemsTableFilterComposer f)
          f) {
    final $$LocalAssessmentItemsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.localAssessmentItems,
        getReferencedColumn: (t) => t.localAssessmentId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$LocalAssessmentItemsTableFilterComposer(
              $db: $db,
              $table: $db.localAssessmentItems,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$LocalAssessmentsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalAssessmentsTable> {
  $$LocalAssessmentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get trainingParticipantId => $composableBuilder(
      column: $table.trainingParticipantId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sessionId => $composableBuilder(
      column: $table.sessionId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get date => $composableBuilder(
      column: $table.date, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get startTime => $composableBuilder(
      column: $table.startTime, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get endTime => $composableBuilder(
      column: $table.endTime, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastError => $composableBuilder(
      column: $table.lastError, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastAttemptAt => $composableBuilder(
      column: $table.lastAttemptAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get attemptCount => $composableBuilder(
      column: $table.attemptCount,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get ownerUserId => $composableBuilder(
      column: $table.ownerUserId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get participantName => $composableBuilder(
      column: $table.participantName,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get score => $composableBuilder(
      column: $table.score, builder: (column) => ColumnOrderings(column));
}

class $$LocalAssessmentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalAssessmentsTable> {
  $$LocalAssessmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get trainingParticipantId => $composableBuilder(
      column: $table.trainingParticipantId, builder: (column) => column);

  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<DateTime> get startTime =>
      $composableBuilder(column: $table.startTime, builder: (column) => column);

  GeneratedColumn<DateTime> get endTime =>
      $composableBuilder(column: $table.endTime, builder: (column) => column);

  GeneratedColumnWithTypeConverter<LocalSyncStatus, String> get syncStatus =>
      $composableBuilder(
          column: $table.syncStatus, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<DateTime> get lastAttemptAt => $composableBuilder(
      column: $table.lastAttemptAt, builder: (column) => column);

  GeneratedColumn<int> get attemptCount => $composableBuilder(
      column: $table.attemptCount, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get ownerUserId => $composableBuilder(
      column: $table.ownerUserId, builder: (column) => column);

  GeneratedColumn<String> get participantName => $composableBuilder(
      column: $table.participantName, builder: (column) => column);

  GeneratedColumn<double> get score =>
      $composableBuilder(column: $table.score, builder: (column) => column);

  Expression<T> localAssessmentItemsRefs<T extends Object>(
      Expression<T> Function($$LocalAssessmentItemsTableAnnotationComposer a)
          f) {
    final $$LocalAssessmentItemsTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $db.localAssessmentItems,
            getReferencedColumn: (t) => t.localAssessmentId,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$LocalAssessmentItemsTableAnnotationComposer(
                  $db: $db,
                  $table: $db.localAssessmentItems,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return f(composer);
  }
}

class $$LocalAssessmentsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $LocalAssessmentsTable,
    LocalAssessment,
    $$LocalAssessmentsTableFilterComposer,
    $$LocalAssessmentsTableOrderingComposer,
    $$LocalAssessmentsTableAnnotationComposer,
    $$LocalAssessmentsTableCreateCompanionBuilder,
    $$LocalAssessmentsTableUpdateCompanionBuilder,
    (LocalAssessment, $$LocalAssessmentsTableReferences),
    LocalAssessment,
    PrefetchHooks Function({bool localAssessmentItemsRefs})> {
  $$LocalAssessmentsTableTableManager(
      _$AppDatabase db, $LocalAssessmentsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalAssessmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalAssessmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalAssessmentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> trainingParticipantId = const Value.absent(),
            Value<String> sessionId = const Value.absent(),
            Value<DateTime> date = const Value.absent(),
            Value<DateTime> startTime = const Value.absent(),
            Value<DateTime?> endTime = const Value.absent(),
            Value<LocalSyncStatus> syncStatus = const Value.absent(),
            Value<String?> lastError = const Value.absent(),
            Value<DateTime?> lastAttemptAt = const Value.absent(),
            Value<int> attemptCount = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<String?> ownerUserId = const Value.absent(),
            Value<String?> participantName = const Value.absent(),
            Value<double?> score = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalAssessmentsCompanion(
            id: id,
            trainingParticipantId: trainingParticipantId,
            sessionId: sessionId,
            date: date,
            startTime: startTime,
            endTime: endTime,
            syncStatus: syncStatus,
            lastError: lastError,
            lastAttemptAt: lastAttemptAt,
            attemptCount: attemptCount,
            createdAt: createdAt,
            updatedAt: updatedAt,
            ownerUserId: ownerUserId,
            participantName: participantName,
            score: score,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String trainingParticipantId,
            required String sessionId,
            required DateTime date,
            required DateTime startTime,
            Value<DateTime?> endTime = const Value.absent(),
            required LocalSyncStatus syncStatus,
            Value<String?> lastError = const Value.absent(),
            Value<DateTime?> lastAttemptAt = const Value.absent(),
            Value<int> attemptCount = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<String?> ownerUserId = const Value.absent(),
            Value<String?> participantName = const Value.absent(),
            Value<double?> score = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalAssessmentsCompanion.insert(
            id: id,
            trainingParticipantId: trainingParticipantId,
            sessionId: sessionId,
            date: date,
            startTime: startTime,
            endTime: endTime,
            syncStatus: syncStatus,
            lastError: lastError,
            lastAttemptAt: lastAttemptAt,
            attemptCount: attemptCount,
            createdAt: createdAt,
            updatedAt: updatedAt,
            ownerUserId: ownerUserId,
            participantName: participantName,
            score: score,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$LocalAssessmentsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({localAssessmentItemsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (localAssessmentItemsRefs) db.localAssessmentItems
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (localAssessmentItemsRefs)
                    await $_getPrefetchedData<LocalAssessment,
                            $LocalAssessmentsTable, LocalAssessmentItem>(
                        currentTable: table,
                        referencedTable: $$LocalAssessmentsTableReferences
                            ._localAssessmentItemsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$LocalAssessmentsTableReferences(db, table, p0)
                                .localAssessmentItemsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.localAssessmentId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$LocalAssessmentsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $LocalAssessmentsTable,
    LocalAssessment,
    $$LocalAssessmentsTableFilterComposer,
    $$LocalAssessmentsTableOrderingComposer,
    $$LocalAssessmentsTableAnnotationComposer,
    $$LocalAssessmentsTableCreateCompanionBuilder,
    $$LocalAssessmentsTableUpdateCompanionBuilder,
    (LocalAssessment, $$LocalAssessmentsTableReferences),
    LocalAssessment,
    PrefetchHooks Function({bool localAssessmentItemsRefs})>;
typedef $$LocalAssessmentItemsTableCreateCompanionBuilder
    = LocalAssessmentItemsCompanion Function({
  required String id,
  required String localAssessmentId,
  required String infractionId,
  required String infractionNoteId,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$LocalAssessmentItemsTableUpdateCompanionBuilder
    = LocalAssessmentItemsCompanion Function({
  Value<String> id,
  Value<String> localAssessmentId,
  Value<String> infractionId,
  Value<String> infractionNoteId,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

final class $$LocalAssessmentItemsTableReferences extends BaseReferences<
    _$AppDatabase, $LocalAssessmentItemsTable, LocalAssessmentItem> {
  $$LocalAssessmentItemsTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $LocalAssessmentsTable _localAssessmentIdTable(_$AppDatabase db) =>
      db.localAssessments.createAlias($_aliasNameGenerator(
          db.localAssessmentItems.localAssessmentId, db.localAssessments.id));

  $$LocalAssessmentsTableProcessedTableManager get localAssessmentId {
    final $_column = $_itemColumn<String>('local_assessment_id')!;

    final manager =
        $$LocalAssessmentsTableTableManager($_db, $_db.localAssessments)
            .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_localAssessmentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$LocalAssessmentItemsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalAssessmentItemsTable> {
  $$LocalAssessmentItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get infractionId => $composableBuilder(
      column: $table.infractionId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get infractionNoteId => $composableBuilder(
      column: $table.infractionNoteId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  $$LocalAssessmentsTableFilterComposer get localAssessmentId {
    final $$LocalAssessmentsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.localAssessmentId,
        referencedTable: $db.localAssessments,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$LocalAssessmentsTableFilterComposer(
              $db: $db,
              $table: $db.localAssessments,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$LocalAssessmentItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalAssessmentItemsTable> {
  $$LocalAssessmentItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get infractionId => $composableBuilder(
      column: $table.infractionId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get infractionNoteId => $composableBuilder(
      column: $table.infractionNoteId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  $$LocalAssessmentsTableOrderingComposer get localAssessmentId {
    final $$LocalAssessmentsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.localAssessmentId,
        referencedTable: $db.localAssessments,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$LocalAssessmentsTableOrderingComposer(
              $db: $db,
              $table: $db.localAssessments,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$LocalAssessmentItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalAssessmentItemsTable> {
  $$LocalAssessmentItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get infractionId => $composableBuilder(
      column: $table.infractionId, builder: (column) => column);

  GeneratedColumn<String> get infractionNoteId => $composableBuilder(
      column: $table.infractionNoteId, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$LocalAssessmentsTableAnnotationComposer get localAssessmentId {
    final $$LocalAssessmentsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.localAssessmentId,
        referencedTable: $db.localAssessments,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$LocalAssessmentsTableAnnotationComposer(
              $db: $db,
              $table: $db.localAssessments,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$LocalAssessmentItemsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $LocalAssessmentItemsTable,
    LocalAssessmentItem,
    $$LocalAssessmentItemsTableFilterComposer,
    $$LocalAssessmentItemsTableOrderingComposer,
    $$LocalAssessmentItemsTableAnnotationComposer,
    $$LocalAssessmentItemsTableCreateCompanionBuilder,
    $$LocalAssessmentItemsTableUpdateCompanionBuilder,
    (LocalAssessmentItem, $$LocalAssessmentItemsTableReferences),
    LocalAssessmentItem,
    PrefetchHooks Function({bool localAssessmentId})> {
  $$LocalAssessmentItemsTableTableManager(
      _$AppDatabase db, $LocalAssessmentItemsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalAssessmentItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalAssessmentItemsTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalAssessmentItemsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> localAssessmentId = const Value.absent(),
            Value<String> infractionId = const Value.absent(),
            Value<String> infractionNoteId = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalAssessmentItemsCompanion(
            id: id,
            localAssessmentId: localAssessmentId,
            infractionId: infractionId,
            infractionNoteId: infractionNoteId,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String localAssessmentId,
            required String infractionId,
            required String infractionNoteId,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalAssessmentItemsCompanion.insert(
            id: id,
            localAssessmentId: localAssessmentId,
            infractionId: infractionId,
            infractionNoteId: infractionNoteId,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$LocalAssessmentItemsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({localAssessmentId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (localAssessmentId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.localAssessmentId,
                    referencedTable: $$LocalAssessmentItemsTableReferences
                        ._localAssessmentIdTable(db),
                    referencedColumn: $$LocalAssessmentItemsTableReferences
                        ._localAssessmentIdTable(db)
                        .id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$LocalAssessmentItemsTableProcessedTableManager
    = ProcessedTableManager<
        _$AppDatabase,
        $LocalAssessmentItemsTable,
        LocalAssessmentItem,
        $$LocalAssessmentItemsTableFilterComposer,
        $$LocalAssessmentItemsTableOrderingComposer,
        $$LocalAssessmentItemsTableAnnotationComposer,
        $$LocalAssessmentItemsTableCreateCompanionBuilder,
        $$LocalAssessmentItemsTableUpdateCompanionBuilder,
        (LocalAssessmentItem, $$LocalAssessmentItemsTableReferences),
        LocalAssessmentItem,
        PrefetchHooks Function({bool localAssessmentId})>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SessionsTableTableManager get sessions =>
      $$SessionsTableTableManager(_db, _db.sessions);
  $$ParticipantsTableTableManager get participants =>
      $$ParticipantsTableTableManager(_db, _db.participants);
  $$SessionConsultantsTableTableManager get sessionConsultants =>
      $$SessionConsultantsTableTableManager(_db, _db.sessionConsultants);
  $$AssessmentCategoriesTableTableManager get assessmentCategories =>
      $$AssessmentCategoriesTableTableManager(_db, _db.assessmentCategories);
  $$InfractionsTableTableManager get infractions =>
      $$InfractionsTableTableManager(_db, _db.infractions);
  $$InfractionNotesTableTableManager get infractionNotes =>
      $$InfractionNotesTableTableManager(_db, _db.infractionNotes);
  $$LocalAssessmentsTableTableManager get localAssessments =>
      $$LocalAssessmentsTableTableManager(_db, _db.localAssessments);
  $$LocalAssessmentItemsTableTableManager get localAssessmentItems =>
      $$LocalAssessmentItemsTableTableManager(_db, _db.localAssessmentItems);
}
