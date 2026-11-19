import 'package:core/core.dart' hide Provider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui/ui.dart';

import '../engine/commands.dart';
import '../state/data.dart';
import 'common.dart';

String citationLabel(CitationRef c) {
  final s = c.title.trim();
  return s.length <= 22 ? s : '${s.substring(0, 21)}…';
}

/// Citation chips for a fact. Tapping one highlights its evidence ([onCitation], default: open in Today).
class CitationChips extends ConsumerWidget {
  const CitationChips(this.citations, {super.key, this.onCitation, this.highlighted = const {}});
  final List<CitationRef> citations;
  final void Function(CitationRef c)? onCitation;
  final Set<String> highlighted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    return Wrap(
      spacing: t.space.xs,
      runSpacing: t.space.xs,
      children: [
        for (final c in citations)
          AntCitationChip(
            label: citationLabel(c),
            tooltip: '${kindLabel(c.kind)} · ${shortDayLabel(c.day)}\n${c.title}',
            highlighted: highlighted.contains(c.evidenceId),
            onPressed: () => onCitation != null ? onCitation!(c) : openEvidenceInToday(ref, c.day, {c.evidenceId}),
          ),
      ],
    );
  }
}

/// One Narrative fact: type, statement, citations, inferred/confirmed label, confirm/edit/reject.
class FactTile extends ConsumerWidget {
  const FactTile({
    super.key,
    required this.item,
    this.onCitation,
    this.showDay = false,
    this.menu = const [],
    this.highlightedEvidence = const {},
  });
  final FactItem item;
  final void Function(CitationRef c)? onCitation;
  final bool showDay;

  /// Extra entries for the "more" menu (e.g. move to workstream).
  final List<AntMenuEntry> menu;
  final Set<String> highlightedEvidence;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final f = item.f;
    final basis = f.type == FactType.timeAllocation
        ? (f.details.contains('"measured"') ? 'Measured' : 'Estimated')
        : null;
    final day = f.periodStart == f.periodEnd
        ? shortDayLabel(f.periodStart)
        : '${shortDayLabel(f.periodStart)} – ${shortDayLabel(f.periodEnd)}';
    return Hover(
      builder: (context, hovered) => AnimatedContainer(
        duration: t.motion.fast,
        padding: EdgeInsets.symmetric(horizontal: t.space.md, vertical: t.space.md),
        decoration: BoxDecoration(
          color: hovered ? t.hover : t.hover.withValues(alpha: 0),
          borderRadius: t.radii.brLg,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: t.space.sm,
                    runSpacing: t.space.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      AntChip(label: factTypeLabel(f.type), tone: factTypeTone(f.type)),
                      if (f.winStatus == WinStatus.accepted)
                        const AntChip(label: 'Win', tone: AntTone.warn, icon: Icons.star_rounded),
                      if (f.winStatus == WinStatus.suggested)
                        const AntChip(label: 'Suggested win', tone: AntTone.warn),
                      if (f.reviewState == ReviewState.needsReview) const AntChip(label: 'Needs review', tone: AntTone.warn),
                      _OriginLabel(f.origin),
                      if (basis != null) Muted('· $basis', style: t.typo.caption),
                      if (showDay) Muted('· $day', style: t.typo.caption),
                    ],
                  ),
                  SizedBox(height: t.space.sm),
                  Text(f.statement, style: t.typo.body.copyWith(color: t.text2)),
                  if (item.citations.isNotEmpty) ...[
                    SizedBox(height: t.space.sm),
                    CitationChips(item.citations, onCitation: onCitation, highlighted: highlightedEvidence),
                  ],
                ],
              ),
            ),
            SizedBox(width: t.space.sm),
            AnimatedOpacity(
              duration: t.motion.fast,
              opacity: hovered ? 1 : 0,
              child: FactActions(f: f, menu: menu),
            ),
          ],
        ),
      ),
    );
  }
}

class _OriginLabel extends StatelessWidget {
  const _OriginLabel(this.origin);
  final FactOrigin origin;
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final confirmed = origin != FactOrigin.inferred;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          confirmed ? Icons.verified_outlined : Icons.auto_awesome_outlined,
          size: t.icon.xs,
          color: confirmed ? t.successText : t.muted,
        ),
        SizedBox(width: t.space.xs),
        Text(originLabel(origin), style: t.typo.caption.copyWith(color: confirmed ? t.successText : t.muted)),
      ],
    );
  }
}

/// Confirm / edit / reject (+ extra menu) for a fact.
class FactActions extends ConsumerWidget {
  const FactActions({super.key, required this.f, this.menu = const []});
  final Fact f;
  final List<AntMenuEntry> menu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (f.origin == FactOrigin.inferred)
          AntIconButton(
            icon: Icons.check_rounded,
            tooltip: 'Confirm',
            onPressed: () => runCmd(context, ref, confirmFactCmd(f.id), ok: 'Fact confirmed'),
          ),
        AntIconButton(icon: Icons.edit_outlined, tooltip: 'Edit', onPressed: () => editFact(context, ref, f)),
        AntIconButton(icon: Icons.close_rounded, tooltip: 'Reject', onPressed: () => rejectFact(context, ref, f)),
        if (menu.isNotEmpty)
          AntMenu(
            items: menu,
            builder: (context, c) => AntIconButton(
              icon: Icons.more_horiz_rounded,
              tooltip: 'More',
              onPressed: () => c.isOpen ? c.close() : c.open(),
            ),
          ),
      ],
    );
  }
}

Future<void> editFact(BuildContext context, WidgetRef ref, Fact f) async {
  final s = await promptText(context, title: 'Edit fact', initial: f.statement, maxLines: 4);
  if (s == null || s == f.statement || !context.mounted) return;
  await runCmd(context, ref, editFactCmd(f.id, s), ok: 'Fact updated. Unlocked reports will follow.');
}

Future<void> rejectFact(BuildContext context, WidgetRef ref, Fact f) async {
  final ok = await confirm(
    context,
    title: 'Reject this fact?',
    message: '“${f.statement}”\n\nIt leaves the Narrative and won’t be suggested again. Regenerate reports to drop it.',
    action: 'Reject',
    danger: true,
  );
  if (!ok || !context.mounted) return;
  await runCmd(context, ref, rejectFactCmd(f.id), ok: 'Fact rejected');
}
