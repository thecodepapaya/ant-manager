/// Settings → Schedule: report schedules, the daily nudge and the weekends toggle (SPEC §7, §8).
library;

import 'dart:convert';

import 'package:core/core.dart' hide Provider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui/ui.dart';

import '../../engine/engine_runtime.dart' show nudgeJobKind;
import '../../engine/setup_commands.dart';
import 'kit.dart';
import 'setup_providers.dart';

const _weekdays = [1, 2, 3, 4, 5];
const _everyDay = [1, 2, 3, 4, 5, 6, 7];
const _dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

String hhmm(int h, int m) => '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

/// Half-hour steps, plus the current value if it's off-grid (e.g. 18:05).
List<((int, int), String)> timeOptions(ScheduleRule r) {
  final out = [
    for (var i = 0; i < 48; i++) ((i ~/ 2, (i % 2) * 30), hhmm(i ~/ 2, (i % 2) * 30)),
  ];
  if (r.minute % 30 != 0) out.add(((r.hour, r.minute), hhmm(r.hour, r.minute)));
  out.sort((a, b) => (a.$1.$1 * 60 + a.$1.$2).compareTo(b.$1.$1 * 60 + b.$1.$2));
  return out;
}

ScheduleRule ruleOf(Schedule s) => ScheduleRule.fromJson(jsonDecode(s.rule) as Map<String, Object?>);

ScheduleRule withTime(ScheduleRule r, int h, int m) =>
    ScheduleRule(hour: h, minute: m, weekdays: r.weekdays, monthDay: r.monthDay, quarterly: r.quarterly);

/// A time select bound to a schedule row.
class ScheduleTimeSelect extends ConsumerWidget {
  const ScheduleTimeSelect(this.s, {super.key});
  final Schedule s;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ruleOf(s);
    return SelectButton<(int, int)>(
      value: (r.hour, r.minute),
      options: timeOptions(r),
      onChanged: (v) => runCmd(context, ref, setScheduleCmd(s.id, withTime(r, v.$1, v.$2), s.enabled)),
    );
  }
}

class ScheduleTab extends ConsumerWidget {
  const ScheduleTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final all = ref.watch(schedulesProvider).value ?? const <String, Schedule>{};
    final daily = all[Scheduler.dailyReport];
    final nudge = all[nudgeJobKind];
    final weekends = daily != null && (ruleOf(daily).weekdays?.length ?? 7) == 7;

    Widget toggle(Schedule s) => AntSwitch(
          value: s.enabled,
          semanticLabel: 'Enabled',
          onChanged: (v) => runCmd(context, ref, setScheduleCmd(s.id, ruleOf(s), v)),
        );

    Widget row(String id, String name, String hint, {Widget? extra}) {
      final s = all[id];
      if (s == null) return const SizedBox.shrink();
      return PanelRow(
        title: name,
        hint: hint,
        trailing: [?extra, ScheduleTimeSelect(s), toggle(s)],
      );
    }

    Future<void> setWeekends(bool on) async {
      for (final s in [?daily, ?nudge]) {
        final r = ruleOf(s);
        await runCmd(
          context,
          ref,
          setScheduleCmd(s.id, ScheduleRule(hour: r.hour, minute: r.minute, weekdays: on ? _everyDay : _weekdays), s.enabled),
        );
      }
    }

    final weekly = all[Scheduler.weeklyReport];
    final weeklyDay = weekly == null ? 1 : (ruleOf(weekly).weekdays?.first ?? 1);

    return PageBody(
      maxWidth: t.narrowPage,
      children: [
        Text('Runs while the app is open (it stays in the menu bar). Missed runs catch up once on the next launch.',
            style: t.typo.small.copyWith(color: t.muted)),
        Gap(t.space.lg),
        ListPanel(children: [
          row(Scheduler.dailyReport, 'Daily report', 'Drafted from the day’s evidence · ${weekends ? 'every day' : 'weekdays'}'),
          row(nudgeJobKind, 'End-of-day nudge',
              '“Your day is drafted, 2-minute review?” · skipped on days with no evidence'),
          row(
            Scheduler.weeklyReport,
            'Weekly report',
            'Rolled up from the week’s facts',
            extra: weekly == null
                ? null
                : SelectButton<int>(
                    value: weeklyDay,
                    options: [for (var d = 1; d <= 7; d++) (d, _dayNames[d - 1])],
                    onChanged: (d) {
                      final r = ruleOf(weekly);
                      runCmd(context, ref,
                          setScheduleCmd(weekly.id, ScheduleRule(hour: r.hour, minute: r.minute, weekdays: [d]), weekly.enabled));
                    },
                  ),
          ),
          row(Scheduler.monthlyReport, 'Monthly report', 'On the 1st, for the month before'),
          row(Scheduler.quarterlyReport, 'Quarterly report', 'On the first day of each quarter · good for reviews'),
          PanelRow(
            title: 'Include weekends',
            hint: 'Draft and nudge on Saturday and Sunday too',
            trailing: [AntSwitch(value: weekends, semanticLabel: 'Include weekends', onChanged: daily == null ? null : setWeekends)],
          ),
        ]),
        Gap(t.space.lg),
        Text('Sources sync every 15 minutes (ICS feeds hourly); local git updates as you commit.',
            style: t.typo.small.copyWith(color: t.muted)),
      ],
    );
  }
}
