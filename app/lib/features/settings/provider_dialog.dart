/// Provider setup (SPEC §6): key / URL / protocol, advanced networking, Test connection → live
/// model list → add a model only after the structured-output probe passes (#70). Non-localhost
/// providers get a one-time consent notice before the first request (#74).
library;

import 'package:core/core.dart' hide Provider;
import 'package:core/core.dart' as core show Provider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui/ui.dart';

import '../../engine/setup_commands.dart';
import '../../state/providers.dart';
import 'kit.dart';
import 'setup_providers.dart';

/// Defaults per provider kind.
class ProviderPreset {
  const ProviderPreset(this.kind, this.name, this.baseUrl, this.protocol, this.keyHint, {this.needsKey = true});
  final ProviderKind kind;
  final String name;
  final String baseUrl;
  final ProviderProtocol protocol;
  final String keyHint;
  final bool needsKey;

  static const openrouter = ProviderPreset(
      ProviderKind.openrouter, 'OpenRouter', 'https://openrouter.ai/api/v1', ProviderProtocol.openai, 'sk-or-v1-…');
  static const openai =
      ProviderPreset(ProviderKind.openai, 'OpenAI', 'https://api.openai.com/v1', ProviderProtocol.openai, 'sk-…');
  static const anthropic = ProviderPreset(
      ProviderKind.anthropic, 'Anthropic', 'https://api.anthropic.com', ProviderProtocol.native, 'sk-ant-…');
  static const gemini = ProviderPreset(ProviderKind.gemini, 'Gemini', 'https://generativelanguage.googleapis.com',
      ProviderProtocol.native, 'AIza…');
  static const custom = ProviderPreset(
      ProviderKind.custom, 'Custom endpoint', 'http://localhost:11434', ProviderProtocol.ollama, 'Optional',
      needsKey: false);

  static const cloud = [openrouter, openai, anthropic, gemini];
}

/// Shows the one-time consent notice for [baseUrl]. True when the user agreed.
Future<bool> askConsent(BuildContext context, String providerName, String baseUrl) async {
  final host = Uri.tryParse(baseUrl)?.host ?? baseUrl;
  final ok = await showAntDialog<bool>(
    context,
    builder: (context) => AntDialog(
      title: 'Send your evidence to $host?',
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('$providerName isn’t on this Mac. Models there receive your full evidence for each generation: '
              'commit diffs, PR text, meeting details, transcripts and screenshots.'),
          Gap(context.tokens.space.md),
          Text('Their privacy policy applies. You’ll be asked once for this provider.'),
        ],
      ),
      actions: [
        AntButton.ghost(label: 'Cancel', onPressed: () => Navigator.of(context).pop(false)),
        AntButton.primary(label: 'I understand', onPressed: () => Navigator.of(context).pop(true)),
      ],
    ),
  );
  return ok ?? false;
}

/// Opens the provider dialog for a new provider from [preset], or for [existing].
Future<void> showProviderDialog(BuildContext context, {ProviderPreset? preset, core.Provider? existing, String? baseUrl}) =>
    showAntDialog<void>(
      context,
      barrierDismissible: false,
      builder: (_) => ProviderDialog(preset: preset ?? ProviderPreset.custom, existing: existing, baseUrl: baseUrl),
    );

class ProviderDialog extends ConsumerStatefulWidget {
  const ProviderDialog({super.key, required this.preset, this.existing, this.baseUrl});
  final ProviderPreset preset;
  final core.Provider? existing;
  final String? baseUrl;

  @override
  ConsumerState<ProviderDialog> createState() => _ProviderDialogState();
}

class _ProviderDialogState extends ConsumerState<ProviderDialog> {
  late final _name = TextEditingController(text: widget.existing?.name ?? widget.preset.name);
  late final _url = TextEditingController(text: widget.existing?.baseUrl ?? widget.baseUrl ?? widget.preset.baseUrl);
  final _key = TextEditingController();
  final _headers = TextEditingController();
  late final _ca = TextEditingController(text: widget.existing?.customCaPem ?? '');
  late final _timeout = TextEditingController(text: '${widget.existing?.timeoutSeconds ?? 120}');
  final _manual = TextEditingController();
  final _filter = TextEditingController();
  late ProviderProtocol _protocol = widget.existing?.protocol ?? widget.preset.protocol;
  late bool _insecure = widget.existing?.allowSelfSigned ?? false;
  late String? _id = widget.existing?.id;

  bool _testing = false;
  String? _error;
  List<ModelInfo>? _available;
  final _adding = <String>{};
  final _rowErrors = <String, String>{};

  bool get _custom => (widget.existing?.kind ?? widget.preset.kind) == ProviderKind.custom;
  ProviderKind get _kind => widget.existing?.kind ?? widget.preset.kind;

  @override
  void dispose() {
    for (final c in [_name, _url, _key, _headers, _ca, _timeout, _manual, _filter]) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, String>? _parseHeaders() {
    final lines = _headers.text.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return widget.existing == null ? const {} : null; // null = keep stored
    return {
      for (final l in lines)
        if (l.contains(':')) l.substring(0, l.indexOf(':')).trim(): l.substring(l.indexOf(':') + 1).trim(),
    };
  }

  /// Saves the provider, asks for consent when needed, then lists models.
  Future<void> _test() async {
    final url = _url.text.trim();
    if (Uri.tryParse(url)?.hasScheme != true) {
      setState(() => _error = 'Enter a full URL, e.g. https://… or http://host:port');
      return;
    }
    if (widget.preset.needsKey && widget.existing == null && _key.text.trim().isEmpty) {
      setState(() => _error = 'Paste your API key first');
      return;
    }
    setState(() {
      _testing = true;
      _error = null;
    });
    try {
      final h = await ref.read(engineProvider.future);
      final (id, consented) = await h.runtime(saveProviderCmd(
        id: _id,
        kind: _kind,
        name: _name.text.trim().isEmpty ? widget.preset.name : _name.text.trim(),
        baseUrl: url,
        protocol: _protocol,
        apiKey: _key.text.trim().isEmpty ? null : _key.text.trim(),
        headers: _parseHeaders(),
        customCaPem: _ca.text,
        allowSelfSigned: _insecure,
        timeoutSeconds: int.tryParse(_timeout.text.trim()) ?? 120,
      ));
      _id = id;
      if (requiresConsent(url) && !consented) {
        if (!mounted) return;
        final ok = await askConsent(context, _name.text.trim(), url);
        if (!ok) {
          setState(() => _error = 'Nothing was sent. Consent is needed before using a provider that isn’t on this Mac.');
          return;
        }
        await h.runtime(setProviderConsentCmd(_id!));
      }
      final models = await h.runtime(listProviderModelsCmd(_id!));
      if (mounted) setState(() => _available = models);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _addModel(String name, ModelInfo? info) async {
    if (_id == null || name.trim().isEmpty) return;
    setState(() {
      _adding.add(name);
      _rowErrors.remove(name);
    });
    try {
      final h = await ref.read(engineProvider.future);
      await h.runtime(addModelCmd(_id!, name.trim(), info: info));
      if (mounted) toast(context, '$name passed the structured-output check', tone: AntTone.ok);
    } catch (e) {
      if (mounted) setState(() => _rowErrors[name] = errorText(e));
    } finally {
      if (mounted) setState(() => _adding.remove(name));
    }
  }

  String _modelHint(ModelInfo m) => [
        if (m.contextLength != null) '${(m.contextLength! / 1000).round()}k context',
        if (m.inputPricePerMTok != null) '\$${m.inputPricePerMTok!.toStringAsFixed(2)} / \$${m.outputPricePerMTok?.toStringAsFixed(2) ?? '?'} per M tok',
        if (m.vision) 'vision',
      ].join(' · ');

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final url = _url.text.trim();
    final added = [
      for (final m in ref.watch(llmModelsProvider).value ?? const <Model>[])
        if (m.providerId == _id) m,
    ];
    final addedNames = {for (final m in added) m.modelName};
    final q = _filter.text.trim().toLowerCase();
    final list = [
      for (final m in _available ?? const <ModelInfo>[])
        if (q.isEmpty || m.name.toLowerCase().contains(q)) m,
    ];
    final plainHttp = Uri.tryParse(url)?.scheme == 'http' && requiresConsent(url); // Uri lowercases the scheme

    return WideDialog(
      title: widget.existing?.name ?? (_custom ? 'Add a custom endpoint' : 'Connect ${widget.preset.name}'),
      subtitle: _custom
          ? 'Any OpenAI-compatible or Ollama server: this Mac, a box on your network, or a remote gateway.'
          : 'Keys are stored in your Keychain, never in a file or backup.',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_custom) ...[
            Row(children: [
              Expanded(child: AntTextField(controller: _name, label: 'Name', placeholder: 'Home GPU box')),
              SizedBox(width: t.space.lg),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Protocol', style: t.typo.label.copyWith(color: t.text2)),
                SizedBox(height: t.space.sm),
                SelectButton<ProviderProtocol>(
                  value: _protocol,
                  options: const [
                    (ProviderProtocol.ollama, 'Ollama'),
                    (ProviderProtocol.openai, 'OpenAI-compatible'),
                  ],
                  onChanged: (v) => setState(() => _protocol = v),
                ),
              ]),
            ]),
            Gap(t.space.lg),
            AntTextField(
              controller: _url,
              label: 'Base URL',
              mono: true,
              placeholder: _protocol == ProviderProtocol.ollama ? 'http://192.168.1.20:11434' : 'http://gpu-box.local:1234/v1',
              onChanged: (_) => setState(() {}),
            ),
            Hint(_protocol == ProviderProtocol.ollama
                ? 'The server root; Ant Manager calls /api/tags and /api/chat.'
                : 'Include /v1; Ant Manager calls /models and /chat/completions.'),
            Gap(t.space.lg),
          ],
          AntTextField(
            controller: _key,
            label: _custom ? 'API key (optional)' : 'API key',
            placeholder: widget.existing?.credentialRef != null ? 'Saved in Keychain · leave blank to keep' : widget.preset.keyHint,
            obscureText: true,
            mono: true,
            autofocus: !_custom && widget.existing == null,
            onSubmitted: (_) => _test(),
          ),
          if (plainHttp) ...[
            Gap(t.space.md),
            const Callout(child: Text('Plain HTTP to another machine: your evidence travels unencrypted on the network.')),
          ],
          Gap(t.space.lg),
          Disclosure(
            title: 'Advanced',
            hint: 'Headers, custom CA, TLS, timeout',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!_custom) ...[
                  AntTextField(controller: _url, label: 'Base URL', mono: true, onChanged: (_) => setState(() {})),
                  Gap(t.space.lg),
                ],
                AntTextField(
                  controller: _headers,
                  label: 'Extra headers',
                  placeholder: widget.existing != null && widget.existing!.headers != '{}'
                      ? 'Saved · type to replace (Name: value per line)'
                      : 'X-Api-Version: 2\nX-Team: mine',
                  mono: true,
                  minLines: 2,
                  maxLines: 4,
                ),
                const Hint('One per line. Values are stored in your Keychain.'),
                Gap(t.space.lg),
                AntTextField(
                  controller: _ca,
                  label: 'Trust a custom CA certificate (PEM)',
                  placeholder: '-----BEGIN CERTIFICATE-----',
                  mono: true,
                  minLines: 2,
                  maxLines: 5,
                ),
                Gap(t.space.lg),
                Row(children: [
                  AntSwitch(
                    value: _insecure,
                    semanticLabel: 'Disable TLS verification',
                    onChanged: (v) => setState(() => _insecure = v),
                  ),
                  SizedBox(width: t.space.md),
                  Text('Disable TLS verification', style: t.typo.body.copyWith(color: t.text)),
                ]),
                if (_insecure) ...[
                  Gap(t.space.md),
                  const Callout(
                    child: Text('Any certificate will be accepted, so someone on the network could read or change '
                        'what is sent. Prefer trusting your CA above.'),
                  ),
                ],
                Gap(t.space.lg),
                SizedBox(
                  width: t.density.menuMinWidth,
                  child: AntTextField(controller: _timeout, label: 'Timeout (seconds)', mono: true),
                ),
                const Hint('Local models can take a while to load.'),
              ],
            ),
          ),
          if (_error != null) ...[
            Gap(t.space.md),
            Text(_error!, style: t.typo.small.copyWith(color: t.dangerText)),
          ],
          if (added.isNotEmpty) ...[
            Gap(t.space.xl),
            const Label('Added models'),
            Gap(t.space.md),
            ListPanel(children: [
              for (final m in added)
                PanelRow(
                  dense: true,
                  title: m.modelName,
                  hint: m.vision ? 'Vision · structured output verified' : 'Structured output verified',
                  trailing: [
                    AntIconButton(
                      icon: Icons.close,
                      tooltip: 'Remove model',
                      size: AntSize.sm,
                      onPressed: () => runCmd(context, ref, removeModelCmd(m.id)),
                    ),
                  ],
                ),
            ]),
          ],
          if (_available != null) ...[
            Gap(t.space.xl),
            Label('Available models',
                trailing: Text('${_available!.length} found · each is checked for structured output before it’s added',
                    style: t.typo.small.copyWith(color: t.muted))),
            Gap(t.space.md),
            if (_available!.length > 8) ...[
              AntTextField(controller: _filter, placeholder: 'Filter models', leadingIcon: Icons.search, onChanged: (_) => setState(() {})),
              Gap(t.space.md),
            ],
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: t.density.dialogWidth * 0.8),
              child: SingleChildScrollView(
                child: ListPanel(children: [
                  if (list.isEmpty) const PanelRow(title: 'No models listed', hint: 'Type a model name below.'),
                  for (final m in list.take(200))
                    PanelRow(
                      dense: true,
                      title: m.name,
                      hint: _rowErrors[m.name] ?? _modelHint(m),
                      trailing: [
                        if (addedNames.contains(m.name))
                          const AntChip(label: 'Added', tone: AntTone.ok)
                        else
                          AntButton(
                            label: _adding.contains(m.name) ? 'Checking…' : 'Add',
                            size: AntSize.sm,
                            onPressed: _adding.contains(m.name) ? null : () => _addModel(m.name, m),
                          ),
                      ],
                    ),
                ]),
              ),
            ),
            Gap(t.space.md),
            Row(children: [
              Expanded(
                child: AntTextField(
                  controller: _manual,
                  placeholder: 'Or type a model name, e.g. qwen2.5:14b',
                  mono: true,
                  onSubmitted: (v) => _addModel(v, null),
                ),
              ),
              SizedBox(width: t.space.md),
              AntButton(
                label: _adding.contains(_manual.text.trim()) ? 'Checking…' : 'Add',
                onPressed: () => _addModel(_manual.text, null),
              ),
            ]),
            if (_rowErrors[_manual.text.trim()] != null)
              Padding(
                padding: EdgeInsets.only(top: t.space.sm),
                child: Text(_rowErrors[_manual.text.trim()]!, style: t.typo.small.copyWith(color: t.dangerText)),
              ),
          ],
        ],
      ),
      leadingActions: [
        if (_id != null)
          AntButton(
            label: 'Remove provider',
            variant: AntButtonVariant.danger,
            onPressed: () async {
              // Stays open on failure (runCmd shows the error), #139.
              if (await runCmd(context, ref, removeProviderCmd(_id!)) != null && context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
      ],
      actions: [
        AntButton.ghost(label: 'Done', onPressed: () => Navigator.of(context).pop()),
        AntButton.primary(
          label: _testing ? 'Connecting…' : (_available == null ? 'Test connection' : 'Test again'),
          onPressed: _testing ? null : _test,
        ),
      ],
    );
  }
}
