/// Placeholder pages for Sources and Settings until their feature screens land
/// (built separately in `features/sources` and `features/settings`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui/ui.dart';

import '../engine/commands.dart';
import '../platform/launch_at_login.dart';
import '../shell/shell_state.dart';
import '../state/providers.dart';
import '../widgets/common.dart';

Widget placeholderPageFor(ShellSection s) => switch (s) {
      ShellSection.settings => const _SettingsPage(),
      _ => _CountsPage(s),
    };

class _CountsPage extends ConsumerWidget {
  const _CountsPage(this.section);
  final ShellSection section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.watch(countProvider(Counter.sources)).value ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TopBar(title: section.label),
        Expanded(
          child: AntEmptyState(
            icon: section.icon,
            title: '${section.label} is coming soon',
            message: '${plural(n, 'source')} connected.',
          ),
        ),
      ],
    );
  }
}

class _SettingsPage extends ConsumerStatefulWidget {
  const _SettingsPage();
  @override
  ConsumerState<_SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<_SettingsPage> {
  bool? _launchAtLogin;

  @override
  void initState() {
    super.initState();
    Future(LaunchAtLogin.isEnabled).then((v) {
      if (mounted) setState(() => _launchAtLogin = v);
    }, onError: (Object _) {});
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final profile = ref.watch(activeProfileProvider);
    final paused = ref.watch(pausedProvider).value ?? false;
    Widget row(String title, String? hint, Widget trailing) => Container(
          padding: EdgeInsets.symmetric(horizontal: t.space.xl, vertical: t.space.lg),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.divider, width: t.stroke.hairline))),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: t.typo.bodyStrong.copyWith(color: t.text)),
                    if (hint != null) Muted(hint),
                  ],
                ),
              ),
              trailing,
            ],
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TopBar(title: 'Settings'),
        Padding(
          padding: EdgeInsets.all(t.space.xxxl),
          child: Panel(
            child: Column(
              children: [
                row('Profile', profile == null ? '…' : '${profile.name} · ${profile.timeZone}', const SizedBox.shrink()),
                row(
                  'Pause collection',
                  'Stops syncing sources for this profile',
                  AntSwitch(
                    value: paused,
                    onChanged: (v) => runCmd(context, ref, setPausedCmd(v)),
                  ),
                ),
                row(
                  'Launch at login',
                  null,
                  AntSwitch(
                    value: _launchAtLogin ?? false,
                    onChanged: _launchAtLogin == null
                        ? null
                        : (v) async {
                            await LaunchAtLogin.setEnabled(v);
                            final now = await LaunchAtLogin.isEnabled();
                            if (mounted) setState(() => _launchAtLogin = now);
                          },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
