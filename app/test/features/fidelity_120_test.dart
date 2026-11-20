/// Independent tests (#99) for the app parts of DECISIONS #120 (UI fidelity round 2): evidence-row
/// actions as a floating toolbar (hover / keyboard focus, not pinned by a highlight, no clicks
/// while hidden), the compact Timeline row, Today's time column at the panel edge, WideDialog as
/// a wider AntDialog, Settings → AI models' empty state, and the keyboard focus ring at a few of
/// the AntInteractive(focusRadius:) sites. Layout invariants only (order, alignment), not pixels.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ant_manager/app.dart';
import 'package:ant_manager/engine/commands.dart';
import 'package:ant_manager/engine/engine_handle.dart';
import 'package:ant_manager/engine/setup_commands.dart';
import 'package:ant_manager/features/reports/reports_page.dart';
import 'package:ant_manager/features/settings/ai_models_tab.dart';
import 'package:ant_manager/features/settings/kit.dart';
import 'package:ant_manager/features/settings/provider_dialog.dart';
import 'package:ant_manager/features/settings/setup_providers.dart';
import 'package:ant_manager/features/timeline/timeline_page.dart';
import 'package:ant_manager/features/today/today_page.dart';
import 'package:ant_manager/state/providers.dart';
import 'package:ant_manager/widgets/common.dart';
import 'package:ant_manager/widgets/evidence_row.dart';
import 'package:core/core.dart' hide Provider;
import 'package:core/core.dart' as core show Provider;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui/ui.dart';

import 'support.dart';

final _t = AntTokens.light();

Rect _r(WidgetTester tester, Finder f) => tester.getRect(f);

void _sameRow(WidgetTester tester, Finder a, Finder b, {double tol = 4, String? reason}) {
  final ca = _r(tester, a).center.dy, cb = _r(tester, b).center.dy;
  expect((ca - cb).abs(), lessThanOrEqualTo(tol), reason: reason ?? 'same row ($ca vs $cb)');
}

void _before(WidgetTester tester, Finder left, Finder right, {String? reason}) {
  expect(_r(tester, left).right, lessThanOrEqualTo(_r(tester, right).left + 0.5), reason: reason);
}

Finder _rowOf(String title) => find.ancestor(of: find.text(title), matching: find.byType(EvidenceRow)).first;

Finder _in(Finder row, Finder m) => find.descendant(of: row, matching: m);

const _actionTips = ['Star as a win', 'Annotate', 'Hide from the narrative', 'More'];

/// Each row action under [row] is (or is not) hit-testable, and the toolbar's opacity matches.
void _expectActions(WidgetTester tester, Finder row, {required bool shown, String? reason}) {
  for (final tip in _actionTips) {
    final f = _in(row, find.byTooltip(tip));
    expect(f, findsOneWidget, reason: '$tip laid out even while hidden');
    expect(f.hitTestable(), shown ? findsOneWidget : findsNothing, reason: '$tip ${reason ?? ''}');
  }
  final opacity = find.ancestor(of: _in(row, find.byTooltip('More')), matching: find.byType(AnimatedOpacity)).first;
  expect(tester.widget<AnimatedOpacity>(opacity).opacity, shown ? 1 : 0, reason: reason);
}

/// The HH:MM label in [row].
Finder _time(Finder row) => _in(row, find.textContaining(RegExp(r'^\d{2}:\d{2}$')));

/// A focusable node inside [of] (the FocusableActionDetector's Focus of the first control).
FocusNode _focusNodeIn(WidgetTester tester, Finder of) => tester
    .widgetList<Focus>(find.descendant(of: of, matching: find.byType(Focus)))
    .map((f) => f.focusNode)
    .firstWhere((n) => n != null && n.canRequestFocus && !n.skipTraversal)!;

/// Keyboard ("traditional") highlight mode for the rest of the test.
void _keyboardMode(WidgetTester tester) {
  final fm = tester.binding.focusManager;
  addTearDown(() => fm.highlightStrategy = FocusHighlightStrategy.automatic);
  fm.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
}

/// Token focus rings (AntFocusRing's foreground DecoratedBox) under [of].
Finder _rings(Finder of) => find.descendant(
      of: of,
      matching: find.byWidgetPredicate((w) =>
          w is DecoratedBox &&
          w.position == DecorationPosition.foreground &&
          ((w.decoration as BoxDecoration).border as Border?)?.top.color == _t.focusRing),
    );

Finder _interactive(String label) =>
    find.byWidgetPredicate((w) => w is AntInteractive && w.semanticLabel == label, description: 'AntInteractive "$label"');

/// Keyboard-focuses the AntInteractive [f] and checks the ring appears only then.
Future<BoxDecoration> _expectRingOnKeyboardFocus(WidgetTester tester, Finder f) async {
  expect(f, findsOneWidget);
  expect(_rings(f), findsNothing, reason: 'no ring before focus');
  _keyboardMode(tester);
  final node = _focusNodeIn(tester, f);
  node.requestFocus();
  await settle(tester, until: () => _rings(f).evaluate().isNotEmpty, max: 20);
  expect(node.hasFocus, isTrue);
  expect(_rings(f), findsOneWidget, reason: 'ring on keyboard focus');
  final deco = tester.widget<DecoratedBox>(_rings(f)).decoration as BoxDecoration;
  node.unfocus();
  await settle(tester, until: () => _rings(f).evaluate().isEmpty, max: 20);
  expect(_rings(f), findsNothing, reason: 'gone after focus leaves');
  return deco;
}

final _png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=');

void main() {
  late Directory dir;
  setUp(() => dir = tempDir());
  tearDown(() => dir.deleteSync(recursive: true));

  // -------------------------------------------------------------------------
  group('EvidenceRow actions (floating toolbar)', () {
    const title = 'Reviewed the rollout plan';

    Future<(ProviderContainer, EngineHandle, String)> today(WidgetTester tester) async {
      final (c, h) = await bootPage(tester, dir, const TodayPage());
      final id = await cmd(tester, h, addNoteCmd(text: title, at: DateTime.now()));
      await settle(tester, until: () => find.text(title).evaluate().isNotEmpty);
      return (c, h, id);
    }

    testWidgets('hidden: not hit-testable; hover shows them; pointer exit hides them', (tester) async {
      final (_, h, _) = await today(tester);
      final row = _rowOf(title);
      _expectActions(tester, row, shown: false, reason: 'before hover');

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: const Offset(1, 1));
      await mouse.moveTo(tester.getCenter(row));
      await tester.pump(const Duration(milliseconds: 300));
      _expectActions(tester, row, shown: true, reason: 'on hover');

      // Pointer leaves the row (to the top bar).
      await mouse.moveTo(Offset(tester.getCenter(row).dx, _r(tester, find.byType(TopBar)).center.dy));
      await tester.pump(const Duration(milliseconds: 300));
      _expectActions(tester, row, shown: false, reason: 'after the pointer leaves');
      await killEngine(tester, h);
    });

    testWidgets('a hidden toolbar takes no clicks: tapping where Star sits does not star', (tester) async {
      final (_, h, id) = await today(tester);
      final row = _rowOf(title);
      final star = _r(tester, _in(row, find.byTooltip('Star as a win')));
      await tester.tapAt(star.center, kind: PointerDeviceKind.touch);
      await settle(tester);
      expect((await read(tester, () => evidenceOf(h, id))).starred, isFalse);
      await killEngine(tester, h);
    });

    testWidgets('keyboard focus inside the row shows them; focus leaving hides them', (tester) async {
      final (_, h, _) = await today(tester);
      final row = _rowOf(title);
      _keyboardMode(tester);
      final node = _focusNodeIn(tester, _in(row, find.byWidgetPredicate((w) => w is AntIconButton && w.tooltip == 'Annotate')));
      node.requestFocus();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(node.hasFocus, isTrue);
      _expectActions(tester, row, shown: true, reason: 'focus inside the row');
      node.unfocus();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      _expectActions(tester, row, shown: false, reason: 'focus left the row');
      await killEngine(tester, h);
    });

    testWidgets('a highlighted row does not pin them; hover still shows them', (tester) async {
      final (c, h, id) = await today(tester);
      c.read(todayFocusProvider.notifier).focus(todayDay(), {id});
      await settle(tester, until: () => tester.widget<EvidenceRow>(_rowOf(title)).highlighted);
      final row = _rowOf(title);
      expect(tester.widget<EvidenceRow>(row).highlighted, isTrue);
      await tester.pump(const Duration(milliseconds: 300));
      _expectActions(tester, row, shown: false, reason: 'highlighted, not hovered');

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: const Offset(1, 1));
      await mouse.moveTo(tester.getCenter(row));
      await tester.pump(const Duration(milliseconds: 300));
      _expectActions(tester, row, shown: true, reason: 'highlighted and hovered');
      await killEngine(tester, h);
    });

    testWidgets('Today: the time sits at the panel edge, and showing the toolbar moves nothing', (tester) async {
      final (_, h, _) = await today(tester);
      final row = _rowOf(title);
      final panel = find.ancestor(
        of: row,
        matching: find.byWidgetPredicate((w) =>
            w is DecoratedBox &&
            w.decoration is BoxDecoration &&
            ((w.decoration as BoxDecoration).border as Border?)?.right.color == _t.border),
      );
      expect(panel, findsOneWidget, reason: 'the evidence column (border on its right)');
      final time = _time(row);
      expect(time, findsOneWidget);
      final edge = _r(tester, panel).right - _t.space.xxl - _t.space.md - _t.stroke.hairline;
      expect(_r(tester, time).right, closeTo(edge, 1),
          reason: 'only the column and row padding between the time and the panel edge');
      expect(_r(tester, row).right, closeTo(_r(tester, panel).right - _t.space.xxl, 0.5));
      // The toolbar floats over the row's right edge (over the time) instead of reserving space.
      final before = (_r(tester, time), _r(tester, find.text(title)));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: const Offset(1, 1));
      await mouse.moveTo(tester.getCenter(row));
      await tester.pump(const Duration(milliseconds: 300));
      expect((_r(tester, time), _r(tester, find.text(title))), before, reason: 'no layout shift');
      final more = _r(tester, _in(row, find.byTooltip('More')));
      expect(more.right, lessThanOrEqualTo(_r(tester, row).right), reason: 'inside the row');
      expect(more.right, greaterThan(_r(tester, time).left), reason: 'over the right edge, not after the time');
      await killEngine(tester, h);
    });
  });

  // -------------------------------------------------------------------------
  group('EvidenceRow(compact) on Timeline', () {
    testWidgets('one line: time, project dot, title, muted "· project", source chip at the right edge',
        (tester) async {
      final (_, h) = await bootPage(tester, dir, const TimelinePage());
      final pid = await cmd(tester, h, createProjectCmd('Checkout'));
      await cmd(tester, h, addNoteCmd(text: 'Paired on the retry worker', at: DateTime.now(), projectId: pid));
      await cmd(tester, h, addNoteCmd(text: 'Sorted the inbox', at: DateTime.now()));
      await settle(tester, until: () => find.text('Sorted the inbox').evaluate().isNotEmpty);
      await settle(tester, until: () => find.text('Paired on the retry worker').evaluate().isNotEmpty);

      for (final (title, detail) in [('Paired on the retry worker', '· Checkout'), ('Sorted the inbox', '· Note')]) {
        final row = _rowOf(title);
        expect(tester.widget<EvidenceRow>(row).compact, isTrue);
        final time = _time(row), dot = _in(row, find.byType(AntDot)), text = find.text(title);
        final muted = _in(row, find.byWidgetPredicate((w) => w is Muted && w.text == detail));
        final chip = _in(row, find.byWidgetPredicate((w) => w is AntChip && w.label == 'Notes'));
        for (final f in [time, dot, muted, chip]) {
          expect(f, findsOneWidget, reason: '$title: $f');
        }
        expect(_in(row, find.byType(KindIcon)), findsNothing, reason: 'no kind icon on the compact line');
        // Order on one line.
        for (final f in [dot, text, muted, chip]) {
          _sameRow(tester, time, f, reason: '$title: one line');
        }
        _before(tester, time, dot, reason: 'time left of the dot');
        _before(tester, dot, text, reason: 'dot left of the title');
        _before(tester, text, muted, reason: 'detail after the title');
        _before(tester, muted, chip, reason: 'chip after the detail');
        final rowRect = _r(tester, row);
        expect(_r(tester, time).left, closeTo(rowRect.left + _t.space.md + _t.stroke.hairline, 1), reason: 'time at the left');
        expect(_r(tester, chip).right, closeTo(rowRect.right - _t.space.md - _t.stroke.hairline, 1),
            reason: 'source chip at the right edge');
        // Muted detail.
        final mutedText = tester.widget<Text>(find.descendant(of: muted, matching: find.byType(Text)));
        expect(mutedText.style?.color, _t.muted);
        expect(mutedText.maxLines, 1);
        // One line high: the tallest item plus the row padding.
        final tallest = [time, dot, text, muted, chip].map((f) => _r(tester, f).height).reduce((a, b) => a > b ? a : b);
        expect(rowRect.height, closeTo(tallest + 2 * (_t.space.md + _t.stroke.hairline), 1), reason: '$title: one line high');
        _expectActions(tester, row, shown: false, reason: 'compact rows hide actions too');
      }
      // Project dot uses the project colour; no project → a different (neutral) colour.
      final withP = tester.widget<AntDot>(_in(_rowOf('Paired on the retry worker'), find.byType(AntDot)));
      final noP = tester.widget<AntDot>(_in(_rowOf('Sorted the inbox'), find.byType(AntDot)));
      expect(withP.color, isNot(noP.color));
      expect(tester.takeException(), isNull);
      await killEngine(tester, h);
    });

    testWidgets('a long title ellipsizes and the chip stays at the right edge', (tester) async {
      final (_, h) = await bootPage(tester, dir, const TimelinePage(), size: const Size(900, 1000));
      final long = 'Investigated the flaky checkout integration tests across every shard ' * 4;
      await cmd(tester, h, addNoteCmd(text: long.trim(), at: DateTime.now()));
      await settle(tester, until: () => find.text(long.trim()).evaluate().isNotEmpty);
      final row = _rowOf(long.trim());
      expect(tester.takeException(), isNull);
      expect(tester.renderObject<RenderParagraph>(find.text(long.trim())).didExceedMaxLines, isTrue);
      final chip = _in(row, find.byWidgetPredicate((w) => w is AntChip && w.label == 'Notes'));
      expect(_r(tester, chip).right, closeTo(_r(tester, row).right - _t.space.md - _t.stroke.hairline, 1));
      _sameRow(tester, _time(row), chip);
      await killEngine(tester, h);
    });

    testWidgets('notes, annotations and screenshots sit indented under the title', (tester) async {
      final (_, h) = await bootPage(tester, dir, const TimelinePage());
      const body = 'Retro notes\nWent well: deploys\nTo fix: flaky CI';
      final retro = await cmd(tester, h, addNoteCmd(text: body, at: DateTime.now()));
      await cmd(tester, h, addNoteCmd(text: 'took 3 days because of flaky CI', at: DateTime.now(), attachTo: retro));
      await cmd(tester, h, addNoteCmd(text: 'Whiteboard sketch', at: DateTime.now(), images: [(_png, 'png')]));
      await settle(tester, until: () => find.text('Whiteboard sketch').evaluate().isNotEmpty);
      await settle(tester, until: () => find.textContaining('took 3 days').evaluate().isNotEmpty);

      final row = _rowOf('Retro notes');
      final titleLeft = _r(tester, find.text('Retro notes')).left;
      final noteBody = _in(row, find.text(body));
      expect(noteBody, findsOneWidget, reason: 'the multi-line note body');
      expect(_r(tester, noteBody).left, closeTo(titleLeft, 1), reason: 'body indented under the title');
      expect(_r(tester, noteBody).top, greaterThanOrEqualTo(_r(tester, find.text('Retro notes')).bottom));
      final annot = find.ancestor(of: find.textContaining('took 3 days'), matching: find.byType(Container)).first;
      expect(_r(tester, annot).left, closeTo(titleLeft, 1), reason: 'annotation indented under the title');
      expect(_r(tester, annot).top, greaterThan(_r(tester, find.text('Retro notes')).bottom));
      // The first line stays one line: time, title and chip level.
      _sameRow(tester, _time(row), find.text('Retro notes'));

      final shotRow = _rowOf('Whiteboard sketch');
      final thumbs = _in(shotRow, find.byType(Wrap));
      expect(thumbs, findsOneWidget, reason: 'the screenshot strip');
      expect(_r(tester, thumbs).left, closeTo(_r(tester, find.text('Whiteboard sketch')).left, 1),
          reason: 'screenshots indented under the title');
      expect(_r(tester, thumbs).top, greaterThan(_r(tester, find.text('Whiteboard sketch')).bottom));
      expect(tester.takeException(), isNull);
      await killEngine(tester, h);
    });

    testWidgets('Today keeps the two-line row (kind icon, meta line, no project detail)', (tester) async {
      final (_, h) = await bootPage(tester, dir, const TodayPage());
      await cmd(tester, h, addNoteCmd(text: 'Two-line row', at: DateTime.now()));
      await settle(tester, until: () => find.text('Two-line row').evaluate().isNotEmpty);
      final row = _rowOf('Two-line row');
      expect(tester.widget<EvidenceRow>(row).compact, isFalse);
      expect(_in(row, find.byType(KindIcon)), findsOneWidget);
      expect(_in(row, find.byWidgetPredicate((w) => w is Muted && w.text == 'Notes · Note')), findsOneWidget);
      expect(_r(tester, _in(row, find.text('Notes · Note'))).top, greaterThan(_r(tester, find.text('Two-line row')).bottom - 0.5));
      await killEngine(tester, h);
    });
  });

  // -------------------------------------------------------------------------
  group('WideDialog', () {
    testWidgets('is an AntDialog with a wider width and the same divided footer', (tester) async {
      await tester.pumpWidget(ProviderScope(
        child: pageApp(Builder(
          builder: (context) => AntButton(
            label: 'Open',
            onPressed: () => showAntDialog<void>(
              context,
              builder: (_) => WideDialog(
                title: 'Add repositories',
                subtitle: 'Pick the repos to import',
                body: const Text('Body'),
                leadingActions: [AntButton.ghost(label: 'Back', onPressed: () {})],
                actions: [AntButton.primary(label: 'Add', onPressed: () {})],
              ),
            ),
          ),
        )),
      ));
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final d = find.descendant(of: find.byType(WideDialog), matching: find.byType(AntDialog));
      expect(d, findsOneWidget);
      final t = tester.element(d).tokens;
      final dialog = tester.widget<AntDialog>(d);
      expect((dialog.title, dialog.subtitle), ('Add repositories', 'Pick the repos to import'));
      expect(dialog.width, greaterThan(t.density.dialogWidth));
      expect(dialog.width, closeTo(t.density.dialogWidth * 1.45, 0.01));
      final panel = find.descendant(of: d, matching: find.byType(Container)).first;
      expect(_r(tester, panel).width, closeTo(t.density.dialogWidth * 1.45, 0.5));
      // Footer: divider above Back (left) and Add (right).
      final footer = find.ancestor(
        of: find.widgetWithText(AntButton, 'Add'),
        matching: find.byWidgetPredicate((w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            ((w.decoration as BoxDecoration).border as Border?)?.top.color == t.divider),
      );
      expect(footer, findsOneWidget);
      expect(find.ancestor(of: find.widgetWithText(AntButton, 'Back'), matching: footer), findsOneWidget);
      expect(_r(tester, find.widgetWithText(AntButton, 'Back')).left, closeTo(_r(tester, panel).left + t.space.xxl, 1));
      expect(_r(tester, find.widgetWithText(AntButton, 'Add')).right, closeTo(_r(tester, panel).right - t.space.xxl, 1));
    });
  });

  // -------------------------------------------------------------------------
  group('Settings → AI models empty state', () {
    Finder empty() => find.byType(AntEmptyState);
    Finder primary(String label) => find.byWidgetPredicate((w) => w is AntButton && w.label == label);

    testWidgets('no provider: "Connect OpenRouter" opens the OpenRouter dialog', (tester) async {
      final (_, h) = await bootPage(tester, dir, const AiModelsTab(), size: const Size(1400, 2000));
      await settle(tester, until: () => empty().evaluate().isNotEmpty);
      expect(empty(), findsOneWidget);
      expect(find.text('No AI model yet'), findsOneWidget);
      expect(primary('Connect OpenRouter'), findsOneWidget);
      expect(primary('Add a model'), findsNothing);
      expect(find.text('DEFAULT MODEL'), findsNothing, reason: 'the empty state replaces the default picker');
      expect(find.text('Customize per task'), findsOneWidget, reason: 'per-task routes stay reachable');
      await tester.tap(primary('Connect OpenRouter'));
      await settle(tester, until: () => find.byType(ProviderDialog).evaluate().isNotEmpty);
      final pd = tester.widget<ProviderDialog>(find.byType(ProviderDialog));
      expect((pd.preset.kind, pd.existing), (ProviderKind.openrouter, null));
      expect(find.text('Connect OpenRouter'), findsWidgets, reason: 'dialog title');
      await killEngine(tester, h);
    });

    testWidgets('provider but no model: "Add a model" opens that provider', (tester) async {
      final (_, h) = await bootPage(tester, dir, const AiModelsTab(), size: const Size(1400, 2000));
      final (pid, _) = await cmd(
          tester,
          h,
          saveProviderCmd(
              kind: ProviderKind.custom, name: 'Fake', baseUrl: 'http://127.0.0.1:9/v1', protocol: ProviderProtocol.openai));
      await settle(tester, until: () => primary('Add a model').evaluate().isNotEmpty);
      expect(empty(), findsOneWidget);
      expect(primary('Add a model'), findsOneWidget);
      expect(primary('Connect OpenRouter'), findsNothing);
      await tester.tap(primary('Add a model'));
      await settle(tester, until: () => find.byType(ProviderDialog).evaluate().isNotEmpty);
      expect(tester.widget<ProviderDialog>(find.byType(ProviderDialog)).existing?.id, pid);
      await killEngine(tester, h);
    });

    testWidgets('a model replaces the empty state with the default picker', (tester) async {
      final llm = (await tester.runAsync(FakeLlm.start))!;
      addTearDown(() => tester.runAsync(llm.close));
      final (_, h) = await bootPage(tester, dir, const AiModelsTab(), size: const Size(1400, 2000));
      await settle(tester, until: () => empty().evaluate().isNotEmpty);
      await tester.runAsync(() => addFakeModel(h, llm));
      await settle(tester, until: () => empty().evaluate().isEmpty);
      expect(empty(), findsNothing);
      expect(find.text('DEFAULT MODEL'), findsOneWidget);
      expect(find.byType(DefaultModelPicker), findsOneWidget);
      await killEngine(tester, h);
    });

    testWidgets('the vision / extraction / reports routes open from the empty state', (tester) async {
      final (_, h) = await bootPage(tester, dir, const AiModelsTab(), size: const Size(1400, 2000));
      await settle(tester, until: () => empty().evaluate().isNotEmpty);
      await tester.tap(find.text('Customize per task'));
      await settle(tester, until: () => find.text('Vision').evaluate().isNotEmpty);
      for (final r in ['Vision', 'Extraction', 'Reports']) {
        expect(find.byWidgetPredicate((w) => w is PanelRow && w.title == r), findsOneWidget, reason: r);
      }
      expect(empty(), findsOneWidget, reason: 'still the empty state');
      await killEngine(tester, h);
    });

    testWidgets('no empty state while models are still loading', (tester) async {
      tester.view.physicalSize = const Size(1400, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final never = StreamController<List<Model>>();
      addTearDown(never.close);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          llmModelsProvider.overrideWith((ref) => never.stream),
          llmProvidersProvider.overrideWith((ref) => Stream.value(const <core.Provider>[])),
          taskRoutesProvider.overrideWith((ref) => Stream.value(const <LlmRoute, String>{})),
          localServersProvider.overrideWith((ref) async => const <LocalServer>[]),
        ],
        child: pageApp(const AiModelsTab()),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(empty(), findsNothing, reason: 'no flash of "No AI model yet" while loading');
      expect(find.text('No AI model yet'), findsNothing);
      expect(primary('Connect OpenRouter'), findsNothing);
      // Once the (empty) list arrives, the empty state shows.
      never.add(const []);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(empty(), findsOneWidget);
      expect(primary('Connect OpenRouter'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  group('focus ring at AntInteractive(focusRadius:) sites', () {
    testWidgets('PanelRow with onTap: inset, square ring on keyboard focus only', (tester) async {
      await tester.pumpWidget(ProviderScope(
        child: pageApp(SizedBox(
          width: 600,
          child: ListPanel(children: [PanelRow(title: 'Clickable row', onTap: () {}), const PanelRow(title: 'Static row')]),
        )),
      ));
      final row = find.ancestor(of: find.text('Clickable row'), matching: find.byType(AntInteractive));
      // Mouse hover + click: no ring.
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(row));
      await tester.pump();
      await tester.tap(row, kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      expect(_rings(row), findsNothing, reason: 'mouse');
      await mouse.moveTo(Offset.zero);
      final deco = await _expectRingOnKeyboardFocus(tester, row);
      final side = (deco.border! as Border).top;
      expect(side.strokeAlign, BorderSide.strokeAlignInside, reason: 'full-bleed row in a clipped panel');
      expect(deco.borderRadius, BorderRadius.zero);
      expect(find.ancestor(of: find.text('Static row'), matching: find.byType(AntInteractive)), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('Settings → AI models: "Customize per task" disclosure', (tester) async {
      final (_, h) = await bootPage(tester, dir, const AiModelsTab(), size: const Size(1400, 2000));
      await settle(tester, until: () => find.text('Customize per task').evaluate().isNotEmpty);
      final deco = await _expectRingOnKeyboardFocus(tester, _interactive('Customize per task'));
      expect(((deco.border! as Border).top).strokeAlign, BorderSide.strokeAlignOutside);
      expect(deco.borderRadius, _t.radii.brMd);
      await killEngine(tester, h);
    });

    testWidgets('Timeline day header', (tester) async {
      final (_, h) = await bootPage(tester, dir, const TimelinePage());
      await cmd(tester, h, addNoteCmd(text: 'Something', at: DateTime.now()));
      final header = _interactive('Open ${todayDay()} in Today');
      await settle(tester, until: () => header.evaluate().isNotEmpty);
      final deco = await _expectRingOnKeyboardFocus(tester, header);
      expect(deco.borderRadius, _t.radii.brMd);
      await killEngine(tester, h);
    });

    testWidgets('Reports list row', (tester) async {
      final llm = (await tester.runAsync(FakeLlm.start))!;
      addTearDown(() => tester.runAsync(llm.close));
      final (_, h) = await bootPage(tester, dir, const ReportsPage());
      await tester.runAsync(() => addFakeModel(h, llm));
      final today = todayDay();
      final ev = await cmd(tester, h, addNoteCmd(text: 'Shipped it', at: DateTime.now()));
      await cmd(tester, h, createFactCmd([ev], statement: 'Shipped it', day: today));
      final week = Period.containing(PeriodKind.weekly, today);
      final report = await cmd(
          tester, h, ensureReportCmd(PeriodKind.weekly, week.start, week.end, defaultTemplateFor[PeriodKind.weekly]!));
      await cmd(tester, h, generateReportCmd(report));
      final item = _interactive(periodLabel(week));
      await settle(tester, until: () => item.evaluate().isNotEmpty);
      final deco = await _expectRingOnKeyboardFocus(tester, item);
      expect(deco.borderRadius, _t.radii.brMd);
      await killEngine(tester, h);
    });

    testWidgets('profile switcher', (tester) async {
      // Past the onboarding gate before the shell is built (as in shell_widget_test).
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = ProviderContainer(overrides: [
        engineConfigProvider.overrideWithValue(testConfig(dir.path)),
        uiPortHostProvider.overrideWithValue(fakeHost()),
      ]);
      addTearDown(c.dispose);
      final h = (await tester.runAsync(() => c.read(engineProvider.future)))!;
      await cmd(tester, h, setSettingCmd(onboardingDoneSettingKey, 'true'));
      await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const AntApp()));
      final sw = _interactive('Switch profile');
      await settle(tester, until: () => sw.evaluate().isNotEmpty);
      final deco = await _expectRingOnKeyboardFocus(tester, sw);
      expect(deco.borderRadius, _t.radii.brMd);
      await killEngine(tester, h);
    });
  });
}
