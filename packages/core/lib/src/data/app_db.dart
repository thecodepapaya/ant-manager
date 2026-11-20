import 'package:drift/drift.dart';

import '../domain/enums.dart';

part 'app_db.g.dart';

/// App-wide database: profiles and global providers/models (#64).

class Profiles extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get colour => text().withDefault(const Constant('#E8A54B'))();
  TextColumn get timeZone => text()(); // IANA name, defaults to system (#87)
  BoolColumn get active => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
}

class Providers extends Table {
  TextColumn get id => text()();
  TextColumn get kind => textEnum<ProviderKind>()();
  TextColumn get name => text()();
  TextColumn get baseUrl => text()();
  TextColumn get protocol => textEnum<ProviderProtocol>()();
  TextColumn get credentialRef => text().nullable()();
  TextColumn get headers => text().withDefault(const Constant('{}'))(); // JSON, values are SecretStore refs
  TextColumn get customCaPem => text().nullable()();
  BoolColumn get allowSelfSigned => boolean().withDefault(const Constant(false))();
  IntColumn get timeoutSeconds => integer().withDefault(const Constant(120))();
  BoolColumn get consentGiven => boolean().withDefault(const Constant(false))();
  @override
  Set<Column> get primaryKey => {id};
}

class Models extends Table {
  TextColumn get id => text()();
  TextColumn get providerId => text().references(Providers, #id)();
  TextColumn get modelName => text()();
  BoolColumn get vision => boolean().withDefault(const Constant(false))();
  IntColumn get contextLength => integer().withDefault(const Constant(8192))();
  /// Verified by probe on add (#70). Models without it are never stored.
  BoolColumn get structuredOutput => boolean().withDefault(const Constant(true))();
  RealColumn get inputPricePerMTok => real().nullable()();
  RealColumn get outputPricePerMTok => real().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Profiles, Providers, Models])
class AppDb extends _$AppDb {
  AppDb(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await customStatement('PRAGMA journal_mode = WAL');
    },
  );
}
