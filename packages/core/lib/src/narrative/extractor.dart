import 'package:drift/drift.dart';

import '../data/profile_db.dart';
import '../domain/enums.dart';
import 'context.dart';
import 'day_input.dart';
import 'interfaces.dart';

/// Fact types the model may produce. Time allocation is computed in code (#90).
const modelFactTypes = {
  'outcome': FactType.outcome,
  'problem_solved': FactType.problemSolved,
  'invisible_work': FactType.invisibleWork,
  'hiccup': FactType.hiccup,
  'decision': FactType.decision,
};

String factTypeName(FactType t) =>
    modelFactTypes.entries.where((e) => e.value == t).firstOrNull?.key ?? 'time_allocation';

/// Per-day fact extraction (LLD 04 §4.6, #72) on the Extraction route.
class LlmFactExtractor implements FactExtractor {
  LlmFactExtractor(this.ctx);
  final NarrativeContext ctx;
  ProfileDb get db => ctx.db;

  /// Share of the model context the prompt may use.
  static const budgetShare = 0.6;
  static const _excerptChars = 1500;

  static const schema = <String, Object?>{
    'type': 'object',
    'properties': {
      'ops': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'op': {
              'type': 'string',
              'enum': ['create', 'update', 'retire'],
            },
            'fact_id': {
              'type': ['string', 'null'],
            },
            'type': {
              'type': ['string', 'null'],
              'enum': ['outcome', 'problem_solved', 'invisible_work', 'hiccup', 'decision', null],
            },
            'statement': {
              'type': ['string', 'null'],
            },
            'citations': {
              'type': 'array',
              'items': {'type': 'string'},
            },
            'project_id': {
              'type': ['string', 'null'],
            },
            'importance': {
              'type': ['number', 'null'],
            },
            'suggest_win': {
              'type': ['boolean', 'null'],
            },
            'reason': {
              'type': ['string', 'null'],
            },
          },
          'required': [
            'op',
            'fact_id',
            'type',
            'statement',
            'citations',
            'project_id',
            'importance',
            'suggest_win',
            'reason',
          ],
          'additionalProperties': false,
        },
      },
    },
    'required': ['ops'],
    'additionalProperties': false,
  };

  static const system = '''
You maintain the "narrative" of one engineer's work: typed, factual statements, each backed by evidence.
You get one day's evidence (payload ids, raw excerpts, summaries) and the facts already recorded for that day.
Return the minimal set of operations that makes the day's facts correct and complete.

Fact types:
- outcome: something shipped, delivered, merged, launched or achieved (results, not activity).
- problem_solved: a bug, incident or technical problem that was diagnosed or fixed; say what the problem was.
- invisible_work: reviews, mentoring, unblocking others, interviews, incident support, meetings that moved work forward.
- hiccup: something that went wrong or slowed the work (blocked, reverted, failed deploy, rework).
- decision: a technical or product decision that was made, and its rationale if stated.
Do NOT produce time-allocation facts; time is computed separately.

Rules:
- Every create/update must cite at least one payload id from the evidence below, and only ids that support the statement.
- One statement = one claim, one sentence, past tense, specific (name the system/feature/PR), no filler or praise.
  Write for the engineer's own record ("Shipped…", "Fixed…", "Reviewed…"), not "the user".
- Merge related evidence into one fact rather than one fact per commit. Routine or trivial items need no fact.
- Use "update" for an existing fact whose wording or citations should change given the evidence; "retire" when its
  evidence no longer supports it. Leave correct facts alone (no op). Never re-create a fact listed as rejected.
- Facts marked user-owned were set by the user; propose an update/retire only if the evidence clearly contradicts them.
- project_id: one of the listed project ids, or null. importance: 0..1 for how much the fact matters in a review.
- suggest_win: true only for an outcome that would be worth highlighting in a performance review.
- For update/retire, set fact_id and give a short reason; for create, fact_id is null.''';

  @override
  Future<FactChangeSet> extract(String day) async {
    final input = await DayInput.load(db, day);
    final facts = await (db.select(
      db.facts,
    )..where((f) => f.periodStart.equals(day) & f.type.equalsValue(FactType.timeAllocation).not())).get();
    final live = facts.where((f) => !f.retired).toList();
    final rejected = facts.where((f) => f.retired && f.origin.isUserTouched).toList();
    if (input.items.isEmpty && live.isEmpty) return FactChangeSet(day, const []);

    final user = await _prompt(day, input, live, rejected);
    final out = await ctx.structured(
      LlmRoute.extraction,
      system: system,
      user: user,
      schema: schema,
      schemaName: 'fact_ops',
    );
    return FactChangeSet(day, parseOps(out));
  }

  Future<String> _prompt(String day, DayInput input, List<Fact> live, List<Fact> rejected) async {
    final budgetChars = ((await ctx.contextTokens(LlmRoute.extraction)) * budgetShare * 4).floor() - system.length;
    final b = StringBuffer('Day: $day\n\n');

    final projects = await (db.select(db.projects)..where((p) => p.archived.equals(false))).get();
    b.writeln('## Projects');
    for (final p in projects) {
      b.writeln('- ${p.id}: ${p.name}');
    }
    if (projects.isEmpty) b.writeln('(none)');

    final since = shiftDay(day, -30);
    final ws = await (db.select(db.workstreams)..where((w) => w.spanEnd.isBiggerOrEqualValue(since))).get();
    if (ws.isNotEmpty) {
      b.writeln('\n## Active workstreams (hints only)');
      for (final w in ws) {
        b.writeln('- ${w.title}${w.summary.isEmpty ? '' : ': ${w.summary}'}');
      }
    }

    b.writeln('\n## Existing facts for this day');
    if (live.isEmpty) b.writeln('(none)');
    final cites = await _citations([...live, ...rejected]);
    for (final f in live) {
      b.writeln(
        '- fact_id=${f.id} type=${factTypeName(f.type)} '
        '${f.origin.isUserTouched ? 'user-owned' : 'model'} cites=[${cites[f.id]?.join(', ') ?? ''}]: ${f.statement}',
      );
    }
    if (rejected.isNotEmpty) {
      b.writeln('\n## Rejected by the user (never re-create these)');
      for (final f in rejected) {
        b.writeln('- ${factTypeName(f.type)}: ${f.statement}');
      }
    }

    b.writeln('\n## Evidence (most important first)');
    final rest = <DayItem>[];
    for (final item in input.items) {
      final block = _block(item);
      if (b.length + block.length > budgetChars) {
        rest.add(item);
      } else {
        b.write(block);
      }
    }
    if (rest.isNotEmpty) {
      b.writeln('\n## More evidence (title only)');
      for (final item in rest) {
        b.writeln('- ${item.evidence.title} [payloads: ${item.payloads.map((p) => p.id).join(', ')}]');
      }
    }
    if (input.items.isEmpty) b.writeln('(none: all evidence for this day was removed or hidden)');
    return b.toString();
  }

  String _block(DayItem item) {
    final e = item.evidence;
    final b = StringBuffer('\n### ${e.title}\n')
      ..writeln(
        'time: ${e.occurredStart.toIso8601String()}${e.occurredEnd == null ? '' : ' – ${e.occurredEnd!.toIso8601String()}'}'
        ' · importance ${e.importance.toStringAsFixed(2)}${e.projectId == null ? '' : ' · project ${e.projectId}'}'
        '${e.starred ? ' · starred by user' : ''}',
      );
    for (final p in item.payloads) {
      b.writeln('- payload_id=${p.id} kind=${p.kind.name}');
      final n = item.enrichments[p.id];
      if (n != null) b.writeln('  summary: ${n.output}');
      b.writeln('  raw: ${excerpt(p, _excerptChars)}');
    }
    return b.toString();
  }

  Future<Map<String, List<String>>> _citations(List<Fact> facts) async {
    if (facts.isEmpty) return {};
    final rows = await (db.select(db.citations)..where((c) => c.factId.isIn(facts.map((f) => f.id)))).get();
    final m = <String, List<String>>{};
    for (final c in rows) {
      m.putIfAbsent(c.factId, () => []).add(c.payloadId);
    }
    return m;
  }

  /// Structured output → ops. Malformed entries are skipped (the reconciler checks the rest).
  static List<FactOp> parseOps(Map<String, Object?> out) {
    final ops = <FactOp>[];
    for (final o in (out['ops'] as List? ?? const []).whereType<Map>()) {
      final cites = (o['citations'] as List? ?? const []).whereType<String>().toList();
      final statement = (o['statement'] as String?)?.trim();
      final factId = o['fact_id'] as String?;
      switch (o['op']) {
        case 'create':
          final type = modelFactTypes[o['type']];
          if (type == null || statement == null || statement.isEmpty) continue;
          ops.add(
            CreateFact(
              type: type,
              statement: statement,
              citations: cites,
              projectId: o['project_id'] as String?,
              importance: (o['importance'] as num?)?.toDouble() ?? 0.5,
              suggestWin: o['suggest_win'] == true,
            ),
          );
        case 'update':
          if (factId == null || statement == null || statement.isEmpty) continue;
          ops.add(UpdateFact(factId: factId, statement: statement, citations: cites));
        case 'retire':
          if (factId == null) continue;
          ops.add(RetireFact(factId: factId, reason: (o['reason'] as String?) ?? ''));
      }
    }
    return ops;
  }
}
