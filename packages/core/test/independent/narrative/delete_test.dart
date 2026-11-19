import 'package:core/core.dart';
import 'package:core/src/narrative/enrichment.dart';
import 'package:core/src/staleness/staleness.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:test/test.dart';

import 'harness.dart';

void main() {
  late H h;
  late String gone, p, pNote, keep, q, path1, path2;

  setUp(() async {
    h = H();
    await h.setUp();
    path1 = await h.blobs.put(Uint8List.fromList([1, 2, 3]), extension: 'png');
    path2 = await h.blobs.put(Uint8List.fromList([4, 5, 6]), extension: 'png');
    // Evidence to delete: a commit "zebracommit" plus a screenshot attached to it.
    gone = await h.commit('a1', at(10), msg: 'zebracommit');
    p = await h.pid(gone);
    await h.note('img', at(10), 'zebranote', kind: PayloadKind.image, attachments: [path1]);
    final img = await h.payloadByExt(H.notes, 'img');
    await (h.db.update(
      h.db.payloads,
    )..where((x) => x.id.equals(img.id))).write(PayloadsCompanion(evidenceId: Value(gone)));
    pNote = img.id;
    await h.db
        .into(h.db.attachments)
        .insert(
          AttachmentsCompanion.insert(
            id: 'att',
            payloadId: pNote,
            path: path2,
            mime: 'image/png',
            sha256: 'x',
            size: 3,
          ),
        );
    keep = await h.pr('pr1', at(11));
    q = await h.pid(keep);
    final reg = EnrichmentRegistry();
    for (final s in defaultEnrichmentStrategies(h.ctx)) {
      reg.register(s);
    }
    await Enricher(h.ctx, reg).enrichDay(day);

    await h.insertFact('only', [p], statement: 'zebrafact only');
    await h.insertFact('protOnly', [p], origin: FactOrigin.confirmed);
    await h.insertFact('shared', [p, q]);
    await h.insertFact('prot', [p, q], origin: FactOrigin.userEdited);
    await h.insertFact('win', [pNote, q], win: WinStatus.accepted);
    for (final f in ['only', 'protOnly', 'shared', 'prot', 'win']) {
      final cites = await h.citations(f);
      await h.ctx.deps.record(
        (type: EntityType.fact, id: f),
        1,
        [for (final c in cites) (type: EntityType.payload, id: c.payloadId, revision: c.payloadRevision)],
      );
    }
    await DependencyRecorder(h.db)
        .record((type: EntityType.report, id: 'r1'), 1, [(type: EntityType.fact, id: 'only', revision: 1)]);
    await h.clearQueue();
  });
  tearDown(() => h.close());

  Future<int> count(String sql) async => (await h.db.customSelect(sql).get()).length;

  test('purges payloads, revisions, attachments, enrichments, citations and FTS rows', () async {
    final enrIds = [(await h.enrichmentOf(p))!.id, (await h.enrichmentOf(pNote))!.id];
    expect(await count("SELECT 1 FROM fts_payloads WHERE fts_payloads MATCH 'zebracommit'"), 1);
    await EvidenceDeleter(h.ctx).permanentDelete(gone);
    expect(await (h.db.select(h.db.evidences)..where((e) => e.id.equals(gone))).get(), isEmpty);
    expect(await (h.db.select(h.db.payloads)..where((x) => x.id.isIn([p, pNote]))).get(), isEmpty);
    expect(await (h.db.select(h.db.payloadRevisions)..where((x) => x.payloadId.isIn([p, pNote]))).get(), isEmpty);
    expect(await h.db.select(h.db.attachments).get(), isEmpty);
    expect(await (h.db.select(h.db.enrichments)..where((n) => n.id.isIn(enrIds))).get(), isEmpty);
    expect(await (h.db.select(h.db.citations)..where((c) => c.payloadId.isIn([p, pNote]))).get(), isEmpty);
    expect(await count("SELECT 1 FROM fts_payloads WHERE fts_payloads MATCH 'zebracommit'"), 0);
    expect(await count("SELECT 1 FROM fts_payloads WHERE fts_payloads MATCH 'zebranote'"), 0);
    expect(
      await (h.db.select(
        h.db.dependencies,
      )..where((d) => d.inputId.isIn([p, pNote, ...enrIds]) | d.dependentId.isIn(enrIds))).get(),
      isEmpty,
    );
    // Kept evidence is untouched.
    expect(await h.enrichmentOf(q), isNotNull);
  });

  test('uncited facts are deleted with history, deps and FTS rows; dependent reports re-queued', () async {
    expect(await count("SELECT 1 FROM fts_facts WHERE fts_facts MATCH 'zebrafact'"), 1);
    await EvidenceDeleter(h.ctx).permanentDelete(gone);
    final ids = (await h.facts()).map((f) => f.id).toSet();
    expect(ids, {'shared', 'prot', 'win'});
    expect(await (h.db.select(h.db.factRevisions)..where((r) => r.factId.isIn(['only', 'protOnly']))).get(), isEmpty);
    expect(await h.depsOf(EntityType.fact, 'only'), isEmpty);
    expect(await count("SELECT 1 FROM fts_facts WHERE fts_facts MATCH 'zebrafact'"), 0);
    final queue = (await h.db.select(h.db.recomputeQueue).get()).map((r) => (r.entityType, r.entityId)).toSet();
    expect(queue, contains((EntityType.report, 'r1')));
  });

  test('facts that keep citations: model-owned keep the rest, protected → needsReview; day re-queued', () async {
    await EvidenceDeleter(h.ctx).permanentDelete(gone);
    final shared = await h.fact('shared');
    expect(shared.reviewState, ReviewState.ok);
    expect((await h.citations('shared')).map((c) => c.payloadId), [q]);
    final prot = await h.fact('prot');
    expect((prot.reviewState, prot.statement, prot.retired), (ReviewState.needsReview, 'Did a thing.', false));
    expect(prot.reviewProposal, isNotNull);
    expect((await h.fact('win')).reviewState, ReviewState.needsReview, reason: 'accepted win is protected');
    final queue = (await h.db.select(h.db.recomputeQueue).get()).map((r) => (r.entityType, r.entityId)).toSet();
    expect(queue, contains((EntityType.day, day)));
  });

  test('returns the attachment paths (content refs and attachment rows) without deleting blobs itself', () async {
    final paths = await EvidenceDeleter(h.ctx).permanentDelete(gone);
    expect(paths.toSet(), {path1, path2});
    expect(h.blobs.deleted, isEmpty, reason: 'files go after commit, by the caller');
  });

  test('deleting unknown evidence is a no-op', () async {
    expect(await EvidenceDeleter(h.ctx).permanentDelete('nope'), isEmpty);
    expect(await h.facts(), hasLength(5));
  });

  test('no dangling foreign keys after delete', () async {
    await EvidenceDeleter(h.ctx).permanentDelete(gone);
    expect(await count('PRAGMA foreign_key_check'), 0);
  });
}
