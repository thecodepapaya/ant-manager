/// Engine-level tests for the setup screens (Sources, Settings, Onboarding): the commands in
/// `engine/setup_commands.dart` and `engine/commands.dart`.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ant_manager/engine/commands.dart';
import 'package:ant_manager/engine/engine_handle.dart';
import 'package:ant_manager/engine/engine_runtime.dart';
import 'package:ant_manager/engine/messages.dart';
import 'package:ant_manager/engine/setup_commands.dart';
import 'package:ant_manager/features/settings/setup_providers.dart';
import 'package:ant_manager/features/sources/git_setup.dart' show existingRepoPaths;
import 'package:ant_manager/state/providers.dart';
import 'package:core/core.dart' hide Provider;
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support.dart';

EngineCommand<String> _resolveCmd(LlmRoute route) => (rt) async => (await rt.engine.router.resolve(route)).modelName;

EngineCommand<String> _createTemplateCmd(String name) =>
    (rt) => TemplateService(rt.db).create(name: name, periodKinds: const [PeriodKind.weekly], prompt: 'x');

EngineCommand<void> _ruleCmd(String id, ScheduleRule rule, DateTime lastRunAt) => (rt) =>
    (rt.db.update(rt.db.schedules)..where((s) => s.id.equals(id))).write(SchedulesCompanion(
      rule: Value(jsonEncode(rule.toJson())),
      lastRunAt: Value(lastRunAt),
    ));

void main() {
  late Directory dir;
  late EngineHandle h;
  late FakeSecrets secrets;
  late FakeNotifier notifier;
  setUp(() {
    dir = tempDir();
    secrets = FakeSecrets();
    notifier = FakeNotifier();
  });
  tearDown(() => dir.deleteSync(recursive: true));

  Future<void> start({bool inMemory = true}) async {
    h = await startEngine(dir, secrets: secrets, notifier: notifier, inMemory: inMemory);
    addTearDown(h.shutdown);
  }

  Future<Map<LlmRoute, String?>> routes() async =>
      {for (final r in await h.db.select(h.db.taskRoutes).get()) r.route: r.modelId};

  group('models', () {
    late FakeLlm llm;
    setUp(() async {
      llm = await FakeLlm.start();
      addTearDown(llm.close);
      await start();
    });

    Future<String> provider({String? apiKey, Map<String, String>? headers, String? id, String? baseUrl}) async =>
        (await h.runtime(saveProviderCmd(
          id: id,
          kind: ProviderKind.custom,
          name: 'Fake',
          baseUrl: baseUrl ?? llm.baseUrl,
          protocol: ProviderProtocol.openai,
          apiKey: apiKey,
          headers: headers,
        )))
            .$1;

    test('addModelCmd stores nothing when the structured-output probe fails', () async {
      final pid = await provider();
      llm.probeFails = true;
      await expectLater(
        h.runtime(addModelCmd(pid, 'm-text')),
        throwsA(isA<EngineCommandException>().having((e) => e.message, 'message', contains('structured output'))),
      );
      expect(await h.appDb.select(h.appDb.models).get(), isEmpty);
      expect((await routes())[LlmRoute.defaultRoute], isNull);
      expect(llm.chatCalls, 1, reason: 'only the probe was sent');
    });

    test('the first model becomes Default only when none is set', () async {
      final pid = await provider();
      final first = await h.runtime(addModelCmd(pid, 'm-text'));
      expect((await routes())[LlmRoute.defaultRoute], first);
      final second = await h.runtime(addModelCmd(pid, 'm-vision', info: const ModelInfo(name: 'm-vision', vision: true)));
      expect((await routes())[LlmRoute.defaultRoute], first);
      final rows = {for (final m in await h.appDb.select(h.appDb.models).get()) m.id: m};
      expect(rows[second]!.vision, isTrue);
      expect(rows[first]!.vision, isFalse);
      // Re-adding the same model name reuses its row.
      expect(await h.runtime(addModelCmd(pid, 'm-text')), first);
      // Removing the default clears the route; the next added model takes it.
      await h.runtime(removeModelCmd(first));
      expect((await routes())[LlmRoute.defaultRoute], isNull);
      final third = await h.runtime(addModelCmd(pid, 'm-text'));
      expect((await routes())[LlmRoute.defaultRoute], third);
    });

    test('a null route inherits Default; a set route uses its own model', () async {
      final pid = await provider();
      await h.runtime(addModelCmd(pid, 'm-text'));
      final vision = await h.runtime(addModelCmd(pid, 'm-vision', info: const ModelInfo(name: 'm-vision', vision: true)));
      expect(await h.runtime(_resolveCmd(LlmRoute.vision)), 'm-text');
      await h.runtime(setRouteCmd(LlmRoute.vision, vision));
      expect(await h.runtime(_resolveCmd(LlmRoute.vision)), 'm-vision');
      expect(await h.runtime(_resolveCmd(LlmRoute.reports)), 'm-text');
      await h.runtime(setRouteCmd(LlmRoute.vision, null));
      expect(await h.runtime(_resolveCmd(LlmRoute.vision)), 'm-text');
    });

    test('consent is per base URL: kept on re-save, reset when the URL changes', () async {
      final (pid, given) = await h.runtime(saveProviderCmd(
        kind: ProviderKind.openai,
        name: 'OpenAI',
        baseUrl: 'https://api.openai.example/v1',
        protocol: ProviderProtocol.openai,
        apiKey: 'sk-1',
      ));
      expect(given, isFalse);
      await h.runtime(setProviderConsentCmd(pid));
      final (_, again) = await h.runtime(saveProviderCmd(
        id: pid,
        kind: ProviderKind.openai,
        name: 'OpenAI',
        baseUrl: 'https://api.openai.example/v1',
        protocol: ProviderProtocol.openai,
      ));
      expect(again, isTrue);
      final (_, moved) = await h.runtime(saveProviderCmd(
        id: pid,
        kind: ProviderKind.openai,
        name: 'OpenAI',
        baseUrl: 'https://gateway.example/v1',
        protocol: ProviderProtocol.openai,
      ));
      expect(moved, isFalse);
      expect((await h.appDb.select(h.appDb.providers).getSingle()).consentGiven, isFalse);
      expect(llm.requests, isEmpty, reason: 'saving sends nothing');
    });

    test('loopback never needs consent; LAN and remote hosts do', () {
      for (final u in ['http://localhost:11434', 'http://127.0.0.1:1234/v1', 'http://[::1]:8080', llm.baseUrl]) {
        expect(requiresConsent(u), isFalse, reason: u);
      }
      for (final u in ['http://192.168.1.20:11434', 'http://gpu-box.local:1234/v1', 'https://openrouter.ai/api/v1']) {
        expect(requiresConsent(u), isTrue, reason: u);
      }
    });

    test('API key: null keeps the stored one, empty deletes it', () async {
      final pid = await provider(apiKey: 'sk-one');
      final ref = (await h.appDb.select(h.appDb.providers).getSingle()).credentialRef!;
      expect(secrets.values[ref], 'sk-one');
      await provider(id: pid); // apiKey null
      expect((await h.appDb.select(h.appDb.providers).getSingle()).credentialRef, ref);
      expect(secrets.values[ref], 'sk-one');
      await provider(id: pid, apiKey: 'sk-two');
      expect(secrets.values[ref], 'sk-two');
      await provider(id: pid, apiKey: '');
      expect((await h.appDb.select(h.appDb.providers).getSingle()).credentialRef, isNull);
      expect(secrets.values.containsKey(ref), isFalse);
    });

    test('headers go to the secret store and replace the old ones', () async {
      final pid = await provider(headers: {'X-Team': 'a', 'X-Old': 'b'});
      var refs = (jsonDecode((await h.appDb.select(h.appDb.providers).getSingle()).headers) as Map).cast<String, String>();
      expect(refs.keys.toSet(), {'X-Team', 'X-Old'});
      expect(secrets.values[refs['X-Team']], 'a');
      expect(jsonEncode(await h.appDb.select(h.appDb.providers).get()), isNot(contains('"b"')),
          reason: 'values are not stored in the DB');
      final old = refs['X-Old']!;
      await provider(id: pid); // headers null = keep
      expect(secrets.values[old], 'b');
      await provider(id: pid, headers: {'X-Team': 'c'});
      refs = (jsonDecode((await h.appDb.select(h.appDb.providers).getSingle()).headers) as Map).cast<String, String>();
      expect(refs.keys, ['X-Team']);
      expect(secrets.values[refs['X-Team']], 'c');
      expect(secrets.values.containsKey(old), isFalse);
      // The current header (read back from the secret store) is sent; the removed one isn't.
      await h.runtime(listProviderModelsCmd(pid));
      expect(llm.requests.last.$1, '/v1/models');
      expect(llm.headers.last['x-team'], 'c');
      expect(llm.headers.last.containsKey('x-old'), isFalse);
    });

    test('removing a provider clears routes to its models and its secrets', () async {
      final pid = await provider(apiKey: 'sk', headers: {'X-A': '1'});
      final m = await h.runtime(addModelCmd(pid, 'm-text'));
      await h.runtime(setRouteCmd(LlmRoute.reports, m));
      await h.runtime(removeProviderCmd(pid));
      final r = await routes();
      expect(r[LlmRoute.defaultRoute], isNull);
      expect(r[LlmRoute.reports], isNull);
      expect(await h.appDb.select(h.appDb.models).get(), isEmpty);
      expect(await h.appDb.select(h.appDb.providers).get(), isEmpty);
      expect(secrets.values, isEmpty);
    });

    test('Test connection lists the provider\'s models, vision flagged', () async {
      final pid = await provider();
      final models = await h.runtime(listProviderModelsCmd(pid));
      expect({for (final m in models) m.name: m.vision}, {'m-text': false, 'm-vision': true});
    });
  });

  group('schedule', () {
    setUp(start);

    test('setScheduleCmd writes the rule and enabled flag and sets lastRunAt = now', () async {
      final before = DateTime.now().toUtc().subtract(const Duration(seconds: 1));
      await h.runtime(setScheduleCmd(Scheduler.dailyReport, const ScheduleRule(hour: 7, minute: 30), false));
      final s = await (h.db.select(h.db.schedules)..where((x) => x.id.equals(Scheduler.dailyReport))).getSingle();
      expect(ScheduleRule.fromJson(jsonDecode(s.rule) as Map<String, Object?>).toJson(), {'hour': 7, 'minute': 30});
      expect(s.enabled, isFalse);
      expect(s.lastRunAt!.isAfter(before), isTrue);
      expect(s.lastRunAt!.isBefore(DateTime.now().toUtc().add(const Duration(seconds: 1))), isTrue);
      // Moving the time earlier today does not fire a "missed" run.
      await h.runtime(setScheduleCmd(Scheduler.dailyReport, const ScheduleRule(hour: 0, minute: 0), true));
      expect(await h.runtime(tickCmd(DateTime.now().toUtc())), isEmpty);
    });

    test('the default daily report and nudge run Mon–Fri', () async {
      for (final id in [Scheduler.dailyReport, nudgeJobKind]) {
        final s = await (h.db.select(h.db.schedules)..where((x) => x.id.equals(id))).getSingle();
        expect(ScheduleRule.fromJson(jsonDecode(s.rule) as Map<String, Object?>).weekdays, [1, 2, 3, 4, 5], reason: id);
      }
    });

    test('the nudge notifies only on days with evidence', () async {
      await h.runtime(enqueueJobCmd(nudgeJobKind));
      expect(await h.runtime(runJobCmd(JobLane.io)), isTrue);
      expect(notifier.shown, isEmpty);
      // Evidence on another day doesn't count.
      await h.runtime(addNoteCmd(text: 'old', at: DateTime.now().subtract(const Duration(days: 3))));
      await h.runtime(enqueueJobCmd(nudgeJobKind));
      await h.runtime(runJobCmd(JobLane.io));
      expect(notifier.shown, isEmpty);
      await h.runtime(addNoteCmd(text: 'today', at: DateTime.now()));
      await h.runtime(enqueueJobCmd(nudgeJobKind));
      await h.runtime(runJobCmd(JobLane.io));
      expect(notifier.shown, [('Your day is drafted', '2-minute review?', 'open-today')]);
    });

    test('a due nudge schedule enqueues the nudge job', () async {
      final now = DateTime.now();
      await h.runtime(_ruleCmd(nudgeJobKind, ScheduleRule(hour: 0, weekdays: [now.weekday]),
          DateTime(now.year, now.month, now.day).subtract(const Duration(days: 2)).toUtc()));
      await h.runtime(tickCmd(DateTime.now().toUtc()));
      final jobs = await h.db.select(h.db.jobs).get();
      expect(jobs.map((j) => j.kind), contains(nudgeJobKind));
    });
  });

  group('backup', () {
    setUp(() => start(inMemory: false));

    test('honours keep and readable export, and records last success', () async {
      final folder = p.join(dir.path, 'bk');
      await h.runtime(setSettingCmd(backupFolderSettingKey, folder));
      await h.runtime(setSettingCmd(backupKeepSettingKey, '2'));
      await h.runtime(setSettingCmd(backupReadableSettingKey, 'true'));
      await h.runtime(addNoteCmd(text: 'kept in the backup', at: DateTime.now()));
      final paths = <String>[];
      for (var i = 0; i < 3; i++) {
        if (i > 0) await Future<void>.delayed(const Duration(milliseconds: 1100)); // names are per second
        paths.add(await h.runtime(backupNowCmd()));
      }
      final bundles = Directory(folder).listSync().whereType<File>().where((f) => f.path.endsWith('.antbackup'));
      expect(bundles.map((f) => f.path).toSet(), paths.skip(1).toSet(), reason: 'only the newest 2 kept');
      expect(Directory(folder).listSync().whereType<Directory>().map((d) => p.basename(d.path)), ['Work-export']);
      expect(DateTime.tryParse(await settingOf(h, backupLastSuccessSettingKey) ?? ''), isNotNull);
      expect(await settingOf(h, backupLastErrorSettingKey), '');
    });

    test('without readable export no export folder is written', () async {
      final folder = p.join(dir.path, 'bk2');
      await h.runtime(setSettingCmd(backupFolderSettingKey, folder));
      await h.runtime(backupNowCmd());
      expect(Directory(folder).listSync().whereType<Directory>(), isEmpty);
    });

    test('a failure records the error and keeps the last success', () async {
      await h.runtime(backupNowCmd()); // default folder
      final ok = await settingOf(h, backupLastSuccessSettingKey);
      final blocker = File(p.join(dir.path, 'not-a-folder'))..writeAsStringSync('x');
      await h.runtime(setSettingCmd(backupFolderSettingKey, blocker.path));
      await expectLater(h.runtime(backupNowCmd()), throwsA(isA<EngineCommandException>()));
      expect(await settingOf(h, backupLastErrorSettingKey), isNotEmpty);
      expect(await settingOf(h, backupLastSuccessSettingKey), ok);
    });

    test('restore creates "… (restored)" with the data', () async {
      await h.runtime(addNoteCmd(text: 'restore me', at: DateTime.now()));
      final file = await h.runtime(backupNowCmd());
      final id = await h.runtime(restoreBackupCmd(file));
      final profiles = {for (final x in await h.appDb.select(h.appDb.profiles).get()) x.id: x};
      expect(profiles[id]!.name, 'Work (restored)');
      expect(profiles[id]!.active, isFalse);
      expect(profiles[h.profileId]!.active, isTrue, reason: 'the current profile is untouched');
      final restored = ProfileDb(NativeDatabase(File(p.join(dir.path, 'profiles', '$id.sqlite'))));
      addTearDown(restored.close);
      expect((await restored.select(restored.evidences).get()).map((e) => e.title), ['restore me']);
    });

    test('restore refuses a newer schema and leaves no orphan profile', () async {
      final file = await h.runtime(backupNowCmd());
      final newer = await _bumpSchema(file, dir);
      await expectLater(
        h.runtime(restoreBackupCmd(newer)),
        throwsA(isA<EngineCommandException>().having((e) => e.message, 'message', contains('newer version'))),
      );
      expect((await h.appDb.select(h.appDb.profiles).get()).map((x) => x.name), ['Work']);
      final files = Directory(p.join(dir.path, 'profiles')).listSync().map((f) => p.basename(f.path));
      expect(files.where((f) => !f.startsWith(h.profileId)), isEmpty, reason: 'no restored DB file left behind');
    });

    test('a file that is not a backup is refused with no profile created', () async {
      final junk = File(p.join(dir.path, 'junk.antbackup'))..writeAsStringSync('nope');
      await expectLater(h.runtime(restoreBackupCmd(junk.path)), throwsA(isA<EngineCommandException>()));
      expect(await h.appDb.select(h.appDb.profiles).get(), hasLength(1));
    });
  }, skip: Process.runSync('which', ['zip']).exitCode != 0 ? 'needs zip/unzip' : null);

  group('templates', () {
    setUp(start);

    Future<Template> tpl(String id) => (h.db.select(h.db.templates)..where((t) => t.id.equals(id))).getSingle();

    test('editing a built-in duplicates it and leaves the built-in alone', () async {
      const id = 'builtin.standup';
      final original = await tpl(id);
      final changed = await h.runtime(updateTemplateCmd(id, prompt: 'My standup'));
      expect(changed, isNot(id));
      expect(changed, startsWith('$id/'));
      expect((await tpl(changed)).prompt, 'My standup');
      expect((await tpl(changed)).builtIn, isFalse);
      expect((await tpl(id)).prompt, original.prompt);
      // Editing the copy edits it in place.
      expect(await h.runtime(updateTemplateCmd(changed, name: 'Mine')), changed);
    });

    test('reset only works on copies of a built-in', () async {
      const id = 'builtin.standup';
      final original = await tpl(id);
      final copy = await h.runtime(updateTemplateCmd(id, prompt: 'Changed'));
      await h.runtime(resetTemplateCmd(copy));
      expect((await tpl(copy)).prompt, original.prompt);
      await h.runtime(resetTemplateCmd(id)); // a built-in itself: no-op
      expect((await tpl(id)).version, original.version);
      // A duplicate of a custom template has no built-in to reset to.
      final custom = await h.runtime(duplicateTemplateCmd(copy));
      expect(custom, startsWith('$id/'), reason: 'a copy of a copy still traces to the built-in');
      final unrelated = await h.runtime(_createTemplateCmd('Own'));
      await expectLater(h.runtime(resetTemplateCmd(unrelated)), throwsA(isA<EngineCommandException>()));
    });

    test('a template used by a report cannot be deleted; built-ins never', () async {
      final copy = await h.runtime(duplicateTemplateCmd('builtin.weekly_review'));
      await h.runtime(ensureReportCmd(PeriodKind.weekly, '2026-03-02', '2026-03-08', copy));
      await expectLater(
        h.runtime(deleteTemplateCmd(copy)),
        throwsA(isA<EngineCommandException>().having((e) => e.message, 'message', contains('used by'))),
      );
      await expectLater(h.runtime(deleteTemplateCmd('builtin.weekly_review')), throwsA(isA<EngineCommandException>()));
      final unused = await h.runtime(duplicateTemplateCmd('builtin.weekly_review'));
      await h.runtime(deleteTemplateCmd(unused));
      expect(await (h.db.select(h.db.templates)..where((t) => t.id.equals(unused))).get(), isEmpty);
      expect(await (h.db.select(h.db.templates)..where((t) => t.id.equals(copy))).get(), hasLength(1));
    });

    test('preview renders with the model and saves nothing', () async {
      final llm = await FakeLlm.start();
      addTearDown(llm.close);
      await addFakeModel(h, llm);
      final ev = await h.runtime(addNoteCmd(text: 'Shipped', at: DateTime.now()));
      await h.runtime(createFactCmd([ev], statement: 'Shipped the preview'));
      final md = await h.runtime(previewTemplateCmd('builtin.standup', PeriodKind.daily));
      expect(md, contains('Shipped the preview'));
      expect(await h.db.select(h.db.reports).get(), isEmpty);
      expect(await h.db.select(h.db.reportSnapshots).get(), isEmpty);
    });
  });

  group('sources, identities, curation rules', () {
    setUp(start);

    test('a blank secret on edit keeps the old one; a new one replaces it', () async {
      final id = await h.runtime(addSourceCmd(SourceKind.linear, 'Linear', const {}, secret: 'lin_1'));
      final ref = (await h.db.select(h.db.sources).getSingle()).credentialRef!;
      expect(secrets.values[ref], 'lin_1');
      await h.runtime(updateSourceCmd(id, name: 'Linear', config: const {}, enabled: true));
      expect((await h.db.select(h.db.sources).getSingle()).credentialRef, ref);
      expect(secrets.values[ref], 'lin_1');
      await h.runtime(updateSourceCmd(id, secret: 'lin_2'));
      expect(secrets.values[ref], 'lin_2');
    });

    test('identities are de-duplicated case-insensitively per kind and trimmed', () async {
      await h.runtime(addIdentityCmd('email', 'Me@Example.com'));
      await h.runtime(addIdentityCmd('email', ' me@example.COM '));
      await h.runtime(addIdentityCmd('email', '   '));
      await h.runtime(addIdentityCmd('github_login', 'me@example.com'));
      final rows = await h.db.select(h.db.identities).get();
      expect({for (final i in rows) (i.kind, i.value)}, {('email', 'Me@Example.com'), ('github_login', 'me@example.com')});
      await h.runtime(removeIdentityCmd(rows.firstWhere((i) => i.kind == 'email').id));
      expect(await h.db.select(h.db.identities).get(), hasLength(1));
    });

    test('curation rules are stored as {titlePattern, sourceKind?}; hide stores value 0', () async {
      await h.runtime(saveCurationRuleCmd(id: 'r1', titlePattern: 'Lunch', action: CurationAction.hide, value: 0.7));
      await h.runtime(saveCurationRuleCmd(
        id: 'r2',
        titlePattern: 'Release*',
        sourceKind: SourceKind.github,
        action: CurationAction.setImportance,
        value: 0.9,
      ));
      final rules = {for (final r in await h.db.select(h.db.curationRules).get()) r.id: r};
      expect(jsonDecode(rules['r1']!.match), {'titlePattern': 'Lunch'});
      expect(rules['r1']!.value, 0);
      expect(jsonDecode(rules['r2']!.match), {'titlePattern': 'Release*', 'sourceKind': 'github'});
      expect(rules['r2']!.value, 0.9);
      // Saving with the same id updates in place.
      await h.runtime(saveCurationRuleCmd(id: 'r2', titlePattern: 'Ship*', action: CurationAction.hide, value: 0.9));
      final r2 = await (h.db.select(h.db.curationRules)..where((r) => r.id.equals('r2'))).getSingle();
      expect(jsonDecode(r2.match), {'titlePattern': 'Ship*'});
      expect(r2.value, 0);
      await h.runtime(setCurationRuleEnabledCmd('r2', false));
      expect((await (h.db.select(h.db.curationRules)..where((r) => r.id.equals('r2'))).getSingle()).enabled, isFalse);
      await h.runtime(deleteCurationRuleCmd('r1'));
      expect(await h.db.select(h.db.curationRules).get(), hasLength(1));
    });

    test('existingRepoPaths lists the added git repos (not other sources)', () async {
      final a = await h.runtime(addSourceCmd(SourceKind.gitRepo, 'a', {'path': '/r/a'}));
      await h.runtime(addSourceCmd(SourceKind.gitRepo, 'b', {'path': '/r/b'}));
      await h.runtime(addSourceCmd(SourceKind.ics, 'ICS', {'url': 'https://x.example/c.ics'}));
      final c = ProviderContainer(overrides: [engineProvider.overrideWith(() => _FixedEngine(h))]);
      addTearDown(c.dispose);
      var all = await _next(c, sourcesProvider, (v) => v.length == 3);
      expect(existingRepoPaths(all), {'/r/a', '/r/b'});
      expect(a, isNotEmpty);
    });

    test(
      'a removed (disabled) repo is not added a second time',
      () async {
        final a = await h.runtime(addSourceCmd(SourceKind.gitRepo, 'a', {'path': '/r/a'}));
        await h.runtime(removeSourceCmd(a));
        final c = ProviderContainer(overrides: [engineProvider.overrideWith(() => _FixedEngine(h))]);
        addTearDown(c.dispose);
        final all = await _next(c, sourcesProvider, (v) => v.any((s) => !s.row.enabled));
        expect(existingRepoPaths(all), contains('/r/a'));
      },
    );
  });

  group('onboarding gate', () {
    setUp(start);

    Future<bool> needed() async {
      final c = ProviderContainer(overrides: [engineProvider.overrideWith(() => _FixedEngine(h))]);
      addTearDown(c.dispose);
      return c.read(onboardingNeededProvider.future);
    }

    test('shows on a fresh profile; notes alone do not count as sources', () async {
      expect(await needed(), isTrue);
      await h.runtime(addNoteCmd(text: 'a note', at: DateTime.now()));
      await h.runtime(importTranscriptCmd('t.txt', 'hi', DateTime.now()));
      expect(await needed(), isTrue);
    });

    test('hidden once there is an identity', () async {
      await h.runtime(addIdentityCmd('email', 'me@example.com'));
      expect(await needed(), isFalse);
    });

    test('hidden once there is a connector source', () async {
      await h.runtime(addSourceCmd(SourceKind.ics, 'ICS', {'url': 'https://x.example/c.ics'}));
      expect(await needed(), isFalse);
    });

    test('hidden once onboarding.done is set', () async {
      await h.runtime(setSettingCmd(onboardingDoneSettingKey, 'true'));
      expect(await needed(), isFalse);
    });
  });
}

/// Rewrites [file]'s manifest with schema_version + 1 (system zip/unzip; the app has no archive dep).
Future<String> _bumpSchema(String file, Directory dir) async {
  final work = Directory(p.join(dir.path, 'bump'))..createSync();
  expect((await Process.run('unzip', ['-q', file, '-d', work.path])).exitCode, 0);
  final manifest = File(p.join(work.path, 'manifest.json'));
  final m = jsonDecode(manifest.readAsStringSync()) as Map<String, Object?>;
  m['schema_version'] = (m['schema_version'] as int) + 1;
  manifest.writeAsStringSync(jsonEncode(m));
  final out = p.join(dir.path, 'newer.antbackup');
  final r = await Process.run('zip', ['-q', '-r', out, '.'], workingDirectory: work.path);
  expect(r.exitCode, 0, reason: '${r.stderr}');
  return out;
}

class _FixedEngine extends EngineController {
  _FixedEngine(this.h);
  final EngineHandle h;
  @override
  Future<EngineHandle> build() async => h;
}

Future<T> _next<T>(ProviderContainer c, ProviderListenable<AsyncValue<T>> provider, bool Function(T) where) {
  final done = Completer<T>();
  final sub = c.listen(provider, (_, v) {
    final value = v.value;
    if (value is T && where(value) && !done.isCompleted) done.complete(value);
  }, fireImmediately: true);
  return done.future.timeout(const Duration(seconds: 5)).whenComplete(sub.close);
}
