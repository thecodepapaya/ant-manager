import 'package:core/core.dart' hide Provider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui/ui.dart';

import 'engine/commands.dart';
import 'features/narrative/narrative_page.dart';
import 'features/projects/projects_page.dart';
import 'features/reports/reports_page.dart';
import 'features/timeline/timeline_page.dart';
import 'features/today/today_page.dart';
import 'features/wins/wins_page.dart';
import 'pages/placeholder_pages.dart';
import 'shell/quick_capture.dart';
import 'shell/shell_state.dart';
import 'state/data.dart';
import 'state/providers.dart';
import 'widgets/common.dart';

/// The page for a sidebar section. Sources and Settings are built by another agent.
Widget pageFor(ShellSection s) => switch (s) {
      ShellSection.today => const TodayPage(),
      ShellSection.timeline => const TimelinePage(),
      ShellSection.narrative => const NarrativePage(),
      ShellSection.reports => const ReportsPage(),
      ShellSection.wins => const WinsPage(),
      ShellSection.projects => const ProjectsPage(),
      ShellSection.sources || ShellSection.settings => placeholderPageFor(s),
    };

class AntApp extends ConsumerWidget {
  const AntApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quickCapture = ref.watch(quickCaptureModeProvider);
    return MaterialApp(
      title: 'Ant Manager',
      debugShowCheckedModeBanner: false,
      theme: antTheme(AntTokens.light()),
      darkTheme: antTheme(AntTokens.dark()),
      themeMode: ThemeMode.system,
      builder: (context, child) => AntToastHost(child: child!),
      home: quickCapture ? const QuickCaptureView() : const AppShell(),
    );
  }
}

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final engine = ref.watch(engineProvider);
    final section = ref.watch(shellSectionProvider);
    return Material(
      color: t.bg,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Sidebar(),
          Expanded(
            child: switch (engine) {
              AsyncData() => KeyedSubtree(key: ValueKey(section), child: pageFor(section)),
              AsyncError(:final error) => AntEmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'The engine failed to start',
                  message: '$error',
                ),
              _ => const SizedBox.shrink(),
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
    final t = context.tokens;
    final current = ref.watch(shellSectionProvider);
    final today = ref.watch(countProvider(Counter.evidenceToday)).value ?? 0;
    final review = ref.watch(reviewCountProvider).value ?? 0;
    final suggested = ref.watch(suggestedWinsCountProvider).value ?? 0;

    Widget? trailing(ShellSection s) {
      Widget count(String text, [Color? color]) =>
          Text(text, style: t.typo.caption.copyWith(color: color ?? t.muted));
      return switch (s) {
        ShellSection.today when today > 0 => count('$today'),
        ShellSection.narrative when review > 0 => count('$review to review', t.accentText),
        ShellSection.wins when suggested > 0 => count('$suggested new', t.accentText),
        _ => null,
      };
    }

    Widget item(ShellSection s) => Padding(
          padding: EdgeInsets.only(bottom: t.space.xxs),
          child: AntSidebarItem(
            label: s.label,
            icon: s.icon,
            selected: s == current,
            trailing: trailing(s),
            onPressed: () => ref.read(shellSectionProvider.notifier).select(s),
          ),
        );

    return Container(
      width: t.density.sidebarWidth,
      padding: EdgeInsets.all(t.space.md + t.space.xxs),
      decoration: BoxDecoration(
        color: t.bgSidebar,
        border: Border(right: BorderSide(color: t.border, width: t.stroke.hairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _ProfileSwitcher(),
          SizedBox(height: t.space.sm),
          for (final s in ShellSection.values.where((s) => !s.bottom)) item(s),
          const Spacer(),
          for (final s in ShellSection.values.where((s) => s.bottom)) item(s),
          const _SyncFooter(),
        ],
      ),
    );
  }
}

class _SyncFooter extends ConsumerWidget {
  const _SyncFooter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final last = ref.watch(lastSyncProvider).value;
    final paused = ref.watch(pausedProvider).value ?? false;
    final jobs = ref.watch(countProvider(Counter.queuedJobs)).value ?? 0;
    final text = paused
        ? 'Collection paused'
        : [
            last == null ? 'Not synced yet' : 'Synced ${ago(last)}',
            if (jobs > 0) plural(jobs, 'job'),
          ].join(' · ');
    return Container(
      margin: EdgeInsets.only(top: t.space.sm),
      padding: EdgeInsets.all(t.space.md + t.space.xxs),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: t.border, width: t.stroke.hairline))),
      child: Row(
        children: [
          AntDot(color: paused ? t.accent : (last == null ? t.raw : t.success), size: t.space.sm),
          SizedBox(width: t.space.md),
          Expanded(child: Muted(text, maxLines: 1, style: t.typo.chip)),
        ],
      ),
    );
  }
}

class _ProfileSwitcher extends ConsumerWidget {
  const _ProfileSwitcher();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final profiles = ref.watch(profilesProvider).value ?? const <Profile>[];
    final active = ref.watch(activeProfileProvider);
    return AntMenu(
      items: [
        for (final p in profiles)
          AntMenuItem(
            label: p.name,
            icon: p.id == active?.id ? Icons.check_rounded : Icons.person_outline_rounded,
            onSelected: () => ref.read(engineProvider.notifier).switchProfile(p.id),
          ),
        const AntMenuDivider(),
        AntMenuItem(label: 'New profile…', icon: Icons.add_rounded, onSelected: () => _create(context, ref)),
      ],
      builder: (context, c) => AntInteractive(
        onTap: () => c.isOpen ? c.close() : c.open(),
        semanticLabel: 'Switch profile',
        excludeChildSemantics: true,
        builder: (context, s) => AnimatedContainer(
          duration: t.motion.fast,
          height: t.density.controlLg + t.space.md,
          padding: EdgeInsets.symmetric(horizontal: t.space.md),
          decoration: BoxDecoration(
            color: s.hovered ? t.hover : t.hover.withValues(alpha: 0),
            borderRadius: t.radii.brMd,
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: t.radii.brMd,
                child: Image.asset('assets/brand/logo.png', width: t.icon.xl, height: t.icon.xl),
              ),
              SizedBox(width: t.space.md),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(active?.name ?? '…',
                        key: const ValueKey('active-profile'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.typo.bodyStrong.copyWith(color: t.text)),
                    Text('Ant Manager', style: t.typo.caption.copyWith(color: t.muted)),
                  ],
                ),
              ),
              Icon(Icons.unfold_more_rounded, size: t.icon.sm, color: t.muted),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final name = await promptText(context, title: 'New profile', placeholder: 'Name, e.g. “Side project”', action: 'Create');
    if (name == null) return;
    final h = await ref.read(engineProvider.future);
    final id = await h.runtime(createProfileCmd(name));
    await ref.read(engineProvider.notifier).switchProfile(id);
  }
}
