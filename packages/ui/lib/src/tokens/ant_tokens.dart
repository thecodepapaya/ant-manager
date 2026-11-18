import 'package:flutter/material.dart';

import 'scales.dart';

/// The single source of every visual value in Ant Manager (SPEC §10, #41).
///
/// Colour names mirror `docs/design/tokens.css`. Accent variants are derived
/// from one [accent] seed and the radius scale from one [radii] base, so a
/// brand change is one argument:
///
/// ```dart
/// final t = AntTokens.dark(accent: myAccent, radius: 4);
/// MaterialApp(theme: antTheme(t));
/// // in widgets:
/// final t = context.tokens;
/// ```
@immutable
class AntTokens extends ThemeExtension<AntTokens> {
  const AntTokens({
    required this.brightness,
    required this.bg,
    required this.bgSidebar,
    required this.surface,
    required this.surfaceSunken,
    required this.surface2,
    required this.raised,
    required this.inputBg,
    required this.hover,
    required this.active,
    required this.chipBg,
    required this.divider,
    required this.border,
    required this.borderSubtle,
    required this.borderStrong,
    required this.borderStronger,
    required this.raw,
    required this.text,
    required this.text2,
    required this.text3,
    required this.textSoft,
    required this.muted,
    required this.placeholder,
    required this.success,
    required this.successText,
    required this.info,
    required this.purple,
    required this.danger,
    required this.dangerText,
    required this.accent,
    required this.accentHover,
    required this.accentText,
    required this.accentTextHover,
    required this.onAccent,
    required this.accentSoft,
    required this.successSoft,
    required this.dangerSoft,
    required this.infoSoft,
    required this.focusRing,
    required this.shadowColor,
    required this.scrim,
    required this.radii,
    required this.typo,
    required this.density,
    this.space = const AntSpacing(),
    this.icon = const AntIconSizes(),
    this.stroke = const AntStroke(),
    this.motion = const AntMotion(),
  });

  /// Brand seed (tokens.css `--accent`).
  static const Color defaultAccent = Color(0xFFE8A54B);

  /// Dark theme (the default).
  factory AntTokens.dark({
    Color accent = defaultAccent,
    double radius = AntRadii.defaultBase,
    AntDensity density = const AntDensity.compact(),
  }) {
    const text = Color(0xFFEDE9E3);
    const success = Color(0xFF6CC28C);
    const danger = Color(0xFFE8796B);
    const info = Color(0xFF7FA8E8);
    return AntTokens(
      brightness: Brightness.dark,
      bg: const Color(0xFF121110),
      bgSidebar: const Color(0xFF171615),
      surface: const Color(0xFF181716),
      surfaceSunken: const Color(0xFF1A1917),
      surface2: const Color(0xFF1F1D1B),
      raised: const Color(0xFF1E1D1B),
      inputBg: const Color(0xFF141312),
      hover: const Color(0xFF1C1B19),
      active: const Color(0xFF262421),
      chipBg: const Color(0xFF23211F),
      divider: const Color(0xFF24221F),
      border: const Color(0xFF2A2826),
      borderSubtle: const Color(0xFF2F2C29),
      borderStrong: const Color(0xFF34312D),
      borderStronger: const Color(0xFF3A3733),
      raw: const Color(0xFF4A4640),
      text: text,
      text2: const Color(0xFFDAD5CD),
      text3: const Color(0xFFC9C4BB),
      textSoft: const Color(0xFFB7B2A9),
      muted: const Color(0xFF9A958C),
      placeholder: const Color(0xFF8F8A81),
      success: success,
      successText: const Color(0xFF8FD3A6),
      info: info,
      purple: const Color(0xFFB3A3F0),
      danger: danger,
      dangerText: const Color(0xFFF2A094),
      onAccent: const Color(0xFF1A1205),
      successSoft: _soft(success, Brightness.dark),
      dangerSoft: _soft(danger, Brightness.dark),
      infoSoft: _soft(info, Brightness.dark),
      shadowColor: const Color(0x73000000), // rgba(0,0,0,.45)
      scrim: const Color(0x99000000),
      radii: AntRadii(radius),
      typo: AntType.standard(text),
      density: density,
      // Placeholders; replaced by _withAccent below.
      accent: accent,
      accentHover: accent,
      accentText: accent,
      accentTextHover: accent,
      accentSoft: accent,
      focusRing: accent,
    )._withAccent(accent);
  }

  /// Light theme, built from the same seeds.
  factory AntTokens.light({
    Color accent = defaultAccent,
    double radius = AntRadii.defaultBase,
    AntDensity density = const AntDensity.compact(),
  }) {
    const text = Color(0xFF1A1917);
    const success = Color(0xFF3F9E64);
    const danger = Color(0xFFD0573F);
    const info = Color(0xFF4C7FD0);
    return AntTokens(
      brightness: Brightness.light,
      bg: const Color(0xFFFBFAF7),
      bgSidebar: const Color(0xFFF4F2EE),
      surface: const Color(0xFFFFFFFF),
      surfaceSunken: const Color(0xFFF4F2EE),
      surface2: const Color(0xFFF6F4F0),
      raised: const Color(0xFFFFFFFF),
      inputBg: const Color(0xFFFFFFFF),
      hover: const Color(0xFFF1EEE9),
      active: const Color(0xFFE9E5DE),
      chipBg: const Color(0xFFF1EEE9),
      divider: const Color(0xFFECE9E3),
      border: const Color(0xFFE3DFD8),
      borderSubtle: const Color(0xFFE0DCD4),
      borderStrong: const Color(0xFFD3CEC5),
      borderStronger: const Color(0xFFC9C3B9),
      raw: const Color(0xFFCFC9BF),
      text: text,
      text2: const Color(0xFF2E2C29),
      text3: const Color(0xFF3D3A36),
      textSoft: const Color(0xFF55514B),
      muted: const Color(0xFF6B665E),
      placeholder: const Color(0xFF77726A),
      success: success,
      successText: const Color(0xFF2B6E45),
      info: info,
      purple: const Color(0xFF7A62D6),
      danger: danger,
      dangerText: const Color(0xFFA8402B),
      onAccent: const Color(0xFF1A1205),
      successSoft: _soft(success, Brightness.light),
      dangerSoft: _soft(danger, Brightness.light),
      infoSoft: _soft(info, Brightness.light),
      shadowColor: const Color(0x24281E0A), // rgba(40,30,10,.14)
      scrim: const Color(0x4D1A1917),
      radii: AntRadii(radius),
      typo: AntType.standard(text),
      density: density,
      accent: accent,
      accentHover: accent,
      accentText: accent,
      accentTextHover: accent,
      accentSoft: accent,
      focusRing: accent,
    )._withAccent(accent);
  }

  static const Color _white = Color(0xFFFFFFFF);
  static const Color _black = Color(0xFF000000);

  /// `color-mix(in srgb, a p%, b)` == lerp from a toward b by (1 - p).
  static Color _mix(Color a, double percentOfA, Color b) =>
      Color.lerp(a, b, 1 - percentOfA)!;

  static Color _soft(Color c, Brightness b) =>
      c.withValues(alpha: b == Brightness.dark ? 0.16 : 0.12);

  /// Re-derives every accent variant from [seed] (tokens.css rules).
  AntTokens _withAccent(Color seed) {
    final dark = brightness == Brightness.dark;
    return copyWith(
      accent: seed,
      accentHover: dark ? _mix(seed, 0.85, _white) : _mix(seed, 0.88, _black),
      accentText: dark ? _mix(seed, 0.72, _white) : _mix(seed, 0.55, _black),
      accentTextHover: dark
          ? _mix(seed, 0.50, _white)
          : _mix(seed, 0.40, _black),
      accentSoft: _soft(seed, brightness),
      focusRing: seed.withValues(alpha: dark ? 0.7 : 0.8),
    );
  }

  final Brightness brightness;

  /// App background (`--bg`).
  final Color bg;

  /// Sidebar background (`--bg-sidebar`).
  final Color bgSidebar;

  /// Cards and panels (`--surface`).
  final Color surface;

  /// Recessed wells (`--surface-sunken`).
  final Color surfaceSunken;

  /// Secondary surface: segmented tracks, headers (`--surface-2`).
  final Color surface2;

  /// Menus, popovers, dialogs, toasts (`--raised`).
  final Color raised;

  /// Text field fill (`--input-bg`).
  final Color inputBg;

  /// Hover fill (`--hover`).
  final Color hover;

  /// Pressed / selected fill (`--active`).
  final Color active;

  /// Neutral chip and kbd fill (`--chip-bg`).
  final Color chipBg;

  /// Row dividers (`--divider`).
  final Color divider;

  /// Default border (`--border`).
  final Color border;

  /// `--border-subtle`.
  final Color borderSubtle;

  /// Inputs, hovered borders (`--border-strong`).
  final Color borderStrong;

  /// Unchecked controls (`--border-stronger`).
  final Color borderStronger;

  /// Raw / unprocessed indicator (`--raw`).
  final Color raw;

  /// Primary text (`--text`).
  final Color text;

  /// `--text-2`.
  final Color text2;

  /// `--text-3`.
  final Color text3;

  /// `--text-soft`.
  final Color textSoft;

  /// Muted text and icons (`--muted`).
  final Color muted;

  /// `--placeholder`.
  final Color placeholder;

  /// `--success`.
  final Color success;

  /// `--success-text`.
  final Color successText;

  /// `--info`.
  final Color info;

  /// `--purple`.
  final Color purple;

  /// `--danger`.
  final Color danger;

  /// `--danger-text`.
  final Color dangerText;

  /// Brand accent seed (`--accent`).
  final Color accent;

  /// Derived: `--accent-hover`.
  final Color accentHover;

  /// Derived: `--accent-text`.
  final Color accentText;

  /// Derived: `--accent-text-hover`.
  final Color accentTextHover;

  /// Text and icons on an accent fill (`--on-accent`).
  final Color onAccent;

  /// Derived: translucent accent fill (selection, warn chips).
  final Color accentSoft;

  /// Translucent success fill.
  final Color successSoft;

  /// Translucent danger fill.
  final Color dangerSoft;

  /// Translucent info fill.
  final Color infoSoft;

  /// Derived: keyboard focus ring.
  final Color focusRing;

  /// Shadow colour (`--shadow`).
  final Color shadowColor;

  /// Modal barrier colour.
  final Color scrim;

  /// Radius scale derived from one base.
  final AntRadii radii;

  /// Type scale (Inter + JetBrains Mono), coloured with [text].
  final AntType typo;

  /// Control sizes.
  final AntDensity density;

  /// 4-pt spacing scale.
  final AntSpacing space;

  /// Icon sizes.
  final AntIconSizes icon;

  /// Stroke widths and state opacities.
  final AntStroke stroke;

  /// Durations and curves.
  final AntMotion motion;

  bool get isDark => brightness == Brightness.dark;

  /// `--shadow`: menus, popovers, dialogs, toasts.
  List<BoxShadow> get shadow => [
    BoxShadow(
      color: shadowColor,
      offset: Offset(0, space.lg),
      blurRadius: space.huge,
    ),
  ];

  /// Same tokens with a new accent seed; all accent variants re-derive.
  AntTokens withAccent(Color seed) => _withAccent(seed);

  /// Same tokens with a new radius base; the whole scale re-derives.
  AntTokens withRadius(double base) => copyWith(radii: AntRadii(base));

  @override
  AntTokens copyWith({
    Brightness? brightness,
    Color? bg,
    Color? bgSidebar,
    Color? surface,
    Color? surfaceSunken,
    Color? surface2,
    Color? raised,
    Color? inputBg,
    Color? hover,
    Color? active,
    Color? chipBg,
    Color? divider,
    Color? border,
    Color? borderSubtle,
    Color? borderStrong,
    Color? borderStronger,
    Color? raw,
    Color? text,
    Color? text2,
    Color? text3,
    Color? textSoft,
    Color? muted,
    Color? placeholder,
    Color? success,
    Color? successText,
    Color? info,
    Color? purple,
    Color? danger,
    Color? dangerText,
    Color? accent,
    Color? accentHover,
    Color? accentText,
    Color? accentTextHover,
    Color? onAccent,
    Color? accentSoft,
    Color? successSoft,
    Color? dangerSoft,
    Color? infoSoft,
    Color? focusRing,
    Color? shadowColor,
    Color? scrim,
    AntRadii? radii,
    AntType? typo,
    AntDensity? density,
  }) {
    return AntTokens(
      brightness: brightness ?? this.brightness,
      bg: bg ?? this.bg,
      bgSidebar: bgSidebar ?? this.bgSidebar,
      surface: surface ?? this.surface,
      surfaceSunken: surfaceSunken ?? this.surfaceSunken,
      surface2: surface2 ?? this.surface2,
      raised: raised ?? this.raised,
      inputBg: inputBg ?? this.inputBg,
      hover: hover ?? this.hover,
      active: active ?? this.active,
      chipBg: chipBg ?? this.chipBg,
      divider: divider ?? this.divider,
      border: border ?? this.border,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      borderStrong: borderStrong ?? this.borderStrong,
      borderStronger: borderStronger ?? this.borderStronger,
      raw: raw ?? this.raw,
      text: text ?? this.text,
      text2: text2 ?? this.text2,
      text3: text3 ?? this.text3,
      textSoft: textSoft ?? this.textSoft,
      muted: muted ?? this.muted,
      placeholder: placeholder ?? this.placeholder,
      success: success ?? this.success,
      successText: successText ?? this.successText,
      info: info ?? this.info,
      purple: purple ?? this.purple,
      danger: danger ?? this.danger,
      dangerText: dangerText ?? this.dangerText,
      accent: accent ?? this.accent,
      accentHover: accentHover ?? this.accentHover,
      accentText: accentText ?? this.accentText,
      accentTextHover: accentTextHover ?? this.accentTextHover,
      onAccent: onAccent ?? this.onAccent,
      accentSoft: accentSoft ?? this.accentSoft,
      successSoft: successSoft ?? this.successSoft,
      dangerSoft: dangerSoft ?? this.dangerSoft,
      infoSoft: infoSoft ?? this.infoSoft,
      focusRing: focusRing ?? this.focusRing,
      shadowColor: shadowColor ?? this.shadowColor,
      scrim: scrim ?? this.scrim,
      radii: radii ?? this.radii,
      typo: typo ?? this.typo,
      density: density ?? this.density,
      space: space,
      icon: icon,
      stroke: stroke,
      motion: motion,
    );
  }

  @override
  AntTokens lerp(covariant AntTokens? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return AntTokens(
      brightness: t < 0.5 ? brightness : other.brightness,
      bg: c(bg, other.bg),
      bgSidebar: c(bgSidebar, other.bgSidebar),
      surface: c(surface, other.surface),
      surfaceSunken: c(surfaceSunken, other.surfaceSunken),
      surface2: c(surface2, other.surface2),
      raised: c(raised, other.raised),
      inputBg: c(inputBg, other.inputBg),
      hover: c(hover, other.hover),
      active: c(active, other.active),
      chipBg: c(chipBg, other.chipBg),
      divider: c(divider, other.divider),
      border: c(border, other.border),
      borderSubtle: c(borderSubtle, other.borderSubtle),
      borderStrong: c(borderStrong, other.borderStrong),
      borderStronger: c(borderStronger, other.borderStronger),
      raw: c(raw, other.raw),
      text: c(text, other.text),
      text2: c(text2, other.text2),
      text3: c(text3, other.text3),
      textSoft: c(textSoft, other.textSoft),
      muted: c(muted, other.muted),
      placeholder: c(placeholder, other.placeholder),
      success: c(success, other.success),
      successText: c(successText, other.successText),
      info: c(info, other.info),
      purple: c(purple, other.purple),
      danger: c(danger, other.danger),
      dangerText: c(dangerText, other.dangerText),
      accent: c(accent, other.accent),
      accentHover: c(accentHover, other.accentHover),
      accentText: c(accentText, other.accentText),
      accentTextHover: c(accentTextHover, other.accentTextHover),
      onAccent: c(onAccent, other.onAccent),
      accentSoft: c(accentSoft, other.accentSoft),
      successSoft: c(successSoft, other.successSoft),
      dangerSoft: c(dangerSoft, other.dangerSoft),
      infoSoft: c(infoSoft, other.infoSoft),
      focusRing: c(focusRing, other.focusRing),
      shadowColor: c(shadowColor, other.shadowColor),
      scrim: c(scrim, other.scrim),
      radii: AntRadii.lerp(radii, other.radii, t),
      typo: AntType.lerp(typo, other.typo, t),
      density: AntDensity.lerp(density, other.density, t),
    );
  }
}

/// `context.tokens`: the current [AntTokens]. The theme must come from
/// [antTheme] (or otherwise register an [AntTokens] extension).
extension AntTokensContext on BuildContext {
  AntTokens get tokens {
    final t = Theme.of(this).extension<AntTokens>();
    if (t == null) {
      throw FlutterError(
        'No AntTokens in Theme. Build the theme with antTheme().',
      );
    }
    return t;
  }
}
