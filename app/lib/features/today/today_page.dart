import 'package:core/core.dart' hide Provider;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui/ui.dart';

import '../../engine/commands.dart';
import '../../shell/shell_state.dart';
import '../../state/data.dart';
import '../../widgets/common.dart';
import '../../widgets/evidence_row.dart';
import '../../widgets/fact_tile.dart';
import '../../widgets/note_composer.dart';
import '../../widgets/report_view.dart';

/// Home (SPEC §7): a journal-style day view. Evidence grouped by project on the left; the day's
/// read-only daily report and its facts on the right. ←/→ or [/] move between days.
class TodayPage extends ConsumerWidget {
  const TodayPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final focus = ref.watch(todayFocusProvider);
    final day = focus.day;
    final ctl = ref.read(todayFocusProvider.notifier);
    final evidence = ref.watch(evidenceProvider((day: day, sourceId: null, projectId: null, limit: 1000))).value;
    void go(int d) => ctl.setDay(shiftDayBy(day, d));
    final isToday = day == todayDay();

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => go(-1),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => go(1),
        const SingleActivator(LogicalKeyboardKey.bracketLeft): () => go(-1),
        const SingleActivator(LogicalKeyboardKey.bracketRight): () => go(1),
      },
      child: Focus(
        autofocus: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TopBar(
              leading: [
                AntIconButton(icon: Icons.chevron_left_rounded, tooltip: 'Previous day  ←', onPressed: () => go(-1)),
                AntIconButton(icon: Icons.chevron_right_rounded, tooltip: 'Next day  →', onPressed: () => go(1)),
              ],
              titleWidget: AntInteractive(
                semanticLabel: 'Pick a date',
                focusRadius: t.radii.brMd,
                onTap: () async {
                  final d = await pickDay(context, day);
                  if (d != null) ctl.setDay(d);
                },
                builder: (context, s) => Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(longDayLabel(day), style: t.typo.title.copyWith(color: t.text)),
                      SizedBox(width: t.space.xs),
                      Icon(Icons.keyboard_arrow_down_rounded, size: t.icon.sm, color: s.hovered ? t.text : t.muted),
                    ]),
                    Text(
                      '${relativeDayLabel(day)} · ${plural(evidence?.length ?? 0, 'item')}',
                      style: t.typo.small.copyWith(color: t.muted),
                    ),
                  ],
                ),
              ),
              actions: [
                if (!isToday) AntButton.ghost(label: 'Today', onPressed: () => ctl.setDay(todayDay())),
                AntButton.ghost(
                  label: 'Sync',
                  icon: Icons.sync_rounded,
                  onPressed: () => runCmd(context, ref, syncNowCmd(), ok: 'Syncing your sources'),
                ),
              ],
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  final wide = c.maxWidth >= t.density.columnMinWidth * 3;
                  final left = _EvidenceColumn(day: day, highlight: focus.highlight);
                  final right = _DayNarrative(day: day, highlight: focus.highlight);
                  if (!wide) {
                    return ListView(children: [left, Divider(color: t.border, height: t.stroke.hairline), right]);
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 6,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border(right: BorderSide(color: t.border, width: t.stroke.hairline)),
                          ),
                          child: SingleChildScrollView(child: left),
                        ),
                      ),
                      Expanded(flex: 5, child: SingleChildScrollView(child: right)),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EvidenceColumn extends ConsumerStatefulWidget {
  const _EvidenceColumn({required this.day, required this.highlight});
  final String day;
  final Set<String> highlight;
  @override
  ConsumerState<_EvidenceColumn> createState() => _EvidenceColumnState();
}

class _EvidenceColumnState extends ConsumerState<_EvidenceColumn> {
  var _showHidden = false;
  final _firstHighlight = GlobalKey();

  @override
  void didUpdateWidget(covariant _EvidenceColumn old) {
    super.didUpdateWidget(old);
    if (widget.highlight.isNotEmpty && widget.highlight != old.highlight) _scrollToHighlight();
  }

  @override
  void initState() {
    super.initState();
    if (widget.highlight.isNotEmpty) _scrollToHighlight();
  }

  void _scrollToHighlight() => WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _firstHighlight.currentContext;
        if (ctx != null && ctx.mounted) {
          Scrollable.ensureVisible(ctx, duration: context.tokens.motion.slow, alignment: 0.3);
        }
      });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final items = ref.watch(evidenceProvider((day: widget.day, sourceId: null, projectId: null, limit: 1000)));
    final projects = ref.watch(allProjectsProvider).value ?? const <Project>[];
    return Padding(
      padding: EdgeInsets.fromLTRB(t.space.xxl, t.space.xl, t.space.xxl, t.space.giant),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NoteComposer(day: widget.day),
          SizedBox(height: t.space.xxl),
          AsyncBody(
            items,
            builder: (all) {
              final hidden = all.where((e) => e.e.hidden).length;
              final visible = _showHidden ? all : all.where((e) => !e.e.hidden).toList();
              if (all.isEmpty) return _empty(context);
              final groups = <String?, List<EvidenceItem>>{};
              for (final e in visible) {
                groups.putIfAbsent(e.e.projectId, () => []).add(e);
              }
              final order = groups.keys.toList()
                ..sort((a, b) => a == null ? 1 : (b == null ? -1 : _name(projects, a).compareTo(_name(projects, b))));
              var keyed = false;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionHeader(
                    'Evidence',
                    note: [
                      plural(all.length, 'item'),
                      if (all.any((e) => e.e.starred)) '${all.where((e) => e.e.starred).length} starred',
                      if (hidden > 0) '$hidden hidden',
                    ].join(' · '),
                    trailing: [
                      if (hidden > 0)
                        AntButton.ghost(
                          size: AntSize.sm,
                          label: _showHidden ? 'Hide hidden' : 'Show hidden',
                          onPressed: () => setState(() => _showHidden = !_showHidden),
                        ),
                    ],
                  ),
                  for (final pid in order) ...[
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: t.space.md, vertical: t.space.sm),
                      child: Row(children: [
                        AntDot(color: projectColour(t, projects.where((p) => p.id == pid).firstOrNull)),
                        SizedBox(width: t.space.md),
                        Text(pid == null ? 'No project' : _name(projects, pid),
                            style: t.typo.bodyStrong.copyWith(color: t.text)),
                        SizedBox(width: t.space.md),
                        Muted('${groups[pid]!.length}'),
                      ]),
                    ),
                    for (final e in groups[pid]!)
                      Builder(builder: (context) {
                        final hl = widget.highlight.contains(e.e.id);
                        final key = hl && !keyed ? _firstHighlight : null;
                        if (key != null) keyed = true;
                        return EvidenceRow(key: key ?? ValueKey(e.e.id), item: e, highlighted: hl);
                      }),
                    SizedBox(height: t.space.lg),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String _name(List<Project> ps, String id) => ps.where((p) => p.id == id).firstOrNull?.name ?? 'Unknown project';

  Widget _empty(BuildContext context) {
    final isPast = widget.day.compareTo(todayDay()) < 0;
    return AntEmptyState(
      icon: Icons.wb_sunny_outlined,
      title: isPast ? 'Nothing captured on this day' : 'A quiet day so far',
      message: isPast
          ? 'You can still add a note above about what you worked on. It counts as evidence for this day.'
          : 'Work from your connected sources shows up here as it happens. Add a note above any time, '
              'or press ⌥⌘N from anywhere.',
      action: AntButton(
        label: 'Connect a source',
        icon: Icons.power_outlined,
        onPressed: () => ref.read(shellSectionProvider.notifier).select(ShellSection.sources),
      ),
    );
  }
}

/// The day's read-only daily report and the facts behind it.
class _DayNarrative extends ConsumerWidget {
  const _DayNarrative({required this.day, required this.highlight});
  final String day;
  final Set<String> highlight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final reports = ref.watch(reportsProvider((kind: PeriodKind.daily, day: day))).value ?? const <ReportItem>[];
    final report = reports.where((r) => r.r.templateId == defaultTemplateFor[PeriodKind.daily]).firstOrNull ??
        reports.firstOrNull;
    final generating = report != null && ref.watch(generatingProvider).contains(report.r.id);
    final shown = report?.shown;
    final facts = ref.watch(factsProvider(factQuery(start: day, end: day))).value ?? const <FactItem>[];
    final ctl = ref.read(todayFocusProvider.notifier);

    void regenerate(String? style) => generateReport(
          context,
          ref,
          reportId: report?.r.id,
          kind: PeriodKind.daily,
          start: day,
          end: day,
          style: style,
        );

    final pad = EdgeInsets.fromLTRB(t.space.xxxl, t.space.xl, t.space.xxxl, t.space.giant);
    // Nothing to write from yet (e.g. a new profile): one calm note instead of empty controls.
    final loaded = ref.watch(reportsProvider((kind: PeriodKind.daily, day: day))).hasValue &&
        ref.watch(factsProvider(factQuery(start: day, end: day))).hasValue;
    if (loaded && report == null && facts.isEmpty) {
      return Padding(
        padding: pad,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader('Daily report'),
            Panel(
              padding: EdgeInsets.all(t.space.xxl),
              child: Column(children: [
                Icon(Icons.auto_awesome_outlined, size: t.icon.lg, color: t.muted),
                SizedBox(height: t.space.md),
                Text('Your daily report appears here', style: t.typo.bodyStrong.copyWith(color: t.text)),
                SizedBox(height: t.space.xs),
                Text(
                  'Once there’s work for this day, Ant Manager writes a short report from it at 18:00 on weekdays. '
                  'Nothing to do until then.',
                  textAlign: TextAlign.center,
                  style: t.typo.small.copyWith(color: t.muted),
                ),
              ]),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: pad,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader('Daily report', trailing: [if (report != null) ReportStatusChip(report)]),
          Wrap(
            spacing: t.space.sm,
            runSpacing: t.space.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              RegenerateButton(
                label: shown == null ? 'Generate' : 'Regenerate',
                enabled: !generating && !(report?.r.locked ?? false),
                onRegenerate: regenerate,
              ),
              if (shown != null)
                ShareButton(markdown: shown.markdown, fileName: 'Daily report $day'),
              if (shown != null)
                Muted(
                  [
                    shown.modelId,
                    hhmm(shown.generatedAt),
                    if (shown.styleInstruction != null) '“${shown.styleInstruction}”',
                    if (report!.r.locked) 'unlock in Reports to regenerate',
                  ].join(' · '),
                  style: t.typo.chip,
                ),
            ],
          ),
          SizedBox(height: t.space.xl),
          if (generating)
            const GeneratingPlaceholder()
          else if (shown != null)
            ReportProse(markdown: shown.markdown)
          else
            Panel(
              padding: EdgeInsets.all(t.space.xxl),
              child: Column(children: [
                Text('No report for this day yet', style: t.typo.bodyStrong.copyWith(color: t.text)),
                SizedBox(height: t.space.xs),
                Muted(
                  facts.isEmpty
                      ? 'It’s written from the facts below once there are some, on schedule or on demand.'
                      : 'Generate it now from ${plural(facts.length, 'fact')}, or wait for the scheduled run.',
                  style: t.typo.small,
                ),
              ]),
            ),
          SizedBox(height: t.space.giant),
          SectionHeader(
            'Facts',
            note: facts.isEmpty ? null : 'What the model understood. Confirm or correct; reports follow.',
          ),
          if (facts.isEmpty)
            Muted(
              'No facts yet. They appear shortly after evidence arrives, once an AI provider is set up in Settings.',
              style: t.typo.small,
            ),
          for (final f in facts)
            FactTile(
              item: f,
              highlightedEvidence: highlight,
              onCitation: (c) => ctl.focus(c.day, {c.evidenceId}),
            ),
        ],
      ),
    );
  }
}
