import 'package:core/core.dart';
import 'package:core/src/narrative/importance.dart';
import 'package:core/src/narrative/reconciler.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:test/test.dart';

import 'harness.dart';

void main() {
  late H h;
  late WinService wins;
  late String e1, p1, e2, p2;
  setUp(() async {
    h = H();
    await h.setUp();
    wins = WinService(h.ctx);
    e1 = await h.commit('a1', at(10), msg: 'Ship retries');
    p1 = await h.pid(e1);
    e2 = await h.pr('pr1', at(11));
    p2 = await h.pid(e2);
  });
  tearDown(() => h.close());

  test('existing outcome citing the evidence → accepted + confirmed, no model call', () async {
    await h.insertFact('f1', [p1], win: WinStatus.suggested);
    final id = await wins.starEvidence(e1);
    expect(id, 'f1');
    final f = await h.fact('f1');
    expect((f.winStatus, f.origin, f.revision), (WinStatus.accepted, FactOrigin.confirmed, 2));
    expect((await h.history('f1')).last.changedBy, 'user');
    expect(h.router.calls, isEmpty);
    final ev = await h.evidence(e1);
    expect((ev.starred, ev.importance, ev.importanceSetBy), (true, 1.0, ImportanceSetBy.user));
  });

  test('a user-edited outcome keeps its origin when accepted', () async {
    await h.insertFact('f1', [p1], origin: FactOrigin.userEdited);
    await wins.starEvidence(e1);
    expect((await h.fact('f1')).origin, FactOrigin.userEdited);
    expect((await h.fact('f1')).winStatus, WinStatus.accepted);
  });

  test('non-outcome or retired facts do not count as the win', () async {
    await h.insertFact('d', [p1], type: FactType.decision);
    await h.insertFact('r', [p1], retired: true);
    final id = await wins.starEvidence(e1);
    expect(id, isNot(anyOf('d', 'r')));
    expect(h.router.of('win'), hasLength(1));
    expect((await h.fact('d')).winStatus, WinStatus.none);
  });

  test('no outcome → one model call → userCreated + accepted with valid citations only', () async {
    h.router.responders['win'] = (_) => {
      'statement': ' Shipped payment retries. ',
      'citations': [p1, p2, 'bogus'],
    };
    final id = await wins.starEvidence(e1);
    expect(h.router.calls, hasLength(1));
    expect(h.router.calls.single.route, LlmRoute.extraction);
    final f = await h.fact(id);
    expect(
      (f.type, f.origin, f.winStatus, f.statement, f.periodStart, f.importance),
      (FactType.outcome, FactOrigin.userCreated, WinStatus.accepted, 'Shipped payment retries.', day, 1.0),
    );
    expect((await h.citations(id)).map((c) => c.payloadId), [p1], reason: 'only payloads of the starred evidence');
    expect((await h.history(id)).single.changedBy, 'user');
  });

  test('model gives no valid citations → cites the starred evidence', () async {
    final id = await wins.starEvidence(e1);
    expect((await h.citations(id)).map((c) => c.payloadId), [p1]);
  });

  test('starring twice does not create a second win', () async {
    final a = await wins.starEvidence(e1);
    final b = await wins.starEvidence(e1);
    expect(a, b);
    expect(h.router.of('win'), hasLength(1));
    expect(await h.facts(type: FactType.outcome), hasLength(1));
  });

  test('the created win is protected from later model updates', () async {
    final id = await wins.starEvidence(e1);
    await FactReconciler(h.ctx).apply(
      FactChangeSet(day, [
        UpdateFact(factId: id, statement: 'Model rewrite.', citations: [p1]),
      ]),
    );
    final f = await h.fact(id);
    expect((f.statement, f.revision, f.reviewState), ('Shipped the thing.', 1, ReviewState.needsReview));
  });

  test('starring hidden evidence keeps importance 0', () async {
    await (h.db.update(
      h.db.evidences,
    )..where((e) => e.id.equals(e1))).write(const EvidencesCompanion(hidden: Value(true)));
    await wins.starEvidence(e1);
    final ev = await h.evidence(e1);
    expect((ev.importance, ev.starred, ev.importanceSetBy), (0.0, true, ImportanceSetBy.user));
  });

  test(
    'evidence deleted while the win call runs: no uncited fact is written',
    () async {
      h.router.onCall = (c) async {
        if (c.schema == 'win') await EvidenceDeleter(h.ctx).permanentDelete(e1);
      };
      try {
        await wins.starEvidence(e1);
      } catch (_) {
        // failing is acceptable; writing an uncited fact is not
      }
      for (final f in await h.facts()) {
        expect(await h.citations(f.id), isNotEmpty, reason: 'invariant 4: every fact has >= 1 citation');
      }
    },
  );

  test(
    'starring an item a rule hid: the user star beats the rule (importance 1, visible)',
    () async {
      await h.rule('r', {'titlePattern': 'ship'}, CurationAction.hide);
      await ImportanceScorer(h.ctx).scoreDay(day);
      expect((await h.evidence(e1)).hidden, isTrue);
      await wins.starEvidence(e1);
      final ev = await h.evidence(e1);
      expect((ev.importance, ev.hidden), (1.0, false));
    },
  );
}
