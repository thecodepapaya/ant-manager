import '../domain/enums.dart';
import '../jobs/job_queue.dart';
import '../util/ids.dart';
import 'generator.dart';
import 'periods.dart';
import 'templates.dart';

/// The period a scheduled run at [due] reports on: the daily run covers its own day,
/// longer kinds cover the period that just ended (weekly Mon 09:00 → last Mon–Sun).
Period scheduledPeriod(PeriodKind kind, DateTime due, Duration utcOffset) {
  final day = dayOf(due, utcOffset);
  final current = Period.containing(kind, day);
  return kind == PeriodKind.daily ? current : current.previous();
}

/// Job handler for `report:<kind>` jobs enqueued by the Scheduler (args: `{due}` ISO-8601 UTC).
/// Uses the kind's default built-in template; locked reports are left alone.
JobHandler scheduledReportHandler(
  ReportGenerator generator,
  PeriodKind kind,
  Duration Function(DateTime at) utcOffset,
) => (args) async {
  final due = DateTime.parse(args['due'] as String);
  final p = scheduledPeriod(kind, due, utcOffset(due));
  final report = await generator.ensureReport(kind, p.start, p.end, defaultTemplateFor[kind]!);
  if (report.locked) return;
  await generator.generate(report.id).drain<void>();
};
