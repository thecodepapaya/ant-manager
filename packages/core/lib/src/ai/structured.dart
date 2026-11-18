import 'dart:convert';

import '../domain/enums.dart';
import 'llm.dart';

/// Typed JSON output (#70). Native structured output only: no repair retries.
/// A malformed response is an error.
class StructuredOutput {
  StructuredOutput(this.router);
  final ModelRouter router;

  Future<Map<String, Object?>> call(
    LlmRoute route, {
    required String system,
    required String user,
    required Map<String, Object?> schema,
    String schemaName = 'output',
    List<LlmImage> images = const [],
    void Function(String delta)? onDelta,
  }) async {
    final m = await router.resolve(route);
    final req = LlmRequest(
      model: m.modelName,
      schema: schema,
      schemaName: schemaName,
      messages: [LlmMessage.system(system), LlmMessage.user(user, images: images)],
    );
    await for (final e in m.client.generate(req)) {
      switch (e) {
        case LlmDelta(:final text):
          onDelta?.call(text);
        case LlmDone(:final text):
          final decoded = jsonDecode(text);
          if (decoded is! Map<String, Object?>) {
            throw LlmFailure('Model returned non-object JSON');
          }
          return decoded;
      }
    }
    throw LlmFailure('Stream ended without a result');
  }
}
