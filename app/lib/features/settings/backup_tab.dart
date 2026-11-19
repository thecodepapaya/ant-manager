/// Settings → Backup (SPEC §9): local folder, keep N, readable export, Back up now, restore with
/// a manifest preview, plaintext warning.
library;

import 'package:core/core.dart' hide Provider;
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui/ui.dart';

import '../../engine/engine_runtime.dart';
import '../../engine/setup_commands.dart';
import '../../platform/time_zone.dart';
import '../../state/providers.dart';
import '../sources/git_setup.dart' show tildePath;
import '../sources/sources_page.dart' show ago;
import '../../widgets/common.dart' show shortDayLabel;
import 'kit.dart';
import 'schedule_tab.dart';
import 'setup_providers.dart';

final _defaultFolderProvider = FutureProvider<String>((ref) async {
  final h = await ref.watch(engineProvider.future);
  return h.runtime(defaultBackupFolderCmd());
});

class BackupTab extends ConsumerStatefulWidget {
  const BackupTab({super.key});
  @override
  ConsumerState<BackupTab> createState() => _BackupTabState();
}

class _BackupTabState extends ConsumerState<BackupTab> {
  bool _running = false;

  Future<void> _backupNow() async {
    setState(() => _running = true);
    final path = await runCmd(context, ref, backupNowCmd());
    if (mounted) {
      setState(() => _running = false);
      if (path != null) toast(context, 'Backed up to ${tildePath(path)}', tone: AntTone.ok);
    }
  }

  Future<void> _restore() async {
    final file = await openFile(acceptedTypeGroups: const [
      XTypeGroup(label: 'Ant Manager backup', extensions: ['antbackup']),
    ]);
    if (file == null || !mounted) return;
    final m = await runCmd(context, ref, inspectBackupCmd(file.path));
    if (m == null || !mounted) return;
    final ok = await showAntDialog<bool>(context, builder: (_) => _RestorePreview(m));
    if (ok != true || !mounted) return;
    final id = await runCmd(context, ref, restoreBackupCmd(file.path));
    if (id == null || !mounted) return;
    toast(context, 'Restored as “${m.profile} (restored)” · sign in to your sources again', tone: AntTone.ok);
    await ref.read(engineProvider.notifier).switchProfile(id);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final settings = ref.watch(settingsProvider).value ?? const <String, String>{};
    final folder = settings[backupFolderSettingKey] ?? ref.watch(_defaultFolderProvider).value ?? '';
    final keep = int.tryParse(settings[backupKeepSettingKey] ?? '') ?? 14;
    final readable = settings[backupReadableSettingKey] == 'true';
    final lastOk = DateTime.tryParse(settings[backupLastSuccessSettingKey] ?? '');
    final lastErr = settings[backupLastErrorSettingKey] ?? '';
    final stale = lastOk == null || DateTime.now().difference(lastOk).inDays >= 3;
    final schedule = ref.watch(schedulesProvider).value?[Scheduler.backup];

    final status = lastErr.isNotEmpty
        ? 'Last backup failed: $lastErr'
        : lastOk == null
            ? 'No backup yet'
            : 'Last successful backup: ${ago(lastOk)}';

    Widget card(String label, Widget body, String hint) => AntCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Label(label),
              Gap(t.space.md),
              body,
              Gap(t.space.sm),
              Text(hint, style: t.typo.small.copyWith(color: t.muted)),
            ],
          ),
        );

    return PageBody(
      maxWidth: t.widePage,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Backups', style: t.typo.title.copyWith(color: t.text)),
                Text(status, style: t.typo.small.copyWith(color: lastErr.isNotEmpty ? t.dangerText : t.muted)),
              ]),
            ),
            AntButton(label: 'Restore…', onPressed: _restore),
            SizedBox(width: t.space.md),
            AntButton.primary(label: _running ? 'Backing up…' : 'Back up now', onPressed: _running ? null : _backupNow),
          ],
        ),
        Gap(t.space.xxl),
        const Label('Destination'),
        Gap(t.space.md),
        ListPanel(children: [
          PanelRow(
            leading: const Glyph('', icon: Icons.folder_outlined),
            title: 'Local folder',
            hint: tildePath(folder),
            hintMono: true,
            trailing: [
              if (lastErr.isNotEmpty)
                const AntChip(label: 'Failed', tone: AntTone.err)
              else if (lastOk != null)
                AntChip(label: stale ? 'Old · ${ago(lastOk)}' : 'OK', tone: stale ? AntTone.warn : AntTone.ok),
              AntButton.ghost(
                label: 'Change…',
                size: AntSize.sm,
                onPressed: () async {
                  final dir = await getDirectoryPath(confirmButtonText: 'Back up here');
                  if (dir != null && context.mounted) {
                    await runCmd(context, ref, setSettingCmd(backupFolderSettingKey, dir));
                  }
                },
              ),
            ],
          ),
        ]),
        Hint('To keep a copy in the cloud, pick a synced folder (iCloud Drive, Google Drive, Dropbox, OneDrive).'),
        Gap(t.space.xxl),
        TileGrid(
          minWidth: t.gridMinTile,
          children: [
            card(
              'Schedule',
              schedule == null
                  ? Text('Daily', style: t.typo.body.copyWith(color: t.text))
                  : Row(children: [
                      Text('Daily at', style: t.typo.body.copyWith(color: t.text)),
                      SizedBox(width: t.space.md),
                      ScheduleTimeSelect(schedule),
                    ]),
              'Missed runs catch up on next launch',
            ),
            card(
              'Keep',
              Row(children: [
                Text('Last', style: t.typo.body.copyWith(color: t.text)),
                SizedBox(width: t.space.md),
                SelectButton<int>(
                  value: keep,
                  options: [for (final n in const [7, 14, 30, 60]) (n, '$n backups')],
                  onChanged: (n) => runCmd(context, ref, setSettingCmd(backupKeepSettingKey, '$n')),
                ),
              ]),
              'Older backups in the folder are deleted',
            ),
            card(
              'Contents',
              Row(children: [
                AntSwitch(
                  value: readable,
                  semanticLabel: 'Readable export',
                  onChanged: (v) => runCmd(context, ref, setSettingCmd(backupReadableSettingKey, '$v')),
                ),
                SizedBox(width: t.space.md),
                Expanded(child: Text('Readable Markdown/JSON export too', style: t.typo.body.copyWith(color: t.text))),
              ]),
              'API keys and sign-ins are never included',
            ),
          ],
        ),
        Gap(t.space.xl),
        const Callout(
          child: Text('Backups are not encrypted. A synced folder puts your full evidence, including code diffs and '
              'meeting details, in that cloud.'),
        ),
      ],
    );
  }
}

class _RestorePreview extends StatelessWidget {
  const _RestorePreview(this.m);
  final BackupManifest m;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = m.counts;
    String n(String k) => '${c[k] ?? 0}';
    Widget kv(String k, String v) => Padding(
          padding: EdgeInsets.symmetric(vertical: t.space.xxs),
          child: Row(children: [
            SizedBox(width: t.space.giant * 2.5, child: Text(k, style: t.typo.small.copyWith(color: t.muted))),
            Expanded(child: Text(v, style: t.typo.body.copyWith(color: t.text))),
          ]),
        );
    final created = m.createdAt.toUtc().add(profileUtcOffset(m.createdAt)); // profile wall clock
    return AntDialog(
      title: 'Restore this backup?',
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          kv('Profile', m.profile),
          kv('Backed up', '${shortDayLabel(profileDayOf(m.createdAt))}, ${hhmm(created.hour, created.minute)}'),
          kv('Covers', m.firstDay == null ? 'No evidence' : '${shortDayLabel(m.firstDay!)} – ${shortDayLabel(m.lastDay ?? m.firstDay!)}'),
          kv('Contains', '${n('evidences')} evidence · ${n('facts')} facts · ${n('reports')} reports'),
          kv('App version', m.appVersion),
          Gap(t.space.lg),
          const Text('It’s restored as a new profile; your current data isn’t touched. Sign in to sources and '
              're-enter API keys afterwards: secrets are never in backups.'),
        ],
      ),
      actions: [
        AntButton.ghost(label: 'Cancel', onPressed: () => Navigator.of(context).pop(false)),
        AntButton.primary(label: 'Restore as new profile', onPressed: () => Navigator.of(context).pop(true)),
      ],
    );
  }
}
