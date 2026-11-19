import 'dart:convert';

import 'package:core/core.dart';
import 'package:core/src/narrative/time_allocation.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
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

  /// (project, basis) → minutes for the live time facts of [d].
  Future<Map<(String?, String), int>> minutes([String d = day]) async => {
    for (final f in await h.timeFacts())
      if (f.periodStart == d)
        (f.projectId, (jsonDecode(f.details) as Map)['basis'] as String):
            (jsonDecode(f.details) as Map)['minutes'] as int,
  };

  test('overlapping meetings are merged: 10–11 + 10:30–11:30 + 14–14:15 = 105 min', () async {
    final ids = [
      await h.meeting('m1', at(10), at(11)),
      await h.meeting('m2', at(10, 30), at(11, 30)),
      await h.meeting('m3', at(14), at(14, 15)),
    ];
    await time.computeDay(day);
    expect(await minutes(), {(null, 'measured'): 105});
    final f = (await h.timeFacts()).single;
    expect(f.statement, '1 h 45 min in meetings with no project');
    expect(f.origin, FactOrigin.inferred);
    expect((await h.citations(f.id)).map((c) => c.payloadId).toSet(), {for (final e in ids) await h.pid(e)});
    expect(h.router.calls, isEmpty, reason: 'deterministic: no model');
  });

  test('declined, hidden and all-day events are excluded', () async {
    await h.meeting('m1', at(10), at(11));
    await h.meeting('d1', at(12), at(13), extra: {'responseStatus': 'declined'});
    await h.meeting('d2', at(13), at(14), extra: {'declined': true});
    final hidden = await h.meeting('h1', at(15), at(16));
    await h.setHidden(hidden, true);
    await h.meeting('a1', at(0), at(24), allDay: true);
    await time.computeDay(day);
    expect(await minutes(), {(null, 'measured'): 60});
    final cites = (await h.citations((await h.timeFacts()).single.id)).length;
    expect(cites, 1);
  });

  test('a meeting crossing midnight counts once, on its own day (23:30–00:30 = 60)', () async {
    await h.meeting('m1', at(23, 30), at(24, 30));
    await time.computeDay(day);
    await time.computeDay('2026-11-18');
    expect(await minutes(), {(null, 'measured'): 60});
    expect(await minutes('2026-11-18'), isEmpty);
  });

  test('single commit → 30 min estimated', () async {
    await h.commit('a1', at(15));
    await time.computeDay(day);
    expect(await minutes(), {(null, 'estimated'): 30});
    expect((await h.timeFacts()).single.statement, '~30 min of coding with no project (estimated from commits)');
  });

  test('commit sessions: 10:00, 10:40, 13:00 → (9:30–10:40) + (12:30–13:00) = 100 min', () async {
    await h.commit('a1', at(10));
    await h.commit('a2', at(10, 40));
    await h.commit('a3', at(13));
    await time.computeDay(day);
    expect(await minutes(), {(null, 'estimated'): 100});
  });

  test('a gap of exactly 90 min splits a session; 89 min does not', () async {
    await h.commit('a1', at(10));
    await h.commit('a2', at(11, 30));
    await time.computeDay(day);
    expect(await minutes(), {(null, 'estimated'): 60});
    await h.commit('a3', at(12, 59)); // 89 min after 11:30 → 11:00–12:59 = 119, + 9:30–10:00 = 30
    await time.computeDay(day);
    expect(await minutes(), {(null, 'estimated'): 149});
  });

  test('estimated time excludes meeting overlap: sessions 100 − 40 overlap = 60', () async {
    // Sessions 9:30–10:40 and 12:30–13:00; meeting 10:00–11:00 cuts 10:00–10:40.
    await h.commit('a1', at(10));
    await h.commit('a2', at(10, 40));
    await h.commit('a3', at(13));
    await h.meeting('m1', at(10), at(11));
    await time.computeDay(day);
    expect(await minutes(), {(null, 'measured'): 60, (null, 'estimated'): 60});
  });

  test('a meeting inside a session splits it: 9:30–12:00 minus 10:30–11:00 = 120', () async {
    await h.commit('a1', at(10));
    await h.commit('a2', at(11));
    await h.commit('a3', at(12));
    await h.meeting('m1', at(10, 30), at(11));
    await time.computeDay(day);
    expect(await minutes(), {(null, 'measured'): 30, (null, 'estimated'): 120});
  });

  test('commits either side of midnight: each day gets its own 30-min session', () async {
    await h.commit('a1', at(23, 50));
    await h.commit('a2', at(24, 20)); // 00:20 next day
    await time.computeDay(day);
    await time.computeDay('2026-11-18');
    expect(await minutes(), {(null, 'estimated'): 30});
    expect(await minutes('2026-11-18'), {(null, 'estimated'): 30});
  });

  test('per project: measured and estimated facts per project', () async {
    final m1 = await h.meeting('m1', at(9), at(10));
    final m2 = await h.meeting('m2', at(11), at(11, 30));
    final c1 = await h.commit('a1', at(15));
    final c2 = await h.commit(
      'a2',
      at(9, 20),
    ); // overlaps the 'pay' meeting 9:00–10:00 → session 8:50–9:20 − 9:00.. = 10
    await h.setProject(m1, 'pay');
    await h.setProject(m2, 'web');
    await h.setProject(c1, 'pay');
    await h.setProject(c2, 'web');
    await time.computeDay(day);
    expect(await minutes(), {
      ('pay', 'measured'): 60,
      ('web', 'measured'): 30,
      ('pay', 'estimated'): 30,
      ('web', 'estimated'): 10,
    });
    final pay = (await h.timeFacts()).firstWhere((f) => f.projectId == 'pay' && f.statement.contains('meetings'));
    expect(pay.statement, '1 h in meetings on Payments');
  });

  test('profile time zone decides the day', () async {
    final tz = H(offset: const Duration(hours: 2));
    await tz.setUp();
    addTearDown(tz.close);
    // 23:00Z on the 16th is 01:00 local on the 17th.
    await tz.meeting('m1', at(23, 0, '2026-11-16'), at(24, 0, '2026-11-16'));
    expect((await tz.db.select(tz.db.evidences).getSingle()).day, day);
    await TimeAllocator(tz.ctx).computeDay(day);
    expect((await tz.timeFacts()).single.details, contains('"minutes":60'));
  });

  test('idempotent: re-running writes nothing new', () async {
    await h.meeting('m1', at(10), at(11));
    await h.commit('a1', at(15));
    await time.computeDay(day);
    final before = await h.timeFacts();
    final hist = (await h.db.select(h.db.factRevisions).get()).length;
    await h.clearQueue();
    await time.computeDay(day);
    await time.computeDay(day);
    final after = await h.timeFacts();
    expect(after.map((f) => (f.id, f.revision, f.details)), before.map((f) => (f.id, f.revision, f.details)));
    expect((await h.db.select(h.db.factRevisions).get()).length, hist);
    expect(await h.db.select(h.db.recomputeQueue).get(), isEmpty);
  });

  test('a change updates the same fact (revision 2, new statement)', () async {
    await h.meeting('m1', at(10), at(11));
    await time.computeDay(day);
    final id = (await h.timeFacts()).single.id;
    await h.meeting('m2', at(13), at(13, 30));
    await time.computeDay(day);
    final f = (await h.timeFacts()).single;
    expect((f.id, f.revision), (id, 2));
    expect(f.statement, '1 h 30 min in meetings with no project');
    expect(await minutes(), {(null, 'measured'): 90});
    expect(await h.citations(id), hasLength(2));
    expect(await h.history(id), hasLength(2));
  });

  test('a rescheduled meeting (payload change, same minutes) re-pins without a revision bump', () async {
    await h.meeting('m1', at(10), at(11));
    await time.computeDay(day);
    await h.meeting('m1', at(12), at(13));
    await time.computeDay(day);
    final f = (await h.timeFacts()).single;
    expect(f.revision, 1);
    expect((await h.citations(f.id)).single.payloadRevision, 2);
    expect(await h.ctx.isStale(EntityType.fact, f.id), isFalse);
  });

  test('no time any more → the fact is retired', () async {
    final m = await h.meeting('m1', at(10), at(11));
    await time.computeDay(day);
    await h.setHidden(m, true);
    await time.computeDay(day);
    expect(await h.timeFacts(), isEmpty);
    expect((await h.timeFacts(live: false)).single.retired, isTrue);
  });

  test('a user-touched time fact gets a proposal instead of the change', () async {
    await h.meeting('m1', at(10), at(11));
    await time.computeDay(day);
    final id = (await h.timeFacts()).single.id;
    await (h.db.update(
      h.db.facts,
    )..where((f) => f.id.equals(id))).write(const FactsCompanion(origin: Value(FactOrigin.confirmed)));
    await h.meeting('m2', at(13), at(13, 30));
    await time.computeDay(day);
    final f = await h.fact(id);
    expect((f.revision, f.reviewState), (1, ReviewState.needsReview));
    expect((jsonDecode(f.details) as Map)['minutes'], 60);
    final proposal = jsonDecode(f.reviewProposal!) as Map;
    expect((proposal['details'] as Map)['minutes'], 90);
    expect((await h.timeFacts()).length, 1, reason: 'no duplicate fact created next to the protected one');
  });

  test('meetings without an end time are ignored', () async {
    await h.ingest(
      H.cal,
      PayloadObservation(
        externalId: 'open',
        kind: PayloadKind.calendarEvent,
        content: {'title': 'x', 'start': at(10).toIso8601String()},
        occurredStart: at(10),
        title: 'x',
      ),
    );
    await time.computeDay(day);
    expect(await h.timeFacts(), isEmpty);
  });

  group('pure helpers', () {
    test('merge and subtract', () {
      final a = TimeAllocator.merge([
        (start: at(10), end: at(11)),
        (start: at(11), end: at(12)),
        (start: at(14), end: at(15)),
      ]);
      expect(TimeAllocator.totalMinutes(a), 180);
      expect(a, hasLength(2));
      final s = TimeAllocator.subtract(a, [(start: at(9), end: at(10, 30)), (start: at(14, 15), end: at(14, 45))]);
      expect(TimeAllocator.totalMinutes(s), 90 + 30);
    });
  });
}
