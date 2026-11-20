import 'dart:convert';

import 'package:drift/drift.dart';

import '../ai/llm.dart';
import '../ai/structured.dart';
import '../capture/ingestor.dart';
import '../capture/source.dart';
import '../data/profile_db.dart';
import '../domain/enums.dart';
import '../jobs/job_queue.dart';
import '../narrative/fact_writer.dart' show updateWorkstreamSpan;
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
    required Duration Function(DateTime at) utcOffset,
  })  : ingestor = Ingestor(db, utcOffset: utcOffset),
        deps = DependencyRecorder(db),
        staleness = StalenessService(db),
        // Reports regenerate lazily and their staleness is computed (LLD 04 §4.2): queued
        // snapshot rows are only acknowledged, so they don't pile up (#NEXT).
        recompute = RecomputeWorker(db)..on(EntityType.reportSnapshot, (_) async {}),
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
  final Duration Function(DateTime at) _utcOffset;

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
          day: dayOf(at, _utcOffset(at)),
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
        title: Value(text.split('\n').first),
        occurredStart: Value(at.toUtc()),
      ));
      for (final path in attachmentPaths) {
        final bytes = await ports.blobs.get(path);
        await db.into(db.attachments).insert(AttachmentsCompanion.insert(
          id: newId(at),
          payloadId: payloadId,
          path: path,
          mime: switch (path.split('.').last.toLowerCase()) {
            'png' => 'image/png',
            'gif' => 'image/gif',
            'webp' => 'image/webp',
            'heic' => 'image/heic',
            _ => 'image/jpeg',
          },
          sha256: sha256BytesHex(bytes),
          size: bytes.length,
        ));
      }
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

  Future<void> setStarred(String evidenceId, bool starred) => _curate(evidenceId, starred: starred);
  Future<void> setHidden(String evidenceId, bool hidden) => _curate(evidenceId, hidden: hidden);

  /// Importance derives from the combined user state: hidden → 0, starred → 1, else back to model/rule (re-scored).
  /// Starring evidence a rule hid unhides it.
  Future<void> _curate(String id, {bool? starred, bool? hidden}) => db.transaction(() async {
        final e = await (db.select(db.evidences)..where((x) => x.id.equals(id))).getSingle();
        // A star beats a rule's hide (only the user's own hide keeps starred evidence hidden).
        final ruleHidden = e.hidden && e.importanceSetBy == ImportanceSetBy.rule;
        final s = starred ?? e.starred, h = hidden ?? (starred == true && ruleHidden ? false : e.hidden);
        final userSet = s || h;
        await (db.update(db.evidences)..where((x) => x.id.equals(id))).write(EvidencesCompanion(
          starred: Value(s),
          hidden: Value(h),
          importance: Value(h ? 0.0 : (s ? 1.0 : 0.5)),
          importanceSetBy: Value(userSet ? ImportanceSetBy.user : null), // null = re-score by model/rule
          updatedAt: Value(ports.clock.now()),
        ));
        // §4.10 / invariant 9: starring makes an Outcome fact already citing this evidence an accepted win.
        if (starred == true && !e.starred) {
          final facts = await (db.select(db.facts)
                ..where((f) =>
                    f.type.equalsValue(FactType.outcome) &
                    f.retired.equals(false) &
                    f.winStatus.equalsValue(WinStatus.accepted).not() &
                    f.id.isInQuery(db.selectOnly(db.citations).join([
                      innerJoin(db.payloads, db.payloads.id.equalsExp(db.citations.payloadId), useColumns: false),
                    ])
                      ..addColumns([db.citations.factId])
                      ..where(db.payloads.evidenceId.equals(id)))))
              .get();
          for (final f in facts) {
            await _writeFact(f,
                origin: f.origin.isUserTouched ? f.origin : FactOrigin.confirmed,
                winStatus: WinStatus.accepted,
                by: 'user');
          }
        }
      });

  /// User assigns evidence to a project (null = no project). Re-runs its day via the curation trigger.
  Future<void> setEvidenceProject(String evidenceId, String? projectId) =>
      (db.update(db.evidences)..where((x) => x.id.equals(evidenceId)))
          .write(EvidencesCompanion(projectId: Value(projectId), updatedAt: Value(ports.clock.now())));

  // ---------- Projects ----------

  Future<String> createProject(String name, {String? colour}) async {
    final id = newId();
    await db.into(db.projects).insert(ProjectsCompanion.insert(
          id: id,
          name: name,
          colour: colour == null ? const Value.absent() : Value(colour),
        ));
    return id;
  }

  Future<void> updateProject(String id, {String? name, String? colour, bool? archived}) =>
      (db.update(db.projects)..where((p) => p.id.equals(id))).write(ProjectsCompanion(
        name: name == null ? const Value.absent() : Value(name),
        colour: colour == null ? const Value.absent() : Value(colour),
        archived: archived == null ? const Value.absent() : Value(archived),
      ));

  // ---------- Workstreams (user edits mark them user-touched) ----------

  Future<void> renameWorkstream(String id, String title) =>
      (db.update(db.workstreams)..where((w) => w.id.equals(id)))
          .write(WorkstreamsCompanion(title: Value(title), userTouched: const Value(true)));

  /// Moves a fact into [workstreamId] (null = none). Membership isn't fact content, but a model-owned
  /// fact becomes `confirmed` (like setWinStatus) so the assigner never moves it back (#NEXT).
  Future<void> moveFactToWorkstream(String factId, String? workstreamId) => db.transaction(() async {
        final f = await _fact(factId);
        if (!f.origin.isUserTouched) await _writeFact(f, origin: FactOrigin.confirmed, by: 'user');
        await (db.update(db.facts)..where((x) => x.id.equals(factId)))
            .write(FactsCompanion(workstreamId: Value(workstreamId)));
        for (final id in {f.workstreamId, workstreamId}.nonNulls) {
          await _updateSpan(id);
        }
        if (workstreamId != null) {
          await (db.update(db.workstreams)..where((w) => w.id.equals(workstreamId)))
              .write(const WorkstreamsCompanion(userTouched: Value(true)));
        }
      });

  /// Moves every fact of [fromId] into [intoId] and deletes [fromId].
  Future<void> mergeWorkstreams(String fromId, String intoId) => db.transaction(() async {
        if (fromId == intoId) return;
        await (db.update(db.facts)..where((f) => f.workstreamId.equals(fromId)))
            .write(FactsCompanion(workstreamId: Value(intoId)));
        await (db.delete(db.workstreams)..where((w) => w.id.equals(fromId))).go();
        await (db.update(db.workstreams)..where((w) => w.id.equals(intoId)))
            .write(const WorkstreamsCompanion(userTouched: Value(true)));
        await _updateSpan(intoId);
      });

  Future<void> _updateSpan(String workstreamId) => updateWorkstreamSpan(db, workstreamId);

  // ---------- Narrative commands (user-touched rules, #50 #62 #63) ----------

  Future<void> confirmFact(String factId) => _touchFact(factId, origin: FactOrigin.confirmed);

  Future<void> editFact(String factId, String statement, {Map<String, Object?>? details}) =>
      _touchFact(factId, origin: FactOrigin.userEdited, statement: statement, details: details);

  Future<void> rejectFact(String factId) => db.transaction(() async {
        final f = await _fact(factId);
        await _writeFact(f, origin: FactOrigin.userEdited, retired: true, winStatus: WinStatus.rejected, by: 'user');
      });

  Future<void> setWinStatus(String factId, WinStatus status) => db.transaction(() async {
        final f = await _fact(factId);
        final origin = f.origin.isUserTouched ? f.origin : FactOrigin.confirmed;
        await _writeFact(f, origin: origin, winStatus: status, by: 'user');
      });

  /// Accepts or dismisses a pending model proposal on a user-touched fact. Accepting applies the
  /// proposed statement/details/retire and re-pins citations to the proposal's payloads (or the
  /// current ones when it names none) at their current revisions, so the fact isn't left stale.
  Future<void> resolveReview(String factId, {required bool accept}) => db.transaction(() async {
        final f = await _fact(factId);
        if (accept && f.reviewProposal != null) {
          final p = jsonDecode(f.reviewProposal!) as Map<String, Object?>;
          final rev = await _writeFact(f,
              origin: f.origin,
              statement: p['statement'] as String?,
              details: (p['details'] as Map?)?.cast<String, Object?>(),
              retired: p['retire'] == true,
              by: 'user');
          final cited = (p['citations'] as List?)?.whereType<String>().toList() ??
              (await (db.select(db.citations)..where((c) => c.factId.equals(factId))).get())
                  .map((c) => c.payloadId)
                  .toList();
          await _pin(factId, rev, cited);
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

  /// Pins [factId]'s citations to the current revisions of [payloadIds] and re-records the fact's
  /// Dependency rows (same rule as FactWriter in the narrative pipeline).
  Future<void> _pin(String factId, int factRevision, List<String> payloadIds) async {
    final ps = payloadIds.isEmpty
        ? const <Payload>[]
        : await (db.select(db.payloads)..where((p) => p.id.isIn(payloadIds))).get();
    await (db.delete(db.citations)..where((c) => c.factId.equals(factId))).go();
    for (final p in ps) {
      await db
          .into(db.citations)
          .insert(CitationsCompanion.insert(factId: factId, payloadId: p.id, payloadRevision: p.revision));
    }
    await deps.record((type: EntityType.fact, id: factId), factRevision,
        [for (final p in ps) (type: EntityType.payload, id: p.id, revision: p.revision)]);
  }

  /// Bumps the fact revision (fires staleness triggers), appends a FactRevision, returns the new revision.
  Future<int> _writeFact(Fact f,
      {required FactOrigin origin,
      String? statement,
      Map<String, Object?>? details,
      bool? retired,
      WinStatus? winStatus,
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
      winStatus: Value(winStatus ?? f.winStatus),
      revision: Value(rev),
      updatedAt: Value(now),
      // A user write supersedes any pending model proposal.
      reviewState: by == 'user' ? const Value(ReviewState.ok) : const Value.absent(),
      reviewProposal: by == 'user' ? const Value(null) : const Value.absent(),
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
    if (retired != null && retired != f.retired && f.workstreamId != null) await _updateSpan(f.workstreamId!);
    return rev;
  }

  Future<String> _builtinSource(SourceKind kind, String name) async {
    final existing = await (db.select(db.sources)..where((s) => s.kind.equalsValue(kind))..limit(1)).getSingleOrNull();
    if (existing != null) return existing.id;
    final id = newId();
    await db.into(db.sources).insert(SourcesCompanion.insert(id: id, kind: kind, name: name));
    return id;
  }
}
