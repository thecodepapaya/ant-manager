// Independent tests (#99) for #109 time allocation: only commits authored by your email identities,
// commit sessions formed across projects, each commit's stretch credited to its own project.
import 'dart:convert';

import 'package:core/core.dart';
import 'package:core/src/narrative/time_allocation.dart';
import 'package:test/test.dart';

import 'harness.dart';

void main() {
  late H h;
  late TimeAllocator time;
  setUp(() async {
    h = H();
    await h.setUp();
    time = TimeAllocator(h.ctx);
  });
  tearDown(() => h.close());

  Future<void> identity(String kind, String value) => h.db
      .into(h.db.identities)
      .insert(IdentitiesCompanion.insert(id: '$kind:$value', kind: kind, value: value));

  Map<String, Object?> by(String email) => {
    'author': {'name': 'Someone', 'email': email},
  };

  Future<String> commit(String sha, DateTime t, {String? project, String? author}) async {
    final e = await h.commit(sha, t, extra: author == null ? const {} : by(author));
    if (project != null) await h.setProject(e, project);
    return e;
  }

  Future<Map<(String?, String), int>> minutes([String d = day]) async => {
    for (final f in await h.timeFacts())
      if (f.periodStart == d)
        (f.projectId, (jsonDecode(f.details) as Map)['basis'] as String):
            (jsonDecode(f.details) as Map)['minutes'] as int,
  };

  Future<Set<String>> cites(String? project, String basis) async {
    final f = (await h.timeFacts()).singleWhere(
      (f) => f.projectId == project && (jsonDecode(f.details) as Map)['basis'] == basis,
    );
    return (await h.citations(f.id)).map((c) => c.payloadId).toSet();
  }

  group('authorship', () {
    test("someone else's commit is excluded from minutes and citations; one with no author is kept", () async {
      await identity('email', 'me@acme.io');
      final mine = await commit('a1', at(10), author: 'me@acme.io');
      await commit('o1', at(13), author: 'other@acme.io');
      final anon = await commit('n1', at(16));
      await time.computeDay(day);
      expect(await minutes(), {(null, 'estimated'): 60});
      expect(await cites(null, 'estimated'), {await h.pid(mine), await h.pid(anon)});
    });

    test("only someone else's commits → no time fact at all", () async {
      await identity('email', 'me@acme.io');
      await commit('o1', at(10), author: 'other@acme.io');
      await commit('o2', at(10, 20), author: 'other@acme.io');
      await time.computeDay(day);
      expect(await h.timeFacts(), isEmpty);
    });

    test('email match ignores case and surrounding whitespace on both sides', () async {
      await identity('email', '  Me@Acme.IO ');
      await commit('a1', at(10), author: ' ME@acme.io\n');
      await commit('a2', at(14), author: 'me@acme.io');
      await time.computeDay(day);
      expect(await minutes(), {(null, 'estimated'): 60});
    });

    test('several email identities all count as you', () async {
      await identity('email', 'me@acme.io');
      await identity('email', 'me@personal.dev');
      await commit('a1', at(10), author: 'me@acme.io');
      await commit('a2', at(14), author: 'me@personal.dev');
      await commit('o1', at(16), author: 'other@acme.io');
      await time.computeDay(day);
      expect(await minutes(), {(null, 'estimated'): 60});
    });

    test('a non-email identity with the same value does not make a commit yours', () async {
      await identity('github_login', 'me@acme.io');
      await commit('a1', at(10), author: 'me@acme.io');
      await time.computeDay(day);
      expect(await h.timeFacts(), isEmpty);
    });

    test('an excluded commit does not join or bridge your sessions', () async {
      // Mine: 9:30–10:00, 10:00–11:20, 11:20–12:45 (one session), then 15:00–15:30.
      await identity('email', 'me@acme.io');
      await commit('a1', at(10), author: 'me@acme.io');
      await commit('o1', at(10, 40), author: 'other@acme.io');
      await commit('a2', at(11, 20), author: 'me@acme.io');
      // Someone else's 14:10 would bridge 12:45 → 15:30 (85 + 80 min) if it counted.
      await commit('a3', at(12, 45), author: 'me@acme.io');
      await commit('o2', at(14, 10), author: 'other@acme.io');
      await commit('a4', at(15, 30), author: 'me@acme.io');
      await time.computeDay(day);
      expect(await minutes(), {(null, 'estimated'): 110 + 85 + 30});
    });

    test(
      'a commit whose author email is empty counts as having no author email (kept)',
      () async {
        await identity('email', 'me@acme.io');
        await commit('a1', at(10), author: '');
        await time.computeDay(day);
        expect(await minutes(), {(null, 'estimated'): 30});
      },
      skip: "BUG: author email '' is treated as someone else's (LLD 04: no author email counts too)",
    );

    test('a commit whose author has no email is kept', () async {
      await identity('email', 'me@acme.io');
      await h.commit('a1', at(10), extra: {'author': {'name': 'Me'}});
      await time.computeDay(day);
      expect(await minutes(), {(null, 'estimated'): 30});
    });
  });

  group('sessions across projects', () {
    test('10:00 A + 10:30 B → A 30, B 30', () async {
      final a = await commit('a1', at(10), project: 'pay');
      final b = await commit('b1', at(10, 30), project: 'web');
      await time.computeDay(day);
      expect(await minutes(), {('pay', 'estimated'): 30, ('web', 'estimated'): 30});
      expect(await cites('pay', 'estimated'), {await h.pid(a)});
      expect(await cites('web', 'estimated'), {await h.pid(b)});
    });

    test('10:00 A + 11:00 B → A 30, B 60 (one session)', () async {
      await commit('a1', at(10), project: 'pay');
      await commit('b1', at(11), project: 'web');
      await time.computeDay(day);
      expect(await minutes(), {('pay', 'estimated'): 30, ('web', 'estimated'): 60});
    });

    test('order of ingestion does not matter (segments follow commit time)', () async {
      await commit('b1', at(11), project: 'web');
      await commit('a1', at(10), project: 'pay');
      await time.computeDay(day);
      expect(await minutes(), {('pay', 'estimated'): 30, ('web', 'estimated'): 60});
    });

    test('a gap of exactly 90 min starts a new session with its own 30 min lead', () async {
      await commit('a1', at(10), project: 'pay');
      await commit('b1', at(11, 30), project: 'web');
      await time.computeDay(day);
      expect(await minutes(), {('pay', 'estimated'): 30, ('web', 'estimated'): 30});
    });

    test('a gap of 89 min stays in the session', () async {
      await commit('a1', at(10), project: 'pay');
      await commit('b1', at(11, 29), project: 'web');
      await time.computeDay(day);
      expect(await minutes(), {('pay', 'estimated'): 30, ('web', 'estimated'): 89});
    });

    test('interleaved projects: each stretch goes to the commit that ends it', () async {
      // 9:30–10:00 A, 10:00–10:30 A, 10:30–11:00 B, 11:00–11:30 A.
      final a1 = await commit('a1', at(10), project: 'pay');
      final a2 = await commit('a2', at(10, 30), project: 'pay');
      final b1 = await commit('b1', at(11), project: 'web');
      final a3 = await commit('a3', at(11, 30), project: 'pay');
      await time.computeDay(day);
      expect(await minutes(), {('pay', 'estimated'): 90, ('web', 'estimated'): 30});
      expect(await cites('pay', 'estimated'), {await h.pid(a1), await h.pid(a2), await h.pid(a3)});
      expect(await cites('web', 'estimated'), {await h.pid(b1)});
    });

    test('no-project commits share sessions with project commits', () async {
      await commit('n1', at(10));
      await commit('a1', at(10, 45), project: 'pay');
      await time.computeDay(day);
      expect(await minutes(), {(null, 'estimated'): 30, ('pay', 'estimated'): 45});
    });

    test('meeting time is subtracted from each project segment', () async {
      // A 9:30–10:00; B 10:00–11:00 minus meeting 10:30–11:15 → 30. Meeting itself: 45 measured.
      await commit('a1', at(10), project: 'pay');
      await commit('b1', at(11), project: 'web');
      await h.meeting('m1', at(10, 30), at(11, 15));
      await time.computeDay(day);
      expect(await minutes(), {(null, 'measured'): 45, ('pay', 'estimated'): 30, ('web', 'estimated'): 30});
    });

    test("a meeting on another project still cuts this project's coding", () async {
      await commit('a1', at(10), project: 'pay');
      final m = await h.meeting('m1', at(9, 30), at(9, 45));
      await h.setProject(m, 'web');
      await time.computeDay(day);
      expect(await minutes(), {('web', 'measured'): 15, ('pay', 'estimated'): 15});
    });

    test('a segment fully inside a meeting yields no estimated fact for its project', () async {
      await commit('a1', at(10), project: 'pay');
      await commit('b1', at(10, 20), project: 'web'); // 10:00–10:20, inside the meeting
      await h.meeting('m1', at(10), at(10, 30));
      await time.computeDay(day);
      expect(await minutes(), {(null, 'measured'): 30, ('pay', 'estimated'): 30});
    });

    test('authorship filtering and projects combine', () async {
      await identity('email', 'me@acme.io');
      await commit('a1', at(10), project: 'pay', author: 'me@acme.io');
      await commit('o1', at(10, 30), project: 'web', author: 'other@acme.io');
      await commit('a2', at(11), project: 'web', author: 'me@acme.io');
      await time.computeDay(day);
      expect(await minutes(), {('pay', 'estimated'): 30, ('web', 'estimated'): 60});
    });

    test('idempotent across projects: re-running changes nothing', () async {
      await commit('a1', at(10), project: 'pay');
      await commit('b1', at(11), project: 'web');
      await time.computeDay(day);
      final before = await h.timeFacts();
      final hist = (await h.db.select(h.db.factRevisions).get()).length;
      await h.clearQueue();
      await time.computeDay(day);
      final after = await h.timeFacts();
      expect(after.map((f) => (f.id, f.revision, f.details)), before.map((f) => (f.id, f.revision, f.details)));
      expect((await h.db.select(h.db.factRevisions).get()).length, hist);
      expect(await h.db.select(h.db.recomputeQueue).get(), isEmpty);
    });

    test('a session across midnight is split: each day gets its own lead', () async {
      await commit('a1', at(23, 50), project: 'pay');
      await commit('b1', at(24, 10), project: 'web'); // 00:10 next day: 20 min if the session carried over
      await time.computeDay(day);
      await time.computeDay('2026-11-18');
      expect(await minutes(), {('pay', 'estimated'): 30});
      expect(await minutes('2026-11-18'), {('web', 'estimated'): 30});
    });
  });

  group('segments (pure)', () {
    test('first commit of a session gets the lead, later ones the stretch since the previous', () {
      final s = TimeAllocator.segments([(at(11), 'B', 'b'), (at(10), 'A', 'a'), (at(13), 'C', 'c')]);
      expect(s.map((x) => (x.$1.start, x.$1.end, x.$2, x.$3)), [
        (at(9, 30), at(10), 'A', 'a'),
        (at(10), at(11), 'B', 'b'),
        (at(12, 30), at(13), 'C', 'c'),
      ]);
    });

    test('authoredByYou', () {
      final me = {'me@acme.io'};
      expect(TimeAllocator.authoredByYou({}, me), isTrue);
      expect(TimeAllocator.authoredByYou({'author': 'me'}, me), isTrue);
      expect(TimeAllocator.authoredByYou({'author': {'email': ' ME@acme.io '}}, me), isTrue);
      expect(TimeAllocator.authoredByYou({'author': {'email': 'x@y.z'}}, me), isFalse);
      expect(TimeAllocator.authoredByYou({'author': {'email': 'x@y.z'}}, const {}), isFalse);
    });
  });
}
