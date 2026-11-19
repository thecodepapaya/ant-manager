/// Onboarding (SPEC §10): profile → identities → repos → optional sources → model (structured-output
/// probe + consent) → first import. Every step can be skipped; everything is editable later.
library;

import 'package:core/core.dart' hide Provider;
import 'package:core/core.dart' as core show Provider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui/ui.dart';

import '../../engine/setup_commands.dart';
import '../../shell/shell_state.dart';
import '../../state/providers.dart';
import '../settings/ai_models_tab.dart';
import '../settings/kit.dart';
import '../settings/provider_dialog.dart';
import '../settings/setup_providers.dart';
import '../sources/git_setup.dart';
import '../sources/source_form.dart';
import '../sources/sources_page.dart' show SourceTile;

enum _Step {
  profile('Profile'),
  identities('Identities'),
  repos('Repositories'),
  sources('Sources'),
  model('AI model'),
  import('First import');

  const _Step(this.label);
  final String label;
}

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});
  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  _Step _step = _Step.profile;
  final _maxReached = <_Step>{_Step.profile};
  bool _busy = false;

  late final _name = TextEditingController(text: ref.read(activeProfileProvider)?.name ?? 'Work');
  late final _scan = RepoScanController(ref);

  // Identities step.
  final _picked = <String>{};
  final _manual = <(String, String)>[];
  final _manualValue = TextEditingController();
  String _manualKind = 'email';
  bool _showManual = false;
  bool _identitiesReady = false;

  @override
  void initState() {
    super.initState();
    // Scan early: identities are suggested from repo authors.
    Future(() async {
      await _scan.checkGit();
      await _scan.scan();
      final h = await ref.read(engineProvider.future);
      final me = await h.runtime(gitGlobalEmailCmd());
      final authors = _scan.authors();
      final myName = authors.where((a) => a.$1 == me).firstOrNull?.$2;
      if (mounted) {
        setState(() {
          for (final (email, name, _) in authors) {
            if (email == me || (myName != null && name == myName)) _picked.add(email);
          }
          _identitiesReady = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _manualValue.dispose();
    _scan.dispose();
    super.dispose();
  }

  Future<void> _go(_Step s) async => setState(() {
        _step = s;
        _maxReached.add(s);
      });

  /// Saves the current step, then moves on. [skip] moves on without saving.
  Future<void> _next({bool skip = false}) async {
    if (_step == _Step.import) return _finish();
    setState(() => _busy = true);
    try {
      final h = await ref.read(engineProvider.future);
      if (!skip) {
        switch (_step) {
          case _Step.profile:
            final p = ref.read(activeProfileProvider);
            final n = _name.text.trim();
            if (p != null && n.isNotEmpty && n != p.name) await h.runtime(renameProfileCmd(p.id, n));
          case _Step.identities:
            for (final e in _picked) {
              await h.runtime(addIdentityCmd('email', e));
            }
            for (final (k, v) in _manual) {
              await h.runtime(addIdentityCmd(k, v));
            }
            _scan.autoSelect({..._picked, for (final (k, v) in _manual) if (k == 'email') v.toLowerCase()});
          case _Step.repos:
            await _scan.addSelected(existingRepoPaths(ref.read(sourcesProvider).value ?? const []));
          default:
        }
      } else if (_step == _Step.identities) {
        _scan.autoSelect(const {});
      }
      await _go(_Step.values[_step.index + 1]);
    } catch (e) {
      if (mounted) toast(context, errorText(e), tone: AntTone.err);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finish() async {
    await runCmd(context, ref, setSettingCmd(onboardingDoneSettingKey, 'true'));
    ref.read(shellSectionProvider.notifier).select(ShellSection.today);
    ref.invalidate(onboardingNeededProvider);
  }

  @override
  Widget build(BuildContext context) {
    return TokensScope(
      child: Builder(builder: (context) {
        final t = context.tokens;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Rail(step: _step, reached: _maxReached, onPick: _go, onSkipAll: _finish),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: t.space.huge, vertical: t.space.giant + t.space.md),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: t.density.dialogWidth * 1.4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ..._body(context),
                        Gap(t.space.huge),
                        Row(children: [
                          if (_step != _Step.profile)
                            AntButton.ghost(
                              label: 'Back',
                              size: AntSize.lg,
                              onPressed: () => _go(_Step.values[_step.index - 1]),
                            ),
                          const Spacer(),
                          if (_step != _Step.profile && _step != _Step.import) ...[
                            AntButton.ghost(label: 'Skip', size: AntSize.lg, onPressed: _busy ? null : () => _next(skip: true)),
                            SizedBox(width: t.space.md),
                          ],
                          AntButton.primary(
                            size: AntSize.lg,
                            label: _busy
                                ? 'Saving…'
                                : switch (_step) {
                                    _Step.profile => 'Get started',
                                    _Step.import => 'Open Today',
                                    _ => 'Continue',
                                  },
                            onPressed: _busy ? null : _next,
                          ),
                        ]),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _heading(BuildContext context, String title, String sub) {
    final t = context.tokens;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: t.typo.display.copyWith(color: t.text)),
      Gap(t.space.sm),
      Text(sub, style: t.typo.body.copyWith(color: t.muted)),
      Gap(t.space.huge - t.space.xs),
    ]);
  }

  List<Widget> _body(BuildContext context) {
    final t = context.tokens;
    switch (_step) {
      case _Step.profile:
        return [
          _heading(
            context,
            'Your work, quietly remembered.',
            'Ant Manager collects evidence of your work (commits, PRs, meetings, tickets, notes) and turns it into '
                'honest daily, weekly and review-ready reports. Everything stays on this Mac unless you choose a cloud model.',
          ),
          AntTextField(controller: _name, label: 'Name this profile', size: AntSize.lg, autofocus: true, onSubmitted: (_) => _next()),
          const Hint('Profiles keep separate data, sources and models, e.g. Work and Side projects.'),
        ];
      case _Step.identities:
        final authors = _scan.authors();
        return [
          _heading(context, 'Which of these are you?',
              'We found these people in your repos. Evidence from the ones you tick counts as yours.'),
          ListenableBuilder(
            listenable: _scan,
            builder: (context, _) => ListPanel(children: [
              if (!_identitiesReady)
                const PanelRow(title: 'Looking through your repos…')
              else if (authors.isEmpty && _manual.isEmpty)
                const PanelRow(title: 'No commit authors found', hint: 'Add the email you commit with below.'),
              for (final (email, name, repos) in authors.where((a) => !a.$1.contains('[bot]')).take(8))
                PanelRow(
                  dense: true,
                  onTap: () => setState(() => _picked.contains(email) ? _picked.remove(email) : _picked.add(email)),
                  leading: AntCheckbox(
                    value: _picked.contains(email),
                    onChanged: (v) => setState(() => v ? _picked.add(email) : _picked.remove(email)),
                  ),
                  title: name,
                  hint: email,
                  hintMono: true,
                  trailing: [Text('$repos repo${repos == 1 ? '' : 's'}', style: t.typo.small.copyWith(color: t.muted))],
                ),
              for (final (k, v) in _manual)
                PanelRow(
                  dense: true,
                  leading: const AntCheckbox(value: true, onChanged: null),
                  title: v,
                  hint: identityKinds[k],
                  trailing: [
                    AntIconButton(
                      icon: Icons.close,
                      tooltip: 'Remove',
                      size: AntSize.sm,
                      onPressed: () => setState(() => _manual.remove((k, v))),
                    ),
                  ],
                ),
            ]),
          ),
          Gap(t.space.md),
          if (!_showManual)
            Row(children: [
              AntButton.ghost(label: 'Add email or username', icon: Icons.add, onPressed: () => setState(() => _showManual = true)),
            ])
          else
            Row(children: [
              SelectButton<String>(
                value: _manualKind,
                options: [for (final e in identityKinds.entries) (e.key, e.value)],
                onChanged: (v) => setState(() => _manualKind = v),
              ),
              SizedBox(width: t.space.md),
              Expanded(
                child: AntTextField(
                  controller: _manualValue,
                  autofocus: true,
                  mono: true,
                  placeholder: _manualKind == 'email' ? 'you@company.com' : 'username',
                  onSubmitted: (_) => _addManual(),
                ),
              ),
              SizedBox(width: t.space.md),
              AntButton(label: 'Add', onPressed: _addManual),
            ]),
        ];
      case _Step.repos:
        return [
          _heading(
            context,
            'Pick the repos to watch',
            _scan.roots.isEmpty
                ? 'Add the folder where you keep your code. New repos there will be suggested automatically.'
                : 'Scanned ${_scan.roots.map(tildePath).join(' and ')}. New repos there will be suggested automatically.',
          ),
          RepoPicker(c: _scan, existing: existingRepoPaths(ref.watch(sourcesProvider).value ?? const [])),
        ];
      case _Step.sources:
        final connected = {
          for (final s in ref.watch(sourcesProvider).value ?? const <SourceStatus>[])
            if (isConnector(s.row.kind) && s.row.enabled) SourceOption.of(s.row),
        };
        return [
          _heading(context, 'Connect more sources', 'Optional. Catches the work local git can’t see: reviews, meetings, tickets.'),
          TileGrid(
            minWidth: t.gridMinTile * 0.95,
            gap: t.space.md,
            children: [
              for (final o in SourceOption.available)
                if (o != SourceOption.git)
                  SourceTile(option: o, connected: connected.contains(o), onPressed: () => connectSource(context, o)),
            ],
          ),
        ];
      case _Step.model:
        return [
          _heading(
            context,
            'Choose a model',
            'One model writes everything. A local model keeps it all on this Mac; a cloud model writes best. '
                'You can customize per task later in Settings.',
          ),
          const _ModelStep(),
        ];
      case _Step.import:
        return [
          _heading(context, 'You’re set.', 'Importing the last 30 days so your timeline isn’t empty.'),
          const _ImportProgress(),
          Gap(t.space.lg),
          Callout(
            warn: false,
            icon: Icons.auto_awesome,
            child: Text('Your first daily report is drafted at 18:00 on weekdays. Add a note any time with '
                '${Theme.of(context).platform == TargetPlatform.macOS ? '⌥⌘N' : 'Ctrl+Alt+N'}.'),
          ),
        ];
    }
  }

  void _addManual() {
    final v = _manualValue.text.trim();
    if (v.isEmpty) return;
    setState(() {
      _manual.add((_manualKind, v));
      _manualValue.clear();
    });
  }
}

class _Rail extends StatelessWidget {
  const _Rail({required this.step, required this.reached, required this.onPick, required this.onSkipAll});
  final _Step step;
  final Set<_Step> reached;
  final ValueChanged<_Step> onPick;
  final VoidCallback onSkipAll;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final numSize = t.icon.lg;
    return Container(
      width: t.gridMinTile,
      padding: EdgeInsets.symmetric(horizontal: t.space.xxl, vertical: t.space.huge - t.space.xs),
      decoration: BoxDecoration(
        color: t.bgSidebar,
        border: Border(right: BorderSide(color: t.border, width: t.stroke.hairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: t.space.md + t.space.xxs),
            child: Row(children: [
              Container(
                width: t.density.controlMd,
                height: t.density.controlMd,
                decoration: BoxDecoration(color: t.text, borderRadius: t.radii.brMd),
                padding: EdgeInsets.all(t.space.sm),
                child: Image.asset('assets/tray/tray_icon.png', color: t.bg),
              ),
              SizedBox(width: t.space.md + t.space.xxs),
              Text('Ant Manager', style: t.typo.bodyStrong.copyWith(color: t.text, fontWeight: FontWeight.w600)),
            ]),
          ),
          Gap(t.space.xxxl),
          for (final s in _Step.values)
            Padding(
              padding: EdgeInsets.only(bottom: t.space.xs),
              child: AntInteractive(
                onTap: reached.contains(s) ? () => onPick(s) : null,
                semanticLabel: s.label,
                selected: s == step,
                builder: (context, st) {
                  final on = s == step;
                  final done = s.index < step.index;
                  return Container(
                    height: t.density.controlLg + t.space.xs,
                    padding: EdgeInsets.symmetric(horizontal: t.space.md + t.space.xxs),
                    decoration: BoxDecoration(
                      color: on ? t.active : (st.hovered && st.enabled ? t.hover : t.hover.withValues(alpha: 0)),
                      borderRadius: t.radii.brMd,
                    ),
                    child: Row(children: [
                      Container(
                        width: numSize,
                        height: numSize,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: done ? t.accent : t.accent.withValues(alpha: 0),
                          border: Border.all(
                            color: done || on ? t.accent : t.borderStronger,
                            width: t.stroke.hairline,
                          ),
                        ),
                        child: done
                            ? Icon(Icons.check, size: t.icon.xs, color: t.onAccent)
                            : Text('${s.index + 1}', style: t.typo.caption.copyWith(color: on ? t.accentText : t.muted)),
                      ),
                      SizedBox(width: t.space.lg),
                      Text(s.label, style: t.typo.body.copyWith(color: on ? t.text : (done ? t.textSoft : t.muted))),
                    ]),
                  );
                },
              ),
            ),
          const Spacer(),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: t.space.md + t.space.xxs),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Every step can be skipped and changed later in Settings.',
                  style: t.typo.small.copyWith(color: t.muted)),
              Gap(t.space.md),
              AntButton.ghost(label: 'Skip setup', size: AntSize.sm, onPressed: onSkipAll),
            ]),
          ),
        ],
      ),
    );
  }
}

class _ModelStep extends ConsumerWidget {
  const _ModelStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final local = ref.watch(localServersProvider);
    final models = ref.watch(llmModelsProvider).value ?? const <Model>[];
    final providers = ref.watch(llmProvidersProvider).value ?? const <core.Provider>[];
    final urls = {for (final p in providers) p.baseUrl};
    final kinds = {for (final p in providers) p.kind};

    Widget option(String title, String hint, VoidCallback onTap, {Widget? chip, bool recommended = false}) => PanelRow(
          onTap: onTap,
          leading: Icon(recommended ? Icons.auto_awesome : Icons.circle_outlined, size: t.icon.md, color: recommended ? t.accentText : t.muted),
          title: title,
          hint: hint,
          trailing: [?chip, Icon(Icons.chevron_right, size: t.icon.md, color: t.muted)],
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (models.isNotEmpty) ...[
          AntCard(
            padding: EdgeInsets.all(t.space.xl),
            child: Row(children: [
              const Expanded(child: DefaultModelPicker()),
              const AntChip(label: 'Structured output verified', tone: AntTone.ok, icon: Icons.check),
            ]),
          ),
          Gap(t.space.xl),
          const Label('Or add another'),
          Gap(t.space.md),
        ],
        ListPanel(children: [
          if (local.isLoading) const PanelRow(title: 'Looking for local models…', hint: 'Ollama on :11434, LM Studio on :1234'),
          for (final s in local.value ?? const <LocalServer>[])
            if (!urls.contains(s.baseUrl))
              option(
                '${s.name} (local)',
                'Detected at ${Uri.parse(s.baseUrl).authority} · full privacy, nothing leaves this Mac',
                () => showProviderDialog(context,
                    preset: ProviderPreset(ProviderKind.custom, s.name, s.baseUrl, s.protocol, 'Optional', needsKey: false)),
                chip: const AntChip(label: 'Detected', tone: AntTone.ok),
              ),
          for (final p in ProviderPreset.cloud)
            if (!kinds.contains(p.kind))
              option(
                p.name,
                p.kind == ProviderKind.openrouter
                    ? 'Recommended: one key for Claude, GPT, Gemini and open models, with prices'
                    : 'Use your ${p.name} API key',
                () => showProviderDialog(context, preset: p),
                recommended: p.kind == ProviderKind.openrouter,
              ),
          option('Custom endpoint', 'A model server on your network or a company gateway',
              () => showProviderDialog(context, preset: ProviderPreset.custom)),
        ]),
        Gap(t.space.md),
        Text('Each model is tested for native structured output before it’s used. Providers that aren’t on this Mac '
            'ask for your consent first.', style: t.typo.small.copyWith(color: t.muted)),
      ],
    );
  }
}

class _ImportProgress extends ConsumerWidget {
  const _ImportProgress();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final sources = [
      for (final s in ref.watch(sourcesProvider).value ?? const <SourceStatus>[])
        if (isConnector(s.row.kind) && s.row.enabled) s,
    ];
    final counts = ref.watch(evidenceBySourceProvider).value ?? const <String, int>{};
    if (sources.isEmpty) {
      return const ListPanel(children: [
        PanelRow(title: 'No sources connected', hint: 'That’s fine: add notes from Today, or connect sources later.'),
      ]);
    }
    return AntCard(
      padding: EdgeInsets.all(t.space.xl),
      child: Column(children: [
        for (final s in sources)
          Padding(
            padding: EdgeInsets.symmetric(vertical: t.space.sm),
            child: Row(children: [
              SizedBox(
                width: t.gridMinTile * 0.6,
                child: Text(s.row.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.typo.body.copyWith(color: t.text)),
              ),
              Expanded(
                child: Bar((s.lastError?.isNotEmpty ?? false) || s.lastSuccessAt != null ? 1 : null),
              ),
              SizedBox(
                width: t.space.giant * 2,
                child: Text(
                  (s.lastError?.isNotEmpty ?? false) ? 'error' : '${counts[s.row.id] ?? 0} items',
                  textAlign: TextAlign.right,
                  style: t.typo.mono.copyWith(color: (s.lastError?.isNotEmpty ?? false) ? t.dangerText : t.muted),
                ),
              ),
            ]),
          ),
      ]),
    );
  }
}
