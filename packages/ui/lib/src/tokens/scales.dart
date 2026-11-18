import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

/// Corner radius scale, derived from one [base] (tokens.css `--radius`).
///
/// Setting [base] to 0 squares everything; raising it rounds everything.
@immutable
class AntRadii {
  const AntRadii(this.base);

  /// The default base radius (tokens.css `--radius: 6px`).
  static const double defaultBase = 6;

  final double base;

  /// kbd, citations.
  double get xs => base * 0.67;

  /// Chips.
  double get sm => base * 0.83;

  /// Buttons, inputs, nav items.
  double get md => base;

  /// Rows, menus, tabs.
  double get lg => base * 1.33;

  /// Panels, cards, dialogs.
  double get xl => base * 1.67;

  BorderRadius get brXs => BorderRadius.circular(xs);
  BorderRadius get brSm => BorderRadius.circular(sm);
  BorderRadius get brMd => BorderRadius.circular(md);
  BorderRadius get brLg => BorderRadius.circular(lg);
  BorderRadius get brXl => BorderRadius.circular(xl);

  /// Fully rounded (pills, switch tracks); square when [base] is 0.
  BorderRadius get brPill => BorderRadius.circular(base <= 0 ? 0 : 999);

  static AntRadii lerp(AntRadii a, AntRadii b, double t) =>
      AntRadii(lerpDouble(a.base, b.base, t)!);

  @override
  bool operator ==(Object other) => other is AntRadii && other.base == base;

  @override
  int get hashCode => base.hashCode;
}

/// 4-pt spacing scale.
@immutable
class AntSpacing {
  const AntSpacing();

  /// 2
  double get xxs => 2;

  /// 4
  double get xs => 4;

  /// 6 (half-step, for dense inline gaps)
  double get sm => 6;

  /// 8
  double get md => 8;

  /// 12
  double get lg => 12;

  /// 16
  double get xl => 16;

  /// 20
  double get xxl => 20;

  /// 24
  double get xxxl => 24;

  /// 32
  double get huge => 32;

  /// 48
  double get giant => 48;
}

/// Control sizes for the information density (Linear-like compact by default).
@immutable
class AntDensity {
  const AntDensity({
    required this.controlSm,
    required this.controlMd,
    required this.controlLg,
    required this.rowHeight,
    required this.sidebarItemHeight,
    required this.switchWidth,
    required this.switchHeight,
    required this.checkboxSize,
    required this.dialogWidth,
    required this.menuMinWidth,
    required this.toastWidth,
    required this.emptyStateMaxWidth,
    required this.tooltipMaxWidth,
  });

  const AntDensity.compact()
    : controlSm = 24,
      controlMd = 28,
      controlLg = 32,
      rowHeight = 32,
      sidebarItemHeight = 28,
      switchWidth = 28,
      switchHeight = 16,
      checkboxSize = 14,
      dialogWidth = 440,
      menuMinWidth = 180,
      toastWidth = 340,
      emptyStateMaxWidth = 360,
      tooltipMaxWidth = 280;

  const AntDensity.comfortable()
    : controlSm = 28,
      controlMd = 32,
      controlLg = 36,
      rowHeight = 36,
      sidebarItemHeight = 32,
      switchWidth = 32,
      switchHeight = 18,
      checkboxSize = 16,
      dialogWidth = 480,
      menuMinWidth = 200,
      toastWidth = 360,
      emptyStateMaxWidth = 400,
      tooltipMaxWidth = 300;

  final double controlSm;
  final double controlMd;
  final double controlLg;
  final double rowHeight;
  final double sidebarItemHeight;
  final double switchWidth;
  final double switchHeight;
  final double checkboxSize;
  final double dialogWidth;
  final double menuMinWidth;
  final double toastWidth;
  final double emptyStateMaxWidth;
  final double tooltipMaxWidth;

  static AntDensity lerp(AntDensity a, AntDensity b, double t) {
    double l(double x, double y) => lerpDouble(x, y, t)!;
    return AntDensity(
      controlSm: l(a.controlSm, b.controlSm),
      controlMd: l(a.controlMd, b.controlMd),
      controlLg: l(a.controlLg, b.controlLg),
      rowHeight: l(a.rowHeight, b.rowHeight),
      sidebarItemHeight: l(a.sidebarItemHeight, b.sidebarItemHeight),
      switchWidth: l(a.switchWidth, b.switchWidth),
      switchHeight: l(a.switchHeight, b.switchHeight),
      checkboxSize: l(a.checkboxSize, b.checkboxSize),
      dialogWidth: l(a.dialogWidth, b.dialogWidth),
      menuMinWidth: l(a.menuMinWidth, b.menuMinWidth),
      toastWidth: l(a.toastWidth, b.toastWidth),
      emptyStateMaxWidth: l(a.emptyStateMaxWidth, b.emptyStateMaxWidth),
      tooltipMaxWidth: l(a.tooltipMaxWidth, b.tooltipMaxWidth),
    );
  }
}

/// Icon sizes.
@immutable
class AntIconSizes {
  const AntIconSizes();
  double get xs => 12;
  double get sm => 14;
  double get md => 16;
  double get lg => 20;
  double get xl => 24;

  /// Empty-state illustration icon.
  double get hero => 32;
}

/// Stroke widths and state opacities.
@immutable
class AntStroke {
  const AntStroke();

  /// Hairline borders and dividers.
  double get hairline => 1;

  /// Keyboard focus ring.
  double get focus => 2;

  /// Gap between a control and its focus ring.
  double get focusOffset => 1;

  /// Opacity applied to disabled controls.
  double get disabledOpacity => 0.45;

  /// Material elevation for Material-backed overlays (menus); Ant overlays
  /// use `AntTokens.shadow` instead.
  double get overlayElevation => 8;
}

/// Motion durations and curves.
@immutable
class AntMotion {
  const AntMotion();

  /// Hover / press feedback.
  Duration get fast => const Duration(milliseconds: 90);

  /// Toggles, tab indicator, popovers.
  Duration get base => const Duration(milliseconds: 150);

  /// Dialogs, theme switch, toasts.
  Duration get slow => const Duration(milliseconds: 240);

  /// How long a toast stays visible.
  Duration get toastDwell => const Duration(seconds: 4);

  /// Delay before a tooltip appears.
  Duration get tooltipWait => const Duration(milliseconds: 500);

  Curve get standard => Curves.easeOutCubic;
  Curve get emphasized => Curves.easeInOutCubicEmphasized;
  Curve get exit => Curves.easeInCubic;
}

/// Font families bundled with the `ui` package.
abstract final class AntFonts {
  static const String package = 'ui';
  static const String sans = 'Inter';
  static const String mono = 'JetBrainsMono';
}

/// Type scale. Styles carry no colour unless noted; components apply colour
/// tokens on top (`t.typo.body.copyWith(color: t.text2)`), or use the
/// pre-coloured defaults built by `AntTokens`.
@immutable
class AntType {
  const AntType({
    required this.caption,
    required this.small,
    required this.label,
    required this.body,
    required this.bodyStrong,
    required this.title,
    required this.heading,
    required this.display,
    required this.sectionLabel,
    required this.mono,
    required this.monoSmall,
    required this.kbd,
  });

  /// Builds the scale in [color].
  factory AntType.standard(Color color) {
    TextStyle sans(
      double size,
      FontWeight weight,
      double height, {
      double letterSpacing = 0,
    }) => TextStyle(
      fontFamily: AntFonts.sans,
      package: AntFonts.package,
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: letterSpacing,
      color: color,
    );
    TextStyle mono(double size, FontWeight weight) => TextStyle(
      fontFamily: AntFonts.mono,
      package: AntFonts.package,
      fontSize: size,
      fontWeight: weight,
      // The mono face is a variable font: drive its weight axis explicitly.
      fontVariations: [FontVariation.weight(weight.value.toDouble())],
      height: 1.4,
      color: color,
    );
    return AntType(
      caption: sans(11, FontWeight.w400, 1.35),
      small: sans(12, FontWeight.w400, 1.4),
      label: sans(12, FontWeight.w500, 1.35),
      body: sans(13, FontWeight.w400, 1.5),
      bodyStrong: sans(13, FontWeight.w500, 1.5),
      title: sans(15, FontWeight.w600, 1.35, letterSpacing: -0.1),
      heading: sans(18, FontWeight.w600, 1.3, letterSpacing: -0.2),
      display: sans(24, FontWeight.w600, 1.25, letterSpacing: -0.4),
      sectionLabel: sans(11, FontWeight.w600, 1.3, letterSpacing: 0.5),
      mono: mono(12, FontWeight.w400),
      monoSmall: mono(11, FontWeight.w500),
      kbd: mono(10.5, FontWeight.w500),
    );
  }

  final TextStyle caption;
  final TextStyle small;
  final TextStyle label;
  final TextStyle body;
  final TextStyle bodyStrong;
  final TextStyle title;
  final TextStyle heading;
  final TextStyle display;
  final TextStyle sectionLabel;
  final TextStyle mono;
  final TextStyle monoSmall;
  final TextStyle kbd;

  static AntType lerp(AntType a, AntType b, double t) {
    TextStyle l(TextStyle x, TextStyle y) => TextStyle.lerp(x, y, t)!;
    return AntType(
      caption: l(a.caption, b.caption),
      small: l(a.small, b.small),
      label: l(a.label, b.label),
      body: l(a.body, b.body),
      bodyStrong: l(a.bodyStrong, b.bodyStrong),
      title: l(a.title, b.title),
      heading: l(a.heading, b.heading),
      display: l(a.display, b.display),
      sectionLabel: l(a.sectionLabel, b.sectionLabel),
      mono: l(a.mono, b.mono),
      monoSmall: l(a.monoSmall, b.monoSmall),
      kbd: l(a.kbd, b.kbd),
    );
  }
}
