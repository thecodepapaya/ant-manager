import 'dart:convert';

import 'package:core/core.dart';
import 'package:core/src/jobs/scheduler.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:test/test.dart';

import '../tools/fixtures.dart';

void main() {
  group('latestDue', () {
    const daily18 = ScheduleRule(hour: 18, weekdays: [1, 2, 3, 4, 5]);

    test('same day after the time, previous weekday before it', () {
      // Wed 2026-11-18.
      expect(daily18.latestDue(DateTime.utc(2026, 11, 18, 19), Duration.zero), DateTime.utc(2026, 11, 18, 18));
      expect(daily18.latestDue(DateTime.utc(2026, 11, 18, 17, 59), Duration.zero), DateTime.utc(2026, 11, 17, 18));
      expect(daily18.latestDue(DateTime.utc(2026, 11, 18, 18), Duration.zero), DateTime.utc(2026, 11, 18, 18));
      // Sunday → Friday.
      expect(daily18.latestDue(DateTime.utc(2026, 11, 22, 12), Duration.zero), DateTime.utc(2026, 11, 20, 18));
    });

    test('uses the profile offset for wall-clock time and weekday', () {
      const ist = Duration(hours: 5, minutes: 30);
      // 12:00 UTC = 17:30 IST Wed → latest is Tue 18:00 IST = Tue 12:30 UTC.
      expect(daily18.latestDue(DateTime.utc(2026, 11, 18, 12), ist), DateTime.utc(2026, 11, 17, 12, 30));
      expect(daily18.latestDue(DateTime.utc(2026, 11, 18, 13), ist), DateTime.utc(2026, 11, 18, 12, 30));
      const pst = Duration(hours: -8);
      // Sat 01:00 UTC = Fri 17:00 PST → Thu 18:00 PST = Fri 02:00 UTC.
      expect(daily18.latestDue(DateTime.utc(2026, 11, 21, 1), pst), DateTime.utc(2026, 11, 20, 2));
      // Sat 03:00 UTC = Fri 19:00 PST → Fri 18:00 PST = Sat 02:00 UTC.
      expect(daily18.latestDue(DateTime.utc(2026, 11, 21, 3), pst), DateTime.utc(2026, 11, 21, 2));
    });

    test('weekly, monthly, quarterly rules', () {
      final weekly = defaultSchedules[Scheduler.weeklyReport]!;
      expect(weekly.latestDue(DateTime.utc(2026, 11, 18), Duration.zero), DateTime.utc(2026, 11, 16, 9));
      final monthly = defaultSchedules[Scheduler.monthlyReport]!;
      expect(monthly.latestDue(DateTime.utc(2026, 11, 1, 8), Duration.zero), DateTime.utc(2026, 10, 1, 9));
      final q = defaultSchedules[Scheduler.quarterlyReport]!;
      expect(q.latestDue(DateTime.utc(2026, 11, 18), Duration.zero), DateTime.utc(2026, 10, 1, 9));
      expect(q.latestDue(DateTime.utc(2026, 3, 31), Duration.zero), DateTime.utc(2026, 1, 1, 9));
      expect(ScheduleRule.fromJson(jsonDecode(jsonEncode(q.toJson())) as Map<String, Object?>).quarterly, isTrue);
    });
  });

  group('Scheduler.tick', () {
    late ProfileDb db;
    late JobQueue jobs;
    late FixedClock clock;
    late Scheduler s;
    const offset = Duration(hours: 5, minutes: 30);

    setUp(() async {
      db = ProfileDb(NativeDatabase.memory());
      clock = FixedClock(DateTime.utc(2026, 11, 18, 0)); // Wed 05:30 IST
      jobs = JobQueue(db, clock: clock);
      for (final k in defaultSchedules.keys) {
        jobs.register(k, JobLane.io, (_) async {});
      }
      s = Scheduler(db, jobs, utcOffset: (_) => offset, clock: clock);
      await s.seedDefaults();
    });
    tearDown(() => db.close());

    Future<List<String>> kinds(List<String> ids) async => [
      for (final id in ids) (await (db.select(db.jobs)..where((j) => j.id.equals(id))).getSingle()).kind,
    ];

    test('seeding does not fire immediately and is idempotent', () async {
      await s.seedDefaults();
      expect(await db.select(db.schedules).get(), hasLength(5));
      expect(await s.tick(), isEmpty);
    });

    test('catches up once after a long gap, then waits for the next due time', () async {
      // Closed for ~2 weeks; reopen Wed 2026-12-02 12:00 UTC (17:30 IST).
      final ids = await s.tick(DateTime.utc(2026, 12, 2, 12));
      expect(
        await kinds(ids),
        unorderedEquals([Scheduler.dailyReport, Scheduler.weeklyReport, Scheduler.monthlyReport, Scheduler.backup]),
      );
      final daily = await (db.select(db.jobs)..where((j) => j.kind.equals(Scheduler.dailyReport))).getSingle();
      // Latest weekday 18:00 IST before Wed 17:30 IST = Tue 12:30 UTC.
      expect(jsonDecode(daily.args)['due'], DateTime.utc(2026, 12, 1, 12, 30).toIso8601String());

      expect(await s.tick(DateTime.utc(2026, 12, 2, 12, 20)), isEmpty);
      expect(await kinds(await s.tick(DateTime.utc(2026, 12, 2, 12, 31))), [Scheduler.dailyReport]);
    });

    test('disabled schedules are skipped', () async {
      await db.update(db.schedules).write(const SchedulesCompanion(enabled: Value(false)));
      expect(await s.tick(DateTime.utc(2027, 1, 1)), isEmpty);
    });
  });
}
