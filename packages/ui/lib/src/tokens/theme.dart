import 'package:flutter/material.dart';

import 'ant_tokens.dart';
import 'scales.dart';

/// Builds a [ThemeData] whose Material defaults follow [t], with [t]
/// registered as a theme extension (read it with `context.tokens`).
///
/// Ant components don't rely on Material styling; this only keeps stray
/// Material widgets (scrollbars, selection, default text) on-brand.
ThemeData antTheme(AntTokens t) {
  final scheme = ColorScheme(
    brightness: t.brightness,
    primary: t.accent,
    onPrimary: t.onAccent,
    secondary: t.accent,
    onSecondary: t.onAccent,
    error: t.danger,
    onError: t.onAccent,
    surface: t.surface,
    onSurface: t.text,
    onSurfaceVariant: t.muted,
    surfaceContainerLowest: t.bg,
    surfaceContainerLow: t.surfaceSunken,
    surfaceContainer: t.surface2,
    surfaceContainerHigh: t.raised,
    surfaceContainerHighest: t.active,
    outline: t.border,
    outlineVariant: t.divider,
    shadow: t.shadowColor,
    scrim: t.scrim,
  );
  final tt = t.typo;
  final textTheme = TextTheme(
    displaySmall: tt.display,
    headlineSmall: tt.heading,
    titleMedium: tt.title,
    titleSmall: tt.bodyStrong,
    bodyLarge: tt.body,
    bodyMedium: tt.body,
    bodySmall: tt.small,
    labelLarge: tt.label,
    labelMedium: tt.label,
    labelSmall: tt.caption,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: t.brightness,
    colorScheme: scheme,
    fontFamily: AntFonts.sans,
    package: AntFonts.package,
    textTheme: textTheme,
    scaffoldBackgroundColor: t.bg,
    canvasColor: t.bg,
    dividerColor: t.divider,
    hoverColor: t.hover,
    focusColor: t.focusRing,
    highlightColor: t.active,
    splashFactory: NoSplash.splashFactory,
    visualDensity: VisualDensity.compact,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: t.accent,
      selectionColor: t.accentSoft,
      selectionHandleColor: t.accent,
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(t.raw),
      radius: Radius.circular(t.radii.sm),
      thickness: WidgetStatePropertyAll(t.space.sm),
    ),
    dividerTheme: DividerThemeData(
      color: t.divider,
      thickness: t.stroke.hairline,
      space: t.stroke.hairline,
    ),
    extensions: [t],
  );
}
