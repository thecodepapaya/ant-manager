// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_db.dart';

// ignore_for_file: type=lint
class $ProfilesTable extends Profiles with TableInfo<$ProfilesTable, Profile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colourMeta = const VerificationMeta('colour');
  @override
  late final GeneratedColumn<String> colour = GeneratedColumn<String>(
    'colour',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('#E8A54B'),
  );
  static const VerificationMeta _timeZoneMeta = const VerificationMeta(
    'timeZone',
  );
  @override
  late final GeneratedColumn<String> timeZone = GeneratedColumn<String>(
    'time_zone',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _activeMeta = const VerificationMeta('active');
  @override
  late final GeneratedColumn<bool> active = GeneratedColumn<bool>(
    'active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("active" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    colour,
    timeZone,
    active,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<Profile> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('colour')) {
      context.handle(
        _colourMeta,
        colour.isAcceptableOrUnknown(data['colour']!, _colourMeta),
      );
    }
    if (data.containsKey('time_zone')) {
      context.handle(
        _timeZoneMeta,
        timeZone.isAcceptableOrUnknown(data['time_zone']!, _timeZoneMeta),
      );
    } else if (isInserting) {
      context.missing(_timeZoneMeta);
    }
    if (data.containsKey('active')) {
      context.handle(
        _activeMeta,
        active.isAcceptableOrUnknown(data['active']!, _activeMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Profile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Profile(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      colour: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}colour'],
      )!,
      timeZone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}time_zone'],
      )!,
      active: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}active'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ProfilesTable createAlias(String alias) {
    return $ProfilesTable(attachedDatabase, alias);
  }
}

class Profile extends DataClass implements Insertable<Profile> {
  final String id;
  final String name;
  final String colour;
  final String timeZone;
  final bool active;
  final DateTime createdAt;
  const Profile({
    required this.id,
    required this.name,
    required this.colour,
    required this.timeZone,
    required this.active,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['colour'] = Variable<String>(colour);
    map['time_zone'] = Variable<String>(timeZone);
    map['active'] = Variable<bool>(active);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ProfilesCompanion toCompanion(bool nullToAbsent) {
    return ProfilesCompanion(
      id: Value(id),
      name: Value(name),
      colour: Value(colour),
      timeZone: Value(timeZone),
      active: Value(active),
      createdAt: Value(createdAt),
    );
  }

  factory Profile.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Profile(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      colour: serializer.fromJson<String>(json['colour']),
      timeZone: serializer.fromJson<String>(json['timeZone']),
      active: serializer.fromJson<bool>(json['active']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'colour': serializer.toJson<String>(colour),
      'timeZone': serializer.toJson<String>(timeZone),
      'active': serializer.toJson<bool>(active),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Profile copyWith({
    String? id,
    String? name,
    String? colour,
    String? timeZone,
    bool? active,
    DateTime? createdAt,
  }) => Profile(
    id: id ?? this.id,
    name: name ?? this.name,
    colour: colour ?? this.colour,
    timeZone: timeZone ?? this.timeZone,
    active: active ?? this.active,
    createdAt: createdAt ?? this.createdAt,
  );
  Profile copyWithCompanion(ProfilesCompanion data) {
    return Profile(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      colour: data.colour.present ? data.colour.value : this.colour,
      timeZone: data.timeZone.present ? data.timeZone.value : this.timeZone,
      active: data.active.present ? data.active.value : this.active,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Profile(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('colour: $colour, ')
          ..write('timeZone: $timeZone, ')
          ..write('active: $active, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, colour, timeZone, active, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Profile &&
          other.id == this.id &&
          other.name == this.name &&
          other.colour == this.colour &&
          other.timeZone == this.timeZone &&
          other.active == this.active &&
          other.createdAt == this.createdAt);
}

class ProfilesCompanion extends UpdateCompanion<Profile> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> colour;
  final Value<String> timeZone;
  final Value<bool> active;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ProfilesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.colour = const Value.absent(),
    this.timeZone = const Value.absent(),
    this.active = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProfilesCompanion.insert({
    required String id,
    required String name,
    this.colour = const Value.absent(),
    required String timeZone,
    this.active = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       timeZone = Value(timeZone),
       createdAt = Value(createdAt);
  static Insertable<Profile> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? colour,
    Expression<String>? timeZone,
    Expression<bool>? active,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (colour != null) 'colour': colour,
      if (timeZone != null) 'time_zone': timeZone,
      if (active != null) 'active': active,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProfilesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? colour,
    Value<String>? timeZone,
    Value<bool>? active,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return ProfilesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      colour: colour ?? this.colour,
      timeZone: timeZone ?? this.timeZone,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (colour.present) {
      map['colour'] = Variable<String>(colour.value);
    }
    if (timeZone.present) {
      map['time_zone'] = Variable<String>(timeZone.value);
    }
    if (active.present) {
      map['active'] = Variable<bool>(active.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProfilesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('colour: $colour, ')
          ..write('timeZone: $timeZone, ')
          ..write('active: $active, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProvidersTable extends Providers
    with TableInfo<$ProvidersTable, Provider> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProvidersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<ProviderKind, String> kind =
      GeneratedColumn<String>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<ProviderKind>($ProvidersTable.$converterkind);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _baseUrlMeta = const VerificationMeta(
    'baseUrl',
  );
  @override
  late final GeneratedColumn<String> baseUrl = GeneratedColumn<String>(
    'base_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<ProviderProtocol, String>
  protocol = GeneratedColumn<String>(
    'protocol',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<ProviderProtocol>($ProvidersTable.$converterprotocol);
  static const VerificationMeta _credentialRefMeta = const VerificationMeta(
    'credentialRef',
  );
  @override
  late final GeneratedColumn<String> credentialRef = GeneratedColumn<String>(
    'credential_ref',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _headersMeta = const VerificationMeta(
    'headers',
  );
  @override
  late final GeneratedColumn<String> headers = GeneratedColumn<String>(
    'headers',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _customCaPemMeta = const VerificationMeta(
    'customCaPem',
  );
  @override
  late final GeneratedColumn<String> customCaPem = GeneratedColumn<String>(
    'custom_ca_pem',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _allowSelfSignedMeta = const VerificationMeta(
    'allowSelfSigned',
  );
  @override
  late final GeneratedColumn<bool> allowSelfSigned = GeneratedColumn<bool>(
    'allow_self_signed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("allow_self_signed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _timeoutSecondsMeta = const VerificationMeta(
    'timeoutSeconds',
  );
  @override
  late final GeneratedColumn<int> timeoutSeconds = GeneratedColumn<int>(
    'timeout_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(120),
  );
  static const VerificationMeta _consentGivenMeta = const VerificationMeta(
    'consentGiven',
  );
  @override
  late final GeneratedColumn<bool> consentGiven = GeneratedColumn<bool>(
    'consent_given',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("consent_given" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    kind,
    name,
    baseUrl,
    protocol,
    credentialRef,
    headers,
    customCaPem,
    allowSelfSigned,
    timeoutSeconds,
    consentGiven,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'providers';
  @override
  VerificationContext validateIntegrity(
    Insertable<Provider> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('base_url')) {
      context.handle(
        _baseUrlMeta,
        baseUrl.isAcceptableOrUnknown(data['base_url']!, _baseUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_baseUrlMeta);
    }
    if (data.containsKey('credential_ref')) {
      context.handle(
        _credentialRefMeta,
        credentialRef.isAcceptableOrUnknown(
          data['credential_ref']!,
          _credentialRefMeta,
        ),
      );
    }
    if (data.containsKey('headers')) {
      context.handle(
        _headersMeta,
        headers.isAcceptableOrUnknown(data['headers']!, _headersMeta),
      );
    }
    if (data.containsKey('custom_ca_pem')) {
      context.handle(
        _customCaPemMeta,
        customCaPem.isAcceptableOrUnknown(
          data['custom_ca_pem']!,
          _customCaPemMeta,
        ),
      );
    }
    if (data.containsKey('allow_self_signed')) {
      context.handle(
        _allowSelfSignedMeta,
        allowSelfSigned.isAcceptableOrUnknown(
          data['allow_self_signed']!,
          _allowSelfSignedMeta,
        ),
      );
    }
    if (data.containsKey('timeout_seconds')) {
      context.handle(
        _timeoutSecondsMeta,
        timeoutSeconds.isAcceptableOrUnknown(
          data['timeout_seconds']!,
          _timeoutSecondsMeta,
        ),
      );
    }
    if (data.containsKey('consent_given')) {
      context.handle(
        _consentGivenMeta,
        consentGiven.isAcceptableOrUnknown(
          data['consent_given']!,
          _consentGivenMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Provider map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Provider(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      kind: $ProvidersTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}kind'],
        )!,
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      baseUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}base_url'],
      )!,
      protocol: $ProvidersTable.$converterprotocol.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}protocol'],
        )!,
      ),
      credentialRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}credential_ref'],
      ),
      headers: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}headers'],
      )!,
      customCaPem: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}custom_ca_pem'],
      ),
      allowSelfSigned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}allow_self_signed'],
      )!,
      timeoutSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}timeout_seconds'],
      )!,
      consentGiven: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}consent_given'],
      )!,
    );
  }

  @override
  $ProvidersTable createAlias(String alias) {
    return $ProvidersTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ProviderKind, String, String> $converterkind =
      const EnumNameConverter<ProviderKind>(ProviderKind.values);
  static JsonTypeConverter2<ProviderProtocol, String, String>
  $converterprotocol = const EnumNameConverter<ProviderProtocol>(
    ProviderProtocol.values,
  );
}

class Provider extends DataClass implements Insertable<Provider> {
  final String id;
  final ProviderKind kind;
  final String name;
  final String baseUrl;
  final ProviderProtocol protocol;
  final String? credentialRef;
  final String headers;
  final String? customCaPem;
  final bool allowSelfSigned;
  final int timeoutSeconds;
  final bool consentGiven;
  const Provider({
    required this.id,
    required this.kind,
    required this.name,
    required this.baseUrl,
    required this.protocol,
    this.credentialRef,
    required this.headers,
    this.customCaPem,
    required this.allowSelfSigned,
    required this.timeoutSeconds,
    required this.consentGiven,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    {
      map['kind'] = Variable<String>(
        $ProvidersTable.$converterkind.toSql(kind),
      );
    }
    map['name'] = Variable<String>(name);
    map['base_url'] = Variable<String>(baseUrl);
    {
      map['protocol'] = Variable<String>(
        $ProvidersTable.$converterprotocol.toSql(protocol),
      );
    }
    if (!nullToAbsent || credentialRef != null) {
      map['credential_ref'] = Variable<String>(credentialRef);
    }
    map['headers'] = Variable<String>(headers);
    if (!nullToAbsent || customCaPem != null) {
      map['custom_ca_pem'] = Variable<String>(customCaPem);
    }
    map['allow_self_signed'] = Variable<bool>(allowSelfSigned);
    map['timeout_seconds'] = Variable<int>(timeoutSeconds);
    map['consent_given'] = Variable<bool>(consentGiven);
    return map;
  }

  ProvidersCompanion toCompanion(bool nullToAbsent) {
    return ProvidersCompanion(
      id: Value(id),
      kind: Value(kind),
      name: Value(name),
      baseUrl: Value(baseUrl),
      protocol: Value(protocol),
      credentialRef: credentialRef == null && nullToAbsent
          ? const Value.absent()
          : Value(credentialRef),
      headers: Value(headers),
      customCaPem: customCaPem == null && nullToAbsent
          ? const Value.absent()
          : Value(customCaPem),
      allowSelfSigned: Value(allowSelfSigned),
      timeoutSeconds: Value(timeoutSeconds),
      consentGiven: Value(consentGiven),
    );
  }

  factory Provider.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Provider(
      id: serializer.fromJson<String>(json['id']),
      kind: $ProvidersTable.$converterkind.fromJson(
        serializer.fromJson<String>(json['kind']),
      ),
      name: serializer.fromJson<String>(json['name']),
      baseUrl: serializer.fromJson<String>(json['baseUrl']),
      protocol: $ProvidersTable.$converterprotocol.fromJson(
        serializer.fromJson<String>(json['protocol']),
      ),
      credentialRef: serializer.fromJson<String?>(json['credentialRef']),
      headers: serializer.fromJson<String>(json['headers']),
      customCaPem: serializer.fromJson<String?>(json['customCaPem']),
      allowSelfSigned: serializer.fromJson<bool>(json['allowSelfSigned']),
      timeoutSeconds: serializer.fromJson<int>(json['timeoutSeconds']),
      consentGiven: serializer.fromJson<bool>(json['consentGiven']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String>(
        $ProvidersTable.$converterkind.toJson(kind),
      ),
      'name': serializer.toJson<String>(name),
      'baseUrl': serializer.toJson<String>(baseUrl),
      'protocol': serializer.toJson<String>(
        $ProvidersTable.$converterprotocol.toJson(protocol),
      ),
      'credentialRef': serializer.toJson<String?>(credentialRef),
      'headers': serializer.toJson<String>(headers),
      'customCaPem': serializer.toJson<String?>(customCaPem),
      'allowSelfSigned': serializer.toJson<bool>(allowSelfSigned),
      'timeoutSeconds': serializer.toJson<int>(timeoutSeconds),
      'consentGiven': serializer.toJson<bool>(consentGiven),
    };
  }

  Provider copyWith({
    String? id,
    ProviderKind? kind,
    String? name,
    String? baseUrl,
    ProviderProtocol? protocol,
    Value<String?> credentialRef = const Value.absent(),
    String? headers,
    Value<String?> customCaPem = const Value.absent(),
    bool? allowSelfSigned,
    int? timeoutSeconds,
    bool? consentGiven,
  }) => Provider(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    name: name ?? this.name,
    baseUrl: baseUrl ?? this.baseUrl,
    protocol: protocol ?? this.protocol,
    credentialRef: credentialRef.present
        ? credentialRef.value
        : this.credentialRef,
    headers: headers ?? this.headers,
    customCaPem: customCaPem.present ? customCaPem.value : this.customCaPem,
    allowSelfSigned: allowSelfSigned ?? this.allowSelfSigned,
    timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
    consentGiven: consentGiven ?? this.consentGiven,
  );
  Provider copyWithCompanion(ProvidersCompanion data) {
    return Provider(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      name: data.name.present ? data.name.value : this.name,
      baseUrl: data.baseUrl.present ? data.baseUrl.value : this.baseUrl,
      protocol: data.protocol.present ? data.protocol.value : this.protocol,
      credentialRef: data.credentialRef.present
          ? data.credentialRef.value
          : this.credentialRef,
      headers: data.headers.present ? data.headers.value : this.headers,
      customCaPem: data.customCaPem.present
          ? data.customCaPem.value
          : this.customCaPem,
      allowSelfSigned: data.allowSelfSigned.present
          ? data.allowSelfSigned.value
          : this.allowSelfSigned,
      timeoutSeconds: data.timeoutSeconds.present
          ? data.timeoutSeconds.value
          : this.timeoutSeconds,
      consentGiven: data.consentGiven.present
          ? data.consentGiven.value
          : this.consentGiven,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Provider(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('name: $name, ')
          ..write('baseUrl: $baseUrl, ')
          ..write('protocol: $protocol, ')
          ..write('credentialRef: $credentialRef, ')
          ..write('headers: $headers, ')
          ..write('customCaPem: $customCaPem, ')
          ..write('allowSelfSigned: $allowSelfSigned, ')
          ..write('timeoutSeconds: $timeoutSeconds, ')
          ..write('consentGiven: $consentGiven')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    name,
    baseUrl,
    protocol,
    credentialRef,
    headers,
    customCaPem,
    allowSelfSigned,
    timeoutSeconds,
    consentGiven,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Provider &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.name == this.name &&
          other.baseUrl == this.baseUrl &&
          other.protocol == this.protocol &&
          other.credentialRef == this.credentialRef &&
          other.headers == this.headers &&
          other.customCaPem == this.customCaPem &&
          other.allowSelfSigned == this.allowSelfSigned &&
          other.timeoutSeconds == this.timeoutSeconds &&
          other.consentGiven == this.consentGiven);
}

class ProvidersCompanion extends UpdateCompanion<Provider> {
  final Value<String> id;
  final Value<ProviderKind> kind;
  final Value<String> name;
  final Value<String> baseUrl;
  final Value<ProviderProtocol> protocol;
  final Value<String?> credentialRef;
  final Value<String> headers;
  final Value<String?> customCaPem;
  final Value<bool> allowSelfSigned;
  final Value<int> timeoutSeconds;
  final Value<bool> consentGiven;
  final Value<int> rowid;
  const ProvidersCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.name = const Value.absent(),
    this.baseUrl = const Value.absent(),
    this.protocol = const Value.absent(),
    this.credentialRef = const Value.absent(),
    this.headers = const Value.absent(),
    this.customCaPem = const Value.absent(),
    this.allowSelfSigned = const Value.absent(),
    this.timeoutSeconds = const Value.absent(),
    this.consentGiven = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProvidersCompanion.insert({
    required String id,
    required ProviderKind kind,
    required String name,
    required String baseUrl,
    required ProviderProtocol protocol,
    this.credentialRef = const Value.absent(),
    this.headers = const Value.absent(),
    this.customCaPem = const Value.absent(),
    this.allowSelfSigned = const Value.absent(),
    this.timeoutSeconds = const Value.absent(),
    this.consentGiven = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       name = Value(name),
       baseUrl = Value(baseUrl),
       protocol = Value(protocol);
  static Insertable<Provider> custom({
    Expression<String>? id,
    Expression<String>? kind,
    Expression<String>? name,
    Expression<String>? baseUrl,
    Expression<String>? protocol,
    Expression<String>? credentialRef,
    Expression<String>? headers,
    Expression<String>? customCaPem,
    Expression<bool>? allowSelfSigned,
    Expression<int>? timeoutSeconds,
    Expression<bool>? consentGiven,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (name != null) 'name': name,
      if (baseUrl != null) 'base_url': baseUrl,
      if (protocol != null) 'protocol': protocol,
      if (credentialRef != null) 'credential_ref': credentialRef,
      if (headers != null) 'headers': headers,
      if (customCaPem != null) 'custom_ca_pem': customCaPem,
      if (allowSelfSigned != null) 'allow_self_signed': allowSelfSigned,
      if (timeoutSeconds != null) 'timeout_seconds': timeoutSeconds,
      if (consentGiven != null) 'consent_given': consentGiven,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProvidersCompanion copyWith({
    Value<String>? id,
    Value<ProviderKind>? kind,
    Value<String>? name,
    Value<String>? baseUrl,
    Value<ProviderProtocol>? protocol,
    Value<String?>? credentialRef,
    Value<String>? headers,
    Value<String?>? customCaPem,
    Value<bool>? allowSelfSigned,
    Value<int>? timeoutSeconds,
    Value<bool>? consentGiven,
    Value<int>? rowid,
  }) {
    return ProvidersCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      protocol: protocol ?? this.protocol,
      credentialRef: credentialRef ?? this.credentialRef,
      headers: headers ?? this.headers,
      customCaPem: customCaPem ?? this.customCaPem,
      allowSelfSigned: allowSelfSigned ?? this.allowSelfSigned,
      timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
      consentGiven: consentGiven ?? this.consentGiven,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(
        $ProvidersTable.$converterkind.toSql(kind.value),
      );
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (baseUrl.present) {
      map['base_url'] = Variable<String>(baseUrl.value);
    }
    if (protocol.present) {
      map['protocol'] = Variable<String>(
        $ProvidersTable.$converterprotocol.toSql(protocol.value),
      );
    }
    if (credentialRef.present) {
      map['credential_ref'] = Variable<String>(credentialRef.value);
    }
    if (headers.present) {
      map['headers'] = Variable<String>(headers.value);
    }
    if (customCaPem.present) {
      map['custom_ca_pem'] = Variable<String>(customCaPem.value);
    }
    if (allowSelfSigned.present) {
      map['allow_self_signed'] = Variable<bool>(allowSelfSigned.value);
    }
    if (timeoutSeconds.present) {
      map['timeout_seconds'] = Variable<int>(timeoutSeconds.value);
    }
    if (consentGiven.present) {
      map['consent_given'] = Variable<bool>(consentGiven.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProvidersCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('name: $name, ')
          ..write('baseUrl: $baseUrl, ')
          ..write('protocol: $protocol, ')
          ..write('credentialRef: $credentialRef, ')
          ..write('headers: $headers, ')
          ..write('customCaPem: $customCaPem, ')
          ..write('allowSelfSigned: $allowSelfSigned, ')
          ..write('timeoutSeconds: $timeoutSeconds, ')
          ..write('consentGiven: $consentGiven, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ModelsTable extends Models with TableInfo<$ModelsTable, Model> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ModelsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _providerIdMeta = const VerificationMeta(
    'providerId',
  );
  @override
  late final GeneratedColumn<String> providerId = GeneratedColumn<String>(
    'provider_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES providers (id)',
    ),
  );
  static const VerificationMeta _modelNameMeta = const VerificationMeta(
    'modelName',
  );
  @override
  late final GeneratedColumn<String> modelName = GeneratedColumn<String>(
    'model_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _visionMeta = const VerificationMeta('vision');
  @override
  late final GeneratedColumn<bool> vision = GeneratedColumn<bool>(
    'vision',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("vision" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _contextLengthMeta = const VerificationMeta(
    'contextLength',
  );
  @override
  late final GeneratedColumn<int> contextLength = GeneratedColumn<int>(
    'context_length',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(8192),
  );
  static const VerificationMeta _structuredOutputMeta = const VerificationMeta(
    'structuredOutput',
  );
  @override
  late final GeneratedColumn<bool> structuredOutput = GeneratedColumn<bool>(
    'structured_output',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("structured_output" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _inputPricePerMTokMeta = const VerificationMeta(
    'inputPricePerMTok',
  );
  @override
  late final GeneratedColumn<double> inputPricePerMTok =
      GeneratedColumn<double>(
        'input_price_per_m_tok',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _outputPricePerMTokMeta =
      const VerificationMeta('outputPricePerMTok');
  @override
  late final GeneratedColumn<double> outputPricePerMTok =
      GeneratedColumn<double>(
        'output_price_per_m_tok',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    providerId,
    modelName,
    vision,
    contextLength,
    structuredOutput,
    inputPricePerMTok,
    outputPricePerMTok,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'models';
  @override
  VerificationContext validateIntegrity(
    Insertable<Model> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('provider_id')) {
      context.handle(
        _providerIdMeta,
        providerId.isAcceptableOrUnknown(data['provider_id']!, _providerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_providerIdMeta);
    }
    if (data.containsKey('model_name')) {
      context.handle(
        _modelNameMeta,
        modelName.isAcceptableOrUnknown(data['model_name']!, _modelNameMeta),
      );
    } else if (isInserting) {
      context.missing(_modelNameMeta);
    }
    if (data.containsKey('vision')) {
      context.handle(
        _visionMeta,
        vision.isAcceptableOrUnknown(data['vision']!, _visionMeta),
      );
    }
    if (data.containsKey('context_length')) {
      context.handle(
        _contextLengthMeta,
        contextLength.isAcceptableOrUnknown(
          data['context_length']!,
          _contextLengthMeta,
        ),
      );
    }
    if (data.containsKey('structured_output')) {
      context.handle(
        _structuredOutputMeta,
        structuredOutput.isAcceptableOrUnknown(
          data['structured_output']!,
          _structuredOutputMeta,
        ),
      );
    }
    if (data.containsKey('input_price_per_m_tok')) {
      context.handle(
        _inputPricePerMTokMeta,
        inputPricePerMTok.isAcceptableOrUnknown(
          data['input_price_per_m_tok']!,
          _inputPricePerMTokMeta,
        ),
      );
    }
    if (data.containsKey('output_price_per_m_tok')) {
      context.handle(
        _outputPricePerMTokMeta,
        outputPricePerMTok.isAcceptableOrUnknown(
          data['output_price_per_m_tok']!,
          _outputPricePerMTokMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Model map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Model(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      providerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_id'],
      )!,
      modelName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model_name'],
      )!,
      vision: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}vision'],
      )!,
      contextLength: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}context_length'],
      )!,
      structuredOutput: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}structured_output'],
      )!,
      inputPricePerMTok: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}input_price_per_m_tok'],
      ),
      outputPricePerMTok: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}output_price_per_m_tok'],
      ),
    );
  }

  @override
  $ModelsTable createAlias(String alias) {
    return $ModelsTable(attachedDatabase, alias);
  }
}

class Model extends DataClass implements Insertable<Model> {
  final String id;
  final String providerId;
  final String modelName;
  final bool vision;
  final int contextLength;

  /// Verified by probe on add (#70). Models without it are never stored.
  final bool structuredOutput;
  final double? inputPricePerMTok;
  final double? outputPricePerMTok;
  const Model({
    required this.id,
    required this.providerId,
    required this.modelName,
    required this.vision,
    required this.contextLength,
    required this.structuredOutput,
    this.inputPricePerMTok,
    this.outputPricePerMTok,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['provider_id'] = Variable<String>(providerId);
    map['model_name'] = Variable<String>(modelName);
    map['vision'] = Variable<bool>(vision);
    map['context_length'] = Variable<int>(contextLength);
    map['structured_output'] = Variable<bool>(structuredOutput);
    if (!nullToAbsent || inputPricePerMTok != null) {
      map['input_price_per_m_tok'] = Variable<double>(inputPricePerMTok);
    }
    if (!nullToAbsent || outputPricePerMTok != null) {
      map['output_price_per_m_tok'] = Variable<double>(outputPricePerMTok);
    }
    return map;
  }

  ModelsCompanion toCompanion(bool nullToAbsent) {
    return ModelsCompanion(
      id: Value(id),
      providerId: Value(providerId),
      modelName: Value(modelName),
      vision: Value(vision),
      contextLength: Value(contextLength),
      structuredOutput: Value(structuredOutput),
      inputPricePerMTok: inputPricePerMTok == null && nullToAbsent
          ? const Value.absent()
          : Value(inputPricePerMTok),
      outputPricePerMTok: outputPricePerMTok == null && nullToAbsent
          ? const Value.absent()
          : Value(outputPricePerMTok),
    );
  }

  factory Model.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Model(
      id: serializer.fromJson<String>(json['id']),
      providerId: serializer.fromJson<String>(json['providerId']),
      modelName: serializer.fromJson<String>(json['modelName']),
      vision: serializer.fromJson<bool>(json['vision']),
      contextLength: serializer.fromJson<int>(json['contextLength']),
      structuredOutput: serializer.fromJson<bool>(json['structuredOutput']),
      inputPricePerMTok: serializer.fromJson<double?>(
        json['inputPricePerMTok'],
      ),
      outputPricePerMTok: serializer.fromJson<double?>(
        json['outputPricePerMTok'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'providerId': serializer.toJson<String>(providerId),
      'modelName': serializer.toJson<String>(modelName),
      'vision': serializer.toJson<bool>(vision),
      'contextLength': serializer.toJson<int>(contextLength),
      'structuredOutput': serializer.toJson<bool>(structuredOutput),
      'inputPricePerMTok': serializer.toJson<double?>(inputPricePerMTok),
      'outputPricePerMTok': serializer.toJson<double?>(outputPricePerMTok),
    };
  }

  Model copyWith({
    String? id,
    String? providerId,
    String? modelName,
    bool? vision,
    int? contextLength,
    bool? structuredOutput,
    Value<double?> inputPricePerMTok = const Value.absent(),
    Value<double?> outputPricePerMTok = const Value.absent(),
  }) => Model(
    id: id ?? this.id,
    providerId: providerId ?? this.providerId,
    modelName: modelName ?? this.modelName,
    vision: vision ?? this.vision,
    contextLength: contextLength ?? this.contextLength,
    structuredOutput: structuredOutput ?? this.structuredOutput,
    inputPricePerMTok: inputPricePerMTok.present
        ? inputPricePerMTok.value
        : this.inputPricePerMTok,
    outputPricePerMTok: outputPricePerMTok.present
        ? outputPricePerMTok.value
        : this.outputPricePerMTok,
  );
  Model copyWithCompanion(ModelsCompanion data) {
    return Model(
      id: data.id.present ? data.id.value : this.id,
      providerId: data.providerId.present
          ? data.providerId.value
          : this.providerId,
      modelName: data.modelName.present ? data.modelName.value : this.modelName,
      vision: data.vision.present ? data.vision.value : this.vision,
      contextLength: data.contextLength.present
          ? data.contextLength.value
          : this.contextLength,
      structuredOutput: data.structuredOutput.present
          ? data.structuredOutput.value
          : this.structuredOutput,
      inputPricePerMTok: data.inputPricePerMTok.present
          ? data.inputPricePerMTok.value
          : this.inputPricePerMTok,
      outputPricePerMTok: data.outputPricePerMTok.present
          ? data.outputPricePerMTok.value
          : this.outputPricePerMTok,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Model(')
          ..write('id: $id, ')
          ..write('providerId: $providerId, ')
          ..write('modelName: $modelName, ')
          ..write('vision: $vision, ')
          ..write('contextLength: $contextLength, ')
          ..write('structuredOutput: $structuredOutput, ')
          ..write('inputPricePerMTok: $inputPricePerMTok, ')
          ..write('outputPricePerMTok: $outputPricePerMTok')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    providerId,
    modelName,
    vision,
    contextLength,
    structuredOutput,
    inputPricePerMTok,
    outputPricePerMTok,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Model &&
          other.id == this.id &&
          other.providerId == this.providerId &&
          other.modelName == this.modelName &&
          other.vision == this.vision &&
          other.contextLength == this.contextLength &&
          other.structuredOutput == this.structuredOutput &&
          other.inputPricePerMTok == this.inputPricePerMTok &&
          other.outputPricePerMTok == this.outputPricePerMTok);
}

class ModelsCompanion extends UpdateCompanion<Model> {
  final Value<String> id;
  final Value<String> providerId;
  final Value<String> modelName;
  final Value<bool> vision;
  final Value<int> contextLength;
  final Value<bool> structuredOutput;
  final Value<double?> inputPricePerMTok;
  final Value<double?> outputPricePerMTok;
  final Value<int> rowid;
  const ModelsCompanion({
    this.id = const Value.absent(),
    this.providerId = const Value.absent(),
    this.modelName = const Value.absent(),
    this.vision = const Value.absent(),
    this.contextLength = const Value.absent(),
    this.structuredOutput = const Value.absent(),
    this.inputPricePerMTok = const Value.absent(),
    this.outputPricePerMTok = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ModelsCompanion.insert({
    required String id,
    required String providerId,
    required String modelName,
    this.vision = const Value.absent(),
    this.contextLength = const Value.absent(),
    this.structuredOutput = const Value.absent(),
    this.inputPricePerMTok = const Value.absent(),
    this.outputPricePerMTok = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       providerId = Value(providerId),
       modelName = Value(modelName);
  static Insertable<Model> custom({
    Expression<String>? id,
    Expression<String>? providerId,
    Expression<String>? modelName,
    Expression<bool>? vision,
    Expression<int>? contextLength,
    Expression<bool>? structuredOutput,
    Expression<double>? inputPricePerMTok,
    Expression<double>? outputPricePerMTok,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (providerId != null) 'provider_id': providerId,
      if (modelName != null) 'model_name': modelName,
      if (vision != null) 'vision': vision,
      if (contextLength != null) 'context_length': contextLength,
      if (structuredOutput != null) 'structured_output': structuredOutput,
      if (inputPricePerMTok != null) 'input_price_per_m_tok': inputPricePerMTok,
      if (outputPricePerMTok != null)
        'output_price_per_m_tok': outputPricePerMTok,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ModelsCompanion copyWith({
    Value<String>? id,
    Value<String>? providerId,
    Value<String>? modelName,
    Value<bool>? vision,
    Value<int>? contextLength,
    Value<bool>? structuredOutput,
    Value<double?>? inputPricePerMTok,
    Value<double?>? outputPricePerMTok,
    Value<int>? rowid,
  }) {
    return ModelsCompanion(
      id: id ?? this.id,
      providerId: providerId ?? this.providerId,
      modelName: modelName ?? this.modelName,
      vision: vision ?? this.vision,
      contextLength: contextLength ?? this.contextLength,
      structuredOutput: structuredOutput ?? this.structuredOutput,
      inputPricePerMTok: inputPricePerMTok ?? this.inputPricePerMTok,
      outputPricePerMTok: outputPricePerMTok ?? this.outputPricePerMTok,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (providerId.present) {
      map['provider_id'] = Variable<String>(providerId.value);
    }
    if (modelName.present) {
      map['model_name'] = Variable<String>(modelName.value);
    }
    if (vision.present) {
      map['vision'] = Variable<bool>(vision.value);
    }
    if (contextLength.present) {
      map['context_length'] = Variable<int>(contextLength.value);
    }
    if (structuredOutput.present) {
      map['structured_output'] = Variable<bool>(structuredOutput.value);
    }
    if (inputPricePerMTok.present) {
      map['input_price_per_m_tok'] = Variable<double>(inputPricePerMTok.value);
    }
    if (outputPricePerMTok.present) {
      map['output_price_per_m_tok'] = Variable<double>(
        outputPricePerMTok.value,
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ModelsCompanion(')
          ..write('id: $id, ')
          ..write('providerId: $providerId, ')
          ..write('modelName: $modelName, ')
          ..write('vision: $vision, ')
          ..write('contextLength: $contextLength, ')
          ..write('structuredOutput: $structuredOutput, ')
          ..write('inputPricePerMTok: $inputPricePerMTok, ')
          ..write('outputPricePerMTok: $outputPricePerMTok, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDb extends GeneratedDatabase {
  _$AppDb(QueryExecutor e) : super(e);
  $AppDbManager get managers => $AppDbManager(this);
  late final $ProfilesTable profiles = $ProfilesTable(this);
  late final $ProvidersTable providers = $ProvidersTable(this);
  late final $ModelsTable models = $ModelsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    profiles,
    providers,
    models,
  ];
}

typedef $$ProfilesTableCreateCompanionBuilder = ProfilesCompanion Function({
  required String id,
  required String name,
  Value<String> colour,
  required String timeZone,
  Value<bool> active,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$ProfilesTableUpdateCompanionBuilder = ProfilesCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> colour,
  Value<String> timeZone,
  Value<bool> active,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$ProfilesTableFilterComposer extends Composer<_$AppDb, $ProfilesTable> {
  $$ProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get colour => $composableBuilder(
    column: $table.colour,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get timeZone => $composableBuilder(
    column: $table.timeZone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ProfilesTableOrderingComposer
    extends Composer<_$AppDb, $ProfilesTable> {
  $$ProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get colour => $composableBuilder(
    column: $table.colour,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get timeZone => $composableBuilder(
    column: $table.timeZone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProfilesTableAnnotationComposer
    extends Composer<_$AppDb, $ProfilesTable> {
  $$ProfilesTableAnnotationComposer({
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

  GeneratedColumn<String> get colour =>
      $composableBuilder(column: $table.colour, builder: (column) => column);

  GeneratedColumn<String> get timeZone =>
      $composableBuilder(column: $table.timeZone, builder: (column) => column);

  GeneratedColumn<bool> get active =>
      $composableBuilder(column: $table.active, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ProfilesTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $ProfilesTable,
          Profile,
          $$ProfilesTableFilterComposer,
          $$ProfilesTableOrderingComposer,
          $$ProfilesTableAnnotationComposer,
          $$ProfilesTableCreateCompanionBuilder,
          $$ProfilesTableUpdateCompanionBuilder,
          (Profile, BaseReferences<_$AppDb, $ProfilesTable, Profile>),
          Profile,
          PrefetchHooks Function()
        > {
  $$ProfilesTableTableManager(_$AppDb db, $ProfilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> colour = const Value.absent(),
                Value<String> timeZone = const Value.absent(),
                Value<bool> active = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProfilesCompanion(
                id: id,
                name: name,
                colour: colour,
                timeZone: timeZone,
                active: active,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String> colour = const Value.absent(),
                required String timeZone,
                Value<bool> active = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => ProfilesCompanion.insert(
                id: id,
                name: name,
                colour: colour,
                timeZone: timeZone,
                active: active,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ProfilesTable, Profile>(table),
                  BaseReferences<_$AppDb, $ProfilesTable, Profile>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $ProfilesTable,
      Profile,
      $$ProfilesTableFilterComposer,
      $$ProfilesTableOrderingComposer,
      $$ProfilesTableAnnotationComposer,
      $$ProfilesTableCreateCompanionBuilder,
      $$ProfilesTableUpdateCompanionBuilder,
      (Profile, BaseReferences<_$AppDb, $ProfilesTable, Profile>),
      Profile,
      PrefetchHooks Function()
    >;
typedef $$ProvidersTableCreateCompanionBuilder = ProvidersCompanion Function({
  required String id,
  required ProviderKind kind,
  required String name,
  required String baseUrl,
  required ProviderProtocol protocol,
  Value<String?> credentialRef,
  Value<String> headers,
  Value<String?> customCaPem,
  Value<bool> allowSelfSigned,
  Value<int> timeoutSeconds,
  Value<bool> consentGiven,
  Value<int> rowid,
});
typedef $$ProvidersTableUpdateCompanionBuilder = ProvidersCompanion Function({
  Value<String> id,
  Value<ProviderKind> kind,
  Value<String> name,
  Value<String> baseUrl,
  Value<ProviderProtocol> protocol,
  Value<String?> credentialRef,
  Value<String> headers,
  Value<String?> customCaPem,
  Value<bool> allowSelfSigned,
  Value<int> timeoutSeconds,
  Value<bool> consentGiven,
  Value<int> rowid,
});

final class $$ProvidersTableReferences
    extends BaseReferences<_$AppDb, $ProvidersTable, Provider> {
  $$ProvidersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ModelsTable, List<Model>> _modelsRefsTable(
    _$AppDb db,
  ) => MultiTypedResultKey.fromTable(
    db.models,
    aliasName: 'providers__id__models__provider_id',
  );

  $$ModelsTableProcessedTableManager get modelsRefs {
    final manager = $$ModelsTableTableManager(
      $_db,
      $_db.models,
    ).filter((f) => f.providerId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_modelsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ProvidersTableFilterComposer
    extends Composer<_$AppDb, $ProvidersTable> {
  $$ProvidersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ProviderKind, ProviderKind, String> get kind =>
      $composableBuilder(
        column: $table.kind,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get baseUrl => $composableBuilder(
    column: $table.baseUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ProviderProtocol, ProviderProtocol, String>
  get protocol => $composableBuilder(
    column: $table.protocol,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get credentialRef => $composableBuilder(
    column: $table.credentialRef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get headers => $composableBuilder(
    column: $table.headers,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customCaPem => $composableBuilder(
    column: $table.customCaPem,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get allowSelfSigned => $composableBuilder(
    column: $table.allowSelfSigned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get timeoutSeconds => $composableBuilder(
    column: $table.timeoutSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get consentGiven => $composableBuilder(
    column: $table.consentGiven,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> modelsRefs(
    Expression<bool> Function($$ModelsTableFilterComposer f) f,
  ) {
    final $$ModelsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.models,
      getReferencedColumn: (t) => t.providerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ModelsTableFilterComposer(
            $db: $db,
            $table: $db.models,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProvidersTableOrderingComposer
    extends Composer<_$AppDb, $ProvidersTable> {
  $$ProvidersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get baseUrl => $composableBuilder(
    column: $table.baseUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get protocol => $composableBuilder(
    column: $table.protocol,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get credentialRef => $composableBuilder(
    column: $table.credentialRef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get headers => $composableBuilder(
    column: $table.headers,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customCaPem => $composableBuilder(
    column: $table.customCaPem,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get allowSelfSigned => $composableBuilder(
    column: $table.allowSelfSigned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get timeoutSeconds => $composableBuilder(
    column: $table.timeoutSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get consentGiven => $composableBuilder(
    column: $table.consentGiven,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProvidersTableAnnotationComposer
    extends Composer<_$AppDb, $ProvidersTable> {
  $$ProvidersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ProviderKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get baseUrl =>
      $composableBuilder(column: $table.baseUrl, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ProviderProtocol, String> get protocol =>
      $composableBuilder(column: $table.protocol, builder: (column) => column);

  GeneratedColumn<String> get credentialRef => $composableBuilder(
    column: $table.credentialRef,
    builder: (column) => column,
  );

  GeneratedColumn<String> get headers =>
      $composableBuilder(column: $table.headers, builder: (column) => column);

  GeneratedColumn<String> get customCaPem => $composableBuilder(
    column: $table.customCaPem,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get allowSelfSigned => $composableBuilder(
    column: $table.allowSelfSigned,
    builder: (column) => column,
  );

  GeneratedColumn<int> get timeoutSeconds => $composableBuilder(
    column: $table.timeoutSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get consentGiven => $composableBuilder(
    column: $table.consentGiven,
    builder: (column) => column,
  );

  Expression<T> modelsRefs<T extends Object>(
    Expression<T> Function($$ModelsTableAnnotationComposer a) f,
  ) {
    final $$ModelsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.models,
      getReferencedColumn: (t) => t.providerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ModelsTableAnnotationComposer(
            $db: $db,
            $table: $db.models,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProvidersTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $ProvidersTable,
          Provider,
          $$ProvidersTableFilterComposer,
          $$ProvidersTableOrderingComposer,
          $$ProvidersTableAnnotationComposer,
          $$ProvidersTableCreateCompanionBuilder,
          $$ProvidersTableUpdateCompanionBuilder,
          (Provider, $$ProvidersTableReferences),
          Provider,
          PrefetchHooks Function({bool modelsRefs})
        > {
  $$ProvidersTableTableManager(_$AppDb db, $ProvidersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProvidersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProvidersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProvidersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<ProviderKind> kind = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> baseUrl = const Value.absent(),
                Value<ProviderProtocol> protocol = const Value.absent(),
                Value<String?> credentialRef = const Value.absent(),
                Value<String> headers = const Value.absent(),
                Value<String?> customCaPem = const Value.absent(),
                Value<bool> allowSelfSigned = const Value.absent(),
                Value<int> timeoutSeconds = const Value.absent(),
                Value<bool> consentGiven = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProvidersCompanion(
                id: id,
                kind: kind,
                name: name,
                baseUrl: baseUrl,
                protocol: protocol,
                credentialRef: credentialRef,
                headers: headers,
                customCaPem: customCaPem,
                allowSelfSigned: allowSelfSigned,
                timeoutSeconds: timeoutSeconds,
                consentGiven: consentGiven,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required ProviderKind kind,
                required String name,
                required String baseUrl,
                required ProviderProtocol protocol,
                Value<String?> credentialRef = const Value.absent(),
                Value<String> headers = const Value.absent(),
                Value<String?> customCaPem = const Value.absent(),
                Value<bool> allowSelfSigned = const Value.absent(),
                Value<int> timeoutSeconds = const Value.absent(),
                Value<bool> consentGiven = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProvidersCompanion.insert(
                id: id,
                kind: kind,
                name: name,
                baseUrl: baseUrl,
                protocol: protocol,
                credentialRef: credentialRef,
                headers: headers,
                customCaPem: customCaPem,
                allowSelfSigned: allowSelfSigned,
                timeoutSeconds: timeoutSeconds,
                consentGiven: consentGiven,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ProvidersTable, Provider>(table),
                  $$ProvidersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({modelsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (modelsRefs) db.models],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (modelsRefs)
                    await $_getPrefetchedDataByColumns<
                      Provider,
                      $ProvidersTable,
                      Model,
                      $ModelsTable
                    >(
                      currentTable: table,
                      referencedTable: $$ProvidersTableReferences
                          ._modelsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$ProvidersTableReferences(db, table, p0).modelsRefs,
                      currentColumn: 'id',
                      referencedColumn: 'provider_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$ProvidersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $ProvidersTable,
      Provider,
      $$ProvidersTableFilterComposer,
      $$ProvidersTableOrderingComposer,
      $$ProvidersTableAnnotationComposer,
      $$ProvidersTableCreateCompanionBuilder,
      $$ProvidersTableUpdateCompanionBuilder,
      (Provider, $$ProvidersTableReferences),
      Provider,
      PrefetchHooks Function({bool modelsRefs})
    >;
typedef $$ModelsTableCreateCompanionBuilder = ModelsCompanion Function({
  required String id,
  required String providerId,
  required String modelName,
  Value<bool> vision,
  Value<int> contextLength,
  Value<bool> structuredOutput,
  Value<double?> inputPricePerMTok,
  Value<double?> outputPricePerMTok,
  Value<int> rowid,
});
typedef $$ModelsTableUpdateCompanionBuilder = ModelsCompanion Function({
  Value<String> id,
  Value<String> providerId,
  Value<String> modelName,
  Value<bool> vision,
  Value<int> contextLength,
  Value<bool> structuredOutput,
  Value<double?> inputPricePerMTok,
  Value<double?> outputPricePerMTok,
  Value<int> rowid,
});

final class $$ModelsTableReferences
    extends BaseReferences<_$AppDb, $ModelsTable, Model> {
  $$ModelsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProvidersTable _providerIdTable(_$AppDb db) =>
      db.providers.createAlias('models__provider_id__providers__id');

  $$ProvidersTableProcessedTableManager get providerId {
    final $_column = $_itemColumn<String>('provider_id')!;

    final manager = $$ProvidersTableTableManager(
      $_db,
      $_db.providers,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_providerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ModelsTableFilterComposer extends Composer<_$AppDb, $ModelsTable> {
  $$ModelsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get modelName => $composableBuilder(
    column: $table.modelName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get vision => $composableBuilder(
    column: $table.vision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get contextLength => $composableBuilder(
    column: $table.contextLength,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get structuredOutput => $composableBuilder(
    column: $table.structuredOutput,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get inputPricePerMTok => $composableBuilder(
    column: $table.inputPricePerMTok,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get outputPricePerMTok => $composableBuilder(
    column: $table.outputPricePerMTok,
    builder: (column) => ColumnFilters(column),
  );

  $$ProvidersTableFilterComposer get providerId {
    final $$ProvidersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.providerId,
      referencedTable: $db.providers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProvidersTableFilterComposer(
            $db: $db,
            $table: $db.providers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ModelsTableOrderingComposer extends Composer<_$AppDb, $ModelsTable> {
  $$ModelsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get modelName => $composableBuilder(
    column: $table.modelName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get vision => $composableBuilder(
    column: $table.vision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get contextLength => $composableBuilder(
    column: $table.contextLength,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get structuredOutput => $composableBuilder(
    column: $table.structuredOutput,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get inputPricePerMTok => $composableBuilder(
    column: $table.inputPricePerMTok,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get outputPricePerMTok => $composableBuilder(
    column: $table.outputPricePerMTok,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProvidersTableOrderingComposer get providerId {
    final $$ProvidersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.providerId,
      referencedTable: $db.providers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProvidersTableOrderingComposer(
            $db: $db,
            $table: $db.providers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ModelsTableAnnotationComposer extends Composer<_$AppDb, $ModelsTable> {
  $$ModelsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get modelName =>
      $composableBuilder(column: $table.modelName, builder: (column) => column);

  GeneratedColumn<bool> get vision =>
      $composableBuilder(column: $table.vision, builder: (column) => column);

  GeneratedColumn<int> get contextLength => $composableBuilder(
    column: $table.contextLength,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get structuredOutput => $composableBuilder(
    column: $table.structuredOutput,
    builder: (column) => column,
  );

  GeneratedColumn<double> get inputPricePerMTok => $composableBuilder(
    column: $table.inputPricePerMTok,
    builder: (column) => column,
  );

  GeneratedColumn<double> get outputPricePerMTok => $composableBuilder(
    column: $table.outputPricePerMTok,
    builder: (column) => column,
  );

  $$ProvidersTableAnnotationComposer get providerId {
    final $$ProvidersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.providerId,
      referencedTable: $db.providers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProvidersTableAnnotationComposer(
            $db: $db,
            $table: $db.providers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ModelsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $ModelsTable,
          Model,
          $$ModelsTableFilterComposer,
          $$ModelsTableOrderingComposer,
          $$ModelsTableAnnotationComposer,
          $$ModelsTableCreateCompanionBuilder,
          $$ModelsTableUpdateCompanionBuilder,
          (Model, $$ModelsTableReferences),
          Model,
          PrefetchHooks Function({bool providerId})
        > {
  $$ModelsTableTableManager(_$AppDb db, $ModelsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ModelsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ModelsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ModelsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> providerId = const Value.absent(),
                Value<String> modelName = const Value.absent(),
                Value<bool> vision = const Value.absent(),
                Value<int> contextLength = const Value.absent(),
                Value<bool> structuredOutput = const Value.absent(),
                Value<double?> inputPricePerMTok = const Value.absent(),
                Value<double?> outputPricePerMTok = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ModelsCompanion(
                id: id,
                providerId: providerId,
                modelName: modelName,
                vision: vision,
                contextLength: contextLength,
                structuredOutput: structuredOutput,
                inputPricePerMTok: inputPricePerMTok,
                outputPricePerMTok: outputPricePerMTok,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String providerId,
                required String modelName,
                Value<bool> vision = const Value.absent(),
                Value<int> contextLength = const Value.absent(),
                Value<bool> structuredOutput = const Value.absent(),
                Value<double?> inputPricePerMTok = const Value.absent(),
                Value<double?> outputPricePerMTok = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ModelsCompanion.insert(
                id: id,
                providerId: providerId,
                modelName: modelName,
                vision: vision,
                contextLength: contextLength,
                structuredOutput: structuredOutput,
                inputPricePerMTok: inputPricePerMTok,
                outputPricePerMTok: outputPricePerMTok,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ModelsTable, Model>(table),
                  $$ModelsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({providerId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
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
                      dynamic
                    >
                  >(state) {
                    if (providerId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.providerId,
                        referencedTable: $$ModelsTableReferences
                            ._providerIdTable(db),
                        referencedColumn: $$ModelsTableReferences
                            ._providerIdTable(db)
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
        ),
      );
}

typedef $$ModelsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $ModelsTable,
      Model,
      $$ModelsTableFilterComposer,
      $$ModelsTableOrderingComposer,
      $$ModelsTableAnnotationComposer,
      $$ModelsTableCreateCompanionBuilder,
      $$ModelsTableUpdateCompanionBuilder,
      (Model, $$ModelsTableReferences),
      Model,
      PrefetchHooks Function({bool providerId})
    >;

class $AppDbManager {
  final _$AppDb _db;
  $AppDbManager(this._db);
  $$ProfilesTableTableManager get profiles =>
      $$ProfilesTableTableManager(_db, _db.profiles);
  $$ProvidersTableTableManager get providers =>
      $$ProvidersTableTableManager(_db, _db.providers);
  $$ModelsTableTableManager get models =>
      $$ModelsTableTableManager(_db, _db.models);
}
