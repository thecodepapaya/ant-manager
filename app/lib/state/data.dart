/// Read models for the feature screens: drift `watch()` queries on the UI-side connection.
/// Writes never happen here (they go through engine commands).
library;

import 'dart:convert';

import 'package:core/core.dart' hide Provider;
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

// ---------------------------------------------------------------------------
// Evidence
// ---------------------------------------------------------------------------

/// One evidence item with its payloads (oldest first) and their sources.
class EvidenceItem {
  EvidenceItem(this.e, this.payloads, this.sources);
  final Evidence e;
  final List<Payload> payloads;
  final Map<String, SourceRow> sources;

  bool get isNoteOnly => payloads.isNotEmpty && payloads.every((p) => _noteKinds.contains(p.kind));

  /// The kind shown as the row icon.
  PayloadKind get kind => payloads.where((p) => !_noteKinds.contains(p.kind)).firstOrNull?.kind ??
      payloads.firstOrNull?.kind ??
      PayloadKind.note;

  /// Notes the user attached to this evidence (annotations, #56). A standalone note's own
  /// first payload is its body, not an annotation.
  List<Payload> get annotations {
    final notes = payloads.where((p) => _noteKinds.contains(p.kind)).toList();
    return isNoteOnly ? notes.skip(1).toList() : notes;
  }

  /// Body text of a standalone note.
  String? get noteText => isNoteOnly ? payloadText(payloads.first) : null;

  String? get link {
    for (final p in payloads) {
      final c = payloadContent(p);
      final l = c['link'] ?? c['url'];
      if (l is String && l.isNotEmpty) return l;
    }
    return null;
  }

  /// Blob-store paths of attached images.
  List<String> get attachments => [
        for (final p in payloads) ...((payloadContent(p)['attachments'] as List?) ?? const []).whereType<String>(),
      ];

  String get sourceName {
    final first = payloads.where((p) => !_noteKinds.contains(p.kind)).firstOrNull ?? payloads.firstOrNull;
    return first == null ? '' : (sources[first.sourceId]?.name ?? '');
  }
}

const _noteKinds = {PayloadKind.note, PayloadKind.image};

Map<String, Object?> payloadContent(Payload p) {
  try {
    final m = jsonDecode(p.content);
    if (m is Map<String, Object?>) return m;
  } on FormatException {
    // not JSON
  }
  return const {};
}

String payloadText(Payload p) => (payloadContent(p)['text'] as String?) ?? p.title ?? '';

/// Filters for [evidenceProvider]. Records give structural equality for family keys.
typedef EvidenceQuery = ({String? day, String? sourceId, String? projectId, int limit});

/// Evidence for a day (Today) or a page of the timeline, newest first for the timeline,
/// oldest first for a day.
final evidenceProvider = StreamProvider.family<List<EvidenceItem>, EvidenceQuery>((ref, q) async* {
  final h = await ref.watch(engineProvider.future);
  final db = h.db;
  final ids = db.selectOnly(db.evidences)..addColumns([db.evidences.id]);
  Expression<bool> cond = const Constant(true);
  if (q.day != null) cond = cond & db.evidences.day.equals(q.day!);
  if (q.projectId != null) cond = cond & db.evidences.projectId.equals(q.projectId!);
  if (q.sourceId != null) {
    cond = cond &
        db.evidences.id.isInQuery(db.selectOnly(db.payloads)
          ..addColumns([db.payloads.evidenceId])
          ..where(db.payloads.sourceId.equals(q.sourceId!)));
  }
  ids
    ..where(cond)
    ..orderBy([OrderingTerm(expression: db.evidences.occurredStart, mode: q.day == null ? OrderingMode.desc : OrderingMode.asc)])
    ..limit(q.limit);
  final query = db.select(db.evidences).join([
    leftOuterJoin(db.payloads, db.payloads.evidenceId.equalsExp(db.evidences.id)),
    leftOuterJoin(db.sources, db.sources.id.equalsExp(db.payloads.sourceId)),
  ])
    ..where(db.evidences.id.isInQuery(ids))
    ..orderBy([
      OrderingTerm(expression: db.evidences.occurredStart, mode: q.day == null ? OrderingMode.desc : OrderingMode.asc),
      OrderingTerm.asc(db.payloads.id),
    ]);
  yield* query.watch().map((rows) {
    final out = <String, EvidenceItem>{};
    for (final r in rows) {
      final e = r.readTable(db.evidences);
      final item = out.putIfAbsent(e.id, () => EvidenceItem(e, [], {}));
      final p = r.readTableOrNull(db.payloads);
      if (p != null && p.tombstonedAt == null) item.payloads.add(p);
      final s = r.readTableOrNull(db.sources);
      if (s != null) item.sources[s.id] = s;
    }
    return out.values.toList();
  });
});

final sourcesProvider = StreamProvider<List<SourceRow>>((ref) async* {
  final h = await ref.watch(engineProvider.future);
  yield* (h.db.select(h.db.sources)..orderBy([(s) => OrderingTerm.asc(s.name)])).watch();
});

/// Every project, archived included (Projects screen, colour lookups).
final allProjectsProvider = StreamProvider<List<Project>>((ref) async* {
  final h = await ref.watch(engineProvider.future);
  yield* (h.db.select(h.db.projects)..orderBy([(p) => OrderingTerm.asc(p.name)])).watch();
});

// ---------------------------------------------------------------------------
// Facts
// ---------------------------------------------------------------------------

/// A cited payload, resolved to its evidence (for citation chips).
class CitationRef {
  CitationRef({required this.payloadId, required this.evidenceId, required this.day, required this.title, required this.kind});
  final String payloadId, evidenceId, day, title;
  final PayloadKind kind;
}

class FactItem {
  FactItem(this.f, this.citations);
  final Fact f;
  final List<CitationRef> citations;
}

/// Facts overlapping [start]..[end] (inclusive days); null bounds = unbounded.
typedef FactQuery = ({
  String? start,
  String? end,
  FactType? type,
  String? projectId,
  String? workstreamId,
  bool reviewOnly,
  WinStatus? winStatus,
});

FactQuery factQuery({
  String? start,
  String? end,
  FactType? type,
  String? projectId,
  String? workstreamId,
  bool reviewOnly = false,
  WinStatus? winStatus,
}) =>
    (
      start: start,
      end: end,
      type: type,
      projectId: projectId,
      workstreamId: workstreamId,
      reviewOnly: reviewOnly,
      winStatus: winStatus,
    );

final factsProvider = StreamProvider.family<List<FactItem>, FactQuery>((ref, q) async* {
  final h = await ref.watch(engineProvider.future);
  final db = h.db;
  Expression<bool> cond = db.facts.retired.equals(false);
  if (q.end != null) cond = cond & db.facts.periodStart.isSmallerOrEqualValue(q.end!);
  if (q.start != null) cond = cond & db.facts.periodEnd.isBiggerOrEqualValue(q.start!);
  if (q.type != null) cond = cond & db.facts.type.equalsValue(q.type!);
  if (q.projectId != null) cond = cond & db.facts.projectId.equals(q.projectId!);
  if (q.workstreamId != null) cond = cond & db.facts.workstreamId.equals(q.workstreamId!);
  if (q.reviewOnly) cond = cond & db.facts.reviewState.equalsValue(ReviewState.needsReview);
  if (q.winStatus != null) {
    cond = cond & db.facts.winStatus.equalsValue(q.winStatus!) & db.facts.type.equalsValue(FactType.outcome);
  }
  final query = db.select(db.facts).join([
    leftOuterJoin(db.citations, db.citations.factId.equalsExp(db.facts.id)),
    leftOuterJoin(db.payloads, db.payloads.id.equalsExp(db.citations.payloadId)),
    leftOuterJoin(db.evidences, db.evidences.id.equalsExp(db.payloads.evidenceId)),
  ])
    ..where(cond)
    ..orderBy([
      OrderingTerm.desc(db.facts.periodStart),
      OrderingTerm.desc(db.facts.importance),
      OrderingTerm.asc(db.facts.id),
    ]);
  yield* query.watch().map((rows) {
    final out = <String, FactItem>{};
    for (final r in rows) {
      final f = r.readTable(db.facts);
      final item = out.putIfAbsent(f.id, () => FactItem(f, []));
      final p = r.readTableOrNull(db.payloads);
      final e = r.readTableOrNull(db.evidences);
      if (p != null && e != null) {
        item.citations.add(CitationRef(payloadId: p.id, evidenceId: e.id, day: e.day, title: p.title ?? e.title, kind: p.kind));
      }
    }
    return out.values.toList();
  });
});

/// Count of facts waiting in the review queue (sidebar badge).
final reviewCountProvider = StreamProvider<int>((ref) async* {
  final h = await ref.watch(engineProvider.future);
  yield* h.db
      .customSelect("SELECT COUNT(*) AS c FROM facts WHERE retired = 0 AND review_state = 'needsReview'",
          readsFrom: {h.db.facts})
      .watchSingle()
      .map((r) => r.read<int>('c'));
});

/// Count of model-suggested wins waiting for accept/reject (sidebar badge).
final suggestedWinsCountProvider = StreamProvider<int>((ref) async* {
  final h = await ref.watch(engineProvider.future);
  yield* h.db
      .customSelect(
          "SELECT COUNT(*) AS c FROM facts WHERE retired = 0 AND type = 'outcome' AND win_status = 'suggested'",
          readsFrom: {h.db.facts})
      .watchSingle()
      .map((r) => r.read<int>('c'));
});

/// Starred evidence in a period that no accepted win cites yet (e.g. the model call failed).
final starredWithoutWinProvider = StreamProvider.family<List<Evidence>, ({String? start, String? end})>((ref, q) async* {
  final h = await ref.watch(engineProvider.future);
  final db = h.db;
  yield* db
      .customSelect(
        '''SELECT e.* FROM evidences e WHERE e.starred = 1
           AND (?1 IS NULL OR e.day >= ?1) AND (?2 IS NULL OR e.day <= ?2)
           AND NOT EXISTS (SELECT 1 FROM payloads p JOIN citations c ON c.payload_id = p.id
             JOIN facts f ON f.id = c.fact_id
             WHERE p.evidence_id = e.id AND f.retired = 0 AND f.type = 'outcome' AND f.win_status = 'accepted')
           ORDER BY e.occurred_start DESC''',
        variables: [Variable(q.start), Variable(q.end)],
        readsFrom: {db.evidences, db.payloads, db.citations, db.facts},
      )
      .watch()
      .map((rows) => [for (final r in rows) db.evidences.map(r.data)]);
});

// ---------------------------------------------------------------------------
// Workstreams
// ---------------------------------------------------------------------------

class WorkstreamItem {
  WorkstreamItem(this.w, this.factCount);
  final Workstream w;
  final int factCount;
}

final workstreamsProvider = StreamProvider<List<WorkstreamItem>>((ref) async* {
  final h = await ref.watch(engineProvider.future);
  final db = h.db;
  yield* db
      .customSelect(
        '''SELECT w.*, (SELECT COUNT(*) FROM facts f WHERE f.workstream_id = w.id AND f.retired = 0) AS n
           FROM workstreams w ORDER BY COALESCE(w.span_end, '') DESC, w.title''',
        readsFrom: {db.workstreams, db.facts},
      )
      .watch()
      .map((rows) => [for (final r in rows) WorkstreamItem(db.workstreams.map(r.data), r.read<int>('n'))]);
});

// ---------------------------------------------------------------------------
// Reports
// ---------------------------------------------------------------------------

class ReportItem {
  ReportItem(this.r, this.template, this.snapshots);
  final Report r;
  final Template? template;

  /// Newest first.
  final List<ReportSnapshot> snapshots;

  ReportSnapshot? get latest => snapshots.firstOrNull;

  /// What the report shows: the locked snapshot when locked, else the latest.
  ReportSnapshot? get shown =>
      r.locked ? (snapshots.where((s) => s.id == r.lockedSnapshotId).firstOrNull ?? latest) : latest;

  Period get period => Period(r.periodKind, r.periodStart, r.periodEnd);
}

typedef ReportQuery = ({PeriodKind? kind, String? day});

/// Reports of a period kind (or the daily reports of one day), newest period first.
final reportsProvider = StreamProvider.family<List<ReportItem>, ReportQuery>((ref, q) async* {
  final h = await ref.watch(engineProvider.future);
  final db = h.db;
  Expression<bool> cond = const Constant(true);
  if (q.kind != null) cond = cond & db.reports.periodKind.equalsValue(q.kind!);
  if (q.day != null) cond = cond & db.reports.periodStart.equals(q.day!) & db.reports.periodEnd.equals(q.day!);
  final query = db.select(db.reports).join([
    leftOuterJoin(db.templates, db.templates.id.equalsExp(db.reports.templateId)),
    leftOuterJoin(db.reportSnapshots, db.reportSnapshots.reportId.equalsExp(db.reports.id)),
  ])
    ..where(cond)
    ..orderBy([
      OrderingTerm.desc(db.reports.periodStart),
      OrderingTerm.asc(db.reports.templateId),
      OrderingTerm.desc(db.reportSnapshots.version),
    ]);
  yield* query.watch().map((rows) {
    final out = <String, ReportItem>{};
    for (final row in rows) {
      final r = row.readTable(db.reports);
      final item = out.putIfAbsent(r.id, () => ReportItem(r, row.readTableOrNull(db.templates), []));
      final s = row.readTableOrNull(db.reportSnapshots);
      if (s != null) item.snapshots.add(s);
    }
    return out.values.toList();
  });
});

final templatesProvider = StreamProvider<List<Template>>((ref) async* {
  final h = await ref.watch(engineProvider.future);
  yield* (h.db.select(h.db.templates)..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();
});

/// True when facts behind a snapshot changed since it was generated (StalenessService).
final snapshotStaleProvider = StreamProvider.family<bool, String>((ref, snapshotId) async* {
  final h = await ref.watch(engineProvider.future);
  yield* StalenessService(h.db).watch((type: EntityType.reportSnapshot, id: snapshotId));
});

/// Facts by id (report footnotes).
final factByIdProvider = StreamProvider.family<FactItem?, String>((ref, id) async* {
  final h = await ref.watch(engineProvider.future);
  final db = h.db;
  final query = db.select(db.facts).join([
    leftOuterJoin(db.citations, db.citations.factId.equalsExp(db.facts.id)),
    leftOuterJoin(db.payloads, db.payloads.id.equalsExp(db.citations.payloadId)),
    leftOuterJoin(db.evidences, db.evidences.id.equalsExp(db.payloads.evidenceId)),
  ])..where(db.facts.id.equals(id));
  yield* query.watch().map((rows) {
    FactItem? item;
    for (final r in rows) {
      item ??= FactItem(r.readTable(db.facts), []);
      final p = r.readTableOrNull(db.payloads);
      final e = r.readTableOrNull(db.evidences);
      if (p != null && e != null) {
        item.citations.add(CitationRef(payloadId: p.id, evidenceId: e.id, day: e.day, title: p.title ?? e.title, kind: p.kind));
      }
    }
    return item;
  });
});

// ---------------------------------------------------------------------------
// Projects
// ---------------------------------------------------------------------------

class ProjectStats {
  ProjectStats(this.p, this.evidence, this.facts, this.wins);
  final Project p;
  final int evidence, facts, wins;
}

final projectStatsProvider = StreamProvider<List<ProjectStats>>((ref) async* {
  final h = await ref.watch(engineProvider.future);
  final db = h.db;
  yield* db
      .customSelect(
        '''SELECT p.*,
             (SELECT COUNT(*) FROM evidences e WHERE e.project_id = p.id) AS ev,
             (SELECT COUNT(*) FROM facts f WHERE f.project_id = p.id AND f.retired = 0) AS fa,
             (SELECT COUNT(*) FROM facts f WHERE f.project_id = p.id AND f.retired = 0
                AND f.win_status = 'accepted') AS wi
           FROM projects p ORDER BY p.archived, p.name''',
        readsFrom: {db.projects, db.evidences, db.facts},
      )
      .watch()
      .map((rows) => [
            for (final r in rows)
              ProjectStats(db.projects.map(r.data), r.read<int>('ev'), r.read<int>('fa'), r.read<int>('wi')),
          ]);
});

// ---------------------------------------------------------------------------
// Shell status
// ---------------------------------------------------------------------------

/// Last successful sync across sources (sidebar footer).
final lastSyncProvider = StreamProvider<DateTime?>((ref) async* {
  final h = await ref.watch(engineProvider.future);
  final db = h.db;
  yield* db
      .customSelect('SELECT MAX(last_success_at) AS t FROM sync_cursors', readsFrom: {db.syncCursors})
      .watchSingle()
      .map((r) {
    final t = r.read<int?>('t');
    return t == null ? null : DateTime.fromMillisecondsSinceEpoch(t * 1000);
  });
});
