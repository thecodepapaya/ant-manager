import 'package:drift/drift.dart';

import '../data/profile_db.dart';
import '../domain/enums.dart';
import '../staleness/staleness.dart';
import '../util/ids.dart';

/// One evidence item of a day with its live payloads and their enrichments.
class DayItem {
  DayItem(this.evidence, this.payloads, this.enrichments);
  final Evidence evidence;
  final List<Payload> payloads; // live (not tombstoned)
  final Map<String, Enrichment> enrichments; // by payload id
}

/// Everything fact extraction reads for a day (LLD 04 §4.6): non-hidden evidence with live payloads,
/// ordered by importance. The extractor and the reconciler load the same set, so "payloads in the
/// input" is well defined for citation checks.
class DayInput {
  DayInput(this.day, this.items);
  final String day;
  final List<DayItem> items;

  late final Map<String, Payload> payloads = {
    for (final i in items)
      for (final p in i.payloads) p.id: p,
  };

  /// Revisioned inputs recorded as the day's Dependency rows (payloads, enrichments).
  late final List<InputRef> refs = [
    for (final i in items) ...[
      for (final p in i.payloads) (type: EntityType.payload, id: p.id, revision: p.revision),
      for (final n in i.enrichments.values) (type: EntityType.enrichment, id: n.id, revision: n.revision),
    ],
  ];

  /// Evidence curation (importance order, project, star) has no revision column, so it can't be a
  /// Dependency input; its hash is kept in Settings next to the day's Dependency rows.
  late final String curation = sha256Hex(
    [for (final i in items) '${i.evidence.id}|${i.evidence.importance}|${i.evidence.projectId}|${i.evidence.starred}']
        .join('\n'),
  );

  /// The day's input revisions + curation (not titles or workstream/project hints). Compared
  /// before and after the extraction model call: if it moved, the result is discarded and the day re-queued.
  late final String fingerprint = sha256Hex(
    ([for (final r in refs) '${r.type.name}:${r.id}:${r.revision}']..sort()).followedBy([curation]).join('\n'),
  );

  String get _curationKey => 'narrative.day_curation.$day';

  static Future<DayInput> load(ProfileDb db, String day) async {
    final evidence =
        await (db.select(db.evidences)
              ..where((e) => e.day.equals(day) & e.hidden.equals(false))
              ..orderBy([(e) => OrderingTerm.desc(e.importance), (e) => OrderingTerm.asc(e.occurredStart)]))
            .get();
    if (evidence.isEmpty) return DayInput(day, const []);
    final payloads =
        await (db.select(db.payloads)
              ..where((p) => p.evidenceId.isIn(evidence.map((e) => e.id)) & p.tombstonedAt.isNull())
              ..orderBy([(p) => OrderingTerm.asc(p.id)]))
            .get();
    final enrichments = await (db.select(
      db.enrichments,
    )..where((n) => n.targetType.equalsValue(EntityType.payload) & n.targetId.isIn(payloads.map((p) => p.id)))).get();
    final enrByPayload = {for (final n in enrichments) n.targetId: n};
    final items = <DayItem>[];
    for (final e in evidence) {
      final ps = payloads.where((p) => p.evidenceId == e.id).toList();
      if (ps.isEmpty) continue; // no live payloads: hidden from views (LLD 04 §4.1)
      items.add(
        DayItem(e, ps, {
          for (final p in ps)
            if (enrByPayload[p.id] != null) p.id: enrByPayload[p.id]!,
        }),
      );
    }
    return DayInput(day, items);
  }

  /// Records what this day's narrative was built from. Call in the same transaction as the facts.
  Future<void> record(ProfileDb db, DependencyRecorder deps) async {
    await deps.record((type: EntityType.day, id: day), 0, refs);
    await db.into(db.settings).insertOnConflictUpdate(SettingsCompanion.insert(key: _curationKey, value: curation));
  }

  /// True when the day's recorded inputs equal the current ones, so extraction can be skipped.
  Future<bool> isCurrent(ProfileDb db) async {
    final cur = await (db.select(db.settings)..where((s) => s.key.equals(_curationKey))).getSingleOrNull();
    if (cur?.value != curation) return false;
    final recorded = await (db.select(
      db.dependencies,
    )..where((d) => d.dependentType.equalsValue(EntityType.day) & d.dependentId.equals(day))).get();
    final a = {for (final d in recorded) '${d.inputType.name}:${d.inputId}:${d.inputRevision}'};
    final b = {for (final r in refs) '${r.type.name}:${r.id}:${r.revision}'};
    return a.length == b.length && a.containsAll(b);
  }

  /// Removes the day's fingerprint (used by permanent delete).
  static Future<void> forget(ProfileDb db, String day) =>
      (db.delete(db.settings)..where((s) => s.key.equals('narrative.day_curation.$day'))).go();
}
