import 'package:core/core.dart';
import 'package:core/src/ai/clients/anthropic.dart';
import 'package:core/src/ai/clients/gemini.dart';
import 'package:core/src/ai/clients/ollama.dart';
import 'package:core/src/ai/clients/openai_compatible.dart';
import 'package:test/test.dart';

import 'fake_server.dart';

const schema = <String, Object?>{
  'type': 'object',
  'properties': {
    'a': {'type': 'integer'},
  },
  'required': ['a'],
  'additionalProperties': false,
};

const request = LlmRequest(
  model: 'm1',
  schema: schema,
  schemaName: 'thing',
  maxTokens: 100,
  temperature: 0.5,
  messages: [
    LlmMessage.system('sys'),
    LlmMessage.user(
      'hi',
      images: [LlmImage(mime: 'image/png', base64: 'AAAA')],
    ),
  ],
);

Future<(String, LlmDone)> collect(Stream<LlmEvent> s) async {
  final deltas = StringBuffer();
  LlmDone? done;
  await for (final e in s) {
    switch (e) {
      case LlmDelta(:final text):
        deltas.write(text);
      case LlmDone():
        expect(done, isNull, reason: 'exactly one LlmDone');
        done = e;
    }
  }
  return (deltas.toString(), done!);
}

void main() {
  late FakeServer server;
  setUp(() async => server = await FakeServer.start());
  tearDown(() => server.close());

  group('OpenAI-compatible', () {
    OpenAiCompatibleClient client() =>
        OpenAiCompatibleClient(baseUrl: '${server.url}/v1', apiKey: 'k', headers: {'x-extra': 'e'});

    test('request shape and SSE parse', () async {
      server.routes['/v1/chat/completions'] = FakeResponse.sse([
        ': OPENROUTER PROCESSING',
        {
          'choices': [
            {
              'delta': {'role': 'assistant', 'content': '{"a":'},
            },
          ],
        },
        {
          'choices': [
            {
              'delta': {'content': '1}'},
              'finish_reason': 'stop',
            },
          ],
        },
        {
          'choices': <Object>[],
          'usage': {'prompt_tokens': 7, 'completion_tokens': 3},
        },
        'data: [DONE]',
      ]);
      final (deltas, done) = await collect(client().generate(request));
      expect(deltas, '{"a":1}');
      expect(done.text, '{"a":1}');
      expect(done.inputTokens, 7);
      expect(done.outputTokens, 3);

      final r = server.last;
      expect(r.headers.value('authorization'), 'Bearer k');
      expect(r.headers.value('x-extra'), 'e');
      final body = r.json;
      expect(body['model'], 'm1');
      expect(body['stream'], true);
      expect(body['max_tokens'], 100);
      expect(body['response_format'], {
        'type': 'json_schema',
        'json_schema': {'name': 'thing', 'schema': schema, 'strict': true},
      });
      final messages = body['messages'] as List;
      expect(messages[0], {'role': 'system', 'content': 'sys'});
      expect(messages[1], {
        'role': 'user',
        'content': [
          {'type': 'text', 'text': 'hi'},
          {
            'type': 'image_url',
            'image_url': {'url': 'data:image/png;base64,AAAA'},
          },
        ],
      });
    });

    test('listModels parses OpenRouter metadata and drops models without structured output', () async {
      server.routes['/v1/models'] = FakeResponse.json({
        'data': [
          {
            'id': 'google/flash',
            'context_length': 1000000,
            'pricing': {'prompt': '0.0000001', 'completion': '0.0000004'},
            'architecture': {
              'input_modalities': ['text', 'image'],
            },
            'supported_parameters': ['structured_outputs', 'response_format'],
          },
          {
            'id': 'old/model',
            'supported_parameters': ['temperature'],
          },
        ],
      });
      final models = await client().listModels();
      expect(models.map((m) => m.name), ['google/flash']);
      expect(models.single.vision, true);
      expect(models.single.contextLength, 1000000);
      expect(models.single.inputPricePerMTok, closeTo(0.1, 1e-9));
      expect(models.single.outputPricePerMTok, closeTo(0.4, 1e-9));
    });

    test('listModels keeps plain servers that report ids only', () async {
      server.routes['/v1/models'] = FakeResponse.json({
        'data': [
          {'id': 'qwen2.5-7b', 'object': 'model'},
        ],
      });
      final models = await client().listModels();
      expect(models.single.name, 'qwen2.5-7b');
      expect(models.single.vision, false);
    });

    test('HTTP errors become LlmFailure with status and message', () async {
      server.routes['/v1/chat/completions'] = FakeResponse.json({
        'error': {'message': 'bad key'},
      }, status: 401);
      await expectLater(
        client().generate(request).drain<void>(),
        throwsA(
          isA<LlmFailure>().having((f) => f.statusCode, 'status', 401).having((f) => f.message, 'msg', 'bad key'),
        ),
      );
    });

    test('mid-stream error chunk throws', () async {
      server.routes['/v1/chat/completions'] = FakeResponse.sse([
        {
          'error': {'message': 'upstream failed'},
        },
      ]);
      await expectLater(client().generate(request).drain<void>(), throwsA(isA<LlmFailure>()));
    });

    test('truncated output throws', () async {
      server.routes['/v1/chat/completions'] = FakeResponse.sse([
        {
          'choices': [
            {
              'delta': {'content': '{"a"'},
              'finish_reason': 'length',
            },
          ],
        },
      ]);
      await expectLater(client().generate(request).drain<void>(), throwsA(isA<LlmFailure>()));
    });
  });

  group('Ollama', () {
    OllamaClient client() => OllamaClient(baseUrl: server.url);

    test('request shape and NDJSON parse', () async {
      server.routes['/api/chat'] = FakeResponse.ndjson([
        {
          'message': {'role': 'assistant', 'content': '{"a":'},
          'done': false,
        },
        {
          'message': {'role': 'assistant', 'content': '2}'},
          'done': false,
        },
        {
          'message': {'role': 'assistant', 'content': ''},
          'done': true,
          'done_reason': 'stop',
          'prompt_eval_count': 5,
          'eval_count': 4,
        },
      ]);
      final (deltas, done) = await collect(client().generate(request));
      expect(deltas, '{"a":2}');
      expect(done.text, '{"a":2}');
      expect(done.inputTokens, 5);
      expect(done.outputTokens, 4);

      final body = server.last.json;
      expect(server.last.headers.value('authorization'), isNull);
      expect(body['format'], schema);
      expect(body['stream'], true);
      expect(body['options'], {'temperature': 0.5, 'num_predict': 100});
      expect((body['messages'] as List)[1], {
        'role': 'user',
        'content': 'hi',
        'images': ['AAAA'],
      });
    });

    test('listModels from /api/tags', () async {
      server.routes['/api/tags'] = FakeResponse.json({
        'models': [
          {'name': 'llama3.2:latest'},
          {'name': 'qwen2.5vl:7b'},
        ],
      });
      expect((await client().listModels()).map((m) => m.name), ['llama3.2:latest', 'qwen2.5vl:7b']);
    });

    test('error line throws', () async {
      server.routes['/api/chat'] = FakeResponse.ndjson([
        {'error': 'model not found'},
      ]);
      await expectLater(
        client().generate(request).drain<void>(),
        throwsA(isA<LlmFailure>().having((f) => f.message, 'msg', 'model not found')),
      );
    });
  });

  group('Anthropic', () {
    AnthropicClient client() => AnthropicClient(baseUrl: server.url, apiKey: 'ak');

    test('forced tool request shape and SSE parse', () async {
      server.routes['/v1/messages'] = FakeResponse.sse([
        'event: message_start\ndata: {"type":"message_start","message":{"usage":{"input_tokens":11}}}',
        {
          'type': 'content_block_start',
          'index': 0,
          'content_block': {'type': 'tool_use', 'name': 'thing', 'input': <String, Object?>{}},
        },
        {
          'type': 'content_block_delta',
          'index': 0,
          'delta': {'type': 'input_json_delta', 'partial_json': '{"a"'},
        },
        {
          'type': 'content_block_delta',
          'index': 0,
          'delta': {'type': 'input_json_delta', 'partial_json': ':3}'},
        },
        {'type': 'content_block_stop', 'index': 0},
        {
          'type': 'message_delta',
          'delta': {'stop_reason': 'tool_use'},
          'usage': {'output_tokens': 6},
        },
        {'type': 'message_stop'},
      ]);
      final (deltas, done) = await collect(client().generate(request));
      expect(deltas, '{"a":3}');
      expect(done.text, '{"a":3}');
      expect(done.inputTokens, 11);
      expect(done.outputTokens, 6);

      final r = server.last;
      expect(r.headers.value('x-api-key'), 'ak');
      expect(r.headers.value('anthropic-version'), '2023-06-01');
      final body = r.json;
      expect(body['system'], 'sys');
      expect(body['max_tokens'], 100);
      expect(body['tool_choice'], {'type': 'tool', 'name': 'thing'});
      expect(((body['tools'] as List).single as Map)['input_schema'], schema);
      expect((body['messages'] as List).single, {
        'role': 'user',
        'content': [
          {
            'type': 'image',
            'source': {'type': 'base64', 'media_type': 'image/png', 'data': 'AAAA'},
          },
          {'type': 'text', 'text': 'hi'},
        ],
      });
    });

    test('error event throws', () async {
      server.routes['/v1/messages'] = FakeResponse.sse([
        {
          'type': 'error',
          'error': {'type': 'overloaded_error', 'message': 'Overloaded'},
        },
      ]);
      await expectLater(
        client().generate(request).drain<void>(),
        throwsA(isA<LlmFailure>().having((f) => f.message, 'msg', 'Overloaded')),
      );
    });

    test('listModels', () async {
      server.routes['/v1/models'] = FakeResponse.json({
        'data': [
          {'id': 'claude-x', 'display_name': 'Claude X'},
        ],
      });
      final models = await client().listModels();
      expect(models.single.name, 'claude-x');
      expect(models.single.vision, true);
    });
  });

  group('Gemini', () {
    GeminiClient client() => GeminiClient(baseUrl: server.url, apiKey: 'gk');

    test('request shape and SSE parse', () async {
      server.routes['/v1beta/models/m1:streamGenerateContent'] = FakeResponse.sse([
        {
          'candidates': [
            {
              'content': {
                'role': 'model',
                'parts': [
                  {'text': '{"a":'},
                ],
              },
            },
          ],
        },
        {
          'candidates': [
            {
              'content': {
                'role': 'model',
                'parts': [
                  {'text': '4}'},
                ],
              },
              'finishReason': 'STOP',
            },
          ],
          'usageMetadata': {'promptTokenCount': 9, 'candidatesTokenCount': 2},
        },
      ]);
      final (deltas, done) = await collect(client().generate(request));
      expect(deltas, '{"a":4}');
      expect(done.text, '{"a":4}');
      expect(done.inputTokens, 9);
      expect(done.outputTokens, 2);

      final r = server.last;
      expect(r.uri.queryParameters['alt'], 'sse');
      expect(r.headers.value('x-goog-api-key'), 'gk');
      final body = r.json;
      expect(body['systemInstruction'], {
        'parts': [
          {'text': 'sys'},
        ],
      });
      expect(body['generationConfig'], {
        'responseMimeType': 'application/json',
        'responseJsonSchema': schema,
        'temperature': 0.5,
        'maxOutputTokens': 100,
      });
      expect((body['contents'] as List).single, {
        'role': 'user',
        'parts': [
          {
            'inlineData': {'mimeType': 'image/png', 'data': 'AAAA'},
          },
          {'text': 'hi'},
        ],
      });
    });

    test('listModels keeps generateContent models and strips the prefix', () async {
      server.routes['/v1beta/models'] = FakeResponse.json({
        'models': [
          {
            'name': 'models/gemini-flash',
            'inputTokenLimit': 1048576,
            'supportedGenerationMethods': ['generateContent', 'countTokens'],
          },
          {
            'name': 'models/embedding',
            'supportedGenerationMethods': ['embedContent'],
          },
        ],
      });
      final models = await client().listModels();
      expect(models.single.name, 'gemini-flash');
      expect(models.single.contextLength, 1048576);
    });
  });
}
