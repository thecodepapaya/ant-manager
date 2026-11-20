import 'dart:io';
import 'dart:isolate';

import 'package:ant_manager/app.dart';
import 'package:ant_manager/engine/commands.dart';
import 'package:ant_manager/engine/engine_handle.dart';
import 'package:ant_manager/engine/setup_commands.dart';
import 'package:ant_manager/features/onboarding/onboarding_page.dart';
import 'package:ant_manager/features/projects/projects_page.dart';
import 'package:ant_manager/features/reports/reports_page.dart';
import 'package:ant_manager/features/settings/setup_providers.dart';
import 'package:ant_manager/features/timeline/timeline_page.dart';
import 'package:ant_manager/features/today/today_page.dart';
import 'package:ant_manager/shell/shell_state.dart';
import 'package:ant_manager/state/providers.dart';
import 'package:ant_manager/widgets/note_composer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui/ui.dart';

import 'support/fakes.dart';

/// Shell-level: the sidebar (packages/ui AntSidebarItem), section routing to the feature pages,
/// the profile switcher and provider values.
void main() {
  late Directory dir;
  setUp(() => dir = tempDir());
  tearDown(() => dir.deleteSync(recursive: true));

  Future<(ProviderContainer, EngineHandle)> boot(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // Start the engine on the real event loop (not the test's fake-async zone).
    final container = ProviderContainer(overrides: [engineConfigProvider.overrideWithValue(testConfig(dir.path))]);
    addTearDown(container.dispose);
    final h = (await tester.runAsync(() => container.read(engineProvider.future)))!;
    // Skip the first-run onboarding gate (a fresh profile has no identities or sources).
    await tester.runAsync(() => h.runtime(setSettingCmd(onboardingDoneSettingKey, 'true')));
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const AntApp()));
    await settle(tester);
    return (container, h);
  }

  /// The handle's clean shutdown is covered by the unit tests; under the widget binding its
  /// UI-side drift clients (whose queries ran in the fake-async zone) never finish closing,
  /// so here the engine isolate is killed instead.
  Future<void> teardown(WidgetTester tester, EngineHandle h) async {
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
    await tester.runAsync(() async {
      final iso = await h.runtime(currentIsolateCmd());
      final exited = ReceivePort();
      iso.addOnExitListener(exited.sendPort);
      iso.kill(priority: Isolate.immediate);
      await exited.first.timeout(const Duration(seconds: 5));
      exited.close();
    });
  }

  Finder sidebarItem(ShellSection s) =>
      find.byWidgetPredicate((w) => w is AntSidebarItem && w.label == s.label, description: 'sidebar ${s.label}');
  bool selected(WidgetTester tester, ShellSection s) => tester.widget<AntSidebarItem>(sidebarItem(s)).selected;

  testWidgets('shows every section in the sidebar and the active profile', (tester) async {
    final (_, h) = await boot(tester);
    final active = find.byKey(const ValueKey('active-profile'));
    await settle(tester, until: () => tester.widget<Text>(active).data == 'Work');
    for (final s in ShellSection.values) {
      expect(sidebarItem(s), findsOneWidget, reason: s.label);
      expect(tester.widget<AntSidebarItem>(sidebarItem(s)).icon, s.icon, reason: s.label);
    }
    expect(selected(tester, ShellSection.today), isTrue);
    expect(find.byType(TodayPage), findsOneWidget);
    expect(find.byType(OnboardingPage), findsNothing);
    expect(tester.widget<Text>(active).data, 'Work');
    await teardown(tester, h);
  });

  testWidgets('tapping a section switches to it and shows its page', (tester) async {
    final (container, h) = await boot(tester);
    final pages = {
      ShellSection.timeline: TimelinePage,
      ShellSection.reports: ReportsPage,
      ShellSection.projects: ProjectsPage,
      ShellSection.today: TodayPage,
    };
    for (final MapEntry(key: s, value: page) in pages.entries) {
      await tester.tap(sidebarItem(s));
      await settle(tester);
      expect(container.read(shellSectionProvider), s);
      expect(selected(tester, s), isTrue);
      expect(find.byType(page), findsOneWidget, reason: s.label);
      for (final other in ShellSection.values.where((o) => o != s)) {
        expect(selected(tester, other), isFalse);
      }
    }
    await teardown(tester, h);
  });

  testWidgets('evidence count updates after a note is added', (tester) async {
    final (container, h) = await boot(tester);
    final evidence = container.listen(countProvider(Counter.evidence), (_, _) {});
    addTearDown(evidence.close);
    await settle(tester, until: () => evidence.read().value == 0);
    expect(evidence.read().value, 0);
    await tester.runAsync(() => h.runtime(addQuickNoteCmd(text: 'hello')));
    await settle(tester, until: () => evidence.read().value == 1);
    expect(evidence.read().value, 1);
    await teardown(tester, h);
  });

  // Replaces the old placeholder "Add note" dialog test (that page is gone): Today's inline
  // NoteComposer owns its controllers for its whole lifetime.
  testWidgets('Today note composer saves a note, updates the count and clears the field', (tester) async {
    final (container, h) = await boot(tester);
    final evidence = container.listen(countProvider(Counter.evidence), (_, _) {});
    addTearDown(evidence.close);
    await settle(tester, until: () => evidence.read().value == 0);
    final field = find.descendant(of: find.byType(NoteComposer), matching: find.byType(TextField)).first;
    await tester.enterText(field, 'hello');
    await tester.tap(find.descendant(of: find.byType(NoteComposer), matching: find.text('Add note')));
    await settle(tester, until: () => evidence.read().value == 1);
    expect(evidence.read().value, 1);
    await settle(tester, until: () => tester.widget<TextField>(field).controller!.text.isEmpty);
    expect(tester.widget<TextField>(field).controller!.text, isEmpty);
    expect(tester.takeException(), isNull);
    await teardown(tester, h);
  });

  testWidgets('New profile dialog opens from the profile switcher and can be cancelled', (tester) async {
    final (_, h) = await boot(tester);
    await settle(tester, until: () => tester.widget<Text>(find.byKey(const ValueKey('active-profile'))).data == 'Work');
    await tester.tap(find.byKey(const ValueKey('active-profile')));
    await settle(tester, until: () => find.text('New profile…').evaluate().isNotEmpty);
    await tester.tap(find.text('New profile…'));
    await settle(tester, until: () => find.byType(AntDialog).evaluate().isNotEmpty);
    expect(find.descendant(of: find.byType(AntDialog), matching: find.text('New profile')), findsOneWidget);
    await tester.enterText(find.descendant(of: find.byType(AntDialog), matching: find.byType(TextField)), 'Side');
    await tester.tap(find.descendant(of: find.byType(AntDialog), matching: find.text('Cancel')));
    await settle(tester);
    expect(find.byType(AntDialog), findsNothing);
    expect(tester.takeException(), isNull);
    final profiles = await tester.runAsync(() => h.appDb.select(h.appDb.profiles).get());
    expect(profiles!.map((p) => p.name), ['Work']);
    await teardown(tester, h);
  });
}

/// Pumps with real time passing (engine isolate + drift streams need the real event loop).
Future<void> settle(WidgetTester tester, {bool Function()? until}) async {
  for (var i = 0; i < 100; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump(const Duration(milliseconds: 30));
    if (until == null ? i >= 5 : until()) return;
  }
}
