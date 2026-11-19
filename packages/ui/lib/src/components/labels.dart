import 'package:flutter/material.dart';

import '../tokens/ant_tokens.dart';
import 'interactive.dart';
import 'tooltip.dart';

/// Semantic tone for chips and badges.
enum AntTone { neutral, ok, warn, err, info, accent }

({Color bg, Color fg}) antToneColors(AntTokens t, AntTone tone) =>
    switch (tone) {
      AntTone.neutral => (bg: t.chipBg, fg: t.textSoft),
      AntTone.ok => (bg: t.successSoft, fg: t.successText),
      AntTone.warn => (bg: t.accentSoft, fg: t.accentText),
      AntTone.err => (bg: t.dangerSoft, fg: t.dangerText),
      AntTone.info => (bg: t.infoSoft, fg: t.info),
      AntTone.accent => (bg: t.accent, fg: t.onAccent),
    };

/// Chip border for [tone] (mockup: neutral uses `--border-subtle`, tints
/// use their hue at 30%).
Color antToneBorder(AntTokens t, AntTone tone) => switch (tone) {
  AntTone.neutral => t.borderSubtle,
  AntTone.ok => t.success.withValues(alpha: 0.3),
  AntTone.warn => t.accent.withValues(alpha: 0.3),
  AntTone.err => t.danger.withValues(alpha: 0.3),
  AntTone.info => t.info.withValues(alpha: 0.3),
  AntTone.accent => t.accent,
};

/// Small status label: "Synced", "Stale", "Failed"...
class AntChip extends StatelessWidget {
  const AntChip({
    super.key,
    required this.label,
    this.tone = AntTone.neutral,
    this.icon,
  });

  final String label;
  final AntTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = antToneColors(t, tone);
    return Container(
      height: t.density.chipHeight,
      padding: EdgeInsets.symmetric(horizontal: t.space.md),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: t.radii.brSm,
        border: Border.all(color: antToneBorder(t, tone), width: t.stroke.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: t.icon.xs, color: c.fg),
            SizedBox(width: t.space.xs),
          ],
          Text(label, style: t.typo.chip.copyWith(color: c.fg)),
        ],
      ),
    );
  }
}

/// Count or dot indicator.
class AntBadge extends StatelessWidget {
  const AntBadge({
    super.key,
    required int this.count,
    this.tone = AntTone.accent,
  });

  /// A bare dot (e.g. "unread").
  const AntBadge.dot({super.key, this.tone = AntTone.accent}) : count = null;

  final int? count;
  final AntTone tone;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = antToneColors(t, tone);
    final dotColor = tone == AntTone.accent ? t.accent : c.fg;
    if (count == null) {
      return Semantics(
        label: 'indicator',
        child: Container(
          width: t.space.sm,
          height: t.space.sm,
          decoration: BoxDecoration(
            color: dotColor,
            borderRadius: t.radii.brPill,
          ),
        ),
      );
    }
    return Container(
      constraints: BoxConstraints(minWidth: t.icon.md),
      padding: EdgeInsets.symmetric(horizontal: t.space.xs),
      alignment: Alignment.center,
      height: t.icon.md,
      decoration: BoxDecoration(color: c.bg, borderRadius: t.radii.brPill),
      child: Text(
        count! > 99 ? '99+' : '$count',
        style: t.typo.monoSmall.copyWith(color: c.fg),
      ),
    );
  }
}

/// Keyboard shortcut hint: `AntKbd(['⌘', 'K'])`.
class AntKbd extends StatelessWidget {
  const AntKbd(this.keys, {super.key});

  final List<String> keys;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      label: keys.join(' '),
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < keys.length; i++) ...[
            if (i > 0) SizedBox(width: t.space.xxs),
            Container(
              constraints: BoxConstraints(minWidth: t.icon.md),
              height: t.icon.md,
              alignment: Alignment.center,
              padding: EdgeInsets.symmetric(horizontal: t.space.xs),
              decoration: BoxDecoration(
                color: t.chipBg,
                borderRadius: t.radii.brXs,
                border: Border.all(
                  color: t.borderSubtle,
                  width: t.stroke.hairline,
                ),
              ),
              child: Text(keys[i], style: t.typo.kbd.copyWith(color: t.muted)),
            ),
          ],
        ],
      ),
    );
  }
}

/// Inline citation pointing at evidence: `[3]` or `PR #412`. Tapping opens
/// the cited payload.
class AntCitationChip extends StatelessWidget {
  const AntCitationChip({
    super.key,
    required this.label,
    this.onPressed,
    this.tooltip,
    this.highlighted = false,
  });

  final String label;
  final VoidCallback? onPressed;

  /// Drawn in the accent (e.g. while its evidence is highlighted).
  final bool highlighted;

  /// Longer description of the source (title, date).
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final radius = t.radii.brXs;
    Widget chip = AntInteractive(
      onTap: onPressed,
      semanticLabel: 'Citation $label',
      isButton: onPressed != null,
      excludeChildSemantics: true,
      builder: (context, s) => AntFocusRing(
        visible: s.focused,
        borderRadius: radius,
        child: AnimatedContainer(
          duration: t.motion.fast,
          height: t.density.chipHeight - t.space.xxs,
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(horizontal: t.space.sm),
          decoration: BoxDecoration(
            color: highlighted ? t.accentSoft : t.chipBg,
            borderRadius: radius,
            border: Border.all(
              color: s.hovered || highlighted ? t.accent : t.borderStrong,
              width: t.stroke.hairline,
            ),
          ),
          child: Text(
            label,
            style: t.typo.kbd.copyWith(
              color: s.hovered || highlighted ? t.accentText : t.text3,
            ),
          ),
        ),
      ),
    );
    if (tooltip != null) chip = AntTooltip(message: tooltip!, child: chip);
    return chip;
  }
}

/// Uppercase section heading in sidebars and settings.
class AntSectionLabel extends StatelessWidget {
  const AntSectionLabel(this.label, {super.key, this.trailing});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      header: true,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: t.space.md,
          vertical: t.space.sm,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label.toUpperCase(),
                style: t.typo.sectionLabel.copyWith(color: t.muted),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}
