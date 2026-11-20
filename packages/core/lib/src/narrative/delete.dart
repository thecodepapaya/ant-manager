import 'package:drift/drift.dart';

import '../data/profile_db.dart';
import '../domain/enums.dart';
import 'context.dart';
import 'day_input.dart';
import 'fact_writer.dart';

/// "Delete permanently" (LLD 04 §4.12, #85): the one exception to never deleting history.
/// One transaction. Returns the attachment paths to delete from the BlobStore **after** it commits.
class EvidenceDeleter {
  EvidenceDeleter(this.ctx) : writer = FactWriter(ctx);
  final NarrativeContext ctx;
  final FactWriter writer;
  ProfileDb get db => ctx.db;

  /// Every BlobStore path a row still points at: `attachments` rows and payload `attachments` lists,
  /// the same two places [permanentDelete] collects from. The engine's startup orphan sweep keeps
  /// these and deletes any other blob file (#NEXT).
  static Future<Set<String>> referencedBlobPaths(ProfileDb db) async => {
    ...(await db.select(db.attachments).get()).map((a) => a.path),
    for (final p in await db.select(db.payloads).get())
      if (contentOf(p)['attachments'] case final List a) ...a.whereType<String>(),
  };

  Future<List<String>> permanentDelete(String evidenceId) => db.transaction(() async {
    final e = await (db.select(db.evidences)..where((x) => x.id.equals(evidenceId))).getSingleOrNull();
    if (e == null) return const <String>[];
    final payloads = await (db.select(db.payloads)..where((p) => p.evidenceId.equals(evidenceId))).get();
    final pids = payloads.map((p) => p.id).toList();

    // 1. Payload-derived rows, then payloads (FTS rows go via the delete trigger) and the evidence.
    final paths = <String>{
      for (final p in payloads) ...((contentOf(p)['attachments'] as List?) ?? const []).whereType<String>(),
      ...(await (db.select(db.attachments)..where((a) => a.payloadId.isIn(pids))).get()).map((a) => a.path),
    };
    final enrichments =
        await (db.select(db.enrichments)..where(
              (n) =>
                  (n.targetType.equalsValue(EntityType.payload) & n.targetId.isIn(pids)) |
                  (n.targetType.equalsValue(EntityType.evidence) & n.targetId.equals(evidenceId)),
            ))
            .get();
    final enrIds = enrichments.map((n) => n.id).toList();
    final affected = (await (db.select(
      db.citations,
    )..where((c) => c.payloadId.isIn(pids))).get()).map((c) => c.factId).toSet();

    await (db.delete(db.citations)..where((c) => c.payloadId.isIn(pids))).go();
    await (db.delete(db.attachments)..where((a) => a.payloadId.isIn(pids))).go();
    await (db.delete(db.payloadRevisions)..where((r) => r.payloadId.isIn(pids))).go();
    await (db.delete(db.enrichments)..where((n) => n.id.isIn(enrIds))).go();
    await (db.delete(db.dependencies)..where(
          // Rows the deleted entities own, plus facts' rows on them (those follow the citations just
          // dropped; affected facts are handled below). Other dependents (e.g. report snapshots) keep
          // their rows, so the missing input reads as stale.
          (d) =>
              (d.dependentType.equalsValue(EntityType.fact) &
                  d.inputType.equalsValue(EntityType.payload) &
                  d.inputId.isIn(pids)) |
              (d.dependentType.equalsValue(EntityType.enrichment) & d.dependentId.isIn(enrIds)) |
              (d.dependentType.equalsValue(EntityType.evidence) & d.dependentId.equals(evidenceId)),
        ))
        .go();
    await (db.delete(db.recomputeQueue)..where(
          (q) =>
              (q.entityType.equalsValue(EntityType.payload) & q.entityId.isIn(pids)) |
              (q.entityType.equalsValue(EntityType.enrichment) & q.entityId.isIn(enrIds)) |
              (q.entityType.equalsValue(EntityType.evidence) & q.entityId.equals(evidenceId)),
        ))
        .go();
    await (db.delete(db.payloads)..where((p) => p.id.isIn(pids))).go();
    await (db.delete(db.evidences)..where((x) => x.id.equals(evidenceId))).go();

    // 2./3. Facts that cited them: no citations left → delete with history; else re-extract or flag.
    final days = {e.day};
    for (final factId in affected) {
      final f = await (db.select(db.facts)..where((x) => x.id.equals(factId))).getSingle();
      days.add(f.periodStart);
      final left = await (db.select(db.citations)..where((c) => c.factId.equals(factId))).get();
      if (left.isEmpty) {
        // Dependents (reports, workstreams) of the deleted fact are told; their own Dependency
        // rows on it are kept so the report can still see what it was built from.
        await db.customStatement(
          'INSERT INTO recompute_queue(entity_type, entity_id, reason, enqueued_at) '
          "SELECT dependent_type, dependent_id, 'fact deleted ' || ?1, unixepoch() FROM dependencies "
          "WHERE input_type = 'fact' AND input_id = ?1",
          [factId],
        );
        await (db.delete(db.factRevisions)..where((r) => r.factId.equals(factId))).go();
        await (db.delete(
          db.dependencies,
        )..where((d) => d.dependentType.equalsValue(EntityType.fact) & d.dependentId.equals(factId))).go();
        await (db.delete(
          db.recomputeQueue,
        )..where((q) => q.entityType.equalsValue(EntityType.fact) & q.entityId.equals(factId))).go();
        await (db.delete(db.facts)..where((x) => x.id.equals(factId))).go();
        if (f.workstreamId != null) await updateWorkstreamSpan(db, f.workstreamId!);
      } else if (isProtected(f)) {
        await writer.propose(f, {'op': 'review', 'retire': false, 'reason': 'some cited evidence was deleted'});
      }
      // Model-owned facts with citations left are re-extracted with their day (below).
    }
    for (final d in days) {
      await DayInput.forget(db, d);
      await ctx.enqueue(EntityType.day, d, 'evidence deleted $evidenceId');
    }
    return paths.toList();
  });
}
