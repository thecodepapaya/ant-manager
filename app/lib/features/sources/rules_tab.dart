/// Curation rules editor (#60): hide matching evidence or set its importance in bulk.
library;

import 'dart:convert';

import 'package:core/core.dart' hide Provider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui/ui.dart';

import '../../engine/setup_commands.dart';
import '../settings/kit.dart';
import '../settings/setup_providers.dart';

/// Rule actions offered in the editor: hide, or an importance weight.
enum RuleEffect {
  hide('Hide', CurationAction.hide, 0),
  low('Low importance', CurationAction.setImportance, 0.2),
  high('High importance', CurationAction.setImportance, 0.9);

  const RuleEffect(this.label, this.action, this.value);
  final String label;
  final CurationAction action;
  final double value;

  static RuleEffect of(CurationRule r) => r.action == CurationAction.hide ? hide : (r.value >= 0.5 ? high : low);
}

const _sourceLabels = <SourceKind?, String>{
  null: 'Any source',
  SourceKind.gitRepo: 'Local git',
  SourceKind.github: 'GitHub',
  SourceKind.gitlab: 'GitLab',
  SourceKind.googleCalendar: 'Google Calendar',
  SourceKind.appleCalendar: 'Apple Calendar',
  SourceKind.ics: 'ICS / Outlook',
  SourceKind.linear: 'Linear',
  SourceKind.jira: 'Jira',
};

class RulesTab extends ConsumerStatefulWidget {
  const RulesTab({super.key});
  @override
  ConsumerState<RulesTab> createState() => _RulesTabState();
}

class _RulesTabState extends ConsumerState<RulesTab> {
  final _pattern = TextEditingController();
  SourceKind? _source;
  RuleEffect _effect = RuleEffect.hide;

  @override
  void dispose() {
    _pattern.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final pattern = _pattern.text.trim();
    if (pattern.isEmpty) return;
    await runCmd(
      context,
      ref,
      saveCurationRuleCmd(titlePattern: pattern, sourceKind: _source, action: _effect.action, value: _effect.value),
    );
    _pattern.clear();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final rules = ref.watch(curationRulesProvider).value ?? const <CurationRule>[];
    return PageBody(
      maxWidth: t.narrowPage,
      children: [
        Label('Curation rules'),
        Gap(t.space.sm),
        Text(
          'Rules weigh whole groups of evidence, e.g. hide “Lunch” or treat “Daily sync” as low importance. '
          'Titles match as text, or as a pattern with * and ?. Starring or hiding a single item always wins.',
          style: t.typo.small.copyWith(color: t.muted),
        ),
        Gap(t.space.lg),
        ListPanel(children: [
          if (rules.isEmpty) const PanelRow(title: 'No rules yet', hint: 'Most people never need one.'),
          for (final r in rules) _RuleRow(r),
          Padding(
            padding: EdgeInsets.all(t.space.lg),
            child: Row(
              children: [
                Expanded(
                  child: AntTextField(controller: _pattern, placeholder: 'Title contains… (e.g. Lunch)', onSubmitted: (_) => _add()),
                ),
                SizedBox(width: t.space.md),
                SelectButton<SourceKind?>(
                  value: _source,
                  options: [for (final e in _sourceLabels.entries) (e.key, e.value)],
                  onChanged: (v) => setState(() => _source = v),
                ),
                SizedBox(width: t.space.md),
                SelectButton<RuleEffect>(
                  value: _effect,
                  options: [for (final e in RuleEffect.values) (e, e.label)],
                  onChanged: (v) => setState(() => _effect = v),
                ),
                SizedBox(width: t.space.md),
                AntButton(label: 'Add rule', icon: Icons.add, onPressed: _add),
              ],
            ),
          ),
        ]),
      ],
    );
  }
}

class _RuleRow extends ConsumerWidget {
  const _RuleRow(this.r);
  final CurationRule r;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = jsonDecode(r.match) as Map<String, Object?>;
    final kind = m['sourceKind'] is String ? SourceKind.values.asNameMap()[m['sourceKind']] : null;
    final effect = RuleEffect.of(r);
    return PanelRow(
      dense: true,
      title: '“${m['titlePattern'] ?? '*'}”',
      hint: _sourceLabels[kind] ?? kind?.name,
      trailing: [
        AntChip(label: effect.label, tone: effect == RuleEffect.hide ? AntTone.neutral : AntTone.info),
        AntSwitch(
          value: r.enabled,
          semanticLabel: 'Rule enabled',
          onChanged: (v) => runCmd(context, ref, setCurationRuleEnabledCmd(r.id, v)),
        ),
        AntIconButton(
          icon: Icons.close,
          tooltip: 'Delete rule',
          size: AntSize.sm,
          onPressed: () => runCmd(context, ref, deleteCurationRuleCmd(r.id)),
        ),
      ],
    );
  }
}
