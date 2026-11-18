import 'package:flutter/material.dart';

import '../tokens/ant_tokens.dart';
import 'interactive.dart';
import 'tooltip.dart';

enum AntButtonVariant { primary, secondary, ghost, danger }

/// Text button with optional leading icon and trailing widget (e.g. AntKbd).
class AntButton extends StatelessWidget {
  const AntButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AntButtonVariant.secondary,
    this.size = AntSize.md,
    this.icon,
    this.trailing,
    this.expand = false,
    this.focusNode,
    this.autofocus = false,
  });

  const AntButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = AntSize.md,
    this.icon,
    this.trailing,
    this.expand = false,
    this.focusNode,
    this.autofocus = false,
  }) : variant = AntButtonVariant.primary;

  const AntButton.ghost({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = AntSize.md,
    this.icon,
    this.trailing,
    this.expand = false,
    this.focusNode,
    this.autofocus = false,
  }) : variant = AntButtonVariant.ghost;

  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;
  final AntButtonVariant variant;
  final AntSize size;
  final IconData? icon;
  final Widget? trailing;

  /// Fill the available width.
  final bool expand;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final radius = t.radii.brMd;
    final style = size == AntSize.lg ? t.typo.bodyStrong : t.typo.label;
    final pad = switch (size) {
      AntSize.sm => t.space.md,
      AntSize.md => t.space.lg,
      AntSize.lg => t.space.xl,
    };
    return AntInteractive(
      onTap: onPressed,
      focusNode: focusNode,
      autofocus: autofocus,
      semanticLabel: label,
      excludeChildSemantics: true,
      builder: (context, s) {
        final colors = _colors(t, variant, s);
        return AntDisabled(
          enabled: s.enabled,
          child: AntFocusRing(
            visible: s.focused,
            borderRadius: radius,
            child: AnimatedContainer(
              duration: t.motion.fast,
              curve: t.motion.standard,
              height: antControlHeight(t, size),
              padding: EdgeInsets.symmetric(horizontal: pad),
              decoration: BoxDecoration(
                color: colors.bg,
                borderRadius: radius,
                border: Border.all(
                  color: colors.border,
                  width: t.stroke.hairline,
                ),
              ),
              child: Row(
                mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: t.icon.sm, color: colors.fg),
                    SizedBox(width: t.space.sm),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: style.copyWith(color: colors.fg),
                    ),
                  ),
                  if (trailing != null) ...[
                    SizedBox(width: t.space.md),
                    trailing!,
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Colors {
  const _Colors(this.bg, this.fg, this.border);
  final Color bg;
  final Color fg;
  final Color border;
}

_Colors _colors(AntTokens t, AntButtonVariant v, AntInteraction s) {
  switch (v) {
    case AntButtonVariant.primary:
      final bg = s.pressed
          ? t.accent
          : s.hovered
          ? t.accentHover
          : t.accent;
      return _Colors(bg, t.onAccent, bg);
    case AntButtonVariant.secondary:
      return _Colors(
        s.pressed
            ? t.active
            : s.hovered
            ? t.hover
            : t.surface2,
        t.text,
        s.hovered ? t.borderStronger : t.borderStrong,
      );
    case AntButtonVariant.ghost:
      final bg = s.pressed
          ? t.active
          : s.hovered
          ? t.hover
          : t.hover.withValues(alpha: 0);
      return _Colors(bg, s.hovered ? t.text : t.textSoft, bg);
    case AntButtonVariant.danger:
      return _Colors(
        s.pressed || s.hovered ? t.dangerSoft : t.surface2,
        t.dangerText,
        s.hovered ? t.danger : t.borderStrong,
      );
  }
}

/// Square icon-only button. [tooltip] is required: it is also the
/// accessible label.
class AntIconButton extends StatelessWidget {
  const AntIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = AntSize.md,
    this.selected = false,
    this.focusNode,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final AntSize size;
  final bool selected;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dim = antControlHeight(t, size);
    final radius = t.radii.brMd;
    return AntTooltip(
      message: tooltip,
      excludeFromSemantics: true,
      child: AntInteractive(
        onTap: onPressed,
        focusNode: focusNode,
        semanticLabel: tooltip,
        selected: selected,
        builder: (context, s) {
          final bg = s.pressed || selected
              ? t.active
              : s.hovered
              ? t.hover
              : t.hover.withValues(alpha: 0);
          return AntDisabled(
            enabled: s.enabled,
            child: AntFocusRing(
              visible: s.focused,
              borderRadius: radius,
              child: AnimatedContainer(
                duration: t.motion.fast,
                width: dim,
                height: dim,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: bg, borderRadius: radius),
                child: Icon(
                  icon,
                  size: size == AntSize.lg ? t.icon.lg : t.icon.md,
                  color: s.hovered || selected ? t.text : t.muted,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
