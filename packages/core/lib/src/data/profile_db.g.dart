// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_db.dart';

// ignore_for_file: type=lint
class $IdentitiesTable extends Identities
    with TableInfo<$IdentitiesTable, Identity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $IdentitiesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
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
  List<GeneratedColumn> get $columns => [id, kind, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'identities';
  @override
  VerificationContext validateIntegrity(
    Insertable<Identity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
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
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Identity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Identity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $IdentitiesTable createAlias(String alias) {
    return $IdentitiesTable(attachedDatabase, alias);
  }
}

class Identity extends DataClass implements Insertable<Identity> {
  final String id;
  final String kind;
  final String value;
  const Identity({required this.id, required this.kind, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['kind'] = Variable<String>(kind);
    map['value'] = Variable<String>(value);
    return map;
  }

  IdentitiesCompanion toCompanion(bool nullToAbsent) {
    return IdentitiesCompanion(
      id: Value(id),
      kind: Value(kind),
      value: Value(value),
    );
  }

  factory Identity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Identity(
      id: serializer.fromJson<String>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String>(kind),
      'value': serializer.toJson<String>(value),
    };
  }

  Identity copyWith({String? id, String? kind, String? value}) => Identity(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    value: value ?? this.value,
  );
  Identity copyWithCompanion(IdentitiesCompanion data) {
    return Identity(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Identity(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, kind, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Identity &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.value == this.value);
}

class IdentitiesCompanion extends UpdateCompanion<Identity> {
  final Value<String> id;
  final Value<String> kind;
  final Value<String> value;
  final Value<int> rowid;
  const IdentitiesCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  IdentitiesCompanion.insert({
    required String id,
    required String kind,
    required String value,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       value = Value(value);
  static Insertable<Identity> custom({
    Expression<String>? id,
    Expression<String>? kind,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  IdentitiesCompanion copyWith({
    Value<String>? id,
    Value<String>? kind,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return IdentitiesCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      value: value ?? this.value,
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
      map['kind'] = Variable<String>(kind.value);
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
    return (StringBuffer('IdentitiesCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SourcesTable extends Sources with TableInfo<$SourcesTable, SourceRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SourcesTable(this.attachedDatabase, [this._alias]);
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
  late final GeneratedColumnWithTypeConverter<SourceKind, String> kind =
      GeneratedColumn<String>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<SourceKind>($SourcesTable.$converterkind);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _configMeta = const VerificationMeta('config');
  @override
  late final GeneratedColumn<String> config = GeneratedColumn<String>(
    'config',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
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
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    kind,
    name,
    config,
    credentialRef,
    enabled,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sources';
  @override
  VerificationContext validateIntegrity(
    Insertable<SourceRow> instance, {
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
    if (data.containsKey('config')) {
      context.handle(
        _configMeta,
        config.isAcceptableOrUnknown(data['config']!, _configMeta),
      );
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
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SourceRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SourceRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      kind: $SourcesTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}kind'],
        )!,
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      config: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}config'],
      )!,
      credentialRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}credential_ref'],
      ),
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
    );
  }

  @override
  $SourcesTable createAlias(String alias) {
    return $SourcesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<SourceKind, String, String> $converterkind =
      const EnumNameConverter<SourceKind>(SourceKind.values);
}

class SourceRow extends DataClass implements Insertable<SourceRow> {
  final String id;
  final SourceKind kind;
  final String name;
  final String config;
  final String? credentialRef;
  final bool enabled;
  const SourceRow({
    required this.id,
    required this.kind,
    required this.name,
    required this.config,
    this.credentialRef,
    required this.enabled,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    {
      map['kind'] = Variable<String>($SourcesTable.$converterkind.toSql(kind));
    }
    map['name'] = Variable<String>(name);
    map['config'] = Variable<String>(config);
    if (!nullToAbsent || credentialRef != null) {
      map['credential_ref'] = Variable<String>(credentialRef);
    }
    map['enabled'] = Variable<bool>(enabled);
    return map;
  }

  SourcesCompanion toCompanion(bool nullToAbsent) {
    return SourcesCompanion(
      id: Value(id),
      kind: Value(kind),
      name: Value(name),
      config: Value(config),
      credentialRef: credentialRef == null && nullToAbsent
          ? const Value.absent()
          : Value(credentialRef),
      enabled: Value(enabled),
    );
  }

  factory SourceRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SourceRow(
      id: serializer.fromJson<String>(json['id']),
      kind: $SourcesTable.$converterkind.fromJson(
        serializer.fromJson<String>(json['kind']),
      ),
      name: serializer.fromJson<String>(json['name']),
      config: serializer.fromJson<String>(json['config']),
      credentialRef: serializer.fromJson<String?>(json['credentialRef']),
      enabled: serializer.fromJson<bool>(json['enabled']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String>(
        $SourcesTable.$converterkind.toJson(kind),
      ),
      'name': serializer.toJson<String>(name),
      'config': serializer.toJson<String>(config),
      'credentialRef': serializer.toJson<String?>(credentialRef),
      'enabled': serializer.toJson<bool>(enabled),
    };
  }

  SourceRow copyWith({
    String? id,
    SourceKind? kind,
    String? name,
    String? config,
    Value<String?> credentialRef = const Value.absent(),
    bool? enabled,
  }) => SourceRow(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    name: name ?? this.name,
    config: config ?? this.config,
    credentialRef: credentialRef.present
        ? credentialRef.value
        : this.credentialRef,
    enabled: enabled ?? this.enabled,
  );
  SourceRow copyWithCompanion(SourcesCompanion data) {
    return SourceRow(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      name: data.name.present ? data.name.value : this.name,
      config: data.config.present ? data.config.value : this.config,
      credentialRef: data.credentialRef.present
          ? data.credentialRef.value
          : this.credentialRef,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SourceRow(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('name: $name, ')
          ..write('config: $config, ')
          ..write('credentialRef: $credentialRef, ')
          ..write('enabled: $enabled')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, kind, name, config, credentialRef, enabled);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SourceRow &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.name == this.name &&
          other.config == this.config &&
          other.credentialRef == this.credentialRef &&
          other.enabled == this.enabled);
}

class SourcesCompanion extends UpdateCompanion<SourceRow> {
  final Value<String> id;
  final Value<SourceKind> kind;
  final Value<String> name;
  final Value<String> config;
  final Value<String?> credentialRef;
  final Value<bool> enabled;
  final Value<int> rowid;
  const SourcesCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.name = const Value.absent(),
    this.config = const Value.absent(),
    this.credentialRef = const Value.absent(),
    this.enabled = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SourcesCompanion.insert({
    required String id,
    required SourceKind kind,
    required String name,
    this.config = const Value.absent(),
    this.credentialRef = const Value.absent(),
    this.enabled = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       name = Value(name);
  static Insertable<SourceRow> custom({
    Expression<String>? id,
    Expression<String>? kind,
    Expression<String>? name,
    Expression<String>? config,
    Expression<String>? credentialRef,
    Expression<bool>? enabled,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (name != null) 'name': name,
      if (config != null) 'config': config,
      if (credentialRef != null) 'credential_ref': credentialRef,
      if (enabled != null) 'enabled': enabled,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SourcesCompanion copyWith({
    Value<String>? id,
    Value<SourceKind>? kind,
    Value<String>? name,
    Value<String>? config,
    Value<String?>? credentialRef,
    Value<bool>? enabled,
    Value<int>? rowid,
  }) {
    return SourcesCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      name: name ?? this.name,
      config: config ?? this.config,
      credentialRef: credentialRef ?? this.credentialRef,
      enabled: enabled ?? this.enabled,
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
        $SourcesTable.$converterkind.toSql(kind.value),
      );
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (config.present) {
      map['config'] = Variable<String>(config.value);
    }
    if (credentialRef.present) {
      map['credential_ref'] = Variable<String>(credentialRef.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SourcesCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('name: $name, ')
          ..write('config: $config, ')
          ..write('credentialRef: $credentialRef, ')
          ..write('enabled: $enabled, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncCursorsTable extends SyncCursors
    with TableInfo<$SyncCursorsTable, SyncCursor> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncCursorsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sources (id)',
    ),
  );
  static const VerificationMeta _scopeMeta = const VerificationMeta('scope');
  @override
  late final GeneratedColumn<String> scope = GeneratedColumn<String>(
    'scope',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _cursorMeta = const VerificationMeta('cursor');
  @override
  late final GeneratedColumn<String> cursor = GeneratedColumn<String>(
    'cursor',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastSuccessAtMeta = const VerificationMeta(
    'lastSuccessAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSuccessAt =
      GeneratedColumn<DateTime>(
        'last_success_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    sourceId,
    scope,
    cursor,
    lastSuccessAt,
    lastError,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_cursors';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncCursor> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('scope')) {
      context.handle(
        _scopeMeta,
        scope.isAcceptableOrUnknown(data['scope']!, _scopeMeta),
      );
    }
    if (data.containsKey('cursor')) {
      context.handle(
        _cursorMeta,
        cursor.isAcceptableOrUnknown(data['cursor']!, _cursorMeta),
      );
    }
    if (data.containsKey('last_success_at')) {
      context.handle(
        _lastSuccessAtMeta,
        lastSuccessAt.isAcceptableOrUnknown(
          data['last_success_at']!,
          _lastSuccessAtMeta,
        ),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sourceId, scope};
  @override
  SyncCursor map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncCursor(
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      scope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope'],
      )!,
      cursor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cursor'],
      ),
      lastSuccessAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_success_at'],
      ),
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
    );
  }

  @override
  $SyncCursorsTable createAlias(String alias) {
    return $SyncCursorsTable(attachedDatabase, alias);
  }
}

class SyncCursor extends DataClass implements Insertable<SyncCursor> {
  final String sourceId;
  final String scope;
  final String? cursor;
  final DateTime? lastSuccessAt;
  final String? lastError;
  const SyncCursor({
    required this.sourceId,
    required this.scope,
    this.cursor,
    this.lastSuccessAt,
    this.lastError,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['source_id'] = Variable<String>(sourceId);
    map['scope'] = Variable<String>(scope);
    if (!nullToAbsent || cursor != null) {
      map['cursor'] = Variable<String>(cursor);
    }
    if (!nullToAbsent || lastSuccessAt != null) {
      map['last_success_at'] = Variable<DateTime>(lastSuccessAt);
    }
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    return map;
  }

  SyncCursorsCompanion toCompanion(bool nullToAbsent) {
    return SyncCursorsCompanion(
      sourceId: Value(sourceId),
      scope: Value(scope),
      cursor: cursor == null && nullToAbsent
          ? const Value.absent()
          : Value(cursor),
      lastSuccessAt: lastSuccessAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSuccessAt),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
    );
  }

  factory SyncCursor.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncCursor(
      sourceId: serializer.fromJson<String>(json['sourceId']),
      scope: serializer.fromJson<String>(json['scope']),
      cursor: serializer.fromJson<String?>(json['cursor']),
      lastSuccessAt: serializer.fromJson<DateTime?>(json['lastSuccessAt']),
      lastError: serializer.fromJson<String?>(json['lastError']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sourceId': serializer.toJson<String>(sourceId),
      'scope': serializer.toJson<String>(scope),
      'cursor': serializer.toJson<String?>(cursor),
      'lastSuccessAt': serializer.toJson<DateTime?>(lastSuccessAt),
      'lastError': serializer.toJson<String?>(lastError),
    };
  }

  SyncCursor copyWith({
    String? sourceId,
    String? scope,
    Value<String?> cursor = const Value.absent(),
    Value<DateTime?> lastSuccessAt = const Value.absent(),
    Value<String?> lastError = const Value.absent(),
  }) => SyncCursor(
    sourceId: sourceId ?? this.sourceId,
    scope: scope ?? this.scope,
    cursor: cursor.present ? cursor.value : this.cursor,
    lastSuccessAt: lastSuccessAt.present
        ? lastSuccessAt.value
        : this.lastSuccessAt,
    lastError: lastError.present ? lastError.value : this.lastError,
  );
  SyncCursor copyWithCompanion(SyncCursorsCompanion data) {
    return SyncCursor(
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      scope: data.scope.present ? data.scope.value : this.scope,
      cursor: data.cursor.present ? data.cursor.value : this.cursor,
      lastSuccessAt: data.lastSuccessAt.present
          ? data.lastSuccessAt.value
          : this.lastSuccessAt,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncCursor(')
          ..write('sourceId: $sourceId, ')
          ..write('scope: $scope, ')
          ..write('cursor: $cursor, ')
          ..write('lastSuccessAt: $lastSuccessAt, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(sourceId, scope, cursor, lastSuccessAt, lastError);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncCursor &&
          other.sourceId == this.sourceId &&
          other.scope == this.scope &&
          other.cursor == this.cursor &&
          other.lastSuccessAt == this.lastSuccessAt &&
          other.lastError == this.lastError);
}

class SyncCursorsCompanion extends UpdateCompanion<SyncCursor> {
  final Value<String> sourceId;
  final Value<String> scope;
  final Value<String?> cursor;
  final Value<DateTime?> lastSuccessAt;
  final Value<String?> lastError;
  final Value<int> rowid;
  const SyncCursorsCompanion({
    this.sourceId = const Value.absent(),
    this.scope = const Value.absent(),
    this.cursor = const Value.absent(),
    this.lastSuccessAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncCursorsCompanion.insert({
    required String sourceId,
    this.scope = const Value.absent(),
    this.cursor = const Value.absent(),
    this.lastSuccessAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : sourceId = Value(sourceId);
  static Insertable<SyncCursor> custom({
    Expression<String>? sourceId,
    Expression<String>? scope,
    Expression<String>? cursor,
    Expression<DateTime>? lastSuccessAt,
    Expression<String>? lastError,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sourceId != null) 'source_id': sourceId,
      if (scope != null) 'scope': scope,
      if (cursor != null) 'cursor': cursor,
      if (lastSuccessAt != null) 'last_success_at': lastSuccessAt,
      if (lastError != null) 'last_error': lastError,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncCursorsCompanion copyWith({
    Value<String>? sourceId,
    Value<String>? scope,
    Value<String?>? cursor,
    Value<DateTime?>? lastSuccessAt,
    Value<String?>? lastError,
    Value<int>? rowid,
  }) {
    return SyncCursorsCompanion(
      sourceId: sourceId ?? this.sourceId,
      scope: scope ?? this.scope,
      cursor: cursor ?? this.cursor,
      lastSuccessAt: lastSuccessAt ?? this.lastSuccessAt,
      lastError: lastError ?? this.lastError,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (scope.present) {
      map['scope'] = Variable<String>(scope.value);
    }
    if (cursor.present) {
      map['cursor'] = Variable<String>(cursor.value);
    }
    if (lastSuccessAt.present) {
      map['last_success_at'] = Variable<DateTime>(lastSuccessAt.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncCursorsCompanion(')
          ..write('sourceId: $sourceId, ')
          ..write('scope: $scope, ')
          ..write('cursor: $cursor, ')
          ..write('lastSuccessAt: $lastSuccessAt, ')
          ..write('lastError: $lastError, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProjectsTable extends Projects with TableInfo<$ProjectsTable, Project> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProjectsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _archivedMeta = const VerificationMeta(
    'archived',
  );
  @override
  late final GeneratedColumn<bool> archived = GeneratedColumn<bool>(
    'archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, colour, archived];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'projects';
  @override
  VerificationContext validateIntegrity(
    Insertable<Project> instance, {
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
    if (data.containsKey('archived')) {
      context.handle(
        _archivedMeta,
        archived.isAcceptableOrUnknown(data['archived']!, _archivedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Project map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Project(
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
      archived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}archived'],
      )!,
    );
  }

  @override
  $ProjectsTable createAlias(String alias) {
    return $ProjectsTable(attachedDatabase, alias);
  }
}

class Project extends DataClass implements Insertable<Project> {
  final String id;
  final String name;
  final String colour;
  final bool archived;
  const Project({
    required this.id,
    required this.name,
    required this.colour,
    required this.archived,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['colour'] = Variable<String>(colour);
    map['archived'] = Variable<bool>(archived);
    return map;
  }

  ProjectsCompanion toCompanion(bool nullToAbsent) {
    return ProjectsCompanion(
      id: Value(id),
      name: Value(name),
      colour: Value(colour),
      archived: Value(archived),
    );
  }

  factory Project.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Project(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      colour: serializer.fromJson<String>(json['colour']),
      archived: serializer.fromJson<bool>(json['archived']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'colour': serializer.toJson<String>(colour),
      'archived': serializer.toJson<bool>(archived),
    };
  }

  Project copyWith({
    String? id,
    String? name,
    String? colour,
    bool? archived,
  }) => Project(
    id: id ?? this.id,
    name: name ?? this.name,
    colour: colour ?? this.colour,
    archived: archived ?? this.archived,
  );
  Project copyWithCompanion(ProjectsCompanion data) {
    return Project(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      colour: data.colour.present ? data.colour.value : this.colour,
      archived: data.archived.present ? data.archived.value : this.archived,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Project(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('colour: $colour, ')
          ..write('archived: $archived')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, colour, archived);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Project &&
          other.id == this.id &&
          other.name == this.name &&
          other.colour == this.colour &&
          other.archived == this.archived);
}

class ProjectsCompanion extends UpdateCompanion<Project> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> colour;
  final Value<bool> archived;
  final Value<int> rowid;
  const ProjectsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.colour = const Value.absent(),
    this.archived = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProjectsCompanion.insert({
    required String id,
    required String name,
    this.colour = const Value.absent(),
    this.archived = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<Project> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? colour,
    Expression<bool>? archived,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (colour != null) 'colour': colour,
      if (archived != null) 'archived': archived,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProjectsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? colour,
    Value<bool>? archived,
    Value<int>? rowid,
  }) {
    return ProjectsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      colour: colour ?? this.colour,
      archived: archived ?? this.archived,
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
    if (archived.present) {
      map['archived'] = Variable<bool>(archived.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProjectsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('colour: $colour, ')
          ..write('archived: $archived, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EvidencesTable extends Evidences
    with TableInfo<$EvidencesTable, Evidence> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EvidencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _occurredStartMeta = const VerificationMeta(
    'occurredStart',
  );
  @override
  late final GeneratedColumn<DateTime> occurredStart =
      GeneratedColumn<DateTime>(
        'occurred_start',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _occurredEndMeta = const VerificationMeta(
    'occurredEnd',
  );
  @override
  late final GeneratedColumn<DateTime> occurredEnd = GeneratedColumn<DateTime>(
    'occurred_end',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dayMeta = const VerificationMeta('day');
  @override
  late final GeneratedColumn<String> day = GeneratedColumn<String>(
    'day',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES projects (id)',
    ),
  );
  static const VerificationMeta _starredMeta = const VerificationMeta(
    'starred',
  );
  @override
  late final GeneratedColumn<bool> starred = GeneratedColumn<bool>(
    'starred',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("starred" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _hiddenMeta = const VerificationMeta('hidden');
  @override
  late final GeneratedColumn<bool> hidden = GeneratedColumn<bool>(
    'hidden',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("hidden" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _importanceMeta = const VerificationMeta(
    'importance',
  );
  @override
  late final GeneratedColumn<double> importance = GeneratedColumn<double>(
    'importance',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.5),
  );
  static const VerificationMeta _importanceReasonMeta = const VerificationMeta(
    'importanceReason',
  );
  @override
  late final GeneratedColumn<String> importanceReason = GeneratedColumn<String>(
    'importance_reason',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<ImportanceSetBy?, String>
  importanceSetBy = GeneratedColumn<String>(
    'importance_set_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  ).withConverter<ImportanceSetBy?>($EvidencesTable.$converterimportanceSetByn);
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
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    occurredStart,
    occurredEnd,
    day,
    title,
    projectId,
    starred,
    hidden,
    importance,
    importanceReason,
    importanceSetBy,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'evidences';
  @override
  VerificationContext validateIntegrity(
    Insertable<Evidence> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('occurred_start')) {
      context.handle(
        _occurredStartMeta,
        occurredStart.isAcceptableOrUnknown(
          data['occurred_start']!,
          _occurredStartMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_occurredStartMeta);
    }
    if (data.containsKey('occurred_end')) {
      context.handle(
        _occurredEndMeta,
        occurredEnd.isAcceptableOrUnknown(
          data['occurred_end']!,
          _occurredEndMeta,
        ),
      );
    }
    if (data.containsKey('day')) {
      context.handle(
        _dayMeta,
        day.isAcceptableOrUnknown(data['day']!, _dayMeta),
      );
    } else if (isInserting) {
      context.missing(_dayMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    }
    if (data.containsKey('starred')) {
      context.handle(
        _starredMeta,
        starred.isAcceptableOrUnknown(data['starred']!, _starredMeta),
      );
    }
    if (data.containsKey('hidden')) {
      context.handle(
        _hiddenMeta,
        hidden.isAcceptableOrUnknown(data['hidden']!, _hiddenMeta),
      );
    }
    if (data.containsKey('importance')) {
      context.handle(
        _importanceMeta,
        importance.isAcceptableOrUnknown(data['importance']!, _importanceMeta),
      );
    }
    if (data.containsKey('importance_reason')) {
      context.handle(
        _importanceReasonMeta,
        importanceReason.isAcceptableOrUnknown(
          data['importance_reason']!,
          _importanceReasonMeta,
        ),
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
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Evidence map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Evidence(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      occurredStart: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}occurred_start'],
      )!,
      occurredEnd: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}occurred_end'],
      ),
      day: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}day'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      ),
      starred: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}starred'],
      )!,
      hidden: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}hidden'],
      )!,
      importance: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}importance'],
      )!,
      importanceReason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}importance_reason'],
      ),
      importanceSetBy: $EvidencesTable.$converterimportanceSetByn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}importance_set_by'],
        ),
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $EvidencesTable createAlias(String alias) {
    return $EvidencesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ImportanceSetBy, String, String>
  $converterimportanceSetBy = const EnumNameConverter<ImportanceSetBy>(
    ImportanceSetBy.values,
  );
  static JsonTypeConverter2<ImportanceSetBy?, String?, String?>
  $converterimportanceSetByn = JsonTypeConverter2.asNullable(
    $converterimportanceSetBy,
  );
}

class Evidence extends DataClass implements Insertable<Evidence> {
  final String id;
  final DateTime occurredStart;
  final DateTime? occurredEnd;

  /// Local date (YYYY-MM-DD) in the profile time zone, set at ingest (#87).
  final String day;
  final String title;
  final String? projectId;
  final bool starred;
  final bool hidden;
  final double importance;
  final String? importanceReason;
  final ImportanceSetBy? importanceSetBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Evidence({
    required this.id,
    required this.occurredStart,
    this.occurredEnd,
    required this.day,
    required this.title,
    this.projectId,
    required this.starred,
    required this.hidden,
    required this.importance,
    this.importanceReason,
    this.importanceSetBy,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['occurred_start'] = Variable<DateTime>(occurredStart);
    if (!nullToAbsent || occurredEnd != null) {
      map['occurred_end'] = Variable<DateTime>(occurredEnd);
    }
    map['day'] = Variable<String>(day);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || projectId != null) {
      map['project_id'] = Variable<String>(projectId);
    }
    map['starred'] = Variable<bool>(starred);
    map['hidden'] = Variable<bool>(hidden);
    map['importance'] = Variable<double>(importance);
    if (!nullToAbsent || importanceReason != null) {
      map['importance_reason'] = Variable<String>(importanceReason);
    }
    if (!nullToAbsent || importanceSetBy != null) {
      map['importance_set_by'] = Variable<String>(
        $EvidencesTable.$converterimportanceSetByn.toSql(importanceSetBy),
      );
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  EvidencesCompanion toCompanion(bool nullToAbsent) {
    return EvidencesCompanion(
      id: Value(id),
      occurredStart: Value(occurredStart),
      occurredEnd: occurredEnd == null && nullToAbsent
          ? const Value.absent()
          : Value(occurredEnd),
      day: Value(day),
      title: Value(title),
      projectId: projectId == null && nullToAbsent
          ? const Value.absent()
          : Value(projectId),
      starred: Value(starred),
      hidden: Value(hidden),
      importance: Value(importance),
      importanceReason: importanceReason == null && nullToAbsent
          ? const Value.absent()
          : Value(importanceReason),
      importanceSetBy: importanceSetBy == null && nullToAbsent
          ? const Value.absent()
          : Value(importanceSetBy),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Evidence.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Evidence(
      id: serializer.fromJson<String>(json['id']),
      occurredStart: serializer.fromJson<DateTime>(json['occurredStart']),
      occurredEnd: serializer.fromJson<DateTime?>(json['occurredEnd']),
      day: serializer.fromJson<String>(json['day']),
      title: serializer.fromJson<String>(json['title']),
      projectId: serializer.fromJson<String?>(json['projectId']),
      starred: serializer.fromJson<bool>(json['starred']),
      hidden: serializer.fromJson<bool>(json['hidden']),
      importance: serializer.fromJson<double>(json['importance']),
      importanceReason: serializer.fromJson<String?>(json['importanceReason']),
      importanceSetBy: $EvidencesTable.$converterimportanceSetByn.fromJson(
        serializer.fromJson<String?>(json['importanceSetBy']),
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'occurredStart': serializer.toJson<DateTime>(occurredStart),
      'occurredEnd': serializer.toJson<DateTime?>(occurredEnd),
      'day': serializer.toJson<String>(day),
      'title': serializer.toJson<String>(title),
      'projectId': serializer.toJson<String?>(projectId),
      'starred': serializer.toJson<bool>(starred),
      'hidden': serializer.toJson<bool>(hidden),
      'importance': serializer.toJson<double>(importance),
      'importanceReason': serializer.toJson<String?>(importanceReason),
      'importanceSetBy': serializer.toJson<String?>(
        $EvidencesTable.$converterimportanceSetByn.toJson(importanceSetBy),
      ),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Evidence copyWith({
    String? id,
    DateTime? occurredStart,
    Value<DateTime?> occurredEnd = const Value.absent(),
    String? day,
    String? title,
    Value<String?> projectId = const Value.absent(),
    bool? starred,
    bool? hidden,
    double? importance,
    Value<String?> importanceReason = const Value.absent(),
    Value<ImportanceSetBy?> importanceSetBy = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Evidence(
    id: id ?? this.id,
    occurredStart: occurredStart ?? this.occurredStart,
    occurredEnd: occurredEnd.present ? occurredEnd.value : this.occurredEnd,
    day: day ?? this.day,
    title: title ?? this.title,
    projectId: projectId.present ? projectId.value : this.projectId,
    starred: starred ?? this.starred,
    hidden: hidden ?? this.hidden,
    importance: importance ?? this.importance,
    importanceReason: importanceReason.present
        ? importanceReason.value
        : this.importanceReason,
    importanceSetBy: importanceSetBy.present
        ? importanceSetBy.value
        : this.importanceSetBy,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Evidence copyWithCompanion(EvidencesCompanion data) {
    return Evidence(
      id: data.id.present ? data.id.value : this.id,
      occurredStart: data.occurredStart.present
          ? data.occurredStart.value
          : this.occurredStart,
      occurredEnd: data.occurredEnd.present
          ? data.occurredEnd.value
          : this.occurredEnd,
      day: data.day.present ? data.day.value : this.day,
      title: data.title.present ? data.title.value : this.title,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      starred: data.starred.present ? data.starred.value : this.starred,
      hidden: data.hidden.present ? data.hidden.value : this.hidden,
      importance: data.importance.present
          ? data.importance.value
          : this.importance,
      importanceReason: data.importanceReason.present
          ? data.importanceReason.value
          : this.importanceReason,
      importanceSetBy: data.importanceSetBy.present
          ? data.importanceSetBy.value
          : this.importanceSetBy,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Evidence(')
          ..write('id: $id, ')
          ..write('occurredStart: $occurredStart, ')
          ..write('occurredEnd: $occurredEnd, ')
          ..write('day: $day, ')
          ..write('title: $title, ')
          ..write('projectId: $projectId, ')
          ..write('starred: $starred, ')
          ..write('hidden: $hidden, ')
          ..write('importance: $importance, ')
          ..write('importanceReason: $importanceReason, ')
          ..write('importanceSetBy: $importanceSetBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    occurredStart,
    occurredEnd,
    day,
    title,
    projectId,
    starred,
    hidden,
    importance,
    importanceReason,
    importanceSetBy,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Evidence &&
          other.id == this.id &&
          other.occurredStart == this.occurredStart &&
          other.occurredEnd == this.occurredEnd &&
          other.day == this.day &&
          other.title == this.title &&
          other.projectId == this.projectId &&
          other.starred == this.starred &&
          other.hidden == this.hidden &&
          other.importance == this.importance &&
          other.importanceReason == this.importanceReason &&
          other.importanceSetBy == this.importanceSetBy &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class EvidencesCompanion extends UpdateCompanion<Evidence> {
  final Value<String> id;
  final Value<DateTime> occurredStart;
  final Value<DateTime?> occurredEnd;
  final Value<String> day;
  final Value<String> title;
  final Value<String?> projectId;
  final Value<bool> starred;
  final Value<bool> hidden;
  final Value<double> importance;
  final Value<String?> importanceReason;
  final Value<ImportanceSetBy?> importanceSetBy;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const EvidencesCompanion({
    this.id = const Value.absent(),
    this.occurredStart = const Value.absent(),
    this.occurredEnd = const Value.absent(),
    this.day = const Value.absent(),
    this.title = const Value.absent(),
    this.projectId = const Value.absent(),
    this.starred = const Value.absent(),
    this.hidden = const Value.absent(),
    this.importance = const Value.absent(),
    this.importanceReason = const Value.absent(),
    this.importanceSetBy = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EvidencesCompanion.insert({
    required String id,
    required DateTime occurredStart,
    this.occurredEnd = const Value.absent(),
    required String day,
    required String title,
    this.projectId = const Value.absent(),
    this.starred = const Value.absent(),
    this.hidden = const Value.absent(),
    this.importance = const Value.absent(),
    this.importanceReason = const Value.absent(),
    this.importanceSetBy = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       occurredStart = Value(occurredStart),
       day = Value(day),
       title = Value(title),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Evidence> custom({
    Expression<String>? id,
    Expression<DateTime>? occurredStart,
    Expression<DateTime>? occurredEnd,
    Expression<String>? day,
    Expression<String>? title,
    Expression<String>? projectId,
    Expression<bool>? starred,
    Expression<bool>? hidden,
    Expression<double>? importance,
    Expression<String>? importanceReason,
    Expression<String>? importanceSetBy,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (occurredStart != null) 'occurred_start': occurredStart,
      if (occurredEnd != null) 'occurred_end': occurredEnd,
      if (day != null) 'day': day,
      if (title != null) 'title': title,
      if (projectId != null) 'project_id': projectId,
      if (starred != null) 'starred': starred,
      if (hidden != null) 'hidden': hidden,
      if (importance != null) 'importance': importance,
      if (importanceReason != null) 'importance_reason': importanceReason,
      if (importanceSetBy != null) 'importance_set_by': importanceSetBy,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EvidencesCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? occurredStart,
    Value<DateTime?>? occurredEnd,
    Value<String>? day,
    Value<String>? title,
    Value<String?>? projectId,
    Value<bool>? starred,
    Value<bool>? hidden,
    Value<double>? importance,
    Value<String?>? importanceReason,
    Value<ImportanceSetBy?>? importanceSetBy,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return EvidencesCompanion(
      id: id ?? this.id,
      occurredStart: occurredStart ?? this.occurredStart,
      occurredEnd: occurredEnd ?? this.occurredEnd,
      day: day ?? this.day,
      title: title ?? this.title,
      projectId: projectId ?? this.projectId,
      starred: starred ?? this.starred,
      hidden: hidden ?? this.hidden,
      importance: importance ?? this.importance,
      importanceReason: importanceReason ?? this.importanceReason,
      importanceSetBy: importanceSetBy ?? this.importanceSetBy,
      createdAt: createdAt ?? this.createdAt,
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
    if (occurredStart.present) {
      map['occurred_start'] = Variable<DateTime>(occurredStart.value);
    }
    if (occurredEnd.present) {
      map['occurred_end'] = Variable<DateTime>(occurredEnd.value);
    }
    if (day.present) {
      map['day'] = Variable<String>(day.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (starred.present) {
      map['starred'] = Variable<bool>(starred.value);
    }
    if (hidden.present) {
      map['hidden'] = Variable<bool>(hidden.value);
    }
    if (importance.present) {
      map['importance'] = Variable<double>(importance.value);
    }
    if (importanceReason.present) {
      map['importance_reason'] = Variable<String>(importanceReason.value);
    }
    if (importanceSetBy.present) {
      map['importance_set_by'] = Variable<String>(
        $EvidencesTable.$converterimportanceSetByn.toSql(importanceSetBy.value),
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
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
    return (StringBuffer('EvidencesCompanion(')
          ..write('id: $id, ')
          ..write('occurredStart: $occurredStart, ')
          ..write('occurredEnd: $occurredEnd, ')
          ..write('day: $day, ')
          ..write('title: $title, ')
          ..write('projectId: $projectId, ')
          ..write('starred: $starred, ')
          ..write('hidden: $hidden, ')
          ..write('importance: $importance, ')
          ..write('importanceReason: $importanceReason, ')
          ..write('importanceSetBy: $importanceSetBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PayloadsTable extends Payloads with TableInfo<$PayloadsTable, Payload> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PayloadsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _evidenceIdMeta = const VerificationMeta(
    'evidenceId',
  );
  @override
  late final GeneratedColumn<String> evidenceId = GeneratedColumn<String>(
    'evidence_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES evidences (id)',
    ),
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sources (id)',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<PayloadKind, String> kind =
      GeneratedColumn<String>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<PayloadKind>($PayloadsTable.$converterkind);
  static const VerificationMeta _externalIdMeta = const VerificationMeta(
    'externalId',
  );
  @override
  late final GeneratedColumn<String> externalId = GeneratedColumn<String>(
    'external_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _contentHashMeta = const VerificationMeta(
    'contentHash',
  );
  @override
  late final GeneratedColumn<String> contentHash = GeneratedColumn<String>(
    'content_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _groupKeyMeta = const VerificationMeta(
    'groupKey',
  );
  @override
  late final GeneratedColumn<String> groupKey = GeneratedColumn<String>(
    'group_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _tombstonedAtMeta = const VerificationMeta(
    'tombstonedAt',
  );
  @override
  late final GeneratedColumn<DateTime> tombstonedAt = GeneratedColumn<DateTime>(
    'tombstoned_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    evidenceId,
    sourceId,
    kind,
    externalId,
    title,
    content,
    contentHash,
    groupKey,
    revision,
    tombstonedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'payloads';
  @override
  VerificationContext validateIntegrity(
    Insertable<Payload> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('evidence_id')) {
      context.handle(
        _evidenceIdMeta,
        evidenceId.isAcceptableOrUnknown(data['evidence_id']!, _evidenceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_evidenceIdMeta);
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('external_id')) {
      context.handle(
        _externalIdMeta,
        externalId.isAcceptableOrUnknown(data['external_id']!, _externalIdMeta),
      );
    } else if (isInserting) {
      context.missing(_externalIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('content_hash')) {
      context.handle(
        _contentHashMeta,
        contentHash.isAcceptableOrUnknown(
          data['content_hash']!,
          _contentHashMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contentHashMeta);
    }
    if (data.containsKey('group_key')) {
      context.handle(
        _groupKeyMeta,
        groupKey.isAcceptableOrUnknown(data['group_key']!, _groupKeyMeta),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    if (data.containsKey('tombstoned_at')) {
      context.handle(
        _tombstonedAtMeta,
        tombstonedAt.isAcceptableOrUnknown(
          data['tombstoned_at']!,
          _tombstonedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {sourceId, externalId},
  ];
  @override
  Payload map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Payload(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      evidenceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}evidence_id'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      kind: $PayloadsTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}kind'],
        )!,
      ),
      externalId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}external_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      contentHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_hash'],
      )!,
      groupKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_key'],
      ),
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      tombstonedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}tombstoned_at'],
      ),
    );
  }

  @override
  $PayloadsTable createAlias(String alias) {
    return $PayloadsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<PayloadKind, String, String> $converterkind =
      const EnumNameConverter<PayloadKind>(PayloadKind.values);
}

class Payload extends DataClass implements Insertable<Payload> {
  final String id;
  final String evidenceId;
  final String sourceId;
  final PayloadKind kind;
  final String externalId;
  final String? title;
  final String content;
  final String contentHash;

  /// Exact-identity grouping key (iCal UID, commit SHA). Null = never auto-grouped.
  final String? groupKey;
  final int revision;
  final DateTime? tombstonedAt;
  const Payload({
    required this.id,
    required this.evidenceId,
    required this.sourceId,
    required this.kind,
    required this.externalId,
    this.title,
    required this.content,
    required this.contentHash,
    this.groupKey,
    required this.revision,
    this.tombstonedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['evidence_id'] = Variable<String>(evidenceId);
    map['source_id'] = Variable<String>(sourceId);
    {
      map['kind'] = Variable<String>($PayloadsTable.$converterkind.toSql(kind));
    }
    map['external_id'] = Variable<String>(externalId);
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    map['content'] = Variable<String>(content);
    map['content_hash'] = Variable<String>(contentHash);
    if (!nullToAbsent || groupKey != null) {
      map['group_key'] = Variable<String>(groupKey);
    }
    map['revision'] = Variable<int>(revision);
    if (!nullToAbsent || tombstonedAt != null) {
      map['tombstoned_at'] = Variable<DateTime>(tombstonedAt);
    }
    return map;
  }

  PayloadsCompanion toCompanion(bool nullToAbsent) {
    return PayloadsCompanion(
      id: Value(id),
      evidenceId: Value(evidenceId),
      sourceId: Value(sourceId),
      kind: Value(kind),
      externalId: Value(externalId),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      content: Value(content),
      contentHash: Value(contentHash),
      groupKey: groupKey == null && nullToAbsent
          ? const Value.absent()
          : Value(groupKey),
      revision: Value(revision),
      tombstonedAt: tombstonedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(tombstonedAt),
    );
  }

  factory Payload.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Payload(
      id: serializer.fromJson<String>(json['id']),
      evidenceId: serializer.fromJson<String>(json['evidenceId']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      kind: $PayloadsTable.$converterkind.fromJson(
        serializer.fromJson<String>(json['kind']),
      ),
      externalId: serializer.fromJson<String>(json['externalId']),
      title: serializer.fromJson<String?>(json['title']),
      content: serializer.fromJson<String>(json['content']),
      contentHash: serializer.fromJson<String>(json['contentHash']),
      groupKey: serializer.fromJson<String?>(json['groupKey']),
      revision: serializer.fromJson<int>(json['revision']),
      tombstonedAt: serializer.fromJson<DateTime?>(json['tombstonedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'evidenceId': serializer.toJson<String>(evidenceId),
      'sourceId': serializer.toJson<String>(sourceId),
      'kind': serializer.toJson<String>(
        $PayloadsTable.$converterkind.toJson(kind),
      ),
      'externalId': serializer.toJson<String>(externalId),
      'title': serializer.toJson<String?>(title),
      'content': serializer.toJson<String>(content),
      'contentHash': serializer.toJson<String>(contentHash),
      'groupKey': serializer.toJson<String?>(groupKey),
      'revision': serializer.toJson<int>(revision),
      'tombstonedAt': serializer.toJson<DateTime?>(tombstonedAt),
    };
  }

  Payload copyWith({
    String? id,
    String? evidenceId,
    String? sourceId,
    PayloadKind? kind,
    String? externalId,
    Value<String?> title = const Value.absent(),
    String? content,
    String? contentHash,
    Value<String?> groupKey = const Value.absent(),
    int? revision,
    Value<DateTime?> tombstonedAt = const Value.absent(),
  }) => Payload(
    id: id ?? this.id,
    evidenceId: evidenceId ?? this.evidenceId,
    sourceId: sourceId ?? this.sourceId,
    kind: kind ?? this.kind,
    externalId: externalId ?? this.externalId,
    title: title.present ? title.value : this.title,
    content: content ?? this.content,
    contentHash: contentHash ?? this.contentHash,
    groupKey: groupKey.present ? groupKey.value : this.groupKey,
    revision: revision ?? this.revision,
    tombstonedAt: tombstonedAt.present ? tombstonedAt.value : this.tombstonedAt,
  );
  Payload copyWithCompanion(PayloadsCompanion data) {
    return Payload(
      id: data.id.present ? data.id.value : this.id,
      evidenceId: data.evidenceId.present
          ? data.evidenceId.value
          : this.evidenceId,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      kind: data.kind.present ? data.kind.value : this.kind,
      externalId: data.externalId.present
          ? data.externalId.value
          : this.externalId,
      title: data.title.present ? data.title.value : this.title,
      content: data.content.present ? data.content.value : this.content,
      contentHash: data.contentHash.present
          ? data.contentHash.value
          : this.contentHash,
      groupKey: data.groupKey.present ? data.groupKey.value : this.groupKey,
      revision: data.revision.present ? data.revision.value : this.revision,
      tombstonedAt: data.tombstonedAt.present
          ? data.tombstonedAt.value
          : this.tombstonedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Payload(')
          ..write('id: $id, ')
          ..write('evidenceId: $evidenceId, ')
          ..write('sourceId: $sourceId, ')
          ..write('kind: $kind, ')
          ..write('externalId: $externalId, ')
          ..write('title: $title, ')
          ..write('content: $content, ')
          ..write('contentHash: $contentHash, ')
          ..write('groupKey: $groupKey, ')
          ..write('revision: $revision, ')
          ..write('tombstonedAt: $tombstonedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    evidenceId,
    sourceId,
    kind,
    externalId,
    title,
    content,
    contentHash,
    groupKey,
    revision,
    tombstonedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Payload &&
          other.id == this.id &&
          other.evidenceId == this.evidenceId &&
          other.sourceId == this.sourceId &&
          other.kind == this.kind &&
          other.externalId == this.externalId &&
          other.title == this.title &&
          other.content == this.content &&
          other.contentHash == this.contentHash &&
          other.groupKey == this.groupKey &&
          other.revision == this.revision &&
          other.tombstonedAt == this.tombstonedAt);
}

class PayloadsCompanion extends UpdateCompanion<Payload> {
  final Value<String> id;
  final Value<String> evidenceId;
  final Value<String> sourceId;
  final Value<PayloadKind> kind;
  final Value<String> externalId;
  final Value<String?> title;
  final Value<String> content;
  final Value<String> contentHash;
  final Value<String?> groupKey;
  final Value<int> revision;
  final Value<DateTime?> tombstonedAt;
  final Value<int> rowid;
  const PayloadsCompanion({
    this.id = const Value.absent(),
    this.evidenceId = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.kind = const Value.absent(),
    this.externalId = const Value.absent(),
    this.title = const Value.absent(),
    this.content = const Value.absent(),
    this.contentHash = const Value.absent(),
    this.groupKey = const Value.absent(),
    this.revision = const Value.absent(),
    this.tombstonedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PayloadsCompanion.insert({
    required String id,
    required String evidenceId,
    required String sourceId,
    required PayloadKind kind,
    required String externalId,
    this.title = const Value.absent(),
    required String content,
    required String contentHash,
    this.groupKey = const Value.absent(),
    this.revision = const Value.absent(),
    this.tombstonedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       evidenceId = Value(evidenceId),
       sourceId = Value(sourceId),
       kind = Value(kind),
       externalId = Value(externalId),
       content = Value(content),
       contentHash = Value(contentHash);
  static Insertable<Payload> custom({
    Expression<String>? id,
    Expression<String>? evidenceId,
    Expression<String>? sourceId,
    Expression<String>? kind,
    Expression<String>? externalId,
    Expression<String>? title,
    Expression<String>? content,
    Expression<String>? contentHash,
    Expression<String>? groupKey,
    Expression<int>? revision,
    Expression<DateTime>? tombstonedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (evidenceId != null) 'evidence_id': evidenceId,
      if (sourceId != null) 'source_id': sourceId,
      if (kind != null) 'kind': kind,
      if (externalId != null) 'external_id': externalId,
      if (title != null) 'title': title,
      if (content != null) 'content': content,
      if (contentHash != null) 'content_hash': contentHash,
      if (groupKey != null) 'group_key': groupKey,
      if (revision != null) 'revision': revision,
      if (tombstonedAt != null) 'tombstoned_at': tombstonedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PayloadsCompanion copyWith({
    Value<String>? id,
    Value<String>? evidenceId,
    Value<String>? sourceId,
    Value<PayloadKind>? kind,
    Value<String>? externalId,
    Value<String?>? title,
    Value<String>? content,
    Value<String>? contentHash,
    Value<String?>? groupKey,
    Value<int>? revision,
    Value<DateTime?>? tombstonedAt,
    Value<int>? rowid,
  }) {
    return PayloadsCompanion(
      id: id ?? this.id,
      evidenceId: evidenceId ?? this.evidenceId,
      sourceId: sourceId ?? this.sourceId,
      kind: kind ?? this.kind,
      externalId: externalId ?? this.externalId,
      title: title ?? this.title,
      content: content ?? this.content,
      contentHash: contentHash ?? this.contentHash,
      groupKey: groupKey ?? this.groupKey,
      revision: revision ?? this.revision,
      tombstonedAt: tombstonedAt ?? this.tombstonedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (evidenceId.present) {
      map['evidence_id'] = Variable<String>(evidenceId.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(
        $PayloadsTable.$converterkind.toSql(kind.value),
      );
    }
    if (externalId.present) {
      map['external_id'] = Variable<String>(externalId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (contentHash.present) {
      map['content_hash'] = Variable<String>(contentHash.value);
    }
    if (groupKey.present) {
      map['group_key'] = Variable<String>(groupKey.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (tombstonedAt.present) {
      map['tombstoned_at'] = Variable<DateTime>(tombstonedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PayloadsCompanion(')
          ..write('id: $id, ')
          ..write('evidenceId: $evidenceId, ')
          ..write('sourceId: $sourceId, ')
          ..write('kind: $kind, ')
          ..write('externalId: $externalId, ')
          ..write('title: $title, ')
          ..write('content: $content, ')
          ..write('contentHash: $contentHash, ')
          ..write('groupKey: $groupKey, ')
          ..write('revision: $revision, ')
          ..write('tombstonedAt: $tombstonedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PayloadRevisionsTable extends PayloadRevisions
    with TableInfo<$PayloadRevisionsTable, PayloadRevision> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PayloadRevisionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _payloadIdMeta = const VerificationMeta(
    'payloadId',
  );
  @override
  late final GeneratedColumn<String> payloadId = GeneratedColumn<String>(
    'payload_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES payloads (id)',
    ),
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
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
  static const VerificationMeta _contentHashMeta = const VerificationMeta(
    'contentHash',
  );
  @override
  late final GeneratedColumn<String> contentHash = GeneratedColumn<String>(
    'content_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<RevisionCause, String> cause =
      GeneratedColumn<String>(
        'cause',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<RevisionCause>($PayloadRevisionsTable.$convertercause);
  static const VerificationMeta _observedAtMeta = const VerificationMeta(
    'observedAt',
  );
  @override
  late final GeneratedColumn<DateTime> observedAt = GeneratedColumn<DateTime>(
    'observed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    payloadId,
    revision,
    content,
    contentHash,
    cause,
    observedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'payload_revisions';
  @override
  VerificationContext validateIntegrity(
    Insertable<PayloadRevision> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('payload_id')) {
      context.handle(
        _payloadIdMeta,
        payloadId.isAcceptableOrUnknown(data['payload_id']!, _payloadIdMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadIdMeta);
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    } else if (isInserting) {
      context.missing(_revisionMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('content_hash')) {
      context.handle(
        _contentHashMeta,
        contentHash.isAcceptableOrUnknown(
          data['content_hash']!,
          _contentHashMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contentHashMeta);
    }
    if (data.containsKey('observed_at')) {
      context.handle(
        _observedAtMeta,
        observedAt.isAcceptableOrUnknown(data['observed_at']!, _observedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_observedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {payloadId, revision};
  @override
  PayloadRevision map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PayloadRevision(
      payloadId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_id'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      contentHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_hash'],
      )!,
      cause: $PayloadRevisionsTable.$convertercause.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}cause'],
        )!,
      ),
      observedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}observed_at'],
      )!,
    );
  }

  @override
  $PayloadRevisionsTable createAlias(String alias) {
    return $PayloadRevisionsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<RevisionCause, String, String> $convertercause =
      const EnumNameConverter<RevisionCause>(RevisionCause.values);
}

class PayloadRevision extends DataClass implements Insertable<PayloadRevision> {
  final String payloadId;
  final int revision;
  final String content;
  final String contentHash;
  final RevisionCause cause;
  final DateTime observedAt;
  const PayloadRevision({
    required this.payloadId,
    required this.revision,
    required this.content,
    required this.contentHash,
    required this.cause,
    required this.observedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['payload_id'] = Variable<String>(payloadId);
    map['revision'] = Variable<int>(revision);
    map['content'] = Variable<String>(content);
    map['content_hash'] = Variable<String>(contentHash);
    {
      map['cause'] = Variable<String>(
        $PayloadRevisionsTable.$convertercause.toSql(cause),
      );
    }
    map['observed_at'] = Variable<DateTime>(observedAt);
    return map;
  }

  PayloadRevisionsCompanion toCompanion(bool nullToAbsent) {
    return PayloadRevisionsCompanion(
      payloadId: Value(payloadId),
      revision: Value(revision),
      content: Value(content),
      contentHash: Value(contentHash),
      cause: Value(cause),
      observedAt: Value(observedAt),
    );
  }

  factory PayloadRevision.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PayloadRevision(
      payloadId: serializer.fromJson<String>(json['payloadId']),
      revision: serializer.fromJson<int>(json['revision']),
      content: serializer.fromJson<String>(json['content']),
      contentHash: serializer.fromJson<String>(json['contentHash']),
      cause: $PayloadRevisionsTable.$convertercause.fromJson(
        serializer.fromJson<String>(json['cause']),
      ),
      observedAt: serializer.fromJson<DateTime>(json['observedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'payloadId': serializer.toJson<String>(payloadId),
      'revision': serializer.toJson<int>(revision),
      'content': serializer.toJson<String>(content),
      'contentHash': serializer.toJson<String>(contentHash),
      'cause': serializer.toJson<String>(
        $PayloadRevisionsTable.$convertercause.toJson(cause),
      ),
      'observedAt': serializer.toJson<DateTime>(observedAt),
    };
  }

  PayloadRevision copyWith({
    String? payloadId,
    int? revision,
    String? content,
    String? contentHash,
    RevisionCause? cause,
    DateTime? observedAt,
  }) => PayloadRevision(
    payloadId: payloadId ?? this.payloadId,
    revision: revision ?? this.revision,
    content: content ?? this.content,
    contentHash: contentHash ?? this.contentHash,
    cause: cause ?? this.cause,
    observedAt: observedAt ?? this.observedAt,
  );
  PayloadRevision copyWithCompanion(PayloadRevisionsCompanion data) {
    return PayloadRevision(
      payloadId: data.payloadId.present ? data.payloadId.value : this.payloadId,
      revision: data.revision.present ? data.revision.value : this.revision,
      content: data.content.present ? data.content.value : this.content,
      contentHash: data.contentHash.present
          ? data.contentHash.value
          : this.contentHash,
      cause: data.cause.present ? data.cause.value : this.cause,
      observedAt: data.observedAt.present
          ? data.observedAt.value
          : this.observedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PayloadRevision(')
          ..write('payloadId: $payloadId, ')
          ..write('revision: $revision, ')
          ..write('content: $content, ')
          ..write('contentHash: $contentHash, ')
          ..write('cause: $cause, ')
          ..write('observedAt: $observedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(payloadId, revision, content, contentHash, cause, observedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PayloadRevision &&
          other.payloadId == this.payloadId &&
          other.revision == this.revision &&
          other.content == this.content &&
          other.contentHash == this.contentHash &&
          other.cause == this.cause &&
          other.observedAt == this.observedAt);
}

class PayloadRevisionsCompanion extends UpdateCompanion<PayloadRevision> {
  final Value<String> payloadId;
  final Value<int> revision;
  final Value<String> content;
  final Value<String> contentHash;
  final Value<RevisionCause> cause;
  final Value<DateTime> observedAt;
  final Value<int> rowid;
  const PayloadRevisionsCompanion({
    this.payloadId = const Value.absent(),
    this.revision = const Value.absent(),
    this.content = const Value.absent(),
    this.contentHash = const Value.absent(),
    this.cause = const Value.absent(),
    this.observedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PayloadRevisionsCompanion.insert({
    required String payloadId,
    required int revision,
    required String content,
    required String contentHash,
    required RevisionCause cause,
    required DateTime observedAt,
    this.rowid = const Value.absent(),
  }) : payloadId = Value(payloadId),
       revision = Value(revision),
       content = Value(content),
       contentHash = Value(contentHash),
       cause = Value(cause),
       observedAt = Value(observedAt);
  static Insertable<PayloadRevision> custom({
    Expression<String>? payloadId,
    Expression<int>? revision,
    Expression<String>? content,
    Expression<String>? contentHash,
    Expression<String>? cause,
    Expression<DateTime>? observedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (payloadId != null) 'payload_id': payloadId,
      if (revision != null) 'revision': revision,
      if (content != null) 'content': content,
      if (contentHash != null) 'content_hash': contentHash,
      if (cause != null) 'cause': cause,
      if (observedAt != null) 'observed_at': observedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PayloadRevisionsCompanion copyWith({
    Value<String>? payloadId,
    Value<int>? revision,
    Value<String>? content,
    Value<String>? contentHash,
    Value<RevisionCause>? cause,
    Value<DateTime>? observedAt,
    Value<int>? rowid,
  }) {
    return PayloadRevisionsCompanion(
      payloadId: payloadId ?? this.payloadId,
      revision: revision ?? this.revision,
      content: content ?? this.content,
      contentHash: contentHash ?? this.contentHash,
      cause: cause ?? this.cause,
      observedAt: observedAt ?? this.observedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (payloadId.present) {
      map['payload_id'] = Variable<String>(payloadId.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (contentHash.present) {
      map['content_hash'] = Variable<String>(contentHash.value);
    }
    if (cause.present) {
      map['cause'] = Variable<String>(
        $PayloadRevisionsTable.$convertercause.toSql(cause.value),
      );
    }
    if (observedAt.present) {
      map['observed_at'] = Variable<DateTime>(observedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PayloadRevisionsCompanion(')
          ..write('payloadId: $payloadId, ')
          ..write('revision: $revision, ')
          ..write('content: $content, ')
          ..write('contentHash: $contentHash, ')
          ..write('cause: $cause, ')
          ..write('observedAt: $observedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AttachmentsTable extends Attachments
    with TableInfo<$AttachmentsTable, Attachment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AttachmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadIdMeta = const VerificationMeta(
    'payloadId',
  );
  @override
  late final GeneratedColumn<String> payloadId = GeneratedColumn<String>(
    'payload_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES payloads (id)',
    ),
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mimeMeta = const VerificationMeta('mime');
  @override
  late final GeneratedColumn<String> mime = GeneratedColumn<String>(
    'mime',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sha256Meta = const VerificationMeta('sha256');
  @override
  late final GeneratedColumn<String> sha256 = GeneratedColumn<String>(
    'sha256',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sizeMeta = const VerificationMeta('size');
  @override
  late final GeneratedColumn<int> size = GeneratedColumn<int>(
    'size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    payloadId,
    path,
    mime,
    sha256,
    size,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'attachments';
  @override
  VerificationContext validateIntegrity(
    Insertable<Attachment> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('payload_id')) {
      context.handle(
        _payloadIdMeta,
        payloadId.isAcceptableOrUnknown(data['payload_id']!, _payloadIdMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadIdMeta);
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('mime')) {
      context.handle(
        _mimeMeta,
        mime.isAcceptableOrUnknown(data['mime']!, _mimeMeta),
      );
    } else if (isInserting) {
      context.missing(_mimeMeta);
    }
    if (data.containsKey('sha256')) {
      context.handle(
        _sha256Meta,
        sha256.isAcceptableOrUnknown(data['sha256']!, _sha256Meta),
      );
    } else if (isInserting) {
      context.missing(_sha256Meta);
    }
    if (data.containsKey('size')) {
      context.handle(
        _sizeMeta,
        size.isAcceptableOrUnknown(data['size']!, _sizeMeta),
      );
    } else if (isInserting) {
      context.missing(_sizeMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Attachment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Attachment(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      payloadId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_id'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      mime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime'],
      )!,
      sha256: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sha256'],
      )!,
      size: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size'],
      )!,
    );
  }

  @override
  $AttachmentsTable createAlias(String alias) {
    return $AttachmentsTable(attachedDatabase, alias);
  }
}

class Attachment extends DataClass implements Insertable<Attachment> {
  final String id;
  final String payloadId;
  final String path;
  final String mime;
  final String sha256;
  final int size;
  const Attachment({
    required this.id,
    required this.payloadId,
    required this.path,
    required this.mime,
    required this.sha256,
    required this.size,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['payload_id'] = Variable<String>(payloadId);
    map['path'] = Variable<String>(path);
    map['mime'] = Variable<String>(mime);
    map['sha256'] = Variable<String>(sha256);
    map['size'] = Variable<int>(size);
    return map;
  }

  AttachmentsCompanion toCompanion(bool nullToAbsent) {
    return AttachmentsCompanion(
      id: Value(id),
      payloadId: Value(payloadId),
      path: Value(path),
      mime: Value(mime),
      sha256: Value(sha256),
      size: Value(size),
    );
  }

  factory Attachment.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Attachment(
      id: serializer.fromJson<String>(json['id']),
      payloadId: serializer.fromJson<String>(json['payloadId']),
      path: serializer.fromJson<String>(json['path']),
      mime: serializer.fromJson<String>(json['mime']),
      sha256: serializer.fromJson<String>(json['sha256']),
      size: serializer.fromJson<int>(json['size']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'payloadId': serializer.toJson<String>(payloadId),
      'path': serializer.toJson<String>(path),
      'mime': serializer.toJson<String>(mime),
      'sha256': serializer.toJson<String>(sha256),
      'size': serializer.toJson<int>(size),
    };
  }

  Attachment copyWith({
    String? id,
    String? payloadId,
    String? path,
    String? mime,
    String? sha256,
    int? size,
  }) => Attachment(
    id: id ?? this.id,
    payloadId: payloadId ?? this.payloadId,
    path: path ?? this.path,
    mime: mime ?? this.mime,
    sha256: sha256 ?? this.sha256,
    size: size ?? this.size,
  );
  Attachment copyWithCompanion(AttachmentsCompanion data) {
    return Attachment(
      id: data.id.present ? data.id.value : this.id,
      payloadId: data.payloadId.present ? data.payloadId.value : this.payloadId,
      path: data.path.present ? data.path.value : this.path,
      mime: data.mime.present ? data.mime.value : this.mime,
      sha256: data.sha256.present ? data.sha256.value : this.sha256,
      size: data.size.present ? data.size.value : this.size,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Attachment(')
          ..write('id: $id, ')
          ..write('payloadId: $payloadId, ')
          ..write('path: $path, ')
          ..write('mime: $mime, ')
          ..write('sha256: $sha256, ')
          ..write('size: $size')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, payloadId, path, mime, sha256, size);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Attachment &&
          other.id == this.id &&
          other.payloadId == this.payloadId &&
          other.path == this.path &&
          other.mime == this.mime &&
          other.sha256 == this.sha256 &&
          other.size == this.size);
}

class AttachmentsCompanion extends UpdateCompanion<Attachment> {
  final Value<String> id;
  final Value<String> payloadId;
  final Value<String> path;
  final Value<String> mime;
  final Value<String> sha256;
  final Value<int> size;
  final Value<int> rowid;
  const AttachmentsCompanion({
    this.id = const Value.absent(),
    this.payloadId = const Value.absent(),
    this.path = const Value.absent(),
    this.mime = const Value.absent(),
    this.sha256 = const Value.absent(),
    this.size = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AttachmentsCompanion.insert({
    required String id,
    required String payloadId,
    required String path,
    required String mime,
    required String sha256,
    required int size,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       payloadId = Value(payloadId),
       path = Value(path),
       mime = Value(mime),
       sha256 = Value(sha256),
       size = Value(size);
  static Insertable<Attachment> custom({
    Expression<String>? id,
    Expression<String>? payloadId,
    Expression<String>? path,
    Expression<String>? mime,
    Expression<String>? sha256,
    Expression<int>? size,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (payloadId != null) 'payload_id': payloadId,
      if (path != null) 'path': path,
      if (mime != null) 'mime': mime,
      if (sha256 != null) 'sha256': sha256,
      if (size != null) 'size': size,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AttachmentsCompanion copyWith({
    Value<String>? id,
    Value<String>? payloadId,
    Value<String>? path,
    Value<String>? mime,
    Value<String>? sha256,
    Value<int>? size,
    Value<int>? rowid,
  }) {
    return AttachmentsCompanion(
      id: id ?? this.id,
      payloadId: payloadId ?? this.payloadId,
      path: path ?? this.path,
      mime: mime ?? this.mime,
      sha256: sha256 ?? this.sha256,
      size: size ?? this.size,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (payloadId.present) {
      map['payload_id'] = Variable<String>(payloadId.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (mime.present) {
      map['mime'] = Variable<String>(mime.value);
    }
    if (sha256.present) {
      map['sha256'] = Variable<String>(sha256.value);
    }
    if (size.present) {
      map['size'] = Variable<int>(size.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AttachmentsCompanion(')
          ..write('id: $id, ')
          ..write('payloadId: $payloadId, ')
          ..write('path: $path, ')
          ..write('mime: $mime, ')
          ..write('sha256: $sha256, ')
          ..write('size: $size, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EnrichmentsTable extends Enrichments
    with TableInfo<$EnrichmentsTable, Enrichment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EnrichmentsTable(this.attachedDatabase, [this._alias]);
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
  late final GeneratedColumnWithTypeConverter<EntityType, String> targetType =
      GeneratedColumn<String>(
        'target_type',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<EntityType>($EnrichmentsTable.$convertertargetType);
  static const VerificationMeta _targetIdMeta = const VerificationMeta(
    'targetId',
  );
  @override
  late final GeneratedColumn<String> targetId = GeneratedColumn<String>(
    'target_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _outputMeta = const VerificationMeta('output');
  @override
  late final GeneratedColumn<String> output = GeneratedColumn<String>(
    'output',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modelIdMeta = const VerificationMeta(
    'modelId',
  );
  @override
  late final GeneratedColumn<String> modelId = GeneratedColumn<String>(
    'model_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
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
    targetType,
    targetId,
    kind,
    output,
    modelId,
    revision,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'enrichments';
  @override
  VerificationContext validateIntegrity(
    Insertable<Enrichment> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('target_id')) {
      context.handle(
        _targetIdMeta,
        targetId.isAcceptableOrUnknown(data['target_id']!, _targetIdMeta),
      );
    } else if (isInserting) {
      context.missing(_targetIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('output')) {
      context.handle(
        _outputMeta,
        output.isAcceptableOrUnknown(data['output']!, _outputMeta),
      );
    } else if (isInserting) {
      context.missing(_outputMeta);
    }
    if (data.containsKey('model_id')) {
      context.handle(
        _modelIdMeta,
        modelId.isAcceptableOrUnknown(data['model_id']!, _modelIdMeta),
      );
    } else if (isInserting) {
      context.missing(_modelIdMeta);
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
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
  Enrichment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Enrichment(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      targetType: $EnrichmentsTable.$convertertargetType.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}target_type'],
        )!,
      ),
      targetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      output: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}output'],
      )!,
      modelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model_id'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $EnrichmentsTable createAlias(String alias) {
    return $EnrichmentsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<EntityType, String, String> $convertertargetType =
      const EnumNameConverter<EntityType>(EntityType.values);
}

class Enrichment extends DataClass implements Insertable<Enrichment> {
  final String id;
  final EntityType targetType;
  final String targetId;
  final String kind;
  final String output;
  final String modelId;
  final int revision;
  final DateTime createdAt;
  const Enrichment({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.kind,
    required this.output,
    required this.modelId,
    required this.revision,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    {
      map['target_type'] = Variable<String>(
        $EnrichmentsTable.$convertertargetType.toSql(targetType),
      );
    }
    map['target_id'] = Variable<String>(targetId);
    map['kind'] = Variable<String>(kind);
    map['output'] = Variable<String>(output);
    map['model_id'] = Variable<String>(modelId);
    map['revision'] = Variable<int>(revision);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  EnrichmentsCompanion toCompanion(bool nullToAbsent) {
    return EnrichmentsCompanion(
      id: Value(id),
      targetType: Value(targetType),
      targetId: Value(targetId),
      kind: Value(kind),
      output: Value(output),
      modelId: Value(modelId),
      revision: Value(revision),
      createdAt: Value(createdAt),
    );
  }

  factory Enrichment.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Enrichment(
      id: serializer.fromJson<String>(json['id']),
      targetType: $EnrichmentsTable.$convertertargetType.fromJson(
        serializer.fromJson<String>(json['targetType']),
      ),
      targetId: serializer.fromJson<String>(json['targetId']),
      kind: serializer.fromJson<String>(json['kind']),
      output: serializer.fromJson<String>(json['output']),
      modelId: serializer.fromJson<String>(json['modelId']),
      revision: serializer.fromJson<int>(json['revision']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'targetType': serializer.toJson<String>(
        $EnrichmentsTable.$convertertargetType.toJson(targetType),
      ),
      'targetId': serializer.toJson<String>(targetId),
      'kind': serializer.toJson<String>(kind),
      'output': serializer.toJson<String>(output),
      'modelId': serializer.toJson<String>(modelId),
      'revision': serializer.toJson<int>(revision),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Enrichment copyWith({
    String? id,
    EntityType? targetType,
    String? targetId,
    String? kind,
    String? output,
    String? modelId,
    int? revision,
    DateTime? createdAt,
  }) => Enrichment(
    id: id ?? this.id,
    targetType: targetType ?? this.targetType,
    targetId: targetId ?? this.targetId,
    kind: kind ?? this.kind,
    output: output ?? this.output,
    modelId: modelId ?? this.modelId,
    revision: revision ?? this.revision,
    createdAt: createdAt ?? this.createdAt,
  );
  Enrichment copyWithCompanion(EnrichmentsCompanion data) {
    return Enrichment(
      id: data.id.present ? data.id.value : this.id,
      targetType: data.targetType.present
          ? data.targetType.value
          : this.targetType,
      targetId: data.targetId.present ? data.targetId.value : this.targetId,
      kind: data.kind.present ? data.kind.value : this.kind,
      output: data.output.present ? data.output.value : this.output,
      modelId: data.modelId.present ? data.modelId.value : this.modelId,
      revision: data.revision.present ? data.revision.value : this.revision,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Enrichment(')
          ..write('id: $id, ')
          ..write('targetType: $targetType, ')
          ..write('targetId: $targetId, ')
          ..write('kind: $kind, ')
          ..write('output: $output, ')
          ..write('modelId: $modelId, ')
          ..write('revision: $revision, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    targetType,
    targetId,
    kind,
    output,
    modelId,
    revision,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Enrichment &&
          other.id == this.id &&
          other.targetType == this.targetType &&
          other.targetId == this.targetId &&
          other.kind == this.kind &&
          other.output == this.output &&
          other.modelId == this.modelId &&
          other.revision == this.revision &&
          other.createdAt == this.createdAt);
}

class EnrichmentsCompanion extends UpdateCompanion<Enrichment> {
  final Value<String> id;
  final Value<EntityType> targetType;
  final Value<String> targetId;
  final Value<String> kind;
  final Value<String> output;
  final Value<String> modelId;
  final Value<int> revision;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const EnrichmentsCompanion({
    this.id = const Value.absent(),
    this.targetType = const Value.absent(),
    this.targetId = const Value.absent(),
    this.kind = const Value.absent(),
    this.output = const Value.absent(),
    this.modelId = const Value.absent(),
    this.revision = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EnrichmentsCompanion.insert({
    required String id,
    required EntityType targetType,
    required String targetId,
    required String kind,
    required String output,
    required String modelId,
    this.revision = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       targetType = Value(targetType),
       targetId = Value(targetId),
       kind = Value(kind),
       output = Value(output),
       modelId = Value(modelId),
       createdAt = Value(createdAt);
  static Insertable<Enrichment> custom({
    Expression<String>? id,
    Expression<String>? targetType,
    Expression<String>? targetId,
    Expression<String>? kind,
    Expression<String>? output,
    Expression<String>? modelId,
    Expression<int>? revision,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (targetType != null) 'target_type': targetType,
      if (targetId != null) 'target_id': targetId,
      if (kind != null) 'kind': kind,
      if (output != null) 'output': output,
      if (modelId != null) 'model_id': modelId,
      if (revision != null) 'revision': revision,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EnrichmentsCompanion copyWith({
    Value<String>? id,
    Value<EntityType>? targetType,
    Value<String>? targetId,
    Value<String>? kind,
    Value<String>? output,
    Value<String>? modelId,
    Value<int>? revision,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return EnrichmentsCompanion(
      id: id ?? this.id,
      targetType: targetType ?? this.targetType,
      targetId: targetId ?? this.targetId,
      kind: kind ?? this.kind,
      output: output ?? this.output,
      modelId: modelId ?? this.modelId,
      revision: revision ?? this.revision,
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
    if (targetType.present) {
      map['target_type'] = Variable<String>(
        $EnrichmentsTable.$convertertargetType.toSql(targetType.value),
      );
    }
    if (targetId.present) {
      map['target_id'] = Variable<String>(targetId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (output.present) {
      map['output'] = Variable<String>(output.value);
    }
    if (modelId.present) {
      map['model_id'] = Variable<String>(modelId.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
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
    return (StringBuffer('EnrichmentsCompanion(')
          ..write('id: $id, ')
          ..write('targetType: $targetType, ')
          ..write('targetId: $targetId, ')
          ..write('kind: $kind, ')
          ..write('output: $output, ')
          ..write('modelId: $modelId, ')
          ..write('revision: $revision, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WorkstreamsTable extends Workstreams
    with TableInfo<$WorkstreamsTable, Workstream> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkstreamsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES projects (id)',
    ),
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
  static const VerificationMeta _summaryMeta = const VerificationMeta(
    'summary',
  );
  @override
  late final GeneratedColumn<String> summary = GeneratedColumn<String>(
    'summary',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _spanStartMeta = const VerificationMeta(
    'spanStart',
  );
  @override
  late final GeneratedColumn<String> spanStart = GeneratedColumn<String>(
    'span_start',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _spanEndMeta = const VerificationMeta(
    'spanEnd',
  );
  @override
  late final GeneratedColumn<String> spanEnd = GeneratedColumn<String>(
    'span_end',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _userTouchedMeta = const VerificationMeta(
    'userTouched',
  );
  @override
  late final GeneratedColumn<bool> userTouched = GeneratedColumn<bool>(
    'user_touched',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("user_touched" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    projectId,
    title,
    summary,
    spanStart,
    spanEnd,
    userTouched,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workstreams';
  @override
  VerificationContext validateIntegrity(
    Insertable<Workstream> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
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
    if (data.containsKey('summary')) {
      context.handle(
        _summaryMeta,
        summary.isAcceptableOrUnknown(data['summary']!, _summaryMeta),
      );
    }
    if (data.containsKey('span_start')) {
      context.handle(
        _spanStartMeta,
        spanStart.isAcceptableOrUnknown(data['span_start']!, _spanStartMeta),
      );
    }
    if (data.containsKey('span_end')) {
      context.handle(
        _spanEndMeta,
        spanEnd.isAcceptableOrUnknown(data['span_end']!, _spanEndMeta),
      );
    }
    if (data.containsKey('user_touched')) {
      context.handle(
        _userTouchedMeta,
        userTouched.isAcceptableOrUnknown(
          data['user_touched']!,
          _userTouchedMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Workstream map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Workstream(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      summary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary'],
      )!,
      spanStart: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}span_start'],
      ),
      spanEnd: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}span_end'],
      ),
      userTouched: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}user_touched'],
      )!,
    );
  }

  @override
  $WorkstreamsTable createAlias(String alias) {
    return $WorkstreamsTable(attachedDatabase, alias);
  }
}

class Workstream extends DataClass implements Insertable<Workstream> {
  final String id;
  final String? projectId;
  final String title;
  final String summary;
  final String? spanStart;
  final String? spanEnd;
  final bool userTouched;
  const Workstream({
    required this.id,
    this.projectId,
    required this.title,
    required this.summary,
    this.spanStart,
    this.spanEnd,
    required this.userTouched,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || projectId != null) {
      map['project_id'] = Variable<String>(projectId);
    }
    map['title'] = Variable<String>(title);
    map['summary'] = Variable<String>(summary);
    if (!nullToAbsent || spanStart != null) {
      map['span_start'] = Variable<String>(spanStart);
    }
    if (!nullToAbsent || spanEnd != null) {
      map['span_end'] = Variable<String>(spanEnd);
    }
    map['user_touched'] = Variable<bool>(userTouched);
    return map;
  }

  WorkstreamsCompanion toCompanion(bool nullToAbsent) {
    return WorkstreamsCompanion(
      id: Value(id),
      projectId: projectId == null && nullToAbsent
          ? const Value.absent()
          : Value(projectId),
      title: Value(title),
      summary: Value(summary),
      spanStart: spanStart == null && nullToAbsent
          ? const Value.absent()
          : Value(spanStart),
      spanEnd: spanEnd == null && nullToAbsent
          ? const Value.absent()
          : Value(spanEnd),
      userTouched: Value(userTouched),
    );
  }

  factory Workstream.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Workstream(
      id: serializer.fromJson<String>(json['id']),
      projectId: serializer.fromJson<String?>(json['projectId']),
      title: serializer.fromJson<String>(json['title']),
      summary: serializer.fromJson<String>(json['summary']),
      spanStart: serializer.fromJson<String?>(json['spanStart']),
      spanEnd: serializer.fromJson<String?>(json['spanEnd']),
      userTouched: serializer.fromJson<bool>(json['userTouched']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'projectId': serializer.toJson<String?>(projectId),
      'title': serializer.toJson<String>(title),
      'summary': serializer.toJson<String>(summary),
      'spanStart': serializer.toJson<String?>(spanStart),
      'spanEnd': serializer.toJson<String?>(spanEnd),
      'userTouched': serializer.toJson<bool>(userTouched),
    };
  }

  Workstream copyWith({
    String? id,
    Value<String?> projectId = const Value.absent(),
    String? title,
    String? summary,
    Value<String?> spanStart = const Value.absent(),
    Value<String?> spanEnd = const Value.absent(),
    bool? userTouched,
  }) => Workstream(
    id: id ?? this.id,
    projectId: projectId.present ? projectId.value : this.projectId,
    title: title ?? this.title,
    summary: summary ?? this.summary,
    spanStart: spanStart.present ? spanStart.value : this.spanStart,
    spanEnd: spanEnd.present ? spanEnd.value : this.spanEnd,
    userTouched: userTouched ?? this.userTouched,
  );
  Workstream copyWithCompanion(WorkstreamsCompanion data) {
    return Workstream(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      title: data.title.present ? data.title.value : this.title,
      summary: data.summary.present ? data.summary.value : this.summary,
      spanStart: data.spanStart.present ? data.spanStart.value : this.spanStart,
      spanEnd: data.spanEnd.present ? data.spanEnd.value : this.spanEnd,
      userTouched: data.userTouched.present
          ? data.userTouched.value
          : this.userTouched,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Workstream(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('title: $title, ')
          ..write('summary: $summary, ')
          ..write('spanStart: $spanStart, ')
          ..write('spanEnd: $spanEnd, ')
          ..write('userTouched: $userTouched')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    projectId,
    title,
    summary,
    spanStart,
    spanEnd,
    userTouched,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Workstream &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.title == this.title &&
          other.summary == this.summary &&
          other.spanStart == this.spanStart &&
          other.spanEnd == this.spanEnd &&
          other.userTouched == this.userTouched);
}

class WorkstreamsCompanion extends UpdateCompanion<Workstream> {
  final Value<String> id;
  final Value<String?> projectId;
  final Value<String> title;
  final Value<String> summary;
  final Value<String?> spanStart;
  final Value<String?> spanEnd;
  final Value<bool> userTouched;
  final Value<int> rowid;
  const WorkstreamsCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.title = const Value.absent(),
    this.summary = const Value.absent(),
    this.spanStart = const Value.absent(),
    this.spanEnd = const Value.absent(),
    this.userTouched = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorkstreamsCompanion.insert({
    required String id,
    this.projectId = const Value.absent(),
    required String title,
    this.summary = const Value.absent(),
    this.spanStart = const Value.absent(),
    this.spanEnd = const Value.absent(),
    this.userTouched = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title);
  static Insertable<Workstream> custom({
    Expression<String>? id,
    Expression<String>? projectId,
    Expression<String>? title,
    Expression<String>? summary,
    Expression<String>? spanStart,
    Expression<String>? spanEnd,
    Expression<bool>? userTouched,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (title != null) 'title': title,
      if (summary != null) 'summary': summary,
      if (spanStart != null) 'span_start': spanStart,
      if (spanEnd != null) 'span_end': spanEnd,
      if (userTouched != null) 'user_touched': userTouched,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorkstreamsCompanion copyWith({
    Value<String>? id,
    Value<String?>? projectId,
    Value<String>? title,
    Value<String>? summary,
    Value<String?>? spanStart,
    Value<String?>? spanEnd,
    Value<bool>? userTouched,
    Value<int>? rowid,
  }) {
    return WorkstreamsCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      spanStart: spanStart ?? this.spanStart,
      spanEnd: spanEnd ?? this.spanEnd,
      userTouched: userTouched ?? this.userTouched,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (summary.present) {
      map['summary'] = Variable<String>(summary.value);
    }
    if (spanStart.present) {
      map['span_start'] = Variable<String>(spanStart.value);
    }
    if (spanEnd.present) {
      map['span_end'] = Variable<String>(spanEnd.value);
    }
    if (userTouched.present) {
      map['user_touched'] = Variable<bool>(userTouched.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkstreamsCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('title: $title, ')
          ..write('summary: $summary, ')
          ..write('spanStart: $spanStart, ')
          ..write('spanEnd: $spanEnd, ')
          ..write('userTouched: $userTouched, ')
          ..write('rowid: $rowid')
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
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<FactType, String> type =
      GeneratedColumn<String>(
        'type',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<FactType>($FactsTable.$convertertype);
  static const VerificationMeta _statementMeta = const VerificationMeta(
    'statement',
  );
  @override
  late final GeneratedColumn<String> statement = GeneratedColumn<String>(
    'statement',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _detailsMeta = const VerificationMeta(
    'details',
  );
  @override
  late final GeneratedColumn<String> details = GeneratedColumn<String>(
    'details',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _periodStartMeta = const VerificationMeta(
    'periodStart',
  );
  @override
  late final GeneratedColumn<String> periodStart = GeneratedColumn<String>(
    'period_start',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _periodEndMeta = const VerificationMeta(
    'periodEnd',
  );
  @override
  late final GeneratedColumn<String> periodEnd = GeneratedColumn<String>(
    'period_end',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _workstreamIdMeta = const VerificationMeta(
    'workstreamId',
  );
  @override
  late final GeneratedColumn<String> workstreamId = GeneratedColumn<String>(
    'workstream_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES workstreams (id)',
    ),
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES projects (id)',
    ),
  );
  static const VerificationMeta _importanceMeta = const VerificationMeta(
    'importance',
  );
  @override
  late final GeneratedColumn<double> importance = GeneratedColumn<double>(
    'importance',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.5),
  );
  @override
  late final GeneratedColumnWithTypeConverter<FactOrigin, String> origin =
      GeneratedColumn<String>(
        'origin',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<FactOrigin>($FactsTable.$converterorigin);
  @override
  late final GeneratedColumnWithTypeConverter<ReviewState, String> reviewState =
      GeneratedColumn<String>(
        'review_state',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: Constant(ReviewState.ok.name),
      ).withConverter<ReviewState>($FactsTable.$converterreviewState);
  static const VerificationMeta _reviewProposalMeta = const VerificationMeta(
    'reviewProposal',
  );
  @override
  late final GeneratedColumn<String> reviewProposal = GeneratedColumn<String>(
    'review_proposal',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<WinStatus, String> winStatus =
      GeneratedColumn<String>(
        'win_status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: Constant(WinStatus.none.name),
      ).withConverter<WinStatus>($FactsTable.$converterwinStatus);
  static const VerificationMeta _retiredMeta = const VerificationMeta(
    'retired',
  );
  @override
  late final GeneratedColumn<bool> retired = GeneratedColumn<bool>(
    'retired',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("retired" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
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
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    type,
    statement,
    details,
    periodStart,
    periodEnd,
    workstreamId,
    projectId,
    importance,
    origin,
    reviewState,
    reviewProposal,
    winStatus,
    retired,
    revision,
    createdAt,
    updatedAt,
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
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('statement')) {
      context.handle(
        _statementMeta,
        statement.isAcceptableOrUnknown(data['statement']!, _statementMeta),
      );
    } else if (isInserting) {
      context.missing(_statementMeta);
    }
    if (data.containsKey('details')) {
      context.handle(
        _detailsMeta,
        details.isAcceptableOrUnknown(data['details']!, _detailsMeta),
      );
    }
    if (data.containsKey('period_start')) {
      context.handle(
        _periodStartMeta,
        periodStart.isAcceptableOrUnknown(
          data['period_start']!,
          _periodStartMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_periodStartMeta);
    }
    if (data.containsKey('period_end')) {
      context.handle(
        _periodEndMeta,
        periodEnd.isAcceptableOrUnknown(data['period_end']!, _periodEndMeta),
      );
    } else if (isInserting) {
      context.missing(_periodEndMeta);
    }
    if (data.containsKey('workstream_id')) {
      context.handle(
        _workstreamIdMeta,
        workstreamId.isAcceptableOrUnknown(
          data['workstream_id']!,
          _workstreamIdMeta,
        ),
      );
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    }
    if (data.containsKey('importance')) {
      context.handle(
        _importanceMeta,
        importance.isAcceptableOrUnknown(data['importance']!, _importanceMeta),
      );
    }
    if (data.containsKey('review_proposal')) {
      context.handle(
        _reviewProposalMeta,
        reviewProposal.isAcceptableOrUnknown(
          data['review_proposal']!,
          _reviewProposalMeta,
        ),
      );
    }
    if (data.containsKey('retired')) {
      context.handle(
        _retiredMeta,
        retired.isAcceptableOrUnknown(data['retired']!, _retiredMeta),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
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
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
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
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      type: $FactsTable.$convertertype.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}type'],
        )!,
      ),
      statement: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}statement'],
      )!,
      details: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}details'],
      )!,
      periodStart: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}period_start'],
      )!,
      periodEnd: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}period_end'],
      )!,
      workstreamId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}workstream_id'],
      ),
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      ),
      importance: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}importance'],
      )!,
      origin: $FactsTable.$converterorigin.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}origin'],
        )!,
      ),
      reviewState: $FactsTable.$converterreviewState.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}review_state'],
        )!,
      ),
      reviewProposal: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}review_proposal'],
      ),
      winStatus: $FactsTable.$converterwinStatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}win_status'],
        )!,
      ),
      retired: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}retired'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $FactsTable createAlias(String alias) {
    return $FactsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<FactType, String, String> $convertertype =
      const EnumNameConverter<FactType>(FactType.values);
  static JsonTypeConverter2<FactOrigin, String, String> $converterorigin =
      const EnumNameConverter<FactOrigin>(FactOrigin.values);
  static JsonTypeConverter2<ReviewState, String, String> $converterreviewState =
      const EnumNameConverter<ReviewState>(ReviewState.values);
  static JsonTypeConverter2<WinStatus, String, String> $converterwinStatus =
      const EnumNameConverter<WinStatus>(WinStatus.values);
}

class Fact extends DataClass implements Insertable<Fact> {
  final String id;
  final FactType type;
  final String statement;
  final String details;
  final String periodStart;
  final String periodEnd;
  final String? workstreamId;
  final String? projectId;
  final double importance;
  final FactOrigin origin;
  final ReviewState reviewState;

  /// Pending model proposal for a user-touched fact (JSON), shown in the review queue.
  final String? reviewProposal;
  final WinStatus winStatus;
  final bool retired;
  final int revision;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Fact({
    required this.id,
    required this.type,
    required this.statement,
    required this.details,
    required this.periodStart,
    required this.periodEnd,
    this.workstreamId,
    this.projectId,
    required this.importance,
    required this.origin,
    required this.reviewState,
    this.reviewProposal,
    required this.winStatus,
    required this.retired,
    required this.revision,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    {
      map['type'] = Variable<String>($FactsTable.$convertertype.toSql(type));
    }
    map['statement'] = Variable<String>(statement);
    map['details'] = Variable<String>(details);
    map['period_start'] = Variable<String>(periodStart);
    map['period_end'] = Variable<String>(periodEnd);
    if (!nullToAbsent || workstreamId != null) {
      map['workstream_id'] = Variable<String>(workstreamId);
    }
    if (!nullToAbsent || projectId != null) {
      map['project_id'] = Variable<String>(projectId);
    }
    map['importance'] = Variable<double>(importance);
    {
      map['origin'] = Variable<String>(
        $FactsTable.$converterorigin.toSql(origin),
      );
    }
    {
      map['review_state'] = Variable<String>(
        $FactsTable.$converterreviewState.toSql(reviewState),
      );
    }
    if (!nullToAbsent || reviewProposal != null) {
      map['review_proposal'] = Variable<String>(reviewProposal);
    }
    {
      map['win_status'] = Variable<String>(
        $FactsTable.$converterwinStatus.toSql(winStatus),
      );
    }
    map['retired'] = Variable<bool>(retired);
    map['revision'] = Variable<int>(revision);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  FactsCompanion toCompanion(bool nullToAbsent) {
    return FactsCompanion(
      id: Value(id),
      type: Value(type),
      statement: Value(statement),
      details: Value(details),
      periodStart: Value(periodStart),
      periodEnd: Value(periodEnd),
      workstreamId: workstreamId == null && nullToAbsent
          ? const Value.absent()
          : Value(workstreamId),
      projectId: projectId == null && nullToAbsent
          ? const Value.absent()
          : Value(projectId),
      importance: Value(importance),
      origin: Value(origin),
      reviewState: Value(reviewState),
      reviewProposal: reviewProposal == null && nullToAbsent
          ? const Value.absent()
          : Value(reviewProposal),
      winStatus: Value(winStatus),
      retired: Value(retired),
      revision: Value(revision),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Fact.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Fact(
      id: serializer.fromJson<String>(json['id']),
      type: $FactsTable.$convertertype.fromJson(
        serializer.fromJson<String>(json['type']),
      ),
      statement: serializer.fromJson<String>(json['statement']),
      details: serializer.fromJson<String>(json['details']),
      periodStart: serializer.fromJson<String>(json['periodStart']),
      periodEnd: serializer.fromJson<String>(json['periodEnd']),
      workstreamId: serializer.fromJson<String?>(json['workstreamId']),
      projectId: serializer.fromJson<String?>(json['projectId']),
      importance: serializer.fromJson<double>(json['importance']),
      origin: $FactsTable.$converterorigin.fromJson(
        serializer.fromJson<String>(json['origin']),
      ),
      reviewState: $FactsTable.$converterreviewState.fromJson(
        serializer.fromJson<String>(json['reviewState']),
      ),
      reviewProposal: serializer.fromJson<String?>(json['reviewProposal']),
      winStatus: $FactsTable.$converterwinStatus.fromJson(
        serializer.fromJson<String>(json['winStatus']),
      ),
      retired: serializer.fromJson<bool>(json['retired']),
      revision: serializer.fromJson<int>(json['revision']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'type': serializer.toJson<String>(
        $FactsTable.$convertertype.toJson(type),
      ),
      'statement': serializer.toJson<String>(statement),
      'details': serializer.toJson<String>(details),
      'periodStart': serializer.toJson<String>(periodStart),
      'periodEnd': serializer.toJson<String>(periodEnd),
      'workstreamId': serializer.toJson<String?>(workstreamId),
      'projectId': serializer.toJson<String?>(projectId),
      'importance': serializer.toJson<double>(importance),
      'origin': serializer.toJson<String>(
        $FactsTable.$converterorigin.toJson(origin),
      ),
      'reviewState': serializer.toJson<String>(
        $FactsTable.$converterreviewState.toJson(reviewState),
      ),
      'reviewProposal': serializer.toJson<String?>(reviewProposal),
      'winStatus': serializer.toJson<String>(
        $FactsTable.$converterwinStatus.toJson(winStatus),
      ),
      'retired': serializer.toJson<bool>(retired),
      'revision': serializer.toJson<int>(revision),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Fact copyWith({
    String? id,
    FactType? type,
    String? statement,
    String? details,
    String? periodStart,
    String? periodEnd,
    Value<String?> workstreamId = const Value.absent(),
    Value<String?> projectId = const Value.absent(),
    double? importance,
    FactOrigin? origin,
    ReviewState? reviewState,
    Value<String?> reviewProposal = const Value.absent(),
    WinStatus? winStatus,
    bool? retired,
    int? revision,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Fact(
    id: id ?? this.id,
    type: type ?? this.type,
    statement: statement ?? this.statement,
    details: details ?? this.details,
    periodStart: periodStart ?? this.periodStart,
    periodEnd: periodEnd ?? this.periodEnd,
    workstreamId: workstreamId.present ? workstreamId.value : this.workstreamId,
    projectId: projectId.present ? projectId.value : this.projectId,
    importance: importance ?? this.importance,
    origin: origin ?? this.origin,
    reviewState: reviewState ?? this.reviewState,
    reviewProposal: reviewProposal.present
        ? reviewProposal.value
        : this.reviewProposal,
    winStatus: winStatus ?? this.winStatus,
    retired: retired ?? this.retired,
    revision: revision ?? this.revision,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Fact copyWithCompanion(FactsCompanion data) {
    return Fact(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      statement: data.statement.present ? data.statement.value : this.statement,
      details: data.details.present ? data.details.value : this.details,
      periodStart: data.periodStart.present
          ? data.periodStart.value
          : this.periodStart,
      periodEnd: data.periodEnd.present ? data.periodEnd.value : this.periodEnd,
      workstreamId: data.workstreamId.present
          ? data.workstreamId.value
          : this.workstreamId,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      importance: data.importance.present
          ? data.importance.value
          : this.importance,
      origin: data.origin.present ? data.origin.value : this.origin,
      reviewState: data.reviewState.present
          ? data.reviewState.value
          : this.reviewState,
      reviewProposal: data.reviewProposal.present
          ? data.reviewProposal.value
          : this.reviewProposal,
      winStatus: data.winStatus.present ? data.winStatus.value : this.winStatus,
      retired: data.retired.present ? data.retired.value : this.retired,
      revision: data.revision.present ? data.revision.value : this.revision,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Fact(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('statement: $statement, ')
          ..write('details: $details, ')
          ..write('periodStart: $periodStart, ')
          ..write('periodEnd: $periodEnd, ')
          ..write('workstreamId: $workstreamId, ')
          ..write('projectId: $projectId, ')
          ..write('importance: $importance, ')
          ..write('origin: $origin, ')
          ..write('reviewState: $reviewState, ')
          ..write('reviewProposal: $reviewProposal, ')
          ..write('winStatus: $winStatus, ')
          ..write('retired: $retired, ')
          ..write('revision: $revision, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    type,
    statement,
    details,
    periodStart,
    periodEnd,
    workstreamId,
    projectId,
    importance,
    origin,
    reviewState,
    reviewProposal,
    winStatus,
    retired,
    revision,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Fact &&
          other.id == this.id &&
          other.type == this.type &&
          other.statement == this.statement &&
          other.details == this.details &&
          other.periodStart == this.periodStart &&
          other.periodEnd == this.periodEnd &&
          other.workstreamId == this.workstreamId &&
          other.projectId == this.projectId &&
          other.importance == this.importance &&
          other.origin == this.origin &&
          other.reviewState == this.reviewState &&
          other.reviewProposal == this.reviewProposal &&
          other.winStatus == this.winStatus &&
          other.retired == this.retired &&
          other.revision == this.revision &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class FactsCompanion extends UpdateCompanion<Fact> {
  final Value<String> id;
  final Value<FactType> type;
  final Value<String> statement;
  final Value<String> details;
  final Value<String> periodStart;
  final Value<String> periodEnd;
  final Value<String?> workstreamId;
  final Value<String?> projectId;
  final Value<double> importance;
  final Value<FactOrigin> origin;
  final Value<ReviewState> reviewState;
  final Value<String?> reviewProposal;
  final Value<WinStatus> winStatus;
  final Value<bool> retired;
  final Value<int> revision;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const FactsCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.statement = const Value.absent(),
    this.details = const Value.absent(),
    this.periodStart = const Value.absent(),
    this.periodEnd = const Value.absent(),
    this.workstreamId = const Value.absent(),
    this.projectId = const Value.absent(),
    this.importance = const Value.absent(),
    this.origin = const Value.absent(),
    this.reviewState = const Value.absent(),
    this.reviewProposal = const Value.absent(),
    this.winStatus = const Value.absent(),
    this.retired = const Value.absent(),
    this.revision = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FactsCompanion.insert({
    required String id,
    required FactType type,
    required String statement,
    this.details = const Value.absent(),
    required String periodStart,
    required String periodEnd,
    this.workstreamId = const Value.absent(),
    this.projectId = const Value.absent(),
    this.importance = const Value.absent(),
    required FactOrigin origin,
    this.reviewState = const Value.absent(),
    this.reviewProposal = const Value.absent(),
    this.winStatus = const Value.absent(),
    this.retired = const Value.absent(),
    this.revision = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       type = Value(type),
       statement = Value(statement),
       periodStart = Value(periodStart),
       periodEnd = Value(periodEnd),
       origin = Value(origin),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Fact> custom({
    Expression<String>? id,
    Expression<String>? type,
    Expression<String>? statement,
    Expression<String>? details,
    Expression<String>? periodStart,
    Expression<String>? periodEnd,
    Expression<String>? workstreamId,
    Expression<String>? projectId,
    Expression<double>? importance,
    Expression<String>? origin,
    Expression<String>? reviewState,
    Expression<String>? reviewProposal,
    Expression<String>? winStatus,
    Expression<bool>? retired,
    Expression<int>? revision,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (statement != null) 'statement': statement,
      if (details != null) 'details': details,
      if (periodStart != null) 'period_start': periodStart,
      if (periodEnd != null) 'period_end': periodEnd,
      if (workstreamId != null) 'workstream_id': workstreamId,
      if (projectId != null) 'project_id': projectId,
      if (importance != null) 'importance': importance,
      if (origin != null) 'origin': origin,
      if (reviewState != null) 'review_state': reviewState,
      if (reviewProposal != null) 'review_proposal': reviewProposal,
      if (winStatus != null) 'win_status': winStatus,
      if (retired != null) 'retired': retired,
      if (revision != null) 'revision': revision,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FactsCompanion copyWith({
    Value<String>? id,
    Value<FactType>? type,
    Value<String>? statement,
    Value<String>? details,
    Value<String>? periodStart,
    Value<String>? periodEnd,
    Value<String?>? workstreamId,
    Value<String?>? projectId,
    Value<double>? importance,
    Value<FactOrigin>? origin,
    Value<ReviewState>? reviewState,
    Value<String?>? reviewProposal,
    Value<WinStatus>? winStatus,
    Value<bool>? retired,
    Value<int>? revision,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return FactsCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      statement: statement ?? this.statement,
      details: details ?? this.details,
      periodStart: periodStart ?? this.periodStart,
      periodEnd: periodEnd ?? this.periodEnd,
      workstreamId: workstreamId ?? this.workstreamId,
      projectId: projectId ?? this.projectId,
      importance: importance ?? this.importance,
      origin: origin ?? this.origin,
      reviewState: reviewState ?? this.reviewState,
      reviewProposal: reviewProposal ?? this.reviewProposal,
      winStatus: winStatus ?? this.winStatus,
      retired: retired ?? this.retired,
      revision: revision ?? this.revision,
      createdAt: createdAt ?? this.createdAt,
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
    if (type.present) {
      map['type'] = Variable<String>(
        $FactsTable.$convertertype.toSql(type.value),
      );
    }
    if (statement.present) {
      map['statement'] = Variable<String>(statement.value);
    }
    if (details.present) {
      map['details'] = Variable<String>(details.value);
    }
    if (periodStart.present) {
      map['period_start'] = Variable<String>(periodStart.value);
    }
    if (periodEnd.present) {
      map['period_end'] = Variable<String>(periodEnd.value);
    }
    if (workstreamId.present) {
      map['workstream_id'] = Variable<String>(workstreamId.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (importance.present) {
      map['importance'] = Variable<double>(importance.value);
    }
    if (origin.present) {
      map['origin'] = Variable<String>(
        $FactsTable.$converterorigin.toSql(origin.value),
      );
    }
    if (reviewState.present) {
      map['review_state'] = Variable<String>(
        $FactsTable.$converterreviewState.toSql(reviewState.value),
      );
    }
    if (reviewProposal.present) {
      map['review_proposal'] = Variable<String>(reviewProposal.value);
    }
    if (winStatus.present) {
      map['win_status'] = Variable<String>(
        $FactsTable.$converterwinStatus.toSql(winStatus.value),
      );
    }
    if (retired.present) {
      map['retired'] = Variable<bool>(retired.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
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
    return (StringBuffer('FactsCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('statement: $statement, ')
          ..write('details: $details, ')
          ..write('periodStart: $periodStart, ')
          ..write('periodEnd: $periodEnd, ')
          ..write('workstreamId: $workstreamId, ')
          ..write('projectId: $projectId, ')
          ..write('importance: $importance, ')
          ..write('origin: $origin, ')
          ..write('reviewState: $reviewState, ')
          ..write('reviewProposal: $reviewProposal, ')
          ..write('winStatus: $winStatus, ')
          ..write('retired: $retired, ')
          ..write('revision: $revision, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FactRevisionsTable extends FactRevisions
    with TableInfo<$FactRevisionsTable, FactRevision> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FactRevisionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _factIdMeta = const VerificationMeta('factId');
  @override
  late final GeneratedColumn<String> factId = GeneratedColumn<String>(
    'fact_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES facts (id)',
    ),
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statementMeta = const VerificationMeta(
    'statement',
  );
  @override
  late final GeneratedColumn<String> statement = GeneratedColumn<String>(
    'statement',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _detailsMeta = const VerificationMeta(
    'details',
  );
  @override
  late final GeneratedColumn<String> details = GeneratedColumn<String>(
    'details',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<FactOrigin, String> origin =
      GeneratedColumn<String>(
        'origin',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<FactOrigin>($FactRevisionsTable.$converterorigin);
  static const VerificationMeta _changedByMeta = const VerificationMeta(
    'changedBy',
  );
  @override
  late final GeneratedColumn<String> changedBy = GeneratedColumn<String>(
    'changed_by',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _changedAtMeta = const VerificationMeta(
    'changedAt',
  );
  @override
  late final GeneratedColumn<DateTime> changedAt = GeneratedColumn<DateTime>(
    'changed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    factId,
    revision,
    statement,
    details,
    origin,
    changedBy,
    changedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'fact_revisions';
  @override
  VerificationContext validateIntegrity(
    Insertable<FactRevision> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('fact_id')) {
      context.handle(
        _factIdMeta,
        factId.isAcceptableOrUnknown(data['fact_id']!, _factIdMeta),
      );
    } else if (isInserting) {
      context.missing(_factIdMeta);
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    } else if (isInserting) {
      context.missing(_revisionMeta);
    }
    if (data.containsKey('statement')) {
      context.handle(
        _statementMeta,
        statement.isAcceptableOrUnknown(data['statement']!, _statementMeta),
      );
    } else if (isInserting) {
      context.missing(_statementMeta);
    }
    if (data.containsKey('details')) {
      context.handle(
        _detailsMeta,
        details.isAcceptableOrUnknown(data['details']!, _detailsMeta),
      );
    } else if (isInserting) {
      context.missing(_detailsMeta);
    }
    if (data.containsKey('changed_by')) {
      context.handle(
        _changedByMeta,
        changedBy.isAcceptableOrUnknown(data['changed_by']!, _changedByMeta),
      );
    } else if (isInserting) {
      context.missing(_changedByMeta);
    }
    if (data.containsKey('changed_at')) {
      context.handle(
        _changedAtMeta,
        changedAt.isAcceptableOrUnknown(data['changed_at']!, _changedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_changedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {factId, revision};
  @override
  FactRevision map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FactRevision(
      factId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fact_id'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      statement: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}statement'],
      )!,
      details: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}details'],
      )!,
      origin: $FactRevisionsTable.$converterorigin.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}origin'],
        )!,
      ),
      changedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}changed_by'],
      )!,
      changedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}changed_at'],
      )!,
    );
  }

  @override
  $FactRevisionsTable createAlias(String alias) {
    return $FactRevisionsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<FactOrigin, String, String> $converterorigin =
      const EnumNameConverter<FactOrigin>(FactOrigin.values);
}

class FactRevision extends DataClass implements Insertable<FactRevision> {
  final String factId;
  final int revision;
  final String statement;
  final String details;
  final FactOrigin origin;
  final String changedBy;
  final DateTime changedAt;
  const FactRevision({
    required this.factId,
    required this.revision,
    required this.statement,
    required this.details,
    required this.origin,
    required this.changedBy,
    required this.changedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['fact_id'] = Variable<String>(factId);
    map['revision'] = Variable<int>(revision);
    map['statement'] = Variable<String>(statement);
    map['details'] = Variable<String>(details);
    {
      map['origin'] = Variable<String>(
        $FactRevisionsTable.$converterorigin.toSql(origin),
      );
    }
    map['changed_by'] = Variable<String>(changedBy);
    map['changed_at'] = Variable<DateTime>(changedAt);
    return map;
  }

  FactRevisionsCompanion toCompanion(bool nullToAbsent) {
    return FactRevisionsCompanion(
      factId: Value(factId),
      revision: Value(revision),
      statement: Value(statement),
      details: Value(details),
      origin: Value(origin),
      changedBy: Value(changedBy),
      changedAt: Value(changedAt),
    );
  }

  factory FactRevision.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FactRevision(
      factId: serializer.fromJson<String>(json['factId']),
      revision: serializer.fromJson<int>(json['revision']),
      statement: serializer.fromJson<String>(json['statement']),
      details: serializer.fromJson<String>(json['details']),
      origin: $FactRevisionsTable.$converterorigin.fromJson(
        serializer.fromJson<String>(json['origin']),
      ),
      changedBy: serializer.fromJson<String>(json['changedBy']),
      changedAt: serializer.fromJson<DateTime>(json['changedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'factId': serializer.toJson<String>(factId),
      'revision': serializer.toJson<int>(revision),
      'statement': serializer.toJson<String>(statement),
      'details': serializer.toJson<String>(details),
      'origin': serializer.toJson<String>(
        $FactRevisionsTable.$converterorigin.toJson(origin),
      ),
      'changedBy': serializer.toJson<String>(changedBy),
      'changedAt': serializer.toJson<DateTime>(changedAt),
    };
  }

  FactRevision copyWith({
    String? factId,
    int? revision,
    String? statement,
    String? details,
    FactOrigin? origin,
    String? changedBy,
    DateTime? changedAt,
  }) => FactRevision(
    factId: factId ?? this.factId,
    revision: revision ?? this.revision,
    statement: statement ?? this.statement,
    details: details ?? this.details,
    origin: origin ?? this.origin,
    changedBy: changedBy ?? this.changedBy,
    changedAt: changedAt ?? this.changedAt,
  );
  FactRevision copyWithCompanion(FactRevisionsCompanion data) {
    return FactRevision(
      factId: data.factId.present ? data.factId.value : this.factId,
      revision: data.revision.present ? data.revision.value : this.revision,
      statement: data.statement.present ? data.statement.value : this.statement,
      details: data.details.present ? data.details.value : this.details,
      origin: data.origin.present ? data.origin.value : this.origin,
      changedBy: data.changedBy.present ? data.changedBy.value : this.changedBy,
      changedAt: data.changedAt.present ? data.changedAt.value : this.changedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FactRevision(')
          ..write('factId: $factId, ')
          ..write('revision: $revision, ')
          ..write('statement: $statement, ')
          ..write('details: $details, ')
          ..write('origin: $origin, ')
          ..write('changedBy: $changedBy, ')
          ..write('changedAt: $changedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    factId,
    revision,
    statement,
    details,
    origin,
    changedBy,
    changedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FactRevision &&
          other.factId == this.factId &&
          other.revision == this.revision &&
          other.statement == this.statement &&
          other.details == this.details &&
          other.origin == this.origin &&
          other.changedBy == this.changedBy &&
          other.changedAt == this.changedAt);
}

class FactRevisionsCompanion extends UpdateCompanion<FactRevision> {
  final Value<String> factId;
  final Value<int> revision;
  final Value<String> statement;
  final Value<String> details;
  final Value<FactOrigin> origin;
  final Value<String> changedBy;
  final Value<DateTime> changedAt;
  final Value<int> rowid;
  const FactRevisionsCompanion({
    this.factId = const Value.absent(),
    this.revision = const Value.absent(),
    this.statement = const Value.absent(),
    this.details = const Value.absent(),
    this.origin = const Value.absent(),
    this.changedBy = const Value.absent(),
    this.changedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FactRevisionsCompanion.insert({
    required String factId,
    required int revision,
    required String statement,
    required String details,
    required FactOrigin origin,
    required String changedBy,
    required DateTime changedAt,
    this.rowid = const Value.absent(),
  }) : factId = Value(factId),
       revision = Value(revision),
       statement = Value(statement),
       details = Value(details),
       origin = Value(origin),
       changedBy = Value(changedBy),
       changedAt = Value(changedAt);
  static Insertable<FactRevision> custom({
    Expression<String>? factId,
    Expression<int>? revision,
    Expression<String>? statement,
    Expression<String>? details,
    Expression<String>? origin,
    Expression<String>? changedBy,
    Expression<DateTime>? changedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (factId != null) 'fact_id': factId,
      if (revision != null) 'revision': revision,
      if (statement != null) 'statement': statement,
      if (details != null) 'details': details,
      if (origin != null) 'origin': origin,
      if (changedBy != null) 'changed_by': changedBy,
      if (changedAt != null) 'changed_at': changedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FactRevisionsCompanion copyWith({
    Value<String>? factId,
    Value<int>? revision,
    Value<String>? statement,
    Value<String>? details,
    Value<FactOrigin>? origin,
    Value<String>? changedBy,
    Value<DateTime>? changedAt,
    Value<int>? rowid,
  }) {
    return FactRevisionsCompanion(
      factId: factId ?? this.factId,
      revision: revision ?? this.revision,
      statement: statement ?? this.statement,
      details: details ?? this.details,
      origin: origin ?? this.origin,
      changedBy: changedBy ?? this.changedBy,
      changedAt: changedAt ?? this.changedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (factId.present) {
      map['fact_id'] = Variable<String>(factId.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (statement.present) {
      map['statement'] = Variable<String>(statement.value);
    }
    if (details.present) {
      map['details'] = Variable<String>(details.value);
    }
    if (origin.present) {
      map['origin'] = Variable<String>(
        $FactRevisionsTable.$converterorigin.toSql(origin.value),
      );
    }
    if (changedBy.present) {
      map['changed_by'] = Variable<String>(changedBy.value);
    }
    if (changedAt.present) {
      map['changed_at'] = Variable<DateTime>(changedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FactRevisionsCompanion(')
          ..write('factId: $factId, ')
          ..write('revision: $revision, ')
          ..write('statement: $statement, ')
          ..write('details: $details, ')
          ..write('origin: $origin, ')
          ..write('changedBy: $changedBy, ')
          ..write('changedAt: $changedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CitationsTable extends Citations
    with TableInfo<$CitationsTable, Citation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CitationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _factIdMeta = const VerificationMeta('factId');
  @override
  late final GeneratedColumn<String> factId = GeneratedColumn<String>(
    'fact_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES facts (id)',
    ),
  );
  static const VerificationMeta _payloadIdMeta = const VerificationMeta(
    'payloadId',
  );
  @override
  late final GeneratedColumn<String> payloadId = GeneratedColumn<String>(
    'payload_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES payloads (id)',
    ),
  );
  static const VerificationMeta _payloadRevisionMeta = const VerificationMeta(
    'payloadRevision',
  );
  @override
  late final GeneratedColumn<int> payloadRevision = GeneratedColumn<int>(
    'payload_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _locatorMeta = const VerificationMeta(
    'locator',
  );
  @override
  late final GeneratedColumn<String> locator = GeneratedColumn<String>(
    'locator',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    factId,
    payloadId,
    payloadRevision,
    locator,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'citations';
  @override
  VerificationContext validateIntegrity(
    Insertable<Citation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('fact_id')) {
      context.handle(
        _factIdMeta,
        factId.isAcceptableOrUnknown(data['fact_id']!, _factIdMeta),
      );
    } else if (isInserting) {
      context.missing(_factIdMeta);
    }
    if (data.containsKey('payload_id')) {
      context.handle(
        _payloadIdMeta,
        payloadId.isAcceptableOrUnknown(data['payload_id']!, _payloadIdMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadIdMeta);
    }
    if (data.containsKey('payload_revision')) {
      context.handle(
        _payloadRevisionMeta,
        payloadRevision.isAcceptableOrUnknown(
          data['payload_revision']!,
          _payloadRevisionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadRevisionMeta);
    }
    if (data.containsKey('locator')) {
      context.handle(
        _locatorMeta,
        locator.isAcceptableOrUnknown(data['locator']!, _locatorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {factId, payloadId};
  @override
  Citation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Citation(
      factId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fact_id'],
      )!,
      payloadId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_id'],
      )!,
      payloadRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}payload_revision'],
      )!,
      locator: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}locator'],
      ),
    );
  }

  @override
  $CitationsTable createAlias(String alias) {
    return $CitationsTable(attachedDatabase, alias);
  }
}

class Citation extends DataClass implements Insertable<Citation> {
  final String factId;
  final String payloadId;
  final int payloadRevision;
  final String? locator;
  const Citation({
    required this.factId,
    required this.payloadId,
    required this.payloadRevision,
    this.locator,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['fact_id'] = Variable<String>(factId);
    map['payload_id'] = Variable<String>(payloadId);
    map['payload_revision'] = Variable<int>(payloadRevision);
    if (!nullToAbsent || locator != null) {
      map['locator'] = Variable<String>(locator);
    }
    return map;
  }

  CitationsCompanion toCompanion(bool nullToAbsent) {
    return CitationsCompanion(
      factId: Value(factId),
      payloadId: Value(payloadId),
      payloadRevision: Value(payloadRevision),
      locator: locator == null && nullToAbsent
          ? const Value.absent()
          : Value(locator),
    );
  }

  factory Citation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Citation(
      factId: serializer.fromJson<String>(json['factId']),
      payloadId: serializer.fromJson<String>(json['payloadId']),
      payloadRevision: serializer.fromJson<int>(json['payloadRevision']),
      locator: serializer.fromJson<String?>(json['locator']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'factId': serializer.toJson<String>(factId),
      'payloadId': serializer.toJson<String>(payloadId),
      'payloadRevision': serializer.toJson<int>(payloadRevision),
      'locator': serializer.toJson<String?>(locator),
    };
  }

  Citation copyWith({
    String? factId,
    String? payloadId,
    int? payloadRevision,
    Value<String?> locator = const Value.absent(),
  }) => Citation(
    factId: factId ?? this.factId,
    payloadId: payloadId ?? this.payloadId,
    payloadRevision: payloadRevision ?? this.payloadRevision,
    locator: locator.present ? locator.value : this.locator,
  );
  Citation copyWithCompanion(CitationsCompanion data) {
    return Citation(
      factId: data.factId.present ? data.factId.value : this.factId,
      payloadId: data.payloadId.present ? data.payloadId.value : this.payloadId,
      payloadRevision: data.payloadRevision.present
          ? data.payloadRevision.value
          : this.payloadRevision,
      locator: data.locator.present ? data.locator.value : this.locator,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Citation(')
          ..write('factId: $factId, ')
          ..write('payloadId: $payloadId, ')
          ..write('payloadRevision: $payloadRevision, ')
          ..write('locator: $locator')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(factId, payloadId, payloadRevision, locator);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Citation &&
          other.factId == this.factId &&
          other.payloadId == this.payloadId &&
          other.payloadRevision == this.payloadRevision &&
          other.locator == this.locator);
}

class CitationsCompanion extends UpdateCompanion<Citation> {
  final Value<String> factId;
  final Value<String> payloadId;
  final Value<int> payloadRevision;
  final Value<String?> locator;
  final Value<int> rowid;
  const CitationsCompanion({
    this.factId = const Value.absent(),
    this.payloadId = const Value.absent(),
    this.payloadRevision = const Value.absent(),
    this.locator = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CitationsCompanion.insert({
    required String factId,
    required String payloadId,
    required int payloadRevision,
    this.locator = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : factId = Value(factId),
       payloadId = Value(payloadId),
       payloadRevision = Value(payloadRevision);
  static Insertable<Citation> custom({
    Expression<String>? factId,
    Expression<String>? payloadId,
    Expression<int>? payloadRevision,
    Expression<String>? locator,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (factId != null) 'fact_id': factId,
      if (payloadId != null) 'payload_id': payloadId,
      if (payloadRevision != null) 'payload_revision': payloadRevision,
      if (locator != null) 'locator': locator,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CitationsCompanion copyWith({
    Value<String>? factId,
    Value<String>? payloadId,
    Value<int>? payloadRevision,
    Value<String?>? locator,
    Value<int>? rowid,
  }) {
    return CitationsCompanion(
      factId: factId ?? this.factId,
      payloadId: payloadId ?? this.payloadId,
      payloadRevision: payloadRevision ?? this.payloadRevision,
      locator: locator ?? this.locator,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (factId.present) {
      map['fact_id'] = Variable<String>(factId.value);
    }
    if (payloadId.present) {
      map['payload_id'] = Variable<String>(payloadId.value);
    }
    if (payloadRevision.present) {
      map['payload_revision'] = Variable<int>(payloadRevision.value);
    }
    if (locator.present) {
      map['locator'] = Variable<String>(locator.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CitationsCompanion(')
          ..write('factId: $factId, ')
          ..write('payloadId: $payloadId, ')
          ..write('payloadRevision: $payloadRevision, ')
          ..write('locator: $locator, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CurationRulesTable extends CurationRules
    with TableInfo<$CurationRulesTable, CurationRule> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CurationRulesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _matchMeta = const VerificationMeta('match');
  @override
  late final GeneratedColumn<String> match = GeneratedColumn<String>(
    'match',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<CurationAction, String> action =
      GeneratedColumn<String>(
        'action',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<CurationAction>($CurationRulesTable.$converteraction);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<double> value = GeneratedColumn<double>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<int> priority = GeneratedColumn<int>(
    'priority',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    match,
    action,
    value,
    priority,
    enabled,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'curation_rules';
  @override
  VerificationContext validateIntegrity(
    Insertable<CurationRule> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('match')) {
      context.handle(
        _matchMeta,
        match.isAcceptableOrUnknown(data['match']!, _matchMeta),
      );
    } else if (isInserting) {
      context.missing(_matchMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CurationRule map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CurationRule(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      match: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}match'],
      )!,
      action: $CurationRulesTable.$converteraction.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}action'],
        )!,
      ),
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}value'],
      )!,
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}priority'],
      )!,
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
    );
  }

  @override
  $CurationRulesTable createAlias(String alias) {
    return $CurationRulesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<CurationAction, String, String> $converteraction =
      const EnumNameConverter<CurationAction>(CurationAction.values);
}

class CurationRule extends DataClass implements Insertable<CurationRule> {
  final String id;
  final String match;
  final CurationAction action;
  final double value;
  final int priority;
  final bool enabled;
  const CurationRule({
    required this.id,
    required this.match,
    required this.action,
    required this.value,
    required this.priority,
    required this.enabled,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['match'] = Variable<String>(match);
    {
      map['action'] = Variable<String>(
        $CurationRulesTable.$converteraction.toSql(action),
      );
    }
    map['value'] = Variable<double>(value);
    map['priority'] = Variable<int>(priority);
    map['enabled'] = Variable<bool>(enabled);
    return map;
  }

  CurationRulesCompanion toCompanion(bool nullToAbsent) {
    return CurationRulesCompanion(
      id: Value(id),
      match: Value(match),
      action: Value(action),
      value: Value(value),
      priority: Value(priority),
      enabled: Value(enabled),
    );
  }

  factory CurationRule.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CurationRule(
      id: serializer.fromJson<String>(json['id']),
      match: serializer.fromJson<String>(json['match']),
      action: $CurationRulesTable.$converteraction.fromJson(
        serializer.fromJson<String>(json['action']),
      ),
      value: serializer.fromJson<double>(json['value']),
      priority: serializer.fromJson<int>(json['priority']),
      enabled: serializer.fromJson<bool>(json['enabled']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'match': serializer.toJson<String>(match),
      'action': serializer.toJson<String>(
        $CurationRulesTable.$converteraction.toJson(action),
      ),
      'value': serializer.toJson<double>(value),
      'priority': serializer.toJson<int>(priority),
      'enabled': serializer.toJson<bool>(enabled),
    };
  }

  CurationRule copyWith({
    String? id,
    String? match,
    CurationAction? action,
    double? value,
    int? priority,
    bool? enabled,
  }) => CurationRule(
    id: id ?? this.id,
    match: match ?? this.match,
    action: action ?? this.action,
    value: value ?? this.value,
    priority: priority ?? this.priority,
    enabled: enabled ?? this.enabled,
  );
  CurationRule copyWithCompanion(CurationRulesCompanion data) {
    return CurationRule(
      id: data.id.present ? data.id.value : this.id,
      match: data.match.present ? data.match.value : this.match,
      action: data.action.present ? data.action.value : this.action,
      value: data.value.present ? data.value.value : this.value,
      priority: data.priority.present ? data.priority.value : this.priority,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CurationRule(')
          ..write('id: $id, ')
          ..write('match: $match, ')
          ..write('action: $action, ')
          ..write('value: $value, ')
          ..write('priority: $priority, ')
          ..write('enabled: $enabled')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, match, action, value, priority, enabled);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CurationRule &&
          other.id == this.id &&
          other.match == this.match &&
          other.action == this.action &&
          other.value == this.value &&
          other.priority == this.priority &&
          other.enabled == this.enabled);
}

class CurationRulesCompanion extends UpdateCompanion<CurationRule> {
  final Value<String> id;
  final Value<String> match;
  final Value<CurationAction> action;
  final Value<double> value;
  final Value<int> priority;
  final Value<bool> enabled;
  final Value<int> rowid;
  const CurationRulesCompanion({
    this.id = const Value.absent(),
    this.match = const Value.absent(),
    this.action = const Value.absent(),
    this.value = const Value.absent(),
    this.priority = const Value.absent(),
    this.enabled = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CurationRulesCompanion.insert({
    required String id,
    required String match,
    required CurationAction action,
    this.value = const Value.absent(),
    this.priority = const Value.absent(),
    this.enabled = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       match = Value(match),
       action = Value(action);
  static Insertable<CurationRule> custom({
    Expression<String>? id,
    Expression<String>? match,
    Expression<String>? action,
    Expression<double>? value,
    Expression<int>? priority,
    Expression<bool>? enabled,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (match != null) 'match': match,
      if (action != null) 'action': action,
      if (value != null) 'value': value,
      if (priority != null) 'priority': priority,
      if (enabled != null) 'enabled': enabled,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CurationRulesCompanion copyWith({
    Value<String>? id,
    Value<String>? match,
    Value<CurationAction>? action,
    Value<double>? value,
    Value<int>? priority,
    Value<bool>? enabled,
    Value<int>? rowid,
  }) {
    return CurationRulesCompanion(
      id: id ?? this.id,
      match: match ?? this.match,
      action: action ?? this.action,
      value: value ?? this.value,
      priority: priority ?? this.priority,
      enabled: enabled ?? this.enabled,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (match.present) {
      map['match'] = Variable<String>(match.value);
    }
    if (action.present) {
      map['action'] = Variable<String>(
        $CurationRulesTable.$converteraction.toSql(action.value),
      );
    }
    if (value.present) {
      map['value'] = Variable<double>(value.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CurationRulesCompanion(')
          ..write('id: $id, ')
          ..write('match: $match, ')
          ..write('action: $action, ')
          ..write('value: $value, ')
          ..write('priority: $priority, ')
          ..write('enabled: $enabled, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TemplatesTable extends Templates
    with TableInfo<$TemplatesTable, Template> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TemplatesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _periodKindsMeta = const VerificationMeta(
    'periodKinds',
  );
  @override
  late final GeneratedColumn<String> periodKinds = GeneratedColumn<String>(
    'period_kinds',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _promptMeta = const VerificationMeta('prompt');
  @override
  late final GeneratedColumn<String> prompt = GeneratedColumn<String>(
    'prompt',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _builtInMeta = const VerificationMeta(
    'builtIn',
  );
  @override
  late final GeneratedColumn<bool> builtIn = GeneratedColumn<bool>(
    'built_in',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("built_in" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    periodKinds,
    prompt,
    builtIn,
    version,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'templates';
  @override
  VerificationContext validateIntegrity(
    Insertable<Template> instance, {
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
    if (data.containsKey('period_kinds')) {
      context.handle(
        _periodKindsMeta,
        periodKinds.isAcceptableOrUnknown(
          data['period_kinds']!,
          _periodKindsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_periodKindsMeta);
    }
    if (data.containsKey('prompt')) {
      context.handle(
        _promptMeta,
        prompt.isAcceptableOrUnknown(data['prompt']!, _promptMeta),
      );
    } else if (isInserting) {
      context.missing(_promptMeta);
    }
    if (data.containsKey('built_in')) {
      context.handle(
        _builtInMeta,
        builtIn.isAcceptableOrUnknown(data['built_in']!, _builtInMeta),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Template map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Template(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      periodKinds: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}period_kinds'],
      )!,
      prompt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}prompt'],
      )!,
      builtIn: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}built_in'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
    );
  }

  @override
  $TemplatesTable createAlias(String alias) {
    return $TemplatesTable(attachedDatabase, alias);
  }
}

class Template extends DataClass implements Insertable<Template> {
  final String id;
  final String name;
  final String periodKinds;
  final String prompt;
  final bool builtIn;
  final int version;
  const Template({
    required this.id,
    required this.name,
    required this.periodKinds,
    required this.prompt,
    required this.builtIn,
    required this.version,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['period_kinds'] = Variable<String>(periodKinds);
    map['prompt'] = Variable<String>(prompt);
    map['built_in'] = Variable<bool>(builtIn);
    map['version'] = Variable<int>(version);
    return map;
  }

  TemplatesCompanion toCompanion(bool nullToAbsent) {
    return TemplatesCompanion(
      id: Value(id),
      name: Value(name),
      periodKinds: Value(periodKinds),
      prompt: Value(prompt),
      builtIn: Value(builtIn),
      version: Value(version),
    );
  }

  factory Template.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Template(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      periodKinds: serializer.fromJson<String>(json['periodKinds']),
      prompt: serializer.fromJson<String>(json['prompt']),
      builtIn: serializer.fromJson<bool>(json['builtIn']),
      version: serializer.fromJson<int>(json['version']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'periodKinds': serializer.toJson<String>(periodKinds),
      'prompt': serializer.toJson<String>(prompt),
      'builtIn': serializer.toJson<bool>(builtIn),
      'version': serializer.toJson<int>(version),
    };
  }

  Template copyWith({
    String? id,
    String? name,
    String? periodKinds,
    String? prompt,
    bool? builtIn,
    int? version,
  }) => Template(
    id: id ?? this.id,
    name: name ?? this.name,
    periodKinds: periodKinds ?? this.periodKinds,
    prompt: prompt ?? this.prompt,
    builtIn: builtIn ?? this.builtIn,
    version: version ?? this.version,
  );
  Template copyWithCompanion(TemplatesCompanion data) {
    return Template(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      periodKinds: data.periodKinds.present
          ? data.periodKinds.value
          : this.periodKinds,
      prompt: data.prompt.present ? data.prompt.value : this.prompt,
      builtIn: data.builtIn.present ? data.builtIn.value : this.builtIn,
      version: data.version.present ? data.version.value : this.version,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Template(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('periodKinds: $periodKinds, ')
          ..write('prompt: $prompt, ')
          ..write('builtIn: $builtIn, ')
          ..write('version: $version')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, periodKinds, prompt, builtIn, version);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Template &&
          other.id == this.id &&
          other.name == this.name &&
          other.periodKinds == this.periodKinds &&
          other.prompt == this.prompt &&
          other.builtIn == this.builtIn &&
          other.version == this.version);
}

class TemplatesCompanion extends UpdateCompanion<Template> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> periodKinds;
  final Value<String> prompt;
  final Value<bool> builtIn;
  final Value<int> version;
  final Value<int> rowid;
  const TemplatesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.periodKinds = const Value.absent(),
    this.prompt = const Value.absent(),
    this.builtIn = const Value.absent(),
    this.version = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TemplatesCompanion.insert({
    required String id,
    required String name,
    required String periodKinds,
    required String prompt,
    this.builtIn = const Value.absent(),
    this.version = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       periodKinds = Value(periodKinds),
       prompt = Value(prompt);
  static Insertable<Template> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? periodKinds,
    Expression<String>? prompt,
    Expression<bool>? builtIn,
    Expression<int>? version,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (periodKinds != null) 'period_kinds': periodKinds,
      if (prompt != null) 'prompt': prompt,
      if (builtIn != null) 'built_in': builtIn,
      if (version != null) 'version': version,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TemplatesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? periodKinds,
    Value<String>? prompt,
    Value<bool>? builtIn,
    Value<int>? version,
    Value<int>? rowid,
  }) {
    return TemplatesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      periodKinds: periodKinds ?? this.periodKinds,
      prompt: prompt ?? this.prompt,
      builtIn: builtIn ?? this.builtIn,
      version: version ?? this.version,
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
    if (periodKinds.present) {
      map['period_kinds'] = Variable<String>(periodKinds.value);
    }
    if (prompt.present) {
      map['prompt'] = Variable<String>(prompt.value);
    }
    if (builtIn.present) {
      map['built_in'] = Variable<bool>(builtIn.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TemplatesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('periodKinds: $periodKinds, ')
          ..write('prompt: $prompt, ')
          ..write('builtIn: $builtIn, ')
          ..write('version: $version, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReportsTable extends Reports with TableInfo<$ReportsTable, Report> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReportsTable(this.attachedDatabase, [this._alias]);
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
  late final GeneratedColumnWithTypeConverter<PeriodKind, String> periodKind =
      GeneratedColumn<String>(
        'period_kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<PeriodKind>($ReportsTable.$converterperiodKind);
  static const VerificationMeta _periodStartMeta = const VerificationMeta(
    'periodStart',
  );
  @override
  late final GeneratedColumn<String> periodStart = GeneratedColumn<String>(
    'period_start',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _periodEndMeta = const VerificationMeta(
    'periodEnd',
  );
  @override
  late final GeneratedColumn<String> periodEnd = GeneratedColumn<String>(
    'period_end',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _templateIdMeta = const VerificationMeta(
    'templateId',
  );
  @override
  late final GeneratedColumn<String> templateId = GeneratedColumn<String>(
    'template_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES templates (id)',
    ),
  );
  static const VerificationMeta _lockedMeta = const VerificationMeta('locked');
  @override
  late final GeneratedColumn<bool> locked = GeneratedColumn<bool>(
    'locked',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("locked" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lockedSnapshotIdMeta = const VerificationMeta(
    'lockedSnapshotId',
  );
  @override
  late final GeneratedColumn<String> lockedSnapshotId = GeneratedColumn<String>(
    'locked_snapshot_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    periodKind,
    periodStart,
    periodEnd,
    templateId,
    locked,
    lockedSnapshotId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reports';
  @override
  VerificationContext validateIntegrity(
    Insertable<Report> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('period_start')) {
      context.handle(
        _periodStartMeta,
        periodStart.isAcceptableOrUnknown(
          data['period_start']!,
          _periodStartMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_periodStartMeta);
    }
    if (data.containsKey('period_end')) {
      context.handle(
        _periodEndMeta,
        periodEnd.isAcceptableOrUnknown(data['period_end']!, _periodEndMeta),
      );
    } else if (isInserting) {
      context.missing(_periodEndMeta);
    }
    if (data.containsKey('template_id')) {
      context.handle(
        _templateIdMeta,
        templateId.isAcceptableOrUnknown(data['template_id']!, _templateIdMeta),
      );
    } else if (isInserting) {
      context.missing(_templateIdMeta);
    }
    if (data.containsKey('locked')) {
      context.handle(
        _lockedMeta,
        locked.isAcceptableOrUnknown(data['locked']!, _lockedMeta),
      );
    }
    if (data.containsKey('locked_snapshot_id')) {
      context.handle(
        _lockedSnapshotIdMeta,
        lockedSnapshotId.isAcceptableOrUnknown(
          data['locked_snapshot_id']!,
          _lockedSnapshotIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Report map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Report(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      periodKind: $ReportsTable.$converterperiodKind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}period_kind'],
        )!,
      ),
      periodStart: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}period_start'],
      )!,
      periodEnd: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}period_end'],
      )!,
      templateId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}template_id'],
      )!,
      locked: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}locked'],
      )!,
      lockedSnapshotId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}locked_snapshot_id'],
      ),
    );
  }

  @override
  $ReportsTable createAlias(String alias) {
    return $ReportsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<PeriodKind, String, String> $converterperiodKind =
      const EnumNameConverter<PeriodKind>(PeriodKind.values);
}

class Report extends DataClass implements Insertable<Report> {
  final String id;
  final PeriodKind periodKind;
  final String periodStart;
  final String periodEnd;
  final String templateId;
  final bool locked;
  final String? lockedSnapshotId;
  const Report({
    required this.id,
    required this.periodKind,
    required this.periodStart,
    required this.periodEnd,
    required this.templateId,
    required this.locked,
    this.lockedSnapshotId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    {
      map['period_kind'] = Variable<String>(
        $ReportsTable.$converterperiodKind.toSql(periodKind),
      );
    }
    map['period_start'] = Variable<String>(periodStart);
    map['period_end'] = Variable<String>(periodEnd);
    map['template_id'] = Variable<String>(templateId);
    map['locked'] = Variable<bool>(locked);
    if (!nullToAbsent || lockedSnapshotId != null) {
      map['locked_snapshot_id'] = Variable<String>(lockedSnapshotId);
    }
    return map;
  }

  ReportsCompanion toCompanion(bool nullToAbsent) {
    return ReportsCompanion(
      id: Value(id),
      periodKind: Value(periodKind),
      periodStart: Value(periodStart),
      periodEnd: Value(periodEnd),
      templateId: Value(templateId),
      locked: Value(locked),
      lockedSnapshotId: lockedSnapshotId == null && nullToAbsent
          ? const Value.absent()
          : Value(lockedSnapshotId),
    );
  }

  factory Report.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Report(
      id: serializer.fromJson<String>(json['id']),
      periodKind: $ReportsTable.$converterperiodKind.fromJson(
        serializer.fromJson<String>(json['periodKind']),
      ),
      periodStart: serializer.fromJson<String>(json['periodStart']),
      periodEnd: serializer.fromJson<String>(json['periodEnd']),
      templateId: serializer.fromJson<String>(json['templateId']),
      locked: serializer.fromJson<bool>(json['locked']),
      lockedSnapshotId: serializer.fromJson<String?>(json['lockedSnapshotId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'periodKind': serializer.toJson<String>(
        $ReportsTable.$converterperiodKind.toJson(periodKind),
      ),
      'periodStart': serializer.toJson<String>(periodStart),
      'periodEnd': serializer.toJson<String>(periodEnd),
      'templateId': serializer.toJson<String>(templateId),
      'locked': serializer.toJson<bool>(locked),
      'lockedSnapshotId': serializer.toJson<String?>(lockedSnapshotId),
    };
  }

  Report copyWith({
    String? id,
    PeriodKind? periodKind,
    String? periodStart,
    String? periodEnd,
    String? templateId,
    bool? locked,
    Value<String?> lockedSnapshotId = const Value.absent(),
  }) => Report(
    id: id ?? this.id,
    periodKind: periodKind ?? this.periodKind,
    periodStart: periodStart ?? this.periodStart,
    periodEnd: periodEnd ?? this.periodEnd,
    templateId: templateId ?? this.templateId,
    locked: locked ?? this.locked,
    lockedSnapshotId: lockedSnapshotId.present
        ? lockedSnapshotId.value
        : this.lockedSnapshotId,
  );
  Report copyWithCompanion(ReportsCompanion data) {
    return Report(
      id: data.id.present ? data.id.value : this.id,
      periodKind: data.periodKind.present
          ? data.periodKind.value
          : this.periodKind,
      periodStart: data.periodStart.present
          ? data.periodStart.value
          : this.periodStart,
      periodEnd: data.periodEnd.present ? data.periodEnd.value : this.periodEnd,
      templateId: data.templateId.present
          ? data.templateId.value
          : this.templateId,
      locked: data.locked.present ? data.locked.value : this.locked,
      lockedSnapshotId: data.lockedSnapshotId.present
          ? data.lockedSnapshotId.value
          : this.lockedSnapshotId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Report(')
          ..write('id: $id, ')
          ..write('periodKind: $periodKind, ')
          ..write('periodStart: $periodStart, ')
          ..write('periodEnd: $periodEnd, ')
          ..write('templateId: $templateId, ')
          ..write('locked: $locked, ')
          ..write('lockedSnapshotId: $lockedSnapshotId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    periodKind,
    periodStart,
    periodEnd,
    templateId,
    locked,
    lockedSnapshotId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Report &&
          other.id == this.id &&
          other.periodKind == this.periodKind &&
          other.periodStart == this.periodStart &&
          other.periodEnd == this.periodEnd &&
          other.templateId == this.templateId &&
          other.locked == this.locked &&
          other.lockedSnapshotId == this.lockedSnapshotId);
}

class ReportsCompanion extends UpdateCompanion<Report> {
  final Value<String> id;
  final Value<PeriodKind> periodKind;
  final Value<String> periodStart;
  final Value<String> periodEnd;
  final Value<String> templateId;
  final Value<bool> locked;
  final Value<String?> lockedSnapshotId;
  final Value<int> rowid;
  const ReportsCompanion({
    this.id = const Value.absent(),
    this.periodKind = const Value.absent(),
    this.periodStart = const Value.absent(),
    this.periodEnd = const Value.absent(),
    this.templateId = const Value.absent(),
    this.locked = const Value.absent(),
    this.lockedSnapshotId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReportsCompanion.insert({
    required String id,
    required PeriodKind periodKind,
    required String periodStart,
    required String periodEnd,
    required String templateId,
    this.locked = const Value.absent(),
    this.lockedSnapshotId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       periodKind = Value(periodKind),
       periodStart = Value(periodStart),
       periodEnd = Value(periodEnd),
       templateId = Value(templateId);
  static Insertable<Report> custom({
    Expression<String>? id,
    Expression<String>? periodKind,
    Expression<String>? periodStart,
    Expression<String>? periodEnd,
    Expression<String>? templateId,
    Expression<bool>? locked,
    Expression<String>? lockedSnapshotId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (periodKind != null) 'period_kind': periodKind,
      if (periodStart != null) 'period_start': periodStart,
      if (periodEnd != null) 'period_end': periodEnd,
      if (templateId != null) 'template_id': templateId,
      if (locked != null) 'locked': locked,
      if (lockedSnapshotId != null) 'locked_snapshot_id': lockedSnapshotId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReportsCompanion copyWith({
    Value<String>? id,
    Value<PeriodKind>? periodKind,
    Value<String>? periodStart,
    Value<String>? periodEnd,
    Value<String>? templateId,
    Value<bool>? locked,
    Value<String?>? lockedSnapshotId,
    Value<int>? rowid,
  }) {
    return ReportsCompanion(
      id: id ?? this.id,
      periodKind: periodKind ?? this.periodKind,
      periodStart: periodStart ?? this.periodStart,
      periodEnd: periodEnd ?? this.periodEnd,
      templateId: templateId ?? this.templateId,
      locked: locked ?? this.locked,
      lockedSnapshotId: lockedSnapshotId ?? this.lockedSnapshotId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (periodKind.present) {
      map['period_kind'] = Variable<String>(
        $ReportsTable.$converterperiodKind.toSql(periodKind.value),
      );
    }
    if (periodStart.present) {
      map['period_start'] = Variable<String>(periodStart.value);
    }
    if (periodEnd.present) {
      map['period_end'] = Variable<String>(periodEnd.value);
    }
    if (templateId.present) {
      map['template_id'] = Variable<String>(templateId.value);
    }
    if (locked.present) {
      map['locked'] = Variable<bool>(locked.value);
    }
    if (lockedSnapshotId.present) {
      map['locked_snapshot_id'] = Variable<String>(lockedSnapshotId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReportsCompanion(')
          ..write('id: $id, ')
          ..write('periodKind: $periodKind, ')
          ..write('periodStart: $periodStart, ')
          ..write('periodEnd: $periodEnd, ')
          ..write('templateId: $templateId, ')
          ..write('locked: $locked, ')
          ..write('lockedSnapshotId: $lockedSnapshotId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReportSnapshotsTable extends ReportSnapshots
    with TableInfo<$ReportSnapshotsTable, ReportSnapshot> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReportSnapshotsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reportIdMeta = const VerificationMeta(
    'reportId',
  );
  @override
  late final GeneratedColumn<String> reportId = GeneratedColumn<String>(
    'report_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES reports (id)',
    ),
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
    'json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _markdownMeta = const VerificationMeta(
    'markdown',
  );
  @override
  late final GeneratedColumn<String> markdown = GeneratedColumn<String>(
    'markdown',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modelIdMeta = const VerificationMeta(
    'modelId',
  );
  @override
  late final GeneratedColumn<String> modelId = GeneratedColumn<String>(
    'model_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _styleInstructionMeta = const VerificationMeta(
    'styleInstruction',
  );
  @override
  late final GeneratedColumn<String> styleInstruction = GeneratedColumn<String>(
    'style_instruction',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _generatedAtMeta = const VerificationMeta(
    'generatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> generatedAt = GeneratedColumn<DateTime>(
    'generated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    reportId,
    version,
    json,
    markdown,
    modelId,
    styleInstruction,
    generatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'report_snapshots';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReportSnapshot> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('report_id')) {
      context.handle(
        _reportIdMeta,
        reportId.isAcceptableOrUnknown(data['report_id']!, _reportIdMeta),
      );
    } else if (isInserting) {
      context.missing(_reportIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('json')) {
      context.handle(
        _jsonMeta,
        json.isAcceptableOrUnknown(data['json']!, _jsonMeta),
      );
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    if (data.containsKey('markdown')) {
      context.handle(
        _markdownMeta,
        markdown.isAcceptableOrUnknown(data['markdown']!, _markdownMeta),
      );
    } else if (isInserting) {
      context.missing(_markdownMeta);
    }
    if (data.containsKey('model_id')) {
      context.handle(
        _modelIdMeta,
        modelId.isAcceptableOrUnknown(data['model_id']!, _modelIdMeta),
      );
    } else if (isInserting) {
      context.missing(_modelIdMeta);
    }
    if (data.containsKey('style_instruction')) {
      context.handle(
        _styleInstructionMeta,
        styleInstruction.isAcceptableOrUnknown(
          data['style_instruction']!,
          _styleInstructionMeta,
        ),
      );
    }
    if (data.containsKey('generated_at')) {
      context.handle(
        _generatedAtMeta,
        generatedAt.isAcceptableOrUnknown(
          data['generated_at']!,
          _generatedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_generatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReportSnapshot map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReportSnapshot(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      reportId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}report_id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      json: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}json'],
      )!,
      markdown: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}markdown'],
      )!,
      modelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model_id'],
      )!,
      styleInstruction: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}style_instruction'],
      ),
      generatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}generated_at'],
      )!,
    );
  }

  @override
  $ReportSnapshotsTable createAlias(String alias) {
    return $ReportSnapshotsTable(attachedDatabase, alias);
  }
}

class ReportSnapshot extends DataClass implements Insertable<ReportSnapshot> {
  final String id;
  final String reportId;
  final int version;
  final String json;
  final String markdown;
  final String modelId;
  final String? styleInstruction;
  final DateTime generatedAt;
  const ReportSnapshot({
    required this.id,
    required this.reportId,
    required this.version,
    required this.json,
    required this.markdown,
    required this.modelId,
    this.styleInstruction,
    required this.generatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['report_id'] = Variable<String>(reportId);
    map['version'] = Variable<int>(version);
    map['json'] = Variable<String>(json);
    map['markdown'] = Variable<String>(markdown);
    map['model_id'] = Variable<String>(modelId);
    if (!nullToAbsent || styleInstruction != null) {
      map['style_instruction'] = Variable<String>(styleInstruction);
    }
    map['generated_at'] = Variable<DateTime>(generatedAt);
    return map;
  }

  ReportSnapshotsCompanion toCompanion(bool nullToAbsent) {
    return ReportSnapshotsCompanion(
      id: Value(id),
      reportId: Value(reportId),
      version: Value(version),
      json: Value(json),
      markdown: Value(markdown),
      modelId: Value(modelId),
      styleInstruction: styleInstruction == null && nullToAbsent
          ? const Value.absent()
          : Value(styleInstruction),
      generatedAt: Value(generatedAt),
    );
  }

  factory ReportSnapshot.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReportSnapshot(
      id: serializer.fromJson<String>(json['id']),
      reportId: serializer.fromJson<String>(json['reportId']),
      version: serializer.fromJson<int>(json['version']),
      json: serializer.fromJson<String>(json['json']),
      markdown: serializer.fromJson<String>(json['markdown']),
      modelId: serializer.fromJson<String>(json['modelId']),
      styleInstruction: serializer.fromJson<String?>(json['styleInstruction']),
      generatedAt: serializer.fromJson<DateTime>(json['generatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'reportId': serializer.toJson<String>(reportId),
      'version': serializer.toJson<int>(version),
      'json': serializer.toJson<String>(json),
      'markdown': serializer.toJson<String>(markdown),
      'modelId': serializer.toJson<String>(modelId),
      'styleInstruction': serializer.toJson<String?>(styleInstruction),
      'generatedAt': serializer.toJson<DateTime>(generatedAt),
    };
  }

  ReportSnapshot copyWith({
    String? id,
    String? reportId,
    int? version,
    String? json,
    String? markdown,
    String? modelId,
    Value<String?> styleInstruction = const Value.absent(),
    DateTime? generatedAt,
  }) => ReportSnapshot(
    id: id ?? this.id,
    reportId: reportId ?? this.reportId,
    version: version ?? this.version,
    json: json ?? this.json,
    markdown: markdown ?? this.markdown,
    modelId: modelId ?? this.modelId,
    styleInstruction: styleInstruction.present
        ? styleInstruction.value
        : this.styleInstruction,
    generatedAt: generatedAt ?? this.generatedAt,
  );
  ReportSnapshot copyWithCompanion(ReportSnapshotsCompanion data) {
    return ReportSnapshot(
      id: data.id.present ? data.id.value : this.id,
      reportId: data.reportId.present ? data.reportId.value : this.reportId,
      version: data.version.present ? data.version.value : this.version,
      json: data.json.present ? data.json.value : this.json,
      markdown: data.markdown.present ? data.markdown.value : this.markdown,
      modelId: data.modelId.present ? data.modelId.value : this.modelId,
      styleInstruction: data.styleInstruction.present
          ? data.styleInstruction.value
          : this.styleInstruction,
      generatedAt: data.generatedAt.present
          ? data.generatedAt.value
          : this.generatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReportSnapshot(')
          ..write('id: $id, ')
          ..write('reportId: $reportId, ')
          ..write('version: $version, ')
          ..write('json: $json, ')
          ..write('markdown: $markdown, ')
          ..write('modelId: $modelId, ')
          ..write('styleInstruction: $styleInstruction, ')
          ..write('generatedAt: $generatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    reportId,
    version,
    json,
    markdown,
    modelId,
    styleInstruction,
    generatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReportSnapshot &&
          other.id == this.id &&
          other.reportId == this.reportId &&
          other.version == this.version &&
          other.json == this.json &&
          other.markdown == this.markdown &&
          other.modelId == this.modelId &&
          other.styleInstruction == this.styleInstruction &&
          other.generatedAt == this.generatedAt);
}

class ReportSnapshotsCompanion extends UpdateCompanion<ReportSnapshot> {
  final Value<String> id;
  final Value<String> reportId;
  final Value<int> version;
  final Value<String> json;
  final Value<String> markdown;
  final Value<String> modelId;
  final Value<String?> styleInstruction;
  final Value<DateTime> generatedAt;
  final Value<int> rowid;
  const ReportSnapshotsCompanion({
    this.id = const Value.absent(),
    this.reportId = const Value.absent(),
    this.version = const Value.absent(),
    this.json = const Value.absent(),
    this.markdown = const Value.absent(),
    this.modelId = const Value.absent(),
    this.styleInstruction = const Value.absent(),
    this.generatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReportSnapshotsCompanion.insert({
    required String id,
    required String reportId,
    required int version,
    required String json,
    required String markdown,
    required String modelId,
    this.styleInstruction = const Value.absent(),
    required DateTime generatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       reportId = Value(reportId),
       version = Value(version),
       json = Value(json),
       markdown = Value(markdown),
       modelId = Value(modelId),
       generatedAt = Value(generatedAt);
  static Insertable<ReportSnapshot> custom({
    Expression<String>? id,
    Expression<String>? reportId,
    Expression<int>? version,
    Expression<String>? json,
    Expression<String>? markdown,
    Expression<String>? modelId,
    Expression<String>? styleInstruction,
    Expression<DateTime>? generatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (reportId != null) 'report_id': reportId,
      if (version != null) 'version': version,
      if (json != null) 'json': json,
      if (markdown != null) 'markdown': markdown,
      if (modelId != null) 'model_id': modelId,
      if (styleInstruction != null) 'style_instruction': styleInstruction,
      if (generatedAt != null) 'generated_at': generatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReportSnapshotsCompanion copyWith({
    Value<String>? id,
    Value<String>? reportId,
    Value<int>? version,
    Value<String>? json,
    Value<String>? markdown,
    Value<String>? modelId,
    Value<String?>? styleInstruction,
    Value<DateTime>? generatedAt,
    Value<int>? rowid,
  }) {
    return ReportSnapshotsCompanion(
      id: id ?? this.id,
      reportId: reportId ?? this.reportId,
      version: version ?? this.version,
      json: json ?? this.json,
      markdown: markdown ?? this.markdown,
      modelId: modelId ?? this.modelId,
      styleInstruction: styleInstruction ?? this.styleInstruction,
      generatedAt: generatedAt ?? this.generatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (reportId.present) {
      map['report_id'] = Variable<String>(reportId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (markdown.present) {
      map['markdown'] = Variable<String>(markdown.value);
    }
    if (modelId.present) {
      map['model_id'] = Variable<String>(modelId.value);
    }
    if (styleInstruction.present) {
      map['style_instruction'] = Variable<String>(styleInstruction.value);
    }
    if (generatedAt.present) {
      map['generated_at'] = Variable<DateTime>(generatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReportSnapshotsCompanion(')
          ..write('id: $id, ')
          ..write('reportId: $reportId, ')
          ..write('version: $version, ')
          ..write('json: $json, ')
          ..write('markdown: $markdown, ')
          ..write('modelId: $modelId, ')
          ..write('styleInstruction: $styleInstruction, ')
          ..write('generatedAt: $generatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TaskRoutesTable extends TaskRoutes
    with TableInfo<$TaskRoutesTable, TaskRoute> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TaskRoutesTable(this.attachedDatabase, [this._alias]);
  @override
  late final GeneratedColumnWithTypeConverter<LlmRoute, String> route =
      GeneratedColumn<String>(
        'route',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<LlmRoute>($TaskRoutesTable.$converterroute);
  static const VerificationMeta _modelIdMeta = const VerificationMeta(
    'modelId',
  );
  @override
  late final GeneratedColumn<String> modelId = GeneratedColumn<String>(
    'model_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [route, modelId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'task_routes';
  @override
  VerificationContext validateIntegrity(
    Insertable<TaskRoute> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('model_id')) {
      context.handle(
        _modelIdMeta,
        modelId.isAcceptableOrUnknown(data['model_id']!, _modelIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {route};
  @override
  TaskRoute map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TaskRoute(
      route: $TaskRoutesTable.$converterroute.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}route'],
        )!,
      ),
      modelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model_id'],
      ),
    );
  }

  @override
  $TaskRoutesTable createAlias(String alias) {
    return $TaskRoutesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<LlmRoute, String, String> $converterroute =
      const EnumNameConverter<LlmRoute>(LlmRoute.values);
}

class TaskRoute extends DataClass implements Insertable<TaskRoute> {
  final LlmRoute route;
  final String? modelId;
  const TaskRoute({required this.route, this.modelId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    {
      map['route'] = Variable<String>(
        $TaskRoutesTable.$converterroute.toSql(route),
      );
    }
    if (!nullToAbsent || modelId != null) {
      map['model_id'] = Variable<String>(modelId);
    }
    return map;
  }

  TaskRoutesCompanion toCompanion(bool nullToAbsent) {
    return TaskRoutesCompanion(
      route: Value(route),
      modelId: modelId == null && nullToAbsent
          ? const Value.absent()
          : Value(modelId),
    );
  }

  factory TaskRoute.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TaskRoute(
      route: $TaskRoutesTable.$converterroute.fromJson(
        serializer.fromJson<String>(json['route']),
      ),
      modelId: serializer.fromJson<String?>(json['modelId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'route': serializer.toJson<String>(
        $TaskRoutesTable.$converterroute.toJson(route),
      ),
      'modelId': serializer.toJson<String?>(modelId),
    };
  }

  TaskRoute copyWith({
    LlmRoute? route,
    Value<String?> modelId = const Value.absent(),
  }) => TaskRoute(
    route: route ?? this.route,
    modelId: modelId.present ? modelId.value : this.modelId,
  );
  TaskRoute copyWithCompanion(TaskRoutesCompanion data) {
    return TaskRoute(
      route: data.route.present ? data.route.value : this.route,
      modelId: data.modelId.present ? data.modelId.value : this.modelId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TaskRoute(')
          ..write('route: $route, ')
          ..write('modelId: $modelId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(route, modelId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TaskRoute &&
          other.route == this.route &&
          other.modelId == this.modelId);
}

class TaskRoutesCompanion extends UpdateCompanion<TaskRoute> {
  final Value<LlmRoute> route;
  final Value<String?> modelId;
  final Value<int> rowid;
  const TaskRoutesCompanion({
    this.route = const Value.absent(),
    this.modelId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TaskRoutesCompanion.insert({
    required LlmRoute route,
    this.modelId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : route = Value(route);
  static Insertable<TaskRoute> custom({
    Expression<String>? route,
    Expression<String>? modelId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (route != null) 'route': route,
      if (modelId != null) 'model_id': modelId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TaskRoutesCompanion copyWith({
    Value<LlmRoute>? route,
    Value<String?>? modelId,
    Value<int>? rowid,
  }) {
    return TaskRoutesCompanion(
      route: route ?? this.route,
      modelId: modelId ?? this.modelId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (route.present) {
      map['route'] = Variable<String>(
        $TaskRoutesTable.$converterroute.toSql(route.value),
      );
    }
    if (modelId.present) {
      map['model_id'] = Variable<String>(modelId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TaskRoutesCompanion(')
          ..write('route: $route, ')
          ..write('modelId: $modelId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $JobsTable extends Jobs with TableInfo<$JobsTable, Job> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $JobsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _argsMeta = const VerificationMeta('args');
  @override
  late final GeneratedColumn<String> args = GeneratedColumn<String>(
    'args',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  @override
  late final GeneratedColumnWithTypeConverter<JobLane, String> lane =
      GeneratedColumn<String>(
        'lane',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<JobLane>($JobsTable.$converterlane);
  @override
  late final GeneratedColumnWithTypeConverter<JobState, String> state =
      GeneratedColumn<String>(
        'state',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<JobState>($JobsTable.$converterstate);
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _runAfterMeta = const VerificationMeta(
    'runAfter',
  );
  @override
  late final GeneratedColumn<DateTime> runAfter = GeneratedColumn<DateTime>(
    'run_after',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _leaseUntilMeta = const VerificationMeta(
    'leaseUntil',
  );
  @override
  late final GeneratedColumn<DateTime> leaseUntil = GeneratedColumn<DateTime>(
    'lease_until',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
    kind,
    args,
    lane,
    state,
    attempts,
    runAfter,
    leaseUntil,
    lastError,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'jobs';
  @override
  VerificationContext validateIntegrity(
    Insertable<Job> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('args')) {
      context.handle(
        _argsMeta,
        args.isAcceptableOrUnknown(data['args']!, _argsMeta),
      );
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('run_after')) {
      context.handle(
        _runAfterMeta,
        runAfter.isAcceptableOrUnknown(data['run_after']!, _runAfterMeta),
      );
    } else if (isInserting) {
      context.missing(_runAfterMeta);
    }
    if (data.containsKey('lease_until')) {
      context.handle(
        _leaseUntilMeta,
        leaseUntil.isAcceptableOrUnknown(data['lease_until']!, _leaseUntilMeta),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
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
  Job map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Job(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      args: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}args'],
      )!,
      lane: $JobsTable.$converterlane.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}lane'],
        )!,
      ),
      state: $JobsTable.$converterstate.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}state'],
        )!,
      ),
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      runAfter: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}run_after'],
      )!,
      leaseUntil: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}lease_until'],
      ),
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $JobsTable createAlias(String alias) {
    return $JobsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<JobLane, String, String> $converterlane =
      const EnumNameConverter<JobLane>(JobLane.values);
  static JsonTypeConverter2<JobState, String, String> $converterstate =
      const EnumNameConverter<JobState>(JobState.values);
}

class Job extends DataClass implements Insertable<Job> {
  final String id;
  final String kind;
  final String args;
  final JobLane lane;
  final JobState state;
  final int attempts;
  final DateTime runAfter;
  final DateTime? leaseUntil;
  final String? lastError;
  final DateTime createdAt;
  const Job({
    required this.id,
    required this.kind,
    required this.args,
    required this.lane,
    required this.state,
    required this.attempts,
    required this.runAfter,
    this.leaseUntil,
    this.lastError,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['kind'] = Variable<String>(kind);
    map['args'] = Variable<String>(args);
    {
      map['lane'] = Variable<String>($JobsTable.$converterlane.toSql(lane));
    }
    {
      map['state'] = Variable<String>($JobsTable.$converterstate.toSql(state));
    }
    map['attempts'] = Variable<int>(attempts);
    map['run_after'] = Variable<DateTime>(runAfter);
    if (!nullToAbsent || leaseUntil != null) {
      map['lease_until'] = Variable<DateTime>(leaseUntil);
    }
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  JobsCompanion toCompanion(bool nullToAbsent) {
    return JobsCompanion(
      id: Value(id),
      kind: Value(kind),
      args: Value(args),
      lane: Value(lane),
      state: Value(state),
      attempts: Value(attempts),
      runAfter: Value(runAfter),
      leaseUntil: leaseUntil == null && nullToAbsent
          ? const Value.absent()
          : Value(leaseUntil),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      createdAt: Value(createdAt),
    );
  }

  factory Job.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Job(
      id: serializer.fromJson<String>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      args: serializer.fromJson<String>(json['args']),
      lane: $JobsTable.$converterlane.fromJson(
        serializer.fromJson<String>(json['lane']),
      ),
      state: $JobsTable.$converterstate.fromJson(
        serializer.fromJson<String>(json['state']),
      ),
      attempts: serializer.fromJson<int>(json['attempts']),
      runAfter: serializer.fromJson<DateTime>(json['runAfter']),
      leaseUntil: serializer.fromJson<DateTime?>(json['leaseUntil']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String>(kind),
      'args': serializer.toJson<String>(args),
      'lane': serializer.toJson<String>($JobsTable.$converterlane.toJson(lane)),
      'state': serializer.toJson<String>(
        $JobsTable.$converterstate.toJson(state),
      ),
      'attempts': serializer.toJson<int>(attempts),
      'runAfter': serializer.toJson<DateTime>(runAfter),
      'leaseUntil': serializer.toJson<DateTime?>(leaseUntil),
      'lastError': serializer.toJson<String?>(lastError),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Job copyWith({
    String? id,
    String? kind,
    String? args,
    JobLane? lane,
    JobState? state,
    int? attempts,
    DateTime? runAfter,
    Value<DateTime?> leaseUntil = const Value.absent(),
    Value<String?> lastError = const Value.absent(),
    DateTime? createdAt,
  }) => Job(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    args: args ?? this.args,
    lane: lane ?? this.lane,
    state: state ?? this.state,
    attempts: attempts ?? this.attempts,
    runAfter: runAfter ?? this.runAfter,
    leaseUntil: leaseUntil.present ? leaseUntil.value : this.leaseUntil,
    lastError: lastError.present ? lastError.value : this.lastError,
    createdAt: createdAt ?? this.createdAt,
  );
  Job copyWithCompanion(JobsCompanion data) {
    return Job(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      args: data.args.present ? data.args.value : this.args,
      lane: data.lane.present ? data.lane.value : this.lane,
      state: data.state.present ? data.state.value : this.state,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      runAfter: data.runAfter.present ? data.runAfter.value : this.runAfter,
      leaseUntil: data.leaseUntil.present
          ? data.leaseUntil.value
          : this.leaseUntil,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Job(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('args: $args, ')
          ..write('lane: $lane, ')
          ..write('state: $state, ')
          ..write('attempts: $attempts, ')
          ..write('runAfter: $runAfter, ')
          ..write('leaseUntil: $leaseUntil, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    args,
    lane,
    state,
    attempts,
    runAfter,
    leaseUntil,
    lastError,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Job &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.args == this.args &&
          other.lane == this.lane &&
          other.state == this.state &&
          other.attempts == this.attempts &&
          other.runAfter == this.runAfter &&
          other.leaseUntil == this.leaseUntil &&
          other.lastError == this.lastError &&
          other.createdAt == this.createdAt);
}

class JobsCompanion extends UpdateCompanion<Job> {
  final Value<String> id;
  final Value<String> kind;
  final Value<String> args;
  final Value<JobLane> lane;
  final Value<JobState> state;
  final Value<int> attempts;
  final Value<DateTime> runAfter;
  final Value<DateTime?> leaseUntil;
  final Value<String?> lastError;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const JobsCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.args = const Value.absent(),
    this.lane = const Value.absent(),
    this.state = const Value.absent(),
    this.attempts = const Value.absent(),
    this.runAfter = const Value.absent(),
    this.leaseUntil = const Value.absent(),
    this.lastError = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  JobsCompanion.insert({
    required String id,
    required String kind,
    this.args = const Value.absent(),
    required JobLane lane,
    required JobState state,
    this.attempts = const Value.absent(),
    required DateTime runAfter,
    this.leaseUntil = const Value.absent(),
    this.lastError = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       lane = Value(lane),
       state = Value(state),
       runAfter = Value(runAfter),
       createdAt = Value(createdAt);
  static Insertable<Job> custom({
    Expression<String>? id,
    Expression<String>? kind,
    Expression<String>? args,
    Expression<String>? lane,
    Expression<String>? state,
    Expression<int>? attempts,
    Expression<DateTime>? runAfter,
    Expression<DateTime>? leaseUntil,
    Expression<String>? lastError,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (args != null) 'args': args,
      if (lane != null) 'lane': lane,
      if (state != null) 'state': state,
      if (attempts != null) 'attempts': attempts,
      if (runAfter != null) 'run_after': runAfter,
      if (leaseUntil != null) 'lease_until': leaseUntil,
      if (lastError != null) 'last_error': lastError,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  JobsCompanion copyWith({
    Value<String>? id,
    Value<String>? kind,
    Value<String>? args,
    Value<JobLane>? lane,
    Value<JobState>? state,
    Value<int>? attempts,
    Value<DateTime>? runAfter,
    Value<DateTime?>? leaseUntil,
    Value<String?>? lastError,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return JobsCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      args: args ?? this.args,
      lane: lane ?? this.lane,
      state: state ?? this.state,
      attempts: attempts ?? this.attempts,
      runAfter: runAfter ?? this.runAfter,
      leaseUntil: leaseUntil ?? this.leaseUntil,
      lastError: lastError ?? this.lastError,
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
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (args.present) {
      map['args'] = Variable<String>(args.value);
    }
    if (lane.present) {
      map['lane'] = Variable<String>(
        $JobsTable.$converterlane.toSql(lane.value),
      );
    }
    if (state.present) {
      map['state'] = Variable<String>(
        $JobsTable.$converterstate.toSql(state.value),
      );
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (runAfter.present) {
      map['run_after'] = Variable<DateTime>(runAfter.value);
    }
    if (leaseUntil.present) {
      map['lease_until'] = Variable<DateTime>(leaseUntil.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
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
    return (StringBuffer('JobsCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('args: $args, ')
          ..write('lane: $lane, ')
          ..write('state: $state, ')
          ..write('attempts: $attempts, ')
          ..write('runAfter: $runAfter, ')
          ..write('leaseUntil: $leaseUntil, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SchedulesTable extends Schedules
    with TableInfo<$SchedulesTable, Schedule> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SchedulesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ruleMeta = const VerificationMeta('rule');
  @override
  late final GeneratedColumn<String> rule = GeneratedColumn<String>(
    'rule',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _lastRunAtMeta = const VerificationMeta(
    'lastRunAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastRunAt = GeneratedColumn<DateTime>(
    'last_run_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, kind, rule, enabled, lastRunAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'schedules';
  @override
  VerificationContext validateIntegrity(
    Insertable<Schedule> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('rule')) {
      context.handle(
        _ruleMeta,
        rule.isAcceptableOrUnknown(data['rule']!, _ruleMeta),
      );
    } else if (isInserting) {
      context.missing(_ruleMeta);
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    if (data.containsKey('last_run_at')) {
      context.handle(
        _lastRunAtMeta,
        lastRunAt.isAcceptableOrUnknown(data['last_run_at']!, _lastRunAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Schedule map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Schedule(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      rule: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rule'],
      )!,
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      lastRunAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_run_at'],
      ),
    );
  }

  @override
  $SchedulesTable createAlias(String alias) {
    return $SchedulesTable(attachedDatabase, alias);
  }
}

class Schedule extends DataClass implements Insertable<Schedule> {
  final String id;
  final String kind;
  final String rule;
  final bool enabled;
  final DateTime? lastRunAt;
  const Schedule({
    required this.id,
    required this.kind,
    required this.rule,
    required this.enabled,
    this.lastRunAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['kind'] = Variable<String>(kind);
    map['rule'] = Variable<String>(rule);
    map['enabled'] = Variable<bool>(enabled);
    if (!nullToAbsent || lastRunAt != null) {
      map['last_run_at'] = Variable<DateTime>(lastRunAt);
    }
    return map;
  }

  SchedulesCompanion toCompanion(bool nullToAbsent) {
    return SchedulesCompanion(
      id: Value(id),
      kind: Value(kind),
      rule: Value(rule),
      enabled: Value(enabled),
      lastRunAt: lastRunAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastRunAt),
    );
  }

  factory Schedule.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Schedule(
      id: serializer.fromJson<String>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      rule: serializer.fromJson<String>(json['rule']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      lastRunAt: serializer.fromJson<DateTime?>(json['lastRunAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String>(kind),
      'rule': serializer.toJson<String>(rule),
      'enabled': serializer.toJson<bool>(enabled),
      'lastRunAt': serializer.toJson<DateTime?>(lastRunAt),
    };
  }

  Schedule copyWith({
    String? id,
    String? kind,
    String? rule,
    bool? enabled,
    Value<DateTime?> lastRunAt = const Value.absent(),
  }) => Schedule(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    rule: rule ?? this.rule,
    enabled: enabled ?? this.enabled,
    lastRunAt: lastRunAt.present ? lastRunAt.value : this.lastRunAt,
  );
  Schedule copyWithCompanion(SchedulesCompanion data) {
    return Schedule(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      rule: data.rule.present ? data.rule.value : this.rule,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      lastRunAt: data.lastRunAt.present ? data.lastRunAt.value : this.lastRunAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Schedule(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('rule: $rule, ')
          ..write('enabled: $enabled, ')
          ..write('lastRunAt: $lastRunAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, kind, rule, enabled, lastRunAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Schedule &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.rule == this.rule &&
          other.enabled == this.enabled &&
          other.lastRunAt == this.lastRunAt);
}

class SchedulesCompanion extends UpdateCompanion<Schedule> {
  final Value<String> id;
  final Value<String> kind;
  final Value<String> rule;
  final Value<bool> enabled;
  final Value<DateTime?> lastRunAt;
  final Value<int> rowid;
  const SchedulesCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.rule = const Value.absent(),
    this.enabled = const Value.absent(),
    this.lastRunAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SchedulesCompanion.insert({
    required String id,
    required String kind,
    required String rule,
    this.enabled = const Value.absent(),
    this.lastRunAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       rule = Value(rule);
  static Insertable<Schedule> custom({
    Expression<String>? id,
    Expression<String>? kind,
    Expression<String>? rule,
    Expression<bool>? enabled,
    Expression<DateTime>? lastRunAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (rule != null) 'rule': rule,
      if (enabled != null) 'enabled': enabled,
      if (lastRunAt != null) 'last_run_at': lastRunAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SchedulesCompanion copyWith({
    Value<String>? id,
    Value<String>? kind,
    Value<String>? rule,
    Value<bool>? enabled,
    Value<DateTime?>? lastRunAt,
    Value<int>? rowid,
  }) {
    return SchedulesCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      rule: rule ?? this.rule,
      enabled: enabled ?? this.enabled,
      lastRunAt: lastRunAt ?? this.lastRunAt,
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
      map['kind'] = Variable<String>(kind.value);
    }
    if (rule.present) {
      map['rule'] = Variable<String>(rule.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (lastRunAt.present) {
      map['last_run_at'] = Variable<DateTime>(lastRunAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SchedulesCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('rule: $rule, ')
          ..write('enabled: $enabled, ')
          ..write('lastRunAt: $lastRunAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DependenciesTable extends Dependencies
    with TableInfo<$DependenciesTable, Dependency> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DependenciesTable(this.attachedDatabase, [this._alias]);
  @override
  late final GeneratedColumnWithTypeConverter<EntityType, String>
  dependentType = GeneratedColumn<String>(
    'dependent_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<EntityType>($DependenciesTable.$converterdependentType);
  static const VerificationMeta _dependentIdMeta = const VerificationMeta(
    'dependentId',
  );
  @override
  late final GeneratedColumn<String> dependentId = GeneratedColumn<String>(
    'dependent_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dependentRevisionMeta = const VerificationMeta(
    'dependentRevision',
  );
  @override
  late final GeneratedColumn<int> dependentRevision = GeneratedColumn<int>(
    'dependent_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<EntityType, String> inputType =
      GeneratedColumn<String>(
        'input_type',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<EntityType>($DependenciesTable.$converterinputType);
  static const VerificationMeta _inputIdMeta = const VerificationMeta(
    'inputId',
  );
  @override
  late final GeneratedColumn<String> inputId = GeneratedColumn<String>(
    'input_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _inputRevisionMeta = const VerificationMeta(
    'inputRevision',
  );
  @override
  late final GeneratedColumn<int> inputRevision = GeneratedColumn<int>(
    'input_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    dependentType,
    dependentId,
    dependentRevision,
    inputType,
    inputId,
    inputRevision,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dependencies';
  @override
  VerificationContext validateIntegrity(
    Insertable<Dependency> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('dependent_id')) {
      context.handle(
        _dependentIdMeta,
        dependentId.isAcceptableOrUnknown(
          data['dependent_id']!,
          _dependentIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_dependentIdMeta);
    }
    if (data.containsKey('dependent_revision')) {
      context.handle(
        _dependentRevisionMeta,
        dependentRevision.isAcceptableOrUnknown(
          data['dependent_revision']!,
          _dependentRevisionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_dependentRevisionMeta);
    }
    if (data.containsKey('input_id')) {
      context.handle(
        _inputIdMeta,
        inputId.isAcceptableOrUnknown(data['input_id']!, _inputIdMeta),
      );
    } else if (isInserting) {
      context.missing(_inputIdMeta);
    }
    if (data.containsKey('input_revision')) {
      context.handle(
        _inputRevisionMeta,
        inputRevision.isAcceptableOrUnknown(
          data['input_revision']!,
          _inputRevisionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_inputRevisionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {
    dependentType,
    dependentId,
    inputType,
    inputId,
  };
  @override
  Dependency map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Dependency(
      dependentType: $DependenciesTable.$converterdependentType.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}dependent_type'],
        )!,
      ),
      dependentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dependent_id'],
      )!,
      dependentRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}dependent_revision'],
      )!,
      inputType: $DependenciesTable.$converterinputType.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}input_type'],
        )!,
      ),
      inputId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}input_id'],
      )!,
      inputRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}input_revision'],
      )!,
    );
  }

  @override
  $DependenciesTable createAlias(String alias) {
    return $DependenciesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<EntityType, String, String>
  $converterdependentType = const EnumNameConverter<EntityType>(
    EntityType.values,
  );
  static JsonTypeConverter2<EntityType, String, String> $converterinputType =
      const EnumNameConverter<EntityType>(EntityType.values);
}

class Dependency extends DataClass implements Insertable<Dependency> {
  final EntityType dependentType;
  final String dependentId;
  final int dependentRevision;
  final EntityType inputType;
  final String inputId;
  final int inputRevision;
  const Dependency({
    required this.dependentType,
    required this.dependentId,
    required this.dependentRevision,
    required this.inputType,
    required this.inputId,
    required this.inputRevision,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    {
      map['dependent_type'] = Variable<String>(
        $DependenciesTable.$converterdependentType.toSql(dependentType),
      );
    }
    map['dependent_id'] = Variable<String>(dependentId);
    map['dependent_revision'] = Variable<int>(dependentRevision);
    {
      map['input_type'] = Variable<String>(
        $DependenciesTable.$converterinputType.toSql(inputType),
      );
    }
    map['input_id'] = Variable<String>(inputId);
    map['input_revision'] = Variable<int>(inputRevision);
    return map;
  }

  DependenciesCompanion toCompanion(bool nullToAbsent) {
    return DependenciesCompanion(
      dependentType: Value(dependentType),
      dependentId: Value(dependentId),
      dependentRevision: Value(dependentRevision),
      inputType: Value(inputType),
      inputId: Value(inputId),
      inputRevision: Value(inputRevision),
    );
  }

  factory Dependency.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Dependency(
      dependentType: $DependenciesTable.$converterdependentType.fromJson(
        serializer.fromJson<String>(json['dependentType']),
      ),
      dependentId: serializer.fromJson<String>(json['dependentId']),
      dependentRevision: serializer.fromJson<int>(json['dependentRevision']),
      inputType: $DependenciesTable.$converterinputType.fromJson(
        serializer.fromJson<String>(json['inputType']),
      ),
      inputId: serializer.fromJson<String>(json['inputId']),
      inputRevision: serializer.fromJson<int>(json['inputRevision']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'dependentType': serializer.toJson<String>(
        $DependenciesTable.$converterdependentType.toJson(dependentType),
      ),
      'dependentId': serializer.toJson<String>(dependentId),
      'dependentRevision': serializer.toJson<int>(dependentRevision),
      'inputType': serializer.toJson<String>(
        $DependenciesTable.$converterinputType.toJson(inputType),
      ),
      'inputId': serializer.toJson<String>(inputId),
      'inputRevision': serializer.toJson<int>(inputRevision),
    };
  }

  Dependency copyWith({
    EntityType? dependentType,
    String? dependentId,
    int? dependentRevision,
    EntityType? inputType,
    String? inputId,
    int? inputRevision,
  }) => Dependency(
    dependentType: dependentType ?? this.dependentType,
    dependentId: dependentId ?? this.dependentId,
    dependentRevision: dependentRevision ?? this.dependentRevision,
    inputType: inputType ?? this.inputType,
    inputId: inputId ?? this.inputId,
    inputRevision: inputRevision ?? this.inputRevision,
  );
  Dependency copyWithCompanion(DependenciesCompanion data) {
    return Dependency(
      dependentType: data.dependentType.present
          ? data.dependentType.value
          : this.dependentType,
      dependentId: data.dependentId.present
          ? data.dependentId.value
          : this.dependentId,
      dependentRevision: data.dependentRevision.present
          ? data.dependentRevision.value
          : this.dependentRevision,
      inputType: data.inputType.present ? data.inputType.value : this.inputType,
      inputId: data.inputId.present ? data.inputId.value : this.inputId,
      inputRevision: data.inputRevision.present
          ? data.inputRevision.value
          : this.inputRevision,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Dependency(')
          ..write('dependentType: $dependentType, ')
          ..write('dependentId: $dependentId, ')
          ..write('dependentRevision: $dependentRevision, ')
          ..write('inputType: $inputType, ')
          ..write('inputId: $inputId, ')
          ..write('inputRevision: $inputRevision')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    dependentType,
    dependentId,
    dependentRevision,
    inputType,
    inputId,
    inputRevision,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Dependency &&
          other.dependentType == this.dependentType &&
          other.dependentId == this.dependentId &&
          other.dependentRevision == this.dependentRevision &&
          other.inputType == this.inputType &&
          other.inputId == this.inputId &&
          other.inputRevision == this.inputRevision);
}

class DependenciesCompanion extends UpdateCompanion<Dependency> {
  final Value<EntityType> dependentType;
  final Value<String> dependentId;
  final Value<int> dependentRevision;
  final Value<EntityType> inputType;
  final Value<String> inputId;
  final Value<int> inputRevision;
  final Value<int> rowid;
  const DependenciesCompanion({
    this.dependentType = const Value.absent(),
    this.dependentId = const Value.absent(),
    this.dependentRevision = const Value.absent(),
    this.inputType = const Value.absent(),
    this.inputId = const Value.absent(),
    this.inputRevision = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DependenciesCompanion.insert({
    required EntityType dependentType,
    required String dependentId,
    required int dependentRevision,
    required EntityType inputType,
    required String inputId,
    required int inputRevision,
    this.rowid = const Value.absent(),
  }) : dependentType = Value(dependentType),
       dependentId = Value(dependentId),
       dependentRevision = Value(dependentRevision),
       inputType = Value(inputType),
       inputId = Value(inputId),
       inputRevision = Value(inputRevision);
  static Insertable<Dependency> custom({
    Expression<String>? dependentType,
    Expression<String>? dependentId,
    Expression<int>? dependentRevision,
    Expression<String>? inputType,
    Expression<String>? inputId,
    Expression<int>? inputRevision,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (dependentType != null) 'dependent_type': dependentType,
      if (dependentId != null) 'dependent_id': dependentId,
      if (dependentRevision != null) 'dependent_revision': dependentRevision,
      if (inputType != null) 'input_type': inputType,
      if (inputId != null) 'input_id': inputId,
      if (inputRevision != null) 'input_revision': inputRevision,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DependenciesCompanion copyWith({
    Value<EntityType>? dependentType,
    Value<String>? dependentId,
    Value<int>? dependentRevision,
    Value<EntityType>? inputType,
    Value<String>? inputId,
    Value<int>? inputRevision,
    Value<int>? rowid,
  }) {
    return DependenciesCompanion(
      dependentType: dependentType ?? this.dependentType,
      dependentId: dependentId ?? this.dependentId,
      dependentRevision: dependentRevision ?? this.dependentRevision,
      inputType: inputType ?? this.inputType,
      inputId: inputId ?? this.inputId,
      inputRevision: inputRevision ?? this.inputRevision,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (dependentType.present) {
      map['dependent_type'] = Variable<String>(
        $DependenciesTable.$converterdependentType.toSql(dependentType.value),
      );
    }
    if (dependentId.present) {
      map['dependent_id'] = Variable<String>(dependentId.value);
    }
    if (dependentRevision.present) {
      map['dependent_revision'] = Variable<int>(dependentRevision.value);
    }
    if (inputType.present) {
      map['input_type'] = Variable<String>(
        $DependenciesTable.$converterinputType.toSql(inputType.value),
      );
    }
    if (inputId.present) {
      map['input_id'] = Variable<String>(inputId.value);
    }
    if (inputRevision.present) {
      map['input_revision'] = Variable<int>(inputRevision.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DependenciesCompanion(')
          ..write('dependentType: $dependentType, ')
          ..write('dependentId: $dependentId, ')
          ..write('dependentRevision: $dependentRevision, ')
          ..write('inputType: $inputType, ')
          ..write('inputId: $inputId, ')
          ..write('inputRevision: $inputRevision, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RecomputeQueueTable extends RecomputeQueue
    with TableInfo<$RecomputeQueueTable, RecomputeQueueData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecomputeQueueTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<EntityType, String> entityType =
      GeneratedColumn<String>(
        'entity_type',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<EntityType>($RecomputeQueueTable.$converterentityType);
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  @override
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
    'reason',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _enqueuedAtMeta = const VerificationMeta(
    'enqueuedAt',
  );
  @override
  late final GeneratedColumn<DateTime> enqueuedAt = GeneratedColumn<DateTime>(
    'enqueued_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    seq,
    entityType,
    entityId,
    reason,
    enqueuedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recompute_queue';
  @override
  VerificationContext validateIntegrity(
    Insertable<RecomputeQueueData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('reason')) {
      context.handle(
        _reasonMeta,
        reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta),
      );
    } else if (isInserting) {
      context.missing(_reasonMeta);
    }
    if (data.containsKey('enqueued_at')) {
      context.handle(
        _enqueuedAtMeta,
        enqueuedAt.isAcceptableOrUnknown(data['enqueued_at']!, _enqueuedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_enqueuedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {seq};
  @override
  RecomputeQueueData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecomputeQueueData(
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
      entityType: $RecomputeQueueTable.$converterentityType.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}entity_type'],
        )!,
      ),
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      reason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason'],
      )!,
      enqueuedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}enqueued_at'],
      )!,
    );
  }

  @override
  $RecomputeQueueTable createAlias(String alias) {
    return $RecomputeQueueTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<EntityType, String, String> $converterentityType =
      const EnumNameConverter<EntityType>(EntityType.values);
}

class RecomputeQueueData extends DataClass
    implements Insertable<RecomputeQueueData> {
  final int seq;
  final EntityType entityType;
  final String entityId;
  final String reason;
  final DateTime enqueuedAt;
  const RecomputeQueueData({
    required this.seq,
    required this.entityType,
    required this.entityId,
    required this.reason,
    required this.enqueuedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['seq'] = Variable<int>(seq);
    {
      map['entity_type'] = Variable<String>(
        $RecomputeQueueTable.$converterentityType.toSql(entityType),
      );
    }
    map['entity_id'] = Variable<String>(entityId);
    map['reason'] = Variable<String>(reason);
    map['enqueued_at'] = Variable<DateTime>(enqueuedAt);
    return map;
  }

  RecomputeQueueCompanion toCompanion(bool nullToAbsent) {
    return RecomputeQueueCompanion(
      seq: Value(seq),
      entityType: Value(entityType),
      entityId: Value(entityId),
      reason: Value(reason),
      enqueuedAt: Value(enqueuedAt),
    );
  }

  factory RecomputeQueueData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecomputeQueueData(
      seq: serializer.fromJson<int>(json['seq']),
      entityType: $RecomputeQueueTable.$converterentityType.fromJson(
        serializer.fromJson<String>(json['entityType']),
      ),
      entityId: serializer.fromJson<String>(json['entityId']),
      reason: serializer.fromJson<String>(json['reason']),
      enqueuedAt: serializer.fromJson<DateTime>(json['enqueuedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'seq': serializer.toJson<int>(seq),
      'entityType': serializer.toJson<String>(
        $RecomputeQueueTable.$converterentityType.toJson(entityType),
      ),
      'entityId': serializer.toJson<String>(entityId),
      'reason': serializer.toJson<String>(reason),
      'enqueuedAt': serializer.toJson<DateTime>(enqueuedAt),
    };
  }

  RecomputeQueueData copyWith({
    int? seq,
    EntityType? entityType,
    String? entityId,
    String? reason,
    DateTime? enqueuedAt,
  }) => RecomputeQueueData(
    seq: seq ?? this.seq,
    entityType: entityType ?? this.entityType,
    entityId: entityId ?? this.entityId,
    reason: reason ?? this.reason,
    enqueuedAt: enqueuedAt ?? this.enqueuedAt,
  );
  RecomputeQueueData copyWithCompanion(RecomputeQueueCompanion data) {
    return RecomputeQueueData(
      seq: data.seq.present ? data.seq.value : this.seq,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      reason: data.reason.present ? data.reason.value : this.reason,
      enqueuedAt: data.enqueuedAt.present
          ? data.enqueuedAt.value
          : this.enqueuedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecomputeQueueData(')
          ..write('seq: $seq, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('reason: $reason, ')
          ..write('enqueuedAt: $enqueuedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(seq, entityType, entityId, reason, enqueuedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecomputeQueueData &&
          other.seq == this.seq &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.reason == this.reason &&
          other.enqueuedAt == this.enqueuedAt);
}

class RecomputeQueueCompanion extends UpdateCompanion<RecomputeQueueData> {
  final Value<int> seq;
  final Value<EntityType> entityType;
  final Value<String> entityId;
  final Value<String> reason;
  final Value<DateTime> enqueuedAt;
  const RecomputeQueueCompanion({
    this.seq = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.reason = const Value.absent(),
    this.enqueuedAt = const Value.absent(),
  });
  RecomputeQueueCompanion.insert({
    this.seq = const Value.absent(),
    required EntityType entityType,
    required String entityId,
    required String reason,
    required DateTime enqueuedAt,
  }) : entityType = Value(entityType),
       entityId = Value(entityId),
       reason = Value(reason),
       enqueuedAt = Value(enqueuedAt);
  static Insertable<RecomputeQueueData> custom({
    Expression<int>? seq,
    Expression<String>? entityType,
    Expression<String>? entityId,
    Expression<String>? reason,
    Expression<DateTime>? enqueuedAt,
  }) {
    return RawValuesInsertable({
      if (seq != null) 'seq': seq,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (reason != null) 'reason': reason,
      if (enqueuedAt != null) 'enqueued_at': enqueuedAt,
    });
  }

  RecomputeQueueCompanion copyWith({
    Value<int>? seq,
    Value<EntityType>? entityType,
    Value<String>? entityId,
    Value<String>? reason,
    Value<DateTime>? enqueuedAt,
  }) {
    return RecomputeQueueCompanion(
      seq: seq ?? this.seq,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      reason: reason ?? this.reason,
      enqueuedAt: enqueuedAt ?? this.enqueuedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(
        $RecomputeQueueTable.$converterentityType.toSql(entityType.value),
      );
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (enqueuedAt.present) {
      map['enqueued_at'] = Variable<DateTime>(enqueuedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecomputeQueueCompanion(')
          ..write('seq: $seq, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('reason: $reason, ')
          ..write('enqueuedAt: $enqueuedAt')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings with TableInfo<$SettingsTable, Setting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
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
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<Setting> instance, {
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
  Setting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Setting(
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
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class Setting extends DataClass implements Insertable<Setting> {
  final String key;
  final String value;
  const Setting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(key: Value(key), value: Value(value));
  }

  factory Setting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Setting(
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

  Setting copyWith({String? key, String? value}) =>
      Setting(key: key ?? this.key, value: value ?? this.value);
  Setting copyWithCompanion(SettingsCompanion data) {
    return Setting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Setting(')
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
      (other is Setting && other.key == this.key && other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<Setting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<Setting> custom({
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

  SettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
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
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$ProfileDb extends GeneratedDatabase {
  _$ProfileDb(QueryExecutor e) : super(e);
  $ProfileDbManager get managers => $ProfileDbManager(this);
  late final $IdentitiesTable identities = $IdentitiesTable(this);
  late final $SourcesTable sources = $SourcesTable(this);
  late final $SyncCursorsTable syncCursors = $SyncCursorsTable(this);
  late final $ProjectsTable projects = $ProjectsTable(this);
  late final $EvidencesTable evidences = $EvidencesTable(this);
  late final $PayloadsTable payloads = $PayloadsTable(this);
  late final $PayloadRevisionsTable payloadRevisions = $PayloadRevisionsTable(
    this,
  );
  late final $AttachmentsTable attachments = $AttachmentsTable(this);
  late final $EnrichmentsTable enrichments = $EnrichmentsTable(this);
  late final $WorkstreamsTable workstreams = $WorkstreamsTable(this);
  late final $FactsTable facts = $FactsTable(this);
  late final $FactRevisionsTable factRevisions = $FactRevisionsTable(this);
  late final $CitationsTable citations = $CitationsTable(this);
  late final $CurationRulesTable curationRules = $CurationRulesTable(this);
  late final $TemplatesTable templates = $TemplatesTable(this);
  late final $ReportsTable reports = $ReportsTable(this);
  late final $ReportSnapshotsTable reportSnapshots = $ReportSnapshotsTable(
    this,
  );
  late final $TaskRoutesTable taskRoutes = $TaskRoutesTable(this);
  late final $JobsTable jobs = $JobsTable(this);
  late final $SchedulesTable schedules = $SchedulesTable(this);
  late final $DependenciesTable dependencies = $DependenciesTable(this);
  late final $RecomputeQueueTable recomputeQueue = $RecomputeQueueTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    identities,
    sources,
    syncCursors,
    projects,
    evidences,
    payloads,
    payloadRevisions,
    attachments,
    enrichments,
    workstreams,
    facts,
    factRevisions,
    citations,
    curationRules,
    templates,
    reports,
    reportSnapshots,
    taskRoutes,
    jobs,
    schedules,
    dependencies,
    recomputeQueue,
    settings,
  ];
}

typedef $$IdentitiesTableCreateCompanionBuilder = IdentitiesCompanion Function({
  required String id,
  required String kind,
  required String value,
  Value<int> rowid,
});
typedef $$IdentitiesTableUpdateCompanionBuilder = IdentitiesCompanion Function({
  Value<String> id,
  Value<String> kind,
  Value<String> value,
  Value<int> rowid,
});

class $$IdentitiesTableFilterComposer
    extends Composer<_$ProfileDb, $IdentitiesTable> {
  $$IdentitiesTableFilterComposer({
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

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$IdentitiesTableOrderingComposer
    extends Composer<_$ProfileDb, $IdentitiesTable> {
  $$IdentitiesTableOrderingComposer({
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

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$IdentitiesTableAnnotationComposer
    extends Composer<_$ProfileDb, $IdentitiesTable> {
  $$IdentitiesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$IdentitiesTableTableManager
    extends
        RootTableManager<
          _$ProfileDb,
          $IdentitiesTable,
          Identity,
          $$IdentitiesTableFilterComposer,
          $$IdentitiesTableOrderingComposer,
          $$IdentitiesTableAnnotationComposer,
          $$IdentitiesTableCreateCompanionBuilder,
          $$IdentitiesTableUpdateCompanionBuilder,
          (Identity, BaseReferences<_$ProfileDb, $IdentitiesTable, Identity>),
          Identity,
          PrefetchHooks Function()
        > {
  $$IdentitiesTableTableManager(_$ProfileDb db, $IdentitiesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$IdentitiesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$IdentitiesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$IdentitiesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => IdentitiesCompanion(
                id: id,
                kind: kind,
                value: value,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String kind,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => IdentitiesCompanion.insert(
                id: id,
                kind: kind,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$IdentitiesTable, Identity>(table),
                  BaseReferences<_$ProfileDb, $IdentitiesTable, Identity>(
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

typedef $$IdentitiesTableProcessedTableManager =
    ProcessedTableManager<
      _$ProfileDb,
      $IdentitiesTable,
      Identity,
      $$IdentitiesTableFilterComposer,
      $$IdentitiesTableOrderingComposer,
      $$IdentitiesTableAnnotationComposer,
      $$IdentitiesTableCreateCompanionBuilder,
      $$IdentitiesTableUpdateCompanionBuilder,
      (Identity, BaseReferences<_$ProfileDb, $IdentitiesTable, Identity>),
      Identity,
      PrefetchHooks Function()
    >;
typedef $$SourcesTableCreateCompanionBuilder = SourcesCompanion Function({
  required String id,
  required SourceKind kind,
  required String name,
  Value<String> config,
  Value<String?> credentialRef,
  Value<bool> enabled,
  Value<int> rowid,
});
typedef $$SourcesTableUpdateCompanionBuilder = SourcesCompanion Function({
  Value<String> id,
  Value<SourceKind> kind,
  Value<String> name,
  Value<String> config,
  Value<String?> credentialRef,
  Value<bool> enabled,
  Value<int> rowid,
});

final class $$SourcesTableReferences
    extends BaseReferences<_$ProfileDb, $SourcesTable, SourceRow> {
  $$SourcesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$SyncCursorsTable, List<SyncCursor>>
  _syncCursorsRefsTable(_$ProfileDb db) => MultiTypedResultKey.fromTable(
    db.syncCursors,
    aliasName: 'sources__id__sync_cursors__source_id',
  );

  $$SyncCursorsTableProcessedTableManager get syncCursorsRefs {
    final manager = $$SyncCursorsTableTableManager(
      $_db,
      $_db.syncCursors,
    ).filter((f) => f.sourceId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_syncCursorsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PayloadsTable, List<Payload>> _payloadsRefsTable(
    _$ProfileDb db,
  ) => MultiTypedResultKey.fromTable(
    db.payloads,
    aliasName: 'sources__id__payloads__source_id',
  );

  $$PayloadsTableProcessedTableManager get payloadsRefs {
    final manager = $$PayloadsTableTableManager(
      $_db,
      $_db.payloads,
    ).filter((f) => f.sourceId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_payloadsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SourcesTableFilterComposer
    extends Composer<_$ProfileDb, $SourcesTable> {
  $$SourcesTableFilterComposer({
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

  ColumnWithTypeConverterFilters<SourceKind, SourceKind, String> get kind =>
      $composableBuilder(
        column: $table.kind,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get config => $composableBuilder(
    column: $table.config,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get credentialRef => $composableBuilder(
    column: $table.credentialRef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> syncCursorsRefs(
    Expression<bool> Function($$SyncCursorsTableFilterComposer f) f,
  ) {
    final $$SyncCursorsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.syncCursors,
      getReferencedColumn: (t) => t.sourceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SyncCursorsTableFilterComposer(
            $db: $db,
            $table: $db.syncCursors,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> payloadsRefs(
    Expression<bool> Function($$PayloadsTableFilterComposer f) f,
  ) {
    final $$PayloadsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.payloads,
      getReferencedColumn: (t) => t.sourceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PayloadsTableFilterComposer(
            $db: $db,
            $table: $db.payloads,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SourcesTableOrderingComposer
    extends Composer<_$ProfileDb, $SourcesTable> {
  $$SourcesTableOrderingComposer({
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

  ColumnOrderings<String> get config => $composableBuilder(
    column: $table.config,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get credentialRef => $composableBuilder(
    column: $table.credentialRef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SourcesTableAnnotationComposer
    extends Composer<_$ProfileDb, $SourcesTable> {
  $$SourcesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<SourceKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get config =>
      $composableBuilder(column: $table.config, builder: (column) => column);

  GeneratedColumn<String> get credentialRef => $composableBuilder(
    column: $table.credentialRef,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  Expression<T> syncCursorsRefs<T extends Object>(
    Expression<T> Function($$SyncCursorsTableAnnotationComposer a) f,
  ) {
    final $$SyncCursorsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.syncCursors,
      getReferencedColumn: (t) => t.sourceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SyncCursorsTableAnnotationComposer(
            $db: $db,
            $table: $db.syncCursors,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> payloadsRefs<T extends Object>(
    Expression<T> Function($$PayloadsTableAnnotationComposer a) f,
  ) {
    final $$PayloadsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.payloads,
      getReferencedColumn: (t) => t.sourceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PayloadsTableAnnotationComposer(
            $db: $db,
            $table: $db.payloads,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SourcesTableTableManager
    extends
        RootTableManager<
          _$ProfileDb,
          $SourcesTable,
          SourceRow,
          $$SourcesTableFilterComposer,
          $$SourcesTableOrderingComposer,
          $$SourcesTableAnnotationComposer,
          $$SourcesTableCreateCompanionBuilder,
          $$SourcesTableUpdateCompanionBuilder,
          (SourceRow, $$SourcesTableReferences),
          SourceRow,
          PrefetchHooks Function({bool syncCursorsRefs, bool payloadsRefs})
        > {
  $$SourcesTableTableManager(_$ProfileDb db, $SourcesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SourcesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SourcesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SourcesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<SourceKind> kind = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> config = const Value.absent(),
                Value<String?> credentialRef = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SourcesCompanion(
                id: id,
                kind: kind,
                name: name,
                config: config,
                credentialRef: credentialRef,
                enabled: enabled,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required SourceKind kind,
                required String name,
                Value<String> config = const Value.absent(),
                Value<String?> credentialRef = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SourcesCompanion.insert(
                id: id,
                kind: kind,
                name: name,
                config: config,
                credentialRef: credentialRef,
                enabled: enabled,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SourcesTable, SourceRow>(table),
                  $$SourcesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({syncCursorsRefs = false, payloadsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (syncCursorsRefs) db.syncCursors,
                    if (payloadsRefs) db.payloads,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (syncCursorsRefs)
                        await $_getPrefetchedDataByColumns<
                          SourceRow,
                          $SourcesTable,
                          SyncCursor,
                          $SyncCursorsTable
                        >(
                          currentTable: table,
                          referencedTable: $$SourcesTableReferences
                              ._syncCursorsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SourcesTableReferences(
                                db,
                                table,
                                p0,
                              ).syncCursorsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'source_id',
                          typedResults: items,
                        ),
                      if (payloadsRefs)
                        await $_getPrefetchedDataByColumns<
                          SourceRow,
                          $SourcesTable,
                          Payload,
                          $PayloadsTable
                        >(
                          currentTable: table,
                          referencedTable: $$SourcesTableReferences
                              ._payloadsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SourcesTableReferences(
                                db,
                                table,
                                p0,
                              ).payloadsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'source_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$SourcesTableProcessedTableManager =
    ProcessedTableManager<
      _$ProfileDb,
      $SourcesTable,
      SourceRow,
      $$SourcesTableFilterComposer,
      $$SourcesTableOrderingComposer,
      $$SourcesTableAnnotationComposer,
      $$SourcesTableCreateCompanionBuilder,
      $$SourcesTableUpdateCompanionBuilder,
      (SourceRow, $$SourcesTableReferences),
      SourceRow,
      PrefetchHooks Function({bool syncCursorsRefs, bool payloadsRefs})
    >;
typedef $$SyncCursorsTableCreateCompanionBuilder =
    SyncCursorsCompanion Function({
      required String sourceId,
      Value<String> scope,
      Value<String?> cursor,
      Value<DateTime?> lastSuccessAt,
      Value<String?> lastError,
      Value<int> rowid,
    });
typedef $$SyncCursorsTableUpdateCompanionBuilder =
    SyncCursorsCompanion Function({
      Value<String> sourceId,
      Value<String> scope,
      Value<String?> cursor,
      Value<DateTime?> lastSuccessAt,
      Value<String?> lastError,
      Value<int> rowid,
    });

final class $$SyncCursorsTableReferences
    extends BaseReferences<_$ProfileDb, $SyncCursorsTable, SyncCursor> {
  $$SyncCursorsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SourcesTable _sourceIdTable(_$ProfileDb db) =>
      db.sources.createAlias('sync_cursors__source_id__sources__id');

  $$SourcesTableProcessedTableManager get sourceId {
    final $_column = $_itemColumn<String>('source_id')!;

    final manager = $$SourcesTableTableManager(
      $_db,
      $_db.sources,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sourceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SyncCursorsTableFilterComposer
    extends Composer<_$ProfileDb, $SyncCursorsTable> {
  $$SyncCursorsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cursor => $composableBuilder(
    column: $table.cursor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSuccessAt => $composableBuilder(
    column: $table.lastSuccessAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  $$SourcesTableFilterComposer get sourceId {
    final $$SourcesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourcesTableFilterComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SyncCursorsTableOrderingComposer
    extends Composer<_$ProfileDb, $SyncCursorsTable> {
  $$SyncCursorsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cursor => $composableBuilder(
    column: $table.cursor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSuccessAt => $composableBuilder(
    column: $table.lastSuccessAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  $$SourcesTableOrderingComposer get sourceId {
    final $$SourcesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourcesTableOrderingComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SyncCursorsTableAnnotationComposer
    extends Composer<_$ProfileDb, $SyncCursorsTable> {
  $$SyncCursorsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);

  GeneratedColumn<String> get cursor =>
      $composableBuilder(column: $table.cursor, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSuccessAt => $composableBuilder(
    column: $table.lastSuccessAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  $$SourcesTableAnnotationComposer get sourceId {
    final $$SourcesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourcesTableAnnotationComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SyncCursorsTableTableManager
    extends
        RootTableManager<
          _$ProfileDb,
          $SyncCursorsTable,
          SyncCursor,
          $$SyncCursorsTableFilterComposer,
          $$SyncCursorsTableOrderingComposer,
          $$SyncCursorsTableAnnotationComposer,
          $$SyncCursorsTableCreateCompanionBuilder,
          $$SyncCursorsTableUpdateCompanionBuilder,
          (SyncCursor, $$SyncCursorsTableReferences),
          SyncCursor,
          PrefetchHooks Function({bool sourceId})
        > {
  $$SyncCursorsTableTableManager(_$ProfileDb db, $SyncCursorsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncCursorsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncCursorsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncCursorsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> sourceId = const Value.absent(),
                Value<String> scope = const Value.absent(),
                Value<String?> cursor = const Value.absent(),
                Value<DateTime?> lastSuccessAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncCursorsCompanion(
                sourceId: sourceId,
                scope: scope,
                cursor: cursor,
                lastSuccessAt: lastSuccessAt,
                lastError: lastError,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String sourceId,
                Value<String> scope = const Value.absent(),
                Value<String?> cursor = const Value.absent(),
                Value<DateTime?> lastSuccessAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncCursorsCompanion.insert(
                sourceId: sourceId,
                scope: scope,
                cursor: cursor,
                lastSuccessAt: lastSuccessAt,
                lastError: lastError,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncCursorsTable, SyncCursor>(table),
                  $$SyncCursorsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sourceId = false}) {
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
                    if (sourceId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.sourceId,
                        referencedTable: $$SyncCursorsTableReferences
                            ._sourceIdTable(db),
                        referencedColumn: $$SyncCursorsTableReferences
                            ._sourceIdTable(db)
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

typedef $$SyncCursorsTableProcessedTableManager =
    ProcessedTableManager<
      _$ProfileDb,
      $SyncCursorsTable,
      SyncCursor,
      $$SyncCursorsTableFilterComposer,
      $$SyncCursorsTableOrderingComposer,
      $$SyncCursorsTableAnnotationComposer,
      $$SyncCursorsTableCreateCompanionBuilder,
      $$SyncCursorsTableUpdateCompanionBuilder,
      (SyncCursor, $$SyncCursorsTableReferences),
      SyncCursor,
      PrefetchHooks Function({bool sourceId})
    >;
typedef $$ProjectsTableCreateCompanionBuilder = ProjectsCompanion Function({
  required String id,
  required String name,
  Value<String> colour,
  Value<bool> archived,
  Value<int> rowid,
});
typedef $$ProjectsTableUpdateCompanionBuilder = ProjectsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> colour,
  Value<bool> archived,
  Value<int> rowid,
});

final class $$ProjectsTableReferences
    extends BaseReferences<_$ProfileDb, $ProjectsTable, Project> {
  $$ProjectsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$EvidencesTable, List<Evidence>>
  _evidencesRefsTable(_$ProfileDb db) => MultiTypedResultKey.fromTable(
    db.evidences,
    aliasName: 'projects__id__evidences__project_id',
  );

  $$EvidencesTableProcessedTableManager get evidencesRefs {
    final manager = $$EvidencesTableTableManager(
      $_db,
      $_db.evidences,
    ).filter((f) => f.projectId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_evidencesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$WorkstreamsTable, List<Workstream>>
  _workstreamsRefsTable(_$ProfileDb db) => MultiTypedResultKey.fromTable(
    db.workstreams,
    aliasName: 'projects__id__workstreams__project_id',
  );

  $$WorkstreamsTableProcessedTableManager get workstreamsRefs {
    final manager = $$WorkstreamsTableTableManager(
      $_db,
      $_db.workstreams,
    ).filter((f) => f.projectId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_workstreamsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$FactsTable, List<Fact>> _factsRefsTable(
    _$ProfileDb db,
  ) => MultiTypedResultKey.fromTable(
    db.facts,
    aliasName: 'projects__id__facts__project_id',
  );

  $$FactsTableProcessedTableManager get factsRefs {
    final manager = $$FactsTableTableManager(
      $_db,
      $_db.facts,
    ).filter((f) => f.projectId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_factsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ProjectsTableFilterComposer
    extends Composer<_$ProfileDb, $ProjectsTable> {
  $$ProjectsTableFilterComposer({
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

  ColumnFilters<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> evidencesRefs(
    Expression<bool> Function($$EvidencesTableFilterComposer f) f,
  ) {
    final $$EvidencesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.evidences,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EvidencesTableFilterComposer(
            $db: $db,
            $table: $db.evidences,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> workstreamsRefs(
    Expression<bool> Function($$WorkstreamsTableFilterComposer f) f,
  ) {
    final $$WorkstreamsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.workstreams,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkstreamsTableFilterComposer(
            $db: $db,
            $table: $db.workstreams,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> factsRefs(
    Expression<bool> Function($$FactsTableFilterComposer f) f,
  ) {
    final $$FactsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.facts,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FactsTableFilterComposer(
            $db: $db,
            $table: $db.facts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProjectsTableOrderingComposer
    extends Composer<_$ProfileDb, $ProjectsTable> {
  $$ProjectsTableOrderingComposer({
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

  ColumnOrderings<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProjectsTableAnnotationComposer
    extends Composer<_$ProfileDb, $ProjectsTable> {
  $$ProjectsTableAnnotationComposer({
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

  GeneratedColumn<bool> get archived =>
      $composableBuilder(column: $table.archived, builder: (column) => column);

  Expression<T> evidencesRefs<T extends Object>(
    Expression<T> Function($$EvidencesTableAnnotationComposer a) f,
  ) {
    final $$EvidencesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.evidences,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EvidencesTableAnnotationComposer(
            $db: $db,
            $table: $db.evidences,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> workstreamsRefs<T extends Object>(
    Expression<T> Function($$WorkstreamsTableAnnotationComposer a) f,
  ) {
    final $$WorkstreamsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.workstreams,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkstreamsTableAnnotationComposer(
            $db: $db,
            $table: $db.workstreams,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> factsRefs<T extends Object>(
    Expression<T> Function($$FactsTableAnnotationComposer a) f,
  ) {
    final $$FactsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.facts,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FactsTableAnnotationComposer(
            $db: $db,
            $table: $db.facts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProjectsTableTableManager
    extends
        RootTableManager<
          _$ProfileDb,
          $ProjectsTable,
          Project,
          $$ProjectsTableFilterComposer,
          $$ProjectsTableOrderingComposer,
          $$ProjectsTableAnnotationComposer,
          $$ProjectsTableCreateCompanionBuilder,
          $$ProjectsTableUpdateCompanionBuilder,
          (Project, $$ProjectsTableReferences),
          Project,
          PrefetchHooks Function({
            bool evidencesRefs,
            bool workstreamsRefs,
            bool factsRefs,
          })
        > {
  $$ProjectsTableTableManager(_$ProfileDb db, $ProjectsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProjectsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProjectsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProjectsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> colour = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProjectsCompanion(
                id: id,
                name: name,
                colour: colour,
                archived: archived,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String> colour = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProjectsCompanion.insert(
                id: id,
                name: name,
                colour: colour,
                archived: archived,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ProjectsTable, Project>(table),
                  $$ProjectsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                evidencesRefs = false,
                workstreamsRefs = false,
                factsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (evidencesRefs) db.evidences,
                    if (workstreamsRefs) db.workstreams,
                    if (factsRefs) db.facts,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (evidencesRefs)
                        await $_getPrefetchedDataByColumns<
                          Project,
                          $ProjectsTable,
                          Evidence,
                          $EvidencesTable
                        >(
                          currentTable: table,
                          referencedTable: $$ProjectsTableReferences
                              ._evidencesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProjectsTableReferences(
                                db,
                                table,
                                p0,
                              ).evidencesRefs,
                          currentColumn: 'id',
                          referencedColumn: 'project_id',
                          typedResults: items,
                        ),
                      if (workstreamsRefs)
                        await $_getPrefetchedDataByColumns<
                          Project,
                          $ProjectsTable,
                          Workstream,
                          $WorkstreamsTable
                        >(
                          currentTable: table,
                          referencedTable: $$ProjectsTableReferences
                              ._workstreamsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProjectsTableReferences(
                                db,
                                table,
                                p0,
                              ).workstreamsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'project_id',
                          typedResults: items,
                        ),
                      if (factsRefs)
                        await $_getPrefetchedDataByColumns<
                          Project,
                          $ProjectsTable,
                          Fact,
                          $FactsTable
                        >(
                          currentTable: table,
                          referencedTable: $$ProjectsTableReferences
                              ._factsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProjectsTableReferences(
                                db,
                                table,
                                p0,
                              ).factsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'project_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ProjectsTableProcessedTableManager =
    ProcessedTableManager<
      _$ProfileDb,
      $ProjectsTable,
      Project,
      $$ProjectsTableFilterComposer,
      $$ProjectsTableOrderingComposer,
      $$ProjectsTableAnnotationComposer,
      $$ProjectsTableCreateCompanionBuilder,
      $$ProjectsTableUpdateCompanionBuilder,
      (Project, $$ProjectsTableReferences),
      Project,
      PrefetchHooks Function({
        bool evidencesRefs,
        bool workstreamsRefs,
        bool factsRefs,
      })
    >;
typedef $$EvidencesTableCreateCompanionBuilder = EvidencesCompanion Function({
  required String id,
  required DateTime occurredStart,
  Value<DateTime?> occurredEnd,
  required String day,
  required String title,
  Value<String?> projectId,
  Value<bool> starred,
  Value<bool> hidden,
  Value<double> importance,
  Value<String?> importanceReason,
  Value<ImportanceSetBy?> importanceSetBy,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$EvidencesTableUpdateCompanionBuilder = EvidencesCompanion Function({
  Value<String> id,
  Value<DateTime> occurredStart,
  Value<DateTime?> occurredEnd,
  Value<String> day,
  Value<String> title,
  Value<String?> projectId,
  Value<bool> starred,
  Value<bool> hidden,
  Value<double> importance,
  Value<String?> importanceReason,
  Value<ImportanceSetBy?> importanceSetBy,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

final class $$EvidencesTableReferences
    extends BaseReferences<_$ProfileDb, $EvidencesTable, Evidence> {
  $$EvidencesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProjectsTable _projectIdTable(_$ProfileDb db) =>
      db.projects.createAlias('evidences__project_id__projects__id');

  $$ProjectsTableProcessedTableManager? get projectId {
    final $_column = $_itemColumn<String>('project_id');
    if ($_column == null) return null;
    final manager = $$ProjectsTableTableManager(
      $_db,
      $_db.projects,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$PayloadsTable, List<Payload>> _payloadsRefsTable(
    _$ProfileDb db,
  ) => MultiTypedResultKey.fromTable(
    db.payloads,
    aliasName: 'evidences__id__payloads__evidence_id',
  );

  $$PayloadsTableProcessedTableManager get payloadsRefs {
    final manager = $$PayloadsTableTableManager(
      $_db,
      $_db.payloads,
    ).filter((f) => f.evidenceId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_payloadsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$EvidencesTableFilterComposer
    extends Composer<_$ProfileDb, $EvidencesTable> {
  $$EvidencesTableFilterComposer({
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

  ColumnFilters<DateTime> get occurredStart => $composableBuilder(
    column: $table.occurredStart,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get occurredEnd => $composableBuilder(
    column: $table.occurredEnd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get starred => $composableBuilder(
    column: $table.starred,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hidden => $composableBuilder(
    column: $table.hidden,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get importance => $composableBuilder(
    column: $table.importance,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get importanceReason => $composableBuilder(
    column: $table.importanceReason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ImportanceSetBy?, ImportanceSetBy, String>
  get importanceSetBy => $composableBuilder(
    column: $table.importanceSetBy,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableFilterComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> payloadsRefs(
    Expression<bool> Function($$PayloadsTableFilterComposer f) f,
  ) {
    final $$PayloadsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.payloads,
      getReferencedColumn: (t) => t.evidenceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PayloadsTableFilterComposer(
            $db: $db,
            $table: $db.payloads,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$EvidencesTableOrderingComposer
    extends Composer<_$ProfileDb, $EvidencesTable> {
  $$EvidencesTableOrderingComposer({
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

  ColumnOrderings<DateTime> get occurredStart => $composableBuilder(
    column: $table.occurredStart,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get occurredEnd => $composableBuilder(
    column: $table.occurredEnd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get starred => $composableBuilder(
    column: $table.starred,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hidden => $composableBuilder(
    column: $table.hidden,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get importance => $composableBuilder(
    column: $table.importance,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get importanceReason => $composableBuilder(
    column: $table.importanceReason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get importanceSetBy => $composableBuilder(
    column: $table.importanceSetBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableOrderingComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EvidencesTableAnnotationComposer
    extends Composer<_$ProfileDb, $EvidencesTable> {
  $$EvidencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get occurredStart => $composableBuilder(
    column: $table.occurredStart,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get occurredEnd => $composableBuilder(
    column: $table.occurredEnd,
    builder: (column) => column,
  );

  GeneratedColumn<String> get day =>
      $composableBuilder(column: $table.day, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<bool> get starred =>
      $composableBuilder(column: $table.starred, builder: (column) => column);

  GeneratedColumn<bool> get hidden =>
      $composableBuilder(column: $table.hidden, builder: (column) => column);

  GeneratedColumn<double> get importance => $composableBuilder(
    column: $table.importance,
    builder: (column) => column,
  );

  GeneratedColumn<String> get importanceReason => $composableBuilder(
    column: $table.importanceReason,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<ImportanceSetBy?, String>
  get importanceSetBy => $composableBuilder(
    column: $table.importanceSetBy,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$ProjectsTableAnnotationComposer get projectId {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> payloadsRefs<T extends Object>(
    Expression<T> Function($$PayloadsTableAnnotationComposer a) f,
  ) {
    final $$PayloadsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.payloads,
      getReferencedColumn: (t) => t.evidenceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PayloadsTableAnnotationComposer(
            $db: $db,
            $table: $db.payloads,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$EvidencesTableTableManager
    extends
        RootTableManager<
          _$ProfileDb,
          $EvidencesTable,
          Evidence,
          $$EvidencesTableFilterComposer,
          $$EvidencesTableOrderingComposer,
          $$EvidencesTableAnnotationComposer,
          $$EvidencesTableCreateCompanionBuilder,
          $$EvidencesTableUpdateCompanionBuilder,
          (Evidence, $$EvidencesTableReferences),
          Evidence,
          PrefetchHooks Function({bool projectId, bool payloadsRefs})
        > {
  $$EvidencesTableTableManager(_$ProfileDb db, $EvidencesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EvidencesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EvidencesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EvidencesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> occurredStart = const Value.absent(),
                Value<DateTime?> occurredEnd = const Value.absent(),
                Value<String> day = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> projectId = const Value.absent(),
                Value<bool> starred = const Value.absent(),
                Value<bool> hidden = const Value.absent(),
                Value<double> importance = const Value.absent(),
                Value<String?> importanceReason = const Value.absent(),
                Value<ImportanceSetBy?> importanceSetBy = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EvidencesCompanion(
                id: id,
                occurredStart: occurredStart,
                occurredEnd: occurredEnd,
                day: day,
                title: title,
                projectId: projectId,
                starred: starred,
                hidden: hidden,
                importance: importance,
                importanceReason: importanceReason,
                importanceSetBy: importanceSetBy,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required DateTime occurredStart,
                Value<DateTime?> occurredEnd = const Value.absent(),
                required String day,
                required String title,
                Value<String?> projectId = const Value.absent(),
                Value<bool> starred = const Value.absent(),
                Value<bool> hidden = const Value.absent(),
                Value<double> importance = const Value.absent(),
                Value<String?> importanceReason = const Value.absent(),
                Value<ImportanceSetBy?> importanceSetBy = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => EvidencesCompanion.insert(
                id: id,
                occurredStart: occurredStart,
                occurredEnd: occurredEnd,
                day: day,
                title: title,
                projectId: projectId,
                starred: starred,
                hidden: hidden,
                importance: importance,
                importanceReason: importanceReason,
                importanceSetBy: importanceSetBy,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EvidencesTable, Evidence>(table),
                  $$EvidencesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({projectId = false, payloadsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (payloadsRefs) db.payloads],
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
                    if (projectId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.projectId,
                        referencedTable: $$EvidencesTableReferences
                            ._projectIdTable(db),
                        referencedColumn: $$EvidencesTableReferences
                            ._projectIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (payloadsRefs)
                    await $_getPrefetchedDataByColumns<
                      Evidence,
                      $EvidencesTable,
                      Payload,
                      $PayloadsTable
                    >(
                      currentTable: table,
                      referencedTable: $$EvidencesTableReferences
                          ._payloadsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$EvidencesTableReferences(
                            db,
                            table,
                            p0,
                          ).payloadsRefs,
                      currentColumn: 'id',
                      referencedColumn: 'evidence_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$EvidencesTableProcessedTableManager =
    ProcessedTableManager<
      _$ProfileDb,
      $EvidencesTable,
      Evidence,
      $$EvidencesTableFilterComposer,
      $$EvidencesTableOrderingComposer,
      $$EvidencesTableAnnotationComposer,
      $$EvidencesTableCreateCompanionBuilder,
      $$EvidencesTableUpdateCompanionBuilder,
      (Evidence, $$EvidencesTableReferences),
      Evidence,
      PrefetchHooks Function({bool projectId, bool payloadsRefs})
    >;
typedef $$PayloadsTableCreateCompanionBuilder = PayloadsCompanion Function({
  required String id,
  required String evidenceId,
  required String sourceId,
  required PayloadKind kind,
  required String externalId,
  Value<String?> title,
  required String content,
  required String contentHash,
  Value<String?> groupKey,
  Value<int> revision,
  Value<DateTime?> tombstonedAt,
  Value<int> rowid,
});
typedef $$PayloadsTableUpdateCompanionBuilder = PayloadsCompanion Function({
  Value<String> id,
  Value<String> evidenceId,
  Value<String> sourceId,
  Value<PayloadKind> kind,
  Value<String> externalId,
  Value<String?> title,
  Value<String> content,
  Value<String> contentHash,
  Value<String?> groupKey,
  Value<int> revision,
  Value<DateTime?> tombstonedAt,
  Value<int> rowid,
});

final class $$PayloadsTableReferences
    extends BaseReferences<_$ProfileDb, $PayloadsTable, Payload> {
  $$PayloadsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $EvidencesTable _evidenceIdTable(_$ProfileDb db) =>
      db.evidences.createAlias('payloads__evidence_id__evidences__id');

  $$EvidencesTableProcessedTableManager get evidenceId {
    final $_column = $_itemColumn<String>('evidence_id')!;

    final manager = $$EvidencesTableTableManager(
      $_db,
      $_db.evidences,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_evidenceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $SourcesTable _sourceIdTable(_$ProfileDb db) =>
      db.sources.createAlias('payloads__source_id__sources__id');

  $$SourcesTableProcessedTableManager get sourceId {
    final $_column = $_itemColumn<String>('source_id')!;

    final manager = $$SourcesTableTableManager(
      $_db,
      $_db.sources,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sourceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$PayloadRevisionsTable, List<PayloadRevision>>
  _payloadRevisionsRefsTable(_$ProfileDb db) => MultiTypedResultKey.fromTable(
    db.payloadRevisions,
    aliasName: 'payloads__id__payload_revisions__payload_id',
  );

  $$PayloadRevisionsTableProcessedTableManager get payloadRevisionsRefs {
    final manager = $$PayloadRevisionsTableTableManager(
      $_db,
      $_db.payloadRevisions,
    ).filter((f) => f.payloadId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _payloadRevisionsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$AttachmentsTable, List<Attachment>>
  _attachmentsRefsTable(_$ProfileDb db) => MultiTypedResultKey.fromTable(
    db.attachments,
    aliasName: 'payloads__id__attachments__payload_id',
  );

  $$AttachmentsTableProcessedTableManager get attachmentsRefs {
    final manager = $$AttachmentsTableTableManager(
      $_db,
      $_db.attachments,
    ).filter((f) => f.payloadId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_attachmentsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$CitationsTable, List<Citation>>
  _citationsRefsTable(_$ProfileDb db) => MultiTypedResultKey.fromTable(
    db.citations,
    aliasName: 'payloads__id__citations__payload_id',
  );

  $$CitationsTableProcessedTableManager get citationsRefs {
    final manager = $$CitationsTableTableManager(
      $_db,
      $_db.citations,
    ).filter((f) => f.payloadId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_citationsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PayloadsTableFilterComposer
    extends Composer<_$ProfileDb, $PayloadsTable> {
  $$PayloadsTableFilterComposer({
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

  ColumnWithTypeConverterFilters<PayloadKind, PayloadKind, String> get kind =>
      $composableBuilder(
        column: $table.kind,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get externalId => $composableBuilder(
    column: $table.externalId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get groupKey => $composableBuilder(
    column: $table.groupKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get tombstonedAt => $composableBuilder(
    column: $table.tombstonedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$EvidencesTableFilterComposer get evidenceId {
    final $$EvidencesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.evidenceId,
      referencedTable: $db.evidences,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EvidencesTableFilterComposer(
            $db: $db,
            $table: $db.evidences,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SourcesTableFilterComposer get sourceId {
    final $$SourcesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourcesTableFilterComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> payloadRevisionsRefs(
    Expression<bool> Function($$PayloadRevisionsTableFilterComposer f) f,
  ) {
    final $$PayloadRevisionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.payloadRevisions,
      getReferencedColumn: (t) => t.payloadId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PayloadRevisionsTableFilterComposer(
            $db: $db,
            $table: $db.payloadRevisions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> attachmentsRefs(
    Expression<bool> Function($$AttachmentsTableFilterComposer f) f,
  ) {
    final $$AttachmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.attachments,
      getReferencedColumn: (t) => t.payloadId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttachmentsTableFilterComposer(
            $db: $db,
            $table: $db.attachments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> citationsRefs(
    Expression<bool> Function($$CitationsTableFilterComposer f) f,
  ) {
    final $$CitationsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.citations,
      getReferencedColumn: (t) => t.payloadId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CitationsTableFilterComposer(
            $db: $db,
            $table: $db.citations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PayloadsTableOrderingComposer
    extends Composer<_$ProfileDb, $PayloadsTable> {
  $$PayloadsTableOrderingComposer({
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

  ColumnOrderings<String> get externalId => $composableBuilder(
    column: $table.externalId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get groupKey => $composableBuilder(
    column: $table.groupKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get tombstonedAt => $composableBuilder(
    column: $table.tombstonedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$EvidencesTableOrderingComposer get evidenceId {
    final $$EvidencesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.evidenceId,
      referencedTable: $db.evidences,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EvidencesTableOrderingComposer(
            $db: $db,
            $table: $db.evidences,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SourcesTableOrderingComposer get sourceId {
    final $$SourcesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourcesTableOrderingComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PayloadsTableAnnotationComposer
    extends Composer<_$ProfileDb, $PayloadsTable> {
  $$PayloadsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<PayloadKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get externalId => $composableBuilder(
    column: $table.externalId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => column,
  );

  GeneratedColumn<String> get groupKey =>
      $composableBuilder(column: $table.groupKey, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<DateTime> get tombstonedAt => $composableBuilder(
    column: $table.tombstonedAt,
    builder: (column) => column,
  );

  $$EvidencesTableAnnotationComposer get evidenceId {
    final $$EvidencesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.evidenceId,
      referencedTable: $db.evidences,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EvidencesTableAnnotationComposer(
            $db: $db,
            $table: $db.evidences,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SourcesTableAnnotationComposer get sourceId {
    final $$SourcesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourcesTableAnnotationComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> payloadRevisionsRefs<T extends Object>(
    Expression<T> Function($$PayloadRevisionsTableAnnotationComposer a) f,
  ) {
    final $$PayloadRevisionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.payloadRevisions,
      getReferencedColumn: (t) => t.payloadId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PayloadRevisionsTableAnnotationComposer(
            $db: $db,
            $table: $db.payloadRevisions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> attachmentsRefs<T extends Object>(
    Expression<T> Function($$AttachmentsTableAnnotationComposer a) f,
  ) {
    final $$AttachmentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.attachments,
      getReferencedColumn: (t) => t.payloadId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttachmentsTableAnnotationComposer(
            $db: $db,
            $table: $db.attachments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> citationsRefs<T extends Object>(
    Expression<T> Function($$CitationsTableAnnotationComposer a) f,
  ) {
    final $$CitationsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.citations,
      getReferencedColumn: (t) => t.payloadId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CitationsTableAnnotationComposer(
            $db: $db,
            $table: $db.citations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PayloadsTableTableManager
    extends
        RootTableManager<
          _$ProfileDb,
          $PayloadsTable,
          Payload,
          $$PayloadsTableFilterComposer,
          $$PayloadsTableOrderingComposer,
          $$PayloadsTableAnnotationComposer,
          $$PayloadsTableCreateCompanionBuilder,
          $$PayloadsTableUpdateCompanionBuilder,
          (Payload, $$PayloadsTableReferences),
          Payload,
          PrefetchHooks Function({
            bool evidenceId,
            bool sourceId,
            bool payloadRevisionsRefs,
            bool attachmentsRefs,
            bool citationsRefs,
          })
        > {
  $$PayloadsTableTableManager(_$ProfileDb db, $PayloadsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PayloadsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PayloadsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PayloadsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> evidenceId = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                Value<PayloadKind> kind = const Value.absent(),
                Value<String> externalId = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String> contentHash = const Value.absent(),
                Value<String?> groupKey = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<DateTime?> tombstonedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PayloadsCompanion(
                id: id,
                evidenceId: evidenceId,
                sourceId: sourceId,
                kind: kind,
                externalId: externalId,
                title: title,
                content: content,
                contentHash: contentHash,
                groupKey: groupKey,
                revision: revision,
                tombstonedAt: tombstonedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String evidenceId,
                required String sourceId,
                required PayloadKind kind,
                required String externalId,
                Value<String?> title = const Value.absent(),
                required String content,
                required String contentHash,
                Value<String?> groupKey = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<DateTime?> tombstonedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PayloadsCompanion.insert(
                id: id,
                evidenceId: evidenceId,
                sourceId: sourceId,
                kind: kind,
                externalId: externalId,
                title: title,
                content: content,
                contentHash: contentHash,
                groupKey: groupKey,
                revision: revision,
                tombstonedAt: tombstonedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PayloadsTable, Payload>(table),
                  $$PayloadsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                evidenceId = false,
                sourceId = false,
                payloadRevisionsRefs = false,
                attachmentsRefs = false,
                citationsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (payloadRevisionsRefs) db.payloadRevisions,
                    if (attachmentsRefs) db.attachments,
                    if (citationsRefs) db.citations,
                  ],
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
                        if (evidenceId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.evidenceId,
                            referencedTable: $$PayloadsTableReferences
                                ._evidenceIdTable(db),
                            referencedColumn: $$PayloadsTableReferences
                                ._evidenceIdTable(db)
                                .id,
                          ) as T;
                        }
                        if (sourceId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.sourceId,
                            referencedTable: $$PayloadsTableReferences
                                ._sourceIdTable(db),
                            referencedColumn: $$PayloadsTableReferences
                                ._sourceIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (payloadRevisionsRefs)
                        await $_getPrefetchedDataByColumns<
                          Payload,
                          $PayloadsTable,
                          PayloadRevision,
                          $PayloadRevisionsTable
                        >(
                          currentTable: table,
                          referencedTable: $$PayloadsTableReferences
                              ._payloadRevisionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PayloadsTableReferences(
                                db,
                                table,
                                p0,
                              ).payloadRevisionsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'payload_id',
                          typedResults: items,
                        ),
                      if (attachmentsRefs)
                        await $_getPrefetchedDataByColumns<
                          Payload,
                          $PayloadsTable,
                          Attachment,
                          $AttachmentsTable
                        >(
                          currentTable: table,
                          referencedTable: $$PayloadsTableReferences
                              ._attachmentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PayloadsTableReferences(
                                db,
                                table,
                                p0,
                              ).attachmentsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'payload_id',
                          typedResults: items,
                        ),
                      if (citationsRefs)
                        await $_getPrefetchedDataByColumns<
                          Payload,
                          $PayloadsTable,
                          Citation,
                          $CitationsTable
                        >(
                          currentTable: table,
                          referencedTable: $$PayloadsTableReferences
                              ._citationsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PayloadsTableReferences(
                                db,
                                table,
                                p0,
                              ).citationsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'payload_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$PayloadsTableProcessedTableManager =
    ProcessedTableManager<
      _$ProfileDb,
      $PayloadsTable,
      Payload,
      $$PayloadsTableFilterComposer,
      $$PayloadsTableOrderingComposer,
      $$PayloadsTableAnnotationComposer,
      $$PayloadsTableCreateCompanionBuilder,
      $$PayloadsTableUpdateCompanionBuilder,
      (Payload, $$PayloadsTableReferences),
      Payload,
      PrefetchHooks Function({
        bool evidenceId,
        bool sourceId,
        bool payloadRevisionsRefs,
        bool attachmentsRefs,
        bool citationsRefs,
      })
    >;
typedef $$PayloadRevisionsTableCreateCompanionBuilder =
    PayloadRevisionsCompanion Function({
      required String payloadId,
      required int revision,
      required String content,
      required String contentHash,
      required RevisionCause cause,
      required DateTime observedAt,
      Value<int> rowid,
    });
typedef $$PayloadRevisionsTableUpdateCompanionBuilder =
    PayloadRevisionsCompanion Function({
      Value<String> payloadId,
      Value<int> revision,
      Value<String> content,
      Value<String> contentHash,
      Value<RevisionCause> cause,
      Value<DateTime> observedAt,
      Value<int> rowid,
    });

final class $$PayloadRevisionsTableReferences
    extends
        BaseReferences<_$ProfileDb, $PayloadRevisionsTable, PayloadRevision> {
  $$PayloadRevisionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PayloadsTable _payloadIdTable(_$ProfileDb db) =>
      db.payloads.createAlias('payload_revisions__payload_id__payloads__id');

  $$PayloadsTableProcessedTableManager get payloadId {
    final $_column = $_itemColumn<String>('payload_id')!;

    final manager = $$PayloadsTableTableManager(
      $_db,
      $_db.payloads,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_payloadIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PayloadRevisionsTableFilterComposer
    extends Composer<_$ProfileDb, $PayloadRevisionsTable> {
  $$PayloadRevisionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<RevisionCause, RevisionCause, String>
  get cause => $composableBuilder(
    column: $table.cause,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<DateTime> get observedAt => $composableBuilder(
    column: $table.observedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$PayloadsTableFilterComposer get payloadId {
    final $$PayloadsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.payloadId,
      referencedTable: $db.payloads,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PayloadsTableFilterComposer(
            $db: $db,
            $table: $db.payloads,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PayloadRevisionsTableOrderingComposer
    extends Composer<_$ProfileDb, $PayloadRevisionsTable> {
  $$PayloadRevisionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cause => $composableBuilder(
    column: $table.cause,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get observedAt => $composableBuilder(
    column: $table.observedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$PayloadsTableOrderingComposer get payloadId {
    final $$PayloadsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.payloadId,
      referencedTable: $db.payloads,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PayloadsTableOrderingComposer(
            $db: $db,
            $table: $db.payloads,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PayloadRevisionsTableAnnotationComposer
    extends Composer<_$ProfileDb, $PayloadRevisionsTable> {
  $$PayloadRevisionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<RevisionCause, String> get cause =>
      $composableBuilder(column: $table.cause, builder: (column) => column);

  GeneratedColumn<DateTime> get observedAt => $composableBuilder(
    column: $table.observedAt,
    builder: (column) => column,
  );

  $$PayloadsTableAnnotationComposer get payloadId {
    final $$PayloadsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.payloadId,
      referencedTable: $db.payloads,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PayloadsTableAnnotationComposer(
            $db: $db,
            $table: $db.payloads,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PayloadRevisionsTableTableManager
    extends
        RootTableManager<
          _$ProfileDb,
          $PayloadRevisionsTable,
          PayloadRevision,
          $$PayloadRevisionsTableFilterComposer,
          $$PayloadRevisionsTableOrderingComposer,
          $$PayloadRevisionsTableAnnotationComposer,
          $$PayloadRevisionsTableCreateCompanionBuilder,
          $$PayloadRevisionsTableUpdateCompanionBuilder,
          (PayloadRevision, $$PayloadRevisionsTableReferences),
          PayloadRevision,
          PrefetchHooks Function({bool payloadId})
        > {
  $$PayloadRevisionsTableTableManager(
    _$ProfileDb db,
    $PayloadRevisionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PayloadRevisionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PayloadRevisionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PayloadRevisionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> payloadId = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String> contentHash = const Value.absent(),
                Value<RevisionCause> cause = const Value.absent(),
                Value<DateTime> observedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PayloadRevisionsCompanion(
                payloadId: payloadId,
                revision: revision,
                content: content,
                contentHash: contentHash,
                cause: cause,
                observedAt: observedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String payloadId,
                required int revision,
                required String content,
                required String contentHash,
                required RevisionCause cause,
                required DateTime observedAt,
                Value<int> rowid = const Value.absent(),
              }) => PayloadRevisionsCompanion.insert(
                payloadId: payloadId,
                revision: revision,
                content: content,
                contentHash: contentHash,
                cause: cause,
                observedAt: observedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PayloadRevisionsTable, PayloadRevision>(table),
                  $$PayloadRevisionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({payloadId = false}) {
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
                    if (payloadId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.payloadId,
                        referencedTable: $$PayloadRevisionsTableReferences
                            ._payloadIdTable(db),
                        referencedColumn: $$PayloadRevisionsTableReferences
                            ._payloadIdTable(db)
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

typedef $$PayloadRevisionsTableProcessedTableManager =
    ProcessedTableManager<
      _$ProfileDb,
      $PayloadRevisionsTable,
      PayloadRevision,
      $$PayloadRevisionsTableFilterComposer,
      $$PayloadRevisionsTableOrderingComposer,
      $$PayloadRevisionsTableAnnotationComposer,
      $$PayloadRevisionsTableCreateCompanionBuilder,
      $$PayloadRevisionsTableUpdateCompanionBuilder,
      (PayloadRevision, $$PayloadRevisionsTableReferences),
      PayloadRevision,
      PrefetchHooks Function({bool payloadId})
    >;
typedef $$AttachmentsTableCreateCompanionBuilder =
    AttachmentsCompanion Function({
      required String id,
      required String payloadId,
      required String path,
      required String mime,
      required String sha256,
      required int size,
      Value<int> rowid,
    });
typedef $$AttachmentsTableUpdateCompanionBuilder =
    AttachmentsCompanion Function({
      Value<String> id,
      Value<String> payloadId,
      Value<String> path,
      Value<String> mime,
      Value<String> sha256,
      Value<int> size,
      Value<int> rowid,
    });

final class $$AttachmentsTableReferences
    extends BaseReferences<_$ProfileDb, $AttachmentsTable, Attachment> {
  $$AttachmentsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PayloadsTable _payloadIdTable(_$ProfileDb db) =>
      db.payloads.createAlias('attachments__payload_id__payloads__id');

  $$PayloadsTableProcessedTableManager get payloadId {
    final $_column = $_itemColumn<String>('payload_id')!;

    final manager = $$PayloadsTableTableManager(
      $_db,
      $_db.payloads,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_payloadIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AttachmentsTableFilterComposer
    extends Composer<_$ProfileDb, $AttachmentsTable> {
  $$AttachmentsTableFilterComposer({
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

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mime => $composableBuilder(
    column: $table.mime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnFilters(column),
  );

  $$PayloadsTableFilterComposer get payloadId {
    final $$PayloadsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.payloadId,
      referencedTable: $db.payloads,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PayloadsTableFilterComposer(
            $db: $db,
            $table: $db.payloads,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AttachmentsTableOrderingComposer
    extends Composer<_$ProfileDb, $AttachmentsTable> {
  $$AttachmentsTableOrderingComposer({
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

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mime => $composableBuilder(
    column: $table.mime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnOrderings(column),
  );

  $$PayloadsTableOrderingComposer get payloadId {
    final $$PayloadsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.payloadId,
      referencedTable: $db.payloads,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PayloadsTableOrderingComposer(
            $db: $db,
            $table: $db.payloads,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AttachmentsTableAnnotationComposer
    extends Composer<_$ProfileDb, $AttachmentsTable> {
  $$AttachmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get mime =>
      $composableBuilder(column: $table.mime, builder: (column) => column);

  GeneratedColumn<String> get sha256 =>
      $composableBuilder(column: $table.sha256, builder: (column) => column);

  GeneratedColumn<int> get size =>
      $composableBuilder(column: $table.size, builder: (column) => column);

  $$PayloadsTableAnnotationComposer get payloadId {
    final $$PayloadsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.payloadId,
      referencedTable: $db.payloads,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PayloadsTableAnnotationComposer(
            $db: $db,
            $table: $db.payloads,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AttachmentsTableTableManager
    extends
        RootTableManager<
          _$ProfileDb,
          $AttachmentsTable,
          Attachment,
          $$AttachmentsTableFilterComposer,
          $$AttachmentsTableOrderingComposer,
          $$AttachmentsTableAnnotationComposer,
          $$AttachmentsTableCreateCompanionBuilder,
          $$AttachmentsTableUpdateCompanionBuilder,
          (Attachment, $$AttachmentsTableReferences),
          Attachment,
          PrefetchHooks Function({bool payloadId})
        > {
  $$AttachmentsTableTableManager(_$ProfileDb db, $AttachmentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AttachmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AttachmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AttachmentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> payloadId = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<String> mime = const Value.absent(),
                Value<String> sha256 = const Value.absent(),
                Value<int> size = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AttachmentsCompanion(
                id: id,
                payloadId: payloadId,
                path: path,
                mime: mime,
                sha256: sha256,
                size: size,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String payloadId,
                required String path,
                required String mime,
                required String sha256,
                required int size,
                Value<int> rowid = const Value.absent(),
              }) => AttachmentsCompanion.insert(
                id: id,
                payloadId: payloadId,
                path: path,
                mime: mime,
                sha256: sha256,
                size: size,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AttachmentsTable, Attachment>(table),
                  $$AttachmentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({payloadId = false}) {
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
                    if (payloadId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.payloadId,
                        referencedTable: $$AttachmentsTableReferences
                            ._payloadIdTable(db),
                        referencedColumn: $$AttachmentsTableReferences
                            ._payloadIdTable(db)
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

typedef $$AttachmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$ProfileDb,
      $AttachmentsTable,
      Attachment,
      $$AttachmentsTableFilterComposer,
      $$AttachmentsTableOrderingComposer,
      $$AttachmentsTableAnnotationComposer,
      $$AttachmentsTableCreateCompanionBuilder,
      $$AttachmentsTableUpdateCompanionBuilder,
      (Attachment, $$AttachmentsTableReferences),
      Attachment,
      PrefetchHooks Function({bool payloadId})
    >;
typedef $$EnrichmentsTableCreateCompanionBuilder =
    EnrichmentsCompanion Function({
      required String id,
      required EntityType targetType,
      required String targetId,
      required String kind,
      required String output,
      required String modelId,
      Value<int> revision,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$EnrichmentsTableUpdateCompanionBuilder =
    EnrichmentsCompanion Function({
      Value<String> id,
      Value<EntityType> targetType,
      Value<String> targetId,
      Value<String> kind,
      Value<String> output,
      Value<String> modelId,
      Value<int> revision,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$EnrichmentsTableFilterComposer
    extends Composer<_$ProfileDb, $EnrichmentsTable> {
  $$EnrichmentsTableFilterComposer({
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

  ColumnWithTypeConverterFilters<EntityType, EntityType, String>
  get targetType => $composableBuilder(
    column: $table.targetType,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get targetId => $composableBuilder(
    column: $table.targetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get output => $composableBuilder(
    column: $table.output,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get modelId => $composableBuilder(
    column: $table.modelId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EnrichmentsTableOrderingComposer
    extends Composer<_$ProfileDb, $EnrichmentsTable> {
  $$EnrichmentsTableOrderingComposer({
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

  ColumnOrderings<String> get targetType => $composableBuilder(
    column: $table.targetType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetId => $composableBuilder(
    column: $table.targetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get output => $composableBuilder(
    column: $table.output,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get modelId => $composableBuilder(
    column: $table.modelId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EnrichmentsTableAnnotationComposer
    extends Composer<_$ProfileDb, $EnrichmentsTable> {
  $$EnrichmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<EntityType, String> get targetType =>
      $composableBuilder(
        column: $table.targetType,
        builder: (column) => column,
      );

  GeneratedColumn<String> get targetId =>
      $composableBuilder(column: $table.targetId, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get output =>
      $composableBuilder(column: $table.output, builder: (column) => column);

  GeneratedColumn<String> get modelId =>
      $composableBuilder(column: $table.modelId, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$EnrichmentsTableTableManager
    extends
        RootTableManager<
          _$ProfileDb,
          $EnrichmentsTable,
          Enrichment,
          $$EnrichmentsTableFilterComposer,
          $$EnrichmentsTableOrderingComposer,
          $$EnrichmentsTableAnnotationComposer,
          $$EnrichmentsTableCreateCompanionBuilder,
          $$EnrichmentsTableUpdateCompanionBuilder,
          (
            Enrichment,
            BaseReferences<_$ProfileDb, $EnrichmentsTable, Enrichment>,
          ),
          Enrichment,
          PrefetchHooks Function()
        > {
  $$EnrichmentsTableTableManager(_$ProfileDb db, $EnrichmentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EnrichmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EnrichmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EnrichmentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<EntityType> targetType = const Value.absent(),
                Value<String> targetId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> output = const Value.absent(),
                Value<String> modelId = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EnrichmentsCompanion(
                id: id,
                targetType: targetType,
                targetId: targetId,
                kind: kind,
                output: output,
                modelId: modelId,
                revision: revision,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required EntityType targetType,
                required String targetId,
                required String kind,
                required String output,
                required String modelId,
                Value<int> revision = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => EnrichmentsCompanion.insert(
                id: id,
                targetType: targetType,
                targetId: targetId,
                kind: kind,
                output: output,
                modelId: modelId,
                revision: revision,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EnrichmentsTable, Enrichment>(table),
                  BaseReferences<_$ProfileDb, $EnrichmentsTable, Enrichment>(
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

typedef $$EnrichmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$ProfileDb,
      $EnrichmentsTable,
      Enrichment,
      $$EnrichmentsTableFilterComposer,
      $$EnrichmentsTableOrderingComposer,
      $$EnrichmentsTableAnnotationComposer,
      $$EnrichmentsTableCreateCompanionBuilder,
      $$EnrichmentsTableUpdateCompanionBuilder,
      (Enrichment, BaseReferences<_$ProfileDb, $EnrichmentsTable, Enrichment>),
      Enrichment,
      PrefetchHooks Function()
    >;
typedef $$WorkstreamsTableCreateCompanionBuilder =
    WorkstreamsCompanion Function({
      required String id,
      Value<String?> projectId,
      required String title,
      Value<String> summary,
      Value<String?> spanStart,
      Value<String?> spanEnd,
      Value<bool> userTouched,
      Value<int> rowid,
    });
typedef $$WorkstreamsTableUpdateCompanionBuilder =
    WorkstreamsCompanion Function({
      Value<String> id,
      Value<String?> projectId,
      Value<String> title,
      Value<String> summary,
      Value<String?> spanStart,
      Value<String?> spanEnd,
      Value<bool> userTouched,
      Value<int> rowid,
    });

final class $$WorkstreamsTableReferences
    extends BaseReferences<_$ProfileDb, $WorkstreamsTable, Workstream> {
  $$WorkstreamsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProjectsTable _projectIdTable(_$ProfileDb db) =>
      db.projects.createAlias('workstreams__project_id__projects__id');

  $$ProjectsTableProcessedTableManager? get projectId {
    final $_column = $_itemColumn<String>('project_id');
    if ($_column == null) return null;
    final manager = $$ProjectsTableTableManager(
      $_db,
      $_db.projects,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$FactsTable, List<Fact>> _factsRefsTable(
    _$ProfileDb db,
  ) => MultiTypedResultKey.fromTable(
    db.facts,
    aliasName: 'workstreams__id__facts__workstream_id',
  );

  $$FactsTableProcessedTableManager get factsRefs {
    final manager = $$FactsTableTableManager(
      $_db,
      $_db.facts,
    ).filter((f) => f.workstreamId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_factsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$WorkstreamsTableFilterComposer
    extends Composer<_$ProfileDb, $WorkstreamsTable> {
  $$WorkstreamsTableFilterComposer({
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

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get spanStart => $composableBuilder(
    column: $table.spanStart,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get spanEnd => $composableBuilder(
    column: $table.spanEnd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get userTouched => $composableBuilder(
    column: $table.userTouched,
    builder: (column) => ColumnFilters(column),
  );

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableFilterComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> factsRefs(
    Expression<bool> Function($$FactsTableFilterComposer f) f,
  ) {
    final $$FactsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.facts,
      getReferencedColumn: (t) => t.workstreamId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FactsTableFilterComposer(
            $db: $db,
            $table: $db.facts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$WorkstreamsTableOrderingComposer
    extends Composer<_$ProfileDb, $WorkstreamsTable> {
  $$WorkstreamsTableOrderingComposer({
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

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get spanStart => $composableBuilder(
    column: $table.spanStart,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get spanEnd => $composableBuilder(
    column: $table.spanEnd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get userTouched => $composableBuilder(
    column: $table.userTouched,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableOrderingComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WorkstreamsTableAnnotationComposer
    extends Composer<_$ProfileDb, $WorkstreamsTable> {
  $$WorkstreamsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get summary =>
      $composableBuilder(column: $table.summary, builder: (column) => column);

  GeneratedColumn<String> get spanStart =>
      $composableBuilder(column: $table.spanStart, builder: (column) => column);

  GeneratedColumn<String> get spanEnd =>
      $composableBuilder(column: $table.spanEnd, builder: (column) => column);

  GeneratedColumn<bool> get userTouched => $composableBuilder(
    column: $table.userTouched,
    builder: (column) => column,
  );

  $$ProjectsTableAnnotationComposer get projectId {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> factsRefs<T extends Object>(
    Expression<T> Function($$FactsTableAnnotationComposer a) f,
  ) {
    final $$FactsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.facts,
      getReferencedColumn: (t) => t.workstreamId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FactsTableAnnotationComposer(
            $db: $db,
            $table: $db.facts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$WorkstreamsTableTableManager
    extends
        RootTableManager<
          _$ProfileDb,
          $WorkstreamsTable,
          Workstream,
          $$WorkstreamsTableFilterComposer,
          $$WorkstreamsTableOrderingComposer,
          $$WorkstreamsTableAnnotationComposer,
          $$WorkstreamsTableCreateCompanionBuilder,
          $$WorkstreamsTableUpdateCompanionBuilder,
          (Workstream, $$WorkstreamsTableReferences),
          Workstream,
          PrefetchHooks Function({bool projectId, bool factsRefs})
        > {
  $$WorkstreamsTableTableManager(_$ProfileDb db, $WorkstreamsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkstreamsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorkstreamsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorkstreamsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> projectId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> summary = const Value.absent(),
                Value<String?> spanStart = const Value.absent(),
                Value<String?> spanEnd = const Value.absent(),
                Value<bool> userTouched = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkstreamsCompanion(
                id: id,
                projectId: projectId,
                title: title,
                summary: summary,
                spanStart: spanStart,
                spanEnd: spanEnd,
                userTouched: userTouched,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> projectId = const Value.absent(),
                required String title,
                Value<String> summary = const Value.absent(),
                Value<String?> spanStart = const Value.absent(),
                Value<String?> spanEnd = const Value.absent(),
                Value<bool> userTouched = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkstreamsCompanion.insert(
                id: id,
                projectId: projectId,
                title: title,
                summary: summary,
                spanStart: spanStart,
                spanEnd: spanEnd,
                userTouched: userTouched,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$WorkstreamsTable, Workstream>(table),
                  $$WorkstreamsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({projectId = false, factsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (factsRefs) db.facts],
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
                    if (projectId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.projectId,
                        referencedTable: $$WorkstreamsTableReferences
                            ._projectIdTable(db),
                        referencedColumn: $$WorkstreamsTableReferences
                            ._projectIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (factsRefs)
                    await $_getPrefetchedDataByColumns<
                      Workstream,
                      $WorkstreamsTable,
                      Fact,
                      $FactsTable
                    >(
                      currentTable: table,
                      referencedTable: $$WorkstreamsTableReferences
                          ._factsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$WorkstreamsTableReferences(db, table, p0).factsRefs,
                      currentColumn: 'id',
                      referencedColumn: 'workstream_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$WorkstreamsTableProcessedTableManager =
    ProcessedTableManager<
      _$ProfileDb,
      $WorkstreamsTable,
      Workstream,
      $$WorkstreamsTableFilterComposer,
      $$WorkstreamsTableOrderingComposer,
      $$WorkstreamsTableAnnotationComposer,
      $$WorkstreamsTableCreateCompanionBuilder,
      $$WorkstreamsTableUpdateCompanionBuilder,
      (Workstream, $$WorkstreamsTableReferences),
      Workstream,
      PrefetchHooks Function({bool projectId, bool factsRefs})
    >;
typedef $$FactsTableCreateCompanionBuilder = FactsCompanion Function({
  required String id,
  required FactType type,
  required String statement,
  Value<String> details,
  required String periodStart,
  required String periodEnd,
  Value<String?> workstreamId,
  Value<String?> projectId,
  Value<double> importance,
  required FactOrigin origin,
  Value<ReviewState> reviewState,
  Value<String?> reviewProposal,
  Value<WinStatus> winStatus,
  Value<bool> retired,
  Value<int> revision,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$FactsTableUpdateCompanionBuilder = FactsCompanion Function({
  Value<String> id,
  Value<FactType> type,
  Value<String> statement,
  Value<String> details,
  Value<String> periodStart,
  Value<String> periodEnd,
  Value<String?> workstreamId,
  Value<String?> projectId,
  Value<double> importance,
  Value<FactOrigin> origin,
  Value<ReviewState> reviewState,
  Value<String?> reviewProposal,
  Value<WinStatus> winStatus,
  Value<bool> retired,
  Value<int> revision,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

final class $$FactsTableReferences
    extends BaseReferences<_$ProfileDb, $FactsTable, Fact> {
  $$FactsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $WorkstreamsTable _workstreamIdTable(_$ProfileDb db) =>
      db.workstreams.createAlias('facts__workstream_id__workstreams__id');

  $$WorkstreamsTableProcessedTableManager? get workstreamId {
    final $_column = $_itemColumn<String>('workstream_id');
    if ($_column == null) return null;
    final manager = $$WorkstreamsTableTableManager(
      $_db,
      $_db.workstreams,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_workstreamIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ProjectsTable _projectIdTable(_$ProfileDb db) =>
      db.projects.createAlias('facts__project_id__projects__id');

  $$ProjectsTableProcessedTableManager? get projectId {
    final $_column = $_itemColumn<String>('project_id');
    if ($_column == null) return null;
    final manager = $$ProjectsTableTableManager(
      $_db,
      $_db.projects,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$FactRevisionsTable, List<FactRevision>>
  _factRevisionsRefsTable(_$ProfileDb db) => MultiTypedResultKey.fromTable(
    db.factRevisions,
    aliasName: 'facts__id__fact_revisions__fact_id',
  );

  $$FactRevisionsTableProcessedTableManager get factRevisionsRefs {
    final manager = $$FactRevisionsTableTableManager(
      $_db,
      $_db.factRevisions,
    ).filter((f) => f.factId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_factRevisionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$CitationsTable, List<Citation>>
  _citationsRefsTable(_$ProfileDb db) => MultiTypedResultKey.fromTable(
    db.citations,
    aliasName: 'facts__id__citations__fact_id',
  );

  $$CitationsTableProcessedTableManager get citationsRefs {
    final manager = $$CitationsTableTableManager(
      $_db,
      $_db.citations,
    ).filter((f) => f.factId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_citationsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$FactsTableFilterComposer extends Composer<_$ProfileDb, $FactsTable> {
  $$FactsTableFilterComposer({
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

  ColumnWithTypeConverterFilters<FactType, FactType, String> get type =>
      $composableBuilder(
        column: $table.type,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get statement => $composableBuilder(
    column: $table.statement,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get details => $composableBuilder(
    column: $table.details,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get periodStart => $composableBuilder(
    column: $table.periodStart,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get periodEnd => $composableBuilder(
    column: $table.periodEnd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get importance => $composableBuilder(
    column: $table.importance,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<FactOrigin, FactOrigin, String> get origin =>
      $composableBuilder(
        column: $table.origin,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<ReviewState, ReviewState, String>
  get reviewState => $composableBuilder(
    column: $table.reviewState,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get reviewProposal => $composableBuilder(
    column: $table.reviewProposal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<WinStatus, WinStatus, String> get winStatus =>
      $composableBuilder(
        column: $table.winStatus,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<bool> get retired => $composableBuilder(
    column: $table.retired,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$WorkstreamsTableFilterComposer get workstreamId {
    final $$WorkstreamsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.workstreamId,
      referencedTable: $db.workstreams,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkstreamsTableFilterComposer(
            $db: $db,
            $table: $db.workstreams,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableFilterComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> factRevisionsRefs(
    Expression<bool> Function($$FactRevisionsTableFilterComposer f) f,
  ) {
    final $$FactRevisionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.factRevisions,
      getReferencedColumn: (t) => t.factId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FactRevisionsTableFilterComposer(
            $db: $db,
            $table: $db.factRevisions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> citationsRefs(
    Expression<bool> Function($$CitationsTableFilterComposer f) f,
  ) {
    final $$CitationsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.citations,
      getReferencedColumn: (t) => t.factId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CitationsTableFilterComposer(
            $db: $db,
            $table: $db.citations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FactsTableOrderingComposer extends Composer<_$ProfileDb, $FactsTable> {
  $$FactsTableOrderingComposer({
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

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get statement => $composableBuilder(
    column: $table.statement,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get details => $composableBuilder(
    column: $table.details,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get periodStart => $composableBuilder(
    column: $table.periodStart,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get periodEnd => $composableBuilder(
    column: $table.periodEnd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get importance => $composableBuilder(
    column: $table.importance,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get origin => $composableBuilder(
    column: $table.origin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reviewState => $composableBuilder(
    column: $table.reviewState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reviewProposal => $composableBuilder(
    column: $table.reviewProposal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get winStatus => $composableBuilder(
    column: $table.winStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get retired => $composableBuilder(
    column: $table.retired,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$WorkstreamsTableOrderingComposer get workstreamId {
    final $$WorkstreamsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.workstreamId,
      referencedTable: $db.workstreams,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkstreamsTableOrderingComposer(
            $db: $db,
            $table: $db.workstreams,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableOrderingComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FactsTableAnnotationComposer
    extends Composer<_$ProfileDb, $FactsTable> {
  $$FactsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<FactType, String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get statement =>
      $composableBuilder(column: $table.statement, builder: (column) => column);

  GeneratedColumn<String> get details =>
      $composableBuilder(column: $table.details, builder: (column) => column);

  GeneratedColumn<String> get periodStart => $composableBuilder(
    column: $table.periodStart,
    builder: (column) => column,
  );

  GeneratedColumn<String> get periodEnd =>
      $composableBuilder(column: $table.periodEnd, builder: (column) => column);

  GeneratedColumn<double> get importance => $composableBuilder(
    column: $table.importance,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<FactOrigin, String> get origin =>
      $composableBuilder(column: $table.origin, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ReviewState, String> get reviewState =>
      $composableBuilder(
        column: $table.reviewState,
        builder: (column) => column,
      );

  GeneratedColumn<String> get reviewProposal => $composableBuilder(
    column: $table.reviewProposal,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<WinStatus, String> get winStatus =>
      $composableBuilder(column: $table.winStatus, builder: (column) => column);

  GeneratedColumn<bool> get retired =>
      $composableBuilder(column: $table.retired, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$WorkstreamsTableAnnotationComposer get workstreamId {
    final $$WorkstreamsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.workstreamId,
      referencedTable: $db.workstreams,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkstreamsTableAnnotationComposer(
            $db: $db,
            $table: $db.workstreams,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ProjectsTableAnnotationComposer get projectId {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> factRevisionsRefs<T extends Object>(
    Expression<T> Function($$FactRevisionsTableAnnotationComposer a) f,
  ) {
    final $$FactRevisionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.factRevisions,
      getReferencedColumn: (t) => t.factId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FactRevisionsTableAnnotationComposer(
            $db: $db,
            $table: $db.factRevisions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> citationsRefs<T extends Object>(
    Expression<T> Function($$CitationsTableAnnotationComposer a) f,
  ) {
    final $$CitationsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.citations,
      getReferencedColumn: (t) => t.factId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CitationsTableAnnotationComposer(
            $db: $db,
            $table: $db.citations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FactsTableTableManager
    extends
        RootTableManager<
          _$ProfileDb,
          $FactsTable,
          Fact,
          $$FactsTableFilterComposer,
          $$FactsTableOrderingComposer,
          $$FactsTableAnnotationComposer,
          $$FactsTableCreateCompanionBuilder,
          $$FactsTableUpdateCompanionBuilder,
          (Fact, $$FactsTableReferences),
          Fact,
          PrefetchHooks Function({
            bool workstreamId,
            bool projectId,
            bool factRevisionsRefs,
            bool citationsRefs,
          })
        > {
  $$FactsTableTableManager(_$ProfileDb db, $FactsTable table)
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
                Value<String> id = const Value.absent(),
                Value<FactType> type = const Value.absent(),
                Value<String> statement = const Value.absent(),
                Value<String> details = const Value.absent(),
                Value<String> periodStart = const Value.absent(),
                Value<String> periodEnd = const Value.absent(),
                Value<String?> workstreamId = const Value.absent(),
                Value<String?> projectId = const Value.absent(),
                Value<double> importance = const Value.absent(),
                Value<FactOrigin> origin = const Value.absent(),
                Value<ReviewState> reviewState = const Value.absent(),
                Value<String?> reviewProposal = const Value.absent(),
                Value<WinStatus> winStatus = const Value.absent(),
                Value<bool> retired = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FactsCompanion(
                id: id,
                type: type,
                statement: statement,
                details: details,
                periodStart: periodStart,
                periodEnd: periodEnd,
                workstreamId: workstreamId,
                projectId: projectId,
                importance: importance,
                origin: origin,
                reviewState: reviewState,
                reviewProposal: reviewProposal,
                winStatus: winStatus,
                retired: retired,
                revision: revision,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required FactType type,
                required String statement,
                Value<String> details = const Value.absent(),
                required String periodStart,
                required String periodEnd,
                Value<String?> workstreamId = const Value.absent(),
                Value<String?> projectId = const Value.absent(),
                Value<double> importance = const Value.absent(),
                required FactOrigin origin,
                Value<ReviewState> reviewState = const Value.absent(),
                Value<String?> reviewProposal = const Value.absent(),
                Value<WinStatus> winStatus = const Value.absent(),
                Value<bool> retired = const Value.absent(),
                Value<int> revision = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => FactsCompanion.insert(
                id: id,
                type: type,
                statement: statement,
                details: details,
                periodStart: periodStart,
                periodEnd: periodEnd,
                workstreamId: workstreamId,
                projectId: projectId,
                importance: importance,
                origin: origin,
                reviewState: reviewState,
                reviewProposal: reviewProposal,
                winStatus: winStatus,
                retired: retired,
                revision: revision,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FactsTable, Fact>(table),
                  $$FactsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                workstreamId = false,
                projectId = false,
                factRevisionsRefs = false,
                citationsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (factRevisionsRefs) db.factRevisions,
                    if (citationsRefs) db.citations,
                  ],
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
                        if (workstreamId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.workstreamId,
                            referencedTable: $$FactsTableReferences
                                ._workstreamIdTable(db),
                            referencedColumn: $$FactsTableReferences
                                ._workstreamIdTable(db)
                                .id,
                          ) as T;
                        }
                        if (projectId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.projectId,
                            referencedTable: $$FactsTableReferences
                                ._projectIdTable(db),
                            referencedColumn: $$FactsTableReferences
                                ._projectIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (factRevisionsRefs)
                        await $_getPrefetchedDataByColumns<
                          Fact,
                          $FactsTable,
                          FactRevision,
                          $FactRevisionsTable
                        >(
                          currentTable: table,
                          referencedTable: $$FactsTableReferences
                              ._factRevisionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$FactsTableReferences(
                                db,
                                table,
                                p0,
                              ).factRevisionsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'fact_id',
                          typedResults: items,
                        ),
                      if (citationsRefs)
                        await $_getPrefetchedDataByColumns<
                          Fact,
                          $FactsTable,
                          Citation,
                          $CitationsTable
                        >(
                          currentTable: table,
                          referencedTable: $$FactsTableReferences
                              ._citationsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$FactsTableReferences(
                                db,
                                table,
                                p0,
                              ).citationsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'fact_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$FactsTableProcessedTableManager =
    ProcessedTableManager<
      _$ProfileDb,
      $FactsTable,
      Fact,
      $$FactsTableFilterComposer,
      $$FactsTableOrderingComposer,
      $$FactsTableAnnotationComposer,
      $$FactsTableCreateCompanionBuilder,
      $$FactsTableUpdateCompanionBuilder,
      (Fact, $$FactsTableReferences),
      Fact,
      PrefetchHooks Function({
        bool workstreamId,
        bool projectId,
        bool factRevisionsRefs,
        bool citationsRefs,
      })
    >;
typedef $$FactRevisionsTableCreateCompanionBuilder =
    FactRevisionsCompanion Function({
      required String factId,
      required int revision,
      required String statement,
      required String details,
      required FactOrigin origin,
      required String changedBy,
      required DateTime changedAt,
      Value<int> rowid,
    });
typedef $$FactRevisionsTableUpdateCompanionBuilder =
    FactRevisionsCompanion Function({
      Value<String> factId,
      Value<int> revision,
      Value<String> statement,
      Value<String> details,
      Value<FactOrigin> origin,
      Value<String> changedBy,
      Value<DateTime> changedAt,
      Value<int> rowid,
    });

final class $$FactRevisionsTableReferences
    extends BaseReferences<_$ProfileDb, $FactRevisionsTable, FactRevision> {
  $$FactRevisionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $FactsTable _factIdTable(_$ProfileDb db) =>
      db.facts.createAlias('fact_revisions__fact_id__facts__id');

  $$FactsTableProcessedTableManager get factId {
    final $_column = $_itemColumn<String>('fact_id')!;

    final manager = $$FactsTableTableManager(
      $_db,
      $_db.facts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_factIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$FactRevisionsTableFilterComposer
    extends Composer<_$ProfileDb, $FactRevisionsTable> {
  $$FactRevisionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get statement => $composableBuilder(
    column: $table.statement,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get details => $composableBuilder(
    column: $table.details,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<FactOrigin, FactOrigin, String> get origin =>
      $composableBuilder(
        column: $table.origin,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get changedBy => $composableBuilder(
    column: $table.changedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get changedAt => $composableBuilder(
    column: $table.changedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$FactsTableFilterComposer get factId {
    final $$FactsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.factId,
      referencedTable: $db.facts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FactsTableFilterComposer(
            $db: $db,
            $table: $db.facts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FactRevisionsTableOrderingComposer
    extends Composer<_$ProfileDb, $FactRevisionsTable> {
  $$FactRevisionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get statement => $composableBuilder(
    column: $table.statement,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get details => $composableBuilder(
    column: $table.details,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get origin => $composableBuilder(
    column: $table.origin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get changedBy => $composableBuilder(
    column: $table.changedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get changedAt => $composableBuilder(
    column: $table.changedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$FactsTableOrderingComposer get factId {
    final $$FactsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.factId,
      referencedTable: $db.facts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FactsTableOrderingComposer(
            $db: $db,
            $table: $db.facts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FactRevisionsTableAnnotationComposer
    extends Composer<_$ProfileDb, $FactRevisionsTable> {
  $$FactRevisionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<String> get statement =>
      $composableBuilder(column: $table.statement, builder: (column) => column);

  GeneratedColumn<String> get details =>
      $composableBuilder(column: $table.details, builder: (column) => column);

  GeneratedColumnWithTypeConverter<FactOrigin, String> get origin =>
      $composableBuilder(column: $table.origin, builder: (column) => column);

  GeneratedColumn<String> get changedBy =>
      $composableBuilder(column: $table.changedBy, builder: (column) => column);

  GeneratedColumn<DateTime> get changedAt =>
      $composableBuilder(column: $table.changedAt, builder: (column) => column);

  $$FactsTableAnnotationComposer get factId {
    final $$FactsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.factId,
      referencedTable: $db.facts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FactsTableAnnotationComposer(
            $db: $db,
            $table: $db.facts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FactRevisionsTableTableManager
    extends
        RootTableManager<
          _$ProfileDb,
          $FactRevisionsTable,
          FactRevision,
          $$FactRevisionsTableFilterComposer,
          $$FactRevisionsTableOrderingComposer,
          $$FactRevisionsTableAnnotationComposer,
          $$FactRevisionsTableCreateCompanionBuilder,
          $$FactRevisionsTableUpdateCompanionBuilder,
          (FactRevision, $$FactRevisionsTableReferences),
          FactRevision,
          PrefetchHooks Function({bool factId})
        > {
  $$FactRevisionsTableTableManager(_$ProfileDb db, $FactRevisionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FactRevisionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FactRevisionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FactRevisionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> factId = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<String> statement = const Value.absent(),
                Value<String> details = const Value.absent(),
                Value<FactOrigin> origin = const Value.absent(),
                Value<String> changedBy = const Value.absent(),
                Value<DateTime> changedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FactRevisionsCompanion(
                factId: factId,
                revision: revision,
                statement: statement,
                details: details,
                origin: origin,
                changedBy: changedBy,
                changedAt: changedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String factId,
                required int revision,
                required String statement,
                required String details,
                required FactOrigin origin,
                required String changedBy,
                required DateTime changedAt,
                Value<int> rowid = const Value.absent(),
              }) => FactRevisionsCompanion.insert(
                factId: factId,
                revision: revision,
                statement: statement,
                details: details,
                origin: origin,
                changedBy: changedBy,
                changedAt: changedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FactRevisionsTable, FactRevision>(table),
                  $$FactRevisionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({factId = false}) {
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
                    if (factId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.factId,
                        referencedTable: $$FactRevisionsTableReferences
                            ._factIdTable(db),
                        referencedColumn: $$FactRevisionsTableReferences
                            ._factIdTable(db)
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

typedef $$FactRevisionsTableProcessedTableManager =
    ProcessedTableManager<
      _$ProfileDb,
      $FactRevisionsTable,
      FactRevision,
      $$FactRevisionsTableFilterComposer,
      $$FactRevisionsTableOrderingComposer,
      $$FactRevisionsTableAnnotationComposer,
      $$FactRevisionsTableCreateCompanionBuilder,
      $$FactRevisionsTableUpdateCompanionBuilder,
      (FactRevision, $$FactRevisionsTableReferences),
      FactRevision,
      PrefetchHooks Function({bool factId})
    >;
typedef $$CitationsTableCreateCompanionBuilder = CitationsCompanion Function({
  required String factId,
  required String payloadId,
  required int payloadRevision,
  Value<String?> locator,
  Value<int> rowid,
});
typedef $$CitationsTableUpdateCompanionBuilder = CitationsCompanion Function({
  Value<String> factId,
  Value<String> payloadId,
  Value<int> payloadRevision,
  Value<String?> locator,
  Value<int> rowid,
});

final class $$CitationsTableReferences
    extends BaseReferences<_$ProfileDb, $CitationsTable, Citation> {
  $$CitationsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $FactsTable _factIdTable(_$ProfileDb db) =>
      db.facts.createAlias('citations__fact_id__facts__id');

  $$FactsTableProcessedTableManager get factId {
    final $_column = $_itemColumn<String>('fact_id')!;

    final manager = $$FactsTableTableManager(
      $_db,
      $_db.facts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_factIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $PayloadsTable _payloadIdTable(_$ProfileDb db) =>
      db.payloads.createAlias('citations__payload_id__payloads__id');

  $$PayloadsTableProcessedTableManager get payloadId {
    final $_column = $_itemColumn<String>('payload_id')!;

    final manager = $$PayloadsTableTableManager(
      $_db,
      $_db.payloads,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_payloadIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CitationsTableFilterComposer
    extends Composer<_$ProfileDb, $CitationsTable> {
  $$CitationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get payloadRevision => $composableBuilder(
    column: $table.payloadRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get locator => $composableBuilder(
    column: $table.locator,
    builder: (column) => ColumnFilters(column),
  );

  $$FactsTableFilterComposer get factId {
    final $$FactsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.factId,
      referencedTable: $db.facts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FactsTableFilterComposer(
            $db: $db,
            $table: $db.facts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PayloadsTableFilterComposer get payloadId {
    final $$PayloadsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.payloadId,
      referencedTable: $db.payloads,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PayloadsTableFilterComposer(
            $db: $db,
            $table: $db.payloads,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CitationsTableOrderingComposer
    extends Composer<_$ProfileDb, $CitationsTable> {
  $$CitationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get payloadRevision => $composableBuilder(
    column: $table.payloadRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get locator => $composableBuilder(
    column: $table.locator,
    builder: (column) => ColumnOrderings(column),
  );

  $$FactsTableOrderingComposer get factId {
    final $$FactsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.factId,
      referencedTable: $db.facts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FactsTableOrderingComposer(
            $db: $db,
            $table: $db.facts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PayloadsTableOrderingComposer get payloadId {
    final $$PayloadsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.payloadId,
      referencedTable: $db.payloads,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PayloadsTableOrderingComposer(
            $db: $db,
            $table: $db.payloads,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CitationsTableAnnotationComposer
    extends Composer<_$ProfileDb, $CitationsTable> {
  $$CitationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get payloadRevision => $composableBuilder(
    column: $table.payloadRevision,
    builder: (column) => column,
  );

  GeneratedColumn<String> get locator =>
      $composableBuilder(column: $table.locator, builder: (column) => column);

  $$FactsTableAnnotationComposer get factId {
    final $$FactsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.factId,
      referencedTable: $db.facts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FactsTableAnnotationComposer(
            $db: $db,
            $table: $db.facts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PayloadsTableAnnotationComposer get payloadId {
    final $$PayloadsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.payloadId,
      referencedTable: $db.payloads,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PayloadsTableAnnotationComposer(
            $db: $db,
            $table: $db.payloads,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CitationsTableTableManager
    extends
        RootTableManager<
          _$ProfileDb,
          $CitationsTable,
          Citation,
          $$CitationsTableFilterComposer,
          $$CitationsTableOrderingComposer,
          $$CitationsTableAnnotationComposer,
          $$CitationsTableCreateCompanionBuilder,
          $$CitationsTableUpdateCompanionBuilder,
          (Citation, $$CitationsTableReferences),
          Citation,
          PrefetchHooks Function({bool factId, bool payloadId})
        > {
  $$CitationsTableTableManager(_$ProfileDb db, $CitationsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CitationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CitationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CitationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> factId = const Value.absent(),
                Value<String> payloadId = const Value.absent(),
                Value<int> payloadRevision = const Value.absent(),
                Value<String?> locator = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CitationsCompanion(
                factId: factId,
                payloadId: payloadId,
                payloadRevision: payloadRevision,
                locator: locator,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String factId,
                required String payloadId,
                required int payloadRevision,
                Value<String?> locator = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CitationsCompanion.insert(
                factId: factId,
                payloadId: payloadId,
                payloadRevision: payloadRevision,
                locator: locator,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CitationsTable, Citation>(table),
                  $$CitationsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({factId = false, payloadId = false}) {
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
                    if (factId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.factId,
                        referencedTable: $$CitationsTableReferences
                            ._factIdTable(db),
                        referencedColumn: $$CitationsTableReferences
                            ._factIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (payloadId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.payloadId,
                        referencedTable: $$CitationsTableReferences
                            ._payloadIdTable(db),
                        referencedColumn: $$CitationsTableReferences
                            ._payloadIdTable(db)
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

typedef $$CitationsTableProcessedTableManager =
    ProcessedTableManager<
      _$ProfileDb,
      $CitationsTable,
      Citation,
      $$CitationsTableFilterComposer,
      $$CitationsTableOrderingComposer,
      $$CitationsTableAnnotationComposer,
      $$CitationsTableCreateCompanionBuilder,
      $$CitationsTableUpdateCompanionBuilder,
      (Citation, $$CitationsTableReferences),
      Citation,
      PrefetchHooks Function({bool factId, bool payloadId})
    >;
typedef $$CurationRulesTableCreateCompanionBuilder =
    CurationRulesCompanion Function({
      required String id,
      required String match,
      required CurationAction action,
      Value<double> value,
      Value<int> priority,
      Value<bool> enabled,
      Value<int> rowid,
    });
typedef $$CurationRulesTableUpdateCompanionBuilder =
    CurationRulesCompanion Function({
      Value<String> id,
      Value<String> match,
      Value<CurationAction> action,
      Value<double> value,
      Value<int> priority,
      Value<bool> enabled,
      Value<int> rowid,
    });

class $$CurationRulesTableFilterComposer
    extends Composer<_$ProfileDb, $CurationRulesTable> {
  $$CurationRulesTableFilterComposer({
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

  ColumnFilters<String> get match => $composableBuilder(
    column: $table.match,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<CurationAction, CurationAction, String>
  get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<double> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CurationRulesTableOrderingComposer
    extends Composer<_$ProfileDb, $CurationRulesTable> {
  $$CurationRulesTableOrderingComposer({
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

  ColumnOrderings<String> get match => $composableBuilder(
    column: $table.match,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CurationRulesTableAnnotationComposer
    extends Composer<_$ProfileDb, $CurationRulesTable> {
  $$CurationRulesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get match =>
      $composableBuilder(column: $table.match, builder: (column) => column);

  GeneratedColumnWithTypeConverter<CurationAction, String> get action =>
      $composableBuilder(column: $table.action, builder: (column) => column);

  GeneratedColumn<double> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);
}

class $$CurationRulesTableTableManager
    extends
        RootTableManager<
          _$ProfileDb,
          $CurationRulesTable,
          CurationRule,
          $$CurationRulesTableFilterComposer,
          $$CurationRulesTableOrderingComposer,
          $$CurationRulesTableAnnotationComposer,
          $$CurationRulesTableCreateCompanionBuilder,
          $$CurationRulesTableUpdateCompanionBuilder,
          (
            CurationRule,
            BaseReferences<_$ProfileDb, $CurationRulesTable, CurationRule>,
          ),
          CurationRule,
          PrefetchHooks Function()
        > {
  $$CurationRulesTableTableManager(_$ProfileDb db, $CurationRulesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CurationRulesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CurationRulesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CurationRulesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> match = const Value.absent(),
                Value<CurationAction> action = const Value.absent(),
                Value<double> value = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CurationRulesCompanion(
                id: id,
                match: match,
                action: action,
                value: value,
                priority: priority,
                enabled: enabled,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String match,
                required CurationAction action,
                Value<double> value = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CurationRulesCompanion.insert(
                id: id,
                match: match,
                action: action,
                value: value,
                priority: priority,
                enabled: enabled,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CurationRulesTable, CurationRule>(table),
                  BaseReferences<
                    _$ProfileDb,
                    $CurationRulesTable,
                    CurationRule
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CurationRulesTableProcessedTableManager =
    ProcessedTableManager<
      _$ProfileDb,
      $CurationRulesTable,
      CurationRule,
      $$CurationRulesTableFilterComposer,
      $$CurationRulesTableOrderingComposer,
      $$CurationRulesTableAnnotationComposer,
      $$CurationRulesTableCreateCompanionBuilder,
      $$CurationRulesTableUpdateCompanionBuilder,
      (
        CurationRule,
        BaseReferences<_$ProfileDb, $CurationRulesTable, CurationRule>,
      ),
      CurationRule,
      PrefetchHooks Function()
    >;
typedef $$TemplatesTableCreateCompanionBuilder = TemplatesCompanion Function({
  required String id,
  required String name,
  required String periodKinds,
  required String prompt,
  Value<bool> builtIn,
  Value<int> version,
  Value<int> rowid,
});
typedef $$TemplatesTableUpdateCompanionBuilder = TemplatesCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> periodKinds,
  Value<String> prompt,
  Value<bool> builtIn,
  Value<int> version,
  Value<int> rowid,
});

final class $$TemplatesTableReferences
    extends BaseReferences<_$ProfileDb, $TemplatesTable, Template> {
  $$TemplatesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ReportsTable, List<Report>> _reportsRefsTable(
    _$ProfileDb db,
  ) => MultiTypedResultKey.fromTable(
    db.reports,
    aliasName: 'templates__id__reports__template_id',
  );

  $$ReportsTableProcessedTableManager get reportsRefs {
    final manager = $$ReportsTableTableManager(
      $_db,
      $_db.reports,
    ).filter((f) => f.templateId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_reportsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TemplatesTableFilterComposer
    extends Composer<_$ProfileDb, $TemplatesTable> {
  $$TemplatesTableFilterComposer({
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

  ColumnFilters<String> get periodKinds => $composableBuilder(
    column: $table.periodKinds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get prompt => $composableBuilder(
    column: $table.prompt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get builtIn => $composableBuilder(
    column: $table.builtIn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> reportsRefs(
    Expression<bool> Function($$ReportsTableFilterComposer f) f,
  ) {
    final $$ReportsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.reports,
      getReferencedColumn: (t) => t.templateId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReportsTableFilterComposer(
            $db: $db,
            $table: $db.reports,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TemplatesTableOrderingComposer
    extends Composer<_$ProfileDb, $TemplatesTable> {
  $$TemplatesTableOrderingComposer({
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

  ColumnOrderings<String> get periodKinds => $composableBuilder(
    column: $table.periodKinds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get prompt => $composableBuilder(
    column: $table.prompt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get builtIn => $composableBuilder(
    column: $table.builtIn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TemplatesTableAnnotationComposer
    extends Composer<_$ProfileDb, $TemplatesTable> {
  $$TemplatesTableAnnotationComposer({
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

  GeneratedColumn<String> get periodKinds => $composableBuilder(
    column: $table.periodKinds,
    builder: (column) => column,
  );

  GeneratedColumn<String> get prompt =>
      $composableBuilder(column: $table.prompt, builder: (column) => column);

  GeneratedColumn<bool> get builtIn =>
      $composableBuilder(column: $table.builtIn, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  Expression<T> reportsRefs<T extends Object>(
    Expression<T> Function($$ReportsTableAnnotationComposer a) f,
  ) {
    final $$ReportsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.reports,
      getReferencedColumn: (t) => t.templateId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReportsTableAnnotationComposer(
            $db: $db,
            $table: $db.reports,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TemplatesTableTableManager
    extends
        RootTableManager<
          _$ProfileDb,
          $TemplatesTable,
          Template,
          $$TemplatesTableFilterComposer,
          $$TemplatesTableOrderingComposer,
          $$TemplatesTableAnnotationComposer,
          $$TemplatesTableCreateCompanionBuilder,
          $$TemplatesTableUpdateCompanionBuilder,
          (Template, $$TemplatesTableReferences),
          Template,
          PrefetchHooks Function({bool reportsRefs})
        > {
  $$TemplatesTableTableManager(_$ProfileDb db, $TemplatesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TemplatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TemplatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TemplatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> periodKinds = const Value.absent(),
                Value<String> prompt = const Value.absent(),
                Value<bool> builtIn = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TemplatesCompanion(
                id: id,
                name: name,
                periodKinds: periodKinds,
                prompt: prompt,
                builtIn: builtIn,
                version: version,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String periodKinds,
                required String prompt,
                Value<bool> builtIn = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TemplatesCompanion.insert(
                id: id,
                name: name,
                periodKinds: periodKinds,
                prompt: prompt,
                builtIn: builtIn,
                version: version,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TemplatesTable, Template>(table),
                  $$TemplatesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({reportsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (reportsRefs) db.reports],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (reportsRefs)
                    await $_getPrefetchedDataByColumns<
                      Template,
                      $TemplatesTable,
                      Report,
                      $ReportsTable
                    >(
                      currentTable: table,
                      referencedTable: $$TemplatesTableReferences
                          ._reportsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$TemplatesTableReferences(db, table, p0).reportsRefs,
                      currentColumn: 'id',
                      referencedColumn: 'template_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$TemplatesTableProcessedTableManager =
    ProcessedTableManager<
      _$ProfileDb,
      $TemplatesTable,
      Template,
      $$TemplatesTableFilterComposer,
      $$TemplatesTableOrderingComposer,
      $$TemplatesTableAnnotationComposer,
      $$TemplatesTableCreateCompanionBuilder,
      $$TemplatesTableUpdateCompanionBuilder,
      (Template, $$TemplatesTableReferences),
      Template,
      PrefetchHooks Function({bool reportsRefs})
    >;
typedef $$ReportsTableCreateCompanionBuilder = ReportsCompanion Function({
  required String id,
  required PeriodKind periodKind,
  required String periodStart,
  required String periodEnd,
  required String templateId,
  Value<bool> locked,
  Value<String?> lockedSnapshotId,
  Value<int> rowid,
});
typedef $$ReportsTableUpdateCompanionBuilder = ReportsCompanion Function({
  Value<String> id,
  Value<PeriodKind> periodKind,
  Value<String> periodStart,
  Value<String> periodEnd,
  Value<String> templateId,
  Value<bool> locked,
  Value<String?> lockedSnapshotId,
  Value<int> rowid,
});

final class $$ReportsTableReferences
    extends BaseReferences<_$ProfileDb, $ReportsTable, Report> {
  $$ReportsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TemplatesTable _templateIdTable(_$ProfileDb db) =>
      db.templates.createAlias('reports__template_id__templates__id');

  $$TemplatesTableProcessedTableManager get templateId {
    final $_column = $_itemColumn<String>('template_id')!;

    final manager = $$TemplatesTableTableManager(
      $_db,
      $_db.templates,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_templateIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$ReportSnapshotsTable, List<ReportSnapshot>>
  _reportSnapshotsRefsTable(_$ProfileDb db) => MultiTypedResultKey.fromTable(
    db.reportSnapshots,
    aliasName: 'reports__id__report_snapshots__report_id',
  );

  $$ReportSnapshotsTableProcessedTableManager get reportSnapshotsRefs {
    final manager = $$ReportSnapshotsTableTableManager(
      $_db,
      $_db.reportSnapshots,
    ).filter((f) => f.reportId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _reportSnapshotsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ReportsTableFilterComposer
    extends Composer<_$ProfileDb, $ReportsTable> {
  $$ReportsTableFilterComposer({
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

  ColumnWithTypeConverterFilters<PeriodKind, PeriodKind, String>
  get periodKind => $composableBuilder(
    column: $table.periodKind,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get periodStart => $composableBuilder(
    column: $table.periodStart,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get periodEnd => $composableBuilder(
    column: $table.periodEnd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get locked => $composableBuilder(
    column: $table.locked,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lockedSnapshotId => $composableBuilder(
    column: $table.lockedSnapshotId,
    builder: (column) => ColumnFilters(column),
  );

  $$TemplatesTableFilterComposer get templateId {
    final $$TemplatesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.templateId,
      referencedTable: $db.templates,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TemplatesTableFilterComposer(
            $db: $db,
            $table: $db.templates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> reportSnapshotsRefs(
    Expression<bool> Function($$ReportSnapshotsTableFilterComposer f) f,
  ) {
    final $$ReportSnapshotsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.reportSnapshots,
      getReferencedColumn: (t) => t.reportId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReportSnapshotsTableFilterComposer(
            $db: $db,
            $table: $db.reportSnapshots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ReportsTableOrderingComposer
    extends Composer<_$ProfileDb, $ReportsTable> {
  $$ReportsTableOrderingComposer({
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

  ColumnOrderings<String> get periodKind => $composableBuilder(
    column: $table.periodKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get periodStart => $composableBuilder(
    column: $table.periodStart,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get periodEnd => $composableBuilder(
    column: $table.periodEnd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get locked => $composableBuilder(
    column: $table.locked,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lockedSnapshotId => $composableBuilder(
    column: $table.lockedSnapshotId,
    builder: (column) => ColumnOrderings(column),
  );

  $$TemplatesTableOrderingComposer get templateId {
    final $$TemplatesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.templateId,
      referencedTable: $db.templates,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TemplatesTableOrderingComposer(
            $db: $db,
            $table: $db.templates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReportsTableAnnotationComposer
    extends Composer<_$ProfileDb, $ReportsTable> {
  $$ReportsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<PeriodKind, String> get periodKind =>
      $composableBuilder(
        column: $table.periodKind,
        builder: (column) => column,
      );

  GeneratedColumn<String> get periodStart => $composableBuilder(
    column: $table.periodStart,
    builder: (column) => column,
  );

  GeneratedColumn<String> get periodEnd =>
      $composableBuilder(column: $table.periodEnd, builder: (column) => column);

  GeneratedColumn<bool> get locked =>
      $composableBuilder(column: $table.locked, builder: (column) => column);

  GeneratedColumn<String> get lockedSnapshotId => $composableBuilder(
    column: $table.lockedSnapshotId,
    builder: (column) => column,
  );

  $$TemplatesTableAnnotationComposer get templateId {
    final $$TemplatesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.templateId,
      referencedTable: $db.templates,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TemplatesTableAnnotationComposer(
            $db: $db,
            $table: $db.templates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> reportSnapshotsRefs<T extends Object>(
    Expression<T> Function($$ReportSnapshotsTableAnnotationComposer a) f,
  ) {
    final $$ReportSnapshotsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.reportSnapshots,
      getReferencedColumn: (t) => t.reportId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReportSnapshotsTableAnnotationComposer(
            $db: $db,
            $table: $db.reportSnapshots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ReportsTableTableManager
    extends
        RootTableManager<
          _$ProfileDb,
          $ReportsTable,
          Report,
          $$ReportsTableFilterComposer,
          $$ReportsTableOrderingComposer,
          $$ReportsTableAnnotationComposer,
          $$ReportsTableCreateCompanionBuilder,
          $$ReportsTableUpdateCompanionBuilder,
          (Report, $$ReportsTableReferences),
          Report,
          PrefetchHooks Function({bool templateId, bool reportSnapshotsRefs})
        > {
  $$ReportsTableTableManager(_$ProfileDb db, $ReportsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReportsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReportsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReportsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<PeriodKind> periodKind = const Value.absent(),
                Value<String> periodStart = const Value.absent(),
                Value<String> periodEnd = const Value.absent(),
                Value<String> templateId = const Value.absent(),
                Value<bool> locked = const Value.absent(),
                Value<String?> lockedSnapshotId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReportsCompanion(
                id: id,
                periodKind: periodKind,
                periodStart: periodStart,
                periodEnd: periodEnd,
                templateId: templateId,
                locked: locked,
                lockedSnapshotId: lockedSnapshotId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required PeriodKind periodKind,
                required String periodStart,
                required String periodEnd,
                required String templateId,
                Value<bool> locked = const Value.absent(),
                Value<String?> lockedSnapshotId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReportsCompanion.insert(
                id: id,
                periodKind: periodKind,
                periodStart: periodStart,
                periodEnd: periodEnd,
                templateId: templateId,
                locked: locked,
                lockedSnapshotId: lockedSnapshotId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ReportsTable, Report>(table),
                  $$ReportsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({templateId = false, reportSnapshotsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (reportSnapshotsRefs) db.reportSnapshots,
                  ],
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
                        if (templateId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.templateId,
                            referencedTable: $$ReportsTableReferences
                                ._templateIdTable(db),
                            referencedColumn: $$ReportsTableReferences
                                ._templateIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (reportSnapshotsRefs)
                        await $_getPrefetchedDataByColumns<
                          Report,
                          $ReportsTable,
                          ReportSnapshot,
                          $ReportSnapshotsTable
                        >(
                          currentTable: table,
                          referencedTable: $$ReportsTableReferences
                              ._reportSnapshotsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ReportsTableReferences(
                                db,
                                table,
                                p0,
                              ).reportSnapshotsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'report_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ReportsTableProcessedTableManager =
    ProcessedTableManager<
      _$ProfileDb,
      $ReportsTable,
      Report,
      $$ReportsTableFilterComposer,
      $$ReportsTableOrderingComposer,
      $$ReportsTableAnnotationComposer,
      $$ReportsTableCreateCompanionBuilder,
      $$ReportsTableUpdateCompanionBuilder,
      (Report, $$ReportsTableReferences),
      Report,
      PrefetchHooks Function({bool templateId, bool reportSnapshotsRefs})
    >;
typedef $$ReportSnapshotsTableCreateCompanionBuilder =
    ReportSnapshotsCompanion Function({
      required String id,
      required String reportId,
      required int version,
      required String json,
      required String markdown,
      required String modelId,
      Value<String?> styleInstruction,
      required DateTime generatedAt,
      Value<int> rowid,
    });
typedef $$ReportSnapshotsTableUpdateCompanionBuilder =
    ReportSnapshotsCompanion Function({
      Value<String> id,
      Value<String> reportId,
      Value<int> version,
      Value<String> json,
      Value<String> markdown,
      Value<String> modelId,
      Value<String?> styleInstruction,
      Value<DateTime> generatedAt,
      Value<int> rowid,
    });

final class $$ReportSnapshotsTableReferences
    extends BaseReferences<_$ProfileDb, $ReportSnapshotsTable, ReportSnapshot> {
  $$ReportSnapshotsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ReportsTable _reportIdTable(_$ProfileDb db) =>
      db.reports.createAlias('report_snapshots__report_id__reports__id');

  $$ReportsTableProcessedTableManager get reportId {
    final $_column = $_itemColumn<String>('report_id')!;

    final manager = $$ReportsTableTableManager(
      $_db,
      $_db.reports,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_reportIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ReportSnapshotsTableFilterComposer
    extends Composer<_$ProfileDb, $ReportSnapshotsTable> {
  $$ReportSnapshotsTableFilterComposer({
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

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get markdown => $composableBuilder(
    column: $table.markdown,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get modelId => $composableBuilder(
    column: $table.modelId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get styleInstruction => $composableBuilder(
    column: $table.styleInstruction,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get generatedAt => $composableBuilder(
    column: $table.generatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ReportsTableFilterComposer get reportId {
    final $$ReportsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.reportId,
      referencedTable: $db.reports,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReportsTableFilterComposer(
            $db: $db,
            $table: $db.reports,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReportSnapshotsTableOrderingComposer
    extends Composer<_$ProfileDb, $ReportSnapshotsTable> {
  $$ReportSnapshotsTableOrderingComposer({
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

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get markdown => $composableBuilder(
    column: $table.markdown,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get modelId => $composableBuilder(
    column: $table.modelId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get styleInstruction => $composableBuilder(
    column: $table.styleInstruction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get generatedAt => $composableBuilder(
    column: $table.generatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ReportsTableOrderingComposer get reportId {
    final $$ReportsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.reportId,
      referencedTable: $db.reports,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReportsTableOrderingComposer(
            $db: $db,
            $table: $db.reports,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReportSnapshotsTableAnnotationComposer
    extends Composer<_$ProfileDb, $ReportSnapshotsTable> {
  $$ReportSnapshotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);

  GeneratedColumn<String> get markdown =>
      $composableBuilder(column: $table.markdown, builder: (column) => column);

  GeneratedColumn<String> get modelId =>
      $composableBuilder(column: $table.modelId, builder: (column) => column);

  GeneratedColumn<String> get styleInstruction => $composableBuilder(
    column: $table.styleInstruction,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get generatedAt => $composableBuilder(
    column: $table.generatedAt,
    builder: (column) => column,
  );

  $$ReportsTableAnnotationComposer get reportId {
    final $$ReportsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.reportId,
      referencedTable: $db.reports,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReportsTableAnnotationComposer(
            $db: $db,
            $table: $db.reports,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReportSnapshotsTableTableManager
    extends
        RootTableManager<
          _$ProfileDb,
          $ReportSnapshotsTable,
          ReportSnapshot,
          $$ReportSnapshotsTableFilterComposer,
          $$ReportSnapshotsTableOrderingComposer,
          $$ReportSnapshotsTableAnnotationComposer,
          $$ReportSnapshotsTableCreateCompanionBuilder,
          $$ReportSnapshotsTableUpdateCompanionBuilder,
          (ReportSnapshot, $$ReportSnapshotsTableReferences),
          ReportSnapshot,
          PrefetchHooks Function({bool reportId})
        > {
  $$ReportSnapshotsTableTableManager(
    _$ProfileDb db,
    $ReportSnapshotsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReportSnapshotsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReportSnapshotsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReportSnapshotsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> reportId = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<String> json = const Value.absent(),
                Value<String> markdown = const Value.absent(),
                Value<String> modelId = const Value.absent(),
                Value<String?> styleInstruction = const Value.absent(),
                Value<DateTime> generatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReportSnapshotsCompanion(
                id: id,
                reportId: reportId,
                version: version,
                json: json,
                markdown: markdown,
                modelId: modelId,
                styleInstruction: styleInstruction,
                generatedAt: generatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String reportId,
                required int version,
                required String json,
                required String markdown,
                required String modelId,
                Value<String?> styleInstruction = const Value.absent(),
                required DateTime generatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ReportSnapshotsCompanion.insert(
                id: id,
                reportId: reportId,
                version: version,
                json: json,
                markdown: markdown,
                modelId: modelId,
                styleInstruction: styleInstruction,
                generatedAt: generatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ReportSnapshotsTable, ReportSnapshot>(table),
                  $$ReportSnapshotsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({reportId = false}) {
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
                    if (reportId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.reportId,
                        referencedTable: $$ReportSnapshotsTableReferences
                            ._reportIdTable(db),
                        referencedColumn: $$ReportSnapshotsTableReferences
                            ._reportIdTable(db)
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

typedef $$ReportSnapshotsTableProcessedTableManager =
    ProcessedTableManager<
      _$ProfileDb,
      $ReportSnapshotsTable,
      ReportSnapshot,
      $$ReportSnapshotsTableFilterComposer,
      $$ReportSnapshotsTableOrderingComposer,
      $$ReportSnapshotsTableAnnotationComposer,
      $$ReportSnapshotsTableCreateCompanionBuilder,
      $$ReportSnapshotsTableUpdateCompanionBuilder,
      (ReportSnapshot, $$ReportSnapshotsTableReferences),
      ReportSnapshot,
      PrefetchHooks Function({bool reportId})
    >;
typedef $$TaskRoutesTableCreateCompanionBuilder = TaskRoutesCompanion Function({
  required LlmRoute route,
  Value<String?> modelId,
  Value<int> rowid,
});
typedef $$TaskRoutesTableUpdateCompanionBuilder = TaskRoutesCompanion Function({
  Value<LlmRoute> route,
  Value<String?> modelId,
  Value<int> rowid,
});

class $$TaskRoutesTableFilterComposer
    extends Composer<_$ProfileDb, $TaskRoutesTable> {
  $$TaskRoutesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnWithTypeConverterFilters<LlmRoute, LlmRoute, String> get route =>
      $composableBuilder(
        column: $table.route,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get modelId => $composableBuilder(
    column: $table.modelId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TaskRoutesTableOrderingComposer
    extends Composer<_$ProfileDb, $TaskRoutesTable> {
  $$TaskRoutesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get route => $composableBuilder(
    column: $table.route,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get modelId => $composableBuilder(
    column: $table.modelId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TaskRoutesTableAnnotationComposer
    extends Composer<_$ProfileDb, $TaskRoutesTable> {
  $$TaskRoutesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumnWithTypeConverter<LlmRoute, String> get route =>
      $composableBuilder(column: $table.route, builder: (column) => column);

  GeneratedColumn<String> get modelId =>
      $composableBuilder(column: $table.modelId, builder: (column) => column);
}

class $$TaskRoutesTableTableManager
    extends
        RootTableManager<
          _$ProfileDb,
          $TaskRoutesTable,
          TaskRoute,
          $$TaskRoutesTableFilterComposer,
          $$TaskRoutesTableOrderingComposer,
          $$TaskRoutesTableAnnotationComposer,
          $$TaskRoutesTableCreateCompanionBuilder,
          $$TaskRoutesTableUpdateCompanionBuilder,
          (TaskRoute, BaseReferences<_$ProfileDb, $TaskRoutesTable, TaskRoute>),
          TaskRoute,
          PrefetchHooks Function()
        > {
  $$TaskRoutesTableTableManager(_$ProfileDb db, $TaskRoutesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TaskRoutesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TaskRoutesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TaskRoutesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<LlmRoute> route = const Value.absent(),
                Value<String?> modelId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TaskRoutesCompanion(
                route: route,
                modelId: modelId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required LlmRoute route,
                Value<String?> modelId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TaskRoutesCompanion.insert(
                route: route,
                modelId: modelId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TaskRoutesTable, TaskRoute>(table),
                  BaseReferences<_$ProfileDb, $TaskRoutesTable, TaskRoute>(
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

typedef $$TaskRoutesTableProcessedTableManager =
    ProcessedTableManager<
      _$ProfileDb,
      $TaskRoutesTable,
      TaskRoute,
      $$TaskRoutesTableFilterComposer,
      $$TaskRoutesTableOrderingComposer,
      $$TaskRoutesTableAnnotationComposer,
      $$TaskRoutesTableCreateCompanionBuilder,
      $$TaskRoutesTableUpdateCompanionBuilder,
      (TaskRoute, BaseReferences<_$ProfileDb, $TaskRoutesTable, TaskRoute>),
      TaskRoute,
      PrefetchHooks Function()
    >;
typedef $$JobsTableCreateCompanionBuilder = JobsCompanion Function({
  required String id,
  required String kind,
  Value<String> args,
  required JobLane lane,
  required JobState state,
  Value<int> attempts,
  required DateTime runAfter,
  Value<DateTime?> leaseUntil,
  Value<String?> lastError,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$JobsTableUpdateCompanionBuilder = JobsCompanion Function({
  Value<String> id,
  Value<String> kind,
  Value<String> args,
  Value<JobLane> lane,
  Value<JobState> state,
  Value<int> attempts,
  Value<DateTime> runAfter,
  Value<DateTime?> leaseUntil,
  Value<String?> lastError,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$JobsTableFilterComposer extends Composer<_$ProfileDb, $JobsTable> {
  $$JobsTableFilterComposer({
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

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get args => $composableBuilder(
    column: $table.args,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<JobLane, JobLane, String> get lane =>
      $composableBuilder(
        column: $table.lane,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<JobState, JobState, String> get state =>
      $composableBuilder(
        column: $table.state,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get runAfter => $composableBuilder(
    column: $table.runAfter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get leaseUntil => $composableBuilder(
    column: $table.leaseUntil,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$JobsTableOrderingComposer extends Composer<_$ProfileDb, $JobsTable> {
  $$JobsTableOrderingComposer({
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

  ColumnOrderings<String> get args => $composableBuilder(
    column: $table.args,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lane => $composableBuilder(
    column: $table.lane,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get runAfter => $composableBuilder(
    column: $table.runAfter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get leaseUntil => $composableBuilder(
    column: $table.leaseUntil,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$JobsTableAnnotationComposer extends Composer<_$ProfileDb, $JobsTable> {
  $$JobsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get args =>
      $composableBuilder(column: $table.args, builder: (column) => column);

  GeneratedColumnWithTypeConverter<JobLane, String> get lane =>
      $composableBuilder(column: $table.lane, builder: (column) => column);

  GeneratedColumnWithTypeConverter<JobState, String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<DateTime> get runAfter =>
      $composableBuilder(column: $table.runAfter, builder: (column) => column);

  GeneratedColumn<DateTime> get leaseUntil => $composableBuilder(
    column: $table.leaseUntil,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$JobsTableTableManager
    extends
        RootTableManager<
          _$ProfileDb,
          $JobsTable,
          Job,
          $$JobsTableFilterComposer,
          $$JobsTableOrderingComposer,
          $$JobsTableAnnotationComposer,
          $$JobsTableCreateCompanionBuilder,
          $$JobsTableUpdateCompanionBuilder,
          (Job, BaseReferences<_$ProfileDb, $JobsTable, Job>),
          Job,
          PrefetchHooks Function()
        > {
  $$JobsTableTableManager(_$ProfileDb db, $JobsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$JobsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$JobsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$JobsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> args = const Value.absent(),
                Value<JobLane> lane = const Value.absent(),
                Value<JobState> state = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<DateTime> runAfter = const Value.absent(),
                Value<DateTime?> leaseUntil = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => JobsCompanion(
                id: id,
                kind: kind,
                args: args,
                lane: lane,
                state: state,
                attempts: attempts,
                runAfter: runAfter,
                leaseUntil: leaseUntil,
                lastError: lastError,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String kind,
                Value<String> args = const Value.absent(),
                required JobLane lane,
                required JobState state,
                Value<int> attempts = const Value.absent(),
                required DateTime runAfter,
                Value<DateTime?> leaseUntil = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => JobsCompanion.insert(
                id: id,
                kind: kind,
                args: args,
                lane: lane,
                state: state,
                attempts: attempts,
                runAfter: runAfter,
                leaseUntil: leaseUntil,
                lastError: lastError,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$JobsTable, Job>(table),
                  BaseReferences<_$ProfileDb, $JobsTable, Job>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$JobsTableProcessedTableManager =
    ProcessedTableManager<
      _$ProfileDb,
      $JobsTable,
      Job,
      $$JobsTableFilterComposer,
      $$JobsTableOrderingComposer,
      $$JobsTableAnnotationComposer,
      $$JobsTableCreateCompanionBuilder,
      $$JobsTableUpdateCompanionBuilder,
      (Job, BaseReferences<_$ProfileDb, $JobsTable, Job>),
      Job,
      PrefetchHooks Function()
    >;
typedef $$SchedulesTableCreateCompanionBuilder = SchedulesCompanion Function({
  required String id,
  required String kind,
  required String rule,
  Value<bool> enabled,
  Value<DateTime?> lastRunAt,
  Value<int> rowid,
});
typedef $$SchedulesTableUpdateCompanionBuilder = SchedulesCompanion Function({
  Value<String> id,
  Value<String> kind,
  Value<String> rule,
  Value<bool> enabled,
  Value<DateTime?> lastRunAt,
  Value<int> rowid,
});

class $$SchedulesTableFilterComposer
    extends Composer<_$ProfileDb, $SchedulesTable> {
  $$SchedulesTableFilterComposer({
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

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rule => $composableBuilder(
    column: $table.rule,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastRunAt => $composableBuilder(
    column: $table.lastRunAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SchedulesTableOrderingComposer
    extends Composer<_$ProfileDb, $SchedulesTable> {
  $$SchedulesTableOrderingComposer({
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

  ColumnOrderings<String> get rule => $composableBuilder(
    column: $table.rule,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastRunAt => $composableBuilder(
    column: $table.lastRunAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SchedulesTableAnnotationComposer
    extends Composer<_$ProfileDb, $SchedulesTable> {
  $$SchedulesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get rule =>
      $composableBuilder(column: $table.rule, builder: (column) => column);

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<DateTime> get lastRunAt =>
      $composableBuilder(column: $table.lastRunAt, builder: (column) => column);
}

class $$SchedulesTableTableManager
    extends
        RootTableManager<
          _$ProfileDb,
          $SchedulesTable,
          Schedule,
          $$SchedulesTableFilterComposer,
          $$SchedulesTableOrderingComposer,
          $$SchedulesTableAnnotationComposer,
          $$SchedulesTableCreateCompanionBuilder,
          $$SchedulesTableUpdateCompanionBuilder,
          (Schedule, BaseReferences<_$ProfileDb, $SchedulesTable, Schedule>),
          Schedule,
          PrefetchHooks Function()
        > {
  $$SchedulesTableTableManager(_$ProfileDb db, $SchedulesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SchedulesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SchedulesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SchedulesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> rule = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<DateTime?> lastRunAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SchedulesCompanion(
                id: id,
                kind: kind,
                rule: rule,
                enabled: enabled,
                lastRunAt: lastRunAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String kind,
                required String rule,
                Value<bool> enabled = const Value.absent(),
                Value<DateTime?> lastRunAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SchedulesCompanion.insert(
                id: id,
                kind: kind,
                rule: rule,
                enabled: enabled,
                lastRunAt: lastRunAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SchedulesTable, Schedule>(table),
                  BaseReferences<_$ProfileDb, $SchedulesTable, Schedule>(
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

typedef $$SchedulesTableProcessedTableManager =
    ProcessedTableManager<
      _$ProfileDb,
      $SchedulesTable,
      Schedule,
      $$SchedulesTableFilterComposer,
      $$SchedulesTableOrderingComposer,
      $$SchedulesTableAnnotationComposer,
      $$SchedulesTableCreateCompanionBuilder,
      $$SchedulesTableUpdateCompanionBuilder,
      (Schedule, BaseReferences<_$ProfileDb, $SchedulesTable, Schedule>),
      Schedule,
      PrefetchHooks Function()
    >;
typedef $$DependenciesTableCreateCompanionBuilder =
    DependenciesCompanion Function({
      required EntityType dependentType,
      required String dependentId,
      required int dependentRevision,
      required EntityType inputType,
      required String inputId,
      required int inputRevision,
      Value<int> rowid,
    });
typedef $$DependenciesTableUpdateCompanionBuilder =
    DependenciesCompanion Function({
      Value<EntityType> dependentType,
      Value<String> dependentId,
      Value<int> dependentRevision,
      Value<EntityType> inputType,
      Value<String> inputId,
      Value<int> inputRevision,
      Value<int> rowid,
    });

class $$DependenciesTableFilterComposer
    extends Composer<_$ProfileDb, $DependenciesTable> {
  $$DependenciesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnWithTypeConverterFilters<EntityType, EntityType, String>
  get dependentType => $composableBuilder(
    column: $table.dependentType,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get dependentId => $composableBuilder(
    column: $table.dependentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dependentRevision => $composableBuilder(
    column: $table.dependentRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<EntityType, EntityType, String>
  get inputType => $composableBuilder(
    column: $table.inputType,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get inputId => $composableBuilder(
    column: $table.inputId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get inputRevision => $composableBuilder(
    column: $table.inputRevision,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DependenciesTableOrderingComposer
    extends Composer<_$ProfileDb, $DependenciesTable> {
  $$DependenciesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get dependentType => $composableBuilder(
    column: $table.dependentType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dependentId => $composableBuilder(
    column: $table.dependentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dependentRevision => $composableBuilder(
    column: $table.dependentRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get inputType => $composableBuilder(
    column: $table.inputType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get inputId => $composableBuilder(
    column: $table.inputId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get inputRevision => $composableBuilder(
    column: $table.inputRevision,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DependenciesTableAnnotationComposer
    extends Composer<_$ProfileDb, $DependenciesTable> {
  $$DependenciesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumnWithTypeConverter<EntityType, String> get dependentType =>
      $composableBuilder(
        column: $table.dependentType,
        builder: (column) => column,
      );

  GeneratedColumn<String> get dependentId => $composableBuilder(
    column: $table.dependentId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get dependentRevision => $composableBuilder(
    column: $table.dependentRevision,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<EntityType, String> get inputType =>
      $composableBuilder(column: $table.inputType, builder: (column) => column);

  GeneratedColumn<String> get inputId =>
      $composableBuilder(column: $table.inputId, builder: (column) => column);

  GeneratedColumn<int> get inputRevision => $composableBuilder(
    column: $table.inputRevision,
    builder: (column) => column,
  );
}

class $$DependenciesTableTableManager
    extends
        RootTableManager<
          _$ProfileDb,
          $DependenciesTable,
          Dependency,
          $$DependenciesTableFilterComposer,
          $$DependenciesTableOrderingComposer,
          $$DependenciesTableAnnotationComposer,
          $$DependenciesTableCreateCompanionBuilder,
          $$DependenciesTableUpdateCompanionBuilder,
          (
            Dependency,
            BaseReferences<_$ProfileDb, $DependenciesTable, Dependency>,
          ),
          Dependency,
          PrefetchHooks Function()
        > {
  $$DependenciesTableTableManager(_$ProfileDb db, $DependenciesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DependenciesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DependenciesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DependenciesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<EntityType> dependentType = const Value.absent(),
                Value<String> dependentId = const Value.absent(),
                Value<int> dependentRevision = const Value.absent(),
                Value<EntityType> inputType = const Value.absent(),
                Value<String> inputId = const Value.absent(),
                Value<int> inputRevision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DependenciesCompanion(
                dependentType: dependentType,
                dependentId: dependentId,
                dependentRevision: dependentRevision,
                inputType: inputType,
                inputId: inputId,
                inputRevision: inputRevision,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required EntityType dependentType,
                required String dependentId,
                required int dependentRevision,
                required EntityType inputType,
                required String inputId,
                required int inputRevision,
                Value<int> rowid = const Value.absent(),
              }) => DependenciesCompanion.insert(
                dependentType: dependentType,
                dependentId: dependentId,
                dependentRevision: dependentRevision,
                inputType: inputType,
                inputId: inputId,
                inputRevision: inputRevision,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DependenciesTable, Dependency>(table),
                  BaseReferences<_$ProfileDb, $DependenciesTable, Dependency>(
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

typedef $$DependenciesTableProcessedTableManager =
    ProcessedTableManager<
      _$ProfileDb,
      $DependenciesTable,
      Dependency,
      $$DependenciesTableFilterComposer,
      $$DependenciesTableOrderingComposer,
      $$DependenciesTableAnnotationComposer,
      $$DependenciesTableCreateCompanionBuilder,
      $$DependenciesTableUpdateCompanionBuilder,
      (Dependency, BaseReferences<_$ProfileDb, $DependenciesTable, Dependency>),
      Dependency,
      PrefetchHooks Function()
    >;
typedef $$RecomputeQueueTableCreateCompanionBuilder =
    RecomputeQueueCompanion Function({
      Value<int> seq,
      required EntityType entityType,
      required String entityId,
      required String reason,
      required DateTime enqueuedAt,
    });
typedef $$RecomputeQueueTableUpdateCompanionBuilder =
    RecomputeQueueCompanion Function({
      Value<int> seq,
      Value<EntityType> entityType,
      Value<String> entityId,
      Value<String> reason,
      Value<DateTime> enqueuedAt,
    });

class $$RecomputeQueueTableFilterComposer
    extends Composer<_$ProfileDb, $RecomputeQueueTable> {
  $$RecomputeQueueTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<EntityType, EntityType, String>
  get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get enqueuedAt => $composableBuilder(
    column: $table.enqueuedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RecomputeQueueTableOrderingComposer
    extends Composer<_$ProfileDb, $RecomputeQueueTable> {
  $$RecomputeQueueTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get enqueuedAt => $composableBuilder(
    column: $table.enqueuedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RecomputeQueueTableAnnotationComposer
    extends Composer<_$ProfileDb, $RecomputeQueueTable> {
  $$RecomputeQueueTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumnWithTypeConverter<EntityType, String> get entityType =>
      $composableBuilder(
        column: $table.entityType,
        builder: (column) => column,
      );

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);

  GeneratedColumn<DateTime> get enqueuedAt => $composableBuilder(
    column: $table.enqueuedAt,
    builder: (column) => column,
  );
}

class $$RecomputeQueueTableTableManager
    extends
        RootTableManager<
          _$ProfileDb,
          $RecomputeQueueTable,
          RecomputeQueueData,
          $$RecomputeQueueTableFilterComposer,
          $$RecomputeQueueTableOrderingComposer,
          $$RecomputeQueueTableAnnotationComposer,
          $$RecomputeQueueTableCreateCompanionBuilder,
          $$RecomputeQueueTableUpdateCompanionBuilder,
          (
            RecomputeQueueData,
            BaseReferences<
              _$ProfileDb,
              $RecomputeQueueTable,
              RecomputeQueueData
            >,
          ),
          RecomputeQueueData,
          PrefetchHooks Function()
        > {
  $$RecomputeQueueTableTableManager(_$ProfileDb db, $RecomputeQueueTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecomputeQueueTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecomputeQueueTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecomputeQueueTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> seq = const Value.absent(),
                Value<EntityType> entityType = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> reason = const Value.absent(),
                Value<DateTime> enqueuedAt = const Value.absent(),
              }) => RecomputeQueueCompanion(
                seq: seq,
                entityType: entityType,
                entityId: entityId,
                reason: reason,
                enqueuedAt: enqueuedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> seq = const Value.absent(),
                required EntityType entityType,
                required String entityId,
                required String reason,
                required DateTime enqueuedAt,
              }) => RecomputeQueueCompanion.insert(
                seq: seq,
                entityType: entityType,
                entityId: entityId,
                reason: reason,
                enqueuedAt: enqueuedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RecomputeQueueTable, RecomputeQueueData>(table),
                  BaseReferences<
                    _$ProfileDb,
                    $RecomputeQueueTable,
                    RecomputeQueueData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RecomputeQueueTableProcessedTableManager =
    ProcessedTableManager<
      _$ProfileDb,
      $RecomputeQueueTable,
      RecomputeQueueData,
      $$RecomputeQueueTableFilterComposer,
      $$RecomputeQueueTableOrderingComposer,
      $$RecomputeQueueTableAnnotationComposer,
      $$RecomputeQueueTableCreateCompanionBuilder,
      $$RecomputeQueueTableUpdateCompanionBuilder,
      (
        RecomputeQueueData,
        BaseReferences<_$ProfileDb, $RecomputeQueueTable, RecomputeQueueData>,
      ),
      RecomputeQueueData,
      PrefetchHooks Function()
    >;
typedef $$SettingsTableCreateCompanionBuilder = SettingsCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$SettingsTableUpdateCompanionBuilder = SettingsCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$SettingsTableFilterComposer
    extends Composer<_$ProfileDb, $SettingsTable> {
  $$SettingsTableFilterComposer({
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

class $$SettingsTableOrderingComposer
    extends Composer<_$ProfileDb, $SettingsTable> {
  $$SettingsTableOrderingComposer({
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

class $$SettingsTableAnnotationComposer
    extends Composer<_$ProfileDb, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
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

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$ProfileDb,
          $SettingsTable,
          Setting,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (Setting, BaseReferences<_$ProfileDb, $SettingsTable, Setting>),
          Setting,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$ProfileDb db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => SettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) => SettingsCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SettingsTable, Setting>(table),
                  BaseReferences<_$ProfileDb, $SettingsTable, Setting>(
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

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$ProfileDb,
      $SettingsTable,
      Setting,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (Setting, BaseReferences<_$ProfileDb, $SettingsTable, Setting>),
      Setting,
      PrefetchHooks Function()
    >;

class $ProfileDbManager {
  final _$ProfileDb _db;
  $ProfileDbManager(this._db);
  $$IdentitiesTableTableManager get identities =>
      $$IdentitiesTableTableManager(_db, _db.identities);
  $$SourcesTableTableManager get sources =>
      $$SourcesTableTableManager(_db, _db.sources);
  $$SyncCursorsTableTableManager get syncCursors =>
      $$SyncCursorsTableTableManager(_db, _db.syncCursors);
  $$ProjectsTableTableManager get projects =>
      $$ProjectsTableTableManager(_db, _db.projects);
  $$EvidencesTableTableManager get evidences =>
      $$EvidencesTableTableManager(_db, _db.evidences);
  $$PayloadsTableTableManager get payloads =>
      $$PayloadsTableTableManager(_db, _db.payloads);
  $$PayloadRevisionsTableTableManager get payloadRevisions =>
      $$PayloadRevisionsTableTableManager(_db, _db.payloadRevisions);
  $$AttachmentsTableTableManager get attachments =>
      $$AttachmentsTableTableManager(_db, _db.attachments);
  $$EnrichmentsTableTableManager get enrichments =>
      $$EnrichmentsTableTableManager(_db, _db.enrichments);
  $$WorkstreamsTableTableManager get workstreams =>
      $$WorkstreamsTableTableManager(_db, _db.workstreams);
  $$FactsTableTableManager get facts =>
      $$FactsTableTableManager(_db, _db.facts);
  $$FactRevisionsTableTableManager get factRevisions =>
      $$FactRevisionsTableTableManager(_db, _db.factRevisions);
  $$CitationsTableTableManager get citations =>
      $$CitationsTableTableManager(_db, _db.citations);
  $$CurationRulesTableTableManager get curationRules =>
      $$CurationRulesTableTableManager(_db, _db.curationRules);
  $$TemplatesTableTableManager get templates =>
      $$TemplatesTableTableManager(_db, _db.templates);
  $$ReportsTableTableManager get reports =>
      $$ReportsTableTableManager(_db, _db.reports);
  $$ReportSnapshotsTableTableManager get reportSnapshots =>
      $$ReportSnapshotsTableTableManager(_db, _db.reportSnapshots);
  $$TaskRoutesTableTableManager get taskRoutes =>
      $$TaskRoutesTableTableManager(_db, _db.taskRoutes);
  $$JobsTableTableManager get jobs => $$JobsTableTableManager(_db, _db.jobs);
  $$SchedulesTableTableManager get schedules =>
      $$SchedulesTableTableManager(_db, _db.schedules);
  $$DependenciesTableTableManager get dependencies =>
      $$DependenciesTableTableManager(_db, _db.dependencies);
  $$RecomputeQueueTableTableManager get recomputeQueue =>
      $$RecomputeQueueTableTableManager(_db, _db.recomputeQueue);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
}
