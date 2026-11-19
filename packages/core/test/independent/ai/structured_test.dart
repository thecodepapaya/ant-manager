import 'package:core/core.dart';
import 'package:core/src/ai/clients/ollama.dart';
import 'package:core/src/ai/clients/openai_compatible.dart';
import 'package:core/src/ai/structured.dart';
import 'package:test/test.dart';

import 'stub_http.dart';

const schema = <String, Object?>{
  'type': 'object',
  'properties': {
    'name': {'type': 'string'},
    'count': {'type': 'integer'},
    'score': {'type': 'number'},
    'tags': {
      'type': 'array',
      'items': {'type': 'string'},
    },
    'level': {
      'enum': ['low', 'high'],
    },
    'note': {
      'type': ['string', 'null'],
    },
    'inner': {
      'type': 'object',
      'properties': {
        'ok': {'type': 'boolean'},
      },
      'required': ['ok'],
    },
  },
  'required': ['name'],
};

Matcher failsWith([String? fragment]) =>
    throwsA(isA<LlmFailure>().having((f) => f.message, 'message', fragment == null ? anything : contains(fragment)));

class StaticRouter implements ModelRouter {
  StaticRouter(this.client);
  final LlmClient client;
  @override
  Future<ResolvedModel> resolve(LlmRoute route) async => ResolvedModel(
    client: client,
    modelName: 'm',
    info: const ModelInfo(name: 'm'),
  );
}

Reply openAiText(String text) => sse([
  {
    'choices': [
      {
        'delta': {'content': text},
        'finish_reason': 'stop',
      },
    ],
  },
  'data: [DONE]',
]);

void main() {
  group('parseStructured', () {
    test('valid object passes and is returned', () {
      expect(parseStructured('{"name":"a","count":2,"tags":["x"]}', schema), {
        'name': 'a',
        'count': 2,
        'tags': ['x'],
      });
    });

    test('invalid JSON → LlmFailure', () {
      expect(() => parseStructured('{"name":', schema), failsWith('invalid JSON'));
      expect(() => parseStructured('Sure! Here you go', schema), failsWith());
      expect(() => parseStructured('', schema), failsWith());
    });

    test('non-object JSON → LlmFailure', () {
      for (final t in ['[1,2]', '"text"', '42', 'null', 'true']) {
        expect(() => parseStructured(t, schema), failsWith('non-object'), reason: t);
      }
    });

    test('missing required field → LlmFailure', () {
      expect(() => parseStructured('{"count":1}', schema), failsWith('name'));
      expect(() => parseStructured('{"name":"a","inner":{}}', schema), failsWith('ok'));
    });

    test('wrong primitive type → LlmFailure', () {
      expect(() => parseStructured('{"name":5}', schema), failsWith());
      expect(() => parseStructured('{"name":"a","count":"2"}', schema), failsWith());
      expect(() => parseStructured('{"name":"a","score":"1.5"}', schema), failsWith());
      expect(() => parseStructured('{"name":"a","inner":{"ok":"yes"}}', schema), failsWith());
      expect(() => parseStructured('{"name":"a","tags":"x"}', schema), failsWith());
    });

    test('wrong array item type → LlmFailure', () {
      expect(() => parseStructured('{"name":"a","tags":["x",3]}', schema), failsWith('tags'));
    });

    test('enum mismatch → LlmFailure', () {
      expect(parseStructured('{"name":"a","level":"low"}', schema)['level'], 'low');
      expect(() => parseStructured('{"name":"a","level":"medium"}', schema), failsWith());
    });

    test('integer accepts 1.0 but not 1.5; number accepts both', () {
      expect(parseStructured('{"name":"a","count":1.0}', schema)['count'], 1.0);
      expect(() => parseStructured('{"name":"a","count":1.5}', schema), failsWith());
      expect(parseStructured('{"name":"a","score":3}', schema)['score'], 3);
      expect(parseStructured('{"name":"a","score":3.25}', schema)['score'], 3.25);
    });

    test('type lists allow any listed type', () {
      expect(parseStructured('{"name":"a","note":null}', schema)['note'], isNull);
      expect(parseStructured('{"name":"a","note":"n"}', schema)['note'], 'n');
      expect(() => parseStructured('{"name":"a","note":1}', schema), failsWith());
    });
  });

  group('schemaError', () {
    test('returns null on a match and a path on a mismatch', () {
      expect(schemaError({'name': 'x'}, schema), isNull);
      expect(
        schemaError({
          'name': 'x',
          'tags': ['a', 1],
        }, schema),
        contains('tags[1]'),
      );
      expect(schemaError([1], const {'type': 'object'}), isNotNull);
    });
  });

  group('StructuredOutput', () {
    late StubHttp http;
    setUp(() async => http = await StubHttp.start());
    tearDown(() => http.close());

    StructuredOutput out() => StructuredOutput(StaticRouter(OpenAiCompatibleClient(baseUrl: http.url)));
    Future<Map<String, Object?>> run() => out()(LlmRoute.extraction, system: 's', user: 'u', schema: schema);

    test('returns the parsed object and streams deltas', () async {
      http.on['/chat/completions'] = openAiText('{"name":"a"}');
      final deltas = <String>[];
      final r = await out()(LlmRoute.extraction, system: 's', user: 'u', schema: schema, onDelta: deltas.add);
      expect(r, {'name': 'a'});
      expect(deltas.join(), '{"name":"a"}');
    });

    test('invalid JSON from the model → LlmFailure', () async {
      http.on['/chat/completions'] = openAiText('not json');
      await expectLater(run(), failsWith());
    });

    test('non-object JSON from the model → LlmFailure', () async {
      http.on['/chat/completions'] = openAiText('[1]');
      await expectLater(run(), failsWith());
    });

    test('schema mismatch → LlmFailure', () async {
      http.on['/chat/completions'] = openAiText('{"name":"a","count":"x"}');
      await expectLater(run(), failsWith('schema'));
    });

    test('unexpected chunk shapes surface as LlmFailure, not TypeError', () async {
      http.on['/chat/completions'] = sse([
        {'choices': 'oops'},
        'data: [DONE]',
      ]);
      await expectLater(run(), failsWith());
      http.on['/chat/completions'] = sse([
        {
          'choices': [
            {'delta': 'not a map'},
          ],
        },
        'data: [DONE]',
      ]);
      await expectLater(run(), failsWith());
    });

    test('SSE payload that is JSON but not an object → LlmFailure', () async {
      http.on['/chat/completions'] = sse(['data: [1,2,3]', 'data: [DONE]']);
      await expectLater(run(), failsWith());
      http.on['/chat/completions'] = sse(['data: "hello"', 'data: [DONE]']);
      await expectLater(run(), failsWith());
      http.on['/chat/completions'] = sse(['data: {broken', 'data: [DONE]']);
      await expectLater(run(), failsWith());
    });

    test('NDJSON line that is not an object → LlmFailure', () async {
      final o = StructuredOutput(StaticRouter(OllamaClient(baseUrl: http.url)));
      http.on['/api/chat'] = ndjson([
        '[1,2]',
        {
          'message': {'content': '{"name":"a"}'},
          'done': true,
          'done_reason': 'stop',
        },
      ]);
      await expectLater(o(LlmRoute.extraction, system: 's', user: 'u', schema: schema), failsWith());
      http.on['/api/chat'] = ndjson(['42']);
      await expectLater(o(LlmRoute.extraction, system: 's', user: 'u', schema: schema), failsWith());
    });

    test('router failure propagates as LlmFailure', () async {
      final o = StructuredOutput(_FailingRouter());
      await expectLater(o(LlmRoute.reports, system: 's', user: 'u', schema: schema), failsWith('nope'));
    });
  });
}

class _FailingRouter implements ModelRouter {
  @override
  Future<ResolvedModel> resolve(LlmRoute route) async => throw LlmFailure('nope');
}
