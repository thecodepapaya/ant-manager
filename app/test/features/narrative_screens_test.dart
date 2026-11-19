/// Focused widget tests for the narrative-side screens (Today, Wins, Reports, Projects, Timeline).
library;

import 'dart:convert';
import 'dart:io';

import 'package:ant_manager/engine/commands.dart';
import 'package:ant_manager/engine/engine_handle.dart';
import 'package:ant_manager/engine/messages.dart';
import 'package:ant_manager/features/projects/projects_page.dart';
import 'package:ant_manager/features/reports/reports_page.dart';
import 'package:ant_manager/features/timeline/timeline_page.dart';
import 'package:ant_manager/features/today/today_page.dart';
import 'package:ant_manager/features/wins/wins_page.dart';
import 'package:ant_manager/widgets/common.dart';
import 'package:ant_manager/widgets/evidence_row.dart';
import 'package:ant_manager/widgets/note_composer.dart';
import 'package:core/core.dart' hide Provider;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui/ui.dart';

import 'support.dart';

EngineCommand<void> _setStarredCmd(String id) => (rt) => rt.engine.setStarred(id, true);

void main() {
  late Directory dir;
  setUp(() => dir = tempDir());
  tearDown(() => dir.deleteSync(recursive: true));

  Finder composerField() => find.descendant(of: find.byType(NoteComposer), matching: find.byType(TextField)).first;
  Finder rows() => find.byType(EvidenceRow);

  group('Today', () {
    testWidgets('a note added on a past day lands on that day at local noon', (tester) async {
      final (c, h) = await bootPage(tester, dir, const TodayPage());
      c.read(todayFocusProvider.notifier).setDay('2026-03-04');
      await settle(tester);
      await tester.enterText(composerField(), 'Worked offline on the RFC');
      await tester.tap(find.descendant(of: find.byType(NoteComposer), matching: find.text('Add note')));
      await settle(tester, until: () => rows().evaluate().isNotEmpty);
      final e = (await read(tester, () => h.db.select(h.db.evidences).get())).single;
      expect(e.day, '2026-03-04');
      expect(e.occurredStart.toLocal(), DateTime(2026, 3, 4, 12));
      expect(rows(), findsOneWidget);
      await killEngine(tester, h);
    });

    testWidgets('a pasted screenshot (⌘V) is saved as an attachment', (tester) async {
      // A valid 1×1 PNG (the composer previews it with Image.memory).
      final png = base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('ant/clipboard'),
          (call) async => call.method == 'readImage' ? png : null);
      addTearDown(() =>
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('ant/clipboard'), null));
      final (_, h) = await bootPage(tester, dir, const TodayPage());
      await tester.tap(composerField());
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await settle(tester, until: () => find.text('1 screenshot').evaluate().isNotEmpty);
      expect(find.text('1 screenshot'), findsOneWidget, reason: 'macOS-only paste path');
      await tester.tap(find.descendant(of: find.byType(NoteComposer), matching: find.text('Add note')));
      await settle(tester, until: () => rows().evaluate().isNotEmpty);
      final att = (await read(tester, () => h.db.select(h.db.attachments).get())).single;
      expect(att.mime, 'image/png');
      expect(att.size, png.length);
      final e = (await read(tester, () => h.db.select(h.db.evidences).get())).single;
      expect(e.title, 'Screenshot', reason: 'an image-only note is titled "Screenshot"');
      await killEngine(tester, h);
    }, skip: !Platform.isMacOS);

    testWidgets('hidden items are filtered out unless "Show hidden" is on', (tester) async {
      final (_, h) = await bootPage(tester, dir, const TodayPage());
      await cmd(tester, h, addNoteCmd(text: 'Visible note', at: DateTime.now()));
      final hidden = await cmd(tester, h, addNoteCmd(text: 'Hidden note', at: DateTime.now()));
      await cmd(tester, h, setHiddenCmd(hidden, true));
      await settle(tester, until: () => find.text('Show hidden').evaluate().isNotEmpty);
      expect(rows(), findsOneWidget);
      expect(find.text('Visible note'), findsOneWidget);
      expect(find.text('Hidden note'), findsNothing);
      await tester.tap(find.text('Show hidden'));
      await settle(tester);
      expect(rows(), findsNWidgets(2));
      expect(find.text('Hidden note'), findsOneWidget);
      await tester.tap(find.text('Hide hidden'));
      await settle(tester);
      expect(rows(), findsOneWidget);
      // Unhide brings it back without the toggle, and the toggle goes away.
      await cmd(tester, h, setHiddenCmd(hidden, false));
      await settle(tester, until: () => rows().evaluate().length == 2);
      expect(find.text('Show hidden'), findsNothing);
      await killEngine(tester, h);
    });

    testWidgets('Delete permanently asks with the irreversible-action text, then deletes', (tester) async {
      final (_, h) = await bootPage(tester, dir, const TodayPage());
      await cmd(tester, h, addNoteCmd(text: 'Secret meeting', at: DateTime.now()));
      await settle(tester, until: () => rows().evaluate().isNotEmpty);
      await tester.tap(find.descendant(of: rows(), matching: find.byTooltip('More')));
      await settle(tester, until: () => find.text('Delete permanently…').evaluate().isNotEmpty);
      await tester.tap(find.text('Delete permanently…'));
      await settle(tester, until: () => find.byType(AntDialog).evaluate().isNotEmpty);
      expect(find.text('Delete permanently?'), findsOneWidget);
      expect(
        find.text('“Secret meeting” and everything captured with it (notes, screenshots, summaries) will be removed, '
            'and facts that only cite it are deleted too. This can’t be undone.\n\n'
            'Locked reports and existing backups may still contain it.'),
        findsOneWidget,
      );
      // Cancel keeps it.
      await tester.tap(find.descendant(of: find.byType(AntDialog), matching: find.text('Cancel')));
      await settle(tester);
      expect(await read(tester, () => h.db.select(h.db.evidences).get()), hasLength(1));
      await tester.tap(find.descendant(of: rows(), matching: find.byTooltip('More')));
      await settle(tester, until: () => find.text('Delete permanently…').evaluate().isNotEmpty);
      await tester.tap(find.text('Delete permanently…'));
      await settle(tester, until: () => find.byType(AntDialog).evaluate().isNotEmpty);
      await tester.tap(find.descendant(of: find.byType(AntDialog), matching: find.text('Delete permanently')));
      await settle(tester, until: () => rows().evaluate().isEmpty);
      expect(await read(tester, () => h.db.select(h.db.evidences).get()), isEmpty);
      await killEngine(tester, h);
    });
  });

  testWidgets('Wins lists starred evidence with no win under "Starred, not written up yet"', (tester) async {
    final (_, h) = await bootPage(tester, dir, const WinsPage());
    final id = await cmd(tester, h, addNoteCmd(text: 'Rescued the launch', at: DateTime.now()));
    await cmd(tester, h, _setStarredCmd(id));
    // SectionHeader renders its label upper-case.
    final header = find.text('STARRED, NOT WRITTEN UP YET');
    await settle(tester, until: () => header.evaluate().isNotEmpty);
    expect(header, findsOneWidget);
    expect(find.text('Rescued the launch'), findsOneWidget);
    expect(find.text('Write win'), findsOneWidget);
    // Once an accepted win cites it, it leaves the list.
    await cmd(tester, h, createFactCmd([id], statement: 'Rescued the launch', winStatus: WinStatus.accepted));
    await settle(tester, until: () => header.evaluate().isEmpty);
    expect(header, findsNothing);
    expect(find.text('Write win'), findsNothing);
    await killEngine(tester, h);
  });

  group('Reports', () {
    late FakeLlm llm;

    Future<(EngineHandle, String, String)> withReport(WidgetTester tester) async {
      llm = (await tester.runAsync(FakeLlm.start))!;
      addTearDown(() => tester.runAsync(llm.close));
      final (_, h) = await bootPage(tester, dir, const ReportsPage());
      await tester.runAsync(() => addFakeModel(h, llm));
      final today = todayDay();
      final ev = await cmd(tester, h, addNoteCmd(text: 'Shipped it', at: DateTime.now()));
      final fact = await cmd(tester, h, createFactCmd([ev], statement: 'Shipped it', day: today));
      final week = Period.containing(PeriodKind.weekly, today);
      final report = await cmd(
          tester, h, ensureReportCmd(PeriodKind.weekly, week.start, week.end, defaultTemplateFor[PeriodKind.weekly]!));
      await cmd(tester, h, generateReportCmd(report));
      return (h, report, fact);
    }

    Finder chip(String label) => find.byWidgetPredicate((w) => w is AntChip && w.label == label);

    testWidgets('status: Up to date → Out of date after a cited fact changes', (tester) async {
      final (h, _, fact) = await withReport(tester);
      await settle(tester, until: () => chip('Up to date').evaluate().isNotEmpty);
      expect(chip('Up to date'), findsOneWidget);
      await cmd(tester, h, editFactCmd(fact, 'Shipped it to everyone'));
      await settle(tester, until: () => chip('Out of date').evaluate().isNotEmpty);
      expect(chip('Out of date'), findsOneWidget);
      await killEngine(tester, h);
    });

    testWidgets('status: Locked → "Locked · facts changed since lock"; Regenerate disabled', (tester) async {
      final (h, report, fact) = await withReport(tester);
      await cmd(tester, h, lockReportCmd(report));
      await settle(tester, until: () => chip('Locked').evaluate().isNotEmpty);
      expect(chip('Locked'), findsOneWidget);
      final regen = find.byWidgetPredicate((w) => w is AntButton && w.label == 'Regenerate');
      expect(tester.widget<AntButton>(regen).onPressed, isNull);
      await cmd(tester, h, confirmFactCmd(fact));
      await settle(tester, until: () => chip('Locked · facts changed since lock').evaluate().isNotEmpty);
      expect(chip('Locked · facts changed since lock'), findsOneWidget);
      await killEngine(tester, h);
    });

    testWidgets('the version picker shows older snapshots', (tester) async {
      final (h, report, _) = await withReport(tester);
      await cmd(tester, h, generateReportCmd(report, styleInstruction: 'shorter'));
      await settle(tester, until: () => find.textContaining('Version 2 of 2').evaluate().isNotEmpty);
      expect(find.textContaining('style “shorter”'), findsOneWidget);
      await tester.tap(find.byWidgetPredicate((w) => w is AntSelect && w.semanticLabel == 'Version'));
      await settle(tester, until: () => find.text('Version 1').evaluate().isNotEmpty);
      expect(find.text('Version 2'), findsOneWidget);
      await tester.tap(find.text('Version 1'));
      await settle(tester, until: () => find.textContaining('Version 1 of 2').evaluate().isNotEmpty);
      expect(find.textContaining('Version 1 of 2'), findsOneWidget);
      expect(find.textContaining('style “shorter”'), findsNothing);
      await killEngine(tester, h);
    });
  });

  testWidgets('Projects: New project rotates through the palette', (tester) async {
    final (_, h) = await bootPage(tester, dir, const ProjectsPage());
    final palette = projectPalette(AntTokens.light()).map(hexOf).toList();
    for (final name in ['Alpha', 'Beta', 'Gamma']) {
      await tester.tap(find.widgetWithText(AntButton, 'New project').first);
      await settle(tester, until: () => find.byType(AntDialog).evaluate().isNotEmpty);
      await tester.enterText(find.descendant(of: find.byType(AntDialog), matching: find.byType(TextField)), name);
      await tester.tap(find.descendant(of: find.byType(AntDialog), matching: find.text('Create')));
      await settle(tester, until: () => find.text(name).evaluate().isNotEmpty && find.byType(AntDialog).evaluate().isEmpty);
      expect(tester.takeException(), isNull);
    }
    final colours = {for (final p in await read(tester, () => h.db.select(h.db.projects).get())) p.name: p.colour};
    expect(colours, {'Alpha': palette[0], 'Beta': palette[1], 'Gamma': palette[2]});
    await killEngine(tester, h);
  });

  testWidgets('Timeline: Load more pages by 100', (tester) async {
    // A very tall view so the whole (lazily built) list is laid out and absence checks mean something.
    final (_, h) = await bootPage(tester, dir, const TimelinePage(), size: const Size(1400, 40000));
    await tester.runAsync(() async {
      final base = DateTime.now().subtract(const Duration(days: 10));
      for (var i = 0; i < 205; i++) {
        await h.runtime(addNoteCmd(text: 'n$i', at: base.add(Duration(minutes: i))));
      }
    });
    final more = find.widgetWithText(AntButton, 'Load more');
    Future<void> tapMore() async {
      tester.widget<AntButton>(more).onPressed!();
      await settle(tester);
    }

    // Newest first: the first page is n204…n105.
    await settle(tester, until: () => find.text('n105').evaluate().isNotEmpty);
    expect(find.text('n204'), findsOneWidget);
    expect(find.text('n104'), findsNothing);
    expect(more, findsOneWidget);
    await tapMore(); // limit 200: n204…n5, still a full page
    await settle(tester, until: () => find.text('n5').evaluate().isNotEmpty);
    expect(find.text('n4'), findsNothing);
    expect(more, findsOneWidget);
    await tapMore(); // limit 300: all 205, no more pages
    await settle(tester, until: () => find.text('n0').evaluate().isNotEmpty);
    expect(find.text('n0'), findsOneWidget);
    expect(more, findsNothing);
    await killEngine(tester, h);
  });
}
