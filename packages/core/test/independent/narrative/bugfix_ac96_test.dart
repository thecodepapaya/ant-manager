// Independent tests for the fixes in 12c0e9d (merged into v1 by 9bb473f): star routing / rule-hidden
// stars, workstream spans on retire and delete, and dependency rows kept/removed by permanentDelete.
import 'package:core/core.dart';
import 'package:core/src/narrative/enrichment.dart';
import 'package:core/src/narrative/importance.dart';
import 'package:core/src/narrative/reconciler.dart';
import 'package:core/src/staleness/staleness.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:test/test.dart';

import 'harness.dart';

void main() {
  late H h;
  late AntEngine engine;
  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    h = H();
    await h.setUp();
    final u = Unused();
    engine = AntEngine(
      db: h.db,
      profileId: 'p',
      ports: EnginePorts(secrets: u, blobs: h.blobs, git: u, watcher: u, clock: h.clock),
      router: h.router,
      utcOffset: (_) => Duration.zero,
    );
  });
  tearDown(() => h.close());

  group('star routing (WinService.starEvidence)', () {
    late String e1, p1, p1b;
    setUp(() async {
      e1 = await h.commit('a1', at(10), msg: 'Ship retries');
      p1 = await h.pid(e1);
      // A second payload grouped into the same evidence.
      await h.note('n1', at(10), 'retry notes');
      final n = await h.payloadByExt(H.notes, 'n1');
      await (h.db.update(h.db.payloads)..where((x) => x.id.equals(n.id))).write(PayloadsCompanion(evidenceId: Value(e1)));
      p1b = n.id;
    });

    test('no Outcome → exactly one model call; accepted userCreated Outcome citing its payloads', () async {
      final id = await WinService(h.ctx).starEvidence(e1);
      expect(h.router.calls, hasLength(1));
      expect(h.router.calls.single.schema, 'win');
      final f = await h.fact(id);
      expect(
        (f.type, f.origin, f.winStatus, f.retired),
        (FactType.outcome, FactOrigin.userCreated, WinStatus.accepted, false),
      );
      // Default responder gives no citations → falls back to all of the evidence's payloads.
      expect((await h.citations(id)).map((c) => c.payloadId).toSet(), {p1, p1b});
      final ev = await h.evidence(e1);
      expect((ev.starred, ev.importance, ev.importanceSetBy), (true, 1.0, ImportanceSetBy.user));
    });

    test('existing Outcome citing it → upgraded to accepted, no model call, no new fact', () async {
      await h.insertFact('f1', [p1]);
      final id = await WinService(h.ctx).starEvidence(e1);
      expect(id, 'f1');
      expect(h.router.calls, isEmpty);
      final f = await h.fact('f1');
      expect((f.winStatus, f.origin), (WinStatus.accepted, FactOrigin.confirmed));
      expect(await h.facts(type: FactType.outcome), hasLength(1));
    });

    test('an Outcome citing only a second payload of the evidence also counts', () async {
      await h.insertFact('f1', [p1b]);
      expect(await WinService(h.ctx).starEvidence(e1), 'f1');
      expect(h.router.calls, isEmpty);
      expect((await h.fact('f1')).winStatus, WinStatus.accepted);
    });
  });

  group('starring rule-hidden vs user-hidden evidence', () {
    late String e;
    setUp(() async {
      e = await h.commit('a1', at(10), msg: 'Ship retries');
    });

    Future<void> ruleHide() async {
      await h.rule('r', {'titlePattern': 'ship'}, CurationAction.hide);
      await ImportanceScorer(h.ctx).scoreDay(day);
      final ev = await h.evidence(e);
      expect((ev.hidden, ev.importanceSetBy), (true, ImportanceSetBy.rule), reason: 'precondition');
    }

    test('WinService.starEvidence: rule-hidden → visible, importance 1.0', () async {
      await ruleHide();
      final id = await WinService(h.ctx).starEvidence(e);
      final f = await h.fact(id);
      expect((f.type, f.winStatus, f.origin), (FactType.outcome, WinStatus.accepted, FactOrigin.userCreated));
      final ev = await h.evidence(e);
      expect(
        (ev.hidden, ev.starred, ev.importance, ev.importanceSetBy),
        (false, true, 1.0, ImportanceSetBy.user),
      );
    });

    test('AntEngine.setStarred: rule-hidden → visible, importance 1.0', () async {
      await ruleHide();
      await engine.setStarred(e, true);
      final ev = await h.evidence(e);
      expect(
        (ev.hidden, ev.starred, ev.importance, ev.importanceSetBy),
        (false, true, 1.0, ImportanceSetBy.user),
      );
    });

    test('WinService.starEvidence: user-hidden stays hidden, importance 0', () async {
      await engine.setHidden(e, true);
      await WinService(h.ctx).starEvidence(e);
      final ev = await h.evidence(e);
      expect((ev.hidden, ev.starred, ev.importance), (true, true, 0.0));
    });

    test('AntEngine.setStarred: user-hidden stays hidden, importance 0', () async {
      await engine.setHidden(e, true);
      await engine.setStarred(e, true);
      final ev = await h.evidence(e);
      expect((ev.hidden, ev.starred, ev.importance), (true, true, 0.0));
    });

    test('a rule-hidden item later scored again keeps the user star (not re-hidden)', () async {
      await ruleHide();
      await engine.setStarred(e, true);
      await ImportanceScorer(h.ctx).scoreDay(day);
      final ev = await h.evidence(e);
      expect((ev.hidden, ev.importance, ev.importanceSetBy), (false, 1.0, ImportanceSetBy.user));
    });
  });

  group('workstream spans', () {
    late String p;
    setUp(() async {
      p = await h.pid(await h.commit('a1', at(10)));
      await h.db.into(h.db.workstreams).insert(WorkstreamsCompanion.insert(id: 'w', title: 'Retries'));
    });

    Future<(String?, String?)> span() async {
      final w = await (h.db.select(h.db.workstreams)..where((x) => x.id.equals('w'))).getSingle();
      return (w.spanStart, w.spanEnd);
    }

    Future<void> threeFacts() async {
      await h.insertFact('early', [p], d: '2026-11-10', workstream: 'w');
      await h.insertFact('mid', [p], d: '2026-11-12', workstream: 'w');
      await h.insertFact('late', [p], d: '2026-11-17', workstream: 'w');
      await (h.db.update(h.db.workstreams)..where((x) => x.id.equals('w')))
          .write(const WorkstreamsCompanion(spanStart: Value('2026-11-10'), spanEnd: Value('2026-11-17')));
    }

    test('rejectFact on the last fact shrinks the span end', () async {
      await threeFacts();
      await engine.rejectFact('late');
      expect(await span(), ('2026-11-10', '2026-11-12'));
    });

    test('rejectFact on the first fact shrinks the span start', () async {
      await threeFacts();
      await engine.rejectFact('early');
      expect(await span(), ('2026-11-12', '2026-11-17'));
    });

    test('resolveReview accepting a retire proposal shrinks the span', () async {
      await threeFacts();
      await engine.confirmFact('late'); // protected → the model's retire becomes a proposal
      await FactReconciler(h.ctx).apply(FactChangeSet(day, [RetireFact(factId: 'late', reason: 'wrong')]));
      expect(await span(), ('2026-11-10', '2026-11-17'), reason: 'proposal alone changes nothing');
      await engine.resolveReview('late', accept: true);
      expect((await h.fact('late')).retired, isTrue);
      expect(await span(), ('2026-11-10', '2026-11-12'));
    });

    test('dismissing a retire proposal keeps the span', () async {
      await threeFacts();
      await engine.confirmFact('late');
      await FactReconciler(h.ctx).apply(FactChangeSet(day, [RetireFact(factId: 'late', reason: 'wrong')]));
      await engine.resolveReview('late', accept: false);
      expect(await span(), ('2026-11-10', '2026-11-17'));
    });

    test('a model retire of a model-owned fact (FactWriter) shrinks the span', () async {
      await threeFacts();
      await FactReconciler(h.ctx).apply(FactChangeSet(day, [RetireFact(factId: 'late', reason: 'gone')]));
      expect((await h.fact('late')).retired, isTrue);
      expect(await span(), ('2026-11-10', '2026-11-12'));
    });

    test('retiring every fact nulls the span', () async {
      await threeFacts();
      for (final f in ['early', 'mid', 'late']) {
        await engine.rejectFact(f);
      }
      expect(await span(), (null, null));
    });

    test("permanently deleting a workstream's only fact nulls its span", () async {
      final e = await h.commit('b1', at(11));
      await h.insertFact('only', [await h.pid(e)], d: '2026-11-15', workstream: 'w');
      await (h.db.update(h.db.workstreams)..where((x) => x.id.equals('w')))
          .write(const WorkstreamsCompanion(spanStart: Value('2026-11-15'), spanEnd: Value('2026-11-15')));
      await EvidenceDeleter(h.ctx).permanentDelete(e);
      expect(await h.facts(), isEmpty);
      expect(await span(), (null, null));
    });

    test('permanently deleting one of several facts recomputes the span from the rest', () async {
      final e = await h.commit('b1', at(11));
      await h.insertFact('keep', [p], d: '2026-11-10', workstream: 'w');
      await h.insertFact('gone', [await h.pid(e)], d: '2026-11-15', workstream: 'w');
      await (h.db.update(h.db.workstreams)..where((x) => x.id.equals('w')))
          .write(const WorkstreamsCompanion(spanStart: Value('2026-11-10'), spanEnd: Value('2026-11-15')));
      await EvidenceDeleter(h.ctx).permanentDelete(e);
      expect(await span(), ('2026-11-10', '2026-11-10'));
    });
  });

  group('permanentDelete dependency rows', () {
    late String gone, p, q, enr;
    setUp(() async {
      gone = await h.commit('a1', at(9));
      p = await h.pid(gone);
      q = await h.pid(await h.pr('pr1', at(10)));
      final reg = EnrichmentRegistry();
      defaultEnrichmentStrategies(h.ctx).forEach(reg.register);
      await Enricher(h.ctx, reg).enrichDay(day);
      enr = (await h.enrichmentOf(p))!.id;
      await h.insertFact('shared', [p, q]);
      final deps = DependencyRecorder(h.db);
      await deps.record((type: EntityType.fact, id: 'shared'), 1, [
        (type: EntityType.payload, id: p, revision: 1),
        (type: EntityType.payload, id: q, revision: 1),
      ]);
      await deps.record((type: EntityType.reportSnapshot, id: 's'), 1, [
        (type: EntityType.payload, id: p, revision: 1),
        (type: EntityType.enrichment, id: enr, revision: 1),
        (type: EntityType.payload, id: q, revision: 1),
      ]);
    });

    Future<bool> snapshotStale() => StalenessService(h.db).isStale((type: EntityType.reportSnapshot, id: 's'));

    test('snapshot inputs on deleted payload/enrichment are kept and the snapshot reads stale', () async {
      expect(await snapshotStale(), isFalse, reason: 'precondition');
      await EvidenceDeleter(h.ctx).permanentDelete(gone);
      final rows = await h.depsOf(EntityType.reportSnapshot, 's');
      expect(
        rows.map((d) => (d.inputType, d.inputId)).toSet(),
        {(EntityType.payload, p), (EntityType.enrichment, enr), (EntityType.payload, q)},
      );
      expect(await snapshotStale(), isTrue);
    });

    test("fact dependency rows on the deleted payload are removed; others kept", () async {
      await EvidenceDeleter(h.ctx).permanentDelete(gone);
      final rows = await h.depsOf(EntityType.fact, 'shared');
      expect(rows.where((d) => d.inputId == p), isEmpty);
      expect(rows.where((d) => d.inputType == EntityType.payload && d.inputId == q), isNotEmpty);
    });

    test("the deleted enrichment's own dependency rows are removed", () async {
      expect(await h.depsOf(EntityType.enrichment, enr), isNotEmpty, reason: 'precondition');
      await EvidenceDeleter(h.ctx).permanentDelete(gone);
      expect(await h.depsOf(EntityType.enrichment, enr), isEmpty);
    });
  });
}
