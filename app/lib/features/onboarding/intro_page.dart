/// The Welcome step (SPEC §10 Onboarding): what Ant Manager is and how it works.
/// The stages reuse the sidebar's icons, so the explanation maps onto the app you land in.
library;

import 'package:flutter/material.dart';
import 'package:ui/ui.dart';

import '../../shell/shell_state.dart';
import '../settings/kit.dart';

const _stages = [
  (ShellSection.sources, 'Sources', 'Git repos, GitHub, GitLab, calendars, tickets and your own notes.'),
  (ShellSection.timeline, 'Evidence', 'Every commit, review, meeting and note lands on your timeline, kept as it was.'),
  (
    ShellSection.narrative,
    'Narrative',
    'A model turns evidence into facts about what you did, each one citing its evidence.',
  ),
  (
    ShellSection.reports,
    'Reports and wins',
    'Daily to quarterly reports and a wins list for reviews, written from those facts.',
  ),
];

const _principles = [
  (Icons.lock_outline_rounded, 'Local first', 'Your data stays on this computer unless you choose a cloud model.'),
  (Icons.link_rounded, 'Always cited', 'Every line in a report links back to the work behind it.'),
  (Icons.edit_outlined, 'Yours to correct', 'Edit or reject any fact. The model never overwrites your changes.'),
];

/// Body of the Welcome step, below the step heading.
List<Widget> introBody(BuildContext context) {
  final t = context.tokens;
  return [
    const AntSectionLabel('How it works'),
    Gap(t.space.xs),
    ListPanel(
      children: [
        for (final (section, title, body) in _stages)
          PanelRow(
            leading: Glyph(title, icon: section.icon),
            title: title,
            hint: body,
          ),
      ],
    ),
    Gap(t.space.xxxl),
    for (final (icon, title, body) in _principles)
      Padding(
        padding: EdgeInsets.only(bottom: t.space.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(top: t.space.xxs),
              child: Icon(icon, size: t.icon.sm, color: t.accentText),
            ),
            SizedBox(width: t.space.md),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '$title. ',
                      style: t.typo.bodyStrong.copyWith(color: t.text),
                    ),
                    TextSpan(text: body),
                  ],
                ),
                style: t.typo.body.copyWith(color: t.muted),
              ),
            ),
          ],
        ),
      ),
  ];
}
