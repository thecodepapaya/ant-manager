import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui/ui.dart';

import 'helpers.dart';

/// One AntInteractive-based control under test.
class _Case {
  const _Case(this.name, this.build, {this.label});
  final String name;

  /// Builds the control; a null [onTap] disables it.
  final Widget Function(VoidCallback? onTap, FocusNode node) build;

  /// Expected semantics label, if any.
  final String? label;
}

final _cases = <_Case>[
  _Case(
    'AntButton',
    (onTap, node) =>
        AntButton(label: 'Save', onPressed: onTap, focusNode: node),
    label: 'Save',
  ),
  _Case(
    'AntButton.primary',
    (onTap, node) =>
        AntButton.primary(label: 'Go', onPressed: onTap, focusNode: node),
    label: 'Go',
  ),
  _Case(
    'AntIconButton',
    (onTap, node) => AntIconButton(
      icon: Icons.add,
      tooltip: 'Add',
      onPressed: onTap,
      focusNode: node,
    ),
    label: 'Add',
  ),
  _Case(
    'AntSwitch',
    (onTap, node) => AntSwitch(
      value: false,
      onChanged: onTap == null ? null : (_) => onTap(),
      semanticLabel: 'Sync',
      focusNode: node,
    ),
    label: 'Sync',
  ),
  _Case(
    'AntCheckbox',
    (onTap, node) => AntCheckbox(
      value: false,
      onChanged: onTap == null ? null : (_) => onTap(),
      label: 'Remember',
      focusNode: node,
    ),
    label: 'Remember',
  ),
  _Case(
    'AntSidebarItem',
    (onTap, node) => SizedBox(
      width: 200,
      child: AntSidebarItem(label: 'Today', onPressed: onTap),
    ),
    label: 'Today',
  ),
  _Case(
    'AntCard',
    (onTap, node) => SizedBox(
      width: 200,
      child: AntCard(
        semanticLabel: 'Open card',
        onPressed: onTap,
        child: const SizedBox(height: 10),
      ),
    ),
    label: 'Open card',
  ),
  _Case(
    'AntCitationChip',
    (onTap, node) => AntCitationChip(label: '3', onPressed: onTap),
    label: 'Citation 3',
  ),
];

// AntInteractive's GestureDetector adds its own tap semantics, which clash
// with the outer Semantics(onTap:) and split into an unlabeled child node.
const _bugDuplicateTapNode =
    'BUG: interactive.dart:125 GestureDetector lacks excludeFromSemantics; '
    'every control gets an extra unlabeled child node with a tap action';

// Semantics(focused: false) still sets the focusable/focus-state flag.
const _bugFocusable =
    'BUG: interactive.dart:103 focused: active && _hasFocus passes false '
    '(not null) when disabled, so disabled controls report isFocusable';

/// The shipping platforms (keyboard/mouse highlight mode by default).
final _desktop = TargetPlatformVariant(const {
  TargetPlatform.macOS,
  TargetPlatform.windows,
});

Finder _interactive() => find.byType(AntInteractive).first;

/// Moves keyboard focus onto the first focusable control.
Future<void> _tabIn(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.pump();
}

void main() {
  group('AntInteractive controls', () {
    for (final c in _cases) {
      group(c.name, () {
        testWidgets('fires on tap', (tester) async {
          var taps = 0;
          final node = FocusNode();
          addTearDown(node.dispose);
          await tester.pumpWidget(host(c.build(() => taps++, node)));
          await tester.tap(_interactive());
          await tester.pump();
          expect(taps, 1);
        });

        for (final key in [
          LogicalKeyboardKey.enter,
          LogicalKeyboardKey.space,
        ]) {
          testWidgets('fires on ${key.keyLabel} when focused', (tester) async {
            var taps = 0;
            final node = FocusNode();
            addTearDown(node.dispose);
            await tester.pumpWidget(host(c.build(() => taps++, node)));
            await _tabIn(tester);
            await tester.sendKeyEvent(key);
            await tester.pump();
            expect(taps, 1);
          });
        }

        testWidgets('disabled when callback is null', (tester) async {
          final node = FocusNode();
          addTearDown(node.dispose);
          await tester.pumpWidget(host(c.build(null, node)));
          if (c.name == 'AntCard') {
            // A card without onPressed is plain content, not a control.
            expect(find.byType(AntInteractive), findsNothing);
            return;
          }
          // No tap handler, nothing to activate; not focusable via Tab.
          await tester.tap(_interactive(), warnIfMissed: false);
          await _tabIn(tester);
          expect(
            semanticsOf(tester, _interactive()),
            isSemantics(
              hasEnabledState: true,
              isEnabled: false,
              hasTapAction: false,
            ),
          );
        });

        testWidgets(
          'disabled control is not announced as focusable ($_bugFocusable)',
          (tester) async {
            final handle = tester.ensureSemantics();
            final node = FocusNode();
            addTearDown(node.dispose);
            await tester.pumpWidget(host(c.build(null, node)));
            if (c.name == 'AntCard') return handle.dispose();
            expect(
              semanticsOf(tester, _interactive()),
              isSemantics(isFocusable: false, hasFocusAction: false),
            );
            handle.dispose();
          },
        );

        testWidgets('one semantics node with the label and enabled state', (
          tester,
        ) async {
          final handle = tester.ensureSemantics();
          final node = FocusNode();
          addTearDown(node.dispose);
          await tester.pumpWidget(host(c.build(() {}, node)));
          final s = semanticsOf(tester, _interactive());
          expect(
            s,
            isSemantics(
              label: c.label,
              hasEnabledState: true,
              isEnabled: true,
              hasTapAction: true,
              isFocusable: true,
            ),
          );
          handle.dispose();
        });

        testWidgets('no extra child semantics node ($_bugDuplicateTapNode)', (
          tester,
        ) async {
          final handle = tester.ensureSemantics();
          final node = FocusNode();
          addTearDown(node.dispose);
          await tester.pumpWidget(host(c.build(() {}, node)));
          final s = semanticsOf(tester, _interactive());
          final children = <SemanticsNode>[];
          s.visitChildren((n) {
            children.add(n);
            return true;
          });
          expect(children, isEmpty, reason: 'child nodes: $children');
          handle.dispose();
        });

        testWidgets('focus ring only on keyboard focus', (tester) async {
          final node = FocusNode();
          addTearDown(node.dispose);
          await tester.pumpWidget(host(c.build(() {}, node)));
          expect(focusRings(_interactive()), findsNothing);

          final fm = tester.binding.focusManager;
          addTearDown(
            () => fm.highlightStrategy = FocusHighlightStrategy.automatic,
          );

          // Focused while in touch/pointer mode: no ring.
          fm.highlightStrategy = FocusHighlightStrategy.alwaysTouch;
          await _tabIn(tester);
          final focused = fm.primaryFocus!;
          expect(
            find.descendant(
              of: _interactive(),
              matching: find.byWidgetPredicate(
                (w) => w is Focus && w.focusNode == focused,
              ),
            ),
            findsOneWidget,
            reason: 'Tab focuses the control',
          );
          expect(focusRings(_interactive()), findsNothing);

          // Keyboard highlight mode: the ring appears.
          fm.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
          await tester.pump();
          expect(focusRings(_interactive()), findsOneWidget);

          // Losing focus hides it.
          focused.unfocus();
          await tester.pumpAndSettle();
          expect(focusRings(_interactive()), findsNothing);
        });
      });
    }

    testWidgets('disabled controls are dimmed with the token opacity', (
      tester,
    ) async {
      final t = AntTokens.dark();
      for (final c in _cases.where(
        (c) =>
            c.name != 'AntSidebarItem' &&
            c.name != 'AntCard' &&
            c.name != 'AntCitationChip',
      )) {
        final node = FocusNode();
        await tester.pumpWidget(host(c.build(null, node), tokens: t));
        expect(
          disabledOpacity(tester, _interactive()),
          t.stroke.disabledOpacity,
          reason: c.name,
        );
        await tester.pumpWidget(host(c.build(() {}, node), tokens: t));
        expect(disabledOpacity(tester, _interactive()), isNull, reason: c.name);
        node.dispose();
      }
    });
  });

  group('AntButton.primary', () {
    testWidgets('fill is accent, accentHover on hover', (tester) async {
      final t = AntTokens.dark(accent: const Color(0xFF6E9BEA));
      await tester.pumpWidget(
        host(
          AntButton.primary(label: 'Go', onPressed: () {}),
          tokens: t,
        ),
      );
      final btn = find.byType(AntButton);
      expect(fillOf(tester, btn), t.accent);

      final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await g.addPointer(location: Offset.zero);
      addTearDown(g.removePointer);
      await g.moveTo(tester.getCenter(btn));
      await tester.pumpAndSettle();
      expect(fillOf(tester, btn), t.accentHover);

      await g.moveTo(Offset.zero);
      await tester.pumpAndSettle();
      expect(fillOf(tester, btn), t.accent);
    }, variant: _desktop);

    testWidgets('light theme uses light accent variants', (tester) async {
      final t = AntTokens.light();
      await tester.pumpWidget(
        host(
          AntButton.primary(label: 'Go', onPressed: () {}),
          tokens: t,
        ),
      );
      final btn = find.byType(AntButton);
      final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await g.addPointer(location: tester.getCenter(btn));
      addTearDown(g.removePointer);
      await tester.pumpAndSettle();
      expect(fillOf(tester, btn), t.accentHover);
    }, variant: _desktop);
  });

  group('AntSwitch', () {
    for (final v in [false, true]) {
      testWidgets('value $v: callback receives ${!v}, semantics toggled=$v', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        final got = <bool>[];
        await tester.pumpWidget(
          host(AntSwitch(value: v, onChanged: got.add, semanticLabel: 'Sync')),
        );
        await tester.tap(find.byType(AntSwitch));
        expect(got, [!v]);
        expect(
          semanticsOf(tester, _interactive()),
          isSemantics(
            label: 'Sync',
            hasToggledState: true,
            isToggled: v,
            isButton: false,
          ),
        );
        handle.dispose();
      });
    }
  });

  group('AntCheckbox', () {
    for (final v in [false, true]) {
      testWidgets('value $v: callback receives ${!v}, semantics checked=$v', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        final got = <bool>[];
        await tester.pumpWidget(
          host(AntCheckbox(value: v, onChanged: got.add, label: 'Remember')),
        );
        await tester.tap(find.byType(AntCheckbox));
        expect(got, [!v]);
        expect(
          semanticsOf(tester, _interactive()),
          isSemantics(
            label: 'Remember',
            hasCheckedState: true,
            isChecked: v,
            isButton: false,
          ),
        );
        handle.dispose();
      });
    }

    testWidgets('tapping the label toggles', (tester) async {
      final got = <bool>[];
      await tester.pumpWidget(
        host(AntCheckbox(value: false, onChanged: got.add, label: 'Remember')),
      );
      await tester.tap(find.text('Remember'));
      expect(got, [true]);
    });

    testWidgets('shows a check icon only when checked', (tester) async {
      await tester.pumpWidget(
        host(AntCheckbox(value: true, onChanged: (_) {})),
      );
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      await tester.pumpWidget(
        host(AntCheckbox(value: false, onChanged: (_) {})),
      );
      expect(find.byIcon(Icons.check_rounded), findsNothing);
    });
  });

  group('AntTabs', () {
    Widget tabs(String value, ValueChanged<String>? onChanged) =>
        AntTabs<String>(
          value: value,
          onChanged: onChanged,
          tabs: const [
            AntTab(value: 'day', label: 'Day'),
            AntTab(value: 'week', label: 'Week'),
            AntTab(value: 'month', label: 'Month'),
          ],
        );

    testWidgets('onChanged gets the tapped value', (tester) async {
      final got = <String>[];
      await tester.pumpWidget(host(tabs('day', got.add)));
      await tester.tap(find.text('Week'));
      await tester.tap(find.text('Month'));
      expect(got, ['week', 'month']);
    });

    testWidgets('Tab moves between segments; Enter selects', (tester) async {
      final got = <String>[];
      await tester.pumpWidget(host(tabs('day', got.add)));
      await _tabIn(tester);
      await _tabIn(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await _tabIn(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(got, ['week', 'month']);
    });

    testWidgets('semantics: selected flag on the current segment only', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(host(tabs('week', (_) {})));
      final nodes = find.byType(AntInteractive);
      expect(nodes, findsNWidgets(3));
      for (var i = 0; i < 3; i++) {
        expect(
          semanticsOf(tester, nodes.at(i)),
          isSemantics(
            label: ['Day', 'Week', 'Month'][i],
            hasSelectedState: true,
            isSelected: i == 1,
            isInMutuallyExclusiveGroup: true,
            isButton: true,
          ),
        );
      }
      handle.dispose();
    });

    testWidgets('null onChanged disables every segment', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(host(tabs('day', null)));
      for (final e in find.byType(AntInteractive).evaluate()) {
        expect(
          tester.getSemantics(find.byWidget(e.widget)),
          isSemantics(isEnabled: false, hasTapAction: false),
        );
      }
      handle.dispose();
    });
  });

  testWidgets('AntSidebarItem / AntCard label is announced once '
      '(BUG: navigation.dart:135 and surfaces.dart:69 AntInteractive without '
      'excludeChildSemantics; the label Text is read again as a second node)', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    for (final w in [
      AntSidebarItem(label: 'Today', onPressed: () {}),
      AntCard(title: 'Today', onPressed: () {}, child: const SizedBox()),
    ]) {
      await tester.pumpWidget(host(SizedBox(width: 200, child: w)));
      final labels = <String>[];
      void collect(SemanticsNode n) {
        labels.add(n.label);
        n.visitChildren((c) {
          collect(c);
          return true;
        });
      }

      collect(semanticsOf(tester, _interactive()));
      expect(labels.join('|'), 'Today', reason: '${w.runtimeType}');
    }
    handle.dispose();
  });

  group('AntIconButton', () {
    testWidgets('selected flag in semantics', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        host(
          AntIconButton(
            icon: Icons.star,
            tooltip: 'Star',
            selected: true,
            onPressed: () {},
          ),
        ),
      );
      expect(
        semanticsOf(tester, _interactive()),
        isSemantics(label: 'Star', isSelected: true, isButton: true),
      );
      handle.dispose();
    });
  });

  group('AntBadge', () {
    testWidgets('caps the count at 99+', (tester) async {
      for (final (n, text) in [(0, '0'), (7, '7'), (99, '99'), (100, '99+')]) {
        await tester.pumpWidget(host(AntBadge(count: n)));
        expect(find.text(text), findsOneWidget, reason: '$n');
      }
      await tester.pumpWidget(host(const AntBadge(count: 12345)));
      expect(find.text('99+'), findsOneWidget);
    });

    testWidgets('dot has no text', (tester) async {
      await tester.pumpWidget(host(const AntBadge.dot()));
      expect(find.byType(Text), findsNothing);
    });
  });
}
