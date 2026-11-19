import 'dart:io';

import 'package:core/core.dart' hide Provider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:ui/ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../engine/commands.dart';
import '../state/data.dart';
import '../state/providers.dart';
import 'common.dart';

/// Absolute path of a blob-store attachment for the active profile.
String? blobPath(WidgetRef ref, String rel) {
  final h = ref.watch(engineProvider).value;
  if (h == null) return null;
  return p.join(ref.watch(engineConfigProvider).dataDir, 'blobs', h.profileId, rel);
}

/// Square kind icon (mockup `.kind`).
class KindIcon extends StatelessWidget {
  const KindIcon(this.kind, {super.key});
  final PayloadKind kind;
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Tooltip(
      message: kindLabel(kind),
      child: Container(
        width: t.density.controlSm,
        height: t.density.controlSm,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: t.chipBg,
          borderRadius: t.radii.brMd,
          border: Border.all(color: t.borderSubtle, width: t.stroke.hairline),
        ),
        child: Icon(kindIcon(kind), size: t.icon.sm, color: kindTint(t, kind)),
      ),
    );
  }
}

/// One evidence row with hover curation actions (star, annotate, hide, more).
class EvidenceRow extends ConsumerWidget {
  const EvidenceRow({super.key, required this.item, this.highlighted = false, this.showDay = false});
  final EvidenceItem item;
  final bool highlighted;

  /// Timeline: prefix the time with nothing (day headers group rows) but show the project dot.
  final bool showDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final e = item.e;
    final projects = ref.watch(allProjectsProvider).value ?? const <Project>[];
    final project = projects.where((x) => x.id == e.projectId).firstOrNull;
    final meta = [
      if (item.sourceName.isNotEmpty) item.sourceName,
      kindLabel(item.kind),
      if (showDay && project != null) project.name,
    ].join(' · ');
    final noteBody = item.noteText;
    return Hover(
      builder: (context, hovered) {
        final row = AnimatedContainer(
          duration: t.motion.fast,
          padding: EdgeInsets.symmetric(horizontal: t.space.md, vertical: t.space.md),
          decoration: BoxDecoration(
            color: highlighted ? t.accentSoft : (hovered ? t.hover : t.hover.withValues(alpha: 0)),
            borderRadius: t.radii.brLg,
            border: Border.all(
              color: highlighted ? antToneBorder(t, AntTone.warn) : t.border.withValues(alpha: 0),
              width: t.stroke.hairline,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              KindIcon(item.kind),
              SizedBox(width: t.space.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            e.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.typo.bodyStrong.copyWith(color: t.text),
                          ),
                        ),
                        if (e.starred) ...[
                          SizedBox(width: t.space.sm),
                          Icon(Icons.star_rounded, size: t.icon.sm, color: t.accent),
                        ],
                        if (e.hidden) ...[
                          SizedBox(width: t.space.sm),
                          const AntChip(label: 'Hidden'),
                        ],
                      ],
                    ),
                    SizedBox(height: t.space.xxs),
                    Row(
                      children: [
                        Flexible(child: Muted(meta, maxLines: 1)),
                        if (item.link != null) ...[
                          SizedBox(width: t.space.sm),
                          _LinkButton(item.link!),
                        ],
                      ],
                    ),
                    if (noteBody != null && noteBody.contains('\n'))
                      Padding(
                        padding: EdgeInsets.only(top: t.space.xs),
                        child: Text(noteBody, style: t.typo.body.copyWith(color: t.text3)),
                      ),
                    for (final a in item.annotations) _Annotation(payloadText(a)),
                    if (item.attachments.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: t.space.sm),
                        child: Wrap(
                          spacing: t.space.sm,
                          runSpacing: t.space.sm,
                          children: [for (final a in item.attachments) _Thumb(a)],
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(width: t.space.md),
              Padding(
                padding: EdgeInsets.only(top: t.space.xs),
                child: Text(hhmm(e.occurredStart), style: t.typo.mono.copyWith(color: t.muted)),
              ),
              SizedBox(width: t.space.xs),
              AnimatedOpacity(
                duration: t.motion.fast,
                opacity: hovered || highlighted ? 1 : 0,
                child: _Actions(item: item, projects: projects),
              ),
            ],
          ),
        );
        return e.hidden && !hovered ? Opacity(opacity: t.stroke.disabledOpacity, child: row) : row;
      },
    );
  }
}

class _LinkButton extends StatelessWidget {
  const _LinkButton(this.url);
  final String url;
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final uri = Uri.tryParse(url);
    return AntInteractive(
      onTap: uri == null ? null : () => launchUrl(uri),
      semanticLabel: 'Open link',
      builder: (context, s) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.link_rounded, size: t.icon.xs, color: s.hovered ? t.accentTextHover : t.accentText),
          SizedBox(width: t.space.xxs),
          Text(
            uri?.host.isNotEmpty == true ? uri!.host : 'link',
            style: t.typo.small.copyWith(color: s.hovered ? t.accentTextHover : t.accentText),
          ),
        ],
      ),
    );
  }
}

/// "Your note · …" box under an evidence row (mockup `.annot`).
class _Annotation extends StatelessWidget {
  const _Annotation(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      margin: EdgeInsets.only(top: t.space.sm),
      padding: EdgeInsets.symmetric(horizontal: t.space.md, vertical: t.space.sm),
      decoration: BoxDecoration(
        color: t.surface2,
        borderRadius: t.radii.brMd,
        border: Border.all(color: t.borderStronger, width: t.stroke.hairline),
      ),
      child: Text.rich(
        TextSpan(children: [
          TextSpan(text: 'Your note · ', style: TextStyle(color: t.muted)),
          TextSpan(text: text),
        ]),
        style: t.typo.small.copyWith(color: t.text3),
      ),
    );
  }
}

class _Thumb extends ConsumerWidget {
  const _Thumb(this.rel);
  final String rel;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final path = blobPath(ref, rel);
    if (path == null) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: t.radii.brMd,
      child: GestureDetector(
        onTap: () => showAntDialog<void>(
          context,
          builder: (ctx) => Center(child: Image.file(File(path), fit: BoxFit.contain)),
        ),
        child: Image.file(
          File(path),
          height: t.space.giant * 2,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}

class _Actions extends ConsumerWidget {
  const _Actions({required this.item, required this.projects});
  final EvidenceItem item;
  final List<Project> projects;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = item.e;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AntIconButton(
          icon: e.starred ? Icons.star_rounded : Icons.star_outline_rounded,
          tooltip: e.starred ? 'Unstar' : 'Star as a win',
          size: AntSize.md,
          selected: e.starred,
          onPressed: () => e.starred
              ? runCmd(context, ref, unstarEvidenceCmd(e.id))
              : runCmd(context, ref, starEvidenceCmd(e.id), ok: 'Starred and added to your Wins log'),
        ),
        AntIconButton(
          icon: Icons.chat_bubble_outline_rounded,
          tooltip: 'Annotate',
          onPressed: () => annotateEvidence(context, ref, e),
        ),
        AntIconButton(
          icon: e.hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          tooltip: e.hidden ? 'Unhide' : 'Hide from the narrative',
          onPressed: () => runCmd(context, ref, setHiddenCmd(e.id, !e.hidden)),
        ),
        AntMenu(
          items: [
            AntMenuItem(
              label: 'Set project…',
              icon: Icons.folder_outlined,
              onSelected: () => _setProject(context, ref),
            ),
            const AntMenuDivider(),
            AntMenuItem(
              label: 'Delete permanently…',
              icon: Icons.delete_outline_rounded,
              danger: true,
              onSelected: () => deleteEvidence(context, ref, e),
            ),
          ],
          builder: (context, c) => AntIconButton(
            icon: Icons.more_horiz_rounded,
            tooltip: 'More',
            onPressed: () => c.isOpen ? c.close() : c.open(),
          ),
        ),
      ],
    );
  }

  Future<void> _setProject(BuildContext context, WidgetRef ref) async {
    final active = projects.where((p) => !p.archived).toList();
    final picked = await showAntDialog<({String? id})>(
      context,
      builder: (ctx) {
        final t = ctx.tokens;
        return AntDialog(
          title: 'Set project',
          body: Wrap(
            spacing: t.space.sm,
            runSpacing: t.space.sm,
            children: [
              AntSelectChip(
                label: 'No project',
                selected: item.e.projectId == null,
                onPressed: () => Navigator.pop(ctx, (id: null)),
              ),
              for (final p in active)
                AntSelectChip(
                  label: p.name,
                  leading: AntDot(color: projectColour(t, p), size: t.space.sm),
                  selected: item.e.projectId == p.id,
                  onPressed: () => Navigator.pop(ctx, (id: p.id)),
                ),
            ],
          ),
          actions: [AntButton.ghost(label: 'Cancel', onPressed: () => Navigator.pop(ctx))],
        );
      },
    );
    if (picked == null || !context.mounted) return;
    await runCmd(context, ref, setEvidenceProjectCmd(item.e.id, picked.id));
  }
}

/// Annotate = add a note payload to existing evidence (#56, #83).
Future<void> annotateEvidence(BuildContext context, WidgetRef ref, Evidence e) async {
  final text = await promptText(
    context,
    title: 'Add a note to “${e.title}”',
    placeholder: 'Context the model should know, e.g. “took 3 days because of flaky CI”',
    action: 'Add note',
    maxLines: 4,
  );
  if (text == null || !context.mounted) return;
  await runCmd(context, ref, addNoteCmd(text: text, at: e.occurredStart, attachTo: e.id), ok: 'Note added');
}

/// "Delete permanently" (#85) with an irreversible-action confirmation.
Future<void> deleteEvidence(BuildContext context, WidgetRef ref, Evidence e) async {
  final ok = await confirm(
    context,
    title: 'Delete permanently?',
    message: '“${e.title}” and everything captured with it (notes, screenshots, summaries) will be removed, '
        'and facts that only cite it are deleted too. This can’t be undone.\n\n'
        'Locked reports and existing backups may still contain it.',
    action: 'Delete permanently',
    danger: true,
  );
  if (!ok || !context.mounted) return;
  await runCmd(context, ref, deleteEvidenceCmd(e.id), ok: 'Deleted');
}
