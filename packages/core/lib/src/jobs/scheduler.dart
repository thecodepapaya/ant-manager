import 'dart:convert';

import 'package:drift/drift.dart';

import '../data/profile_db.dart';
import '../ports/ports.dart';
import 'job_queue.dart';

/// A schedule rule (Schedules.rule JSON): local wall-clock [hour]:[minute] in the profile time zone,
/// on [weekdays] (1 = Monday … 7 = Sunday) if set, on [monthDay] if set, on the first day of a
/// quarter if [quarterly]. No constraint = every day.
class ScheduleRule {
  const ScheduleRule({required this.hour, this.minute = 0, this.weekdays, this.monthDay, this.quarterly = false});
  final int hour, minute;
  final List<int>? weekdays;
  final int? monthDay;
  final bool quarterly;

  factory ScheduleRule.fromJson(Map<String, Object?> j) => ScheduleRule(
    hour: (j['hour'] as num).toInt(),
    minute: (j['minute'] as num?)?.toInt() ?? 0,
    weekdays: (j['weekdays'] as List?)?.map((d) => (d as num).toInt()).toList(),
    monthDay: (j['monthDay'] as num?)?.toInt(),
    quarterly: j['quarterly'] == true,
  );

  Map<String, Object?> toJson() => {
    'hour': hour,
    'minute': minute,
    if (weekdays != null) 'weekdays': weekdays,
    if (monthDay != null) 'monthDay': monthDay,
    if (quarterly) 'quarterly': true,
  };

  bool matchesDate(DateTime localDate) =>
      (weekdays == null || weekdays!.contains(localDate.weekday)) &&
      (monthDay == null || localDate.day == monthDay) &&
      (!quarterly || (localDate.day == 1 && (localDate.month - 1) % 3 == 0));

  /// The latest occurrence at or before [now] (UTC result), or null if none in the last ~13 months.
  /// [utcOffset] is the profile's offset at [now] (#87); a DST change shifts due times from the next tick.
  DateTime? latestDue(DateTime now, Duration utcOffset) {
    final local = now.toUtc().add(utcOffset); // wall clock, carried in a UTC DateTime
    for (var back = 0; back <= 400; back++) {
      final d = DateTime.utc(local.year, local.month, local.day - back);
      final at = DateTime.utc(d.year, d.month, d.day, hour, minute);
      if (at.isAfter(local) || !matchesDate(d)) continue;
      return at.subtract(utcOffset);
    }
    return null;
  }
}

/// Default schedules (LLD 04 §4.11). Ids equal kinds; kinds are job kinds.
const defaultSchedules = <String, ScheduleRule>{
  Scheduler.dailyReport: ScheduleRule(hour: 18, weekdays: [1, 2, 3, 4, 5]),
  Scheduler.weeklyReport: ScheduleRule(hour: 9, weekdays: [1]),
  Scheduler.monthlyReport: ScheduleRule(hour: 9, monthDay: 1),
  Scheduler.quarterlyReport: ScheduleRule(hour: 9, quarterly: true),
  Scheduler.backup: ScheduleRule(hour: 2),
};

/// Turns Schedules rows into jobs (LLD 04 §4.11). Call [tick] on launch and every minute.
/// Missed runs catch up once: only the latest due occurrence is enqueued (#79).
class Scheduler {
  Scheduler(this.db, this.jobs, {required this.utcOffset, this.clock = const SystemClock()});
  final ProfileDb db;
  final JobQueue jobs;

  /// Profile time zone offset at an instant (#87).
  final Duration Function(DateTime at) utcOffset;
  final Clock clock;

  static const dailyReport = 'report:daily';
  static const weeklyReport = 'report:weekly';
  static const monthlyReport = 'report:monthly';
  static const quarterlyReport = 'report:quarterly';
  static const backup = 'backup';

  /// Inserts missing default schedules with lastRunAt = now, so a new profile doesn't
  /// immediately "catch up" runs from before it existed.
  Future<void> seedDefaults() async {
    final now = clock.now();
    await db.batch((b) {
      for (final MapEntry(:key, :value) in defaultSchedules.entries) {
        b.insert(
          db.schedules,
          SchedulesCompanion.insert(id: key, kind: key, rule: jsonEncode(value.toJson()), lastRunAt: Value(now)),
          mode: InsertMode.insertOrIgnore,
        );
      }
    });
  }

  /// Enqueues at most one job per enabled schedule whose latest due time is after its last run.
  /// Job args: `{schedule_id, due}` (due = ISO-8601 UTC). Returns the enqueued job ids.
  Future<List<String>> tick([DateTime? now]) async {
    final at = (now ?? clock.now()).toUtc();
    final offset = utcOffset(at);
    final enqueued = <String>[];
    final rows = await (db.select(db.schedules)..where((s) => s.enabled.equals(true))).get();
    for (final s in rows) {
      final due = ScheduleRule.fromJson(jsonDecode(s.rule) as Map<String, Object?>).latestDue(at, offset);
      if (due == null) continue;
      final last = s.lastRunAt;
      if (last != null && !last.isBefore(due)) continue;
      await db.transaction(() async {
        enqueued.add(await jobs.enqueue(s.kind, args: {'schedule_id': s.id, 'due': due.toIso8601String()}));
        await (db.update(
          db.schedules,
        )..where((x) => x.id.equals(s.id))).write(SchedulesCompanion(lastRunAt: Value(at)));
      });
    }
    return enqueued;
  }
}
