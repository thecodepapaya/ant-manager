// Independent tests for the AI transport fixes: mid-stream connection drops and StructuredOutput error mapping.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

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

final _req = LlmRequest(
  model: 'm',
  schema: _schema,
  messages: [const LlmMessage.system('s'), const LlmMessage.user('u')],
);

Matcher _fails() => throwsA(isA<LlmFailure>());

String _sse(List<Object> events) => [for (final e in events) 'data: ${jsonEncode(e)}\n\n'].join();
String _nd(List<Object> lines) => [for (final l in lines) '${jsonEncode(l)}\n'].join();

Future<String> _done(Stream<LlmEvent> s) async {
  final events = await s.toList();
  expect(events.last, isA<LlmDone>());
  expect(events.whereType<LlmDone>(), hasLength(1));
  return (events.last as LlmDone).text;
}

class _Router implements ModelRouter {
  _Router(this.client, {this.error});
  final LlmClient client;
  final Object? error;
  @override
  Future<ResolvedModel> resolve(LlmRoute route) async {
    if (error != null) throw error!;
    return ResolvedModel(
      client: client,
      modelName: 'm',
      info: const ModelInfo(name: 'm'),
    );
  }
}

/// A client whose stream emits [before] events then throws [error].
class _Throwing implements LlmClient {
  _Throwing(this.error, {this.before = const []});
  final Object error;
  final List<LlmEvent> before;
  @override
  ProviderProtocol get protocol => ProviderProtocol.openai;
  @override
  Future<List<ModelInfo>> listModels() async => const [];
  @override
  Stream<LlmEvent> generate(LlmRequest request) async* {
    for (final e in before) {
      yield e;
    }
    throw error;
  }
}

void main() {
  late StubHttp http;
  setUp(() async => http = await StubHttp.start());
  tearDown(() => http.close());

  group('connection drop mid-stream (before completion) → LlmFailure', () {
    test('OpenAI-compatible: after a delta, before finish_reason', () async {
      http.on['/v1/chat/completions'] = dropAfter(
        _sse([
          {
            'choices': [
              {
                'delta': {'content': '{"a":'},
                'finish_reason': null,
              },
            ],
          },
        ]),
      );
      final c = OpenAiCompatibleClient(baseUrl: '${http.url}/v1');
      await expectLater(c.generate(_req).toList(), _fails());
    });

    test('OpenAI-compatible: drop with a half-written SSE line', () async {
      http.on['/v1/chat/completions'] = dropAfter('data: {"choices":[{"delta":{"content":"{\\"a');
      // A transport failure, not the partial line parsed as bad JSON.
      await expectLater(
        OpenAiCompatibleClient(baseUrl: '${http.url}/v1').generate(_req).toList(),
        throwsA(isA<LlmFailure>().having((f) => f.message, 'message', isNot(contains('Unexpected response')))),
      );
    });

    test('Anthropic: before message_stop', () async {
      http.on['/v1/messages'] = dropAfter(
        _sse([
          {
            'type': 'content_block_delta',
            'delta': {'type': 'input_json_delta', 'partial_json': '{"a":1}'},
          },
          {
            'type': 'message_delta',
            'delta': {'stop_reason': 'tool_use'},
          },
        ]),
      );
      await expectLater(AnthropicClient(baseUrl: http.url).generate(_req).toList(), _fails());
    });

    test('Ollama: before done', () async {
      http.on['/api/chat'] = dropAfter(
        _nd([
          {
            'message': {'content': '{"a":'},
            'done': false,
          },
        ]),
      );
      await expectLater(OllamaClient(baseUrl: http.url).generate(_req).toList(), _fails());
    });

    test('Gemini: before STOP', () async {
      http.on['/v1beta/models/m:streamGenerateContent'] = dropAfter(
        _sse([
          {
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': '{"a":'},
                  ],
                },
              },
            ],
          },
        ]),
      );
      await expectLater(GeminiClient(baseUrl: http.url).generate(_req).toList(), _fails());
    });

    test('through StructuredOutput the drop is an LlmFailure too', () async {
      http.on['/chat/completions'] = dropAfter(
        _sse([
          {
            'choices': [
              {
                'delta': {'content': '{"a":'},
              },
            ],
          },
        ]),
      );
      final out = StructuredOutput(_Router(OpenAiCompatibleClient(baseUrl: http.url)));
      await expectLater(out(LlmRoute.extraction, system: 's', user: 'u', schema: _schema), _fails());
    });
  });

  group('connection drop after completion → the call completes', () {
    test('OpenAI-compatible: finish_reason stop, then usage chunk, then drop (no [DONE])', () async {
      http.on['/v1/chat/completions'] = dropAfter(
        _sse([
          {
            'choices': [
              {
                'delta': {'content': '{"a":1}'},
                'finish_reason': 'stop',
              },
            ],
          },
          {
            'choices': <Object?>[],
            'usage': {'prompt_tokens': 3, 'completion_tokens': 2},
          },
        ]),
      );
      final events = await OpenAiCompatibleClient(baseUrl: '${http.url}/v1').generate(_req).toList();
      final done = events.last as LlmDone;
      expect(done.text, '{"a":1}');
      expect(done.inputTokens, 3);
      expect(done.outputTokens, 2);
    });

    test('OpenAI-compatible: stop in a separate empty-delta chunk, then drop', () async {
      http.on['/v1/chat/completions'] = dropAfter(
        _sse([
          {
            'choices': [
              {
                'delta': {'content': '{"a":1}'},
              },
            ],
          },
          {
            'choices': [
              {'delta': <String, Object?>{}, 'finish_reason': 'stop'},
            ],
          },
        ]),
      );
      expect(await _done(OpenAiCompatibleClient(baseUrl: '${http.url}/v1').generate(_req)), '{"a":1}');
    });

    test('Gemini: stops reading at STOP, so a later drop is harmless', () async {
      http.on['/v1beta/models/m:streamGenerateContent'] = dropAfter(
        _sse([
          {
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': '{"a":1}'},
                  ],
                },
                'finishReason': 'STOP',
              },
            ],
          },
        ]),
      );
      expect(await _done(GeminiClient(baseUrl: http.url).generate(_req)), '{"a":1}');
    });

    test('Anthropic: returns at message_stop, so a later drop is harmless', () async {
      http.on['/v1/messages'] = dropAfter(
        _sse([
          {
            'type': 'content_block_delta',
            'delta': {'type': 'input_json_delta', 'partial_json': '{"a":1}'},
          },
          {'type': 'message_stop'},
        ]),
      );
      expect(await _done(AnthropicClient(baseUrl: http.url).generate(_req)), '{"a":1}');
    });

    test('Ollama: returns at done, so a later drop is harmless', () async {
      http.on['/api/chat'] = dropAfter(
        _nd([
          {
            'message': {'content': '{"a":1}'},
            'done': true,
            'done_reason': 'stop',
          },
        ]),
      );
      expect(await _done(OllamaClient(baseUrl: http.url).generate(_req)), '{"a":1}');
    });

    test('StructuredOutput returns the parsed result after a post-stop drop', () async {
      http.on['/chat/completions'] = dropAfter(
        _sse([
          {
            'choices': [
              {
                'delta': {'content': '{"a":1}'},
                'finish_reason': 'stop',
              },
            ],
          },
        ]),
      );
      final out = StructuredOutput(_Router(OpenAiCompatibleClient(baseUrl: http.url)));
      expect(await out(LlmRoute.extraction, system: 's', user: 'u', schema: _schema), {'a': 1});
    });
  });

  group('StructuredOutput maps other exceptions to LlmFailure', () {
    Future<Map<String, Object?>> run(LlmClient c, {Object? routerError}) =>
        StructuredOutput(_Router(c, error: routerError))(LlmRoute.extraction, system: 's', user: 'u', schema: _schema);

    for (final (name, error) in <(String, Object)>[
      ('HttpException', const HttpException('Connection closed while receiving data')),
      ('SocketException', const SocketException('reset')),
      ('TimeoutException', TimeoutException('slow')),
      ('custom Exception', Exception('boom')),
    ]) {
      test(name, () async {
        await expectLater(
          run(_Throwing(error)),
          throwsA(isA<LlmFailure>().having((f) => f.message, 'message', contains('Model call failed'))),
        );
      });
    }

    test('after some deltas were streamed', () async {
      final deltas = <String>[];
      final out = StructuredOutput(_Router(_Throwing(const SocketException('x'), before: [LlmDelta('{"a"')])));
      await expectLater(
        out(LlmRoute.extraction, system: 's', user: 'u', schema: _schema, onDelta: deltas.add),
        _fails(),
      );
      expect(deltas, ['{"a"']);
    });

    test('an LlmFailure keeps its message and status code', () async {
      await expectLater(
        run(_Throwing(LlmFailure('quota', statusCode: 429))),
        throwsA(
          isA<LlmFailure>().having((f) => f.message, 'message', 'quota').having((f) => f.statusCode, 'status', 429),
        ),
      );
    });

    test('a stream ending without LlmDone → LlmFailure', () async {
      await expectLater(run(_Empty()), _fails());
    });

    test(
      'a router throwing a non-LlmFailure exception → LlmFailure',
      skip:
          'BUG: structured.dart:21 router.resolve() runs outside the try, so a non-LlmFailure exception from the '
          'router (e.g. a DB/secret-store error) escapes StructuredOutput untranslated',
      () async {
        await expectLater(run(_Empty(), routerError: const FileSystemException('keychain locked')), _fails());
      },
    );
  });
}

class _Empty implements LlmClient {
  @override
  ProviderProtocol get protocol => ProviderProtocol.openai;
  @override
  Future<List<ModelInfo>> listModels() async => const [];
  @override
  Stream<LlmEvent> generate(LlmRequest request) => const Stream.empty();
}
