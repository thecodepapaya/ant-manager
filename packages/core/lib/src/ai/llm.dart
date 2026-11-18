import '../domain/enums.dart';

/// A chat message. [images] are base64 data for vision models.
class LlmMessage {
  const LlmMessage.system(this.text) : role = 'system', images = const [];
  const LlmMessage.user(this.text, {this.images = const []}) : role = 'user';
  final String role;
  final String text;
  final List<LlmImage> images;
}

class LlmImage {
  const LlmImage({required this.mime, required this.base64});
  final String mime;
  final String base64;
}

class LlmRequest {
  const LlmRequest({
    required this.model,
    required this.messages,
    required this.schema,
    this.schemaName = 'output',
    this.maxTokens = 4096,
    this.temperature = 0.2,
  });
  final String model;
  final List<LlmMessage> messages;
  /// JSON schema for native structured output (#70). Always required.
  final Map<String, Object?> schema;
  final String schemaName;
  final int maxTokens;
  final double temperature;
}

sealed class LlmEvent {}

class LlmDelta extends LlmEvent {
  LlmDelta(this.text);
  final String text;
}

class LlmDone extends LlmEvent {
  LlmDone({required this.text, this.inputTokens, this.outputTokens});
  final String text; // full JSON text
  final int? inputTokens, outputTokens;
}

class LlmFailure implements Exception {
  LlmFailure(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => 'LlmFailure($statusCode): $message';
}

class ModelInfo {
  const ModelInfo({
    required this.name,
    this.vision = false,
    this.contextLength,
    this.inputPricePerMTok,
    this.outputPricePerMTok,
  });
  final String name;
  final bool vision;
  final int? contextLength;
  final double? inputPricePerMTok, outputPricePerMTok;
}

/// One provider endpoint. Adapters: OpenAI-compatible (OpenRouter, OpenAI, LM Studio, vLLM, custom),
/// Ollama, Anthropic, Gemini.
abstract interface class LlmClient {
  ProviderProtocol get protocol;
  Future<List<ModelInfo>> listModels();
  /// Streams deltas then exactly one [LlmDone], or throws [LlmFailure]. Output is JSON matching the schema.
  Stream<LlmEvent> generate(LlmRequest request);
}

/// Probe used when a model is added: it must return valid JSON for a tiny schema (#70).
const structuredOutputProbeSchema = <String, Object?>{
  'type': 'object',
  'properties': {
    'ok': {'type': 'boolean'},
  },
  'required': ['ok'],
  'additionalProperties': false,
};

class ResolvedModel {
  const ResolvedModel({required this.client, required this.modelName, required this.info});
  final LlmClient client;
  final String modelName;
  final ModelInfo info;
}

/// Route → model, falling back to the default route (#75).
abstract interface class ModelRouter {
  Future<ResolvedModel> resolve(LlmRoute route);
}
