import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui/ui.dart';

import '../../engine/commands.dart';
import '../../state/data.dart';
import '../../widgets/common.dart';

/// Projects: create, rename, recolour, archive; evidence and fact counts.
class ProjectsPage extends ConsumerStatefulWidget {
  const ProjectsPage({super.key});
  @override
  ConsumerState<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends ConsumerState<ProjectsPage> {
  var _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final stats = ref.watch(projectStatsProvider);
    final all = stats.value ?? const <ProjectStats>[];
    final archived = all.where((s) => s.p.archived).length;
    final shown = _showArchived ? all : all.where((s) => !s.p.archived).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TopBar(
          title: 'Projects',
          subtitle: 'Evidence and facts are grouped into projects; you can correct any of them.',
          actions: [
            if (archived > 0)
              AntButton.ghost(
                label: _showArchived ? 'Hide archived' : 'Show archived ($archived)',
                onPressed: () => setState(() => _showArchived = !_showArchived),
              ),
            AntButton(label: 'New project', icon: Icons.add_rounded, onPressed: () => _create(context)),
          ],
        ),
        Expanded(
          child: stats.hasValue && shown.isEmpty
              ? PageEmpty(AntEmptyState(
                  icon: Icons.folder_outlined,
                  title: 'No projects yet',
                  message: 'Projects group your evidence, facts and reports, e.g. “Checkout v2” or “Hiring”. '
                      'The model files new work into them; you can always move things.',
                  action: AntButton.primary(label: 'Create a project', onPressed: () => _create(context)),
                ))
              : LayoutBuilder(
                  builder: (context, c) {
                    final cols = (c.maxWidth / t.density.columnMinWidth).floor().clamp(1, 4);
                    final rows = <List<ProjectStats>>[];
                    for (var i = 0; i < shown.length; i += cols) {
                      rows.add(shown.sublist(i, (i + cols).clamp(0, shown.length)));
                    }
                    return ListView(
                      padding: EdgeInsets.fromLTRB(t.space.xxxl, t.space.xxl, t.space.xxxl, t.space.giant),
                      children: [
                        for (final row in rows)
                          Padding(
                            padding: EdgeInsets.only(bottom: t.space.lg),
                            child: IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (var i = 0; i < cols; i++) ...[
                                    if (i > 0) SizedBox(width: t.space.lg),
                                    Expanded(child: i < row.length ? _ProjectCard(row[i]) : const SizedBox.shrink()),
                                  ],
                                ],
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _create(BuildContext context) async {
    final t = context.tokens;
    final name = await promptText(context, title: 'New project', placeholder: 'e.g. Checkout v2', action: 'Create');
    if (name == null || !context.mounted) return;
    final palette = projectPalette(t);
    final n = ref.read(projectStatsProvider).value?.length ?? 0;
    await runCmd(context, ref, createProjectCmd(name, colour: hexOf(palette[n % palette.length])), ok: 'Project created');
  }
}

class _ProjectCard extends ConsumerWidget {
  const _ProjectCard(this.s);
  final ProjectStats s;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final p = s.p;
    Widget stat(int n, String one) => Text.rich(
          TextSpan(children: [
            TextSpan(text: '$n', style: t.typo.bodyStrong.copyWith(color: t.text)),
            TextSpan(text: ' ${plural(n, one).split(' ').last}', style: TextStyle(color: t.muted)),
          ]),
          style: t.typo.small,
        );
    return Opacity(
      opacity: p.archived ? t.stroke.disabledOpacity * 2 : 1,
      child: AntCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              AntDot(color: projectColour(t, p)),
              SizedBox(width: t.space.md),
              Expanded(
                child: Text(p.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: t.typo.title.copyWith(color: t.text)),
              ),
              if (p.archived) const AntChip(label: 'Archived'),
              AntMenu(
                items: [
                  AntMenuItem(
                    label: 'Rename…',
                    icon: Icons.edit_outlined,
                    onSelected: () async {
                      final name = await promptText(context, title: 'Rename project', initial: p.name);
                      if (name != null && context.mounted) await runCmd(context, ref, updateProjectCmd(p.id, name: name));
                    },
                  ),
                  const AntMenuDivider(),
                  AntMenuItem(
                    label: p.archived ? 'Unarchive' : 'Archive',
                    icon: p.archived ? Icons.unarchive_outlined : Icons.archive_outlined,
                    onSelected: () => runCmd(context, ref, updateProjectCmd(p.id, archived: !p.archived)),
                  ),
                ],
                builder: (context, c) => AntIconButton(
                  icon: Icons.more_horiz_rounded,
                  tooltip: 'Project actions',
                  onPressed: () => c.isOpen ? c.close() : c.open(),
                ),
              ),
            ]),
            SizedBox(height: t.space.lg),
            Row(children: [
              stat(s.evidence, 'item'),
              SizedBox(width: t.space.xl),
              stat(s.facts, 'fact'),
              SizedBox(width: t.space.xl),
              stat(s.wins, 'win'),
            ]),
            SizedBox(height: t.space.lg),
            Wrap(
              spacing: t.space.sm,
              children: [
                for (final c in projectPalette(t))
                  AntInteractive(
                    semanticLabel: 'Set colour',
                    selected: hexOf(c) == p.colour.toUpperCase(),
                    onTap: () => runCmd(context, ref, updateProjectCmd(p.id, colour: hexOf(c))),
                    builder: (context, st) => Container(
                      width: t.icon.md,
                      height: t.icon.md,
                      decoration: BoxDecoration(
                        color: c,
                        borderRadius: t.radii.brPill,
                        border: Border.all(
                          color: hexOf(c) == p.colour.toUpperCase() || st.hovered ? t.text : c,
                          width: t.stroke.focus,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
