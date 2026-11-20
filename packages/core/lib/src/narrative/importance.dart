import 'dart:convert';

import 'package:drift/drift.dart';

import '../data/profile_db.dart';
import '../domain/enums.dart';
import 'context.dart';

/// Importance per evidence item (LLD 04 §4.4, #60): model score + overrides.
/// Precedence: user per-item > CurationRule (highest priority match) > model.
class ImportanceScorer {
  ImportanceScorer(this.ctx);
  final NarrativeContext ctx;
  ProfileDb get db => ctx.db;

  static const batchSize = 50;
  static const neutral = 0.5;
  static const _excerptChars = 400;

  static const schema = <String, Object?>{
    'type': 'object',
    'properties': {
      'scores': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'evidence_id': {'type': 'string'},
            'score': {'type': 'number', 'minimum': 0, 'maximum': 1},
            'reason': {'type': 'string'},
          },
          'required': ['evidence_id', 'score', 'reason'],
          'additionalProperties': false,
        },
      },
    },
    'required': ['scores'],
    'additionalProperties': false,
  };

  static const system = '''
You rate how much each work item matters for an engineer's record of their work (stand-ups, manager updates,
performance reviews). Score 0..1:
- 0.8–1.0: shipped outcomes, design decisions, incidents, hand-offs, launches, recognition, mentoring that unblocked someone.
- 0.4–0.7: normal feature work, substantive reviews, planning meetings with decisions.
- 0.0–0.3: routine syncs and stand-ups, trivial commits (typos, formatting, version bumps), personal or admin events.
Judge only from the content given. Give a short reason (under 15 words). Return one entry per evidence_id given.''';

  /// Applies rules to the day's evidence, then model-scores what's unscored or changed.
  Future<void> scoreDay(String day) async {
    final evidence = await (db.select(db.evidences)..where((e) => e.day.equals(day))).get();
    if (evidence.isEmpty) return;
    final payloads = await (db.select(
      db.payloads,
    )..where((p) => p.evidenceId.isIn(evidence.map((e) => e.id)) & p.tombstonedAt.isNull())).get();
    final sources = {for (final s in await db.select(db.sources).get()) s.id: s};
    final rules =
        (await (db.select(db.curationRules)
                  ..where((r) => r.enabled.equals(true))
                  ..orderBy([(r) => OrderingTerm.desc(r.priority)]))
                .get())
            .map(RuleMatcher.new)
            .toList();

    final toScore = <(Evidence, List<Payload>)>[];
    for (final e in evidence) {
      final ps = payloads.where((p) => p.evidenceId == e.id).toList();
      if (ps.isEmpty || e.importanceSetBy == ImportanceSetBy.user) continue;
      final rule = rules.where((r) => r.matches(e, ps, sources)).firstOrNull;
      if (rule != null) {
        await _write(
          e,
          importance: rule.row.action == CurationAction.hide ? 0.0 : rule.row.value.clamp(0.0, 1.0).toDouble(),
          reason: 'rule ${rule.row.id}',
          setBy: ImportanceSetBy.rule,
          hidden: rule.row.action == CurationAction.hide,
        );
        continue;
      }
      if (e.importanceSetBy == ImportanceSetBy.rule) {
        // The rule no longer matches: back to the model's score. Only rules hide non-user evidence.
        await _write(e, importance: neutral, reason: null, setBy: null, hidden: false);
        toScore.add((e, ps));
      } else if (e.importanceSetBy == null || await _payloadsChanged(e, ps)) {
        toScore.add((e, ps));
      }
    }

    for (var i = 0; i < toScore.length; i += batchSize) {
      await _scoreBatch(toScore.sublist(i, (i + batchSize).clamp(0, toScore.length)));
    }
  }

  Future<bool> _payloadsChanged(Evidence e, List<Payload> ps) async {
    final recorded = await (db.select(
      db.dependencies,
    )..where((d) => d.dependentType.equalsValue(EntityType.evidence) & d.dependentId.equals(e.id))).get();
    final a = {for (final d in recorded) '${d.inputId}:${d.inputRevision}'};
    final b = {for (final p in ps) '${p.id}:${p.revision}'};
    return a.length != b.length || !a.containsAll(b);
  }

  Future<void> _scoreBatch(List<(Evidence, List<Payload>)> batch) async {
    final items = [
      for (final (e, ps) in batch)
        {
          'evidence_id': e.id,
          'title': e.title,
          'kinds': ps.map((p) => p.kind.name).toSet().toList(),
          'excerpt': ps.map((p) => excerpt(p, _excerptChars)).join('\n'),
        },
    ];
    final out = await ctx.structured(
      LlmRoute.extraction,
      system: system,
      user: 'Rate these evidence items:\n${const JsonEncoder.withIndent(' ').convert(items)}',
      schema: schema,
      schemaName: 'importance',
    );
    final byId = {for (final (e, ps) in batch) e.id: (e, ps)};
    // Short write transaction after the model call, re-checking each item's inputs.
    await db.transaction(() async {
      for (final s in (out['scores'] as List? ?? const []).whereType<Map>()) {
        final hit = byId[s['evidence_id']];
        final score = s['score'];
        if (hit == null || score is! num) continue;
        final (e, ps) = hit;
        // Re-read: a user may have starred/hidden it while the model was thinking.
        final fresh = await (db.select(db.evidences)..where((x) => x.id.equals(e.id))).getSingleOrNull();
        if (fresh == null ||
            fresh.importanceSetBy == ImportanceSetBy.user ||
            fresh.importanceSetBy == ImportanceSetBy.rule) {
          continue;
        }
        // Its payloads changed meanwhile: discard the score; the day is re-queued to score them.
        final now = await (db.select(
          db.payloads,
        )..where((p) => p.evidenceId.equals(e.id) & p.tombstonedAt.isNull())).get();
        if (!_sameRevisions(now, ps)) {
          await ctx.enqueue(EntityType.day, fresh.day, 'payloads changed during importance scoring');
          continue;
        }
        await _write(
          fresh,
          importance: score.toDouble().clamp(0.0, 1.0),
          reason: s['reason'] as String?,
          setBy: ImportanceSetBy.model,
        );
        await ctx.deps.record(
          (type: EntityType.evidence, id: e.id),
          1,
          [for (final p in ps) (type: EntityType.payload, id: p.id, revision: p.revision)],
        );
      }
    });
  }

  static bool _sameRevisions(List<Payload> a, List<Payload> b) {
    final x = {for (final p in a) '${p.id}:${p.revision}'};
    final y = {for (final p in b) '${p.id}:${p.revision}'};
    return x.length == y.length && x.containsAll(y);
  }

  /// Writes only on change, so re-running a day doesn't re-fire the curation trigger.
  Future<void> _write(
    Evidence e, {
    required double importance,
    required String? reason,
    required ImportanceSetBy? setBy,
    bool? hidden,
  }) async {
    if (e.importance == importance &&
        e.importanceReason == reason &&
        e.importanceSetBy == setBy &&
        (hidden == null || e.hidden == hidden)) {
      return;
    }
    // [e] may be stale: never overwrite a user override committed since it was read (#131).
    await (db.update(db.evidences)
          ..where((x) => x.id.equals(e.id) & x.importanceSetBy.isNotValue(ImportanceSetBy.user.name)))
        .write(
      EvidencesCompanion(
        importance: Value(importance),
        importanceReason: Value(reason),
        importanceSetBy: Value(setBy),
        hidden: hidden == null ? const Value.absent() : Value(hidden),
        updatedAt: Value(ctx.clock.now()),
      ),
    );
  }
}

/// CurationRule.match JSON: {sourceKind?, titlePattern?, repo?, minAttendees?, maxAttendees?}.
/// All given fields must match. titlePattern is a case-insensitive substring, or a glob when it
/// contains `*` or `?`. repo matches a payload's content `repo` (PRs/MRs: "owner/name") or the end of
/// its git source's `path` config. Attendees come from calendar content `attendeesCount`.
class RuleMatcher {
  RuleMatcher(this.row) : _m = _decode(row.match);
  final CurationRule row;
  final Map<String, Object?> _m;

  static Map<String, Object?> _decode(String s) {
    final v = jsonDecode(s);
    return v is Map<String, Object?> ? v : const {};
  }

  bool matches(Evidence e, List<Payload> ps, Map<String, SourceRow> sources) {
    if (_m.isEmpty) return false;
    final kind = _m['sourceKind'];
    if (kind is String && !ps.any((p) => sources[p.sourceId]?.kind.name == kind)) return false;
    final pattern = _m['titlePattern'];
    if (pattern is String && !titleMatches(pattern, e.title)) return false;
    final repo = _m['repo'];
    if (repo is String && !ps.any((p) => repoMatches(repo, p, sources[p.sourceId]))) return false;
    final min = _m['minAttendees'], max = _m['maxAttendees'];
    if (min is num || max is num) {
      final counts = ps.map((p) => attendeeCount(contentOf(p))).whereType<int>();
      if (counts.isEmpty) return false;
      final n = counts.first;
      if (min is num && n < min) return false;
      if (max is num && n > max) return false;
    }
    return true;
  }

  static bool repoMatches(String repo, Payload p, SourceRow? source) {
    final r = repo.toLowerCase();
    if (contentOf(p)['repo']?.toString().toLowerCase() == r) return true;
    final path = source == null ? null : _decode(source.config)['path']?.toString().toLowerCase();
    return path != null && (path == r || path.endsWith('/$r'));
  }

  static bool titleMatches(String pattern, String title) {
    final p = pattern.toLowerCase(), t = title.toLowerCase();
    if (!p.contains('*') && !p.contains('?')) return t.contains(p);
    final re = RegExp(
      '^${p.split('').map((c) => c == '*'
          ? '.*'
          : c == '?'
          ? '.'
          : RegExp.escape(c)).join()}\$',
    );
    return re.hasMatch(t);
  }
}

/// Calendar attendee count (`attendeesCount`; `attendees` as a count or list is also accepted).
int? attendeeCount(Map<String, Object?> c) {
  final a = c['attendeesCount'] ?? c['attendees'];
  if (a is num) return a.toInt();
  if (a is List) return a.length;
  return null;
}
