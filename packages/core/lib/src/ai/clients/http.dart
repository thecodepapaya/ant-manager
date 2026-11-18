import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import '../llm.dart';

/// Dio configured for one provider: timeout plus optional custom CA / self-signed TLS (#15).
Dio newDio({Duration timeout = const Duration(seconds: 120), String? customCaPem, bool allowSelfSigned = false}) {
  final dio = Dio(BaseOptions(connectTimeout: timeout, receiveTimeout: timeout, sendTimeout: timeout));
  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () {
      final context = SecurityContext(withTrustedRoots: true);
      if (customCaPem != null && customCaPem.trim().isNotEmpty) {
        context.setTrustedCertificatesBytes(utf8.encode(customCaPem));
      }
      final client = HttpClient(context: context);
      if (allowSelfSigned) client.badCertificateCallback = (_, _, _) => true;
      return client;
    },
  );
  return dio;
}

/// Joins a provider base URL and an API path without relying on Dio's URL resolution.
String joinUrl(String baseUrl, String path) {
  final base = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
  return '$base$path';
}

/// GET returning a JSON object. Non-2xx and transport errors become [LlmFailure].
Future<Map<String, Object?>> getJson(Dio dio, String url, {Map<String, String> headers = const {}}) async {
  final lines = await _send(dio, 'GET', url, null, headers).join('\n');
  final decoded = jsonDecode(lines);
  if (decoded is! Map<String, Object?>) throw LlmFailure('Unexpected response from $url');
  return decoded;
}

/// POST a JSON body and stream the response line by line (SSE or NDJSON).
Stream<String> postLines(Dio dio, String url, Object body, {Map<String, String> headers = const {}}) =>
    _send(dio, 'POST', url, body, headers);

Stream<String> _send(Dio dio, String method, String url, Object? body, Map<String, String> headers) async* {
  final cancel = CancelToken();
  try {
    final Response<ResponseBody> res;
    try {
      res = await dio.request<ResponseBody>(
        url,
        data: body,
        cancelToken: cancel,
        options: Options(
          method: method,
          headers: {if (body != null) 'content-type': 'application/json', ...headers},
          responseType: ResponseType.stream,
          validateStatus: (_) => true,
        ),
      );
    } on DioException catch (e) {
      throw LlmFailure(_transportMessage(e));
    }
    final status = res.statusCode ?? 0;
    final lines = res.data!.stream.cast<List<int>>().transform(utf8.decoder).transform(const LineSplitter());
    if (status >= 400) {
      final text = await lines.join('\n');
      throw LlmFailure(errorMessage(text), statusCode: status);
    }
    try {
      yield* lines;
    } on DioException catch (e) {
      throw LlmFailure(_transportMessage(e));
    }
  } finally {
    // Stops the HTTP request when the consumer cancels the stream early.
    cancel.cancel();
  }
}

String _transportMessage(DioException e) => switch (e.type) {
  DioExceptionType.connectionTimeout ||
  DioExceptionType.receiveTimeout ||
  DioExceptionType.sendTimeout => 'Request timed out',
  _ => e.message ?? e.error?.toString() ?? 'Connection failed',
};

/// Extracts a readable message from a provider error body (all four protocols use an `error` field).
String errorMessage(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map) {
      final error = decoded['error'];
      if (error is String) return error;
      if (error is Map && error['message'] is String) return error['message'] as String;
    }
  } on FormatException {
    // Not JSON: fall through to the raw body.
  }
  return body.length > 500 ? '${body.substring(0, 500)}…' : body;
}

/// Data payloads of an SSE stream, ending at `[DONE]`. Comment and `event:` lines are skipped.
Stream<Map<String, Object?>> sseEvents(Stream<String> lines) async* {
  await for (final line in lines) {
    if (!line.startsWith('data:')) continue;
    final data = line.substring(5).trim();
    if (data.isEmpty) continue;
    if (data == '[DONE]') return;
    yield jsonDecode(data) as Map<String, Object?>;
  }
}

/// JSON objects of an NDJSON stream.
Stream<Map<String, Object?>> ndjsonEvents(Stream<String> lines) async* {
  await for (final line in lines) {
    if (line.trim().isEmpty) continue;
    yield jsonDecode(line) as Map<String, Object?>;
  }
}

/// Throws if a streamed chunk carries an `error` field (OpenRouter, Ollama and Anthropic do this mid-stream).
void throwIfError(Map<String, Object?> chunk) {
  if (chunk['error'] == null) return;
  throw LlmFailure(errorMessage(jsonEncode(chunk)));
}
