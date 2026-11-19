import 'package:drift/drift.dart';

import '../data/profile_db.dart';
import '../domain/enums.dart';

typedef EntityRef = ({EntityType type, String id});
typedef InputRef = ({EntityType type, String id, int revision});

/// Records exactly which input revisions a derived row was built from (#61).
/// Call inside the same transaction that writes the derived row.
class DependencyRecorder {
  DependencyRecorder(this.db);
  final ProfileDb db;

  /// Inputs must be revisioned entities: payload, enrichment or fact.
  static const revisioned = {EntityType.payload, EntityType.enrichment, EntityType.fact};

  Future<void> record(EntityRef dependent, int dependentRevision, List<InputRef> inputs) async {
    for (final i in inputs) {
      if (!revisioned.contains(i.type)) throw ArgumentError('Unrevisioned dependency input: ${i.type}');
    }
    await (db.delete(db.dependencies)
          ..where((d) => d.dependentType.equalsValue(dependent.type) & d.dependentId.equals(dependent.id)))
        .go();
    for (final i in inputs) {
      await db.into(db.dependencies).insert(DependenciesCompanion.insert(
        dependentType: dependent.type,
        dependentId: dependent.id,
        dependentRevision: dependentRevision,
        inputType: i.type,
        inputId: i.id,
        inputRevision: i.revision,
      ));
    }
  }
}

/// Staleness is computed, never set by hand (invariant 5).
class StalenessService {
  StalenessService(this.db);
  final ProfileDb db;

  // LEFT JOIN: a recorded input whose row no longer exists (permanent delete) counts as stale.
  static const _sql = '''
SELECT EXISTS (
  SELECT 1 FROM dependencies d LEFT JOIN payloads p ON p.id = d.input_id
  WHERE d.dependent_type = ?1 AND d.dependent_id = ?2 AND d.input_type = 'payload'
    AND (p.id IS NULL OR p.revision <> d.input_revision)
  UNION ALL
  SELECT 1 FROM dependencies d LEFT JOIN facts f ON f.id = d.input_id
  WHERE d.dependent_type = ?1 AND d.dependent_id = ?2 AND d.input_type = 'fact'
    AND (f.id IS NULL OR f.revision <> d.input_revision)
  UNION ALL
  SELECT 1 FROM dependencies d LEFT JOIN enrichments n ON n.id = d.input_id
  WHERE d.dependent_type = ?1 AND d.dependent_id = ?2 AND d.input_type = 'enrichment'
    AND (n.id IS NULL OR n.revision <> d.input_revision)
) AS stale''';

  Selectable<bool> _query(EntityRef ref) => db
      .customSelect(_sql,
          variables: [Variable.withString(ref.type.name), Variable.withString(ref.id)],
          readsFrom: {db.dependencies, db.payloads, db.facts, db.enrichments})
      .map((r) => r.read<bool>('stale'));

  Future<bool> isStale(EntityRef ref) => _query(ref).getSingle();
  Stream<bool> watch(EntityRef ref) => _query(ref).watchSingle();
}

/// Handles one dirty entity. Must not touch the queue rows it was called for. Runs outside any
/// transaction so model calls don't hold the SQLite write lock: read inputs, call the model, then
/// write in a short transaction after re-checking the inputs are unchanged (else discard and
/// re-queue). Must be idempotent: a crash before the worker removes the queue rows re-runs it.
typedef RecomputeHandler = Future<void> Function(String entityId);

/// Drains the recompute queue (LLD 04 §4.2): de-duplicated, oldest first.
class RecomputeWorker {
  RecomputeWorker(this.db);
  final ProfileDb db;
  final _handlers = <EntityType, RecomputeHandler>{};

  void on(EntityType type, RecomputeHandler handler) => _handlers[type] = handler;

  /// Returns the number of entities processed. Entries whose type has no handler stay queued (#61).
  Future<int> drain() async {
    var processed = 0;
    while (true) {
      if (_handlers.isEmpty) return processed;
      final next = await (db.select(db.recomputeQueue)
            ..where((q) => q.entityType.isIn(_handlers.keys.map((t) => t.name)))
            ..orderBy([(q) => OrderingTerm.asc(q.seq)])
            ..limit(1))
          .getSingleOrNull();
      if (next == null) return processed;
      // De-duplicate: everything queued for this entity so far is covered by this run;
      // rows enqueued during the handler (seq > maxSeq) are processed on a later pass.
      final maxSeq = await db
          .customSelect('SELECT MAX(seq) AS m FROM recompute_queue WHERE entity_type = ? AND entity_id = ?',
              variables: [Variable.withString(next.entityType.name), Variable.withString(next.entityId)])
          .map((r) => r.read<int>('m'))
          .getSingle();
      await _handlers[next.entityType]!(next.entityId);
      // Only after the handler's writes have committed (invariant 5): a crash before this re-runs it.
      await (db.delete(db.recomputeQueue)
            ..where((q) =>
                q.entityType.equalsValue(next.entityType) &
                q.entityId.equals(next.entityId) &
                q.seq.isSmallerOrEqualValue(maxSeq)))
          .go();
      processed++;
    }
  }
}
