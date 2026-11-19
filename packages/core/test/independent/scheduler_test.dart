// Independent tests (#99) for the scheduler: catch up once (#79), first run, rule matching, time zones.
import 'dart:convert';

import 'package:core/core.dart';
import 'package:core/src/jobs/scheduler.dart' show defaultSchedules;
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:test/test.dart';

import 'fakes.dart';

void main() {
  late ProfileDb db;
  late MutableClock clock;
  late JobQueue jobs;

  Scheduler scheduler({Duration offset = Duration.zero}) => Scheduler(db, jobs, utcOffset: (_) => offset, clock: clock);

  setUp(() {
    db = memDb();
    clock = MutableClock(DateTime.utc(2026, 11, 16, 12)); // Monday
    jobs = JobQueue(db, clock: clock);
    for (final k in [
      Scheduler.dailyReport,
      Scheduler.weeklyReport,
      Scheduler.monthlyReport,
      Scheduler.quarterlyReport,
      Scheduler.backup,
      'custom',
    ]) {
      jobs.register(k, k == Scheduler.backup ? JobLane.io : JobLane.llm, (_) async {});
    }
  });
  tearDown(() => db.close());

  Future<void> addSchedule(String id, ScheduleRule rule, {DateTime? lastRun, bool enabled = true, String? kind}) => db
      .into(db.schedules)
      .insert(
        SchedulesCompanion.insert(
          id: id,
          kind: kind ?? id,
          rule: jsonEncode(rule.toJson()),
          lastRunAt: Value(lastRun),
          enabled: Value(enabled),
        ),
      );

  Future<List<Map<String, Object?>>> jobArgs() async => [
    for (final j in await (db.select(db.jobs)..orderBy([(j) => OrderingTerm.asc(j.createdAt)])).get())
      {'kind': j.kind, ...jsonDecode(j.args) as Map<String, Object?>},
  ];

  group('ScheduleRule.latestDue', () {
    DateTime? due(ScheduleRule r, DateTime now, [Duration off = Duration.zero]) => r.latestDue(now, off);

    test('daily weekdays 18:00: weekends fall back to Friday; exact boundary counts', () {
      const r = ScheduleRule(hour: 18, weekdays: [1, 2, 3, 4, 5]);
      expect(due(r, DateTime.utc(2026, 11, 21, 12)), DateTime.utc(2026, 11, 20, 18)); // Saturday
      expect(due(r, DateTime.utc(2026, 11, 23, 17, 59)), DateTime.utc(2026, 11, 20, 18)); // Monday before 18:00
      expect(due(r, DateTime.utc(2026, 11, 23, 18)), DateTime.utc(2026, 11, 23, 18)); // exactly at
    });

    test('monthly on the 31st skips short months', () {
      const r = ScheduleRule(hour: 9, monthDay: 31);
      expect(due(r, DateTime.utc(2026, 3, 15)), DateTime.utc(2026, 1, 31, 9));
      expect(due(r, DateTime.utc(2026, 5, 1)), DateTime.utc(2026, 3, 31, 9));
    });

    test('monthly on the 29th: leap and non-leap February', () {
      const r = ScheduleRule(hour: 9, monthDay: 29);
      expect(due(r, DateTime.utc(2024, 3, 1)), DateTime.utc(2024, 2, 29, 9));
      expect(due(r, DateTime.utc(2026, 3, 1)), DateTime.utc(2026, 1, 29, 9));
    });

    test('quarterly: first day of Jan/Apr/Jul/Oct at 09:00', () {
      const r = ScheduleRule(hour: 9, quarterly: true);
      expect(due(r, DateTime.utc(2027, 1, 1, 8, 59)), DateTime.utc(2026, 10, 1, 9));
      expect(due(r, DateTime.utc(2027, 1, 1, 9)), DateTime.utc(2027, 1, 1, 9));
      expect(due(r, DateTime.utc(2026, 6, 30, 23)), DateTime.utc(2026, 4, 1, 9));
    });

    test('local wall clock: due times shift with the profile offset', () {
      const r = ScheduleRule(hour: 18);
      // 18:00 at UTC+5:30 = 12:30 UTC.
      expect(
        due(r, DateTime.utc(2026, 11, 18, 13), const Duration(hours: 5, minutes: 30)),
        DateTime.utc(2026, 11, 18, 12, 30),
      );
      // 18:00 at UTC-8 = 02:00 UTC next day; at 01:00 UTC on the 19th the latest is the 17th local.
      expect(due(r, DateTime.utc(2026, 11, 19, 1), const Duration(hours: -8)), DateTime.utc(2026, 11, 18, 2));
      // Backup 02:00 at UTC+10 = 16:00 UTC the day before.
      expect(
        due(const ScheduleRule(hour: 2), DateTime.utc(2026, 11, 18, 17), const Duration(hours: 10)),
        DateTime.utc(2026, 11, 18, 16),
      );
    });

    test('JSON round-trip', () {
      const r = ScheduleRule(hour: 7, minute: 15, weekdays: [2, 4], monthDay: 3, quarterly: true);
      final back = ScheduleRule.fromJson(jsonDecode(jsonEncode(r.toJson())) as Map<String, Object?>);
      expect(back.toJson(), r.toJson());
    });
  });

  group('tick (#79 catch up once)', () {
    test('seeded defaults do not catch up runs from before the profile existed', () async {
      final s = scheduler();
      await s.seedDefaults();
      expect(await s.tick(), isEmpty);
      // Re-seeding keeps lastRunAt (does not reset to a later now).
      final before = await db.select(db.schedules).get();
      clock.advance(const Duration(days: 3));
      await s.seedDefaults();
      final after = await db.select(db.schedules).get();
      expect(after.map((x) => x.lastRunAt), before.map((x) => x.lastRunAt));
      expect(after.map((x) => x.id), unorderedEquals(defaultSchedules.keys));
    });

    test('first run (never ran) enqueues the latest due occurrence once', () async {
      await addSchedule('custom', const ScheduleRule(hour: 9));
      final s = scheduler();
      expect(await s.tick(), hasLength(1));
      expect(await s.tick(), isEmpty);
      expect((await jobArgs()).single['due'], DateTime.utc(2026, 11, 16, 9).toIso8601String());
    });

    test('many missed occurrences of several schedules: exactly one job each, for the latest', () async {
      final lastRun = DateTime.utc(2026, 10, 1, 12);
      await addSchedule(Scheduler.dailyReport, defaultSchedules[Scheduler.dailyReport]!, lastRun: lastRun);
      await addSchedule(Scheduler.weeklyReport, defaultSchedules[Scheduler.weeklyReport]!, lastRun: lastRun);
      await addSchedule(Scheduler.monthlyReport, defaultSchedules[Scheduler.monthlyReport]!, lastRun: lastRun);
      await addSchedule(Scheduler.backup, defaultSchedules[Scheduler.backup]!, lastRun: lastRun);
      clock.t = DateTime.utc(2026, 11, 18, 10); // Wednesday morning, 7 weeks later
      final s = scheduler();
      expect(await s.tick(), hasLength(4));
      final byKind = {for (final a in await jobArgs()) a['kind']: a['due']};
      expect(byKind, {
        Scheduler.dailyReport: DateTime.utc(2026, 11, 17, 18).toIso8601String(),
        Scheduler.weeklyReport: DateTime.utc(2026, 11, 16, 9).toIso8601String(),
        Scheduler.monthlyReport: DateTime.utc(2026, 11, 1, 9).toIso8601String(),
        Scheduler.backup: DateTime.utc(2026, 11, 18, 2).toIso8601String(),
      });
      // Ticking every minute afterwards adds nothing until the next occurrence.
      for (var i = 0; i < 5; i++) {
        clock.advance(const Duration(minutes: 1));
        expect(await s.tick(), isEmpty);
      }
      clock.t = DateTime.utc(2026, 11, 18, 18);
      expect(await s.tick(), hasLength(1));
    });

    test('not yet due today: nothing is enqueued', () async {
      await addSchedule('custom', const ScheduleRule(hour: 18), lastRun: DateTime.utc(2026, 11, 15, 18, 0, 30));
      clock.t = DateTime.utc(2026, 11, 16, 17, 59);
      expect(await scheduler().tick(), isEmpty);
      clock.t = DateTime.utc(2026, 11, 16, 18);
      expect(await scheduler().tick(), hasLength(1));
    });

    test('job args carry the schedule id and due time; lastRunAt moves forward', () async {
      await addSchedule('mine', const ScheduleRule(hour: 9), kind: 'custom');
      await scheduler().tick();
      final a = (await jobArgs()).single;
      expect(a['kind'], 'custom');
      expect(a['schedule_id'], 'mine');
      final row = (await db.select(db.schedules).get()).single;
      expect(row.lastRunAt!.toUtc().isBefore(DateTime.parse(a['due'] as String)), isFalse);
    });

    test('disabled schedules are skipped', () async {
      await addSchedule('custom', const ScheduleRule(hour: 9), enabled: false);
      expect(await scheduler().tick(), isEmpty);
    });

    test('a positive offset: local 09:00 Monday at UTC+10 is due on Sunday 23:00 UTC', () async {
      await addSchedule(
        Scheduler.weeklyReport,
        defaultSchedules[Scheduler.weeklyReport]!,
        lastRun: DateTime.utc(2026, 11, 14),
      );
      clock.t = DateTime.utc(2026, 11, 15, 23, 1);
      expect(await scheduler(offset: const Duration(hours: 10)).tick(), hasLength(1));
      expect((await jobArgs()).single['due'], DateTime.utc(2026, 11, 15, 23).toIso8601String());
    });
  });
}
