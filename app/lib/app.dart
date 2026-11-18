import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'engine/commands.dart';
import 'pages/placeholder_pages.dart';
import 'shell/quick_capture.dart';
import 'shell/shell_state.dart';
import 'state/providers.dart';

/// TODO(ui): replace with `packages/ui`'s AntTokens theme (dark + light) once it lands;
/// until then this plain dark theme and the few layout numbers in app/ are placeholders.
ThemeData _theme(Brightness b) => ThemeData(
      brightness: b,
      colorSchemeSeed: const Color(0xFFE8A54B), // placeholder: profile default colour
      useMaterial3: true,
      visualDensity: VisualDensity.compact,
    );

class AntApp extends ConsumerWidget {
  const AntApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quickCapture = ref.watch(quickCaptureModeProvider);
    return MaterialApp(
      title: 'Ant Manager',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: ThemeMode.dark,
      home: quickCapture ? const QuickCaptureView() : const AppShell(),
    );
  }
}

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engine = ref.watch(engineProvider);
    final section = ref.watch(shellSectionProvider);
    return Scaffold(
      body: Row(
        children: [
          const _Sidebar(),
          const VerticalDivider(width: 1),
          Expanded(
            child: switch (engine) {
              AsyncData() => KeyedSubtree(key: ValueKey(section), child: pageFor(section)),
              AsyncError(:final error) => Center(child: Text('Engine failed to start:\n$error')),
              _ => const Center(child: CircularProgressIndicator()),
            },
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends ConsumerWidget {
  const _Sidebar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(shellSectionProvider);
    Widget tile(ShellSection s) => ListTile(
          dense: true,
          selected: s == current,
          leading: Icon(s.icon, size: 18),
          title: Text(s.label),
          onTap: () => ref.read(shellSectionProvider.notifier).select(s),
        );
    return SizedBox(
      width: 220,
      child: Column(
        children: [
          const _ProfileSwitcher(),
          const Divider(height: 1),
          for (final s in ShellSection.values.where((s) => !s.bottom)) tile(s),
          const Spacer(),
          for (final s in ShellSection.values.where((s) => s.bottom)) tile(s),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ProfileSwitcher extends ConsumerWidget {
  const _ProfileSwitcher();

  static const _newProfile = '__new__';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(profilesProvider).value ?? const [];
    final active = ref.watch(activeProfileProvider);
    return PopupMenuButton<String>(
      tooltip: 'Switch profile',
      onSelected: (id) async {
        if (id == _newProfile) {
          await _create(context, ref);
        } else {
          await ref.read(engineProvider.notifier).switchProfile(id);
        }
      },
      itemBuilder: (_) => [
        for (final p in profiles) CheckedPopupMenuItem(value: p.id, checked: p.id == active?.id, child: Text(p.name)),
        const PopupMenuDivider(),
        const PopupMenuItem(value: _newProfile, child: Text('New profile…')),
      ],
      child: ListTile(
        leading: const Icon(Icons.workspaces_outline),
        title: Text(active?.name ?? '…', key: const ValueKey('active-profile')),
        trailing: const Icon(Icons.unfold_more, size: 16),
      ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New profile'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(hintText: 'Name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Create')),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;
    final h = await ref.read(engineProvider.future);
    final id = await h.runtime(createProfileCmd(name));
    await ref.read(engineProvider.notifier).switchProfile(id);
  }
}
