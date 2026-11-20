/// Independent tests (#99) for the packages/ui parts of DECISIONS #120 (UI fidelity round 2):
/// AntDialog's one layout (optional subtitle, scrolling body, divided footer with leading
/// actions, width), AntInteractive(focusRadius:, focusInset:) and long labels in AntSelect and
/// AntMenu. Layout invariants, not pixels.
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui/ui.dart';

import 'helpers.dart';

final _t = AntTokens.dark();

Future<void> _size(WidgetTester tester, Size s) async {
  tester.view.physicalSize = s;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Rect _r(WidgetTester tester, Finder f) => tester.getRect(f);

/// The shipping desktop platforms: a mouse is present and the default
/// highlight mode is traditional, as in the app.
final _desktop = TargetPlatformVariant(const {
  TargetPlatform.macOS,
  TargetPlatform.windows,
});

/// Opens [dialog] with showAntDialog from an "Open" button.
Future<void> _openDialog(WidgetTester tester, Widget dialog) async {
  await tester.pumpWidget(
    host(
      Builder(
        builder: (context) => AntButton(
          label: 'Open',
          onPressed: () =>
              showAntDialog<void>(context, builder: (_) => dialog),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

/// The dialog panel: the Container under AntDialog (it has the raised fill).
Finder _panel() => find
    .descendant(of: find.byType(AntDialog), matching: find.byType(Container))
    .first;

/// The footer: a Container with a top-only hairline divider border, above [of].
Finder _footerOf(Finder of) => find.ancestor(
  of: of,
  matching: find.byWidgetPredicate((w) {
    if (w is! Container || w.decoration is! BoxDecoration) return false;
    final b = (w.decoration! as BoxDecoration).border;
    return b is Border &&
        b.top.color == _t.divider &&
        b.top.width == _t.stroke.hairline &&
        b.bottom == BorderSide.none &&
        b.left == BorderSide.none;
  }),
);

/// The foreground ring DecoratedBox under [of] (AntFocusRing).
Finder _rings(Finder of) => focusRings(of);

void main() {
  // -------------------------------------------------------------------------
  group('AntDialog', () {
    AntDialog dialog({
      String? subtitle,
      Widget? body = const Text('Body text'),
      List<Widget>? actions,
      List<Widget> leading = const [],
      double? width,
    }) => AntDialog(
      title: 'Connect OpenRouter',
      subtitle: subtitle,
      body: body,
      width: width,
      leadingActions: leading,
      actions:
          actions ??
          [
            AntButton.ghost(label: 'Cancel', onPressed: () {}),
            AntButton.primary(label: 'Save', onPressed: () {}),
          ],
    );

    testWidgets('subtitle sits under the title, above the body', (
      tester,
    ) async {
      await _openDialog(tester, dialog(subtitle: 'Keys stay in your Keychain'));
      final title = _r(tester, find.text('Connect OpenRouter'));
      final sub = _r(tester, find.text('Keys stay in your Keychain'));
      final body = _r(tester, find.text('Body text'));
      expect(sub.top, greaterThanOrEqualTo(title.bottom));
      expect(body.top, greaterThanOrEqualTo(sub.bottom));
      expect(sub.left, closeTo(title.left, 0.5), reason: 'left-aligned');
      final style = tester.widget<Text>(
        find.text('Keys stay in your Keychain'),
      );
      expect(style.style?.color, _t.muted, reason: 'muted subtitle');
    });

    testWidgets('no subtitle: only the title and the body', (tester) async {
      await _openDialog(tester, dialog());
      final texts = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byType(AntDialog),
              matching: find.byType(Text),
            ),
          )
          .map((t) => t.data)
          .toList();
      expect(texts, ['Connect OpenRouter', 'Body text', 'Cancel', 'Save']);
    });

    testWidgets('actions sit in a footer behind a hairline divider, right-'
        'aligned in order', (tester) async {
      await _openDialog(tester, dialog());
      final cancel = find.widgetWithText(AntButton, 'Cancel');
      final save = find.widgetWithText(AntButton, 'Save');
      final footer = _footerOf(save);
      expect(footer, findsOneWidget, reason: 'footer with a top divider');
      expect(_footerOf(cancel), findsOneWidget, reason: 'same footer');
      expect(
        _footerOf(find.text('Body text')),
        findsNothing,
        reason: 'the body is not in the footer',
      );
      final panel = _r(tester, _panel());
      final f = _r(tester, footer);
      expect(f.left, closeTo(panel.left, 1), reason: 'divider spans the panel');
      expect(f.right, closeTo(panel.right, 1));
      expect(f.bottom, closeTo(panel.bottom, 1), reason: 'footer at the bottom');
      expect(_r(tester, find.text('Body text')).bottom, lessThan(f.top));
      expect(
        _r(tester, save).right,
        closeTo(panel.right - _t.space.xxl, 1),
        reason: 'right-aligned with the content padding',
      );
      expect(_r(tester, cancel).right, lessThan(_r(tester, save).left));
      expect(
        _r(tester, cancel).center.dy,
        closeTo(_r(tester, save).center.dy, 0.5),
      );
    });

    testWidgets('leading actions sit at the footer left, actions at the right', (
      tester,
    ) async {
      await _openDialog(
        tester,
        dialog(leading: [AntButton.ghost(label: 'Back', onPressed: () {})]),
      );
      final back = find.widgetWithText(AntButton, 'Back');
      final save = find.widgetWithText(AntButton, 'Save');
      expect(_footerOf(back), findsOneWidget, reason: 'in the divided footer');
      final panel = _r(tester, _panel());
      expect(_r(tester, back).left, closeTo(panel.left + _t.space.xxl, 1));
      expect(_r(tester, save).right, closeTo(panel.right - _t.space.xxl, 1));
      expect(
        _r(tester, back).center.dy,
        closeTo(_r(tester, save).center.dy, 0.5),
        reason: 'one footer row',
      );
      expect(
        _r(tester, find.widgetWithText(AntButton, 'Cancel')).left -
            _r(tester, back).right,
        greaterThan(_t.space.xxl),
        reason: 'a gap between leading and trailing groups',
      );
    });

    testWidgets('only leading actions still get the footer', (tester) async {
      await _openDialog(
        tester,
        dialog(
          actions: const [],
          leading: [AntButton.ghost(label: 'Back', onPressed: () {})],
        ),
      );
      expect(_footerOf(find.widgetWithText(AntButton, 'Back')), findsOneWidget);
    });

    testWidgets('no actions: no footer divider', (tester) async {
      await _openDialog(tester, dialog(actions: const []));
      expect(_footerOf(find.text('Body text')), findsNothing);
      final dividerFooters = find.descendant(
        of: find.byType(AntDialog),
        matching: find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              ((w.decoration! as BoxDecoration).border is Border) &&
              ((w.decoration! as BoxDecoration).border! as Border).top.color ==
                  _t.divider,
        ),
      );
      expect(dividerFooters, findsNothing);
    });

    testWidgets('width defaults to density.dialogWidth; a passed width wins', (
      tester,
    ) async {
      await _size(tester, const Size(1400, 900));
      await _openDialog(tester, dialog());
      expect(_r(tester, _panel()).width, closeTo(_t.density.dialogWidth, 0.5));
      Navigator.of(tester.element(find.byType(AntDialog))).pop();
      await tester.pumpAndSettle();
      await _openDialog(tester, dialog(width: 700));
      expect(_r(tester, _panel()).width, closeTo(700, 0.5));
    });

    testWidgets('a tall body scrolls on a short screen; header and footer stay '
        'visible, no overflow', (tester) async {
      const screen = Size(1000, 420);
      await _size(tester, screen);
      await _openDialog(
        tester,
        dialog(
          subtitle: 'Pick the repositories to import',
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [for (var i = 0; i < 60; i++) Text('Line $i')],
          ),
        ),
      );
      expect(tester.takeException(), isNull, reason: 'no overflow');
      final panel = _r(tester, _panel());
      expect(
        panel.height,
        lessThanOrEqualTo(screen.height - _t.space.giant * 2 + 0.5),
      );
      expect(panel.top, greaterThanOrEqualTo(0));
      expect(panel.bottom, lessThanOrEqualTo(screen.height));
      final title = _r(tester, find.text('Connect OpenRouter'));
      final save = _r(tester, find.widgetWithText(AntButton, 'Save'));
      expect(title.top, greaterThanOrEqualTo(panel.top));
      expect(save.bottom, lessThanOrEqualTo(panel.bottom), reason: 'footer on screen');
      // The last line is not visible until the body is scrolled.
      final scroll = find.descendant(
        of: find.byType(AntDialog),
        matching: find.byType(Scrollable),
      );
      expect(scroll, findsOneWidget);
      final last = find.text('Line 59');
      expect(_r(tester, last).top, greaterThan(save.top), reason: 'clipped below');
      await tester.dragUntilVisible(
        last,
        scroll,
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      final footerTop = _r(tester, _footerOf(find.text('Save'))).top;
      expect(_r(tester, last).bottom, lessThanOrEqualTo(footerTop + 0.5));
      expect(
        _r(tester, find.text('Connect OpenRouter')),
        title,
        reason: 'the header does not scroll away',
      );
      expect(tester.takeException(), isNull);
    });
  });

  // -------------------------------------------------------------------------
  group('AntInteractive focusRadius / focusInset', () {
    Widget control({BorderRadius? radius, bool inset = false, FocusNode? node}) =>
        AntInteractive(
          onTap: () {},
          focusNode: node,
          focusRadius: radius,
          focusInset: inset,
          builder: (context, s) =>
              const SizedBox(width: 120, height: 40),
        );

    Future<FocusManager> keyboardMode(WidgetTester tester) async {
      final fm = tester.binding.focusManager;
      addTearDown(() => fm.highlightStrategy = FocusHighlightStrategy.automatic);
      fm.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      return fm;
    }

    testWidgets('no ring on mouse hover or click; ring on keyboard focus', (
      tester,
    ) async {
      final taps = <int>[];
      await tester.pumpWidget(
        host(
          AntInteractive(
            onTap: () => taps.add(1),
            focusRadius: _t.radii.brMd,
            builder: (context, s) => const SizedBox(width: 120, height: 40),
          ),
        ),
      );
      final ai = find.byType(AntInteractive);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(ai));
      await tester.pump();
      expect(_rings(ai), findsNothing, reason: 'hover');
      await tester.tap(ai, kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      expect(taps, [1]);
      expect(_rings(ai), findsNothing, reason: 'mouse click');

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(
        tester.binding.focusManager.highlightMode,
        FocusHighlightMode.traditional,
      );
      expect(_rings(ai), findsOneWidget, reason: 'keyboard focus');
    }, variant: _desktop);

    testWidgets('focused in touch highlight mode: no ring', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(host(control(radius: _t.radii.brMd, node: node)));
      final fm = tester.binding.focusManager;
      addTearDown(() => fm.highlightStrategy = FocusHighlightStrategy.automatic);
      fm.highlightStrategy = FocusHighlightStrategy.alwaysTouch;
      node.requestFocus();
      await tester.pump();
      expect(node.hasFocus, isTrue);
      expect(_rings(find.byType(AntInteractive)), findsNothing);
    });

    testWidgets('without focusRadius no ring is painted around the child', (
      tester,
    ) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(host(control(node: node)));
      await keyboardMode(tester);
      node.requestFocus();
      await tester.pump();
      expect(node.hasFocus, isTrue);
      expect(_rings(find.byType(AntInteractive)), findsNothing);
    });

    testWidgets('a disabled control never shows the ring', (tester) async {
      await tester.pumpWidget(
        host(
          AntInteractive(
            onTap: null,
            focusRadius: _t.radii.brMd,
            builder: (context, s) => const SizedBox(width: 120, height: 40),
          ),
        ),
      );
      await keyboardMode(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(_rings(find.byType(AntInteractive)), findsNothing);
    });

    for (final inset in [false, true]) {
      testWidgets('ring geometry (inset: $inset): token colour/width, the given '
          'radius, ${inset ? 'inside' : 'outside'} the bounds', (tester) async {
        final node = FocusNode();
        addTearDown(node.dispose);
        await tester.pumpWidget(
          host(control(radius: _t.radii.brLg, inset: inset, node: node)),
        );
        await keyboardMode(tester);
        node.requestFocus();
        await tester.pump();
        final ring = _rings(find.byType(AntInteractive));
        expect(ring, findsOneWidget);
        final deco =
            tester.widget<DecoratedBox>(ring).decoration as BoxDecoration;
        final side = (deco.border! as Border).top;
        expect(side.color, _t.focusRing);
        expect(side.width, _t.stroke.focus);
        expect(deco.borderRadius, _t.radii.brLg);
        expect(
          side.strokeAlign,
          inset ? BorderSide.strokeAlignInside : BorderSide.strokeAlignOutside,
        );
        // Wraps the whole child without changing its layout.
        expect(tester.getSize(ring), const Size(120, 40));
        expect(tester.getSize(find.byType(AntInteractive)), const Size(120, 40));
        // Painted geometry: the outer edge of the ring is the child's bounds
        // when inset, outside them otherwise.
        const bounds = Rect.fromLTWH(0, 0, 120, 40);
        expect(
          tester.renderObject(ring),
          paints..something((method, args) {
            if (method != #drawDRRect) return false;
            final outer = (args[0] as RRect).outerRect;
            final inner = (args[1] as RRect).outerRect;
            if (inset) {
              return outer == bounds &&
                  inner == bounds.deflate(_t.stroke.focus);
            }
            return outer == bounds.inflate(_t.stroke.focus) && inner == bounds;
          }),
        );
      });
    }

    testWidgets('losing focus removes the ring; layout never moves', (
      tester,
    ) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        host(control(radius: _t.radii.brMd, inset: true, node: node)),
      );
      final before = _r(tester, find.byType(AntInteractive));
      await keyboardMode(tester);
      node.requestFocus();
      await tester.pump();
      expect(_rings(find.byType(AntInteractive)), findsOneWidget);
      expect(_r(tester, find.byType(AntInteractive)), before);
      node.unfocus();
      await tester.pumpAndSettle();
      expect(_rings(find.byType(AntInteractive)), findsNothing);
    });
  });

  // -------------------------------------------------------------------------
  group('long labels', () {
    const long =
        'Platform reliability and incident follow-ups for the checkout migration';

    testWidgets('AntSelect ellipsizes a long label inside the control', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          SizedBox(
            width: 180,
            child: AntSelect<int>(
              value: 1,
              onChanged: (_) {},
              options: const [AntOption(0, 'None'), AntOption(1, long)],
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final select = _r(tester, find.byType(AntSelect<int>));
      final label = find.descendant(
        of: find.byType(AntSelect<int>),
        matching: find.text(long),
      );
      expect(_r(tester, label).right, lessThanOrEqualTo(select.right + 0.5));
      expect(_r(tester, label).left, greaterThanOrEqualTo(select.left));
      final para = tester.renderObject<RenderParagraph>(label);
      expect(para.didExceedMaxLines, isTrue, reason: 'one ellipsized line');
      expect(para.maxLines, 1);
      // The chevron stays inside too.
      final chevron = find.byIcon(Icons.keyboard_arrow_down_rounded);
      expect(_r(tester, chevron).right, lessThanOrEqualTo(select.right + 0.5));
      expect(_r(tester, chevron).left, greaterThanOrEqualTo(_r(tester, label).right));
    });

    testWidgets('AntSelect with a short label keeps its natural (min) width', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          AntSelect<int>(
            value: 0,
            onChanged: (_) {},
            options: const [AntOption(0, 'None')],
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(AntSelect<int>)).width,
        lessThan(120),
        reason: 'Flexible label does not stretch an unconstrained select',
      );
      final para = tester.renderObject<RenderParagraph>(find.text('None'));
      expect(para.didExceedMaxLines, isFalse);
    });

    for (final align in [Alignment.topLeft, Alignment.topRight]) {
      testWidgets('a long AntMenu item ellipsizes; the menu stays on screen '
          '(anchor ${align == Alignment.topLeft ? 'left' : 'right'})', (
        tester,
      ) async {
        const screen = Size(800, 600);
        await _size(tester, screen);
        await tester.pumpWidget(
          MaterialApp(
            theme: antTheme(_t),
            home: Scaffold(
              body: Align(
                alignment: align,
                child: AntMenu(
                  items: [
                    AntMenuItem(label: 'Short', onSelected: () {}),
                    AntMenuItem(
                      label: '$long and then some more words $long',
                      icon: Icons.folder_outlined,
                      onSelected: () {},
                    ),
                  ],
                  builder: (context, c) =>
                      AntButton(label: 'More', onPressed: c.open),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('More'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final text = find.text('$long and then some more words $long');
        final para = tester.renderObject<RenderParagraph>(text);
        expect(para.didExceedMaxLines, isTrue, reason: 'ellipsized');
        expect(para.maxLines, 1);
        expect(
          _r(tester, text).width,
          lessThanOrEqualTo(_t.density.menuMinWidth * 2 + 0.5),
          reason: 'label capped at twice the menu min width',
        );
        for (final item in tester.widgetList(find.byType(MenuItemButton))) {
          final r = tester.getRect(find.byWidget(item));
          expect(r.left, greaterThanOrEqualTo(0), reason: 'on screen');
          expect(r.right, lessThanOrEqualTo(screen.width), reason: 'on screen');
        }
        // Both items are the same (menu) width.
        final rects = [
          for (final item in tester.widgetList(find.byType(MenuItemButton)))
            tester.getRect(find.byWidget(item)),
        ];
        expect(rects.first.width, closeTo(rects.last.width, 0.5));
      });
    }

    testWidgets('a short AntMenu item is not ellipsized', (tester) async {
      await tester.pumpWidget(
        host(
          AntMenu(
            items: [AntMenuItem(label: 'Rename', onSelected: () {})],
            builder: (context, c) => AntButton(label: 'More', onPressed: c.open),
          ),
        ),
      );
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      expect(
        tester.renderObject<RenderParagraph>(find.text('Rename')).didExceedMaxLines,
        isFalse,
      );
    });
  });
}
