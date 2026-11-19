// Full engine flow against OpenRouter. Runs only with `dart test -t live` and OPENROUTER_API_KEY set.
@Tags(['live'])
library;

import 'dart:io';

import 'package:core/core.dart';
import 'package:test/test.dart';

import 'e2e_flow.dart';

void main() {
  final key = Platform.environment['OPENROUTER_API_KEY'];
  if (key == null || key.isEmpty) {
    test('e2e (OpenRouter)', () {}, skip: 'OPENROUTER_API_KEY not set');
    return;
  }
  defineE2eFlow(
    'e2e (OpenRouter)',
    live: true,
    endpoint: () async => E2eEndpoint(
      kind: ProviderKind.openrouter,
      baseUrl: 'https://openrouter.ai/api/v1',
      model: 'google/gemini-2.5-flash-lite',
      apiKey: key,
    ),
  );
}
