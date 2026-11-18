import 'package:flutter/material.dart';

import '../tokens/ant_tokens.dart';

/// Size steps shared by controls. Heights come from `AntTokens.density`.
enum AntSize { sm, md, lg }

/// Interaction state handed to [AntInteractive.builder].
@immutable
class AntInteraction {
  const AntInteraction({
    required this.hovered,
    required this.focused,
    required this.pressed,
    required this.enabled,
  });

  final bool hovered;
  final bool focused;
  final bool pressed;
  final bool enabled;
}

/// Shared hover / focus / press / keyboard-activation plumbing for Ant
/// controls. Enter and Space activate; focus shows a ring only for keyboard
/// focus (via [FocusableActionDetector]'s highlight mode).
class AntInteractive extends StatefulWidget {
  const AntInteractive({
    super.key,
    required this.builder,
    this.onTap,
    this.enabled = true,
    this.focusNode,
    this.autofocus = false,
    this.semanticLabel,
    this.isButton = true,
    this.selected,
    this.checked,
    this.toggled,
    this.inMutuallyExclusiveGroup = false,
    this.cursor,
    this.excludeChildSemantics = false,
  });

  final Widget Function(BuildContext context, AntInteraction state) builder;
  final VoidCallback? onTap;
  final bool enabled;
  final FocusNode? focusNode;
  final bool autofocus;
  final String? semanticLabel;
  final bool isButton;
  final bool? selected;
  final bool? checked;
  final bool? toggled;
  final bool inMutuallyExclusiveGroup;
  final MouseCursor? cursor;
  final bool excludeChildSemantics;

  @override
  State<AntInteractive> createState() => _AntInteractiveState();
}

class _AntInteractiveState extends State<AntInteractive> {
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;
  bool _hasFocus = false;
  FocusNode? _ownNode;

  FocusNode get _node => widget.focusNode ?? (_ownNode ??= FocusNode());

  @override
  void dispose() {
    _ownNode?.dispose();
    super.dispose();
  }

  bool get _active => widget.enabled && widget.onTap != null;

  void _setPressed(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final active = _active;
    final state = AntInteraction(
      hovered: active && _hovered,
      focused: active && _focused,
      pressed: active && _pressed,
      enabled: active,
    );
    return Semantics(
      container: true,
      button: widget.isButton,
      enabled: active,
      label: widget.semanticLabel,
      selected: widget.selected,
      checked: widget.checked,
      toggled: widget.toggled,
      inMutuallyExclusiveGroup: widget.inMutuallyExclusiveGroup,
      focusable: active,
      focused: active && _hasFocus,
      onTap: active ? widget.onTap : null,
      onFocus: active ? _node.requestFocus : null,
      child: FocusableActionDetector(
        enabled: active,
        focusNode: _node,
        includeFocusSemantics: false,
        onFocusChange: (v) => setState(() => _hasFocus = v),
        autofocus: widget.autofocus,
        mouseCursor:
            widget.cursor ??
            (active ? SystemMouseCursors.click : SystemMouseCursors.basic),
        onShowHoverHighlight: (v) => setState(() => _hovered = v),
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap?.call();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: active ? (_) => _setPressed(true) : null,
          onTapUp: active ? (_) => _setPressed(false) : null,
          onTapCancel: active ? () => _setPressed(false) : null,
          onTap: active ? widget.onTap : null,
          child: ExcludeSemantics(
            excluding: widget.excludeChildSemantics,
            child: widget.builder(context, state),
          ),
        ),
      ),
    );
  }
}

/// Paints a keyboard focus ring just outside [child] without affecting layout.
class AntFocusRing extends StatelessWidget {
  const AntFocusRing({
    super.key,
    required this.visible,
    required this.borderRadius,
    required this.child,
  });

  final bool visible;
  final BorderRadius borderRadius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (!visible) return child;
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        border: Border.all(
          color: t.focusRing,
          width: t.stroke.focus,
          strokeAlign: BorderSide.strokeAlignOutside,
        ),
      ),
      child: child,
    );
  }
}

/// Dims [child] when disabled, using the token opacity.
class AntDisabled extends StatelessWidget {
  const AntDisabled({super.key, required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) => enabled
      ? child
      : Opacity(opacity: context.tokens.stroke.disabledOpacity, child: child);
}

/// Height of a control at [size].
double antControlHeight(AntTokens t, AntSize size) => switch (size) {
  AntSize.sm => t.density.controlSm,
  AntSize.md => t.density.controlMd,
  AntSize.lg => t.density.controlLg,
};
