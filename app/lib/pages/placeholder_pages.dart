/// Placeholder pages per sidebar section. They show live counts from the profile DB to prove
/// the engine isolate + cross-isolate `watch()` wiring; the feature screens replace them.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engine/commands.dart';
import '../platform/launch_at_login.dart';
import '../shell/shell_state.dart';
import '../state/providers.dart';

Widget pageFor(ShellSection s) => switch (s) {
      ShellSection.today => const _CountsPage(
          ShellSection.today,
          [(Counter.evidenceToday, 'Evidence today'), (Counter.notes, 'Notes')],
          showAddNote: true,
        ),
      ShellSection.timeline => const _CountsPage(ShellSection.timeline, [(Counter.evidence, 'Evidence')], showAddNote: true),
      ShellSection.narrative => const _CountsPage(ShellSection.narrative, [(Counter.facts, 'Facts')]),
      ShellSection.reports => const _CountsPage(ShellSection.reports, [(Counter.reports, 'Reports')]),
      ShellSection.wins => const _CountsPage(ShellSection.wins, [(Counter.wins, 'Accepted wins')]),
      ShellSection.projects => const _CountsPage(ShellSection.projects, [(Counter.projects, 'Projects')]),
      ShellSection.sources => const _CountsPage(ShellSection.sources, [(Counter.sources, 'Sources')]),
      ShellSection.settings => const _SettingsPage(),
    };

class _CountsPage extends ConsumerWidget {
  const _CountsPage(this.section, this.counters, {this.showAddNote = false});
  final ShellSection section;
  final List<(Counter, String)> counters;
  final bool showAddNote;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(section.label, style: text.headlineSmall),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final (c, label) in counters) _CountCard(label: label, value: ref.watch(countProvider(c))),
              _CountCard(label: 'Queued jobs', value: ref.watch(countProvider(Counter.queuedJobs))),
            ],
          ),
          if (showAddNote) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const ValueKey('add-note'),
              onPressed: () => _addNote(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Add note'),
            ),
          ],
          const SizedBox(height: 24),
          Text('${section.label} screen coming soon.', style: text.bodyMedium?.copyWith(color: Theme.of(context).hintColor)),
        ],
      ),
    );
  }

  Future<void> _addNote(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add note'),
        content: TextField(controller: controller, autofocus: true, maxLines: 4, minLines: 2),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    controller.dispose();
    if (text == null || text.isEmpty) return;
    final h = await ref.read(engineProvider.future);
    await h.runtime(addQuickNoteCmd(text: text));
  }
}

class _CountCard extends StatelessWidget {
  const _CountCard({required this.label, required this.value});
  final String label;
  final AsyncValue<int> value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: SizedBox(
        width: 160,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value.when(data: (v) => '$v', loading: () => '…', error: (e, _) => '!'),
                style: text.headlineMedium,
              ),
              Text(label, style: text.bodySmall),
            ],
          ),
        ),
      ),
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
    final profile = ref.watch(activeProfileProvider);
    final paused = ref.watch(pausedProvider).value ?? false;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Settings', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        ListTile(
          title: const Text('Profile'),
          subtitle: Text(profile == null ? '…' : '${profile.name} · ${profile.timeZone}'),
        ),
        SwitchListTile(
          title: const Text('Pause collection'),
          subtitle: const Text('Stops syncing sources for this profile'),
          value: paused,
          onChanged: (v) async {
            final h = await ref.read(engineProvider.future);
            await h.runtime(setPausedCmd(v));
          },
        ),
        SwitchListTile(
          title: const Text('Launch at login'),
          value: _launchAtLogin ?? false,
          onChanged: _launchAtLogin == null
              ? null
              : (v) async {
                  await LaunchAtLogin.setEnabled(v);
                  final now = await LaunchAtLogin.isEnabled();
                  if (mounted) setState(() => _launchAtLogin = now);
                },
        ),
      ],
    );
  }
}
