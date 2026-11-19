/// Settings → Templates (#86): list, duplicate, edit prompt and period kinds, live preview against
/// real data, reset to default. Built-ins are read-only (duplicate to edit).
library;

import 'package:core/core.dart' hide Provider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui/ui.dart';

import '../../engine/setup_commands.dart';
import '../../state/providers.dart';
import 'kit.dart';
import 'setup_providers.dart';

const _kindLabels = {
  PeriodKind.daily: 'Daily',
  PeriodKind.weekly: 'Weekly',
  PeriodKind.monthly: 'Monthly',
  PeriodKind.quarterly: 'Quarterly',
  PeriodKind.custom: 'Custom',
};

List<PeriodKind> _kinds(String s) => [for (final k in s.split(',')) if (k.isNotEmpty) PeriodKind.values.byName(k)];

class TemplatesTab extends ConsumerStatefulWidget {
  const TemplatesTab({super.key});
  @override
  ConsumerState<TemplatesTab> createState() => _TemplatesTabState();
}

class _TemplatesTabState extends ConsumerState<TemplatesTab> {
  String? _selected;
  final _name = TextEditingController();
  final _prompt = TextEditingController();
  Set<PeriodKind> _periods = {};
  bool _dirty = false;
  int? _loadedVersion;

  PeriodKind? _previewKind;
  bool _previewing = false;
  String? _preview;
  String? _previewError;

  @override
  void dispose() {
    _name.dispose();
    _prompt.dispose();
    super.dispose();
  }

  void _load(Template t) {
    _selected = t.id;
    _loadedVersion = t.version;
    _name.text = t.name;
    _prompt.text = t.prompt;
    _periods = _kinds(t.periodKinds).toSet();
    _dirty = false;
    _previewKind = _kinds(t.periodKinds).firstOrNull ?? PeriodKind.weekly;
    _preview = null;
    _previewError = null;
  }

  Future<String?> _save(Template t) async {
    final id = await runCmd(
      context,
      ref,
      updateTemplateCmd(t.id, name: _name.text.trim(), periodKinds: _periods.toList()..sort((a, b) => a.index - b.index), prompt: _prompt.text),
      done: 'Template saved',
    );
    if (id != null) setState(() => _selected = id);
    return id;
  }

  Future<void> _runPreview(Template t) async {
    var id = t.id;
    if (_dirty && !t.builtIn) id = await _save(t) ?? id;
    setState(() {
      _previewing = true;
      _previewError = null;
    });
    try {
      final h = await ref.read(engineProvider.future);
      final md = await h.runtime(previewTemplateCmd(id, _previewKind ?? PeriodKind.weekly));
      if (mounted) setState(() => _preview = md.isEmpty ? 'Nothing to report for this period yet.' : md);
    } catch (e) {
      if (mounted) setState(() => _previewError = errorText(e));
    } finally {
      if (mounted) setState(() => _previewing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final all = ref.watch(templatesProvider).value ?? const <Template>[];
    final current = all.where((x) => x.id == _selected).firstOrNull ?? all.firstOrNull;
    if (current != null && (current.id != _selected || (!_dirty && current.version != _loadedVersion))) {
      _load(current);
    }
    final builtIn = current?.builtIn ?? true;
    final fromBuiltin = current != null && !builtIn && current.id.contains('/');

    return PageBody(
      maxWidth: t.widePage,
      children: [
        Text('Templates shape wording and structure only, never facts.', style: t.typo.small.copyWith(color: t.muted)),
        Gap(t.space.lg),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: t.gridMinTile,
              child: ListPanel(children: [
                for (final x in all)
                  PanelRow(
                    dense: true,
                    onTap: () => setState(() => _load(x)),
                    title: x.name,
                    hint: _kinds(x.periodKinds).map((k) => _kindLabels[k]).join(' · '),
                    leading: Icon(
                      x.id == current?.id ? Icons.radio_button_checked : Icons.description_outlined,
                      size: t.icon.sm,
                      color: x.id == current?.id ? t.accentText : t.muted,
                    ),
                    trailing: [if (x.builtIn) const AntChip(label: 'Built-in')],
                  ),
              ]),
            ),
            SizedBox(width: t.space.xl),
            if (current != null)
              Expanded(
                child: AntCard(
                  padding: EdgeInsets.all(t.space.xxl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (builtIn) ...[
                        Callout(
                          warn: false,
                          child: Text('Built-in templates are read-only. Duplicate one to make it your own.'),
                        ),
                        Gap(t.space.lg),
                      ],
                      AntTextField(
                        controller: _name,
                        label: 'Name',
                        enabled: !builtIn,
                        onChanged: (_) => setState(() => _dirty = true),
                      ),
                      Gap(t.space.lg),
                      Text('Used for', style: t.typo.label.copyWith(color: t.text2)),
                      Gap(t.space.sm),
                      Wrap(spacing: t.space.lg, runSpacing: t.space.sm, children: [
                        for (final k in PeriodKind.values)
                          AntCheckbox(
                            value: _periods.contains(k),
                            label: _kindLabels[k],
                            onChanged: builtIn
                                ? null
                                : (v) => setState(() {
                                      v ? _periods.add(k) : _periods.remove(k);
                                      _dirty = true;
                                    }),
                          ),
                      ]),
                      Gap(t.space.lg),
                      AntTextField(
                        controller: _prompt,
                        label: 'Prompt',
                        mono: true,
                        minLines: 8,
                        maxLines: 16,
                        enabled: !builtIn,
                        onChanged: (_) => setState(() => _dirty = true),
                      ),
                      Hint('Variables: ${const ['period_label', 'period_kind', 'start', 'end'].map((v) => '{$v}').join('  ')}'),
                      Gap(t.space.xl),
                      Row(children: [
                        AntButton(
                          label: 'Duplicate',
                          icon: Icons.copy,
                          onPressed: () async {
                            final id = await runCmd(context, ref, duplicateTemplateCmd(current.id), done: 'Duplicated');
                            if (id != null) setState(() => _selected = id);
                          },
                        ),
                        if (fromBuiltin) ...[
                          SizedBox(width: t.space.md),
                          AntButton.ghost(
                            label: 'Reset to default',
                            onPressed: () async {
                              await runCmd(context, ref, resetTemplateCmd(current.id), done: 'Reset to the built-in');
                              setState(() => _loadedVersion = null);
                            },
                          ),
                        ],
                        if (!builtIn) ...[
                          SizedBox(width: t.space.md),
                          AntButton(
                            label: 'Delete',
                            variant: AntButtonVariant.danger,
                            onPressed: () async {
                              await runCmd(context, ref, deleteTemplateCmd(current.id), done: 'Deleted');
                              setState(() => _selected = null);
                            },
                          ),
                        ],
                        const Spacer(),
                        if (!builtIn)
                          AntButton.primary(label: 'Save', onPressed: _dirty ? () => _save(current) : null),
                      ]),
                      Gap(t.space.xxl),
                      Divider(height: t.stroke.hairline, color: t.divider),
                      Gap(t.space.xl),
                      Row(children: [
                        Expanded(child: Label('Preview', trailing: Text('Generated from your real facts; nothing is saved',
                            style: t.typo.small.copyWith(color: t.muted)))),
                        SelectButton<PeriodKind>(
                          value: _previewKind,
                          options: [for (final k in PeriodKind.values) (k, 'This ${_kindLabels[k]!.toLowerCase()} period')],
                          onChanged: (k) => setState(() => _previewKind = k),
                        ),
                        SizedBox(width: t.space.md),
                        AntButton(
                          label: _previewing ? 'Generating…' : 'Preview',
                          icon: Icons.auto_awesome,
                          onPressed: _previewing ? null : () => _runPreview(current),
                        ),
                      ]),
                      if (_previewError != null) ...[
                        Gap(t.space.md),
                        Text(_previewError!, style: t.typo.small.copyWith(color: t.dangerText)),
                      ],
                      if (_preview != null) ...[
                        Gap(t.space.md),
                        Container(
                          padding: EdgeInsets.all(t.space.xl),
                          decoration: BoxDecoration(
                            color: t.surfaceSunken,
                            borderRadius: t.radii.brLg,
                            border: Border.all(color: t.border, width: t.stroke.hairline),
                          ),
                          child: SelectableText(_preview!, style: t.typo.body.copyWith(color: t.text2)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
