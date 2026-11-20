/// Focused widget tests for the setup screens: provider consent, the Vision route picker,
/// the weekends toggle, the source form, the git dialog's add step and the onboarding gate.
library;

import 'dart:convert';
import 'dart:io';

import 'package:ant_manager/app.dart';
import 'package:ant_manager/engine/commands.dart';
import 'package:ant_manager/engine/engine_handle.dart';
import 'package:ant_manager/engine/engine_runtime.dart' show nudgeJobKind;
import 'package:ant_manager/engine/setup_commands.dart';
import 'package:ant_manager/features/onboarding/onboarding_page.dart';
import 'package:ant_manager/features/settings/ai_models_tab.dart';
import 'package:ant_manager/features/settings/kit.dart';
import 'package:ant_manager/features/settings/provider_dialog.dart';
import 'package:ant_manager/features/settings/schedule_tab.dart';
import 'package:ant_manager/features/settings/setup_providers.dart';
import 'package:ant_manager/features/sources/git_setup.dart';
import 'package:ant_manager/features/sources/source_form.dart';
import 'package:ant_manager/features/today/today_page.dart';
import 'package:ant_manager/state/providers.dart';
import 'package:core/core.dart' hide Provider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui/ui.dart';

import 'support.dart';

/// A page with one button that runs [open] (dialogs need a context under the app).
Widget _opener(void Function(BuildContext context) open) =>
    Builder(builder: (context) => Center(child: AntButton(label: 'Open', onPressed: () => open(context))));

Finder _field(String label) => find.descendant(
      of: find.byWidgetPredicate((w) => w is AntTextField && w.label == label),
      matching: find.byType(TextField),
    );

Finder _button(String label) => find.byWidgetPredicate((w) => w is AntButton && w.label == label);

void main() {
  late Directory dir;
  late FakeLlm llm;
  setUp(() => dir = tempDir());
  tearDown(() => dir.deleteSync(recursive: true));

  Future<void> startLlm(WidgetTester tester) async {
    llm = (await tester.runAsync(FakeLlm.start))!;
    addTearDown(() => tester.runAsync(llm.close));
  }

  group('provider dialog consent', () {
    Future<EngineHandle> openCustom(WidgetTester tester, String url) async {
      final (_, h) = await bootPage(tester, dir, _opener((c) => showProviderDialog(c, preset: ProviderPreset.custom)));
      await tester.tap(_button('Open'));
      await settle(tester, until: () => _field('Base URL').evaluate().isNotEmpty);
      await tester.enterText(_field('Base URL'), url);
      await tester.tap(find.byWidgetPredicate((w) => w is SelectButton<ProviderProtocol>));
      await settle(tester, until: () => find.text('OpenAI-compatible').evaluate().isNotEmpty);
      await tester.tap(find.text('OpenAI-compatible'));
      await settle(tester);
      await tester.tap(_button('Test connection'));
      return h;
    }

    testWidgets('loopback never asks and lists models', (tester) async {
      await startLlm(tester);
      final h = await openCustom(tester, llm.baseUrl);
      await settle(tester, until: () => find.text('m-vision').evaluate().isNotEmpty);
      expect(find.textContaining('Send your evidence'), findsNothing);
      expect(find.text('m-text'), findsOneWidget);
      expect(llm.requests.map((r) => r.$1), ['/v1/models']);
      await killEngine(tester, h);
    });

    testWidgets('a non-localhost URL asks first; declining sends nothing', (tester) async {
      await startLlm(tester);
      // `localhost.` resolves to this machine but isn't the bare loopback host, so it needs consent.
      final url = llm.baseUrl.replaceFirst('127.0.0.1', 'localhost.');
      expect(requiresConsent(url), isTrue);
      final h = await openCustom(tester, url);
      await settle(tester, until: () => find.textContaining('Send your evidence').evaluate().isNotEmpty);
      expect(find.text('Send your evidence to localhost.?'), findsOneWidget);
      await tester.tap(_button('Cancel'));
      await settle(tester, until: () => find.textContaining('Nothing was sent').evaluate().isNotEmpty);
      expect(find.text('Nothing was sent. Consent is needed before using a provider that isn’t on this Mac.'),
          findsOneWidget);
      expect(llm.requests, isEmpty);
      final row = (await read(tester, () => h.appDb.select(h.appDb.providers).get())).single;
      expect(row.consentGiven, isFalse);

      // Accepting stores consent and only then calls the provider.
      await tester.tap(_button('Test connection'));
      await settle(tester, until: () => find.textContaining('Send your evidence').evaluate().isNotEmpty);
      await tester.tap(_button('I understand'));
      await settle(tester, until: () => llm.requests.isNotEmpty);
      expect((await read(tester, () => h.appDb.select(h.appDb.providers).get())).single.consentGiven, isTrue);
      expect(llm.requests.first.$1, '/v1/models');

      // Asked once: testing again sends straight away.
      final before = llm.requests.length;
      await settle(tester, until: () => _button('Test again').evaluate().isNotEmpty);
      await tester.tap(_button('Test again'));
      await settle(tester, until: () => llm.requests.length > before);
      expect(find.textContaining('Send your evidence'), findsNothing);
      await killEngine(tester, h);
    });
  });

  testWidgets('Vision picker lists only vision models; inherits Default by default', (tester) async {
    await startLlm(tester);
    final (_, h) = await bootPage(tester, dir, const AiModelsTab(), size: const Size(1400, 2000));
    await tester.runAsync(() async {
      await addFakeModel(h, llm); // m-text becomes Default
      await addFakeModel(h, llm, model: 'm-vision', info: const ModelInfo(name: 'm-vision', vision: true));
    });
    await tester.tap(find.text('Customize per task'));
    await settle(tester, until: () => find.text('Vision').evaluate().isNotEmpty);
    List<String> optionsOf(String route) => tester
        .widget<SelectButton<String?>>(find.descendant(
          of: find.byWidgetPredicate((w) => w is PanelRow && w.title == route),
          matching: find.byWidgetPredicate((w) => w is SelectButton<String?>),
        ))
        .options
        .map((o) => o.$2)
        .toList();
    await settle(tester, until: () => optionsOf('Vision').length == 2);
    expect(optionsOf('Vision'), ['Inherits default (m-text)', 'm-vision · Fake']);
    expect(optionsOf('Reports'), ['Inherits default (m-text)', 'm-text · Fake', 'm-vision · Fake']);
    // The inherited default can't read images.
    expect(
      find.descendant(
        of: find.byWidgetPredicate((w) => w is PanelRow && w.title == 'Vision'),
        matching: find.text('Can’t read images'),
      ),
      findsOneWidget,
    );
    await killEngine(tester, h);
  });

  testWidgets('Include weekends toggles the daily report and nudge between Mon–Fri and every day', (tester) async {
    final (_, h) = await bootPage(tester, dir, const ScheduleTab());
    final toggle = find.byWidgetPredicate((w) => w is AntSwitch && w.semanticLabel == 'Include weekends');
    await settle(tester, until: () => toggle.evaluate().isNotEmpty);
    Future<Map<String, List<int>?>> days() async => {
          for (final s in await read(tester, () => h.db.select(h.db.schedules).get()))
            if (s.id == Scheduler.dailyReport || s.id == nudgeJobKind)
              s.id: ScheduleRule.fromJson(jsonDecode(s.rule) as Map<String, Object?>).weekdays,
        };
    expect(tester.widget<AntSwitch>(toggle).value, isFalse);
    await tester.tap(toggle);
    await settle(tester, until: () => tester.widget<AntSwitch>(toggle).value);
    expect(await days(), {
      Scheduler.dailyReport: [1, 2, 3, 4, 5, 6, 7],
      nudgeJobKind: [1, 2, 3, 4, 5, 6, 7],
    });
    await tester.tap(toggle);
    await settle(tester, until: () => !tester.widget<AntSwitch>(toggle).value);
    expect(await days(), {
      Scheduler.dailyReport: [1, 2, 3, 4, 5],
      nudgeJobKind: [1, 2, 3, 4, 5],
    });
    // Times are kept.
    final daily = (await read(tester, () => h.db.select(h.db.schedules).get())).firstWhere((s) => s.id == Scheduler.dailyReport);
    expect(ScheduleRule.fromJson(jsonDecode(daily.rule) as Map<String, Object?>).hour, 18);
    await killEngine(tester, h);
  });

  group('source form', () {
    testWidgets('adds, then validates, and keeps the id when validation fails', (tester) async {
      await startLlm(tester);
      final (_, h) = await bootPage(tester, dir, _opener((c) => connectSource(c, SourceOption.ics)));
      await tester.tap(_button('Open'));
      await settle(tester, until: () => _field('Calendar URL').evaluate().isNotEmpty);
      await tester.tap(_button('Connect'));
      await settle(tester);
      expect(find.text('Calendar URL is required'), findsOneWidget);
      expect(await read(tester, () => h.db.select(h.db.sources).get()), isEmpty);

      await tester.enterText(_field('Calendar URL'), '${llm.baseUrl}/missing.ics');
      await tester.tap(_button('Connect'));
      await settle(tester, until: () => llm.requests.isNotEmpty && _button('Connect').evaluate().isNotEmpty);
      await settle(tester);
      var rows = await read(tester, () => h.db.select(h.db.sources).get());
      expect(rows, hasLength(1));
      expect(rows.single.kind, SourceKind.ics);
      expect(find.byType(WideDialog), findsOneWidget, reason: 'stays open showing the problem');
      final id = rows.single.id;

      // Retrying updates the same source instead of adding another.
      await tester.enterText(_field('Calendar URL'), '${llm.baseUrl}/still-missing.ics');
      await tester.tap(_button('Connect'));
      await settle(tester, until: () => llm.requests.length >= 2 && _button('Connect').evaluate().isNotEmpty);
      await settle(tester);
      rows = await read(tester, () => h.db.select(h.db.sources).get());
      expect(rows.map((r) => r.id), [id]);
      expect(jsonDecode(rows.single.config), {'url': '${llm.baseUrl}/still-missing.ics'});
      await killEngine(tester, h);
    });

    testWidgets('GitHub with an API URL is githubEnterprise; a blank secret on edit keeps the old one', (tester) async {
      await startLlm(tester);
      final secrets = FakeSecrets();
      final api = llm.baseUrl.replaceFirst('/v1', '/api/v3');
      final (c, h) = await bootPage(tester, dir, _opener((c) => connectSource(c, SourceOption.github)), secrets: secrets);
      await tester.tap(_button('Open'));
      await settle(tester, until: () => _field('Personal access token').evaluate().isNotEmpty);
      await tester.enterText(_field('Personal access token'), 'ghp_first');
      await tester.enterText(_field('API URL (GitHub Enterprise only)'), api);
      await tester.tap(_button('Connect'));
      await settle(tester, until: () => llm.requests.isNotEmpty && _button('Connect').evaluate().isNotEmpty);
      await settle(tester);
      final row = (await read(tester, () => h.db.select(h.db.sources).get())).single;
      expect(row.kind, SourceKind.githubEnterprise);
      expect(row.name, 'GitHub · 127.0.0.1');
      expect(jsonDecode(row.config), {'apiBaseUrl': api});
      expect(secrets.values[row.credentialRef], 'ghp_first');
      await tester.tap(_button('Cancel'));
      await settle(tester);

      // Edit with the token left blank.
      await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: pageApp(_opener((c) => editSource(c, row))),
      ));
      await settle(tester);
      await tester.tap(_button('Open'));
      await settle(tester, until: () => _field('Personal access token').evaluate().isNotEmpty);
      expect(tester.widget<TextField>(_field('Personal access token')).controller!.text, isEmpty);
      final before = llm.requests.length;
      await tester.tap(_button('Save'));
      await settle(tester, until: () => llm.requests.length > before && _button('Save').evaluate().isNotEmpty);
      await settle(tester);
      expect(find.text('Personal access token is required'), findsNothing);
      final after = (await read(tester, () => h.db.select(h.db.sources).get())).single;
      expect(after.credentialRef, row.credentialRef);
      expect(secrets.values[row.credentialRef], 'ghp_first');
      await killEngine(tester, h);
    });

  });

  testWidgets('git dialog: adding the ticked repos never re-adds an existing repo source', (tester) async {
    late WidgetRef ref;
    final (c, h) = await bootPage(tester, dir, Consumer(builder: (context, r, _) {
      ref = r;
      return const SizedBox();
    }));
    await cmd(tester, h, addSourceCmd(SourceKind.gitRepo, 'a', {'path': '/r/a'}));
    final sources = c.listen(sourcesProvider, (_, _) {});
    addTearDown(sources.close);
    await settle(tester, until: () => (sources.read().value ?? const []).isNotEmpty);
    final scan = RepoScanController(ref);
    addTearDown(scan.dispose);
    scan.selected.addAll(['/r/a', '/r/b']);
    final added = await tester.runAsync(() => scan.addSelected(sources.read().value!));
    expect(added, 1);
    final rows = await read(tester, () => h.db.select(h.db.sources).get());
    expect(rows.map((r) => jsonDecode(r.config)['path']).toList()..sort(), ['/r/a', '/r/b']);
    // Running it again adds nothing.
    await settle(tester, until: () => (sources.read().value ?? const []).length == 2);
    expect(await tester.runAsync(() => scan.addSelected(sources.read().value!)), 0);
    expect(await read(tester, () => h.db.select(h.db.sources).get()), hasLength(2));
    await killEngine(tester, h);
  });

  testWidgets('onboarding shows on first run; Skip setup sets onboarding.done and opens Today', (tester) async {
    final (_, h) = await bootPage(tester, dir, const AntApp());
    await settle(tester, until: () => find.byType(OnboardingPage).evaluate().isNotEmpty);
    expect(find.byType(OnboardingPage), findsOneWidget);
    expect(await read(tester, () => settingOf(h, onboardingDoneSettingKey)), isNull);
    await tester.tap(_button('Skip setup'));
    await settle(tester, until: () => find.byType(TodayPage).evaluate().isNotEmpty);
    expect(find.byType(OnboardingPage), findsNothing);
    expect(await tester.runAsync(() => settingOf(h, onboardingDoneSettingKey)), 'true');
    await killEngine(tester, h);
  });

  testWidgets('onboarding stays away once done', (tester) async {
    final c = ProviderContainer(overrides: [engineConfigProvider.overrideWithValue(testConfig(dir.path))]);
    addTearDown(c.dispose);
    final h = (await tester.runAsync(() => c.read(engineProvider.future)))!;
    await cmd(tester, h, setSettingCmd(onboardingDoneSettingKey, 'true'));
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const AntApp()));
    await settle(tester, until: () => find.byType(TodayPage).evaluate().isNotEmpty);
    expect(find.byType(OnboardingPage), findsNothing);
    await killEngine(tester, h);
  });
}
