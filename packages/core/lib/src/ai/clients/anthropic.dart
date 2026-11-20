import 'package:dio/dio.dart';

import '../../domain/enums.dart';
import '../llm.dart';
import 'http.dart';

/// Anthropic Messages API. [baseUrl] is `https://api.anthropic.com`.
/// Structured output: a single tool whose `input_schema` is the schema, forced via `tool_choice`;
/// the tool input JSON is the [LlmDone] text.
class AnthropicClient implements LlmClient {
  AnthropicClient({required this.baseUrl, this.apiKey, this.headers = const {}, Dio? dio}) : _dio = dio ?? newDio();

  final String baseUrl;
  final String? apiKey;
  final Map<String, String> headers;
  final Dio _dio;

  @override
  ProviderProtocol get protocol => ProviderProtocol.native;

  Map<String, String> get _headers => {...headers, 'anthropic-version': '2023-06-01', 'x-api-key': ?apiKey};

  /// All current Claude models accept images; context length and pricing aren't reported.
  @override
  Future<List<ModelInfo>> listModels() async {
    final json = await getJson(_dio, joinUrl(baseUrl, '/v1/models?limit=1000'), headers: _headers);
    return [
      for (final m in (json['data'] as List? ?? const []).cast<Map<String, Object?>>())
        ModelInfo(name: m['id'] as String, vision: true),
    ];
  }

  @override
  Stream<LlmEvent> generate(LlmRequest request) async* {
    final system = [
      for (final m in request.messages)
        if (m.role == 'system') m.text,
    ].join('\n\n');
    final body = {
      'model': request.model,
      'max_tokens': request.maxTokens,
      'temperature': request.temperature,
      if (system.isNotEmpty) 'system': system,
      'messages': [
        for (final m in request.messages)
          if (m.role != 'system')
            {
              'role': m.role,
              'content': [
                for (final i in m.images)
                  {
                    'type': 'image',
                    'source': {'type': 'base64', 'media_type': i.mime, 'data': i.base64},
                  },
                {'type': 'text', 'text': m.text},
              ],
            },
      ],
      'tools': [
        {'name': request.schemaName, 'description': 'Return the result.', 'input_schema': request.schema},
      ],
      'tool_choice': {'type': 'tool', 'name': request.schemaName},
      'stream': true,
    };
    final text = StringBuffer();
    int? inTok, outTok;
    final lines = postLines(_dio, joinUrl(baseUrl, '/v1/messages'), body, headers: _headers);
    await for (final e in sseEvents(lines)) {
      throwIfError(e);
      switch (e['type']) {
        case 'message_start':
          final usage = (e['message'] as Map<String, Object?>?)?['usage'] as Map<String, Object?>?;
          inTok = (usage?['input_tokens'] as num?)?.toInt();
        case 'content_block_delta':
          final delta = e['delta'] as Map<String, Object?>;
          final part = delta['partial_json'];
          if (delta['type'] == 'input_json_delta' && part is String && part.isNotEmpty) {
            text.write(part);
            yield LlmDelta(part);
          }
        case 'message_delta':
          final usage = e['usage'] as Map<String, Object?>?;
          outTok = (usage?['output_tokens'] as num?)?.toInt() ?? outTok;
          final stop = (e['delta'] as Map<String, Object?>?)?['stop_reason'];
          if (stop == 'max_tokens') throw LlmFailure('Output truncated: max tokens reached');
          // The forced tool call ends with `tool_use`; anything else (refusal, pause_turn, …) is not a result.
          if (stop != null && stop != 'tool_use' && stop != 'end_turn') {
            throw LlmFailure('Generation stopped: $stop');
          }
        case 'message_stop':
          yield LlmDone(text: text.toString(), inputTokens: inTok, outputTokens: outTok);
          return;
      }
    }
    throw LlmFailure('Stream ended without a result');
  }
}
