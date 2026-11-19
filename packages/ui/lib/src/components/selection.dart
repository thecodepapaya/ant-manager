import 'package:flutter/material.dart';

import '../tokens/ant_tokens.dart';
import 'interactive.dart';
import 'labels.dart';
import 'overlays.dart';

/// Toggleable filter chip (mockup `.chip` / `.chip.on`).
class AntSelectChip extends StatelessWidget {
  const AntSelectChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
    this.leading,
  });

  final String label;
  final bool selected;
  final VoidCallback? onPressed;

  /// E.g. a project colour dot.
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final radius = t.radii.brSm;
    return AntInteractive(
      onTap: onPressed,
      semanticLabel: label,
      selected: selected,
      excludeChildSemantics: true,
      builder: (context, s) {
        final fg = selected ? t.accentText : (s.hovered ? t.text : t.textSoft);
        return AntFocusRing(
          visible: s.focused,
          borderRadius: radius,
          child: AnimatedContainer(
            duration: t.motion.fast,
            height: t.density.chipHeight,
            padding: EdgeInsets.symmetric(horizontal: t.space.md),
            decoration: BoxDecoration(
              color: selected ? t.accentSoft : t.chipBg,
              borderRadius: radius,
              border: Border.all(
                color: selected
                    ? antToneBorder(t, AntTone.warn)
                    : (s.hovered ? t.borderStrong : t.borderSubtle),
                width: t.stroke.hairline,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leading != null) ...[leading!, SizedBox(width: t.space.sm)],
                Text(label, style: t.typo.chip.copyWith(color: fg)),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// One option of an [AntSelect].
@immutable
class AntOption<T> {
  const AntOption(this.value, this.label, {this.leading});
  final T value;
  final String label;
  final Widget? leading;
}

/// Compact dropdown (mockup `.sel`): shows the selected label and a chevron;
/// opens an [AntMenu] of options.
class AntSelect<T> extends StatelessWidget {
  const AntSelect({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.placeholder = 'Select',
    this.semanticLabel,
  });

  final List<AntOption<T>> options;
  final T value;
  final ValueChanged<T>? onChanged;
  final String placeholder;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final current = options.where((o) => o.value == value).firstOrNull;
    final radius = t.radii.brMd;
    return AntMenu(
      items: [
        for (final o in options)
          AntMenuItem(
            label: o.label,
            icon: o.value == value ? Icons.check_rounded : null,
            onSelected: onChanged == null ? null : () => onChanged!(o.value),
          ),
      ],
      builder: (context, c) => AntInteractive(
        onTap: onChanged == null
            ? null
            : () => c.isOpen ? c.close() : c.open(),
        semanticLabel: semanticLabel ?? current?.label ?? placeholder,
        excludeChildSemantics: true,
        builder: (context, s) => AntFocusRing(
          visible: s.focused,
          borderRadius: radius,
          child: AnimatedContainer(
            duration: t.motion.fast,
            height: t.density.controlMd,
            padding: EdgeInsets.symmetric(horizontal: t.space.md),
            decoration: BoxDecoration(
              color: s.hovered ? t.hover : t.surfaceSunken,
              borderRadius: radius,
              border: Border.all(
                color: t.borderStrong,
                width: t.stroke.hairline,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (current?.leading != null) ...[
                  current!.leading!,
                  SizedBox(width: t.space.sm),
                ],
                Text(
                  current?.label ?? placeholder,
                  style: t.typo.label.copyWith(
                    color: current == null ? t.placeholder : t.text2,
                  ),
                ),
                SizedBox(width: t.space.sm),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: t.icon.sm,
                  color: t.muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small coloured dot (project colours, status).
class AntDot extends StatelessWidget {
  const AntDot({super.key, required this.color, this.size});
  final Color color;

  /// Defaults to `space.md` (8).
  final double? size;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final d = size ?? t.space.md;
    return Container(
      width: d,
      height: d,
      decoration: BoxDecoration(color: color, borderRadius: t.radii.brPill),
    );
  }
}
