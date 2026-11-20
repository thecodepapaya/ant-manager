/// Independent tests (#99) for DECISIONS #130 (Kimi review fixes, app UI): evidence payloads in
/// insertion order, Today's day keys leaving the note composer alone, the midnight rollover of
/// Today and its badge, and the plain-HTTP warning in the provider dialog.
library;

import 'dart:async';
import 'dart:io';

import 'package:ant_manager/app.dart';
import 'package:ant_manager/engine/commands.dart';
import 'package:ant_manager/engine/engine_handle.dart';
import 'package:ant_manager/engine/setup_commands.dart';
import 'package:ant_manager/features/settings/provider_dialog.dart';
import 'package:ant_manager/features/settings/setup_providers.dart';
import 'package:ant_manager/features/today/today_page.dart';
import 'package:ant_manager/platform/time_zone.dart';
import 'package:ant_manager/shell/shell_state.dart';
import 'package:ant_manager/state/data.dart';
import 'package:ant_manager/state/providers.dart';
import 'package:ant_manager/widgets/common.dart';
import 'package:ant_manager/widgets/note_composer.dart';
import 'package:core/core.dart' hide Provider;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui/ui.dart';

import 'support.dart';

const bugSkip = !bool.fromEnvironment('RUN_BUGS');

const _plainHttpWarning = 'Plain HTTP to another machine: your evidence travels unencrypted on the network.';

Finder _field(String label) => find.descendant(
      of: find.byWidgetPredicate((w) => w is AntTextField && w.label == label),
      matching: find.byType(TextField),
    );

Finder _button(String label) => find.byWidgetPredicate((w) => w is AntButton && w.label == label);

Finder _composerField() => find.descendant(of: find.byType(NoteComposer), matching: find.byType(TextField)).first;

/// A fake profile wall clock: the profile offset is chosen so that "now" reads as [wall] (UTC
/// fields) in the profile zone, and [advance] moves that wall clock together with the test's
/// fake time, so the one-minute timer sees the day change exactly as it would at midnight.
class _WallClock {
  _WallClock(DateTime wall) : _offset = wall.difference(DateTime.now().toUtc()) {
    profileUtcOffset = (_) => _offset;
  }
  Duration _offset;

  Future<void> advance(WidgetTester tester, Duration d, {Duration step = const Duration(seconds: 10)}) async {
    var left = d;
    while (left > Duration.zero) {
      final s = left < step ? left : step;
      _offset += s;
      await tester.pump(s);
      left -= s;
    }
  }
}

void main() {
  late Directory dir;
  late UtcOffset savedOffset;
  setUp(() {
    dir = tempDir();
    savedOffset = profileUtcOffset;
  });
  tearDown(() {
    profileUtcOffset = savedOffset;
    dir.deleteSync(recursive: true);
  });

  // -------------------------------------------------------------------------
  // (1) Payloads in insertion order.
  // -------------------------------------------------------------------------
  group('evidence payload order', () {
    late ProviderContainer container;
    late EngineHandle h;

    setUp(() async {
      container = ProviderContainer(overrides: [engineConfigProvider.overrideWithValue(testConfig(dir.path))]);
      h = await container.read(engineProvider.future);
    });
    tearDown(() async {
      container.dispose();
      await h.shutdown();
    });

    Future<List<EvidenceItem>> load(EvidenceQuery q, int count) {
      final c = Completer<List<EvidenceItem>>();
      final sub = container.listen(evidenceProvider(q), (_, v) {
        final items = v.value;
        if (items != null && items.length == count && items.every((e) => e.payloads.length == 2) && !c.isCompleted) {
          c.complete(items);
        }
      }, fireImmediately: true);
      return c.future.timeout(const Duration(seconds: 10)).whenComplete(sub.close);
    }

    test('a note body and its same-instant annotation: body is always noteText, 30 times over', () async {
      const n = 30;
      // Every note and every annotation share one instant, so payload ids share a millisecond
      // prefix and only their random suffix would decide an id ordering (fails ~1 - 2^-30).
      final at = DateTime.utc(2026, 3, 4, 12);
      final bodyOf = <String, int>{};
      for (var i = 0; i < n; i++) {
        final id = await h.runtime(addNoteCmd(text: 'body $i', at: at));
        await h.runtime(addNoteCmd(text: 'annotation $i', at: at, attachTo: id));
        bodyOf[id] = i;
      }

      for (final q in <EvidenceQuery>[
        (day: '2026-03-04', sourceId: null, projectId: null, limit: 1000), // Today
        (day: null, sourceId: null, projectId: null, limit: 1000), // timeline
      ]) {
        final items = await load(q, n);
        expect({for (final e in items) e.e.id}, bodyOf.keys.toSet(), reason: 'day=${q.day}');
        for (final e in items) {
          final i = bodyOf[e.e.id]!;
          expect(e.isNoteOnly, isTrue);
          expect(e.noteText, 'body $i', reason: 'day=${q.day}: the body is the first-inserted payload');
          expect([for (final a in e.annotations) payloadText(a)], ['annotation $i'],
              reason: 'day=${q.day}: only the annotation is listed as one');
        }
      }
    });
  });

  // -------------------------------------------------------------------------
  // (2) Today's day keys vs the note composer.
  // -------------------------------------------------------------------------
  group('Today keys', () {
    String dayOfFocus(ProviderContainer c) => c.read(todayFocusProvider).day;

    testWidgets('with the composer focused, ←/→ move the caret, [ ] are left to the field, day stays', (tester) async {
      final (c, h) = await bootPage(tester, dir, const TodayPage());
      final start = dayOfFocus(c);
      await tester.tap(_composerField());
      await tester.pump();
      await tester.enterText(_composerField(), 'abc');
      await tester.pump();
      TextEditingController ctl() => tester.widget<TextField>(_composerField()).controller!;
      expect(ctl().selection, const TextSelection.collapsed(offset: 3));

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(ctl().selection, const TextSelection.collapsed(offset: 2), reason: '← moves the caret');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(ctl().selection, const TextSelection.collapsed(offset: 1));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(ctl().selection, const TextSelection.collapsed(offset: 2), reason: '→ moves the caret');
      expect(dayOfFocus(c), start, reason: 'arrows in the composer do not switch days');

      // Widget tests can't turn key events into typed text; what matters is that the page
      // doesn't swallow the key (a handled key event never reaches the text input).
      expect(await tester.sendKeyEvent(LogicalKeyboardKey.bracketLeft), isFalse, reason: '[ goes to the field');
      expect(await tester.sendKeyEvent(LogicalKeyboardKey.bracketRight), isFalse, reason: '] goes to the field');
      await tester.pump();
      expect(dayOfFocus(c), start, reason: 'brackets in the composer do not switch days');
      await tester.enterText(_composerField(), 'a[b]c');
      await tester.pump();
      expect(ctl().text, 'a[b]c');
      expect(dayOfFocus(c), start);
      await killEngine(tester, h);
    });

    testWidgets('with nothing editable focused, ←/→ and [ ] switch days', (tester) async {
      final (c, h) = await bootPage(tester, dir, const TodayPage());
      final start = dayOfFocus(c);
      expect(FocusManager.instance.primaryFocus?.context?.findAncestorStateOfType<EditableTextState>(), isNull,
          reason: 'precondition: the page, not a text field, has focus');

      expect(await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft), isTrue);
      await tester.pump();
      expect(dayOfFocus(c), shiftDayBy(start, -1));
      expect(await tester.sendKeyEvent(LogicalKeyboardKey.bracketLeft), isTrue);
      await tester.pump();
      expect(dayOfFocus(c), shiftDayBy(start, -2));
      expect(await tester.sendKeyEvent(LogicalKeyboardKey.bracketRight), isTrue);
      await tester.pump();
      expect(dayOfFocus(c), shiftDayBy(start, -1));
      expect(await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight), isTrue);
      await tester.pump();
      expect(dayOfFocus(c), start);
      await settle(tester);
      expect(find.text(longDayLabel(start)), findsOneWidget, reason: 'the header shows the selected day');
      await killEngine(tester, h);
    });

    testWidgets('⌘Enter in the composer saves the note', (tester) async {
      final (_, h) = await bootPage(tester, dir, const TodayPage());
      await tester.tap(_composerField());
      await tester.pump();
      await tester.enterText(_composerField(), 'Fixed [the] flaky test');
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await settle(tester,
          until: () =>
              tester.widget<TextField>(_composerField()).controller!.text.isEmpty &&
              find.text('Fixed [the] flaky test').evaluate().isNotEmpty);
      final ev = await read(tester, () => h.db.select(h.db.evidences).get());
      expect([for (final e in ev) e.title], ['Fixed [the] flaky test']);
      expect(ev.single.day, todayDay(), reason: 'saved on today');
      expect(tester.widget<TextField>(_composerField()).controller!.text, isEmpty, reason: 'cleared after save');
      await killEngine(tester, h);
    });

    testWidgets('Esc in the composer collapses and unfocuses it', (tester) async {
      final (c, h) = await bootPage(tester, dir, const TodayPage());
      final start = dayOfFocus(c);
      await tester.tap(_composerField());
      await tester.pump();
      await tester.pump();
      expect(find.byWidgetPredicate((w) => w is AntTextField && w.placeholder == 'Link (optional)'), findsOneWidget,
          reason: 'focusing expands the composer');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.pump();
      expect(find.byWidgetPredicate((w) => w is AntTextField && w.placeholder == 'Link (optional)'), findsNothing,
          reason: 'Esc collapses it');
      expect(FocusManager.instance.primaryFocus?.context?.findAncestorStateOfType<EditableTextState>(), isNull,
          reason: 'Esc unfocuses the field');
      expect(dayOfFocus(c), start);
      await killEngine(tester, h);
    });

    // BUG: Esc calls `_focus.unfocus()`, which hands focus to the route's scope, outside
    // _DayKeys. Nothing editable is focused, yet ←/→ and [ ] no longer switch days until the
    // page is clicked (the arrow goes to directional focus traversal instead).
    testWidgets('after Esc leaves the composer, the day keys work again', (tester) async {
      final (c, h) = await bootPage(tester, dir, const TodayPage());
      final start = dayOfFocus(c);
      await tester.tap(_composerField());
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.context?.findAncestorStateOfType<EditableTextState>(), isNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.bracketLeft);
      await tester.pump();
      expect(dayOfFocus(c), shiftDayBy(start, -1), reason: '[ switches days once nothing editable has focus');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(dayOfFocus(c), start, reason: '→ switches days once nothing editable has focus');
      await killEngine(tester, h);
    }, skip: bugSkip);
  });

  // -------------------------------------------------------------------------
  // (3) Midnight rollover.
  // -------------------------------------------------------------------------
  group('day rollover', () {
    // testWidgets runs in fake time, so todayProvider's periodic timer only fires on pump.
    ProviderContainer bare() => ProviderContainer(overrides: [
          engineConfigProvider.overrideWithValue(testConfig(dir.path)),
        ]);

    testWidgets('crossing midnight while on today moves Today and the selected day forward', (tester) async {
      final clock = _WallClock(DateTime.utc(2026, 3, 4, 23, 58, 30));
      final c = bare();
      addTearDown(c.dispose);
      expect(c.read(todayProvider), '2026-03-04');
      expect(c.read(todayFocusProvider).day, '2026-03-04');
      final seen = <String>[];
      final sub = c.listen(todayProvider, (_, d) => seen.add(d));

      await clock.advance(tester, const Duration(minutes: 1)); // 23:59:30
      expect(c.read(todayProvider), '2026-03-04');
      await clock.advance(tester, const Duration(minutes: 1)); // 00:00:30, next tick sees it
      await clock.advance(tester, const Duration(minutes: 1));
      expect(c.read(todayProvider), '2026-03-05');
      expect(c.read(todayFocusProvider).day, '2026-03-05', reason: 'showing today follows the rollover');
      expect(seen, ['2026-03-05'], reason: 'one emission for one midnight');
      sub.close();
    });

    testWidgets('a past day you selected stays put across midnight', (tester) async {
      final clock = _WallClock(DateTime.utc(2026, 3, 4, 23, 59));
      final c = bare();
      addTearDown(c.dispose);
      c.read(todayFocusProvider.notifier).setDay('2026-03-01');
      await clock.advance(tester, const Duration(minutes: 3));
      expect(c.read(todayProvider), '2026-03-05', reason: 'precondition: the day rolled over');
      expect(c.read(todayFocusProvider).day, '2026-03-01');

      // Highlighted evidence on a past day also stays.
      c.read(todayFocusProvider.notifier).focus('2026-03-02', {'ev1'});
      await clock.advance(tester, const Duration(days: 1, minutes: 1), step: const Duration(minutes: 1));
      expect(c.read(todayProvider), '2026-03-06');
      expect(c.read(todayFocusProvider).day, '2026-03-02');
      expect(c.read(todayFocusProvider).highlight, {'ev1'});
    });

    testWidgets('nothing is emitted within the same day', (tester) async {
      final clock = _WallClock(DateTime.utc(2026, 3, 4, 9));
      final c = bare();
      addTearDown(c.dispose);
      final days = <String>[];
      final focus = <Object>[];
      final s1 = c.listen(todayProvider, (_, d) => days.add(d));
      final s2 = c.listen(todayFocusProvider, (_, f) => focus.add(f));
      expect(c.read(todayProvider), '2026-03-04');
      await clock.advance(tester, const Duration(hours: 14, minutes: 59), step: const Duration(minutes: 1)); // 23:59
      expect(c.read(todayProvider), '2026-03-04');
      expect(days, isEmpty);
      expect(focus, isEmpty);
      s1.close();
      s2.close();
    });

    testWidgets('in the app, the Today page and its sidebar badge follow midnight', (tester) async {
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
      // Harness profile zone is UTC: one item on Mar 4, two on Mar 5.
      await cmd(tester, h, addNoteCmd(text: 'March 4 note', at: DateTime.utc(2026, 3, 4, 12)));
      await cmd(tester, h, addNoteCmd(text: 'March 5 note A', at: DateTime.utc(2026, 3, 5, 12)));
      await cmd(tester, h, addNoteCmd(text: 'March 5 note B', at: DateTime.utc(2026, 3, 5, 13)));
      await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const AntApp()));
      await settle(tester);
      expect(find.byType(TodayPage), findsOneWidget);
      // The engine set the zone on start; now fake the wall clock just before Mar 4 midnight.
      final clock = _WallClock(DateTime.utc(2026, 3, 4, 23, 57));

      Finder badge(String n) => find.descendant(
            of: find.byWidgetPredicate((w) => w is AntSidebarItem && w.label == ShellSection.today.label),
            matching: find.text(n),
          );

      await clock.advance(tester, const Duration(minutes: 1)); // first tick: real today -> Mar 4
      await settle(tester,
          until: () => badge('1').evaluate().isNotEmpty && find.text('March 4 note').evaluate().isNotEmpty);
      expect(c.read(todayFocusProvider).day, '2026-03-04');
      expect(badge('1'), findsOneWidget);
      expect(find.text(longDayLabel('2026-03-04')), findsOneWidget);
      expect(find.text('March 4 note'), findsWidgets);

      await clock.advance(tester, const Duration(minutes: 3)); // past midnight
      await settle(tester,
          until: () => badge('2').evaluate().isNotEmpty && find.text('March 5 note A').evaluate().isNotEmpty);
      expect(c.read(todayProvider), '2026-03-05');
      expect(c.read(todayFocusProvider).day, '2026-03-05');
      expect(badge('2'), findsOneWidget, reason: 'the badge counts the new today');
      expect(badge('1'), findsNothing);
      expect(find.text(longDayLabel('2026-03-05')), findsOneWidget);
      expect(find.text('March 5 note A'), findsWidgets);
      expect(find.text('March 4 note'), findsNothing);
      await killEngine(tester, h);
    });
  });

  // -------------------------------------------------------------------------
  // (4) Plain-HTTP warning.
  // -------------------------------------------------------------------------
  group('provider dialog plain-HTTP warning', () {
    testWidgets('shown for http/HTTP to a remote host, not for https or loopback', (tester) async {
      final (_, h) = await bootPage(
        tester,
        dir,
        Builder(
          builder: (context) => Center(
            child: AntButton(label: 'Open', onPressed: () => showProviderDialog(context, preset: ProviderPreset.custom)),
          ),
        ),
      );
      await tester.tap(_button('Open'));
      await settle(tester, until: () => _field('Base URL').evaluate().isNotEmpty);

      const cases = {
        'http://192.168.1.20:11434': true,
        'HTTP://192.168.1.20:11434': true,
        'Http://gpu-box.local:1234/v1': true,
        'HTTP://api.example.com/v1': true,
        'https://192.168.1.20:11434': false,
        'HTTPS://api.example.com/v1': false,
        'http://localhost:11434': false,
        'HTTP://LOCALHOST:11434': false,
        'http://127.0.0.1:1234/v1': false,
        'http://127.0.0.2:1234/v1': false,
        'http://[::1]:11434': false,
      };
      for (final MapEntry(key: url, value: warns) in cases.entries) {
        await tester.enterText(_field('Base URL'), url);
        await tester.pump();
        expect(find.text(_plainHttpWarning), warns ? findsOneWidget : findsNothing, reason: url);
      }
      await killEngine(tester, h);
    });
  });
}
