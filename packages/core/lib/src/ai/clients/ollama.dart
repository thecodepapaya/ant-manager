import 'package:dio/dio.dart';

import '../../domain/enums.dart';
import '../llm.dart';
import 'http.dart';

/// Ollama native API (`/api/chat`, `/api/tags`). [baseUrl] is the server root, e.g. `http://localhost:11434`.
/// Structured output via `format: <schema>`.
class OllamaClient implements LlmClient {
  OllamaClient({required this.baseUrl, this.apiKey, this.headers = const {}, Dio? dio}) : _dio = dio ?? newDio();

  final String baseUrl;
  final String? apiKey;
  final Map<String, String> headers;
  final Dio _dio;

  @override
  ProviderProtocol get protocol => ProviderProtocol.ollama;

  Map<String, String> get _headers => {...headers, if (apiKey != null) 'authorization': 'Bearer $apiKey'};

  /// `/api/tags` reports names only; vision and context length are not detected.
  @override
  Future<List<ModelInfo>> listModels() async {
    final json = await getJson(_dio, joinUrl(baseUrl, '/api/tags'), headers: _headers);
    return [
      for (final m in (json['models'] as List? ?? const []).cast<Map<String, Object?>>())
        ModelInfo(name: m['name'] as String),
    ];
  }

  @override
  Stream<LlmEvent> generate(LlmRequest request) async* {
    final body = {
      'model': request.model,
      'messages': [
        for (final m in request.messages)
          {
            'role': m.role,
            'content': m.text,
            if (m.images.isNotEmpty) 'images': [for (final i in m.images) i.base64],
          },
      ],
      'stream': true,
      'format': request.schema,
      'options': {'temperature': request.temperature, 'num_predict': request.maxTokens},
    };
    final text = StringBuffer();
    final lines = postLines(_dio, joinUrl(baseUrl, '/api/chat'), body, headers: _headers);
    await for (final chunk in ndjsonEvents(lines)) {
      throwIfError(chunk);
      final delta = (chunk['message'] as Map<String, Object?>?)?['content'];
      if (delta is String && delta.isNotEmpty) {
        text.write(delta);
        yield LlmDelta(delta);
      }
      if (chunk['done'] == true) {
        final reason = chunk['done_reason'];
        if (reason == 'length') throw LlmFailure('Output truncated: max tokens reached');
        if (reason != null && reason != 'stop') throw LlmFailure('Generation stopped: $reason');
        yield LlmDone(
          text: text.toString(),
          inputTokens: (chunk['prompt_eval_count'] as num?)?.toInt(),
          outputTokens: (chunk['eval_count'] as num?)?.toInt(),
        );
        return;
      }
    }
    throw LlmFailure('Stream ended without a result');
  }
}
