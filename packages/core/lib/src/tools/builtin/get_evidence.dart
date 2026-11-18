import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/enums.dart';
import '../tool.dart';
import 'common.dart';

/// One evidence item with its payloads and enrichments.
class GetEvidenceTool implements HarnessTool {
  @override
  String get name => 'get_evidence';

  @override
  String get description =>
      'Gets one evidence item by id, with all its payloads (current revision content) and enrichments.';

  @override
  Map<String, Object?> get inputSchema => const {
    'type': 'object',
    'properties': {
      'evidence_id': {'type': 'string'},
    },
    'required': ['evidence_id'],
    'additionalProperties': false,
  };

  @override
  Future<Map<String, Object?>> call(Map<String, Object?> input, ToolContext ctx) async {
    final db = ctx.db;
    final id = reqString(input, 'evidence_id');
    final e = await (db.select(db.evidences)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (e == null) return {'found': false};
    final payloads = await (db.select(db.payloads)..where((p) => p.evidenceId.equals(id))).get();
    final ids = payloads.map((p) => p.id).toList();
    final enrichments =
        await (db.select(db.enrichments)..where(
              (n) =>
                  (n.targetType.equalsValue(EntityType.evidence) & n.targetId.equals(id)) |
                  (n.targetType.equalsValue(EntityType.payload) & n.targetId.isIn(ids)),
            ))
            .get();
    return {
      'found': true,
      'evidence': {
        'evidence_id': e.id,
        'day': e.day,
        'title': e.title,
        'occurred_start': e.occurredStart.toUtc().toIso8601String(),
        'occurred_end': e.occurredEnd?.toUtc().toIso8601String(),
        'project_id': e.projectId,
        'starred': e.starred,
        'hidden': e.hidden,
        'importance': e.importance,
      },
      'payloads': [
        for (final p in payloads)
          {
            'payload_id': p.id,
            'kind': p.kind.name,
            'revision': p.revision,
            'tombstoned': p.tombstonedAt != null,
            'content': jsonDecode(p.content),
          },
      ],
      'enrichments': [
        for (final n in enrichments)
          {
            'enrichment_id': n.id,
            'target_type': n.targetType.name,
            'target_id': n.targetId,
            'kind': n.kind,
            'output': n.output,
            'revision': n.revision,
          },
      ],
    };
  }
}
