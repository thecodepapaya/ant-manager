import '../data/profile_db.dart';
import '../domain/enums.dart';
import '../engine/engine.dart';
import 'context.dart';
import 'day_input.dart';
import 'enrichment.dart';
import 'extractor.dart';
import 'fact_writer.dart';
import 'importance.dart';
import 'interfaces.dart';
import 'reconciler.dart';
import 'time_allocation.dart';
import 'workstreams.dart';

/// The per-day narrative pipeline (LLD 04 §4.2): importance → enrichment → extraction + reconcile →
/// time allocation → workstreams. Every stage is idempotent and writes only on change, so the
/// re-queues caused by its own writes (curation and enrichment triggers) end in a cheap no-op pass.
class NarrativePipeline {
  NarrativePipeline(this.ctx, {EnrichmentRegistry? enrichments, FactExtractor? extractor})
    : enrichments = enrichments ?? (EnrichmentRegistry()..registerAll(defaultEnrichmentStrategies(ctx))),
      importance = ImportanceScorer(ctx),
      extractor = extractor ?? LlmFactExtractor(ctx),
      reconciler = FactReconciler(ctx),
      time = TimeAllocator(ctx),
      workstreams = WorkstreamAssigner(ctx);

  final NarrativeContext ctx;
  final EnrichmentRegistry enrichments;
  final ImportanceScorer importance;
  final FactExtractor extractor;
  final FactReconciler reconciler;
  final TimeAllocator time;
  final WorkstreamAssigner workstreams;
  ProfileDb get db => ctx.db;

  /// Result of the last extraction per day (for logs and evals); null when it was skipped.
  final lastReconcile = <String, ReconcileResult?>{};

  /// Runs outside any transaction: model calls happen between short write transactions, and each
  /// write re-checks its inputs (LLD 04 §4.2).
  Future<void> runDay(String day) async {
    await importance.scoreDay(day);
    await Enricher(ctx, enrichments).enrichDay(day);
    final input = await DayInput.load(db, day);
    final current = await input.isCurrent(db);
    lastReconcile[day] = null;
    if (!current) {
      final cs = await extractor.extract(day);
      final applied = await db.transaction(() async {
        // The day's inputs moved during the model call: discard and re-queue the day.
        if ((await DayInput.load(db, day)).fingerprint != input.fingerprint) return false;
        lastReconcile[day] = await reconciler.apply(cs);
        // Committed with the facts, so a failure before workstream assignment retries it.
        await db.into(db.settings).insertOnConflictUpdate(SettingsCompanion.insert(key: _wsKey(day), value: '1'));
        return true;
      });
      if (!applied) return ctx.enqueue(EntityType.day, day, 'inputs changed during extraction');
    }
    await db.transaction(() => time.computeDay(day));
    // Only after a real extraction: facts the model left unassigned aren't re-asked on no-op passes.
    final key = _wsKey(day);
    if (await (db.select(db.settings)..where((s) => s.key.equals(key))).getSingleOrNull() != null) {
      await workstreams.assignDay(day);
      await (db.delete(db.settings)..where((s) => s.key.equals(key))).go();
    }
  }

  static String _wsKey(String day) => 'narrative.workstreams_pending.$day';

  Future<void> onEvidence(String evidenceId) async {
    final e = await (db.select(db.evidences)..where((x) => x.id.equals(evidenceId))).getSingleOrNull();
    if (e != null) await runDay(e.day);
  }

  Future<void> onEnrichment(String enrichmentId) async {
    final n = await (db.select(db.enrichments)..where((x) => x.id.equals(enrichmentId))).getSingleOrNull();
    if (n == null) return;
    final evidenceId = n.targetType == EntityType.evidence
        ? n.targetId
        : (await (db.select(db.payloads)..where((p) => p.id.equals(n.targetId))).getSingleOrNull())?.evidenceId;
    if (evidenceId != null) await onEvidence(evidenceId);
  }

  /// A fact's cited payload changed. User-touched facts are flagged for review instead of being
  /// re-extracted (invariant 7); then the fact's day is re-run.
  Future<void> onFact(String factId) async {
    final f = await (db.select(db.facts)..where((x) => x.id.equals(factId))).getSingleOrNull();
    if (f == null) return;
    if (isProtected(f) && f.reviewState == ReviewState.ok && await ctx.isStale(EntityType.fact, f.id)) {
      await FactWriter(ctx).propose(f, {'op': 'review', 'retire': false, 'reason': 'cited evidence changed'});
    }
    await runDay(f.periodStart);
  }
}

extension on EnrichmentRegistry {
  void registerAll(List<EnrichmentStrategy> list) => list.forEach(register);
}

/// Wires the narrative pipeline into [e]'s RecomputeWorker (debouncing is the caller's concern) and
/// registers the default enrichment strategies on [e.enrichments]. Returns the pipeline.
NarrativePipeline registerNarrativePipeline(AntEngine e) {
  final ctx = NarrativeContext.of(e);
  e.enrichments.registerAll(defaultEnrichmentStrategies(ctx));
  final p = NarrativePipeline(ctx, enrichments: e.enrichments);
  e.recompute
    ..on(EntityType.day, p.runDay)
    ..on(EntityType.evidence, p.onEvidence)
    ..on(EntityType.enrichment, p.onEnrichment)
    ..on(EntityType.fact, p.onFact);
  return p;
}
