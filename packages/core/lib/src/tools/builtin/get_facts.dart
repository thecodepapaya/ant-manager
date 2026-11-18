import 'package:drift/drift.dart';

import '../../domain/enums.dart';
import '../tool.dart';
import 'common.dart';

/// Narrative facts overlapping a period, most important first.
class GetFactsTool implements HarnessTool {
  @override
  String get name => 'get_facts';

  @override
  String get description =>
      'Lists narrative facts whose period overlaps start..end, ordered by importance (highest first). '
      'Retired or rejected facts are excluded. Optionally filtered by project and fact types.';

  @override
  Map<String, Object?> get inputSchema => {
    'type': 'object',
    'properties': {
      ...periodProperties,
      'types': {
        'type': 'array',
        'items': {
          'type': 'string',
          'enum': [for (final t in FactType.values) t.name],
        },
      },
      'limit': {'type': 'integer', 'minimum': 1},
    },
    'required': ['start', 'end'],
    'additionalProperties': false,
  };

  @override
  Future<Map<String, Object?>> call(Map<String, Object?> input, ToolContext ctx) async {
    final db = ctx.db;
    final start = reqString(input, 'start');
    final end = reqString(input, 'end');
    final project = optString(input, 'project_id');
    final types = (input['types'] as List?)?.map((t) => FactType.values.byName(t as String)).toList();
    final limit = input['limit'] is num ? (input['limit'] as num).toInt() : null;
    final q = db.select(db.facts)
      ..where((f) {
        var e = factInPeriod(f, start, end, projectId: project);
        if (types != null) e = e & f.type.isIn(types.map((t) => t.name));
        return e;
      })
      ..orderBy(factOrder);
    if (limit != null) q.limit(limit);
    final rows = await q.get();
    return {
      'facts': [for (final f in rows) factJson(f)],
    };
  }
}
