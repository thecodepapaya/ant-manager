import 'package:drift/drift.dart';

import '../domain/enums.dart';

part 'profile_db.g.dart';

/// Per-profile database (LLD 02). Everything except Profile/Provider/Model lives here.
/// Read models are the generated data classes (#71); writes go only through AntEngine.

class Identities extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text()(); // email, github_login, gitlab_user, jira_account, linear_user
  TextColumn get value => text()();
  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SourceRow')
class Sources extends Table {
  TextColumn get id => text()();
  TextColumn get kind => textEnum<SourceKind>()();
  TextColumn get name => text()();
  TextColumn get config => text().withDefault(const Constant('{}'))(); // JSON
  TextColumn get credentialRef => text().nullable()(); // SecretStore key
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  @override
  Set<Column> get primaryKey => {id};
}

class SyncCursors extends Table {
  TextColumn get sourceId => text().references(Sources, #id)();
  TextColumn get scope => text().withDefault(const Constant(''))();
  TextColumn get cursor => text().nullable()();
  DateTimeColumn get lastSuccessAt => dateTime().nullable()();
  TextColumn get lastError => text().nullable()();
  @override
  Set<Column> get primaryKey => {sourceId, scope};
}

class Projects extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get colour => text().withDefault(const Constant('#E8A54B'))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  @override
  Set<Column> get primaryKey => {id};
}

class Evidences extends Table {
  TextColumn get id => text()();
  DateTimeColumn get occurredStart => dateTime()();
  DateTimeColumn get occurredEnd => dateTime().nullable()();
  /// Local date (YYYY-MM-DD) in the profile time zone, set at ingest (#87).
  TextColumn get day => text()();
  TextColumn get title => text()();
  TextColumn get projectId => text().nullable().references(Projects, #id)();
  BoolColumn get starred => boolean().withDefault(const Constant(false))();
  BoolColumn get hidden => boolean().withDefault(const Constant(false))();
  RealColumn get importance => real().withDefault(const Constant(0.5))();
  TextColumn get importanceReason => text().nullable()();
  TextColumn get importanceSetBy => textEnum<ImportanceSetBy>().nullable()(); // null = unscored
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
}

class Payloads extends Table {
  TextColumn get id => text()();
  TextColumn get evidenceId => text().references(Evidences, #id)();
  TextColumn get sourceId => text().references(Sources, #id)();
  TextColumn get kind => textEnum<PayloadKind>()();
  TextColumn get externalId => text()();
  TextColumn get title => text().nullable()(); // used to re-title evidence on tombstone (§4.1)
  // Used with title to re-time evidence on tombstone (§4.1, #NEXT). Null on rows from schema v1.
  DateTimeColumn get occurredStart => dateTime().nullable()();
  DateTimeColumn get occurredEnd => dateTime().nullable()();
  TextColumn get content => text()(); // canonical JSON
  TextColumn get contentHash => text()();
  /// Exact-identity grouping key (iCal UID, commit SHA). Null = never auto-grouped.
  TextColumn get groupKey => text().nullable()();
  IntColumn get revision => integer().withDefault(const Constant(1))();
  DateTimeColumn get tombstonedAt => dateTime().nullable()();
  @override
  Set<Column> get primaryKey => {id};
  @override
  List<Set<Column>> get uniqueKeys => [
    {sourceId, externalId},
  ];
}

class PayloadRevisions extends Table {
  TextColumn get payloadId => text().references(Payloads, #id)();
  IntColumn get revision => integer()();
  TextColumn get content => text()();
  TextColumn get contentHash => text()();
  TextColumn get cause => textEnum<RevisionCause>()();
  DateTimeColumn get observedAt => dateTime()();
  @override
  Set<Column> get primaryKey => {payloadId, revision};
}

class Attachments extends Table {
  TextColumn get id => text()();
  TextColumn get payloadId => text().references(Payloads, #id)();
  TextColumn get path => text()(); // relative to BlobStore root
  TextColumn get mime => text()();
  TextColumn get sha256 => text()();
  IntColumn get size => integer()();
  @override
  Set<Column> get primaryKey => {id};
}

class Enrichments extends Table {
  TextColumn get id => text()();
  TextColumn get targetType => textEnum<EntityType>()(); // payload | evidence
  TextColumn get targetId => text()();
  TextColumn get kind => text()(); // summary, image_description, transcript_summary
  TextColumn get output => text()();
  TextColumn get modelId => text()();
  IntColumn get revision => integer().withDefault(const Constant(1))();
  DateTimeColumn get createdAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
}

class Workstreams extends Table {
  TextColumn get id => text()();
  TextColumn get projectId => text().nullable().references(Projects, #id)();
  TextColumn get title => text()();
  TextColumn get summary => text().withDefault(const Constant(''))();
  TextColumn get spanStart => text().nullable()(); // day
  TextColumn get spanEnd => text().nullable()();
  BoolColumn get userTouched => boolean().withDefault(const Constant(false))();
  @override
  Set<Column> get primaryKey => {id};
}

class Facts extends Table {
  TextColumn get id => text()();
  TextColumn get type => textEnum<FactType>()();
  TextColumn get statement => text()();
  TextColumn get details => text().withDefault(const Constant('{}'))(); // JSON
  TextColumn get periodStart => text()(); // day
  TextColumn get periodEnd => text()(); // day
  TextColumn get workstreamId => text().nullable().references(Workstreams, #id)();
  TextColumn get projectId => text().nullable().references(Projects, #id)();
  RealColumn get importance => real().withDefault(const Constant(0.5))();
  TextColumn get origin => textEnum<FactOrigin>()();
  TextColumn get reviewState => textEnum<ReviewState>().withDefault(Constant(ReviewState.ok.name))();
  /// Pending model proposal for a user-touched fact (JSON), shown in the review queue.
  TextColumn get reviewProposal => text().nullable()();
  TextColumn get winStatus => textEnum<WinStatus>().withDefault(Constant(WinStatus.none.name))();
  BoolColumn get retired => boolean().withDefault(const Constant(false))();
  IntColumn get revision => integer().withDefault(const Constant(1))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
}

class FactRevisions extends Table {
  TextColumn get factId => text().references(Facts, #id)();
  IntColumn get revision => integer()();
  TextColumn get statement => text()();
  TextColumn get details => text()();
  TextColumn get origin => textEnum<FactOrigin>()();
  TextColumn get changedBy => text()(); // model | user
  DateTimeColumn get changedAt => dateTime()();
  @override
  Set<Column> get primaryKey => {factId, revision};
}

class Citations extends Table {
  TextColumn get factId => text().references(Facts, #id)();
  TextColumn get payloadId => text().references(Payloads, #id)();
  IntColumn get payloadRevision => integer()();
  TextColumn get locator => text().nullable()();
  @override
  Set<Column> get primaryKey => {factId, payloadId};
}

class CurationRules extends Table {
  TextColumn get id => text()();
  TextColumn get match => text()(); // JSON: {sourceKind?, titlePattern?, repo?, minAttendees?, maxAttendees?}
  TextColumn get action => textEnum<CurationAction>()();
  RealColumn get value => real().withDefault(const Constant(0))();
  IntColumn get priority => integer().withDefault(const Constant(0))();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  @override
  Set<Column> get primaryKey => {id};
}

class Templates extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get periodKinds => text()(); // comma-separated PeriodKind names
  TextColumn get prompt => text()();
  BoolColumn get builtIn => boolean().withDefault(const Constant(false))();
  IntColumn get version => integer().withDefault(const Constant(1))();
  @override
  Set<Column> get primaryKey => {id};
}

class Reports extends Table {
  TextColumn get id => text()();
  TextColumn get periodKind => textEnum<PeriodKind>()();
  TextColumn get periodStart => text()(); // day
  TextColumn get periodEnd => text()(); // day
  TextColumn get templateId => text().references(Templates, #id)();
  BoolColumn get locked => boolean().withDefault(const Constant(false))();
  TextColumn get lockedSnapshotId => text().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

class ReportSnapshots extends Table {
  TextColumn get id => text()();
  TextColumn get reportId => text().references(Reports, #id)();
  IntColumn get version => integer()();
  TextColumn get json => text()(); // structured output (#92)
  TextColumn get markdown => text()();
  TextColumn get modelId => text()();
  TextColumn get styleInstruction => text().nullable()();
  DateTimeColumn get generatedAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
}

class TaskRoutes extends Table {
  TextColumn get route => textEnum<LlmRoute>()();
  TextColumn get modelId => text().nullable()(); // null = inherit default (#75)
  @override
  Set<Column> get primaryKey => {route};
}

class Jobs extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text()();
  TextColumn get args => text().withDefault(const Constant('{}'))();
  TextColumn get lane => textEnum<JobLane>()();
  TextColumn get state => textEnum<JobState>()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  DateTimeColumn get runAfter => dateTime()();
  DateTimeColumn get leaseUntil => dateTime().nullable()();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
}

class Schedules extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text()(); // report:daily, report:weekly, backup, ...
  TextColumn get rule => text()(); // JSON: {hour, minute, weekdays?, monthDay?, quarterly?}
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  DateTimeColumn get lastRunAt => dateTime().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

/// Exactly which input revisions a derived row was built from (#61).
class Dependencies extends Table {
  TextColumn get dependentType => textEnum<EntityType>()();
  TextColumn get dependentId => text()();
  IntColumn get dependentRevision => integer()();
  TextColumn get inputType => textEnum<EntityType>()();
  TextColumn get inputId => text()();
  IntColumn get inputRevision => integer()();
  @override
  Set<Column> get primaryKey => {dependentType, dependentId, inputType, inputId};
}

/// Written by triggers in the same transaction as the change (#61).
class RecomputeQueue extends Table {
  IntColumn get seq => integer().autoIncrement()();
  TextColumn get entityType => textEnum<EntityType>()();
  TextColumn get entityId => text()();
  TextColumn get reason => text()();
  DateTimeColumn get enqueuedAt => dateTime()();
}

class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(
  tables: [
    Identities, Sources, SyncCursors, Projects, Evidences, Payloads, PayloadRevisions, Attachments,
    Enrichments, Workstreams, Facts, FactRevisions, Citations, CurationRules, Templates, Reports,
    ReportSnapshots, TaskRoutes, Jobs, Schedules, Dependencies, RecomputeQueue, Settings,
  ],
)
class ProfileDb extends _$ProfileDb {
  ProfileDb(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      for (final sql in profileDbExtraSql) {
        await customStatement(sql);
      }
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(payloads, payloads.occurredStart);
        await m.addColumn(payloads, payloads.occurredEnd);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await customStatement('PRAGMA journal_mode = WAL');
    },
  );
}

/// Indexes, FTS5 (#52) and staleness triggers (#61). Drift stores DateTime as unix seconds.
const profileDbExtraSql = <String>[
  'CREATE INDEX idx_evidence_day ON evidences(day)',
  'CREATE INDEX idx_payload_evidence ON payloads(evidence_id)',
  'CREATE INDEX idx_payload_group ON payloads(group_key)',
  'CREATE INDEX idx_fact_period ON facts(period_start, period_end)',
  'CREATE INDEX idx_dep_input ON dependencies(input_type, input_id)',
  'CREATE INDEX idx_jobs_ready ON jobs(state, lane, run_after)',
  // Full-text index over payload text values and facts.
  "CREATE VIRTUAL TABLE fts_payloads USING fts5(payload_id UNINDEXED, content, tokenize='unicode61')",
  "CREATE VIRTUAL TABLE fts_facts USING fts5(fact_id UNINDEXED, statement, tokenize='unicode61')",
  // Only the payload's string values are indexed, not JSON keys, escapes or literals.
  '''CREATE TRIGGER fts_payload_ins AFTER INSERT ON payloads BEGIN
       INSERT INTO fts_payloads(payload_id, content)
       SELECT NEW.id, coalesce(group_concat(value, ' '), '') FROM json_tree(NEW.content) WHERE type = 'text'; END''',
  '''CREATE TRIGGER fts_payload_upd AFTER UPDATE OF content ON payloads BEGIN
       DELETE FROM fts_payloads WHERE payload_id = OLD.id;
       INSERT INTO fts_payloads(payload_id, content)
       SELECT NEW.id, coalesce(group_concat(value, ' '), '') FROM json_tree(NEW.content) WHERE type = 'text'; END''',
  '''CREATE TRIGGER fts_payload_del AFTER DELETE ON payloads BEGIN
       DELETE FROM fts_payloads WHERE payload_id = OLD.id; END''',
  '''CREATE TRIGGER fts_payload_tomb AFTER UPDATE OF tombstoned_at ON payloads WHEN NEW.tombstoned_at IS NOT NULL BEGIN
       DELETE FROM fts_payloads WHERE payload_id = NEW.id; END''',
  '''CREATE TRIGGER fts_fact_ins AFTER INSERT ON facts BEGIN
       INSERT INTO fts_facts(fact_id, statement) VALUES (NEW.id, NEW.statement); END''',
  '''CREATE TRIGGER fts_fact_upd AFTER UPDATE OF statement ON facts BEGIN
       DELETE FROM fts_facts WHERE fact_id = OLD.id;
       INSERT INTO fts_facts(fact_id, statement) VALUES (NEW.id, NEW.statement); END''',
  '''CREATE TRIGGER fts_fact_del AFTER DELETE ON facts BEGIN
       DELETE FROM fts_facts WHERE fact_id = OLD.id; END''',
  // Staleness: new payload → its evidence's day.
  '''CREATE TRIGGER stale_payload_ins AFTER INSERT ON payloads BEGIN
       INSERT INTO recompute_queue(entity_type, entity_id, reason, enqueued_at)
       SELECT 'day', e.day, 'payload added ' || NEW.id, unixepoch() FROM evidences e WHERE e.id = NEW.evidence_id; END''',
  // Staleness: payload revision bump → dependents + its day.
  '''CREATE TRIGGER stale_payload_rev AFTER UPDATE OF revision ON payloads BEGIN
       INSERT INTO recompute_queue(entity_type, entity_id, reason, enqueued_at)
       SELECT d.dependent_type, d.dependent_id, 'payload ' || NEW.id || ' r' || NEW.revision, unixepoch()
       FROM dependencies d WHERE d.input_type = 'payload' AND d.input_id = NEW.id;
       INSERT INTO recompute_queue(entity_type, entity_id, reason, enqueued_at)
       SELECT 'day', e.day, 'payload changed ' || NEW.id, unixepoch() FROM evidences e WHERE e.id = NEW.evidence_id; END''',
  // Staleness: payload moved between evidence (merge/split) → old and new day.
  '''CREATE TRIGGER stale_payload_move AFTER UPDATE OF evidence_id ON payloads BEGIN
       INSERT INTO recompute_queue(entity_type, entity_id, reason, enqueued_at)
       SELECT 'day', e.day, 'payload moved ' || NEW.id, unixepoch() FROM evidences e
       WHERE e.id IN (OLD.evidence_id, NEW.evidence_id); END''',
  // Staleness: evidence moved to another day (rescheduled) → old and new day.
  '''CREATE TRIGGER stale_evidence_day AFTER UPDATE OF day ON evidences WHEN OLD.day IS NOT NEW.day BEGIN
       INSERT INTO recompute_queue(entity_type, entity_id, reason, enqueued_at)
       VALUES ('day', OLD.day, 'evidence moved ' || NEW.id, unixepoch()), ('day', NEW.day, 'evidence moved ' || NEW.id, unixepoch()); END''',
  // Staleness: curation of evidence → its day.
  '''CREATE TRIGGER stale_evidence_curation AFTER UPDATE OF starred, hidden, importance, project_id ON evidences
       WHEN OLD.starred IS NOT NEW.starred OR OLD.hidden IS NOT NEW.hidden
         OR OLD.importance IS NOT NEW.importance OR OLD.project_id IS NOT NEW.project_id BEGIN
       INSERT INTO recompute_queue(entity_type, entity_id, reason, enqueued_at)
       VALUES ('day', NEW.day, 'evidence curated ' || NEW.id, unixepoch()); END''',
  // Staleness: enrichment revision bump → dependents (facts).
  '''CREATE TRIGGER stale_enrichment_rev AFTER UPDATE OF revision ON enrichments BEGIN
       INSERT INTO recompute_queue(entity_type, entity_id, reason, enqueued_at)
       SELECT d.dependent_type, d.dependent_id, 'enrichment ' || NEW.id || ' r' || NEW.revision, unixepoch()
       FROM dependencies d WHERE d.input_type = 'enrichment' AND d.input_id = NEW.id; END''',
  // Staleness: fact revision bump → dependents (reports, workstreams).
  '''CREATE TRIGGER stale_fact_rev AFTER UPDATE OF revision ON facts BEGIN
       INSERT INTO recompute_queue(entity_type, entity_id, reason, enqueued_at)
       SELECT d.dependent_type, d.dependent_id, 'fact ' || NEW.id || ' r' || NEW.revision, unixepoch()
       FROM dependencies d WHERE d.input_type = 'fact' AND d.input_id = NEW.id; END''',
];
