import '../data/app_db.dart';
import '../domain/enums.dart';
import 'clients/anthropic.dart';
import 'consent.dart';
import 'clients/gemini.dart';
import 'clients/http.dart';
import 'clients/ollama.dart';
import 'clients/openai_compatible.dart';
import 'llm.dart';

/// Builds the client for a provider row. [apiKey] and [headers] are already resolved from the SecretStore.
/// `native` protocol means the provider's own API (Anthropic or Gemini).
/// Every request path builds its client here, so consent for a non-loopback base URL is enforced here (#NEXT).
LlmClient createClient(Provider row, {required String? apiKey, Map<String, String> headers = const {}}) {
  if (requiresConsent(row.baseUrl) && !row.consentGiven) {
    throw LlmFailure('${row.name} at ${row.baseUrl} has no consent to receive your data. '
        'Open it in Settings → Models and press Test connection to agree.');
  }
  final dio = newDio(
    timeout: Duration(seconds: row.timeoutSeconds),
    customCaPem: row.customCaPem,
    allowSelfSigned: row.allowSelfSigned,
  );
  final base = row.baseUrl;
  return switch (row.protocol) {
    ProviderProtocol.openai => OpenAiCompatibleClient(
      baseUrl: base,
      apiKey: apiKey,
      headers: headers,
      kind: row.kind,
      dio: dio,
    ),
    ProviderProtocol.ollama => OllamaClient(baseUrl: base, apiKey: apiKey, headers: headers, dio: dio),
    ProviderProtocol.native => switch (row.kind) {
      ProviderKind.anthropic => AnthropicClient(baseUrl: base, apiKey: apiKey, headers: headers, dio: dio),
      ProviderKind.gemini => GeminiClient(baseUrl: base, apiKey: apiKey, headers: headers, dio: dio),
      _ => throw LlmFailure('${row.kind.name} has no native protocol; use openai or ollama'),
    },
  };
}
