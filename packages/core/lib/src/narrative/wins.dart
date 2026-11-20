import 'package:drift/drift.dart';

import '../data/profile_db.dart';
import '../domain/enums.dart';
import 'context.dart';
import 'extractor.dart' show factTypeName;
import 'fact_writer.dart';

/// Starring evidence (LLD 04 §4.10, #63): a win is an Outcome fact with win_status accepted.
class WinService {
  WinService(this.ctx) : writer = FactWriter(ctx);
  final NarrativeContext ctx;
  final FactWriter writer;
  ProfileDb get db => ctx.db;

  static const schema = <String, Object?>{
    'type': 'object',
    'properties': {
      'fact_id': {
        'type': ['string', 'null'],
      },
      'statement': {'type': 'string'},
      'citations': {
        'type': 'array',
        'items': {'type': 'string'},
      },
    },
    'required': ['fact_id', 'statement', 'citations'],
    'additionalProperties': false,
  };

  static const system = '''
The engineer starred this piece of evidence as a win. Write the single outcome it represents, as it would
appear in a performance review: one past-tense sentence, specific (name the system, feature, PR or person helped),
stating the result, not the activity. Use only what the evidence says; no praise or adjectives.
Cite the payload ids that support it.
If one of the listed existing facts already describes this same accomplishment, set fact_id to its id (it becomes
the win, restated by your statement); otherwise fact_id is null and a new fact is written. Pick a fact only when
it is the same piece of work, not merely related.''';

  /// Stars [evidenceId] and makes sure an accepted Outcome fact covers it. Returns the fact id.
  /// If no Outcome fact cites the evidence yet, a one-off model call writes one (origin userCreated), or turns an
  /// equivalent model-owned fact citing the evidence into the win (no duplicate fact).
  /// The model call runs outside any transaction; call this from a job, not inside the recompute drain.
  Future<String> starEvidence(String evidenceId) async {
    final existing = await db.transaction(() async {
      final e = await (db.select(db.evidences)..where((x) => x.id.equals(evidenceId))).getSingle();
      // A star beats a rule's hide; only the user's own hide keeps it hidden (importance 0).
      final hidden = e.hidden && e.importanceSetBy != ImportanceSetBy.rule;
      await (db.update(db.evidences)..where((x) => x.id.equals(evidenceId))).write(
        EvidencesCompanion(
          starred: const Value(true),
          hidden: Value(hidden),
          importance: Value(hidden ? 0.0 : 1.0),
          importanceSetBy: const Value(ImportanceSetBy.user),
          updatedAt: Value(ctx.clock.now()),
        ),
      );
      final q = db.select(db.facts).join([innerJoin(db.citations, db.citations.factId.equalsExp(db.facts.id))])
        ..where(
          db.citations.payloadId.isInQuery(
                db.selectOnly(db.payloads)
                  ..addColumns([db.payloads.id])
                  ..where(db.payloads.evidenceId.equals(evidenceId)),
              ) &
              db.facts.type.equalsValue(FactType.outcome) &
              db.facts.retired.equals(false),
        )
        ..orderBy([OrderingTerm.desc(db.facts.importance)])
        ..limit(1);
      final f = (await q.getSingleOrNull())?.readTable(db.facts);
      if (f != null && f.winStatus != WinStatus.accepted) await writer.acceptWin(f);
      return f?.id;
    });
    if (existing != null) return existing;

    final e = await (db.select(db.evidences)..where((x) => x.id.equals(evidenceId))).getSingle();
    final payloads = await (db.select(
      db.payloads,
    )..where((p) => p.evidenceId.equals(evidenceId) & p.tombstonedAt.isNull())).get();
    if (payloads.isEmpty) throw StateError('Evidence $evidenceId has no live payloads to cite');
    final enr = {
      for (final n in await (db.select(
        db.enrichments,
      )..where((n) => n.targetType.equalsValue(EntityType.payload) & n.targetId.isIn(payloads.map((p) => p.id)))).get())
        n.targetId: n.output,
    };
    final candidates = await _candidates(payloads.map((p) => p.id));
    final user = StringBuffer('Evidence: ${e.title} (${e.day})\n');
    for (final p in payloads) {
      user.writeln('- payload_id=${p.id} kind=${p.kind.name}');
      if (enr[p.id] != null) user.writeln('  summary: ${enr[p.id]}');
      user.writeln('  raw: ${excerpt(p, 3000)}');
    }
    user.writeln('\nExisting facts citing this evidence:');
    if (candidates.isEmpty) user.writeln('(none)');
    for (final f in candidates) {
      user.writeln('- fact_id=${f.id} type=${factTypeName(f.type)}: ${f.statement}');
    }
    final out = await ctx.structured(
      LlmRoute.extraction,
      system: system,
      user: user.toString(),
      schema: schema,
      schemaName: 'win',
    );
    final statement = (out['statement'] as String?)?.trim();
    if (statement == null || statement.isEmpty) throw StateError('Model returned no outcome statement');
    final ids = payloads.map((p) => p.id).toSet();
    var cites = (out['citations'] as List? ?? const []).whereType<String>().where(ids.contains).toList();
    if (cites.isEmpty) cites = ids.toList(); // the user starred this evidence: it supports the win

    return db.transaction(() async {
      // The user may have unstarred or hidden the evidence while the model ran: don't write the win.
      final now = await (db.select(db.evidences)..where((x) => x.id.equals(evidenceId))).getSingleOrNull();
      if (now == null || !now.starred || (now.hidden && !e.hidden)) {
        throw StateError('Evidence $evidenceId was unstarred or hidden during the win call');
      }
      // The evidence may have been deleted or tombstoned while the model ran: never write an uncited win.
      final liveIds = (await (db.select(
        db.payloads,
      )..where((p) => p.id.isIn(cites) & p.tombstonedAt.isNull())).get()).map((p) => p.id).toSet();
      final live = cites.where(liveIds.contains).toList();
      if (live.isEmpty) throw StateError('Evidence $evidenceId changed during the win call; nothing to cite');
      // Reuse the fact the model picked if it is still an unprotected live fact citing this evidence.
      final pick = (await _candidates(payloads.map((p) => p.id))).where((f) => f.id == out['fact_id']).firstOrNull;
      if (pick != null) {
        final cites = {...await writer.citedPayloads(pick.id), ...live}.toList();
        await writer.acceptWin(pick, statement: statement, citations: cites, importance: 1.0);
        return pick.id;
      }
      return writer.create(
        type: FactType.outcome,
        statement: statement,
        day: now.day,
        citations: live,
        projectId: now.projectId,
        importance: 1.0,
        origin: FactOrigin.userCreated,
        winStatus: WinStatus.accepted,
      );
    });
  }

  /// Live, model-owned result facts (outcome, problem solved, invisible work) citing any of [payloadIds]: the facts
  /// a star may turn into the win. Decisions and hiccups are never retyped.
  Future<List<Fact>> _candidates(Iterable<String> payloadIds) async {
    final q = db.select(db.facts).join([innerJoin(db.citations, db.citations.factId.equalsExp(db.facts.id))])
      ..where(
        db.citations.payloadId.isIn(payloadIds) &
            db.facts.retired.equals(false) &
            db.facts.type.isInValues(const [FactType.outcome, FactType.problemSolved, FactType.invisibleWork]),
      );
    final byId = {for (final r in await q.get()) r.readTable(db.facts).id: r.readTable(db.facts)};
    return byId.values.where((f) => !isProtected(f)).toList();
  }
}
