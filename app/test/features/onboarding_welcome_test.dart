/// Onboarding Welcome step (#114) and the last step's copy (#113), against a real engine.
library;

import 'dart:io';

import 'package:ant_manager/app.dart';
import 'package:ant_manager/engine/commands.dart';
import 'package:ant_manager/engine/engine_handle.dart';
import 'package:ant_manager/features/onboarding/onboarding_page.dart';
import 'package:ant_manager/features/settings/setup_providers.dart';
import 'package:ant_manager/features/today/today_page.dart';
import 'package:core/core.dart' hide Provider;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui/ui.dart';

import 'support.dart';

Finder _button(String label) => find.byWidgetPredicate((w) => w is AntButton && w.label == label);

Finder _field(String label) => find.descendant(
      of: find.byWidgetPredicate((w) => w is AntTextField && w.label == label),
      matching: find.byType(TextField),
    );

/// Rail entries, in order (AntInteractive carries the step label).
List<String> _railLabels(WidgetTester tester) => [
      for (final w in tester.widgetList<AntInteractive>(find.byType(AntInteractive)))
        if (w.semanticLabel != null &&
            const ['Welcome', 'Profile', 'Identities', 'Repositories', 'Sources', 'AI model', 'First import']
                .contains(w.semanticLabel))
          w.semanticLabel!,
    ];

AntInteractive _railItem(WidgetTester tester, String label) =>
    tester.widget<AntInteractive>(find.byWidgetPredicate((w) => w is AntInteractive && w.semanticLabel == label));

const _welcomeTitle = 'Your work, quietly remembered.';
const _profileTitle = 'Name your profile';
const _lastTitle = 'You’re set.';
const _noConnector = 'Start with a note about today. Sources can be connected any time.';
const _importing = 'Importing the last 30 days so your timeline isn’t empty.';

void main() {
  late Directory dir;
  setUp(() => dir = tempDir());
  tearDown(() => dir.deleteSync(recursive: true));

  Future<EngineHandle> boot(WidgetTester tester) async {
    final (_, h) = await bootPage(tester, dir, const OnboardingPage(), size: const Size(1400, 1000));
    await settle(tester, until: () => find.text(_welcomeTitle).evaluate().isNotEmpty);
    return h;
  }

  /// Welcome → Profile → (skip) identities, repos, sources, model → First import.
  Future<void> toLastStep(WidgetTester tester) async {
    await tester.tap(_button('Get started'));
    await settle(tester, until: () => find.text(_profileTitle).evaluate().isNotEmpty);
    await tester.tap(_button('Continue'));
    for (var i = 0; i < 4; i++) {
      await settle(tester, until: () => _button('Skip').evaluate().isNotEmpty);
      final before = _railItem(tester, 'First import').onTap;
      expect(before, isNull, reason: 'First import is not reachable yet');
      await tester.tap(_button('Skip'));
      await settle(tester, until: () => _button('Saving…').evaluate().isEmpty);
    }
    await settle(tester, until: () => find.text(_lastTitle).evaluate().isNotEmpty);
    expect(find.text(_lastTitle), findsOneWidget);
    expect(_railItem(tester, 'First import').onTap, isNotNull, reason: 'reached, so pickable');
  }

  group('Welcome step', () {
    testWidgets('opens first: heading, the four stages and one principles line', (tester) async {
      final h = await boot(tester);
      expect(_railLabels(tester), ['Welcome', 'Profile', 'Identities', 'Repositories', 'Sources', 'AI model', 'First import']);
      expect(_railItem(tester, 'Welcome').selected, isTrue);
      expect(_railItem(tester, 'Profile').selected, isFalse);
      expect(find.text(_welcomeTitle), findsOneWidget);
      expect(find.text(_profileTitle), findsNothing);
      for (final s in const ['Sources', 'Evidence', 'Narrative', 'Reports and wins']) {
        expect(find.text(s), findsWidgets, reason: s);
      }
      expect(find.textContaining('Every line cites the work behind it.'), findsOneWidget);
      await killEngine(tester, h);
    });

    testWidgets('no Back and no Skip; the primary is "Get started"', (tester) async {
      final h = await boot(tester);
      expect(_button('Back'), findsNothing);
      expect(_button('Skip'), findsNothing);
      expect(_button('Get started'), findsOneWidget);
      expect(_button('Continue'), findsNothing);
      await killEngine(tester, h);
    });

    testWidgets('Get started → Profile ("Continue", Back) → Back returns to Welcome', (tester) async {
      final h = await boot(tester);
      await tester.tap(_button('Get started'));
      await settle(tester, until: () => find.text(_profileTitle).evaluate().isNotEmpty);
      expect(find.text(_welcomeTitle), findsNothing);
      expect(_railItem(tester, 'Profile').selected, isTrue);
      expect(_button('Continue'), findsOneWidget);
      expect(_button('Get started'), findsNothing);
      expect(_button('Back'), findsOneWidget);
      expect(_button('Skip'), findsNothing, reason: 'the profile step is not skippable');
      expect(_field('Profile name'), findsOneWidget);

      await tester.tap(_button('Back'));
      await settle(tester, until: () => find.text(_welcomeTitle).evaluate().isNotEmpty);
      expect(find.text(_profileTitle), findsNothing);
      expect(_railItem(tester, 'Welcome').selected, isTrue);
      expect(_button('Get started'), findsOneWidget);
      expect(_button('Back'), findsNothing);
      // Profile was reached, so the rail can jump back to it.
      expect(_railItem(tester, 'Profile').onTap, isNotNull);
      await killEngine(tester, h);
    });

    testWidgets('only Continue on Profile saves the name: Back then "Get started" does not', (tester) async {
      final (_, h) = await bootPage(tester, dir, const AntApp());
      await settle(tester, until: () => find.text(_welcomeTitle).evaluate().isNotEmpty);
      final before = (await read(tester, () => h.appDb.select(h.appDb.profiles).get())).single.name;
      await tester.tap(_button('Get started'));
      await settle(tester, until: () => _field('Profile name').evaluate().isNotEmpty);
      await tester.enterText(_field('Profile name'), 'Typed but not continued');
      await tester.tap(_button('Back'));
      await settle(tester, until: () => find.text(_welcomeTitle).evaluate().isNotEmpty);
      await tester.tap(_button('Get started'));
      await settle(tester, until: () => find.text(_profileTitle).evaluate().isNotEmpty);
      expect((await read(tester, () => h.appDb.select(h.appDb.profiles).get())).single.name, before);
      expect(tester.widget<TextField>(_field('Profile name')).controller!.text, 'Typed but not continued',
          reason: 'the typed name survives going back');
      await killEngine(tester, h);
    });

    testWidgets('Skip setup from Welcome finishes onboarding and opens Today', (tester) async {
      final (_, h) = await bootPage(tester, dir, const AntApp());
      await settle(tester, until: () => find.text(_welcomeTitle).evaluate().isNotEmpty);
      expect(find.text(_welcomeTitle), findsOneWidget, reason: 'the app opens onboarding on Welcome');
      expect(await read(tester, () => settingOf(h, onboardingDoneSettingKey)), isNull);
      await tester.tap(_button('Skip setup'));
      await settle(tester, until: () => find.byType(TodayPage).evaluate().isNotEmpty);
      expect(find.byType(OnboardingPage), findsNothing);
      expect(find.byType(TodayPage), findsOneWidget);
      expect(await read(tester, () => settingOf(h, onboardingDoneSettingKey)), 'true');
      await killEngine(tester, h);
    });

    testWidgets('disposing onboarding on Welcome (Profile never visited) does not throw', (tester) async {
      final h = await boot(tester);
      expect(find.text(_profileTitle), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await settle(tester);
      expect(tester.takeException(), isNull);
      await killEngine(tester, h);
    });
  });

  // Booted through AntApp: that is how onboarding is reached in the app (nothing else on screen).
  testWidgets('renaming the profile on the Profile step saves it', (tester) async {
    final (_, h) = await bootPage(tester, dir, const AntApp());
    await settle(tester, until: () => find.text(_welcomeTitle).evaluate().isNotEmpty);
    await tester.tap(_button('Get started'));
    await settle(tester, until: () => _field('Profile name').evaluate().isNotEmpty);
    final p = (await read(tester, () => h.appDb.select(h.appDb.profiles).get())).single;
    expect(tester.widget<TextField>(_field('Profile name')).controller!.text, p.name,
        reason: 'prefilled with the current name');
    await tester.enterText(_field('Profile name'), '  Side projects  ');
    await tester.tap(_button('Continue'));
    await settle(tester, until: () => find.text('Which of these are you?').evaluate().isNotEmpty);
    final after = (await read(tester, () => h.appDb.select(h.appDb.profiles).get())).single;
    expect(after.id, p.id);
    expect(after.name, 'Side projects', reason: 'trimmed');
    await killEngine(tester, h);
  });

  testWidgets('a blank profile name is not saved', (tester) async {
    final (_, h) = await bootPage(tester, dir, const AntApp());
    await settle(tester, until: () => find.text(_welcomeTitle).evaluate().isNotEmpty);
    final before = (await read(tester, () => h.appDb.select(h.appDb.profiles).get())).single.name;
    await tester.tap(_button('Get started'));
    await settle(tester, until: () => _field('Profile name').evaluate().isNotEmpty);
    await tester.enterText(_field('Profile name'), '   ');
    await tester.tap(_button('Continue'));
    await settle(tester, until: () => find.text('Which of these are you?').evaluate().isNotEmpty);
    expect((await read(tester, () => h.appDb.select(h.appDb.profiles).get())).single.name, before);
    await killEngine(tester, h);
  });

  group('last step copy', () {
    testWidgets('no connector source: "Start with a note about today…"', (tester) async {
      final h = await boot(tester);
      await toLastStep(tester);
      expect(find.text(_noConnector), findsOneWidget);
      expect(find.text(_importing), findsNothing);
      expect(_button('Open Today'), findsOneWidget);
      expect(_button('Skip'), findsNothing);
      // Open Today finishes onboarding.
      await tester.tap(_button('Open Today'));
      await settle(tester, until: () => false, max: 10);
      expect(await read(tester, () => settingOf(h, onboardingDoneSettingKey)), 'true');
      await killEngine(tester, h);
    });

    testWidgets('a disabled connector does not count', (tester) async {
      final h = await boot(tester);
      final id = await cmd(tester, h, addSourceCmd(SourceKind.gitRepo, 'r', {'path': '${dir.path}/nope'}));
      await cmd(tester, h, updateSourceCmd(id, enabled: false));
      await toLastStep(tester);
      expect(find.text(_noConnector), findsOneWidget);
      expect(find.text(_importing), findsNothing);
      await killEngine(tester, h);
    });

    testWidgets('an enabled connector source: "Importing the last 30 days…"', (tester) async {
      final h = await boot(tester);
      await cmd(tester, h, addSourceCmd(SourceKind.gitRepo, 'r', {'path': '${dir.path}/nope'}));
      await toLastStep(tester);
      await settle(tester, until: () => find.text(_importing).evaluate().isNotEmpty);
      expect(find.text(_importing), findsOneWidget);
      expect(find.text(_noConnector), findsNothing);
      await killEngine(tester, h);
    });
  });
}
