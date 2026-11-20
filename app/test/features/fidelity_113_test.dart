/// Independent tests (#99) for parts of the DECISIONS #113 visual-fidelity pass: quick capture's
/// layout and behaviour, top bars (TopBar / SectionHeader / PageTopBar) keeping title, tabs and a
/// one-line subtitle on one row with actions at the right edge, fact-tile actions on the chip row
/// (not hit-testable while hidden), and page-level empty states at the top on Projects and Reports.
/// Layout invariants only (order, alignment, no overflow), not pixels.
library;

import 'dart:convert';
import 'dart:io';

import 'package:ant_manager/engine/commands.dart';
import 'package:ant_manager/features/projects/projects_page.dart';
import 'package:ant_manager/features/reports/reports_page.dart';
import 'package:ant_manager/features/settings/kit.dart' show PageTopBar;
import 'package:ant_manager/shell/quick_capture.dart';
import 'package:ant_manager/shell/shell_state.dart';
import 'package:ant_manager/state/data.dart' show FactItem, CitationRef;
import 'package:ant_manager/state/providers.dart';
import 'package:ant_manager/widgets/common.dart';
import 'package:ant_manager/widgets/fact_tile.dart';
import 'package:core/core.dart' hide Provider;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui/ui.dart';

import 'support.dart';

/// Tests documenting a known BUG are skipped unless run with `--dart-define=RUN_BUGS=true`
/// (same convention as packages/ui/test/helpers.dart).
const bugSkip = !bool.fromEnvironment('RUN_BUGS');

final _t = AntTokens.light();

/// The quick-capture window size (DesktopShell.quickCaptureSize).
const _qcSize = Size(480, 300);

Rect _r(WidgetTester tester, Finder f) => tester.getRect(f);

/// [a] and [b] sit on one row: their vertical centres are within [tol] px.
void _sameRow(WidgetTester tester, Finder a, Finder b, {double tol = 4, String? reason}) {
  final ca = _r(tester, a).center.dy, cb = _r(tester, b).center.dy;
  expect((ca - cb).abs(), lessThanOrEqualTo(tol), reason: reason ?? 'same row ($ca vs $cb)');
}

/// [left] ends before [right] starts.
void _before(WidgetTester tester, Finder left, Finder right, {String? reason}) {
  expect(_r(tester, left).right, lessThanOrEqualTo(_r(tester, right).left + 0.5), reason: reason);
}

/// The paragraph rendering [text] (exact match).
RenderParagraph _para(WidgetTester tester, String text) =>
    tester.renderObject<RenderParagraph>(find.text(text));

Widget _host(Widget child, {double? width}) => ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: antTheme(_t),
        home: Material(
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: width, child: child),
          ),
        ),
      ),
    );

Future<void> _size(WidgetTester tester, Size s) async {
  tester.view.physicalSize = s;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Fact _fact({String statement = 'A fact', FactOrigin origin = FactOrigin.inferred}) => Fact(
      id: 'f1',
      type: FactType.outcome,
      statement: statement,
      details: '{}',
      periodStart: '2026-11-17',
      periodEnd: '2026-11-17',
      importance: 0.5,
      origin: origin,
      reviewState: ReviewState.ok,
      winStatus: WinStatus.none,
      retired: false,
      revision: 1,
      createdAt: DateTime.utc(2026, 11, 17),
      updatedAt: DateTime.utc(2026, 11, 17),
    );

void main() {
  // -------------------------------------------------------------------------
  group('quick capture', () {
    late Directory dir;
    setUp(() => dir = tempDir());
    tearDown(() => dir.deleteSync(recursive: true));

    Finder saveButton() => find.widgetWithText(AntButton, 'Save');
    Finder note() => find.descendant(of: find.byType(QuickCaptureView), matching: find.byType(TextField)).first;
    Finder select() => find.byType(AntSelect<String?>);
    Finder link() => find.byType(AntTextField);

    testWidgets('header: Quick note, profile and time, esc; then the note; then the footer', (tester) async {
      final (c, h) = await bootPage(tester, dir, const QuickCaptureView(), size: _qcSize);
      final profile = c.read(activeProfileProvider)!.name;
      expect(find.text('Quick note'), findsOneWidget);
      final meta = find.textContaining(RegExp('^· ${RegExp.escape(profile)} · today \\d{2}:\\d{2}\$'));
      expect(meta, findsOneWidget, reason: 'profile then "today HH:MM"');
      final esc = find.text('esc');
      expect(esc, findsOneWidget);
      // Header row: Quick note → profile/time → esc, esc at the right edge.
      _sameRow(tester, find.text('Quick note'), meta);
      _sameRow(tester, find.text('Quick note'), esc);
      _before(tester, find.text('Quick note'), meta);
      _before(tester, meta, esc);
      expect(_r(tester, find.widgetWithText(AntKbd, 'esc')).right, closeTo(_qcSize.width - _t.space.xl, 1),
          reason: 'esc hint at the right edge');
      // Note area between header and footer, using the full width minus padding.
      expect(find.text('What just happened? Blocker, decision, offline work…'), findsOneWidget);
      expect(_r(tester, esc).bottom, lessThan(_r(tester, note()).top));
      expect(_r(tester, note()).bottom, lessThan(_r(tester, saveButton()).top));
      expect(_r(tester, note()).width, closeTo(_qcSize.width - 2 * _t.space.xl, 1));
      // Footer: project, link, (screenshot,) Save on one row, Save at the right edge.
      expect(find.text('No project'), findsOneWidget);
      expect(find.text('Link (optional)'), findsOneWidget);
      _sameRow(tester, select(), link());
      _sameRow(tester, select(), saveButton());
      _before(tester, select(), link());
      _before(tester, link(), saveButton());
      final shot = find.byTooltip('Capture a screen region');
      if (Platform.isMacOS) {
        expect(shot, findsOneWidget);
        _before(tester, link(), shot);
        _before(tester, shot, saveButton());
        _sameRow(tester, shot, saveButton());
      } else {
        expect(shot, findsNothing, reason: 'region capture is macOS-only');
      }
      expect(_r(tester, saveButton()).right, closeTo(_qcSize.width - _t.space.xl, 1));
      expect(_r(tester, saveButton()).bottom, lessThanOrEqualTo(_qcSize.height));
      expect(tester.takeException(), isNull);
      await killEngine(tester, h);
    });

    testWidgets('Save shows ⌘ ⏎ on macOS', (tester) async {
      final (_, h) = await bootPage(tester, dir, const QuickCaptureView(), size: _qcSize);
      final kbd = find.descendant(of: saveButton(), matching: find.byType(AntKbd));
      expect(tester.widget<AntKbd>(kbd).keys, ['⌘', '⏎']);
      await killEngine(tester, h);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('Save shows Ctrl ⏎ off macOS', (tester) async {
      final (_, h) = await bootPage(tester, dir, const QuickCaptureView(), size: _qcSize);
      final kbd = find.descendant(of: saveButton(), matching: find.byType(AntKbd));
      expect(tester.widget<AntKbd>(kbd).keys, ['Ctrl', '⏎']);
      await killEngine(tester, h);
    }, variant: const TargetPlatformVariant({TargetPlatform.windows, TargetPlatform.linux}));

    testWidgets('Save adds a note with the link and the chosen project, then closes', (tester) async {
      final (c, h) = await bootPage(tester, dir, const QuickCaptureView(), size: _qcSize);
      final pid = await cmd(tester, h, createProjectCmd('Checkout'));
      await settle(tester);
      c.read(quickCaptureModeProvider.notifier).set(true);
      await tester.enterText(note(), '  Unblocked the deploy  ');
      await tester.enterText(find.descendant(of: link(), matching: find.byType(TextField)), ' https://x.test/1 ');
      await tester.tap(select());
      await settle(tester);
      await tester.tap(find.text('Checkout').last);
      await settle(tester);
      expect(find.descendant(of: select(), matching: find.text('Checkout')), findsOneWidget);
      await tester.tap(saveButton());
      await settle(tester, until: () => !c.read(quickCaptureModeProvider));
      expect(c.read(quickCaptureModeProvider), isFalse, reason: 'closes after saving');
      final e = (await read(tester, () => h.db.select(h.db.evidences).get())).single;
      expect(e.projectId, pid);
      expect(e.title, 'Unblocked the deploy', reason: 'note trimmed');
      final payload =
          (await read(tester, () => (h.db.select(h.db.payloads)..where((x) => x.evidenceId.equals(e.id))).get())).single;
      final content = jsonDecode(payload.content) as Map;
      expect((content['text'], content['link']), ('Unblocked the deploy', 'https://x.test/1'), reason: 'trimmed');
      expect(e.day, dayOf(DateTime.now(), Duration.zero), reason: 'UTC profile zone');
      await killEngine(tester, h);
    });

    testWidgets('Save with an empty note and no screenshot does nothing', (tester) async {
      final (c, h) = await bootPage(tester, dir, const QuickCaptureView(), size: _qcSize);
      c.read(quickCaptureModeProvider.notifier).set(true);
      await tester.enterText(note(), '   ');
      await tester.tap(saveButton());
      await settle(tester);
      expect(c.read(quickCaptureModeProvider), isTrue, reason: 'stays open');
      expect(await read(tester, () => h.db.select(h.db.evidences).get()), isEmpty);
      await killEngine(tester, h);
    });

    testWidgets('esc closes; ⌘⏎ and Ctrl+⏎ save', (tester) async {
      final (c, h) = await bootPage(tester, dir, const QuickCaptureView(), size: _qcSize);
      c.read(quickCaptureModeProvider.notifier).set(true);
      await tester.tap(note());
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(c.read(quickCaptureModeProvider), isFalse, reason: 'esc closes');

      for (final mod in [LogicalKeyboardKey.metaLeft, LogicalKeyboardKey.controlLeft]) {
        c.read(quickCaptureModeProvider.notifier).set(true);
        await tester.enterText(note(), 'via $mod');
        await tester.sendKeyDownEvent(mod);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyUpEvent(mod);
        await settle(tester, until: () => !c.read(quickCaptureModeProvider));
        expect(c.read(quickCaptureModeProvider), isFalse, reason: '$mod+enter saves and closes');
      }
      final ev = await read(tester, () => h.db.select(h.db.evidences).get());
      expect(ev, hasLength(2));
      await killEngine(tester, h);
    });

    testWidgets('a long project name does not overflow the footer', (tester) async {
      // Was a BUG-skip (unbounded AntSelect label); fixed by #120 (e): the label ellipsizes.
      final (c, h) = await bootPage(tester, dir, const QuickCaptureView(), size: _qcSize);
      const long = 'Platform reliability and incident follow-ups for the checkout migration';
      await cmd(tester, h, createProjectCmd(long));
      await settle(tester);
      await tester.tap(select());
      await settle(tester);
      await tester.tap(find.text(long).last);
      await settle(tester);
      final label = find.descendant(of: select(), matching: find.text(long));
      expect(label, findsOneWidget, reason: 'selected');
      expect(tester.takeException(), isNull, reason: 'no overflow error');
      final box = _r(tester, select());
      expect(box.width, lessThanOrEqualTo(_t.density.menuMinWidth + 0.5));
      // The label is drawn inside the select (today it is laid out ~900px wide, past the window).
      expect(_r(tester, label).right, lessThanOrEqualTo(box.right + 0.5), reason: 'label stays inside the select');
      expect(_r(tester, label).top, greaterThanOrEqualTo(box.top - 0.5), reason: 'label stays inside the select');
      _before(tester, select(), link());
      expect(_r(tester, saveButton()).right, lessThanOrEqualTo(_qcSize.width));
      await killEngine(tester, h);
    });
  });

  // -------------------------------------------------------------------------
  group('TopBar', () {
    const subtitle = 'Evidence and facts are grouped into projects; you can correct any of them, '
        'and the model keeps filing new work into them as it arrives.';
    Widget bar() => TopBar(
          title: 'Projects',
          subtitle: subtitle,
          middle: [
            AntTabs<int>(
              value: 0,
              onChanged: (_) {},
              tabs: const [AntTab(value: 0, label: 'Daily'), AntTab(value: 1, label: 'Weekly')],
            ),
          ],
          actions: [AntButton(label: 'New project', icon: Icons.add_rounded, onPressed: () {})],
        );

    testWidgets('title, subtitle, tabs and actions sit on one row in order; actions at the right edge',
        (tester) async {
      await _size(tester, const Size(1400, 400));
      await tester.pumpWidget(_host(bar(), width: 1400));
      final title = find.text('Projects'), sub = find.text(subtitle), tab = find.text('Daily');
      final action = find.widgetWithText(AntButton, 'New project');
      for (final f in [sub, tab, action]) {
        _sameRow(tester, title, f);
      }
      _before(tester, title, sub);
      _before(tester, sub, tab, reason: 'tabs follow the subtitle');
      _before(tester, tab, action);
      expect(_r(tester, action).right, closeTo(1400 - _t.space.xxxl, 1), reason: 'actions at the right edge');
      expect(_para(tester, subtitle).maxLines, 1);
      expect(_r(tester, find.byType(TopBar)).height, closeTo(_t.density.topbarHeight, 0.5),
          reason: 'one row: the bar stays at its minimum height');
    });

    testWidgets('without middle widgets, actions still sit at the right edge', (tester) async {
      await _size(tester, const Size(1200, 400));
      await tester.pumpWidget(_host(
        TopBar(title: 'Wins', actions: [AntButton(label: 'Export', onPressed: () {})]),
        width: 1200,
      ));
      expect(_r(tester, find.widgetWithText(AntButton, 'Export')).right, closeTo(1200 - _t.space.xxxl, 1));
    });

    // Narrowest page: the 900px minimum window minus the sidebar.
    final narrow = 900 - _t.density.sidebarWidth;

    testWidgets('a long subtitle ellipsizes on one line at the narrowest page width', (tester) async {
      // Was a BUG-skip (fixed-width subtitle overflowed); fixed by #120 (f).
      await _size(tester, Size(narrow, 400));
      await tester.pumpWidget(_host(bar(), width: narrow));
      expect(tester.takeException(), isNull, reason: 'no overflow');
      final action = find.widgetWithText(AntButton, 'New project');
      expect(_r(tester, action).right, lessThanOrEqualTo(narrow - _t.space.xxxl + 0.5));
      _before(tester, find.text(subtitle), action);
      expect(_para(tester, subtitle).didExceedMaxLines, isTrue, reason: 'ellipsized, one line');
    });

    testWidgets('at a wide width a long subtitle is still one line (bounded, ellipsized)', (tester) async {
      await _size(tester, const Size(1400, 400));
      await tester.pumpWidget(_host(bar(), width: 1400));
      expect(tester.takeException(), isNull);
      expect(_para(tester, subtitle).didExceedMaxLines, isTrue,
          reason: 'longer than its bound → ellipsis, not a second line');
    });
  });

  // -------------------------------------------------------------------------
  group('SectionHeader', () {
    const note = 'A long note about what this section holds, how it was generated, and what the model '
        'thinks about it, long enough to need more than one line at a narrow width.';

    testWidgets('label, note and trailing on one row; trailing at the right edge; note ellipsizes',
        (tester) async {
      for (final w in [1000.0, 360.0]) {
        await _size(tester, Size(w, 300));
        await tester.pumpWidget(_host(
          SectionHeader('Highlights', note: note, trailing: [AntButton.ghost(label: 'All', onPressed: () {})]),
          width: w,
        ));
        expect(tester.takeException(), isNull, reason: 'no overflow at $w');
        final label = find.text('HIGHLIGHTS'), n = find.text(note);
        final trailing = find.widgetWithText(AntButton, 'All');
        _sameRow(tester, label, n);
        _sameRow(tester, label, trailing);
        _before(tester, label, n);
        _before(tester, n, trailing);
        expect(_r(tester, trailing).right, closeTo(w, 1), reason: 'trailing at the right edge ($w)');
        expect(_para(tester, note).didExceedMaxLines, isTrue, reason: 'one ellipsized line ($w)');
      }
    });

    testWidgets('without a note, trailing still sits at the right edge', (tester) async {
      await _size(tester, const Size(800, 300));
      await tester.pumpWidget(_host(
        SectionHeader('Wins', trailing: [AntButton.ghost(label: 'All', onPressed: () {})]),
        width: 800,
      ));
      expect(_r(tester, find.widgetWithText(AntButton, 'All')).right, closeTo(800, 1));
    });
  });

  // -------------------------------------------------------------------------
  group('PageTopBar', () {
    const subtitle = 'Where your evidence comes from: git repositories, calendars and notes, synced in the '
        'background while the app runs and paused whenever you ask.';
    Widget bar() => PageTopBar(
          title: 'Sources',
          subtitle: subtitle,
          center: AntTabs<int>(
            value: 0,
            onChanged: (_) {},
            tabs: const [AntTab(value: 0, label: 'All'), AntTab(value: 1, label: 'Git')],
          ),
          actions: [
            AntButton.ghost(label: 'Sync now', onPressed: () {}),
            AntButton(label: 'Add source', onPressed: () {}),
          ],
        );

    for (final w in [1400.0, 900 - _t.density.sidebarWidth]) {
      testWidgets('title, tabs, subtitle, actions on one row; actions at the right edge (width $w)',
          (tester) async {
        await _size(tester, Size(w, 300));
        await tester.pumpWidget(_host(bar(), width: w));
        expect(tester.takeException(), isNull, reason: 'no overflow');
        final title = find.text('Sources'), tab = find.text('Git'), sub = find.text(subtitle);
        final sync = find.widgetWithText(AntButton, 'Sync now'), add = find.widgetWithText(AntButton, 'Add source');
        for (final f in [tab, sub, sync, add]) {
          _sameRow(tester, title, f);
        }
        _before(tester, title, tab);
        _before(tester, tab, sub, reason: 'tabs right after the title, then the subtitle');
        _before(tester, sub, sync);
        _before(tester, sync, add);
        expect(_r(tester, add).right, closeTo(w - _t.space.xxxl, 1));
        expect(_para(tester, subtitle).didExceedMaxLines, isTrue, reason: 'one ellipsized line');
      });
    }
  });

  // -------------------------------------------------------------------------
  group('FactTile actions', () {
    const long = 'Moved the payments retry worker onto the shared queue, cut duplicate charges to zero over '
        'the week and wrote the runbook the on-call team now uses for every retry incident.';

    Future<void> pumpTile(WidgetTester tester, {bool flush = false, FactOrigin origin = FactOrigin.inferred}) async {
      await _size(tester, const Size(700, 400));
      await tester.pumpWidget(_host(
        Padding(
          padding: const EdgeInsets.all(20),
          child: FactTile(
            item: FactItem(_fact(statement: long, origin: origin), [
              CitationRef(payloadId: 'p', evidenceId: 'e', day: '2026-11-17', title: 'Retry PR', kind: PayloadKind.commit),
            ]),
            flush: flush,
          ),
        ),
        width: 700,
      ));
      await tester.pump(const Duration(milliseconds: 300));
    }

    Finder edit() => find.byTooltip('Edit');
    Finder chip() => find.text('Outcome');

    testWidgets('actions sit on the chip row, above the full-width statement', (tester) async {
      await pumpTile(tester);
      expect(edit(), findsOneWidget, reason: 'laid out even while hidden');
      _sameRow(tester, chip(), edit(), tol: 6);
      final statement = _r(tester, find.text(long));
      expect(_r(tester, edit()).bottom, lessThanOrEqualTo(statement.top + 0.5), reason: 'above the statement');
      expect(statement.right, greaterThan(_r(tester, find.byTooltip('Confirm')).left),
          reason: 'the statement runs under the actions column');
      expect(statement.right, closeTo(700 - 20 - _t.space.md, 24), reason: 'wrapped statement fills the content width');
      expect(_r(tester, find.byTooltip('Reject')).right, closeTo(700 - 20 - _t.space.md, 1),
          reason: 'actions at the tile right edge');
    });

    testWidgets('hidden actions are not hit-testable; hover reveals them without moving the statement',
        (tester) async {
      await pumpTile(tester);
      final before = _r(tester, find.text(long));
      expect(edit().hitTestable(), findsNothing);
      expect(find.byTooltip('Confirm').hitTestable(), findsNothing);
      expect(find.byTooltip('Reject').hitTestable(), findsNothing);
      final opacity = find.ancestor(of: edit(), matching: find.byType(AnimatedOpacity));
      expect(tester.widget<AnimatedOpacity>(opacity).opacity, 0);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.text(long)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(edit().hitTestable(), findsOneWidget);
      expect(find.byTooltip('Confirm').hitTestable(), findsOneWidget);
      expect(tester.widget<AnimatedOpacity>(opacity).opacity, 1);
      expect(_r(tester, find.text(long)), before, reason: 'statement does not shift');

      await mouse.moveTo(Offset(10, _r(tester, find.byType(FactTile)).bottom + 10));
      await tester.pump(const Duration(milliseconds: 300));
      expect(edit().hitTestable(), findsNothing, reason: 'hidden again after the pointer leaves');
    });

    testWidgets('flush tiles always show hit-testable actions and have no inset', (tester) async {
      await pumpTile(tester, flush: true);
      expect(edit().hitTestable(), findsOneWidget);
      _sameRow(tester, chip(), edit(), tol: 6);
      final tile = _r(tester, find.byType(FactTile));
      expect(_r(tester, find.text(long)).left, closeTo(tile.left, 0.5));
      expect(_r(tester, find.byTooltip('Reject')).right, closeTo(tile.right, 1));
    });

    testWidgets('a confirmed fact offers edit and reject but no confirm', (tester) async {
      await pumpTile(tester, flush: true, origin: FactOrigin.confirmed);
      expect(find.byTooltip('Confirm'), findsNothing);
      expect(edit().hitTestable(), findsOneWidget);
      expect(find.byTooltip('Reject').hitTestable(), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  group('page-level empty states sit at the top', () {
    late Directory dir;
    setUp(() => dir = tempDir());
    tearDown(() => dir.deleteSync(recursive: true));

    for (final (name, page, title) in [
      ('Projects', const ProjectsPage() as Widget, 'No projects yet'),
      ('Reports', const ReportsPage() as Widget, 'No weekly reports yet'),
    ]) {
      testWidgets(name, (tester) async {
        final (_, h) = await bootPage(tester, dir, page, size: const Size(1200, 900));
        await settle(tester, until: () => find.text(title).evaluate().isNotEmpty);
        final empty = find.byType(AntEmptyState);
        expect(empty, findsOneWidget);
        expect(find.text(title), findsOneWidget);
        final bar = _r(tester, find.byType(TopBar));
        final box = _r(tester, find.byType(PageEmpty));
        final card = _r(tester, empty);
        expect(box.top, closeTo(bar.bottom, 0.5), reason: 'PageEmpty fills the body under the bar');
        expect(card.top, closeTo(bar.bottom + _t.space.xl, 1), reason: 'top-aligned, not vertically centred');
        expect(card.height, lessThan(box.height / 2), reason: 'does not stretch to the body height');
        expect(card.center.dx, closeTo(box.center.dx, 1), reason: 'horizontally centred');
        expect(tester.takeException(), isNull);
        await killEngine(tester, h);
      });
    }
  });
}
