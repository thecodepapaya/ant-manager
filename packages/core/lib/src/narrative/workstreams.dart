import 'dart:convert';

import 'package:drift/drift.dart';

import '../data/profile_db.dart';
import '../domain/enums.dart';
import '../util/ids.dart';
import 'context.dart';
import 'extractor.dart';
import 'fact_writer.dart';

/// Puts a day's new facts into workstreams (LLD 04 §4.8) on the Extraction route.
/// Only model-owned facts without a workstream are assigned, so a fact the user moved (or moved
/// out) is never moved again. User-touched workstreams keep their title and summary.
class WorkstreamAssigner {
  WorkstreamAssigner(this.ctx);
  final NarrativeContext ctx;
  ProfileDb get db => ctx.db;

  static const activeDays = 30;

  static const schema = <String, Object?>{
    'type': 'object',
    'properties': {
      'assignments': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'fact_id': {'type': 'string'},
            'workstream_id': {
              'type': ['string', 'null'],
            },
            'new_title': {
              'type': ['string', 'null'],
            },
            'new_summary': {
              'type': ['string', 'null'],
            },
          },
          'required': ['fact_id', 'workstream_id', 'new_title', 'new_summary'],
          'additionalProperties': false,
        },
      },
    },
    'required': ['assignments'],
    'additionalProperties': false,
  };

  static const system = '''
You group an engineer's work facts into workstreams: threads of related work that run over days or weeks
(a feature, a migration, an incident, an ongoing responsibility like hiring or on-call).
For each fact, pick the existing workstream it continues (workstream_id), or, only if none fits, start a new one:
workstream_id null, new_title (2–6 words, specific, e.g. "Payments idempotency keys") and new_summary (one sentence).
Facts that belong together get the same new_title. Don't create a workstream per fact; prefer existing ones.''';

  Future<void> assignDay(String day) async {
    final facts =
        await (db.select(db.facts)..where(
              (f) =>
                  f.periodStart.equals(day) &
                  f.workstreamId.isNull() &
                  f.retired.equals(false) &
                  f.origin.equalsValue(FactOrigin.inferred) &
                  f.type.equalsValue(FactType.timeAllocation).not(),
            ))
            .get();
    if (facts.isEmpty) return;
    final since = shiftDay(day, -activeDays);
    final active = await (db.select(
      db.workstreams,
    )..where((w) => w.spanEnd.isBiggerOrEqualValue(since) | w.spanEnd.isNull())).get();
    final user = jsonEncode({
      'workstreams': [
        for (final w in active) {'id': w.id, 'title': w.title, 'summary': w.summary, 'project_id': w.projectId},
      ],
      'facts': [
        for (final f in facts)
          {'fact_id': f.id, 'type': factTypeName(f.type), 'statement': f.statement, 'project_id': f.projectId},
      ],
    });
    final out = await ctx.structured(
      LlmRoute.extraction,
      system: system,
      user: user,
      schema: schema,
      schemaName: 'workstreams',
    );

    // Short write transaction after the model call. Re-read: facts the user touched, moved, retired
    // or that changed meanwhile, and workstreams removed meanwhile, are skipped.
    await db.transaction(() => _apply(day, out, facts));
  }

  Future<void> _apply(String day, Map<String, Object?> out, List<Fact> asked) async {
    final asOf = {for (final f in asked) f.id: f.revision};
    final facts = await (db.select(db.facts)..where(
          (f) =>
              f.id.isIn(asOf.keys) &
              f.workstreamId.isNull() &
              f.retired.equals(false) &
              f.origin.equalsValue(FactOrigin.inferred),
        ))
        .get();
    final since = shiftDay(day, -activeDays);
    final active = await (db.select(
      db.workstreams,
    )..where((w) => w.spanEnd.isBiggerOrEqualValue(since) | w.spanEnd.isNull())).get();
    final byId = {for (final w in active) w.id: w};
    final byTitle = {for (final w in active) w.title.toLowerCase(): w.id};
    final factById = {
      for (final f in facts)
        if (asOf[f.id] == f.revision) f.id: f,
    };
    final changed = <String>{};
    for (final a in (out['assignments'] as List? ?? const []).whereType<Map>()) {
      final f = factById.remove(a['fact_id']);
      if (f == null) continue;
      var wsId = byId.containsKey(a['workstream_id']) ? a['workstream_id'] as String : null;
      final title = (a['new_title'] as String?)?.trim();
      if (wsId == null && title != null && title.isNotEmpty) {
        wsId = byTitle[title.toLowerCase()];
        if (wsId == null) {
          wsId = newId(ctx.clock.now());
          await db
              .into(db.workstreams)
              .insert(
                WorkstreamsCompanion.insert(
                  id: wsId,
                  title: title,
                  projectId: Value(f.projectId),
                  summary: Value((a['new_summary'] as String?) ?? ''),
                  spanStart: Value(day),
                  spanEnd: Value(day),
                ),
              );
          byTitle[title.toLowerCase()] = wsId;
        }
      }
      if (wsId == null) continue;
      // Workstream membership isn't fact content: no revision bump.
      await (db.update(db.facts)..where((x) => x.id.equals(f.id))).write(FactsCompanion(workstreamId: Value(wsId)));
      changed.add(wsId);
    }
    for (final id in changed) {
      await updateSpan(id);
    }
  }

  /// Span = first..last day of the workstream's live facts.
  Future<void> updateSpan(String workstreamId) => updateWorkstreamSpan(db, workstreamId);
}
