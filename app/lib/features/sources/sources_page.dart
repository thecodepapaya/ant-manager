/// Sources screen (SPEC §5): connected sources with health and Sync now, add flows,
/// transcript import, identities and curation rules.
library;

import 'dart:convert';
import 'dart:io';

import 'package:core/core.dart' hide Provider;
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:ui/ui.dart';

import '../../engine/commands.dart';
import '../../state/providers.dart';
import '../settings/kit.dart';
import '../settings/setup_providers.dart';
import 'git_setup.dart';
import 'identities_tab.dart';
import 'rules_tab.dart';
import 'source_form.dart';

enum _Tab { sources, identities, rules }

class SourcesPage extends ConsumerStatefulWidget {
  const SourcesPage({super.key});
  @override
  ConsumerState<SourcesPage> createState() => _SourcesPageState();
}

class _SourcesPageState extends ConsumerState<SourcesPage> {
  _Tab _tab = _Tab.sources;

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(activeProfileProvider);
    final paused = ref.watch(pausedProvider).value ?? false;
    return TokensScope(
      child: Builder(builder: (context) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageTopBar(
              title: 'Sources',
              center: AntTabs<_Tab>(
                value: _tab,
                onChanged: (v) => setState(() => _tab = v),
                tabs: const [
                  AntTab(value: _Tab.sources, label: 'Sources'),
                  AntTab(value: _Tab.identities, label: 'Identities'),
                  AntTab(value: _Tab.rules, label: 'Rules'),
                ],
              ),
              subtitle: paused
                  ? 'Collection paused'
                  : '${profile?.name ?? ''} profile · syncs every 15 min while the app runs',
              actions: [
                if (_tab == _Tab.sources) ...[
                  AntButton.ghost(
                    label: 'Sync now',
                    icon: Icons.sync,
                    onPressed: () => runCmd(context, ref, syncNowCmd(), done: 'Syncing all sources'),
                  ),
                  AntButton(label: 'Add source', icon: Icons.add, onPressed: () => _addSource(context)),
                ],
              ],
            ),
            Expanded(
              child: switch (_tab) {
                _Tab.sources => const _SourcesTab(),
                _Tab.identities => const IdentitiesTab(),
                _Tab.rules => const RulesTab(),
              },
            ),
          ],
        );
      }),
    );
  }
}

Future<void> _addSource(BuildContext context) async {
  final option = await showAntDialog<SourceOption>(context, builder: (_) => const _AddSourceDialog());
  if (option != null && context.mounted) await connectSource(context, option);
}

/// Grid of connectable kinds (onboarding "Connect more sources" style).
class _AddSourceDialog extends StatelessWidget {
  const _AddSourceDialog();
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return WideDialog(
      title: 'Add a source',
      subtitle: 'Catches the work local git can’t see: reviews, meetings, tickets.',
      body: TileGrid(
        minWidth: t.density.menuMinWidth * 1.2,
        gap: t.space.md,
        children: [
          for (final o in SourceOption.available)
            SourceTile(option: o, onPressed: () => Navigator.of(context).pop(o)),
        ],
      ),
      actions: [AntButton.ghost(label: 'Cancel', onPressed: () => Navigator.of(context).pop())],
    );
  }
}

/// A connectable kind: glyph, name, hint and a Connect button.
class SourceTile extends StatelessWidget {
  const SourceTile({super.key, required this.option, required this.onPressed, this.connected = false});
  final SourceOption option;
  final VoidCallback onPressed;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AntCard(
      padding: EdgeInsets.all(t.space.lg + t.space.xxs),
      onPressed: onPressed,
      semanticLabel: 'Connect ${option.label}',
      child: Row(
        children: [
          Glyph(option.glyph, icon: option.icon),
          SizedBox(width: t.space.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(option.label, style: t.typo.bodyStrong.copyWith(color: t.text)),
                Text(connected ? 'Connected' : option.hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.typo.small.copyWith(color: connected ? t.successText : t.muted)),
              ],
            ),
          ),
          SizedBox(width: t.space.md),
          AntButton(
            label: connected ? 'Add another' : 'Connect',
            size: AntSize.sm,
            variant: connected ? AntButtonVariant.ghost : AntButtonVariant.secondary,
            onPressed: onPressed,
          ),
        ],
      ),
    );
  }
}

class _SourcesTab extends ConsumerWidget {
  const _SourcesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final all = ref.watch(sourcesProvider);
    final sources = [for (final s in all.value ?? const <SourceStatus>[]) if (isConnector(s.row.kind)) s];
    if (all.isLoading && sources.isEmpty) return const SizedBox.shrink();
    return PageBody(
      children: [
        if (sources.isEmpty)
          AntCard(
            child: AntEmptyState(
              icon: Icons.hub_outlined,
              title: 'No sources yet',
              message: 'Connect local git, GitHub, your calendar or tickets. Ant Manager imports the last 30 days, '
                  'then keeps up quietly in the background.',
              action: AntButton.primary(label: 'Add source', icon: Icons.add, onPressed: () => _addSource(context)),
            ),
          )
        else
          TileGrid(
            minWidth: t.gridMinTile,
            children: [for (final s in sources) _SourceCard(s)],
          ),
        Gap(t.space.xl),
        const _TranscriptPanel(),
      ],
    );
  }
}

String ago(DateTime at) {
  final d = DateTime.now().difference(at.toLocal());
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  return '${d.inDays} d ago';
}

class _SourceCard extends ConsumerWidget {
  const _SourceCard(this.s);
  final SourceStatus s;

  String _host(SourceRow r) {
    final c = jsonDecode(r.config) as Map<String, Object?>;
    String h(String? url, String fallback) => url == null ? fallback : (Uri.tryParse(url)?.host ?? url);
    return switch (r.kind) {
      SourceKind.gitRepo => tildePath((c['path'] as String?) ?? ''),
      SourceKind.github => 'github.com${c['login'] == null ? '' : ' · @${c['login']}'}',
      SourceKind.githubEnterprise => h(c['apiBaseUrl'] as String?, 'GitHub Enterprise'),
      SourceKind.gitlab => h(c['baseUrl'] as String?, 'gitlab.com'),
      SourceKind.googleCalendar => 'Google account',
      SourceKind.appleCalendar => 'Calendar.app · macOS',
      SourceKind.ics => h(c['url'] as String?, 'ICS feed'),
      SourceKind.linear => 'linear.app',
      SourceKind.jira => h(c['siteUrl'] as String?, 'Jira Cloud'),
      _ => '',
    };
  }

  String _detail(SourceKind k) => switch (k) {
        SourceKind.gitRepo => 'Commits on every branch by your identities',
        SourceKind.github || SourceKind.githubEnterprise => 'PRs opened, merged and reviewed; review comments; issues',
        SourceKind.gitlab => 'Merge requests, approvals, comments, issues',
        SourceKind.googleCalendar || SourceKind.appleCalendar || SourceKind.ics => 'Events you attended',
        SourceKind.linear => 'Issues created, completed, commented',
        SourceKind.jira => 'Issues transitioned, commented, assigned',
        _ => '',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final r = s.row;
    final option = SourceOption.of(r);
    final (status, tone) = !r.enabled
        ? ('Disabled', AntTone.neutral)
        : (s.lastError?.isNotEmpty ?? false)
            ? ('Error', AntTone.err)
            : s.lastSuccessAt != null
                ? ('Connected', AntTone.ok)
                : ('Importing…', AntTone.info);
    final last = s.lastSuccessAt == null ? (r.enabled ? 'Not synced yet' : '') : 'Synced ${ago(s.lastSuccessAt!)}';
    return AntCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Glyph(option.glyph, icon: option.icon),
              SizedBox(width: t.space.md + t.space.xxs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.typo.bodyStrong.copyWith(color: t.text)),
                    Text(_host(r), maxLines: 1, overflow: TextOverflow.ellipsis, style: t.typo.caption.copyWith(color: t.muted)),
                  ],
                ),
              ),
              SizedBox(width: t.space.md),
              AntChip(label: status, tone: tone),
            ],
          ),
          Gap(t.space.md),
          Text(
            tone == AntTone.err ? s.lastError! : _detail(r.kind),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.typo.small.copyWith(color: tone == AntTone.err ? t.dangerText : t.textSoft),
          ),
          Gap(t.space.md),
          Row(
            children: [
              AntButton(
                label: r.kind == SourceKind.gitRepo ? 'Manage repos' : 'Settings',
                size: AntSize.sm,
                onPressed: () => r.kind == SourceKind.gitRepo
                    ? connectSource(context, SourceOption.git)
                    : editSource(context, r),
              ),
              SizedBox(width: t.space.sm),
              if (r.enabled)
                AntIconButton(
                  icon: Icons.sync,
                  tooltip: 'Sync now',
                  size: AntSize.sm,
                  onPressed: () => runCmd(context, ref, syncSourceCmd(r.id), done: 'Syncing ${r.name}'),
                )
              else
                AntButton.ghost(
                  label: 'Enable',
                  size: AntSize.sm,
                  onPressed: () => runCmd(context, ref, updateSourceCmd(r.id, enabled: true)),
                ),
              SizedBox(width: t.space.md),
              Expanded(
                child: Text(last,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: t.typo.caption.copyWith(color: t.muted)),
              ),
              if (r.kind == SourceKind.gitRepo && r.enabled)
                AntIconButton(
                  icon: Icons.close,
                  tooltip: 'Stop watching',
                  size: AntSize.sm,
                  onPressed: () => runCmd(context, ref, removeSourceCmd(r.id), done: 'Stopped watching ${r.name}'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Transcript import (.vtt / .srt / .txt); evidence starts at the meeting time the user confirms.
class _TranscriptPanel extends ConsumerWidget {
  const _TranscriptPanel();

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final file = await openFile(acceptedTypeGroups: const [
      XTypeGroup(label: 'Transcripts', extensions: ['vtt', 'srt', 'txt']),
    ]);
    if (file == null || !context.mounted) return;
    final modified = await File(file.path).lastModified();
    if (!context.mounted) return;
    final at = await showAntDialog<DateTime>(context, builder: (_) => _MeetingTimeDialog(file.name, modified));
    if (at == null || !context.mounted) return;
    final text = await File(file.path).readAsString();
    if (!context.mounted) return;
    await runCmd(context, ref, importTranscriptCmd(p.basename(file.path), text, at),
        done: 'Transcript imported · it will be summarized shortly');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    return AntInteractive(
      onTap: () => _import(context, ref),
      semanticLabel: 'Import a meeting transcript',
      builder: (context, s) => Container(
        padding: EdgeInsets.all(t.space.xl + t.space.xxs),
        decoration: BoxDecoration(
          color: s.hovered ? t.hover : t.surfaceSunken,
          borderRadius: t.radii.brXl,
          border: Border.all(color: s.hovered ? t.borderStronger : t.borderStrong, width: t.stroke.hairline),
        ),
        child: Column(
          children: [
            Icon(Icons.upload_file_outlined, size: t.icon.lg, color: t.muted),
            Gap(t.space.sm),
            Text('Import a meeting transcript', style: t.typo.bodyStrong.copyWith(color: t.text)),
            Gap(t.space.xs),
            Text('.vtt · .srt · .txt · you confirm which calendar event it belongs to, then it is summarized',
                textAlign: TextAlign.center, style: t.typo.small.copyWith(color: t.muted)),
          ],
        ),
      ),
    );
  }
}

class _MeetingTimeDialog extends StatefulWidget {
  const _MeetingTimeDialog(this.name, this.initial);
  final String name;
  final DateTime initial;
  @override
  State<_MeetingTimeDialog> createState() => _MeetingTimeDialogState();
}

class _MeetingTimeDialogState extends State<_MeetingTimeDialog> {
  late final _c = TextEditingController(text: _fmt(widget.initial));
  String? _error;

  static String _fmt(DateTime d) =>
      '${d.year}-${_pad(d.month)}-${_pad(d.day)} ${_pad(d.hour)}:${_pad(d.minute)}';
  static String _pad(int n) => n.toString().padLeft(2, '0');

  void _ok() {
    final v = DateTime.tryParse(_c.text.trim().replaceFirst(' ', 'T'));
    if (v == null) {
      setState(() => _error = 'Use YYYY-MM-DD HH:MM');
      return;
    }
    Navigator.of(context).pop(v);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AntDialog(
      title: 'When did the meeting start?',
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.name),
          Gap(context.tokens.space.lg),
          AntTextField(controller: _c, label: 'Start', mono: true, errorText: _error, autofocus: true, onSubmitted: (_) => _ok()),
          const Hint('Defaults to the file’s date. The transcript joins that day’s evidence.'),
        ],
      ),
      actions: [
        AntButton.ghost(label: 'Cancel', onPressed: () => Navigator.of(context).pop()),
        AntButton.primary(label: 'Import', onPressed: _ok),
      ],
    );
  }
}
