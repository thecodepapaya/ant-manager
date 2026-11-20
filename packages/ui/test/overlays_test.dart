import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui/ui.dart';

import 'helpers.dart';

/// App with a toast host. [inBuilder] places it as documented (in
/// MaterialApp.builder, above the Navigator's Overlay); otherwise it sits
/// inside the home route.
Widget _toastApp(Widget home, {AntTokens? tokens, bool inBuilder = false}) =>
    MaterialApp(
      theme: antTheme(tokens ?? AntTokens.dark()),
      builder: inBuilder
          ? (context, child) => AntToastHost(child: child!)
          : null,
      home: Scaffold(
        body: inBuilder
            ? Center(child: home)
            : AntToastHost(child: Center(child: home)),
      ),
    );

const _bugMenuFocus =
    'BUG: overlays.dart:64 AntMenu opened by a click (AntButton never takes '
    'focus) leaves focus outside the menu, so Escape and arrow keys do nothing';

const _bugToastOverlay =
    'BUG: overlays.dart:394 AntToastHost placed in MaterialApp.builder (as its '
    'doc says) has no Overlay ancestor; the toast dismiss AntIconButton\'s '
    'Tooltip throws "No Overlay widget found" on every show()';

void main() {
  group('AntMenu', () {
    Widget menu(List<String> log) => AntMenu(
      items: [
        AntMenuItem(label: 'Rename', onSelected: () => log.add('rename')),
        const AntMenuDivider(),
        AntMenuItem(
          label: 'Delete',
          danger: true,
          shortcut: const ['⌘', '⌫'],
          onSelected: () => log.add('delete'),
        ),
      ],
      builder: (context, c) => AntButton(label: 'More', onPressed: c.open),
    );

    testWidgets('opens and runs onSelected, then closes', (tester) async {
      final log = <String>[];
      await tester.pumpWidget(host(menu(log)));
      expect(find.text('Rename'), findsNothing);

      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      expect(find.text('Rename'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      expect(find.byType(AntKbd), findsOneWidget);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(log, ['delete']);
      expect(find.text('Rename'), findsNothing);
    });

    Future<void> openByKeyboard(WidgetTester tester) async {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Rename'), findsOneWidget);
    }

    testWidgets('keyboard-opened: Escape closes without selecting', (
      tester,
    ) async {
      final log = <String>[];
      await tester.pumpWidget(host(menu(log)));
      await openByKeyboard(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Rename'), findsNothing);
      expect(log, isEmpty);
    });

    testWidgets('keyboard-opened: arrow keys + Enter select', (tester) async {
      final log = <String>[];
      await tester.pumpWidget(host(menu(log)));
      await openByKeyboard(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(log, hasLength(1));
    });

    testWidgets('mouse-opened: Escape closes ($_bugMenuFocus)', (tester) async {
      final log = <String>[];
      await tester.pumpWidget(host(menu(log)));
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Rename'), findsNothing);
      expect(log, isEmpty);
    });

    testWidgets('mouse-opened: arrow keys + Enter select ($_bugMenuFocus)', (
      tester,
    ) async {
      final log = <String>[];
      await tester.pumpWidget(host(menu(log)));
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(log, hasLength(1));
    });

    testWidgets('builds in dark and light', (tester) async {
      for (final t in [AntTokens.dark(), AntTokens.light()]) {
        await tester.pumpWidget(host(menu([]), tokens: t));
        await tester.tap(find.text('More'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
      }
    });
  });

  group('AntPopover', () {
    Widget popover() => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AntPopover(
          anchorBuilder: (context, c) =>
              AntButton(label: 'Filter', onPressed: c.toggle),
          contentBuilder: (context, c) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Popover body'),
              AntButton(label: 'Close', onPressed: c.hide),
            ],
          ),
        ),
        const SizedBox(height: 200),
        const Text('Elsewhere'),
      ],
    );

    Future<void> open(WidgetTester tester) async {
      await tester.tap(find.text('Filter'));
      await tester.pumpAndSettle();
      expect(find.text('Popover body'), findsOneWidget);
    }

    testWidgets('anchor toggles it open and closed', (tester) async {
      await tester.pumpWidget(host(popover()));
      expect(find.text('Popover body'), findsNothing);
      await open(tester);
      await tester.tap(find.text('Filter'));
      await tester.pumpAndSettle();
      expect(find.text('Popover body'), findsNothing);
    });

    testWidgets('closes on Escape', (tester) async {
      await tester.pumpWidget(host(popover()));
      await open(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Popover body'), findsNothing);
    });

    testWidgets('closes on Escape after a click inside the content', (
      tester,
    ) async {
      await tester.pumpWidget(host(popover()));
      await open(tester);
      await tester.tap(find.text('Popover body'));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Popover body'), findsNothing);
    });

    testWidgets('closes on outside tap', (tester) async {
      await tester.pumpWidget(host(popover()));
      await open(tester);
      await tester.tap(find.text('Elsewhere'));
      await tester.pumpAndSettle();
      expect(find.text('Popover body'), findsNothing);
    });

    testWidgets('tap inside the content keeps it open', (tester) async {
      await tester.pumpWidget(host(popover()));
      await open(tester);
      await tester.tap(find.text('Popover body'));
      await tester.pumpAndSettle();
      expect(find.text('Popover body'), findsOneWidget);
    });

    testWidgets('content can close it via the controller', (tester) async {
      await tester.pumpWidget(host(popover()));
      await open(tester);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Popover body'), findsNothing);
    });

    testWidgets('shows below the anchor', (tester) async {
      await tester.pumpWidget(host(popover()));
      await open(tester);
      final anchor = tester.getRect(find.byType(AntButton).first);
      final panel = tester.getRect(find.byType(AntPanel));
      expect(panel.top, greaterThanOrEqualTo(anchor.bottom));
      expect(panel.left, closeTo(anchor.left, 0.01));
    });
  });

  group('showAntDialog', () {
    Widget launcher({
      bool dismissible = true,
      void Function(Object?)? onResult,
    }) => Builder(
      builder: (context) => AntButton(
        label: 'Open',
        onPressed: () async {
          final r = await showAntDialog<String>(
            context,
            barrierDismissible: dismissible,
            builder: (context) => AntDialog(
              title: 'Delete project?',
              body: const Text('This cannot be undone.'),
              actions: [
                AntButton.ghost(
                  label: 'Cancel',
                  onPressed: () => Navigator.of(context).pop('cancel'),
                ),
                AntButton.primary(
                  label: 'Delete',
                  onPressed: () => Navigator.of(context).pop('delete'),
                ),
              ],
            ),
          );
          onResult?.call(r);
        },
      ),
    );

    Future<void> open(WidgetTester tester) async {
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Delete project?'), findsOneWidget);
    }

    testWidgets('actions pop with a result', (tester) async {
      final results = <Object?>[];
      await tester.pumpWidget(host(launcher(onResult: results.add)));
      await open(tester);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete project?'), findsNothing);
      expect(results, ['delete']);
    });

    testWidgets('Escape dismisses with null', (tester) async {
      final results = <Object?>[];
      await tester.pumpWidget(host(launcher(onResult: results.add)));
      await open(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Delete project?'), findsNothing);
      expect(results, [null]);
    });

    testWidgets('scrim tap dismisses', (tester) async {
      final results = <Object?>[];
      await tester.pumpWidget(host(launcher(onResult: results.add)));
      await open(tester);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.text('Delete project?'), findsNothing);
      expect(results, [null]);
    });

    testWidgets('barrierDismissible: false ignores scrim taps', (tester) async {
      await tester.pumpWidget(host(launcher(dismissible: false)));
      await open(tester);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.text('Delete project?'), findsOneWidget);
    });

    testWidgets('uses the scrim token and dialog semantics', (tester) async {
      final handle = tester.ensureSemantics();
      final t = AntTokens.light();
      await tester.pumpWidget(host(launcher(), tokens: t));
      await open(tester);
      final barrier = tester.widget<ModalBarrier>(
        find.byType(ModalBarrier).last,
      );
      expect(barrier.color, t.scrim);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Delete project?').first),
        isSemantics(scopesRoute: true, namesRoute: true),
      );
      handle.dispose();
    });

    testWidgets('keeps a locally overridden theme inside the dialog', (
      tester,
    ) async {
      final light = AntTokens.light();
      AntTokens? seen;
      await tester.pumpWidget(
        MaterialApp(
          theme: antTheme(AntTokens.dark()),
          home: Theme(
            data: antTheme(light),
            child: Builder(
              builder: (context) => AntButton(
                label: 'Open',
                onPressed: () => showAntDialog<void>(
                  context,
                  builder: (context) {
                    seen = context.tokens;
                    return const AntDialog(title: 'Hi');
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(identical(seen, light), isTrue);
    });
  });

  group('Toasts', () {
    Widget trigger({AntTone tone = AntTone.neutral, String msg = 'Saved'}) =>
        Builder(
          builder: (context) => AntButton(
            label: 'Toast',
            onPressed: () => AntToastHost.of(context).show(msg, tone: tone),
          ),
        );

    testWidgets('auto-dismisses after motion.toastDwell', (tester) async {
      final t = AntTokens.dark();
      await tester.pumpWidget(_toastApp(trigger(), tokens: t));
      await tester.tap(find.text('Toast'));
      await tester.pump();
      expect(find.text('Saved'), findsOneWidget);

      await tester.pump(t.motion.toastDwell - const Duration(milliseconds: 50));
      expect(find.text('Saved'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(find.text('Saved'), findsNothing);
    });

    testWidgets('dismiss button removes it immediately', (tester) async {
      await tester.pumpWidget(_toastApp(trigger()));
      await tester.tap(find.text('Toast'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AntToast),
          matching: find.byType(AntIconButton),
        ),
      );
      await tester.pump();
      expect(find.text('Saved'), findsNothing);
      // The cancelled timer must not fire into a removed entry.
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('several toasts stack and expire independently', (
      tester,
    ) async {
      final t = AntTokens.dark();
      late AntToastHostState hostState;
      await tester.pumpWidget(
        _toastApp(
          Builder(
            builder: (context) {
              hostState = AntToastHost.of(context);
              return const SizedBox();
            },
          ),
          tokens: t,
        ),
      );
      hostState.show('one');
      await tester.pump(const Duration(seconds: 2));
      hostState.show('two');
      await tester.pump();
      expect(find.byType(AntToast), findsNWidgets(2));
      await tester.pump(t.motion.toastDwell - const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 10));
      expect(find.text('one'), findsNothing);
      expect(find.text('two'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('two'), findsNothing);
    });

    testWidgets('every tone builds; toast is a live region', (tester) async {
      final handle = tester.ensureSemantics();
      for (final tone in AntTone.values) {
        for (final t in [AntTokens.dark(), AntTokens.light()]) {
          await tester.pumpWidget(
            host(
              AntToast(message: 'm', tone: tone, onDismiss: () {}),
              tokens: t,
            ),
          );
          expect(tester.takeException(), isNull);
        }
      }
      expect(
        tester.getSemantics(find.byType(AntToast)),
        isSemantics(isLiveRegion: true),
      );
      handle.dispose();
    });

    testWidgets('AntToastHost.of throws without a host', (tester) async {
      Object? error;
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) {
              try {
                AntToastHost.of(context);
              } catch (e) {
                error = e;
              }
              return const SizedBox();
            },
          ),
        ),
      );
      expect(error, isA<FlutterError>());
    });

    testWidgets('hovering the dismiss button shows its tooltip', (
      tester,
    ) async {
      final t = AntTokens.dark();
      await tester.pumpWidget(_toastApp(trigger(), tokens: t));
      await tester.tap(find.text('Toast'));
      await tester.pumpAndSettle();
      final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await g.addPointer(location: Offset.zero);
      addTearDown(g.removePointer);
      await g.moveTo(
        tester.getCenter(
          find.descendant(
            of: find.byType(AntToast),
            matching: find.byType(AntIconButton),
          ),
        ),
      );
      await tester.pump(t.motion.tooltipWait);
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(find.text('Dismiss'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
  });

  testWidgets(
    'toast shows when the host is in MaterialApp.builder ($_bugToastOverlay)',
    (tester) async {
      await tester.pumpWidget(
        _toastApp(
          Builder(
            builder: (context) => AntButton(
              label: 'Toast',
              onPressed: () => AntToastHost.of(context).show('Saved'),
            ),
          ),
          inBuilder: true,
        ),
      );
      await tester.tap(find.text('Toast'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Saved'), findsOneWidget);
    },
  );

  group('AntTooltip', () {
    testWidgets('appears after tooltipWait on hover', (tester) async {
      final t = AntTokens.dark();
      await tester.pumpWidget(
        host(
          const AntTooltip(message: 'More info', child: Text('i')),
          tokens: t,
        ),
      );
      final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await g.addPointer(location: Offset.zero);
      addTearDown(g.removePointer);
      await g.moveTo(tester.getCenter(find.text('i')));
      await tester.pump(t.motion.tooltipWait ~/ 2);
      expect(find.text('More info'), findsNothing);
      await tester.pump(t.motion.tooltipWait);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('More info'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
  });
}
