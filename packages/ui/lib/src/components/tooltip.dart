import 'package:flutter/material.dart';

import '../tokens/ant_tokens.dart';

/// Token-styled tooltip. Appears on hover after `motion.tooltipWait` and on
/// keyboard focus.
class AntTooltip extends StatelessWidget {
  const AntTooltip({
    super.key,
    required this.message,
    required this.child,
    this.excludeFromSemantics = false,
  });

  final String message;

  /// Set when [child] already carries [message] as its label.
  final bool excludeFromSemantics;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Tooltip(
      message: message,
      waitDuration: t.motion.tooltipWait,
      exitDuration: t.motion.fast,
      verticalOffset: t.space.xl,
      constraints: BoxConstraints(maxWidth: t.density.tooltipMaxWidth),
      padding: EdgeInsets.symmetric(
        horizontal: t.space.md,
        vertical: t.space.xs,
      ),
      decoration: BoxDecoration(
        color: t.raised,
        borderRadius: t.radii.brMd,
        border: Border.all(color: t.border, width: t.stroke.hairline),
        boxShadow: t.shadow,
      ),
      textStyle: t.typo.small.copyWith(color: t.text2),
      excludeFromSemantics: excludeFromSemantics,
      child: child,
    );
  }
}
