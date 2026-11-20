// Independent tests (#99) for DECISIONS #131 (Kimi review fixes, narrative and user overrides):
// rejected time facts stay rejected, workstream moves confirm the fact, empty-citation updates
// validate the kept citations, reportSnapshot queue rows are drained, importance writes never
// clobber a user override, and starring an existing Outcome sets its importance to 1.
import 'dart:convert';

import 'package:core/core.dart';
import 'package:core/src/narrative/importance.dart';
import 'package:core/src/narrative/reconciler.dart';
import 'package:core/src/narrative/time_allocation.dart';
import 'package:core/src/narrative/workstreams.dart';
import 'package:core/src/staleness/staleness.dart' show RecomputeWorker;
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:test/test.dart';

import 'fakes.dart' show Seed;
import 'narrative/harness.dart';

const bugSkip = !bool.fromEnvironment('RUN_BUGS');

AntEngine engineFor(H h) {
  final u = Unused();
  return AntEngine(
    db: h.db,
    profileId: 'p',
    ports: EnginePorts(secrets: u, blobs: h.blobs, git: u, watcher: u, clock: h.clock),
    router: h.router,
    utcOffset: (_) => Duration.zero,
  );
}

Map<String, Object?> detailsOf(Fact f) => jsonDecode(f.details) as Map<String, Object?>;

void main() {
  late H h;
  late AntEngine engine;
  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    h = H();
    await h.setUp();
    engine = engineFor(h);
  });
  tearDown(() => h.close());

  // ---------------------------------------------------------------------------------------------
  group('(a) time facts: a rejected (project, basis) is never re-created', () {
    late TimeAllocator time;
    setUp(() => time = TimeAllocator(h.ctx));

    /// Inserts a live time fact for (no project, measured) next to the computed one.
    Future<String> liveDuplicate(FactOrigin origin) async {
      final pm = (await h.payloadByExt(H.cal, 'm1')).id;
      await h.insertFact('dup', [pm], type: FactType.timeAllocation, statement: '1 h in meetings', origin: origin);
      await (h.db.update(h.db.facts)..where((f) => f.id.equals('dup'))).write(
        const FactsCompanion(details: Value('{"basis":"measured","minutes":60}')),
      );
      return 'dup';
    }

    test('reject, recompute: not re-created, even when the minutes change; other keys still are', () async {
      await h.meeting('m1', at(10), at(11));
      await time.computeDay(day);
      final id = (await h.timeFacts()).single.id;
      await engine.rejectFact(id);
      final rejected = await h.fact(id);
      expect((rejected.retired, rejected.winStatus), (true, WinStatus.rejected));

      await time.computeDay(day);
      expect(await h.timeFacts(), isEmpty, reason: 'same input: no new measured fact');

      await h.meeting('m2', at(13), at(13, 30)); // 90 min now
      await h.commit('c1', at(16)); // a new (no project, estimated) key
      await time.computeDay(day);
      final live = await h.timeFacts();
      expect(live.map((f) => detailsOf(f)['basis']), ['estimated'], reason: 'measured stays rejected');
      expect((await h.timeFacts(live: false)).length, 2, reason: 'only the estimated fact was created');
      final after = await h.fact(id);
      expect((after.retired, after.winStatus, after.revision), (true, WinStatus.rejected, rejected.revision));
    });

    test('a live, model-owned duplicate of a rejected key is retired', () async {
      await h.meeting('m1', at(10), at(11));
      await time.computeDay(day);
      await engine.rejectFact((await h.timeFacts()).single.id);
      await liveDuplicate(FactOrigin.inferred);
      await time.computeDay(day);
      final dup = await h.fact('dup');
      expect((dup.retired, dup.reviewState), (true, ReviewState.ok));
      expect(await h.timeFacts(), isEmpty);
    });

    test('a live, protected duplicate of a rejected key gets a retire proposal with its own reason', () async {
      await h.meeting('m1', at(10), at(11));
      await time.computeDay(day);
      await engine.rejectFact((await h.timeFacts()).single.id);
      await liveDuplicate(FactOrigin.confirmed);
      await time.computeDay(day);
      final dup = await h.fact('dup');
      expect((dup.retired, dup.reviewState, dup.revision), (false, ReviewState.needsReview, 1));
      expect(jsonDecode(dup.reviewProposal!), {
        'op': 'retire',
        'retire': true,
        'reason': 'duplicate or rejected time fact',
      });
      expect((await h.timeFacts()).map((f) => f.id), ['dup'], reason: 'nothing created beside it');
    });

    test('a protected fact retired by an accepted proposal (not rejected) is re-created later', () async {
      final m = await h.meeting('m1', at(10), at(11));
      await time.computeDay(day);
      final id = (await h.timeFacts()).single.id;
      await engine.confirmFact(id);
      await h.setHidden(m, true);
      await time.computeDay(day);
      expect((jsonDecode((await h.fact(id)).reviewProposal!) as Map)['reason'], 'no time recorded any more');
      await engine.resolveReview(id, accept: true);
      final retired = await h.fact(id);
      expect((retired.retired, retired.winStatus), (true, WinStatus.none));

      await h.setHidden(m, false);
      await time.computeDay(day);
      final live = (await h.timeFacts()).single;
      expect(live.id, isNot(id));
      expect(detailsOf(live), {'basis': 'measured', 'minutes': 60});
    });
  });

  // ---------------------------------------------------------------------------------------------
  group('(b) moveFactToWorkstream confirms a model-owned fact', () {
    late String p1;
    setUp(() async {
      p1 = await h.pid(await h.commit('a1', at(10)));
      for (final w in ['w1', 'w2']) {
        await h.db
            .into(h.db.workstreams)
            .insert(WorkstreamsCompanion.insert(id: w, title: w, spanStart: const Value(day), spanEnd: const Value(day)));
      }
    });

    test('remove from workstream: confirmed, revision bump; the assigner leaves it alone', () async {
      await h.insertFact('f', [p1], workstream: 'w1');
      await h.insertFact('g', [p1]); // control: still model-owned and unassigned
      await engine.moveFactToWorkstream('f', null);
      final f = await h.fact('f');
      expect((f.workstreamId, f.origin, f.revision), (null, FactOrigin.confirmed, 2));
      final last = ((await h.history('f'))..sort((a, b) => a.revision.compareTo(b.revision))).last;
      expect((last.revision, last.origin, last.changedBy), (2, FactOrigin.confirmed, 'user'));

      h.router.responders['workstreams'] = (_) => {
        'assignments': [
          for (final id in ['f', 'g']) {'fact_id': id, 'workstream_id': 'w2', 'new_title': null, 'new_summary': ''},
        ],
      };
      await WorkstreamAssigner(h.ctx).assignDay(day);
      final asked = [
        for (final c in h.router.of('workstreams'))
          for (final x in (jsonDecode(c.user) as Map)['facts'] as List) (x as Map)['fact_id'],
      ];
      expect(asked, ['g']);
      expect((await h.fact('g')).workstreamId, 'w2', reason: 'the assigner did run'); // w1 emptied: span null
      final after = await h.fact('f');
      expect((after.workstreamId, after.origin, after.revision), (null, FactOrigin.confirmed, 2));
    });

    test('moving into a workstream also confirms it', () async {
      await h.insertFact('f', [p1]);
      await engine.moveFactToWorkstream('f', 'w2');
      final f = await h.fact('f');
      expect((f.workstreamId, f.origin, f.revision), ('w2', FactOrigin.confirmed, 2));
    });

    for (final origin in [FactOrigin.userEdited, FactOrigin.userCreated, FactOrigin.confirmed]) {
      test('a ${origin.name} fact keeps its origin, no revision bump', () async {
        await h.insertFact('f', [p1], workstream: 'w1', origin: origin);
        await h.clearQueue();
        await engine.moveFactToWorkstream('f', 'w2');
        final f = await h.fact('f');
        expect((f.workstreamId, f.origin, f.revision), ('w2', origin, 1));
        expect(await h.history('f'), hasLength(1));
      });
    }
  });

  // ---------------------------------------------------------------------------------------------
  group('(c) reconciler update with no citations', () {
    late FactReconciler rec;
    late String e1, p1, p2;
    setUp(() async {
      rec = FactReconciler(h.ctx);
      e1 = await h.commit('a1', at(10));
      p1 = await h.pid(e1);
      p2 = await h.pid(await h.commit('b1', at(11))); // keeps the day's input non-empty
    });

    Future<ReconcileResult> update(String id) =>
        rec.apply(FactChangeSet(day, [UpdateFact(factId: id, statement: 'Rewritten.', citations: const [])]));

    Future<void> tombstone(String payloadId) => (h.db.update(h.db.payloads)..where((p) => p.id.equals(payloadId)))
        .write(PayloadsCompanion(tombstonedAt: Value(h.clock.now())));

    for (final (label, protected) in [('model-owned', false), ('protected', true)]) {
      test('$label fact whose current citation is tombstoned: dropped', () async {
        await h.insertFact('f', [p1], origin: protected ? FactOrigin.confirmed : FactOrigin.inferred);
        await tombstone(p1);
        final r = await update('f');
        expect(r.updated, 0);
        expect(r.dropped, contains('update: citations not in input $p1'));
        final f = await h.fact('f');
        expect(f.statement, 'Did a thing.');
        expect((await h.history('f')).map((x) => x.statement), isNot(contains('Rewritten.')));
        // The leftover pass then retires it (no live evidence): directly, or as a retire proposal.
        if (protected) {
          expect((jsonDecode(f.reviewProposal!) as Map)['op'], 'retire');
        } else {
          expect((f.reviewProposal, f.retired), (null, true));
        }
      });
    }

    test('fact whose current citation is outside the input (hidden evidence): dropped', () async {
      await h.insertFact('f', [p1]);
      await h.setHidden(e1, true);
      final r = await update('f');
      expect(r.updated, 0);
      expect(r.dropped, contains('update: citations not in input $p1'));
      expect((await h.fact('f')).statement, 'Did a thing.');
    });

    test('valid current citations: the update applies and keeps them', () async {
      await h.insertFact('f', [p1]);
      final r = await update('f');
      expect(r.dropped, isEmpty);
      expect(r.updated, 1);
      final f = await h.fact('f');
      expect((f.statement, f.revision), ('Rewritten.', 2));
      expect((await h.citations('f')).map((c) => c.payloadId), [p1]);
    });

    test('protected fact with valid citations: a proposal citing the current ones', () async {
      await h.insertFact('f', [p1, p2], origin: FactOrigin.userEdited);
      final r = await update('f');
      expect(r.dropped, isEmpty);
      expect((r.proposed, r.updated), (1, 0));
      final f = await h.fact('f');
      expect((f.statement, f.revision, f.reviewState), ('Did a thing.', 1, ReviewState.needsReview));
      final p = jsonDecode(f.reviewProposal!) as Map;
      expect((p['op'], p['statement'], p['retire']), ('update', 'Rewritten.', false));
      expect((p['citations'] as List).toSet(), {p1, p2});
    });
  });

  // ---------------------------------------------------------------------------------------------
  group('(d) reportSnapshot recompute rows', () {
    test('a fact bump queues the snapshot; drain removes the rows; computed staleness is unchanged', () async {
      final p1 = await h.pid(await h.commit('a1', at(10)));
      await h.insertFact('f', [p1]);
      await TemplateService(h.db).seedBuiltins();
      await h.db
          .into(h.db.reports)
          .insert(
            ReportsCompanion.insert(
              id: 'r',
              periodKind: PeriodKind.daily,
              periodStart: day,
              periodEnd: day,
              templateId: 'builtin.standup',
            ),
          );
      await h.db
          .into(h.db.reportSnapshots)
          .insert(
            ReportSnapshotsCompanion.insert(
              id: 's1',
              reportId: 'r',
              version: 1,
              json: '{}',
              markdown: '',
              modelId: 'm',
              generatedAt: h.clock.now(),
            ),
          );
      const snap = (type: EntityType.reportSnapshot, id: 's1');
      await engine.deps.record(snap, 1, [(type: EntityType.fact, id: 'f', revision: 1)]);
      await h.clearQueue();
      expect(await engine.staleness.isStale(snap), isFalse);

      await engine.confirmFact('f'); // revision 1 → 2
      final seed = Seed(h.db);
      expect(await seed.queueCount(EntityType.reportSnapshot, 's1'), 1);
      expect(await engine.staleness.isStale(snap), isTrue);

      // Without a handler the row would stay queued forever.
      expect(await RecomputeWorker(h.db).drain(), 0);
      expect(await seed.queueCount(EntityType.reportSnapshot), 1);

      expect(await engine.recompute.drain(), 1);
      expect(await seed.queueCount(EntityType.reportSnapshot), 0);
      expect(await engine.staleness.isStale(snap), isTrue, reason: 'staleness is computed, not cleared by the drain');
      expect(await h.db.select(h.db.reportSnapshots).get(), hasLength(1), reason: 'no regeneration');
    });
  });

  // ---------------------------------------------------------------------------------------------
  group('(f) importance writes never overwrite a user override', () {
    late ProfileDb db;
    late FakeRouter router;
    late ImportanceScorer scorer;
    late Seed seed;
    late String src, ev;
    late _OverrideOnRulesRead hook;

    setUp(() async {
      hook = _OverrideOnRulesRead();
      db = ProfileDb(NativeDatabase.memory().interceptWith(hook));
      router = FakeRouter();
      scorer = ImportanceScorer(NarrativeContext(db: db, router: router, blobs: FakeBlobs(), clock: h.clock));
      seed = Seed(db);
      src = await seed.source(SourceKind.gitRepo);
      ev = (await seed.evidence(src, day, {'message': 'Ship retries'}, title: 'Ship retries')).evidence;
    });
    tearDown(() => db.close());

    Future<Evidence> evidence() => (db.select(db.evidences)..where((e) => e.id.equals(ev))).getSingle();
    Future<void> setBy(ImportanceSetBy? by, double importance) => (db.update(db.evidences)..where((e) => e.id.equals(ev)))
        .write(EvidencesCompanion(importanceSetBy: Value(by), importance: Value(importance)));
    Future<void> boostRule() => db
        .into(db.curationRules)
        .insert(
          CurationRulesCompanion.insert(
            id: 'boost',
            match: jsonEncode({'sourceKind': 'gitRepo'}),
            action: CurationAction.setImportance,
            value: const Value(0.9),
          ),
        );
    Future<void> userStars() => db.customUpdate(
      "UPDATE evidences SET starred = 1, importance = 1.0, importance_set_by = 'user' WHERE id = ?",
      variables: [Variable.withString(ev)],
    );

    void expectUser(Evidence e) =>
        expect((e.importanceSetBy, e.importance, e.starred), (ImportanceSetBy.user, 1.0, true));

    test('rule write: override committed after scoreDay read the evidence survives', () async {
      await boostRule();
      hook.onRulesRead = userStars;
      await scorer.scoreDay(day);
      expect(hook.fired, isTrue, reason: 'the override landed between the read and the rule write');
      expectUser(await evidence());
    });

    test('reset write: override committed after the read survives the rule-no-longer-matches reset', () async {
      await setBy(ImportanceSetBy.rule, 0.9); // set by a rule that no longer exists
      hook.onRulesRead = userStars;
      await scorer.scoreDay(day);
      expect(hook.fired, isTrue);
      expectUser(await evidence());
    });

    test('hide rule write: a star committed after the read is not hidden by the rule', () async {
      await db
          .into(db.curationRules)
          .insert(
            CurationRulesCompanion.insert(
              id: 'hide',
              match: jsonEncode({'sourceKind': 'gitRepo'}),
              action: CurationAction.hide,
            ),
          );
      hook.onRulesRead = userStars;
      await scorer.scoreDay(day);
      expect(hook.fired, isTrue);
      final e = await evidence();
      expectUser(e);
      expect(e.hidden, isFalse);
    });

    // Regression guard: _scoreBatch already re-read the row before #131, so this passes either way.
    test('model write: override committed while the model is thinking survives', () async {
      router.onCall = (c) async {
        if (c.schema == 'importance') await userStars();
      };
      await scorer.scoreDay(day);
      expect(router.of('importance'), hasLength(1));
      expectUser(await evidence());
    });

    test('never-scored evidence (set_by NULL) still gets the rule score', () async {
      await boostRule();
      await scorer.scoreDay(day);
      final e = await evidence();
      expect((e.importanceSetBy, e.importance, e.importanceReason), (ImportanceSetBy.rule, 0.9, 'rule boost'));
    });

    test('never-scored evidence (set_by NULL) still gets the model score', () async {
      await scorer.scoreDay(day);
      final e = await evidence();
      expect((e.importanceSetBy, e.importance, e.importanceReason), (ImportanceSetBy.model, 0.7, 'fake'));
    });

    test('rule-set evidence whose rule is gone is reset and re-scored by the model', () async {
      await setBy(ImportanceSetBy.rule, 0.9);
      await scorer.scoreDay(day);
      final e = await evidence();
      expect((e.importanceSetBy, e.importance), (ImportanceSetBy.model, 0.7));
    });
  });

  // ---------------------------------------------------------------------------------------------
  group('(g) starring evidence cited by an existing Outcome sets its importance to 1', () {
    late String e1, p1;
    setUp(() async {
      e1 = await h.commit('a1', at(10), msg: 'Ship retries');
      p1 = await h.pid(e1);
    });

    Future<void> setImportance(String id, double v) =>
        (h.db.update(h.db.facts)..where((f) => f.id.equals(id))).write(FactsCompanion(importance: Value(v)));

    test('not yet accepted → accepted win with importance 1, no model call', () async {
      await h.insertFact('o', [p1]);
      await setImportance('o', 0.4);
      expect(await WinService(h.ctx).starEvidence(e1), 'o');
      final f = await h.fact('o');
      expect((f.winStatus, f.importance, f.origin), (WinStatus.accepted, 1.0, FactOrigin.confirmed));
      expect(h.router.of('win'), isEmpty);
    });

    test('already accepted with a lower importance → raised to 1', () async {
      await h.insertFact('o', [p1], win: WinStatus.accepted);
      await setImportance('o', 0.6);
      expect(await WinService(h.ctx).starEvidence(e1), 'o');
      final f = await h.fact('o');
      expect((f.winStatus, f.importance), (WinStatus.accepted, 1.0));
      expect(h.router.of('win'), isEmpty);
    });

    test('already accepted at importance 1 → no new revision', () async {
      await h.insertFact('o', [p1], win: WinStatus.accepted);
      await setImportance('o', 1.0);
      await WinService(h.ctx).starEvidence(e1);
      expect((await h.fact('o')).revision, 1);
    });

    // BUG: AntEngine.setStarred(true) (_curate) accepts the Outcome but never sets importance 1, and
    // skips already-accepted facts, so #131(g) holds only on WinService.starEvidence.
    test('AntEngine.setStarred(true) also gives the existing Outcome importance 1', () async {
      await h.insertFact('o', [p1]);
      await setImportance('o', 0.4);
      await engine.setStarred(e1, true);
      final f = await h.fact('o');
      expect((f.winStatus, f.importance), (WinStatus.accepted, 1.0));
    }, skip: bugSkip);

    test('AntEngine.setStarred(true) raises an accepted Outcome with a lower importance to 1', () async {
      await h.insertFact('o', [p1], win: WinStatus.accepted);
      await setImportance('o', 0.6);
      await engine.setStarred(e1, true);
      expect((await h.fact('o')).importance, 1.0);
    }, skip: bugSkip);
  });
}

/// Runs [onRulesRead] once, right before scoreDay's curation-rule read: after the day's evidence
/// was read and before any rule/reset write, so the scorer's in-memory evidence row is stale.
class _OverrideOnRulesRead extends QueryInterceptor {
  Future<void> Function()? onRulesRead;
  var fired = false;

  @override
  Future<List<Map<String, Object?>>> runSelect(QueryExecutor executor, String statement, List<Object?> args) async {
    final hook = onRulesRead;
    if (hook != null && !fired && statement.contains('"curation_rules"')) {
      fired = true;
      await hook();
    }
    return executor.runSelect(statement, args);
  }
}
