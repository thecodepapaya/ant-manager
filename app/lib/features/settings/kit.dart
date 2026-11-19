/// Small layout pieces shared by the Sources, Settings and Onboarding screens, matching the
/// mockup's topbar, panels, rows, labels and selects. Every value comes from [AntTokens].
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui/ui.dart';

import '../../engine/engine_handle.dart';
import '../../engine/messages.dart';
import '../../state/providers.dart';

/// Provides [AntTokens] (and a toast host) when the surrounding theme doesn't have them yet.
/// TODO(ui): drop once app.dart builds its theme with `antTheme`.
class TokensScope extends StatelessWidget {
  const TokensScope({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final existing = theme.extension<AntTokens>();
    if (existing != null) return ColoredBox(color: existing.bg, child: AntToastHost(child: child));
    final host = AntToastHost(child: child);
    final t = theme.brightness == Brightness.dark ? AntTokens.dark() : AntTokens.light();
    return Theme(
      data: antTheme(t),
      child: Builder(
        builder: (context) => DefaultTextStyle(
          style: context.tokens.typo.body.copyWith(color: context.tokens.text),
          child: ColoredBox(color: context.tokens.bg, child: host),
        ),
      ),
    );
  }
}

void toast(BuildContext context, String message, {AntTone tone = AntTone.neutral}) {
  if (!context.mounted) return;
  AntToastHost.of(context).show(message, tone: tone);
}

/// Strips the exception wrapper from an engine error for display.
String errorText(Object e) {
  final s = e is EngineCommandException ? e.message : '$e';
  return s
      .replaceFirst(RegExp(r'^(Exception|StateError|Bad state|LlmFailure\(\w*\)|BackupException): ?'), '')
      .trim();
}

/// Runs an engine command; on failure shows an error toast and returns null.
Future<T?> runCmd<T>(BuildContext context, WidgetRef ref, EngineCommand<T> cmd, {String? done}) async {
  try {
    final h = await ref.read(engineProvider.future);
    final v = await h.runtime(cmd);
    if (done != null && context.mounted) toast(context, done, tone: AntTone.ok);
    return v;
  } catch (e) {
    if (context.mounted) toast(context, errorText(e), tone: AntTone.err);
    return null;
  }
}

/// `.topbar`: page title, muted subtitle, then actions on the right.
class PageTopBar extends StatelessWidget {
  const PageTopBar({super.key, required this.title, this.subtitle, this.center, this.actions = const []});
  final String title;
  final String? subtitle;
  final Widget? center;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      constraints: BoxConstraints(minHeight: t.space.giant + t.space.xs),
      padding: EdgeInsets.symmetric(horizontal: t.space.xxxl, vertical: t.space.md),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.border, width: t.stroke.hairline)),
      ),
      child: Row(
        children: [
          Text(title, style: t.typo.title.copyWith(color: t.text)),
          // Tabs right after the title (as on Narrative and Reports), then the muted subtitle.
          if (center != null) ...[SizedBox(width: t.space.lg), center!],
          if (subtitle != null) ...[
            SizedBox(width: t.space.lg),
            Expanded(
              child: Text(subtitle!,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: t.typo.small.copyWith(color: t.muted)),
            ),
          ] else
            const Spacer(),
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0) SizedBox(width: t.space.md),
            actions[i],
          ],
        ],
      ),
    );
  }
}

/// Scrolling page body with the mockup's 20/24/48 padding and a max content width.
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children, this.maxWidth});
  final List<Widget> children;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(t.space.xxxl, t.space.xxl, t.space.xxxl, t.space.giant),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth ?? double.infinity),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
        ),
      ),
    );
  }
}

/// Content widths used by the settings pages (mockup: 760 / 980).
extension PageWidths on AntTokens {
  double get narrowPage => density.dialogWidth * 1.75;
  double get widePage => density.dialogWidth * 2.25;
  double get gridMinTile => density.menuMinWidth * 1.5;
}

/// `.label`: uppercase muted heading above a panel.
class Label extends StatelessWidget {
  const Label(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      children: [
        Text(text.toUpperCase(), style: t.typo.sectionLabel.copyWith(color: t.muted)),
        if (trailing != null) ...[SizedBox(width: t.space.md), Expanded(child: trailing!)],
      ],
    );
  }
}

/// `.panel` holding rows separated by hairline dividers.
class ListPanel extends StatelessWidget {
  const ListPanel({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: t.radii.brXl,
        border: Border.all(color: t.border, width: t.stroke.hairline),
      ),
      child: ClipRRect(
        borderRadius: t.radii.brXl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) Divider(height: t.stroke.hairline, thickness: t.stroke.hairline, color: t.divider),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// One row inside a [ListPanel]: optional leading, title + hint, trailing widgets.
class PanelRow extends StatelessWidget {
  const PanelRow({
    super.key,
    this.leading,
    required this.title,
    this.hint,
    this.hintMono = false,
    this.titleWidth,
    this.trailing = const [],
    this.onTap,
    this.dense = false,
  });
  final Widget? leading;
  final String title;
  final String? hint;
  final bool hintMono;

  /// Fixed title column (provider table); the hint then sits beside it.
  final double? titleWidth;
  final List<Widget> trailing;
  final VoidCallback? onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final titleText = Text(title, style: t.typo.bodyStrong.copyWith(color: t.text));
    final hintText = hint == null
        ? null
        : Text(hint!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: hintMono ? t.typo.mono.copyWith(color: t.muted) : t.typo.small.copyWith(color: t.muted));
    Widget content(bool hovered) => Container(
          color: hovered ? t.hover : t.hover.withValues(alpha: 0),
          padding: EdgeInsets.symmetric(horizontal: t.space.xl, vertical: dense ? t.space.lg - t.space.xxs : t.space.lg + t.space.xxs),
          child: Row(
            children: [
              if (leading != null) ...[leading!, SizedBox(width: t.space.lg)],
              if (titleWidth != null) ...[
                SizedBox(width: titleWidth, child: titleText),
                if (hintText != null) Expanded(child: hintText) else const Spacer(),
              ] else
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [titleText, ?hintText],
                  ),
                ),
              for (final w in trailing) ...[SizedBox(width: t.space.lg), w],
            ],
          ),
        );
    if (onTap == null) return content(false);
    return AntInteractive(onTap: onTap, builder: (context, s) => content(s.hovered));
  }
}

/// 30×30 rounded glyph box (source / destination icons).
class Glyph extends StatelessWidget {
  const Glyph(this.text, {super.key, this.icon});
  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final size = t.density.controlMd + t.space.xxs;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: t.chipBg,
        borderRadius: t.radii.brMd,
        border: Border.all(color: t.borderSubtle, width: t.stroke.hairline),
      ),
      child: icon != null
          ? Icon(icon, size: t.icon.md, color: t.text2)
          : Text(text, style: t.typo.label.copyWith(color: t.text2, fontWeight: FontWeight.w600)),
    );
  }
}

/// `.sel`: a compact select built on [AntMenu].
class SelectButton<T> extends StatelessWidget {
  const SelectButton({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.labelFor,
    this.placeholder = 'Choose…',
  });
  final T? value;
  final List<(T, String)> options;
  final ValueChanged<T>? onChanged;
  final String Function(T)? labelFor;
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final current = options.where((o) => o.$1 == value).firstOrNull;
    final label = current?.$2 ?? (value == null ? placeholder : (labelFor?.call(value as T) ?? '$value'));
    return AntMenu(
      items: [
        for (final (v, l) in options) AntMenuItem(label: l, icon: v == value ? Icons.check : null, onSelected: () => onChanged?.call(v)),
      ],
      builder: (context, c) => AntInteractive(
        enabled: onChanged != null,
        onTap: () => c.isOpen ? c.close() : c.open(),
        builder: (context, s) => AntDisabled(
          enabled: s.enabled,
          child: AntFocusRing(
            visible: s.focused,
            borderRadius: t.radii.brMd,
            child: Container(
              height: t.density.controlMd,
              padding: EdgeInsets.symmetric(horizontal: t.space.md + t.space.xxs),
              decoration: BoxDecoration(
                color: s.hovered ? t.hover : t.surfaceSunken,
                borderRadius: t.radii.brMd,
                border: Border.all(color: t.borderStrong, width: t.stroke.hairline),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(label,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: t.typo.label.copyWith(color: t.text2)),
                  ),
                  SizedBox(width: t.space.md),
                  Icon(Icons.expand_more, size: t.icon.sm, color: t.muted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Accent (warning) or neutral (info) callout box.
class Callout extends StatelessWidget {
  const Callout({super.key, required this.child, this.warn = true, this.icon});
  final Widget child;
  final bool warn;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final fg = warn ? t.accentText : t.muted;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: t.space.lg + t.space.xxs, vertical: t.space.md + t.space.xxs),
      decoration: BoxDecoration(
        color: warn ? t.accentSoft : t.surface2,
        borderRadius: t.radii.brLg,
        border: Border.all(color: warn ? t.accent.withValues(alpha: 0.3) : t.border, width: t.stroke.hairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? (warn ? Icons.warning_amber_rounded : Icons.info_outline), size: t.icon.sm, color: fg),
          SizedBox(width: t.space.md),
          Expanded(child: DefaultTextStyle(style: t.typo.small.copyWith(color: warn ? t.text2 : t.muted), child: child)),
        ],
      ),
    );
  }
}

/// Muted helper text under a field.
class Hint extends StatelessWidget {
  const Hint(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: EdgeInsets.only(top: t.space.sm),
      child: Text(text, style: t.typo.small.copyWith(color: t.muted)),
    );
  }
}

/// Vertical gap in spacing tokens.
class Gap extends StatelessWidget {
  const Gap(this.size, {super.key});
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox(height: size, width: size);
}

/// Disclosure row ("Customize per task", "Advanced") that expands [child].
class Disclosure extends StatefulWidget {
  const Disclosure({super.key, required this.title, this.hint, required this.child, this.initiallyOpen = false});
  final String title;
  final String? hint;
  final Widget child;
  final bool initiallyOpen;
  @override
  State<Disclosure> createState() => _DisclosureState();
}

class _DisclosureState extends State<Disclosure> {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AntInteractive(
          onTap: () => setState(() => _open = !_open),
          semanticLabel: widget.title,
          builder: (context, s) => Padding(
            padding: EdgeInsets.symmetric(vertical: t.space.sm),
            child: Row(
              children: [
                AnimatedRotation(
                  turns: _open ? 0.25 : 0,
                  duration: t.motion.base,
                  child: Icon(Icons.chevron_right, size: t.icon.md, color: s.hovered ? t.text : t.muted),
                ),
                SizedBox(width: t.space.sm),
                Text(widget.title, style: t.typo.bodyStrong.copyWith(color: s.hovered ? t.text : t.text2)),
                if (widget.hint != null) ...[
                  SizedBox(width: t.space.md),
                  Flexible(child: Text(widget.hint!, style: t.typo.small.copyWith(color: t.muted))),
                ],
              ],
            ),
          ),
        ),
        if (_open) ...[SizedBox(height: t.space.md), widget.child],
      ],
    );
  }
}

/// A wide modal panel for multi-step flows (provider setup, git setup, restore preview).
class WideDialog extends StatelessWidget {
  const WideDialog({super.key, required this.title, this.subtitle, required this.body, this.actions = const [], this.leadingActions = const []});
  final String title;
  final String? subtitle;
  final Widget body;
  final List<Widget> actions;
  final List<Widget> leadingActions;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final size = MediaQuery.sizeOf(context);
    return Center(
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          width: t.density.dialogWidth * 1.45,
          constraints: BoxConstraints(maxHeight: size.height - t.space.giant * 2),
          decoration: BoxDecoration(
            color: t.raised,
            borderRadius: t.radii.brXl,
            border: Border.all(color: t.borderSubtle, width: t.stroke.hairline),
            boxShadow: t.shadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(t.space.xxl, t.space.xxl, t.space.xxl, t.space.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: t.typo.title.copyWith(color: t.text)),
                    if (subtitle != null) ...[
                      SizedBox(height: t.space.xs),
                      Text(subtitle!, style: t.typo.small.copyWith(color: t.muted)),
                    ],
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: t.space.xxl, vertical: t.space.md),
                  child: DefaultTextStyle(style: t.typo.body.copyWith(color: t.textSoft), child: body),
                ),
              ),
              Container(
                padding: EdgeInsets.all(t.space.xl),
                decoration: BoxDecoration(border: Border(top: BorderSide(color: t.divider, width: t.stroke.hairline))),
                child: Row(
                  children: [
                    for (final a in leadingActions) ...[a, SizedBox(width: t.space.md)],
                    const Spacer(),
                    for (var i = 0; i < actions.length; i++) ...[
                      if (i > 0) SizedBox(width: t.space.md),
                      actions[i],
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lays children out in equal columns at least [minWidth] wide (CSS `auto-fill, minmax`).
class TileGrid extends StatelessWidget {
  const TileGrid({super.key, required this.children, required this.minWidth, this.gap});
  final List<Widget> children;
  final double minWidth;
  final double? gap;

  @override
  Widget build(BuildContext context) {
    final g = gap ?? context.tokens.space.lg;
    return LayoutBuilder(builder: (context, c) {
      final cols = ((c.maxWidth + g) / (minWidth + g)).floor().clamp(1, 99);
      final w = (c.maxWidth - g * (cols - 1)) / cols;
      return Wrap(
        spacing: g,
        runSpacing: g,
        children: [for (final child in children) SizedBox(width: w, child: child)],
      );
    });
  }
}

/// A thin progress bar (`.seg`).
class Bar extends StatelessWidget {
  const Bar(this.value, {super.key});

  /// 0..1, or null for an indeterminate shimmer.
  final double? value;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ClipRRect(
      borderRadius: t.radii.brPill,
      child: LinearProgressIndicator(
        value: value,
        minHeight: t.space.sm,
        backgroundColor: t.border,
        color: t.accent,
      ),
    );
  }
}
