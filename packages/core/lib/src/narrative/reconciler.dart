import 'package:drift/drift.dart';

import '../data/profile_db.dart';
import '../domain/enums.dart';
import 'context.dart';
import 'day_input.dart';
import 'fact_writer.dart';
import 'interfaces.dart';

/// What a reconcile did. [dropped] lists rejected ops with reasons (extraction errors, counted for evals).
class ReconcileResult {
  int created = 0, updated = 0, retired = 0, proposed = 0, repinned = 0;
  final dropped = <String>[];
  @override
  String toString() =>
      'created=$created updated=$updated retired=$retired proposed=$proposed repinned=$repinned dropped=${dropped.length}';
}

/// Applies a day's FactChangeSet while enforcing the narrative invariants (LLD 04 §4.6).
/// Call inside the day's transaction (the RecomputeWorker provides one).
class FactReconciler {
  FactReconciler(this.ctx) : writer = FactWriter(ctx);
  final NarrativeContext ctx;
  final FactWriter writer;
  ProfileDb get db => ctx.db;

  Future<ReconcileResult> apply(FactChangeSet cs) async {
    final r = ReconcileResult();
    final input = await DayInput.load(db, cs.day);
    final facts = {
      for (final f in await (db.select(db.facts)..where((f) => f.periodStart.equals(cs.day))).get()) f.id: f,
    };
    final projectIds = (await db.select(db.projects).get()).map((p) => p.id).toSet();
    final opTouched = <String>{};

    for (final op in cs.ops) {
      switch (op) {
        case CreateFact():
          if (!_citationsOk(op.citations, input, r, 'create')) continue;
          if (op.type == FactType.timeAllocation) {
            r.dropped.add('create: time allocation is computed in code');
            continue;
          }
          if (facts.values.any((f) => f.retired && f.origin.isUserTouched && _same(f.statement, op.statement))) {
            r.dropped.add('create: re-creates a fact the user rejected');
            continue;
          }
          final win = op.suggestWin && op.type == FactType.outcome && !await _winRejectedFor(op.citations)
              ? WinStatus.suggested
              : WinStatus.none;
          await writer.create(
            type: op.type,
            statement: op.statement,
            day: cs.day,
            citations: op.citations,
            details: op.details,
            projectId: projectIds.contains(op.projectId) ? op.projectId : _sharedProject(op.citations, input),
            importance: op.importance,
            winStatus: win,
          );
          r.created++;
        case UpdateFact():
          final f = _target(facts, op.factId, r, 'update');
          if (f == null) continue;
          final cites = op.citations.isEmpty ? await writer.citedPayloads(f.id) : op.citations;
          if (op.citations.isNotEmpty && !_citationsOk(op.citations, input, r, 'update')) continue;
          opTouched.add(f.id);
          if (isProtected(f)) {
            await writer.propose(f, {'op': 'update', 'statement': op.statement, 'citations': cites, 'retire': false});
            r.proposed++;
          } else {
            await writer.update(f, statement: op.statement, details: op.details, citations: cites);
            r.updated++;
          }
        case RetireFact():
          final f = _target(facts, op.factId, r, 'retire');
          if (f == null) continue;
          opTouched.add(f.id);
          await _retire(f, op.reason, r, explicit: true);
      }
    }

    // Facts the model left alone: if none of their evidence is still in the input, retire them (no
    // fact without live evidence, invariant 4); otherwise the model reviewed the current evidence
    // and kept them, so re-pin their citations to it.
    for (final f in facts.values) {
      if (f.retired || f.type == FactType.timeAllocation || opTouched.contains(f.id)) continue;
      final cites = await (db.select(db.citations)..where((c) => c.factId.equals(f.id))).get();
      final inInput = cites.where((c) => input.payloads.containsKey(c.payloadId)).toList();
      if (inInput.isEmpty) {
        await _retire(f, 'evidence removed', r);
      } else if (!isProtected(f) && inInput.any((c) => input.payloads[c.payloadId]!.revision != c.payloadRevision)) {
        await writer.repin(f);
        r.repinned++;
      }
    }

    await input.record(db, ctx.deps);
    return r;
  }

  Future<void> _retire(Fact f, String reason, ReconcileResult r, {bool explicit = false}) async {
    if (isProtected(f)) {
      if (!explicit && f.reviewState == ReviewState.needsReview && f.reviewProposal != null) return;
      await writer.propose(f, {'op': 'retire', 'retire': true, 'reason': reason});
      r.proposed++;
    } else {
      await writer.update(f, retired: true);
      r.retired++;
    }
  }

  Fact? _target(Map<String, Fact> facts, String id, ReconcileResult r, String op) {
    final f = facts[id];
    if (f == null || f.retired || f.type == FactType.timeAllocation) {
      r.dropped.add('$op: unknown, retired or time fact $id');
      return null;
    }
    return f;
  }

  bool _citationsOk(List<String> citations, DayInput input, ReconcileResult r, String op) {
    final bad = citations.where((c) => !input.payloads.containsKey(c)).toList();
    if (citations.isEmpty || bad.isNotEmpty) {
      r.dropped.add('$op: citations not in input ${bad.isEmpty ? '(none)' : bad.join(',')}');
      return false;
    }
    return true;
  }

  /// A suggested win the user rejected before, citing any of these payloads, is never re-suggested (#63).
  Future<bool> _winRejectedFor(List<String> citations) async {
    final q = db.select(db.citations).join([innerJoin(db.facts, db.facts.id.equalsExp(db.citations.factId))])
      ..where(
        db.citations.payloadId.isIn(citations) &
            db.facts.type.equalsValue(FactType.outcome) &
            db.facts.winStatus.equalsValue(WinStatus.rejected),
      )
      ..limit(1);
    return (await q.get()).isNotEmpty;
  }

  String? _sharedProject(List<String> citations, DayInput input) {
    final projects = {
      for (final i in input.items)
        if (i.payloads.any((p) => citations.contains(p.id))) i.evidence.projectId,
    };
    return projects.length == 1 ? projects.first : null;
  }

  static bool _same(String a, String b) => _norm(a) == _norm(b);
  static String _norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}
