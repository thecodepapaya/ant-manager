import 'dart:convert';

import 'package:core/core.dart' hide Provider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui/ui.dart';

import '../../engine/commands.dart';
import '../../state/data.dart';
import '../../widgets/common.dart';
import '../../widgets/fact_tile.dart';

enum _Tab { facts, review, workstreams }

/// Period filter shared by Narrative and Wins.
enum PeriodFilter {
  week('This week'),
  month('This month'),
  quarter('This quarter'),
  year('This year'),
  all('All time');

  const PeriodFilter(this.label);
  final String label;

  ({String? start, String? end}) range() {
    final today = todayDay();
    return switch (this) {
      PeriodFilter.week => _p(Period.containing(PeriodKind.weekly, today)),
      PeriodFilter.month => _p(Period.containing(PeriodKind.monthly, today)),
      PeriodFilter.quarter => _p(Period.containing(PeriodKind.quarterly, today)),
      PeriodFilter.year => (start: '${today.substring(0, 4)}-01-01', end: '${today.substring(0, 4)}-12-31'),
      PeriodFilter.all => (start: null, end: null),
    };
  }

  static ({String? start, String? end}) _p(Period p) => (start: p.start, end: p.end);
}

/// The Narrative (SPEC §8): browse facts, work the review queue, tidy workstreams.
class NarrativePage extends ConsumerStatefulWidget {
  const NarrativePage({super.key});
  @override
  ConsumerState<NarrativePage> createState() => _NarrativePageState();
}

class _NarrativePageState extends ConsumerState<NarrativePage> {
  var _tab = _Tab.facts;

  @override
  Widget build(BuildContext context) {
    final review = ref.watch(reviewCountProvider).value ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TopBar(
          title: 'Narrative',
          middle: [
            AntTabs<_Tab>(
              value: _tab,
              onChanged: (v) => setState(() => _tab = v),
              tabs: [
                const AntTab(value: _Tab.facts, label: 'Facts'),
                AntTab(value: _Tab.review, label: review > 0 ? 'Review ($review)' : 'Review'),
                const AntTab(value: _Tab.workstreams, label: 'Workstreams'),
              ],
            ),
          ],
        ),
        Expanded(
          child: switch (_tab) {
            _Tab.facts => const _FactsBrowser(),
            _Tab.review => const _ReviewQueue(),
            _Tab.workstreams => const _Workstreams(),
          },
        ),
      ],
    );
  }
}

/// Bounded, padded scroll body.
class _Body extends StatelessWidget {
  const _Body({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ListView(
      padding: EdgeInsets.fromLTRB(t.space.xxxl, t.space.xl, t.space.xxxl, t.space.giant),
      children: [
        Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: t.density.contentMaxWidth),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
          ),
        ),
      ],
    );
  }
}

class _FactsBrowser extends ConsumerStatefulWidget {
  const _FactsBrowser();
  @override
  ConsumerState<_FactsBrowser> createState() => _FactsBrowserState();
}

class _FactsBrowserState extends ConsumerState<_FactsBrowser> {
  var _period = PeriodFilter.week;
  FactType? _type;
  String? _projectId;
  String? _workstreamId;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final r = _period.range();
    final projects = ref.watch(allProjectsProvider).value ?? const <Project>[];
    final workstreams = ref.watch(workstreamsProvider).value ?? const <WorkstreamItem>[];
    final facts = ref.watch(factsProvider(factQuery(
      start: r.start,
      end: r.end,
      type: _type,
      projectId: _projectId,
      workstreamId: _workstreamId,
    )));
    final days = <String, List<FactItem>>{};
    for (final f in facts.value ?? const <FactItem>[]) {
      days.putIfAbsent(f.f.periodStart, () => []).add(f);
    }
    return _Body(children: [
      Wrap(
        spacing: t.space.sm,
        runSpacing: t.space.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          AntSelect<PeriodFilter>(
            value: _period,
            options: [for (final p in PeriodFilter.values) AntOption(p, p.label)],
            onChanged: (v) => setState(() => _period = v),
          ),
          AntSelect<String?>(
            value: _projectId,
            options: [
              const AntOption(null, 'All projects'),
              for (final p in projects)
                AntOption(p.id, p.name, leading: AntDot(color: projectColour(t, p), size: t.space.sm)),
            ],
            onChanged: (v) => setState(() => _projectId = v),
          ),
          if (workstreams.isNotEmpty)
            AntSelect<String?>(
              value: _workstreamId,
              options: [
                const AntOption(null, 'All workstreams'),
                for (final w in workstreams) AntOption(w.w.id, w.w.title),
              ],
              onChanged: (v) => setState(() => _workstreamId = v),
            ),
        ],
      ),
      SizedBox(height: t.space.md),
      Wrap(
        spacing: t.space.sm,
        runSpacing: t.space.sm,
        children: [
          AntSelectChip(label: 'All types', selected: _type == null, onPressed: () => setState(() => _type = null)),
          for (final ft in FactType.values)
            AntSelectChip(label: factTypeLabel(ft), selected: _type == ft, onPressed: () => setState(() => _type = ft)),
        ],
      ),
      SizedBox(height: t.space.lg),
      if (facts.hasValue && days.isEmpty)
        const AntEmptyState(
          icon: Icons.article_outlined,
          title: 'No facts here yet',
          message: 'Facts are written from your evidence: outcomes, problems solved, invisible work, '
              'hiccups, decisions and where time went. Try a longer period or fewer filters.',
        ),
      for (final MapEntry(key: day, value: list) in days.entries) ...[
        Padding(
          padding: EdgeInsets.fromLTRB(t.space.md, t.space.lg, t.space.md, t.space.xs),
          child: Row(children: [
            Text(longDayLabel(day), style: t.typo.bodyStrong.copyWith(color: t.text)),
            SizedBox(width: t.space.md),
            Muted(plural(list.length, 'fact')),
          ]),
        ),
        for (final f in list) FactTile(key: ValueKey(f.f.id), item: f, menu: _moveMenu(f, workstreams)),
      ],
    ]);
  }

  List<AntMenuEntry> _moveMenu(FactItem f, List<WorkstreamItem> ws) => [
        for (final w in ws.where((w) => w.w.id != f.f.workstreamId))
          AntMenuItem(
            label: 'Move to ${w.w.title}',
            icon: Icons.drive_file_move_outline,
            onSelected: () => runCmd(context, ref, moveFactToWorkstreamCmd(f.f.id, w.w.id)),
          ),
        if (f.f.workstreamId != null)
          AntMenuItem(
            label: 'Remove from workstream',
            icon: Icons.remove_circle_outline_rounded,
            onSelected: () => runCmd(context, ref, moveFactToWorkstreamCmd(f.f.id, null)),
          ),
      ];
}

class _ReviewQueue extends ConsumerWidget {
  const _ReviewQueue();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final facts = ref.watch(factsProvider(factQuery(reviewOnly: true)));
    final list = facts.value ?? const <FactItem>[];
    return _Body(children: [
      SectionHeader('Needs your review', note: 'The model proposes changes to facts you confirmed or edited. Nothing changes without you.'),
      if (facts.hasValue && list.isEmpty)
        const AntEmptyState(
          icon: Icons.task_alt_rounded,
          title: 'All caught up',
          message: 'When new evidence contradicts a fact you confirmed or edited, the proposal waits here.',
        ),
      for (final f in list) _ReviewCard(item: f),
    ]);
  }
}

class _ReviewCard extends ConsumerWidget {
  const _ReviewCard({required this.item});
  final FactItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final f = item.f;
    Map<String, Object?> p = const {};
    try {
      p = (jsonDecode(f.reviewProposal ?? '{}') as Map).cast<String, Object?>();
    } on FormatException {
      // shown as a plain review
    }
    final retire = p['retire'] == true;
    final statement = p['statement'] as String?;
    final reason = p['reason'] as String?;
    final what = retire
        ? 'Retire this fact'
        : statement != null
            ? 'Reword it'
            : 'Check it still holds';
    return Padding(
      padding: EdgeInsets.only(bottom: t.space.md),
      child: Panel(
        padding: EdgeInsets.all(t.space.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              AntChip(label: factTypeLabel(f.type), tone: factTypeTone(f.type)),
              SizedBox(width: t.space.sm),
              Muted(shortDayLabel(f.periodStart), style: t.typo.caption),
              const Spacer(),
              AntChip(label: what, tone: retire ? AntTone.err : AntTone.warn),
            ]),
            SizedBox(height: t.space.md),
            Text(f.statement, style: t.typo.body.copyWith(color: t.text2)),
            if (statement != null) ...[
              SizedBox(height: t.space.md),
              Container(
                padding: EdgeInsets.all(t.space.md),
                decoration: BoxDecoration(
                  color: t.surface2,
                  borderRadius: t.radii.brMd,
                  border: Border.all(color: t.borderStronger, width: t.stroke.hairline),
                ),
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: 'Proposed · ', style: TextStyle(color: t.muted)),
                    TextSpan(text: statement),
                  ]),
                  style: t.typo.body.copyWith(color: t.text),
                ),
              ),
            ],
            if (reason != null) ...[SizedBox(height: t.space.sm), Muted('Why: $reason')],
            if (item.citations.isNotEmpty) ...[
              SizedBox(height: t.space.md),
              CitationChips(item.citations),
            ],
            SizedBox(height: t.space.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AntButton.ghost(
                  label: 'Keep mine',
                  onPressed: () => runCmd(context, ref, resolveReviewCmd(f.id, accept: false)),
                ),
                SizedBox(width: t.space.sm),
                AntButton(
                  label: retire ? 'Retire it' : (statement != null ? 'Accept change' : 'Looks right'),
                  onPressed: () => runCmd(context, ref, resolveReviewCmd(f.id, accept: true)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Workstreams extends ConsumerStatefulWidget {
  const _Workstreams();
  @override
  ConsumerState<_Workstreams> createState() => _WorkstreamsState();
}

class _WorkstreamsState extends ConsumerState<_Workstreams> {
  String? _open;

  @override
  Widget build(BuildContext context) {
    final ws = ref.watch(workstreamsProvider);
    final projects = ref.watch(allProjectsProvider).value ?? const <Project>[];
    final list = ws.value ?? const <WorkstreamItem>[];
    return _Body(children: [
      SectionHeader('Workstreams', note: 'Threads of related work, grouped by the model. Rename or merge them freely.'),
      if (ws.hasValue && list.isEmpty)
        const AntEmptyState(
          icon: Icons.account_tree_outlined,
          title: 'No workstreams yet',
          message: 'As facts accumulate, related work is grouped into workstreams like “Payments idempotency”.',
        ),
      if (list.isNotEmpty)
        Panel(
          child: Column(children: [
            for (final w in list) ...[
              _WorkstreamRow(
                item: w,
                project: projects.where((p) => p.id == w.w.projectId).firstOrNull,
                others: list.where((o) => o.w.id != w.w.id).toList(),
                open: _open == w.w.id,
                onToggle: () => setState(() => _open = _open == w.w.id ? null : w.w.id),
              ),
              if (_open == w.w.id) _WorkstreamFacts(w: w.w, all: list),
            ],
          ]),
        ),
    ]);
  }
}

class _WorkstreamRow extends ConsumerWidget {
  const _WorkstreamRow({
    required this.item,
    required this.project,
    required this.others,
    required this.open,
    required this.onToggle,
  });
  final WorkstreamItem item;
  final Project? project;
  final List<WorkstreamItem> others;
  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final w = item.w;
    final span = w.spanStart == null
        ? ''
        : w.spanStart == w.spanEnd
            ? shortDayLabel(w.spanStart!)
            : '${shortDayLabel(w.spanStart!)} – ${shortDayLabel(w.spanEnd!)}';
    return AntInteractive(
      onTap: onToggle,
      semanticLabel: w.title,
      builder: (context, s) => Container(
        padding: EdgeInsets.symmetric(horizontal: t.space.xl, vertical: t.space.md),
        decoration: BoxDecoration(
          color: s.hovered ? t.hover : t.hover.withValues(alpha: 0),
          border: Border(bottom: BorderSide(color: t.divider, width: t.stroke.hairline)),
        ),
        child: Row(
          children: [
            Icon(open ? Icons.expand_more_rounded : Icons.chevron_right_rounded, size: t.icon.md, color: t.muted),
            SizedBox(width: t.space.sm),
            AntDot(color: projectColour(t, project)),
            SizedBox(width: t.space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(w.title, style: t.typo.bodyStrong.copyWith(color: t.text)),
                  Muted(
                    [
                      if (project != null) project!.name,
                      plural(item.factCount, 'fact'),
                      if (span.isNotEmpty) span,
                      if (w.summary.isNotEmpty) w.summary,
                    ].join(' · '),
                    maxLines: 1,
                  ),
                ],
              ),
            ),
            AntIconButton(
              icon: Icons.edit_outlined,
              tooltip: 'Rename',
              onPressed: () async {
                final title = await promptText(context, title: 'Rename workstream', initial: w.title);
                if (title != null && context.mounted) await runCmd(context, ref, renameWorkstreamCmd(w.id, title));
              },
            ),
            if (others.isNotEmpty)
              AntMenu(
                items: [
                  for (final o in others)
                    AntMenuItem(
                      label: 'Merge into ${o.w.title}',
                      icon: Icons.call_merge_rounded,
                      onSelected: () async {
                        final ok = await confirm(
                          context,
                          title: 'Merge workstreams?',
                          message: 'All ${plural(item.factCount, 'fact')} of “${w.title}” move into “${o.w.title}”, '
                              'and “${w.title}” is removed.',
                          action: 'Merge',
                        );
                        if (ok && context.mounted) await runCmd(context, ref, mergeWorkstreamsCmd(w.id, o.w.id));
                      },
                    ),
                ],
                builder: (context, c) => AntIconButton(
                  icon: Icons.call_merge_rounded,
                  tooltip: 'Merge into…',
                  onPressed: () => c.isOpen ? c.close() : c.open(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _WorkstreamFacts extends ConsumerWidget {
  const _WorkstreamFacts({required this.w, required this.all});
  final Workstream w;
  final List<WorkstreamItem> all;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final facts = ref.watch(factsProvider(factQuery(workstreamId: w.id))).value ?? const <FactItem>[];
    return Container(
      color: t.surfaceSunken,
      padding: EdgeInsets.symmetric(horizontal: t.space.xl, vertical: t.space.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (facts.isEmpty) Muted('No live facts in this workstream.'),
          for (final f in facts)
            FactTile(
              item: f,
              showDay: true,
              menu: [
                for (final o in all.where((o) => o.w.id != w.id))
                  AntMenuItem(
                    label: 'Move to ${o.w.title}',
                    icon: Icons.drive_file_move_outline,
                    onSelected: () => runCmd(context, ref, moveFactToWorkstreamCmd(f.f.id, o.w.id)),
                  ),
                AntMenuItem(
                  label: 'Remove from workstream',
                  icon: Icons.remove_circle_outline_rounded,
                  onSelected: () => runCmd(context, ref, moveFactToWorkstreamCmd(f.f.id, null)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
