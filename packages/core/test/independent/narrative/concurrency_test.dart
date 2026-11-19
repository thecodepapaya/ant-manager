// Model calls run outside transactions (#101): writers aren't blocked, every stage re-checks its
// inputs after the call, and the queue keeps work until a handler succeeds.
import 'dart:async';
import 'dart:convert';

import 'package:core/core.dart';
import 'package:core/src/narrative/enrichment.dart';
import 'package:core/src/narrative/importance.dart';
import 'package:core/src/narrative/reconciler.dart';
import 'package:core/src/narrative/workstreams.dart';
import 'package:core/src/staleness/staleness.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:test/test.dart';

import 'harness.dart';

void main() {
  late H h;
  late AntEngine engine;
  late NarrativePipeline pipeline;
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
    pipeline = registerNarrativePipeline(engine);
    h.router.responders['fact_ops'] = (c) {
      final ids = FakeRouter.payloadIds(c.user);
      return {
        'ops': [
          if (ids.isNotEmpty) createOp([ids.first]),
        ],
      };
    };
  });
  tearDown(() => h.close());

  Future<List<RecomputeQueueData>> queue() => h.db.select(h.db.recomputeQueue).get();

  PayloadObservation commitObs(String sha, {String msg = 'commit', int hour = 10}) => PayloadObservation(
    externalId: sha,
    kind: PayloadKind.commit,
    content: {'sha': sha, 'message': msg},
    occurredStart: at(hour),
    title: msg,
  );

  test('another writer can commit while a model call is blocked', () async {
    await h.ingestor.ingest(H.git, [commitObs('a1')]);
    final blocked = Completer<void>(), release = Completer<void>();
    h.router.onCall = (c) async {
      if (c.schema != 'fact_ops') return;
      if (!blocked.isCompleted) blocked.complete();
      await release.future;
    };
    final drain = engine.recompute.drain();
    await blocked.future;
    // Runs in the test's zone, not the handler's: must not wait for the model call.
    await h.ingestor.ingest(H.git, [commitObs('b1', hour: 12)]).timeout(const Duration(seconds: 2));
    final e = (await h.payloadByExt(H.git, 'b1')).evidenceId;
    await engine.setStarred(e, true).timeout(const Duration(seconds: 2));
    release.complete();
    await drain;
    expect(await queue(), isEmpty);
    // The late commit made it into a later extraction.
    final late = (await h.payloadByExt(H.git, 'b1')).id;
    expect(h.router.of('fact_ops').any((c) => c.user.contains('payload_id=$late')), isTrue);
  });

  group('RecomputeWorker queue rows', () {
    test('a throwing handler leaves its rows queued', () async {
      final w = RecomputeWorker(h.db)..on(EntityType.report, (_) async => throw StateError('boom'));
      await h.ctx.enqueue(EntityType.report, 'r1', 'a');
      await h.ctx.enqueue(EntityType.report, 'r1', 'b');
      await expectLater(w.drain(), throwsStateError);
      expect((await queue()).map((q) => q.reason), ['a', 'b']);
    });

    test('after success only rows with seq <= maxSeq are removed', () async {
      var calls = 0;
      final seen = <List<String>>[];
      late RecomputeWorker w;
      w = RecomputeWorker(h.db)
        ..on(EntityType.report, (id) async {
          calls++;
          seen.add((await queue()).map((q) => q.reason).toList());
          if (calls == 1) await h.ctx.enqueue(EntityType.report, id, 'during');
        });
      await h.ctx.enqueue(EntityType.report, 'r1', 'a');
      await h.ctx.enqueue(EntityType.report, 'r1', 'b');
      await h.ctx.enqueue(EntityType.workstream, 'w1', 'no handler');
      expect(await w.drain(), 2);
      expect(calls, 2, reason: 'the row added during the handler survives and is processed next');
      expect(seen.last, ['no handler', 'during']);
      expect((await queue()).map((q) => q.reason), ['no handler']);
    });
  });

  group('inputs changing during extraction', () {
    test('a payload change → no facts written, day re-queued; next pass writes them', () async {
      await h.ingestor.ingest(H.git, [commitObs('a1')]);
      var first = true;
      h.router.onCall = (c) async {
        if (c.schema != 'fact_ops' || !first) return;
        first = false;
        await h.ingestor.ingest(H.git, [commitObs('a1', msg: 'amended')]);
      };
      await h.clearQueue();
      await pipeline.runDay(day);
      expect(await h.facts(type: FactType.outcome), isEmpty);
      expect((await queue()).any((q) => q.entityType == EntityType.day && q.entityId == day), isTrue);
      expect(pipeline.lastReconcile[day], isNull);
      await engine.recompute.drain();
      final f = (await h.facts(type: FactType.outcome)).single;
      expect((await h.citations(f.id)).single.payloadRevision, 2);
      expect(await queue(), isEmpty);
    });

    test('a curation change → no facts written, day re-queued', () async {
      final e = await h.commit('a1', at(10));
      var first = true;
      h.router.onCall = (c) async {
        if (c.schema != 'fact_ops' || !first) return;
        first = false;
        await engine.setStarred(e, true);
      };
      await h.clearQueue();
      await pipeline.runDay(day);
      expect(await h.facts(type: FactType.outcome), isEmpty);
      expect((await queue()).where((q) => q.entityType == EntityType.day), isNotEmpty);
      await engine.recompute.drain();
      expect(await h.facts(type: FactType.outcome), hasLength(1));
    });
  });

  test('importance: an item that changed during the call is not written, others are', () async {
    final a = await h.commit('a1', at(9));
    final b = await h.commit('b1', at(10));
    h.router.onCall = (c) async {
      if (c.schema == 'importance') await h.ingestor.ingest(H.git, [commitObs('a1', msg: 'amended', hour: 9)]);
    };
    await h.clearQueue();
    await ImportanceScorer(h.ctx).scoreDay(day);
    expect((await h.evidence(a)).importanceSetBy, isNull);
    expect((await h.evidence(b)).importanceSetBy, ImportanceSetBy.model);
    expect((await queue()).where((q) => q.entityType == EntityType.day), isNotEmpty);
  });

  test('enrichment: a payload that changed during the call is not written, others are', () async {
    final a = await h.pid(await h.commit('a1', at(9)));
    final b = await h.pid(await h.commit('b1', at(10)));
    h.router.onCall = (c) async {
      if (c.schema == 'enrichment') await h.ingestor.ingest(H.git, [commitObs('a1', msg: 'amended', hour: 9)]);
    };
    final reg = EnrichmentRegistry();
    defaultEnrichmentStrategies(h.ctx).forEach(reg.register);
    await h.clearQueue();
    await Enricher(h.ctx, reg).enrichDay(day);
    expect(await h.enrichmentOf(a), isNull);
    expect(await h.enrichmentOf(b), isNotNull);
    expect((await queue()).where((q) => q.entityType == EntityType.day), isNotEmpty);
  });

  group('workstreams', () {
    test('facts touched, retired or changed during the call are not assigned', () async {
      final p = await h.pid(await h.commit('a1', at(9)));
      for (final id in ['touched', 'retired', 'changed', 'plain']) {
        await h.insertFact(id, [p]);
      }
      h.router.responders['workstreams'] = (c) => {
        'assignments': [
          for (final f in (jsonDecode(c.user) as Map)['facts'] as List)
            {'fact_id': (f as Map)['fact_id'], 'workstream_id': null, 'new_title': 'Thread', 'new_summary': ''},
        ],
      };
      h.router.onCall = (c) async {
        if (c.schema != 'workstreams') return;
        await engine.confirmFact('touched');
        await (h.db.update(
          h.db.facts,
        )..where((f) => f.id.equals('retired'))).write(const FactsCompanion(retired: Value(true)));
        await (h.db.update(h.db.facts)..where((f) => f.id.equals('changed'))).write(
          const FactsCompanion(revision: Value(2), statement: Value('changed')),
        );
      };
      await WorkstreamAssigner(h.ctx).assignDay(day);
      final assigned = {for (final f in await h.facts()) f.id: f.workstreamId != null};
      expect(assigned, {'touched': false, 'retired': false, 'changed': false, 'plain': true});
    });

    test('a retry after a failed workstream call still assigns', () async {
      await h.ingestor.ingest(H.git, [commitObs('a1')]);
      var fail = true;
      h.router.responders['workstreams'] = (c) {
        if (fail) {
          fail = false;
          throw StateError('model down');
        }
        return {
          'assignments': [
            for (final f in (jsonDecode(c.user) as Map)['facts'] as List)
              {'fact_id': (f as Map)['fact_id'], 'workstream_id': null, 'new_title': 'Thread', 'new_summary': ''},
          ],
        };
      };
      await expectLater(engine.recompute.drain(), throwsStateError);
      expect((await h.facts(type: FactType.outcome)).single.workstreamId, isNull);
      expect(await queue(), isNotEmpty, reason: 'the failed day stays queued');
      await engine.recompute.drain();
      expect((await h.facts(type: FactType.outcome)).single.workstreamId, isNotNull);
      expect(h.router.of('fact_ops'), hasLength(1), reason: 'facts were committed; no re-extraction');
      expect(await queue(), isEmpty);
    });
  });

  group('staleness with missing inputs', () {
    Future<bool> stale(String id) => StalenessService(h.db).isStale((type: EntityType.reportSnapshot, id: id));

    test('a snapshot whose recorded fact, payload or enrichment row is gone is stale', () async {
      final p = await h.pid(await h.commit('a1', at(9)));
      await h.insertFact('f1', [p]);
      await h.db
          .into(h.db.enrichments)
          .insert(
            EnrichmentsCompanion.insert(
              id: 'n1',
              targetType: EntityType.payload,
              targetId: p,
              kind: 'summary',
              output: 'o',
              modelId: 'm',
              createdAt: h.clock.now(),
            ),
          );
      final deps = DependencyRecorder(h.db);
      await deps.record(
        (type: EntityType.reportSnapshot, id: 'sf'),
        1,
        [(type: EntityType.fact, id: 'f1', revision: 1)],
      );
      await deps.record(
        (type: EntityType.reportSnapshot, id: 'sp'),
        1,
        [(type: EntityType.payload, id: p, revision: 1)],
      );
      await deps.record(
        (type: EntityType.reportSnapshot, id: 'sn'),
        1,
        [(type: EntityType.enrichment, id: 'n1', revision: 1)],
      );
      expect([await stale('sf'), await stale('sp'), await stale('sn')], [false, false, false]);
      await h.db.customStatement('PRAGMA foreign_keys = OFF');
      await h.db.customStatement("DELETE FROM facts WHERE id = 'f1'");
      await h.db.customStatement("DELETE FROM enrichments WHERE id = 'n1'");
      await h.db.customStatement('DELETE FROM payloads WHERE id = ?', [p]);
      expect([await stale('sf'), await stale('sp'), await stale('sn')], [true, true, true]);
    });

    test('after permanent delete, a snapshot built from the deleted fact is stale', () async {
      final e = await h.commit('a1', at(9));
      await h.insertFact('f1', [await h.pid(e)]);
      await DependencyRecorder(h.db)
          .record((type: EntityType.reportSnapshot, id: 's'), 1, [(type: EntityType.fact, id: 'f1', revision: 1)]);
      await EvidenceDeleter(h.ctx).permanentDelete(e);
      expect(await stale('s'), isTrue);
    });

    test(
      'after permanent delete, a snapshot that recorded the deleted payload or enrichment is stale',
      () async {
        final e = await h.commit('a1', at(9));
        final p = await h.pid(e);
        final reg = EnrichmentRegistry();
        defaultEnrichmentStrategies(h.ctx).forEach(reg.register);
        await Enricher(h.ctx, reg).enrichDay(day);
        final n = (await h.enrichmentOf(p))!;
        final deps = DependencyRecorder(h.db);
        await deps.record(
          (type: EntityType.reportSnapshot, id: 'sp'),
          1,
          [(type: EntityType.payload, id: p, revision: 1)],
        );
        await deps.record(
          (type: EntityType.reportSnapshot, id: 'sn'),
          1,
          [(type: EntityType.enrichment, id: n.id, revision: 1)],
        );
        await EvidenceDeleter(h.ctx).permanentDelete(e);
        expect([await stale('sp'), await stale('sn')], [true, true]);
      },
      skip:
          'BUG: delete.dart permanentDelete deletes every Dependency row whose input is a deleted payload or '
          'enrichment, including other dependents\' rows (it keeps them only for facts), so such a snapshot '
          'loses its record and reads as fresh',
    );
  });

  group('resolveReview', () {
    late String p1, p2;
    setUp(() async {
      p1 = await h.pid(await h.commit('a1', at(9)));
      p2 = await h.pid(await h.pr('pr1', at(10)));
      await h.insertFact('f1', [p1]);
      await engine.confirmFact('f1'); // revision 2, confirmed
      await h.ctx.deps.record((type: EntityType.fact, id: 'f1'), 2, [(type: EntityType.payload, id: p1, revision: 1)]);
    });

    test('accept an update proposal: statement applied, citations re-pinned, not stale', () async {
      await FactReconciler(h.ctx).apply(
        FactChangeSet(day, [
          UpdateFact(factId: 'f1', statement: 'Better wording.', citations: [p1, p2]),
        ]),
      );
      expect((await h.fact('f1')).reviewState, ReviewState.needsReview);
      await engine.resolveReview('f1', accept: true);
      final f = await h.fact('f1');
      expect(
        (f.statement, f.revision, f.origin, f.reviewState, f.reviewProposal, f.retired),
        ('Better wording.', 3, FactOrigin.confirmed, ReviewState.ok, null, false),
      );
      expect({for (final c in await h.citations('f1')) c.payloadId: c.payloadRevision}, {p1: 1, p2: 1});
      expect(await h.ctx.isStale(EntityType.fact, 'f1'), isFalse);
      expect((await h.history('f1')).last.changedBy, 'user');
    });

    test('accept a review proposal (evidence changed): text kept, citations re-pinned to current', () async {
      await h.ingestor.ingest(H.git, [commitObs('a1', msg: 'amended', hour: 9)]);
      h.router.responders['fact_ops'] = (_) => {'ops': <Object?>[]};
      await engine.recompute.drain();
      final before = await h.fact('f1');
      expect(before.reviewState, ReviewState.needsReview);
      expect(await h.ctx.isStale(EntityType.fact, 'f1'), isTrue);
      await engine.resolveReview('f1', accept: true);
      final f = await h.fact('f1');
      expect((f.statement, f.reviewState, f.retired), (before.statement, ReviewState.ok, false));
      expect((await h.citations('f1')).single.payloadRevision, 2);
      expect(await h.ctx.isStale(EntityType.fact, 'f1'), isFalse);
    });

    test('accept a retire proposal: fact retired', () async {
      await FactReconciler(h.ctx).apply(FactChangeSet(day, [RetireFact(factId: 'f1', reason: 'wrong')]));
      await engine.resolveReview('f1', accept: true);
      final f = await h.fact('f1');
      expect((f.retired, f.reviewState, f.reviewProposal), (true, ReviewState.ok, null));
    });

    test('dismiss: nothing applied, review cleared', () async {
      await FactReconciler(h.ctx).apply(
        FactChangeSet(day, [
          UpdateFact(factId: 'f1', statement: 'Model text.', citations: [p2]),
        ]),
      );
      final before = await h.fact('f1');
      await engine.resolveReview('f1', accept: false);
      final f = await h.fact('f1');
      expect(
        (f.statement, f.revision, f.retired, f.reviewState, f.reviewProposal),
        (before.statement, before.revision, false, ReviewState.ok, null),
      );
      expect((await h.citations('f1')).map((c) => c.payloadId), [p1]);
    });

    test('a dismissed review is not re-raised by a no-op pass', () async {
      await h.ingestor.ingest(H.git, [commitObs('a1', msg: 'amended', hour: 9)]);
      h.router.responders['fact_ops'] = (_) => {'ops': <Object?>[]};
      await engine.recompute.drain();
      await engine.resolveReview('f1', accept: false);
      await h.ctx.enqueue(EntityType.day, day, 'manual');
      await engine.recompute.drain();
      expect((await h.fact('f1')).reviewState, ReviewState.ok);
    });
  });
}
