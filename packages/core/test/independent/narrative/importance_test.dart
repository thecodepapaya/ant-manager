import 'package:core/core.dart';
import 'package:core/src/narrative/importance.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:test/test.dart';

import 'harness.dart';

void main() {
  late H h;
  late ImportanceScorer scorer;
  setUp(() async {
    h = H();
    await h.setUp();
    scorer = ImportanceScorer(h.ctx);
  });
  tearDown(() => h.close());

  Future<void> userSet(String id, {bool starred = false, bool hidden = false}) =>
      (h.db.update(h.db.evidences)..where((e) => e.id.equals(id))).write(
        EvidencesCompanion(
          starred: Value(starred),
          hidden: Value(hidden),
          importance: Value(hidden ? 0.0 : 1.0),
          importanceSetBy: const Value(ImportanceSetBy.user),
        ),
      );

  List<String> scoredIds() => [
    for (final c in h.router.of('importance'))
      for (final i in FakeRouter.jsonItems(c.user, 'Rate these evidence items:\n')) i['evidence_id'] as String,
  ];

  test('model scores unscored evidence and records its payload revisions', () async {
    final e = await h.commit('a1', at(10), msg: 'Add retries');
    await scorer.scoreDay(day);
    final ev = await h.evidence(e);
    expect(ev.importance, 0.7);
    expect(ev.importanceSetBy, ImportanceSetBy.model);
    expect(ev.importanceReason, 'fake');
    final deps = await h.depsOf(EntityType.evidence, e);
    expect(deps.map((d) => (d.inputId, d.inputRevision)), [(await h.pid(e), 1)]);
    expect(h.router.of('importance').single.route, LlmRoute.extraction);
  });

  test('unscored evidence starts at the neutral 0.5', () async {
    final e = await h.commit('a1', at(10));
    expect((await h.evidence(e)).importance, 0.5);
  });

  test('user per-item beats rules and the model', () async {
    final starred = await h.commit('a1', at(10), msg: 'Daily sync');
    final hidden = await h.commit('a2', at(11), msg: 'Daily sync 2');
    await userSet(starred, starred: true);
    await userSet(hidden, hidden: true);
    await h.rule('r1', {'titlePattern': 'daily sync'}, CurationAction.setImportance, value: 0.1);
    await scorer.scoreDay(day);
    expect((await h.evidence(starred)).importance, 1.0);
    expect((await h.evidence(starred)).importanceSetBy, ImportanceSetBy.user);
    expect((await h.evidence(hidden)).importance, 0.0);
    expect((await h.evidence(hidden)).hidden, isTrue);
    expect(h.router.calls, isEmpty);
  });

  test('highest-priority enabled rule wins over lower ones and disabled ones', () async {
    final e = await h.commit('a1', at(10), msg: 'Daily sync');
    await h.rule('low', {'titlePattern': 'daily'}, CurationAction.setImportance, value: 0.2, priority: 1);
    await h.rule('high', {'titlePattern': 'sync'}, CurationAction.setImportance, value: 0.9, priority: 5);
    await h.rule('off', {'titlePattern': 'sync'}, CurationAction.hide, priority: 99, enabled: false);
    await scorer.scoreDay(day);
    final ev = await h.evidence(e);
    expect(ev.importance, 0.9);
    expect(ev.importanceSetBy, ImportanceSetBy.rule);
    expect(ev.hidden, isFalse);
    expect(h.router.calls, isEmpty, reason: 'rule-set items are never sent to the model');
  });

  test('hide rule → importance 0 and hidden', () async {
    final e = await h.meeting('m1', at(12), at(13), title: 'Lunch');
    await h.rule('r', {'titlePattern': 'lunch'}, CurationAction.hide);
    await scorer.scoreDay(day);
    final ev = await h.evidence(e);
    expect((ev.importance, ev.hidden, ev.importanceSetBy), (0.0, true, ImportanceSetBy.rule));
  });

  test('setImportance stores the rule value', () async {
    final e = await h.meeting('m1', at(9), at(10), title: 'Standup');
    await h.rule('r', {'titlePattern': 'standup'}, CurationAction.setImportance, value: 0.15);
    await scorer.scoreDay(day);
    expect((await h.evidence(e)).importance, closeTo(0.15, 1e-9));
  });

  group('title patterns', () {
    test('case-insensitive substring', () {
      expect(RuleMatcher.titleMatches('DAILY sync', 'Team daily SYNC (eng)'), isTrue);
      expect(RuleMatcher.titleMatches('weekly', 'Team daily sync'), isFalse);
    });
    test('glob with * and ? is anchored and case-insensitive', () {
      expect(RuleMatcher.titleMatches('lunch*', 'LUNCH with Bob'), isTrue);
      expect(RuleMatcher.titleMatches('lunch*', 'Team lunch'), isFalse);
      expect(RuleMatcher.titleMatches('*lunch', 'Team Lunch'), isTrue);
      expect(RuleMatcher.titleMatches('1?1 *', '1:1 with Ann'), isTrue);
      expect(RuleMatcher.titleMatches('1?1', '1:1 with Ann'), isFalse);
    });
    test('regex metacharacters in a glob are literal', () {
      expect(RuleMatcher.titleMatches('[ops]*', '[OPS] deploy'), isTrue);
      expect(RuleMatcher.titleMatches('a.c*', 'abc'), isFalse);
    });
  });

  test('repo matcher: PR content repo and git source path', () async {
    final pr = await h.pr('pr1', at(10), repo: 'acme/api');
    final other = await h.pr('pr2', at(11), repo: 'acme/web');
    final c = await h.commit('a1', at(12)); // git source path ends with /acme/api
    await h.rule('r', {'repo': 'ACME/api'}, CurationAction.setImportance, value: 0.95);
    await scorer.scoreDay(day);
    expect((await h.evidence(pr)).importanceSetBy, ImportanceSetBy.rule);
    expect((await h.evidence(c)).importanceSetBy, ImportanceSetBy.rule);
    expect((await h.evidence(other)).importanceSetBy, ImportanceSetBy.model);
  });

  test('attendee matchers', () async {
    final big = await h.meeting('m1', at(9), at(10), title: 'All hands', attendees: 40);
    final small = await h.meeting('m2', at(11), at(12), title: '1:1', attendees: 2);
    final commit = await h.commit('a1', at(13));
    await h.rule('r', {'minAttendees': 10}, CurationAction.setImportance, value: 0.1);
    await h.rule('r2', {'maxAttendees': 2}, CurationAction.setImportance, value: 0.8);
    await scorer.scoreDay(day);
    expect((await h.evidence(big)).importance, closeTo(0.1, 1e-9));
    expect((await h.evidence(small)).importance, closeTo(0.8, 1e-9));
    expect((await h.evidence(commit)).importanceSetBy, ImportanceSetBy.model, reason: 'no attendee count → no match');
  });

  test('sourceKind matcher', () async {
    final m = await h.meeting('m1', at(9), at(10));
    final c = await h.commit('a1', at(13));
    await h.rule('r', {'sourceKind': 'googleCalendar'}, CurationAction.setImportance, value: 0.3);
    await scorer.scoreDay(day);
    expect((await h.evidence(m)).importanceSetBy, ImportanceSetBy.rule);
    expect((await h.evidence(c)).importanceSetBy, ImportanceSetBy.model);
  });

  test('model batches are at most 50 items and cover every unscored item once', () async {
    final ids = <String>[];
    for (var i = 0; i < 120; i++) {
      ids.add(await h.commit('c$i', at(8, i), msg: 'commit $i'));
    }
    await scorer.scoreDay(day);
    final sizes = [
      for (final c in h.router.of('importance')) FakeRouter.jsonItems(c.user, 'Rate these evidence items:\n').length,
    ];
    expect(sizes, [50, 50, 20]);
    expect(scoredIds().toSet(), ids.toSet());
    expect(scoredIds().length, 120);
  });

  test('model never sees user- or rule-set items', () async {
    final u = await h.commit('a1', at(9), msg: 'user one');
    final r = await h.commit('a2', at(10), msg: 'Standup');
    final m = await h.commit('a3', at(11), msg: 'model one');
    await userSet(u, starred: true);
    await h.rule('r', {'titlePattern': 'standup'}, CurationAction.setImportance, value: 0.1);
    await scorer.scoreDay(day);
    expect(scoredIds(), [m]);
    expect(r, isNotEmpty);
  });

  test('only unscored or changed evidence is re-scored', () async {
    final a = await h.commit('a1', at(9), msg: 'one');
    await h.commit('a2', at(10), msg: 'two');
    await scorer.scoreDay(day);
    expect(h.router.calls, hasLength(1));
    await scorer.scoreDay(day);
    expect(h.router.calls, hasLength(1), reason: 'nothing changed');
    await h.commit('a1', at(9), msg: 'one', extra: {'stats': 'amended'});
    await scorer.scoreDay(day);
    expect(h.router.calls, hasLength(2));
    expect(
      FakeRouter.jsonItems(h.router.calls.last.user, 'Rate these evidence items:\n').map((i) => i['evidence_id']),
      [a],
    );
  });

  test('disabling a rule hands the item back to the model (and un-hides it)', () async {
    final e = await h.meeting('m1', at(12), at(13), title: 'Lunch');
    await h.rule('r', {'titlePattern': 'lunch'}, CurationAction.hide);
    await scorer.scoreDay(day);
    expect((await h.evidence(e)).hidden, isTrue);
    await (h.db.update(
      h.db.curationRules,
    )..where((r) => r.id.equals('r'))).write(const CurationRulesCompanion(enabled: Value(false)));
    await scorer.scoreDay(day);
    final ev = await h.evidence(e);
    expect((ev.hidden, ev.importanceSetBy, ev.importance), (false, ImportanceSetBy.model, 0.7));
    expect(scoredIds(), [e]);
  });

  test('a model score never overwrites a user star made while the model was thinking', () async {
    final e = await h.commit('a1', at(9));
    h.router.onCall = (_) => userSet(e, starred: true);
    await scorer.scoreDay(day);
    final ev = await h.evidence(e);
    expect((ev.importance, ev.importanceSetBy), (1.0, ImportanceSetBy.user));
  });

  test('a starred item whose payload changes stays user-set and is not re-scored', () async {
    final e = await h.commit('a1', at(9));
    await scorer.scoreDay(day);
    await userSet(e, starred: true);
    await h.commit('a1', at(9), extra: {'x': 1});
    await scorer.scoreDay(day);
    expect((await h.evidence(e)).importance, 1.0);
    expect(h.router.calls, hasLength(1));
  });

  test('model scores for unknown ids or out of range are ignored / clamped', () async {
    final e = await h.commit('a1', at(9));
    h.router.responders['importance'] = (c) => {
      'scores': [
        {'evidence_id': 'nope', 'score': 0.9, 'reason': 'x'},
        {'evidence_id': e, 'score': 1.7, 'reason': 'x'},
      ],
    };
    await scorer.scoreDay(day);
    expect((await h.evidence(e)).importance, 1.0);
  });
}
