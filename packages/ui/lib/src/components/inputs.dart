import 'package:flutter/material.dart';

import '../tokens/ant_tokens.dart';
import 'interactive.dart';

/// Single- or multi-line text input.
class AntTextField extends StatelessWidget {
  const AntTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.placeholder,
    this.label,
    this.errorText,
    this.leadingIcon,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.obscureText = false,
    this.mono = false,
    this.autofocus = false,
    this.minLines,
    this.maxLines = 1,
    this.size = AntSize.md,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? placeholder;

  /// Label shown above the field (also the accessible label).
  final String? label;
  final String? errorText;
  final IconData? leadingIcon;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final bool obscureText;

  /// Use the mono face (URLs, tokens, paths).
  final bool mono;
  final bool autofocus;
  final int? minLines;
  final int? maxLines;
  final AntSize size;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final base = mono ? t.typo.mono : t.typo.body;
    OutlineInputBorder border(Color c, double w) => OutlineInputBorder(
      borderRadius: t.radii.brMd,
      borderSide: BorderSide(color: c, width: w),
    );
    final single = maxLines == 1;
    final vPad = single
        ? (antControlHeight(t, size) -
                  (base.fontSize! * base.height!) -
                  2 * t.stroke.hairline) /
              2
        : t.space.md;
    final field = Material(
      type: MaterialType.transparency,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        enabled: enabled,
        obscureText: obscureText,
        autofocus: autofocus,
        minLines: minLines,
        maxLines: maxLines,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        style: base.copyWith(color: t.text),
        cursorColor: t.accent,
        cursorWidth: t.stroke.hairline,
        textAlignVertical: single ? TextAlignVertical.center : null,
        decoration: InputDecoration(
          isDense: true,
          constraints: single
              ? BoxConstraints.tightFor(height: antControlHeight(t, size))
              : null,
          filled: true,
          fillColor: t.inputBg,
          hoverColor: t.hover.withValues(alpha: 0),
          hintText: placeholder,
          hintStyle: base.copyWith(color: t.placeholder),
          errorText: errorText,
          errorStyle: t.typo.small.copyWith(color: t.dangerText),
          prefixIcon: leadingIcon == null
              ? null
              : Icon(leadingIcon, size: t.icon.sm, color: t.muted),
          prefixIconConstraints: BoxConstraints(
            minWidth: t.density.controlMd,
            minHeight: t.icon.sm,
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: t.space.md,
            vertical: vPad,
          ),
          border: border(t.borderStrong, t.stroke.hairline),
          enabledBorder: border(t.borderStrong, t.stroke.hairline),
          disabledBorder: border(t.border, t.stroke.hairline),
          focusedBorder: border(t.accent, t.stroke.hairline),
          errorBorder: border(t.danger, t.stroke.hairline),
          focusedErrorBorder: border(t.danger, t.stroke.hairline),
        ),
      ),
    );
    final content = AntDisabled(enabled: enabled, child: field);
    if (label == null) return content;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label!, style: t.typo.label.copyWith(color: t.text2)),
        SizedBox(height: t.space.sm),
        content,
      ],
    );
  }
}

/// On/off toggle.
class AntSwitch extends StatelessWidget {
  const AntSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.semanticLabel,
    this.focusNode,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? semanticLabel;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final d = t.density;
    final inset = t.space.xxs;
    final thumb = d.switchHeight - 2 * inset;
    final radius = t.radii.brPill;
    return AntInteractive(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      focusNode: focusNode,
      semanticLabel: semanticLabel,
      isButton: false,
      toggled: value,
      builder: (context, s) => AntDisabled(
        enabled: s.enabled,
        child: AntFocusRing(
          visible: s.focused,
          borderRadius: radius,
          child: AnimatedContainer(
            duration: t.motion.base,
            curve: t.motion.standard,
            width: d.switchWidth,
            height: d.switchHeight,
            padding: EdgeInsets.all(inset),
            decoration: BoxDecoration(
              color: value
                  ? (s.hovered ? t.accentHover : t.accent)
                  : (s.hovered ? t.raw : t.borderStronger),
              borderRadius: radius,
            ),
            child: AnimatedAlign(
              duration: t.motion.base,
              curve: t.motion.standard,
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: thumb,
                height: thumb,
                decoration: BoxDecoration(
                  color: value ? t.onAccent : t.text2,
                  borderRadius: radius,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Checkbox with an optional clickable label.
class AntCheckbox extends StatelessWidget {
  const AntCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
    this.focusNode,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? label;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final size = t.density.checkboxSize;
    final radius = t.radii.brXs;
    return AntInteractive(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      focusNode: focusNode,
      semanticLabel: label,
      isButton: false,
      checked: value,
      excludeChildSemantics: true,
      builder: (context, s) => AntDisabled(
        enabled: s.enabled,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AntFocusRing(
              visible: s.focused,
              borderRadius: radius,
              child: AnimatedContainer(
                duration: t.motion.fast,
                width: size,
                height: size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: value
                      ? (s.hovered ? t.accentHover : t.accent)
                      : t.inputBg,
                  borderRadius: radius,
                  border: Border.all(
                    color: value
                        ? t.accent
                        : (s.hovered ? t.raw : t.borderStronger),
                    width: t.stroke.hairline,
                  ),
                ),
                child: value
                    ? Icon(
                        Icons.check_rounded,
                        size: t.icon.xs,
                        color: t.onAccent,
                      )
                    : null,
              ),
            ),
            if (label != null) ...[
              SizedBox(width: t.space.md),
              Flexible(
                child: Text(
                  label!,
                  style: t.typo.body.copyWith(color: t.text2),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
