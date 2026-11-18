import 'dart:convert';

import 'package:drift/drift.dart';

import '../ai/llm.dart';
import '../ai/structured.dart';
import '../capture/ingestor.dart';
import '../capture/source.dart';
import '../data/profile_db.dart';
import '../domain/enums.dart';
import '../jobs/job_queue.dart';
import '../narrative/interfaces.dart';
import '../ports/ports.dart';
import '../staleness/staleness.dart';
import '../tools/tool.dart';
import '../util/ids.dart';

/// Platform services the engine needs (adapters live in app).
class EnginePorts {
  const EnginePorts({
    required this.secrets,
    required this.blobs,
    required this.git,
    required this.watcher,
    this.calendar,
    this.notifier,
    this.clock = const SystemClock(),
  });
  final SecretStore secrets;
  final BlobStore blobs;
  final GitExecutable git;
  final FileWatcher watcher;
  final CalendarBridge? calendar;
  final Notifier? notifier;
  final Clock clock;
}

/// The only object the app talks to, per active profile (LLD 03 §3.4).
/// Reads: drift data classes via [db]. Writes: only through these commands.
class AntEngine {
  AntEngine({
    required this.db,
    required this.profileId,
    required this.ports,
    required this.router,
    required Duration Function() utcOffset,
  })  : ingestor = Ingestor(db, utcOffset: utcOffset),
        deps = DependencyRecorder(db),
        staleness = StalenessService(db),
        recompute = RecomputeWorker(db),
        jobs = JobQueue(db, clock: ports.clock),
        structured = StructuredOutput(router),
        _utcOffset = utcOffset;

  final ProfileDb db;
  final String profileId;
  final EnginePorts ports;
  final ModelRouter router;
  final Ingestor ingestor;
  final DependencyRecorder deps;
  final StalenessService staleness;
  final RecomputeWorker recompute;
  final JobQueue jobs;
  final StructuredOutput structured;
  final sources = SourceRegistry();
  final enrichments = EnrichmentRegistry();
  final tools = ToolRegistry();
  final Duration Function() _utcOffset;

  ToolContext get toolContext => ToolContext(db: db, profileId: profileId);

  // ---------- Capture commands ----------

  /// Adds a note (#83): standalone evidence on [at]'s day, or attached to [attachTo] evidence.
  Future<String> addNote({
    required String text,
    required DateTime at,
    String? link,
    String? projectId,
    String? attachTo,
    List<String> attachmentPaths = const [],
  }) async {
    final source = await _builtinSource(SourceKind.manualNote, 'Notes');
    final now = ports.clock.now();
    return db.transaction(() async {
      final content = canonicalJson({'text': text, 'link': link, 'attachments': attachmentPaths});
      final evidenceId = attachTo ?? newId(at);
      if (attachTo == null) {
        await db.into(db.evidences).insert(EvidencesCompanion.insert(
          id: evidenceId,
          occurredStart: at.toUtc(),
          day: dayOf(at, _utcOffset()),
          title: text.split('\n').first,
          projectId: Value(projectId),
          createdAt: now,
          updatedAt: now,
        ));
      }
      final payloadId = newId(at);
      await db.into(db.payloads).insert(PayloadsCompanion.insert(
        id: payloadId,
        evidenceId: evidenceId,
        sourceId: source,
        kind: attachmentPaths.isEmpty ? PayloadKind.note : PayloadKind.image,
        externalId: payloadId,
        content: content,
        contentHash: sha256Hex(content),
      ));
      await db.into(db.payloadRevisions).insert(PayloadRevisionsCompanion.insert(
        payloadId: payloadId,
        revision: 1,
        content: content,
        contentHash: sha256Hex(content),
        cause: RevisionCause.user,
        observedAt: now,
      ));
      return evidenceId;
    });
  }

  Future<void> setStarred(String evidenceId, bool starred) =>
      (db.update(db.evidences)..where((e) => e.id.equals(evidenceId))).write(EvidencesCompanion(
        starred: Value(starred),
        importance: Value(starred ? 1.0 : 0.5),
        importanceSetBy: Value(starred ? ImportanceSetBy.user : null),
        updatedAt: Value(ports.clock.now()),
      ));

  Future<void> setHidden(String evidenceId, bool hidden) =>
      (db.update(db.evidences)..where((e) => e.id.equals(evidenceId))).write(EvidencesCompanion(
        hidden: Value(hidden),
        importance: Value(hidden ? 0.0 : 0.5),
        importanceSetBy: Value(hidden ? ImportanceSetBy.user : null),
        updatedAt: Value(ports.clock.now()),
      ));

  // ---------- Narrative commands (user-touched rules, #50 #62 #63) ----------

  Future<void> confirmFact(String factId) => _touchFact(factId, origin: FactOrigin.confirmed);

  Future<void> editFact(String factId, String statement, {Map<String, Object?>? details}) =>
      _touchFact(factId, origin: FactOrigin.userEdited, statement: statement, details: details);

  Future<void> rejectFact(String factId) => db.transaction(() async {
        final f = await _fact(factId);
        await _writeFact(f, origin: FactOrigin.userEdited, retired: true, by: 'user');
      });

  Future<void> setWinStatus(String factId, WinStatus status) =>
      (db.update(db.facts)..where((f) => f.id.equals(factId))).write(FactsCompanion(
        winStatus: Value(status),
        updatedAt: Value(ports.clock.now()),
      ));

  /// Accepts or dismisses a pending model proposal on a user-touched fact.
  Future<void> resolveReview(String factId, {required bool accept}) => db.transaction(() async {
        final f = await _fact(factId);
        if (accept && f.reviewProposal != null) {
          final p = jsonDecode(f.reviewProposal!) as Map<String, Object?>;
          await _writeFact(f,
              origin: f.origin,
              statement: p['statement'] as String?,
              retired: p['retire'] == true,
              by: 'user');
        }
        await (db.update(db.facts)..where((x) => x.id.equals(factId))).write(const FactsCompanion(
          reviewState: Value(ReviewState.ok),
          reviewProposal: Value(null),
        ));
      });

  // ---------- Reports ----------

  Future<void> lockReport(String reportId) => db.transaction(() async {
        final latest = await (db.select(db.reportSnapshots)
              ..where((s) => s.reportId.equals(reportId))
              ..orderBy([(s) => OrderingTerm.desc(s.version)])
              ..limit(1))
            .getSingleOrNull();
        if (latest == null) throw StateError('Nothing to lock: report has no snapshot');
        await (db.update(db.reports)..where((r) => r.id.equals(reportId)))
            .write(ReportsCompanion(locked: const Value(true), lockedSnapshotId: Value(latest.id)));
      });

  Future<void> unlockReport(String reportId) =>
      (db.update(db.reports)..where((r) => r.id.equals(reportId)))
          .write(const ReportsCompanion(locked: Value(false), lockedSnapshotId: Value(null)));

  // ---------- internals ----------

  Future<Fact> _fact(String id) => (db.select(db.facts)..where((f) => f.id.equals(id))).getSingle();

  Future<void> _touchFact(String id, {required FactOrigin origin, String? statement, Map<String, Object?>? details}) =>
      db.transaction(() async {
        final f = await _fact(id);
        await _writeFact(f, origin: origin, statement: statement, details: details, by: 'user');
      });

  /// Bumps the fact revision (fires staleness triggers) and appends a FactRevision.
  Future<void> _writeFact(Fact f,
      {required FactOrigin origin,
      String? statement,
      Map<String, Object?>? details,
      bool? retired,
      required String by}) async {
    final rev = f.revision + 1;
    final now = ports.clock.now();
    final st = statement ?? f.statement;
    final det = details == null ? f.details : canonicalJson(details);
    await (db.update(db.facts)..where((x) => x.id.equals(f.id))).write(FactsCompanion(
      statement: Value(st),
      details: Value(det),
      origin: Value(origin),
      retired: Value(retired ?? f.retired),
      revision: Value(rev),
      updatedAt: Value(now),
    ));
    await db.into(db.factRevisions).insert(FactRevisionsCompanion.insert(
      factId: f.id,
      revision: rev,
      statement: st,
      details: det,
      origin: origin,
      changedBy: by,
      changedAt: now,
    ));
  }

  Future<String> _builtinSource(SourceKind kind, String name) async {
    final existing = await (db.select(db.sources)..where((s) => s.kind.equalsValue(kind))..limit(1)).getSingleOrNull();
    if (existing != null) return existing.id;
    final id = newId();
    await db.into(db.sources).insert(SourcesCompanion.insert(id: id, kind: kind, name: name));
    return id;
  }
}
