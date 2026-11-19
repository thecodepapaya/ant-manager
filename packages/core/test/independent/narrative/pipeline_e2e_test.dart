import 'dart:convert';

import 'package:core/core.dart';
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
    registerNarrativePipeline(engine);
    // Extraction: create one outcome citing the first payload, or update the first existing fact.
    h.router.responders['fact_ops'] = (c) {
      final existing = RegExp(r'fact_id=(\S+) type=(?!time)').firstMatch(c.user)?.group(1);
      final ids = FakeRouter.payloadIds(c.user);
      if (ids.isEmpty) return {'ops': <Object?>[]};
      return {
        'ops': [
          existing == null
              ? createOp([ids.first], statement: 'Shipped retries.')
              : updateOp(existing, 'Shipped retries (amended) ${c.user.hashCode}.', [ids.first]),
        ],
      };
    };
  });
  tearDown(() => h.close());

  Future<void> ingestDay() async {
    await engine.ingestor.ingest(H.git, [
      PayloadObservation(
        externalId: 'a1',
        kind: PayloadKind.commit,
        content: const {'sha': 'a1', 'message': 'Add retries'},
        occurredStart: at(10),
        title: 'Add retries',
      ),
    ]);
    await engine.ingestor.ingest(H.cal, [
      PayloadObservation(
        externalId: 'm1',
        kind: PayloadKind.calendarEvent,
        content: {'title': 'Design review', 'start': at(14).toIso8601String(), 'end': at(15).toIso8601String()},
        occurredStart: at(14),
        occurredEnd: at(15),
        title: 'Design review',
      ),
    ]);
  }

  Future<void> amendCommit(String msg) => engine.ingestor.ingest(H.git, [
    PayloadObservation(
      externalId: 'a1',
      kind: PayloadKind.commit,
      content: {'sha': 'a1', 'message': msg},
      occurredStart: at(10),
      title: msg,
    ),
  ]);

  Future<Fact> outcome() async => (await h.facts(type: FactType.outcome)).single;

  test('ingest → drain → facts, enrichments, time facts, empty queue, one extraction call', () async {
    await ingestDay();
    await engine.recompute.drain();
    expect(h.router.of('fact_ops'), hasLength(1));
    final f = await outcome();
    expect((f.statement, f.origin, f.revision), ('Shipped retries.', FactOrigin.inferred, 1));
    final payloads = await h.db.select(h.db.payloads).get();
    for (final p in payloads) {
      expect(await h.enrichmentOf(p.id), isNotNull, reason: p.kind.name);
    }
    final time = await h.timeFacts();
    final byBasis = {
      for (final t in time) (jsonDecode(t.details) as Map)['basis']: (jsonDecode(t.details) as Map)['minutes'],
    };
    expect(byBasis, {'measured': 60, 'estimated': 30});
    expect(await h.db.select(h.db.recomputeQueue).get(), isEmpty);
    for (final e in await h.db.select(h.db.evidences).get()) {
      expect(e.importanceSetBy, ImportanceSetBy.model);
    }
    expect(await h.ctx.isStale(EntityType.fact, f.id), isFalse);
  });

  test('extraction prompt includes the enrichment summaries', () async {
    await ingestDay();
    await engine.recompute.drain();
    expect(h.router.of('fact_ops').single.user, contains('summary: summary of'));
  });

  test('an unchanged day costs no model calls', () async {
    await ingestDay();
    await engine.recompute.drain();
    final n = h.router.calls.length;
    await ingestDay(); // identical re-sync: nothing queued
    expect(await h.db.select(h.db.recomputeQueue).get(), isEmpty);
    await h.ctx.enqueue(EntityType.day, day, 'manual');
    await engine.recompute.drain();
    expect(h.router.calls.length, n);
    expect(await h.db.select(h.db.recomputeQueue).get(), isEmpty);
  });

  test('amending a payload re-extracts the same fact id at revision 2, not stale', () async {
    await ingestDay();
    await engine.recompute.drain();
    final id = (await outcome()).id;
    final calls = h.router.of('fact_ops').length;
    await amendCommit('Add retries with backoff');
    await engine.recompute.drain();
    expect(h.router.of('fact_ops').length, calls + 1, reason: 'exactly one re-extraction');
    final f = await outcome();
    expect((f.id, f.revision), (id, 2));
    expect(f.statement, startsWith('Shipped retries (amended)'));
    expect(await h.ctx.isStale(EntityType.fact, id), isFalse);
    expect(await h.history(id), hasLength(2));
    expect(await h.db.select(h.db.recomputeQueue).get(), isEmpty);
  });

  test('a confirmed fact whose evidence changes → needsReview, unchanged', () async {
    await ingestDay();
    await engine.recompute.drain();
    final id = (await outcome()).id;
    await engine.confirmFact(id);
    final before = await h.fact(id);
    await amendCommit('Add retries with backoff');
    await engine.recompute.drain();
    final f = await h.fact(id);
    expect(f.reviewState, ReviewState.needsReview);
    expect((f.statement, f.revision, f.origin), (before.statement, before.revision, FactOrigin.confirmed));
    expect(f.reviewProposal, isNotNull);
    expect(await h.db.select(h.db.recomputeQueue).get(), isEmpty);
  });

  test('a confirmed fact whose evidence changes is flagged even if the model proposes nothing', () async {
    await ingestDay();
    await engine.recompute.drain();
    final id = (await outcome()).id;
    await engine.confirmFact(id);
    h.router.responders['fact_ops'] = (_) => {'ops': <Object?>[]};
    await amendCommit('Add retries with backoff');
    await engine.recompute.drain();
    expect((await h.fact(id)).reviewState, ReviewState.needsReview);
  });

  test('hiding evidence retires its model-owned fact and its time', () async {
    await ingestDay();
    await engine.recompute.drain();
    final id = (await outcome()).id;
    final commitEvidence = (await h.payloadByExt(H.git, 'a1')).evidenceId;
    h.router.responders['fact_ops'] = (_) => {'ops': <Object?>[]};
    await engine.setHidden(commitEvidence, true);
    await engine.recompute.drain();
    expect((await h.fact(id)).retired, isTrue);
    final bases = [for (final t in await h.timeFacts()) (jsonDecode(t.details) as Map)['basis']];
    expect(bases, ['measured']);
  });

  test('a protected fact\'s pending review is not wiped by the next no-op pass', () async {
    await ingestDay();
    await engine.recompute.drain();
    final id = (await outcome()).id;
    await engine.confirmFact(id);
    await amendCommit('v2');
    await engine.recompute.drain();
    await h.ctx.enqueue(EntityType.day, day, 'manual');
    await engine.recompute.drain();
    expect((await h.fact(id)).reviewState, ReviewState.needsReview);
  });

  test('starring evidence in a full flow keeps the accepted win through re-extraction', () async {
    await ingestDay();
    await engine.recompute.drain();
    final commitEvidence = (await h.payloadByExt(H.git, 'a1')).evidenceId;
    final id = await WinService(h.ctx).starEvidence(commitEvidence);
    await engine.recompute.drain();
    final f = await h.fact(id);
    expect((f.winStatus, f.retired), (WinStatus.accepted, false));
    await amendCommit('v2');
    await engine.recompute.drain();
    final g = await h.fact(id);
    expect((g.winStatus, g.statement, g.revision), (WinStatus.accepted, f.statement, f.revision));
  });

  test('permanent delete then drain re-extracts the day and leaves no facts citing the deleted evidence', () async {
    await ingestDay();
    await engine.recompute.drain();
    final commitEvidence = (await h.payloadByExt(H.git, 'a1')).evidenceId;
    final calls = h.router.of('fact_ops').length;
    final oldId = (await outcome()).id;
    h.router.responders['fact_ops'] = (_) => {'ops': <Object?>[]};
    await EvidenceDeleter(h.ctx).permanentDelete(commitEvidence);
    await engine.recompute.drain();
    expect(h.router.of('fact_ops').length, calls + 1);
    expect((await h.facts()).map((f) => f.id), isNot(contains(oldId)), reason: 'its only citation was deleted');
    expect(await h.facts(type: FactType.outcome), isEmpty);
    final bases = [for (final t in await h.timeFacts()) (jsonDecode(t.details) as Map)['basis']];
    expect(bases, ['measured']);
    expect(await h.db.select(h.db.recomputeQueue).get(), isEmpty);
  });

  test('a rejected suggested win is not re-suggested by later extractions', () async {
    h.router.responders['fact_ops'] = (c) {
      final ids = FakeRouter.payloadIds(c.user);
      return {
        'ops': [
          createOp([ids.first], statement: 'Shipped retries ${h.router.calls.length}.', suggestWin: true),
        ],
      };
    };
    await ingestDay();
    await engine.recompute.drain();
    final f = await outcome();
    expect(f.winStatus, WinStatus.suggested);
    await engine.setWinStatus(f.id, WinStatus.rejected);
    await amendCommit('v2');
    await engine.recompute.drain();
    final created = (await h.facts(type: FactType.outcome)).where((x) => x.id != f.id).toList();
    expect(created, isNotEmpty);
    expect(created.every((x) => x.winStatus == WinStatus.none), isTrue);
  });

  test('a payload ingested while extraction is running is extracted on a later pass', () async {
    await ingestDay();
    var injected = false;
    h.router.onCall = (c) async {
      if (c.schema != 'fact_ops' || injected) return;
      injected = true;
      await engine.ingestor.ingest(H.git, [
        PayloadObservation(
          externalId: 'b1',
          kind: PayloadKind.commit,
          content: const {'sha': 'b1', 'message': 'Late commit'},
          occurredStart: at(16),
          title: 'Late commit',
        ),
      ]);
    };
    await engine.recompute.drain();
    final late = (await h.payloadByExt(H.git, 'b1')).id;
    final prompts = h.router.of('fact_ops').map((c) => c.user);
    expect(
      prompts.any((u) => u.contains('payload_id=$late')),
      isTrue,
      reason: 'the late payload must reach an extraction prompt',
    );
  });

  test('accepting a time-fact proposal applies its minutes (no endless review loop)', () async {
    await ingestDay();
    await engine.recompute.drain();
    final t = (await h.timeFacts()).firstWhere((f) => f.details.contains('measured'));
    await engine.confirmFact(t.id);
    await engine.ingestor.ingest(H.cal, [
      PayloadObservation(
        externalId: 'm2',
        kind: PayloadKind.calendarEvent,
        content: {'title': 'Sync', 'start': at(16).toIso8601String(), 'end': at(16, 30).toIso8601String()},
        occurredStart: at(16),
        occurredEnd: at(16, 30),
        title: 'Sync',
      ),
    ]);
    await engine.recompute.drain();
    expect((await h.fact(t.id)).reviewState, ReviewState.needsReview);
    await engine.resolveReview(t.id, accept: true);
    await engine.recompute.drain();
    await h.ctx.enqueue(EntityType.day, day, 'manual');
    await engine.recompute.drain();
    final f = await h.fact(t.id);
    expect((jsonDecode(f.details) as Map)['minutes'], 90);
    expect(f.reviewState, ReviewState.ok);
  });
}
