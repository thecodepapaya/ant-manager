// Independent tests (#99) for DECISIONS #119: (a) the extraction prompt's type definitions,
// importance rubric and fact_ops field order; (b) a star with no Outcome citing the evidence offers
// the live, model-owned outcome / problem_solved / invisible_work facts citing it to the win call,
// and a returned fact_id turns that fact into the accepted win instead of writing a new one.
import 'package:core/core.dart';
import 'package:core/src/narrative/extractor.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:test/test.dart';

import 'harness.dart';

void main() {
  late H h;
  late WinService wins;
  late String e1, p1, pX, e2, p2;
  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    h = H();
    await h.setUp();
    wins = WinService(h.ctx);
    e1 = await h.commit('a1', at(10), msg: 'Ship retries');
    p1 = await h.pid(e1);
    // A second payload grouped into the same evidence (same group key as the commit).
    await h.ingest(
      H.gh,
      PayloadObservation(
        externalId: 'pr-a1',
        kind: PayloadKind.pullRequest,
        content: {'title': 'Retries PR', 'repo': 'acme/api', 'state': 'merged'},
        occurredStart: at(10, 5),
        title: 'Retries PR',
        groupKey: 'a1',
      ),
    );
    pX = (await h.payloadByExt(H.gh, 'pr-a1')).id;
    e2 = await h.commit('b1', at(11), msg: 'Unrelated');
    p2 = await h.pid(e2);
  });
  tearDown(() => h.close());

  /// Model answers the win call with [factId] (and cites [cites], default: the first payload offered).
  void pick(Object? factId, {String statement = 'Shipped payment retries.', List<String>? cites}) =>
      h.router.responders['win'] = (c) => {
        'fact_id': factId,
        'statement': statement,
        'citations': cites ?? [FakeRouter.payloadIds(c.user).first],
      };

  /// fact ids listed in the win prompt's "Existing facts" section.
  List<String> offered() =>
      RegExp(r'^- fact_id=(\S+)', multiLine: true).allMatches(h.router.of('win').single.user).map((m) => m.group(1)!).toList();

  test('the grouped payload really belongs to the starred evidence', () async {
    expect((await h.payloadsOf(e1)).map((p) => p.id).toSet(), {p1, pX});
  });

  group('reuse path', () {
    test('picked invisible_work fact becomes the accepted Outcome win; no new fact', () async {
      await h.insertFact('iw', [p1, p2], type: FactType.invisibleWork, statement: 'Paired on retries.');
      final before = (await h.facts()).length;
      pick('iw', statement: ' Shipped payment retries. ', cites: [pX]);
      final id = await wins.starEvidence(e1);
      expect(id, 'iw');
      expect((await h.facts()).length, before, reason: 'no new fact');
      final f = await h.fact('iw');
      expect(
        (f.type, f.statement, f.importance, f.origin, f.winStatus, f.retired, f.revision),
        (FactType.outcome, 'Shipped payment retries.', 1.0, FactOrigin.confirmed, WinStatus.accepted, false, 2),
      );
      expect(
        (await h.citations('iw')).map((c) => c.payloadId).toSet(),
        {p1, p2, pX},
        reason: 'union of the fact\'s citations and the call\'s',
      );
      final hist = await h.history('iw');
      expect((hist.last.revision, hist.last.statement, hist.last.changedBy), (2, 'Shipped payment retries.', 'user'));
      expect(offered(), ['iw']);
    });

    test('picked problem_solved fact is reused too', () async {
      await h.insertFact('ps', [p1], type: FactType.problemSolved);
      pick('ps');
      expect(await wins.starEvidence(e1), 'ps');
      expect((await h.fact('ps')).type, FactType.outcome);
    });

    test('the reused win is now protected (a later star needs no model call)', () async {
      await h.insertFact('iw', [p1], type: FactType.invisibleWork);
      pick('iw');
      await wins.starEvidence(e1);
      expect(await wins.starEvidence(e1), 'iw');
      expect(h.router.of('win'), hasLength(1));
    });

    test('candidates are listed with id, type and statement', () async {
      await h.insertFact('iw', [p1], type: FactType.invisibleWork, statement: 'Reviewed the retry PR.');
      await h.insertFact('ps', [pX], type: FactType.problemSolved, statement: 'Fixed the retry loop.');
      pick(null);
      await wins.starEvidence(e1);
      final u = h.router.of('win').single.user;
      expect(u, contains('- fact_id=iw type=invisible_work: Reviewed the retry PR.'));
      expect(u, contains('- fact_id=ps type=problem_solved: Fixed the retry loop.'));
    });

    test('no candidates → the prompt says (none)', () async {
      pick(null);
      await wins.starEvidence(e1);
      expect(h.router.of('win').single.user, contains('Existing facts citing this evidence:\n(none)'));
    });
  });

  group('never offered, never retyped', () {
    test('decision and hiccup facts citing the evidence', () async {
      await h.insertFact('d', [p1], type: FactType.decision, statement: 'Chose retries.');
      await h.insertFact('hc', [p1], type: FactType.hiccup, statement: 'Reverted retries.');
      await h.insertFact('iw', [p1], type: FactType.invisibleWork);
      pick(null);
      await wins.starEvidence(e1);
      expect(offered(), ['iw']);
      expect(h.router.of('win').single.user, isNot(contains('Chose retries.')));
      expect(h.router.of('win').single.user, isNot(contains('Reverted retries.')));
    });

    for (final (label, type) in [('decision', FactType.decision), ('hiccup', FactType.hiccup)]) {
      test('a returned $label id is ignored: new fact, $label untouched', () async {
        await h.insertFact('x', [p1], type: type);
        final before = await h.fact('x');
        pick('x');
        final id = await wins.starEvidence(e1);
        expect(id, isNot('x'));
        expect((await h.fact(id)).origin, FactOrigin.userCreated);
        final after = await h.fact('x');
        expect((after.type, after.winStatus, after.revision, after.statement), (type, WinStatus.none, 1, before.statement));
      });
    }

    for (final (label, origin) in [
      ('userEdited', FactOrigin.userEdited),
      ('userCreated', FactOrigin.userCreated),
      ('confirmed', FactOrigin.confirmed),
    ]) {
      test('a $label (user-touched) fact is not offered and not reused', () async {
        await h.insertFact('u', [p1], type: FactType.invisibleWork, origin: origin);
        pick('u');
        final id = await wins.starEvidence(e1);
        expect(offered(), isEmpty);
        expect(id, isNot('u'));
        final u = await h.fact('u');
        expect((u.type, u.origin, u.revision), (FactType.invisibleWork, origin, 1));
      });
    }

    test('facts citing only other evidence are not offered', () async {
      await h.insertFact('other', [p2], type: FactType.invisibleWork);
      pick(null);
      await wins.starEvidence(e1);
      expect(offered(), isEmpty);
    });
  });

  group('fact_id that is not a valid pick → a new fact', () {
    Future<void> expectNew(String badId) async {
      final before = (await h.facts()).length;
      final id = await wins.starEvidence(e1);
      expect(id, isNot(badId));
      expect((await h.facts()).length, before + 1);
      final f = await h.fact(id);
      expect((f.type, f.origin, f.winStatus, f.importance), (FactType.outcome, FactOrigin.userCreated, WinStatus.accepted, 1.0));
    }

    test('unknown id', () async {
      await h.insertFact('iw', [p1], type: FactType.invisibleWork);
      pick('no-such-fact');
      await expectNew('no-such-fact');
      expect((await h.fact('iw')).type, FactType.invisibleWork);
    });

    test('protected (accepted) fact id', () async {
      await h.insertFact('acc', [p1], type: FactType.invisibleWork, win: WinStatus.accepted);
      pick('acc');
      await expectNew('acc');
      expect((await h.fact('acc')).type, FactType.invisibleWork);
    });

    test('retired fact id', () async {
      await h.insertFact('r', [p1], type: FactType.invisibleWork, retired: true);
      pick('r');
      await expectNew('r');
      final r = await h.fact('r');
      expect((r.type, r.retired, r.revision), (FactType.invisibleWork, true, 1));
      expect(offered(), isEmpty);
    });

    test('a fact citing only other evidence', () async {
      await h.insertFact('other', [p2], type: FactType.invisibleWork);
      pick('other');
      await expectNew('other');
      expect((await h.fact('other')).type, FactType.invisibleWork);
    });
  });

  group('the pick is re-checked in the write transaction', () {
    test('picked fact retired while the model call runs → new fact, picked one untouched', () async {
      await h.insertFact('iw', [p1], type: FactType.invisibleWork, statement: 'Paired on retries.');
      h.router.onCall = (c) async {
        if (c.schema == 'win') {
          await (h.db.update(h.db.facts)..where((f) => f.id.equals('iw'))).write(const FactsCompanion(retired: Value(true)));
        }
      };
      pick('iw');
      final id = await wins.starEvidence(e1);
      expect(id, isNot('iw'));
      expect(offered(), ['iw'], reason: 'it was a candidate when the call started');
      final iw = await h.fact('iw');
      expect(
        (iw.type, iw.statement, iw.retired, iw.winStatus, iw.revision),
        (FactType.invisibleWork, 'Paired on retries.', true, WinStatus.none, 1),
      );
      expect((await h.fact(id)).origin, FactOrigin.userCreated);
    });

    test('picked fact user-edited while the model call runs → new fact, picked one untouched', () async {
      await h.insertFact('iw', [p1], type: FactType.invisibleWork, statement: 'Paired on retries.');
      h.router.onCall = (c) async {
        if (c.schema == 'win') {
          await (h.db.update(h.db.facts)..where((f) => f.id.equals('iw'))).write(
            const FactsCompanion(statement: Value('My own words.'), origin: Value(FactOrigin.userEdited)),
          );
        }
      };
      pick('iw');
      final id = await wins.starEvidence(e1);
      expect(id, isNot('iw'));
      final iw = await h.fact('iw');
      expect(
        (iw.type, iw.statement, iw.origin, iw.winStatus, iw.importance),
        (FactType.invisibleWork, 'My own words.', FactOrigin.userEdited, WinStatus.none, 0.5),
      );
      expect((await h.citations('iw')).map((c) => c.payloadId), [p1]);
    });
  });

  group('extraction prompt (a)', () {
    test('system prompt has the type definitions and the importance rubric anchors', () {
      const s = LlmFactExtractor.system;
      for (final anchor in [
        '0.1-0.2 routine',
        '0.3-0.4 normal',
        '0.5-0.6 notable',
        '0.7-0.8 significant',
        '0.9-1.0 exceptional',
        'When unsure whether something is an outcome, it is not.',
        'NOT an outcome on its own',
        'suggest_win: true only for an outcome of importance 0.7 or more',
      ]) {
        expect(s, contains(anchor));
      }
      for (final t in ['outcome:', 'problem_solved:', 'invisible_work:', 'hiccup:', 'decision:']) {
        expect(s, contains('- $t'));
      }
    });

    test('fact_ops item fields are ordered citations, statement, type, importance, ...', () {
      final item = ((LlmFactExtractor.schema['properties'] as Map)['ops'] as Map)['items'] as Map;
      const order = ['op', 'fact_id', 'citations', 'statement', 'type', 'importance', 'suggest_win', 'project_id', 'reason'];
      expect((item['properties'] as Map).keys.toList(), order);
      expect(item['required'], order);
    });

    test('the extractor sends that system prompt and schema to the model', () async {
      await h.insertFact('f', [p1]);
      await LlmFactExtractor(h.ctx).extract(day);
      final req = h.router.of('fact_ops').single.request;
      expect(req.messages.first.role, 'system');
      expect(req.messages.first.text, LlmFactExtractor.system);
      expect(req.schema, same(LlmFactExtractor.schema));
    });

    test('win schema requires a nullable fact_id', () {
      final props = WinService.schema['properties'] as Map;
      expect((props['fact_id'] as Map)['type'], ['string', 'null']);
      expect(WinService.schema['required'], containsAll(['fact_id', 'statement', 'citations']));
    });
  });
}
