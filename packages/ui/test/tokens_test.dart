import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui/ui.dart';

import 'helpers.dart';

const _white = Color(0xFFFFFFFF);
const _black = Color(0xFF000000);

/// Seeds to derive accent variants from (brand + a few arbitrary ones).
const _seeds = <Color>[
  AntTokens.defaultAccent,
  Color(0xFF6E9BEA),
  Color(0xFF000000),
  Color(0xFFFFFFFF),
  Color(0x80FF0000),
];

/// tokens.css name -> AntTokens role.
final _roles = <String, Color Function(AntTokens)>{
  'accent': (t) => t.accent,
  'bg': (t) => t.bg,
  'bg-sidebar': (t) => t.bgSidebar,
  'surface': (t) => t.surface,
  'surface-sunken': (t) => t.surfaceSunken,
  'surface-2': (t) => t.surface2,
  'raised': (t) => t.raised,
  'input-bg': (t) => t.inputBg,
  'hover': (t) => t.hover,
  'active': (t) => t.active,
  'chip-bg': (t) => t.chipBg,
  'divider': (t) => t.divider,
  'border': (t) => t.border,
  'border-subtle': (t) => t.borderSubtle,
  'border-strong': (t) => t.borderStrong,
  'border-stronger': (t) => t.borderStronger,
  'raw': (t) => t.raw,
  'text': (t) => t.text,
  'text-2': (t) => t.text2,
  'text-3': (t) => t.text3,
  'text-soft': (t) => t.textSoft,
  'muted': (t) => t.muted,
  'placeholder': (t) => t.placeholder,
  'success': (t) => t.success,
  'success-text': (t) => t.successText,
  'info': (t) => t.info,
  'purple': (t) => t.purple,
  'danger': (t) => t.danger,
  'danger-text': (t) => t.dangerText,
  'on-accent': (t) => t.onAccent,
};

final _accentVariants = <String, Color Function(AntTokens)>{
  'accent-hover': (t) => t.accentHover,
  'accent-text': (t) => t.accentText,
  'accent-text-hover': (t) => t.accentTextHover,
};

/// All colour roles, for "unchanged" comparisons.
final _allRoles = <String, Color Function(AntTokens)>{
  ..._roles,
  ..._accentVariants,
  'accentSoft': (t) => t.accentSoft,
  'successSoft': (t) => t.successSoft,
  'dangerSoft': (t) => t.dangerSoft,
  'infoSoft': (t) => t.infoSoft,
  'focusRing': (t) => t.focusRing,
  'shadowColor': (t) => t.shadowColor,
  'scrim': (t) => t.scrim,
};

/// Parses `docs/design/tokens.css` (dark block, light block).
({String dark, String light}) _cssBlocks() {
  final css = File('../../docs/design/tokens.css').readAsStringSync();
  final lightStart = css.indexOf('.ant[data-theme="light"]');
  if (lightStart <= 0) throw StateError('no light block in tokens.css');
  return (dark: css.substring(0, lightStart), light: css.substring(lightStart));
}

Map<String, Color> _hexes(String block) => {
  for (final m in RegExp(
    r'--([a-z0-9-]+):\s*#([0-9A-Fa-f]{6})\s*;',
  ).allMatches(block))
    m.group(1)!: Color(0xFF000000 | int.parse(m.group(2)!, radix: 16)),
};

/// `--name: color-mix(in srgb, var(--accent) P%, white|black)`.
Map<String, (double, Color)> _mixes(String block) => {
  for (final m in RegExp(
    r'--([a-z-]+):\s*color-mix\(in srgb,\s*var\(--accent\)\s*(\d+)%,\s*(white|black)\)',
  ).allMatches(block))
    m.group(1)!: (
      int.parse(m.group(2)!) / 100,
      m.group(3) == 'white' ? _white : _black,
    ),
};

void main() {
  group('tokens.css parity', () {
    final blocks = _cssBlocks();
    final darkCss = _hexes(blocks.dark);
    final lightCss = {...darkCss, ..._hexes(blocks.light)};

    test('every colour role matches tokens.css (dark)', () {
      final t = AntTokens.dark();
      for (final e in _roles.entries) {
        expect(darkCss, contains(e.key), reason: '--${e.key} in tokens.css');
        expectColor(e.value(t), darkCss[e.key]!, reason: 'dark --${e.key}');
      }
    });

    test('every colour role matches tokens.css (light)', () {
      final t = AntTokens.light();
      for (final e in _roles.entries) {
        if (e.key == 'accent') continue; // accent seed is shared
        expectColor(e.value(t), lightCss[e.key]!, reason: 'light --${e.key}');
      }
      expectColor(t.accent, darkCss['accent']!, reason: 'light --accent');
    });

    test('accent variants follow the tokens.css color-mix rules', () {
      final darkMix = _mixes(blocks.dark);
      final lightMix = _mixes(blocks.light);
      expect(darkMix.keys, containsAll(_accentVariants.keys));
      expect(lightMix.keys, containsAll(_accentVariants.keys));
      for (final seed in _seeds) {
        final d = AntTokens.dark(accent: seed);
        final l = AntTokens.light(accent: seed);
        for (final e in _accentVariants.entries) {
          final (dp, dTo) = darkMix[e.key]!;
          final (lp, lTo) = lightMix[e.key]!;
          expectColor(
            e.value(d),
            cssMix(seed, dp, dTo),
            reason: 'dark ${e.key} for $seed',
          );
          expectColor(
            e.value(l),
            cssMix(seed, lp, lTo),
            reason: 'light ${e.key} for $seed',
          );
        }
      }
    });

    test('radius base and shadow match tokens.css', () {
      final css = File('../../docs/design/tokens.css').readAsStringSync();
      final base = RegExp(r'--radius:\s*(\d+)px').firstMatch(css)!.group(1)!;
      expect(AntRadii.defaultBase, double.parse(base));
      expect(AntTokens.dark().radii.base, AntRadii.defaultBase);

      final d = AntTokens.dark().shadow.single;
      expect(d.offset, const Offset(0, 12));
      expect(d.blurRadius, 32);
      expect(d.color.a, closeTo(.45, 1 / 255));
      final l = AntTokens.light().shadow.single;
      expect(l.offset, const Offset(0, 12));
      expect(l.blurRadius, 32);
      expect(l.color.a, closeTo(.14, 1 / 255));
      expect((l.color.r * 255).round(), 40);
      expect((l.color.g * 255).round(), 30);
      expect((l.color.b * 255).round(), 10);
    });
  });

  group('accent variants (author claims)', () {
    test('dark: lerp toward white by .15 / .28 / .5', () {
      for (final seed in _seeds) {
        final t = AntTokens.dark(accent: seed);
        expectColor(t.accent, seed, reason: 'accent');
        expectColor(t.accentHover, cssMix(seed, .85, _white));
        expectColor(t.accentText, cssMix(seed, .72, _white));
        expectColor(t.accentTextHover, cssMix(seed, .50, _white));
      }
    });

    test('light: lerp toward black by .12 / .45 / .60', () {
      for (final seed in _seeds) {
        final t = AntTokens.light(accent: seed);
        expectColor(t.accent, seed, reason: 'accent');
        expectColor(t.accentHover, cssMix(seed, .88, _black));
        expectColor(t.accentText, cssMix(seed, .55, _black));
        expectColor(t.accentTextHover, cssMix(seed, .40, _black));
      }
    });

    test('accent text variants get progressively further from the seed', () {
      // Hover is a subtle shift; text variants are stronger.
      double dist(Color a, Color b) =>
          (a.r - b.r).abs() + (a.g - b.g).abs() + (a.b - b.b).abs();
      for (final t in [AntTokens.dark(), AntTokens.light()]) {
        final h = dist(t.accentHover, t.accent);
        final tx = dist(t.accentText, t.accent);
        final txh = dist(t.accentTextHover, t.accent);
        expect(h, lessThan(tx));
        expect(tx, lessThan(txh));
      }
    });
  });

  group('withAccent', () {
    const seed = Color(0xFF5FBF8A);

    for (final b in Brightness.values) {
      AntTokens make({Color accent = AntTokens.defaultAccent}) =>
          b == Brightness.dark
          ? AntTokens.dark(accent: accent)
          : AntTokens.light(accent: accent);

      test('$b: same variants as the factory with that seed', () {
        final viaWith = make().withAccent(seed);
        final viaFactory = make(accent: seed);
        for (final e in _allRoles.entries) {
          expectColor(
            e.value(viaWith),
            e.value(viaFactory),
            reason: '${e.key} via withAccent vs factory',
          );
        }
      });

      test('$b: leaves every non-accent role unchanged', () {
        final before = make();
        final after = before.withAccent(seed);
        const accentRoles = {
          'accent',
          'accent-hover',
          'accent-text',
          'accent-text-hover',
          'accentSoft',
          'focusRing',
        };
        for (final e in _allRoles.entries) {
          if (accentRoles.contains(e.key)) continue;
          expectColor(e.value(after), e.value(before), reason: e.key);
        }
        expect(after.brightness, before.brightness);
        expect(after.radii, before.radii);
        expect(after.density.controlMd, before.density.controlMd);
        expect(after.typo.body, before.typo.body);
      });

      test('$b: accent-derived roles do change', () {
        final before = make();
        final after = before.withAccent(seed);
        expect(after.accent, isNot(before.accent));
        expect(after.accentHover, isNot(before.accentHover));
        expect(after.accentSoft, isNot(before.accentSoft));
        expect(after.focusRing, isNot(before.focusRing));
      });
    }

    test('withRadius re-derives the scale and keeps colours', () {
      final t = AntTokens.dark().withRadius(10);
      expect(t.radii.base, 10);
      expect(t.radii.xl, closeTo(16.7, 1e-9));
      expectColor(t.accent, AntTokens.defaultAccent);
    });
  });

  group('radius scale', () {
    test('derives xs..xl from the base', () {
      for (final base in [6.0, 4.0, 10.0]) {
        final r = AntRadii(base);
        expect(r.xs, closeTo(base * .67, 1e-9));
        expect(r.sm, closeTo(base * .83, 1e-9));
        expect(r.md, base);
        expect(r.lg, closeTo(base * 1.33, 1e-9));
        expect(r.xl, closeTo(base * 1.67, 1e-9));
        expect(r.brXs, BorderRadius.circular(base * .67));
        expect(r.brSm, BorderRadius.circular(base * .83));
        expect(r.brMd, BorderRadius.circular(base));
        expect(r.brLg, BorderRadius.circular(base * 1.33));
        expect(r.brXl, BorderRadius.circular(base * 1.67));
        expect(r.brPill.topLeft.x, greaterThan(base * 10));
      }
    });

    test('radius 0 squares everything, including pills', () {
      final t = AntTokens.dark(radius: 0);
      final r = t.radii;
      for (final v in [r.xs, r.sm, r.md, r.lg, r.xl]) {
        expect(v, 0);
      }
      for (final br in [r.brXs, r.brSm, r.brMd, r.brLg, r.brXl, r.brPill]) {
        expect(br, BorderRadius.zero);
      }
      expect(AntTokens.light(radius: 0).radii.brPill, BorderRadius.zero);
    });

    test('AntRadii equality is by base', () {
      expect(const AntRadii(6), const AntRadii(6));
      expect(const AntRadii(6).hashCode, const AntRadii(6).hashCode);
      expect(const AntRadii(6), isNot(const AntRadii(4)));
    });
  });

  group('lerp', () {
    final dark = AntTokens.dark(radius: 4);
    final light = AntTokens.light(
      accent: const Color(0xFF6E9BEA),
      radius: 10,
      density: const AntDensity.comfortable(),
    );

    test('endpoints reproduce each side', () {
      final a = dark.lerp(light, 0);
      final b = dark.lerp(light, 1);
      for (final e in _allRoles.entries) {
        expectColor(e.value(a), e.value(dark), reason: '${e.key} @0');
        expectColor(e.value(b), e.value(light), reason: '${e.key} @1');
      }
      expect(a.radii.base, 4);
      expect(b.radii.base, 10);
      expect(b.density.controlMd, light.density.controlMd);
    });

    test('midpoint interpolates colours, radius, density and type', () {
      final m = dark.lerp(light, .5);
      expectColor(m.bg, Color.lerp(dark.bg, light.bg, .5)!, reason: 'bg');
      expectColor(
        m.accent,
        Color.lerp(dark.accent, light.accent, .5)!,
        reason: 'accent',
      );
      expect(m.radii.base, 7);
      expect(
        m.density.controlMd,
        (dark.density.controlMd + light.density.controlMd) / 2,
      );
      expect(m.typo.body.color, Color.lerp(dark.text, light.text, .5));
    });

    test('brightness flips at t = 0.5', () {
      expect(dark.lerp(light, .49).brightness, Brightness.dark);
      expect(dark.lerp(light, .5).brightness, Brightness.light);
      expect(light.lerp(dark, .49).brightness, Brightness.light);
      expect(light.lerp(dark, .5).brightness, Brightness.dark);
    });

    test('lerp with null returns this', () {
      expect(identical(dark.lerp(null, .5), dark), isTrue);
    });

    test('ThemeData.lerp carries the extension through', () {
      final m = ThemeData.lerp(antTheme(dark), antTheme(light), .25);
      final t = m.extension<AntTokens>()!;
      expectColor(t.bg, Color.lerp(dark.bg, light.bg, .25)!, reason: 'bg');
    });
  });

  group('antTheme', () {
    test('registers the tokens and maps core roles', () {
      final t = AntTokens.light();
      final theme = antTheme(t);
      expect(identical(theme.extension<AntTokens>(), t), isTrue);
      expect(theme.brightness, Brightness.light);
      expect(theme.colorScheme.primary, t.accent);
      expect(theme.colorScheme.onPrimary, t.onAccent);
      expect(theme.scaffoldBackgroundColor, t.bg);
      expect(antTheme(AntTokens.dark()).brightness, Brightness.dark);
    });
  });

  group('context.tokens', () {
    testWidgets('returns the registered extension', (tester) async {
      final t = AntTokens.dark(accent: const Color(0xFF123456));
      AntTokens? seen;
      await tester.pumpWidget(
        MaterialApp(
          theme: antTheme(t),
          home: Builder(
            builder: (context) {
              seen = context.tokens;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(identical(seen, t), isTrue);
    });

    testWidgets('throws a FlutterError without an AntTokens theme', (
      tester,
    ) async {
      Object? error;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(),
          home: Builder(
            builder: (context) {
              try {
                context.tokens;
              } catch (e) {
                error = e;
              }
              return const SizedBox();
            },
          ),
        ),
      );
      expect(error, isA<FlutterError>());
      expect(error.toString(), contains('antTheme'));
    });
  });
}
