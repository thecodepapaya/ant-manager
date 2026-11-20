import 'package:core/core.dart' hide Provider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui/ui.dart';

import '../../engine/commands.dart';
import '../../shell/shell_state.dart';
import '../../state/data.dart';
import '../../widgets/common.dart';
import '../../widgets/fact_tile.dart';
import '../narrative/narrative_page.dart' show PeriodFilter;

/// Wins (#51, #63): accepted Outcome facts, plus model suggestions to accept or reject.
class WinsPage extends ConsumerStatefulWidget {
  const WinsPage({super.key});
  @override
  ConsumerState<WinsPage> createState() => _WinsPageState();
}

class _WinsPageState extends ConsumerState<WinsPage> {
  var _period = PeriodFilter.quarter;
  String? _projectId;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final r = _period.range();
    final projects = ref.watch(allProjectsProvider).value ?? const <Project>[];
    final wins = ref.watch(factsProvider(factQuery(
      start: r.start,
      end: r.end,
      projectId: _projectId,
      winStatus: WinStatus.accepted,
    )));
    final suggested = ref.watch(factsProvider(factQuery(projectId: _projectId, winStatus: WinStatus.suggested))).value ??
        const <FactItem>[];
    final starred = ref.watch(starredWithoutWinProvider(r)).value ?? const <Evidence>[];
    final list = wins.value ?? const <FactItem>[];
    final months = <String, List<FactItem>>{};
    for (final w in list) {
      months.putIfAbsent(monthLabel(w.f.periodStart), () => []).add(w);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TopBar(
          title: 'Wins log',
          subtitle: '${plural(list.length, 'win')} · ${_period.label.toLowerCase()}',
          middle: [
            for (final p in [PeriodFilter.month, PeriodFilter.quarter, PeriodFilter.year, PeriodFilter.all])
              AntSelectChip(label: p.label, selected: p == _period, onPressed: () => setState(() => _period = p)),
          ],
          actions: [
            AntSelect<String?>(
              value: _projectId,
              options: [
                const AntOption(null, 'All projects'),
                for (final p in projects)
                  AntOption(p.id, p.name, leading: AntDot(color: projectColour(t, p), size: t.space.sm)),
              ],
              onChanged: (v) => setState(() => _projectId = v),
            ),
            AntButton(
              label: 'Use in a report',
              onPressed: () => ref.read(shellSectionProvider.notifier).select(ShellSection.reports),
            ),
          ],
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(t.space.xxxl, t.space.xl, t.space.xxxl, t.space.giant),
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: t.density.contentMaxWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (suggested.isNotEmpty) ...[
                        SectionHeader(
                          'Suggested by the model',
                          tone: t.accentText,
                          note: 'Accept to add to the log. Nothing is added without you.',
                        ),
                        Panel(
                          accent: true,
                          child: Column(children: [for (final s in suggested) _SuggestionRow(item: s, projects: projects)]),
                        ),
                        SizedBox(height: t.space.huge),
                      ],
                      if (starred.isNotEmpty) ...[
                        SectionHeader('Starred, not written up yet', note: 'The model couldn’t write these wins. Try again.'),
                        for (final e in starred)
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: t.space.md, vertical: t.space.sm),
                            child: Row(children: [
                              Icon(Icons.star_rounded, size: t.icon.sm, color: t.accent),
                              SizedBox(width: t.space.md),
                              Expanded(child: Text(e.title, style: t.typo.body.copyWith(color: t.text2))),
                              Muted(shortDayLabel(e.day)),
                              SizedBox(width: t.space.md),
                              AntButton(
                                size: AntSize.sm,
                                label: 'Write win',
                                onPressed: () => runCmd(context, ref, starEvidenceCmd(e.id), ok: 'Added to your Wins log'),
                              ),
                            ]),
                          ),
                        SizedBox(height: t.space.huge),
                      ],
                      if (wins.hasValue && list.isEmpty && suggested.isEmpty)
                        const AntEmptyState(
                          icon: Icons.star_outline_rounded,
                          title: 'No wins logged for this period',
                          message: 'Star any evidence in Today to turn it into a win, or accept the model’s '
                              'suggestions when they show up here.',
                        ),
                      for (final MapEntry(key: month, value: items) in months.entries) ...[
                        Padding(
                          padding: EdgeInsets.only(top: t.space.sm, bottom: t.space.sm),
                          child: Row(children: [
                            Text(month, style: t.typo.bodyStrong.copyWith(color: t.text)),
                            SizedBox(width: t.space.md),
                            Muted(plural(items.length, 'win')),
                          ]),
                        ),
                        for (final w in items) _WinRow(item: w, projects: projects),
                        SizedBox(height: t.space.xxl),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _sources(FactItem f) {
  final kinds = {for (final c in f.citations) kindLabel(c.kind)};
  return kinds.isEmpty ? 'no sources' : plural(f.citations.length, 'source');
}

class _SuggestionRow extends ConsumerWidget {
  const _SuggestionRow({required this.item, required this.projects});
  final FactItem item;
  final List<Project> projects;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final f = item.f;
    final project = projects.where((p) => p.id == f.projectId).firstOrNull;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: t.space.xl, vertical: t.space.lg),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.divider, width: t.stroke.hairline))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: EdgeInsets.only(top: t.space.sm), child: AntDot(color: projectColour(t, project))),
          SizedBox(width: t.space.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(f.statement, style: t.typo.bodyStrong.copyWith(color: t.text)),
                SizedBox(height: t.space.xxs),
                Muted([project?.name ?? 'No project', shortDayLabel(f.periodStart), _sources(item)].join(' · ')),
                if (item.citations.isNotEmpty) ...[SizedBox(height: t.space.sm), CitationChips(item.citations)],
              ],
            ),
          ),
          SizedBox(width: t.space.md),
          AntButton.ghost(
            label: 'Dismiss',
            onPressed: () => runCmd(context, ref, setWinStatusCmd(f.id, WinStatus.rejected)),
          ),
          SizedBox(width: t.space.sm),
          AntButton(
            label: 'Accept',
            onPressed: () => runCmd(context, ref, setWinStatusCmd(f.id, WinStatus.accepted), ok: 'Added to your Wins log'),
          ),
        ],
      ),
    );
  }
}

class _WinRow extends ConsumerWidget {
  const _WinRow({required this.item, required this.projects});
  final FactItem item;
  final List<Project> projects;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final f = item.f;
    final project = projects.where((p) => p.id == f.projectId).firstOrNull;
    return Hover(
      builder: (context, hovered) => Container(
        padding: EdgeInsets.symmetric(horizontal: t.space.md, vertical: t.space.lg),
        decoration: BoxDecoration(
          color: hovered ? t.hover : t.hover.withValues(alpha: 0),
          border: Border(bottom: BorderSide(color: t.divider, width: t.stroke.hairline)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(top: t.space.xxs),
              child: Icon(Icons.star_rounded, size: t.icon.md, color: t.accent),
            ),
            SizedBox(width: t.space.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(f.statement, style: t.typo.bodyStrong.copyWith(color: t.text)),
                  SizedBox(height: t.space.sm),
                  Wrap(
                    spacing: t.space.md,
                    runSpacing: t.space.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      AntSelectChip(
                        label: project?.name ?? 'No project',
                        selected: false,
                        leading: AntDot(color: projectColour(t, project), size: t.space.sm),
                        onPressed: null,
                      ),
                      Muted([shortDayLabel(f.periodStart), _sources(item), originLabel(f.origin)].join(' · ')),
                    ],
                  ),
                  if (hovered && item.citations.isNotEmpty) ...[
                    SizedBox(height: t.space.sm),
                    CitationChips(item.citations),
                  ],
                ],
              ),
            ),
            AnimatedOpacity(
              duration: t.motion.fast,
              opacity: hovered ? 1 : 0,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                AntIconButton(icon: Icons.edit_outlined, tooltip: 'Reword', onPressed: () => editFact(context, ref, f)),
                AntIconButton(
                  icon: Icons.remove_circle_outline_rounded,
                  tooltip: 'Remove from wins',
                  onPressed: () => runCmd(context, ref, setWinStatusCmd(f.id, WinStatus.none)),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
