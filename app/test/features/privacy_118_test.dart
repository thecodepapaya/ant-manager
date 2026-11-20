/// Independent tests (#99) for DECISIONS #118 at the command level: provider consent is enforced when the
/// client is built (Test connection, model probe, routing), and restore clears source secrets until the
/// source is saved with a new one. Run known bugs with `--dart-define=RUN_BUGS=true`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:ant_manager/engine/commands.dart';
import 'package:ant_manager/engine/engine_handle.dart';
import 'package:ant_manager/engine/messages.dart';
import 'package:ant_manager/engine/setup_commands.dart';
import 'package:core/core.dart' hide Provider;
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

const bugSkip = !bool.fromEnvironment('RUN_BUGS');

EngineCommand<String> _resolveCmd(LlmRoute route) => (rt) async => (await rt.engine.router.resolve(route)).modelName;

/// A fake OpenAI-compatible server on every IPv4 interface, reached through this machine's LAN address: a
/// non-loopback URL that really works, so a missing request is the consent check, not an unreachable host.
class LanLlm {
  LanLlm._(this._server, this.ip);
  final HttpServer _server;
  final String? ip;
  final paths = <String>[];

  static Future<LanLlm> start() async {
    final s = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    String? ip;
    for (final i in await NetworkInterface.list(type: InternetAddressType.IPv4)) {
      for (final a in i.addresses) {
        if (!a.isLoopback && !a.isLinkLocal) ip ??= a.address;
      }
    }
    final llm = LanLlm._(s, ip);
    s.listen((req) async {
      llm.paths.add(req.uri.path);
      await req.drain<void>();
      req.response.headers.contentType = ContentType.json;
      req.response.write(jsonEncode({
        'data': [
          {'id': 'm-text'},
        ],
      }));
      await req.response.close();
    });
    return llm;
  }

  String url(String prefix) => 'http://$ip:${_server.port}/$prefix';
  Future<void> close() => _server.close(force: true);
}

Matcher _noConsent() => throwsA(isA<EngineCommandException>().having((e) => e.message, 'message', contains('consent')));

void main() {
  late Directory dir;
  late EngineHandle h;
  late FakeSecrets secrets;
  setUp(() {
    dir = tempDir();
    secrets = FakeSecrets();
  });
  tearDown(() => dir.deleteSync(recursive: true));

  group('provider consent at request time', () {
    late LanLlm llm;
    setUp(() async {
      llm = await LanLlm.start();
      addTearDown(llm.close);
      h = await startEngine(dir, secrets: secrets);
      addTearDown(h.shutdown);
    });

    Future<String> save(String baseUrl, {String? id}) async => (await h.runtime(saveProviderCmd(
          id: id,
          kind: ProviderKind.custom,
          name: 'LAN box',
          baseUrl: baseUrl,
          protocol: ProviderProtocol.openai,
        )))
            .$1;

    test('a new non-loopback provider: Test connection and Add model fail and send nothing', () async {
      final pid = await save('https://llm.invalid/v1');
      await expectLater(h.runtime(listProviderModelsCmd(pid)), _noConsent());
      await expectLater(h.runtime(addModelCmd(pid, 'm-text')), _noConsent());
      expect(await h.appDb.select(h.appDb.models).get(), isEmpty);
    });

    test('URL edited after consent and the notice declined: Test connection and routing fail, no request',
        () async {
      if (llm.ip == null) return markTestSkipped('no LAN interface');
      final pid = await save(llm.url('v1'));
      await h.runtime(setProviderConsentCmd(pid));
      expect((await h.runtime(listProviderModelsCmd(pid))).map((m) => m.name), ['m-text']);
      final mid = await h.runtime(_addModelNoProbeCmd(pid, 'm-text'));
      expect(await h.runtime(_resolveCmd(LlmRoute.defaultRoute)), 'm-text');
      expect(llm.paths, ['/v1/models'], reason: 'the LAN URL really reaches the fake');
      llm.paths.clear();

      // Edit the URL (same host, new path): consent resets; the user doesn't agree again.
      final (_, consent) = await h.runtime(saveProviderCmd(
        id: pid,
        kind: ProviderKind.custom,
        name: 'LAN box',
        baseUrl: llm.url('v2'),
        protocol: ProviderProtocol.openai,
      ));
      expect(consent, isFalse);
      await expectLater(h.runtime(listProviderModelsCmd(pid)), _noConsent());
      await expectLater(h.runtime(_resolveCmd(LlmRoute.defaultRoute)), _noConsent());
      await expectLater(h.runtime(_resolveCmd(LlmRoute.extraction)), _noConsent());
      await expectLater(h.runtime(_resolveCmd(LlmRoute.vision)), _noConsent());
      await expectLater(h.runtime(addModelCmd(pid, 'm-text')), _noConsent());
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(llm.paths, isEmpty);
      expect(mid, isNotEmpty);

      // Agreeing again makes it work.
      await h.runtime(setProviderConsentCmd(pid));
      await h.runtime(listProviderModelsCmd(pid));
      expect(llm.paths, ['/v2/models']);
    });

    test('loopback providers never need consent', () async {
      final fake = await FakeLlm.start();
      addTearDown(fake.close);
      final pid = await save(fake.baseUrl);
      expect(await h.runtime(listProviderModelsCmd(pid)), isNotEmpty);
    });
  });

  group('restore clears source secrets', () {
    late String ghId, repoId, lin;
    setUp(() async {
      h = await startEngine(dir, secrets: secrets, inMemory: false);
      ghId = await h.runtime(addSourceCmd(SourceKind.github, 'GitHub', const {'login': 'me'}, secret: 'ghp_ORIGINAL'));
      lin = await h.runtime(addSourceCmd(SourceKind.linear, 'Linear', const {}, secret: 'lin_ORIGINAL'));
      repoId = await h.runtime(addSourceCmd(SourceKind.gitRepo, 'repo', const {'path': '/tmp/nowhere'}));
    });

    /// Backs up, restores, and restarts the engine on the restored profile.
    Future<String> restoreAndSwitch() async {
      final file = await h.runtime(backupNowCmd());
      final id = await h.runtime(restoreBackupCmd(file));
      await h.runtime(setActiveProfileCmd(id));
      await h.shutdown();
      h = await startEngine(dir, secrets: secrets, inMemory: false);
      addTearDown(h.shutdown);
      expect(h.profileId, id);
      return id;
    }

    Future<Map<String, SourceRow>> rows() async => {for (final s in await h.db.select(h.db.sources).get()) s.id: s};

    test('sources that had a secret are disabled with no ref; others unchanged', () async {
      await restoreAndSwitch();
      final r = await rows();
      for (final id in [ghId, lin]) {
        expect((r[id]!.enabled, r[id]!.credentialRef), (false, null), reason: r[id]!.name);
      }
      expect((r[repoId]!.enabled, r[repoId]!.credentialRef), (true, null));
    });

    test('saving the source with a new secret re-enables it and stores the new secret', () async {
      await restoreAndSwitch();
      // What the source form sends on save.
      await h.runtime(updateSourceCmd(ghId, name: 'GitHub', config: const {'login': 'me'}, secret: 'ghp_NEW', enabled: true));
      final gh = (await rows())[ghId]!;
      expect(gh.enabled, isTrue);
      expect(gh.credentialRef, isNotNull);
      expect(secrets.values[gh.credentialRef!], 'ghp_NEW');
      // Untouched: the other restored source stays signed out.
      expect(((await rows())[lin]!.enabled, (await rows())[lin]!.credentialRef), (false, null));
    });

    test("signing in again in the restored profile leaves the original profile's secret alone", () async {
      final originalRef = (await rows())[ghId]!.credentialRef!;
      await restoreAndSwitch();
      await h.runtime(updateSourceCmd(ghId, name: 'GitHub', config: const {'login': 'me'}, secret: 'ghp_NEW', enabled: true));
      final newRef = (await rows())[ghId]!.credentialRef!;
      // The restored source keeps the original's id, so `source:<id>` is the same keychain item (BUG #118):
      // the original profile's GitHub source now syncs with the restored profile's token.
      expect(newRef, isNot(originalRef));
      expect(secrets.values[originalRef], 'ghp_ORIGINAL');
    }, skip: bugSkip);
  });
}

/// Stores a model row without the structured-output probe (the fake only serves /models).
EngineCommand<String> _addModelNoProbeCmd(String providerId, String name) => (rt) async {
      final id = 'model-$name';
      await rt.appDb.into(rt.appDb.models).insert(ModelsCompanion.insert(id: id, providerId: providerId, modelName: name));
      await rt.db.into(rt.db.taskRoutes).insertOnConflictUpdate(
            TaskRoutesCompanion.insert(route: LlmRoute.defaultRoute, modelId: Value(id)),
          );
      return id;
    };
