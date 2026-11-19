import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui/ui.dart';

/// Hosts [child] in a MaterialApp themed by [tokens] (dark by default).
Widget host(Widget child, {AntTokens? tokens}) => MaterialApp(
  theme: antTheme(tokens ?? AntTokens.dark()),
  home: Scaffold(body: Center(child: child)),
);

/// Asserts two colours are equal channel by channel (float precision).
void expectColor(Color actual, Color expected, {String? reason}) {
  const eps = 1e-6;
  expect(actual.a, closeTo(expected.a, eps), reason: '$reason (alpha)');
  expect(actual.r, closeTo(expected.r, eps), reason: '$reason (red)');
  expect(actual.g, closeTo(expected.g, eps), reason: '$reason (green)');
  expect(actual.b, closeTo(expected.b, eps), reason: '$reason (blue)');
}

/// `color-mix(in srgb, a p%, b)`, computed independently of Color.lerp.
Color cssMix(Color a, double percentOfA, Color b) {
  double ch(double x, double y) => x * percentOfA + y * (1 - percentOfA);
  return Color.from(
    alpha: ch(a.a, b.a),
    red: ch(a.r, b.r),
    green: ch(a.g, b.g),
    blue: ch(a.b, b.b),
  );
}

/// Foreground-painted focus rings ([AntFocusRing]) under [of].
Finder focusRings([Finder? of]) {
  final ring = find.byWidgetPredicate(
    (w) => w is DecoratedBox && w.position == DecorationPosition.foreground,
  );
  return of == null ? ring : find.descendant(of: of, matching: ring);
}

/// Fill colour of the first [AnimatedContainer] under [of].
Color? fillOf(WidgetTester tester, Finder of) {
  final c = tester.widget<AnimatedContainer>(
    find.descendant(of: of, matching: find.byType(AnimatedContainer)).first,
  );
  return (c.decoration as BoxDecoration?)?.color;
}

/// Puts the focus manager in keyboard ("traditional") highlight mode.
Future<void> useKeyboardHighlight(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.shiftLeft);
  await tester.pump();
  expect(FocusManager.instance.highlightMode, FocusHighlightMode.traditional);
}

/// The semantics node that owns [finder]'s widget.
SemanticsNode semanticsOf(WidgetTester tester, Finder finder) =>
    tester.getSemantics(finder);

/// Opacity applied by [AntDisabled] under [of], or null if none.
double? disabledOpacity(WidgetTester tester, Finder of) {
  final f = find.descendant(of: of, matching: find.byType(Opacity));
  if (f.evaluate().isEmpty) return null;
  return tester.widget<Opacity>(f.first).opacity;
}

/// Tests that document a known BUG are skipped unless run with
/// `flutter test --dart-define=RUN_BUGS=true`.
const bugSkip = !bool.fromEnvironment('RUN_BUGS');
