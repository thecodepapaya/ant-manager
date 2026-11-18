import 'package:core/core.dart';
import 'package:core/src/capture/ingestor.dart';
import 'package:core/src/staleness/staleness.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:test/test.dart';

PayloadObservation obs(String id, Map<String, Object?> content, {String? group, bool tomb = false}) =>
    PayloadObservation(
      externalId: id,
      kind: PayloadKind.commit,
      content: content,
      occurredStart: DateTime.utc(2026, 11, 17, 10),
      title: 'commit $id',
      groupKey: group,
      tombstone: tomb,
    );

void main() {
  late ProfileDb db;
  late Ingestor ingestor;

  setUp(() async {
    db = ProfileDb(NativeDatabase.memory());
    ingestor = Ingestor(db, utcOffset: () => Duration.zero);
    await db.into(db.sources).insert(SourcesCompanion.insert(id: 's1', kind: SourceKind.gitRepo, name: 'repo'));
    await db.into(db.sources).insert(SourcesCompanion.insert(id: 's2', kind: SourceKind.github, name: 'gh'));
  });
  tearDown(() => db.close());

  Future<int> queued() async => (await db.select(db.recomputeQueue).get()).length;

  test('identical re-sync writes nothing (invariant 2)', () async {
    await ingestor.ingest('s1', [obs('a', {'msg': 'x'})]);
    await db.delete(db.recomputeQueue).go();
    final r = await ingestor.ingest('s1', [obs('a', {'msg': 'x'})]);
    expect(r.unchanged, 1);
    expect(await queued(), 0);
  });

  test('content change bumps revision, appends history, enqueues the day', () async {
    await ingestor.ingest('s1', [obs('a', {'msg': 'x'})]);
    await db.delete(db.recomputeQueue).go();
    await ingestor.ingest('s1', [obs('a', {'msg': 'y'})]);
    final p = await db.select(db.payloads).getSingle();
    expect(p.revision, 2);
    expect((await db.select(db.payloadRevisions).get()).length, 2);
    final q = await db.select(db.recomputeQueue).get();
    expect(q.map((e) => (e.entityType, e.entityId)), contains((EntityType.day, '2026-11-17')));
  });

  test('same group key from another source joins the same evidence', () async {
    await ingestor.ingest('s1', [obs('sha1', {'m': 1}, group: 'sha1')]);
    await ingestor.ingest('s2', [obs('pr-commit-sha1', {'m': 2}, group: 'sha1')]);
    expect((await db.select(db.evidences).get()).length, 1);
    expect((await db.select(db.payloads).get()).length, 2);
  });

  test('tombstone keeps history and bumps revision', () async {
    await ingestor.ingest('s1', [obs('a', {'m': 1})]);
    await ingestor.ingest('s1', [obs('a', {'m': 1}, tomb: true)]);
    final p = await db.select(db.payloads).getSingle();
    expect(p.tombstonedAt, isNotNull);
    expect(p.revision, 2);
  });

  test('staleness is computed from recorded input revisions', () async {
    await ingestor.ingest('s1', [obs('a', {'m': 1})]);
    final p = await db.select(db.payloads).getSingle();
    final rec = DependencyRecorder(db);
    await rec.record((type: EntityType.enrichment, id: 'n1'), 1, [(type: EntityType.payload, id: p.id, revision: 1)]);
    final s = StalenessService(db);
    expect(await s.isStale((type: EntityType.enrichment, id: 'n1')), isFalse);
    await db.delete(db.recomputeQueue).go();
    await ingestor.ingest('s1', [obs('a', {'m': 2})]);
    expect(await s.isStale((type: EntityType.enrichment, id: 'n1')), isTrue);
    final q = await db.select(db.recomputeQueue).get();
    expect(q.any((e) => e.entityType == EntityType.enrichment && e.entityId == 'n1'), isTrue);
  });

  test('FTS indexes payload content', () async {
    await ingestor.ingest('s1', [obs('a', {'msg': 'idempotency keys for payment intents'})]);
    final rows = await db.customSelect("SELECT payload_id FROM fts_payloads WHERE fts_payloads MATCH 'idempotency'").get();
    expect(rows, hasLength(1));
  });

  test('recompute worker drains de-duplicated entries', () async {
    await ingestor.ingest('s1', [obs('a', {'m': 1}), obs('b', {'m': 2})]);
    final w = RecomputeWorker(db);
    final seen = <String>[];
    w.on(EntityType.day, (id) async => seen.add(id));
    await w.drain();
    expect(seen, ['2026-11-17']);
    expect(await queued(), 0);
  });

  test('job queue retries with backoff then fails', () async {
    final q = JobQueue(db);
    var calls = 0;
    q.register('boom', JobLane.io, (_) async {
      calls++;
      throw StateError('x');
    });
    await q.enqueue('boom');
    expect(await q.runOne(JobLane.io), isTrue);
    final j = await db.select(db.jobs).getSingle();
    expect(j.state, JobState.queued);
    expect(j.runAfter.isAfter(DateTime.now()), isTrue);
    expect(calls, 1);
    await (db.update(db.jobs)).write(JobsCompanion(attempts: const Value(3), runAfter: Value(DateTime.now())));
    await q.runOne(JobLane.io);
    expect((await db.select(db.jobs).getSingle()).state, JobState.failed);
  });
}
