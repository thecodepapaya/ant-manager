import 'package:dio/dio.dart';

import '../../domain/enums.dart';
import '../llm.dart';
import 'http.dart';

/// OpenAI chat completions: OpenRouter (`https://openrouter.ai/api/v1`), OpenAI (`https://api.openai.com/v1`)
/// and custom endpoints (LM Studio, vLLM, llama.cpp: `http://host:port/v1`). [baseUrl] includes the `/v1` part.
class OpenAiCompatibleClient implements LlmClient {
  OpenAiCompatibleClient({required this.baseUrl, this.apiKey, this.headers = const {}, Dio? dio})
    : _dio = dio ?? newDio();

  final String baseUrl;
  final String? apiKey;
  final Map<String, String> headers;
  final Dio _dio;

  @override
  ProviderProtocol get protocol => ProviderProtocol.openai;

  Map<String, String> get _headers => {...headers, if (apiKey != null) 'authorization': 'Bearer $apiKey'};

  /// OpenRouter reports pricing, context, modalities and supported parameters; plain servers only ids.
  /// When `supported_parameters` is reported, models without structured output are dropped (#70).
  @override
  Future<List<ModelInfo>> listModels() async {
    final json = await getJson(_dio, joinUrl(baseUrl, '/models'), headers: _headers);
    final out = <ModelInfo>[];
    for (final m in (json['data'] as List? ?? const []).cast<Map<String, Object?>>()) {
      final params = m['supported_parameters'];
      if (params is List && !params.contains('structured_outputs') && !params.contains('response_format')) continue;
      final pricing = m['pricing'] as Map<String, Object?>?;
      final arch = m['architecture'] as Map<String, Object?>?;
      final modalities = arch?['input_modalities'] as List?;
      out.add(
        ModelInfo(
          name: m['id'] as String,
          vision: modalities?.contains('image') ?? false,
          contextLength: (m['context_length'] as num?)?.toInt(),
          inputPricePerMTok: _perMTok(pricing?['prompt']),
          outputPricePerMTok: _perMTok(pricing?['completion']),
        ),
      );
    }
    return out;
  }

  static double? _perMTok(Object? perToken) {
    final v = perToken is num ? perToken.toDouble() : double.tryParse('${perToken ?? ''}');
    return v == null ? null : v * 1e6;
  }

  @override
  Stream<LlmEvent> generate(LlmRequest request) async* {
    final body = {
      'model': request.model,
      'messages': [for (final m in request.messages) _message(m)],
      'stream': true,
      'stream_options': {'include_usage': true},
      'max_tokens': request.maxTokens,
      'temperature': request.temperature,
      'response_format': {
        'type': 'json_schema',
        'json_schema': {'name': request.schemaName, 'schema': request.schema, 'strict': true},
      },
    };
    final text = StringBuffer();
    int? inTok, outTok;
    final lines = postLines(_dio, joinUrl(baseUrl, '/chat/completions'), body, headers: _headers);
    await for (final chunk in sseEvents(lines)) {
      throwIfError(chunk);
      final usage = chunk['usage'] as Map<String, Object?>?;
      if (usage != null) {
        inTok = (usage['prompt_tokens'] as num?)?.toInt();
        outTok = (usage['completion_tokens'] as num?)?.toInt();
      }
      for (final c in (chunk['choices'] as List? ?? const []).cast<Map<String, Object?>>()) {
        final delta = (c['delta'] as Map<String, Object?>?)?['content'];
        if (delta is String && delta.isNotEmpty) {
          text.write(delta);
          yield LlmDelta(delta);
        }
        if (c['finish_reason'] == 'length') throw LlmFailure('Output truncated: max tokens reached');
      }
    }
    yield LlmDone(text: text.toString(), inputTokens: inTok, outputTokens: outTok);
  }

  static Map<String, Object?> _message(LlmMessage m) => {
    'role': m.role,
    'content': m.images.isEmpty
        ? m.text
        : [
            {'type': 'text', 'text': m.text},
            for (final i in m.images)
              {
                'type': 'image_url',
                'image_url': {'url': 'data:${i.mime};base64,${i.base64}'},
              },
          ],
  };
}
