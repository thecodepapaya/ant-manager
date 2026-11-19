import 'package:dio/dio.dart';

import '../../domain/enums.dart';
import '../llm.dart';
import 'http.dart';

/// Gemini API (`streamGenerateContent`). [baseUrl] is `https://generativelanguage.googleapis.com`.
/// Structured output via `responseMimeType: application/json` + `responseJsonSchema` (accepts standard
/// JSON Schema, unlike the OpenAPI-subset `responseSchema`, which rejects e.g. `additionalProperties`).
class GeminiClient implements LlmClient {
  GeminiClient({required this.baseUrl, this.apiKey, this.headers = const {}, Dio? dio}) : _dio = dio ?? newDio();

  final String baseUrl;
  final String? apiKey;
  final Map<String, String> headers;
  final Dio _dio;

  @override
  ProviderProtocol get protocol => ProviderProtocol.native;

  Map<String, String> get _headers => {...headers, 'x-goog-api-key': ?apiKey};

  /// Models that support `generateContent`. Gemini models are multimodal, so vision is assumed.
  @override
  Future<List<ModelInfo>> listModels() async {
    final json = await getJson(_dio, joinUrl(baseUrl, '/v1beta/models?pageSize=1000'), headers: _headers);
    return [
      for (final m in (json['models'] as List? ?? const []).cast<Map<String, Object?>>())
        if ((m['supportedGenerationMethods'] as List? ?? const []).contains('generateContent'))
          ModelInfo(
            name: (m['name'] as String).replaceFirst('models/', ''),
            vision: true,
            contextLength: (m['inputTokenLimit'] as num?)?.toInt(),
          ),
    ];
  }

  @override
  Stream<LlmEvent> generate(LlmRequest request) async* {
    final system = [
      for (final m in request.messages)
        if (m.role == 'system') m.text,
    ].join('\n\n');
    final body = {
      if (system.isNotEmpty)
        'systemInstruction': {
          'parts': [
            {'text': system},
          ],
        },
      'contents': [
        for (final m in request.messages)
          if (m.role != 'system')
            {
              'role': 'user',
              'parts': [
                for (final i in m.images)
                  {
                    'inlineData': {'mimeType': i.mime, 'data': i.base64},
                  },
                {'text': m.text},
              ],
            },
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'responseJsonSchema': request.schema,
        'temperature': request.temperature,
        'maxOutputTokens': request.maxTokens,
      },
    };
    final text = StringBuffer();
    int? inTok, outTok;
    var finished = false;
    final url = joinUrl(baseUrl, '/v1beta/models/${request.model}:streamGenerateContent?alt=sse');
    await for (final chunk in sseEvents(postLines(_dio, url, body, headers: _headers))) {
      throwIfError(chunk);
      final usage = chunk['usageMetadata'] as Map<String, Object?>?;
      if (usage != null) {
        inTok = (usage['promptTokenCount'] as num?)?.toInt();
        outTok = (usage['candidatesTokenCount'] as num?)?.toInt();
      }
      for (final c in (chunk['candidates'] as List? ?? const []).cast<Map<String, Object?>>()) {
        final parts = (c['content'] as Map<String, Object?>?)?['parts'] as List? ?? const [];
        for (final p in parts.cast<Map<String, Object?>>()) {
          final t = p['text'];
          if (t is String && t.isNotEmpty && p['thought'] != true) {
            text.write(t);
            yield LlmDelta(t);
          }
        }
        final reason = c['finishReason'];
        if (reason == 'MAX_TOKENS') throw LlmFailure('Output truncated: max tokens reached');
        if (reason != null && reason != 'STOP') throw LlmFailure('Generation stopped: $reason');
        if (reason == 'STOP') finished = true;
      }
    }
    if (!finished) throw LlmFailure('Stream ended before the response was complete');
    yield LlmDone(text: text.toString(), inputTokens: inTok, outputTokens: outTok);
  }
}
