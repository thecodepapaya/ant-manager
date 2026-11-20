// Independent tests (#99) for #117: each occurrence uses the zone offset valid on its own day, so
// catch-up across a DST change still lands on local wall-clock time.
//
// 2026 transitions used below:
//   Europe/London    spring forward Sun 2026-03-29 01:00Z (GMT→BST), fall back Sun 2026-10-25 01:00Z.
//   America/New_York spring forward Sun 2026-03-08 07:00Z (EST→EDT), fall back Sun 2026-11-01 06:00Z.
import 'dart:convert';

import 'package:core/core.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:test/test.dart';

import 'fakes.dart';

void main() {
  final london = zoneOffset('Europe/London');
  final newYork = zoneOffset('America/New_York');
  const weekdays18 = ScheduleRule(hour: 18, weekdays: [1, 2, 3, 4, 5]);
  const daily18 = ScheduleRule(hour: 18);

  test('zone fixtures have the expected offsets either side of the 2026 transitions', () {
    expect(london(DateTime.utc(2026, 3, 27, 18)), Duration.zero);
    expect(london(DateTime.utc(2026, 3, 30, 8)), const Duration(hours: 1));
    expect(london(DateTime.utc(2026, 10, 23, 17)), const Duration(hours: 1));
    expect(london(DateTime.utc(2026, 10, 26, 8)), Duration.zero);
    expect(newYork(DateTime.utc(2026, 3, 6, 23)), const Duration(hours: -5));
    expect(newYork(DateTime.utc(2026, 3, 9, 12)), const Duration(hours: -4));
    expect(newYork(DateTime.utc(2026, 10, 30, 22)), const Duration(hours: -4));
    expect(newYork(DateTime.utc(2026, 11, 2, 12)), const Duration(hours: -5));
  });

  group('latestDue across DST (London)', () {
    test('spring forward: Monday catch-up lands on Friday 18:00 GMT, not 17:00Z', () {
      // Mon 2026-03-30 09:00 BST.
      expect(weekdays18.latestDue(DateTime.utc(2026, 3, 30, 8), london), DateTime.utc(2026, 3, 27, 18));
    });

    test('spring forward: Monday after 18:00 BST is that day at 17:00Z', () {
      expect(weekdays18.latestDue(DateTime.utc(2026, 3, 30, 17), london), DateTime.utc(2026, 3, 30, 17));
      expect(weekdays18.latestDue(DateTime.utc(2026, 3, 30, 16, 59), london), DateTime.utc(2026, 3, 27, 18));
    });

    test('fall back: Monday catch-up lands on Friday 18:00 BST = 17:00Z', () {
      // Mon 2026-10-26 08:00 GMT.
      expect(weekdays18.latestDue(DateTime.utc(2026, 10, 26, 8), london), DateTime.utc(2026, 10, 23, 17));
      expect(weekdays18.latestDue(DateTime.utc(2026, 10, 26, 18), london), DateTime.utc(2026, 10, 26, 18));
    });

    test('on the spring-forward day itself: before vs after 18:00 BST', () {
      // Sun 2026-03-29 is BST from 01:00Z; 18:00 BST = 17:00Z. Saturday was GMT: 18:00Z.
      expect(daily18.latestDue(DateTime.utc(2026, 3, 29, 16, 59), london), DateTime.utc(2026, 3, 28, 18));
      expect(daily18.latestDue(DateTime.utc(2026, 3, 29, 17), london), DateTime.utc(2026, 3, 29, 17));
      expect(daily18.latestDue(DateTime.utc(2026, 3, 29, 17, 30), london), DateTime.utc(2026, 3, 29, 17));
    });

    test('on the fall-back day itself: before vs after 18:00 GMT', () {
      // Sun 2026-10-25 is GMT from 01:00Z; 18:00 GMT = 18:00Z. Saturday was BST: 17:00Z.
      expect(daily18.latestDue(DateTime.utc(2026, 10, 25, 17, 59), london), DateTime.utc(2026, 10, 24, 17));
      expect(daily18.latestDue(DateTime.utc(2026, 10, 25, 18), london), DateTime.utc(2026, 10, 25, 18));
    });
  });

  group('latestDue across DST (New York)', () {
    test('fall back: Mon 2026-11-02 catch-up lands on Fri 18:00 EDT = 22:00Z', () {
      // Mon 07:00 EST.
      expect(weekdays18.latestDue(DateTime.utc(2026, 11, 2, 12), newYork), DateTime.utc(2026, 10, 30, 22));
      // Mon 18:00 EST = 23:00Z.
      expect(weekdays18.latestDue(DateTime.utc(2026, 11, 2, 23), newYork), DateTime.utc(2026, 11, 2, 23));
      expect(weekdays18.latestDue(DateTime.utc(2026, 11, 2, 22, 59), newYork), DateTime.utc(2026, 10, 30, 22));
    });

    test('spring forward: Mon 2026-03-09 catch-up lands on Fri 18:00 EST = 23:00Z', () {
      // Mon 08:00 EDT.
      expect(weekdays18.latestDue(DateTime.utc(2026, 3, 9, 12), newYork), DateTime.utc(2026, 3, 6, 23));
      // Mon 18:00 EDT = 22:00Z.
      expect(weekdays18.latestDue(DateTime.utc(2026, 3, 9, 22), newYork), DateTime.utc(2026, 3, 9, 22));
    });

    test('on the transition days: before vs after 18:00 local', () {
      // Sun 2026-03-08 (EDT from 07:00Z): 18:00 EDT = 22:00Z; Sat 18:00 EST = 23:00Z.
      expect(daily18.latestDue(DateTime.utc(2026, 3, 8, 21, 59), newYork), DateTime.utc(2026, 3, 7, 23));
      expect(daily18.latestDue(DateTime.utc(2026, 3, 8, 22), newYork), DateTime.utc(2026, 3, 8, 22));
      // Sun 2026-11-01 (EST from 06:00Z): 18:00 EST = 23:00Z; Sat 18:00 EDT = 22:00Z.
      expect(daily18.latestDue(DateTime.utc(2026, 11, 1, 22, 59), newYork), DateTime.utc(2026, 10, 31, 22));
      expect(daily18.latestDue(DateTime.utc(2026, 11, 1, 23), newYork), DateTime.utc(2026, 11, 1, 23));
    });

    test('backup 02:00 on the spring-forward day (02:00 does not exist) fires at 06:00Z = 01:00 EST', () {
      // Pinned behaviour, accepted under #67 (no special handling of skipped wall times):
      // wall 02:00 → offsetAt(02:00Z) = EST → 07:00Z → offsetAt(07:00Z) = EDT → at = 02:00 + 4h = 06:00Z.
      const backup = ScheduleRule(hour: 2);
      expect(backup.latestDue(DateTime.utc(2026, 3, 8, 12), newYork), DateTime.utc(2026, 3, 8, 6));
      // The day after is ordinary 02:00 EDT = 06:00Z; the day before 02:00 EST = 07:00Z.
      expect(backup.latestDue(DateTime.utc(2026, 3, 9, 12), newYork), DateTime.utc(2026, 3, 9, 6));
      expect(backup.latestDue(DateTime.utc(2026, 3, 7, 12), newYork), DateTime.utc(2026, 3, 7, 7));
    });

    test('01:30 on the fall-back day (happens twice) resolves to the first, EDT occurrence', () {
      // Pinned behaviour, accepted under #67: 01:30 EDT = 05:30Z (the EST repeat would be 06:30Z).
      const r = ScheduleRule(hour: 1, minute: 30);
      expect(r.latestDue(DateTime.utc(2026, 11, 1, 12), newYork), DateTime.utc(2026, 11, 1, 5, 30));
    });
  });

  group('fixed offsets are unchanged (regression)', () {
    test('IST +5:30 as a constant and via Asia/Kolkata', () {
      const ist = Duration(hours: 5, minutes: 30);
      for (final off in <UtcOffset>[(_) => ist, zoneOffset('Asia/Kolkata')]) {
        // Wed 2026-11-18 17:30 IST → Tue 18:00 IST.
        expect(weekdays18.latestDue(DateTime.utc(2026, 11, 18, 12), off), DateTime.utc(2026, 11, 17, 12, 30));
        expect(weekdays18.latestDue(DateTime.utc(2026, 11, 18, 12, 30), off), DateTime.utc(2026, 11, 18, 12, 30));
        // Mon 2026-03-30 across the European/US change dates: IST has none.
        expect(weekdays18.latestDue(DateTime.utc(2026, 3, 30, 8), off), DateTime.utc(2026, 3, 27, 12, 30));
      }
    });

    test('PST -8 constant: next-UTC-day due times', () {
      Duration pst(DateTime _) => const Duration(hours: -8);
      // Sat 2026-11-21 01:00Z = Fri 17:00 PST → Thu 18:00 PST = Fri 02:00Z.
      expect(weekdays18.latestDue(DateTime.utc(2026, 11, 21, 1), pst), DateTime.utc(2026, 11, 20, 2));
      expect(weekdays18.latestDue(DateTime.utc(2026, 11, 21, 2), pst), DateTime.utc(2026, 11, 21, 2));
      // Mon 2026-03-09 12:00Z (Mon 04:00 PST) → Fri 18:00 PST = Sat 02:00Z.
      expect(weekdays18.latestDue(DateTime.utc(2026, 3, 9, 12), pst), DateTime.utc(2026, 3, 7, 2));
    });
  });

  group('Scheduler.tick with zoneOffset across DST', () {
    late ProfileDb db;
    late MutableClock clock;
    late JobQueue jobs;

    setUp(() {
      db = memDb();
      clock = MutableClock(DateTime.utc(2026, 11, 2, 12));
      jobs = JobQueue(db, clock: clock);
      jobs.register(Scheduler.dailyReport, JobLane.llm, (_) async {});
    });
    tearDown(() => db.close());

    Future<void> addDaily(DateTime lastRun) => db
        .into(db.schedules)
        .insert(
          SchedulesCompanion.insert(
            id: Scheduler.dailyReport,
            kind: Scheduler.dailyReport,
            rule: jsonEncode(weekdays18.toJson()),
            lastRunAt: Value(lastRun),
          ),
        );

    Future<List<String>> dues() async => [
      for (final j in await (db.select(db.jobs)..orderBy([(j) => OrderingTerm.asc(j.createdAt)])).get())
        (jsonDecode(j.args) as Map<String, Object?>)['due'] as String,
    ];

    test('NY: Friday already ran at 18:30 EDT, so Monday morning (EST) enqueues nothing', () async {
      // With the Monday offset applied to Friday, due would be 23:00Z > lastRun and re-fire.
      await addDaily(DateTime.utc(2026, 10, 30, 22, 30));
      final s = Scheduler(db, jobs, utcOffset: newYork, clock: clock);
      expect(await s.tick(), isEmpty);
      clock.t = DateTime.utc(2026, 11, 2, 22, 59);
      expect(await s.tick(), isEmpty);
      clock.t = DateTime.utc(2026, 11, 2, 23); // Mon 18:00 EST
      expect(await s.tick(), hasLength(1));
      expect(await dues(), [DateTime.utc(2026, 11, 2, 23).toIso8601String()]);
      expect(await s.tick(), isEmpty);
    });

    test('NY: missed Friday catches up on Monday with due = Fri 22:00Z', () async {
      await addDaily(DateTime.utc(2026, 10, 29, 22, 30)); // Thursday's run
      final s = Scheduler(db, jobs, utcOffset: newYork, clock: clock);
      expect(await s.tick(), hasLength(1));
      expect(await dues(), [DateTime.utc(2026, 10, 30, 22).toIso8601String()]);
      final row = (await db.select(db.schedules).get()).single;
      expect(row.lastRunAt!.toUtc(), DateTime.utc(2026, 11, 2, 12));
      expect(await s.tick(), isEmpty);
    });

    test('London spring forward: missed Friday catches up with due = Fri 18:00Z (GMT)', () async {
      await addDaily(DateTime.utc(2026, 3, 26, 18, 30));
      clock.t = DateTime.utc(2026, 3, 30, 8);
      final s = Scheduler(db, jobs, utcOffset: london, clock: clock);
      expect(await s.tick(), hasLength(1));
      expect(await dues(), [DateTime.utc(2026, 3, 27, 18).toIso8601String()]);
      clock.t = DateTime.utc(2026, 3, 30, 17); // Mon 18:00 BST
      expect(await s.tick(), hasLength(1));
      expect((await dues()).last, DateTime.utc(2026, 3, 30, 17).toIso8601String());
    });
  });
}
