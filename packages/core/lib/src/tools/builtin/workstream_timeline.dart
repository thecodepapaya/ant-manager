import 'package:drift/drift.dart';

import '../tool.dart';
import 'common.dart';

/// Workstreams with facts in a period, each with its facts in time order.
class WorkstreamTimelineTool implements HarnessTool {
  @override
  String get name => 'workstream_timeline';

  @override
  String get description =>
      'Workstreams that have facts overlapping start..end, ordered by first activity, each with its facts '
      'in time order. Retired facts are excluded.';

  @override
  Map<String, Object?> get inputSchema => const {
    'type': 'object',
    'properties': periodProperties,
    'required': ['start', 'end'],
    'additionalProperties': false,
  };

  @override
  Future<Map<String, Object?>> call(Map<String, Object?> input, ToolContext ctx) async {
    final db = ctx.db;
    final start = reqDay(input, 'start');
    final end = reqDay(input, 'end');
    final project = optString(input, 'project_id');
    final facts =
        await (db.select(db.facts)
              ..where((f) => factInPeriod(f, start, end, projectId: project) & f.workstreamId.isNotNull())
              ..orderBy([(f) => OrderingTerm.asc(f.periodStart), (f) => OrderingTerm.asc(f.id)]))
            .get();
    final byWs = <String, List<Map<String, Object?>>>{};
    for (final f in facts) {
      byWs.putIfAbsent(f.workstreamId!, () => []).add(factJson(f));
    }
    final ws = await (db.select(db.workstreams)..where((w) => w.id.isIn(byWs.keys))).get();
    final wsById = {for (final w in ws) w.id: w};
    return {
      'workstreams': [
        // byWs keeps insertion order = first fact's period start.
        for (final MapEntry(:key, :value) in byWs.entries)
          if (wsById[key] case final w?)
            {
              'workstream_id': w.id,
              'title': w.title,
              'summary': w.summary,
              'project_id': w.projectId,
              'span_start': w.spanStart,
              'span_end': w.spanEnd,
              'fact_count': value.length,
              'facts': value,
            },
      ],
    };
  }
}
