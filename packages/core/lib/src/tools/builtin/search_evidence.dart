import 'package:drift/drift.dart';

import '../tool.dart';
import 'common.dart';

/// Full-text search (FTS5, #52) over payload content and fact statements.
class SearchEvidenceTool implements HarnessTool {
  @override
  String get name => 'search_evidence';

  @override
  String get description =>
      'Full-text search over evidence payloads and narrative facts. All words must match. '
      'Optionally limited to a day range and a project. Hidden evidence and retired facts are excluded.';

  @override
  Map<String, Object?> get inputSchema => const {
    'type': 'object',
    'properties': {
      'query': {'type': 'string', 'description': 'Words to search for.'},
      ...periodProperties,
      'limit': {'type': 'integer', 'minimum': 1, 'maximum': 100, 'default': 20},
    },
    'required': ['query'],
    'additionalProperties': false,
  };

  @override
  Future<Map<String, Object?>> call(Map<String, Object?> input, ToolContext ctx) async {
    final match = ftsQuery(reqString(input, 'query'));
    if (match.isEmpty) return {'evidence': [], 'facts': []};
    final start = optDay(input, 'start');
    final end = optDay(input, 'end');
    final project = optString(input, 'project_id');
    final limit = optInt(input, 'limit', 20).clamp(1, 100);
    final vars = [
      Variable.withString(match),
      Variable<String>(start),
      Variable<String>(end),
      Variable<String>(project),
      Variable.withInt(limit),
    ];
    final db = ctx.db;
    final payloads = await db
        .customSelect(
          '''
SELECT p.id AS payload_id, p.kind AS kind, e.id AS evidence_id, e.day AS day, e.title AS title,
       e.project_id AS project_id, snippet(fts_payloads, 1, '[', ']', '…', 12) AS snippet
FROM fts_payloads
JOIN payloads p ON p.id = fts_payloads.payload_id
JOIN evidences e ON e.id = p.evidence_id
WHERE fts_payloads MATCH ?1 AND e.hidden = 0 AND p.tombstoned_at IS NULL
  AND (?2 IS NULL OR e.day >= ?2) AND (?3 IS NULL OR e.day <= ?3) AND (?4 IS NULL OR e.project_id = ?4)
ORDER BY bm25(fts_payloads) LIMIT ?5''',
          variables: vars,
          readsFrom: {db.payloads, db.evidences},
        )
        .get();
    final facts = await db
        .customSelect(
          '''
SELECT f.id AS fact_id, f.type AS type, f.statement AS statement, f.period_start AS period_start,
       f.period_end AS period_end, f.project_id AS project_id
FROM fts_facts
JOIN facts f ON f.id = fts_facts.fact_id
WHERE fts_facts MATCH ?1 AND f.retired = 0
  AND (?2 IS NULL OR f.period_end >= ?2) AND (?3 IS NULL OR f.period_start <= ?3) AND (?4 IS NULL OR f.project_id = ?4)
ORDER BY bm25(fts_facts) LIMIT ?5''',
          variables: vars,
          readsFrom: {db.facts},
        )
        .get();
    return {
      'evidence': [for (final r in payloads) r.data],
      'facts': [for (final r in facts) r.data],
    };
  }
}

/// Turns free text into a safe FTS5 query: every word quoted, implicitly ANDed.
String ftsQuery(String text) =>
    text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).map((w) => '"${w.replaceAll('"', '""')}"').join(' ');
