/// First-run states from the UI fidelity pass (#113): Today's single daily-report card, Narrative's
/// single explanation, and the restore preview with an incomplete backup manifest.
library;

import 'dart:convert';
import 'dart:io';

import 'package:ant_manager/engine/commands.dart';
import 'package:ant_manager/features/narrative/narrative_page.dart';
import 'package:ant_manager/features/settings/backup_tab.dart';
import 'package:ant_manager/features/today/today_page.dart';
import 'package:ant_manager/widgets/common.dart';
import 'package:ant_manager/widgets/report_view.dart' show RegenerateButton;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui/ui.dart';

import 'support.dart';

const _todayCard = 'Your daily report appears here';
const _narrativeEmpty = 'Your narrative starts here';

Finder _button(String label) => find.byWidgetPredicate((w) => w is AntButton && w.label == label);

/// Any Narrative filter control (period/project selects, type chips).
Finder _filters() => find.byWidgetPredicate(
    (w) => w is AntSelect<PeriodFilter> || w is AntSelect<String?> || (w is AntSelectChip && w.label == 'All types'));

void main() {
  late Directory dir;
  setUp(() => dir = tempDir());
  tearDown(() => dir.deleteSync(recursive: true));

  group('Today, first run', () {
    testWidgets('one "Your daily report appears here" card, no report controls or Facts section', (tester) async {
      final (_, h) = await bootPage(tester, dir, const TodayPage());
      await settle(tester, until: () => find.text(_todayCard).evaluate().isNotEmpty);
      expect(find.text(_todayCard), findsOneWidget);
      expect(find.text('No report for this day yet'), findsNothing);
      expect(find.byType(RegenerateButton), findsNothing);
      expect(find.text('FACTS'), findsNothing);
      expect(find.textContaining('No facts yet'), findsNothing);
      await killEngine(tester, h);
    });

    testWidgets('evidence alone keeps the card; a fact for the day replaces it with the report controls',
        (tester) async {
      final (_, h) = await bootPage(tester, dir, const TodayPage());
      final ev = await cmd(tester, h, addNoteCmd(text: 'Paired on the migration', at: DateTime.now()));
      await settle(tester, until: () => find.text('Paired on the migration').evaluate().isNotEmpty);
      expect(find.text(_todayCard), findsOneWidget, reason: 'nothing to write a report from yet');

      await cmd(tester, h, createFactCmd([ev], statement: 'Migrated the billing tables'));
      await settle(tester, until: () => find.text('Migrated the billing tables').evaluate().isNotEmpty);
      expect(find.text(_todayCard), findsNothing);
      expect(find.text('No report for this day yet'), findsOneWidget);
      expect(find.byType(RegenerateButton), findsOneWidget);
      expect(find.text('FACTS'), findsOneWidget, reason: 'the Facts section is back (same finder as the empty case)');
      await killEngine(tester, h);
    });
  });

  group('Narrative, first run', () {
    testWidgets('no facts: one explanation and no filters', (tester) async {
      final (_, h) = await bootPage(tester, dir, const NarrativePage());
      await settle(tester, until: () => find.text(_narrativeEmpty).evaluate().isNotEmpty);
      expect(find.text(_narrativeEmpty), findsOneWidget);
      expect(find.byType(AntEmptyState), findsOneWidget);
      expect(_filters(), findsNothing);
      await killEngine(tester, h);
    });

    testWidgets('once a fact exists the filters come back and the explanation goes', (tester) async {
      final (_, h) = await bootPage(tester, dir, const NarrativePage());
      await settle(tester, until: () => find.text(_narrativeEmpty).evaluate().isNotEmpty);
      final ev = await cmd(tester, h, addNoteCmd(text: 'n', at: DateTime.now()));
      await cmd(tester, h, createFactCmd([ev], statement: 'Shipped search'));
      await settle(tester, until: () => find.text(_narrativeEmpty).evaluate().isEmpty);
      expect(find.text(_narrativeEmpty), findsNothing);
      expect(_filters(), findsWidgets);
      await killEngine(tester, h);
    });
  });

  group('restore preview', () {
    const channel = MethodChannel('plugins.flutter.io/file_selector');

    /// A zip holding only manifest.json (what the preview reads).
    Future<String> bundle(WidgetTester tester, Map<String, Object?> manifest) async {
      final src = Directory('${dir.path}/bundle')..createSync();
      File('${src.path}/manifest.json').writeAsStringSync(jsonEncode(manifest));
      final out = '${dir.path}/b.antbackup';
      final r = (await tester.runAsync(() => Process.run('zip', ['-q', out, 'manifest.json'], workingDirectory: src.path)))!;
      expect(r.exitCode, 0, reason: '${r.stderr}');
      return out;
    }

    Future<void> openPreview(WidgetTester tester, String file) async {
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => call.method == 'openFile' ? [file] : null);
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
      await settle(tester, until: () => _button('Restore…').evaluate().isNotEmpty);
      await tester.tap(_button('Restore…'));
      await settle(tester, until: () => find.text('Restore this backup?').evaluate().isNotEmpty);
    }

    Map<String, Object?> manifest({String? firstDay, String? lastDay, Map<String, int> counts = const {}}) => {
          'format': 1,
          'app_version': '0.9.0',
          'schema_version': 1,
          'profile': 'Old work',
          'created_at': '2026-03-05T10:00:00Z',
          'first_day': firstDay,
          'last_day': lastDay,
          'counts': counts,
          'db_sha256': '',
        };

    testWidgets('first day without a last day and no counts: shows a one-day range and zeros', (tester) async {
      final (_, h) = await bootPage(tester, dir, const BackupTab(), size: const Size(1400, 1400));
      final file = await bundle(tester, manifest(firstDay: '2026-03-02'));
      await openPreview(tester, file);
      expect(tester.takeException(), isNull);
      expect(find.text('Old work'), findsOneWidget);
      expect(find.text('${shortDayLabel('2026-03-02')} – ${shortDayLabel('2026-03-02')}'), findsOneWidget);
      expect(find.text('0 evidence · 0 facts · 0 reports'), findsOneWidget);
      expect(find.text('0.9.0'), findsOneWidget);
      await tester.tap(_button('Cancel'));
      await settle(tester);
      await killEngine(tester, h);
    });

    testWidgets('no days at all: "No evidence"', (tester) async {
      final (_, h) = await bootPage(tester, dir, const BackupTab(), size: const Size(1400, 1400));
      await openPreview(tester, await bundle(tester, manifest()));
      expect(tester.takeException(), isNull);
      expect(find.text('No evidence'), findsOneWidget);
      await tester.tap(_button('Cancel'));
      await settle(tester);
      await killEngine(tester, h);
    });

    testWidgets('a complete manifest shows its range and counts', (tester) async {
      final (_, h) = await bootPage(tester, dir, const BackupTab(), size: const Size(1400, 1400));
      await openPreview(
        tester,
        await bundle(
            tester, manifest(firstDay: '2026-03-02', lastDay: '2026-03-04', counts: {'evidences': 5, 'facts': 2, 'reports': 1})),
      );
      expect(find.text('${shortDayLabel('2026-03-02')} – ${shortDayLabel('2026-03-04')}'), findsOneWidget);
      expect(find.text('5 evidence · 2 facts · 1 reports'), findsOneWidget);
      await tester.tap(_button('Cancel'));
      await settle(tester);
      await killEngine(tester, h);
    });
  });
}
