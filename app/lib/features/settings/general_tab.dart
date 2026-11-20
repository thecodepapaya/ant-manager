/// Settings → General: profiles, time zone, launch at login, pause collection, crash reports, diagnostics.
library;

import 'dart:io';

import 'package:core/core.dart' hide Provider;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:ui/ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../engine/commands.dart';
import '../../engine/diagnostics.dart';
import '../../engine/setup_commands.dart';
import '../../platform/launch_at_login.dart';
import '../../platform/rotating_log.dart';
import '../../state/providers.dart';
import 'kit.dart';
import 'setup_providers.dart';

class GeneralTab extends ConsumerStatefulWidget {
  const GeneralTab({super.key});
  @override
  ConsumerState<GeneralTab> createState() => _GeneralTabState();
}

class _GeneralTabState extends ConsumerState<GeneralTab> {
  bool? _launchAtLogin;

  @override
  void initState() {
    super.initState();
    Future(LaunchAtLogin.isEnabled).then((v) {
      if (mounted) setState(() => _launchAtLogin = v);
    }, onError: (Object _) {});
  }

  Future<void> _newProfile() async {
    final name = await showAntDialog<String>(context, builder: (_) => const _NameDialog());
    if (name == null || name.isEmpty || !mounted) return;
    final id = await runCmd(context, ref, createProfileCmd(name));
    if (id != null) await ref.read(engineProvider.notifier).switchProfile(id);
  }

  Future<void> _rename(Profile p) async {
    final name = await showAntDialog<String>(context, builder: (_) => _NameDialog(initial: p.name));
    if (name == null || name.isEmpty || !mounted) return;
    await runCmd(context, ref, renameProfileCmd(p.id, name));
  }

  /// Builds the diagnostics report (SPEC §10) and puts it on the clipboard.
  Future<void> _copyDiagnostics() async {
    final dataDir = ref.read(engineConfigProvider).dataDir;
    final info = await PackageInfo.fromPlatform();
    String engine;
    try {
      engine = await (await ref.read(engineProvider.future)).runtime(diagnosticsCmd());
    } catch (e) {
      engine = 'Engine: unavailable (${errorSummary(e)})\n';
    }
    final report = diagnosticsReport(
      app: {
        'App': '${info.version} (build ${info.buildNumber})',
        'OS': '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
        'Flutter': '${FlutterVersion.version ?? 'unknown'} (${FlutterVersion.channel ?? 'unknown'})',
        'Dart': Platform.version.split(' ').first,
        'Data folder': const String.fromEnvironment('ANT_DATA_DIR').isEmpty ? 'default' : 'custom (ANT_DATA_DIR)',
      },
      engine: engine,
      logs: tailLogs(logsDir(dataDir)),
    );
    await Clipboard.setData(ClipboardData(text: report));
    if (mounted) toast(context, 'Diagnostics copied · paste them into your bug report', tone: AntTone.ok);
  }

  Future<void> _openLogs() async {
    final dir = Directory(logsDir(ref.read(engineConfigProvider).dataDir))..createSync(recursive: true);
    if (!await launchUrl(Uri.directory(dir.path)) && mounted) {
      toast(context, 'Couldn’t open the logs folder', tone: AntTone.err);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final profiles = ref.watch(profilesProvider).value ?? const <Profile>[];
    final active = ref.watch(activeProfileProvider);
    final paused = ref.watch(pausedProvider).value ?? false;
    final crash = ref.watch(settingsProvider).value?[crashReportsSettingKey] == 'true';
    return PageBody(
      maxWidth: t.narrowPage,
      children: [
        Label('Profiles',
            trailing: Text('Each profile keeps its own data, sources, models routing and schedule.',
                style: t.typo.small.copyWith(color: t.muted))),
        Gap(t.space.md),
        ListPanel(children: [
          for (final p in profiles)
            PanelRow(
              leading: Icon(
                p.id == active?.id ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                size: t.icon.sm,
                color: p.id == active?.id ? t.accentText : t.muted,
              ),
              title: p.name,
              hint: 'Time zone ${p.timeZone}',
              trailing: [
                AntButton.ghost(label: 'Rename', size: AntSize.sm, onPressed: () => _rename(p)),
                if (p.id == active?.id)
                  const AntChip(label: 'Active', tone: AntTone.ok)
                else
                  AntButton(
                    label: 'Switch',
                    size: AntSize.sm,
                    onPressed: () => ref.read(engineProvider.notifier).switchProfile(p.id),
                  ),
              ],
            ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: t.space.lg, vertical: t.space.md),
            child: Row(children: [
              AntButton.ghost(label: 'New profile…', icon: Icons.add, size: AntSize.sm, onPressed: _newProfile),
            ]),
          ),
        ]),
        Hint('Only the active profile syncs and runs schedules; others catch up when you switch to them. '
            'Day boundaries use the profile’s time zone.'),
        Gap(t.space.xxxl),
        const Label('App'),
        Gap(t.space.md),
        ListPanel(children: [
          PanelRow(
            title: 'Launch at login',
            hint: 'Start in the menu bar so syncs and schedules run',
            trailing: [
              AntSwitch(
                value: _launchAtLogin ?? false,
                semanticLabel: 'Launch at login',
                onChanged: _launchAtLogin == null
                    ? null
                    : (v) async {
                        await LaunchAtLogin.setEnabled(v);
                        final now = await LaunchAtLogin.isEnabled();
                        if (mounted) setState(() => _launchAtLogin = now);
                      },
              ),
            ],
          ),
          PanelRow(
            title: 'Pause collection',
            hint: 'Stops syncing sources for this profile; notes and reports still work',
            trailing: [
              AntSwitch(
                value: paused,
                semanticLabel: 'Pause collection',
                onChanged: (v) => runCmd(context, ref, setPausedCmd(v)),
              ),
            ],
          ),
          PanelRow(
            title: 'Share anonymous crash reports',
            hint: 'Stack traces only, never your content. Off by default.',
            trailing: [
              // TODO(owner): Sentry DSN (docs/OWNER_TODO.md). Only the preference is stored for now.
              AntSwitch(
                value: crash,
                semanticLabel: 'Share anonymous crash reports',
                onChanged: (v) => runCmd(context, ref, setSettingCmd(crashReportsSettingKey, '$v')),
              ),
            ],
          ),
        ]),
        Gap(t.space.xxxl),
        const Label('Diagnostics'),
        Gap(t.space.md),
        ListPanel(children: [
          PanelRow(
            title: 'Copy diagnostics',
            hint: 'Versions, setup summary and recent log lines for a bug report. No content, names, URLs or keys.',
            trailing: [AntButton(label: 'Copy', size: AntSize.sm, onPressed: _copyDiagnostics)],
          ),
          PanelRow(
            title: 'Logs',
            hint: 'Kept on this computer only, about 3 MB per process; oldest lines are dropped first',
            trailing: [AntButton.ghost(label: 'Open folder', size: AntSize.sm, onPressed: _openLogs)],
          ),
        ]),
      ],
    );
  }
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({this.initial});
  final String? initial;
  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _c = TextEditingController(text: widget.initial ?? '');

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AntDialog(
        title: widget.initial == null ? 'New profile' : 'Rename profile',
        body: AntTextField(
          controller: _c,
          autofocus: true,
          placeholder: 'e.g. Side projects',
          onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
        ),
        actions: [
          AntButton.ghost(label: 'Cancel', onPressed: () => Navigator.of(context).pop()),
          AntButton.primary(
            label: widget.initial == null ? 'Create' : 'Save',
            onPressed: () => Navigator.of(context).pop(_c.text.trim()),
          ),
        ],
      );
}
