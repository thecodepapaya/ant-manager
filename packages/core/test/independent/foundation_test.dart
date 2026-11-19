// Independent tests (#99) for capture, staleness, jobs, engine commands, triggers and FTS.
// Derived from LLD 02 key invariants and LLD 04 §4.1, §4.2, §4.11.
import 'dart:convert';

import 'package:core/core.dart';
import 'package:core/src/capture/ingestor.dart';
import 'package:core/src/staleness/staleness.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:test/test.dart';

import 'fakes.dart';

PayloadObservation obs(
  String id,
  Map<String, Object?> content, {
  DateTime? at,
  String title = 'Event',
  String? group,
  bool tombstone = false,
  PayloadKind kind = PayloadKind.calendarEvent,
}) => PayloadObservation(
  externalId: id,
  kind: kind,
  content: content,
  occurredStart: at ?? DateTime.utc(2026, 11, 18, 10),
  title: title,
  groupKey: group,
  tombstone: tombstone,
);

void main() {
  late ProfileDb db;
  late Seed seed;
  late String src;
  late Ingestor ing;

  setUp(() async {
    db = memDb();
    seed = Seed(db);
    src = await seed.source();
    ing = Ingestor(db, utcOffset: (_) => Duration.zero);
  });
  tearDown(() => db.close());

  Future<Payload> payloadOf(String ext) => (db.select(db.payloads)..where((p) => p.externalId.equals(ext))).getSingle();
  Future<List<PayloadRevision>> revisionsOf(String payloadId) =>
      (db.select(db.payloadRevisions)
            ..where((r) => r.payloadId.equals(payloadId))
            ..orderBy([(r) => OrderingTerm.asc(r.revision)]))
          .get();
  Future<Evidence> evidenceById(String id) => (db.select(db.evidences)..where((e) => e.id.equals(id))).getSingle();

  group('ingestor (LLD 04 §4.1)', () {
    test('new observation creates evidence, payload rev 1 and one revision row', () async {
      final r = await ing.ingest(src, [
        obs('a', {'t': 1}),
      ]);
      expect(r.created, 1);
      final p = await payloadOf('a');
      expect(p.revision, 1);
      expect((await revisionsOf(p.id)).map((r) => r.revision), [1]);
      expect((await evidenceById(p.evidenceId)).title, 'Event');
    });

    test('evidence day uses the profile offset at the observation instant', () async {
      final tz = Ingestor(db, utcOffset: (_) => const Duration(hours: 2));
      await tz.ingest(src, [
        obs('late', {'t': 1}, at: DateTime.utc(2026, 11, 18, 23, 30)),
      ]);
      final p = await payloadOf('late');
      expect((await evidenceById(p.evidenceId)).day, '2026-11-19');
      final west = Ingestor(db, utcOffset: (_) => const Duration(hours: -8));
      await west.ingest(src, [
        obs('early', {'t': 1}, at: DateTime.utc(2026, 11, 18, 3)),
      ]);
      expect((await evidenceById((await payloadOf('early')).evidenceId)).day, '2026-11-17');
    });

    test('invariant 2: identical re-sync (any key order) writes nothing and queues nothing', () async {
      await ing.ingest(src, [
        obs('a', {
          'b': 2,
          'a': {
            'y': 1,
            'x': [3, 2],
          },
        }),
      ]);
      final before = await seed.queueCount();
      final r = await ing.ingest(src, [
        obs('a', {
          'a': {
            'x': [3, 2],
            'y': 1,
          },
          'b': 2,
        }),
      ]);
      expect(r.unchanged, 1);
      expect(r.updated, 0);
      final p = await payloadOf('a');
      expect(p.revision, 1);
      expect(await revisionsOf(p.id), hasLength(1));
      expect(await seed.queueCount(), before);
    });

    test('a list order change is a real change', () async {
      await ing.ingest(src, [
        obs('a', {
          'x': [1, 2],
        }),
      ]);
      final r = await ing.ingest(src, [
        obs('a', {
          'x': [2, 1],
        }),
      ]);
      expect(r.updated, 1);
    });

    test('content change bumps revision and appends history (append-only)', () async {
      await ing.ingest(src, [
        obs('a', {'t': 'v1'}),
      ]);
      await ing.ingest(src, [
        obs('a', {'t': 'v2'}),
      ]);
      await ing.ingest(src, [
        obs('a', {'t': 'v3'}),
      ]);
      final p = await payloadOf('a');
      expect(p.revision, 3);
      final revs = await revisionsOf(p.id);
      expect(revs.map((r) => r.revision), [1, 2, 3]);
      expect(revs.map((r) => (jsonDecode(r.content) as Map)['t']), ['v1', 'v2', 'v3']);
      expect(revs.last.contentHash, p.contentHash);
    });

    test('invariant 3: tombstone keeps evidence and history; repeat tombstone is a no-op', () async {
      await ing.ingest(src, [
        obs('a', {'t': 1}),
      ]);
      final r1 = await ing.ingest(src, [
        obs('a', {'t': 1}, tombstone: true),
      ]);
      expect(r1.tombstoned, 1);
      final p = await payloadOf('a');
      expect(p.tombstonedAt, isNotNull);
      expect(p.revision, 2);
      expect(await db.select(db.evidences).get(), hasLength(1));
      final r2 = await ing.ingest(src, [
        obs('a', {'t': 1}, tombstone: true),
      ]);
      expect(r2.tombstoned, 0);
      expect((await payloadOf('a')).revision, 2);
      expect(await revisionsOf(p.id), hasLength(2));
    });

    test('tombstone for an unknown payload creates nothing', () async {
      await ing.ingest(src, [
        obs('ghost', {'t': 1}, tombstone: true),
      ]);
      expect(await db.select(db.payloads).get(), isEmpty);
      expect(await db.select(db.evidences).get(), isEmpty);
    });

    test('a tombstoned payload that reappears upstream is revived as a new revision', () async {
      await ing.ingest(src, [
        obs('a', {'t': 1}),
      ]);
      await ing.ingest(src, [
        obs('a', {'t': 1}, tombstone: true),
      ]);
      final r = await ing.ingest(src, [
        obs('a', {'t': 1}),
      ]);
      expect(r.updated, 1);
      final p = await payloadOf('a');
      expect(p.tombstonedAt, isNull);
      expect(p.revision, 3);
    });

    test('group key joins payloads across sources into one evidence; tombstoned peers do not', () async {
      final src2 = await seed.source(SourceKind.ics);
      await ing.ingest(src, [
        obs('g1', {'s': 'google'}, group: 'uid@x'),
      ]);
      await ing.ingest(src2, [
        obs('i1', {'s': 'ics'}, group: 'uid@x'),
      ]);
      expect((await payloadOf('g1')).evidenceId, (await payloadOf('i1')).evidenceId);
      // Same group key, but the only peer is tombstoned → new evidence.
      await ing.ingest(src, [
        obs('g2', {'s': 1}, group: 'uid@y'),
      ]);
      await ing.ingest(src, [
        obs('g2', {'s': 1}, group: 'uid@y', tombstone: true),
      ]);
      await ing.ingest(src2, [
        obs('i2', {'s': 2}, group: 'uid@y'),
      ]);
      expect((await payloadOf('i2')).evidenceId, isNot((await payloadOf('g2')).evidenceId));
    });

    test('no group key never auto-groups', () async {
      await ing.ingest(src, [
        obs('a', {'t': 1}),
        obs('b', {'t': 1}),
      ]);
      expect(await db.select(db.evidences).get(), hasLength(2));
    });

    test('invariant 1: a sync never touches another payload on the same evidence (user note)', () async {
      final engine = _engine(db);
      await ing.ingest(src, [
        obs('meet', {'t': 'v1'}),
      ]);
      final evidenceId = (await payloadOf('meet')).evidenceId;
      await engine.addNote(text: 'my note', at: DateTime.utc(2026, 11, 18, 10), attachTo: evidenceId);
      final note = (await db.select(db.payloads).get()).firstWhere((p) => p.kind == PayloadKind.note);
      await ing.ingest(src, [
        obs('meet', {'t': 'v2'}),
      ]);
      await ing.ingest(src, [
        obs('meet', {'t': 'v2'}, tombstone: true),
      ]);
      final after = await (db.select(db.payloads)..where((p) => p.id.equals(note.id))).getSingle();
      expect(after.revision, note.revision);
      expect(after.content, note.content);
      expect(after.tombstonedAt, isNull);
      // Evidence survives while it has a live payload, and its title moves to that payload.
      expect((await evidenceById(evidenceId)).title, 'my note');
    });

    test('a batch is one transaction: a failing observation rolls back the whole batch', () async {
      await expectLater(
        ing.ingest('no-such-source', [
          obs('a', {'t': 1}),
        ]),
        throwsA(anything),
      );
      expect(await db.select(db.evidences).get(), isEmpty);
      expect(await db.select(db.payloads).get(), isEmpty);
      expect(await db.select(db.recomputeQueue).get(), isEmpty);
    });

    test(
      'evidence time and day follow its first payload when that payload is rescheduled',
      () async {
        await ing.ingest(src, [
          obs('m', {'start': '18'}, at: DateTime.utc(2026, 11, 18, 10)),
        ]);
        await ing.ingest(src, [
          obs('m', {'start': '20'}, at: DateTime.utc(2026, 11, 20, 10)),
        ]);
        final e = await evidenceById((await payloadOf('m')).evidenceId);
        expect(e.day, '2026-11-20');
        expect(e.occurredStart.toUtc(), DateTime.utc(2026, 11, 20, 10));
      },
    );
  });

  group('triggers and staleness (LLD 04 §4.2, invariant 5)', () {
    late DependencyRecorder deps;
    late StalenessService stale;
    setUp(() {
      deps = DependencyRecorder(db);
      stale = StalenessService(db);
    });

    Future<String> enrichment(String payloadId) async {
      final id = 'n-$payloadId';
      await db
          .into(db.enrichments)
          .insert(
            EnrichmentsCompanion.insert(
              id: id,
              targetType: EntityType.payload,
              targetId: payloadId,
              kind: 'summary',
              output: 'sum',
              modelId: 'm',
              createdAt: seed.now,
            ),
          );
      return id;
    }

    Future<void> bumpEnrichment(String id) =>
        db.customStatement('UPDATE enrichments SET revision = revision + 1 WHERE id = ?', [id]);
    Future<void> bumpFact(String id) =>
        db.customStatement('UPDATE facts SET revision = revision + 1 WHERE id = ?', [id]);

    test('recording rejects unrevisioned inputs', () async {
      expect(
        () => deps.record((type: EntityType.fact, id: 'f'), 1, [(type: EntityType.day, id: '2026-11-18', revision: 1)]),
        throwsArgumentError,
      );
    });

    test('new payload queues its day', () async {
      await ing.ingest(src, [
        obs('a', {'t': 1}),
      ]);
      expect(await seed.queueCount(EntityType.day, '2026-11-18'), greaterThanOrEqualTo(1));
    });

    test('chain: payload → enrichment → fact → report snapshot, each stale and queued as its input moves', () async {
      await ing.ingest(src, [
        obs('a', {'t': 1}),
      ]);
      final p = await payloadOf('a');
      final n = await enrichment(p.id);
      final f = await seed.fact('Shipped', '2026-11-18', cites: [p.id]);
      await deps.record((type: EntityType.enrichment, id: n), 1, [(type: EntityType.payload, id: p.id, revision: 1)]);
      await deps.record(
        (type: EntityType.fact, id: f),
        1,
        [(type: EntityType.payload, id: p.id, revision: 1), (type: EntityType.enrichment, id: n, revision: 1)],
      );
      await deps.record((type: EntityType.reportSnapshot, id: 's1'), 1, [(type: EntityType.fact, id: f, revision: 1)]);
      await db.delete(db.recomputeQueue).go();
      for (final ref in [
        (type: EntityType.enrichment, id: n),
        (type: EntityType.fact, id: f),
        (type: EntityType.reportSnapshot, id: 's1'),
      ]) {
        expect(await stale.isStale(ref), isFalse, reason: '$ref fresh');
      }

      await ing.ingest(src, [
        obs('a', {'t': 2}),
      ]);
      expect(await stale.isStale((type: EntityType.enrichment, id: n)), isTrue);
      expect(await stale.isStale((type: EntityType.fact, id: f)), isTrue);
      expect(await seed.queueCount(EntityType.enrichment, n), 1);
      expect(await seed.queueCount(EntityType.fact, f), 1);
      expect(await seed.queueCount(EntityType.day, '2026-11-18'), 1);

      // Enrichment recomputes → its fact dependents get queued.
      await db.delete(db.recomputeQueue).go();
      await bumpEnrichment(n);
      await deps.record((type: EntityType.enrichment, id: n), 2, [(type: EntityType.payload, id: p.id, revision: 2)]);
      expect(await stale.isStale((type: EntityType.enrichment, id: n)), isFalse);
      expect(await seed.queueCount(EntityType.fact, f), 1);

      // Fact recomputes → snapshot stale + queued.
      await bumpFact(f);
      await deps.record(
        (type: EntityType.fact, id: f),
        2,
        [(type: EntityType.payload, id: p.id, revision: 2), (type: EntityType.enrichment, id: n, revision: 2)],
      );
      expect(await stale.isStale((type: EntityType.fact, id: f)), isFalse);
      expect(await stale.isStale((type: EntityType.reportSnapshot, id: 's1')), isTrue);
      expect(await seed.queueCount(EntityType.reportSnapshot, 's1'), 1);
    });

    test(
      'staleness is transitive: a fact built only from an enrichment is stale once the payload moves',
      () async {
        await ing.ingest(src, [
          obs('a', {'t': 1}),
        ]);
        final p = await payloadOf('a');
        final n = await enrichment(p.id);
        final f = await seed.fact('X', '2026-11-18', cites: [p.id]);
        await deps.record((type: EntityType.enrichment, id: n), 1, [(type: EntityType.payload, id: p.id, revision: 1)]);
        await deps.record((type: EntityType.fact, id: f), 1, [(type: EntityType.enrichment, id: n, revision: 1)]);
        await deps.record((type: EntityType.reportSnapshot, id: 's'), 1, [(type: EntityType.fact, id: f, revision: 1)]);
        await ing.ingest(src, [
          obs('a', {'t': 2}),
        ]);
        expect(await stale.isStale((type: EntityType.fact, id: f)), isTrue);
        expect(await stale.isStale((type: EntityType.reportSnapshot, id: 's')), isTrue);
      },
    );

    test('re-recording at current revisions clears staleness', () async {
      await ing.ingest(src, [
        obs('a', {'t': 1}),
      ]);
      final p = await payloadOf('a');
      await deps.record((type: EntityType.fact, id: 'f'), 1, [(type: EntityType.payload, id: p.id, revision: 1)]);
      await ing.ingest(src, [
        obs('a', {'t': 2}),
      ]);
      expect(await stale.isStale((type: EntityType.fact, id: 'f')), isTrue);
      await deps.record((type: EntityType.fact, id: 'f'), 2, [(type: EntityType.payload, id: p.id, revision: 2)]);
      expect(await stale.isStale((type: EntityType.fact, id: 'f')), isFalse);
    });

    test('an entity with no dependencies is not stale', () async {
      expect(await stale.isStale((type: EntityType.reportSnapshot, id: 'nothing')), isFalse);
    });

    test('watch emits true when an input changes', () async {
      await ing.ingest(src, [
        obs('a', {'t': 1}),
      ]);
      final p = await payloadOf('a');
      await deps.record((type: EntityType.fact, id: 'f'), 1, [(type: EntityType.payload, id: p.id, revision: 1)]);
      final values = stale.watch((type: EntityType.fact, id: 'f')).take(2).toList();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await ing.ingest(src, [
        obs('a', {'t': 2}),
      ]);
      expect(await values.timeout(const Duration(seconds: 5)), [false, true]);
    });

    test('queue rows are written atomically: a rolled-back change leaves no queue entry', () async {
      await ing.ingest(src, [
        obs('a', {'t': 1}),
      ]);
      final p = await payloadOf('a');
      await deps.record((type: EntityType.fact, id: 'f'), 1, [(type: EntityType.payload, id: p.id, revision: 1)]);
      await db.delete(db.recomputeQueue).go();
      await expectLater(
        db.transaction(() async {
          await db.customStatement('UPDATE payloads SET revision = 9 WHERE id = ?', [p.id]);
          throw StateError('crash');
        }),
        throwsStateError,
      );
      expect(await db.select(db.recomputeQueue).get(), isEmpty);
      expect((await payloadOf('a')).revision, 1);
    });

    test('curation queues the day only on a real change', () async {
      final e = await seed.evidence(src, '2026-11-10', {'t': 1});
      await db.delete(db.recomputeQueue).go();
      await db.customStatement('UPDATE evidences SET starred = starred WHERE id = ?', [e.evidence]);
      expect(await seed.queueCount(), 0);
      await db.customStatement('UPDATE evidences SET starred = 1 WHERE id = ?', [e.evidence]);
      expect(await seed.queueCount(EntityType.day, '2026-11-10'), 1);
    });

    test('moving a payload between evidence queues both days', () async {
      final a = await seed.evidence(src, '2026-11-10', {'t': 1});
      final b = await seed.evidence(src, '2026-11-12', {'t': 2});
      await db.delete(db.recomputeQueue).go();
      await db.customStatement('UPDATE payloads SET evidence_id = ? WHERE id = ?', [b.evidence, a.payload]);
      expect(await seed.queueCount(EntityType.day, '2026-11-10'), 1);
      expect(await seed.queueCount(EntityType.day, '2026-11-12'), 1);
    });
  });

  group('recompute worker', () {
    test('de-duplicates by entity and drains oldest first', () async {
      final w = RecomputeWorker(db);
      final seen = <String>[];
      w.on(EntityType.day, (id) async => seen.add(id));
      for (final d in ['2026-11-02', '2026-11-01', '2026-11-02', '2026-11-02']) {
        await db
            .into(db.recomputeQueue)
            .insert(
              RecomputeQueueCompanion.insert(
                entityType: EntityType.day,
                entityId: d,
                reason: 't',
                enqueuedAt: seed.now,
              ),
            );
      }
      expect(await w.drain(), 2);
      expect(seen, ['2026-11-02', '2026-11-01']);
      expect(await db.select(db.recomputeQueue).get(), isEmpty);
    });

    test('a failing handler leaves its work queued (crash-safe)', () async {
      final w = RecomputeWorker(db)..on(EntityType.day, (_) async => throw StateError('boom'));
      await db
          .into(db.recomputeQueue)
          .insert(
            RecomputeQueueCompanion.insert(
              entityType: EntityType.day,
              entityId: 'd',
              reason: 't',
              enqueuedAt: seed.now,
            ),
          );
      await expectLater(w.drain(), throwsStateError);
      expect(await db.select(db.recomputeQueue).get(), hasLength(1));
    });

    test('entries without a handler stay queued', () async {
      final w = RecomputeWorker(db)..on(EntityType.day, (_) async {});
      await db
          .into(db.recomputeQueue)
          .insert(
            RecomputeQueueCompanion.insert(
              entityType: EntityType.reportSnapshot,
              entityId: 's',
              reason: 't',
              enqueuedAt: seed.now,
            ),
          );
      expect(await w.drain(), 0);
      expect(await db.select(db.recomputeQueue).get(), hasLength(1));
    });
  });

  group('job queue (LLD 04 §4.11)', () {
    late MutableClock clock;
    late JobQueue q;
    setUp(() {
      clock = MutableClock(DateTime.utc(2026, 11, 18, 12));
      q = JobQueue(db, clock: clock);
    });
    Future<Job> job(String id) => (db.select(db.jobs)..where((j) => j.id.equals(id))).getSingle();

    test('lanes are independent', () async {
      var io = 0, llm = 0;
      q
        ..register('sync', JobLane.io, (_) async => io++)
        ..register('extract', JobLane.llm, (_) async => llm++);
      await q.enqueue('extract');
      expect(await q.runOne(JobLane.io), isFalse);
      expect(await q.runOne(JobLane.llm), isTrue);
      expect((io, llm), (0, 1));
    });

    test('jobs pass args and run only when due', () async {
      Map<String, Object?>? got;
      q.register('k', JobLane.io, (a) async => got = a);
      final id = await q.enqueue('k', args: {'x': 1}, runAfter: clock.now().add(const Duration(minutes: 5)));
      expect(await q.runOne(JobLane.io), isFalse);
      clock.advance(const Duration(minutes: 5));
      expect(await q.runOne(JobLane.io), isTrue);
      expect(got, {'x': 1});
      expect((await job(id)).state, JobState.done);
    });

    test('backoff 1 min, 5 min, 30 min, then failed with the last error', () async {
      q.register('bad', JobLane.io, (_) async => throw StateError('nope'));
      final id = await q.enqueue('bad');
      for (final wait in const [Duration(minutes: 1), Duration(minutes: 5), Duration(minutes: 30)]) {
        expect(await q.runOne(JobLane.io), isTrue);
        final j = await job(id);
        expect(j.state, JobState.queued);
        expect(j.runAfter.toUtc(), clock.now().add(wait));
        expect(await q.runOne(JobLane.io), isFalse, reason: 'not due before backoff');
        clock.t = j.runAfter.toUtc();
      }
      expect(await q.runOne(JobLane.io), isTrue);
      final j = await job(id);
      expect(j.state, JobState.failed);
      expect(j.attempts, 4);
      expect(j.lastError, contains('nope'));
      clock.advance(const Duration(days: 1));
      expect(await q.runOne(JobLane.io), isFalse);
    });

    test('a job leased by a dead worker is re-run once its lease passes', () async {
      var runs = 0;
      q.register('k', JobLane.io, (_) async => runs++);
      final id = await q.enqueue('k');
      // Simulate a worker that leased the job and died.
      await (db.update(db.jobs)..where((j) => j.id.equals(id))).write(
        JobsCompanion(
          state: const Value(JobState.running),
          leaseUntil: Value(clock.now().add(const Duration(minutes: 10))),
        ),
      );
      expect(await q.runOne(JobLane.io), isFalse);
      clock.advance(const Duration(minutes: 11));
      expect(await q.runOne(JobLane.io), isTrue);
      expect(runs, 1);
      expect((await job(id)).state, JobState.done);
    });

    test('enqueueing an unknown kind throws', () async {
      expect(() => q.enqueue('nope'), throwsStateError);
    });
  });

  group('engine commands', () {
    late AntEngine engine;
    late MemBlobs blobs;
    setUp(() {
      blobs = MemBlobs();
      engine = _engine(db, blobs: blobs);
    });

    Future<Fact> factById(String id) => (db.select(db.facts)..where((f) => f.id.equals(id))).getSingle();
    Future<List<FactRevision>> factRevs(String id) =>
        (db.select(db.factRevisions)
              ..where((r) => r.factId.equals(id))
              ..orderBy([(r) => OrderingTerm.asc(r.revision)]))
            .get();

    test('addNote creates standalone evidence on the local day with a user revision', () async {
      final tzEngine = _engine(db, offset: const Duration(hours: 5, minutes: 30));
      final id = await tzEngine.addNote(text: 'Helped Sam\nwith deploy', at: DateTime.utc(2026, 11, 18, 20));
      final e = await evidenceById(id);
      expect(e.day, '2026-11-19');
      expect(e.title, 'Helped Sam');
      final p = (await db.select(db.payloads).get()).single;
      expect(p.kind, PayloadKind.note);
      final revs = await revisionsOf(p.id);
      expect(revs.single.cause, RevisionCause.user);
      expect(await seed.queueCount(EntityType.day, '2026-11-19'), greaterThanOrEqualTo(1));
    });

    test('addNote attached to evidence adds a payload, not a new evidence', () async {
      await ing.ingest(src, [
        obs('m', {'t': 1}),
      ]);
      final eid = (await payloadOf('m')).evidenceId;
      final returned = await engine.addNote(text: 'context', at: DateTime.utc(2026, 11, 18, 10), attachTo: eid);
      expect(returned, eid);
      expect(await db.select(db.evidences).get(), hasLength(1));
      expect((await db.select(db.payloads).get()).where((p) => p.evidenceId == eid), hasLength(2));
    });

    test(
      'attachment sha256 is the sha256 of the file bytes',
      () async {
        final bytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0xFF, 0x00, 0xC3, 0xA9]);
        final path = await blobs.put(bytes, extension: 'png');
        await engine.addNote(text: 'shot', at: DateTime.utc(2026, 11, 18), attachmentPaths: [path]);
        final a = (await db.select(db.attachments).get()).single;
        expect(a.size, bytes.length);
        expect(a.sha256, sha256.convert(bytes).toString());
      },
    );

    test('confirm/edit bump revision, append history and make dependent snapshots stale', () async {
      final p = await seed.evidence(src, '2026-11-18', {'t': 1});
      final f = await seed.fact('Old statement', '2026-11-18', cites: [p.payload]);
      await engine.deps.record(
        (type: EntityType.reportSnapshot, id: 's'),
        1,
        [(type: EntityType.fact, id: f, revision: 1)],
      );
      await engine.confirmFact(f);
      var fact = await factById(f);
      expect(fact.origin, FactOrigin.confirmed);
      expect(fact.revision, 2);
      expect(await engine.staleness.isStale((type: EntityType.reportSnapshot, id: 's')), isTrue);
      expect(await seed.queueCount(EntityType.reportSnapshot, 's'), 1);

      await engine.editFact(f, 'New statement', details: {'k': 'v'});
      fact = await factById(f);
      expect(fact.statement, 'New statement');
      expect(jsonDecode(fact.details), {'k': 'v'});
      expect(fact.origin, FactOrigin.userEdited);
      final revs = await factRevs(f);
      expect(revs.map((r) => r.revision), [2, 3]);
      expect(revs.every((r) => r.changedBy == 'user'), isTrue);
      // Editing without details keeps them.
      await engine.editFact(f, 'Newer');
      expect(jsonDecode((await factById(f)).details), {'k': 'v'});
    });

    test('rejectFact retires it as rejected and it leaves get_facts', () async {
      final f = await seed.fact('Claim', '2026-11-18', win: WinStatus.suggested);
      await engine.rejectFact(f);
      final fact = await factById(f);
      expect(fact.retired, isTrue);
      expect(fact.winStatus, WinStatus.rejected);
      expect(fact.origin.isUserTouched, isTrue);
      registerBuiltinTools(engine.tools);
      final out = await engine.tools['get_facts'].call({
        'start': '2026-11-01',
        'end': '2026-11-30',
      }, engine.toolContext);
      expect(out['facts'], isEmpty);
    });

    test('accepting a win makes a model fact user-touched', () async {
      final f = await seed.fact('Shipped', '2026-11-18', win: WinStatus.suggested);
      await engine.setWinStatus(f, WinStatus.accepted);
      final fact = await factById(f);
      expect(fact.winStatus, WinStatus.accepted);
      expect(fact.origin.isUserTouched, isTrue);
      // A user-edited fact keeps its origin.
      final g = await seed.fact('Edited', '2026-11-18', origin: FactOrigin.userEdited);
      await engine.setWinStatus(g, WinStatus.accepted);
      expect((await factById(g)).origin, FactOrigin.userEdited);
    });

    test('resolveReview: accept applies the proposal, dismiss keeps the fact; both clear the review', () async {
      final a = await seed.fact('Mine', '2026-11-18', origin: FactOrigin.confirmed);
      final b = await seed.fact('Mine too', '2026-11-18', origin: FactOrigin.confirmed);
      for (final id in [a, b]) {
        await (db.update(db.facts)..where((f) => f.id.equals(id))).write(
          FactsCompanion(
            reviewState: const Value(ReviewState.needsReview),
            reviewProposal: Value(jsonEncode({'statement': 'Model says'})),
          ),
        );
      }
      await engine.resolveReview(a, accept: true);
      await engine.resolveReview(b, accept: false);
      final fa = await factById(a), fb = await factById(b);
      expect(fa.statement, 'Model says');
      expect(fa.origin, FactOrigin.confirmed);
      expect(fa.revision, 2);
      expect(fb.statement, 'Mine too');
      expect(fb.revision, 1);
      for (final f in [fa, fb]) {
        expect(f.reviewState, ReviewState.ok);
        expect(f.reviewProposal, isNull);
      }
    });

    test('star/hide set user importance; clearing both hands importance back to the model', () async {
      final e = (await seed.evidence(src, '2026-11-18', {'t': 1})).evidence;
      await engine.setStarred(e, true);
      var ev = await evidenceById(e);
      expect((ev.importance, ev.importanceSetBy), (1.0, ImportanceSetBy.user));
      await engine.setHidden(e, true);
      ev = await evidenceById(e);
      expect((ev.starred, ev.hidden, ev.importance), (true, true, 0.0));
      await engine.setHidden(e, false);
      await engine.setStarred(e, false);
      ev = await evidenceById(e);
      expect(ev.importanceSetBy, isNull);
      expect(await seed.queueCount(EntityType.day, '2026-11-18'), greaterThanOrEqualTo(1));
    });

    test(
      'invariant 9: starring evidence upgrades an Outcome fact citing it to an accepted win',
      () async {
        final e = await seed.evidence(src, '2026-11-18', {'t': 1});
        final f = await seed.fact('Launched', '2026-11-18', cites: [e.payload]);
        await engine.setStarred(e.evidence, true);
        expect((await factById(f)).winStatus, WinStatus.accepted);
      },
    );

    test('lock pins the latest snapshot; unlock clears it; locking with no snapshot fails', () async {
      final t = TemplateService(db);
      await t.seedBuiltins();
      await db
          .into(db.reports)
          .insert(
            ReportsCompanion.insert(
              id: 'r',
              periodKind: PeriodKind.daily,
              periodStart: '2026-11-18',
              periodEnd: '2026-11-18',
              templateId: 'builtin.standup',
            ),
          );
      await expectLater(engine.lockReport('r'), throwsStateError);
      for (final v in [1, 2]) {
        await db
            .into(db.reportSnapshots)
            .insert(
              ReportSnapshotsCompanion.insert(
                id: 'snap$v',
                reportId: 'r',
                version: v,
                json: '{}',
                markdown: '',
                modelId: 'm',
                generatedAt: seed.now,
              ),
            );
      }
      await engine.lockReport('r');
      var r = await (db.select(db.reports)..where((x) => x.id.equals('r'))).getSingle();
      expect((r.locked, r.lockedSnapshotId), (true, 'snap2'));
      await engine.unlockReport('r');
      r = await (db.select(db.reports)..where((x) => x.id.equals('r'))).getSingle();
      expect((r.locked, r.lockedSnapshotId), (false, null));
    });
  });

  group('FTS search robustness (#52)', () {
    late AntEngine engine;
    setUp(() {
      engine = _engine(db);
      registerBuiltinTools(engine.tools);
    });
    Future<Map<String, Object?>> search(String q, {Map<String, Object?> extra = const {}}) =>
        engine.tools['search_evidence'].call({'query': q, ...extra}, engine.toolContext);
    Future<int> hits(String q) async => ((await search(q))['evidence'] as List).length;

    test('special characters and FTS operators never throw', () async {
      await engine.addNote(text: 'Fixed the NEAR(cache) AND "retry" bug: 50% faster * yes', at: seed.now);
      for (final q in [
        '"',
        '""',
        "'",
        '*',
        '(',
        ')',
        'NEAR',
        'AND OR NOT',
        '-retry',
        'a:b',
        '^cache',
        'cache*',
        '{x}',
        r'\',
        '%',
        'retry"',
        '"unterminated',
        '   ',
        '\t\n',
      ]) {
        await expectLater(search(q), completes, reason: 'query <$q>');
      }
      expect(await hits('retry'), 1);
      expect(await hits('"retry"'), 1);
      expect(await hits('AND'), 1, reason: 'operators are searched as words');
    });

    test('all words must match', () async {
      await engine.addNote(text: 'payments refactor', at: seed.now);
      await engine.addNote(text: 'payments outage', at: seed.now);
      expect(await hits('payments'), 2);
      expect(await hits('payments outage'), 1);
      expect(await hits('outage refactor'), 0);
    });

    test("apostrophes and quotes in content are searchable", () async {
      await engine.addNote(text: "Paired with O'Brien on the \"hotfix\"", at: seed.now);
      expect(await hits("O'Brien"), 1);
      expect(await hits('hotfix'), 1);
      expect(await hits('"hotfix"'), 1);
    });

    test('unicode: case and diacritics fold, non-Latin scripts and emoji work', () async {
      await engine.addNote(text: 'Café menu naïve résumé Привет мир 🚀 launch', at: seed.now);
      expect(await hits('cafe'), 1);
      expect(await hits('CAFÉ'), 1);
      expect(await hits('resume'), 1);
      expect(await hits('привет'), 1);
      expect(await hits('🚀'), anyOf(0, 1)); // must not throw
      expect(await hits('launch'), 1);
    });

    test(
      'words after a newline in a note are searchable',
      () async {
        await engine.addNote(text: 'first line\nsecond paragraph\ttabbed', at: seed.now);
        expect(await hits('second'), 1);
        expect(await hits('tabbed'), 1);
      },
    );

    test(
      'JSON structure is not searchable text',
      () async {
        await engine.addNote(text: 'standup', at: seed.now);
        expect(await hits('attachments'), 0);
        expect(await hits('link'), 0);
        expect(await hits('null'), 0);
      },
    );

    test('tombstoned payloads and hidden evidence are excluded; revived payloads come back', () async {
      await ing.ingest(src, [
        obs('a', {'text': 'zebra'}),
      ]);
      expect(await hits('zebra'), 1);
      await ing.ingest(src, [
        obs('a', {'text': 'zebra'}, tombstone: true),
      ]);
      expect(await hits('zebra'), 0);
      await ing.ingest(src, [
        obs('a', {'text': 'zebra'}),
      ]);
      expect(await hits('zebra'), 1);
      final eid = (await payloadOf('a')).evidenceId;
      await engine.setHidden(eid, true);
      expect(await hits('zebra'), 0);
    });

    test('updated content replaces the old index entry', () async {
      await ing.ingest(src, [
        obs('a', {'text': 'alpha'}),
      ]);
      await ing.ingest(src, [
        obs('a', {'text': 'beta'}),
      ]);
      expect(await hits('alpha'), 0);
      expect(await hits('beta'), 1);
    });

    test('fact statements are indexed, follow edits and drop when retired', () async {
      final f = await seed.fact('Migrated billing service', '2026-11-18');
      Future<int> factHits(String q) async => ((await search(q))['facts'] as List).length;
      expect(await factHits('billing'), 1);
      await engine.editFact(f, 'Migrated invoicing service');
      expect(await factHits('billing'), 0);
      expect(await factHits('invoicing'), 1);
      await engine.rejectFact(f);
      expect(await factHits('invoicing'), 0);
    });

    test('day range and limit filters', () async {
      for (var i = 1; i <= 5; i++) {
        await engine.addNote(text: 'deploy $i', at: DateTime.utc(2026, 11, i, 12));
      }
      expect(
        ((await search('deploy', extra: {'start': '2026-11-02', 'end': '2026-11-04'}))['evidence'] as List).length,
        3,
      );
      expect(((await search('deploy', extra: {'limit': 2}))['evidence'] as List).length, 2);
      expect(((await search('deploy', extra: {'limit': 0}))['evidence'] as List).length, 1, reason: 'clamped to ≥ 1');
    });
  });
}

AntEngine _engine(ProfileDb db, {MemBlobs? blobs, Duration offset = Duration.zero}) => AntEngine(
  db: db,
  profileId: 'p1',
  ports: EnginePorts(
    secrets: MemSecrets(),
    blobs: blobs ?? MemBlobs(),
    git: NoGit(),
    watcher: NoWatcher(),
    clock: MutableClock(DateTime.utc(2026, 11, 18, 12)),
  ),
  router: ScriptedRouter(ScriptedLlm([])),
  utcOffset: (_) => offset,
);
