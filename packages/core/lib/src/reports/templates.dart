import 'package:drift/drift.dart';

import '../data/profile_db.dart';
import '../domain/enums.dart';
import '../util/ids.dart';
import 'periods.dart';

/// A built-in template shipped in code (LLD 02: built-ins ship in code, custom ones are per profile).
class BuiltinTemplate {
  const BuiltinTemplate(this.id, this.name, this.periodKinds, this.prompt);
  final String id, name;
  final List<PeriodKind> periodKinds;
  final String prompt;
}

/// Variables available in template prompts (`{name}`); unknown names are left as-is.
const templateVariables = ['period_label', 'period_kind', 'start', 'end'];

const builtinTemplates = <BuiltinTemplate>[
  BuiltinTemplate(
    'builtin.standup',
    'Standup',
    [PeriodKind.daily],
    '''
Write a standup update for {period_label}.
Sections, in this order: "Done" (what was completed or moved forward), "Blockers" (hiccups or problems still open;
omit the section if there are none), "Notes" (decisions worth knowing; omit if none).
One short line per item, past tense, no filler. Group by project only if there are several.''',
  ),
  BuiltinTemplate(
    'builtin.manager_update',
    'Manager update',
    [PeriodKind.weekly, PeriodKind.monthly, PeriodKind.custom],
    '''
Write an update for my manager covering {period_label} ({start} to {end}).
Sections: "Highlights" (outcomes and wins first), "Progress by project" (one section per project is fine),
"Risks and blockers" (hiccups, open problems), "Decisions" (omit if none).
Plain, factual, confident. Lead each item with the result, then the context.''',
  ),
  BuiltinTemplate(
    'builtin.weekly_review',
    'Weekly review',
    [PeriodKind.weekly],
    '''
Write a weekly review for {period_label} ({start} to {end}).
Sections: "Outcomes", "Problems solved", "Invisible work" (support, reviews, unblocking others),
"Hiccups and lessons", "Where the time went" (from the time breakdown, by project).
Omit empty sections. Keep items to one or two sentences.''',
  ),
  BuiltinTemplate(
    'builtin.monthly_recap',
    'Monthly recap',
    [PeriodKind.monthly],
    '''
Write a monthly recap for {period_label}.
Start with a "Summary" section of three to five items capturing the month's most important outcomes.
Then one section per major workstream or project with its outcomes, problems solved and decisions.
End with "Time" (from the time breakdown) and "Looking back" (hiccups and what they taught). Omit empty sections.''',
  ),
  BuiltinTemplate(
    'builtin.wins',
    'Wins summary',
    [PeriodKind.weekly, PeriodKind.monthly, PeriodKind.quarterly, PeriodKind.custom],
    '''
Summarize my wins for {period_label} ({start} to {end}).
Use only facts marked as wins or clear outcomes. Sections by project.
Each item states the result and its impact in one sentence.''',
  ),
  BuiltinTemplate(
    'builtin.brag_doc',
    'Brag doc',
    [PeriodKind.quarterly, PeriodKind.custom],
    '''
Write a brag document for a performance review covering {period_label} ({start} to {end}).
Sections: "Key accomplishments" (the biggest outcomes and wins, with impact), "Projects" (one section per project:
what I delivered and the problems I solved), "Collaboration and invisible work", "Decisions and judgement",
"Growth" (hiccups handled and lessons). Specific, first person, no exaggeration. Omit empty sections.''',
  ),
];

/// Default template per scheduled report kind.
const defaultTemplateFor = <PeriodKind, String>{
  PeriodKind.daily: 'builtin.standup',
  PeriodKind.weekly: 'builtin.weekly_review',
  PeriodKind.monthly: 'builtin.monthly_recap',
  PeriodKind.quarterly: 'builtin.brag_doc',
  PeriodKind.custom: 'builtin.manager_update',
};

BuiltinTemplate? builtinById(String id) {
  for (final t in builtinTemplates) {
    if (t.id == id) return t;
  }
  return null;
}

/// Fills `{variables}` in a template prompt for [period].
String renderPrompt(String prompt, Period period) {
  final vars = {
    'period_label': period.label,
    'period_kind': period.kind.name,
    'start': period.start,
    'end': period.end,
  };
  return prompt.replaceAllMapped(RegExp(r'\{(\w+)\}'), (m) => vars[m[1]] ?? m[0]!);
}

List<PeriodKind> parsePeriodKinds(String s) => [
  for (final k in s.split(','))
    if (k.isNotEmpty) PeriodKind.values.byName(k),
];

String _kinds(List<PeriodKind> kinds) => kinds.map((k) => k.name).join(',');

/// Template editor support (#86). Built-ins are read-only: editing one duplicates it.
///
/// A copy of a built-in gets the id `<builtinId>/<ulid>` so reset-to-default can find its origin
/// without a schema column.
class TemplateService {
  TemplateService(this.db);
  final ProfileDb db;

  /// Inserts or refreshes the built-in templates from code. Safe to call on every launch.
  Future<void> seedBuiltins() => db.batch((b) {
    for (final t in builtinTemplates) {
      b.insert(
        db.templates,
        TemplatesCompanion.insert(
          id: t.id,
          name: t.name,
          periodKinds: _kinds(t.periodKinds),
          prompt: t.prompt,
          builtIn: const Value(true),
        ),
        onConflict: DoUpdate(
          (_) => TemplatesCompanion(
            name: Value(t.name),
            periodKinds: Value(_kinds(t.periodKinds)),
            prompt: Value(t.prompt),
          ),
        ),
      );
    }
  });

  Future<Template> get(String id) => (db.select(db.templates)..where((t) => t.id.equals(id))).getSingle();

  Future<List<Template>> list() =>
      (db.select(db.templates)..orderBy([(t) => OrderingTerm.desc(t.builtIn), (t) => OrderingTerm.asc(t.name)])).get();

  Future<String> create({required String name, required List<PeriodKind> periodKinds, required String prompt}) async {
    final id = newId();
    await db
        .into(db.templates)
        .insert(TemplatesCompanion.insert(id: id, name: name, periodKinds: _kinds(periodKinds), prompt: prompt));
    return id;
  }

  Future<String> duplicate(String id, {String? name}) async {
    final src = await get(id);
    final root = _builtinRoot(src.id);
    final newTemplateId = root == null ? newId() : '$root/${newId()}';
    await db
        .into(db.templates)
        .insert(
          TemplatesCompanion.insert(
            id: newTemplateId,
            name: name ?? '${src.name} (copy)',
            periodKinds: src.periodKinds,
            prompt: src.prompt,
          ),
        );
    return newTemplateId;
  }

  /// Updates a custom template (version + 1). Editing a built-in duplicates it first;
  /// returns the id of the template that was actually changed.
  Future<String> update(String id, {String? name, List<PeriodKind>? periodKinds, String? prompt}) async {
    var t = await get(id);
    if (t.builtIn) t = await get(await duplicate(id, name: name ?? t.name));
    await (db.update(db.templates)..where((x) => x.id.equals(t.id))).write(
      TemplatesCompanion(
        name: Value(name ?? t.name),
        periodKinds: Value(periodKinds == null ? t.periodKinds : _kinds(periodKinds)),
        prompt: Value(prompt ?? t.prompt),
        version: Value(t.version + 1),
      ),
    );
    return t.id;
  }

  /// Resets a copy of a built-in back to the built-in's current prompt and period kinds.
  Future<void> resetToDefault(String id) async {
    final t = await get(id);
    if (t.builtIn) return;
    final root = _builtinRoot(id);
    final b = root == null ? null : builtinById(root);
    if (b == null) throw StateError('Template $id is not based on a built-in template');
    await (db.update(db.templates)..where((x) => x.id.equals(id))).write(
      TemplatesCompanion(
        periodKinds: Value(_kinds(b.periodKinds)),
        prompt: Value(b.prompt),
        version: Value(t.version + 1),
      ),
    );
  }

  /// Deletes a custom template. Built-ins and templates used by reports can't be deleted.
  Future<void> delete(String id) async {
    final t = await get(id);
    if (t.builtIn) throw StateError('Built-in templates cannot be deleted');
    final used =
        await (db.select(db.reports)
              ..where((r) => r.templateId.equals(id))
              ..limit(1))
            .getSingleOrNull();
    if (used != null) throw StateError('Template is used by existing reports');
    await (db.delete(db.templates)..where((x) => x.id.equals(id))).go();
  }

  static String? _builtinRoot(String id) {
    final root = id.split('/').first;
    return builtinById(root) == null ? null : root;
  }
}
