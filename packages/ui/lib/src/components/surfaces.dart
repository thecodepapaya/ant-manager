import 'package:flutter/material.dart';

import '../tokens/ant_tokens.dart';
import 'interactive.dart';

/// Bordered content card on `surface`. Pass [onPressed] to make it a
/// hoverable, focusable button.
class AntCard extends StatelessWidget {
  const AntCard({
    super.key,
    required this.child,
    this.title,
    this.trailing,
    this.onPressed,
    this.semanticLabel,
    this.padding,
  });

  final Widget child;
  final String? title;
  final Widget? trailing;
  final VoidCallback? onPressed;
  final String? semanticLabel;

  /// Defaults to `space.xl` on all sides.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final radius = t.radii.brXl;
    Widget body(bool hovered) => AnimatedContainer(
      duration: t.motion.fast,
      padding: padding ?? EdgeInsets.all(t.space.xl),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: radius,
        border: Border.all(
          color: hovered ? t.borderStrong : t.border,
          width: t.stroke.hairline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null || trailing != null) ...[
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    // Interactive cards announce the title as their label.
                    excludeSemantics:
                        onPressed != null && semanticLabel == null,
                    child: Text(
                      title ?? '',
                      style: t.typo.title.copyWith(color: t.text),
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            SizedBox(height: t.space.lg),
          ],
          child,
        ],
      ),
    );
    if (onPressed == null) return body(false);
    return AntInteractive(
      onTap: onPressed,
      semanticLabel: semanticLabel ?? title,
      builder: (context, s) => AntFocusRing(
        visible: s.focused,
        borderRadius: radius,
        child: body(s.hovered),
      ),
    );
  }
}

/// Floating surface on `raised` with the overlay shadow: menus, popovers,
/// toasts, dialogs.
class AntPanel extends StatelessWidget {
  const AntPanel({super.key, required this.child, this.padding, this.width});

  final Widget child;

  /// Defaults to `space.xs` (menus); dialogs pass their own.
  final EdgeInsetsGeometry? padding;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      width: width,
      padding: padding ?? EdgeInsets.all(t.space.xs),
      decoration: BoxDecoration(
        color: t.raised,
        borderRadius: t.radii.brLg,
        border: Border.all(color: t.borderSubtle, width: t.stroke.hairline),
        boxShadow: t.shadow,
      ),
      child: child,
    );
  }
}

/// Calm, helpful empty state (SPEC §10: every screen has one).
class AntEmptyState extends StatelessWidget {
  const AntEmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon,
    this.action,
  });

  final String title;
  final String? message;
  final IconData? icon;

  /// Usually one primary [AntButton]: the obvious next step.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: t.density.emptyStateMaxWidth),
        child: Padding(
          padding: EdgeInsets.all(t.space.xxxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: t.icon.hero, color: t.muted),
                SizedBox(height: t.space.xl),
              ],
              Text(
                title,
                textAlign: TextAlign.center,
                style: t.typo.title.copyWith(color: t.text),
              ),
              if (message != null) ...[
                SizedBox(height: t.space.sm),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: t.typo.body.copyWith(color: t.muted),
                ),
              ],
              if (action != null) ...[SizedBox(height: t.space.xl), action!],
            ],
          ),
        ),
      ),
    );
  }
}
