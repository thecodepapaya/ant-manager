import 'dart:convert';

import 'package:drift/drift.dart';

import '../data/profile_db.dart';
import '../domain/enums.dart';
import '../util/ids.dart';
import 'context.dart';

/// The model never changes user-touched facts (#50, #62). Accepted wins are user-set too, so they
/// are protected the same way (§4.10).
bool isProtected(Fact f) => f.origin.isUserTouched || f.winStatus == WinStatus.accepted;

/// Shared fact writes: every change appends a FactRevision, pins citations to current payload
/// revisions and re-records the fact's Dependency rows (fact ← cited payload revisions).
class FactWriter {
  FactWriter(this.ctx);
  final NarrativeContext ctx;
  ProfileDb get db => ctx.db;

  Future<String> create({
    required FactType type,
    required String statement,
    required String day,
    required List<String> citations,
    Map<String, Object?> details = const {},
    String? projectId,
    double importance = 0.5,
    FactOrigin origin = FactOrigin.inferred,
    WinStatus winStatus = WinStatus.none,
    String? workstreamId,
  }) async {
    final now = ctx.clock.now();
    final id = newId(now);
    final det = canonicalJson(details);
    await db
        .into(db.facts)
        .insert(
          FactsCompanion.insert(
            id: id,
            type: type,
            statement: statement,
            details: Value(det),
            periodStart: day,
            periodEnd: day,
            projectId: Value(projectId),
            workstreamId: Value(workstreamId),
            importance: Value(importance.clamp(0.0, 1.0).toDouble()),
            origin: origin,
            winStatus: Value(winStatus),
            createdAt: now,
            updatedAt: now,
          ),
        );
    await _revision(id, 1, statement, det, origin, origin.isUserTouched ? 'user' : 'model');
    await _pin(id, 1, citations);
    return id;
  }

  /// Model-side change of a model-owned fact: bump revision (fires staleness triggers), append history.
  Future<void> update(
    Fact f, {
    String? statement,
    Map<String, Object?>? details,
    List<String>? citations,
    bool? retired,
  }) async {
    final rev = f.revision + 1;
    final st = statement ?? f.statement;
    final det = details == null ? f.details : canonicalJson(details);
    await (db.update(db.facts)..where((x) => x.id.equals(f.id))).write(
      FactsCompanion(
        statement: Value(st),
        details: Value(det),
        retired: Value(retired ?? f.retired),
        revision: Value(rev),
        updatedAt: Value(ctx.clock.now()),
      ),
    );
    await _revision(f.id, rev, st, det, f.origin, 'model');
    await _pin(f.id, rev, citations ?? await citedPayloads(f.id));
  }

  /// User accepts a win (same semantics as AntEngine.setWinStatus): user-touched from then on.
  Future<void> acceptWin(Fact f) async {
    final rev = f.revision + 1;
    final origin = f.origin.isUserTouched ? f.origin : FactOrigin.confirmed;
    await (db.update(db.facts)..where((x) => x.id.equals(f.id))).write(
      FactsCompanion(
        origin: Value(origin),
        winStatus: const Value(WinStatus.accepted),
        revision: Value(rev),
        reviewState: const Value(ReviewState.ok),
        reviewProposal: const Value(null),
        updatedAt: Value(ctx.clock.now()),
      ),
    );
    await _revision(f.id, rev, f.statement, f.details, origin, 'user');
    await ctx.deps.record(
      (type: EntityType.fact, id: f.id),
      rev,
      [
        for (final c in await (db.select(db.citations)..where((c) => c.factId.equals(f.id))).get())
          (type: EntityType.payload, id: c.payloadId, revision: c.payloadRevision),
      ],
    );
  }

  /// Re-pins a model-owned fact's citations to current revisions after the model reviewed the
  /// changed evidence and kept the fact as is (no revision bump: its text didn't change).
  Future<void> repin(Fact f) async => _pin(f.id, f.revision, await citedPayloads(f.id));

  /// A user-touched fact gets the model's proposal instead of the change (invariant 7).
  Future<void> propose(Fact f, Map<String, Object?> proposal) =>
      (db.update(db.facts)..where((x) => x.id.equals(f.id))).write(
        FactsCompanion(
          reviewState: const Value(ReviewState.needsReview),
          reviewProposal: Value(canonicalJson(proposal)),
          updatedAt: Value(ctx.clock.now()),
        ),
      );

  Future<List<String>> citedPayloads(String factId) async =>
      (await (db.select(db.citations)..where((c) => c.factId.equals(factId))).get()).map((c) => c.payloadId).toList();

  Future<void> _pin(String factId, int factRevision, List<String> payloadIds) async {
    final ps = await db.payloadsById(payloadIds);
    await (db.delete(db.citations)..where((c) => c.factId.equals(factId))).go();
    for (final p in ps.values) {
      await db
          .into(db.citations)
          .insert(CitationsCompanion.insert(factId: factId, payloadId: p.id, payloadRevision: p.revision));
    }
    await ctx.deps.record(
      (type: EntityType.fact, id: factId),
      factRevision,
      [for (final p in ps.values) (type: EntityType.payload, id: p.id, revision: p.revision)],
    );
  }

  Future<void> _revision(String id, int rev, String st, String det, FactOrigin origin, String by) => db
      .into(db.factRevisions)
      .insert(
        FactRevisionsCompanion.insert(
          factId: id,
          revision: rev,
          statement: st,
          details: det,
          origin: origin,
          changedBy: by,
          changedAt: ctx.clock.now(),
        ),
      );
}

Map<String, Object?> detailsOf(Fact f) {
  final m = jsonDecode(f.details);
  return m is Map<String, Object?> ? m : const {};
}
