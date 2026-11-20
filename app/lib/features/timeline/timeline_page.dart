import 'package:core/core.dart' hide Provider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui/ui.dart';

import '../../state/data.dart';
import '../../widgets/common.dart';
import '../../widgets/evidence_row.dart';
import '../../widgets/note_composer.dart';

/// All evidence, newest first, grouped by day; filter by source and project; load more in pages.
class TimelinePage extends ConsumerStatefulWidget {
  const TimelinePage({super.key});
  @override
  ConsumerState<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends ConsumerState<TimelinePage> {
  static const _page = 100;
  String? _sourceId;
  String? _projectId;
  var _limit = _page;
  var _composer = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final sources = ref.watch(sourcesProvider).value ?? const <SourceRow>[];
    final projects = ref.watch(allProjectsProvider).value ?? const <Project>[];
    final items = ref.watch(evidenceProvider((day: null, sourceId: _sourceId, projectId: _projectId, limit: _limit)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TopBar(
          title: 'Timeline',
          middle: [
            AntSelect<String?>(
              value: _sourceId,
              semanticLabel: 'Source',
              options: [
                const AntOption(null, 'All sources'),
                for (final s in sources) AntOption(s.id, s.name),
              ],
              onChanged: (v) => setState(() {
                _sourceId = v;
                _limit = _page;
              }),
            ),
            AntSelect<String?>(
              value: _projectId,
              semanticLabel: 'Project',
              options: [
                const AntOption(null, 'All projects'),
                for (final p in projects)
                  AntOption(p.id, p.name, leading: AntDot(color: projectColour(t, p), size: t.space.sm)),
              ],
              onChanged: (v) => setState(() {
                _projectId = v;
                _limit = _page;
              }),
            ),
          ],
          actions: [
            AntButton(
              label: 'Add note',
              icon: Icons.edit_note_rounded,
              onPressed: () => setState(() => _composer = !_composer),
            ),
          ],
        ),
        Expanded(
          child: AsyncBody(
            items,
            builder: (list) {
              final days = <String, List<EvidenceItem>>{};
              for (final e in list) {
                days.putIfAbsent(e.e.day, () => []).add(e);
              }
              final filtered = _sourceId != null || _projectId != null;
              return ListView(
                padding: EdgeInsets.fromLTRB(t.space.xxxl, t.space.lg, t.space.xxxl, t.space.giant),
                children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: t.density.contentMaxWidth),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_composer) ...[
                            const NoteComposer(placeholder: 'Add a note for today — or open a day in Today to add one there'),
                            SizedBox(height: t.space.lg),
                          ],
                          if (list.isEmpty)
                            AntEmptyState(
                              icon: Icons.format_list_bulleted_rounded,
                              title: filtered ? 'Nothing matches these filters' : 'Your timeline is empty',
                              message: filtered
                                  ? 'Try another source or project.'
                                  : 'Evidence from your sources and notes lands here, newest first.',
                              action: filtered
                                  ? AntButton(
                                      label: 'Clear filters',
                                      onPressed: () => setState(() {
                                        _sourceId = null;
                                        _projectId = null;
                                      }),
                                    )
                                  : null,
                            ),
                          for (final MapEntry(key: day, value: rows) in days.entries) ...[
                            AntInteractive(
                              semanticLabel: 'Open $day in Today',
                              focusRadius: t.radii.brMd,
                              onTap: () => openEvidenceInToday(ref, day, const {}),
                              builder: (context, s) => Padding(
                                padding: EdgeInsets.fromLTRB(t.space.md, t.space.xl, t.space.md, t.space.sm),
                                child: Row(children: [
                                  Text(
                                    longDayLabel(day),
                                    style: t.typo.bodyStrong.copyWith(color: s.hovered ? t.accentText : t.text),
                                  ),
                                  SizedBox(width: t.space.md),
                                  Muted(plural(rows.length, 'item')),
                                ]),
                              ),
                            ),
                            for (final e in rows) EvidenceRow(key: ValueKey(e.e.id), item: e, compact: true),
                          ],
                          if (list.length >= _limit)
                            Padding(
                              padding: EdgeInsets.only(top: t.space.xl),
                              child: Center(
                                child: AntButton(
                                  label: 'Load more',
                                  onPressed: () => setState(() => _limit += _page),
                                ),
                              ),
                            ),
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
}
