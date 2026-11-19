import 'package:core/core.dart' hide Provider, Notifier;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui/ui.dart';

import '../engine/commands.dart';
import '../features/reports/share.dart';
import '../platform/rich_clipboard.dart';
import '../state/data.dart';
import 'common.dart';
import 'fact_tile.dart';

/// Reports currently being generated (shared by Today and Reports).
final generatingProvider = NotifierProvider<Generating, Set<String>>(Generating.new);

class Generating extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};
  void start(String id) => state = {...state, id};
  void stop(String id) => state = {...state}..remove(id);
}

/// Ensures the report exists, then generates a new snapshot with an optional style instruction (#66).
Future<void> generateReport(
  BuildContext context,
  WidgetRef ref, {
  String? reportId,
  PeriodKind? kind,
  String? start,
  String? end,
  String? templateId,
  String? style,
}) async {
  final id = reportId ??
      await runCmd(context, ref, ensureReportCmd(kind!, start!, end!, templateId ?? defaultTemplateFor[kind]!));
  if (id == null || !context.mounted) return;
  final gen = ref.read(generatingProvider.notifier);
  gen.start(id);
  try {
    await runCmd(context, ref, generateReportCmd(id, styleInstruction: style), ok: 'Report generated');
  } finally {
    gen.stop(id);
  }
}

/// "Regenerate" with an optional style instruction (mockup regenerate popover).
class RegenerateButton extends StatelessWidget {
  const RegenerateButton({super.key, required this.onRegenerate, this.label = 'Regenerate', this.enabled = true});
  final void Function(String? style) onRegenerate;
  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AntPopover(
      width: t.density.columnMinWidth + t.space.huge,
      anchorBuilder: (context, c) => AntButton(
        label: label,
        icon: Icons.refresh_rounded,
        onPressed: enabled ? c.toggle : null,
      ),
      contentBuilder: (context, c) => _RegenerateForm(onSubmit: (s) {
        c.hide();
        onRegenerate(s);
      }, onCancel: c.hide),
    );
  }
}

class _RegenerateForm extends StatefulWidget {
  const _RegenerateForm({required this.onSubmit, required this.onCancel});
  final void Function(String? style) onSubmit;
  final VoidCallback onCancel;
  @override
  State<_RegenerateForm> createState() => _RegenerateFormState();
}

class _RegenerateFormState extends State<_RegenerateForm> {
  final _c = TextEditingController();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _submit() {
    final s = _c.text.trim();
    widget.onSubmit(s.isEmpty ? null : s);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AntTextField(
          controller: _c,
          autofocus: true,
          label: 'Style instruction (optional)',
          placeholder: 'e.g. shorter, less jargon, more impact',
          onSubmitted: (_) => _submit(),
        ),
        SizedBox(height: t.space.md),
        Wrap(
          spacing: t.space.sm,
          runSpacing: t.space.sm,
          children: [
            for (final s in const ['Shorter', 'More impact', 'Less jargon'])
              AntSelectChip(label: s, selected: false, onPressed: () => setState(() => _c.text = s.toLowerCase())),
          ],
        ),
        SizedBox(height: t.space.sm),
        Muted('Changes wording only. To change what it says, correct facts or add notes.', style: t.typo.caption),
        SizedBox(height: t.space.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            AntButton.ghost(label: 'Cancel', onPressed: widget.onCancel),
            SizedBox(width: t.space.sm),
            AntButton.primary(label: 'Regenerate', onPressed: _submit),
          ],
        ),
      ],
    );
  }
}

/// Share menu: Markdown, Slack, rich text, PDF.
class ShareButton extends StatelessWidget {
  const ShareButton({super.key, required this.markdown, required this.fileName});
  final String markdown;
  final String fileName;

  @override
  Widget build(BuildContext context) {
    final toasts = AntToastHost.of(context);
    final r = ParsedReport.parse(markdown);
    Future<void> copy(String what, Future<void> Function() f) async {
      await f();
      toasts.show('Copied as $what', tone: AntTone.ok);
    }

    return AntMenu(
      items: [
        AntMenuItem(
          label: 'Copy for Slack',
          icon: Icons.tag_rounded,
          onSelected: () => copy('Slack text', () => Clipboard.setData(ClipboardData(text: r.toSlack()))),
        ),
        AntMenuItem(
          label: 'Copy as rich text',
          icon: Icons.text_fields_rounded,
          onSelected: () => copy('rich text', () => RichClipboard.setHtml(r.toHtml(), r.toMarkdown())),
        ),
        AntMenuItem(
          label: 'Copy as Markdown',
          icon: Icons.code_rounded,
          onSelected: () => copy('Markdown', () => Clipboard.setData(ClipboardData(text: r.toMarkdown()))),
        ),
        const AntMenuDivider(),
        AntMenuItem(
          label: 'Export PDF…',
          icon: Icons.picture_as_pdf_outlined,
          onSelected: () async {
            try {
              final path = await exportPdf(r, '$fileName.pdf');
              if (path != null) toasts.show('Saved $path', tone: AntTone.ok);
            } catch (e) {
              toasts.show('Couldn’t export PDF: $e', tone: AntTone.err);
            }
          },
        ),
      ],
      builder: (context, c) => AntButton.primary(
        label: 'Share',
        icon: Icons.ios_share_rounded,
        onPressed: () => c.isOpen ? c.close() : c.open(),
      ),
    );
  }
}

/// Read-only rendering of a report snapshot: sections, bullets with citation chips, footnotes
/// linked to facts (tap to see / correct the fact).
class ReportProse extends ConsumerWidget {
  const ReportProse({super.key, required this.markdown, this.showTitle = false});
  final String markdown;
  final bool showTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final r = ParsedReport.parse(markdown);
    final prose = t.typo.prose.copyWith(color: t.text2);
    void open(int n) {
      final f = r.footnotes[n];
      if (f != null) showFactDialog(context, f.factId);
    }

    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showTitle) Text(r.title, style: t.typo.heading.copyWith(color: t.text)),
          if (r.emptyNote != null)
            Padding(padding: EdgeInsets.only(top: t.space.md), child: Muted(r.emptyNote!, style: prose)),
          for (final s in r.sections) ...[
            if (s.heading.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: t.space.xl, bottom: t.space.sm),
                child: Text(s.heading, style: t.typo.label.copyWith(color: t.text)),
              ),
            for (final i in s.items)
              Padding(
                padding: EdgeInsets.symmetric(vertical: t.space.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: t.space.lg, child: Text('•', style: prose.copyWith(color: t.muted))),
                    Expanded(
                      child: Text.rich(
                        TextSpan(children: [
                          TextSpan(text: '${i.text} '),
                          for (final n in i.notes)
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: t.space.xxs),
                                child: AntCitationChip(
                                  label: '$n',
                                  tooltip: r.footnotes[n]?.statement,
                                  onPressed: () => open(n),
                                ),
                              ),
                            ),
                        ]),
                        style: prose,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (r.footnotes.isNotEmpty) ...[
            Padding(
              padding: EdgeInsets.only(top: t.space.xxl, bottom: t.space.sm),
              child: Divider(color: t.divider, height: t.stroke.hairline),
            ),
            for (final f in r.footnotes.values)
              AntInteractive(
                onTap: () => open(f.n),
                semanticLabel: 'Fact ${f.n}',
                builder: (context, s) => Padding(
                  padding: EdgeInsets.symmetric(vertical: t.space.xxs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: t.space.xxxl,
                        child: Text('${f.n}', style: t.typo.monoSmall.copyWith(color: t.muted)),
                      ),
                      Expanded(
                        child: Text(
                          f.statement,
                          style: t.typo.small.copyWith(color: s.hovered ? t.accentText : t.muted),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// A fact with its citations and confirm/edit/reject (report footnotes link here).
Future<void> showFactDialog(BuildContext context, String factId) => showAntDialog<void>(
      context,
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final t = ctx.tokens;
          final item = ref.watch(factByIdProvider(factId)).value;
          return AntDialog(
            title: 'Fact',
            body: item == null
                ? const Text('This fact no longer exists (its evidence was deleted).')
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FactTile(
                        item: item,
                        showDay: true,
                        flush: true,
                        onCitation: (c) {
                          Navigator.pop(ctx);
                          openEvidenceInToday(ref, c.day, {c.evidenceId});
                        },
                      ),
                      if (item.f.retired) ...[
                        SizedBox(height: t.space.sm),
                        const AntChip(label: 'Rejected or retired since this report', tone: AntTone.err),
                      ],
                    ],
                  ),
            actions: [AntButton(label: 'Close', onPressed: () => Navigator.pop(ctx))],
          );
        },
      ),
    );

/// Status chip for a report: Locked / Facts changed since lock / Out of date / Up to date / Not generated.
class ReportStatusChip extends ConsumerWidget {
  const ReportStatusChip(this.item, {super.key});
  final ReportItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shown = item.shown;
    if (ref.watch(generatingProvider).contains(item.r.id)) {
      return const AntChip(label: 'Generating…', tone: AntTone.info);
    }
    if (shown == null) return const AntChip(label: 'Not generated');
    final stale = ref.watch(snapshotStaleProvider(shown.id)).value ?? false;
    if (item.r.locked) {
      return stale
          ? const AntChip(label: 'Locked · facts changed since lock', tone: AntTone.warn, icon: Icons.lock_rounded)
          : const AntChip(label: 'Locked', icon: Icons.lock_rounded);
    }
    return stale ? const AntChip(label: 'Out of date', tone: AntTone.warn) : const AntChip(label: 'Up to date', tone: AntTone.ok);
  }
}

/// Skeleton shown while a report is being written.
class GeneratingPlaceholder extends StatelessWidget {
  const GeneratingPlaceholder({super.key});
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    Widget bar(double f) => FractionallySizedBox(
          widthFactor: f,
          child: Container(
            height: t.space.md,
            margin: EdgeInsets.only(top: t.space.md),
            decoration: BoxDecoration(color: t.border, borderRadius: t.radii.brXs),
          ),
        );
    return Panel(
      padding: EdgeInsets.all(t.space.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            SizedBox(
              width: t.icon.sm,
              height: t.icon.sm,
              child: CircularProgressIndicator(strokeWidth: t.stroke.focus, color: t.accentText),
            ),
            SizedBox(width: t.space.md),
            Text('Writing from your facts…', style: t.typo.label.copyWith(color: t.accentText)),
          ]),
          bar(0.8),
          bar(0.64),
        ],
      ),
    );
  }
}
