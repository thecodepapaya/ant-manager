// Independent tests (#99) for the privacy gaps closed in DECISIONS #118:
// (a) consent enforced in createClient, (b) restore clears secret refs and disables those sources,
// (c) git reads can't be made to run the repo's own commands (textconv, external diff, gpg.program).
import 'dart:convert';
import 'dart:io';

import 'package:core/core.dart';
import 'package:core/src/capture/sources/git_repo.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'fakes.dart';
import 'sources/support.dart' show Api, Res, Ctx;

const token = 'ghp_ORIGINAL_TOKEN_118';

Provider providerRow({required String baseUrl, bool consent = false, String id = 'p'}) => Provider(
  id: id,
  kind: ProviderKind.custom,
  name: 'Box',
  baseUrl: baseUrl,
  protocol: ProviderProtocol.openai,
  headers: '{}',
  allowSelfSigned: false,
  timeoutSeconds: 5,
  consentGiven: consent,
);

Matcher noConsent() => throwsA(
  isA<LlmFailure>().having((f) => f.message, 'message', allOf(contains('Box'), contains('consent'))),
);

/// A fake OpenAI-compatible server on every IPv4 interface, so a LAN (non-loopback) address of this machine
/// really reaches it: proof that a missing request is due to the consent check, not an unreachable URL.
class LanServer {
  LanServer._(this._server, this.lanIp);
  final HttpServer _server;
  final String? lanIp;
  final paths = <String>[];

  static Future<LanServer> start() async {
    final s = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    String? ip;
    for (final i in await NetworkInterface.list(type: InternetAddressType.IPv4)) {
      for (final a in i.addresses) {
        if (!a.isLoopback && !a.isLinkLocal) ip ??= a.address;
      }
    }
    final server = LanServer._(s, ip);
    s.listen((req) async {
      server.paths.add(req.uri.path);
      await req.drain<void>();
      req.response.headers.contentType = ContentType.json;
      req.response.write(
        jsonEncode({
          'data': [
            {'id': 'm'},
          ],
        }),
      );
      await req.response.close();
    });
    return server;
  }

  String get loopbackUrl => 'http://127.0.0.1:${_server.port}/v1';
  String get lanUrl => 'http://$lanIp:${_server.port}/v1';
  Future<void> close() => _server.close(force: true);
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  group('(a) createClient enforces consent', () {
    test('a non-loopback base URL without consent throws LlmFailure', () {
      for (final u in [
        'https://api.openai.com/v1',
        'http://192.168.1.20:11434',
        'http://10.0.0.5:8000/v1',
        'http://gpu-box.local:1234',
        'http://localhost.example.com/v1',
        'http://[fe80::1]:1234',
      ]) {
        expect(() => createClient(providerRow(baseUrl: u), apiKey: 'k'), noConsent(), reason: u);
      }
    });

    test('loopback URLs need no consent', () {
      for (final u in [
        'http://localhost:11434',
        'http://LOCALHOST:1234/v1',
        'http://127.0.0.1:1234/v1',
        'http://127.4.5.6:80',
        'http://[::1]:8080/v1',
      ]) {
        expect(createClient(providerRow(baseUrl: u), apiKey: null), isA<LlmClient>(), reason: u);
      }
    });

    test('with consent a non-loopback URL builds a client', () {
      expect(createClient(providerRow(baseUrl: 'https://api.openai.com/v1', consent: true), apiKey: 'k'), isA<LlmClient>());
    });

    test('every protocol is checked, not only openai', () {
      for (final (kind, proto) in [
        (ProviderKind.custom, ProviderProtocol.ollama),
        (ProviderKind.anthropic, ProviderProtocol.native),
        (ProviderKind.gemini, ProviderProtocol.native),
      ]) {
        final row = providerRow(baseUrl: 'https://remote.example/v1').copyWith(kind: kind, protocol: proto);
        expect(() => createClient(row, apiKey: 'k'), noConsent(), reason: '$kind/$proto');
      }
    });
  });

  group('(a) DbModelRouter after the URL changes without consent', () {
    late AppDb app;
    late ProfileDb profile;
    late LanServer server;
    late DbModelRouter router;

    setUp(() async {
      server = await LanServer.start();
      app = AppDb(NativeDatabase.memory());
      profile = ProfileDb(NativeDatabase.memory());
      router = DbModelRouter(appDb: app, profileDb: profile, secrets: MemSecrets());
      await app
          .into(app.providers)
          .insert(
            ProvidersCompanion.insert(
              id: 'p',
              kind: ProviderKind.custom,
              name: 'Box',
              baseUrl: server.loopbackUrl,
              protocol: ProviderProtocol.openai,
            ),
          );
      await app.into(app.models).insert(ModelsCompanion.insert(id: 'm', providerId: 'p', modelName: 'm'));
      await profile
          .into(profile.taskRoutes)
          .insert(TaskRoutesCompanion.insert(route: LlmRoute.defaultRoute, modelId: const Value('m')));
    });
    tearDown(() async {
      await app.close();
      await profile.close();
      await server.close();
    });

    Future<void> setProvider(String url, {required bool consent}) =>
        (app.update(app.providers)..where((x) => x.id.equals('p'))).write(
          ProvidersCompanion(baseUrl: Value(url), consentGiven: Value(consent)),
        );

    test('loopback resolves without consent', () async {
      final m = await router.resolve(LlmRoute.extraction);
      await m.client.listModels();
      expect(server.paths, ['/v1/models']);
    });

    test('a URL moved off loopback fails at resolve, before any request', () async {
      await setProvider('https://llm.invalid/v1', consent: false);
      await expectLater(router.resolve(LlmRoute.defaultRoute), noConsent());
      await expectLater(router.resolve(LlmRoute.reports), noConsent());
      await expectLater(router.resolve(LlmRoute.vision), noConsent());
    });

    test(
      'a reachable LAN URL: with consent requests arrive; consent reset (URL edit) → no request reaches it',
      () async {
        if (server.lanIp == null) return markTestSkipped('no LAN interface');
        await setProvider(server.lanUrl, consent: true);
        await (await router.resolve(LlmRoute.defaultRoute)).client.listModels();
        expect(server.paths, ['/v1/models'], reason: 'the LAN address really reaches the fake server');
        server.paths.clear();
        await setProvider(server.lanUrl, consent: false);
        await expectLater(router.resolve(LlmRoute.defaultRoute), noConsent());
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(server.paths, isEmpty);
      },
    );
  });

  group('(b) restore clears secret references', () {
    late Directory tmp;
    late ProfileDb live;
    late MemSecrets secrets;
    late Api api;
    final clock = MutableClock(DateTime.utc(2026, 11, 18, 2));

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('privacy118');
      live = ProfileDb(NativeDatabase(File(p.join(tmp.path, 'live.sqlite'))));
      secrets = MemSecrets()..values['source:gh'] = token;
      api = await Api.start();
      api.handler = (h) => h.uri.path == '/user' ? const Res({'login': 'me'}) : null;
      Future<void> add(String id, SourceKind kind, {String? cred, bool enabled = true, Map<String, Object?>? config}) =>
          live
              .into(live.sources)
              .insert(
                SourcesCompanion.insert(
                  id: id,
                  kind: kind,
                  name: id,
                  credentialRef: Value(cred),
                  enabled: Value(enabled),
                  config: Value(jsonEncode(config ?? const {})),
                ),
              );
      await add('gh', SourceKind.github, cred: 'source:gh', config: {'apiBaseUrl': api.url, 'login': 'me'});
      await add('lin', SourceKind.linear, cred: 'source:lin');
      await add('off', SourceKind.jira, cred: 'source:off', enabled: false);
      await add('repo', SourceKind.gitRepo, config: {'path': '/tmp/x'});
      await add('repo-off', SourceKind.gitRepo, enabled: false);
    });
    tearDown(() async {
      await live.close();
      await api.close();
      await tmp.delete(recursive: true);
    });

    Future<String> backupAndRestore() async {
      final file = await BackupService(
        live,
        profileName: 'Work',
        appVersion: '1',
        clock: clock,
      ).createBackup(p.join(tmp.path, 'bk'));
      final target = p.join(tmp.path, 'restored.sqlite');
      await BackupService.restore(file.path, target, currentSchemaVersion: live.schemaVersion);
      return target;
    }

    Future<Map<String, SourceRow>> rows(ProfileDb db) async => {
      for (final s in await db.select(db.sources).get()) s.id: s,
    };

    test('sources with a ref lose it and are disabled; others are unchanged', () async {
      final restored = ProfileDb(NativeDatabase(File(await backupAndRestore())));
      addTearDown(restored.close);
      final r = await rows(restored);
      for (final id in ['gh', 'lin', 'off']) {
        expect(r[id]!.credentialRef, isNull, reason: id);
        expect(r[id]!.enabled, isFalse, reason: id);
      }
      expect((r['repo']!.enabled, r['repo']!.credentialRef), (true, null));
      expect((r['repo-off']!.enabled, r['repo-off']!.credentialRef), (false, null));
      expect(r['gh']!.config, contains(api.url), reason: 'config is kept');
      // The live profile is untouched.
      final l = await rows(live);
      expect((l['gh']!.enabled, l['gh']!.credentialRef), (true, 'source:gh'));
      expect(secrets.values['source:gh'], token, reason: 'restore never deletes secrets');
    });

    test('a restored GitHub source never sends the original token, even when re-enabled', () async {
      final restored = ProfileDb(NativeDatabase(File(await backupAndRestore())));
      addTearDown(restored.close);
      AntEngine engineOn(ProfileDb db) {
        final e = AntEngine(
          db: db,
          profileId: 'p1',
          ports: EnginePorts(secrets: secrets, blobs: MemBlobs(), git: NoGit(), watcher: NoWatcher(), clock: clock),
          router: ScriptedRouter(ScriptedLlm([])),
          utcOffset: (_) => Duration.zero,
        );
        registerCodeSources(e.sources);
        return e;
      }

      // Control: in the live profile the token resolves and is sent.
      final liveSync = SyncService(engineOn(live));
      expect((await liveSync.validateSource('gh')).ok, isTrue);
      expect(api.hits.single.headers.value('authorization'), contains(token));
      api.hits.clear();

      // Same machine, same secret store: the restored source has no ref, so the token is unreachable.
      final sync = SyncService(engineOn(restored));
      await sync.updateSource('gh', enabled: true); // re-enabled without signing in again
      expect((await rows(restored))['gh']!.credentialRef, isNull);
      expect((await sync.validateSource('gh')).ok, isFalse);
      await expectLater(sync.syncSource('gh'), throwsA(anything));
      expect(api.hits.where((h) => '${h.headers.value('authorization')}'.contains(token)), isEmpty);
      expect(api.hits, isEmpty);
    });

    test('saving the source with a new secret re-enables it with a ref to the new secret', () async {
      final restored = ProfileDb(NativeDatabase(File(await backupAndRestore())));
      addTearDown(restored.close);
      final e = AntEngine(
        db: restored,
        profileId: 'p1',
        ports: EnginePorts(secrets: secrets, blobs: MemBlobs(), git: NoGit(), watcher: NoWatcher(), clock: clock),
        router: ScriptedRouter(ScriptedLlm([])),
        utcOffset: (_) => Duration.zero,
      );
      registerCodeSources(e.sources);
      final sync = SyncService(e);
      // What the source form does on save (secret + enabled: true). The new ref is `source:<id>` again, the
      // same keychain item the original profile uses; that clobbering is BUG-skipped in app/test/features/privacy_118_test.dart.
      await sync.updateSource('gh', name: 'gh', secret: 'ghp_NEW', enabled: true);
      final gh = (await rows(restored))['gh']!;
      expect(gh.enabled, isTrue);
      expect(gh.credentialRef, isNotNull);
      expect(secrets.values[gh.credentialRef!], 'ghp_NEW');
      expect((await sync.validateSource('gh')).ok, isTrue);
      expect(api.hits.last.headers.value('authorization'), contains('ghp_NEW'));
      expect(api.hits.last.headers.value('authorization'), isNot(contains(token)));
    });
  });

  group('(c) git reads cannot run the repo\'s commands', () {
    late Directory tmp;
    late String repo;
    late String marker;
    late String hook;
    final now = DateTime.now().toUtc();

    Future<ProcessResult> git(List<String> args, {String? stdin}) async {
      final date = now.subtract(const Duration(hours: 2)).toIso8601String();
      final env = {
        'GIT_AUTHOR_NAME': 'Me',
        'GIT_AUTHOR_EMAIL': 'me@x.test',
        'GIT_COMMITTER_NAME': 'Me',
        'GIT_COMMITTER_EMAIL': 'me@x.test',
        'GIT_AUTHOR_DATE': date,
        'GIT_COMMITTER_DATE': date,
      };
      if (stdin == null) return Process.run('git', ['-C', repo, ...args], environment: env);
      final proc = await Process.start('git', ['-C', repo, ...args], environment: env);
      proc.stdin.write(stdin);
      await proc.stdin.close();
      final out = await proc.stdout.transform(utf8.decoder).join();
      await proc.stderr.drain<void>();
      return ProcessResult(proc.pid, await proc.exitCode, out, '');
    }

    Future<String> ok(List<String> args, {String? stdin}) async {
      final r = await git(args, stdin: stdin);
      if (r.exitCode != 0) fail('git $args: ${r.stderr}');
      return (r.stdout as String).trim();
    }

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('privacy118_git');
      repo = p.join(tmp.path, 'repo');
      marker = p.join(tmp.path, 'marker');
      hook = p.join(tmp.path, 'hook.sh');
      File(hook).writeAsStringSync('#!/bin/sh\necho "\$0 \$*" >> "$marker"\ncat "\$1" 2>/dev/null\nexit 0\n');
      await Process.run('chmod', ['+x', hook]);
      await Directory(repo).create();
      await ok(['init', '-q', '-b', 'main']);
      for (final kv in [
        ['commit.gpgsign', 'false'],
        ['diff.evil.textconv', hook],
        ['diff.evil.command', hook],
        ['diff.external', hook],
        ['gpg.program', hook],
        ['gpg.ssh.program', hook],
        ['log.showSignature', 'true'],
      ]) {
        await ok(['config', ...kv]);
      }
      File(p.join(repo, '.gitattributes')).writeAsStringSync('* diff=evil\n');
      File(p.join(repo, 'a.ipynb')).writeAsStringSync('{"cells": []}\n');
      await ok(['add', '.']);
      await ok(['commit', '-q', '-m', 'one']);
      File(p.join(repo, 'a.ipynb')).writeAsStringSync('{"cells": [1]}\n');
      await ok(['commit', '-q', '-am', 'two']);
      // A commit with a (bogus) signature: showing it with log.showSignature runs gpg.program.
      final tree = await ok(['write-tree']);
      final parent = await ok(['rev-parse', 'HEAD']);
      final ts = now.subtract(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000;
      final signed = await ok(
        ['hash-object', '-t', 'commit', '-w', '--stdin'],
        stdin:
            'tree $tree\nparent $parent\nauthor Me <me@x.test> $ts +0000\ncommitter Me <me@x.test> $ts +0000\n'
            'gpgsig -----BEGIN PGP SIGNATURE-----\n \n AAAA\n -----END PGP SIGNATURE-----\n\nsigned\n',
      );
      await ok(['update-ref', 'refs/heads/main', signed]);
    });
    tearDown(() => tmp.delete(recursive: true));

    Ctx ctx(GitExecutable g) => Ctx(config: {'path': repo}, ids: {'email': ['me@x.test']}, git: g, now: now);

    test('the fixture is armed: plain git log / show do run the repo\'s commands', () async {
      await ok(['log', '-1', '--format=%H']);
      expect(File(marker).existsSync(), isTrue, reason: 'gpg.program ran for the signed commit');
      File(marker).deleteSync();
      await ok(['show', 'HEAD~1']);
      expect(File(marker).existsSync(), isTrue, reason: 'textconv / external diff ran');
    });

    test('a full capture through ProcessGitExecutable never creates the marker', () async {
      final out = await GitRepoSource().sync(ctx(ProcessGitExecutable())).toList();
      expect(out, hasLength(3));
      expect(File(marker).existsSync(), isFalse, reason: File(marker).existsSync() ? File(marker).readAsStringSync() : '');
      // Patches are still captured, as plain git diffs.
      final two = out.firstWhere((o) => o.title.contains('two'));
      expect(jsonEncode(two.content), contains('cells'));
    });

    test('argv: every call has -c log.showSignature=false; log and show pass --no-textconv --no-ext-diff', () async {
      // A wrapper `git` first on PATH that records its argv, then runs the real git.
      final realGit = GitDetector().detect()!;
      final bin = Directory(p.join(tmp.path, 'bin'))..createSync();
      final argvLog = p.join(tmp.path, 'argv');
      final wrapper = p.join(bin.path, 'git');
      File(wrapper).writeAsStringSync(
        '#!/bin/sh\nfor a in "\$@"; do printf "%s\\037" "\$a" >> "$argvLog"; done\necho >> "$argvLog"\n'
        'exec "$realGit" "\$@"\n',
      );
      await Process.run('chmod', ['+x', wrapper]);
      final g = ProcessGitExecutable(detector: GitDetector(os: 'linux', env: {'PATH': bin.path}));
      expect(await g.locate(), wrapper);

      final src = GitRepoSource();
      expect((await src.validate(ctx(g))).ok, isTrue);
      await src.sync(ctx(g)).toList();
      final calls = [
        for (final line in File(argvLog).readAsLinesSync())
          if (line.isNotEmpty) line.split('\x1f')..removeLast(),
      ];
      expect(calls.length, greaterThanOrEqualTo(5)); // rev-parse, log, 3× show
      for (final a in calls) {
        expect(a.sublist(0, 4), ['-C', repo, '-c', 'log.showSignature=false'], reason: '$a');
      }
      final logs = calls.where((a) => a[4] == 'log').toList();
      final shows = calls.where((a) => a[4] == 'show').toList();
      expect(logs, hasLength(1));
      expect(shows, hasLength(3));
      for (final a in [...logs, ...shows]) {
        expect(a, containsAll(['--no-textconv', '--no-ext-diff']), reason: '$a');
        expect(a, isNot(contains('--textconv')));
        expect(a, isNot(contains('--ext-diff')));
      }
      expect(File(marker).existsSync(), isFalse);
    });
  }, skip: GitDetector().detect() == null ? 'git not installed' : false);
}
