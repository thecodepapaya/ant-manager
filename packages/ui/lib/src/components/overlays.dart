import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens/ant_tokens.dart';
import 'button.dart';
import 'interactive.dart';
import 'labels.dart';
import 'surfaces.dart';

// ---------------------------------------------------------------------------
// Menu
// ---------------------------------------------------------------------------

/// An entry in an [AntMenu].
sealed class AntMenuEntry {
  const AntMenuEntry();
}

class AntMenuItem extends AntMenuEntry {
  const AntMenuItem({
    required this.label,
    required this.onSelected,
    this.icon,
    this.shortcut,
    this.danger = false,
  });

  final String label;
  final VoidCallback? onSelected;
  final IconData? icon;

  /// Hint only (rendered as [AntKbd]); register the real shortcut elsewhere.
  final List<String>? shortcut;
  final bool danger;
}

class AntMenuDivider extends AntMenuEntry {
  const AntMenuDivider();
}

/// Dropdown / context menu built on [MenuAnchor] (arrow-key navigation,
/// Escape to close, focus return) with Ant styling.
class AntMenu extends StatelessWidget {
  const AntMenu({
    super.key,
    required this.items,
    required this.builder,
    this.controller,
  });

  final List<AntMenuEntry> items;

  /// Builds the anchor; call `controller.open()` / `.close()`.
  final Widget Function(BuildContext context, MenuController controller)
  builder;
  final MenuController? controller;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final transparent = t.raised.withValues(alpha: 0);
    return MenuAnchor(
      controller: controller,
      alignmentOffset: Offset(0, t.space.xs),
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(t.raised),
        surfaceTintColor: WidgetStatePropertyAll(transparent),
        shadowColor: WidgetStatePropertyAll(t.shadowColor),
        elevation: WidgetStatePropertyAll(t.stroke.overlayElevation),
        padding: WidgetStatePropertyAll(EdgeInsets.all(t.space.xs)),
        minimumSize: WidgetStatePropertyAll(Size(t.density.menuMinWidth, 0)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: t.radii.brLg,
            side: BorderSide(color: t.borderSubtle, width: t.stroke.hairline),
          ),
        ),
      ),
      menuChildren: [
        for (final e in items)
          switch (e) {
            AntMenuDivider() => Padding(
              padding: EdgeInsets.symmetric(vertical: t.space.xs),
              child: Divider(
                height: t.stroke.hairline,
                thickness: t.stroke.hairline,
                color: t.divider,
              ),
            ),
            AntMenuItem() => _item(t, e, transparent),
          },
      ],
      builder: (context, controller, _) => builder(context, controller),
    );
  }

  Widget _item(AntTokens t, AntMenuItem e, Color transparent) {
    final fg = e.danger ? t.dangerText : t.text2;
    return MenuItemButton(
      onPressed: e.onSelected,
      leadingIcon: e.icon == null
          ? null
          : Icon(e.icon, size: t.icon.sm, color: e.danger ? t.danger : t.muted),
      trailingIcon: e.shortcut == null ? null : AntKbd(e.shortcut!),
      style: ButtonStyle(
        minimumSize: WidgetStatePropertyAll(Size(0, t.density.controlMd)),
        padding: WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: t.space.md),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: t.radii.brMd),
        ),
        textStyle: WidgetStatePropertyAll(t.typo.body),
        foregroundColor: WidgetStatePropertyAll(fg),
        iconColor: WidgetStatePropertyAll(fg),
        overlayColor: WidgetStatePropertyAll(transparent),
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) =>
              s.contains(WidgetState.hovered) || s.contains(WidgetState.focused)
              ? (e.danger ? t.dangerSoft : t.hover)
              : transparent,
        ),
      ),
      child: Text(e.label),
    );
  }
}

// ---------------------------------------------------------------------------
// Popover
// ---------------------------------------------------------------------------

/// Floating panel anchored below its trigger. Closes on outside tap or
/// Escape. Content gets focus when shown.
class AntPopover extends StatefulWidget {
  const AntPopover({
    super.key,
    required this.anchorBuilder,
    required this.contentBuilder,
    this.width,
  });

  /// Build the trigger; call `controller.toggle()` on press.
  final Widget Function(BuildContext context, OverlayPortalController c)
  anchorBuilder;

  /// Build the content; call `controller.hide()` to close.
  final Widget Function(BuildContext context, OverlayPortalController c)
  contentBuilder;
  final double? width;

  @override
  State<AntPopover> createState() => _AntPopoverState();
}

class _AntPopoverState extends State<AntPopover> {
  final _controller = OverlayPortalController();
  final _link = LayerLink();
  final _group = Object();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _controller,
        overlayChildBuilder: (context) => CompositedTransformFollower(
          link: _link,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: Offset(0, t.space.xs),
          child: Align(
            alignment: Alignment.topLeft,
            child: TapRegion(
              groupId: _group,
              onTapOutside: (_) => _controller.hide(),
              child: CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.escape):
                      _controller.hide,
                },
                child: FocusScope(
                  autofocus: true,
                  child: Semantics(
                    scopesRoute: true,
                    explicitChildNodes: true,
                    child: AntPanel(
                      width: widget.width ?? t.density.menuMinWidth,
                      padding: EdgeInsets.all(t.space.md),
                      child: widget.contentBuilder(context, _controller),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        child: TapRegion(
          groupId: _group,
          child: widget.anchorBuilder(context, _controller),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dialog
// ---------------------------------------------------------------------------

/// Modal dialog body. Show it with [showAntDialog].
class AntDialog extends StatelessWidget {
  const AntDialog({
    super.key,
    required this.title,
    this.body,
    this.actions = const [],
  });

  final String title;
  final Widget? body;

  /// Right-aligned, usually `[AntButton.ghost(Cancel), AntButton.primary(OK)]`.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Center(
      child: Semantics(
        scopesRoute: true,
        namesRoute: true,
        label: title,
        explicitChildNodes: true,
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            width: t.density.dialogWidth,
            padding: EdgeInsets.all(t.space.xxl),
            decoration: BoxDecoration(
              color: t.raised,
              borderRadius: t.radii.brXl,
              border: Border.all(
                color: t.borderSubtle,
                width: t.stroke.hairline,
              ),
              boxShadow: t.shadow,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: t.typo.title.copyWith(color: t.text),
                  ),
                ),
                if (body != null) ...[
                  SizedBox(height: t.space.md),
                  DefaultTextStyle(
                    style: t.typo.body.copyWith(color: t.textSoft),
                    child: body!,
                  ),
                ],
                if (actions.isNotEmpty) ...[
                  SizedBox(height: t.space.xxl),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      for (var i = 0; i < actions.length; i++) ...[
                        if (i > 0) SizedBox(width: t.space.md),
                        actions[i],
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows a modal [AntDialog] (or any widget) over a scrim. Escape and a
/// scrim click dismiss it.
Future<T?> showAntDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  final t = context.tokens;
  // Keep a locally overridden theme (e.g. a nested Theme) inside the route.
  final themes = InheritedTheme.capture(
    from: context,
    to: Navigator.of(context).context,
  );
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: 'Dismiss',
    barrierColor: t.scrim,
    transitionDuration: t.motion.slow,
    pageBuilder: (context, _, _) => themes.wrap(Builder(builder: builder)),
    transitionBuilder: (context, anim, _, child) {
      final curved = CurvedAnimation(
        parent: anim,
        curve: t.motion.standard,
        reverseCurve: t.motion.exit,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.97, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Toast
// ---------------------------------------------------------------------------

/// Visual toast. Usually shown through [AntToastHost.of].
class AntToast extends StatelessWidget {
  const AntToast({
    super.key,
    required this.message,
    this.tone = AntTone.neutral,
    this.action,
    this.onDismiss,
  });

  final String message;
  final AntTone tone;

  /// Optional inline action, e.g. `AntButton.ghost(label: 'Undo', ...)`.
  final Widget? action;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final icon = switch (tone) {
      AntTone.ok => (Icons.check_circle_rounded, t.success),
      AntTone.err => (Icons.error_rounded, t.danger),
      AntTone.warn => (Icons.warning_rounded, t.accent),
      AntTone.info => (Icons.info_rounded, t.info),
      AntTone.neutral || AntTone.accent => (Icons.info_rounded, t.muted),
    };
    return Semantics(
      liveRegion: true,
      container: true,
      child: AntPanel(
        width: t.density.toastWidth,
        padding: EdgeInsets.symmetric(
          horizontal: t.space.lg,
          vertical: t.space.md,
        ),
        child: Row(
          children: [
            Icon(icon.$1, size: t.icon.md, color: icon.$2),
            SizedBox(width: t.space.md),
            Expanded(
              child: Text(message, style: t.typo.body.copyWith(color: t.text2)),
            ),
            if (action != null) ...[SizedBox(width: t.space.md), action!],
            if (onDismiss != null) ...[
              SizedBox(width: t.space.xs),
              AntIconButton(
                icon: Icons.close_rounded,
                tooltip: 'Dismiss',
                size: AntSize.sm,
                onPressed: onDismiss,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Hosts toasts bottom-right above [child]. Put it once near the app root
/// (inside the MaterialApp builder), then `AntToastHost.of(context).show(...)`.
class AntToastHost extends StatefulWidget {
  const AntToastHost({super.key, required this.child});

  final Widget child;

  static AntToastHostState of(BuildContext context) {
    final s = context.findAncestorStateOfType<AntToastHostState>();
    if (s == null) {
      throw FlutterError('No AntToastHost above this context.');
    }
    return s;
  }

  @override
  State<AntToastHost> createState() => AntToastHostState();
}

class AntToastHostState extends State<AntToastHost> {
  final _toasts = <_ToastEntry>[];
  int _next = 0;

  /// Shows a toast for `motion.toastDwell`.
  void show(String message, {AntTone tone = AntTone.neutral, Widget? action}) {
    final entry = _ToastEntry(_next++, message, tone, action);
    setState(() => _toasts.add(entry));
    entry.timer = Timer(context.tokens.motion.toastDwell, () => _remove(entry));
  }

  void _remove(_ToastEntry e) {
    e.timer?.cancel();
    if (mounted) setState(() => _toasts.remove(e));
  }

  @override
  void dispose() {
    for (final e in _toasts) {
      e.timer?.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Stack(
      children: [
        widget.child,
        Positioned(
          right: t.space.xl,
          bottom: t.space.xl,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final e in _toasts)
                Padding(
                  key: ValueKey(e.id),
                  padding: EdgeInsets.only(top: t.space.md),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: t.motion.slow,
                    curve: t.motion.standard,
                    builder: (context, v, child) => Opacity(
                      opacity: v,
                      child: Transform.translate(
                        offset: Offset(0, (1 - v) * t.space.md),
                        child: child,
                      ),
                    ),
                    child: AntToast(
                      message: e.message,
                      tone: e.tone,
                      action: e.action,
                      onDismiss: () => _remove(e),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ToastEntry {
  _ToastEntry(this.id, this.message, this.tone, this.action);
  final int id;
  final String message;
  final AntTone tone;
  final Widget? action;
  Timer? timer;
}
