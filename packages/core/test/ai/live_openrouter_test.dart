@Tags(['live'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:core/core.dart';
import 'package:core/src/ai/clients/openai_compatible.dart';
import 'package:core/src/ai/probe.dart';
import 'package:test/test.dart';

/// Runs only with OPENROUTER_API_KEY set: `dart test -t live`.
void main() {
  final key = Platform.environment['OPENROUTER_API_KEY'];

  test(
    'OpenRouter: list, probe and a tiny structured request',
    () async {
      final client = OpenAiCompatibleClient(baseUrl: 'https://openrouter.ai/api/v1', apiKey: key);
      final models = await client.listModels();
      expect(models, isNotEmpty);
      const preferred = [
        'openai/gpt-4.1-nano',
        'openai/gpt-4o-mini',
        'google/gemini-2.5-flash-lite',
        'google/gemini-2.0-flash-001',
      ];
      final model = models.firstWhere(
        (m) => preferred.contains(m.name),
        orElse: () => models.firstWhere((m) => m.name.startsWith('openai/') && (m.inputPricePerMTok ?? 99) < 1),
      );
      printOnFailure('model: ${model.name}');
      expect(model.inputPricePerMTok, isNotNull);
      expect(model.contextLength, isNotNull);

      await probeModel(client, model.name, info: model);

      final req = LlmRequest(
        model: model.name,
        maxTokens: 200,
        schema: const {
          'type': 'object',
          'properties': {
            'sum': {'type': 'integer'},
            'word': {'type': 'string'},
          },
          'required': ['sum', 'word'],
          'additionalProperties': false,
        },
        messages: const [
          LlmMessage.system('Answer in JSON.'),
          LlmMessage.user('What is 2+3? Also give any English word.'),
        ],
      );
      final done = (await client.generate(req).last) as LlmDone;
      print("live model: ${model.name}");
      final out = jsonDecode(done.text) as Map<String, Object?>;
      expect(out['sum'], 5);
      expect(out['word'], isA<String>());
      expect(done.inputTokens, isNotNull);
    },
    skip: key == null || key.isEmpty ? 'OPENROUTER_API_KEY not set' : false,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
