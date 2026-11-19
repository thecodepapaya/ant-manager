import 'dart:convert';

import '../domain/enums.dart';
import 'llm.dart';

/// Typed JSON output (#70). Native structured output only: no repair retries.
/// A malformed response is an error: only [LlmFailure] escapes.
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
    try {
      final m = await router.resolve(route);
      final req = LlmRequest(
        model: m.modelName,
        schema: schema,
        schemaName: schemaName,
        messages: [
          LlmMessage.system(system),
          LlmMessage.user(user, images: images),
        ],
      );
      await for (final e in m.client.generate(req)) {
        switch (e) {
          case LlmDelta(:final text):
            onDelta?.call(text);
          case LlmDone(:final text):
            return parseStructured(text, schema);
        }
      }
    } on LlmFailure {
      rethrow;
    } on FormatException catch (e) {
      throw LlmFailure('Unexpected response from the model: ${e.message}');
    } on TypeError catch (e) {
      // A client cast an unexpected stream payload shape.
      throw LlmFailure('Unexpected response from the model: $e');
    } on Exception catch (e) {
      throw LlmFailure('Model call failed: $e');
    }
    throw LlmFailure('Stream ended without a result');
  }
}

/// Decodes [text] as a JSON object and checks it against [schema]. Throws [LlmFailure] otherwise.
Map<String, Object?> parseStructured(String text, Map<String, Object?> schema) {
  final Object? decoded;
  try {
    decoded = jsonDecode(text);
  } on FormatException catch (e) {
    throw LlmFailure('Model returned invalid JSON: ${e.message}');
  }
  if (decoded is! Map<String, Object?>) throw LlmFailure('Model returned non-object JSON');
  final error = schemaError(decoded, schema);
  if (error != null) throw LlmFailure('Model output does not match the schema: $error');
  return decoded;
}

/// Minimal JSON-schema check: `type` (incl. type lists), `enum`, object `properties`/`required`,
/// array `items`. Other keywords are ignored. Returns a description of the first mismatch, or null.
String? schemaError(
  Object? value,
  Map<String, Object?> schema, [
  String path = r'$',
]) {
  final type = schema['type'];
  final types = type is List ? type.cast<String>() : [if (type is String) type];
  if (types.isNotEmpty && !types.any((t) => _isType(value, t))) {
    return '$path is not ${types.join(' or ')}';
  }
  final allowed = schema['enum'];
  if (allowed is List && !allowed.contains(value)) return '$path is not one of $allowed';
  if (value is Map) {
    for (final key
        in (schema['required'] as List? ?? const []).cast<String>()) {
      if (!value.containsKey(key)) return '$path.$key is missing';
    }
    final props = schema['properties'] as Map? ?? const {};
    for (final e in props.entries) {
      if (!value.containsKey(e.key)) continue;
      final err = schemaError(
        value[e.key],
        (e.value as Map).cast<String, Object?>(),
        '$path.${e.key}',
      );
      if (err != null) return err;
    }
  }
  final items = schema['items'];
  if (value is List && items is Map) {
    for (var i = 0; i < value.length; i++) {
      final err = schemaError(
        value[i],
        items.cast<String, Object?>(),
        '$path[$i]',
      );
      if (err != null) return err;
    }
  }
  return null;
}

bool _isType(Object? v, String type) => switch (type) {
  'object' => v is Map,
  'array' => v is List,
  'string' => v is String,
  'integer' => v is int || (v is double && v == v.truncateToDouble()),
  'number' => v is num,
  'boolean' => v is bool,
  'null' => v == null,
  _ => true,
};
