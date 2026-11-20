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
/// out) is never moved again. The same call refreshes the summary of an existing workstream a fact
/// joins (`new_summary`, #109); user-touched workstreams keep their title and summary.
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
Facts that belong together get the same new_title. Don't create a workstream per fact; prefer existing ones.
When a fact joins an existing workstream and changes what it covers, set new_summary to its refreshed one-sentence
summary (covering its earlier work too); otherwise new_summary null.''';

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
    )..where((w) => w.spanEnd.isBiggerOrEqualValue(since))).get(); // null span = no live facts (#110)
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
    await db.transaction(() => _apply(day, out, facts, {for (final w in active) w.id}));
  }

  Future<void> _apply(String day, Map<String, Object?> out, List<Fact> asked, Set<String> offered) async {
    final asOf = {for (final f in asked) f.id: f.revision};
    final facts = await (db.select(db.facts)..where(
          (f) =>
              f.id.isIn(asOf.keys) &
              f.workstreamId.isNull() &
              f.retired.equals(false) &
              f.origin.equalsValue(FactOrigin.inferred),
        ))
        .get();
    // Ids: offered ones that still exist (one may have emptied meanwhile). Titles: any existing workstream,
    // so a new title reuses an empty one instead of duplicating it (#110).
    final all = await db.select(db.workstreams).get();
    final byId = {
      for (final w in all)
        if (offered.contains(w.id)) w.id: w,
    };
    final byTitle = {for (final w in all) w.title.toLowerCase(): w.id};
    final factById = {
      for (final f in facts)
        if (asOf[f.id] == f.revision) f.id: f,
    };
    final changed = <String>{};
    final summaries = <String, String>{};
    // Created in this batch with a blank summary: the first later non-blank summary fills it.
    final createdBlank = <String>{};
    for (final a in (out['assignments'] as List? ?? const []).whereType<Map>()) {
      final f = factById.remove(a['fact_id']);
      if (f == null) continue;
      var wsId = byId.containsKey(a['workstream_id']) ? a['workstream_id'] as String : null;
      final title = (a['new_title'] as String?)?.trim();
      final summary = (a['new_summary'] as String?)?.trim() ?? '';
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
                  summary: Value(summary),
                  spanStart: Value(day),
                  spanEnd: Value(day),
                ),
              );
          byTitle[title.toLowerCase()] = wsId;
          if (summary.isEmpty) createdBlank.add(wsId);
        } else if (summary.isNotEmpty && createdBlank.remove(wsId)) {
          summaries[wsId] = summary;
        }
      }
      if (wsId == null) continue;
      // Any existing workstream (offered or reused by title); just-created ones are handled above.
      final existing = all.where((w) => w.id == wsId).firstOrNull;
      if (existing != null && !existing.userTouched && summary.isNotEmpty) {
        summaries[wsId] = summary;
      }
      // Workstream membership isn't fact content: no revision bump.
      await (db.update(db.facts)..where((x) => x.id.equals(f.id))).write(FactsCompanion(workstreamId: Value(wsId)));
      changed.add(wsId);
    }
    for (final id in changed) {
      await updateSpan(id);
    }
    for (final MapEntry(key: id, value: summary) in summaries.entries) {
      await (db.update(
        db.workstreams,
      )..where((w) => w.id.equals(id))).write(WorkstreamsCompanion(summary: Value(summary)));
    }
  }

  /// Span = first..last day of the workstream's live facts.
  Future<void> updateSpan(String workstreamId) => updateWorkstreamSpan(db, workstreamId);
}
