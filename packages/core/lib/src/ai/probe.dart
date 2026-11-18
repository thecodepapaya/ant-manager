import 'dart:convert';

import 'llm.dart';

/// Runs a tiny structured-output request when a model is added (#70). Throws [LlmFailure] unless the model
/// returns valid JSON for [structuredOutputProbeSchema]. Returns [info] (from listing) or a bare [ModelInfo].
Future<ModelInfo> probeModel(LlmClient client, String model, {ModelInfo? info}) async {
  final request = LlmRequest(
    model: model,
    schema: structuredOutputProbeSchema,
    schemaName: 'probe',
    maxTokens: 256,
    temperature: 0,
    messages: const [LlmMessage.user('Reply with {"ok": true}.')],
  );
  String? text;
  await for (final e in client.generate(request)) {
    if (e is LlmDone) text = e.text;
  }
  Object? decoded;
  try {
    decoded = jsonDecode(text ?? '');
  } on FormatException {
    decoded = null;
  }
  if (decoded is! Map || decoded['ok'] is! bool) {
    throw LlmFailure('$model does not support structured output (JSON schema); choose another model');
  }
  return info ?? ModelInfo(name: model);
}
