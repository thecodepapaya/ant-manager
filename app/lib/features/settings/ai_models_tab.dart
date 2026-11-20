/// Settings → AI models (SPEC §6, §10): one obvious default model first, then providers, then the
/// collapsed per-task overrides that inherit the default (#75).
library;

import 'package:core/core.dart' hide Provider;
import 'package:core/core.dart' as core show Provider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui/ui.dart';

import '../../engine/setup_commands.dart';
import '../../state/providers.dart';
import 'kit.dart';
import 'provider_dialog.dart';
import 'setup_providers.dart';

/// Local servers answering on their default ports (detected once per engine).
final localServersProvider = FutureProvider<List<LocalServer>>((ref) async {
  final h = await ref.watch(engineProvider.future);
  return h.runtime(detectLocalServersCmd());
});

String modelLabel(Model m, List<core.Provider> providers) {
  final p = providers.where((p) => p.id == m.providerId).firstOrNull;
  return p == null ? m.modelName : '${m.modelName} · ${p.name}';
}

/// "Use [model] for everything": the global default (#75).
class DefaultModelPicker extends ConsumerWidget {
  const DefaultModelPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final models = ref.watch(llmModelsProvider).value ?? const <Model>[];
    final providers = ref.watch(llmProvidersProvider).value ?? const <core.Provider>[];
    final routes = ref.watch(taskRoutesProvider).value ?? const <LlmRoute, String>{};
    if (models.isEmpty) {
      return Text('No model yet. Connect a provider below; each model is checked for structured output before it’s added.',
          style: t.typo.body.copyWith(color: t.muted));
    }
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: t.space.md,
      runSpacing: t.space.md,
      children: [
        Text('Use', style: t.typo.title.copyWith(color: t.text)),
        SelectButton<String>(
          value: routes[LlmRoute.defaultRoute],
          placeholder: 'Choose a model',
          options: [for (final m in models) (m.id, modelLabel(m, providers))],
          onChanged: (id) => runCmd(context, ref, setRouteCmd(LlmRoute.defaultRoute, id)),
        ),
        Text('for everything', style: t.typo.title.copyWith(color: t.text)),
      ],
    );
  }
}

class AiModelsTab extends ConsumerWidget {
  const AiModelsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final providers = ref.watch(llmProvidersProvider).value ?? const <core.Provider>[];
    final models = ref.watch(llmModelsProvider).value ?? const <Model>[];
    final local = ref.watch(localServersProvider).value ?? const <LocalServer>[];
    // Keep routes loaded even while the empty state hides the default picker, so the per-task
    // overrides show the inherited model as soon as they open.
    ref.watch(taskRoutesProvider);
    final kinds = {for (final p in providers) p.kind};
    final urls = {for (final p in providers) p.baseUrl};

    String detail(core.Provider p) {
      final n = models.where((m) => m.providerId == p.id).length;
      final where = requiresConsent(p.baseUrl) ? Uri.tryParse(p.baseUrl)?.host ?? p.baseUrl : 'On this Mac';
      final key = p.credentialRef != null ? 'Key in Keychain · ' : '';
      return '$key$where · $n model${n == 1 ? '' : 's'} added';
    }

    return PageBody(
      maxWidth: t.widePage,
      children: [
        if (models.isEmpty && ref.watch(llmModelsProvider).hasValue)
          // Fresh profile: one obvious next step, like the other empty states.
          AntCard(
            child: AntEmptyState(
              icon: Icons.auto_awesome_outlined,
              title: 'No AI model yet',
              message: 'Reports, facts and wins need a model. OpenRouter is one key for Claude, GPT, Gemini and '
                  'open models, or pick a provider below.',
              action: AntButton.primary(
                label: providers.isEmpty ? 'Connect OpenRouter' : 'Add a model',
                icon: Icons.add,
                onPressed: () => providers.isEmpty
                    ? showProviderDialog(context, preset: ProviderPreset.openrouter)
                    : showProviderDialog(context, existing: providers.first),
              ),
            ),
          )
        else
        AntCard(
          padding: EdgeInsets.all(t.space.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Label('Default model'),
              Gap(t.space.lg),
              const DefaultModelPicker(),
              Gap(t.space.md),
              Text('Writes reports, extracts facts, scores importance and reads screenshots.',
                  style: t.typo.small.copyWith(color: t.muted)),
            ],
          ),
        ),
        Gap(t.space.xxxl),
        const Label('Providers'),
        Gap(t.space.md),
        ListPanel(children: [
          for (final p in providers)
            PanelRow(
              titleWidth: t.space.giant * 3,
              title: p.name,
              hint: detail(p),
              trailing: [
                if (models.any((m) => m.providerId == p.id))
                  const AntChip(label: 'Connected', tone: AntTone.ok)
                else
                  const AntChip(label: 'No models', tone: AntTone.warn),
                AntButton(
                  label: 'Models',
                  size: AntSize.sm,
                  onPressed: () => showProviderDialog(context, existing: p),
                ),
              ],
            ),
          for (final s in local)
            if (!urls.contains(s.baseUrl))
              PanelRow(
                titleWidth: t.space.giant * 3,
                title: s.name,
                hint: 'Detected at ${Uri.parse(s.baseUrl).authority} · stays on this Mac',
                trailing: [
                  const AntChip(label: 'Running', tone: AntTone.ok),
                  AntButton(
                    label: 'Add',
                    size: AntSize.sm,
                    onPressed: () => showProviderDialog(
                      context,
                      preset: ProviderPreset(ProviderKind.custom, s.name, s.baseUrl, s.protocol, 'Optional', needsKey: false),
                    ),
                  ),
                ],
              ),
          for (final preset in ProviderPreset.cloud)
            if (!kinds.contains(preset.kind))
              PanelRow(
                titleWidth: t.space.giant * 3,
                title: preset.name,
                hint: preset.kind == ProviderKind.openrouter ? 'One key for hundreds of models, with prices' : 'Direct API key',
                trailing: [
                  const AntChip(label: 'Not set'),
                  AntButton(label: 'Add key', size: AntSize.sm, onPressed: () => showProviderDialog(context, preset: preset)),
                ],
              ),
          PanelRow(
            titleWidth: t.space.giant * 3,
            title: 'Custom endpoint',
            hint: 'Any OpenAI-compatible or Ollama URL: localhost, your network, or a gateway',
            trailing: [
              AntButton(
                label: 'Add',
                size: AntSize.sm,
                icon: Icons.add,
                onPressed: () => showProviderDialog(context, preset: ProviderPreset.custom),
              ),
            ],
          ),
        ]),
        Gap(t.space.xxl),
        Disclosure(
          title: 'Customize per task',
          hint: 'Vision, Extraction and Reports use the default model unless you pick another',
          child: const _RouteOverrides(),
        ),
        Gap(t.space.xl),
        Row(children: [
          Icon(Icons.info_outline, size: t.icon.sm, color: t.muted),
          SizedBox(width: t.space.md),
          Expanded(
            child: Text(
              'Providers that aren’t on this Mac receive full evidence, including diffs and meeting details. '
              'Local models keep everything on this machine.',
              style: t.typo.small.copyWith(color: t.muted),
            ),
          ),
        ]),
      ],
    );
  }
}

class _RouteOverrides extends ConsumerWidget {
  const _RouteOverrides();

  static const _routes = [
    (LlmRoute.vision, 'Vision', 'Reads screenshots and images in notes'),
    (LlmRoute.extraction, 'Extraction', 'Importance, summaries, facts and win suggestions'),
    (LlmRoute.reports, 'Reports', 'Daily to quarterly reports and reviews'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final models = ref.watch(llmModelsProvider).value ?? const <Model>[];
    final providers = ref.watch(llmProvidersProvider).value ?? const <core.Provider>[];
    final routes = ref.watch(taskRoutesProvider).value ?? const <LlmRoute, String>{};
    final def = models.where((m) => m.id == routes[LlmRoute.defaultRoute]).firstOrNull;
    return ListPanel(children: [
      for (final (route, name, hint) in _routes)
        Builder(builder: (context) {
          final own = models.where((m) => m.id == routes[route]).firstOrNull;
          final effective = own ?? def;
          return PanelRow(
            title: name,
            hint: hint,
            trailing: [
              if (route == LlmRoute.vision && effective != null && !effective.vision)
                const AntChip(label: 'Can’t read images', tone: AntTone.warn),
              SelectButton<String?>(
                value: own?.id,
                options: [
                  (null, def == null ? 'Inherits default' : 'Inherits default (${def.modelName})'),
                  for (final m in models)
                    if (route != LlmRoute.vision || m.vision) (m.id, modelLabel(m, providers)),
                ],
                onChanged: (id) => runCmd(context, ref, setRouteCmd(route, id)),
              ),
            ],
          );
        }),
    ]);
  }
}
