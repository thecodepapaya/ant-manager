import 'package:dio/dio.dart';

import '../../domain/enums.dart';
import '../llm.dart';
import 'http.dart';

/// OpenAI chat completions: OpenRouter (`https://openrouter.ai/api/v1`), OpenAI (`https://api.openai.com/v1`)
/// and custom endpoints (LM Studio, vLLM, llama.cpp: `http://host:port/v1`). [baseUrl] includes the `/v1` part.
class OpenAiCompatibleClient implements LlmClient {
  OpenAiCompatibleClient({
    required this.baseUrl,
    this.apiKey,
    this.headers = const {},
    this.kind = ProviderKind.custom,
    Dio? dio,
  }) : _dio = dio ?? newDio();

  final String baseUrl;

  /// [ProviderKind.openai] enables the reasoning-model parameter rules (see [_isOpenAiReasoning]).
  final ProviderKind kind;
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
    final reasoning = kind == ProviderKind.openai && _isOpenAiReasoning(request.model);
    final body = {
      'model': request.model,
      'messages': [for (final m in request.messages) _message(m)],
      'stream': true,
      'stream_options': {'include_usage': true},
      if (reasoning) 'max_completion_tokens': request.maxTokens else 'max_tokens': request.maxTokens,
      if (!reasoning) 'temperature': request.temperature,
      'response_format': {
        'type': 'json_schema',
        'json_schema': {'name': request.schemaName, 'schema': request.schema, 'strict': true},
      },
    };
    final text = StringBuffer();
    int? inTok, outTok;
    var finished = false;
    final lines = postLines(_dio, joinUrl(baseUrl, '/chat/completions'), body, headers: _headers);
    // After `finish_reason: stop` only the usage chunk / `[DONE]` remain, so a transport drop then still completes.
    try {
      await for (final chunk in sseEvents(lines)) {
        if (identical(chunk, sseDone)) {
          finished = true;
          break;
        }
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
          final reason = c['finish_reason'];
          if (reason == 'length') throw LlmFailure('Output truncated: max tokens reached');
          if (reason != null && reason != 'stop') throw LlmFailure('Generation stopped: $reason');
          if (reason == 'stop') finished = true;
        }
      }
    } on LlmFailure {
      if (!finished) rethrow;
    }
    // A stream that closes before `finish_reason`/`[DONE]` was cut off: its text is partial.
    if (!finished) throw LlmFailure('Stream ended before the response was complete');
    yield LlmDone(text: text.toString(), inputTokens: inTok, outputTokens: outTok);
  }

  /// OpenAI's reasoning models reject `max_tokens` and any non-default `temperature`.
  static bool _isOpenAiReasoning(String model) => ['o1', 'o3', 'o4', 'gpt-5'].any((p) => model.startsWith(p));

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
