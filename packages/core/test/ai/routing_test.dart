import 'package:core/core.dart';
import 'package:core/src/ai/clients/openai_compatible.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:test/test.dart';

import 'fake_server.dart';

class MemorySecrets implements SecretStore {
  final Map<String, String> values = {};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> delete(String key) async => values.remove(key);
}

FakeResponse sseJson(String text) => FakeResponse.sse([
  {
    'choices': [
      {
        'delta': {'content': text},
      },
    ],
  },
  'data: [DONE]',
]);

void main() {
  late FakeServer server;
  setUp(() async => server = await FakeServer.start());
  tearDown(() => server.close());

  group('requiresConsent', () {
    test('loopback needs no consent', () {
      expect(requiresConsent('http://localhost:11434'), false);
      expect(requiresConsent('http://127.0.0.1:1234/v1'), false);
      expect(requiresConsent('http://127.4.5.6'), false);
      expect(requiresConsent('http://[::1]:8080'), false);
    });
    test('LAN and remote need consent', () {
      expect(requiresConsent('http://192.168.1.20:11434'), true);
      expect(requiresConsent('http://gpu-box.local:1234'), true);
      expect(requiresConsent('https://openrouter.ai/api/v1'), true);
    });
  });

  group('probeModel', () {
    OpenAiCompatibleClient client() => OpenAiCompatibleClient(baseUrl: server.url);

    test('accepts valid JSON', () async {
      server.routes['/chat/completions'] = sseJson('{"ok":true}');
      final info = await probeModel(client(), 'm', info: const ModelInfo(name: 'm', vision: true));
      expect(info.vision, true);
      expect(
        (server.last.json['response_format'] as Map)['json_schema'],
        containsPair('schema', structuredOutputProbeSchema),
      );
    });

    test('rejects non-JSON output', () async {
      server.routes['/chat/completions'] = sseJson('Sure! ok is true.');
      await expectLater(probeModel(client(), 'm'), throwsA(isA<LlmFailure>()));
    });

    test('rejects an endpoint that refuses response_format', () async {
      server.routes['/chat/completions'] = FakeResponse.json({
        'error': {'message': 'response_format not supported'},
      }, status: 400);
      await expectLater(probeModel(client(), 'm'), throwsA(isA<LlmFailure>()));
    });
  });

  group('DbModelRouter', () {
    late AppDb appDb;
    late ProfileDb profileDb;
    late MemorySecrets secrets;
    late DbModelRouter router;

    setUp(() async {
      appDb = AppDb(NativeDatabase.memory());
      profileDb = ProfileDb(NativeDatabase.memory());
      secrets = MemorySecrets()..values.addAll({'key/p1': 'sekret', 'hdr/p1': 'hv'});
      router = DbModelRouter(appDb: appDb, profileDb: profileDb, secrets: secrets);
      await appDb
          .into(appDb.providers)
          .insert(
            ProvidersCompanion.insert(
              id: 'p1',
              kind: ProviderKind.custom,
              name: 'Local',
              baseUrl: server.url,
              protocol: ProviderProtocol.openai,
              credentialRef: const Value('key/p1'),
              headers: const Value('{"x-team":"hdr/p1"}'),
            ),
          );
      for (final (id, vision) in [('m-default', false), ('m-vision', true)]) {
        await appDb
            .into(appDb.models)
            .insert(ModelsCompanion.insert(id: id, providerId: 'p1', modelName: '$id-name', vision: Value(vision)));
      }
    });
    tearDown(() async {
      await appDb.close();
      await profileDb.close();
    });

    Future<void> setRoute(LlmRoute route, String? modelId) => profileDb
        .into(profileDb.taskRoutes)
        .insertOnConflictUpdate(TaskRoutesCompanion.insert(route: route, modelId: Value(modelId)));

    test('fails clearly without a default model', () async {
      await expectLater(
        router.resolve(LlmRoute.extraction),
        throwsA(isA<LlmFailure>().having((f) => f.message, 'msg', contains('No default model'))),
      );
    });

    test('unset routes inherit default; overrides win', () async {
      await setRoute(LlmRoute.defaultRoute, 'm-default');
      await setRoute(LlmRoute.vision, 'm-vision');
      await setRoute(LlmRoute.reports, null);
      expect((await router.resolve(LlmRoute.extraction)).modelName, 'm-default-name');
      expect((await router.resolve(LlmRoute.reports)).modelName, 'm-default-name');
      final vision = await router.resolve(LlmRoute.vision);
      expect(vision.modelName, 'm-vision-name');
      expect(vision.info.vision, true);
    });

    test('client carries the API key and header values from the SecretStore', () async {
      await setRoute(LlmRoute.defaultRoute, 'm-default');
      server.routes['/chat/completions'] = sseJson('{"x":1}');
      final out = await StructuredOutput(router)(
        LlmRoute.reports,
        system: 's',
        user: 'u',
        schema: const {'type': 'object'},
      );
      expect(out, {'x': 1});
      expect(server.last.headers.value('authorization'), 'Bearer sekret');
      expect(server.last.headers.value('x-team'), 'hv');
      expect(server.last.json['model'], 'm-default-name');
    });
  });
}
