import 'dart:convert';

import 'package:core/core.dart';
import 'package:core/src/narrative/extractor.dart';
import 'package:core/src/narrative/reconciler.dart';
import 'package:test/test.dart';

import 'harness.dart';

void main() {
  late H h;
  late FactReconciler rec;
  late String e1, p1, e2, p2;
  setUp(() async {
    h = H();
    await h.setUp();
    rec = FactReconciler(h.ctx);
    e1 = await h.commit('a1', at(10), msg: 'Add retries');
    p1 = await h.pid(e1);
    e2 = await h.pr('pr1', at(11), title: 'Retries PR');
    p2 = await h.pid(e2);
  });
  tearDown(() => h.close());

  Future<ReconcileResult> apply(List<FactOp> ops, {String d = day}) => rec.apply(FactChangeSet(d, ops));
  CreateFact create(
    List<String> cites, {
    FactType type = FactType.outcome,
    String st = 'Shipped retries.',
    bool win = false,
  }) => CreateFact(type: type, statement: st, citations: cites, suggestWin: win);

  group('citation checks', () {
    test('unknown and empty citations are dropped', () async {
      final r = await apply([
        create(['nope']),
        create([]),
        create([p1, 'nope']),
      ]);
      expect(r.created, 0);
      expect(r.dropped, hasLength(3));
      expect(await h.facts(), isEmpty);
    });

    test('a payload from another day is out of the input', () async {
      final other = await h.pid(await h.commit('b1', at(10, 0, '2026-11-16')));
      final r = await apply([
        create([other]),
      ]);
      expect((r.created, r.dropped.length), (0, 1));
    });

    test('hidden evidence and tombstoned payloads cannot be cited', () async {
      await h.setHidden(e1, true);
      await h.ingestor.ingest(H.gh, [
        PayloadObservation(
          externalId: 'pr1',
          kind: PayloadKind.pullRequest,
          content: const {},
          occurredStart: at(11),
          title: 't',
          tombstone: true,
        ),
      ]);
      final r = await apply([
        create([p1]),
        create([p2]),
      ]);
      expect((r.created, r.dropped.length), (0, 2));
    });

    test('an update with a bad citation is dropped and the fact is unchanged', () async {
      await h.insertFact('f1', [p1]);
      final r = await apply([
        UpdateFact(factId: 'f1', statement: 'Changed.', citations: ['nope']),
      ]);
      expect(r.dropped, hasLength(1));
      final f = await h.fact('f1');
      expect((f.statement, f.revision), ('Did a thing.', 1));
    });
  });

  test('create → inferred, revision 1, FactRevision, citations pinned to current revisions', () async {
    await h.commit('a1', at(10), msg: 'Add retries', extra: {'v': 2}); // p1 now at r2
    final r = await apply([
      create([p1, p2]),
    ]);
    expect(r.created, 1);
    final f = (await h.facts()).single;
    expect((f.origin, f.revision, f.periodStart, f.periodEnd, f.retired), (FactOrigin.inferred, 1, day, day, false));
    final hist = await h.history(f.id);
    expect(hist.map((x) => (x.revision, x.statement, x.changedBy)), [(1, 'Shipped retries.', 'model')]);
    final cites = {for (final c in await h.citations(f.id)) c.payloadId: c.payloadRevision};
    expect(cites, {p1: 2, p2: 1});
    final deps = {for (final d in await h.depsOf(EntityType.fact, f.id)) d.inputId: d.inputRevision};
    expect(deps, {p1: 2, p2: 1});
    expect(await h.ctx.isStale(EntityType.fact, f.id), isFalse);
  });

  test('the day records its input revisions', () async {
    await apply([]);
    final deps = {for (final d in await h.depsOf(EntityType.day, day)) d.inputId: d.inputRevision};
    expect(deps, {p1: 1, p2: 1});
  });

  group('suggest_win', () {
    test('only outcomes become suggested', () async {
      await apply([
        create([p1], win: true),
        create([p2], type: FactType.decision, st: 'Decided to retry.', win: true),
        create([p2], st: 'Merged PR.', win: false),
      ]);
      final byStatement = {for (final f in await h.facts()) f.statement: f.winStatus};
      expect(byStatement, {
        'Shipped retries.': WinStatus.suggested,
        'Decided to retry.': WinStatus.none,
        'Merged PR.': WinStatus.none,
      });
    });

    test('never re-suggested after the user rejected a win over the same payloads', () async {
      await h.insertFact('old', [p1], win: WinStatus.rejected, origin: FactOrigin.confirmed, statement: 'Old win.');
      await apply([
        create([p1, p2], st: 'Shipped retries v2.', win: true),
      ]);
      final f = (await h.facts()).firstWhere((f) => f.id != 'old');
      expect(f.winStatus, WinStatus.none);
    });

    test('a win rejection over other payloads does not block a suggestion', () async {
      await h.insertFact('old', [p2], win: WinStatus.rejected, origin: FactOrigin.confirmed, statement: 'Old win.');
      await apply([
        create([p1], win: true),
      ]);
      expect((await h.facts()).firstWhere((f) => f.id != 'old').winStatus, WinStatus.suggested);
    });
  });

  test('never re-creates a fact the user rejected', () async {
    await h.insertFact(
      'rej',
      [p1],
      statement: 'Shipped retries.',
      origin: FactOrigin.userEdited,
      retired: true,
      win: WinStatus.rejected,
    );
    final r = await apply([
      create([p1], st: 'shipped   RETRIES'),
    ]);
    expect(r.created, 0);
    expect(r.dropped.single, contains('rejected'));
  });

  test('the extractor prompt lists user-rejected facts so the model avoids them', () async {
    await h.insertFact('rej', [p1], statement: 'Shipped retries.', origin: FactOrigin.userEdited, retired: true);
    await LlmFactExtractor(h.ctx).extract(day);
    final prompt = h.router.of('fact_ops').single.user;
    expect(prompt, contains('Rejected by the user'));
    expect(prompt, contains('Shipped retries.'));
  });

  group('model-owned facts', () {
    test('update bumps revision, appends history and re-pins citations', () async {
      await h.insertFact('f1', [p1]);
      final r = await apply([
        UpdateFact(factId: 'f1', statement: 'Shipped retries to prod.', citations: [p1, p2]),
      ]);
      expect(r.updated, 1);
      final f = await h.fact('f1');
      expect((f.statement, f.revision, f.origin), ('Shipped retries to prod.', 2, FactOrigin.inferred));
      expect((await h.history('f1')).map((x) => (x.revision, x.changedBy)), [(1, 'model'), (2, 'model')]);
      expect((await h.citations('f1')).map((c) => c.payloadId).toSet(), {p1, p2});
      expect(await h.ctx.isStale(EntityType.fact, 'f1'), isFalse);
    });

    test('retire bumps revision and appends history', () async {
      await h.insertFact('f1', [p1]);
      final r = await apply([RetireFact(factId: 'f1', reason: 'wrong')]);
      expect(r.retired, 1);
      final f = await h.fact('f1');
      expect((f.retired, f.revision), (true, 2));
      expect(await h.history('f1'), hasLength(2));
    });

    test('a model-owned fact with no live citations is retired', () async {
      await h.insertFact('f1', [p2]);
      await h.ingestor.ingest(H.gh, [
        PayloadObservation(
          externalId: 'pr1',
          kind: PayloadKind.pullRequest,
          content: const {},
          occurredStart: at(11),
          title: 't',
          tombstone: true,
        ),
      ]);
      await apply([]);
      final f = await h.fact('f1');
      expect((f.retired, f.revision), (true, 2));
    });

    test('a fact citing hidden evidence only is retired', () async {
      await h.insertFact('f1', [p1]);
      await h.setHidden(e1, true);
      await apply([]);
      expect((await h.fact('f1')).retired, isTrue);
    });
  });

  group('protected facts', () {
    for (final (name, origin, win) in [
      ('confirmed', FactOrigin.confirmed, WinStatus.none),
      ('user-edited', FactOrigin.userEdited, WinStatus.none),
      ('user-created', FactOrigin.userCreated, WinStatus.none),
      ('accepted win', FactOrigin.inferred, WinStatus.accepted),
    ]) {
      test('$name: update → needsReview + proposal, fact unchanged', () async {
        await h.insertFact('f1', [p1], origin: origin, win: win);
        final r = await apply([
          UpdateFact(factId: 'f1', statement: 'Model rewrite.', citations: [p1]),
        ]);
        expect(r.proposed, 1);
        final f = await h.fact('f1');
        expect((f.statement, f.revision, f.retired, f.origin), ('Did a thing.', 1, false, origin));
        expect(f.reviewState, ReviewState.needsReview);
        final proposal = jsonDecode(f.reviewProposal!) as Map;
        expect(proposal['statement'], 'Model rewrite.');
        expect(await h.history('f1'), hasLength(1));
      });

      test('$name: retire → needsReview + retire proposal, not retired', () async {
        await h.insertFact('f1', [p1], origin: origin, win: win);
        await apply([RetireFact(factId: 'f1', reason: 'gone')]);
        final f = await h.fact('f1');
        expect((f.retired, f.revision, f.reviewState), (false, 1, ReviewState.needsReview));
        expect((jsonDecode(f.reviewProposal!) as Map)['retire'], isTrue);
      });
    }

    test('protected fact with no live citations is proposed for retirement, not retired', () async {
      await h.insertFact('f1', [p1], origin: FactOrigin.confirmed);
      await h.setHidden(e1, true);
      await apply([]);
      final f = await h.fact('f1');
      expect((f.retired, f.reviewState), (false, ReviewState.needsReview));
      expect((jsonDecode(f.reviewProposal!) as Map)['retire'], isTrue);
    });

    test('protected fact whose evidence is unchanged and untouched by ops stays ok', () async {
      await h.insertFact('f1', [p1], origin: FactOrigin.confirmed);
      await apply([]);
      expect((await h.fact('f1')).reviewState, ReviewState.ok);
    });
  });

  test('time-allocation ops from the model are dropped', () async {
    await h.insertFact('t1', [p1], type: FactType.timeAllocation, statement: '1 h');
    final r = await apply([
      create([p1], type: FactType.timeAllocation),
      UpdateFact(factId: 't1', statement: 'x', citations: [p1]),
      RetireFact(factId: 't1', reason: 'x'),
    ]);
    expect(r.dropped, hasLength(3));
    final t = await h.fact('t1');
    expect((t.statement, t.retired), ('1 h', false));
  });

  test('parseOps drops time_allocation type and malformed entries', () {
    final ops = LlmFactExtractor.parseOps({
      'ops': [
        createOp(['x'], type: 'time_allocation'),
        createOp(['x'], statement: '  '),
        {'op': 'update', 'fact_id': null, 'statement': 's', 'citations': <String>[]},
        createOp(['x']),
      ],
    });
    expect(ops.single, isA<CreateFact>());
  });

  test('an unknown project id falls back to the cited evidence project', () async {
    await h.setProject(e1, 'pay');
    await apply([
      CreateFact(type: FactType.outcome, statement: 's', citations: [p1], projectId: 'nope'),
    ]);
    expect((await h.facts()).single.projectId, 'pay');
  });

  test('a model-owned fact left alone after its payload changed is re-pinned (not stale, no revision bump)', () async {
    await h.insertFact('f1', [p1]);
    await h.commit('a1', at(10), msg: 'Add retries', extra: {'v': 2});
    final r = await apply([]);
    expect(r.repinned, 1);
    final f = await h.fact('f1');
    expect(f.revision, 1);
    expect((await h.citations('f1')).single.payloadRevision, 2);
  });

  test('a user-touched fact is never re-pinned by the model', () async {
    await h.insertFact('f1', [p1], origin: FactOrigin.confirmed);
    await h.commit('a1', at(10), msg: 'Add retries', extra: {'v': 2});
    await apply([]);
    expect((await h.citations('f1')).single.payloadRevision, 1);
  });

  test('ops on another day\'s facts are dropped', () async {
    final other = await h.pid(await h.commit('b1', at(10, 0, '2026-11-16')));
    await h.insertFact('f1', [other], d: '2026-11-16');
    final r = await apply([RetireFact(factId: 'f1', reason: 'x')]);
    expect(r.dropped, hasLength(1));
    expect((await h.fact('f1')).retired, isFalse);
  });

  test('model updates never touch a fact the user retired (rejected)', () async {
    await h.insertFact('f1', [p1], origin: FactOrigin.userEdited, retired: true);
    await apply([
      UpdateFact(factId: 'f1', statement: 'back', citations: [p1]),
    ]);
    final f = await h.fact('f1');
    expect((f.retired, f.statement), (true, 'Did a thing.'));
  });

  test('a suggested (not accepted) win stays model-owned and updatable', () async {
    await h.insertFact('f1', [p1], win: WinStatus.suggested);
    await apply([]);
    expect((await h.fact('f1')).winStatus, WinStatus.suggested);
    // sanity: suggested (not accepted) model-owned facts are not protected.
    await apply([
      UpdateFact(factId: 'f1', statement: 'New.', citations: [p1]),
    ]);
    expect((await h.fact('f1')).statement, 'New.');
  });

  test('db has no orphan citations after updates', () async {
    await h.insertFact('f1', [p1, p2]);
    await apply([
      UpdateFact(factId: 'f1', statement: 'Only PR.', citations: [p2]),
    ]);
    expect((await h.citations('f1')).map((c) => c.payloadId), [p2]);
    final rows = await (h.db.select(h.db.citations)..where((c) => c.factId.equals('f1'))).get();
    expect(rows, hasLength(1));
  });
}
