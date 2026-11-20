/// The Welcome step (SPEC §10 Onboarding): what Ant Manager is and how it works, kept sparse.
/// The stages reuse the sidebar's icons, so the explanation maps onto the app you land in.
library;

import 'package:flutter/material.dart';
import 'package:ui/ui.dart';

import '../../shell/shell_state.dart';
import '../settings/kit.dart' show Gap;

const _stages = [
  (ShellSection.sources, 'Sources'),
  (ShellSection.timeline, 'Evidence'),
  (ShellSection.narrative, 'Narrative'),
  (ShellSection.reports, 'Reports and wins'),
];

/// Body of the Welcome step, below the step heading: one row of stages and one line of principles.
List<Widget> introBody(BuildContext context) {
  final t = context.tokens;
  return [
    Wrap(
      spacing: t.space.md,
      runSpacing: t.space.md,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final (i, (section, label)) in _stages.indexed) ...[
          if (i > 0) Icon(Icons.arrow_forward_rounded, size: t.icon.sm, color: t.muted),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(section.icon, size: t.icon.md, color: t.accentText),
            SizedBox(width: t.space.sm),
            Text(label, style: t.typo.bodyStrong.copyWith(color: t.text)),
          ]),
        ],
      ],
    ),
    Gap(t.space.xxxl),
    Row(children: [
      Icon(Icons.lock_outline_rounded, size: t.icon.sm, color: t.muted),
      SizedBox(width: t.space.md),
      Expanded(
        child: Text(
          'Stays on this computer unless you pick a cloud model. Every line cites the work behind it.',
          style: t.typo.small.copyWith(color: t.muted),
        ),
      ),
    ]),
  ];
}
