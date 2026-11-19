import 'package:core/core.dart';
import 'package:core/src/ai/clients/anthropic.dart';
import 'package:core/src/ai/clients/gemini.dart';
import 'package:core/src/ai/clients/ollama.dart';
import 'package:core/src/ai/clients/openai_compatible.dart';
import 'package:test/test.dart';

import 'stub_http.dart';

const _schema = <String, Object?>{
  'type': 'object',
  'properties': {
    'a': {'type': 'integer'},
  },
  'required': ['a'],
};

LlmRequest req(String model, {List<LlmImage> images = const []}) => LlmRequest(
  model: model,
  schema: _schema,
  schemaName: 'thing',
  maxTokens: 321,
  temperature: 0.3,
  messages: [
    const LlmMessage.system('SYS'),
    LlmMessage.user('USER', images: images),
  ],
);

const img = LlmImage(mime: 'image/png', base64: 'iVBORw0KGgo=');

Matcher fails([String? fragment]) =>
    throwsA(isA<LlmFailure>().having((f) => f.message, 'message', fragment == null ? anything : contains(fragment)));

Future<String> doneText(Stream<LlmEvent> s) async {
  final events = await s.toList();
  final done = events.whereType<LlmDone>().toList();
  expect(done, hasLength(1));
  expect(events.last, isA<LlmDone>());
  return done.single.text;
}

Map<String, Object?> oaChunk(String? content, {String? finish}) => {
  'choices': [
    {
      'delta': {'content': ?content},
      'finish_reason': finish,
    },
  ],
};

void main() {
  late StubHttp http;
  setUp(() async => http = await StubHttp.start());
  tearDown(() => http.close());

  group('OpenAI-compatible', () {
    OpenAiCompatibleClient client({ProviderKind kind = ProviderKind.custom, String? key, Map<String, String>? h}) =>
        OpenAiCompatibleClient(baseUrl: '${http.url}/v1/', apiKey: key, headers: h ?? const {}, kind: kind);
    const path = '/v1/chat/completions';

    test('request shape: json_schema strict, stream, auth, custom headers, images', () async {
      http.on[path] = sse([oaChunk('{"a":1}', finish: 'stop'), 'data: [DONE]']);
      expect(await doneText(client(key: 'k1', h: {'x-org': 'o'}).generate(req('gpt-4o', images: [img]))), '{"a":1}');
      final s = http.last;
      expect(s.method, 'POST');
      expect(s.headers.value('authorization'), 'Bearer k1');
      expect(s.headers.value('x-org'), 'o');
      final b = s.json;
      expect(b['model'], 'gpt-4o');
      expect(b['stream'], true);
      expect(b['response_format'], {
        'type': 'json_schema',
        'json_schema': {'name': 'thing', 'schema': _schema, 'strict': true},
      });
      expect(b['max_tokens'], 321);
      expect(b['temperature'], 0.3);
      final msgs = (b['messages'] as List).cast<Map>();
      expect(msgs[0], {'role': 'system', 'content': 'SYS'});
      expect(msgs[1]['role'], 'user');
      expect(msgs[1]['content'], [
        {'type': 'text', 'text': 'USER'},
        {
          'type': 'image_url',
          'image_url': {'url': 'data:image/png;base64,iVBORw0KGgo='},
        },
      ]);
    });

    test('no API key → no authorization header', () async {
      http.on[path] = sse([oaChunk('{"a":1}', finish: 'stop')]);
      await doneText(client().generate(req('m')));
      expect(http.last.headers.value('authorization'), isNull);
    });

    test('OpenAI reasoning models use max_completion_tokens and drop temperature', () async {
      http.on[path] = sse([oaChunk('{"a":1}', finish: 'stop'), 'data: [DONE]']);
      for (final m in ['o1', 'o1-mini', 'o3-mini', 'o4-mini', 'gpt-5', 'gpt-5-mini']) {
        await doneText(client(kind: ProviderKind.openai).generate(req(m)));
        final b = http.last.json;
        expect(b['max_completion_tokens'], 321, reason: m);
        expect(b.containsKey('max_tokens'), false, reason: m);
        expect(b.containsKey('temperature'), false, reason: m);
      }
    });

    test('non-reasoning OpenAI models and other kinds keep max_tokens + temperature', () async {
      http.on[path] = sse([oaChunk('{"a":1}', finish: 'stop'), 'data: [DONE]']);
      for (final (kind, m) in [
        (ProviderKind.openai, 'gpt-4o'),
        (ProviderKind.openai, 'gpt-4.1-mini'),
        (ProviderKind.openrouter, 'o3-mini'),
        (ProviderKind.custom, 'gpt-5'),
      ]) {
        await doneText(client(kind: kind).generate(req(m)));
        final b = http.last.json;
        expect(b['max_tokens'], 321, reason: '$kind $m');
        expect(b['temperature'], 0.3, reason: '$kind $m');
        expect(b.containsKey('max_completion_tokens'), false, reason: '$kind $m');
      }
    });

    test('[DONE] alone (no finish_reason) completes', () async {
      http.on[path] = sse([oaChunk('{"a"'), oaChunk(':1}'), 'data: [DONE]']);
      expect(await doneText(client().generate(req('m'))), '{"a":1}');
    });

    test('finish_reason stop without [DONE] completes', () async {
      http.on[path] = sse([oaChunk('{"a":1}'), oaChunk(null, finish: 'stop')]);
      expect(await doneText(client().generate(req('m'))), '{"a":1}');
    });

    test('finish_reason stop then a dropped connection still completes', () async {
      http.on[path] = dropAfter(
        'data: ${'{"choices":[{"delta":{"content":"{\\"a\\":1}"},"finish_reason":"stop"}]}'}\n\n',
      );
      expect(await doneText(client().generate(req('m'))), '{"a":1}');
    });

    test('stream ending without finish_reason or [DONE] → failure', () async {
      http.on[path] = sse([oaChunk('{"a":1}')]);
      await expectLater(client().generate(req('m')).toList(), fails());
    });

    test('connection dropped mid-stream (no finish) → failure', () async {
      http.on[path] = dropAfter('data: ${'{"choices":[{"delta":{"content":"{\\"a\\""}}]}'}\n\n');
      await expectLater(client().generate(req('m')).toList(), fails());
    });

    test('finish_reason length / content_filter → failure', () async {
      for (final reason in ['length', 'content_filter', 'tool_calls']) {
        http.on[path] = sse([oaChunk('{"a":1}', finish: reason), 'data: [DONE]']);
        await expectLater(client().generate(req('m')).toList(), fails(), reason: reason);
      }
    });

    test('mid-stream error chunk → failure with the message', () async {
      http.on[path] = sse([
        oaChunk('{"a"'),
        {
          'error': {'message': 'upstream exploded'},
        },
        'data: [DONE]',
      ]);
      await expectLater(client().generate(req('m')).toList(), fails('upstream exploded'));
    });

    test('HTTP 401 → failure carrying status and provider message', () async {
      http.on[path] = json({
        'error': {'message': 'bad key'},
      }, status: 401);
      await expectLater(
        client().generate(req('m')).toList(),
        throwsA(isA<LlmFailure>().having((f) => f.statusCode, 'status', 401).having((f) => f.message, 'm', 'bad key')),
      );
    });

    test('listModels: HTML 200 → LlmFailure', () async {
      http.on['/v1/models'] = text('<html><body>Login</body></html>', type: 'text/html');
      await expectLater(client().listModels(), fails());
    });

    test('listModels: JSON array (non-object) → LlmFailure', () async {
      http.on['/v1/models'] = text('[]');
      await expectLater(client().listModels(), fails());
    });

    test('listModels parses OpenRouter metadata and drops models without structured output', () async {
      http.on['/v1/models'] = json({
        'data': [
          {
            'id': 'vis',
            'context_length': 128000,
            'pricing': {'prompt': '0.000001', 'completion': '0.000002'},
            'architecture': {
              'input_modalities': ['text', 'image'],
            },
            'supported_parameters': ['structured_outputs'],
          },
          {
            'id': 'nostruct',
            'supported_parameters': ['tools'],
          },
          {'id': 'plain'},
        ],
      });
      final models = await client(key: 'k').listModels();
      expect(models.map((m) => m.name), ['vis', 'plain']);
      expect(models.first.vision, true);
      expect(models.first.contextLength, 128000);
      expect(models.first.inputPricePerMTok, closeTo(1.0, 1e-9));
      expect(models.first.outputPricePerMTok, closeTo(2.0, 1e-9));
      expect(http.last.method, 'GET');
      expect(http.last.headers.value('authorization'), 'Bearer k');
    });

    test('connection refused → LlmFailure', () async {
      final c = OpenAiCompatibleClient(baseUrl: 'http://127.0.0.1:1/v1');
      await expectLater(c.generate(req('m')).toList(), fails());
    });
  });

  group('Ollama', () {
    OllamaClient client({String? key, Map<String, String>? h}) =>
        OllamaClient(baseUrl: http.url, apiKey: key, headers: h ?? const {});

    test('request shape: format = schema, images base64, options', () async {
      http.on['/api/chat'] = ndjson([
        {
          'message': {'content': '{"a":'},
          'done': false,
        },
        {
          'message': {'content': '1}'},
          'done': true,
          'done_reason': 'stop',
          'prompt_eval_count': 7,
          'eval_count': 3,
        },
      ]);
      final events = await client(key: 'k', h: {'x-a': 'b'}).generate(req('llava', images: [img])).toList();
      final done = events.last as LlmDone;
      expect(done.text, '{"a":1}');
      expect(done.inputTokens, 7);
      expect(done.outputTokens, 3);
      final s = http.last;
      expect(s.headers.value('authorization'), 'Bearer k');
      expect(s.headers.value('x-a'), 'b');
      final b = s.json;
      expect(b['format'], _schema);
      expect(b['stream'], true);
      expect(b['options'], {'temperature': 0.3, 'num_predict': 321});
      final msgs = (b['messages'] as List).cast<Map>();
      expect(msgs[0], {'role': 'system', 'content': 'SYS'});
      expect(msgs[1]['images'], ['iVBORw0KGgo=']);
      expect(msgs[1]['content'], 'USER');
    });

    test('done_reason length → failure', () async {
      http.on['/api/chat'] = ndjson([
        {
          'message': {'content': '{"a":1'},
          'done': true,
          'done_reason': 'length',
        },
      ]);
      await expectLater(client().generate(req('m')).toList(), fails());
    });

    test('done without done_reason completes', () async {
      http.on['/api/chat'] = ndjson([
        {
          'message': {'content': '{"a":1}'},
          'done': true,
        },
      ]);
      expect(await doneText(client().generate(req('m'))), '{"a":1}');
    });

    test('stream ending without done → failure', () async {
      http.on['/api/chat'] = ndjson([
        {
          'message': {'content': '{"a":1}'},
          'done': false,
        },
      ]);
      await expectLater(client().generate(req('m')).toList(), fails());
    });

    test('error line → failure', () async {
      http.on['/api/chat'] = ndjson([
        {'error': 'model not found'},
      ]);
      await expectLater(client().generate(req('m')).toList(), fails('model not found'));
    });

    test('listModels reads /api/tags; HTML → failure', () async {
      http.on['/api/tags'] = json({
        'models': [
          {'name': 'llama3:8b'},
        ],
      });
      expect((await client().listModels()).single.name, 'llama3:8b');
      http.on['/api/tags'] = text('<!doctype html><p>hi</p>', type: 'text/html');
      await expectLater(client().listModels(), fails());
    });
  });

  group('Anthropic', () {
    AnthropicClient client({String? key, Map<String, String>? h}) =>
        AnthropicClient(baseUrl: http.url, apiKey: key, headers: h ?? const {});

    List<Object> stream(String stop) => [
      {
        'type': 'message_start',
        'message': {
          'usage': {'input_tokens': 11},
        },
      },
      {
        'type': 'content_block_start',
        'index': 0,
        'content_block': {'type': 'tool_use', 'name': 'thing'},
      },
      {
        'type': 'content_block_delta',
        'delta': {'type': 'input_json_delta', 'partial_json': '{"a":'},
      },
      {
        'type': 'content_block_delta',
        'delta': {'type': 'input_json_delta', 'partial_json': '1}'},
      },
      {
        'type': 'message_delta',
        'delta': {'stop_reason': stop},
        'usage': {'output_tokens': 5},
      },
      {'type': 'message_stop'},
    ];

    test('request shape: forced tool, system, headers, images', () async {
      http.on['/v1/messages'] = sse(stream('tool_use'));
      final events = await client(key: 'sk', h: {'x-b': 'c'}).generate(req('claude-x', images: [img])).toList();
      final done = events.last as LlmDone;
      expect(done.text, '{"a":1}');
      expect(done.inputTokens, 11);
      expect(done.outputTokens, 5);
      final s = http.last;
      expect(s.headers.value('x-api-key'), 'sk');
      expect(s.headers.value('anthropic-version'), isNotNull);
      expect(s.headers.value('x-b'), 'c');
      final b = s.json;
      expect(b['system'], 'SYS');
      expect(b['max_tokens'], 321);
      expect(b['stream'], true);
      expect(b['tools'], [
        {'name': 'thing', 'description': isA<String>(), 'input_schema': _schema},
      ]);
      expect(b['tool_choice'], {'type': 'tool', 'name': 'thing'});
      final msgs = (b['messages'] as List).cast<Map>();
      expect(msgs, hasLength(1));
      expect(msgs[0]['role'], 'user');
      expect(msgs[0]['content'], [
        {
          'type': 'image',
          'source': {'type': 'base64', 'media_type': 'image/png', 'data': 'iVBORw0KGgo='},
        },
        {'type': 'text', 'text': 'USER'},
      ]);
    });

    test('tool_use and end_turn complete', () async {
      for (final stop in ['tool_use', 'end_turn']) {
        http.on['/v1/messages'] = sse(stream(stop));
        expect(await doneText(client().generate(req('m'))), '{"a":1}', reason: stop);
      }
    });

    test('max_tokens / refusal / pause_turn → failure', () async {
      for (final stop in ['max_tokens', 'refusal', 'pause_turn']) {
        http.on['/v1/messages'] = sse(stream(stop));
        await expectLater(client().generate(req('m')).toList(), fails(), reason: stop);
      }
    });

    test('stream ending without message_stop → failure', () async {
      http.on['/v1/messages'] = sse(stream('tool_use').sublist(0, 4));
      await expectLater(client().generate(req('m')).toList(), fails());
    });

    test('error event → failure', () async {
      http.on['/v1/messages'] = sse([
        'event: error\ndata: {"type":"error","error":{"type":"overloaded_error","message":"Overloaded"}}',
      ]);
      await expectLater(client().generate(req('m')).toList(), fails('Overloaded'));
    });

    test('listModels: HTML 200 → failure', () async {
      http.on['/v1/models'] = text('<html></html>', type: 'text/html');
      await expectLater(client().listModels(), fails());
    });
  });

  group('Gemini', () {
    GeminiClient client({String? key, Map<String, String>? h}) =>
        GeminiClient(baseUrl: http.url, apiKey: key, headers: h ?? const {});
    const path = '/v1beta/models/gemini-x:streamGenerateContent';

    Map<String, Object?> chunk(String t, {String? finish}) => {
      'candidates': [
        {
          'content': {
            'parts': [
              {'text': t},
            ],
          },
          'finishReason': ?finish,
        },
      ],
      'usageMetadata': {'promptTokenCount': 4, 'candidatesTokenCount': 2},
    };

    test('request shape: responseJsonSchema, systemInstruction, key header, inlineData', () async {
      http.on[path] = sse([chunk('{"a":'), chunk('1}', finish: 'STOP')]);
      final events = await client(key: 'gk', h: {'x-c': 'd'}).generate(req('gemini-x', images: [img])).toList();
      final done = events.last as LlmDone;
      expect(done.text, '{"a":1}');
      expect(done.inputTokens, 4);
      final s = http.last;
      expect(s.uri.queryParameters['alt'], 'sse');
      expect(s.headers.value('x-goog-api-key'), 'gk');
      expect(s.headers.value('x-c'), 'd');
      final b = s.json;
      expect(b['systemInstruction'], {
        'parts': [
          {'text': 'SYS'},
        ],
      });
      final gc = b['generationConfig'] as Map;
      expect(gc['responseMimeType'], 'application/json');
      expect(gc['responseJsonSchema'], _schema);
      expect(gc['maxOutputTokens'], 321);
      expect(gc['temperature'], 0.3);
      final contents = (b['contents'] as List).cast<Map>();
      expect(contents, hasLength(1));
      expect(contents[0]['parts'], [
        {
          'inlineData': {'mimeType': 'image/png', 'data': 'iVBORw0KGgo='},
        },
        {'text': 'USER'},
      ]);
    });

    test('thought parts are not part of the output', () async {
      http.on[path] = sse([
        {
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': 'thinking...', 'thought': true},
                  {'text': '{"a":1}'},
                ],
              },
              'finishReason': 'STOP',
            },
          ],
        },
      ]);
      expect(await doneText(client().generate(req('gemini-x'))), '{"a":1}');
    });

    test('non-STOP finishReason → failure', () async {
      for (final r in ['MAX_TOKENS', 'SAFETY', 'RECITATION', 'OTHER']) {
        http.on[path] = sse([chunk('{"a":1}', finish: r)]);
        await expectLater(client().generate(req('gemini-x')).toList(), fails(), reason: r);
      }
    });

    test('no STOP at all → failure', () async {
      http.on[path] = sse([chunk('{"a":1}')]);
      await expectLater(client().generate(req('gemini-x')).toList(), fails());
    });

    test('listModels keeps generateContent models and strips models/', () async {
      http.on['/v1beta/models'] = json({
        'models': [
          {
            'name': 'models/gemini-x',
            'inputTokenLimit': 1000,
            'supportedGenerationMethods': ['generateContent'],
          },
          {
            'name': 'models/embed',
            'supportedGenerationMethods': ['embedContent'],
          },
        ],
      });
      final m = await client().listModels();
      expect(m.map((e) => e.name), ['gemini-x']);
      http.on['/v1beta/models'] = text('<html/>', type: 'text/html');
      await expectLater(client().listModels(), fails());
    });
  });
}
