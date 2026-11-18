import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/enums.dart';
import '../tool.dart';
import 'common.dart';

/// Sums Time allocation facts (LLD 04 §4.7) per project and basis over a period.
class TimeBreakdownTool implements HarnessTool {
  @override
  String get name => 'time_breakdown';

  @override
  String get description =>
      'Total minutes per project over start..end, split into measured (calendar) and estimated (commit sessions), '
      'summed from Time allocation facts. Project null = unassigned.';

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
    final start = reqString(input, 'start');
    final end = reqString(input, 'end');
    final project = optString(input, 'project_id');
    final facts =
        await (db.select(db.facts)
              ..where(
                (f) => factInPeriod(f, start, end, projectId: project) & f.type.equalsValue(FactType.timeAllocation),
              )
              ..orderBy([(f) => OrderingTerm.asc(f.periodStart), (f) => OrderingTerm.asc(f.id)]))
            .get();
    final names = {for (final p in await db.select(db.projects).get()) p.id: p.name};
    final rows = <String?, _Row>{};
    for (final f in facts) {
      final d = jsonDecode(f.details) as Map<String, Object?>;
      final minutes = (d['minutes'] as num?)?.toInt() ?? 0;
      final r = rows.putIfAbsent(f.projectId, () => _Row());
      if (d['basis'] == 'measured') {
        r.measured += minutes;
      } else {
        r.estimated += minutes;
      }
      r.factIds.add(f.id);
    }
    final byProject = [
      for (final MapEntry(:key, :value) in rows.entries)
        {
          'project_id': key,
          'project_name': key == null ? null : names[key],
          'measured_minutes': value.measured,
          'estimated_minutes': value.estimated,
          'total_minutes': value.measured + value.estimated,
          'fact_ids': value.factIds,
        },
    ]..sort((a, b) => (b['total_minutes'] as int).compareTo(a['total_minutes'] as int));
    return {
      'total_minutes': byProject.fold<int>(0, (s, r) => s + (r['total_minutes'] as int)),
      'by_project': byProject,
    };
  }
}

class _Row {
  int measured = 0, estimated = 0;
  final factIds = <String>[];
}
