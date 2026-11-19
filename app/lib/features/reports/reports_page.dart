import 'package:core/core.dart' hide Provider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui/ui.dart';

import '../../engine/commands.dart';
import '../../state/data.dart';
import '../../widgets/common.dart';
import '../../widgets/report_view.dart';

/// Reports (SPEC §8): read-only renderings of the Narrative. List by period kind, create,
/// regenerate with a style instruction, lock/unlock, share.
class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});
  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  var _kind = PeriodKind.weekly;
  String? _selected;
  String? _version; // snapshot id when viewing an older version

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final reports = ref.watch(reportsProvider((kind: _kind, day: null)));
    final list = reports.value ?? const <ReportItem>[];
    final current = list.where((r) => r.r.id == _selected).firstOrNull ?? list.firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TopBar(
          title: 'Reports',
          middle: [
            AntTabs<PeriodKind>(
              value: _kind,
              onChanged: (k) => setState(() {
                _kind = k;
                _selected = null;
                _version = null;
              }),
              tabs: [for (final k in PeriodKind.values) AntTab(value: k, label: periodKindLabel(k))],
            ),
          ],
          actions: [
            AntButton(label: 'New report', icon: Icons.add_rounded, onPressed: () => _create(context)),
          ],
        ),
        Expanded(
          child: reports.hasValue && list.isEmpty
              ? AntEmptyState(
                  icon: Icons.fact_check_outlined,
                  title: 'No ${periodKindLabel(_kind).toLowerCase()} reports yet',
                  message: 'Reports are written from your facts and can’t be edited: to change one, correct a fact '
                      'or add a note, then regenerate. Scheduled reports appear here on their own.',
                  action: AntButton.primary(label: 'Create a report', onPressed: () => _create(context)),
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: t.density.columnMinWidth,
                      decoration: BoxDecoration(
                        border: Border(right: BorderSide(color: t.border, width: t.stroke.hairline)),
                      ),
                      child: ListView(
                        padding: EdgeInsets.symmetric(horizontal: t.space.md, vertical: t.space.lg),
                        children: [
                          for (final r in list)
                            _ReportListItem(
                              item: r,
                              selected: r.r.id == current?.r.id,
                              onTap: () => setState(() {
                                _selected = r.r.id;
                                _version = null;
                              }),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: current == null
                          ? const SizedBox.shrink()
                          : _ReportDetail(
                              key: ValueKey(current.r.id),
                              item: current,
                              version: _version,
                              onVersion: (v) => setState(() => _version = v),
                            ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _create(BuildContext context) async {
    final spec = await showAntDialog<_NewReport>(context, builder: (_) => _NewReportDialog(kind: _kind));
    if (spec == null || !context.mounted) return;
    setState(() => _kind = spec.period.kind);
    final id = await runCmd(
      context,
      ref,
      ensureReportCmd(spec.period.kind, spec.period.start, spec.period.end, spec.templateId),
    );
    if (id == null || !context.mounted) return;
    setState(() {
      _selected = id;
      _version = null;
    });
    await generateReport(context, ref, reportId: id);
  }
}

class _ReportListItem extends StatelessWidget {
  const _ReportListItem({required this.item, required this.selected, required this.onTap});
  final ReportItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final s = item.latest;
    return AntInteractive(
      onTap: onTap,
      selected: selected,
      semanticLabel: periodLabel(item.period),
      builder: (context, st) => AnimatedContainer(
        duration: t.motion.fast,
        margin: EdgeInsets.only(bottom: t.space.xxs),
        padding: EdgeInsets.symmetric(horizontal: t.space.md, vertical: t.space.md),
        decoration: BoxDecoration(
          color: selected ? t.active : (st.hovered ? t.hover : t.hover.withValues(alpha: 0)),
          borderRadius: t.radii.brMd,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(periodLabel(item.period),
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: t.typo.bodyStrong.copyWith(color: t.text)),
              ),
              if (item.r.locked) Icon(Icons.lock_rounded, size: t.icon.xs, color: t.muted),
            ]),
            Muted(
              [
                item.template?.name ?? item.r.templateId,
                s == null ? 'not generated' : 'v${s.version} · ${shortDayLabel(dayOf(s.generatedAt, s.generatedAt.toLocal().timeZoneOffset))}',
              ].join(' · '),
              maxLines: 1,
              style: t.typo.chip,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportDetail extends ConsumerWidget {
  const _ReportDetail({super.key, required this.item, required this.version, required this.onVersion});
  final ReportItem item;
  final String? version;
  final ValueChanged<String?> onVersion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final r = item.r;
    final generating = ref.watch(generatingProvider).contains(r.id);
    final shown = item.snapshots.where((s) => s.id == version).firstOrNull ?? item.shown;
    final title = '${item.template?.name ?? 'Report'} · ${periodLabel(item.period)}';
    return ListView(
      padding: EdgeInsets.fromLTRB(t.space.huge, t.space.xxl, t.space.huge, t.space.giant),
      children: [
        Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: t.density.contentMaxWidth - t.space.giant * 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: t.space.md,
                  runSpacing: t.space.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(periodLabel(item.period), style: t.typo.heading.copyWith(color: t.text)),
                    ReportStatusChip(item),
                  ],
                ),
                SizedBox(height: t.space.xs),
                Muted('${item.template?.name ?? r.templateId} · ${item.period.start} to ${item.period.end}'),
                SizedBox(height: t.space.lg),
                Wrap(
                  spacing: t.space.sm,
                  runSpacing: t.space.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    RegenerateButton(
                      label: item.latest == null ? 'Generate' : 'Regenerate',
                      enabled: !generating && !r.locked,
                      onRegenerate: (style) => generateReport(context, ref, reportId: r.id, style: style),
                    ),
                    if (item.latest != null)
                      AntButton(
                        label: r.locked ? 'Unlock' : 'Lock',
                        icon: r.locked ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                        onPressed: generating
                            ? null
                            : () => runCmd(
                                  context,
                                  ref,
                                  r.locked ? unlockReportCmd(r.id) : lockReportCmd(r.id),
                                  ok: r.locked ? 'Unlocked. It can be regenerated again.' : 'Locked. It won’t be regenerated.',
                                ),
                      ),
                    if (shown != null) ShareButton(markdown: shown.markdown, fileName: title),
                  ],
                ),
                if (r.locked)
                  Padding(
                    padding: EdgeInsets.only(top: t.space.md),
                    child: Muted('Locked: a frozen snapshot. Unlock to regenerate it from the current facts.'),
                  ),
                SizedBox(height: t.space.xxl),
                if (generating)
                  const GeneratingPlaceholder()
                else if (shown == null)
                  Panel(
                    padding: EdgeInsets.all(t.space.xxl),
                    child: Column(children: [
                      Text('Nothing generated for this period yet', style: t.typo.bodyStrong.copyWith(color: t.text)),
                      SizedBox(height: t.space.xs),
                      Muted('Generate it from the facts in ${periodLabel(item.period)}.'),
                    ]),
                  )
                else
                  ReportProse(markdown: shown.markdown),
                if (item.snapshots.isNotEmpty) ...[
                  SizedBox(height: t.space.xxl),
                  Row(children: [
                    Icon(Icons.history_rounded, size: t.icon.sm, color: t.muted),
                    SizedBox(width: t.space.sm),
                    Expanded(
                      child: Muted(
                        shown == null
                            ? ''
                            : [
                                'Version ${shown.version} of ${item.snapshots.length}',
                                'generated ${shortDayLabel(dayOf(shown.generatedAt, shown.generatedAt.toLocal().timeZoneOffset))} '
                                    '${hhmm(shown.generatedAt)}',
                                shown.modelId,
                                if (shown.styleInstruction != null) 'style “${shown.styleInstruction}”',
                              ].join(' · '),
                        style: t.typo.chip,
                      ),
                    ),
                    if (item.snapshots.length > 1)
                      AntSelect<String?>(
                        value: version,
                        semanticLabel: 'Version',
                        options: [
                          AntOption(null, r.locked ? 'Locked version' : 'Latest'),
                          for (final s in item.snapshots) AntOption(s.id, 'Version ${s.version}'),
                        ],
                        onChanged: onVersion,
                      ),
                  ]),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _NewReport {
  _NewReport(this.period, this.templateId);
  final Period period;
  final String templateId;
}

class _NewReportDialog extends ConsumerStatefulWidget {
  const _NewReportDialog({required this.kind});
  final PeriodKind kind;
  @override
  ConsumerState<_NewReportDialog> createState() => _NewReportDialogState();
}

class _NewReportDialogState extends ConsumerState<_NewReportDialog> {
  late var _kind = widget.kind;
  var _day = todayDay();
  var _end = todayDay();
  String? _templateId;

  Period get _period => _kind == PeriodKind.custom
      ? Period.custom(_day.compareTo(_end) <= 0 ? _day : _end, _day.compareTo(_end) <= 0 ? _end : _day)
      : Period.containing(_kind, _day);

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final templates = (ref.watch(templatesProvider).value ?? const <Template>[])
        .where((tp) => tp.periodKinds.split(',').contains(_kind.name))
        .toList();
    final tid = templates.any((tp) => tp.id == _templateId)
        ? _templateId
        : (templates.where((tp) => tp.id == defaultTemplateFor[_kind]).firstOrNull ?? templates.firstOrNull)?.id;
    Widget dayButton(String label, String value, ValueChanged<String> set) => AntButton(
          label: '$label${shortDayLabel(value)}',
          icon: Icons.calendar_today_outlined,
          onPressed: () async {
            final d = await pickDay(context, value);
            if (d != null) setState(() => set(d));
          },
        );
    return AntDialog(
      title: 'New report',
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader('Period'),
          Wrap(
            spacing: t.space.sm,
            runSpacing: t.space.sm,
            children: [
              for (final k in PeriodKind.values)
                AntSelectChip(label: periodKindLabel(k), selected: k == _kind, onPressed: () => setState(() => _kind = k)),
            ],
          ),
          SizedBox(height: t.space.md),
          Wrap(
            spacing: t.space.sm,
            runSpacing: t.space.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              dayButton(_kind == PeriodKind.custom ? 'From ' : 'Containing ', _day, (d) => _day = d),
              if (_kind == PeriodKind.custom) dayButton('To ', _end, (d) => _end = d),
              Muted(periodLabel(_period)),
            ],
          ),
          SizedBox(height: t.space.xl),
          const SectionHeader('Template'),
          Wrap(
            spacing: t.space.sm,
            runSpacing: t.space.sm,
            children: [
              for (final tp in templates)
                AntSelectChip(label: tp.name, selected: tp.id == tid, onPressed: () => setState(() => _templateId = tp.id)),
            ],
          ),
        ],
      ),
      actions: [
        AntButton.ghost(label: 'Cancel', onPressed: () => Navigator.pop(context)),
        AntButton.primary(
          label: 'Create and generate',
          onPressed: tid == null ? null : () => Navigator.pop(context, _NewReport(_period, tid)),
        ),
      ],
    );
  }
}
