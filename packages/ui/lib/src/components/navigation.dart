import 'package:flutter/material.dart';

import '../tokens/ant_tokens.dart';
import 'interactive.dart';

/// One segment of [AntTabs].
@immutable
class AntTab<T> {
  const AntTab({required this.value, required this.label, this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

/// Segmented control. Tab moves between segments; Enter/Space selects.
class AntTabs<T> extends StatelessWidget {
  const AntTabs({
    super.key,
    required this.tabs,
    required this.value,
    required this.onChanged,
    this.size = AntSize.sm,
  });

  final List<AntTab<T>> tabs;
  final T value;
  final ValueChanged<T>? onChanged;
  final AntSize size;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final inset = t.space.xxs;
    final outer = t.radii.lg;
    // Inner segments nest inside the track: radius shrinks by the inset.
    final inner = BorderRadius.circular(
      (outer - inset).clamp(0, double.infinity).toDouble(),
    );
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: FocusTraversalGroup(
        child: Container(
          height: antControlHeight(t, size) + 2 * inset,
          padding: EdgeInsets.all(inset),
          decoration: BoxDecoration(
            color: t.surface2,
            borderRadius: t.radii.brLg,
            border: Border.all(color: t.border, width: t.stroke.hairline),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final tab in tabs)
                AntInteractive(
                  onTap: onChanged == null ? null : () => onChanged!(tab.value),
                  semanticLabel: tab.label,
                  selected: tab.value == value,
                  inMutuallyExclusiveGroup: true,
                  excludeChildSemantics: true,
                  builder: (context, s) {
                    final selected = tab.value == value;
                    final fg = selected
                        ? t.text
                        : (s.hovered ? t.text2 : t.muted);
                    return AntFocusRing(
                      visible: s.focused,
                      borderRadius: inner,
                      child: AnimatedContainer(
                        duration: t.motion.base,
                        curve: t.motion.standard,
                        padding: EdgeInsets.symmetric(horizontal: t.space.lg),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected
                              ? t.raised
                              : t.raised.withValues(alpha: 0),
                          borderRadius: inner,
                          border: Border.all(
                            color: selected
                                ? t.borderStrong
                                : t.borderStrong.withValues(alpha: 0),
                            width: t.stroke.hairline,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (tab.icon != null) ...[
                              Icon(tab.icon, size: t.icon.sm, color: fg),
                              SizedBox(width: t.space.sm),
                            ],
                            Text(
                              tab.label,
                              style: t.typo.label.copyWith(color: fg),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sidebar navigation row.
class AntSidebarItem extends StatelessWidget {
  const AntSidebarItem({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.selected = false,
    this.trailing,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool selected;

  /// Count badge, kbd hint, status dot...
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final radius = t.radii.brMd;
    return AntInteractive(
      onTap: onPressed,
      semanticLabel: label,
      selected: selected,
      excludeChildSemantics: true,
      builder: (context, s) {
        final fg = selected || s.hovered ? t.text : t.textSoft;
        return AntFocusRing(
          visible: s.focused,
          borderRadius: radius,
          child: AntDisabled(
            enabled: s.enabled,
            child: AnimatedContainer(
              duration: t.motion.fast,
              height: t.density.sidebarItemHeight,
              padding: EdgeInsets.symmetric(horizontal: t.space.md),
              decoration: BoxDecoration(
                color: selected
                    ? t.active
                    : s.pressed
                    ? t.active
                    : s.hovered
                    ? t.hover
                    : t.hover.withValues(alpha: 0),
                borderRadius: radius,
              ),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: t.icon.md, color: fg),
                    SizedBox(width: t.space.md),
                  ],
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.typo.body.copyWith(color: fg),
                    ),
                  ),
                  if (trailing != null) ...[
                    SizedBox(width: t.space.sm),
                    ExcludeSemantics(child: trailing!),
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
