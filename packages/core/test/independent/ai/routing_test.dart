import 'package:core/core.dart';
import 'package:core/src/ai/clients/openai_compatible.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:test/test.dart';

import 'stub_http.dart';

class Secrets implements SecretStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> delete(String key) async => values.remove(key);
}

Reply answer(String text) => sse([
  {
    'choices': [
      {
        'delta': {'content': text},
        'finish_reason': 'stop',
      },
    ],
  },
]);

Matcher fails([String? fragment]) =>
    throwsA(isA<LlmFailure>().having((f) => f.message, 'message', fragment == null ? anything : contains(fragment)));

void main() {
  late StubHttp http;
  setUp(() async => http = await StubHttp.start());
  tearDown(() => http.close());

  group('requiresConsent', () {
    test('false only for localhost / loopback', () {
      for (final u in [
        'http://localhost:11434',
        'http://LOCALHOST:1234/v1',
        'http://127.0.0.1:1234/v1',
        'http://127.9.8.7',
        'https://127.0.0.1',
        'http://[::1]:8080/v1',
      ]) {
        expect(requiresConsent(u), false, reason: u);
      }
    });
    test('true for LAN IPs, mDNS names and remote hosts', () {
      for (final u in [
        'http://192.168.1.20:11434',
        'http://10.0.0.5:8000/v1',
        'http://172.16.3.4',
        'http://[fe80::1]:1234',
        'http://gpu-box.local:1234',
        'http://localhost.example.com',
        'https://openrouter.ai/api/v1',
        'https://api.openai.com/v1',
      ]) {
        expect(requiresConsent(u), true, reason: u);
      }
    });
  });

  group('probeModel', () {
    OpenAiCompatibleClient client() => OpenAiCompatibleClient(baseUrl: http.url);

    test('accepts {"ok": bool} and sends the probe schema', () async {
      http.on['/chat/completions'] = answer('{"ok":false}');
      final info = await probeModel(client(), 'm');
      expect(info.name, 'm');
      final b = http.last.json;
      expect(((b['response_format'] as Map)['json_schema'] as Map)['schema'], structuredOutputProbeSchema);
    });

    test('returns the listing info when given', () async {
      http.on['/chat/completions'] = answer('{"ok":true}');
      final info = await probeModel(client(), 'm', info: const ModelInfo(name: 'm', contextLength: 99));
      expect(info.contextLength, 99);
    });

    test('rejects non-JSON, non-object and wrong-shape output', () async {
      for (final t in ['Sure, ok!', '', '[true]', '{"ok":"yes"}', '{}']) {
        http.on['/chat/completions'] = answer(t);
        await expectLater(probeModel(client(), 'm'), fails(), reason: t);
      }
    });

    test('rejects an endpoint error', () async {
      http.on['/chat/completions'] = json({'error': 'response_format unsupported'}, status: 400);
      await expectLater(probeModel(client(), 'm'), fails());
    });
  });

  group('DbModelRouter', () {
    late AppDb app;
    late ProfileDb profile;
    late Secrets secrets;
    late DbModelRouter router;

    Future<void> provider(String id, {String? cred, String headers = '{}', String name = 'Box'}) => app
        .into(app.providers)
        .insert(
          ProvidersCompanion.insert(
            id: id,
            kind: ProviderKind.custom,
            name: name,
            baseUrl: http.url,
            protocol: ProviderProtocol.openai,
            credentialRef: Value(cred),
            headers: Value(headers),
          ),
        );
    Future<void> model(String id, String providerId) =>
        app.into(app.models).insert(ModelsCompanion.insert(id: id, providerId: providerId, modelName: '$id-name'));
    Future<void> route(LlmRoute r, String? modelId) => profile
        .into(profile.taskRoutes)
        .insertOnConflictUpdate(TaskRoutesCompanion.insert(route: r, modelId: Value(modelId)));

    setUp(() async {
      app = AppDb(NativeDatabase.memory());
      profile = ProfileDb(NativeDatabase.memory());
      secrets = Secrets();
      router = DbModelRouter(appDb: app, profileDb: profile, secrets: secrets);
    });
    tearDown(() async {
      await app.close();
      await profile.close();
    });

    test('no routes at all → LlmFailure', () async {
      await expectLater(router.resolve(LlmRoute.defaultRoute), fails());
      await expectLater(router.resolve(LlmRoute.vision), fails());
    });

    test('override set but default missing: override works, others fail', () async {
      await provider('p');
      await model('x', 'p');
      await route(LlmRoute.reports, 'x');
      expect((await router.resolve(LlmRoute.reports)).modelName, 'x-name');
      await expectLater(router.resolve(LlmRoute.extraction), fails());
    });

    test('unset and null routes fall back to default', () async {
      await provider('p');
      await model('d', 'p');
      await model('v', 'p');
      await route(LlmRoute.defaultRoute, 'd');
      await route(LlmRoute.vision, 'v');
      await route(LlmRoute.extraction, null);
      expect((await router.resolve(LlmRoute.extraction)).modelName, 'd-name');
      expect((await router.resolve(LlmRoute.reports)).modelName, 'd-name');
      expect((await router.resolve(LlmRoute.vision)).modelName, 'v-name');
    });

    test('route pointing at a removed model → LlmFailure', () async {
      await route(LlmRoute.defaultRoute, 'ghost');
      await expectLater(router.resolve(LlmRoute.defaultRoute), fails());
    });

    test('missing API-key secret → LlmFailure naming the provider and credential', () async {
      await provider('p', cred: 'key/p', name: 'Home GPU');
      await model('d', 'p');
      await route(LlmRoute.defaultRoute, 'd');
      await expectLater(
        router.resolve(LlmRoute.defaultRoute),
        throwsA(isA<LlmFailure>().having((f) => f.message, 'm', allOf(contains('Home GPU'), contains('API key')))),
      );
    });

    test('missing header secret → LlmFailure naming the provider and header', () async {
      await provider('p', cred: 'key/p', headers: '{"x-tenant":"hdr/p"}', name: 'Gateway');
      secrets.values['key/p'] = 'k';
      await model('d', 'p');
      await route(LlmRoute.defaultRoute, 'd');
      await expectLater(
        router.resolve(LlmRoute.defaultRoute),
        throwsA(isA<LlmFailure>().having((f) => f.message, 'm', allOf(contains('Gateway'), contains('x-tenant')))),
      );
    });

    test('resolved client sends the key and header values', () async {
      await provider('p', cred: 'key/p', headers: '{"x-tenant":"hdr/p"}');
      secrets.values.addAll({'key/p': 'sekret', 'hdr/p': 'acme'});
      await model('d', 'p');
      await route(LlmRoute.defaultRoute, 'd');
      http.on['/chat/completions'] = answer('{"n":1}');
      final out = await StructuredOutput(router)(
        LlmRoute.vision,
        system: 's',
        user: 'u',
        schema: const {'type': 'object'},
      );
      expect(out, {'n': 1});
      expect(http.last.headers.value('authorization'), 'Bearer sekret');
      expect(http.last.headers.value('x-tenant'), 'acme');
      expect(http.last.json['model'], 'd-name');
    });

    test('provider without credential sends no auth header', () async {
      await provider('p');
      await model('d', 'p');
      await route(LlmRoute.defaultRoute, 'd');
      http.on['/chat/completions'] = answer('{}');
      await StructuredOutput(router)(LlmRoute.defaultRoute, system: 's', user: 'u', schema: const {'type': 'object'});
      expect(http.last.headers.value('authorization'), isNull);
    });
  });
}
