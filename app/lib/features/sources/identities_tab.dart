/// Identities editor (SPEC §4): emails and logins that make evidence "yours", suggested from repos
/// and connected accounts.
library;

import 'dart:convert';

import 'package:core/core.dart' hide Provider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui/ui.dart';

import '../../engine/setup_commands.dart';
import '../../state/providers.dart';
import '../settings/kit.dart';
import '../settings/setup_providers.dart';

/// (kind, value, label shown, where it was seen)
typedef IdentitySuggestion = (String, String, String, String);

/// Suggestions from the repos already added (commit authors) and from source configs (logins).
Future<List<IdentitySuggestion>> suggestIdentities(WidgetRef ref) async {
  final h = await ref.read(engineProvider.future);
  final sources = await h.db.select(h.db.sources).get();
  final have = {for (final i in await h.db.select(h.db.identities).get()) '${i.kind}:${i.value.toLowerCase()}'};
  final repoPaths = <String>[];
  final out = <IdentitySuggestion>[];
  void add(String kind, String value, String label, String where) {
    final k = '$kind:${value.toLowerCase()}';
    if (have.add(k)) out.add((kind, value, label, where));
  }

  for (final s in sources.where((s) => s.enabled)) {
    final c = jsonDecode(s.config) as Map<String, Object?>;
    switch (s.kind) {
      case SourceKind.gitRepo:
        if (c['path'] is String) repoPaths.add(c['path']! as String);
      case SourceKind.github || SourceKind.githubEnterprise:
        if (c['login'] is String) add('github_login', c['login']! as String, '@${c['login']}', s.name);
      case SourceKind.gitlab:
        if (c['username'] is String) add('gitlab_user', c['username']! as String, '@${c['username']}', s.name);
      case SourceKind.jira:
        if (c['email'] is String) add('email', c['email']! as String, c['email']! as String, s.name);
      default:
    }
  }
  if (repoPaths.isNotEmpty) {
    final scans = await h.runtime(scanReposCmd(repoPaths));
    final byEmail = <String, (String, int)>{};
    for (final r in scans) {
      for (final e in r.authors.entries) {
        byEmail[e.key] = (e.value.$1, (byEmail[e.key]?.$2 ?? 0) + 1);
      }
    }
    final sorted = byEmail.entries.toList()..sort((a, b) => b.value.$2.compareTo(a.value.$2));
    for (final e in sorted) {
      add('email', e.key, '${e.value.$1} · ${e.key}', '${e.value.$2} repo${e.value.$2 == 1 ? '' : 's'}');
    }
  }
  return out;
}

class IdentitiesTab extends ConsumerStatefulWidget {
  const IdentitiesTab({super.key});
  @override
  ConsumerState<IdentitiesTab> createState() => _IdentitiesTabState();
}

class _IdentitiesTabState extends ConsumerState<IdentitiesTab> {
  final _value = TextEditingController();
  String _kind = 'email';
  List<IdentitySuggestion>? _suggestions;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final s = await suggestIdentities(ref);
      if (mounted) setState(() => _suggestions = s);
    } catch (_) {
      if (mounted) setState(() => _suggestions = const []);
    }
  }

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  Future<void> _add(String kind, String value) async {
    await runCmd(context, ref, addIdentityCmd(kind, value));
    _value.clear();
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final ids = ref.watch(identitiesProvider).value ?? const <Identity>[];
    return PageBody(
      maxWidth: t.narrowPage,
      children: [
        Label('Your identities',
            trailing: Text('Evidence from these counts as yours.', style: t.typo.small.copyWith(color: t.muted))),
        Gap(t.space.md),
        ListPanel(children: [
          if (ids.isEmpty)
            const PanelRow(title: 'No identities yet', hint: 'Add the emails you commit with and your usernames.'),
          for (final i in ids)
            PanelRow(
              dense: true,
              leading: SizedBox(width: t.space.giant * 2.5, child: AntChip(label: identityKinds[i.kind] ?? i.kind)),
              title: i.value,
              trailing: [
                AntIconButton(
                  icon: Icons.close,
                  tooltip: 'Remove',
                  size: AntSize.sm,
                  onPressed: () async {
                    await runCmd(context, ref, removeIdentityCmd(i.id));
                    await _refresh();
                  },
                ),
              ],
            ),
          Padding(
            padding: EdgeInsets.all(t.space.lg),
            child: Row(
              children: [
                SelectButton<String>(
                  value: _kind,
                  options: [for (final e in identityKinds.entries) (e.key, e.value)],
                  onChanged: (v) => setState(() => _kind = v),
                ),
                SizedBox(width: t.space.md),
                Expanded(
                  child: AntTextField(
                    controller: _value,
                    placeholder: _kind == 'email' ? 'you@company.com' : 'username',
                    mono: true,
                    onSubmitted: (v) => _add(_kind, v),
                  ),
                ),
                SizedBox(width: t.space.md),
                AntButton(label: 'Add', icon: Icons.add, onPressed: () => _add(_kind, _value.text)),
              ],
            ),
          ),
        ]),
        Gap(t.space.xxxl),
        Label('Suggested',
            trailing: Text('From your repos and connected accounts', style: t.typo.small.copyWith(color: t.muted))),
        Gap(t.space.md),
        ListPanel(children: [
          if (_suggestions == null)
            const PanelRow(title: 'Looking at your repos…')
          else if (_suggestions!.isEmpty)
            const PanelRow(title: 'No suggestions', hint: 'Add repos or accounts in Sources to get suggestions.')
          else
            for (final (kind, value, label, where) in _suggestions!)
              PanelRow(
                dense: true,
                title: label,
                hint: where,
                trailing: [
                  AntButton(label: 'This is me', size: AntSize.sm, icon: Icons.add, onPressed: () => _add(kind, value)),
                ],
              ),
        ]),
        Gap(t.space.lg),
        Text('Tip: commits from bots (ci@, noreply) aren’t you; leave them out.',
            style: t.typo.small.copyWith(color: t.muted)),
      ],
    );
  }
}
